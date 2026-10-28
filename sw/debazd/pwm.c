/*
 * pwm.c - PWM on the fan connector outputs (J3 / J5 pin 4, fields
 * /fan/3/out and /fan/5/out, hdmi_audio_regs IO_OUT [9:8]).
 *
 * J3 uses the hardware PWM when the bitstream has it (build `pwm`,
 * 2026-10-27; PWM_ID "PWM1" at 0x43C6_0098) and the rate is >= 6 Hz: exact
 * to 10 ns, no CPU. Otherwise (J5, J3 below 6 Hz or an older bitstream) a
 * software thread makes the edges. The commands are the same:
 *
 *   /fan/<3|5>/pwm f:hz f:duty     start: duty 0..1 = part of each period with
 *                                  the opto ON (pin 4 low). Software 0.1-2000
 *                                  Hz; J3 hardware 6 Hz-100 kHz (the opto
 *                                  only follows a few kHz)
 *   /fan/<3|5>/pwm 0               stop (opto off, pin 4 high)
 *   /fan/<3|5>/pwm                 -> /fan/<n>/pwm f:hz f:duty
 *   /fan/<3|5>/duty f              duty only (for LFO targets: "/fan/3/duty $0")
 *   /fan/<3|5>/servo f:pos [f:min_ms f:max_ms]
 *                                  50 Hz, pin 4 HIGH for min..max ms (default
 *                                  1..2) at pos 0..1 = an RC servo pulse
 *   /fan/pwm/stats                 -> /fan/pwm/stats f:late_max_us f:late_avg_us i:edges
 *                                  (software edges only)
 *   Raw hardware fields: /fan/3/pwm/{on,period,duty,invert,lock}; lock = 1
 *   restarts the period at each vsync start (pulses locked to the frame).
 *
 * One SCHED_FIFO thread (priority 55, below the vsync thread) sleeps to each
 * edge; at <= 200 Hz it sleeps to 100 us before the edge and then spins, for
 * a few us of jitter (cost: about 1 % CPU per channel at 50 Hz). Above that
 * it only sleeps: expect 50-500 us of jitter. The opto limits the rate to a
 * few kHz anyway (ROADMAP.md section 11).
 * ⚠ pin 4 pulls up to 12 V on the board: replace the pull-up before a servo
 * or a 5 V logic input goes on pin 4.
 * A write to /fan/<n>/out while the PWM runs is overwritten at the next edge.
 */
#include "debazd.h"
#include "dz_fields.h"
#include "dz_hw.h"
#include "dz_map.h"

#include <math.h>
#include <pthread.h>
#include <stdio.h>
#include <string.h>
#include <time.h>

#define NCH		2
#define SPIN_S		100e-6
#define SPIN_MAX_HZ	200.0
#define HW_MIN_HZ	6.0		/* 24-bit period at 100 MHz: 5.96 Hz */
#define HW_MAX_HZ	100e3
#define PWM_ID_OFF	0x98
#define PWM_ID		0x50574D31u	/* "PWM1" */

typedef struct {
	const dz_field *out;
	double hz, duty;	/* duty = opto ON part of the period */
	int    on;		/* software PWM running */
	int    hw;		/* hardware PWM running (J3 only) */
	int    inv;		/* hardware: active part = opto off (servo) */
	int    level;		/* last written /fan/<n>/out */
	double next;		/* time of the next edge */
} pwm_ch;

static pwm_ch          ch[NCH];
static const int       conn[NCH] = { 3, 5 };
static pthread_t       th;
static int             th_ok, quit;
static pthread_mutex_t mu = PTHREAD_MUTEX_INITIALIZER;
static pthread_cond_t  cv = PTHREAD_COND_INITIALIZER;
static double          late_max, late_sum;
static int             hw_ok;		/* J3 hardware PWM in this bitstream */
static const dz_field *f_on, *f_period, *f_duty, *f_inv;
static unsigned long   edges;

static double mono(void)
{
	struct timespec t;

	clock_gettime(CLOCK_MONOTONIC, &t);
	return t.tv_sec + t.tv_nsec / 1e9;
}

static void sleep_until(double t)
{
	struct timespec ts;

	ts.tv_sec = (time_t)t;
	ts.tv_nsec = (long)((t - (double)ts.tv_sec) * 1e9);
	clock_nanosleep(CLOCK_MONOTONIC, TIMER_ABSTIME, &ts, NULL);
}

static void set_level(pwm_ch *c, int v)
{
	if (c->level != v && c->out)
		dz_field_write(c->out, (uint32_t)v);
	c->level = v;
}

/* constant output for duty 0 / 1, else 1 = the PWM needs edges */
static int needs_edges(const pwm_ch *c)
{
	return c->on && c->duty > 0.0 && c->duty < 1.0;
}

static void *pwm_main(void *arg)
{
	struct sched_param sp = { .sched_priority = 55 };

	(void)arg;
	if (pthread_setschedparam(pthread_self(), SCHED_FIFO, &sp) != 0)
		dzd_log("pwm: no real-time priority (not root?) - fan PWM jitter will be high\n");
	pthread_mutex_lock(&mu);
	while (!quit) {
		int k = -1;
		double t, edge;

		for (int i = 0; i < NCH; i++)
			if (needs_edges(&ch[i]) && (k < 0 || ch[i].next < ch[k].next))
				k = i;
		if (k < 0) {
			pthread_cond_wait(&cv, &mu);
			continue;
		}
		edge = ch[k].next;
		{
			int spin = ch[k].hz <= SPIN_MAX_HZ;

			pthread_mutex_unlock(&mu);
			t = mono();
			if (edge - (spin ? SPIN_S : 0.0) > t)
				sleep_until(edge - (spin ? SPIN_S : 0.0));
			if (spin)
				while (mono() < edge)
					;
			pthread_mutex_lock(&mu);
		}
		/* the settings may have changed while the lock was free */
		if (quit || !needs_edges(&ch[k]) || ch[k].next != edge)
			continue;
		t = mono();
		{
			pwm_ch *c = &ch[k];
			double period = 1.0 / c->hz, late = t - edge;

			edges++;
			late_sum += late;
			if (late > late_max)
				late_max = late;
			set_level(c, !c->level);
			/* opto on for duty x period, then off for the rest */
			c->next = edge + (c->level ? c->duty : 1.0 - c->duty) * period;
			if (c->next < t - period) {	/* far behind (stall): restart */
				c->next = t;
				set_level(c, 0);
			}
		}
	}
	pthread_mutex_unlock(&mu);
	return NULL;
}

/* apply hz / duty / on of channel i (lock held) */
static void restart(int i)
{
	pwm_ch *c = &ch[i];

	if (!c->on) {
		set_level(c, 0);
	} else if (c->duty <= 0.0) {
		set_level(c, 0);
	} else if (c->duty >= 1.0) {
		set_level(c, 1);
	} else {
		set_level(c, 0);
		c->next = mono() + 0.001;	/* first ON edge 1 ms from now */
	}
	pthread_cond_signal(&cv);
}

/* ---- J3 hardware PWM (lock held) ---- */
static void hw_write(pwm_ch *c)
{
	uint32_t period = (uint32_t)lround(1e8 / c->hz);
	double active = c->inv ? 1.0 - c->duty : c->duty;

	if (period < 2)
		period = 2;
	dz_field_write(f_duty, (uint32_t)lround(active * period));
	dz_field_write(f_inv, (uint32_t)c->inv);
	dz_field_write(f_period, period);
	dz_field_write(f_on, 1);
}

static void hw_off(pwm_ch *c)
{
	dz_field_write(f_on, 0);
	c->hw = 0;
	c->level = -1;
	set_level(c, 0);		/* J3 back to the level bit: opto off */
}

/* start or change channel i (lock held); keep = keep the phase of a running
 * software PWM at the same rate */
static void go(int i, double hz, double duty, int inv, int keep)
{
	pwm_ch *c = &ch[i];
	int was;

	if (i == 0 && hw_ok && hz >= HW_MIN_HZ) {
		if (c->on) {			/* stop the software edges */
			c->on = 0;
			pthread_cond_signal(&cv);
		}
		c->hz = hz;
		c->duty = duty;
		c->inv = inv;
		c->hw = 1;
		hw_write(c);
		return;
	}
	if (c->hw)
		hw_off(c);
	was = needs_edges(c) && c->hz == hz;
	c->hz = hz;
	c->duty = duty;
	c->inv = inv;
	c->on = 1;
	if (!(keep && was && needs_edges(c)))
		restart(i);
}

void pwm_init(void)
{
	volatile uint32_t *r = dz_regs(HW_HDMI_AUDIO_REGS_0_BASE);

	f_on = dz_field_find("/fan/3/pwm/on");
	f_period = dz_field_find("/fan/3/pwm/period");
	f_duty = dz_field_find("/fan/3/pwm/duty");
	f_inv = dz_field_find("/fan/3/pwm/invert");
	/* simulated hardware has every block: give it the PWM ID too */
	if (r && dz_map_simulating())
		r[PWM_ID_OFF / 4] = PWM_ID;
	hw_ok = r && f_on && f_period && f_duty && f_inv && r[PWM_ID_OFF / 4] == PWM_ID;
	dzd_log("pwm: J3 %s, J5 software\n", hw_ok ? "hardware PWM (>= 6 Hz)" : "software");
	for (int i = 0; i < NCH; i++) {
		char p[24];

		snprintf(p, sizeof(p), "/fan/%d/out", conn[i]);
		ch[i].out = dz_field_find(p);
		ch[i].level = -1;	/* unknown: the first write always goes out */
	}
	if (pthread_create(&th, NULL, pwm_main, NULL) == 0)
		th_ok = 1;
	else
		dzd_log("pwm: no PWM thread\n");
}

void pwm_close(void)
{
	if (!th_ok)
		return;
	pthread_mutex_lock(&mu);
	quit = 1;
	for (int i = 0; i < NCH; i++) {
		if (ch[i].hw)
			hw_off(&ch[i]);
		if (ch[i].on) {
			ch[i].on = 0;
			set_level(&ch[i], 0);	/* leave the optos off */
		}
	}
	pthread_cond_signal(&cv);
	pthread_mutex_unlock(&mu);
	pthread_join(th, NULL);
	th_ok = 0;
}

static double arg_f(const dz_arg *a)
{
	return a->type == 'f' ? a->f : a->type == 'i' ? (double)a->i : NAN;
}

int pwm_dispatch(const dz_msg *m)
{
	int n, n0 = 0, i;
	char what[8];

	if (!strcmp(m->path, "/fan/pwm/stats")) {
		pthread_mutex_lock(&mu);
		dzd_reply("/fan/pwm/stats", "ffi", (float)(late_max * 1e6),
			  (float)(edges ? late_sum / edges * 1e6 : 0.0), (int)edges);
		late_max = late_sum = 0.0;
		edges = 0;
		pthread_mutex_unlock(&mu);
		return 1;
	}
	if (sscanf(m->path, "/fan/%d/%7[a-z]%n", &n, what, &n0) != 2 || m->path[n0])
		return 0;
	if (strcmp(what, "pwm") && strcmp(what, "duty") && strcmp(what, "servo"))
		return 0;
	i = n == 3 ? 0 : n == 5 ? 1 : -1;
	if (i < 0) {
		dzd_reply("/error", "ss", "fan connector is 3 or 5", m->path);
		return 1;
	}
	if (!ch[i].out || !th_ok) {
		dzd_reply("/error", "ss", "no fan outputs in this bitstream (or no PWM thread)", m->path);
		return 1;
	}
	pthread_mutex_lock(&mu);
	if (!strcmp(what, "pwm") && m->n >= 1) {
		double hz = arg_f(&m->a[0]), duty = m->n >= 2 ? arg_f(&m->a[1]) : ch[i].duty;
		double max = (i == 0 && hw_ok) ? HW_MAX_HZ : 2000.0;

		if (hz == 0.0) {
			if (ch[i].hw)
				hw_off(&ch[i]);
			ch[i].on = 0;
			restart(i);
		} else if (!(hz >= 0.1 && hz <= max) || !(duty >= 0.0 && duty <= 1.0)) {
			pthread_mutex_unlock(&mu);
			dzd_reply("/error", "ss", i == 0 && hw_ok ?
				  "/fan/3/pwm hz (0.1-100000, 0 = off) duty (0..1)" :
				  "/fan/<n>/pwm hz (0.1-2000, 0 = off) duty (0..1)", m->path);
			return 1;
		} else
			go(i, hz, duty, 0, 0);
	} else if (!strcmp(what, "duty") && m->n >= 1) {
		double duty = arg_f(&m->a[0]);

		if (!(duty >= 0.0 && duty <= 1.0)) {
			pthread_mutex_unlock(&mu);
			dzd_reply("/error", "ss", "duty is 0..1", m->path);
			return 1;
		}
		/* a running PWM keeps its rate and phase: the new duty applies
		 * from the next edge (hardware: the next period); a stopped one
		 * only stores it */
		if (ch[i].on || ch[i].hw)
			go(i, ch[i].hz, duty, ch[i].inv, 1);
		else
			ch[i].duty = duty;
	} else if (!strcmp(what, "servo") && m->n >= 1) {
		double pos = arg_f(&m->a[0]);
		double lo = m->n >= 3 ? arg_f(&m->a[1]) : 1.0;
		double hi = m->n >= 3 ? arg_f(&m->a[2]) : 2.0;

		if (!(pos >= 0.0 && pos <= 1.0) || !(lo > 0.0 && hi > lo && hi < 20.0)) {
			pthread_mutex_unlock(&mu);
			dzd_reply("/error", "ss", "/fan/<n>/servo pos (0..1) [min_ms max_ms] (0 < min < max < 20)", m->path);
			return 1;
		}
		/* pin 4 HIGH = opto OFF during the pulse (hardware: inverted, so
		 * the pulse starts the period, also with the vsync lock) */
		go(i, 50.0, 1.0 - (lo + pos * (hi - lo)) / 20.0, 1, 1);
	} else if (strcmp(what, "pwm")) {
		pthread_mutex_unlock(&mu);
		dzd_reply("/error", "ss", "missing value", m->path);
		return 1;
	}
	{
		char p[24];

		snprintf(p, sizeof(p), "/fan/%d/pwm", conn[i]);
		dzd_reply(p, "ff", (float)(ch[i].on || ch[i].hw ? ch[i].hz : 0.0), (float)ch[i].duty);
	}
	pthread_mutex_unlock(&mu);
	return 1;
}

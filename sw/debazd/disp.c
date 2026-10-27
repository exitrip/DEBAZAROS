/*
 * disp.c - display buffers: show, blank, frame sequences, vsync thread.
 *
 * Model (per display d):
 *   frame store 0 = the slot or address shown (front)
 *   frame store 2 = slot DZ_SLOT_BLANK (black), set once at start
 *   blank = park on store 2, unblank = park on store 0: one register write,
 *   the front address stays as it was.
 *
 * A real-time thread waits for vsync (VTC status bit 13) and applies all
 * pending display changes right after it, so every change lands on a whole
 * frame. It sleeps until approx. 1.5 ms before the predicted vsync and polls
 * only in that window (approx. 10% of one core). Without vsync (displays not
 * started) changes apply at once and the frame tick runs from a timer.
 *
 * OSC (d = 0, 1 or a pattern):
 *   /disp/<d>/show i:slot          front = slot (next frame)
 *   /disp/<d>/home                 display 0 -> slot 0, display 1 -> slot 2
 *   /disp/<d>/capture              front = the frame the capture writes
 *   /disp/<d>/blank [i:0|1]        black / back; no argument = toggle
 *   /disp/<d>/seq i:slot ...       loop through slots, one step per `rate`
 *                                  frames; -1 = black. Strobe: seq 5 -1
 *   /disp/<d>/seq/rate i:frames    frames per step (default 1)
 *   /disp/<d>/seq/stop             back to the front slot (or black)
 *   /disp/<d>                      -> /disp/<d> i:slot i:blanked i:seq
 *   /vsync                         -> /vsync i:frames f:hz f:jitter_us i:ok
 */
#define _GNU_SOURCE
#include "debazd.h"
#include "dz_hw.h"
#include "dz_map.h"
#include "dz_vdma.h"

#include <pthread.h>
#include <sched.h>
#include <stdio.h>
#include <string.h>
#include <sys/eventfd.h>
#include <time.h>
#include <unistd.h>

#define STORE_FRONT	0
#define STORE_BLANK	2
#define SEQ_MAX		32

typedef struct {
	uint32_t front;			/* address in store 0              */
	int      blanked;
	int      want;			/* pending: new front address      */
	uint32_t want_addr;
	int      want_blank;		/* pending: -1 none, 0, 1          */
	int      seq[SEQ_MAX];		/* slots, -1 = black               */
	int      seqn, seqpos, rate, cnt, seqon, seqstop;
} dstate;

static dstate          D[DZ_DISPLAYS];
static pthread_mutex_t mu = PTHREAD_MUTEX_INITIALIZER;
static pthread_t       thr;
static volatile int    run, vs_ok;
static int             efd = -1, sim;
static double          period = 1.0 / 60.0, jit_max;
static unsigned long   frames;

static double now(void)
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

/* ---- applying changes (mu held) ------------------------------------------- */
static void park_front_or_blank(int d)
{
	dz_disp_park(d, D[d].blanked ? STORE_BLANK : STORE_FRONT);
}

static void apply(int d)
{
	dstate *s = &D[d];

	if (s->seqstop) {
		s->seqon = s->seqstop = 0;
		dz_disp_set_store(d, STORE_FRONT, s->front);
		park_front_or_blank(d);
	}
	if (s->want) {
		s->front = s->want_addr;
		s->want = 0;
		if (!s->seqon) {
			dz_disp_set_store(d, STORE_FRONT, s->front);
			park_front_or_blank(d);
		}
	}
	if (s->want_blank >= 0) {
		s->blanked = s->want_blank;
		s->want_blank = -1;
		if (!s->seqon)
			park_front_or_blank(d);
	}
	if (s->seqon && s->seqn > 0 && ++s->cnt >= s->rate) {
		int slot = s->seq[s->seqpos];

		s->cnt = 0;
		s->seqpos = (s->seqpos + 1) % s->seqn;
		if (slot < 0) {
			dz_disp_park(d, STORE_BLANK);
		} else {
			dz_disp_set_store(d, STORE_FRONT, DZ_SLOT_ADDR(slot));
			dz_disp_park(d, STORE_FRONT);
		}
	}
}

/* ---- vsync thread ----------------------------------------------------------- */
static void *vsync_main(void *arg)
{
	struct sched_param sp = { .sched_priority = 60 };
	double last = 0.0;

	(void)arg;
	if (pthread_setschedparam(pthread_self(), SCHED_FIFO, &sp) != 0)
		dzd_log("disp: no real-time priority (not root?) - vsync jitter will be high\n");
	while (run) {
		double t = now(), deadline;
		int got = 0;

		if (vs_ok && last > 0.0 && last + period - 0.0015 > t)
			sleep_until(last + period - 0.0015);
		deadline = now() + (vs_ok ? 0.004 : 0.0);
		do {				/* poll window around the expected vsync */
			if (dz_vsync_latched()) {
				got = 1;
				break;
			}
		} while (now() < deadline);
		if (!got) {
			if (vs_ok && now() - last > 0.1) {
				vs_ok = 0;
				dzd_log("disp: vsync lost\n");
			}
			if (!vs_ok)
				usleep(2000);	/* idle check, the bit stays latched */
			continue;
		}
		t = now();
		if (last > 0.0) {
			double dt = t - last;

			if (dt > 0.5 * period && dt < 1.5 * period) {
				double j = (dt - period) * 1e6;

				period += (dt - period) * 0.05;
				j = j < 0 ? -j : j;
				jit_max = j > jit_max ? j : jit_max * 0.999 + j * 0.001;
			}
		}
		if (!vs_ok)
			dzd_log("disp: vsync found\n");
		last = t;
		vs_ok = 1;
		pthread_mutex_lock(&mu);
		frames++;
		for (int d = 0; d < DZ_DISPLAYS; d++)
			apply(d);
		pthread_mutex_unlock(&mu);
		if (efd >= 0) {
			uint64_t one = 1;

			if (write(efd, &one, sizeof(one)) < 0) {
				/* eventfd full: the main loop is behind, drop the tick */
			}
		}
	}
	return NULL;
}

/* no vsync: apply at once (main thread) */
static void kick(int d)
{
	if (vs_ok)
		return;
	pthread_mutex_lock(&mu);
	apply(d);
	pthread_mutex_unlock(&mu);
}

/* ---- init ------------------------------------------------------------------- */
static void blank_slot_fill(void)
{
	size_t len = (size_t)DZ_WIDTH * DZ_HEIGHT * DZ_BPP;
	uint32_t *p = (uint32_t *)dz_slot(DZ_SLOT_BLANK, len, NULL);

	if (!p) {
		dzd_log("disp: blank slot %d not available\n", DZ_SLOT_BLANK);
		return;
	}
	for (size_t k = 0; k < len / 4; k++)
		p[k] = 0xFF000000u;
	__sync_synchronize();
}

int disp_init(int simulate)
{
	sim = simulate;
	blank_slot_fill();
	for (int d = 0; d < DZ_DISPLAYS; d++) {
		dstate *s = &D[d];
		uint32_t a = dz_disp_addr(d);	/* what it shows now */

		memset(s, 0, sizeof(*s));
		s->want_blank = -1;
		s->rate = 1;
		s->front = a;
		if (a) {	/* normalise: front in store 0, black in store 2 */
			dz_disp_set_store(d, STORE_FRONT, a);
			dz_disp_set_store(d, STORE_BLANK, DZ_SLOT_ADDR(DZ_SLOT_BLANK));
			dz_disp_park(d, STORE_FRONT);
		}
	}
	efd = eventfd(0, EFD_NONBLOCK | EFD_CLOEXEC);
	if (sim)
		return 0;
	/* map every block the thread touches now: the dz_map cache is not
	 * thread safe, so the thread must never be the first to map one */
	dz_regs(HW_HDMI_0_V_TC_0_BASE);
	dz_regs(DZ_DISP0_VDMA);
	dz_regs(DZ_DISP1_VDMA);
	run = 1;
	if (pthread_create(&thr, NULL, vsync_main, NULL) != 0) {
		run = 0;
		return -1;
	}
	return 0;
}

void disp_close(void)
{
	if (run) {
		run = 0;
		pthread_join(thr, NULL);
	}
	if (efd >= 0)
		close(efd);
	efd = -1;
}

int disp_frame_fd(void) { return efd; }
int disp_vsync_ok(void) { return vs_ok; }
double disp_frame_hz(void) { return vs_ok ? 1.0 / period : 0.0; }

/* ---- OSC ---------------------------------------------------------------------- */
static int slot_of(uint32_t a)
{
	if (a < DZ_SLOT_BASE || (a - DZ_SLOT_BASE) % DZ_SLOT_PITCH)
		return -1;
	a = (a - DZ_SLOT_BASE) / DZ_SLOT_PITCH;
	return a < DZ_SLOTS ? (int)a : -1;
}

static void status(int d)
{
	char p[24];
	int slot, bl, sq;

	pthread_mutex_lock(&mu);
	slot = slot_of(D[d].want ? D[d].want_addr : D[d].front);
	bl = D[d].want_blank >= 0 ? D[d].want_blank : D[d].blanked;
	sq = D[d].seqon;
	pthread_mutex_unlock(&mu);
	snprintf(p, sizeof(p), "/disp/%d", d);
	dzd_reply(p, "iii", slot, bl, sq);
}

static int usable(int slot)
{
	return slot >= 0 && slot < DZ_SLOTS &&
	       dz_reserved(DZ_SLOT_ADDR(slot), DZ_WIDTH * DZ_HEIGHT * DZ_BPP);
}

int disp_dispatch(const dz_msg *m)
{
	const dz_arg *a = m->a;
	int n = m->n, hits = 0;

	if (!strcmp(m->path, "/vsync")) {
		pthread_mutex_lock(&mu);
		dzd_reply("/vsync", "iffi", (int)frames, 1.0 / period, jit_max, vs_ok);
		pthread_mutex_unlock(&mu);
		return 1;
	}
	if (strncmp(m->path, "/disp/", 6))
		return 0;

	for (int d = 0; d < DZ_DISPLAYS; d++) {
		char base[16], p[40];
		const char *op = NULL;
		static const char *ops[] = { "show", "home", "capture", "blank", "seq",
					     "seq/rate", "seq/stop", NULL };

		snprintf(base, sizeof(base), "/disp/%d", d);
		if (dz_osc_match(m->path, base)) {
			op = "";
		} else {
			for (int k = 0; ops[k]; k++) {
				snprintf(p, sizeof(p), "%s/%s", base, ops[k]);
				if (dz_osc_match(m->path, p)) {
					op = ops[k];
					break;
				}
			}
		}
		if (!op)
			continue;
		hits++;
		if (!*op) {
			status(d);
			continue;
		}
		if (!dz_disp_addr(d) && !sim) {
			dzd_reply("/error", "ss", "display not running (run hdmi2 first)", base);
			continue;
		}

		pthread_mutex_lock(&mu);
		if (!strcmp(op, "show") || !strcmp(op, "home")) {
			int slot = !strcmp(op, "home") ? (d == 0 ? DZ_DISP0_HOME : DZ_DISP1_HOME)
						       : (n >= 1 ? a[0].i : -1);

			if (!usable(slot)) {
				pthread_mutex_unlock(&mu);
				dzd_reply("/error", "ss", "slot outside reserved memory or bad", base);
				continue;
			}
			D[d].want_addr = DZ_SLOT_ADDR(slot);
			D[d].want = 1;
		} else if (!strcmp(op, "capture")) {
			uint32_t c = dz_capture_addr();

			if (c) {
				D[d].want_addr = c;
				D[d].want = 1;
			}
		} else if (!strcmp(op, "blank")) {
			int cur = D[d].want_blank >= 0 ? D[d].want_blank : D[d].blanked;

			D[d].want_blank = n >= 1 ? (a[0].i != 0) : !cur;
		} else if (!strcmp(op, "seq")) {
			int k = 0;

			for (int j = 0; j < n && k < SEQ_MAX; j++)
				if (a[j].i < 0 || usable(a[j].i))
					D[d].seq[k++] = a[j].i < 0 ? -1 : a[j].i;
			if (k) {
				D[d].seqn = k;
				D[d].seqpos = 0;
				D[d].cnt = D[d].rate;	/* first step on the next frame */
				D[d].seqon = 1;
				D[d].seqstop = 0;
			}
		} else if (!strcmp(op, "seq/rate")) {
			D[d].rate = n >= 1 && a[0].i > 0 ? a[0].i : 1;
		} else if (!strcmp(op, "seq/stop")) {
			if (D[d].seqon)
				D[d].seqstop = 1;
		}
		pthread_mutex_unlock(&mu);
		kick(d);
		dzd_log("disp: %s %s\n", base, op);
		status(d);
	}
	return hits;
}

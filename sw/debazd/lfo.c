/*
 * lfo.c - soft oscillators, wave shapers, step sequences, envelopes.
 *
 * 16 LFOs, evaluated once per frame (vsync) in debazd's main thread.
 * value = min + (max - min) * quantise(curve(shape(phase)))
 *
 * OSC (<n> = 0..15 or a pattern):
 *   /lfo/<n>/shape  sine|tri|saw|ramp|square|random|smooth|step|noise|audio
 *   /lfo/<n>/rate   f:Hz                 (cycles per second)
 *   /lfo/<n>/frames i:n                  one cycle per n frames (frame exact)
 *   /lfo/<n>/width  f:0..1               square duty, tri peak position
 *   /lfo/<n>/phase  f:0..1               phase offset
 *   /lfo/<n>/range  f:min f:max          output range (default 0 1)
 *   /lfo/<n>/min f, /lfo/<n>/max f       one end of the range alone
 *   /lfo/<n>/curve  f:k                  y = y^k (1 = linear) wave shaper
 *   /lfo/<n>/steps  i:n                  quantise to n levels (0 = off)
 *   /lfo/<n>/seq    f:v0 f:v1 ...        step values (shape step), as 0..1
 *   /lfo/<n>/seq    s:"v0 v1 ..."        the same as one string: up to 1024 steps
 *                                        (an OSC message has max 32 arguments)
 *   /lfo/<n>/step   off | frames k | hz f | bpm b [div] | clock k
 *                                        step clock (2026-11-22): each step
 *                                        lasts k frames / 1/f s / one beat / div
 *                                        (div steps per beat), and the cycle =
 *                                        the sum of the steps (adding a step
 *                                        makes it longer). clock k = one step
 *                                        each time LFO k steps (a step LFO) or
 *                                        wraps (any other shape): polymeter on
 *                                        one clock. off = the steps share the
 *                                        cycle of rate / frames (as before).
 *                                        Selects shape step (not off).
 *   /lfo/<n>/dur    f:w ... | s:"w ..."  step lengths in steps (default all 1;
 *                                        0 = skip the step); no argument = off
 *   /lfo/<n>/ease   step|linear|smooth   from each step's value to the next
 *   /lfo/<n>/glide  f:0..1               the part of the step the ease takes, at
 *                                        its end (0 = jump, 1 = the whole step).
 *                                        The ease has no memory: a new seq, a
 *                                        new range etc. JUMPS at the next frame
 *   With a step clock, /phase rotates the sequence (phase x steps).
 *   /lfo/<n>/sync   i:k [f:delay] | off  phase sync (2026-11-22): this LFO takes
 *                                        LFO k's place in its cycle (any shape,
 *                                        any step counts: 3 steps span k's
 *                                        cycle of 16), instead of its own rate /
 *                                        step clock; delay = frames later
 *                                        (0..1023: k's phase of that many frames
 *                                        ago). Own /phase still adds an offset
 *                                        (cycle units). A loop of syncs holds.
 *   /lfo/<n>/delay  f:frames             the delay alone (live, cues, LFOs): for
 *                                        sync and for step clock k (this LFO
 *                                        steps that many frames after LFO k)
 *   /lfo/<n>/align  i:0|1                step clock k: 1 = back to step 0 when
 *                                        LFO k starts a new cycle (3 steps on
 *                                        16: 0 1 2 0 1 2 .. 0, stepping
 *                                        together and lined up; 0 = free
 *                                        running polymeter, as before)
 *   /lfo/<n>/fast   i:0|1                fast (2026-11-22): this LFO runs in a
 *                                        thread at /lfo/fastrate Hz instead of
 *                                        once per frame and writes its FIELD
 *                                        targets at that rate (mid-frame:
 *                                        tearing bands, jitter ~1 ms: noisy by
 *                                        design). Message targets stay at the
 *                                        frame rate (the value is the latest).
 *                                        Not for sync / clock followers (they
 *                                        run per frame; a fast leader's steps
 *                                        still clock them).
 *   /lfo/fastrate   [f:hz]               the fast thread's rate (default 1000,
 *                                        10..4000) -> /lfo/fastrate f:hz
 *                                        f:measured_hz f:late_max_ms i:fast_lfos
 *   Step lengths (dur) also count when the steps share the cycle (step off,
 *   sync): the phase goes through the steps in proportion to their lengths.
 *   /lfo/<n>/mode   loop|once            once = one cycle, then hold the end
 *   /lfo/<n>/trigger                     restart from phase 0 (and turn on)
 *   /lfo/<n>/on     [i:0|1]              default 1
 *   /lfo/<n>/every  i:k                  apply the target only every k-th frame
 *                                        (throttle heavy targets: a full-frame
 *                                        fade costs 25-60 ms)
 *   /lfo/<n>/every  change | step        apply it only when the value changes
 *                                        (shape step: the step's own value, not
 *                                        the eased one: once per new value) /
 *                                        at each step start (also when the
 *                                        value repeats; other shapes: at each
 *                                        wrap). An event sequencer: a message
 *                                        target fires once per step
 *   /lfo/<n>/target s:"/field/path"      write the value to fields (pattern ok,
 *                                        int = raw, Hz fields take Hz)
 *   /lfo/<n>/target s:"/addr a b $0 $f1" send a message to debazd itself each
 *                                        frame; $k = int value of LFO k,
 *                                        $fk = float value of LFO k
 *   /lfo/<n>/target                      (no argument) no target
 *   /lfo/<n>/audio  s:feature            shape audio (2026-11-01): the value
 *                                        follows an audio feature of react.c
 *                                        (level peak bass low mid high air flux
 *                                        beat band0..band15; /audio/react/source)
 *   /lfo/<n>/gain   f:k                  feature x k before the clamp to 0..1
 *                                        (default 1). 0 = auto: the feature /
 *                                        its recent peak (the peak halves in
 *                                        10 s): loud or quiet material both
 *                                        use the whole range
 *   /lfo/<n>/attack f:s, /release f:s    envelope follower times (default
 *                                        0 / 0.15 s); then curve, steps, range
 *   /lfo/<n>                             -> /lfo/<n> f:value i:on i:step
 *   /lfo/reset                           all LFOs off, defaults
 *
 * Example, light painting by two LFOs:
 *   /lfo/0/rate 0.3   /lfo/0/range 100 1180
 *   /lfo/1/rate 0.47  /lfo/1/range 80 640
 *   /lfo/1/target "/draw/5/brush 255 120 20 $0 $1 30 0"
 */
#define _GNU_SOURCE
#include "debazd.h"
#include "dz_fields.h"

#include <math.h>
#include <pthread.h>
#include <sched.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

#define N_LFO		16
#define MAX_TOK		DZ_OSC_MAX_ARGS
#define TPL_LEN		256
#define SEQ_LEN		1024

enum { SH_SINE, SH_TRI, SH_SAW, SH_RAMP, SH_SQUARE, SH_RANDOM, SH_SMOOTH,
       SH_STEP, SH_NOISE, SH_AUDIO, SH_COUNT };
static const char *shape_names[SH_COUNT] = {
	"sine", "tri", "saw", "ramp", "square", "random", "smooth", "step", "noise", "audio" };

typedef struct {
	int    on, once, done, shape, steps, frames, every, ecount;
	double rate, width, phase0, lo, hi, curve;
	double phase, value;
	double rnd_a, rnd_b;		/* random / smooth: previous and next */
	int    afeat;			/* audio: react.c feature index */
	double gain, attack, release, env, apk;	/* apk: auto gain peak */
	float  seq[SEQ_LEN];
	int    seqn;
	/* step clock (2026-11-22) */
	float  dur[SEQ_LEN];		/* step lengths in steps */
	int    durn;
	int    smode;			/* SM_*: 0 = the steps share rate / frames */
	double sframes, shz, sbpm, sdiv;
	int    sclock;			/* SM_CLOCK: the LFO that clocks this one */
	int    sidx;			/* step now */
	double spos, sfrac;		/* time in the step (frames or s), 0..1 of it */
	int    stepped, ticked;		/* stepped / wrapped this tick; done this tick */
	int    wrapped;			/* a new cycle began this tick */
	int    align;			/* step clock k: restart at k's new cycle */
	int    fast;			/* runs in the fast thread */
	int    fev;			/* fast: steps / wraps since the frame tick */
	int    ease;			/* EASE_* */
	double glide;
	double cur0;			/* the step's own value (before the ease) */
	int    sync;			/* phase sync: the leading LFO, -1 = off */
	double delay;			/* sync delay, frames */
	double sprev;			/* synced phase of the last tick (wraps) */
	int    emode;			/* EV_*: when the target is applied */
	int    armed;			/* fire at the next tick (on, trigger, new seq) */
	double lastkey;
	/* target */
	int    tkind;			/* 0 none, 1 fields, 2 template */
	char   tpl[TPL_LEN];		/* raw target text                  */
	char  *tok[MAX_TOK];		/* template tokens (point into tbuf) */
	int    ntok;
	char   tbuf[TPL_LEN];
	int    fields[64];		/* field indices for kind 1         */
	int    nfields;
} lfo_t;

enum { SM_OFF, SM_FRAMES, SM_HZ, SM_BPM, SM_CLOCK };
enum { EASE_STEP, EASE_LINEAR, EASE_SMOOTH };
enum { EV_FRAMES, EV_CHANGE, EV_STEP };
static const char *ease_names[] = { "step", "linear", "smooth" };

static lfo_t    L[N_LFO];
/* the fast thread (2026-11-22): L is shared, one recursive lock (the frame
 * tick's templates come back into lfo_dispatch on the same thread) */
static pthread_mutex_t lmu = PTHREAD_RECURSIVE_MUTEX_INITIALIZER_NP;
static double   fast_hz = 1000.0, frame_dt = 1.0 / 60.0;
static int      frun;			/* the fast thread runs (under lmu) */
static double   fast_meas, fast_late;	/* measured rate, worst lateness (ms) */
/* every LFO's phase of the last HIST ticks, for /sync delays */
#define HIST		1024
static float    hist[N_LFO][HIST];
static float    hfrac[N_LFO][HIST];	/* place in the step (clock delays) */
static uint8_t  hev[N_LFO][HIST];	/* bit 0 stepped, bit 1 wrapped */
static unsigned hhead;
static unsigned rng = 0x2545F491u;

static double rnd01(void)
{
	rng ^= rng << 13; rng ^= rng >> 17; rng ^= rng << 5;
	return (double)(rng & 0xFFFFFF) / (double)0xFFFFFF;
}

static void defaults(lfo_t *l)
{
	memset(l, 0, sizeof(*l));
	l->rate = 1.0;
	l->every = 1;
	l->width = 0.5;
	l->hi = 1.0;
	l->curve = 1.0;
	l->gain = 1.0;
	l->release = 0.15;
	l->rnd_a = rnd01();
	l->rnd_b = rnd01();
	l->sframes = 15;
	l->shz = 4;
	l->sbpm = 120;
	l->sdiv = 4;
	l->sclock = -1;
	l->sync = -1;
	l->armed = 1;
}

/* ---- the step sequencer ----------------------------------------------------------- */
/* length of step i in the clock's unit (frames or seconds); 0 = skipped */
static double step_len(const lfo_t *l, int i)
{
	double base = l->smode == SM_FRAMES ? l->sframes :
		      l->smode == SM_HZ ? 1.0 / l->shz :
		      l->smode == SM_BPM ? 60.0 / (l->sbpm * l->sdiv) : 1.0;
	double w = l->durn ? l->dur[i % l->durn] : 1.0;

	return w > 0.0 ? base * w : 0.0;
}

static void step_frac(lfo_t *l)
{
	double len = step_len(l, l->sidx);

	l->sfrac = len > 0.0 ? (l->spos >= len ? 1.0 : l->spos / len) : 0.0;
}

/* steps sharing the cycle (step off, sync): phase p -> step and the place in
 * it, in proportion to the step lengths (dur) */
static void step_from_phase(lfo_t *l, double p)
{
	int n = l->seqn, k = 0;
	double tot = 0.0, x, acc = 0.0;

	if (!n)
		return;
	if (!l->durn) {
		x = p * n;
		k = (int)x % n;
		l->sfrac = x - floor(x);
	} else {
		for (int i = 0; i < n; i++)
			tot += step_len(l, i);
		if (tot <= 0.0) {
			k = 0;
			l->sfrac = 0.0;
		} else {
			x = p * tot;
			for (k = 0; k < n - 1; k++) {
				double w = step_len(l, k);

				if (acc + w > x)
					break;
				acc += w;
			}
			l->sfrac = step_len(l, k) > 0.0 ? (x - acc) / step_len(l, k) : 0.0;
		}
	}
	if (k != l->sidx)
		l->stepped = 1;
	if (k < l->sidx)
		l->wrapped = 1;
	l->sidx = k;
}

/* a step-clocked LFO's place in its cycle (step lengths counted): what a
 * synced follower reads */
static double step_phase(const lfo_t *l)
{
	double tot = 0.0, before = 0.0;

	if (!l->seqn)
		return 0.0;
	if (!l->durn)
		return (l->sidx + l->sfrac) / l->seqn;
	for (int i = 0; i < l->seqn; i++) {
		double w = step_len(l, i);

		if (i < l->sidx)
			before += w;
		tot += w;
	}
	return tot > 0.0 ? (before + l->sfrac * step_len(l, l->sidx)) / tot : 0.0;
}

/* next step (skips zero-length steps); once: hold the last one */
static void step_next(lfo_t *l)
{
	for (int g = 0; g < l->seqn; g++) {
		if (l->once && l->sidx >= l->seqn - 1) {
			l->done = 1;
			return;
		}
		l->sidx = (l->sidx + 1) % l->seqn;
		l->stepped = 1;
		if (l->sidx == 0)
			l->wrapped = 1;
		if (!l->durn || step_len(l, l->sidx) > 0.0)
			return;
	}
}

/* own clock: inc = 1 frame or dt seconds */
static void step_advance(lfo_t *l, double inc)
{
	l->spos += inc;
	for (int g = 0; g <= l->seqn && !l->done; g++) {
		double len = step_len(l, l->sidx);

		if (len > 0.0 && l->spos < len)
			break;
		l->spos = len > 0.0 ? l->spos - len : l->spos;
		step_next(l);
		if (g == l->seqn)		/* every step 0 long: stand still */
			l->spos = 0.0;
	}
	if (l->done)
		l->spos = step_len(l, l->sidx);
	step_frac(l);
}

/* the value of the step now, eased toward the next one (no memory: any
 * change of seq / range / ease shows at once) */
static double step_value(lfo_t *l)
{
	int n = l->seqn, i, off = 0;
	double v0, v1, g, t;

	if (!n)
		return l->cur0 = 0.0;
	if (l->smode != SM_OFF && l->sync < 0)	/* (phase mode: in p already) */
		off = (int)floor(l->phase0 * n);
	i = (((l->sidx + off) % n) + n) % n;
	v0 = l->cur0 = l->seq[i];
	if (l->ease == EASE_STEP || l->glide <= 0.0 || (l->once && l->sidx >= n - 1))
		return v0;
	v1 = l->seq[(i + 1) % n];
	g = l->glide > 1.0 ? 1.0 : l->glide;
	t = (l->sfrac - (1.0 - g)) / g;
	if (t <= 0.0)
		return v0;
	t = t > 1.0 ? 1.0 : t;
	if (l->ease == EASE_SMOOTH)
		t = t * t * (3.0 - 2.0 * t);
	return v0 + (v1 - v0) * t;
}

/* "v v v" (spaces or commas) -> dst; returns the count */
static int parse_list(const char *s, float *dst, int max)
{
	int n = 0;
	char *end;

	while (*s && n < max) {
		while (*s == ' ' || *s == ',' || *s == '\t' || *s == '\n')
			s++;
		if (!*s)
			break;
		dst[n] = strtof(s, &end);
		if (end == s)
			break;
		if (!isfinite(dst[n]))		/* "nan", "inf", 1e39: 0 */
			dst[n] = 0.0f;
		n++;
		s = end;
	}
	return n;
}

/* a list as one string for the state model (%.4g; %.3g if it gets long) */
static const char *list_str(const float *v, int n, char *b, size_t cap)
{
	for (int pass = 0; pass < 2; pass++) {
		size_t o = 0;

		for (int k = 0; k < n && o < cap - 16; k++)
			o += (size_t)snprintf(b + o, cap - o, pass ? "%s%.3g" : "%s%.4g", k ? " " : "", (double)v[k]);
		if (o < 7000 || pass)
			break;
	}
	return b;
}

void lfo_init(void)
{
	for (int i = 0; i < N_LFO; i++)
		defaults(&L[i]);
}

/* raw wave, 0..1, for phase p in [0,1) */
static double wave(lfo_t *l, double p)
{
	double w = l->width < 0.001 ? 0.001 : (l->width > 0.999 ? 0.999 : l->width);

	switch (l->shape) {
	case SH_SINE:	return 0.5 - 0.5 * cos(2.0 * M_PI * p);
	case SH_TRI:	return p < w ? p / w : (1.0 - p) / (1.0 - w);
	case SH_SAW:	return p;
	case SH_RAMP:	return 1.0 - p;
	case SH_SQUARE:	return p < w ? 1.0 : 0.0;
	case SH_RANDOM:	return l->rnd_b;
	case SH_SMOOTH:	{
		double t = 0.5 - 0.5 * cos(M_PI * p);	/* eased */

		return l->rnd_a + (l->rnd_b - l->rnd_a) * t;
	}
	case SH_STEP:
		if ((l->smode == SM_OFF || l->sync >= 0) && l->seqn)
			step_from_phase(l, p);	/* the steps share the cycle */
		return step_value(l);
	case SH_NOISE:	return rnd01();
	case SH_AUDIO:	return l->env;
	}
	return 0.0;
}

static double shaped(lfo_t *l)
{
	double p = fmod(l->phase + l->phase0, 1.0), y = wave(l, p < 0 ? p + 1.0 : p);

	y = y < 0.0 ? 0.0 : (y > 1.0 ? 1.0 : y);
	if (l->curve > 0.0 && l->curve != 1.0)
		y = pow(y, l->curve);
	if (l->steps > 1)
		y = floor(y * l->steps) / (l->steps - 1);
	y = y > 1.0 ? 1.0 : y;
	return l->lo + (l->hi - l->lo) * y;
}

/* ---- targets ------------------------------------------------------------------- */
/* message template: split at spaces, "quoted strings" stay one token */
static int tokenize(char *p, char **tok, int max)
{
	int n = 0;

	while (*p && n < max) {
		while (*p == ' ')
			*p++ = 0;
		if (!*p)
			break;
		if (*p == '"') {
			tok[n++] = ++p;
			while (*p && *p != '"')
				p++;
			if (*p)
				*p++ = 0;
		} else {
			tok[n++] = p;
			while (*p && *p != ' ')
				p++;
		}
	}
	return n;
}

static void parse_tok(const char *s, dz_arg *a);

static void set_target(lfo_t *l, const char *t)
{
	l->tkind = 0;
	l->ntok = 0;
	l->nfields = 0;
	l->tpl[0] = 0;
	if (!t || !*t)
		return;
	snprintf(l->tpl, sizeof(l->tpl), "%s", t);
	if (!strchr(t, ' ')) {			/* field path or pattern */
		for (int i = 0; i < dz_fields_count() && l->nfields < 64; i++)
			if (dz_osc_match(t, dz_field_at(i)->path) &&
			    !(dz_field_at(i)->flags & DZ_F_RO))
				l->fields[l->nfields++] = i;
		if (l->nfields) {
			l->tkind = 1;
			return;
		}
	}
	snprintf(l->tbuf, sizeof(l->tbuf), "%s", t);
	l->ntok = tokenize(l->tbuf, l->tok, MAX_TOK);
	if (l->ntok >= 1 && l->tok[0][0] == '/')
		l->tkind = 2;
}

static void parse_tok(const char *s, dz_arg *a)
{
	char *end;
	long v;
	float f;

	memset(a, 0, sizeof(*a));
	if (s[0] == '$') {			/* $k int, $fk float */
		int isf = s[1] == 'f', k = atoi(s + 1 + isf);
		double x = (k >= 0 && k < N_LFO) ? L[k].value : 0.0;

		if (isf) {
			a->type = 'f'; a->f = (float)x; a->i = (int)x;
		} else {
			a->type = 'i'; a->i = (int)lround(x); a->f = (float)a->i;
		}
		return;
	}
	v = strtol(s, &end, 0);
	if (*s && !*end) {
		a->type = 'i'; a->i = (int32_t)v; a->f = (float)v;
		return;
	}
	f = strtof(s, &end);
	if (*s && !*end) {
		a->type = 'f'; a->f = f; a->i = (int)f;
		return;
	}
	a->type = 's';
	a->s = s;
}

static void apply_target(lfo_t *l)
{
	if (!isfinite(l->value))		/* never a NaN into a register */
		return;
	if (l->tkind == 1) {
		for (int k = 0; k < l->nfields; k++) {
			const dz_field *f = dz_field_at(l->fields[k]);
			dz_arg a = { 0 };

			if (f->unit == DZ_HZ) {
				a.type = 'f';	/* Hz */
				a.f = (float)l->value;
				a.i = (int)l->value;
				dz_field_write(f, dz_field_from_float(f, a.f));
			} else {
				a.type = 'i';
				a.i = (int)lround(l->value);
				dz_field_set(f, &a, 1, NULL);
			}
		}
	} else if (l->tkind == 2) {
		dz_msg m;

		m.path = l->tok[0];
		m.n = 0;
		for (int k = 1; k < l->ntok && m.n < DZ_OSC_MAX_ARGS; k++)
			parse_tok(l->tok[k], &m.a[m.n++]);
		dzd_handle_internal(&m);
	}
}

void dzd_send_template(const char *tpl)
{
	char buf[TPL_LEN], *tok[MAX_TOK];
	dz_msg m;
	int n;

	if (!tpl || !*tpl)
		return;
	snprintf(buf, sizeof(buf), "%s", tpl);
	n = tokenize(buf, tok, MAX_TOK);
	if (n < 1 || tok[0][0] != '/')
		return;
	m.path = tok[0];
	m.n = 0;
	for (int k = 1; k < n && m.n < DZ_OSC_MAX_ARGS; k++)
		parse_tok(tok[k], &m.a[m.n++]);
	dzd_handle_internal(&m);
}

/* one free-running LFO by dt seconds; finc = frames passed (1 on the frame
 * tick, dt / frame time in the fast thread) */
static void advance_one(lfo_t *l, double dt, double finc)
{
	double np;

	if (l->shape == SH_STEP && l->smode != SM_OFF) {
		if (l->seqn)
			step_advance(l, l->smode == SM_FRAMES ? finc : dt);
		l->phase = step_phase(l);
		l->value = shaped(l);
		return;
	}
	if (l->shape == SH_AUDIO) {	/* envelope follower on the feature */
		double f = react_feature(l->afeat), y, t;

		if (l->gain > 0.0) {
			y = f * l->gain;
		} else {		/* auto: relative to the recent peak */
			l->apk *= exp(-dt * M_LN2 / 10.0);
			l->apk = f > l->apk ? f : (l->apk < 1e-3 ? 1e-3 : l->apk);
			y = f / l->apk;
		}
		t = y > l->env ? l->attack : l->release;

		y = y < 0.0 ? 0.0 : (y > 1.0 ? 1.0 : y);
		l->env += (y - l->env) * (t > 0.0 ? 1.0 - exp(-dt / t) : 1.0);
		l->value = shaped(l);
		return;
	}
	np = l->phase + (l->frames > 0 ? finc / l->frames : l->rate * dt);
	if (np >= 1.0) {
		if (l->once) {
			np = 0.999999;
			l->done = 1;
		} else {
			np -= floor(np);
		}
		l->rnd_a = l->rnd_b;		/* new random segment */
		l->rnd_b = rnd01();
		if (l->shape != SH_STEP)
			l->stepped = l->wrapped = 1;	/* a wrap clocks followers */
	}
	l->phase = np;
	if (l->shape != SH_STEP)
		l->sfrac = np;
	l->value = shaped(l);
}

/* is the target due now (every k / change / step)? */
static int due(lfo_t *l)
{
	int fire;

	if (l->emode == EV_CHANGE) {	/* the step's own value for shape step */
		double key = l->shape == SH_STEP ? l->cur0 : l->value;

		fire = l->armed || key != l->lastkey;
		l->lastkey = key;
	} else if (l->emode == EV_STEP) {
		fire = l->armed || l->stepped;
	} else {
		fire = ++l->ecount >= l->every;
		if (fire)
			l->ecount = 0;
	}
	l->armed = 0;
	return fire;
}

/* a free-running LFO the fast thread may move (followers run per frame) */
static int fast_ok(const lfo_t *l)
{
	return l->fast && l->sync < 0 && !(l->shape == SH_STEP && l->smode == SM_CLOCK);
}

/* the fast thread: fast LFOs at fast_hz, their field targets written at once */
static void *fast_main(void *arg)
{
	struct timespec next;
	double last, w0, late = 0.0;
	long ticks = 0;
	(void)arg;

	clock_gettime(CLOCK_MONOTONIC, &next);
	last = w0 = next.tv_sec + next.tv_nsec * 1e-9;
	for (;;) {
		struct timespec now;
		double t, dt;
		int any = 0;

		next.tv_nsec += (long)(1e9 / fast_hz);
		while (next.tv_nsec >= 1000000000L) {
			next.tv_nsec -= 1000000000L;
			next.tv_sec++;
		}
		clock_nanosleep(CLOCK_MONOTONIC, TIMER_ABSTIME, &next, NULL);
		clock_gettime(CLOCK_MONOTONIC, &now);
		t = now.tv_sec + now.tv_nsec * 1e-9;
		dt = t - last;
		last = t;
		if (dt > 0.1)			/* stalled (debugger, overload) */
			dt = 0.1;
		{
			double lt = (t - (next.tv_sec + next.tv_nsec * 1e-9)) * 1000.0;

			if (lt > late)
				late = lt;
			if (lt > 50.0)		/* far behind: start again from now */
				next = now;
		}
		pthread_mutex_lock(&lmu);
		for (int i = 0; i < N_LFO; i++) {
			lfo_t *l = &L[i];

			if (!fast_ok(l) || !l->on || l->done)
				continue;
			any = 1;
			l->stepped = l->wrapped = 0;
			advance_one(l, dt, dt / frame_dt);
			l->fev |= l->stepped | l->wrapped << 1;
			if (l->tkind == 1 && isfinite(l->value) && due(l))
				apply_target(l);
		}
		ticks++;
		if (t - w0 >= 1.0) {		/* rate and lateness of the last second */
			fast_meas = ticks / (t - w0);
			fast_late = late;
			ticks = 0;
			late = 0.0;
			w0 = t;
		}
		if (!any)
			frun = 0;		/* no fast LFO on: the thread ends */
		pthread_mutex_unlock(&lmu);
		if (!any)
			return NULL;
	}
}

static void fast_start(void)	/* lmu held */
{
	pthread_t th;
	pthread_attr_t at;
	struct sched_param sp = { .sched_priority = 20 };
	int any = 0;

	for (int i = 0; i < N_LFO; i++)
		if (fast_ok(&L[i]) && L[i].on && !L[i].done)
			any = 1;
	if (frun || !any)
		return;
	pthread_attr_init(&at);
	pthread_attr_setdetachstate(&at, PTHREAD_CREATE_DETACHED);
	if (geteuid() == 0) {			/* real time when debazd may (as the vsync thread) */
		pthread_attr_setinheritsched(&at, PTHREAD_EXPLICIT_SCHED);
		pthread_attr_setschedpolicy(&at, SCHED_FIFO);
		pthread_attr_setschedparam(&at, &sp);
	}
	if (pthread_create(&th, &at, fast_main, NULL) == 0 ||
	    pthread_create(&th, NULL, fast_main, NULL) == 0)
		frun = 1;
	pthread_attr_destroy(&at);
}

void lfo_tick(double dt)
{
	pthread_mutex_lock(&lmu);
	if (dt <= 0.0 || dt > 0.5)
		dt = 1.0 / 60.0;
	frame_dt = dt;
	for (int i = 0; i < N_LFO; i++)
		L[i].stepped = L[i].ticked = L[i].wrapped = 0;
	for (int i = 0; i < N_LFO; i++) {
		lfo_t *l = &L[i];

		if (!l->on || l->done) {
			l->ticked = 1;
			continue;
		}
		if (l->sync >= 0 || (l->shape == SH_STEP && l->smode == SM_CLOCK))
			continue;		/* below, after its clock / leader */
		l->ticked = 1;
		if (fast_ok(l)) {		/* the fast thread moves it */
			l->stepped |= l->fev & 1;
			l->wrapped |= (l->fev >> 1) & 1;
			l->fev = 0;
			continue;
		}
		advance_one(l, dt, 1.0);
	}
	/* clocked by another LFO: after it (chains resolve in up to N passes;
	 * a loop of clocks never moves) */
	for (int pass = 0; pass < N_LFO; pass++) {
		int left = 0;

		for (int i = 0; i < N_LFO; i++) {
			lfo_t *l = &L[i], *c;

			if (l->ticked)
				continue;
			if (l->sync >= 0) {		/* phase sync to LFO sync */
				lfo_t *ld = l->sync < N_LFO && l->sync != i ? &L[l->sync] : NULL;
				int dl;
				double p;

				if (!ld || !ld->ticked) {
					left++;
					continue;
				}
				l->ticked = 1;
				dl = l->delay > 0.0 ? (int)lround(l->delay) : 0;
				dl = dl > HIST - 1 ? HIST - 1 : dl;
				p = dl ? hist[l->sync][(hhead - (unsigned)dl) % HIST] : ld->phase;
				if (l->shape != SH_STEP && p < l->sprev)
					l->stepped = l->wrapped = 1;	/* wrapped: clocks its followers */
				l->sprev = p;
				l->phase = p;
				if (l->shape != SH_STEP)
					l->sfrac = p;
				l->value = shaped(l);
				continue;
			}
			c = l->sclock >= 0 && l->sclock < N_LFO && l->sclock != i ? &L[l->sclock] : NULL;
			if (!c || !c->ticked) {
				left++;
				continue;
			}
			l->ticked = 1;
			{	/* k's step / wrap of `delay` frames ago (0: this tick) */
				int dl = l->delay > 0.0 ? (int)lround(l->delay) : 0, ev;
				double fr;

				dl = dl > HIST - 1 ? HIST - 1 : dl;
				if (dl) {
					unsigned at = (hhead - (unsigned)dl) % HIST;

					ev = hev[l->sclock][at];
					fr = hfrac[l->sclock][at];
				} else {
					ev = (c->on && !c->done) ? (c->stepped | c->wrapped << 1) : 0;
					fr = c->sfrac;
				}
				if (ev && l->seqn) {
					if (l->align && (ev & 2)) {	/* k's new cycle: step 0 */
						if (l->sidx != 0)
							l->wrapped = 1;
						l->sidx = 0;
						l->stepped = 1;
						l->done = 0;
					} else if (ev & 1) {
						step_next(l);
					}
					l->spos = 0.0;
				}
				l->sfrac = fr;
			}
			l->phase = step_phase(l);
			l->value = shaped(l);
		}
		if (!left)
			break;
	}
	for (int i = 0; i < N_LFO; i++) {	/* history (sync and clock delays) */
		int on = L[i].on && !L[i].done;

		hist[i][hhead % HIST] = (float)L[i].phase;
		hfrac[i][hhead % HIST] = (float)L[i].sfrac;
		hev[i][hhead % HIST] = (uint8_t)(on ? (L[i].stepped | L[i].wrapped << 1) : 0);
	}
	hhead++;
	for (int i = 0; i < N_LFO; i++) {	/* all values first: templates see them */
		lfo_t *l = &L[i];

		if (!l->on || !l->tkind)
			continue;
		if (fast_ok(l) && l->tkind == 1)
			continue;			/* the fast thread writes it */
		if (due(l))
			apply_target(l);
	}
	fast_start();
	pthread_mutex_unlock(&lmu);
}

/* ---- OSC ------------------------------------------------------------------------ */
static double fa(const dz_arg *a) { return a->type == 'f' ? a->f : (double)a->i; }

/* the state model (state.c): every LFO's settings, then on */
void lfo_state(state_cb cb, void *ctx)
{
	pthread_mutex_lock(&lmu);
	char p[40], k[40];
	static char lbuf[8192];

	for (int n = 0; n < N_LFO; n++) {
		const lfo_t *l = &L[n];

#define LP(x) (snprintf(p, sizeof(p), "/lfo/%d/" x, n), p)
		/* audio first: it also selects shape audio, the shape after it wins */
		st_emit(cb, ctx, NULL, LP("audio"), "s", react_feature_name(l->afeat));
		st_emit(cb, ctx, NULL, LP("gain"), "f", l->gain);
		st_emit(cb, ctx, NULL, LP("attack"), "f", l->attack);
		st_emit(cb, ctx, NULL, LP("release"), "f", l->release);
		/* seq, dur and step select shape step: before the shape, which wins */
		if (l->seqn > 32) {
			st_emit(cb, ctx, NULL, LP("seq"), "s", list_str(l->seq, l->seqn, lbuf, sizeof(lbuf)));
		} else if (l->seqn > 0) {
			dz_arg a[32];

			for (int j = 0; j < l->seqn; j++)
				a[j] = (dz_arg){ .type = 'f', .f = l->seq[j] };
			st_emit_args(cb, ctx, NULL, LP("seq"), a, l->seqn);
		}
		if (l->durn)
			st_emit(cb, ctx, NULL, LP("dur"), "s", list_str(l->dur, l->durn, lbuf, sizeof(lbuf)));
		else
			st_emit(cb, ctx, NULL, LP("dur"), "");
		switch (l->smode) {
		case SM_FRAMES: st_emit(cb, ctx, NULL, LP("step"), "sf", "frames", l->sframes); break;
		case SM_HZ:     st_emit(cb, ctx, NULL, LP("step"), "sf", "hz", l->shz); break;
		case SM_BPM:    st_emit(cb, ctx, NULL, LP("step"), "sff", "bpm", l->sbpm, l->sdiv); break;
		case SM_CLOCK:  st_emit(cb, ctx, NULL, LP("step"), "si", "clock", l->sclock); break;
		default:        st_emit(cb, ctx, NULL, LP("step"), "s", "off"); break;
		}
		if (l->sync >= 0)
			st_emit(cb, ctx, NULL, LP("sync"), "if", l->sync, l->delay);
		else
			st_emit(cb, ctx, NULL, LP("sync"), "s", "off");
		st_emit(cb, ctx, NULL, LP("delay"), "f", l->delay);
		st_emit(cb, ctx, NULL, LP("align"), "i", l->align);
		st_emit(cb, ctx, NULL, LP("fast"), "i", l->fast);
		st_emit(cb, ctx, NULL, LP("ease"), "s", ease_names[l->ease]);
		st_emit(cb, ctx, NULL, LP("glide"), "f", l->glide);
		st_emit(cb, ctx, NULL, LP("shape"), "s", shape_names[l->shape]);
		(void)k;			/* rate, then frames (0 = the rate counts) */
		st_emit(cb, ctx, NULL, LP("rate"), "f", l->rate);
		st_emit(cb, ctx, NULL, LP("frames"), "i", l->frames);
		st_emit(cb, ctx, NULL, LP("min"), "f", l->lo);
		st_emit(cb, ctx, NULL, LP("max"), "f", l->hi);
		st_emit(cb, ctx, NULL, LP("width"), "f", l->width);
		st_emit(cb, ctx, NULL, LP("phase"), "f", l->phase0);
		st_emit(cb, ctx, NULL, LP("curve"), "f", l->curve);
		st_emit(cb, ctx, NULL, LP("steps"), "i", l->steps);
		st_emit(cb, ctx, NULL, LP("mode"), "s", l->once ? "once" : "loop");
		if (l->emode == EV_CHANGE || l->emode == EV_STEP)
			st_emit(cb, ctx, NULL, LP("every"), "s", l->emode == EV_CHANGE ? "change" : "step");
		else
			st_emit(cb, ctx, NULL, LP("every"), "i", l->every > 0 ? l->every : 1);
		if (l->tkind)
			st_emit(cb, ctx, NULL, LP("target"), "s", l->tpl);
		else
			st_emit(cb, ctx, NULL, LP("target"), "");
		st_emit(cb, ctx, NULL, LP("on"), "i", l->on ? 1 : 0);
#undef LP
	}
	pthread_mutex_unlock(&lmu);
}

static int dispatch(const dz_msg *m);

int lfo_dispatch(const dz_msg *m)
{
	int r;

	if (strncmp(m->path, "/lfo/", 5))
		return 0;
	pthread_mutex_lock(&lmu);
	r = dispatch(m);
	if (r)
		fast_start();		/* a fast LFO switched on */
	pthread_mutex_unlock(&lmu);
	return r;
}

static int dispatch(const dz_msg *m)
{
	static const char *ops[] = { "shape", "rate", "frames", "width", "phase", "range", "min", "max",
		"curve", "steps", "seq", "mode", "trigger", "on", "target", "every",
		"audio", "gain", "attack", "release", "dur", "step", "ease", "glide", "sync", "delay", "align", "fast", NULL };
	const dz_arg *a = m->a;
	int n = m->n, hits = 0;

	if (!strcmp(m->path, "/lfo/fastrate")) {
		int nf = 0;

		if (m->n >= 1) {
			double hz = m->a[0].type == 'f' ? m->a[0].f : (double)m->a[0].i;

			fast_hz = hz < 10.0 ? 10.0 : (hz > 4000.0 ? 4000.0 : hz);
		}
		for (int i = 0; i < N_LFO; i++)
			nf += fast_ok(&L[i]) && L[i].on;
		dzd_reply("/lfo/fastrate", "fffi", fast_hz, frun ? fast_meas : 0.0, frun ? fast_late : 0.0, nf);
		return 1;
	}
	if (!strcmp(m->path, "/lfo/reset")) {
		lfo_init();
		dzd_reply("/ok", "s", m->path);
		return 1;
	}
	if (strncmp(m->path, "/lfo/", 5))
		return 0;
	for (int i = 0; i < N_LFO; i++) {
		lfo_t *l = &L[i];
		char base[16], p[40];
		const char *op = NULL;

		snprintf(base, sizeof(base), "/lfo/%d", i);
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
			dzd_reply(base, "fii", l->value, l->on, l->sidx);	/* + step now (web playhead) */
		} else if (!strcmp(op, "shape") && n >= 1) {
			if (a[0].type == 's') {
				for (int k = 0; k < SH_COUNT; k++)
					if (!strcmp(a[0].s, shape_names[k]))
						l->shape = k;
			} else if (a[0].i >= 0 && a[0].i < SH_COUNT) {
				l->shape = a[0].i;
			}
		} else if (!strcmp(op, "rate") && n >= 1) {
			l->rate = fa(&a[0]);
			l->frames = 0;
		} else if (!strcmp(op, "frames") && n >= 1) {
			l->frames = a[0].i > 0 ? a[0].i : 0;
		} else if (!strcmp(op, "width") && n >= 1) {
			l->width = fa(&a[0]);
		} else if (!strcmp(op, "phase") && n >= 1) {
			l->phase0 = fa(&a[0]);
		} else if (!strcmp(op, "range") && n >= 2) {
			l->lo = fa(&a[0]);
			l->hi = fa(&a[1]);
		} else if (!strcmp(op, "min") && n >= 1) {
			l->lo = fa(&a[0]);
		} else if (!strcmp(op, "max") && n >= 1) {
			l->hi = fa(&a[0]);
		} else if (!strcmp(op, "curve") && n >= 1) {
			l->curve = fa(&a[0]);
		} else if (!strcmp(op, "every") && n >= 1) {
			if (a[0].type == 's') {
				if (!strcmp(a[0].s, "change") || !strcmp(a[0].s, "step")) {
					l->emode = a[0].s[0] == 'c' ? EV_CHANGE : EV_STEP;
					l->armed = 1;
				} else
					dzd_reply("/error", "ss", "every: k, change or step", base);
			} else {
				l->emode = EV_FRAMES;
				l->every = a[0].i > 0 ? a[0].i : 1;
			}
		} else if (!strcmp(op, "audio") && n >= 1 && a[0].type == 's') {
			int k = react_feature_index(a[0].s);

			if (k < 0) {
				dzd_reply("/error", "ss", "audio feature: level peak bass low mid high "
					  "air flux beat band0..band15", base);
			} else {
				l->afeat = k;
				l->shape = SH_AUDIO;
			}
		} else if (!strcmp(op, "gain") && n >= 1) {
			l->gain = fa(&a[0]);
		} else if (!strcmp(op, "attack") && n >= 1) {
			l->attack = fa(&a[0]) > 0 ? fa(&a[0]) : 0.0;
		} else if (!strcmp(op, "release") && n >= 1) {
			l->release = fa(&a[0]) > 0 ? fa(&a[0]) : 0.0;
		} else if (!strcmp(op, "steps") && n >= 1) {
			l->steps = a[0].i;
		} else if (!strcmp(op, "seq")) {
			if (n == 1 && a[0].type == 's') {
				l->seqn = parse_list(a[0].s, l->seq, SEQ_LEN);
			} else {
				l->seqn = 0;
				for (int k = 0; k < n && k < SEQ_LEN; k++)
					l->seq[l->seqn++] = (float)fa(&a[k]);
			}
			l->shape = SH_STEP;
			if (l->seqn)
				l->sidx %= l->seqn;
			else
				l->sidx = 0;
			step_frac(l);
			l->armed = 1;			/* a new sequence: jump, and fire */
			l->value = shaped(l);
		} else if (!strcmp(op, "dur")) {
			if (n == 1 && a[0].type == 's')
				l->durn = parse_list(a[0].s, l->dur, SEQ_LEN);
			else {
				l->durn = 0;
				for (int k = 0; k < n && k < SEQ_LEN; k++)
					l->dur[l->durn++] = (float)fa(&a[k]);
			}
			step_frac(l);
		} else if (!strcmp(op, "step") && n >= 1 && a[0].type == 's') {
			const char *md = a[0].s;
			double v = n >= 2 ? fa(&a[1]) : 0.0;

			if (!strcmp(md, "off")) {
				l->smode = SM_OFF;
			} else if (!strcmp(md, "frames") && v > 0.0) {
				l->smode = SM_FRAMES; l->sframes = v;
			} else if (!strcmp(md, "hz") && v > 0.0) {
				l->smode = SM_HZ; l->shz = v;
			} else if (!strcmp(md, "bpm") && v > 0.0) {
				l->smode = SM_BPM; l->sbpm = v;
				l->sdiv = n >= 3 && fa(&a[2]) > 0.0 ? fa(&a[2]) : 1.0;
			} else if (!strcmp(md, "clock") && n >= 2 && (int)v >= 0 && (int)v < N_LFO && (int)v != i) {
				l->smode = SM_CLOCK; l->sclock = (int)v;
			} else {
				dzd_reply("/error", "ss", "step off | frames k | hz f | bpm b [div] | clock k (another LFO)", base);
				continue;
			}
			if (l->smode != SM_OFF)
				l->shape = SH_STEP;
			if (l->smode != SM_OFF && l->smode != SM_CLOCK) {	/* the place stays */
				double len = step_len(l, l->sidx);

				if (l->spos > len)
					l->spos = len;
			}
			step_frac(l);
		} else if (!strcmp(op, "sync") && n >= 1) {
			if (a[0].type == 's' && !strcmp(a[0].s, "off")) {
				l->sync = -1;
			} else if (a[0].type != 's' && (int)fa(&a[0]) == -1) {
				l->sync = -1;
			} else if (a[0].type != 's' && (int)fa(&a[0]) >= 0 && (int)fa(&a[0]) < N_LFO && (int)fa(&a[0]) != i) {
				l->sync = (int)fa(&a[0]);
				if (n >= 2)
					l->delay = fa(&a[1]) > 0.0 ? (fa(&a[1]) < HIST - 1 ? fa(&a[1]) : HIST - 1) : 0.0;
				l->sprev = L[l->sync].phase;
			} else {
				dzd_reply("/error", "ss", "sync k [delay frames] (another LFO) | off", base);
				continue;
			}
		} else if (!strcmp(op, "fast") && n >= 1) {
			l->fast = (int)fa(&a[0]) != 0;
			l->fev = 0;
		} else if (!strcmp(op, "align") && n >= 1) {
			l->align = (int)fa(&a[0]) != 0;
		} else if (!strcmp(op, "delay") && n >= 1) {
			double d = fa(&a[0]);

			l->delay = d > 0.0 ? (d < HIST - 1 ? d : HIST - 1) : 0.0;
		} else if (!strcmp(op, "ease") && n >= 1) {
			if (a[0].type == 's') {
				for (int k = 0; k < 3; k++)
					if (!strcmp(a[0].s, ease_names[k]))
						l->ease = k;
			} else if (a[0].i >= 0 && a[0].i < 3) {
				l->ease = a[0].i;
			}
		} else if (!strcmp(op, "glide") && n >= 1) {
			double g = fa(&a[0]);

			l->glide = g < 0.0 ? 0.0 : (g > 1.0 ? 1.0 : g);
		} else if (!strcmp(op, "mode") && n >= 1) {
			l->once = a[0].type == 's' ? !strcmp(a[0].s, "once") : a[0].i != 0;
			l->done = 0;
		} else if (!strcmp(op, "trigger")) {
			l->phase = 0.0;
			l->sidx = 0;
			l->spos = l->sfrac = 0.0;
			l->done = 0;
			l->on = 1;
			l->armed = 1;
			l->value = shaped(l);
		} else if (!strcmp(op, "on")) {
			int was = l->on;

			l->on = n >= 1 ? a[0].i != 0 : 1;
			if (l->on && !was)
				l->armed = 1;
			if (l->on)
				l->value = shaped(l);
		} else if (!strcmp(op, "target")) {
			set_target(l, n >= 1 && a[0].type == 's' ? a[0].s : NULL);
			if (n >= 1 && !l->tkind)
				dzd_reply("/error", "ss", "target matches no field and is "
					  "not a /message template", base);
		}
		dzd_log("lfo: %s %s\n", base, op);
	}
	return hits;
}

void lfo_status_lines(void)
{
	static const char *const sm[] = { "", "frames", "hz", "bpm", "clock" };

	pthread_mutex_lock(&lmu);
	for (int i = 0; i < N_LFO; i++) {
		const lfo_t *l = &L[i];
		char how[64] = "";

		if (!l->on)
			continue;
		if (l->sync >= 0)
			snprintf(how, sizeof(how), "sync %d delay %g", l->sync, l->delay);
		else if (l->shape == SH_STEP && l->smode == SM_CLOCK)
			snprintf(how, sizeof(how), "clock %d%s", l->sclock, l->align ? " align" : "");
		else if (l->shape == SH_STEP && l->smode != SM_OFF)
			snprintf(how, sizeof(how), "%d steps, step %s %g", l->seqn, sm[l->smode],
				 l->smode == SM_FRAMES ? l->sframes : l->smode == SM_HZ ? l->shz : l->sbpm);
		else if (l->frames > 0)
			snprintf(how, sizeof(how), "%d frames", l->frames);
		else
			snprintf(how, sizeof(how), "%g Hz", l->rate);
		sline("lfo %d: %s, %s%s%s -> %s", i, shape_names[l->shape], how, l->fast ? ", fast" : "",
		      l->done ? ", done" : "", l->tkind ? l->tpl : "(no target)");
	}
	pthread_mutex_unlock(&lmu);
}

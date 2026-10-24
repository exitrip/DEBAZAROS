/*
 * lfo.c - soft oscillators, wave shapers, step sequences, envelopes.
 *
 * 16 LFOs, evaluated once per frame (vsync) in debazd's main thread.
 * value = min + (max - min) * quantise(curve(shape(phase)))
 *
 * OSC (<n> = 0..15 or a pattern):
 *   /lfo/<n>/shape  sine|tri|saw|ramp|square|random|smooth|step|noise
 *   /lfo/<n>/rate   f:Hz                 (cycles per second)
 *   /lfo/<n>/frames i:n                  one cycle per n frames (frame exact)
 *   /lfo/<n>/width  f:0..1               square duty, tri peak position
 *   /lfo/<n>/phase  f:0..1               phase offset
 *   /lfo/<n>/range  f:min f:max          output range (default 0 1)
 *   /lfo/<n>/curve  f:k                  y = y^k (1 = linear) wave shaper
 *   /lfo/<n>/steps  i:n                  quantise to n levels (0 = off)
 *   /lfo/<n>/seq    f:v0 f:v1 ...        step values (shape step), as 0..1
 *   /lfo/<n>/mode   loop|once            once = one cycle, then hold the end
 *   /lfo/<n>/trigger                     restart from phase 0 (and turn on)
 *   /lfo/<n>/on     [i:0|1]              default 1
 *   /lfo/<n>/every  i:k                  apply the target only every k-th frame
 *                                        (throttle heavy targets: a full-frame
 *                                        fade costs 25-60 ms)
 *   /lfo/<n>/target s:"/field/path"      write the value to fields (pattern ok,
 *                                        int = raw, Hz fields take Hz)
 *   /lfo/<n>/target s:"/addr a b $0 $f1" send a message to debazd itself each
 *                                        frame; $k = int value of LFO k,
 *                                        $fk = float value of LFO k
 *   /lfo/<n>/target                      (no argument) no target
 *   /lfo/<n>                             -> /lfo/<n> f:value i:on
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
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define N_LFO		16
#define MAX_TOK		DZ_OSC_MAX_ARGS
#define TPL_LEN		256
#define SEQ_LEN		64

enum { SH_SINE, SH_TRI, SH_SAW, SH_RAMP, SH_SQUARE, SH_RANDOM, SH_SMOOTH,
       SH_STEP, SH_NOISE, SH_COUNT };
static const char *shape_names[SH_COUNT] = {
	"sine", "tri", "saw", "ramp", "square", "random", "smooth", "step", "noise" };

typedef struct {
	int    on, once, done, shape, steps, frames, every, ecount;
	double rate, width, phase0, lo, hi, curve;
	double phase, value;
	double rnd_a, rnd_b;		/* random / smooth: previous and next */
	float  seq[SEQ_LEN];
	int    seqn;
	/* target */
	int    tkind;			/* 0 none, 1 fields, 2 template */
	char   tpl[TPL_LEN];		/* raw target text                  */
	char  *tok[MAX_TOK];		/* template tokens (point into tbuf) */
	int    ntok;
	char   tbuf[TPL_LEN];
	int    fields[64];		/* field indices for kind 1         */
	int    nfields;
} lfo_t;

static lfo_t    L[N_LFO];
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
	l->rnd_a = rnd01();
	l->rnd_b = rnd01();
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
	case SH_STEP:	return l->seqn ? l->seq[(int)(p * l->seqn) % l->seqn] : 0.0;
	case SH_NOISE:	return rnd01();
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

void lfo_tick(double dt)
{
	if (dt <= 0.0 || dt > 0.5)
		dt = 1.0 / 60.0;
	for (int i = 0; i < N_LFO; i++) {
		lfo_t *l = &L[i];
		double np;

		if (!l->on || l->done)
			continue;
		np = l->phase + (l->frames > 0 ? 1.0 / l->frames : l->rate * dt);
		if (np >= 1.0) {
			if (l->once) {
				np = 0.999999;
				l->done = 1;
			} else {
				np -= floor(np);
			}
			l->rnd_a = l->rnd_b;		/* new random segment */
			l->rnd_b = rnd01();
		}
		l->phase = np;
		l->value = shaped(l);
	}
	for (int i = 0; i < N_LFO; i++) {	/* all values first: templates see them */
		lfo_t *l = &L[i];

		if (l->on && l->tkind && ++l->ecount >= l->every) {
			l->ecount = 0;
			apply_target(l);
		}
	}
}

/* ---- OSC ------------------------------------------------------------------------ */
static double fa(const dz_arg *a) { return a->type == 'f' ? a->f : (double)a->i; }

int lfo_dispatch(const dz_msg *m)
{
	static const char *ops[] = { "shape", "rate", "frames", "width", "phase", "range",
		"curve", "steps", "seq", "mode", "trigger", "on", "target", "every", NULL };
	const dz_arg *a = m->a;
	int n = m->n, hits = 0;

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
			dzd_reply(base, "fi", l->value, l->on);
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
		} else if (!strcmp(op, "curve") && n >= 1) {
			l->curve = fa(&a[0]);
		} else if (!strcmp(op, "every") && n >= 1) {
			l->every = a[0].i > 0 ? a[0].i : 1;
		} else if (!strcmp(op, "steps") && n >= 1) {
			l->steps = a[0].i;
		} else if (!strcmp(op, "seq")) {
			l->seqn = 0;
			for (int k = 0; k < n && k < SEQ_LEN; k++)
				l->seq[l->seqn++] = (float)fa(&a[k]);
			l->shape = SH_STEP;
		} else if (!strcmp(op, "mode") && n >= 1) {
			l->once = a[0].type == 's' ? !strcmp(a[0].s, "once") : a[0].i != 0;
			l->done = 0;
		} else if (!strcmp(op, "trigger")) {
			l->phase = 0.0;
			l->done = 0;
			l->on = 1;
			l->value = shaped(l);
		} else if (!strcmp(op, "on")) {
			l->on = n >= 1 ? a[0].i != 0 : 1;
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

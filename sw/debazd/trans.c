/*
 * trans.c - timed transitions of register fields (2026-10-30; ROADMAP.md
 * section 15, step 1). The engine of the cue fades: a ramp moves one field
 * from its value now to a target over a time, one step per frame tick (vsync,
 * or debazd's timer without it). It runs before the LFOs in the tick, so an
 * LFO on the same field has the last word. A new ramp on a field replaces
 * the old one. Packed gain words (DZ_RGB) ramp per lane; other fields as one
 * unsigned number. Curves: linear, smooth (S curve: 3x^2 - 2x^3).
 *
 *   /fx/xfade f:t [f:seconds] [s:curve]
 *        HDMI_1 cross-fade: t 0 = HDMI_1's own slot, t 1 = HDMI_0's output.
 *        Per lane the level G = own gain + feedback gain now (255 if both 0,
 *        at most 255), then own = (1 - t) G, feedback = t G: the sum stays G,
 *        so the adder does not wrap. HDMI_0 has no blend path.
 *   /fx/xfade                           -> /fx/xfade f:t (from the gains now)
 *   /trans/field s:path i|f:value f:seconds [s:curve]
 *        ramp one field (int = raw, float = 0..1 as for fields; DZ_RGB: one
 *        int = grey, or the raw 24-bit word with 0x...)
 *   /trans/stop                         stop all ramps where they are
 *   /trans/status                       -> /trans/status i:ramps_running
 */
#include "debazd.h"
#include "dz_fields.h"

#include <stdio.h>
#include <string.h>

#define RAMPS	64

enum { CURVE_LINEAR, CURVE_SMOOTH };

typedef struct {
	const dz_field *f;
	uint32_t        from, to;
	double          t, dur;
	int             curve;
	int             on;
	/* pair ramp (/fx/xfade): f = own gain, pair = feedback gain, from / to
	 * = the position t x 1e6; per lane fb = round(t G), own = G - fb, so the
	 * two always sum to G (two separate ramps could both round up: 256) */
	const dz_field *pair;
	uint32_t        g;		/* G per lane, packed as the gain word */
} ramp_t;

static ramp_t ramps[RAMPS];

/* one value between from and to at x (0..1): per lane for DZ_RGB */
static uint32_t mix(const dz_field *f, uint32_t from, uint32_t to, double x)
{
	if (f->unit == DZ_RGB) {
		uint32_t v = 0;

		for (int sh = 0; sh < 24; sh += 8) {
			double a = (from >> sh) & 0xFF, b = (to >> sh) & 0xFF;
			v |= ((uint32_t)(a + (b - a) * x + 0.5) & 0xFF) << sh;
		}
		return v;
	}
	return (uint32_t)((double)from + ((double)to - (double)from) * x + 0.5);
}

static double shape(int curve, double x)
{
	return curve == CURVE_SMOOTH ? x * x * (3.0 - 2.0 * x) : x;
}

/* Ramp field f to target (raw) in secs; secs <= 0 = at once. 0 or -1. */
int trans_field(const dz_field *f, uint32_t target, double secs, int curve)
{
	uint32_t now;
	ramp_t *free_r = NULL;

	if (!f || (f->flags & DZ_F_RO) || dz_field_read(f, &now) < 0)
		return -1;
	for (int i = 0; i < RAMPS; i++) {
		if (ramps[i].on && (ramps[i].f == f || ramps[i].pair == f)) {	/* replace: from where it is now */
			ramps[i].on = 0;
			free_r = &ramps[i];
		}
		if (!ramps[i].on && !free_r)
			free_r = &ramps[i];
	}
	if (secs <= 0.0 || !free_r)
		return dz_field_write(f, target) < 0 ? -1 : 0;
	*free_r = (ramp_t){ .f = f, .from = now, .to = target, .t = 0, .dur = secs,
			    .curve = curve, .on = 1, .pair = NULL };
	return 0;
}

/* the two gain words of an xfade position t: own = G - fb, fb = round(t G) */
static void xfade_words(uint32_t g, double t, uint32_t *own, uint32_t *fb)
{
	*own = *fb = 0;
	for (int sh = 0; sh < 24; sh += 8) {
		unsigned gl = (g >> sh) & 0xFF, b = (unsigned)(t * gl + 0.5);

		*own |= (uint32_t)(gl - b) << sh;
		*fb |= (uint32_t)b << sh;
	}
}

void trans_tick(double dt)
{
	for (int i = 0; i < RAMPS; i++) {
		ramp_t *r = &ramps[i];

		if (!r->on)
			continue;
		r->t += dt;
		double x = r->t >= r->dur ? 1.0 : r->t / r->dur;
		if (r->pair) {
			uint32_t o, b;
			double t = (r->from + ((double)r->to - r->from) * shape(r->curve, x)) / 1e6;
			xfade_words(r->g, t, &o, &b);
			dz_field_write(r->f, o);
			dz_field_write(r->pair, b);
		} else {
			dz_field_write(r->f, mix(r->f, r->from, r->to, shape(r->curve, x)));
		}
		if (x >= 1.0)
			r->on = 0;
	}
}

void trans_stop_all(void)
{
	for (int i = 0; i < RAMPS; i++)
		ramps[i].on = 0;
}

static int running(void)
{
	int n = 0;

	for (int i = 0; i < RAMPS; i++)
		n += ramps[i].on;
	return n;
}

static int arg_curve(const dz_msg *m, int i)
{
	return m->n > i && m->a[i].type == 's' && !strcmp(m->a[i].s, "smooth") ? CURVE_SMOOTH
										  : CURVE_LINEAR;
}

static double argd(const dz_arg *a)
{
	return a->type == 'f' ? (double)a->f : (double)a->i;
}

/* the HDMI_1 cross-fade position now: feedback / (own + feedback), lane mean */
static float xfade_now(const dz_field *own, const dz_field *fb)
{
	uint32_t o = 0, b = 0;
	double sum = 0;
	int lanes = 0;

	dz_field_read(own, &o);
	dz_field_read(fb, &b);
	for (int sh = 0; sh < 24; sh += 8) {
		unsigned ov = (o >> sh) & 0xFF, bv = (b >> sh) & 0xFF;
		if (ov + bv) {
			sum += (double)bv / (ov + bv);
			lanes++;
		}
	}
	return lanes ? (float)(sum / lanes) : 0.0f;
}

static int xfade(const dz_msg *m)
{
	const dz_field *own = dz_field_find("/hdmi/1/gain/rgb");
	const dz_field *fb = dz_field_find("/hdmi/1/feedback/rgb");
	uint32_t o = 0, b = 0, to_o = 0, to_b = 0;

	if (!own || !fb) {
		dzd_reply("/error", "ss", "no HDMI_1 gain fields", m->path);
		return 1;
	}
	if (m->n == 0) {
		dzd_reply("/fx/xfade", "f", xfade_now(own, fb));
		return 1;
	}
	double t = argd(&m->a[0]);
	t = t < 0 ? 0 : t > 1 ? 1 : t;
	double secs = m->n >= 2 && m->a[1].type != 's' ? argd(&m->a[1]) : 0.0;
	int curve = arg_curve(m, m->n >= 2 && m->a[1].type == 's' ? 1 : 2);

	/* G per lane from the gains now (during a running xfade the sum is
	 * still exactly G) and the position now */
	float t0 = xfade_now(own, fb);
	uint32_t g = 0;
	dz_field_read(own, &o);
	dz_field_read(fb, &b);
	for (int sh = 0; sh < 24; sh += 8) {
		unsigned gl = ((o >> sh) & 0xFF) + ((b >> sh) & 0xFF);
		g |= (uint32_t)(gl == 0 || gl > 255 ? 255 : gl) << sh;
	}
	ramp_t *slot = NULL;
	for (int i = 0; i < RAMPS; i++) {	/* replace ramps on either field */
		if (ramps[i].on && (ramps[i].f == own || ramps[i].f == fb ||
				    ramps[i].pair == own || ramps[i].pair == fb))
			ramps[i].on = 0;
		if (!ramps[i].on && !slot)
			slot = &ramps[i];
	}
	if (secs <= 0.0 || !slot) {
		xfade_words(g, t, &to_o, &to_b);
		dz_field_write(own, to_o);
		dz_field_write(fb, to_b);
	} else {
		*slot = (ramp_t){ .f = own, .pair = fb, .g = g, .from = (uint32_t)(t0 * 1e6 + 0.5),
				  .to = (uint32_t)(t * 1e6 + 0.5), .t = 0, .dur = secs,
				  .curve = curve, .on = 1 };
	}
	dzd_reply("/fx/xfade", "f", (float)t);
	return 1;
}

int trans_dispatch(const dz_msg *m)
{
	if (!strcmp(m->path, "/fx/xfade"))
		return xfade(m);
	if (strncmp(m->path, "/trans/", 7))
		return 0;
	if (!strcmp(m->path, "/trans/stop")) {
		for (int i = 0; i < RAMPS; i++)
			ramps[i].on = 0;
		dzd_reply("/trans/status", "i", 0);
		return 1;
	}
	if (!strcmp(m->path, "/trans/status")) {
		dzd_reply("/trans/status", "i", running());
		return 1;
	}
	if (!strcmp(m->path, "/trans/field")) {
		const dz_field *f = m->n >= 3 && m->a[0].type == 's' ? dz_field_find(m->a[0].s) : NULL;

		if (!f || (f->flags & DZ_F_RO) || m->a[1].type == 's') {
			dzd_reply("/error", "ss", "/trans/field s:path i|f:value f:seconds [s:curve]", m->path);
			return 1;
		}
		uint32_t target;
		if (m->a[1].type == 'f')
			target = dz_field_from_float(f, m->a[1].f);
		else if (f->unit == DZ_RGB && m->a[1].i >= 0 && m->a[1].i <= 255)
			target = (uint32_t)m->a[1].i * 0x010101u;	/* grey */
		else
			target = (uint32_t)m->a[1].i & dz_field_mask(f);
		if (trans_field(f, target, argd(&m->a[2]), arg_curve(m, 3)) < 0)
			dzd_reply("/error", "ss", "field not readable", m->a[0].s);
		else
			dzd_reply("/trans/status", "i", running());
		return 1;
	}
	return 0;
}

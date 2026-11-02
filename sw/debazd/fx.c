/*
 * fx.c - higher-level video functions built on the HDMI_0 mixer.
 *
 * Colour matrix. HDMI_0's own video goes through a 3x3 matrix (colorGainMatrix,
 * 9 xbip_multadd); mixer channel c supplies one gain per pixel. In mode 4 the
 * gain is the constant K: out = (sum of in * K) >> 16, so K 0x10000 = 1.0
 * (K is 16 bits: max 0xFFFF = 0.99998). The gains are UNSIGNED and the sums
 * do NOT saturate: a row sum above 1.0 wraps bright pixels to dark. Rows are
 * scaled down to 1.0 unless /fx/wrap 1.
 *
 * Channel of each matrix entry, out row x in column, true R G B order (traced
 * from the BD; the pixel bus is RBG, see CLAUDE.md):
 *            in R  in G  in B
 *   out R     0     2     1
 *   out G     6     7     8
 *   out B     3     4     5
 *
 *   /fx/matrix f*9         rows out R, G, B; columns in R, G, B; 0..1
 *   /fx/matrix             -> /fx/matrix f*9 (-1 = channel not in mode 4)
 *   /fx/identity           = /fx/matrix 1 0 0 0 1 0 0 0 1
 *   /fx/matrix/<o><i> f    one entry, o = out and i = in, each r|g|b (e.g.
 *                          /fx/matrix/rg 0.5 = out R from in G); the rest stays
 *   /fx/hue f:deg [f:gain] rotate the hue about the grey axis (+ = R->G->B).
 *                          Without gain the last gain stays (default 1).
 *   /fx/hue/deg f, /fx/hue/gain f   one value alone (LFO: "/fx/hue/deg $f0")
 *   /fx/hue                -> /fx/hue f:deg f:gain f:sat
 *   /fx/hue/sat f          saturation (1 = as is, 0 = grey, > 1 more, < 0
 *                          the complement), applied with the hue
 *                          Unsigned (default): negative coefficients are
 *                          clipped, so between multiples of 120 degrees the
 *                          colours lose some saturation, and sat > 1 does
 *                          little. With /fx/signed 1 they are exact.
 *   /fx/signed i           1 = write the matrix as mode 5 signed constants
 *                          (mixer coreRevision 25, build smix or later):
 *                          entries -128..128, no clipping. As in the
 *                          gateware, a negative result wraps (dark ->
 *                          bright), as a row sum > 1.0 does. Older
 *                          bitstreams store mode 5 and output 0x7FFF.
 *   /fx/map i:r i:g i:b    where each input primary goes: three 0xRRGGBB
 *                          colours (the matrix columns)
 *   /fx/wrap i             1 = allow row sums > 1.0 (wrap-around effect)
 *
 * Colour key (mixer coreRevision 22): the box is the lo..hi bands of
 * channel 0 (R lane), 3 (B lane) and 6 (G lane) with their KEY bit set; where
 * the tested pixel is inside all joined bands, HDMI_1's pixel replaces the
 * matrix result. The channels keep their mode (their gains do not change).
 *   /fx/key/color i:0xRRGGBB [i:tol]      box = colour +- tol (default 24;
 *                                         without tol the last one stays)
 *   /fx/key/tol i                         tolerance alone, same colour
 *   /fx/key/color                         -> /fx/key/color i:0xRRGGBB i:tol
 *   /fx/key/range i:0xRRGGBB i:0xRRGGBB   low and high corner (a low byte
 *                                         above the high byte = outside)
 *   /fx/key/source i                      1 = test HDMI_0's video (SRC bits)
 *   /fx/key/off                           KEY bits of all 9 channels off
 *   /key/invert, /key/stream              global fields (dz_fields.c)
 * Older bitstreams store these bits and ignore them.
 */
#include "debazd.h"
#include "dz_fields.h"
#include "dz_hw.h"
#include "dz_map.h"

#include <math.h>
#include <stdio.h>
#include <string.h>

#define K_ONE		65536.0
#define K_MAX		0xFFFFu
#define ROW_MAX		65793u		/* 255 * sum(K) must fit in 24 bits */
#define MODE_CONST	4
#define MODE_SCONST	5		/* signed constant: gain/0 [23:0], Q8.16 */

static const int chan_of[3][3] = { { 0, 2, 1 }, { 6, 7, 8 }, { 3, 4, 5 } };
static int wrap, sgn;
static float hue_deg, hue_gain = 1.0f, hue_sat = 1.0f;	/* last /fx/hue */
static uint32_t key_col = 0x00FF00;		/* last /fx/key/color */
static int key_tol = 24, key_have;

static const dz_field *mix_field(int c, const char *name)
{
	char p[32];

	snprintf(p, sizeof(p), "/mixer/%d/%s", c, name);
	return dz_field_find(p);
}

static float clamp01(float v)
{
	return v < 0.0f ? 0.0f : (v > 1.0f ? 1.0f : v);
}

/* Write m (rows out R G B, columns in R G B) as mode-4 constants, or with
 * /fx/signed as mode-5 signed constants (a row scaled when its sum is above
 * 1.0, unless /fx/wrap: grey keeps its level; a saturated colour can still
 * leave 0..255 and wraps, as in the gateware) */
static void set_matrix(float m[3][3])
{
	if (sgn) {
		for (int o = 0; o < 3; o++) {
			double sum = 0, sc = 1;

			for (int i = 0; i < 3; i++)	/* grey stays grey; colours may wrap */
				sum += m[o][i];
			if (!wrap && sum * K_ONE > ROW_MAX)
				sc = ROW_MAX / (sum * K_ONE);
			for (int i = 0; i < 3; i++) {
				int c = chan_of[o][i];
				dz_arg v = { 'f', 0, (float)(m[o][i] * sc), NULL };

				dz_field_set(mix_field(c, "g/0"), &v, 1, NULL);
				dz_field_write(mix_field(c, "mode"), MODE_SCONST);
			}
		}
		return;
	}
	for (int o = 0; o < 3; o++) {
		uint32_t k[3], sum = 0;

		for (int i = 0; i < 3; i++) {
			double v = clamp01(m[o][i]) * K_ONE + 0.5;

			k[i] = v > K_MAX ? K_MAX : (uint32_t)v;
			sum += k[i];
		}
		if (!wrap && sum > ROW_MAX)
			for (int i = 0; i < 3; i++)
				k[i] = (uint32_t)((uint64_t)k[i] * ROW_MAX / sum);
		for (int i = 0; i < 3; i++) {
			int c = chan_of[o][i];

			dz_field_write(mix_field(c, "k"), k[i]);
			dz_field_write(mix_field(c, "mode"), MODE_CONST);
		}
	}
}

/* one matrix entry: mode 4 K or mode 5 g/0; other modes: none */
static float entry(int c, float none)
{
	uint32_t mode = 0, k = 0;
	const dz_field *g = mix_field(c, "g/0");

	dz_field_read(mix_field(c, "mode"), &mode);
	if (mode == MODE_SCONST && g && dz_field_read(g, &k) == 0)
		return dz_field_to_float(g, k);
	dz_field_read(mix_field(c, "k"), &k);
	return mode == MODE_CONST ? (float)(k / K_ONE) : none;
}

static void reply_matrix(void)
{
	float v[9];

	for (int o = 0; o < 3; o++)
		for (int i = 0; i < 3; i++)
			v[o * 3 + i] = entry(chan_of[o][i], -1.0f);
	dzd_reply("/fx/matrix", "fffffffff", v[0], v[1], v[2], v[3], v[4], v[5],
		  v[6], v[7], v[8]);
}

static float num(const dz_arg *a)
{
	return a->type == 'f' ? a->f : (float)a->i;
}

/* hue gain: 0..1 unsigned (K max 0.99998), 0..4 signed */
static float gain_arg(float v)
{
	return sgn ? (v < 0 ? 0 : v > 4 ? 4 : v) : clamp01(v);
}

/* Rotation about the grey axis (1,1,1) times the saturation (both
 * circulant: they commute), times gain. Signed: exact; unsigned: the
 * negative terms clipped and the row scaled back to gain. */
static void hue_matrix(float deg, float gain, float sat, float m[3][3])
{
	double t = deg * M_PI / 180.0, c = cos(t), s = sin(t) / sqrt(3.0);
	double d = (1.0 + 2.0 * c) / 3.0, up = (1.0 - c) / 3.0 + s,
	       dn = (1.0 - c) / 3.0 - s, sum;
	double a = (1.0 + 2.0 * sat) / 3.0, b = (1.0 - sat) / 3.0;	/* saturation */
	double d2 = d * a + (up + dn) * b, up2 = up * a + (d + dn) * b, dn2 = dn * a + (d + up) * b;

	d = d2;
	up = up2;
	dn = dn2;
	if (sgn) {
		for (int o = 0; o < 3; o++) {
			m[o][o] = (float)(d * gain);
			m[o][(o + 2) % 3] = (float)(up * gain);
			m[o][(o + 1) % 3] = (float)(dn * gain);
		}
		return;
	}
	d = d < 0 ? 0 : d;
	up = up < 0 ? 0 : up;
	dn = dn < 0 ? 0 : dn;
	sum = d + up + dn;		/* >= 1 after clipping: keep rows <= 1 */
	d *= gain / sum;
	up *= gain / sum;
	dn *= gain / sum;
	for (int o = 0; o < 3; o++) {
		m[o][o] = (float)d;
		m[o][(o + 2) % 3] = (float)up;	/* R' takes B, G' takes R, ... */
		m[o][(o + 1) % 3] = (float)dn;
	}
}

/* Key channel of each colour: the channel that compares that lane. */
static const int key_chan[3] = { 0, 6, 3 };	/* R, G, B */

static int byte_add(uint32_t rgb, int sh, int d)
{
	int v = (int)((rgb >> sh) & 0xFF) + d;

	return v < 0 ? 0 : (v > 255 ? 255 : v);
}

static void key_set(uint32_t lo, uint32_t hi)
{
	for (int c = 0; c < 9; c++)
		dz_field_write(mix_field(c, "key"), 0);
	for (int k = 0; k < 3; k++) {
		int c = key_chan[k], sh = 16 - 8 * k;	/* R, G, B in 0xRRGGBB */

		dz_field_write(mix_field(c, "lo"), (lo >> sh) & 0xFF);
		dz_field_write(mix_field(c, "hi"), (hi >> sh) & 0xFF);
		dz_field_write(mix_field(c, "key"), 1);
	}
	dzd_reply("/fx/key", "ii", (int)lo, (int)hi);
}

/* the state model (state.c): the wrap flag (the matrix itself is fields) */
void fx_state(state_cb cb, void *ctx)
{
	st_emit(cb, ctx, NULL, "/fx/wrap", "i", wrap);
	st_emit(cb, ctx, NULL, "/fx/signed", "i", sgn);
}

int fx_dispatch(const dz_msg *m)
{
	const dz_arg *a = m->a;
	int n = m->n;

	if (strncmp(m->path, "/fx/", 4))
		return 0;
	if (!strcmp(m->path, "/fx/matrix")) {
		float mt[3][3];

		if (n == 0) {
			reply_matrix();
			return 1;
		}
		if (n != 9) {
			dzd_reply("/error", "ss", "/fx/matrix needs 9 values", m->path);
			return 1;
		}
		for (int k = 0; k < 9; k++)
			mt[k / 3][k % 3] = num(&a[k]);
		set_matrix(mt);
		reply_matrix();
		return 1;
	}
	if (!strcmp(m->path, "/fx/identity")) {
		float mt[3][3] = { { 1, 0, 0 }, { 0, 1, 0 }, { 0, 0, 1 } };

		set_matrix(mt);
		reply_matrix();
		return 1;
	}
	if (!strcmp(m->path, "/fx/hue") || !strcmp(m->path, "/fx/hue/deg") ||
	    !strcmp(m->path, "/fx/hue/gain") || !strcmp(m->path, "/fx/hue/sat")) {
		float mt[3][3];
		const char *sub = m->path + 7;		/* "", "/deg", "/gain", "/sat" */

		if (n < 1) {
			dzd_reply("/fx/hue", "fff", hue_deg, hue_gain, hue_sat);
			return 1;
		}
		if (!strcmp(sub, "/gain")) {
			hue_gain = gain_arg(num(&a[0]));
		} else if (!strcmp(sub, "/sat")) {
			hue_sat = num(&a[0]);
			hue_sat = hue_sat < -2 ? -2 : hue_sat > 4 ? 4 : hue_sat;
		} else {
			hue_deg = num(&a[0]);
			if (!*sub && n >= 2)
				hue_gain = gain_arg(num(&a[1]));
		}
		hue_matrix(hue_deg, hue_gain, hue_sat, mt);
		set_matrix(mt);
		reply_matrix();
		return 1;
	}
	if (!strncmp(m->path, "/fx/matrix/", 11) && strlen(m->path) == 13) {
		static const char rgb[] = "rgb";
		const char *oi = m->path + 11, *o = strchr(rgb, oi[0]), *i = strchr(rgb, oi[1]);
		float mt[3][3];

		if (!o || !i || !oi[0] || !oi[1] || n < 1) {
			dzd_reply("/error", "ss", "/fx/matrix/<out><in> f (r, g, b)", m->path);
			return 1;
		}
		for (int r = 0; r < 3; r++)		/* the matrix now (not mode 4 / 5 = 0) */
			for (int c = 0; c < 3; c++)
				mt[r][c] = entry(chan_of[r][c], 0.0f);
		mt[o - rgb][i - rgb] = num(&a[0]);
		set_matrix(mt);
		reply_matrix();
		return 1;
	}
	if (!strcmp(m->path, "/fx/map")) {
		float mt[3][3];

		if (n != 3) {
			dzd_reply("/error", "ss", "/fx/map needs 3 colours 0xRRGGBB", m->path);
			return 1;
		}
		for (int i = 0; i < 3; i++) {
			uint32_t c = (uint32_t)a[i].i;

			mt[0][i] = ((c >> 16) & 0xFF) / 255.0f;
			mt[1][i] = ((c >> 8) & 0xFF) / 255.0f;
			mt[2][i] = (c & 0xFF) / 255.0f;
		}
		set_matrix(mt);
		reply_matrix();
		return 1;
	}
	if (!strcmp(m->path, "/fx/signed")) {
		if (n >= 1)
			sgn = a[0].i != 0;
		dzd_reply("/fx/signed", "i", sgn);
		return 1;
	}
	if (!strcmp(m->path, "/fx/wrap")) {
		if (n >= 1)
			wrap = a[0].i != 0;
		dzd_reply("/fx/wrap", "i", wrap);
		return 1;
	}
	if (!strcmp(m->path, "/fx/key/color") || !strcmp(m->path, "/fx/key/tol")) {
		uint32_t c;
		int t;

		if (n < 1) {
			dzd_reply("/fx/key/color", "ii", (int)key_col, key_tol);
			return 1;
		}
		if (m->path[8] == 't') {		/* /fx/key/tol */
			key_tol = (int)num(&a[0]);
			if (!key_have)			/* no colour yet: only remember it */
				return 1;
		} else {
			if (a[0].type != 'i') {
				dzd_reply("/error", "ss", "/fx/key/color needs 0xRRGGBB [tol]", m->path);
				return 1;
			}
			key_col = (uint32_t)a[0].i;
			if (n >= 2)
				key_tol = (int)num(&a[1]);
			key_have = 1;
		}
		c = key_col;
		t = key_tol;
		key_set((uint32_t)(byte_add(c, 16, -t) << 16 | byte_add(c, 8, -t) << 8 |
				   byte_add(c, 0, -t)),
			(uint32_t)(byte_add(c, 16, t) << 16 | byte_add(c, 8, t) << 8 |
				   byte_add(c, 0, t)));
		return 1;
	}
	if (!strcmp(m->path, "/fx/key/range")) {
		if (n != 2 || a[0].type != 'i' || a[1].type != 'i') {
			dzd_reply("/error", "ss", "/fx/key/range needs 2 colours 0xRRGGBB", m->path);
			return 1;
		}
		key_set((uint32_t)a[0].i, (uint32_t)a[1].i);
		return 1;
	}
	if (!strcmp(m->path, "/fx/key/source")) {
		for (int k = 0; k < 3; k++)
			dz_field_write(mix_field(key_chan[k], "src"),
				       n >= 1 && a[0].i != 0);
		dzd_reply("/ok", "s", m->path);
		return 1;
	}
	if (!strcmp(m->path, "/fx/key/off")) {
		key_have = 0;			/* /fx/key/tol must not turn it on again */
		for (int c = 0; c < 9; c++)
			dz_field_write(mix_field(c, "key"), 0);
		dzd_reply("/ok", "s", m->path);
		return 1;
	}
	dzd_reply("/error", "ss", "no such /fx address", m->path);
	return 1;
}

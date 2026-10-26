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
 *   /fx/hue f:deg [f:gain] rotate the hue about the grey axis (+ = R->G->B).
 *                          Negative coefficients are clipped (no signed
 *                          gains), so between multiples of 120 degrees the
 *                          colours lose some saturation.
 *   /fx/map i:r i:g i:b    where each input primary goes: three 0xRRGGBB
 *                          colours (the matrix columns)
 *   /fx/wrap i             1 = allow row sums > 1.0 (wrap-around effect)
 *
 * Colour key (mixer coreRevision 22): the box is the lo..hi bands of
 * channel 0 (R lane), 3 (B lane) and 6 (G lane) with their KEY bit set; where
 * the tested pixel is inside all joined bands, HDMI_1's pixel replaces the
 * matrix result. The channels keep their mode (their gains do not change).
 *   /fx/key/color i:0xRRGGBB [i:tol]      box = colour +- tol (default 24)
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

static const int chan_of[3][3] = { { 0, 2, 1 }, { 6, 7, 8 }, { 3, 4, 5 } };
static int wrap;

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

/* Write m (rows out R G B, columns in R G B) as mode-4 constants. */
static void set_matrix(float m[3][3])
{
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

static void reply_matrix(void)
{
	float v[9];

	for (int o = 0; o < 3; o++)
		for (int i = 0; i < 3; i++) {
			int c = chan_of[o][i];
			uint32_t mode = 0, k = 0;

			dz_field_read(mix_field(c, "mode"), &mode);
			dz_field_read(mix_field(c, "k"), &k);
			v[o * 3 + i] = mode == MODE_CONST ? (float)(k / K_ONE) : -1.0f;
		}
	dzd_reply("/fx/matrix", "fffffffff", v[0], v[1], v[2], v[3], v[4], v[5],
		  v[6], v[7], v[8]);
}

static float num(const dz_arg *a)
{
	return a->type == 'f' ? a->f : (float)a->i;
}

/* Rotation about the grey axis (1,1,1): a circulant matrix. */
static void hue_matrix(float deg, float gain, float m[3][3])
{
	double t = deg * M_PI / 180.0, c = cos(t), s = sin(t) / sqrt(3.0);
	double d = (1.0 + 2.0 * c) / 3.0, up = (1.0 - c) / 3.0 + s,
	       dn = (1.0 - c) / 3.0 - s, sum;

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
	if (!strcmp(m->path, "/fx/hue")) {
		float mt[3][3];

		if (n < 1) {
			dzd_reply("/error", "ss", "/fx/hue needs degrees", m->path);
			return 1;
		}
		hue_matrix(num(&a[0]), n >= 2 ? clamp01(num(&a[1])) : 1.0f, mt);
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
	if (!strcmp(m->path, "/fx/wrap")) {
		if (n >= 1)
			wrap = a[0].i != 0;
		dzd_reply("/fx/wrap", "i", wrap);
		return 1;
	}
	if (!strcmp(m->path, "/fx/key/color")) {
		uint32_t c;
		int t;

		if (n < 1 || a[0].type != 'i') {
			dzd_reply("/error", "ss", "/fx/key/color needs 0xRRGGBB [tol]", m->path);
			return 1;
		}
		c = (uint32_t)a[0].i;
		t = n >= 2 ? (int)num(&a[1]) : 24;
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
		for (int c = 0; c < 9; c++)
			dz_field_write(mix_field(c, "key"), 0);
		dzd_reply("/ok", "s", m->path);
		return 1;
	}
	dzd_reply("/error", "ss", "no such /fx address", m->path);
	return 1;
}

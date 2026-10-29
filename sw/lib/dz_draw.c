/*
 * dz_draw.c - see dz_draw.h. Ported from sw/oscreg/oscdraw.c.
 */
#define _GNU_SOURCE
#include "dz_draw.h"
#include "dz_draw_int.h"
#include "dz_text.h"
#include "dz_shape.h"
#include "dz_xform.h"
#include "dz_hw.h"
#include "dz_map.h"
#include "dz_vdma.h"

#include <errno.h>
#include <math.h>
#include <sched.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

#if defined(__ARM_NEON)
#include <arm_neon.h>
#endif

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

typedef struct {
	int       w, h;
	size_t    stride;		/* bytes per line in the slot        */
	uint32_t *shadow;		/* w*h words, NULL until first use   */
	int       dx0, dy0, dx1, dy1;	/* dirty rectangle, x1/y1 exclusive  */
	unsigned  alpha;		/* 0..256                            */
	int       blend;		/* dz_blend                          */
	int       autoflush;
	pid_t     player;
	pid_t     aplayer;		/* the movie's audio (own process) */
} surf_t;

static surf_t surf[DZ_SLOTS];
static int    movie_verbose;	/* debazd -v: fbfeed -v prints fps to the log */

/* Geometry = the running video mode (dz_geom_*, 2026-10-28: 720p or 1080p).
 * A surface made for another mode starts again: black, its movie stopped
 * (ffmpeg/fbfeed run with the old size and stride). */
static surf_t *get(int i)
{
	surf_t *s;

	if (i < 0 || i >= DZ_SLOTS)
		return NULL;
	s = &surf[i];
	if (s->shadow && (s->w != dz_geom_w() || s->h != dz_geom_h() ||
			  s->stride != dz_geom_stride())) {
		dz_draw_movie_stop(i);
		free(s->shadow);
		s->shadow = NULL;
		s->dx0 = s->dy0 = s->dx1 = s->dy1 = 0;
	}
	if (!s->shadow) {
		s->w = dz_geom_w();
		s->h = dz_geom_h();
		s->stride = dz_geom_stride();
		s->alpha = 256;
		s->blend = DZ_BLEND_NORMAL;
		s->autoflush = 1;
		s->player = 0;
		s->shadow = calloc((size_t)s->w * s->h, sizeof(uint32_t));
		if (!s->shadow) {
			fprintf(stderr, "dz_draw: no memory for surface %d\n", i);
			return NULL;
		}
		for (size_t k = 0; k < (size_t)s->w * s->h; k++)
			s->shadow[k] = 0xFF000000u;
	}
	return s;
}

void dz_draw_close(void)
{
	for (int i = 0; i < DZ_SLOTS; i++) {
		dz_draw_movie_stop(i);
		free(surf[i].shadow);
		memset(&surf[i], 0, sizeof(surf[i]));
	}
}

/* ---- dirty tracking + present -------------------------------------------- */
static void dirty(surf_t *s, int x0, int y0, int x1, int y1)
{
	if (s->dx1 <= s->dx0 || s->dy1 <= s->dy0) {
		s->dx0 = x0; s->dy0 = y0; s->dx1 = x1; s->dy1 = y1;
		return;
	}
	if (x0 < s->dx0) s->dx0 = x0;
	if (y0 < s->dy0) s->dy0 = y0;
	if (x1 > s->dx1) s->dx1 = x1;
	if (y1 > s->dy1) s->dy1 = y1;
}

int dz_draw_present(int i)
{
	surf_t *s = get(i);
	uint8_t *dev;
	int x0, y0, x1, y1;

	if (!s)
		return -1;
	if (s->dx1 <= s->dx0 || s->dy1 <= s->dy0)
		return 0;
	dev = dz_slot(i, (size_t)(s->h - 1) * s->stride + (size_t)s->w * 4, NULL);
	if (!dev)
		return -1;
	x0 = s->dx0; y0 = s->dy0; x1 = s->dx1; y1 = s->dy1;
	for (int y = y0; y < y1; y++)
		memcpy(dev + (size_t)y * s->stride + (size_t)x0 * 4,
		       s->shadow + (size_t)y * s->w + x0, (size_t)(x1 - x0) * 4);
	/* drain the write buffer: the VDMA reads DDR and does not snoop */
	__sync_synchronize();
	s->dx0 = s->dy0 = s->dx1 = s->dy1 = 0;
	return 0;
}

int dz_draw_present_all(int i)
{
	surf_t *s = get(i);

	if (!s)
		return -1;
	dirty(s, 0, 0, s->w, s->h);
	return dz_draw_present(i);
}

static int fails;	/* operations whose present failed, see dz_draw_take_fails */

int dz_draw_take_fails(void)
{
	int n = fails;

	fails = 0;
	return n;
}

static void finish(surf_t *s, int i)
{
	if (s->autoflush && dz_draw_present(i) < 0)
		fails++;
}

void dz_draw_set_alpha(int i, float a)
{
	surf_t *s = get(i);

	if (!s)
		return;
	a = a < 0.0f ? 0.0f : (a > 1.0f ? 1.0f : a);
	s->alpha = (unsigned)(a * 256.0f + 0.5f);
}

void dz_draw_set_auto(int i, int on)
{
	surf_t *s = get(i);

	if (s)
		s->autoflush = on != 0;
}

/* ---- pixels --------------------------------------------------------------- */
static uint32_t pack(dz_color c)	/* a8r8g8b8 */
{
	return 0xFF000000u | ((uint32_t)c.r << 16) | ((uint32_t)c.g << 8) | c.b;
}

static uint32_t mix(uint32_t d, uint32_t v, unsigned a)
{
	int dr, dg, db;

	if (a >= 256)
		return v;
	if (a == 0)
		return d;
	dr = (int)((d >> 16) & 0xFF); dg = (int)((d >> 8) & 0xFF); db = (int)(d & 0xFF);
	dr += ((((int)(v >> 16) & 0xFF) - dr) * (int)a) >> 8;
	dg += ((((int)(v >> 8) & 0xFF) - dg) * (int)a) >> 8;
	db += ((((int)v & 0xFF) - db) * (int)a) >> 8;
	return 0xFF000000u | ((uint32_t)dr << 16) | ((uint32_t)dg << 8) | (uint32_t)db;
}

/* d = destination pixel, v = new colour, a = coverage 0..256, mode = dz_blend */
static uint32_t blendpx(uint32_t d, uint32_t v, unsigned a, int mode)
{
	unsigned dr, dg, db, vr, vg, vb, r, g, b;

	if (mode == DZ_BLEND_NORMAL)
		return mix(d, v, a);
	if (a == 0)
		return d;
	dr = (d >> 16) & 0xFF; dg = (d >> 8) & 0xFF; db = d & 0xFF;
	vr = (v >> 16) & 0xFF; vg = (v >> 8) & 0xFF; vb = v & 0xFF;
	switch (mode) {
	case DZ_BLEND_ADD:	/* light painting: coverage scales the light */
		r = dr + ((vr * a) >> 8); g = dg + ((vg * a) >> 8); b = db + ((vb * a) >> 8);
		r = r > 255 ? 255 : r; g = g > 255 ? 255 : g; b = b > 255 ? 255 : b;
		return 0xFF000000u | (r << 16) | (g << 8) | b;
	case DZ_BLEND_LIGHTEN:
		r = vr > dr ? vr : dr; g = vg > dg ? vg : dg; b = vb > db ? vb : db;
		break;
	case DZ_BLEND_MULTIPLY:
		r = dr * vr / 255; g = dg * vg / 255; b = db * vb / 255;
		break;
	default:
		return mix(d, v, a);
	}
	return mix(d, 0xFF000000u | (r << 16) | (g << 8) | b, a);
}

/* one pixel, with the surface alpha and blend mode, scaled by cov (0..256) */
static void put(surf_t *s, uint32_t *p, uint32_t v, unsigned cov)
{
	unsigned a = (s->alpha * cov) >> 8;

	*p = (a >= 256 && s->blend == DZ_BLEND_NORMAL) ? v : blendpx(*p, v, a, s->blend);
}

static int clip(const surf_t *s, dz_rect *r)
{
	if (r->w == 0 && r->h == 0 && r->x == 0 && r->y == 0) {
		r->w = s->w;
		r->h = s->h;
	}
	if (r->w < 0) { r->x += r->w; r->w = -r->w; }
	if (r->h < 0) { r->y += r->h; r->h = -r->h; }
	if (r->x < 0) { r->w += r->x; r->x = 0; }
	if (r->y < 0) { r->h += r->y; r->y = 0; }
	if (r->x + r->w > s->w) r->w = s->w - r->x;
	if (r->y + r->h > s->h) r->h = s->h - r->y;
	return r->w > 0 && r->h > 0;
}

static void span(surf_t *s, int y, int x0, int x1, uint32_t v)
{
	uint32_t *p;

	if (y < 0 || y >= s->h)
		return;
	if (x0 < 0) x0 = 0;
	if (x1 > s->w) x1 = s->w;
	if (x1 <= x0)
		return;
	p = s->shadow + (size_t)y * s->w;
	for (int x = x0; x < x1; x++)
		put(s, &p[x], v, 256);
	dirty(s, x0, y, x1, y + 1);
}

/* ---- drawing ---------------------------------------------------------------- */
int dz_draw_solid(int i, dz_color c, dz_rect r)
{
	surf_t *s = get(i);
	uint32_t v;

	if (!s || !clip(s, &r))
		return -1;
	dz_draw_movie_stop(i);
	v = pack(c);
	for (int y = r.y; y < r.y + r.h; y++)
		span(s, y, r.x, r.x + r.w, v);
	finish(s, i);
	return 0;
}

int dz_draw_bars(int i)
{
	static const dz_color bars[8] = {
		{ 255, 255, 255 }, { 255, 255, 0 }, { 0, 255, 255 }, { 0, 255, 0 },
		{ 255, 0, 255 },   { 255, 0, 0 },   { 0, 0, 255 },   { 0, 0, 0 },
	};
	surf_t *s = get(i);

	if (!s)
		return -1;
	dz_draw_movie_stop(i);
	for (int b = 0; b < 8; b++) {
		int x0 = s->w * b / 8, x1 = s->w * (b + 1) / 8;

		for (int y = 0; y < s->h; y++)
			span(s, y, x0, x1, pack(bars[b]));
	}
	finish(s, i);
	return 0;
}

int dz_draw_gradient(int i, dz_color a, dz_color b, float degrees, dz_rect r)
{
	surf_t *s = get(i);
	float rad, ca, sa, p0, p1, den, corner[4];

	if (!s || !clip(s, &r))
		return -1;
	dz_draw_movie_stop(i);
	rad = degrees * (float)M_PI / 180.0f;
	ca = cosf(rad);
	sa = sinf(rad);
	corner[0] = 0.0f;
	corner[1] = (float)(r.w - 1) * ca;
	corner[2] = (float)(r.h - 1) * sa;
	corner[3] = corner[1] + corner[2];
	p0 = p1 = 0.0f;
	for (int k = 1; k < 4; k++) {
		if (corner[k] < p0) p0 = corner[k];
		if (corner[k] > p1) p1 = corner[k];
	}
	den = p1 - p0;
	if (den == 0.0f)
		den = 1.0f;
	for (int y = 0; y < r.h; y++) {
		float base = (float)y * sa - p0;
		uint32_t *row = s->shadow + (size_t)(r.y + y) * s->w;

		for (int x = 0; x < r.w; x++) {
			float t = (base + (float)x * ca) / den;
			uint32_t v;

			t = t < 0.0f ? 0.0f : (t > 1.0f ? 1.0f : t);
			v = pack(DZ_RGB8(a.r + (int)((b.r - a.r) * t),
					 a.g + (int)((b.g - a.g) * t),
					 a.b + (int)((b.b - a.b) * t)));
			put(s, &row[r.x + x], v, 256);
		}
	}
	dirty(s, r.x, r.y, r.x + r.w, r.y + r.h);
	finish(s, i);
	return 0;
}

int dz_draw_corners(int i, dz_color tl, dz_color tr, dz_color bl, dz_color br,
		    dz_rect r)
{
	surf_t *s = get(i);

	if (!s || !clip(s, &r))
		return -1;
	dz_draw_movie_stop(i);
	for (int y = 0; y < r.h; y++) {
		int vq = r.h > 1 ? y * 256 / (r.h - 1) : 0;
		int lr = tl.r + (((bl.r - tl.r) * vq) >> 8);
		int lg = tl.g + (((bl.g - tl.g) * vq) >> 8);
		int lb = tl.b + (((bl.b - tl.b) * vq) >> 8);
		int rr = tr.r + (((br.r - tr.r) * vq) >> 8);
		int rg = tr.g + (((br.g - tr.g) * vq) >> 8);
		int rb = tr.b + (((br.b - tr.b) * vq) >> 8);
		uint32_t *row = s->shadow + (size_t)(r.y + y) * s->w;

		for (int x = 0; x < r.w; x++) {
			int uq = r.w > 1 ? x * 256 / (r.w - 1) : 0;
			uint32_t v = pack(DZ_RGB8(lr + (((rr - lr) * uq) >> 8),
						  lg + (((rg - lg) * uq) >> 8),
						  lb + (((rb - lb) * uq) >> 8)));

			put(s, &row[r.x + x], v, 256);
		}
	}
	dirty(s, r.x, r.y, r.x + r.w, r.y + r.h);
	finish(s, i);
	return 0;
}

int dz_draw_rect(int i, dz_color c, dz_rect r, int t)
{
	surf_t *s = get(i);
	uint32_t v;

	if (!s)
		return -1;
	if (t <= 0)
		return dz_draw_solid(i, c, r);
	if (!clip(s, &r))
		return -1;
	dz_draw_movie_stop(i);
	v = pack(c);
	if (t > r.h / 2 + 1)
		t = r.h / 2 + 1;
	for (int y = r.y; y < r.y + r.h; y++) {
		if (y < r.y + t || y >= r.y + r.h - t) {
			span(s, y, r.x, r.x + r.w, v);
		} else {
			span(s, y, r.x, r.x + t, v);
			span(s, y, r.x + r.w - t, r.x + r.w, v);
		}
	}
	finish(s, i);
	return 0;
}

int dz_draw_ellipse(int i, dz_color c, int cx, int cy, int rx, int ry, int t)
{
	surf_t *s = get(i);
	uint32_t v;

	if (!s || rx <= 0 || ry <= 0)
		return -1;
	dz_draw_movie_stop(i);
	v = pack(c);
	if (t < 0)
		t = 0;
	for (int y = cy - ry; y <= cy + ry; y++) {
		float dy, k, ho, hi = 0.0f;

		if (y < 0 || y >= s->h)
			continue;
		dy = (float)(y - cy) / (float)ry;
		k = 1.0f - dy * dy;
		if (k < 0.0f)
			continue;
		ho = (float)rx * sqrtf(k);
		if (t > 0 && rx - t > 0 && ry - t > 0) {
			float di = (float)(y - cy) / (float)(ry - t);
			float ki = 1.0f - di * di;

			if (ki > 0.0f)
				hi = (float)(rx - t) * sqrtf(ki);
		}
		if (t == 0 || hi <= 0.0f) {
			span(s, y, cx - (int)ho, cx + (int)ho + 1, v);
		} else {
			span(s, y, cx - (int)ho, cx - (int)hi, v);
			span(s, y, cx + (int)hi + 1, cx + (int)ho + 1, v);
		}
	}
	finish(s, i);
	return 0;
}

/* ---- painting: brush, line, stroke, fade ----------------------------------- */
void dz_draw_set_blend(int i, int mode)
{
	surf_t *s = get(i);

	if (s && mode >= DZ_BLEND_NORMAL && mode <= DZ_BLEND_MULTIPLY)
		s->blend = mode;
}

/*
 * Soft round stamp. Full coverage inside radius*hardness, then a linear
 * falloff to 0 at radius. hardness 1 = hard edge. No present.
 */
static void stamp(surf_t *s, uint32_t v, float cx, float cy, float r, float hard)
{
	int x0 = (int)floorf(cx - r), x1 = (int)ceilf(cx + r);
	int y0 = (int)floorf(cy - r), y1 = (int)ceilf(cy + r);
	float ri, edge;

	if (r < 0.5f)
		r = 0.5f;
	hard = hard < 0.0f ? 0.0f : (hard > 1.0f ? 1.0f : hard);
	ri = r * hard;
	edge = r - ri > 0.5f ? r - ri : 0.5f;	/* at least half a pixel of AA */
	if (x0 < 0) x0 = 0;
	if (y0 < 0) y0 = 0;
	if (x1 > s->w - 1) x1 = s->w - 1;
	if (y1 > s->h - 1) y1 = s->h - 1;
	for (int y = y0; y <= y1; y++) {
		uint32_t *row = s->shadow + (size_t)y * s->w;
		float dy = (float)y - cy;

		for (int x = x0; x <= x1; x++) {
			float dx = (float)x - cx, d = sqrtf(dx * dx + dy * dy);
			unsigned cov;

			if (d >= r)
				continue;
			cov = d <= ri ? 256u : (unsigned)(256.0f * (r - d) / edge);
			if (cov > 256)
				cov = 256;
			put(s, &row[x], v, cov);
		}
	}
	if (x1 >= x0 && y1 >= y0)
		dirty(s, x0, y0, x1 + 1, y1 + 1);
}

/* stamps from (x0,y0) to (x1,y1); the first point is skipped when skip0 */
static void stamp_line(surf_t *s, uint32_t v, float x0, float y0, float x1, float y1,
		       float r, float hard, int skip0)
{
	float dx = x1 - x0, dy = y1 - y0, len = sqrtf(dx * dx + dy * dy);
	float step = r / 3.0f > 1.0f ? r / 3.0f : 1.0f;	/* overlap: no gaps */
	int n = (int)(len / step);

	for (int k = skip0 ? 1 : 0; k <= n; k++) {
		float t = n ? (float)k / (float)n : 0.0f;

		stamp(s, v, x0 + dx * t, y0 + dy * t, r, hard);
	}
}

int dz_draw_brush(int i, dz_color c, int x, int y, int radius, float hardness)
{
	surf_t *s = get(i);

	if (!s || radius <= 0)
		return -1;
	dz_draw_movie_stop(i);
	stamp(s, pack(c), (float)x, (float)y, (float)radius, hardness);
	finish(s, i);
	return 0;
}

int dz_draw_line(int i, dz_color c, int x0, int y0, int x1, int y1, int width)
{
	surf_t *s = get(i);
	uint32_t v;

	if (!s)
		return -1;
	dz_draw_movie_stop(i);
	v = pack(c);
	if (width <= 1) {	/* 1 px Bresenham */
		int dx = abs(x1 - x0), sx = x0 < x1 ? 1 : -1;
		int dy = -abs(y1 - y0), sy = y0 < y1 ? 1 : -1, err = dx + dy;

		for (;;) {
			if (x0 >= 0 && x0 < s->w && y0 >= 0 && y0 < s->h) {
				put(s, &s->shadow[(size_t)y0 * s->w + x0], v, 256);
				dirty(s, x0, y0, x0 + 1, y0 + 1);
			}
			if (x0 == x1 && y0 == y1)
				break;
			int e2 = 2 * err;

			if (e2 >= dy) { err += dy; x0 += sx; }
			if (e2 <= dx) { err += dx; y0 += sy; }
		}
	} else {
		stamp_line(s, v, (float)x0, (float)y0, (float)x1, (float)y1,
			   (float)width / 2.0f, 1.0f, 0);
	}
	finish(s, i);
	return 0;
}

int dz_draw_stroke(int i, dz_color c, int radius, float hardness, const int *xy, int npts)
{
	surf_t *s = get(i);
	uint32_t v;

	if (!s || radius <= 0 || npts < 1)
		return -1;
	dz_draw_movie_stop(i);
	v = pack(c);
	stamp(s, v, (float)xy[0], (float)xy[1], (float)radius, hardness);
	for (int k = 1; k < npts; k++)
		stamp_line(s, v, (float)xy[2 * k - 2], (float)xy[2 * k - 1],
			   (float)xy[2 * k], (float)xy[2 * k + 1], (float)radius, hardness, 1);
	finish(s, i);
	return 0;
}

/*
 * Every byte: d + (((t - d) * a) >> 7), a = 0..128 (t = target byte, alpha
 * byte included). NEON does 16 bytes per step; the C loop uses the same
 * formula, so both give the same result.
 */
static void fade_buf(uint8_t *p, size_t len, uint32_t target, unsigned a)
{
	uint8_t tb[4] = { (uint8_t)target, (uint8_t)(target >> 8),
			  (uint8_t)(target >> 16), (uint8_t)(target >> 24) };
	size_t k = 0;

#if defined(__ARM_NEON)
	{
		uint8_t pat[16];
		int16x8_t tlo, thi, av = vdupq_n_s16((int16_t)a);

		for (int j = 0; j < 16; j++)
			pat[j] = tb[j & 3];
		tlo = vreinterpretq_s16_u16(vmovl_u8(vld1_u8(pat)));
		thi = vreinterpretq_s16_u16(vmovl_u8(vld1_u8(pat + 8)));
		for (; k + 16 <= len; k += 16) {
			uint8x16_t d = vld1q_u8(p + k);
			int16x8_t dl = vreinterpretq_s16_u16(vmovl_u8(vget_low_u8(d)));
			int16x8_t dh = vreinterpretq_s16_u16(vmovl_u8(vget_high_u8(d)));

			dl = vaddq_s16(dl, vshrq_n_s16(vmulq_s16(vsubq_s16(tlo, dl), av), 7));
			dh = vaddq_s16(dh, vshrq_n_s16(vmulq_s16(vsubq_s16(thi, dh), av), 7));
			vst1q_u8(p + k, vcombine_u8(vqmovun_s16(dl), vqmovun_s16(dh)));
		}
	}
#endif
	for (; k < len; k++) {
		int d = p[k];

		p[k] = (uint8_t)(d + (((tb[k & 3] - d) * (int)a) >> 7));
	}
}

int dz_draw_fade(int i, float amount, dz_color to)
{
	surf_t *s = get(i);
	unsigned a;
	uint32_t t;

	if (!s)
		return -1;
	dz_draw_movie_stop(i);
	amount = amount < 0.0f ? 0.0f : (amount > 1.0f ? 1.0f : amount);
	a = (unsigned)(amount * 128.0f + 0.5f);	/* 7 bit: products fit in int16 */
	t = pack(to);
	if (s->autoflush) {
		/* fade + present in one pass: copy each row while it is in cache */
		size_t rowb = (size_t)s->w * 4;
		uint8_t *dev = dz_slot(i, (size_t)(s->h - 1) * s->stride + rowb, NULL);

		if (dz_draw_present(i) < 0 || !dev) {	/* flush pending work first */
			fails++;
			fade_buf((uint8_t *)s->shadow, rowb * s->h, t, a);
			dirty(s, 0, 0, s->w, s->h);
			return -1;
		}
		for (int y = 0; y < s->h; y++) {
			uint8_t *row = (uint8_t *)(s->shadow + (size_t)y * s->w);

			fade_buf(row, rowb, t, a);
			memcpy(dev + (size_t)y * s->stride, row, rowb);
		}
		__sync_synchronize();
		return 0;
	}
	fade_buf((uint8_t *)s->shadow, (size_t)s->w * s->h * 4, t, a);
	dirty(s, 0, 0, s->w, s->h);
	return 0;
}

/*
 * Copy the real content of slot src (live capture, a paused movie, ...) into
 * the painting buffer of surface i. The slot is uncached memory: this read is
 * slow (tens of ms) - use it to freeze a frame, not every frame.
 */
int dz_draw_grab(int i, int src)
{
	surf_t *s = get(i);
	const uint8_t *dev;

	if (!s || src < 0 || src >= DZ_SLOTS)
		return -1;
	dev = dz_slot(src, (size_t)(s->h - 1) * s->stride + (size_t)s->w * 4, NULL);
	if (!dev)
		return -1;
	for (int y = 0; y < s->h; y++) {
		uint32_t *row = s->shadow + (size_t)y * s->w;

		memcpy(row, dev + (size_t)y * s->stride, (size_t)s->w * 4);
		for (int x = 0; x < s->w; x++)
			row[x] |= 0xFF000000u;
	}
	dz_draw_movie_stop(i);		/* after the copy: freezes a playing movie */
	if (src != i) {
		dirty(s, 0, 0, s->w, s->h);
		finish(s, i);
	}
	return 0;
}

int dz_draw_peek(int i, int x, int y, dz_color *c)
{
	surf_t *s = get(i);
	uint32_t v;

	if (!s || x < 0 || y < 0 || x >= s->w || y >= s->h)
		return -1;
	v = s->shadow[(size_t)y * s->w + x];
	*c = DZ_RGB8(v >> 16, v >> 8, v);
	return 0;
}

/* ---- internal interface for dz_sprite.c, dz_xform.c, dz_text.c ------------- */
uint32_t *dz_surf(int i, int *w, int *h)
{
	surf_t *s = get(i);

	if (!s)
		return NULL;
	dz_draw_movie_stop(i);
	*w = s->w;
	*h = s->h;
	return s->shadow;
}

void dz_surf_put(int i, uint32_t *p, uint32_t v, unsigned cov)
{
	surf_t *s = get(i);

	if (s)
		put(s, p, v, cov);
}

void dz_surf_dirty(int i, int x0, int y0, int x1, int y1)
{
	surf_t *s = get(i);

	if (!s)
		return;
	x0 = x0 < 0 ? 0 : x0;
	y0 = y0 < 0 ? 0 : y0;
	x1 = x1 > s->w ? s->w : x1;
	y1 = y1 > s->h ? s->h : y1;
	if (x1 > x0 && y1 > y0)
		dirty(s, x0, y0, x1, y1);
}

void dz_surf_finish(int i)
{
	surf_t *s = get(i);

	if (s)
		finish(s, i);
}

uint32_t *dz_surf_swap(int i, uint32_t *buf)
{
	surf_t *s = get(i);
	uint32_t *old;

	if (!s || !buf)
		return NULL;
	old = s->shadow;
	s->shadow = buf;
	return old;
}

uint8_t *dz_surf_dev(int i, size_t *stride)
{
	surf_t *s = get(i);

	if (!s || !s->autoflush || dz_draw_present(i) < 0)
		return NULL;
	*stride = s->stride;
	return dz_slot(i, (size_t)(s->h - 1) * s->stride + (size_t)s->w * 4, NULL);
}

void dz_surf_clean(int i)
{
	surf_t *s = get(i);

	if (s)
		s->dx0 = s->dy0 = s->dx1 = s->dy1 = 0;
}

int dz_surf_plain(int i)
{
	surf_t *s = get(i);

	return s && s->alpha >= 256 && s->blend == DZ_BLEND_NORMAL;
}

void dz_surf_fail(void)
{
	fails++;
}

/* ---- files ------------------------------------------------------------------ */
/* Only a plain file name: this runs on a network port. */
static int name_ok(const char *n)
{
	if (!n || !*n || *n == '.' || strlen(n) > 96 || strstr(n, ".."))
		return 0;
	for (const char *p = n; *p; p++)
		if (!((*p >= 'a' && *p <= 'z') || (*p >= 'A' && *p <= 'Z') ||
		      (*p >= '0' && *p <= '9') || *p == '.' || *p == '_' ||
		      *p == '-'))
			return 0;
	return 1;
}

int dz_draw_image(int i, const char *name, dz_rect r)
{
	surf_t *s = get(i);
	char cmd[512];
	uint32_t *line;
	FILE *fp;
	int rows = 0;

	if (!s || !name_ok(name) || !clip(s, &r))
		return -1;
	dz_draw_movie_stop(i);
	snprintf(cmd, sizeof(cmd),
		 "ffmpeg -nostdin -hide_banner -loglevel error -i '%s/%s' -frames:v 1 "
		 "-vf scale=%d:%d -pix_fmt bgra -f rawvideo pipe:1",
		 DZ_IMG_DIR, name, r.w, r.h);
	fp = popen(cmd, "r");
	if (!fp)
		return -1;
	line = malloc((size_t)r.w * 4);
	if (!line) {
		pclose(fp);
		return -1;
	}
	for (int y = 0; y < r.h; y++) {
		uint32_t *row = s->shadow + (size_t)(r.y + y) * s->w + r.x;

		if (fread(line, 4, (size_t)r.w, fp) != (size_t)r.w)
			break;
		for (int x = 0; x < r.w; x++)
			put(s, &row[x], line[x] | 0xFF000000u, 256);
		rows++;
	}
	free(line);
	pclose(fp);
	if (!rows)
		return -1;
	dirty(s, r.x, r.y, r.x + r.w, r.y + rows);
	finish(s, i);
	return 0;
}

int dz_draw_movie_running(int i)
{
	surf_t *s = (i >= 0 && i < DZ_SLOTS) ? &surf[i] : NULL;

	if (s && s->aplayer > 0 && waitpid(s->aplayer, NULL, WNOHANG) == s->aplayer)
		s->aplayer = 0;
	if (!s || s->player <= 0)
		return 0;
	if (waitpid(s->player, NULL, WNOHANG) == s->player) {
		s->player = 0;
		return 0;
	}
	return 1;
}

int dz_draw_movie_stop(int i)
{
	surf_t *s = (i >= 0 && i < DZ_SLOTS) ? &surf[i] : NULL;

	if (s && s->aplayer > 0) {
		kill(-s->aplayer, SIGKILL);	/* at once: no ALSA buffer play-out */
		waitpid(s->aplayer, NULL, 0);
		s->aplayer = 0;
	}
	if (!s || s->player <= 0)
		return 0;
	kill(-s->player, SIGTERM);
	waitpid(s->player, NULL, 0);
	s->player = 0;
	return 1;
}

int dz_draw_movie_play(int i, const char *name)
{
	return dz_draw_movie_play_fps(i, name, 0.0f);
}

int dz_draw_movie_play_fps(int i, const char *name, float fps)
{
	return dz_draw_movie_play_av(i, name, fps, 0);
}

/* the movie's audio track to ALSA card DEBAZ (2026-10-28): bit 0 = HDMI 0
 * (PCM 0), bit 1 = HDMI 1 (PCM 1), bit 2 = I2S (PCM 3). Several bits = the
 * same audio on several PCMs; the route controls choose what each output
 * plays (a swap = route changes only).
 * The audio is a SECOND ffmpeg (same file, -re, same start, same loop) at
 * SCHED_FIFO 20: in one ffmpeg the audio waited for every video frame, and
 * with two movies + uploads (8 fps) it broke up (PCM in XRUN, 2026-10-28).
 * Now the sound stays smooth; on an overloaded CPU the picture falls behind
 * instead. A file without audio: the shell checks for an audio stream
 * (ffprobe) and exits, so this call does not wait. */
int dz_draw_movie_play_av(int i, const char *name, float fps, int audio)
{
	surf_t *s = get(i);
	char cmd[900], path[256], dst[96], cap[32] = "", aud[400] = "";
	static const int pcm_of[3] = { 0, 1, 3 };
	pid_t pid;

	if (!s || !name_ok(name))
		return -1;
	dz_draw_movie_stop(i);
	snprintf(path, sizeof(path), "%s/%s", DZ_MOVIE_DIR, name);
	if (access(path, R_OK) != 0) {
		fprintf(stderr, "dz_draw: no such movie %s\n", path);
		return -1;
	}
	if (!dz_reserved(DZ_SLOT_ADDR(i), (uint32_t)(s->stride * s->h))) {
		fprintf(stderr, "dz_draw: slot %d is outside reserved memory - refused\n", i);
		return -1;
	}
	if (dz_map_simulating())
		return 0;
	/*
	 * ffmpeg decodes to yuv420p and fbfeed -y converts with NEON: ffmpeg's
	 * own yuv420p -> bgra path is slow on ARM (measured 2026-10-24, two 720p
	 * movies at once: 7 fps each with bgra, 12.5 fps each with this).
	 * slot 0 lies inside /dev/fb0: use its write-combined mapping.
	 */
	if (i == DZ_SLOT_FB0)
		snprintf(dst, sizeof(dst), "-d /dev/fb0 -o 0");
	else
		snprintf(dst, sizeof(dst), "-a 0x%08X", (unsigned)DZ_SLOT_ADDR(i));
	/* frame-rate cap before the scaler: a dropped frame costs no scaling,
	 * pipe copy or conversion (DDR traffic at 1080p60, CLAUDE.md) */
	if (fps > 0.0f && fps <= 120.0f)
		snprintf(cap, sizeof(cap), "fps=%.3f,", fps);
	for (int k = 0; k < 3; k++)
		if (audio & (1 << k))
			snprintf(aud + strlen(aud), sizeof(aud) - strlen(aud),
				 " -map 0:a:0 -ac 2 -ar 48000 -f alsa hw:DEBAZ,%d", pcm_of[k]);
	if (aud[0]) {
		char acmd[900];

		snprintf(acmd, sizeof(acmd),
			 "ffprobe -v error -select_streams a:0 -show_entries stream=index "
			 "-of csv=p=0 '%s' | grep -q . || exit 0; "
			 "exec ffmpeg -nostdin -hide_banner -loglevel error -stream_loop -1 -re "
			 "-i '%s'%s", path, path, aud);
		pid = fork();
		if (pid == 0) {
			struct sched_param sp = { .sched_priority = 20 };

			setsid();
			sched_setscheduler(0, SCHED_FIFO, &sp);	/* inherited by ffmpeg */
			execl("/bin/sh", "sh", "-c", acmd, (char *)NULL);
			_exit(127);
		}
		s->aplayer = pid > 0 ? pid : 0;
	}
	snprintf(cmd, sizeof(cmd),
		 "exec ffmpeg -nostdin -hide_banner -loglevel error -stream_loop -1 -re "
		 "-i '%s' -map 0:v:0 -vf %sscale=%d:%d:flags=fast_bilinear -pix_fmt yuv420p "
		 "-f rawvideo pipe:1 "
		 "| %s -y %s -w %d -h %d -s %u%s",
		 path, cap, s->w, s->h, DZ_FBFEED, dst, s->w, s->h, (unsigned)s->stride,
		 movie_verbose ? " -v" : "");
	pid = fork();
	if (pid < 0)
		return -1;
	if (pid == 0) {
		setsid();	/* own process group: stop kills the whole pipe */
		execl("/bin/sh", "sh", "-c", cmd, (char *)NULL);
		_exit(127);
	}
	s->player = pid;
	return 0;
}

/* PPM, written at once (debugging; also what older versions wrote) */
static int save_ppm(surf_t *s, const char *name)
{
	char path[256];
	FILE *fp;

	snprintf(path, sizeof(path), "%s/%.96s", DZ_IMG_DIR, name);	/* name_ok: <= 96 */
	fp = fopen(path, "wb");
	if (!fp)
		return -1;
	fprintf(fp, "P6\n%d %d\n255\n", s->w, s->h);
	for (size_t k = 0; k < (size_t)s->w * s->h; k++) {
		uint32_t v = s->shadow[k];
		uint8_t px[3] = { (uint8_t)(v >> 16), (uint8_t)(v >> 8), (uint8_t)v };

		fwrite(px, 1, 3, fp);
	}
	fclose(fp);
	return 0;
}

/*
 * PNG: copy the shadow to a raw file in /tmp (fast), then a background
 * ffmpeg encodes it (about 1 s for 720p on the A9) to ".<name>.png" - hidden
 * from the media list while it grows - and renames it to "<name>.png". The
 * OSC loop does not wait. Double fork: no zombie, no SIGCHLD handler needed.
 */
static int save_png(surf_t *s, const char *base)
{
	static unsigned seq;
	char raw[96], cmd[768];
	FILE *fp;
	pid_t pid;
	size_t n = (size_t)s->w * s->h;

	snprintf(raw, sizeof(raw), "/tmp/dz_save_%d_%u.raw", (int)getpid(), seq++);
	fp = fopen(raw, "wb");
	if (!fp)
		return -1;
	if (fwrite(s->shadow, 4, n, fp) != n) {	/* 0x..RRGGBB = bgr0 bytes */
		fclose(fp);
		unlink(raw);
		return -1;
	}
	fclose(fp);
	snprintf(cmd, sizeof(cmd),
		 "ffmpeg -nostdin -hide_banner -loglevel error -y -f rawvideo -pix_fmt bgr0 "
		 "-s %dx%d -i '%s' -frames:v 1 -pix_fmt rgb24 '%s/.%s.png' && "
		 "mv -f '%s/.%s.png' '%s/%s.png'; rm -f '%s'",
		 s->w, s->h, raw, DZ_IMG_DIR, base, DZ_IMG_DIR, base, DZ_IMG_DIR, base, raw);
	pid = fork();
	if (pid < 0) {
		unlink(raw);
		return -1;
	}
	if (pid == 0) {
		if (fork() == 0) {
			setsid();
			execl("/bin/sh", "sh", "-c", cmd, (char *)NULL);
			_exit(127);
		}
		_exit(0);
	}
	waitpid(pid, NULL, 0);
	return 0;
}

int dz_draw_save(int i, const char *name)
{
	surf_t *s = get(i);
	char base[100];
	size_t l;

	if (!s || !name_ok(name))
		return -1;
	l = strlen(name);
	if (l > 4 && !strcmp(name + l - 4, ".ppm"))
		return save_ppm(s, name);
	snprintf(base, sizeof(base), "%.96s", name);
	if (l > 4 && !strcmp(base + l - 4, ".png"))
		base[l - 4] = 0;
	return save_png(s, base);
}

/* ---- OSC ------------------------------------------------------------------- */
static uint8_t comp(const dz_arg *a)
{
	if (a->type == 'f')
		return a->f <= 0.0f ? 0 : a->f >= 1.0f ? 255 : (uint8_t)(a->f * 255.0f + 0.5f);
	return a->i <= 0 ? 0 : a->i >= 255 ? 255 : (uint8_t)a->i;
}

static dz_color col(const dz_arg *a, int k)
{
	return DZ_RGB8(comp(&a[k]), comp(&a[k + 1]), comp(&a[k + 2]));
}

static dz_rect rect_at(const dz_arg *a, int n, int k)
{
	dz_rect r = DZ_ALL;

	if (n >= k + 4) {
		r.x = a[k].i; r.y = a[k + 1].i; r.w = a[k + 2].i; r.h = a[k + 3].i;
	}
	return r;
}

/* a plain number: float or int as is */
static float argn(const dz_arg *a)
{
	return a->type == 'f' ? a->f : (float)a->i;
}

/* float 0..1: a float as is, an int as 0..255 */
static float argf(const dz_arg *a)
{
	return a->type == 'f' ? a->f : (float)a->i / 255.0f;
}

static int blend_of(const dz_arg *a)
{
	static const char *names[] = { "normal", "add", "lighten", "multiply" };

	if (a->type == 's') {
		for (int k = 0; k < 4; k++)
			if (!strcmp(a->s, names[k]))
				return k;
		return -1;
	}
	return a->i;
}

/* "/draw/2/solid" -> slot mask, tail "solid" */
static int split(const char *path, const char *group, unsigned *mask, const char **tail)
{
	size_t gl = strlen(group);
	const char *p, *q;
	int v = 0, any = 0;

	if (path[0] != '/' || strncmp(path + 1, group, gl) || path[1 + gl] != '/')
		return 0;
	p = path + 2 + gl;
	q = strchr(p, '/');
	if (*p == '*') {
		*mask = (1u << DZ_SLOTS) - 1u;
	} else {
		for (const char *c = p; c != q && *c; c++) {
			if (*c < '0' || *c > '9')
				return 0;
			v = v * 10 + (*c - '0');
			any = 1;
		}
		if (!any || v >= DZ_SLOTS)
			return 0;
		*mask = 1u << v;
	}
	*tail = q ? q + 1 : "";
	return 1;
}

#define NI(k) ((int)argn(&a[k]))

/* rect/square: x y w h [thickness] [angle]; k = index of thickness */
static int op_rect(int i, const dz_arg *a, int n, float w, float h, int k)
{
	int t = n > k ? NI(k) : 0;
	float ang = n > k + 1 ? argn(&a[k + 1]) : 0.0f;

	if (ang == 0.0f && !dz_shape_fancy(i))	/* the old exact pixels */
		return dz_draw_rect(i, col(a, 0), (dz_rect){ NI(3), NI(4), (int)w, (int)h }, t);
	return dz_shape_rect(i, col(a, 0), argn(&a[3]), argn(&a[4]), w, h, t, ang);
}

/* circle/ellipse: cx cy rx ry [thickness] [angle] */
static int op_ellipse(int i, const dz_arg *a, int n, float rx, float ry, int k)
{
	int t = n > k ? NI(k) : 0;
	float ang = n > k + 1 ? argn(&a[k + 1]) : 0.0f;

	if (ang == 0.0f && !dz_shape_fancy(i))
		return dz_draw_ellipse(i, col(a, 0), NI(3), NI(4), (int)rx, (int)ry, t);
	return dz_shape_ellipse(i, col(a, 0), argn(&a[3]), argn(&a[4]), rx, ry, t, ang);
}

/* fill solid | linear r2 g2 b2 [deg] | radial r2 g2 b2   (or mode 0/1/2) */
static int op_fill(int i, const dz_arg *a, int n)
{
	int mode = -1;

	if (a[0].type == 's')
		mode = !strcmp(a[0].s, "solid") ? DZ_FILL_SOLID :
		       !strcmp(a[0].s, "linear") ? DZ_FILL_LINEAR :
		       !strcmp(a[0].s, "radial") ? DZ_FILL_RADIAL : -1;
	else
		mode = a[0].i;
	if (mode < DZ_FILL_SOLID || mode > DZ_FILL_RADIAL || (mode != DZ_FILL_SOLID && n < 4))
		return -1;
	dz_shape_fill(i, mode, mode == DZ_FILL_SOLID ? DZ_RGB8(0, 0, 0) : col(a, 1),
		      n >= 5 ? argn(&a[4]) : 0.0f);
	return 0;
}

int dz_draw_dispatch(const dz_msg *m, int verbose)
{
	movie_verbose = verbose;
	const dz_arg *a = m->a;
	const char *op = "";
	unsigned mask = 0;
	int n = m->n, hits = 0;

	if (split(m->path, "draw", &mask, &op)) {
		for (int i = 0; i < DZ_SLOTS; i++) {
			int rc;

			if (!(mask & (1u << i)))
				continue;
			if (!strcmp(op, "solid") && n >= 3)
				rc = dz_draw_solid(i, col(a, 0), rect_at(a, n, 3));
			else if (!strcmp(op, "clear"))
				rc = dz_draw_solid(i, n >= 3 ? col(a, 0) : DZ_RGB8(0, 0, 0), DZ_ALL);
			else if (!strcmp(op, "bars"))
				rc = dz_draw_bars(i);
			else if (!strcmp(op, "gradient/h") && n >= 6)
				rc = dz_draw_gradient(i, col(a, 0), col(a, 3), 0.0f, rect_at(a, n, 6));
			else if (!strcmp(op, "gradient/v") && n >= 6)
				rc = dz_draw_gradient(i, col(a, 0), col(a, 3), 90.0f, rect_at(a, n, 6));
			else if (!strcmp(op, "gradient/angle") && n >= 7)
				rc = dz_draw_gradient(i, col(a, 1), col(a, 4), argn(&a[0]), rect_at(a, n, 7));
			else if (!strcmp(op, "gradient/corners") && n >= 12)
				rc = dz_draw_corners(i, col(a, 0), col(a, 3), col(a, 6), col(a, 9),
						     rect_at(a, n, 12));
			else if (!strcmp(op, "rect") && n >= 7)
				rc = op_rect(i, a, n, argn(&a[5]), argn(&a[6]), 7);
			else if (!strcmp(op, "square") && n >= 6)
				rc = op_rect(i, a, n, argn(&a[5]), argn(&a[5]), 6);
			else if (!strcmp(op, "circle") && n >= 6)
				rc = op_ellipse(i, a, n, argn(&a[5]), argn(&a[5]), 6);
			else if (!strcmp(op, "ellipse") && n >= 7)
				rc = op_ellipse(i, a, n, argn(&a[5]), argn(&a[6]), 7);
			else if (!strcmp(op, "polygon") && n >= 8)
				rc = dz_shape_polygon(i, col(a, 0), argn(&a[3]), argn(&a[4]), argn(&a[5]),
						      argn(&a[6]), NI(7), n >= 9 ? NI(8) : 0,
						      n >= 10 ? argn(&a[9]) : 0.0f);
			else if (!strcmp(op, "star") && n >= 8)
				rc = dz_shape_star(i, col(a, 0), argn(&a[3]), argn(&a[4]), argn(&a[5]),
						   argn(&a[6]), NI(7), n >= 9 ? argn(&a[8]) : 0.0f,
						   n >= 10 ? NI(9) : 0, n >= 11 ? argn(&a[10]) : 0.0f);
			else if (!strcmp(op, "starpoly") && n >= 9)
				rc = dz_shape_starpoly(i, col(a, 0), argn(&a[3]), argn(&a[4]), argn(&a[5]),
						       argn(&a[6]), NI(7), NI(8), n >= 10 ? NI(9) : 0,
						       n >= 11 ? argn(&a[10]) : 0.0f);
			else if (!strcmp(op, "gradient/radial") && n >= 6)
				rc = dz_shape_radial(i, col(a, 0), col(a, 3),
						     n >= 8 ? argn(&a[6]) : dz_geom_w() / 2.0f,
						     n >= 8 ? argn(&a[7]) : dz_geom_h() / 2.0f,
						     n >= 9 ? argn(&a[8]) : 0.0f);
			else if (!strcmp(op, "fill") && n >= 1) {
				rc = op_fill(i, a, n);
			} else if (!strcmp(op, "text") && n >= 6 && a[5].type == 's')
				rc = dz_text_draw(i, col(a, 0), a[3].i, a[4].i, a[5].s,
						  n >= 7 ? a[6].i : 1, n >= 8 ? a[7].i : 16);
			else if (!strcmp(op, "ttf") && n >= 7 && a[6].type == 's')
				rc = dz_ttf_draw(i, col(a, 0), a[3].i, a[4].i, argn(&a[5]), a[6].s,
						 n >= 8 && a[7].type == 's' ? a[7].s : NULL);
			else if (!strcmp(op, "transform") && n >= 6) {
				float mm[6];

				for (int k = 0; k < 6; k++)
					mm[k] = argn(&a[k]);
				rc = dz_xform_affine(i, n >= 7 ? a[6].i : -1, mm);
			} else if (!strcmp(op, "rotozoom") && n >= 2)
				rc = dz_xform_rotozoom(i, n >= 5 ? a[4].i : -1, argn(&a[0]), argn(&a[1]),
						       n >= 4 ? argn(&a[2]) : dz_geom_w() / 2.0f,
						       n >= 4 ? argn(&a[3]) : dz_geom_h() / 2.0f);
			else if (!strcmp(op, "scroll") && n >= 2)
				rc = dz_xform_scroll(i, n >= 3 ? a[2].i : -1, a[0].i, a[1].i);
			else if (!strcmp(op, "mirror") && n >= 1)
				rc = dz_xform_mirror(i, a[0].type == 's'
						     ? (!strcmp(a[0].s, "v") ? 1 : !strcmp(a[0].s, "quad") ? 2 : 0)
						     : a[0].i);
			else if (!strcmp(op, "wave") && n >= 4)
				rc = dz_xform_wave(i, n >= 5 ? a[4].i : -1, a[0].i, argn(&a[1]),
						   argn(&a[2]), argn(&a[3]));
			else if (!strcmp(op, "line") && n >= 7)
				rc = dz_draw_line(i, col(a, 0), a[3].i, a[4].i, a[5].i, a[6].i,
						  n >= 8 ? a[7].i : 1);
			else if (!strcmp(op, "brush") && n >= 6)
				rc = dz_draw_brush(i, col(a, 0), a[3].i, a[4].i, a[5].i,
						   n >= 7 ? argf(&a[6]) : 0.5f);
			else if (!strcmp(op, "stroke") && n >= 7 && (n - 5) % 2 == 0) {
				int xy[2 * DZ_OSC_MAX_ARGS];

				for (int k = 5; k < n; k++)
					xy[k - 5] = a[k].i;
				rc = dz_draw_stroke(i, col(a, 0), a[3].i, argf(&a[4]), xy, (n - 5) / 2);
			} else if (!strcmp(op, "fade") && n >= 1)
				rc = dz_draw_fade(i, argf(&a[0]) , n >= 4 ? col(a, 1) : DZ_RGB8(0, 0, 0));
			else if (!strcmp(op, "blend") && n >= 1) {
				dz_draw_set_blend(i, blend_of(&a[0]));
				rc = 0;
			} else if (!strcmp(op, "alpha") && n >= 1) {
				dz_draw_set_alpha(i, a[0].type == 'f' ? a[0].f : (float)a[0].i);
				rc = 0;
			} else
				continue;
			hits++;
			if (rc)
				fails++;
			if (verbose)
				fprintf(stderr, "dz_draw: slot %d %s%s\n", i, op, rc ? " FAILED" : "");
		}
		return hits;
	}
	if (split(m->path, "img", &mask, &op)) {
		for (int i = 0; i < DZ_SLOTS; i++)
			if ((mask & (1u << i)) && !strcmp(op, "load") && n >= 1 && a[0].type == 's') {
				int rc = dz_draw_image(i, a[0].s, rect_at(a, n, 1));

				hits++;
				if (rc)
					fails++;
				if (verbose)
					fprintf(stderr, "dz_draw: slot %d img %s%s\n", i, a[0].s,
						rc ? " FAILED" : "");
			}
		return hits;
	}
	if (split(m->path, "movie", &mask, &op)) {
		for (int i = 0; i < DZ_SLOTS; i++) {
			if (!(mask & (1u << i)))
				continue;
			if (!strcmp(op, "play") && n >= 1 && a[0].type == 's') {
				float fps = n >= 2 ? (a[1].type == 'f' ? a[1].f :
						      a[1].type == 'i' ? (float)a[1].i : 0.0f) : 0.0f;
				int au = n >= 3 ? (a[2].type == 'f' ? (int)a[2].f :
						      a[2].type == 'i' ? a[2].i : 0) : 0;
				int rc = dz_draw_movie_play_av(i, a[0].s, fps, au & 7);

				if (rc)
					fails++;
				if (verbose)
					fprintf(stderr, "dz_draw: slot %d movie %s%s\n", i, a[0].s,
						rc ? " FAILED" : "");
				hits++;
			} else if (!strcmp(op, "stop")) {
				dz_draw_movie_stop(i);
				hits++;
			}
		}
		return hits;
	}
	if (split(m->path, "surface", &mask, &op)) {
		for (int i = 0; i < DZ_SLOTS; i++) {
			if (!(mask & (1u << i)))
				continue;
			if (!strcmp(op, "present")) {
				if (dz_draw_present_all(i) < 0)
					fails++;
			}
			else if (!strcmp(op, "auto") && n >= 1)
				dz_draw_set_auto(i, a[0].i);
			else if (!strcmp(op, "save") && n >= 1 && a[0].type == 's') {
				if (dz_draw_save(i, a[0].s) < 0)
					fails++;
			}
			else if (!strcmp(op, "grab")) {
				if (dz_draw_grab(i, n >= 1 && a[0].type != 's' ? a[0].i : i) < 0)
					fails++;
			}
			else
				continue;
			hits++;
		}
		return hits;
	}
	return 0;
}

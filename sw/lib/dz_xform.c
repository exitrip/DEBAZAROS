/*
 * dz_xform.c - see dz_xform.h. Nearest-neighbour sampling, 16.16 fixed point,
 * wrap-around kept by add/subtract (no division per pixel).
 */
#define _GNU_SOURCE
#include "dz_xform.h"
#include "dz_draw_int.h"

#include <math.h>
#include <stdlib.h>
#include <string.h>

static uint32_t *spare;			/* back buffer, w*h, swapped in */
static size_t    spare_n;

/*
 * A transform run. Plain surfaces (alpha 1, blend normal): read src, write
 * the spare buffer, present each row while it is in cache, then swap the
 * spare in - no copy of the source and no second pass for present.
 * Otherwise: blend into the target through dz_surf_put (needs a source copy
 * when src == dst).
 */
typedef struct {
	int             dst, w, h, plain;
	const uint32_t *src;
	uint32_t       *out;
	uint8_t        *dev;
	size_t          stride;
} xf_t;

static int ensure_spare(size_t n)
{
	if (spare_n >= n)
		return 0;
	free(spare);
	spare = malloc(n * 4);
	spare_n = spare ? n : 0;
	return spare ? 0 : -1;
}

static int xf_begin(xf_t *x, int dst, int src)
{
	int sw, sh;
	uint32_t *d = dz_surf(dst, &x->w, &x->h), *s;

	if (!d)
		return -1;
	s = (src < 0 || src == dst) ? d : dz_surf(src, &sw, &sh);
	if (!s || (s != d && (sw != x->w || sh != x->h)))
		return -1;
	if (ensure_spare((size_t)x->w * x->h) < 0)
		return -1;
	x->dst = dst;
	x->plain = dz_surf_plain(dst);
	if (x->plain) {
		x->src = s;
		x->out = spare;
		x->dev = dz_surf_dev(dst, &x->stride);
	} else {
		if (s == d) {			/* blending needs the old target too */
			memcpy(spare, d, (size_t)x->w * x->h * 4);
			s = spare;
		}
		x->src = s;
		x->out = d;
		x->dev = NULL;
	}
	return 0;
}

static void xf_put(xf_t *x, uint32_t *p, uint32_t v)
{
	if (x->plain)
		*p = v;
	else
		dz_surf_put(x->dst, p, v, 256);
}

static void xf_row(xf_t *x, int y)
{
	if (x->dev)
		memcpy(x->dev + (size_t)y * x->stride, x->out + (size_t)y * x->w,
		       (size_t)x->w * 4);
}

static void xf_end(xf_t *x)
{
	if (x->plain) {
		uint32_t *old = dz_surf_swap(x->dst, x->out);

		spare = old;			/* the old buffer is the next spare */
		if (x->dev) {
			__sync_synchronize();
			dz_surf_clean(x->dst);
			return;
		}
	}
	dz_surf_dirty(x->dst, 0, 0, x->w, x->h);
	dz_surf_finish(x->dst);
}

/* wrap a 16.16 value into [0, lim) where lim = size << 16 */
static int32_t wrap16(int64_t v, int32_t lim)
{
	v %= lim;
	return (int32_t)(v < 0 ? v + lim : v);
}

int dz_xform_affine(int dst, int src, const float m[6])
{
	xf_t x;

	if (xf_begin(&x, dst, src) < 0)
		return -1;
	{
		int w = x.w, h = x.h;
		int32_t W = w << 16, H = h << 16;
		int32_t du = wrap16((int64_t)(m[0] * 65536.0f), W);
		int32_t dv = wrap16((int64_t)(m[3] * 65536.0f), H);

		for (int y = 0; y < h; y++) {
			int32_t u = wrap16((int64_t)((m[1] * y + m[2]) * 65536.0f), W);
			int32_t v = wrap16((int64_t)((m[4] * y + m[5]) * 65536.0f), H);
			uint32_t *row = x.out + (size_t)y * w;

			for (int i = 0; i < w; i++) {
				xf_put(&x, &row[i], x.src[(size_t)(v >> 16) * w + (u >> 16)]);
				u += du;
				if (u >= W)
					u -= W;
				v += dv;
				if (v >= H)
					v -= H;
			}
			xf_row(&x, y);
		}
	}
	xf_end(&x);
	return 0;
}

int dz_xform_rotozoom(int dst, int src, float angle, float zoom, float cx, float cy)
{
	float ca, sa, m[6];

	if (zoom <= 0.0001f)
		return -1;
	ca = cosf(angle * (float)M_PI / 180.0f) / zoom;
	sa = sinf(angle * (float)M_PI / 180.0f) / zoom;
	/* target (x,y) -> source: rotate by -angle, scale 1/zoom, about (cx,cy) */
	m[0] = ca;  m[1] = sa;  m[2] = cx - ca * cx - sa * cy;
	m[3] = -sa; m[4] = ca;  m[5] = cy + sa * cx - ca * cy;
	return dz_xform_affine(dst, src, m);
}

int dz_xform_scroll(int dst, int src, int dx, int dy)
{
	xf_t x;
	int w, h;

	if (xf_begin(&x, dst, src) < 0)
		return -1;
	w = x.w;
	h = x.h;
	dx = ((dx % w) + w) % w;
	dy = ((dy % h) + h) % h;
	for (int y = 0; y < h; y++) {
		const uint32_t *sr = x.src + (size_t)((y - dy + h) % h) * w;
		uint32_t *dr = x.out + (size_t)y * w;

		if (x.plain) {			/* two memcpy per row */
			memcpy(dr + dx, sr, (size_t)(w - dx) * 4);
			memcpy(dr, sr + (w - dx), (size_t)dx * 4);
		} else {
			for (int i = 0; i < w; i++)
				xf_put(&x, &dr[(i + dx) % w], sr[i]);
		}
		xf_row(&x, y);
	}
	xf_end(&x);
	return 0;
}

int dz_xform_mirror(int dst, int mode)
{
	xf_t x;
	int w, h, mh, mv;

	if (mode < 0 || mode > 2 || xf_begin(&x, dst, -1) < 0)
		return -1;
	w = x.w;
	h = x.h;
	mh = mode == 0 || mode == 2;		/* left half -> right half */
	mv = mode == 1 || mode == 2;		/* top half -> bottom half */
	for (int y = 0; y < h; y++) {
		const uint32_t *sr = x.src + (size_t)(mv && y >= h / 2 ? h - 1 - y : y) * w;
		uint32_t *dr = x.out + (size_t)y * w;

		if (x.plain) {
			memcpy(dr, sr, (size_t)(mh ? w / 2 : w) * 4);
			if (mh)
				for (int i = w / 2; i < w; i++)
					dr[i] = sr[w - 1 - i];
		} else {
			for (int i = 0; i < w; i++)
				xf_put(&x, &dr[i], sr[mh && i >= w / 2 ? w - 1 - i : i]);
		}
		xf_row(&x, y);
	}
	xf_end(&x);
	return 0;
}

int dz_xform_wave(int dst, int src, int axis, float amp, float period, float phase)
{
	xf_t x;
	int w, h;

	if (period <= 0.0f || xf_begin(&x, dst, src) < 0)
		return -1;
	w = x.w;
	h = x.h;
	if (axis == 0) {			/* row y shifts sideways */
		for (int y = 0; y < h; y++) {
			int sh = (int)lroundf(amp * sinf(2.0f * (float)M_PI *
							 ((float)y / period + phase)));
			const uint32_t *sr = x.src + (size_t)y * w;
			uint32_t *dr = x.out + (size_t)y * w;

			sh = ((sh % w) + w) % w;
			if (x.plain) {
				memcpy(dr + sh, sr, (size_t)(w - sh) * 4);
				memcpy(dr, sr + (w - sh), (size_t)sh * 4);
			} else {
				for (int i = 0; i < w; i++)
					xf_put(&x, &dr[(i + sh) % w], sr[i]);
			}
			xf_row(&x, y);
		}
	} else {				/* column x shifts up/down */
		int *shv = malloc((size_t)w * sizeof(int));

		if (!shv)
			return -1;
		for (int i = 0; i < w; i++) {
			int sh = (int)lroundf(amp * sinf(2.0f * (float)M_PI *
							 ((float)i / period + phase)));

			shv[i] = ((sh % h) + h) % h;
		}
		for (int y = 0; y < h; y++) {
			uint32_t *dr = x.out + (size_t)y * w;

			for (int i = 0; i < w; i++) {
				int sy = y - shv[i];

				xf_put(&x, &dr[i], x.src[(size_t)(sy < 0 ? sy + h : sy) * w + i]);
			}
			xf_row(&x, y);
		}
		free(shv);
	}
	xf_end(&x);
	return 0;
}

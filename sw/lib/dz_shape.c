/*
 * dz_shape.c - rotated and gradient-filled shapes (see dz_shape.h).
 *
 * Every shape becomes a set of closed loops (points in slot pixels). Filled
 * shapes fill the loops; outlines become one quad per edge plus a round
 * join at each corner, filled with the nonzero rule (union). One scanline
 * rasterizer does both: 4 sub-lines per pixel row, exact span ends in x, so
 * edges are antialiased. Colour per pixel comes from the slot's fill state.
 */
#include "dz_shape.h"
#include "dz_draw_int.h"
#include "dz_hw.h"

#include <math.h>
#include <stdlib.h>
#include <string.h>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

#define SUB	4		/* sub-lines per pixel row */
#define MAXE	16384		/* edges per shape */

typedef struct { int mode; dz_color c2; float deg; } fill_t;
static fill_t fills[DZ_SLOTS];

typedef struct { float x0, y0, x1, y1; int dir; } edge_t;	/* y0 < y1 */

typedef struct {		/* colour of a pixel */
	int      mode;
	uint32_t v;		/* solid */
	dz_color a, b;
	float    cx, cy, ca, sa, ihx, ihy, gc, gs, gn;
	uint32_t lut[257];	/* gradient colours, t = 0..1 in 256 steps */
} paint_t;

static edge_t E[MAXE];
static int    ne;

void dz_shape_fill(int s, int mode, dz_color c2, float degrees)
{
	if (s < 0 || s >= DZ_SLOTS || mode < DZ_FILL_SOLID || mode > DZ_FILL_RADIAL)
		return;
	fills[s].mode = mode;
	fills[s].c2 = c2;
	fills[s].deg = degrees;
}

int dz_shape_fancy(int s)
{
	return s >= 0 && s < DZ_SLOTS && fills[s].mode != DZ_FILL_SOLID;
}

static uint32_t pack(dz_color c)
{
	return 0xFF000000u | ((uint32_t)c.r << 16) | ((uint32_t)c.g << 8) | c.b;
}

/* ---- loops -> edges --------------------------------------------------------- */
static void edge(float x0, float y0, float x1, float y1)
{
	edge_t *e;

	if (y0 == y1 || ne >= MAXE)
		return;			/* horizontal edges never cross a sub-line */
	e = &E[ne++];
	if (y0 < y1) {
		*e = (edge_t){ x0, y0, x1, y1, 1 };
	} else {
		*e = (edge_t){ x1, y1, x0, y0, -1 };
	}
}

static void loop(const float *p, int n)	/* closed: n points */
{
	for (int k = 0; k < n; k++) {
		int j = (k + 1) % n;

		edge(p[2 * k], p[2 * k + 1], p[2 * j], p[2 * j + 1]);
	}
}

/* a loop with positive orientation (so overlapping parts add up, never cancel) */
static void loop_pos(float *p, int n)
{
	float area = 0.0f;

	for (int k = 0; k < n; k++) {
		int j = (k + 1) % n;

		area += p[2 * k] * p[2 * j + 1] - p[2 * j] * p[2 * k + 1];
	}
	if (area < 0.0f)		/* reverse */
		for (int k = 0; k < n / 2; k++) {
			float tx = p[2 * k], ty = p[2 * k + 1];

			p[2 * k] = p[2 * (n - 1 - k)];
			p[2 * k + 1] = p[2 * (n - 1 - k) + 1];
			p[2 * (n - 1 - k)] = tx;
			p[2 * (n - 1 - k) + 1] = ty;
		}
	loop(p, n);
}

static void disk(float cx, float cy, float r)
{
	float p[2 * 32];
	int n = r < 4.0f ? 8 : (r < 16.0f ? 16 : 32);

	for (int k = 0; k < n; k++) {
		float a = 2.0f * (float)M_PI * (float)k / (float)n;

		p[2 * k] = cx + r * cosf(a);
		p[2 * k + 1] = cy + r * sinf(a);
	}
	loop_pos(p, n);
}

/* outline of a closed loop: a quad per edge, a round join where it turns */
static void stroke(const float *p, int n, float w)
{
	float h = w / 2.0f;

	for (int k = 0; k < n; k++) {
		int j = (k + 1) % n, i = (k + n - 1) % n;
		float dx = p[2 * j] - p[2 * k], dy = p[2 * j + 1] - p[2 * k + 1];
		float len = sqrtf(dx * dx + dy * dy), q[8];

		if (len > 0.0f) {
			float nx = -dy / len * h, ny = dx / len * h;

			q[0] = p[2 * k] + nx; q[1] = p[2 * k + 1] + ny;
			q[2] = p[2 * j] + nx; q[3] = p[2 * j + 1] + ny;
			q[4] = p[2 * j] - nx; q[5] = p[2 * j + 1] - ny;
			q[6] = p[2 * k] - nx; q[7] = p[2 * k + 1] - ny;
			loop_pos(q, 4);
		}
		{			/* join at point k when the path turns */
			float ax = p[2 * k] - p[2 * i], ay = p[2 * k + 1] - p[2 * i + 1];
			float la = sqrtf(ax * ax + ay * ay);
			float c = (la > 0.0f && len > 0.0f) ? (ax * dx + ay * dy) / (la * len) : 0.0f;

			if (c < 0.985f && h >= 1.0f)	/* more than about 10 degrees */
				disk(p[2 * k], p[2 * k + 1], h);
		}
	}
}

/* ---- rasterizer ----------------------------------------------------------- */
static uint32_t colour(const paint_t *pt, int x, int y)
{
	float dx, dy, u, v, t;

	if (pt->mode == DZ_FILL_SOLID)
		return pt->v;
	dx = (float)x + 0.5f - pt->cx;
	dy = (float)y + 0.5f - pt->cy;
	u = (dx * pt->ca + dy * pt->sa) * pt->ihx;	/* shape frame, -1..1 */
	v = (-dx * pt->sa + dy * pt->ca) * pt->ihy;
	if (pt->mode == DZ_FILL_RADIAL)
		t = sqrtf(u * u + v * v);
	else
		t = ((u * pt->gc + v * pt->gs) / pt->gn + 1.0f) * 0.5f;
	t = t < 0.0f ? 0.0f : (t > 1.0f ? 1.0f : t);
	return pt->lut[(int)(t * 256.0f)];
}

/* crossings: (x, dir) pairs; few per line, so insertion sort */
static void sort_x(float *xs, int n)
{
	for (int k = 1; k < n; k++) {
		float x = xs[2 * k], d = xs[2 * k + 1];
		int j = k - 1;

		for (; j >= 0 && xs[2 * j] > x; j--) {
			xs[2 * j + 2] = xs[2 * j];
			xs[2 * j + 3] = xs[2 * j + 1];
		}
		xs[2 * j + 2] = x;
		xs[2 * j + 3] = d;
	}
}

static void add_span(int *acc, int w, float xa, float xb, int *lo, int *hi)
{
	int ia, ib;

	if (xa < 0.0f) xa = 0.0f;
	if (xb > (float)w) xb = (float)w;
	if (xb <= xa)
		return;
	ia = (int)xa;
	ib = (int)xb;
	if (ia < *lo) *lo = ia;
	if (ib > *hi) *hi = ib < w ? ib : w - 1;
	if (ia == ib) {
		acc[ia] += (int)((xb - xa) * (256 / SUB));
		return;
	}
	acc[ia] += (int)(((float)(ia + 1) - xa) * (256 / SUB));
	for (int x = ia + 1; x < ib; x++)
		acc[x] += 256 / SUB;
	if (ib < w)
		acc[ib] += (int)((xb - (float)ib) * (256 / SUB));
}

/* fill the collected edges; evenodd = 0: nonzero rule */
static int raster(int i, const paint_t *pt, int evenodd)
{
	static edge_t *act[MAXE];
	static float xs[2 * MAXE];	/* x, dir pairs */
	int W, H, y0, y1, bx0 = 1 << 30, bx1 = -1, plain;
	float fy0 = 1e9f, fy1 = -1e9f;
	uint32_t *buf = dz_surf(i, &W, &H);
	int *acc;

	if (!buf)
		return -1;
	if (!ne)
		return 0;
	for (int k = 0; k < ne; k++) {
		if (E[k].y0 < fy0) fy0 = E[k].y0;
		if (E[k].y1 > fy1) fy1 = E[k].y1;
	}
	y0 = fy0 < 0.0f ? 0 : (int)fy0;
	y1 = fy1 > (float)H ? H : (int)ceilf(fy1);
	acc = calloc((size_t)W, sizeof(int));
	if (!acc)
		return -1;
	plain = dz_surf_plain(i);	/* full coverage: write the pixel directly */
	for (int y = y0; y < y1; y++) {
		int na = 0, lo = W, hi = -1;

		for (int k = 0; k < ne; k++)	/* edges that touch this row */
			if (E[k].y1 > (float)y && E[k].y0 < (float)(y + 1))
				act[na++] = &E[k];
		for (int sl = 0; sl < SUB; sl++) {
			float sy = (float)y + ((float)sl + 0.5f) / SUB, xa = 0.0f;
			int nx = 0, wind = 0;

			for (int k = 0; k < na; k++) {
				const edge_t *e = act[k];

				if (sy < e->y0 || sy >= e->y1)
					continue;
				xs[2 * nx] = e->x0 + (sy - e->y0) * (e->x1 - e->x0) / (e->y1 - e->y0);
				xs[2 * nx + 1] = (float)e->dir;
				nx++;
			}
			sort_x(xs, nx);
			for (int k = 0; k < nx; k++) {
				int was = evenodd ? (wind & 1) : wind != 0, now;

				wind += (int)xs[2 * k + 1];
				now = evenodd ? (wind & 1) : wind != 0;
				if (!was && now)
					xa = xs[2 * k];
				else if (was && !now)
					add_span(acc, W, xa, xs[2 * k], &lo, &hi);
			}
		}
		if (hi < lo)
			continue;
		for (int x = lo; x <= hi; x++) {
			int cov = acc[x];

			acc[x] = 0;
			if (cov <= 0)
				continue;
			if (cov >= 256 && plain)
				buf[(size_t)y * W + x] = colour(pt, x, y);
			else
				dz_surf_put(i, &buf[(size_t)y * W + x], colour(pt, x, y),
					    (unsigned)(cov > 256 ? 256 : cov));
		}
		if (lo < bx0) bx0 = lo;
		if (hi > bx1) bx1 = hi;
	}
	free(acc);
	if (bx1 >= bx0)
		dz_surf_dirty(i, bx0, y0, bx1 + 1, y1);
	dz_surf_finish(i);
	return 0;
}

/* ---- shapes ----------------------------------------------------------------- */
static void paint_init(paint_t *pt, int i, dz_color c, float cx, float cy, float hx, float hy,
		       float angle)
{
	const fill_t *f = &fills[i];
	float r = angle * (float)M_PI / 180.0f, g = f->deg * (float)M_PI / 180.0f;

	pt->mode = f->mode;
	pt->v = pack(c);
	pt->a = c;
	pt->b = f->c2;
	pt->cx = cx;
	pt->cy = cy;
	pt->ca = cosf(r);
	pt->sa = sinf(r);
	pt->ihx = hx > 0.5f ? 1.0f / hx : 2.0f;
	pt->ihy = hy > 0.5f ? 1.0f / hy : 2.0f;
	pt->gc = cosf(g);
	pt->gs = sinf(g);
	pt->gn = fabsf(pt->gc) + fabsf(pt->gs);
	for (int k = 0; k <= 256; k++)
		pt->lut[k] = pack(DZ_RGB8(c.r + (f->c2.r - c.r) * k / 256,
					  c.g + (f->c2.g - c.g) * k / 256,
					  c.b + (f->c2.b - c.b) * k / 256));
}

/* rotate points (shape frame, about 0,0) by angle and move them to cx,cy */
static void place(float *p, int n, float cx, float cy, float angle)
{
	float r = angle * (float)M_PI / 180.0f, c = cosf(r), s = sinf(r);

	for (int k = 0; k < n; k++) {
		float x = p[2 * k], y = p[2 * k + 1];

		p[2 * k] = cx + x * c - y * s;
		p[2 * k + 1] = cy + x * s + y * c;
	}
}

static int ok_slot(int i)
{
	return i >= 0 && i < DZ_SLOTS;
}

/* outline inset: the stroke stays inside the shape size */
static float inset(float r, int t)
{
	r -= (float)t / 2.0f;
	return r < 0.5f ? 0.5f : r;
}

static int shape_loop(int i, dz_color c, float *p, int n, float cx, float cy, float hx,
		      float hy, int t, float angle, int evenodd)
{
	paint_t pt;

	place(p, n, cx, cy, angle);
	ne = 0;
	if (t > 0)
		stroke(p, n, (float)t);
	else
		loop(p, n);
	paint_init(&pt, i, c, cx, cy, hx, hy, angle);
	return raster(i, &pt, t > 0 ? 0 : evenodd);
}

int dz_shape_rect(int i, dz_color c, float x, float y, float w, float h, int t, float angle)
{
	float hx, hy, p[8];

	if (!ok_slot(i))
		return -1;
	if (w < 0) { x += w; w = -w; }
	if (h < 0) { y += h; h = -h; }
	hx = w / 2.0f;
	hy = h / 2.0f;
	{
		float ix = t > 0 ? inset(hx, t) : hx, iy = t > 0 ? inset(hy, t) : hy;

		p[0] = -ix; p[1] = -iy; p[2] = ix; p[3] = -iy;
		p[4] = ix;  p[5] = iy;  p[6] = -ix; p[7] = iy;
	}
	return shape_loop(i, c, p, 4, x + hx, y + hy, hx, hy, t, angle, 0);
}

int dz_shape_ellipse(int i, dz_color c, float cx, float cy, float rx, float ry, int t,
		     float angle)
{
	float *p, ix = t > 0 ? inset(rx, t) : rx, iy = t > 0 ? inset(ry, t) : ry;
	int n, rc;

	if (!ok_slot(i) || rx <= 0.0f || ry <= 0.0f)
		return -1;
	n = (int)(2.0f * (float)M_PI * (rx > ry ? rx : ry) / 4.0f);	/* about 4 px per side */
	n = n < 24 ? 24 : (n > 720 ? 720 : n);
	p = malloc(sizeof(float) * 2 * (size_t)n);
	if (!p)
		return -1;
	for (int k = 0; k < n; k++) {
		float a = 2.0f * (float)M_PI * (float)k / (float)n;

		p[2 * k] = ix * cosf(a);
		p[2 * k + 1] = iy * sinf(a);
	}
	rc = shape_loop(i, c, p, n, cx, cy, rx, ry, t, angle, 0);
	free(p);
	return rc;
}

/* point k of n on the ellipse rx,ry, first point at the top */
static void ring(float *x, float *y, int k, int n, float rx, float ry)
{
	float a = -(float)M_PI / 2.0f + 2.0f * (float)M_PI * (float)k / (float)n;

	*x = rx * cosf(a);
	*y = ry * sinf(a);
}

int dz_shape_polygon(int i, dz_color c, float cx, float cy, float rx, float ry, int sides,
		     int t, float angle)
{
	float p[2 * 256], ix = t > 0 ? inset(rx, t) : rx, iy = t > 0 ? inset(ry, t) : ry;

	if (!ok_slot(i) || sides < 3 || sides > 256 || rx <= 0.0f || ry <= 0.0f)
		return -1;
	for (int k = 0; k < sides; k++)
		ring(&p[2 * k], &p[2 * k + 1], k, sides, ix, iy);
	return shape_loop(i, c, p, sides, cx, cy, rx, ry, t, angle, 0);
}

int dz_shape_star(int i, dz_color c, float cx, float cy, float rx, float ry, int points,
		  float inner, int t, float angle)
{
	float p[4 * 128], ix = t > 0 ? inset(rx, t) : rx, iy = t > 0 ? inset(ry, t) : ry;

	if (!ok_slot(i) || points < 3 || points > 128 || rx <= 0.0f || ry <= 0.0f)
		return -1;
	if (inner <= 0.0f) {		/* the outline of the {n/2} star polygon */
		inner = points >= 5 ? cosf(2.0f * (float)M_PI / (float)points) /
				      cosf((float)M_PI / (float)points) : 0.5f;
	}
	if (inner > 1.0f)
		inner = 1.0f;
	for (int k = 0; k < 2 * points; k++) {
		float f = (k & 1) ? inner : 1.0f;

		ring(&p[2 * k], &p[2 * k + 1], k, 2 * points, ix * f, iy * f);
	}
	return shape_loop(i, c, p, 2 * points, cx, cy, rx, ry, t, angle, 0);
}

static int gcd(int a, int b)
{
	while (b) {
		int t = a % b;

		a = b;
		b = t;
	}
	return a;
}

int dz_shape_starpoly(int i, dz_color c, float cx, float cy, float rx, float ry, int n, int k,
		      int t, float angle)
{
	float v[2 * 256], p[2 * 256], ix = t > 0 ? inset(rx, t) : rx, iy = t > 0 ? inset(ry, t) : ry;
	int g, m;
	paint_t pt;

	if (!ok_slot(i) || n < 3 || n > 256 || rx <= 0.0f || ry <= 0.0f)
		return -1;
	k %= n;
	if (k < 1)
		k = 1;
	g = gcd(n, k);
	m = n / g;			/* points per loop */
	if (m < 3)			/* {4/2}, {6/3}: loops of 2 points = lines */
		m = 2;
	for (int q = 0; q < n; q++) {
		ring(&v[2 * q], &v[2 * q + 1], q, n, ix, iy);
	}
	place(v, n, cx, cy, angle);
	ne = 0;
	for (int l = 0; l < g; l++) {	/* one loop per common factor */
		for (int q = 0; q < m; q++) {
			int idx = (l + q * k) % n;

			p[2 * q] = v[2 * idx];
			p[2 * q + 1] = v[2 * idx + 1];
		}
		if (t > 0)
			stroke(p, m, (float)t);
		else if (m >= 3)
			loop(p, m);
	}
	paint_init(&pt, i, c, cx, cy, rx, ry, angle);
	return raster(i, &pt, t > 0 ? 0 : 1);
}

int dz_shape_radial(int i, dz_color a, dz_color b, float cx, float cy, float radius)
{
	int W, H, plain;
	uint32_t *buf = dz_surf(i, &W, &H);
	paint_t pt;
	fill_t keep;

	if (!buf)
		return -1;
	if (radius <= 0.0f)		/* default: centre to the far corner */
		radius = sqrtf((float)(W * W + H * H)) / 2.0f;
	keep = fills[i];
	fills[i] = (fill_t){ DZ_FILL_RADIAL, b, 0.0f };
	paint_init(&pt, i, a, cx, cy, radius, radius, 0.0f);
	fills[i] = keep;
	plain = dz_surf_plain(i);
	for (int y = 0; y < H; y++) {
		uint32_t *row = buf + (size_t)y * W;
		float dy = ((float)y + 0.5f - cy) * pt.ihy, dy2 = dy * dy;

		for (int x = 0; x < W; x++) {
			float dx = ((float)x + 0.5f - cx) * pt.ihx, t = sqrtf(dx * dx + dy2);
			uint32_t v = pt.lut[t >= 1.0f ? 256 : (int)(t * 256.0f)];

			if (plain)
				row[x] = v;
			else
				dz_surf_put(i, &row[x], v, 256);
		}
	}
	dz_surf_dirty(i, 0, 0, W, H);
	dz_surf_finish(i);
	return 0;
}

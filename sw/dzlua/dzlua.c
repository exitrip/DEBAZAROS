/*
 * dzlua - a LuaJIT script draws into one frame slot (2026-11-20).
 *
 * The gap between the compiled effects and the OSC API: a curve of 10,000
 * segments is one script line, not 10,000 OSC messages. debazd starts it
 * (/lua/<s>/start name, sw/debazd/lua.c) as it starts a movie: one process
 * per slot, any draw on the slot stops it, a crash or an endless loop stops
 * only the script.
 *
 *   dzlua -s slot [-c ctl_fifo] [-t stat_file] [-n frames] [-S] [-o out.ppm] script.lua
 *
 *   -s   the target slot (0..DZ_SLOTS-1)
 *   -l   layer mode: only pixels brighter than a key level go to the slot
 *        (debazd sets it when a movie or the capture writes the slot)
 *   -c   control FIFO (debazd made it and holds it open): one line per
 *        parameter, "key value" -> param.key in the script (live)
 *   -t   stat file, written once a second: "fps ms frames"
 *   -n   stop after n frames (tests)
 *   -S   simulation (no hardware: host tests), -o = the canvas as a PPM at
 *        the end
 *
 * The canvas is a RAM copy of the slot at the running video mode's size
 * (it starts with the slot's picture); present() copies the changed
 * rectangle to the slot. The drawing calls are C (below); the Lua API
 * around them is prelude.lua (built into this program, .incbin). LuaJIT
 * comes from the image (libluajit-5.1.so.2, dlopen: no headers needed at
 * build time); the script calls the dzl_* functions through the FFI (the
 * program is linked with -rdynamic).
 *
 * Pixels are 0xRRGGBB (true RGB: the RBG lane order is a PL detail).
 */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <errno.h>
#include <fcntl.h>
#include <math.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <time.h>
#include <unistd.h>

#ifdef __ARM_NEON
#include <arm_neon.h>
#endif
#include "dz_font_data.h"
#include "dz_hw.h"
#include "dz_map.h"
#include "dz_react_shm.h"
#include "dz_vdma.h"

#define DZL __attribute__((visibility("default"), used))

/* prelude.lua, built in (Makefile: -DDZL_PRELUDE=<path>) */
__asm__(".section .rodata\n"
	".global dzl_prelude\n"
	"dzl_prelude:\n"
	".incbin \"" DZL_PRELUDE "\"\n"
	".byte 0\n"
	".previous\n");
extern const char dzl_prelude[];

static uint32_t *fb;			/* the canvas (RAM) */
static int W, H;
static uint8_t *slot;			/* the slot, written (write-through with dzmem, else uncached) */
static const uint8_t *slot_rd;		/* the slot, read (write-back with dzmem: 2x faster) */
static size_t stride = DZ_STRIDE;
static int dx0, dy0, dx1 = -1, dy1 = -1;	/* changed area, dx1 < dx0 = none */
static int blend, galpha = 256;
static int ctl_fd = -1;
static char ctl_buf[4096];
static size_t ctl_n;
static char ctl_line[1024];
static const char *stat_path;
static int frames_max;
static double t_start, t_next, t_stat, work_ms, work_t0;
static unsigned long frames, stat_frames;

static double mono(void)
{
	struct timespec t;

	clock_gettime(CLOCK_MONOTONIC, &t);
	return (double)t.tv_sec + t.tv_nsec * 1e-9;
}

/* ---- changed area ---- */
static void mark(int x0, int y0, int x1, int y1)
{
	if (x0 < 0) x0 = 0;
	if (y0 < 0) y0 = 0;
	if (x1 >= W) x1 = W - 1;
	if (y1 >= H) y1 = H - 1;
	if (x1 < x0 || y1 < y0)
		return;
	if (dx1 < dx0) {
		dx0 = x0; dy0 = y0; dx1 = x1; dy1 = y1;
		return;
	}
	if (x0 < dx0) dx0 = x0;
	if (y0 < dy0) dy0 = y0;
	if (x1 > dx1) dx1 = x1;
	if (y1 > dy1) dy1 = y1;
}

static void mark_all(void)
{
	dx0 = dy0 = 0;
	dx1 = W - 1;
	dy1 = H - 1;
}

/* ---- one pixel, coverage 0..256, the blend mode ---- */
static inline int c8(int v)
{
	return v < 0 ? 0 : v > 255 ? 255 : v;
}

static inline void put(int x, int y, uint32_t c, int cov)
{
	uint32_t *p, d;
	int r, g, b, cr, cg, cb;

	if ((unsigned)x >= (unsigned)W || (unsigned)y >= (unsigned)H)
		return;
	cov = cov * galpha >> 8;
	if (cov <= 0)
		return;
	p = &fb[(size_t)y * W + x];
	if (blend == 0 && cov >= 256) {
		*p = c | 0xFF000000u;
		return;
	}
	d = *p;
	r = (d >> 16) & 255; g = (d >> 8) & 255; b = d & 255;
	cr = (c >> 16) & 255; cg = (c >> 8) & 255; cb = c & 255;
	switch (blend) {
	case 1:		/* add */
		r = c8(r + (cr * cov >> 8)); g = c8(g + (cg * cov >> 8)); b = c8(b + (cb * cov >> 8));
		break;
	case 2:		/* lighten */
		cr = cr * cov >> 8; cg = cg * cov >> 8; cb = cb * cov >> 8;
		r = r > cr ? r : cr; g = g > cg ? g : cg; b = b > cb ? b : cb;
		break;
	case 3:		/* subtract */
		r = c8(r - (cr * cov >> 8)); g = c8(g - (cg * cov >> 8)); b = c8(b - (cb * cov >> 8));
		break;
	default:	/* normal */
		r += (cr - r) * cov / 256; g += (cg - g) * cov / 256; b += (cb - b) * cov / 256;
		break;
	}
	*p = 0xFF000000u | (uint32_t)r << 16 | (uint32_t)g << 8 | (uint32_t)b;
}

static int cov_of(double v)		/* 0..1 -> 0..256 */
{
	return v <= 0 ? 0 : v >= 1 ? 256 : (int)(v * 256.0);
}

/* ---- the API (ffi.C.dzl_*) ---- */
DZL uint32_t *dzl_fb(void) { return fb; }
DZL double dzl_mono(void) { return mono(); }
DZL int dzl_w(void) { return W; }
DZL int dzl_h(void) { return H; }
DZL int dzl_frames_max(void) { return frames_max; }
DZL double dzl_time(void) { return mono() - t_start; }

DZL void dzl_blend(int mode) { blend = mode >= 0 && mode <= 3 ? mode : 0; }
DZL void dzl_alpha(double a) { galpha = cov_of(a); }

DZL void dzl_dirty(int x, int y, int w, int h)
{
	if (w <= 0 || h <= 0)
		mark_all();
	else
		mark(x, y, x + w - 1, y + h - 1);
}

DZL void dzl_clear(uint32_t c)
{
	size_t n = (size_t)W * H;

	c |= 0xFF000000u;
	for (size_t i = 0; i < n; i++)
		fb[i] = c;
	mark_all();
}

/* n pixels toward colour `to` by a/256: out = (p * (256 - a) + to * a) >> 8
 * per channel, exact in 16 bits; the alpha byte stays 0xFF. NEON: 4
 * pixels per step (the C loop: 44 ms for 1280 x 1024 on the A9). */
static void fade_px(uint32_t *px, size_t n, uint32_t a, uint32_t to)
{
	uint32_t inv = 256 - a;
	size_t i = 0;

	to |= 0xFF000000u;
#ifdef __ARM_NEON
	{
		uint8x8_t t8 = vreinterpret_u8_u32(vdup_n_u32(to));
		uint16x8_t ta = vmulq_n_u16(vmovl_u8(t8), (uint16_t)a);
		uint8_t *p = (uint8_t *)px;

		for (; i + 4 <= n; i += 4, p += 16) {
			uint8x16_t v = vld1q_u8(p);
			uint16x8_t lo = vmlaq_n_u16(ta, vmovl_u8(vget_low_u8(v)), (uint16_t)inv);
			uint16x8_t hi = vmlaq_n_u16(ta, vmovl_u8(vget_high_u8(v)), (uint16_t)inv);

			vst1q_u8(p, vcombine_u8(vshrn_n_u16(lo, 8), vshrn_n_u16(hi, 8)));
		}
	}
#endif
	{
		uint32_t trb = (to & 0xFF00FFu) * a, tg = (to & 0xFF00u) * a;

		for (; i < n; i++) {
			uint32_t p = px[i];

			px[i] = 0xFF000000u | ((((p & 0xFF00FFu) * inv + trb) >> 8) & 0xFF00FFu) |
				((((p & 0xFF00u) * inv + tg) >> 8) & 0xFF00u);
		}
	}
}

/* every pixel toward colour `to` by k (0..1) */
DZL void dzl_fade(double k, uint32_t to)
{
	uint32_t a = (uint32_t)cov_of(k);

	if (!a)
		return;
	fade_px(fb, (size_t)W * H, a, to);
	mark_all();
}

/* trails: the same fade after each present, fused with the copy (row by
 * row, while the row is in the cache): cheaper than fade() at the start
 * of each frame, same picture. k = 0: off */
static uint32_t trails_a, trails_to;

DZL void dzl_trails(double k, uint32_t to)
{
	trails_a = (uint32_t)cov_of(k);
	trails_to = to;
}

DZL void dzl_pset(int x, int y, uint32_t c)
{
	put(x, y, c, 256);
	mark(x, y, x, y);
}

DZL uint32_t dzl_pget(int x, int y)
{
	if ((unsigned)x >= (unsigned)W || (unsigned)y >= (unsigned)H)
		return 0;
	return fb[(size_t)y * W + x] & 0xFFFFFFu;
}

/* thin anti-aliased line (Xiaolin Wu), the far end pixel left out: a
 * polyline does not draw its corners twice */
static void wu(double x0, double y0, double x1, double y1, uint32_t c)
{
	int steep = fabs(y1 - y0) > fabs(x1 - x0), lim, xa, xb;
	double t, grad, y;

	if (steep) {
		t = x0; x0 = y0; y0 = t;
		t = x1; x1 = y1; y1 = t;
	}
	if (x0 > x1) {
		t = x0; x0 = x1; x1 = t;
		t = y0; y0 = y1; y1 = t;
	}
	grad = x1 - x0 > 1e-9 ? (y1 - y0) / (x1 - x0) : 0;
	lim = steep ? H : W;
	xa = (int)floor(x0 + 0.5);
	xb = (int)floor(x1 + 0.5);
	if (xa == xb)
		xb++;			/* a dot */
	y = y0 + grad * (xa - x0);
	if (xa < 0) {
		y += grad * -xa;
		xa = 0;
	}
	if (xb > lim)
		xb = lim;
	for (int x = xa; x < xb; x++, y += grad) {
		int yi = (int)floor(y), f = (int)((y - yi) * 256.0);

		if (steep) {
			put(yi, x, c, 256 - f);
			put(yi + 1, x, c, f);
		} else {
			put(x, yi, c, 256 - f);
			put(x, yi + 1, c, f);
		}
	}
}

static int ival_lin(double a, double b, double lo, double hi, double *xl, double *xh)
{
	/* lo <= a*x + b <= hi -> x interval; 0 = empty */
	if (fabs(a) < 1e-12) {
		if (b < lo || b > hi)
			return 0;
		*xl = -1e9;
		*xh = 1e9;
		return 1;
	}
	double p = (lo - b) / a, q = (hi - b) / a;

	*xl = p < q ? p : q;
	*xh = p < q ? q : p;
	return 1;
}

/* thick anti-aliased line: a capsule (round ends) of radius r. Per row
 * only the x span that can reach the shape is visited. */
static void capsule(double ax, double ay, double bx, double by, double r, uint32_t c)
{
	double vx = bx - ax, vy = by - ay, l2 = vx * vx + vy * vy, l = sqrt(l2), R = r + 1.0;
	int y0 = (int)floor((ay < by ? ay : by) - R), y1 = (int)ceil((ay > by ? ay : by) + R);

	if (y0 < 0) y0 = 0;
	if (y1 > H - 1) y1 = H - 1;
	for (int y = y0; y <= y1; y++) {
		double lo = 1e18, hi = -1e18, xl, xh, d;

		for (int e = 0; e < 2; e++) {	/* the two end circles */
			double ey = e ? by : ay, ex = e ? bx : ax, dy = y - ey;

			if ((d = R * R - dy * dy) >= 0) {
				d = sqrt(d);
				if (ex - d < lo) lo = ex - d;
				if (ex + d > hi) hi = ex + d;
			}
		}
		if (l > 1e-9) {			/* the band between them */
			double ml, mh, nl, nh, dy = y - ay;

			if (ival_lin(vy, -dy * vx, -R * l, R * l, &ml, &mh) &&
			    ival_lin(vx, dy * vy, 0, l2, &nl, &nh)) {
				xl = ml > nl ? ml : nl;
				xh = mh < nh ? mh : nh;
				if (xl <= xh) {
					if (xl + ax < lo) lo = xl + ax;
					if (xh + ax > hi) hi = xh + ax;
				}
			}
		}
		if (lo > hi)
			continue;
		int xa = (int)floor(lo), xb = (int)ceil(hi);

		if (xa < 0) xa = 0;
		if (xb > W - 1) xb = W - 1;
		for (int x = xa; x <= xb; x++) {
			double px = x - ax, py = y - ay, t = l2 > 1e-12 ? (px * vx + py * vy) / l2 : 0;

			t = t < 0 ? 0 : t > 1 ? 1 : t;
			px -= t * vx;
			py -= t * vy;
			put(x, y, c, cov_of(r + 0.5 - sqrt(px * px + py * py)));
		}
	}
}

static int finite4(double a, double b, double c, double d)
{
	return isfinite(a) && isfinite(b) && isfinite(c) && isfinite(d);
}

DZL void dzl_line(double x0, double y0, double x1, double y1, uint32_t c, double w)
{
	double m = w > 1 ? w / 2 + 2 : 2;

	if (!finite4(x0, y0, x1, y1) || fabs(x0) > 1e6 || fabs(y0) > 1e6 || fabs(x1) > 1e6 || fabs(y1) > 1e6)
		return;
	if (w <= 1.0)
		wu(x0, y0, x1, y1, c);
	else
		capsule(x0, y0, x1, y1, w / 2, c);
	mark((int)floor((x0 < x1 ? x0 : x1) - m), (int)floor((y0 < y1 ? y0 : y1) - m),
	     (int)ceil((x0 > x1 ? x0 : x1) + m), (int)ceil((y0 > y1 ? y0 : y1) + m));
}

DZL void dzl_rect(double x, double y, double w, double h, uint32_t c, int fill)
{
	int xa = (int)floor(x), ya = (int)floor(y), xb = (int)floor(x + w) - 1, yb = (int)floor(y + h) - 1;

	if (!finite4(x, y, w, h) || w <= 0 || h <= 0)
		return;
	if (xa < 0) xa = 0;
	if (ya < 0) ya = 0;
	if (xb > W - 1) xb = W - 1;
	if (yb > H - 1) yb = H - 1;
	for (int yy = ya; yy <= yb; yy++)
		for (int xx = xa; xx <= xb; xx++)
			if (fill || yy == (int)floor(y) || yy == (int)floor(y + h) - 1 ||
			    xx == (int)floor(x) || xx == (int)floor(x + w) - 1)
				put(xx, yy, c, 256);
	mark(xa, ya, xb, yb);
}

DZL void dzl_circle(double cx, double cy, double r, uint32_t c, int fill, double w)
{
	if (!finite4(cx, cy, r, w) || r <= 0 || r > 1e5)
		return;
	if (!fill) {			/* outline: a polygon of short segments */
		int n = (int)(r * 1.5) + 12;
		double px = cx + r, py = cy;

		if (n > 4000)
			n = 4000;
		for (int i = 1; i <= n; i++) {
			double a = 2 * M_PI * i / n, qx = cx + r * cos(a), qy = cy + r * sin(a);

			if (w <= 1.0)
				wu(px, py, qx, qy, c);
			else
				capsule(px, py, qx, qy, w / 2, c);
			px = qx;
			py = qy;
		}
	} else {
		int y0 = (int)floor(cy - r - 1), y1 = (int)ceil(cy + r + 1);

		if (y0 < 0) y0 = 0;
		if (y1 > H - 1) y1 = H - 1;
		for (int y = y0; y <= y1; y++) {
			double dy = y - cy, o = (r + 0.5) * (r + 0.5) - dy * dy, in;

			if (o < 0)
				continue;
			o = sqrt(o);
			in = r - 0.5 > fabs(dy) ? sqrt((r - 0.5) * (r - 0.5) - dy * dy) : -1;
			int xa = (int)floor(cx - o), xb = (int)ceil(cx + o);

			if (xa < 0) xa = 0;
			if (xb > W - 1) xb = W - 1;
			for (int x = xa; x <= xb; x++) {
				double dx = x - cx;

				if (fabs(dx) <= in)
					put(x, y, c, 256);
				else
					put(x, y, c, cov_of(r + 0.5 - sqrt(dx * dx + dy * dy)));
			}
		}
	}
	double m = r + (w > 1 ? w / 2 : 0) + 2;

	mark((int)floor(cx - m), (int)floor(cy - m), (int)ceil(cx + m), (int)ceil(cy + m));
}

/* the 8 x 16 pixel font (ASCII 32..126), integer scale, "\n" = new line */
DZL void dzl_text(int x, int y, const char *s, uint32_t c, int scale)
{
	int cx = x, cy = y, maxx = x;

	if (!s)
		return;
	if (scale < 1) scale = 1;
	if (scale > 64) scale = 64;
	for (; *s; s++) {
		unsigned ch = (unsigned char)*s;

		if (ch == '\n') {
			cx = x;
			cy += DZ_FONT16_H * scale;
			continue;
		}
		if (ch < 32 || ch > 126)
			ch = '?';
		const uint8_t *g = dz_font16[ch - 32];

		for (int gy = 0; gy < DZ_FONT16_H; gy++)
			for (int gx = 0; gx < DZ_FONT16_W; gx++)
				if (g[gy] & (0x80 >> gx))
					for (int sy = 0; sy < scale; sy++)
						for (int sx = 0; sx < scale; sx++)
							put(cx + gx * scale + sx, cy + gy * scale + sy, c, 256);
		cx += DZ_FONT16_W * scale;
		if (cx > maxx)
			maxx = cx;
	}
	mark(x, y, maxx, cy + DZ_FONT16_H * scale);
}

/* move the whole canvas by dx, dy (the free edge keeps its old pixels) */
DZL void dzl_scroll(int dx, int dy)
{
	if (dx <= -W || dx >= W || dy <= -H || dy >= H || (!dx && !dy))
		return;
	if (dy > 0)
		for (int y = H - 1; y >= dy; y--)
			memmove(fb + (size_t)y * W, fb + (size_t)(y - dy) * W, (size_t)W * 4);
	else if (dy < 0)
		for (int y = 0; y < H + dy; y++)
			memmove(fb + (size_t)y * W, fb + (size_t)(y - dy) * W, (size_t)W * 4);
	if (dx)
		for (int y = 0; y < H; y++) {
			uint32_t *r = fb + (size_t)y * W;

			if (dx > 0)
				memmove(r + dx, r, (size_t)(W - dx) * 4);
			else
				memmove(r, r - dx, (size_t)(W + dx) * 4);
		}
	mark_all();
}

/*
 * Layer mode (2026-11-20, ROADMAP.md section 19): on a slot that another
 * writer refreshes every frame (a movie, the capture) only the pixels
 * brighter than layer_key go to the slot, as runs of memcpy (no reads):
 * black is transparent, trails dissolve into the movie. Opaque mode (the
 * default on a still slot) copies the whole changed rectangle.
 */
static int layer_on, layer_key = 8;

DZL void dzl_layer(int on, int key)
{
	layer_on = on != 0;
	if (key >= 0)
		layer_key = key > 255 ? 255 : key;
}

DZL int dzl_layer_get(void) { return layer_on; }

static inline int visible(uint32_t p)
{
	uint32_t r = (p >> 16) & 255, g = (p >> 8) & 255, b = p & 255;

	return (int)(r > g ? (r > b ? r : b) : (g > b ? g : b)) > layer_key;
}

/* row y, columns x0..x1 (inclusive): opaque = one copy, layer = runs of
 * visible pixels. NEON tests 4 pixels per step (the scalar test cost 16
 * ms per 1280 x 1024 frame, 50 ms next to a movie, measured 2026-11-20). */
static void put_row(int y, int x0, int x1)
{
	const uint32_t *r = fb + (size_t)y * W;
	uint8_t *d = slot + (size_t)y * stride;
	int run = -1, x = x0;

	if (!layer_on) {
		memcpy(d + (size_t)x0 * 4, r + x0, (size_t)(x1 - x0 + 1) * 4);
		return;
	}
#define FLUSH(e) do { if (run >= 0) { memcpy(d + (size_t)run * 4, r + run, (size_t)((e) - run) * 4); run = -1; } } while (0)
#ifdef __ARM_NEON
	{
		const uint8x16_t key = vdupq_n_u8((uint8_t)layer_key);
		const uint32x4_t rgb = vdupq_n_u32(0x00FFFFFFu);

		for (; x + 4 <= x1 + 1; x += 4) {
			uint8x16_t gt = vcgtq_u8(vld1q_u8((const uint8_t *)(r + x)), key);
			uint32x4_t m = vtstq_u32(vreinterpretq_u32_u8(gt), rgb);
			uint64x2_t m2 = vreinterpretq_u64_u32(m);
			uint64_t lo = vgetq_lane_u64(m2, 0), hi = vgetq_lane_u64(m2, 1);

			if (!lo && !hi) {		/* 4 transparent */
				FLUSH(x);
				continue;
			}
			if (!~lo && !~hi) {		/* 4 visible */
				if (run < 0)
					run = x;
				continue;
			}
			for (int k = 0; k < 4; k++) {	/* mixed */
				if (visible(r[x + k])) {
					if (run < 0)
						run = x + k;
				} else {
					FLUSH(x + k);
				}
			}
		}
	}
#endif
	for (; x <= x1; x++) {
		if (visible(r[x])) {
			if (run < 0)
				run = x;
		} else {
			FLUSH(x);
		}
	}
	FLUSH(x1 + 1);
#undef FLUSH
}

/* the changed rectangle to the slot */
DZL void dzl_present(void)
{
	if (trails_a) {
		for (int y = 0; y < H; y++) {
			put_row(y, 0, W - 1);
			fade_px(fb + (size_t)y * W, (size_t)W, trails_a, trails_to);
		}
		mark_all();		/* the next frame changes every pixel */
		return;
	}
	if (dx1 < dx0)
		return;
	for (int y = dy0; y <= dy1; y++)
		put_row(y, dx0, dx1);
	dx0 = dy0 = 0;
	dx1 = dy1 = -1;
}

/* the slot into the canvas (uncached reads: ~50 ms for 1280 x 1024): a
 * script that wants to keep what others drew there */
DZL void dzl_grab(void)
{
	for (int y = 0; y < H; y++) {
		uint32_t *r = fb + (size_t)y * W;

		memcpy(r, slot_rd + (size_t)y * stride, (size_t)W * 4);
		for (int x = 0; x < W; x++)
			r[x] |= 0xFF000000u;
	}
	dx0 = dy0 = 0;
	dx1 = dy1 = -1;
}

/* debazd's audio analysis (lib/dz_react_shm.h): copy a consistent
 * snapshot into dst (the prelude's `audio`). Pokes the block = "a reader
 * wants data" (debazd then writes it each frame, source auto runs).
 * 1 = copied, 0 = no data yet (debazd not writing / no file), -1 = the
 * file has another layout version. */
DZL int dzl_audio(dz_react_shm *dst)
{
	static dz_react_shm *m;
	static double retry;
	uint32_t s0, s1;

	if (!m) {
		int f;
		void *p;

		if (mono() < retry)
			return 0;
		retry = mono() + 1.0;
		f = open(DZ_REACT_SHM, O_RDWR | O_CLOEXEC);
		if (f < 0)
			return 0;
		p = mmap(NULL, sizeof(dz_react_shm), PROT_READ | PROT_WRITE, MAP_SHARED, f, 0);
		close(f);
		if (p == MAP_FAILED)
			return 0;
		m = p;
	}
	__atomic_fetch_add(&m->poke, 1, __ATOMIC_RELAXED);
	if (m->magic != DZ_REACT_SHM_MAGIC || m->version != DZ_REACT_SHM_VERSION)
		return -1;
	if (!m->frame)
		return 0;			/* debazd has not written yet */
	for (int tries = 0; tries < 8; tries++) {	/* a write takes ~50 us */
		s0 = __atomic_load_n(&m->seq, __ATOMIC_ACQUIRE);
		if (!(s0 & 1)) {
			memcpy(dst, m, sizeof(*dst));
			__sync_synchronize();
			s1 = __atomic_load_n(&m->seq, __ATOMIC_RELAXED);
			if (s0 == s1)
				return 1;
		}
		usleep(50);
	}
	return 0;
}

static void write_stat(double now)
{
	FILE *f;
	char tmp[300];

	if (!stat_path || now - t_stat < 1.0)
		return;
	snprintf(tmp, sizeof(tmp), "%s.part", stat_path);
	if ((f = fopen(tmp, "w"))) {
		double dt = now - t_stat;

		fprintf(f, "%.2f %.2f %lu\n", (frames - stat_frames) / dt,
			frames > stat_frames ? work_ms / (frames - stat_frames) : 0.0, frames);
		if (fclose(f) == 0)
			rename(tmp, stat_path);
	}
	t_stat = now;
	stat_frames = frames;
	work_ms = 0;
}

/* the end of a frame: wait for the next frame time at fps; returns the
 * time since the start (s). Late by more than a frame: no catching up. */
DZL double dzl_wait(double fps)
{
	double now = mono(), per;

	if (!(fps > 0.1)) fps = 0.1;
	if (fps > 240) fps = 240;
	per = 1.0 / fps;
	work_ms += (now - work_t0) * 1e3;
	frames++;
	write_stat(now);
	t_next += per;
	if (t_next < now - per)
		t_next = now;
	if (t_next > now) {
		struct timespec ts;
		double t = t_next;

		ts.tv_sec = (time_t)t;
		ts.tv_nsec = (long)((t - (double)ts.tv_sec) * 1e9);
		while (clock_nanosleep(CLOCK_MONOTONIC, TIMER_ABSTIME, &ts, NULL) == EINTR)
			;
	}
	work_t0 = mono();
	return work_t0 - t_start;
}


/* ---- MIDI out: the ALSA sequencer with a real-time queue (2026-11-20) ------
 * Notes leave at their time stamp (the kernel's hrtimer), not at the frame:
 * a script schedules them ahead (midi.note(..., at)). libasound by dlopen
 * (the toolchain has no ALSA headers: the event layout is written out here,
 * snd_seq_event_t = 28 bytes on ARM32). Every way out sends "all off":
 * the end of the script, a Lua error, os.exit (atexit) and SIGTERM
 * (/lua/<s>/stop): the main client is closed first (that drops its queue
 * with every event still waiting in it), then a second client sends sustain
 * off, All Notes Off and All Sound Off on the 16 channels. SIGKILL (debazd
 * sends it 0.5 s after SIGTERM) cannot be caught. */
typedef struct { unsigned char client, port; } sq_addr;
typedef struct {
	unsigned char type, flags;
	char          tag;
	unsigned char queue;
	unsigned int  sec, nsec;		/* union time: real time */
	sq_addr       source, dest;
	union {
		struct { unsigned char channel, note, velocity, off_velocity; unsigned int duration; } note;
		struct { unsigned char channel, u1, u2, u3; unsigned int param; int value; } control;
		unsigned char raw[12];
	} data;
} sq_event;
_Static_assert(sizeof(sq_event) == 28, "snd_seq_event_t layout");

enum { SQ_NOTEON = 6, SQ_NOTEOFF = 7, SQ_CONTROLLER = 10, SQ_PGMCHANGE = 11, SQ_PITCHBEND = 13,
       SQ_START = 30, SQ_REAL = 1, SQ_DIRECT = 253, SQ_SUBS = 254, SQ_UNKNOWN = 253 };

static int slot_no = -1;
static struct {
	void *lib;
	int  (*f_open)(void **, const char *, int, int);
	int  (*f_name)(void *, const char *);
	int  (*f_port)(void *, const char *, unsigned, unsigned);
	int  (*f_queue)(void *);
	int  (*f_ctlq)(void *, int, int, int, void *);
	int  (*f_out)(void *, sq_event *);
	int  (*f_direct)(void *, sq_event *);
	int  (*f_drain)(void *);
	int  (*f_parse)(void *, sq_addr *, const char *);
	int  (*f_connect)(void *, int, int, int);
	int  (*f_pollfd)(void *, void *, unsigned, short);
	void  *seq, *pseq;			/* main client, panic client */
	int    port, pport, queue, fd, on;
	double t0;				/* script time of the queue's 0 */
	char   err[160];
} M = { .fd = -1 };

static void midi_panic_on(void *seq, int port)
{
	static const int cc[3] = { 64, 123, 120 };	/* sustain off, all notes off, all sound off */
	sq_event e;

	for (int ch = 0; ch < 16; ch++)
		for (int k = 0; k < 3; k++) {
			memset(&e, 0, sizeof(e));
			e.type = SQ_CONTROLLER;
			e.queue = SQ_DIRECT;
			e.source.port = (unsigned char)port;
			e.dest.client = SQ_SUBS;
			e.dest.port = SQ_UNKNOWN;
			e.data.control.channel = (unsigned char)ch;
			e.data.control.param = (unsigned)cc[k];
			M.f_direct(seq, &e);
		}
}

/* signal-safe enough: close() and direct writes, no allocation */
static void midi_close(void)
{
	if (!M.on)
		return;
	M.on = 0;
	if (M.fd >= 0)
		close(M.fd);			/* the main client: its queue and waiting notes go */
	M.fd = -1;
	midi_panic_on(M.pseq, M.pport);
}

static void midi_sigterm(int sig)
{
	midi_close();
	_exit(128 + sig);
}

static int need(void **f, const char *n)
{
	*f = dlsym(M.lib, n);
	if (!*f)
		snprintf(M.err, sizeof(M.err), "libasound: no %s", n);
	return *f ? 0 : -1;
}

static int connect_dest(void *seq, int port, const char *dest)
{
	sq_addr a;

	if (M.f_parse(seq, &a, dest) < 0 || M.f_connect(seq, port, a.client, a.port) < 0) {
		snprintf(M.err, sizeof(M.err), "no MIDI destination \"%s\" (sudo dzsynth.sh start? aconnect -l)", dest);
		return -1;
	}
	return 0;
}

/* open once: clients "dzlua <slot>" (+ "panic"), port "out", a real-time
 * queue; connect to dest ("FLUID Synth" = dzsynth.sh, a client:port, or
 * "none" = only who subscribes, aconnect). 0 = ok, -1 = see dzl_midi_err() */
DZL int dzl_midi_open(const char *dest)
{
	struct { int fd; short ev, rev; } pfd;
	char name[40];
	sq_event e;

	if (M.on)
		return 0;
	M.err[0] = 0;
	if (!M.lib && !(M.lib = dlopen("libasound.so.2", RTLD_NOW))) {
		snprintf(M.err, sizeof(M.err), "no libasound.so.2");
		return -1;
	}
	if (need((void **)&M.f_open, "snd_seq_open") || need((void **)&M.f_name, "snd_seq_set_client_name") ||
	    need((void **)&M.f_port, "snd_seq_create_simple_port") || need((void **)&M.f_queue, "snd_seq_alloc_queue") ||
	    need((void **)&M.f_ctlq, "snd_seq_control_queue") || need((void **)&M.f_out, "snd_seq_event_output") ||
	    need((void **)&M.f_direct, "snd_seq_event_output_direct") || need((void **)&M.f_drain, "snd_seq_drain_output") ||
	    need((void **)&M.f_parse, "snd_seq_parse_address") || need((void **)&M.f_connect, "snd_seq_connect_to") ||
	    need((void **)&M.f_pollfd, "snd_seq_poll_descriptors"))
		return -1;
	if (!M.seq && (M.f_open(&M.seq, "default", 1 /* output */, 0) < 0 ||
		       M.f_open(&M.pseq, "default", 1, 0) < 0)) {
		snprintf(M.err, sizeof(M.err), "cannot open the ALSA sequencer");
		M.seq = NULL;
		return -1;
	}
	snprintf(name, sizeof(name), "dzlua %d", slot_no);
	M.f_name(M.seq, name);
	snprintf(name, sizeof(name), "dzlua %d panic", slot_no);
	M.f_name(M.pseq, name);
	M.port = M.f_port(M.seq, "out", 1 | 32 /* READ | SUBS_READ */, 2 | (1u << 20) /* MIDI_GENERIC | APPLICATION */);
	M.pport = M.f_port(M.pseq, "panic", 1 | 32, 2 | (1u << 20));
	if (M.port < 0 || M.pport < 0 || (M.queue = M.f_queue(M.seq)) < 0) {
		snprintf(M.err, sizeof(M.err), "ALSA sequencer: no port / queue");
		return -1;
	}
	if (dest && *dest && strcmp(dest, "none") &&
	    (connect_dest(M.seq, M.port, dest) < 0 || connect_dest(M.pseq, M.pport, dest) < 0))
		return -1;
	memset(&e, 0, sizeof(e));
	M.f_ctlq(M.seq, M.queue, SQ_START, 0, NULL);
	M.f_drain(M.seq);
	M.t0 = mono() - t_start;		/* the queue's 0 in script time */
	M.fd = M.f_pollfd(M.seq, &pfd, 1, 4 /* POLLOUT */) == 1 ? pfd.fd : -1;
	M.on = 1;
	atexit(midi_close);
	signal(SIGTERM, midi_sigterm);
	return 0;
}

DZL const char *dzl_midi_err(void) { return M.err; }

/* kind 0 note on, 1 note off, 2 controller, 3 program, 4 pitch bend
 * (a = -8192..8191); at = script time (time()), < 0 or past = now */
DZL int dzl_midi_ev(int kind, int ch, int a, int b, double at)
{
	static const unsigned char T[5] = { SQ_NOTEON, SQ_NOTEOFF, SQ_CONTROLLER, SQ_PGMCHANGE, SQ_PITCHBEND };
	sq_event e;
	double q;

	if (!M.on || kind < 0 || kind > 4)
		return -1;
	memset(&e, 0, sizeof(e));
	e.type = T[kind];
	e.source.port = (unsigned char)M.port;
	e.dest.client = SQ_SUBS;
	e.dest.port = SQ_UNKNOWN;
	if (kind <= 1) {
		e.data.note.channel = (unsigned char)(ch & 15);
		e.data.note.note = (unsigned char)(a & 127);
		e.data.note.velocity = (unsigned char)(b < 0 ? 0 : b > 127 ? 127 : b);
	} else {
		e.data.control.channel = (unsigned char)(ch & 15);
		e.data.control.param = (unsigned)a;
		e.data.control.value = kind == 2 ? b : a;
		if (kind == 3)
			e.data.control.param = 0;
	}
	q = at - M.t0;
	if (at < 0 || q <= 0) {
		e.queue = SQ_DIRECT;
		return M.f_direct(M.seq, &e) < 0 ? -1 : 0;
	}
	e.flags = SQ_REAL;			/* real time, absolute */
	e.queue = (unsigned char)M.queue;
	e.sec = (unsigned)q;
	e.nsec = (unsigned)((q - (double)e.sec) * 1e9);
	if (M.f_out(M.seq, &e) < 0)
		return -1;
	return M.f_drain(M.seq) < 0 ? -1 : 0;
}

/* now: all off on 16 channels (the waiting notes stay queued) */
DZL void dzl_midi_panic(void)
{
	if (M.on)
		midi_panic_on(M.pseq, M.pport);
}

/* the next control line ("key value"), or NULL */
DZL const char *dzl_ctl(void)
{
	for (;;) {
		char *nl = memchr(ctl_buf, '\n', ctl_n);

		if (nl) {
			size_t l = (size_t)(nl - ctl_buf);

			if (l >= sizeof(ctl_line))
				l = sizeof(ctl_line) - 1;
			memcpy(ctl_line, ctl_buf, l);
			ctl_line[l] = 0;
			ctl_n -= (size_t)(nl + 1 - ctl_buf);
			memmove(ctl_buf, nl + 1, ctl_n);
			return ctl_line;
		}
		if (ctl_n == sizeof(ctl_buf))
			ctl_n = 0;		/* a line too long: drop it */
		if (ctl_fd < 0)
			return NULL;
		ssize_t k = read(ctl_fd, ctl_buf + ctl_n, sizeof(ctl_buf) - ctl_n);

		if (k <= 0)
			return NULL;
		ctl_n += (size_t)k;
	}
}

/* ---- LuaJIT, through dlopen (the image has the library, no headers) ---- */
typedef struct lua_State lua_State;
#define LUA_GLOBALSINDEX	(-10002)
static struct {
	lua_State *(*newstate)(void);
	void (*openlibs)(lua_State *);
	int (*loadbuffer)(lua_State *, const char *, size_t, const char *);
	int (*pcall)(lua_State *, int, int, int);
	const char *(*tolstring)(lua_State *, int, size_t *);
	void (*pushlstring)(lua_State *, const char *, size_t);
	void (*pushnumber)(lua_State *, double);
	void (*setfield)(lua_State *, int, const char *);
	void (*close)(lua_State *);
} L_;

static int lua_load_lib(void)
{
	static const char *const names[] = { "libluajit-5.1.so.2", "libluajit-5.1.so.2.1.0",
					     "libluajit-5.1.so", NULL };
	void *h = NULL;

	for (int i = 0; names[i] && !h; i++)
		h = dlopen(names[i], RTLD_NOW | RTLD_GLOBAL);
	if (!h) {
		fprintf(stderr, "dzlua: no LuaJIT library (%s)\n", dlerror());
		return -1;
	}
#define SYM(f, n) if (!(*(void **)&L_.f = dlsym(h, n))) { fprintf(stderr, "dzlua: %s missing\n", n); return -1; }
	SYM(newstate, "luaL_newstate");
	SYM(openlibs, "luaL_openlibs");
	SYM(loadbuffer, "luaL_loadbuffer");
	SYM(pcall, "lua_pcall");
	SYM(tolstring, "lua_tolstring");
	SYM(pushlstring, "lua_pushlstring");
	SYM(pushnumber, "lua_pushnumber");
	SYM(setfield, "lua_setfield");
	SYM(close, "lua_close");
#undef SYM
	return 0;
}

static char *read_file(const char *p, size_t *len)
{
	FILE *f = fopen(p, "rb");
	char *b;
	long n;

	if (!f)
		return NULL;
	if (fseek(f, 0, SEEK_END) < 0 || (n = ftell(f)) < 0 || n > (1L << 20) || fseek(f, 0, SEEK_SET) < 0 ||
	    !(b = malloc((size_t)n + 1))) {
		fclose(f);
		return NULL;
	}
	if (fread(b, 1, (size_t)n, f) != (size_t)n) {
		free(b);
		fclose(f);
		return NULL;
	}
	fclose(f);
	b[n] = 0;
	*len = (size_t)n;
	return b;
}

static void write_ppm(const char *p)
{
	FILE *f = fopen(p, "wb");

	if (!f)
		return;
	fprintf(f, "P6\n%d %d\n255\n", W, H);
	for (size_t i = 0; i < (size_t)W * H; i++) {
		uint8_t px[3] = { (uint8_t)(fb[i] >> 16), (uint8_t)(fb[i] >> 8), (uint8_t)fb[i] };

		fwrite(px, 1, 3, f);
	}
	fclose(f);
}

static void usage(void)
{
	fprintf(stderr, "usage: dzlua -s slot [-l] [-c ctl_fifo] [-t stat_file] [-n frames] [-S] [-o out.ppm] script.lua\n");
	exit(2);
}

int main(int argc, char **argv)
{
	int s = -1, sim = 0, opt, rc = 0;
	const char *ctl = NULL, *ppm = NULL, *via = "", *name;
	char *src;
	size_t srclen;
	lua_State *L;
	FILE *f;

	while ((opt = getopt(argc, argv, "s:lc:t:n:So:")) != -1) {
		switch (opt) {
		case 's': s = atoi(optarg); slot_no = s; break;
		case 'c': ctl = optarg; break;
		case 't': stat_path = optarg; break;
		case 'n': frames_max = atoi(optarg); break;
		case 'S': sim = 1; break;
		case 'o': ppm = optarg; break;
		case 'l': layer_on = 1; break;
		default: usage();
		}
	}
	if (optind != argc - 1 || s < 0 || s >= DZ_SLOTS || s == DZ_SLOT_BLANK) {
		if (s == DZ_SLOT_BLANK)
			fprintf(stderr, "dzlua: slot %d is the black slot\n", s);
		usage();
	}
	setvbuf(stdout, NULL, _IOLBF, 0);
	if ((f = fopen("/proc/self/oom_score_adj", "w"))) {	/* a script goes first */
		fputs("500\n", f);
		fclose(f);
	}
	if (!(src = read_file(argv[optind], &srclen))) {
		fprintf(stderr, "dzlua: cannot read %s: %s\n", argv[optind], strerror(errno));
		return 1;
	}
	name = strrchr(argv[optind], '/') ? strrchr(argv[optind], '/') + 1 : argv[optind];
	if (sim)
		dz_map_simulate(1);
	dz_geom_refresh();
	W = dz_geom_w();
	H = dz_geom_h();
	if (W > (int)(stride / 4))
		W = (int)(stride / 4);
	slot = dz_slot(s, stride * (size_t)H, &via);
	slot_rd = slot ? dz_slot_rd(s, stride * (size_t)H) : NULL;
	if (!slot || !slot_rd) {
		fprintf(stderr, "dzlua: slot %d is not in reserved memory\n", s);
		return 1;
	}
	if (!(fb = malloc((size_t)W * H * 4))) {
		fprintf(stderr, "dzlua: no memory for the %d x %d canvas\n", W, H);
		return 1;
	}
	for (int y = 0; y < H; y++) {		/* start on the slot's picture */
		memcpy(fb + (size_t)y * W, slot_rd + (size_t)y * stride, (size_t)W * 4);
		for (int x = 0; x < W; x++)
			fb[(size_t)y * W + x] |= 0xFF000000u;
	}
	if (ctl)
		ctl_fd = open(ctl, O_RDONLY | O_NONBLOCK | O_CLOEXEC);
	if (lua_load_lib() < 0)
		return 1;
	printf("dzlua: %s on slot %d, %d x %d (%s)\n", name, s, W, H, via);
	t_start = t_next = t_stat = work_t0 = mono();

	L = L_.newstate();
	if (!L) {
		fprintf(stderr, "dzlua: no Lua state\n");
		return 1;
	}
	L_.openlibs(L);
	L_.pushlstring(L, src, srclen);
	L_.setfield(L, LUA_GLOBALSINDEX, "SCRIPT");
	L_.pushlstring(L, name, strlen(name));
	L_.setfield(L, LUA_GLOBALSINDEX, "SCRIPT_NAME");
	L_.pushnumber(L, s);
	L_.setfield(L, LUA_GLOBALSINDEX, "SLOT");
	L_.pushnumber(L, W);
	L_.setfield(L, LUA_GLOBALSINDEX, "W");
	L_.pushnumber(L, H);
	L_.setfield(L, LUA_GLOBALSINDEX, "H");
	if (L_.loadbuffer(L, dzl_prelude, strlen(dzl_prelude), "=prelude") || L_.pcall(L, 0, 0, 0)) {
		const char *e = L_.tolstring(L, -1, NULL);

		fprintf(stderr, "dzlua: error: %s\n", e ? e : "?");
		rc = 1;
	}
	dzl_present();
	if (rc == 0)
		printf("dzlua: %s ended after %lu frames\n", name, frames);
	L_.close(L);
	if (ppm)
		write_ppm(ppm);
	free(src);
	return rc;
}

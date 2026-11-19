/*
 * slit.c - slit scan and sample-and-hold effects (2026-11-19, ROADMAP.md
 * section 18). One effect per target slot d; the source is any slot (a
 * movie, a paint slot) or the live capture. Runs on the pixel thread once
 * per frame and writes the target slot directly (no paint buffer):
 * < 1 ms per frame (a row 0.08 ms, a column 0.2 ms, measured at 720p).
 *
 *   row     source row `pos` (band rows thick) into target row w, then w
 *           moves by `speed` rows: the classic slit scan, time runs down
 *   col     source column `pos` into target column w: time runs right
 *   scan    the band of `band` rows at p is copied from the source to the
 *           same place, p moves by `speed`: a scanner bar; the rest holds
 *   scanv   the same with columns
 *   tiles   `tiles` random squares of `band` px copied in place per frame:
 *           a sample-and-hold glitch
 *   scroll 1 (row only) = waterfall: every row is written twice (at w and
 *           w + H) and each display that shows the target starts `w + 1`
 *           rows down, so the newest row is at the bottom and the picture
 *           scrolls up with no copy. Uses rows H..2H-1 below the target:
 *           part of the next slot (refused when that is the black slot 11).
 *
 * OSC (d = target slot; int = pixels / raw, float 0..1 = part of the size):
 *   /slit/<d>/run src | "capture"   start (src = slot; -1 = stop: state model)
 *   /slit/<d>/stop
 *   /slit/<d>/mode row|col|scan|scanv|tiles
 *   /slit/<d>/pos i|f        slit row / column in the source (row, col)
 *   /slit/<d>/speed f        rows / columns per frame, may be fractional or
 *                            negative (row, col, scan, scanv)
 *   /slit/<d>/band i         slit thickness, scanner band, tile size (px)
 *   /slit/<d>/tiles i        tiles per frame
 *   /slit/<d>/every k        work every k-th frame
 *   /slit/<d>/scroll 0|1     waterfall (row)
 *   /slit/<d>/clear          the target black, the write position to 0
 *   /slit/<d>/status   -> /slit/<d>/status i:run i:src s:mode i:pos f:speed
 *                         i:band i:tiles i:every i:scroll i:w f:ms
 *   (/slit/<d> state: settings, then run)
 */
#define _GNU_SOURCE
#include "debazd.h"
#include "dz_draw.h"
#include "dz_hw.h"
#include "dz_map.h"
#include "dz_vdma.h"

#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

enum { S_ROW, S_COL, S_SCAN, S_SCANV, S_TILES, S_N };
static const char *const MODE[S_N] = { "row", "col", "scan", "scanv", "tiles" };
#define SRC_CAPTURE	100

typedef struct {
	int    used, run, src, mode, band, tiles, every, scroll, cnt;
	double pos;			/* pixels, or 0..1 when posf */
	int    posf;
	double speed, w;		/* write position (row/col) or scan position */
	float  ms;			/* last frame's cost */
	int    scrolled;		/* displays moved by the waterfall */
} slit_t;

static slit_t S[DZ_SLOTS];

static double now_ms(void)
{
	struct timespec t;

	clock_gettime(CLOCK_MONOTONIC, &t);
	return t.tv_sec * 1e3 + t.tv_nsec / 1e6;
}

static slit_t *get(int d)
{
	slit_t *s;

	if (d < 0 || d >= DZ_SLOTS)
		return NULL;
	s = &S[d];
	if (!s->band) {			/* defaults */
		s->mode = S_ROW;
		s->band = 1;
		s->tiles = 8;
		s->every = 1;
		s->speed = 1.0;
		s->pos = 0.5;
		s->posf = 1;
	}
	return s;
}

/* ---- memory: rows of a slot, also past its end (waterfall) ---- */
typedef struct {
	int      slot, w, h;		/* geometry used for this frame */
	size_t   stride;
	uint8_t *p[2];			/* the slot and the next one */
} plane_t;

static uint8_t *row_at(const plane_t *pl, int y)
{
	size_t off = (size_t)y * pl->stride;
	int k = (int)(off / DZ_SLOT_PITCH);

	if (k > 1 || !pl->p[k])
		return NULL;
	return pl->p[k] + off % DZ_SLOT_PITCH;
}

static int plane_slot(plane_t *pl, int slot, int w, int h, size_t stride, int two)
{
	pl->slot = slot;
	pl->w = w;
	pl->h = h;
	pl->stride = stride;
	pl->p[0] = dz_slot(slot, DZ_SLOT_PITCH, NULL);
	pl->p[1] = two && slot + 1 < DZ_SLOTS ? dz_slot(slot + 1, DZ_SLOT_PITCH, NULL) : NULL;
	return pl->p[0] && (!two || pl->p[1]) ? 0 : -1;
}

/* the source: a slot at the mode size, or the capture at its own size */
static int source(const slit_t *s, plane_t *pl)
{
	if (s->src == SRC_CAPTURE) {
		uint32_t a = dz_capture_addr();
		dz_vdma_regs r;

		if (!a || a < DZ_SLOT_BASE || (a - DZ_SLOT_BASE) % DZ_SLOT_PITCH ||
		    dz_capture_regs(&r) < 0 || !r.vsize)
			return -1;
		return plane_slot(pl, (int)((a - DZ_SLOT_BASE) / DZ_SLOT_PITCH),
				  (int)(r.hsize & 0xFFFF) / DZ_BPP, (int)(r.vsize & 0x1FFF),
				  r.stride & 0xFFFF, 0);
	}
	return plane_slot(pl, s->src, dz_geom_w(), dz_geom_h(), dz_geom_stride(), 0);
}

static void copy_px(uint8_t *d, const uint8_t *s, size_t n)
{
	memcpy(d, s, n);
}

/* rows [sy, sy+n) of src -> rows [dy, dy+n) of dst, width min of both */
static void copy_rows(const plane_t *src, int sy, const plane_t *dst, int dy, int n)
{
	int w = src->w < dst->w ? src->w : dst->w;

	for (int k = 0; k < n; k++) {
		int y = sy + k, t = dy + k;
		const uint8_t *a;
		uint8_t *b;

		if (y < 0 || y >= src->h)
			continue;
		a = row_at(src, y);
		b = row_at(dst, t);
		if (a && b)
			copy_px(b, a, (size_t)w * 4);
	}
}

/* columns [sx, sx+n) of src -> columns [dx, dx+n), height min of both */
static void copy_cols(const plane_t *src, int sx, const plane_t *dst, int dx, int n)
{
	int h = src->h < dst->h ? src->h : dst->h;

	if (sx < 0 || dx < 0 || sx + n > src->w || dx + n > dst->w || n <= 0)
		return;
	for (int y = 0; y < h; y++) {
		const uint8_t *ra = row_at(src, y);
		uint8_t *rb = row_at(dst, y);

		if (!ra || !rb)
			continue;
		const uint32_t *a = (const uint32_t *)(ra + (size_t)sx * 4);
		uint32_t *b = (uint32_t *)(rb + (size_t)dx * 4);

		for (int k = 0; k < n; k++)
			b[k] = a[k];
	}
}

/* the waterfall writes rows H..2H-1, part of slot d + 1: not the black
 * slot 11, not the slot the capture writes. NULL = allowed */
static const char *waterfall_refused(int d)
{
	uint32_t a = dz_capture_addr();

	if (d + 1 >= DZ_SLOT_BLANK)
		return "waterfall needs the next slot (not the black slot 11): target 0-9";
	if (a && a == DZ_SLOT_ADDR(d + 1))
		return "waterfall needs the next slot, but the capture writes it: choose another target";
	return NULL;
}

static int wrap(int v, int n)
{
	v %= n;
	return v < 0 ? v + n : v;
}

static int pos_px(const slit_t *s, int size)
{
	int v = s->posf ? (int)lround(s->pos * (size - 1)) : (int)s->pos;

	return v < 0 ? 0 : v >= size ? size - 1 : v;
}

/* the waterfall's display offset; 0 rows = back to the crop alone */
static void set_scroll(slit_t *s, int d, int rows)
{
	disp_slot_scroll(d, rows);
	s->scrolled = rows != 0;
}

/* ---- row / col slits: map, then one read of the band, one write per line ---- */
static int     *lmap;			/* target line -> band line, -1 = untouched */
static size_t   lmap_n;
static uint32_t *band_buf;		/* the source band, cached (normal RAM) */
static size_t   band_n;

static int grow(void **p, size_t *have, size_t need)
{
	void *q;

	if (need <= *have)
		return 0;
	q = realloc(*p, need);
	if (!q)
		return -1;
	*p = q;
	*have = need;
	return 0;
}

static void slit_lines(const slit_t *s, const plane_t *src, int sp, const plane_t *dst,
		       long a, long b, int size, int band, int wf)
{
	int rows = s->mode == S_ROW;
	int nl = rows ? (wf ? 2 * size : size) + band : size;	/* target lines */
	int nb = rows ? (sp + band > src->h ? src->h - sp : band)	/* band lines in the source */
		      : (sp + band > src->w ? src->w - sp : band);
	int h = src->h < dst->h ? src->h : dst->h, w = src->w < dst->w ? src->w : dst->w;
	int lo = nl, hi = -1;

	if (nb <= 0 || grow((void **)&lmap, &lmap_n, (size_t)nl * sizeof(int)) < 0)
		return;
	for (int i = 0; i < nl; i++)
		lmap[i] = -1;
	for (long k = a; k != b && labs(k - a) <= size; k += b > a ? 1 : -1) {
		int t = wrap((int)(b > a ? k + 1 : k - 1), size);
		int n = rows ? band : (band > size - t ? size - t : band);

		for (int j = 0; j < n && j < nb; j++) {
			int r = t + j;

			lmap[r] = j;
			if (rows && wf)
				lmap[r + size] = j;
			if (r < lo)
				lo = r;
			if (r > hi)
				hi = r;
		}
	}
	if (hi < 0)
		return;
	if (rows) {
		size_t rb = (size_t)w * 4;

		if (grow((void **)&band_buf, &band_n, rb * (size_t)nb) < 0)
			return;
		for (int j = 0; j < nb; j++) {
			const uint8_t *r = row_at(src, sp + j);

			if (r)
				memcpy((uint8_t *)band_buf + rb * (size_t)j, r, rb);
		}
		for (int r = 0; r < nl; r++) {
			uint8_t *o = lmap[r] >= 0 ? row_at(dst, r) : NULL;

			if (o)
				memcpy(o, (uint8_t *)band_buf + rb * (size_t)lmap[r], rb);
		}
	} else {
		/* columns: the band of every source row once, then each target
		 * row gets its new columns [lo, hi] in one pass */
		if (hi >= w)
			hi = w - 1;
		if (grow((void **)&band_buf, &band_n, (size_t)h * (size_t)nb * 4) < 0)
			return;
		for (int y = 0; y < h; y++) {
			const uint8_t *r = row_at(src, y);

			if (r)
				memcpy(band_buf + (size_t)y * nb, r + (size_t)sp * 4, (size_t)nb * 4);
		}
		/* the new columns as segments of one band line each (made once
		 * per frame: few - the steps' line plus the last band), then per
		 * row constant fills in RAM and one copy per contiguous run.
		 * Single 4-byte stores to the uncached slot: ~25 ms for 250
		 * columns; a per-pixel lookup loop: ~40 ms at full width */
		static uint32_t rowbuf[1920];
		static struct { short x0, n, j, run_end; } seg[1920];
		int ns = 0;

		if (hi >= 1920)
			hi = 1919;
		for (int x = lo; x <= hi; ) {
			int j = lmap[x], x0 = x;

			if (j < 0) {
				x++;
				continue;
			}
			while (x <= hi && lmap[x] == j)
				x++;
			seg[ns].x0 = (short)x0;
			seg[ns].n = (short)(x - x0);
			seg[ns].j = (short)j;
			seg[ns].run_end = (short)(x > hi || lmap[x] < 0);	/* a copy after it */
			ns++;
		}
		for (int y = 0; y < h; y++) {
			uint32_t *o = (uint32_t *)row_at(dst, y);
			const uint32_t *c = band_buf + (size_t)y * nb;
			int run0 = -1;

			if (!o)
				continue;
			for (int k = 0; k < ns; k++) {
				uint32_t v = c[seg[k].j], *q = rowbuf + seg[k].x0;

				if (run0 < 0)
					run0 = seg[k].x0;
				for (int i = 0; i < seg[k].n; i++)
					q[i] = v;
				if (seg[k].run_end) {
					int e = seg[k].x0 + seg[k].n;

					memcpy(o + run0, rowbuf + run0, (size_t)(e - run0) * 4);
					run0 = -1;
				}
			}
		}
	}
}

static int frame(int d)
{
	slit_t *s = &S[d];
	plane_t src, dst;
	int W = dz_geom_w(), H = dz_geom_h(), band = s->band < 1 ? 1 : s->band;
	int wf = s->mode == S_ROW && s->scroll;
	double old = s->w;

	if (source(s, &src) < 0 || plane_slot(&dst, d, W, H, dz_geom_stride(), wf) < 0)
		return -1;
	switch (s->mode) {
	case S_ROW:
	case S_COL: {
		int size = s->mode == S_ROW ? H : W, sp = pos_px(s, s->mode == S_ROW ? src.h : src.w);
		long a = (long)floor(old), b;

		s->w = old + s->speed;
		b = (long)floor(s->w);
		/* one slit for each whole step crossed (fractional speeds: some
		 * frames write nothing); at most one target size per frame.
		 * 2026-11-20: the steps only fill a map "target line -> band
		 * line" (the last write wins, as before); then the source band
		 * is read ONCE and each target line written once. Before, every
		 * step read the source again from uncached memory: speed 250 in
		 * col mode = 250 x 720 uncached reads, ~400 ms a frame, and the
		 * pixel thread had no time left for /slit/<d>/stop. */
		if (b != a)
			slit_lines(s, &src, sp, &dst, a, b, size, band, wf);
		s->w = fmod(s->w, (double)size);
		if (s->w < 0)
			s->w += size;
		if (wf)
			set_scroll(s, d, wrap((int)floor(s->w) + 1, H));
		break;
	}
	case S_SCAN:
	case S_SCANV: {
		int size = s->mode == S_SCAN ? H : W, p = wrap((int)floor(old), size);

		if (s->mode == S_SCAN)
			copy_rows(&src, p, &dst, p, band > H - p ? H - p : band);
		else
			copy_cols(&src, p, &dst, p, band > W - p ? W - p : band);
		s->w = fmod(old + s->speed, (double)size);
		if (s->w < 0)
			s->w += size;
		break;
	}
	case S_TILES:
		for (int k = 0; k < s->tiles; k++) {
			int tw = band > W ? W : band, th = band > H ? H : band;
			int x = rand() % (W - tw + 1), y = rand() % (H - th + 1);

			for (int r = 0; r < th; r++) {
				const uint8_t *a = y + r < src.h && x + tw <= src.w ? row_at(&src, y + r) : NULL;
				uint8_t *b = row_at(&dst, y + r);

				if (a && b)
					copy_px(b + (size_t)x * 4, a + (size_t)x * 4, (size_t)tw * 4);
			}
		}
		break;
	}
	__sync_synchronize();		/* the VDMA reads DDR, it does not snoop */
	return 0;
}

static void clear(int d, int rows)
{
	plane_t dst;

	if (plane_slot(&dst, d, dz_geom_w(), rows, dz_geom_stride(), rows > dz_geom_h()) < 0)
		return;
	for (int y = 0; y < rows; y++) {
		uint32_t *r = (uint32_t *)row_at(&dst, y);

		for (int x = 0; r && x < dst.w; x++)
			r[x] = 0xFF000000u;
	}
	__sync_synchronize();
}

static void stop(int d, slit_t *s)
{
	s->run = 0;
	if (s->scrolled)
		set_scroll(s, d, 0);
}

void slit_tick(void)
{
	for (int d = 0; d < DZ_SLOTS; d++) {
		slit_t *s = &S[d];
		double t0;

		if (!s->run || ++s->cnt < s->every)
			continue;
		s->cnt = 0;
		if (dz_draw_movie_running(d)) {	/* a movie started on the target: it wins */
			stop(d, s);
			dzd_log("slit: slot %d stopped (a movie plays there now)\n", d);
			continue;
		}
		/* a save or a draw on the target made a paint buffer: the slit
		 * writes the slot itself, so that buffer is old at once - drop it
		 * (the next draw / save starts from the slot picture) */
		dz_draw_adopt(d);
		t0 = now_ms();
		if (frame(d) < 0) {
			stop(d, s);
			dzd_log("slit: slot %d stopped (source not readable)\n", d);
			continue;
		}
		s->ms = (float)(now_ms() - t0);
	}
}

/* ---- OSC ---- */
static double argd(const dz_arg *a)
{
	return a->type == 'f' ? a->f : a->type == 'i' ? a->i : 0.0;
}

static void status(int d, const slit_t *s)
{
	char p[40];

	snprintf(p, sizeof(p), "/slit/%d/status", d);
	dzd_reply(p, "iisifiiiiif", s->run, s->src == SRC_CAPTURE ? -2 : s->src, MODE[s->mode],
		  pos_px(s, s->mode == S_COL || s->mode == S_SCANV ? dz_geom_w() : dz_geom_h()),
		  (float)s->speed, s->band, s->tiles, s->every, s->scroll, (int)s->w, s->ms);
}

void slit_state(state_cb cb, void *ctx)
{
	char p[40];

	for (int d = 0; d < DZ_SLOTS; d++) {
		const slit_t *s = &S[d];

#define SP(x) (snprintf(p, sizeof(p), "/slit/%d/" x, d), p)
		if (!s->used)
			continue;
		st_emit(cb, ctx, NULL, SP("mode"), "s", MODE[s->mode]);
		if (s->posf)
			st_emit(cb, ctx, NULL, SP("pos"), "f", (float)s->pos);
		else
			st_emit(cb, ctx, NULL, SP("pos"), "i", (int)s->pos);
		st_emit(cb, ctx, NULL, SP("speed"), "f", (float)s->speed);
		st_emit(cb, ctx, NULL, SP("band"), "i", s->band);
		st_emit(cb, ctx, NULL, SP("tiles"), "i", s->tiles);
		st_emit(cb, ctx, NULL, SP("every"), "i", s->every);
		st_emit(cb, ctx, NULL, SP("scroll"), "i", s->scroll);
		if (s->run && s->src == SRC_CAPTURE)
			st_emit(cb, ctx, NULL, SP("run"), "s", "capture");
		else
			st_emit(cb, ctx, NULL, SP("run"), "i", s->run ? s->src : -1);
#undef SP
	}
}

int slit_dispatch(const dz_msg *m)
{
	int d, off = 0, n = m->n;
	slit_t *s;
	const char *op;

	if (sscanf(m->path, "/slit/%d/%n", &d, &off) != 1 || !off)
		return 0;
	op = m->path + off;
	s = get(d);
	if (!s) {
		dzd_reply("/error", "ss", "slot out of range", m->path);
		return 1;
	}
	if (strcmp(op, "status"))
		s->used = 1;
	if (!strcmp(op, "run")) {
		int src = s->src;

		if (n >= 1 && m->a[0].type == 's')
			src = !strcmp(m->a[0].s, "capture") ? SRC_CAPTURE : -1;
		else if (n >= 1)
			src = (int)argd(&m->a[0]);
		if (src < 0 || (src >= DZ_SLOTS && src != SRC_CAPTURE)) {	/* -1: stop */
			stop(d, s);
			return 1;
		}
		if (src == d) {
			dzd_reply("/error", "ss", "source = target", m->path);
			return 1;
		}
		if (s->mode == S_ROW && s->scroll && waterfall_refused(d)) {
			dzd_reply("/error", "ss", waterfall_refused(d), m->path);
			return 1;
		}
		s->src = src;
		dz_draw_movie_stop(d);	/* the target is written directly */
		dz_draw_adopt(d);	/* a later draw continues on the slit picture */
		if (s->mode == S_ROW && s->scroll)
			dz_draw_adopt(d + 1);	/* its picture changes too: a cue loads its image again */
		s->run = 1;
		s->cnt = 0;
		status(d, s);
		return 1;
	}
	if (!strcmp(op, "stop")) {
		stop(d, s);
	} else if (!strcmp(op, "mode") && n >= 1) {
		int k;

		for (k = 0; k < S_N; k++)
			if (m->a[0].type == 's' ? !strcmp(m->a[0].s, MODE[k]) : k == (int)argd(&m->a[0]))
				break;
		if (k == S_N) {
			dzd_reply("/error", "ss", "mode: row col scan scanv tiles", m->path);
			return 1;
		}
		if (s->scrolled && k != S_ROW)
			set_scroll(s, d, 0);
		s->mode = k;
	} else if (!strcmp(op, "pos") && n >= 1) {
		s->posf = m->a[0].type == 'f';
		s->pos = argd(&m->a[0]);
		if (s->posf)
			s->pos = s->pos < 0 ? 0 : s->pos > 1 ? 1 : s->pos;
	} else if (!strcmp(op, "speed") && n >= 1) {
		double v = argd(&m->a[0]);

		s->speed = v < -2000 ? -2000 : v > 2000 ? 2000 : v;
	} else if (!strcmp(op, "band") && n >= 1) {
		int v = (int)argd(&m->a[0]);

		s->band = v < 1 ? 1 : v > 1080 ? 1080 : v;
	} else if (!strcmp(op, "tiles") && n >= 1) {
		int v = (int)argd(&m->a[0]);

		s->tiles = v < 0 ? 0 : v > 4096 ? 4096 : v;
	} else if (!strcmp(op, "every") && n >= 1) {
		int v = (int)argd(&m->a[0]);

		s->every = v < 1 ? 1 : v > 600 ? 600 : v;
	} else if (!strcmp(op, "scroll") && n >= 1) {
		int v = (int)argd(&m->a[0]) != 0;

		if (v && waterfall_refused(d)) {
			dzd_reply("/error", "ss", waterfall_refused(d), m->path);
			return 1;
		}
		if (v)
			dz_draw_adopt(d + 1);
		if (!v && s->scrolled)
			set_scroll(s, d, 0);
		s->scroll = v;
	} else if (!strcmp(op, "clear")) {
		clear(d, s->mode == S_ROW && s->scroll ? 2 * dz_geom_h() : dz_geom_h());
		s->w = 0;
	} else if (!strcmp(op, "status")) {
		status(d, s);
	} else {
		dzd_reply("/error", "ss", "unknown (see sw/debazd/slit.c)", m->path);
	}
	return 1;
}

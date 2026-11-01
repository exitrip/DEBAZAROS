/*
 * ascii.c - text-mode picture of a slot (2026-10-30). Reads a source slot
 * (movie, capture, painting: anything a display can show) and draws it as
 * a grid of characters into a target slot, once or every k frames.
 *
 * Cost: the source is read at 4 points per cell (8 for braille and half;
 * the slot memory is uncached: slow to read). Only the cells that changed
 * since the last frame are drawn and copied to the slot; a full redraw
 * after a setting change and every 120 frames. A9, still picture: 160 cols
 * ~9 ms, 80 cols ~2.5 ms, 40 cols ~1 ms; braille 160 cols ~17 ms. With a
 * movie decoding on both cores, the wall time per frame varies a lot.
 * /ascii/<d>/status gives the time of the last frame in ms.
 *
 * Cells are cw x 2cw pixels, cw = width / cols (a terminal's proportions);
 * the grid is centred, the rest is bg.
 *
 *   /ascii/<d>/run i:src         draw slot src into slot d every k frames
 *                                (refused while a movie plays in slot d; a
 *                                movie started there later stops it)
 *   /ascii/<d>/once i:src        one frame
 *   /ascii/<d>/stop
 *   /ascii/<d>/cols i:n          4..320 (default 80; 1280 wide: 16 x 32 px cells)
 *   /ascii/<d>/mode s:name       ascii   " .:-=+*#%@" in the pixel font
 *                                shade   " ░▒▓█" (drawn, no font needed)
 *                                braille 2 x 4 dots per cell (level = threshold)
 *                                half    "▀": two colour pixels per cell
 *                                chars   the /chars string
 *   /ascii/<d>/chars s:"text" [s:"font"]   any UTF-8 characters, as a ramp;
 *                                drawn with the TrueType font (default
 *                                DZ_FONT_DEFAULT), the pixel font when there
 *                                is no font file. Sorted by ink: the order
 *                                does not matter. Sets mode chars.
 *   /ascii/<d>/color i:c         0 = fg on bg, 1 = the cell's colour,
 *                                2 = the cell's colour at full brightness
 *   /ascii/<d>/fg r g b, /bg r g b    (0..255 or 0..1)
 *   /ascii/<d>/level f           0..1: braille dot / mono half threshold (0.5)
 *   /ascii/<d>/invert i          dark = dense
 *   /ascii/<d>/every i:k         draw each k-th frame (default 2)
 *   /ascii/<d>/status            -> /ascii/<d>/status i:run i:src i:cols s:mode
 *                                   i:color i:fg i:bg f:level i:invert i:every
 *                                   s:chars s:font f:ms i:drawn i:chars
 *                                   (drawn = characters of the string that a
 *                                   font has; a cue stores the settings)
 */
#include "debazd.h"
#include "dz_draw_int.h"
#include "dz_hw.h"
#include "dz_map.h"
#include "dz_text.h"
#include "dz_vdma.h"

#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

enum { M_ASCII, M_SHADE, M_BRAILLE, M_HALF, M_CHARS, M_N };
static const char *const MODE[M_N] = { "ascii", "shade", "braille", "half", "chars" };
static const char RAMP[] = " .:-=+*#%@";

#define MAX_GLYPHS	64

typedef struct {
	int      run, src, cols, mode, color, invert, every, cnt;
	uint32_t fg, bg;		/* 0xRRGGBB */
	float    level, ms;
	char     chars[256], font[64];
	/* glyph masks for (mode, cw, ch, chars, font) */
	uint8_t *mask;
	int      nmask, kmode, kcw, kch;
	char     kchars[256], kfont[64];
	/* per cell: what was drawn last (glyph | colours); only changed cells
	 * are drawn and copied to the slot (2026-11-01: the full frame cost
	 * ~20 ms on the A9, ~40 ms next to a movie) */
	uint64_t *ck;
	int      ckn, ckvalid, frames;
	int      nchars, ndrawn;	/* chars mode: string length, glyphs found */
	int      used;			/* a setting was sent (the state model lists it) */
} asc_t;

static asc_t A[DZ_SLOTS];
static uint32_t *obuf;
static size_t obuf_n;

static asc_t *get(int d)
{
	asc_t *a;

	if (d < 0 || d >= DZ_SLOTS)
		return NULL;
	a = &A[d];
	if (!a->cols) {		/* defaults */
		a->cols = 80;
		a->every = 2;
		a->fg = 0xFFFFFF;
		a->level = 0.5f;
		snprintf(a->chars, sizeof(a->chars), "%s", RAMP);
	}
	return a;
}

static double now_ms(void)
{
	struct timespec ts;

	clock_gettime(CLOCK_MONOTONIC, &ts);
	return ts.tv_sec * 1e3 + ts.tv_nsec / 1e6;
}

/* ---- glyphs ---- */

static int utf8_cps(const char *s, uint32_t *cp, int max)
{
	const unsigned char *p = (const unsigned char *)s;
	int n = 0;

	while (*p && n < max) {
		uint32_t c = *p++;
		int k = c < 0x80 ? 0 : c < 0xE0 ? 1 : c < 0xF0 ? 2 : 3;

		if (k)
			c &= 0x3F >> k;
		for (; k && (*p & 0xC0) == 0x80; k--)
			c = (c << 6) | (*p++ & 0x3F);
		cp[n++] = c;
	}
	return n;
}

static int ink(const uint8_t *m, int n)
{
	int s = 0;

	for (int i = 0; i < n; i++)
		s += m[i];
	return s;
}

/* sort the masks by ink, light first (insertion sort: <= 64 glyphs) */
static void sort_ink(uint8_t *m, int n, int sz)
{
	uint8_t *t = malloc((size_t)sz);

	if (!t)
		return;
	for (int i = 1; i < n; i++) {
		int j = i, v = ink(m + (size_t)i * sz, sz);

		memcpy(t, m + (size_t)i * sz, (size_t)sz);
		while (j > 0 && ink(m + (size_t)(j - 1) * sz, sz) > v) {
			memcpy(m + (size_t)j * sz, m + (size_t)(j - 1) * sz, (size_t)sz);
			j--;
		}
		memcpy(m + (size_t)j * sz, t, (size_t)sz);
	}
	free(t);
}

static int build(asc_t *a, int cw, int ch)
{
	const char *chars = a->mode == M_ASCII ? RAMP : a->chars;
	int sz = cw * ch, n = 0;

	if (a->mask && a->kmode == a->mode && a->kcw == cw && a->kch == ch &&
	    !strcmp(a->kchars, chars) && !strcmp(a->kfont, a->font))
		return 0;
	free(a->mask);
	a->mask = NULL;
	a->nmask = 0;
	if (a->mode == M_HALF)
		goto done;
	a->mask = calloc(256, (size_t)sz);
	if (!a->mask)
		return -1;
	if (a->mode == M_SHADE) {		/* ' ' ░ ▒ ▓ █ as dither patterns */
		int b = cw / 4 > 1 ? cw / 4 : 1;

		for (int k = 0; k < 5; k++)
			for (int y = 0; y < ch; y++)
				for (int x = 0; x < cw; x++) {
					int bx = x / b, by = y / b, on;

					on = k == 0 ? 0 : k == 1 ? (!(bx & 1) && !(by & 1)) :
					     k == 2 ? ((bx + by) & 1) : k == 3 ? !(!(bx & 1) && !(by & 1)) : 1;
					a->mask[(size_t)k * sz + y * cw + x] = on ? 255 : 0;
				}
		n = 5;
	} else if (a->mode == M_BRAILLE) {	/* 256 patterns of 2 x 4 dots */
		float r = (cw / 4.0f < ch / 8.0f ? cw / 4.0f : ch / 8.0f) * 0.75f;

		for (int b = 0; b < 256; b++)
			for (int k = 0; k < 8; k++) {
				if (!(b & (1 << k)))
					continue;
				float cx = cw / 4.0f * (2 * (k & 1) + 1), cy = ch / 8.0f * (2 * (k >> 1) + 1);

				for (int y = 0; y < ch; y++)
					for (int x = 0; x < cw; x++) {
						float dx = x + 0.5f - cx, dy = y + 0.5f - cy;
						float c = (r - sqrtf(dx * dx + dy * dy) + 0.5f) * 255.0f;

						if (c > 0) {
							uint8_t *p = &a->mask[(size_t)b * sz + y * cw + x];
							int v = c > 255 ? 255 : (int)c;

							if (v > *p)
								*p = (uint8_t)v;
						}
					}
			}
		n = 256;
	} else {				/* ascii (pixel font) or chars */
		uint32_t cp[MAX_GLYPHS];
		int m = utf8_cps(chars, cp, MAX_GLYPHS);

		a->nchars = m;

		for (int i = 0; i < m; i++) {
			uint8_t *g = a->mask + (size_t)n * sz;
			int rc = a->mode == M_ASCII ? -1 : dz_ttf_glyph(a->font, cp[i], cw, ch, g);

			if (rc == -1)			/* no font file: the pixel font */
				rc = dz_font_glyph(cp[i], cw, ch, g);
			if (rc == 0 || cp[i] == ' ')
				n++;
		}
		a->ndrawn = n;
		if (n == 0)
			n = 1;				/* nothing drawable: blank */
		sort_ink(a->mask, n, sz);
	}
	a->nmask = n;
done:
	a->kmode = a->mode;
	a->kcw = cw;
	a->kch = ch;
	snprintf(a->kchars, sizeof(a->kchars), "%s", chars);
	snprintf(a->kfont, sizeof(a->kfont), "%s", a->font);
	return 0;
}

/* ---- one frame ---- */

static inline uint32_t mixc(uint32_t bg, uint32_t fg, unsigned m)
{
	if (m == 0)
		return bg;
	if (m >= 255)
		return fg;
	uint32_t rb = ((bg & 0xFF00FF) * (255 - m) + (fg & 0xFF00FF) * m) / 255;
	uint32_t g = ((bg & 0x00FF00) * (255 - m) + (fg & 0x00FF00) * m) / 255;

	return 0xFF000000u | (rb & 0xFF00FF) | (g & 0x00FF00);
}

/* cell colours are rounded to 32 steps per channel: more cells stay the
 * same from frame to frame (they are not drawn again) */
static uint32_t cell_color(const asc_t *a, unsigned r, unsigned g, unsigned b)
{
	if (a->color == 0)
		return 0xFF000000u | a->fg;
	r = (r & 0xF8) | (r >> 5);
	g = (g & 0xF8) | (g >> 5);
	b = (b & 0xF8) | (b >> 5);
	if (a->color == 2) {
		unsigned mx = r > g ? (r > b ? r : b) : (g > b ? g : b);

		if (mx) {
			r = r * 255 / mx;
			g = g * 255 / mx;
			b = b * 255 / mx;
		}
	}
	return 0xFF000000u | r << 16 | g << 8 | b;
}

/* one cell: 8 samples of the source -> what to draw (a key that changes
 * when the drawing changes) */
typedef struct {
	uint64_t       key;
	uint32_t       fg, bg, top, bot;	/* top / bot: half mode */
	const uint8_t *m;			/* glyph mask, NULL = half */
} cell_t;

static void cell_eval(const asc_t *a, const uint8_t *sp, size_t sstride, int x0, int y0,
		      int cw, int ch, uint32_t bg, unsigned thr, cell_t *o)
{
	unsigned R[8], G[8], B[8], L[8], sr = 0, sg = 0, sb = 0, sl = 0;
	/* braille and half use every point; the other modes only the mean:
	 * 4 points (each column, each row once). The slot is uncached: one
	 * read costs ~200 ns on the A9 (12 ms for 160 x 45 cells x 8) */
	int all = a->mode == M_BRAILLE || a->mode == M_HALF, np = all ? 8 : 4;

	for (int j = 0; j < np; j++) {	/* 2 x 4 sample points */
		int k = all ? j : (int[]){ 0, 3, 4, 7 }[j];
		int sx = x0 + cw * (2 * (k & 1) + 1) / 4;
		int sy = y0 + ch * (2 * (k >> 1) + 1) / 8;
		uint32_t v = *(const volatile uint32_t *)(sp + (size_t)sy * sstride + (size_t)sx * 4);

		R[k] = (v >> 16) & 255; G[k] = (v >> 8) & 255; B[k] = v & 255;
		L[k] = (2 * R[k] + 5 * G[k] + B[k]) >> 3;
		if (a->invert)
			L[k] = 255 - L[k];
		sr += R[k]; sg += G[k]; sb += B[k]; sl += L[k];
	}
	o->fg = cell_color(a, sr / np, sg / np, sb / np);
	o->bg = bg;
	o->m = NULL;
	if (a->mode == M_HALF) {
		if (a->color) {
			o->top = cell_color(a, (R[0] + R[1] + R[2] + R[3]) / 4, (G[0] + G[1] + G[2] + G[3]) / 4,
					    (B[0] + B[1] + B[2] + B[3]) / 4);
			o->bot = cell_color(a, (R[4] + R[5] + R[6] + R[7]) / 4, (G[4] + G[5] + G[6] + G[7]) / 4,
					    (B[4] + B[5] + B[6] + B[7]) / 4);
		} else {
			o->top = (L[0] + L[1] + L[2] + L[3]) / 4 > thr ? o->fg : bg;
			o->bot = (L[4] + L[5] + L[6] + L[7]) / 4 > thr ? o->fg : bg;
		}
		o->key = (uint64_t)(o->top & 0xFFFFFF) << 24 | (o->bot & 0xFFFFFF);
		return;
	}
	int idx;

	if (a->mode == M_BRAILLE) {
		idx = 0;
		for (int k = 0; k < 8; k++)
			if (L[k] > thr)
				idx |= 1 << k;
	} else {
		idx = (int)(sl / np) * a->nmask / 256;
		if (idx >= a->nmask)
			idx = a->nmask - 1;
	}
	o->m = a->mask + (size_t)idx * cw * ch;
	o->key = (uint64_t)1 << 63 | (uint64_t)idx << 24 | (o->fg & 0xFFFFFF);
}

/* draw a cell at o (row pitch W words) */
static void cell_draw(const cell_t *c, uint32_t *o, int W, int cw, int ch)
{
	for (int y = 0; y < ch; y++, o += W) {
		if (!c->m) {
			uint32_t v = y < ch / 2 ? c->top : c->bot;

			for (int x = 0; x < cw; x++)
				o[x] = v;
			continue;
		}
		const uint8_t *mr = c->m + y * cw;

		for (int x = 0; x < cw; x++)
			o[x] = mr[x] == 0 ? c->bg : mr[x] == 255 ? c->fg : mixc(c->bg, c->fg, mr[x]);
	}
}

static int render(int d)
{
	asc_t *a = get(d);
	int W, H;
	uint32_t *dst;
	const uint8_t *sp;
	size_t sstride = dz_geom_stride(), stride = 0;
	double t0 = now_ms();

	if (!a || a->src < 0 || a->src >= DZ_SLOTS)
		return -1;
	dst = dz_surf(d, &W, &H);	/* stops a movie that plays into d */
	if (!dst)
		return -1;
	sp = dz_slot(a->src, (size_t)(H - 1) * sstride + (size_t)W * 4, NULL);
	if (!sp)
		return -1;
	int cols = a->cols < 4 ? 4 : a->cols > W / 2 ? W / 2 : a->cols;
	int cw = W / cols, ch = 2 * cw;
	int rows = H / ch < 1 ? 1 : H / ch;
	int ox = (W - cols * cw) / 2, oy = (H - rows * ch) / 2;
	uint32_t bg = 0xFF000000u | a->bg;
	unsigned thr = (unsigned)(a->level * 255.0f + 0.5f);
	cell_t c;

	if (oy < 0)
		oy = 0;
	if (rows * ch > H)
		rows = H / ch;
	if (build(a, cw, ch) < 0)
		return -1;
	int plain = dz_surf_plain(d);
	uint8_t *dev = plain ? dz_surf_dev(d, &stride) : NULL;

	if (dev) {
		/* changed cells only, drawn straight into the painting buffer and
		 * copied to the slot; everything again after a change of the
		 * geometry or the settings, and every 120 frames */
		int n = cols * rows, full;

		if (a->ckn != n) {
			free(a->ck);
			a->ck = calloc((size_t)n, sizeof(*a->ck));
			a->ckn = a->ck ? n : 0;
			a->ckvalid = 0;
			if (!a->ck)
				return -1;
		}
		full = !a->ckvalid || ++a->frames % 120 == 0;
		if (full) {
			for (int y = 0; y < H; y++) {
				uint32_t *row = dst + (size_t)y * W;
				int inside = y >= oy && y < oy + rows * ch;

				for (int x = 0; x < W; x++)
					if (!inside || x < ox || x >= ox + cols * cw)
						row[x] = bg;
				if (!inside)
					memcpy(dev + (size_t)y * stride, row, (size_t)W * 4);
				else {
					memcpy(dev + (size_t)y * stride, row, (size_t)ox * 4);
					memcpy(dev + (size_t)y * stride + (size_t)(ox + cols * cw) * 4,
					       row + ox + cols * cw, (size_t)(W - ox - cols * cw) * 4);
				}
			}
		}
		for (int r = 0; r < rows; r++)
			for (int k = 0; k < cols; k++) {
				int x0 = ox + k * cw, y0 = oy + r * ch;
				uint64_t *ck = &a->ck[r * cols + k];

				cell_eval(a, sp, sstride, x0, y0, cw, ch, bg, thr, &c);
				if (!full && *ck == c.key)
					continue;
				*ck = c.key;
				cell_draw(&c, dst + (size_t)y0 * W + x0, W, cw, ch);
				for (int y = y0; y < y0 + ch; y++)
					memcpy(dev + (size_t)y * stride + (size_t)x0 * 4,
					       dst + (size_t)y * W + x0, (size_t)cw * 4);
			}
		a->ckvalid = 1;
		__sync_synchronize();
		dz_surf_clean(d);
		a->ms = (float)(now_ms() - t0);
		return 0;
	}

	/* alpha or a blend mode on the surface: a whole frame, then put */
	if (obuf_n < (size_t)W * H) {
		free(obuf);
		obuf = malloc((size_t)W * H * 4);
		obuf_n = obuf ? (size_t)W * H : 0;
		if (!obuf)
			return -1;
	}
	for (size_t i = 0; i < (size_t)W * H; i++)
		obuf[i] = bg;
	for (int r = 0; r < rows; r++)
		for (int k = 0; k < cols; k++) {
			int x0 = ox + k * cw, y0 = oy + r * ch;

			cell_eval(a, sp, sstride, x0, y0, cw, ch, bg, thr, &c);
			cell_draw(&c, obuf + (size_t)y0 * W + x0, W, cw, ch);
		}
	for (size_t i = 0; i < (size_t)W * H; i++)
		dz_surf_put(d, &dst[i], obuf[i], 256);
	dz_surf_dirty(d, 0, 0, W, H);
	dz_surf_finish(d);
	a->ckvalid = 0;
	a->ms = (float)(now_ms() - t0);
	return 0;
}

void ascii_tick(void)
{
	for (int d = 0; d < DZ_SLOTS; d++) {
		asc_t *a = &A[d];

		if (!a->run || ++a->cnt < a->every)
			continue;
		a->cnt = 0;
		if (dz_draw_movie_running(d)) {	/* a movie started on the target: it wins */
			a->run = 0;
			dzd_log("ascii: slot %d stopped (a movie plays there now)\n", d);
			continue;
		}
		if (render(d) < 0) {
			a->run = 0;
			dzd_log("ascii: slot %d stopped (source %d not readable)\n", d, a->src);
		}
	}
}

/* ---- OSC ---- */

static double argd(const dz_arg *a)
{
	return a->type == 'f' ? (double)a->f : a->type == 'i' ? (double)a->i : 0.0;
}

/* r g b as 0..255 ints or 0..1 floats */
static int arg_rgb(const dz_msg *m, uint32_t *out)
{
	unsigned c[3];

	if (m->n < 3)
		return -1;
	for (int i = 0; i < 3; i++) {
		double v = argd(&m->a[i]);

		if (m->a[i].type == 'f')
			v *= 255.0;
		c[i] = v < 0 ? 0 : v > 255 ? 255 : (unsigned)(v + 0.5);
	}
	*out = c[0] << 16 | c[1] << 8 | c[2];
	return 0;
}

static void status(int d, const asc_t *a)
{
	char p[48];

	snprintf(p, sizeof(p), "/ascii/%d/status", d);
	dzd_reply(p, "iiisiiifiissfii", a->run, a->src, a->cols, MODE[a->mode], a->color,
		  (int)a->fg, (int)a->bg, a->level, a->invert, a->every, a->chars, a->font, a->ms,
		  a->ndrawn, a->nchars);
}

/* the state model (state.c): settings of the slots ever used, then run
 * <src> or run -1 (stop) for every slot */
void ascii_state(state_cb cb, void *ctx)
{
	char p[40], k[40];

	for (int d = 0; d < DZ_SLOTS; d++) {
		const asc_t *a = &A[d];

#define AP(x) (snprintf(p, sizeof(p), "/ascii/%d/" x, d), p)
		if (a->used) {			/* touched: its settings */
			st_emit(cb, ctx, NULL, AP("cols"), "i", a->cols);
			(void)k;		/* chars (it sets mode chars), then the mode */
			st_emit(cb, ctx, NULL, AP("chars"), "ss", a->chars, a->font);
			st_emit(cb, ctx, NULL, AP("mode"), "s", MODE[a->mode]);
			st_emit(cb, ctx, NULL, AP("color"), "i", a->color);
			st_emit(cb, ctx, NULL, AP("fg"), "iii", (int)(a->fg >> 16) & 255,
				(int)(a->fg >> 8) & 255, (int)a->fg & 255);
			st_emit(cb, ctx, NULL, AP("bg"), "iii", (int)(a->bg >> 16) & 255,
				(int)(a->bg >> 8) & 255, (int)a->bg & 255);
			st_emit(cb, ctx, NULL, AP("level"), "f", a->level);
			st_emit(cb, ctx, NULL, AP("invert"), "i", a->invert);
			st_emit(cb, ctx, NULL, AP("every"), "i", a->every);
		}
		st_emit(cb, ctx, NULL, AP("run"), "i", a->run ? a->src : -1);
#undef AP
	}
}

int ascii_dispatch(const dz_msg *m)
{
	int d, off = 0;
	asc_t *a;

	if (sscanf(m->path, "/ascii/%d/%n", &d, &off) != 1 || !off)
		return 0;
	const char *op = m->path + off;

	a = get(d);
	if (!a) {
		dzd_reply("/error", "ss", "slot out of range", m->path);
		return 1;
	}
	int n = m->n, i0 = n >= 1 ? (int)argd(&m->a[0]) : 0;

	if (!strcmp(op, "run") || !strcmp(op, "once")) {
		if (n >= 1 && i0 < 0 && op[0] == 'r') {	/* run -1 = stop (the state model) */
			a->run = 0;
			status(d, a);
			return 1;
		}
		a->used = 1;
		if (n >= 1)
			a->src = i0;
		if (dz_draw_movie_running(d)) {	/* drawing would stop the movie */
			dzd_reply("/error", "ss", "a movie plays in the target slot: stop it or choose another", m->path);
			return 1;
		}
		a->ckvalid = 0;
		if (render(d) < 0) {
			a->run = 0;
			dzd_reply("/error", "ss", "source slot not readable", m->path);
			return 1;
		}
		a->run = op[0] == 'r';
		a->cnt = 0;
	} else if (!strcmp(op, "stop")) {
		a->run = 0;
	} else if (strcmp(op, "status") && strcmp(op, "stop") && (a->used = 1, 0)) {
	} else if (!strcmp(op, "cols") && n >= 1) {
		a->cols = i0 < 4 ? 4 : i0 > 320 ? 320 : i0;
	} else if (!strcmp(op, "mode") && n >= 1) {
		int k;

		for (k = 0; k < M_N; k++)
			if (m->a[0].type == 's' ? !strcmp(m->a[0].s, MODE[k]) : k == i0)
				break;
		if (k == M_N) {
			dzd_reply("/error", "ss", "mode: ascii shade braille half chars", m->path);
			return 1;
		}
		a->mode = k;
	} else if (!strcmp(op, "chars") && n >= 1 && m->a[0].type == 's') {
		snprintf(a->chars, sizeof(a->chars), "%s", m->a[0].s);
		if (n >= 2 && m->a[1].type == 's')
			snprintf(a->font, sizeof(a->font), "%s", m->a[1].s);
		a->mode = M_CHARS;
	} else if (!strcmp(op, "color") && n >= 1) {
		a->color = i0 < 0 ? 0 : i0 > 2 ? 2 : i0;
	} else if (!strcmp(op, "fg") && !arg_rgb(m, &a->fg)) {
	} else if (!strcmp(op, "bg") && !arg_rgb(m, &a->bg)) {
	} else if (!strcmp(op, "level") && n >= 1) {
		double v = argd(&m->a[0]);
		a->level = v < 0 ? 0 : v > 1 ? 1 : (float)v;
	} else if (!strcmp(op, "invert") && n >= 1) {
		a->invert = i0 != 0;
	} else if (!strcmp(op, "every") && n >= 1) {
		a->every = i0 < 1 ? 1 : i0 > 600 ? 600 : i0;
	} else if (!strcmp(op, "status")) {
		status(d, a);
		return 1;
	} else {
		dzd_reply("/error", "ss", "bad arguments (see sw/debazd/ascii.c)", m->path);
		return 1;
	}
	a->ckvalid = 0;		/* a new setting: draw everything */
	status(d, a);
	return 1;
}

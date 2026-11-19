/*
 * dz_sprite.c - see dz_sprite.h.
 */
#define _GNU_SOURCE
#include "dz_sprite.h"
#include "dz_draw.h"
#include "dz_draw_int.h"
#include "dz_hw.h"
#include "dz_map.h"
#include "dz_vdma.h"
#include "dz_text.h"

#include <math.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define MIPS 3			/* 1/2, 1/4, 1/8 size copies */

typedef struct {
	int       w, h;
	uint32_t *px;
	char      src[160];	/* where it came from (dz_sprite_src) */
	uint32_t *mip[MIPS];	/* box-filtered smaller copies, made on first use */
	int       mw[MIPS], mh[MIPS];
	dz_sprite_rec rec;	/* how it was made (state) */
} sprite_t;

static void mips_free(sprite_t *s)
{
	for (int k = 0; k < MIPS; k++) {
		free(s->mip[k]);
		s->mip[k] = NULL;
		s->mw[k] = s->mh[k] = 0;
	}
}

/* level k (1..MIPS) = half of level k-1, colours averaged by alpha;
 * NULL if too small or no memory */
static const uint32_t *mip(sprite_t *s, int k, int *w, int *h)
{
	const uint32_t *src = k == 1 ? s->px : s->mip[k - 2];
	int sw = k == 1 ? s->w : s->mw[k - 2], sh = k == 1 ? s->h : s->mh[k - 2];
	int dw = sw / 2, dh = sh / 2;
	uint32_t *d;

	if (!s->mip[k - 1]) {
		if (!src || dw < 4 || dh < 4)
			return NULL;
		d = malloc((size_t)dw * dh * 4);
		if (!d)
			return NULL;
		for (int y = 0; y < dh; y++)
			for (int x = 0; x < dw; x++) {
				const uint32_t *a = src + (size_t)(2 * y) * sw + 2 * x, *b = a + sw;
				uint32_t q[4] = { a[0], a[1], b[0], b[1] };
				unsigned sa = 0, sr = 0, sg = 0, sb = 0;

				for (int i = 0; i < 4; i++) {
					unsigned al = q[i] >> 24;

					sa += al;
					sr += ((q[i] >> 16) & 0xFF) * al;
					sg += ((q[i] >> 8) & 0xFF) * al;
					sb += (q[i] & 0xFF) * al;
				}
				d[(size_t)y * dw + x] = sa ? ((sa / 4) << 24) | ((sr / sa) << 16) |
							     ((sg / sa) << 8) | (sb / sa) : 0;
			}
		s->mip[k - 1] = d;
		s->mw[k - 1] = dw;
		s->mh[k - 1] = dh;
	}
	*w = s->mw[k - 1];
	*h = s->mh[k - 1];
	return s->mip[k - 1];
}

static sprite_t S[DZ_SPRITES];

static sprite_t *sp(int id)
{
	return (id >= 0 && id < DZ_SPRITES) ? &S[id] : NULL;
}

void dz_sprite_free(int id)
{
	sprite_t *s = sp(id);

	if (s) {
		free(s->px);
		mips_free(s);
		memset(s, 0, sizeof(*s));
	}
}

int dz_sprite_set(int id, int w, int h, uint32_t *px)
{
	sprite_t *s = sp(id);

	if (!s || !px || w <= 0 || h <= 0) {
		free(px);
		return -1;
	}
	dz_sprite_free(id);
	s->w = w;
	s->h = h;
	s->px = px;
	return 0;
}

const dz_sprite_rec *dz_sprite_get_rec(int id)
{
	sprite_t *s = sp(id);

	return s && s->px ? &s->rec : NULL;
}

const char *dz_sprite_src(int id)
{
	sprite_t *s = sp(id);

	return s && s->px ? s->src : NULL;
}

static void note(int id, const char *fmt, ...) __attribute__((format(printf, 2, 3)));
static void note(int id, const char *fmt, ...)
{
	sprite_t *s = sp(id);
	va_list ap;

	if (!s || !s->px)
		return;
	va_start(ap, fmt);
	vsnprintf(s->src, sizeof(s->src), fmt, ap);
	va_end(ap);
}

int dz_sprite_size(int id, int *w, int *h)
{
	sprite_t *s = sp(id);

	if (!s || !s->px)
		return -1;
	*w = s->w;
	*h = s->h;
	return 0;
}

/* same rule as images: a plain file name inside DZ_IMG_DIR */
static int name_ok(const char *n)
{
	if (!n || !*n || *n == '.' || strlen(n) > 96 || strstr(n, ".."))
		return 0;
	for (const char *p = n; *p; p++)
		if (!((*p >= 'a' && *p <= 'z') || (*p >= 'A' && *p <= 'Z') ||
		      (*p >= '0' && *p <= '9') || *p == '.' || *p == '_' || *p == '-'))
			return 0;
	return 1;
}

int dz_sprite_load(int id, const char *name, int w, int h)
{
	char cmd[640];
	uint32_t *px;
	FILE *fp;
	size_t n;

	if (!sp(id) || !name_ok(name))
		return -1;
	if (w <= 0 || h <= 0) {		/* native size */
		snprintf(cmd, sizeof(cmd), "ffprobe -v error -select_streams v:0 "
			 "-show_entries stream=width,height -of csv=p=0 '%s/%s'",
			 DZ_IMG_DIR, name);
		fp = popen(cmd, "r");
		if (!fp)
			return -1;
		if (fscanf(fp, "%d,%d", &w, &h) != 2)
			w = h = 0;
		pclose(fp);
	}
	if (w <= 0 || h <= 0 || w > DZ_SPRITE_MAX || h > DZ_SPRITE_MAX)
		return -1;
	px = malloc((size_t)w * h * 4);
	if (!px)
		return -1;
	snprintf(cmd, sizeof(cmd), "ffmpeg -nostdin -hide_banner -loglevel error -i "
		 "'%s/%s' -frames:v 1 -vf scale=%d:%d -pix_fmt bgra -f rawvideo pipe:1",
		 DZ_IMG_DIR, name, w, h);
	fp = popen(cmd, "r");
	if (!fp) {
		free(px);
		return -1;
	}
	n = fread(px, 4, (size_t)w * h, fp);
	pclose(fp);
	if (n != (size_t)w * h) {
		free(px);
		return -1;
	}
	return dz_sprite_set(id, w, h, px);
}

int dz_sprite_grab(int id, int slot, int x, int y, int w, int h)
{
	const uint8_t *dev;
	uint32_t *px;
	const size_t st = dz_geom_stride();	/* the running mode's line pitch */

	if (!sp(id) || w <= 0 || h <= 0 || x < 0 || y < 0 ||	/* inside the slot */
	    (size_t)(x + w) * DZ_BPP > st || (size_t)(y + h) * st > DZ_SLOT_PITCH)
		return -1;
	dev = dz_slot(slot, DZ_SLOT_PITCH, NULL);
	px = dev ? malloc((size_t)w * h * 4) : NULL;
	if (!px)
		return -1;
	for (int r = 0; r < h; r++) {
		uint32_t *row = px + (size_t)r * w;

		memcpy(row, dev + (size_t)(y + r) * st + (size_t)x * 4, (size_t)w * 4);
		for (int c = 0; c < w; c++)
			row[c] |= 0xFF000000u;		/* opaque */
	}
	return dz_sprite_set(id, w, h, px);
}

int dz_sprite_key(int id, uint8_t r, uint8_t g, uint8_t b, int tol)
{
	sprite_t *s = sp(id);

	if (!s || !s->px)
		return -1;
	for (size_t k = 0; k < (size_t)s->w * s->h; k++) {
		uint32_t v = s->px[k];
		int dr = (int)((v >> 16) & 0xFF) - r, dg = (int)((v >> 8) & 0xFF) - g;
		int db = (int)(v & 0xFF) - b;

		if (abs(dr) <= tol && abs(dg) <= tol && abs(db) <= tol)
			s->px[k] = v & 0x00FFFFFFu;	/* alpha 0 */
	}
	mips_free(s);				/* the smaller copies are made again */
	return 0;
}

int dz_sprite_draw(int id, int slot, float cx, float cy, float scale, float angle,
		   float alpha)
{
	sprite_t *s = sp(id);
	uint32_t *dst;
	int W, H, x0, y0, x1, y1;
	float ca, sa, hw, hh, ex, ey;
	unsigned a8;

	const uint32_t *tex;
	int tw, th, plain;
	float sc;

	if (!s || !s->px || scale <= 0.0f)
		return -1;
	/* below half size: a box-filtered smaller copy (2026-11-20): fewer cache
	 * misses (a 256 px sprite at 0.35 read every 3rd texel of 256 KB) and
	 * less aliasing; the effective scale stays above 0.5 */
	tex = s->px; tw = s->w; th = s->h; sc = scale;
	for (int k = 1; k <= MIPS && sc < 0.5f; k++) {
		int mw, mh;
		const uint32_t *m = mip(s, k, &mw, &mh);

		if (!m)
			break;
		tex = m; tw = mw; th = mh;
		sc = scale * (float)s->w / (float)mw;
	}
	alpha = alpha < 0.0f ? 0.0f : (alpha > 1.0f ? 1.0f : alpha);
	a8 = (unsigned)(alpha * 256.0f + 0.5f);
	ca = cosf(angle * (float)M_PI / 180.0f);
	sa = sinf(angle * (float)M_PI / 180.0f);
	hw = tw * sc * 0.5f;
	hh = th * sc * 0.5f;
	ex = fabsf(hw * ca) + fabsf(hh * sa);	/* half extent of the rotated box */
	ey = fabsf(hw * sa) + fabsf(hh * ca);
	/* on a live slot only the box is read (splat, the writer keeps running) */
	dst = dz_surf_splat_area(slot, &W, &H, (int)floorf(cx - ex) - 1, (int)floorf(cy - ey) - 1,
				 (int)ceilf(cx + ex) + 2, (int)ceilf(cy + ey) + 2);
	if (!dst)
		return -1;
	x0 = (int)floorf(cx - ex); x1 = (int)ceilf(cx + ex);
	y0 = (int)floorf(cy - ey); y1 = (int)ceilf(cy + ey);
	x0 = x0 < 0 ? 0 : x0; y0 = y0 < 0 ? 0 : y0;
	x1 = x1 > W - 1 ? W - 1 : x1; y1 = y1 > H - 1 ? H - 1 : y1;
	if (x1 < x0 || y1 < y0)
		return 0;			/* off screen */
	/* plain surface (alpha 1, blend normal) + alpha 1: opaque texels are
	 * stored directly, only the edges blend */
	plain = a8 >= 256 && dz_surf_plain(slot);
	{
		/* inverse map: dest -> sprite, 16.16 fixed point, stepped per pixel */
		float inv = 1.0f / sc;
		float ux = ca * inv, uy = sa * inv;	/* d(src x)/d(dst x), /d(dst y) */
		float vx = -sa * inv, vy = ca * inv;
		int32_t dux = (int32_t)(ux * 65536.0f), dvx = (int32_t)(vx * 65536.0f);
		int32_t sw = tw << 16, sh = th << 16;

		for (int y = y0; y <= y1; y++) {
			float dx = (float)x0 - cx, dy = (float)y - cy;
			float uf = dx * ux + dy * uy + tw * 0.5f, vf = dx * vx + dy * vy + th * 0.5f;
			float lo = 0.0f, hi = (float)(x1 - x0);
			int32_t u, v;
			uint32_t *row = dst + (size_t)y * W;
			int xa, xb;

			/* only the part of the row inside the rotated sprite (the
			 * corners of the box are empty: about half of it at 45 deg);
			 * one pixel of margin, the test per pixel stays */
			if (ux > 1e-6f || ux < -1e-6f) {
				float a = -uf / ux, b = ((float)tw - uf) / ux;
				if (a > b) { float t = a; a = b; b = t; }
				lo = a > lo ? a : lo; hi = b < hi ? b : hi;
			} else if (uf < 0.0f || uf >= (float)tw)
				continue;
			if (vx > 1e-6f || vx < -1e-6f) {
				float a = -vf / vx, b = ((float)th - vf) / vx;
				if (a > b) { float t = a; a = b; b = t; }
				lo = a > lo ? a : lo; hi = b < hi ? b : hi;
			} else if (vf < 0.0f || vf >= (float)th)
				continue;
			if (hi < lo)
				continue;
			xa = x0 + (int)floorf(lo) - 1;
			xb = x0 + (int)ceilf(hi) + 1;
			xa = xa < x0 ? x0 : xa;
			xb = xb > x1 ? x1 : xb;
			dx = (float)xa - cx;
			u = (int32_t)((dx * ux + dy * uy + tw * 0.5f) * 65536.0f);
			v = (int32_t)((dx * vx + dy * vy + th * 0.5f) * 65536.0f);

			for (int x = xa; x <= xb; x++, u += dux, v += dvx) {
				uint32_t p;
				unsigned pa;

				if (u < 0 || v < 0 || u >= sw || v >= sh)
					continue;
				p = tex[(size_t)(v >> 16) * tw + (u >> 16)];
				pa = (p >> 24) + ((p >> 31) & 1);	/* 0..256 */
				if (!pa)
					continue;
				if (plain && pa >= 256)
					row[x] = p | 0xFF000000u;
				else
					dz_surf_put(slot, &row[x], p | 0xFF000000u, (pa * a8) >> 8);
			}
		}
	}
	dz_surf_dirty(slot, x0, y0, x1 + 1, y1 + 1);
	dz_surf_finish(slot);
	return 0;
}

/* ---- OSC ---------------------------------------------------------------------- */
static float af(const dz_arg *a) { return a->type == 'f' ? a->f : (float)a->i; }
static uint8_t c8(const dz_arg *a)
{
	float v = a->type == 'f' ? a->f * 255.0f : (float)a->i;

	return v <= 0 ? 0 : (v >= 255 ? 255 : (uint8_t)(v + 0.5f));
}

int dz_sprite_dispatch(const dz_msg *m, int verbose)
{
	const dz_arg *a = m->a;
	int n = m->n, id, k = 0, rc = -1;
	char op[24] = "";

	if (sscanf(m->path, "/sprite/%d/%23s%n", &id, op, &k) != 2 || m->path[k])
		return 0;
	/* /sprite/<id>/src kind ... (the state: resume, cues, show files) =
	 * the same as /sprite/<id>/load|text|ttf with the args after kind */
	if (!strcmp(op, "src") && n >= 2 && a[0].type == 's' &&
	    (!strcmp(a[0].s, "file") || !strcmp(a[0].s, "text") || !strcmp(a[0].s, "ttf"))) {
		snprintf(op, sizeof(op), "%s", !strcmp(a[0].s, "file") ? "load" : a[0].s);
		a++;
		n--;
	}
	if (!strcmp(op, "load") && n >= 1 && a[0].type == 's')
		rc = dz_sprite_load(id, a[0].s, n >= 3 ? a[1].i : 0, n >= 3 ? a[2].i : 0);
	else if (!strcmp(op, "grab") && n >= 5)
		rc = dz_sprite_grab(id, a[0].i, a[1].i, a[2].i, a[3].i, a[4].i);
	else if (!strcmp(op, "text") && n >= 4 && a[3].type == 's')
		rc = dz_text_sprite(id, DZ_RGB8(c8(&a[0]), c8(&a[1]), c8(&a[2])), a[3].s,
				    n >= 5 ? a[4].i : 1, n >= 6 ? a[5].i : 16);
	else if (!strcmp(op, "ttf") && n >= 5 && a[4].type == 's')
		rc = dz_ttf_sprite(id, DZ_RGB8(c8(&a[0]), c8(&a[1]), c8(&a[2])), af(&a[3]),
				   a[4].s, n >= 6 && a[5].type == 's' ? a[5].s : NULL);
	else if (!strcmp(op, "key") && n >= 3)
		rc = dz_sprite_key(id, c8(&a[0]), c8(&a[1]), c8(&a[2]), n >= 4 ? a[3].i : 0);
	else if (!strcmp(op, "draw") && n >= 3)
		rc = dz_sprite_draw(id, a[0].i, af(&a[1]), af(&a[2]), n >= 4 ? af(&a[3]) : 1.0f,
				    n >= 5 ? af(&a[4]) : 0.0f, n >= 6 ? af(&a[5]) : 1.0f);
	else if (!strcmp(op, "free")) {
		dz_sprite_free(id);
		rc = 0;
	} else
		return 0;
	if (rc < 0)
		dz_surf_fail();
	else if (!strcmp(op, "load")) {	/* the source, for /sprite/<id> and /sprite/list */
		sprite_t *t = sp(id);

		note(id, "file:%s", a[0].s);
		t->rec.kind = 1;
		t->rec.w = n >= 3 ? a[1].i : 0;
		t->rec.h = n >= 3 ? a[2].i : 0;
		snprintf(t->rec.text, sizeof(t->rec.text), "%s", a[0].s);
	}
	else if (!strcmp(op, "grab"))
		note(id, "grab:%d %d %d %d %d", a[0].i, a[1].i, a[2].i, a[3].i, a[4].i);
	else if (!strcmp(op, "text") || !strcmp(op, "ttf")) {
		sprite_t *t = sp(id);
		int tt = op[1] == 't';		/* "ttf" */

		note(id, "%s:#%02x%02x%02x:%s", op, c8(&a[0]), c8(&a[1]), c8(&a[2]), tt ? a[4].s : a[3].s);
		t->rec.kind = tt ? 3 : 2;
		t->rec.r = c8(&a[0]);
		t->rec.g = c8(&a[1]);
		t->rec.b = c8(&a[2]);
		if (tt) {
			t->rec.size = af(&a[3]);
			snprintf(t->rec.text, sizeof(t->rec.text), "%s", a[4].s);
			snprintf(t->rec.face, sizeof(t->rec.face), "%s", n >= 6 && a[5].type == 's' ? a[5].s : "");
		} else {
			t->rec.scale = n >= 5 ? a[4].i : 1;
			t->rec.font = n >= 6 ? a[5].i : 16;
			snprintf(t->rec.text, sizeof(t->rec.text), "%s", a[3].s);
		}
	}
	else if (!strcmp(op, "key")) {
		sprite_t *t = sp(id);

		if (t && !strstr(t->src, " +key"))
			strncat(t->src, " +key", sizeof(t->src) - strlen(t->src) - 1);
		if (t) {
			t->rec.key = 1;
			t->rec.kr = c8(&a[0]);
			t->rec.kg = c8(&a[1]);
			t->rec.kb = c8(&a[2]);
			t->rec.ktol = n >= 4 ? a[3].i : 0;
		}
	}
	if (verbose)
		fprintf(stderr, "dz_sprite: %d %s%s\n", id, op, rc < 0 ? " FAILED" : "");
	return 1;
}

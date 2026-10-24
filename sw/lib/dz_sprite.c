/*
 * dz_sprite.c - see dz_sprite.h.
 */
#define _GNU_SOURCE
#include "dz_sprite.h"
#include "dz_draw.h"
#include "dz_draw_int.h"
#include "dz_hw.h"
#include "dz_map.h"
#include "dz_text.h"

#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct {
	int       w, h;
	uint32_t *px;
} sprite_t;

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

	if (!sp(id) || w <= 0 || h <= 0 || x < 0 || y < 0 ||
	    x + w > DZ_WIDTH || y + h > DZ_HEIGHT)
		return -1;
	dev = dz_slot(slot, (size_t)DZ_WIDTH * DZ_HEIGHT * DZ_BPP, NULL);
	px = dev ? malloc((size_t)w * h * 4) : NULL;
	if (!px)
		return -1;
	for (int r = 0; r < h; r++) {
		uint32_t *row = px + (size_t)r * w;

		memcpy(row, dev + ((size_t)(y + r) * DZ_WIDTH + x) * 4, (size_t)w * 4);
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

	if (!s || !s->px || scale <= 0.0f)
		return -1;
	dst = dz_surf(slot, &W, &H);
	if (!dst)
		return -1;
	alpha = alpha < 0.0f ? 0.0f : (alpha > 1.0f ? 1.0f : alpha);
	a8 = (unsigned)(alpha * 256.0f + 0.5f);
	ca = cosf(angle * (float)M_PI / 180.0f);
	sa = sinf(angle * (float)M_PI / 180.0f);
	hw = s->w * scale * 0.5f;
	hh = s->h * scale * 0.5f;
	ex = fabsf(hw * ca) + fabsf(hh * sa);	/* half extent of the rotated box */
	ey = fabsf(hw * sa) + fabsf(hh * ca);
	x0 = (int)floorf(cx - ex); x1 = (int)ceilf(cx + ex);
	y0 = (int)floorf(cy - ey); y1 = (int)ceilf(cy + ey);
	x0 = x0 < 0 ? 0 : x0; y0 = y0 < 0 ? 0 : y0;
	x1 = x1 > W - 1 ? W - 1 : x1; y1 = y1 > H - 1 ? H - 1 : y1;
	if (x1 < x0 || y1 < y0)
		return 0;			/* off screen */
	{
		/* inverse map: dest -> sprite, 16.16 fixed point, stepped per pixel */
		float inv = 1.0f / scale;
		float ux = ca * inv, uy = sa * inv;	/* d(src x)/d(dst x), /d(dst y) */
		float vx = -sa * inv, vy = ca * inv;
		int32_t dux = (int32_t)(ux * 65536.0f), dvx = (int32_t)(vx * 65536.0f);
		int32_t sw = s->w << 16, sh = s->h << 16;

		for (int y = y0; y <= y1; y++) {
			float dx = (float)x0 - cx, dy = (float)y - cy;
			int32_t u = (int32_t)((dx * ux + dy * uy + s->w * 0.5f) * 65536.0f);
			int32_t v = (int32_t)((dx * vx + dy * vy + s->h * 0.5f) * 65536.0f);
			uint32_t *row = dst + (size_t)y * W;

			for (int x = x0; x <= x1; x++, u += dux, v += dvx) {
				uint32_t p;
				unsigned pa;

				if (u < 0 || v < 0 || u >= sw || v >= sh)
					continue;
				p = s->px[(size_t)(v >> 16) * s->w + (u >> 16)];
				pa = (p >> 24) + ((p >> 31) & 1);	/* 0..256 */
				if (!pa)
					continue;
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
	if (verbose)
		fprintf(stderr, "dz_sprite: %d %s%s\n", id, op, rc < 0 ? " FAILED" : "");
	return 1;
}

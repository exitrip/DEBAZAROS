/*
 * dz_text.c - see dz_text.h.
 */
#define _GNU_SOURCE
#include "dz_text.h"
#include "dz_draw_int.h"
#include "dz_font_data.h"
#include "dz_sprite.h"

#include <dirent.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wunused-function"
#pragma GCC diagnostic ignored "-Wsign-compare"
#pragma GCC diagnostic ignored "-Wunused-parameter"
#define STB_TRUETYPE_IMPLEMENTATION
#define STBTT_STATIC
#include "../third_party/stb/stb_truetype.h"
#pragma GCC diagnostic pop

/* A pixel sink: draws coverage cov (0..256) of colour v at (x,y). The same
 * glyph code renders into a surface or into a new sprite. */
typedef struct {
	int       slot;		/* >= 0: surface */
	uint32_t *buf;		/* else: sprite buffer w*h */
	int       w, h, x0, y0, x1, y1;	/* bounds touched */
	uint32_t  v;
} sink_t;

static void sink_px(sink_t *k, uint32_t *base, int x, int y, unsigned cov)
{
	if (x < 0 || y < 0 || x >= k->w || y >= k->h || !cov)
		return;
	if (k->slot >= 0) {
		dz_surf_put(k->slot, &base[(size_t)y * k->w + x], k->v, cov);
	} else {			/* sprite: colour + coverage as alpha */
		uint32_t *p = &k->buf[(size_t)y * k->w + x];
		unsigned old = *p >> 24, a = cov >= 256 ? 255 : cov;

		*p = (k->v & 0x00FFFFFFu) | ((uint32_t)(a > old ? a : old) << 24);
	}
	if (x < k->x0) k->x0 = x;
	if (y < k->y0) k->y0 = y;
	if (x + 1 > k->x1) k->x1 = x + 1;
	if (y + 1 > k->y1) k->y1 = y + 1;
}

/* ---- pixel font ------------------------------------------------------------------ */
static void bm_font(int font, const uint8_t **data, int *w, int *h, int *stride)
{
	if (font == 32) {
		*data = &dz_font32[0][0]; *w = DZ_FONT32_W; *h = DZ_FONT32_H;
		*stride = sizeof(dz_font32[0]);
	} else {
		*data = &dz_font16[0][0]; *w = DZ_FONT16_W; *h = DZ_FONT16_H;
		*stride = sizeof(dz_font16[0]);
	}
}

/* size of a text block in pixels; "\n" or the two characters \ n break lines */
static void bm_measure(const char *s, int scale, int font, int *tw, int *th)
{
	const uint8_t *d;
	int gw, gh, st, col = 0, maxc = 0, lines = 1;

	bm_font(font, &d, &gw, &gh, &st);
	for (const char *p = s; *p; p++) {
		if (*p == '\n' || (p[0] == '\\' && p[1] == 'n')) {
			if (*p == '\\')
				p++;
			lines++;
			col = 0;
			continue;
		}
		if (++col > maxc)
			maxc = col;
	}
	*tw = maxc * gw * scale;
	*th = lines * gh * scale;
}

static void bm_render(sink_t *k, uint32_t *base, int x, int y, const char *s, int scale,
		      int font)
{
	const uint8_t *d;
	int gw, gh, st, cx = x, cy = y;

	bm_font(font, &d, &gw, &gh, &st);
	if (scale < 1)
		scale = 1;
	for (const char *p = s; *p; p++) {
		unsigned c = (unsigned char)*p;
		const uint8_t *g;
		int bpr = (gw + 7) / 8;

		if (c == '\n' || (p[0] == '\\' && p[1] == 'n')) {
			if (c == '\\')
				p++;
			cx = x;
			cy += gh * scale;
			continue;
		}
		if (c < 32 || c > 126)
			c = '?';
		g = d + (size_t)(c - 32) * st;
		for (int r = 0; r < gh; r++)
			for (int b = 0; b < gw; b++)
				if (g[r * bpr + b / 8] & (0x80 >> (b % 8)))
					for (int sy = 0; sy < scale; sy++)
						for (int sx = 0; sx < scale; sx++)
							sink_px(k, base, cx + b * scale + sx,
								cy + r * scale + sy, 256);
		cx += gw * scale;
	}
}

/* ---- TrueType -------------------------------------------------------------------- */
#define N_FONTS	4
static struct {
	char           name[100];
	unsigned char *data;
	stbtt_fontinfo info;
} F[N_FONTS];
static int f_next;

static int font_name_ok(const char *n)
{
	if (!n || !*n || *n == '.' || strlen(n) > 96 || strstr(n, ".."))
		return 0;
	for (const char *p = n; *p; p++)
		if (!((*p >= 'a' && *p <= 'z') || (*p >= 'A' && *p <= 'Z') ||
		      (*p >= '0' && *p <= '9') || *p == '.' || *p == '_' || *p == '-'))
			return 0;
	return 1;
}

/* name in DZ_FONT_DIR or its subfolders (3 levels: board ttf/, Ubuntu
 * truetype/<family>/) */
static FILE *font_find(const char *dir, const char *name, int depth)
{
	char p[512];
	FILE *fp;
	DIR *d;
	struct dirent *e;

	snprintf(p, sizeof(p), "%s/%s", dir, name);
	if ((fp = fopen(p, "rb")) || depth <= 0)
		return fp;
	d = opendir(dir);
	if (!d)
		return NULL;
	while (!fp && (e = readdir(d))) {
		if (e->d_name[0] == '.' || e->d_type == DT_REG)
			continue;
		snprintf(p, sizeof(p), "%s/%s", dir, e->d_name);
		fp = font_find(p, name, depth - 1);
	}
	closedir(d);
	return fp;
}

static FILE *font_open(const char *name)
{
	return font_find(DZ_FONT_DIR, name, 3);
}

static stbtt_fontinfo *font_get(const char *name)
{
	FILE *fp;
	long len;
	unsigned char *buf;
	int i;

	if (!name || !*name)
		name = DZ_FONT_DEFAULT;
	if (!font_name_ok(name))
		return NULL;
	for (i = 0; i < N_FONTS; i++)
		if (F[i].data && !strcmp(F[i].name, name))
			return &F[i].info;
	fp = font_open(name);
	if (!fp)
		return NULL;
	fseek(fp, 0, SEEK_END);
	len = ftell(fp);
	fseek(fp, 0, SEEK_SET);
	buf = (len > 0 && len < 32L * 1024 * 1024) ? malloc((size_t)len) : NULL;
	if (!buf || fread(buf, 1, (size_t)len, fp) != (size_t)len ||
	    !stbtt_InitFont(&F[f_next].info, buf, stbtt_GetFontOffsetForIndex(buf, 0))) {
		fclose(fp);
		free(buf);
		return NULL;
	}
	fclose(fp);
	i = f_next;
	f_next = (f_next + 1) % N_FONTS;
	free(F[i].data);			/* evict the oldest */
	F[i].data = buf;
	snprintf(F[i].name, sizeof(F[i].name), "%s", name);
	if (!stbtt_InitFont(&F[i].info, buf, stbtt_GetFontOffsetForIndex(buf, 0)))
		return NULL;
	return &F[i].info;
}

static void ttf_measure(stbtt_fontinfo *f, float px, const char *s, int *tw, int *th)
{
	float sc = stbtt_ScaleForPixelHeight(f, px), x = 0, maxx = 0;
	int asc, desc, gap, lines = 1;

	stbtt_GetFontVMetrics(f, &asc, &desc, &gap);
	for (const char *p = s; *p; p++) {
		int adv, lsb;

		if (*p == '\n' || (p[0] == '\\' && p[1] == 'n')) {
			if (*p == '\\')
				p++;
			lines++;
			x = 0;
			continue;
		}
		stbtt_GetCodepointHMetrics(f, (unsigned char)*p, &adv, &lsb);
		x += adv * sc;
		if (p[1])
			x += sc * stbtt_GetCodepointKernAdvance(f, (unsigned char)p[0],
								 (unsigned char)p[1]);
		if (x > maxx)
			maxx = x;
	}
	*tw = (int)(maxx + 2);
	*th = (int)((asc - desc + gap) * sc * lines + 2);
}

static void ttf_render(sink_t *k, uint32_t *base, stbtt_fontinfo *f, int x, int y, float px,
		       const char *s)
{
	float sc = stbtt_ScaleForPixelHeight(f, px), cx = (float)x;
	int asc, desc, gap, base_y;

	stbtt_GetFontVMetrics(f, &asc, &desc, &gap);
	base_y = y + (int)(asc * sc);
	for (const char *p = s; *p; p++) {
		int adv, lsb, x0, y0, x1, y1, gw, gh;
		unsigned char *bm;

		if (*p == '\n' || (p[0] == '\\' && p[1] == 'n')) {
			if (*p == '\\')
				p++;
			cx = (float)x;
			base_y += (int)((asc - desc + gap) * sc);
			continue;
		}
		stbtt_GetCodepointHMetrics(f, (unsigned char)*p, &adv, &lsb);
		stbtt_GetCodepointBitmapBox(f, (unsigned char)*p, sc, sc, &x0, &y0, &x1, &y1);
		bm = stbtt_GetCodepointBitmap(f, sc, sc, (unsigned char)*p, &gw, &gh, &x0, &y0);
		if (bm) {
			for (int r = 0; r < gh; r++)
				for (int c = 0; c < gw; c++) {
					unsigned v = bm[r * gw + c];

					if (v)
						sink_px(k, base, (int)cx + x0 + c, base_y + y0 + r,
							v + (v >> 7));	/* 255 -> 256 */
				}
			stbtt_FreeBitmap(bm, NULL);
		}
		cx += adv * sc;
		if (p[1])
			cx += sc * stbtt_GetCodepointKernAdvance(f, (unsigned char)p[0],
								  (unsigned char)p[1]);
	}
}

/* ---- public ------------------------------------------------------------------------ */
static uint32_t argb(dz_color c)
{
	return 0xFF000000u | ((uint32_t)c.r << 16) | ((uint32_t)c.g << 8) | c.b;
}

static int surf_sink(sink_t *k, int slot, dz_color c, uint32_t **base)
{
	memset(k, 0, sizeof(*k));
	*base = dz_surf(slot, &k->w, &k->h);
	if (!*base)
		return -1;
	k->slot = slot;
	k->v = argb(c);
	k->x0 = k->w; k->y0 = k->h;
	return 0;
}

static void surf_done(sink_t *k)
{
	if (k->x1 > k->x0 && k->y1 > k->y0)
		dz_surf_dirty(k->slot, k->x0, k->y0, k->x1, k->y1);
	dz_surf_finish(k->slot);
}

int dz_text_draw(int slot, dz_color c, int x, int y, const char *s, int scale, int font)
{
	sink_t k;
	uint32_t *base;

	if (!s || surf_sink(&k, slot, c, &base) < 0)
		return -1;
	bm_render(&k, base, x, y, s, scale, font);
	surf_done(&k);
	return 0;
}

int dz_ttf_draw(int slot, dz_color c, int x, int y, float px, const char *s,
		const char *font)
{
	stbtt_fontinfo *f = font_get(font);
	sink_t k;
	uint32_t *base;

	if (!f || !s || px < 2.0f || px > 1000.0f || surf_sink(&k, slot, c, &base) < 0)
		return -1;
	ttf_render(&k, base, f, x, y, px, s);
	surf_done(&k);
	return 0;
}

static int sprite_sink(sink_t *k, dz_color c, int w, int h)
{
	memset(k, 0, sizeof(*k));
	if (w <= 0 || h <= 0 || w > DZ_SPRITE_MAX || h > DZ_SPRITE_MAX)
		return -1;
	k->buf = calloc((size_t)w * h, 4);	/* transparent */
	if (!k->buf)
		return -1;
	for (size_t i = 0; i < (size_t)w * h; i++)
		k->buf[i] = argb(c) & 0x00FFFFFFu;
	k->slot = -1;
	k->w = w;
	k->h = h;
	k->v = argb(c);
	return 0;
}

int dz_text_sprite(int id, dz_color c, const char *s, int scale, int font)
{
	sink_t k;
	int w, h;

	if (!s || !*s)
		return -1;
	scale = scale < 1 ? 1 : scale;
	bm_measure(s, scale, font, &w, &h);
	if (sprite_sink(&k, c, w, h) < 0)
		return -1;
	bm_render(&k, k.buf, 0, 0, s, scale, font);
	return dz_sprite_set(id, w, h, k.buf);
}

int dz_ttf_sprite(int id, dz_color c, float px, const char *s, const char *font)
{
	stbtt_fontinfo *f = font_get(font);
	sink_t k;
	int w, h;

	if (!f || !s || !*s || px < 2.0f || px > 1000.0f)
		return -1;
	ttf_measure(f, px, s, &w, &h);
	if (sprite_sink(&k, c, w, h) < 0)
		return -1;
	ttf_render(&k, k.buf, f, 0, 0, px, s);
	return dz_sprite_set(id, w, h, k.buf);
}

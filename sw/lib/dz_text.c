/*
 * dz_text.c - see dz_text.h.
 */
#define _GNU_SOURCE
#include "dz_text.h"
#include "dz_draw_int.h"
#include "dz_font_data.h"
#include "dz_sprite.h"

#include <dirent.h>
#include <math.h>
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
#define N_FONTS	8	/* the fallbacks below + the fonts in use */
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

#ifndef DZ_FONT_FALLBACK	/* tried in order for a character the font lacks */
#define DZ_FONT_FALLBACK	"DejaVuSans.ttf", "FreeSerif.ttf", "DroidSansFallbackFull.ttf"
#endif
static const char *const fallback[] = { DZ_FONT_FALLBACK };

/* The font that draws cp: name if it has the glyph, else the first fallback
 * that has it, else name (its "missing" box) or NULL. Only valid until the
 * next font_get (a load can evict a cached font): look up per character. */
static stbtt_fontinfo *font_with(const char *name, uint32_t cp)
{
	stbtt_fontinfo *f = font_get(name);

	if (f && stbtt_FindGlyphIndex(f, (int)cp))
		return f;
	for (size_t i = 0; i < sizeof(fallback) / sizeof(fallback[0]); i++) {
		stbtt_fontinfo *g = font_get(fallback[i]);

		if (g && stbtt_FindGlyphIndex(g, (int)cp))
			return g;
	}
	return font_get(name);
}

/* line metrics of the font (or of the first fallback when it is missing):
 * ascent, line height and scale for px; -1 = no font at all */
static int line_metrics(const char *name, float px, float *asc, float *lh)
{
	stbtt_fontinfo *f = font_get(name);
	int a, d, g;

	for (size_t i = 0; !f && i < sizeof(fallback) / sizeof(fallback[0]); i++)
		f = font_get(fallback[i]);
	if (!f)
		return -1;
	float sc = stbtt_ScaleForPixelHeight(f, px);

	stbtt_GetFontVMetrics(f, &a, &d, &g);
	*asc = a * sc;
	*lh = (a - d + g) * sc;
	return 0;
}

/* next code point of UTF-8 text (2026-10-30: TrueType text was bytes only);
 * a broken sequence = U+FFFD */
static uint32_t utf8_next(const char **pp)
{
	const unsigned char *p = (const unsigned char *)*pp;
	uint32_t c = *p++;
	int n;

	if (c < 0x80)
		n = 0;
	else if (c < 0xC0 || c >= 0xF8)
		n = -1;
	else if (c < 0xE0)
		c &= 0x1F, n = 1;
	else if (c < 0xF0)
		c &= 0x0F, n = 2;
	else
		c &= 0x07, n = 3;
	for (; n > 0 && (*p & 0xC0) == 0x80; n--)
		c = (c << 6) | (*p++ & 0x3F);
	*pp = (const char *)p;
	return n ? 0xFFFD : c;
}

/* code point after p (for kerning), 0 at the end or at a new line */
static uint32_t utf8_peek(const char *p)
{
	return *p && *p != '\n' && !(p[0] == '\\' && p[1] == 'n') ? utf8_next(&p) : 0;
}

static void ttf_measure(const char *font, float px, const char *s, int *tw, int *th)
{
	float x = 0, maxx = 0, asc, lh;
	int lines = 1;

	if (line_metrics(font, px, &asc, &lh) < 0) {
		*tw = *th = 1;
		return;
	}
	for (const char *p = s; *p;) {
		int adv, lsb;

		if (*p == '\n' || (p[0] == '\\' && p[1] == 'n')) {
			p += *p == '\\' ? 2 : 1;
			lines++;
			x = 0;
			continue;
		}
		uint32_t c = utf8_next(&p), nx = utf8_peek(p);
		stbtt_fontinfo *f = font_with(font, c);

		if (!f)
			continue;
		float sc = stbtt_ScaleForPixelHeight(f, px);

		stbtt_GetCodepointHMetrics(f, (int)c, &adv, &lsb);
		x += adv * sc;
		if (nx && stbtt_FindGlyphIndex(f, (int)nx))
			x += sc * stbtt_GetCodepointKernAdvance(f, (int)c, (int)nx);
		if (x > maxx)
			maxx = x;
	}
	*tw = (int)(maxx + 2);
	*th = (int)(lh * lines + 2);
}

static void ttf_render(sink_t *k, uint32_t *base, const char *font, int x, int y, float px,
		       const char *s)
{
	float cx = (float)x, asc, lh;
	int base_y;

	if (line_metrics(font, px, &asc, &lh) < 0)
		return;
	base_y = y + (int)asc;
	for (const char *p = s; *p;) {
		int adv, lsb, x0, y0, gw, gh;
		unsigned char *bm;

		if (*p == '\n' || (p[0] == '\\' && p[1] == 'n')) {
			p += *p == '\\' ? 2 : 1;
			cx = (float)x;
			base_y += (int)lh;
			continue;
		}
		uint32_t c = utf8_next(&p), nx = utf8_peek(p);
		stbtt_fontinfo *f = font_with(font, c);	/* per character: fallbacks */

		if (!f)
			continue;
		float sc = stbtt_ScaleForPixelHeight(f, px);

		stbtt_GetCodepointHMetrics(f, (int)c, &adv, &lsb);
		bm = stbtt_GetCodepointBitmap(f, sc, sc, (int)c, &gw, &gh, &x0, &y0);
		if (bm) {
			for (int r = 0; r < gh; r++)
				for (int q = 0; q < gw; q++) {
					unsigned v = bm[r * gw + q];

					if (v)
						sink_px(k, base, (int)cx + x0 + q, base_y + y0 + r,
							v + (v >> 7));	/* 255 -> 256 */
				}
			stbtt_FreeBitmap(bm, NULL);
		}
		cx += adv * sc;
		if (nx && stbtt_FindGlyphIndex(f, (int)nx))
			cx += sc * stbtt_GetCodepointKernAdvance(f, (int)c, (int)nx);
	}
}

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
	float asc, lh;
	sink_t k;
	uint32_t *base;

	if (line_metrics(font, px, &asc, &lh) < 0 || !s || px < 2.0f || px > 1000.0f ||
	    surf_sink(&k, slot, c, &base) < 0)
		return -1;
	ttf_render(&k, base, font, x, y, px, s);
	surf_done(&k);
	return 0;
}

/* Rotated text (2026-10-29): the text is rendered into a coverage buffer of
 * its own size (the sprite sink: alpha = coverage), then put on the surface
 * rotated about its centre, angle in degrees clockwise (as dz_shape), with
 * bilinear coverage. x, y = top-left of the text before the rotation. */
static int sprite_sink(sink_t *k, dz_color c, int w, int h);

static int put_rotated(int slot, dz_color c, const uint32_t *src, int w, int h, int x, int y,
		       float angle)
{
	sink_t k;
	uint32_t *base;
	const double a = angle * M_PI / 180.0, ca = cos(a), sa = sin(a);
	const double cx = x + w / 2.0, cy = y + h / 2.0;
	/* the rotated box: half extents */
	const double ex = (fabs(ca) * w + fabs(sa) * h) / 2.0 + 1, ey = (fabs(sa) * w + fabs(ca) * h) / 2.0 + 1;

	if (surf_sink(&k, slot, c, &base) < 0)
		return -1;
	int y0 = (int)floor(cy - ey), y1 = (int)ceil(cy + ey), x0 = (int)floor(cx - ex), x1 = (int)ceil(cx + ex);
	for (int py = y0; py <= y1; py++) {
		if (py < 0 || py >= k.h)
			continue;
		for (int px = x0; px <= x1; px++) {
			if (px < 0 || px >= k.w)
				continue;
			/* back into the text: the inverse rotation about the centre */
			double dx = px + 0.5 - cx, dy = py + 0.5 - cy;
			double u = ca * dx + sa * dy + w / 2.0 - 0.5, v = -sa * dx + ca * dy + h / 2.0 - 0.5;
			int iu = (int)floor(u), iv = (int)floor(v);
			if (iu < -1 || iv < -1 || iu >= w || iv >= h)
				continue;
			double fu = u - iu, fv = v - iv, cov = 0;
			for (int j = 0; j < 2; j++)
				for (int i = 0; i < 2; i++) {
					int su = iu + i, sv = iv + j;
					if (su < 0 || sv < 0 || su >= w || sv >= h)
						continue;
					double wgt = (i ? fu : 1 - fu) * (j ? fv : 1 - fv);
					cov += wgt * (src[(size_t)sv * w + su] >> 24);
				}
			sink_px(&k, base, px, py, (unsigned)(cov * 256.0 / 255.0 + 0.5));
		}
	}
	surf_done(&k);
	return 0;
}

int dz_text_draw_rot(int slot, dz_color c, int x, int y, const char *s, int scale, int font,
		     float angle)
{
	sink_t k;
	int w, h, rc;

	if (fmodf(angle, 360.0f) == 0.0f)
		return dz_text_draw(slot, c, x, y, s, scale, font);
	if (!s || !*s)
		return -1;
	scale = scale < 1 ? 1 : scale;
	bm_measure(s, scale, font, &w, &h);
	if (sprite_sink(&k, c, w, h) < 0)
		return -1;
	bm_render(&k, k.buf, 0, 0, s, scale, font);
	rc = put_rotated(slot, c, k.buf, w, h, x, y, angle);
	free(k.buf);
	return rc;
}

int dz_ttf_draw_rot(int slot, dz_color c, int x, int y, float px, const char *s,
		    const char *font, float angle)
{
	float asc, lh;
	sink_t k;
	int w, h, rc;

	if (fmodf(angle, 360.0f) == 0.0f)
		return dz_ttf_draw(slot, c, x, y, px, s, font);
	if (line_metrics(font, px, &asc, &lh) < 0 || !s || !*s || px < 2.0f || px > 1000.0f)
		return -1;
	ttf_measure(font, px, s, &w, &h);
	if (sprite_sink(&k, c, w, h) < 0)
		return -1;
	ttf_render(&k, k.buf, font, 0, 0, px, s);
	rc = put_rotated(slot, c, k.buf, w, h, x, y, angle);
	free(k.buf);
	return rc;
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
	float asc, lh;
	sink_t k;
	int w, h;

	if (line_metrics(font, px, &asc, &lh) < 0 || !s || !*s || px < 2.0f || px > 1000.0f)
		return -1;
	ttf_measure(font, px, s, &w, &h);
	if (sprite_sink(&k, c, w, h) < 0)
		return -1;
	ttf_render(&k, k.buf, font, 0, 0, px, s);
	return dz_sprite_set(id, w, h, k.buf);
}

/* ---- one glyph in a cell (debazd ascii.c) ---------------------------------------- */

int dz_ttf_glyph(const char *font, uint32_t cp, int cw, int ch, uint8_t *mask)
{
	stbtt_fontinfo *f;
	int asc, desc, gap, gw, gh, x0, y0;
	unsigned char *bm;
	float sc, a, l;

	memset(mask, 0, (size_t)cw * ch);
	if (line_metrics(font, 16.0f, &a, &l) < 0)
		return -1;			/* no font file at all */
	f = font_with(font, cp);	/* the font, else a fallback that has cp */
	if (!f || !stbtt_FindGlyphIndex(f, (int)cp))
		return -2;			/* no font has such a glyph */
	stbtt_GetFontVMetrics(f, &asc, &desc, &gap);
	sc = (float)ch / (float)(asc - desc);
	{	/* narrow the scale when the glyph is wider than the cell */
		int bx0, by0, bx1, by1;

		stbtt_GetCodepointBitmapBox(f, (int)cp, sc, sc, &bx0, &by0, &bx1, &by1);
		if (bx1 - bx0 > cw)
			sc *= (float)cw / (float)(bx1 - bx0);
	}
	bm = stbtt_GetCodepointBitmap(f, sc, sc, (int)cp, &gw, &gh, &x0, &y0);
	if (!bm)
		return 0;			/* a space */
	int ox = (cw - gw) / 2, oy = (int)(asc * sc) + y0;

	for (int r = 0; r < gh; r++)
		for (int c = 0; c < gw; c++) {
			int x = ox + c, y = oy + r;

			if (x >= 0 && y >= 0 && x < cw && y < ch)
				mask[y * cw + x] = bm[r * gw + c];
		}
	stbtt_FreeBitmap(bm, NULL);
	return 0;
}

int dz_font_glyph(uint32_t cp, int cw, int ch, uint8_t *mask)
{
	const uint8_t *data;
	int fw, fh, stride;

	memset(mask, 0, (size_t)cw * ch);
	if (cp < 32 || cp > 126)
		return -2;
	bm_font(cw >= 16 ? 32 : 16, &data, &fw, &fh, &stride);
	const uint8_t *g = data + (size_t)(cp - 32) * stride;
	int bpr = (fw + 7) / 8;

	for (int y = 0; y < ch; y++)
		for (int x = 0; x < cw; x++) {
			int gx = x * fw / cw, gy = y * fh / ch;

			if (g[gy * bpr + gx / 8] & (0x80 >> (gx % 8)))
				mask[y * cw + x] = 255;
		}
	return 0;
}

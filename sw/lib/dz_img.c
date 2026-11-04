/*
 * dz_img.c - JPEG (TurboJPEG) and PNG (libpng simplified API) decode by
 * dlopen. See dz_img.h.
 */
#define _GNU_SOURCE
#include "dz_img.h"

#include <dlfcn.h>
#include <fcntl.h>
#include <pthread.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <sys/stat.h>
#include <unistd.h>

/* ---- TurboJPEG 2.x API (the handle is opaque: no struct layouts) ---- */
#define TJPF_BGRX		3
#define TJFLAG_FASTUPSAMPLE	256
#define TJFLAG_FASTDCT		2048
typedef void *tjhandle;
typedef struct { int num, denom; } tjsf;
static tjhandle (*tj_init)(void);
static int (*tj_header)(tjhandle, const unsigned char *, unsigned long, int *, int *, int *, int *);
static int (*tj_decode)(tjhandle, const unsigned char *, unsigned long, unsigned char *,
			int, int, int, int, int);
static char *(*tj_errstr)(tjhandle);
static tjsf *(*tj_factors)(int *);
static tjhandle (*tj_init_c)(void);
static int (*tj_compress)(tjhandle, const unsigned char *, int, int, int, int, unsigned char **,
			  unsigned long *, int, int, int);
static void (*tj_free)(unsigned char *);
#define TJSAMP_420		2

/* ---- libpng simplified API (struct png_image, PNG_IMAGE_VERSION 1) ---- */
#define PNG_IMAGE_VERSION	1
#define PNG_FORMAT_BGRA		0x13	/* COLOR | ALPHA | BGR */
typedef struct {
	void    *opaque;
	uint32_t version, width, height, format, flags, colormap_entries;
	uint32_t warning_or_error;
	char     message[64];
} png_image;
static int (*png_begin_file)(png_image *, const char *);
static int (*png_finish)(png_image *, const void *, void *, int32_t, void *);
static void (*png_free_img)(png_image *);

static pthread_once_t once = PTHREAD_ONCE_INIT;
static int have_jpeg, have_png, have_enc;
static tjsf *factors;
static int nfactors;

static void load_libs(void)
{
	void *j = dlopen("libturbojpeg.so.0", RTLD_NOW);
	void *p = dlopen("libpng16.so.16", RTLD_NOW);

	if (j) {
		tj_init = (tjhandle (*)(void))dlsym(j, "tjInitDecompress");
		tj_header = (int (*)(tjhandle, const unsigned char *, unsigned long, int *, int *,
				     int *, int *))dlsym(j, "tjDecompressHeader3");
		tj_decode = (int (*)(tjhandle, const unsigned char *, unsigned long, unsigned char *,
				     int, int, int, int, int))dlsym(j, "tjDecompress2");
		tj_errstr = (char *(*)(tjhandle))dlsym(j, "tjGetErrorStr2");
		tj_factors = (tjsf *(*)(int *))dlsym(j, "tjGetScalingFactors");
		have_jpeg = tj_init && tj_header && tj_decode && tj_errstr && tj_factors;
		if (have_jpeg)
			factors = tj_factors(&nfactors);
		if (!factors || nfactors <= 0)
			have_jpeg = 0;
		tj_init_c = (tjhandle (*)(void))dlsym(j, "tjInitCompress");
		tj_compress = (int (*)(tjhandle, const unsigned char *, int, int, int, int,
				       unsigned char **, unsigned long *, int, int, int))
			dlsym(j, "tjCompress2");
		tj_free = (void (*)(unsigned char *))dlsym(j, "tjFree");
		have_enc = tj_init_c && tj_compress && tj_free && tj_errstr;
	}
	if (p) {
		png_begin_file = (int (*)(png_image *, const char *))
			dlsym(p, "png_image_begin_read_from_file");
		png_finish = (int (*)(png_image *, const void *, void *, int32_t, void *))
			dlsym(p, "png_image_finish_read");
		png_free_img = (void (*)(png_image *))dlsym(p, "png_image_free");
		have_png = png_begin_file && png_finish && png_free_img;
	}
}

int dz_img_kind(const char *path)
{
	const char *e = path ? strrchr(path, '.') : NULL;

	if (!e)
		return DZ_IMG_NONE;
	if (!strcasecmp(e, ".jpg") || !strcasecmp(e, ".jpeg"))
		return DZ_IMG_JPEG;
	if (!strcasecmp(e, ".png"))
		return DZ_IMG_PNG;
	return DZ_IMG_NONE;
}

int dz_img_available(int kind)
{
	pthread_once(&once, load_libs);
	return kind == DZ_IMG_JPEG ? have_jpeg : kind == DZ_IMG_PNG ? have_png : 0;
}

static int fail(char *err, size_t n, const char *fmt, ...)
{
	va_list ap;

	if (err && n) {
		va_start(ap, fmt);
		vsnprintf(err, n, fmt, ap);
		va_end(ap);
	}
	return -1;
}

/* per thread: the TurboJPEG handle, the file buffer and a scratch picture */
static __thread tjhandle th_tj;
static __thread unsigned char *th_file;
static __thread size_t th_file_cap;
static __thread uint32_t *th_pic;
static __thread size_t th_pic_cap;

static unsigned char *read_file(const char *path, unsigned long *len)
{
	int fd = open(path, O_RDONLY | O_CLOEXEC);
	struct stat st;
	size_t got = 0;

	if (fd < 0)
		return NULL;
	if (fstat(fd, &st) || st.st_size <= 0) {
		close(fd);
		return NULL;
	}
	if ((size_t)st.st_size > th_file_cap) {
		unsigned char *b = realloc(th_file, (size_t)st.st_size);

		if (!b) {
			close(fd);
			return NULL;
		}
		th_file = b;
		th_file_cap = (size_t)st.st_size;
	}
	while (got < (size_t)st.st_size) {
		ssize_t r = read(fd, th_file + got, (size_t)st.st_size - got);

		if (r <= 0)
			break;
		got += (size_t)r;
	}
	close(fd);
	if (got != (size_t)st.st_size)
		return NULL;
	*len = (unsigned long)got;
	return th_file;
}

static uint32_t *scratch(size_t px)
{
	if (px > th_pic_cap) {
		uint32_t *p = realloc(th_pic, px * 4);

		if (!p)
			return NULL;
		th_pic = p;
		th_pic_cap = px;
	}
	return th_pic;
}

#define SCALED(d, f) (((d) * (f).num + (f).denom - 1) / (f).denom)

/* the largest TurboJPEG factor that fits w x h into dw x dh, else the smallest */
static tjsf fit_factor(int w, int h, int dw, int dh)
{
	tjsf best = { 0, 0 }, small = factors[0];

	for (int i = 0; i < nfactors; i++) {
		tjsf f = factors[i];

		if (f.num > f.denom)		/* never enlarge */
			continue;
		if ((double)f.num / f.denom < (double)small.num / small.denom || small.num > small.denom)
			small = f;
		if (SCALED(w, f) <= dw && SCALED(h, f) <= dh &&
		    (!best.denom || (double)f.num / f.denom > (double)best.num / best.denom))
			best = f;
	}
	return best.denom ? best : small;
}

/* the smallest factor whose result still covers minw x minh (1/1 if none) */
static tjsf cover_factor(int w, int h, int minw, int minh)
{
	tjsf best = { 1, 1 };

	for (int i = 0; i < nfactors; i++) {
		tjsf f = factors[i];

		if (f.num > f.denom)
			continue;
		if (SCALED(w, f) >= minw && SCALED(h, f) >= minh &&
		    (double)f.num / f.denom < (double)best.num / best.denom)
			best = f;
	}
	return best;
}

static void black_rows(uint8_t *dst, size_t stride, int x, int y, int w, int h)
{
	for (int r = 0; r < h; r++) {
		uint32_t *p = (uint32_t *)(dst + (size_t)(y + r) * stride) + x;

		for (int c = 0; c < w; c++)
			p[c] = 0xFF000000u;
	}
}

/* black around an iw x ih picture at ox, oy inside the dw x dh window */
static void borders(uint8_t *dst, size_t stride, int dw, int dh, int ox, int oy, int iw, int ih)
{
	black_rows(dst, stride, 0, 0, dw, oy);
	black_rows(dst, stride, 0, oy + ih, dw, dh - oy - ih);
	black_rows(dst, stride, 0, oy, ox, ih);
	black_rows(dst, stride, ox + iw, oy, dw - ox - iw, ih);
}

/* copy the centre of a w x h picture (opaque) into the window (centred
 * with black borders, or at the top left without them) */
static void put_centre(const uint32_t *pic, int w, int h, uint8_t *dst, size_t stride,
		       int dw, int dh, int flags)
{
	int cw = w < dw ? w : dw, ch = h < dh ? h : dh;
	int sx = (w - cw) / 2, sy = (h - ch) / 2, ox = (dw - cw) / 2, oy = (dh - ch) / 2;

	if (flags & DZ_IMG_TOPLEFT)
		ox = oy = 0;
	else
		borders(dst, stride, dw, dh, ox, oy, cw, ch);
	for (int r = 0; r < ch; r++)
		memcpy(dst + (size_t)(oy + r) * stride + (size_t)ox * 4,
		       pic + (size_t)(sy + r) * w + sx, (size_t)cw * 4);
}

static int jpeg_header(const char *path, unsigned char **buf, unsigned long *len,
		       int *w, int *h, char *err, size_t errlen)
{
	int ss, cs;

	if (!dz_img_available(DZ_IMG_JPEG))
		return fail(err, errlen, "no libturbojpeg.so.0");
	if (!th_tj && !(th_tj = tj_init()))
		return fail(err, errlen, "tjInitDecompress failed");
	*buf = read_file(path, len);
	if (!*buf)
		return fail(err, errlen, "cannot read file");
	if (tj_header(th_tj, *buf, *len, w, h, &ss, &cs))
		return fail(err, errlen, "not a JPEG: %s", tj_errstr(th_tj));
	return 0;
}

/* PNG into the scratch picture, alpha composited onto black */
static uint32_t *png_read(const char *path, int *w, int *h, char *err, size_t errlen)
{
	png_image im;
	uint32_t *pic;

	if (!dz_img_available(DZ_IMG_PNG)) {
		fail(err, errlen, "no libpng16.so.16");
		return NULL;
	}
	memset(&im, 0, sizeof(im));
	im.version = PNG_IMAGE_VERSION;
	if (!png_begin_file(&im, path)) {
		fail(err, errlen, "PNG: %s", im.message);
		return NULL;
	}
	im.format = PNG_FORMAT_BGRA;
	pic = scratch((size_t)im.width * im.height);
	if (!pic || !png_finish(&im, NULL, pic, 0, NULL)) {
		fail(err, errlen, "PNG: %s", pic ? im.message : "out of memory");
		png_free_img(&im);
		return NULL;
	}
	*w = (int)im.width;
	*h = (int)im.height;
	for (size_t i = 0, n = (size_t)*w * *h; i < n; i++) {
		uint32_t v = pic[i], a = v >> 24;

		if (a == 255)
			continue;
		pic[i] = 0xFF000000u | ((((v >> 16) & 0xFF) * a / 255) << 16) |
			 ((((v >> 8) & 0xFF) * a / 255) << 8) | ((v & 0xFF) * a / 255);
	}
	return pic;
}

int dz_img_fit(const char *path, uint8_t *dst, size_t stride, int dw, int dh,
	       int flags, char *err, size_t errlen)
{
	int kind = dz_img_kind(path), w, h;

	if (dw <= 0 || dh <= 0 || (size_t)dw * 4 > stride)
		return fail(err, errlen, "bad window");
	if (kind == DZ_IMG_JPEG) {
		unsigned char *buf;
		unsigned long len;
		int tf = (flags & DZ_IMG_FAST) ? TJFLAG_FASTDCT | TJFLAG_FASTUPSAMPLE : 0;
		tjsf f;
		int sw, sh;

		if (jpeg_header(path, &buf, &len, &w, &h, err, errlen))
			return -1;
		f = fit_factor(w, h, dw, dh);
		sw = SCALED(w, f);
		sh = SCALED(h, f);
		if (sw <= dw && sh <= dh) {	/* straight into the window */
			int ox = (dw - sw) / 2, oy = (dh - sh) / 2;

			if (flags & DZ_IMG_TOPLEFT)
				ox = oy = 0;
			else
				borders(dst, stride, dw, dh, ox, oy, sw, sh);
			if (tj_decode(th_tj, buf, len, dst + (size_t)oy * stride + (size_t)ox * 4,
				      sw, (int)stride, sh, TJPF_BGRX, tf))
				return fail(err, errlen, "JPEG: %s", tj_errstr(th_tj));
			return 0;
		}
		/* still larger than the window at 1/8: decode, then crop */
		uint32_t *pic = scratch((size_t)sw * sh);

		if (!pic)
			return fail(err, errlen, "out of memory");
		if (tj_decode(th_tj, buf, len, (unsigned char *)pic, sw, sw * 4, sh, TJPF_BGRX, tf))
			return fail(err, errlen, "JPEG: %s", tj_errstr(th_tj));
		put_centre(pic, sw, sh, dst, stride, dw, dh, flags);
		return 0;
	}
	if (kind == DZ_IMG_PNG) {
		uint32_t *pic = png_read(path, &w, &h, err, errlen);

		if (!pic)
			return -1;
		put_centre(pic, w, h, dst, stride, dw, dh, flags);
		return 0;
	}
	return fail(err, errlen, "not .jpg / .jpeg / .png");
}

uint32_t *dz_img_load(const char *path, int minw, int minh, int *w, int *h,
		      char *err, size_t errlen)
{
	int kind = dz_img_kind(path), iw, ih;
	uint32_t *out, *pic;

	if (kind == DZ_IMG_JPEG) {
		unsigned char *buf;
		unsigned long len;
		tjsf f;

		if (jpeg_header(path, &buf, &len, &iw, &ih, err, errlen))
			return NULL;
		f = cover_factor(iw, ih, minw, minh);
		*w = SCALED(iw, f);
		*h = SCALED(ih, f);
		out = malloc((size_t)*w * *h * 4);
		if (!out) {
			fail(err, errlen, "out of memory");
			return NULL;
		}
		if (tj_decode(th_tj, buf, len, (unsigned char *)out, *w, *w * 4, *h, TJPF_BGRX, 0)) {
			fail(err, errlen, "JPEG: %s", tj_errstr(th_tj));
			free(out);
			return NULL;
		}
		return out;
	}
	if (kind == DZ_IMG_PNG) {
		pic = png_read(path, &iw, &ih, err, errlen);
		if (!pic)
			return NULL;
		out = malloc((size_t)iw * ih * 4);
		if (!out) {
			fail(err, errlen, "out of memory");
			return NULL;
		}
		memcpy(out, pic, (size_t)iw * ih * 4);
		*w = iw;
		*h = ih;
		return out;
	}
	fail(err, errlen, "not .jpg / .jpeg / .png");
	return NULL;
}

void dz_img_resize(const uint32_t *src, int w, int h, uint32_t *dst,
		   size_t dst_stride, int dw, int dh)
{
	/* 16.16 fixed point, sample centres aligned */
	int64_t fx = ((int64_t)w << 16) / dw, fy = ((int64_t)h << 16) / dh;

	for (int y = 0; y < dh; y++) {
		int64_t sy = (y * fy) + fy / 2 - 32768;
		int y0 = sy < 0 ? 0 : (int)(sy >> 16), y1 = y0 + 1 < h ? y0 + 1 : h - 1;
		unsigned wy = sy < 0 ? 0 : (unsigned)((sy >> 8) & 0xFF);
		const uint32_t *r0 = src + (size_t)y0 * w, *r1 = src + (size_t)y1 * w;
		uint32_t *o = (uint32_t *)((uint8_t *)dst + (size_t)y * dst_stride);

		for (int x = 0; x < dw; x++) {
			int64_t sx = (x * fx) + fx / 2 - 32768;
			int x0 = sx < 0 ? 0 : (int)(sx >> 16), x1 = x0 + 1 < w ? x0 + 1 : w - 1;
			unsigned wx = sx < 0 ? 0 : (unsigned)((sx >> 8) & 0xFF);
			uint32_t a = r0[x0], b = r0[x1], c = r1[x0], d = r1[x1], v = 0xFF000000u;

			for (int sh = 0; sh < 24; sh += 8) {
				unsigned ca = (a >> sh) & 0xFF, cb = (b >> sh) & 0xFF;
				unsigned cc = (c >> sh) & 0xFF, cd = (d >> sh) & 0xFF;
				unsigned top = ca * (256 - wx) + cb * wx, bot = cc * (256 - wx) + cd * wx;

				v |= ((top * (256 - wy) + bot * wy) >> 16) << sh;
			}
			o[x] = v;
		}
	}
}

static __thread tjhandle th_tjc;

int dz_img_save_jpeg(const char *path, const uint8_t *src, size_t stride, int w, int h,
		     int quality, char *err, size_t errlen)
{
	unsigned char *jpg = NULL;
	unsigned long len = 0;
	char part[400];
	int fd, ok;

	pthread_once(&once, load_libs);
	if (!have_enc)
		return fail(err, errlen, "no libturbojpeg.so.0 (encoder)");
	if (!th_tjc && !(th_tjc = tj_init_c()))
		return fail(err, errlen, "tjInitCompress failed");
	quality = quality < 1 ? 1 : quality > 100 ? 100 : quality;
	if (tj_compress(th_tjc, src, w, (int)stride, h, TJPF_BGRX, &jpg, &len, TJSAMP_420, quality, 0))
		return fail(err, errlen, "JPEG encode: %s", tj_errstr(th_tjc));
	snprintf(part, sizeof(part), "%s.part", path);
	fd = open(part, O_WRONLY | O_CREAT | O_TRUNC | O_CLOEXEC, 0644);
	ok = fd >= 0 && write(fd, jpg, len) == (ssize_t)len;
	if (fd >= 0 && close(fd))
		ok = 0;
	tj_free(jpg);
	if (!ok || rename(part, path)) {
		unlink(part);
		return fail(err, errlen, "cannot write %s", path);
	}
	return 0;
}

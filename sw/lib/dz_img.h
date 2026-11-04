/*
 * dz_img.h - JPEG and PNG decode without ffmpeg (2026-11-01).
 *
 * JPEG: TurboJPEG (libturbojpeg.so.0, NEON), PNG: libpng's simplified API
 * (libpng16.so.16). Both are opened with dlopen on first use: the Vitis
 * toolchain has no headers for them, and a missing library only turns that
 * format off. Measured on the board (ROADMAP.md section 16): 720p JPEG
 * 31 ms at 46 KB, 63 ms at 250 KB per frame; the time follows the file
 * size. ffmpeg needed 0.8-1.7 s per image.
 *
 * Output pixels: a8r8g8b8 (memory bytes B, G, R, A), A = 0xFF. PNG alpha
 * is composited onto black. Thread safe (one decoder per thread).
 */
#ifndef DZ_IMG_H
#define DZ_IMG_H

#include <stddef.h>
#include <stdint.h>

enum { DZ_IMG_NONE = 0, DZ_IMG_JPEG = 1, DZ_IMG_PNG = 2 };

/* the kind by file extension (.jpg .jpeg .png, any case) */
int dz_img_kind(const char *path);

/* 1 if the library of that kind loads */
int dz_img_available(int kind);

/*
 * Decode path into dst (stride bytes per line), fitted into dw x dh:
 * never enlarged, centred, the rest of the dw x dh window black.
 * TurboJPEG scales on decode (1/2 .. 1/8: the largest that fits); a
 * picture that is still larger (or a large PNG) is cropped to its centre.
 * dst is only written, in order (uncached or write-combined memory is fine).
 * flags: DZ_IMG_FAST = TurboJPEG fast DCT + fast upsampling (~20 % faster);
 * DZ_IMG_TOPLEFT = the picture at the top left of the window and nothing
 * else written (no black borders: the rest of the window keeps its pixels).
 * Returns 0, or -1 with a message in err.
 */
#define DZ_IMG_FAST 1
#define DZ_IMG_TOPLEFT 2
int dz_img_fit(const char *path, uint8_t *dst, size_t stride, int dw, int dh,
	       int flags, char *err, size_t errlen);

/*
 * Decode into a new buffer (malloc, *w x *h pixels, free() it). JPEG is
 * scaled on decode to the smallest size that still covers minw x minh
 * (0 0 = full size). NULL with a message in err on failure.
 */
uint32_t *dz_img_load(const char *path, int minw, int minh, int *w, int *h,
		      char *err, size_t errlen);

/*
 * Encode a w x h a8r8g8b8 picture (stride bytes per line) as a baseline
 * JPEG, 4:2:0, quality 1-100 (TurboJPEG). Written as path.part, then
 * renamed: a reader never sees half a file. Returns 0 or -1 with err.
 */
int dz_img_save_jpeg(const char *path, const uint8_t *src, size_t stride, int w, int h,
		     int quality, char *err, size_t errlen);

/* bilinear resize of a w x h picture into dst (dw x dh, dst_stride bytes) */
void dz_img_resize(const uint32_t *src, int w, int h, uint32_t *dst,
		   size_t dst_stride, int dw, int dh);

#endif /* DZ_IMG_H */

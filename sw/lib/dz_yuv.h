/*
 * dz_yuv.h - planar YUV 4:2:0 (I420, ffmpeg "yuv420p") to a8r8g8b8.
 *
 * Why: ffmpeg's own yuv420p -> bgra conversion has no ARM fast path and
 * costs about 45% of the CPU time of a 720p mpeg4 stream (measured on the
 * board, Oct 2026: decode only 36 fps, decode + bgra 20 fps). This NEON
 * version converts one 720p frame in a few milliseconds, and the pipe then
 * carries 1.5 bytes per pixel instead of 4.
 *
 * Fixed point Q6 with saturation (the same results with and without NEON).
 * Limited ("tv") range input: Y 16..235, U/V 16..240.
 */
#ifndef DZ_YUV_H
#define DZ_YUV_H

#include <stddef.h>
#include <stdint.h>

typedef enum {
	DZ_YUV_BT709 = 0,	/* HD video (the default) */
	DZ_YUV_BT601 = 1,	/* SD video               */
} dz_yuv_matrix;

/*
 * Convert one row. y: w luma bytes; u, v: w/2 chroma bytes of the row pair;
 * dst: w pixels a8r8g8b8 (memory bytes B, G, R, A). w must be even.
 * dst is only written, in order: fine for uncached or write-combined memory.
 */
void dz_i420_row(const uint8_t *y, const uint8_t *u, const uint8_t *v,
		 uint8_t *dst, int w, dz_yuv_matrix m);

/* Same, plain C only (reference for tests). */
void dz_i420_row_c(const uint8_t *y, const uint8_t *u, const uint8_t *v,
		   uint8_t *dst, int w, dz_yuv_matrix m);

/*
 * Convert a whole I420 frame (Y plane w*h, then U and V planes w/2*h/2)
 * into dst with dst_stride bytes per line. w and h must be even.
 */
void dz_i420_frame(const uint8_t *frame, int w, int h, uint8_t *dst,
		   size_t dst_stride, dz_yuv_matrix m);

/* 1 if this build has the NEON path. */
int dz_yuv_neon(void);

#endif /* DZ_YUV_H */

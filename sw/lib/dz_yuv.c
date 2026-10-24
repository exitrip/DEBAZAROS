/*
 * dz_yuv.c - see dz_yuv.h.
 *
 * Q6 coefficients (x64), limited range:
 *   yy = (Y - 16) * 74.5 + 32              (1.164; +32 rounds the >> 6)
 *        computed as 74*y' + (y' >> 1) + 32, y' = Y - 16
 *   R  = (yy + rv*V')            >> 6      V' = V - 128
 *   G  = (yy - gu*U' - gv*V')    >> 6      U' = U - 128
 *   B  = (yy + bu*U')            >> 6
 *            rv    gu   gv    bu
 *   BT.709: 115    14   34   135   (1.793 0.213 0.533 2.112)
 *   BT.601: 102    25   52   129   (1.596 0.391 0.813 2.018)
 * All sums use saturating 16-bit arithmetic, then a saturating shift to
 * 0..255. The C path does the same clamps, so both give identical bytes.
 */
#include "dz_yuv.h"

#if defined(__ARM_NEON)
#include <arm_neon.h>
#endif

static const int16_t coef[2][4] = {
	{ 115, 14, 34, 135 },	/* BT.709 */
	{ 102, 25, 52, 129 },	/* BT.601 */
};

static int16_t sat16(int32_t v)
{
	return v > 32767 ? 32767 : (v < -32768 ? -32768 : (int16_t)v);
}

static uint8_t px(int16_t v)		/* saturating >> 6 to unsigned 8 bit */
{
	int32_t r = v >> 6;

	return r < 0 ? 0 : (r > 255 ? 255 : (uint8_t)r);
}

void dz_i420_row_c(const uint8_t *y, const uint8_t *u, const uint8_t *v,
		   uint8_t *dst, int w, dz_yuv_matrix m)
{
	const int16_t *k = coef[m == DZ_YUV_BT601];

	for (int x = 0; x < w; x++) {
		int16_t ys = (int16_t)(y[x] - 16);
		int16_t yy = (int16_t)(ys * 74 + (ys >> 1) + 32);
		int16_t uu = (int16_t)(u[x / 2] - 128);
		int16_t vv = (int16_t)(v[x / 2] - 128);
		int16_t r = sat16(yy + sat16(k[0] * vv));
		int16_t g = sat16(sat16(yy - sat16(k[1] * uu)) - sat16(k[2] * vv));
		int16_t b = sat16(yy + sat16(k[3] * uu));

		dst[4 * x + 0] = px(b);
		dst[4 * x + 1] = px(g);
		dst[4 * x + 2] = px(r);
		dst[4 * x + 3] = 0xFF;
	}
}

#if defined(__ARM_NEON)
void dz_i420_row(const uint8_t *y, const uint8_t *u, const uint8_t *v,
		 uint8_t *dst, int w, dz_yuv_matrix m)
{
	const int16_t *k = coef[m == DZ_YUV_BT601];
	const int16x8_t c16 = vdupq_n_s16(16), c128 = vdupq_n_s16(128);
	const int16x8_t c74 = vdupq_n_s16(74), c32 = vdupq_n_s16(32);
	const int16x8_t rv = vdupq_n_s16(k[0]), gu = vdupq_n_s16(k[1]);
	const int16x8_t gv = vdupq_n_s16(k[2]), bu = vdupq_n_s16(k[3]);
	const uint8x8_t alpha = vdup_n_u8(0xFF);
	int x = 0;

	for (; x + 16 <= w; x += 16) {
		uint8x16_t y8 = vld1q_u8(y + x);
		uint8x8x2_t uz = vzip_u8(vld1_u8(u + x / 2), vld1_u8(u + x / 2));
		uint8x8x2_t vz = vzip_u8(vld1_u8(v + x / 2), vld1_u8(v + x / 2));

		for (int h = 0; h < 2; h++) {	/* two halves of 8 pixels */
			uint8x8_t yh = h ? vget_high_u8(y8) : vget_low_u8(y8);
			int16x8_t ys = vsubq_s16(vreinterpretq_s16_u16(vmovl_u8(yh)), c16);
			int16x8_t yy = vaddq_s16(vsraq_n_s16(vmulq_s16(ys, c74), ys, 1), c32);
			int16x8_t uu = vsubq_s16(vreinterpretq_s16_u16(vmovl_u8(uz.val[h])), c128);
			int16x8_t vv = vsubq_s16(vreinterpretq_s16_u16(vmovl_u8(vz.val[h])), c128);
			int16x8_t r = vqaddq_s16(yy, vmulq_s16(rv, vv));
			int16x8_t g = vqsubq_s16(vqsubq_s16(yy, vmulq_s16(gu, uu)),
						 vmulq_s16(gv, vv));
			int16x8_t b = vqaddq_s16(yy, vmulq_s16(bu, uu));
			uint8x8x4_t o;

			o.val[0] = vqshrun_n_s16(b, 6);
			o.val[1] = vqshrun_n_s16(g, 6);
			o.val[2] = vqshrun_n_s16(r, 6);
			o.val[3] = alpha;
			vst4_u8(dst + 4 * (x + 8 * h), o);
		}
	}
	if (x < w)
		dz_i420_row_c(y + x, u + x / 2, v + x / 2, dst + 4 * x, w - x, m);
}

int dz_yuv_neon(void) { return 1; }
#else
void dz_i420_row(const uint8_t *y, const uint8_t *u, const uint8_t *v,
		 uint8_t *dst, int w, dz_yuv_matrix m)
{
	dz_i420_row_c(y, u, v, dst, w, m);
}

int dz_yuv_neon(void) { return 0; }
#endif

void dz_i420_frame(const uint8_t *frame, int w, int h, uint8_t *dst,
		   size_t dst_stride, dz_yuv_matrix m)
{
	const uint8_t *yp = frame;
	const uint8_t *up = yp + (size_t)w * h;
	const uint8_t *vp = up + (size_t)(w / 2) * (h / 2);

	for (int row = 0; row < h; row++)
		dz_i420_row(yp + (size_t)row * w, up + (size_t)(row / 2) * (w / 2),
			    vp + (size_t)(row / 2) * (w / 2), dst + (size_t)row * dst_stride,
			    w, m);
}

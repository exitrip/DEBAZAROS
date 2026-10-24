/*
 * vsync_probe - find a per-frame signal for frame-exact buffer switching.
 * For each candidate (register, bit): W1C the bit, spin until it is set
 * again, record the interval. A period of 1/refresh = usable vsync.
 * Reads/W1C status bits only. Run as root on the board.
 */
#include "dz_map.h"
#include "dz_hw.h"
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

static double now(void)
{
	struct timespec t;

	clock_gettime(CLOCK_MONOTONIC, &t);
	return t.tv_sec + t.tv_nsec / 1e9;
}

static void probe(const char *name, uint32_t base, uint32_t off, uint32_t bit)
{
	volatile uint32_t *r = dz_regs(base);
	double t0, last, sum = 0, mn = 1e9, mx = 0;
	int n = 0;

	if (!r) {
		printf("%-28s not mapped\n", name);
		return;
	}
	r[off / 4] = bit;				/* W1C */
	if (r[off / 4] & bit) {
		printf("%-28s bit 0x%x does not clear (not W1C, or level)\n", name, bit);
		return;
	}
	t0 = last = now();
	while (n < 30 && now() - t0 < 2.0) {
		if (r[off / 4] & bit) {
			double t = now();

			if (n > 0) {
				double d = t - last;

				sum += d; mn = d < mn ? d : mn; mx = d > mx ? d : mx;
			}
			last = t;
			n++;
			r[off / 4] = bit;
		}
	}
	if (n < 3)
		printf("%-28s no edges in 2 s\n", name);
	else
		printf("%-28s period %.3f ms (min %.3f max %.3f) = %.2f Hz\n", name,
		       1000 * sum / (n - 1), 1000 * mn, 1000 * mx, (n - 1) / sum);
}

/* watch: at each vsync, print which frame store display d reads (PARK[20:16]) */
static int watch(int d, int nframes, int slots)
{
	uint32_t b = d ? DZ_DISP1_VDMA : DZ_DISP0_VDMA;
	volatile uint32_t *r = dz_regs(b);
	/* frame clock: display 0 VDMA FrmCnt (SR bit 12). NOT the VTC bit 13 that
	 * debazd's vsync thread uses: clearing that one would steal its frames. */
	volatile uint32_t *v = dz_regs(DZ_DISP0_VDMA);
	char line[256];
	int k = 0, flips = 0, prev = -1;

	if (!r || !v)
		return 1;
	v[1] = 1u << 12;
	for (int f = 0; f < nframes; f++) {
		double t0 = now();
		int cur;

		while (!(v[1] & (1u << 12)))
			if (now() - t0 > 0.1)
				return printf("no vsync\n"), 1;
		v[1] = 1u << 12;
		/* sample in the middle of the frame: the store being read now */
		while (now() - t0 < 0.008)
			;
		cur = (int)((r[0x28 / 4] >> 16) & 0x1F);
		if (slots) {		/* slot of the address in the store being read */
			uint32_t ad = r[(0x5C + 4 * cur) / 4];

			cur = ad >= DZ_SLOT_BASE ? (int)((ad - DZ_SLOT_BASE) / DZ_SLOT_PITCH) : 0;
			cur = cur > 35 ? 35 : cur;
		}
		if (prev >= 0 && cur != prev)
			flips++;
		prev = cur;
		if (k < (int)sizeof(line) - 1)
			line[k++] = (char)(cur < 10 ? '0' + cur : 'a' + cur - 10);
	}
	line[k] = 0;
	printf("display %d stores per frame: %s\nchanges: %d in %d frames\n", d, line, flips,
	       nframes);
	return 0;
}

int main(int argc, char **argv)
{
	/* w = frame store index per frame, a = slot number per frame */
	if (argc >= 3 && (argv[1][0] == 'w' || argv[1][0] == 'a'))
		return watch(atoi(argv[2]), argc >= 4 ? atoi(argv[3]) : 60, argv[1][0] == 'a');
	probe("disp0 MM2S SR FrmCnt b12", DZ_DISP0_VDMA, 0x04, 1u << 12);
	probe("disp1 MM2S SR FrmCnt b12", DZ_DISP1_VDMA, 0x04, 1u << 12);
	probe("capture S2MM SR FrmCnt b12", DZ_CAPTURE_VDMA, 0x34, 1u << 12);
	for (int b = 8; b <= 17; b++) {
		char nm[40];

		snprintf(nm, sizeof(nm), "VTC ISR bit %d", b);
		probe(nm, HW_HDMI_0_V_TC_0_BASE, 0x04, 1u << b);
	}
	return 0;
}

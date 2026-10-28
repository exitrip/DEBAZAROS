/*
 * pcmplay - play raw audio into a Linux PCM FIFO of the gateware (build
 * `pcm`, 2026-10-27, hdmi_audio_regs 0x43C6_0060-8C) from userspace, by
 * polling the FIFO level: a test of the PCM path before the ALSA driver
 * exists. Input on stdin: S16_LE, 2 channels, 48000 Hz, e.g.
 *
 *   ffmpeg -loglevel error -i song.mp3 -f s16le -ac 2 -ar 48000 - | sudo pcmplay -s 0
 *   pcmplay -s 1 -t 440          sine test tone (no stdin), Ctrl-C stops
 *   pcmplay -c 5                 capture 5 s of HDMI_2 audio to stdout (S16_LE)
 *
 * -s 0 = HDMI_0, 1 = HDMI_1, 2 = I2S DOUT (set the pins: /io/pin ... bclk
 * lrclk dout, /i2s/on 1). The tool sets the routing bit (I2S_CTRL [6]/[5]/[7])
 * and clears it at the end. The output must be in HDMI mode with audio on
 * (/audio/tx0/hdmi 1, /audio/tx0/enable 1, tone off). Run as root.
 * At the end it prints frames sent, underruns, and the FIFO level range.
 *
 * -s 0,1 (2026-10-28) writes the same samples into several FIFOs, started
 * together (one PCM_CTRL write), so a switch between outputs is only a
 * routing bit (/pcm/to_hdmi0|1). -n leaves the routing bits alone (a
 * routing test script sets them).
 */
#include "dz_map.h"
#include "dz_hw.h"

#include <math.h>
#include <sched.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

#define I2S_CTRL	0x4C
#define PCM_CTRL	0x60
#define CAP_DATA	0x6C
#define LEVEL01		0x74
#define LEVEL2C		0x78
#define IRQ_STATUS	0x7C
#define PCM_FRAMES	0x84
#define DEPTH		512
#define TOP		480		/* fill up to this level */

static const uint32_t data_off[3] = { 0x64, 0x68, 0x70 };
static const int      route_bit[3] = { 6, 5, 7 };
static volatile int   stop;

static void on_sig(int s) { (void)s; stop = 1; }

static void nap_us(long us)
{
	struct timespec t = { 0, us * 1000 };

	nanosleep(&t, NULL);
}

static int level(volatile uint32_t *r, int s)
{
	uint32_t v = r[(s == 2 ? LEVEL2C : LEVEL01) / 4];

	return (int)((s == 1 ? v >> 16 : v) & 0x3FF);
}

static int capture(volatile uint32_t *r, double secs)
{
	uint32_t want = (uint32_t)(secs * 48000.0), got = 0, f0 = r[PCM_FRAMES / 4];

	r[PCM_CTRL / 4] = (r[PCM_CTRL / 4] & 0xF) | (1u << 11);	/* flush capture */
	r[PCM_CTRL / 4] |= 1u << 3;
	while (!stop && got < want) {
		int n = (int)((r[LEVEL2C / 4] >> 16) & 0x3FF);

		for (int i = 0; i < n && got < want; i++, got++) {
			uint32_t w = r[CAP_DATA / 4];	/* the read pops it */

			fwrite(&w, 4, 1, stdout);
		}
		nap_us(2000);
	}
	r[PCM_CTRL / 4] &= ~(1u << 3);
	fprintf(stderr, "pcmplay: captured %u frames in %u pacer frames, overrun %s\n", got,
		r[PCM_FRAMES / 4] - f0, (r[IRQ_STATUS / 4] & 0x80) ? "YES" : "no");
	r[IRQ_STATUS / 4] = 0x80;
	return 0;
}

int main(int argc, char **argv)
{
	int s = 0, opt, lmin = DEPTH, lmax = 0, prime = 1, noroute = 0;
	unsigned mask = 0, route = 0, irq = 0;
	const char *list = "0";
	double tone = 0.0, ph = 0.0, cap = 0.0;
	unsigned long sent = 0, under = 0;
	volatile uint32_t *r;
	struct sched_param sp = { .sched_priority = 50 };

	while ((opt = getopt(argc, argv, "s:t:c:n")) != -1) {
		if (opt == 's')
			list = optarg;
		else if (opt == 'n')
			noroute = 1;
		else if (opt == 't')
			tone = atof(optarg);
		else if (opt == 'c')
			cap = atof(optarg);
		else {
			fprintf(stderr, "usage: pcmplay [-s 0|1|2[,..]] [-n] [-t hz] [-c secs] < s16le-stereo-48k\n");
			return 2;
		}
	}
	for (const char *c = list; *c; c++) {
		if (*c >= '0' && *c <= '2')
			mask |= 1u << (*c - '0');
		else if (*c != ',')
			return 2;
	}
	if (!mask)
		return 2;
	for (int k = 0; k < 3; k++)
		if (mask & (1u << k)) {
			route |= 1u << route_bit[k];
			irq |= 0x10u << k;
			s = k;			/* the summary names the last one */
		}
	r = dz_regs(HW_HDMI_AUDIO_REGS_0_BASE);	/* dz_map checks the "HAUD" ID */
	if (!r) {
		fprintf(stderr, "pcmplay: no HDMI audio block in this bitstream\n");
		return 1;
	}
	signal(SIGINT, on_sig);
	signal(SIGTERM, on_sig);
	sched_setscheduler(0, SCHED_FIFO, &sp);	/* best effort */
	if (cap > 0.0)
		return capture(r, cap);

	r[PCM_CTRL / 4] = (r[PCM_CTRL / 4] & 0xF & ~mask) | (mask << 8);	/* stop + flush */
	r[IRQ_STATUS / 4] = irq;					/* clear the underrun latches */
	if (!noroute)
		r[I2S_CTRL / 4] |= route;
	while (!stop) {
		int lv = 0, room, eof = 0;

		for (int k = 0; k < 3; k++)	/* the fullest FIFO sets the room */
			if (mask & (1u << k) && level(r, k) > lv)
				lv = level(r, k);
		room = TOP - lv;
		if (!prime) {
			lmin = lv < lmin ? lv : lmin;
			lmax = lv > lmax ? lv : lmax;
			if (r[IRQ_STATUS / 4] & irq) {
				under++;
				r[IRQ_STATUS / 4] = irq;
			}
		}
		for (int i = 0; i < room; i++) {
			uint32_t w;

			if (tone > 0.0) {
				int16_t v = (int16_t)(8000.0 * sin(ph));

				ph += 2.0 * M_PI * tone / 48000.0;
				if (ph > 2.0 * M_PI)
					ph -= 2.0 * M_PI;
				w = (uint16_t)v | ((uint32_t)(uint16_t)v << 16);
			} else if (fread(&w, 4, 1, stdin) != 1) {
				eof = 1;
				break;
			}
			for (int k = 0; k < 3; k++)
				if (mask & (1u << k))
					r[data_off[k] / 4] = w;
			sent++;
		}
		if (prime) {			/* pre-filled: start the stream */
			r[PCM_CTRL / 4] |= mask;
			prime = 0;
		}
		if (eof) {			/* let the FIFO play out */
			while (!stop && level(r, s) > 0)	/* the FIFOs drain together */
				nap_us(2000);
			break;
		}
		nap_us(2000);			/* 2 ms = 96 frames; the FIFO holds 10.7 ms */
	}
	r[PCM_CTRL / 4] &= ~mask;
	r[IRQ_STATUS / 4] = irq;	/* the drained FIFO latches one underrun */
	if (!noroute)
		r[I2S_CTRL / 4] &= ~route;
	fprintf(stderr, "pcmplay: stream %s, %lu frames (%.1f s), %lu underrun periods, level %d..%d of %d\n",
		list, sent, sent / 48000.0, under, lmin, lmax, DEPTH);
	return 0;
}

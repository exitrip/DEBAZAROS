/*
 * audio.c - housekeeping for the HDMI audio block (hdmi_audio_regs,
 * 0x43C6_0000):
 *
 * - 48 kHz rate setting: the transmitters' test-tone clock is an NCO on the
 *   pixel clock (fs_inc = 48000 * 2^32 / f_pixel, shared by HDMI_0 and HDMI_1).
 *   Once vsync runs, f_pixel = measured frame rate x the VTC frame size
 *   (GHSIZE x GVSIZE), so every video mode that hdmi2 sets gets the right
 *   value. Checked once per second; written when it is off by > 0.1 %.
 *     /audio/fs                 -> /audio/fs f:pixel_MHz i:fs_inc i:auto
 *     /audio/fs/auto i          1 (default) = keep it updated, 0 = hands off
 * - HDMI_2 replug: the source re-reads the EDID and redoes its mode set (for
 *   example after a PL reload left it in DVI mode).
 *     /capture/replug [f:s]     hot-plug low for s seconds (default 2; use
 *                               12 when the source polls instead of using
 *                               hot-plug interrupts)
 * - HDMI_2 audio watchdog (2026-10-28): the EDID allows only 48 kHz. When
 *   audio arrives but at a rate off by > 2 % for 3 s, the link has bit
 *   errors on the data lanes (seen after a physical hot-plug on the second
 *   board: 38959 samples/s, video still clean - packets with a BCH error are
 *   dropped). A replug makes dvi2rgb align again; at most once per 30 s.
 *     /audio/rx/auto i          1 (default) = watch and replug, 0 = off
 *     /audio/rx/rate            -> /audio/rx/rate f:samples_per_s i:auto
 * On a bitstream without the block the field writes fail and nothing happens.
 */
#include "debazd.h"
#include "dz_fields.h"
#include "dz_hw.h"
#include "dz_map.h"

#include <math.h>
#include <string.h>
#include <time.h>

#define VTC_GHSIZE	(0x070 / 4)
#define VTC_GVSIZE	(0x074 / 4)

static int  fs_auto = 1, rx_auto = 1, rx_bad;
static long next_check, replug_end, rx_last_ms, rx_last_replug;
static uint32_t rx_last_n;
static double rx_rate;

static void replug(double s, long now)
{
	if (dz_field_write(dz_field_find("/hdmi/2/hpd_low"), 1) < 0)
		return;
	replug_end = now + (long)(s * 1000.0);
}

/* once a second: input samples per second; replug when audio arrives at a
 * wrong rate for 3 s */
static void rx_watch(long ms)
{
	uint32_t n, active = 0;

	if (dz_field_read(dz_field_find("/audio/rx/samples"), &n) < 0)
		return;
	dz_field_read(dz_field_find("/audio/rx/active"), &active);
	if (rx_last_ms && ms > rx_last_ms)
		rx_rate = (double)(uint32_t)(n - rx_last_n) * 1000.0 / (double)(ms - rx_last_ms);
	rx_last_n = n;
	rx_last_ms = ms;
	if (!rx_auto || replug_end || !active || rx_rate <= 0.0 ||
	    fabs(rx_rate - 48000.0) < 48000.0 * 0.02) {
		rx_bad = 0;
		return;
	}
	if (++rx_bad < 3 || ms - rx_last_replug < 30000)
		return;
	dzd_log("audio: HDMI_2 audio at %.0f samples/s (48000 expected): link errors, replug\n",
		rx_rate);
	rx_last_replug = ms;
	rx_bad = 0;
	replug(2.0, ms);
	rx_last_ms = 0;
}

static double pixel_hz(void)
{
	volatile uint32_t *vtc = dz_regs(HW_HDMI_0_V_TC_0_BASE);
	double hz = disp_frame_hz();

	if (!vtc || hz <= 0.0)
		return 0.0;
	return hz * (double)(vtc[VTC_GHSIZE] & 0x1FFF) * (double)(vtc[VTC_GVSIZE] & 0x1FFF);
}

static uint32_t want_inc(double f)
{
	return f > 1e6 ? (uint32_t)(48000.0 * 4294967296.0 / f + 0.5) : 0;
}

void audio_tick(long ms)
{
	const dz_field *fi = dz_field_find("/audio/tx/fs_inc");

	if (replug_end && ms >= replug_end) {
		dz_field_write(dz_field_find("/hdmi/2/hpd_low"), 0);
		replug_end = 0;
		dzd_log("audio: HDMI_2 hot-plug high again\n");
	}
	if (ms < next_check)
		return;
	next_check = ms + 1000;
	rx_watch(ms);
	if (!fs_auto || !fi)
		return;
	{
		uint32_t cur, want = want_inc(pixel_hz());

		if (!want || dz_field_read(fi, &cur) < 0)
			return;
		if (cur == 0 || fabs((double)cur - want) > want * 0.001) {
			dz_field_write(fi, want);
			dzd_log("audio: fs_inc %u -> %u (pixel clock %.4f MHz)\n", cur, want,
				pixel_hz() / 1e6);
		}
	}
}

int audio_dispatch(const dz_msg *m)
{
	const dz_arg *a = m->a;

	if (!strcmp(m->path, "/audio/fs")) {
		uint32_t cur = 0;

		dz_field_read(dz_field_find("/audio/tx/fs_inc"), &cur);
		dzd_reply("/audio/fs", "fii", (float)(pixel_hz() / 1e6), (int)cur, fs_auto);
		return 1;
	}
	if (!strcmp(m->path, "/audio/fs/auto")) {
		if (m->n >= 1)
			fs_auto = (a[0].type == 'f' ? a[0].f != 0.0f : a[0].i != 0);
		next_check = 0;
		dzd_reply("/audio/fs/auto", "i", fs_auto);
		return 1;
	}
	if (!strcmp(m->path, "/audio/rx/auto")) {
		if (m->n >= 1)
			rx_auto = (a[0].type == 'f' ? a[0].f != 0.0f : a[0].i != 0);
		dzd_reply("/audio/rx/auto", "i", rx_auto);
		return 1;
	}
	if (!strcmp(m->path, "/audio/rx/rate")) {
		dzd_reply("/audio/rx/rate", "fi", (float)rx_rate, rx_auto);
		return 1;
	}
	if (!strcmp(m->path, "/capture/auto")) {	/* capture size follows the input */
		if (m->n >= 1)
			capture_auto = m->a[0].type == 'f' ? m->a[0].f != 0.0f : m->a[0].i != 0;
		dzd_reply("/capture/auto", "i", capture_auto);
		return 1;
	}
	if (!strcmp(m->path, "/capture/replug")) {
		double s = m->n >= 1 ? (a[0].type == 'f' ? a[0].f : a[0].i) : 2.0;
		struct timespec ts;

		if (s < 0.1)
			s = 0.1;
		if (s > 30.0)
			s = 30.0;
		if (dz_field_write(dz_field_find("/hdmi/2/hpd_low"), 1) < 0) {
			dzd_reply("/error", "ss", "no HPD control in this bitstream", m->path);
			return 1;
		}
		clock_gettime(CLOCK_MONOTONIC, &ts);
		replug_end = ts.tv_sec * 1000L + ts.tv_nsec / 1000000L + (long)(s * 1000.0);
		dzd_reply("/ok", "sf", m->path, (float)s);
		return 1;
	}
	return 0;
}

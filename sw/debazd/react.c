/*
 * react.c - audio analysis for audio-reactive LFOs (2026-11-01).
 *
 * One analyser, evaluated once per frame before the LFOs. Sources:
 *   capture  the HDMI_2 input through ALSA (arecord hw:DEBAZ,2 -> FIFO;
 *            48 kHz stereo s16): all features
 *   peak     the PL peak meter of hdmi_rx (/audio/rx/peak/l|r, cleared each
 *            frame by a toggle of RX_CTRL[1]): level and peak only, no
 *            ALSA, almost no CPU
 *   auto     default (2026-11-02): capture while a sink asks for the data
 *            (an LFO with shape audio, a DDS audio scope, an /audio/react
 *            query), off 5 s after the last demand
 *   off
 * Features, 0..1 (a full-scale sine = 1; louder material can exceed 1):
 *   level    RMS of the samples of this frame (x sqrt 2)
 *   peak     max |sample| of this frame
 *   bass low mid high air   FFT band amplitudes: < 250 Hz, 250-500,
 *            500-2k, 2k-8k, > 8k
 *   band0..band15            16 log-spaced FFT bands
 *   flux     spectral flux (rise of the band amplitudes since the last frame)
 *   beat     1 at an onset (flux > 1.5 x its running mean + a floor), else 0
 * FFT: our own radix-2 real FFT (N/2-point complex + split), Hann window, on
 * the newest N samples each frame. Measured on the A9 (window + FFT + 16
 * bands): N 256 34 us, 512 73 us, 1024 159 us = 0.2 / 0.4 / 1 % of a core at
 * 60 frames/s.
 *
 * The capture device has ONE owner (ALSA). react_hold() (sound.c: /audio/rec)
 * pauses the capture source and gives the device back after the recording;
 * before each arecord start the PCM status in /proc/asound is checked, and
 * another owner (pid, name) is reported instead of starting (retry every 2 s).
 * Status: off | starting | ok | held: <why> | busy: <pid name> | no samples |
 * auto: idle (no sink asked for 5 s)
 *
 * OSC:
 *   /audio/react/source s:auto|capture|peak|off
 *   /audio/react/fft i:256|512|1024        (default 1024: 47 Hz per bin)
 *   /audio/react                           -> s:source i:running f:level f:peak
 *                                             (source = the setting: auto
 *                                             runs capture on demand)
 *                                             f:bass f:low f:mid f:high f:air
 *                                             f:flux f:beat s:status
 *   /audio/react/bands                     -> 16 x f
 * Use: /lfo/<n>/shape audio, /lfo/<n>/audio <feature> (lfo.c); the
 * waveform: /dds/<n>/scope (dds.c, writes the newest 2048 samples, or the
 * spectrum of one channel (react_spectrum), into the AWG table each frame).
 */
#define _GNU_SOURCE
#include "debazd.h"
#include "dz_draw.h"
#include "dz_fields.h"

#include <errno.h>
#include <fcntl.h>
#include <math.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

#define REACT_FIFO	"/tmp/dzreact.fifo"
#define PCM_STATUS	"/proc/asound/DEBAZ/pcm2c/sub0/status"
#define RING		4096			/* samples kept: 2048 for the scope + a trigger search */
#define NMAX		1024

enum { SRC_OFF, SRC_CAPTURE, SRC_PEAK, SRC_AUTO };
static const char *src_names[] = { "off", "capture", "peak", "auto" };
#define AUTO_LINGER_MS	5000		/* auto: capture stops this long after the last demand */

typedef struct { float re, im; } cpx;

static int    src = SRC_OFF, fft_n = 1024;	/* src = what runs (off, capture, peak) */
static int    want = SRC_AUTO;		/* the setting; auto = capture on demand */
static long   need_ms;			/* auto: the last demand of a sink */
static int    fd = -1;
static pid_t  rec_pid;
static long   restart_at;			/* ms: start arecord again */
static long   last_ms;			/* ms: the last samples */
static float  ring[RING], ringl[RING], ringr[RING];	/* (L+R)/2, L, R */
static int    held;				/* react_hold count */
static char   hold_why[24], status[64] = "auto: idle";
static unsigned rpos, rfill;
static unsigned long rtotal;		/* samples ever written (react_spectrum's cache key) */
static uint8_t carry[4];
static int    ncarry;

/* features */
static float  f_level, f_peak, f_bass, f_low, f_mid, f_high, f_air, f_flux, f_beat;
static float  f_band[16], prev_band[16], flux_mean;
static int    running;

/* FFT plan for fft_n */
static int    plan_n;
static int    rev[NMAX / 2];
static cpx    tw[NMAX / 2], sp[NMAX];
static float  win[NMAX];
static int    band_lo[17];

static long ms_now(void)
{
	struct timespec ts;

	clock_gettime(CLOCK_MONOTONIC, &ts);
	return ts.tv_sec * 1000L + ts.tv_nsec / 1000000L;
}

static void mkplan(int n)
{
	int m = n / 2, bits = 0;

	while ((1 << bits) < m)
		bits++;
	for (int i = 0; i < m; i++) {
		int v = 0;

		for (int b = 0; b < bits; b++)
			if (i >> b & 1)
				v |= 1 << (bits - 1 - b);
		rev[i] = v;
		tw[i].re = cosf(-2.0f * (float)M_PI * i / m);
		tw[i].im = sinf(-2.0f * (float)M_PI * i / m);
	}
	for (int k = 0; k < n; k++) {
		sp[k].re = cosf(-2.0f * (float)M_PI * k / n);
		sp[k].im = sinf(-2.0f * (float)M_PI * k / n);
		win[k] = 0.5f - 0.5f * cosf(2.0f * (float)M_PI * k / (n - 1));
	}
	for (int b = 0; b <= 16; b++) {		/* log bands from bin 1 to n/2 */
		int lo = (int)lrint(pow(n / 2.0, b / 16.0));

		band_lo[b] = lo < 1 ? 1 : lo;
	}
	for (int b = 1; b <= 16; b++)
		if (band_lo[b] <= band_lo[b - 1])
			band_lo[b] = band_lo[b - 1] + 1;
	if (band_lo[16] > n / 2 + 1)
		band_lo[16] = n / 2 + 1;
	plan_n = n;
}

static void fft_c(cpx *x, int m)
{
	for (int i = 0; i < m; i++)
		if (rev[i] > i) {
			cpx t = x[i];

			x[i] = x[rev[i]];
			x[rev[i]] = t;
		}
	for (int len = 2; len <= m; len <<= 1) {
		int h = len >> 1, step = m / len;

		for (int i = 0; i < m; i += len)
			for (int k = 0; k < h; k++) {
				cpx w = tw[k * step], a = x[i + k], b = x[i + k + h], t;

				t.re = b.re * w.re - b.im * w.im;
				t.im = b.re * w.im + b.im * w.re;
				x[i + k].re = a.re + t.re;
				x[i + k].im = a.im + t.im;
				x[i + k + h].re = a.re - t.re;
				x[i + k + h].im = a.im - t.im;
			}
	}
}

/* power spectrum of the newest n samples of rb: pw[0..n/2] */
static void spectrum(const float *rb, float *pw)
{
	int n = plan_n, m = n / 2;
	cpx z[NMAX / 2];
	unsigned s = (rpos + RING - (unsigned)n) % RING;

	if (m < 2)
		return;

	for (int i = 0; i < m; i++) {
		z[i].re = rb[(s + 2 * i) % RING] * win[2 * i];
		z[i].im = rb[(s + 2 * i + 1) % RING] * win[2 * i + 1];
	}
	fft_c(z, m);
	pw[0] = (z[0].re + z[0].im) * (z[0].re + z[0].im);
	for (int k = 1; k < m; k++) {
		cpx a = z[k], b = z[m - k], w = sp[k];
		float er = 0.5f * (a.re + b.re), ei = 0.5f * (a.im - b.im);
		float orr = 0.5f * (a.im + b.im), oi = -0.5f * (a.re - b.re);
		float xr = er + w.re * orr - w.im * oi, xi = ei + w.re * oi + w.im * orr;

		pw[k] = xr * xr + xi * xi;
	}
	pw[m] = (z[0].re - z[0].im) * (z[0].re - z[0].im);
}

/* amplitude of bins [lo, hi): a full-scale sine in the range = ~1 (Hann: n/4) */
static float bins_amp(const float *pw, int lo, int hi)
{
	double s = 0;

	if (hi > plan_n / 2 + 1)
		hi = plan_n / 2 + 1;
	for (int k = lo; k < hi; k++)
		s += pw[k];
	return (float)(sqrt(s) / (plan_n / 4.0));
}

static int hz_bin(double hz)
{
	int k = (int)lrint(hz * plan_n / 48000.0);

	return k < 1 ? 1 : k;
}

static void analyse(void)
{
	float pw[NMAX / 2 + 1], flux = 0;

	if (plan_n != fft_n)
		mkplan(fft_n);
	if (rfill < (unsigned)plan_n)
		return;
	spectrum(ring, pw);
	f_bass = bins_amp(pw, 1, hz_bin(250));
	f_low  = bins_amp(pw, hz_bin(250), hz_bin(500));
	f_mid  = bins_amp(pw, hz_bin(500), hz_bin(2000));
	f_high = bins_amp(pw, hz_bin(2000), hz_bin(8000));
	f_air  = bins_amp(pw, hz_bin(8000), plan_n / 2 + 1);
	for (int b = 0; b < 16; b++) {
		f_band[b] = bins_amp(pw, band_lo[b], band_lo[b + 1]);
		if (f_band[b] > prev_band[b])
			flux += f_band[b] - prev_band[b];
		prev_band[b] = f_band[b];
	}
	f_flux = flux;
	f_beat = (flux > 1.5f * flux_mean + 0.02f) ? 1.0f : 0.0f;
	flux_mean += (flux - flux_mean) * 0.05f;	/* ~20 frames */
}

/* ---- the capture source: arecord -> FIFO ------------------------------------ */
static void capture_stop(void)
{
	if (rec_pid > 0) {
		dz_kill_group(rec_pid, SIGTERM);
		rec_pid = 0;
	}
	if (fd >= 0) {
		close(fd);
		fd = -1;
	}
	running = 0;
}

/* the capture PCM's owner: 0 = closed (free), else its pid (-1 = unknown) */
static int pcm_owner(char *name, size_t cap)
{
	FILE *fp = fopen(PCM_STATUS, "r");
	char line[96];
	int pid = 0, open_ = 0;

	name[0] = 0;
	if (!fp)
		return 0;			/* no card: arecord will say so */
	while (fgets(line, sizeof(line), fp)) {
		if (!strncmp(line, "state:", 6))
			open_ = 1;		/* "closed" has no state line */
		if (!strncmp(line, "owner_pid", 9))
			pid = atoi(strchr(line, ':') ? strchr(line, ':') + 1 : line);
	}
	fclose(fp);
	if (!open_)
		return 0;
	if (pid > 0) {
		char p[40];

		snprintf(p, sizeof(p), "/proc/%d/comm", pid);
		fp = fopen(p, "r");
		if (fp) {
			if (fgets(name, (int)cap, fp))
				name[strcspn(name, "\n")] = 0;
			fclose(fp);
		}
		return pid;
	}
	return -1;
}

static int capture_start(void)
{
	char cmd[512], who[24];
	int owner;

	capture_stop();
	if (held) {
		snprintf(status, sizeof(status), "held: %s", hold_why);
		return 0;
	}
	owner = getenv("DZ_REACT_CMD") ? 0 : pcm_owner(who, sizeof(who));
	if (owner) {
		snprintf(status, sizeof(status), "busy: %d %s", owner, who);
		restart_at = ms_now() + 2000;
		return 0;
	}
	snprintf(status, sizeof(status), "starting");
	unlink(REACT_FIFO);
	if (mkfifo(REACT_FIFO, 0600) < 0)
		return -1;
	/* O_RDWR: no EOF while arecord restarts, and its open never blocks */
	fd = open(REACT_FIFO, O_RDWR | O_NONBLOCK | O_CLOEXEC);
	if (fd < 0)
		return -1;
	fcntl(fd, F_SETPIPE_SZ, 1 << 18);	/* 1.3 s at 192 KB/s */
	if (getenv("DZ_REACT_CMD"))		/* host tests: 48 kHz s16 stereo on stdout */
		snprintf(cmd, sizeof(cmd), "exec %s > %s", getenv("DZ_REACT_CMD"), REACT_FIFO);
	else
		snprintf(cmd, sizeof(cmd), "exec arecord -q -D hw:DEBAZ,2 -f S16_LE -c 2 -r 48000 "
			 "-t raw > %s 2>/dev/null", REACT_FIFO);
	rec_pid = dz_spawn(cmd, 0);
	ncarry = 0;
	return rec_pid > 0 ? 0 : -1;
}

/* read what arrived: s16 stereo -> mono ring; level and peak of these samples */
static void capture_read(void)
{
	uint8_t buf[16384 + 4];
	double sq = 0;
	float pk = 0;
	long cnt = 0;
	ssize_t r;
	int st;

	if (rec_pid > 0 && waitpid(rec_pid, &st, WNOHANG) == rec_pid) {
		rec_pid = 0;			/* PCM busy, card gone, ... */
		running = 0;
		restart_at = ms_now() + 2000;
		snprintf(status, sizeof(status), "arecord ended, retry");
		dzd_log("react: arecord ended (status %d), again in 2 s\n", st);
	}
	if (!rec_pid && !held && restart_at && ms_now() >= restart_at) {
		restart_at = 0;
		capture_start();
	}
	if (fd < 0)
		return;
	for (;;) {
		int n;

		memcpy(buf, carry, (size_t)ncarry);
		r = read(fd, buf + ncarry, 16384);
		if (r <= 0)
			break;
		n = ncarry + (int)r;
		for (int i = 0; i + 4 <= n; i += 4) {
			int16_t l = (int16_t)(buf[i] | buf[i + 1] << 8), rr = (int16_t)(buf[i + 2] | buf[i + 3] << 8);
			float v = (l + rr) * (0.5f / 32768.0f), a = fabsf(v);

			ring[rpos] = v;
			ringl[rpos] = l * (1.0f / 32768.0f);
			ringr[rpos] = rr * (1.0f / 32768.0f);
			rpos = (rpos + 1) % RING;
			rtotal++;
			if (rfill < RING)
				rfill++;
			sq += (double)v * v;
			pk = a > pk ? a : pk;
			cnt++;
		}
		ncarry = n & 3;
		memcpy(carry, buf + (n - ncarry), (size_t)ncarry);
	}
	if (cnt) {
		running = 1;
		snprintf(status, sizeof(status), "ok");
		last_ms = ms_now();
		f_level = (float)sqrt(2.0 * sq / cnt);
		f_peak = pk;
		analyse();
	} else if (ms_now() - last_ms > 200) {	/* frames between sample blocks keep the values */
		if (running)
			snprintf(status, sizeof(status), "no samples");
		running = 0;
		f_level = f_peak = 0;
	}
}

/* ---- the peak source: PL meter -------------------------------------------- */
static void peak_read(void)
{
	static const dz_field *fl, *fr, *fc;
	uint32_t l = 0, r = 0, c = 0;

	if (!fl) {
		fl = dz_field_find("/audio/rx/peak/l");
		fr = dz_field_find("/audio/rx/peak/r");
		fc = dz_field_find("/audio/rx/clear");
	}
	if (!fl || !fr || !fc || dz_field_read(fl, &l) < 0 || dz_field_read(fr, &r) < 0) {
		running = 0;
		return;
	}
	dz_field_read(fc, &c);
	dz_field_write(fc, c ^ 1);		/* a toggle clears the meters */
	running = 1;
	f_peak = (float)(l > r ? l : r) / 32768.0f;
	f_level = f_peak;
}

/* the newest n mono samples (-1..1) of the capture source, oldest first;
 * 0 when there are none (other source, not running, fewer than n yet) */
int react_samples(float *out, int n, int chan)
{
	const float *r = chan == 1 ? ringl : chan == 2 ? ringr : ring;

	need_ms = ms_now();
	if (src != SRC_CAPTURE || !running || n > RING || rfill < (unsigned)n)
		return 0;
	for (int i = 0; i < n; i++)
		out[i] = r[(rpos + RING - (unsigned)n + (unsigned)i) % RING];
	return n;
}

/* amplitude spectrum of the newest fft_n samples of one channel (0 = (L+R)/2,
 * 1 = L, 2 = R): amp[0..fft_n/2], a full-scale sine = ~1 in its bin.
 * Returns the bin count (fft_n/2 + 1; bin k = k x 48000 / fft_n Hz), 0 =
 * no samples. One FFT per channel and frame (the DDS channels share it). */
int react_spectrum(float *amp, int chan)
{
	static float cache[3][NMAX / 2 + 1];
	/* the cache key is the sample count, not rpos: reads come in 16384-byte
	 * blocks = 4096 samples = RING, so rpos can stand still while every
	 * sample is new (2026-11-02: the fft scope froze, the wave scope ran) */
	static unsigned long at[3] = { ~0ul, ~0ul, ~0ul };
	static int at_n[3];
	const float *r = chan == 1 ? ringl : chan == 2 ? ringr : ring;
	float pw[NMAX / 2 + 1];

	need_ms = ms_now();
	if (chan < 0 || chan > 2 || src != SRC_CAPTURE || !running)
		return 0;
	if (plan_n != fft_n)
		mkplan(fft_n);
	if (rfill < (unsigned)plan_n)
		return 0;
	if (at[chan] != rtotal || at_n[chan] != plan_n) {
		spectrum(r, pw);
		for (int k = 0; k <= plan_n / 2; k++)
			cache[chan][k] = sqrtf(pw[k]) * (4.0f / plan_n);
		at[chan] = rtotal;
		at_n[chan] = plan_n;
	}
	memcpy(amp, cache[chan], sizeof(float) * (size_t)(plan_n / 2 + 1));
	return plan_n / 2 + 1;
}

/* another user of the capture PCM (sound.c recorder): pause / resume */
void react_hold(int on, const char *why)
{
	if (on) {
		if (held++ == 0) {
			snprintf(hold_why, sizeof(hold_why), "%s", why ? why : "");
			if (src == SRC_CAPTURE) {
				capture_stop();	/* waits for arecord: the PCM is free after it */
				snprintf(status, sizeof(status), "held: %s", hold_why);
				dzd_log("react: capture paused (%s)\n", hold_why);
			}
		}
	} else if (held > 0 && --held == 0 && src == SRC_CAPTURE) {
		dzd_log("react: capture resumed\n");
		capture_start();
	}
}

int react_capturing(void)
{
	return src == SRC_CAPTURE && rec_pid > 0;
}

static void set_source(int s);

void react_tick(void)
{
	if (want == SRC_AUTO) {		/* capture while a sink asks */
		int need = need_ms && ms_now() - need_ms < AUTO_LINGER_MS;

		if (need && src != SRC_CAPTURE) {
			dzd_log("react: auto: a sink asks, capture on\n");
			set_source(SRC_CAPTURE);
		} else if (!need && src != SRC_OFF) {
			dzd_log("react: auto: no sink for %d s, capture off\n", AUTO_LINGER_MS / 1000);
			set_source(SRC_OFF);
			snprintf(status, sizeof(status), "auto: idle");
		}
	}
	if (src == SRC_CAPTURE)
		capture_read();
	else if (src == SRC_PEAK)
		peak_read();
}

static const char *feat_names[] = { "level", "peak", "bass", "low", "mid", "high", "air",
				    "flux", "beat" };

const char *react_feature_name(int i)
{
	static char b[16];

	if (i >= 0 && i < 9)
		return feat_names[i];
	snprintf(b, sizeof(b), "band%d", i - 16);
	return b;
}

/* a feature by name, or -1 */
int react_feature_index(const char *name)
{
	const char *const *names = feat_names;

	for (int i = 0; i < 9; i++)
		if (!strcmp(name, names[i]))
			return i;
	if (!strncmp(name, "band", 4) && name[4]) {
		char *e;
		long b = strtol(name + 4, &e, 10);

		if (!*e && b >= 0 && b < 16)
			return 16 + (int)b;
	}
	return -1;
}

float react_feature(int i)
{
	const float v[9] = { f_level, f_peak, f_bass, f_low, f_mid, f_high, f_air, f_flux, f_beat };

	need_ms = ms_now();
	if (src == SRC_OFF || !running)
		return 0.0f;
	if (i >= 0 && i < 9)
		return v[i];
	if (i >= 16 && i < 32)
		return f_band[i - 16];
	return 0.0f;
}

static void set_source(int s)
{
	if (s == src)
		return;
	capture_stop();
	restart_at = 0;
	src = s;
	f_level = f_peak = f_bass = f_low = f_mid = f_high = f_air = f_flux = f_beat = 0;
	memset(f_band, 0, sizeof(f_band));
	memset(prev_band, 0, sizeof(prev_band));
	rfill = 0;
	snprintf(status, sizeof(status), "%s", s == SRC_OFF ? "off" : s == SRC_PEAK ? "ok" : "starting");
	if (s == SRC_CAPTURE && capture_start() < 0)
		dzd_log("react: cannot start arecord\n");
}

void react_state(state_cb cb, void *ctx)
{
	st_emit(cb, ctx, NULL, "/audio/react/fft", "i", fft_n);
	st_emit(cb, ctx, NULL, "/audio/react/source", "s", src_names[want]);
}

void react_stop(void)
{
	capture_stop();
}

int react_dispatch(const dz_msg *m)
{
	if (strncmp(m->path, "/audio/react", 12))
		return 0;
	if (!strcmp(m->path, "/audio/react")) {
		need_ms = ms_now();	/* a meter is a sink too (auto) */
		dzd_reply("/audio/react", "sifffffffffs", src_names[want], running, f_level, f_peak,
			  f_bass, f_low, f_mid, f_high, f_air, f_flux, f_beat, status);
		return 1;
	}
	if (!strcmp(m->path, "/audio/react/bands")) {
		dz_arg a[16];

		for (int b = 0; b < 16; b++)
			a[b] = (dz_arg){ .type = 'f', .f = f_band[b] };
		dzd_reply_args("/audio/react/bands", a, 16);
		return 1;
	}
	if (!strcmp(m->path, "/audio/react/source")) {
		if (m->n >= 1 && m->a[0].type == 's') {
			for (int s = 0; s < 4; s++)
				if (!strcmp(m->a[0].s, src_names[s])) {
					want = s;
					if (s == SRC_AUTO) {	/* react_tick starts it on demand */
						set_source(SRC_OFF);
						snprintf(status, sizeof(status), "auto: idle");
						need_ms = 0;
					} else
						set_source(s);
					dzd_log("react: source %s\n", src_names[s]);
					dzd_reply("/audio/react/source", "s", src_names[want]);
					return 1;
				}
			dzd_reply("/error", "ss", "/audio/react/source", "auto, capture, peak or off");
			return 1;
		}
		dzd_reply("/audio/react/source", "s", src_names[want]);
		return 1;
	}
	if (!strcmp(m->path, "/audio/react/fft")) {
		if (m->n >= 1) {
			int n = m->a[0].type == 'f' ? (int)m->a[0].f : m->a[0].i;

			if (n != 256 && n != 512 && n != 1024) {
				dzd_reply("/error", "ss", "/audio/react/fft", "256, 512 or 1024");
				return 1;
			}
			fft_n = n;
			memset(prev_band, 0, sizeof(prev_band));
		}
		dzd_reply("/audio/react/fft", "i", fft_n);
		return 1;
	}
	return 0;
}

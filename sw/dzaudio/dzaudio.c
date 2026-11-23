/*
 * dzaudio - the units' audio engine: sources -> routing matrix -> outputs
 * (2026-11-21).
 *
 * The base of a mixer / router for all audio work to come (8-channel HDMI
 * gateware, I2S, movie audio, the HDMI_2 input as sources). Today:
 *
 *   sources  fluidsynth (libfluidsynth, General MIDI): ONE synth, each MIDI
 *            channel rendered to its own stereo pair (synth.audio-groups =
 *            16), plus the reverb and the chorus returns. MIDI in from the
 *            ALSA sequencer: client "FLUID Synth (debaz-synth)", the same
 *            name as the old fluidsynth, so Lua midi.* and dzsynth.sh wiring
 *            work as before.
 *   matrix   mono gains: every input channel to every output channel.
 *   outputs  ALSA PCMs ("sinks") of any channel count. Default HDMI 0 +
 *            HDMI 1 (hw:DEBAZ,0 and hw:DEBAZ,1, 2 channels each) = 4 output
 *            channels. A DEBAZ output also gets a copy into /tmp/dztap.<n>
 *            (debazd react.c, source "synth"): written here, non-blocking,
 *            dropped when debazd does not read (no asound.conf tap plugin, no
 *            broken pipe when debazd restarts).
 *
 * Inputs (stereo pairs, index = OSC <in>):
 *   0..15  MIDI channel 1..16 (fluidsynth renders channel c to pair c)
 *   16     reverb return      17  chorus return  (only with -f)
 *   18..33 streams 0..15 (2026-11-22, lib/dz_ain.h): FIFO /tmp/dzin.<n>,
 *          S16LE 48 kHz stereo, made and held open here. debazd writes
 *          movie audio (stream = slot) and /audio/play (12 + out) there
 *          while dzaudio runs, and routes it with /mix/stream. A ring per
 *          stream takes up the writer's jitter (ffmpeg -re); above
 *          STRM_HIGH frames the oldest are dropped (latency stays low), an
 *          empty ring plays silence.
 * Input CHANNEL (mono) = 2 * in + 0 (L) / 1 (R).
 * Output channels are numbered over the sinks in order: -o 0,1 gives
 * 0 = HDMI 0 L, 1 = HDMI 0 R, 2 = HDMI 1 L, 3 = HDMI 1 R; output PAIR p =
 * channels 2p, 2p+1.
 *
 *   dzaudio [-o outs] [-s soundfont] [-f] [-g gain] [-r preset] [-p port]
 *           [-P frames] [-v]
 *     -o  comma list: a DEBAZ playback device number (0, 1, 3 = I2S: no
 *         hardware yet) or an ALSA name with ":channels" (hw:X,Y:8);
 *         default "0,1"
 *     -s  soundfont (default /usr/share/soundfonts/default.sf2)
 *     -f  reverb + chorus on (about twice the CPU)
 *     -g  synth gain (default 0.6)
 *     -r  routing at start: both (default: every input to every pair),
 *         split (MIDI 1-8 -> pair 0, 9-16 -> pair 1, ...), pair<N> (all to
 *         pair N only), off
 *     -p  OSC UDP port (default 9002)
 *     -P  period in frames (default 256 = 5.3 ms)
 *     -c  synth render threads (synth.cpu-cores, default 1)
 *
 * OSC (UDP, the reply goes to the sender; dzctl -p 9002 ...):
 *   /mix/route <in> <pair> [gain]      stereo route (L->L, R->R); gain 0 = off
 *   /mix/route/mono <inch> <outch> g   one matrix entry
 *   /mix/preset both|split|off|pair<N>
 *   /mix/gain [f]                      master gain (query without argument)
 *   /mix/pair/<p>/gain [f]             output pair trim
 *   /mix/routes                        s: "in>pair:gain ..." (+ mono entries)
 *   /mix/routes s:"in>pair:gain ..."   set the matrix from that text (2026-11-22:
 *                                      cues; the stream inputs keep their
 *                                      /mix/stream routes; "none" = all off)
 *   /mix/state                         s:routes (no streams) f:master f:pair gains...
 *                                      (debazd: the mixer in its state / cues)
 *   /mix/status                        s: sinks, xruns, CPU, voices
 *   /mix/sf s:file                     load a soundfont (replaces the old one)
 *   /mix/panic                         all notes / sounds off, controllers reset
 *   /mix/stream <n> <devmask> [gain]   stream n -> the pairs of the DEBAZ
 *                                      devices in devmask (bit d = hw:DEBAZ,d;
 *                                      0 = off); kept by the presets
 *   /mix/streams                       s: "s<n>:<frames buffered>/<under>/<drop>"
 *   /mix/ping                          -> /mix/pong
 *
 * libfluidsynth and libasound are opened with dlopen (the Vitis toolchain
 * has no headers; as dzlua): the prototypes below are the libraries' own.
 * The DEBAZ PCM of a sink has ONE owner: while dzaudio holds HDMI 0 and 1,
 * movie audio and /audio/play come in as streams (above); pcmplay / aplay
 * do not play there, and plreload.sh refuses to load.
 */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <errno.h>
#include <fcntl.h>
#include <math.h>
#include <netinet/in.h>
#include <poll.h>
#include <pthread.h>
#include <sched.h>
#include <signal.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <time.h>
#include <unistd.h>

#include "dz_osc.h"
#include "dz_ain.h"

#define RATE		48000
#define N_MIDI		16			/* stereo inputs from the MIDI channels */
#define N_FX		2			/* reverb, chorus returns */
#define IN_STRM		(N_MIDI + N_FX)		/* first stream input */
#define N_IN		(IN_STRM + DZA_STREAMS)
#define N_INCH		(2 * N_IN)
#define MAX_SINKS	8
#define MAX_OUTCH	32
#define MAX_PERIOD	2048
#define LATENCY_US	40000			/* ALSA buffer per sink */

/* ---- libfluidsynth (2.2) and libasound, by dlopen ------------------------- */
typedef void fl_settings;
typedef void fl_synth;
typedef void fl_mdriver;
typedef int (*fl_handler)(void *data, void *event);
static struct {
	fl_settings *(*new_settings)(void);
	int (*setint)(fl_settings *, const char *, int);
	int (*setnum)(fl_settings *, const char *, double);
	int (*setstr)(fl_settings *, const char *, const char *);
	fl_synth *(*new_synth)(fl_settings *);
	int (*sfload)(fl_synth *, const char *, int);
	int (*sfunload)(fl_synth *, int, int);
	int (*process)(fl_synth *, int, int, float **, int, float **);
	int (*system_reset)(fl_synth *);
	int (*voices)(fl_synth *);
	fl_mdriver *(*new_mdriver)(fl_settings *, fl_handler, void *);
	fl_handler handle_midi;
} F;

typedef void snd_pcm;
#define SND_PCM_STREAM_PLAYBACK		0
#define SND_PCM_NONBLOCK		1
#define SND_PCM_FORMAT_S16_LE		2
#define SND_PCM_ACCESS_RW_INTERLEAVED	3
static struct {
	int (*open)(snd_pcm **, const char *, int, int);
	int (*close)(snd_pcm *);
	int (*set_params)(snd_pcm *, int, int, unsigned, unsigned, int, unsigned);
	long (*writei)(snd_pcm *, const void *, unsigned long);
	int (*recover)(snd_pcm *, int, int);
	int (*wait)(snd_pcm *, int);
	int (*drop)(snd_pcm *);
	const char *(*strerror)(int);
} A;

static int load_libs(void)
{
	void *f = dlopen("libfluidsynth.so.3", RTLD_NOW);
	void *a = dlopen("libasound.so.2", RTLD_NOW);

	if (!f || !a) {
		fprintf(stderr, "dzaudio: %s\n", dlerror());
		return -1;
	}
#define SYM(lib, dst, name) do { *(void **)&(dst) = dlsym(lib, name); \
	if (!(dst)) { fprintf(stderr, "dzaudio: no %s\n", name); return -1; } } while (0)
	SYM(f, F.new_settings, "new_fluid_settings");
	SYM(f, F.setint, "fluid_settings_setint");
	SYM(f, F.setnum, "fluid_settings_setnum");
	SYM(f, F.setstr, "fluid_settings_setstr");
	SYM(f, F.new_synth, "new_fluid_synth");
	SYM(f, F.sfload, "fluid_synth_sfload");
	SYM(f, F.sfunload, "fluid_synth_sfunload");
	SYM(f, F.process, "fluid_synth_process");
	SYM(f, F.system_reset, "fluid_synth_system_reset");
	SYM(f, F.voices, "fluid_synth_get_active_voice_count");
	SYM(f, F.new_mdriver, "new_fluid_midi_driver");
	SYM(f, F.handle_midi, "fluid_synth_handle_midi_event");
	SYM(a, A.open, "snd_pcm_open");
	SYM(a, A.close, "snd_pcm_close");
	SYM(a, A.set_params, "snd_pcm_set_params");
	SYM(a, A.writei, "snd_pcm_writei");
	SYM(a, A.recover, "snd_pcm_recover");
	SYM(a, A.wait, "snd_pcm_wait");
	SYM(a, A.drop, "snd_pcm_drop");
	SYM(a, A.strerror, "snd_strerror");
#undef SYM
	return 0;
}

/* ---- state ----------------------------------------------------------------- */
enum { S_DOWN, S_OPEN, S_STALLED };
static const char *st_name[] = { "down", "open", "stalled" };

typedef struct {
	char     name[64];		/* ALSA device */
	int      ch;			/* channels */
	int      first;		/* first output channel of the matrix */
	int      debaz;		/* DEBAZ device number (tap), else -1 */
	snd_pcm *pcm;
	int      state;
	long     retry_ms;		/* next open attempt */
	long     backoff_ms;
	unsigned xruns, stalls, opens, drops;
	long     progress_ms;		/* last frames taken */
	long     opened_ms;
	int      tapfd;
	long     tap_retry_ms;
	unsigned tap_drops;
	int16_t *buf;
} sink_t;

static sink_t   sink[MAX_SINKS];
static int      nsink, noutch;
static int      period = 256, verbose;
static fl_synth *synth;
static int      fxon, sfid = -1, cores = 1;

/* matrix: written by the control thread under mu, copied by the audio
 * thread when gen changes (trylock: the audio thread never waits) */
static pthread_mutex_t mu = PTHREAD_MUTEX_INITIALIZER;
static float    mtx[MAX_OUTCH][N_INCH];
static float    pair_gain[MAX_OUTCH / 2];
static float    master = 1.0f;
static unsigned gen = 1;

/* stream inputs: FIFO -> ring (audio thread only), routes (under mu) */
#define STRM_RING	16384			/* frames, power of 2 (341 ms) */
#define STRM_HIGH	9600			/* above: drop the oldest down to STRM_LOW */
#define STRM_LOW	4800			/* 100 ms */
typedef struct {
	int      fd;
	int16_t  ring[STRM_RING * 2];
	unsigned wr, rd;			/* frames, free running */
	uint8_t  carry[4];			/* a part frame from the last read */
	int      ncarry;
	int      primed;			/* buffered STRM_LOW once: playing */
	volatile unsigned under, drop;		/* periods short / frames dropped */
	unsigned mask;				/* /mix/stream devmask (mu) */
	float    gain;
} strm_t;
static strm_t strm[DZA_STREAMS];

/* stats (audio thread writes, control thread reads: approximate is fine) */
static volatile double cpu_avg, cpu_max, render_avg;
static volatile unsigned long periods;

static long ms_now(void)
{
	struct timespec t;

	clock_gettime(CLOCK_MONOTONIC, &t);
	return t.tv_sec * 1000L + t.tv_nsec / 1000000L;
}

static void logf_(const char *fmt, ...)
{
	va_list ap;
	char t[16];
	time_t now = time(NULL);

	strftime(t, sizeof(t), "%H:%M:%S", localtime(&now));
	fprintf(stderr, "dzaudio %s: ", t);
	va_start(ap, fmt);
	vfprintf(stderr, fmt, ap);
	va_end(ap);
}

/* ---- sinks ----------------------------------------------------------------- */
static int add_sink(const char *spec)
{
	sink_t *s = &sink[nsink];
	char *end;
	long n = strtol(spec, &end, 10);

	if (nsink >= MAX_SINKS)
		return -1;
	memset(s, 0, sizeof(*s));
	s->debaz = -1;
	s->tapfd = -1;
	if (*spec && !*end && n >= 0 && n < 16) {	/* a DEBAZ device number */
		snprintf(s->name, sizeof(s->name), "hw:DEBAZ,%ld", n);
		s->ch = 2;
		s->debaz = (int)n;
	} else {
		const char *c = strrchr(spec, ':');

		snprintf(s->name, sizeof(s->name), "%.*s", c ? (int)(c - spec) : (int)strlen(spec), spec);
		s->ch = c ? atoi(c + 1) : 2;
		if (sscanf(s->name, "hw:DEBAZ,%ld", &n) == 1)
			s->debaz = (int)n;
	}
	if (s->ch < 1 || noutch + s->ch > MAX_OUTCH)
		return -1;
	s->first = noutch;
	noutch += s->ch;
	s->buf = calloc((size_t)MAX_PERIOD * s->ch, sizeof(int16_t));
	nsink++;
	return 0;
}

static void sink_open(sink_t *s, long now)
{
	int r = A.open(&s->pcm, s->name, SND_PCM_STREAM_PLAYBACK, SND_PCM_NONBLOCK);

	if (r == 0)
		r = A.set_params(s->pcm, SND_PCM_FORMAT_S16_LE, SND_PCM_ACCESS_RW_INTERLEAVED,
				 (unsigned)s->ch, RATE, 0, LATENCY_US);
	if (r < 0) {
		if (s->pcm)
			A.close(s->pcm);
		s->pcm = NULL;
		if (s->opens == 0 || verbose)
			logf_("%s: %s (retry)\n", s->name, A.strerror(r));
		s->opens += s->opens == 0;	/* log the first failure only */
		s->backoff_ms = s->backoff_ms ? (s->backoff_ms * 2 > 30000 ? 30000 : s->backoff_ms * 2) : 1000;
		s->retry_ms = now + s->backoff_ms;
		return;
	}
	s->state = S_OPEN;
	s->progress_ms = s->opened_ms = now;
	s->opens++;
	if (s->stalls < 3 || verbose)
		logf_("%s: open, %d channels -> outputs %d..%d%s\n", s->name, s->ch, s->first,
		      s->first + s->ch - 1, s->debaz >= 0 ? " (tap)" : "");
}

static void sink_fail(sink_t *s, int state, long now, const char *why)
{
	if (s->stalls < 3 || state != S_STALLED || verbose)
		logf_("%s: %s%s\n", s->name, why, s->stalls == 2 && state == S_STALLED ?
		      " (further stalls: /mix/status)" : "");
	if (s->pcm) {
		A.drop(s->pcm);
		A.close(s->pcm);
	}
	s->pcm = NULL;
	s->state = state;
	if (state == S_STALLED)
		s->stalls++;
	s->backoff_ms = s->backoff_ms ? (s->backoff_ms * 2 > 30000 ? 30000 : s->backoff_ms * 2) : 2000;
	s->retry_ms = now + s->backoff_ms;
}

/* write one period. The PACER (the first open sink) waits for room: it sets
 * the loop's pace, at most 4 periods + the buffer, else it is closed as
 * stalled. Every other sink takes what fits without waiting (the rest of the
 * period is dropped and counted): a sink without a clock (I2S with no
 * master running) never holds up the others; one that takes nothing for
 * STALL_MS is closed and tried again later, with a growing pause. */
#define STALL_MS	500
static void sink_write(sink_t *s, long now, int pace)
{
	long off = 0;
	int tmo = (int)(4 * period * 1000L / RATE) + LATENCY_US / 1000;

	while (off < period) {
		long r = A.writei(s->pcm, s->buf + off * s->ch, (unsigned long)(period - off));

		if (r > 0) {
			off += r;
			continue;
		}
		if (r == -EAGAIN && !pace) {
			s->drops += (unsigned)(period - off);
			if (!off && now - s->progress_ms > STALL_MS) {
				sink_fail(s, S_STALLED, now, "takes no audio: stalled (no clock?)");
				return;
			}
			break;
		}
		if (r == -EAGAIN) {
			int w = A.wait(s->pcm, tmo);

			if (w == 0) {
				sink_fail(s, S_STALLED, now, "no room for a period: stalled (no clock?)");
				return;
			}
			if (w > 0)
				continue;
			r = w;
		}
		s->xruns++;
		if (A.recover(s->pcm, (int)r, 1) < 0) {
			sink_fail(s, S_DOWN, now, A.strerror((int)r));
			return;
		}
	}
	if (off)
		s->progress_ms = now;
	if (off == period && now - s->opened_ms > 10000)
		s->backoff_ms = 0;		/* ran well for 10 s: retry fast again */
}

/* the copy for debazd: S16 stereo (the sink's first two channels) */
static void tap_write(sink_t *s, long now)
{
	static int16_t t[MAX_PERIOD * 2];
	char p[32];
	const int16_t *src = s->buf;
	ssize_t n;

	if (s->debaz < 0)
		return;
	if (s->tapfd < 0) {
		if (now < s->tap_retry_ms)
			return;
		s->tap_retry_ms = now + 1000;
		snprintf(p, sizeof(p), "/tmp/dztap.%d", s->debaz);
		s->tapfd = open(p, O_WRONLY | O_NONBLOCK | O_CLOEXEC);	/* ENXIO: no reader */
		if (s->tapfd < 0)
			return;
	}
	if (s->ch != 2) {
		for (int i = 0; i < period; i++) {
			t[2 * i] = s->buf[i * s->ch];
			t[2 * i + 1] = s->buf[i * s->ch + (s->ch > 1)];
		}
		src = t;
	}
	n = write(s->tapfd, src, (size_t)period * 4);
	if (n < 0 && errno == EAGAIN)
		s->tap_drops++;			/* full: debazd does not read now */
	else if (n < 0) {			/* EPIPE: debazd gone; reopen later */
		close(s->tapfd);
		s->tapfd = -1;
	}
}

/* ---- mixing (NEON; n is a multiple of 64: period >= 64, fluidsynth blocks) -- */
#ifdef __ARM_NEON
#include <arm_neon.h>
static int silent(const float *a, int n)
{
	uint32x4_t acc = vdupq_n_u32(0);

	for (int t = 0; t < n; t += 4)	/* any bit but the sign: not +-0 */
		acc = vorrq_u32(acc, vandq_u32(vreinterpretq_u32_f32(vld1q_f32(a + t)), vdupq_n_u32(0x7fffffff)));
	return (vgetq_lane_u32(acc, 0) | vgetq_lane_u32(acc, 1) | vgetq_lane_u32(acc, 2) | vgetq_lane_u32(acc, 3)) == 0;
}

static void mac(float *b, const float *a, float g, int n)
{
	for (int t = 0; t < n; t += 4)
		vst1q_f32(b + t, vmlaq_n_f32(vld1q_f32(b + t), vld1q_f32(a + t), g));
}

static void to_s16(int16_t *d, const float *b, int n)	/* saturating */
{
	for (int t = 0; t < n; t += 4)
		vst1_s16(d + t, vqmovn_s32(vcvtq_s32_f32(vmulq_n_f32(vld1q_f32(b + t), 32767.0f))));
}
#else	/* host builds */
static int silent(const float *a, int n)
{
	for (int t = 0; t < n; t++)
		if (a[t] != 0.0f)
			return 0;
	return 1;
}

static void mac(float *b, const float *a, float g, int n)
{
	for (int t = 0; t < n; t++)
		b[t] += g * a[t];
}

static void to_s16(int16_t *d, const float *b, int n)
{
	for (int t = 0; t < n; t++) {
		float v = b[t] * 32767.0f;

		d[t] = (int16_t)(v > 32767.0f ? 32767 : v < -32768.0f ? -32768 : (int)v);
	}
}
#endif

/* ---- stream inputs --------------------------------------------------------- */
/* the routes survive a dzaudio restart (2026-11-22, edge.py: after a restart
 * the playing movies' streams had no route = silent until the movie
 * restarted); a route for a movie that ended is harmless (silent input) */
#define STRM_SAVE	"/tmp/dzaudio.streams"

static void strm_save(void)	/* mu held */
{
	FILE *f = fopen(STRM_SAVE ".tmp", "w");

	if (!f)
		return;
	for (int n = 0; n < DZA_STREAMS; n++)
		if (strm[n].mask)
			fprintf(f, "%d %u %g\n", n, strm[n].mask, (double)strm[n].gain);
	if (fclose(f) == 0)
		rename(STRM_SAVE ".tmp", STRM_SAVE);
}

static void strm_load(void)	/* before the audio thread */
{
	FILE *f = fopen(STRM_SAVE, "r");
	int n, k = 0;
	unsigned mask;
	double g;

	if (!f)
		return;
	while (fscanf(f, "%d %u %lf", &n, &mask, &g) == 3)
		if (n >= 0 && n < DZA_STREAMS && isfinite(g)) {
			strm[n].mask = mask;
			strm[n].gain = (float)g;
			k++;
		}
	fclose(f);
	if (k)
		logf_("%d stream routes from %s\n", k, STRM_SAVE);
}

static void strm_open_all(void)
{
	for (int n = 0; n < DZA_STREAMS; n++) {
		char p[32];
		struct stat st;

		snprintf(p, sizeof(p), DZA_FIFO, n);
		if (lstat(p, &st) == 0 && !S_ISFIFO(st.st_mode))
			unlink(p);
		if (mkfifo(p, 0660) < 0 && errno != EEXIST) {
			logf_("%s: %s\n", p, strerror(errno));
			strm[n].fd = -1;
			continue;
		}
		/* read-write: the writer's open never blocks, and no EOF when it
		 * goes (a pipe with no writer would read 0 for ever) */
		strm[n].fd = open(p, O_RDWR | O_NONBLOCK | O_CLOEXEC);
		strm[n].gain = 1.0f;
	}
}

/* drain the FIFO into the ring, then one period (zeros if short) into L, R */
static int strm_read(strm_t *t, float *l, float *r)
{
	uint8_t b[16384];
	ssize_t k;
	unsigned fill;

	if (t->fd < 0)
		return 0;
	memcpy(b, t->carry, (size_t)t->ncarry);	/* a part frame first */
	while ((k = read(t->fd, b + t->ncarry, sizeof(b) - (size_t)t->ncarry)) > 0) {
		size_t all = (size_t)k + (size_t)t->ncarry, fr = all / 4;

		for (size_t i = 0; i < fr; i++) {
			memcpy(&t->ring[(t->wr & (STRM_RING - 1)) * 2], b + i * 4, 4);
			t->wr++;
		}
		t->ncarry = (int)(all - fr * 4);
		memcpy(t->carry, b + fr * 4, (size_t)t->ncarry);
		memcpy(b, t->carry, (size_t)t->ncarry);
		if (t->wr - t->rd > STRM_RING - 1) {	/* overrun: keep the newest */
			t->drop += t->wr - t->rd - (STRM_RING - 1);
			t->rd = t->wr - (STRM_RING - 1);
		}
	}
	fill = t->wr - t->rd;
	if (!t->primed) {			/* start with some reserve */
		if (fill < STRM_LOW)
			return 0;
		t->primed = 1;
	}
	if (fill > STRM_HIGH) {			/* the writer runs ahead: catch up */
		t->drop += fill - STRM_LOW;
		t->rd = t->wr - STRM_LOW;
		fill = STRM_LOW;
	}
	if (fill == 0) {			/* ran dry (stopped, paused): wait */
		t->primed = 0;
		return 0;
	}
	if (fill < (unsigned)period)
		t->under++;
	for (int i = 0; i < period; i++) {
		if ((unsigned)i < fill) {
			const int16_t *f = &t->ring[((t->rd + (unsigned)i) & (STRM_RING - 1)) * 2];

			l[i] = f[0] * (1.0f / 32768.0f);
			r[i] = f[1] * (1.0f / 32768.0f);
		} else
			l[i] = r[i] = 0.0f;
	}
	t->rd += fill < (unsigned)period ? fill : (unsigned)period;
	return 1;
}

/* ---- the audio thread ------------------------------------------------------ */
typedef struct { uint8_t in, out; float g; } route_t;

static void *audio_thread(void *arg)
{
	static float inb[N_INCH][MAX_PERIOD] __attribute__((aligned(16)));
	static float outb[MAX_OUTCH][MAX_PERIOD] __attribute__((aligned(16)));
	static int16_t conv[MAX_PERIOD] __attribute__((aligned(16)));
	int live[N_INCH];
	float *dry[2 * N_MIDI], *fx[4];
	route_t plan[MAX_OUTCH * N_INCH];
	int nplan = 0;
	unsigned seen = 0;
	struct timespec next;
	(void)arg;

	for (int i = 0; i < 2 * N_MIDI; i++)
		dry[i] = inb[i];
	for (int i = 0; i < 4; i++)
		fx[i] = inb[2 * N_MIDI + i];	/* reverb L R, chorus L R */
	clock_gettime(CLOCK_MONOTONIC, &next);
	for (;;) {
		struct timespec t0, tr, t1;
		long now = ms_now();
		int any = 0;

		/* a new routing: copy it (never wait for the control thread) */
		if (seen != gen && pthread_mutex_trylock(&mu) == 0) {
			nplan = 0;
			for (int o = 0; o < noutch; o++)
				for (int i = 0; i < N_INCH; i++)
					if (mtx[o][i] != 0.0f)
						plan[nplan++] = (route_t){ (uint8_t)i, (uint8_t)o,
							mtx[o][i] * pair_gain[o / 2] * master };
			seen = gen;
			pthread_mutex_unlock(&mu);
		}
		clock_gettime(CLOCK_MONOTONIC, &t0);
		for (int i = 0; i < 2 * IN_STRM; i++)
			memset(inb[i], 0, sizeof(float) * (size_t)period);
		F.process(synth, period, fxon ? 4 : 0, fxon ? fx : NULL, 2 * N_MIDI, dry);
		clock_gettime(CLOCK_MONOTONIC, &tr);
		/* a MIDI channel with no voice renders zeros: skip it in the mix */
		for (int i = 0; i < 2 * IN_STRM; i++)
			live[i] = !silent(inb[i], period);
		for (int n = 0; n < DZA_STREAMS; n++)
			live[2 * (IN_STRM + n)] = live[2 * (IN_STRM + n) + 1] =
				strm_read(&strm[n], inb[2 * (IN_STRM + n)], inb[2 * (IN_STRM + n) + 1]);
		for (int o = 0; o < noutch; o++)
			memset(outb[o], 0, sizeof(float) * (size_t)period);
		for (int k = 0; k < nplan; k++)
			if (live[plan[k].in])
				mac(outb[plan[k].out], inb[plan[k].in], plan[k].g, period);
		for (int s = 0; s < nsink; s++) {
			sink_t *k = &sink[s];

			for (int c = 0; c < k->ch; c++) {
				to_s16(conv, outb[k->first + c], period);
				for (int t = 0; t < period; t++)
					k->buf[t * k->ch + c] = conv[t];
			}
		}
		clock_gettime(CLOCK_MONOTONIC, &t1);
		{
			double us = (t1.tv_sec - t0.tv_sec) * 1e6 + (t1.tv_nsec - t0.tv_nsec) / 1e3;
			double pct = 100.0 * us / (period * 1e6 / RATE);

			cpu_avg = cpu_avg * 0.99 + pct * 0.01;
			us = (tr.tv_sec - t0.tv_sec) * 1e6 + (tr.tv_nsec - t0.tv_nsec) / 1e3;
			render_avg = render_avg * 0.99 + 100.0 * us / (period * 1e6 / RATE) * 0.01;
			if (pct > cpu_max)
				cpu_max = pct;
		}
		for (int s = 0; s < nsink; s++) {
			sink_t *k = &sink[s];

			if (k->state != S_OPEN && now >= k->retry_ms)
				sink_open(k, now);
			if (k->state == S_OPEN) {
				sink_write(k, now, !any);
				if (k->state == S_OPEN) {
					tap_write(k, now);
					any = 1;
				}
			}
		}
		periods++;
		/* no sink took the period: keep time ourselves (the synth, the
		 * scheduled MIDI and the taps run on) */
		next.tv_nsec += (long)period * 1000000000L / RATE;
		while (next.tv_nsec >= 1000000000L) {
			next.tv_nsec -= 1000000000L;
			next.tv_sec++;
		}
		if (any)
			clock_gettime(CLOCK_MONOTONIC, &next);
		else
			clock_nanosleep(CLOCK_MONOTONIC, TIMER_ABSTIME, &next, NULL);
	}
	return NULL;
}

/* ---- routing --------------------------------------------------------------- */
static void route_stereo(int in, int pair, float g)	/* mu held */
{
	if (in < 0 || in >= N_IN || pair < 0 || 2 * pair + 1 >= noutch)
		return;
	mtx[2 * pair][2 * in] = g;
	mtx[2 * pair + 1][2 * in + 1] = g;
}

/* stream n -> every pair whose sink is a DEBAZ device in its mask (mu held) */
static void strm_route(int n)
{
	for (int q = 0; 2 * q + 1 < noutch; q++)
		route_stereo(IN_STRM + n, q, 0.0f);
	for (int k = 0; k < nsink; k++)
		if (sink[k].debaz >= 0 && sink[k].debaz < 32 && (strm[n].mask >> sink[k].debaz & 1u))
			for (int c = 0; c + 1 < sink[k].ch; c += 2)
				route_stereo(IN_STRM + n, (sink[k].first + c) / 2, strm[n].gain);
}

static int preset(const char *name)	/* mu held */
{
	int npair = noutch / 2, p = 0;

	if (strcmp(name, "off") && strcmp(name, "both") && strcmp(name, "split") &&
	    !(sscanf(name, "pair%d", &p) == 1 && p >= 0 && p < npair))
		return -1;
	memset(mtx, 0, sizeof(mtx));
	for (int n = 0; n < DZA_STREAMS; n++)	/* the streams keep their routes */
		strm_route(n);
	for (int in = 0; in < IN_STRM; in++) {
		if (!strcmp(name, "both"))
			for (int q = 0; q < npair; q++)
				route_stereo(in, q, 1.0f);
		else if (!strcmp(name, "split") && npair)
			route_stereo(in, in < N_MIDI ? in * npair / N_MIDI : in - N_MIDI < npair ? in - N_MIDI : 0, 1.0f);
		else if (!strncmp(name, "pair", 4))
			route_stereo(in, p, 1.0f);
	}
	if (!strcmp(name, "split") && npair)		/* fx returns to every pair */
		for (int q = 0; q < npair; q++) {
			route_stereo(N_MIDI, q, 1.0f);
			route_stereo(N_MIDI + 1, q, 1.0f);
		}
	gen++;
	return 0;
}

static const char *in_name(int in, char *b, size_t n)
{
	if (in < N_MIDI)
		snprintf(b, n, "ch%d", in + 1);
	else if (in >= IN_STRM)
		snprintf(b, n, "s%d", in - IN_STRM);
	else
		snprintf(b, n, "%s", in == N_MIDI ? "rev" : "cho");
	return b;
}

/* the matrix as text: "ch1>0:1.00 ... m5>2:0.50" (mu held); streams optional */
static size_t routes_text(char *s, size_t cap, int streams)
{
	size_t o = 0;
	char nb[8];
	int nin = streams ? N_IN : IN_STRM;

	for (int in = 0; in < nin; in++)	/* stereo routes first */
		for (int q = 0; 2 * q + 1 < noutch; q++)
			if (mtx[2 * q][2 * in] != 0.0f && mtx[2 * q][2 * in] == mtx[2 * q + 1][2 * in + 1] && o < cap - 40)
				o += (size_t)snprintf(s + o, cap - o, "%s%s>%d:%.3g", o ? " " : "",
						      in_name(in, nb, sizeof(nb)), q, mtx[2 * q][2 * in]);
	for (int q = 0; q < noutch; q++)	/* the rest as mono entries */
		for (int i = 0; i < 2 * nin; i++) {
			float g = mtx[q][i];
			int st = (i & 1) == (q & 1) && g == mtx[q ^ 1][i ^ 1];

			if (g != 0.0f && !st && o < cap - 40)
				o += (size_t)snprintf(s + o, cap - o, "%sm%d>%d:%.3g", o ? " " : "", i, q, g);
		}
	if (!o)
		o = (size_t)snprintf(s, cap, "none");
	return o;
}

/* set the non-stream part of the matrix from routes_text's format (mu held) */
static void routes_set(const char *t)
{
	char tok[48];
	int k;

	for (int o = 0; o < MAX_OUTCH; o++)
		for (int i = 0; i < 2 * IN_STRM; i++)
			mtx[o][i] = 0.0f;
	while (sscanf(t, " %47s%n", tok, &k) == 1) {
		int in = -1, q, ch;
		float g;
		char *gt = strchr(tok, '>');

		t += k;
		if (!gt || sscanf(gt + 1, "%d:%f", &q, &g) != 2 || !isfinite(g) || q < 0)
			continue;
		*gt = 0;
		if (tok[0] == 'm' && sscanf(tok + 1, "%d", &ch) == 1) {	/* mono */
			if (ch >= 0 && ch < 2 * IN_STRM && q < noutch)
				mtx[q][ch] = g;
			continue;
		}
		if (!strncmp(tok, "ch", 2))
			in = atoi(tok + 2) - 1;
		else if (!strcmp(tok, "rev"))
			in = N_MIDI;
		else if (!strcmp(tok, "cho"))
			in = N_MIDI + 1;
		if (in >= 0 && in < IN_STRM)	/* s<n>: streams keep their own routes */
			route_stereo(in, q, g);
	}
	gen++;
}

/* ---- control (main thread): OSC over UDP ------------------------------------ */
static int sock;
static struct sockaddr_in peer;
static socklen_t peerlen;

static void reply(const char *path, const char *tags, ...)
{
	uint8_t b[DZ_OSC_MAX_PKT];
	va_list ap;
	size_t n;

	va_start(ap, tags);
	n = dz_osc_vbuild(b, sizeof(b), path, tags, ap);
	va_end(ap);
	if (n)
		sendto(sock, b, n, 0, (struct sockaddr *)&peer, peerlen);
}

static float argf(const dz_arg *a)
{
	return a->type == 'f' ? a->f : (float)a->i;
}

static int argi(const dz_arg *a)
{
	return a->type == 'f' ? (int)a->f : a->i;
}

static void on_msg(dz_msg *m, void *ctx)
{
	char s[4096];
	size_t o = 0;
	int p;
	(void)ctx;

	for (int k = 0; k < m->n; k++)		/* no NaN / inf (a NaN gain = silence) */
		if (m->a[k].type == 'f' && !isfinite(m->a[k].f)) {
			reply("/error", "ss", m->path, "not a finite number (nan / inf)");
			return;
		}
	if (!strcmp(m->path, "/mix/ping")) {
		reply("/mix/pong", "");
	} else if (!strcmp(m->path, "/mix/route") && m->n >= 2) {
		pthread_mutex_lock(&mu);
		route_stereo(argi(&m->a[0]), argi(&m->a[1]), m->n > 2 ? argf(&m->a[2]) : 1.0f);
		gen++;
		pthread_mutex_unlock(&mu);
	} else if (!strcmp(m->path, "/mix/route/mono") && m->n >= 3) {
		int i = argi(&m->a[0]), q = argi(&m->a[1]);

		if (i >= 0 && i < N_INCH && q >= 0 && q < noutch) {
			pthread_mutex_lock(&mu);
			mtx[q][i] = argf(&m->a[2]);
			gen++;
			pthread_mutex_unlock(&mu);
		} else
			reply("/error", "ss", m->path, "inch 0..67, outch 0..outputs-1");
	} else if (!strcmp(m->path, "/mix/preset") && m->n >= 1 && m->a[0].type == 's') {
		pthread_mutex_lock(&mu);
		p = preset(m->a[0].s);
		pthread_mutex_unlock(&mu);
		if (p < 0)
			reply("/error", "ss", m->path, "both, split, off or pair<N>");
	} else if (!strcmp(m->path, "/mix/gain")) {
		if (m->n >= 1) {
			pthread_mutex_lock(&mu);
			master = argf(&m->a[0]);
			gen++;
			pthread_mutex_unlock(&mu);
		}
		reply("/mix/gain", "f", (double)master);
	} else if (sscanf(m->path, "/mix/pair/%d/gain", &p) == 1 && p >= 0 && 2 * p + 1 < noutch) {
		if (m->n >= 1) {
			pthread_mutex_lock(&mu);
			pair_gain[p] = argf(&m->a[0]);
			gen++;
			pthread_mutex_unlock(&mu);
		}
		reply(m->path, "f", (double)pair_gain[p]);
	} else if (!strcmp(m->path, "/mix/routes")) {
		pthread_mutex_lock(&mu);
		if (m->n >= 1 && m->a[0].type == 's')
			routes_set(m->a[0].s);
		routes_text(s, sizeof(s), 1);
		pthread_mutex_unlock(&mu);
		reply("/mix/routes", "s", s);
	} else if (!strcmp(m->path, "/mix/state")) {
		dz_arg a[DZ_OSC_MAX_ARGS];
		int na = 0;
		uint8_t b[DZ_OSC_MAX_PKT];
		size_t len;

		pthread_mutex_lock(&mu);
		routes_text(s, sizeof(s), 0);
		a[na++] = (dz_arg){ .type = 's', .s = s };
		a[na++] = (dz_arg){ .type = 'f', .f = master };
		for (int q = 0; 2 * q + 1 < noutch && na < DZ_OSC_MAX_ARGS; q++)
			a[na++] = (dz_arg){ .type = 'f', .f = pair_gain[q] };
		pthread_mutex_unlock(&mu);
		len = dz_osc_build_args(b, sizeof(b), "/mix/state", a, na);
		if (len)
			sendto(sock, b, len, 0, (struct sockaddr *)&peer, peerlen);
	} else if (!strcmp(m->path, "/mix/status")) {
		o = (size_t)snprintf(s, sizeof(s), "cpu %.1f%% max %.1f%% (render %.1f%%), voices %d, period %d, outputs %d,",
				     cpu_avg, cpu_max, render_avg, F.voices(synth), period, noutch);
		for (int k = 0; k < nsink && o < sizeof(s) - 120; k++)
			o += (size_t)snprintf(s + o, sizeof(s) - o, " %s %s xruns %u stalls %u drops %u%s%s", sink[k].name,
					      st_name[sink[k].state], sink[k].xruns, sink[k].stalls, sink[k].drops,
					      sink[k].debaz >= 0 ? (sink[k].tapfd >= 0 ? " tap" : " no-tap") : "",
					      k + 1 < nsink ? ";" : "");
		cpu_max = 0;
		reply("/mix/status", "s", s);
	} else if (!strcmp(m->path, "/mix/sf") && m->n >= 1 && m->a[0].type == 's') {
		int id = F.sfload(synth, m->a[0].s, 1);

		if (id < 0) {
			reply("/error", "ss", m->path, "could not load the soundfont");
		} else {
			if (sfid >= 0)
				F.sfunload(synth, sfid, 1);
			sfid = id;
			reply("/mix/sf", "s", m->a[0].s);
		}
	} else if (!strcmp(m->path, "/mix/stream") && m->n >= 2) {
		int n = argi(&m->a[0]);

		if (n < 0 || n >= DZA_STREAMS) {
			reply("/error", "ss", m->path, "stream 0..15");
			return;
		}
		pthread_mutex_lock(&mu);
		strm[n].mask = (unsigned)argi(&m->a[1]);
		if (m->n > 2 && isfinite(argf(&m->a[2])))
			strm[n].gain = argf(&m->a[2]);
		strm_route(n);
		strm_save();
		gen++;
		pthread_mutex_unlock(&mu);
		if (verbose)
			logf_("stream %d -> devices 0x%x, gain %.2f\n", n, strm[n].mask, strm[n].gain);
	} else if (!strcmp(m->path, "/mix/streams")) {
		for (int n = 0; n < DZA_STREAMS && o < sizeof(s) - 60; n++)
			if (strm[n].mask || strm[n].wr != strm[n].rd || strm[n].under || strm[n].drop)
				o += (size_t)snprintf(s + o, sizeof(s) - o, "%ss%d:dev0x%x:%u/%u/%u", o ? " " : "", n,
						      strm[n].mask, strm[n].wr - strm[n].rd, strm[n].under, strm[n].drop);
		reply("/mix/streams", "s", o ? s : "none");
	} else if (!strcmp(m->path, "/mix/panic")) {
		F.system_reset(synth);
	} else {
		reply("/error", "ss", m->path, "unknown (see dzaudio -h)");
	}
}

int main(int argc, char **argv)
{
	const char *outs = "0,1", *sf = "/usr/share/soundfonts/default.sf2", *pre = "both";
	double gain = 0.6;
	int port = 9002, opt;
	fl_settings *set;
	pthread_t th;
	pthread_attr_t at;
	struct sched_param sp = { .sched_priority = 70 };
	struct sockaddr_in a = { .sin_family = AF_INET };
	char *list, *tok, *save;

	while ((opt = getopt(argc, argv, "o:s:fg:r:p:P:c:vh")) != -1) {
		switch (opt) {
		case 'o': outs = optarg; break;
		case 's': sf = optarg; break;
		case 'f': fxon = 1; break;
		case 'g': gain = atof(optarg); break;
		case 'r': pre = optarg; break;
		case 'p': port = atoi(optarg); break;
		case 'P': period = atoi(optarg); break;
		case 'c': cores = atoi(optarg); break;
		case 'v': verbose = 1; break;
		default:
			fprintf(stderr, "usage: dzaudio [-o 0,1|hw:X,Y:ch,...] [-s sf2] [-f] [-g gain] "
				"[-r both|split|off|pairN] [-p port] [-P frames] [-v]\n");
			return 2;
		}
	}
	if (period < 64 || period > MAX_PERIOD)
		period = 256;
	period &= ~63;			/* NEON loops, fluidsynth's 64-frame blocks */
	signal(SIGPIPE, SIG_IGN);
	list = strdup(outs);
	for (tok = strtok_r(list, ",", &save); tok; tok = strtok_r(NULL, ",", &save))
		if (add_sink(tok) < 0) {
			fprintf(stderr, "dzaudio: bad output \"%s\" (max %d sinks, %d channels)\n",
				tok, MAX_SINKS, MAX_OUTCH);
			return 2;
		}
	if (!nsink)
		return 2;
	for (int q = 0; q < MAX_OUTCH / 2; q++)
		pair_gain[q] = 1.0f;
	if (preset(pre) < 0) {
		fprintf(stderr, "dzaudio: preset both, split, off or pair<N>\n");
		return 2;
	}

	/* the control socket first: a second dzaudio stops here */
	sock = socket(AF_INET, SOCK_DGRAM | SOCK_CLOEXEC, 0);
	a.sin_port = htons((uint16_t)port);
	a.sin_addr.s_addr = htonl(INADDR_ANY);
	if (sock < 0 || bind(sock, (struct sockaddr *)&a, sizeof(a)) < 0) {
		fprintf(stderr, "dzaudio: UDP port %d: %s (runs already?)\n", port, strerror(errno));
		return 1;
	}
	if (load_libs() < 0)
		return 1;
	strm_open_all();
	strm_load();
	for (int n = 0; n < DZA_STREAMS; n++)	/* routes from before a restart */
		if (strm[n].mask)
			strm_route(n);
	gen++;

	set = F.new_settings();
	F.setnum(set, "synth.sample-rate", RATE);
	F.setint(set, "synth.audio-groups", N_MIDI);
	F.setint(set, "synth.audio-channels", N_MIDI);
	F.setint(set, "synth.effects-groups", 1);
	F.setint(set, "synth.reverb.active", fxon);
	F.setint(set, "synth.chorus.active", fxon);
	F.setint(set, "synth.cpu-cores", cores);
	F.setnum(set, "synth.gain", gain);
	F.setstr(set, "midi.driver", "alsa_seq");
	F.setstr(set, "midi.alsa_seq.id", "debaz-synth");
	synth = F.new_synth(set);
	if (!synth) {
		fprintf(stderr, "dzaudio: no synth\n");
		return 1;
	}
	sfid = F.sfload(synth, sf, 1);
	if (sfid < 0) {
		fprintf(stderr, "dzaudio: soundfont %s did not load\n", sf);
		return 1;
	}
	if (!F.new_mdriver(set, F.handle_midi, synth))
		fprintf(stderr, "dzaudio: no ALSA sequencer port (MIDI in off)\n");

	pthread_attr_init(&at);
	pthread_attr_setstacksize(&at, 256 * 1024);
	if (geteuid() == 0) {		/* real time as root, as fluidsynth -R */
		pthread_attr_setinheritsched(&at, PTHREAD_EXPLICIT_SCHED);
		pthread_attr_setschedpolicy(&at, SCHED_FIFO);
		pthread_attr_setschedparam(&at, &sp);
	}
	if (pthread_create(&th, &at, audio_thread, NULL) != 0 &&
	    pthread_create(&th, NULL, audio_thread, NULL) != 0) {
		fprintf(stderr, "dzaudio: no audio thread\n");
		return 1;
	}
	logf_("%d outputs (%d sinks), %s, routing %s, period %d, fx %s, OSC udp %d\n",
	      noutch, nsink, sf, pre, period, fxon ? "on" : "off", port);

	for (;;) {
		uint8_t b[DZ_OSC_MAX_PKT];
		ssize_t n;

		peerlen = sizeof(peer);
		n = recvfrom(sock, b, sizeof(b), 0, (struct sockaddr *)&peer, &peerlen);
		if (n > 0)
			dz_osc_walk(b, (size_t)n, on_msg, NULL);
	}
}

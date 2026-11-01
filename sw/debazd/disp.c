/*
 * disp.c - display buffers: show, blank, frame sequences, vsync thread.
 *
 * Model (per display d):
 *   frame store 0 = the slot or address shown (front)
 *   frame store 2 = slot DZ_SLOT_BLANK (black), set once at start
 *   blank = park on store 2, unblank = park on store 0: one register write,
 *   the front address stays as it was.
 *
 * A real-time thread waits for vsync (VTC status bit 13) and applies all
 * pending display changes right after it, so every change lands on a whole
 * frame. It sleeps until approx. 1.5 ms before the predicted vsync and polls
 * only in that window (approx. 10% of one core). Without vsync (displays not
 * started) changes apply at once and the frame tick runs from a timer.
 *
 * OSC (d = 0, 1 or a pattern):
 *   /disp/<d>/source s:what ...    "show" slot | "capture" | "seq" rate slots...
 *                                  (one address for what the display shows:
 *                                  the state model / cues)
 *   /disp/<d>/show i:slot          front = slot (next frame)
 *   /disp/<d>/home                 display 0 -> slot 0, display 1 -> slot 2
 *   /disp/<d>/capture              front = the frame the capture writes
 *   /disp/<d>/blank [i:0|1]        black / back; no argument = toggle
 *   /disp/<d>/seq i:slot ...       loop through slots, one step per `rate`
 *                                  frames; -1 = black. Strobe: seq 5 -1
 *   /disp/<d>/seq/rate i:frames    frames per step (default 1)
 *   /disp/<d>/seq/stop             back to the front slot (or black)
 *   /disp/<d>/crop i:x i:y         show the window of the slot that starts at
 *                                  pixel x, y (2026-10-28). Window = the video
 *                                  mode (both displays share it); a slot is
 *                                  1920 x 1080 at the fixed 7680-byte pitch, so
 *                                  at 720p x = 0..640, y = 0..360. x is made
 *                                  even (8-byte VDMA address alignment); the
 *                                  values are clamped. Also for show, capture
 *                                  and seq; lands on the next vsync, so it can
 *                                  move every frame (LFO: "/disp/0/crop $0 $1").
 *   /disp/<d>/crop                 -> /disp/<d>/crop i:x i:y
 *   /disp/<d>/crop/x i, /crop/y i  one coordinate alone (LFO target:
 *                                  "/disp/0/crop/x $i0")
 *   /disp/<d>/crop/off             = crop 0 0
 *   /disp/<d>                      -> /disp/<d> i:slot i:blanked i:seq
 *   /vsync                         -> /vsync i:frames f:hz f:jitter_us i:ok
 *   /video/mode                    -> /video/mode i:w i:h f:hz s:name
 *   /video/mode s:name             set the video mode of both displays (one
 *                                  pixel clock + VTC): stops hdmi2.elf (by pid)
 *                                  and starts it again with -r name, as
 *                                  plreload.sh but without a PL load. The main
 *                                  loop then sees the new geometry
 *                                  (/event/mode): movies stop, crops reset.
 *                                  Names = video_modes[] (hdmi2 -r).
 *   /video/modes                   -> /video/modes s:name ... (WxH[xNNHz], 60 Hz
 *                                  without a rate)
 */
#define _GNU_SOURCE
#include "debazd.h"
#include "dz_hw.h"
#include "dz_map.h"
#include "dz_vdma.h"

#include <dirent.h>
#include <pthread.h>
#include <sched.h>
#include <signal.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <sys/eventfd.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

#define STORE_FRONT	0
#define STORE_BLANK	2
#define SEQ_MAX		32

typedef struct {
	uint32_t front;			/* address in store 0              */
	int      blanked;
	int      want;			/* pending: new front address      */
	uint32_t want_addr;
	int      want_blank;		/* pending: -1 none, 0, 1          */
	int      seq[SEQ_MAX];		/* slots, -1 = black               */
	uint32_t off;			/* crop offset in bytes (applied)  */
	int      want_crop;		/* pending: new offset in want_off */
	uint32_t want_off;
	int      cx, cy;		/* crop origin, pixels (requested) */
	int      seqn, seqpos, rate, cnt, seqon, seqstop;
} dstate;

static dstate          D[DZ_DISPLAYS];
static pthread_mutex_t mu = PTHREAD_MUTEX_INITIALIZER;
static pthread_t       thr;
static volatile int    run, vs_ok;
static int             efd = -1, sim;
static double          period = 1.0 / 60.0, jit_max;
static unsigned long   frames;

static double now(void)
{
	struct timespec t;

	clock_gettime(CLOCK_MONOTONIC, &t);
	return t.tv_sec + t.tv_nsec / 1e9;
}

static void sleep_until(double t)
{
	struct timespec ts;

	ts.tv_sec = (time_t)t;
	ts.tv_nsec = (long)((t - (double)ts.tv_sec) * 1e9);
	clock_nanosleep(CLOCK_MONOTONIC, TIMER_ABSTIME, &ts, NULL);
}

/* ---- applying changes (mu held) ------------------------------------------- */
static void park_front_or_blank(int d)
{
	dz_disp_park(d, D[d].blanked ? STORE_BLANK : STORE_FRONT);
}

static void apply(int d)
{
	dstate *s = &D[d];

	if (s->want_crop) {
		s->off = s->want_off;
		s->want_crop = 0;
		if (!s->seqon && !s->want && s->front)
			dz_disp_set_store(d, STORE_FRONT, s->front + s->off);
	}
	if (s->seqstop) {
		s->seqon = s->seqstop = 0;
		dz_disp_set_store(d, STORE_FRONT, s->front + s->off);
		park_front_or_blank(d);
	}
	if (s->want) {
		s->front = s->want_addr;
		s->want = 0;
		if (!s->seqon) {
			dz_disp_set_store(d, STORE_FRONT, s->front + s->off);
			park_front_or_blank(d);
		}
	}
	if (s->want_blank >= 0) {
		s->blanked = s->want_blank;
		s->want_blank = -1;
		if (!s->seqon)
			park_front_or_blank(d);
	}
	if (s->seqon && s->seqn > 0 && ++s->cnt >= s->rate) {
		int slot = s->seq[s->seqpos];

		s->cnt = 0;
		s->seqpos = (s->seqpos + 1) % s->seqn;
		if (slot < 0) {
			dz_disp_park(d, STORE_BLANK);
		} else {
			dz_disp_set_store(d, STORE_FRONT, DZ_SLOT_ADDR(slot) + s->off);
			dz_disp_park(d, STORE_FRONT);
		}
	}
}

/* ---- vsync thread ----------------------------------------------------------- */
static void *vsync_main(void *arg)
{
	struct sched_param sp = { .sched_priority = 60 };
	double last = 0.0;
	int irq;

	(void)arg;
	if (pthread_setschedparam(pthread_self(), SCHED_FIFO, &sp) != 0)
		dzd_log("disp: no real-time priority (not root?) - vsync jitter will be high\n");
	irq = !sim && dz_vsync_irq();
	dzd_log("disp: vsync by %s\n", irq ? "interrupt (VTC UIO)" : "polling");
	while (run) {
		double t = now(), deadline;
		int got = 0;

		if (irq) {			/* sleep until the VTC interrupt */
			int w = dz_vsync_wait(100);

			if (w < 0) {
				irq = 0;
				dzd_log("disp: vsync interrupt failed - polling\n");
			}
			got = w > 0;
		} else {
			/* wake 0.4 ms early (was 1.5): the status bit stays latched,
			 * so a late wake costs precision, not a frame; the spin at
			 * real-time priority took CPU from movie decoding */
			if (vs_ok && last > 0.0 && last + period - 0.0004 > t)
				sleep_until(last + period - 0.0004);
			deadline = now() + (vs_ok ? 0.004 : 0.0);
			do {			/* poll window around the expected vsync */
				if (dz_vsync_latched()) {
					got = 1;
					break;
				}
			} while (now() < deadline);
		}
		if (!got) {
			if (vs_ok && now() - last > 0.1) {
				vs_ok = 0;
				dzd_log("disp: vsync lost\n");
			}
			if (!vs_ok && !irq)
				usleep(2000);	/* idle check, the bit stays latched */
			continue;
		}
		t = now();
		if (last > 0.0) {
			double dt = t - last;

			if (dt > 0.5 * period && dt < 1.5 * period) {
				double j = (dt - period) * 1e6;

				period += (dt - period) * 0.05;
				j = j < 0 ? -j : j;
				jit_max = j > jit_max ? j : jit_max * 0.999 + j * 0.001;
			}
		}
		if (!vs_ok)
			dzd_log("disp: vsync found\n");
		last = t;
		vs_ok = 1;
		pthread_mutex_lock(&mu);
		frames++;
		for (int d = 0; d < DZ_DISPLAYS; d++)
			apply(d);
		pthread_mutex_unlock(&mu);
		if (efd >= 0) {
			uint64_t one = 1;

			if (write(efd, &one, sizeof(one)) < 0) {
				/* eventfd full: the main loop is behind, drop the tick */
			}
		}
	}
	return NULL;
}

/* after a video mode change: the old crop may not fit the new window */
void disp_crop_reset(void)
{
	pthread_mutex_lock(&mu);
	for (int d = 0; d < DZ_DISPLAYS; d++) {
		D[d].cx = D[d].cy = 0;
		D[d].want_off = 0;
		D[d].want_crop = 1;
	}
	pthread_mutex_unlock(&mu);
}

/* no vsync: apply at once (main thread) */
static void kick(int d)
{
	if (vs_ok)
		return;
	pthread_mutex_lock(&mu);
	apply(d);
	pthread_mutex_unlock(&mu);
}

/* ---- init ------------------------------------------------------------------- */
static void blank_slot_fill(void)
{
	size_t len = DZ_SLOT_PITCH;		/* any mode up to 1080p */
	uint32_t *p = (uint32_t *)dz_slot(DZ_SLOT_BLANK, len, NULL);

	if (!p) {
		dzd_log("disp: blank slot %d not available\n", DZ_SLOT_BLANK);
		return;
	}
	for (size_t k = 0; k < len / 4; k++)
		p[k] = 0xFF000000u;
	__sync_synchronize();
}

int disp_init(int simulate)
{
	sim = simulate;
	blank_slot_fill();
	for (int d = 0; d < DZ_DISPLAYS; d++) {
		dstate *s = &D[d];
		uint32_t a = dz_disp_addr(d);	/* what it shows now */

		memset(s, 0, sizeof(*s));
		s->want_blank = -1;
		s->rate = 1;
		s->front = a;
		if (a) {	/* normalise: front in store 0, black in store 2 */
			dz_disp_set_store(d, STORE_FRONT, a);
			dz_disp_set_store(d, STORE_BLANK, DZ_SLOT_ADDR(DZ_SLOT_BLANK));
			dz_disp_park(d, STORE_FRONT);
		}
	}
	efd = eventfd(0, EFD_NONBLOCK | EFD_CLOEXEC);
	if (sim)
		return 0;
	/* map every block the thread touches now: the dz_map cache is not
	 * thread safe, so the thread must never be the first to map one */
	dz_regs(HW_HDMI_0_V_TC_0_BASE);
	dz_regs(DZ_DISP0_VDMA);
	dz_regs(DZ_DISP1_VDMA);
	run = 1;
	if (pthread_create(&thr, NULL, vsync_main, NULL) != 0) {
		run = 0;
		return -1;
	}
	return 0;
}

void disp_close(void)
{
	if (run) {
		run = 0;
		pthread_join(thr, NULL);
	}
	if (efd >= 0)
		close(efd);
	efd = -1;
}

int disp_frame_fd(void) { return efd; }
int disp_vsync_ok(void) { return vs_ok; }
double disp_frame_hz(void) { return vs_ok ? 1.0 / period : 0.0; }

/* ---- OSC ---------------------------------------------------------------------- */
static int slot_of(uint32_t a)
{
	if (a < DZ_SLOT_BASE || (a - DZ_SLOT_BASE) % DZ_SLOT_PITCH)
		return -1;
	a = (a - DZ_SLOT_BASE) / DZ_SLOT_PITCH;
	return a < DZ_SLOTS ? (int)a : -1;
}

/* the state model (state.c): what each display shows (key
 * /disp/<d>/source: a slot, the capture or a sequence), blank, crop */
void disp_state(state_cb cb, void *ctx)
{
	for (int d = 0; d < DZ_DISPLAYS; d++) {
		char p[40], key[40];
		int slot, bl, seqon, seqn, rate, cx, cy, capture, seq[SEQ_MAX];

		pthread_mutex_lock(&mu);
		uint32_t a = D[d].want ? D[d].want_addr : D[d].front;
		slot = slot_of(a);
		capture = a && a == dz_capture_addr() && slot < 0;
		bl = D[d].want_blank >= 0 ? D[d].want_blank : D[d].blanked;
		seqon = D[d].seqon && !D[d].seqstop;
		seqn = D[d].seqn;
		rate = D[d].rate;
		memcpy(seq, D[d].seq, sizeof(seq));
		cx = D[d].cx;
		cy = D[d].cy;
		pthread_mutex_unlock(&mu);
		snprintf(key, sizeof(key), "/disp/%d/source", d);
		if (seqon && seqn > 0) {
			dz_arg sa[SEQ_MAX + 2];
			int k2 = 0;

			sa[k2++] = (dz_arg){ .type = 's', .s = "seq" };
			sa[k2++] = (dz_arg){ .type = 'i', .i = rate > 0 ? rate : 1 };
			for (int k = 0; k < seqn && k2 < DZ_OSC_MAX_ARGS; k++)
				sa[k2++] = (dz_arg){ .type = 'i', .i = seq[k] };
			st_emit_args(cb, ctx, NULL, key, sa, k2);
		} else if (capture) {
			st_emit(cb, ctx, NULL, key, "s", "capture");
		} else if (slot >= 0) {
			st_emit(cb, ctx, NULL, key, "si", "show", slot);
		}
		snprintf(p, sizeof(p), "/disp/%d/blank", d);
		st_emit(cb, ctx, NULL, p, "i", bl ? 1 : 0);
		snprintf(p, sizeof(p), "/disp/%d/crop/x", d);
		st_emit(cb, ctx, NULL, p, "i", cx);
		snprintf(p, sizeof(p), "/disp/%d/crop/y", d);
		st_emit(cb, ctx, NULL, p, "i", cy);
	}
}

static void status(int d)
{
	char p[24];
	int slot, bl, sq;

	pthread_mutex_lock(&mu);
	slot = slot_of(D[d].want ? D[d].want_addr : D[d].front);
	bl = D[d].want_blank >= 0 ? D[d].want_blank : D[d].blanked;
	sq = D[d].seqon;
	pthread_mutex_unlock(&mu);
	snprintf(p, sizeof(p), "/disp/%d", d);
	dzd_reply(p, "iii", slot, bl, sq);
}

static int usable(int slot)
{
	return slot >= 0 && slot < DZ_SLOTS &&
	       dz_reserved(DZ_SLOT_ADDR(slot), DZ_SLOT_PITCH);
}

/* ---- video mode: hdmi2.elf -r (2026-11-01) ---- */

static const struct { const char *name; int w, h; float hz; } video_modes[] = {
	{ "640x480", 640, 480, 60 },	   { "800x600", 800, 600, 60 },
	{ "1024x768", 1024, 768, 60 },	   { "1280x720", 1280, 720, 60 },
	{ "1280x720x50Hz", 1280, 720, 50 }, { "1280x720x30Hz", 1280, 720, 30 },
	{ "1920x1080x25Hz", 1920, 1080, 25 }, { "1920x1080x30Hz", 1920, 1080, 30 },
	{ "1920x1080x60Hz", 1920, 1080, 60 },
};
#define N_VMODES ((int)(sizeof(video_modes) / sizeof(video_modes[0])))

/* the mode that matches the running geometry and frame rate best */
static const char *video_mode_name(int w, int h, double hz)
{
	const char *best = "";
	double bd = 1e9;

	for (int i = 0; i < N_VMODES; i++) {
		double dd = hz > 1 ? (video_modes[i].hz - hz) * (video_modes[i].hz - hz) : 0;
		if (video_modes[i].w == w && video_modes[i].h == h && dd < bd) {
			bd = dd;
			best = video_modes[i].name;
		}
	}
	return best;
}

/* stop every hdmi2.elf by pid (SIGTERM, 1 s, then SIGKILL) */
static void hdmi2_stop(void)
{
	pid_t pids[8];
	int n = 0;
	DIR *dp = opendir("/proc");
	struct dirent *e;

	if (!dp)
		return;
	while ((e = readdir(dp)) && n < 8) {
		char path[64], comm[32] = "";
		pid_t pid = (pid_t)atoi(e->d_name);
		FILE *fp;

		if (pid <= 0)
			continue;
		snprintf(path, sizeof(path), "/proc/%d/comm", (int)pid);
		fp = fopen(path, "r");
		if (!fp)
			continue;
		if (fgets(comm, sizeof(comm), fp) && !strncmp(comm, "hdmi2.elf", 9))
			pids[n++] = pid;
		fclose(fp);
	}
	closedir(dp);
	for (int i = 0; i < n; i++)
		kill(pids[i], SIGTERM);
	for (int t = 0; t < 100; t++) {
		int alive = 0;
		for (int i = 0; i < n; i++)
			if (kill(pids[i], 0) == 0)
				alive++;
		if (!alive)
			return;
		usleep(10000);
	}
	for (int i = 0; i < n; i++)
		kill(pids[i], SIGKILL);
}

/* hdmi2.elf -r name, detached (double fork, all inherited fds closed: the OSC
 * socket and the /tmp/debazd.lock flock must not live on in hdmi2).
 * DZ_HDMI2 = another program (host tests). */
static int hdmi2_start(const char *name)
{
	const char *prog = getenv("DZ_HDMI2");
	pid_t pid;

	if (!prog || !*prog)
		prog = "/home/ebaz/bin/hdmi2.elf";
	if (access(prog, X_OK))
		return -1;
	pid = fork();
	if (pid < 0)
		return -1;
	if (pid == 0) {
		if (fork() == 0) {
			setsid();
			for (int fd = 3; fd < 1024; fd++)
				close(fd);
			if (!freopen("/dev/null", "r", stdin) ||
			    !freopen("/tmp/hdmi2.log", "w", stdout))
				_exit(127);
			dup2(1, 2);
			execl(prog, prog, "-r", name, (char *)NULL);
			_exit(127);
		}
		_exit(0);
	}
	waitpid(pid, NULL, 0);
	return 0;
}

static int video_dispatch(const dz_msg *m)
{
	if (!strcmp(m->path, "/video/modes")) {
		dz_arg a[N_VMODES];

		for (int i = 0; i < N_VMODES; i++)
			a[i] = (dz_arg){ .type = 's', .s = video_modes[i].name };
		dzd_reply_args("/video/modes", a, N_VMODES);
		return 1;
	}
	if (strcmp(m->path, "/video/mode"))
		return 0;
	if (m->n < 1 || m->a[0].type != 's') {
		int w = dz_geom_w(), h = dz_geom_h();
		double hz = disp_frame_hz();
		dzd_reply("/video/mode", "iifs", w, h, (float)hz, video_mode_name(w, h, hz));
		return 1;
	}
	for (int i = 0; i < N_VMODES; i++) {
		if (strcmp(m->a[0].s, video_modes[i].name))
			continue;
		dzd_log("debazd: video mode -> %s (hdmi2 restart)\n", video_modes[i].name);
		audio_rx_hold();
		hdmi2_stop();
		if (hdmi2_start(video_modes[i].name)) {
			dzd_reply("/error", "ss", "/video/mode", "hdmi2.elf missing");
			return 1;
		}
		dzd_reply("/video/mode", "s", "starting");
		return 1;
	}
	dzd_reply("/error", "ss", "/video/mode", "unknown mode (see /video/modes)");
	return 1;
}

int disp_dispatch(const dz_msg *m)
{
	const dz_arg *a = m->a;
	int n = m->n, hits = 0;

	if (!strcmp(m->path, "/vsync")) {
		pthread_mutex_lock(&mu);
		dzd_reply("/vsync", "iffi", (int)frames, 1.0 / period, jit_max, vs_ok);
		pthread_mutex_unlock(&mu);
		return 1;
	}
	if (!strncmp(m->path, "/video/", 7))
		return video_dispatch(m);
	if (strncmp(m->path, "/disp/", 6))
		return 0;

	for (int d = 0; d < DZ_DISPLAYS; d++) {
		char base[16], p[40];
		const char *op = NULL;
		static const char *ops[] = { "source", "show", "home", "capture", "blank", "seq",
					     "seq/rate", "seq/stop", "crop", "crop/off", "crop/x", "crop/y",
					     NULL };

		snprintf(base, sizeof(base), "/disp/%d", d);
		if (dz_osc_match(m->path, base)) {
			op = "";
		} else {
			for (int k = 0; ops[k]; k++) {
				snprintf(p, sizeof(p), "%s/%s", base, ops[k]);
				if (dz_osc_match(m->path, p)) {
					op = ops[k];
					break;
				}
			}
		}
		if (!op)
			continue;
		hits++;
		if (!*op) {
			status(d);
			continue;
		}
		if (!strcmp(op, "source") && n >= 1 && a[0].type == 's') {
			/* the state model: "show" slot | "capture" | "seq" rate slots... */
			dz_msg mm = { .n = 0 };

			snprintf(p, sizeof(p), "%s/%s", base, !strcmp(a[0].s, "seq") ? "seq/rate" : a[0].s);
			mm.path = p;
			if (!strcmp(a[0].s, "show") && n >= 2) {
				mm.a[0] = a[1];
				mm.n = 1;
			} else if (!strcmp(a[0].s, "seq") && n >= 3) {
				mm.a[0] = a[1];			/* rate first, then the slots */
				mm.n = 1;
				dzd_handle_internal(&mm);
				snprintf(p, sizeof(p), "%s/seq", base);
				mm.n = 0;
				for (int k = 2; k < n && mm.n < DZ_OSC_MAX_ARGS; k++)
					mm.a[mm.n++] = a[k];
			} else if (strcmp(a[0].s, "capture")) {
				dzd_reply("/error", "ss", "source: show <slot> | capture | seq <rate> <slots...>", m->path);
				continue;
			}
			dzd_handle_internal(&mm);
			continue;
		}
		if (!strncmp(op, "crop", 4) && strcmp(op, "crop/off") && n == 0) {	/* query */
			snprintf(p, sizeof(p), "%s/crop", base);
			pthread_mutex_lock(&mu);
			dzd_reply(p, "ii", D[d].cx, D[d].cy);
			pthread_mutex_unlock(&mu);
			continue;
		}
		if (!dz_disp_addr(d) && !sim) {
			dzd_reply("/error", "ss", "display not running (run hdmi2 first)", base);
			continue;
		}

		pthread_mutex_lock(&mu);
		if (!strcmp(op, "show") || !strcmp(op, "home")) {
			int slot = !strcmp(op, "home") ? (d == 0 ? DZ_DISP0_HOME : DZ_DISP1_HOME)
						       : (n >= 1 ? a[0].i : -1);

			if (!usable(slot)) {
				pthread_mutex_unlock(&mu);
				dzd_reply("/error", "ss", "slot outside reserved memory or bad", base);
				continue;
			}
			D[d].want_addr = DZ_SLOT_ADDR(slot);
			D[d].want = 1;
		} else if (!strcmp(op, "capture")) {
			uint32_t c = dz_capture_addr();

			if (c) {
				D[d].want_addr = c;
				D[d].want = 1;
			}
		} else if (!strcmp(op, "blank")) {
			int cur = D[d].want_blank >= 0 ? D[d].want_blank : D[d].blanked;

			D[d].want_blank = n >= 1 ? (a[0].i != 0) : !cur;
		} else if (!strcmp(op, "seq")) {
			int k = 0;

			for (int j = 0; j < n && k < SEQ_MAX; j++)
				if (a[j].i < 0 || usable(a[j].i))
					D[d].seq[k++] = a[j].i < 0 ? -1 : a[j].i;
			if (k) {
				D[d].seqn = k;
				D[d].seqpos = 0;
				D[d].cnt = D[d].rate;	/* first step on the next frame */
				D[d].seqon = 1;
				D[d].seqstop = 0;
			}
		} else if (!strcmp(op, "seq/rate")) {
			D[d].rate = n >= 1 && a[0].i > 0 ? a[0].i : 1;
		} else if (!strcmp(op, "seq/stop")) {
			if (D[d].seqon)
				D[d].seqstop = 1;
		} else if (!strncmp(op, "crop", 4)) {
			/* window = the mode, inside the source: the capture's
			 * real size (e.g. 1600 x 1200, which runs into the next
			 * slot) when it is shown, else a 1920 x 1080 slot at
			 * the running line pitch; x even: 8-byte VDMA alignment */
			size_t st = dz_geom_stride();
			int sw = (int)(st / DZ_BPP), sh = (int)(DZ_SLOT_PITCH / st);
			dz_vdma_regs cr;
			int maxx, maxy, x = 0, y = 0;

			if (sh > 1080)
				sh = 1080;
			if (D[d].front && D[d].front == dz_capture_addr() &&
			    dz_capture_regs(&cr) == 0 && cr.vsize) {
				sw = (int)(cr.hsize & 0xFFFF) / DZ_BPP;
				sh = (int)(cr.vsize & 0x1FFF);
			}
			maxx = sw - dz_geom_w();
			maxy = sh - dz_geom_h();
			maxx = maxx < 0 ? 0 : maxx;
			maxy = maxy < 0 ? 0 : maxy;

			if (!strcmp(op, "crop") && n >= 2) {
				x = a[0].type == 'f' ? (int)a[0].f : a[0].i;
				y = a[1].type == 'f' ? (int)a[1].f : a[1].i;
			} else if (!strcmp(op, "crop/x") || !strcmp(op, "crop/y")) {
				int v = a[0].type == 'f' ? (int)a[0].f : a[0].i;

				x = op[5] == 'x' ? v : D[d].cx;
				y = op[5] == 'y' ? v : D[d].cy;
			}
			x = x < 0 ? 0 : x > maxx ? maxx : x;
			y = y < 0 ? 0 : y > maxy ? maxy : y;
			x &= ~1;
			D[d].cx = x;
			D[d].cy = y;
			D[d].want_off = (uint32_t)((size_t)y * st + (size_t)x * DZ_BPP);
			D[d].want_crop = 1;
		}
		pthread_mutex_unlock(&mu);
		kick(d);
		if (!strncmp(op, "crop", 4)) {
			snprintf(p, sizeof(p), "%s/crop", base);	/* no log: may run per frame */
			dzd_reply(p, "ii", D[d].cx, D[d].cy);
			continue;
		}
		dzd_log("disp: %s %s\n", base, op);
		status(d);
	}
	return hits;
}

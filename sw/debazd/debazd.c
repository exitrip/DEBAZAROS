/*
 * debazd - DEBAZAROS hardware daemon: the one owner of the PL control
 * registers and the DDR frame slots, reachable over OSC/UDP.
 *
 *   debazd [-p port] [-v] [-n] [-l] [-i ms]
 *     -p PORT  UDP port (default 9000)
 *     -v       log every operation
 *     -n       simulate: RAM instead of hardware (host tests)
 *     -l       print the field table and exit
 *     -i MS    monitor interval for capture / user I/O events (default 20)
 *
 * It does NOT initialise the displays: hdmi2.elf (or later a bring-up
 * library) sets the video mode and starts the VDMAs first.
 *
 * OSC interface (replies go to the sender's address and port):
 *   /ping                         -> /pong
 *   /info                         -> /info s:variant i:fields i:slots i:usable
 *                                    s:hostname s:mac  (usable = slots inside
 *                                    reserved memory; dzctl -s broadcasts it)
 *   /list [s:prefix]              -> /entry s:path s:help ... /entry/end i:count
 *   /fields [s:prefix]            -> /field s:path i:lo i:width s:unit i:ro
 *                                    s:help ... /field/end i:count  (for UIs)
 *   /files s:img|movies|audio     -> /file s:name ... /file/end i:count
 *   <field> value...              set a field (see sw/lib/dz_fields.h rules)
 *   <field>                       (no value) -> /value s:path i:raw f:normalized
 *   /get s:path                   same as <field> without value
 *   /disp/<d>/show i:slot         display d shows DDR slot (0..5)
 *   /disp/<d>/home                display 0 -> slot 0 (fb0), display 1 -> slot 2
 *   /disp/<d>/capture             show the frame the capture VDMA writes now
 *   /disp/<d>                     -> /disp/<d> i:slot  (-1 = not a slot / off)
 *   /capture/status               -> /capture/status i:plocked i:alocked
 *                                    i:frames i:overflow s:dmasr
 *   /io/press/<bit> s:"template"  on a press of user I/O bit 0..7 (1 -> 0,
 *   /io/release/<bit> s:"template" active low) send that message to debazd
 *                                 itself (same syntax as LFO targets, $k =
 *                                 LFO values); no argument = remove
 *   /subscribe [i:port]           events go to the sender (or that port)
 *   /unsubscribe [i:port]
 *   /draw/... /img/... /movie/... /surface/...   see sw/lib/dz_draw.h
 *   /surface/<s>/peek i:x i:y     -> /pixel i:s i:x i:y i:r i:g i:b
 *   /fx/hue /fx/matrix /fx/map /fx/key/...   colour matrix and key (fx.c)
 *   /io/pin i:line s:name, /io/pins     user I/O line functions (io.c)
 *   /audio/fs, /audio/fs/auto i, /capture/replug [f:s]   (audio.c)
 * Events to subscribers:
 *   /event/io i:raw               user I/O byte changed (active low)
 *   /event/hpd i:hpd0 i:hpd1
 *   /event/capture i:plocked i:frames   capture lock or frame flow changed
 * Wildcards ? * [] {} work in addresses, e.g. /mixer/[0-8]/mode 35.
 */
#define _GNU_SOURCE
#include "debazd.h"
#include "dz_draw.h"
#include "dz_fields.h"
#include "dz_hw.h"
#include "dz_sprite.h"
#include "dz_map.h"
#include "dz_osc.h"
#include "dz_vdma.h"

#include <arpa/inet.h>
#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <netinet/in.h>
#include <poll.h>
#include <pthread.h>
#include <signal.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/file.h>
#include <sys/socket.h>
#include <time.h>
#include <unistd.h>

#ifndef DEBAZD_LOCK
#define DEBAZD_LOCK	"/tmp/debazd.lock"
#endif
#define MAX_SUBS	16

static volatile sig_atomic_t stop;
static int verbose;
static int sock = -1;

typedef struct {
	struct sockaddr_in to;
	int                used;
} sub_t;
static sub_t subs[MAX_SUBS];

/* the sender of the message being handled; internal = sent by the daemon */
static struct sockaddr_in cur_from;
static int cur_internal;

static void on_signal(int sig) { (void)sig; stop = 1; }

/* A read of the VTC while hdmi2 switches the pixel clock (menu mode change)
 * gave a bus error (external abort at 0x43C2_0004, 2026-10-28) and SIGBUS
 * killed debazd. Such a fault lasts only for the clock switch. On ARM the
 * faulting load runs again when the handler returns: wait 1 ms and return.
 * Faults for 2 s without a pause of 100 ms = a block that is really missing:
 * default action (core dump). Async-signal-safe calls only. */
static void on_sigbus(int sig, siginfo_t *si, void *uc)
{
	static long first, last;
	struct timespec ts;
	long t;

	(void)si; (void)uc;
	clock_gettime(CLOCK_MONOTONIC, &ts);
	t = ts.tv_sec * 1000L + ts.tv_nsec / 1000000L;
	if (t - last > 100) {
		static const char msg[] = "debazd: bus error (pixel clock switch?), retrying\n";
		first = t;
		if (write(2, msg, sizeof(msg) - 1) < 0) {}
	}
	last = t;
	if (t - first > 2000) {
		static const char msg[] = "debazd: bus errors for 2 s, giving up\n";
		if (write(2, msg, sizeof(msg) - 1) < 0) {}
		signal(sig, SIG_DFL);
		return;					/* the load faults again: dies */
	}
	nanosleep(&(struct timespec){ 0, 1000000 }, NULL);
}

/* ---- sending ---------------------------------------------------------------- */
static void send_to(const struct sockaddr_in *to, const char *path, const char *tags, ...)
{
	uint8_t buf[DZ_OSC_MAX_PKT];
	va_list ap;
	size_t n;

	va_start(ap, tags);
	n = dz_osc_vbuild(buf, sizeof(buf), path, tags, ap);
	va_end(ap);
	if (n && sock >= 0)
		sendto(sock, buf, n, 0, (const struct sockaddr *)to, sizeof(*to));
}

void dzd_reply(const char *path, const char *tags, ...)
{
	uint8_t buf[DZ_OSC_MAX_PKT];
	va_list ap;
	size_t n;

	if (cur_internal || sock < 0)
		return;
	va_start(ap, tags);
	n = dz_osc_vbuild(buf, sizeof(buf), path, tags, ap);
	va_end(ap);
	if (n)
		sendto(sock, buf, n, 0, (const struct sockaddr *)&cur_from, sizeof(cur_from));
}

void dzd_log(const char *fmt, ...)
{
	va_list ap;

	if (!verbose)
		return;
	va_start(ap, fmt);
	vfprintf(stderr, fmt, ap);
	va_end(ap);
}

#define reply dzd_reply

static void event(const char *path, const char *tags, ...)
{
	uint8_t buf[512];
	va_list ap;
	size_t n;

	va_start(ap, tags);
	n = dz_osc_vbuild(buf, sizeof(buf), path, tags, ap);
	va_end(ap);
	if (!n)
		return;
	for (int i = 0; i < MAX_SUBS; i++)
		if (subs[i].used)
			sendto(sock, buf, n, 0, (const struct sockaddr *)&subs[i].to,
			       sizeof(subs[i].to));
}

static int cap_frames = -1;	/* frame flow state, updated by the monitor */
static int sim_mode;
#define IO_BITS		8
#define TPL_MAX		256
static char bind_press[IO_BITS][TPL_MAX], bind_release[IO_BITS][TPL_MAX];
static int io_word(uint32_t *v);
static void handle(dz_msg *m, void *ctx);

/* Current state to one new subscriber, so it does not wait for a change. */
static void snapshot(const struct sockaddr_in *to)
{
	uint32_t io;

	if (io_word(&io) < 0)
		return;
	send_to(to, "/event/io", "i", (int)(io & 0xFF));
	send_to(to, "/event/hpd", "ii", (int)((io >> 8) & 1), (int)((io >> 9) & 1));
	send_to(to, "/event/capture", "ii", (int)((io >> 10) & 1), cap_frames);
}

static void subscribe(int port, int on)
{
	struct sockaddr_in to = cur_from;
	int freei = -1;

	if (port > 0)
		to.sin_port = htons((uint16_t)port);
	for (int i = 0; i < MAX_SUBS; i++) {
		if (subs[i].used && subs[i].to.sin_addr.s_addr == to.sin_addr.s_addr &&
		    subs[i].to.sin_port == to.sin_port) {
			if (!on)
				subs[i].used = 0;
			return;
		}
		if (!subs[i].used && freei < 0)
			freei = i;
	}
	if (on && freei >= 0) {
		subs[freei].to = to;
		subs[freei].used = 1;
		snapshot(&to);
	}
}

/* ---- handlers -------------------------------------------------------------- */
static void send_value(const dz_field *f)
{
	uint32_t raw = 0;

	if (dz_field_read(f, &raw) < 0) {
		reply("/error", "ss", "read failed", f->path);
		return;
	}
	reply("/value", "sif", f->path, (int)raw, (double)dz_field_to_float(f, raw));
}

static int do_fields(const dz_msg *m)
{
	int hits = 0;

	for (int i = 0; i < dz_fields_count(); i++) {
		const dz_field *f = dz_field_at(i);
		uint32_t raw = 0;
		int rc;

		if (!dz_osc_match(m->path, f->path))
			continue;
		hits++;
		if (m->n == 0) {
			send_value(f);
			continue;
		}
		rc = dz_field_set(f, m->a, m->n, &raw);
		if (rc == -2)
			reply("/error", "ss", "read only", f->path);
		else if (rc < 0)
			reply("/error", "ss", "bad value", f->path);
		else
			dzd_log("debazd: %-28s <- 0x%08X (%u)\n", f->path, raw, raw);
	}
	return hits;
}

static int io_word(uint32_t *v)
{
	volatile uint32_t *r = dz_regs(DZ_IO_GPIO);

	if (!r)
		return -1;
	*v = r[0];
	return 0;
}

static void do_capture_status(void)
{
	dz_vdma_regs r;
	uint32_t io = 0;
	char sr[96];

	if (dz_capture_regs(&r) < 0 || io_word(&io) < 0) {
		reply("/error", "s", "capture not available");
		return;
	}
	reply("/capture/status", "iiiis", (int)((io >> 10) & 1), (int)((io >> 11) & 1),
	      cap_frames, (int)((io >> 12) & 1), dz_vdma_sr_text(r.sr, sr, sizeof(sr)));
}

static void do_list(const dz_msg *m)
{
	const char *pre = (m->n >= 1 && m->a[0].type == 's') ? m->a[0].s : "";
	int count = 0;

	for (int i = 0; i < dz_fields_count(); i++) {
		const dz_field *f = dz_field_at(i);

		if (strncmp(f->path, pre, strlen(pre)))
			continue;
		reply("/entry", "ss", f->path, f->help);
		count++;
	}
	reply("/entry/end", "i", count);
}

static void handle(dz_msg *m, void *ctx)
{
	int hits = 0;

	(void)ctx;
	if (!strcmp(m->path, "/ping")) {
		reply("/pong", "");
		return;
	}
	if (!strcmp(m->path, "/info")) {
		char host[64] = "?", mac[32] = "?";
		FILE *fp = fopen("/sys/class/net/eth0/address", "r");

		gethostname(host, sizeof(host) - 1);
		if (fp) {
			if (fgets(mac, sizeof(mac), fp))
				mac[strcspn(mac, "\n")] = 0;
			fclose(fp);
		}
		reply("/info", "siiiss", HW_VARIANT, dz_fields_count(), DZ_SLOTS,
		      dz_slots_usable(), host, mac);
		return;
	}
	if (!strcmp(m->path, "/fields")) {
		static const char *units[] = { "raw", "bool", "hz", "rgb" };
		const char *pre = (m->n >= 1 && m->a[0].type == 's') ? m->a[0].s : "";
		int count = 0;

		for (int i = 0; i < dz_fields_count(); i++) {
			const dz_field *f = dz_field_at(i);

			if (strncmp(f->path, pre, strlen(pre)))
				continue;
			reply("/field", "siisis", f->path, f->lo, f->width,
			      units[f->unit & 3], (f->flags & DZ_F_RO) ? 1 : 0, f->help);
			count++;
		}
		reply("/field/end", "i", count);
		return;
	}
	if (!strcmp(m->path, "/files")) {
		const char *which = (m->n >= 1 && m->a[0].type == 's') ? m->a[0].s : "";
		const char *dir = !strcmp(which, "movies") ? DZ_MOVIE_DIR :
				  !strcmp(which, "img") ? DZ_IMG_DIR :
				  !strcmp(which, "audio") ? DZ_AUDIO_DIR : NULL;
		DIR *d = dir ? opendir(dir) : NULL;
		struct dirent *e;
		int count = 0;

		if (!dir) {
			reply("/error", "ss", "/files needs img, movies or audio", m->path);
			return;
		}
		while (d && (e = readdir(d)) != NULL) {
			if (e->d_name[0] == '.')
				continue;
			reply("/file", "s", e->d_name);
			count++;
		}
		if (d)
			closedir(d);
		reply("/file/end", "i", count);
		return;
	}
	if (!strcmp(m->path, "/list")) {
		do_list(m);
		return;
	}
	if (!strcmp(m->path, "/get")) {
		const dz_field *f = (m->n >= 1 && m->a[0].type == 's')
				    ? dz_field_find(m->a[0].s) : NULL;

		if (f)
			send_value(f);
		else
			reply("/error", "s", "/get needs a field path");
		return;
	}
	if (!strcmp(m->path, "/capture/status")) {
		do_capture_status();
		return;
	}
	if (!strcmp(m->path, "/subscribe") || !strcmp(m->path, "/unsubscribe")) {
		reply("/ok", "s", m->path);
		subscribe(m->n >= 1 && m->a[0].type == 'i' ? m->a[0].i : 0,
			  m->path[1] == 's');
		return;
	}

	/* /surface/<s>/peek x y -> /pixel s x y r g b (needs a reply) */
	{
		int sl, n0 = 0;

		if (sscanf(m->path, "/surface/%d/peek%n", &sl, &n0) == 1 &&
		    !m->path[n0] && m->n >= 2) {
			dz_color c;

			if (dz_draw_peek(sl, m->a[0].i, m->a[1].i, &c) == 0)
				reply("/pixel", "iiiiii", sl, m->a[0].i, m->a[1].i, c.r, c.g, c.b);
			else
				reply("/error", "ss", "bad surface or position", m->path);
			return;
		}
	}
	if (lfo_dispatch(m) || disp_dispatch(m) || fx_dispatch(m) || io_dispatch(m) ||
	    audio_dispatch(m) || sound_dispatch(m) || pwm_dispatch(m))
		return;
	{	/* /io/press/<bit>, /io/release/<bit>, /io/simulate (sim only) */
		int bit, n0 = 0, press = 0;

		if ((sscanf(m->path, "/io/press/%d%n", &bit, &n0) == 1 && (press = 1)) ||
		    sscanf(m->path, "/io/release/%d%n", &bit, &n0) == 1) {
			if (m->path[n0] || bit < 0 || bit >= IO_BITS) {
				reply("/error", "ss", "bit must be 0..7", m->path);
				return;
			}
			snprintf(press ? bind_press[bit] : bind_release[bit], TPL_MAX, "%s",
				 m->n >= 1 && m->a[0].type == 's' ? m->a[0].s : "");
			reply("/ok", "s", m->path);
			return;
		}
		if (!strcmp(m->path, "/io/simulate")) {
			volatile uint32_t *r = dz_regs(DZ_IO_GPIO);

			if (!sim_mode || !r || m->n < 1)
				reply("/error", "ss", "only with debazd -n", m->path);
			else
				r[0] = (r[0] & ~0xFFu) | ((uint32_t)m->a[0].i & 0xFFu);
			return;
		}
	}
	{	/* /sprite/<id> query -> /sprite/<id> i:w i:h */
		int id, n0 = 0, w = 0, h = 0;

		if (sscanf(m->path, "/sprite/%d%n", &id, &n0) == 1 && !m->path[n0]) {
			if (dz_sprite_size(id, &w, &h) == 0)
				reply(m->path, "ii", w, h);
			else
				reply("/error", "ss", "no such sprite", m->path);
			return;
		}
	}
	if (dz_sprite_dispatch(m, verbose)) {
		if (dz_draw_take_fails())
			reply("/error", "ss", "sprite operation failed", m->path);
		return;
	}
	hits += do_fields(m);
	if (!hits) {
		hits += dz_draw_dispatch(m, verbose);
		if (hits && dz_draw_take_fails())
			reply("/error", "ss", "draw failed (slot outside reserved memory, "
			      "or file missing)", m->path);
	}
	if (!hits) {
		reply("/error", "ss", "no such address", m->path);
		dzd_log("debazd: no match %s\n", m->path);
	}
}

void dzd_handle_internal(dz_msg *m)
{
	int saved = cur_internal;

	cur_internal = 1;
	handle(m, NULL);
	cur_internal = saved;
}

/* ---- monitor --------------------------------------------------------------- */
static void video_watch(void);
static void capture_watch(void);
static long now_ms(void);

static void monitor(void)
{
	static uint32_t last_io = 0xFFFFFFFFu;
	static int last_lock = -1, last_frames = -1;
	static int idle_polls;
	uint32_t io;
	int lock, seen;

	if (io_word(&io) < 0)
		return;
	if ((io & 0xFF) != (last_io & 0xFF) || last_io == 0xFFFFFFFFu)
		event("/event/io", "i", (int)(io & 0xFF));
	if (last_io != 0xFFFFFFFFu)	/* bound actions: active low, 1 -> 0 = press */
		for (int b = 0; b < IO_BITS; b++) {
			uint32_t was = (last_io >> b) & 1, now = (io >> b) & 1;

			if (was && !now && bind_press[b][0])
				dzd_send_template(bind_press[b]);
			else if (!was && now && bind_release[b][0])
				dzd_send_template(bind_release[b]);
		}
	if (((io >> 8) & 3) != ((last_io >> 8) & 3) || last_io == 0xFFFFFFFFu)
		event("/event/hpd", "ii", (int)((io >> 8) & 1), (int)((io >> 9) & 1));
	last_io = io;

	/* frames: alive if a frame completed within the last ~5 polls (100 ms) */
	seen = dz_capture_frames_seen();
	idle_polls = seen ? 0 : idle_polls + 1;
	cap_frames = idle_polls < 5;
	lock = (int)((io >> 10) & 1);
	if (lock != last_lock || cap_frames != last_frames) {
		event("/event/capture", "ii", lock, cap_frames);
		dzd_log("debazd: capture plocked=%d frames=%d\n", lock, cap_frames);
	}
	last_lock = lock;
	last_frames = cap_frames;
	video_watch();
	capture_watch();
	/* video mode changed (hdmi2 menu or a restart with -r): surfaces start
	 * again at the new size on their next use; movies stop (they write
	 * with the old line pitch) */
	if (dz_geom_refresh()) {
		dzd_log("debazd: video mode now %dx%d, stride %u: movies stopped\n",
			dz_geom_w(), dz_geom_h(), (unsigned)dz_geom_stride());
		for (int s = 0; s < DZ_SLOTS; s++)
			dz_draw_movie_stop(s);
		disp_crop_reset();
		event("/event/mode", "iii", dz_geom_w(), dz_geom_h(), (int)dz_geom_stride());
	}
}

/* Video footprints (gateware p148, 2026-10-28): the event block latches every
 * lock change of both v_axi4s_vid_out and the dynclk MMCM, and every vid_out
 * underflow (a starved output stream: the output then blanks until it locks
 * again). Logged with the 100 MHz timestamp; /event/video to subscribers.
 * Older bitstreams have no bits 13:9 (their enables do not stick): silent. */
#define EV_VIDEO	0x3E00u
static void video_watch(void)
{
	volatile uint32_t *e = dz_regs(HW_HDMI_AUDIO_REGS_0_BASE + 0x1000);
	static int armed;
	uint32_t pend, lvl, uf;

	if (!e)
		return;
	if (!armed) {
		e[0x10 / 4] |= EV_VIDEO;	/* rising and falling edges */
		e[0x14 / 4] |= EV_VIDEO;
		e[0x08 / 4] = EV_VIDEO;		/* clear old latches */
		armed = 1;
		if (!(e[0x10 / 4] & EV_VIDEO))
			return;
		dzd_log("debazd: video watch on (vid_out lock/underflow, dynclk lock)\n");
	}
	pend = e[0x08 / 4] & EV_VIDEO;
	if (!pend)
		return;
	e[0x08 / 4] = pend;			/* W1C */
	lvl = e[0x18 / 4];
	uf = e[0x3C / 4];
	dzd_log("debazd: VIDEO t=%u%s%s%s%s%s | locked0=%u locked1=%u dynclk=%u | underflows0=%u underflows1=%u\n",
		(unsigned)e[0x38 / 4],
		(pend & 0x0200) ? " HDMI_0-lock" : "", (pend & 0x0400) ? " HDMI_1-lock" : "",
		(pend & 0x0800) ? " HDMI_0-UNDERFLOW" : "", (pend & 0x1000) ? " HDMI_1-UNDERFLOW" : "",
		(pend & 0x2000) ? " DYNCLK-lock" : "",
		(unsigned)((lvl >> 9) & 1), (unsigned)((lvl >> 10) & 1), (unsigned)((lvl >> 13) & 1),
		(unsigned)(uf & 0xFFFF), (unsigned)(uf >> 16));
	event("/event/video", "iiii", (int)pend, (int)lvl, (int)(uf & 0xFFFF), (int)(uf >> 16));
}

/* Capture size follows the INPUT (2026-10-28), not the output mode: the
 * HDMI_2 input size measured by hdmi_rx (RX_SIZE, build p148+). When a
 * valid size is stable for 3 polls and differs from the S2MM setup, or the
 * channel stopped (halted, or no completed frame for ~1 s), arm it again with
 * the safe sequence (dz_capture_arm: soft reset first). An arm latches IntErr
 * once (the partial first frame) while the channel runs on: the latches are
 * cleared on the next poll, they are not a reason to arm again. At most one
 * try per 2 s. The soft reset waits for the transfers in progress: at
 * 1080p60 (HP ports starved) it took longer than the 100 ms of
 * dz_capture_arm (2026-10-28) and completed later. So a reset that is not
 * done yet only pauses the watch; it continues when the reset bit clears.
 * After 10 s it is a wedged HP1 AFI (power cycle), reported once.
 * /capture/auto 0 = off. */
int capture_auto = 1;
static void capture_watch(void)
{
	static int last_w, last_h, stable, pending, wedged, clear_next, idle;
	static long last_try;
	volatile uint32_t *a = dz_regs(HW_HDMI_AUDIO_REGS_0_BASE);
	dz_vdma_regs r;
	uint32_t sh, sv, addr;
	int w, h, sick, rc;

	if (!capture_auto || !a || dz_map_simulating() || dz_capture_regs(&r) < 0)
		return;
	if (pending) {					/* soft reset not done yet */
		if (r.cr & 0x04) {
			if (!wedged && now_ms() - last_try > 10000) {
				wedged = 1;
				dzd_log("debazd: capture soft reset stuck for 10 s - HP1 AFI wedged, power cycle\n");
				event("/event/capture/armed", "iii", 0, 0, -2);
			}
			return;
		}
		dzd_log("debazd: capture soft reset done after %ld ms\n", now_ms() - last_try);
		pending = wedged = 0;
		last_try = 0;				/* arm again on this poll */
	}
	if (clear_next) {				/* the arm's own IntErr etc. */
		dz_wr(DZ_CAPTURE_VDMA, 0x34, 0x0000F990);	/* S2MM_SR, W1C */
		clear_next = 0;
	}
	idle = cap_frames ? 0 : idle + 1;		/* polls without a frame */
	sh = a[0x24 / 4];
	sv = a[0x28 / 4];
	w = (int)(sh >> 16);
	h = (int)(sv & 0xFFF) - (int)(sv >> 24);	/* minus the short "lines" */
	if (w < 64 || w > 1920 || h < 64 || h > 1200 || (sh & 0xFFFF) != (uint32_t)w) {
		stable = 0;				/* no input, or ragged */
		return;
	}
	stable = (w == last_w && h == last_h) ? stable + 1 : 0;
	last_w = w;
	last_h = h;
	sick = (r.sr & 0x01) || idle > 50;		/* halted, or ~1 s no frame */
	if (stable < 3 || (!sick && r.hsize == (uint32_t)w * DZ_BPP && r.vsize == (uint32_t)h))
		return;
	if (now_ms() - last_try < 2000)
		return;
	last_try = now_ms();
	addr = r.addr[0] ? r.addr[0] : DZ_SLOT_ADDR(DZ_SLOT_CAPTURE);
	rc = dz_capture_arm(w, h, dz_geom_stride(), addr);
	dzd_log("debazd: capture armed for the %dx%d input, stride %u -> 0x%08X%s\n", w, h,
		(unsigned)dz_geom_stride(), (unsigned)addr,
		rc == 0 ? "" : rc == -2 ? ": soft reset not done in 100 ms, waiting" : ": refused");
	pending = (rc == -2);
	clear_next = (rc == 0);
	idle = 0;
	event("/event/capture/armed", "iii", w, h, rc);
}

/* ---- main ------------------------------------------------------------------ */
static void print_fields(void)
{
	printf("%-30s %-14s %-8s %s\n", "ADDRESS", "REGISTER", "BITS", "MEANING");
	for (int i = 0; i < dz_fields_count(); i++) {
		const dz_field *f = dz_field_at(i);
		char bits[16], reg[24];

		if (f->width == 1)
			snprintf(bits, sizeof(bits), "[%u]", f->lo);
		else
			snprintf(bits, sizeof(bits), "[%u:%u]", f->lo + f->width - 1, f->lo);
		snprintf(reg, sizeof(reg), "%08X+%X", (unsigned)f->base, (unsigned)f->off);
		printf("%-30s %-14s %-8s %s%s\n", f->path, reg, bits, f->help,
		       (f->flags & DZ_F_RO) ? " (read only)" : "");
	}
}

static long now_ms(void)
{
	struct timespec ts;

	clock_gettime(CLOCK_MONOTONIC, &ts);
	return ts.tv_sec * 1000L + ts.tv_nsec / 1000000L;
}

int main(int argc, char **argv)
{
	int port = 9000, sim = 0, interval = 20, lockfd;
	struct sockaddr_in me;
	struct sigaction sa;
	long next;
	int opt;

	while ((opt = getopt(argc, argv, "p:vnli:")) != -1) {
		switch (opt) {
		case 'p': port = atoi(optarg); break;
		case 'v': verbose = 1; break;
		case 'n': sim = 1; break;
		case 'i': interval = atoi(optarg) > 10 ? atoi(optarg) : 10; break;
		case 'l': dz_fields_build(); print_fields(); return 0;
		default:
			fprintf(stderr, "usage: %s [-p port] [-v] [-n] [-l] [-i ms]\n", argv[0]);
			return 2;
		}
	}

	lockfd = open(DEBAZD_LOCK, O_RDWR | O_CREAT, 0644);
	if (lockfd < 0 || flock(lockfd, LOCK_EX | LOCK_NB) < 0) {
		fprintf(stderr, "debazd: another debazd is running (%s)\n", DEBAZD_LOCK);
		return 1;
	}

	dz_map_simulate(sim);
	sim_mode = sim;
	dz_fields_build();

	sock = socket(AF_INET, SOCK_DGRAM, 0);
	if (sock < 0) {
		perror("debazd: socket");
		return 1;
	}
	setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, &(int){ 1 }, sizeof(int));
	memset(&me, 0, sizeof(me));
	me.sin_family = AF_INET;
	me.sin_addr.s_addr = htonl(INADDR_ANY);
	me.sin_port = htons((uint16_t)port);
	if (bind(sock, (struct sockaddr *)&me, sizeof(me)) < 0) {
		fprintf(stderr, "debazd: bind udp/%d: %s\n", port, strerror(errno));
		return 1;
	}

	memset(&sa, 0, sizeof(sa));
	sa.sa_handler = on_signal;
	sigaction(SIGINT, &sa, NULL);
	sigaction(SIGTERM, &sa, NULL);
	signal(SIGPIPE, SIG_IGN);
	sa.sa_handler = NULL;
	sa.sa_sigaction = on_sigbus;
	sa.sa_flags = SA_SIGINFO | SA_NODEFER;
	sigaction(SIGBUS, &sa, NULL);

	fprintf(stderr, "debazd: %s, %d fields, udp/%d%s\n", HW_VARIANT,
		dz_fields_count(), port, sim ? " (simulated)" : "");
	for (int d = 0; d < DZ_DISPLAYS; d++)
		fprintf(stderr, "debazd: display %d shows 0x%08X (slot %d)\n", d,
			(unsigned)dz_disp_addr(d), dz_disp_slot(d));
	fprintf(stderr, "debazd: %d of %d slots inside reserved memory\n",
		dz_slots_usable(), DZ_SLOTS);
	if (!sim && dz_capture_addr() &&
	    !dz_reserved(dz_capture_addr(), DZ_SLOT_PITCH))
		fprintf(stderr, "debazd: WARNING capture writes 0x%08X, OUTSIDE reserved "
			"memory: it overwrites Linux RAM (fix: CLAUDE.md reserved-memory)\n",
			(unsigned)dz_capture_addr());

	if (disp_init(sim) < 0)
		fprintf(stderr, "debazd: no vsync thread\n");
	lfo_init();
	pwm_init();

	next = now_ms();
	{
	long next_tick = now_ms(), last_tick = now_ms();

	while (!stop) {
		struct pollfd pfd[2] = { { .fd = sock, .events = POLLIN },
					 { .fd = disp_frame_fd(), .events = POLLIN } };
		long t = now_ms(), until = next < next_tick ? next : next_tick;
		long wait = until - t;
		int rc = poll(pfd, pfd[1].fd >= 0 ? 2 : 1, wait > 0 ? (int)wait : 0);

		if (rc < 0 && errno != EINTR)
			break;
		/* frame tick: from vsync, or a 60 Hz timer without vsync */
		if (rc > 0 && pfd[1].fd >= 0 && (pfd[1].revents & POLLIN)) {
			uint64_t k;

			if (read(pfd[1].fd, &k, sizeof(k)) == sizeof(k)) {
				t = now_ms();
				lfo_tick((t - last_tick) / 1000.0);
				last_tick = t;
				next_tick = t + 50;	/* fallback if vsync stops */
			}
		} else if (now_ms() >= next_tick) {
			t = now_ms();
			lfo_tick((t - last_tick) / 1000.0);
			last_tick = t;
			next_tick = t + (disp_vsync_ok() ? 50 : 16);
		}
		if (rc > 0 && (pfd[0].revents & POLLIN)) {
			uint8_t buf[DZ_OSC_MAX_PKT];
			socklen_t fl = sizeof(cur_from);
			ssize_t n = recvfrom(sock, buf, sizeof(buf), 0,
					     (struct sockaddr *)&cur_from, &fl);

			if (n > 0)
				dz_osc_walk(buf, (size_t)n, handle, NULL);
		}
		if (now_ms() >= next) {
			monitor();
			audio_tick(now_ms());
			sound_tick();
			for (int s = 0; s < DZ_SLOTS; s++)
				dz_draw_movie_running(s);
			next = now_ms() + interval;
		}
	}
	}
	fprintf(stderr, "debazd: stopping\n");
	pwm_close();
	sound_close();
	disp_close();
	dz_draw_close();
	dz_unmap_all();
	close(sock);
	return 0;
}

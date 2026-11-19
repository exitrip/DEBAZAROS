/*
 * resume.c - debazd comes back where it was (2026-11-19).
 *
 * debazd runs as a systemd service that restarts it (debazd.service). A
 * restart used to start from nothing: no show, no LFOs, no movies, black
 * paint canvases, while the PL registers and the slot pictures were still
 * there. Now:
 *
 *   autosave  every 5 s, when the pixel thread is idle and the state
 *             changed: the whole state (state.c, ~700 targets, ~40 KB) +
 *             show / scene / cue to /run/debaz/autosave.bin (tmpfs: gone
 *             at a reboot, as the PL setup)
 *   resume    at start, unless /run/debaz/fresh exists (dzstart / plreload
 *             loaded the PL or started the displays: registers at reset,
 *             slots hold garbage): the show is read again and positioned
 *             (no go), the autosave is applied, and the paint buffers are
 *             rebuilt from the slots on first use (dz_draw_adopt_all).
 *             /run/debaz/fresh is removed by the boot setup (dzsetup.sh).
 *
 * Cost: one state dump every 5 s (~3-5 ms), a file write only on change.
 * A show's unsaved edits (cues recorded but not saved) are NOT in the
 * autosave: save the show.
 */
#define _GNU_SOURCE
#include "debazd.h"
#include "dz_draw.h"
#include "dz_map.h"

#include <errno.h>
#include <stddef.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <time.h>
#include <unistd.h>

#define RUN_DIR		"/run/debaz"
#define AUTOSAVE	RUN_DIR "/autosave.bin"
#define FRESH		RUN_DIR "/fresh"
#define MAGIC		"DZAS1\n"
#define EVERY_S		5.0

static uint64_t last_hash;
static double next_t;
static int enabled = 1;

static double mono(void)
{
	struct timespec t;

	clock_gettime(CLOCK_MONOTONIC, &t);
	return (double)t.tv_sec + t.tv_nsec * 1e-9;
}

static uint64_t fnv(uint64_t h, const void *p, size_t n)
{
	const uint8_t *b = p;

	while (n--)
		h = (h ^ *b++) * 0x100000001b3ULL;
	return h;
}

static int put_str(FILE *f, const char *s)
{
	uint16_t l = (uint16_t)strlen(s);

	return fwrite(&l, 2, 1, f) == 1 && fwrite(s, 1, l, f) == l ? 0 : -1;
}

static int get_str(FILE *f, char *out, size_t cap)
{
	uint16_t l;

	if (fread(&l, 2, 1, f) != 1 || l >= cap || fread(out, 1, l, f) != l)
		return -1;
	out[l] = 0;
	return 0;
}

static void autosave(void)
{
	st_list l = { 0 };
	char show[64], scene[64], tmp[64];
	double num;
	uint64_t h = 0xcbf29ce484222325ULL;
	FILE *f;

	st_list_dump(&l);
	cue_where(show, sizeof(show), scene, sizeof(scene), &num);
	h = fnv(h, show, strlen(show) + 1);
	h = fnv(h, scene, strlen(scene) + 1);
	h = fnv(h, &num, sizeof(num));
	for (int i = 0; i < l.n; i++)
		h = fnv(h, l.t[i].msg, l.t[i].len);
	if (h == last_hash) {
		st_list_free(&l);
		return;
	}
	mkdir(RUN_DIR, 0755);
	snprintf(tmp, sizeof(tmp), "%s.part", AUTOSAVE);
	f = fopen(tmp, "wb");
	if (!f) {
		st_list_free(&l);
		return;
	}
	int ok = fwrite(MAGIC, 1, 6, f) == 6 && !put_str(f, show) && !put_str(f, scene) &&
		 fwrite(&num, sizeof(num), 1, f) == 1 && fwrite(&l.n, sizeof(l.n), 1, f) == 1;
	for (int i = 0; ok && i < l.n; i++) {
		uint32_t len = (uint32_t)l.t[i].len;

		ok = !put_str(f, l.t[i].key) && fwrite(&len, 4, 1, f) == 1 &&
		     fwrite(l.t[i].msg, 1, len, f) == len;
	}
	if (fclose(f) != 0)
		ok = 0;
	if (ok && rename(tmp, AUTOSAVE) == 0)
		last_hash = h;
	else
		unlink(tmp);
	st_list_free(&l);
}

/*
 * systemd watchdog (2026-11-19): debazd.service has WatchdogSec=15; the
 * main loop says "alive" every 2 s on $NOTIFY_SOCKET (sd_notify protocol,
 * without libsystemd). A main loop blocked longer (the 2026-11-01 wait4
 * hang) gets debazd killed and restarted, and the state comes back.
 */
static void notify_alive(double t)
{
	static double next;
	static int fd = -2;
	static struct sockaddr_un sa;
	static socklen_t salen;

	if (fd == -1 || t < next)
		return;
	next = t + 2.0;
	if (fd == -2) {
		const char *e = getenv("NOTIFY_SOCKET");
		size_t l = e ? strlen(e) : 0;

		fd = -1;
		if (!e || (e[0] != '/' && e[0] != '@') || l >= sizeof(sa.sun_path))
			return;
		memset(&sa, 0, sizeof(sa));
		sa.sun_family = AF_UNIX;
		memcpy(sa.sun_path, e, l);
		if (e[0] == '@')
			sa.sun_path[0] = 0;		/* abstract socket */
		salen = (socklen_t)(offsetof(struct sockaddr_un, sun_path) + l);
		fd = socket(AF_UNIX, SOCK_DGRAM | SOCK_CLOEXEC, 0);
		if (fd < 0)
			return;
	}
	(void)sendto(fd, "WATCHDOG=1", 10, MSG_NOSIGNAL, (struct sockaddr *)&sa, salen);
}

void resume_tick(void)
{
	double t = mono();

	notify_alive(t);

	if (!enabled || t < next_t)
		return;
	if (pix_busy()) {		/* the dump would wait for the pixel job */
		next_t = t + 0.5;
		return;
	}
	next_t = t + EVERY_S;
	autosave();
}

void resume_init(void)
{
	char show[64], scene[64], key[160];
	double num;
	int n;
	st_list l = { 0 };
	FILE *f;
	char magic[6];

	if (getenv("DZ_NO_RESUME") || dz_map_simulating()) {	/* host tests */
		enabled = 0;
		return;
	}
	next_t = mono() + EVERY_S;
	if (access(FRESH, F_OK) == 0) {
		dzd_log("resume: fresh start (%s): no resume\n", FRESH);
		return;
	}
	dz_draw_adopt_all();		/* the slots hold the pictures */
	f = fopen(AUTOSAVE, "rb");
	if (!f) {
		dzd_log("resume: no autosave, paint continues on the slot pictures\n");
		return;
	}
	if (fread(magic, 1, 6, f) != 6 || memcmp(magic, MAGIC, 6) || get_str(f, show, sizeof(show)) ||
	    get_str(f, scene, sizeof(scene)) || fread(&num, sizeof(num), 1, f) != 1 ||
	    fread(&n, sizeof(n), 1, f) != 1 || n < 0 || n > 100000) {
		fclose(f);
		dzd_log("resume: %s unreadable\n", AUTOSAVE);
		return;
	}
	for (int i = 0; i < n; i++) {
		uint32_t len;
		uint8_t *msg;

		if (get_str(f, key, sizeof(key)) || fread(&len, 4, 1, f) != 1 || len > 65536 ||
		    !(msg = malloc(len)))
			break;
		if (fread(msg, 1, len, f) == len)
			st_list_put(&l, key, msg, len);
		free(msg);
	}
	fclose(f);
	if (scene[0] && cue_resume(show, scene, num) < 0)
		dzd_log("resume: show %s not readable: state only\n", show);
	st_list_apply(&l);
	dzd_log("resume: %d targets from %s (show %s)\n", l.n, AUTOSAVE, show);
	st_list_free(&l);
}

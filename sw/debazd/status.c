/*
 * status.c - what runs now, as text (2026-11-22): /run/debaz/status.
 *
 * /state lists every settable target (~850, mostly defaults); this lists
 * only what is ACTIVE: the slots and who writes them (movie, script,
 * ASCII, slit, capture, black), the displays, the running LFOs, the cue,
 * audio, and the load. Rewritten once per second from the frame tick
 * (temp file + rename, tmpfs, ~2 KB); each module adds its own lines from
 * its own variables without waiting for the pixel thread (a line can be a
 * frame old). Also: OSC /status -> s:text, dzweb GET /status.
 * DZ_STATUS_FILE = another path (host tests); "" = no file.
 */
#include "debazd.h"
#include "dz_ain.h"
#include "dz_draw.h"
#include "dz_hw.h"
#include "dz_map.h"

#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <time.h>
#include <unistd.h>

static char  sbuf[8192];
static size_t so;
static double last_ms;

void sline(const char *fmt, ...)
{
	va_list ap;
	int n;

	if (so >= sizeof(sbuf) - 2)
		return;
	va_start(ap, fmt);
	n = vsnprintf(sbuf + so, sizeof(sbuf) - so - 1, fmt, ap);
	va_end(ap);
	if (n < 0)
		return;
	so += (size_t)n < sizeof(sbuf) - so - 1 ? (size_t)n : sizeof(sbuf) - so - 2;
	sbuf[so++] = '\n';
	sbuf[so] = 0;
}

static long kb_of(const char *file, const char *key)
{
	char line[128];
	long v = -1;
	FILE *f = fopen(file, "r");

	while (f && fgets(line, sizeof(line), f))
		if (!strncmp(line, key, strlen(key))) {
			v = atol(line + strlen(key));
			break;
		}
	if (f)
		fclose(f);
	return v;
}

static void build(void)
{
	time_t now = time(NULL);
	char ts[32];

	so = 0;
	sbuf[0] = 0;
	strftime(ts, sizeof(ts), "%F %T", localtime(&now));
	sline("debazd: %s, pid %d, RSS %ld kB, RAM available %ld kB", ts, (int)getpid(),
	      kb_of("/proc/self/status", "VmRSS:"), kb_of("/proc/meminfo", "MemAvailable:"));
	stats_status_lines();
	disp_status_lines();
	for (int s = 0; s < DZ_SLOTS; s++) {	/* who writes each slot */
		char name[100];
		float fps;
		int audio;

		if (s == DZ_SLOT_CAPTURE)
			sline("slot %d: capture", s);
		else if (s == DZ_SLOT_BLANK)
			sline("slot %d: black (blanking)", s);
		if (dz_draw_movie_info(s, name, sizeof(name), &fps, &audio))
			sline("slot %d: movie %s%s", s, name, audio ? (dz_ain_ready(s) ? ", audio -> dzaudio" : ", audio -> HDMI") : "");
	}
	lua_status_lines();
	ascii_status_lines();
	slit_status_lines();
	anim_status_lines();
	lfo_status_lines();
	cue_status_lines();
	react_status_lines();
	sound_status_lines();
	if (dz_ain_ready(0))
		sline("dzaudio: running (movie audio and /audio/play go into it)");
}

void status_tick(void)
{
	static const char *path;
	double t = stats_now();

	if (t - last_ms < 1000.0)
		return;
	last_ms = t;
	if (!path) {
		const char *e = getenv("DZ_STATUS_FILE");

		path = e ? e : dz_map_simulating() ? "" : "/run/debaz/status";
		if (!e && *path)
			mkdir("/run/debaz", 0755);
	}
	if (!*path)
		return;
	build();
	{
		char tmp[200];
		FILE *f;

		snprintf(tmp, sizeof(tmp), "%s.tmp", path);
		if ((f = fopen(tmp, "w"))) {
			fwrite(sbuf, 1, so, f);
			if (fclose(f) == 0)
				rename(tmp, path);
		}
	}
}

int status_dispatch(const dz_msg *m)
{
	if (strcmp(m->path, "/status"))
		return 0;
	build();
	dzd_reply("/status", "s", sbuf);
	return 1;
}

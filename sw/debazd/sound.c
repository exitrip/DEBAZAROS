/*
 * sound.c - audio files, recording and the audio source of each output
 * (2026-10-28), through the ALSA card DEBAZ (driver debaz-audio):
 *
 *   /audio/play i:out s:file [i:loop]   play a file from DZ_AUDIO_DIR (any
 *                                       format ffmpeg reads) on output out:
 *                                       0 = HDMI 0, 1 = HDMI 1, 2 = I2S
 *   /audio/stop [i:out]                 stop one output (default all)
 *   /audio/rec s:file [f:secs]          record HDMI 2 In to DZ_AUDIO_DIR/file
 *                                       (WAV, ".wav" added if missing); secs
 *                                       0 = until /audio/rec/stop (max 1 h)
 *   /audio/rec/stop
 *   /audio/status                       -> /audio/out i:out s:file i:loop (x3)
 *                                          /audio/rec s:file f:seconds
 *   /audio/out/<n>/source [s:src]       what output n plays (no arg = query):
 *        HDMI 0/1: auto  (Linux audio while a PCM plays, else the HDMI 2 input)
 *                  linux | input (HDMI 2) | i2s (I2S DIN) | tone | off
 *        I2S (2):  auto | linux | input | off
 *                  (every source but off = HDMI mode + audio on, I2S on)
 *
 * The "Linux" part of a source is the driver's route control (amixer: the
 * driver owns those I2S_CTRL bits); the other parts are dz_fields. Without
 * the card (old image) the route falls back to the /pcm/to_* fields.
 * Until a source is set, the queries read it back from the hardware
 * (after a debazd restart). Players and the recorder are children in their own process group
 * (ffmpeg -f alsa / arecord); sound_tick reaps them.
 */
#include "debazd.h"
#include "dz_draw.h"
#include "dz_fields.h"

#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

#define OUTS 3

static const int   pcm_of[OUTS] = { 0, 1, 3 };	/* output -> DEBAZ PCM */
static const char *ctl_of[OUTS] = { "HDMI 0 Route", "HDMI 1 Route", "I2S Route" };
static const char *pcm_field[OUTS] = { "/pcm/to_hdmi0", "/pcm/to_hdmi1", "/pcm/to_i2s" };

static struct {
	pid_t pid;
	char  file[100];
	int   loop;
} play[OUTS];
static pid_t rec_pid;
static char  rec_file[104];
static long  rec_t0;
static char  source[OUTS][8] = { "?", "?", "?" };

static long now_ms(void)
{
	struct timespec ts;

	clock_gettime(CLOCK_MONOTONIC, &ts);
	return ts.tv_sec * 1000L + ts.tv_nsec / 1000000L;
}

static int file_ok(const char *n)	/* a bare name in DZ_AUDIO_DIR */
{
	if (!n || !*n || *n == '.' || strlen(n) > 96 || strstr(n, ".."))
		return 0;
	for (const char *p = n; *p; p++)
		if (!((*p >= 'a' && *p <= 'z') || (*p >= 'A' && *p <= 'Z') ||
		      (*p >= '0' && *p <= '9') || *p == '.' || *p == '_' || *p == '-'))
			return 0;
	return 1;
}

static pid_t spawn(const char *cmd)
{
	pid_t pid = fork();

	if (pid == 0) {
		setsid();	/* own process group: stop kills the whole command */
		execl("/bin/sh", "sh", "-c", cmd, (char *)NULL);
		_exit(127);
	}
	return pid < 0 ? 0 : pid;
}

static void stop_pid(pid_t *pid, int sig)
{
	if (*pid <= 0)
		return;
	kill(-*pid, sig);
	waitpid(*pid, NULL, 0);
	*pid = 0;
}

static int field(const char *path, uint32_t v)
{
	return dz_field_write(dz_field_find(path), v);
}

/* the driver's route control: Auto / Linux / Other */
static void route(int out, const char *mode)
{
	char cmd[160];

	if (access("/proc/asound/DEBAZ", F_OK) == 0) {
		snprintf(cmd, sizeof(cmd), "amixer -q -c DEBAZ cset name='%s' %s", ctl_of[out], mode);
		if (system(cmd) == 0)
			return;
	}
	field(pcm_field[out], !strcmp(mode, "Linux"));	/* no card: the bit itself */
}

static uint32_t fval(const char *path)
{
	uint32_t v = 0;

	dz_field_read(dz_field_find(path), &v);
	return v;
}

/* the route control now: 0 Auto, 1 Linux, 2 Other; -1 = no card */
static int route_now(int out)
{
	char cmd[160], line[200];
	int v = -1;
	FILE *f;

	if (access("/proc/asound/DEBAZ", F_OK) != 0)
		return -1;
	snprintf(cmd, sizeof(cmd), "amixer -c DEBAZ cget name='%s' 2>/dev/null", ctl_of[out]);
	f = popen(cmd, "r");
	if (!f)
		return -1;
	while (fgets(line, sizeof(line), f))
		if (strstr(line, ": values="))
			v = atoi(strstr(line, ": values=") + 9);
	pclose(f);
	return v;
}

/* the source from the hardware (debazd restarted, or set by someone else) */
static void read_source(int out)
{
	int r = route_now(out);
	const char *src;

	if (out < 2) {
		const char *tx = out == 0 ? "/audio/tx0" : "/audio/tx";
		char p[48];

		snprintf(p, sizeof(p), "%s/enable", tx);
		if (!fval(p)) {
			src = "off";
		} else {
			snprintf(p, sizeof(p), "%s/tone", tx);
			src = fval(p) ? "tone" : r == 0 ? "auto" : r == 1 ? "linux" :
			      fval(out == 0 ? "/i2s/to_hdmi0" : "/i2s/to_hdmi1") ? "i2s" : "input";
		}
	} else {
		src = !fval("/i2s/on") ? "off" : r == 0 ? "auto" : r == 1 ? "linux" : "input";
	}
	snprintf(source[out], sizeof(source[out]), "%s", src);
}

static int set_source(int out, const char *src)
{
	const char *tx = out == 0 ? "/audio/tx0" : "/audio/tx";
	char p[48];

	if (out < 2) {
		int off = !strcmp(src, "off");

		if (!off && strcmp(src, "auto") && strcmp(src, "linux") && strcmp(src, "input") &&
		    strcmp(src, "i2s") && strcmp(src, "tone"))
			return -1;
		route(out, !strcmp(src, "auto") ? "Auto" : !strcmp(src, "linux") ? "Linux" : "Other");
		field(out == 0 ? "/i2s/to_hdmi0" : "/i2s/to_hdmi1", !strcmp(src, "i2s"));
		snprintf(p, sizeof(p), "%s/tone", tx);
		field(p, !strcmp(src, "tone"));
		if (!strcmp(src, "auto") || !strcmp(src, "input"))
			field("/audio/rx/loop", 1);
		if (!off) {
			snprintf(p, sizeof(p), "%s/hdmi", tx);
			field(p, 1);
		}
		snprintf(p, sizeof(p), "%s/enable", tx);
		field(p, !off);
	} else {
		if (strcmp(src, "auto") && strcmp(src, "linux") && strcmp(src, "input") &&
		    strcmp(src, "off"))
			return -1;
		route(out, !strcmp(src, "auto") ? "Auto" : !strcmp(src, "linux") ? "Linux" : "Other");
		field("/i2s/play", !strcmp(src, "auto") || !strcmp(src, "input"));
		field("/i2s/on", strcmp(src, "off") != 0);
	}
	snprintf(source[out], sizeof(source[out]), "%s", src);
	return 0;
}

/* debazd runs as root; dzweb (user ebaz) must be able to delete recordings.
 * On the exFAT media partition every file already belongs to the mount's
 * user (and chown fails there): only change what differs. */
static void own_like_dir(const char *file)
{
	char p[200];
	struct stat st, fs;

	if (stat(DZ_AUDIO_DIR, &st) < 0)
		return;
	snprintf(p, sizeof(p), "%s/%s", DZ_AUDIO_DIR, file);
	if (stat(p, &fs) < 0 || (fs.st_uid == st.st_uid && fs.st_gid == st.st_gid))
		return;
	if (chown(p, st.st_uid, st.st_gid) < 0)
		dzd_log("sound: chown %s failed\n", p);
}

/* SIGKILL: at once (SIGTERM lets ffmpeg play out its ALSA buffer first,
 * up to 341 ms, while debazd's main loop waits) */
static void stop_play(int out)
{
	stop_pid(&play[out].pid, SIGKILL);
	play[out].file[0] = 0;
	play[out].loop = 0;
}

static int play_file(int out, const char *name, int loop)
{
	char cmd[512];

	stop_play(out);
	snprintf(cmd, sizeof(cmd),
		 "exec ffmpeg -nostdin -hide_banner -loglevel error %s-i '%s/%s' "
		 "-map 0:a:0 -ac 2 -ar 48000 -f alsa hw:DEBAZ,%d",
		 loop ? "-stream_loop -1 " : "", DZ_AUDIO_DIR, name, pcm_of[out]);
	play[out].pid = spawn(cmd);
	if (!play[out].pid)
		return -1;
	snprintf(play[out].file, sizeof(play[out].file), "%s", name);
	play[out].loop = loop;
	dzd_log("sound: out %d plays %s%s\n", out, name, loop ? " (loop)" : "");
	return 0;
}

static int rec_start(const char *name, double secs)
{
	char cmd[400];
	size_t n = strlen(name);

	if (rec_pid > 0) {
		stop_pid(&rec_pid, SIGINT);
		own_like_dir(rec_file);
	}
	snprintf(rec_file, sizeof(rec_file), "%s%s", name,
		 (n > 4 && !strcmp(name + n - 4, ".wav")) ? "" : ".wav");
	if (secs <= 0.0 || secs > 3600.0)
		secs = 3600.0;
	mkdir(DZ_AUDIO_DIR, 0755);
	snprintf(cmd, sizeof(cmd),
		 "exec arecord -q -D hw:DEBAZ,2 -f S16_LE -c 2 -r 48000 -d %d '%s/%s'",
		 (int)(secs + 0.5), DZ_AUDIO_DIR, rec_file);
	rec_pid = spawn(cmd);
	if (!rec_pid)
		return -1;
	rec_t0 = now_ms();
	dzd_log("sound: recording %s (max %.0f s)\n", rec_file, secs);
	return 0;
}

static int arg_i(const dz_arg *a, int dflt)
{
	return a->type == 'i' ? a->i : a->type == 'f' ? (int)a->f : dflt;
}

static int out_ok(int out)
{
	if (out >= 0 && out < OUTS)
		return 1;
	dzd_reply("/error", "ss", "output must be 0 (HDMI 0), 1 (HDMI 1) or 2 (I2S)", "/audio");
	return 0;
}

void sound_tick(void)
{
	for (int k = 0; k < OUTS; k++)
		if (play[k].pid > 0 && waitpid(play[k].pid, NULL, WNOHANG) == play[k].pid) {
			dzd_log("sound: out %d: %s ended\n", k, play[k].file);
			play[k].pid = 0;
			play[k].file[0] = 0;
			play[k].loop = 0;
		}
	if (rec_pid > 0 && waitpid(rec_pid, NULL, WNOHANG) == rec_pid) {
		dzd_log("sound: recording %s ended\n", rec_file);
		own_like_dir(rec_file);
		rec_pid = 0;
	}
}

int sound_dispatch(const dz_msg *m)
{
	const dz_arg *a = m->a;
	int n;

	if (!strcmp(m->path, "/audio/play")) {
		int out = m->n >= 1 ? arg_i(&a[0], -1) : -1;

		if (!out_ok(out))
			return 1;
		if (m->n < 2 || a[1].type != 's' || !file_ok(a[1].s)) {
			dzd_reply("/error", "ss", "/audio/play i:out s:file [i:loop] (file in audio/)", m->path);
			return 1;
		}
		if (play_file(out, a[1].s, m->n >= 3 && arg_i(&a[2], 0) != 0) < 0)
			dzd_reply("/error", "ss", "cannot start ffmpeg", m->path);
		else
			dzd_reply("/ok", "sis", m->path, out, a[1].s);
		return 1;
	}
	if (!strcmp(m->path, "/audio/stop")) {
		for (int k = 0; k < OUTS; k++)
			if (m->n < 1 || arg_i(&a[0], -1) == k)
				stop_play(k);
		dzd_reply("/ok", "s", m->path);
		return 1;
	}
	if (!strcmp(m->path, "/audio/rec")) {
		if (m->n < 1 || a[0].type != 's' || !file_ok(a[0].s)) {
			dzd_reply("/error", "ss", "/audio/rec s:file [f:secs]", m->path);
			return 1;
		}
		if (rec_start(a[0].s, m->n >= 2 ? (a[1].type == 'f' ? a[1].f : arg_i(&a[1], 0)) : 0) < 0)
			dzd_reply("/error", "ss", "cannot start arecord", m->path);
		else
			dzd_reply("/ok", "ss", m->path, rec_file);
		return 1;
	}
	if (!strcmp(m->path, "/audio/rec/stop")) {
		if (rec_pid > 0) {
			stop_pid(&rec_pid, SIGINT);	/* SIGINT: arecord finishes the WAV header */
			own_like_dir(rec_file);
		}
		dzd_reply("/ok", "ss", m->path, rec_file);
		return 1;
	}
	if (!strcmp(m->path, "/audio/status")) {
		sound_tick();
		for (int k = 0; k < OUTS; k++)
			if (source[k][0] == '?')
				read_source(k);
		for (int k = 0; k < OUTS; k++)
			dzd_reply("/audio/out", "isis", k, play[k].pid ? play[k].file : "",
				  play[k].loop, source[k]);
		dzd_reply("/audio/rec", "sf", rec_pid ? rec_file : "",
			  rec_pid ? (float)((now_ms() - rec_t0) / 1000.0) : 0.0f);
		return 1;
	}
	if (!strncmp(m->path, "/audio/out/", 11) && m->path[11] >= '0' && m->path[11] <= '9' &&
	    !strcmp(m->path + 12, "/source")) {
		n = m->path[11] - '0';
		if (!out_ok(n))
			return 1;
		if (m->n < 1 && source[n][0] == '?')
			read_source(n);
		if (m->n >= 1) {
			if (a[0].type != 's' || set_source(n, a[0].s) < 0) {
				dzd_reply("/error", "ss", n < 2 ? "source: auto|linux|input|i2s|tone|off"
							: "source: auto|linux|input|off", m->path);
				return 1;
			}
		}
		dzd_reply(m->path, "s", source[n]);
		return 1;
	}
	return 0;
}

void sound_close(void)
{
	for (int k = 0; k < OUTS; k++)
		stop_play(k);
	if (rec_pid > 0) {
		stop_pid(&rec_pid, SIGINT);
		own_like_dir(rec_file);
	}
}

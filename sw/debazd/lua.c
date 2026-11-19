/*
 * lua.c - LuaJIT scripts that draw into a slot (2026-11-20, sw/dzlua).
 *
 * One dzlua process per slot, started and stopped like a movie: a draw, an
 * image, a movie or a slit effect on the slot stops the script
 * (dz_draw_claim_hook), the picture stays. Scripts are files in
 * DZ_MEDIA_DIR/scripts (dzweb /media/scripts/<name>.lua: the web Console
 * tab saves there). The script API: sw/dzlua/prelude.lua.
 *
 * OSC (<s> = slot):
 *   /lua/<s>/start "name"     (re)start scripts/name(.lua) on slot s
 *   /lua/<s>/run "name"|""    the state model (cues): start, unless that
 *                             script runs or ended without an error there
 *                             already; "" = stop
 *   /lua/<s>/stop             the picture stays
 *   /lua/<s>/p/<key> v        a parameter: param.key in the script (int,
 *                             float or string; live, and kept for the next
 *                             start); "fps" sets the frame rate
 *   /lua/<s>/p/<key>          (no value) forget it
 *   /lua/<s>/layer auto|0|1   layer mode for the next start (auto, the
 *                             default: on when a movie or the capture
 *                             writes the slot; the script keeps running
 *                             over them, draws on its slot splat)
 *   /lua/<s>/status  -> /lua/<s>/status i:running s:name i:exit f:fps
 *                       f:ms (script time per frame) i:frames
 *                       (exit: -1 = runs / never ran, 0 = ended, > 0 error,
 *                       128 + n = signal n)
 *   /lua/<s>/log [bytes]  -> /lua/<s>/log s:text (the end of the log:
 *                       print() output and errors; default 2000 bytes)
 *   /lua/list                 -> /lua/<s>/status for every running script,
 *                             then /lua/list i:n (2026-11-20, the web panel)
 *   (state: /lua/<s>/p/<key> ..., then /lua/<s>/run)
 *
 * Files per slot: /tmp/dzlua.<s>.log, .stat (dzlua -t), .ctl (FIFO).
 */
#define _GNU_SOURCE
#include "debazd.h"
#include "dz_draw.h"
#include "dz_hw.h"
#include "dz_path.h"
#include "dz_vdma.h"

#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <unistd.h>

#ifndef DZ_SCRIPT_DIR
#define DZ_SCRIPT_DIR	DZ_MEDIA_DIR "/scripts"
#endif
#define NPARAM		32

typedef struct {
	char key[32];
	char tag;		/* 'i' 'f' 's' */
	int  i;
	float f;
	char s[96];
} lparam;

typedef struct {
	int    used;
	pid_t  pid;
	int    ctl;		/* our end of the control FIFO, -1 */
	int    exit;		/* -1 runs / never ran */
	char   name[100];	/* the state: runs or ended cleanly; "" = none */
	char   last[100];	/* the last started script (status) */
	int    layer;		/* -1 auto (live slot), 0, 1 */
	int    np;
	lparam p[NPARAM];
} lua_t;

static lua_t LS[DZ_SLOTS];

static void path_of(char *o, size_t n, const char *kind, int s)
{
	snprintf(o, n, "/tmp/dzlua.%d.%s", s, kind);
}

static int name_ok(const char *n)
{
	if (!n || !*n || *n == '.' || strlen(n) > 90 || strstr(n, ".."))
		return 0;
	for (const char *p = n; *p; p++)
		if (!((*p >= 'a' && *p <= 'z') || (*p >= 'A' && *p <= 'Z') ||
		      (*p >= '0' && *p <= '9') || *p == '.' || *p == '_' || *p == '-'))
			return 0;
	return 1;
}

/* "x" -> "x.lua"; a name with .lua stays */
static void canon(char *o, size_t n, const char *name)
{
	size_t l = strlen(name);

	if (l > 4 && !strcmp(name + l - 4, ".lua"))
		snprintf(o, n, "%.90s", name);
	else
		snprintf(o, n, "%.90s.lua", name);
}

static void param_line(const lparam *p, char *o, size_t n)
{
	if (p->tag == 'i')
		snprintf(o, n, "%s %d\n", p->key, p->i);
	else if (p->tag == 'f')
		snprintf(o, n, "%s %.9g\n", p->key, p->f);
	else
		snprintf(o, n, "%s %s\n", p->key, p->s);
}

static void ctl_send(lua_t *l, const lparam *p)
{
	char b[160];

	if (l->ctl < 0)
		return;
	param_line(p, b, sizeof(b));
	if (write(l->ctl, b, strlen(b)) < 0 && errno == EAGAIN)
		dzd_log("lua: control FIFO full, %s lost\n", p->key);
}

/* adopt: drop debazd's paint buffer of the slot (it is older than the
 * script's picture). Not when a draw takes the slot: its get() has just
 * built that buffer from the slot, and the draw writes into it. */
static void ended(int s, lua_t *l, int code, int adopt)
{
	char p[64];

	l->pid = 0;
	l->exit = code;
	if (l->ctl >= 0)
		close(l->ctl);
	l->ctl = -1;
	path_of(p, sizeof(p), "ctl", s);
	unlink(p);
	if (code != 0)
		l->name[0] = 0;		/* a cue starts it again */
	if (adopt)
		dz_draw_adopt(s);	/* a later draw continues on the script's picture */
}

static void stop(int s, int adopt)
{
	lua_t *l = &LS[s];

	if (l->pid <= 0)
		return;
	dz_kill_group(l->pid, SIGTERM);	/* reaps it */
	ended(s, l, 128 + SIGTERM, adopt);
}

/* dz_draw_live_hook: a running script makes its slot live (draws splat) */
static int slot_live(int s)
{
	return s >= 0 && s < DZ_SLOTS && LS[s].pid > 0;
}

static void claim(int s)
{
	if (s >= 0 && s < DZ_SLOTS && LS[s].pid > 0) {
		dzd_log("lua: slot %d taken by another writer: script %s stops\n", s, LS[s].last);
		stop(s, 0);
	}
}

void lua_poll(void)
{
	for (int s = 0; s < DZ_SLOTS; s++) {
		lua_t *l = &LS[s];
		int st;
		pid_t r;

		if (l->pid <= 0)
			continue;
		r = waitpid(l->pid, &st, WNOHANG);
		if (r == l->pid)
			ended(s, l, WIFEXITED(st) ? WEXITSTATUS(st) : 128 + WTERMSIG(st), 1);
		else if (r < 0 && errno == ECHILD)
			ended(s, l, 255, 1);
	}
}

static int start(int s, const char *name, const char *from)
{
	lua_t *l = &LS[s];
	char file[100], path[300], ctl[64], st[64], log[64], cmd[700];
	long need_kb = (long)dz_geom_w() * dz_geom_h() * 4 / 1024 + 12 * 1024;

	if (!name_ok(name)) {
		dzd_reply("/error", "ss", "script name: A-Z a-z 0-9 . _ -", from);
		return -1;
	}
	if (s == DZ_SLOT_BLANK) {
		dzd_reply("/error", "ss", "slot 11 is the black slot", from);
		return -1;
	}
	canon(file, sizeof(file), name);
	snprintf(path, sizeof(path), "%s/%s", DZ_SCRIPT_DIR, file);
	if (access(path, R_OK) < 0) {
		dzd_reply("/error", "ss", "no such script (Console tab: Save)", path);
		return -1;
	}
	stop(s, 1);
	dz_draw_claim_hook = claim;
	dz_draw_live_hook = slot_live;
	/* shared slots (ROADMAP.md section 19): a movie or the capture keeps
	 * writing the slot, the script draws over it in layer mode */
	int layer = l->layer >= 0 ? l->layer : dz_draw_live(s);

	dz_draw_adopt(s);
	if (dz_draw_mem_avail_kb() < need_kb)
		dz_draw_trim(need_kb + 24 * 1024, -1, 1.0, 0);
	if (dz_draw_mem_avail_kb() < need_kb) {
		dzd_reply("/error", "ss", "not enough free RAM for a script", from);
		return -1;
	}
	path_of(ctl, sizeof(ctl), "ctl", s);
	path_of(st, sizeof(st), "stat", s);
	path_of(log, sizeof(log), "log", s);
	unlink(ctl);
	unlink(st);
	if (mkfifo(ctl, 0600) < 0 ||
	    (l->ctl = open(ctl, O_RDWR | O_NONBLOCK | O_CLOEXEC)) < 0) {
		l->ctl = -1;
		dzd_reply("/error", "ss", "control FIFO failed", ctl);
		return -1;
	}
	for (int k = 0; k < l->np; k++)	/* waits in the FIFO for the script */
		ctl_send(l, &l->p[k]);
	snprintf(cmd, sizeof(cmd), "exec %s -s %d %s-c %s -t %s %s >%s 2>&1",
		 dz_prog("dzlua"), s, layer ? "-l " : "", ctl, st, path, log);
	l->pid = dz_spawn(cmd, 0);
	if (l->pid <= 0) {
		l->pid = 0;
		ended(s, l, 255, 1);
		dzd_reply("/error", "ss", "dzlua did not start", from);
		return -1;
	}
	l->used = 1;
	l->exit = -1;
	snprintf(l->name, sizeof(l->name), "%s", file);
	snprintf(l->last, sizeof(l->last), "%s", file);
	dzd_log("lua: %s on slot %d (pid %d)\n", file, s, (int)l->pid);
	return 0;
}

static void status(int s)
{
	lua_t *l = &LS[s];
	char p[40], sp[64];
	float fps = 0, ms = 0;
	unsigned long fr = 0;
	FILE *f;

	lua_poll();
	path_of(sp, sizeof(sp), "stat", s);
	if (l->pid > 0 && (f = fopen(sp, "r"))) {
		if (fscanf(f, "%f %f %lu", &fps, &ms, &fr) != 3)
			fps = ms = 0;
		fclose(f);
	}
	snprintf(p, sizeof(p), "/lua/%d/status", s);
	dzd_reply(p, "isiffi", l->pid > 0, l->last, l->exit, fps, ms, (int)fr);
}

static void log_tail(int s, int bytes)
{
	char p[40], lp[64], *b;
	FILE *f;
	long sz;
	size_t n = 0;

	if (bytes < 64) bytes = 64;
	if (bytes > 6000) bytes = 6000;	/* one OSC packet (8 KB) */
	b = calloc(1, (size_t)bytes + 1);
	if (!b)
		return;
	path_of(lp, sizeof(lp), "log", s);
	if ((f = fopen(lp, "r"))) {
		fseek(f, 0, SEEK_END);
		sz = ftell(f);
		fseek(f, sz > bytes ? sz - bytes : 0, SEEK_SET);
		n = fread(b, 1, (size_t)bytes, f);
		fclose(f);
	}
	b[n] = 0;
	for (size_t k = 0; k < n; k++)	/* a valid OSC string */
		if (!b[k])
			b[k] = ' ';
	snprintf(p, sizeof(p), "/lua/%d/log", s);
	dzd_reply(p, "s", b);
	free(b);
}

void lua_state(state_cb cb, void *ctx)
{
	char p[80];

	lua_poll();
	for (int s = 0; s < DZ_SLOTS; s++) {
		lua_t *l = &LS[s];

		if (!l->used)
			continue;
		for (int k = 0; k < l->np; k++) {
			const lparam *q = &l->p[k];

			snprintf(p, sizeof(p), "/lua/%d/p/%s", s, q->key);
			if (q->tag == 'i')
				st_emit(cb, ctx, NULL, p, "i", q->i);
			else if (q->tag == 'f')
				st_emit(cb, ctx, NULL, p, "f", q->f);
			else
				st_emit(cb, ctx, NULL, p, "s", q->s);
		}
		snprintf(p, sizeof(p), "/lua/%d/layer", s);
		st_emit(cb, ctx, NULL, p, "s", l->layer < 0 ? "auto" : l->layer ? "1" : "0");
		snprintf(p, sizeof(p), "/lua/%d/run", s);
		st_emit(cb, ctx, NULL, p, "s", l->name);
	}
}

static int key_ok(const char *k)
{
	if (!*k || strlen(k) >= 32)
		return 0;
	for (; *k; k++)
		if (!((*k >= 'a' && *k <= 'z') || (*k >= 'A' && *k <= 'Z') ||
		      (*k >= '0' && *k <= '9') || *k == '_'))
			return 0;
	return 1;
}

static void set_param(int s, const char *key, const dz_msg *m)
{
	lua_t *l = &LS[s];
	int k;

	for (k = 0; k < l->np; k++)
		if (!strcmp(l->p[k].key, key))
			break;
	if (m->n < 1) {			/* forget it */
		if (k < l->np)
			l->p[k] = l->p[--l->np];
		return;
	}
	if (k == l->np) {
		if (l->np == NPARAM) {
			dzd_reply("/error", "ss", "too many parameters (32)", m->path);
			return;
		}
		l->np++;
		memset(&l->p[k], 0, sizeof(l->p[k]));
		snprintf(l->p[k].key, sizeof(l->p[k].key), "%s", key);
	}
	lparam *q = &l->p[k];

	q->tag = m->a[0].type == 'f' ? 'f' : m->a[0].type == 's' ? 's' : 'i';
	if (q->tag == 'f')
		q->f = m->a[0].f;
	else if (q->tag == 'i')
		q->i = m->a[0].i;
	else {
		snprintf(q->s, sizeof(q->s), "%s", m->a[0].s);
		for (char *c = q->s; *c; c++)	/* one line */
			if (*c == '\n' || *c == '\r')
				*c = ' ';
	}
	l->used = 1;
	ctl_send(l, q);
}

int lua_dispatch(const dz_msg *m)
{
	int s, off = 0;
	const char *op, *str;

	if (!strcmp(m->path, "/lua/list")) {	/* every running script, then /lua/list n */
		int n = 0;

		lua_poll();
		for (int k = 0; k < DZ_SLOTS; k++)
			if (LS[k].pid > 0) {
				status(k);
				n++;
			}
		dzd_reply("/lua/list", "i", n);
		return 1;
	}
	if (sscanf(m->path, "/lua/%d/%n", &s, &off) != 1 || !off)
		return 0;
	{
		static int inited;

		if (!inited) {		/* layer: auto by default */
			for (int k = 0; k < DZ_SLOTS; k++)
				LS[k].layer = -1;
			inited = 1;
		}
	}
	if (s < 0 || s >= DZ_SLOTS) {
		dzd_reply("/error", "ss", "slot out of range", m->path);
		return 1;
	}
	op = m->path + off;
	str = m->n >= 1 && m->a[0].type == 's' ? m->a[0].s : NULL;
	if (!strcmp(op, "start")) {
		if (!str)
			dzd_reply("/error", "ss", "/lua/<s>/start \"name\"", m->path);
		else if (start(s, str, m->path) == 0)
			status(s);
	} else if (!strcmp(op, "run")) {
		char file[100];

		if (!str) {
			dzd_reply("/error", "ss", "/lua/<s>/run \"name\"|\"\"", m->path);
			return 1;
		}
		lua_poll();
		if (!*str) {
			stop(s, 1);
			LS[s].name[0] = 0;
			LS[s].used = 1;
			return 1;
		}
		canon(file, sizeof(file), str);
		if (strcmp(LS[s].name, file))	/* runs or ended cleanly already: no change */
			start(s, str, m->path);
	} else if (!strcmp(op, "stop")) {
		stop(s, 1);
		LS[s].name[0] = 0;
	} else if (!strncmp(op, "p/", 2)) {
		if (!key_ok(op + 2))
			dzd_reply("/error", "ss", "parameter name: A-Z a-z 0-9 _ (31)", m->path);
		else
			set_param(s, op + 2, m);
	} else if (!strcmp(op, "layer")) {
		if (m->n < 1) {
			char p[40];

			snprintf(p, sizeof(p), "/lua/%d/layer", s);
			dzd_reply(p, "s", LS[s].layer < 0 ? "auto" : LS[s].layer ? "1" : "0");
		} else if (str) {
			LS[s].layer = !strcmp(str, "auto") ? -1 : atoi(str) != 0;
		} else {
			LS[s].layer = m->a[0].type == 'f' ? m->a[0].f != 0 : m->a[0].i < 0 ? -1 : m->a[0].i != 0;
		}
		LS[s].used = 1;
	} else if (!strcmp(op, "status")) {
		status(s);
	} else if (!strcmp(op, "log")) {
		log_tail(s, m->n >= 1 && m->a[0].type == 'i' ? m->a[0].i : 2000);
	} else {
		dzd_reply("/error", "ss", "unknown (see sw/debazd/lua.c)", m->path);
	}
	return 1;
}

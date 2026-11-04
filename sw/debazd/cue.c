/*
 * cue.c - shows, scenes, cues and looks (2026-11-01; ROADMAP.md section 15,
 * steps 3-5; storage design of the user: a show FOLDER, looks by reference,
 * record into the cue only, decimal cue numbers).
 *
 * State model (state.c): a list of targets, one OSC message each, key =
 * address. Resolve:
 *   keyframe cue  = baseline + its looks + its own targets ("set")
 *   delta cue     = the state of the cue before + its looks + its set
 * (tracking; the first cue of a scene must be a keyframe). A LOOK is a
 * named part-state, used by reference: the same look in cue 1, 100, 150;
 * its transition belongs to the cue. RECORD stores into the cue's own set
 * only (the differences from baseline + looks, or from the cue before +
 * looks); looks change only with /look/save and /look/update.
 *
 *   /cue/record <scene> <num> keyframe|delta [name]   num: 1, 2.5, ...; an
 *                existing num is re-recorded (its looks, name, transition
 *                stay); a new scene name makes the scene
 *   /cue/go <scene> <num> [secs] [cut|fade|dip] [smooth|linear]
 *   /cue/next, /cue/back [same]   in number order; then the next scene
 *   /cue/stop (also the follow), /cue/status -> s:show s:scene f:num s:name
 *                s:kind i:scenes i:cues f:follow f:left (-1 = none, -2 =
 *                waiting for the end of its media) i:loop
 *   /cue/list <scene> -> /cue f:num s:name s:kind i:set f:fade s:curve
 *                s:transition s:looks f:follow i:end, /cue/end i:count
 *   /cue/get <scene> <num> (its set), /cue/resolve <scene> <num> ->
 *                /cue/target s:key s:address args..., /cue/end i:count
 *   /cue/delete | name | move <scene> <num> [s:name | f:newnum]
 *   /cue/fade <scene> <num> secs [smooth|linear] [cut|fade|dip]
 *   /cue/follow <scene> <num> secs | end [secs] | off   auto follow
 *                (2026-11-04): secs after its go, the next cue of the scene
 *                goes by itself (0 / off = manual); "end" = secs after the
 *                media this cue names in its own set ended: the movies of
 *                /movie/<s>/file (play once: /movie/<s>/loop 0) and the
 *                files of /audio/out/<n>/file (loop 0). After the last cue:
 *                the first again if the scene loops, else nothing (a follow
 *                never leaves its scene)
 *   /scene/loop <scene> [0|1]  repeat: after the last cue the first again
 *                (/cue/next too); no arg = query -> /scene/loop s i
 *   /cue/put <scene> <num> keyframe|delta [name]   make (or empty) a cue
 *                without recording; /cue/add <scene> <num> <address> args...
 *                puts one target into its set (same address = replaced).
 *                A playlist from the web (Media tab) is built with these
 *   /cue/look <scene> <num> add|remove <look>,  /cue/look <scene> <num> clear
 *   /look/save <name>     the targets that differ from the current cue (or
 *                from the baseline before any cue) -> a new look
 *   /look/update <name> [add]  its targets take their values now ("add":
 *                also the targets changed since the current cue)
 *   /look/apply <name> [secs] [mode] [curve],  /look/delete <name>,
 *   /look/list -> /look s:name i:targets i:uses ..., /look/end,
 *   /look/get <name> -> /look/target ..., /look/end
 *   /scene/add | delete | rename | list
 *   /show/new <name>, /show/load <name>, /show/reload, /show/save [name]
 *                [force], /show/list, /show/baseline (the state now),
 *   /show/check -> /show/issue s:where s:what ..., /show/check/end i:count
 *
 * Files: DZ_SHOW_DIR/<show>/ ($DZ_SHOW_DIR, else /data/shows; simulation
 * /tmp/dzshows): show.json (scenes, cues: number, name, kind, looks,
 * transition, set), baseline.json, looks/<name>.json. Targets as objects
 * {"/address": value or [values]} (1 = int, 1.0 = float). Every file is
 * written to <file>.part and renamed; show.json last. A save never deletes
 * a file it did not delete itself (a look deleted here); it refuses (unless
 * "force") to overwrite a file that changed on disk since it was read or
 * written here (a hand edit): /show/reload reads it instead. /show/check
 * finds what a hand edit can break (unknown addresses, argument types,
 * missing movies / audio / looks, a scene that starts with a delta).
 */
#include "debazd.h"
#include "dz_draw.h"
#include "dz_fields.h"
#include "dz_hw.h"
#include "dz_map.h"
#include "dz_osc.h"

#include <dirent.h>
#include <errno.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <time.h>
#include <unistd.h>

enum { K_KEY, K_DELTA };
static const char *const kind_names[] = { "keyframe", "delta" };
#define MAXLOOKS	8

typedef struct {
	double  num;
	char    name[48];
	int     kind;
	float   fade;
	char    curve[12];		/* linear | smooth */
	char    mode[8];		/* cut | fade | dip ("" = fade if fade > 0) */
	char    looks[MAXLOOKS][48];
	int     nlooks;
	float   follow;			/* auto follow after secs, 0 = manual */
	int     follow_end;		/* the secs count from the end of its media */
	st_list set;			/* its own targets */
} cue_t;

typedef struct {
	char   name[48];
	cue_t *c;			/* sorted by num */
	int    n, cap;
	int    loop;			/* after the last cue: the first again */
} scene_t;

typedef struct {
	char    name[48];
	st_list t;
} look_t;

static char     show_name[64] = "show";
static scene_t *S;
static int      ns, scap;
static look_t  *L;
static int      nl, lcap;
static st_list  baseline;
static int      cur_s = -1, cur_c = -1;	/* position: scene, cue index */
static struct {				/* the armed auto follow */
	int      on, s;
	double   num, t, at;
	int      end, ended, a_seen;	/* follow_end: waiting, done, audio seen */
	double   t_end;
	unsigned mov, aud;		/* the media of the cue: slots, outputs */
	unsigned gen0[DZ_SLOTS];	/* movie starts at the go */
} fol;

/* files read or written here: their mtime then (a hand edit changes it) */
#define NFILES	256
static struct {
	char   path[200];
	time_t mt;
} known[NFILES];
static int  nknown;
static char deleted[32][48];		/* looks deleted here: their files go at the next save */
static int  ndeleted;

/* ---- data ---- */

static void cue_free(cue_t *c)
{
	st_list_free(&c->set);
}

static void show_clear(void)
{
	for (int i = 0; i < ns; i++) {
		for (int j = 0; j < S[i].n; j++)
			cue_free(&S[i].c[j]);
		free(S[i].c);
	}
	free(S);
	S = NULL;
	ns = scap = 0;
	for (int i = 0; i < nl; i++)
		st_list_free(&L[i].t);
	free(L);
	L = NULL;
	nl = lcap = 0;
	st_list_free(&baseline);
	cur_s = cur_c = -1;
	nknown = ndeleted = 0;
}

static int scene_new(const char *name)
{
	if (ns == scap) {
		int cap = scap ? 2 * scap : 8;
		scene_t *t = realloc(S, sizeof(scene_t) * (size_t)cap);

		if (!t)
			return -1;
		S = t;
		scap = cap;
	}
	S[ns] = (scene_t){ 0 };
	snprintf(S[ns].name, sizeof(S[ns].name), "%s", name);
	return ns++;
}

static int scene_of(const dz_arg *a)
{
	if (a->type == 's') {
		for (int i = 0; i < ns; i++)
			if (!strcmp(S[i].name, a->s))
				return i;
		return -1;
	}
	int n = a->type == 'f' ? (int)a->f : a->i;
	return n >= 1 && n <= ns ? n - 1 : -1;
}

static double num_arg(const dz_arg *a)
{
	return a->type == 'f' ? a->f : a->type == 'i' ? a->i : (a->s ? atof(a->s) : 0);
}

/* cue numbers compare at 1/1000 (2.5 typed as a float arrives as 2.49999) */
static int num_eq(double a, double b)
{
	return fabs(a - b) < 0.0005;
}

static int cue_of(int s, const dz_arg *a)
{
	if (a->type == 's' && (a->s[0] < '0' || a->s[0] > '9')) {	/* a name */
		for (int i = 0; i < S[s].n; i++)
			if (!strcmp(S[s].c[i].name, a->s))
				return i;
		return -1;
	}
	double v = num_arg(a);

	for (int i = 0; i < S[s].n; i++)
		if (num_eq(S[s].c[i].num, v))
			return i;
	return -1;
}

/* a new cue with number num, sorted in; NULL if it exists or no memory */
static cue_t *cue_insert(int s, double num)
{
	scene_t *sc = &S[s];
	int at = 0;

	for (int i = 0; i < sc->n; i++) {
		if (num_eq(sc->c[i].num, num))
			return NULL;
		if (sc->c[i].num < num)
			at = i + 1;
	}
	if (sc->n == sc->cap) {
		int cap = sc->cap ? 2 * sc->cap : 8;
		cue_t *t = realloc(sc->c, sizeof(cue_t) * (size_t)cap);

		if (!t)
			return NULL;
		sc->c = t;
		sc->cap = cap;
	}
	memmove(&sc->c[at + 1], &sc->c[at], sizeof(cue_t) * (size_t)(sc->n - at));
	sc->n++;
	sc->c[at] = (cue_t){ .num = num, .curve = "linear" };
	if (cur_s == s && cur_c >= at)
		cur_c++;
	return &sc->c[at];
}

static look_t *look_find(const char *name)
{
	for (int i = 0; i < nl; i++)
		if (!strcmp(L[i].name, name))
			return &L[i];
	return NULL;
}

static look_t *look_new(const char *name)
{
	if (nl == lcap) {
		int cap = lcap ? 2 * lcap : 16;
		look_t *t = realloc(L, sizeof(look_t) * (size_t)cap);

		if (!t)
			return NULL;
		L = t;
		lcap = cap;
	}
	L[nl] = (look_t){ 0 };
	snprintf(L[nl].name, sizeof(L[nl].name), "%s", name);
	return &L[nl++];
}

static int look_uses(const char *name)
{
	int n = 0;

	for (int s = 0; s < ns; s++)
		for (int i = 0; i < S[s].n; i++)
			for (int k = 0; k < S[s].c[i].nlooks; k++)
				n += !strcmp(S[s].c[i].looks[k], name);
	return n;
}

static void put_all(st_list *out, const st_list *in)
{
	for (int t = 0; t < in->n; t++)
		st_list_put(out, in->t[t].key, in->t[t].msg, in->t[t].len);
}

static void put_looks(st_list *out, const cue_t *c)
{
	for (int k = 0; k < c->nlooks; k++) {
		const look_t *lk = look_find(c->looks[k]);

		if (lk)
			put_all(out, &lk->t);	/* a missing look: /show/check reports it */
	}
}

/* state(cue i of scene s) */
static void resolve(int s, int i, st_list *out)
{
	int k = i;

	while (k > 0 && S[s].c[k].kind != K_KEY)
		k--;
	st_list_copy(out, &baseline);
	for (int j = k; j <= i; j++) {
		put_looks(out, &S[s].c[j]);
		put_all(out, &S[s].c[j].set);
	}
}

/* ---- transitions (step 4) ----
 * fade: numbers ramp, the rest switches at the start. Fields ramp in
 * trans.c (RGB per lane); other single-number messages ramp here, one
 * message per frame. dip: the output gains go to 0 in the first half, all
 * switches at the bottom, the gains come back in the second half. */
enum { T_CUT, T_FADE, T_DIP };
static const char *const tnames[] = { "cut", "fade", "dip" };

static int mode_of(const char *m, float fade)
{
	if (m && !strcmp(m, "cut"))
		return T_CUT;
	if (m && !strcmp(m, "dip"))
		return T_DIP;
	if (m && !strcmp(m, "fade"))
		return T_FADE;
	return fade > 0 ? T_FADE : T_CUT;
}

/* a field that may ramp: not on/off, not 1..5 bits, not a choice */
static int field_continuous(const dz_field *f)
{
	static const char *const choice[] = { "/mode", "/shape", "/tick", "/reset", "/last",
					      "/func", "/stream", "/vic", "/src", "/key" };
	size_t l = strlen(f->path);

	if (f->unit == DZ_BOOL || f->width < 6)
		return 0;
	for (size_t i = 0; i < sizeof(choice) / sizeof(choice[0]); i++) {
		size_t c = strlen(choice[i]);

		if (l >= c && !strcmp(f->path + l - c, choice[i]))
			return 0;
	}
	return 1;
}

/* a single-number message (not a field) that may ramp: floats, and the
 * integer crop positions */
static int msg_continuous(const dz_msg *m)
{
	size_t l = strlen(m->path);

	if (m->n != 1)
		return 0;
	if (m->a[0].type == 'f')
		return 1;
	return m->a[0].type == 'i' && l > 7 &&
	       (!strcmp(m->path + l - 7, "/crop/x") || !strcmp(m->path + l - 7, "/crop/y"));
}

static double num_of(const dz_arg *a)
{
	return a->type == 'f' ? a->f : a->i;
}

/* the raw value a field message sets (RGB: r g b in the lanes) */
static int field_raw(const dz_field *f, const dz_msg *m, uint32_t *raw)
{
	if (f->unit == DZ_RGB && m->n >= 3) {
		*raw = ((uint32_t)num_of(&m->a[0]) & 255) << DZ_LANE_R |
		       ((uint32_t)num_of(&m->a[1]) & 255) << DZ_LANE_G |
		       ((uint32_t)num_of(&m->a[2]) & 255) << DZ_LANE_B;
		return 0;
	}
	if (m->n >= 1 && m->a[0].type != 's') {
		*raw = (uint32_t)(int64_t)num_of(&m->a[0]) & dz_field_mask(f);
		return 0;
	}
	return -1;
}

typedef struct {
	char   path[64];
	double from, to, t, dur;
	int    isint, smooth, on;
} mramp_t;

#define MRAMPS	64
static mramp_t mr[MRAMPS];

static void mramp_start(const char *path, double from, double to, int isint, double dur, int smooth)
{
	mramp_t *r = NULL;

	for (int i = 0; i < MRAMPS && !r; i++)		/* the same path: replace */
		if (mr[i].on && !strcmp(mr[i].path, path))
			r = &mr[i];
	for (int i = 0; i < MRAMPS && !r; i++)
		if (!mr[i].on)
			r = &mr[i];
	if (!r)
		return;
	*r = (mramp_t){ .from = from, .to = to, .dur = dur, .isint = isint, .smooth = smooth, .on = 1 };
	snprintf(r->path, sizeof(r->path), "%s", path);
}

static void send_num(const char *path, double v, int isint)
{
	dz_msg m = { .path = path, .n = 1 };

	m.a[0] = isint ? (dz_arg){ .type = 'i', .i = (int32_t)lround(v) } : (dz_arg){ .type = 'f', .f = (float)v };
	dzd_handle_internal(&m);
}

/* the output gains that a dip takes to black */
static const char *const dip_fields[] = { "/hdmi/0/gain/rgb", "/hdmi/1/gain/rgb",
					   "/hdmi/1/feedback/rgb", "/hdmi/1/osc/sin/gain/rgb",
					   "/hdmi/1/osc/phase/gain/rgb" };
#define NDIP	(sizeof(dip_fields) / sizeof(dip_fields[0]))

static struct {
	int      on, phase, smooth;
	double   t, half;
	st_list  pending;		/* the targets that switch at the bottom */
	uint32_t keep[NDIP];		/* the gains before the dip */
	int      have[NDIP];
} dip;

static int is_dip_field(const char *path)
{
	for (size_t i = 0; i < NDIP; i++)
		if (!strcmp(path, dip_fields[i]))
			return (int)i;
	return -1;
}

/* apply d (the targets that differ) with a transition; now = the state now
 * (where the ramps start) */
static void apply_trans(const st_list *d, const st_list *now, int mode, double secs, int smooth)
{
	if (mode == T_DIP && secs > 0) {
		dip.on = 1;
		dip.phase = 1;
		dip.t = 0;
		dip.half = secs / 2;
		dip.smooth = smooth;
		st_list_copy(&dip.pending, d);
		for (size_t i = 0; i < NDIP; i++) {
			const dz_field *f = dz_field_find(dip_fields[i]);

			dip.have[i] = f && dz_field_read(f, &dip.keep[i]) == 0;
			if (dip.have[i])
				trans_field(f, 0, dip.half, smooth);
		}
		return;
	}
	for (int i = 0; i < d->n; i++) {
		dz_msg m;
		const dz_field *f;
		uint32_t raw;

		if (dz_osc_parse(d->t[i].msg, d->t[i].len, &m) < 0)
			continue;
		f = !strcmp(d->t[i].key, m.path) ? dz_field_find(m.path) : NULL;
		if (mode == T_FADE && secs > 0 && f && field_continuous(f) && field_raw(f, &m, &raw) == 0) {
			trans_field(f, raw, secs, smooth);
			continue;
		}
		if (mode == T_FADE && secs > 0 && !f && msg_continuous(&m)) {
			int j = st_list_find(now, d->t[i].key);
			dz_msg o;

			if (j >= 0 && dz_osc_parse(now->t[j].msg, now->t[j].len, &o) == 0 && o.n == 1 &&
			    o.a[0].type != 's') {
				mramp_start(m.path, num_of(&o.a[0]), num_of(&m.a[0]), m.a[0].type == 'i', secs, smooth);
				continue;
			}
		}
		dzd_handle_internal(&m);		/* switches now */
	}
}

static void follow_fire(void);

/* the media of the cue we follow ended: every movie is not running and
 * started after the go (or 3 s passed: it did not start, or played on from
 * the cue before), every audio file played and stopped (or 3 s passed) */
static int media_done(void)
{
	for (int s = 0; s < DZ_SLOTS; s++)
		if ((fol.mov >> s) & 1) {
			if (dz_draw_movie_alive(s))
				return 0;
			if (dz_draw_movie_gen(s) == fol.gen0[s] && fol.t < 3.0)
				return 0;
		}
	for (int o = 0; o < 3; o++)
		if ((fol.aud >> o) & 1) {
			if (sound_playing(o)) {
				fol.a_seen = 1;
				return 0;
			}
			if (!fol.a_seen && fol.t < 3.0)
				return 0;
		}
	return 1;
}

void cue_tick(double dt)
{
	if (fol.on) {
		fol.t += dt;
		if (fol.end && !fol.ended && media_done()) {
			fol.ended = 1;
			fol.t_end = fol.t;
		}
		if (fol.end ? fol.ended && fol.t - fol.t_end >= fol.at : fol.t >= fol.at) {
			fol.on = 0;
			follow_fire();
		}
	}
	for (int i = 0; i < MRAMPS; i++) {
		mramp_t *r = &mr[i];

		if (!r->on)
			continue;
		r->t += dt;
		double x = r->t >= r->dur ? 1.0 : r->t / r->dur;
		if (r->smooth)
			x = x * x * (3.0 - 2.0 * x);
		send_num(r->path, r->from + (r->to - r->from) * x, r->isint);
		if (r->t >= r->dur)
			r->on = 0;
	}
	if (!dip.on)
		return;
	dip.t += dt;
	if (dip.phase == 1 && dip.t >= dip.half) {	/* the bottom: switch, then back up */
		uint32_t to[NDIP];

		for (size_t k = 0; k < NDIP; k++)
			to[k] = dip.keep[k];
		for (int i = 0; i < dip.pending.n; i++) {
			dz_msg m;
			int k;

			if (dz_osc_parse(dip.pending.t[i].msg, dip.pending.t[i].len, &m) < 0)
				continue;
			k = is_dip_field(m.path);
			if (k >= 0) {			/* a gain: its new value, reached in the second half */
				const dz_field *f = dz_field_find(m.path);

				if (f)
					field_raw(f, &m, &to[k]);
				continue;
			}
			dzd_handle_internal(&m);
		}
		for (size_t k = 0; k < NDIP; k++)
			if (dip.have[k])
				trans_field(dz_field_find(dip_fields[k]), to[k], dip.half, dip.smooth);
		st_list_free(&dip.pending);
		dip.phase = 2;
	} else if (dip.phase == 2 && dip.t >= 2 * dip.half) {
		dip.on = 0;
	}
}

static void stop_all(void)
{
	trans_stop_all();
	for (int i = 0; i < MRAMPS; i++)
		mr[i].on = 0;
	if (dip.on && dip.phase == 1) {			/* do not leave it black */
		for (size_t k = 0; k < NDIP; k++)
			if (dip.have[k])
				dz_field_write(dz_field_find(dip_fields[k]), dip.keep[k]);
	}
	st_list_free(&dip.pending);
	dip.on = 0;
}

typedef struct {
	int    mode, smooth;
	double secs;
} tparam;

static tparam tparam_of(const cue_t *c, const dz_msg *m, int k)
{
	tparam tp = { .secs = c ? c->fade : 0, .smooth = c && !strcmp(c->curve, "smooth") };
	const char *mode = c ? c->mode : "";

	for (int j = k; m && j < m->n; j++) {
		if (m->a[j].type == 'f' || m->a[j].type == 'i')
			tp.secs = num_of(&m->a[j]);
		else if (!strcmp(m->a[j].s, "smooth") || !strcmp(m->a[j].s, "linear"))
			tp.smooth = m->a[j].s[0] == 's';
		else
			mode = m->a[j].s;
	}
	tp.mode = mode_of(mode, (float)tp.secs);
	if (tp.mode == T_CUT)
		tp.secs = 0;
	return tp;
}

/* apply what in `want` differs from now, with a transition; how many */
static int apply_diff(const st_list *want, tparam tp)
{
	st_list now = { 0 }, d = { 0 };
	int n;

	st_list_dump(&now);
	st_list_diff(want, &now, &d);
	stop_all();				/* a new go replaces a running one */
	apply_trans(&d, &now, tp.mode, tp.secs, tp.smooth);
	n = d.n;
	st_list_free(&now);
	st_list_free(&d);
	return n;
}

static void status(void)
{
	const cue_t *c = cur_s >= 0 && cur_c >= 0 && cur_c < S[cur_s].n ? &S[cur_s].c[cur_c] : NULL;

	dzd_reply("/cue/status", "ssfssiiffi", show_name, cur_s >= 0 ? S[cur_s].name : "",
		  c ? (float)c->num : 0.0f, c ? c->name : "", c ? kind_names[c->kind] : "", ns,
		  cur_s >= 0 ? S[cur_s].n : 0, c ? c->follow : 0.0f,
		  !fol.on ? -1.0f : fol.end && !fol.ended ? -2.0f :	/* -2: waiting for the end */
		  (float)(fol.at - (fol.t - (fol.end ? fol.t_end : 0))), cur_s >= 0 ? S[cur_s].loop : 0);
}

static double ms_since(const struct timespec *t0)
{
	struct timespec t1;

	clock_gettime(CLOCK_MONOTONIC, &t1);
	return (t1.tv_sec - t0->tv_sec) * 1e3 + (t1.tv_nsec - t0->tv_nsec) / 1e6;
}

/* the follow of the cue we are on now (a new go replaces the old one) */
static void arm(void)
{
	const cue_t *c = cur_s >= 0 && cur_c >= 0 && cur_c < S[cur_s].n ? &S[cur_s].c[cur_c] : NULL;

	fol.on = c && (c->follow > 0.0f || c->follow_end);
	if (!fol.on)
		return;
	fol.s = cur_s;
	fol.num = c->num;
	fol.t = 0;
	fol.at = c->follow;
	fol.end = c->follow_end;
	fol.ended = fol.a_seen = 0;
	fol.mov = fol.aud = 0;
	for (int k = 0; fol.end && k < c->set.n; k++) {
		dz_msg m;
		int x, off = 0;

		if (dz_osc_parse(c->set.t[k].msg, c->set.t[k].len, &m) < 0 || m.n < 1 ||
		    m.a[0].type != 's' || !m.a[0].s[0])
			continue;
		if (sscanf(m.path, "/movie/%d/file%n", &x, &off) == 1 && !m.path[off] && x >= 0 && x < DZ_SLOTS)
			fol.mov |= 1u << x;
		else if (sscanf(m.path, "/audio/out/%d/file%n", &x, &off) == 1 && !m.path[off] && x >= 0 && x < 3)
			fol.aud |= 1u << x;
	}
	for (int s = 0; s < DZ_SLOTS; s++)
		fol.gen0[s] = dz_draw_movie_gen(s);
}

static void go(int s, int i, const dz_msg *m, int k)
{
	st_list want = { 0 };
	tparam tp = tparam_of(&S[s].c[i], m, k);
	struct timespec t0;
	int n;

	clock_gettime(CLOCK_MONOTONIC, &t0);
	resolve(s, i, &want);
	n = apply_diff(&want, tp);
	st_list_free(&want);
	cur_s = s;
	cur_c = i;
	arm();
	dzd_log("cue: go %s %g \"%s\" (%d targets, %s %.1f s, %.1f ms)\n", S[s].name, S[s].c[i].num,
		S[s].c[i].name, n, tnames[tp.mode], tp.secs, ms_since(&t0));
	status();
}

static void next(const dz_msg *msg)
{
	int s = cur_s, i = cur_c + 1;

	if (s < 0) {
		s = 0;
		i = 0;
	}
	if (s == cur_s && i >= S[s].n && S[s].loop && S[s].n > 0) {
		go(s, 0, msg, 0);			/* a loop: the first cue again */
		return;
	}
	while (s < ns && i >= S[s].n) {
		s++;
		i = 0;
	}
	if (s >= ns) {
		dzd_reply("/error", "ss", "no next cue", "/cue/next");
		return;
	}
	if (S[s].c[i].kind == K_KEY || s != cur_s) {
		go(s, i, msg, 0);
		return;
	}
	/* in order: only what this cue changes (its looks + its set) */
	st_list d = { 0 };
	struct timespec t0;

	clock_gettime(CLOCK_MONOTONIC, &t0);
	put_looks(&d, &S[s].c[i]);
	put_all(&d, &S[s].c[i].set);
	int n = apply_diff(&d, tparam_of(&S[s].c[i], msg, 0));
	st_list_free(&d);
	cur_s = s;
	cur_c = i;
	arm();
	dzd_log("cue: next %s %g \"%s\" (%d targets, %.1f ms)\n", S[s].name, S[s].c[i].num, S[s].c[i].name,
		n, ms_since(&t0));
	status();
}

/* the follow time of the current cue is over: its next cue, inside the
 * scene (the first again in a loop) */
static void follow_fire(void)
{
	if (cur_s < 0 || cur_s != fol.s || cur_c < 0 || cur_c >= S[cur_s].n ||
	    !num_eq(S[cur_s].c[cur_c].num, fol.num))
		return;				/* moved, deleted or loaded since */
	if (cur_c + 1 < S[cur_s].n)
		next(NULL);
	else if (S[cur_s].loop)
		go(cur_s, 0, NULL, 0);
	else
		dzd_log("cue: follow at the end of scene %s (no loop): stays\n", S[cur_s].name);
}

/* record cue num of scene s: its set = the differences from baseline +
 * looks (keyframe) or the cue before + looks (delta) */
static void record(int s, double num, int kind, const char *name, const char *path)
{
	st_list now = { 0 }, base = { 0 };
	int i = -1;
	cue_t *c;

	for (int k = 0; k < S[s].n; k++)
		if (num_eq(S[s].c[k].num, num))
			i = k;
	if (kind == K_DELTA && (i == 0 || (i < 0 && (S[s].n == 0 || num < S[s].c[0].num)))) {
		dzd_reply("/error", "ss", "the first cue of a scene must be a keyframe", path);
		return;
	}
	if (kind == K_DELTA) {			/* relative to the cue before by number */
		int prev = -1;

		for (int k = 0; k < S[s].n; k++)
			if (S[s].c[k].num < num - 0.0005)
				prev = k;
		if (prev >= 0 && (cur_s != s || cur_c != prev)) {
			char w[200];

			snprintf(w, sizeof(w), "delta %g is relative to cue %g (you were not on it): it holds "
				 "everything that differs from cue %g", num, S[s].c[prev].num, S[s].c[prev].num);
			dzd_reply("/warning", "ss", w, path);
		}
	}
	st_list_dump(&now);
	if (kind == K_KEY && baseline.n == 0) {
		st_list_copy(&baseline, &now);		/* the first keyframe: the baseline too */
		dzd_log("cue: baseline taken (%d targets)\n", baseline.n);
	}
	if (i < 0) {
		c = cue_insert(s, num);
		if (!c) {
			st_list_free(&now);
			dzd_reply("/error", "ss", "no memory", path);
			return;
		}
		i = (int)(c - S[s].c);
	}
	c = &S[s].c[i];
	if (kind == K_KEY) {
		st_list_copy(&base, &baseline);
		put_looks(&base, c);
	} else {
		resolve(s, i - 1, &base);
		put_looks(&base, c);
	}
	st_list_diff(&now, &base, &c->set);
	c->kind = kind;
	if (name && *name)
		snprintf(c->name, sizeof(c->name), "%s", name);
	else if (!c->name[0])
		snprintf(c->name, sizeof(c->name), "cue %g", num);
	st_list_free(&now);
	st_list_free(&base);
	cur_s = s;
	cur_c = i;
	dzd_log("cue: record %s %g %s \"%s\" (%d own targets)\n", S[s].name, num, kind_names[kind], c->name,
		c->set.n);
	dzd_reply("/cue/record", "sfsi", S[s].name, (float)num, kind_names[kind], c->set.n);
}

static void reply_list(const char *item, const char *end, const st_list *l)
{
	for (int i = 0; i < l->n; i++) {
		dz_msg m;

		if (dz_osc_parse(l->t[i].msg, l->t[i].len, &m) == 0)
			st_reply_target(item, l->t[i].key, &m);
	}
	dzd_reply(end, "i", l->n);
}

/* the targets that differ from the current cue (or the baseline) */
static void changes_now(st_list *out)
{
	st_list now = { 0 }, base = { 0 };

	st_list_dump(&now);
	if (cur_s >= 0 && cur_c >= 0)
		resolve(cur_s, cur_c, &base);
	else
		st_list_copy(&base, &baseline);
	st_list_diff(&now, &base, out);
	st_list_free(&now);
	st_list_free(&base);
}

/* ---- files ---- */

static const char *show_dir(void)
{
	const char *e = getenv("DZ_SHOW_DIR");

	return e && *e ? e : dz_map_simulating() ? "/tmp/dzshows" : "/data/shows";
}

static int name_ok(const char *n)
{
	if (!n || !*n || *n == '.' || strlen(n) > 46)
		return 0;
	for (const char *p = n; *p; p++)
		if (!((*p >= 'a' && *p <= 'z') || (*p >= 'A' && *p <= 'Z') || (*p >= '0' && *p <= '9') ||
		      *p == '.' || *p == '_' || *p == '-'))
			return 0;
	return 1;
}

static time_t mtime_of(const char *path)
{
	struct stat st;

	return stat(path, &st) == 0 ? st.st_mtime : 0;
}

static void known_set(const char *path)
{
	for (int i = 0; i < nknown; i++)
		if (!strcmp(known[i].path, path)) {
			known[i].mt = mtime_of(path);
			return;
		}
	if (nknown < NFILES) {
		snprintf(known[nknown].path, sizeof(known[nknown].path), "%s", path);
		known[nknown++].mt = mtime_of(path);
	}
}

/* 1 if path exists and changed since it was read / written here (or was
 * never read here: a file someone else made) */
static int changed_on_disk(const char *path)
{
	time_t m = mtime_of(path);

	if (!m)
		return 0;
	for (int i = 0; i < nknown; i++)
		if (!strcmp(known[i].path, path))
			return known[i].mt != m;
	return 1;
}

static void jstr(FILE *f, const char *s)
{
	fputc('"', f);
	for (const unsigned char *p = (const unsigned char *)s; *p; p++) {
		if (*p == '"' || *p == '\\')
			fprintf(f, "\\%c", *p);
		else if (*p < 0x20)
			fprintf(f, "\\u%04x", *p);
		else
			fputc(*p, f);
	}
	fputc('"', f);
}

static void jfloat(FILE *f, double v)
{
	char b[40];

	if (!isfinite(v))
		v = 0;
	/* the shortest form that reads back as the same 32-bit float (OSC
	 * floats are 32 bit: %.9g wrote 0.7 as 0.699999988) */
	snprintf(b, sizeof(b), "%.7g", v);
	if ((float)strtod(b, NULL) != (float)v)
		snprintf(b, sizeof(b), "%.9g", v);
	fputs(b, f);
	if (!strpbrk(b, ".eE"))
		fputs(".0", f);			/* stays a float on load */
}

/* targets as a JSON object {"/address": value or [values]} (key = address) */
static void jtargets(FILE *f, const st_list *l, const char *ind)
{
	fputc('{', f);
	for (int t = 0; t < l->n; t++) {
		dz_msg m;

		if (dz_osc_parse(l->t[t].msg, l->t[t].len, &m) < 0)
			continue;
		fprintf(f, "%s\n%s", t ? "," : "", ind);
		jstr(f, l->t[t].key);
		fputs(": ", f);
		if (m.n != 1)
			fputc('[', f);
		for (int k = 0; k < m.n; k++) {
			if (k)
				fputs(", ", f);
			if (m.a[k].type == 'i')
				fprintf(f, "%d", m.a[k].i);
			else if (m.a[k].type == 'f')
				jfloat(f, m.a[k].f);
			else
				jstr(f, m.a[k].s ? m.a[k].s : "");
		}
		if (m.n != 1)
			fputc(']', f);
	}
	fputc('}', f);
}

/* write path via path.part + rename */
static FILE *wopen(const char *path, char *tmp, size_t cap)
{
	snprintf(tmp, cap, "%s.part", path);
	return fopen(tmp, "w");
}

static int wclose(FILE *f, const char *tmp, const char *path)
{
	if (fclose(f) != 0 || rename(tmp, path) != 0) {
		unlink(tmp);
		return -1;
	}
	known_set(path);
	return 0;
}

static int show_write(const char *name, int force, char *err, size_t errcap)
{
	char dir[200], path[260], tmp[270];
	FILE *f;

	snprintf(dir, sizeof(dir), "%s/%s", show_dir(), name);
	mkdir(show_dir(), 0755);
	mkdir(dir, 0755);
	snprintf(path, sizeof(path), "%s/looks", dir);
	mkdir(path, 0755);
	if (!force) {				/* a hand edit since: refuse */
		char what[200] = "";

		snprintf(path, sizeof(path), "%s/show.json", dir);
		if (changed_on_disk(path))
			snprintf(what, sizeof(what), "show.json");
		snprintf(path, sizeof(path), "%s/baseline.json", dir);
		if (!what[0] && changed_on_disk(path))
			snprintf(what, sizeof(what), "baseline.json");
		for (int i = 0; !what[0] && i < nl; i++) {
			snprintf(path, sizeof(path), "%s/looks/%s.json", dir, L[i].name);
			if (changed_on_disk(path))
				snprintf(what, sizeof(what), "looks/%s.json", L[i].name);
		}
		if (what[0]) {
			snprintf(err, errcap, "%s changed on disk since it was loaded: /show/reload, or "
				 "/show/save %s force", what, name);
			return -1;
		}
	}
	snprintf(path, sizeof(path), "%s/baseline.json", dir);
	if (!(f = wopen(path, tmp, sizeof(tmp))))
		goto fail;
	fprintf(f, "{\"baseline\": ");
	jstr(f, name);
	fprintf(f, ", \"targets\": ");
	jtargets(f, &baseline, "  ");
	fprintf(f, "}\n");
	if (wclose(f, tmp, path) < 0)
		goto fail;
	for (int i = 0; i < nl; i++) {
		snprintf(path, sizeof(path), "%s/looks/%s.json", dir, L[i].name);
		if (!(f = wopen(path, tmp, sizeof(tmp))))
			goto fail;
		fprintf(f, "{\"look\": ");
		jstr(f, L[i].name);
		fprintf(f, ", \"targets\": ");
		jtargets(f, &L[i].t, "  ");
		fprintf(f, "}\n");
		if (wclose(f, tmp, path) < 0)
			goto fail;
	}
	for (int i = 0; i < ndeleted; i++) {	/* deleted here: the file too */
		snprintf(path, sizeof(path), "%s/looks/%.47s.json", dir, deleted[i]);
		unlink(path);
	}
	ndeleted = 0;
	snprintf(path, sizeof(path), "%s/show.json", dir);
	if (!(f = wopen(path, tmp, sizeof(tmp))))
		goto fail;
	fprintf(f, "{\"show\": ");
	jstr(f, name);
	fprintf(f, ", \"format\": 2, \"scenes\": [");
	for (int s = 0; s < ns; s++) {
		fprintf(f, "%s\n {\"name\": ", s ? "," : "");
		jstr(f, S[s].name);
		fprintf(f, ", \"loop\": %s, \"cues\": [", S[s].loop ? "true" : "false");
		for (int i = 0; i < S[s].n; i++) {
			const cue_t *c = &S[s].c[i];

			fprintf(f, "%s\n  {\"n\": ", i ? "," : "");
			jfloat(f, c->num);
			fprintf(f, ", \"name\": ");
			jstr(f, c->name);
			fprintf(f, ", \"kind\": \"%s\", \"looks\": [", kind_names[c->kind]);
			for (int k = 0; k < c->nlooks; k++) {
				if (k)
					fputs(", ", f);
				jstr(f, c->looks[k]);
			}
			fprintf(f, "], \"fade\": ");
			jfloat(f, c->fade);
			fprintf(f, ", \"curve\": ");
			jstr(f, c->curve);
			fprintf(f, ", \"transition\": ");
			jstr(f, c->mode[0] ? c->mode : tnames[mode_of(c->mode, c->fade)]);
			fprintf(f, ", \"follow\": ");
			jfloat(f, c->follow);
			fprintf(f, ", \"follow_end\": %s", c->follow_end ? "true" : "false");
			fprintf(f, ",\n   \"set\": ");
			jtargets(f, &c->set, "    ");
			fprintf(f, "}");
		}
		fprintf(f, "]}");
	}
	fprintf(f, "\n]}\n");
	if (wclose(f, tmp, path) < 0)
		goto fail;
	return 0;
fail:
	snprintf(err, errcap, "cannot write %s: %s", path, strerror(errno));
	return -1;
}

/* a small JSON reader: values into a tree */
enum { J_NULL, J_BOOL, J_NUM, J_STR, J_ARR, J_OBJ };
typedef struct jv {
	int         type, isint;
	double      num;
	char       *str;
	struct jv  *kid;	/* J_ARR / J_OBJ: n children */
	char      **key;	/* J_OBJ */
	int         n;
} jv;

static const char *jp;

static void jfree(jv *v)
{
	for (int i = 0; i < v->n; i++) {
		jfree(&v->kid[i]);
		if (v->key)
			free(v->key[i]);
	}
	free(v->kid);
	free(v->key);
	free(v->str);
}

static void jws(void)
{
	while (*jp == ' ' || *jp == '\t' || *jp == '\n' || *jp == '\r')
		jp++;
}

static char *jparse_str(void)
{
	size_t cap = 64, n = 0;
	char *b = malloc(cap);

	if (!b || *jp != '"')
		goto bad;
	jp++;
	while (*jp && *jp != '"') {
		unsigned c = (unsigned char)*jp++;

		if (c == '\\') {
			c = (unsigned char)*jp++;
			if (c == 'n') c = '\n';
			else if (c == 't') c = '\t';
			else if (c == 'r') c = '\r';
			else if (c == 'b') c = '\b';
			else if (c == 'f') c = '\f';
			else if (c == 'u') {
				unsigned u = 0;

				for (int k = 0; k < 4; k++) {
					char h = *jp++;
					u = u * 16 + (unsigned)(h >= 'a' ? h - 'a' + 10 : h >= 'A' ? h - 'A' + 10 : h - '0');
				}
				if (n + 4 >= cap && !(b = realloc(b, cap *= 2)))
					return NULL;
				if (u < 0x80) {
					b[n++] = (char)u;
				} else if (u < 0x800) {
					b[n++] = (char)(0xC0 | (u >> 6));
					b[n++] = (char)(0x80 | (u & 0x3F));
				} else {
					b[n++] = (char)(0xE0 | (u >> 12));
					b[n++] = (char)(0x80 | ((u >> 6) & 0x3F));
					b[n++] = (char)(0x80 | (u & 0x3F));
				}
				continue;
			}
		}
		if (n + 1 >= cap && !(b = realloc(b, cap *= 2)))
			return NULL;
		b[n++] = (char)c;
	}
	if (*jp != '"')
		goto bad;
	jp++;
	b[n] = 0;
	return b;
bad:
	free(b);
	return NULL;
}

static int jparse(jv *v)
{
	*v = (jv){ 0 };
	jws();
	if (*jp == '"') {
		v->type = J_STR;
		return (v->str = jparse_str()) ? 0 : -1;
	}
	if (*jp == '[' || *jp == '{') {
		int obj = *jp++ == '{';
		int cap = 0;

		v->type = obj ? J_OBJ : J_ARR;
		jws();
		if (*jp == (obj ? '}' : ']')) {
			jp++;
			return 0;
		}
		for (;;) {
			char *k = NULL;

			jws();
			if (obj) {
				if (!(k = jparse_str()))
					return -1;
				jws();
				if (*jp++ != ':') {
					free(k);
					return -1;
				}
			}
			if (v->n == cap) {
				cap = cap ? 2 * cap : 8;
				v->kid = realloc(v->kid, sizeof(jv) * (size_t)cap);
				if (obj)
					v->key = realloc(v->key, sizeof(char *) * (size_t)cap);
				if (!v->kid || (obj && !v->key)) {
					free(k);
					return -1;
				}
			}
			if (obj)
				v->key[v->n] = k;
			if (jparse(&v->kid[v->n++]) < 0)
				return -1;
			jws();
			if (*jp == ',') {
				jp++;
				continue;
			}
			if (*jp++ != (obj ? '}' : ']'))
				return -1;
			return 0;
		}
	}
	if (!strncmp(jp, "true", 4) || !strncmp(jp, "false", 5)) {
		v->type = J_BOOL;
		v->num = *jp == 't';
		v->isint = 1;
		jp += *jp == 't' ? 4 : 5;
		return 0;
	}
	if (!strncmp(jp, "null", 4)) {
		jp += 4;
		return 0;
	}
	char *end;
	const char *start = jp;

	v->num = strtod(jp, &end);
	if (end == jp)
		return -1;
	v->type = J_NUM;
	v->isint = !memchr(start, '.', (size_t)(end - start)) && !memchr(start, 'e', (size_t)(end - start)) &&
		   !memchr(start, 'E', (size_t)(end - start));
	jp = end;
	return 0;
}

static const jv *jget(const jv *o, const char *k)
{
	for (int i = 0; o->type == J_OBJ && i < o->n; i++)
		if (!strcmp(o->key[i], k))
			return &o->kid[i];
	return NULL;
}

static char *slurp(const char *path, char *err, size_t errcap)
{
	FILE *f = fopen(path, "r");
	long len;
	char *buf;

	if (!f) {
		snprintf(err, errcap, "%s: %s", path, strerror(errno));
		return NULL;
	}
	fseek(f, 0, SEEK_END);
	len = ftell(f);
	fseek(f, 0, SEEK_SET);
	buf = len >= 0 && len < 64L * 1024 * 1024 ? malloc((size_t)len + 1) : NULL;
	if (!buf || fread(buf, 1, (size_t)len, f) != (size_t)len) {
		fclose(f);
		free(buf);
		snprintf(err, errcap, "cannot read %s", path);
		return NULL;
	}
	fclose(f);
	buf[len] = 0;
	known_set(path);
	return buf;
}

/* {"/address": value | [values], ...} -> targets */
static void read_targets(const jv *o, st_list *out)
{
	for (int t = 0; o && o->type == J_OBJ && t < o->n; t++) {
		const jv *v = &o->kid[t];
		const jv *one[1] = { v };
		const jv *const *vals = one;
		int nv = 1;
		dz_msg m = { .path = o->key[t] };

		if (v->type == J_ARR) {
			nv = v->n;
			vals = NULL;
		}
		for (int k = 0; k < nv && m.n < DZ_OSC_MAX_ARGS; k++) {
			const jv *a = vals ? vals[k] : &v->kid[k];

			if (a->type == J_STR)
				m.a[m.n++] = (dz_arg){ .type = 's', .s = a->str };
			else if (a->type == J_NUM && !a->isint)
				m.a[m.n++] = (dz_arg){ .type = 'f', .f = (float)a->num };
			else if (a->type == J_NUM || a->type == J_BOOL)
				m.a[m.n++] = (dz_arg){ .type = 'i', .i = (int32_t)a->num };
		}
		st_list_put_msg(out, o->key[t], &m);
	}
}

/* parse a file; root must be an object */
static int read_json(const char *path, jv *root, char **buf, char *err, size_t errcap)
{
	*buf = slurp(path, err, errcap);
	if (!*buf)
		return -1;
	jp = *buf;
	if (jparse(root) < 0 || root->type != J_OBJ) {
		snprintf(err, errcap, "%s: bad JSON near byte %ld", path, (long)(jp - *buf));
		jfree(root);
		free(*buf);
		return -1;
	}
	return 0;
}

static int show_read(const char *name, char *err, size_t errcap)
{
	char dir[200], path[260];
	jv root;
	char *buf;

	snprintf(dir, sizeof(dir), "%s/%s", show_dir(), name);
	snprintf(path, sizeof(path), "%s/show.json", dir);
	if (access(path, R_OK) != 0) {
		snprintf(err, errcap, "%s: %s", path, strerror(errno));
		return -1;
	}
	show_clear();
	snprintf(show_name, sizeof(show_name), "%s", name);
	/* baseline */
	snprintf(path, sizeof(path), "%s/baseline.json", dir);
	if (access(path, R_OK) == 0 && read_json(path, &root, &buf, err, errcap) == 0) {
		read_targets(jget(&root, "targets"), &baseline);
		jfree(&root);
		free(buf);
	}
	/* every look file in looks/ (also hand-made ones) */
	snprintf(path, sizeof(path), "%s/looks", dir);
	DIR *d = opendir(path);
	struct dirent *e;

	while (d && (e = readdir(d))) {
		size_t l = strlen(e->d_name);
		char nm[48];

		if (l <= 5 || strcmp(e->d_name + l - 5, ".json") || l - 5 >= sizeof(nm))
			continue;
		snprintf(nm, sizeof(nm), "%.*s", (int)(l - 5), e->d_name);
		snprintf(path, sizeof(path), "%s/looks/%s", dir, e->d_name);
		if (!name_ok(nm) || read_json(path, &root, &buf, err, errcap) < 0)
			continue;			/* /show/check reports a missing look */
		look_t *lk = look_new(nm);

		if (lk)
			read_targets(jget(&root, "targets"), &lk->t);
		jfree(&root);
		free(buf);
	}
	if (d)
		closedir(d);
	/* the playlist */
	snprintf(path, sizeof(path), "%s/show.json", dir);
	if (read_json(path, &root, &buf, err, errcap) < 0)
		return -1;
	const jv *scenes = jget(&root, "scenes");

	for (int s = 0; scenes && scenes->type == J_ARR && s < scenes->n; s++) {
		const jv *sc = &scenes->kid[s], *nm = jget(sc, "name"), *cues = jget(sc, "cues");
		int si = scene_new(nm && nm->type == J_STR ? nm->str : "scene");
		const jv *lp = jget(sc, "loop");

		if (si >= 0)
			S[si].loop = lp && (lp->type == J_BOOL || lp->type == J_NUM) && lp->num != 0;

		for (int i = 0; si >= 0 && cues && cues->type == J_ARR && i < cues->n; i++) {
			const jv *cj = &cues->kid[i], *v;
			double num = (v = jget(cj, "n")) && v->type == J_NUM ? v->num : (double)(i + 1);
			cue_t *c = cue_insert(si, num);

			if (!c)
				continue;			/* a duplicate number: /show/check */
			if ((v = jget(cj, "name")) && v->type == J_STR)
				snprintf(c->name, sizeof(c->name), "%s", v->str);
			c->kind = (v = jget(cj, "kind")) && v->type == J_STR && !strcmp(v->str, "delta") ? K_DELTA : K_KEY;
			if ((v = jget(cj, "fade")) && v->type == J_NUM)
				c->fade = (float)v->num;
			if ((v = jget(cj, "curve")) && v->type == J_STR)
				snprintf(c->curve, sizeof(c->curve), "%s", v->str);
			if ((v = jget(cj, "transition")) && v->type == J_STR)
				snprintf(c->mode, sizeof(c->mode), "%s", v->str);
			if ((v = jget(cj, "follow")) && v->type == J_NUM && v->num > 0)
				c->follow = (float)v->num;
			if ((v = jget(cj, "follow_end")) && (v->type == J_BOOL || v->type == J_NUM))
				c->follow_end = v->num != 0;
			if ((v = jget(cj, "looks")) && v->type == J_ARR)
				for (int k = 0; k < v->n && c->nlooks < MAXLOOKS; k++)
					if (v->kid[k].type == J_STR)
						snprintf(c->looks[c->nlooks++], sizeof(c->looks[0]), "%s", v->kid[k].str);
			read_targets(jget(cj, "set"), &c->set);
		}
	}
	jfree(&root);
	free(buf);
	return 0;
}

/* ---- /show/check ---- */

static int check_count;

static void issue(const char *where, const char *fmt, ...)
{
	char what[300];
	va_list ap;

	va_start(ap, fmt);
	vsnprintf(what, sizeof(what), fmt, ap);
	va_end(ap);
	dzd_reply("/show/issue", "ss", where, what);
	check_count++;
}

/* targets that a dump lists only sometimes (not playing, not used yet) */
static int known_sometimes(const char *a)
{
	int x;
	char op[40];

	if (sscanf(a, "/movie/%d/%39s", &x, op) == 2 &&
	    (!strcmp(op, "mosh") || !strcmp(op, "bloom") || !strcmp(op, "corrupt") || !strcmp(op, "pause") ||
	     !strncmp(op, "vf/", 3) || !strncmp(op, "af/", 3)))
		return 1;
	if (sscanf(a, "/dds/%d/%39s", &x, op) == 2 && (!strncmp(op, "step/", 5) || !strcmp(op, "awg")))
		return 1;
	if (sscanf(a, "/ascii/%d/%39s", &x, op) == 2)
		return 1;
	if (sscanf(a, "/lfo/%d/%39s", &x, op) == 2 && !strcmp(op, "seq"))
		return 1;
	if (!strncmp(a, "/audio/out/", 11))
		return 1;
	if (sscanf(a, "/disp/%d/%39s", &x, op) == 2 && !strcmp(op, "source"))
		return 1;			/* absent while a display shows no slot */
	return 0;
}

static void check_list(const char *where, const st_list *l, const st_list *now)
{
	for (int t = 0; t < l->n; t++) {
		dz_msg m, o;
		int j = st_list_find(now, l->t[t].key);

		if (dz_osc_parse(l->t[t].msg, l->t[t].len, &m) < 0)
			continue;
		if (j < 0) {
			if (!known_sometimes(m.path))
				issue(where, "unknown address %s", m.path);
		} else if (dz_osc_parse(now->t[j].msg, now->t[j].len, &o) == 0) {
			int same = o.n == m.n;
			char want[40] = "", got[40] = "";

			for (int k = 0; k < o.n && k < 39; k++)
				want[k] = o.a[k].type;
			for (int k = 0; k < m.n && k < 39; k++)
				got[k] = m.a[k].type;
			same = same && !strcmp(want, got);
			if (!same && known_sometimes(m.path) && strstr(m.path, "/source"))
				same = 1;		/* show <slot> | capture | anim | seq ...: any */
			if (!same)
				issue(where, "%s: arguments %s, expected %s (1 = int, 1.0 = float)", m.path,
				      got[0] ? got : "none", want[0] ? want : "none");
		}
		/* the files it names */
		size_t pl = strlen(m.path);
		const char *dir = pl > 5 && !strcmp(m.path + pl - 5, "/file") ?
				  (!strncmp(m.path, "/movie/", 7) ? DZ_MOVIE_DIR :
				   !strncmp(m.path, "/img/", 5) ? DZ_IMG_DIR : DZ_AUDIO_DIR) : NULL;
		if (dir && m.n >= 1 && m.a[0].type == 's' && m.a[0].s[0]) {
			char p[300];

			snprintf(p, sizeof(p), "%s/%s", dir, m.a[0].s);
			if (access(p, R_OK) != 0)
				issue(where, "%s: no file %s", m.path, p);
		}
	}
}

static void check_show(void)
{
	st_list now = { 0 };
	char where[120];

	check_count = 0;
	st_list_dump(&now);
	check_list("baseline", &baseline, &now);
	for (int i = 0; i < nl; i++) {
		snprintf(where, sizeof(where), "look %s", L[i].name);
		check_list(where, &L[i].t, &now);
	}
	for (int s = 0; s < ns; s++) {
		if (S[s].n && S[s].c[0].kind != K_KEY) {
			snprintf(where, sizeof(where), "scene %s", S[s].name);
			issue(where, "the first cue (%g) is a delta: it must be a keyframe", S[s].c[0].num);
		}
		for (int i = 0; i < S[s].n; i++) {
			const cue_t *c = &S[s].c[i];

			snprintf(where, sizeof(where), "%s cue %g", S[s].name, c->num);
			if (c->kind == K_KEY && baseline.n == 0)
				issue(where, "a keyframe but no baseline (/show/baseline)");
			for (int k = 0; k < c->nlooks; k++)
				if (!look_find(c->looks[k]))
					issue(where, "no look %s", c->looks[k]);
			check_list(where, &c->set, &now);
		}
	}
	st_list_free(&now);
	dzd_reply("/show/check/end", "i", check_count);
}

/* ---- OSC ---- */

int cue_dispatch(const dz_msg *m)
{
	const char *p = m->path;
	const dz_arg *a = m->a;
	int n = m->n;
	char err[400] = "";

	if (strncmp(p, "/cue/", 5) && strncmp(p, "/scene/", 7) && strncmp(p, "/show/", 6) &&
	    strncmp(p, "/look/", 6))
		return 0;

	if (!strcmp(p, "/cue/status")) {
		status();
	} else if (!strcmp(p, "/cue/record")) {
		int s = n >= 1 ? scene_of(&a[0]) : -1, kind;

		if (n < 3 || a[2].type != 's' || (strcmp(a[2].s, "keyframe") && strcmp(a[2].s, "delta")) ||
		    a[1].type == 's' || num_arg(&a[1]) <= 0) {
			dzd_reply("/error", "ss", "/cue/record <scene> <num > 0> keyframe|delta [name]", p);
			return 1;
		}
		kind = a[2].s[0] == 'd' ? K_DELTA : K_KEY;
		if (s < 0 && kind == K_DELTA) {		/* checks first: a refusal changes nothing */
			dzd_reply("/error", "ss", "the first cue of a scene must be a keyframe", p);
			return 1;
		}
		if (s < 0 && a[0].type == 's')
			s = scene_new(a[0].s);
		if (s < 0) {
			dzd_reply("/error", "ss", "no such scene", p);
			return 1;
		}
		record(s, num_arg(&a[1]), kind, n >= 4 && a[3].type == 's' ? a[3].s : NULL, p);
	} else if (!strcmp(p, "/cue/go") || !strcmp(p, "/cue/get") || !strcmp(p, "/cue/resolve") ||
		   !strcmp(p, "/cue/delete") || !strcmp(p, "/cue/name") || !strcmp(p, "/cue/fade") ||
		   !strcmp(p, "/cue/look") || !strcmp(p, "/cue/move") || !strcmp(p, "/cue/follow") ||
		   !strcmp(p, "/cue/add")) {
		int s = n >= 1 ? scene_of(&a[0]) : -1, i = s >= 0 && n >= 2 ? cue_of(s, &a[1]) : -1;

		if (i < 0) {
			dzd_reply("/error", "ss", "no such scene / cue", p);
			return 1;
		}
		cue_t *c = &S[s].c[i];

		if (!strcmp(p, "/cue/go")) {
			go(s, i, m, 2);
		} else if (!strcmp(p, "/cue/follow") && n >= 3) {
			int end = a[2].type == 's' && !strcmp(a[2].s, "end");
			double v = end ? (n >= 4 && a[3].type != 's' ? num_of(&a[3]) : 0) :
				   a[2].type == 's' ? 0 : num_of(&a[2]);	/* "off" = 0 */

			c->follow = v > 0 ? (float)v : 0.0f;
			c->follow_end = end;
			if (s == cur_s && i == cur_c && !c->follow && !end)
				fol.on = 0;
			dzd_reply("/cue/follow", "sffi", S[s].name, (float)c->num, c->follow, c->follow_end);
		} else if (!strcmp(p, "/cue/add") && n >= 3 && a[2].type == 's' && a[2].s[0] == '/') {
			dz_msg t = { .path = a[2].s, .n = n - 3 };

			memcpy(t.a, &a[3], sizeof(dz_arg) * (size_t)t.n);
			if (st_list_put_msg(&c->set, a[2].s, &t) < 0) {
				dzd_reply("/error", "ss", "no memory", p);
				return 1;
			}
			dzd_reply("/cue/add", "sfi", S[s].name, (float)c->num, c->set.n);
		} else if (!strcmp(p, "/cue/get")) {
			reply_list("/cue/target", "/cue/end", &c->set);
		} else if (!strcmp(p, "/cue/resolve")) {
			st_list r = { 0 };

			resolve(s, i, &r);
			reply_list("/cue/target", "/cue/end", &r);
			st_list_free(&r);
		} else if (!strcmp(p, "/cue/delete")) {
			if (i == 0 && S[s].n > 1 && S[s].c[1].kind != K_KEY) {
				dzd_reply("/error", "ss", "the next cue is a delta: it would start the scene", p);
				return 1;
			}
			cue_free(c);
			memmove(c, c + 1, sizeof(cue_t) * (size_t)(S[s].n - i - 1));
			S[s].n--;
			if (cur_s == s && cur_c >= i)
				cur_c = cur_c > 0 ? cur_c - 1 : -1;
			dzd_reply("/cue/delete", "si", S[s].name, S[s].n);
		} else if (!strcmp(p, "/cue/name") && n >= 3 && a[2].type == 's') {
			snprintf(c->name, sizeof(c->name), "%s", a[2].s);
		} else if (!strcmp(p, "/cue/move") && n >= 3) {	/* a new number */
			double to = num_arg(&a[2]);
			cue_t tmp = *c;

			if (to <= 0 || cue_of(s, &a[2]) >= 0) {
				dzd_reply("/error", "ss", "the new number is taken (or <= 0)", p);
				return 1;
			}
			/* the scene must still start with a keyframe */
			int first = i == 0 ? 1 : 0;
			double next_first = S[s].n > 1 ? S[s].c[first].num : to;
			if ((tmp.kind != K_KEY && to < S[s].c[i == 0 ? 1 : 0].num) ||
			    (i == 0 && S[s].n > 1 && to > next_first && S[s].c[1].kind != K_KEY)) {
				dzd_reply("/error", "ss", "the scene would start with a delta", p);
				return 1;
			}
			memmove(c, c + 1, sizeof(cue_t) * (size_t)(S[s].n - i - 1));
			S[s].n--;
			cue_t *nc = cue_insert(s, to);

			if (nc) {
				*nc = tmp;
				nc->num = to;
			}
			cur_s = cur_c = -1;
			dzd_reply("/cue/move", "sf", S[s].name, (float)to);
		} else if (!strcmp(p, "/cue/fade") && n >= 3) {
			c->fade = a[2].type == 'f' ? a[2].f : (float)a[2].i;
			for (int j = 3; j < n; j++)
				if (a[j].type == 's' && (!strcmp(a[j].s, "smooth") || !strcmp(a[j].s, "linear")))
					snprintf(c->curve, sizeof(c->curve), "%s", a[j].s);
				else if (a[j].type == 's')
					snprintf(c->mode, sizeof(c->mode), "%s", a[j].s);
			dzd_reply("/cue/fade", "sffss", S[s].name, (float)c->num, c->fade, c->curve,
				  tnames[mode_of(c->mode, c->fade)]);
		} else if (!strcmp(p, "/cue/look") && n >= 3 && a[2].type == 's') {
			const char *nm = n >= 4 && a[3].type == 's' ? a[3].s : "";

			if (!strcmp(a[2].s, "clear")) {
				c->nlooks = 0;
			} else if (!strcmp(a[2].s, "add") && look_find(nm) && c->nlooks < MAXLOOKS) {
				/* its own targets with exactly the look's value are now
				 * redundant: dropped, or they would hide later look
				 * updates (the set applies after the looks). A different
				 * value stays: a deliberate override. */
				const look_t *lk = look_find(nm);
				st_list keep = { 0 };
				int dropped = 0;

				snprintf(c->looks[c->nlooks++], sizeof(c->looks[0]), "%s", nm);
				for (int t = 0; t < c->set.n; t++) {
					int j = st_list_find(&lk->t, c->set.t[t].key);

					if (j >= 0 && st_same(&c->set, t, &lk->t, j))
						dropped++;
					else
						st_list_put(&keep, c->set.t[t].key, c->set.t[t].msg, c->set.t[t].len);
				}
				st_list_free(&c->set);
				c->set = keep;
				dzd_reply("/cue/look", "sfii", S[s].name, (float)c->num, c->nlooks, dropped);
				return 1;
			} else if (!strcmp(a[2].s, "remove")) {
				for (int k = 0; k < c->nlooks; k++)
					if (!strcmp(c->looks[k], nm)) {
						memmove(c->looks[k], c->looks[k + 1], sizeof(c->looks[0]) * (size_t)(c->nlooks - k - 1));
						c->nlooks--;
						break;
					}
			} else {
				dzd_reply("/error", "ss", "/cue/look <scene> <num> add|remove <look> | clear (the look must exist)", p);
				return 1;
			}
			dzd_reply("/cue/look", "sfi", S[s].name, (float)c->num, c->nlooks);
		} else {
			dzd_reply("/error", "ss", "bad arguments (see sw/debazd/cue.c)", p);
		}
	} else if (!strcmp(p, "/cue/next")) {
		next(m);
	} else if (!strcmp(p, "/cue/stop")) {
		stop_all();
		fol.on = 0;
		dzd_reply("/cue/stop", "i", 1);
	} else if (!strcmp(p, "/cue/back")) {
		if (cur_s < 0)
			dzd_reply("/error", "ss", "no cue yet", p);
		else if (cur_c > 0)
			go(cur_s, cur_c - 1, m, 0);
		else if (cur_s > 0 && S[cur_s - 1].n > 0)
			go(cur_s - 1, S[cur_s - 1].n - 1, m, 0);
		else
			dzd_reply("/error", "ss", "no cue before", p);
	} else if (!strcmp(p, "/cue/list")) {
		int s = n >= 1 ? scene_of(&a[0]) : cur_s;

		if (s < 0) {
			dzd_reply("/error", "ss", "no such scene", p);
			return 1;
		}
		for (int i = 0; i < S[s].n; i++) {
			const cue_t *c = &S[s].c[i];
			char lk[MAXLOOKS * 50] = "";

			for (int k = 0; k < c->nlooks; k++)
				snprintf(lk + strlen(lk), sizeof(lk) - strlen(lk), "%s%s", k ? "," : "", c->looks[k]);
			dzd_reply("/cue", "fssifsssfi", (float)c->num, c->name, kind_names[c->kind], c->set.n, c->fade,
				  c->curve, tnames[mode_of(c->mode, c->fade)], lk, c->follow, c->follow_end);
		}
		dzd_reply("/cue/end", "i", S[s].n);
	} else if (!strcmp(p, "/look/save") && n >= 1 && a[0].type == 's') {
		look_t *lk;

		if (!name_ok(a[0].s) || look_find(a[0].s)) {
			dzd_reply("/error", "ss", "look name: A-Z a-z 0-9 . _ -, and new (/look/update changes one)", p);
			return 1;
		}
		lk = look_new(a[0].s);
		if (lk)
			changes_now(&lk->t);
		dzd_reply("/look/save", "si", a[0].s, lk ? lk->t.n : 0);
	} else if (!strcmp(p, "/look/update") && n >= 1 && a[0].type == 's') {
		look_t *lk = look_find(a[0].s);
		st_list now = { 0 };

		if (!lk) {
			dzd_reply("/error", "ss", "no such look", p);
			return 1;
		}
		st_list_dump(&now);
		for (int t = 0; t < lk->t.n; t++) {	/* its targets: the values now */
			int j = st_list_find(&now, lk->t.t[t].key);

			if (j >= 0)
				st_list_put(&lk->t, now.t[j].key, now.t[j].msg, now.t[j].len);
		}
		if (n >= 2 && a[1].type == 's' && !strcmp(a[1].s, "add")) {
			st_list ch = { 0 };

			changes_now(&ch);
			put_all(&lk->t, &ch);
			st_list_free(&ch);
		}
		st_list_free(&now);
		dzd_reply("/look/update", "si", lk->name, lk->t.n);
	} else if (!strcmp(p, "/look/apply") && n >= 1 && a[0].type == 's') {
		look_t *lk = look_find(a[0].s);

		if (!lk) {
			dzd_reply("/error", "ss", "no such look", p);
			return 1;
		}
		int k = apply_diff(&lk->t, tparam_of(NULL, m, 1));
		dzd_reply("/look/apply", "si", lk->name, k);
	} else if (!strcmp(p, "/look/delete") && n >= 1 && a[0].type == 's') {
		look_t *lk = look_find(a[0].s);
		int uses = lk ? look_uses(lk->name) : 0;

		if (!lk || (uses && !(n >= 2 && a[1].type == 's' && !strcmp(a[1].s, "force")))) {
			dzd_reply("/error", "ss", lk ? "the look is used by cues: /look/delete <name> force" : "no such look", p);
			return 1;
		}
		if (ndeleted < 32)
			snprintf(deleted[ndeleted++], sizeof(deleted[0]), "%s", lk->name);
		st_list_free(&lk->t);
		memmove(lk, lk + 1, sizeof(look_t) * (size_t)(nl - (lk - L) - 1));
		nl--;
		dzd_reply("/look/delete", "si", a[0].s, uses);
	} else if (!strcmp(p, "/look/list")) {
		for (int i = 0; i < nl; i++)
			dzd_reply("/look", "sii", L[i].name, L[i].t.n, look_uses(L[i].name));
		dzd_reply("/look/end", "i", nl);
	} else if (!strcmp(p, "/look/get") && n >= 1 && a[0].type == 's') {
		look_t *lk = look_find(a[0].s);

		if (!lk) {
			dzd_reply("/error", "ss", "no such look", p);
			return 1;
		}
		reply_list("/look/target", "/look/end", &lk->t);
	} else if (!strcmp(p, "/cue/put")) {
		int s = n >= 1 ? scene_of(&a[0]) : -1, kind, i = -1;
		double num = n >= 2 && a[1].type != 's' ? num_arg(&a[1]) : 0;
		cue_t *c;

		if (n < 3 || a[2].type != 's' || (strcmp(a[2].s, "keyframe") && strcmp(a[2].s, "delta")) || num <= 0) {
			dzd_reply("/error", "ss", "/cue/put <scene> <num > 0> keyframe|delta [name]", p);
			return 1;
		}
		kind = a[2].s[0] == 'd' ? K_DELTA : K_KEY;
		if (s < 0 && a[0].type == 's' && kind == K_KEY)
			s = scene_new(a[0].s);
		for (int k = 0; s >= 0 && k < S[s].n; k++)
			if (num_eq(S[s].c[k].num, num))
				i = k;
		if (s < 0 || (kind == K_DELTA && (i == 0 || (i < 0 && (S[s].n == 0 || num < S[s].c[0].num))))) {
			dzd_reply("/error", "ss", s < 0 ? "no such scene" : "the first cue of a scene must be a keyframe", p);
			return 1;
		}
		if (i >= 0) {				/* the same number: empty it */
			c = &S[s].c[i];
			st_list_free(&c->set);
			c->nlooks = 0;
		} else if (!(c = cue_insert(s, num))) {
			dzd_reply("/error", "ss", "no memory", p);
			return 1;
		}
		c->kind = kind;
		c->fade = 0;
		c->follow = 0;
		c->follow_end = 0;
		c->mode[0] = 0;
		snprintf(c->curve, sizeof(c->curve), "linear");
		if (n >= 4 && a[3].type == 's' && a[3].s[0])
			snprintf(c->name, sizeof(c->name), "%s", a[3].s);
		else
			snprintf(c->name, sizeof(c->name), "cue %g", num);
		dzd_reply("/cue/put", "sfs", S[s].name, (float)num, kind_names[kind]);
	} else if (!strcmp(p, "/scene/loop") && n >= 1) {
		int s = scene_of(&a[0]);

		if (s < 0) {
			dzd_reply("/error", "ss", "no such scene", p);
			return 1;
		}
		if (n >= 2 && a[1].type != 's')
			S[s].loop = num_of(&a[1]) != 0;
		dzd_reply("/scene/loop", "si", S[s].name, S[s].loop);
	} else if (!strcmp(p, "/scene/add") && n >= 1 && a[0].type == 's') {
		if (scene_of(&a[0]) < 0)
			scene_new(a[0].s);
		dzd_reply("/scene/add", "si", a[0].s, ns);
	} else if (!strcmp(p, "/scene/delete") && n >= 1) {
		int s = scene_of(&a[0]);

		if (s < 0) {
			dzd_reply("/error", "ss", "no such scene", p);
			return 1;
		}
		for (int j = 0; j < S[s].n; j++)
			cue_free(&S[s].c[j]);
		free(S[s].c);
		memmove(&S[s], &S[s + 1], sizeof(scene_t) * (size_t)(ns - s - 1));
		ns--;
		if (cur_s == s)
			cur_s = cur_c = -1;
		else if (cur_s > s)
			cur_s--;
		dzd_reply("/scene/delete", "i", ns);
	} else if (!strcmp(p, "/scene/rename") && n >= 2 && a[1].type == 's') {
		int s = scene_of(&a[0]);

		if (s >= 0)
			snprintf(S[s].name, sizeof(S[s].name), "%s", a[1].s);
	} else if (!strcmp(p, "/scene/list")) {
		for (int s = 0; s < ns; s++)
			dzd_reply("/scene", "isii", s + 1, S[s].name, S[s].n, S[s].loop);
		dzd_reply("/scene/end", "i", ns);
	} else if (!strcmp(p, "/show/new")) {
		const char *nm = n >= 1 && a[0].type == 's' ? a[0].s : "show";

		if (!name_ok(nm)) {
			dzd_reply("/error", "ss", "show name: A-Z a-z 0-9 . _ -", p);
			return 1;
		}
		show_clear();
		snprintf(show_name, sizeof(show_name), "%s", nm);
		status();
	} else if (!strcmp(p, "/show/baseline")) {
		st_list_dump(&baseline);
		dzd_log("cue: baseline taken (%d targets)\n", baseline.n);
		dzd_reply("/show/baseline", "i", baseline.n);
	} else if (!strcmp(p, "/show/save")) {
		const char *nm = n >= 1 && a[0].type == 's' && strcmp(a[0].s, "force") ? a[0].s : show_name;
		int force = n >= 1 && a[n - 1].type == 's' && !strcmp(a[n - 1].s, "force");

		if (!name_ok(nm)) {
			dzd_reply("/error", "ss", "show name: A-Z a-z 0-9 . _ -", p);
			return 1;
		}
		if (strcmp(nm, show_name))
			nknown = 0;			/* another folder: nothing read there */
		if (show_write(nm, force, err, sizeof(err)) < 0) {
			dzd_reply("/error", "ss", err, p);
			return 1;
		}
		if (nm != show_name)		/* never onto itself (undefined in C) */
			snprintf(show_name, sizeof(show_name), "%s", nm);
		dzd_log("cue: show %s saved\n", show_name);
		dzd_reply("/show/save", "s", nm);
	} else if ((!strcmp(p, "/show/load") && n >= 1 && a[0].type == 's') || !strcmp(p, "/show/reload")) {
		char nm[64];

		snprintf(nm, sizeof(nm), "%s", !strcmp(p, "/show/reload") ? show_name : a[0].s);
		if (!name_ok(nm) || show_read(nm, err, sizeof(err)) < 0) {
			dzd_reply("/error", "ss", err[0] ? err : "bad show name", p);
			return 1;
		}
		dzd_log("cue: show %s loaded (%d scenes, %d looks)\n", show_name, ns, nl);
		status();
	} else if (!strcmp(p, "/show/check")) {
		check_show();
	} else if (!strcmp(p, "/show/list")) {
		DIR *d = opendir(show_dir());
		struct dirent *e;
		int count = 0;

		while (d && (e = readdir(d))) {
			char sj[400];

			snprintf(sj, sizeof(sj), "%s/%s/show.json", show_dir(), e->d_name);
			if (e->d_name[0] != '.' && access(sj, R_OK) == 0) {
				dzd_reply("/show", "s", e->d_name);
				count++;
			}
		}
		if (d)
			closedir(d);
		dzd_reply("/show/end", "i", count);
	} else {
		dzd_reply("/error", "ss", "bad arguments (see sw/debazd/cue.c)", p);
	}
	return 1;
}

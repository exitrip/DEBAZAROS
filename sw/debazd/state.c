/*
 * state.c - the state model of the cue system (2026-11-01; ROADMAP.md
 * section 15, step 2). The whole state of debazd as a flat list of targets:
 * one OSC message each (the message that sets it), in a fixed order:
 *
 *   system     /capture/auto, /audio/fs/auto, /audio/rx/auto
 *   media      /movie/<s>/vf, af, trails, ghost, then /movie/<s>/file, then
 *              (while it plays) mosh, bloom, corrupt, pause; audio sources
 *              and file players (key /audio/out/<n>/file: play or stop)
 *   displays   /disp/<d>/show or seq, blank, crop/x, crop/y   (disp.c)
 *   ascii      /ascii/<d>/... settings, then run <src> or run -1 (ascii.c)
 *   dds        the step tables and the AWG, if debazd wrote them (dds.c)
 *   lfo        /lfo/<n>/... settings, then on                 (lfo.c)
 *   pwm        /fan/<n>/pwm hz duty invert, or 0 (also the software PWM)
 *   fx         /fx/wrap
 *   fields     register fields by name: one canonical field per bit range
 *              (the widest; /hdmi/1/gain/rgb, not /r /g /b), no read-only
 *              fields, no action or measured fields (skip list below)
 *
 * Dispatching the messages of a dump in this order restores the state (the
 * fields come last: they also hold what the higher-level settings wrote).
 * The /fx/hue and /fx/key settings are not targets: they only compute
 * mixer fields, which are.
 *
 *   /state                 -> /state/target s:key s:address args..., one per
 *                             target, then /state/end i:count
 *   /state/snap [s:name]   store the state now in memory (8 names; default
 *                          "a") -> /state/snap s:name i:targets
 *   /state/recall [s:name] dispatch it in order -> /state/recall s:name i:n
 *   /state/diff [s:name]   -> /state/target ... for each target that differs
 *                             from the snapshot now, /state/gone s:key for a
 *                             snapshot target the state has no more, then
 *                             /state/end i:count
 * Step 3 (cues) builds on the same dump: a keyframe = the dump, a delta =
 * the targets that differ from the resolved state of the cue before.
 */
#include "debazd.h"
#include "dz_draw.h"
#include "dz_fields.h"
#include "dz_hw.h"
#include "dz_osc.h"

#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

/* ---- emit ---- */

void st_emit_args(state_cb cb, void *ctx, const char *key, const char *path,
		  const dz_arg *a, int n)
{
	dz_msg m = { .path = path, .n = n > DZ_OSC_MAX_ARGS ? DZ_OSC_MAX_ARGS : n };

	for (int i = 0; i < m.n; i++)
		m.a[i] = a[i];
	cb(key ? key : path, &m, ctx);
}

void st_emit(state_cb cb, void *ctx, const char *key, const char *path, const char *tags, ...)
{
	dz_arg a[DZ_OSC_MAX_ARGS];
	int n = 0;
	va_list ap;

	va_start(ap, tags);
	for (const char *t = tags; *t && n < DZ_OSC_MAX_ARGS; t++, n++) {
		a[n] = (dz_arg){ .type = *t };
		if (*t == 'i')
			a[n].i = va_arg(ap, int);
		else if (*t == 'f')
			a[n].f = (float)va_arg(ap, double);
		else
			a[n].s = va_arg(ap, const char *);
	}
	va_end(ap);
	st_emit_args(cb, ctx, key, path, a, n);
}

/* ---- groups that live in sw/lib (dz_draw, dz_fields) ---- */

static void movie_state(state_cb cb, void *ctx)
{
	char p[48];

	for (int s = 0; s < DZ_SLOTS; s++) {
		char name[100];
		float fps, tr, gh, co;
		int audio, mo, bl, pa, run;

		run = dz_draw_movie_info(s, name, sizeof(name), &fps, &audio);
		dz_draw_movie_memfx_get(s, &tr, &gh);
		snprintf(p, sizeof(p), "/movie/%d/vf", s);
		st_emit(cb, ctx, NULL, p, "s", dz_draw_movie_vf(s));
		snprintf(p, sizeof(p), "/movie/%d/af", s);
		st_emit(cb, ctx, NULL, p, "s", dz_draw_movie_af(s));
		snprintf(p, sizeof(p), "/movie/%d/trails", s);
		st_emit(cb, ctx, NULL, p, "f", (double)tr);
		snprintf(p, sizeof(p), "/movie/%d/ghost", s);
		st_emit(cb, ctx, NULL, p, "f", (double)gh);
		snprintf(p, sizeof(p), "/movie/%d/file", s);
		st_emit(cb, ctx, NULL, p, "sfi", run ? name : "", (double)fps, audio);
		if (!run)
			continue;
		dz_draw_movie_fx(s, &mo, &bl, &co, &pa);
		snprintf(p, sizeof(p), "/movie/%d/mosh", s);	/* hold states only */
		st_emit(cb, ctx, NULL, p, "i", mo < 0 ? -1 : 0);
		snprintf(p, sizeof(p), "/movie/%d/bloom", s);
		st_emit(cb, ctx, NULL, p, "i", bl < 0 ? -1 : 0);
		snprintf(p, sizeof(p), "/movie/%d/corrupt", s);
		st_emit(cb, ctx, NULL, p, "f", (double)co);
		snprintf(p, sizeof(p), "/movie/%d/pause", s);
		st_emit(cb, ctx, NULL, p, "i", pa ? 1 : 0);
	}
}

/* fields that a cue must never store or write: actions (a write does
 * something), counters, and what debazd measures and sets by itself */
static int field_skip(const dz_field *f)
{
	static const char *const prefix[] = { "/ev/", "/pcm/" };
	static const char *const exact[] = { "/audio/rx/clear", "/hdmi/2/hpd_low",
					     "/audio/tx/fs_inc", "/hdmi/0/sync_delay",
					     "/hdmi/1/sync_delay" };	/* calibration, not a look */

	if (f->flags & DZ_F_RO)
		return 1;
	if (f->unit == DZ_HZ)		/* the same bits as the raw PINC field */
		return 1;
	for (size_t i = 0; i < sizeof(prefix) / sizeof(prefix[0]); i++)
		if (!strncmp(f->path, prefix[i], strlen(prefix[i])))
			return 1;
	for (size_t i = 0; i < sizeof(exact) / sizeof(exact[0]); i++)
		if (!strcmp(f->path, exact[i]))
			return 1;
	return 0;
}

/* the canonical fields, in table order: per register the widest field
 * wins, a narrower one only for bits no wider field has (computed once) */
static int *canon, ncanon = -1;

static int width_desc(const void *x, const void *y)
{
	const dz_field *a = dz_field_at(*(const int *)x), *b = dz_field_at(*(const int *)y);

	return (int)b->width - (int)a->width;
}

static int index_asc(const void *x, const void *y)
{
	return *(const int *)x - *(const int *)y;
}

static void build_canon(void)
{
	int n = dz_fields_count(), k = 0;
	int *cand = malloc(sizeof(int) * (size_t)(n > 0 ? n : 1));

	canon = malloc(sizeof(int) * (size_t)(n > 0 ? n : 1));
	if (!cand || !canon) {
		free(cand);
		ncanon = 0;
		return;
	}
	for (int i = 0; i < n; i++)
		if (!field_skip(dz_field_at(i)))
			cand[k++] = i;
	qsort(cand, (size_t)k, sizeof(int), width_desc);
	ncanon = 0;
	for (int c = 0; c < k; c++) {
		const dz_field *f = dz_field_at(cand[c]);
		uint32_t m = dz_field_mask(f) << f->lo;
		int taken = 0;

		for (int j = 0; j < ncanon && !taken; j++) {
			const dz_field *g = dz_field_at(canon[j]);

			if (g->base == f->base && g->off == f->off && ((dz_field_mask(g) << g->lo) & m))
				taken = 1;
		}
		if (!taken)
			canon[ncanon++] = cand[c];
	}
	qsort(canon, (size_t)ncanon, sizeof(int), index_asc);	/* table order */
	free(cand);
}

static void fields_state(state_cb cb, void *ctx)
{
	if (ncanon < 0)
		build_canon();
	for (int j = 0; j < ncanon; j++) {
		const dz_field *f = dz_field_at(canon[j]);
		uint32_t raw;

		if (dz_field_read(f, &raw) < 0)
			continue;			/* not in this bitstream */
		if (f->unit == DZ_RGB)		/* one int would mean grey */
			st_emit(cb, ctx, NULL, f->path, "iii", (int)((raw >> DZ_LANE_R) & 255),
				(int)((raw >> DZ_LANE_G) & 255), (int)((raw >> DZ_LANE_B) & 255));
		else
			st_emit(cb, ctx, NULL, f->path, "i", (int)raw);
	}
}

void state_dump(state_cb cb, void *ctx)
{
	audio_state(cb, ctx);		/* automatic settings first */
	movie_state(cb, ctx);
	sound_state(cb, ctx);
	disp_state(cb, ctx);
	anim_state(cb, ctx);
	ascii_state(cb, ctx);
	dds_state(cb, ctx);
	react_state(cb, ctx);
	lfo_state(cb, ctx);
	pwm_state(cb, ctx);
	fx_state(cb, ctx);
	fields_state(cb, ctx);
}

/* ---- target lists (snapshots here, cues in cue.c) ---- */

void st_list_free(st_list *l)
{
	for (int i = 0; i < l->n; i++) {
		free(l->t[i].key);
		free(l->t[i].msg);
	}
	free(l->t);
	free(l->hix);
	*l = (st_list){ 0 };
}

/* the key lookup was a linear search: a dump, a diff and a resolve were
 * ~n^2/2 string compares each (477 targets: a cue go 30-58 ms on the A9,
 * 2026-11-01); now a hash index, rebuilt when it is half full */
static uint32_t key_hash(const char *k)
{
	uint32_t h = 2166136261u;		/* FNV-1a */

	while (*k)
		h = (h ^ (uint8_t)*k++) * 16777619u;
	return h;
}

static void hix_insert(st_list *l, int i)
{
	uint32_t m = (uint32_t)l->hcap - 1, h = key_hash(l->t[i].key) & m;

	while (l->hix[h] >= 0)
		h = (h + 1) & m;
	l->hix[h] = i;
}

static int hix_grow(st_list *l)
{
	int cap = l->hcap ? 2 * l->hcap : 1024;
	int *h = malloc(sizeof(int) * (size_t)cap);

	if (!h)
		return -1;
	free(l->hix);
	l->hix = h;
	l->hcap = cap;
	for (int i = 0; i < cap; i++)
		h[i] = -1;
	for (int i = 0; i < l->n; i++)
		hix_insert(l, i);
	return 0;
}

int st_list_find(const st_list *l, const char *key)
{
	if (!l->hcap)
		return -1;
	uint32_t m = (uint32_t)l->hcap - 1, h = key_hash(key) & m;

	for (; l->hix[h] >= 0; h = (h + 1) & m)
		if (!strcmp(l->t[l->hix[h]].key, key))
			return l->hix[h];
	return -1;
}

int st_list_put(st_list *l, const char *key, const uint8_t *msg, size_t len)
{
	int i = st_list_find(l, key);
	uint8_t *copy = malloc(len);

	if (!copy)
		return -1;
	memcpy(copy, msg, len);
	if (i >= 0) {				/* replace: the place stays */
		free(l->t[i].msg);
		l->t[i].msg = copy;
		l->t[i].len = len;
		return 0;
	}
	if (l->n == l->cap) {
		int cap = l->cap ? 2 * l->cap : 512;
		st_tgt *t = realloc(l->t, sizeof(st_tgt) * (size_t)cap);

		if (!t) {
			free(copy);
			return -1;
		}
		l->t = t;
		l->cap = cap;
	}
	l->t[l->n].key = strdup(key);
	if (!l->t[l->n].key) {
		free(copy);
		return -1;
	}
	l->t[l->n].msg = copy;
	l->t[l->n].len = len;
	l->n++;
	if (2 * l->n > l->hcap)
		hix_grow(l);			/* rebuilds with the new one */
	else
		hix_insert(l, l->n - 1);
	return 0;
}

int st_list_put_msg(st_list *l, const char *key, const dz_msg *m)
{
	static uint8_t buf[DZ_OSC_MAX_PKT];
	size_t len = dz_osc_build_args(buf, sizeof(buf), m->path, m->a, m->n);

	return len ? st_list_put(l, key, buf, len) : -1;
}

void st_list_copy(st_list *dst, const st_list *src)
{
	st_list_free(dst);
	for (int i = 0; i < src->n; i++)
		st_list_put(dst, src->t[i].key, src->t[i].msg, src->t[i].len);
}

static void list_add_cb(const char *key, const dz_msg *m, void *ctx)
{
	st_list_put_msg(ctx, key, m);
}

void st_list_dump(st_list *l)
{
	st_list_free(l);
	state_dump(list_add_cb, l);
}

int st_same(const st_list *a, int i, const st_list *b, int j)
{
	return a->t[i].len == b->t[j].len && !memcmp(a->t[i].msg, b->t[j].msg, a->t[i].len);
}

/* the apply order by kind (2026-11-01): a list in any order (a hand-edited
 * file) applies as a dump would: media before its effects, a display's
 * source, settings before "run" / "on", LFO rate before frames (rate sets
 * frames to 0), the register fields last. The same rank keeps list order. */
static int rank_of(const char *a)
{
	static const struct { const char *pre, *suf; int r; } tab[] = {
		{ "/capture/auto", "", 0 }, { "/audio/fs/auto", "", 0 }, { "/audio/rx/auto", "", 0 },
		{ "/movie/", "/vf", 10 }, { "/movie/", "/af", 10 }, { "/movie/", "/trails", 10 },
		{ "/movie/", "/ghost", 10 }, { "/movie/", "/file", 11 }, { "/movie/", "", 12 },
		{ "/audio/out/", "/source", 20 }, { "/audio/out/", "/file", 21 },
		{ "/disp/", "", 30 }, { "/anim/", "/play", 32 }, { "/anim/", "/pause", 33 },
		{ "/anim/", "", 31 },
		{ "/ascii/", "/chars", 40 }, { "/ascii/", "/run", 42 }, { "/ascii/", "", 41 },
		{ "/dds/", "", 50 }, { "/audio/react/", "", 55 },
		{ "/lfo/", "/rate", 60 }, { "/lfo/", "/frames", 61 }, { "/lfo/", "/on", 63 },
		{ "/lfo/", "", 62 },
		{ "/fan/", "/pwm", 70 }, { "/fx/", "", 80 } };
	size_t la = strlen(a);

	for (size_t i = 0; i < sizeof(tab) / sizeof(tab[0]); i++) {
		size_t lp = strlen(tab[i].pre), ls = strlen(tab[i].suf);

		if (!strncmp(a, tab[i].pre, lp) && la >= lp + ls && !strcmp(a + la - ls, tab[i].suf))
			return tab[i].r;
	}
	return 90;					/* register fields */
}

void st_list_apply(const st_list *l)
{
	int *rk = malloc(sizeof(int) * (size_t)(l->n ? l->n : 1)), cnt[92] = { 0 };

	if (!rk)
		return;
	for (int i = 0; i < l->n; i++) {		/* each rank once (the key = the address) */
		rk[i] = rank_of(l->t[i].key);
		cnt[rk[i]]++;
	}
	for (int r = 0; r <= 90; r++) {			/* stable: list order within a rank */
		for (int i = 0; cnt[r] && i < l->n; i++) {
			dz_msg m;

			if (rk[i] == r && dz_osc_parse(l->t[i].msg, l->t[i].len, &m) == 0)
				dzd_handle_internal(&m);
		}
	}
	free(rk);
}

void st_list_diff(const st_list *want, const st_list *now, st_list *out)
{
	st_list_free(out);
	for (int i = 0; i < want->n; i++) {
		int j = st_list_find(now, want->t[i].key);

		if (j < 0 || !st_same(want, i, now, j))
			st_list_put(out, want->t[i].key, want->t[i].msg, want->t[i].len);
	}
}

/* ---- snapshots ---- */

typedef struct {
	char    name[32];
	st_list l;
	int     used;
} snap_t;

#define SNAPS	8
static snap_t snaps[SNAPS];

static snap_t *snap_find(const char *name, int create)
{
	snap_t *free_s = NULL;

	for (int i = 0; i < SNAPS; i++) {
		if (snaps[i].used && !strcmp(snaps[i].name, name))
			return &snaps[i];
		if (!snaps[i].used && !free_s)
			free_s = &snaps[i];
	}
	if (create && free_s) {
		snprintf(free_s->name, sizeof(free_s->name), "%s", name);
		free_s->used = 1;
	}
	return create ? free_s : NULL;
}

/* one target as a reply: <path> s:key s:address args... */
void st_reply_target(const char *path, const char *key, const dz_msg *m)
{
	dz_arg a[DZ_OSC_MAX_ARGS];
	int n = 0;

	a[n++] = (dz_arg){ .type = 's', .s = key };
	a[n++] = (dz_arg){ .type = 's', .s = m->path };
	for (int i = 0; i < m->n && n < DZ_OSC_MAX_ARGS; i++)
		a[n++] = m->a[i];
	dzd_reply_args(path, a, n);
}

static int dump_count;

static void reply_cb(const char *key, const dz_msg *m, void *ctx)
{
	(void)ctx;
	st_reply_target("/state/target", key, m);
	dump_count++;
}

int state_dispatch(const dz_msg *m)
{
	const char *p = m->path;
	const char *name = m->n >= 1 && m->a[0].type == 's' && m->a[0].s[0] ? m->a[0].s : "a";

	if (strncmp(p, "/state", 6) || (p[6] && p[6] != '/'))
		return 0;
	if (!strcmp(p, "/state")) {
		dump_count = 0;
		state_dump(reply_cb, NULL);
		dzd_reply("/state/end", "i", dump_count);
		return 1;
	}
	if (!strcmp(p, "/state/bench")) {	/* -> /state/bench i:targets f:dump_ms f:diff_ms f:fields_ms */
		int n = m->n >= 1 && m->a[0].type != 's' ? (m->a[0].type == 'f' ? (int)m->a[0].f : m->a[0].i) : 20;
		st_list a = { 0 }, b = { 0 }, d = { 0 };
		struct timespec t0, t1, t2, t3;

		n = n < 1 ? 1 : n > 1000 ? 1000 : n;
		clock_gettime(CLOCK_MONOTONIC, &t0);
		for (int k = 0; k < n; k++)
			st_list_dump(&a);
		clock_gettime(CLOCK_MONOTONIC, &t1);
		for (int k = 0; k < n; k++) {
			st_list_dump(&b);
			st_list_diff(&b, &a, &d);
		}
		clock_gettime(CLOCK_MONOTONIC, &t2);
		for (int k = 0; k < n; k++) {	/* the register reads alone */
			st_list f = { 0 };

			fields_state(list_add_cb, &f);
			st_list_free(&f);
		}
		clock_gettime(CLOCK_MONOTONIC, &t3);
#define MS(x, y) (((y).tv_sec - (x).tv_sec) * 1e3 + ((y).tv_nsec - (x).tv_nsec) / 1e6)
		dzd_reply("/state/bench", "ifff", a.n, MS(t0, t1) / n, MS(t1, t2) / n, MS(t2, t3) / n);
#undef MS
		st_list_free(&a);
		st_list_free(&b);
		st_list_free(&d);
		return 1;
	}
	if (!strcmp(p, "/state/snap")) {
		snap_t *s = snap_find(name, 1);

		if (!s) {
			dzd_reply("/error", "ss", "no free snapshot (8)", p);
			return 1;
		}
		st_list_dump(&s->l);
		dzd_reply("/state/snap", "si", s->name, s->l.n);
		return 1;
	}
	if (!strcmp(p, "/state/recall")) {
		snap_t *s = snap_find(name, 0);

		if (!s) {
			dzd_reply("/error", "ss", "no such snapshot", p);
			return 1;
		}
		st_list_apply(&s->l);
		dzd_log("state: recall %s (%d targets)\n", s->name, s->l.n);
		dzd_reply("/state/recall", "si", s->name, s->l.n);
		return 1;
	}
	if (!strcmp(p, "/state/diff")) {
		snap_t *s = snap_find(name, 0);
		st_list now = { 0 }, d = { 0 };
		int count = 0;

		if (!s) {
			dzd_reply("/error", "ss", "no such snapshot", p);
			return 1;
		}
		st_list_dump(&now);
		st_list_diff(&now, &s->l, &d);		/* now vs the snapshot */
		for (int i = 0; i < d.n; i++) {
			dz_msg mm;

			if (dz_osc_parse(d.t[i].msg, d.t[i].len, &mm) == 0)
				st_reply_target("/state/target", d.t[i].key, &mm);
			count++;
		}
		for (int j = 0; j < s->l.n; j++)	/* in the snapshot, not in the state now */
			if (st_list_find(&now, s->l.t[j].key) < 0) {
				dzd_reply("/state/gone", "s", s->l.t[j].key);
				count++;
			}
		st_list_free(&now);
		st_list_free(&d);
		dzd_reply("/state/end", "i", count);
		return 1;
	}
	return 0;
}

/*
 * anim.c - image sequences: a folder of frames out of a display (2026-11-01,
 * ROADMAP.md section 16).
 *
 * A folder /media/debaz/anim/<name>/ of .jpg / .png frames (natural sort:
 * f2 before f10) plays out of display d at any rate. Worker threads decode
 * the next frames (dz_img: TurboJPEG straight into the slot) into a ring of
 * hidden slots; the vsync thread flips to the next ready frame when it is
 * due (disp.c calls anim_vsync under its lock), so every frame starts on a
 * whole video frame. A slot that was shown stays untouched for one more
 * video frame (the VDMA reads it until the next vsync).
 *
 * Optional timing sheet <folder>/timing.txt: one line per frame
 * "<file> [hold]" (hold = frames at the sequence rate: 2 = "on twos"; a
 * file may come back), "# fps <rate>" = the rate when /play gives none.
 *
 * Sequences with <= ring slots different files are "resident": each file is
 * decoded once into its own slot, then the flips cost no CPU.
 *
 * OSC (d = 0, 1):
 *   /anim/<d>/play s:name [f:fps]  start (the same name again while it
 *                                  plays: only unpause); "" = stop
 *   /anim/<d>/stop                 back to what the display showed before
 *   /anim/<d>/pause [i:1|0]        no argument = toggle
 *   /anim/<d>/fps f                sequence frames per second (0.1 .. 120)
 *   /anim/<d>/mode s               loop | once | pingpong | random
 *   /anim/<d>/end s                after "once": hold | black | stop
 *   /anim/<d>/range i:in i:out     frame range (positions of the list;
 *                                  -1 = last)
 *   /anim/<d>/reverse i
 *   /anim/<d>/frame i              go to position i at once (also paused)
 *   /anim/<d>/step i               pause and move i positions (+1, -1)
 *   /anim/<d>/late s               hold = wait for a late frame, the time
 *                                  stretches (default: no drawn frame is
 *                                  lost); skip = keep time, drop frames
 *   /anim/<d>/ahead i              files read ahead (posix_fadvise, 0-16)
 *   /anim/<d>/threads i            decode threads 1 | 2 (default 2)
 *   /anim/<d>/fast i               TurboJPEG fast DCT (~20 % faster)
 *   /anim/<d>/slots i...           ring slots (2-6; defaults 5 6 7 8 /
 *                                  9 10 1 3), only while stopped
 *   /anim/<d>                      -> /anim/<d> s:name i:frames i:pos
 *                                  f:fps f:fps_real i:late f:dec_ms
 *                                  f:dec_max_ms s:state s:file i:resident
 *                                  i:slot (shown, -1 = none yet)
 *   /anim/list                     -> /anim/folder s:name i:frames i:kbytes
 *                                  ... /anim/folder/end i:count
 *
 * Building a folder frame by frame (stop motion, drawn animation; web Paint
 * tab):
 *   /anim/save s:folder [src] [i:quality] [i:hold]
 *                                  the picture of src as the next frame
 *                                  f00001.jpg, f00002.jpg ... (folder made
 *                                  if needed); src = a slot number (default
 *                                  0), "capture" (the live input at its own
 *                                  size), "disp0" / "disp1" (what the
 *                                  display shows now, with its crop);
 *                                  quality default 90 (display size, 4:2:0);
 *                                  hold (sequence frames, default 1): with a
 *                                  hold > 1 or an existing timing.txt the
 *                                  frame's line goes into timing.txt (made
 *                                  from the folder order the first time)
 *                                  -> /anim/saved s:folder s:file i:frames f:ms
 *                                  i:bytes (the file size: it sets the
 *                                  decode time, ~25 ms + 0.16 ms per KB at
 *                                  720p)
 *   /anim/undo s:folder            delete the last fNNNNN.jpg (and its lines
 *                                  in timing.txt)
 *                                  -> /anim/saved s:folder "" i:frames f:0 i:0
 *
 * Onion skin (stop motion: line the next shot up with the last ones):
 *   /anim/<d>/onion s:folder [f:opacity] [i:frames] [src]
 *                                  display d shows the live input with the
 *                                  last 1-3 frames of the folder over it
 *                                  (opacity default 0.4 for the newest, half
 *                                  for each older one); src = "capture"
 *                                  (default) or a slot number (a paint
 *                                  slot). ~20 fps at 720p (one thread: copy
 *                                  out of the capture, blend, write). A save
 *                                  into the folder loads the new last frames.
 *                                  "" or /anim/<d>/stop = off
 *   /anim/<d>/onion/opacity f, /onion/frames i   while it runs
 *   /anim/delete s:folder          stop players on it, delete its .jpg / .png
 *                                  frames and timing.txt, then the folder
 *                                  -> /anim/deleted s:folder i:files
 *
 * Timing sheet (the web Paint tab's sheet editor; 8 KB packets: in parts):
 *   /anim/sheet s:folder           -> /anim/sheet/part s:folder i:k s:text ...
 *                                  /anim/sheet/end s:folder i:exists
 *                                  i:entries f:fps (no timing.txt: one made
 *                                  from the folder, exists 0)
 *   /anim/sheet/put s:folder i:part i:last s:text
 *                                  part 0 starts, last = 1 writes timing.txt
 *                                  ("" = delete it: folder order again)
 *                                  -> /anim/sheet/saved s:folder i:entries
 *                                  i:unknown s:first_unknown
 * A display that plays the folder loads it again (the new frame is in).
 */
#define _GNU_SOURCE
#include "debazd.h"
#include "dz_draw.h"
#include "dz_hw.h"
#include "dz_img.h"
#include "dz_map.h"
#include "dz_vdma.h"

#include <ctype.h>
#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <sys/stat.h>
#include <time.h>
#include <unistd.h>

#define RING_MAX	6
#define FILES_MAX	20000
#define NAME_MAX_	96

enum { E_FREE, E_BUSY, E_READY, E_SHOWN, E_COOL };
enum { M_LOOP, M_ONCE, M_PINGPONG, M_RANDOM };
enum { END_HOLD, END_BLACK, END_STOP };
static const char *mode_names[] = { "loop", "once", "pingpong", "random" };
static const char *end_names[] = { "hold", "black", "stop" };

typedef struct {
	int           slot, state, pos;	/* pos = list position decoded */
	unsigned      seq, gen;
	unsigned long free_at;		/* E_COOL: free from this vsync on */
	uint8_t      *ptr;
} entry;

typedef struct {
	/* settings (kept across plays) */
	float  fps;
	int    mode, endm, skip, rev, in, out, ahead, nthr, fast;
	int    slots[RING_MAX], nslots;
	/* the sequence */
	int    on, paused, ended;
	char   name[NAME_MAX_ + 1], dir[160];
	char **files;
	int    nfiles;
	int   *lfile, *lhold, nlist;	/* list: file index + hold per position */
	int    resident;
	int    dw, dh;			/* fit window */
	/* generator (next position to decode; resident: next to show) */
	int    gpos, gdir, gend, last_pos;
	unsigned gseq, gen, show_seq;
	unsigned geo;			/* resident: bumped by a mode change */
	int    debt;			/* late skip: positions to drop */
	/* ring */
	entry  e[RING_MAX];
	int    ne, cur;			/* cur = entry shown, -1 */
	int    force;			/* show the next frame at once */
	int    pend_frame;		/* resident: -1 or position to show */
	unsigned long vs;		/* own vsync count */
	double due;			/* vsync count of the next flip */
	/* statistics */
	unsigned long flips, late_n, last_flip_vs;
	double fps_real, iv_avg, dec_sum, dec_max;
	unsigned long dec_n;
	int    end_pending;
	/* onion skin */
	int    onion, on_n, on_src, on_reload;	/* on_src: slot, -1 = capture */
	float  on_op;
	uint32_t *on_fr[3];			/* last frames, newest first, dw x dh */
	int    on_have;
	uint8_t *on_map[DZ_SLOTS];		/* source slots, mapped in the main thread */
	/* threads */
	pthread_t thr[2];
	int    nthr_run, run;
	pthread_mutex_t mu;
	pthread_cond_t cv;
} player;

static player P[DZ_DISPLAYS];
static int num(const dz_arg *a, int *v);
static int start(int d, const char *name, float fps, char *err, size_t errlen);
static void reload_folder(const char *name);
static int read_phys(uint8_t *dst, uint32_t phys, size_t len, uint8_t **map);
static int slot_taken(int d, int slot);
static int inited;

static double now_ms(void)
{
	struct timespec t;

	clock_gettime(CLOCK_MONOTONIC, &t);
	return t.tv_sec * 1e3 + t.tv_nsec / 1e6;
}

static const char *anim_dir(void)
{
	const char *e = getenv("DZ_ANIM_DIR");

	return e && *e ? e : DZ_MEDIA_DIR "/anim";
}

static void init_once(void)
{
	static const int defs[DZ_DISPLAYS][4] = { { 5, 6, 7, 8 }, { 9, 10, 1, 3 } };

	if (inited)
		return;
	inited = 1;
	for (int d = 0; d < DZ_DISPLAYS; d++) {
		player *p = &P[d];

		memset(p, 0, sizeof(*p));
		pthread_mutex_init(&p->mu, NULL);
		pthread_cond_init(&p->cv, NULL);
		p->fps = 12;
		p->in = 0;
		p->out = -1;
		p->ahead = 6;
		p->nthr = 2;
		p->nslots = 4;
		memcpy(p->slots, defs[d], sizeof(defs[d]));
		p->cur = -1;
		p->pend_frame = -1;
	}
}

/* ---- folder ------------------------------------------------------------------ */

static int name_ok(const char *n)
{
	if (!n || !*n || *n == '.' || strlen(n) > NAME_MAX_ || strstr(n, ".."))
		return 0;
	for (const char *c = n; *c; c++)
		if (!(isalnum((unsigned char)*c) || *c == '.' || *c == '_' || *c == '-'))
			return 0;
	return 1;
}

/* natural order: digit runs compare as numbers (f2 < f10) */
static int natcmp(const char *a, const char *b)
{
	while (*a && *b) {
		if (isdigit((unsigned char)*a) && isdigit((unsigned char)*b)) {
			const char *a0, *b0;
			size_t la, lb;

			while (*a == '0' && isdigit((unsigned char)a[1]))
				a++;
			while (*b == '0' && isdigit((unsigned char)b[1]))
				b++;
			for (a0 = a; isdigit((unsigned char)*a); a++)
				;
			for (b0 = b; isdigit((unsigned char)*b); b++)
				;
			la = (size_t)(a - a0);
			lb = (size_t)(b - b0);
			if (la != lb)
				return la < lb ? -1 : 1;
			int c = strncmp(a0, b0, la);
			if (c)
				return c;
			continue;
		}
		int ca = tolower((unsigned char)*a), cb = tolower((unsigned char)*b);
		if (ca != cb)
			return ca < cb ? -1 : 1;
		a++;
		b++;
	}
	return *a ? 1 : *b ? -1 : 0;
}

static int natcmp_p(const void *x, const void *y)
{
	return natcmp(*(char *const *)x, *(char *const *)y);
}

static void free_files(char **f, int n)
{
	for (int i = 0; i < n; i++)
		free(f[i]);
	free(f);
}

/* the frames of a folder, sorted; -1 if it cannot be read */
static int scan_folder(const char *dir, char ***out, long *bytes)
{
	DIR *dp = opendir(dir);
	struct dirent *e;
	char **f = NULL;
	int n = 0, cap = 0;

	*out = NULL;
	if (bytes)
		*bytes = 0;
	if (!dp)
		return -1;
	while ((e = readdir(dp)) && n < FILES_MAX) {
		if (e->d_name[0] == '.' || !dz_img_kind(e->d_name) || !name_ok(e->d_name))
			continue;
		if (n == cap) {
			char **g = realloc(f, sizeof(char *) * (size_t)(cap = cap ? cap * 2 : 256));

			if (!g)
				break;
			f = g;
		}
		f[n++] = strdup(e->d_name);
		if (bytes) {
			char p[400];
			struct stat st;

			snprintf(p, sizeof(p), "%s/%s", dir, e->d_name);
			if (!stat(p, &st))
				*bytes += st.st_size;
		}
	}
	closedir(dp);
	if (n)
		qsort(f, (size_t)n, sizeof(char *), natcmp_p);
	*out = f;
	return n;
}

static int file_index(char **f, int n, const char *name)
{
	for (int i = 0; i < n; i++)
		if (!strcmp(f[i], name))
			return i;
	return -1;
}

/* the play list: timing.txt or every file once; fps from the sheet or 0 */
static int build_list(player *p, float *sheet_fps)
{
	char path[200], line[256];
	FILE *fp;
	int cap = p->nfiles > 0 ? p->nfiles : 1;

	*sheet_fps = 0;
	free(p->lfile);
	free(p->lhold);
	p->nlist = 0;
	p->lfile = malloc(sizeof(int) * (size_t)cap);
	p->lhold = malloc(sizeof(int) * (size_t)cap);
	if (!p->lfile || !p->lhold)
		return -1;
	snprintf(path, sizeof(path), "%s/timing.txt", p->dir);
	fp = fopen(path, "r");
	if (fp) {
		while (fgets(line, sizeof(line), fp)) {
			char name[NAME_MAX_ + 2];
			int hold = 1, k;
			float r;

			if (sscanf(line, " # fps %f", &r) == 1) {
				*sheet_fps = r;
				continue;
			}
			if (sscanf(line, " %97s %d", name, &hold) < 1 || name[0] == '#')
				continue;
			k = file_index(p->files, p->nfiles, name);
			if (k < 0) {
				dzd_log("anim: %s: timing.txt names %s (not in the folder)\n", p->name, name);
				continue;
			}
			if (p->nlist == cap) {
				int *a = realloc(p->lfile, sizeof(int) * (size_t)cap * 2);
				int *b = a ? realloc(p->lhold, sizeof(int) * (size_t)cap * 2) : NULL;

				if (a)
					p->lfile = a;
				if (!b)
					break;
				p->lhold = b;
				cap *= 2;
			}
			p->lfile[p->nlist] = k;
			p->lhold[p->nlist++] = hold < 1 ? 1 : hold > 1000 ? 1000 : hold;
		}
		fclose(fp);
		if (p->nlist)
			return 0;
	}
	for (int i = 0; i < p->nfiles; i++) {
		p->lfile[i] = i;
		p->lhold[i] = 1;
	}
	p->nlist = p->nfiles;
	return 0;
}

/* ---- order (p->mu held) ------------------------------------------------------- */

static void range_of(const player *p, int *lo, int *hi)
{
	int a = p->in < 0 ? p->nlist - 1 : p->in, b = p->out < 0 ? p->nlist - 1 : p->out;

	a = a < 0 ? 0 : a >= p->nlist ? p->nlist - 1 : a;
	b = b < 0 ? 0 : b >= p->nlist ? p->nlist - 1 : b;
	*lo = a < b ? a : b;
	*hi = a < b ? b : a;
}

/* the position after pos (sets *dir for ping-pong); -1 = the end (once) */
static int next_pos(const player *p, int pos, int *dir)
{
	int lo, hi, n;

	range_of(p, &lo, &hi);
	n = hi - lo + 1;
	if (pos < lo || pos > hi)
		return p->rev ? hi : lo;
	switch (p->mode) {
	case M_RANDOM:
		if (n <= 1)
			return lo;
		{
			int r = lo + rand() % (n - 1);

			return r >= pos ? r + 1 : r;	/* never the same frame twice */
		}
	case M_PINGPONG:
		if (n <= 1)
			return lo;
		if (pos + *dir > hi || pos + *dir < lo)
			*dir = -*dir;
		return pos + *dir;
	case M_ONCE:
		pos += p->rev ? -1 : 1;
		return pos < lo || pos > hi ? -1 : pos;
	default:
		pos += p->rev ? -1 : 1;
		return pos > hi ? lo : pos < lo ? hi : pos;
	}
}

static int first_pos(const player *p)
{
	int lo, hi;

	range_of(p, &lo, &hi);
	return p->rev ? hi : lo;
}

/* forget every decoded frame; the generator restarts at pos */
static void flush(player *p, int pos)
{
	p->gen++;
	for (int i = 0; i < p->ne && !p->resident; i++)	/* resident frames stay */
		if (p->e[i].state == E_READY)
			p->e[i].state = E_FREE;
	p->gpos = pos;
	p->gdir = p->rev ? -1 : 1;
	p->gend = 0;
	p->ended = 0;
	p->debt = 0;
	p->show_seq = p->gseq;
	p->force = 1;
	if (p->resident)
		p->pend_frame = pos;
	pthread_cond_broadcast(&p->cv);
}

/* order changed while playing (mode, reverse): keep the frame shown,
 * decode again from the one after it */
static void regen(player *p)
{
	if (!p->on || p->last_pos < 0)
		return;
	flush(p, p->last_pos);
	p->force = 0;
	p->pend_frame = -1;
	p->gpos = next_pos(p, p->last_pos, &p->gdir);
	p->gend = p->gpos < 0;
}

/* ---- decode workers ----------------------------------------------------------- */

static void path_of(const player *p, int pos, char *buf, size_t n)
{
	snprintf(buf, n, "%s/%s", p->dir, p->files[p->lfile[pos]]);
}

static void read_ahead(const player *p, int pos, int dir)
{
	/* p->mu held: only cheap work; posix_fadvise does not block on I/O */
	for (int k = 0; k < p->ahead && pos >= 0; k++) {
		char path[400];
		int fd;

		pos = next_pos(p, pos, &dir);
		if (pos < 0)
			break;
		path_of(p, pos, path, sizeof(path));
		fd = open(path, O_RDONLY | O_CLOEXEC);
		if (fd >= 0) {
			posix_fadvise(fd, 0, 0, POSIX_FADV_WILLNEED);
			close(fd);
		}
	}
}

/* a free entry, or -1 */
static int free_entry(player *p)
{
	for (int i = 0; i < p->ne; i++)
		if (p->e[i].state == E_FREE)
			return i;
	return -1;
}

/* ---- onion skin ---- */

/* l * (1 - a) + o * a, a = 0..256, two channels at once */
static inline uint32_t mix(uint32_t l, uint32_t o, uint32_t a)
{
	uint32_t rb = (((l & 0xFF00FFu) * (256 - a) + (o & 0xFF00FFu) * a) >> 8) & 0xFF00FFu;
	uint32_t g = (((l & 0x00FF00u) * (256 - a) + (o & 0x00FF00u) * a) >> 8) & 0x00FF00u;

	return 0xFF000000u | rb | g;
}

/* row = row * (1 - a) + f * a over n pixels; a = 0..256. NEON: 4 pixels a
 * step, weights 0..255 (the C version: ~32 ms per 720p layer on the A9) */
#if defined(__ARM_NEON) || defined(__ARM_NEON__)
#include <arm_neon.h>
#endif
static void mix_row(uint32_t *row, const uint32_t *f, int n, uint32_t a)
{
	int x = 0;
#if defined(__ARM_NEON) || defined(__ARM_NEON__)
	uint8_t a8 = (uint8_t)(a > 255 ? 255 : a);
	uint8x8_t va = vdup_n_u8(a8), vi = vdup_n_u8((uint8_t)(255 - a8));

	for (; x + 4 <= n; x += 4) {
		uint8x16_t l = vld1q_u8((const uint8_t *)(row + x)), o = vld1q_u8((const uint8_t *)(f + x));
		uint16x8_t lo = vmlal_u8(vmull_u8(vget_low_u8(l), vi), vget_low_u8(o), va);
		uint16x8_t hi = vmlal_u8(vmull_u8(vget_high_u8(l), vi), vget_high_u8(o), va);

		vst1q_u8((uint8_t *)(row + x), vcombine_u8(vrshrn_n_u16(lo, 8), vrshrn_n_u16(hi, 8)));
	}
#endif
	for (; x < n; x++)
		row[x] = mix(row[x], f[x], a);
}

/* the last n frames of the folder (natural order), newest first; p->mu held,
 * released while decoding */
static void onion_load(player *p)
{
	char **f, path[400], err[128];
	int n, want, dw = p->dw, dh = p->dh;
	uint32_t *fr[3] = { 0 };

	pthread_mutex_unlock(&p->mu);
	n = scan_folder(p->dir, &f, NULL);
	want = n < 0 ? 0 : (n < p->on_n ? n : p->on_n);
	for (int k = 0; k < want; k++) {
		fr[k] = malloc((size_t)dw * dh * 4);
		snprintf(path, sizeof(path), "%s/%s", p->dir, f[n - 1 - k]);
		if (fr[k] && dz_img_fit(path, (uint8_t *)fr[k], (size_t)dw * 4, dw, dh, 0, err, sizeof(err))) {
			dzd_log("anim: onion %s: %s\n", path, err);
			free(fr[k]);
			fr[k] = NULL;
		}
	}
	free_files(f, n > 0 ? n : 0);
	pthread_mutex_lock(&p->mu);
	for (int k = 0; k < 3; k++) {
		free(p->on_fr[k]);
		p->on_fr[k] = fr[k];
	}
	p->on_have = want;
}

static void onion_step(player *p)
{
	int i = free_entry(p), dw = p->dw, dh = p->dh, sw = dw, sh = dh, have;
	uint32_t phys, a[3];
	size_t st = DZ_STRIDE;
	uint8_t *dst;
	uint32_t *row, *fr[3];
	double t0;

	if (p->on_reload) {
		p->on_reload = 0;
		onion_load(p);
		return;
	}
	if (i < 0) {
		struct timespec ts;

		clock_gettime(CLOCK_REALTIME, &ts);
		ts.tv_nsec += 5 * 1000000;
		if (ts.tv_nsec >= 1000000000) {
			ts.tv_sec++;
			ts.tv_nsec -= 1000000000;
		}
		pthread_cond_timedwait(&p->cv, &p->mu, &ts);
		return;
	}
	p->e[i].state = E_BUSY;
	have = p->on_have;
	for (int k = 0; k < 3; k++) {
		fr[k] = p->on_fr[k];
		a[k] = (uint32_t)(p->on_op * 256.0f / (float)(1 << k) + 0.5f);	/* older: half */
	}
	dst = p->e[i].ptr;
	pthread_mutex_unlock(&p->mu);

	t0 = now_ms();
	if (p->on_src < 0) {			/* the capture at its own size */
		dz_vdma_regs cr;

		phys = dz_capture_addr();
		if (dz_capture_regs(&cr) == 0 && cr.vsize && cr.hsize) {
			sw = (int)(cr.hsize & 0xFFFF) / DZ_BPP;
			sh = (int)(cr.vsize & 0x1FFF);
		} else {
			phys = 0;		/* no input: black under the frames */
		}
	} else {
		phys = DZ_SLOT_ADDR(p->on_src);
	}
	row = malloc((size_t)(sw > dw ? sw : dw) * 4);
	/* source column per output column, once per frame: a 64-bit division
	 * per pixel is a library call on the A9 (330 ms per frame, measured) */
	int *xm = sw != dw ? malloc(sizeof(int) * (size_t)dw) : NULL;

	for (int x = 0; xm && x < dw; x++)
		xm[x] = (int)((int64_t)x * sw / dw);
	for (int y = 0; row && y < dh; y++) {
		uint32_t *o = (uint32_t *)(dst + (size_t)y * DZ_STRIDE);
		int sy = (int)((int64_t)y * sh / dh);

		if (!phys || read_phys((uint8_t *)row, phys + (uint32_t)((size_t)sy * st),
				       (size_t)sw * 4, p->on_map))
			memset(row, 0, (size_t)dw * 4);
		else if (xm && sw > dw)		/* nearest, in place: dst x <= src x */
			for (int x = 0; x < dw; x++)
				row[x] = row[xm[x]];
		else if (xm)			/* a smaller source: from the right end */
			for (int x = dw - 1; x >= 0; x--)
				row[x] = row[xm[x]];
		for (int k = have - 1; k >= 0; k--) {	/* oldest first, the newest on top */
			mix_row(row, fr[k] + (size_t)y * dw, dw, a[k]);
		}
		memcpy(o, row, (size_t)dw * 4);
	}
	free(row);
	free(xm);
	__sync_synchronize();

	pthread_mutex_lock(&p->mu);
	p->dec_sum += now_ms() - t0;
	p->dec_n++;
	if (now_ms() - t0 > p->dec_max)
		p->dec_max = now_ms() - t0;
	p->e[i].seq = p->gseq++;
	p->e[i].gen = p->gen;
	p->e[i].state = E_READY;
}

static void *worker(void *arg)
{
	player *p = arg;
	char path[400], err[128];

	pthread_mutex_lock(&p->mu);
	while (p->run) {
		int i, pos, ok;
		unsigned gen;
		double t0, dt;

		if (p->onion) {
			onion_step(p);		/* unlocks while it works */
			continue;
		}

		if (p->resident) {		/* each file once into its own entry */
			for (i = 0; i < p->ne; i++)
				if (p->e[i].state == E_FREE && p->e[i].pos >= 0)
					break;
			if (i == p->ne) {
				pthread_cond_wait(&p->cv, &p->mu);
				continue;
			}
			pos = p->e[i].pos;
		} else {
			i = p->gend ? -1 : free_entry(p);
			if (i < 0) {
				struct timespec ts;

				clock_gettime(CLOCK_REALTIME, &ts);
				ts.tv_nsec += 20 * 1000000;
				if (ts.tv_nsec >= 1000000000) {
					ts.tv_sec++;
					ts.tv_nsec -= 1000000000;
				}
				pthread_cond_timedwait(&p->cv, &p->mu, &ts);
				continue;
			}
			while (p->debt > 0 && p->gpos >= 0) {	/* late skip: drop positions */
				int np = next_pos(p, p->gpos, &p->gdir);

				p->debt--;
				if (np < 0)
					break;
				p->gpos = np;
			}
			pos = p->gpos;
			p->e[i].seq = p->gseq++;
			p->e[i].pos = pos;
			p->gpos = next_pos(p, pos, &p->gdir);
			if (p->gpos < 0)
				p->gend = 1;
			read_ahead(p, pos, p->gdir);
		}
		p->e[i].state = E_BUSY;
		p->e[i].gen = gen = p->resident ? p->geo : p->gen;
		path_of(p, pos, path, sizeof(path));
		pthread_mutex_unlock(&p->mu);

		t0 = now_ms();
		ok = dz_img_fit(path, p->e[i].ptr, DZ_STRIDE, p->dw, p->dh,
				p->fast ? DZ_IMG_FAST : 0, err, sizeof(err)) == 0;
		dt = now_ms() - t0;
		if (!ok) {
			dzd_log("anim: %s: %s\n", path, err);
			/* a black frame keeps the timing */
			for (int y = 0; y < p->dh; y++) {
				uint32_t *r = (uint32_t *)(p->e[i].ptr + (size_t)y * DZ_STRIDE);

				for (int x = 0; x < p->dw; x++)
					r[x] = 0xFF000000u;
			}
		}
		__sync_synchronize();		/* pixels before the READY mark */

		pthread_mutex_lock(&p->mu);
		p->dec_sum += dt;
		p->dec_n++;
		if (dt > p->dec_max)
			p->dec_max = dt;
		/* stale (flushed, or a mode change while resident): free again */
		p->e[i].state = gen == (p->resident ? p->geo : p->gen) ? E_READY : E_FREE;
	}
	pthread_mutex_unlock(&p->mu);
	return NULL;
}

/* ---- the vsync side (disp lock held; p->mu taken briefly) ---------------------- */

static double hold_vs(const player *p, int pos)
{
	double hz = disp_frame_hz();
	float fps = p->fps > 0.01f ? p->fps : 0.01f;

	if (hz < 1)
		hz = 60;
	return hz / fps * (pos >= 0 && pos < p->nlist ? p->lhold[pos] : 1);
}

static void note_flip(player *p)
{
	if (p->last_flip_vs) {
		double hz = disp_frame_hz() > 1 ? disp_frame_hz() : 60;
		double iv = (double)(p->vs - p->last_flip_vs);	/* vsyncs per flip */

		/* average the interval, not the rate: 24 fps at 60 Hz = 2, 3, 2, 3 */
		p->iv_avg = p->iv_avg > 0 ? p->iv_avg * 0.9 + iv * 0.1 : iv;
		p->fps_real = hz / p->iv_avg;
	}
	p->last_flip_vs = p->vs;
	p->flips++;
}

/* the frame due now in a streaming player: an entry index or -1 */
static int pick_stream(player *p, int late)
{
	int best = -1;

	for (int i = 0; i < p->ne; i++) {
		entry *e = &p->e[i];

		if (e->state != E_READY || e->gen != p->gen)
			continue;
		if (e->seq == p->show_seq)
			return i;
		/* late skip: the oldest ready frame after the one due */
		if (late && p->skip && (int)(e->seq - p->show_seq) > 0 &&
		    (best < 0 || (int)(e->seq - p->e[best].seq) < 0))
			best = i;
	}
	return best;
}

uint32_t anim_vsync(int d)
{
	player *p;
	uint32_t addr = 0;

	if (!inited || d < 0 || d >= DZ_DISPLAYS)
		return 0;
	p = &P[d];
	pthread_mutex_lock(&p->mu);
	if (!p->on) {
		pthread_mutex_unlock(&p->mu);
		return 0;
	}
	p->vs++;
	for (int i = 0; i < p->ne; i++)		/* the VDMA has left these */
		if (p->e[i].state == E_COOL && p->vs >= p->e[i].free_at) {
			p->e[i].state = E_FREE;
			pthread_cond_signal(&p->cv);
		}

	if (p->onion) {			/* the newest rendered frame */
		int best = -1;

		for (int i = 0; i < p->ne; i++)
			if (p->e[i].state == E_READY && (best < 0 || (int)(p->e[i].seq - p->e[best].seq) > 0))
				best = i;
		if (best >= 0) {
			for (int i = 0; i < p->ne; i++)	/* older ones: drop */
				if (i != best && p->e[i].state == E_READY)
					p->e[i].state = E_FREE;
			if (p->cur >= 0 && p->cur != best) {
				p->e[p->cur].state = E_COOL;
				p->e[p->cur].free_at = p->vs + 1;
			}
			p->e[best].state = E_SHOWN;
			p->cur = best;
			addr = DZ_SLOT_ADDR(p->e[best].slot);
			note_flip(p);
			pthread_cond_signal(&p->cv);
		}
		pthread_mutex_unlock(&p->mu);
		return addr;
	}

	if (p->resident) {
		int pos = -1;

		if (p->pend_frame >= 0) {
			pos = p->pend_frame;
		} else if (!p->paused && !p->ended && p->vs >= p->due) {
			pos = next_pos(p, p->last_pos, &p->gdir);
			if (pos < 0) {
				p->ended = 1;
				if (p->endm == END_BLACK)
					addr = DZ_SLOT_ADDR(DZ_SLOT_BLANK);
				else if (p->endm == END_STOP)
					p->end_pending = 1;
			}
		}
		if (pos >= 0) {
			int k = p->lfile[pos];	/* resident: entry k holds file k */

			if (k < p->ne && p->e[k].state == E_READY) {
				addr = DZ_SLOT_ADDR(p->e[k].slot);
				if (p->vs > p->due + 1 && p->pend_frame < 0)
					p->late_n++;
				p->due = (p->pend_frame >= 0 || p->vs > p->due + 1 ? (double)p->vs : p->due) +
					 hold_vs(p, pos);
				p->last_pos = pos;
				p->pend_frame = -1;
				p->cur = k;
				note_flip(p);
			} else if (p->pend_frame < 0) {
				p->pend_frame = pos;	/* not decoded yet: show when it is */
			}
		}
		pthread_mutex_unlock(&p->mu);
		return addr;
	}

	if (p->force || (!p->paused && p->vs >= p->due)) {
		int late = !p->force && p->vs >= p->due + 1;
		int i = pick_stream(p, late);

		if (i >= 0) {
			entry *e = &p->e[i];

			if (late)
				p->late_n++;
			if (p->cur >= 0 && p->cur != i) {
				p->e[p->cur].state = E_COOL;
				p->e[p->cur].free_at = p->vs + 1;
			}
			e->state = E_SHOWN;
			p->cur = i;
			p->show_seq = e->seq + 1;
			p->last_pos = e->pos;
			if (p->force || !p->skip)
				p->due = (late || p->force ? (double)p->vs : p->due) + hold_vs(p, e->pos);
			else
				p->due += hold_vs(p, e->pos);
			p->force = 0;
			addr = DZ_SLOT_ADDR(e->slot);
			note_flip(p);
		} else if (p->gend && !p->ended) {
			int busy = 0;

			for (int k = 0; k < p->ne; k++)
				if (p->e[k].state == E_BUSY || (p->e[k].state == E_READY && p->e[k].gen == p->gen))
					busy = 1;
			if (!busy) {
				p->ended = 1;
				if (p->endm == END_BLACK)
					addr = DZ_SLOT_ADDR(DZ_SLOT_BLANK);
				else if (p->endm == END_STOP)
					p->end_pending = 1;
			}
		} else if (p->skip && late && !p->force && p->vs >= p->due + hold_vs(p, p->last_pos)) {
			/* a whole frame behind: drop one position at the decoder */
			p->debt++;
			p->due += hold_vs(p, p->last_pos);
		}
	}
	pthread_mutex_unlock(&p->mu);
	return addr;
}

/* ---- control (main thread) ------------------------------------------------------ */

static void stop_threads(player *p)
{
	pthread_mutex_lock(&p->mu);
	p->run = 0;
	pthread_cond_broadcast(&p->cv);
	pthread_mutex_unlock(&p->mu);
	for (int k = 0; k < p->nthr_run; k++)
		pthread_join(p->thr[k], NULL);
	p->nthr_run = 0;
}

void anim_stop(int d)
{
	player *p;

	if (!inited || d < 0 || d >= DZ_DISPLAYS || !P[d].on)
		return;
	p = &P[d];
	stop_threads(p);
	pthread_mutex_lock(&p->mu);
	p->on = 0;
	pthread_mutex_unlock(&p->mu);
	disp_anim_attach(d, 0);		/* the display shows its front slot again */
	for (int k = 0; k < 3; k++) {
		free(p->on_fr[k]);
		p->on_fr[k] = NULL;
	}
	p->onion = p->on_have = 0;
	free_files(p->files, p->nfiles);
	p->files = NULL;
	p->nfiles = 0;
	dzd_log("anim: display %d stopped (%s, %lu flips, %lu late)\n", d, p->name,
		p->flips, p->late_n);
}

int anim_on(int d)
{
	return inited && d >= 0 && d < DZ_DISPLAYS && P[d].on;
}

void anim_stop_all(void)
{
	for (int d = 0; d < DZ_DISPLAYS; d++)
		anim_stop(d);
}

static int slot_taken(int d, int slot)
{
	for (int o = 0; o < DZ_DISPLAYS; o++)
		if (o != d)
			for (int k = 0; k < P[o].nslots; k++)
				if (P[o].on && P[o].slots[k] == slot)
					return 1;
	return slot == DZ_SLOT_BLANK || slot == DZ_SLOT_CAPTURE;
}

static int start(int d, const char *name, float fps, char *err, size_t errlen)
{
	player *p = &P[d];
	float sheet_fps;

	if (!name_ok(name)) {
		snprintf(err, errlen, "bad folder name");
		return -1;
	}
	if (!dz_img_available(DZ_IMG_JPEG) && !dz_img_available(DZ_IMG_PNG)) {
		snprintf(err, errlen, "no libturbojpeg / libpng");
		return -1;
	}
	for (int k = 0; k < p->nslots; k++)
		if (slot_taken(d, p->slots[k]) || !dz_reserved(DZ_SLOT_ADDR(p->slots[k]), DZ_SLOT_PITCH)) {
			snprintf(err, errlen, "slot %d not usable (other display, blank, capture or "
				 "not reserved)", p->slots[k]);
			return -1;
		}
	anim_stop(d);
	free_files(p->files, p->nfiles);	/* left by a failed start */
	p->files = NULL;
	p->nfiles = 0;
	snprintf(p->name, sizeof(p->name), "%s", name);
	snprintf(p->dir, sizeof(p->dir), "%s/%s", anim_dir(), name);
	p->nfiles = scan_folder(p->dir, &p->files, NULL);
	if (p->nfiles <= 0) {
		snprintf(err, errlen, p->nfiles < 0 ? "no folder %s" : "no .jpg / .png in %s", p->dir);
		free_files(p->files, 0);
		p->files = NULL;
		p->nfiles = 0;
		return -1;
	}
	if (build_list(p, &sheet_fps)) {
		snprintf(err, errlen, "out of memory");
		return -1;
	}
	if (fps > 0)
		p->fps = fps;
	else if (sheet_fps > 0)
		p->fps = sheet_fps;
	/* slots: stop movies / ASCII there, map them in this thread (dz_map is
	 * not thread safe) */
	p->ne = p->nslots;
	for (int k = 0; k < p->ne; k++) {
		dz_draw_movie_stop(p->slots[k]);
		memset(&p->e[k], 0, sizeof(entry));
		p->e[k].slot = p->slots[k];
		p->e[k].pos = -1;
		p->e[k].ptr = dz_slot(p->slots[k], DZ_SLOT_PITCH, NULL);
		if (!p->e[k].ptr) {
			snprintf(err, errlen, "slot %d: no mapping", p->slots[k]);
			return -1;
		}
	}
	p->resident = p->nfiles <= p->ne;	/* entry k = file k */
	p->dw = dz_geom_w();
	p->dh = dz_geom_h();
	p->paused = p->ended = p->end_pending = 0;
	p->cur = -1;
	p->flips = p->late_n = p->last_flip_vs = p->dec_n = 0;
	p->fps_real = p->iv_avg = p->dec_sum = p->dec_max = 0;
	p->vs = 0;
	p->due = 0;
	p->gseq = 0;
	p->last_pos = -1;
	if (p->resident) {
		/* entry k = file k: the worker decodes position of its first use */
		for (int k = 0; k < p->ne; k++)
			p->e[k].pos = -1;
		for (int i = p->nlist - 1; i >= 0; i--)
			p->e[p->lfile[i]].pos = i;
	}
	flush(p, first_pos(p));
	p->on = 1;
	p->run = 1;
	disp_anim_attach(d, 1);
	p->nthr_run = 0;
	for (int k = 0; k < (p->resident ? 1 : p->nthr); k++)
		if (pthread_create(&p->thr[k], NULL, worker, p) == 0)
			p->nthr_run++;
	dzd_log("anim: display %d plays %s: %d files, %d positions, %.2f fps, %s, slots %d..%d\n",
		d, p->name, p->nfiles, p->nlist, p->fps, p->resident ? "resident" : "streaming",
		p->slots[0], p->slots[p->ne - 1]);
	return 0;
}

static int start_onion(int d, const char *name, float op, int frames, int src, char *err, size_t errlen)
{
	player *p = &P[d];

	if (!name_ok(name)) {
		snprintf(err, errlen, "bad folder name");
		return -1;
	}
	if (src >= 0 && (src >= DZ_SLOTS || !dz_reserved(DZ_SLOT_ADDR(src), DZ_SLOT_PITCH))) {
		snprintf(err, errlen, "bad source slot");
		return -1;
	}
	for (int k = 0; k < p->nslots; k++)
		if (slot_taken(d, p->slots[k]) || p->slots[k] == src ||
		    !dz_reserved(DZ_SLOT_ADDR(p->slots[k]), DZ_SLOT_PITCH)) {
			snprintf(err, errlen, "slot %d not usable (other display, source, blank, capture)",
				 p->slots[k]);
			return -1;
		}
	anim_stop(d);
	free_files(p->files, p->nfiles);
	p->files = NULL;
	p->nfiles = 0;
	snprintf(p->name, sizeof(p->name), "%s", name);
	snprintf(p->dir, sizeof(p->dir), "%s/%s", anim_dir(), name);
	p->ne = p->nslots;
	for (int k = 0; k < p->ne; k++) {
		dz_draw_movie_stop(p->slots[k]);
		memset(&p->e[k], 0, sizeof(entry));
		p->e[k].slot = p->slots[k];
		p->e[k].pos = -1;
		p->e[k].ptr = dz_slot(p->slots[k], DZ_SLOT_PITCH, NULL);
		if (!p->e[k].ptr) {
			snprintf(err, errlen, "slot %d: no mapping", p->slots[k]);
			return -1;
		}
	}
	/* the source slots, mapped here (dz_map is not thread safe): the capture
	 * may run into the next slots (input taller than 1080 lines) */
	memset(p->on_map, 0, sizeof(p->on_map));
	{
		int s0 = src >= 0 ? src : (int)((dz_capture_addr() - DZ_SLOT_BASE) / DZ_SLOT_PITCH);
		dz_vdma_regs cr;

		dz_capture_regs(&cr);		/* maps the capture VDMA's registers */
		for (int k = s0; k >= 0 && k < DZ_SLOTS && k <= s0 + 1; k++)
			if (dz_reserved(DZ_SLOT_ADDR(k), DZ_SLOT_PITCH))
				p->on_map[k] = dz_slot(k, DZ_SLOT_PITCH, NULL);
	}
	p->dw = dz_geom_w();
	p->dh = dz_geom_h();
	p->onion = 1;
	p->on_src = src;
	p->on_op = op < 0 ? 0 : op > 1 ? 1 : op;
	p->on_n = frames < 1 ? 1 : frames > 3 ? 3 : frames;
	p->on_reload = 1;
	p->on_have = 0;
	p->paused = p->ended = p->end_pending = p->resident = 0;
	p->nlist = 0;
	p->cur = -1;
	p->flips = p->late_n = p->last_flip_vs = p->dec_n = 0;
	p->fps_real = p->iv_avg = p->dec_sum = p->dec_max = 0;
	p->vs = 0;
	p->gseq = 0;
	p->last_pos = -1;
	p->on = 1;
	p->run = 1;
	disp_anim_attach(d, 1);
	p->nthr_run = pthread_create(&p->thr[0], NULL, worker, p) == 0;
	dzd_log("anim: display %d onion skin of %s (%d frames, %.2f) over %s\n", d, name, p->on_n,
		p->on_op, src < 0 ? "the capture" : "a slot");
	return 0;
}

/* after a video mode change: decode again at the new size */
void anim_geometry(void)
{
	for (int d = 0; d < DZ_DISPLAYS; d++) {
		player *p = &P[d];

		if (!inited || !p->on)
			continue;
		pthread_mutex_lock(&p->mu);
		p->dw = dz_geom_w();
		p->dh = dz_geom_h();
		if (p->onion) {
			p->on_reload = 1;
			pthread_cond_broadcast(&p->cv);
			pthread_mutex_unlock(&p->mu);
			continue;
		}
		if (p->resident) {
			p->geo++;
			for (int k = 0; k < p->ne; k++)
				if (p->e[k].pos >= 0 && p->e[k].state == E_READY)
					p->e[k].state = E_FREE;
		}
		flush(p, p->last_pos >= 0 ? p->last_pos : first_pos(p));
		pthread_mutex_unlock(&p->mu);
	}
}

void anim_tick(void)
{
	if (!inited)
		return;
	if (!disp_vsync_ok())
		disp_anim_frame();	/* no vsync (host, displays off): timer frames */
	for (int d = 0; d < DZ_DISPLAYS; d++) {
		int stop;

		pthread_mutex_lock(&P[d].mu);
		stop = P[d].on && P[d].end_pending;
		P[d].end_pending = 0;
		pthread_mutex_unlock(&P[d].mu);
		if (stop)
			anim_stop(d);
	}
}

static const char *state_name(const player *p)
{
	return !p->on ? "stopped" : p->onion ? "onion" : p->ended ? "ended" : p->paused ? "paused" :
	       p->flips == 0 ? "loading" : "playing";
}

static void status(int d)
{
	player *p = &P[d];
	char path[16], file[NAME_MAX_ + 1] = "";
	int pos;

	pthread_mutex_lock(&p->mu);
	pos = p->on ? p->last_pos : -1;
	if (pos >= 0 && pos < p->nlist)
		snprintf(file, sizeof(file), "%s", p->files[p->lfile[pos]]);
	snprintf(path, sizeof(path), "/anim/%d", d);
	dzd_reply(path, "siiffiffssii", p->on ? p->name : "", p->on ? p->nlist : 0, pos,
		  p->fps, (float)(p->on && !p->paused && !p->ended ? p->fps_real : 0.0),
		  (int)p->late_n, (float)(p->dec_n ? p->dec_sum / p->dec_n : 0.0),
		  (float)p->dec_max, state_name(p), file, p->resident,
		  p->on && p->cur >= 0 ? p->e[p->cur].slot : -1);
	pthread_mutex_unlock(&p->mu);
}

static int list_folders(void)
{
	DIR *dp = opendir(anim_dir());
	struct dirent *e;
	int count = 0;

	while (dp && (e = readdir(dp))) {
		char dir[300], **f;
		long bytes;
		int n;

		if (e->d_name[0] == '.' || !name_ok(e->d_name))
			continue;
		snprintf(dir, sizeof(dir), "%s/%s", anim_dir(), e->d_name);
		n = scan_folder(dir, &f, &bytes);
		if (n < 0)
			continue;
		free_files(f, n);
		dzd_reply("/anim/folder", "sii", e->d_name, n, (int)(bytes / 1024));
		count++;
	}
	if (dp)
		closedir(dp);
	dzd_reply("/anim/folder/end", "i", count);
	return count;
}

/* the folder names for /files anim (debazd.c) */
int anim_folder_names(void (*cb)(const char *name, void *ctx), void *ctx)
{
	DIR *dp = opendir(anim_dir());
	struct dirent *e;
	int n = 0;

	while (dp && (e = readdir(dp))) {
		struct stat st;
		char dir[300];

		snprintf(dir, sizeof(dir), "%s/%s", anim_dir(), e->d_name);
		if (e->d_name[0] == '.' || !name_ok(e->d_name) || stat(dir, &st) || !S_ISDIR(st.st_mode))
			continue;
		cb(e->d_name, ctx);
		n++;
	}
	if (dp)
		closedir(dp);
	return n;
}

/* ---- saving frames ---- */

/* copy len bytes from a physical address inside the reserved slots (a row
 * may cross from one slot mapping into the next). map[] caches the slot
 * pointers: dz_slot checks the reservation each call (/proc/iomem) */
static int read_phys(uint8_t *dst, uint32_t phys, size_t len, uint8_t **map)
{
	while (len > 0) {
		uint32_t rel = phys - DZ_SLOT_BASE;
		int slot = (int)(rel / DZ_SLOT_PITCH);
		size_t off = rel % DZ_SLOT_PITCH, n = DZ_SLOT_PITCH - off;

		if (phys < DZ_SLOT_BASE || slot >= DZ_SLOTS)
			return -1;
		if (!map[slot] && !(map[slot] = dz_slot(slot, DZ_SLOT_PITCH, NULL)))
			return -1;
		n = n < len ? n : len;
		memcpy(dst, map[slot] + off, n);
		dst += n;
		phys += (uint32_t)n;
		len -= n;
	}
	return 0;
}

/* the highest number of fNNNNN.jpg in dir (0 = none) and the frame count */
static int last_number(const char *dir, int *frames)
{
	DIR *dp = opendir(dir);
	struct dirent *e;
	int hi = 0;

	*frames = 0;
	while (dp && (e = readdir(dp))) {
		int k, len = 0;

		if (e->d_name[0] == '.' || !dz_img_kind(e->d_name))
			continue;
		(*frames)++;
		if (sscanf(e->d_name, "f%d.jpg%n", &k, &len) == 1 && !e->d_name[len] && k > hi)
			hi = k;
	}
	if (dp)
		closedir(dp);
	return hi;
}

/* ---- timing.txt ---- */

/* whole file into a new string (NULL if missing) */
static char *slurp(const char *path)
{
	FILE *fp = fopen(path, "r");
	long n;
	char *b;

	if (!fp)
		return NULL;
	fseek(fp, 0, SEEK_END);
	n = ftell(fp);
	fseek(fp, 0, SEEK_SET);
	b = malloc((size_t)(n < 0 ? 0 : n) + 1);
	if (b) {
		n = (long)fread(b, 1, (size_t)(n < 0 ? 0 : n), fp);
		b[n] = 0;
	}
	fclose(fp);
	return b;
}

static int write_text(const char *path, const char *text)
{
	char part[300];
	FILE *fp;
	int ok;

	snprintf(part, sizeof(part), "%s.part", path);
	fp = fopen(part, "w");
	if (!fp)
		return -1;
	ok = fputs(text, fp) >= 0;
	ok = (fclose(fp) == 0) && ok;
	if (!ok || rename(part, path)) {
		unlink(part);
		return -1;
	}
	return 0;
}

/* the sheet that the folder order means (every frame once) */
static char *sheet_from_folder(const char *dir, float fps, const char *skip)
{
	char **f;
	int n = scan_folder(dir, &f, NULL);
	size_t cap = 64 + (size_t)(n > 0 ? n : 0) * (NAME_MAX_ + 8), len;
	char *t = malloc(cap);

	if (!t) {
		free_files(f, n > 0 ? n : 0);
		return NULL;
	}
	len = (size_t)snprintf(t, cap, "# fps %g\n", fps);
	for (int i = 0; i < n; i++)
		if (!skip || strcmp(f[i], skip))
			len += (size_t)snprintf(t + len, cap - len, "%s\n", f[i]);
	free_files(f, n > 0 ? n : 0);
	return t;
}

static float folder_fps(const char *name)
{
	for (int d = 0; d < DZ_DISPLAYS; d++)
		if (P[d].on && !strcmp(P[d].name, name))
			return P[d].fps;
	return 12;
}

/* a new frame's line; the sheet is made first if needed */
static void sheet_add(const char *folder, const char *dir, const char *file, int hold)
{
	char path[240], line[NAME_MAX_ + 16], *old = NULL, *all;

	snprintf(path, sizeof(path), "%s/timing.txt", dir);
	old = slurp(path);
	if (!old && hold <= 1)
		return;				/* no sheet: the folder order does it */
	if (!old)
		old = sheet_from_folder(dir, folder_fps(folder), file);
	if (!old)
		return;
	if (hold > 1)
		snprintf(line, sizeof(line), "%s %d\n", file, hold);
	else
		snprintf(line, sizeof(line), "%s\n", file);
	all = malloc(strlen(old) + strlen(line) + 2);
	if (all) {
		size_t l = strlen(old);

		strcpy(all, old);
		if (l && all[l - 1] != '\n')
			strcat(all, "\n");
		strcat(all, line);
		if (write_text(path, all))
			dzd_log("anim: cannot write %s\n", path);
	}
	free(all);
	free(old);
}

/* drop the lines of one file */
static void sheet_remove(const char *dir, const char *file)
{
	char path[240], *old, *out, *line, *save = NULL;

	snprintf(path, sizeof(path), "%s/timing.txt", dir);
	old = slurp(path);
	if (!old)
		return;
	out = calloc(strlen(old) + 2, 1);
	for (line = strtok_r(old, "\n", &save); out && line; line = strtok_r(NULL, "\n", &save)) {
		char name[NAME_MAX_ + 2] = "";

		if (sscanf(line, " %97s", name) == 1 && !strcmp(name, file))
			continue;
		strcat(out, line);
		strcat(out, "\n");
	}
	if (out && write_text(path, out))
		dzd_log("anim: cannot write %s\n", path);
	free(out);
	free(old);
}

/* count entries and names that are not in the folder */
static int sheet_check(const char *dir, const char *text, int *unknown, char *first, size_t fl,
		       float *fps)
{
	char **f, *copy = strdup(text ? text : ""), *line, *save = NULL;
	int n = scan_folder(dir, &f, NULL), entries = 0;

	*unknown = 0;
	*fps = 0;
	if (first && fl)
		first[0] = 0;
	for (line = strtok_r(copy, "\n", &save); copy && line; line = strtok_r(NULL, "\n", &save)) {
		char name[NAME_MAX_ + 2];
		float r;

		if (sscanf(line, " # fps %f", &r) == 1) {
			*fps = r;
			continue;
		}
		if (sscanf(line, " %97s", name) != 1 || name[0] == '#')
			continue;
		entries++;
		if (file_index(f, n > 0 ? n : 0, name) < 0 && (*unknown)++ == 0 && first)
			snprintf(first, fl, "%s", name);
	}
	free(copy);
	free_files(f, n > 0 ? n : 0);
	return entries;
}

static void sheet_get(const dz_msg *m)
{
	const char *folder = m->n >= 1 && m->a[0].type == 's' ? m->a[0].s : "";
	char dir[200], path[240];
	char *t;
	int exists, unknown, entries, k = 0;
	float fps;

	if (!name_ok(folder)) {
		dzd_reply("/error", "ss", "sheet needs a folder name", m->path);
		return;
	}
	snprintf(dir, sizeof(dir), "%s/%s", anim_dir(), folder);
	{
		struct stat st;

		if (stat(dir, &st) || !S_ISDIR(st.st_mode)) {
			dzd_reply("/error", "ss", "no folder", dir);
			return;
		}
	}
	snprintf(path, sizeof(path), "%s/timing.txt", dir);
	t = slurp(path);
	exists = t != NULL;
	if (!t)
		t = sheet_from_folder(dir, folder_fps(folder), NULL);
	if (!t) {
		dzd_reply("/error", "ss", "no folder", dir);
		return;
	}
	entries = sheet_check(dir, t, &unknown, NULL, 0, &fps);
	for (size_t off = 0, len = strlen(t); off < len; k++) {	/* parts of <= 4000 bytes, whole lines */
		size_t n = len - off > 4000 ? 4000 : len - off;
		char c;

		while (off + n < len && n > 1 && t[off + n - 1] != '\n')
			n--;
		c = t[off + n];
		t[off + n] = 0;
		dzd_reply("/anim/sheet/part", "sis", folder, k, t + off);
		t[off + n] = c;
		off += n;
	}
	dzd_reply("/anim/sheet/end", "siif", folder, exists, entries, fps);
	free(t);
}

static char  *put_buf;
static char   put_folder[NAME_MAX_ + 1];
static size_t put_len;

static void sheet_put(const dz_msg *m)
{
	const dz_arg *a = m->a;
	char dir[200], path[240], first[NAME_MAX_ + 2];
	int part, last, unknown, entries;
	float fps;

	if (m->n < 4 || a[0].type != 's' || a[3].type != 's' || !name_ok(a[0].s) ||
	    !num(&a[1], &part) || !num(&a[2], &last)) {
		dzd_reply("/error", "ss", "sheet/put: folder part last text", m->path);
		return;
	}
	if (part == 0) {
		free(put_buf);
		put_buf = NULL;
		put_len = 0;
		snprintf(put_folder, sizeof(put_folder), "%s", a[0].s);
	} else if (strcmp(put_folder, a[0].s) || !put_buf) {
		dzd_reply("/error", "ss", "sheet/put: part 0 missing", m->path);
		return;
	}
	{
		size_t n = strlen(a[3].s);
		char *g = realloc(put_buf, put_len + n + 1);

		if (!g || put_len + n > 1024 * 1024) {
			dzd_reply("/error", "ss", "sheet/put: too large", m->path);
			return;
		}
		put_buf = g;
		memcpy(put_buf + put_len, a[3].s, n + 1);
		put_len += n;
	}
	if (!last)
		return;
	snprintf(dir, sizeof(dir), "%s/%s", anim_dir(), put_folder);
	snprintf(path, sizeof(path), "%s/timing.txt", dir);
	if (!put_len) {				/* empty: back to the folder order */
		unlink(path);
		entries = unknown = 0;
		first[0] = 0;
	} else {
		entries = sheet_check(dir, put_buf, &unknown, first, sizeof(first), &fps);
		if (put_buf[put_len - 1] != '\n') {
			char *g = realloc(put_buf, put_len + 2);

			if (g) {
				put_buf = g;
				strcat(put_buf, "\n");
			}
		}
		if (write_text(path, put_buf)) {
			dzd_reply("/error", "ss", "cannot write", path);
			return;
		}
	}
	dzd_log("anim: %s/timing.txt: %d entries, %d unknown\n", put_folder, entries, unknown);
	reload_folder(put_folder);
	dzd_reply("/anim/sheet/saved", "siis", put_folder, entries, unknown, first);
	free(put_buf);
	put_buf = NULL;
	put_len = 0;
}

/* players that show this folder: load it again (keeps fps and mode) */
static void reload_folder(const char *name)
{
	for (int d = 0; d < DZ_DISPLAYS; d++) {
		char err[200];

		if (P[d].on && P[d].onion && !strcmp(P[d].name, name)) {
			pthread_mutex_lock(&P[d].mu);
			P[d].on_reload = 1;
			pthread_cond_broadcast(&P[d].cv);
			pthread_mutex_unlock(&P[d].mu);
		} else if (P[d].on && !strcmp(P[d].name, name) && start(d, name, 0, err, sizeof(err)))
			dzd_log("anim: reload %s: %s\n", name, err);
	}
}

static void save_frame(const dz_msg *m)
{
	const dz_arg *a = m->a;
	const char *folder = m->n >= 1 && a[0].type == 's' ? a[0].s : "";
	char dir[200], file[32], path[240], err[160] = "";
	int w = dz_geom_w(), h = dz_geom_h(), q = 90, frames, num_hi, slot = 0;
	size_t stride = dz_geom_stride();
	uint32_t phys;
	uint8_t *buf;
	double t0 = now_ms();

	if (!name_ok(folder)) {
		dzd_reply("/error", "ss", "save needs a folder name (A-Z a-z 0-9 . _ -)", m->path);
		return;
	}
	if (m->n >= 2 && a[1].type == 's') {
		if (!strcmp(a[1].s, "capture")) {
			dz_vdma_regs cr;

			phys = dz_capture_addr();
			if (dz_capture_regs(&cr) == 0 && cr.vsize && cr.hsize) {
				w = (int)(cr.hsize & 0xFFFF) / DZ_BPP;
				h = (int)(cr.vsize & 0x1FFF);
			}
		} else if (!strcmp(a[1].s, "disp0") || !strcmp(a[1].s, "disp1")) {
			phys = dz_disp_addr(a[1].s[4] - '0');
		} else {
			dzd_reply("/error", "ss", "source: a slot, capture, disp0 or disp1", m->path);
			return;
		}
	} else {
		if (m->n >= 2)
			num(&a[1], &slot);
		if (slot < 0 || slot >= DZ_SLOTS) {
			dzd_reply("/error", "ss", "bad slot", m->path);
			return;
		}
		phys = DZ_SLOT_ADDR(slot);
	}
	int hold = 1;

	if (m->n >= 3)
		num(&a[2], &q);
	if (m->n >= 4)
		num(&a[3], &hold);
	if (!phys || w <= 0 || h <= 0 || !dz_reserved(phys, (uint32_t)((size_t)h * stride))) {
		dzd_reply("/error", "ss", "source not in reserved memory (display or capture off?)", m->path);
		return;
	}
	snprintf(dir, sizeof(dir), "%s/%s", anim_dir(), folder);
	mkdir(anim_dir(), 0755);
	if (mkdir(dir, 0755) && errno != EEXIST) {
		dzd_reply("/error", "ss", "cannot make the folder", dir);
		return;
	}
	num_hi = last_number(dir, &frames);
	snprintf(file, sizeof(file), "f%05d.jpg", num_hi + 1);
	snprintf(path, sizeof(path), "%s/%s", dir, file);
	buf = malloc((size_t)w * h * 4);
	if (!buf) {
		dzd_reply("/error", "ss", "out of memory", m->path);
		return;
	}
	/* one copy out of the uncached slot (~25 ms at 720p), then the encode
	 * from cached RAM (~50 ms) */
	uint8_t *map[DZ_SLOTS] = { 0 };

	for (int y = 0; y < h; y++)
		if (read_phys(buf + (size_t)y * w * 4, phys + (uint32_t)((size_t)y * stride), (size_t)w * 4, map)) {
			snprintf(err, sizeof(err), "read failed");
			break;
		}
	double t1 = now_ms();
	if (!err[0])
		dz_img_save_jpeg(path, buf, (size_t)w * 4, w, h, q, err, sizeof(err));
	free(buf);
	if (err[0]) {
		dzd_reply("/error", "ss", err, m->path);
		return;
	}
	sheet_add(folder, dir, file, hold);
	dzd_log("anim: saved %s/%s (%dx%d, %.0f ms: copy %.0f, encode + write %.0f)\n", folder, file,
		w, h, now_ms() - t0, t1 - t0, now_ms() - t1);
	reload_folder(folder);
	{
		struct stat st;

		dzd_reply("/anim/saved", "ssifi", folder, file, frames + 1, (float)(now_ms() - t0),
			  stat(path, &st) ? 0 : (int)st.st_size);
	}
}

static void undo_frame(const dz_msg *m)
{
	const char *folder = m->n >= 1 && m->a[0].type == 's' ? m->a[0].s : "";
	char dir[200], path[240];
	int frames, hi;

	if (!name_ok(folder)) {
		dzd_reply("/error", "ss", "undo needs a folder name", m->path);
		return;
	}
	snprintf(dir, sizeof(dir), "%s/%s", anim_dir(), folder);
	hi = last_number(dir, &frames);
	if (hi <= 0) {
		dzd_reply("/error", "ss", "no fNNNNN.jpg frame to delete", dir);
		return;
	}
	snprintf(path, sizeof(path), "%s/f%05d.jpg", dir, hi);
	if (unlink(path)) {
		dzd_reply("/error", "ss", "cannot delete", path);
		return;
	}
	dzd_log("anim: deleted %s\n", path);
	{
		char fn[32];

		snprintf(fn, sizeof(fn), "f%05d.jpg", hi);
		sheet_remove(dir, fn);
	}
	frames--;
	if (frames > 0)
		reload_folder(folder);
	else
		for (int d = 0; d < DZ_DISPLAYS; d++)
			if (P[d].on && !strcmp(P[d].name, folder))
				anim_stop(d);
	dzd_reply("/anim/saved", "ssifi", folder, "", frames, 0.0f, 0);
}

static void delete_folder(const dz_msg *m)
{
	const char *folder = m->n >= 1 && m->a[0].type == 's' ? m->a[0].s : "";
	char dir[200], path[320], **f;
	int n, gone = 0;

	if (!name_ok(folder)) {
		dzd_reply("/error", "ss", "delete needs a folder name", m->path);
		return;
	}
	for (int d = 0; d < DZ_DISPLAYS; d++)
		if (P[d].on && !strcmp(P[d].name, folder))
			anim_stop(d);
	snprintf(dir, sizeof(dir), "%s/%s", anim_dir(), folder);
	n = scan_folder(dir, &f, NULL);
	if (n < 0) {
		dzd_reply("/error", "ss", "no folder", dir);
		return;
	}
	for (int i = 0; i < n; i++) {
		snprintf(path, sizeof(path), "%s/%s", dir, f[i]);
		gone += unlink(path) == 0;
	}
	free_files(f, n);
	snprintf(path, sizeof(path), "%s/timing.txt", dir);
	unlink(path);
	if (rmdir(dir))		/* other files left (not frames): keep the folder */
		dzd_log("anim: %s: %s (folder kept)\n", dir, strerror(errno));
	dzd_log("anim: deleted folder %s (%d frames)\n", folder, gone);
	dzd_reply("/anim/deleted", "si", folder, gone);
}

static int num(const dz_arg *a, int *v)
{
	if (a->type == 'i')
		*v = a->i;
	else if (a->type == 'f')
		*v = (int)a->f;
	else
		return 0;
	return 1;
}

static int pick(const char *s, const char *const *names, int n)
{
	for (int i = 0; i < n; i++)
		if (!strcmp(s, names[i]))
			return i;
	return -1;
}

int anim_dispatch(const dz_msg *m)
{
	const dz_arg *a = m->a;
	int n = m->n, d, len = 0, v;
	char op[24] = "";
	player *p;

	if (strncmp(m->path, "/anim", 5))
		return 0;
	init_once();
	if (!strcmp(m->path, "/anim/list")) {
		list_folders();
		return 1;
	}
	if (!strcmp(m->path, "/anim/save")) {
		save_frame(m);
		return 1;
	}
	if (!strcmp(m->path, "/anim/undo")) {
		undo_frame(m);
		return 1;
	}
	if (!strcmp(m->path, "/anim/delete")) {
		delete_folder(m);
		return 1;
	}
	if (!strcmp(m->path, "/anim/sheet")) {
		sheet_get(m);
		return 1;
	}
	if (!strcmp(m->path, "/anim/sheet/put")) {
		sheet_put(m);
		return 1;
	}
	if (sscanf(m->path, "/anim/%d%n", &d, &len) != 1 || d < 0 || d >= DZ_DISPLAYS)
		return 0;
	if (m->path[len] == '/')
		snprintf(op, sizeof(op), "%s", m->path + len + 1);
	else if (m->path[len])
		return 0;
	p = &P[d];

	if (!*op) {
		status(d);
		return 1;
	}
	if (!strcmp(op, "play")) {
		char err[200];
		float fps = 0;

		if (n < 1 || a[0].type != 's') {
			dzd_reply("/error", "ss", "play needs a folder name", m->path);
			return 1;
		}
		if (!*a[0].s) {
			anim_stop(d);
			status(d);
			return 1;
		}
		if (n >= 2)
			fps = a[1].type == 'f' ? a[1].f : a[1].type == 'i' ? (float)a[1].i : 0;
		if (p->on && !strcmp(p->name, a[0].s)) {	/* the same: keep the position */
			pthread_mutex_lock(&p->mu);
			if (fps > 0)
				p->fps = fps;
			if (p->ended)			/* "once" finished: again */
				flush(p, first_pos(p));
			if (p->paused) {
				p->paused = 0;
				p->due = (double)p->vs;
			}
			pthread_mutex_unlock(&p->mu);
		} else if (start(d, a[0].s, fps, err, sizeof(err))) {
			dzd_reply("/error", "ss", err, m->path);
			return 1;
		}
		status(d);
		return 1;
	}
	if (!strcmp(op, "stop")) {
		anim_stop(d);
		status(d);
		return 1;
	}
	if (!strcmp(op, "onion")) {
		char err[200];
		float o = 0.4f;
		int fr = 1, src = -1;

		if (n < 1 || a[0].type != 's') {
			dzd_reply("/error", "ss", "onion needs a folder name (\"\" = off)", m->path);
			return 1;
		}
		if (!*a[0].s) {
			if (p->onion)
				anim_stop(d);
			status(d);
			return 1;
		}
		if (n >= 2)
			o = a[1].type == 'f' ? a[1].f : a[1].type == 'i' ? (float)a[1].i : o;
		if (n >= 3)
			num(&a[2], &fr);
		if (n >= 4 && a[3].type != 's')
			num(&a[3], &src);
		if (start_onion(d, a[0].s, o, fr, src, err, sizeof(err))) {
			dzd_reply("/error", "ss", err, m->path);
			return 1;
		}
		status(d);
		return 1;
	}
	if (!strcmp(op, "onion/opacity") || !strcmp(op, "onion/frames")) {
		pthread_mutex_lock(&p->mu);
		if (op[6] == 'o' && n >= 1)
			p->on_op = a[0].type == 'f' ? (a[0].f < 0 ? 0 : a[0].f > 1 ? 1 : a[0].f) :
				   a[0].type == 'i' ? (a[0].i ? 1.0f : 0.0f) : p->on_op;
		else if (n >= 1 && num(&a[0], &v)) {
			p->on_n = v < 1 ? 1 : v > 3 ? 3 : v;
			p->on_reload = 1;
			pthread_cond_broadcast(&p->cv);
		}
		pthread_mutex_unlock(&p->mu);
		status(d);
		return 1;
	}
	if (!strcmp(op, "slots")) {
		int k = 0, s[RING_MAX];

		if (p->on) {
			dzd_reply("/error", "ss", "slots: stop the sequence first", m->path);
			return 1;
		}
		for (int j = 0; j < n && k < RING_MAX; j++)
			if (num(&a[j], &v) && v >= 0 && v < DZ_SLOTS)
				s[k++] = v;
		if (k >= 2) {
			memcpy(p->slots, s, sizeof(int) * (size_t)k);
			p->nslots = k;
		}
		{
			dz_arg r[RING_MAX];

			for (int j = 0; j < p->nslots; j++)
				r[j] = (dz_arg){ .type = 'i', .i = p->slots[j] };
			dzd_reply_args(m->path, r, p->nslots);
		}
		return 1;
	}

	pthread_mutex_lock(&p->mu);
	if (!strcmp(op, "pause")) {
		int was = p->paused;

		p->paused = n >= 1 && num(&a[0], &v) ? v != 0 : !p->paused;
		if (was && !p->paused)
			p->due = (double)p->vs;		/* go on from now */
	} else if (!strcmp(op, "fps") && n >= 1) {
		float f = a[0].type == 'f' ? a[0].f : a[0].type == 'i' ? (float)a[0].i : p->fps;

		p->fps = f < 0.1f ? 0.1f : f > 120 ? 120 : f;
	} else if (!strcmp(op, "mode") && n >= 1 && a[0].type == 's') {
		int k = pick(a[0].s, mode_names, 4);

		if (k >= 0 && k != p->mode) {
			p->mode = k;
			regen(p);
		}
	} else if (!strcmp(op, "end") && n >= 1 && a[0].type == 's') {
		int k = pick(a[0].s, end_names, 3);

		if (k >= 0)
			p->endm = k;
	} else if (!strcmp(op, "late") && n >= 1 && a[0].type == 's') {
		p->skip = !strcmp(a[0].s, "skip");
	} else if (!strcmp(op, "range") && n >= 2 && num(&a[0], &p->in) && num(&a[1], &p->out)) {
		if (p->on)
			flush(p, first_pos(p));
	} else if (!strcmp(op, "reverse") && n >= 1 && num(&a[0], &v)) {
		if ((v != 0) != p->rev) {
			p->rev = v != 0;
			regen(p);
		}
	} else if ((!strcmp(op, "frame") || !strcmp(op, "step")) && n >= 1 && num(&a[0], &v)) {
		if (p->on && p->nlist > 0) {
			int pos = !strcmp(op, "frame") ? v : (p->last_pos < 0 ? 0 : p->last_pos) + v;

			if (op[0] == 's')
				p->paused = 1;
			pos = ((pos % p->nlist) + p->nlist) % p->nlist;
			flush(p, pos);
		}
	} else if (!strcmp(op, "ahead") && n >= 1 && num(&a[0], &v)) {
		p->ahead = v < 0 ? 0 : v > 16 ? 16 : v;
	} else if (!strcmp(op, "threads") && n >= 1 && num(&a[0], &v)) {
		p->nthr = v >= 2 ? 2 : 1;	/* from the next play */
	} else if (!strcmp(op, "fast") && n >= 1 && num(&a[0], &v)) {
		p->fast = v != 0;
	} else {
		pthread_mutex_unlock(&p->mu);
		dzd_reply("/error", "ss", "unknown /anim operation", m->path);
		return 1;
	}
	pthread_mutex_unlock(&p->mu);
	status(d);
	return 1;
}

/* the state model: settings first, then what plays (rank: state.c) */
void anim_state(state_cb cb, void *ctx)
{
	init_once();
	for (int d = 0; d < DZ_DISPLAYS; d++) {
		player *p = &P[d];
		char k[40];

		pthread_mutex_lock(&p->mu);
		snprintf(k, sizeof(k), "/anim/%d/fps", d);
		st_emit(cb, ctx, NULL, k, "f", p->fps);
		snprintf(k, sizeof(k), "/anim/%d/mode", d);
		st_emit(cb, ctx, NULL, k, "s", mode_names[p->mode]);
		snprintf(k, sizeof(k), "/anim/%d/end", d);
		st_emit(cb, ctx, NULL, k, "s", end_names[p->endm]);
		snprintf(k, sizeof(k), "/anim/%d/late", d);
		st_emit(cb, ctx, NULL, k, "s", p->skip ? "skip" : "hold");
		snprintf(k, sizeof(k), "/anim/%d/reverse", d);
		st_emit(cb, ctx, NULL, k, "i", p->rev);
		snprintf(k, sizeof(k), "/anim/%d/range", d);
		st_emit(cb, ctx, NULL, k, "ii", p->in, p->out);
		snprintf(k, sizeof(k), "/anim/%d/play", d);
		st_emit(cb, ctx, NULL, k, "s", p->on && !p->onion ? p->name : "");
		snprintf(k, sizeof(k), "/anim/%d/pause", d);
		st_emit(cb, ctx, NULL, k, "i", p->on && p->paused);
		pthread_mutex_unlock(&p->mu);
	}
}

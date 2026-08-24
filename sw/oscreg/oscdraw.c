/*
 * oscdraw - drawing and playback layer for the DEBAZAROS frame slots.
 * See oscdraw.h for the model and the OSC address list.
 */
#define _GNU_SOURCE
#include "oscdraw.h"

#include <errno.h>
#include <fcntl.h>
#include <linux/fb.h>
#include <math.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

typedef struct {
	uint32_t  base;			/* physical address of the slot   */
	int       w, h;
	size_t    dstride;		/* bytes per line in the slot     */
	uint32_t *shadow;		/* cached working copy, w*h words */
	uint8_t  *dev;			/* mapped slot, NULL until used   */
	void     *map;			/* mmap base, for munmap          */
	size_t    map_len;
	size_t    map_shift;
	int       fd;
	char      via[16];		/* "fb0" or "mem" or "sim"        */
	int       dx0, dy0, dx1, dy1;	/* dirty rectangle, x1/y1 exclusive */
	unsigned  alpha;		/* 0..256                         */
	int       autoflush;
	pid_t     player;
} od_surf;

static od_surf surf[OSCDRAW_SURFACES];
static int     sim_mode;
static int     mem_fd = -1;
static int     fb_fd = -1;
static uint8_t *fb_map;
static size_t   fb_len;
static uint32_t fb_phys;

/* ------------------------------------------------------------------ */
/* mapping                                                             */
/* ------------------------------------------------------------------ */
static void fb_probe(void)
{
	struct fb_fix_screeninfo fix;

	fb_fd = open("/dev/fb0", O_RDWR);
	if (fb_fd < 0)
		return;
	if (ioctl(fb_fd, FBIOGET_FSCREENINFO, &fix) < 0 || fix.smem_len == 0) {
		close(fb_fd);
		fb_fd = -1;
		return;
	}
	fb_map = mmap(NULL, fix.smem_len, PROT_READ | PROT_WRITE, MAP_SHARED,
		      fb_fd, 0);
	if (fb_map == MAP_FAILED) {
		fb_map = NULL;
		close(fb_fd);
		fb_fd = -1;
		return;
	}
	fb_len  = fix.smem_len;
	fb_phys = (uint32_t)fix.smem_start;
}

static int surf_map(od_surf *s)
{
	size_t need = (size_t)(s->h - 1) * s->dstride + (size_t)s->w * 4;
	long page;

	if (s->dev)
		return 0;

	if (sim_mode) {
		s->map = calloc(1, need);
		if (!s->map)
			return -1;
		s->dev = s->map;
		s->map_len = need;
		snprintf(s->via, sizeof(s->via), "sim");
		return 0;
	}

	/*
	 * Prefer /dev/fb0 when its memory covers this slot: the fbdev mapping
	 * is write-combining, while /dev/mem on a no-map region is uncached
	 * and roughly ten times slower to write.
	 */
	if (fb_map && s->base >= fb_phys &&
	    (size_t)(s->base - fb_phys) + need <= fb_len) {
		s->dev = fb_map + (s->base - fb_phys);
		s->map = NULL;
		snprintf(s->via, sizeof(s->via), "fb0");
		return 0;
	}

	if (mem_fd < 0) {
		mem_fd = open("/dev/mem", O_RDWR | O_SYNC);
		if (mem_fd < 0) {
			fprintf(stderr, "oscdraw: open /dev/mem: %s\n",
				strerror(errno));
			return -1;
		}
	}
	page = sysconf(_SC_PAGESIZE);
	s->map_shift = s->base & ((unsigned long)page - 1);
	s->map_len   = s->map_shift + need;
	s->map = mmap(NULL, s->map_len, PROT_READ | PROT_WRITE, MAP_SHARED,
		      mem_fd, (off_t)(s->base - s->map_shift));
	if (s->map == MAP_FAILED) {
		fprintf(stderr, "oscdraw: mmap 0x%08X: %s\n",
			(unsigned)s->base, strerror(errno));
		s->map = NULL;
		return -1;
	}
	s->dev = (uint8_t *)s->map + s->map_shift;
	snprintf(s->via, sizeof(s->via), "mem");
	return 0;
}

int oscdraw_init(int simulate)
{
	sim_mode = simulate;
	if (!simulate)
		fb_probe();

	for (int i = 0; i < OSCDRAW_SURFACES; i++) {
		od_surf *s = &surf[i];

		s->base      = OSCDRAW_FB_BASE + (uint32_t)i * OSCDRAW_SLOT_PITCH;
		s->w         = OSCDRAW_WIDTH;
		s->h         = OSCDRAW_HEIGHT;
		s->dstride   = (size_t)s->w * 4;
		s->alpha     = 256;
		s->autoflush = 1;
		s->player    = -1;
		s->fd        = -1;
		s->shadow    = calloc((size_t)s->w * s->h, sizeof(uint32_t));
		if (!s->shadow)
			return -1;
		s->dx0 = s->dy0 = s->dx1 = s->dy1 = 0;
	}
	return 0;
}

void oscdraw_close(void)
{
	for (int i = 0; i < OSCDRAW_SURFACES; i++) {
		od_surf *s = &surf[i];

		oscdraw_movie_stop(i);
		free(s->shadow);
		s->shadow = NULL;
		if (s->map) {
			if (sim_mode)
				free(s->map);
			else
				munmap(s->map, s->map_len);
		}
		s->map = NULL;
		s->dev = NULL;
	}
	if (fb_map) {
		munmap(fb_map, fb_len);
		fb_map = NULL;
	}
	if (fb_fd >= 0) {
		close(fb_fd);
		fb_fd = -1;
	}
	if (mem_fd >= 0) {
		close(mem_fd);
		mem_fd = -1;
	}
}

int oscdraw_count(void)  { return OSCDRAW_SURFACES; }
int oscdraw_width(int s) { return (s >= 0 && s < OSCDRAW_SURFACES) ? surf[s].w : 0; }
int oscdraw_height(int s){ return (s >= 0 && s < OSCDRAW_SURFACES) ? surf[s].h : 0; }

/* ------------------------------------------------------------------ */
/* dirty tracking and present                                          */
/* ------------------------------------------------------------------ */
static od_surf *get(int i)
{
	if (i < 0 || i >= OSCDRAW_SURFACES || !surf[i].shadow)
		return NULL;
	return &surf[i];
}

static void dirty(od_surf *s, int x0, int y0, int x1, int y1)
{
	if (s->dx1 <= s->dx0 || s->dy1 <= s->dy0) {
		s->dx0 = x0; s->dy0 = y0; s->dx1 = x1; s->dy1 = y1;
		return;
	}
	if (x0 < s->dx0) s->dx0 = x0;
	if (y0 < s->dy0) s->dy0 = y0;
	if (x1 > s->dx1) s->dx1 = x1;
	if (y1 > s->dy1) s->dy1 = y1;
}

int oscdraw_present(int i)
{
	od_surf *s = get(i);
	int x0, y0, x1, y1;

	if (!s)
		return -1;
	if (s->dx1 <= s->dx0 || s->dy1 <= s->dy0)
		return 0;
	if (surf_map(s) < 0)
		return -1;

	x0 = s->dx0; y0 = s->dy0; x1 = s->dx1; y1 = s->dy1;
	for (int y = y0; y < y1; y++) {
		memcpy(s->dev + (size_t)y * s->dstride + (size_t)x0 * 4,
		       s->shadow + (size_t)y * s->w + x0,
		       (size_t)(x1 - x0) * 4);
	}
	/* Push the write buffer out: the VDMA reads DDR and does not snoop. */
	__sync_synchronize();

	s->dx0 = s->dy0 = s->dx1 = s->dy1 = 0;
	return 0;
}

static void finish(od_surf *s, int i)
{
	if (s->autoflush)
		oscdraw_present(i);
}

void oscdraw_set_alpha(int i, float a)
{
	od_surf *s = get(i);

	if (!s)
		return;
	if (a < 0.0f) a = 0.0f;
	if (a > 1.0f) a = 1.0f;
	s->alpha = (unsigned)(a * 256.0f + 0.5f);
}

void oscdraw_set_auto(int i, int on)
{
	od_surf *s = get(i);

	if (s)
		s->autoflush = on ? 1 : 0;
}

/* ------------------------------------------------------------------ */
/* pixels                                                              */
/* ------------------------------------------------------------------ */
static uint32_t pack(od_color c)
{
	return 0xFF000000u | ((uint32_t)c.r << 16) | ((uint32_t)c.g << 8) | c.b;
}

static uint32_t mix(uint32_t d, uint32_t s, unsigned a)
{
	unsigned dr, dg, db, sr, sg, sb;

	if (a >= 256)
		return s;
	if (a == 0)
		return d;
	dr = (d >> 16) & 0xFF; dg = (d >> 8) & 0xFF; db = d & 0xFF;
	sr = (s >> 16) & 0xFF; sg = (s >> 8) & 0xFF; sb = s & 0xFF;
	dr += ((int)(sr - dr) * (int)a) >> 8;
	dg += ((int)(sg - dg) * (int)a) >> 8;
	db += ((int)(sb - db) * (int)a) >> 8;
	return 0xFF000000u | (dr << 16) | (dg << 8) | db;
}

/* Clip a request to the surface.  w == 0 means the whole surface. */
static int clip(const od_surf *s, od_rect *r)
{
	if (r->w == 0 && r->h == 0 && r->x == 0 && r->y == 0) {
		r->w = s->w;
		r->h = s->h;
	}
	if (r->w < 0) { r->x += r->w; r->w = -r->w; }
	if (r->h < 0) { r->y += r->h; r->h = -r->h; }
	if (r->x < 0) { r->w += r->x; r->x = 0; }
	if (r->y < 0) { r->h += r->y; r->y = 0; }
	if (r->x + r->w > s->w) r->w = s->w - r->x;
	if (r->y + r->h > s->h) r->h = s->h - r->y;
	return (r->w > 0 && r->h > 0);
}

static void span(od_surf *s, int y, int x0, int x1, uint32_t v)
{
	uint32_t *p;

	if (y < 0 || y >= s->h)
		return;
	if (x0 < 0) x0 = 0;
	if (x1 > s->w) x1 = s->w;
	if (x1 <= x0)
		return;

	p = s->shadow + (size_t)y * s->w;
	if (s->alpha >= 256) {
		for (int x = x0; x < x1; x++)
			p[x] = v;
	} else {
		for (int x = x0; x < x1; x++)
			p[x] = mix(p[x], v, s->alpha);
	}
	dirty(s, x0, y, x1, y + 1);
}

/* ------------------------------------------------------------------ */
/* drawing                                                             */
/* ------------------------------------------------------------------ */
int oscdraw_solid(int i, od_color c, od_rect r)
{
	od_surf *s = get(i);
	uint32_t v;

	if (!s || !clip(s, &r))
		return -1;
	oscdraw_movie_stop(i);
	v = pack(c);
	for (int y = r.y; y < r.y + r.h; y++)
		span(s, y, r.x, r.x + r.w, v);
	finish(s, i);
	return 0;
}

int oscdraw_gradient(int i, od_color a, od_color b, float degrees, od_rect r)
{
	od_surf *s = get(i);
	float rad, ca, sa, p0, p1, denom;
	float corner[4];

	if (!s || !clip(s, &r))
		return -1;
	oscdraw_movie_stop(i);

	rad = degrees * (float)M_PI / 180.0f;
	ca  = cosf(rad);
	sa  = sinf(rad);

	/* Normalise the projection over the rectangle's corners. */
	corner[0] = 0.0f;
	corner[1] = (float)(r.w - 1) * ca;
	corner[2] = (float)(r.h - 1) * sa;
	corner[3] = corner[1] + corner[2];
	p0 = p1 = corner[0];
	for (int k = 1; k < 4; k++) {
		if (corner[k] < p0) p0 = corner[k];
		if (corner[k] > p1) p1 = corner[k];
	}
	denom = (p1 - p0);
	if (denom == 0.0f)
		denom = 1.0f;

	for (int y = 0; y < r.h; y++) {
		float base = (float)y * sa - p0;
		uint32_t *row = s->shadow + (size_t)(r.y + y) * s->w;

		for (int x = 0; x < r.w; x++) {
			float t = (base + (float)x * ca) / denom;
			unsigned rr, gg, bb;
			uint32_t v;

			if (t < 0.0f) t = 0.0f;
			if (t > 1.0f) t = 1.0f;
			rr = (unsigned)(a.r + (int)((b.r - a.r) * t));
			gg = (unsigned)(a.g + (int)((b.g - a.g) * t));
			bb = (unsigned)(a.b + (int)((b.b - a.b) * t));
			v = 0xFF000000u | (rr << 16) | (gg << 8) | bb;
			row[r.x + x] = (s->alpha >= 256)
				     ? v : mix(row[r.x + x], v, s->alpha);
		}
	}
	dirty(s, r.x, r.y, r.x + r.w, r.y + r.h);
	finish(s, i);
	return 0;
}

int oscdraw_corners(int i, od_color tl, od_color tr, od_color bl, od_color br,
		    od_rect r)
{
	od_surf *s = get(i);

	if (!s || !clip(s, &r))
		return -1;
	oscdraw_movie_stop(i);

	for (int y = 0; y < r.h; y++) {
		int vq = (r.h > 1) ? (y * 256) / (r.h - 1) : 0;
		int lr = tl.r + (((bl.r - tl.r) * vq) >> 8);
		int lg = tl.g + (((bl.g - tl.g) * vq) >> 8);
		int lb = tl.b + (((bl.b - tl.b) * vq) >> 8);
		int rr = tr.r + (((br.r - tr.r) * vq) >> 8);
		int rg = tr.g + (((br.g - tr.g) * vq) >> 8);
		int rb = tr.b + (((br.b - tr.b) * vq) >> 8);
		uint32_t *row = s->shadow + (size_t)(r.y + y) * s->w;

		for (int x = 0; x < r.w; x++) {
			int uq = (r.w > 1) ? (x * 256) / (r.w - 1) : 0;
			unsigned cr = (unsigned)(lr + (((rr - lr) * uq) >> 8));
			unsigned cg = (unsigned)(lg + (((rg - lg) * uq) >> 8));
			unsigned cb = (unsigned)(lb + (((rb - lb) * uq) >> 8));
			uint32_t v = 0xFF000000u | (cr << 16) | (cg << 8) | cb;

			row[r.x + x] = (s->alpha >= 256)
				     ? v : mix(row[r.x + x], v, s->alpha);
		}
	}
	dirty(s, r.x, r.y, r.x + r.w, r.y + r.h);
	finish(s, i);
	return 0;
}

int oscdraw_rect(int i, od_color c, od_rect r, int t)
{
	od_surf *s = get(i);
	uint32_t v;
	od_rect f;

	if (!s)
		return -1;
	if (t <= 0)
		return oscdraw_solid(i, c, r);

	oscdraw_movie_stop(i);
	f = r;
	if (!clip(s, &f))
		return -1;
	v = pack(c);

	if (t > f.h / 2 + 1) t = f.h / 2 + 1;
	for (int y = f.y; y < f.y + t && y < f.y + f.h; y++)
		span(s, y, f.x, f.x + f.w, v);
	for (int y = f.y + f.h - t; y < f.y + f.h; y++)
		if (y >= f.y + t)
			span(s, y, f.x, f.x + f.w, v);
	for (int y = f.y + t; y < f.y + f.h - t; y++) {
		span(s, y, f.x, f.x + t, v);
		span(s, y, f.x + f.w - t, f.x + f.w, v);
	}
	finish(s, i);
	return 0;
}

int oscdraw_ellipse(int i, od_color c, int cx, int cy, int rx, int ry, int t)
{
	od_surf *s = get(i);
	uint32_t v;

	if (!s || rx <= 0 || ry <= 0)
		return -1;
	oscdraw_movie_stop(i);
	v = pack(c);

	if (t < 0)
		t = 0;
	for (int y = cy - ry; y <= cy + ry; y++) {
		float dy, k, ho, hi;
		int irx, iry;

		if (y < 0 || y >= s->h)
			continue;
		dy = (float)(y - cy) / (float)ry;
		k  = 1.0f - dy * dy;
		if (k < 0.0f)
			continue;
		ho = (float)rx * sqrtf(k);

		if (t == 0) {
			span(s, y, cx - (int)ho, cx + (int)ho + 1, v);
			continue;
		}
		/* Outline: outer span minus the inner ellipse span. */
		irx = rx - t;
		iry = ry - t;
		hi  = 0.0f;
		if (irx > 0 && iry > 0) {
			float dyi = (float)(y - cy) / (float)iry;
			float ki  = 1.0f - dyi * dyi;

			if (ki > 0.0f)
				hi = (float)irx * sqrtf(ki);
		}
		if (hi <= 0.0f) {
			span(s, y, cx - (int)ho, cx + (int)ho + 1, v);
		} else {
			span(s, y, cx - (int)ho, cx - (int)hi, v);
			span(s, y, cx + (int)hi + 1, cx + (int)ho + 1, v);
		}
	}
	finish(s, i);
	return 0;
}

/* ------------------------------------------------------------------ */
/* files: image, movie, snapshot                                       */
/* ------------------------------------------------------------------ */
/* Allow only a plain file name: this port is on the network. */
static int name_ok(const char *n)
{
	if (!n || !*n || *n == '.' || strlen(n) > 96)
		return 0;
	for (const char *p = n; *p; p++) {
		if ((*p >= 'a' && *p <= 'z') || (*p >= 'A' && *p <= 'Z') ||
		    (*p >= '0' && *p <= '9') || *p == '.' || *p == '_' ||
		    *p == '-' || *p == ' ')
			continue;
		return 0;
	}
	return strstr(n, "..") == NULL;
}

int oscdraw_image(int i, const char *name, od_rect r)
{
	od_surf *s = get(i);
	char cmd[512], path[256];
	uint32_t *line;
	FILE *fp;
	int rows = 0;

	if (!s || !name_ok(name))
		return -1;
	if (!clip(s, &r))
		return -1;
	oscdraw_movie_stop(i);

	snprintf(path, sizeof(path), "%s/%s", OSCDRAW_IMG_DIR, name);
	snprintf(cmd, sizeof(cmd),
		 "ffmpeg -hide_banner -loglevel error -i '%s' -frames:v 1 "
		 "-vf scale=%d:%d -pix_fmt bgra -f rawvideo pipe:1",
		 path, r.w, r.h);

	fp = popen(cmd, "r");
	if (!fp) {
		fprintf(stderr, "oscdraw: cannot run ffmpeg\n");
		return -1;
	}
	line = malloc((size_t)r.w * 4);
	if (!line) {
		pclose(fp);
		return -1;
	}
	for (int y = 0; y < r.h; y++) {
		if (fread(line, 4, (size_t)r.w, fp) != (size_t)r.w)
			break;
		uint32_t *row = s->shadow + (size_t)(r.y + y) * s->w + r.x;

		if (s->alpha >= 256)
			memcpy(row, line, (size_t)r.w * 4);
		else
			for (int x = 0; x < r.w; x++)
				row[x] = mix(row[x], line[x] | 0xFF000000u,
					     s->alpha);
		rows++;
	}
	free(line);
	pclose(fp);

	if (rows == 0) {
		fprintf(stderr, "oscdraw: no image data from %s\n", path);
		return -1;
	}
	dirty(s, r.x, r.y, r.x + r.w, r.y + rows);
	finish(s, i);
	return 0;
}

int oscdraw_movie_stop(int i)
{
	od_surf *s = get(i);

	if (!s || s->player <= 0)
		return 0;
	kill(-s->player, SIGTERM);
	waitpid(s->player, NULL, 0);
	s->player = -1;
	return 1;
}

int oscdraw_movie_play(int i, const char *name)
{
	od_surf *s = get(i);
	char cmd[768], path[256];
	pid_t pid;

	if (!s)
		return -1;
	if (!name)
		return oscdraw_movie_stop(i);
	if (!name_ok(name))
		return -1;

	oscdraw_movie_stop(i);
	snprintf(path, sizeof(path), "%s/%s", OSCDRAW_MOVIE_DIR, name);
	if (access(path, R_OK) != 0) {
		fprintf(stderr, "oscdraw: no such movie %s\n", path);
		return -1;
	}
	if (sim_mode)
		return 0;

	/*
	 * The player writes the slot directly, so the shadow no longer
	 * describes the screen.  Any later draw call stops the movie first.
	 */
	snprintf(cmd, sizeof(cmd),
		 "ffmpeg -hide_banner -loglevel error -stream_loop -1 -re -i '%s' "
		 "-vf scale=%d:%d -pix_fmt bgra -f rawvideo pipe:1 "
		 "| %s -a 0x%08X -w %d -h %d -s %u",
		 path, s->w, s->h, OSCDRAW_FBFEED, (unsigned)s->base,
		 s->w, s->h, (unsigned)s->dstride);

	pid = fork();
	if (pid < 0)
		return -1;
	if (pid == 0) {
		setsid();		/* own group, so we can stop the pipe */
		execl("/bin/sh", "sh", "-c", cmd, (char *)NULL);
		_exit(127);
	}
	s->player = pid;
	return 0;
}

int oscdraw_save(int i, const char *name)
{
	od_surf *s = get(i);
	char path[256];
	FILE *fp;

	if (!s || !name_ok(name))
		return -1;
	snprintf(path, sizeof(path), "%s/%s.ppm", OSCDRAW_IMG_DIR, name);
	fp = fopen(path, "wb");
	if (!fp)
		return -1;
	fprintf(fp, "P6\n%d %d\n255\n", s->w, s->h);
	for (int y = 0; y < s->h; y++) {
		for (int x = 0; x < s->w; x++) {
			uint32_t v = s->shadow[(size_t)y * s->w + x];
			uint8_t px[3] = { (uint8_t)(v >> 16), (uint8_t)(v >> 8),
					  (uint8_t)v };

			fwrite(px, 1, 3, fp);
		}
	}
	fclose(fp);
	return 0;
}

/* ------------------------------------------------------------------ */
/* OSC front end                                                       */
/* ------------------------------------------------------------------ */
static uint8_t comp(const oscreg_arg *a)
{
	if (a->type == 'f') {
		float v = a->f;

		if (v <= 0.0f) return 0;
		if (v >= 1.0f) return 255;
		return (uint8_t)(v * 255.0f + 0.5f);
	}
	if (a->i <= 0) return 0;
	if (a->i >= 255) return 255;
	return (uint8_t)a->i;
}

static od_color argc3(const oscreg_arg *a, int i)
{
	return OD_RGB(comp(&a[i]), comp(&a[i + 1]), comp(&a[i + 2]));
}

/* Optional trailing rectangle: x y w h. */
static od_rect argrect(const oscreg_arg *a, int n, int i)
{
	od_rect r = OD_ALL;

	if (n >= i + 4) {
		r.x = a[i].i;
		r.y = a[i + 1].i;
		r.w = a[i + 2].i;
		r.h = a[i + 3].i;
	}
	return r;
}

/* "/draw/2/solid" -> group "draw", surfaces {2}, tail "solid" */
static int split(const char *path, const char *group, unsigned *mask,
		 const char **tail)
{
	size_t gl = strlen(group);
	const char *p, *q;

	if (path[0] != '/' || strncmp(path + 1, group, gl) != 0 ||
	    path[1 + gl] != '/')
		return 0;
	p = path + 2 + gl;
	q = strchr(p, '/');

	*mask = 0;
	if (*p == '*') {
		*mask = (1u << OSCDRAW_SURFACES) - 1u;
	} else {
		int v = 0, any = 0;

		for (const char *c = p; c != q && *c; c++) {
			if (*c < '0' || *c > '9')
				return 0;
			v = v * 10 + (*c - '0');
			any = 1;
		}
		if (!any || v >= OSCDRAW_SURFACES)
			return 0;
		*mask = 1u << v;
	}
	*tail = q ? q + 1 : "";
	return 1;
}

int oscdraw_dispatch(const char *path, const oscreg_arg *a, int n, int verbose)
{
	unsigned mask = 0;
	const char *op = NULL;
	int hits = 0;

	if (split(path, "draw", &mask, &op)) {
		for (int i = 0; i < OSCDRAW_SURFACES; i++) {
			if (!(mask & (1u << i)))
				continue;

			if (!strcmp(op, "solid") && n >= 3) {
				oscdraw_solid(i, argc3(a, 0), argrect(a, n, 3));
			} else if (!strcmp(op, "clear")) {
				od_color c = (n >= 3) ? argc3(a, 0) : OD_RGB(0, 0, 0);

				oscdraw_solid(i, c, OD_ALL);
			} else if (!strcmp(op, "gradient/h") && n >= 6) {
				oscdraw_gradient(i, argc3(a, 0), argc3(a, 3),
						 0.0f, argrect(a, n, 6));
			} else if (!strcmp(op, "gradient/v") && n >= 6) {
				oscdraw_gradient(i, argc3(a, 0), argc3(a, 3),
						 90.0f, argrect(a, n, 6));
			} else if (!strcmp(op, "gradient/angle") && n >= 7) {
				oscdraw_gradient(i, argc3(a, 1), argc3(a, 4),
						 a[0].f, argrect(a, n, 7));
			} else if (!strcmp(op, "gradient/corners") && n >= 12) {
				oscdraw_corners(i, argc3(a, 0), argc3(a, 3),
						argc3(a, 6), argc3(a, 9),
						argrect(a, n, 12));
			} else if (!strcmp(op, "rect") && n >= 7) {
				od_rect r = { a[3].i, a[4].i, a[5].i, a[6].i };

				oscdraw_rect(i, argc3(a, 0), r,
					     n >= 8 ? a[7].i : 0);
			} else if (!strcmp(op, "square") && n >= 6) {
				od_rect r = { a[3].i, a[4].i, a[5].i, a[5].i };

				oscdraw_rect(i, argc3(a, 0), r,
					     n >= 7 ? a[6].i : 0);
			} else if (!strcmp(op, "circle") && n >= 6) {
				oscdraw_ellipse(i, argc3(a, 0), a[3].i, a[4].i,
						a[5].i, a[5].i,
						n >= 7 ? a[6].i : 0);
			} else if (!strcmp(op, "ellipse") && n >= 7) {
				oscdraw_ellipse(i, argc3(a, 0), a[3].i, a[4].i,
						a[5].i, a[6].i,
						n >= 8 ? a[7].i : 0);
			} else if (!strcmp(op, "alpha") && n >= 1) {
				oscdraw_set_alpha(i, a[0].type == 'f'
						  ? a[0].f : (float)a[0].i);
			} else {
				continue;
			}
			hits++;
			if (verbose)
				fprintf(stderr, "oscdraw: surface %d %s\n", i, op);
		}
		return hits;
	}

	if (split(path, "img", &mask, &op)) {
		for (int i = 0; i < OSCDRAW_SURFACES; i++) {
			if (!(mask & (1u << i)))
				continue;
			if (!strcmp(op, "load") && n >= 1 && a[0].type == 's') {
				int ok = oscdraw_image(i, a[0].s,
						       argrect(a, n, 1)) == 0;

				hits++;	/* the address was ours either way */
				if (verbose)
					fprintf(stderr, "oscdraw: surface %d img %s%s\n",
						i, a[0].s, ok ? "" : " FAILED");
			}
		}
		return hits;
	}

	if (split(path, "movie", &mask, &op)) {
		for (int i = 0; i < OSCDRAW_SURFACES; i++) {
			if (!(mask & (1u << i)))
				continue;
			if (!strcmp(op, "play") && n >= 1 && a[0].type == 's') {
				int ok = oscdraw_movie_play(i, a[0].s) == 0;

				hits++;
				if (verbose)
					fprintf(stderr, "oscdraw: surface %d movie %s%s\n",
						i, a[0].s, ok ? "" : " FAILED");
			} else if (!strcmp(op, "stop")) {
				oscdraw_movie_stop(i);
				hits++;
			}
		}
		return hits;
	}

	if (split(path, "surface", &mask, &op)) {
		for (int i = 0; i < OSCDRAW_SURFACES; i++) {
			if (!(mask & (1u << i)))
				continue;
			if (!strcmp(op, "present")) {
				od_surf *s = get(i);

				if (s) {	/* force a full copy */
					dirty(s, 0, 0, s->w, s->h);
					oscdraw_present(i);
					hits++;
				}
			} else if (!strcmp(op, "auto") && n >= 1) {
				oscdraw_set_auto(i, a[0].i);
				hits++;
			} else if (!strcmp(op, "save") && n >= 1 &&
				   a[0].type == 's') {
				int ok = oscdraw_save(i, a[0].s) == 0;

				hits++;
				if (verbose)
					fprintf(stderr, "oscdraw: surface %d save %s%s\n",
						i, a[0].s, ok ? "" : " FAILED");
			}
		}
		return hits;
	}
	return 0;
}

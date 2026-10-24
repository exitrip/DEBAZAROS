/*
 * oscreg - OSC control surface for the DEBAZAROS PL register map.
 * See oscreg.h for the address rules.  Build with -DOSCREG_MAIN for the daemon.
 */
#define _GNU_SOURCE
#include "oscreg.h"

#include <arpa/inet.h>
#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <netinet/in.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <unistd.h>

volatile sig_atomic_t oscreg_stop;

/* ------------------------------------------------------------------ */
/* 1. the register map                                                 */
/* ------------------------------------------------------------------ */
/*
 * colorGain words pack one byte per colour in [23:0].
 * R = [23:16], G = [15:8], B = [7:0].  Flip here if the hardware differs;
 * "devmem 0x41210000 32 0" blacks out BD HDMI_0, "0x00ffffff" restores it.
 */
#define GAIN_R_LO	16
#define GAIN_G_LO	8
#define GAIN_B_LO	0

static const oscreg_field static_fields[] = {
/*   path                    base                    off              lo width unit ro help */
{ "/hdmi/0/gain/r",   OSCREG_HDMI0_GAIN_BASE, OSCREG_GPIO_CH1, GAIN_R_LO, 8,  OSCREG_RAW,  0, "HDMI_0 main red gain" },
{ "/hdmi/0/gain/g",   OSCREG_HDMI0_GAIN_BASE, OSCREG_GPIO_CH1, GAIN_G_LO, 8,  OSCREG_RAW,  0, "HDMI_0 main green gain" },
{ "/hdmi/0/gain/b",   OSCREG_HDMI0_GAIN_BASE, OSCREG_GPIO_CH1, GAIN_B_LO, 8,  OSCREG_RAW,  0, "HDMI_0 main blue gain" },
{ "/hdmi/0/gain/rgb", OSCREG_HDMI0_GAIN_BASE, OSCREG_GPIO_CH1, 0,        24,  OSCREG_RGB,  0, "HDMI_0 main gains, 1 or 3 args" },
{ "/hdmi/0/hpd",      OSCREG_HDMI0_HPD_BASE,  OSCREG_GPIO_CH1, 0,        32,  OSCREG_RAW,  1, "HDMI_0 hot plug detect" },

{ "/hdmi/1/gain/r",   OSCREG_HDMI1_GAIN_BASE, OSCREG_GPIO_CH1, GAIN_R_LO, 8,  OSCREG_RAW,  0, "HDMI_1 main red gain" },
{ "/hdmi/1/gain/g",   OSCREG_HDMI1_GAIN_BASE, OSCREG_GPIO_CH1, GAIN_G_LO, 8,  OSCREG_RAW,  0, "HDMI_1 main green gain" },
{ "/hdmi/1/gain/b",   OSCREG_HDMI1_GAIN_BASE, OSCREG_GPIO_CH1, GAIN_B_LO, 8,  OSCREG_RAW,  0, "HDMI_1 main blue gain" },
{ "/hdmi/1/gain/rgb", OSCREG_HDMI1_GAIN_BASE, OSCREG_GPIO_CH1, 0,        24,  OSCREG_RGB,  0, "HDMI_1 main gains, 1 or 3 args" },

{ "/hdmi/1/dds/r",    OSCREG_HDMI1_GAIN_BASE, OSCREG_GPIO_CH2, GAIN_R_LO, 8,  OSCREG_RAW,  0, "HDMI_1 DDS layer red gain" },
{ "/hdmi/1/dds/g",    OSCREG_HDMI1_GAIN_BASE, OSCREG_GPIO_CH2, GAIN_G_LO, 8,  OSCREG_RAW,  0, "HDMI_1 DDS layer green gain" },
{ "/hdmi/1/dds/b",    OSCREG_HDMI1_GAIN_BASE, OSCREG_GPIO_CH2, GAIN_B_LO, 8,  OSCREG_RAW,  0, "HDMI_1 DDS layer blue gain" },
{ "/hdmi/1/dds/rgb",  OSCREG_HDMI1_GAIN_BASE, OSCREG_GPIO_CH2, 0,        24,  OSCREG_RGB,  0, "HDMI_1 DDS layer gains" },

{ "/hdmi/1/fb/a/r",   OSCREG_HDMI1_FB_BASE,   OSCREG_GPIO_CH1, GAIN_R_LO, 8,  OSCREG_RAW,  0, "feedback A (HDMI_0 pixel) red" },
{ "/hdmi/1/fb/a/g",   OSCREG_HDMI1_FB_BASE,   OSCREG_GPIO_CH1, GAIN_G_LO, 8,  OSCREG_RAW,  0, "feedback A (HDMI_0 pixel) green" },
{ "/hdmi/1/fb/a/b",   OSCREG_HDMI1_FB_BASE,   OSCREG_GPIO_CH1, GAIN_B_LO, 8,  OSCREG_RAW,  0, "feedback A (HDMI_0 pixel) blue" },
{ "/hdmi/1/fb/a/rgb", OSCREG_HDMI1_FB_BASE,   OSCREG_GPIO_CH1, 0,        24,  OSCREG_RGB,  0, "feedback A gains" },
{ "/hdmi/1/fb/b/r",   OSCREG_HDMI1_FB_BASE,   OSCREG_GPIO_CH2, GAIN_R_LO, 8,  OSCREG_RAW,  0, "feedback B (own video) red" },
{ "/hdmi/1/fb/b/g",   OSCREG_HDMI1_FB_BASE,   OSCREG_GPIO_CH2, GAIN_G_LO, 8,  OSCREG_RAW,  0, "feedback B (own video) green" },
{ "/hdmi/1/fb/b/b",   OSCREG_HDMI1_FB_BASE,   OSCREG_GPIO_CH2, GAIN_B_LO, 8,  OSCREG_RAW,  0, "feedback B (own video) blue" },
{ "/hdmi/1/fb/b/rgb", OSCREG_HDMI1_FB_BASE,   OSCREG_GPIO_CH2, 0,        24,  OSCREG_RGB,  0, "feedback B gains" },
{ "/hdmi/1/hpd",      OSCREG_HDMI1_HPD_BASE,  OSCREG_GPIO_CH1, 0,        32,  OSCREG_RAW,  1, "HDMI_1 hot plug detect" },

{ "/dds/0/hz",        OSCREG_DDS0_BASE,       OSCREG_DDS_CTRL,  0,       31,  OSCREG_HZ,   0, "HDMI_0 DDS frequency, Hz" },
{ "/dds/0/pinc",      OSCREG_DDS0_BASE,       OSCREG_DDS_CTRL,  0,       31,  OSCREG_RAW,  0, "HDMI_0 DDS phase increment, raw" },
{ "/dds/0/enable",    OSCREG_DDS0_BASE,       OSCREG_DDS_CTRL, 31,        1,  OSCREG_BOOL, 0, "HDMI_0 DDS TVALID" },
{ "/dds/0/offset",    OSCREG_DDS0_SHIFT_BASE, OSCREG_GPIO_CH1,  0,       32,  OSCREG_RAW,  0, "HDMI_0 DDS DC offset (c_addsub B)" },
{ "/dds/1/hz",        OSCREG_DDS1_BASE,       OSCREG_DDS_CTRL,  0,       31,  OSCREG_HZ,   0, "HDMI_1 DDS frequency, Hz" },
{ "/dds/1/pinc",      OSCREG_DDS1_BASE,       OSCREG_DDS_CTRL,  0,       31,  OSCREG_RAW,  0, "HDMI_1 DDS phase increment, raw" },
{ "/dds/1/enable",    OSCREG_DDS1_BASE,       OSCREG_DDS_CTRL, 31,        1,  OSCREG_BOOL, 0, "HDMI_1 DDS TVALID" },
{ "/dds/1/offset",    OSCREG_DDS1_SHIFT_BASE, OSCREG_GPIO_CH1,  0,       32,  OSCREG_RAW,  0, "HDMI_1 DDS DC offset" },

{ "/led",             OSCREG_LED_BASE,        OSCREG_GPIO_CH1,  0,        1,  OSCREG_BOOL, 0, "green LED (W13)" },
};

/* Mixer endpoints are generated: 9 channels x (5 gains + 5 controls). */
#define MIX_PER_CHAN	10
#define N_STATIC	((int)(sizeof(static_fields) / sizeof(static_fields[0])))
#define N_MIXER		(OSCREG_MIX_CHANS * MIX_PER_CHAN)
#define N_FIELDS	(N_STATIC + N_MIXER)

static oscreg_field fields[N_FIELDS];
static char         path_pool[N_MIXER][32];
static int          n_fields;

/* ------------------------------------------------------------------ */
/* 2. peripheral mapping (UIO first, /dev/mem as fallback)             */
/* ------------------------------------------------------------------ */
typedef struct {
	uint32_t  base;
	uint32_t  max_off;		/* highest byte offset the table uses */
	volatile uint32_t *map;
	int       fd;
	uint32_t *shadow;		/* last written value, for read-modify-write */
	uint8_t  *shadow_ok;
	char      src[24];
} oscreg_dev;

#define MAX_DEVS	16
static oscreg_dev devs[MAX_DEVS];
static int        n_devs;
static int        mem_fd = -1;
static int        sim_mode;

static oscreg_dev *dev_for(uint32_t base)
{
	for (int i = 0; i < n_devs; i++)
		if (devs[i].base == base)
			return &devs[i];
	return NULL;
}

/* Look for a UIO node whose map0 address equals base.  Returns fd or -1. */
static int uio_open(uint32_t base, char *src, size_t srclen)
{
	DIR *d = opendir("/sys/class/uio");
	struct dirent *e;
	int fd = -1;

	if (!d)
		return -1;

	while ((e = readdir(d)) != NULL) {
		char p[512], buf[64];
		FILE *fp;
		unsigned long addr = 0;

		if (strncmp(e->d_name, "uio", 3) != 0)
			continue;

		snprintf(p, sizeof(p), "/sys/class/uio/%s/maps/map0/addr", e->d_name);
		fp = fopen(p, "r");
		if (!fp)
			continue;
		if (fgets(buf, sizeof(buf), fp))
			addr = strtoul(buf, NULL, 0);
		fclose(fp);

		if (addr != base)
			continue;

		snprintf(p, sizeof(p), "/dev/%s", e->d_name);
		fd = open(p, O_RDWR | O_SYNC);
		if (fd >= 0)
			snprintf(src, srclen, "%.15s", e->d_name);
		break;
	}
	closedir(d);
	return fd;
}

static int dev_map(oscreg_dev *dv)
{
	size_t words = dv->max_off / 4 + 1;

	dv->shadow    = calloc(words, sizeof(uint32_t));
	dv->shadow_ok = calloc(words, 1);
	if (!dv->shadow || !dv->shadow_ok)
		return -1;

	if (sim_mode) {
		dv->map = calloc(OSCREG_MAP_SIZE / 4, sizeof(uint32_t));
		dv->fd  = -1;
		snprintf(dv->src, sizeof(dv->src), "sim");
		return dv->map ? 0 : -1;
	}

	dv->fd = uio_open(dv->base, dv->src, sizeof(dv->src));
	if (dv->fd >= 0) {
		dv->map = mmap(NULL, OSCREG_MAP_SIZE, PROT_READ | PROT_WRITE,
			       MAP_SHARED, dv->fd, 0);
		if (dv->map != MAP_FAILED)
			return 0;
		close(dv->fd);
		dv->fd = -1;
	}

	if (mem_fd < 0) {
		mem_fd = open("/dev/mem", O_RDWR | O_SYNC);
		if (mem_fd < 0) {
			fprintf(stderr, "oscreg: open /dev/mem: %s\n", strerror(errno));
			return -1;
		}
	}
	dv->map = mmap(NULL, OSCREG_MAP_SIZE, PROT_READ | PROT_WRITE,
		       MAP_SHARED, mem_fd, (off_t)dv->base);
	if (dv->map == MAP_FAILED) {
		fprintf(stderr, "oscreg: mmap 0x%08X: %s\n",
			(unsigned)dv->base, strerror(errno));
		dv->map = NULL;
		return -1;
	}
	snprintf(dv->src, sizeof(dv->src), "mem");
	return 0;
}

/* ------------------------------------------------------------------ */
/* 3. table build + field access                                       */
/* ------------------------------------------------------------------ */
static void add_dev(uint32_t base, uint32_t off)
{
	oscreg_dev *dv = dev_for(base);

	if (dv) {
		if (off > dv->max_off)
			dv->max_off = off;
		return;
	}
	if (n_devs >= MAX_DEVS)
		return;
	devs[n_devs].base    = base;
	devs[n_devs].max_off = off;
	n_devs++;
}

static void build_table(void)
{
	int k = 0, pool = 0;

	if (n_fields)
		return;		/* idempotent */

	memcpy(fields, static_fields, sizeof(static_fields));
	k = N_STATIC;

	for (int c = 0; c < OSCREG_MIX_CHANS; c++) {
		for (int n = 0; n < OSCREG_MIX_GAINS; n++) {
			oscreg_field *f = &fields[k++];

			snprintf(path_pool[pool], sizeof(path_pool[0]),
				 "/mixer/%d/gain/%d", c, n);
			f->path  = path_pool[pool++];
			f->base  = OSCREG_MIXER0_BASE;
			f->off   = OSCREG_MIX_REG(c, n);
			f->lo    = 0;
			f->width = 32;
			f->unit  = OSCREG_RAW;
			f->ro    = 0;
			f->help  = "mixer gain for din0..din4";
		}
		/* CTRL0: mode [7:0], K [31:16] */
		{
			oscreg_field *f = &fields[k++];

			snprintf(path_pool[pool], sizeof(path_pool[0]), "/mixer/%d/mode", c);
			f->path = path_pool[pool++];
			f->base = OSCREG_MIXER0_BASE;
			f->off  = OSCREG_MIX_REG(c, OSCREG_MIX_CTRL0);
			f->lo = 0; f->width = 8; f->unit = OSCREG_RAW; f->ro = 0;
			f->help = "0 zero, 1 MAC, 3 pass, 4 const K, 0x10-0x13 clip, 0x20-0x23 clip to K";
		}
		{
			oscreg_field *f = &fields[k++];

			snprintf(path_pool[pool], sizeof(path_pool[0]), "/mixer/%d/k", c);
			f->path = path_pool[pool++];
			f->base = OSCREG_MIXER0_BASE;
			f->off  = OSCREG_MIX_REG(c, OSCREG_MIX_CTRL0);
			f->lo = 16; f->width = 16; f->unit = OSCREG_RAW; f->ro = 0;
			f->help = "constant K used by modes 4 and 0x20-0x23";
		}
		/* CTRL1: stream [0], lo [23:16], hi [31:24] */
		{
			oscreg_field *f = &fields[k++];

			snprintf(path_pool[pool], sizeof(path_pool[0]), "/mixer/%d/stream", c);
			f->path = path_pool[pool++];
			f->base = OSCREG_MIXER0_BASE;
			f->off  = OSCREG_MIX_REG(c, OSCREG_MIX_CTRL1);
			f->lo = 0; f->width = 1; f->unit = OSCREG_BOOL; f->ro = 0;
			f->help = "0 = stream A (din0/1/2), 1 = stream B (din5/6/7)";
		}
		{
			oscreg_field *f = &fields[k++];

			snprintf(path_pool[pool], sizeof(path_pool[0]), "/mixer/%d/lo", c);
			f->path = path_pool[pool++];
			f->base = OSCREG_MIXER0_BASE;
			f->off  = OSCREG_MIX_REG(c, OSCREG_MIX_CTRL1);
			f->lo = 16; f->width = 8; f->unit = OSCREG_RAW; f->ro = 0;
			f->help = "clip threshold low";
		}
		{
			oscreg_field *f = &fields[k++];

			snprintf(path_pool[pool], sizeof(path_pool[0]), "/mixer/%d/hi", c);
			f->path = path_pool[pool++];
			f->base = OSCREG_MIXER0_BASE;
			f->off  = OSCREG_MIX_REG(c, OSCREG_MIX_CTRL1);
			f->lo = 24; f->width = 8; f->unit = OSCREG_RAW; f->ro = 0;
			f->help = "clip threshold high";
		}
	}
	n_fields = k;

	for (int i = 0; i < n_fields; i++)
		add_dev(fields[i].base, fields[i].off);
}

int oscreg_count(void)
{
	return n_fields;
}

const oscreg_field *oscreg_at(int index)
{
	return (index >= 0 && index < n_fields) ? &fields[index] : NULL;
}

const oscreg_field *oscreg_find(const char *path)
{
	for (int i = 0; i < n_fields; i++)
		if (strcmp(fields[i].path, path) == 0)
			return &fields[i];
	return NULL;
}

static uint32_t field_mask(const oscreg_field *f)
{
	return (f->width >= 32) ? 0xFFFFFFFFu : ((1u << f->width) - 1u);
}

int oscreg_read(const oscreg_field *f, uint32_t *raw)
{
	oscreg_dev *dv = dev_for(f->base);

	if (!dv || !dv->map)
		return -1;
	*raw = (dv->map[f->off / 4] >> f->lo) & field_mask(f);
	return 0;
}

int oscreg_write(const oscreg_field *f, uint32_t raw)
{
	oscreg_dev *dv = dev_for(f->base);
	uint32_t idx, mask, cur, val;

	if (!dv || !dv->map)
		return -1;
	if (f->ro)
		return -2;

	idx  = f->off / 4;
	mask = field_mask(f) << f->lo;

	/*
	 * Read-modify-write against a shadow copy.  Several of these registers
	 * share one word (mode + K, stream + lo + hi, R + G + B), and a write
	 * only register would return rubbish if we read the hardware back.
	 * The first touch seeds the shadow from the device, which is correct
	 * for every readable register here and keeps boot state from the
	 * startup script.
	 */
	if (!dv->shadow_ok[idx]) {
		dv->shadow[idx]    = dv->map[idx];
		dv->shadow_ok[idx] = 1;
	}
	cur = dv->shadow[idx];
	val = (cur & ~mask) | ((raw & field_mask(f)) << f->lo);

	dv->map[idx]    = val;
	dv->shadow[idx] = val;
	return 0;
}

uint32_t oscreg_from_float(const oscreg_field *f, float v)
{
	uint32_t max = field_mask(f);

	switch (f->unit) {
	case OSCREG_BOOL:
		return v != 0.0f ? 1u : 0u;
	case OSCREG_HZ: {
		double pinc;

		if (v < 0.0f)
			v = 0.0f;
		/* pinc = f_out * 2^32 / f_clk */
		pinc = (double)v * 4294967296.0 / OSCREG_DDS_CLK_HZ;
		if (pinc > (double)max)
			pinc = (double)max;
		return (uint32_t)(pinc + 0.5);
	}
	default:
		if (v <= 0.0f)
			return 0u;
		if (v >= 1.0f)
			return max;
		return (uint32_t)((double)v * (double)max + 0.5);
	}
}

float oscreg_to_float(const oscreg_field *f, uint32_t raw)
{
	uint32_t max = field_mask(f);

	switch (f->unit) {
	case OSCREG_BOOL:
		return raw ? 1.0f : 0.0f;
	case OSCREG_HZ:
		return (float)((double)raw * OSCREG_DDS_CLK_HZ / 4294967296.0);
	default:
		return max ? (float)((double)raw / (double)max) : 0.0f;
	}
}

void oscreg_build(void)
{
	build_table();
}

int oscreg_init(int simulate)
{
	sim_mode = simulate;
	build_table();

	for (int i = 0; i < n_devs; i++) {
		if (dev_map(&devs[i]) < 0) {
			fprintf(stderr, "oscreg: cannot map 0x%08X\n",
				(unsigned)devs[i].base);
			return -1;
		}
	}
	return 0;
}

void oscreg_close(void)
{
	for (int i = 0; i < n_devs; i++) {
		if (!devs[i].map)
			continue;
		if (sim_mode)
			free((void *)devs[i].map);
		else
			munmap((void *)devs[i].map, OSCREG_MAP_SIZE);
		if (devs[i].fd >= 0)
			close(devs[i].fd);
		free(devs[i].shadow);
		free(devs[i].shadow_ok);
		memset(&devs[i], 0, sizeof(devs[i]));
	}
	n_devs = 0;
	if (mem_fd >= 0) {
		close(mem_fd);
		mem_fd = -1;
	}
}

/* ------------------------------------------------------------------ */
/* 4. OSC 1.0 wire format                                              */
/* ------------------------------------------------------------------ */
static uint32_t rd_be32(const uint8_t *p)
{
	return ((uint32_t)p[0] << 24) | ((uint32_t)p[1] << 16) |
	       ((uint32_t)p[2] << 8) | (uint32_t)p[3];
}

static void wr_be32(uint8_t *p, uint32_t v)
{
	p[0] = (uint8_t)(v >> 24);
	p[1] = (uint8_t)(v >> 16);
	p[2] = (uint8_t)(v >> 8);
	p[3] = (uint8_t)v;
}

static float rd_bef(const uint8_t *p)
{
	uint32_t u = rd_be32(p);
	float f;

	memcpy(&f, &u, sizeof(f));
	return f;
}

static size_t pad4(size_t n)
{
	return (n + 3u) & ~(size_t)3u;
}

/* Read a padded OSC string.  Returns its length or 0 on error. */
static size_t osc_str(const uint8_t *b, size_t len, size_t pos, const char **out)
{
	size_t end = pos;

	while (end < len && b[end] != '\0')
		end++;
	if (end >= len)
		return 0;
	*out = (const char *)(b + pos);
	return pad4(end - pos + 1);
}

/* ---- OSC address pattern matching: ? * [] {} ---- */
static int match_class(const char **pp, char c)
{
	const char *p = *pp + 1;
	int neg = 0, ok = 0;

	if (*p == '!') {
		neg = 1;
		p++;
	}
	while (*p && *p != ']') {
		if (p[1] == '-' && p[2] && p[2] != ']') {
			if (c >= p[0] && c <= p[2])
				ok = 1;
			p += 3;
		} else {
			if (c == *p)
				ok = 1;
			p++;
		}
	}
	if (*p == ']')
		p++;
	*pp = p;
	return neg ? !ok : ok;
}

static int match_here(const char *p, const char *s)
{
	while (*p) {
		if (*p == '*') {
			p++;
			for (const char *q = s;; q++) {
				if (match_here(p, q))
					return 1;
				if (*q == '\0' || *q == '/')
					break;
			}
			return 0;
		}
		if (*p == '?') {
			if (*s == '\0' || *s == '/')
				return 0;
			p++;
			s++;
			continue;
		}
		if (*p == '[') {
			const char *pp = p;

			if (*s == '\0' || *s == '/')
				return 0;
			if (!match_class(&pp, *s))
				return 0;
			p = pp;
			s++;
			continue;
		}
		if (*p == '{') {
			const char *e = strchr(p, '}');
			const char *a;

			if (!e)
				return 0;
			a = p + 1;
			while (a <= e) {
				const char *b = a;
				size_t n;

				while (b < e && *b != ',')
					b++;
				n = (size_t)(b - a);
				if (strncmp(s, a, n) == 0 && match_here(e + 1, s + n))
					return 1;
				a = b + 1;
			}
			return 0;
		}
		if (*p != *s)
			return 0;
		p++;
		s++;
	}
	return *s == '\0';
}

/* ------------------------------------------------------------------ */
/* 5. dispatch                                                         */
/* ------------------------------------------------------------------ */
typedef struct {
	int   sock;
	const struct sockaddr *to;
	socklen_t tolen;
} osc_reply;

static void osc_send(const osc_reply *r, const char *path, const char *tags, ...)
{
	uint8_t buf[512];
	size_t n = 0, tl;
	va_list ap;

	if (!r || r->sock < 0)
		return;

	tl = strlen(path) + 1;
	if (pad4(tl) + 8 > sizeof(buf))
		return;
	memset(buf, 0, pad4(tl));
	memcpy(buf, path, tl);
	n = pad4(tl);

	{
		char tt[16];

		snprintf(tt, sizeof(tt), ",%s", tags);
		tl = strlen(tt) + 1;
		memset(buf + n, 0, pad4(tl));
		memcpy(buf + n, tt, tl);
		n += pad4(tl);
	}

	va_start(ap, tags);
	for (const char *t = tags; *t; t++) {
		if (*t == 'i') {
			if (n + 4 > sizeof(buf))
				break;
			wr_be32(buf + n, (uint32_t)va_arg(ap, int));
			n += 4;
		} else if (*t == 'f') {
			float f = (float)va_arg(ap, double);
			uint32_t u;

			if (n + 4 > sizeof(buf))
				break;
			memcpy(&u, &f, 4);
			wr_be32(buf + n, u);
			n += 4;
		} else if (*t == 's') {
			const char *s = va_arg(ap, const char *);
			size_t sl = strlen(s) + 1;

			if (n + pad4(sl) > sizeof(buf))
				break;
			memset(buf + n, 0, pad4(sl));
			memcpy(buf + n, s, sl);
			n += pad4(sl);
		}
	}
	va_end(ap);

	sendto(r->sock, buf, n, 0, r->to, r->tolen);
}

static oscreg_handler extra_handler;

void oscreg_set_handler(oscreg_handler h)
{
	extra_handler = h;
}

static uint32_t arg_to_raw(const oscreg_field *f, const oscreg_arg *a)
{
	if (a->type == 'f')
		return oscreg_from_float(f, a->f);
	/* ints are raw, except HZ where an int is still Hz */
	if (f->unit == OSCREG_HZ)
		return oscreg_from_float(f, (float)a->i);
	return (uint32_t)a->i & field_mask(f);
}

static void apply(const oscreg_field *f, const oscreg_arg *args, int nargs,
		  int verbose)
{
	uint32_t raw;

	if (nargs <= 0)
		return;

	if (f->unit == OSCREG_RGB && nargs >= 3) {
		uint32_t r, g, b;
		oscreg_field byte = *f;

		byte.width = 8;
		byte.unit  = OSCREG_RAW;
		r = arg_to_raw(&byte, &args[0]);
		g = arg_to_raw(&byte, &args[1]);
		b = arg_to_raw(&byte, &args[2]);
		raw = (r << 16) | (g << 8) | b;
	} else if (f->unit == OSCREG_RGB && args[0].type == 'f') {
		oscreg_field byte = *f;
		uint32_t v;

		byte.width = 8;
		byte.unit  = OSCREG_RAW;
		v = arg_to_raw(&byte, &args[0]);	/* one float = grey level */
		raw = (v << 16) | (v << 8) | v;
	} else {
		raw = arg_to_raw(f, &args[0]);
	}

	if (oscreg_write(f, raw) == 0) {
		if (verbose)
			fprintf(stderr, "oscreg: %-22s <- 0x%08X (%u)\n",
				f->path, (unsigned)raw, (unsigned)raw);
	} else if (verbose) {
		fprintf(stderr, "oscreg: %-22s write refused\n", f->path);
	}
}

static void do_query(const osc_reply *r, const char *path)
{
	const oscreg_field *f = oscreg_find(path);
	uint32_t raw = 0;

	if (!f) {
		osc_send(r, "/error", "ss", "no such endpoint", path);
		return;
	}
	oscreg_read(f, &raw);
	osc_send(r, "/value", "sif", f->path, (int)raw,
		 (double)oscreg_to_float(f, raw));
}

static void do_list(const osc_reply *r)
{
	for (int i = 0; i < n_fields; i++)
		osc_send(r, "/entry", "ss", fields[i].path, fields[i].help);
	osc_send(r, "/entry/end", "i", n_fields);
}

static int handle_message(const uint8_t *b, size_t len, const osc_reply *r,
			  int verbose)
{
	const char *path = NULL, *tags = NULL;
	size_t pos = 0, step;
	oscreg_arg args[OSCREG_MAX_ARGS];
	int nargs = 0, hits = 0;

	step = osc_str(b, len, pos, &path);
	if (!step)
		return -1;
	pos += step;

	if (pos < len) {
		step = osc_str(b, len, pos, &tags);
		if (step && tags[0] == ',')
			pos += step;
		else
			tags = NULL;
	}

	for (const char *t = tags ? tags + 1 : "";
	     *t && nargs < OSCREG_MAX_ARGS; t++) {
		oscreg_arg *a = &args[nargs];

		memset(a, 0, sizeof(*a));
		switch (*t) {
		case 'i':
			if (pos + 4 > len)
				return -1;
			a->type = 'i';
			a->i = (int32_t)rd_be32(b + pos);
			a->f = (float)a->i;
			pos += 4;
			break;
		case 'f':
			if (pos + 4 > len)
				return -1;
			a->type = 'f';
			a->f = rd_bef(b + pos);
			a->i = (int)a->f;
			pos += 4;
			break;
		case 'T':
		case 'F':
			a->type = 'i';
			a->i = (*t == 'T');
			a->f = (float)a->i;
			break;
		case 's': {
			const char *s = NULL;

			step = osc_str(b, len, pos, &s);
			if (!step)
				return -1;
			a->type = 's';
			a->s = s;
			pos += step;
			break;
		}
		case 'b': {
			uint32_t sz;

			if (pos + 4 > len)
				return -1;
			sz = rd_be32(b + pos);
			pos += 4 + pad4(sz);
			continue;
		}
		default:
			/* unknown tag: its width is unknown, so stop here */
			goto args_done;
		}
		nargs++;
	}
args_done:

	if (strcmp(path, "/ping") == 0) {
		osc_send(r, "/pong", "");
		return 1;
	}
	if (strcmp(path, "/list") == 0) {
		do_list(r);
		return 1;
	}
	if (strcmp(path, "/get") == 0) {
		if (nargs && args[0].type == 's')
			do_query(r, args[0].s);
		else
			osc_send(r, "/error", "s", "/get needs a string argument");
		return 1;
	}

	for (int i = 0; i < n_fields; i++) {
		if (!match_here(path, fields[i].path))
			continue;
		apply(&fields[i], args, nargs, verbose);
		hits++;
	}
	if (!hits && extra_handler)
		hits = extra_handler(path, args, nargs, verbose);
	if (!hits && verbose)
		fprintf(stderr, "oscreg: no endpoint matches %s\n", path);
	return hits;
}

static int handle_packet(const uint8_t *b, size_t len, const osc_reply *r,
			 int verbose)
{
	if (len >= 8 && memcmp(b, "#bundle", 8) == 0) {
		size_t pos = 16;	/* 8 tag + 8 timetag, executed at once */
		int hits = 0;

		while (pos + 4 <= len) {
			uint32_t sz = rd_be32(b + pos);

			pos += 4;
			if (sz == 0 || pos + sz > len)
				break;
			hits += handle_packet(b + pos, sz, r, verbose);
			pos += sz;
		}
		return hits;
	}
	if (len && b[0] == '/')
		return handle_message(b, len, r, verbose);
	return -1;
}

int oscreg_handle(const void *pkt, size_t len, int verbose)
{
	osc_reply r = { -1, NULL, 0 };

	return handle_packet((const uint8_t *)pkt, len, &r, verbose);
}

/* ------------------------------------------------------------------ */
/* 6. UDP server                                                       */
/* ------------------------------------------------------------------ */
int oscreg_serve(int port, int verbose)
{
	struct sockaddr_in me;
	int s = socket(AF_INET, SOCK_DGRAM, 0);
	int one = 1;

	if (s < 0) {
		fprintf(stderr, "oscreg: socket: %s\n", strerror(errno));
		return -1;
	}
	setsockopt(s, SOL_SOCKET, SO_REUSEADDR, &one, sizeof(one));

	memset(&me, 0, sizeof(me));
	me.sin_family      = AF_INET;
	me.sin_addr.s_addr = htonl(INADDR_ANY);
	me.sin_port        = htons((uint16_t)port);

	if (bind(s, (struct sockaddr *)&me, sizeof(me)) < 0) {
		fprintf(stderr, "oscreg: bind %d: %s\n", port, strerror(errno));
		close(s);
		return -1;
	}
	fprintf(stderr, "oscreg: listening on udp/%d, %d endpoints\n",
		port, n_fields);

	while (!oscreg_stop) {
		uint8_t buf[2048];
		struct sockaddr_in from;
		socklen_t fl = sizeof(from);
		ssize_t n = recvfrom(s, buf, sizeof(buf), 0,
				     (struct sockaddr *)&from, &fl);
		osc_reply r;

		if (n < 0) {
			if (errno == EINTR)
				continue;
			fprintf(stderr, "oscreg: recvfrom: %s\n", strerror(errno));
			break;
		}
		r.sock  = s;
		r.to    = (struct sockaddr *)&from;
		r.tolen = fl;
		handle_packet(buf, (size_t)n, &r, verbose);
	}
	close(s);
	return 0;
}

/* ------------------------------------------------------------------ */
/* 7. daemon                                                           */
/* ------------------------------------------------------------------ */
#ifdef OSCREG_MAIN
#ifdef OSCREG_WITH_DRAW
#include "oscdraw.h"
#endif

static void on_signal(int sig)
{
	(void)sig;
	oscreg_stop = 1;
}

static void print_table(void)
{
	printf("%-24s %-12s %-8s %s\n", "OSC ADDRESS", "REG", "BITS", "MEANING");
	for (int i = 0; i < n_fields; i++) {
		const oscreg_field *f = &fields[i];
		char bits[16], reg[16];

		if (f->width == 1)
			snprintf(bits, sizeof(bits), "[%u]", f->lo);
		else
			snprintf(bits, sizeof(bits), "[%u:%u]",
				 f->lo + f->width - 1, f->lo);
		snprintf(reg, sizeof(reg), "%08X+%X", (unsigned)f->base,
			 (unsigned)f->off);
		printf("%-24s %-12s %-8s %s%s\n", f->path, reg, bits,
		       f->help, f->ro ? " (read only)" : "");
	}
}

int main(int argc, char **argv)
{
	int port = 9000, verbose = 0, sim = 0, list = 0;
	struct sigaction sa;

	for (int i = 1; i < argc; i++) {
		if (!strcmp(argv[i], "-p") && i + 1 < argc)
			port = atoi(argv[++i]);
		else if (!strcmp(argv[i], "-v"))
			verbose = 1;
		else if (!strcmp(argv[i], "-n"))
			sim = 1;
		else if (!strcmp(argv[i], "-l"))
			list = 1;
		else {
			fprintf(stderr,
"usage: %s [-p port] [-v] [-n] [-l]\n"
"  -p PORT  UDP port to listen on (default 9000)\n"
"  -v       log every register write\n"
"  -n       simulate: use RAM, do not touch the hardware\n"
"  -l       print the endpoint table and exit\n", argv[0]);
			return 2;
		}
	}

	if (list) {
		oscreg_build();
		print_table();
		return 0;
	}

	if (oscreg_init(sim) < 0)
		return 1;

#ifdef OSCREG_WITH_DRAW
	if (oscdraw_init(sim) < 0) {
		fprintf(stderr, "oscreg: oscdraw_init failed\n");
		oscreg_close();
		return 1;
	}
	oscreg_set_handler(oscdraw_dispatch);
#endif

	memset(&sa, 0, sizeof(sa));
	sa.sa_handler = on_signal;
	sigaction(SIGINT, &sa, NULL);
	sigaction(SIGTERM, &sa, NULL);

	oscreg_serve(port, verbose);
#ifdef OSCREG_WITH_DRAW
	oscdraw_close();
#endif
	oscreg_close();
	return 0;
}
#endif /* OSCREG_MAIN */

/*
 * dds.c - patterns and tables of the PL DDS engine dz_osc2 (build osc,
 * 2026-10-29; hw/rtl/dz_osc/dz_osc_ch.v, ROADMAP.md section 14).
 *
 * The registers of each channel are fields (dz_fields.c: /dds/<n>/shape,
 * /seq, /tick, ...). This file adds what a field cannot do: patterns that
 * set several registers from the running video mode, and the two
 * write-only tables (16 steps, 2048-entry AWG), of which it keeps a copy.
 *
 * Sizes are in the VISIBLE picture: "4 bars" = 4 cycles across the active
 * width. Line rate = measured frame rate x VTC GVSIZE, cycles per line =
 * cycles x GHSIZE / active width (the phase also runs in the blanking).
 * The phase runs on FCLK0 (100 MHz): an edge can move by ~0.75 px.
 *
 *   /dds/<n>/wave s:shape [f:hz]     free running (no reset, no sequencer)
 *   /dds/<n>/bars f:n [s:shape]      n vertical bars (phase reset at hsync)
 *   /dds/<n>/hbars f:n [s:shape]     n horizontal bands (LINESTEP, reset at vsync)
 *   /dds/<n>/checker i:cols i:rows [s:shape]   sequencer: 2 steps, tick hsync
 *   /dds/<n>/slant f:n f:shift       bars + shift cycles per line (diagonals)
 *   /dds/<n>/scroll f:speed          adds speed cycles per second (FRAMESTEP)
 *   /dds/<n>/pulse f:duty            pulse shape, high for duty (0..1) of a cycle
 *   /dds/<n>/off                     sequencer, reset, steps, offsets off (PINC stays)
 *   /dds/<n>/step i:idx i:start i:delta i:len [i:keep i:rst i:phase]
 *   /dds/<n>/steps                   -> /dds/<n>/step i*7 for steps 0..15, then
 *                                       /dds/<n>/steps/end
 *   /dds/<n>/awg s:"v v v ..."       2..1024 points 0..65535 (one cycle); linear
 *                                    interpolation to 2048 entries (cyclic)
 *   /dds/<n>/awg                     -> /dds/<n>/awg s:points (the copy)
 *   /dds/raster                      -> /dds/raster f:line_hz f:frame_hz
 *                                       i:htotal i:vtotal i:width i:height
 * shape: sine saw sawdown tri square pulse awg, or 0..6.
 * The sine is two's complement; the other shapes are unsigned 0..0xFFFF
 * (do not set /dds/<n>/invert for them: a square becomes 0x8000 / 0x7FFF).
 */
#include "debazd.h"
#include "dz_hw.h"
#include "dz_map.h"
#include "dz_vdma.h"

#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef HW_DZ_OSC2_0_BASE

#define R_PINC		0x00
#define R_CTRL		0x08
#define R_POFF		0x10
#define R_LSTEP		0x14
#define R_FSTEP		0x18
#define R_PWIDTH	0x1C
#define R_ID		0x28
#define R_STEP		0x100
#define R_AWG		0x2000
#define ID_DOSC		0x444F5343u
#define PINC_VALID	0x80000000u

#define C_SEQ		(1u << 0)
#define C_TICK(t)	((uint32_t)(t) << 1)
#define C_RESET(r)	((uint32_t)(r) << 4)
#define C_LAST(l)	((uint32_t)(l) << 8)
#define C_VSRESTART	(1u << 13)
#define C_SHAPE(s)	((uint32_t)(s) << 16)
#define TICK_HSYNC	1
#define RST_HSYNC	1
#define RST_VSYNC	2
#define SH_SQUARE	4
#define SH_PULSE	5

#define VTC_GHSIZE	0x070
#define VTC_GVSIZE	0x074

#define AWG_N		2048
#define PTS_MAX		1024

static const char *const shape_names[] = { "sine", "saw", "sawdown", "tri", "square", "pulse", "awg" };

static struct {
	uint32_t step[16][4];		/* START, DELTA, LEN|KEEP|RST, PHASE */
	uint16_t pts[PTS_MAX];		/* the AWG as it was sent */
	int      npts;
} ch[2];

static uint32_t base_of(int n)
{
	return n ? HW_DDS_AXI_INTERFACE_1_BASE : HW_DDS_AXI_INTERFACE_0_BASE;
}

static void wr(int n, uint32_t off, uint32_t v)
{
	dz_wr(base_of(n), off, v);
}

/* dz_osc2 in the loaded bitstream (an older one has dds_axi_interface_0
 * there: reads 0 at +0x28; channel 1's address would be a bus error) */
static int present(void)
{
	return dz_regs_known(HW_DDS_AXI_INTERFACE_0_BASE) &&
	       dz_rd(HW_DDS_AXI_INTERFACE_0_BASE, R_ID) == ID_DOSC;
}

typedef struct {
	double line_hz, frame_hz;
	int    htotal, vtotal, w, h;
} raster;

static raster get_raster(void)
{
	raster r;

	r.htotal = (int)(dz_rd(HW_HDMI_0_V_TC_0_BASE, VTC_GHSIZE) & 0x1FFF);
	r.vtotal = (int)(dz_rd(HW_HDMI_0_V_TC_0_BASE, VTC_GVSIZE) & 0x1FFF);
	r.w = dz_geom_w();
	r.h = dz_geom_h();
	if (r.htotal < r.w || r.htotal <= 0)	/* VTC not readable: 720p */
		r.htotal = 1650;
	if (r.vtotal < r.h || r.vtotal <= 0)
		r.vtotal = 750;
	r.frame_hz = disp_frame_hz();
	if (r.frame_hz < 1.0)
		r.frame_hz = 60.0;
	r.line_hz = r.frame_hz * r.vtotal;
	return r;
}

/* phase increment for c cycles per second, clamped to 31 bits */
static uint32_t inc_hz(double c)
{
	double v = c * 4294967296.0 / DZ_DDS_CLK_HZ;

	if (v < 0)
		v = 0;
	if (v > 2147483647.0)
		v = 2147483647.0;
	return (uint32_t)llround(v);
}

/* 2^32 x frac, wrapped into one cycle (for offsets and steps) */
static uint32_t cycles32(double frac)
{
	double v = fmod(frac, 1.0);

	if (v < 0)
		v += 1.0;
	return (uint32_t)llround(v * 4294967296.0) ;
}

static double argf(const dz_arg *a)
{
	return a->type == 'f' ? (double)a->f : (double)a->i;
}

/* shape argument: a name or 0..6; def when absent; -1 = unknown */
static int arg_shape(const dz_msg *m, int i, int def)
{
	if (m->n <= i)
		return def;
	if (m->a[i].type == 's') {
		for (int s = 0; s < 7; s++)
			if (!strcmp(m->a[i].s, shape_names[s]))
				return s;
		if (!strcmp(m->a[i].s, "triangle"))
			return 3;
		return -1;
	}
	int s = (int)argf(&m->a[i]);
	return s >= 0 && s <= 6 ? s : -1;
}

static void clean(int n)
{
	wr(n, R_LSTEP, 0);
	wr(n, R_FSTEP, 0);
	wr(n, R_POFF, 0);
}

static void put_step(int n, int i, uint32_t start, uint32_t delta, uint32_t len, uint32_t ph)
{
	uint32_t *s = ch[n].step[i];

	s[0] = start;
	s[1] = delta;
	s[2] = len;
	s[3] = ph;
	for (int k = 0; k < 4; k++)
		wr(n, R_STEP + 16u * (uint32_t)i + 4u * (uint32_t)k, s[k]);
}

static void reply_steps(int n)
{
	char p[24];

	snprintf(p, sizeof(p), "/dds/%d/step", n);
	for (int i = 0; i < 16; i++) {
		const uint32_t *s = ch[n].step[i];
		dzd_reply(p, "iiiiiii", i, (int)s[0], (int)s[1], (int)(s[2] & 0xFFFFFF),
			  (int)((s[2] >> 24) & 1), (int)((s[2] >> 25) & 1), (int)s[3]);
	}
	snprintf(p, sizeof(p), "/dds/%d/steps/end", n);
	dzd_reply(p, "");
}

/* points -> 2048 entries, linear, cyclic (the last point joins the first) */
static void write_awg(int n)
{
	const int np = ch[n].npts;

	for (int k = 0; k < AWG_N; k++) {
		double pos = (double)k * np / AWG_N;
		int    i = (int)pos;
		double fr = pos - i;
		double v = ch[n].pts[i] * (1.0 - fr) + ch[n].pts[(i + 1) % np] * fr;
		wr(n, R_AWG + 4u * (uint32_t)k, (uint32_t)lround(v) & 0xFFFF);
	}
}

static int set_awg(int n, const dz_msg *m)
{
	uint16_t pts[PTS_MAX];
	int np = 0;

	if (m->n == 1 && m->a[0].type == 's') {	/* "v v v", commas allowed */
		const char *s = m->a[0].s;
		char *e;
		while (*s && np < PTS_MAX) {
			while (*s == ' ' || *s == ',' || *s == '\t' || *s == '\n')
				s++;
			if (!*s)
				break;
			long v = strtol(s, &e, 0);
			if (e == s)
				return -1;
			pts[np++] = (uint16_t)(v < 0 ? 0 : v > 0xFFFF ? 0xFFFF : v);
			s = e;
		}
	} else {				/* up to 31 numbers as arguments */
		for (int i = 0; i < m->n && np < PTS_MAX; i++) {
			long v = (long)argf(&m->a[i]);
			pts[np++] = (uint16_t)(v < 0 ? 0 : v > 0xFFFF ? 0xFFFF : v);
		}
	}
	if (np < 2)
		return -1;
	memcpy(ch[n].pts, pts, sizeof(pts[0]) * (size_t)np);
	ch[n].npts = np;
	write_awg(n);
	return np;
}

static void reply_awg(int n)
{
	static char buf[PTS_MAX * 6 + 1];
	char p[24];
	size_t o = 0;

	for (int i = 0; i < ch[n].npts && o + 7 < sizeof(buf); i++)
		o += (size_t)snprintf(buf + o, sizeof(buf) - o, i ? " %u" : "%u", ch[n].pts[i]);
	buf[o] = 0;
	snprintf(p, sizeof(p), "/dds/%d/awg", n);
	dzd_reply(p, "s", buf);
}

int dds_dispatch(const dz_msg *m)
{
	const char *p = m->path, *c;
	int n;

	if (strncmp(p, "/dds/", 5))
		return 0;
	if (!strcmp(p, "/dds/raster")) {
		raster r = get_raster();
		dzd_reply("/dds/raster", "ffiiii", (float)r.line_hz, (float)r.frame_hz,
			  r.htotal, r.vtotal, r.w, r.h);
		return 1;
	}
	if ((p[5] != '0' && p[5] != '1') || p[6] != '/')
		return 0;
	n = p[5] - '0';
	c = p + 7;
	/* the commands of this file; anything else is a field */
	static const char *const cmds[] = { "wave", "bars", "hbars", "checker", "slant", "scroll",
					    "pulse", "off", "step", "steps", "awg" };
	int known = 0;
	for (size_t i = 0; i < sizeof(cmds) / sizeof(cmds[0]); i++)
		if (!strcmp(c, cmds[i]))
			known = 1;
	if (!known)
		return 0;
	if (!present()) {
		dzd_reply("/error", "ss", p, "needs a bitstream with dz_osc2 (build osc or later)");
		return 1;
	}

	raster r = get_raster();
	double vis = (double)r.htotal / (r.w > 0 ? r.w : 1);	/* line / visible width */

	if (!strcmp(c, "wave")) {
		int s = arg_shape(m, 0, 0);
		if (s < 0)
			goto bad;
		clean(n);
		wr(n, R_CTRL, C_SHAPE(s));
		if (m->n >= 2)
			wr(n, R_PINC, PINC_VALID | inc_hz(argf(&m->a[1])));
	} else if (!strcmp(c, "bars") || !strcmp(c, "slant")) {
		int slant = c[0] == 's';
		if (m->n < 1 + slant)
			goto bad;
		int s = arg_shape(m, 1 + slant, SH_SQUARE);
		if (s < 0)
			goto bad;
		clean(n);
		wr(n, R_PINC, PINC_VALID | inc_hz(argf(&m->a[0]) * vis * r.line_hz));
		if (slant)
			wr(n, R_LSTEP, cycles32(argf(&m->a[1])));
		wr(n, R_CTRL, C_SHAPE(s) | C_RESET(RST_HSYNC));
	} else if (!strcmp(c, "hbars")) {
		if (m->n < 1)
			goto bad;
		int s = arg_shape(m, 1, SH_SQUARE);
		if (s < 0)
			goto bad;
		clean(n);
		wr(n, R_PINC, PINC_VALID);		/* increment 0: one value per line */
		wr(n, R_LSTEP, cycles32(argf(&m->a[0]) / (r.h > 0 ? r.h : 720)));
		wr(n, R_CTRL, C_SHAPE(s) | C_RESET(RST_VSYNC));
	} else if (!strcmp(c, "checker")) {
		if (m->n < 2)
			goto bad;
		int cols = (int)argf(&m->a[0]), rows = (int)argf(&m->a[1]);
		int s = arg_shape(m, 2, SH_SQUARE);
		if (cols < 1 || rows < 1 || s < 0)
			goto bad;
		/* a square wave of cols/2 cycles: one cycle = a light and a dark column */
		uint32_t inc = inc_hz(cols / 2.0 * vis * r.line_hz);
		uint32_t lines = (uint32_t)(r.h / rows > 0 ? r.h / rows : 1);
		clean(n);
		put_step(n, 0, inc, 0, lines, 0);
		put_step(n, 1, inc, 0, lines, 0x80000000u);
		wr(n, R_PINC, PINC_VALID | inc);
		wr(n, R_CTRL, C_SEQ | C_TICK(TICK_HSYNC) | C_RESET(RST_HSYNC) | C_LAST(1) |
				  C_VSRESTART | C_SHAPE(s));
	} else if (!strcmp(c, "scroll")) {
		if (m->n < 1)
			goto bad;
		wr(n, R_FSTEP, cycles32(argf(&m->a[0]) / r.frame_hz));
	} else if (!strcmp(c, "pulse")) {
		if (m->n < 1)
			goto bad;
		double d = argf(&m->a[0]);
		d = d < 0 ? 0 : d > 1 ? 1 : d;
		wr(n, R_PWIDTH, d >= 1.0 ? 0xFFFFFFFFu : (uint32_t)llround(d * 4294967296.0));
		wr(n, R_CTRL, (dz_rd(base_of(n), R_CTRL) & ~C_SHAPE(7)) | C_SHAPE(SH_PULSE));
	} else if (!strcmp(c, "off")) {
		wr(n, R_CTRL, 0);
		clean(n);
		for (int i = 0; i < 16; i++)
			put_step(n, i, 0, 0, 0, 0);
	} else if (!strcmp(c, "step")) {
		if (m->n < 4)
			goto bad;
		int i = (int)argf(&m->a[0]);
		if (i < 0 || i > 15)
			goto bad;
		uint32_t len = (uint32_t)argf(&m->a[3]) & 0xFFFFFF;
		if (m->n > 4 && argf(&m->a[4]) != 0)
			len |= 1u << 24;		/* KEEP */
		if (m->n > 5 && argf(&m->a[5]) != 0)
			len |= 1u << 25;		/* RST */
		uint32_t ph = m->n > 6 ? (uint32_t)(int64_t)argf(&m->a[6]) : 0;
		put_step(n, i, (uint32_t)(int64_t)argf(&m->a[1]), (uint32_t)(int64_t)argf(&m->a[2]),
			 len, ph);
	} else if (!strcmp(c, "steps")) {
		reply_steps(n);
		return 1;
	} else if (!strcmp(c, "awg")) {
		if (m->n == 0) {
			reply_awg(n);
			return 1;
		}
		if (set_awg(n, m) < 0)
			goto bad;
	}
	dzd_reply(p, "i", 1);
	return 1;
bad:
	dzd_reply("/error", "ss", p, "bad arguments (see sw/debazd/dds.c)");
	return 1;
}

#else	/* hw_map.h without dz_osc2 */

int dds_dispatch(const dz_msg *m)
{
	(void)m;
	return 0;
}

#endif

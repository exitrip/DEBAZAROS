/*
 * dz_vdma.c - see dz_vdma.h.
 */
#include "dz_vdma.h"
#include "dz_hw.h"
#include "dz_map.h"

#include <stdio.h>
#include <string.h>

/* MM2S register offsets (PG020) */
#define MM2S_CR		0x00
#define MM2S_SR		0x04
#define PARK_PTR	0x28
#define MM2S_VSIZE	0x50
#define MM2S_HSIZE	0x54
#define MM2S_STRIDE	0x58
#define MM2S_ADDR(n)	(0x5C + 4u * (n))
/* S2MM */
#define S2MM_CR		0x30
#define S2MM_SR		0x34
#define S2MM_VSIZE	0xA0
#define S2MM_HSIZE	0xA4
#define S2MM_STRIDE	0xA8
#define S2MM_ADDR(n)	(0xAC + 4u * (n))

#define CR_RS		(1u << 0)
#define CR_CIRC		(1u << 1)	/* 1 = circular, 0 = park */
#define SR_HALTED	(1u << 0)
#define SR_FRMCNT	(1u << 12)
#define PARK_RD_REF	0x1Fu		/* [4:0] MM2S park frame index */
#define PARK_RD_STORE(p) (((p) >> 16) & 0x1Fu)	/* frame being read */

static uint32_t disp_base(int d)
{
	return d == 0 ? DZ_DISP0_VDMA : d == 1 ? DZ_DISP1_VDMA : 0;
}

int dz_disp_regs(int d, dz_vdma_regs *r)
{
	uint32_t b = disp_base(d);

	if (!b || !dz_regs(b))
		return -1;
	r->cr     = dz_rd(b, MM2S_CR);
	r->sr     = dz_rd(b, MM2S_SR);
	r->park   = dz_rd(b, PARK_PTR);
	r->vsize  = dz_rd(b, MM2S_VSIZE);
	r->hsize  = dz_rd(b, MM2S_HSIZE);
	r->stride = dz_rd(b, MM2S_STRIDE);
	for (int i = 0; i < 3; i++)
		r->addr[i] = dz_rd(b, MM2S_ADDR(i));
	return 0;
}

static int running(const dz_vdma_regs *r)
{
	return (r->cr & CR_RS) && !(r->sr & SR_HALTED) && r->vsize;
}

uint32_t dz_disp_addr(int d)
{
	dz_vdma_regs r;
	unsigned i;

	if (dz_disp_regs(d, &r) < 0 || !running(&r))
		return 0;
	/* parked: the reference index; circular: the store being read now */
	i = (r.cr & CR_CIRC) ? PARK_RD_STORE(r.park) : (r.park & PARK_RD_REF);
	return i < 3 ? r.addr[i] : 0;
}

int dz_disp_slot(int d)
{
	uint32_t a = dz_disp_addr(d);

	if (a < DZ_SLOT_BASE || a >= DZ_SLOT_ADDR(DZ_SLOTS))
		return -1;
	if ((a - DZ_SLOT_BASE) % DZ_SLOT_PITCH)
		return -1;
	return (int)((a - DZ_SLOT_BASE) / DZ_SLOT_PITCH);
}

static int show_addr(int d, uint32_t addr)
{
	uint32_t b = disp_base(d);
	dz_vdma_regs r;

	if (!b || dz_disp_regs(d, &r) < 0)
		return -1;
	if (!running(&r))
		return -2;		/* run hdmi2 (display init) first */

	dz_wr(b, MM2S_ADDR(0), addr);
	dz_wr(b, MM2S_VSIZE, r.vsize);			/* commit */
	dz_wr(b, PARK_PTR, (r.park & ~PARK_RD_REF) | 0u);	/* park on 0 */
	if (r.cr & CR_CIRC)
		dz_wr(b, MM2S_CR, r.cr & ~CR_CIRC);	/* park mode */
	return 0;
}

int dz_disp_set_store(int d, int idx, uint32_t addr)
{
	uint32_t b = disp_base(d);
	uint32_t vs;

	if (!b || idx < 0 || idx > 2 || !dz_regs(b))
		return -1;
	vs = dz_rd(b, MM2S_VSIZE);
	if (!vs)
		return -2;
	dz_wr(b, MM2S_ADDR(idx), addr);
	dz_wr(b, MM2S_VSIZE, vs);		/* commit */
	return 0;
}

int dz_disp_park(int d, int idx)
{
	uint32_t b = disp_base(d);

	if (!b || idx < 0 || idx > 2 || !dz_regs(b))
		return -1;
	dz_wr(b, PARK_PTR, (dz_rd(b, PARK_PTR) & ~PARK_RD_REF) | (uint32_t)idx);
	return 0;
}

int dz_disp_parked(int d)
{
	uint32_t b = disp_base(d);

	if (!b || !dz_regs(b))
		return -1;
	return (int)(dz_rd(b, PARK_PTR) & PARK_RD_REF);
}

#define VTC_ISR		0x04
#define VTC_FRAME_BIT	(1u << 13)

int dz_vsync_latched(void)
{
	volatile uint32_t *r = dz_regs(HW_HDMI_0_V_TC_0_BASE);

	if (!r || !(r[VTC_ISR / 4] & VTC_FRAME_BIT))
		return 0;
	r[VTC_ISR / 4] = VTC_FRAME_BIT;		/* W1C */
	return 1;
}

int dz_disp_show(int d, int slot)
{
	if (slot < 0 || slot >= DZ_SLOTS)
		return -1;
	/* reading Linux RAM is harmless, but the picture would be garbage and
	 * whoever fills that slot would corrupt Linux: refuse it here */
	if (!dz_reserved(DZ_SLOT_ADDR(slot), DZ_WIDTH * DZ_HEIGHT * DZ_BPP))
		return -1;
	return show_addr(d, DZ_SLOT_ADDR(slot));
}

uint32_t dz_capture_addr(void)
{
	dz_vdma_regs r;

	if (dz_capture_regs(&r) < 0 || !r.vsize)
		return 0;
	return r.addr[0];
}

int dz_disp_show_capture(int d)
{
	uint32_t a = dz_capture_addr();

	return a ? show_addr(d, a) : -3;
}

int dz_capture_regs(dz_vdma_regs *r)
{
	uint32_t b = DZ_CAPTURE_VDMA;

	if (!dz_regs(b))
		return -1;
	r->cr     = dz_rd(b, S2MM_CR);
	r->sr     = dz_rd(b, S2MM_SR);
	r->park   = dz_rd(b, PARK_PTR);
	r->vsize  = dz_rd(b, S2MM_VSIZE);
	r->hsize  = dz_rd(b, S2MM_HSIZE);
	r->stride = dz_rd(b, S2MM_STRIDE);
	for (int i = 0; i < 3; i++)
		r->addr[i] = dz_rd(b, S2MM_ADDR(i));
	return 0;
}

int dz_capture_frames_seen(void)
{
	uint32_t b = DZ_CAPTURE_VDMA;
	uint32_t sr;

	if (!dz_regs(b))
		return 0;
	sr = dz_rd(b, S2MM_SR);
	if (!(sr & SR_FRMCNT))
		return 0;
	dz_wr(b, S2MM_SR, SR_FRMCNT);	/* W1C, only this bit */
	return 1;
}

const char *dz_vdma_sr_text(uint32_t sr, char *buf, unsigned len)
{
	static const struct { uint32_t bit; const char *name; } bits[] = {
		{ 1u << 0,  "halted" },   { 1u << 4,  "interr" },
		{ 1u << 5,  "slverr" },   { 1u << 6,  "decerr" },
		{ 1u << 7,  "sofearly" }, { 1u << 8,  "eolearly" },
		{ 1u << 11, "soflate" },  { 1u << 14, "errirq" },
		{ 1u << 15, "eollate" },
	};
	size_t n = 0;

	buf[0] = 0;
	for (unsigned i = 0; i < sizeof(bits) / sizeof(bits[0]); i++) {
		if (!(sr & bits[i].bit))
			continue;
		n += (size_t)snprintf(buf + n, n < len ? len - n : 0, "%s%s",
				      n ? " " : "", bits[i].name);
	}
	if (!n)
		snprintf(buf, len, "ok");
	return buf;
}

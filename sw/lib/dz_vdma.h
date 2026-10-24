/*
 * dz_vdma.h - display routing and capture status on the AXI VDMAs.
 *
 * Routing model: display d always scans its MM2S frame store 0, parked.
 * dz_disp_show(d, slot) points store 0 at a DDR slot and commits it. Use it
 * to show the capture (slot 4), to flip between front and back slots, or to
 * route a display back to the slot that ffmpeg writes (slot 0 = /dev/fb0).
 *
 * VDMA rules from the bench (CLAUDE.md):
 *  - a new START_ADDRESS takes effect only after VSIZE is written again
 *    (VSIZE = commit point); the change applies at the next frame start;
 *  - never halt (RS=0) an S2MM channel during a frame. Nothing here writes
 *    the S2MM control register.
 */
#ifndef DZ_VDMA_H
#define DZ_VDMA_H

#include <stdint.h>

typedef struct {
	uint32_t cr, sr, park, vsize, hsize, stride;
	uint32_t addr[3];	/* frame store start addresses */
} dz_vdma_regs;

/* MM2S (display) channel registers of display d. 0 or -1. */
int dz_disp_regs(int d, dz_vdma_regs *r);
/* Physical address display d scans now, or 0 if it is not running. */
uint32_t dz_disp_addr(int d);
/* Slot number display d scans now, or -1 (not running / not a slot). */
int dz_disp_slot(int d);
/* Show a slot on display d. 0, -1 bad args or slot outside reserved memory,
 * -2 display not running. */
int dz_disp_show(int d, int slot);
/* Show the frame the capture VDMA writes (its frame store 0). Same codes,
 * -3 = capture not configured. */
int dz_disp_show_capture(int d);
/* Physical address the capture writes (S2MM frame store 0), or 0. */
uint32_t dz_capture_addr(void);

/*
 * Frame stores. Display d has 3 MM2S frame stores. Setting an address needs a
 * commit (VSIZE rewrite); parking on a store does not. Both take effect at
 * the next frame start.
 */
int dz_disp_set_store(int d, int idx, uint32_t addr);	/* addr + commit */
int dz_disp_park(int d, int idx);			/* park pointer only */
int dz_disp_parked(int d);				/* park index, or -1 */

/*
 * Vsync: VTC status bit 13 latches once per frame (60.03 Hz measured, +-1 us
 * with a real-time thread). Returns 1 and clears it if it was set. The VTC is
 * shared, so this is the frame clock of both displays.
 */
int dz_vsync_latched(void);

/* S2MM (capture) channel registers. 0 or -1. */
int dz_capture_regs(dz_vdma_regs *r);
/*
 * 1 if at least one capture frame completed since the last call, else 0.
 * Uses (and clears, W1C) S2MM DMASR bit 12 FrmCnt_Irq. Only one program
 * should call it (the daemon); capstat.sh clears the same bit.
 */
int dz_capture_frames_seen(void);

/* DMASR error bits as text ("ok" if none). buf >= 96 bytes. */
const char *dz_vdma_sr_text(uint32_t sr, char *buf, unsigned len);

#endif /* DZ_VDMA_H */

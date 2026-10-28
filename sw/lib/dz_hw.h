/*
 * dz_hw.h - DEBAZAROS memory map: register blocks and DDR frame slots.
 *
 * Register bases come from the generated hw_map.h (hw/hw_map.tcl). This file
 * only adds what the block design does not know: the DDR slot layout that
 * hdmi2.elf, ffmpeg and the dtsi agree on, and which block is which display.
 */
#ifndef DZ_HW_H
#define DZ_HW_H

#include <stdint.h>
#include "hw_map.h"

/* ---- DDR frame slots ------------------------------------------------------
 * Reserved region (/boot/system.dtb, no-map): 0x0800_0000, 96 MB (128 MB is
 * rejected by the kernel on this board - PetaLinux/dtb/README.md).
 * Slot pitch = hdmi2 DEMO_MAX_FRAME = 1920*1080*4, so any slot can hold a
 * 1080p frame. 12 slots = 0x0800_0000..0x0DEE_C000, the span hdmi2 maps.
 * Slots 0-5: 3 displays x 2 (third-port rule); 4 = capture; 6-10: free;
 * 11: black frame for blanking (debazd keeps it black).
 */
#define DZ_SLOT_BASE	0x08000000u
#define DZ_SLOT_PITCH	(1920u * 1080u * 4u)	/* 0x7E9000 */
#define DZ_SLOTS	12
#define DZ_SLOT_ADDR(n)	(DZ_SLOT_BASE + (uint32_t)(n) * DZ_SLOT_PITCH)
#define DZ_RESERVED_END	0x10000000u

#define DZ_SLOT_FB0	0	/* /dev/fb0 (simplefb) starts here: ffmpeg -f fbdev */
#define DZ_SLOT_CAPTURE	4	/* HDMI_2 capture writes here                      */
#define DZ_SLOT_BLANK	11	/* always black: frame store 2 of each display     */

/* Default geometry of every slot today (hdmi2 default mode). */
#define DZ_WIDTH	1280	/* fallback geometry; the running mode: dz_geom_w/h/stride() */
#define DZ_HEIGHT	720
#define DZ_BPP		4	/* a8r8g8b8 in memory                              */
#define DZ_STRIDE	(1920u * 4u)	/* fixed line pitch of every slot and mode
				 * (2026-10-28; hdmi2 DISPLAY_STRIDE): fallback  */

/* ---- displays ------------------------------------------------------------ */
#define DZ_DISPLAYS	2
/* Display d scans the slot at its VDMA frame store 0 (hdmi2 parks index 0). */
#define DZ_DISP0_VDMA	HW_HDMI_0_AXI_VDMA_0_BASE
#define DZ_DISP1_VDMA	HW_HDMI_1_AXI_VDMA_0_BASE
#define DZ_DISP0_HOME	0	/* slot a display shows by default */
#define DZ_DISP1_HOME	2

#define DZ_CAPTURE_VDMA	HW_HDMI_2_AXI_VDMA_0_BASE

/* GPIO 0x4120_0000: ch1 = inputs (user I/O + capture status), ch2 = outputs */
#define DZ_IO_GPIO	HW_AXI_GPIO_HDMI_IN_PHASE0_DIV_GPHASE1_BASE

/*
 * Pixel bus lane order (verified in the BD, Oct 2026). The display path
 * remaps memory a8r8g8b8 to an RBG bus: [23:16] = R, [15:8] = B, [7:0] = G
 * (axis_subset_converter TDATA_REMAP + Digilent rgb2dvi "RBG packing").
 * Every per-colour gain byte multiplies the pixel byte in the same lane.
 */
#define DZ_LANE_R	16
#define DZ_LANE_B	8
#define DZ_LANE_G	0

#endif /* DZ_HW_H */

/*
 * dzmem.h - the user interface of the dzmem kernel module (ROADMAP.md section
 * 19 step 5, the CACHED-slots experiment, 2026-11-20). Shared by the module
 * (PetaLinux recipe dzmem copies this file) and user space (sw/tools/dzmemtest).
 *
 * /dev/dzmem maps the reserved video-slot region (module parameters base /
 * size, default 0x0800_0000 + 96 MB) into user space with a chosen memory
 * type, and syncs the caches for a range on request:
 *   mmap(NULL, len, PROT_READ | PROT_WRITE, MAP_SHARED, fd, offset)
 *     offset = byte offset in the region (slot n = n * 0x7E9000, page aligned)
 *   ioctl(fd, DZMEM_IOC_MODE, &mode)   BEFORE mmap: the memory type of the
 *     next mappings of this open file (default DZMEM_WB)
 *   ioctl(fd, DZMEM_IOC_SYNC, &s)      cache maintenance for [addr, addr+len)
 *     of one dzmem mapping of this process: TO_DEVICE before the VDMA reads
 *     what the CPU wrote (clean), FROM_DEVICE before the CPU reads what a DMA
 *     wrote (invalidate). s.ns = the time it took.
 *
 * The VDMAs do not snoop the caches (no ACP/coherent port on the HP ports).
 * The A9 L1 data cache is physically tagged and L2 (PL310) is physical:
 * every process that maps the same slot through dzmem with a CACHED type
 * shares those caches, so CPU writers see each other without maintenance.
 * ⚠️ ONE MEMORY TYPE PER SLOT (measured 2026-11-21, dzmemtest coh: WB + WT,
 * WB + WC and WT + WC all lose writes; WT is non-cacheable in the A9 L1).
 * v2 enforces it: an mmap of another class (WB / WT / NC = WC or UC) than
 * a live mapping of the slot fails with EBUSY; WT needs allow_wt=1; the
 * last cached mapping of a slot to close flushes it (L1 all CPUs + L2).
 * /dev/mem and /dev/fb0 are outside the guard: do not write a slot through
 * them while it has a dzmem mapping (sw/SLOTMEM.md 4.4).
 */
#ifndef DZMEM_H
#define DZMEM_H

#include <linux/ioctl.h>
#include <linux/types.h>

/* memory types (ARMv7 attributes) */
#define DZMEM_WB	0	/* write-back, write-allocate: fastest; needs SYNC both ways */
#define DZMEM_WT	1	/* write-through: reads cached, writes reach DDR (the VDMA
				 * then needs no clean; a DMA-written range still needs
				 * FROM_DEVICE before the CPU reads it) */
#define DZMEM_WC	2	/* normal non-cacheable, bufferable (what fb0 uses) */
#define DZMEM_UC	3	/* strongly ordered (what /dev/mem gives for this region) */

/* sync directions */
#define DZMEM_TO_DEVICE		1	/* clean: CPU writes -> DDR (L1 then L2) */
#define DZMEM_FROM_DEVICE	2	/* invalidate: DDR -> CPU (L2 then L1) */
#define DZMEM_BIDIRECTIONAL	3	/* clean + invalidate */

/* sync flags */
#define DZMEM_SYNC_L2_ALL	1	/* NOT SUPPORTED (-EOPNOTSUPP): outer_flush_all
					 * needs interrupts off on one core; called from
					 * the ioctl it oopsed (2026-11-20) */

struct dzmem_info {
	__u64 base;		/* physical start of the region */
	__u64 size;		/* bytes */
	__u32 page;		/* PAGE_SIZE */
	__u32 version;		/* DZMEM_VERSION */
};

struct dzmem_sync {
	__u64 addr;		/* user address inside ONE dzmem mapping */
	__u64 len;		/* bytes */
	__u32 dir;		/* DZMEM_TO_DEVICE | FROM_DEVICE | BIDIRECTIONAL */
	__u32 flags;		/* DZMEM_SYNC_L2_ALL */
	__u64 ns;		/* out: the time the maintenance took */
};

#define DZMEM_VERSION		2	/* v2: one type per slot (guard), flush on last close */
#define DZMEM_IOC_MAGIC		'D'
#define DZMEM_IOC_INFO		_IOR(DZMEM_IOC_MAGIC, 1, struct dzmem_info)
#define DZMEM_IOC_MODE		_IOW(DZMEM_IOC_MAGIC, 2, __u32)
#define DZMEM_IOC_SYNC		_IOWR(DZMEM_IOC_MAGIC, 3, struct dzmem_sync)

#endif

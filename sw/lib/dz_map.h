/*
 * dz_map.h - safe access to PL register blocks and DDR frame slots.
 *
 * Register blocks: only bases listed in hw_map.h can be mapped. A base that
 * the current block design does not have (old addresses, speculative UIO
 * nodes in the dtsi) is refused, because any access to it is a bus error
 * (SIGBUS "external abort") that kills the process.
 *
 * Each block is mapped through its UIO node when the dtsi has one (match on
 * /sys/class/uio/<n>/maps/map0/addr), else through /dev/mem.
 */
#ifndef DZ_MAP_H
#define DZ_MAP_H

#include <stddef.h>
#include <stdint.h>

/* sim != 0: blocks and slots are plain RAM. For host tests. */
void dz_map_simulate(int sim);
int  dz_map_simulating(void);

/* Register block at physical base. NULL if the base is not in hw_map.h or
 * the mapping fails. The mapping is cached; call as often as you like. */
volatile uint32_t *dz_regs(uint32_t base);

/* "uio3", "mem" or "sim" for a mapped block, "" otherwise. */
const char *dz_regs_via(uint32_t base);

/* UIO file descriptor of a block (for interrupts), or -1. */
int dz_regs_uio_fd(uint32_t base);

/* 1 if base is a register block of this bitstream. */
int dz_regs_known(uint32_t base);

static inline uint32_t dz_rd(uint32_t base, uint32_t off)
{
	volatile uint32_t *r = dz_regs(base);

	return r ? r[off / 4] : 0;
}

static inline void dz_wr(uint32_t base, uint32_t off, uint32_t v)
{
	volatile uint32_t *r = dz_regs(base);

	if (r)
		r[off / 4] = v;
}

/* DDR frame slot n (0..DZ_SLOTS-1), len bytes from its start. Uses the
 * write-combined /dev/fb0 mapping when fb0 covers the range, else /dev/mem
 * (fast to write, very slow to read). via = "fb0", "mem" or "sim".
 * NULL if the slot is not completely inside reserved memory (dz_reserved). */
uint8_t *dz_slot(int n, size_t len, const char **via);

/*
 * Reserved memory of the RUNNING kernel (reserved-memory nodes in
 * /proc/device-tree). Slot writes are refused outside it: on the bench board
 * (Oct 2026) only 16 MB is reserved although the repo dtsi says 128 MB, and
 * 0x0900_0000+ is normal Linux RAM. Writing there corrupts running programs.
 * 1 if [phys, phys+len) lies inside one reserved region (simulation: always).
 */
int dz_reserved(uint32_t phys, uint32_t len);
/* Number of whole slots inside the reserved memory, from slot 0 up. */
int dz_slots_usable(void);

void dz_unmap_all(void);

#endif /* DZ_MAP_H */

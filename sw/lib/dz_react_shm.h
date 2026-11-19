/*
 * dz_react_shm.h - the audio analysis of debazd (react.c) as shared memory
 * for other processes (dzlua: the `audio` table), 2026-11-20.
 *
 * File DZ_REACT_SHM (tmpfs), written by debazd once per frame while a
 * reader asked in the last 5 s. Seqlock: seq is odd while debazd writes;
 * a reader copies the block between two equal even reads of seq (with
 * memory barriers: dzlua.c dzl_audio). A reader increments `poke` (the
 * only field it writes): debazd takes that as a demand, as an LFO with
 * shape audio (source auto then runs movie / capture audio).
 *
 * ⚠️ The prelude of dzlua (sw/dzlua/prelude.lua) repeats this struct in
 * its ffi.cdef: change both and DZ_REACT_SHM_VERSION together.
 */
#ifndef DZ_REACT_SHM_H
#define DZ_REACT_SHM_H

#include <stdint.h>

#define DZ_REACT_SHM		"/dev/shm/dzreact"
#define DZ_REACT_SHM_MAGIC	0x41525a44u	/* "DZRA" */
#define DZ_REACT_SHM_VERSION	1
#define DZ_REACT_WAVE		2048		/* newest samples per channel */
#define DZ_REACT_BINS		513		/* fft 1024: bins 0..512 */

typedef struct {
	uint32_t magic, version;
	uint32_t seq;			/* odd = being written */
	uint32_t poke;			/* readers: ++ = "I want data" */
	uint32_t frame;			/* debazd writes: ++ each write */
	int32_t  running;		/* 1 = samples arrive (features valid) */
	int32_t  source;		/* 0 off, 1 capture, 2 peak, 4 movie */
	int32_t  movie_slot;		/* source movie: its slot, else -1 */
	double   t;			/* CLOCK_MONOTONIC seconds of the write */
	float    feat[9];		/* level peak bass low mid high air flux beat */
	float    band[16];		/* band0..band15 */
	int32_t  fft_n;			/* 256 | 512 | 1024 */
	int32_t  nbins;			/* fft_n / 2 + 1 (0 = no spectrum) */
	float    spec[DZ_REACT_BINS];	/* amplitude of (L+R)/2, bin k = k x 48000 / fft_n Hz */
	int32_t  nwave;			/* valid samples in the wave arrays (0..2048) */
	uint32_t total_lo;		/* samples ever analysed (low 32 bits) */
	float    wave_m[DZ_REACT_WAVE];	/* (L+R)/2, oldest first, -1..1 */
	float    wave_l[DZ_REACT_WAVE];
	float    wave_r[DZ_REACT_WAVE];
} dz_react_shm;

#endif

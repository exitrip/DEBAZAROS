/*
 * dzmemtest - the cached-slots experiment (ROADMAP.md section 19 step 5,
 * 2026-11-20): speed and correctness of /dev/dzmem (kernel module dzmem,
 * sw/include/dzmem.h) against today's uncached /dev/mem mapping.
 *
 *   dzmemtest bench [-s slot] [-n reps]   MB/s per memory type + sync costs
 *   dzmemtest check [-s slot]             correctness: what a DMA (= the
 *                                         uncached view) sees, before and
 *                                         after a sync, both directions
 *   dzmemtest show  [-s slot] [-t secs] [-m wb|wt] [nosync]
 *                                         moving bars into the slot for a
 *                                         display (/disp/1/show <slot>):
 *                                         without sync = stale cache lines
 *   dzmemtest ddr [-s slot]               read only: the cached view of the
 *                                         slot against DDR (uncached), word
 *                                         by word: what a present has not
 *                                         cleaned yet (debazd may run)
 *   dzmemtest capture                     slot 4 (the capture VDMA writes
 *                                         it): cached reads with and without
 *                                         FROM_DEVICE (needs a live input)
 *   dzmemtest ddr -e file [-s slot]       DDR of the slot against a raw file
 *                                         (BGRA, pitch 7680, up to one slot)
 *   dzmemtest l1                          the same 16 KB read 2000 times per
 *                                         type: L1 hits or not (the A9 TRM
 *                                         says WT is non-cacheable in L1)
 *   dzmemtest coh [-s slot] [-t secs] [-k KB] A B
 *                                         coherence (sw/SLOTMEM.md T2): two
 *                                         processes on CPU 0 / CPU 1 map the
 *                                         same KB of the slot as types A and
 *                                         B (wb wt wc uc), each owns half of
 *                                         every 32-byte line, writes a new
 *                                         value each pass and reads it back
 *                                         through its own mapping. A lost
 *                                         write = the other side's cache line
 *                                         came back over it. At the end DDR
 *                                         (/dev/mem) is checked against the
 *                                         last values (WB sides clean first).
 *   dzmemtest dump [-s slot] file         save the slot (DDR, uncached) to a
 *                                         raw file (the T3 reference)
 *   dzmemtest mixshow [-s slot] [-t secs] A B
 *                                         VISUAL mix test for a monitor
 *                                         (/disp/1/show <slot>): two processes
 *                                         (CPU 0 / 1, types A and B) paint the
 *                                         1280x720 window, each half of every
 *                                         32-byte line: A a red ramp moving
 *                                         right, B a green ramp moving down
 *                                         (WB sides clean each frame unless
 *                                         "nosync" follows). Correct = an even
 *                                         fine mesh moving smoothly; lost
 *                                         writes = stuck or flickering dots.
 *                                         Needs guard=0 for a mix.
 *   dzmemtest guard [-s slot]             dzmem v2 type guard (T2e): WB then
 *                                         WC / WT / slot 4 WB must be refused,
 *                                         WC after the WB unmap allowed (sets
 *                                         guard=1 for the test, restores it)
 *   dzmemtest crash [-s slot] [-k KB]     T2f: a child writes KB through WB
 *                                         and SIGKILLs itself without a clean;
 *                                         DDR must hold its data (v2 flushes
 *                                         at the last close; v1 FAILS)
 *
 * Load first: sudo insmod dzmem.ko (sw/tools/pkgpush.sh kernel-module-dzmem
 * dzmem; the .ko is in /lib/modules/<release>/extra). Default slot 10: a
 * slot nothing else uses (not 0 = fb0, 4 = capture, 11 = the black slot).
 * ⚠️ While it runs no other program may draw into that slot (debazd,
 * a movie, a script): the test mixes cached and uncached views on purpose.
 */
#define _GNU_SOURCE
#include <errno.h>
#include <sched.h>
#include <signal.h>
#include <sys/wait.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <time.h>
#include <unistd.h>

#include "dzmem.h"

#define SLOT_BASE	0x08000000u
#define SLOT_PITCH	(1920u * 1080u * 4u)	/* 0x7E9000 */
#define STRIDE		7680u			/* 1920 px */
#define CAPTURE_SLOT	4

static const char *mname[] = { "WB", "WT", "WC", "UC" };
static int dzfd = -1, memfd = -1;
static size_t maplen;

static double now(void)
{
	struct timespec t;

	clock_gettime(CLOCK_MONOTONIC, &t);
	return t.tv_sec + t.tv_nsec * 1e-9;
}

static size_t round_page(size_t n)
{
	size_t p = (size_t)sysconf(_SC_PAGESIZE);

	return (n + p - 1) & ~(p - 1);
}

/* slot through dzmem with a memory type; NULL on error */
static uint8_t *map_dz(int slot, unsigned mode)
{
	uint32_t m = mode;
	void *p;

	if (ioctl(dzfd, DZMEM_IOC_MODE, &m) < 0) {
		perror("DZMEM_IOC_MODE");
		return NULL;
	}
	p = mmap(NULL, maplen, PROT_READ | PROT_WRITE, MAP_SHARED, dzfd, (off_t)slot * SLOT_PITCH);
	if (p == MAP_FAILED) {
		perror("mmap /dev/dzmem");
		return NULL;
	}
	return p;
}

/* the same slot through /dev/mem (uncached, what debazd uses today) */
static uint8_t *map_mem(int slot)
{
	void *p = mmap(NULL, maplen, PROT_READ | PROT_WRITE, MAP_SHARED, memfd,
		       (off_t)(SLOT_BASE + (uint32_t)slot * SLOT_PITCH));

	if (p == MAP_FAILED) {
		perror("mmap /dev/mem");
		return NULL;
	}
	return p;
}

static double sync_ms(void *addr, size_t len, unsigned dir, unsigned flags)
{
	struct dzmem_sync s = { .addr = (uintptr_t)addr, .len = len, .dir = dir, .flags = flags };

	if (ioctl(dzfd, DZMEM_IOC_SYNC, &s) < 0) {
		perror("DZMEM_IOC_SYNC");
		return -1;
	}
	return s.ns / 1e6;
}

/* ---- bench ------------------------------------------------------------------- */
static void bench_one(const char *name, uint8_t *p, int reps, int cached)
{
	uint8_t *ram = malloc(SLOT_PITCH);
	double t, wr = 0, rd = 0, rmw = 0, small = 0;
	volatile uint32_t sink = 0;

	if (!ram)
		return;
	memset(ram, 0x40, SLOT_PITCH);
	for (int r = 0; r < reps; r++) {
		t = now(); memcpy(p, ram, SLOT_PITCH); wr += now() - t;
		t = now(); memcpy(ram, p, SLOT_PITCH); rd += now() - t;
		t = now();				/* a fade: read + write a 1280 x 720 window */
		for (int y = 0; y < 720; y++) {
			uint32_t *row = (uint32_t *)(p + (size_t)y * STRIDE);

			for (int x = 0; x < 1280; x++)
				row[x] = (row[x] >> 1) & 0x7F7F7F7Fu;
		}
		rmw += now() - t;
		t = now();				/* a 100 x 100 rectangle read (a splat) */
		for (int y = 0; y < 100; y++)
			memcpy(ram + (size_t)y * 400, p + (size_t)(200 + y) * STRIDE + 800, 400);
		small += now() - t;
		sink += ram[0];
	}
	{	/* scattered: 8-pixel (32-byte) spans at 20000 pseudo-random places
		 * (ASCII cells, glyph rows, small splats) */
		double sw = 0, sr = 0;
		uint32_t q = 12345, acc = 0;

		for (int r = 0; r < reps; r++) {
			t = now();
			for (int k = 0; k < 20000; k++) {
				q = q * 1103515245u + 12345u;
				uint32_t *d = (uint32_t *)(p + (size_t)((q >> 8) % 1000) * STRIDE + ((q >> 4) % 1800) * 4);

				for (int x = 0; x < 8; x++)
					d[x] = q;
			}
			sw += now() - t;
			t = now();
			for (int k = 0; k < 20000; k++) {
				q = q * 1103515245u + 12345u;
				const uint32_t *d = (const uint32_t *)(p + (size_t)((q >> 8) % 1000) * STRIDE + ((q >> 4) % 1800) * 4);

				for (int x = 0; x < 8; x++)
					acc += d[x];
			}
			sr += now() - t;
		}
		sink += acc;
		printf("  %-12s scattered 20000 x 32 B: write %6.2f ms, read %6.2f ms\n", name, sw / reps * 1e3, sr / reps * 1e3);
	}
	printf("  %-12s write %6.0f MB/s   read %6.0f MB/s   fade 720p %6.1f ms   100x100 read %6.3f ms\n",
	       name, SLOT_PITCH / (wr / reps) / 1e6, SLOT_PITCH / (rd / reps) / 1e6,
	       rmw / reps * 1e3, small / reps * 1e3);
	if (cached) {
		double a = 0, b = 0, c = 0, d = 0, e = 0;

		for (int r = 0; r < reps; r++) {
			memset(p, r, SLOT_PITCH);	/* dirty lines to clean */
			a += sync_ms(p, SLOT_PITCH, DZMEM_TO_DEVICE, 0);
			memset(p, r + 1, SLOT_PITCH);
			b += sync_ms(p, SLOT_PITCH, DZMEM_BIDIRECTIONAL, 0);	/* clean + invalidate */
			c += sync_ms(p, SLOT_PITCH, DZMEM_FROM_DEVICE, 0);
			memset(p + 200 * STRIDE, r, 100 * STRIDE);
			d += sync_ms(p + 200 * STRIDE, 100 * STRIDE, DZMEM_TO_DEVICE, 0);	/* rows of a 100 px rect */
			t = now();
			for (int y = 0; y < 100; y++)
				sync_ms(p + (size_t)(200 + y) * STRIDE + 800, 400, DZMEM_TO_DEVICE, 0);
			e += now() - t;
		}
		printf("  %-12s sync: full slot clean %.2f ms (clean+inv %.2f), invalidate %.2f ms,\n"
		       "  %-12s       100 rows clean %.3f ms, 100 x 400 B one by one %.3f ms (with ioctls)\n",
		       "", a / reps, b / reps, c / reps, "", d / reps, e / reps * 1e3);
	}
	free(ram);
	(void)sink;
}

static int bench(int slot, int reps)
{
	uint8_t *p = map_mem(slot);

	printf("slot %d (0x%08X), %d reps, 8.3 MB per pass\n", slot, SLOT_BASE + slot * SLOT_PITCH, reps);
	{	/* the baseline: ordinary Linux RAM (what debazd's paint buffers were) */
		uint8_t *m = malloc(SLOT_PITCH);

		if (m) {
			memset(m, 0, SLOT_PITCH);
			bench_one("malloc RAM", m, reps, 0);
			free(m);
		}
	}
	if (p) {
		bench_one("/dev/mem", p, reps, 0);
		munmap(p, maplen);
	}
	for (unsigned m = DZMEM_WB; m <= DZMEM_UC; m++) {
		char n[24];

		snprintf(n, sizeof(n), "dzmem %s", mname[m]);
		p = map_dz(slot, m);
		if (!p)
			return 1;
		bench_one(n, p, reps, m == DZMEM_WB || m == DZMEM_WT);
		munmap(p, maplen);
	}
	return 0;
}

/* ---- check ------------------------------------------------------------------- */
static size_t diff_words(const uint32_t *a, uint32_t v, size_t n)
{
	size_t d = 0;

	for (size_t i = 0; i < n; i++)
		d += a[i] != v;
	return d;
}

static int check(int slot)
{
	uint8_t *uc = map_mem(slot), *wb = map_dz(slot, DZMEM_WB);
	const size_t n = SLOT_PITCH / 4;
	size_t before, after, stale, fresh;
	int ok = 1;

	if (!uc || !wb)
		return 1;
	/* 1. CPU writes through the cache: the DMA side sees them only after
	 * TO_DEVICE */
	memset(uc, 0, SLOT_PITCH);
	sync_ms(wb, SLOT_PITCH, DZMEM_FROM_DEVICE, 0);		/* drop old lines */
	for (size_t i = 0; i < n; i++)
		((uint32_t *)wb)[i] = 0xFF123456u;
	before = diff_words((uint32_t *)uc, 0xFF123456u, n);
	sync_ms(wb, SLOT_PITCH, DZMEM_TO_DEVICE, 0);
	after = diff_words((uint32_t *)uc, 0xFF123456u, n);
	printf("TO_DEVICE   : words the DMA side does not see yet: before sync %zu of %zu, after %zu  %s\n",
	       before, n, after, after == 0 ? "PASS" : "FAIL");
	ok &= after == 0;
	/* 2. the same on a 64 KB window that fits in the caches (on the whole
	 * 8.3 MB slot the 512 KB L2 evicts most lines by itself) */
	{
		const size_t wn = 65536 / 4;
		uint32_t *w = (uint32_t *)wb, *u = (uint32_t *)uc;

		sync_ms(wb, 65536, DZMEM_FROM_DEVICE, 0);
		for (size_t i = 0; i < wn; i++)
			w[i] = 0xFF112233u;
		before = diff_words(u, 0xFF112233u, wn);
		sync_ms(wb, 65536, DZMEM_TO_DEVICE, 0);
		after = diff_words(u, 0xFF112233u, wn);
		printf("TO_DEVICE 64K: words the DMA side does not see: before sync %zu of %zu, after %zu  %s\n",
		       before, wn, after, after == 0 ? "PASS" : "FAIL");
		ok &= after == 0;
		/* a DMA writes (here: the uncached view) under cached lines: the
		 * CPU sees it only after FROM_DEVICE */
		for (size_t i = 0; i < wn; i++)
			(void)((volatile uint32_t *)w)[i];	/* lines into the caches */
		for (size_t i = 0; i < wn; i++)
			u[i] = 0xFF654321u;
		__sync_synchronize();
		stale = diff_words(w, 0xFF654321u, wn);
		sync_ms(wb, 65536, DZMEM_FROM_DEVICE, 0);
		fresh = diff_words(w, 0xFF654321u, wn);
		printf("FROM_DEVICE 64K: stale words the CPU still reads: before sync %zu of %zu, after %zu  %s\n",
		       stale, wn, fresh, fresh == 0 ? (stale ? "PASS" : "PASS (but nothing was stale: test inconclusive)") : "FAIL");
		ok &= fresh == 0;
	}
	/* 3. write-through: no clean needed for the DMA side */
	munmap(wb, maplen);
	wb = map_dz(slot, DZMEM_WT);
	if (wb) {
		for (size_t i = 0; i < n; i++)
			((uint32_t *)wb)[i] = 0xFF0A0B0Cu;
		__sync_synchronize();
		after = diff_words((uint32_t *)uc, 0xFF0A0B0Cu, n);
		printf("WT, no sync : words the DMA side does not see: %zu  %s\n", after,
		       after == 0 ? "PASS" : "FAIL (WT still needs a clean?)");
		munmap(wb, maplen);
	}
	memset(uc, 0, SLOT_PITCH);
	munmap(uc, maplen);
	printf("%s\n", ok ? "check: PASS" : "check: FAIL");
	return ok ? 0 : 1;
}

/* ---- show -------------------------------------------------------------------- */
static int show(int slot, double secs, unsigned mode, int dosync)
{
	uint8_t *p = map_dz(slot, mode);
	double t0 = now(), tl = t0, ms = 0;
	int frames = 0;

	if (!p)
		return 1;
	printf("slot %d, %s, %s: moving bars for %.0f s (show it: dzctl /disp/1/show %d)\n",
	       slot, mname[mode], dosync ? "TO_DEVICE after each frame" : "NO sync", secs, slot);
	while (now() - t0 < secs) {
		int off = (int)((now() - t0) * 240) % 1280;

		for (int y = 0; y < 720; y++) {
			uint32_t *row = (uint32_t *)(p + (size_t)y * STRIDE);

			for (int x = 0; x < 1280; x++)
				row[x] = ((x + off) / 80) & 1 ? 0xFFFFFFFFu : (y < 360 ? 0xFFFF0000u : 0xFF0000FFu);
		}
		if (dosync)
			ms += sync_ms(p, 720 * STRIDE, DZMEM_TO_DEVICE, 0);
		frames++;
		if (now() - tl >= 2) {
			printf("  %.1f fps, sync %.2f ms per frame\n", frames / (now() - t0), frames ? ms / frames : 0);
			tl = now();
		}
		usleep(5000);
	}
	munmap(p, maplen);
	return 0;
}

/* ---- capture ----------------------------------------------------------------- */
static uint32_t sum(const uint8_t *p)
{
	uint32_t s = 0;

	for (size_t i = 0; i < 720 * STRIDE; i += 64)
		s = s * 31 + *(const uint32_t *)(p + i);
	return s;
}

static int capture(void)
{
	uint8_t *wb = map_dz(CAPTURE_SLOT, DZMEM_WB), *uc = map_mem(CAPTURE_SLOT);

	if (!wb || !uc)
		return 1;
	printf("slot 4 (the capture writes it), checksums of 720 lines, 100 ms apart:\n");
	for (int k = 0; k < 4; k++) {
		uint32_t a = sum(wb), u = sum(uc);

		printf("  cached %08x  uncached %08x  %s\n", a, u, a == u ? "same" : "STALE cached");
		usleep(100000);
		if (k == 1)
			printf("  -- now with FROM_DEVICE before each read --\n");
		if (k >= 1)
			sync_ms(wb, 720 * STRIDE, DZMEM_FROM_DEVICE, 0);
	}
	return 0;
}

/* ---- ddr: cached view vs DDR ---------------------------------------------- */
static int ddr(int slot)
{
	const uint32_t *wb = (const uint32_t *)map_dz(slot, DZMEM_WB);
	const uint32_t *uc = (const uint32_t *)map_mem(slot);
	size_t n = SLOT_PITCH / 4, bad = 0, w = STRIDE / 4;
	size_t x0 = w, y0 = n, x1 = 0, y1 = 0;

	if (!wb || !uc)
		return 1;
	for (size_t k = 0; k < n; k++)
		if (wb[k] != uc[k]) {
			size_t x = k % w, y = k / w;

			bad++;
			if (x < x0) x0 = x;
			if (x > x1) x1 = x;
			if (y < y0) y0 = y;
			if (y > y1) y1 = y;
		}
	if (bad)
		printf("slot %d: %zu words differ (cached vs DDR), box x %zu..%zu y %zu..%zu\n",
		       slot, bad, x0, x1, y0, y1);
	else
		printf("slot %d: cached view = DDR (%zu words)\n", slot, n);
	return bad ? 3 : 0;
}

/* ---- ddr -e: DDR against a file ------------------------------------------ */
static int ddr_file(int slot, const char *path)
{
	const uint8_t *uc = map_mem(slot);
	FILE *f = fopen(path, "rb");
	uint8_t *buf;
	size_t n, bad = 0, x0 = STRIDE, y0 = 1 << 20, x1 = 0, y1 = 0;

	if (!uc || !f) {
		fprintf(stderr, "dzmemtest: %s: %s\n", path, f ? "no /dev/mem" : strerror(errno));
		return 1;
	}
	buf = malloc(SLOT_PITCH);
	n = fread(buf, 1, SLOT_PITCH, f);
	fclose(f);
	n &= ~(size_t)3;
	for (size_t k = 0; k < n; k += 4)
		if (memcmp(buf + k, uc + k, 4)) {
			size_t x = (k % STRIDE) / 4, y = k / STRIDE;

			bad++;
			if (x < x0) x0 = x;
			if (x > x1) x1 = x;
			if (y < y0) y0 = y;
			if (y > y1) y1 = y;
		}
	free(buf);
	if (bad)
		printf("slot %d: %zu of %zu pixels differ from %s, box x %zu..%zu y %zu..%zu\n",
		       slot, bad, n / 4, path, x0, x1, y0, y1);
	else
		printf("slot %d: DDR = %s (%zu pixels)\n", slot, path, n / 4);
	return bad ? 3 : 0;
}

/* ---- l1: does a type hit the L1? ------------------------------------------ */
static int l1(int slot)
{
	const size_t len = 16384;
	const int reps = 2000;
	unsigned modes[] = { DZMEM_WB, DZMEM_WT, DZMEM_WC, DZMEM_UC };

	for (int m = 0; m < 4; m++) {
		const volatile uint32_t *p = (const volatile uint32_t *)map_dz(slot, modes[m]);
		uint32_t acc = 0;
		double t;

		if (!p)
			return 1;
		for (size_t k = 0; k < len / 4; k++)	/* warm */
			acc += p[k];
		t = now();
		for (int r = 0; r < reps; r++)
			for (size_t k = 0; k < len / 4; k += 4)
				acc += p[k] + p[k + 1] + p[k + 2] + p[k + 3];
		t = now() - t;
		printf("l1: %s  16 KB x %d: %8.1f MB/s (acc %08x)\n", mname[modes[m]], reps,
		       len * (double)reps / t / 1e6, acc);
		munmap((void *)p, maplen);
	}
	return 0;
}

/* ---- coh: two processes, two memory types, shared cache lines ------------- */
static unsigned mode_of(const char *s)
{
	return !strcmp(s, "wb") ? DZMEM_WB : !strcmp(s, "wt") ? DZMEM_WT :
	       !strcmp(s, "wc") ? DZMEM_WC : !strcmp(s, "uc") ? DZMEM_UC : 99;
}

#define COH_TAG(side, pass, k)	(((uint32_t)(pass) << 16) ^ ((uint32_t)(side) << 15) ^ (uint32_t)(k))

/* one side: words 4*side .. 4*side+3 of every 8-word (32-byte) line */
static void coh_side(int side, int slot, unsigned mode, size_t words, double secs, int outfd)
{
	cpu_set_t cs;
	int fd = open("/dev/dzmem", O_RDWR);
	uint32_t m = mode;
	volatile uint32_t *p;
	unsigned long pass = 0, lost = 0, first_k = 0, first_pass = 0;
	uint32_t first_got = 0, first_want = 0;
	char out[256];
	double end;

	CPU_ZERO(&cs);
	CPU_SET(side, &cs);
	sched_setaffinity(0, sizeof(cs), &cs);
	if (fd < 0 || ioctl(fd, DZMEM_IOC_MODE, &m) < 0)
		_exit(10);
	p = mmap(NULL, maplen, PROT_READ | PROT_WRITE, MAP_SHARED, fd, (off_t)slot * SLOT_PITCH);
	if (p == MAP_FAILED)
		_exit(11);
	end = now() + secs;
	while (now() < end) {
		pass++;
		for (size_t l = 0; l < words; l += 8)
			for (int j = 0; j < 4; j++) {
				size_t k = l + 4 * side + j;

				p[k] = COH_TAG(side, pass, k);
			}
		for (size_t l = 0; l < words; l += 8)
			for (int j = 0; j < 4; j++) {
				size_t k = l + 4 * side + j;
				uint32_t got = p[k], want = COH_TAG(side, pass, k);

				if (got != want) {
					if (!lost++) {
						first_k = k;
						first_pass = pass;
						first_got = got;
						first_want = want;
					}
					p[k] = want;	/* write it again: the end state must be right */
				}
			}
	}
	if (mode == DZMEM_WB) {	/* WB: our dirty lines to DDR before the parent looks */
		struct dzmem_sync sy = { .addr = (uintptr_t)p, .len = words * 4, .dir = DZMEM_TO_DEVICE };

		ioctl(fd, DZMEM_IOC_SYNC, &sy);
	}
	snprintf(out, sizeof(out), "%lu %lu %lu %lu %08x %08x\n", pass, lost, first_k, first_pass,
		 first_got, first_want);
	if (write(outfd, out, strlen(out)) < 0)
		_exit(12);
	_exit(0);
}

static int coh(int slot, double secs, size_t kb, const char *a, const char *b)
{
	unsigned mode[2] = { mode_of(a), mode_of(b) };
	size_t words = kb * 1024 / 4;
	unsigned long res[2][4] = { { 0 } };
	uint32_t gw[2][2] = { { 0 } };
	int pfd[2][2], bad = 0;
	pid_t pid[2];
	const uint32_t *uc;
	size_t ddr_bad[2] = { 0, 0 };

	if (mode[0] > DZMEM_UC || mode[1] > DZMEM_UC || words < 8 || kb * 1024 > SLOT_PITCH) {
		fprintf(stderr, "dzmemtest coh: types wb|wt|wc|uc, KB 1..%u\n", SLOT_PITCH / 1024);
		return 2;
	}
	uc = (const uint32_t *)map_mem(slot);
	if (!uc)
		return 1;
	printf("coh: slot %d, %zu KB, %.0f s, side A %s on CPU 0, side B %s on CPU 1\n",
	       slot, kb, secs, mname[mode[0]], mname[mode[1]]);
	fflush(stdout);
	for (int s = 0; s < 2; s++) {
		if (pipe(pfd[s]) < 0)
			return 1;
		pid[s] = fork();
		if (pid[s] == 0) {
			close(pfd[s][0]);
			coh_side(s, slot, mode[s], words, secs, pfd[s][1]);
		}
		close(pfd[s][1]);
	}
	for (int s = 0; s < 2; s++) {
		char buf[256] = "";
		int st = 0;
		ssize_t n = read(pfd[s][0], buf, sizeof(buf) - 1);

		waitpid(pid[s], &st, 0);
		if (n <= 0 || sscanf(buf, "%lu %lu %lu %lu %x %x", &res[s][0], &res[s][1], &res[s][2],
				     &res[s][3], &gw[s][0], &gw[s][1]) != 6) {
			printf("coh: side %c failed (exit %d)\n", 'A' + s, WEXITSTATUS(st));
			return 1;
		}
	}
	/* DDR against each side's last values */
	for (size_t l = 0; l < words; l += 8)
		for (int s = 0; s < 2; s++)
			for (int j = 0; j < 4; j++) {
				size_t k = l + 4 * s + j;

				if (uc[k] != COH_TAG(s, res[s][0], k))
					ddr_bad[s]++;
			}
	for (int s = 0; s < 2; s++) {
		printf("coh: side %c %s: %lu passes, %lu lost writes", 'A' + s, mname[mode[s]],
		       res[s][0], res[s][1]);
		if (res[s][1])
			printf(" (first: word %lu pass %lu read %08x want %08x)", res[s][2], res[s][3],
			       gw[s][0], gw[s][1]);
		printf(", DDR wrong at the end: %zu of %zu words\n", ddr_bad[s], words / 2);
		bad += res[s][1] || ddr_bad[s];
	}
	printf("coh: %s\n", bad ? "FAIL (not coherent)" : "PASS (coherent)");
	return bad ? 3 : 0;
}

/* ---- guard (v2): one type per slot ---------------------------------------- */
static int try_map(int slot, unsigned mode, void **out)
{
	int fd = open("/dev/dzmem", O_RDWR), e;
	uint32_t m = mode;
	void *p;

	if (fd < 0 || ioctl(fd, DZMEM_IOC_MODE, &m) < 0)
		return -errno;
	p = mmap(NULL, maplen, PROT_READ | PROT_WRITE, MAP_SHARED, fd, (off_t)slot * SLOT_PITCH);
	e = p == MAP_FAILED ? -errno : 0;
	close(fd);			/* the mapping keeps the file */
	if (out)
		*out = e ? NULL : p;
	else if (!e)
		munmap(p, maplen);
	return e;
}

static int expect(const char *what, int got, int want)
{
	int ok = got == want;

	printf("guard: %-40s %-8s %s\n", what, got ? strerror(-got) : "mapped",
	       ok ? "ok" : "WRONG");
	return !ok;
}

#define GUARD_PARAM "/sys/module/dzmem/parameters/guard"
static int guard(int slot)
{
	void *wb = NULL;
	int bad = 0, old = -1;
	FILE *f = fopen(GUARD_PARAM, "r");

	if (f) {
		if (fscanf(f, "%d", &old) != 1)
			old = -1;
		fclose(f);
	}
	f = fopen(GUARD_PARAM, "w");
	if (!f || fprintf(f, "1\n") < 0 || fclose(f) != 0) {
		printf("guard: cannot set %s (module older than v2?)\n", GUARD_PARAM);
		return 1;
	}

	bad += expect("WB map", try_map(slot, DZMEM_WB, &wb), 0);
	bad += expect("second WB map (same class)", try_map(slot, DZMEM_WB, NULL), 0);
	bad += expect("WC map while WB is live", try_map(slot, DZMEM_WC, NULL), -EBUSY);
	bad += expect("UC map while WB is live", try_map(slot, DZMEM_UC, NULL), -EBUSY);
	bad += expect("WT map (allow_wt=0)", try_map(slot, DZMEM_WT, NULL), -EPERM);
	if (wb)
		munmap(wb, maplen);
	bad += expect("WC map after the WB unmap", try_map(slot, DZMEM_WC, NULL), 0);
	bad += expect("WB map of slot 4 (nocache)", try_map(CAPTURE_SLOT, DZMEM_WB, NULL), -EBUSY);
	bad += expect("WC map of slot 4", try_map(CAPTURE_SLOT, DZMEM_WC, NULL), 0);
	f = fopen(GUARD_PARAM, "w");
	if (f) {
		fprintf(f, "%d\n", old < 0 ? 0 : old);
		fclose(f);
	}
	printf("guard: %s (guard back to %d)\n", bad ? "FAIL" : "PASS", old < 0 ? 0 : old);
	return bad ? 3 : 0;
}

/* ---- crash: dirty WB lines of a killed process ----------------------------- */
static int crash(int slot, size_t kb)
{
	size_t words = kb * 1024 / 4, bad = 0;
	volatile uint32_t *uc = (volatile uint32_t *)map_mem(slot);
	pid_t pid;
	int st = 0;

	if (!uc || words > SLOT_PITCH / 4)
		return 1;
	for (size_t k = 0; k < words; k++)	/* DDR: a known old value */
		uc[k] = 0x01D01D00u ^ (uint32_t)k;
	pid = fork();
	if (pid == 0) {
		int fd = open("/dev/dzmem", O_RDWR);
		uint32_t m = DZMEM_WB;
		volatile uint32_t *p;

		if (fd < 0 || ioctl(fd, DZMEM_IOC_MODE, &m) < 0)
			_exit(10);
		p = mmap(NULL, maplen, PROT_READ | PROT_WRITE, MAP_SHARED, fd, (off_t)slot * SLOT_PITCH);
		if (p == MAP_FAILED)
			_exit(11);
		for (size_t k = 0; k < words; k++)
			p[k] = 0xC0DE0000u ^ (uint32_t)k;
		raise(SIGKILL);			/* no clean, no munmap */
		_exit(12);
	}
	waitpid(pid, &st, 0);
	if (!WIFSIGNALED(st)) {
		printf("crash: child did not run (exit %d)\n", WEXITSTATUS(st));
		return 1;
	}
	for (size_t k = 0; k < words; k++)
		if (uc[k] != (0xC0DE0000u ^ (uint32_t)k))
			bad++;
	printf("crash: %zu KB written through WB, writer killed: %zu of %zu words NOT in DDR: %s\n",
	       kb, bad, words, bad ? "FAIL (dirty lines left in the caches)" : "PASS");
	return bad ? 3 : 0;
}

/* ---- dump: the slot as DDR holds it ---------------------------------------- */
static int dump(int slot, const char *path)
{
	const uint8_t *uc = map_mem(slot);
	FILE *f = fopen(path, "wb");
	size_t n;

	if (!uc || !f)
		return 1;
	n = fwrite(uc, 1, SLOT_PITCH, f);
	fclose(f);
	printf("dump: slot %d -> %s (%zu bytes)\n", slot, path, n);
	return n == SLOT_PITCH ? 0 : 1;
}

/* ---- mixshow: a visual mix test --------------------------------------------- */
#define MIX_W	1280
#define MIX_H	720
static void mix_side(int side, int slot, unsigned mode, double secs, int dosync, int outfd)
{
	cpu_set_t cs;
	int fd = open("/dev/dzmem", O_RDWR);
	uint32_t m = mode;
	volatile uint32_t *p;
	unsigned long f = 0, lost = 0;
	char out[96];
	double end;

	CPU_ZERO(&cs);
	CPU_SET(side, &cs);
	sched_setaffinity(0, sizeof(cs), &cs);
	if (fd < 0 || ioctl(fd, DZMEM_IOC_MODE, &m) < 0)
		_exit(10);
	p = mmap(NULL, maplen, PROT_READ | PROT_WRITE, MAP_SHARED, fd, (off_t)slot * SLOT_PITCH);
	if (p == MAP_FAILED)
		_exit(11);
	end = now() + secs;
	while (now() < end) {
		f++;
		for (int y = 0; y < MIX_H; y++) {
			volatile uint32_t *row = p + (size_t)y * (STRIDE / 4);
			uint32_t g = (((uint32_t)y + 3 * f) & 255) << 8;

			for (int x = 4 * side; x < MIX_W; x += 8)	/* 4 px = 16 bytes */
				for (int j = 0; j < 4; j++)
					row[x + j] = side ? 0xFF000000u | g :
						0xFF000000u | ((((uint32_t)(x + j) + 3 * f) & 255) << 16);
		}
		/* check our own pixels of one row band (cheap): a lost write */
		for (int y = (int)(f % MIX_H); y < MIX_H && y < (int)(f % MIX_H) + 8; y++) {
			volatile uint32_t *row = p + (size_t)y * (STRIDE / 4);
			uint32_t g = (((uint32_t)y + 3 * f) & 255) << 8;

			for (int x = 4 * side; x < MIX_W; x += 8)
				for (int j = 0; j < 4; j++) {
					uint32_t want = side ? 0xFF000000u | g :
						0xFF000000u | ((((uint32_t)(x + j) + 3 * f) & 255) << 16);

					if (row[x + j] != want)
						lost++;
				}
		}
		if (mode == DZMEM_WB && dosync) {
			struct dzmem_sync sy = { .addr = (uintptr_t)p, .len = (size_t)MIX_H * STRIDE,
						 .dir = DZMEM_TO_DEVICE };

			ioctl(fd, DZMEM_IOC_SYNC, &sy);
		}
	}
	snprintf(out, sizeof(out), "%lu %lu\n", f, lost);
	if (write(outfd, out, strlen(out)) < 0)
		_exit(12);
	_exit(0);
}

static int mixshow(int slot, double secs, const char *a, const char *b, int dosync)
{
	unsigned mode[2] = { mode_of(a), mode_of(b) };
	int pfd[2][2];
	pid_t pid[2];

	if (mode[0] > DZMEM_UC || mode[1] > DZMEM_UC) {
		fprintf(stderr, "dzmemtest mixshow: types wb|wt|wc|uc\n");
		return 2;
	}
	printf("mixshow: slot %d, %.0f s: A %s red ramp moving right (CPU 0), B %s green ramp "
	       "moving down (CPU 1)%s - show it: dzctl /disp/1/show %d\n", slot, secs,
	       mname[mode[0]], mname[mode[1]], dosync ? "" : ", WB NOT cleaned", slot);
	fflush(stdout);
	for (int s = 0; s < 2; s++) {
		if (pipe(pfd[s]) < 0)
			return 1;
		pid[s] = fork();
		if (pid[s] == 0) {
			close(pfd[s][0]);
			mix_side(s, slot, mode[s], secs, dosync, pfd[s][1]);
		}
		close(pfd[s][1]);
	}
	for (int s = 0; s < 2; s++) {
		char buf[96] = "";
		unsigned long fr = 0, lost = 0;
		int st = 0;
		ssize_t n = read(pfd[s][0], buf, sizeof(buf) - 1);

		waitpid(pid[s], &st, 0);
		if (n <= 0 || sscanf(buf, "%lu %lu", &fr, &lost) != 2) {
			printf("mixshow: side %c failed (exit %d: 11 = mmap refused, guard=1?)\n", 'A' + s,
			       WEXITSTATUS(st));
			continue;
		}
		printf("mixshow: side %c %s: %lu frames (%.1f fps), %lu lost pixels in the sampled rows\n",
		       'A' + s, mname[mode[s]], fr, fr / secs, lost);
	}
	return 0;
}

int main(int argc, char **argv)
{
	int slot = 10, reps = 5, opt, dosync = 1;
	size_t kb = 0;	/* 0 = the default of the command */
	const char *efile = NULL;
	unsigned mode = DZMEM_WB;
	double secs = 10;
	struct dzmem_info info;
	const char *cmd;

	while ((opt = getopt(argc, argv, "s:n:t:m:k:e:")) != -1) {
		switch (opt) {
		case 's': slot = atoi(optarg); break;
		case 'n': reps = atoi(optarg); break;
		case 't': secs = atof(optarg); break;
		case 'm': mode = !strcmp(optarg, "wt") ? DZMEM_WT : DZMEM_WB; break;
		case 'k': kb = (size_t)atol(optarg); break;
		case 'e': efile = optarg; break;
		default: goto usage;
		}
	}
	if (optind >= argc)
		goto usage;
	cmd = argv[optind];
	if (optind + 1 < argc && !strcmp(argv[optind + 1], "nosync"))
		dosync = 0;
	if (slot < 0 || slot > 11 || slot == 0 || slot == 11 || (slot == CAPTURE_SLOT && strcmp(cmd, "capture"))) {
		fprintf(stderr, "dzmemtest: slot %d is in use by the system (0 fb0, 4 capture, 11 black)\n", slot);
		return 2;
	}
	dzfd = open("/dev/dzmem", O_RDWR);
	/* dump and ddr -e read DDR through /dev/mem only: no module needed */
	if (dzfd < 0 && !(!strcmp(cmd, "dump") || (!strcmp(cmd, "ddr") && efile))) {
		fprintf(stderr, "dzmemtest: /dev/dzmem: %s (sudo insmod dzmem.ko?)\n", strerror(errno));
		return 1;
	}
	if (dzfd >= 0 && ioctl(dzfd, DZMEM_IOC_INFO, &info) == 0)
		printf("dzmem v%u: 0x%08llx + %llu MB\n", info.version, (unsigned long long)info.base,
		       (unsigned long long)(info.size >> 20));
	memfd = open("/dev/mem", O_RDWR | O_SYNC);
	if (memfd < 0)
		fprintf(stderr, "dzmemtest: /dev/mem: %s (run as root for the uncached view)\n", strerror(errno));
	maplen = round_page(SLOT_PITCH);
	if (!strcmp(cmd, "bench"))
		return bench(slot, reps);
	if (!strcmp(cmd, "check"))
		return memfd < 0 ? 1 : check(slot);
	if (!strcmp(cmd, "show"))
		return show(slot, secs, mode, dosync);
	if (!strcmp(cmd, "capture"))
		return memfd < 0 ? 1 : capture();
	if (!strcmp(cmd, "ddr"))
		return memfd < 0 ? 1 : efile ? ddr_file(slot, efile) : ddr(slot);
	if (!strcmp(cmd, "dump")) {
		if (optind + 1 >= argc || memfd < 0)
			goto usage;
		return dump(slot, argv[optind + 1]);
	}
	if (!strcmp(cmd, "mixshow")) {
		if (optind + 2 >= argc)
			goto usage;
		return mixshow(slot, secs, argv[optind + 1], argv[optind + 2],
			       !(optind + 3 < argc && !strcmp(argv[optind + 3], "nosync")));
	}
	if (!strcmp(cmd, "guard"))
		return guard(slot);
	if (!strcmp(cmd, "crash"))
		return memfd < 0 ? 1 : crash(slot, kb ? kb : 64);
	if (!strcmp(cmd, "l1"))
		return l1(slot);
	if (!strcmp(cmd, "coh")) {
		if (optind + 2 >= argc || memfd < 0)
			goto usage;
		return coh(slot, secs, kb ? kb : 256, argv[optind + 1], argv[optind + 2]);
	}
usage:
	fprintf(stderr, "usage: dzmemtest [-s slot] [-n reps] bench | check | show [-t s] [-m wb|wt] [nosync] |\n"
		"       ddr [-e file] | capture | l1 | coh [-t s] [-k KB] wb|wt|wc|uc wb|wt|wc|uc |\n"
		"       guard | crash [-k KB] | dump file | mixshow [-t s] A B [nosync]\n");
	return 2;
}

/*
 * dz_map.c - see dz_map.h.
 */
#define _GNU_SOURCE
#include "dz_map.h"
#include "dz_hw.h"
#include "dzmem.h"

#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <linux/fb.h>
#include <pthread.h>
#include <setjmp.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <unistd.h>

#define BLOCK_MAP	0x10000u	/* every block owns a 64K window */

/* Allowlist: every block in this bitstream. Missing macro = block absent. */
static const uint32_t known_bases[] = {
#ifdef HW_AXI_GPIO_HDMI_IN_PHASE0_DIV_GPHASE1_BASE
	HW_AXI_GPIO_HDMI_IN_PHASE0_DIV_GPHASE1_BASE,
#endif
#ifdef HW_HDMI_0_AXI_GPIO_MAING_SHIFT_MEMDELAY_BASE
	HW_HDMI_0_AXI_GPIO_MAING_SHIFT_MEMDELAY_BASE,
#endif
#ifdef HW_HDMI_1_AXI_GPIO_DIVOSC_GOSC_SHIFTPHASEOSC_BASE
	HW_HDMI_1_AXI_GPIO_DIVOSC_GOSC_SHIFTPHASEOSC_BASE,
#endif
#ifdef HW_HDMI_1_AXI_GPIO_DIVPHASE_GMAIN_SHIFTPHASE_GFEEDBACK_BASE
	HW_HDMI_1_AXI_GPIO_DIVPHASE_GMAIN_SHIFTPHASE_GFEEDBACK_BASE,
#endif
#ifdef HW_HDMI_0_AXI_VDMA_0_BASE
	HW_HDMI_0_AXI_VDMA_0_BASE,
#endif
#ifdef HW_HDMI_1_AXI_VDMA_0_BASE
	HW_HDMI_1_AXI_VDMA_0_BASE,
#endif
#ifdef HW_HDMI_2_AXI_VDMA_0_BASE
	HW_HDMI_2_AXI_VDMA_0_BASE,
#endif
#ifdef HW_HDMI_0_V_TC_0_BASE
	HW_HDMI_0_V_TC_0_BASE,
#endif
#ifdef HW_AXI_DYNCLK_0_BASE
	HW_AXI_DYNCLK_0_BASE,
#endif
#ifdef HW_HDMI_0_MIXERMATRIX_MIXER_0_BASE
	HW_HDMI_0_MIXERMATRIX_MIXER_0_BASE,
#endif
#ifdef HW_DDS_AXI_INTERFACE_0_BASE
	HW_DDS_AXI_INTERFACE_0_BASE,
#endif
#ifdef HW_DDS_AXI_INTERFACE_1_BASE
	HW_DDS_AXI_INTERFACE_1_BASE,
#endif
#ifdef HW_HDMI_AUDIO_REGS_0_BASE
	HW_HDMI_AUDIO_REGS_0_BASE,
	HW_HDMI_AUDIO_REGS_0_BASE + 0x1000,	/* events page (own probe: older
						 * bitstreams alias it onto page 0) */
#endif
};

/* Blocks that an older bitstream may not have (same hw_map.h, other .bit):
 * their ID register is read once under a SIGBUS guard (a missing AXI slave
 * gives a bus error, not a value). Wrong ID or SIGBUS = absent. */
static const struct { uint32_t base, off, id; } probed[] = {
#ifdef HW_HDMI_AUDIO_REGS_0_BASE
	{ HW_HDMI_AUDIO_REGS_0_BASE, 0x3C, 0x48415544 },	/* "HAUD" */
	{ HW_HDMI_AUDIO_REGS_0_BASE + 0x1000, 0x00, 0x45564E54 },	/* "EVNT" */
#endif
	{ 0, 0, 0 }
};
#define N_KNOWN	((int)(sizeof(known_bases) / sizeof(known_bases[0])))

typedef struct {
	uint32_t           base;
	volatile uint32_t *map;
	int                fd;	/* UIO fd, -1 for /dev/mem */
	size_t             len;	/* mapped length (a UIO node can be smaller than 64K) */
	int                absent;	/* probe failed: not in the loaded bitstream */
	char               via[16];
} block;

static sigjmp_buf probe_jmp;

static void probe_sigbus(int sig)
{
	(void)sig;
	siglongjmp(probe_jmp, 1);
}

/* 0 = present (or no probe for this block), -1 = absent */
static int probe(const block *b, void *map)
{
	struct sigaction sa, old;
	volatile uint32_t v = 0;
	int k, bad = 0;

	for (k = 0; probed[k].base; k++)
		if (probed[k].base == b->base)
			break;
	if (!probed[k].base)
		return 0;
	const uint32_t off = probed[k].off, id = probed[k].id;	/* not live across the longjmp */
	memset(&sa, 0, sizeof(sa));
	sa.sa_handler = probe_sigbus;
	sigaction(SIGBUS, &sa, &old);
	if (sigsetjmp(probe_jmp, 1) == 0)
		v = ((volatile uint32_t *)map)[off / 4];
	else
		bad = 1;
	sigaction(SIGBUS, &old, NULL);
	if (bad || v != id) {
		fprintf(stderr, "dz_map: block 0x%08X not in this bitstream (%s)\n",
			(unsigned)b->base, bad ? "bus error" : "wrong ID");
		return -1;
	}
	return 0;
}

static block blocks[N_KNOWN];
static int   sim;
static int   mem_fd = -1;

/* Two threads map blocks and slots (debazd: the main thread and the pixel
 * thread, 2026-11-03). A mapping is made once under this lock and then only
 * read: the fast paths take no lock. */
static pthread_mutex_t map_mu = PTHREAD_MUTEX_INITIALIZER;

void dz_map_simulate(int on) { sim = on; }
int  dz_map_simulating(void) { return sim; }

int dz_regs_known(uint32_t base)
{
	for (int i = 0; i < N_KNOWN; i++)
		if (known_bases[i] == base)
			return 1;
	return 0;
}

static int mem_open(void)
{
	if (mem_fd < 0)
		mem_fd = open("/dev/mem", O_RDWR | O_SYNC);
	if (mem_fd < 0)
		fprintf(stderr, "dz_map: open /dev/mem: %s\n", strerror(errno));
	return mem_fd;
}

/* UIO node whose map0 address is base: open it, return fd or -1; *len =
 * the map size, at most BLOCK_MAP. */
static int uio_find(uint32_t base, char *name, size_t nlen, size_t *len)
{
	DIR *d = opendir("/sys/class/uio");
	struct dirent *e;
	int fd = -1;

	if (!d)
		return -1;
	while ((e = readdir(d)) != NULL) {
		char p[300], buf[32];
		FILE *fp;

		if (strncmp(e->d_name, "uio", 3) != 0)
			continue;
		snprintf(p, sizeof(p), "/sys/class/uio/%s/maps/map0/addr", e->d_name);
		fp = fopen(p, "r");
		if (!fp)
			continue;
		buf[0] = 0;
		if (!fgets(buf, sizeof(buf), fp))
			buf[0] = 0;
		fclose(fp);
		if (strtoul(buf, NULL, 0) != base)
			continue;
		*len = BLOCK_MAP;
		snprintf(p, sizeof(p), "/sys/class/uio/%s/maps/map0/size", e->d_name);
		fp = fopen(p, "r");
		if (fp) {
			if (fgets(buf, sizeof(buf), fp)) {
				unsigned long sz = strtoul(buf, NULL, 0);

				if (sz && sz < BLOCK_MAP)
					*len = sz;
			}
			fclose(fp);
		}
		snprintf(p, sizeof(p), "/dev/%s", e->d_name);
		fd = open(p, O_RDWR | O_SYNC);
		if (fd >= 0)
			snprintf(name, nlen, "%.15s", e->d_name);
		break;
	}
	closedir(d);
	return fd;
}

static block *find_block(uint32_t base)
{
	for (int i = 0; i < N_KNOWN; i++)
		if (known_bases[i] == base)
			return &blocks[i];
	return NULL;
}

static volatile uint32_t *regs_locked(block *b, uint32_t base);

volatile uint32_t *dz_regs(uint32_t base)
{
	block *b = find_block(base);
	volatile uint32_t *r;

	if (!b)
		return NULL;
	r = __atomic_load_n(&b->map, __ATOMIC_ACQUIRE);
	if (r || b->absent)
		return r;		/* absent = not in this bitstream: refuse */
	pthread_mutex_lock(&map_mu);
	r = regs_locked(b, base);
	pthread_mutex_unlock(&map_mu);
	return r;
}

/* the first map of a block. The pointer is published (b->map) only after
 * the probe: another thread never sees a block that may be absent. */
static volatile uint32_t *regs_locked(block *b, uint32_t base)
{
	void *m;

	if (b->absent || b->map)
		return b->map;

	b->base = base;
	b->fd = -1;
	b->len = BLOCK_MAP;
	if (sim) {
		b->map = calloc(BLOCK_MAP / 4, sizeof(uint32_t));
		snprintf(b->via, sizeof(b->via), "sim");
		for (int k = 0; b->map && probed[k].base; k++)
			if (probed[k].base == base)
				b->map[probed[k].off / 4] = probed[k].id;
		return b->map;
	}

	b->fd = uio_find(base, b->via, sizeof(b->via), &b->len);
	if (b->fd >= 0) {
		m = mmap(NULL, b->len, PROT_READ | PROT_WRITE, MAP_SHARED, b->fd, 0);
		if (m != MAP_FAILED) {
			if (probe(b, m) < 0) {
				munmap(m, b->len);
				close(b->fd);
				b->fd = -1;
				b->absent = 1;
				return NULL;
			}
			__atomic_store_n(&b->map, (volatile uint32_t *)m, __ATOMIC_RELEASE);
			return b->map;
		}
		close(b->fd);
		b->fd = -1;
		b->len = BLOCK_MAP;
	}

	if (mem_open() < 0)
		return NULL;
	m = mmap(NULL, BLOCK_MAP, PROT_READ | PROT_WRITE, MAP_SHARED, mem_fd,
		 (off_t)base);
	if (m == MAP_FAILED) {
		fprintf(stderr, "dz_map: mmap 0x%08X: %s\n", (unsigned)base,
			strerror(errno));
		return NULL;
	}
	snprintf(b->via, sizeof(b->via), "mem");
	if (probe(b, m) < 0) {
		munmap(m, BLOCK_MAP);
		b->absent = 1;
		return NULL;
	}
	__atomic_store_n(&b->map, (volatile uint32_t *)m, __ATOMIC_RELEASE);
	return b->map;
}

const char *dz_regs_via(uint32_t base)
{
	block *b = find_block(base);

	return (b && b->map) ? b->via : "";
}

int dz_regs_uio_fd(uint32_t base)
{
	block *b = find_block(base);

	if (!b)
		return -1;
	dz_regs(base);
	return b->fd;
}

/* ---- reserved memory ------------------------------------------------------- */
#define MAX_RES	8
static uint32_t res_base[MAX_RES], res_size[MAX_RES];
static int      n_res = -1;

static uint32_t be32(const uint8_t *p)
{
	return ((uint32_t)p[0] << 24) | ((uint32_t)p[1] << 16) |
	       ((uint32_t)p[2] << 8) | p[3];
}

/* Zynq-7000: #address-cells = #size-cells = 1, so reg = <base size>... */
static void res_load(void)
{
	const char *root = "/proc/device-tree/reserved-memory";
	DIR *d;
	struct dirent *e;

	if (n_res >= 0)
		return;
	n_res = 0;
	d = opendir(root);
	if (!d)
		return;
	while ((e = readdir(d)) != NULL && n_res < MAX_RES) {
		char p[512];
		uint8_t buf[64];
		FILE *fp;
		size_t n;

		if (e->d_name[0] == '.')
			continue;
		snprintf(p, sizeof(p), "%s/%s/reg", root, e->d_name);
		fp = fopen(p, "rb");
		if (!fp)
			continue;
		n = fread(buf, 1, sizeof(buf), fp);
		fclose(fp);
		for (size_t k = 0; k + 8 <= n && n_res < MAX_RES; k += 8) {
			res_base[n_res] = be32(buf + k);
			res_size[n_res] = be32(buf + k + 4);
			n_res++;
		}
	}
	closedir(d);
}


/*
 * 1 if [phys, phys+len) overlaps "System RAM" in /proc/iomem, 0 if not,
 * -1 if unknown (file missing, or not root: addresses read as zeros).
 * The reserved-memory node alone is not proof: on 2026-10-24 a node of
 * 128 MB was REJECTED by the kernel (the region reached the top of RAM,
 * where U-Boot put the DTB blob), the node stayed in /proc/device-tree,
 * and all of it was System RAM.
 */
static int ram_overlap(unsigned long phys, unsigned long len)
{
	FILE *fp = fopen("/proc/iomem", "r");
	char line[256];
	int known = 0, hit = 0;

	if (!fp)
		return -1;
	while (fgets(line, sizeof(line), fp)) {
		unsigned long a, b;

		if (line[0] == ' ' || !strstr(line, "System RAM"))
			continue;
		if (sscanf(line, "%lx-%lx", &a, &b) != 2)
			continue;
		if (a || b)
			known = 1;
		if (phys <= b && phys + len - 1 >= a)
			hit = 1;
	}
	fclose(fp);
	return known ? hit : -1;
}

int dz_reserved(uint32_t phys, uint32_t len)
{
	if (sim)
		return 1;
	if (ram_overlap(phys, len) == 1)
		return 0;	/* the kernel did not honour the reservation */
	res_load();
	for (int i = 0; i < n_res; i++)
		if (phys >= res_base[i] &&
		    (uint64_t)phys + len <= (uint64_t)res_base[i] + res_size[i])
			return 1;
	return 0;
}

int dz_slots_usable(void)
{
	int n = 0;

	while (n < DZ_SLOTS && dz_reserved(DZ_SLOT_ADDR(n), DZ_SLOT_PITCH))
		n++;
	return n;
}

/* ---- frame slots ---------------------------------------------------------- */
typedef struct {
	uint8_t *ptr;		/* start of the slot                  */
	void    *map;		/* own mmap, NULL when inside fb0     */
	size_t   len;		/* bytes mapped from the slot start   */
	char     via[8];
	int      cached;	/* dzmem: 1 = the mapping is write-back (dz_slot_cache),
				 * 0 = write-combined (non-cacheable) */
} slotmap;

static slotmap slots[DZ_SLOTS];
static uint8_t *fb_map;
static size_t   fb_len;
static uint32_t fb_phys;
static int      fb_fd = -1, fb_probed;

static void fb_probe(void)
{
	struct fb_fix_screeninfo fix;
	void *m;

	if (fb_probed)
		return;
	fb_probed = 1;
	fb_fd = open("/dev/fb0", O_RDWR);
	if (fb_fd < 0)
		return;
	if (ioctl(fb_fd, FBIOGET_FSCREENINFO, &fix) < 0 || fix.smem_len == 0)
		goto fail;
	m = mmap(NULL, fix.smem_len, PROT_READ | PROT_WRITE, MAP_SHARED, fb_fd, 0);
	if (m == MAP_FAILED)
		goto fail;
	fb_map  = m;
	fb_len  = fix.smem_len;
	fb_phys = (uint32_t)fix.smem_start;
	return;
fail:
	close(fb_fd);
	fb_fd = -1;
}

static uint8_t *slot_locked(slotmap *s, int n, size_t len);

/* ---- dzmem (cached slots, v2: ONE memory type per slot, sw/SLOTMEM.md) ----
 * Each slot has ONE mapping in this process, at a fixed address: WC
 * (non-cacheable, like /dev/mem and fb0) by default; dz_slot_cache(n, 1)
 * makes it write-back IN PLACE (MAP_FIXED over the same address, so the
 * pointers that threads hold stay valid). The module refuses a type that
 * differs from another live mapping of the slot (another process), and
 * flushes the slot when its last cached mapping closes. */
static int dz_fd_wc = -1, dz_fd_wb = -1, dz_tried;

static int dzmem_open(void)
{
	struct dzmem_info inf;
	const char *e = getenv("DZ_DZMEM");
	uint32_t wc = DZMEM_WC, wb = DZMEM_WB;

	if (dz_tried)
		return dz_fd_wc;
	dz_tried = 1;
	if (sim || (e && !strcmp(e, "0")))
		return -1;
	dz_fd_wc = open("/dev/dzmem", O_RDWR | O_CLOEXEC);
	if (dz_fd_wc < 0)
		return -1;
	if (ioctl(dz_fd_wc, DZMEM_IOC_INFO, &inf) < 0 || inf.base != DZ_SLOT_BASE ||
	    inf.size < (uint64_t)DZ_SLOTS * DZ_SLOT_PITCH || inf.version < 2) {
		fprintf(stderr, "dz_map: /dev/dzmem is not the slot region or older than v2: "
			"not used\n");
		goto fail;
	}
	/* one open file per memory type: the type is set before mmap */
	dz_fd_wb = open("/dev/dzmem", O_RDWR | O_CLOEXEC);
	if (ioctl(dz_fd_wc, DZMEM_IOC_MODE, &wc) < 0 || dz_fd_wb < 0 ||
	    ioctl(dz_fd_wb, DZMEM_IOC_MODE, &wb) < 0)
		goto fail;
	return dz_fd_wc;
fail:
	close(dz_fd_wc);
	if (dz_fd_wb >= 0)
		close(dz_fd_wb);
	dz_fd_wc = dz_fd_wb = -1;
	return -1;
}

const char *dz_slot_cached(void)
{
	return dz_fd_wc >= 0 ? "dzmem" : "";
}

uint8_t *dz_slot_rd(int n, size_t len)
{
	return dz_slot(n, len, NULL);	/* one mapping per slot (v2) */
}

/* live mappings of slot n in the module (all processes), -1 = unknown */
static int live_other_class(int n, int want_cached)
{
	FILE *f = fopen("/sys/class/misc/dzmem/slots", "r");
	char line[96];
	int rc = -1;

	if (!f)
		return -1;
	rc = 0;
	while (fgets(line, sizeof(line), f)) {
		unsigned s, wb, wt, nc;

		if (sscanf(line, "slot %u WB %u WT %u NC %u", &s, &wb, &wt, &nc) == 4 && (int)s == n)
			rc = want_cached ? (int)nc - 1 : (int)wb - 1 + (int)wt;	/* minus our own */
	}
	fclose(f);
	return rc;
}

int dz_slot_cache(int n, int on)
{
	slotmap *s;
	void *m;
	int rc = 0;

	on = !!on;
	if (n < 0 || n >= DZ_SLOTS || !dz_slot(n, DZ_SLOT_PITCH, NULL))
		return -EINVAL;
	s = &slots[n];
	if (strcmp(s->via, "dzmem") || (on && n == DZ_SLOT_CAPTURE))
		return on ? -ENOTSUP : 0;
	pthread_mutex_lock(&map_mu);
	if (s->cached == on)
		goto out;
	if (live_other_class(n, on) > 0) {	/* another process maps it the other way */
		rc = -EBUSY;
		goto out;
	}
	/* MAP_FIXED: the old mapping goes first (the module flushes it if it was
	 * cached), the new one takes the same address */
	m = mmap(s->map, DZ_SLOT_PITCH, PROT_READ | PROT_WRITE, MAP_SHARED | MAP_FIXED,
		 on ? dz_fd_wb : dz_fd_wc, (off_t)n * DZ_SLOT_PITCH);
	if (m == MAP_FAILED) {
		rc = -errno;
		/* the address range is empty now: put the old type back at once */
		m = mmap(s->map, DZ_SLOT_PITCH, PROT_READ | PROT_WRITE, MAP_SHARED | MAP_FIXED,
			 on ? dz_fd_wc : dz_fd_wb, (off_t)n * DZ_SLOT_PITCH);
		if (m == MAP_FAILED) {
			fprintf(stderr, "dz_map: slot %d LOST its mapping (%s): abort\n", n, strerror(errno));
			abort();
		}
		goto out;
	}
	s->cached = on;
out:
	pthread_mutex_unlock(&map_mu);
	return rc;
}

int dz_slot_is_cached(int n)
{
	return n >= 0 && n < DZ_SLOTS && __atomic_load_n(&slots[n].cached, __ATOMIC_ACQUIRE);
}

uint8_t *dz_slot_wb(int n)
{
	if (dz_fd_wb < 0 || n == DZ_SLOT_CAPTURE || dz_slot_cache(n, 1) < 0)
		return NULL;
	return dz_slot(n, DZ_SLOT_PITCH, NULL);
}

static uint64_t clean_ns, clean_bytes;
static unsigned clean_calls;

int dz_slot_clean(const void *addr, size_t len)
{
	struct dzmem_sync sy = { .addr = (uintptr_t)addr, .len = len, .dir = DZMEM_TO_DEVICE };

	if (dz_fd_wb < 0 || !len)
		return 0;
	if (ioctl(dz_fd_wb, DZMEM_IOC_SYNC, &sy) < 0) {
		__sync_synchronize();
		return -1;
	}
	__atomic_add_fetch(&clean_ns, sy.ns, __ATOMIC_RELAXED);
	__atomic_add_fetch(&clean_bytes, len, __ATOMIC_RELAXED);
	__atomic_add_fetch(&clean_calls, 1, __ATOMIC_RELAXED);
	return 0;
}

void dz_slot_clean_stats(uint64_t *ns, uint64_t *bytes, unsigned *calls)
{
	*ns = __atomic_load_n(&clean_ns, __ATOMIC_RELAXED);
	*bytes = __atomic_load_n(&clean_bytes, __ATOMIC_RELAXED);
	*calls = __atomic_load_n(&clean_calls, __ATOMIC_RELAXED);
}

/* A slot is mapped once with its full pitch when the reservation covers it
 * (2026-11-03): before, a longer request unmapped the slot and mapped it
 * again, under the feet of another thread that held the old pointer (anim
 * workers map the full pitch, the draw code the mode-sized part). */
uint8_t *dz_slot(int n, size_t len, const char **via)
{
	slotmap *s;
	uint8_t *p;

	if (n < 0 || n >= DZ_SLOTS || len == 0 || len > DZ_SLOT_PITCH)
		return NULL;
	s = &slots[n];
	p = __atomic_load_n(&s->ptr, __ATOMIC_ACQUIRE);
	if (!p || s->len < len) {
		pthread_mutex_lock(&map_mu);
		p = slot_locked(s, n, len);
		pthread_mutex_unlock(&map_mu);
	}
	if (p && via)
		*via = s->via;
	return p;
}

static uint8_t *slot_locked(slotmap *s, int n, size_t len)
{
	uint32_t phys = DZ_SLOT_ADDR(n);
	void *m;

	if (!dz_reserved(phys, (uint32_t)len)) {
		fprintf(stderr, "dz_map: slot %d (0x%08X + %zu) is outside reserved "
			"memory - refused (see CLAUDE.md, reserved-memory)\n", n,
			(unsigned)phys, len);
		return NULL;
	}
	if (s->ptr && s->len >= len)
		return s->ptr;
	if (dz_reserved(phys, DZ_SLOT_PITCH))
		len = DZ_SLOT_PITCH;		/* the whole slot: never grows again */
	if (s->map) {			/* grow (reservation ends inside the slot) */
		if (sim)
			free(s->map);
		else
			munmap(s->map, s->len);
		s->map = NULL;
		s->ptr = NULL;
	}

	if (sim) {
		s->map = calloc(1, DZ_SLOT_PITCH);
		if (!s->map)
			return NULL;
		s->len = DZ_SLOT_PITCH;
		snprintf(s->via, sizeof(s->via), "sim");
		__atomic_store_n(&s->ptr, (uint8_t *)s->map, __ATOMIC_RELEASE);
		return s->ptr;
	}

	/* dzmem: the whole slot write-combined (in the module's type guard);
	 * dz_slot_cache() makes it write-back in place */
	if (dzmem_open() >= 0 && dz_reserved(phys, DZ_SLOT_PITCH)) {
		m = mmap(NULL, DZ_SLOT_PITCH, PROT_READ | PROT_WRITE, MAP_SHARED, dz_fd_wc,
			 (off_t)n * DZ_SLOT_PITCH);
		if (m != MAP_FAILED) {
			s->map = m;
			s->len = DZ_SLOT_PITCH;
			s->cached = 0;
			snprintf(s->via, sizeof(s->via), "dzmem");
			__atomic_store_n(&s->ptr, (uint8_t *)m, __ATOMIC_RELEASE);
			return s->ptr;
		}
		if (errno == EBUSY) {	/* another process maps it with the other type:
					 * /dev/mem would be a third type on it */
			fprintf(stderr, "dz_map: slot %d is mapped write-back by another process "
				"(dzmem refused): not mapped\n", n);
			return NULL;
		}
		fprintf(stderr, "dz_map: dzmem mmap slot %d: %s (falls back to /dev/mem)\n",
			n, strerror(errno));
	}

	fb_probe();
	if (fb_map && phys >= fb_phys && (size_t)(phys - fb_phys) + len <= fb_len) {
		s->len = fb_len - (phys - fb_phys);
		snprintf(s->via, sizeof(s->via), "fb0");
		__atomic_store_n(&s->ptr, fb_map + (phys - fb_phys), __ATOMIC_RELEASE);
		return s->ptr;
	}

	if (mem_open() < 0)
		return NULL;
	/* slot addresses are page aligned (0x7E9000 = 2025 pages) */
	m = mmap(NULL, len, PROT_READ | PROT_WRITE, MAP_SHARED, mem_fd, (off_t)phys);
	if (m == MAP_FAILED) {
		fprintf(stderr, "dz_map: mmap slot %d: %s\n", n, strerror(errno));
		return NULL;
	}
	s->map = m;
	s->len = len;
	snprintf(s->via, sizeof(s->via), "mem");
	__atomic_store_n(&s->ptr, (uint8_t *)m, __ATOMIC_RELEASE);
	return s->ptr;
}

void dz_unmap_all(void)
{
	for (int i = 0; i < N_KNOWN; i++) {
		block *b = &blocks[i];

		if (b->map) {
			if (sim)
				free((void *)b->map);
			else
				munmap((void *)b->map, b->len);
		}
		if (b->fd >= 0)
			close(b->fd);
		memset(b, 0, sizeof(*b));
		b->fd = -1;
	}
	for (int i = 0; i < DZ_SLOTS; i++) {
		slotmap *s = &slots[i];

		if (s->map) {
			if (sim)
				free(s->map);
			else
				munmap(s->map, s->len);
		}
		memset(s, 0, sizeof(*s));
	}
	if (fb_map)
		munmap(fb_map, fb_len);
	fb_map = NULL;
	if (fb_fd >= 0)
		close(fb_fd);
	fb_fd = -1;
	fb_probed = 0;
	if (mem_fd >= 0)
		close(mem_fd);
	mem_fd = -1;
}

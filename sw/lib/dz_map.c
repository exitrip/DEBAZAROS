/*
 * dz_map.c - see dz_map.h.
 */
#define _GNU_SOURCE
#include "dz_map.h"
#include "dz_hw.h"

#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <linux/fb.h>
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
static int probe(block *b)
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
		v = b->map[off / 4];
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

volatile uint32_t *dz_regs(uint32_t base)
{
	block *b = find_block(base);
	void *m;

	if (!b || b->absent)
		return NULL;		/* not in this bitstream: refuse */
	if (b->map)
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
			b->map = m;
			if (probe(b) < 0) {
				munmap(m, b->len);
				close(b->fd);
				b->fd = -1;
				b->map = NULL;
				b->absent = 1;
			}
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
	b->map = m;
	snprintf(b->via, sizeof(b->via), "mem");
	if (probe(b) < 0) {
		munmap(m, BLOCK_MAP);
		b->map = NULL;
		b->absent = 1;
	}
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

	while (n < DZ_SLOTS && dz_reserved(DZ_SLOT_ADDR(n), DZ_WIDTH * DZ_HEIGHT * DZ_BPP))
		n++;
	return n;
}

/* ---- frame slots ---------------------------------------------------------- */
typedef struct {
	uint8_t *ptr;		/* start of the slot                  */
	void    *map;		/* own mmap, NULL when inside fb0     */
	size_t   len;		/* bytes mapped from the slot start   */
	char     via[8];
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

uint8_t *dz_slot(int n, size_t len, const char **via)
{
	slotmap *s;
	uint32_t phys;
	void *m;

	if (n < 0 || n >= DZ_SLOTS || len == 0 || len > DZ_SLOT_PITCH)
		return NULL;
	s = &slots[n];
	phys = DZ_SLOT_ADDR(n);
	if (!dz_reserved(phys, (uint32_t)len)) {
		fprintf(stderr, "dz_map: slot %d (0x%08X + %zu) is outside reserved "
			"memory - refused (see CLAUDE.md, reserved-memory)\n", n,
			(unsigned)phys, len);
		return NULL;
	}

	if (s->ptr && s->len >= len)
		goto done;
	if (s->map) {			/* grow: drop the old mapping */
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
		s->ptr = s->map;
		s->len = DZ_SLOT_PITCH;
		snprintf(s->via, sizeof(s->via), "sim");
		goto done;
	}

	fb_probe();
	if (fb_map && phys >= fb_phys && (size_t)(phys - fb_phys) + len <= fb_len) {
		s->ptr = fb_map + (phys - fb_phys);
		s->len = fb_len - (phys - fb_phys);
		snprintf(s->via, sizeof(s->via), "fb0");
		goto done;
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
	s->ptr = m;
	s->len = len;
	snprintf(s->via, sizeof(s->via), "mem");
done:
	if (via)
		*via = s->via;
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

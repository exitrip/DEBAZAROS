/*
 * fbfeed - write raw BGRA/xRGB frames from stdin into a VDMA scanout slot.
 *
 * DEBAZAROS: the PL has two VDMAs but Linux gives only one /dev/fb, because
 * simplefb refuses a second instance (num_registered_fb > 0 check in
 * simplefb_probe).  fbfeed feeds the second display without a kernel change.
 *
 * Two target styles:
 *
 *   1) /dev/mem at the physical slot address (works today, no DTS change):
 *        fbfeed -d /dev/mem -a 0x08FD2000 -w 1280 -h 720
 *      The reserved region is "removed-dma-pool" + no-map, so it is not
 *      System RAM and /dev/mem will map it.  ARM maps non-RAM as uncached,
 *      so writes are slow (tens of MB/s).  Measure with -v before trusting it.
 *
 *   2) /dev/fb0 at a byte offset (faster: simplefb maps write-combined).
 *      Needs the fb node grown to cover both slots.  With disp0 at
 *      0x08000000 and disp1 at 0x08FD2000, stride 5120:
 *        offset = 0x08FD2000 - 0x08000000 = 16588800 bytes = row 3240
 *        fb height must be >= 3240 + 720 = 3960
 *      then:
 *        fbfeed -d /dev/fb0 -o 16588800 -w 1280 -h 720
 *
 * Input is raw frames of width*height*4 bytes, top row first, matching the
 * format= of the scanout slot.  For "a8r8g8b8" ask ffmpeg for bgra:
 *
 *   ffmpeg -stream_loop -1 -re -i clip2.mp4 -vf scale=1280:720 \
 *          -pix_fmt bgra -f rawvideo pipe:1 | fbfeed -a 0x08FD2000
 *
 * There is no vsync source here, so tearing is possible.  The VDMA is parked
 * on one frame; do not point fbfeed at a slot the display is not parked on.
 *
 * Build: make            (native)
 *        make CROSS_COMPILE=arm-xilinx-linux-gnueabihf-
 */

#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <getopt.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <dirent.h>
#include <time.h>
#include <unistd.h>

#include "dz_yuv.h"

#if defined(__ARM_NEON)
#include <arm_neon.h>
#endif
#include <poll.h>

#define DEF_DEV	   "/dev/mem"
#define DEF_ADDR   0x08FD2000UL	/* HDMI_1 slot = 2 * DEMO_MAX_FRAME */
#define DEF_WIDTH  1280
#define DEF_HEIGHT 720
#define BYTES_PP   4

static volatile sig_atomic_t stop;

static void on_signal(int sig)
{
	(void)sig;
	stop = 1;
}

static double now_s(void)
{
	struct timespec ts;

	clock_gettime(CLOCK_MONOTONIC, &ts);
	return ts.tv_sec + ts.tv_nsec / 1e9;
}

/* ---- frame memory effects on the yuv420p input (2026-11-01) ----
 * trails d: luma = max(new, old * d) (as ffmpeg lagfun, which the A9 runs
 *           at ~10 fps at 720p); the chroma comes from whichever pixel won
 *           the luma, so a trail keeps its colour
 * ghost k:  every plane = old * k + new * (1 - k) (an echo of the motion)
 * Both run on the frame in a cached buffer before the conversion: about
 * 1 ms per 720p frame with NEON. Live control: -L fifo, lines "trails d",
 * "ghost k", "off" (debazd /movie/<s>/trails, /ghost). */
static int    fx_mode;			/* 0 off, 1 trails, 2 ghost */
static unsigned fx_k8;			/* d or k as 0..256 */
static uint8_t *fx_prev;		/* the last output frame (i420) */
static int    fx_valid;
static int    ctl_fd = -1;
static const char *ctl_path;
static const char *stat_path;		/* -S: one line per second for debazd */

static void fx_set(int mode, double v)
{
	v = v < 0 ? 0 : v > 1 ? 1 : v;
	fx_k8 = (unsigned)(v * 256.0 + 0.5);
	fx_mode = fx_k8 ? mode : 0;
	if (!fx_mode)
		fx_valid = 0;
}

static void ctl_poll(void)
{
	static char buf[256];
	static size_t len;
	struct pollfd p = { .fd = ctl_fd, .events = POLLIN };

	if (ctl_fd < 0 || poll(&p, 1, 0) <= 0)
		return;
	ssize_t n = read(ctl_fd, buf + len, sizeof(buf) - 1 - len);
	if (n <= 0)
		return;
	len += (size_t)n;
	buf[len] = 0;
	for (char *nl; (nl = strchr(buf, '\n'));) {
		char word[16];
		double v = 0;

		*nl = 0;
		if (sscanf(buf, "%15s %lf", word, &v) >= 1) {
			if (!strcmp(word, "trails"))
				fx_set(1, v);
			else if (!strcmp(word, "ghost"))
				fx_set(2, v);
			else if (!strcmp(word, "off"))
				fx_set(0, 0);
		}
		len -= (size_t)(nl + 1 - buf);
		memmove(buf, nl + 1, len + 1);
	}
	if (len == sizeof(buf) - 1)
		len = 0;
}

/* in = the new frame; returns the frame to show (fx_prev, or in when off) */
static const uint8_t *fx_frame(const uint8_t *in, int w, int h)
{
	size_t ny = (size_t)w * h, nc = ny / 4;

	if (!fx_mode || !fx_prev)
		return in;
	if (!fx_valid) {			/* the first frame: nothing to remember */
		memcpy(fx_prev, in, ny + 2 * nc);
		fx_valid = 1;
		return fx_prev;
	}
	uint8_t *py = fx_prev, *pu = py + ny, *pv = pu + nc;
	const uint8_t *iy = in, *iu = iy + ny, *iv = iu + nc;
	unsigned k = fx_k8, nk = 256 - k;

	if (fx_mode == 2) {			/* ghost: blend every byte */
		size_t n = ny + 2 * nc, i = 0;
#if defined(__ARM_NEON)
		uint8x8_t vk = vdup_n_u8((uint8_t)(k > 255 ? 255 : k)), vn = vdup_n_u8((uint8_t)(nk > 255 ? 255 : nk));
		for (; i + 16 <= n; i += 16) {
			uint8x16_t o = vld1q_u8(py + i), a = vld1q_u8(iy + i);
			uint16x8_t lo = vmlal_u8(vmull_u8(vget_low_u8(o), vk), vget_low_u8(a), vn);
			uint16x8_t hi = vmlal_u8(vmull_u8(vget_high_u8(o), vk), vget_high_u8(a), vn);
			vst1q_u8(py + i, vcombine_u8(vrshrn_n_u16(lo, 8), vrshrn_n_u16(hi, 8)));
		}
#endif
		for (; i < n; i++)
			py[i] = (uint8_t)((py[i] * k + iy[i] * nk + 128) >> 8);
		return fx_prev;
	}
	/* trails: chroma first (it needs the old luma), from the luma winner */
	for (int y = 0; y < h / 2; y++) {
		const uint8_t *oy = py + (size_t)(2 * y) * w, *nyr = iy + (size_t)(2 * y) * w;
		size_t c = (size_t)y * (w / 2);

		for (int x = 0; x < w / 2; x++)
			if (((oy[2 * x] * k) >> 8) <= nyr[2 * x]) {
				pu[c + x] = iu[c + x];
				pv[c + x] = iv[c + x];
			}
	}
	size_t i = 0;
#if defined(__ARM_NEON)
	uint8x8_t vk = vdup_n_u8((uint8_t)(k > 255 ? 255 : k));
	for (; i + 16 <= ny; i += 16) {
		uint8x16_t o = vld1q_u8(py + i), a = vld1q_u8(iy + i);
		uint8x16_t d = vcombine_u8(vshrn_n_u16(vmull_u8(vget_low_u8(o), vk), 8),
					   vshrn_n_u16(vmull_u8(vget_high_u8(o), vk), 8));
		vst1q_u8(py + i, vmaxq_u8(a, d));
	}
#endif
	for (; i < ny; i++) {
		unsigned d = (py[i] * k) >> 8;
		py[i] = (uint8_t)(iy[i] > d ? iy[i] : d);
	}
	return fx_prev;
}

/* -S file (2026-11-02, debazd /movie/<s>/stats): "frames N fps F ms M" =
 * frames written, frames per second and the mean time per frame spent
 * here (conversion + effects + write) over the last second. Written as
 * file.tmp + rename, so a reader never sees half a line. */
static void stat_write(unsigned long frames, double fps, double ms)
{
	char tmp[256], line[96];
	int fd, n;

	if (!stat_path)
		return;
	snprintf(tmp, sizeof(tmp), "%s.tmp", stat_path);
	n = snprintf(line, sizeof(line), "frames %lu fps %.2f ms %.2f\n", frames, fps, ms);
	fd = open(tmp, O_WRONLY | O_CREAT | O_TRUNC, 0644);
	if (fd < 0)
		return;
	if (write(fd, line, (size_t)n) == n)
		rename(tmp, stat_path);
	close(fd);
}

/* Read exactly len bytes.  Returns 0 on EOF, 1 on success, -1 on error. */
static int read_full(int fd, void *buf, size_t len)
{
	uint8_t *p = buf;
	size_t got = 0;

	while (got < len) {
		ssize_t n = read(fd, p + got, len - got);

		if (n == 0)
			return got == 0 ? 0 : -2;	/* -2 = short frame */
		if (n < 0) {
			if (errno == EINTR) {
				if (stop)
					return 0;
				continue;
			}
			return -1;
		}
		got += (size_t)n;
	}
	return 1;
}

/*
 * 1 if [phys, phys+len) lies inside a reserved-memory region of the running
 * kernel. /dev/mem also maps normal Linux RAM; writing a frame there corrupts
 * running programs (seen on the bench, Oct 2026: only 16 MB was reserved).
 */

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

static int reserved(unsigned long phys, size_t len)
{
	const char *root = "/proc/device-tree/reserved-memory";
	DIR *d = opendir(root);
	struct dirent *e;
	int ok = 0;

	if (ram_overlap(phys, len) == 1) {
		if (d)
			closedir(d);
		return 0;
	}
	if (!d)
		return 0;
	while (!ok && (e = readdir(d)) != NULL) {
		char p[512];
		uint8_t b[64];
		FILE *fp;
		size_t n;

		if (e->d_name[0] == '.')
			continue;
		snprintf(p, sizeof(p), "%s/%s/reg", root, e->d_name);
		fp = fopen(p, "rb");
		if (!fp)
			continue;
		n = fread(b, 1, sizeof(b), fp);
		fclose(fp);
		for (size_t k = 0; k + 8 <= n; k += 8) {
			unsigned long base = ((unsigned long)b[k] << 24) | (b[k + 1] << 16) |
					     (b[k + 2] << 8) | b[k + 3];
			unsigned long size = ((unsigned long)b[k + 4] << 24) | (b[k + 5] << 16) |
					     (b[k + 6] << 8) | b[k + 7];

			if (phys >= base && (unsigned long long)phys + len <=
			    (unsigned long long)base + size)
				ok = 1;
		}
	}
	closedir(d);
	return ok;
}

/* NEON vs C on random rows, plus known colours. 0 = pass. */
static int yuv_selftest(void)
{
	enum { W = 1280 };
	static uint8_t y[W], u[W / 2], v[W / 2], a[W * 4], b[W * 4];
	unsigned seed = 12345;
	int bad = 0;

	for (int m = 0; m < 2; m++) {
		for (int t = 0; t < 200; t++) {
			int w = (t % 7 == 0) ? W - 2 * (t % 13) : W;	/* odd tails too */

			for (int i = 0; i < W; i++) {
				seed = seed * 1103515245u + 12345u;
				y[i] = (uint8_t)(seed >> 16);
				if (i < W / 2) {
					u[i] = (uint8_t)(seed >> 8);
					v[i] = (uint8_t)(seed >> 24);
				}
			}
			dz_i420_row(y, u, v, a, w, (dz_yuv_matrix)m);
			dz_i420_row_c(y, u, v, b, w, (dz_yuv_matrix)m);
			if (memcmp(a, b, (size_t)w * 4)) {
				fprintf(stderr, "selftest: NEON != C (matrix %d, row %d)\n", m, t);
				bad = 1;
				break;
			}
		}
	}
	/* white, black, red (BT.709 limited range: Y 63, U 102, V 240) */
	{
		static const struct { uint8_t y, u, v, r, g, b; int tol; } k[] = {
			{ 235, 128, 128, 255, 255, 255, 1 },
			{  16, 128, 128,   0,   0,   0, 0 },
			{  63, 102, 240, 255,   0,   0, 3 },
		};

		for (unsigned i = 0; i < sizeof(k) / sizeof(k[0]); i++) {
			memset(y, k[i].y, 16); memset(u, k[i].u, 8); memset(v, k[i].v, 8);
			dz_i420_row(y, u, v, a, 16, DZ_YUV_BT709);
			if (abs(a[2] - k[i].r) > k[i].tol || abs(a[1] - k[i].g) > k[i].tol ||
			    abs(a[0] - k[i].b) > k[i].tol || a[3] != 0xFF) {
				fprintf(stderr, "selftest: colour %u -> %d %d %d, want %d %d %d\n",
					i, a[2], a[1], a[0], k[i].r, k[i].g, k[i].b);
				bad = 1;
			}
		}
	}
	/* speed: one 720p frame */
	{
		static uint8_t fy[W * 720], fu[W * 180], fv[W * 180];
		static uint8_t out[W * 720 * 4];
		uint8_t *f = malloc((size_t)W * 720 * 3 / 2);
		double t0;

		if (f) {
			memcpy(f, fy, sizeof(fy));
			memcpy(f + sizeof(fy), fu, sizeof(fu));
			memcpy(f + sizeof(fy) + sizeof(fu), fv, sizeof(fv));
			t0 = now_s();
			for (int i = 0; i < 20; i++)
				dz_i420_frame(f, W, 720, out, W * 4, DZ_YUV_BT709);
			fprintf(stderr, "selftest: 720p frame in %.2f ms (%s)\n",
				(now_s() - t0) / 20 * 1000.0, dz_yuv_neon() ? "NEON" : "C");
			free(f);
		}
	}
	fprintf(stderr, "selftest: %s\n", bad ? "FAIL" : "pass");
	return bad;
}

static void usage(const char *me)
{
	fprintf(stderr,
"usage: %s [options]   (raw frames on stdin)\n"
"  -d, --dev PATH      target device            (default %s)\n"
"  -a, --addr HEX      physical address, /dev/mem style (default 0x%08lX)\n"
"  -o, --offset BYTES  byte offset, /dev/fbN style (overrides --addr)\n"
"  -w, --width PX      frame width              (default %d)\n"
"  -h, --height PX     frame height             (default %d)\n"
"  -s, --stride BYTES  destination line length  (default width*4)\n"
"  -c, --color RRGGBB  fill once with this color and exit (no stdin)\n"
"  -v, --verbose       print throughput every 30 frames\n"
"  -f, --force         /dev/mem: allow an address outside reserved memory\n"
"  -y, --yuv           input is yuv420p (I420, 1.5 bytes/px): converted here\n"
"                      (NEON), much cheaper than ffmpeg -pix_fmt bgra\n"
"  -m, --matrix 709|601  YUV matrix for -y (default 709)\n"
"  -T, --trails D      -y: trails, luma = max(new, old * D), D 0..1\n"
"  -G, --ghost K       -y: ghost, frame = old * K + new * (1 - K)\n"
"  -L, --ctl FIFO      control FIFO (made here): trails D | ghost K | off\n"
"  -S, --stats FILE    each second: frames N fps F ms M (time per frame here)\n"
"      --selftest      check the YUV converter (NEON vs C) and exit\n"
"      --help          this text\n",
		me, DEF_DEV, DEF_ADDR, DEF_WIDTH, DEF_HEIGHT);
}

int main(int argc, char **argv)
{
	const char *dev = DEF_DEV;
	unsigned long addr = DEF_ADDR;
	unsigned long offset = 0;
	int have_offset = 0;
	int width = DEF_WIDTH, height = DEF_HEIGHT;
	size_t stride = 0;
	long color = -1;
	int verbose = 0;
	int force = 0;
	int yuv = 0;
	dz_yuv_matrix matrix = DZ_YUV_BT709;

	static const struct option lopts[] = {
		{ "dev",     required_argument, NULL, 'd' },
		{ "addr",    required_argument, NULL, 'a' },
		{ "offset",  required_argument, NULL, 'o' },
		{ "width",   required_argument, NULL, 'w' },
		{ "height",  required_argument, NULL, 'h' },
		{ "stride",  required_argument, NULL, 's' },
		{ "color",   required_argument, NULL, 'c' },
		{ "verbose", no_argument,       NULL, 'v' },
		{ "force",   no_argument,       NULL, 'f' },
		{ "yuv",     no_argument,       NULL, 'y' },
		{ "matrix",  required_argument, NULL, 'm' },
		{ "trails",  required_argument, NULL, 'T' },
		{ "ghost",   required_argument, NULL, 'G' },
		{ "ctl",     required_argument, NULL, 'L' },
		{ "stats",   required_argument, NULL, 'S' },
		{ "selftest", no_argument,      NULL, 2   },
		{ "help",    no_argument,       NULL, 1   },
		{ 0, 0, 0, 0 }
	};
	int opt;

	while ((opt = getopt_long(argc, argv, "d:a:o:w:h:s:c:vfym:T:G:L:S:", lopts, NULL)) != -1) {
		switch (opt) {
		case 'd': dev = optarg; break;
		case 'a': addr = strtoul(optarg, NULL, 0); break;
		case 'o': offset = strtoul(optarg, NULL, 0); have_offset = 1; break;
		case 'w': width = atoi(optarg); break;
		case 'h': height = atoi(optarg); break;
		case 's': stride = strtoul(optarg, NULL, 0); break;
		case 'c': color = strtol(optarg, NULL, 16); break;
		case 'v': verbose = 1; break;
		case 'f': force = 1; break;
		case 'y': yuv = 1; break;
		case 'm': matrix = atoi(optarg) == 601 ? DZ_YUV_BT601 : DZ_YUV_BT709; break;
		case 'T': fx_set(1, atof(optarg)); break;
		case 'G': fx_set(2, atof(optarg)); break;
		case 'L': ctl_path = optarg; break;
		case 'S': stat_path = optarg; break;
		case 2:   return yuv_selftest();
		case 1:   usage(argv[0]); return 0;
		default:  usage(argv[0]); return 2;
		}
	}

	if (yuv && ((width | height) & 1)) {
		fprintf(stderr, "fbfeed: -y needs an even width and height\n");
		return 2;
	}
	if (width <= 0 || height <= 0) {
		fprintf(stderr, "fbfeed: bad geometry %dx%d\n", width, height);
		return 2;
	}

	const size_t row_bytes = (size_t)width * BYTES_PP;

	if (stride == 0)
		stride = row_bytes;
	if (stride < row_bytes) {
		fprintf(stderr, "fbfeed: stride %zu < row %zu\n", stride, row_bytes);
		return 2;
	}

	/* Where the frame starts, in the file's own address space. */
	const unsigned long start = have_offset ? offset : addr;
	const size_t span = (size_t)(height - 1) * stride + row_bytes;

	/* mmap needs a page-aligned file offset; keep the remainder as a shift. */
	const long page = sysconf(_SC_PAGESIZE);
	const unsigned long map_off = start & ~((unsigned long)page - 1);
	const size_t shift = (size_t)(start - map_off);
	const size_t map_len = shift + span;

	if (!have_offset && strcmp(dev, "/dev/mem") == 0 && !force &&
	    !reserved(start, span)) {
		fprintf(stderr, "fbfeed: 0x%08lX + %zu is outside reserved memory: it is "
			"Linux RAM, writing it corrupts running programs. Refused "
			"(-f to override).\n", start, span);
		return 1;
	}

	int fd = open(dev, O_RDWR | O_SYNC);

	if (fd < 0) {
		fprintf(stderr, "fbfeed: open %s: %s\n", dev, strerror(errno));
		return 1;
	}

	uint8_t *map = mmap(NULL, map_len, PROT_READ | PROT_WRITE, MAP_SHARED,
			    fd, (off_t)map_off);

	if (map == MAP_FAILED) {
		fprintf(stderr, "fbfeed: mmap %s @0x%lX len %zu: %s\n",
			dev, map_off, map_len, strerror(errno));
		close(fd);
		return 1;
	}

	uint8_t *dst = map + shift;

	fprintf(stderr, "fbfeed: %s @0x%08lX %dx%d stride %zu (%zu bytes/frame)\n",
		dev, start, width, height, stride, span);

	/* One-shot fill: bring-up test, tells you which monitor is which. */
	if (color >= 0) {
		uint32_t px = 0xFF000000u | (uint32_t)(color & 0xFFFFFF);

		for (int y = 0; y < height; y++) {
			uint32_t *row = (uint32_t *)(dst + (size_t)y * stride);

			for (int x = 0; x < width; x++)
				row[x] = px;
		}
		munmap(map, map_len);
		close(fd);
		return 0;
	}

	const size_t in_bytes = yuv ? (size_t)width * height * 3 / 2
				    : row_bytes * (size_t)height;
	uint8_t *frame = malloc(in_bytes);

	if (yuv)				/* trails / ghost memory */
		fx_prev = malloc(in_bytes);
	if (yuv && ctl_path) {
		unlink(ctl_path);
		if (mkfifo(ctl_path, 0600) == 0) {
			ctl_fd = open(ctl_path, O_RDONLY | O_NONBLOCK);
			open(ctl_path, O_WRONLY | O_NONBLOCK);	/* never EOF */
		}
	}

	if (!frame) {
		fprintf(stderr, "fbfeed: out of memory\n");
		munmap(map, map_len);
		close(fd);
		return 1;
	}

	struct sigaction sa = { 0 };

	sa.sa_handler = on_signal;
	sigaction(SIGINT, &sa, NULL);
	sigaction(SIGTERM, &sa, NULL);
	signal(SIGPIPE, SIG_IGN);

	unsigned long frames = 0, st_frames = 0;
	double t0 = now_s(), st_t0 = t0, st_busy = 0;
	int rc = 0;

	while (!stop) {
		int r = read_full(STDIN_FILENO, frame, in_bytes);

		if (r == 0)
			break;			/* clean EOF */
		if (r == -2) {
			fprintf(stderr, "fbfeed: short frame, stopping\n");
			rc = 1;
			break;
		}
		if (r < 0) {
			fprintf(stderr, "fbfeed: read: %s\n", strerror(errno));
			rc = 1;
			break;
		}

		double tb = now_s();

		/* Sequential writes: best case for write-combining. */
		if (yuv) {
			ctl_poll();
			dz_i420_frame(fx_frame(frame, width, height), width, height, dst, stride, matrix);
		} else if (stride == row_bytes) {
			memcpy(dst, frame, row_bytes * (size_t)height);
		} else {
			for (int y = 0; y < height; y++)
				memcpy(dst + (size_t)y * stride,
				       frame + (size_t)y * row_bytes, row_bytes);
		}

		/*
		 * Drain the write buffer before the next frame.  A /dev/fbN
		 * mapping is write-combining (bufferable), so stores can still
		 * be in flight here; the VDMA reads DDR directly and does not
		 * snoop.  Costs one barrier per frame.
		 */
		__sync_synchronize();

		if (stat_path) {
			double t = now_s();

			st_busy += t - tb;
			st_frames++;
			if (t - st_t0 >= 1.0) {
				static unsigned long total;

				total += st_frames;
				stat_write(total, st_frames / (t - st_t0), st_busy / st_frames * 1e3);
				st_t0 = t;
				st_frames = 0;
				st_busy = 0;
			}
		}
		if (verbose && ++frames % 30 == 0) {
			/* MB/s below = bytes written to the slot */
			double t = now_s(), dt = t - t0;

			if (dt > 0)
				fprintf(stderr,
					"fbfeed: %.1f fps, %.1f MB/s written\n",
					30.0 / dt,
					(double)span * 30.0 / dt / 1e6);
			t0 = t;
		}
	}

	free(frame);
	free(fx_prev);
	if (ctl_path && ctl_fd >= 0)
		unlink(ctl_path);
	if (stat_path)
		unlink(stat_path);
	munmap(map, map_len);
	close(fd);
	return rc;
}

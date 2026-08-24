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
#include <time.h>
#include <unistd.h>

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

	static const struct option lopts[] = {
		{ "dev",     required_argument, NULL, 'd' },
		{ "addr",    required_argument, NULL, 'a' },
		{ "offset",  required_argument, NULL, 'o' },
		{ "width",   required_argument, NULL, 'w' },
		{ "height",  required_argument, NULL, 'h' },
		{ "stride",  required_argument, NULL, 's' },
		{ "color",   required_argument, NULL, 'c' },
		{ "verbose", no_argument,       NULL, 'v' },
		{ "help",    no_argument,       NULL, 1   },
		{ 0, 0, 0, 0 }
	};
	int opt;

	while ((opt = getopt_long(argc, argv, "d:a:o:w:h:s:c:v", lopts, NULL)) != -1) {
		switch (opt) {
		case 'd': dev = optarg; break;
		case 'a': addr = strtoul(optarg, NULL, 0); break;
		case 'o': offset = strtoul(optarg, NULL, 0); have_offset = 1; break;
		case 'w': width = atoi(optarg); break;
		case 'h': height = atoi(optarg); break;
		case 's': stride = strtoul(optarg, NULL, 0); break;
		case 'c': color = strtol(optarg, NULL, 16); break;
		case 'v': verbose = 1; break;
		case 1:   usage(argv[0]); return 0;
		default:  usage(argv[0]); return 2;
		}
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

	uint8_t *frame = malloc(row_bytes * (size_t)height);

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

	unsigned long frames = 0;
	double t0 = now_s();
	int rc = 0;

	while (!stop) {
		int r = read_full(STDIN_FILENO, frame, row_bytes * (size_t)height);

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

		/* Sequential writes: best case for write-combining. */
		if (stride == row_bytes) {
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

		if (verbose && ++frames % 30 == 0) {
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
	munmap(map, map_len);
	close(fd);
	return rc;
}

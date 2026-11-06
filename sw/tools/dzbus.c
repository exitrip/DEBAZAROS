/*
 * dzbus.c - test the user I/O lines PL_KEY0-5 between two boards (2026-11-04):
 * a fast sampler of the 6 line levels and software I2C / SPI subordinates.
 * The PS has SPI and I2C controllers only (the 5.15 kernel has no I2C or SPI
 * subordinate mode), so the board on the other end of the wires runs this.
 *
 *   dzbus levels                      the 6 line levels and functions now
 *   dzbus set <line> in|out0|out1     one line (GPIO function 0 / 1)
 *   dzbus sniff <ms> [-i scl sda] [-s sclk cosi cs [ciso]] [-r]
 *                                     record every edge (real time, CPU 1),
 *                                     then: samples/s, edges and the shortest
 *                                     pulse per line, an I2C / SPI mode 0
 *                                     decode (-r: every edge)
 *   dzbus i2csub <scl> <sda> <addr> <ms> [-x]
 *                                     an I2C subordinate at addr (7 bit): ACKs
 *                                     its address, writes = [reg] [data...]
 *                                     into a 256-byte register file, reads
 *                                     return from reg on (mem[i] = i ^ 0x5A at
 *                                     the start). Open drain: a line is driven
 *                                     low (function 1, value 0) or released
 *                                     (input), never driven high. -x = hold
 *                                     SCL low while it acts (clock stretch)
 *   dzbus spisub <sclk> <cosi> <ciso> <cs> <ms>
 *                                     an SPI subordinate, mode 0: CISO byte k
 *                                     = COSI byte k-1 of the same frame (the
 *                                     first = 0xA5), CISO driven push-pull
 *
 * Registers: hdmi_audio_regs (0x43C6_0000) 0x40 IO_FUNC (4 bits per line),
 * 0x44 IO_OUT [5:0], 0x48 IO_IN [5:0] (2-FF synchronised to FCLK0). The line
 * functions are put back at the end. debazd may run (it writes IO_FUNC only
 * for /io/pin, IO_OUT bits [13:8] only for the fan outputs).
 * Run as root (/dev/mem). Lines: 0-3 = PL_KEY0-3, 4 = PL_KEY4 (K17), 5 =
 * PL_KEY5 (E19).
 */
#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <sched.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <time.h>
#include <unistd.h>

#define REGS_BASE	0x43C60000u
#define R_FUNC		(0x40 / 4)
#define R_OUT		(0x44 / 4)
#define R_IN		(0x48 / 4)
#define MAXEV		(1 << 20)

static volatile uint32_t *R;
static uint32_t func0;			/* IO_FUNC at the start, put back at exit */
static volatile sig_atomic_t stop_now;

typedef struct {
	uint64_t t;			/* ns since the start */
	uint8_t  v;			/* line levels after the edge */
} ev_t;

static ev_t *ev;
static int   nev;

static uint64_t now_ns(void)
{
	struct timespec ts;

	clock_gettime(CLOCK_MONOTONIC, &ts);
	return (uint64_t)ts.tv_sec * 1000000000ull + (uint64_t)ts.tv_nsec;
}

static void on_signal(int s)
{
	(void)s;
	stop_now = 1;
}

static int map_regs(void)
{
	int fd = open("/dev/mem", O_RDWR | O_SYNC);

	if (fd < 0) {
		perror("dzbus: /dev/mem (run as root)");
		return -1;
	}
	R = mmap(NULL, 4096, PROT_READ | PROT_WRITE, MAP_SHARED, fd, REGS_BASE);
	close(fd);
	if (R == MAP_FAILED) {
		perror("dzbus: mmap");
		return -1;
	}
	if (R[0x3C / 4] != 0x48415544u) {	/* "HAUD": the pl_io registers are here */
		fprintf(stderr, "dzbus: no hdmi_audio_regs at 0x%08X (ID 0x%08X)\n", REGS_BASE, R[0x3C / 4]);
		return -1;
	}
	func0 = R[R_FUNC];
	return 0;
}

static void set_func(int line, unsigned code)
{
	uint32_t f = R[R_FUNC];

	f &= ~(15u << (4 * line));
	R[R_FUNC] = f | (code & 15u) << (4 * line);
}

static void set_out(int line, int v)
{
	uint32_t o = R[R_OUT];

	R[R_OUT] = v ? o | 1u << line : o & ~(1u << line);
}

/* open drain: 1 = drive low, 0 = release (input; the pull-ups take it high) */
static void od(int line, int low)
{
	set_func(line, low ? 1 : 0);
}

static void realtime(void)
{
	struct sched_param sp = { .sched_priority = 60 };	/* below debazd vsync (80) */
	cpu_set_t cs;

	CPU_ZERO(&cs);
	CPU_SET(1, &cs);
	sched_setaffinity(0, sizeof(cs), &cs);
	if (sched_setscheduler(0, SCHED_FIFO, &sp) < 0)
		perror("dzbus: SCHED_FIFO");
	mlockall(MCL_CURRENT | MCL_FUTURE);
}

static const char *const fname[16] = {
	"in", "out", "scl", "sda", "sclk", "cosi", "ciso", "cs0",
	"txd", "rxd", "bclk", "lrclk", "dout", "din", "cs1", "-"
};

static void levels(void)
{
	uint32_t in = R[R_IN], f = R[R_FUNC], o = R[R_OUT];

	for (int n = 0; n < 6; n++)
		printf("line %d: %d  %-5s%s\n", n, (in >> n) & 1, fname[(f >> (4 * n)) & 15],
		       ((f >> (4 * n)) & 15) == 1 ? ((o >> n) & 1 ? " (drives 1)" : " (drives 0)") : "");
}

/* ---- sampler ---------------------------------------------------------------- */

static long sample(int ms)
{
	uint64_t t0 = now_ns(), end = t0 + (uint64_t)ms * 1000000ull, t;
	uint8_t last = R[R_IN] & 0x3F, v;
	long reads = 0;

	ev[0] = (ev_t){ 0, last };
	nev = 1;
	do {
		for (int k = 0; k < 64; k++) {
			v = R[R_IN] & 0x3F;
			if (v != last) {
				if (nev < MAXEV)
					ev[nev++] = (ev_t){ now_ns() - t0, v };
				last = v;
			}
		}
		reads += 64;
		t = now_ns();
	} while (t < end && !stop_now);
	return (long)((double)reads * 1e9 / (double)(t - t0));
}

static void decode_i2c(int scl, int sda)
{
	int pscl = (ev[0].v >> scl) & 1, psda = (ev[0].v >> sda) & 1, nb = -1, byte = 0, frames = 0;
	char line[1024] = "";
	uint64_t t_s = 0, t_r[2] = { 0, 0 };
	double khz = 0;

	printf("I2C (SCL line %d, SDA line %d):\n", scl, sda);
	for (int i = 1; i < nev; i++) {
		int c = (ev[i].v >> scl) & 1, d = (ev[i].v >> sda) & 1;

		if (c && pscl && psda && !d) {			/* START (or repeated) */
			if (line[0] && frames < 40)
				printf("  %s\n", line);
			snprintf(line, sizeof(line), "%8.3f ms S", ev[i].t / 1e6);
			nb = 0;
			byte = 0;
			t_s = ev[i].t;
		} else if (c && pscl && !psda && d) {		/* STOP */
			if (frames++ < 40)
				printf("  %s P  (%.0f us)\n", line, (ev[i].t - t_s) / 1e3);
			line[0] = 0;
			nb = -1;
		} else if (c && !pscl && nb >= 0) {		/* SCL rising: a bit */
			t_r[0] = t_r[1];
			t_r[1] = ev[i].t;
			if (t_r[0] && t_r[1] - t_r[0] < 100000 && !khz)
				khz = 1e6 / (double)(t_r[1] - t_r[0]);
			if (nb < 8) {
				byte = byte << 1 | d;
				nb++;
			} else {
				snprintf(line + strlen(line), sizeof(line) - strlen(line), " %02X%s", byte, d ? "N" : "A");
				nb = 0;
				byte = 0;
			}
		}
		pscl = c;
		psda = d;
	}
	if (line[0])
		printf("  %s (no STOP)\n", line);
	printf("  %d transactions; SCL ~%.0f kHz (one bit period)\n", frames, khz);
}

static void decode_spi(int sclk, int cosi, int cs, int ciso)
{
	int ps = (ev[0].v >> sclk) & 1, pcs = (ev[0].v >> cs) & 1, nb = 0, bo = 0, bi = 0, frames = 0, nbytes = 0;
	char line[2048] = "";
	uint64_t r0 = 0;
	double khz = 0;

	printf("SPI mode 0 (SCLK %d, COSI %d, CS %d%s):\n", sclk, cosi, cs, ciso >= 0 ? ", CISO in brackets" : "");
	for (int i = 1; i < nev; i++) {
		int s = (ev[i].v >> sclk) & 1, c = (ev[i].v >> cs) & 1;

		if (pcs && !c) {				/* CS low: a frame */
			snprintf(line, sizeof(line), "%8.3f ms:", ev[i].t / 1e6);
			nb = bo = bi = nbytes = 0;
			r0 = 0;
		} else if (!pcs && c) {
			if (frames++ < 40)
				printf("  %s  (%d bytes%s)\n", line, nbytes, nb ? ", + bits" : "");
		} else if (!c && s && !ps) {			/* rising edge: sample */
			if (!r0)
				r0 = ev[i].t;
			else if (!khz && nbytes == 0 && nb == 1)
				khz = 1e6 / (double)(ev[i].t - r0);
			bo = bo << 1 | ((ev[i].v >> cosi) & 1);
			if (ciso >= 0)
				bi = bi << 1 | ((ev[i].v >> ciso) & 1);
			if (++nb == 8) {
				if (ciso >= 0)
					snprintf(line + strlen(line), sizeof(line) - strlen(line), " %02X[%02X]", bo, bi);
				else
					snprintf(line + strlen(line), sizeof(line) - strlen(line), " %02X", bo);
				nb = bo = bi = 0;
				nbytes++;
			}
		}
		ps = s;
		pcs = c;
	}
	printf("  %d frames; SCLK ~%.0f kHz\n", frames, khz);
}

static int cmd_sniff(int argc, char **argv)
{
	int ms = argc > 2 ? atoi(argv[2]) : 1000, i2c[2] = { -1, -1 }, spi[4] = { -1, -1, -1, -1 }, raw = 0;
	int edges[6] = { 0 };
	uint64_t lastt[6], minw[6];

	for (int k = 3; k < argc; k++) {
		if (!strcmp(argv[k], "-i") && k + 2 < argc) {
			i2c[0] = atoi(argv[++k]);
			i2c[1] = atoi(argv[++k]);
		} else if (!strcmp(argv[k], "-s") && k + 3 < argc) {
			spi[0] = atoi(argv[++k]);
			spi[1] = atoi(argv[++k]);
			spi[2] = atoi(argv[++k]);
			if (k + 1 < argc && argv[k + 1][0] != '-')
				spi[3] = atoi(argv[++k]);
		} else if (!strcmp(argv[k], "-r"))
			raw = 1;
	}
	realtime();
	long rate = sample(ms);

	printf("%d edges in %d ms, %.1f M samples/s (%.0f ns each); start levels 0x%02X\n",
	       nev - 1, ms, rate / 1e6, 1e9 / (double)rate, ev[0].v);
	for (int n = 0; n < 6; n++) {
		lastt[n] = 0;
		minw[n] = UINT64_MAX;
	}
	for (int i = 1; i < nev; i++) {
		uint8_t ch = ev[i].v ^ ev[i - 1].v;

		for (int n = 0; n < 6; n++)
			if ((ch >> n) & 1) {
				if (edges[n] && ev[i].t - lastt[n] < minw[n])
					minw[n] = ev[i].t - lastt[n];
				edges[n]++;
				lastt[n] = ev[i].t;
			}
		if (raw)
			printf("  %10.3f us  %02X\n", ev[i].t / 1e3, ev[i].v);
	}
	for (int n = 0; n < 6; n++)
		if (edges[n])
			printf("line %d: %d edges, shortest pulse %.2f us\n", n, edges[n],
			       minw[n] == UINT64_MAX ? 0 : minw[n] / 1e3);
	if (i2c[0] >= 0)
		decode_i2c(i2c[0], i2c[1]);
	if (spi[0] >= 0)
		decode_spi(spi[0], spi[1], spi[2], spi[3]);
	if (nev == MAXEV)
		printf("(buffer full: the first %d edges only)\n", MAXEV);
	return 0;
}

/* ---- I2C subordinate ---------------------------------------------------------- */

enum { I_IDLE, I_ADDR, I_ACK_ADDR, I_WR, I_ACK_WR, I_RD, I_RD_ACK, I_SKIP };

static int cmd_i2csub(int argc, char **argv)
{
	if (argc < 6)
		return fprintf(stderr, "dzbus i2csub <scl> <sda> <addr> <ms> [-x]\n"), 2;
	int scl = atoi(argv[2]), sda = atoi(argv[3]), addr = (int)strtol(argv[4], NULL, 0), ms = atoi(argv[5]);
	int stretch = argc > 6 && !strcmp(argv[6], "-x");
	uint8_t mem[256], ptr = 0;
	int st = I_IDLE, nb = 0, byte = 0, rw = 0, first = 0, macks = 0, low = 0;
	int n_start = 0, n_mine = 0, n_wr = 0, n_rd = 0, n_other = 0;
	char log[64][96];
	int nlog = 0;
	uint64_t end;

	for (int k = 0; k < 256; k++)
		mem[k] = (uint8_t)(k ^ 0x5A);
	set_out(scl, 0);
	set_out(sda, 0);
	od(scl, 0);
	od(sda, 0);
	realtime();
	uint32_t v = R[R_IN];
	int pc = (v >> scl) & 1, pd = (v >> sda) & 1;

	end = now_ns() + (uint64_t)ms * 1000000ull;
#define SDA(l) do { low = (l); od(sda, low); } while (0)
#define LOG(...) do { if (nlog < 64) snprintf(log[nlog++], sizeof(log[0]), __VA_ARGS__); } while (0)
	for (unsigned long k = 0; !stop_now; k++) {
		if (!(k & 1023) && now_ns() > end)
			break;
		v = R[R_IN];
		int c = (v >> scl) & 1, d = (v >> sda) & 1;

		if (c && pc && !low) {				/* SCL high: START / STOP */
			if (pd && !d) {
				n_start++;
				st = I_ADDR;
				nb = byte = 0;
			} else if (!pd && d) {
				st = I_IDLE;
			}
		}
		if (c && !pc) {					/* SCL rising: a bit */
			if (st == I_ADDR || st == I_WR) {
				byte = byte << 1 | d;
				nb++;
			} else if (st == I_RD_ACK) {
				macks = !d;
			}
		} else if (!c && pc) {				/* SCL falling: act */
			if (stretch)
				od(scl, 1);
			if ((st == I_ADDR || st == I_WR) && nb == 8) {
				if (st == I_ADDR) {
					if ((byte >> 1) == addr) {
						rw = byte & 1;
						n_mine++;
						first = 1;
						SDA(1);
						st = I_ACK_ADDR;
						LOG("addr 0x%02X %s (reg 0x%02X)", addr, rw ? "read" : "write", ptr);
					} else {
						n_other++;
						st = I_SKIP;
					}
				} else {
					if (first) {
						ptr = (uint8_t)byte;
						first = 0;
					} else {
						mem[ptr] = (uint8_t)byte;
						LOG("  write [0x%02X] = 0x%02X", ptr, byte);
						ptr++;
						n_wr++;
					}
					SDA(1);
					st = I_ACK_WR;
				}
			} else if (st == I_ACK_ADDR || st == I_ACK_WR) {
				SDA(0);
				nb = byte = 0;
				if (st == I_ACK_ADDR && rw) {
					byte = mem[ptr];
					LOG("  read  [0x%02X] = 0x%02X", ptr, byte);
					ptr++;
					n_rd++;
					SDA(!(byte & 0x80));
					nb = 1;
					st = I_RD;
				} else {
					st = I_WR;
				}
			} else if (st == I_RD) {
				if (nb < 8) {
					SDA(!((byte >> (7 - nb)) & 1));
					nb++;
				} else {
					SDA(0);			/* the controller's ACK / NACK bit */
					st = I_RD_ACK;
				}
			} else if (st == I_RD_ACK) {
				if (macks) {
					byte = mem[ptr];
					LOG("  read  [0x%02X] = 0x%02X", ptr, byte);
					ptr++;
					n_rd++;
					SDA(!(byte & 0x80));
					nb = 1;
					st = I_RD;
				} else {
					st = I_SKIP;		/* NACK: the controller ends it */
				}
			}
			if (stretch)
				od(scl, 0);
			/* our own SDA change (SCL is low now) is not a START / STOP */
			v = R[R_IN];
			c = (v >> scl) & 1;
			d = (v >> sda) & 1;
		}
		pc = c;
		pd = d;
	}
	od(sda, 0);
	od(scl, 0);
	printf("i2csub 0x%02X: %d starts, %d to us, %d to others, %d bytes written, %d read\n",
	       addr, n_start, n_mine, n_other, n_wr, n_rd);
	for (int k = 0; k < nlog; k++)
		printf("%s\n", log[k]);
	return 0;
}

/* ---- SPI subordinate ---------------------------------------------------------- */

static int cmd_spisub(int argc, char **argv)
{
	if (argc < 7)
		return fprintf(stderr, "dzbus spisub <sclk> <cosi> <ciso> <cs> <ms>\n"), 2;
	int sclk = atoi(argv[2]), cosi = atoi(argv[3]), ciso = atoi(argv[4]), cs = atoi(argv[5]), ms = atoi(argv[6]);
	uint8_t rx[256], tx;
	int n = 0, nb = 0, in = 0, frames = 0;
	char out[64][200];
	int nout = 0;
	uint64_t end;

	set_out(ciso, 1);
	set_func(ciso, 1);
	realtime();
	uint32_t v = R[R_IN];
	int ps = (v >> sclk) & 1, pcs = (v >> cs) & 1;

	end = now_ns() + (uint64_t)ms * 1000000ull;
	tx = 0xA5;
	for (unsigned long k = 0; !stop_now; k++) {
		if (!(k & 1023) && now_ns() > end)
			break;
		v = R[R_IN];
		int s = (v >> sclk) & 1, c = (v >> cs) & 1;

		if (pcs && !c) {				/* CS low */
			n = nb = in = 0;
			tx = 0xA5;
			set_out(ciso, tx >> 7);
		} else if (!pcs && c) {				/* CS high: the frame */
			if (nout < 64) {
				int l = snprintf(out[nout], sizeof(out[0]), "frame %d:", frames);

				for (int i = 0; i < n && l < (int)sizeof(out[0]) - 4; i++)
					l += snprintf(out[nout] + l, sizeof(out[0]) - (size_t)l, " %02X", rx[i]);
				nout++;
			}
			frames++;
		} else if (!c && s && !ps) {			/* rising: sample COSI */
			in = in << 1 | ((v >> cosi) & 1);
			if (++nb == 8) {
				if (n < 256)
					rx[n] = (uint8_t)in;
				tx = (uint8_t)in;		/* the next byte echoes this one */
				n++;
				nb = in = 0;
			}
		} else if (!c && !s && ps) {			/* falling: the next CISO bit */
			set_out(ciso, (tx >> (7 - nb)) & 1);
		}
		ps = s;
		pcs = c;
	}
	set_func(ciso, 0);
	printf("spisub: %d frames (CISO byte k = COSI byte k-1, the first 0xA5)\n", frames);
	for (int k = 0; k < nout; k++)
		printf("%s\n", out[k]);
	return 0;
}

int main(int argc, char **argv)
{
	int rc = 2;

	if (argc < 2) {
		fprintf(stderr, "dzbus levels | set <line> in|out0|out1 | sniff <ms> [-i scl sda] "
			"[-s sclk cosi cs [ciso]] [-r] | i2csub <scl> <sda> <addr> <ms> [-x] | "
			"spisub <sclk> <cosi> <ciso> <cs> <ms>\n");
		return 2;
	}
	if (map_regs() < 0)
		return 1;
	signal(SIGINT, on_signal);
	signal(SIGTERM, on_signal);
	if (!strcmp(argv[1], "levels")) {
		levels();
		return 0;
	}
	if (!strcmp(argv[1], "set") && argc >= 4) {
		int n = atoi(argv[2]);

		if (n < 0 || n > 5)
			return fprintf(stderr, "dzbus: line 0..5\n"), 2;
		if (!strcmp(argv[3], "in"))
			set_func(n, 0);
		else {
			set_out(n, !strcmp(argv[3], "out1"));
			set_func(n, 1);
		}
		levels();
		return 0;
	}
	ev = malloc(sizeof(ev_t) * MAXEV);
	if (!ev)
		return 1;
	if (!strcmp(argv[1], "sniff"))
		rc = cmd_sniff(argc, argv);
	else if (!strcmp(argv[1], "i2csub"))
		rc = cmd_i2csub(argc, argv);
	else if (!strcmp(argv[1], "spisub"))
		rc = cmd_spisub(argc, argv);
	else
		fprintf(stderr, "dzbus: unknown command %s\n", argv[1]);
	if (strcmp(argv[1], "sniff"))
		R[R_FUNC] = func0;		/* the line functions as they were */
	return rc;
}

/*
 * dzmosh - live datamosh filter for an MPEG-4 Part 2 elementary stream
 * (2026-10-30). It sits in the movie pipe between two ffmpegs:
 *
 *   ffmpeg -stream_loop -1 -i x.mp4 -map 0:v:0 -c:v copy -bsf:v dump_extra -f m4v pipe:1 \
 *   | dzmosh -r 30/1 -c /tmp/dzmosh.0 \
 *   | ffmpeg -use_wallclock_as_timestamps 1 -f m4v -i pipe:0 ... -f rawvideo pipe:1 | fbfeed ...
 *
 * mkmedia encodes with -c:v mpeg4 (no B frames). In the m4v stream every
 * frame (VOP) starts with 00 00 01 B6; the next 2 bits are its type (00 I,
 * 01 P, 10 B, 11 S). Headers (VOS B0, VO, VOL 20, user data B2, GOV B3) come
 * before each I frame (dump_extra) and go out with the VOP that follows them.
 *
 * dzmosh also sets the pace: one VOP each 1/fps (-r), so the ffmpegs run
 * without -re. Without that, repeated frames (bloom) would arrive in a burst.
 * When the output falls behind (slow decoder), the clock starts again from
 * now: no catch-up burst.
 *
 * Commands, one per line, on the control FIFO (-c, made by dzmosh, mode 0600):
 *   mosh N      drop the next N I frames (with their headers); -1 = all until
 *               "mosh 0". The P frames of the new picture then move the pixels
 *               of the old one. The first I frame always goes through.
 *   bloom N     send the next P frame N more times (its motion again and
 *               again: smear); -1 = repeat the last P frame until "bloom 0"
 *               (the input waits meanwhile)
 *   corrupt P   flip one bit in each VOP byte with probability P (0..1; the
 *               first 8 bytes of a VOP = its header are kept)
 *   pause 0|1   1 = send nothing (the decoder holds the last picture)
 *   stats       counters to stderr
 *
 * Build: in sw/ "make" (cross) or "make NATIVE=1".
 */

#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <getopt.h>
#include <math.h>
#include <poll.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <time.h>
#include <unistd.h>

#define MAX_FRAME	(16u << 20)	/* one VOP + headers; larger = broken input */
#define VOP_HDR		8		/* bytes of a VOP that corrupt keeps */

static volatile sig_atomic_t stop;
static const char *ctl_path;

/* the commands */
static int    mosh_n;		/* I frames to drop; -1 = all */
static int    bloom_n;		/* repeats of the next P; -1 = hold */
static double corrupt_p;
static int    paused;

static double period;		/* 1/fps, 0 = no pace */
static double next_t;
static int    verbose;
static uint64_t rng = 0x9E3779B97F4A7C15ull;
static unsigned long n_in, n_out, n_drop_i, n_bloom, n_flip;

static void on_signal(int sig)
{
	(void)sig;
	stop = 1;
	if (ctl_path)
		unlink(ctl_path);	/* async-signal-safe */
}

static double now_s(void)
{
	struct timespec ts;

	clock_gettime(CLOCK_MONOTONIC, &ts);
	return ts.tv_sec + ts.tv_nsec / 1e9;
}

static uint64_t rnd(void)	/* xorshift64 */
{
	rng ^= rng << 13;
	rng ^= rng >> 7;
	rng ^= rng << 17;
	return rng;
}

/* "30000/1001", "30/1", "29.97"; 0 if not a rate */
static double parse_rate(const char *s)
{
	char *e;
	double a = strtod(s, &e), b = 1.0;

	if (*e == '/')
		b = strtod(e + 1, NULL);
	return a > 0 && b > 0 ? a / b : 0.0;
}

/* ---- control FIFO ---- */

static int ctl_fd = -1;
static char ctl_buf[256];
static size_t ctl_len;

static void command(char *line)
{
	char word[16];
	double v = 0;

	if (sscanf(line, "%15s %lf", word, &v) < 1)
		return;
	if (!strcmp(word, "mosh"))
		mosh_n = (int)v;
	else if (!strcmp(word, "bloom"))
		bloom_n = (int)v;
	else if (!strcmp(word, "corrupt"))
		corrupt_p = v < 0 ? 0 : v > 1 ? 1 : v;
	else if (!strcmp(word, "pause"))
		paused = v != 0;
	else if (!strcmp(word, "stats"))
		fprintf(stderr, "dzmosh: in %lu out %lu dropped-I %lu bloom %lu flips %lu\n",
			n_in, n_out, n_drop_i, n_bloom, n_flip);
	else if (verbose)
		fprintf(stderr, "dzmosh: unknown command \"%s\"\n", word);
	if (verbose)
		fprintf(stderr, "dzmosh: mosh %d bloom %d corrupt %g pause %d\n",
			mosh_n, bloom_n, corrupt_p, paused);
}

/* read what is there; wait up to ms for a command (0 = no wait) */
static void ctl_poll(int ms)
{
	struct pollfd p = { .fd = ctl_fd, .events = POLLIN };

	if (ctl_fd < 0) {
		if (ms > 0)
			usleep((useconds_t)ms * 1000);
		return;
	}
	if (poll(&p, 1, ms) <= 0)
		return;
	for (;;) {
		ssize_t n = read(ctl_fd, ctl_buf + ctl_len, sizeof(ctl_buf) - 1 - ctl_len);
		char *nl;

		if (n <= 0)
			return;
		ctl_len += (size_t)n;
		ctl_buf[ctl_len] = 0;
		while ((nl = strchr(ctl_buf, '\n'))) {
			*nl = 0;
			command(ctl_buf);
			ctl_len -= (size_t)(nl + 1 - ctl_buf);
			memmove(ctl_buf, nl + 1, ctl_len + 1);
		}
		if (ctl_len == sizeof(ctl_buf) - 1)
			ctl_len = 0;	/* a line too long: drop it */
	}
}

static int ctl_open(const char *path)
{
	unlink(path);
	if (mkfifo(path, 0600) < 0) {
		perror(path);
		return -1;
	}
	ctl_fd = open(path, O_RDONLY | O_NONBLOCK);
	/* a writer of our own: the FIFO never reads EOF between commands */
	if (ctl_fd < 0 || open(path, O_WRONLY | O_NONBLOCK) < 0) {
		perror(path);
		return -1;
	}
	ctl_path = path;
	return 0;
}

/* ---- output ---- */

static int write_all(const uint8_t *p, size_t n)
{
	while (n) {
		ssize_t w = write(1, p, n);

		if (w < 0) {
			if (errno == EINTR && !stop)
				continue;
			return -1;
		}
		p += w;
		n -= (size_t)w;
	}
	return 0;
}

/* wait for the slot of the next VOP; commands are read while waiting */
static void pace(void)
{
	if (period <= 0) {
		ctl_poll(0);
		return;
	}
	double t = now_s();

	if (next_t == 0 || t > next_t + 0.25)
		next_t = t;	/* start, or far behind: no burst */
	while (!stop && t < next_t) {
		ctl_poll((int)((next_t - t) * 1000) + 1);
		t = now_s();
	}
	next_t += period;
}

static uint8_t *scratch;

/* headers (may be empty) + one VOP, after its time slot */
static int emit(const uint8_t *hdr, size_t hn, const uint8_t *vop, size_t vn)
{
	pace();
	if (hn && write_all(hdr, hn) < 0)
		return -1;
	if (corrupt_p > 0 && vn > VOP_HDR) {
		/* bytes to the next flip: geometric, so a small P costs little */
		memcpy(scratch, vop, vn);
		double q = corrupt_p >= 1 ? 0 : 1.0 / -log1p(-corrupt_p);
		for (size_t i = VOP_HDR;;) {
			double u = (rnd() >> 11) * (1.0 / 9007199254740992.0);
			i += corrupt_p >= 1 ? 1 : (size_t)(-log(u + 1e-300) * q);
			if (i >= vn)
				break;
			scratch[i] ^= (uint8_t)(1u << (rnd() & 7));
			n_flip++;
			i++;
		}
		vop = scratch;
	}
	n_out++;
	return write_all(vop, vn);
}

/* ---- stream ---- */

static uint8_t *hdr, *lastp;
static size_t hdr_len, lastp_len;
static int seen_i;

/* hold states: no input is read while paused or while bloom holds */
static int hold(void)
{
	while (!stop && (paused || bloom_n < 0)) {
		if (paused) {
			ctl_poll(period > 0 ? (int)(period * 1000) + 1 : 20);
			next_t = 0;	/* resume: the clock starts again */
		} else if (lastp_len) {
			if (emit(NULL, 0, lastp, lastp_len) < 0)
				return -1;
			n_bloom++;
		} else {
			bloom_n = 0;	/* nothing to repeat yet */
		}
	}
	return 0;
}

static int vop(const uint8_t *c, size_t n)
{
	int type = c[4] >> 6;

	n_in++;
	if (hold() < 0)
		return -1;
	if (type == 0) {
		if (seen_i && mosh_n != 0) {
			if (mosh_n > 0)
				mosh_n--;
			n_drop_i++;
			hdr_len = 0;	/* its VOL/GOV go with it */
			return 0;
		}
		seen_i = 1;
	}
	if (emit(hdr, hdr_len, c, n) < 0)
		return -1;
	hdr_len = 0;
	if (type == 1) {
		memcpy(lastp, c, n);
		lastp_len = n;
		for (; bloom_n > 0 && !stop; bloom_n--) {
			if (emit(NULL, 0, c, n) < 0)
				return -1;
			n_bloom++;
		}
	}
	return 0;
}

/* one start-code chunk: 00 00 01 xx ... up to the next start code */
static int chunk(const uint8_t *c, size_t n)
{
	if (n >= 5 && c[0] == 0 && c[1] == 0 && c[2] == 1 && c[3] == 0xB6)
		return vop(c, n);
	if (hdr_len + n > MAX_FRAME)
		hdr_len = 0;	/* junk without a VOP: drop it */
	memcpy(hdr + hdr_len, c, n);
	hdr_len += n;
	return 0;
}

static void usage(void)
{
	fprintf(stderr,
"usage: dzmosh [-r fps] [-c fifo] [-s seed] [-v]   (m4v on stdin -> m4v on stdout)\n"
"  -r fps    pace: one frame each 1/fps (\"30000/1001\", \"25\"); 0 = no pace\n"
"  -c fifo   control FIFO (made here): mosh N | bloom N | corrupt P | pause 0|1 | stats\n"
"  -s seed   random seed for corrupt\n"
"  -v        print the state after each command\n");
}

int main(int argc, char **argv)
{
	uint8_t *buf;
	size_t len = 0, start = 0, pos = 0;
	int o, have = 0;

	while ((o = getopt(argc, argv, "r:c:s:vh")) != -1) {
		switch (o) {
		case 'r': {
			double f = parse_rate(optarg);
			period = f > 0 && f <= 240 ? 1.0 / f : 0.0;
			if (f <= 0 && strcmp(optarg, "0"))
				fprintf(stderr, "dzmosh: rate \"%s\"? 30 fps\n", optarg), period = 1.0 / 30;
			break;
		}
		case 'c': if (ctl_open(optarg) < 0) return 1; break;
		case 's': rng = strtoull(optarg, NULL, 0) | 1; break;
		case 'v': verbose = 1; break;
		default:  usage(); return o == 'h' ? 0 : 2;
		}
	}
	struct sigaction sa = { .sa_handler = on_signal };
	sigaction(SIGTERM, &sa, NULL);
	sigaction(SIGINT, &sa, NULL);
	sigaction(SIGHUP, &sa, NULL);
	signal(SIGPIPE, SIG_IGN);	/* a closed reader = write error = exit */

	buf = malloc(MAX_FRAME + 65536);
	hdr = malloc(MAX_FRAME);
	lastp = malloc(MAX_FRAME);
	scratch = malloc(MAX_FRAME);
	if (!buf || !hdr || !lastp || !scratch)
		return 1;

	while (!stop) {
		ssize_t r = read(0, buf + len, MAX_FRAME + 65536 - len);

		if (r < 0 && errno == EINTR)
			continue;
		if (r <= 0)
			break;
		len += (size_t)r;
		for (; pos + 3 <= len; pos++) {
			if (buf[pos] || buf[pos + 1] || buf[pos + 2] != 1)
				continue;
			if (have && chunk(buf + start, pos - start) < 0)
				goto out;
			have = 1;
			start = pos;
			pos += 2;
		}
		if (!have) {		/* no start code yet: keep the last 2 bytes */
			if (len > 2) {
				memmove(buf, buf + len - 2, 2);
				len = 2;
			}
			pos = 0;
			continue;
		}
		if (len - start >= MAX_FRAME) {	/* no end in sight: broken input */
			fprintf(stderr, "dzmosh: chunk over %u bytes, dropped\n", MAX_FRAME);
			start = len;
		}
		memmove(buf, buf + start, len - start);
		pos -= start;
		len -= start;
		start = 0;
	}
	if (have && len > start && !stop)
		chunk(buf + start, len - start);
out:
	if (verbose)
		fprintf(stderr, "dzmosh: in %lu out %lu dropped-I %lu bloom %lu flips %lu\n",
			n_in, n_out, n_drop_i, n_bloom, n_flip);
	if (ctl_path)
		unlink(ctl_path);
	return 0;
}

/*
 * stats.c - debazd load and health (2026-11-02). The main loop reports the
 * time of each frame tick (LFOs, cues, ASCII, ...) and of each OSC packet;
 * a slow tick or packet blocks OSC replies, which in the web app looks like
 * a crash (ASCII into a slot with alpha took 229 ms per frame).
 *
 *   /stats   -> /stats f:debazd_cpu f:cpu_total (% of one core; 200 = both
 *               cores busy) f:tick_hz f:tick_max_ms f:osc_max_ms f:load1
 *               i:mem_avail_kb f:temp_c (XADC, -1 = none)
 *
 * tick_hz, tick_max_ms and osc_max_ms cover the last full second; the CPU
 * values cover the time since the previous /stats (the first: since start).
 */
#include "debazd.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

#define XADC	"/sys/bus/iio/devices/iio:device0/"

static double win_t0, tick_max, osc_max;
static int win_ticks;
static float last_hz, last_tick_max, last_osc_max;

double stats_now(void)
{
	struct timespec ts;

	clock_gettime(CLOCK_MONOTONIC, &ts);
	return ts.tv_sec * 1e3 + ts.tv_nsec / 1e6;
}

static void window(double t)
{
	if (win_t0 == 0)
		win_t0 = t;
	if (t - win_t0 < 1000)
		return;
	last_hz = (float)(win_ticks * 1000.0 / (t - win_t0));
	last_tick_max = (float)tick_max;
	last_osc_max = (float)osc_max;
	win_t0 = t;
	win_ticks = 0;
	tick_max = osc_max = 0;
}

void stats_tick(double ms)
{
	double t = stats_now();

	window(t);
	win_ticks++;
	if (ms > tick_max)
		tick_max = ms;
}

void stats_osc(double ms)
{
	window(stats_now());
	if (ms > osc_max)
		osc_max = ms;
}

static double read_num(const char *path)
{
	FILE *f = fopen(path, "r");
	double v = 0;

	if (!f)
		return 0;
	if (fscanf(f, "%lf", &v) != 1)
		v = 0;
	fclose(f);
	return v;
}

/* XADC die temperature in degrees C; -1 when there is none or it reads 0
 * (raw 0 = -273 C: seen right after boot) */
static float temp_c(void)
{
	double raw = read_num(XADC "in_temp0_raw");

	if (raw <= 0)
		return -1;
	return (float)((raw + read_num(XADC "in_temp0_offset")) * read_num(XADC "in_temp0_scale") / 1000.0);
}

static long mem_avail_kb(void)
{
	FILE *f = fopen("/proc/meminfo", "r");
	char line[128];
	long kb = -1;

	if (!f)
		return -1;
	while (fgets(line, sizeof(line), f))
		if (sscanf(line, "MemAvailable: %ld kB", &kb) == 1)
			break;
	fclose(f);
	return kb;
}

static void cpu(float *self, float *total)
{
	static unsigned long self0, busy0, all0;
	static double t0;
	unsigned long ut = 0, st = 0, v[8] = { 0 };
	double t = stats_now(), hz = (double)sysconf(_SC_CLK_TCK);
	char line[512], *rp;
	FILE *f;

	if ((f = fopen("/proc/self/stat", "r"))) {
		rp = fgets(line, sizeof(line), f) ? strrchr(line, ')') : NULL;
		if (rp)
			sscanf(rp + 2, "%*c %*d %*d %*d %*d %*d %*u %*u %*u %*u %*u %lu %lu", &ut, &st);
		fclose(f);
	}
	if ((f = fopen("/proc/stat", "r"))) {
		if (fscanf(f, "cpu %lu %lu %lu %lu %lu %lu %lu %lu",
			   &v[0], &v[1], &v[2], &v[3], &v[4], &v[5], &v[6], &v[7]) != 8)
			memset(v, 0, sizeof(v));
		fclose(f);
	}
	unsigned long all = 0, busy;

	for (int k = 0; k < 8; k++)
		all += v[k];
	busy = all - v[3] - v[4];	/* idle, iowait */
	/* first call: since start (the process start is not kept: ~0) */
	double dt = (t - t0) / 1000.0;
	long ncpu = sysconf(_SC_NPROCESSORS_ONLN);

	*self = t0 > 0 && dt > 0 ? (float)((ut + st - self0) / hz / dt * 100.0) : -1;
	*total = all > all0 && t0 > 0 ? (float)((double)(busy - busy0) / (double)(all - all0) * 100.0 *
						 (ncpu > 0 ? ncpu : 1)) : -1;
	self0 = ut + st;
	busy0 = busy;
	all0 = all;
	t0 = t;
}

int stats_dispatch(const dz_msg *m)
{
	float self, total, load = 0;
	FILE *f;

	if (strcmp(m->path, "/stats"))
		return 0;
	cpu(&self, &total);
	if ((f = fopen("/proc/loadavg", "r"))) {
		if (fscanf(f, "%f", &load) != 1)
			load = 0;
		fclose(f);
	}
	window(stats_now());
	dzd_reply("/stats", "ffffffif", self, total, last_hz, last_tick_max, last_osc_max,
		  load, (int)mem_avail_kb(), temp_c());
	return 1;
}

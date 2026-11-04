/*
 * pix.c - the pixel thread (2026-11-03). It owns the work on pixels: the
 * OSC addresses /draw/ /img/ /movie/ /surface/ /sprite/ /ascii/ /media/info, the ASCII
 * frames and the movie ticks (ffmpeg commands, end of a movie). The main
 * thread keeps OSC, the register fields and the frame tick (LFOs, ramps,
 * cues, DDS), so a slow pixel job no longer delays them: before, an ASCII
 * frame of 18 ms in the frame tick queued the brush strokes (OSC round trip
 * 400-700 ms), and the slowest tick set the p99 of every reply.
 *
 * Order: the messages of the pixel domain run in the order they arrived
 * (network and internal: cues, LFO templates, recalls); an internal message
 * replaces a waiting internal one of the same address. A reply comes from
 * the pixel thread to the same sender, so a /ping sent after a /draw can
 * come back first.
 *
 * Main thread: pix_post() a message, pix_frame() once per frame. To read
 * the state of the pixel domain (state dump), pix_sync() (the messages
 * posted so far have run) and pix_lock() / pix_unlock() (no job runs).
 * Without the thread (it did not start) everything runs inline as before.
 */
#define _GNU_SOURCE
#include "debazd.h"
#include "dz_draw.h"
#include "dz_hw.h"

#include <errno.h>
#include <pthread.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#define QMAX		1024		/* messages waiting */
#define FRAME_WAIT_MS	8.0		/* messages first, but a frame waits at most this */
#define POLL_MS		20.0		/* movie end check (was the monitor interval) */

typedef struct {
	struct sockaddr_in from;
	int                internal;
	size_t             len;
	uint8_t            data[];
} job_t;

static pthread_mutex_t qmu = PTHREAD_MUTEX_INITIALIZER;	/* queue + counters */
static pthread_cond_t  qcv = PTHREAD_COND_INITIALIZER;		/* work for the thread */
static pthread_cond_t  donecv = PTHREAD_COND_INITIALIZER;	/* a message is done */
static pthread_mutex_t pmu = PTHREAD_MUTEX_INITIALIZER;	/* the pixel lock */
static job_t *q[QMAX];
static int qh, qn, frame_due, run;
static unsigned long posted, done;
static double frame_t0;
static pthread_t thr;
static __thread int in_pix;

int pix_owns(const char *path)
{
	static const char *const pre[] = { "/draw/", "/img/", "/movie/", "/surface/",
					   "/sprite/", "/ascii/", "/media/info" };	/* ffprobe: slow */

	for (size_t k = 0; k < sizeof(pre) / sizeof(pre[0]); k++)
		if (!strncmp(path, pre[k], strlen(pre[k])))
			return 1;
	return 0;
}

int pix_here(void)
{
	return in_pix || !run;
}

int pix_queued(void)
{
	int n;

	pthread_mutex_lock(&qmu);
	n = qn;
	pthread_mutex_unlock(&qmu);
	return n;
}

int pix_post(const dz_msg *m, const struct sockaddr_in *from, int internal)
{
	uint8_t buf[DZ_OSC_MAX_PKT];
	size_t n;
	job_t *j;

	if (!run)
		return -1;
	n = dz_osc_build_args(buf, sizeof(buf), m->path, m->a, m->n);
	if (!n || !(j = malloc(sizeof(*j) + n)))
		return -1;
	j->from = *from;
	j->internal = internal;
	j->len = n;
	memcpy(j->data, buf, n);
	pthread_mutex_lock(&qmu);
	/* an internal message (LFO template, cue ramp) replaces a waiting one
	 * of the same address: the newest value wins, as for a field. Without
	 * it, an LFO that sends a slow op every frame (rotozoom ~25 ms) filled
	 * the queue and the picture fell behind by up to QMAX messages. The
	 * network messages (brush strokes) all run. */
	if (internal)
		for (int k = 0; k < qn; k++) {
			job_t **o = &q[(qh + k) % QMAX];

			if ((*o)->internal && !strcmp((const char *)(*o)->data, (const char *)j->data)) {
				free(*o);
				*o = j;
				pthread_mutex_unlock(&qmu);
				return 0;
			}
		}
	if (qn == QMAX) {
		pthread_mutex_unlock(&qmu);
		free(j);
		return -2;
	}
	q[(qh + qn) % QMAX] = j;
	qn++;
	posted++;
	pthread_cond_signal(&qcv);
	pthread_mutex_unlock(&qmu);
	return 0;
}

static void frame_work(void)
{
	ascii_tick();
	dz_draw_movie_tick();
}

static void poll_work(void)
{
	for (int s = 0; s < DZ_SLOTS; s++)
		dz_draw_movie_running(s);
}

void pix_frame(void)
{
	if (!run) {
		frame_work();
		return;
	}
	pthread_mutex_lock(&qmu);
	if (!frame_due)
		frame_t0 = stats_now();
	frame_due = 1;		/* a frame missed while busy is not made up */
	pthread_cond_signal(&qcv);
	pthread_mutex_unlock(&qmu);
}

void pix_monitor(void)
{
	if (!run)
		poll_work();
}

void pix_sync(void)
{
	unsigned long want;

	if (pix_here())
		return;
	pthread_mutex_lock(&qmu);
	want = posted;
	while (run && done < want)
		pthread_cond_wait(&donecv, &qmu);
	pthread_mutex_unlock(&qmu);
}

void pix_lock(void)
{
	if (!in_pix)
		pthread_mutex_lock(&pmu);
}

void pix_unlock(void)
{
	if (!in_pix)
		pthread_mutex_unlock(&pmu);
}

static void *pix_main(void *arg)
{
	double next_poll = 0;

	(void)arg;
	in_pix = 1;
	pthread_mutex_lock(&qmu);
	while (run) {
		double t = stats_now(), t0;

		if (frame_due && (!qn || t - frame_t0 >= FRAME_WAIT_MS)) {
			frame_due = 0;
			pthread_mutex_unlock(&qmu);
			pthread_mutex_lock(&pmu);
			t0 = stats_now();
			frame_work();
			stats_pix(stats_now() - t0);
			pthread_mutex_unlock(&pmu);
			pthread_mutex_lock(&qmu);
		} else if (qn) {
			job_t *j = q[qh];

			qh = (qh + 1) % QMAX;
			qn--;
			pthread_mutex_unlock(&qmu);
			pthread_mutex_lock(&pmu);
			t0 = stats_now();
			dzd_pix_run(j->data, j->len, &j->from, j->internal);
			stats_pix(stats_now() - t0);
			pthread_mutex_unlock(&pmu);
			free(j);
			pthread_mutex_lock(&qmu);
			done++;
			pthread_cond_broadcast(&donecv);
		} else if (t >= next_poll) {
			pthread_mutex_unlock(&qmu);
			pthread_mutex_lock(&pmu);
			poll_work();
			pthread_mutex_unlock(&pmu);
			next_poll = stats_now() + POLL_MS;
			pthread_mutex_lock(&qmu);
		} else {
			struct timespec ts;
			double w = next_poll - t;

			clock_gettime(CLOCK_MONOTONIC, &ts);
			ts.tv_nsec += (long)(w * 1e6);
			ts.tv_sec += ts.tv_nsec / 1000000000L;
			ts.tv_nsec %= 1000000000L;
			pthread_cond_timedwait(&qcv, &qmu, &ts);
		}
	}
	pthread_mutex_unlock(&qmu);
	return NULL;
}

int pix_init(void)
{
	pthread_condattr_t ca;

	/* the timed wait counts on the monotonic clock (stats_now) */
	pthread_condattr_init(&ca);
	pthread_condattr_setclock(&ca, CLOCK_MONOTONIC);
	pthread_cond_init(&qcv, &ca);
	pthread_condattr_destroy(&ca);
	run = 1;
	if (pthread_create(&thr, NULL, pix_main, NULL) != 0) {
		run = 0;
		return -1;
	}
	pthread_setname_np(thr, "debazd-pix");
	return 0;
}

/* the messages still queued are dropped */
void pix_close(void)
{
	if (!run)
		return;
	pthread_mutex_lock(&qmu);
	run = 0;
	pthread_cond_broadcast(&qcv);
	pthread_cond_broadcast(&donecv);
	pthread_mutex_unlock(&qmu);
	pthread_join(thr, NULL);
	while (qn) {
		free(q[qh]);
		qh = (qh + 1) % QMAX;
		qn--;
	}
}

/*
 * mix.c - the dzaudio mixer in debazd's state and cues (2026-11-22).
 *
 * dzaudio (sw/dzaudio, OSC UDP 9002) is its own process: its routing matrix
 * and gains were not in /state, so cues could not record them, and a /mix
 * message in a cue (/cue/add) found no handler. Now:
 *   /mix/...        any /mix message is passed on to dzaudio (fire and
 *                   forget: query dzaudio on port 9002 for its replies)
 *   state targets   while dzaudio runs (its stream FIFOs have a reader):
 *                   /mix/routes s:"in>pair:gain ..." (the matrix without
 *                   the movie streams, which debazd routes itself),
 *                   /mix/gain f, /mix/pair/<p>/gain f
 * A state dump asks dzaudio once (/mix/state, a reply in < 50 ms); without
 * dzaudio no wait and no /mix targets.
 */
#include "debazd.h"
#include "dz_ain.h"

#include <arpa/inet.h>
#include <netinet/in.h>
#include <poll.h>
#include <stdio.h>
#include <string.h>
#include <sys/socket.h>
#include <unistd.h>

static void to_dzaudio(int fd, const uint8_t *b, size_t len)
{
	struct sockaddr_in a = { .sin_family = AF_INET, .sin_port = htons(DZA_PORT) };

	a.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
	sendto(fd, b, len, 0, (struct sockaddr *)&a, sizeof(a));
}

int mix_dispatch(const dz_msg *m)
{
	static int fd = -1;
	uint8_t b[DZ_OSC_MAX_PKT];
	size_t len;

	if (strncmp(m->path, "/mix/", 5))
		return 0;
	if (fd < 0)
		fd = socket(AF_INET, SOCK_DGRAM | SOCK_CLOEXEC, 0);
	len = dz_osc_build_args(b, sizeof(b), m->path, m->a, m->n);
	if (fd >= 0 && len)
		to_dzaudio(fd, b, len);
	return 1;
}

void mix_state(state_cb cb, void *ctx)
{
	uint8_t b[DZ_OSC_MAX_PKT];
	struct pollfd pf;
	dz_msg m;
	size_t len;
	ssize_t n;
	int fd;

	if (!dz_ain_ready(0))			/* dzaudio is not running */
		return;
	fd = socket(AF_INET, SOCK_DGRAM | SOCK_CLOEXEC, 0);
	if (fd < 0)
		return;
	len = dz_osc_build(b, sizeof(b), "/mix/state", "");
	to_dzaudio(fd, b, len);
	pf = (struct pollfd){ .fd = fd, .events = POLLIN };
	if (poll(&pf, 1, 50) == 1 && (n = recv(fd, b, sizeof(b), 0)) > 0 &&
	    dz_osc_parse(b, (size_t)n, &m) == 0 && !strcmp(m.path, "/mix/state") &&
	    m.n >= 2 && m.a[0].type == 's') {
		char p[32];

		st_emit(cb, ctx, NULL, "/mix/routes", "s", m.a[0].s);
		st_emit(cb, ctx, NULL, "/mix/gain", "f", (double)m.a[1].f);
		for (int q = 0; q + 2 < m.n; q++) {
			snprintf(p, sizeof(p), "/mix/pair/%d/gain", q);
			st_emit(cb, ctx, NULL, p, "f", (double)m.a[q + 2].f);
		}
	}
	close(fd);
}

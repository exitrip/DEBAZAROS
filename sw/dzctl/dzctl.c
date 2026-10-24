/*
 * dzctl - send one OSC message to debazd and print the replies.
 *
 *   dzctl [-h host] [-p port] [-t ms] /address [value...]
 *   dzctl [-h host] [-p port] -w            print events (subscribes)
 *   dzctl [-h bcast] [-p port] -s           find all debazd on the LAN
 *                                           (default 255.255.255.255)
 *
 * Values: 12 -> int, 0.5 -> float, anything else -> string.
 * Force a type with a prefix: i:12  f:1  s:12
 *
 * Examples
 *   dzctl /ping
 *   dzctl /list /hdmi/1
 *   dzctl /hdmi/0/gain/rgb 255 128 0
 *   dzctl /dds/0/hz 60
 *   dzctl /disp/0/show 4          show the capture on display 0
 *   dzctl /disp/0/home            back to slot 0 (ffmpeg -f fbdev /dev/fb0)
 *   dzctl /draw/3/bars
 *   dzctl -h 10.42.0.128 /capture/status
 */
#define _GNU_SOURCE
#include "dz_osc.h"

#include <arpa/inet.h>
#include <errno.h>
#include <netdb.h>
#include <netinet/in.h>
#include <poll.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <unistd.h>

static int parse_value(const char *s, dz_arg *a)
{
	char *end;

	memset(a, 0, sizeof(*a));
	if (!strncmp(s, "s:", 2)) {
		a->type = 's';
		a->s = s + 2;
		return 0;
	}
	if (!strncmp(s, "i:", 2)) {
		a->type = 'i';
		a->i = (int32_t)strtoll(s + 2, NULL, 0);
		return 0;
	}
	if (!strncmp(s, "f:", 2)) {
		a->type = 'f';
		a->f = strtof(s + 2, NULL);
		return 0;
	}
	errno = 0;
	long long v = strtoll(s, &end, 0);
	if (*s && !*end && !errno) {
		a->type = 'i';
		a->i = (int32_t)v;
		return 0;
	}
	float f = strtof(s, &end);
	if (*s && !*end) {
		a->type = 'f';
		a->f = f;
		return 0;
	}
	a->type = 's';
	a->s = s;
	return 0;
}

static void print_msg(dz_msg *m, void *ctx)
{
	char line[1024];

	(void)ctx;
	dz_osc_format(m, line, sizeof(line));
	printf("%s\n", line);
	fflush(stdout);
}

static const char *scan_host(const char *h)
{
	return strcmp(h, "127.0.0.1") ? h : "255.255.255.255";
}

static void print_from(dz_msg *m, void *ctx)
{
	char line[1024];

	dz_osc_format(m, line, sizeof(line));
	printf("%-16s %s\n", (const char *)ctx, line);
	fflush(stdout);
}

/* Broadcast /info and print every reply with its sender address. */
static int do_scan(const char *bcast, const char *port, int timeout)
{
	struct sockaddr_in to = { 0 }, from;
	uint8_t buf[DZ_OSC_MAX_PKT];
	int s = socket(AF_INET, SOCK_DGRAM, 0), one = 1, found = 0;
	size_t len = dz_osc_build(buf, sizeof(buf), "/info", "");

	if (s < 0 || setsockopt(s, SOL_SOCKET, SO_BROADCAST, &one, sizeof(one)) < 0) {
		perror("dzctl: socket");
		return 1;
	}
	to.sin_family = AF_INET;
	to.sin_port = htons((uint16_t)atoi(port));
	if (inet_pton(AF_INET, bcast, &to.sin_addr) != 1) {
		fprintf(stderr, "dzctl: -s needs an IPv4 broadcast address\n");
		return 2;
	}
	if (sendto(s, buf, len, 0, (struct sockaddr *)&to, sizeof(to)) < 0) {
		perror("dzctl: sendto");
		return 1;
	}
	for (;;) {
		struct pollfd p = { .fd = s, .events = POLLIN };
		socklen_t fl = sizeof(from);
		char ip[INET_ADDRSTRLEN];
		ssize_t n;

		if (poll(&p, 1, timeout) <= 0)
			break;
		n = recvfrom(s, buf, sizeof(buf), 0, (struct sockaddr *)&from, &fl);
		if (n <= 0)
			break;
		inet_ntop(AF_INET, &from.sin_addr, ip, sizeof(ip));
		dz_osc_walk(buf, (size_t)n, print_from, ip);
		found++;
	}
	fprintf(stderr, "dzctl: %d unit(s) answered\n", found);
	close(s);
	return 0;
}

int main(int argc, char **argv)
{
	const char *host = "127.0.0.1", *port = "9000";
	int timeout = 400, watch = 0, scan = 0, opt, s;
	struct addrinfo hints = { 0 }, *ai;
	uint8_t buf[DZ_OSC_MAX_PKT];
	dz_arg args[DZ_OSC_MAX_ARGS];
	int nargs = 0;
	size_t len;

	/* "+": stop at the /address, so a value like -1 is not an option */
	while ((opt = getopt(argc, argv, "+h:p:t:ws")) != -1) {
		switch (opt) {
		case 'h': host = optarg; break;
		case 'p': port = optarg; break;
		case 't': timeout = atoi(optarg); break;
		case 'w': watch = 1; break;
		case 's': scan = 1; break;
		default:
			fprintf(stderr,
				"usage: %s [-h host] [-p port] [-t ms] /address [value...]\n"
				"       %s [-h host] [-p port] -w\n", argv[0], argv[0]);
			return 2;
		}
	}
	if (scan)
		return do_scan(scan_host(host), port, timeout < 1000 ? 1000 : timeout);
	if (!watch && (optind >= argc || argv[optind][0] != '/')) {
		fprintf(stderr, "%s: need an /address (try /list)\n", argv[0]);
		return 2;
	}

	hints.ai_family = AF_UNSPEC;
	hints.ai_socktype = SOCK_DGRAM;
	if (getaddrinfo(host, port, &hints, &ai) != 0) {
		fprintf(stderr, "%s: cannot resolve %s\n", argv[0], host);
		return 1;
	}
	s = socket(ai->ai_family, SOCK_DGRAM, 0);
	if (s < 0 || connect(s, ai->ai_addr, ai->ai_addrlen) < 0) {
		perror("dzctl: socket");
		return 1;
	}

	if (watch) {
		len = dz_osc_build(buf, sizeof(buf), "/subscribe", "");
	} else {
		for (int i = optind + 1; i < argc && nargs < DZ_OSC_MAX_ARGS; i++)
			parse_value(argv[i], &args[nargs++]);
		len = dz_osc_build_args(buf, sizeof(buf), argv[optind], args, nargs);
	}
	if (!len || send(s, buf, len, 0) < 0) {
		fprintf(stderr, "%s: send failed\n", argv[0]);
		return 1;
	}

	/* print replies until quiet for `timeout` ms (watch: forever) */
	for (;;) {
		struct pollfd p = { .fd = s, .events = POLLIN };
		ssize_t n;

		if (poll(&p, 1, watch ? -1 : timeout) <= 0)
			break;
		n = recv(s, buf, sizeof(buf), 0);
		if (n <= 0) {
			if (n < 0 && errno == ECONNREFUSED)
				fprintf(stderr, "%s: no debazd on %s:%s\n", argv[0], host, port);
			break;
		}
		dz_osc_walk(buf, (size_t)n, print_msg, NULL);
	}
	freeaddrinfo(ai);
	close(s);
	return 0;
}

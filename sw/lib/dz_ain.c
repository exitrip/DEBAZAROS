/* dz_ain.c - audio into dzaudio's stream inputs (dz_ain.h) */
#define _GNU_SOURCE
#include "dz_ain.h"
#include "dz_osc.h"

#include <arpa/inet.h>
#include <errno.h>
#include <fcntl.h>
#include <netinet/in.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <unistd.h>

int dz_ain_ready(int n)
{
	char p[32];
	struct stat st;
	int fd;

	if (n < 0 || n >= DZA_STREAMS)
		return 0;
	snprintf(p, sizeof(p), DZA_FIFO, n);
	if (stat(p, &st) < 0 || !S_ISFIFO(st.st_mode))
		return 0;
	fd = open(p, O_WRONLY | O_NONBLOCK | O_CLOEXEC);	/* ENXIO: nobody reads */
	if (fd < 0)
		return 0;
	close(fd);
	return 1;
}

void dz_ain_route(int n, unsigned devmask)
{
	uint8_t b[64];
	size_t len = dz_osc_build(b, sizeof(b), "/mix/stream", "ii", n, (int)devmask);
	struct sockaddr_in a = { .sin_family = AF_INET, .sin_port = htons(DZA_PORT) };
	int s;

	if (!len || (s = socket(AF_INET, SOCK_DGRAM | SOCK_CLOEXEC, 0)) < 0)
		return;
	a.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
	sendto(s, b, len, 0, (struct sockaddr *)&a, sizeof(a));
	close(s);
}

int dz_pcm_owner(int dev, char *who, size_t n)
{
	char p[64], line[128], comm[32] = "?";
	int pid = 0, open_ = 0;
	FILE *f;

	who[0] = 0;
	snprintf(p, sizeof(p), "/proc/asound/DEBAZ/pcm%dp/sub0/status", dev);
	if (!(f = fopen(p, "r")))
		return 0;
	while (fgets(line, sizeof(line), f)) {
		if (!strncmp(line, "state:", 6))
			open_ = 1;
		sscanf(line, "owner_pid : %d", &pid);
	}
	fclose(f);
	if (!open_)
		return 0;
	snprintf(p, sizeof(p), "/proc/%d/comm", pid);
	if ((f = fopen(p, "r"))) {
		if (fgets(comm, sizeof(comm), f))
			comm[strcspn(comm, "\n")] = 0;
		fclose(f);
	}
	snprintf(who, n, "%d %s", pid, comm);
	return 1;
}

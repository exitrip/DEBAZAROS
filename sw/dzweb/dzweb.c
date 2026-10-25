/*
 * dzweb - serve the DEBAZAROS web app and bridge WebSocket <-> OSC/UDP.
 *
 *   dzweb [-p port] [-w wwwdir] [-m mediadir] [-d host] [-o oscport] [-v]
 *     -p PORT   HTTP port (default 8080)
 *     -w DIR    web app files (default /home/ebaz/www)
 *     -m DIR    media root with img/ and movies/ (default /home/ebaz)
 *     -d HOST   debazd host (default 127.0.0.1), -o its UDP port (9000)
 *
 * HTTP:
 *   GET /...        static files from DIR (index.html for /)
 *   GET /units      JSON list of debazd units on the LAN (broadcast /info)
 *   GET /osc        WebSocket. Each binary message is one OSC packet (or
 *                   bundle). Every browser gets its own UDP socket to debazd,
 *                   so replies and /subscribe events come back to it.
 *   GET /media                     JSON: free bytes, files in img/ and movies/
 *   GET    /media/<img|movies>/<name>  download a file (?dl: as attachment)
 *   PUT    /media/<img|movies>/<name>  upload (raw body, Content-Length)
 *   DELETE /media/<img|movies>/<name>  delete
 *     Media folders are <media>/img and <media>/movies (-m, default
 *     /home/ebaz), the folders debazd reads. Names: [A-Za-z0-9._-], as in
 *     debazd. An upload goes to .<name>.part and is renamed when complete.
 *     Transfers move in chunks inside the poll loop, so other clients stay live.
 *
 * Single thread, poll(). No authentication: for an installation LAN only.
 */
#define _GNU_SOURCE
#define _FILE_OFFSET_BITS 64		/* movies can be > 2 GB */
#include "dz_osc.h"

#include <arpa/inet.h>
#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <netinet/in.h>
#include <poll.h>
#include <signal.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/sendfile.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/statvfs.h>
#include <time.h>
#include <unistd.h>

#define MAX_CLIENTS	16
#define HDR_MAX		8192
#define WS_MAX		65536
#define MEDIA_MAX	(4LL << 30)	/* largest upload */
#define DISK_KEEP	(64LL << 20)	/* never fill the root file system */

static int  verbose;
static char www[256] = "/home/ebaz/www";
static char media[128] = "/home/ebaz";
static struct sockaddr_in dzd;		/* debazd address */
static volatile sig_atomic_t stop;

static void logv(const char *fmt, ...)
{
	va_list ap;

	if (!verbose)
		return;
	va_start(ap, fmt);
	vfprintf(stderr, fmt, ap);
	va_end(ap);
}

/* ---- SHA-1 and base64 (for the WebSocket handshake) ----------------------- */
typedef struct { uint32_t h[5]; uint64_t len; uint8_t buf[64]; size_t n; } sha1_t;

static uint32_t rol(uint32_t x, int k) { return (x << k) | (x >> (32 - k)); }

static void sha1_block(sha1_t *s, const uint8_t *p)
{
	uint32_t w[80], a = s->h[0], b = s->h[1], c = s->h[2], d = s->h[3], e = s->h[4];

	for (int i = 0; i < 16; i++)
		w[i] = (uint32_t)p[4 * i] << 24 | (uint32_t)p[4 * i + 1] << 16 |
		       (uint32_t)p[4 * i + 2] << 8 | p[4 * i + 3];
	for (int i = 16; i < 80; i++)
		w[i] = rol(w[i - 3] ^ w[i - 8] ^ w[i - 14] ^ w[i - 16], 1);
	for (int i = 0; i < 80; i++) {
		uint32_t f, k, t;

		if (i < 20)      { f = (b & c) | (~b & d);           k = 0x5A827999; }
		else if (i < 40) { f = b ^ c ^ d;                     k = 0x6ED9EBA1; }
		else if (i < 60) { f = (b & c) | (b & d) | (c & d);   k = 0x8F1BBCDC; }
		else             { f = b ^ c ^ d;                     k = 0xCA62C1D6; }
		t = rol(a, 5) + f + e + k + w[i];
		e = d; d = c; c = rol(b, 30); b = a; a = t;
	}
	s->h[0] += a; s->h[1] += b; s->h[2] += c; s->h[3] += d; s->h[4] += e;
}

static void sha1(const uint8_t *data, size_t len, uint8_t out[20])
{
	sha1_t s = { { 0x67452301, 0xEFCDAB89, 0x98BADCFE, 0x10325476, 0xC3D2E1F0 }, 0, { 0 }, 0 };
	uint8_t pad[72];
	size_t pl;

	s.len = (uint64_t)len * 8;
	for (; len >= 64; data += 64, len -= 64)
		sha1_block(&s, data);
	memcpy(s.buf, data, len);
	pl = len < 56 ? 56 - len : 120 - len;
	memset(pad, 0, sizeof(pad));
	pad[0] = 0x80;
	for (int i = 0; i < 8; i++)
		pad[pl + i] = (uint8_t)(s.len >> (56 - 8 * i));
	{
		uint8_t blk[128];

		memcpy(blk, s.buf, len);
		memcpy(blk + len, pad, pl + 8);
		sha1_block(&s, blk);
		if (len + pl + 8 > 64)
			sha1_block(&s, blk + 64);
	}
	for (int i = 0; i < 5; i++)
		for (int j = 0; j < 4; j++)
			out[4 * i + j] = (uint8_t)(s.h[i] >> (24 - 8 * j));
}

static void b64(const uint8_t *in, size_t n, char *out)
{
	static const char t[] =
		"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
	size_t i, o = 0;

	for (i = 0; i + 2 < n; i += 3) {
		uint32_t v = (uint32_t)in[i] << 16 | (uint32_t)in[i + 1] << 8 | in[i + 2];

		out[o++] = t[v >> 18]; out[o++] = t[(v >> 12) & 63];
		out[o++] = t[(v >> 6) & 63]; out[o++] = t[v & 63];
	}
	if (i < n) {
		uint32_t v = (uint32_t)in[i] << 16 | (i + 1 < n ? (uint32_t)in[i + 1] << 8 : 0);

		out[o++] = t[v >> 18]; out[o++] = t[(v >> 12) & 63];
		out[o++] = i + 1 < n ? t[(v >> 6) & 63] : '=';
		out[o++] = '=';
	}
	out[o] = 0;
}

/* ---- clients ------------------------------------------------------------------ */
typedef struct {
	int     fd;		/* TCP, -1 = free */
	int     udp;	/* UDP to debazd once a WebSocket */
	int     ws;
	int     xfer;	/* XFER_*: file transfer in progress */
	int     ffd;	/* file of the transfer */
	long long left;	/* bytes still to move */
	char    part[320], final[320];	/* upload: temp and final path */
	uint8_t in[WS_MAX + 16];
	size_t  n;
} client_t;

enum { XFER_NONE, XFER_UP, XFER_DOWN };

static client_t C[MAX_CLIENTS];

static void client_close(client_t *c)
{
	if (c->udp >= 0) {		/* stop events for this page */
		uint8_t b[64];
		size_t n = dz_osc_build(b, sizeof(b), "/unsubscribe", "");

		sendto(c->udp, b, n, 0, (struct sockaddr *)&dzd, sizeof(dzd));
		close(c->udp);
	}
	if (c->ffd >= 0)
		close(c->ffd);
	if (c->xfer == XFER_UP) {		/* incomplete upload */
		unlink(c->part);
		logv("dzweb: upload aborted, %lld bytes missing\n", c->left);
	}
	if (c->fd >= 0)
		close(c->fd);
	c->fd = c->udp = c->ffd = -1;
	c->ws = 0;
	c->xfer = XFER_NONE;
	c->n = 0;
}

static int send_all(int fd, const void *p, size_t n)
{
	const uint8_t *b = p;

	while (n) {
		ssize_t k = send(fd, b, n, MSG_NOSIGNAL);

		if (k < 0) {
			if (errno == EINTR)
				continue;
			if (errno == EAGAIN) {	/* slow client: wait a little */
				struct pollfd pf = { .fd = fd, .events = POLLOUT };

				if (poll(&pf, 1, 200) <= 0)
					return -1;
				continue;
			}
			return -1;
		}
		b += k;
		n -= (size_t)k;
	}
	return 0;
}

static void http_reply(client_t *c, const char *status, const char *type,
		       const void *body, size_t len)
{
	char h[256];
	int n = snprintf(h, sizeof(h), "HTTP/1.1 %s\r\nContent-Type: %s\r\n"
			 "Content-Length: %zu\r\nCache-Control: no-cache\r\n"
			 "Access-Control-Allow-Origin: *\r\n"	/* pages of other units */
			 "Connection: close\r\n\r\n", status, type, len);

	send_all(c->fd, h, (size_t)n);
	if (len)
		send_all(c->fd, body, len);
}

/* ---- static files ------------------------------------------------------------ */
static const char *mime(const char *p)
{
	const char *e = strrchr(p, '.');

	if (!e) return "application/octet-stream";
	if (!strcmp(e, ".html")) return "text/html; charset=utf-8";
	if (!strcmp(e, ".js")) return "text/javascript; charset=utf-8";
	if (!strcmp(e, ".css")) return "text/css; charset=utf-8";
	if (!strcmp(e, ".svg")) return "image/svg+xml";
	if (!strcmp(e, ".png")) return "image/png";
	if (!strcasecmp(e, ".jpg") || !strcasecmp(e, ".jpeg")) return "image/jpeg";
	if (!strcasecmp(e, ".gif")) return "image/gif";
	if (!strcasecmp(e, ".webp")) return "image/webp";
	if (!strcasecmp(e, ".bmp")) return "image/bmp";
	if (!strcasecmp(e, ".mp4") || !strcasecmp(e, ".m4v")) return "video/mp4";
	if (!strcasecmp(e, ".webm")) return "video/webm";
	if (!strcasecmp(e, ".mkv")) return "video/x-matroska";
	if (!strcasecmp(e, ".mov")) return "video/quicktime";
	if (!strcmp(e, ".json") || !strcmp(e, ".webmanifest")) return "application/json";
	return "application/octet-stream";
}

static void serve_file(client_t *c, const char *path)
{
	char full[512];
	struct stat st;
	char *buf;
	FILE *fp;

	if (!strcmp(path, "/"))
		path = "/index.html";
	for (const char *p = path + 1; *p; p++)	/* plain names only */
		if (!((*p >= 'a' && *p <= 'z') || (*p >= 'A' && *p <= 'Z') ||
		      (*p >= '0' && *p <= '9') || *p == '.' || *p == '-' || *p == '_') ||
		    (p[0] == '.' && p[1] == '.')) {
			http_reply(c, "404 Not Found", "text/plain", "not found\n", 10);
			return;
		}
	snprintf(full, sizeof(full), "%s%s", www, path);
	if (stat(full, &st) < 0 || !S_ISREG(st.st_mode) || st.st_size > 4 * 1024 * 1024 ||
	    !(fp = fopen(full, "rb"))) {
		http_reply(c, "404 Not Found", "text/plain", "not found\n", 10);
		return;
	}
	buf = malloc((size_t)st.st_size + 1);
	if (buf && fread(buf, 1, (size_t)st.st_size, fp) == (size_t)st.st_size)
		http_reply(c, "200 OK", mime(path), buf, (size_t)st.st_size);
	else
		http_reply(c, "500 Error", "text/plain", "error\n", 6);
	free(buf);
	fclose(fp);
}

/* ---- /units: broadcast /info, collect replies ---------------------------------- */
static void serve_units(client_t *c)
{
	int s = socket(AF_INET, SOCK_DGRAM, 0), one = 1, n = 0;
	struct sockaddr_in to = dzd;
	uint8_t pkt[64], buf[1024];
	size_t len = dz_osc_build(pkt, sizeof(pkt), "/info", "");
	char json[8192];
	size_t o = 0;
	char seen[16][32];
	int nseen = 0;
	struct timespec t0, t;

	o += (size_t)snprintf(json + o, sizeof(json) - o, "[");
	if (s >= 0) {
		setsockopt(s, SOL_SOCKET, SO_BROADCAST, &one, sizeof(one));
		sendto(s, pkt, len, 0, (struct sockaddr *)&dzd, sizeof(dzd));	/* local */
		to.sin_addr.s_addr = htonl(INADDR_BROADCAST);
		sendto(s, pkt, len, 0, (struct sockaddr *)&to, sizeof(to));
		clock_gettime(CLOCK_MONOTONIC, &t0);
		for (;;) {
			struct pollfd pf = { .fd = s, .events = POLLIN };
			struct sockaddr_in from;
			socklen_t fl = sizeof(from);
			long ms;
			ssize_t k;
			dz_msg m;
			char ip[INET_ADDRSTRLEN];
			int dup = 0;

			clock_gettime(CLOCK_MONOTONIC, &t);
			ms = 400 - ((t.tv_sec - t0.tv_sec) * 1000 + (t.tv_nsec - t0.tv_nsec) / 1000000);
			if (ms <= 0 || poll(&pf, 1, (int)ms) <= 0)
				break;
			k = recvfrom(s, buf, sizeof(buf), 0, (struct sockaddr *)&from, &fl);
			if (k <= 0 || dz_osc_parse(buf, (size_t)k, &m) < 0 ||
			    strcmp(m.path, "/info") || m.n < 6)
				continue;
			for (int i = 0; i < nseen; i++)	/* local + broadcast reply */
				dup |= !strcmp(seen[i], m.a[5].s);
			if (dup || nseen >= 16)
				continue;
			snprintf(seen[nseen++], sizeof(seen[0]), "%s", m.a[5].s);
			inet_ntop(AF_INET, &from.sin_addr, ip, sizeof(ip));
			if (!strcmp(ip, "127.0.0.1"))
				ip[0] = 0;		/* "this unit" */
			o += (size_t)snprintf(json + o, sizeof(json) - o,
				"%s{\"ip\":\"%s\",\"variant\":\"%s\",\"usable\":%d,"
				"\"host\":\"%s\",\"mac\":\"%s\"}", n++ ? "," : "", ip,
				m.a[0].s, m.a[3].i, m.a[4].s, m.a[5].s);
		}
		close(s);
	}
	o += (size_t)snprintf(json + o, sizeof(json) - o, "]\n");
	http_reply(c, "200 OK", "application/json", json, o);
}

/* ---- /media: files in img/ and movies/ ---------------------------------------- */
static void http_err(client_t *c, const char *status, const char *msg)
{
	http_reply(c, status, "text/plain", msg, strlen(msg));
}

/* same rule as debazd (dz_draw.c name_ok): a plain name on a network port */
static int media_name_ok(const char *n)
{
	if (!*n || *n == '.' || strlen(n) > 96 || strstr(n, ".."))
		return 0;
	for (const char *p = n; *p; p++)
		if (!((*p >= 'a' && *p <= 'z') || (*p >= 'A' && *p <= 'Z') ||
		      (*p >= '0' && *p <= '9') || *p == '.' || *p == '_' || *p == '-'))
			return 0;
	return 1;
}

static long long disk_free(void)
{
	struct statvfs v;

	return statvfs(media, &v) < 0 ? -1 : (long long)v.f_bavail * (long long)v.f_frsize;
}

/* "/media/<kind>/<name>" -> full path; -1 if not a valid media path */
static int media_path(const char *url, char *out, size_t sz, char *part, size_t psz)
{
	char kind[16], name[128];
	const char *s = url + 7, *e = strchr(s, '/');

	if (!e || (size_t)(e - s) >= sizeof(kind))
		return -1;
	memcpy(kind, s, (size_t)(e - s));
	kind[e - s] = 0;
	if (strcmp(kind, "img") && strcmp(kind, "movies"))
		return -1;
	snprintf(name, sizeof(name), "%s", e + 1);
	if (!media_name_ok(name))
		return -1;
	snprintf(out, sz, "%.127s/%.6s/%.96s", media, kind, name);
	if (part)
		snprintf(part, psz, "%.127s/%.6s/.%.96s.part", media, kind, name);
	return 0;
}

static size_t list_dir(const char *kind, char *o, size_t room)
{
	char dir[300];
	size_t k = 0;
	int n = 0;
	DIR *d;
	struct dirent *e;

	snprintf(dir, sizeof(dir), "%s/%s", media, kind);
	k += (size_t)snprintf(o + k, room - k, "\"%s\":[", kind);
	if ((d = opendir(dir))) {
		while ((e = readdir(d)) && k + 200 < room) {
			char f[420];
			struct stat st;

			if (!media_name_ok(e->d_name))	/* also hides .part files */
				continue;
			snprintf(f, sizeof(f), "%.140s/%.96s", dir, e->d_name);
			if (stat(f, &st) < 0 || !S_ISREG(st.st_mode))
				continue;
			k += (size_t)snprintf(o + k, room - k, "%s{\"name\":\"%s\",\"size\":%lld,\"mtime\":%lld}",
					      n++ ? "," : "", e->d_name, (long long)st.st_size,
					      (long long)st.st_mtime);
		}
		closedir(d);
	}
	k += (size_t)snprintf(o + k, room - k, "]");
	return k;
}

static void serve_media_list(client_t *c)
{
	static char json[65536];
	size_t o = 0;

	o += (size_t)snprintf(json, sizeof(json), "{\"free\":%lld,\"keep\":%lld,\"max\":%lld,",
			      disk_free(), DISK_KEEP, MEDIA_MAX);
	o += list_dir("img", json + o, sizeof(json) - o - 64);
	o += (size_t)snprintf(json + o, sizeof(json) - o, ",");
	o += list_dir("movies", json + o, sizeof(json) - o - 64);
	o += (size_t)snprintf(json + o, sizeof(json) - o, "}\n");
	http_reply(c, "200 OK", "application/json", json, o);
}

/* returns 1: transfer started (keep the connection), 0: replied (close) */
static int media_get(client_t *c, const char *url, int attach)
{
	char path[320], h[640], disp[160] = "";
	struct stat st;
	int fd, n;

	if (media_path(url, path, sizeof(path), NULL, 0) < 0 ||
	    (fd = open(path, O_RDONLY)) < 0) {
		http_err(c, "404 Not Found", "not found\n");
		return 0;
	}
	if (fstat(fd, &st) < 0 || !S_ISREG(st.st_mode)) {
		close(fd);
		http_err(c, "404 Not Found", "not found\n");
		return 0;
	}
	if (attach)	/* save, not show (download links to another unit) */
		snprintf(disp, sizeof(disp), "Content-Disposition: attachment; filename=\"%.96s\"\r\n",
			 strrchr(path, '/') + 1);
	n = snprintf(h, sizeof(h), "HTTP/1.1 200 OK\r\nContent-Type: %s\r\n"
		     "Content-Length: %lld\r\nAccess-Control-Allow-Origin: *\r\n%s"
		     "Connection: close\r\n\r\n", mime(path), (long long)st.st_size, disp);
	if (send_all(c->fd, h, (size_t)n) < 0) {
		close(fd);
		return 0;
	}
	c->ffd = fd;
	c->left = st.st_size;
	c->xfer = XFER_DOWN;
	logv("dzweb: download %s (%lld bytes)\n", path, c->left);
	return 1;
}

/* socket writable: send the next chunk. returns -1 when done or failed */
static int media_pump(client_t *c)
{
	ssize_t k = sendfile(c->fd, c->ffd, NULL, c->left > (1 << 18) ? (1 << 18) : (size_t)c->left);

	if (k < 0)
		return errno == EAGAIN || errno == EINTR ? 0 : -1;
	c->left -= k;
	if (k == 0 || c->left <= 0) {
		c->xfer = XFER_NONE;		/* complete: close normally */
		return -1;
	}
	return 0;
}

/* write the body bytes we have; finish the upload when all arrived.
   returns 0 to wait for more, -1 to close */
static int upload_data(client_t *c, const uint8_t *p, size_t n)
{
	if ((long long)n > c->left)
		n = (size_t)c->left;		/* ignore extra bytes */
	while (n) {
		ssize_t w = write(c->ffd, p, n);

		if (w < 0) {
			if (errno == EINTR)
				continue;
			http_err(c, "507 Insufficient Storage", "write failed\n");
			return -1;			/* client_close unlinks .part */
		}
		p += w;
		n -= (size_t)w;
		c->left -= w;
	}
	if (c->left > 0)
		return 0;
	if (fsync(c->ffd) < 0 || close(c->ffd) < 0) {
		c->ffd = -1;
		http_err(c, "507 Insufficient Storage", "write failed\n");
		return -1;
	}
	c->ffd = -1;
	if (rename(c->part, c->final) < 0) {
		http_err(c, "500 Error", "rename failed\n");
		return -1;
	}
	c->xfer = XFER_NONE;
	logv("dzweb: upload done: %s\n", c->final);
	http_err(c, "201 Created", "ok\n");
	return -1;
}

/* PUT: hdr = request header, body = bytes after it. returns 0 = keep, -1 = close */
static int media_put(client_t *c, const char *url, const char *hdr, const uint8_t *body, size_t blen)
{
	const char *cl = strcasestr(hdr, "\r\nContent-Length:");
	long long len, avail;

	if (media_path(url, c->final, sizeof(c->final), c->part, sizeof(c->part)) < 0) {
		http_err(c, "400 Bad Request", "bad name: use A-Z a-z 0-9 . _ -\n");
		return -1;
	}
	if (!cl || (len = atoll(cl + 17)) < 0) {
		http_err(c, "411 Length Required", "Content-Length needed\n");
		return -1;
	}
	if (len > MEDIA_MAX) {
		http_err(c, "413 Payload Too Large", "file too large\n");
		return -1;
	}
	avail = disk_free();
	if (avail >= 0 && len > avail - DISK_KEEP) {
		char m[128];

		snprintf(m, sizeof(m), "not enough space: %lld MB free, %lld MB must stay free\n",
			 avail >> 20, DISK_KEEP >> 20);
		http_err(c, "507 Insufficient Storage", m);
		return -1;
	}
	c->ffd = open(c->part, O_WRONLY | O_CREAT | O_TRUNC, 0644);
	if (c->ffd < 0) {
		http_err(c, "500 Error", "cannot create file\n");
		return -1;
	}
	c->xfer = XFER_UP;
	c->left = len;
	logv("dzweb: upload %s (%lld bytes)\n", c->final, len);
	return upload_data(c, body, blen);
}

static void media_delete(client_t *c, const char *url)
{
	char path[320];

	if (media_path(url, path, sizeof(path), NULL, 0) < 0 || unlink(path) < 0)
		http_err(c, "404 Not Found", "not found\n");
	else
		http_err(c, "200 OK", "deleted\n");
}

/* %XX in a URL path (names from encodeURIComponent) */
static void url_decode(char *s)
{
	char *o = s;

	for (; *s; s++) {
		if (s[0] == '%' && s[1] && s[2]) {
			char hx[3] = { s[1], s[2], 0 };

			*o++ = (char)strtol(hx, NULL, 16);
			s += 2;
		} else {
			*o++ = *s;
		}
	}
	*o = 0;
}

/* ---- WebSocket ---------------------------------------------------------------- */
static void ws_send(client_t *c, int op, const uint8_t *p, size_t n)
{
	uint8_t h[10];
	size_t hl = 2;

	h[0] = (uint8_t)(0x80 | op);
	if (n < 126) {
		h[1] = (uint8_t)n;
	} else if (n < 65536) {
		h[1] = 126; h[2] = (uint8_t)(n >> 8); h[3] = (uint8_t)n; hl = 4;
	} else {
		h[1] = 127;
		for (int i = 0; i < 8; i++)
			h[2 + i] = (uint8_t)((uint64_t)n >> (56 - 8 * i));
		hl = 10;
	}
	if (send_all(c->fd, h, hl) < 0 || send_all(c->fd, p, n) < 0)
		client_close(c);
}

static int ws_handshake(client_t *c, const char *req)
{
	const char *k = strcasestr(req, "\r\nSec-WebSocket-Key:");
	char key[128], acc[64], resp[256];
	uint8_t dig[20];
	int i = 0;

	if (!k)
		return -1;
	k += 20;
	while (*k == ' ')
		k++;
	while (*k && *k != '\r' && i < 60)
		key[i++] = *k++;
	key[i] = 0;
	strcat(key, "258EAFA5-E914-47DA-95CA-C5AB0DC85B11");
	sha1((const uint8_t *)key, strlen(key), dig);
	b64(dig, 20, acc);
	i = snprintf(resp, sizeof(resp), "HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\n"
		     "Connection: Upgrade\r\nSec-WebSocket-Accept: %s\r\n\r\n", acc);
	if (send_all(c->fd, resp, (size_t)i) < 0)
		return -1;
	c->udp = socket(AF_INET, SOCK_DGRAM, 0);
	if (c->udp < 0)
		return -1;
	c->ws = 1;
	return 0;
}

/* parse complete frames in c->in; returns -1 to close */
static int ws_frames(client_t *c)
{
	for (;;) {
		size_t hl = 2, len;
		uint8_t *p = c->in, mask[4];
		int op, fin;

		if (c->n < 2)
			return 0;
		fin = p[0] & 0x80;
		op = p[0] & 0x0F;
		len = p[1] & 0x7F;
		if (!(p[1] & 0x80))
			return -1;			/* clients must mask */
		if (len == 126) {
			if (c->n < 4) return 0;
			len = (size_t)p[2] << 8 | p[3];
			hl = 4;
		} else if (len == 127) {
			if (c->n < 10) return 0;
			len = 0;
			for (int i = 0; i < 8; i++)
				len = len << 8 | p[2 + i];
			hl = 10;
		}
		if (len > WS_MAX)
			return -1;
		if (c->n < hl + 4 + len)
			return 0;
		memcpy(mask, p + hl, 4);
		for (size_t i = 0; i < len; i++)
			p[hl + 4 + i] ^= mask[i & 3];
		if (!fin)
			return -1;			/* fragmentation not supported */
		if (op == 1 || op == 2) {		/* one OSC packet */
			sendto(c->udp, p + hl + 4, len, 0, (struct sockaddr *)&dzd, sizeof(dzd));
		} else if (op == 8) {
			ws_send(c, 8, NULL, 0);
			return -1;
		} else if (op == 9) {
			ws_send(c, 10, p + hl + 4, len);
		}
		memmove(c->in, c->in + hl + 4 + len, c->n - (hl + 4 + len));
		c->n -= hl + 4 + len;
	}
}

/* returns -1 to close */
static int on_tcp(client_t *c)
{
	ssize_t k;

	if (c->xfer == XFER_UP) {		/* upload body: straight to the file */
		k = recv(c->fd, c->in, sizeof(c->in), 0);
		if (k < 0 && (errno == EAGAIN || errno == EINTR))
			return 0;
		if (k <= 0)
			return -1;
		return upload_data(c, c->in, (size_t)k);
	}
	k = recv(c->fd, c->in + c->n, sizeof(c->in) - c->n - 1, 0);
	if (k < 0 && (errno == EAGAIN || errno == EINTR))
		return 0;
	if (k <= 0)
		return -1;
	c->n += (size_t)k;
	if (c->ws)
		return ws_frames(c);
	c->in[c->n] = 0;
	if (!strstr((char *)c->in, "\r\n\r\n"))
		return c->n >= HDR_MAX ? -1 : 0;	/* wait for the whole header */
	{
		char method[8], path[256], *hend = strstr((char *)c->in, "\r\n\r\n"), *q;
		size_t hlen = (size_t)(hend + 4 - (char *)c->in);
		int attach = 0;

		if (sscanf((char *)c->in, "%7s %255s", method, path) != 2)
			return -1;
		logv("dzweb: %s %s\n", method, path);
		if ((q = strchr(path, '?'))) {
			attach = !!strstr(q, "dl");
			*q = 0;
		}
		if (!strncmp(path, "/media/", 7)) {
			url_decode(path);
			if (!strcmp(method, "OPTIONS")) {	/* CORS preflight */
				static const char pre[] = "HTTP/1.1 204 No Content\r\n"
					"Access-Control-Allow-Origin: *\r\n"
					"Access-Control-Allow-Methods: GET, PUT, DELETE\r\n"
					"Access-Control-Allow-Headers: Content-Type\r\n"
					"Content-Length: 0\r\nConnection: close\r\n\r\n";
				send_all(c->fd, pre, sizeof(pre) - 1);
				return -1;
			}
			if (!strcmp(method, "PUT")) {
				*hend = 0;
				return media_put(c, path, (char *)c->in, c->in + hlen, c->n - hlen);
			}
			if (!strcmp(method, "DELETE")) {
				media_delete(c, path);
				return -1;
			}
			if (!strcmp(method, "GET"))
				return media_get(c, path, attach) ? 0 : -1;
		}
		if (strcmp(method, "GET")) {
			http_err(c, "405 Method Not Allowed", "method not allowed\n");
			return -1;
		}
		if (!strcmp(path, "/osc")) {
			if (ws_handshake(c, (char *)c->in) < 0)
				return -1;
			c->n = 0;
			return 0;
		}
		if (!strcmp(path, "/units"))
			serve_units(c);
		else if (!strcmp(path, "/media"))
			serve_media_list(c);
		else
			serve_file(c, path);
		return -1;				/* Connection: close */
	}
}

static void on_signal(int s) { (void)s; stop = 1; }

int main(int argc, char **argv)
{
	int port = 8080, oport = 9000, lfd, opt, one = 1;
	const char *host = "127.0.0.1";
	struct sockaddr_in me;

	while ((opt = getopt(argc, argv, "p:w:m:d:o:v")) != -1) {
		switch (opt) {
		case 'p': port = atoi(optarg); break;
		case 'w': snprintf(www, sizeof(www), "%s", optarg); break;
		case 'm': snprintf(media, sizeof(media), "%s", optarg); break;
		case 'd': host = optarg; break;
		case 'o': oport = atoi(optarg); break;
		case 'v': verbose = 1; break;
		default:
			fprintf(stderr, "usage: %s [-p port] [-w wwwdir] [-m mediadir] [-d host] [-o oscport] [-v]\n",
				argv[0]);
			return 2;
		}
	}
	memset(&dzd, 0, sizeof(dzd));
	dzd.sin_family = AF_INET;
	dzd.sin_port = htons((uint16_t)oport);
	if (inet_pton(AF_INET, host, &dzd.sin_addr) != 1) {
		fprintf(stderr, "dzweb: -d needs an IPv4 address\n");
		return 2;
	}
	for (int i = 0; i < MAX_CLIENTS; i++)
		C[i].fd = C[i].udp = C[i].ffd = -1;
	for (const char *k = "img"; k; k = strcmp(k, "img") ? NULL : "movies") {
		char d[300];

		snprintf(d, sizeof(d), "%s/%s", media, k);
		mkdir(d, 0755);			/* EEXIST is fine */
	}

	lfd = socket(AF_INET, SOCK_STREAM, 0);
	setsockopt(lfd, SOL_SOCKET, SO_REUSEADDR, &one, sizeof(one));
	memset(&me, 0, sizeof(me));
	me.sin_family = AF_INET;
	me.sin_addr.s_addr = htonl(INADDR_ANY);
	me.sin_port = htons((uint16_t)port);
	if (lfd < 0 || bind(lfd, (struct sockaddr *)&me, sizeof(me)) < 0 || listen(lfd, 8) < 0) {
		fprintf(stderr, "dzweb: tcp/%d: %s\n", port, strerror(errno));
		return 1;
	}
	signal(SIGINT, on_signal);
	signal(SIGTERM, on_signal);
	signal(SIGPIPE, SIG_IGN);
	fprintf(stderr, "dzweb: http://0.0.0.0:%d/  files %s  media %s  debazd %s:%d\n",
		port, www, media, host, oport);

	while (!stop) {
		struct pollfd pf[1 + 2 * MAX_CLIENTS];
		int map[1 + 2 * MAX_CLIENTS], np = 1;

		pf[0].fd = lfd;
		pf[0].events = POLLIN;
		for (int i = 0; i < MAX_CLIENTS; i++) {
			if (C[i].fd < 0)
				continue;
			pf[np].fd = C[i].fd;
			pf[np].events = C[i].xfer == XFER_DOWN ? POLLOUT : POLLIN;
			map[np++] = i;
			if (C[i].udp >= 0) {
				pf[np].fd = C[i].udp; pf[np].events = POLLIN; map[np++] = i | 0x100;
			}
		}
		if (poll(pf, (nfds_t)np, 1000) < 0) {
			if (errno == EINTR)
				continue;
			break;
		}
		if (pf[0].revents & POLLIN) {
			int fd = accept(lfd, NULL, NULL), slot = -1;

			for (int i = 0; i < MAX_CLIENTS && fd >= 0; i++)
				if (C[i].fd < 0) {
					slot = i;
					break;
				}
			if (slot < 0) {
				if (fd >= 0)
					close(fd);
			} else {
				fcntl(fd, F_SETFL, fcntl(fd, F_GETFL) | O_NONBLOCK);
				C[slot].fd = fd;
				C[slot].udp = C[slot].ffd = -1;
				C[slot].ws = 0;
				C[slot].xfer = XFER_NONE;
				C[slot].n = 0;
			}
		}
		for (int k = 1; k < np; k++) {
			client_t *c = &C[map[k] & 0xFF];

			if (!pf[k].revents || c->fd < 0)
				continue;
			if (map[k] & 0x100) {		/* debazd -> browser */
				uint8_t b[DZ_OSC_MAX_PKT];
				ssize_t n = recv(c->udp, b, sizeof(b), 0);

				if (n > 0)
					ws_send(c, 2, b, (size_t)n);
			} else if (c->xfer == XFER_DOWN) {
				if ((pf[k].revents & (POLLERR | POLLHUP)) || media_pump(c) < 0)
					client_close(c);
			} else if (on_tcp(c) < 0) {
				logv("dzweb: client %d closed\n", map[k] & 0xFF);
				client_close(c);
			}
		}
	}
	for (int i = 0; i < MAX_CLIENTS; i++)
		if (C[i].fd >= 0)
			client_close(&C[i]);
	close(lfd);
	return 0;
}

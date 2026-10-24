/*
 * dz_osc.h - OSC 1.0 wire format: parse, match, build. No sockets.
 *
 * Argument tags read: i f s T F (b is skipped). Tags written: i f s.
 * Address patterns: ? * [abc] [a-z] [!x] {foo,bar}.
 */
#ifndef DZ_OSC_H
#define DZ_OSC_H

#include <stdarg.h>
#include <stddef.h>
#include <stdint.h>
#include "dz_fields.h"	/* dz_arg */

#define DZ_OSC_MAX_ARGS	32
#define DZ_OSC_MAX_PKT	8192

typedef struct {
	const char *path;
	dz_arg      a[DZ_OSC_MAX_ARGS];
	int         n;
} dz_msg;

/* Parse one message (not a bundle). 0 or -1. Strings point into b. */
int dz_osc_parse(const uint8_t *b, size_t len, dz_msg *m);

/* Call cb for every message in a packet, bundles included (time tags are
 * ignored: everything runs at once). Returns the number of messages. */
typedef void (*dz_osc_cb)(dz_msg *m, void *ctx);
int dz_osc_walk(const uint8_t *b, size_t len, dz_osc_cb cb, void *ctx);

/* 1 if pattern matches path. */
int dz_osc_match(const char *pattern, const char *path);

/* Build a message into buf. tags: "", "i", "fs", ... (no leading comma).
 * Returns the length, or 0 if it does not fit. */
size_t dz_osc_build(uint8_t *buf, size_t cap, const char *path, const char *tags, ...);
size_t dz_osc_vbuild(uint8_t *buf, size_t cap, const char *path, const char *tags,
		     va_list ap);

/* Build from already parsed arguments (used by dzctl). */
size_t dz_osc_build_args(uint8_t *buf, size_t cap, const char *path,
			 const dz_arg *a, int n);

/* Print a message as text: "/path i:3 f:0.5 s:"x"". */
void dz_osc_format(const dz_msg *m, char *out, size_t cap);

#endif /* DZ_OSC_H */

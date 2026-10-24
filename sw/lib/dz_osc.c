/*
 * dz_osc.c - see dz_osc.h. The parser and matcher come from sw/oscreg.
 */
#include "dz_osc.h"

#include <stdio.h>
#include <string.h>

static uint32_t rd32(const uint8_t *p)
{
	return ((uint32_t)p[0] << 24) | ((uint32_t)p[1] << 16) |
	       ((uint32_t)p[2] << 8) | p[3];
}

static void wr32(uint8_t *p, uint32_t v)
{
	p[0] = (uint8_t)(v >> 24);
	p[1] = (uint8_t)(v >> 16);
	p[2] = (uint8_t)(v >> 8);
	p[3] = (uint8_t)v;
}

static size_t pad4(size_t n) { return (n + 3u) & ~(size_t)3u; }

/* Padded OSC string at pos. Returns its padded size, 0 on error. */
static size_t rd_str(const uint8_t *b, size_t len, size_t pos, const char **out)
{
	size_t e = pos;

	while (e < len && b[e])
		e++;
	if (e >= len)
		return 0;
	*out = (const char *)(b + pos);
	return pad4(e - pos + 1);
}

int dz_osc_parse(const uint8_t *b, size_t len, dz_msg *m)
{
	const char *tags = NULL;
	size_t pos = 0, step;

	m->n = 0;
	m->path = NULL;
	if (!len || b[0] != '/')
		return -1;
	step = rd_str(b, len, 0, &m->path);
	if (!step)
		return -1;
	pos = step;
	if (pos < len) {
		step = rd_str(b, len, pos, &tags);
		if (step && tags[0] == ',')
			pos += step;
		else
			tags = NULL;
	}
	for (const char *t = tags ? tags + 1 : ""; *t && m->n < DZ_OSC_MAX_ARGS; t++) {
		dz_arg *a = &m->a[m->n];

		memset(a, 0, sizeof(*a));
		switch (*t) {
		case 'i':
			if (pos + 4 > len)
				return -1;
			a->type = 'i';
			a->i = (int32_t)rd32(b + pos);
			a->f = (float)a->i;
			pos += 4;
			break;
		case 'f': {
			uint32_t u;

			if (pos + 4 > len)
				return -1;
			u = rd32(b + pos);
			a->type = 'f';
			memcpy(&a->f, &u, 4);
			a->i = (int32_t)a->f;
			pos += 4;
			break;
		}
		case 'T':
		case 'F':
			a->type = 'i';
			a->i = (*t == 'T');
			a->f = (float)a->i;
			break;
		case 's':
			step = rd_str(b, len, pos, &a->s);
			if (!step)
				return -1;
			a->type = 's';
			pos += step;
			break;
		case 'b':
			if (pos + 4 > len)
				return -1;
			pos += 4 + pad4(rd32(b + pos));
			continue;
		default:
			return 0;	/* unknown width: keep what we have */
		}
		m->n++;
	}
	return 0;
}

int dz_osc_walk(const uint8_t *b, size_t len, dz_osc_cb cb, void *ctx)
{
	dz_msg m;
	int count = 0;

	if (len >= 16 && memcmp(b, "#bundle", 8) == 0) {
		size_t pos = 16;

		while (pos + 4 <= len) {
			uint32_t sz = rd32(b + pos);

			pos += 4;
			if (!sz || pos + sz > len)
				break;
			count += dz_osc_walk(b + pos, sz, cb, ctx);
			pos += sz;
		}
		return count;
	}
	if (dz_osc_parse(b, len, &m) < 0)
		return 0;
	cb(&m, ctx);
	return 1;
}

/* ---- pattern matching ---------------------------------------------------- */
static int match_class(const char **pp, char c)
{
	const char *p = *pp + 1;
	int neg = 0, ok = 0;

	if (*p == '!') {
		neg = 1;
		p++;
	}
	while (*p && *p != ']') {
		if (p[1] == '-' && p[2] && p[2] != ']') {
			if (c >= p[0] && c <= p[2])
				ok = 1;
			p += 3;
		} else {
			if (c == *p)
				ok = 1;
			p++;
		}
	}
	if (*p == ']')
		p++;
	*pp = p;
	return neg ? !ok : ok;
}

int dz_osc_match(const char *p, const char *s)
{
	while (*p) {
		if (*p == '*') {
			p++;
			for (const char *q = s;; q++) {
				if (dz_osc_match(p, q))
					return 1;
				if (!*q || *q == '/')
					break;
			}
			return 0;
		}
		if (*p == '?') {
			if (!*s || *s == '/')
				return 0;
			p++;
			s++;
			continue;
		}
		if (*p == '[') {
			const char *pp = p;

			if (!*s || *s == '/' || !match_class(&pp, *s))
				return 0;
			p = pp;
			s++;
			continue;
		}
		if (*p == '{') {
			const char *e = strchr(p, '}');

			if (!e)
				return 0;
			for (const char *a = p + 1; a <= e;) {
				const char *c = a;
				size_t n;

				while (c < e && *c != ',')
					c++;
				n = (size_t)(c - a);
				if (strncmp(s, a, n) == 0 && dz_osc_match(e + 1, s + n))
					return 1;
				a = c + 1;
			}
			return 0;
		}
		if (*p != *s)
			return 0;
		p++;
		s++;
	}
	return *s == 0;
}

/* ---- building ------------------------------------------------------------- */
static int put_str(uint8_t *buf, size_t cap, size_t *n, const char *s)
{
	size_t l = strlen(s) + 1, pl = pad4(l);

	if (*n + pl > cap)
		return -1;
	memset(buf + *n, 0, pl);
	memcpy(buf + *n, s, l);
	*n += pl;
	return 0;
}

static int put32(uint8_t *buf, size_t cap, size_t *n, uint32_t v)
{
	if (*n + 4 > cap)
		return -1;
	wr32(buf + *n, v);
	*n += 4;
	return 0;
}

size_t dz_osc_vbuild(uint8_t *buf, size_t cap, const char *path, const char *tags,
		     va_list ap)
{
	char tt[DZ_OSC_MAX_ARGS + 2];
	size_t n = 0;

	if (strlen(tags) > DZ_OSC_MAX_ARGS)
		return 0;
	snprintf(tt, sizeof(tt), ",%s", tags);
	if (put_str(buf, cap, &n, path) || put_str(buf, cap, &n, tt))
		return 0;
	for (const char *t = tags; *t; t++) {
		int err = 0;

		if (*t == 'i') {
			err = put32(buf, cap, &n, (uint32_t)va_arg(ap, int));
		} else if (*t == 'f') {
			float f = (float)va_arg(ap, double);
			uint32_t u;

			memcpy(&u, &f, 4);
			err = put32(buf, cap, &n, u);
		} else if (*t == 's') {
			err = put_str(buf, cap, &n, va_arg(ap, const char *));
		} else {
			return 0;
		}
		if (err)
			return 0;
	}
	return n;
}

size_t dz_osc_build(uint8_t *buf, size_t cap, const char *path, const char *tags, ...)
{
	va_list ap;
	size_t n;

	va_start(ap, tags);
	n = dz_osc_vbuild(buf, cap, path, tags, ap);
	va_end(ap);
	return n;
}

size_t dz_osc_build_args(uint8_t *buf, size_t cap, const char *path,
			 const dz_arg *a, int na)
{
	char tt[DZ_OSC_MAX_ARGS + 2];
	size_t n = 0;
	int k = 0;

	if (na > DZ_OSC_MAX_ARGS)
		return 0;
	tt[k++] = ',';
	for (int i = 0; i < na; i++)
		tt[k++] = a[i].type;
	tt[k] = 0;
	if (put_str(buf, cap, &n, path) || put_str(buf, cap, &n, tt))
		return 0;
	for (int i = 0; i < na; i++) {
		int err;

		if (a[i].type == 'i') {
			err = put32(buf, cap, &n, (uint32_t)a[i].i);
		} else if (a[i].type == 'f') {
			uint32_t u;

			memcpy(&u, &a[i].f, 4);
			err = put32(buf, cap, &n, u);
		} else if (a[i].type == 's') {
			err = put_str(buf, cap, &n, a[i].s ? a[i].s : "");
		} else {
			return 0;
		}
		if (err)
			return 0;
	}
	return n;
}

void dz_osc_format(const dz_msg *m, char *out, size_t cap)
{
	size_t n = (size_t)snprintf(out, cap, "%s", m->path ? m->path : "?");

	for (int i = 0; i < m->n && n < cap; i++) {
		const dz_arg *a = &m->a[i];

		if (a->type == 'i')
			n += (size_t)snprintf(out + n, cap - n, " %d", a->i);
		else if (a->type == 'f')
			n += (size_t)snprintf(out + n, cap - n, " %g", (double)a->f);
		else
			n += (size_t)snprintf(out + n, cap - n, " \"%s\"", a->s);
	}
}

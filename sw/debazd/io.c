/*
 * io.c - user I/O lines PL_KEY0-5 by name (pin function select in the PL,
 * hw/rtl/pl_io; registers 0x43C6_0040, fields /io/func/<n>).
 *
 *   /io/pin i:line s:name    set the function of line 0..5 (or i:code)
 *   /io/pin i:line           -> /io/pin i:line s:name
 *   /io/pins                 -> /io/pins s:name0 ... s:name5
 * Names: in out scl sda sclk mosi miso cs0 txd rxd bclk lrclk dout din cs1.
 * scl/sda = PS I2C0 (/dev/i2c-0), sclk/mosi/miso/cs0/cs1 = PS SPI0
 * (/dev/spidev0.0/0.1), txd/rxd = PS UART0 (/dev/ttyPS1), bclk..din = the PL
 * I2S master (/i2s/...). "in" (the reset state) = input, as before.
 */
#include "debazd.h"
#include "dz_fields.h"

#include <stdio.h>
#include <string.h>

static const char *names[16] = {
	"in", "out", "scl", "sda", "sclk", "mosi", "miso", "cs0",
	"txd", "rxd", "bclk", "lrclk", "dout", "din", "cs1", "-"
};

static const dz_field *func_field(int line)
{
	char p[16];

	snprintf(p, sizeof(p), "/io/func/%d", line);
	return dz_field_find(p);
}

static const char *func_name(int line)
{
	uint32_t v;

	if (dz_field_read(func_field(line), &v) < 0)
		return "?";
	return names[v & 15];
}

int io_dispatch(const dz_msg *m)
{
	const dz_arg *a = m->a;

	if (!strcmp(m->path, "/io/pins")) {
		dzd_reply("/io/pins", "ssssss", func_name(0), func_name(1), func_name(2),
			  func_name(3), func_name(4), func_name(5));
		return 1;
	}
	if (strcmp(m->path, "/io/pin"))
		return 0;
	if (m->n < 1 || a[0].type != 'i' || a[0].i < 0 || a[0].i > 5) {
		dzd_reply("/error", "ss", "/io/pin needs a line 0..5", m->path);
		return 1;
	}
	if (m->n >= 2) {
		int code = -1;

		if (a[1].type == 's') {
			for (int k = 0; k < 15; k++)
				if (!strcmp(a[1].s, names[k]))
					code = k;
		} else if (a[1].type == 'i' && a[1].i >= 0 && a[1].i < 15)
			code = a[1].i;
		if (code < 0) {
			dzd_reply("/error", "ss", "unknown function (in out scl sda sclk mosi miso cs0 txd rxd bclk lrclk dout din cs1)", m->path);
			return 1;
		}
		if (dz_field_write(func_field(a[0].i), (uint32_t)code) < 0) {
			dzd_reply("/error", "ss", "no user I/O block in this bitstream", m->path);
			return 1;
		}
	}
	dzd_reply("/io/pin", "is", a[0].i, func_name(a[0].i));
	return 1;
}

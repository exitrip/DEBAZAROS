/*
 * oscreg - OSC control surface for the DEBAZAROS PL register map.
 *
 * One table maps an OSC address to one bit field of one AXI register.
 * Everything else (UDP, OSC parsing, /dev/mem or UIO mapping) is generic,
 * so a gateware change means editing the table below and nothing else.
 *
 * Argument rules, uniform across every endpoint:
 *   int   ('i')  = raw register value, clamped to the field width
 *   float ('f')  = 0.0 .. 1.0 across the whole field
 *                  (OSCREG_HZ takes Hz instead, OSCREG_BOOL takes 0/1)
 *   T / F        = 1 / 0
 *   OSCREG_RGB fields also accept three args = R, G, B
 *
 * Queries (reply goes back to the sender):
 *   /get   s <path>     ->  /value  s <path>  i <raw>  f <normalized>
 *   /list                ->  one /entry s <path> s <help> per endpoint
 *   /ping                ->  /pong
 *
 * OSC wildcards ? * [] {} work in incoming addresses, so
 *   /mixer/[0-8]/mode 35      sets the mode of all nine mixer channels.
 */
#ifndef OSCREG_H
#define OSCREG_H

#include <signal.h>
#include <stddef.h>
#include <stdint.h>

/* ---- peripheral bases (PS view).  Keep in step with CLAUDE.md. ---- */
#define OSCREG_HDMI0_HPD_BASE	0x41200000u	/* axi_gpio_hdmi   */
#define OSCREG_HDMI0_GAIN_BASE	0x41210000u	/* colorGainMain   */
#define OSCREG_HDMI1_HPD_BASE	0x41220000u
#define OSCREG_HDMI1_GAIN_BASE	0x41230000u	/* dual: +0 video, +8 DDS layer */
#define OSCREG_LED_BASE		0x41240000u
#define OSCREG_HDMI1_FB_BASE	0x41260000u	/* dual: +0 ch1, +8 ch2 */
#define OSCREG_MIXER0_BASE	0x43C50000u
#define OSCREG_DDS0_BASE	0x43D00000u
#define OSCREG_DDS0_SHIFT_BASE	0x43D10000u
#define OSCREG_DDS1_BASE	0x44D00000u
#define OSCREG_DDS1_SHIFT_BASE	0x44D10000u

#define OSCREG_MAP_SIZE		0x10000u	/* one 64K page per peripheral */

/* AXI GPIO channel data registers */
#define OSCREG_GPIO_CH1		0x0u
#define OSCREG_GPIO_CH2		0x8u

/* mixer 2.0: register index = chan*10 + n, byte offset = index*4 */
#define OSCREG_MIX_REG(chan, n)	((((chan) * 10u) + (n)) * 4u)
#define OSCREG_MIX_CHANS	9
#define OSCREG_MIX_GAINS	5	/* n = 0..4 -> din0..din4 */
#define OSCREG_MIX_CTRL0	8	/* [7:0] mode, [31:16] constant K   */
#define OSCREG_MIX_CTRL1	9	/* [0] stream sel, [23:16] lo, [31:24] hi */

/* dds_axi_interface: one 32-bit register at +0 */
#define OSCREG_DDS_CTRL		0x0u	/* [31] TVALID enable, [30:0] phase inc */
#define OSCREG_DDS_STATUS	0x10u	/* [0] TVALID readback */
#define OSCREG_DDS_CLK_HZ	100000000.0	/* dds_compiler clock  */
#define OSCREG_DDS_PHASE_BITS	32		/* phase accumulator   */

/* ---- field descriptors ---- */
typedef enum {
	OSCREG_RAW = 0,	/* float 0..1 spans the field                 */
	OSCREG_BOOL,	/* float/int != 0                             */
	OSCREG_HZ,	/* float is Hz, converted to a phase increment */
	OSCREG_RGB	/* 24-bit packed R,G,B; accepts three args     */
} oscreg_unit;

typedef struct {
	const char *path;	/* OSC address                       */
	uint32_t    base;	/* peripheral base address           */
	uint32_t    off;	/* byte offset inside the peripheral */
	uint8_t     lo;		/* lowest bit of the field           */
	uint8_t     width;	/* field width in bits               */
	uint8_t     unit;	/* oscreg_unit                       */
	uint8_t     ro;		/* 1 = read only                     */
	const char *help;
} oscreg_field;

/* One decoded OSC argument.  T and F arrive as type 'i' with i = 1 or 0. */
typedef struct {
	char        type;	/* 'i', 'f' or 's' */
	int         i;
	float       f;
	const char *s;
} oscreg_arg;

/* Handler for addresses that match no field, e.g. the oscdraw layer.
 * Returns the number of operations performed, 0 if the address is not its own. */
typedef int (*oscreg_handler)(const char *path, const oscreg_arg *args,
			      int nargs, int verbose);
void oscreg_set_handler(oscreg_handler h);

#define OSCREG_MAX_ARGS	24

/* ---- API ---- */

/* Build the endpoint table only.  No hardware is touched; safe for listing. */
void oscreg_build(void);

/* simulate != 0 maps plain RAM instead of hardware, for testing off-target. */
int  oscreg_init(int simulate);
void oscreg_close(void);

int                 oscreg_count(void);
const oscreg_field *oscreg_at(int index);
const oscreg_field *oscreg_find(const char *path);

int  oscreg_read(const oscreg_field *f, uint32_t *raw);
int  oscreg_write(const oscreg_field *f, uint32_t raw);

uint32_t oscreg_from_float(const oscreg_field *f, float v);
float    oscreg_to_float(const oscreg_field *f, uint32_t raw);

/* Handle one UDP payload (message or bundle) with no reply path. */
int  oscreg_handle(const void *pkt, size_t len, int verbose);

/* Blocking UDP server.  Returns when oscreg_stop is set. */
int  oscreg_serve(int port, int verbose);

extern volatile sig_atomic_t oscreg_stop;

#endif /* OSCREG_H */

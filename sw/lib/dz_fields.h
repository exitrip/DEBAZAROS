/*
 * dz_fields.h - named bit fields of the PL control registers.
 *
 * One table entry = one bit field of one AXI register, with an OSC-style
 * path. The table was traced from the block design (Oct 2026): for every AXI
 * GPIO output, which xlslice takes which bits and which IP pin they drive.
 *
 * Value rules, the same for every field:
 *   int   = raw field value (clamped to the field width)
 *   float = 0.0 .. 1.0 across the field (DZ_HZ: Hz; DZ_BOOL: != 0)
 *   DZ_RGB fields take 1 value (grey) or 3 values (r, g, b)
 *
 * Writes are read-modify-write against the hardware. Every register here
 * reads back its last written value (verified on the board), so other
 * writers (debazarosit.sh, devmem) never fight a stale copy.
 */
#ifndef DZ_FIELDS_H
#define DZ_FIELDS_H

#include <stdint.h>

typedef enum {
	DZ_RAW = 0,	/* float 0..1 spans the field                     */
	DZ_BOOL,	/* any non-zero value = 1                         */
	DZ_HZ,		/* value in Hz -> DDS phase increment             */
	DZ_RGB		/* [23:0] three gain bytes in display lane order  */
} dz_unit;

enum {
	DZ_F_RO  = 1u << 0,	/* read only                                   */
	DZ_F_DDS = 1u << 1,	/* also set bit 31 (TVALID): the DDS ignores a
				 * phase increment written without it         */
};

typedef struct {
	const char *path;
	uint32_t    base;	/* register block (hw_map.h)        */
	uint32_t    off;	/* byte offset in the block         */
	uint8_t     lo;		/* lowest bit of the field          */
	uint8_t     width;	/* bits                             */
	uint8_t     unit;	/* dz_unit                          */
	uint8_t     flags;	/* DZ_F_*                           */
	const char *help;
} dz_field;

/* One OSC-style argument. T/F arrive as 'i' 1/0. */
typedef struct {
	char        type;	/* 'i', 'f', 's' */
	int32_t     i;
	float       f;
	const char *s;
} dz_arg;

void            dz_fields_build(void);	/* idempotent, touches no hardware */
int             dz_fields_count(void);
const dz_field *dz_field_at(int i);
const dz_field *dz_field_find(const char *path);

uint32_t dz_field_mask(const dz_field *f);
int      dz_field_read(const dz_field *f, uint32_t *raw);	/* 0 or -1 */
int      dz_field_write(const dz_field *f, uint32_t raw);	/* 0, -1, -2 = read only */
/* Apply OSC-style arguments (rules above). Returns 0 or < 0. */
int      dz_field_set(const dz_field *f, const dz_arg *a, int n, uint32_t *raw_out);

uint32_t dz_field_from_float(const dz_field *f, float v);
float    dz_field_to_float(const dz_field *f, uint32_t raw);

/* DDS: phase accumulator 32 bit, clocked by FCLK0 = 100 MHz. */
#define DZ_DDS_CLK_HZ	100000000.0

#endif /* DZ_FIELDS_H */

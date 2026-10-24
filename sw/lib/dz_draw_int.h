/*
 * dz_draw_int.h - internal surface access for the sw/lib drawing modules
 * (dz_sprite.c, dz_xform.c, dz_text.c). Not for programs.
 */
#ifndef DZ_DRAW_INT_H
#define DZ_DRAW_INT_H

#include <stddef.h>
#include <stdint.h>

/* Painting buffer of surface (slot) i: w*h a8r8g8b8 words, allocated on
 * first use. NULL for a bad slot. Stops a movie that plays into the slot. */
uint32_t *dz_surf(int i, int *w, int *h);
/* One pixel with the surface alpha and blend mode, scaled by cov (0..256). */
void dz_surf_put(int i, uint32_t *p, uint32_t v, unsigned cov);
/* Mark a changed area (x1/y1 exclusive), then present if auto-present is on. */
void dz_surf_dirty(int i, int x0, int y0, int x1, int y1);
void dz_surf_finish(int i);
/* 1 if the surface draws plainly (alpha 1, blend normal): copy without put. */
int dz_surf_plain(int i);
/* Replace the painting buffer of surface i with buf (same size); returns the
 * old buffer, which the caller now owns. */
uint32_t *dz_surf_swap(int i, uint32_t *buf);
/* Slot memory of surface i when auto-present is on (row-wise present while a
 * row is in cache), else NULL. Also flushes pending dirty work first. */
uint8_t *dz_surf_dev(int i, size_t *stride);
/* Forget the dirty area: the caller has presented everything itself. */
void dz_surf_clean(int i);
/* Count a failed operation for dz_draw_take_fails. */
void dz_surf_fail(void);

#endif

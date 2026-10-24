/*
 * dz_sprite.h - sprites: images in RAM, drawn into any slot with position,
 * scale, rotation and alpha. Per-pixel alpha is kept (PNG transparency, text).
 *
 * OSC (<id> = 0..63, <s> = slot):
 *   /sprite/<id>/load  "file" [w h]        image from DZ_IMG_DIR (ffmpeg decodes;
 *                                          png/jpg/gif/...; w h = resize)
 *   /sprite/<id>/grab  s x y w h           copy a rectangle of slot s (what is
 *                                          in DDR now: capture, movie, ...)
 *   /sprite/<id>/text  r g b "text" [scale] [font 16|32]   pixel-font text
 *   /sprite/<id>/ttf   r g b size "text" ["font file"]     anti-aliased text
 *   /sprite/<id>/key   r g b [tolerance]   that colour becomes transparent
 *   /sprite/<id>/draw  s x y [scale] [angle] [alpha]
 *                      centred at x,y; angle in degrees; nearest-neighbour;
 *                      uses the target surface's blend mode (/draw/<s>/blend)
 *   /sprite/<id>/free
 *   /sprite/<id>                           -> /sprite/<id> i:w i:h (debazd)
 */
#ifndef DZ_SPRITE_H
#define DZ_SPRITE_H

#include <stdint.h>
#include "dz_osc.h"

#define DZ_SPRITES	64
#define DZ_SPRITE_MAX	2048		/* max width or height */

int  dz_sprite_load(int id, const char *name, int w, int h);
int  dz_sprite_grab(int id, int slot, int x, int y, int w, int h);
/* take ownership of px (malloc'd, w*h a8r8g8b8 with alpha) */
int  dz_sprite_set(int id, int w, int h, uint32_t *px);
int  dz_sprite_key(int id, uint8_t r, uint8_t g, uint8_t b, int tol);
int  dz_sprite_draw(int id, int slot, float cx, float cy, float scale, float angle,
		    float alpha);
int  dz_sprite_size(int id, int *w, int *h);
void dz_sprite_free(int id);

/* /sprite/... except the query. Returns operations done, 0 = not ours. */
int  dz_sprite_dispatch(const dz_msg *m, int verbose);

#endif

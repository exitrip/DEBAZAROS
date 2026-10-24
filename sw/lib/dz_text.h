/*
 * dz_text.h - text: a pixel font (dz pixel font, from Terminus Font, OFL)
 * and anti-aliased TrueType text (stb_truetype, fonts from DZ_FONT_DIR).
 *
 * OSC (<s> = slot):
 *   /draw/<s>/text r g b x y "text" [scale] [font 16|32]
 *        pixel font, top-left at x,y, integer scale; "\n" = new line
 *   /draw/<s>/ttf  r g b x y size "text" ["font file"]
 *        anti-aliased; size in pixels; x,y = top-left; default font
 *        DZ_FONT_DEFAULT; "font file" = a file name under DZ_FONT_DIR
 * Text sprites: /sprite/<id>/text and /sprite/<id>/ttf (dz_sprite.h).
 */
#ifndef DZ_TEXT_H
#define DZ_TEXT_H

#include "dz_draw.h"

#ifndef DZ_FONT_DIR
#define DZ_FONT_DIR	"/usr/share/fonts"
#endif
#ifndef DZ_FONT_DEFAULT
#define DZ_FONT_DEFAULT	"LiberationSans-Regular.ttf"
#endif

int dz_text_draw(int slot, dz_color c, int x, int y, const char *s, int scale, int font);
int dz_ttf_draw(int slot, dz_color c, int x, int y, float px, const char *s,
		const char *font);
/* render into sprite id: text colour c, transparent background */
int dz_text_sprite(int id, dz_color c, const char *s, int scale, int font);
int dz_ttf_sprite(int id, dz_color c, float px, const char *s, const char *font);

#endif

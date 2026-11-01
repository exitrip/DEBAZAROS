/*
 * dz_text.h - text: a pixel font (dz pixel font, from Terminus Font, OFL)
 * and anti-aliased TrueType text (stb_truetype, fonts from DZ_FONT_DIR).
 *
 * OSC (<s> = slot):
 *   /draw/<s>/text r g b x y "text" [scale] [font 16|32] [angle]
 *        pixel font, top-left at x,y, integer scale; "\n" = new line
 *   /draw/<s>/ttf  r g b x y size "text" ["font file"] [angle]
 *        anti-aliased; size in pixels; x,y = top-left; default font
 *        DZ_FONT_DEFAULT; "font file" = a file name under DZ_FONT_DIR
 *   (ttf text is UTF-8: a character the font lacks comes from the first
 *    fallback that has it: DejaVuSans, FreeSerif, DroidSansFallbackFull;
 *    sw/tools/pushfonts.sh puts them on a board. The pixel font is ASCII
 *    32..126 only)
 *   angle: degrees, clockwise, about the centre of the text (as dz_shape);
 *        x,y stay the top-left of the text before the rotation
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
int dz_text_draw_rot(int slot, dz_color c, int x, int y, const char *s, int scale, int font,
		     float angle);
int dz_ttf_draw_rot(int slot, dz_color c, int x, int y, float px, const char *s,
		    const char *font, float angle);
/* render into sprite id: text colour c, transparent background */
int dz_text_sprite(int id, dz_color c, const char *s, int scale, int font);
int dz_ttf_sprite(int id, dz_color c, float px, const char *s, const char *font);

/* one glyph scaled into a cw x ch cell, coverage 0..255 (debazd ascii.c):
 * 0, -1 = no font, -2 = no such glyph (mask cleared) */
int dz_ttf_glyph(const char *font, uint32_t cp, int cw, int ch, uint8_t *mask);
int dz_font_glyph(uint32_t cp, int cw, int ch, uint8_t *mask);	/* pixel font */

#endif

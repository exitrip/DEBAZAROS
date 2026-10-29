/*
 * dz_draw.h - drawing and playback into the DDR frame slots.
 * (Moved from sw/oscreg/oscdraw; same model and operations.)
 *
 * A surface is one DDR slot (0..DZ_SLOTS-1), not one display: which slot a
 * display shows is a separate choice (dz_disp_show, OSC /disp/<d>/show).
 * Draw into a slot that no display shows, then show it: no tearing.
 *
 * Each surface owns a cached shadow buffer in normal RAM, allocated on first
 * use. Drawing writes the shadow; present copies the changed rectangle to the
 * slot (uncached or write-combined memory: slow to read, slow in small
 * pieces). Auto-present is on by default.
 *
 * OSC addresses (<s> = slot number or *):
 *   /draw/<s>/solid            r g b [x y w h]
 *   /draw/<s>/clear            [r g b]
 *   /draw/<s>/bars                         (8 colour bars: test pattern)
 *   /draw/<s>/gradient/h       r1 g1 b1 r2 g2 b2 [x y w h]
 *   /draw/<s>/gradient/v       r1 g1 b1 r2 g2 b2 [x y w h]
 *   /draw/<s>/gradient/angle   deg r1 g1 b1 r2 g2 b2 [x y w h]
 *   /draw/<s>/gradient/corners tl(3) tr(3) bl(3) br(3) [x y w h]
 *   /draw/<s>/rect             r g b x y w h [thickness] [angle]
 *   /draw/<s>/square           r g b x y size [thickness] [angle]
 *   /draw/<s>/circle           r g b cx cy radius [thickness]
 *   /draw/<s>/ellipse          r g b cx cy rx ry [thickness] [angle]
 *   /draw/<s>/polygon, /star, /starpoly, /fill, /gradient/radial: dz_shape.h
 *   /draw/<s>/line             r g b x0 y0 x1 y1 [width]   (1 = thin, else round)
 *   /draw/<s>/brush            r g b x y radius [hardness] (soft stamp, 0..1)
 *   /draw/<s>/stroke           r g b radius hardness x0 y0 x1 y1 [x y ...]
 *   /draw/<s>/fade             amount [r g b]   (pull all pixels toward a colour
 *                                                by amount 0..1: trails)
 *   /draw/<s>/alpha            a          (0..1, for later draws)
 *   /draw/<s>/blend            normal|add|lighten|multiply (or 0..3)
 *   /img/<s>/load              "name" [x y w h]     (file in DZ_IMG_DIR)
 *   /movie/<s>/play            "name" [fps] [audio] (file in DZ_MOVIE_DIR; fps
 *                                         caps the frame rate: dropped frames
 *                                         are not scaled, piped or converted,
 *                                         only decoded; 0 = the file's rate.
 *                                         audio = outputs for the audio track:
 *                                         1 HDMI 0, 2 HDMI 1, 3 both, 4 I2S;
 *                                         0 / none = no audio)
 *   /movie/<s>/stop
 *   /surface/<s>/present
 *   /surface/<s>/auto          0|1
 *   /surface/<s>/save          "name"     (the shadow as name.png in DZ_IMG_DIR,
 *                                         ready about 1 s later; "x.ppm" = PPM
 *                                         at once). Load it back: /img/<s>/load
 *   /surface/<s>/grab          [src]      copy slot src (default s) into the
 *                                         painting buffer: freeze the capture
 *                                         or a movie frame, then paint on it
 *   /surface/<s>/peek          x y        -> /pixel s x y r g b (debazd)
 *
 * Colours: float 0..1 or int 0..255. No rectangle = whole surface.
 * thickness 0 or absent = filled.
 */
#ifndef DZ_DRAW_H
#define DZ_DRAW_H

#include <stdint.h>
#include "dz_osc.h"

#ifndef DZ_FBFEED
#define DZ_FBFEED	"/home/ebaz/bin/fbfeed"
#endif
/* media folders (2026-10-28): on the exFAT media partition (label
 * DEBAZMEDIA, mounted by debaz-firstboot / fstab); without it /media/debaz
 * is a plain folder on the root file system. /home/ebaz/{img,movies,audio}
 * are symlinks here (old paths keep working). */
#ifndef DZ_MEDIA_DIR
#define DZ_MEDIA_DIR	"/media/debaz"
#endif
#ifndef DZ_MOVIE_DIR
#define DZ_MOVIE_DIR	DZ_MEDIA_DIR "/movies"
#endif
#ifndef DZ_AUDIO_DIR
#define DZ_AUDIO_DIR	DZ_MEDIA_DIR "/audio"
#endif
#ifndef DZ_IMG_DIR
#define DZ_IMG_DIR	DZ_MEDIA_DIR "/img"
#endif

typedef struct { int x, y, w, h; } dz_rect;	/* w == 0: whole surface */

typedef enum {
	DZ_BLEND_NORMAL = 0,	/* mix by alpha                       */
	DZ_BLEND_ADD,		/* add light, clamp: light painting   */
	DZ_BLEND_LIGHTEN,	/* keep the brighter channel          */
	DZ_BLEND_MULTIPLY,	/* darken: d * v / 255                */
} dz_blend;
typedef struct { uint8_t r, g, b; } dz_color;

#define DZ_ALL		((dz_rect){ 0, 0, 0, 0 })
#define DZ_RGB8(R, G, B) ((dz_color){ (uint8_t)(R), (uint8_t)(G), (uint8_t)(B) })

void dz_draw_close(void);

void dz_draw_set_alpha(int s, float a);
void dz_draw_set_auto(int s, int on);
int  dz_draw_present(int s);		/* changed area only */
int  dz_draw_present_all(int s);	/* whole surface */

int  dz_draw_solid(int s, dz_color c, dz_rect r);
int  dz_draw_bars(int s);
int  dz_draw_gradient(int s, dz_color a, dz_color b, float degrees, dz_rect r);
int  dz_draw_corners(int s, dz_color tl, dz_color tr, dz_color bl, dz_color br,
		     dz_rect r);
int  dz_draw_rect(int s, dz_color c, dz_rect r, int thickness);
int  dz_draw_ellipse(int s, dz_color c, int cx, int cy, int rx, int ry,
		     int thickness);
int  dz_draw_line(int s, dz_color c, int x0, int y0, int x1, int y1, int width);
int  dz_draw_brush(int s, dz_color c, int x, int y, int radius, float hardness);
int  dz_draw_stroke(int s, dz_color c, int radius, float hardness,
		    const int *xy, int npts);
int  dz_draw_fade(int s, float amount, dz_color to);
void dz_draw_set_blend(int s, int mode);
int  dz_draw_grab(int s, int src_slot);
int  dz_draw_peek(int s, int x, int y, dz_color *c);
int  dz_draw_image(int s, const char *name, dz_rect r);
int  dz_draw_movie_play(int s, const char *name);
int  dz_draw_movie_play_fps(int s, const char *name, float fps);	/* 0 = no cap */
int  dz_draw_movie_play_av(int s, const char *name, float fps, int audio);	/* + audio to DEBAZ */
int  dz_draw_movie_stop(int s);
int  dz_draw_movie_running(int s);	/* reaps a finished player */
int  dz_draw_save(int s, const char *name);

/* Number of operations that failed since the last call (e.g. a slot outside
 * reserved memory), then reset to 0. */
int  dz_draw_take_fails(void);

/* OSC front end: number of operations done, 0 if the address is not ours. */
int  dz_draw_dispatch(const dz_msg *m, int verbose);

#endif /* DZ_DRAW_H */

/*
 * oscdraw - drawing and playback layer for the DEBAZAROS frame slots.
 *
 * Companion to oscreg.  oscreg drives PL registers; oscdraw fills the DDR
 * frame slots that the VDMAs scan out.  Both answer on the same UDP port.
 *
 * Every operation is a plain C function first and an OSC address second, so
 * a script, a GPIO poller or a future sequencer can call the same entry
 * points without going through the network.
 *
 * Model
 *   A surface is one VDMA frame slot.  Each surface owns a cached shadow
 *   buffer in normal RAM.  Drawing writes the shadow.  present() copies the
 *   changed rectangle to the slot, which is uncached or write-combined
 *   memory that is slow to read and slow to touch in small pieces.
 *   Auto-present is on by default, so single commands appear immediately.
 *
 * OSC addresses (surface index, or * for all)
 *   /draw/<s>/solid            r g b [x y w h]
 *   /draw/<s>/gradient/h       r1 g1 b1 r2 g2 b2 [x y w h]
 *   /draw/<s>/gradient/v       r1 g1 b1 r2 g2 b2 [x y w h]
 *   /draw/<s>/gradient/angle   deg r1 g1 b1 r2 g2 b2 [x y w h]
 *   /draw/<s>/gradient/corners tl(3) tr(3) bl(3) br(3) [x y w h]
 *   /draw/<s>/rect             r g b x y w h [thickness]
 *   /draw/<s>/square           r g b x y size [thickness]
 *   /draw/<s>/circle           r g b cx cy radius [thickness]
 *   /draw/<s>/ellipse          r g b cx cy rx ry [thickness]
 *   /draw/<s>/alpha            a            (0..1, applies to later draws)
 *   /draw/<s>/clear            [r g b]
 *   /img/<s>/load              "name" [x y w h]
 *   /movie/<s>/play            "name"
 *   /movie/<s>/stop
 *   /surface/<s>/present
 *   /surface/<s>/auto          0|1
 *   /surface/<s>/save          "name"       (PPM snapshot, for debugging)
 *
 * Colour arguments follow the oscreg rule: float = 0..1, int = 0..255.
 * A missing rectangle means the whole surface, so "solid" covers both
 * "paint the screen" and "paint a box".  thickness 0 or absent = filled.
 */
#ifndef OSCDRAW_H
#define OSCDRAW_H

#include <stdint.h>
#include "oscreg.h"

/* Frame slots, matching hdmi2.elf: pitch = DEMO_MAX_FRAME = 1920*1080*4. */
#define OSCDRAW_FB_BASE		0x08000000u
#define OSCDRAW_SLOT_PITCH	(1920u * 1080u * 4u)
#define OSCDRAW_SURFACES	4	/* disp0 = 0,1   disp1 = 2,3 */
#define OSCDRAW_WIDTH		1280
#define OSCDRAW_HEIGHT		720

/* External helpers, both optional at run time.  Override with -D at build. */
#ifndef OSCDRAW_FBFEED
#define OSCDRAW_FBFEED		"/home/ebaz/fbfeed"
#endif
#ifndef OSCDRAW_MOVIE_DIR
#define OSCDRAW_MOVIE_DIR	"/home/ebaz/movies"
#endif
#ifndef OSCDRAW_IMG_DIR
#define OSCDRAW_IMG_DIR		"/home/ebaz/img"
#endif

typedef struct {
	int x, y, w, h;		/* w == 0 means "the whole surface" */
} od_rect;

typedef struct {
	uint8_t r, g, b;
} od_color;

#define OD_ALL		((od_rect){ 0, 0, 0, 0 })
#define OD_RGB(R, G, B)	((od_color){ (uint8_t)(R), (uint8_t)(G), (uint8_t)(B) })

int  oscdraw_init(int simulate);
void oscdraw_close(void);

int  oscdraw_count(void);
int  oscdraw_width(int s);
int  oscdraw_height(int s);

void oscdraw_set_alpha(int s, float a);
void oscdraw_set_auto(int s, int on);
int  oscdraw_present(int s);

int  oscdraw_solid(int s, od_color c, od_rect r);
int  oscdraw_gradient(int s, od_color a, od_color b, float degrees, od_rect r);
int  oscdraw_corners(int s, od_color tl, od_color tr, od_color bl, od_color br,
		     od_rect r);
int  oscdraw_rect(int s, od_color c, od_rect r, int thickness);
int  oscdraw_ellipse(int s, od_color c, int cx, int cy, int rx, int ry,
		     int thickness);

int  oscdraw_image(int s, const char *name, od_rect r);
int  oscdraw_movie_play(int s, const char *name);
int  oscdraw_movie_stop(int s);
int  oscdraw_save(int s, const char *name);

/* OSC front end.  Returns the number of operations performed, 0 if the
 * address belongs to somebody else. */
int  oscdraw_dispatch(const char *path, const oscreg_arg *a, int n, int verbose);

#endif /* OSCDRAW_H */

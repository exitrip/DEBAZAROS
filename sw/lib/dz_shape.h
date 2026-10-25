/*
 * dz_shape.h - rotated and gradient-filled shapes: rect, ellipse, regular
 * polygon, star, star polygon. Antialiased scanline fill (4 sub-lines).
 *
 * OSC (<s> = slot, handled in dz_draw.c):
 *   /draw/<s>/fill      solid                       (default)
 *   /draw/<s>/fill      linear r2 g2 b2 [deg]       colour 1 -> colour 2 across
 *                                                   the shape (deg in the shape's
 *                                                   own frame, 0 = left to right)
 *   /draw/<s>/fill      radial r2 g2 b2             colour 1 at the centre ->
 *                                                   colour 2 at the edge
 *     The fill stays set for later shapes on that slot, as /alpha and /blend.
 *     Colour 1 = the r g b of each shape. Shapes only (not solid/clear).
 *   /draw/<s>/rect      r g b x y w h [thickness] [angle]
 *   /draw/<s>/square    r g b x y size [thickness] [angle]
 *   /draw/<s>/ellipse   r g b cx cy rx ry [thickness] [angle]
 *   /draw/<s>/polygon   r g b cx cy rx ry sides [thickness] [angle]
 *   /draw/<s>/star      r g b cx cy rx ry points [inner] [thickness] [angle]
 *        inner = inner radius / outer radius (0 or absent = the classic
 *        star: the outline of the {points/2} star polygon)
 *   /draw/<s>/starpoly  r g b cx cy rx ry n k [thickness] [angle]
 *        the star polygon {n/k}: join every k-th of n points. {5/2} =
 *        pentagram, {6/2} = star of David (two triangles), {7/3}, ...
 *        When n and k have a common factor, it is several closed loops.
 *        Filled: even-odd rule (the points fill, the centre stays open).
 *   /draw/<s>/gradient/radial  r1 g1 b1 r2 g2 b2 [cx cy radius]  whole slot
 *
 * angle in degrees, clockwise (screen y points down), about the shape centre.
 * thickness 0 or absent = filled. An outline lies inside the shape size.
 * Polygons and stars point up (first point at the top).
 */
#ifndef DZ_SHAPE_H
#define DZ_SHAPE_H

#include "dz_draw.h"

enum { DZ_FILL_SOLID = 0, DZ_FILL_LINEAR, DZ_FILL_RADIAL };

void dz_shape_fill(int s, int mode, dz_color c2, float degrees);
/* 1 if a shape on slot s needs the new rasterizer (fill not solid) */
int  dz_shape_fancy(int s);

int  dz_shape_rect(int s, dz_color c, float x, float y, float w, float h, int t, float angle);
int  dz_shape_ellipse(int s, dz_color c, float cx, float cy, float rx, float ry, int t, float angle);
int  dz_shape_polygon(int s, dz_color c, float cx, float cy, float rx, float ry, int sides,
		      int t, float angle);
int  dz_shape_star(int s, dz_color c, float cx, float cy, float rx, float ry, int points,
		   float inner, int t, float angle);
int  dz_shape_starpoly(int s, dz_color c, float cx, float cy, float rx, float ry, int n, int k,
		       int t, float angle);
int  dz_shape_radial(int s, dz_color a, dz_color b, float cx, float cy, float radius);

#endif

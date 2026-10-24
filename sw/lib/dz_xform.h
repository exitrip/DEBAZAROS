/*
 * dz_xform.h - image transforms on a surface's painting buffer.
 * src = another surface (slot) to read from, or the target itself (default):
 * the source is copied first, so a surface can transform itself (feedback).
 * Out-of-range source positions wrap around (tiling).
 *
 * OSC (<s> = target slot):
 *   /draw/<s>/transform a b c d e f [src]  general affine map, target pixel
 *        (x,y) reads source (a*x + b*y + c, d*x + e*y + f)
 *   /draw/<s>/rotozoom  angle zoom [cx cy] [src]   rotate (degrees) and zoom
 *        (> 1 = larger) about cx,cy (default: centre)
 *   /draw/<s>/scroll    dx dy [src]        shift with wrap-around
 *   /draw/<s>/mirror    h|v|quad           left half -> right, top -> bottom,
 *                                          or both (4-way kaleidoscope)
 *   /draw/<s>/wave      axis amp period phase [src]   sine displacement:
 *        axis 0 = rows shift sideways, 1 = columns shift up/down; amp and
 *        period in pixels, phase 0..1 (animate it with an LFO)
 */
#ifndef DZ_XFORM_H
#define DZ_XFORM_H

int dz_xform_affine(int dst, int src, const float m[6]);
int dz_xform_rotozoom(int dst, int src, float angle, float zoom, float cx, float cy);
int dz_xform_scroll(int dst, int src, int dx, int dy);
int dz_xform_mirror(int dst, int mode);	/* 0 h, 1 v, 2 quad */
int dz_xform_wave(int dst, int src, int axis, float amp, float period, float phase);

#endif

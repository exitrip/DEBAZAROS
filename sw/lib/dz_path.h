/*
 * dz_path.h - where the DEBAZAROS programs and web files are (2026-11-01).
 *
 * Two installs can be on one card: the image (PetaLinux recipe debaz-sw:
 * /usr/bin, /usr/share/debaz/www) and a development copy (`make -C sw
 * install`: /home/ebaz/bin, /home/ebaz/www). The development copy wins, so
 * `make install` works on an image as before; remove /home/ebaz/bin to go
 * back to the image's programs.
 */
#ifndef DZ_PATH_H
#define DZ_PATH_H

/*
 * Persistent, changing files (2026-11-19) go to the data partition
 * (DEBAZDATA, ext4, LABEL mount on /data; debaz-firstboot makes it), never
 * to the root file system, which becomes read-only later (ROADMAP.md
 * section 10):
 *   /data/shows/<show>/       shows (cue.c; $DZ_SHOW_DIR = another place)
 *   /data/debaz/dzstart.conf  per-card bring-up settings (dzstart.sh,
 *                             dzrun.sh; the old /home/ebaz/dzstart.conf is
 *                             copied there once)
 * Media: /media/debaz (DEBAZMEDIA, exFAT). Run-time state: /run/debaz (RAM).
 */
#define DZ_DATA_DIR	"/data"
#define DZ_SHOW_SUBDIR	DZ_DATA_DIR "/shows"

#define DZ_DEV_BIN	"/home/ebaz/bin"
#define DZ_IMG_BIN	"/usr/bin"
#define DZ_DEV_WWW	"/home/ebaz/www"
#define DZ_IMG_WWW	"/usr/share/debaz/www"

/* full path of program name: $DZ_BIN/name, DZ_DEV_BIN/name, DZ_IMG_BIN/name
 * (the first that is executable), else name itself (PATH). The string stays
 * valid (one cached entry per name). */
const char *dz_prog(const char *name);

/* the web app folder: DZ_DEV_WWW if it has an index.html, else DZ_IMG_WWW */
const char *dz_www_dir(void);

#endif

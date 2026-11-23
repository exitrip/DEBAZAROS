/*
 * dz_ain.h - audio into dzaudio (2026-11-22): the stream inputs of dzaudio's
 * matrix, for the players of debazd (movie audio, /audio/play).
 *
 * While dzaudio runs it holds hw:DEBAZ,0 and 1 (one owner per PCM): a movie's
 * audio ffmpeg could not open them and played nothing. Now dzaudio has
 * DZA_STREAMS stereo stream inputs, each a FIFO DZA_FIFO (S16LE 48 kHz
 * stereo) that dzaudio makes and keeps open; a player writes there instead
 * of the PCM, and /mix/stream <n> <devmask> routes the stream to the outputs
 * of those DEBAZ devices (bit d = hw:DEBAZ,d). Without dzaudio (no reader on
 * the FIFO) the players open the PCM as before.
 *   streams 0..11  movie audio of slot 0..11
 *   streams 12..14 /audio/play on out 0, 1, 2 (HDMI 0, HDMI 1, I2S)
 */
#ifndef DZ_AIN_H
#define DZ_AIN_H

#include <stddef.h>

#define DZA_STREAMS	16
#define DZA_FIFO	"/tmp/dzin.%d"
#define DZA_PORT	9002
#define DZA_SOUND	12		/* + out: /audio/play streams */

/* 1 when dzaudio reads stream n (its FIFO has a reader) */
int dz_ain_ready(int n);
/* route stream n to the DEBAZ devices in devmask (0 = off); UDP to dzaudio */
void dz_ain_route(int n, unsigned devmask);
/* the owner of DEBAZ playback device dev when it is open: "1234 dzaudio",
 * returns 1 (busy) / 0 (closed or unknown) */
int dz_pcm_owner(int dev, char *who, size_t n);

#endif

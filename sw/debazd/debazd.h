/*
 * debazd.h - internal interface between the debazd modules.
 */
#ifndef DEBAZD_H
#define DEBAZD_H

#include "dz_osc.h"

/* Reply to the sender of the message being handled. No-op for messages
 * that the daemon sends to itself (LFO templates, sequencers). */
void dzd_reply(const char *path, const char *tags, ...);

/* Log line when debazd runs with -v. */
void dzd_log(const char *fmt, ...);

/* Handle one message as if it came from the network, without replies.
 * Used by LFO targets of the "message template" kind. */
void dzd_handle_internal(dz_msg *m);

/* ---- disp.c: frame stores, blank, sequencer, vsync thread ---- */
int  disp_init(int simulate);	/* starts the vsync thread */
void disp_close(void);
int  disp_dispatch(const dz_msg *m);	/* 0 = not a /disp or /vsync address */
int  disp_frame_fd(void);	/* eventfd: readable once per frame (or -1) */
int  disp_vsync_ok(void);	/* 1 while real vsync arrives */
double disp_frame_hz(void);	/* measured frame rate, 0 without vsync */

/* ---- lfo.c: oscillators, wave shapers, step sequences ---- */
void lfo_init(void);
int  lfo_dispatch(const dz_msg *m);	/* 0 = not an /lfo address */
void lfo_tick(double dt);		/* once per frame (or timer) */
/* Send a message template ("/addr a b $0 ...") to debazd itself. */
void dzd_send_template(const char *tpl);

/* ---- fx.c: colour matrix (hue, map) and colour key on the HDMI_0 mixer ---- */
int  fx_dispatch(const dz_msg *m);	/* 0 = not an /fx address */

/* ---- io.c: user I/O line functions by name ---- */
int  io_dispatch(const dz_msg *m);	/* 0 = not /io/pin or /io/pins */

/* ---- audio.c: 48 kHz rate setting from the video mode, HDMI_2 replug ---- */
int  audio_dispatch(const dz_msg *m);	/* 0 = not an /audio/fs or /capture/replug address */
void audio_tick(long ms);		/* from the monitor loop */

/* ---- pwm.c: software PWM / servo pulses on the fan pin 4 outputs ---- */
void pwm_init(void);			/* starts the PWM thread */
void pwm_close(void);			/* stops it, optos off */
int  pwm_dispatch(const dz_msg *m);	/* 0 = not /fan/<n>/pwm|duty|servo, /fan/pwm/stats */

#endif /* DEBAZD_H */

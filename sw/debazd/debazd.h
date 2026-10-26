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

/* ---- lfo.c: oscillators, wave shapers, step sequences ---- */
void lfo_init(void);
int  lfo_dispatch(const dz_msg *m);	/* 0 = not an /lfo address */
void lfo_tick(double dt);		/* once per frame (or timer) */
/* Send a message template ("/addr a b $0 ...") to debazd itself. */
void dzd_send_template(const char *tpl);

/* ---- fx.c: colour matrix (hue, map) and colour key on the HDMI_0 mixer ---- */
int  fx_dispatch(const dz_msg *m);	/* 0 = not an /fx address */

#endif /* DEBAZD_H */

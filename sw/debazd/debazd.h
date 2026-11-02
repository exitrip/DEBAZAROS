/*
 * debazd.h - internal interface between the debazd modules.
 */
#ifndef DEBAZD_H
#define DEBAZD_H

#include "dz_osc.h"
#include "dz_fields.h"

/* Reply to the sender of the message being handled. No-op for messages
 * that the daemon sends to itself (LFO templates, sequencers). */
void dzd_reply(const char *path, const char *tags, ...);
void dzd_reply_args(const char *path, const dz_arg *a, int n);	/* typed arguments */

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
void disp_crop_reset(void);	/* crops back to 0 0 (video mode change) */
extern int capture_auto;	/* debazd.c: capture size follows the input */

/* ---- lfo.c: oscillators, wave shapers, step sequences ---- */
void lfo_init(void);
int  lfo_dispatch(const dz_msg *m);	/* 0 = not an /lfo address */
void lfo_tick(double dt);		/* once per frame (or timer) */
/* react.c: audio analysis (2026-11-01) */
int   react_dispatch(const dz_msg *m);	/* 0 = not an /audio/react address */
void  react_tick(void);			/* once per frame, before lfo_tick */
void  react_stop(void);
int   react_feature_index(const char *name);	/* -1 = unknown */
const char *react_feature_name(int i);
float react_feature(int i);		/* 0..1 (a full-scale sine = 1) */
int   react_samples(float *out, int n, int chan);	/* newest n capture samples (chan 0 =
					 * (L+R)/2, 1 = L, 2 = R), 0 = none */
void  react_hold(int on, const char *why);	/* pause / resume the capture source */
int   react_capturing(void);		/* react's arecord holds the capture PCM */
void  dds_tick(void);			/* once per frame after react_tick: AWG scope */
/* Send a message template ("/addr a b $0 ...") to debazd itself. */
void dzd_send_template(const char *tpl);

/* ---- fx.c: colour matrix (hue, map) and colour key on the HDMI_0 mixer ---- */
int  fx_dispatch(const dz_msg *m);	/* 0 = not an /fx address */

/* ---- trans.c: timed field ramps (cue fades), /fx/xfade ---- */
int  trans_dispatch(const dz_msg *m);	/* 0 = not /fx/xfade or /trans/... */
void trans_tick(double dt);		/* once per frame, before lfo_tick */
/* ramp field f to raw target in secs (<= 0: at once); curve 0 linear, 1 smooth */
int  trans_field(const dz_field *f, uint32_t target, double secs, int curve);
void trans_stop_all(void);		/* every field ramp stops where it is */
void cue_tick(double dt);		/* once per frame: cue message ramps, dip */

/* ---- dds.c: dz_osc2 patterns, step table, AWG (fields: dz_fields.c) ---- */
int  ascii_dispatch(const dz_msg *m);	/* /ascii/<d>/... (ascii.c) */
void ascii_tick(void);			/* once per frame */

/* ---- state model (state.c; ROADMAP.md section 15) ----
 * Every subsystem lists its targets: one OSC message of debazd each (the
 * message that sets it), under a key (normally the address; the DDS steps:
 * "/dds/<n>/step/<i>"). Dispatching the messages of a dump in its order
 * restores the state. Strings of a message are valid only during the call. */
typedef void (*state_cb)(const char *key, const dz_msg *m, void *ctx);
/* tags: i f s (s = const char *); key NULL = the address */
void st_emit(state_cb cb, void *ctx, const char *key, const char *path, const char *tags, ...);
void st_emit_args(state_cb cb, void *ctx, const char *key, const char *path,
		  const dz_arg *a, int n);
void state_dump(state_cb cb, void *ctx);
/* a list of targets: key + the OSC message bytes, in order */
typedef struct {
	char    *key;
	uint8_t *msg;
	size_t   len;
} st_tgt;
typedef struct {
	st_tgt *t;
	int     n, cap;
	int    *hix, hcap;		/* hash index of the keys (open addressing) */
} st_list;
void st_list_free(st_list *l);
int  st_list_find(const st_list *l, const char *key);	/* index or -1 */
int  st_list_put(st_list *l, const char *key, const uint8_t *msg, size_t len); /* replace or append */
int  st_list_put_msg(st_list *l, const char *key, const dz_msg *m);
void st_list_copy(st_list *dst, const st_list *src);
void st_list_dump(st_list *l);			/* the state now */
int  st_same(const st_list *a, int i, const st_list *b, int j);	/* equal message bytes */
void st_list_apply(const st_list *l);		/* dispatch in order (internal) */
/* the targets of `want` that differ from (or are missing in) `now` -> out */
void st_list_diff(const st_list *want, const st_list *now, st_list *out);
void st_reply_target(const char *path, const char *key, const dz_msg *m);
int  cue_dispatch(const dz_msg *m);	/* /show, /scene, /cue (cue.c) */
int  state_dispatch(const dz_msg *m);	/* /state, /state/snap|recall|diff */
void disp_state(state_cb cb, void *ctx);
void lfo_state(state_cb cb, void *ctx);
void react_state(state_cb cb, void *ctx);
void dds_state(state_cb cb, void *ctx);
void ascii_state(state_cb cb, void *ctx);
void sound_state(state_cb cb, void *ctx);	/* sources, file players */
void pwm_state(state_cb cb, void *ctx);	/* fan PWM (also the software one) */
void fx_state(state_cb cb, void *ctx);	/* /fx/wrap */
void audio_state(state_cb cb, void *ctx);	/* the automatic settings */
int  dds_dispatch(const dz_msg *m);	/* 0 = not a /dds pattern / table address */

/* ---- io.c: user I/O line functions by name ---- */
int  io_dispatch(const dz_msg *m);	/* 0 = not /io/pin or /io/pins */

/* ---- audio.c: 48 kHz rate setting from the video mode, HDMI_2 replug ---- */
int  audio_dispatch(const dz_msg *m);	/* 0 = not an /audio/fs or /capture/replug address */
void audio_tick(long ms);		/* from the monitor loop */
void audio_rx_hold(void);		/* no input rate replug for 10 s (video mode change) */
int  sound_dispatch(const dz_msg *m);	/* 0 = not /audio/play|stop|rec|status|out/<n>/source */
void sound_tick(void);			/* reaps finished players / recorder */
void sound_close(void);

/* ---- pwm.c: software PWM / servo pulses on the fan pin 4 outputs ---- */
void pwm_init(void);			/* starts the PWM thread */
void pwm_close(void);			/* stops it, optos off */
int  pwm_dispatch(const dz_msg *m);	/* 0 = not /fan/<n>/pwm|duty|servo, /fan/pwm/stats */

#endif /* DEBAZD_H */

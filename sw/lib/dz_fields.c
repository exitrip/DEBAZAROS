/*
 * dz_fields.c - the field table. See dz_fields.h.
 *
 * Where each field goes (traced from the BD, Oct 2026):
 *
 *   0x4121_0000 HDMI_0 axi_gpio_mainG_shift_memdelay
 *     ch1 [23:0]  colorGainMain gains (HDMI_0 output)
 *     ch1 [31:24] div16_8_recip_0 den: HDMI_0 DDS sine divider
 *     ch2 [15:0]  c_addsub_0 B: HDMI_0 DDS sine offset (-> mixer din3)
 *     ch2 [29:16] c_addsub_1 B: BRAM pixel delay read offset (-> mixer stream B)
 *   0x4120_0000 axi_gpio_hdmi_in_phase0_div_gPhase1
 *     ch1         inputs: [7:0] user I/O, [9:8] HPD, [14:10] capture status
 *     ch2 [31:24] HDMI_0 div16_8_recip_1 den: HDMI_0 DDS phase divider (-> din4)
 *     ch2 [23:0]  HDMI_1 colorGainOscPhase gains
 *   0x4123_0000 HDMI_1 axi_gpio_divOsc_gosc_shiftPhaseOsc
 *     ch1 [31:24] div16_8_recip_0 den: HDMI_1 DDS sine divider
 *     ch1 [23:0]  colorGainOscSin gains
 *     ch2 [15:0]  c_addsub_0 B: HDMI_1 DDS sine offset
 *     ch2 [31:16] c_addsub_3 B: HDMI_1 DDS phase offset
 *   0x4126_0000 HDMI_1 axi_gpio_divPhase_gmain_shiftPhase_gfeedback
 *     ch1 [31:24] div16_8_recip_1 den: HDMI_1 DDS phase divider
 *     ch1 [23:0]  colorGainFeedback1 gains on HDMI_1's own video
 *     ch2 [23:0]  colorGainFeedback1 gains on HDMI_0's output (feedback)
 *
 * Divider den: 1 = pass through, 0 = output stuck at 0xFFFF.
 */
#include "dz_fields.h"
#include "dz_hw.h"
#include "dz_map.h"

#include <pthread.h>
#include <stdio.h>
#include <string.h>

#define IO	HW_AXI_GPIO_HDMI_IN_PHASE0_DIV_GPHASE1_BASE
#define G0	HW_HDMI_0_AXI_GPIO_MAING_SHIFT_MEMDELAY_BASE
#define G1OSC	HW_HDMI_1_AXI_GPIO_DIVOSC_GOSC_SHIFTPHASEOSC_BASE
#define G1MAIN	HW_HDMI_1_AXI_GPIO_DIVPHASE_GMAIN_SHIFTPHASE_GFEEDBACK_BASE
#define MIX	HW_HDMI_0_MIXERMATRIX_MIXER_0_BASE
#ifdef HW_HDMI_AUDIO_REGS_0_BASE
#define AUD	HW_HDMI_AUDIO_REGS_0_BASE
#define EVT	(HW_HDMI_AUDIO_REGS_0_BASE + 0x1000)	/* events page */
#endif
#define DDS0	HW_DDS_AXI_INTERFACE_0_BASE
#define DDS1	HW_DDS_AXI_INTERFACE_1_BASE
#define CH1	0x0u
#define CH2	0x8u

/* r, g, b and rgb for one gain word, in display lane order */
#define RGB4(p, base, off, what)						\
	{ p "/r",   base, off, DZ_LANE_R, 8,  DZ_RAW, 0, what " red" },		\
	{ p "/g",   base, off, DZ_LANE_G, 8,  DZ_RAW, 0, what " green" },	\
	{ p "/b",   base, off, DZ_LANE_B, 8,  DZ_RAW, 0, what " blue" },		\
	{ p "/rgb", base, off, 0,        24,  DZ_RGB, 0, what ", 1 or 3 values" }

#define DDS3(p, base, who)							\
	{ p "/hz",     base, 0x0, 0,  31, DZ_HZ,   DZ_F_DDS, who " frequency in Hz (sets enable)" }, \
	{ p "/pinc",   base, 0x0, 0,  31, DZ_RAW,  DZ_F_DDS, who " phase increment, raw (sets enable)" }, \
	{ p "/enable", base, 0x0, 31, 1,  DZ_BOOL, 0,        who " TVALID enable, bit 31" }, \
	{ p "/valid",  base, 0x4, 0,  1,  DZ_BOOL, DZ_F_RO,  who " TVALID readback" }

static const dz_field static_fields[] = {
	RGB4("/hdmi/0/gain", G0, CH1, "HDMI_0 output gain"),
	{ "/hdmi/0/osc/sin/div",    G0, CH1, 24,  8, DZ_RAW, 0, "HDMI_0 DDS sine divider (1 = pass, 0 = stuck 0xFFFF)" },
	{ "/hdmi/0/osc/sin/offset", G0, CH2,  0, 16, DZ_RAW, 0, "HDMI_0 DDS sine offset (mixer din3)" },
	{ "/hdmi/0/delay",          G0, CH2, 16, 14, DZ_RAW, 0, "mixer stream B pixel delay: read offset, delay = 16384 - value" },
	{ "/hdmi/0/osc/phase/div",  IO, CH2, 24,  8, DZ_RAW, 0, "HDMI_0 DDS phase divider (mixer din4)" },

	RGB4("/hdmi/1/gain",           G1MAIN, CH1, "HDMI_1 own-video gain"),
	RGB4("/hdmi/1/feedback",       G1MAIN, CH2, "HDMI_1 gain on HDMI_0 output (feedback)"),
	RGB4("/hdmi/1/osc/sin/gain",   G1OSC,  CH1, "HDMI_1 sine layer gain"),
	RGB4("/hdmi/1/osc/phase/gain", IO,     CH2, "HDMI_1 phase (saw) layer gain"),
	{ "/hdmi/1/osc/sin/div",      G1OSC,  CH1, 24,  8, DZ_RAW, 0, "HDMI_1 DDS sine divider" },
	{ "/hdmi/1/osc/sin/offset",   G1OSC,  CH2,  0, 16, DZ_RAW, 0, "HDMI_1 DDS sine offset" },
	{ "/hdmi/1/osc/phase/div",    G1MAIN, CH1, 24,  8, DZ_RAW, 0, "HDMI_1 DDS phase divider" },
	{ "/hdmi/1/osc/phase/offset", G1OSC,  CH2, 16, 16, DZ_RAW, 0, "HDMI_1 DDS phase offset" },

	DDS3("/dds/0", DDS0, "HDMI_0 DDS"),
	DDS3("/dds/1", DDS1, "HDMI_1 DDS"),

	{ "/io/raw",            IO, CH1,  0, 8, DZ_RAW,  DZ_F_RO, "user I/O lines [7:0] (PL_KEY[3:0] + K17/E19), active low" },
	{ "/io/key/0",          IO, CH1,  0, 1, DZ_BOOL, DZ_F_RO, "PL_KEY0, 0 = pressed" },
	{ "/io/key/1",          IO, CH1,  1, 1, DZ_BOOL, DZ_F_RO, "PL_KEY1, 0 = pressed" },
	{ "/io/key/2",          IO, CH1,  2, 1, DZ_BOOL, DZ_F_RO, "PL_KEY2, 0 = pressed" },
	{ "/io/key/3",          IO, CH1,  3, 1, DZ_BOOL, DZ_F_RO, "PL_KEY3, 0 = pressed" },
	{ "/hdmi/0/hpd",        IO, CH1,  8, 1, DZ_BOOL, DZ_F_RO, "HDMI_0 hot plug detect" },
	{ "/hdmi/1/hpd",        IO, CH1,  9, 1, DZ_BOOL, DZ_F_RO, "HDMI_1 hot plug detect" },
	{ "/fan/3/in",          IO, CH1, 15, 1, DZ_BOOL, DZ_F_RO, "J3 pin 3 level (0 = pulled low outside; active low)" },
	{ "/fan/5/in",          IO, CH1, 16, 1, DZ_BOOL, DZ_F_RO, "J5 pin 3 level (0 = pulled low outside; active low)" },
	{ "/capture/plocked",   IO, CH1, 10, 1, DZ_BOOL, DZ_F_RO, "dvi2rgb pLocked (MMCM lock, not alignment)" },
	{ "/capture/alocked",   IO, CH1, 11, 1, DZ_BOOL, DZ_F_RO, "dvi2rgb aLocked" },
	{ "/capture/overflow",  IO, CH1, 12, 1, DZ_BOOL, DZ_F_RO, "v_vid_in_axi4s FIFO overflow" },
	{ "/capture/underflow", IO, CH1, 13, 1, DZ_BOOL, DZ_F_RO, "v_vid_in_axi4s FIFO underflow" },
	{ "/capture/fid",       IO, CH1, 14, 1, DZ_BOOL, DZ_F_RO, "v_vid_in_axi4s field id" },

#ifdef HW_HDMI_AUDIO_REGS_0_BASE
	/* HDMI audio (hw/rtl/hdmi_tx/hdmi_audio_regs.v): output on HDMI_1, input
	 * on HDMI_2, ONE format 48 kHz 16-bit stereo. On a bitstream without the
	 * block these fields return an error (dz_map probes its ID). */
	{ "/audio/tx/hdmi",   AUD, 0x00, 0, 1,  DZ_BOOL, 0, "HDMI_1 output: 0 = DVI (as rgb2dvi), 1 = HDMI (InfoFrames); HDMI_0: /audio/tx0/..." },
	{ "/audio/tx/enable", AUD, 0x00, 1, 1,  DZ_BOOL, 0, "HDMI_1 audio packets (needs /audio/tx/hdmi)" },
	{ "/audio/tx/tone",   AUD, 0x00, 2, 1,  DZ_BOOL, 0, "1 kHz test tone (needs /audio/tx/fs_inc)" },
	{ "/audio/tx/avi",    AUD, 0x00, 8, 2,  DZ_RAW,  0, "AVI VIC: 0 = 720p60, 1 = 1080p30, 2 = 1080p60, 3 = none" },
	{ "/audio/tx/fs_inc", AUD, 0x04, 0, 32, DZ_RAW,  0, "internal 48 kHz clock: 48000 * 2^32 / f_pixel (720p60: 2776544); both outputs" },
	{ "/audio/tx0/hdmi",  AUD, 0x0C, 0, 1,  DZ_BOOL, 0, "HDMI_0 output: 0 = DVI (as rgb2dvi), 1 = HDMI (InfoFrames)" },
	{ "/audio/tx0/enable",AUD, 0x0C, 1, 1,  DZ_BOOL, 0, "HDMI_0 audio packets (needs /audio/tx0/hdmi)" },
	{ "/audio/tx0/tone",  AUD, 0x0C, 2, 1,  DZ_BOOL, 0, "HDMI_0 1 kHz test tone (uses /audio/tx/fs_inc)" },
	{ "/audio/tx0/avi",   AUD, 0x0C, 8, 2,  DZ_RAW,  0, "HDMI_0 AVI VIC: 0 = 720p60, 1 = 1080p30, 2 = 1080p60, 3 = none" },
	{ "/audio/rx/loop",   AUD, 0x08, 0, 1,  DZ_BOOL, 0, "send the HDMI_2 input audio to the HDMI_1 output" },
	{ "/audio/rx/clear",  AUD, 0x08, 1, 1,  DZ_BOOL, 0, "toggle: clear the input peak meters" },
	{ "/hdmi/2/hpd_low",  AUD, 0x08, 2, 1,  DZ_BOOL, 0, "force the HDMI_2 hot-plug line low (source sees an unplug; /capture/replug pulses it)" },
	{ "/audio/rx/islands",AUD, 0x10, 0, 1,  DZ_BOOL, DZ_F_RO, "HDMI_2 input: good data-island packets (last ~1 ms window)" },
	{ "/audio/rx/active", AUD, 0x10, 1, 1,  DZ_BOOL, DZ_F_RO, "HDMI_2 input: audio samples arrive" },
	{ "/audio/rx/samples",AUD, 0x14, 0, 32, DZ_RAW,  DZ_F_RO, "HDMI_2 input: stereo samples received (wraps)" },
	{ "/audio/rx/peak/l", AUD, 0x18, 0, 16, DZ_RAW,  DZ_F_RO, "HDMI_2 input: peak |left| since the last clear" },
	{ "/audio/rx/peak/r", AUD, 0x18, 16, 16, DZ_RAW, DZ_F_RO, "HDMI_2 input: peak |right| since the last clear" },
	{ "/audio/rx/n",      AUD, 0x1C, 0, 20, DZ_RAW,  DZ_F_RO, "HDMI_2 input: ACR N (48 kHz = 6144)" },
	{ "/audio/rx/cts",    AUD, 0x20, 0, 20, DZ_RAW,  DZ_F_RO, "HDMI_2 input: ACR CTS (720p60 = 74250)" },
	/* user I/O lines PL_KEY0-5 (hw/rtl/pl_io, 2026-10-27): names for
	 * /io/func/<n> in debazd/io.c (/io/pin <n> <name>) */
	{ "/io/func/0",       AUD, 0x40, 0, 4,   DZ_RAW,  0, "line 0 function: 0 in 1 out 2 scl 3 sda 4 sclk 5 mosi 6 miso 7 cs0 8 txd 9 rxd 10 bclk 11 lrclk 12 dout 13 din 14 cs1" },
	{ "/io/func/1",       AUD, 0x40, 4, 4,   DZ_RAW,  0, "line 1 function (see /io/func/0)" },
	{ "/io/func/2",       AUD, 0x40, 8, 4,   DZ_RAW,  0, "line 2 function (see /io/func/0)" },
	{ "/io/func/3",       AUD, 0x40, 12, 4,  DZ_RAW,  0, "line 3 function (see /io/func/0)" },
	{ "/io/func/4",       AUD, 0x40, 16, 4,  DZ_RAW,  0, "line 4 (K17) function (see /io/func/0)" },
	{ "/io/func/5",       AUD, 0x40, 20, 4,  DZ_RAW,  0, "line 5 (E19) function (see /io/func/0)" },
	{ "/io/out/0",        AUD, 0x44, 0, 1,   DZ_BOOL, 0, "line 0 output value (function 1)" },
	{ "/io/out/1",        AUD, 0x44, 1, 1,   DZ_BOOL, 0, "line 1 output value (function 1)" },
	{ "/io/out/2",        AUD, 0x44, 2, 1,   DZ_BOOL, 0, "line 2 output value (function 1)" },
	{ "/io/out/3",        AUD, 0x44, 3, 1,   DZ_BOOL, 0, "line 3 output value (function 1)" },
	{ "/io/out/4",        AUD, 0x44, 4, 1,   DZ_BOOL, 0, "line 4 output value (function 1)" },
	{ "/io/out/5",        AUD, 0x44, 5, 1,   DZ_BOOL, 0, "line 5 output value (function 1)" },
	{ "/io/level",        AUD, 0x48, 0, 6,   DZ_RAW,  DZ_F_RO, "levels of lines 0-5 (same as /io/raw [5:0])" },
	{ "/i2s/on",          AUD, 0x4C, 0, 1,   DZ_BOOL, 0, "I2S master on (BCLK 3.072 MHz, LRCLK 48 kHz)" },
	{ "/i2s/play",        AUD, 0x4C, 1, 1,   DZ_BOOL, 0, "I2S DOUT plays the HDMI_2 input audio (else silence)" },
	{ "/i2s/to_hdmi1",    AUD, 0x4C, 2, 1,   DZ_BOOL, 0, "HDMI_1 audio = I2S DIN (else the HDMI_2 loop)" },
	{ "/i2s/steer",       AUD, 0x4C, 3, 1,   DZ_BOOL, 0, "follow the HDMI_2 source clock (FIFO-level steering)" },
	{ "/i2s/to_hdmi0",    AUD, 0x4C, 4, 1,   DZ_BOOL, 0, "HDMI_0 audio = I2S DIN (else the HDMI_2 loop)" },
	{ "/i2s/inc",         AUD, 0x50, 0, 32,  DZ_RAW,  0, "bit clock NCO: 2*64*fs*2^32/100 MHz (48 kHz: 263882791)" },
	{ "/i2s/level",       AUD, 0x54, 0, 4,   DZ_RAW,  DZ_F_RO, "I2S TX FIFO level (0-8)" },
	{ "/i2s/underruns",   AUD, 0x54, 8, 8,   DZ_RAW,  DZ_F_RO, "I2S TX frames without a sample (incl. pre-fill)" },
	/* fan connectors J3/J5 (opto level shifters, 12 V side; gateware 2026-10-27) */
	{ "/fan/3/out",       AUD, 0x44, 8, 1,   DZ_BOOL, 0, "J3 pin 4 opto on (pin 4 pulled to ground)" },
	{ "/fan/5/out",       AUD, 0x44, 9, 1,   DZ_BOOL, 0, "J5 pin 4 opto on (pin 4 pulled to ground)" },
	{ "/fan/3/vsync",     AUD, 0x44, 10, 1,  DZ_BOOL, 0, "J3 pin 4 follows the vsync pulse (frame sync out)" },
	{ "/fan/5/vsync",     AUD, 0x44, 11, 1,  DZ_BOOL, 0, "J5 pin 4 follows the vsync pulse (frame sync out)" },
	/* J3 hardware PWM (gateware build pwm 2026-10-27; /fan/3/pwm in pwm.c
	 * sets these from Hz and duty) */
	{ "/fan/3/pwm/on",     AUD, 0x44, 13, 1, DZ_BOOL, 0, "J3 pin 4 = hardware PWM (wins over /fan/3/out and /fan/3/vsync)" },
	{ "/fan/3/pwm/period", AUD, 0x90, 0, 24, DZ_RAW,  0, "period in 10 ns counts (2000000 = 50 Hz)" },
	{ "/fan/3/pwm/invert", AUD, 0x90, 30, 1, DZ_BOOL, 0, "active part = opto off = pin 4 high (servo pulses)" },
	{ "/fan/3/pwm/lock",   AUD, 0x90, 31, 1, DZ_BOOL, 0, "restart the period at each vsync start" },
	{ "/fan/3/pwm/duty",   AUD, 0x94, 0, 24, DZ_RAW,  0, "active counts at the start of each period" },
	{ "/led/red",         AUD, 0x44, 12, 1,  DZ_BOOL, 0, "LED_RED pin W14 level (the LED may not be fitted)" },
	/* events (page 0x1000; gateware 2026-10-27). Bits: [0] J3 pin 3, [1] J5
	 * pin 3, [7:2] user I/O lines 0-5, [8] vsync. Times: 100 MHz counts */
	{ "/ev/rise",         EVT, 0x10, 0, 9,   DZ_RAW,  0, "sources whose rising edges count as events" },
	{ "/ev/fall",         EVT, 0x14, 0, 9,   DZ_RAW,  0, "sources whose falling edges count (pin 3 / buttons are active low)" },
	{ "/ev/irq_en",       EVT, 0x0C, 0, 9,   DZ_RAW,  0, "pending events that raise the event interrupt (GIC 84)" },
	{ "/ev/pend",         EVT, 0x08, 0, 9,   DZ_RAW,  DZ_F_RO, "events seen (write 1 to 0x43C6_1008 to clear)" },
	{ "/ev/level",        EVT, 0x18, 0, 9,   DZ_RAW,  DZ_F_RO, "synchronized source levels now" },
	{ "/ev/time",         EVT, 0x04, 0, 32,  DZ_RAW,  DZ_F_RO, "free-running 100 MHz counter (wraps every 42.9 s)" },
	{ "/ev/ts/j3",        EVT, 0x20, 0, 32,  DZ_RAW,  DZ_F_RO, "time of the last enabled J3 pin 3 edge" },
	{ "/ev/ts/j5",        EVT, 0x24, 0, 32,  DZ_RAW,  DZ_F_RO, "time of the last enabled J5 pin 3 edge" },
	{ "/ev/ts/line",      EVT, 0x28, 0, 32,  DZ_RAW,  DZ_F_RO, "time of the last enabled edge of lines 0-5" },
	{ "/ev/ts/vsync",     EVT, 0x2C, 0, 32,  DZ_RAW,  DZ_F_RO, "time of the last vsync start" },
	{ "/dds/0/phase",     EVT, 0x34, 0, 32,  DZ_RAW,  DZ_F_RO, "HDMI_0 DDS phase now (2^32 = one cycle)" },
	{ "/dds/0/phase_vs",  EVT, 0x30, 0, 32,  DZ_RAW,  DZ_F_RO, "HDMI_0 DDS phase at the last vsync start" },
	/* Linux PCM (ALSA card; gateware build pcm 2026-10-27): the kernel driver
	 * owns run/data/IRQ; these are routing + read-only status for debugging */
	{ "/pcm/to_hdmi1",    AUD, 0x4C, 5, 1,   DZ_BOOL, 0, "HDMI_1 audio = Linux PCM 1 (wins over the other sources)" },
	{ "/pcm/to_hdmi0",    AUD, 0x4C, 6, 1,   DZ_BOOL, 0, "HDMI_0 audio = Linux PCM 0 (wins over the other sources)" },
	{ "/pcm/to_i2s",      AUD, 0x4C, 7, 1,   DZ_BOOL, 0, "I2S DOUT = Linux PCM 2 (wins over /i2s/play)" },
	{ "/pcm/run",         AUD, 0x60, 0, 4,   DZ_RAW,  DZ_F_RO, "streams running: [0] HDMI_0 [1] HDMI_1 [2] I2S [3] capture" },
	{ "/pcm/level/0",     AUD, 0x74, 0, 10,  DZ_RAW,  DZ_F_RO, "HDMI_0 playback FIFO level (0-512 frames)" },
	{ "/pcm/level/1",     AUD, 0x74, 16, 10, DZ_RAW,  DZ_F_RO, "HDMI_1 playback FIFO level" },
	{ "/pcm/level/2",     AUD, 0x78, 0, 10,  DZ_RAW,  DZ_F_RO, "I2S playback FIFO level" },
	{ "/pcm/level/cap",   AUD, 0x78, 16, 10, DZ_RAW,  DZ_F_RO, "HDMI_2 capture FIFO level" },
	{ "/pcm/irq_status",  AUD, 0x7C, 0, 8,   DZ_RAW,  DZ_F_RO, "[3:0] level conditions, [7:4] xrun latches" },
	{ "/pcm/frames",      AUD, 0x84, 0, 32,  DZ_RAW,  DZ_F_RO, "48 kHz pacer frames (wraps)" },
#endif

	/* colour key (mixer coreRevision 22, 2026-10-26): the global bits are
	 * in channel 0 CTRL_0 [15:8]; per channel /mixer/<c>/key and /src */
	{ "/key/invert", MIX, 8 * 4, 8, 1, DZ_BOOL, 0, "colour key: HDMI_1 OUTSIDE the box (mixer chan 0 CTRL_0 [8])" },
	{ "/key/stream", MIX, 8 * 4, 9, 1, DZ_BOOL, 0, "colour key fill: 0 = live HDMI_1, 1 = delayed stream B (chan 0 CTRL_0 [9])" },
};

/* mixer 2.0: register index = chan*10 + n, byte offset = index*4 */
#define MIX_CHANS	9
#define MIX_GAINS	5
#define MIX_PER_CHAN	(MIX_GAINS + 7)
#define MIX_REG(c, n)	((((uint32_t)(c) * 10u) + (uint32_t)(n)) * 4u)
#define N_STATIC	((int)(sizeof(static_fields) / sizeof(static_fields[0])))
#define N_MIX		(MIX_CHANS * MIX_PER_CHAN)
#define N_FIELDS	(N_STATIC + N_MIX)

static dz_field fields[N_FIELDS];
static char     mix_paths[N_MIX][24];
static int      n_fields;

static void mix_add(int *k, int *p, int c, const char *name, uint32_t n,
		    uint8_t lo, uint8_t w, uint8_t unit, const char *help)
{
	dz_field *f = &fields[(*k)++];

	snprintf(mix_paths[*p], sizeof(mix_paths[0]), "/mixer/%d/%s", c, name);
	f->path  = mix_paths[(*p)++];
	f->base  = MIX;
	f->off   = MIX_REG(c, n);
	f->lo    = lo;
	f->width = w;
	f->unit  = unit;
	f->flags = 0;
	f->help  = help;
}

void dz_fields_build(void)
{
	int k, p = 0;

	if (n_fields)
		return;
	memcpy(fields, static_fields, sizeof(static_fields));
	k = N_STATIC;
	for (int c = 0; c < MIX_CHANS; c++) {
		static const char *gn[MIX_GAINS] = {
			"gain/0", "gain/1", "gain/2", "gain/3", "gain/4" };

		for (int n = 0; n < MIX_GAINS; n++)
			mix_add(&k, &p, c, gn[n], (uint32_t)n, 0, 32, DZ_RAW,
				"weight of din0..4 (din0 R, din1 B, din2 G, din3 sine, din4 saw)");
		mix_add(&k, &p, c, "mode", 8, 0, 8, DZ_RAW,
			"0 zero, 1 MAC, 3 pass, 4 const K, 0x10-0x13 clip, 0x20-0x23 clip to K");
		mix_add(&k, &p, c, "k", 8, 16, 16, DZ_RAW, "constant K (modes 4, 0x20-0x23)");
		mix_add(&k, &p, c, "stream", 9, 0, 1, DZ_BOOL,
			"0 = stream A (live HDMI_1), 1 = stream B (BRAM-delayed HDMI_1)");
		mix_add(&k, &p, c, "lo", 9, 16, 8, DZ_RAW, "clip threshold low");
		mix_add(&k, &p, c, "hi", 9, 24, 8, DZ_RAW, "clip threshold high");
		mix_add(&k, &p, c, "key", 9, 1, 1, DZ_BOOL,
			"colour key: this channel's lo..hi band joins the key mask (AND)");
		mix_add(&k, &p, c, "src", 9, 2, 1, DZ_BOOL,
			"compare HDMI_0's video instead of HDMI_1 (key, modes 3, 0x1x, 0x2x)");
	}
	n_fields = k;
}

int dz_fields_count(void) { return n_fields; }

const dz_field *dz_field_at(int i)
{
	return (i >= 0 && i < n_fields) ? &fields[i] : NULL;
}

const dz_field *dz_field_find(const char *path)
{
	for (int i = 0; i < n_fields; i++)
		if (strcmp(fields[i].path, path) == 0)
			return &fields[i];
	return NULL;
}

uint32_t dz_field_mask(const dz_field *f)
{
	return f->width >= 32 ? 0xFFFFFFFFu : ((1u << f->width) - 1u);
}

int dz_field_read(const dz_field *f, uint32_t *raw)
{
	volatile uint32_t *r = dz_regs(f->base);

	if (!r)
		return -1;
	*raw = (r[f->off / 4] >> f->lo) & dz_field_mask(f);
	return 0;
}

/* One lock for every read-modify-write: fields share registers (IO_OUT holds
 * GPIO outputs, fan bits and LED_RED), and debazd writes them from more than
 * one thread (the fan PWM thread, the main loop). */
static pthread_mutex_t rmw_mu = PTHREAD_MUTEX_INITIALIZER;

int dz_field_write(const dz_field *f, uint32_t raw)
{
	volatile uint32_t *r = dz_regs(f->base);
	uint32_t m, v;

	if (!r)
		return -1;
	if (f->flags & DZ_F_RO)
		return -2;
	m = dz_field_mask(f) << f->lo;
	pthread_mutex_lock(&rmw_mu);
	v = (r[f->off / 4] & ~m) | ((raw & dz_field_mask(f)) << f->lo);
	if (f->flags & DZ_F_DDS)
		v |= 0x80000000u;
	r[f->off / 4] = v;
	pthread_mutex_unlock(&rmw_mu);
	return 0;
}

uint32_t dz_field_from_float(const dz_field *f, float v)
{
	uint32_t max = dz_field_mask(f);

	switch (f->unit) {
	case DZ_BOOL:
		return v != 0.0f;
	case DZ_HZ: {
		double pinc = v <= 0.0f ? 0.0 : (double)v * 4294967296.0 / DZ_DDS_CLK_HZ;

		return pinc > (double)max ? max : (uint32_t)(pinc + 0.5);
	}
	default:
		if (v <= 0.0f)
			return 0;
		if (v >= 1.0f)
			return max;
		return (uint32_t)((double)v * max + 0.5);
	}
}

float dz_field_to_float(const dz_field *f, uint32_t raw)
{
	uint32_t max = dz_field_mask(f);

	switch (f->unit) {
	case DZ_BOOL:
		return raw ? 1.0f : 0.0f;
	case DZ_HZ:
		return (float)((double)raw * DZ_DDS_CLK_HZ / 4294967296.0);
	default:
		return max ? (float)((double)raw / max) : 0.0f;
	}
}

static uint32_t byte_of(const dz_arg *a)
{
	if (a->type == 'f') {
		if (a->f <= 0.0f)
			return 0;
		if (a->f >= 1.0f)
			return 255;
		return (uint32_t)(a->f * 255.0f + 0.5f);
	}
	return a->i < 0 ? 0 : (a->i > 255 ? 255 : (uint32_t)a->i);
}

static uint32_t raw_of(const dz_field *f, const dz_arg *a)
{
	if (a->type == 'f')
		return dz_field_from_float(f, a->f);
	if (f->unit == DZ_HZ)		/* an int Hz is still Hz */
		return dz_field_from_float(f, (float)a->i);
	if (f->unit == DZ_BOOL)
		return a->i != 0;
	return (uint32_t)a->i & dz_field_mask(f);
}

int dz_field_set(const dz_field *f, const dz_arg *a, int n, uint32_t *raw_out)
{
	uint32_t raw;

	if (n < 1 || a[0].type == 's')
		return -3;
	if (f->unit == DZ_RGB) {
		uint32_t r, g, b;

		if (n >= 3) {
			r = byte_of(&a[0]);
			g = byte_of(&a[1]);
			b = byte_of(&a[2]);
		} else {
			r = g = b = byte_of(&a[0]);
		}
		raw = (r << DZ_LANE_R) | (g << DZ_LANE_G) | (b << DZ_LANE_B);
	} else {
		raw = raw_of(f, &a[0]);
	}
	if (raw_out)
		*raw_out = raw;
	return dz_field_write(f, raw);
}

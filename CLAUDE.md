# DEBAZAROS — project notes for Claude

**What this actually is:** a 2-channel video playback + effects unit (standalone art
installation) built on a reclaimed EBAZ4205 crypto-miner control board (Zynq XC7Z010),
with a custom adapter PCB (`pcb/3xHDMI/`) providing power and two DVI/HDMI connectors.
It plays a looping movie via ffmpeg into a framebuffer and manipulates PL-based video
mixers/oscillators via `devmem` for generative feedback effects.

**What it is NOT:** the top-level `README.md`, `docs/`, and most folders describe the
*upstream project this was forked from* — Guido's "EBAZ4205 SDR and Spectrum" software
defined radio. All SDR/radio documentation is wildly out of date and irrelevant.
Working branch: `nuMix`.

⚠️ **The Vivado project is fragile.** Recent history includes a broken/recovered build
("recovered a decent build... after breaking trying out frame buffer read IP").
Never hand-edit `.bd`/`.xci` files; treat `Vivado/` as regenerate-only via Vivado 2022.2.

## Folder map: live vs legacy

| Path | Status | Notes |
|---|---|---|
| `Vivado/` | **LIVE** | Vivado 2022.2 project (`Vivado.xpr`), top = `ebaz4205_wrapper`, active BD = `ebaz4205` (`design_1` is an abandoned stub) |
| `ip_repo/mixer_1_0/` | **LIVE** | Custom mixer IP, vlnv `user.org:user:mixer:2.0` (folder name says 1_0, component.xml says 2.0) |
| `IP_rgb2dvi/`, `Vivado/IP_rgb2dvi/` | **LIVE** | Digilent rgb2dvi 1.3 (copy outside Vivado added Jan 2026) |
| `IP_axi_dynclk/`, `Vivado/IP_axi_dynclk/` | **LIVE** | Digilent axi_dynclk (dynamic pixel clock) |
| `PetaLinux/` | **LIVE** (config only) | Actual PetaLinux build lives on another machine; this tracks project-spec / dtsi / rootfs config. PetaLinux 2022.2/2023.1 era |
| `Vitis/colorbars/` | semi-live | Old Vitis workspace copy; **real application code is in `/home/aescape/workspace/jerkspace/`** (see below) |
| `debazarosit.sh`, `debazit.service` | **LIVE** | Top-level runtime: systemd oneshot → shell script (deployed to `/home/ebaz/` on target) |
| `system-user.dtsi` (repo root) | **LIVE** | The *current* dtsi ("save dtsi" commit, Dec 2025). Newer than the copy inside `PetaLinux/project-spec/.../device-tree/files/system-user.dtsi`, which still references SDR-era nodes |
| `debaz*.img/.bit/.bin/.xsa/.bsp`, `ebaz4205_wrapper*.xsa/.bit` | artifacts | Build/deploy snapshots; deployed bitstream is `debaz4205_wrapper_20250916.bit.bin` |
| `ad9851*`, `CIC_FIR*`, `axi_gen_test`, `jt9-flask`, `matlab/`, `qt5/`, `xapp888/`, `fritzing/`, `docs/`, `Vitis/Capture_RF/` | **LEGACY** | SDR-era remnants, safe to ignore (candidates for cleanup/archive) |

External (not in repo):
- **Vitis workspace:** `/home/aescape/workspace/jerkspace/` — many projects in various states;
  **`hdmi2` is the current application** (`hdmi2/src/colorbars/display_demo.c` is main).
  Others (`nuMixer*`, `hdmi22`, `debazaros`, `*_bare`) are experiments.
- **PetaLinux build machine:** elsewhere; only config is tracked here.

## Hardware / gateware architecture (BD `ebaz4205`)

Three hierarchies: `PS`, `HDMI_0`, `HDMI_1`. Both HDMI channels share one pixel clock.

### Clocking
- FCLK0 = 100 MHz: all AXI-Lite, DDS compilers, axi_dynclk REF_CLK
- FCLK1 = 64 MHz → `clk_wiz_128M` (PLL ×14/7 = 128 MHz) → DivideBy2N chains (50/25 MHz legacy)
- FCLK2 ≈ 145.45 MHz (named "140M"): VDMA memory-side + AXIS stream clock for both channels
- FCLK3 = 25 MHz
- `axi_dynclk_0` (0x43C4_0000) generates **shared** `PXL_CLK_O` (PixelClk) + `PXL_CLK_5X_O`
  (SerialClk) for both rgb2dvi instances; its `LOCKED_O` is the aRst_n for both output stages.
  Both displays therefore always run the same resolution; last `DisplayStart()` wins.

**⚠️ Regional pixel-clock architecture (root cause of "fabric full" + 35 MHz ceiling):**
the deployed axi_dynclk (stock Digilent, `Vivado.gen/.../ipshared/9097/src/axi_dynclk.vhd`)
puts the MMCM 5× clock on a **BUFIO** (SerialClk) and derives PixelClk via **BUFR ÷5** —
both *regional* buffers. Routed report (`impl_2/ebaz4205_wrapper_clock_utilization_routed.rpt`):
pixel clock g1 = BUFR_X0Y5, and **all 5,942 pixel-domain loads are locked into clock region
X1Y1** (one of four regions). The whole effects path (mixer, colorGain, v_tc video side,
vid_out video side, rgb2dvi fabric) must place in ¼ of the die → congestion, the >35 MHz
feedback ceiling, and why global-buffer experiments failed: OSERDES in rgb2dvi needs
CLK/CLKDIV on a *skew-matched pair* (BUFIO+BUFR same region, or BUFG+BUFG); mixing
BUFG pixel + BUFIO serial has undefined skew → garbage TMDS that mimics CDC failure.
The repo-local `IP_axi_dynclk/` copy has the BUFR commented out and an `ADD_BUFMR`
generic — remnants of these experiments; the *packaged* IP the BD uses is unmodified.
Proper global fix = MMCM emits both 1× and 5× (two CLKOUTs, inherently phase-aligned)
each through BUFG; requires extending the DRP ROM in `mmcme2_drp.v` (currently programs
CLKOUT0/FB/DIV only) + matching updates in hdmi2.elf `dynclk.c`. CLKOUT1 divider is
integer-only — pick serial on fractional CLKOUT0, pixel on CLKOUT1 = 5× that divide.

### Video pipeline (per channel)
```
DDR (HP0 for HDMI_0 / HP2 for HDMI_1)
  → axi_vdma (MM2S only, 3 fstores, 32-bit stream)
  → axis_subset_converter (32→24 bit, TDATA_REMAP: tdata[23:16],tdata[7:0],tdata[15:8])
  → v_axi4s_vid_out (+ v_tc timing gen, enable_detection=false)
  → [effects stage, differs per channel — below]
  → rgb2dvi (kGenerateSerialClk=false, clocks from axi_dynclk)
  → TMDS out
```

**HDMI_0 effects** (`mixerMatrix` + `colorGainMain`):
- `mixer_0` (custom IP, IN_WIDTH=16, OUT_WIDTH=24) computes **nine per-pixel gain
  signals** g_rr…g_bb that drive a 3×3 color matrix (`colorGainMatrix`, 9× xbip_multadd)
  applied to the channel's own video.
- Mixer inputs: din0/1/2 = R/G/B slices ([23:16]/[15:8]/[7:0]) of **HDMI_1's output pixel**
  (cross-feed `HDMI_1/pixData → HDMI_0/pixIn`); din3 = DDS sine + offset
  (`dds_compiler_0` 16-bit sine → c_addsub + B from `axi_gpio_dds_shift`, AINIT=0x8000);
  din4 = DDS phase[31:16] (sawtooth).
- Then `colorGainMain`: static per-channel 8×8-bit gain multiply; gains packed
  RGB-per-byte in one AXI GPIO word.

**HDMI_1 effects** (video feedback):
- `colorGainFeedback1`: two gain sets over Din0 = **HDMI_0's output pixel**
  (`HDMI_0/pixData → HDMI_1/pixIn1`) and Din1 = own VDMA video (dual-channel GPIO
  0x4126_0000: ch1 @+0, ch2 @+8) → dout0 + dout1 summed (c_addsub_1)
- `colorGainMain` (dual): Din = feedback sum, Din1 = DDS layer (dds_compiler + shift,
  c_addsub_0); its dual GPIO is 0x4123_0000 (ch1 @+0 video gains, ch2 @+8 DDS-layer gains)
- outputs summed (c_addsub_2) → rgb2dvi

The two channels cross-feed each other's final pixel output → the video-feedback
architecture. **Known limitation (git log 2025-09-11): feedback loop only stable below
720p@30 Hz / ~35 MHz pixel clock.** This is the main gateware stability issue to fix.

### IRQ chain
`HDMI_0` v_tc irq + vdma mm2s_introut (+ In3/In4/In5 spares) → concat → `HDMI_1` →
concat → PS IRQ_F2P.

### Address map (PS view)
| Base | Block |
|---|---|
| 0x4120_0000 | HDMI_0 axi_gpio_hdmi (HPD) |
| 0x4121_0000 | HDMI_0 colorGainMain GPIO (RGB gains, 1 byte each in [23:0]) |
| 0x4122_0000 | HDMI_1 axi_gpio_hdmi (HPD) |
| 0x4123_0000 | HDMI_1 colorGainMain GPIO (ch1 @+0 video, ch2 @+8 DDS layer) |
| 0x4124_0000 | axi_gpio_led (green LED, W13) |
| 0x4126_0000 | HDMI_1 colorGainFeedback1 GPIO (ch1 @+0, ch2 @+8) |
| 0x4300_0000 | HDMI_0 VDMA (AXI-Lite) |
| 0x4301_0000 | HDMI_1 VDMA (AXI-Lite) |
| 0x43C2_0000 | HDMI_0 v_tc |
| 0x43C3_0000 | HDMI_1 v_tc |
| 0x43C4_0000 | axi_dynclk |
| 0x43C5_0000 | HDMI_0 mixer_0 (the "nuMixer") |
| 0x43D0_0000 | dds_axi_interface_0 → HDMI_0 DDS phase increment |
| 0x43D1_0000 | HDMI_0 axi_gpio_dds_shift (DDS DC offset, c_addsub B) |
| 0x44D0_0000 | dds_axi_interface_1 → HDMI_1 DDS phase increment |
| 0x44D1_0000 | HDMI_1 axi_gpio_dds_shift |

VDMA masters: HDMI_0 → S_AXI_HP0, HDMI_1 → S_AXI_HP2 (both 256M window at 0).

### Custom IP register maps

**mixer 2.0** (`ip_repo/mixer_1_0/hdl/mixer_v1_0.v`, 0x43C5_0000): 9 output channels
("gain planes"), register index = `chan*10 + n` (word addressing, so byte offset =
(chan*10+n)*4):
- n=0..4: GAIN_chan_0..4 (weights for din0..din4)
- n=8: CTRL_chan_0 — [7:0] mode, [31:16] constant value K
- n=9: CTRL_chan_1 — [23:16] threshold lo, [31:24] threshold hi

Modes: 0=zero; 1=Σ gains[n]·din[n]; 3={din,8'hff} passthrough; 4=constant K;
0x10/0x11/0x12/0x13 = clip din (≥lo / ≤hi / ==lo / band) → {din,0xff} else 0;
0x20/0x21/0x22/0x23 = same comparisons but output K else 0.
Comparison source din: chans 0-2 use din0, 3-5 use din1, 6-8 use din2.
Output→matrix wiring: dout0→g_rr, dout1→g_br, dout2→g_gr, dout3→g_rg, dout4→g_gg,
dout5→g_bg, dout6→g_rb, dout7→g_gb, dout8→g_bb.
Known wart: dout7 modes 0x20-0x23 read `ctrl[6]` instead of `ctrl[7]` (copy-paste bug
in the Verilog). Multiply path is unregistered single-pixel-clock — a likely timing
limiter at higher pixel clocks.

**dds_axi_interface** (`Vivado/Vivado.srcs/sources_1/new/dds_axi_inteface.vhd` — note
filename typo): single 32-bit reg at +0. Bit31 = TVALID enable, bits[30:0] = phase
increment to dds_compiler (100 MHz, 32-bit phase acc → f = PINC × 100e6/2³² ≈
0.0233 Hz/LSB; PINC 0xa11 ≈ 60 Hz). Reg +0x10 (slv_reg_4 bit0) reads back TVALID status.

## Software stack

Boot: SD card PetaLinux → `debazit.service` (systemd oneshot) → `/home/ebaz/debazarosit.sh`:
1. Loads bitstream via fpga_manager (`debaz4205_wrapper_20250916.bit.bin` in /lib/firmware)
2. Mixer setup via devmem: chans {1,2,3,4,6,8} → mode 0x23 band-clip (0x20..0xed → out
   0xffff); chans {0,5,7} → mode 4 constant 0x8000
3. Launches `/home/ebaz/hdmi2.elf &` (display init) then
   `ffmpeg -stream_loop -1 -re -i test24-1280-8MBps.mp4 -pix_fmt bgra -f fbdev /dev/fb0 &`
4. Sets DDS0 ≈60 Hz (0x80000a11), DDS1 PINC=2, sets assorted mixer gains
   (reg 83=GAIN_8_3, 81=GAIN_8_1, 33=GAIN_3_3, 30=GAIN_3_0, 10/11=GAIN_1_0/1)
5. Infinite devmem loop: cycles DDS1 PINC {2,5,1290}, ramps colorGainFeedback gains
   (0x4126_0000/+8) up/down at 10 Hz, ping-pongs DDS0 freq and HDMI_1 main/DDS-layer
   gains (0x4123_0008)

**hdmi2.elf** (`/home/aescape/workspace/jerkspace/hdmi2/`, main =
`src/colorbars/display_demo.c`): Linux userspace app that runs once at startup to set
display timing and init PL. Reuses Xilinx baremetal drivers (xaxivdma v6_10, vtc v8_4,
Digilent dynclk/display_ctrl) on Linux by mmapping /dev/mem (`src/IP_Driver.c`,
`mm_IP` struct). Default mode 1280x720@30 both channels. Framebuffers: physical
0x0800_0000, 2 frames per display, frame size `DEMO_MAX_FRAME = 1920*1080*4`;
disp0 frames 0-1, disp1 frames 2-3. Has vestigial commented-out UDP server (port 8888)
and a menu mode (`-m`). CLI: `-r <res>`. Note: `TimerDelay` via scutimer SEGVs (commented
out); LED GPIO hardcoded 0x41240000.

**Device tree** (root `system-user.dtsi`, current): reserved-memory `removed-dma-pool`
16 MB @0x0800_0000 (no-map); simple-framebuffer 1280×2160 (3×720 stacked frames!)
a8r8g8b8 → `/dev/fb0` (ffmpeg writes top 720 lines = disp0 frame 0). bootargs:
`clk_ignore_unused cma=256M uio_pdrv_genirq.of_id=generic-uio`, root mmcblk0p2.
UIO nodes for HDMI_0/1 GPIOs and all 9 mixer nodes (mixer_1..8 labels are speculative —
only mixer_0 exists in the current BD). 16 MB reservation < 4 frames × 8.1 MB = 29.5 MB
used by hdmi2.elf — the app maps 97 MB span; **reserved region is undersized vs what the
code touches** (works because nothing else claims that RAM, but worth fixing in the
kernel/dts pass).

## Third HDMI/DVI port (hard constraint)

The adapter PCB (`pcb/3xHDMI/`) has a **third TMDS pinout laid out** — future input or
output. Therefore: **never remove memory or bus capacity that accommodates a third
frame/channel**: keep VDMA `c_num_fstores = 3`; keep spare ps7_axi_periph master ports
and address-map gaps; HP1/HP3 stay free for a third VDMA; DDR framebuffer budgeting
assumes up to 6 frames (3 disp × 2). The dtsi fb is already 3 frames tall (1280×2160).
Clocking note: a third TMDS bank outside region X1Y1 cannot be served by the current
single BUFIO/BUFR — needs either BUFMR → per-region BUFIO/BUFR (the `ADD_BUFMR` stub in
the local dynclk copy) or the dual-BUFG MMCM scheme.

## VTC sharing (resource win — correct recipe verified against RTL, Jul 2026)

Both v_tc always ran identical timing (shared PixelClk, same mode). Sharing one VTC
saves ~1.3k LUTs + 3.2k FFs, much of it inside crowded region X1Y1. Implemented Jul 2026:
VTC deleted from HDMI_1; the five vtiming signals (vsync/hsync/vblank/hblank/
active_video) cross hierarchies as discrete nets (interface "monitor pin" hookup was
abandoned; discrete nets verified correct in BD); HDMI_1 `xlconcat_IRQ/In0` tied 0;
hdmi2.elf display 1 reuses vtc_0 (correct).

**⚠️ Timing-mode gotcha (cost a debug cycle):** in v_axi4s_vid_out 4.0 (rev 15 RTL,
`ipshared/1b6c/hdl/v_axi4s_vid_out_v4_0_vl_rfs.v`) the mode names are the OPPOSITE of
what PG044 suggests for this use:
- **Slave mode (C_VTG_MASTER_SLAVE=0) PAUSES the VTC via vtg_ce during alignment**
  (`gen_fifo_vtg_en_slave_mode` gates VTG_EN in CALN/lagging states; `vtg_lag` counter
  gives up → IDLE → retries forever). With gen_clken tied high the VTG never lags, and
  since VDMA and VTG frame rates are identical the bad phase repeats deterministically —
  a channel either locks by boot-time luck or never locks at all.
- **Master mode (C_VTG_MASTER_SLAVE=1) holds VTG_EN = VID_CE constantly** and aligns by
  dropping FIFO data (EOL/SOF slip) — works fine with a free-running/shared VTC. The
  original two-VTC design was master mode with vtg_ce effectively always high.
- The output formatter **zeroes hsync/vsync/DE whenever not LOCKED** — an unlocked
  vid_out gives "no signal" on the monitor (not black), only the TMDS clock lane runs.

**Correct shared-VTC config: both vid_outs in MASTER mode + VTC gen_clken tied 1**
(or wired to either vtg_ce — equivalent, master mode never deasserts it). Behavior:
each channel locks independently by data-slip within a frame or two; an underflow kills
only that channel's output until re-lock. No software change beyond the single-VTC
edits already in hdmi2.elf.

**⚠️ IPI interface-vs-member-pin gotcha (Aug 2026, cost another debug cycle):** an
interface connection (v_tc vtiming_out → vid_out vtiming_in) drawn in the BD was
**silently generated as all-zero tie-offs** because the same interface's member pins
(vsync_out etc.) were simultaneously connected to discrete nets for the cross-hierarchy
fanout. IPI refuses to *branch* an interface net, allows the mixed hookup in the
diagram, then drops the interface side at generation — no warning. Rule: **when any
member pin of an interface is individually connected, connect ALL consumers via
discrete member nets; never leave a parallel interface-level connection.** Verify after
generation: both vid_out instantiations in
`Vivado.gen/sources_1/bd/ebaz4205/synth/ebaz4205.v` must show real nets on all five
vtg_* ports (only vtg_field_id may be 1'b0).
Also: physical DVI connector labels vs BD names may be swapped — BD HDMI_0 = TMDS clk
F19/F20, BD HDMI_1 = TMDS clk L16/L17 (see ebaz4205.xdc). Channel-identity kill test:
`devmem 0x41210000 32 0` blacks out BD HDMI_0's output (restore 0x00ffffff).

**Timing-report hygiene (Aug 2026):** PXL_CLK is constrained at 10 ns (100 MHz dynclk
default) so every build "fails" with WNS ≈ −39 ns — all on DORMANT mixer mode-1 MAC
paths (synthesis builds 10-DSP cascades ACROSS channels, e.g. dout3_reg→dout7_reg,
19 logic levels; harmless while no channel uses mode 1 — script uses modes 0x23/4).
⚠️ The summary only prints top paths per clock — the −39 ns mixer paths HIDE other
real violations below the cutoff; use targeted `report_timing -to <endpoint>`.
Fix later: constrain PXL_CLK to realistic 74.25 MHz max + false-path or pipeline the
MAC paths; the cross-channel DSP cascading is also why the time-multiplexed mixer
redesign must re-structure the adder trees.

**HDMI_1 content-dependent dropout ROOT CAUSE (Aug 2026, MEASURED):** the entire
effects chain is one unregistered combinational mega-cone. Worst measured path
(routed impl_2): `HDMI_0/v_axi4s_vid_out_0/FORMATTER_INST/in_data_mux_reg` →
colorGainMatrix xbip_multadd → HDMI_0 colorGainMain mult → cross-hierarchy pixData →
HDMI_1 feedback mult → c_addsub_1 → HDMI_1 colorGainMain mult → c_addsub_2 →
`HDMI_1/rgb2dvi_0/DataEncoders[*]/n1d_1_reg` (TMDS encoder popcount): **arrival
≈35.5 ns** (slack −25.5 vs the 10 ns constraint). 4 mults + 2 adders + encoder
front-end, zero registers (mult_gen PipeStages=0, multadd latency 0, c_addsub_1/2
Latency 0). At 720p60 (13.5 ns) violated by ~22 ns → dropouts; at 720p30 (28.6 ns)
violated by ~7 ns worst-case but typical-corner silicon ≈ passes → the historical
"touchy, only below 720p30/35 MHz" ceiling WAS this cone. DDS leg additionally enters
via HDMI_1/c_addsub_0 registered on the ASYNC 145M stream clock (HDMI_0's on 100M).
Symptoms: solid with gains=0 (no transitions on violating paths); unstable with
feedback gain ≥~0x08 or DDS-layer content; monitor drops sync every few seconds
(encoder disparity corruption); MMCM lock + HDMI_0 unaffected. PCB exonerated
(4-layer, GND zones, port 0 measures worse than port 1 on pair skew yet is stable).

**Fix (all free/near-free, BD re-customize only, no address/software changes):**
1. all mult_gen PipeStages 0→1 (DSP-internal regs), 2. all 9 xbip_multadd: GUI only
offers latency 0 or **−1 (auto; forces both fields)** — use −1. They form 3 C-cascaded
chains of 3, so nonzero C latency skews R/G/B matrix contributions by (Actual C
Latency) px per cascade stage — cosmetic chromatic offset in the matrix layer only;
compensable later with SRL delays on the G (+1×C-lat) and B (+2×C-lat) slices. Record
the "Actual AB/C Latency" values the GUI reports. (Alternative: leave multadds at 0 —
sync dropouts still fixed at all rates since mult_gen regs bound every encoder-facing
segment; the residual ~20 ns comb multadd chain inside HDMI_0 then only corrupts
matrix-layer pixel VALUES at 720p60, sparkle not sync loss; pixel-perfect at 720p30.)
3. c_addsub_1/2 Latency →1 with CLK=PixelClk, 4. both c_addsub_0 reclocked to PixelClk
(confines DDS CDC to one registered slow value). Adder-regs-only is NOT enough for
720p60 (front segment still ~20 ns). Side effects: few-px shift vs sync + small
inter-layer shifts (imperceptible). Verify pre/post on routed dcp:
`report_timing -from [get_clocks axi_dynclk_0_PXL_CLK_O] -to [get_clocks
axi_dynclk_0_PXL_CLK_O] -max_paths 1000 -nworst 1 -sort_by slack -file pxl.rpt`
then grep for HDMI_1/rgb2dvi. (GUI Tcl console can wedge/queue silently — use
`vivado -mode batch` against the checkpoint instead.) After this fix, feedback at
720p60 becomes plausible for the first time; remaining offender = dormant mixer
mode-1 MAC paths (−39 ns, masked by mode muxing).

**Debug visibility TODO:** make both axi_gpio_hdmi dual-channel, ch2 inputs = local
vid_out locked/underflow/overflow → readable at 0x4120_0008 / 0x4122_0008, no address
moves. In master mode, "no signal" ⇔ not locked ⇔ usually no stream SOF (VDMA not
running) — check MM2S DMACR/DMASR (0x4300_0000/4, 0x4301_0000/4) before suspecting
the BD.

## Driver-code direction (analysis Aug 2026 — no API designed yet)

Goal: live-performance control of mixers/DDS. Agreed pain points and direction:

- hdmi2 = three things: an **invasive frozen fork** of Xilinx baremetal drivers
  (146 mm_IP touchpoints in xvtc.c, 107 in xaxivdma.c — never extend, never update),
  a reusable 60-line /dev/mem mmap shim (IP_Driver.c), and bring-up sequencing worth
  keeping (vga_modes.h MMCM tables, start ordering). Hardware truth is quadruplicated
  by hand: stale xparameters.h (Feb 2025) + xvtc_g.c/xaxivdma_g.c + hardcoded consts +
  debazarosit.sh.
- **Control plane ≠ bring-up**: new control code = thin dependency-free register layer;
  discover devices at runtime via UIO (/sys/class/uio scan; dtsi generic-uio nodes
  already exist) so BD address changes propagate with zero C edits.
- **Address-stability contract**: bitstream-only fpga_manager swaps work because
  addresses never move. Do the GPIO/interconnect consolidation ONCE before driver work,
  then freeze the map except additions (third channel = pure addition).
- Move app code from jerkspace (local git, no remote, "testing this mess" commits) into
  this repo (`sw/`), plain Makefile, drop the Vitis managed build.
- **Framebuffer geometry trap**: hdmi2 slot pitch = DEMO_MAX_FRAME (1920·1080·4 ≈
  8.29 MB, disp0=slots 0-1, disp1=slots 2-3) but dtsi fb0 = 1280×2160 = 3×720p at
  3.69 MB pitch — fb0 rows 720+ land mid-slot-0, NOT in a second frame. Unify in one
  memory_map.h (keep 1080p pitch, 6 slots for 3 displays, fb0 = slot 0 only) and fix
  reserved-memory (16 MB now vs ~50 MB for 6 slots).
- Coherence between ffmpeg (fbdev WC), C code (/dev/mem uncached), VDMA (DDR direct)
  is inherent — but uncached A9 reads are tens of MB/s: benchmark before promising
  full-frame 30 fps CPU processing; slow generative layer + PL data plane is the fit.
  Tear-free flip already exists (write off-screen slot → DisplayChangeFrame park).
  VTC IRQ → UIO would give a clean wait-for-vsync primitive later.

## Known issues / future work (user's stated roadmap)
1. **Cleanup + documentation pass** without breaking the fragile Vivado project
   (READMEs are all SDR-era; legacy folders to prune/archive)
2. **Better driver C code** + proper PetaLinux kernel/DTS config (replace devmem pokes
   and /dev/mem mmap with UIO or real drivers; fix reserved-memory sizing; dtsi in
   PetaLinux/ tree is stale vs repo root)
3. **Gateware stability/usage/timing**: feedback path unstable above ~35 MHz pixel clock
   (720p30 limit) — primary suspect is the BUFR single-region pixel clock (see Clocking)
   plus unregistered multiply chains; mixer dout7 ctrl[6] copy-paste bug;
   only HDMI_0 has the mixerMatrix (HDMI_1 uses simpler gain blocks — DSP budget:
   69/80 used, mixer alone = 45); frame-buffer-read IP experiment previously broke the
   build (be careful re-attempting)
4. **Resource budget** (impl_2, Jan 2026): slices 94% (binding), DSP 69/80, LUT 65%,
   FF 54% (19.2k: v_tc ×2 ≈ 6.5k, mixer reg file ≈ 4k incl. a redundant duplicate
   output-register stage on the same clock, VDMA ×2 ≈ 2.8k), BRAM 55%. Savings queue:
   shared VTC (above); delete dead SDR clock tree (`PS/clk_wiz_128M` PLL,
   `proc_sys_reset_128M`, `DivideBy2_50MHz`, `rst_ps7_0_64M` — outputs unconsumed at top;
   KEEP `DivideBy4_25MHz` = ethernet PHY clock on U18); slim mixer register file;
   GPIO/interconnect consolidation (addresses change → update devmem scripts).
   Do NOT trim VDMA fstores (third-port constraint). DSP relief = time-multiplexed
   mixer MACs at 2× pixel clock (45→~23 DSPs, also fixes timing ceiling).

## Build facts
- Vivado 2022.2, part XC7Z010 (EBAZ4205), top `ebaz4205_wrapper`, pblock constraint on SLR0
- Constraints: `Vivado/Vivado.srcs/constrs_1/imports/new/ebaz4205.xdc` (TMDS pins for two
  DVI ports on adapter PCB, HPD/CEC, ethernet GMII, LED W13, 25 MHz clk U18)
- PetaLinux: machine zynq-generic; build with
  `petalinux-config --get-hw-description=<Vivado dir>` then `petalinux-build`;
  package with `--fsbl zynq_fsbl.elf --fpga ebaz4205_wrapper.bit --u-boot`
- XSA snapshots at repo root and in `Vivado/`; latest-good checkpoint
  `Vivado/checkpoint_20250916.dcp` and `debaz4205_wrapper_20250916.xsa`

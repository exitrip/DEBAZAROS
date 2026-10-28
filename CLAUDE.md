# DEBAZAROS — project notes for Claude

**What this actually is:** a 2-channel video playback + effects unit (standalone art
installation) built on a reclaimed EBAZ4205 crypto-miner control board (Zynq XC7Z010),
with a custom adapter PCB (`pcb/3xHDMI/`) providing power and two DVI/HDMI connectors.
It plays a looping movie via ffmpeg into a framebuffer and manipulates PL-based video
mixers/oscillators via `devmem` for generative feedback effects.

**What it is NOT:** the top-level `README.md`, `docs/`, and most folders describe the
*upstream project this was forked from* — Guido's "EBAZ4205 SDR and Spectrum" software
defined radio. All SDR/radio documentation is wildly out of date and irrelevant.
Working branch: `clanker` (remote `debaz`). `nuMix` and the other branches are old.
Current work plan and status: `ROADMAP.md` (Oct 2026).

⚠️ **The Vivado project is fragile.** Recent history includes a broken/recovered build
("recovered a decent build... after breaking trying out frame buffer read IP").
Never hand-edit `.bd`/`.xci` files; treat `Vivado/` as regenerate-only via Vivado 2022.2.

**Tcl flow (Oct 2026) — `hw/README.md`:** `hw/bd/<variant>.tcl` is now the BD
source of truth (`ebaz4205_2out1in` = the live 2-out/1-in design).
`hw/build.tcl <variant> project|build [outdir]` regenerates `build/<variant>/` (git-ignored,
deleted every run; normal GUI-openable .xpr) and writes .bit/.bit.bin/.xsa +
`hw_map.h` (address map named by full hierarchy path). After any GUI BD edit:
`hw/export_bd.tcl <variant>` (or `write_bd_tcl -force -include_layout`) → commit
the Tcl diff, else the next build erases it. Only 4 RTL files feed the BD
(DivideBy2N, div16_8_recip, dds_axi_inteface + _logic); all other RTL in
`Vivado.srcs/sources_1/new/` is unused legacy. Those 4 RTL files and the XDC
are now copied to `hw/rtl/` and `hw/xdc/` (Oct 25 2026) and build.tcl reads only
those: the Tcl flow no longer reads anything from `Vivado/`. Digilent TMDS interface def is
vendored in `ip_repo/if/` (was silently resolved from an external
`~/Documents/github/vivado-library` clone). Rebuild vs live netlist: identical
except the K17/E19 GPIO lines (ports `AUDIO_L/R`) moved 0x4120_0000 bits
[7:6]→[5:4] (write_bd_tcl dropped a stale xlconcat_2 IN0_WIDTH=6). `-read_only` project open fails on
this BD, legacy AND rebuilt (empty axi_dynclk s_axi_lite_aclk CLK_DOMAIN) —
batch scripts open a copy or the generated project read-write. Full Tcl build vs
live impl_2: same util (LUT +1, FF −12, BRAM/DSP equal), same timing character
(all fails in PXL_CLK_O @10 ns over-constraint + FCLK0→PXL GPIO crossings).
Export round-trip is clean except assign_bd_address line ORDER (nondeterministic).
Since Oct 27 2026 build.tcl runs phys_opt + post-route phys_opt (AggressiveExplore):
at ~95 % slices FCLK2 has ~0.1 ns inside the capture VDMA S2MM datamover and
the default flow failed it once (-0.39 ns). Always check FCLK2 in the report.

## Folder map (after the cleanup of Oct 25 2026)

| Path | Notes |
|---|---|
| `hw/` | Gateware as Tcl: `hw/bd/<variant>.tcl` (BD source of truth), `hw/rtl/` (4 module-ref RTL files), `hw/xdc/ebaz4205.xdc`, `build.tcl`, `export_bd.tcl`, `repackage_ip.tcl`, `hw_map.tcl`, `patches/` (dvi2rgb vs Digilent f4613ff). See `hw/README.md` |
| `ip_repo/if/`, `ip_repo/mixer_1_0/` | Digilent TMDS interface def (vendored); custom mixer IP, vlnv `user.org:user:mixer:2.0` (folder name says 1_0) |
| `IP_dvi2rgb/`, `IP_rgb2dvi/`, `IP_axi_dynclk/` | Digilent IP repos used by the build (dvi2rgb = local fork, see `hw/patches/`) |
| `artifacts/` | Bitstreams/XSA in use (BOOT fallback 20250916, legacy dev 20261019_dvi2ms, first Tcl build 20261025 = hardware-tested) + README |
| `sw/` | All userspace code: debazd, dzctl, dzweb (web app), libdz, hdmi2, fbfeed. Plain make. See `sw/README.md` |
| `PetaLinux/` | PetaLinux 2022.2 project-spec + `dtb/`. The project itself is built on the build machine (see below) |
| `pcb/` | 3xHDMI adapter PCB (KiCad) |
| `debazarosit.sh`, `debazit.service` | Old boot runtime: systemd oneshot (disabled on the bench board) → shell script in `/home/ebaz/` |
| `FLEET.md`, `ROADMAP.md` | Fleet/time-sync/transport design; work plan |

REMOVED Oct 25 2026 (all still in branch `legacy-vivado-project`, commit f2f0b80c; untracked
files of those folders + SD images moved to `~/Documents/github/DEBAZAROS-archive-20261025/`):
`Vivado/` (legacy GUI project), `Vitis/`, `sw/oscreg`, SDR remnants (`ad9851*`, `AD9851_test`,
`CIC_FIR*`, `axi_gen_test`, `jt9-flask`, `qt5`, `fritzing`, `docs`, `matlab`, `xapp888`),
`ip_repo/{ad9851gfsk*,myip_1_0,edit_myip_v1_0.*}`, old root `.xsa/.bit/.bin/.bsp/.img`.
**Paths under `Vivado/...` elsewhere in this file (reports, ipshared copies, impl_2) refer to
that legacy project**: check them out from the branch when needed.

External (not in repo):
- **Vitis workspace:** `/home/aescape/workspace/jerkspace/` — where hdmi2 was edited and
  built until Oct 2026. Its `hdmi2/src` was copied into the repo and is now `sw/hdmi2/src`
  (the board's boot `/home/ebaz/hdmi2.elf` is still the jerkspace build). Others
  (`nuMixer*`, `hdmi22`, `debazaros`, `*_bare`) are experiments.
- **PetaLinux build machine:** `ssh -o IdentitiesOnly=yes -i ~/.ssh/id_ed25519 aescape@192.168.1.239`
  (Ubuntu 22.04; the project is that machine's repo clone `~/Documents/projects/DEBAZAROS/PetaLinux`;
  build/ and images/ live only there).

## PetaLinux (state 2026-10-25; procedure in `PetaLinux/README.md`)

- Builds pass on the build machine with the Tcl XSA (FSBL: FCLK3 = 200 MHz), the
  single dtsi (no PL nodes, NAND on, 96 MB), and a 200 MB rootfs (ffmpeg, LuaJIT,
  libjpeg-turbo, pixman, exFAT, mtd-utils; no package manager, no Qt/SDR load).
  Images NOT yet on any card (next: spare test card).
- After EVERY XSA import: `petalinux-build -c fsbl-firmware -x cleansstate` and the
  same for `device-tree` (stale xsct workspace -> "Failed to generate bsp").
- `silentconfig` rewrites `configs/*`: copy the rewritten files back into the repo
  and commit, or the next pull on the build machine is refused.
- LuaJIT recipe needed `meta-user/recipes-devtools/luajit/*.bbappend` (dead
  luajit.org tarball + broken `CCOPT:x86=` make word).
- Workflow used: edit here, commit locally, `git bundle` -> build machine ff-merge
  (same hashes, no push). Cache backup: build machine `~/petalinux-2022.2-cache/`.

## Hardware / gateware architecture (BD `ebaz4205`)

Three hierarchies: `PS`, `HDMI_0`, `HDMI_1`. Both HDMI channels share one pixel clock.

### Clocking
- FCLK0 = 100 MHz: all AXI-Lite, DDS compilers, axi_dynclk REF_CLK
- FCLK1 = 64 MHz → `clk_wiz_128M` (PLL ×14/7 = 128 MHz) → DivideBy2N chains (50/25 MHz legacy)
- FCLK2 ≈ 145.45 MHz (named "140M"): VDMA memory-side + AXIS stream clock for both channels
- FCLK3 = 200 MHz (changed from 25 MHz, Aug 2026): dvi2rgb IDELAYCTRL RefClk (HDMI_2 input)

**⚠️ FSBL-vs-bitstream clock trap (cost a full debug day, Aug 2026):** FCLK
frequencies are programmed by the FSBL at boot from the PS7 init of the XSA it
was built from — a bitstream-only fpga_manager reload NEVER updates them. After
changing any PCW_FPGAx frequency in the BD, either rebuild BOOT.BIN from the new
XSA or poke the SLCR at runtime (unlock 0xF8000008=0xDF0D, then FPGAx_CLK_CTRL
at 0xF8000170/180/190/1A0; IOPLL=1600 MHz, value fields DIV0[13:8] DIV1[25:20]).
debazarosit.sh now sets FPGA3=0x00100800 (1600/8=200 MHz) as a boot workaround;
remove once BOOT.BIN is rebuilt. Symptom of the trap: dvi2rgb aLocked stuck low
(IDELAYCTRL never ready on a 25 MHz "200 MHz" RefClk) with everything else
checking out perfectly.

**Boot/flash workflow (deliberate):** BOOT.BIN carries the OLD stable
bitstream so every boot brings up ethernet (the PHY 25 MHz clock comes from
the PL); the dev bitstream is then JTAG-flashed on top. Consequences: a reboot
loses the dev PL (reflash needed, and the ethernet often needs a cable replug
to renegotiate); do NOT run debazarosit.sh after a JTAG flash — its first line
would reload the old bitstream from /lib/firmware over the dev design. The
FCLK3 SLCR poke must be redone after every reboot.
**fpga_manager reload (new image, 2026-10-26):** works and the ethernet link
stayed up: `sw/tools/plreload.sh` (stops hdmi2 + debazd, loads, restarts them,
re-applies the boot mixer setup). Soft-reset capture first.
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
The repo-local `IP_axi_dynclk/` IS the IP the BD uses (its `src/axi_dynclk.vhd` is
byte-identical to the live `ipshared/2a7c` copy, verified Oct 25 2026): BUFIO 5× +
BUFR ÷5, plus a `kAddBUFMR` generic (default false) left from these experiments.
(`Vivado/IP_axi_dynclk/` is only an IP-packager project, not used by any build.)
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
- **Pixel bus lane order is RBG** (verified in BD, Oct 2026): `[23:16]` = R,
  `[15:8]` = B, `[7:0]` = G (TDATA_REMAP {R,B,G} + Digilent rgb2dvi "RBG packing").
  Every per-colour gain byte multiplies the pixel byte in the same lane, so gain
  words are R[23:16], B[15:8], G[7:0] — NOT RGB. (sw/lib/dz_fields hides this.)
- Mixer inputs: din0/1/2 = slices [23:16]/[15:8]/[7:0] = **R / B / G** of **HDMI_1's
  output pixel** (stream A); din5/6/7 = same slices of the BRAM-delayed copy (stream B,
  `blk_mem_gen_0` line delay, read offset = 0x4121_0000 ch2 [29:16], delay = 16384 −
  value px); din3 = HDMI_0 DDS sine ÷ den (0x4121_0000 ch1 [31:24]) + offset (ch2
  [15:0]); din4 = DDS phase ÷ den (0x4120_0008 [31:24]) (sawtooth).
- Then `colorGainMain`: static per-channel 8×8-bit gain multiply; gains packed one
  byte per lane (R/B/G as above) in 0x4121_0000 ch1 [23:0].

**HDMI_1 effects** (video feedback):
- `colorGainFeedback1` (traced Oct 2026): gains 0x4126_0000 ch1 [23:0] × HDMI_1's own
  VDMA video, gains 0x4126_0000 ch2 [23:0] × **HDMI_0's output pixel** (feedback) →
  summed (c_addsub_1). There is no separate HDMI_1 colorGainMain any more.
- Two oscillator layers: `colorGainOscSin` (gains 0x4123_0000 ch1 [23:0]; sine ÷ den
  ch1 [31:24] + offset ch2 [15:0]) and `colorGainOscPhase` (gains 0x4120_0008 [23:0];
  saw ÷ den 0x4126_0000 ch1 [31:24] + offset 0x4123_0000 ch2 [31:16]). Full field
  table with OSC names: `sw/lib/dz_fields.c` (`debazd -l`).
- outputs summed (c_addsub_2) → rgb2dvi

**DDS divider layer (Aug 2026):** every DDS output (sine and phase, both
channels) now passes through a `div16_8_recip` module-ref before its adder/
gain stage — unsigned 16÷8 via a ceil(2^24/den) ROM-reciprocal multiply
(1 DSP + 1 BRAM, bit-exact, 3-cycle latency, den=0 → 0xFFFF). Denominators
come from GPIO fields (see address map; all default to 1 = passthrough), so
integer attenuation composes with the multiplication-based gains.
HDMI_1 also gained a second osc gain stage (colorGainOscSin + colorGainOscPhase,
c_addsub_3/4). HDMI_0's DDS legs run on FCLK0; HDMI_1's on PixelClk.

The two channels cross-feed each other's final pixel output → the video-feedback
architecture. **Known limitation (git log 2025-09-11): feedback loop only stable below
720p@30 Hz / ~35 MHz pixel clock.** This is the main gateware stability issue to fix.

### HDMI_2 capture path (third port as INPUT — **WORKING end-to-end Aug 2026**)

Live 720p60 video from an external HDMI source captures to DDR and routes to
either display, toggled live via hdmi2.elf -m key 'a' (off → disp1 → disp0 →
off). Verified stable with live video. Getting here required three stacked
fixes: the FSBL clock trap (above), the VDMA driver channel-base fix, and the
VDMA address-latch recommit (both below).

```
TMDS in (N20/P20 clk; N17/P18, M19/M20, M17/M18 data — pins split across
banks 34+35, so dvi2rgb is patched for BUFG+BUFG clocking)
  → dvi2rgb 2.0 (local IP_dvi2rgb fork: MMCM CLKOUT1 1x + BUFG replaces BUFR;
    kClkRange=2, kAddBUFG=false; EDID ROM "DGL 720P CEA" served over DDC_2 —
    edited Aug 2026: advertises 720p60 native + 1080p30 [VIC 34 + DTDs at
    74.25 MHz], 1080p60 REMOVED [silicon can't deserialize 1.485 Gbps];
    verified live on the wire. 1080p30 capture also needs CAPTURE_W/H
    1920x1080 in hdmi2.elf)
  → v_vid_in_axi4s (async FIFO CDC, depth 8192 ≈ 6 lines of 720p;
    vid_io_in_ce = pLocked)
  → axis_subset_converter 24→32 (TDATA_REMAP 8'b11111111,tdata[23:16],
    tdata[7:0],tdata[15:8] — inverse of display-side swap, alpha 0xff)
  → axi_vdma S2MM (0x4302_0000, 3 fstores all pointed at slot 4 for now)
  → HP1 → DDR slot 4 (0x09FA_4000)
```

**⚠️ VDMA frame-address latch gotcha (cost most of a debug day, Aug 2026):**
writing a VDMA START_ADDRESS register reads back correctly but the scanout
KEEPS FETCHING the previously committed address until VSIZE is rewritten
(VSIZE write = the arm/commit point). Applies to every VDMA channel in the
design. Symptom: "parked the display on the capture slot, still shows stale
memory noise" while devmem readback of the address register looks perfect.
Correct sequence after changing FrameStoreStartAddr on a RUNNING channel:
XAxiVdma_DmaSetBufferAddr then XAxiVdma_DmaStart (on a running channel this
skips the RS write and just rewrites VSIZE = recommit). By devmem: write the
address reg, then write VSIZE (MM2S 0x50 / S2MM 0xA0). Park-pointer-only
changes between already-committed frames need no recommit.

**⚠️ NEVER halt an S2MM channel mid-frame (DMACR.RS=0 while streaming) — and
NEVER JTAG-reflash the PL while capture is running (same wedge, confirmed by
a second incident Aug 2026: reflash over live capture → stuck soft reset →
capture dead until power cycle; stop capture with a soft reset BEFORE
flashing):** the
datamover abandons an in-flight burst inside the HP-port AFI write FIFO (in
the PS). After that: DMASR.Halted never asserts, soft reset (DMACR bit2)
sticks forever, and NO PL-side reset recovers it (FPGA_RST_CTRL, dynclk
relock pulse, full driver re-init — all tried, all useless). Only a PS reset
(reboot/power cycle) clears the AFI. This is the probable anatomy of the
mysterious full-board hangs. To stop capture safely, use soft reset while the
stream is healthy (reset completes when beats can flush), or gate at a frame
boundary. Symptom chain if it happens anyway: armed channel + locked input +
zero DMASR activity + stuck reset bit.

Display of the capture = repoint a display VDMA frame index at slot 4 and park
(hdmi2.elf menu key 'a' cycles off / disp1 / disp0). HPD_2 = PL pin R18 driven
by an xlconstant (high) into Q9 on the adapter PCB — software HPD control is a
gateware-only change; 49.9Ω pull-up terminations on all TMDS lines.
**User I/O (PCB v2):** 6 GPIO lines with active-low buttons (PCB labels
PL_KEY0-5), also on header P1 (pins 1-6, +3V3, GND). PL_KEY[3:0] =
U19/V20/T19/U20 (J7/DATA3). The other two GPIO lines = J9/DATA1 pins 19/17 =
FPGA K17/E19. They are GPIO, not audio: the BD/XDC ports are still named
`AUDIO_L/R` from an old PCB label. From the netlists (Oct 26): PL_KEY4 = K17
(SW6, MRCC clock-capable), PL_KEY5 = E19 (SW5); 10 kΩ pull-ups, no capacitors
(fit for MHz I2C/SPI/UART/I2S via EMIO). Pressed 2026-10-28 (event block, `_pwm`
bitstream): PL_KEY0-3 give events on lines 0-3 in order; the 5th/6th press gave
NOTHING on lines 4/5 (K17/E19) - SW5/SW6 fitted? mapping right? OPEN.
**Fan connectors as I/O (Oct 27 2026, build `fan`, NOT yet on hardware):**
BD ports J3P3_INPUT/J5P3_INPUT -> GPIO 0x4120_0000 ch1 [15]/[16] (raw, active
low; the GPIO change interrupt GIC 66 covers them), J3P4_OUTPUT/J5P4_OUTPUT
<- hdmi_audio_regs IO_OUT (0x43C6_0044) [9:8] opto on (= pin 4 low), [11:10]
pin 4 = VTC vsync pulse (frame sync to other units). Reset = optos off.
debazd `/fan/{3,5}/{in,out,vsync}`. **J3 hardware PWM (build `pwm`, Oct 27
2026, simulated only):** IO_OUT [13] selects it; 0x90 PWM_CTRL ([23:0] period
in 10 ns counts, [30] invert = active pin 4 high, [31] restart at each vsync
start), 0x94 PWM_DUTY (active counts, taken at the period start), 0x98 ID
"PWM1". J5 = level / vsync (+ software PWM). `sw/debazd/pwm.c`: `/fan/<n>/pwm
hz duty`, `/fan/<n>/duty`, `/fan/<n>/servo pos [min max]` use the hardware on
J3 (>= 6 Hz, if the ID reads) and an RT software thread otherwise
(`/fan/pwm/stats`; spins the last 100 us at <= 200 Hz). dz_field_write now holds one mutex (fields share registers; the PWM
thread writes IO_OUT).
**Function select (Oct 27 2026, branch hdmi-audio, simulated — NOT yet on
hardware):** `hw/rtl/pl_io/` (module ref `pl_io_0`, IOBUFs; the BD ports
PL_KEY/AUDIO_L/AUDIO_R are now inout, names unchanged) gives each line one of:
in (reset default = as before), out, PS I2C0 SCL/SDA (open drain), PS SPI0
SCLK/MOSI/MISO/CS0/CS1, PS UART0 TXD/RXD, PL I2S master BCLK/LRCLK/DOUT/DIN
(16 in 32, 48 kHz, NCO on FCLK0 steered by the TX FIFO level; DOUT = HDMI_2
audio, DIN can replace the loop as HDMI_1 audio). PS7: I2C0/SPI0/UART0 on
EMIO (XSA change; no FSBL change needed for EMIO routing). Registers
0x43C6_0040-54 (in hdmi_audio_regs, address bits 7). GPIO 0x4120_0000 ch1
[5:0] still reads the line levels. debazd: `/io/pin <n> <name>`, `/io/pins`,
fields `/io/func|out/<n>`, `/io/level`, `/i2s/...`. Linux (needs a PetaLinux
rebuild): i2c0, spi0 (spidev 0.0/0.1), uart0 = ttyPS1 nodes + kernel fragment
`user_2026-10-27-plio.cfg` + i2c-tools. Sim: `sh hw/sim/run_pl_io_tb.sh`.
Lines 0-3 = PL_KEY[3:0], 4 = AUDIO_L (K17), 5 = AUDIO_R (E19). Keep all 6 live in every variant —
see ROADMAP.md "User I/O". Fleet use (2-12+ units, network control first)
is in ROADMAP.md "Fleet".
**Other board I/O (traced EBAZ4205 schematic, Oct 26; details ROADMAP.md
"PS buttons and reset" + §11):** S2 = PS MIO 20 (S3, not fitted = MIO 32),
active HIGH with 10 kΩ pull-down — the PS7 internal pull-up fights it (TODO).
Reset button = U65 SGM706 ~MR pin 1 to GND (resets PS_POR_B + PHY). Fan
connectors J3/J5 = 12 V opto level shifters, NOT isolated (GND3 tied to GND
by L36): pin 4 out (U12 J3, V12 J5; inverted open collector), pin 3 in (V13
J3, V15 J5; active low), a few kHz max — triggers, relays, servo PWM,
contact inputs, a vsync pulse between units. MIDI/DMX/RS485 need UART0 on
PL_KEY + an add-on board. SD0 = MIO 40-45 (CD MIO 34); NAND W29N01HV on the
SMC (MIO 0, 2-14) = /dev/mtd0; no QSPI. Factory NAND dump: `original_flash/`.
Debug bits readable at 0x4120_0000 GPIO ch1 (see address map; verified in BD
Oct 2026). `sw/tools/capstat.sh [-w ms]` decodes them + capture DMASR + a
frame-content checksum. Requires FCLK3 = 200 MHz
(see the FSBL clock trap above). hdmi2.elf CaptureInitialize prints per-step
diagnostics; stdout is unbuffered so prints survive crashes.

**Hot-plug delay/freeze — FIXED Oct 2026 (ROADMAP.md §1):** replug used to
take 17-45 s (looked frozen). Cause: dvi2rgb alignment sweep waits
`kBlankTimeoutMs` per IDELAY tap per bitslip (10×32×50 ms = 16 s per sweep;
a marginal source fails several sweeps). Fix: `IP_dvi2rgb/src/DVI_Constants.vhd`
kBlankTimeoutMs 50→2 (sweep ≈0.64 s), IP coreRevision 12. Verified: frames
resume within 250 ms of pLocked. Remaining (robustness only): capture resets
still hang off the OUTPUT dynclk LOCKED; `vid_io_in_reset` tied 0; pLocked =
MMCM lock only. Latched S2MM SOF/EOL errors are non-fatal (c_flush_on_fsync=1);
the ELMO presenter source latches them every frame (not exactly 1280×720).
Edit packaged-IP RTL in `IP_dvi2rgb/` (NOT IP_rgb2dvi, NOT ipshared copies),
then `hw/repackage_ip.tcl IP_dvi2rgb` + `hw/build.tcl` (the old
`tools/vivado/dvi2rgb_rebuild.tcl` needed the legacy project; removed).

**VDMA driver fork fix (Aug 2026):** the hacked XAxiVdma_ReadReg/WriteReg in
jerkspace hdmi2 used to DISCARD the channel base address, collapsing every
access onto MM2S offsets — invisible for the MM2S-only display VDMAs, fatal for
S2MM. Now they apply (BaseAddress − mm_IP base); the 0x50/0x54/0x58/0x5c
hardcoded offsets were reverted to stock relative macros. Do not reintroduce
absolute offsets in that driver.

### IRQ chain
`HDMI_0` concat (In0 v_tc, In1 VDMA, In2 GPIO, In3 capture S2MM, In4 PCM, In5
events) → `HDMI_1` concat (In0 tied 0, In1 HDMI_1 VDMA, In2 spare, In3 = HDMI_0's
6 bits) → PS IRQ_F2P[8:0]. IRQ_F2P[7:0] = GIC 61-68, [8] = GIC 84; DT number =
GIC − 32: VTC <0 32 4>, GPIO 34, HDMI_0 VDMA 33, HDMI_1 VDMA 30, capture 35, PCM
36, events 52. Table + generic-uio nodes: overlay `hw/dt/ebaz4205_2out1in.dtso`
(dtc: `~/Xilinx/Vitis/2022.2/bin/dtc -@`). Linux used none of them until then:
debazd polled. With the overlay, debazd's vsync thread sleeps on the VTC
interrupt (`dz_vsync_wait`, sets VTC IRQ_ENABLE = bit 13 only), else it polls.
**Events (build `ev`, Oct 27 2026, simulated only):** hdmi_audio_regs page 1
(0x43C6_1000, own 4K for a UIO node; ID "EVNT"; dz_map probes it, since older
bitstreams alias page 1 onto page 0): sources [0] J3 pin 3, [1] J5 pin 3, [7:2]
user I/O lines, [8] vsync; RISE/FALL enables, PEND (W1C), IRQ_EN, 100 MHz
EV_TIME, timestamps of the last J3 / J5 / line / vsync edge, HDMI_0 DDS phase
now and at the last vsync. Map in hdmi_audio_regs.v; debazd `/ev/...`,
`/dds/0/phase`, `/dds/0/phase_vs`. LED_RED (W14, maybe not fitted) = IO_OUT
[12], `/led/red`.

### Address map (PS view)
(verified against live BD, Aug 2026 — several old entries are GONE; poking a
removed address bus-errors with SIGBUS "external abort", which crashed hdmi2)

| Base | Block |
|---|---|
| 0x4120_0000 | axi_gpio_hdmi_in_phase0_div_gPhase1 (renamed Aug 2026): ch1 @+0 INPUT = {[9:8] HPD[1:0], [10] pLocked, [11] aLocked, [12] vid_in overflow, [13] underflow, [14] fid; [7:0] dangling}; ch2 @+8 OUTPUT (default 0x0100_0000) = {[31:24] HDMI_0 DDS-phase divider den, [23:0] HDMI_1 gPhase} |
| 0x4121_0000 | HDMI_0 axi_gpio_mainG_shift_memdelay (ch1 also feeds HDMI_0 DDS-sine divider den via slice) |
| 0x4123_0000 | HDMI_1 axi_gpio_divOsc_gosc_shiftPhaseOsc (dual all-out, ch1 default 0x0101_0101; osc dividers + gains + shifts) |
| 0x4126_0000 | HDMI_1 axi_gpio_divPhase_gmain_shiftPhase_gfeedback (ch1 default 0x01FF_FFFF, ch2 default 0x0080_8080) |
| 0x4300_0000 | HDMI_0 VDMA (MM2S) |
| 0x4301_0000 | HDMI_1 VDMA (MM2S) |
| 0x4302_0000 | HDMI_2 capture VDMA (S2MM only, 3 fstores; S2MM regs at +0x30/+0xA0..AC) |
| 0x43C2_0000 | v_tc (shared, lives in HDMI_0) |
| 0x43C4_0000 | axi_dynclk |
| 0x43C5_0000 | HDMI_0 mixer_0 (the "nuMixer") |
| 0x43D0_0000 | dds_axi_interface_0 → HDMI_0 DDS phase increment |
| 0x44D0_0000 | dds_axi_interface_1 → HDMI_1 DDS phase increment |
| 0x43C6_0000 | hdmi_audio_regs_0 (Oct 26 2026, branch hdmi-audio; ps7_axi_periph M12, NUM_MI 12→13): HDMI audio TX ctrl / RX status, ID 0x3C = "HAUD". Not in bitstreams before it: dz_map probes the ID under a SIGBUS guard |

REMOVED (do not touch): 0x4122_0000, 0x4124_0000 (old LED GPIO — LED is
xlconstant-driven now), 0x43C3_0000 (HDMI_1 VTC), 0x43D1_0000, 0x44D1_0000.

VDMA memory ports: HDMI_0 → S_AXI_HP0, HDMI_1 → S_AXI_HP2, HDMI_2 capture → S_AXI_HP1
(all 256M window at 0). Capture writes slot 4 = 0x09FA_4000.

### Custom IP register maps

**mixer 2.0** (`ip_repo/mixer_1_0/hdl/mixer_v1_0.v`, 0x43C5_0000): 9 output channels
("gain planes"), register index = `chan*10 + n` (word addressing, so byte offset =
(chan*10+n)*4):
- n=0..4: GAIN_chan_0..4 (weights for din0..din4)
- n=8: CTRL_chan_0 — [7:0] mode, [31:16] constant value K
- n=9: CTRL_chan_1 — [0] stream select (0 = stream A din0/1/2, 1 = stream B
  din5/6/7; per-channel, added Aug 2026), [23:16] threshold lo, [31:24] threshold hi

Modes: 0=zero; 1=Σ gains[n]·din[n]; 3={din,8'hff} passthrough; 4=constant K;
0x10/0x11/0x12/0x13 = clip din (≥lo / ≤hi / ==lo / band) → {din,0xff} else 0;
0x20/0x21/0x22/0x23 = same comparisons but output K else 0.
Comparison/passthrough source: chans 0-2 use din0 (R), 3-5 din1 (**B**, lane
[15:8]), 6-8 din2 (**G**, lane [7:0]) of the selected stream (A: din0/1/2; B:
din5/6/7). The RTL calls din1 "G" — the bus is RBG, see HDMI_0 effects. Mode 1 multiplies the selected
stream's R/G/B in the gains[0..2] slots; din3/din4 (DDS) are never muxed.
The 9 always blocks were collapsed into one generate loop (Aug 2026);
select bit 0 = old behavior, bit-for-bit.
Output→matrix wiring: dout0→g_rr, dout1→g_br, dout2→g_gr, dout3→g_rg, dout4→g_gg,
dout5→g_bg, dout6→g_rb, dout7→g_gb, dout8→g_bb.
(dout7 ctrl[6]-vs-ctrl[7] copy-paste bug: FIXED and verified Aug 2026.)
Multiply path is unregistered single-pixel-clock — a likely timing
limiter at higher pixel clocks.

**Colour matrix math (traced from the BD, Oct 26 2026; confirmed on the board
by `/fx/matrix` readback):** the matrix multiplies **HDMI_0's own video**; the
mixer (fed from HDMI_1's pixel) only supplies the 9 gains.
out = (Σ in·gain) >> 16, so gain 0x10000 = 1.0; mode-4 K is 16 bits, max 0xFFFF
= 0.99998. xbip_multadd A/B are UNSIGNED (no negative coefficients) and the
24-bit sums do NOT saturate: a row sum > 1.0 wraps bright pixels to dark.
Channel per entry (true R/G/B, out row × in column): out R ← R ch0, G ch2,
B ch1; out G ← R ch6, G ch7, B ch8; out B ← R ch3, G ch4, B ch5 (the boot
setup's diagonal = chans 0/7/5). `sw/debazd/fx.c` (`/fx/hue`, `/fx/matrix`,
`/fx/map`, `/fx/identity`, `/fx/wrap`) writes these as mode-4 constants; hue
rotation clips the negative terms and normalises rows (exact at 0/120/240°,
less saturated between).

**Colour key + register-file slim-down (mixer coreRevision 22, Oct 26 2026 —
key WORKS on hardware 2026-10-28, `_pwm` bitstream: `/fx/key/source 1` + `/fx/key/color
0x00FF00` replaced exactly the green bar of HDMI_0's bars with HDMI_1's picture):** per channel CTRL_1 [1] KEY = this
channel's lo..hi band joins the key mask (AND of all joined bands; lo > hi =
outside hi..lo), CTRL_1 [2] SRC = compare HDMI_0's video (vid_in) instead of
HDMI_1 — also for modes 3/0x1x/0x2x. Globals in channel 0 CTRL_0 [15:8]: [8]
invert mask, [9] fill from stream B. Key on = any KEY bit. Keyed pixel = HDMI_1's
pixel instead of the matrix result. The box for a 24-bit colour = ch0 (R lane),
ch3 (B lane), ch6 (G lane); KEY is independent of the channel's mode, but a
joined channel's clip mode uses the same lo/hi. New ports bg_in (matrix
result) / vid_in (HDMI_0 vid_data) / pix_out; mixerMatrix/dout = pix_out,
registered ALWAYS (1 px later than before, also with the key off; it also cuts
the HDMI_0 → HDMI_1 feedback cone after the matrix). All new bits 0 = old
behaviour (old bitstreams store and ignore them). The duplicate output-register
stage of `mixer_v1_0_S00_AXI.v` (63 × 32-bit copies on the same AXI clock) is
now continuous assigns (measured −311 FF, slices 4302 → 4209: synthesis had merged most copies already). `hw/sim/run_mixer_tb.sh`: the new mixer equals the
4e2d1820 mixer on 12,000 random pixel clocks × 9 channels (all modes, random
gains/thresholds/streams), plus directed key tests. OSC: `/mixer/<c>/key`,
`/mixer/<c>/src`, `/key/invert`, `/key/stream`, `/fx/key/color 0xRRGGBB [tol]`,
`/fx/key/range lo hi`, `/fx/key/source i`, `/fx/key/off`.

**HDMI audio (branch `hdmi-audio`, Oct 26 2026 — WORKS on hardware: out, in,
loop; laptop i915 needs a >= 15 s unplug after PL reloads (HPD storm → polling); details ROADMAP.md §11 "HDMI audio out"):** ONE format, 48 kHz
2-ch 16-bit L-PCM (media is pre-rendered).
- Output: BOTH rgb2dvi are replaced by `hw/rtl/hdmi_tx/hdmi_tx.v` (module
  refs HDMI_1/hdmi_tx_0 Oct 26, HDMI_0/hdmi_tx_0 Oct 27; rgb2dvi is no longer
  used). Each has its own ctrl (HDMI_1 TX_CTRL 0x00, HDMI_0 TX0_CTRL 0x0C) and
  audio source (pl_io: HDMI_2 loop or I2S DIN, i2s_ctrl[2] HDMI_1 / [4]
  HDMI_0); TX_FS_INC is shared (one pixel clock). The island scheduler has a
  register stage (Oct 27): worst hdmi_tx path 10.05 ns routed, +3.4 ns at
  720p60 (was 12.58 ns); latency LOOK + 5 = 15 px.
- HDMI_2 hot-plug (Oct 27; WORKS on hardware Oct 28: laptop re-locked 0.75 s after
  HPD high, EDID re-read): HDMI_HPD_2 = ~RX_CTRL[2] (was an xlconstant 1;
  reset = high as before). `/capture/replug [s]` pulses it low: the source
  re-reads the EDID and redoes its mode set (use 12 s if the source fell back
  to polling after an HPD storm). `/hdmi/2/hpd_low` = the raw bit.
- 48 kHz rate setting: debazd (audio.c) sets `/audio/tx/fs_inc` from the
  measured frame rate x VTC GHSIZE x GVSIZE once vsync runs (`/audio/fs`,
  `/audio/fs/auto 0` = hands off). ALSA card design: ROADMAP.md section 13. ctrl = 0 → DVI, symbol-identical to rgb2dvi (simulated against
  a copy of TMDS_Encoder.vhd), latency +10 px for sync and data together.
  HDMI: data islands placed from the incoming VTC timing (line length from
  HSYNC edges, active width from DE, 10-px look-ahead); AVI + Audio InfoFrame
  from a generated ROM (`gen_rom.py` → `hdmi_tx_rom.v`, ECC included); ACR
  (CTS measured) + 1-sample Audio Sample packets; test tone on an NCO.
- Input: dvi2rgb fork rev 13 exports `pRawSym[29:0]` (bonded 10-bit
  symbols). ⚠️ dvi2rgb calls every non-control symbol video (DE = 1 in data
  islands and guard bands) and keeps stale syncs inside islands (HSYNC lies
  inside the island at 720p): `hw/rtl/hdmi_tx/hdmi_rx.v` sits between
  dvi2rgb and v_vid_in_axi4s, classifies periods from the preambles (DVI
  source = unchanged), takes syncs from TERC4 in islands, extracts Audio
  Sample + ACR packets (BCH checked), status → regs, loop → async FIFO →
  hdmi_tx aud_* (rx_ctrl[0]). EDID (`hw/edid_audio.py`): + basic audio,
  Audio Data Block (only 48 kHz 16 bit 2 ch), HDMI VSDB — without the VSDB a
  source sends DVI.
- Registers 0x43C6_0000: 0x00 TX_CTRL (HDMI_1: [0] HDMI, [1] audio, [2] tone,
  [9:8] AVI VIC 4/34/16/none), 0x04 TX_FS_INC (720p60: 2776544, both outputs),
  0x08 RX_CTRL ([0] loop, [1] clear peaks), 0x0C TX0_CTRL (HDMI_0, as TX_CTRL), 0x10 RX_STATUS, 0x14 samples, 0x18 peak R|L, 0x1C N,
  0x20 CTS, 0x3C ID. OSC fields `/audio/...` (`sw/lib/dz_fields.c`).
  RX_CTRL [2] = HDMI_2 HPD low. 0x40-0x54 = pl_io (user I/O + I2S).
- **Linux PCM for an ALSA card (2026-10-27, build `pcm`, simulated only):**
  0x60-0x8C, 3 playback FIFOs (HDMI_0, HDMI_1, I2S DOUT) + 1 capture FIFO
  (HDMI_2), BRAM 512 x 32 each, paced by a 48 kHz NCO on FCLK0; IRQ =
  HDMI_0/In4 = GIC SPI 36 (`<0 36 4>`); routing I2S_CTRL [6]/[5]/[7].
  Register table + driver sequence: ROADMAP.md §13. Sim: `sh
  hw/sim/run_pl_io_tb.sh` (pl_io_tb + pcm_tb). Kernel driver not written yet.
- Sims: `sh hw/sim/run_hdmi_tx_tb.sh` (7 × ALL PASS: TX 4 modes, regs, RX
  loop DVI + HDMI). ⚠️ `hw/repackage_ip.tcl <ip> ports <top>` DROPS non-HDL
  files of an IP (dvi2rgb's EDID/xdc/xci): the script now refuses; add the
  port element by hand for such IPs.

**dds_axi_interface** (`hw/rtl/dds_axi_inteface.vhd` — note
filename typo): single 32-bit reg at +0. Bit31 = TVALID enable, bits[30:0] = phase
increment to dds_compiler (100 MHz, 32-bit phase acc → f = PINC × 100e6/2³² ≈
0.0233 Hz/LSB; PINC 0xa11 ≈ 60 Hz). Reg +0x4 (slv_reg_4 bit0; ADDR_LSB=2, index 1)
reads back TVALID status (+0x10 was wrong). Reg +0 reads back. **A PINC written without
bit 31 is ignored** — always write 0x8000_0000 | PINC (dz_fields does).

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

**hdmi2.elf** (source now `sw/hdmi2/` in this repo, plain Makefile, Oct 2026 —
moved from Vitis/hdmi2, identical to jerkspace/hdmi2 at the move; main =
`src/colorbars/display_demo.c`): Linux userspace app that runs once at startup to set
display timing and init PL. Reuses Xilinx baremetal drivers (xaxivdma v6_10, vtc v8_4,
Digilent dynclk/display_ctrl) on Linux by mmapping /dev/mem (`src/IP_Driver.c`,
`mm_IP` struct). Default mode 1280x720@30 both channels. Framebuffers: physical
0x0800_0000, 2 frames per display, frame size `DEMO_MAX_FRAME = 1920*1080*4`;
disp0 frames 0-1, disp1 frames 2-3. Has vestigial commented-out UDP server (port 8888)
and a menu mode (`-m`). CLI: `-r <res>`. Note: `TimerDelay` via scutimer SEGVs (commented
out); LED GPIO hardcoded 0x41240000 (removed block; the code is commented out).
⚠️ Boot mode (no `-m`, as debazarosit.sh starts it) runs "Loop furever": it redraws
display 1's frame (slot 2) EVERY 10 s — with only 16 MB reserved that is 3.4 MB of
Linux RAM (see Device tree). sw/hdmi2 now refuses frames outside reserved memory
and moves the capture to slot 1 when slot 4 is not reserved.

**Device tree — NEW (2026-10-25):** the only dtsi is now
`PetaLinux/project-spec/meta-user/recipes-bsp/device-tree/files/system-user.dtsi`
(96 MB, one simplefb 1280x2160, fpga-full region, NO PL nodes via
`CONFIG_SUBSYSTEM_REMOVE_PL_DTB=y`; the root copy was removed). The running board
(Jan 2025 image + `/boot/system.dtb` 96M) still binds xilinx-vdma to the display VDMAs,
xilinx-vtc, and has stale audio_formatter/i2s/mixer1-8 nodes until the new image is
deployed. History of the old dtsi:
**Device tree** (old root `system-user.dtsi`): reserved-memory `removed-dma-pool`
**128 MB** @0x0800_0000 in the REPO (no-map, `reg = <0x08000000 0x08000000>`, commit
45a668cb, Jul 2026) — that value FAILS on this U-Boot (see below); use 96 MB. Until 2026-10-24 **the bench board ran 16 MB** (verified Oct 2026:
/proc/device-tree reg = 0x08000000 0x01000000, /proc/iomem System RAM 0x0900_0000+):
the 128 MB dtsi was never built into its image. So slots 2-5 (0x08FD_2000+) are Linux
RAM, and capture slot 4 + hdmi2's display-1 redraw + any slot 2-5 writer corrupted
running programs (seen: malloc heap corruption; probable cause of the "mysterious
full-board hangs"). FIXED + VERIFIED 2026-10-24: `PetaLinux/dtb/system-96M.dtb` = /boot/system.dtb
(iomem hole 0x0800_0000-0x0DFF_FFFF, /dev/fb0 ok, 6/6 slots, capture back in slot 4). ⚠️ 128 MB (`<0x08000000 0x08000000>`, as in the repo dtsi) is
REJECTED by the kernel on this board — region reaches top of RAM where U-Boot puts the
DTB blob (-EBUSY for no-map) → NO reservation at all, simplefb fails -12, no /dev/fb0,
while /proc/device-tree still shows the node. Use 96 MB; check the HOLE in /proc/iomem,
not the DT node. Guards (dz_map, fbfeed, hdmi2) now also check /proc/iomem.
Was: `PetaLinux/dtb/system-128M.dtb` (running
DTB, one line changed) → copy to `/boot/system.dtb` (boot.scr prefers it over BOOT.BIN's
DTB), reboot. Until then the running capture was moved to slot 1, and debazd / fbfeed /
sw hdmi2 refuse slots outside the running reservation. simple-framebuffer 1280×2160 (3×720 stacked frames!)
a8r8g8b8 → `/dev/fb0` (ffmpeg writes top 720 lines = disp0 frame 0). bootargs:
`clk_ignore_unused cma=256M uio_pdrv_genirq.of_id=generic-uio`, root mmcblk0p2.
UIO nodes (running board): 0x4120_0000 (with IRQ, GIC 66), 0x4121_0000, 0x4123_0000,
0x43C5_0000, plus STALE nodes for removed blocks 0x4122_0000 and mixers 1-8
(0x43C6_0000-0x43CD_0000) — any access = bus error. 0x4126_0000 has no UIO node.
sw/lib/dz_map maps only blocks listed in hw_map.h.

**Two independent framebuffers — MEASURED on hardware, Aug 2026:**

⚠️ **`simplefb` allows exactly ONE instance system-wide.** Confirmed on the target
(5.15.36-xilinx-v2022.2): a second `simple-framebuffer` node probes and is rejected with
`simple-framebuffer 8384000.framebuffer1: simplefb: a framebuffer is already registered`.
The cause is upstream commit "fbdev: Prevent probing generic drivers if a FB is already
registered" (Javier Martinez Canillas, 2021), present in the Xilinx 5.15 LTS rebase:

```c
	if (num_registered_fb > 0) {
		dev_err(&pdev->dev, "simplefb: a framebuffer is already registered\n");
		return -EINVAL;
	}
```

Its intent was "do not probe a generic FB driver when a real one already bound"; blocking
multiple simplefb instances is a side effect. Multiple nodes are legal in the *binding* —
only this driver check forbids them. Do not repeat this test unpatched.

Second, independent bug in that same test: the node was placed at 0x0838_4000 (the "stacked
fb rows" address). Display 1 does NOT scan out there. Both displays park on frame index 0
(`curFrame = 0` + `XAxiVdma_StartParking`), so disp0 = 0x0800_0000 and
**disp1 = 0x08FD_2000** (= 2 × DEMO_MAX_FRAME). Each 1280×720, stride 1280·4
(`display_ctrl.c:363` sets VDMA stride = width·4). Even if simplefb had allowed the second
node, fb1 at 0x0838_4000 would have shown nothing.

Ways to get two independent surfaces, cheapest first:

1. **Patch out the `num_registered_fb` guard** (5-line deletion, kernel patch in
   `meta-user/recipes-kernel/linux/`), two DT nodes at 0x0800_0000 / 0x08FD_2000. No Kconfig
   change (`CONFIG_FB_SIMPLE=y` already). Per-frame kernel overhead: zero — simplefb has no
   IRQ and no per-frame work. **Recommended.**
2. **No kernel change at all**: keep one fb0, write disp1's slot through `sw/fbfeed/`
   (mmaps `/dev/mem` at 0x08FD_2000, or `/dev/fbN` at a byte offset; fed by
   `ffmpeg ... -pix_fmt bgra -f rawvideo pipe:1`). Same copy cost as the fbdev muxer.
   `/dev/mem` on a no-map region maps **uncached** on ARM — run `fbfeed -v` and check the
   MB/s before trusting it. If too slow, grow fb0 to 1280×3960 (row 3240 = 0x08FD_2000)
   and feed both displays through `/dev/fb0` at offsets, which is write-combined.
3. **`simpledrm`** (no singleton check; `devm_aperture_acquire_from_firmware` per range, so
   two instances are fine): swap `CONFIG_FB_SIMPLE` → `CONFIG_DRM_SIMPLEDRM` +
   `DRM_GEM_SHMEM_HELPER` + `DRM_FBDEV_EMULATION`. Costs one extra full-frame blit per flush
   (`drm_fb_blit_rect_dstclip` from the shadow plane) ≈ 3.69 MB/frame/display, ~220 MB/s at
   720p30 ×2, plus deferred-IO faults. Gives no real mode setting. Already tried and backed
   out in 2023: `user_2023-03-13-15-42-00.cfg` enables it, `user_2023-03-13-17-53-00.cfg`
   disables it and selects `CONFIG_FB_SIMPLE=y`.
4. **Real DRM/KMS (`xlnx,pl-disp`)** — a project, not a config change. `DRM_XLNX_PL_DISP`
   depends on `XILINX_FRMBUF` (the frame-buffer-read IP that once broke the Vivado build);
   it takes a dmaengine channel named `dma0` + `xlnx,vformat`, and does NO clock work.
   Timing needs the `xlnx,bridge-v-tc-6.1` VTC bridge (`DRM_XLNX_BRIDGE_VTC`), which demands
   `s_axi_aclk` + `clk` as CCF clocks — axi_dynclk is not a CCF provider, so a `fixed-clock`
   stub (or a new clk driver) is required, and DRM could not change resolution. An
   encoder/connector must also be invented, since rgb2dvi has no I2C/EDID. hdmi2.elf would
   have to stop touching the VDMAs and VTC. Note ffmpeg has no KMS output, so through fbdev
   emulation this path is *slower* than option 1.

## Third HDMI/DVI port (hard constraint)

The adapter PCB (`pcb/3xHDMI/`) has a **third TMDS pinout laid out** — future input or
output. Therefore: **never remove memory or bus capacity that accommodates a third
frame/channel**: keep VDMA `c_num_fstores = 3`; keep spare ps7_axi_periph `M**_AXI` ports
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
what PG044 suggests for this use. Below, modes are named by behavior;
`C_VTG_MASTER_SLAVE` is the Xilinx parameter that selects them:
- **VTC-pausing mode (`C_VTG_MASTER_SLAVE=0`) PAUSES the VTC via vtg_ce during alignment**
  (`gen_fifo_vtg_en_slave_mode` gates VTG_EN in CALN/lagging states; `vtg_lag` counter
  gives up → IDLE → retries forever). With gen_clken tied high the VTG never lags, and
  since VDMA and VTG frame rates are identical the bad phase repeats deterministically —
  a channel either locks by boot-time luck or never locks at all.
- **Free-running-VTC mode (`C_VTG_MASTER_SLAVE=1`) holds VTG_EN = VID_CE constantly** and aligns by
  dropping FIFO data (EOL/SOF slip) — works fine with a free-running/shared VTC. The
  original two-VTC design used this mode with vtg_ce effectively always high.
- The output formatter **zeroes hsync/vsync/DE whenever not LOCKED** — an unlocked
  vid_out gives "no signal" on the monitor (not black), only the TMDS clock lane runs.

**Correct shared-VTC config: both vid_outs in free-running-VTC mode (`C_VTG_MASTER_SLAVE=1`)
+ VTC gen_clken tied 1** (or wired to either vtg_ce — equivalent, this mode never
deasserts it). Behavior:
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
`devmem 0x41210000 32 0` blacks out BD HDMI_0's output (restore **0x01ffffff**: bits
[31:24] are the HDMI_0 sine divider den, and den=0 sticks the oscillator at 0xFFFF —
the board was found in that state, Oct 2026).

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
moves. In free-running-VTC mode, "no signal" ⇔ not locked ⇔ usually no stream SOF (VDMA not
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
- DONE Oct 2026: app code is in `sw/` with plain Makefiles (`sw/README.md`): `debazd`
  (hardware daemon, OSC/UDP 9000: fields, display routing `/disp/<d>/show|home|capture`,
  capture status, `/subscribe` events, drawing), `dzctl` (OSC client, board + laptop),
  `libdz` (`sw/lib`), `hdmi2` (bring-up), `fbfeed`. Remote gdb via VS Code
  (`sw/tools/vscode/`). Tested on the board.
- **`sw/oscreg/` (Aug 2026) — DEPRECATED Oct 2026, replaced by debazd/libdz. Never deploy:
  its table uses removed blocks (0x4122_0000, 0x4124_0000, 0x43D1_0000, 0x44D1_0000 → SIGBUS)
  and swaps the G/B lanes. Its local build was x86 (CC ?= bug). History only:**
  One `oscreg_field` table maps each OSC address to base+offset+bit range; UIO is tried
  first (matching `/sys/class/uio/*/maps/map0/addr` against the base) and `/dev/mem` is the
  fallback, so the dtsi generic-uio nodes are used when present. 121 endpoints:
  `/hdmi/{0,1}/gain/{r,g,b,rgb}`, `/hdmi/1/{dds,fb/a,fb/b}/*`, `/dds/{0,1}/{hz,pinc,enable,offset}`,
  `/mixer/0..8/{gain/0..4,mode,k,stream,lo,hi}`, `/led`, plus `/get`, `/list`, `/ping`.
  Arg rule: int = raw register value, float = 0..1 across the field (Hz for `/dds/*/hz`).
  Writes are read-modify-write against a shadow word, because mode+K, stream+lo+hi and
  R+G+B share one register. ⚠️ Do not run it at the same time as the devmem loop in
  debazarosit.sh — both write the same words and the shadow will fight the shell script.
- **`sw/oscreg/oscdraw.{c,h}` (Aug 2026): drawing/playback layer on the same OSC port.**
  A "surface" = one VDMA frame slot (0x0800_0000 + n × DEMO_MAX_FRAME, n = 0..3).
  **Surface 0 = display 0, surface 2 = display 1** (both park on frame index 0);
  surfaces 1 and 3 are the back slots and are not scanned out until someone calls
  DisplayChangeFrame. Each surface keeps a cached shadow buffer; draws hit the shadow and
  `present()` copies only the dirty rectangle to the slot, because the slot is uncached
  (/dev/mem) or write-combined (/dev/fb0) and terrible for read-modify-write. It probes
  /dev/fb0 via FBIOGET_FSCREENINFO and uses it when smem covers the slot, else /dev/mem.
  Ops: solid (rect optional = whole screen), gradients (h/v/angle/4-corner), rect, square,
  circle, ellipse (filled or outline), per-surface alpha, image load and movie play
  (both shell out to ffmpeg; movie pipes into `sw/fbfeed`, runs in its own session, and any
  later draw stops it). File args are a bare name inside `/home/ebaz/{img,movies}` —
  no slashes, since the port is on the network. `/surface/<n>/save` dumps a PPM for
  debugging. Every op is also a plain C entry point, for scripting or a future GPIO poller.
- **Framebuffer geometry trap**: hdmi2 slot pitch = DEMO_MAX_FRAME (1920·1080·4 ≈
  8.29 MB, disp0=slots 0-1, disp1=slots 2-3) but dtsi fb0 = 1280×2160 = 3×720p at
  3.69 MB pitch — fb0 rows 720+ land mid-slot-0 (rows 1620+ spill into disp0 slot 1),
  NOT in a second frame, and never reach disp1 at 0x08FD_2000 (fb0 ends at 0x08A8_C000).
  Unify in one memory_map.h (keep 1080p pitch, 6 slots for 3 displays, fb0 = slot 0 only)
  — done for sw/ in `sw/lib/dz_hw.h`. Needs the 128 MB reservation on the board (see
  Device tree: the bench board still runs 16 MB).
- MEASURED Oct 2026: slot WRITES via /dev/fb0 ≈ 630 MB/s and via /dev/mem ≈ 660 MB/s (not
  slow); fbfeed through a pipe ≈ 25 fps @720p (pipe-limited); ffmpeg mpeg4 720p: decode
  36 fps, +bgra 20 fps, +uyvy422 6 fps. ffmpeg's yuv→rgb has no ARM fast path: debazd
  /movie now pipes yuv420p into `fbfeed -y` (NEON, sw/lib/dz_yuv.c, BT.709 default):
  two 720p movies at once 12.5 fps each (was 7). Decode is now the limit. A PL YUV→RGB
  converter was considered: needs packed 4:2:2 (ffmpeg's packing is too slow), BRAM 96%
  and DSP 91% used — only a LUT version in the AXIS (FCLK2) domain would fit.
- Video painter (Oct 2026, sw/lib/dz_draw.c, ex-oscdraw): + brush (soft stamp), stroke,
  line, fade (NEON, fused with present), blend normal/add/lighten/multiply, grab (copy a
  slot, e.g. capture 4, into the paint buffer), peek. Light painting with trails: 35 fps
  idle, 16 fps with a movie on the other display (fade is DDR-bandwidth bound). Demo +
  OSC example: sw/tools/osc_paint_demo.py. Host tests via peek in sw/tools/selftest.sh.
- debazd Oct 24 additions (sw/README.md): 12 slots (11 = black), vsync = VTC ISR bit 13
  (W1C; 60.03 Hz; the display VDMA SR bit 12 is equally exact — vsync_probe uses that one
  so it does not steal debazd's bit), real-time vsync thread applies /disp show/blank/seq
  right after vsync (frame-exact: 30 Hz strobe, 60 fps 5-slot flipbook verified by
  per-frame sampling), lfo.c (16 LFOs, field or "/msg $0 $f1" template targets, every k),
  sprites (dz_sprite.c), text (dz_text.c: Terminus-derived pixel font OFL + stb_truetype),
  transforms (dz_xform.c: double buffer + row-wise present, 22-29 ms full frame idle).
  dzctl: getopt "+" so negative values after the /address work.
- **dzweb (Oct 24, sw/README.md "Web app")**: board-side HTTP + WebSocket→UDP OSC bridge
  (port 8080, runs as ebaz, pages in /home/ebaz/www, `make install` copies them). One UDP
  socket per browser; WS frame = OSC packet. `/units` = LAN /info broadcast, dedupe by MAC
  (all boards share MAC 00:0a:35:00:1e:53 today → only one shows until MACs are unique).
  debazd gained `/fields` and `/files` list queries for it; the UI builds Effects from
  /fields. Not started by debazarosit.sh yet. Media transfer = dzweb HTTP `/media`
  (GET list/file, PUT raw-body upload → .part + rename, DELETE; CORS for other units;
  64 MB disk reserve; nonblocking chunks in the poll loop). Board root fs: 3.8 GB, ~310 MB free. Headless-Chromium testing: `--virtual-time-budget`
  fakes timers (collect timeouts fire early → empty tabs); drive Chromium over CDP instead.
- After a reboot WITHOUT debazarosit.sh the mixer is all mode 0 → HDMI_0 output BLACK
  (the colour matrix multiplies by 0). Apply the mixer setup (debaz-start.sh / onlySetup.sh).
- "ffmpeg -f fbdev /dev/fb0 doesn't work after running the C code" = ROUTING: hdmi2 'a'
  (or /disp/0/capture) parks display 0 on the capture slot, so ffmpeg's slot 0 is not
  shown. `dzctl /disp/0/home` fixes it.
- Coherence between ffmpeg (fbdev WC), C code (/dev/mem uncached), VDMA (DDR direct)
  is inherent — but uncached A9 reads are slow: benchmark before promising
  full-frame 30 fps CPU processing; slow generative layer + PL data plane is the fit.
  Tear-free flip already exists (write off-screen slot → DisplayChangeFrame park).
  VTC IRQ → UIO would give a clean wait-for-vsync primitive later.

## Known issues / future work (user's stated roadmap)
1. **Cleanup + documentation pass** without breaking the fragile Vivado project
   (READMEs are all SDR-era; legacy folders to prune/archive)
2. **Better driver C code** + proper PetaLinux kernel/DTS config (replace devmem pokes
   and /dev/mem mmap with UIO or real drivers; reserved-memory: 128 MB in the repo but
   the board still runs 16 MB — install PetaLinux/dtb/system-128M.dtb; in progress Aug 2026: per-display simple-framebuffer nodes so disp1 gets a
   /dev/fb — building on the PetaLinux machine, not yet run on hardware. Keep the dtsi in
   PetaLinux/ in sync with the repo root; it went stale once)
3. **Gateware stability/usage/timing**: feedback path unstable above ~35 MHz pixel clock
   (720p30 limit) — primary suspect is the BUFR single-region pixel clock (see Clocking)
   plus unregistered multiply chains;
   only HDMI_0 has the mixerMatrix (HDMI_1 uses simpler gain blocks — DSP budget:
   69/80 used, mixer alone = 45); frame-buffer-read IP experiment previously broke the
   build (be careful re-attempting)
4. **Resource budget** (impl_2, Jan 2026): slices 94% (binding), DSP 69/80, LUT 65%,
   FF 54% (19.2k: v_tc ×2 ≈ 6.5k, mixer reg file ≈ 4k incl. a redundant duplicate
   output-register stage on the same clock — REMOVED Oct 26 2026, VDMA ×2 ≈ 2.8k), BRAM 55%. Savings queue:
   shared VTC (above); the dead SDR clock tree (`PS/clk_wiz_128M` etc.) is NOT in
   the Tcl BD any more (only `DivideBy4_25MHz` = ethernet PHY clock on U18 is left;
   FCLK1 64 MHz is unused); the three VDMA memory interconnects lost their
   packet data FIFO + register slice (Oct 27 2026, build `fan`: the VDMA line
   buffers / S2MM store-and-forward and the HP FIFOs do that job); slim mixer register file;
   GPIO/interconnect consolidation (addresses change → update devmem scripts).
   Do NOT trim VDMA fstores (third-port constraint). DSP relief = time-multiplexed
   mixer MACs at 2× pixel clock (45→~23 DSPs, also fixes timing ceiling).

## Build facts
- Vivado 2022.2, part XC7Z010 (EBAZ4205), top `ebaz4205_wrapper`, pblock constraint on SLR0
- Constraints: `hw/xdc/ebaz4205.xdc` (TMDS pins for two
  DVI ports on adapter PCB, HPD/CEC, ethernet GMII, LED W13, 25 MHz clk U18)
- PetaLinux: machine zynq-generic; build with
  `petalinux-config --get-hw-description=<Vivado dir>` then `petalinux-build`;
  package with `--fsbl zynq_fsbl.elf --fpga ebaz4205_wrapper.bit --u-boot`
- XSA snapshots at repo root and in `Vivado/`; latest-good checkpoint
  `Vivado/checkpoint_20250916.dcp` and `debaz4205_wrapper_20250916.xsa`

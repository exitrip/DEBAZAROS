# DEBAZAROS roadmap (written 2026-10-19)

Goal: move the bitstream changes from the one good bench setup into a
repeatable system, so that we can test new hardware. Do the PetaLinux
rebuild one time only, and prepare it for later bitstream variants.

Status words: TODO, DOING, DONE, BLOCKED.

## Order of work and dependencies

| # | Task | Depends on | Status |
| --- | --- | --- | --- |
| 1 | HDMI input hot-plug: find the cause | hardware | DONE (2026-10-19) |
| 2 | Export the Vivado project to Tcl, rebuild it, compare | — | DONE (2026-10-25): Tcl build tested on hardware (outputs, capture, 117/117 register fields, GPIO, ethernet); legacy `Vivado/`, `Vitis/` and SDR folders removed (branch `legacy-vivado-project`) |
| 3 | Capture robustness BD changes (resets, HPD, status bits) | 1, 2 | TODO |
| 0 | **URGENT: reserved memory** (`PetaLinux/dtb/README.md`): 16 MB was too small; 128 MB is rejected by the kernel; 96 MB DTB installed | reboot | DONE, verified 2026-10-24: iomem hole, /dev/fb0, 6 usable slots, capture in slot 4, movie into slot 3 without corruption |
| 4 | XSA export + one PetaLinux rebuild with overlay support | 3 | TODO |
| 5 | C code: no Vitis, plain Makefiles in `sw/` | — | DONE (2026-10-19, `sw/README.md`) |
| 6 | Hardware daemon (mixer, DDS, video out, capture) | 5; capture part needs 3 | DOING: debazd runs on the board (fields, routing, capture status, events, drawing) |
| 7 | Test the OSC drawing layer against the daemon | 6 | DONE: painter, sprites, text, transforms, LFOs, 60 fps flipbook/strobe (2026-10-24, `sw/README.md`) |
| 8 | Variants "3out/0in" and "1out/2in" | 2, 4 | TODO |
| 9 | Web control app (`sw/dzweb`: HTTP + WebSocket to OSC bridge, browser UI) | 6 | DOING: runs on the board, tested with live registers 2026-10-24; media upload/download/delete tested 2026-10-24; not in the boot script yet |
| 10 | Display views: crop, pan, zoom, split of live input or a movie (section 9) | 2 (gateware) | DESIGN (2026-10-24) |

Reason for this order: a PetaLinux rebuild is expensive. All BD changes
that change the XSA (task 3) must be complete before task 4. Task 2 comes
before any BD edit, so that every edit starts from a known Tcl source.

## User I/O: buttons and the P1 GPIO header

Facts (PCB v2 `pcb/3xHDMI`, 2026-09-22, and the XDC):

- 6 buttons SW1-SW6 = `PL_KEY0`-`PL_KEY5`, active low (pull-up to 3V3
  on each line). The same 6 lines go to header **P1** (pins 1-6, pin 7 =
  3V3, pin 8 = GND). P1 is the external hardware I/O connector.
- `PL_KEY0`-`PL_KEY3`: J7 (DATA3) -> FPGA U19, V20, T19, U20 = BD port
  `PL_KEY[3:0]`.
- `PL_KEY4` (J9 pin 19) and `PL_KEY5` (J9 pin 17): J9 = DATA1. These
  are two GPIO lines, FPGA K17 and E19 (the only non-HDMI0 pins in that
  XDC group). An old PCB label called them audio L/R; the v2 layout makes
  them GPIO. The BD/XDC ports still have the old names `AUDIO_L`/`AUDIO_R`.
  Which pin is SW5 and which is SW6: TO VERIFY on a v2 board (press
  SW5/SW6, read 0x4120_0000).
- Readback today: GPIO 0x4120_0000 ch1. `PL_KEY[3:0]` = bits [3:0].
  K17/E19 = bits [7:6] in the live bitstream, bits [5:4] in the
  Tcl-built bitstream.

Rules:

- Keep all 6 lines live and readable in EVERY variant (with the ethernet
  PHY clock, this is part of the shared base of all bitstreams).
- Make all 6 lines one GPIO port: BD/XDC port `PL_GPIO[5:0]` (bits 3:0 =
  today's `PL_KEY[3:0]`, bits 5:4 = K17/E19). Buttons are one use of these
  GPIO lines; P1 is the other. Do it with the task 3 BD changes, then
  freeze the bit positions.
- Make the 6 lines bidirectional, so P1 can also drive external
  hardware. Same address: change GPIO 0x4120_0000 ch1 from all-input to
  tri-state with `C_TRI_DEFAULT = 0xFFFFFFFF` (all inputs at reset).
  Bits [5:0] get `gpio_io_o`/`gpio_io_t` to IOBUFs on the six pins; the
  status bits [14:8] keep only their input path. Data register +0x00,
  tri-state register +0x04. Ch2 (+0x08) does not change.
- Register layout of ch1 after the change: [5:0] `PL_GPIO`, [7:6] spare,
  [9:8] HPD, [14:10] capture status, [31:15] spare (decoder status, task 3).
  No address-map change.
- Bandwidth: the GPIO interrupt is already wired to IRQ_F2P. Use it
  through UIO for events (latency approx. tens of us). Polling by mmap
  costs approx. 0.3-1 us per read. If a sampled stream (kHz-MHz) is
  necessary later: a small PL sampler that writes to DDR. Do not use
  HP1/HP3 for it (third-port rule); use the ACP or GP port.

## Fleet (2-12+ units on a LAN; 50 boards + 20 expanders bought 2026-10)

Network control comes first; local GPIO/buttons come second. Six buttons
are enough for menu + mode on one unit, but not to manage 12 units.

- One image for all units. Unit identity from the ethernet MAC (hostname,
  OSC address). Per-unit config in a small file, not in the image.
- **MAC problem:** the bench board uses `00:0A:35:00:1E:53`, the Xilinx
  default MAC. All boards from the same image will have the same MAC and
  cannot share a LAN. Give each board its own MAC: U-Boot `ethaddr` from
  the Zynq DNA or the SD card serial (locally administered, `02:xx:...`),
  or a per-card `uEnv.txt` (boot.scr already imports it).
- Discovery: mDNS (avahi) or an OSC broadcast "hello".
- OSC namespace per unit plus group addresses (all units, groups).
- Multi-unit UI (selection, spreads, hub), shared show clock, timed
  OSC bundles, movie transport: design in `FLEET.md` (2026-10-24), tasks
  F1-F8. No genlock between boards: best case is about one frame.
- Bitstream variant per unit through the fpga_manager overlays (task 4).
- Incoming hardware test (50 boards): one script that does a boot check,
  a PL load, ethernet, DDR, both outputs, capture with `capstat.sh`,
  all 6 buttons, and the P1 lines. Record the MAC and the result.

## 1. HDMI input hot-plug

### Symptom

The first capture after JTAG flash + init works. After unplug and replug,
the capture shows one frame and then freezes. On 2026-10-19 the capture
recovered without any action 45-60 s after the replug.

### Measurements (2026-10-19, `sw/tools/capstat.sh -w 250`)

- Healthy capture: `pL=1 aL=1`, frames arrive, DMASR = `0x0001D910`
  (IntErr EOLEarly SOFLate EOLLate ErrIrq, all latched), `Halted=0`.
- Unplugged: `pL=0 aL=0`, no frames, SOFEarly also latched. VDMA does
  not halt.
- After recovery: frames arrive again with the same latched errors.

Conclusions:

- The capture VDMA has `c_flush_on_fsync=1`. Its latched errors are NOT
  fatal, and the VDMA resyncs on the next SOF. The comment in
  `CaptureInitialize` that calls IntErr fatal is wrong for this
  configuration. Its `errMask` also labels bit 11 as SOFEarly; bit 11 is
  SOFLate (SOFEarly is bit 7).
- The VDMA is not the cause.

Second run (2026-10-19, source = ELMO presenter, DVI, hardware switch
720p/SXGA, set to 720p):

- Unplug 01:11:37, replug 01:11:42: `pL=1 aL=1` at once.
- Frames start again at 01:11:59: 17 s with lock but no frames.
- 17 s = one full alignment sweep (10 bitslips x 32 taps x 50 ms).
  CAUSE FOUND: dvi2rgb `kBlankTimeoutMs = 50` in
  `IP_dvi2rgb/src/DVI_Constants.vhd`. Fix: 50 -> 2 (sweep 16 s -> 0.64 s).
  No BD/address/PS change, so no PetaLinux rebuild. Rebuild with
  `hw/repackage_ip.tcl IP_dvi2rgb`, then `hw/build.tcl <variant> build`.
- After a W1C clear of DMASR, EOLEarly, SOFLate and EOLLate latch again
  in each frame: the ELMO frame is not exactly 1280x720 (line lengths
  vary, more than 720 lines). The VDMA flushes and resyncs in each frame,
  so the picture is correct. The daemon must measure the real frame.
- FIX VERIFIED (2026-10-19, bitstream `debaz4205_wrapper_20261019_dvi2ms.bit` + `.bit.bin`, now in `artifacts/`):
  10 replugs with the ELMO, including fast replugs and contact bounces.
  In all of them, frames start in the same 250 ms sample as `pL=1`.
  The BD changes below are no longer necessary for hot-plug. They are
  still useful for robustness (no capture reset from the output clock,
  HPD control for EDID re-read, alignment status bits).
- SXGA (1280x1024 at 108 MHz) is a possible capture mode: same width,
  MMCM VCO 1080 MHz (in range with kClkRange=2), fits in one slot.

### Findings in the RTL and the netlist

- `v_vid_in_axi4s_0.vid_io_in_reset` is tied to `1'b0`. The video side of
  the input FIFO never gets a reset.
- All capture resets come from `axi_dynclk_0/LOCKED_O` (the OUTPUT pixel
  clock lock): dvi2rgb `aRst_n` and `pRst_n`, vid_in `aresetn`, capture
  VDMA `axi_resetn`, `axi_interconnect_1`, `axis_subset_converter_0`.
  Thus an output mode change resets the capture VDMA, possibly during a
  write (AFI-wedge risk, see CLAUDE.md). An input loss resets nothing in
  this group.
- `pLocked` is only the dvi2rgb MMCM lock. It does not show if the three
  data channels are aligned. `pL=1` with no frames is possible.
- dvi2rgb alignment (`TMDS_Decoder.vhd` + `PhaseAlign.vhd`): when a
  channel cannot align, it does a bitslip and starts again. Each failed
  blank search waits up to `kBlankTimeoutMs = 50` ms. One full sweep =
  32 taps x 10 bitslips x 50 ms = approx. 16 s. Thus 45-60 s = approx.
  3 failed sweeps. This occurs if the source sends unstable data, or data
  with no blank of 128 control tokens, after the replug.
- HPD_2 is a PL output (pin R18), driven by an `xlconstant`. Software
  control of HPD needs only a gateware change. PCB v2 does not change.
- hdmi2.elf has no recovery code. It calls `CaptureInitialize` one time.

### Next measurements

1. Run `capstat.sh -w 250` without a stop, from before the unplug to
   after the recovery. Record when `pL`/`aL` come back and when
   `frm`/`pix` start again.
   - `pL`/`aL` come back late: the source starts late, or the MMCM
     relocks late.
   - `pL=1` early, but frames start late: dvi2rgb alignment sweeps
     (most probable).
2. Record which source is used, and if its output is DVI or HDMI mode.
   HDMI mode puts data islands into the blanking, so control-token runs
   are shorter.
3. Optional and risky: change the output mode with hdmi2. This pulses
   dynclk LOCKED, which resets all of dvi2rgb and the capture path. If
   the capture comes back at once, a reset fixes the problem. Risk: this
   also resets the capture VDMA. Do it only while the capture is idle
   (frozen). The worst result is a reboot.

### Robustness BD changes (task 3, not urgent)

- Add one AXI GPIO for capture control, at a NEW address (an addition
  only; the address contract stays). Output bits: dvi2rgb `pRst`
  (restart alignment), capture-path reset, HPD_2.
- Connect `vid_io_in_reset` to NOT `pLocked`.
- Disconnect the capture-path resets from the dynclk lock. Use a
  `proc_sys_reset` and the new GPIO bit.
- Send the decoder status to the spare GPIO ch1 bits [31:15] at
  0x4120_0000 (bits [5:0] are the user GPIO, see "User I/O"):
  `pRdy[2:0]`, `pVld[2:0]`, alignment error. This needs new
  ports in the local `IP_dvi2rgb` fork.
- Later, in the daemon: when `pL=1` and there are no frames for more than
  200 ms, pulse `pRst`. If that does not help, pulse HPD, so that the
  source reads the EDID again and restarts its output.

## 2. Vivado project as Tcl

Status 2026-10-19: scripts done (`hw/export_bd.tcl`, `hw/build.tcl`,
`hw/README.md`). The BD netlist from the Tcl is identical to the live one,
except the K17/E19 GPIO lines moved from bits [7:6] to [5:4]. Full build:
same utilization and same timing character as the live impl_2. Export
round trip is clean. Open: hardware test of
`build/ebaz4205_2out1in/ebaz4205_2out1in_20261019.bit`. Notes below are the original plan.

- Use `write_bd_tcl` for the BD. Write `build.tcl` to create the project,
  set the IP repo paths, add the module-ref RTL (`div16_8_recip`,
  `dds_axi_interface`) and the XDC, source the BD Tcl, run synth/impl,
  and write the `.bit`, `.bit.bin` and `.xsa`.
- IP sources to include: `ip_repo/mixer_1_0`, `IP_rgb2dvi`,
  `IP_axi_dynclk`, `IP_dvi2rgb`, and the external Digilent
  vivado-library dependency (commit `d70ab01c`; see
  `vivado-library-dvi2rgb.patch`).
- Rebuild in a NEW directory. Do not touch `Vivado/`. Compare the
  generated `ebaz4205.v`, the utilization and the timing with the current
  build.
- One BD Tcl per variant, with a shared XDC and per-variant XDC parts.
- Run Vivado with `vivado -mode batch` (the GUI Tcl console can wedge).
- In the same build, generate `hw_map.h` from `get_bd_addr_segs`. This
  makes the address map one source of truth for C code and scripts.

## 4. PetaLinux rebuild (one time)

- New BOOT.BIN from the new XSA. This removes the FCLK3 SLCR poke.
- Enable fpga_manager overlays: one `.bit.bin` + one `.dtbo` per variant.
  Each overlay has `generic-uio` nodes for the IP in its variant. The
  daemons find the hardware through `/sys/class/uio`.
- Rules for all variants:
  - The same PS configuration (one FSBL for all).
  - The 25 MHz ethernet PHY clock (`DivideBy4_25MHz`, pin U18) must be in
    every bitstream.
  - Set the FCLKs in the overlay (clocking node with
    `assigned-clock-rates`), not only in the FSBL. Verify this on the
    target.
- A bitstream swap stops the PHY clock for a short time. An ssh session
  can drop during a swap. Use a local script or the serial console for
  swaps.
- Keep the PetaLinux copy of `system-user.dtsi` in sync with the repo
  root copy.
- Decide: does BOOT.BIN still carry the old stable bitstream, or does it
  carry the new default variant?

## 5. C code without Vitis

DONE 2026-10-19 (see `sw/README.md`): `sw/Makefile` builds debazd, dzctl,
libdz, fbfeed and hdmi2 with the Vitis gcc (no project, no BSP). hdmi2 has
the same symbols as the Vitis build. Host self test: `make -C sw test`.
VS Code remote gdb: `sw/tools/vscode/`. Open: replace `xparameters.h` in
hdmi2 with `hw_map.h`; split hdmi2 bring-up into a library for debazd.
Original plan below.

- Build all Linux applications with plain Makefiles in `sw/`, as
  `sw/oscreg` does. Compiler:
  `/home/aescape/Xilinx/Vitis/2022.2/gnu/aarch32/lin/gcc-arm-linux-gnueabi/bin/arm-linux-gnueabihf-gcc`.
- Move hdmi2 from `Vitis/hdmi2` (and jerkspace) to `sw/hdmi2`. Split the
  setup code (dynclk MMCM tables, VTC, VDMA start order) into a library
  that the daemon can use.
- Replace `xparameters.h` and the hand-copied addresses with the
  generated `hw_map.h`.
- Live debugging without Eclipse: `gdbserver` and `gdb` are on the
  target, and the toolchain has `arm-linux-gnueabihf-gdb`. On the target:
  `sudo gdbserver :2345 ./hdmi2.elf`. On the laptop: a VS Code
  `launch.json` (cppdbg, `miDebuggerPath` = the toolchain gdb,
  `miDebuggerServerAddress` = the target link-local address + `:2345`).
  Build with `-g -O0` for debugging.
- Put the target-side scripts in the repo: `nudebaz.sh`, `onlySetup.sh`,
  `dumpPhase.sh`, `updownPhase.sh`, `wigglePhase.sh`, `wompPhase.sh`,
  `wumpPhase.sh`, `wMem.sh` (now only in `/home/ebaz`).
- Vitis is necessary only if we want a baremetal application. PetaLinux
  builds the FSBL.

## 6. Hardware daemon

Update 2026-10-24: vsync thread (frame-exact show/blank/sequences, 12 slots,
black slot 11), 16 LFOs with field and message-template targets, sprites,
pixel + TrueType text, full-frame transforms, NEON YUV movies. Open: mirror
on the fast transform path, sprite filtering (now nearest), buttons → LFO
triggers / sequences, a systemd unit, unit identity (MAC) for the fleet.

Status 2026-10-19: `debazd` runs on the board. Done: 138 named fields
(traced from the BD), display routing (`/disp/<d>/show|home|capture`),
capture status, `/subscribe` events (`/event/io`, `/event/hpd`,
`/event/capture`, with a snapshot on subscribe), drawing and movies, memory
safety (only blocks in hw_map.h, only slots in reserved memory). Open:
capture recovery actions (needs the task 3 reset bits), input mode
measurement, GPIO interrupt via UIO (now polled every 100 ms), unit
identity for the fleet, a systemd unit (not installed: boot still runs
debazarosit.sh). Original plan below.

- One root daemon is the only owner of the hardware. It has modules for
  the mixer, the DDS, the video output and the capture input. External
  programs connect through OSC (`sw/oscreg`) or a unix socket. One owner
  prevents the shadow-register conflict with the devmem loop in
  `debazarosit.sh`.
- Capture module state machine: NO_SIGNAL -> LOCKED -> MEASURE -> ARM ->
  RUN. On loss of signal: safe stop (soft reset while the stream is
  healthy, never `RS=0` during a frame). Wake on the GPIO interrupt
  (already wired to IRQ_F2P) through UIO, with polling as a fallback.
- Input modes 800x600@60, 720p60 and 1080p30:
  - The design has no input mode measurement now. Options: a small
    frame/line counter module on a GPIO, or a VTC in detector mode.
  - The EDID ROM needs an 800x600 entry.
  - A mode change needs an HPD pulse (see task 3).

## 8. Variants

- "3out/0in": the third port is an output.
- "1out/2in": two capture paths. There are only two VTCs.
- OPEN QUESTION: "the 1 out is timed by the 2 input" - does this mean the
  output is genlocked to an input, or that the VTCs are used as input
  detectors?
- The variants do not block tasks 2-7.

## 9. Display views: crop, pan, zoom, split (design, 2026-10-24)

Goal: each display shows a window of any slot (live input 4, a movie, a
painting), for example display 0 = top-left quarter of the input at 2x and
display 1 = top-right quarter at 2x. Input and output resolution are the
same (1280x720). This generalizes to crop, pan and zoom.

### Measured facts (bench board, 2026-10-24)

- CPU path today (`/surface/6/grab 4` then `/draw/6/transform` x2): grab
  48 ms (uncached read of 3.7 MB, about 77 MB/s), zoom 24 ms. About 72 ms
  for each live frame = 14 fps for ONE display, 7 fps for two. A grab of
  only the quarter that is needed (0.9 MB) would give about 25 fps for one
  display. Not enough for live 60 fps.
- The display VDMAs (MM2S) can already read a window: start address =
  slot + y0 * 5120 + x0 * 4, HSIZE, VSIZE, STRIDE = 5120. No DRE and a
  64-bit memory bus: x0 must be even. A window costs no CPU and no extra
  DDR bandwidth (a smaller window reads less).
- But a VDMA cannot scale. v_axi4s_vid_out needs exactly 1280x720 at its
  input, so a 640x360 window needs a 2x scale between the VDMA and vid_out.

### Design: VDMA window + nearest-neighbour upscaler in the PL

```
VDMA MM2S (window: start, HSIZE, VSIZE, STRIDE) -> subset converter
  -> NEW "view" scaler (AXIS, FCLK2) -> v_axi4s_vid_out -> effects -> rgb2dvi
```

- The scaler repeats pixels and lines (nearest neighbour). It uses a DDA
  step per axis in 16.16 fixed point, so any zoom >= 1 costs the same as
  2x: smooth zoom, not only integer steps. X and Y steps are separate.
- Horizontal: hold TREADY low while a source pixel repeats. Vertical: keep
  one source line in a line buffer and send it again while the VDMA waits
  (its 4096-deep line buffer absorbs the stall).
- Line buffer: one line of up to 1280 px x 24 bit = 30.7 kbit = 1 BRAM36
  per display, or about 480 LUTs as distributed RAM. BRAM is about 96%
  used (two BRAM36 free), LUTs about 65%: LUTRAM is the safe choice.
- It runs in the AXIS clock (FCLK2), NOT in the crowded pixel clock region
  X1Y1. Logic: two accumulators, counters, SOF/EOL generation: small.
- Registers (zoom steps, enable) double-buffered and latched at SOF. debazd
  writes the VDMA window and the scaler at vsync (VSIZE write last = the
  VDMA commit), so window and zoom change on the same frame.
- Zoom < 1 (shrink): vertical by STRIDE = n x 5120 (skip lines, integer
  only, free); horizontal by dropping pixels (the VDMA reads the full line).
- Cheap extra: read the line buffer backwards = horizontal mirror.
- One AXI-Lite block with registers for 3 channels (third-port rule: keep
  room for a third display). Use a spare `M**_AXI` port of ps7_axi_periph
  (an addition: no address moves).
- Effects apply AFTER the view (the feedback paths see the zoomed image).

### Software

- `/disp/<d>/view x0 y0 zoom [zoomy]` and `/disp/<d>/view/reset`. Window
  size = 1280/zoom x 720/zoom. debazd clamps the window inside the slot
  (a VDMA read past the slot shows the next slot's memory).
- Pan and zoom from LFOs (`/disp/1/view $0 $1 2`), at 60 fps, no CPU load.
- Quarter split of the input: `/disp/0/view 0 0 2`, `/disp/1/view 640 0 2`.
  Zero copy: both displays read capture slot 4.
- With one decoded movie and two views, both displays show the same movie
  with different crops at the cost of ONE decode (see FLEET.md section 4).
- Fleet: a video wall from one HDMI source (split it with an HDMI
  splitter), each unit shows its own tile; an "offset" spread on x0/y0.

### Interim without gateware

- CPU path (above): about 14 fps for one display, about 25 fps after a
  quarter-only grab. For slow or frozen effects only.
- VDMA window at 1:1 only (no scaler): pan a 1280x720 window over a slot
  that holds a bigger picture (slots are 1920x1080 in size). Useful for a
  large painted canvas, or a 1080p30 input. With same-size sources there
  is nothing to pan over.

### Open points

- Measure the free resources in the Tcl build before the BD change.
- Build the scaler as RTL (module reference, as `div16_8_recip`) or HLS.
- Branch: `view` (gateware + debazd), after the Tcl flow hardware test
  (task 2).


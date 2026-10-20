# DEBAZAROS roadmap (written 2026-10-19)

Goal: move the bitstream changes from the one good bench setup into a
repeatable system, so that we can test new hardware. Do the PetaLinux
rebuild one time only, and prepare it for later bitstream variants.

Status words: TODO, DOING, DONE, BLOCKED.

## Order of work and dependencies

| # | Task | Depends on | Status |
| --- | --- | --- | --- |
| 1 | HDMI input hot-plug: find the cause | hardware | DONE (2026-10-19) |
| 2 | Export the Vivado project to Tcl, rebuild it, compare | — | DOING (netlist, util, timing OK; HW test open) |
| 3 | Capture robustness BD changes (resets, HPD, status bits) | 1, 2 | TODO |
| 4 | XSA export + one PetaLinux rebuild with overlay support | 3 | TODO |
| 5 | C code: no Vitis, plain Makefiles in `sw/` | — (can start now) | TODO |
| 6 | Hardware daemon (mixer, DDS, video out, capture) | 5; capture part needs 3 | TODO |
| 7 | Test the OSC drawing layer against the daemon | 6 | TODO |
| 8 | Variants "3out/0in" and "1out/2in" | 2, 4 | TODO |

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
- Discovery: mDNS (avahi) or an OSC broadcast "hello".
- OSC namespace per unit plus group addresses (all units, groups).
- Time/frame sync between units: later (PTP or NTP + frame-count
  alignment). No genlock between boards today.
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
  `tools/vivado/dvi2rgb_rebuild.tcl` (phase `upgrade`, then `build`).
- After a W1C clear of DMASR, EOLEarly, SOFLate and EOLLate latch again
  in each frame: the ELMO frame is not exactly 1280x720 (line lengths
  vary, more than 720 lines). The VDMA flushes and resyncs in each frame,
  so the picture is correct. The daemon must measure the real frame.
- FIX VERIFIED (2026-10-19, bitstream `debaz4205_wrapper_20261019_dvi2ms.bit` + `.bit.bin` in the repo root):
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

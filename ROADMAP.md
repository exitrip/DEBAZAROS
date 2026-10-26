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
| 11 | SD card image: partitions, packages, sw deploy, read-only root (section 10) | 4 | PLAN (2026-10-25) |

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
- DONE 2026-10-25: one dtsi only
  (`PetaLinux/project-spec/meta-user/recipes-bsp/device-tree/files/system-user.dtsi`;
  root copy removed): 96 MB reservation, one simplefb, fpga-full region, no PL
  nodes (`CONFIG_SUBSYSTEM_REMOVE_PL_DTB=y`: generated PL nodes had bound
  xilinx-vdma/xilinx-vtc and stale SDR-era nodes).
- DECIDED 2026-10-25: BOOT.BIN carries the default variant (now
  `ebaz4205_2out1in_20261025`, hardware-tested), so ethernet always comes
  up; FPGA_MANAGER option stays OFF (it would drop the bitstream from
  BOOT.BIN). XSA imported 2026-10-25: the new FSBL sets FCLK3 = 200 MHz.

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

## 8. Variants (analysis 2026-10-25)

Swapped rarely, with jumpers on the adapter: not hot-swap, but modular
fleet setups (feedback over HDMI cables between units, video walls from
splitter arrays).

| Variant | HDMI_0 | HDMI_1 | HDMI_2 |
| --- | --- | --- | --- |
| `ebaz4205_2out1in` (now, default) | out | out | in |
| `ebaz4205_3out0in` | out | out | out |
| `ebaz4205_1out2in` | **in** | out (timed by HDMI_0) | in |

### Pins and clock regions (the real limit)

HDMI_0 (pins A-F) and HDMI_1 (G-L) are both in bank 35: one clock region,
served by the one BUFIO/BUFR pair of axi_dynclk. HDMI_2 is split: clock and
data 0 (N20/P20, N17/P18) in bank 34, data 1-2 (M17-M20) in bank 35.

- **3out0in.** rgb2dvi needs serial + pixel clock on a skew-matched pair in
  BOTH banks of HDMI_2. (a) BUFG + BUFG, as in the dvi2rgb input fork: fine
  at 720p (serial 371 MHz); at 1080p the serial clock (742.5 MHz) is above
  the BUFG limit of a -1 part (about 628 MHz). (b) BUFMR -> BUFIO/BUFR in
  both regions (the `kAddBUFMR` stub in `IP_axi_dynclk`): one pixel clock
  for all three outputs; at 1080p outside the BUFIO data sheet limit, as
  the two current outputs already are (they work at 1080p60). Plan: 720p
  with (a) first, then try (b) for 1080p.
- **1out2in.** The XC7Z010 has 2 MMCM + 2 PLL. Now: dynclk = 1 MMCM,
  dvi2rgb = 1 MMCM. A second dvi2rgb needs a third MMCM. Solution: HDMI_1's
  rgb2dvi and the shared VTC run from the recovered pixel clock of the
  HDMI_0 input, and dynclk is removed in this variant (HDMI_1 goes dark
  when HDMI_0 has no source: accepted). HDMI_0 input uses the BUFG+BUFG
  dvi2rgb fork. Alternative: port one dvi2rgb to PLLE2.
- Each variant: its own VDMA set (MM2S x3, or S2MM x2 + MM2S x1), VTC role
  (generator / follower of an input), `hw_map.h`, and debazd/hdmi2 code
  paths. Shared blocks keep their addresses; new blocks are additions.
- **Add to every variant: a constant variant/build ID word** at a fixed
  address (spare bits of the 0x4120_0000 ch1 input are enough), so the
  software reads what is really loaded.

### PetaLinux and the XSA with several variants

PetaLinux takes three things from an XSA: the PS7 setup (FSBL `ps7_init`:
FCLK0-3, DDR, MIO, which GP/HP ports and interrupts are on), the PL device
tree, and the default bitstream for BOOT.BIN. Only the PS7 setup is fixed
at boot.

- **Rule (PS contract): all variants have the same PS7 configuration.**
  Then ONE XSA (the default variant) is enough for PetaLinux, and a variant
  is only `<variant>.bit.bin` (+ optional `.dtbo`) loaded by fpga_manager.
  Contract now: FCLK0 100, FCLK1 64, FCLK2 142 (145.45), FCLK3 200 MHz;
  M_AXI_GP0; S_AXI_HP0/1/2 (64 bit); IRQ_F2P; ENET0 on EMIO. (3 VDMAs fit
  every variant; enable HP3 only if a variant needs a 4th port, and then
  rebuild BOOT.BIN for all.) TODO: build.tcl compares the PS7 config of
  each variant with this contract and stops on a difference.
- If a variant ever needs another FCLK: set it at run time (SLCR, or
  `assigned-clock-rates` in the variant overlay: the zynq clock driver
  exposes fclk0-3), not with a new FSBL.
- Base device tree: no PL nodes (`CONFIG_SUBSYSTEM_REMOVE_PL_DTB`) or the
  default variant's nodes; each variant's UIO nodes in a small overlay made
  from its `hw_map.h`: `fpgautil -b x.bit.bin -o x.dtbo`. The kernel on the
  board has CONFIG_OF_OVERLAY, CONFIG_OF_CONFIGFS, an `fpga-full` region and
  `fpgautil`. Overlays are optional: debazd falls back to /dev/mem.
- PetaLinux `CONFIG_SUBSYSTEM_FPGA_MANAGER` stays OFF: it removes the
  bitstream from BOOT.BIN, and the ethernet PHY clock comes from the PL
  (decision 2026-10-25: a stable default bitstream always brings up
  ethernet).

### 1080p30 input on 1080p60 outputs

No gateware for the frame rate: the frame buffers decouple it (each
captured frame is shown twice). Open points: (1) tearing - capture circular
over its 3 frame stores and debazd parks the display on the last complete
frame at each vsync (software; VDMA genlock wiring is the gateware
alternative); (2) DDR bandwidth - 2 x 1080p60 out (about 1.0 GB/s) + 1080p30
in (0.25 GB/s) on 16-bit DDR3 (about 2.1 GB/s peak): measure; (3) effects at
148.5 MHz (6.7 ns): the effects chain needs a register after every
multiplier/adder - the planned pipelining fix (CLAUDE.md) targets 720p60
(13.5 ns) only; (4) hdmi2 CAPTURE_W/H 1920x1080 (EDID already has 1080p30).

Order: variant ID word -> 3out0in at 720p (BUFG+BUFG) -> 1080p / BUFMR ->
1out2in (HDMI_1 on the HDMI_0 input clock).

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

## 10. SD card image and software deploy (plan, 2026-10-25)

Goal: one image for every card (16 GB or larger). Flash it, and the unit
works; per-unit identity lives in small files, not in the image.

### Partitions

| # | Type | Size | Mount | Content |
| --- | --- | --- | --- | --- |
| 1 | FAT32 `BOOT` | 256 MB | `/boot` | BOOT.BIN (FSBL + default bitstream + U-Boot), boot.scr, uImage, system.dtb, `uEnv.txt` (MAC, see Fleet) |
| 2 | ext4 `rootfs` | 3-4 GB | `/` (read-only later) | system + our software |
| 3 | ext4 `data` | 256 MB | `/data` | per-unit state that must survive: ssh host keys, machine-id, unit settings, presets, logs |
| 4 | FAT32 `DEBAZMEDIA` | rest of the card | `/media/debaz` | `img/`, `movies/`, `fonts/`: load media with any card reader |

- The image file holds partitions 1-3 only (small, quick to flash).
  A first-boot service makes partition 4 in the free space (`parted` +
  `mkfs.vfat -n DEBAZMEDIA`) and creates the media folders. A 16 GB card
  and a 64 GB card both get all the remaining space.
- FAT32: every computer reads it; the limit is 4 GB per file (the same as
  the dzweb upload limit). exFAT (kernel 5.15 has a native driver) is the
  option if one movie must be larger than 4 GB.
- debazd and dzweb use the media partition: `DZ_IMG_DIR` /
  `DZ_MOVIE_DIR` -> `/media/debaz/{img,movies}`, `dzweb -m /media/debaz`.
  The file name rule (A-Z a-z 0-9 . _ -) is safe on FAT.
- Tool: a custom `.wks` file for `petalinux-package --wic` (or a script
  with `sfdisk` + `mkfs` + copies, which is easier to read and change).

### Packages (rootfs_config / user-rootfsconfig)

- REMOVE the SDR-era load: Qt5 + PyQt5, matplotlib, fftw, audio groups,
  `packagegroup-core-buildessential` (+dbg), python modules -dbg/-dev,
  `myjtdx`, `fftw`, `chown-ebaz-uio-sdr-app`, `colorbars` recipes.
- ADD: `ffmpeg` (+ libav* for the future dzplay; needs
  `LICENSE_FLAGS_ACCEPTED` for some codecs), `parted`, `dosfstools`,
  `e2fsprogs`, `rsync`, `curl`, `iproute2`, `ethtool`, `htop`, `python3`
  (small: for tools/demos), `gdbserver`. Keep dropbear + sftp.
- Fonts: our default `LiberationSans-Regular.ttf` (dz_text) + OFL notice.
- Media libraries (no GPU and no hardware video codec on the Zynq-7010:
  every decode runs on the A9 cores with NEON):
  - ffmpeg / libav*: the base. NEON decoders (H.264, MPEG-4, MJPEG),
    network input (UDP/RTP/SRT/HTTP); the future dzplay links libav.
  - stb_image (single header, same project as stb_truetype): PNG/JPEG
    decode inside debazd for `/img` and sprites, instead of one ffmpeg
    process per image. TODO.
  - libjpeg-turbo 2.1 (+ cjpeg/djpeg): in the image (2026-10-25). NEON
    JPEG for image loads and a possible MJPEG scrub/reverse format.
  - pixman: in the image (2026-10-25). NEON compositing/scaling, if our
    own blend and transform code becomes a bottleneck.
  - GStreamer: not now. Same libav decode on this chip, more RAM/CPU, needs
    a custom appsink for our frame slots. Its network clock
    (GstNetClientClock) is a good model for the FLEET.md show clock.
  - OpenGL: no (software Mesa only: a few fps at 720p). Effects belong in
    the PL, generative drawing in the NEON painter.
  - Media preparation (encode, resize, GOP) on the laptop, not the board.
- Languages (2026-10-25): Python 3.9 in the image for users who want
  Python (the DEBAZAROS software does not depend on it); LuaJIT 2.1 in the image (see "Local scripts"); no Perl, Ruby,
  Node.js (none was installed anyway). Rust: built outside PetaLinux with
  rustup (static `armv7-unknown-linux-musleabihf` binaries), only to
  replace C code later; PetaLinux's own Rust 1.54 is too old. PetaLinux
  2022.2 also ships, if ever needed: Node.js 14, Lua 5.3, Go 1.16, Ruby 3.0,
  Perl 5.34, Tcl 8.6, PHP 7.4, meta-jupyter.

### Local scripts (scenes without a controller)

- First form: a text file of time-coded OSC messages on the media card,
  for example `0.000 /disp/1/show 5`, `2.500 /lfo/0/on 1`, and a runner.
  The runner can be debazd itself (`/scene/play <file>`: lines applied
  from the vsync thread at their time, frame-exact, looped or once) or a
  shell script (`dzctl` + `sleep`, or UDP from bash) for quick tests.
  The same file format can come from the hub (record a performance,
  play it back on a unit) and later carry show-clock times (FLEET.md).
- Second form, when a scene needs logic (random choices, reactions to
  buttons or input lock): LuaJIT embedded in debazd, with the OSC
  addresses as Lua functions.

### Our software in the image

Three ways, in this order of work:

1. Now (development): `make -C sw install` over the network, unchanged.
2. Image (recommended next): a meta-user recipe `debaz-sw` that builds
   `sw/` with the Yocto cross compiler (the Makefiles are plain; set
   `CC`/`CFLAGS` from the recipe) and installs `/usr/bin/{debazd,dzctl,
   dzweb,fbfeed,hdmi2,vsync_probe}`, `/usr/share/debaz/www`, the scripts,
   the bitstreams (`/lib/firmware`) and the systemd units. The recipe
   reads the source from the repo (`EXTERNALSRC`), so a rebuild picks up
   the current `sw/`.
3. Option for quick images: a recipe that installs prebuilt binaries from
   `sw/out/arm/` (no compile in Yocto).

### Start-up (replaces debazarosit.sh)

systemd units, in order: `debaz-firstboot` (media partition, data
partition, ssh keys, hostname from the MAC) -> `debaz-pl` (optional:
load a non-default variant + overlay from a setting in `/data`; the
default variant is already in BOOT.BIN) -> `debaz-display` (hdmi2: video
mode, VDMAs) -> `debazd` -> `dzweb` -> `debaz-scene` (apply the unit's
start scene: mixer setup, movie, LFOs - from `/data` or the media card).

### Read-only root (after the above works)

Yocto `read-only-rootfs` image feature: `/` mounted read-only, `/var`
volatile (tmpfs), writable things bind-mounted from `/data` (ssh host
keys, machine-id, `/etc/hostname`, network). Gain: a power cut cannot
damage the system; a unit is "power off = safe". Media stay on their own
FAT partition (writable). Software updates then need a remount
(`mount -o remount,rw /`) or a new image.

### Decisions (user, 2026-10-25)

- Media partition: **exFAT** (macOS, Windows and Linux read and write it;
  files may be larger than 4 GB). Kernel exFAT + exfat-utils are in the
  image since build 3. Change the FAT32 entries above accordingly.
- **No package manager** (changed the same day): the only use would be
  externally built tools, and Debian/Arch repositories cannot be used on a
  Yocto rootfs (other glibc and library versions; grabbing foreign ARM
  binaries is bad practice). Tools go into the image (recipe, or built
  with our toolchain), or into `/data/opt` once the root is read-only.
  `imagefeature-package-management` removed (about 9 MB rpm database).
- **One image for all variants**; the variant is a setting on `/data`.
- `uEnv.txt` (MAC) is per-card setup: `debaz-firstboot` writes it when it
  is missing (MAC from the SD card CID, locally administered), then
  reboots once.

### Build tools: stay on PetaLinux 2022.2 (decision 2026-10-25)

- No upgrade: the units are offline (no security updates needed), the
  Zynq-7000 support in kernel 5.15 / U-Boot 2022.01 is complete for us,
  and Vivado 2022.2 + its XSA + write_bd_tcl + PetaLinux 2022.2 are locked
  together; an upgrade means weeks of re-validation. PetaLinux ends after
  2024.2 anyway.
- If ever: go to plain Yocto + meta-xilinx WITHOUT a Vivado upgrade. Since
  the device tree has no PL nodes, only the FSBL (from ps7_init) and the
  bitstream need the XSA; make both with Vitis/Vivado 2022.2 (xsct +
  bootgen) and let Yocto build only U-Boot, kernel, a hand-written PS dts
  and the rootfs.
- The real risk is "bit rot" of the build: upstream download addresses die
  (seen 2026-10-25: luajit.org tarball gone, LuaJIT tags deleted, and the
  2022.2 LuaJIT recipe was broken by the override conversion). The project
  also uses AMD's petalinux.xilinx.com pre-mirror and sstate feed.
  Measures: (1) backup of build/downloads + sstate-cache, with git sources
  also as mirror tarballs; (2) a tested "local only" build (no network);
  (3) a container (Ubuntu 22.04 + PetaLinux 2022.2, built from the AMD
  installer, which cannot go to a public registry) so any computer can
  build.

### Status (2026-10-25)

PetaLinux builds pass with the Tcl XSA (FCLK3 = 200 MHz in the FSBL), the
new dtsi (no PL nodes, NAND enabled) and the trimmed rootfs (200 MB).

TEST CARD (2026-10-26, `petalinux-package --wic`, default 2 partitions:
2 GB FAT32 + 4 GB ext4; image `debazaros-20261026-build8.wic.xz`, 51 MB):
PASS - boots; 96 MB hole in /proc/iomem; /dev/fb0 1280x2160; FCLK3 =
0x00200400 from the FSBL (no SLCR poke); Tcl bitstream from BOOT.BIN
(GPIO K17/E19 at [5:4]); no PL drivers bound; ethernet + DHCP; NAND as mtd0
(Winbond W29N01HV, 128 MiB SLC); ffmpeg, Python 3.9, libjpeg-turbo, pixman,
exFAT; our sw via `make install`: debazd + hdmi2 + dzweb up, vsync 60.03 Hz,
capture locked, 117/117 register fields, movie playback (clip encoded on
the board by ffmpeg in 19 s). Bring-up on this image = debazd, mixer setup,
hdmi2, dzweb (no bitstream load, no FCLK poke).
Found and fixed in the repo (next build): nfs-utils removed (3 NFS server
units failed: no nfsd in the kernel); LuaJIT installs only
`luajit-2.1.0-beta3` -> `luajit` link added.
Notes: the userland is BusyBox (no GNU dd/od/head options); `ebaz` PATH has
no /sbin; debazd reports a display as slot -1 until it sets it itself.
The NAND holds the original Ebang "Ebit" miner firmware: a Zynq boot image
with U-Boot 2015.07 (2017) at offset 0, and JFFS2/rootfs partitions
(`nand-rootfs`, `nand-jffs2`, `nand-allrootfs`); read only.


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
| 10 | Display views: crop, pan, zoom, split of live input or a movie (section 9) | 2 (gateware) | DOING: crops in software (`/disp/<d>/crop`, fixed 7680-byte pitch), frame-synced display VDMAs (build fs); video wall from a 1600x1200@30 input (CVT-RB EDID, build edid2) with 800x600 quarters WORKS 2026-10-28 |
| 11 | SD card image: partitions, packages, sw deploy, read-only root (section 10) | 4 | DOING (2026-10-28): full userland beside BusyBox, passwordless sudo, journald runtime cap, ALSA card + alsa-utils, per-card MAC/hostname at first boot (debaz-firstboot, in the config, not built yet); open: partitions, sw in the image, read-only root |
| 12 | Audio (HDMI out/in, I2S), PL_KEY I2C/SPI/UART, fan-port I/O, PL resource recovery, 1080p buffers (section 11) | 2 | ANALYSIS (2026-10-26) |
| 13 | Mixer video functions: colour matrix (hue, map) and RGB colour key (section 12) | 2 | DOING: matrix tested on the board 2026-10-26; key bitstream loaded on the bench board 2026-10-26, picture check pending (`sw/tools/keytest.sh`) |
| 14 | HDMI audio out (HDMI_1) + in (HDMI_2), 48 kHz 16 bit (section 11) | 2 | WORKS on hardware 2026-10-26 (branch hdmi-audio, artifacts/..._20261026_audio): out, in, loop; 2026-10-27: HDMI_0 also hdmi_tx (own TX0_CTRL + audio source), simulated, built, not yet on hardware; open: software HPD; 1080p60 still needs the effects-chain pipelining (hdmi_tx itself: 10 ns) |
| 15 | Linux ALSA card DEBAZ (driver debaz-audio, section 13) | 14 | WORKS (2026-10-28): in the image, binds at boot; aplay/arecord/speaker-test/amixer/alsactl tested on HDMI 0/1, HDMI 2 In, I2S; open: dmix/softvol asound.conf, HDMI-mode control |
| 16 | DDS pattern engine `dz_osc2`: sequencer, raster sync, shapes, AWG, own sine, one AXI port for both DDS (section 14) | 2 | RTL + testbench DONE, both channels (2026-10-29, ALL PASS; OOC 1361 LUT / 1508 FF / 2.5 BRAM tiles / 0 DSP / +0.71 ns; net vs the old parts ~+1130 LUT, ~+860 FF, -12.5 BRAM tiles); step before it DONE: GPIO consolidation `dz_regs` ON THE BOARD 2026-10-29 (build regs3, tested); BD integration DONE + bench-tested 2026-10-29 (build osc: bars, checkerboard; slices 100 %, FCLK2 -0.017 ns: closure runs); next: timing, software presets |

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
  From the netlists (2026-10-26): PL_KEY4 = K17 = SW6, PL_KEY5 = E19 =
  SW5. Still confirm on a v2 board (press SW5/SW6, read 0x4120_0000).
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

### PS buttons and reset (from the traced EBAZ4205 schematic, 2026-10-26)

- S2 = **MIO 20**, S3 (not fitted) = **MIO 32**: PS GPIO, NOT PL pins (no
  XDC lines). Active HIGH: the button connects VCC; 10 kOhm to GND
  (R9999 / R2648) + 1 uF debounce (C73 / C2410).
- TODO: the PS7 setup enables the internal PULL-UP on MIO 20/32
  (`PCW_MIO_20_PULLUP {enabled}`), which fights the external pull-down.
  Turn it off in the BD (changes the FSBL: XSA re-import), or at run time:
  clear bit 12 of SLCR `MIO_PIN_20` / `MIO_PIN_32` (0xF8000750 / 0xF8000780).
- TODO: on the new image, `/sys/class/gpio/export` of a zynq-gpio line
  (base 906: MIO 20 = 926) fails with EIO and the GPIO clock (APER_CLK_CTRL
  bit 22) stays off. Find out why (runtime PM / clock in the DT) before
  software reads S2.
- Reset: U65 SGM706 supervisor drives PS_POR_B (C7) AND the IP101GA PHY
  RESET_N. Its manual-reset input ~MR (pin 1) has only a 10 kOhm pull-up
  (R2336): a button from U65 pin 1 to GND = full board reset (debounced by
  the supervisor). PS_SRST_B (B10): 100 kOhm pull-up only. WDI (watchdog)
  unconnected.
- Fan connectors J3/J5 (optocouplers, but NOT isolated: see section 11):
  U12 -> J3 pin 4 (PWM out, PC817
  U69), V13 <- J3 pin 3 (tach in, EL817 U67), V12 -> J5 pin 4 (U70),
  V15 <- J5 pin 3 (U68). Bank 34, LVCMOS33.

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
  **DONE 2026-10-28:** `sw/tools/debaz-mac.sh` (commissioning, as root):
  MAC = md5("debaz:" SD CID), locally administered unicast, written as
  `dz_ethaddr=` + `uenvcmd=setenv -f ethaddr ${dz_ethaddr}` (a plain
  `ethaddr=` is refused: write-once env flag); hostname debaz-<last 3
  bytes>. U-Boot's fdt fixup gives it to the kernel. Tested: 00:0a:35:00:1e:53
  -> 66:af:a3:4d:9c:fa after one reboot. The Ebang NAND MAC
  (`eth0_mac.conf`) is 8C:C7:D0:0F:4F:C1 on two different boards: NOT
  unique, not used. Automatic: recipe `meta-user/recipes-apps/debaz-firstboot`
  (debaz-mac.sh from sw/tools + debaz-firstboot.service, enabled, before
  the network): a card without a MAC in uEnv.txt commissions itself and
  reboots once. In the config, NOT built yet (2026-10-28); unit dry-tested
  by hand on the board (MAC present -> no action).
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

- **DONE 2026-10-28 (in the image config, built, not yet on a card):**
  `sw/tools/debaz-firstboot.sh` (debaz-firstboot.service, every boot,
  idempotent): with >= 2 GiB free after p2 it appends p3 `DEBAZDATA` (ext4,
  256 MiB, `/data`) and p4 `DEBAZMEDIA` (**exFAT**, the rest,
  `/media/debaz`, uid/gid ebaz, fmask 0133 / dmask 0022) with sfdisk
  --append + partx -a (no reboot), writes the fstab lines (by label,
  nofail), makes `/media/debaz/{img,movies,audio}`, moves files from
  `/home/ebaz/{img,movies,audio}` there and leaves symlinks, then runs
  debaz-mac.sh --firstboot. Without free space `/media/debaz` stays a
  folder on the root (the second board: root grown by hand). All software
  uses `/media/debaz` (DZ_MEDIA_DIR, dzweb -m default, avplay/avswitch,
  mkmedia -m). Tested on a loop-device copy of the layout on the board
  (partitions, labels, idempotent second run, exFAT writable by ebaz) and
  for real in the no-space case on the second board; the fstab mount step
  runs first on a fresh card. The WIC image has p1 2 GiB + p2 4 GiB, so a
  16 GB card gets ~9 GiB of media.
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
The NAND holds the original Ebang "Ebit" miner firmware, dumped and split
2026-10-26: `original_flash/README.md`. It stores each board's FACTORY MAC
(`eth0_mac.conf`, this board 8C:C7:D0:0F:4F:C1): debaz-firstboot can read it
from /dev/mtd0 for uEnv.txt instead of a CID-derived MAC.

## 11. Audio, extra I/O, PL resources, 1080p (analysis, 2026-10-26)

### Where the PL is now (Tcl build 20261025, routed)

LUT 10237/17600 (58%), FF 17411/35200 (49%), Slice 4302/4400 (98%),
BRAM36 57.5/60 (96%), DSP 73/80. 824 control sets, 1453 unused register
places in used slices.

- The slice figure overstates the fullness: LUTs need >= 2560 slices, FFs
  >= 2177; Vivado spreads the logic when it has room and packs tighter when
  it must. The real limits are BRAM (96%), DSP (91%) and the **pixel clock
  region**: the regional BUFR pixel clock keeps all pixel-domain logic in
  clock region X1Y1 (about 1/4 of the die). New pixel-domain logic (an
  HDMI audio encoder, the view scaler) competes there. The dual-BUFG
  axi_dynclk change (CLAUDE.md "Regional pixel-clock architecture") removes
  that limit and is also needed for 3out0in; do it first.
- Biggest blocks: HDMI_0 mixerMatrix 1901 LUT / 2679 FF / 54 DSP; v_tc
  951 LUT / **2597 FF**; VDMAs 907 / 905 / 1375 LUT (1355-2083 FF each);
  three AXI interconnects (VDMA -> HP, packet FIFO + regslices) 252-364 LUT,
  627-767 FF each; ps7_axi_periph 776 LUT (crossbar already "minimize
  area"); 5 AXI GPIOs 63-160 LUT, 222-453 FF each.
- BRAM36: dds_compiler 7 + 7 (+1 B18 each: 16-bit output at full 16-bit
  accuracy), mixer delay line 11, VDMAs 5 x 3, v_vid_in FIFO 7 (8192 deep),
  vid_out FIFOs 3 + 3 (4096 deep), interconnect FIFOs 1 x 3.

### Resource recovery, cheapest first (ONE build tests a whole group)

A full build of this design takes about 15 min on the laptop (not an
hour). The build machine (8 cores, 62 GB) can run 3-4 implementation
strategies in parallel from one synthesis: `launch_runs impl_1 impl_2
impl_3 ...` with Area_Explore / Area_ExploreSequential / default, then
compare. Group the changes so one build checks many.

1. BD parameters only (no RTL, no software change):
   - DDS: keep Output_Width 16 but lower the accuracy (Spurious Free
     Dynamic Range ~60-66 dB) -> about 6 BRAM36 free per DDS (~12 total).
     A video oscillator does not need 96 dB.
   - v_vid_in FIFO 8192 -> 4096 (still > 2 lines of 1080p): ~3 BRAM36.
   - VTC: switch off the generator features we do not use (chroma, field
     id, interlace, unused polarity/ blank options): fewer of its 2597 FFs.
2. RTL, small: mixer register file has a duplicate output-register stage on
   the same clock (CLAUDE.md): ~1-2k FF.
3. Bigger: replace v_tc with a small AXI-Lite timing generator (~100 LUT,
   ~200 FF instead of 951 / 2597); needs hdmi2 + debazd vsync changes.
   GPIO consolidation (5 AXI GPIO -> 1-2) after the address-map freeze.
4. Placement/packing: opt_design -control_set_merge, synth
   AreaOptimized_high in a parallel run; only if 1-3 are not enough.

### HDMI audio out (8 ch LPCM possible; start with 2 ch on one output)

**Block written and simulated (2026-10-26): `hw/rtl/hdmi_tx/`** (Verilog-2001,
BD module reference), a replacement for rgb2dvi with the same ports plus
`ctrl`, `fs_inc`, `aud_l/aud_r/aud_valid`. Ported from hdl-util/hdmi (MIT,
https://github.com/hdl-util/hdmi): data islands, ACR, Audio Sample (2 ch, 24
bit L-PCM), AVI / Audio / SPD InfoFrames, BCH ECC. Changes: the island
position comes from the incoming VTC timing (line length measured between
HSYNC edges, active width from DE, a 10-pixel look-ahead delay for the video
preamble), so every mode hdmi2 sets works; VIC and sample rate are run-time
inputs; Digilent's 3-stage TMDS encoder pipeline; a 1 kHz test tone on an
internal sample-clock NCO.
- `ctrl = 0` = DVI: the TMDS words are the same as rgb2dvi's on every clock
  (simulated against a copy of TMDS_Encoder.vhd); latency +10 clocks for
  sync and data together.
- `sh hw/sim/run_hdmi_tx_tb.sh`: 4 modes (DVI, HDMI, HDMI + audio, test
  tone), a receiver-side decoder checks pixels, syncs, preambles, guard
  bands, TERC4, ECC of every packet, audio samples in order, parity, B flags,
  channel status, ACR N/CTS; AVI and Audio InfoFrame == the upstream modules.
  Two RTL bugs found and fixed by it (sample-buffer flag cleared one clock
  late; line length measured across the vertical blanking).
- ONE audio format (decision 2026-10-26: all media is pre-rendered):
  48 kHz, 2 ch, 16 bit. One sample per Audio Sample packet, 4-deep LUTRAM
  FIFO, one BCH engine; AVI (VIC select 4/34/16/none) and Audio InfoFrame
  are a generated constant ROM (`gen_rom.py` -> `hdmi_tx_rom.v`, ECC
  included, like the EDID ROM); SPD dropped. ctrl: [0] HDMI, [1] audio,
  [2] tone, [9:8] AVI VIC select.
- Out-of-context synthesis: 630 LUT, 441 FF, no BRAM/DSP (first version
  927 / 1005; rgb2dvi about 100 LUT/FF); 720p60 +3.4 ns, 1080p60 -3.4 ns.
- Audio IN (built 2026-10-26, branch hdmi-audio): EDID with only L-PCM
  2 ch 48 kHz 16 bit + HDMI VSDB (`hw/edid_audio.py`); dvi2rgb fork exports
  `pRawSym`; `hw/rtl/hdmi_tx/hdmi_rx.v` between dvi2rgb and v_vid_in fixes
  DE/syncs for HDMI sources (dvi2rgb alone would capture islands as video)
  and extracts the audio; loop into hdmi_tx on HDMI_1 by `/audio/rx/loop`.
  Output with audio on HDMI_1 (HDMI_0 keeps the VTC and may become an input
  in a 1out2in variant).
- HARDWARE RESULT 2026-10-26: output tone on a scope behind an HDMI audio
  extractor; laptop -> HDMI_2: ELD "DGL 720P CEA" LPCM 2 ch 48 kHz 16 bit,
  islands + audio flags, N 6144, CTS 74250 (exact), a left-only 4096 sine
  read back as peak L 4096 / R 0 at 100 % laptop volume; capture DMA error
  bits stay clear with an HDMI source (DE/sync fix works); /audio/rx/loop 1
  plays the laptop audio on HDMI_1 (heard). Gotchas: (1) every PL reload
  bounces HPD_2; the laptop's i915 then switched that port to polling ("HPD
  interrupt storm") and did not redo the mode set: unplug the cable >= 15 s
  so it switches to HDMI audio. Software HPD control would avoid it. (2) the
  laptop's HDMI 1 sink was at 153 % volume (+11 dB): peaks read 3.55x high.
- Test plan (board): load the build with plreload.sh; `/audio/tx/hdmi 1`,
  `/audio/tx/enable 1`, `/audio/tx/fs_inc 2776544`, `/audio/tx/tone 1` ->
  the HDMI audio extractor on HDMI_1 plays 1 kHz. Laptop -> HDMI_2: the
  laptop must now offer "HDMI audio" for that output (EDID); play a tone,
  read `/audio/rx/{islands,active,n,cts,samples,peak/l}` (N 6144, CTS 74250
  at 720p60), check the capture picture is still clean (DE fix), then
  `/audio/rx/loop 1` with tone off -> laptop audio on HDMI_1.


Background (still valid): data-island periods in the blanking (TERC4,
guard bands, preambles), packets (ACR N/CTS, AVI, Audio InfoFrame, Audio
Sample; BCH ECC). 8 ch = "layout 1" sample packets; at 720p60 and 1080p the
blanking has room for 8 ch at 48 kHz (the block does 2 ch).
- Linux side: the kernel ALREADY has ALSA + SND_SOC_XILINX_AUDIO_FORMATTER +
  SND_SOC_XILINX_PL_SND_CARD (built in, 2026-10-26 image; /dev/snd only has
  "timer" now). Path: Xilinx Audio Formatter (MM2S, DMA from DDR) -> AXIS
  audio -> async FIFO (LUTRAM) -> HDMI packetizer. The PL sound-card driver
  expects a codec-side IP; with the Xilinx I2S Transmitter (enable
  SND_SOC_XILINX_I2S in the kernel) the same stream ALSO goes out as real
  I2S on PL_KEY pins (external DAC). Sample clock: an NCO from the pixel
  clock is enough for HDMI (the N/CTS packets carry the ratio); two PLLE2
  are free if an exact 12.288 / 11.2896 MHz is wanted.
- One output with audio is enough (as wanted); doing both later is a copy.

### HDMI audio in (2 ch) on HDMI_2

- dvi2rgb decodes only video/control periods. Needed: TERC4 decode of the
  data islands (dvi2rgb fork: export the 10-bit symbols), packet assembly +
  BCH check, Audio Sample + ACR parsing -> AXIS -> Audio Formatter S2MM ->
  ALSA capture. Estimate 500-800 LUT.
- EDID must change, or no source sends audio: add an HDMI Vendor-Specific
  Data Block + Audio Data Block (2-ch LPCM 32/44.1/48 kHz); do NOT
  advertise YCbCr (keep RGB, so the video path is unchanged).
- For audio-reactive use, exact sample-rate recovery is not needed (analyse
  at the nominal rate).

### PL_KEY0-5 as I2C / SPI / UART / I2S (no new pins, little logic)

**Built 2026-10-27 (branch hdmi-audio), simulated, NOT yet on hardware:**
`hw/rtl/pl_io/` = per-line function select (4 bits per line: in, out, I2C0
SCL/SDA, SPI0 SCLK/MOSI/MISO/CS0/CS1, UART0 TXD/RXD, I2S BCLK/LRCLK/DOUT/DIN)
+ an I2S master (dz_i2s.v) + two async FIFOs (dz_async_fifo.v). PS I2C0/SPI0/
UART0 on EMIO (standard Linux drivers). Registers 0x43C6_0040: IO_FUNC,
IO_OUT, IO_IN, I2S_CTRL, I2S_INC, I2S_STATUS. Test
(`sh hw/sim/run_pl_io_tb.sh`): reset = all inputs, every function on the pins
with 10k pull-ups, I2S pin format decoded independently, HDMI_2 audio -> DOUT
-> wire -> DIN -> HDMI_1 sample for sample with the source 200 ppm fast (FIFO
pre-fill + level steering: no underrun, no lost sample). Linux side in
PetaLinux/ (dtsi nodes, kernel fragment, i2c-tools); needs a PetaLinux build
with the new XSA. Hardware test plan: `/io/pin 0 scl; /io/pin 1 sda;
i2cdetect -y 0` with a sensor; `/io/pin 2 txd; /io/pin 3 rxd` + a loop wire,
`cat /dev/ttyPS1`; I2S: a PCM5102 board on bclk/lrclk/dout.


- Pins (3xHDMI v2, verified against the EBAZ netlist, header numbering is
  mirrored between the two KiCad projects): PL_KEY0 U19 (SW1), PL_KEY1
  V20 (SW2), PL_KEY2 T19 (SW3), PL_KEY3 U20 (SW4) - bank 34; PL_KEY4 **K17**
  (SW6, clock-capable MRCC: external word/bit clock input possible), PL_KEY5
  **E19** (SW5) - bank 35. Each line: 10 kOhm pull-up to 3V3 + button to
  GND, NO capacitor -> fit for MHz signals.
- Best route: the PS's own controllers through EMIO, with an IOBUF per pin
  in the PL: I2C0/1 (cdns-i2c), SPI0/1 (spi-cadence; add spidev), UART0
  (xuartps; UART1 is the console), CAN0/1. Standard Linux drivers, almost
  no PL logic. A small per-pin "function select" register (like the MIO
  mux) lets ONE bitstream offer GPIO / I2C / SPI / UART / I2S per pin.
- EMIO for these controllers is a PS7 change -> part of the PS contract
  (section 8): enable them ONCE for all variants (FSBL rebuild once).
- I2C: the 10 kOhm pull-ups are already there (fine for 100 kHz).
- I2S out: from the audio path above (BCLK, LRCLK, SDATA, optional MCLK).
- MIDI: UART0 at 31250 baud + a standard MIDI opto circuit (6N138 /
  H11L1) on a small add-on board. DMX512 / RS485: UART0 at 250 kbaud 8N2
  + a MAX485 module (driver enable on a GPIO). Not through the fan optos.
- Caution: a button pressed while its line is a driven-high output shorts
  the output; use series resistors on add-on boards or do not press.

### Fan connectors J3/J5 as I/O (measured from the netlist, 2026-10-26)

- NOT galvanically isolated: fan ground GND3 is tied to logic GND by L36
  (0.33 uH, a filter). The optos are 12 V <-> 3.3 V level shifters.
- Pin 4 output: FPGA low -> PC817 on -> pin 4 pulled to ground; 10 kOhm
  pull-up to 12 V (VCC8). Inverted, open collector, 12 V level. Another
  output level: replace the pull-up (R2350 / R2556) and pull up externally.
- Pin 3 input: external device pulls pin 3 low -> ~1 mA through the EL817
  LED (10 kOhm from 12 V) -> FPGA reads low. Active low; contacts or open
  collector outputs.
- Speed: PC817/EL817 with 10 kOhm loads and 1-3 mA LED current -> edges of
  tens of microseconds -> reliable up to a few kHz (measure).
- Good uses: low-frequency PWM for motor controllers, LED drivers, RC servos
  (50 Hz, 1-2 ms), 12 V relay/SSR/camera/strobe triggers; contact closures,
  PIR, limit switches, tach/encoders at low rates; and a **frame-sync pulse
  between units** (vsync out on one unit's pin 4 -> other units' pin 3:
  hardware sync within tens of microseconds, well inside one frame -
  better than network sync for FLEET.md level A).
- Not suitable: MIDI (31.25 kbaud needs fast optos), DMX512 / RS485 (250
  kbaud, differential), I2C, SPI. Slow UART (<= ~2400 baud) is possible.

### 1080p: memory and buffers

- DDR: OK. Slot pitch is already 1920x1080x4 (8,294,400 B); 12 slots =
  94.9 MiB, inside the 96 MiB reservation.
- PL buffers: OK for 1080p (VDMA line buffers 4096 px, v_vid_in 8192 px,
  vid_out 4096 px; mixer delay 16384 px = 8.5 lines).
- Software: NOT yet. dz_hw.h fixes DZ_WIDTH/HEIGHT 1280x720 and stride =
  width x 4; hdmi2 CAPTURE_W/H 1280x720; fb0 (simplefb) is 1280x2160, so it
  spans slot 0 and part of slot 1. Plan: ONE fixed stride of 1920 px (7680
  B) in every slot and every mode; width/height at run time from the video
  mode; fb0 = 1920x1080 = exactly slot 0. Then any mode up to 1080p uses
  the same buffers, and a 720p mode shows the top-left 1280x720.
- RAM: a dz_draw shadow buffer at 1080p is 8.3 MB; Linux has ~150 MB, so
  only a few surfaces can be active at once (transforms double that).
- Video timing at 1080p60 (148.5 MHz) is a separate gateware item: the
  effects chain needs a register after each multiplier/adder (section 8).

## 12. Mixer video functions (2026-10-26)

What the hardware gives (CLAUDE.md "Colour matrix math"): HDMI_0's video goes
through a 3x3 matrix of UNSIGNED gains (1.0 = 0x10000, no saturation); the
9 mixer channels make the gains, per pixel, from HDMI_1's pixel. HDMI_1's
pixel itself never reached HDMI_0's output before the key.

### Colour matrix: hue shift and colour map (software, done)

`sw/debazd/fx.c`, works on every bitstream (mode 4 = constant K on all 9
channels; it replaces the boot setup's band-clip channels until the next
mixer setup):

- `/fx/hue deg [gain]` - rotation about the grey axis. Without negative
  gains, the negative terms are clipped and each row is scaled to 1.0:
  exact at 0/120/240 deg (permutations), darker and less saturated between
  (60 deg: pure red -> half-bright yellow).
- `/fx/map 0xRRGGBB 0xRRGGBB 0xRRGGBB` - where input red, green and blue
  go (the matrix columns). `/fx/matrix` 9 values, `/fx/identity`.
- `/fx/wrap 1` - allow row sums > 1.0 (bright colours wrap: an effect).
- Next: an LFO target (`/fx/hue $0`) for a hue cycle; a UI card in dzweb.
  For full-saturation hue rotation, the gateware needs signed gains
  (xbip_multadd c_a/c_b type signed + a clamp after the sum, ~30 LUT/lane).

### RGB colour key (gateware, simulated 2026-10-26, test on hardware next)

In the mixer IP (coreRevision 22), in spare control bits, no new register:
per channel CTRL_1 [1] KEY (the channel's lo..hi band joins the mask, AND)
and [2] SRC (compare HDMI_0's video instead of HDMI_1); channel 0 CTRL_0 [8]
invert and [9] fill from stream B. A 24-bit colour box = ch0 R, ch3 B, ch6 G.
In the box (XOR invert), HDMI_1's pixel replaces HDMI_0's matrix result,
before colorGainMain; a registered 2:1 pixel mux, no DSP. Default test =
HDMI_1's pixel; `/key/invert 1` = classic green screen (HDMI_1's green parts
show HDMI_0); `/fx/key/source 1` = test HDMI_0 ("HDMI_0's blue sky becomes
HDMI_1"). The same rework removed the mixer's duplicate output-register stage
(measured: FF 17411 -> 17100, slices 4302 -> 4209; Vivado had already merged most of the copies); an equivalence simulation against the old mixer passes
(`hw/sim/run_mixer_tb.sh`).

Deployed 2026-10-26 with fpga_manager (`sw/tools/plreload.sh`, capture
soft-reset first; the network stayed up): both display VDMAs run, vsync 60.03
Hz, capture re-armed, all key fields read back. Picture NOT yet checked (the
user was away). `sw/tools/keytest.sh` sets up the test below; after a reboot,
first `cp /home/ebaz/ebaz4205_2out1in_20261026_key.bit.bin /tmp/` + plreload.

Test plan on the board (`artifacts/ebaz4205_2out1in_20261026_key.bit`; stop
capture first):
1. Key off: the picture is unchanged (only 1 px later). Run the boot mixer
   setup and the usual effects: same look as before.
2. Solid colours: `/draw/0/solid 0 255 0` on display 0's slot, a movie on
   display 1; `/fx/key/source 1` + `/fx/key/color 0x00ff00 30` -> display 0
   shows HDMI_1. Then `/fx/key/source 0`: key on HDMI_1's own colours.
3. Movie on both; key a colour range of the movie; check `/key/invert`.

Timing (routed, 2026-10-26, PXL_CLK constrained at 10 ns): pixel WNS -7.14
ns (20261025 build: -7.59), TNS -1262 (was -1519); worst path is still the
dormant mode-1 MAC (stream-B BRAM -> dout_r). Into the new mux register:
13.8 ns (the 3-DSP matrix chain; passes at 720p30, 0.3 ns over at 720p60);
after it: +3.6 ns slack into colorGainMain. HDMI_1 encoder paths meet (+3.5).

Next steps for the key:
- Soft edge: a per-pixel alpha from the distance to the box (one 8x8
  multiply per lane = 3 DSP, or 2-bit steps in LUTs).
- Key in YCbCr/hue space (chroma key independent of brightness): an RGB ->
  hue/chroma stage in LUTs before the comparators.
- Key mask as a matrix gain source (a mixer mode "K if keyed"), so the
  matrix effects apply only inside or outside the key.

## 13. Linux audio: an ALSA card for the HDMI and I2S audio (design, 2026-10-27)

Why: with a real ALSA card, standard software works without our own daemon:
aplay/arecord, amixer + alsactl (installation setup saved and restored at
boot), ffmpeg `-f alsa`, synthesis software, network players (snapclient,
shairport-sync, GStreamer, PipeWire). Today the audio paths are PL-only (HDMI_2
loop, I2S in, test tone); Linux cannot play into them or record from them.

### What the card looks like (proposal)

Card `DEBAZ` (`/proc/asound/cards`), one PCM device per stream, so every
application can name its output (`hw:DEBAZ,0` etc.):

| PCM | Direction | Stream |
| --- | --- | --- |
| 0 "HDMI 0" | playback | HDMI_0 audio |
| 1 "HDMI 1" | playback | HDMI_1 audio |
| 2 "HDMI 2 In" | capture | audio from the HDMI_2 source |
| 3 "I2S" | playback + capture | the user I/O lines (DAC / ADC) |

All S16_LE, 2 channels, 48000 Hz only (the one format of the design; ALSA's
plug layer converts other formats in software). One PCM per stream rather
than subdevices of one PCM: clearer names for applications and amixer.

amixer controls (all map onto registers that already exist, so installation
routing is `amixer`/`alsactl` instead of debazd fields):
- `HDMI 0 Source`, `HDMI 1 Source`: enum {Linux, HDMI 2 loop, I2S in, Test tone, Off}
- `HDMI 0 Mode`, `HDMI 1 Mode`: enum {DVI, HDMI} (TX_CTRL/TX0_CTRL bit 0)
- `I2S Out Source`: enum {Linux, HDMI 2 in, Off}; `I2S Clock Follow` switch (steering)
- `HDMI 2 Hotplug` switch (RX_CTRL[2]), read-only `HDMI 2 Locked`, `HDMI 2 Peak L/R`
- Volume: softvol in `/etc/asound.conf` per device (no multipliers in the PL:
  DSP 91 % used); dmix per output so several programs can play at once.

### Hardware (gateware) needed

Small, all in `pl_io` / `hdmi_audio_regs` (no DMA, no new AXI port):
1. A 48 kHz pacer on FCLK0 (fixed NCO from the 100 MHz crystal clock). It
   takes the place of the pixel-clock NCO for everything that Linux feeds, so
   the rate no longer depends on the video mode (`fs_inc` then only serves
   the test tone).
2. Per playback stream a FIFO (64 x 32 bit, LUTRAM) written through one
   AXI-Lite data register; the pacer pops one word per sample and feeds the
   existing source selectors (`Linux` = this FIFO).
3. A capture FIFO from `hdmi_rx` samples (rx clock -> FCLK0).
4. Level registers + one interrupt (FIFO half empty / half full) on a spare
   IRQ_F2P input (HDMI_0's concat has spare inputs).
Estimate: 150-250 LUT. Slices are at 96.6 % (2026-10-27): it should fit; if
not, do the resource savings of section 11 first.

**DONE in RTL + simulation (2026-10-27, build `pcm`):** as above, but the
FIFOs are block RAM, 512 x 32 each (4 of the 5 free BRAM18;
`hw/rtl/pl_io/dz_bram_fifo.v`): 10.7 ms of audio per stream, so the driver
can use periods of up to ~240 frames. Capture comes from the HDMI_2 receiver
(`hdmi_rx`), I2S capture is not in it yet (the I2S input still goes only to
the HDMI outputs). Interrupt = HDMI_0/In4 = IRQ_F2P[7] = GIC SPI 36 (DT
`interrupts = <0 36 4>`, level high). Routing: I2S_CTRL [6] HDMI_0 = PCM 0,
[5] HDMI_1 = PCM 1, [7] I2S DOUT = PCM 2 (these win over the other source
bits). A running stream with an empty FIFO sends silence and latches an
underrun. Registers (hdmi_audio_regs 0x43C6_0000):

| Offset | Name | Content |
| --- | --- | --- |
| 0x60 | PCM_CTRL | [3:0] run (0 HDMI_0, 1 HDMI_1, 2 I2S, 3 capture), [11:8] write 1 = flush |
| 0x64 / 0x68 / 0x70 | PCM0/1/2_DATA | write one frame {R[31:16], L[15:0]} |
| 0x6C | CAP_DATA | read = oldest captured frame, and removes it |
| 0x74 / 0x78 | LEVEL01 / LEVEL2C | FIFO levels {PCM1, PCM0} / {CAP, PCM2}, 10 bits at [25:16] / [9:0] |
| 0x7C | IRQ_STATUS | [3:0] live level condition (playback level <= threshold, capture level >= threshold), [7:4] xrun latch, write 1 to clear |
| 0x80 | IRQ_EN | mask for IRQ_STATUS [7:0] |
| 0x84 | PCM_FRAMES | 48 kHz pacer count |
| 0x88 / 0x8C | THRESH01 / THRESH2C | thresholds, 9 bits at [24:16] / [8:0] |

Driver sequence per playback stream: flush, pre-fill up to 512 frames, set
the threshold (e.g. 512 - period), set run, enable the level IRQ; in the
IRQ, write frames until the level is above the threshold (or disable the
bit when the ALSA buffer has no more data). Test: `sh
hw/sim/run_pl_io_tb.sh` (`pcm_tb`: all four streams in order at 48 kHz,
level IRQ, underrun IRQ + silence + clear, flush).

### Kernel driver (`debaz-audio`, out-of-tree module, PetaLinux recipe)

**WRITTEN + TESTED on the board (2026-10-28, test overlay + insmod; bitstream
edid2):** `meta-user/recipes-modules/debaz-audio/`, DT node in
`system-user.dtsi` (test: `hw/dt/debaz-audio.dtso`). Card DEBAZ, PCM 0 HDMI 0,
1 HDMI 1, 2 HDMI 2 In (capture), 3 I2S; controls `HDMI 0 Route`, `HDMI 1
Route`, `I2S Route` = Auto (Linux while the PCM runs) / Linux / Other.
Results: 60 s file (ffmpeg -f alsa, full buffer) 0 ALSA + 0 FIFO underruns,
~5 % CPU, ~1400 IRQ/s; capture 5.00 s exact, real levels; live loop
capture -> playback 5-6 ALSA underruns per 30-60 s (ffmpeg keeps only ~6 ms
in the playback buffer in a live loop: an application setting); drain ends
on time; plreload unbinds/binds the driver around a PL load. Lessons: the
playback pointer must be the PLAYED position (moved - FIFO level), moves
are limited to appl_ptr, the playback underrun latch must NOT be an
interrupt (it sets again every 48 kHz tick while empty = interrupt storm),
starving = threshold 0 so the empty FIFO reports the end of a drain.
Buffer max 16384 frames (341 ms).

**IN THE IMAGE + TESTED with alsa-utils (2026-10-28 evening, image of
commit e6fde117 on the second board, bitstream edid2):** the card binds at
boot (4 s), no overlay or insmod. All heard on the HDMI0 audio extractor.
| Test | Result |
| --- | --- |
| `aplay -l`, `amixer -c DEBAZ` | 3 playback devices; controls shown as `HDMI 0`, `HDMI 1`, `I2S` (the simple mixer drops "Route"), items Auto/Linux/Other |
| `speaker-test -c 2 -t sine` on hw:DEBAZ,0 (440 Hz) and hw:DEBAZ,1 (1800 Hz) at once | both complete, L then R; it takes 4 x 4096 frames (the maximum buffer) |
| Route during playback (`amixer sset "HDMI 0" ...`) | idle Auto 0, playing Auto 1, Other 0 (silence), Linux 1, stopped Linux 1, stopped Auto 0 |
| `aplay` WAV (440 Hz left, 1800 Hz right) | plays; `plughw` resamples 44.1 kHz |
| `arecord -D hw:DEBAZ,2 -d 5` | 5.00 s, mean -18.4 dB from the laptop |
| `arecord \| aplay` HDMI2 -> HDMI0, 30 s, `-B 100000` both | 0 underruns / overruns (the earlier ffmpeg loop underruns came from its ~6 ms buffer) |
| I2S PCM hw:DEBAZ,3 (`/i2s/on 1`, no DAC) | drains at 48 kHz (5 s in 5.08 s), route bit 7 follows Auto |
| `alsactl store` / `restore` | route saved and restored; `alsa-restore.service` restores at boot and stores at shutdown (/var/lib/alsa/asound.state) |
**OSC + web control (2026-10-28, tested on the board):** debazd `sound.c`
(`/audio/out/<n>/source`, `/audio/play|stop|rec|rec/stop|status`, files in
/home/ebaz/audio), `/movie/<s>/play name fps audio-mask` (the movie's own
audio track to 1 HDMI 0 / 2 HDMI 1 / 3 both / 4 I2S), dzweb Media "Audio"
folder + the Audio tab (sources, play, record, input meters). Tested: auto
route bit 1 while a file plays / 0 after; 5 s recording exact; loop + stop
(immediate); movie mask 1 -> PCM 0 runs, mask 3 -> PCM 0 + 1; sources read
back after a debazd restart; web list / upload / delete. Details: sw/README.md.
**HDMI_2 audio after a hot-plug (2026-10-28, second board):** after a
physical replug the input delivered 38959 samples/s instead of 48000 with
CLEAN samples and clean video (1600x1200, 0 short lines): hdmi_rx drops a
subpacket with a BCH error (a packet with a header error), so the link had
bit errors on the data lanes - a marginal dvi2rgb alignment. An HPD replug
fixed it (3 of 3: ~48000/s). debazd now watches the rate (audio.c,
`/audio/rx/rate`, `/audio/rx/auto`): off by > 2 % for 3 s -> replug, at most
every 30 s. TODO gateware: count header / subpacket ECC errors (RX_STATUS)
for an exact link-quality value (errors that cost no samples too), and
check the alignment margin of dvi2rgb (kBlankTimeoutMs 2 ms) on this board.
(The full-scale peaks seen at the same time were the laptop volume.)
Notes: `alsactl` is in /usr/sbin (not in sudo's PATH: use the full path);
the UCM warning of alsactl ("failed to import hw:0 use case configuration")
is harmless (no UCM file for this card). A driver bind starts the controls
at Auto: plreload.sh runs `alsactl restore DEBAZ` after its re-bind
(commit c5953a19). Open: dmix/softvol `/etc/asound.conf` (one program per
PCM today), an ALSA control for the HDMI mode of an output (still
`/audio/tx*` in debazd), debazd leaving I2S_CTRL routing to the driver. debazd's
`/pcm/to_hdmi*` fields write the same I2S_CTRL bits: use one or the other.

- Platform driver, `compatible = "debaz,hdmi-audio-1.0"`, node in
  `system-user.dtsi` (REMOVE_PL_DTB: written by hand): reg 0x43c60000
  0x10000, the interrupt above. Registers an ALSA card (no ASoC needed: a
  plain `snd_card` + `snd_pcm` with vmalloc buffers).
- Data transfer by CPU (PIO): the IRQ handler copies one period (e.g. 32
  frames) between the PCM buffer and the FIFO data register and calls
  `snd_pcm_period_elapsed`. Cost: one AXI-Lite access per stereo frame,
  48k/s per stream, a few % CPU per stream. If that is too much later: an
  AXI master that reads a DDR ring buffer (S_AXI_GP / ACP; HP3 stays free for
  the third channel).
- kcontrols for the routing above, written to the same registers.
- Ownership: the driver owns 0x43C6_0000; debazd keeps reading the status
  fields but leaves the routing to ALSA when `/proc/asound/DEBAZ` exists.

### PetaLinux / rootfs

- DONE 2026-10-28: recipe `meta-user/recipes-modules/debaz-audio`
  (module.bbclass, `KERNEL_MODULE_AUTOLOAD`), the DT node in
  system-user.dtsi, rootfs alsa-utils (aplay/arecord, amixer, alsamixer,
  alsactl, speaker-test, alsaloop); `alsa-restore.service` is active.
- `/etc/asound.conf` (in the debaz-audio recipe, 2026-10-28, not built
  yet; installed by hand on the second board): default PCM = plughw:DEBAZ,0
  playback / plughw:DEBAZ,2 capture, default ctl = DEBAZ. Needed because
  alsa-plugins brings `99-pulseaudio-default.conf` (default = PulseAudio,
  no server in the image: `amixer` / `aplay` without -c/-D failed with
  "Connection refused"). TODO there: dmix + softvol per HDMI output.
- Kernel: CONFIG_SND and CONFIG_SND_PCM (already in the Xilinx defconfig);
  the 2023 Xilinx I2S / Audio Formatter / ADAU1761 fragment was removed
  2026-10-27 (no such hardware).
- Later, by need: ffmpeg with ALSA output (PACKAGECONFIG alsa), shairport-sync
  or snapclient (meta-multimedia), PipeWire.
- **Decision (user, 2026-10-28): no PulseAudio / PipeWire on the unit.** The
  complex sound design runs elsewhere (Max / Pd / Ableton / TouchDesigner);
  the unit plays, captures and routes, and later gets network audio, not
  much more. Estimate for PulseAudio here: 6-10 MB RAM, 1-3 % CPU per
  stream, 5-10 % per resampled stream, more latency, and its rewinds do not
  fit the FIFO driver - while a 720p movie already takes ~96 % CPU. Mixing
  and volume, when needed: dmix + softvol in /etc/asound.conf (no daemon).
  Network audio: one dedicated receiver (e.g. snapclient for synchronised
  multi-unit audio, or RTP / shairport-sync) that plays into hw:DEBAZ, chosen
  when the fleet work needs it. The alsa-plugins PulseAudio default is
  overridden by /etc/asound.conf; the plugin can leave the image (done:
  `meta-user/recipes-multimedia/alsa/alsa-plugins_%.bbappend`, not built yet).
- **MIDI (decision 2026-10-28):** live MIDI comes over the network. Kernel
  fragment `user_2026-10-28-midi.cfg` (not built yet): ALSA sequencer,
  seq-dummy, hrtimer, rawmidi, virmidi, plus snd-aloop for routing tools,
  all built in. Side effect: VirMIDI and Loopback are extra cards at boot,
  so DEBAZ may not be card 0 - always name it (`hw:DEBAZ,N`, `-c DEBAZ`;
  asound.conf does). Next, when needed: OSC -> synth (debazd passes
  /midi/... to e.g. fluidsynth's command interface; no MIDI stack needed),
  or rtpmidid (RTP-MIDI/AppleMIDI, needs the sequencer; no recipe yet).
  The synth itself: TBD.
- **Streaming audio to the fleet instead (estimate):** 48 kHz 16 bit
  stereo = 1.54 Mbit/s raw (about 1.6 with RTP/UDP headers). Unicast to 12
  units = ~19 Mbit/s from the sender, multicast = ~1.6 Mbit/s in total;
  the units have 100 Mbit/s ethernet. So streaming PCM is cheap; a synth on
  each unit only matters for independent, generative audio per unit.

### Order and test

Gateware 1-4 + simulation (a testbench with a model of the driver's FIFO
writes) -> build -> driver + recipe -> `aplay -D hw:DEBAZ,0 tone.wav` on the
HDMI audio extractor, `arecord -D hw:DEBAZ,2` from the laptop, `amixer -c
DEBAZ` for the routing, `alsactl store`.

## 14. DDS pattern engine `dz_osc` (design 2026-10-29)

Why: the plan of record was to make complex DDS patterns ("FM" patterns,
checkerboards) from the CPU, by writing the DDS increment many times per
frame. That does not work: an 8x8 checkerboard at 720p60 needs row edges
every 90 lines with about one line (22 us) of accuracy, and the wake-up
jitter of a 5.15 PREEMPT userspace thread is about 50-200 us (milliseconds
under movie / upload load); exact timing would need busy-waiting through
every frame (a whole A9 core). Edges inside a line (13 ns per pixel) are
impossible from the CPU. The CPU stays right for PER-FRAME control
(debazd's vsync thread, lfo.c: 60 writes/s); everything per line or per
pixel goes into the PL.

Facts (BD, 2026-10-29): both DDS compilers run on FCLK0 (100 MHz; CLAUDE.md
said HDMI_1's ran on PixelClk - not in this BD). The pixel clock comes from
FCLK0 (dynclk MMCM reference), so the DDS and the raster are frequency-locked
(rational ratio), not phase-locked: patterns roll unless reset by the raster.
Measured in the routed `fs` design: each DDS compiler uses **7 RAMB36 + 1
RAMB18** for its sine (32-bit phase, 16-bit output: 15 of the 58 BRAM tiles
for two sines), 67-75 LUT, 167-199 FF; each dds_axi_interface 28-30 LUT,
140 FF (a useless 2-FF synchronizer: both sides on FCLK0).

Decisions (user, 2026-10-29): 100 MHz (FCLK0) is the base clock; the DDS
gets the streaming control scheme (the phase every clock); the remaining
BRAM goes to a waveshaper / AWG; nothing is removed yet; one AXI port for
both DDS. The mixer MAC matrix + per-pixel feedback path is the core of the
device: never a candidate for removal (optimise it instead).

### Files (2026-10-29)

`hw/rtl/dz_osc/`: `dz_osc2.v` (top: one AXI-Lite port of 32 KB, channel 0
at +0x0000, channel 1 at +0x4000; shared raster synchronizers; the chain
inputs of each channel are the other channel's step / wrap pulses),
`dz_osc_ch.v` (one channel; register map in its header), `dz_sine_rom.v`
(GENERATED by `gen_sine.py`: quarter-wave 1024 x 16, registered case ROM,
no .mem file). Outputs per channel: wave (old sine leg), phase[31:16] (old
phase leg), the full phase without delay (event block); 3 clocks from the
phase. The DDS compiler is no longer needed (sine inside).

### Function (per channel)

- Owns the phase accumulator: phase = acc + POFF + line offset + frame
  offset + step phase; streams it every clock.
- **Segment sequencer**, 16 steps {START, DELTA (signed, per tick), LEN |
  KEEP | RST, PHASE}: square / pulse width / ramp / triangle are special
  cases; KEEP continues from the current increment; RST restarts the
  phase; one shot; restart at vsync.
- **Tick sources**: 24-bit prescaler on FCLK0 (the second divided
  frequency), hsync, vsync, line start (DE), the other channel's step or
  wrap (divider chains, cross-modulation), an external trigger.
- **Raster sync**: phase reset at hsync / vsync / line start (standing
  patterns), LINESTEP (per line: slants, diagonals), FRAMESTEP (per frame:
  scrolling), commit at vsync for PINC / POFF / CTRL (tear-free changes).
  Syncs come into FCLK0 through 2 FF: an edge moves by at most 10 ns
  (~0.75 px at 74 MHz).
- **Shapes**: sine, saw up / down, triangle, square, pulse (phase < PWIDTH),
  **AWG** (2048 x 16 table, indexed by phase[31:21]); output MSB flip
  (two's complement <-> offset binary); all aligned with the sine latency.
- Registers +0 PINC (bit 31 valid; a write without it is IGNORED, as
  before; reset 0x8000_0001) and +4 STATUS bit 0 stay compatible: all
  existing software keeps working. Full map in the file header. Step and
  AWG tables are write-only (one RAM port each; the software keeps a copy).
- Example, 8x8 checkerboard with no CPU: PINC = 8 cycles per line, phase
  reset at hsync, tick = hsync, steps {P,0,rows} {P,0,rows | PHASE 180 deg}.

Test: `sh hw/sim/run_dz_osc_tb.sh` (Verilator; ALL PASS 2026-10-29, both
channels): IDs and reset values of both channels, the old PINC rule,
square / ramp+triangle (KEEP) / one shot tick by tick, phase reset at
hsync, line and frame steps, commit at vsync, all shapes (own sine against
the gen_sine.py formula with the quadrant logic) and the phase outputs
clock-exact, AWG through AXI, channel 1 stepping on channel 0's step
pulses, external trigger, step RST.

Resources, one channel out of context (XC7Z010, placed + routed, 10 ns):
first version 877 LUT / 964 FF / 319 slices / 2 BRAM tiles (the AWG had 3
ports and was duplicated); after write-only tables, one table read address
(DELTA latched), 16-bit phase leg, commit shadows only for PINC/POFF/CTRL,
fewer pipeline registers: **677 LUT (84 LUTRAM, 19 SRL) / 784 FF / ~236
slices / 1 BRAM tile / 0 DSP, WNS +0.90 ns**.
**Both channels (`dz_osc2`, own sine): 1361 LUT (184 LUTRAM) / 1508 FF /
~469 slices / 2.5 BRAM tiles (2 AWG RAMB36 + ONE RAMB18: Vivado merged the
two identical sine ROMs into one dual-port RAMB18) / 0 DSP, WNS +0.71 ns.**
Against the parts it replaces (routed `fs`): 2 DDS compilers 142 LUT /
366 FF / 15 BRAM tiles, 2 dds_axi_interface 58 LUT / 280 FF, one crossbar
port ~30 LUT: **net ~+1130 LUT, ~+860 FF, -12.5 BRAM tiles, 0 DSP.**

### Plan

1. DONE in RTL: **dual-channel top, one AXI port** (`dz_osc2`): one 32 KB subordinate at
   0x43D0_0000, channel 0 at +0x0000 (the old HDMI_0 address), channel 1 at
   **+0x4000** (0x44D0_0000 disappears: the two windows are 16 MB apart, an
   AXI window must be aligned to its size). One AXI handshake, one set of
   raster synchronizers, internal chaining; one ps7_axi_periph port less
   (the crossbar costs ~30 LUT per port; a free M port suits the third-port
   rule). Software: libdz / dz_fields take bases from hw_map.h (generated);
   dz_fields gets channel 1's new offset; the old debazarosit.sh (not used)
   still writes 0x44D0_0000.
2. DONE in RTL: **own sine table**: a quarter-wave table, 1024 x 16 in one RAMB18 per
   channel (4096 points, spurs ~ -72 dBc: invisible), then the DDS
   compilers go entirely. Net with both channels: BRAM ~15 tiles -> 3
   (2 sines + 2 AWG = 3 tiles), **~12 tiles free**; minus the compilers and
   the old interfaces (~200 LUT, ~650 FF). Estimated net cost of the whole
   engine: ~+1150 LUT, ~+900 FF, -12 BRAM tiles, 0 DSP.
3. DONE 2026-10-29 (build `osc`, ON THE BOARD, details below the plan).
   **BD**: replace dds_axi_interface_0/1 + both dds_compiler_0 with the
   module reference (dz_osc2: top level, FCLK0; build.tcl reads the three
   files); wire wave_out to the old sine leg (div16_8_recip_0
   num), phase_out to the old phase leg (div16_8_recip_1 via the slice), the
   full phase to hdmi_audio_regs dds_phase (event block), VTC vsync / hsync
   / active_video in (shared VTC, discrete nets - see the IPI interface
   gotcha). Build, timing (FCLK0 has +0.5 ns; FCLK2 is the tight clock),
   hardware test.
4. **Software**: debazd fields + OSC presets that compute PINC from the
   measured pixel clock: /dds/<n>/square, /ramp, /triangle, /pulse,
   /checker cols rows, /seq/<i>, /sync, /linestep, /framestep, /shape,
   /awg (load a table from a file or a formula); a web card.
5. Later, by need: phase accumulator in the pixel clock domain (exactly
   raster-locked edges; costs logic in the congested region X1Y1) - only
   if the ~0.75 px shimmer is visible; the PWM as a channel of the engine
   (LED fades as ramp steps); HDMI_2 input vsync as a sync source.

### Step 3 result: dz_osc2 in the BD (2026-10-29, build `osc`)

`hw/bd_edits/2026-10-29_dz_osc2.tcl` (on the regs3 BD): the compilers, the
two AXI interfaces and both 32-bit phase slices (xlslice_4) out; new pins
HDMI_<n>/osc_wave, osc_phase; dividers' ce = xlconstant 1; dz_osc2_0 at the
top level on M07, ps7_axi_periph 10 -> 9 ports (audio M09 -> M08); address
0x43D0_0000, 32 KB. Software: sw/include/hw_map.h of build osc;
sw/lib/dz_hw.h maps HW_DDS_AXI_INTERFACE_0/1_BASE onto HW_DZ_OSC2_0_BASE +
0 / + 0x4000, so all old fields work (NEW software needs an osc bitstream:
on older ones channel 1 at 0x43D0_4000 is a bus error).

Build `osc` (default directives): LUT 12648 -> 13758 (+1110, as estimated),
FF 19673 -> 20530, BRAM tiles 45.5 of 60, DSP 73, **slices 100.0 %**;
FCLK0 +0.054, **FCLK2 -0.017 (1 endpoint, the capture S2MM datamover - the
known weak path, not dz_osc2)**, FCLK3 +0.067, pixel -3.389 (31). Timing
closure runs with other directives: build.tcl takes DZ_PLACE_DIRECTIVE /
DZ_ROUTE_DIRECTIVE from the environment. Four runs (routing AggressiveExplore
in all), FCLK0 / FCLK2 / FCLK3:
ExtraTimingOpt +0.079 / -0.333 / +0.389; Explore +0.431 / +0.006 / +0.485;
AltSpreadLogic_high +0.011 / -0.426 / +0.090; **ExtraPostPlacementOpt
+0.191 / +0.268 / +0.619** (pixel -3.485, 30) = artifacts/..._osc_epo, ON
THE BOARD. At 100 % slices the result depends on the run: every further
addition needs resource savings first (or a smaller dz_osc2: 8 steps).
Now the build.tcl defaults (place ExtraPostPlacementOpt, route
AggressiveExplore). Synthesis comparison on the same design (build machine;
LUT / FF / slices / FCLK0 / FCLK2 / pixel): default 13760 / 20530 / 4400 /
+0.191 / +0.268 / -3.485; AreaOptimized_high (all 73 per-IP runs) 12824 /
20404 / 4390 / +0.028 / +0.008 / -3.587; global synthesis 13656 / 20376 /
4392 / +0.344 / -0.073 / -3.365; global + AreaOptimized_high 12687 / 20237 /
4386 / +0.001 / +0.008 / -3.833. So area synthesis frees ~950 LUT (7 %) but
almost no slices - the slice count is packing / spreading, LUTs were at 78 %
before - and the timing margins become thin: not the default, an option
(DZ_SYNTH_DIRECTIVE) for a design that runs out of LUTs. Global synthesis
(DZ_SYNTH_MODE=global) needs a rename first: dvi2rgb and axi_dynclk both
define an entity SyncAsync with different content, and in one library
dvi2rgb becomes a black box (tested with axi_dynclk's renamed to
SyncAsyncDynclk on the build machine only; not in the repo).

Board test (debaz-7130d5, 2026-10-29): both IDs "DOSC", PINC reset
0x8000_0001, the phase runs at PINC x 100 MHz; /dds/0/hz, /dds/1/pinc and
the event block phase work unchanged; on HDMI_1 (osc layer, gains 1):
square 0.5 Hz, vertical bars (square, 4 or 8 cycles per line, phase reset
at hsync) and an 8-row checkerboard (sequencer, tick hsync, 2 steps of 90
lines, step 1 PHASE 0x8000_0000, restart at vsync) - also cleanly on black
with the HDMI_1 video and feedback gains at 0. The "green on / off" of the
square over video = the packed-lane adders (intentional). Lesson: CTRL[19]
(MSB invert) only for the sine; on the unsigned shapes it leaves a step of
1 (0x8000 / 0x7FFF).

### Audit: how the old DDS outputs are used (2026-10-29, BD + generated netlist)

- HDMI_0 (DDS + dividers on FCLK0, adder + mixer on the pixel clock): sine
  (16 bit, two's complement) -> div16_8_recip_0 (UNSIGNED 16/8, den
  0x4121_0000 ch1[31:24]) -> c_addsub_0 (signed 16+16 -> 16, wraps; offset
  0x4121_0000 ch2[15:0]) -> mixer din3; phase[31:16] -> div16_8_recip_1
  (den 0x4120_0008[31:24]) -> mixer din4; phase[31:0] -> event block.
- HDMI_1 (DDS on FCLK0; dividers, adders, gains on the PIXEL clock): sine ->
  div0 (den 0x4123_0000 ch1[31:24]) -> c_addsub_0 (+ 0x4123_0000 ch2[15:0])
  -> colorGainOscSin; phase[31:16] -> div1 (den 0x4126_0000 ch1[31:24]) ->
  c_addsub_3 (+ 0x4123_0000 ch2[31:16]) -> colorGainOscPhase; per lane
  osc16 (signed) x gain8 (unsigned) -> lane = product[15:8] = (osc g / 256)
  mod 256; c_addsub_4 = OscSin + OscPhase; c_addsub_2 = feedback sum +
  c_addsub_4 -> hdmi_tx. (colorGainMain / colorGainFeedback1: 8x8, lane =
  product[15:8] = pixel g / 256.)
- **INTENTIONAL (user, 2026-10-29): the overflow / clipping / wrapping math
  is a feature** - it lets users make more complex waveforms from the
  inputs. These stages stay as playable "sliders" after the generators,
  even where the AWG / sequencer of dz_osc2 overlaps them: never "fix" them.
- Effects that come from the widths, not from "gain" / "divider":
  (1) the divider is unsigned on a signed sine: for den > 1 the negative
  half folds (only den = 1 passes the sine unchanged); (2) the oscillator
  gain wraps (g = 2 = bits [14:7] with a fold: a brightness fold /
  multiplier); (3) the offset adders wrap; (4) the 24-bit adders add three
  packed 8-bit lanes as one number: carries cross from G into B and from B
  into R (colour bleed); (5) clock crossings with no synchronizer: HDMI_1's
  16-bit DDS buses (FCLK0) into pixel-clock dividers, HDMI_0's divider
  outputs (FCLK0) into the pixel-clock adder: a torn sample = single-pixel
  noise (invisible on fast oscillators, rare sparkle on slow patterns).
- dz_osc2 fits bit for bit: wave = two's complement sine like the
  compiler's, phase_out = phase[31:16] like xlslice_4, so (1)-(4) and all
  current settings look the same. New: CTRL[19] gives an offset-binary sine
  (the divider then scales it without the fold); the other shapes are
  unsigned. (5) stays while the oscillator runs on FCLK0 (plan step 5).

### GPIO consolidation: `dz_regs` (2026-10-29)

The four AXI GPIOs that serve as register banks cost (routed `fs`) 63 / 63
/ 63 / 160 LUT and 222 / 222 / 222 / 453 FF (~1119 FF for ~260 FF of real
registers: the rest is AXI glue), plus four crossbar ports. `hw/rtl/dz_regs/
dz_regs.v` is one subordinate over 0x4120_0000-0x4127_FFFF (512 KB) with
the old GPIO addresses and register offsets inside (bank = addr[18:16]: 0,
1, 3, 6; reset values as the IPs; bank 0 ch1 = the input with 2-FF sync
and the change interrupt, GIER / toggle-on-write ISR / IER, to GIC 66; free
banks read 0 instead of a bus error), so software and the address contract
stay. New: byte / halfword writes (WSTRB) - nearly every field is byte- or
halfword-aligned, so one 8/16-bit store changes one field. Test: `sh
hw/sim/run_dz_regs_tb.sh` (ALL PASS). BD: `hw/bd_edits/2026-10-29_dz_regs.tcl`
(records every slice the GPIOs drove, replaces the GPIOs, new hierarchy
pins regs_main_ch1/2 (HDMI_0), regs_osc_ch1/2 and regs_fb_ch1/2 (HDMI_1),
ps7_axi_periph 13 -> 10 master ports; addresses unchanged). Software:
sw/lib/dz_hw.h maps the old HW_*_AXI_GPIO_* names onto HW_DZ_REGS_0_BASE
+ bank x 64K. Built and tested ON ITS OWN, before dz_osc2 goes into the BD.

Result (2026-10-29, build `regs3` = artifacts/..._20261029_regs3, ON THE
BOARD): three builds were necessary to get the timing back to the level of
`edid2`:

- `regs` (first): FCLK0 -1.6 ns, PS7 MAXIGP0 WDATA -> registers with no
  logic level: `S00_HAS_REGSLICE {4}` on ps7_axi_periph fixed it (+0.008).
  This build also decoded address bits [1:0], so CPU byte stores to +1..+3
  were ignored (found on the board): now the word address is decoded and
  WSTRB selects the bytes (testbench covers unaligned stores).
- `regs2`: FCLK0 -0.29 ns (71 endpoints) in the mixer AXI register file
  (axi_awaddr -> 63 x 32 clock enables, 9 ns of routing): mixer coreRevision
  23 registers the write (enable, word index, data, strobes; max_fanout 16)
  one clock after the handshake. Then dz_regs' read mux on ARADDR failed
  (-0.27 ns): the read address is now latched at accept, data one clock later.
- The bank 0 input crossings (HDMI_2 status, fid on FCLK2) need a false path
  to `dz_regs_0/inst/in_s1_reg[*]` (XDC; the AXI GPIO did not show them).

`regs3`: FCLK0 +0.396, FCLK2 +0.123, FCLK3 +0.228, no failing crossings;
pixel -3.388 (52 endpoints, the HDMI_0 matrix cone as in edid2); LUT 12648,
FF 19673, slices 98.75 %. Board tests (two boards): reset values, word /
byte / halfword writes at +0..+3, free banks read 0, the status inputs
follow hot-plug and lock, ISR set by a change; HDMI_0 goes black with
0x4121_0000 = 0 and loses only red with a byte store of 0 to 0x4121_0002
(seen on the monitor). Capture 1600x1200@30 and 1080p30 work (user, video
wall via dzweb).

Fit: slices are at 99.6 % with LUTs at 72.6 % (partly filled slices), so
Vivado can usually pack ~1000 more LUT, but placement and timing get
harder; FCLK0 logic is not region-locked (unlike the pixel clock in X1Y1).
If it does not fit: 8 steps instead of 16, or the per-channel options
(line/frame step) as build parameters.


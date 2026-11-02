# artifacts/ - bitstreams and hardware descriptions in use

Hardware-tested builds only. New builds land in `build/<variant>/`
(git-ignored); copy a build here after a hardware test, with one row below.

`.bit` = JTAG. `.bit.bin` = fpga_manager: `sw/tools/plreload.sh` (or copy it to
`/lib/firmware/` and `echo <name> | sudo tee /sys/class/fpga_manager/fpga0/firmware`).
`.xsa` = the hardware description for PetaLinux. All builds since `_plio`
(2026-10-27) have the SAME PS7 setup (`ps7_init.c` identical, checked for
`_pwm` and `_sdly` 2026-11-01): a new XSA changes only the bitstream in
BOOT.BIN, not the FSBL or the device tree.

Where the builds are used (2026-11-02):

- **Bench board debaz-7130d5:** Oct 28 image (BOOT.BIN = `_pwm`), then
  `dzstart.sh` loads `_sdly` (`/home/ebaz/dzstart.conf` BITSTREAM). On
  2026-11-02 `_smix` and then `_gpclk` were loaded by hand (plreload.sh): a
  reboot goes back to `_sdly`.
- **Next image (to test) `debazaros-20261102-dsp.wic.xz`** (sandbox build on
  the build machine 2026-11-02, `~/dz-sandbox/`, not yet on a card):
  BOOT.BIN = `_dsp` (md5 checked), `/lib/firmware` = `_dsp` + `_sdly` +
  `_osc_epo`, the software of branch dsp-pipe (d4d9e9c4), no PL load at
  boot (dzstart.conf BITSTREAM empty), ps7_init.c identical to the Oct 28
  image. ⚠️ `_sdly` / `_osc_epo` from /lib/firmware still work with this
  hdmi2 (older bitstreams ignore the CLK_O1 write).
- Previous sandbox image `debazaros-20261101-sw.wic.xz` (PetaLinux recipe
  `debaz-sw`, sandbox build on the build machine 2026-11-01, not yet on a
  card): BOOT.BIN = `_sdly`, `/lib/firmware` = `_sdly` + `_osc_epo`; no PL
  load at boot. If `_sdly` shows timing trouble: BITSTREAM=`_osc_epo` in
  `/home/ebaz/dzstart.conf` (dzstart loads it at boot).

| File | What it is |
| --- | --- |
| `ebaz4205_2out1in_20261102_dsp.bit` / `.bit.bin` / `.xsa` (+ `.timing.rpt`, `.util.rpt`) | **On the bench board 2026-11-02, the newest (loaded by plreload.sh; dzstart.conf still _sdly)** (branch dsp-pipe; build dsp_AltSpreadLogic_high, `DZ_PLACE_DIRECTIVE=AltSpreadLogic_high DZ_ROUTE_DIRECTIVE=AggressiveExplore`). _smix + _gpclk merged + mixer coreRevision 26: mode 1 systolic in DSP48 registers (timed), the colour matrix inside the mixer (MATRIX_INT = 1, DSP48 registers; HDMI_0 sync delay 4). **ALL TIMING MET**: pixel +0.399 at 108 MHz, FCLK2 +0.145, FCLK0 +0.368, hold +0.023. NEEDS hdmi2 with the CLK_O1 write (sw since 2026-11-02). TESTED: all 9 output modes, capture through the switches, mode 1 DIFF, signed hue (by eye). Util: LUT 14115, FF 20512, DSP 73, slices 100 %. |
| `ebaz4205_2out1in_20261102_smix.bit` / `.bit.bin` / `.xsa` (+ `.timing.rpt`, `.util.rpt`) | **Tested on the bench board 2026-11-02** (branch signed-mixer; build smix4, `DZ_PLACE_DIRECTIVE=ExtraTimingOpt DZ_ROUTE_DIRECTIVE=AggressiveExplore`). _sdly + mixer coreRevision 25: signed gains (mode 1 operand bits DIFF / CENTRE / DSIGN, mode 5 signed constant), GAIN [31:24] not stored (reads 0). Same address map and hw_map.h as _sdly. NEEDS the software of branch signed-mixer for `/fx/signed`, `/mixer/<c>/g/<n>` (older software works, without those). TESTED: boot setup, `/fx/signed 1` + hue 60 by eye, GAIN / CTRL readback. Timing: FCLK0 +0.163, **FCLK2 -0.111 (1 endpoint, capture S2MM datamover)**, pixel -8.067 at 108 MHz (452: mode 1, which was then NOT false-pathed by mistake, and the colour matrix -> pix_r -5.5; 720p60 ok without mode 1). Util: LUT 13918, FF 20629, slices 4400 (100 %). |
| `ebaz4205_2out1in_20261102_gpclk.bit` / `.bit.bin` / `.xsa` (+ `.timing.rpt`, `.util.rpt`) | **On the bench board 2026-11-02 (loaded by plreload.sh, not in dzstart.conf)** (branch global-pclk; build gpclkt, `DZ_PLACE_DIRECTIVE=ExtraTimingOpt DZ_ROUTE_DIRECTIVE=AggressiveExplore`). _sdly + the global pixel clock: axi_dynclk revision 3 (MMCM CLKOUT1 on a BUFG = PXL_CLK_O, CLK_O1 register +0x24; BUFIO/BUFR only for the OSERDES), hdmi_tx_cdc.v FIFO, mixer GAIN [31:24] not stored (revision 24). **NEEDS hdmi2 with the CLK_O1 write** (sw/hdmi2 dynclk.c 2026-11-02, both branches): another hdmi2 breaks every mode with another serial divider. TESTED: all 9 output modes 640x480 .. 1080p60, displays good, capture, HDMI_2 audio in, ALSA capture, HDMI_0 audio out by ear. Timing: FCLK0 +0.101, **FCLK2 -0.080 (1 endpoint)**, pixel -2.758 at 108 MHz (29 endpoints: colour matrix -> pix_r, 5 mixer dout_r), FIFO crossing +5.9, serial +0.185. Util: LUT 13797, FF 20330, slices 4400 (100 %). |
| `ebaz4205_2out1in_20261101_sdly.bit` / `.bit.bin` / `.xsa` (+ `.timing.rpt`, `.util.rpt`) | **The default since 2026-11-01** (dzstart.conf) (dzstart.conf BITSTREAM; branch hdmi-audio). The _osc_epo design + hdmi_tx DE/sync delay ctrl[14:12] (`/hdmi/<n>/sync_delay`, reset 0 = old behaviour): HDMI_1's picture sat right of DE (bar at the left edge with a crop at x ~700). TESTED by eye on the board: HDMI_1 correct at **5**, HDMI_0 shows no change at any value (left at 0); plreload.sh sets 0 / 5. Same address map and hw_map.h as _osc. Built with `DZ_PLACE_DIRECTIVE=ExtraPostPlacementOpt DZ_ROUTE_DIRECTIVE=AggressiveExplore`: FCLK0 +0.181, **FCLK2 +0.102** (osc_epo +0.268), pixel -4.007 at the 108 MHz constraint (46 endpoints; worst = the HDMI_0 colour-matrix multadd -> mixer pix_r, 13.2 ns: 720p60 passes by ~0.2 ns, osc_epo 12.7 ns). Util: LUT 13761, FF 20592, slices 4400 (100 %). **If timing trouble appears (sparkle in the colour-matrix layer of HDMI_0, capture errors), go back to _osc_epo** (same software; sync_delay is then ignored). |
| `ebaz4205_2out1in_20261029_osc_epo.bit` / `.bit.bin` / `.xsa` (+ `.timing.rpt`, `.util.rpt`) | **Was on the bench board 2026-10-29 to 2026-11-01** (fallback if _sdly shows timing trouble) (branch hdmi-audio). The same design as _osc, implemented with `DZ_PLACE_DIRECTIVE=ExtraPostPlacementOpt DZ_ROUTE_DIRECTIVE=AggressiveExplore` (built on the PetaLinux build machine): **FCLK0 +0.191, FCLK2 +0.268, FCLK3 +0.619, no failing crossings**; pixel -3.485 at the 108 MHz constraint (30 endpoints). Util as _osc (slices 100 %). Same hw_map.h as _osc. |
| `ebaz4205_2out1in_20261029_osc.bit` / `.bit.bin` / `.xsa` (+ `.timing.rpt`, `.util.rpt`) | **Bench-tested 2026-10-29** (replaced on the board by _osc_epo: FCLK2 failed here; branch hdmi-audio). regs3 + the DDS engine dz_osc2 in place of both DDS compilers and dds_axi_interface_0/1: 0x43D0_0000 32 KB, channel 1 at +0x4000 (0x44D0_0000 gone; ROADMAP.md section 14). NEEDS the software with sw/include/hw_map.h of this build. Tested: old DDS fields, bars + checkerboard on HDMI_1. Timing (default directives): FCLK0 +0.054, **FCLK2 -0.017 (1 endpoint, capture S2MM datamover)**, FCLK3 +0.067, pixel -3.389 (31). Util: LUT 13758, FF 20530, slices 4400 (100 %), BRAM 45.5/60, DSP 73. Timing-closure runs pending. |
| `ebaz4205_2out1in_20261029_regs3.bit` / `.bit.bin` / `.xsa` (+ `.timing.rpt`, `.util.rpt`) | **Tested 2026-10-29** (on the bench board until osc; branch hdmi-audio). edid2 + GPIO consolidation: the four AXI GPIOs -> one `dz_regs` block at 0x4120_0000-0x4127_FFFF, same addresses / offsets / reset values, + byte and halfword writes (ROADMAP.md section 14); ps7_axi_periph 13 -> 10 ports + S00 register slice; mixer coreRevision 23 (registered AXI write). Timing: FCLK0 +0.396, FCLK2 +0.123, FCLK3 +0.228, no failing crossings; pixel -3.388 at the 108 MHz constraint (52 endpoints). Util: LUT 12648, FF 19673, slices 4345 (98.75 %). TESTED on two boards: register tests, HDMI_0 kill + byte lane on the monitor, capture 1600x1200@30 + 1080p30 (video wall). |
| `ebaz4205_2out1in_20261028_edid2.bit` / `.bit.bin` / `.xsa` (+ `.timing.rpt`, `.util.rpt`) | **Tested 2026-10-28** (on the bench board until regs3; branch hdmi-audio). The _fs build with a new capture EDID only (dvi2rgb rev 15): extension DTDs 1280x1024@60, 1600x1200@30 CVT reduced blanking (64.25 MHz), 1600x1200@25 (67.5 MHz), 1280x960@60. TESTED: 1600x1200@30 from the laptop decodes clean (1600x1200, 0 short lines), 800x600 quarters on both outputs. Timing as _fs: FCLK2 +0.047, pixel -3.240 at the 108 MHz constraint (25 endpoints). |
| `ebaz4205_2out1in_20261028_fs.bit` / `.bit.bin` / `.xsa` (+ reports, `checkpoints/..._fs_routed.dcp`) | On the bench board 2026-10-28, tested (branch hdmi-audio). The _edid build + display VDMAs frame-synced to the VTC vsync (fsync_gen, c_use_mm2s_fsync = 1) + the display interconnect data FIFOs back (packet mode + register slice) + pixel clock timed for 108 MHz instead of 148.5 (1080p60 still selectable, untimed). TESTED: moving crops at 60 changes/s on both displays (slot and live input) -> 0 lock losses, 0 underflows, smooth; 5 hdmi2 restarts recover; 640x480 quarters of a 1280x960 input. Util: LUT 12791, FF 20032, slices 4374 (99.4 %), BRAM 58/60, DSP 73. Timing: FCLK2 +0.270, FCLK0 +0.54, serial clock (540 MHz) met; pixel worst 12.77 ns (720p60 passes by 0.7 ns; the 108 MHz modes do not close: 49 endpoints). |

`checkpoints/`: routed design checkpoints (`.dcp`) of `_edid`, `_fs`,
`_p148`, `_rx2`, for timing analysis without a rebuild.

## Removed builds (commit 725f9751, 2026-10-29)

Their files are in git history: `git show 725f9751^:artifacts/<file> > <file>`.
Details of each build: this README in that commit, and CLAUDE.md.

| Build | Notes |
| --- | --- |
| `ebaz4205_2out1in_20261028_rx2` | hdmi_rx finds data islands by their guard band (1080p30 laptop input exact); pixel clock constrained for 148.5 MHz |
| `ebaz4205_2out1in_20261028_p148` | 1080p60 timing work: event bits for vid_out lock / underflow, hdmi_rx input size (RX_SIZE) |
| `ebaz4205_2out1in_20261027_pwm` | J3 hardware PWM; **the bitstream in BOOT.BIN of the Oct 28 image** (its XSA is the image's hardware description) |
| `ebaz4205_2out1in_20261027_ev` / `_fan` / `_pcm` / `_hpd` / `_tx0` / `_plio` | event block, fan connector I/O, Linux PCM FIFOs, HDMI_2 hot-plug, hdmi_tx on HDMI_0, user I/O function select (first build with the EMIO PS7) |
| `ebaz4205_2out1in_20261026_audio` / `_key` | HDMI audio TX/RX; colour key (mixer coreRevision 22) |
| `ebaz4205_2out1in_20261025` | first Tcl build |
| `debaz4205_wrapper_20261019_dvi2ms` | last bitstream of the legacy GUI project (hot-plug fix) |
| `debaz4205_wrapper_20250916` | BOOT.BIN of the Jan 2025 image (old cards) |

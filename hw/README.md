# hw/ - gateware as Tcl

`hw/bd/<variant>.tcl` is the source of truth for each block design.
Vivado projects are generated from it into `build/<variant>/` (git-ignored).
The legacy hand-made `Vivado/` project was removed on 2026-10-25 (branch
`legacy-vivado-project`).

All commands: Vivado 2022.2, run from the repo root.

## Build

```sh
# Create the project only (fast, about 1 min). Open it in the GUI if you want.
vivado -mode batch -source hw/build.tcl -tclargs ebaz4205_2out1in project

# Full build: synth + impl + bitstream (about 15-25 min).
vivado -mode batch -source hw/build.tcl -tclargs ebaz4205_2out1in build

# Same, into build/<dir>/ (use it while the GUI has build/<variant>/ open:
# every run deletes its output folder).
vivado -mode batch -source hw/build.tcl -tclargs ebaz4205_2out1in build <dir>
```

Output in `build/<variant>/`:

| File | Use |
| --- | --- |
| `<variant>.xpr` | Normal Vivado project. Open it in the GUI. |
| `<variant>_<date>.bit` | JTAG flash |
| `<variant>_<date>.bit.bin` | fpga_manager (`/lib/firmware`) |
| `<variant>_<date>.xsa` | PetaLinux / Vitis hardware description |
| `hw_map.h` | PS address map for C code and scripts |
| `<variant>_<date>.timing.rpt`, `.util.rpt` | Reports |

Each run deletes and recreates `build/<variant>/`. Copy the outputs that
you want to keep.

`hw_map.h` comes from the `project` phase (no synthesis necessary). To make
it again from the GUI, with the BD open, in the Tcl console:

```tcl
source <repo>/hw/hw_map.tcl
write_hw_map <repo>/build/<variant>/hw_map.h <variant>
```

## Edit a block design

1. Run the `project` phase, then open `build/<variant>/<variant>.xpr`.
2. Edit the BD in the GUI. Save it.
3. Write the BD back to its Tcl source. Do ONE of these:
   - GUI Tcl console:
     `write_bd_tcl -force -include_layout <repo>/hw/bd/<variant>.tcl`
   - Shell: `vivado -mode batch -source hw/export_bd.tcl -tclargs <variant>`
4. Review `git diff hw/bd/<variant>.tcl`, then commit.

If you skip step 3, the next `build.tcl` run deletes your edits.

## New variant

Copy `hw/bd/ebaz4205_2out1in.tcl` to `hw/bd/<new>.tcl`, build its project,
edit it in the GUI, and export it with `-tclargs <new>`.

## Inputs

- IP repos: `ip_repo/if` (Digilent TMDS interface definition, MIT),
  `ip_repo/mixer_1_0`, `IP_axi_dynclk`, `IP_dvi2rgb`, `IP_rgb2dvi`.
- RTL for BD module references: `hw/rtl/`: `hdmi_tx/` (HDMI/DVI
  transmitter with audio, both outputs; `hdmi_rx.v` for the input;
  `hdmi_audio_regs.v` = the register block at 0x43C6_0000 with PCM FIFOs,
  events, PWM), `dz_osc/` (DDS pattern engine dz_osc2), `dz_regs/` (the
  register banks at 0x4120_0000), `pl_io/` (user I/O function select, I2S),
  `fsync_gen.v` (VDMA frame sync), `DivideBy2N.v`, `div16_8_recip.v`. The two
  `dds_axi_inter*` files are only for BD sources from before dz_osc2.
- XDC: `hw/xdc/ebaz4205.xdc`.

`DivideBy2N.v`, `div16_8_recip.v` and the XDC came from the legacy
`Vivado/` project (2026-10-25); the rest is new. The dvi2rgb changes against Digilent's
original are recorded in `hw/patches/`.

## Packaged IP edits

To change RTL inside a packaged IP (for example `IP_dvi2rgb/src/*.vhd`),
edit the file in the IP folder, NOT a copy in `*.gen/.../ipshared/`.
Then re-package the IP (new checksums, `coreRevision` + 1) and run
`build.tcl` again:

```sh
vivado -mode batch -source hw/repackage_ip.tcl -tclargs IP_dvi2rgb
vivado -mode batch -source hw/build.tcl -tclargs ebaz4205_2out1in build
```
 The BD Tcl names each IP by version only (for example
`dvi2rgb:2.0`), so a new build uses the new revision. You need an
`upgrade_ip` only in a project that is already open.

## Simulation

`sh hw/sim/run_mixer_tb.sh` (Verilator 5): the mixer IP against the mixer of
commit 4e2d1820 (equivalence on random registers and pixels), then the colour
key. Expect "ALL PASS". Run it after every mixer RTL edit.

`sh hw/sim/run_hdmi_tx_tb.sh`: `hw/rtl/hdmi_tx` (rgb2dvi replacement with
HDMI audio) in DVI, HDMI, HDMI + audio and test-tone modes, the sync delay
(`ctrl[14:12]`), the register block and the receiver loop, checked by a
receiver-side TMDS decoder. Expect 10 x "ALL PASS".

Also: `run_dz_osc_tb.sh` (DDS engine), `run_dz_regs_tb.sh` (register
banks), `run_pl_io_tb.sh` (user I/O, I2S, PCM FIFOs).

## Timing

`build.tcl` runs placement ExtraPostPlacementOpt and routing
AggressiveExplore plus post-route phys_opt by default (slices are at 100 %
since dz_osc2). Always check FCLK2 in the timing report (the capture VDMA
datamover has about 0.1 ns). The pixel clock is constrained for 108 MHz and
fails there (the colour-matrix multiply-add path); what counts is the worst
path against the mode in use (720p60: 13.47 ns). CLAUDE.md has the details.

## IP with changed ports

After an RTL edit that adds or changes ports of a packaged IP:
`vivado -mode batch -source hw/repackage_ip.tcl -tclargs <ipdir> ports <top>`
(e.g. `ip_repo/mixer_1_0 ports mixer_v1_0`), then connect the new pins in
`hw/bd/<variant>.tcl`.


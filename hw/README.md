# hw/ - gateware as Tcl

`hw/bd/<variant>.tcl` is the source of truth for each block design.
Vivado projects are generated from it into `build/<variant>/` (git-ignored).
Do not edit the legacy `Vivado/` project for new work.

All commands: Vivado 2022.2, run from the repo root.

## Build

```sh
# Create the project only (fast, about 1 min). Open it in the GUI if you want.
vivado -mode batch -source hw/build.tcl -tclargs ebaz4205_2out1in project

# Full build: synth + impl + bitstream (about 15-25 min).
vivado -mode batch -source hw/build.tcl -tclargs ebaz4205_2out1in build
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
- RTL for BD module references: `DivideBy2N.v`, `div16_8_recip.v`,
  `dds_axi_inteface.vhd`, `dds_axi_interface_logic.vhd` (now in
  `Vivado/Vivado.srcs/sources_1/new/`). No other RTL in that folder is used.
- XDC: `Vivado/Vivado.srcs/constrs_1/imports/new/ebaz4205.xdc`.

## Packaged IP edits

To change RTL inside a packaged IP (for example `IP_dvi2rgb/src/*.vhd`),
edit the file in the IP folder, NOT a copy in `*.gen/.../ipshared/`.
Then re-package the IP (new checksums, `coreRevision` + 1) and run
`build.tcl` again. The BD Tcl names each IP by version only (for example
`dvi2rgb:2.0`), so a new build uses the new revision. You need an
`upgrade_ip` only in a project that is already open.

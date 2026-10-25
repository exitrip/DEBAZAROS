# artifacts/ - bitstreams and hardware descriptions in use

| File | What it is |
| --- | --- |
| `ebaz4205_2out1in_20261025.bit` / `.bit.bin` / `.xsa` | First build from the Tcl flow (`hw/build.tcl ebaz4205_2out1in build`). Tested on hardware 2026-10-25: both outputs, capture, all 117 register fields, GPIO, ethernet. The `.xsa` is the next PetaLinux hardware description (its FSBL sets FCLK3 = 200 MHz). |
| `debaz4205_wrapper_20261019_dvi2ms.bit` / `.bit.bin` | Last bitstream from the legacy GUI project (hot-plug fix). Same design as the Tcl build, except the K17/E19 GPIO bits ([7:6] here, [5:4] in the Tcl build). |
| `debaz4205_wrapper_20250916.bit` / `.bit.bin` | The bitstream in the deployed BOOT.BIN and in `/lib/firmware` on the board (fallback; brings up ethernet). |

`.bit` = JTAG. `.bit.bin` = fpga_manager: copy it to `/lib/firmware/` on the
board, then `echo <name> | sudo tee /sys/class/fpga_manager/fpga0/firmware`.
New builds land in `build/<variant>/` (git-ignored); copy a build here only
after a hardware test.

#!/bin/sh
# run_dz_osc_tb.sh - simulate hw/rtl/dz_osc (dz_osc2 + dz_osc_ch + sine ROM)
# with Verilator 5. Expect "dz_osc: ALL PASS".
#   sh hw/sim/run_dz_osc_tb.sh        (from the repo root)
set -e
OUT=build/sim_dz_osc
mkdir -p $OUT
verilator --binary --timing -Wno-fatal -Wno-lint -Wno-style \
	--top-module tb --Mdir $OUT -o tbsim \
	hw/sim/dz_osc_tb.sv hw/rtl/dz_osc/dz_osc2.v hw/rtl/dz_osc/dz_osc_ch.v \
	hw/rtl/dz_osc/dz_sine_rom.v > $OUT/verilator.log 2>&1 ||
	{ tail -30 $OUT/verilator.log; exit 1; }
$OUT/tbsim | grep -v '^- '

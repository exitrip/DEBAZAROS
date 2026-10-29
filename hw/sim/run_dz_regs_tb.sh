#!/bin/sh
# run_dz_regs_tb.sh - simulate hw/rtl/dz_regs/dz_regs.v (the register block
# in place of the four AXI GPIOs) with Verilator 5. Expect "dz_regs: ALL PASS".
#   sh hw/sim/run_dz_regs_tb.sh        (from the repo root)
set -e
OUT=build/sim_dz_regs
mkdir -p $OUT
verilator --binary --timing -Wno-fatal -Wno-lint -Wno-style \
	--top-module tb --Mdir $OUT -o tbsim \
	hw/sim/dz_regs_tb.sv hw/rtl/dz_regs/dz_regs.v > $OUT/verilator.log 2>&1 ||
	{ tail -30 $OUT/verilator.log; exit 1; }
$OUT/tbsim | grep -v '^- '

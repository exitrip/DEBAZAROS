#!/bin/sh
# run_pl_io_tb.sh - simulate hw/rtl/pl_io (pin functions + I2S) with
# Verilator 5. Expect "ALL PASS".   sh hw/sim/run_pl_io_tb.sh  (repo root)
set -e
OUT=build/sim_pl_io
mkdir -p $OUT
verilator --binary --timing -Wno-fatal -Wno-lint -Wno-style -Wno-COMBDLY \
	--top-module tb --Mdir $OUT -o tbsim hw/sim/pl_io_tb.sv \
	hw/rtl/pl_io/pl_io_core.v hw/rtl/pl_io/dz_i2s.v hw/rtl/pl_io/dz_async_fifo.v \
	> $OUT/verilator.log 2>&1 || { tail -30 $OUT/verilator.log; exit 1; }
$OUT/tbsim | grep -v '^- '

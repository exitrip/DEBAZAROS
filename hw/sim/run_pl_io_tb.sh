#!/bin/sh
# run_pl_io_tb.sh - simulate hw/rtl/pl_io with Verilator 5: pin functions +
# I2S (pl_io_tb), then the Linux PCM path with hdmi_audio_regs (pcm_tb).
# Expect "ALL PASS" twice.   sh hw/sim/run_pl_io_tb.sh  (repo root)
set -e
RTL="hw/rtl/pl_io/pl_io_core.v hw/rtl/pl_io/dz_i2s.v hw/rtl/pl_io/dz_async_fifo.v hw/rtl/pl_io/dz_bram_fifo.v"
for tb in pl_io_tb pcm_tb; do
	OUT=build/sim_$tb
	mkdir -p $OUT
	verilator --binary --timing -Wno-fatal -Wno-lint -Wno-style -Wno-COMBDLY \
		--top-module tb --Mdir $OUT -o tbsim hw/sim/$tb.sv $RTL hw/rtl/hdmi_tx/hdmi_audio_regs.v \
		> $OUT/verilator.log 2>&1 || { tail -30 $OUT/verilator.log; exit 1; }
	echo "== $tb"
	$OUT/tbsim | grep -v '^- '
done

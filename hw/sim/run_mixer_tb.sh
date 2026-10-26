#!/bin/sh
# run_mixer_tb.sh - simulate the mixer IP with Verilator 5 (expect "ALL PASS").
# The reference mixer for the equivalence test is the RTL of commit REF (the
# last mixer before the colour key), renamed to mixer_ref_*.
#   sh hw/sim/run_mixer_tb.sh        (from the repo root)
set -e
REF=${REF:-4e2d1820}
OUT=build/sim
mkdir -p $OUT/ref
for f in mixer_v1_0.v mixer_v1_0_S00_AXI.v; do
	git show $REF:ip_repo/mixer_1_0/hdl/$f | sed 's/mixer_v1_0/mixer_ref_v1_0/g' > $OUT/ref/$f
done
verilator --binary --timing -Wno-fatal -Wno-lint -Wno-style -Wno-COMBDLY \
	--top-module tb --Mdir $OUT -o tbsim \
	hw/sim/mixer_key_tb.sv ip_repo/mixer_1_0/hdl/mixer_v1_0.v \
	ip_repo/mixer_1_0/hdl/mixer_v1_0_S00_AXI.v $OUT/ref/*.v > $OUT/verilator.log 2>&1 ||
	{ tail -20 $OUT/verilator.log; exit 1; }
$OUT/tbsim

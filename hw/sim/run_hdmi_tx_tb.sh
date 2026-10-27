#!/bin/sh
# run_hdmi_tx_tb.sh - simulate hw/rtl/hdmi_tx with Verilator 5 in all four
# modes (DVI, HDMI, HDMI + audio, HDMI + test tone), then the AXI-Lite
# register block, then the receiver loop (2 modes). Expect 7 x "ALL PASS".
#   sh hw/sim/run_hdmi_tx_tb.sh        (from the repo root)
set -e
OUT=build/sim_hdmi_tx
mkdir -p $OUT
verilator --binary --timing -Wno-fatal -Wno-lint -Wno-style -Wno-COMBDLY \
	--top-module tb --Mdir $OUT -o tbsim \
	hw/sim/hdmi_tx_tb.sv hw/rtl/hdmi_tx/hdmi_tx*.v \
	hw/sim/ref_hdl_util/auxiliary_video_information_info_frame.sv \
	hw/sim/ref_hdl_util/audio_info_frame.sv > $OUT/verilator.log 2>&1 ||
	{ tail -30 $OUT/verilator.log; exit 1; }
rc=0
for m in 0 1 2 3; do
	$OUT/tbsim +mode=$m | grep -v '^- ' || rc=1
done
verilator --binary --timing -Wno-fatal -Wno-lint -Wno-style --top-module tb \
	--Mdir $OUT/regs -o tbsim hw/sim/hdmi_audio_regs_tb.sv \
	hw/rtl/hdmi_tx/hdmi_audio_regs.v > $OUT/regs.log 2>&1 || { tail -20 $OUT/regs.log; exit 1; }
echo "registers:"; $OUT/regs/tbsim | grep -v '^- ' || rc=1
# receiver: hdmi_tx -> dvi2rgb decoder model -> hdmi_rx (DVI, HDMI + audio)
verilator --binary --timing -Wno-fatal -Wno-lint -Wno-style -Wno-COMBDLY --top-module tb \
	--Mdir $OUT/rx -o tbsim hw/sim/hdmi_rx_tb.sv hw/rtl/hdmi_tx/hdmi_tx.v \
	hw/rtl/hdmi_tx/hdmi_tx_encoder.v hw/rtl/hdmi_tx/hdmi_tx_packets.v \
	hw/rtl/hdmi_tx/hdmi_tx_rom.v hw/rtl/hdmi_tx/hdmi_tx_serdes.v \
	hw/rtl/hdmi_tx/hdmi_rx.v > $OUT/rx.log 2>&1 || { tail -20 $OUT/rx.log; exit 1; }
for m in 0 1; do
	$OUT/rx/tbsim +mode=$m | grep -v '^- ' || rc=1
done
exit $rc

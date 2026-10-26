#!/bin/sh
# plreload.sh <name.bit.bin> - load a bitstream with fpga_manager, then bring
# the displays, debazd and the boot mixer setup back. On the board, as root:
#   cp x.bit.bin /tmp/ && sudo setsid sh /home/ebaz/bin/plreload.sh x.bit.bin \
#       > /tmp/plreload.log 2>&1 &
# Run it detached: the ethernet PHY clock comes from the PL, so the link can
# drop during the load (it did not on 2026-10-26).
# Before: stop capture with a soft reset (devmem 0x43020030 32 0x00010004,
# wait for bit 2 to clear). NEVER load while capture writes frames.
set -x
BIN=$1
D=/home/ebaz/bin
[ -f /tmp/$BIN ] || { echo "no /tmp/$BIN"; exit 1; }
# hdmi2 and debazd access PL registers all the time: stop them for the load
kill $(pgrep debazd) $(pgrep -f hdmi2.elf) 2>/dev/null
sleep 1
mkdir -p /lib/firmware
cp /tmp/$BIN /lib/firmware/$BIN
echo 0 > /sys/class/fpga_manager/fpga0/flags
echo $BIN > /sys/class/fpga_manager/fpga0/firmware
cat /sys/class/fpga_manager/fpga0/state
sleep 1
setsid nohup $D/hdmi2.elf > /tmp/hdmi2.log 2>&1 &
sleep 4
setsid nohup $D/debazd -v > /tmp/debazd.log 2>&1 &
sleep 1
# boot mixer setup (debazarosit.sh values); without it HDMI_0 is black
for c in 1 2 3 4 6 8; do
	$D/dzctl /mixer/$c/mode 35; $D/dzctl /mixer/$c/k 65535
	$D/dzctl /mixer/$c/lo 32; $D/dzctl /mixer/$c/hi 237
done
for c in 0 5 7; do $D/dzctl /mixer/$c/mode 4; $D/dzctl /mixer/$c/k 32768; done
$D/dzctl /hdmi/0/gain/rgb 255
echo DONE

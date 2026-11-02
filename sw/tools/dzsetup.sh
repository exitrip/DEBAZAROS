#!/bin/sh
# dzsetup.sh - the boot setup of the PL registers (2026-11-01; was inline in
# plreload.sh): after a PL load or a power-up every register is at its reset
# value, and HDMI_0 stays BLACK until the mixer is set up (the colour matrix
# multiplies by 0). Run by plreload.sh and dzstart.sh; needs debazd.
#   sh dzsetup.sh
D=${DZ_BIN:-/home/ebaz/bin}; [ -x "$D/debazd" ] || D=/usr/bin	# dev copy, else the image (dz_path.h)
# mixer (debazarosit.sh values): chans 1 2 3 4 6 8 band-clip, 0 5 7 constant 0.5
for c in 1 2 3 4 6 8; do
	$D/dzctl /mixer/$c/mode 35; $D/dzctl /mixer/$c/k 65535
	$D/dzctl /mixer/$c/lo 32; $D/dzctl /mixer/$c/hi 237
done
for c in 0 5 7; do $D/dzctl /mixer/$c/mode 4; $D/dzctl /mixer/$c/k 32768; done
$D/dzctl /hdmi/0/gain/rgb 255
# DE/sync delay = the effects data latency (hdmi_tx ctrl[14:12], set by eye
# 2026-11-01; bitstreams before _sdly store and ignore it)
$D/dzctl /hdmi/0/sync_delay 0; $D/dzctl /hdmi/1/sync_delay 5

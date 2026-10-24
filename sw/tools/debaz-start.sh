#!/usr/bin/env bash
# debaz-start.sh - the debazarosit.sh boot sequence, through debazd.
#
# NOT INSTALLED (2026-10-19). debazit.service still runs debazarosit.sh.
# Same look as debazarosit.sh: every devmem write is translated to a named
# field (sw/lib/dz_fields.c), with the same values.
#
#   LOAD_PL=0 ./debaz-start.sh     after a JTAG flash (keep the dev bitstream)
#   ./debaz-start.sh               boot: load $BITSTREAM through fpga_manager
#   LOOP=0 ./debaz-start.sh        set up only, no animation loop
set -u
BIN=${BIN:-/home/ebaz/bin}
DZ="$BIN/dzctl -t 150"
BITSTREAM=${BITSTREAM:-debaz4205_wrapper_20250916.bit.bin}
MOVIE=${MOVIE:-/home/ebaz/test24-1280-8MBps.mp4}
LOAD_PL=${LOAD_PL:-1}
LOOP=${LOOP:-1}

dz() { $DZ "$@" >/dev/null; }			# set, ignore the reply
val() { $DZ "$1" | awk '/^\/value/ {print $3}'; }	# raw value of a field

if [ "$LOAD_PL" = 1 ]; then
	echo "$BITSTREAM" > /sys/class/fpga_manager/fpga0/firmware
fi

# FCLK3 -> 200 MHz for the dvi2rgb IDELAYCTRL (old FSBL programs 25 MHz).
# Remove when BOOT.BIN is rebuilt from the new XSA (ROADMAP task 4).
devmem 0xF8000008 32 0x0000DF0D		# SLCR unlock
devmem 0xF80001A0 32 0x00100800		# FPGA3_CLK_CTRL: DIV0=8, DIV1=1

# Daemon first (it only reads until told otherwise), then display bring-up.
# The sw/ hdmi2 build refuses frames outside reserved memory.
pgrep -x debazd >/dev/null || { "$BIN/debazd" > /tmp/debazd.log 2>&1 & }
"$BIN/hdmi2.elf" &
for _ in $(seq 50); do				# wait until display 0 runs (max 10 s)
	sleep 0.2
	slot=$($DZ /disp/0 | awk '/^\/disp/ {print $2}')
	[ -n "$slot" ] && [ "$slot" != "-1" ] && break
done

# mixer: chans 1 2 3 4 6 8 = clip-to-K band 0x20..0xed, K = 0xffff
for c in 1 2 3 4 6 8; do
	dz /mixer/$c/mode 0x23; dz /mixer/$c/k 0xffff
	dz /mixer/$c/lo 0x20;   dz /mixer/$c/hi 0xed; dz /mixer/$c/stream 0
done
# chans 0 5 7 = constant K = 0x8000
for c in 0 5 7; do dz /mixer/$c/mode 4; dz /mixer/$c/k 0x8000; done

dz /disp/0/home				# display 0 shows slot 0 = /dev/fb0
ffmpeg -nostdin -stream_loop -1 -re -i "$MOVIE" -pix_fmt bgra -f fbdev /dev/fb0 \
	-loglevel quiet &

dz /mixer/8/gain/3 0x01
dz /dds/0/pinc 0xa11			# approx. 60 Hz (bit 31 is set by the field)
dz /dds/1/pinc 2
dz /mixer/8/gain/1 0x40
dz /mixer/3/gain/3 0x03
dz /mixer/3/gain/0 0x20
dz /mixer/1/gain/0 0xff
dz /mixer/1/gain/1 0xff
dz /hdmi/1/osc/phase/offset 0x13	# was: devmem 0x41230008 0x00130000
dz /hdmi/1/osc/sin/offset 0

# debazarosit.sh writes whole words to 0x4126_0000; since Aug 2026 bits
# [31:24] there are the HDMI_1 saw (phase) divider, so the old loop holds it
# at 0 = output stuck at 0xFFFF. Keep that look; delete this line to let the
# saw layer move (den 1 = pass through).
dz /hdmi/1/osc/phase/div 0

[ "$LOOP" = 1 ] || exit 0

phase_toggle=0
while true; do
	for j in 2 5 1290; do
		dz /dds/1/pinc $j
		# feedback gain ramp. Old word: i*0x020000 + 0x010000 + i*0x0100 + i
		# -> R lane = (2i+1) & 0xff, B lane = i, G lane = i
		for i in $(seq 0 255); do
			dz /hdmi/1/feedback/rgb $(( (2*i+1) & 255 )) $i $i; sleep 0.1
		done
		for i in $(seq 255 -5 0); do
			dz /hdmi/1/feedback/rgb $i $i $i; sleep 0.1
		done
		# own-video gain ramp down and up (grey)
		for i in $(seq 255 -2 0); do
			dz /hdmi/1/gain/rgb $i $i $i; sleep 0.1
		done
		for i in $(seq 0 2 255); do
			dz /hdmi/1/gain/rgb $i $i $i; sleep 0.1
		done
		# DDS 0: ping-pong between approx. 60 Hz and approx. 45 kHz
		if [ "$(val /dds/0/pinc)" -gt 65535 ]; then
			dz /dds/0/pinc 0xa11
		else
			dz /dds/0/pinc $(( 0xa12 * 750 + 163 ))
		fi
	done
	# HDMI_1 oscillator offsets: ping-pong (old words 0x00130000 / 0x00204000)
	if [ $phase_toggle = 0 ]; then
		dz /hdmi/1/osc/phase/offset 0x20; dz /hdmi/1/osc/sin/offset 0x4000
		phase_toggle=1
	else
		dz /hdmi/1/osc/phase/offset 0x13; dz /hdmi/1/osc/sin/offset 0
		phase_toggle=0
	fi
done

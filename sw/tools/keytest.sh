#!/bin/sh
# keytest.sh [off] - visual test of the colour key (key bitstream 2026-10-26).
# Display 0: colour bars + a green rectangle; display 1: a movie in slot 6.
# Expected on display 0: the rectangle and the green bar show HDMI_1's
# picture; the other bars do not change. "off" = key off, boot mixer look.
D=/home/ebaz/bin
if [ "$1" = off ]; then
	$D/dzctl /fx/key/off
	$D/dzctl /fx/key/source 0
	exit 0
fi
$D/dzctl /fx/identity
$D/dzctl /draw/0/bars
$D/dzctl /draw/0/rect 0 255 0 320 180 640 360
$D/dzctl /disp/1/show 6
$D/dzctl /movie/6/play testsrc.mp4
$D/dzctl /fx/key/source 1
$D/dzctl /fx/key/color 0x00ff00 40

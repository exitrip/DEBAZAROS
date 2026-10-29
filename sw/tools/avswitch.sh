#!/bin/sh
# avswitch.sh - routing test (2026-10-28): a movie (video + audio) and the
# live HDMI_2 input (video + the source's audio) on the two outputs,
# swapped every few seconds; the audio follows the picture. On the board,
# as root, with debazd running and an HDMI source (with audio) on HDMI2:
#
#   sudo sh avswitch.sh [-p secs] [-n swaps] file.mkv     (file from mkmedia.sh)
#
# Video: the movie plays into slot 1 (display 0's back slot), the live
# input is slot 4; a swap = /disp/0/show and /disp/1/show (applied by debazd
# at the next vsync). Audio: pcmplay writes the movie into BOTH PCM FIFOs
# (-s 0,1 -n); each output plays its PCM FIFO when /pcm/to_hdmiN = 1, else
# the HDMI_2 loop (/audio/rx/loop). A swap flips both bits.
set -e
per=5 n=12
while getopts p:n: opt; do
	case $opt in
	p) per=$OPTARG ;;
	n) n=$OPTARG ;;
	*) sed -n '6,7p' "$0"; exit 2 ;;
	esac
done
shift $((OPTIND - 1))
f=$1
[ -f "$f" ] || f=/media/debaz/movies/$1
[ -f "$f" ] || { echo "no file $1"; exit 1; }
D=/home/ebaz/bin
Z="$D/dzctl -t 5"		# do not wait 400 ms for more replies
SLOT1=0x087E9000			# 0x0800_0000 + 1 x 8294400

for t in tx tx0; do
	$Z /audio/$t/hdmi 1; $Z /audio/$t/tone 0; $Z /audio/$t/enable 1
done > /dev/null
$Z /audio/rx/loop 1 > /dev/null
$Z /audio/rx/active
size=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height \
	-of csv=p=0:s=x "$f")
w=${size%x*} h=${size#*x}

# the movie, looped, in its own process group
setsid sh -c "{ ffmpeg -nostdin -hide_banner -loglevel error -stream_loop -1 -re -i '$f' \
	-map 0:v:0 -pix_fmt yuv420p -f rawvideo pipe:1 \
	-map 0:a:0 -f s16le -ar 48000 -ac 2 pipe:3 \
	3>&1 1>&4 | $D/pcmplay -n -s 0,1; } 4>&1 | \
	$D/fbfeed -y -a $SLOT1 -w $w -h $h -s 7680" > /tmp/avswitch.log 2>&1 &
mpid=$!
trap 'kill -INT -$mpid 2>/dev/null; $Z /pcm/to_hdmi0 0 > /dev/null; $Z /pcm/to_hdmi1 0 > /dev/null' EXIT INT TERM
sleep 2

i=0
while [ $i -lt "$n" ]; do
	if [ $((i % 2)) = 0 ]; then	# A: HDMI0 = movie, HDMI1 = live
		$Z /disp/0/show 1 > /dev/null; $Z /disp/1/show 4 > /dev/null
		$Z /pcm/to_hdmi0 1 > /dev/null; $Z /pcm/to_hdmi1 0 > /dev/null
		echo "$(date +%T) swap $i: HDMI0 = movie, HDMI1 = live"
	else				# B: HDMI0 = live, HDMI1 = movie
		$Z /disp/0/show 4 > /dev/null; $Z /disp/1/show 1 > /dev/null
		$Z /pcm/to_hdmi0 0 > /dev/null; $Z /pcm/to_hdmi1 1 > /dev/null
		echo "$(date +%T) swap $i: HDMI0 = live, HDMI1 = movie"
	fi
	i=$((i + 1))
	sleep "$per"
done
$Z /disp/0/home > /dev/null
$Z /disp/1/home > /dev/null

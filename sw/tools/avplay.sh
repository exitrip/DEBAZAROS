#!/bin/sh
# avplay.sh - play video AND audio of one file on the board (test, 2026-10-28;
# before debazd /movie and an ALSA driver do it). Run on the board as root.
#
#   sudo sh avplay.sh [-o 0|1] [-v] [-l] file.mkv | -k     (file from mkmovie.sh)
#
#   -o n   output: HDMI_n (PCB name = BD name; default 0 = J1 "HDMI0").
#          Video goes to the slot that display n shows at home (0 or 2),
#          audio into PCM FIFO n; the output is set to HDMI mode + audio.
#   -v     fbfeed prints fps
#   -l     loop the file
#   -k     stop every running avplay (SIGINT to its process group: pcmplay
#          prints its summary and clears its routing bit)
#
# One ffmpeg decodes both streams at the file rate (-re): video as yuv420p on
# stdout -> fbfeed -y, audio as S16LE 48 kHz on fd 3 -> pcmplay. The PCM FIFO
# drains at exactly 48 kHz; when a pipe is full, ffmpeg waits, so a slow
# video path also stalls the audio (underruns in the pcmplay summary).
# The movie size must be the display mode (mkmovie.sh -s).
set -e
out=0 v= loop=
while getopts o:vlk opt; do
	case $opt in
	o) out=$OPTARG ;;
	v) v=-v ;;
	l) loop="-stream_loop -1" ;;
	k)	# process group = field 5 of /proc/<pid>/stat (no pkill in BusyBox)
		for p in /proc/[0-9]*; do
			c=$(tr "\0" " " < "$p/cmdline" 2>/dev/null)
			case "$c" in *avplay.sh*) ;; *) continue ;; esac
			g=$(cut -d' ' -f5 "$p/stat")
			[ "$g" = "$(cut -d' ' -f5 /proc/$$/stat)" ] || kill -INT -"$g" 2>/dev/null
		done
		exit 0 ;;
	*) sed -n '5,13p' "$0"; exit 2 ;;
	esac
done
shift $((OPTIND - 1))
f=$1
[ -f "$f" ] || f=/home/ebaz/movies/$1
[ -f "$f" ] || { echo "no file $1"; exit 1; }
D=/home/ebaz/bin

# slot of the display at home: display 0 = slot 0 (/dev/fb0), display 1 = slot 2
if [ "$out" = 0 ]; then dst="-d /dev/fb0 -o 0"; tx=tx0; else dst="-a 0x08FD2000"; tx=tx; fi
$D/dzctl /disp/$out/home > /dev/null
$D/dzctl /audio/$tx/hdmi 1 > /dev/null
$D/dzctl /audio/$tx/tone 0 > /dev/null
$D/dzctl /audio/$tx/enable 1 > /dev/null

size=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height \
	-of csv=p=0:s=x "$f")
w=${size%x*} h=${size#*x}

# fd 4 = the pipe to fbfeed; inside, ffmpeg fd 1 -> fd 4 (video), fd 3 -> pcmplay
# shellcheck disable=SC2086
{ ffmpeg -nostdin -hide_banner -loglevel error $loop -re -i "$f" \
	-map 0:v:0 -pix_fmt yuv420p -f rawvideo pipe:1 \
	-map 0:a:0 -f s16le -ar 48000 -ac 2 pipe:3 \
	3>&1 1>&4 | $D/pcmplay -s "$out"; } 4>&1 | \
	$D/fbfeed -y $dst -w "$w" -h "$h" -s 7680 $v

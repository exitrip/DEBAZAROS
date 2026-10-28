#!/bin/sh
# mkmovie.sh - convert a video on the HOST into the board's playback format
# (2026-10-28). Run on the laptop / build machine, not on the board.
#
#   sh sw/tools/mkmovie.sh [options] input [output.mkv]
#
#   -s WxH    size (default 1280x720; the display mode the movie plays in)
#   -r fps    maximum frame rate (default 25: the board plays 720p at about 26
#             fps; at 30 the audio breaks up, measured 2026-10-28)
#   -q n      MPEG-4 quality, 2 (best) .. 31 (default 4)
#   -f        fill: scale up and crop to the size (default: fit, black bars)
#   -t secs   only the first secs seconds (tests)
#   -n        no audio
#   -u        upload to the board movie folder (scp to $DZ_BOARD:/home/ebaz/movies/)
#
# Format, chosen for the A9 (measurements in CLAUDE.md):
#   video  MPEG-4 Part 2, yuv420p, keyframe every second: decodes at about
#          36 fps at 720p (H.264 about 18); 1080p is not supported
#   audio  PCM S16LE, 2 channels, 48000 Hz = the format of the gateware PCM
#          FIFOs (pcmplay): no decode, no resample on the board
#   file   Matroska (.mkv); about 11 MB per minute of audio + the video
set -e

size=1280x720 fps=25 q=4 fill=0 dur= audio=1 upload=0
while getopts s:r:q:ft:nu opt; do
	case $opt in
	s) size=$OPTARG ;;
	r) fps=$OPTARG ;;
	q) q=$OPTARG ;;
	f) fill=1 ;;
	t) dur="-t $OPTARG" ;;
	n) audio=0 ;;
	u) upload=1 ;;
	*) sed -n '4,16p' "$0"; exit 2 ;;
	esac
done
shift $((OPTIND - 1))
[ $# -ge 1 ] || { sed -n '4,16p' "$0"; exit 2; }
in=$1
out=${2:-$(basename "${in%.*}")_${size#*x}p.mkv}
w=${size%x*} h=${size#*x}

if [ $fill = 1 ]; then
	vf="scale=$w:$h:force_original_aspect_ratio=increase,crop=$w:$h"
else
	vf="scale=$w:$h:force_original_aspect_ratio=decrease,pad=$w:$h:(ow-iw)/2:(oh-ih)/2"
fi
vf="$vf,setsar=1,format=yuv420p"

# keyframe interval = 1 s at the output rate
rate=$(ffprobe -v error -select_streams v:0 -show_entries stream=avg_frame_rate \
	-of csv=p=0 "$in")
g=$(awk -v r="$rate" -v m="$fps" 'BEGIN { split(r, a, "/"); f = a[2] ? a[1] / a[2] : m;
	if (f <= 0 || f > m) f = m; printf "%d", f + 0.5 }')

if [ $audio = 1 ] && [ -n "$(ffprobe -v error -select_streams a:0 \
	-show_entries stream=index -of csv=p=0 "$in")" ]; then
	a="-map 0:a:0 -c:a pcm_s16le -ar 48000 -ac 2"
else
	a="-an"
fi

# shellcheck disable=SC2086
ffmpeg -hide_banner -loglevel warning -stats -y -i "$in" $dur \
	-map 0:v:0 -vf "$vf" -fpsmax "$fps" -c:v mpeg4 -q:v "$q" -g "$g" \
	$a "$out"

ffprobe -v error -show_entries stream=codec_name,width,height,avg_frame_rate,sample_rate,channels \
	-show_entries format=duration,size -of compact=p=0 "$out"

if [ $upload = 1 ]; then
	board=${DZ_BOARD:-ebaz@10.42.0.128}
	scp "$out" "$board:/home/ebaz/movies/"
	echo "uploaded: $board:/home/ebaz/movies/$(basename "$out")"
fi

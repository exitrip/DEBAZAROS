#!/bin/bash
# mkmedia.sh - convert media on the HOST into the board's formats and folder
# layout (2026-10-28). Run on the laptop / build machine, not on the board.
#
#   bash sw/tools/mkmedia.sh [options] FILE|FOLDER|PATTERN ...
#
#   PATTERN   a glob, also in quotes: 'video*/test*.mov', 'shoot/**/*.mp4'
#             (** = any depth); case is ignored (*.mov finds TEST.MOV); a
#             folder that matches is searched as a folder; a file matched
#             twice is converted once
#   -o DIR    output root (default ./board-media): DIR/img, DIR/movies,
#             DIR/audio - the media folders on the board (-m)
#   -s WxH    display size (default 1280x720): movies are scaled to it,
#             images fitted into it (never enlarged)
#   -r fps    movie frame rate cap (default 25: the board plays 720p at about
#             26 fps; at 30 the audio breaks up, measured 2026-10-28)
#   -q n      MPEG-4 quality, 2 (best) .. 31 (default 4)
#   -f        movies: fill = scale up and crop (default: fit, black bars);
#             the same as -z fill
#   -z MODE   movies, the output size (2026-11-20; -s = the box):
#               fit     scale up or down to the edge of WxH, centred, black
#                       bars to WxH (default; smaller movies ARE enlarged)
#               fill    scale to cover WxH, crop the rest (= -f)
#               box     scale to the edge, NO bars: the file is the scaled
#                       size (less to decode; place it on the board with
#                       /movie/<s>/pos or a display crop)
#               native  never enlarge (only shrink to fit WxH), no bars
#             Non-square pixels (DVD-style 720x480 with SAR 109:120 etc.)
#             become square first in every mode: nothing is stretched.
#   -P DIR    movies: a portrait movie (taller than wide, as displayed, a
#             rotation tag counted) is turned 90 degrees, DIR = cw | ccw;
#             landscape movies are left alone
#   -a fmt    audio files: wav (default) or flac (lossless, about half size)
#   -n        movies: no audio at all
#   -t secs   only the first secs seconds of movies and audio (tests)
#   -F        convert again even when the output is newer than the input
#   -u [HOST] upload to the board HOST (user@ip), else $DZ_BOARD; no default:
#             each file goes to MEDIA/{img,movies,audio} as soon as it
#             is converted or found up to date (a background queue, one
#             file at a time, while the next file transcodes; rsync skips a
#             file the board already has); a final rsync of the whole tree
#             catches anything else (other files in the output folders).
#             Before each file the board's free space is checked: a file is
#             sent only if RESERVE stays free (else "no room", listed at the
#             end, and the final sync is left out)
#   -m MEDIA  media root on the board (default /media/debaz: the exFAT media
#             partition; older cards: /home/ebaz)
#   -R MB     space to keep free on the board (default 256)
#   -A NAME   image sequence mode (debazd anim.c, ROADMAP.md section 16): all
#             inputs become ONE sequence OUT/anim/NAME/f00001.jpg ... (the
#             arguments in their order, a folder in natural order of its
#             paths: f2 before f10): image files and
#             folders, and the frames of movie files (at -r fps when -r is
#             given, else every frame). Display size (-s), baseline JPEG
#             4:2:0 at -j quality; the folder is made new each run. -r also
#             writes timing.txt "# fps r". -u: rsync to MEDIA/anim/NAME on
#             the board (--delete: the board's folder = this sequence)
#   -j Q      JPEG quality 1-100 for -A (default 85; lower = smaller files =
#             faster playback: 720p ~150 KB plays ~20+ fps next to a movie)
#
# Audio level (2026-11-22; movies and audio files). The gain is set from the
# TRUE PEAK (EBU R128 dBTP), not from the loudness: a quiet film keeps its
# dynamics, it only comes up until its loudest moment reaches the floor.
# Files with a peak inside MIN..MAX are left as they are. No limiter, no
# compression: one fixed gain per file.
#   --audio-min-peak DB   raise a file whose true peak is below DB to DB
#                         (e.g. -6.0; a 1973 transfer at -26 dBTP gets +20 dB)
#   --audio-max-peak DB   lower a file whose true peak is above DB to DB
#                         (e.g. -1.0: headroom for files that clip)
#   --audio-max-gain DB   never raise by more than DB (default 30: the noise
#                         floor comes up with the signal)
#   --audio-only          re-render ONLY the audio of board movies (.mkv made
#                         by mkmedia): the video is copied, not encoded again.
#                         A file already in range is left alone. Output path
#                         as usual (OUT/movies/NAME.mkv): with -o board-media
#                         and inputs in board-media/movies the file is replaced
#                         in place (temp file + rename). Images are skipped.
#             Each file prints its true peak, loudness (LUFS) and the gain.
#   --analyze-audio       only MEASURE the inputs (movies and audio files, any
#                         format; nothing is written): one table row per file
#                         = length, format, loudness (LUFS), loudness range
#                         (LRA), true peak, mean and max level, and with
#                         --audio-min/max-peak the gain each file would get.
#                         Several files are measured at once (-j-style: half
#                         the cores); -t measures only the first secs.
#   Example: bash sw/tools/mkmedia.sh --audio-only --audio-min-peak -6 \
#                 board-media/movies/*sobell*.mkv
#
# Folders are searched recursively; the type comes from the extension.
# Formats, chosen for the A9 (measurements in CLAUDE.md / ROADMAP.md):
#   movies  MPEG-4 Part 2, yuv420p, keyframe every second, .mkv; audio PCM
#           S16LE 48 kHz stereo = the PCM FIFO format (no decode, no
#           resample on the board). The audio track is left out when the
#           source has none or it is silent (max level below -80 dB).
#   audio   48 kHz 16 bit stereo, WAV (or FLAC)
#   images  PNG
# File names change to A-Z a-z 0-9 . _ - (the board's rule).
set -u

out=./board-media size=1280x720 fps=25 q=4 fill=0 afmt=wav noaudio=0 dur= zmode=fit portrait=
force=0 upload=0 board=${DZ_BOARD:-} rroot=/media/debaz reserve_mb=256 anim= jq=85 fps_set=0
amin= amax= amaxgain=30 aonly=0 analyze=0
usage() { awk 'NR >= 5 && /^#/ { sub(/^# ?/, ""); print; next } NR >= 5 { exit }' "$0"; exit 2; }
# the long options first (getopts has none); the rest goes to getopts
isnum() { [[ $1 =~ ^[-+]?[0-9]+([.][0-9]+)?$ ]] || { echo "$2: a number in dB, not '$1'"; exit 2; }; }
declare -a rest=()
while [ $# -gt 0 ]; do
	case $1 in
	--audio-min-peak|--audio-max-peak|--audio-max-gain)
		[ $# -ge 2 ] || { echo "$1 needs a value"; exit 2; }
		isnum "$2" "$1"
		case $1 in
		--audio-min-peak) amin=$2 ;; --audio-max-peak) amax=$2 ;; *) amaxgain=$2 ;;
		esac
		shift 2 ;;
	--audio-min-peak=*) amin=${1#*=}; isnum "$amin" "${1%%=*}"; shift ;;
	--audio-max-peak=*) amax=${1#*=}; isnum "$amax" "${1%%=*}"; shift ;;
	--audio-max-gain=*) amaxgain=${1#*=}; isnum "$amaxgain" "${1%%=*}"; shift ;;
	--audio-only) aonly=1; shift ;;
	--analyze-audio) analyze=1; shift ;;
	--help) usage ;;
	--) rest+=("$@"); break ;;
	--*) echo "unknown option $1"; usage ;;
	*) rest+=("$1"); shift ;;
	esac
done
set -- "${rest[@]+"${rest[@]}"}"
while getopts o:s:r:q:fz:P:a:nt:Fum:R:A:j:h opt; do
	case $opt in
	o) out=$OPTARG ;;
	s) size=$OPTARG ;;
	r) fps=$OPTARG; fps_set=1 ;;
	A) anim=$OPTARG ;;
	j) jq=$OPTARG ;;
	q) q=$OPTARG ;;
	f) fill=1; zmode=fill ;;
	z) zmode=$OPTARG ;;
	P) portrait=$OPTARG ;;
	a) afmt=$OPTARG ;;
	n) noaudio=1 ;;
	t) dur=$OPTARG ;;
	m) rroot=$OPTARG ;;
	R) reserve_mb=$OPTARG ;;
	F) force=1 ;;
	u) upload=1
	   # optional host argument: the next word, if it is not an option or a path
	   if [[ ${!OPTIND:-} == *@* ]]; then board=${!OPTIND}; OPTIND=$((OPTIND + 1)); fi ;;
	*) usage ;;
	esac
done
shift $((OPTIND - 1))
[ $# -ge 1 ] || usage
if [ $upload = 1 ] && [ -z "$board" ]; then
	echo "-u needs the board: -u ebaz@<ip>, or export DZ_BOARD=ebaz@<ip>"
	exit 2
fi
[[ $afmt == wav || $afmt == flac ]] || { echo "-a: wav or flac"; exit 2; }
[[ $zmode =~ ^(fit|fill|box|native)$ ]] || { echo "-z: fit, fill, box or native"; exit 2; }
[[ -z $portrait || $portrait == cw || $portrait == ccw ]] || { echo "-P: cw or ccw"; exit 2; }
if [ -n "$amin" ] && [ -n "$amax" ] && awk -v a="$amin" -v b="$amax" 'BEGIN { exit !(a > b) }'; then
	echo "--audio-min-peak $amin is above --audio-max-peak $amax"; exit 2
fi
if [ $aonly = 1 ] && [ $analyze = 1 ]; then
	echo "--analyze-audio only measures: leave out --audio-only"; exit 2
fi
if [ $aonly = 1 ] && [ -z "$amin$amax" ]; then
	echo "--audio-only needs --audio-min-peak and/or --audio-max-peak"; exit 2
fi
w=${size%x*} h=${size#*x}
command -v ffmpeg > /dev/null && command -v ffprobe > /dev/null || { echo "needs ffmpeg + ffprobe"; exit 1; }

VIDEO='mp4|m4v|mkv|mov|avi|webm|ts|mts|m2ts|mpg|mpeg|wmv|flv|ogv|3gp'
AUDIO='wav|mp3|flac|ogg|oga|opus|m4a|aac|aif|aiff|wma'
IMAGE='png|jpg|jpeg|bmp|gif|webp|tif|tiff|ppm|pgm|tga'

tty=0; [ -t 1 ] && tty=1
if [ $tty = 1 ]; then B=$'\e[1m' D=$'\e[2m' G=$'\e[32m' Y=$'\e[33m' R=$'\e[31m' N=$'\e[0m'
else B= D= G= Y= R= N=; fi

clean_name() {	# the board's rule: A-Z a-z 0-9 . _ -, no leading . or _
	local n
	n=$1
	# é -> e etc. first (when iconv can), then the board's character set
	command -v iconv > /dev/null && n=$(printf '%s' "$n" | iconv -f UTF-8 -t ASCII//TRANSLIT 2>/dev/null || printf '%s' "$n")
	n=$(printf '%s' "$n" | LC_ALL=C tr -c 'A-Za-z0-9._-' '_' | sed -e 's/_\{2,\}/_/g' \
		-e 's/\.\{2,\}/./g' -e 's/^[._]*//' -e 's/_$//' | tail -c 96)
	echo "${n:-file}"
}

human() {	# bytes -> 12.3 MB
	awk -v b="$1" 'BEGIN { if (b >= 1073741824) printf "%.2f GB", b / 1073741824;
		else if (b >= 1048576) printf "%.1f MB", b / 1048576; else printf "%.0f kB", b / 1024 }'
}

probe() {	# probe FILE ENTRIES [STREAM]
	ffprobe -v error ${3:+-select_streams $3} -show_entries "$2" -of csv=p=0 "$1" 2>/dev/null | head -1
}

# run ffmpeg with a progress bar: run_ffmpeg DURATION_S ffmpeg-args...
run_ffmpeg() {
	local total=$1; shift
	local err; err=$(mktemp)
	local cols=${COLUMNS:-80} barw t speed pct fill_n left
	barw=$(( cols > 70 ? 30 : 15 ))
	ffmpeg -hide_banner -nostdin -loglevel error -y -progress pipe:1 -nostats "$@" 2> "$err" |
	while IFS='=' read -r k v; do
		case $k in
		out_time_us) t=$v ;;
		speed) speed=${v// /} ;;
		progress)
			[ $tty = 1 ] || continue
			awk -v t="${t:-0}" -v T="$total" -v s="${speed:-}" -v W="$barw" 'BEGIN {
				p = (T > 0) ? t / 1e6 / T : 0; if (p > 1) p = 1; if (p < 0) p = 0
				n = int(p * W + 0.5); bar = ""
				for (i = 0; i < W; i++) bar = bar (i < n ? "#" : "-")
				sp = s + 0; left = (sp > 0 && T > 0) ? (T - t / 1e6) / sp : -1
				printf "\r    [%s] %3d%%  %s%s   ", bar, p * 100, (s != "" ? s " " : ""),
					(left >= 0 ? sprintf("%ds left", left + 0.5) : "")
			}' ;;
		esac
	done
	local rc=${PIPESTATUS[0]}
	[ $tty = 1 ] && printf '\r\e[K'
	if [ "$rc" != 0 ]; then
		sed 's/^/    /' "$err" | tail -5
	fi
	rm -f "$err"
	return "$rc"
}

newer() {	# output exists and is newer than the input
	[ $force = 0 ] && [ -s "$2" ] && [ "$2" -nt "$1" ]
}

# ---- audio level ---------------------------------------------------------------
# measure_audio IN: a_tp = true peak (dBTP), a_i = integrated loudness (LUFS),
# a_max = max sample (dB, volumedetect: "" or -inf = no signal)
# (+ a_lra = loudness range LU, a_mean = mean level dB)
measure_log() {	# IN: the summary of ebur128 + volumedetect
	ffmpeg -hide_banner -nostdin -nostats -i "$1" ${dur:+-t $dur} -map 0:a:0 -vn \
		-af ebur128=peak=true,volumedetect -f null - 2>&1 | tail -40
}
parse_audio() {	# LOG
	a_max=$(sed -n 's/.*max_volume: \(.*\) dB/\1/p' <<< "$1")
	a_mean=$(sed -n 's/.*mean_volume: \(.*\) dB/\1/p' <<< "$1")
	a_i=$(awk '/Integrated loudness/ { f = 1 } f && $1 == "I:" { print $2; exit }' <<< "$1")
	a_lra=$(awk '/Loudness range/ { f = 1 } f && $1 == "LRA:" { print $2; exit }' <<< "$1")
	a_tp=$(awk '/True peak/ { f = 1 } f && $1 == "Peak:" { print $2; exit }' <<< "$1")
}
measure_audio() { parse_audio "$(measure_log "$1")"; }
# audio_gain: a_gain = the gain in dB from a_tp and the range ("" = none),
# a_note = what happened, for the report
audio_gain() {
	a_gain= a_note=
	[ -n "$amin$amax" ] || return 0
	local r
	r=$(awk -v tp="$a_tp" -v lo="$amin" -v hi="$amax" -v cap="$amaxgain" 'BEGIN {
		if (tp == "" || tp ~ /inf/) { print "x"; exit }
		g = 0; c = ""
		if (lo != "" && tp < lo) g = lo - tp
		if (hi != "" && tp > hi) g = hi - tp
		if (g > cap) { g = cap; c = sprintf(" (capped at +%s dB)", cap) }
		if (g > -0.05 && g < 0.05) { print "0"; exit }
		printf "%+.2f%s\n", g, c }')
	case $r in
	x) a_note="no signal: gain left alone" ;;
	0) a_note="peak in range: unchanged" ;;
	*) a_gain=${r%% *}
	   a_note="gain ${a_gain} dB -> peak $(awk -v t="$a_tp" -v g="$a_gain" 'BEGIN { printf "%.1f", t + g }') dBTP${r#"$a_gain"}" ;;
	esac
}
# the report line: peak, loudness, what the range does
audio_report() {
	echo "    ${D}audio: true peak ${a_tp:-?} dBTP, ${a_i:-?} LUFS${a_note:+, $a_note}${N}"
}

# --audio-only: copy the video, re-render the audio with the gain.
# returns 3 = nothing to do (no audio, or already in range)
do_reaudio() {	# in out
	local in=$1 o=$2 d
	if [ -z "$(probe "$in" stream=index a:0)" ]; then
		echo "    ${D}no audio track: unchanged${N}"; return 3
	fi
	measure_audio "$in"; audio_gain; audio_report
	[ -n "$a_gain" ] || return 3
	d=$(probe "$in" format=duration); d=${d%%.*}; d=${d:-0}
	[ -n "$dur" ] && [ "$dur" -lt "$d" ] 2>/dev/null && d=$dur
	run_ffmpeg "$d" -i "$in" ${dur:+-t $dur} -map '0:v:0?' -c:v copy -map 0:a:0 \
		-af "volume=${a_gain}dB" -c:a pcm_s16le -ar 48000 -ac 2 "$o"
}

n_ok=0 n_skip=0 n_fail=0 n_queued=0 bytes_in=0 bytes_out=0
declare -a fails=()

do_movie() {	# in out
	local in=$1 o=$2 vf="" rate g a d note="" sar iw ih rot dw dh turn="" px=""
	# the displayed size: stored size x sample aspect, a 90/270 rotation tag
	# swaps it (ffmpeg turns such a movie by itself when it decodes)
	iw=$(probe "$in" stream=width v:0); ih=$(probe "$in" stream=height v:0)
	sar=$(probe "$in" stream=sample_aspect_ratio v:0)
	rot=$(ffprobe -v error -select_streams v:0 -show_entries stream_side_data=rotation:stream_tags=rotate \
		-of csv=p=0 "$in" 2>/dev/null | tr -d ' ,\n' | sed 's/^-//')
	if [[ $sar =~ ^([0-9]+):([0-9]+)$ ]] && [ "${BASH_REMATCH[1]}" != "${BASH_REMATCH[2]}" ] &&
	   [ "${BASH_REMATCH[1]}" != 0 ] && [ "${BASH_REMATCH[2]}" != 0 ]; then
		vf="scale='trunc(iw*sar/2)*2':ih,setsar=1,"	# square pixels first
		dw=$(( iw * BASH_REMATCH[1] / BASH_REMATCH[2] )); px=", pixels ${sar} -> square"
	else
		dw=${iw:-0}
	fi
	dh=${ih:-0}
	[[ $rot == 90 || $rot == 270 ]] && { local t=$dw; dw=$dh; dh=$t; }
	if [ -n "$portrait" ] && [ "$dh" -gt "$dw" ] 2>/dev/null; then
		[ "$portrait" = cw ] && vf="${vf}transpose=1," || vf="${vf}transpose=2,"
		turn=" (portrait ${dw}x${dh} turned $portrait)"
		local t=$dw; dw=$dh; dh=$t
	fi
	case $zmode in
	fill)   vf="${vf}scale=$w:$h:force_original_aspect_ratio=increase,crop=$w:$h" ;;
	fit)    vf="${vf}scale=$w:$h:force_original_aspect_ratio=decrease,pad=$w:$h:(ow-iw)/2:(oh-ih)/2" ;;
	box)    vf="${vf}scale=$w:$h:force_original_aspect_ratio=decrease:force_divisible_by=2" ;;
	native) vf="${vf}scale='min($w,iw)':'min($h,ih)':force_original_aspect_ratio=decrease:force_divisible_by=2" ;;
	esac
	vf="$vf,setsar=1,format=yuv420p"
	rate=$(probe "$in" stream=avg_frame_rate v:0)
	g=$(awk -v r="$rate" -v m="$fps" 'BEGIN { split(r, a, "/"); f = a[2] ? a[1] / a[2] : m;
		if (f <= 0 || f > m) f = m; printf "%d", f + 0.5 }')
	d=$(probe "$in" format=duration); d=${d%%.*}; d=${d:-0}
	[ -n "$dur" ] && [ "$dur" -lt "$d" ] 2>/dev/null && d=$dur
	a="-an"
	if [ $noaudio = 0 ] && [ -n "$(probe "$in" stream=index a:0)" ]; then
		measure_audio "$in"
		if [[ -z $a_max || $a_max == -inf ]] || awk -v m="$a_max" 'BEGIN { exit !(m < -80) }'; then
			note="silent audio track removed"
		else
			audio_gain
			a="-map 0:a:0 ${a_gain:+-af volume=${a_gain}dB} -c:a pcm_s16le -ar 48000 -ac 2"
			note="audio 48 kHz 16 bit (max ${a_max} dB)"
		fi
	else
		[ $noaudio = 1 ] && note="audio left out (-n)" || note="no audio track"
	fi
	echo "    ${D}${zmode} in ${w}x${h}${turn}${px}, ${g} fps, ${note}${N}"
	[ "$a" != -an ] && [ -n "$amin$amax" ] && audio_report
	# shellcheck disable=SC2086
	run_ffmpeg "$d" -i "$in" ${dur:+-t $dur} -map 0:v:0 -vf "$vf" -fpsmax "$fps" \
		-c:v mpeg4 -q:v "$q" -g "$g" $a "$o"
}

do_audio() {	# in out
	local in=$1 o=$2 d codec=pcm_s16le
	[ $afmt = flac ] && codec=flac
	d=$(probe "$in" format=duration); d=${d%%.*}; d=${d:-0}
	[ -n "$dur" ] && [ "$dur" -lt "$d" ] 2>/dev/null && d=$dur
	echo "    ${D}48 kHz 16 bit stereo ${afmt}${N}"
	a_gain=
	if [ -n "$amin$amax" ]; then
		measure_audio "$in"; audio_gain; audio_report
		[ $aonly = 1 ] && [ -z "$a_gain" ] && return 3
	fi
	run_ffmpeg "$d" -i "$in" ${dur:+-t $dur} -map 0:a:0 -vn ${a_gain:+-af volume=${a_gain}dB} \
		-ac 2 -ar 48000 -sample_fmt s16 -c:a $codec "$o"
}

do_image() {	# in out
	local in=$1 o=$2
	echo "    ${D}fitted into ${w}x${h}, PNG${N}"
	run_ffmpeg 0 -i "$in" -frames:v 1 \
		-vf "scale='min($w,iw)':'min($h,ih)':force_original_aspect_ratio=decrease" "$o"
}

# ---- -A: one image sequence -------------------------------------------------------
# convert_frame IN OUT: fit into w x h (never enlarged), JPEG quality jq
convert_frame() {
	local in=$1 o=$2 vf="scale='min($w,iw)':'min($h,ih)':force_original_aspect_ratio=decrease"
	if command -v cjpeg > /dev/null; then	# exact quality, baseline 4:2:0
		ffmpeg -hide_banner -nostdin -loglevel error -i "$in" -frames:v 1 -vf "$vf" \
			-pix_fmt rgb24 -f image2pipe -c:v ppm - | cjpeg -quality "$jq" -optimize > "$o.part" &&
			mv -f "$o.part" "$o"
	else				# ffmpeg's scale 2..31 (approximately)
		ffmpeg -hide_banner -nostdin -loglevel error -y -i "$in" -frames:v 1 -vf "$vf" \
			-pix_fmt yuvj420p -q:v $(( 2 + (100 - jq) * 29 / 100 )) -f image2 "$o.part.jpg" &&
			mv -f "$o.part.jpg" "$o"
	fi
}
do_anim() {
	local name adir n=0 f ext list movies=() m start total_b avg kb
	name=$(clean_name "$anim")
	adir="$out/anim/$name"
	mkdir -p "$adir"
	rm -f "$adir"/f[0-9]*.jpg "$adir/timing.txt"
	list=$(mktemp)
	for arg in "$@"; do	# the arguments in their order, each folder in natural order
		if [ -d "$arg" ]; then find "$arg" -type f ! -name '.*' | sort -V
		elif [ -f "$arg" ]; then printf '%s\n' "$arg"
		else echo "${Y}not found: $arg${N}" >&2; fi
	done > "$list.all"
	# images in order; movies are cut into frames where they come in the order
	while IFS= read -r f; do
		ext=${f##*.}; ext=${ext,,}
		if [[ $ext =~ ^($IMAGE)$ ]]; then n=$((n + 1)); printf '%s\t%s\n' "$n" "$f" >> "$list"
		elif [[ $ext =~ ^($VIDEO)$ ]]; then
			n=$((n + 1)); printf '%s\tMOVIE:%s\n' "$n" "$f" >> "$list"
		fi
	done < "$list.all"
	[ -s "$list" ] || { echo "no images or movies"; rm -f "$list" "$list.all"; exit 1; }
	local fpsf="" note=""
	[ "$fps_set" = 1 ] && fpsf="fps=$fps," note=", movies at $fps fps, timing.txt"
	echo "${B}mkmedia -A${N} $name: $(wc -l < "$list") input(s) -> $adir   (${size}, JPEG q $jq$note)"
	local t0=$SECONDS idx=0
	export -f convert_frame
	export w h jq
	# movies first get their frame numbers in sequence: process in order, images in parallel batches
	local batch; batch=$(mktemp)
	flush_batch() {
		[ -s "$batch" ] || return 0
		tr '\n' '\0' < "$batch" | xargs -0 -n 2 -P "$(nproc)" bash -c 'convert_frame "$0" "$1"' 2>&1 | sed 's/^/    /'
		: > "$batch"
	}
	while IFS=$'\t' read -r _ f; do
		if [[ $f == MOVIE:* ]]; then
			flush_batch
			m=${f#MOVIE:}
			start=$((idx + 1))
			echo "    ${D}frames of $m${N}"
			ffmpeg -hide_banner -nostdin -loglevel error -i "$m" \
				-vf "${fpsf}scale='min($w,iw)':'min($h,ih)':force_original_aspect_ratio=decrease" \
				-pix_fmt yuvj420p -q:v $(( 2 + (100 - jq) * 29 / 100 )) -start_number "$start" \
				"$adir/f%05d.jpg" || echo "    ${R}FAILED${N} $m"
			idx=$(find "$adir" -maxdepth 1 -name 'f[0-9]*.jpg' | wc -l)
		else
			idx=$((idx + 1))
			printf '%s\n%s\n' "$f" "$adir/$(printf 'f%05d.jpg' "$idx")" >> "$batch"
		fi
	done < "$list"
	flush_batch
	rm -f "$list" "$list.all" "$batch"
	[ "$fps_set" = 1 ] && printf '# fps %s\n' "$fps" > "$adir/timing.txt.head"
	if [ -f "$adir/timing.txt.head" ]; then	# fps only: every frame once, in order
		{ cat "$adir/timing.txt.head"; (cd "$adir" && ls f[0-9]*.jpg | sort -V); } > "$adir/timing.txt"
		rm -f "$adir/timing.txt.head"
	fi
	n=$(find "$adir" -maxdepth 1 -name 'f[0-9]*.jpg' | wc -l)
	total_b=$(du -cb "$adir"/f[0-9]*.jpg 2>/dev/null | tail -1 | cut -f1)
	avg=$(( n > 0 ? total_b / n : 0 )); kb=$(( avg / 1024 ))
	echo "${G}done${N} in $((SECONDS - t0)) s: $n frames, $(human "$total_b"), ${kb} kB per frame"
	awk -v kb="$kb" 'BEGIN { ms = 25 + 0.16 * kb; a = 2000 / ms; t = 1000 / ms;
		sd = 10240 / (kb > 0 ? kb : 1); if (a > sd) a = sd; if (t > sd / 2) t = sd / 2;
		if (a > 60) a = 60; if (t > 60) t = 60
		printf "    expected at 720p: ~%.0f fps alone, ~%.0f fps with a sequence on the other display\n", a, t }'
	if [ $upload = 1 ]; then
		local ssh_opt="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=5"
		local sshc="ssh $ssh_opt" avail
		command -v sshpass > /dev/null && sshc="sshpass -p '${DZ_PASS:-}' ssh $ssh_opt"
		avail=$(eval "$sshc" "$board" "\"mkdir -p '$rroot/anim/$name' && df -Pk '$rroot' | tail -1\"" < /dev/null |
			awk '{ printf "%.0f", $4 * 1024 }')
		if [ -z "$avail" ]; then echo "${R}upload: no connection to $board${N}"; exit 1; fi
		if [ $((avail - total_b)) -lt $((reserve_mb * 1024 * 1024)) ]; then
			echo "${R}upload: no room on the board ($(human "$avail") free, ${reserve_mb} MB must stay free)${N}"; exit 1
		fi
		echo "${B}upload${N} -> $board:$rroot/anim/$name/"
		rsync -rt --delete --stats --exclude '.*' -e "$sshc" "$adir/" "$board:$rroot/anim/$name/" |
			grep -E "Number of regular files transferred|Total transferred file size" | sed 's/^/    /'
		[ "${PIPESTATUS[0]}" = 0 ] || { echo "${R}upload failed${N}"; exit 1; }
		echo "    play: dzctl -h ${board#*@} /anim/0/play $name"
	fi
	exit 0
}
[ -n "$anim" ] && do_anim "$@"

# ---- collect the inputs --------------------------------------------------------
declare -a files=()
declare -A seen=()
add_path() {	# a file, or a folder (recursive)
	local f
	if [ -d "$1" ]; then
		while IFS= read -r -d '' f; do add_file "$f"; done < <(find "$1" -type f ! -name '.*' -print0 | sort -z)
	elif [ -f "$1" ]; then
		add_file "$1"
	fi
}
add_file() {	# once per real file, even when two arguments match it
	local k
	k=$(realpath -e -- "$1" 2>/dev/null || printf '%s' "$1")
	[ -n "${seen[$k]:-}" ] && return
	seen[$k]=1
	files+=("$1")
}
shopt -s globstar nocaseglob nullglob
for arg in "$@"; do
	if [ -e "$arg" ]; then
		add_path "$arg"
	elif [[ $arg == *[*?[]* ]]; then	# a pattern the shell did not expand (quoted, or no match there)
		# shellcheck disable=SC2206
		matches=( $arg )
		[ ${#matches[@]} -gt 0 ] || { echo "${Y}no match: $arg${N}"; continue; }
		for m in "${matches[@]}"; do add_path "$m"; done
	else
		echo "${Y}not found: $arg${N}"
	fi
done
shopt -u globstar nocaseglob nullglob
total=${#files[@]}
[ "$total" -gt 0 ] || { echo "nothing to convert"; exit 1; }

# ---- --analyze-audio: a table, no output files ------------------------------------
if [ $analyze = 1 ]; then
	adir=$(mktemp -d)
	trap 'rm -rf "$adir"' EXIT
	jobs_max=$(( $(nproc) / 2 )); [ $jobs_max -ge 1 ] || jobs_max=1
	declare -a afiles=()
	for f in "${files[@]}"; do
		ext=${f##*.}; ext=${ext,,}
		[[ $ext =~ ^($VIDEO|$AUDIO)$ ]] && afiles+=("$f")
	done
	[ ${#afiles[@]} -gt 0 ] || { echo "no movies or audio files"; exit 1; }
	echo "${B}mkmedia --analyze-audio${N}: ${#afiles[@]} file(s)${dur:+, first $dur s}, $jobs_max at a time..."
	k=0
	for f in "${afiles[@]}"; do	# measure in parallel, one log per file
		k=$((k + 1))
		while [ "$(jobs -rp | wc -l)" -ge $jobs_max ]; do wait -n; done
		( if [ -n "$(probe "$f" stream=index a:0)" ]; then measure_log "$f" > "$adir/$k.log"; fi ) &
	done
	wait
	nw=4
	for f in "${afiles[@]}"; do b=$(basename "$f"); [ ${#b} -gt $nw ] && nw=${#b}; done
	[ $nw -gt 48 ] && nw=48
	rng=""; [ -n "$amin$amax" ] && rng="gain (${amin:-…} .. ${amax:-…} dBTP)"
	printf "${B}%-${nw}s %8s  %-16s %7s %6s %7s %7s %7s  %s${N}\n" \
		file length audio LUFS LRA "peak" mean max "$rng"
	printf "%-${nw}s %8s  %-16s %7s %6s %7s %7s %7s\n" "" "" "" "" LU dBTP dB dB
	k=0 n_aud=0 n_clip=0 n_none=0 lo= hi= lof= hif=
	for f in "${afiles[@]}"; do
		k=$((k + 1))
		b=$(basename "$f"); [ ${#b} -gt $nw ] && b="${b:0:$((nw - 1))}…"
		d=$(probe "$f" format=duration)
		len=$(awk -v d="${d:-0}" 'BEGIN { d = int(d + 0.5); if (d >= 3600) printf "%d:%02d:%02d", d / 3600, d % 3600 / 60, d % 60;
			else printf "%d:%02d", d / 60, d % 60 }')
		if [ ! -s "$adir/$k.log" ]; then
			printf "%-${nw}s %8s  ${D}%s${N}\n" "$b" "$len" "no audio"
			n_none=$((n_none + 1)); continue
		fi
		fmt=$(probe "$f" stream=codec_name,sample_rate,channels a:0 |
			awk -F, '{ printf "%s %gk %sch", $1, $2 / 1000, $3 }')
		parse_audio "$(cat "$adir/$k.log")"
		audio_gain
		n_aud=$((n_aud + 1))
		c=; act=
		if awk -v t="$a_tp" 'BEGIN { exit !(t != "" && t !~ /inf/ && t + 0 > 0) }'; then c=$R; n_clip=$((n_clip + 1)); fi
		if [ -n "$amin$amax" ]; then
			if [ -n "$a_gain" ]; then act="${Y}${a_gain} dB${N}${a_note#*dBTP}"; else act="${D}${a_note%%:*}${N}"; fi
		fi
		printf "%-${nw}s %8s  %-16s %7s %6s ${c}%7s${N} %7s %7s  %s\n" "$b" "$len" "${fmt:0:16}" \
			"${a_i:--}" "${a_lra:--}" "${a_tp:--}" "${a_mean:--}" "${a_max:--}" "$act"
		if [[ $a_i =~ ^-?[0-9.]+$ ]]; then
			if [ -z "$lo" ] || awk -v a="$a_i" -v b="$lo" 'BEGIN { exit !(a < b) }'; then lo=$a_i lof=$b; fi
			if [ -z "$hi" ] || awk -v a="$a_i" -v b="$hi" 'BEGIN { exit !(a > b) }'; then hi=$a_i hif=$b; fi
		fi
	done
	echo
	clip=; [ $n_clip -gt 0 ] && clip=", ${R}${n_clip} over 0 dBTP (clip)${N}"
	echo "${n_aud} with audio, ${n_none} without${clip}"
	[ -n "$lo" ] && echo "loudness: ${lo} LUFS ($lof) .. ${hi} LUFS ($hif), spread $(awk -v a="$hi" -v b="$lo" 'BEGIN { printf "%.1f", a - b }') LU"
	exit 0
fi

mkdir -p "$out/img" "$out/movies" "$out/audio"
echo "${B}mkmedia${N}: $total file(s) -> $out/{img,movies,audio}   (display ${size}, movies max ${fps} fps)"
t_start=$SECONDS

# ---- upload queue: a background worker sends each finished file -------------------
ssh_opt="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=5"
ssh_cmd="ssh $ssh_opt"
# rsync -e honours quotes: keeps the (empty) password one argument
command -v sshpass > /dev/null && ssh_cmd="sshpass -p '${DZ_PASS:-}' ssh $ssh_opt"
# the same as an array for direct calls (the df before each upload): an
# array keeps the empty password as one argument
# shellcheck disable=SC2206
ssh_arr=(ssh $ssh_opt)
# shellcheck disable=SC2206
command -v sshpass > /dev/null && ssh_arr=(sshpass -p "${DZ_PASS:-}" ssh $ssh_opt)
up_log= up_shown=0 up_pid=
if [ $upload = 1 ]; then
	# check the board before any conversion (2026-10-29: the default host was
	# a board that was off, and every upload failed one by one)
	if ! "${ssh_arr[@]}" "$board" "test -d '$rroot'" < /dev/null 2>/dev/null; then
		echo "${R}upload: no connection to $board, or no $rroot there${N}"
		echo "    give the host: -u ebaz@<ip>, or export DZ_BOARD=ebaz@<ip>"
		exit 1
	fi
	up_dir=$(mktemp -d)
	up_log=$up_dir/done
	: > "$up_log"
	mkfifo "$up_dir/q"
	main_pid=$$
	(	# one file at a time; rsync writes a hidden temp file on the board and
		# renames it at the end (debazd / dzweb skip dot-files)
		reserve=$((reserve_mb * 1024 * 1024))
		while IFS= read -r rel; do
			kill -0 "$main_pid" 2>/dev/null || exit 0	# main gone: stop
			t0=$SECONDS
			# free space on the board (POSIX df: KiB in field 4)
			# < /dev/null: ssh reads stdin, and here stdin is the queue
			avail=$("${ssh_arr[@]}" "$board" "df -Pk '$rroot' | tail -1" < /dev/null 2>/dev/null |
				awk '{ printf "%.0f", $4 * 1024 }')
			need=$(stat -c %s "$out/$rel")
			if [ -n "$avail" ] && [ $((avail - need)) -lt "$reserve" ]; then
				echo "room 0 $rel $need $avail" >> "$up_log"
				continue
			fi
			# --out-format prints the name only when rsync really sends the file
			if sent=$(rsync -t --out-format=%n -e "$ssh_cmd" "$out/$rel" "$board:$rroot/$rel" 2>> "$up_dir/err"); then
				[ -n "$sent" ] && st=ok || st=same
				echo "$st $((SECONDS - t0)) $rel" >> "$up_log"
			else
				echo "FAIL 0 $rel" >> "$up_log"
			fi
		done < "$up_dir/q"
	) &
	up_pid=$!
	# A background job of a non-interactive bash ignores Ctrl-C: without this
	# trap, an interrupted run left its worker uploading (2026-10-28: two
	# workers of two runs sent the same files in parallel). Normal end: the
	# worker has finished (wait below) and the kill finds nothing.
	stop_worker() {
		exec 7>&- 2>/dev/null
		local c	# worker -> $(...) subshell -> rsync: end the chain
		for c in $(pgrep -P "$up_pid" 2>/dev/null); do
			pkill -P "$c" 2>/dev/null
			kill "$c" 2>/dev/null
		done
		kill "$up_pid" 2>/dev/null
		rm -rf "$up_dir"
	}
	trap stop_worker EXIT
	trap 'echo; echo "${Y}interrupted: upload stopped${N}"; exit 130' INT TERM
	exec 7> "$up_dir/q"	# keep the queue open until the end
	echo "    ${D}uploads to $board start as files finish${N}"
fi
show_uploads() {	# report finished uploads (between files: keeps the bar clean)
	[ -n "$up_log" ] || return 0
	local n st t rel more
	n=$(wc -l < "$up_log")
	while [ "$up_shown" -lt "$n" ]; do
		up_shown=$((up_shown + 1))
		read -r st t rel more < <(sed -n "${up_shown}p" "$up_log")
		case $st in
		ok)   echo "    ${G}↑${N} ${D}uploaded $rel (${t} s)${N}" ;;
		same) echo "    ${D}= $rel already on the board${N}" ;;
		room) echo "    ${Y}↑ no room on the board for $rel${N}" ;;
		*)    echo "    ${R}↑ upload FAILED: $rel${N}" ;;
		esac
	done
}

i=0
for f in "${files[@]}"; do
	i=$((i + 1))
	base=$(basename "$f"); ext=${base##*.}; ext=${ext,,}; stem=$(clean_name "${base%.*}")
	if [[ $ext =~ ^($VIDEO)$ ]]; then kind=movies; o="$out/movies/$stem.mkv"
	elif [[ $ext =~ ^($AUDIO)$ ]]; then kind=audio; o="$out/audio/$stem.$afmt"
	elif [[ $ext =~ ^($IMAGE)$ ]]; then kind=img; o="$out/img/$stem.png"
	else
		echo "${D}[$i/$total] skip $f (unknown type)${N}"
		n_skip=$((n_skip + 1)); continue
	fi
	show_uploads
	if [ $aonly = 1 ] && [ $kind = img ]; then
		echo "${D}[$i/$total] skip $f (--audio-only)${N}"
		n_skip=$((n_skip + 1)); continue
	fi
	# --audio-only in place: -t would cut the original
	if [ $aonly = 1 ] && [ -n "$dur" ] && [ "$(realpath -m -- "$f")" = "$(realpath -m -- "$o")" ]; then
		echo "${R}[$i/$total] $f: -t with --audio-only in place would cut the file; use -o elsewhere${N}"
		fails+=("$f"); n_fail=$((n_fail + 1)); continue
	fi
	if newer "$f" "$o"; then
		echo "${D}[$i/$total] up to date: $kind/$(basename "$o")${up_pid:+ (queued: rsync skips it if the board has it)}${N}"
		n_skip=$((n_skip + 1)); n_queued=$((n_queued + 1))
		[ -n "$up_pid" ] && echo "$kind/$(basename "$o")" >&7
		continue
	fi
	sz_in=$(stat -c %s "$f")
	echo "${B}[$i/$total]${N} $f ${D}($(human "$sz_in"))${N} -> ${B}$kind/$(basename "$o")${N}"
	tmp="$(dirname "$o")/.$(basename "$o").part.${o##*.}"
	case $kind in
	movies) if [ $aonly = 1 ]; then do_reaudio "$f" "$tmp"; else do_movie "$f" "$tmp"; fi ;;
	audio)  do_audio "$f" "$tmp" ;;
	img)    do_image "$f" "$tmp" ;;
	esac
	rc=$?
	if [ $rc = 3 ]; then		# --audio-only: nothing to do
		rm -f "$tmp"
		n_skip=$((n_skip + 1)); continue
	fi
	if [ $rc = 0 ] && [ -s "$tmp" ]; then
		mv -f "$tmp" "$o"
		sz_out=$(stat -c %s "$o")
		bytes_in=$((bytes_in + sz_in)); bytes_out=$((bytes_out + sz_out))
		echo "    ${G}ok${N} $(human "$sz_out")${up_pid:+ ${D}(queued for upload)${N}}"
		n_ok=$((n_ok + 1)); n_queued=$((n_queued + 1))
		[ -n "$up_pid" ] && echo "$kind/$(basename "$o")" >&7
	else
		rm -f "$tmp"
		echo "    ${R}FAILED${N}"
		fails+=("$f")
		n_fail=$((n_fail + 1))
	fi
done

el=$((SECONDS - t_start))
echo
fc=$N; [ $n_fail -gt 0 ] && fc=$R
echo "${B}done${N} in ${el} s: ${G}$n_ok converted${N} ($(human $bytes_in) -> $(human $bytes_out)), $n_skip skipped, ${fc}$n_fail failed${N}"
for f in "${fails[@]}"; do echo "  ${R}failed:${N} $f"; done
for k in img movies audio; do
	c=$(find "$out/$k" -maxdepth 1 -type f ! -name '.*' | wc -l)
	[ "$c" -gt 0 ] && echo "  $out/$k: $c file(s), $(du -sh "$out/$k" | cut -f1)"
done

if [ $upload = 1 ]; then
	exec 7>&-			# end of the queue
	q_left=$(( n_queued - $(wc -l < "$up_log") ))
	[ "$q_left" -gt 0 ] && echo "${B}upload${N}: waiting for $q_left queued file(s)..."
	wait "$up_pid"
	show_uploads
	n_upfail=$(grep -c '^FAIL' "$up_log")
	[ "$n_upfail" -gt 0 ] && sed 's/^/    /' "$up_dir/err" | tail -5
	n_room=$(grep -c '^room' "$up_log")
	if [ "$n_room" -gt 0 ]; then
		echo "${Y}upload: $n_room file(s) did not fit (keeping ${reserve_mb} MB free on the board):${N}"
		awk '$1 == "room" { printf "    %s (%.0f MB, %.0f MB free)\n", $3, $4 / 1048576, $5 / 1048576 }' "$up_log"
		echo "    final sync left out (it would fill the board)"
	else
		echo "${B}upload${N}: final sync of $out/{img,movies,audio} -> $board:$rroot/"
		rsync -rt --stats --exclude '.*' -e "$ssh_cmd" "$out/img" "$out/movies" "$out/audio" \
			"$board:$rroot/" | grep -E "Number of regular files transferred|Total transferred file size" |
			sed 's/^/    /'
		[ "${PIPESTATUS[0]}" = 0 ] || { echo "${R}upload failed${N}"; exit 1; }
	fi
	rm -rf "$up_dir"
	echo "${B}total${N} $((SECONDS - t_start)) s"
fi
[ $n_fail = 0 ]

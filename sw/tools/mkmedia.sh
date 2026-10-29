#!/bin/bash
# mkmedia.sh - convert media on the HOST into the board's formats and folder
# layout (2026-10-28). Run on the laptop / build machine, not on the board.
#
#   bash sw/tools/mkmedia.sh [options] FILE|FOLDER ...
#
#   -o DIR    output root (default ./board-media): DIR/img, DIR/movies,
#             DIR/audio - the media folders on the board (-m)
#   -s WxH    display size (default 1280x720): movies are scaled to it,
#             images fitted into it (never enlarged)
#   -r fps    movie frame rate cap (default 25: the board plays 720p at about
#             26 fps; at 30 the audio breaks up, measured 2026-10-28)
#   -q n      MPEG-4 quality, 2 (best) .. 31 (default 4)
#   -f        movies: fill = scale up and crop (default: fit, black bars)
#   -a fmt    audio files: wav (default) or flac (lossless, about half size)
#   -n        movies: no audio at all
#   -t secs   only the first secs seconds of movies and audio (tests)
#   -F        convert again even when the output is newer than the input
#   -u [HOST] upload to the board (default $DZ_BOARD or ebaz@10.42.0.68):
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

out=./board-media size=1280x720 fps=25 q=4 fill=0 afmt=wav noaudio=0 dur=
force=0 upload=0 board=${DZ_BOARD:-ebaz@10.42.0.68} rroot=/media/debaz reserve_mb=256
usage() { sed -n '5,33p' "$0"; exit 2; }
while getopts o:s:r:q:fa:nt:Fum:R:h opt; do
	case $opt in
	o) out=$OPTARG ;;
	s) size=$OPTARG ;;
	r) fps=$OPTARG ;;
	q) q=$OPTARG ;;
	f) fill=1 ;;
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
[[ $afmt == wav || $afmt == flac ]] || { echo "-a: wav or flac"; exit 2; }
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

n_ok=0 n_skip=0 n_fail=0 n_queued=0 bytes_in=0 bytes_out=0
declare -a fails=()

do_movie() {	# in out
	local in=$1 o=$2 vf rate g a d note=""
	if [ $fill = 1 ]; then
		vf="scale=$w:$h:force_original_aspect_ratio=increase,crop=$w:$h"
	else
		vf="scale=$w:$h:force_original_aspect_ratio=decrease,pad=$w:$h:(ow-iw)/2:(oh-ih)/2"
	fi
	vf="$vf,setsar=1,format=yuv420p"
	rate=$(probe "$in" stream=avg_frame_rate v:0)
	g=$(awk -v r="$rate" -v m="$fps" 'BEGIN { split(r, a, "/"); f = a[2] ? a[1] / a[2] : m;
		if (f <= 0 || f > m) f = m; printf "%d", f + 0.5 }')
	d=$(probe "$in" format=duration); d=${d%%.*}; d=${d:-0}
	[ -n "$dur" ] && [ "$dur" -lt "$d" ] 2>/dev/null && d=$dur
	a="-an"
	if [ $noaudio = 0 ] && [ -n "$(probe "$in" stream=index a:0)" ]; then
		local maxv
		maxv=$(ffmpeg -hide_banner -nostdin -i "$in" ${dur:+-t $dur} -map 0:a:0 -vn \
			-af volumedetect -f null - 2>&1 | sed -n 's/.*max_volume: \(.*\) dB/\1/p')
		if [[ -z $maxv || $maxv == -inf ]] || awk -v m="$maxv" 'BEGIN { exit !(m < -80) }'; then
			note="silent audio track removed"
		else
			a="-map 0:a:0 -c:a pcm_s16le -ar 48000 -ac 2"
			note="audio 48 kHz 16 bit (max ${maxv} dB)"
		fi
	else
		[ $noaudio = 1 ] && note="audio left out (-n)" || note="no audio track"
	fi
	echo "    ${D}${w}x${h} ${g} fps, ${note}${N}"
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
	run_ffmpeg "$d" -i "$in" ${dur:+-t $dur} -map 0:a:0 -vn -ac 2 -ar 48000 \
		-sample_fmt s16 -c:a $codec "$o"
}

do_image() {	# in out
	local in=$1 o=$2
	echo "    ${D}fitted into ${w}x${h}, PNG${N}"
	run_ffmpeg 0 -i "$in" -frames:v 1 \
		-vf "scale='min($w,iw)':'min($h,ih)':force_original_aspect_ratio=decrease" "$o"
}

# ---- collect the inputs --------------------------------------------------------
declare -a files=()
for arg in "$@"; do
	if [ -d "$arg" ]; then
		while IFS= read -r -d '' f; do files+=("$f"); done < <(find "$arg" -type f ! -name '.*' -print0 | sort -z)
	elif [ -f "$arg" ]; then
		files+=("$arg")
	else
		echo "${Y}not found: $arg${N}"
	fi
done
total=${#files[@]}
[ "$total" -gt 0 ] || { echo "nothing to convert"; exit 1; }
mkdir -p "$out/img" "$out/movies" "$out/audio"
echo "${B}mkmedia${N}: $total file(s) -> $out/{img,movies,audio}   (display ${size}, movies max ${fps} fps)"
t_start=$SECONDS

# ---- upload queue: a background worker sends each finished file -------------------
ssh_opt="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR"
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
	movies) do_movie "$f" "$tmp" ;;
	audio)  do_audio "$f" "$tmp" ;;
	img)    do_image "$f" "$tmp" ;;
	esac
	if [ $? = 0 ] && [ -s "$tmp" ]; then
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

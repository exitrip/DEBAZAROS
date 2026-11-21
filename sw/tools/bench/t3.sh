#!/bin/sh
# t3.sh - SLOTMEM.md T3 on the board (2026-11-21): transitions of slot S
# between STILL (debazd paints it, write-back) and STREAM (a movie writes it,
# write-combined), checked against a reference picture in DDR.
#
#   sh t3.sh ref [S]          paint the pattern, save DDR of slot S to
#                             /tmp/t3ref.<S>.raw (run with debazd UNCACHED:
#                             benchmode.sh start uncached)
#   sh t3.sh run [S] [N]      N rounds (default 50): pattern -> check, movie
#                             on S 1 s -> stop -> pattern -> check (debazd
#                             cached: benchmode.sh start cached)
# Run as ebaz; dzmemtest needs sudo (/dev/mem). Nothing else may use slot S.
S=${2:-9}
N=${3:-50}
MOVIE=${T3_MOVIE:-wavefarmsky.mkv}
REF=/tmp/t3ref.$S.raw
ADDR=$((0x08000000 + S * 0x7E9000))

fence() { dzctl -t 3000 /sprite/0 >/dev/null 2>&1; }	# a pixel-thread reply

pattern() {
	dzctl -t 0 /draw/$S/clear 0 0 0 >/dev/null
	for y in 0 1 2 3 4; do
		for x in 0 1 2 3 4 5 6 7; do
			dzctl -t 0 /draw/$S/rect $((x * 30 + 20)) $((y * 50)) $((255 - x * 30)) \
				$((x * 230 + 20)) $((y * 200 + 20)) 200 170 >/dev/null
		done
	done
	dzctl -t 0 /draw/$S/text 255 255 0 100 900 "T3 GRID 0123456789" 6 >/dev/null
	dzctl -t 0 /draw/$S/brush 255 0 255 960 540 120 0.7 >/dev/null
	dzctl -t 0 /draw/$S/stroke 0 255 255 10 0.5 100 100 600 800 1200 150 1800 1000 >/dev/null
	dzctl -t 0 /draw/$S/fade 0.25 >/dev/null
	dzctl -t 0 /draw/$S/ellipse 255 128 0 1400 700 200 120 1 >/dev/null
	fence
}

check() {	# $1 = label; prints one line, returns 0 = DDR equals the reference
	sleep 0.1	# direct surfaces are cleaned at the next frame tick (<= 1 frame)
	out=$(sudo /home/ebaz/bin/dzmemtest -s $S -e $REF ddr | tail -1)
	case $out in *"DDR ="*) return 0 ;; esac
	echo "  $1: $out"
	return 1
}

case ${1:-run} in
ref)
	pattern
	sleep 1
	sudo /home/ebaz/bin/dzmemtest -s $S dump $REF >/dev/null
	echo "t3: reference $REF ($(md5sum < $REF | cut -c1-12)), slot $S"
	;;
run)
	[ -s $REF ] || { echo "t3: no $REF (sh t3.sh ref $S with debazd uncached)"; exit 2; }
	bad=0; t0=$(date +%s)
	for r in $(seq 1 $N); do
		pattern; check "round $r still" || bad=$((bad + 1))
		dzctl -t 0 /movie/$S/play $MOVIE 0 0 >/dev/null; sleep 1
		dzctl -t 0 /movie/$S/stop >/dev/null; fence
		pattern; check "round $r after movie" || bad=$((bad + 1))
	done
	echo "t3: $N rounds ($((2 * N)) checks) in $(( $(date +%s) - t0 )) s: $bad mismatches: $( [ $bad = 0 ] && echo PASS || echo FAIL)"
	cat /sys/class/misc/dzmem/stats 2>/dev/null
	;;
*) sed -n '2,13p' "$0"; exit 2 ;;
esac

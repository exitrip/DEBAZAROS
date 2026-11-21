#!/bin/sh
# t4.sh - SLOTMEM.md T4 on the board (2026-11-21): paint-op timing IN debazd
# (/stats/op: median p95 min max of the handler, no OSC round trip), slot S
# (a still slot: nothing else writes it). Start debazd in bench mode first
# (benchmode.sh start cached|uncached); the A/B driver is t4ab.sh (laptop).
#
#   sh t4.sh [S] [N]       N timed calls per op (default 30) after 3 warm-ups
# Output: "op <key> <count> <median> <p95> <min> <max>" lines (ms), the first
# draw, RAM in paint buffers, dzmem clean totals.
S=${1:-9}
N=${2:-30}
GRAB=${T4_GRAB:-6}		# a second still slot for the grab test
IMG=${T4_IMG:-flyer-addy.png}
IMG2=${T4_IMG2:-bench-direct-1.png}	# alternate: the same image again is a no-op

d() { dzctl -t 0 "$@" >/dev/null 2>&1; }
fence() { dzctl -t 5000 /sprite/0 >/dev/null 2>&1; }
stat_of() { dzctl -t 3000 /stats/op "$1" | sed 's/^\/stats\/op /op /; s/"//g'; }

# the first draw on a fresh debazd (no paint buffer yet)
d /stats/op/reset
d /draw/$S/rect 255 0 0 10 10 50 50; fence
echo "first $(stat_of /draw/*/rect | awk '{print $4}')"
d /draw/$GRAB/clear 30 60 90; fence

op() {	# name, then the message with {i} for the call number
	name=$1; shift
	for w in 1 2 3; do d $(echo "$@" | sed "s/{i}/$w/g"); done; fence
	d /stats/op/reset
	i=1
	while [ $i -le $N ]; do d $(echo "$@" | sed "s/{i}/$i/g"); i=$((i + 1)); done
	fence
	key=$(echo "$1" | sed 's|/[0-9][0-9]*/|/*/|')
	echo "$name $(stat_of "$key" | head -1)"
}

op clear      /draw/$S/clear {i} 10 10
op fade       /draw/$S/fade 0.1
op rect       /draw/$S/rect 0 255 0 {i}00 500 200 150
op brush      /draw/$S/brush 255 0 0 {i}0 300 20 0.5
op stroke     /draw/$S/stroke 255 0 255 8 0.5 100 100 300 200 500 150 700 300 900 200 1100 350 1200 100 1250 400
op text       /draw/$S/text 255 255 0 100 700 T4-{i} 4
op grab_other /surface/$S/grab $GRAB
op grab_own   /surface/$S/grab
img_alt() { [ $(($1 % 2)) = 1 ] && echo $IMG || echo $IMG2; }
op_img() {	# like op, the image name alternating per call
	for w in 1 2 3; do d /img/$S/file $(img_alt $w); done; fence
	d /stats/op/reset
	i=1
	while [ $i -le $N ]; do d /img/$S/file $(img_alt $i); i=$((i + 1)); done
	fence
	echo "img_file $(stat_of /img/*/file | head -1)"
}
op_img
dzctl -t 3000 /surface/mem | sed 's/^/mem /; s/"//g'
# transforms last: they move a direct surface to a RAM buffer for 60 s
op scroll     /draw/$S/scroll 4 0
op rotozoom   /draw/$S/rotozoom 3 1.01
dzctl -t 3000 /surface/mem | sed 's/^/mem_end /; s/"//g'
cat /sys/class/misc/dzmem/stats 2>/dev/null | sed 's/^/dzmem /'

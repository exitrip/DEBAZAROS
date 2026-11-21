#!/bin/sh
# t5.sh - SLOTMEM.md T5 on the board (2026-11-21): a show-like load for M
# minutes, then the T3 picture check. Start debazd in bench mode first
# (benchmode.sh start cached|uncached), keep the HDMI_2 input live and the
# serial log running (boardpower.sh log start, laptop).
#   movie on slot 6 (STREAM, loops), capture slot 4 on display 0, paint on
#   slot 9 (STILL) on display 1: rect / brush / text every second, a fade
#   every 5 s, a grab of the movie every 10 s, a transition every minute
#   (movie on 9 for 5 s, stop, paint again); ASCII 6 -> 8, slit 6 -> 7.
#   Every minute: uptime, taint, memory, movie stats, video events, dzmem.
#
#   sh t5.sh [minutes]      (default 15); the reference /tmp/t3ref.9.raw
#                           must exist (t3.sh ref 9 with debazd uncached)
M=${1:-15}
MOVIE=${T5_MOVIE:-wavefarmsky.mkv}
S=9
d() { dzctl -t 0 "$@" >/dev/null 2>&1; }
fence() { dzctl -t 5000 /sprite/0 >/dev/null 2>&1; }
sample() {
	echo "t5 $(date +%T) min $1: up $(cut -d. -f1 /proc/uptime) s, taint $(cat /proc/sys/kernel/tainted)," \
	     "$(free -m | awk 'NR == 2 {print $7}') MB avail, video events $(grep -c VIDEO /tmp/debazd.log)," \
	     "movie $(dzctl -t 1000 /movie/6/stats | cut -d' ' -f2-6)," \
	     "capture $(dzctl -t 1000 /capture/status | cut -d' ' -f2-4)"
	[ -r /sys/class/misc/dzmem/stats ] && echo "    dzmem $(cut -d' ' -f1-12 /sys/class/misc/dzmem/stats)"
	top -bn1 | awk 'NR > 7 && $9 > 3 {printf "%s %s%% ", $12, $9} END {print ""}' | sed 's/^/    cpu /'
}

d /movie/6/loop 1
d /movie/6/play $MOVIE 0 0
d /disp/0/capture
d /disp/1/show $S
d /draw/$S/clear 20 20 40
d /ascii/8/cols 160; d /ascii/8/mode ascii; d /ascii/8/run 6
d /slit/7/mode col; d /slit/7/speed 250; d /slit/7/band 16; d /slit/7/run 6
d /stats/op/reset
sleep 3
sample 0
t_end=$(( $(date +%s) + M * 60 )); n=0; next=60
while [ $(date +%s) -lt $t_end ]; do
	n=$((n + 1))
	d /draw/$S/rect $((n * 37 % 255)) $((n * 91 % 255)) 128 $((n * 53 % 1700)) $((n * 29 % 900)) 200 150
	d /draw/$S/brush 255 $((n * 13 % 255)) 0 $((n * 71 % 1900)) $((n * 47 % 1060)) 30 0.6
	d /draw/$S/text 255 255 0 $((n * 17 % 1500)) $((n * 31 % 1000)) T5-$n 3
	[ $((n % 5)) = 0 ] && d /draw/$S/fade 0.15
	[ $((n % 10)) = 0 ] && d /surface/$S/grab 6
	el=$(( M * 60 - (t_end - $(date +%s)) ))
	if [ $el -ge $next ]; then
		d /movie/$S/play $MOVIE 0 0; sleep 5; d /movie/$S/stop; fence
		d /draw/$S/clear 20 20 40
		sample $((next / 60)); next=$((next + 60))
	fi
	sleep 1
done
d /ascii/8/run -1; d /slit/7/stop; d /movie/6/stop; d /movie/$S/stop; fence
echo "t5: paint ops (count median p95 min max ms):"
dzctl -t 3000 /stats/op /draw | sed 's/^/    /; s/"//g'
dzctl -t 3000 /stats/op /surface | sed 's/^/    /; s/"//g'
sh /tmp/t3.sh run $S 1 | tail -2
sample end

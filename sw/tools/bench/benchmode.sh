#!/bin/bash
# benchmode.sh - put a bench board into the fixed state of the slot-memory
# tests (sw/SLOTMEM.md section 5.0 rule 3), from the laptop (2026-11-21).
#
#   benchmode.sh [-u ebaz@host] stop          stop debazd, dzweb and every slot
#                                             writer (by PID), keep hdmi2
#   benchmode.sh [-u ...] start [cached|uncached]
#                                             stop, then start debazd without
#                                             resume (DZ_NO_RESUME=1), log in
#                                             /tmp/debazd.log; uncached =
#                                             DZ_DZMEM=0
#   benchmode.sh [-u ...] record              the session header: kernel,
#                                             taint, dzmem, binaries, mode,
#                                             processes above 2 % CPU
#
# The board's own units (debazd.service, dzweb.service) are stopped with
# systemctl when they are active, else the processes by PID. A session must
# start from a fresh boot (boardpower.sh reboot) and stop on a taint other
# than 4096 (an out-of-tree module, normal on .236).
set -uo pipefail
BOARD=${DZ_BOARD:-ebaz@10.42.0.236}
while getopts "u:h" o; do
	case $o in u) BOARD=$OPTARG ;; *) sed -n '2,22p' "$0"; exit 2 ;; esac
done
shift $((OPTIND - 1))
O=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=5)
on() { sshpass -p '' ssh "${O[@]}" "$BOARD" "$@"; }

stop_all() {
	on 'for u in debazd dzweb; do systemctl is-active -q $u.service 2>/dev/null && sudo systemctl stop $u.service && echo "stopped unit $u"; done
	for name in debazd dzweb fbfeed dzlua dzmosh ffmpeg arecord aplay dzmemtest; do
		for p in $(pgrep -x $name); do sudo kill $p && echo "stopped $name pid $p"; done
	done
	sleep 2
	for name in debazd dzweb fbfeed dzlua dzmosh ffmpeg arecord aplay dzmemtest; do
		for p in $(pgrep -x $name); do sudo kill -9 $p && echo "KILLED $name pid $p (did not stop)"; done
	done
	pgrep -a hdmi2 >/dev/null && echo "hdmi2 kept: $(pgrep -a hdmi2)" || echo "WARNING: hdmi2 is not running (no scan out)"'
}

record() {
	on 'echo "date      $(date -u +%FT%TZ)"
	echo "kernel    $(uname -r), up $(cut -d. -f1 /proc/uptime) s"
	t=$(cat /proc/sys/kernel/tainted); echo "tainted   $t$( [ $t = 0 ] || [ $t = 4096 ] && echo " (ok)" || echo " STOP: not a fresh kernel")"
	if [ -e /dev/dzmem ]; then echo "dzmem     $(dmesg | grep -o "dzmem: /dev/dzmem.*" | tail -1)"; cat /sys/class/misc/dzmem/stats 2>/dev/null | sed "s/^/          /"; else echo "dzmem     not loaded"; fi
	for b in debazd fbfeed dzlua dzmemtest hdmi2.elf; do f=/home/ebaz/bin/$b; [ -e $f ] && echo "$(printf %-9s $b) $(md5sum < $f | cut -c1-12) $(date -r $f +%F_%T)"; done
	m=$(dzctl -t 1000 /video/mode 2>/dev/null | head -1); echo "mode      ${m:-(debazd not running)}"
	echo "busy      $(top -bn1 | awk "NR > 7 && \$9 > 2 {print \$12 \"(\" \$9 \"%)\"}" | tr "\n" " ")"
	free -m | awk "NR == 2 {print \"memory    \" \$7 \" MB available\"}"'
}

case ${1:-record} in
stop) stop_all ;;
start)
	stop_all
	env=DZ_NO_RESUME=1
	[ "${2:-cached}" = uncached ] && env="$env DZ_DZMEM=0"
	on "sudo sh -c '$env setsid nohup /home/ebaz/bin/debazd -v > /tmp/debazd.log 2>&1 < /dev/null &'; sleep 3; grep -m1 'slot memory' /tmp/debazd.log; pgrep -a debazd"
	;;
record) record ;;
*) sed -n '2,22p' "$0"; exit 2 ;;
esac

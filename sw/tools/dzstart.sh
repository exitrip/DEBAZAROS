#!/bin/sh
# dzstart.sh - bring a booted board to the working state (2026-10-29): load
# the dev bitstream (plreload.sh: stops hdmi2 + debazd, soft-resets the
# capture, loads, starts hdmi2 + debazd, mixer boot setup), then start dzweb
# (as ebaz) and check that everything runs. On the board, as root:
#
#   sudo sh /home/ebaz/bin/dzstart.sh                 bitstream of the config
#   sudo sh /home/ebaz/bin/dzstart.sh x.bit.bin       this one (in /lib/firmware
#                                                     or a path)
#   sudo sh /home/ebaz/bin/dzstart.sh x.bit.bin -r 1920x1080   + hdmi2 args
#   sudo sh /home/ebaz/bin/dzstart.sh -n              no PL load: only start
#                                                     what does not run
#
# Config /home/ebaz/dzstart.conf (shell, all optional):
#   BITSTREAM=ebaz4205_2out1in_20261029_osc_epo.bit.bin
#   HDMI2_ARGS="-r 1280x720"
#   WEB=1                      0 = do not start dzweb
#
# Why: after a reboot the card loads only the stable bitstream of BOOT.BIN
# and starts none of the software. The installed debazd / dz_fields follow
# the hw_map.h of the DEV bitstream (since build osc: DDS 1 at 0x43D0_4000,
# a bus error on the boot bitstream), so start it only after the load.
# The script runs itself detached (setsid): the ethernet PHY clock comes
# from the PL, so the ssh link can drop during the load; the log is
# /tmp/dzstart.log (this terminal shows it while it runs).
set -u
D=/home/ebaz/bin
CONF=/home/ebaz/dzstart.conf
LOG=/tmp/dzstart.log

if [ -z "${DZSTART_BG:-}" ]; then
	[ "$(id -u)" = 0 ] || { echo "dzstart: run as root (sudo)"; exit 1; }
	: > $LOG
	DZSTART_BG=1 setsid nohup sh "$0" "$@" >> $LOG 2>&1 < /dev/null &
	pid=$!
	tail -n +1 -f --pid=$pid $LOG 2>/dev/null || { wait $pid; cat $LOG; }
	tail -1 $LOG | grep -q "^dzstart: OK" && exit 0
	exit 1
fi

BITSTREAM=
HDMI2_ARGS="-r 1280x720"
WEB=1
[ -f $CONF ] && . $CONF
load=1
if [ "${1:-}" = -n ]; then
	load=0
	shift
elif [ $# -ge 1 ] && [ "${1#-}" = "$1" ]; then
	BITSTREAM=$1
	shift
fi
[ $# -ge 1 ] && HDMI2_ARGS="$*"
fail() { echo "dzstart: FAILED: $*"; exit 1; }
echo "dzstart: $(date '+%F %T'), PL load $load, bitstream '${BITSTREAM:-}', hdmi2 $HDMI2_ARGS"

# ---- 1. bitstream + hdmi2 + debazd + mixer setup (plreload.sh) ---------------------
if [ $load = 1 ]; then
	[ -n "$BITSTREAM" ] || fail "no bitstream (argument or BITSTREAM in $CONF)"
	case $BITSTREAM in
	*/*) src=$BITSTREAM ;;
	*)   src=/lib/firmware/$BITSTREAM ;;
	esac
	[ -f "$src" ] || fail "$src not found"
	name=$(basename "$src")
	[ "$src" = /tmp/$name ] || cp "$src" /tmp/$name || fail "copy to /tmp"
	# plreload refuses to load while a DEBAZ PCM is open or the capture reset sticks
	# shellcheck disable=SC2086
	sh $D/plreload.sh "$name" $HDMI2_ARGS > /tmp/plreload.log 2>&1
	rc=$?
	grep -v '^+' /tmp/plreload.log | sed 's/^/  plreload: /' | tail -5
	[ $rc = 0 ] && tail -1 /tmp/plreload.log | grep -q DONE || fail "plreload (rc $rc, /tmp/plreload.log)"
else
	pgrep -f hdmi2.elf > /dev/null || {
		# shellcheck disable=SC2086
		setsid nohup $D/hdmi2.elf $HDMI2_ARGS > /tmp/hdmi2.log 2>&1 < /dev/null &
		echo "  started hdmi2"
		sleep 4
	}
	pgrep -x debazd > /dev/null || {
		setsid nohup $D/debazd -v > /tmp/debazd.log 2>&1 < /dev/null &
		echo "  started debazd"
		sleep 1
	}
fi

# ---- 2. dzweb (as ebaz: it serves /home/ebaz/www and the media) -----------------------
if [ "$WEB" = 1 ] && ! pgrep -x dzweb > /dev/null; then
	# setpriv, not su: su ends its login session at exit and that kills
	# dzweb. The old log goes first: root may not write a file of ebaz in
	# the sticky /tmp (protected_regular).
	rm -f /tmp/dzweb.log
	(cd /home/ebaz && HOME=/home/ebaz setsid nohup setpriv --reuid=ebaz --regid=ebaz \
		--init-groups ./bin/dzweb > /tmp/dzweb.log 2>&1 < /dev/null &)
	echo "  started dzweb"
	sleep 1
fi

# ---- 3. check --------------------------------------------------------------------------
ok=1
for p in hdmi2.elf debazd; do
	pgrep -f "$p" > /dev/null || { echo "  $p does not run"; ok=0; }
done
[ "$WEB" = 1 ] && { pgrep -x dzweb > /dev/null || { echo "  dzweb does not run"; ok=0; }; }
reply=$($D/dzctl -t 500 /ping 2>/dev/null)
[ -n "$reply" ] || { echo "  debazd does not answer /ping"; ok=0; }
echo "  PL $(cat /sys/class/fpga_manager/fpga0/state), display VDMAs SR $(/sbin/devmem 0x43000004 32) $(/sbin/devmem 0x43010004 32)"
echo "  capture: $($D/dzctl -t 500 /capture/status 2>/dev/null)"
ip=$(awk '/32 host/ { print f } { f = $2 }' /proc/net/fib_trie 2>/dev/null | grep -v '^127\.' | head -1)
echo "  web: http://${ip:-$(hostname)}:8080/"
[ $ok = 1 ] || fail "see above (logs: /tmp/plreload.log, /tmp/hdmi2.log, /tmp/debazd.log, /tmp/dzweb.log)"
echo "dzstart: OK"

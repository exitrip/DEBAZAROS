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
# Config (shell, all optional): /data/debaz/dzstart.conf (the card's, on
# the data partition), else /home/ebaz/dzstart.conf (old place: copied to
# /data/debaz once), else the image's /etc/debaz/dzstart.conf
# ($DZSTART_CONF = another file):
#   BITSTREAM=ebaz4205_2out1in_20261101_sdly.bit.bin   (empty = no PL load:
#                              the bitstream of BOOT.BIN; the image's BOOT.BIN
#                              carries the current one)
#   HDMI2_ARGS="-r 1280x720"
#   WEB=1                      0 = do not start dzweb
#   SHOW=flyer1204             (2026-11-19) after a FRESH start (boot, PL
#   CUE="main 1"               load): load this show and go to this cue (an
#                              installation comes back by itself; a debazd
#                              restart resumes instead: debazd/resume.c)
#   SYNTH="0,1"                (2026-11-21) start the MIDI synth (dzaudio,
#                              dzsynth.sh start $SYNTH: outs [soundfont] [fx]
#                              [routing]) after debazd; empty = off. Those
#                              outputs are then the synth's: no movie audio
# At boot: debaz.service (image) runs this with DZSTART_BG=1 (no detach,
# the output goes to the journal: journalctl -u debaz).
#
# Units (2026-11-19): when debazd.service is installed, the programs run as
# systemd units - debaz-video (hdmi2), debazd (restarted when it dies, its
# state comes back), dzweb (as ebaz) - and this script starts the units
# (stray copies started by hand are stopped first). /run/debaz/fresh tells
# debazd.service that the PL is at reset: its ExecStartPost runs dzsetup.sh.
# Logs: journalctl -u debazd / -u debaz-video / -u dzweb. Without the units
# (older cards) the old way: setsid + /tmp/*.log.
#
# Why: after a reboot the card loads only the stable bitstream of BOOT.BIN
# and starts none of the software. The installed debazd / dz_fields follow
# the hw_map.h of the DEV bitstream (since build osc: DDS 1 at 0x43D0_4000,
# a bus error on the boot bitstream), so start it only after the load.
# The script runs itself detached (setsid): the ethernet PHY clock comes
# from the PL, so the ssh link can drop during the load; the log is
# /tmp/dzstart.log (this terminal shows it while it runs).
set -u
D=${DZ_BIN:-/home/ebaz/bin}; [ -x "$D/debazd" ] || D=/usr/bin	# dev copy, else the image (dz_path.h)
# config: $DZSTART_CONF, else the card's on the data partition, else the
# old place in the home folder (root fs: read-only later), else the image's
CONF=${DZSTART_CONF:-/data/debaz/dzstart.conf}
[ -f "$CONF" ] || CONF=/home/ebaz/dzstart.conf
[ -f "$CONF" ] || CONF=/etc/debaz/dzstart.conf
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
SHOW=
CUE=
SYNTH=
[ -f $CONF ] && . $CONF
load=1
if [ "${1:-}" = -n ]; then
	load=0
	shift
elif [ $# -ge 1 ] && [ "${1#-}" = "$1" ]; then
	BITSTREAM=$1
	shift
fi
[ -n "$BITSTREAM" ] || load=0		# no bitstream: the one of BOOT.BIN
[ $# -ge 1 ] && HDMI2_ARGS="$*"
fail() { echo "dzstart: FAILED: $*"; exit 1; }
UNITS=0
systemctl cat debazd.service > /dev/null 2>&1 && UNITS=1
# a copy of prog that runs outside its unit: stop it (SIGTERM, up to 3 s)
stray() {
	systemctl is-active -q "$2" && return 0
	pids=$(pgrep -x "$1") || return 0
	echo "  stopping $1 started by hand ($pids)"
	# shellcheck disable=SC2086
	kill $pids 2>/dev/null
	i=0
	while [ $i -lt 30 ] && pgrep -x "$1" > /dev/null; do sleep 0.1; i=$((i + 1)); done
	return 0
}
echo "dzstart: $(date '+%F %T'), PL load $load, bitstream '${BITSTREAM:-BOOT.BIN}', hdmi2 $HDMI2_ARGS, programs $D, config $CONF, units $UNITS"
mkdir -p /run/debaz
# persistent files live on the data partition (the root fs becomes read-only
# later): its folders, and the old home-folder config moved there once
if mountpoint -q /data 2>/dev/null; then
	mkdir -p /data/debaz /data/shows
	if [ ! -f /data/debaz/dzstart.conf ] && [ -f /home/ebaz/dzstart.conf ]; then
		cp /home/ebaz/dzstart.conf /data/debaz/dzstart.conf &&
			echo "  config copied to /data/debaz/dzstart.conf (edit it there)"
	fi
fi
# hdmi2 arguments given here: the video unit uses them (also after a restart)
[ $UNITS = 1 ] && [ $# -ge 1 ] && echo "$HDMI2_ARGS" > /run/debaz/video.args

# ---- 1. bitstream + hdmi2 + debazd + mixer setup (plreload.sh) ---------------------
if [ $load = 1 ]; then
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
elif [ $UNITS = 1 ]; then
	if systemctl is-active -q debaz-video; then
		:
	elif pgrep -x hdmi2.elf > /dev/null; then
		# a restart relocks the pixel clock = a mode switch (capture wedge
		# risk with a live input): leave it; /video/mode moves it into the unit
		echo "  hdmi2 runs outside its unit: left running"
	else
		# the displays were off: the PL is at its reset state
		started_fresh=1
		touch /run/debaz/fresh
		rm -f /run/debaz/autosave.bin
		systemctl start debaz-video && echo "  started debaz-video (hdmi2)"
		sleep 4
	fi
	stray debazd debazd
	# ExecStartPost waits for /ping and runs dzsetup.sh after a fresh PL
	systemctl start debazd && echo "  started debazd"
else
	fresh=0
	pgrep -f hdmi2.elf > /dev/null || {
		# shellcheck disable=SC2086
		setsid nohup $D/hdmi2.elf $HDMI2_ARGS > /tmp/hdmi2.log 2>&1 < /dev/null &
		echo "  started hdmi2"
		fresh=1			# the displays were off: the PL is at its reset state
		sleep 4
	}
	pgrep -x debazd > /dev/null || {
		setsid nohup $D/debazd -v > /tmp/debazd.log 2>&1 < /dev/null &
		echo "  started debazd"
		sleep 1
	}
	# after a power-up the registers are at reset (HDMI_0 black): boot setup;
	# never over a running setup (it would undo the user's state)
	[ $fresh = 1 ] && { sh $D/dzsetup.sh > /tmp/dzsetup.log 2>&1; echo "  boot setup (dzsetup.sh)"; }
fi

# ---- 2. dzweb (as ebaz: it serves /home/ebaz/www and the media) -----------------------
if [ "$WEB" = 1 ] && [ $UNITS = 1 ]; then
	stray dzweb dzweb
	systemctl start dzweb && echo "  started dzweb"
elif [ "$WEB" = 1 ] && ! pgrep -x dzweb > /dev/null; then
	# setpriv, not su: su ends its login session at exit and that kills
	# dzweb. The old log goes first: root may not write a file of ebaz in
	# the sticky /tmp (protected_regular).
	rm -f /tmp/dzweb.log
	(cd /home/ebaz && HOME=/home/ebaz setsid nohup setpriv --reuid=ebaz --regid=ebaz \
		--init-groups $D/dzweb > /tmp/dzweb.log 2>&1 < /dev/null &)
	echo "  started dzweb"
	sleep 1
fi

# ---- 2b. the MIDI synth (before the show: its scripts may play MIDI) -------------------
# after debazd answers (dzaudio finds debazd's tap FIFOs by itself and
# follows debazd restarts)
if [ -n "$SYNTH" ] && ! pgrep -x dzaudio > /dev/null && ! pgrep -x fluidsynth > /dev/null; then
	i=0
	while [ $i -lt 50 ] && ! $D/dzctl -t 200 /ping > /dev/null 2>&1; do sleep 0.1; i=$((i + 1)); done
	# shellcheck disable=SC2086
	echo "  synth: $(sh $D/dzsynth.sh start $SYNTH 2>&1 | tail -1)"
fi

# ---- 3. the boot show (fresh start only) ---------------------------------------------
if [ -n "$SHOW" ] && { [ $load = 1 ] || [ "${fresh:-0}" = 1 ] || [ -f /run/debaz/fresh ] || [ "${started_fresh:-0}" = 1 ]; }; then
	i=0
	while [ $i -lt 50 ] && ! $D/dzctl -t 200 /ping > /dev/null 2>&1; do sleep 0.1; i=$((i + 1)); done
	sleep 1					# the boot setup (dzsetup) first
	echo "  show: $($D/dzctl -t 2000 /show/load "$SHOW" 2>&1)"
	# shellcheck disable=SC2086
	[ -n "$CUE" ] && echo "  cue: $($D/dzctl -t 2000 /cue/go $CUE 2>&1)"
fi

# ---- 4. check --------------------------------------------------------------------------
ok=1
for p in hdmi2.elf debazd; do
	pgrep -x "$p" > /dev/null || { echo "  $p does not run"; ok=0; }
done
[ $UNITS = 1 ] && for u in debazd; do
	systemctl is-active -q $u || { echo "  unit $u is not active"; ok=0; }
done
[ "$WEB" = 1 ] && { pgrep -x dzweb > /dev/null || { echo "  dzweb does not run"; ok=0; }; }
reply=$($D/dzctl -t 500 /ping 2>/dev/null)
[ -n "$reply" ] || { echo "  debazd does not answer /ping"; ok=0; }
echo "  PL $(cat /sys/class/fpga_manager/fpga0/state), display VDMAs SR $(/sbin/devmem 0x43000004 32) $(/sbin/devmem 0x43010004 32)"
echo "  capture: $($D/dzctl -t 500 /capture/status 2>/dev/null)"
ip=$(awk '/32 host/ { print f } { f = $2 }' /proc/net/fib_trie 2>/dev/null | grep -v '^127\.' | head -1)
echo "  web: http://${ip:-$(hostname)}:8080/"
if [ $UNITS = 1 ]; then
	[ $ok = 1 ] || fail "see above (logs: /tmp/plreload.log, journalctl -u debaz-video -u debazd -u dzweb)"
else
	[ $ok = 1 ] || fail "see above (logs: /tmp/plreload.log, /tmp/hdmi2.log, /tmp/debazd.log, /tmp/dzweb.log)"
fi
echo "dzstart: OK"

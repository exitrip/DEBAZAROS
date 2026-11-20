#!/bin/sh
# dzsynth.sh - fluidsynth as the units' General MIDI synth (2026-11-20).
# Audio to the DEBAZ ALSA card (HDMI 0 / HDMI 1 / I2S), MIDI in from the ALSA
# sequencer; the four VirMIDI ports (card 1, /dev/snd/midiC1D0..3 = clients
# 20-23) and every running Lua script's MIDI port ("dzlua <slot>") are
# connected to it.
#
#   dzsynth.sh start [out] [soundfont] [fx]   out: 0 | 1 (default) | 3 = I2S
#              soundfont: default /usr/share/soundfonts/default.sf2 (TimGM6mb),
#              or a name in /media/debaz/soundfonts; fx: 1 = reverb + chorus
#              (about twice the CPU; default off)
#   dzsynth.sh stop | status
#   Run with sudo for real-time priority (as ebaz fluidsynth warns
#   "Failed to set thread to high priority" and still plays).
# Measured on the board (2026-11-20, 48 kHz, 2 cores, fx off): idle ~7 % of a
# core, 8 piano notes 12 %, 20 string notes 67 %; fx on: 25 % / ~100 %.
# ⚠️ The DEBAZ PCM of that output has ONE owner: no movie audio, /audio/play
# or pcmplay on the same output while the synth runs.
# Analysis (2026-11-20): while debazd runs, the synth plays through the tap
# PCM debaz_tap<out> (/etc/asound.conf): debazd gets a copy (/audio/react/
# source synth or auto; LFO shape audio, DDS scope, Lua audio.*). Without
# debazd (nobody reads the FIFO) it plays to hw:DEBAZ,<out> directly.
# A watcher (started with it) restarts fluidsynth when its PCM stops while
# it runs: a debazd restart breaks the tap's pipe (fluidsynth then reports
# an audio device error and goes silent); the restart uses the tap again
# once debazd is back, and connects VirMIDI and the scripts again.
set -u
LOG=/tmp/dzsynth.log
WPID=/tmp/dzsynth.watch.pid
pid() { pgrep -x fluidsynth | head -1; }
client() { aconnect -l | sed -n 's/^client \([0-9]*\): .FLUID Synth (debaz-synth).*/\1/p' | head -1; }

# connect VirMIDI 1-0..3 and every "dzlua <slot>" / "dzlua <slot> panic" port
wire() {
	c=$1
	for v in 20 21 22 23; do aconnect $v:0 $c:0 2>/dev/null; done
	for d in $(aconnect -l | sed -n "s/^client \([0-9]*\): 'dzlua .*/\1/p"); do
		aconnect $d:0 $c:0 2>/dev/null
	done
}

launch() {		# out sf fx -> fluidsynth running, wired; prints the device
	out=$1 sf=$2 fxon=$3
	fx="-R 0 -C 0"
	[ "$fxon" = 1 ] && fx="-R 1 -C 1"
	dev=hw:DEBAZ,$out
	if pgrep -x debazd > /dev/null && [ -p /tmp/dztap.$out ] && grep -q "debaz_tap$out" /etc/asound.conf 2>/dev/null; then
		dev=debaz_tap$out		# debazd reads the copy
	fi
	trap '' PIPE			# a broken tap pipe must not kill it (inherited)
	# shellcheck disable=SC2086
	setsid nohup fluidsynth -i -s $fx -a alsa -m alsa_seq -o audio.alsa.device=$dev \
		-o synth.cpu-cores=2 -o midi.alsa_seq.id=debaz-synth -r 48000 -g 0.6 "$sf" \
		>> $LOG 2>&1 < /dev/null &
	c=
	for i in 1 2 3 4 5 6 7 8 9 10; do
		c=$(client)
		[ -n "$c" ] && break
		sleep 0.3
	done
	[ -n "$c" ] || return 1
	wire "$c"
	echo "$dev"
}

case "${1:-status}" in
start)
	out=${2:-1}
	sf=${3:-/usr/share/soundfonts/default.sf2}
	[ -f "$sf" ] || sf=/media/debaz/soundfonts/$sf
	[ -f "$sf" ] || { echo "dzsynth: no soundfont $sf" >&2; exit 1; }
	[ -n "$(pid)" ] && { echo "dzsynth: runs already (pid $(pid)); stop first" >&2; exit 1; }
	: > $LOG
	dev=$(launch "$out" "$sf" "${4:-0}") || { echo "dzsynth: fluidsynth did not start:" >&2; cat $LOG >&2; exit 1; }
	# the watcher: the output's PCM must stay RUNNING while fluidsynth lives
	setsid sh "$0" watch "$out" "$sf" "${4:-0}" > /dev/null 2>&1 < /dev/null &
	echo $! > $WPID
	echo "dzsynth: pid $(pid), client $(client), out $dev, $sf (watcher $(cat $WPID))"
	;;
watch)		# internal: watch out sf fx
	out=$2 sf=$3 fxon=$4 bad=0
	st=/proc/asound/DEBAZ/pcm${out}p/sub0/status
	while :; do
		sleep 2
		p=$(pid)
		[ -n "$p" ] || exit 0			# stopped (dzsynth.sh stop): done
		if grep -q "^state: RUNNING" $st 2>/dev/null; then bad=0; continue; fi
		bad=$((bad + 1))
		[ $bad -ge 2 ] || continue
		echo "dzsynth: $(date +%T) PCM of out $out not running: restarting fluidsynth" >> $LOG
		kill "$p"; sleep 1; [ -n "$(pid)" ] && kill -9 "$(pid)"
		# a debazd restart: wait for it (it opens the tap FIFOs at its first
		# frame), so the synth goes back on the tap and stays analysed
		for i in $(seq 1 30); do
			pgrep -x debazd > /dev/null && [ -n "$(ls -l /proc/$(pgrep -x debazd | head -1)/fd 2>/dev/null | grep dztap.$out)" ] && break
			sleep 0.5
		done
		dev=$(launch "$out" "$sf" "$fxon") && echo "dzsynth: restarted on $dev" >> $LOG
		bad=0
	done
	;;
stop)
	[ -f $WPID ] && kill "$(cat $WPID)" 2>/dev/null; rm -f $WPID
	p=$(pid)
	[ -n "$p" ] && kill "$p" && echo "dzsynth: stopped $p" || echo "dzsynth: not running"
	;;
status)
	p=$(pid)
	[ -n "$p" ] && echo "dzsynth: pid $p, watcher $(cat $WPID 2>/dev/null)" && aconnect -l | grep -A1 "debaz-synth" || echo "dzsynth: not running"
	;;
*) sed -n '2,28p' "$0"; exit 2 ;;
esac

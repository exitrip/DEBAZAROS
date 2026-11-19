#!/bin/sh
# dzsynth.sh - fluidsynth as the units' General MIDI synth (2026-11-20).
# Audio to the DEBAZ ALSA card (HDMI 0 / HDMI 1 / I2S), MIDI in from the ALSA
# sequencer; the four VirMIDI ports (card 1, /dev/snd/midiC1D0..3 = clients
# 20-23) are connected to it, so a Lua script that writes raw MIDI to
# /dev/snd/midiC1D0 (template midi-io) plays it.
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
set -u
LOG=/tmp/dzsynth.log
pid() { pgrep -x fluidsynth | head -1; }
case "${1:-status}" in
start)
	out=${2:-1}
	sf=${3:-/usr/share/soundfonts/default.sf2}
	[ -f "$sf" ] || sf=/media/debaz/soundfonts/$sf
	[ -f "$sf" ] || { echo "dzsynth: no soundfont $sf" >&2; exit 1; }
	fx="-R 0 -C 0"
	[ "${4:-0}" = 1 ] && fx="-R 1 -C 1"
	[ -n "$(pid)" ] && { echo "dzsynth: runs already (pid $(pid)); stop first" >&2; exit 1; }
	# shellcheck disable=SC2086
	setsid nohup fluidsynth -i -s $fx -a alsa -m alsa_seq -o audio.alsa.device=hw:DEBAZ,$out \
		-o synth.cpu-cores=2 -o midi.alsa_seq.id=debaz-synth -r 48000 -g 0.6 "$sf" \
		> $LOG 2>&1 < /dev/null &
	for i in 1 2 3 4 5 6 7 8 9 10; do
		c=$(aconnect -l | sed -n 's/^client \([0-9]*\): .FLUID Synth (debaz-synth).*/\1/p')
		[ -n "$c" ] && break
		sleep 0.3
	done
	[ -n "$c" ] || { echo "dzsynth: fluidsynth did not start:" >&2; cat $LOG >&2; exit 1; }
	for v in 20 21 22 23; do aconnect $v:0 $c:0 2>/dev/null; done
	echo "dzsynth: pid $(pid), client $c, out hw:DEBAZ,$out, $sf"
	;;
stop)
	p=$(pid)
	[ -n "$p" ] && kill "$p" && echo "dzsynth: stopped $p" || echo "dzsynth: not running"
	;;
status)
	p=$(pid)
	[ -n "$p" ] && echo "dzsynth: pid $p" && aconnect -l | grep -A1 "debaz-synth" || echo "dzsynth: not running"
	;;
*) sed -n '2,20p' "$0"; exit 2 ;;
esac

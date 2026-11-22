#!/bin/sh
# dzsynth.sh - the units' General MIDI synth (2026-11-20; dzaudio 2026-11-21).
# Starts dzaudio (sw/dzaudio: ONE fluidsynth, each MIDI channel on its own
# stereo pair, a routing matrix to the outputs; OSC on UDP 9002) and wires
# MIDI to it from the ALSA sequencer: the four VirMIDI ports (card 1,
# /dev/snd/midiC1D0..3 = clients 20-23) and every running Lua script's MIDI
# port ("dzlua <slot>").
#
#   dzsynth.sh start [outs] [soundfont] [fx] [routing]
#              outs: comma list of DEBAZ outputs, default 0,1 = HDMI 0 + HDMI 1
#              (4 channels); 1 = HDMI 1 only; 3 = I2S (no hardware yet)
#              soundfont: default /usr/share/soundfonts/default.sf2 (TimGM6mb),
#              or a name in /media/debaz/soundfonts; fx: 1 = reverb + chorus
#              (about twice the CPU; default 0); routing: both (default),
#              split (MIDI 1-8 -> first output, 9-16 -> second), pair<N>
#   dzsynth.sh stop | status
#   Routing while it runs: dzctl -p 9002 /mix/route <in> <pair> [gain],
#   /mix/preset, /mix/routes, /mix/status (sw/README.md "dzaudio").
#   Run with sudo for real-time priority.
# Measured on the board (2026-11-20, fluidsynth, 48 kHz, 2 cores, fx off):
# idle ~7 % of a core, 8 piano notes 12 %, 20 string notes 67 %; fx on:
# 25 % / ~100 %.
# ⚠️ Each DEBAZ output has ONE owner: no movie audio, /audio/play or pcmplay
# on an output dzaudio holds (default: both HDMI outputs).
# debazd's copy (react source synth / auto, LFO shape audio, DDS scope, Lua
# audio.*): dzaudio writes /tmp/dztap.<n> itself (no asound.conf tap) and
# follows debazd restarts and lost outputs by itself: no watcher.
# Without dzaudio (older software) the old way: the fluidsynth program on
# ONE output (the first of outs) through the asound.conf tap + a watcher.
set -u
LOG=/tmp/dzsynth.log
WPID=/tmp/dzsynth.watch.pid
pid() { { pgrep -x dzaudio; pgrep -x fluidsynth; } | head -1; }
# programs: the dev copy in /home/ebaz/bin wins (sw/lib/dz_path.h), else the image
D=${DZ_BIN:-/home/ebaz/bin}; [ -x "$D/dzaudio" ] || D=/usr/bin
DZCTL=$D/dzctl; [ -x "$DZCTL" ] || DZCTL=dzctl
client() { aconnect -l | sed -n 's/^client \([0-9]*\): .FLUID Synth (debaz-synth).*/\1/p' | head -1; }

# connect VirMIDI 1-0..3 and every "dzlua <slot>" / "dzlua <slot> panic" port
wire() {
	c=$1
	for v in 20 21 22 23; do aconnect $v:0 $c:0 2>/dev/null; done
	for d in $(aconnect -l | sed -n "s/^client \([0-9]*\): 'dzlua .*/\1/p"); do
		aconnect $d:0 $c:0 2>/dev/null
	done
}

# wait for the sequencer client, wire it
wired() {
	c=
	for i in 1 2 3 4 5 6 7 8 9 10; do
		c=$(client)
		[ -n "$c" ] && break
		sleep 0.3
	done
	[ -n "$c" ] || return 1
	wire "$c"
}

launch_dzaudio() {	# outs sf fx routing -> dzaudio running, wired
	f=
	[ "$3" = 1 ] && f=-f
	setsid nohup "$D/dzaudio" -o "$1" -s "$2" $f -r "${4:-both}" >> $LOG 2>&1 < /dev/null &
	wired
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
	wired || return 1
	echo "$dev"
}

case "${1:-status}" in
start)
	outs=${2:-0,1}
	sf=${3:-/usr/share/soundfonts/default.sf2}
	[ -f "$sf" ] || sf=/media/debaz/soundfonts/$sf
	[ -f "$sf" ] || { echo "dzsynth: no soundfont $sf" >&2; exit 1; }
	[ -n "$(pid)" ] && { echo "dzsynth: runs already (pid $(pid)); stop first" >&2; exit 1; }
	: > $LOG
	if [ -x "$D/dzaudio" ]; then
		launch_dzaudio "$outs" "$sf" "${4:-0}" "${5:-both}" ||
			{ echo "dzsynth: dzaudio did not start:" >&2; cat $LOG >&2; exit 1; }
		echo "dzsynth: dzaudio pid $(pid), client $(client), outs $outs, $sf"
		exit 0
	fi
	out=${outs%%,*}
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
	if [ -n "$p" ] && pgrep -x dzaudio > /dev/null; then
		echo "dzsynth: dzaudio pid $p"
		$DZCTL -p 9002 -t 1000 /mix/status
		$DZCTL -p 9002 -t 1000 /mix/routes
		aconnect -l | grep -A1 "debaz-synth"
	elif [ -n "$p" ]; then
		echo "dzsynth: fluidsynth pid $p, watcher $(cat $WPID 2>/dev/null)"; aconnect -l | grep -A1 "debaz-synth"
	else
		echo "dzsynth: not running"
	fi
	;;
*) sed -n '2,31p' "$0"; exit 2 ;;
esac

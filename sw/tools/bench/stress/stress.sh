#!/bin/bash
# stress.sh - unattended stress tests of a bench board from the laptop
# (2026-11-22). One phase per call; every phase samples the board every 30 s
# (sample.sh: memory, debazd RSS / CPU / tick and OSC times, ping, video
# events, log errors, dzaudio xruns / streams, restarts, taint, dmesg) and,
# with a USB capture of one board output, whether the picture still changes.
#
#   bash stress.sh setup                 push sample.sh, save the board state
#   bash stress.sh <phase> [minutes]     run one phase (load + sampling)
#   bash stress.sh restore               replay the saved state, stop the load
#   bash stress.sh report                summary of all phases so far
#
# Phases: idle, show (2 movies, paint ops, ASCII, slit, Lua, crop LFO),
# lfo (16 LFOs: 1024-step sequencers on a clock chain, field and draw
# targets), combo (show + lfo), cues (a looping show of 4 auto-follow cues),
# audio (dzaudio + movie audio streams + /audio/play + Lua MIDI), flood (OSC
# message flood + ping latency), restart (debazd restarts under load), modes
# (output mode switches; only while the capture has NO input), reboot (soft
# reboots), power (USB-C power cycles: the last phase, it can hurt the SD).
#
# Environment: DZ_BOARD (ebaz@10.42.0.236), DZ_STRESS_DIR (~/debaz-stress/
# <date>), DZ_CAPDEV (/dev/video4; "" = no picture check).
set -u
BOARD=${DZ_BOARD:-ebaz@10.42.0.236}
IP=${BOARD#*@}
HERE=$(cd "$(dirname "$0")" && pwd)
OUT=${DZ_STRESS_DIR:-$HOME/debaz-stress/$(date +%Y%m%d)}
CAP=${DZ_CAPDEV-/dev/video4}
mkdir -p "$OUT"
O=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=5)
sb() { sshpass -p "${DZ_PASS:-}" ssh "${O[@]}" "$BOARD" "$@"; }
d() { sb "dzctl -t 0 $*" >/dev/null 2>&1; }			# fire and forget (one ssh per call)
dz() { sb "$(printf 'dzctl -t 0 %s >/dev/null 2>&1; ' "$@")"; }	# many messages, one ssh
log() { echo "$(date '+%F %T') $*" | tee -a "$OUT/stress.log"; }

# ---- picture check (USB capture of one board output) ----
pic() {	# -> "mean diff" (luma 0..255 of a 64x36 frame, mean abs diff to the last)
	[ -n "$CAP" ] && [ -e "$CAP" ] || { echo "- -"; return; }
	timeout 15 ffmpeg -v error -f v4l2 -i "$CAP" -frames:v 1 -vf scale=64:36,format=gray \
		-f rawvideo -y "$OUT/.pic.new" 2>/dev/null || { echo "nocap -"; return; }
	python3 - "$OUT/.pic.new" "$OUT/.pic.old" <<'PY'
import sys, os
a = open(sys.argv[1], "rb").read()
m = sum(a) / max(1, len(a))
d = "-"
if os.path.exists(sys.argv[2]):
    b = open(sys.argv[2], "rb").read()
    if len(b) == len(a): d = "%.1f" % (sum(abs(x - y) for x, y in zip(a, b)) / len(a))
os.replace(sys.argv[1], sys.argv[2])
print("%.1f %s" % (m, d))
PY
}

# ---- OSC round trip from the laptop (ms, or "timeout") ----
oscping() {
	python3 - "$IP" <<'PY'
import socket, sys, time
s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM); s.settimeout(2.0)
m = b"/ping\0\0\0,\0\0\0"
t0 = time.time(); s.sendto(m, (sys.argv[1], 9000))
try:
    while b"/pong" not in s.recv(65536): pass
    print("%.1f" % ((time.time() - t0) * 1000))
except socket.timeout: print("timeout")
PY
}

# ---- sampling loop: phase name, minutes, optional per-sample hook ----
monitor() {
	local name=$1 mins=$2 hook=${3:-} end n=0 s p down=0
	end=$(( $(date +%s) + mins * 60 ))
	while [ "$(date +%s)" -lt "$end" ]; do
		s=$(sb "sh /home/ebaz/stress/sample.sh" 2>/dev/null)
		if [ -z "$s" ]; then
			down=$((down + 1))
			log "$name: NO ANSWER from the board ($down)"
			if [ $down -ge 6 ]; then	# 3 min: try to get it back
				log "$name: board gone for 3 min: boardpower reboot -S"
				bash "$HERE/../../boardpower.sh" reboot -S >> "$OUT/stress.log" 2>&1
				down=0
			fi
		else
			down=0
		fi
		p=$(pic)
		echo "phase=$name n=$n pic=${p// /,} ping_ms=$(oscping) $s" >> "$OUT/samples.txt"
		[ -n "$hook" ] && $hook "$n"
		n=$((n + 1))
		sleep 25
	done
}

# ---- loads ----
MOV1=wavefarmsky.mkv MOV2=frac.mkv MOV3=Shape-Shifter.mkv MOV4=2frac.mkv
show_start() {
	dz /movie/6/loop\ 1 "/movie/6/play $MOV1 0 0" /movie/5/loop\ 1 "/movie/5/play $MOV2 0 1" \
	   /disp/0/show\ 6 /disp/1/show\ 9 "/draw/9/clear 20 20 40" \
	   "/ascii/8/cols 160" "/ascii/8/mode ascii" "/ascii/8/run 6" \
	   "/slit/7/mode col" "/slit/7/speed 250" "/slit/7/band 16" "/slit/7/run 6" \
	   "/lua/10/start fb-plasma"
	# paint ops on slot 9, every second, on the board (one ssh for the whole phase)
	sb "nohup sh -c 'n=0; while [ ! -e /tmp/stress.stop ]; do n=\$((n+1));
	  dzctl -t 0 /draw/9/rect \$((n*37%255)) \$((n*91%255)) 128 \$((n*53%1700)) \$((n*29%900)) 200 150;
	  dzctl -t 0 /draw/9/brush 255 \$((n*13%255)) 0 \$((n*71%1900)) \$((n*47%1060)) 30 0.6;
	  dzctl -t 0 /draw/9/text 255 255 0 \$((n*17%1500)) \$((n*31%1000)) S-\$n 3;
	  dzctl -t 0 /draw/9/ttf 0 255 255 \$((n*23%1400)) \$((n*41%900)) 48 \"stress \$n\" 0.0;
	  [ \$((n%5)) = 0 ] && dzctl -t 0 /draw/9/fade 0.15;
	  [ \$((n%10)) = 0 ] && dzctl -t 0 /surface/9/grab 6;
	  sleep 1; done' > /dev/null 2>&1 &"
}
show_stop() {
	sb "touch /tmp/stress.stop; sleep 2; rm -f /tmp/stress.stop"
	dz "/ascii/8/run -1" /slit/7/stop /lua/10/stop /movie/6/stop /movie/5/stop
}
lfo_start() {	# 16 LFOs; 0-3 1024-step sequencers on a clock chain
	local seq k
	for k in 0 1 2 3; do
		seq=$(awk -v s=$k 'BEGIN { srand(s + 7); for (i = 0; i < 1024; i++) printf "%s%.3f", i ? " " : "", rand() }')
		sb "dzctl -t 0 /lfo/$k/seq \"$seq\"" >/dev/null 2>&1
	done
	dz "/lfo/0/step bpm 140 4" "/lfo/1/step clock 0" "/lfo/2/step clock 1" "/lfo/3/step frames 3" \
	   "/lfo/0/ease smooth" "/lfo/0/glide 0.5" "/lfo/1/ease linear" "/lfo/1/glide 1" \
	   "/lfo/0/range 0 255" "/lfo/0/target /hdmi/1/feedback/r" \
	   "/lfo/1/range 0 255" "/lfo/1/target /hdmi/1/feedback/g" \
	   "/lfo/2/range 0 640" "/lfo/2/target /disp/0/crop/x" "/lfo/2/every change" \
	   "/lfo/3/range 0 65535" "/lfo/3/target /mixer/8/gain/4" \
	   "/lfo/4/rate 0.3" "/lfo/4/range 0 255" "/lfo/4/target /hdmi/0/gain/r" \
	   "/lfo/5/shape tri" "/lfo/5/rate 0.21" "/lfo/5/range 0 255" "/lfo/5/target /hdmi/0/gain/b" \
	   "/lfo/6/shape smooth" "/lfo/6/rate 2" "/lfo/6/range 1 2000" "/lfo/6/target /dds/1/hz" \
	   "/lfo/7/shape square" "/lfo/7/frames 7" "/lfo/7/range 0 65535" "/lfo/7/target /mixer/8/gain/3" \
	   "/lfo/8/rate 0.31" "/lfo/8/range 100 1800" "/lfo/9/rate 0.47" "/lfo/9/range 80 1000" \
	   "/lfo/10/rate 0.13" "/lfo/10/range 0 255" \
	   "/lfo/10/target \"/draw/3/brush 255 \\\$10 40 \\\$8 \\\$9 24 0.5\"" \
	   "/lfo/11/target \"/draw/3/fade 0.1\"" "/lfo/11/every 6" \
	   "/lfo/12/seq \"0 0.5 1 0.25\"" "/lfo/12/step frames 20" "/lfo/12/range 0 3" \
	   "/lfo/12/target \"/ascii/8/every \\\$12\"" "/lfo/12/every step" \
	   "/lfo/13/shape noise" "/lfo/13/range 0 65535" "/lfo/13/target /mixer/8/gain/2" \
	   "/lfo/14/shape random" "/lfo/14/rate 3" "/lfo/14/range 0 360" "/lfo/14/target \"/fx/hue/deg \\\$f14\"" "/lfo/14/every 4" \
	   "/lfo/15/rate 5" "/lfo/15/range 0 1" "/lfo/15/target \"/draw/3/alpha \\\$f15\"" \
	   "/lfo/[0-9]/on 1" "/lfo/1[0-5]/on 1"
}
lfo_stop() { dz "/lfo/[0-9]/on 0" "/lfo/1[0-5]/on 0"; }

cues_start() {
	dz "/show/new stress" "/scene/add s"
	dz "/movie/6/loop 1" "/movie/6/play $MOV2 0 1" "/disp/0/show 6" "/disp/1/show 9" "/img/9/file flyer-addy.png" "/cue/record s 1 keyframe one"
	sleep 2
	dz "/movie/6/play $MOV3 0 1" "/img/9/file paint-performances.png" "/lfo/4/on 1" "/cue/record s 2 keyframe two"
	sleep 2
	dz "/movie/6/stop" "/lua/10/start sprite-bounce" "/disp/0/show 10" "/img/9/file flyer-date-time.png" "/cue/record s 3 keyframe three"
	sleep 2
	dz "/lua/10/stop" "/movie/6/play $MOV4 0 2" "/disp/0/show 6" "/disp/1/show 2" "/lfo/4/on 0" "/cue/record s 4 keyframe four"
	dz "/cue/follow s 1 4" "/cue/follow s 2 3" "/cue/follow s 3 5" "/cue/follow s 4 2" \
	   "/cue/fade s 2 1 smooth fade" "/cue/fade s 4 0.5 linear dip" "/scene/loop s 1" "/show/save" "/cue/go s 1"
}
cues_stop() { dz /cue/stop /lua/10/stop /movie/6/stop; }

audio_start() {
	sb "sudo dzsynth.sh start >/dev/null 2>&1; ffmpeg -v error -y -f lavfi -i 'sine=f=1800:d=20' -ac 2 -ar 48000 /media/debaz/audio/stress1800.wav"
	sleep 3
	dz "/movie/5/loop 1" "/movie/5/play $MOV2 0 1" "/movie/6/loop 1" "/movie/6/play $MOV3 0 2" \
	   "/disp/0/show 6" "/disp/1/show 5" "/audio/play 0 stress1800.wav 1" "/lua/1/start midi-arp"
}
audio_stop() {
	dz "/audio/stop 0" /lua/1/stop /movie/5/stop /movie/6/stop
	sb "sudo dzsynth.sh stop >/dev/null 2>&1; rm -f /media/debaz/audio/stress1800.wav"
}

# ---- phases ----
phase() {
	local name=$1 mins=$2
	log "=== $name ($mins min) start"
	echo "phase=$name start=$(date +%s)" >> "$OUT/phases.txt"
	case $name in
	idle)    monitor idle "$mins" ;;
	show)    show_start; monitor show "$mins"; show_stop ;;
	lfo)     lfo_start; monitor lfo "$mins"; lfo_stop ;;
	combo)   show_start; lfo_start; monitor combo "$mins"; lfo_stop; show_stop ;;
	cues)    cues_start; monitor cues "$mins"; cues_stop ;;
	audio)   audio_start; monitor audio "$mins"; audio_stop ;;
	flood)   flood "$mins" ;;
	restart) show_start; monitor restart "$mins" restart_hook; show_stop ;;
	modes)   modes "$mins" ;;
	reboot)  reboots soft "${3:-5}" ;;
	power)   reboots hard "${3:-3}" ;;
	*) echo "unknown phase $name"; exit 2 ;;
	esac
	echo "phase=$name end=$(date +%s)" >> "$OUT/phases.txt"
	log "=== $name end"
}

restart_hook() {	# every 2nd sample (~1 min): restart debazd, time the way back
	[ $(($1 % 2)) = 1 ] || return 0
	local t0 t1
	t0=$(date +%s%N)
	sb "sudo systemctl restart debazd"
	for _ in $(seq 1 60); do
		sb "dzctl -t 500 /ping" 2>/dev/null | grep -q pong && break
		sleep 0.5
	done
	t1=$(date +%s%N)
	log "restart: debazd answers $(( (t1 - t0) / 1000000 )) ms after the restart; movies $(sb 'pidof ffmpeg | wc -w')"
}

flood() {	# OSC flood from the laptop at rising rates, ping latency each step
	local mins=$1
	python3 - "$IP" "$mins" "$OUT/flood.txt" <<'PY' | tee -a "$OUT/stress.log"
import socket, struct, sys, time, statistics
ip, mins, out = sys.argv[1], float(sys.argv[2]), sys.argv[3]
def pad(b): return b + b"\0" * (4 - len(b) % 4)
def msg(path, *ints):
    return pad(path.encode()) + pad(("," + "i" * len(ints)).encode()) + b"".join(struct.pack(">i", v) for v in ints)
s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM); s.setblocking(False)
p = socket.socket(socket.AF_INET, socket.SOCK_DGRAM); p.settimeout(1.0)
rates = [100, 500, 1000, 2000, 4000]
per = mins * 60 / len(rates)
f = open(out, "a")
for r in rates:
    t_end = time.time() + per; sent = 0; rtt = []; lost = 0; nxt = time.time(); nping = time.time()
    while time.time() < t_end:
        now = time.time()
        while nxt <= now:
            try: s.sendto(msg("/mixer/8/gain/4", sent % 65536), (ip, 9000)); sent += 1
            except BlockingIOError: pass
            nxt += 1.0 / r
        if now >= nping:
            t0 = time.time(); p.sendto(msg("/ping"), (ip, 9000))
            try:
                while True:
                    d, _ = p.recvfrom(65536)
                    if b"/pong" in d: rtt.append((time.time() - t0) * 1000); break
            except socket.timeout: lost += 1
            nping = time.time() + 0.1
        time.sleep(0.0005)
    try: s.recv(65536)
    except Exception: pass
    q = sorted(rtt) or [float("nan")]
    line = "flood %5d msg/s: sent %6d, ping n=%d lost=%d p50=%.1f p99=%.1f max=%.1f ms" % (
        r, sent, len(rtt), lost, statistics.median(q), q[int(len(q) * 0.99) - 1 if len(q) > 1 else 0], q[-1])
    print(line); f.write(line + "\n"); f.flush()
PY
	sb "sh /home/ebaz/stress/sample.sh" | sed 's/^/phase=flood /' >> "$OUT/samples.txt"
}

modes() {	# output mode switches (refused while the capture has an input)
	local mins=$1 end k=0 m list
	if sb "dzctl -t 500 /capture/status" | awk '{exit !($2 > 0)}'; then
		log "modes: the capture has an input: SKIPPED (CLAUDE.md: no mode switch while it streams)"
		return
	fi
	list="1280x720 1024x768 640x480 800x600 1280x720x30Hz 1920x1080x30Hz 1280x1024 1280x720"
	end=$(( $(date +%s) + mins * 60 ))
	show_start
	while [ "$(date +%s)" -lt "$end" ]; do
		for m in $list; do
			k=$((k + 1))
			d "/video/mode $m"
			sleep 12
			log "modes: $k $m -> $(sb 'dzctl -t 1000 /video/mode' | cut -d' ' -f2-5) events $(sb 'journalctl -u debazd --since -13s -o cat | grep -c "VIDEO "')"
			echo "phase=modes n=$k mode=$m pic=$(pic | tr ' ' ,) $(sb 'sh /home/ebaz/stress/sample.sh')" >> "$OUT/samples.txt"
		done
	done
	d "/video/mode 1280x720"; sleep 8
	show_stop
}

reboots() {	# soft | hard, count
	local how=$1 n=$2 k t0 ok
	for k in $(seq 1 "$n"); do
		t0=$(date +%s)
		if [ "$how" = soft ]; then
			sb "sudo reboot" >/dev/null 2>&1
			sleep 15
			bash "$HERE/../../boardpower.sh" wait-up 240 >> "$OUT/stress.log" 2>&1
		else
			bash "$HERE/../../boardpower.sh" reboot -H >> "$OUT/stress.log" 2>&1
		fi
		ok=0
		for _ in $(seq 1 30); do	# services up and debazd answering
			sb "systemctl is-active debazd dzweb | grep -c '^active' | grep -q 2 && dzctl -t 800 /ping | grep -q pong" 2>/dev/null && { ok=1; break; }
			sleep 5
		done
		log "$how reboot $k/$n: $([ $ok = 1 ] && echo OK || echo FAILED) after $(( $(date +%s) - t0 )) s; $(sb 'uptime; dzctl -t 800 /video/mode; dmesg | grep -ciE "error|fail"' 2>/dev/null | tr '\n' ' ')"
		echo "phase=$how-reboot n=$k ok=$ok secs=$(( $(date +%s) - t0 )) $(sb 'sh /home/ebaz/stress/sample.sh' 2>/dev/null)" >> "$OUT/samples.txt"
		[ $ok = 1 ] || { log "$how reboot: board not back: STOP"; return 1; }
		sleep 20
	done
}

report() {
	python3 - "$OUT" <<'PY'
import sys, re, collections
out = sys.argv[1]
rows = collections.OrderedDict()
for line in open(out + "/samples.txt"):
    kv = dict(re.findall(r"(\w+)=(\S+)", line))
    rows.setdefault(kv.get("phase", "?"), []).append(kv)
def num(x):
    try: return float(x)
    except: return None
print("%-12s %4s %9s %9s %7s %8s %8s %8s %8s %6s %6s %6s %5s %7s" % ("phase", "n", "avail MB", "dzd RSS", "dzd/all%", "tick max", "osc max", "pix max", "ping ms", "vidEv", "logErr", "xruns", "pic", "restrt"))
for ph, r in rows.items():
    av = [num(k.get("avail_kb")) for k in r if num(k.get("avail_kb"))]
    rss = [num(k.get("dzd_rss")) for k in r if num(k.get("dzd_rss"))]
    st = [k.get("stats", "-").split(",") for k in r]
    # stats = debazd_cpu, cpu_total, tick_max, osc_max, pix_max, pix_queue
    tick = [num(s[2]) for s in st if len(s) > 4 and num(s[2]) is not None]
    osc = [num(s[3]) for s in st if len(s) > 4 and num(s[3]) is not None]
    # CPU % of one core from /proc deltas between samples (debazd, whole board)
    cpu, tot = [], []
    for a, b in zip(r, r[1:]):
        try:
            dt = float(b["t"]) - float(a["t"])
            cpu.append((float(b["dzd_ticks"]) - float(a["dzd_ticks"])) / dt)   # ticks = 1/100 s
            ba, bb = [float(x) for x in a["cpu_busy_all"].split(",")], [float(x) for x in b["cpu_busy_all"].split(",")]
            tot.append((bb[0] - ba[0]) / (bb[1] - ba[1]) * 200.0)
        except (KeyError, ValueError, ZeroDivisionError):
            pass
    pix = [num(s[4]) for s in st if len(s) > 4 and num(s[4]) is not None]
    ping = [num(k.get("ping_ms")) for k in r if num(k.get("ping_ms")) is not None]
    to = sum(1 for k in r if k.get("ping_ms") == "timeout")
    ev = sum(int(num(k.get("video_ev")) or 0) for k in r)
    er = sum(int(num(k.get("log_err")) or 0) for k in r)
    xr = [num(k.get("xruns")) for k in r if num(k.get("xruns")) is not None]
    pics = [k.get("pic", "-").split(",") for k in r]
    still = sum(1 for p in pics if len(p) == 2 and num(p[1]) is not None and num(p[1]) < 0.5)
    rs = [k.get("restarts") for k in r]
    f = lambda a, g: ("%.0f" % g(a)) if a else "-"
    print("%-12s %4d %4s-%-4s %4s-%-4s %7s %8s %8s %8s %8s %6d %6d %6s %5s %7s" % (ph, len(r),
        f([a / 1024 for a in av], min), f([a / 1024 for a in av], max), f([a / 1024 for a in rss], min), f([a / 1024 for a in rss], max),
        ("%.0f/%.0f" % (sum(cpu) / len(cpu), sum(tot) / len(tot))) if cpu and tot else "-",
        ("%.1f" % max(tick)) if tick else "-", ("%.1f" % max(osc)) if osc else "-", ("%.0f" % max(pix)) if pix else "-",
        (("%.0f" % max(ping)) if ping else "-") + ("/%dTO" % to if to else ""), ev, er,
        ("%.0f" % (max(xr) - min(xr))) if xr else "-", "%d st" % still, "%s>%s" % (rs[0], rs[-1]) if rs else "-"))
PY
	[ -f "$OUT/flood.txt" ] && cat "$OUT/flood.txt"
	grep -E "FAILED|NO ANSWER|STOP|gone|SKIPPED" "$OUT/stress.log" | tail -20
}

case ${1:-} in
setup)
	# keep the first saved state of the day: a second setup must not overwrite it
	[ -f "$OUT/state-before.json" ] && cp -n "$OUT/state-before.json" "$OUT/state-first.json"
	sb "mkdir -p /home/ebaz/stress"
	sshpass -p "${DZ_PASS:-}" scp "${O[@]}" "$HERE/sample.sh" "$BOARD:/home/ebaz/stress/sample.sh"
	python3 "$HERE/oscstate.py" save "$IP" "$OUT/state-before.json"
	sb "dzctl -t 1000 /cue/status" > "$OUT/cue-before.txt"
	sb "uname -a; uptime; md5sum /home/ebaz/bin/debazd /home/ebaz/bin/dzaudio; lsmod | grep dzmem" > "$OUT/board-before.txt"
	log "setup: $OUT ($(cat "$OUT/cue-before.txt"))" ;;
restore)
	lfo_stop; show_stop; cues_stop
	sb "pidof dzaudio >/dev/null && sudo dzsynth.sh stop >/dev/null 2>&1; rm -f /media/debaz/audio/stress1800.wav"
	# replay only on request: after the reboot / power phases the board is in
	# its boot state, and a state saved by a second "setup" is not the one
	# from before the tests (2026-11-22: it replayed the smoke tests' state)
	if [ "${DZ_STRESS_REPLAY:-0}" = 1 ]; then
		show=$(awk -F'"' '{print $2}' "$OUT/cue-before.txt")
		[ -n "$show" ] && d "/show/load $show"
		python3 "$HERE/oscstate.py" replay "$IP" "$OUT/state-before.json"
		log "restore: show $show, state replayed"
	else
		log "restore: loads stopped (no replay: DZ_STRESS_REPLAY=1 replays $OUT/state-before.json)"
	fi ;;
report) report ;;
"") sed -n '2,24p' "$0"; exit 2 ;;
*) phase "$1" "${2:-10}" "${3:-}" ;;
esac

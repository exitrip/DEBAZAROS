#!/bin/sh
# selftest.sh - host test of debazd + dzctl with simulated hardware.
#   sh tools/selftest.sh out/native
# Exit 0 = all checks passed.
set -u
BIN=${1:-out/native}
PORT=19123
FAIL=0
LOCKDIR=$(mktemp -d)
export DZ_SHOW_DIR="$LOCKDIR/shows"	# fresh shows every run (a saved show of an
					# earlier run made /show/save refuse: stale load)
mkdir -p "$DZ_SHOW_DIR"
# /video/mode starts this instead of hdmi2.elf: it writes its arguments
printf '#!/bin/sh\necho "$@" > %s/hdmi2.args\n' "$LOCKDIR" > "$LOCKDIR/hdmi2.elf"
chmod +x "$LOCKDIR/hdmi2.elf"
export DZ_HDMI2="$LOCKDIR/hdmi2.elf"
# /audio/react/source capture reads this instead of arecord: 2 s of 100 Hz,
# then 2 s of 5 kHz, then silence (48 kHz s16 stereo, real time)
cat > "$LOCKDIR/tone.py" <<'PYEOF'
import math, struct, sys, time
o = sys.stdout.buffer
for f in (100.0, 5000.0, 0.0):
    for blk in range(120):
        s = b"".join(struct.pack("<hh", v, v) for v in
                     (int(16000 * math.sin(2 * math.pi * f * (blk * 1200 + i) / 48000)) for i in range(1200)))
        o.write(s); o.flush(); time.sleep(0.025)
time.sleep(30)
PYEOF
export DZ_REACT_CMD="python3 $LOCKDIR/tone.py"
# /audio/rec runs this arecord (2 s, writes nothing): the capture hand-over test
printf '#!/bin/sh\nsleep 2\n' > "$LOCKDIR/arecord"; chmod +x "$LOCKDIR/arecord"
export PATH="$LOCKDIR:$PATH"

# image sequences (anim.c): small JPEG / PNG frames made with ffmpeg
export DZ_ANIM_DIR="$LOCKDIR/anim"
HAVE_FF=0
if command -v ffmpeg >/dev/null 2>&1; then
	HAVE_FF=1
	mkdir -p "$DZ_ANIM_DIR/seq" "$DZ_ANIM_DIR/sheet"
	for i in 1 2 3 4 5 6 7 8; do
		ffmpeg -v error -f lavfi -i "color=c=0x$((i + 1))04080:s=320x180" -frames:v 1 "$DZ_ANIM_DIR/seq/f$i.jpg"
	done
	cp "$DZ_ANIM_DIR/seq/f1.jpg" "$DZ_ANIM_DIR/sheet/a.jpg"
	ffmpeg -v error -f lavfi -i "color=c=0xff0000:s=640x360" -frames:v 1 "$DZ_ANIM_DIR/sheet/b.png"
	printf '# fps 5\na.jpg 2\nb.png\n' > "$DZ_ANIM_DIR/sheet/timing.txt"
fi

"$BIN/debazd" -n -p $PORT 2>"$LOCKDIR/log" &
PID=$!
trap 'kill $PID 2>/dev/null; rm -rf "$LOCKDIR"' EXIT
sleep 0.3

q() { "$BIN/dzctl" -p $PORT -t 200 "$@"; }

near() {	# near "name" "r g b" command... (a /pixel reply, each channel +-4: JPEG)
	name=$1; want=$2; shift 2
	got=$("$@" 2>&1)
	if echo "$got $want" | awk '{n = NF - 3; for (i = 0; i < 3; i++) { d = $(n - 2 + i) - $(NF - 2 + i); if (d > 4 || d < -4) exit 1 } }'; then
		echo "ok   $name"
	else
		echo "FAIL $name: want [$want] got [$got]"; FAIL=1
	fi
}

check() {	# check "name" "expected substring" command...
	name=$1; want=$2; shift 2
	got=$("$@" 2>&1)
	case "$got" in
	*"$want"*) echo "ok   $name" ;;
	*) echo "FAIL $name: want [$want] got [$got]"; FAIL=1 ;;
	esac
}

check ping        "/pong"                          q /ping
check info        "/info"                          q /info
check list-count  "/entry/end"                     q /list /hdmi/0
q /hdmi/0/gain/rgb 10 20 30 >/dev/null
# lanes: R [23:16], B [15:8], G [7:0] -> 10<<16 | 30<<8 | 20 = 663060
check rgb-lanes   "/value \"/hdmi/0/gain/rgb\" 663060" q /hdmi/0/gain/rgb
check green-lane  "/value \"/hdmi/0/gain/g\" 20"   q /hdmi/0/gain/g
check blue-lane   "/value \"/hdmi/0/gain/b\" 30"   q /hdmi/0/gain/b
q /hdmi/0/osc/sin/div 1 >/dev/null
check rmw-keeps   "/value \"/hdmi/0/gain/r\" 10"   q /hdmi/0/gain/r
check div-set     "/value \"/hdmi/0/osc/sin/div\" 1" q /hdmi/0/osc/sin/div
q /dds/0/pinc 2577 >/dev/null
check dds-enable  "/value \"/dds/0/enable\" 1"     q /dds/0/enable
check dds-pinc    "/value \"/dds/0/pinc\" 2577"    q /dds/0/pinc
q /dds/0/enable 0 >/dev/null
check dds-off     "/value \"/dds/0/enable\" 0"     q /dds/0/enable
check dds-pinc-kept "/value \"/dds/0/pinc\" 2577"  q /dds/0/pinc
check read-only   "read only"                      q /io/raw 1
check wildcard    "/value \"/mixer/8/mode\""       q "/mixer/[0-8]/mode"
q "/mixer/*/mode" 35 >/dev/null
check wild-set    "/value \"/mixer/4/mode\" 35"    q /mixer/4/mode
check no-addr     "no such address"                q /nothing/here
# signed mixer gains (coreRevision 25): g/<n> = gain/<n> [23:0], 1.0 = 0x10000
q /mixer/3/gain/2 0x12000000 >/dev/null
q /mixer/3/g/2 -1.5 >/dev/null
check sgain-raw   "/value \"/mixer/3/gain/2\" 318668800" q /mixer/3/gain/2	# 0x12FE8000: [31:24] kept
check sgain-float "/value \"/mixer/3/g/2\" 16678912 -1.5" q /mixer/3/g/2
q /mixer/3/g/2 500.0 >/dev/null
check sgain-clamp "/value \"/mixer/3/g/2\" 8388607 " q /mixer/3/g/2
q /mixer/3/g/2 -255 >/dev/null	# an int is the raw signed value (web Mixer table)
check sgain-int   "/value \"/mixer/3/g/2\" 16776961 " q /mixer/3/g/2	# 0xFFFF01
q /mixer/3/diff 1 >/dev/null
check mix-diff    "/value \"/mixer/3/diff\" 1"   q /mixer/3/diff
q /mixer/3/diff 0 >/dev/null; q /mixer/3/gain/2 0 >/dev/null
n=$(q /state | grep -c '/mixer/3/g/')
check sgain-state "state g aliases 0" echo "state g aliases $n"	# the dump keeps gain/<n> only
# --- /fx colour matrix and key (fx.c) ---
check fx-hue120   "/fx/matrix 0 0 0.999985 0.999985 0 0 0 0.999985 0" q /fx/hue 120
check fx-hue60    "/fx/matrix 0.5 0 0.5 0.5 0.5 0 0 0.5 0.5" q /fx/hue 60
check fx-rownorm  "/fx/matrix 0.334641 0.334641 0.334641" q /fx/matrix 1 1 1 0 1 0 0 0 1
check fx-chanmap  "/value \"/mixer/5/k\" 65535"   q /mixer/5/k
check fx-chanmap2 "/value \"/mixer/2/k\" 21931"   q /mixer/2/k
check fx-ident    "/fx/matrix 0.999985 0 0 0 0.999985 0 0 0 0.999985" q /fx/identity
# signed matrix (mode 5): exact hue at 60 degrees has negative terms
q /fx/signed 1 >/dev/null
check fx-s-hue60  "/fx/matrix 0.666672 -0.333328 0.666672 0.666672 0.666672 -0.333328 -0.333328 0.666672 0.666672" q /fx/hue 60 1
check fx-s-mode   "/value \"/mixer/0/mode\" 5"   q /mixer/0/mode
q /fx/hue/deg 0 >/dev/null
check fx-s-sat2   "/fx/matrix 1.66667 -0.333328 -0.333328" q /fx/hue/sat 2	# rows sum to 1
check fx-s-entry  "/fx/matrix 1.66667 -0.5 -0.333328 " q /fx/matrix/rg -0.5
q /fx/hue/sat 1 >/dev/null; q /fx/signed 0 >/dev/null
check fx-u-back   "/fx/matrix 0.999985 0 0 0 0.999985 0 0 0 0.999985" q /fx/hue 0 1
q /fx/key/color 0x00ff00 30 >/dev/null
# box (0,225,0)..(30,255,30): R = chan 0, G = chan 6, B = chan 3
check key-r-hi    "/value \"/mixer/0/hi\" 30 "      q /mixer/0/hi
check key-g-lo    "/value \"/mixer/6/lo\" 225 "     q /mixer/6/lo
check key-b-key   "/value \"/mixer/3/key\" 1"       q /mixer/3/key
check key-other   "/value \"/mixer/1/key\" 0"       q /mixer/1/key
check key-mode    "/value \"/mixer/0/mode\" 4"      q /mixer/0/mode
q /key/invert 1 >/dev/null
check key-invert  "/value \"/mixer/0/mode\" 4"      q /mixer/0/mode
q /fx/key/off >/dev/null
check key-off     "/value \"/mixer/6/key\" 0"       q /mixer/6/key
# --- HDMI_2 replug + 48 kHz rate setting (audio.c) ---
check replug      "/ok \"/capture/replug\""         q /capture/replug 0.3
check replug-low  "/value \"/hdmi/2/hpd_low\" 1"   q /hdmi/2/hpd_low
check audio-fs    "/audio/fs"                      q /audio/fs
# --- user I/O line functions (io.c) ---
check io-pin-name "/io/pin 2 \"mosi\""            q /io/pin 2 mosi
check io-pin-code "/value \"/io/func/2\" 5"       q /io/func/2
check io-pin-bad  "unknown function"               q /io/pin 2 nonsense
check io-pins     "/io/pins \"in\" \"in\" \"mosi\"" q /io/pins
q /io/pin 2 in >/dev/null
check io-pin-in   "/io/pins \"in\" \"in\" \"in\""   q /io/pins
check disp-show   "/disp/0 4 0 0"                  q /disp/0/show 4
check disp-blank  "/disp/0 4 1 0"                  q /disp/0/blank 1
check disp-toggle "/disp/0 4 0 0"                  q /disp/0/blank
check disp-seq    "/disp/1 -1 0 1"                 q /disp/1/seq 5 -1
check disp-seqoff "/disp/1 -1 0 0"                 q /disp/1/seq/stop
check disp-bad    "outside reserved"               q /disp/0/show 99
check vsync       "/vsync"                         q /vsync
check draw        ""                               q /draw/3/bars
check capture     "/capture/status"                q /capture/status
check snapshot    "/event/capture"                 timeout 1 "$BIN/dzctl" -p $PORT -w

# --- painter (peek reads the painting buffer) ---
q /draw/5/clear 0 0 0 >/dev/null
q /draw/5/brush 255 0 0 100 100 20 1 >/dev/null
check brush-hard   "/pixel 5 100 100 255 0 0"      q /surface/5/peek 100 100
check brush-out    "/pixel 5 100 125 0 0 0"        q /surface/5/peek 100 125
q /draw/5/brush 0 255 0 300 100 20 0 >/dev/null
check brush-soft0  "/pixel 5 300 100 0 255 0"      q /surface/5/peek 300 100
check brush-soft   "/pixel 5 310 100 0 127 0"      q /surface/5/peek 310 100
q /draw/5/line 255 255 255 0 200 50 200 >/dev/null
check line-thin    "/pixel 5 25 200 255 255 255"   q /surface/5/peek 25 200
check line-thin2   "/pixel 5 25 201 0 0 0"         q /surface/5/peek 25 201
q /draw/5/stroke 0 0 255 5 1 600 600 700 600 700 650 >/dev/null
check stroke-mid   "/pixel 5 650 600 0 0 255"      q /surface/5/peek 650 600
check stroke-turn  "/pixel 5 700 625 0 0 255"      q /surface/5/peek 700 625
q /draw/5/solid 100 0 0 390 390 20 20 >/dev/null
q /draw/5/blend add >/dev/null
q /draw/5/brush 100 0 0 400 400 5 1 >/dev/null
q /draw/5/blend normal >/dev/null
check blend-add    "/pixel 5 400 400 200 0 0"      q /surface/5/peek 400 400
q /draw/5/solid 200 200 200 >/dev/null
q /draw/5/fade 0.5 >/dev/null
check fade         "/pixel 5 0 0 100 100 100"      q /surface/5/peek 0 0
q /draw/4/solid 10 20 30 >/dev/null
q /surface/2/grab 4 >/dev/null
check grab         "/pixel 2 640 360 10 20 30"     q /surface/2/peek 640 360
check peek-bad     "bad surface"                   q /surface/2/peek 5000 0

# --- shapes: rotation, polygons, stars, gradient fills (dz_shape.c) ---
q /draw/7/clear >/dev/null
q /draw/7/square 255 0 0 540 260 200 0 45.0 >/dev/null
check rot-square    "/pixel 7 640 225 255 0 0"     q /surface/7/peek 640 225
check rot-corner    "/pixel 7 548 268 0 0 0"       q /surface/7/peek 548 268
q /draw/7/clear >/dev/null
q /draw/7/star 255 255 0 640 360 150 150 5 >/dev/null
check star-tip      "/pixel 7 640 216 255 255 0"   q /surface/7/peek 640 216
check star-gap      "/pixel 7 640 470 0 0 0"       q /surface/7/peek 640 470
q /draw/7/clear >/dev/null
q /draw/7/starpoly 255 0 255 640 360 150 150 5 2 >/dev/null
check pentagram-hole "/pixel 7 640 360 0 0 0"      q /surface/7/peek 640 360
check pentagram-tip "/pixel 7 640 220 255 0 255"   q /surface/7/peek 640 220
q /draw/7/clear >/dev/null
q /draw/7/fill radial 0 0 255 >/dev/null
q /draw/7/circle 255 0 0 640 360 200 >/dev/null
check radial-centre "/pixel 7 640 360 255 0 0"     q /surface/7/peek 640 360
check radial-mid    "/pixel 7 740 360 128 0 127"   q /surface/7/peek 740 360
q /draw/7/fill solid >/dev/null

# --- text (pixel font: 'A' row 2 = ..####.. -> x 2..5) ---
q /draw/7/clear 0 0 0 >/dev/null
q /draw/7/text 255 255 255 0 0 A 1 16 >/dev/null
check text-on      "/pixel 7 2 2 255 255 255"     q /surface/7/peek 2 2
check text-off     "/pixel 7 0 2 0 0 0"           q /surface/7/peek 0 2
q /draw/7/text 255 255 255 100 100 A 2 16 >/dev/null
check text-scale2  "/pixel 7 105 105 255 255 255" q /surface/7/peek 105 105
q /draw/7/ttf 255 255 255 300 300 48 Hello >/dev/null
check ttf-draw     ""                             q /surface/7/peek 0 0
# --- sprites ---
q /sprite/1/text 255 0 0 AB 1 16 >/dev/null
check sprite-size  "/sprite/1 16 16"              q /sprite/1
q /draw/8/clear 0 0 0 >/dev/null
q /sprite/1/draw 8 200 200 >/dev/null
check sprite-draw  "/pixel 8 194 194 255 0 0"     q /surface/8/peek 194 194
check sprite-alpha "/pixel 8 192 192 0 0 0"       q /surface/8/peek 192 192
q /sprite/2/ttf 255 255 255 32 Hi >/dev/null
check sprite-ttf   "/sprite/2 "                   q /sprite/2
check sprite-none  "no such sprite"               q /sprite/40
# --- transforms ---
q /draw/9/clear 0 0 0 >/dev/null
q /draw/9/solid 255 0 0 0 0 1 1 >/dev/null
q /draw/9/scroll 10 5 >/dev/null
check scroll       "/pixel 9 10 5 255 0 0"        q /surface/9/peek 10 5
q /draw/9/scroll -20 -10 >/dev/null
check scroll-wrap  "/pixel 9 1270 715 255 0 0"    q /surface/9/peek 1270 715
q /draw/10/clear 0 0 0 >/dev/null
q /draw/10/solid 0 255 0 0 0 1 1 >/dev/null
q /draw/10/mirror quad >/dev/null
check mirror-h     "/pixel 10 1279 0 0 255 0"     q /surface/10/peek 1279 0
check mirror-quad  "/pixel 10 1279 719 0 255 0"   q /surface/10/peek 1279 719
q /draw/10/clear 0 0 0 >/dev/null
q /draw/10/solid 0 0 255 10 0 1 1 >/dev/null
q /draw/10/transform 1 0 10 0 1 0 >/dev/null
check transform    "/pixel 10 0 0 0 0 255"        q /surface/10/peek 0 0
q /draw/9/rotozoom 0 1 9 >/dev/null
check rotozoom-id  "/pixel 9 1270 715 255 0 0"    q /surface/9/peek 1270 715
q /draw/10/wave 0 0 100 0 >/dev/null
check wave-zero    "/pixel 10 0 0 0 0 255"        q /surface/10/peek 0 0

# --- button bindings (active low: 1 -> 0 = press) ---
q /io/simulate 255 >/dev/null
sleep 0.1
q /io/press/2 "/draw/11/solid 9 8 7 0 0 4 4" >/dev/null
q /io/release/2 "/draw/11/solid 1 2 3 0 0 4 4" >/dev/null
q /io/simulate 251 >/dev/null
sleep 0.15
check io-press     "/pixel 11 0 0 9 8 7"          q /surface/11/peek 0 0
q /io/simulate 255 >/dev/null
sleep 0.15
check io-release   "/pixel 11 0 0 1 2 3"          q /surface/11/peek 0 0
check io-badbit    "bit must be"                   q /io/press/9 "/ping"

# --- LFOs: constant step value 0.2 in range 0..100 = 20 ---
q /lfo/0/seq 0.2 0.2 >/dev/null
q /lfo/0/range 0 100 >/dev/null
q /lfo/0/target /hdmi/0/gain/r >/dev/null
q /lfo/1/seq 0.5 >/dev/null
q /lfo/1/range 0 200 >/dev/null
q /lfo/1/target "/draw/6/solid \$0 \$1 7" >/dev/null
q /lfo/0/on 1 >/dev/null
q /lfo/1/on 1 >/dev/null
sleep 0.3
check lfo-value    "/lfo/0 20"                     q /lfo/0
check lfo-field    "/value \"/hdmi/0/gain/r\" 20" q /hdmi/0/gain/r
check lfo-template "/pixel 6 10 10 20 100 7"       q /surface/6/peek 10 10
check lfo-bad      "matches no field"              q /lfo/2/target nothing
q /lfo/reset >/dev/null
check lfo-reset    "/lfo/0 0 0"                    q /lfo/0

# video mode (disp.c): query, mode list, a restart of (fake) hdmi2 -r
check vmode-query  "/video/mode 1280 720"          q /video/mode
check vmode-list   "\"800x600\""                   q /video/modes
check vmode-bad    "unknown mode"                  q /video/mode 999x9
check vmode-set    "starting"                      q /video/mode 800x600
sleep 0.2
check vmode-args   "-r 800x600"                    cat "$LOCKDIR/hdmi2.args"
# audio reactivity (react.c + lfo shape audio): fed by tone.py
check react-off    "/audio/react \"off\" 0"        q /audio/react
check react-fftbad "256, 512 or 1024"              q /audio/react/fft 300
q /lfo/3/audio bass > /dev/null; q /lfo/3/range 0 100 > /dev/null; q /lfo/3/on 1 > /dev/null
check lfo-badfeat  "audio feature"                 q /lfo/3/audio treble
q /lfo/4/audio high > /dev/null; q /lfo/4/gain 0 > /dev/null; q /lfo/4/range 0 100 > /dev/null; q /lfo/4/on 1 > /dev/null
check react-src    "/audio/react/source \"capture\"" q /audio/react/source capture	# the tone starts
sleep 1.5
check react-bass   "ok"  sh -c "$BIN/dzctl -p $PORT -t 200 /audio/react | awk '{ print (\$6 > 0.3 && \$6 > 4 * \$9) ? \"ok\" : \$0 }'"
check lfo-audio    "ok"  sh -c "$BIN/dzctl -p $PORT -t 200 /lfo/3 | awk '{ print (\$2 > 30) ? \"ok\" : \$0 }'"
sleep 3
check lfo-autogain "ok"  sh -c "$BIN/dzctl -p $PORT -t 200 /lfo/4 | awk '{ print (\$2 > 70) ? \"ok\" : \$0 }'"
check react-high   "ok"  sh -c "$BIN/dzctl -p $PORT -t 200 /audio/react | awk '{ print (\$9 > 0.3 && \$9 > 4 * \$6) ? \"ok\" : \$0 }'"
check react-held   "held: recording"  sh -c "$BIN/dzctl -p $PORT -t 200 /audio/rec selftest_rec >/dev/null; $BIN/dzctl -p $PORT -t 200 /audio/react"
sleep 2.5
check react-resume "\"ok\""                         q /audio/react
check react-state  "\"/lfo/3/audio\" \"bass\""        sh -c "$BIN/dzctl -p $PORT -t 400 /state | grep -F /lfo/3/audio"
check react-st-src "\"/audio/react/source\" \"capture\"" sh -c "$BIN/dzctl -p $PORT -t 400 /state | grep -F /audio/react/source"
check dds-scope    "dz_osc2"                       q /dds/1/scope 4 v	# simulation: no dz_osc2 (board test)
q /audio/react/source off > /dev/null; q /lfo/reset > /dev/null
# crop windows (disp.c): 720p window in a 1920x1080 slot, x even, clamped
check crop-set     "/disp/0/crop 100 50"           q /disp/0/crop 100 50
check crop-odd     "/disp/0/crop 100 51"           q /disp/0/crop 101 51
check crop-clamp   "/disp/0/crop 640 360"          q /disp/0/crop 1000 999
check crop-query   "/disp/0/crop 640 360"          q /disp/0/crop
check crop-off     "/disp/0/crop 0 0"              q /disp/0/crop/off
check capture-auto "/capture/auto 1"               q /capture/auto

# fan PWM (pwm.c): J3 = hardware registers (simulated), J5 = software edges;
# other IO_OUT bits survive the thread
q /led/red 1 >/dev/null
check pwm-hw-start  "/fan/3/pwm 1000 0.25"          q /fan/3/pwm 1000 0.25
check pwm-hw-period "/value \"/fan/3/pwm/period\" 100000" q /fan/3/pwm/period
check pwm-hw-duty   "/value \"/fan/3/pwm/duty\" 25000"   q /fan/3/pwm/duty
check pwm-hw-on     "/value \"/fan/3/pwm/on\" 1"         q /fan/3/pwm/on
check pwm-hw-servo  "/fan/3/pwm 50 0.925"           q /fan/3/servo 0.5
check pwm-hw-pulse  "/value \"/fan/3/pwm/duty\" 150000"  q /fan/3/pwm/duty
check pwm-hw-inv    "/value \"/fan/3/pwm/invert\" 1"     q /fan/3/pwm/invert
check pwm-hw-slow   "/fan/3/pwm 2 0.5"              q /fan/3/pwm 2 0.5
check pwm-hw-off    "/value \"/fan/3/pwm/on\" 0"         q /fan/3/pwm/on
q /fan/3/pwm 0 >/dev/null
check pwm-sw-start  "/fan/5/pwm 50 0.25"            q /fan/5/pwm 50 0.25
q /fan/pwm/stats >/dev/null
sleep 0.5
check pwm-sw-edges  "/fan/pwm/stats"                q /fan/pwm/stats
check pwm-led       "/value \"/led/red\" 1"         q /led/red
check pwm-sw-servo  "/fan/5/pwm 50 0.925"           q /fan/5/servo 0.5
check pwm-sw-stop   "/fan/5/pwm 0"                  q /fan/5/pwm 0
check pwm-sw-off    "/value \"/fan/5/out\" 0"       q /fan/5/out
check pwm-bad-conn  "fan connector is 3 or 5"       q /fan/4/pwm 50 0.5
check pwm-bad-hz    "/fan/<n>/pwm hz"               q /fan/5/pwm 5000 0.5

# trans.c (2026-10-30): HDMI_1 cross-fade; own + feedback = G per lane, never 256
q /hdmi/1/gain/rgb 255 >/dev/null; q /hdmi/1/feedback/rgb 0 >/dev/null
q /fx/xfade 0.5 >/dev/null
check xfade-own     "/value \"/hdmi/1/gain/rgb\" 8355711"     q /hdmi/1/gain/rgb
check xfade-fb      "/value \"/hdmi/1/feedback/rgb\" 8421504" q /hdmi/1/feedback/rgb
check xfade-query   "/fx/xfade 0.50"                        q /fx/xfade
check trans-now     "/trans/status 0"                       q /trans/field /hdmi/0/gain/r 77 0
check trans-value   "/value \"/hdmi/0/gain/r\" 77"          q /hdmi/0/gain/r
check trans-bad     "/trans/field s:path"                   q /trans/field /no/such 1 1
check mosh-nomovie  "no movie through dzmosh"               q /movie/0/mosh -1
check movie-fx      "/movie/0/fx 0 0 0 0 0"                 q /movie/0/fx
check ascii-mode    "\"braille\""                           q /ascii/1/mode braille
check ascii-once    "/ascii/1/status 0 0"                   q /ascii/1/once 0
check ascii-bad     "mode: ascii shade"                     q /ascii/1/mode nosuch
check ascii-stop    "/ascii/1/status 0 0"                   q /ascii/1/stop
check ascii-cols    "/ascii/1/status 0 0 40"                q /ascii/1/cols 40
check stats         "/stats"                                q /stats
check movie-stats   "/movie/5/stats 0"                      q /movie/5/stats
check hue-set       "/fx/matrix"                            q /fx/hue 120 0.5
q /fx/hue/deg 90 >/dev/null
check hue-gainkeep  "/fx/hue 90 0.5"                        q /fx/hue
q /fx/identity >/dev/null; q /fx/matrix/rr 0.5 >/dev/null; q /fx/matrix/rg 0.25 >/dev/null
check matrix-entry  "/fx/matrix 0.5 0.25 0"                 q /fx/matrix
q /fx/key/color 0x00FF00 >/dev/null; q /fx/key/tol 40 >/dev/null
check key-tol       "/fx/key/color 65280 40"                q /fx/key/color
check crop-x        "/disp/0/crop"                          q /disp/0/crop/x 64
q /movie/2/vf lagfun >/dev/null
check vf-preset     "/movie/2/vf \"lagfun=decay=0.95\""     q /movie/2/vf
check vf-refused    "filter refused"                        q /movie/2/vf "negate;rm"
q /movie/2/af tremolo >/dev/null
check af-preset     "/movie/2/af \"tremolo=f=6:d=0.8\""     q /movie/2/af
q /movie/2/vf trails >/dev/null
check trails-word   "/movie/2/fx 0 0 0 0 0 0.9 0"            q /movie/2/fx
q /movie/2/ghost 0.5 >/dev/null
check ghost-set     "/movie/2/fx 0 0 0 0 0 0 0.5"            q /movie/2/fx
q /movie/2/vf "hue=h=90:s=2:b=0,negate" >/dev/null; q /movie/2/vf/hue/h 45 >/dev/null
check live-replace  "/movie/2/vf \"hue=h=45:s=2:b=0,negate\"" q /movie/2/vf
q /movie/2/vf "lagfun" >/dev/null; q /movie/2/vf/lagfun/decay 0.9 >/dev/null
check live-append   "/movie/2/vf \"lagfun=decay=0.9\""      q /movie/2/vf
check live-refused  "live filter refused"                   q /movie/2/vf/hue/h "1;rm"
q /state/snap t1 >/dev/null; q /mixer/3/k 777 >/dev/null; q /lfo/5/rate 3 >/dev/null
check state-diff    "/state/end 2"                          q /state/diff t1
q /state/recall t1 >/dev/null
check state-recall  "/state/end 0"                          q /state/diff t1
check state-count   "ok"  sh -c "$BIN/dzctl -p $PORT -t 400 /state | awk '/^.state.end/ { print (\$2 > 400) ? \"ok\" : \$0 }'"
q /show/new selftest >/dev/null; q /mixer/3/k 100 >/dev/null; q /lfo/2/rate 1 >/dev/null
check cue-key       "\"keyframe\""                          q /cue/record s1 1 keyframe dark
q /mixer/3/k 200 >/dev/null
check cue-delta     "\"delta\" 1"                           q /cue/record s1 2 delta x
q /lfo/2/rate 5 >/dev/null; q /cue/record s1 3 delta y >/dev/null
check cue-track     "\"/mixer/3/k\" \"/mixer/3/k\" 200"       q /cue/resolve s1 3
check cue-first     "must be a keyframe"                    q /cue/record s2 1 delta
check cue-noscene   "/scene/end 1"                          q /scene/list
q /cue/go s1 1 >/dev/null
check cue-go1       "/value \"/mixer/3/k\" 100"              q /mixer/3/k
q /cue/go s1 3 >/dev/null
check cue-go3       "/value \"/mixer/3/k\" 200"              q /mixer/3/k
q /show/save selftest >/dev/null; q /show/new other >/dev/null; q /show/load selftest >/dev/null
check cue-load      "/cue/end 3"                            q /cue/list s1
q /cue/go s1 1 >/dev/null; q /cue/go s1 3 0.6 fade >/dev/null; sleep 0.25
check cue-fading    "/trans/status 1"                       q /trans/status
sleep 0.6
check cue-faded     "/value \"/mixer/3/k\" 200"              q /mixer/3/k
q /hdmi/0/gain/rgb 200 200 200 >/dev/null; q /cue/go s1 1 2 dip >/dev/null; sleep 0.1
check cue-dip-down  "/value \"/mixer/3/k\" 200"              q /mixer/3/k
sleep 2
check cue-dip-done  "/value \"/mixer/3/k\" 100"              q /mixer/3/k
q /cue/go s1 2 >/dev/null; q /mixer/3/k 150 >/dev/null
check cue-decimal   "/cue/record \"s1\" 2.5 \"delta\" 1"      q /cue/record s1 2.5 delta
check cue-order     "/cue 2.5"                              q /cue/list s1
q /cue/go s1 1 >/dev/null; q /hdmi/1/gain/rgb 11 22 33 >/dev/null
check look-save     "/look/save \"lk1\""                    q /look/save lk1
q /cue/go s1 1 >/dev/null; q /look/apply lk1 >/dev/null
check look-apply    "/value \"/hdmi/1/gain/rgb\" 729366"    q /hdmi/1/gain/rgb
check look-add      "/cue/look \"s1\" 3 1"                  q /cue/look s1 3 add lk1
check show-check    "/show/check/end 0"                     q /show/check
q /led/red 0 >/dev/null

# paint bucket: an outlined box, filled inside; outside stays black
q /draw/5/clear 0 0 0 >/dev/null
q /draw/5/rect 255 255 255 100 100 200 100 4 >/dev/null
q /draw/5/fill solid >/dev/null
q /draw/5/flood 0 255 0 200 150 >/dev/null
check flood-inside  "/pixel 5 200 150 0 255 0"          q /surface/5/peek 200 150
check flood-edge    "/pixel 5 101 150 255 255 255"      q /surface/5/peek 101 150
check flood-outside "/pixel 5 50 50 0 0 0"              q /surface/5/peek 50 50
q /draw/5/fill linear 0 0 255 0 >/dev/null
q /draw/5/flood 255 0 0 200 150 30 >/dev/null
check flood-grad-l  "/pixel 5 105 150 25"               q /surface/5/peek 105 150
check flood-grad-r  "/pixel 5 294 150 2 0 25"           q /surface/5/peek 294 150
q /draw/5/fill solid >/dev/null

if [ $HAVE_FF -eq 1 ]; then
	check anim-list    "/anim/folder \"seq\" 8"              q /anim/list
	check anim-files   "/file \"sheet\""                     q /files anim
	q /anim/0/play seq 30 >/dev/null; sleep 0.4
	check anim-play    "/anim/0 \"seq\" 8"                   q /anim/0
	check anim-playing "\"playing\""                         q /anim/0
	check anim-source  "\"/disp/0/source\" \"anim\""         q /state
	q /anim/0/pause 1 >/dev/null; q /anim/0/frame 0 >/dev/null; sleep 0.15
	check anim-frame0  "\"paused\" \"f1.jpg\""               q /anim/0
	q /surface/3/grab "$(q /anim/0 | awk '{print $NF}')" >/dev/null
	near  anim-pixel   "32 64 128"                            q /surface/3/peek 640 360
	check anim-border  "/pixel 3 479 360 0 0 0"               q /surface/3/peek 479 360
	q /anim/0/step 2 >/dev/null; sleep 0.15
	check anim-step    "\"f3.jpg\""                          q /anim/0
	check anim-sheet   "/anim/1 \"sheet\" 2 -1 5"             q /anim/1/play sheet
	sleep 0.6
	check anim-resident "\"playing\""                        q /anim/1
	check anim-slots-busy "stop the sequence first"          q /anim/1/slots 1 3
	q /anim/1/pause 1 >/dev/null; q /anim/1/frame 1 >/dev/null; sleep 0.15
	q /surface/3/grab "$(q /anim/1 | awk '{print $NF}')" >/dev/null
	near  anim-png     "255 0 0"                              q /surface/3/peek 640 360
	q /state/snap anim1 >/dev/null
	q /disp/0/show 0 >/dev/null
	check anim-stopped "/anim/0 \"\" 0 -1"                   q /anim/0
	q /state/recall anim1 >/dev/null; sleep 0.2
	check anim-recall  "/anim/0 \"seq\" 8"                   q /anim/0
	check anim-bad     "no folder"                            q /anim/0/play nothere
	q /anim/0/stop >/dev/null; q /anim/1/stop >/dev/null
	# build a folder frame by frame (web Paint tab: Save frame)
	q /draw/3/clear 0 200 0 >/dev/null
	check anim-save1   "/anim/saved \"take\" \"f00001.jpg\" 1"  q /anim/save take 3
	q /draw/3/clear 0 0 200 >/dev/null
	check anim-save2   "/anim/saved \"take\" \"f00002.jpg\" 2"  q /anim/save take 3 80
	check anim-undo    "/anim/saved \"take\" \"\" 1"           q /anim/undo take
	check anim-save-bad "folder name"                         q /anim/save "../x" 3
	q /anim/0/play take 10 >/dev/null; sleep 0.3
	q /surface/3/grab "$(q /anim/0 | awk '{print $NF}')" >/dev/null
	near  anim-saved-px "0 200 0"                             q /surface/3/peek 640 360
	q /anim/save take 3 >/dev/null; sleep 0.3
	check anim-reload  "/anim/0 \"take\" 2"                  q /anim/0
	q /anim/0/stop >/dev/null
	# timing sheet: a hold on save makes timing.txt; edit it; undo drops the line
	check sheet-none   "/anim/sheet/end \"take\" 0 2"         q /anim/sheet take
	q /anim/save take 3 90 4 >/dev/null
	check sheet-hold   "f00003.jpg 4"                         q /anim/sheet take
	check sheet-made   "/anim/sheet/end \"take\" 1 3"         q /anim/sheet take
	check sheet-put    "/anim/sheet/saved \"take\" 3 1 \"nope.jpg\"" \
		q /anim/sheet/put take 0 1 "# fps 6
f00001.jpg 2
nope.jpg
f00002.jpg 3
"
	check sheet-read   "f00002.jpg 3"                         q /anim/sheet take
	q /anim/save take 3 >/dev/null
	check sheet-append "f00004.jpg"                           q /anim/sheet take
	q /anim/undo take >/dev/null
	check sheet-undo   "/anim/sheet/end \"take\" 1 3 6"       q /anim/sheet take
	check sheet-parts  "part 0 missing"                       q /anim/sheet/put take 1 1 "x"
	q /anim/sheet/put take 0 0 "f00001.jpg 2
" >/dev/null
	check sheet-parts2 "/anim/sheet/saved \"take\" 2 0"        q /anim/sheet/put take 1 1 "f00002.jpg
"
	check sheet-clear  "/anim/sheet/saved \"take\" 0 0"        q /anim/sheet/put take 0 1 ""
	check sheet-gone   "/anim/sheet/end \"take\" 0"            q /anim/sheet take
	check anim-saved-bytes "/anim/saved \"take\" \"f00004.jpg\" 4"  q /anim/save take 3 50
	# onion skin: source slot 2 (red) under the last frame (green: slot 3 holds a grab of f00001)
	q /draw/2/clear 200 0 0 >/dev/null
	check onion-start  "\"onion\""                           q /anim/1/onion take 0.5 1 2
	sleep 0.4
	q /surface/4/grab "$(q /anim/1 | awk '{print $NF}')" >/dev/null
	near  onion-mix    "100 100 0"                            q /surface/4/peek 640 360
	q /anim/1/onion/opacity 1 >/dev/null; sleep 0.3
	q /surface/4/grab "$(q /anim/1 | awk '{print $NF}')" >/dev/null
	near  onion-opaque "0 200 0"                              q /surface/4/peek 640 360
	check onion-state  "\"/anim/1/play\" \"\""                  q /state
	check onion-off    "\"stopped\""                         q /anim/1/onion ""
	check anim-delete  "/anim/deleted \"take\" 4"              q /anim/delete take
	check anim-deleted "no folder"                            q /anim/sheet take
else
	echo "skip anim-* (no ffmpeg to make test frames)"
fi

kill $PID
wait $PID 2>/dev/null
if [ $FAIL -ne 0 ]; then
	echo "--- debazd log"; cat "$LOCKDIR/log"
	exit 1
fi
echo "all checks passed"

#!/bin/sh
# selftest.sh - host test of debazd + dzctl with simulated hardware.
#   sh tools/selftest.sh out/native
# Exit 0 = all checks passed.
set -u
BIN=${1:-out/native}
PORT=19123
FAIL=0
LOCKDIR=$(mktemp -d)

"$BIN/debazd" -n -p $PORT 2>"$LOCKDIR/log" &
PID=$!
trap 'kill $PID 2>/dev/null; rm -rf "$LOCKDIR"' EXIT
sleep 0.3

q() { "$BIN/dzctl" -p $PORT -t 200 "$@"; }

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

kill $PID
wait $PID 2>/dev/null
if [ $FAIL -ne 0 ]; then
	echo "--- debazd log"; cat "$LOCKDIR/log"
	exit 1
fi
echo "all checks passed"

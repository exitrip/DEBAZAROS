#!/usr/bin/env python3
"""osc_feature_demo.py - tour of the debazd features on one display.

    python3 osc_feature_demo.py [host] [display] [--strobe]
    default host 10.42.0.128, display 1

Uses slots 6-10 and sprite ids 50-53, then shows the display's previous slot
again. Needs /home/ebaz/img/utriusque_cosmi_majoris-11.jpg on the board.
--strobe adds a 2-second 30 Hz black/white strobe: a photosensitivity risk.
"""
import math
import socket
import struct
import sys
import time

args = [a for a in sys.argv[1:] if not a.startswith("--")]
HOST = args[0] if args else "10.42.0.128"
DISP = int(args[1]) if len(args) > 1 else 1
STROBE = "--strobe" in sys.argv
sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.settimeout(3.0)


def _s(x):
    b = x.encode() + b"\0"
    return b + b"\0" * (-len(b) % 4)


def msg(path, *a):
    tags, data = ",", b""
    for v in a:
        if isinstance(v, float):
            tags, data = tags + "f", data + struct.pack(">f", v)
        elif isinstance(v, int):
            tags, data = tags + "i", data + struct.pack(">i", v)
        else:
            tags, data = tags + "s", data + _s(str(v))
    return _s(path) + _s(tags) + data


def send(*msgs):
    """one bundle + /ping; wait for /pong, print errors"""
    out = b"#bundle\0" + struct.pack(">Q", 1)
    for m in msgs + (msg("/ping"),):
        out += struct.pack(">i", len(m)) + m
    sock.sendto(out, (HOST, 9000))
    while True:
        data, _ = sock.recvfrom(4096)
        if data.startswith(b"/pong"):
            return
        if data.startswith(b"/error"):
            print("  error:", b" ".join(x for x in data.split(b"\0") if x and x[0:1] != b","))


def ask(path):
    sock.sendto(msg(path), (HOST, 9000))
    data, _ = sock.recvfrom(4096)
    return data


def title(t):
    print("== " + t)


prev = struct.unpack(">i", ask("/disp/%d" % DISP)[-12:-8])[0]

title("1 TrueType title + pixel font")
send(msg("/draw/6/gradient/v", 10, 0, 40, 0, 0, 0),
     msg("/draw/6/ttf", 255, 220, 120, 260, 220, 120, "DEBAZAROS"),
     msg("/draw/6/text", 160, 160, 160, 300, 400, "reclaimed miner board video feedback", 2, 16),
     msg("/disp/%d/show" % DISP, 6))
time.sleep(3)

title("2 sprite: engraving, rotating, with trails")
send(msg("/sprite/50/load", "utriusque_cosmi_majoris-11.jpg", 400, 400),
     msg("/sprite/50/key", 255, 255, 255, 40),          # white paper -> transparent
     msg("/draw/7/clear", 0, 0, 0), msg("/disp/%d/show" % DISP, 7))
for k in range(90):
    send(msg("/draw/7/fade", 0.08),
         msg("/sprite/50/draw", 7, 640 + int(300 * math.sin(k * 0.07)), 360, 0.9, k * 4.0))

title("3 feedback tunnel: rotozoom on itself")
send(msg("/draw/8/clear", 0, 0, 0), msg("/disp/%d/show" % DISP, 8))
for k in range(90):
    send(msg("/draw/8/brush", 255, (k * 7) % 255, 80, 640, 360, 25, 0.2),
         msg("/draw/8/rotozoom", 3.0, 1.04))

title("4 LFO light painting (the daemon animates by itself for 6 s)")
send(msg("/draw/9/clear", 0, 0, 0), msg("/draw/9/blend", "add"),
     msg("/disp/%d/show" % DISP, 9),
     msg("/lfo/10/rate", 0.31), msg("/lfo/10/range", 100.0, 1180.0),
     msg("/lfo/11/rate", 0.47), msg("/lfo/11/range", 80.0, 640.0),
     msg("/lfo/12/shape", "tri"), msg("/lfo/12/rate", 0.2), msg("/lfo/12/range", 10.0, 50.0),
     msg("/lfo/11/target", "/draw/9/brush 160 70 20 $10 $11 $12 0"),
     msg("/lfo/13/target", "/draw/9/fade 0.1"), msg("/lfo/13/every", 4),
     *[msg("/lfo/%d/on" % k, 1) for k in (10, 11, 12, 13)])
time.sleep(6)
send(*[msg("/lfo/%d/on" % k, 0) for k in (10, 11, 12, 13)], msg("/draw/9/blend", "normal"))

title("5 text sprite + transforms: wave, mirror quad")
send(msg("/sprite/51/ttf", 120, 200, 255, 90, "feedback"),
     msg("/draw/10/gradient/h", 0, 0, 0, 0, 30, 60),
     msg("/sprite/51/draw", 10, 400, 250, 1.0, -15.0),
     msg("/disp/%d/show" % DISP, 10))
for k in range(60):
    send(msg("/draw/10/wave", 0, 6.0, 90.0, k / 60.0))
send(msg("/draw/10/mirror", "quad"))
time.sleep(2)

title("6 flipbook of slots 6-10, 6 frames per step, then blank/unblank")
send(msg("/disp/%d/seq/rate" % DISP, 6), msg("/disp/%d/seq" % DISP, 6, 7, 8, 9, 10))
time.sleep(4)
send(msg("/disp/%d/seq/stop" % DISP), msg("/disp/%d/seq/rate" % DISP, 1))
for _ in range(3):
    send(msg("/disp/%d/blank" % DISP, 1)); time.sleep(0.5)
    send(msg("/disp/%d/blank" % DISP, 0)); time.sleep(0.5)

if STROBE:
    title("7 STROBE 30 Hz for 2 s")
    send(msg("/draw/6/clear", 255, 255, 255), msg("/disp/%d/seq" % DISP, 6, -1))
    time.sleep(2)
    send(msg("/disp/%d/seq/stop" % DISP))

for k in (50, 51):
    send(msg("/sprite/%d/free" % k))
if prev >= 0:
    send(msg("/disp/%d/show" % DISP, prev))
print("done")

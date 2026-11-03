#!/usr/bin/env python3
"""asciibench.py - baseline test: ASCII + live painting on one slot (2026-11-02).

The scene (the user's, 2026-11-02): display 0 shows slot 6; /ascii/6/run 6 =
ASCII reads slot 6 and draws into slot 6 (feedback: the text is drawn from
the painting and the text, so the brush leaves a "cursor" trail); brush
strokes into slot 6 at ~60 per second (as a fast Paint-tab drag).
SRC = 0 instead: ASCII from slot 0 into slot 6 (no feedback). Variants:
"still" = slot 0 is one picture; "moving" = a disc moves in slot 0 every
frame (with SRC 6 the brush moves the picture in both).

Each second: /ascii/6/status (ms per frame, fps), /stats (debazd CPU, tick
rate, slowest tick / OSC packet) and a /ping round trip. Prints the medians.

  python3 sw/tools/asciibench.py [host] [seconds] [cols] [mode] [every] [src]
  (default 10.42.0.210 15 80 ascii 1 6; mode chars = a TrueType ramp)

It takes over display 0 and slots 0 and 6. Plain UDP OSC, no extra modules.
"""
import math
import os
import socket
import statistics
import struct
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from dzosc import msg, bundle, parse  # noqa: E402

HOST = sys.argv[1] if len(sys.argv) > 1 else "10.42.0.210"
SECS = float(sys.argv[2]) if len(sys.argv) > 2 else 15
COLS = int(sys.argv[3]) if len(sys.argv) > 3 else 80
MODE = sys.argv[4] if len(sys.argv) > 4 else "ascii"
EVERY = int(sys.argv[5]) if len(sys.argv) > 5 else 1
SRC = int(sys.argv[6]) if len(sys.argv) > 6 else 6


sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.settimeout(0.002)
dst = (HOST, 9000)


def send(p):
    sock.sendto(p, dst)


def drain(into):
    while True:
        try:
            pkt, _ = sock.recvfrom(65536)
        except (socket.timeout, BlockingIOError):
            return
        for m in parse(pkt):
            into.append((time.monotonic(), m))


def setup():
    send(bundle(msg("/ascii/6/stop"), msg("/lfo/reset"), msg("/movie/0/stop"), msg("/movie/6/stop"),
                msg("/draw/6/alpha", 1.0), msg("/draw/6/blend", "normal"),
                msg("/draw/0/alpha", 1.0), msg("/draw/0/blend", "normal")))
    time.sleep(0.2)
    # slot 0: a still picture with detail (gradient + discs)
    send(msg("/draw/0/gradient/h", 20, 0, 80, 250, 200, 40))
    for k in range(8):
        send(msg("/draw/0/circle", 255, 255 - 30 * k, 30 * k, 160 * k + 80, 360, 60, 0))
    send(msg("/draw/6/solid", 0, 0, 0))
    send(msg("/disp/0/show", 6))
    mode = [msg("/ascii/6/chars", "@!~/';.,[]\\+_)(*^%$#")] if MODE == "chars" else [msg("/ascii/6/mode", MODE)]
    send(bundle(*mode, msg("/ascii/6/cols", COLS), msg("/ascii/6/color", 1), msg("/ascii/6/every", EVERY)))
    time.sleep(0.3)
    send(msg("/ascii/6/run", SRC))
    time.sleep(1.0)


def run(variant):
    setup()
    seen = []
    t0 = time.monotonic()
    nxt = t0
    last_q = t0
    ping_t = None
    pings = []
    k = 0
    while time.monotonic() - t0 < SECS:
        now = time.monotonic()
        if now >= nxt:
            a = k * 0.09
            pts = []
            for j in range(4):
                x = 640 + 400 * math.cos(a + j * 0.02)
                y = 360 + 250 * math.sin(1.3 * (a + j * 0.02))
                pts += [int(x), int(y)]
            m = [msg("/draw/6/stroke", 255, 120, 20, 18, 0.6, *pts)]
            if variant == "moving":
                bx = int(640 + 500 * math.sin(k * 0.05))
                m.append(msg("/draw/0/circle", 250, 250, 250, bx, 360, 90, 0))
                m.append(msg("/draw/0/circle", 30, 30, 120, (bx + 640) % 1280, 360, 90, 0))
            send(bundle(*m) if len(m) > 1 else m[0])
            k += 1
            nxt += 1 / 60
        if now - last_q >= 1.0:
            last_q = now
            ping_t = now
            send(bundle(msg("/ascii/6/status"), msg("/stats")))
            send(msg("/ping"))
        n0 = len(seen)
        drain(seen)
        for t, (path, args) in seen[n0:]:
            if path == "/pong" and ping_t is not None:
                pings.append((t - ping_t) * 1000)
                ping_t = None
        time.sleep(0.001)
    drain(seen)
    send(msg("/ascii/6/stop"))
    st = [a for _, (p, a) in seen if p == "/ascii/6/status" and len(a) >= 15 and a[0]]
    ss = [a for _, (p, a) in seen if p == "/stats" and len(a) >= 8]
    med = lambda v: statistics.median(v) if v else float("nan")
    ms = [a[12] for a in st]
    fps = [a[15] for a in st[1:] if len(a) >= 16]  # builds before 2026-11-02: no fps
    print(f"{variant:7s} {MODE} {COLS} every {EVERY} src {SRC}: ascii {med(ms):6.2f} ms  {med(fps):5.1f} fps | debazd cpu {med([a[0] for a in ss[1:]]):5.1f} % "
          f"tick {med([a[2] for a in ss]):5.1f} Hz, slowest tick {med([a[3] for a in ss]):5.1f} ms, "
          f"osc {med([a[4] for a in ss]):5.2f} ms | ping {med(pings):5.1f} ms | strokes {k / SECS:4.1f}/s")


if __name__ == "__main__":
    for v in ("still", "moving"):
        run(v)

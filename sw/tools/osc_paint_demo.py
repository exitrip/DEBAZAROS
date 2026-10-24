#!/usr/bin/env python3
"""osc_paint_demo.py - drive the debazd painter over OSC (no extra packages).

    python3 osc_paint_demo.py [host] [slot]      default 10.42.0.128, slot 5

Show the canvas first:  dzctl -h <host> /disp/1/show 5

Phases: 1) light painting with trails (add blend + fade), 2) strokes and
lines, 3) grab the live capture (slot 4) and paint over the frozen frame.
Each frame is one OSC bundle that ends with /ping; the script waits for the
/pong, so the printed fps is what the daemon really achieves.
"""
import math
import socket
import struct
import sys
import time

HOST = sys.argv[1] if len(sys.argv) > 1 else "10.42.0.128"
SLOT = int(sys.argv[2]) if len(sys.argv) > 2 else 5
PORT = 9000


def _s(x):
    b = x.encode() + b"\0"
    return b + b"\0" * (-len(b) % 4)


def msg(path, *args):
    tags, data = ",", b""
    for a in args:
        if isinstance(a, float):
            tags += "f"
            data += struct.pack(">f", a)
        elif isinstance(a, int):
            tags += "i"
            data += struct.pack(">i", a)
        else:
            tags += "s"
            data += _s(str(a))
    return _s(path) + _s(tags) + data


def bundle(*msgs):
    out = b"#bundle\0" + struct.pack(">Q", 1)
    for m in msgs:
        out += struct.pack(">i", len(m)) + m
    return out


sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.settimeout(2.0)
d = "/draw/%d/" % SLOT


def frame(*msgs):
    """send one bundle + /ping, wait for /pong; return seconds"""
    t0 = time.time()
    sock.sendto(bundle(*msgs, msg("/ping")), (HOST, PORT))
    while True:
        data, _ = sock.recvfrom(4096)
        if data.startswith(b"/pong"):
            return time.time() - t0
        if data.startswith(b"/error"):
            print("error:", data.split(b"\0")[0:6])


def phase(name, seconds, fn):
    n, busy, t_end = 0, 0.0, time.time() + seconds
    while time.time() < t_end:
        busy += frame(*fn(n))
        n += 1
    print("%-28s %4d frames  %5.1f fps  %5.1f ms per frame" %
          (name, n, n / seconds, 1000.0 * busy / max(n, 1)))


# 1) light painting: three coloured lights on Lissajous paths, with trails
frame(msg(d + "clear", 0, 0, 0), msg(d + "blend", "add"))


def lights(n):
    t = n * 0.08
    out = [msg(d + "fade", 0.06)]
    for k, (r, g, b) in enumerate([(160, 30, 10), (10, 120, 160), (90, 160, 20)]):
        x = int(640 + 520 * math.sin(t * (1.0 + 0.3 * k) + k))
        y = int(360 + 300 * math.sin(t * (1.7 - 0.2 * k)))
        out.append(msg(d + "brush", r, g, b, x, y, 40, 0.0))
    return out


phase("1 light painting + trails", 8, lights)

# 2) strokes and lines on a dark background
frame(msg(d + "blend", "normal"), msg(d + "gradient/v", 0, 0, 60, 0, 0, 0))


def strokes(n):
    a = n * 0.35
    pts = []
    for k in range(6):
        r = 40 + 25 * k + n * 2
        pts += [int(640 + r * math.cos(a + k * 0.9)), int(360 + r * math.sin(a + k * 0.9))]
    hue = (n * 37) % 255
    return [msg(d + "stroke", 255, hue, 255 - hue, 6, 0.3, *pts),
            msg(d + "line", 255, 255, 255, 0, (n * 9) % 720, 1279, 719 - (n * 9) % 720, 1)]


phase("2 strokes + lines", 6, strokes)

# 3) freeze the live capture into the canvas and paint over it
t0 = time.time()
frame(msg("/surface/%d/grab" % SLOT, 4))
print("%-28s %5.0f ms (one uncached frame read)" % ("3 grab capture", 1000 * (time.time() - t0)))


def over(n):
    return [msg(d + "circle", 255, 220, 0, 100 + (n * 47) % 1080, 100 + (n * 29) % 520, 30 + n % 40, 4)]


phase("3 paint over frozen frame", 4, over)

#!/usr/bin/env python3
# oscstate.py - save debazd's /state to a JSON file and replay it (2026-11-22,
# for stress.sh: put a bench board back as it was).
#   oscstate.py save HOST FILE      /state -> [[address, [[tag, value], ...]], ...]
#   oscstate.py replay HOST FILE    send every target back, in dump order
import json, socket, struct, sys, time

def pad(b): return b + b"\0" * (4 - len(b) % 4)
def build(path, args):
    tags, data = ",", b""
    for t, v in args:
        tags += t
        data += struct.pack(">i", v) if t == "i" else struct.pack(">f", v) if t == "f" else pad(v.encode())
    return pad(path.encode()) + pad(tags.encode()) + data
def rd_str(b, o):
    e = b.index(b"\0", o); return b[o:e].decode(errors="replace"), (e + 4) & ~3
def parse(b, out):
    if b.startswith(b"#bundle"):
        o = 16
        while o < len(b):
            n = struct.unpack(">i", b[o:o + 4])[0]; parse(b[o + 4:o + 4 + n], out); o += 4 + n
        return
    path, o = rd_str(b, 0); tags, o = rd_str(b, o); args = []
    for t in tags[1:]:
        if t == "s": v, o = rd_str(b, o)
        elif t in "if": v = struct.unpack(">" + t, b[o:o + 4])[0]; o += 4
        else: continue
        args.append([t, v])
    out.append((path, args))

mode, host, fn = sys.argv[1:4]
s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM); s.settimeout(1.0)
if mode == "save":
    s.sendto(build("/state", []), (host, 9000)); got = []
    try:
        while not any(p == "/state/end" for p, _ in got): parse(s.recv(65536), got)
    except socket.timeout: pass
    t = [[a[1][1], a[2:]] for p, a in got if p == "/state/target" and len(a) >= 2]
    json.dump(t, open(fn, "w")); print(f"saved {len(t)} targets")
else:
    t = json.load(open(fn))
    for addr, args in t:
        s.sendto(build(addr, args), (host, 9000)); time.sleep(0.002)
    print(f"replayed {len(t)} targets")

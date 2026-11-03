#!/usr/bin/env python3
"""dzstate.py - save debazd's whole state to a file and send it back (2026-11-02).

  python3 sw/tools/dzstate.py save [host] [file]   /state -> file (one line per target)
  python3 sw/tools/dzstate.py load [host] [file]   file -> debazd, as bundles of 16

The file holds "/address args" lines (JSON per line: address + typed args), the
same targets a cue keyframe stores. For a debazd restart (a new build, a crash):
snapshots and looks without a show live only in debazd's memory.
Defaults: host 10.42.0.210, file /tmp/dzstate.jsonl. Plain UDP OSC.
"""
import json
import socket
import struct
import sys
import time

import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from dzosc import msg, bundle, parse  # noqa: E402

cmd = sys.argv[1] if len(sys.argv) > 1 else ""
host = sys.argv[2] if len(sys.argv) > 2 else "10.42.0.210"
path = sys.argv[3] if len(sys.argv) > 3 else "/tmp/dzstate.jsonl"
sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.settimeout(0.5)
dst = (host, 9000)


if cmd == "save":
    sock.sendto(msg("/state"), dst)
    got, t0 = [], time.monotonic()
    while time.monotonic() - t0 < 5:
        try:
            pkt, _ = sock.recvfrom(65536)
        except socket.timeout:
            break
        done = False
        for m in parse(pkt):
            if m[0] == "/state/target":
                got.append(m[1])
            if m[0] == "/state/end":
                done = True
        if done:
            break
    with open(path, "w") as f:
        for a in got:
            f.write(json.dumps({"addr": a[1], "args": a[2:]}) + "\n")
    print(f"{len(got)} targets -> {path}")
elif cmd == "load":
    lines = [json.loads(x) for x in open(path)]
    msgs = []
    for e in lines:
        args = [float(v) if isinstance(v, float) else v for v in e["args"]]
        msgs.append(msg(e["addr"], *args))
    for k in range(0, len(msgs), 16):
        sock.sendto(bundle(*msgs[k:k + 16]), dst)
        time.sleep(0.01)
    print(f"{len(msgs)} targets sent from {path}")
else:
    print(__doc__)

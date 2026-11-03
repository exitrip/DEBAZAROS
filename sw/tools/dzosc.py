"""dzosc.py - minimal OSC over UDP for the sw/tools Python scripts (2026-11-02):
msg(path, *args) (int -> i, float -> f, str -> s), bundle(*msgs), parse(pkt) ->
[(path, args)]. No extra modules."""
import struct


def pad(b):
    return b + b"\0" * (4 - len(b) % 4)


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
            data += pad(a.encode())
    return pad(path.encode()) + pad(tags.encode()) + data


def bundle(*msgs):
    return b"#bundle\0" + struct.pack(">Q", 1) + b"".join(struct.pack(">i", len(m)) + m for m in msgs)


def parse(pkt):
    if pkt.startswith(b"#bundle\0"):
        out, pos = [], 16
        while pos + 4 <= len(pkt):
            n = struct.unpack(">i", pkt[pos:pos + 4])[0]
            out += parse(pkt[pos + 4:pos + 4 + n])
            pos += 4 + n
        return out
    end = pkt.index(b"\0")
    path = pkt[:end].decode()
    pos = (end + 4) & ~3
    if pos >= len(pkt) or pkt[pos:pos + 1] != b",":
        return [(path, [])]
    end = pkt.index(b"\0", pos)
    tags = pkt[pos + 1:end].decode()
    pos = (end + 4) & ~3
    args = []
    for t in tags:
        if t == "i":
            args.append(struct.unpack(">i", pkt[pos:pos + 4])[0]); pos += 4
        elif t == "f":
            args.append(struct.unpack(">f", pkt[pos:pos + 4])[0]); pos += 4
        elif t == "s":
            e = pkt.index(b"\0", pos)
            args.append(pkt[pos:e].decode(errors="replace")); pos = (e + 4) & ~3
    return [(path, args)]

#!/usr/bin/env python3
# edge.py - edge-case tests of a bench board from the laptop (2026-11-22).
# Short, targeted cases; after EVERY case an OSC ping (debazd must answer in
# 2 s), after every group a board check (debazd pid / restarts, dmesg,
# taint, leftover processes, memory). Anomalies are logged and the run goes
# on (a crashed debazd is restarted by systemd; the case is marked CRASH).
#
#   edge.py GROUP... [--board ebaz@10.42.0.236] [--out DIR]
#   groups: osc args lfo slots modes audio web resume   (all = every group)
#
# Destructive addresses (show / cue / look editing, saves, deletes, records)
# are never fuzzed. The board state afterwards is junk: reboot it.
import json, os, random, socket, struct, subprocess, sys, time, math

args = sys.argv[1:]
BOARD = "ebaz@10.42.0.236"
OUT = os.path.expanduser("~/debaz-stress/" + time.strftime("%Y%m%d"))
if "--board" in args: BOARD = args[args.index("--board") + 1]
if "--out" in args: OUT = args[args.index("--out") + 1]
IP = BOARD.split("@")[1]
os.makedirs(OUT, exist_ok=True)
LOG = open(os.path.join(OUT, "edge.log"), "a")
SSH = ["sshpass", "-p", os.environ.get("DZ_PASS", ""), "ssh", "-o", "StrictHostKeyChecking=no",
       "-o", "UserKnownHostsFile=/dev/null", "-o", "LogLevel=ERROR", "-o", "ConnectTimeout=5", BOARD]
NEVER = ("/show", "/cue/delete", "/cue/record", "/cue/put", "/cue/move", "/cue/name", "/scene/delete",
         "/scene/rename", "/look", "/anim/save", "/anim/delete", "/anim/undo", "/surface/save",
         "/audio/rec", "/state/snap", "/state/recall", "/lfo/reset")
anomalies = []

def log(s):
    line = time.strftime("%H:%M:%S ") + s
    print(line, flush=True); LOG.write(line + "\n"); LOG.flush()

def sh(cmd, t=30):
    try: return subprocess.run(SSH + [cmd], capture_output=True, text=True, timeout=t).stdout
    except subprocess.TimeoutExpired: return "SSH-TIMEOUT"

# ---- OSC ----
def pad(b): return b + b"\0" * (4 - len(b) % 4)
def osc(path, *a):
    tags, data = ",", b""
    for v in a:
        if isinstance(v, bool): tags += "T" if v else "F"
        elif isinstance(v, int): tags += "i"; data += struct.pack(">i", max(-2**31, min(2**31 - 1, v)))
        elif isinstance(v, float): tags += "f"; data += struct.pack(">f", v) if abs(v) < 3.4e38 or math.isnan(v) or math.isinf(v) else struct.pack(">f", math.copysign(3.4e38, v))
        elif isinstance(v, bytes): tags += "b"; data += struct.pack(">i", len(v)) + pad(v) if len(v) % 4 else struct.pack(">i", len(v)) + v
        else: tags += "s"; data += pad(str(v).encode())
    return pad(path.encode()) + pad(tags.encode()) + data
def bundle(*elems):
    return b"#bundle\0" + b"\0" * 8 + b"".join(struct.pack(">i", len(e)) + e for e in elems)

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
def send(pkt, port=9000):
    try: sock.sendto(pkt, (IP, port))
    except OSError as e: log(f"  send failed: {e} ({len(pkt)} bytes)")
def drain():
    sock.setblocking(False)
    try:
        while True: sock.recv(65536)
    except (BlockingIOError, OSError): pass
    sock.setblocking(True)

def ping(t=2.0):
    p = socket.socket(socket.AF_INET, socket.SOCK_DGRAM); p.settimeout(t)
    t0 = time.time(); p.sendto(osc("/ping"), (IP, 9000))
    try:
        while b"/pong" not in p.recv(65536): pass
        return (time.time() - t0) * 1000
    except socket.timeout: return None
    finally: p.close()

def query(path, *a, t=1.0):
    p = socket.socket(socket.AF_INET, socket.SOCK_DGRAM); p.settimeout(t)
    p.sendto(osc(path, *a), (IP, 9000)); got = b""
    try:
        while True: got += p.recv(65536) + b"\n"
    except socket.timeout: pass
    p.close(); return got

# ---- health ----
state = {}
def board_check(tag):
    s = sh("echo pid=$(pidof debazd) restarts=$(systemctl show debazd -p NRestarts --value) "
           "dmesg=$(dmesg | wc -l) taint=$(cat /proc/sys/kernel/tainted) "
           "avail=$(awk '/MemAvailable/{print $2}' /proc/meminfo) rss=$(awk '/VmRSS/{print $2}' /proc/$(pidof debazd)/status) "
           "ffmpeg=$(pidof ffmpeg | wc -w) fbfeed=$(pidof fbfeed | wc -w) dzmosh=$(pidof dzmosh | wc -w) dzlua=$(pidof dzlua | wc -w) "
           "hdmi2=$(pidof hdmi2.elf | wc -w) dzweb=$(pidof dzweb | wc -w) active=$(systemctl is-active debazd) "
           "pixticks=$(for t in /proc/$(pidof debazd)/task/*; do [ \"$(cat $t/comm)\" = debazd-pix ] && awk '{print $14+$15}' $t/stat; done) "
           "uptime=$(cut -d' ' -f1 /proc/uptime)")
    kv = dict(x.split("=", 1) for x in s.split() if "=" in x)
    if state:
        for k in ("pid", "restarts", "taint"):
            if kv.get(k) != state.get(k): anomaly(tag, f"{k} {state.get(k)} -> {kv.get(k)}")
        try:	# the pixel thread busy since the last check (the ping does not see it)
            busy = (float(kv["pixticks"]) - float(state["pixticks"])) / 100.0 / (float(kv["uptime"]) - float(state["uptime"]))
            if kv.get("pid") == state.get("pid") and busy > 0.8: anomaly(tag, f"pixel thread {busy * 100:.0f} % busy since the last check")
        except (KeyError, ValueError, ZeroDivisionError): pass
        try:
            if int(kv.get("dmesg", 0)) > int(state.get("dmesg", 0)):
                new = sh(f"dmesg | tail -n +{int(state['dmesg']) + 1} | tail -8")
                anomaly(tag, "new kernel messages:\n" + new.strip())
        except ValueError: pass
    log(f"  board: {s.strip()}")
    act = [l for l in sh("cat /run/debaz/status 2>/dev/null").splitlines()
           if l.startswith(("lfo ", "audio out", "cue:")) or (l.startswith("slot ") and any(w in l for w in (": movie", ": lua", ": ascii", ": slit")))
           or ": anim" in l]
    if act: log("  still active (/run/debaz/status): " + "; ".join(act))
    state.clear(); state.update(kv)

def anomaly(case, what):
    anomalies.append((case, what)); log(f"  ANOMALY [{case}] {what}")

def case(name, fn, settle=0.3):
    drain()
    try: fn()
    except Exception as e: anomaly(name, f"harness exception {e!r}")
    time.sleep(settle)
    r = ping()
    if r is None:
        anomaly(name, "debazd does not answer (2 s)")
        for _ in range(30):	# systemd restart, resume
            time.sleep(1)
            if ping() is not None: break
        log(f"  back after: {name}")
        board_check(name)
    elif r > 500: anomaly(name, f"slow ping {r:.0f} ms")
    return r

# ---- corpus: /state targets (address + typed args) ----
def corpus():
    p = os.path.join(OUT, "corpus.json")
    if not os.path.exists(p):
        subprocess.run([sys.executable, os.path.join(os.path.dirname(__file__), "oscstate.py"), "save", IP, p], check=True)
    t = json.load(open(p))
    return [(a, [v for _, v in args]) for a, args in t if not a.startswith(NEVER)]

# ============================ groups ============================
def g_osc():
    log("== osc: malformed packets")
    bad = {
        "empty": b"", "1byte": b"/", "no-null": b"/ping", "path-only": pad(b"/ping"),
        "no-comma-tags": pad(b"/ping") + pad(b"ii"), "tags-no-data": pad(b"/fx/hue/deg") + pad(b",ff"),
        "int-truncated": pad(b"/hdmi/0/gain/r") + pad(b",i") + b"\0\0",
        "string-unterminated": pad(b"/img/9/file") + pad(b",s") + b"abcd",
        "blob-huge": pad(b"/lfo/0/seq") + pad(b",b") + struct.pack(">i", 0x7fffffff),
        "blob-negative": pad(b"/lfo/0/seq") + pad(b",b") + struct.pack(">i", -8) + b"abcd",
        "unknown-tags": pad(b"/lfo/0/rate") + pad(b",xyzhtdcrm") + b"\0" * 64,
        "40-ints": osc("/lfo/0/seq", *range(40)), "1000-char-path": osc("/" + "a" * 1000),
        "8k-string": osc("/img/9/file", "x" * 8100), "max-udp": osc("/lfo/0/seq", "0.5 " * 16000),
        "bundle-trunc": b"#bundle\0", "bundle-size-over": b"#bundle\0" + b"\0" * 8 + struct.pack(">i", 9999) + osc("/ping"),
        "bundle-size-neg": b"#bundle\0" + b"\0" * 8 + struct.pack(">i", -4) + osc("/ping"),
        "bundle-size-0": b"#bundle\0" + b"\0" * 8 + struct.pack(">i", 0) * 50,
        "bundle-nested-200": None, "garbage-4k": bytes(random.getrandbits(8) for _ in range(4096)),
        "slash": osc("/"), "double-slash": osc("//"), "pat-open-bracket": osc("/lfo/[", 1), "pat-open-brace": osc("/lfo/{0,1/on", 1),
        "pat-reverse-range": osc("/lfo/[9-0]/on", 0), "pat-stars": osc("/*/*/*/*/*/*"), "pat-star-only": osc("*"),
        "pat-all-on": osc("/*", 0), "pat-qmarks": osc("/????/?/??"), "pat-neg-brace": osc("/lfo/{}/on"),
        "nul-in-path": b"/lfo\0/0/on\0\0\0,i\0\0" + struct.pack(">i", 0),
    }
    nested = osc("/ping")
    for _ in range(200): nested = bundle(nested)
    bad["bundle-nested-200"] = nested
    for name, pkt in bad.items():
        case("osc " + name, lambda p=pkt: send(p))
    board_check("osc malformed")
    log("== osc: mutation fuzz of the /state corpus (20000 packets)")
    c = corpus(); rnd = random.Random(1122); n = 0; t0 = time.time()
    pkts = [osc(a, *v) for a, v in c]
    for i in range(20000):
        p = bytearray(rnd.choice(pkts)); k = rnd.random()
        if k < 0.4:
            for _ in range(rnd.randint(1, 4)): p[rnd.randrange(len(p))] = rnd.getrandbits(8)
        elif k < 0.6: p = p[:rnd.randrange(1, len(p))]
        elif k < 0.8: p = p + bytes(rnd.getrandbits(8) for _ in range(rnd.randint(1, 64)))
        else:
            q = rnd.choice(pkts); cut = rnd.randrange(1, len(p)); p = p[:cut] + q[rnd.randrange(len(q)):]
        send(bytes(p)); n += 1
        if i % 200 == 199:
            time.sleep(0.05)
            if case(f"fuzz batch {i // 200}", lambda: None, 0.1) is None:
                log(f"  the batch: packets {i - 199}..{i}, seed 1122")
    log(f"  {n} packets in {time.time() - t0:.0f} s")
    board_check("osc fuzz")

def g_args():
    log("== args: boundary values on every settable target")
    vals = [0, -1, 2**31 - 1, -2**31, 1e30, -1e30, float("nan"), float("inf"), float("-inf"), "x", "", "../../etc/passwd"]
    c = corpus(); n = 0
    for addr, v in c:
        def run(addr=addr, v=v):
            send(osc(addr))					# no args (query or default)
            for x in vals:
                send(osc(addr, *([x] * max(1, len(v)))))	# every arg the same edge
            send(osc(addr, *(v + [1, 2, 3, "extra"])))		# extra args
            send(osc(addr, *v))					# back to the dump's value
        case("args " + addr, run, 0.05); n += 1
        if n % 100 == 0: board_check(f"args {n}")
    board_check("args end")

def g_lfo():
    log("== lfo: sequencer edges")
    L = lambda *m: [send(osc(*x)) for x in m]
    cases = {
        "seq-empty": [("/lfo/0/seq",), ("/lfo/0/step", "frames", 1), ("/lfo/0/on", 1)],
        "seq-garbage-str": [("/lfo/0/seq", "nan inf -inf 1e39 abc ,,, -0 0x10")],
        "seq-8k-str": [("/lfo/0/seq", "9" * 8000)],
        "seq-1024-then-1": [("/lfo/0/seq", " ".join(["0.5"] * 1024)), ("/lfo/0/seq", 0.3)],
        "dur-all-zero": [("/lfo/0/seq", "0 1 0.5"), ("/lfo/0/dur", "0 0 0"), ("/lfo/0/step", "frames", 2)],
        "dur-negative-nan": [("/lfo/0/dur", "-1 nan inf 1e30")],
        "step-zero": [("/lfo/0/step", "frames", 0), ("/lfo/0/step", "hz", 0), ("/lfo/0/step", "bpm", 0)],
        "step-negative": [("/lfo/0/step", "frames", -5), ("/lfo/0/step", "bpm", -120, -4)],
        "step-tiny": [("/lfo/0/step", "frames", 1e-30), ("/lfo/0/step", "hz", 1e30), ("/lfo/0/step", "bpm", 1e30, 1e30)],
        "step-nan": [("/lfo/0/step", "frames", float("nan")), ("/lfo/0/step", "hz", float("inf"))],
        "clock-self": [("/lfo/0/step", "clock", 0)],
        "clock-loop": [("/lfo/1/seq", "0 1"), ("/lfo/2/seq", "1 0"), ("/lfo/1/step", "clock", 2), ("/lfo/2/step", "clock", 1),
                       ("/lfo/1/on", 1), ("/lfo/2/on", 1)],
        "clock-chain-16": [("/lfo/%d/seq" % k, "0 1") for k in range(16)] + [("/lfo/%d/step" % k, "clock", k - 1) for k in range(1, 16)]
                          + [("/lfo/0/step", "frames", 1), ("/lfo/*/on", 1)],
        "clock-out-of-range": [("/lfo/3/step", "clock", 99), ("/lfo/3/step", "clock", -1)],
        "glide-nan": [("/lfo/0/ease", "smooth"), ("/lfo/0/glide", float("nan")), ("/lfo/0/glide", float("inf")), ("/lfo/0/ease", 99)],
        "self-trigger-every-step": [("/lfo/5/seq", "0 1"), ("/lfo/5/step", "frames", 1), ("/lfo/5/target", "/lfo/5/trigger"),
                                    ("/lfo/5/every", "step"), ("/lfo/5/on", 1)],
        "self-seq-rewrite": [("/lfo/6/seq", "0 1"), ("/lfo/6/step", "frames", 1), ("/lfo/6/target", "/lfo/6/seq $f6 $f6 $f6"), ("/lfo/6/on", 1)],
        "lfo-targets-all-lfos": [("/lfo/7/target", "/lfo/*/rate $f7"), ("/lfo/7/range", 0, 1e9), ("/lfo/7/on", 1)],
        "every-weird": [("/lfo/0/every", -5), ("/lfo/0/every", 2**31 - 1), ("/lfo/0/every", "")],
        "rate-extreme": [("/lfo/8/rate", 1e30), ("/lfo/8/frames", 2**31 - 1), ("/lfo/8/rate", float("nan")), ("/lfo/8/on", 1)],
        "phase-huge": [("/lfo/0/phase", 1e30), ("/lfo/0/phase", -1e30), ("/lfo/0/phase", float("nan"))],
        "sync-loop": [("/lfo/1/sync", 2), ("/lfo/2/sync", 1), ("/lfo/1/on", 1), ("/lfo/2/on", 1)],
        "sync-chain-16": [("/lfo/%d/sync" % k, k - 1, float(k * 7)) for k in range(1, 16)] + [("/lfo/0/rate", 3.0), ("/lfo/*/on", 1)],
        "sync-delay-extreme": [("/lfo/3/sync", 0, 1e30), ("/lfo/3/delay", -5.0), ("/lfo/3/delay", 2**31 - 1), ("/lfo/3/sync", 99), ("/lfo/3/sync", 3)],
        "sync-plus-clock": [("/lfo/4/seq", "0 1 0.5"), ("/lfo/4/step", "clock", 5), ("/lfo/4/sync", 5, 10.0), ("/lfo/5/seq", "1 0"),
                            ("/lfo/5/step", "clock", 4), ("/lfo/4/on", 1), ("/lfo/5/on", 1)],
        "clock-align-delay": [("/lfo/10/seq", "0 1 0.5"), ("/lfo/10/step", "clock", 11), ("/lfo/10/align", 1), ("/lfo/10/delay", 1e9),
                              ("/lfo/11/seq", " ".join(["0.5"] * 1024)), ("/lfo/11/step", "frames", 1), ("/lfo/10/on", 1), ("/lfo/11/on", 1)],
        "fast-all-4k": [("/lfo/fastrate", 4000.0)] + [("/lfo/%d/fast" % k, 1) for k in range(16)] +
                       [("/lfo/%d/rate" % k, 1e6) for k in range(16)] + [("/lfo/0/target", "/lfo/1/rate $f0"), ("/lfo/*/on", 1)],
        "fast-followers": [("/lfo/2/sync", 3), ("/lfo/2/fast", 1), ("/lfo/4/step", "clock", 3), ("/lfo/4/fast", 1), ("/lfo/3/fast", 1),
                           ("/lfo/3/seq", "0 1 0.5"), ("/lfo/3/step", "hz", 1e6)],
        "fastrate-extremes": [("/lfo/fastrate", 0.0), ("/lfo/fastrate", -5.0), ("/lfo/fastrate", 2**31 - 1), ("/lfo/fastrate", 1000.0)],
        "curve-steps": [("/lfo/9/curve", -1), ("/lfo/9/curve", 1e30), ("/lfo/9/steps", -3), ("/lfo/9/steps", 2**31 - 1), ("/lfo/9/on", 1)],
    }
    for name, msgs in cases.items():
        def run(msgs=msgs):
            L(*msgs); time.sleep(1.0)	# let the ticks run
        case("lfo " + name, run, 0.3)
    st = query("/state", t=3.0)
    if b"/state/end" not in st: anomaly("lfo state", "the /state dump did not end after the LFO cases")
    send(osc("/lfo/*/on", 0)); send(osc("/lfo/*/target"))
    board_check("lfo")

def g_slots():
    log("== slots: process and slot races")
    M = "frac.mkv"
    def storm():
        for k in range(50):
            send(osc("/movie/6/play", M, 0, 0)); send(osc("/movie/6/stop"))
    case("movie play/stop x50 no wait", storm, 3)
    case("movie play x20 no stop", lambda: [send(osc("/movie/6/play", M, 0, 0)) for _ in range(20)], 4)
    send(osc("/movie/6/stop")); time.sleep(2); board_check("after storms (leftover processes?)")
    case("movie on capture slot 4", lambda: send(osc("/movie/4/play", M, 0, 0)), 2)
    case("movie on black slot 11", lambda: send(osc("/movie/11/play", M, 0, 0)), 2)
    case("movie on all 12 slots", lambda: [send(osc("/movie/%d/play" % s, M, 0, 0)) for s in range(12)], 8)
    board_check("12 movies (memory guard?)")
    send(osc("/movie/*/stop")); time.sleep(3)
    for nm in ["../../etc/passwd", "", "x" * 300, "nosuch.mkv", "stress1800.wav", "flyer-addy.png", ".hidden", "a b.mkv", "frac.mkv;reboot"]:
        case(f"movie name {nm[:30]!r}", lambda nm=nm: send(osc("/movie/6/play", nm, 0, 0)), 1)
    for pos in [(1919, 1079), (5000, 5000), (-5000, -5000), (2**31 - 1, 2**31 - 1), (-1, 0)]:
        case(f"movie pos {pos} slot 10", lambda pos=pos: (send(osc("/movie/10/pos", *pos)), send(osc("/movie/10/play", M, 0, 0))), 3)
        send(osc("/movie/10/stop"))
    send(osc("/movie/10/pos", 0, 0))
    for crop in [(1918, 1078), (-1920, -1080), (2**31 - 1, 0), (-2**31, -2**31), (1, 1)]:
        case(f"crop {crop} display 0", lambda crop=crop: send(osc("/disp/0/crop", *crop)), 0.5)
    send(osc("/disp/0/crop", 0, 0))
    case("lua start/stop x30", lambda: [(send(osc("/lua/9/start", "fb-plasma")), send(osc("/lua/9/stop"))) for _ in range(30)], 4)
    case("lua then movie same slot", lambda: (send(osc("/lua/9/start", "fb-plasma")), time.sleep(1), send(osc("/movie/9/play", M, 0, 0))), 3)
    case("draw on movie slot", lambda: [send(osc("/draw/9/rect", 255, 0, 0, i * 10, 10, 100, 100)) for i in range(100)], 2)
    case("ascii into movie slot", lambda: send(osc("/ascii/9/run", 6)), 1)
    case("ascii from slot 9 into 6 + movie on 6", lambda: (send(osc("/ascii/6/run", 9)), send(osc("/movie/6/play", M, 0, 0))), 3)
    case("slit + movie same slot", lambda: (send(osc("/slit/9/run", 9)), time.sleep(1)), 2)
    case("transforms on a movie slot", lambda: [send(osc(p, *a)) for p, a in [("/draw/9/rotozoom", (3, 1.01)), ("/draw/9/scroll", (4, 0)), ("/draw/9/wave", (10, 0.1))]], 2)
    case("anim missing folder", lambda: send(osc("/anim/0/play", "nosuch", 30)), 1)
    case("movie vf garbage", lambda: send(osc("/movie/9/vf", "hue;rm -rf /;`reboot`")), 2)
    case("movie af unknown", lambda: send(osc("/movie/9/af", "nosuchfilter=1")), 3)
    case("movie fx extremes", lambda: [send(osc("/movie/9/" + k, v)) for k, v in [("mosh", 2**31 - 1), ("bloom", -1), ("corrupt", 1.0), ("trails", 5.0), ("ghost", -3.0), ("pause", 1), ("pause", 0)]], 2)
    for s in ("6", "9", "*"): send(osc(f"/movie/{s}/stop"))
    send(osc("/lua/9/stop")); send(osc("/ascii/*/run", -1)); send(osc("/slit/*/stop")); time.sleep(3)
    board_check("slots end (leftover processes?)")

def g_modes():
    log("== modes: output mode switches")
    cap = query("/capture/status")
    if b"/capture/status" in cap and b"/capture/status\0\0,iiis" in cap and cap.split(b",iiis")[1][:4] != b"\0\0\0\0":
        log("  the capture has an input: SKIPPED"); return
    modes = ["1280x720", "640x480", "1920x1080x30Hz", "1024x768", "800x600", "1280x1024", "1280x720x30Hz", "1280x720"]
    case("modes back-to-back x8 no wait", lambda: [send(osc("/video/mode", m)) for m in modes], 20)
    for m in ["", "nosuch", "99999x99999", "1280x720x0Hz", "../x"]:
        case(f"mode name {m!r}", lambda m=m: send(osc("/video/mode", m)), 2)
    send(osc("/movie/6/play", "frac.mkv", 0, 0)); send(osc("/disp/0/show", 6)); time.sleep(2)
    for m in ["640x480", "1920x1080x30Hz", "1280x720"]:
        case(f"mode {m} during a movie", lambda m=m: send(osc("/video/mode", m)), 12)
    send(osc("/movie/6/stop")); time.sleep(5)
    log("  mode now: " + query("/video/mode").decode(errors="replace").replace("\0", " ").split("/video/mode")[-1][:60])
    board_check("modes")

def g_audio():
    log("== audio: dzaudio edges")
    sh("sudo dzsynth.sh start >/dev/null 2>&1"); time.sleep(3)
    case("fifo half frames", lambda: sh("printf 'abc' > /tmp/dzin.7; printf '12345' > /tmp/dzin.7; head -c 4097 /dev/urandom > /tmp/dzin.7"), 1)
    case("fifo writer killed mid-stream", lambda: sh("(head -c 9999999 /dev/urandom > /tmp/dzin.8 &) ; sleep 1; pkill -x head"), 1)
    case("fifo flood 10 MB", lambda: sh("head -c 10000000 /dev/zero > /tmp/dzin.9 & sleep 2; kill $! 2>/dev/null"), 1)
    for a in [(99, 3), (-1, 3), (0, 2**31 - 1), (0, -1), (0, 3, float("nan")), (0, 3, 1e30), ()]:
        send(osc("/mix/stream", *a), 9002)
    case("mix bad args", lambda: [send(osc(p, *a), 9002) for p, a in [("/mix/route", (99, 99)), ("/mix/route/mono", (-1, 999, 1.0)),
         ("/mix/preset", ("pair99",)), ("/mix/gain", (float("nan"),)), ("/mix/pair/99/gain", (1.0,)), ("/mix/sf", ("/etc/passwd",)), ("/mix/nosuch", ())]], 1)
    send(osc("/mix/gain", 1.0), 9002)
    send(osc("/movie/5/play", "frac.mkv", 0, 1)); send(osc("/movie/6/play", "Shape-Shifter.mkv", 0, 2)); time.sleep(4)
    log("  streams: " + sh("dzctl -p 9002 -t 800 /mix/streams").strip())
    case("dzaudio restart while 2 movies stream", lambda: (sh("sudo dzsynth.sh stop >/dev/null 2>&1; sleep 1; sudo dzsynth.sh start >/dev/null 2>&1"), time.sleep(4)), 1)
    log("  after restart: streams " + sh("dzctl -p 9002 -t 800 /mix/streams").strip() + "; movie 5 " +
        sh("dzctl -t 500 /movie/5/stats").strip()[:80])
    case("dzaudio stop with movies playing", lambda: (sh("sudo dzsynth.sh stop >/dev/null 2>&1"), time.sleep(3)), 1)
    log("  movie 5 after the stop: " + sh("dzctl -t 500 /movie/5/stats").strip()[:80])
    send(osc("/movie/5/stop")); send(osc("/movie/6/stop")); time.sleep(2)
    board_check("audio")

def g_web():
    log("== web: dzweb edges")
    def http(raw, t=3.0):
        s = socket.create_connection((IP, 8080), timeout=t)
        try:
            s.sendall(raw); d = b""
            while True:
                x = s.recv(65536)
                if not x: break
                d += x
        except socket.timeout: d += b"<timeout>"
        finally: s.close()
        return d
    def webok(tag):
        try:
            r = http(b"GET / HTTP/1.1\r\nHost: x\r\n\r\n")
            if b"200 OK" not in r[:40]: anomaly(tag, f"dzweb GET / -> {r[:60]!r}")
        except OSError as e: anomaly(tag, f"dzweb does not answer: {e}")
    paths = ["/fonts/../../etc/passwd", "/fonts/%2e%2e%2f%2e%2e%2fetc%2fpasswd", "/fonts/..%2f..%2fetc%2fpasswd",
             "/media/img/..%2f..%2f..%2fetc%2fpasswd", "/media/img/%2e%2e/%2e%2e/etc/passwd", "/../../etc/passwd",
             "/media/anim/../../etc/passwd", "/shows/..%2f..%2fetc%2fpasswd.json", "/fonts/" + "A" * 300 + ".ttf", "/%00", "/media/img/%"]
    for p in paths:
        r = http(f"GET {p} HTTP/1.1\r\nHost: x\r\n\r\n".encode())
        if b"root:" in r: anomaly("web " + p, "PATH TRAVERSAL: /etc/passwd served")
        log(f"  GET {p[:50]} -> {r[:15]!r}")
    webok("web paths")
    for name, raw in {"huge-header": b"GET / HTTP/1.1\r\n" + b"X: " + b"a" * 70000 + b"\r\n\r\n",
                      "no-crlf": b"GET / HTTP/1.1", "binary": bytes(range(256)) * 20,
                      "put-len-over": b"PUT /media/img/edge.png HTTP/1.1\r\nContent-Length: 999999999999\r\n\r\nabc",
                      "put-len-neg": b"PUT /media/img/edge.png HTTP/1.1\r\nContent-Length: -5\r\n\r\nabc",
                      "put-bad-name": b"PUT /media/img/../edge.png HTTP/1.1\r\nContent-Length: 3\r\n\r\nabc",
                      "ws-garbage": b"GET /osc HTTP/1.1\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\nSec-WebSocket-Version: 13\r\n\r\n"
                                    + b"\x82\x7f" + struct.pack(">Q", 2**63 - 1) + b"\x00" * 64,
                      "ws-unmasked-close": b"GET /osc HTTP/1.1\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\nSec-WebSocket-Version: 13\r\n\r\n"
                                    + b"\x88\x00" + b"\x89\x7e\xff\xff" + b"x" * 100}.items():
        try: r = http(raw, 2.0)
        except OSError as e: r = repr(e).encode()
        log(f"  {name} -> {r[:40]!r}")
        webok("web " + name)
    socks = []
    try:
        for _ in range(200): socks.append(socket.create_connection((IP, 8080), timeout=3))
    except OSError as e: log(f"  connection {len(socks)}: {e}")
    log(f"  {len(socks)} idle connections open")
    time.sleep(2)
    try:
        r = http(b"GET / HTTP/1.1\r\nHost: x\r\n\r\n", 3)
        log(f"  GET / with them open -> {r[:15]!r}")
    except OSError as e: log(f"  GET / with them open: {e}")
    for s in socks: s.close()
    time.sleep(2)
    webok("web after 200 idle connections")
    sh("rm -f /media/debaz/img/edge.png /media/debaz/img/.edge.png.part")
    log("  dzweb: " + sh("echo pid $(pidof dzweb); systemctl show dzweb -p NRestarts").strip())

def g_resume():
    log("== resume: kill and corrupt the autosave")
    send(osc("/movie/6/play", "frac.mkv", 0, 0)); send(osc("/lfo/0/rate", 0.5)); send(osc("/lfo/0/on", 1)); time.sleep(6)
    case("kill -9 debazd during a fade", lambda: (send(osc("/fx/xfade", 1.0, 3.0)), time.sleep(0.5), sh("sudo kill -9 $(pidof debazd)"), time.sleep(8)), 1)
    board_check("after kill -9 (pid change expected)")
    log("  after: movie 6 " + sh("dzctl -t 500 /movie/6/stats").strip()[:60] + "; leftover ffmpeg " + sh("pidof ffmpeg | wc -w").strip())
    for name, cmd in {"autosave truncated": "sudo truncate -s 100 /run/debaz/autosave.bin",
                      "autosave random": "sudo sh -c 'head -c 20000 /dev/urandom > /run/debaz/autosave.bin'",
                      "autosave empty": "sudo truncate -s 0 /run/debaz/autosave.bin"}.items():
        case(name + " + restart", lambda cmd=cmd: (sh("ls -la /run/debaz/autosave.bin; " + cmd + "; sudo systemctl restart debazd"), time.sleep(8)), 1)
        board_check(name + " (pid change expected)")
    send(osc("/movie/*/stop")); send(osc("/lfo/*/on", 0))

GROUPS = {"osc": g_osc, "args": g_args, "lfo": g_lfo, "slots": g_slots, "modes": g_modes,
          "audio": g_audio, "web": g_web, "resume": g_resume}
want = [a for a in args if a in GROUPS or a == "all"]
if "all" in want: want = list(GROUPS)
if not want: print(__doc__ if __doc__ else "edge.py GROUP...", list(GROUPS)); sys.exit(2)
log(f"=== edge {' '.join(want)} on {BOARD}")
board_check("start")
for g in want:
    t0 = time.time()
    GROUPS[g]()
    log(f"== {g}: {time.time() - t0:.0f} s, anomalies so far {len(anomalies)}")
log("=== anomalies: %d" % len(anomalies))
for c, w in anomalies: log(f"  [{c}] {w.splitlines()[0]}")

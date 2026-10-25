# Fleet control, time sync and transport (design, 2026-10-24)

Status: DESIGN ONLY. Nothing in this file is built yet. Task list and
order: section 5. Background: `ROADMAP.md` "Fleet", `sw/README.md`.

Three parts:

1. Control of many units from one UI, with a different value per unit.
2. A shared clock, so that units can change and play at the same time.
3. Movie transport: speed, pause, seek, skip, reverse (own branch).

## 0. Facts that set the design (measured on the bench board, 2026-10-24)

| Fact | Effect on the design |
| --- | --- |
| All boards have the Xilinx default MAC `00:0a:35:00:1e:53` | Two units cannot share a LAN (same MAC, same DHCP address). A unique MAC is the first task. |
| Linux has 146 MB RAM (97 MB available) | No frame cache in RAM. A reverse buffer of one GOP (about 22 MB) is the maximum. |
| No NTP, chrony or PTP program; no `/dev/ptp*`; busybox has only `rdate` | The clock sync must be our own small protocol in debazd (section 2). |
| Movie decode: mpeg4 720p 36 fps for one stream; 12-20 fps per stream with two streams | Today a 24 fps movie plays SLOWER than real time when it cannot decode fast enough, because `ffmpeg -re` waits but never skips. Playback drifts. |
| Test movies: a keyframe about every 16 frames (0.7 s at 24 fps) | Seek and skip are cheap. Reverse needs a GOP buffer. |
| libavformat/libavcodec 4.4 shared libraries and headers are on the board | A real player (`dzplay`) can link against them. |
| debazd has a vsync thread at 60.03 Hz; `/disp` changes apply right after vsync | Scheduled changes can be frame-exact on one unit. |
| `dz_osc` reads OSC bundles but ignores their time tags | Time tags are free for scheduled execution (section 2.2). |
| Each board has its own pixel clock crystal; no genlock | Units cannot be frame-locked. Best case: the same frame within about one frame period (17 ms). |

## 1. Control of many units from one UI

### 1.1 Model

- **Unit**: one board. Identity = MAC (after the MAC fix). Fields: alias
  ("left-1"), address (ip:port), tags ("wall", "ring", "left"), position
  (order index, and x/y for spatial effects), variant, online state.
- **Selection**: an ORDERED list of units. You make it from tags, from
  "all", or from single unit toggles. The order is important, because a
  spread uses the index of each unit. Default order = position index; you
  can sort by x, by y, or drag the order.
- **Spread**: the rule that makes the value for each unit from the one
  value of a control. Each control can have its own spread.
- **Timing**: when each unit applies the message: now, at one shared
  time T, or staggered (T + i * dt).

### 1.2 Spread modes

Symbols: v = control value, i = index of the unit in the selection
(0..n-1), n = number of units, u = i/(n-1) (0..1), x/y = unit position,
r = a fixed random number per unit (seeded, so the same each time).

| Mode | Value for unit i | Example |
| --- | --- | --- |
| same | v | all displays to slot 5 |
| ramp | a + (b - a) * u | feedback gain 0 on the left unit, 255 on the right |
| offset | v + i * step | slot 5, 6, 7, ... (wraps with mod) |
| mirror | ramp from the centre out | symmetric wall |
| random | v + r * range | slight differences, but the same each time |
| list | list[i mod len] | slots "5 6" alternate across units |
| phase | for LFOs: phase = u | one wave runs across the wall |
| round-robin | only ONE unit gets this send; the next send goes to the next unit | a chase from one control |
| stagger | value "same", time T + i * dt | a wave of changes |
| expression | free formula of v, i, n, u, x, y, r, t | `(v + 40*sin(6.28*u)) & 255` |

The expression mode is the general form. All other modes are presets of it.
This is the same idea as the `$k` templates of the LFO targets, extended
from one unit to many.

### 1.3 UI layout

The "all units" check box in the header changes to a fleet bar.

```
+---------------------------------------------------------------------------+
| DEBAZAROS  [left-1][left-2][centre][right-1][right-2] (+tag: wall ▾)  ⏱ +0.4ms |
|            ^ chips: on = selected; colour = online/offline; drag = order    |
+---------------------------------------------------------------------------+
| Displays  Effects  Oscillators  Paint  Media  Fleet  Cues  Console          |
+---------------------------------------------------------------------------+
|  feedback/r   [=========|--------]  128   (ramp 0→255 ▾)                    |
|               preview:  ▁ ▃ ▅ ▆ █    <- value per selected unit, live        |
|  gain/g       [====|-------------]   64   (same ▾)                          |
|  display 1    [5] -> slots: 5 6 7 8 9    (offset +1 ▾)   timing: at T ▾     |
+---------------------------------------------------------------------------+
```

- With one unit selected, the UI looks as it does today.
- With more than one unit selected, each control shows a small spread
  badge. Click it for a popover: mode, parameters, timing, and a preview
  strip with the value for each selected unit.
- The spread is stored per control in the browser, so a control keeps
  its spread across sessions.

New tabs:

- **Fleet**: a table of units: alias, tags, position, ip, MAC, variant,
  vsync, input lock, clock offset, the movie that plays and its position.
  Edit alias/tags/position in the table. "Identify" shows the alias as
  large text on the unit's displays for 3 s (steady text, no flash).
- **Matrix**: rows = fields you choose, columns = selected units. Each
  cell shows the live value; edit one cell, one row (with a spread), or
  one column.
- **Cues**: a cue = a snapshot of field values + display slots + LFO
  settings for each unit. "Go" sends a cue to all units at one time T,
  with an optional fade time (the hub interpolates fields over the fade).

### 1.4 Where the fan-out happens: the hub

The browser does NOT open one WebSocket for each unit. A hub expands each
message:

```
browser / TouchOSC / Max  --(WebSocket or OSC/UDP)-->  hub  --UDP-->  debazd x N
```

- The hub = `dzweb` with a new option `-H` (hub mode). It runs on the
  laptop (`make NATIVE=1`) or on any one unit. Without `-H`, dzweb works
  as today (one unit).
- The hub keeps the unit registry in a JSON file (alias, tags, position).
  Units come from `/info` broadcasts; the registry adds names to them.
- The hub is the clock reference (section 2), so it can schedule.
- OSC address form for non-browser clients, the same rules as the UI:

| Address | Meaning |
| --- | --- |
| `/@all/disp/1/show 5` | all units, same value |
| `/@wall/...` | units with tag "wall" |
| `/@left-1,centre/...` | units by alias |
| `/@3-7/...` | units by position index |
| `/fleet/spread "<selector>" "<mode>" <params...> "<template>"` | spread send, for example `/fleet/spread "wall" "ramp" 0 255 "/hdmi/1/feedback/r $v"` |
| `/fleet/at <T or +ms> <bundle>` | timed send |

- Replies from units come back with the unit in the address:
  `/from/left-1/value ...`. The UI uses this for the Matrix and Fleet tabs.

### 1.5 Test without a fleet

Run several simulated units on the laptop: `debazd -n -p 19500`,
`-p 19501`, and so on, and register them as `127.0.0.1:19500` etc. in
the hub. Two small changes are necessary first: the debazd lock file
(`/tmp/debazd.lock`) must include the port (today a second simulated
unit refuses to start), and `/units` must accept ip:port.

## 2. Shared clock and time code

### 2.1 Targets

| Level | Accuracy | How | Status |
| --- | --- | --- | --- |
| A: rough | within about 1 frame (17-40 ms) | software clock sync + scheduled changes + player that follows the clock | this design |
| B: frame-locked | same frame, same vsync | genlock: common pixel clock or VTC reset between boards (gateware, cable) | not planned |

Level A is enough for "units change at the same time" and "movies stay
together for hours". It cannot make a flash on two units land in the same
vsync every time.

### 2.2 Show clock

- Each debazd keeps a **show clock** = `CLOCK_MONOTONIC` + offset. It does
  not change the Linux system time.
- The hub is the reference. Each unit sends `/clock/ping t1` once per
  second. The hub replies `/clock/pong t1 t2 t3` (receive and send time).
  The unit calculates offset and round-trip time like NTP, keeps the
  sample with the shortest round trip of the last 8, and slews the offset
  slowly (no steps after the first lock).
- Expected accuracy on one switched LAN: better than 1 ms. That is small
  against one frame (17 ms).
- `/clock` on a unit replies: offset, round trip, locked. The Fleet tab
  shows it.
- Later option: chrony in the PetaLinux rebuild (task 4) can replace this
  protocol. PTP needs a PTP clock device; the Zynq GEM has hardware time
  stamps, but this kernel does not give `/dev/ptp0`. Not needed for level A.

### 2.3 Scheduled execution with OSC time tags

- An OSC bundle has a time tag. debazd today ignores it. New: when the
  time tag is in the future, debazd keeps the bundle in a queue, and the
  vsync thread applies it at the first vsync after the time tag (show
  clock).
- The hub sends timed bundles with T = now + lead (default 100 ms, more
  than the LAN delay). All units apply at T, within clock error + one
  frame.
- The same queue gives frame-exact sequences on one unit (a strobe pattern
  sent in advance), so it is useful before there is a fleet.
- Time tag "immediately" (value 1) works as today.

### 2.4 Movies that follow the clock

A movie started at show time T0 with rate R must show, at show time t:

```
position = ((t - T0) * R + start) mod duration
frame    = floor(position * fps)
```

The player calculates this at each vsync and shows that frame:

- decoder late by less than one GOP: drop frames (decode, do not show);
- decoder late by more than one GOP: seek to the next keyframe after the
  target position;
- decoder early: keep the current frame.

Thus units never drift, even if one unit decodes slower. The cost: a slow
unit skips frames.

**The current player cannot do this.** `ffmpeg -re | fbfeed` has no
position output, cannot seek while it runs, and plays slowly when decode
is too slow. The real fix is `dzplay` (section 3).

**Interim (before dzplay):** start all units with one timed
`/movie/<s>/play` (same T), and use media that decodes faster than real
time on every unit (for example 720p at 24 fps when only ONE movie plays
per unit, or 640x360 when two play). Then `-re` keeps each unit on its
own system clock, and units stay together within a few frames for a long
time. A restart at a known T (for example at each loop) removes any drift.

### 2.5 External time code

- The board has no audio input and no MIDI, so LTC and MTC are not
  possible directly.
- The hub can take time from an external show controller (QLab, Ableton,
  TouchDesigner) over OSC, for example `/fleet/clock <seconds>`, and use it
  as the reference for T0. Units only see the show clock.

## 3. Transport (own branch: `transport`)

Yes, this is a separate branch. It replaces the movie pipeline that
`/movie` uses now, it adds a binary that links libav, and it needs
performance work on the board.

### 3.1 dzplay

- New program `sw/dzplay/`. One process for each slot that plays.
- It links libavformat/libavcodec 4.4 (shared libraries on the board; copy
  the board headers into `sw/third_party/` for the cross build, or build
  on the board).
- It decodes to yuv420p and converts with NEON (`dz_yuv.c`, as `fbfeed -y`
  does now) into the slot.
- It knows the media position. It seeks with `av_seek_frame`, and it
  follows the show clock (section 2.4).
- debazd stays the only OSC owner. It starts dzplay and controls it over a
  Unix datagram socket. dzplay sends status back (position, fps, dropped
  frames).

### 3.2 OSC addresses

| Address | Arguments | Effect |
| --- | --- | --- |
| `/movie/<s>/play` | name [T0] | start (at show time T0) |
| `/movie/<s>/pause`, `/resume` | | hold / continue the frame |
| `/movie/<s>/stop` | | stop the player |
| `/movie/<s>/rate` | f | speed: 1 = normal, 0.5 = half, -1 = reverse |
| `/movie/<s>/seek` | seconds [T] | go to a position (at time T) |
| `/movie/<s>/skip` | ±seconds | jump forward or back |
| `/movie/<s>/step` | ±frames | one frame (when paused) |
| `/movie/<s>/loop` | a b | loop between a and b seconds (none = whole file) |
| `/movie/<s>/sync` | 0/1 | follow the show clock (default 1 in a fleet) |
| `/movie/<s>` | | reply `/movie/<s>/pos seconds frame duration rate dropped` |

LFO targets work with these addresses, for example a slow sine on
`/movie/3/rate $f0` for "breathing" speed.

### 3.3 Limits

| Function | Limit | Reason |
| --- | --- | --- |
| rate up to about 1.5 (24 fps media, one stream) | decode speed (36 fps) | above that: skip frames |
| fast scan (2x-8x) | decode keyframes only | one keyframe every 0.7 s gives about 8x without load |
| reverse | one stream at a time, about real speed | decode one GOP forward into a ring (16 x 1.38 MB = 22 MB of the 97 MB free), show it backwards |
| two movies at once | 12-20 fps each (measured) | use 640x360 media, or one movie per unit |

Media preparation makes transport better: a short GOP (keyframe every 8
frames) makes reverse and seek faster. A laptop script
`sw/tools/prepare_media.sh` can transcode with the correct size, codec
and GOP. First measure which codec decodes fastest on the A9 (mpeg4
today; h264 in software is probably slower).

### 3.4 Steps on the branch

1. dzplay plays one file into a slot at real time, with frame drop
   (replaces `ffmpeg | fbfeed -y` for `/movie`).
2. pause, seek, skip, step, loop, position reply.
3. rate > 0 (drop or keyframe-only), then reverse (GOP ring).
4. Follow the show clock (needs section 2.2).
5. Measure on the board, merge.

## 4. Decisions (user, 2026-10-24)

1. **The hub runs on an external laptop** (`dzweb -H`, `make NATIVE=1`).
   A hub on a unit is not necessary now. The laptop is also the clock
   reference.
2. **Sync within one frame is enough.** Level A (section 2.1). No genlock.
3. **Both outputs stay as capable as possible.** Two playback profiles:

| Profile | Movies per unit | Media | Transport |
| --- | --- | --- | --- |
| 1-out full | one movie, on one display (the other display: live input, paint, or the same movie through a view, see below) | 720p, 24-30 fps | rate up to about 1.5, fast scan, reverse |
| 2-out reduced | two different movies, one per display | 640x360 (or 720p at 12-15 fps) | rate up to 1, fast scan; reverse only for one stream |

   The decode budget (36 fps of 720p mpeg4 for each unit, measured) is
   shared by all the movies that play. dzplay must measure its own decode
   rate and report it, so that the UI can show when a profile is too heavy.
   With the planned display views (ROADMAP.md section 9), ONE decoded movie
   can fill two displays with different crops, at no extra decode cost.

## 5. Order of work

| # | Task | Depends on | Branch |
| --- | --- | --- | --- |
| F1 | Unique MAC per board (U-Boot `ethaddr`, see ROADMAP "Fleet") | - | clanker |
| F2 | debazd: lock file per port; `/units` with ip:port (fleet test on one laptop) | - | clanker |
| F3 | Hub mode in dzweb: registry, `/@selector` fan-out, `/from/<unit>` replies; fleet bar with "same" spread | F2 | clanker |
| F4 | Spreads (all modes), preview strip, Fleet tab, Identify | F3 | clanker |
| F5 | Show clock (`/clock/ping`) + time-tag queue in debazd | - | clanker |
| F6 | Timed sends from the hub (`/fleet/at`, timing per control); interim movie sync with timed `/movie/play` | F3, F5 | clanker |
| F7 | dzplay with transport (section 3.4) | - (step 4 needs F5) | transport |
| F8 | Matrix and Cues tabs (snapshot, timed go, fade) | F4, F6 | clanker |

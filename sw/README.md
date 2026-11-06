# sw/ - DEBAZAROS userspace software

Built with plain make: the gcc from Vitis 2022.2 for development, the Yocto
cross compiler in the image (PetaLinux recipe `debaz-sw`). No Vitis project,
no BSP.

| Path | What it is |
| --- | --- |
| `debazd/` | The hardware daemon: the one owner of the PL registers and frame slots, controlled over OSC/UDP (port 9000). One file per area: `disp.c` (display routing, crops, `/video/mode`), `dds.c` (DDS patterns, AWG, audio scope), `lfo.c`, `trans.c` (field ramps, cross-fade), `state.c` (state dump, snapshots), `cue.c` (cues, scenes, shows), `react.c` (audio analysis), `ascii.c`, `fx.c` (colour matrix, key), `sound.c` (audio files, recording, sources), `audio.c` (48 kHz rate, HDMI_2 replug), `pwm.c`, `io.c`. Each file starts with its OSC addresses. |
| `dzweb/` | Web app: a small HTTP + WebSocket server on the board (port 8080) and the browser pages in `dzweb/www/`. See "Web app" below. |
| `dzctl/` | Command-line OSC client for debazd. Runs on the board and on the laptop. |
| `lib/` | `libdz`: register mapping (`dz_map`), named register fields (`dz_fields`), display routing and capture status (`dz_vdma`), OSC wire format (`dz_osc`), drawing and movies (`dz_draw`), text (`dz_text`), program lookup (`dz_path`). |
| `hdmi2/` | Display bring-up (video mode, VDMAs, VTC, dynclk; capture only when debazd does not run). Moved from the old Vitis workspace (jerkspace). |
| `fbfeed/` | Copies raw frames from stdin into a frame slot (movies; NEON yuv420p -> RGB, trails, ghost). |
| `dzmosh/` | Live datamosh in the movie pipe (MPEG-4 Part 2 only): drops key frames, repeats P frames, flips bits, pauses; sets the frame pace. Commands on `/tmp/dzmosh.<slot>` (debazd `/movie/<s>/mosh\|bloom\|corrupt\|pause`). |
| `include/hw_map.h` | Register base addresses, GENERATED from the block design (`make hwmap`). Must match the bitstream that runs. |
| `tools/` | Board scripts (`dzstart.sh`, `plreload.sh`, `dzsetup.sh`, `capstat.sh`, ...), laptop scripts (`mkmedia.sh`, `pushfonts.sh`), `selftest.sh`, `image/` (the image's systemd unit and default config), `vscode/` (debug setup). |

## Build and install

```sh
make              # ARM binaries -> out/arm/   (hdmi2: out/arm/hdmi2.elf)
make NATIVE=1     # x86 binaries -> out/native/ (dzctl for the laptop)
make test         # host self test, simulated hardware
make install TARGET=ebaz@<board-ip>   # copy to the board: /home/ebaz/bin/, /home/ebaz/www/
make DEBUG=1      # -O0 -g for gdb
make image-install DESTDIR=<dir>      # the image layout (used by the recipe)
```

Two installs can be on one card (2026-11-01, `lib/dz_path.h`):

| | Programs | Web app | Comes from |
| --- | --- | --- | --- |
| Image | `/usr/bin` | `/usr/share/debaz/www` | PetaLinux recipe `debaz-sw` (builds this folder) |
| Development | `/home/ebaz/bin` | `/home/ebaz/www` | `make install` |

The development copy wins: debazd starts `dz_prog("fbfeed")` etc. from
`$DZ_BIN`, else `/home/ebaz/bin`, else `/usr/bin`; the scripts choose their
folder the same way; dzweb serves `/home/ebaz/www` when it has an
`index.html`. Remove `/home/ebaz/bin` and `/home/ebaz/www` to go back to the
image's software.

## Bring-up on the board

`tools/dzstart.sh` brings a booted board to the working state. The image runs
it at boot (`debaz.service`, log: `journalctl -u debaz`); by hand:
`sudo sh <bin>/dzstart.sh` (`-n` = no PL load).

1. If BITSTREAM is set in the config: load it (`plreload.sh`: stops hdmi2
   and debazd, soft-resets the capture, loads, starts hdmi2 + debazd, then
   `dzsetup.sh`). Empty = keep the bitstream of BOOT.BIN.
2. Else start what does not run: hdmi2 (video mode), debazd; after a
   power-up also `dzsetup.sh` (mixer boot setup and sync delays: without it
   HDMI_0 is black).
3. dzweb as user ebaz (port 8080).
4. Checks: processes, `/ping`, VDMA status, capture.

Config: `/home/ebaz/dzstart.conf` (per card), else `/etc/debaz/dzstart.conf`
(image): `BITSTREAM=`, `HDMI2_ARGS="-r 1280x720"`, `WEB=1`.
The video mode can change later without a reboot: `/video/mode 800x600`.

Only one debazd runs at a time (`/tmp/debazd.lock`). hdmi2 does not touch
the capture while debazd holds that lock.

## OSC interface (summary)

Full list: `dzctl /list`, or `debazd -l` (prints address, register, bits).

| Address | Arguments | Effect |
| --- | --- | --- |
| `/ping`, `/info` | | `/pong`; variant, field count, slots, usable slots |
| any field, e.g. `/hdmi/0/gain/rgb` | value(s) | set it (int = raw, float = 0..1) |
| any field | none | reply `/value path raw normalized` |
| `/disp/<d>/show` | slot | display d shows DDR slot (0..5) |
| `/disp/<d>/home` | | display 0 -> slot 0 (fb0), display 1 -> slot 2 |
| `/disp/<d>/capture` | | display d shows the live capture frame |
| `/disp/<d>` | | reply: slot that display d shows (-1 = not a slot) |
| `/capture/status` | | plocked, alocked, frames flowing, overflow, DMA status |
| `/fields` | [prefix] | one `/field path lo width unit ro help` per field, then `/field/end count` |
| `/files` | `img`, `movies`, `audio` or `fonts` | one `/file name` per file in `/media/debaz/<kind>` (fonts: `/usr/share/fonts`), then `/file/end count` |
| `/subscribe` | [port] | send events to me: `/event/io`, `/event/hpd`, `/event/capture`, `/event/video`, `/event/mode`, ... |
| `/video/mode` | [name] | the output mode of both displays (`/video/modes`); a name restarts hdmi2 `-r name` |
| `/draw/<slot>/...`, `/img/...`, `/movie/...`, `/surface/...` | | drawing and playback, see `lib/dz_draw.h` |
| `/fx/hue`, `/fx/map`, `/fx/matrix`, `/fx/key/...` | | colour matrix and colour key on HDMI_0, see "Colour FX" |

Field groups: `/hdmi/0/...` (gain, osc sin/phase divider and offset, mixer
pixel delay), `/hdmi/1/...` (own-video gain, feedback gain from HDMI_0, sine
and saw layer gains, dividers, offsets), `/dds/0|1/{hz,pinc,enable,valid}`,
`/mixer/0..8/{gain/0..4,mode,k,stream,lo,hi}`, `/io/...` and `/capture/...`
(read only). Wildcards work: `dzctl "/mixer/*/mode" 35`.

Colour order: every `r`/`g`/`b` field writes the correct pixel lane. The
display bus is RBG ([23:16] R, [15:8] B, [7:0] G), and the fields hide that.

DDS: a write to `/dds/<n>/hz` or `/pinc` also sets bit 31 (TVALID enable).
Without that bit the DDS ignores the new value.

## Web app (dzweb)

`dzweb` serves the pages in `/home/ebaz/www` (else the image's
`/usr/share/debaz/www`) and connects browsers to
debazd. The browser sends OSC packets as WebSocket frames, and dzweb sends
them to debazd over UDP. Replies and events come back the same way. Thus the
browser uses the same OSC addresses as `dzctl`.

**Fleet page (2026-11-04): `http://<any unit>:8080/fleet.html`** (also the
"Fleet" link in the header). The browser opens a WebSocket to the dzweb of
every unit and sends to each one itself: no unit relays for another (CORS
does not cover WebSockets; dzweb accepts any page, and its HTTP replies
carry `Access-Control-Allow-Origin: *`). Units: Scan (`/units` of the
serving unit) or Add by IP; list, order and selection stay in the browser.
Per unit: connection, `/ping` round trip, mode, vsync, debazd CPU, cue,
Identify (`/led/red` blinks), its own UI. For the selected units, in list
order: any OSC line, cue GO / Next / Back / Stop, blank / home, video mode,
and a spread (one value per unit: same, ramp, reverse, alternate, random).
Replies show per unit in the log. Tested on three boards (page from .210
and from .104): 3 units in 0.2 ms per command, an offline unit shown as
such, every unit's own error reply in the log.

```sh
dzweb &      # -p 8080  -w <www>  -m /media/debaz  -d 127.0.0.1 -o 9000  -v   (dzstart.sh starts it as ebaz)
```

| URL | What it does |
| --- | --- |
| `/` and other flat file names | static files from the www folder (no sub folders, `..` gives 404) |
| `/units` | broadcasts `/info` on the LAN; JSON list of units (ip, variant, slots, host, MAC) |
| `/osc` | WebSocket. Each binary frame is one OSC packet (message or bundle). |
| `GET /media` | JSON: free bytes on the disk, files in `img/`, `movies/`, `audio/` (name, size, mtime) |
| `GET /media/<kind>/<name>` | download a file (`?dl`: as an attachment) |
| `PUT /media/<kind>/<name>` | upload a file (raw body with Content-Length) |
| `DELETE /media/<kind>/<name>` | delete a file |

Tabs in the app:

- **Displays**: slot grid per display (12 slots), Home, Live input, Blank,
  frame sequencer. The page asks for a confirmation before a fast black
  strobe (photosensitivity).
- **Wall**: output mode (`/video/mode`), input size, crops per display on a
  tile map, manual crop sliders, a crop exerciser that counts video events.
- **Effects**: cross-fade card, then all register fields. The page gets them
  from `/fields`, so a new field in `dz_fields.c` shows without a change to
  the page. Mixer: a table with 9 channels (mode, K, lo, hi, stream B, 5 gains).
- **Oscillators**: the 16 LFOs, with the audio source row (`/audio/react`).
  debazd reports only value and on/off, so the page keeps its own copy of
  the settings in the browser: "Send all settings" sends that copy again
  (after a debazd restart). A copy can be out of step with the board (the
  On button, for example) when another client changed the LFO.
- **DDS**: patterns, audio scope per channel, AWG draw panel, step table.
- **Paint**: brush, line, shapes, gradients, paint bucket (fill), colour
  pick, pixel text, TrueType text and sprites on a 1280x720 canvas, in board
  coordinates. The canvas shows a local preview only. Board effects (grab,
  transforms, Load) show on the display. **Live** sends each stroke at once;
  **Batch** keeps the drawing in the browser with Undo / Redo (Ctrl+Z,
  Ctrl+Shift+Z) until **Send** (Enter) replays it in order. Colour card: S/V
  square, hue, alpha, hex/RGB, recent colours, palette. Brush card: sample,
  presets, size / hardness / opacity / fill tolerance. Keys: B L R E P G F I
  T = tools, [ ] = size, X = swap colours, Alt+click = pick. "Save frame"
  card + timing sheet editor: see Image sequences.
- **Media**: upload (drop files or choose them), download and delete images,
  movies and audio; use them as sprites, draw them, play movies; datamosh and
  movie effects cards (with live parameter dialogs), ASCII card, sprites from
  text, colour key.
- **Audio**: output sources, file players, recording.
- **Cues**: shows, scenes, cues (keyframe / delta), looks, transitions.
- **Console**: all replies and events, and a command line
  (`/disp/1/show 5`, `"quoted text"` = one string, numbers with a point = float).

Header: unit selector and "Scan" (`/units`). With "all units" set, each
control goes to all units found, not only to the selected unit.

Test without a board: `make NATIVE=1`, then
`out/native/debazd -n -p 19500 &` and
`out/native/dzweb -p 18080 -o 19500 -w dzweb/www`, open `http://127.0.0.1:18080/`.

Media transfer rules:

- The media folders are `<-m>/img` and `<-m>/movies`, the same folders
  that debazd reads. dzweb makes them if they do not exist.
- Names: `A-Z a-z 0-9 . _ -` only, 96 characters maximum, no leading dot
  (the same rule as debazd). The page changes other characters to `_`.
- An upload writes `.<name>.part` and renames it when all bytes are on the
  disk. If the connection stops, dzweb deletes the part file.
- dzweb refuses an upload that leaves less than 64 MB free (507), or that is
  larger than 4 GB (413). The page also checks this before it sends.
- Transfers move in chunks in the poll loop. Measured on the board
  (2026-10-24): upload 6.2 MB/s, download 11.8 MB/s (100 Mbit/s Ethernet);
  OSC `/ping` through the WebSocket during an upload: median 21 ms, max 60 ms.
- The root file system of the bench board is 3.8 GB with about 310 MB free.

Limits: 16 browsers at a time, 64 KB per WebSocket frame, no fragmented
frames. No login: use the app only on a closed LAN. Anyone on the LAN can
upload and delete media.

## Video painter

`/draw/<slot>/...` paints into a DDR slot; any display can show that slot.
Full list in `lib/dz_draw.h`. Painting operations (Oct 2026):

| Address | Arguments |
| --- | --- |
| `/draw/<s>/brush` | r g b x y radius [hardness 0..1] — soft round stamp |
| `/draw/<s>/stroke` | r g b radius hardness x0 y0 x1 y1 [x y ...] — soft polyline |
| `/draw/<s>/line` | r g b x0 y0 x1 y1 [width] — 1 = thin, else round |
| `/draw/<s>/fade` | amount 0..1 [r g b] — pull all pixels toward a colour: trails |
| `/draw/<s>/blend` | `normal`, `add` (light painting), `lighten`, `multiply` |
| `/draw/<s>/alpha` | 0..1 for later operations |
| `/draw/<s>/flood` | r g b x y [tol 0-255, default 32] — paint bucket: the connected area of similar colour, filled with the slot's `/fill` (solid, linear across the area, radial from the click) |
| `/surface/<s>/grab` | [src slot] — copy the real slot content (live capture = 4, a playing movie) into the painting buffer: freeze it, then paint on it |
| `/surface/<s>/peek` | x y — reply `/pixel s x y r g b` |
| `/surface/<s>/save` | name — the painting buffer as `name.png` in `/home/ebaz/img`, encoded by a background ffmpeg (ready about 1 s later; `x.ppm` = PPM at once) |
| `/img/<s>/load` | name [x y w h] — draw an image file back (scaled; whole frame by default) |

The web app's Paint page has these as the **Image** card: "save as" (a time
stamp name by default) and "recall" (the board's images, newest first; Load
also updates the browser preview). Saved images show in Media too.

Plus the older fills, gradients, images and movies (`lib/dz_draw.h`).
Every operation stops a movie that plays into the same slot.

Shapes (`lib/dz_shape.h`): rotation, gradient fill, polygons and stars.
`thickness` 0 or absent = filled; an outline stays inside the shape size.
`angle` in degrees, clockwise, about the shape centre.

| Address | Arguments |
| --- | --- |
| `/draw/<s>/fill` | `solid`, or `linear` r2 g2 b2 [deg], or `radial` r2 g2 b2. Stays set for later shapes on that slot. Colour 1 = the r g b of each shape. |
| `/draw/<s>/rect` | r g b x y w h [thickness] [angle] |
| `/draw/<s>/square` | r g b x y size [thickness] [angle] |
| `/draw/<s>/circle` | r g b cx cy radius [thickness] |
| `/draw/<s>/ellipse` | r g b cx cy rx ry [thickness] [angle] |
| `/draw/<s>/polygon` | r g b cx cy rx ry sides [thickness] [angle] |
| `/draw/<s>/star` | r g b cx cy rx ry points [inner] [thickness] [angle] — inner 0 = classic star |
| `/draw/<s>/starpoly` | r g b cx cy rx ry n k [thickness] [angle] — {5/2} pentagram, {6/2} star of David; filled = even-odd (open centre) |
| `/draw/<s>/gradient/radial` | r1 g1 b1 r2 g2 b2 [cx cy radius] — whole slot |

The new shapes are antialiased. rect/ellipse with angle 0 and fill
`solid` keep the old exact pixels. Measured on the board (2026-10-24):
rotated 600x400 rect 23 ms, radial-filled ellipse 39 ms, 24 px rotated
ellipse outline 49 ms, star or pentagram (r 300) 13 ms, full-screen radial
gradient 115 ms. Web app Paint tab: tools rect, ellipse, shape; Ctrl =
equal width and height, Shift while dragging = rotate (Ctrl+Shift: 15°).

Try it: `dzctl /disp/1/show 5`, then on the laptop
`python3 sw/tools/osc_paint_demo.py <board-ip> 5` (light painting with
trails, strokes, painting over a frozen capture frame; it prints the fps).

Measured on the board (one bundle per frame, auto present):

| Frame | CPU idle | Movie on the other display |
| --- | --- | --- |
| light painting (fade + 3 soft brushes) | 28 ms (35 fps) | 61 ms (16 fps) |
| strokes + full-width line | — | 47 ms (21 fps) |
| one circle on a frozen frame | — | 2.6 ms |
| grab a slot (uncached read) | — | approx. 100 ms |

`fade` touches the whole frame (NEON, fused with the copy to the slot), so it
is limited by DDR bandwidth, which the displays and the capture share. Small
operations cost only their own area.

## debazd threads (2026-11-03)

| Thread | Does | Priority |
| --- | --- | --- |
| main | OSC, register fields, frame tick (ramps, cues, audio analysis, DDS, LFOs, image sequences), monitor every 20 ms | normal |
| vsync | display changes right after each vsync (VTC interrupt with the UIO overlay, else polling) | SCHED_FIFO 60 |
| pwm | software PWM on J5 | SCHED_FIFO 55 |
| debazd-pix | the pixel domain: `/draw/ /img/ /movie/ /surface/ /sprite/ /ascii/`, ASCII frames, movie ticks | normal |

The pixel thread runs the messages of its addresses in their order of
arrival (`sw/debazd/pix.c`); an internal message (LFO template, cue ramp)
replaces a waiting internal one with the same address. Its replies go to the
sender as before, but a `/ping` sent after a `/draw` can come back first.
`/stats` ends with `f:pix_max_ms i:pix_queue`. Measured on the board (an
ASCII 6→6 scene + 60 brush strokes per second): OSC round trip p99 1.5 ms
(was 24 ms), slowest main tick 0.1 ms (was 38 ms). Child programs start
with `posix_spawn` (a `fork` of debazd took 9-19 ms), and a stopped child
gets SIGKILL after 0.5 s (an arecord without input blocked for 10 s).

## Display buffers, blank and strobe

There are **12 slots** (0x0800_0000 + n × 0x7E9000, inside the 96 MB
reservation): 0–5 as before (4 = capture), 6–10 free, 11 = always black.
Each display keeps the shown slot in VDMA frame store 0 and the black slot in
frame store 2. A real-time thread in debazd waits for vsync (VTC status bit
13, 60.03 Hz, jitter < 0.1 ms) and applies every display change right after
it, so each change lands on a whole frame. With the UIO overlay
(`hw/dt/ebaz4205_2out1in.dtso`) it sleeps on the VTC interrupt (0.3 % CPU,
jitter max ~90 us); without it, it polls (2.5 % CPU, ~30 us).

| Address | Effect |
| --- | --- |
| `/disp/<d>/show` slot | show a slot (next frame) |
| `/disp/<d>/blank` [0\|1] | black / back; no argument = toggle (one register write) |
| `/disp/<d>/seq` slot slot ... | loop through slots, -1 = black |
| `/disp/<d>/seq/rate` frames | frames per step (default 1) |
| `/disp/<d>/seq/stop` | back to the shown slot |
| `/vsync` | → frames, Hz, jitter in µs, ok |

Measured per frame on the board: `seq 5 -1` = black on every second frame
(30 Hz strobe), `seq 6 7 8 9 10` = a 5-slot flipbook at 60 fps, `rate 3` =
exactly 3 frames per step. Draw the frames first, then play them: playback
costs no drawing. ⚠️ Fast strobes are a photosensitivity risk.

## Soft timing: LFOs

16 oscillators in debazd, evaluated once per frame (`debazd/lfo.c` has the
full list). Shapes: sine, tri, saw, ramp, square, random (sample & hold),
smooth, step, noise; wave shaping with width, curve, steps, range, phase;
rate in Hz or a period in frames; loop or one-shot (`trigger`).

A target is either register fields or a **message template**, sent to the
daemon itself every frame, where `$k` = value of LFO k (`$fk` as float):

```sh
dzctl /lfo/0/rate 0.31; dzctl /lfo/0/range 100 1180      # x
dzctl /lfo/1/rate 0.47; dzctl /lfo/1/range 80 640        # y
dzctl /lfo/1/target "/draw/6/brush 200 80 20 \$0 \$1 30 0"
dzctl /lfo/2/target "/draw/6/fade 0.12"; dzctl /lfo/2/every 4
dzctl "/lfo/[0-2]/on" 1                                  # light painting, no client
dzctl /lfo/4/range 0 255; dzctl /lfo/4/target /hdmi/1/feedback/r; dzctl /lfo/4/on 1
dzctl /lfo/reset
```

`every k` applies a target only on every k-th frame: use it for heavy
targets (a full-frame fade takes 25–60 ms).

Shape `audio` (2026-11-01): the value follows a feature of the audio
analysis (`debazd/react.c`, source `/audio/react/source auto|movie|capture|peak|off`):

```sh
dzctl /audio/react/source auto             # default: a movie's audio, else HDMI 2
dzctl /audio/react/source movie            # the audio of a playing movie (all features)
dzctl /audio/react/source capture          # HDMI 2 input via ALSA (all features)
dzctl /lfo/0/audio bass                    # also selects shape audio
dzctl /lfo/0/gain 0                        # 0 = auto (feature / its recent peak)
dzctl /lfo/0/attack 0; dzctl /lfo/0/release 0.15
dzctl /lfo/0/range 0 1000; dzctl /lfo/0/target /hdmi/0/delay; dzctl /lfo/0/on 1
```

Features: level, peak, bass (< 250 Hz), low, mid, high, air (> 8 kHz),
flux, beat, band0..band15 (FFT 1024 by default, `/audio/react/fft`). A
full-scale sine = 1; typical program material is 0.1-0.4, so use gain 0
(auto) or 3-8. The capture device has one owner: `/audio/rec` pauses the
analysis ("held: recording"), another program that holds it is reported
as "busy: <pid> <name>" (`/audio/react` ends with the status).

Movie audio (2026-11-04): a movie that plays audio (`/movie/<s>/play name
fps audio`, audio > 0) also writes it, after its `/af` chain, as s16le 48
kHz stereo into the FIFO `/tmp/dzmaudio.<slot>`. debazd drains these FIFOs
every frame, also when no sink asks: a full pipe (256 KB = 1.3 s) would stop
the audio ffmpeg and the sound with it. `movie` uses the movie in use while
it delivers, else the lowest slot that delivers; status "ok: movie <slot>".
`auto` takes a movie first, then HDMI 2 (when it has lock). A movie with
audio 0 has no tap. ⚠️ Audio 4 (I2S) blocks the whole audio ffmpeg (all its
outputs, the tap too) while the I2S master does not run (hw_ptr stays 0).

## DDS patterns, AWG, audio scope

`debazd/dds.c` (OSC list at the top of the file): patterns that set several
dz_osc2 registers from the running video mode (`/dds/<n>/bars`, `hbars`,
`checker`, `slant`, `scroll`, `pulse`), the 16-step sequencer table, the
2048-entry AWG table (`/dds/<n>/awg "v v v ..."`) and the audio scope:
`/dds/<n>/scope <gain> <h|v|free|keep> <sum|l|r> <wave|fft|fftlin>` writes
the newest 2048 samples of the capture, or the spectrum of that channel, into
the AWG table each frame. The modes are:

- h: across each line.
- v: down the frame.
- free: shape awg with no phase reset; set the rate with `/dds/<n>/hz`.

Each part of the scope also has its own address:

- `/dds/<n>/scope/skew f` makes it diagonal. In h, the cycle moves f cycles
  from the top line to the bottom line. In v, f cycles across the width.
- `/scope/seam mirror|fade` removes the jump where the cycle wraps (use it
  with free, skew or v).
- `/scope/trigger 1` starts the waveform at a rising zero crossing.
- `/scope/smooth 0..0.99` smooths the table from frame to frame.
- `/scope/table` returns 128 values of the last table.

The fft source has a log frequency axis (47 Hz to 24 kHz at FFT 1024) and a
range of 60 dB. Gain 1 puts a full-scale sine at the top. Cost on the board:
about 6 % of a core per channel for the waveform and 9 % for the spectrum
(the 2048 uncached writes take most of it). DDS 1 shows on HDMI_1 through
the oscillator layers (`/hdmi/1/osc/sin/gain`).

## Video mode and video wall

`/video/mode 800x600` restarts hdmi2 with `-r 800x600` (both outputs share
one pixel clock); movies stop and the crops go back to 0, 0 (`/event/mode`).
`/disp/<d>/crop x y` shows the output-sized window at x, y of the slot (a
slot is 1920 x 1080; the capture: its real size), applied at vsync, so it
can move every frame. A small output mode over a large input gives the
zoom (640x480 quarters of a 1280x960 input). The Wall tab has all of it.

Slots, not modes (2026-11-04): every slot is a 1920 x 1080 picture in every
output mode, and each source keeps its own size in it, so a display (any
mode) shows a window of whatever is there: a 720p movie fills 1280 x 720 of
its slot, the rest is what memory holds. Two displays on the same slot with
different crops cut one movie, animation or painting into parts.

- **Movies** are never scaled to the output mode (measured on the board, 720p
  movie, decode alone 46 fps; scaled to 640x480 34 fps, 1024x768 27, 1080p
  16). `/movie/<s>/pos x y` = the movie's top left in the slot (a playing
  movie restarts; in `/state`). Not clamped: a movie taller than 1080 or
  placed near the edge runs on into the next slot (on purpose); rows run on
  into the next line. Odd sizes are rounded down to even (fbfeed and
  ffmpeg's yuv420p disagree on odd chroma sizes; the only case that
  scales). **Usage rules:** at most 1920 wide (fbfeed refuses longer rows:
  no picture, the sound plays); nothing past slot 11's end (fbfeed refuses
  Linux RAM); above 720p the A9 decodes too slowly (2560x1440: 2.9 fps,
  1280x1440: 14 fps, 720p: 23-24 fps).
- **Images** (`/img/<s>/load name` without a rectangle) and **animation
  frames** sit at their own size at the top left; a larger one is made
  smaller. Animation frames write only their own pixels (no black borders).
  The web upload fits frames into the slot (default) or the output size
  (smaller files: decode time follows the file size; 1080p JPEG frames ~190
  ms each while a movie decodes, so ~10 fps).
- **Draw surfaces** are the whole slot (`/surface/<s>/canvas full`, the
  default) and stay through a mode change. Each costs 8.3 MB of RAM (11 fit,
  the 12th was refused); full-frame operations are 2.25 x slower than at
  720p. `/surface/<s>/canvas mode` = the old behaviour (the mode's size,
  started again after a mode change); `/surface/<s>/canvas` -> setting,
  w, h, kB in use, kB free. `/surface/<s>/free` gives the RAM back. A new
  surface is refused when less than 24 MB would stay free.
- Web: the Paint tab shows the whole slot with the output sizes (dashed)
  and the window of each display that shows the slot; the Wall tab selects
  the slot per display; the Media tab sets the movie position.

## Movies: datamosh, effects, ASCII

`lib/dz_draw.c` (`/movie/<s>/...`): MPEG-4 Part 2 movies play through
`dzmosh` (key-frame drops, bloom, corruption, pause); other codecs through
one ffmpeg. `/movie/<s>/vf|af "preset|chain"` (checked filter chains, the
movie restarts), live options `/movie/<s>/vf/<filter>/<option> v` (ffmpeg's
runtime commands, queued every 110 ms), `/movie/<s>/trails d` and `ghost k`
(in fbfeed). `debazd/ascii.c`: `/ascii/<d>/run <src>` draws a slot as text.

## Image sequences (stop motion, drawn animation)

`debazd/anim.c` + `lib/dz_img.c` (ROADMAP.md section 16): a folder
`/media/debaz/anim/<name>/` of .jpg (or slow .png) frames plays out of a
display: `/anim/<d>/play <name> [fps]`, `pause`, `step ±1`, `frame i`,
`fps`, `mode loop|once|pingpong|random`, `end hold|black|stop`, `range`,
`reverse`, `late hold|skip`, `/anim/<d>` = status, `/anim/list`. Decode
threads (TurboJPEG, straight into the slot) fill a ring of 4 hidden slots
(5-8 for display 0, 9 10 1 3 for display 1); the vsync thread flips, so
every frame starts on a whole video frame. Optional `timing.txt`: lines
`<file> [hold]` (hold in sequence frames, "on twos" = 2) and `# fps 12`.
Folders of <= 4 files stay decoded ("resident", no CPU). Both displays can
play at once. Budget (720p, measured): 46 KB frames 30 fps on each display
at once; 250 KB frames 15 fps on each, 24 alone; 550 KB 12 fps (SD card).
Build a folder from the web: Paint tab "Save frame" = `/anim/save <folder>
[slot|capture|disp0|disp1] [quality] [hold]` adds the next fNNNNN.jpg (a
hold > 1 starts timing.txt; later saves add their line; "Timing sheet…"
opens the editor: thumbnails, holds, order, repeats, raw text = `/anim/sheet`
and `/anim/sheet/put` in parts of 4 KB; dzweb serves the frames at
`/media/anim/<folder>/<file>`, also PUT and DELETE) (live input
for stop motion, a paint slot for drawn frames; 80-200 ms), `/anim/undo
<folder>`; a display that plays the folder reloads after each save. Media
tab "Image sequences" = the player for both displays, plus "Add a sequence"
(drop or pick a folder / files: natural order, rename f00001.jpg …, fit +
JPEG in the browser, progress) and Delete folder (`/anim/delete`). Onion
skin for stop motion: `/anim/<d>/onion <folder> [opacity] [frames 1-3]
[src slot, default the capture]` shows the live input with the last frames
over it (12-20 fps; web Save frame card "onion" row); each save reloads it.
Each save reports the file size (quality slider: smaller = faster). Laptop:
`mkmedia -A <name>` (see Preparing media).

## Cues, scenes and shows

`debazd/state.c` + `debazd/cue.c` (ROADMAP.md section 15): `/state` dumps
every target as one OSC message (~540); `/state/snap|recall|diff`. A show is
a folder `/data/shows/<show>/` (`show.json`, `baseline.json`,
`looks/*.json`, hand-editable). Cues are keyframes (everything) or deltas
(tracking from the cue before); `/cue/record`, `/cue/go <scene> <n> [secs]
[cut|fade|dip]`, `/cue/next`, `/look/save|apply`, `/show/save|load`. The
Cues tab has all of it. LFOs are free running: cues set them up or switch
them; an LFO left on may fight a fade.

Auto follow and playlists (2026-11-04): `/cue/follow <scene> <n> <secs>` =
the next cue of the scene goes by itself that many seconds after this
cue's go (0 = wait for GO; timed from the go, by the frame tick; a follow
never leaves its scene). `/cue/follow <scene> <n> end [secs]` = secs after
the media this cue names in its own set ended (the movies of
`/movie/<s>/file`, the files of `/audio/out/<n>/file`): the real end, also
when the decode is slower than real time (two movies at once: ~11 fps of
25). `/movie/<s>/loop 0` = the movie plays once (default 1 = loops for ever;
a state target; a change restarts a playing movie). A movie's sound plays
in real time, so it ends before a slow picture: play one movie with sound
at a time. `/scene/loop <scene> 1` = after the last cue the
first again, for a follow and for `/cue/next` (repeat forever).
`/cue/put <scene> <n> keyframe|delta [name]` + `/cue/add <scene> <n>
<address> args...` build a cue from targets, without recording.
`/img/<s>/file name` is a state target (slot black, then the image at its
own size; "" = forget). `/media/info movies|audio|img <file>` -> seconds
(0 = a still), w, h (ffprobe on the pixel thread, cached). The Media tab's
**Playlist → scene** card: pick files (boxes, in click order; shift = a
range) -> Generate = an editable sheet (`movie|image|audio|black <hold>
[file]`, hold = seconds, `end` or `end+2`; movies and audio `end` by default,
else their durations; a black cue of `pause` s between items) ->
Save as scene (put/add/follow/loop, then `/show/save`). Each cue sets all
media of its slot, output and displays, so delta cues ("keep the look")
work. Then edit it in the Cues tab (follow column, repeat box): a card over
a black cue, looks, fades. A movie that decodes slower than real time
(above 720p) is cut at its file duration.

## Colour FX: hue, colour map, colour key

`debazd/fx.c`. The HDMI_0 colour matrix multiplies HDMI_0's video by 9
gains from the mixer (CLAUDE.md "Colour matrix math"). These commands set
all 9 channels to constant gains (mode 4), so they replace the boot mixer
setup ("Boot setup" in the web app puts it back).

```sh
dzctl /fx/hue 120            # R->G, G->B, B->R; any angle, + optional gain 0..1
dzctl /fx/map 0x00ff00 0x0000ff 0xff0000   # where input R, G, B go (= hue 120)
dzctl /fx/matrix 1 0 0  0 0 1  0 1 0       # rows out R G B, columns in R G B
dzctl /fx/matrix             # read back (-1 = channel not in mode 4)
dzctl /fx/identity
dzctl /fx/wrap 1             # allow row sums > 1: bright colours wrap to dark
dzctl /lfo/5/range -180 180; dzctl /lfo/5/target "/fx/hue \$f5"; dzctl /lfo/5/on 1
```

The gains are unsigned, so a hue angle between the multiples of 120 degrees
clips the negative terms: less saturation and brightness (60 degrees: red ->
half-bright yellow).

Signed gains (mixer coreRevision 25, branch signed-mixer): `dzctl /fx/signed 1`
writes the matrix as mode 5 signed constants. Then the hue is exact at every
angle, `/fx/hue/sat 2` gives more saturation (0 = grey, -1 = the
complement), and `/fx/matrix` takes negative entries. As in the rest of the
gateware, a result outside 0..255 wraps (no clamp). Older bitstreams show
mode 5 as 0x7FFF: keep `/fx/signed 0` on them. Per channel, the fields
`/mixer/<c>/g/<n>` set a gain as a signed number: an int is the raw 24-bit
two's complement value (0x10000 = 1.0, -255 = 0xFFFF01; the web Mixer
table uses ints), a float is scaled (1.0 = 0x10000); and
`/mixer/<c>/diff`, `centre` and `dsign` select the mode 1 inputs: stream A
minus stream B (with the BRAM delay `/hdmi/0/delay`: an edge or comb
filter), the stream minus 128, and the DDS inputs as signed numbers.

Colour key (needs the key bitstream, Oct 26 2026; older bitstreams ignore
it): where the tested pixel is inside a colour box, HDMI_1's pixel replaces
HDMI_0's. The box is the lo/hi of mixer channels 0 (R), 6 (G), 3 (B) with
their `key` bit; those channels keep their mode, but a band-clip mode on them
uses the same lo/hi.

```sh
dzctl /fx/key/color 0x00ff00 30      # box = colour +- 30 per channel, key on
dzctl /fx/key/range 0x000080 0x4040ff  # low and high corner
dzctl /key/invert 1                  # insert HDMI_1 OUTSIDE the box
dzctl /fx/key/source 1               # test HDMI_0's video (default: HDMI_1)
dzctl /key/stream 1                  # fill with the delayed HDMI_1 copy
dzctl /mixer/2/key 1                 # add another band (here: a 2nd R range)
dzctl /fx/key/off
```

HDMI audio housekeeping (debazd audio.c):

```sh
dzctl /audio/fs              # pixel clock, the 48 kHz rate setting, auto on/off
dzctl /audio/fs/auto 0       # stop debazd from setting /audio/tx/fs_inc
dzctl /capture/replug 2      # HDMI_2 hot-plug low for 2 s: source re-reads the EDID
dzctl /audio/rx/rate         # HDMI_2 input samples per second (48000 = healthy)
dzctl /audio/rx/auto 0       # watchdog off (default on: replug when the rate is off by > 2 % for 3 s)
```

## Preparing media on the laptop (sw/tools/mkmedia.sh)

```sh
bash sw/tools/mkmedia.sh ~/show-media                 # a folder of mixed files -> ./board-media/{img,movies,audio}
bash sw/tools/mkmedia.sh -o /tmp/out -u clip.mov a.mp3 # files; -u = upload to the board (default ebaz@10.42.0.68 or $DZ_BOARD)
bash sw/tools/mkmedia.sh -A walk -j 85 -u shots/      # image sequence: shots/* -> anim/walk/f00001.jpg ... (-r 12: movie frames at 12 fps + timing.txt)
bash sw/tools/mkmedia.sh -h                            # all options
```

Movies -> MPEG-4 1280x720 at most 25 fps, audio PCM 48 kHz 16 bit (left
out when the source has none or it is silent); audio files -> WAV (or
`-a flac`) 48 kHz 16 bit stereo; images -> PNG fitted into the display
size. Names change to the board's A-Z a-z 0-9 . _ -. Files that are up to
date are skipped (`-F` = convert again); `-m` = the media root on the board
(default `/media/debaz`), `-R MB` = space to keep free there (default 256:
a file that does not fit is skipped and listed, and the final sync is left
out); Ctrl-C also stops the upload worker; a progress bar per file on a
terminal, a summary at the end. With `-u` each file is uploaded (rsync, one
at a time, in the background) as soon as it is converted, while the next
one transcodes; a final rsync of the whole output tree then sends what is
missing on the board (also files that were up to date here). Nothing on
the board is deleted.

## Audio: sources, files, recording (debazd sound.c, ALSA card DEBAZ)

Outputs: 0 = HDMI 0, 1 = HDMI 1, 2 = I2S out. Files live in
`/media/debaz/audio` (all media: `/media/debaz/{img,movies,audio}`, the
exFAT media partition made at first boot; `/home/ebaz/{img,movies,audio}`
are symlinks there). The web app's Media tab uploads there; the Audio tab
has all of this as controls.

```sh
dzctl /audio/out/0/source auto     # auto | linux | input | i2s | tone | off (I2S: auto|linux|input|off)
dzctl /audio/out/1/source          # query (read from the hardware after a restart)
dzctl /audio/play 0 song.mp3 1     # out, file, loop (any format ffmpeg reads)
dzctl /audio/stop 0                # one output; no argument = all
dzctl /audio/rec take1 30          # HDMI 2 In -> audio/take1.wav, 30 s (0 = until stop, max 1 h)
dzctl /audio/rec/stop
dzctl /audio/status                # /audio/out out file loop source (x3), /audio/rec file secs
dzctl /files audio
dzctl /movie/0/play clip.mkv 0 3   # a movie's own audio: 1 HDMI 0, 2 HDMI 1, 3 both, 4 I2S
```

A movie's audio (`/movie/<s>/play name fps mask`) is a second ffmpeg at
SCHED_FIFO 20 that reads only the audio track: the sound stays smooth when
the video decode falls behind (two movies: 0 underruns in 38 s; in one
ffmpeg the audio broke up), and on an overloaded CPU the picture lags.

`auto` = the output plays Linux audio while something plays on it, else
the HDMI 2 input; every source but `off` switches an HDMI output to HDMI
mode with audio. The Linux part is the driver's route control (`amixer -c
DEBAZ`), so plain `aplay -D hw:DEBAZ,N` follows the same rules. "Audio
follows the picture" with a movie on both outputs (mask 3): swap the
sources `linux` / `input` together with the `/disp` swap. Playback is
ffmpeg -f alsa, recording arecord, both children of debazd; a stop is
immediate (SIGKILL; the recorder gets SIGINT so the WAV header is written).
Recordings belong to the owner of the folder (dzweb can delete them).

Green screen on HDMI_1 over HDMI_0: `/key/invert 1`,
`/fx/key/color 0x00ff00 40`.

## User I/O lines: GPIO, I2C, SPI, UART, I2S

The 6 user I/O lines (PCB PL_KEY0-5, header P1) take one function each
(bitstream 2026-10-27 or later; older bitstreams: the fields return an
error). At power-up every line is an input, as before.

```sh
dzctl /io/pin 0 scl; dzctl /io/pin 1 sda      # PS I2C0 -> /dev/i2c-0 (i2cdetect -y 0)
dzctl /io/pin 2 sclk; dzctl /io/pin 3 cosi    # PS SPI0 -> /dev/spidev0.0
dzctl /io/pin 4 ciso; dzctl /io/pin 5 cs0
dzctl /io/pin 2 txd; dzctl /io/pin 3 rxd      # PS UART0 -> /dev/ttyPS1
dzctl /io/pin 0 bclk; dzctl /io/pin 1 lrclk; dzctl /io/pin 2 dout   # I2S DAC
dzctl /i2s/on 1; dzctl /i2s/play 1; dzctl /i2s/steer 1  # play the HDMI_2 audio
dzctl /audio/tx0/hdmi 1; dzctl /audio/tx0/enable 1   # HDMI_0 audio too (own switches)
dzctl /i2s/to_hdmi0 1                         # HDMI_0 audio = I2S in (else HDMI_2 loop)
dzctl /io/pin 5 out; dzctl /io/out/5 1        # plain output
dzctl /io/pins                                # all six functions
```

Names: in out scl sda sclk cosi ciso cs0 cs1 txd rxd bclk lrclk dout din
(COSI = controller out, CISO = controller in; `mosi` / `miso` still work).
Any function goes on any line, so TX/RX and COSI/CISO swaps are a
setting, not a wiring change.
The Linux devices need the PetaLinux image with the 2026-10-27 device tree.
Do not press a button whose line is an output driving high (it shorts the
output); use series resistors on add-on boards.

Tested 2026-11-04 between two boards (debaz-00e1da / debaz-c153e5, PL_KEY0-5
wired 0-0 .. 5-5 + GND, bitstream `_dsp`):

| Test | Result |
| --- | --- |
| GPIO: each line driven low by one board, all 6 read on both | 12 of 12 right: no open, no short, idle high |
| UART0 (/dev/ttyPS1), line 0 TXD -> RXD, line 1 RXD <- TXD (crossed in pl_io) | 20000 random bytes echoed at 115200 and 921600: 0 wrong, 0 lost |
| I2C0 (/dev/i2c-0, 100 kHz) against `dzbus i2csub` | write + read back byte-exact; ~1 in 5 transactions missed by the software subordinate |
| SPI0 (/dev/spidev0.0, 625 kHz = 160 MHz / 256, the lowest) against `dzbus spisub` | 13 of 20 frames exact, the rest 1-2 bits late (software CISO) |

Tools: `sw/tools/dzbus` (C, root, real time on CPU 1): `levels`, `set <line>
in|out0|out1`, `sniff <ms> [-i scl sda] [-s sclk cosi cs [ciso]] [-r]` (4.6 M
samples/s: edges, I2C / SPI decode), `i2csub`, `spisub` (software
subordinates: the kernel has no CONFIG_I2C_SLAVE / SPI_SLAVE). `sw/tools/
dzcomm.py` (python3, the controller side): `uart-echo`, `uart-test`, `spi`,
`i2c ... write|read|test`. Found: `/dev/ttyPS1` is group dialout (ebaz is not
in it: sudo); clock stretching by the software subordinate (`i2csub -x`)
left the Cadence I2C "bus active" bit set (EAGAIN for every transfer; only
an I2C0 reset through the SLCR cleared it). ⚠️ After a devmem write to the
SLCR, leave it UNLOCKED: Linux keeps it unlocked, and with the lock set
every clock gate write of the kernel is lost (I2C0 and SPI0 stopped: their
APER_CLK_CTRL bits stayed off while the clock framework counted them on).

## Fan connectors J3 / J5: inputs, outputs, PWM

Needs the `fan` bitstream (2026-10-27) or newer. Pin 3 = input (active low),
pin 4 = output through an opto (inverted, open collector, **pulled up to 12
V on the board**: replace the pull-up before a servo or 5 V logic goes on it).
The optos limit the rate to a few kHz (ROADMAP.md section 11).

```sh
dzctl /fan/3/in                   # pin 3 level (0 = pulled low outside)
dzctl /fan/3/out 1                # opto on: pin 4 low
dzctl /fan/3/vsync 1              # pin 4 = the vsync pulse (frame sync out)
dzctl /fan/3/pwm 100 0.3          # software PWM: 100 Hz, opto on 30 % of the time
dzctl /fan/3/duty 0.6             # new duty, same frequency and phase
dzctl /fan/5/servo 0.5            # 50 Hz, pin 4 high for 1.5 ms (1..2 ms range)
dzctl /fan/5/servo 0.5 0.6 2.4    # same, 0.6..2.4 ms range
dzctl /fan/3/pwm 0                # stop, opto off
dzctl /fan/pwm/stats              # max / mean lateness of the edges (us), edges
dzctl /lfo/0/target "/fan/3/duty \$0"   # an LFO drives the duty (range 0..1)
```

**J3 = hardware PWM** (bitstream `pwm`, 2026-10-27, found by its ID): 6 Hz to
100 kHz, exact to 10 ns, no CPU, glitch-free duty changes (taken at each
period start). Below 6 Hz, with an older bitstream, and always on J5, the
same commands use software. **J5 keeps the vsync output** (`/fan/5/vsync 1`)
for frame sync to other units. Raw J3 fields:

```sh
dzctl /fan/3/pwm/lock 1           # restart the J3 period at each vsync start:
dzctl /fan/3/pwm 120 0.1          #   e.g. 2 strobe pulses per 60 Hz frame, in phase
dzctl /fan/3/pwm/period /fan/3/pwm/duty /fan/3/pwm/invert /fan/3/pwm/on
```

The software PWM: a real-time thread in debazd (priority 55, below the
vsync thread). Up to 200 Hz it spins for the last 100 us before each edge
(a few us of jitter, about 1 % CPU per channel at 50 Hz); above that it only
sleeps (50-500 us of jitter). Run debazd as root for SCHED_FIFO.
`/fan/pwm/stats` shows the result on the board. A write to `/fan/<n>/out`
while the PWM runs lasts only to the next edge.

## Buttons and GPIO actions

`/io/press/<bit> "template"` and `/io/release/<bit> "template"` bind a
message to an edge of user I/O bit 0..7 (the 6 buttons / P1 lines, active
low: a press is 1 → 0). The daemon sends the message to itself, with the
same syntax as LFO targets. No argument removes the binding. The monitor
polls every 20 ms (`debazd -i`).

```sh
dzctl /io/press/0 "/disp/1/blank"                 # button 0 toggles black
dzctl /io/press/1 "/disp/1/seq 6 7 8 9 10"        # button 1 starts a flipbook
dzctl /io/press/2 "/lfo/3/trigger"                # button 2 fires an envelope
```

## Sprites, text and transforms

| Address | Arguments |
| --- | --- |
| `/sprite/<id>/load` | "file" [w h] — image from `/home/ebaz/img` (PNG alpha kept) |
| `/sprite/<id>/grab` | slot x y w h — a rectangle of a slot (e.g. the capture) |
| `/sprite/<id>/text` | r g b "text" [scale] [16\|32] — pixel font |
| `/sprite/<id>/ttf` | r g b size "text" ["font file"] — anti-aliased |
| `/sprite/<id>/key` | r g b [tolerance] — colour → transparent |
| `/sprite/<id>/draw` | slot x y [scale] [angle] [alpha] — centred at x,y |
| `/draw/<s>/text` | r g b x y "text" [scale] [16\|32] |
| `/draw/<s>/ttf` | r g b x y size "text" ["font file"] |
| `/draw/<s>/rotozoom` | angle zoom [cx cy] [src] — on itself = feedback tunnel |
| `/draw/<s>/transform` | a b c d e f [src] — affine map with wrap-around |
| `/draw/<s>/scroll` | dx dy [src] |
| `/draw/<s>/mirror` | h \| v \| quad (4-way kaleidoscope) |
| `/draw/<s>/wave` | axis amp period phase [src] |

Fonts: the pixel font is derived from Terminus Font (SIL OFL 1.1,
`third_party/fonts/OFL.txt`); TrueType files come from `/usr/share/fonts`
(default `LiberationSans-Regular.ttf`), rendered by stb_truetype
(`third_party/stb`, public domain / MIT).

Measured on the board (ms per operation, including the copy to the slot):

| Operation | CPU idle | movie on the other display |
| --- | --- | --- |
| sprite load (jpeg, ffmpeg) | — | 700–1200 |
| sprite 600×600 / ×0.5 rotated / 869×860 ×0.3 α | 38 / 15 / 17 | 74 / 35 / 39 |
| pixel text (32 chars ×2) / TrueType 64 px | — | 3 / 14 |
| rotozoom / scroll / wave / shear / mirror quad (full frame) | 27 / 22 / 22 / 29 / 15 | 64 / 48 / 62 / 73 / — |

Full-frame transforms read the source once, write a spare buffer, copy each
finished row to the slot while it is in cache, then swap the buffers.

## "ffmpeg -f fbdev /dev/fb0 does not work"

ffmpeg writes slot 0. It shows only if display 0 scans slot 0. After the
hdmi2 menu key 'a' ("capture on display 0"), display 0 scans the capture
slot, and ffmpeg writes to a slot that nobody shows. Fix:

```sh
dzctl /disp/0/home        # display 0 shows slot 0 (ffmpeg) again
dzctl /disp/0/capture     # display 0 shows the live input
dzctl /disp/0             # which slot does display 0 show now?
```

## Memory safety (important)

Frame slots are `0x0800_0000 + n * 0x7E9000`. They must be inside the
`reserved-memory` of the RUNNING kernel. On the bench board (Oct 2026) only
16 MB is reserved, so only slots 0 and 1 are safe; slots 2-5 are Linux RAM.
debazd, fbfeed and hdmi2 check this at run time and refuse unsafe slots
(`dzctl /info`: last value = usable slots). The fix (a 128 MB DTB, one
reboot) is ready in `PetaLinux/dtb/` - see its README.

Register blocks: debazd maps only blocks listed in `include/hw_map.h`. Old
addresses (and the speculative UIO nodes in the dtsi) are refused, because
any access to them is a bus error.

## Debugging (no Eclipse)

Copy `tools/vscode/launch.json` and `tasks.json` to `.vscode/` (done on the
bench laptop). Build with `make DEBUG=1 install`, start the gdbserver task,
then F5. The ARM gdb comes from the Vitis toolchain; its Python files are
borrowed from the aarch64 package (`--data-directory`, already in the file).

## Measured on the board (Oct 2026)

- Slot writes: /dev/fb0 approx. 630 MB/s, /dev/mem approx. 660 MB/s. Reads from
  /dev/mem are slow; the drawing code keeps shadow buffers for that reason.
- fbfeed through a pipe: approx. 25 fps at 720p (92 MB/s). The pipe is the limit.
- ffmpeg 720p mpeg4: decode only (yuv420p) 36 fps; + ffmpeg's bgra conversion
  20 fps; + ffmpeg's uyvy422 packing 6 fps (very slow on ARM).
- `fbfeed -y` (yuv420p in, NEON conversion in fbfeed, `lib/dz_yuv.c`): one
  720p frame in 16 ms. Two 720p movies at once: **12.5 fps each** (was 7 fps
  each with ffmpeg's bgra path). Now the decoder is the limit. debazd's
  `/movie` player uses this path. `fbfeed --selftest` checks NEON vs C.
- YUV matrix: BT.709 by default (the test files are bt709); `fbfeed -m 601`.
- Capture colours are exact: red in -> `0xFFFF0000` in the slot.

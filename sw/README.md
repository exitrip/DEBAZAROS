# sw/ - DEBAZAROS userspace software

Built with plain make and the gcc from Vitis 2022.2. No Vitis project, no BSP.

| Path | What it is |
| --- | --- |
| `debazd/` | The hardware daemon: the one owner of the PL registers and frame slots, controlled over OSC/UDP (port 9000). |
| `dzweb/` | Web app: a small HTTP + WebSocket server on the board (port 8080) and the browser pages in `dzweb/www/`. See "Web app" below. |
| `dzctl/` | Command-line OSC client for debazd. Runs on the board and on the laptop. |
| `lib/` | `libdz`: register mapping (`dz_map`), named register fields (`dz_fields`), display routing and capture status (`dz_vdma`), OSC wire format (`dz_osc`), drawing (`dz_draw`). |
| `hdmi2/` | Display bring-up (video mode, VDMAs, VTC, dynclk, capture). Moved from the old Vitis workspace (jerkspace). |
| `fbfeed/` | Copies raw frames from stdin into a frame slot (second video stream). |
| `include/hw_map.h` | Register base addresses, GENERATED from the block design (`make hwmap`). |
| `tools/` | `capstat.sh` (capture status), `selftest.sh`, `vscode/` (debug setup). |

## Build and install

```sh
make              # ARM binaries -> out/arm/   (hdmi2: out/arm/hdmi2.elf)
make NATIVE=1     # x86 binaries -> out/native/ (dzctl for the laptop)
make test         # host self test, simulated hardware
make install      # copy to the board: /home/ebaz/bin/
make DEBUG=1      # -O0 -g for gdb
```

`make install` copies to `/home/ebaz/bin/`. The boot script `debazarosit.sh`
still starts `/home/ebaz/hdmi2.elf` (the old build). Change that only when you
decide to.

## Start order on the board

1. Load the bitstream (JTAG, or fpga_manager).
2. Run hdmi2 one time: it sets the video mode and starts the VDMAs.
   debazd does not do this.
3. Start the daemon: `sudo /home/ebaz/bin/debazd &` (`-v` logs every write).
4. Control it: `dzctl ...` on the board, `dzctl -h <board-ip> ...` from the LAN.
5. Optional, the web app: `/home/ebaz/bin/dzweb &` (no sudo), then open
   `http://<board-ip>:8080/` in a browser.

Only one debazd runs at a time (`/tmp/debazd.lock`). Do not run the devmem
loop of `debazarosit.sh` at the same time: both write the same registers.

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
| `/files` | `img` or `movies` | one `/file name` per file in `/home/ebaz/img` or `/home/ebaz/movies`, then `/file/end count` |
| `/subscribe` | [port] | send events to me: `/event/io`, `/event/hpd`, `/event/capture` |
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

`dzweb` serves the pages in `/home/ebaz/www` and connects browsers to
debazd. The browser sends OSC packets as WebSocket frames, and dzweb sends
them to debazd over UDP. Replies and events come back the same way. Thus the
browser uses the same OSC addresses as `dzctl`.

```sh
/home/ebaz/bin/dzweb &      # -p 8080  -w /home/ebaz/www  -m /home/ebaz  -d 127.0.0.1 -o 9000  -v
```

| URL | What it does |
| --- | --- |
| `/` and other flat file names | static files from the www folder (no sub folders, `..` gives 404) |
| `/units` | broadcasts `/info` on the LAN; JSON list of units (ip, variant, slots, host, MAC) |
| `/osc` | WebSocket. Each binary frame is one OSC packet (message or bundle). |
| `GET /media` | JSON: free bytes on the disk, files in `img/` and `movies/` (name, size, mtime) |
| `GET /media/<img\|movies>/<name>` | download a file (`?dl`: as an attachment) |
| `PUT /media/<img\|movies>/<name>` | upload a file (raw body with Content-Length) |
| `DELETE /media/<img\|movies>/<name>` | delete a file |

Tabs in the app:

- **Displays**: slot grid per display (12 slots), Home, Live input, Blank,
  frame sequencer. The page asks for a confirmation before a fast black
  strobe (photosensitivity).
- **Effects**: all register fields. The page gets them from `/fields`, so a
  new field in `dz_fields.c` shows without a change to the page. Mixer: a
  table with 9 channels (mode, K, lo, hi, stream B, 5 gains).
- **Oscillators**: the 16 LFOs. debazd reports only value and on/off, so the
  page keeps its own copy of the settings in the browser.
  "Send all settings" sends that copy again (for example after a debazd restart).
- **Paint**: brush, line, pixel text, TrueType text and sprites on a
  1280x720 canvas, in board coordinates. The canvas shows a local preview
  only. Board effects (grab, transforms) show on the display.
- **Media**: upload (drop files or choose them), download and delete images
  and movies; use them as sprites, draw them, play movies; sprites from
  text, colour key.
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

## Display buffers, blank and strobe

There are **12 slots** (0x0800_0000 + n × 0x7E9000, inside the 96 MB
reservation): 0–5 as before (4 = capture), 6–10 free, 11 = always black.
Each display keeps the shown slot in VDMA frame store 0 and the black slot in
frame store 2. A real-time thread in debazd waits for vsync (VTC status bit
13, 60.03 Hz, jitter < 0.1 ms) and applies every display change right after
it, so each change lands on a whole frame.

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

## Audio: sources, files, recording (debazd sound.c, ALSA card DEBAZ)

Outputs: 0 = HDMI 0, 1 = HDMI 1, 2 = I2S out. Files live in
`/home/ebaz/audio` (the web app's Media tab uploads there; the Audio tab
has all of this as controls).

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
dzctl /io/pin 2 sclk; dzctl /io/pin 3 mosi    # PS SPI0 -> /dev/spidev0.0
dzctl /io/pin 4 miso; dzctl /io/pin 5 cs0
dzctl /io/pin 2 txd; dzctl /io/pin 3 rxd      # PS UART0 -> /dev/ttyPS1
dzctl /io/pin 0 bclk; dzctl /io/pin 1 lrclk; dzctl /io/pin 2 dout   # I2S DAC
dzctl /i2s/on 1; dzctl /i2s/play 1; dzctl /i2s/steer 1  # play the HDMI_2 audio
dzctl /audio/tx0/hdmi 1; dzctl /audio/tx0/enable 1   # HDMI_0 audio too (own switches)
dzctl /i2s/to_hdmi0 1                         # HDMI_0 audio = I2S in (else HDMI_2 loop)
dzctl /io/pin 5 out; dzctl /io/out/5 1        # plain output
dzctl /io/pins                                # all six functions
```

Names: in out scl sda sclk mosi miso cs0 cs1 txd rxd bclk lrclk dout din.
The Linux devices need the PetaLinux image with the 2026-10-27 device tree.
Do not press a button whose line is an output driving high (it shorts the
output); use series resistors on add-on boards.

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

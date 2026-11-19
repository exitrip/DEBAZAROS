-- prelude.lua - the drawing API of a dzlua script (sw/dzlua/dzlua.c, 2026-11-20).
-- Built into dzlua. The script runs after it, in the same global table.
--
-- A script either defines frame(n, t) (called once per frame at `fps`, the
-- frame is shown after each call) or draws once and ends (the picture stays),
-- or runs its own loop and calls wait() at the end of each frame.
--
--   W, H, SLOT          canvas size (the video mode), target slot
--   fps                 frames per second (default 30; param "fps" sets it)
--   param               live values: /lua/<s>/p/<key> v -> param.key
--   onparam(k, v)       if defined: called on each new param value
--   setup()             if defined: called once before the first frame
--   frame(n, t)         n = frame number from 0, t = seconds since start
--
--   rgb(r, g, b)        colour from 0..255 values; hsv(h, s, v) from 0..1
--                       (h wraps); gray(v) 0..255. Colours are 0xRRGGBB
--   clear([c])          the whole canvas (default black)
--   fade(k, [c])        every pixel toward c (black) by k 0..1: trails
--   trails(k, [c])      the same fade after every frame, fused with the
--                       copy to the slot: faster than fade() in frame();
--                       trails(0) = off
--   pset(x, y, c)       pget(x, y) -> c
--   line(x0, y0, x1, y1, c, [w])         anti-aliased; w = width (1)
--   poly(pts, c, [w], [closed])          pts = { x1, y1, x2, y2, ... }
--   rect(x, y, w, h, c, [fill])          fill: true / false (outline)
--   circle(x, y, r, c, [fill], [w])
--   text(x, y, str, c, [scale])          8 x 16 pixel font, "\n" ok
--   scroll(dx, dy)      move the whole canvas
--   blend(mode)         "normal" "add" "lighten" "sub"
--   alpha(a)            0..1 for later drawing
--   FB, dirty(x, y, w, h)    the canvas as uint32_t[W * H] (FFI pointer:
--                       FB[y * W + x] = c), then mark the changed area
--                       (dirty() = all)
--   present()           copy the changes to the slot now
--   layer([on, [key]])  layer mode: only pixels brighter than key (8) go
--                       to the slot (black = transparent). debazd turns it
--                       on when a movie or the capture writes the slot
--                       (LAYER = the start value); layer() -> on?
--   grab()              the slot into the canvas (~50 ms: what a movie,
--                       paint or the capture put there)
--   wait()              present, read params, sleep to the next frame;
--                       returns t
--   time()              seconds since start
--   turtle([x, y, heading])  a turtle (heading 0 = up, clockwise):
--     :fd(d) :bk(d) :rt(deg) :lt(deg) :pu() :pd() :color(c) :width(w)
--     :jump(x, y) (no line) :moveto(x, y) (line if pen down)
--     :heading(deg) :home() :push() :pop()   (all return the turtle;
--     fields .x .y .a)
--   print(...)          to the script log (/lua/<s>/log; max 256 KB)
--   audio               debazd's audio analysis, updated each frame (the
--                       first use turns it on; source: /audio/react/source,
--                       auto = movie audio, else the HDMI_2 input):
--     .level .peak .bass .low .mid .high .air .flux .beat   0..1 (beat 0|1)
--     .band[0..15]      16 log bands      .running  samples arrive
--     .n, .M[i] .L[i] .R[i]   the newest n (2048) samples, oldest first,
--                       -1..1: mix, left, right (FFI arrays, i from 0)
--     .nbins, .spec[k]  amplitude spectrum of the mix, k = 0..nbins-1;
--                       .hz(k) -> Hz, .bin(hz) -> k   .fft_n (1024)
--     .source ("off" "capture" "peak" "movie" "none"), .age (s), .frame
--   midi                MIDI out through the ALSA sequencer, on time: events
--                       carry a time stamp (script time, like time()), the
--                       kernel sends them then, whatever the frame rate.
--                       Schedule ahead (e.g. 0.15 s). The first call opens it
--                       and connects "FLUID Synth" (sudo dzsynth.sh start);
--                       midi.open(dest) for another (aconnect -l name or
--                       "none"; param midi_dest). ch = 0..15 (9 = GM drums)
--     .note(ch, n, vel, len, [at])   on at `at` (default now), off at at+len
--     .on(ch, n, vel, [at])  .off(ch, n, [at])  .cc(ch, c, v, [at])
--     .program(ch, p, [at])  .bend(ch, -8192..8191, [at])
--     .panic()          all off now (sustain, notes, sound) on 16 channels
--                       The script's end, an error and /lua/<s>/stop send
--                       all off by themselves (waiting notes are dropped).
--   osc(addr, ...)      send an OSC message to debazd (any Console message:
--                       /lfo, /dds, fields, /disp, /cue/go ...). Numbers:
--                       whole = int, else float; osc_f(v) = always float
--   osc_get(addr, ...)  send and wait (0.2 s) for the reply from addr (else
--                       the first other reply): its args as a table (nil =
--                       no reply), 2nd result = its address

local ffi = require("ffi")
ffi.cdef [[
uint32_t *dzl_fb(void);
int dzl_frames_max(void);
double dzl_time(void);
void dzl_blend(int mode);
void dzl_alpha(double a);
void dzl_dirty(int x, int y, int w, int h);
void dzl_clear(uint32_t c);
void dzl_fade(double k, uint32_t to);
void dzl_trails(double k, uint32_t to);
void dzl_pset(int x, int y, uint32_t c);
uint32_t dzl_pget(int x, int y);
void dzl_line(double x0, double y0, double x1, double y1, uint32_t c, double w);
void dzl_rect(double x, double y, double w, double h, uint32_t c, int fill);
void dzl_circle(double x, double y, double r, uint32_t c, int fill, double w);
void dzl_text(int x, int y, const char *s, uint32_t c, int scale);
void dzl_scroll(int dx, int dy);
void dzl_present(void);
void dzl_grab(void);
void dzl_layer(int on, int key);
int dzl_layer_get(void);
double dzl_wait(double fps);
const char *dzl_ctl(void);
]]
local C = ffi.C
local floor, sin, cos, rad, max, min = math.floor, math.sin, math.cos, math.rad, math.max, math.min

FB = ffi.cast("uint32_t *", C.dzl_fb())
fps = 30
param = {}

local function b8(v)
  v = floor(tonumber(v) or 0)
  return v < 0 and 0 or v > 255 and 255 or v
end

function rgb(r, g, b) return b8(r) * 65536 + b8(g) * 256 + b8(b) end
function gray(v) v = b8(v) return v * 65793 end
function hsv(h, s, v)
  h = (h % 1) * 6
  s = s or 1
  v = v or 1
  local i = floor(h)
  local f = h - i
  local p, q, t = v * (1 - s), v * (1 - s * f), v * (1 - s * (1 - f))
  local r, g, b
  if i == 0 then r, g, b = v, t, p
  elseif i == 1 then r, g, b = q, v, p
  elseif i == 2 then r, g, b = p, v, t
  elseif i == 3 then r, g, b = p, q, v
  elseif i == 4 then r, g, b = t, p, v
  else r, g, b = v, p, q end
  return rgb(r * 255, g * 255, b * 255)
end

local WHITE = 0xFFFFFF
function clear(c) C.dzl_clear(c or 0) end
function fade(k, c) C.dzl_fade(k or 0.1, c or 0) end
function trails(k, c) C.dzl_trails(k or 0, c or 0) end
function pset(x, y, c) C.dzl_pset(x, y, c or WHITE) end
function pget(x, y) return C.dzl_pget(x, y) end
function line(x0, y0, x1, y1, c, w) C.dzl_line(x0, y0, x1, y1, c or WHITE, w or 1) end
function rect(x, y, w, h, c, fill) C.dzl_rect(x, y, w, h, c or WHITE, fill and 1 or 0) end
function circle(x, y, r, c, fill, w) C.dzl_circle(x, y, r, c or WHITE, fill and 1 or 0, w or 1) end
function text(x, y, s, c, scale) C.dzl_text(x, y, tostring(s), c or WHITE, scale or 1) end
function scroll(dx, dy) C.dzl_scroll(dx or 0, dy or 0) end
function dirty(x, y, w, h) C.dzl_dirty(x or 0, y or 0, w or 0, h or 0) end
function present() C.dzl_present() end
function grab() C.dzl_grab() end
function layer(on, key)
  if on == nil then return C.dzl_layer_get() ~= 0 end
  C.dzl_layer(on and 1 or 0, key or -1)
end
LAYER = C.dzl_layer_get() ~= 0
function time() return C.dzl_time() end
function alpha(a) C.dzl_alpha(a or 1) end
local BLEND = { normal = 0, add = 1, lighten = 2, sub = 3 }
function blend(m)
  local v = BLEND[m] or tonumber(m)
  if not v then error("blend: normal add lighten sub", 2) end
  C.dzl_blend(v)
end

function poly(p, c, w, closed)
  c, w = c or WHITE, w or 1
  local n = #p
  for i = 1, n - 3, 2 do C.dzl_line(p[i], p[i + 1], p[i + 2], p[i + 3], c, w) end
  if closed and n >= 4 then C.dzl_line(p[n - 1], p[n], p[1], p[2], c, w) end
end

-- the turtle
local T = {}
T.__index = T
function turtle(x, y, a)
  return setmetatable({ x = x or W / 2, y = y or H / 2, a = a or 0, down = true,
                        c = WHITE, w = 1, stack = {} }, T)
end
function T:fd(d)
  local r = rad(self.a)
  local nx, ny = self.x + sin(r) * d, self.y - cos(r) * d
  if self.down then C.dzl_line(self.x, self.y, nx, ny, self.c, self.w) end
  self.x, self.y = nx, ny
  return self
end
function T:bk(d) return self:fd(-d) end
function T:rt(a) self.a = self.a + a return self end
function T:lt(a) self.a = self.a - a return self end
function T:pu() self.down = false return self end
function T:pd() self.down = true return self end
function T:color(c) self.c = c return self end
function T:width(w) self.w = w return self end
function T:heading(a) self.a = a return self end
function T:jump(x, y) self.x, self.y = x, y return self end
function T:moveto(x, y)
  if self.down then C.dzl_line(self.x, self.y, x, y, self.c, self.w) end
  self.x, self.y = x, y
  return self
end
function T:home() self.x, self.y, self.a = W / 2, H / 2, 0 return self end
function T:push() local s = self.stack s[#s + 1] = { self.x, self.y, self.a } return self end
function T:pop()
  local s = self.stack
  local v = table.remove(s)
  if v then self.x, self.y, self.a = v[1], v[2], v[3] end
  return self
end

-- OSC to debazd (UDP 127.0.0.1:9000): the same messages as the Console
-- osc("/lfo/0/rate", 0.5)   numbers: whole = int, else float; osc_f(v) = float
-- osc_get("/lfo/0") -> the reply's args (table) or nil (timeout 0.2 s)
pcall(ffi.cdef, [[
int socket(int domain, int type, int protocol);
long sendto(int fd, const void *b, unsigned long n, int flags, const void *a, unsigned int al);
long recv(int fd, void *b, unsigned long n, int flags);
struct dzl_pollfd { int fd; short events; short revents; };
int poll(struct dzl_pollfd *p, unsigned long n, int timeout);
]])
local bit = require("bit")
local osc_fd, osc_addr
local obuf = ffi.new("uint8_t[2048]")
local f2u = ffi.new("union { float f; uint32_t u; int32_t i; }")
local OSCF = {}
function osc_f(v) return setmetatable({ v = v }, OSCF) end

local function osc_open()
  if osc_fd then return osc_fd end
  osc_fd = C.socket(2, 2, 0)                         -- AF_INET, SOCK_DGRAM
  if osc_fd < 0 then osc_fd = nil error("osc: no socket", 3) end
  osc_addr = ffi.new("uint8_t[16]", { 2, 0, 0x23, 0x28, 127, 0, 0, 1 })  -- port 9000
  return osc_fd
end

local function osc_pack(addr, ...)
  local n, tags, args = 0, { "," }, { ... }
  local function put32(i) ffi.cast("int32_t *", obuf + n)[0] = bit.bswap(i) n = n + 4 end
  local function puts(s)
    if n + #s + 4 > 2040 then error("osc: message too long", 4) end
    ffi.copy(obuf + n, s, #s) n = n + #s
    repeat obuf[n] = 0 n = n + 1 until n % 4 == 0
  end
  for i = 1, select("#", ...) do
    local v = args[i]
    if type(v) == "number" then
      tags[#tags + 1] = (v == floor(v) and v >= -2147483648 and v <= 2147483647) and "i" or "f"
    elseif getmetatable(v) == OSCF then tags[#tags + 1] = "f"
    elseif type(v) == "boolean" then tags[#tags + 1] = "i" args[i] = v and 1 or 0
    else tags[#tags + 1] = "s" args[i] = tostring(v) end
  end
  puts(addr) puts(table.concat(tags))
  for i = 2, #tags do
    local v, t = args[i - 1], tags[i]
    if t == "i" then put32(v)
    elseif t == "f" then f2u.f = type(v) == "table" and v.v or v put32(f2u.i)
    else puts(v) end
  end
  return n
end

function osc(addr, ...)
  local fd = osc_open()
  local n = osc_pack(addr, ...)
  C.sendto(fd, obuf, n, 0, osc_addr, 16)
end

local rbuf = ffi.new("uint8_t[65536]")
local function rd32(p) return bit.bswap(ffi.cast("uint32_t *", p)[0]) end
local function parse_msg(p, len)                      -- -> address, { args }
  local function str(o) local s = ffi.string(p + o) return s, o + bit.band(#s + 4, -4) end
  local a, o = str(0)
  local tags; tags, o = str(o)
  local r = {}
  for i = 2, #tags do
    local t = tags:sub(i, i)
    if t == "i" then r[#r + 1] = rd32(p + o) o = o + 4
    elseif t == "f" then f2u.i = rd32(p + o) r[#r + 1] = f2u.f o = o + 4
    elseif t == "s" then local s s, o = str(o) r[#r + 1] = s
    elseif t == "h" or t == "d" or t == "t" then o = o + 8
    elseif t == "b" then o = o + 4 + bit.band(rd32(p + o) + 3, -4) end
    if o > len then break end
  end
  return a, r
end

function osc_get(addr, ...)                           -- the reply from addr (else the first)
  local fd = osc_open()
  local pf = ffi.new("struct dzl_pollfd[1]")
  pf[0].fd, pf[0].events = fd, 1
  while C.poll(pf, 1, 0) > 0 do C.recv(fd, rbuf, 65536, 0) end   -- old replies
  osc(addr, ...)
  -- other messages of the script may answer too (e.g. /disp/<d>/show): skip
  -- them until the reply from addr comes (2026-11-20: a fence passed early)
  local first, firsta
  local t_end = C.dzl_mono() + 0.2
  while true do
    local ms = math.floor((t_end - C.dzl_mono()) * 1000)
    if ms < 0 or C.poll(pf, 1, ms) <= 0 then break end
    local n = tonumber(C.recv(fd, rbuf, 65536, 0))
    if n >= 8 then
      local p, len = rbuf, n
      local bundle = ffi.string(rbuf, 7) == "#bundle"
      if bundle and n >= 20 then p, len = rbuf + 20, rd32(rbuf + 16) end
      if not bundle or n >= 20 then
        local a, r = parse_msg(p, len)
        -- a field answers "/value" <addr> ..., a failure "/error" <why> <addr>
        if a == addr or (a == "/value" and r[1] == addr) or (a == "/error" and r[2] == addr) then
          return r, a
        end
        if not first then first, firsta = r, a end
      end
    end
  end
  return first, firsta
end

-- midi: the ALSA sequencer client in dzlua.c (real-time queue)
pcall(ffi.cdef, [[
int dzl_midi_open(const char *dest);
const char *dzl_midi_err(void);
int dzl_midi_ev(int kind, int ch, int a, int b, double at);
void dzl_midi_panic(void);
]])
midi = {}
local midi_on = false
function midi.open(dest)
  if midi_on then return true end
  if C.dzl_midi_open(dest or param.midi_dest or "FLUID Synth") ~= 0 then
    error("midi: " .. ffi.string(C.dzl_midi_err()), 2)
  end
  midi_on = true
  return true
end
local function mo() if not midi_on then midi.open() end end
local function ev(kind, ch, a, b, at) mo() C.dzl_midi_ev(kind, ch, a, b, at or -1) end
function midi.on(ch, n, v, at) ev(0, ch, n, v or 100, at) end
function midi.off(ch, n, at) ev(1, ch, n, 0, at) end
function midi.note(ch, n, v, len, at)
  at = at or C.dzl_time()
  ev(0, ch, n, v or 100, at)
  ev(1, ch, n, 0, at + (len or 0.25))
end
function midi.cc(ch, c, v, at) ev(2, ch, c, v, at) end
function midi.program(ch, p, at) ev(3, ch, p, 0, at) end
function midi.bend(ch, v, at) ev(4, ch, v, 0, at) end
function midi.panic() if midi_on then C.dzl_midi_panic() end end

-- audio: debazd's analysis (react.c) through shared memory
-- (lib/dz_react_shm.h; ⚠️ keep this struct equal to it)
pcall(ffi.cdef, [[
typedef struct {
  uint32_t magic, version, seq, poke, frame;
  int32_t running, source, movie_slot;
  double t;
  float feat[9];
  float band[16];
  int32_t fft_n, nbins;
  float spec[513];
  int32_t nwave;
  uint32_t total_lo;
  float wave_m[2048], wave_l[2048], wave_r[2048];
} dz_react_shm;
int dzl_audio(dz_react_shm *dst);
double dzl_mono(void);
]])
local asnap = ffi.new("dz_react_shm")
local AFEAT = { "level", "peak", "bass", "low", "mid", "high", "air", "flux", "beat" }
local ASRC = { [0] = "off", "capture", "peak", [4] = "movie" }
local audio_on = false
local AU = {}
local function audio_update()
  local ok = C.dzl_audio(asnap)
  if ok < 0 then error("audio: debazd and dzlua differ (dz_react_shm version)", 0) end
  local a, s = AU, asnap
  local live = ok == 1 and s.running ~= 0
  for i = 1, 9 do rawset(a, AFEAT[i], live and s.feat[i - 1] or 0) end
  rawset(a, "running", live)
  rawset(a, "source", ok == 1 and (ASRC[s.source] or tostring(s.source)) or "none")
  rawset(a, "movie_slot", s.movie_slot)
  rawset(a, "frame", s.frame)
  rawset(a, "age", ok == 1 and math.max(0, C.dzl_mono() - s.t) or 1e9)  -- s since the write
  rawset(a, "band", s.band)
  rawset(a, "spec", s.spec)
  rawset(a, "nbins", live and s.nbins or 0)
  rawset(a, "fft_n", s.fft_n)
  rawset(a, "n", live and s.nwave or 0)
  rawset(a, "M", s.wave_m)
  rawset(a, "L", s.wave_l)
  rawset(a, "R", s.wave_r)
end
function AU.hz(k) return k * 48000 / (asnap.fft_n > 0 and asnap.fft_n or 1024) end
function AU.bin(hz) return math.floor(hz * (asnap.fft_n > 0 and asnap.fft_n or 1024) / 48000 + 0.5) end
audio = setmetatable(AU, { __index = function(t, k)
  if not audio_on then                 -- the first use turns the feed on
    audio_on = true
    audio_update()
    return rawget(t, k)
  end
end })

-- parameters from debazd (the control FIFO)
local function poll()
  while true do
    local p = C.dzl_ctl()
    if p == nil then break end
    local k, v = ffi.string(p):match("^(%S+)%s?(.*)$")
    if k then
      local n = tonumber(v)
      if n then v = n end
      if k == "fps" and n then fps = n else param[k] = v end
      if onparam then onparam(k, v) end
    end
  end
end

function wait()
  C.dzl_present()
  poll()
  if audio_on then audio_update() end
  return C.dzl_wait(fps)
end

-- print: to the log, at most 256 KB (the log is in RAM)
local logged, LOGMAX = 0, 262144
print = function(...)
  if logged > LOGMAX then return end
  local t = {}
  for i = 1, select("#", ...) do t[i] = tostring((select(i, ...))) end
  local s = table.concat(t, "\t")
  logged = logged + #s + 1
  io.stdout:write(s, "\n")
  if logged > LOGMAX then io.stdout:write("[dzlua: log full, print is off]\n") end
end

-- run the script
local chunk, err = loadstring(SCRIPT, "@" .. SCRIPT_NAME)
if not chunk then error(err, 0) end
local ok, e = xpcall(function()
  poll()
  chunk()
  poll()
  if setup then setup() end
  if frame then
    local n, nmax, t = 0, C.dzl_frames_max(), C.dzl_time()
    while nmax == 0 or n < nmax do
      frame(n, t)
      t = wait()
      n = n + 1
    end
  end
end, debug.traceback)
if not ok then error(e, 0) end

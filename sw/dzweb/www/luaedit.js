// luaedit.js - Console tab, Lua: write a LuaJIT script, save it on the unit
// (/media/scripts/<name>.lua), run it into a slot (debazd /lua/<s>/start,
// sw/debazd/lua.c), read its print() output and errors. API: sw/dzlua/prelude.lua.
import * as net from "./net.js";
import { h, store, toast } from "./ui.js";
import { highlight, lint, helpAt } from "./luahl.js";
import { API as REF } from "./luaapi.js";

const EXAMPLES = {
  "turtle-flower": `-- turtle curve on loop: a spiral that turns, the old frames fade
-- params (Console: p): step (3), angle (121)
local t = turtle()
blend("add")
trails(0.08)        -- the old frames fade (cheaper than fade() in frame)
fps = 30

function frame(n, time)
  t:jump(W / 2, H / 2):heading(n * 2)
  local hue = (time * 0.05) % 1
  for i = 1, 120 do
    t:color(hsv(hue + i / 400, 0.8, 0.6))
    t:fd(i * (param.step or 3)):rt(param.angle or 121)
  end
end
`,
  "turtle-tree": `-- a branching tree (recursion + push/pop), it sways
-- params: depth (9), wind (1)
local t = turtle()

local function branch(len, d, sway)
  if d == 0 then return end
  t:width(d * 0.8):color(hsv(0.08 + (9 - d) * 0.04, 0.7, 0.4 + d * 0.06))
  t:fd(len)
  t:push():lt(22 + sway):pop()
  t:push():lt(22 + sway); branch(len * 0.72, d - 1, sway); t:pop()
  t:push():rt(25 - sway); branch(len * 0.68, d - 1, sway); t:pop()
end

function frame(n, time)
  clear(rgb(8, 10, 20))
  t:jump(W / 2, H - 20):heading(0)
  branch(H / 5, param.depth or 9, math.sin(time * 1.3) * 6 * (param.wind or 1))
end
`,
  "harmonograph": `-- a damped pendulum curve drawn a little more each frame, then again
local A = { 1.00, 2.01, 3.00, 1.99 }
local seg, x0, y0 = 0

function frame(n, time)
  if seg == 0 then clear() A[2] = 2 + math.random() * 0.02 end
  for i = 1, 40 do
    local s = seg * 0.02
    local d = math.exp(-s * 0.004)
    local x = W / 2 + d * (H * 0.3 * math.sin(A[1] * s) + H * 0.15 * math.sin(A[2] * s + 1))
    local y = H / 2 + d * (H * 0.3 * math.sin(A[3] * s + 0.5) + H * 0.15 * math.sin(A[4] * s))
    if x0 then line(x0, y0, x, y, hsv(s * 0.002, 0.7, 1), 1.5) end
    x0, y0, seg = x, y, seg + 1
  end
  if seg > 40000 then seg, x0 = 0, nil end
end
`,
  "life": `-- Conway's life, written straight into FB (the canvas as uint32_t[W*H])
local CS = param.cell or 8               -- cell size in pixels
local cw, ch = math.floor(W / CS), math.floor(H / CS)
local a, b = {}, {}
for i = 0, cw * ch - 1 do a[i] = math.random() < 0.25 and 1 or 0 end
fps = 15

local function cell(x, y, c)
  for yy = y * CS, y * CS + CS - 2 do
    local row = yy * W
    for xx = x * CS, x * CS + CS - 2 do FB[row + xx] = c end
  end
end

function frame(n)
  for y = 0, ch - 1 do
    for x = 0, cw - 1 do
      local s = 0
      for dy = -1, 1 do for dx = -1, 1 do
        if dx ~= 0 or dy ~= 0 then s = s + a[((y + dy) % ch) * cw + (x + dx) % cw] end
      end end
      local v = a[y * cw + x]
      local nv = (s == 3 or (v == 1 and s == 2)) and 1 or 0
      b[y * cw + x] = nv
      if nv ~= v or n == 0 then cell(x, y, nv == 1 and hsv(n / 300, 0.6, 1) or 0x101010) end
    end
  end
  a, b = b, a
  dirty()
end
`,
  "skeleton": `-- TEMPLATE: the parts of a script, start here
-- Each param has a default; a new value from /lua/<s>/p/<key> v (Console:
-- the key/value boxes, an LFO target, a cue) is smoothed so it never jumps.
-- QUIRK: debazd keeps the params of a slot and sends them again at each
-- start (also to the next script on that slot): /lua/<s>/p/<key> with no
-- value forgets one.
local P = { speed = 1, size = 80, hue = 0.6 }   -- defaults (and the keys)
local cur = {}                                   -- smoothed values
for k, v in pairs(P) do cur[k] = v end

function onparam(k, v)              -- each new value (v is a number if it reads as one)
  print("param", k, v)              -- shows in the log below
end

function setup()                    -- once, before frame 0
  clear()
  trails(0.15)                      -- the old frames fade (fused with the copy)
  fps = 30                          -- or param "fps"
end

local function p(k)                 -- smoothed param: 15 % of the way each frame
  local want = tonumber(param[k]) or P[k]
  cur[k] = cur[k] + (want - cur[k]) * 0.15
  return cur[k]
end

function frame(n, t)                -- n = frame number, t = seconds since start
  -- (trails() in setup fades the old frames: cheaper than fade() here)
  local r = p("size")
  local x = W / 2 + math.cos(t * p("speed")) * (W / 3)
  local y = H / 2 + math.sin(t * p("speed") * 1.3) * (H / 3)
  circle(x, y, r, hsv(p("hue"), 0.7, 1), true)
  if n % 150 == 0 then print(string.format("frame %d, %.1f s", n, t)) end
end
`,
  "draw-once": `-- TEMPLATE: draw once and end: no frame(), no loop. The picture stays in
-- the slot and the script uses no CPU. Here: a test card (grid, circle,
-- colour bars, the size). Good to check a crop, a projector or a key.
clear(rgb(40, 40, 40))
local step = param.step or 80
for x = 0, W, step do line(x, 0, x, H, gray(110)) end
for y = 0, H, step do line(0, y, W, y, gray(110)) end
local bars = { 0xFFFFFF, 0xFFFF00, 0x00FFFF, 0x00FF00, 0xFF00FF, 0xFF0000, 0x0000FF, 0x000000 }
local bw = W / #bars
for i, c in ipairs(bars) do rect((i - 1) * bw, H * 0.7, bw + 1, H * 0.15, c, true) end
circle(W / 2, H / 2, H * 0.45, 0xFFFFFF, false, 3)
line(0, 0, W, H, 0xFF0000, 2) line(W, 0, 0, H, 0xFF0000, 2)
text(W / 2 - 60, H / 2 - 16, W .. " x " .. H, 0xFFFFFF, 2)
text(10, 10, "slot " .. SLOT, 0xFFFFFF, 2)
print("drawn", W, H)
`,
  "own-loop": `-- TEMPLATE: your own loop instead of frame(): code that reads top to bottom,
-- like a sequence of scenes. wait() shows the frame, reads params and sleeps
-- to the next frame (returns the time). Ends after the last scene (the
-- picture stays) unless param loop is 1.
local function hold(s, fn)          -- run fn(k) each frame for s seconds, k 0..1
  local t0 = time()
  repeat
    local k = (time() - t0) / s
    fn(k > 1 and 1 or k)
    wait()
  until time() - t0 >= s
end

repeat
  hold(2, function(k) clear(gray(k * 255)) end)                  -- fade up
  hold(2, function(k) clear() circle(W / 2, H / 2, k * H / 2, rgb(255, 80, 0), true) end)
  for i = 1, 3 do                                                -- 3 flashes
    hold(0.15, function() clear(0xFFFFFF) end)
    hold(0.15, function() clear() end)
  end
  local tu = turtle()
  hold(3, function(k)                                            -- draw a star
    tu:color(hsv(k, 1, 1)):width(3):fd(H / 4 * 0.05):rt(144 * 0.05)
  end)
  text(20, 20, "the end", 0xFFFFFF, 3)
  wait()
until (param.loop or 0) == 0
`,
  "layer-overlay": `-- TEMPLATE: an overlay on a slot that something else fills (a picture, paint,
-- a movie, the capture). Layer mode: only pixels brighter than the key
-- (default 8) reach the slot; black = transparent, so draw on a black canvas.
-- QUIRKS: dark colours (all channels <= key) vanish too; anti-aliased edges
-- fade into the key, so thin lines look thinner; over a MOVIE or the capture
-- the overlay is seen only until their next frame (they rewrite the slot).
-- Best over a still picture or paint. debazd turns layer mode on by itself
-- when a movie / the capture runs there (Lua panel: layer auto).
layer(true, param.key or 8)
local msg = param.msg or "DEBAZAROS"

function frame(n, t)
  clear()                                  -- black = keep the slot as it is
  local x = (W - #msg * 8 * 6) / 2
  text(x, H * 0.4, msg, hsv(t * 0.1, 0.5, 1), 6)
  for i = 0, 11 do                         -- a turning ring of dots
    local a = t + i * math.pi / 6
    circle(W / 2 + math.cos(a) * H * 0.35, H / 2 + math.sin(a) * H * 0.35, 10,
           0xFFFFFF, true)
  end
  rect(20, 20, W - 40, H - 40, 0xFF2020, false)   -- a frame
end
`,
  "osc-control": `-- TEMPLATE: drive debazd from a script with osc(): every Console message
-- works (/lfo, /dds, /fx, fields like /hdmi/1/osc/sin/gain/rgb, /disp,
-- /cue/go ...). osc_get() sends a query and returns the reply's args.
-- Costs: osc() ~0.1 ms, osc_get() ~1 ms (a round trip): fine a few times a
-- frame, never per pixel. Split the work: an LFO runs in debazd frame-exact
-- for free; the script sends only what an LFO cannot make.
-- QUIRK: what a script sets STAYS after it stops (it is debazd state): undo
-- it yourself (param off 1 here), or with a cue / /state/recall.
local hue0 = osc_get("/fx/hue") or { 0, 1 }          -- the old value, to undo
local pinc0 = (osc_get("/dds/1/pinc") or {})[2]     -- field reply: path, raw, value
print("hue was", hue0[1], hue0[2], "dds 1 pinc", pinc0)

-- an LFO in debazd turns the colour matrix hue (no script time per frame)
osc("/lfo/4/shape", "sine")
osc("/lfo/4/rate", osc_f(0.1))
osc("/lfo/4/range", 0, 360)
osc("/lfo/4/target", "/fx/hue/deg $f4")
osc("/lfo/4/on", 1)

local done = false
function onparam(k, v)
  if k == "off" and v == 1 and not done then
    done = true
    osc("/lfo/4/on", 0)
    osc("/lfo/4/target")
    osc("/fx/hue", osc_f(hue0[1]), osc_f(hue0[2]))
    if pinc0 then osc("/dds/1/pinc", pinc0) end
    print("undone")
  end
end

local deg = 0
function frame(n, t)
  if done then return end
  -- the script's own part: the HDMI_1 oscillator steps up a scale each beat
  if n % 15 == 0 then
    local step = ({ 0, 2, 4, 7, 9, 12 })[(n / 15) % 6 + 1]
    osc("/dds/1/hz", osc_f(30 * 2 ^ (step / 12)))
  end
  if n % 10 == 0 then                                  -- read back, show it
    local r = osc_get("/lfo/4")
    if r then deg = r[1] end
    rect(0, 0, 360, 40, 0, true)
    text(10, 10, string.format("hue %.0f deg", deg), 0xFFFFFF, 2)
  end
end
`,
  "sprite-bounce": `-- TEMPLATE: a debazd sprite bounces across display 0, then across display 1,
-- then back: one wide floor made of two slots. The script draws nothing in
-- its own canvas: it is a controller and sends OSC (osc()) each frame:
-- a black box over the old place, then /sprite/<id>/draw at the new one.
-- Run it on a slot that is NOT one of the two (e.g. 9): it writes nothing there.
-- params: a (5), b (6) = the slots of display 0 / 1 (show 1 = put them on
--   the displays), sprite ("sigil-01-bael.png", in /media/debaz/img), id (0),
--   scale (0.6), speed (9) px per frame, spin (3) degrees per frame,
--   gravity (0.8), bounce (0.9) energy kept per floor hit
local A, B = param.a or 5, param.b or 6
local ID = param.id or 0
local SC = param.scale or 0.6
local R = math.ceil(256 * SC * 0.71) + 3            -- half box of the rotated sprite

osc("/sprite/" .. ID .. "/load", param.sprite or "sigil-01-bael.png")
if (param.show or 1) ~= 0 then
  osc("/disp/0/show", A)
  osc("/disp/1/show", B)
end
osc("/draw/" .. A .. "/solid", 0, 0, 0)
osc("/draw/" .. B .. "/solid", 0, 0, 0)

local x, y = R, R                                    -- x: 0 .. 2W across both
local vx, vy, ang = param.speed or 9, 0, 0
local old = {}                                       -- slot -> {x, y} drawn last

-- the sprite at virtual x: on A, on B, or on both while it crosses the seam
local function place(px, py)
  local now = {}
  if px - R < W then now[A] = { px, py } end
  if px + R >= W then now[B] = { px - W, py } end
  for s, p in pairs(old) do                          -- erase where it was
    osc("/draw/" .. s .. "/rect", 0, 0, 0, math.floor(p[1] - R), math.floor(p[2] - R), 2 * R, 2 * R)
  end
  for s, p in pairs(now) do
    osc("/sprite/" .. ID .. "/draw", s, osc_f(p[1]), osc_f(p[2]), osc_f(SC), osc_f(ang), osc_f(1))
  end
  old = now
end

function frame(n, t)
  local g, k = param.gravity or 0.8, param.bounce or 0.9
  vy = vy + g
  x, y = x + vx, y + vy
  if y > H - R then y = H - R; vy = -math.abs(vy) * k; if math.abs(vy) < 6 then vy = -22 end end
  if x > 2 * W - R then x = 2 * W - R; vx = -math.abs(vx) end   -- far wall: back
  if x < R then x = R; vx = math.abs(vx) end                     -- near wall: again
  ang = (ang + (param.spin or 3) * (vx > 0 and 1 or -1)) % 360
  place(x, y)
end
`,
  "sprite-swarm": `-- TEMPLATE / STRESS TEST: every sprite loaded on the unit (/sprite/<id> for
-- 0..63) bounces across display 0 and display 1 (one wide floor of two
-- slots). A controller script: it sends OSC each frame (osc()), the drawing
-- happens in debazd. Run it on a slot that is not one of them (e.g. 9).
-- Each frame: first ALL old boxes are erased, then ALL sprites drawn (an
-- erase never cuts a sprite drawn earlier in the same frame).
-- flip 1 = double buffer: each display gets a second slot, the frame is
-- drawn there and the display switches to it at vsync, after debazd has
-- finished drawing it: no half-erased sprite is ever on screen. Each slot remembers the boxes drawn into it
-- (two frames ago) and erases only those: about the same work as flip 0
-- (a full clear per frame was 54 ms a slot at 1920 x 1080).
-- Pacing: each frame ends with a query that debazd answers after the
-- frame's messages (osc_get = a fence): the script runs as fast as debazd
-- draws (~1.6 ms per erase box, ~2 ms per sprite at scale 0.35), and the
-- pixel thread's queue cannot overflow (it did at 30 fps: 1023 waiting).
-- params: a (5), b (6) the slots of display 0 / 1; a2 (7), b2 (8) their
--   back slots (flip); show (1); scale (0.35); speed (6); spin (2);
--   flip (0); max (64) sprites at most
local A, B = param.a or 5, param.b or 6
local FLIP = (param.flip or 0) ~= 0
local SC = param.scale or 0.35
local R = math.ceil(256 * SC * 0.71) + 3

-- the loaded sprites: one query per number (osc_get gets one reply)
local ids = {}
for id = 0, 63 do
  local r, addr = osc_get("/sprite/" .. id)
  if addr == "/sprite/" .. id and #ids < (param.max or 64) then ids[#ids + 1] = id end
end
print(#ids .. " sprites: " .. table.concat(ids, " "))
if #ids == 0 then error("no sprites loaded (Media tab, Sprites card)") end

local front = { [0] = A, [1] = B }                   -- what each display shows
local back = { [0] = param.a2 or 7, [1] = param.b2 or 8 }
if (param.show or 1) ~= 0 then osc("/disp/0/show", A) osc("/disp/1/show", B) end
for _, s in ipairs({ A, B, back[0], back[1] }) do osc("/draw/" .. s .. "/clear", 0, 0, 0) end

local sp = {}
for k, id in ipairs(ids) do
  local a = math.random() * 2 * math.pi
  local v = (param.speed or 6) * (0.6 + math.random() * 0.8)
  sp[k] = { id = id, x = R + math.random() * (2 * W - 2 * R), y = R + math.random() * (H - 2 * R),
            vx = math.cos(a) * v, vy = math.sin(a) * v, ang = math.random() * 360,
            spin = (param.spin or 2) * (math.random() < 0.5 and -1 or 1) * (0.5 + math.random()) }
end
local old = {}                                       -- erase boxes: { slot, x, y }
local drawn = {}                                     -- flip: slot -> boxes drawn into it

-- display d's part of the virtual x range [0, 2W)
local function parts(x)
  local p = {}
  if x - R < W then p[#p + 1] = { 0, x } end
  if x + R >= W then p[#p + 1] = { 1, x - W } end
  return p
end

local fence = "/sprite/" .. ids[1]
local function wait_drawn()                          -- until debazd has done this frame
  for _ = 1, 25 do if osc_get(fence) then return end end
end

function frame(n, t)
  wait_drawn()
  for _, s in ipairs(sp) do                          -- move
    s.x, s.y = s.x + s.vx, s.y + s.vy
    if s.x < R then s.x, s.vx = R, math.abs(s.vx) elseif s.x > 2 * W - R then s.x, s.vx = 2 * W - R, -math.abs(s.vx) end
    if s.y < R then s.y, s.vy = R, math.abs(s.vy) elseif s.y > H - R then s.y, s.vy = H - R, -math.abs(s.vy) end
    s.ang = (s.ang + s.spin) % 360
  end
  if FLIP then                                       -- draw into the back slots, then show them
    for d = 0, 1 do                                  -- what this back slot got last time
      local bs = back[d]
      for _, o in ipairs(drawn[bs] or {}) do
        osc("/draw/" .. bs .. "/rect", 0, 0, 0, math.floor(o[1] - R), math.floor(o[2] - R), 2 * R, 2 * R)
      end
      drawn[bs] = {}
    end
    for _, s in ipairs(sp) do
      for _, p in ipairs(parts(s.x)) do
        local bs = back[p[1]]
        osc("/sprite/" .. s.id .. "/draw", bs, osc_f(p[2]), osc_f(s.y), osc_f(SC), osc_f(s.ang), osc_f(1))
        local t = drawn[bs] t[#t + 1] = { p[2], s.y }
      end
    end
    -- the switch only after debazd has drawn the back slots: /disp/<d>/show
    -- runs on debazd's main thread at the next vsync, the drawing on its
    -- pixel thread (not in order with each other: without this wait a
    -- half-drawn back slot could go on screen)
    wait_drawn()
    for d = 0, 1 do
      osc("/disp/" .. d .. "/show", back[d])
      front[d], back[d] = back[d], front[d]
    end
    return
  end
  for _, o in ipairs(old) do                         -- 1. erase every old box
    osc("/draw/" .. o[1] .. "/rect", 0, 0, 0, math.floor(o[2] - R), math.floor(o[3] - R), 2 * R, 2 * R)
  end
  old = {}
  for _, s in ipairs(sp) do                          -- 2. draw every sprite
    for _, p in ipairs(parts(s.x)) do
      local slot = p[1] == 0 and A or B
      osc("/sprite/" .. s.id .. "/draw", slot, osc_f(p[2]), osc_f(s.y), osc_f(SC), osc_f(s.ang), osc_f(1))
      old[#old + 1] = { slot, p[2], s.y }
    end
  end
end
`,
  "audio-scope": `-- TEMPLATE: an oscilloscope of the audio (debazd's analysis, \`audio\`).
-- Source: /audio/react/source auto (a movie that plays audio, else the
-- HDMI_2 input), capture, movie. params:
--   mode  "wave" (default) | "xy" (left = x, right = y) | "spec" (spectrum)
--   gain  (4: laptop / movie audio is often at 0.1-0.3 of full scale)
--   span  samples across the screen in wave mode (1024 = 21 ms)
--   glow  phosphor trails 0..1 (0.3)
-- The wave is triggered: it starts at a rising zero crossing of the mix,
-- so a steady tone stands still.
local floor, log10, max, min = math.floor, math.log10, math.max, math.min
local CL, CR, CM = rgb(80, 255, 120), rgb(255, 120, 60), rgb(120, 180, 255)

local function trigger(M, n, span)          -- index of a rising zero crossing
  for i = n - span - 1, max(1, n - span - 1024), -1 do
    if M[i - 1] < 0 and M[i] >= 0 then return i end
  end
  return n - span
end

local function wave(g)
  local n = audio.n
  local span = min(floor(param.span or 1024), n - 2)
  local i0 = trigger(audio.M, n, span)
  local L, R = audio.L, audio.R
  local h4 = H / 4
  local px, pl, pr
  for k = 0, span - 1, 2 do                 -- every 2nd sample: enough at 1024
    local x = k * W / span
    local yl = H * 0.3 - L[i0 + k] * g * h4
    local yr = H * 0.7 - R[i0 + k] * g * h4
    if px then line(px, pl, x, yl, CL, 2) line(px, pr, x, yr, CR, 2) end
    px, pl, pr = x, yl, yr
  end
end

local function xy(g)
  local n, L, R = audio.n, audio.L, audio.R
  local s = H * 0.45 * g
  local cx, cy = W / 2, H / 2
  blend("add") alpha(0.5)
  local px, py
  for i = n - 1024, n - 1 do                -- the newest 1024 samples
    local x, y = cx + L[i] * s, cy - R[i] * s
    if px then line(px, py, x, y, CM, 1) end
    px, py = x, y
  end
  blend("normal") alpha(1)
end

local function spec(g)
  local nb, S = audio.nbins, audio.spec
  local cols = 128
  local f0, f1 = log10(30), log10(20000)
  local bw = W / cols
  for c = 0, cols - 1 do                    -- log frequency axis, dB height
    local k0 = audio.bin(10 ^ (f0 + (f1 - f0) * c / cols))
    local k1 = max(k0, audio.bin(10 ^ (f0 + (f1 - f0) * (c + 1) / cols)) - 1)
    local a = 0
    for k = k0, min(k1, nb - 1) do a = max(a, S[k]) end
    local db = 20 * log10(a * g + 1e-6)     -- 0 dB = full scale
    local h = max(0, (db + 60) / 60) * H * 0.9
    rect(c * bw, H - h, bw - 1, h, hsv(c / cols * 0.8, 0.8, 1), true)
  end
end

function frame(n, t)
  trails(param.glow or 0.3)
  local g = param.gain or 4
  if not audio.running or audio.n < 1100 then
    line(0, H / 2, W, H / 2, gray(60))
    text(20, 20, "no audio (" .. audio.source .. ")", 0xFFFFFF, 2)
    return
  end
  local m = param.mode or "wave"
  if m == "xy" then xy(g) elseif m == "spec" then spec(g) else wave(g) end
  text(20, 20, string.format("%s  level %.2f", audio.source, audio.level), gray(160), 2)
end
`,
  "audio-react": `-- TEMPLATE: react to sound with the features of \`audio\` (debazd's
-- analysis, updated each frame; the first use turns it on):
--   audio.level .peak .bass .low .mid .high .air .flux .beat (0|1),
--   audio.band[0..15], audio.running, audio.source
-- Source: /audio/react/source auto | movie | capture. Laptop and movie
-- audio is often at 0.1-0.3 of full scale: param gain (4).
-- (To move debazd things - hue, DDS, gains - without a script, use an LFO
-- with shape audio: /lfo/0/audio bass, /lfo/0/target "/fx/hue/deg $f0".)
trails(0.12)
blend("add")
local env = 0                                 -- a decaying flash on each beat

function frame(n, t)
  local g = param.gain or 4
  local bass, high = math.min(1, audio.bass * g), math.min(1, audio.high * g)
  if audio.beat > 0 then env = 1 end
  env = env * 0.85
  circle(W / 2, H / 2, 40 + bass * H * 0.4, hsv(0.02, 0.9, 0.5), false, 4 + env * 20)
  for i = 1, math.floor(high * 60) do         -- sparks: more on the highs
    local a, r = math.random() * 6.283, H * (0.1 + math.random() * 0.4)
    pset(W / 2 + math.cos(a) * r, H / 2 + math.sin(a) * r, hsv(0.55, 0.3, 1))
  end
  local bw = W / 16                           -- the 16 bands along the bottom
  for b = 0, 15 do
    local h = math.min(1, audio.band[b] * g) * H * 0.25
    rect(b * bw + 2, H - h, bw - 4, h, hsv(b / 16, 0.7, 0.4), true)
  end
end
`,
  "midi-io": `-- TEMPLATE: MIDI in from an ALSA raw MIDI device (LuaJIT FFI: open/read of
-- the C library), MIDI out with midi.* (the ALSA sequencer, on time, all
-- notes off at the end). In: VirMIDI 1-0 (/dev/snd/midiC1D0, client 20) by
-- default; route a source to it with aconnect on the unit, e.g.
--   aconnect 21:0 20:0     test: amidi -p hw:1,1 -S "90 3C 7F"
-- (dzsynth.sh connects VirMIDI to the synth too: notes you send to 20 also
-- sound.) In: note on = a circle (x = pitch, size = velocity), CC n =
-- param.cc<n>. Out: a note each time the ball hits a wall (to "FLUID Synth":
-- sudo dzsynth.sh start). param dev = other input device.
local ffi = require("ffi")
local bit = require("bit")
pcall(ffi.cdef, [[
int open(const char *path, int flags, ...);
long read(int fd, void *buf, unsigned long n);
long write(int fd, const void *buf, unsigned long n);
int close(int fd);
]])
local O_RDWR, O_NONBLOCK = 2, 2048                  -- Linux ARM values
local fd = ffi.C.open(param.dev or "/dev/snd/midiC1D0", O_RDWR + O_NONBLOCK)
if fd < 0 then error("cannot open the MIDI device (dev param)") end
local buf = ffi.new("uint8_t[512]")


local status, data = 0, {}                          -- parser (running status)
local function on_msg(st, d1, d2)
  local kind, ch = bit.band(st, 0xF0), bit.band(st, 0x0F)
  if kind == 0x90 and d2 > 0 then
    circle(d1 / 127 * W, H - d2 / 127 * H, 4 + d2 / 4, hsv(ch / 16, 0.8, 1), true)
  elseif kind == 0xB0 then
    param["cc" .. d1] = d2 / 127
  end
end
local function midi_in()
  local n = ffi.C.read(fd, buf, 512)
  for i = 0, n - 1 do
    local b = buf[i]
    if b >= 0xF8 then                               -- clock etc.: ignore
    elseif b >= 0x80 then status, data = b, {}
    elseif status ~= 0 then
      data[#data + 1] = b
      local k = bit.band(status, 0xF0)
      local need = (k == 0xC0 or k == 0xD0) and 1 or 2
      if #data == need then on_msg(status, data[1], data[2] or 0) data = {} end
    end
  end
end

local x, y, vx, vy = W / 2, H / 2, 9, 7
function frame(n, t)
  fade(0.05)
  midi_in()
  x, y = x + vx, y + vy
  if x < 0 or x > W then vx = -vx midi.note(0, 48 + math.floor(y / H * 24), 100, 0.3) end
  if y < 0 or y > H then vy = -vy midi.note(0, 60 + math.floor(x / W * 24), 80, 0.3) end
  circle(x, y, 8 + (param.cc1 or 0) * 60, 0xFFFFFF, true)
end
`,
  "midi-arp": `-- TEMPLATE: MIDI out on time (midi.*: the ALSA sequencer). Start the synth
-- first (sudo dzsynth.sh start). Every step is scheduled AHEAD seconds before
-- it sounds, with its exact time: the tempo does not follow the frame rate.
-- An arpeggio, a bass line and drums; the notes are drawn when they are sent.
-- Stop = all notes off (the script's end, an error or /lua/<s>/stop do it).
-- params: bpm (110), prog (lead GM program 0-127, default 81 = saw lead),
--   bass (33 = finger bass), voices (1-4 lead notes per step), drums (1),
--   vel (90), swing (0..0.5: every 2nd sixteenth later), ahead (0.2 s)
local CHORDS = { { 57, 60, 64, 67 }, { 53, 57, 60, 64 }, { 48, 52, 55, 59 }, { 55, 59, 62, 65 } }  -- Am7 Fmaj7 Cmaj7 G7
midi.program(0, param.prog or 81)    -- lead on channel 0
midi.program(1, param.bass or 33)    -- bass on channel 1
trails(0.08)

local function dot(ch, n, v)
  circle((n - 24) / 72 * W, H - (v / 127) * H * 0.8 - 40, 6 + ch * 4, hsv(ch / 10 + n / 120, 0.8, 1), true)
end
local function note(ch, n, v, len, at)
  midi.note(ch, n, v, len, at)
  dot(ch, n, v)
end

local step, nextt = 0, time() + 0.1
function onparam(k, v)
  if k == "prog" then midi.program(0, v) elseif k == "bass" then midi.program(1, v) end
end

function frame(n, t)
  local spb = 60 / (param.bpm or 110) / 4        -- one sixteenth
  local v = param.vel or 90
  while nextt < t + (param.ahead or 0.2) do      -- everything due in the next AHEAD s
    local at = nextt + ((step % 2 == 1) and spb * (param.swing or 0) or 0)
    local ch = CHORDS[math.floor(step / 16) % #CHORDS + 1]
    for k = 1, math.max(1, math.min(4, param.voices or 1)) do
      note(0, ch[(step + k - 1) % 4 + 1] + 12 * (k > 2 and 1 or 0) + ((step % 8 >= 4) and 12 or 0), v, spb * 0.9, at)
    end
    if step % 4 == 0 then note(1, ch[1] - 24, v + 10, spb * 3.5, at) end
    if (param.drums or 1) ~= 0 then
      if step % 4 == 0 then note(9, 36, 110, spb, at) end           -- kick
      if step % 8 == 4 then note(9, 38, 100, spb, at) end           -- snare
      note(9, 42, step % 2 == 0 and 70 or 40, spb * 0.5, at)         -- hat
    end
    step = step + 1
    nextt = nextt + spb
  end
end
`,
  "dirty-fast": `-- QUIRK: only the changed area goes to the slot, so small changes are fast.
-- Each frame erases the balls' old boxes and draws the new ones: no clear(),
-- no fade(). dzlua keeps ONE changed rectangle per frame (the box around
-- everything drawn), so balls far apart make it big again: present() after
-- each ball copies each small box alone. param split 0 = one box, 1 = per ball.
-- Measured at 720p: split 1 = 2.1 ms per frame, split 0 = 7.8 ms (two far
-- circles: 0.4 ms with a present() each, 8.5 ms with one). Status line: ms.
local N, R = param.n or 6, 24
local B = {}
for i = 1, N do
  B[i] = { x = math.random(R, W - R), y = math.random(R, H - R),
           vx = (math.random() - 0.5) * 16, vy = (math.random() - 0.5) * 16,
           c = hsv(i / N, 0.8, 1) }
end
clear()

function frame()
  local split = (param.split or 1) ~= 0
  for _, b in ipairs(B) do
    rect(b.x - R - 2, b.y - R - 2, 2 * R + 4, 2 * R + 4, 0, true)  -- erase old
    b.x, b.y = b.x + b.vx, b.y + b.vy
    if b.x < R or b.x > W - R then b.vx = -b.vx end
    if b.y < R or b.y > H - R then b.vy = -b.vy end
    -- the erase box and the new ball are next to each other: one small box
    circle(b.x, b.y, R, b.c, true)
    if split then present() end
  end
end
`,
  "fb-plasma": `-- QUIRK: writing pixels. FB[y * W + x] = c in a plain loop is the fastest
-- way (LuaJIT compiles it to a store). pset() blends and clips each pixel
-- (slower, use it for few pixels). After FB writes call dirty(): FB writes
-- do not mark anything. A full canvas per frame costs ~7 ms for the copy
-- to the slot alone (720p); keep the per-pixel math small: here the sines
-- are made once per column, row and diagonal (not per pixel), one row is
-- computed and ffi.copy() repeats it (short nested loops per block are 3x
-- slower: LuaJIT likes long simple loops). 720p alone: cell 4 = 32 ms,
-- cell 1 = per-pixel math, ~4x more. params: cell (4), speed (1)
local bit = require("bit")
local ffi = require("ffi")
local sin, floor, min = math.sin, math.floor, math.min
local pal = ffi.new("uint32_t[256]")  -- 256 colours, made once (no hsv() per pixel)
for i = 0, 255 do pal[i] = hsv(i / 256, 0.8, 0.5 + 0.5 * sin(i / 256 * math.pi * 2)) end
local sx, sy, sd = ffi.new("double[?]", W + 1), ffi.new("double[?]", H + 1),
                   ffi.new("double[?]", W + H + 2)

function frame(n, t)
  local CS = floor(param.cell or 4)
  if CS < 1 then CS = 1 end
  local tt = t * (param.speed or 1)
  for x = 0, W, CS do sx[x] = sin(x * 0.011 + tt) end
  for y = 0, H, CS do sy[y] = sin(y * 0.013 - tt * 1.3) end
  for d = 0, W + H, CS do sd[d] = sin(d * 0.007 + tt * 0.7) end
  local shift = tt * 40
  for by = 0, H - 1, CS do                -- one row of the block row in FB ...
    local row = FB + by * W
    for x = 0, W - 1 do
      local bx = x - x % CS
      row[x] = pal[bit.band(floor((sx[bx] + sy[by] + sd[bx + by]) * 42.6 + shift), 255)]
    end
    for y = by + 1, min(by + CS, H) - 1 do  -- ... copied to the rows below it
      ffi.copy(FB + y * W, row, W * 4)
    end
  end
  dirty()                            -- all changed
end
`,
  "grab-mosaic": `-- QUIRK: reading pixels. grab() reads the SLOT (uncached memory, ~50 ms for
-- a full frame), so call it rarely. After it, reading the canvas (FB[] or
-- pget) is fast (normal RAM). Here: every \`every\` seconds take what is in
-- the slot (a movie frame, paint, the capture) and turn it into a mosaic.
-- Run it on a slot that has a picture; a movie there overwrites the mosaic
-- (use a second slot for a movie: not possible from here, it reads its own).
-- params: cell (24), every (3)
local last = -1e9

local function mosaic(CS)
  for by = 0, H - CS, CS do
    for bx = 0, W - CS, CS do
      local c = FB[(by + CS / 2) * W + bx + CS / 2]      -- the centre pixel
      rect(bx, by, CS - 1, CS - 1, c, true)
      rect(bx, by, CS - 1, CS - 1, 0x000000, false)
    end
  end
end

function frame(n, t)
  if t - last >= (param.every or 3) then
    last = t
    grab()                                 -- the slot -> the canvas
    mosaic(math.floor(param.cell or 24))
  end
end
`,
  "ticker": `-- QUIRK: scroll(dx, dy) moves the WHOLE canvas, so the whole frame goes to
-- the slot every frame (~7 ms copy at 720p plus the move). For a text
-- ticker redraw only the strip: clear the strip, draw the text at an
-- offset, dirty marks just that box. params: msg, speed (4), scale (3)
local s = param.msg or "DEBAZAROS  -  text ticker  -  only the strip is redrawn  -  "
local sc = param.scale or 3
local cw, chh = 8 * sc, 16 * sc
local y = H - chh - 20
local off = 0

function frame(n, t)
  rect(0, y, W, chh, rgb(0, 0, 60), true)           -- the strip (also marks it)
  local wtxt = #s * cw
  local x = -off
  while x < W do                                     -- repeat to fill the width
    text(math.floor(x), y, s, 0xFFFF80, sc)
    x = x + wtxt
  end
  off = (off + (param.speed or 4)) % wtxt
end
`,
};

const NOTES = `Shared slot: the script keeps running over a movie or the capture (layer mode, auto); brush, lines,
shapes and text from Paint splat into its slot; clear, fill, image load, fade, a movie start stop it.
Speed: only the changed rectangle goes to the slot (one per frame: present() between far areas); trails() is cheaper
than fade(); FB[] loops are the fastest pixel writes. MIDI: midi.* (the ALSA sequencer, time-stamped, all off at the end).
Full API: the top of sw/dzlua/prelude.lua.`;

let ed, nameIn, slotSel, list, logEl, statEl, pkey, pval, timer = 0, polls = 0;
let hl, gut, band, diagEl, helpEl, lintRes = null, lintTimer = 0, lintGen = 0;
let runEl, runSeen = null, runMap = new Map(), listTimer = 0;	// scripts running on ANY slot (/lua/list)

function listRunning() {
  if (!net.connected()) return;
  runSeen = new Map();
  net.msg("/lua/list");
}

function showRunning() {
  if (!runMap.size) {
    runEl.replaceChildren(h("span.hint", {}, "no script runs on any slot"));
    return;
  }
  runEl.replaceChildren(h("span.hint", {}, "running:"), ...[...runMap].sort((a, b) => a[0] - b[0]).map(([sl, r]) =>
    h("span.lua-run" + (sl === slot() ? ".on" : ""), {},
      h("button.ghost", { title: `show slot ${sl} in this panel (status, log, Stop)`,
        onclick: () => { slotSel.value = sl; store.set("lua.slot", sl); poll(2); showRunning(); } },
        `slot ${sl}: ${r.name} · ${r.fps.toFixed(0)} fps`),
      h("button.danger", { title: `/lua/${sl}/stop`, onclick: () => { net.msg(`/lua/${sl}/stop`); setTimeout(listRunning, 700); poll(2); } }, "■"))));
}

// every 3 s while the panel is on screen
function listTick() {
  listTimer = 0;
  if (!runEl.offsetParent) return;
  listRunning();
  listTimer = setTimeout(listTick, 3000);
}

// ---- highlighting, lint, help (luahl.js) ---------------------------------
function lineH() { return parseFloat(getComputedStyle(ed).lineHeight) || 18.85; }

function paint() {
  const marks = new Map();
  if (lintRes) for (const w of lintRes.warns) marks.set(w.off, w.len);
  hl.innerHTML = highlight(ed.value, marks);
  if (lintRes && lintRes.error) {
    band.style.top = `${10 + (lintRes.error.line - 1) * lineH()}px`;
    band.style.height = `${lineH()}px`;
    hl.prepend(band);
  }
  hl.scrollTop = ed.scrollTop;
  hl.scrollLeft = ed.scrollLeft;
  gutter();
}

// line numbers: a column left of the text, rebuilt when the count changes
let gutN = 0;
function gutter() {
  const n = ed.value.split("\n").length;
  if (n !== gutN) {
    gutN = n;
    gut.textContent = Array.from({ length: n }, (_, i) => i + 1).join("\n") + "\n";
  }
  gut.scrollTop = ed.scrollTop;
}

function diagRow(line, text, cls) {
  const d = h("div", { className: cls, title: `go to line ${line}` }, `line ${line}: ${text}`);
  d.onclick = () => gotoLine(line);
  return d;
}

function showDiag() {
  if (!lintRes || !lintRes.ok) { diagEl.replaceChildren(); return; }
  const rows = [];
  if (lintRes.error) rows.push(diagRow(lintRes.error.line, lintRes.error.msg, "err"));
  for (const w of lintRes.warns) if (w.msg) rows.push(diagRow(w.line, w.msg, "warn-text"));
  diagEl.replaceChildren(...rows.slice(0, 12));
  if (!rows.length) diagEl.replaceChildren(h("div.hint", {}, "syntax ok (LuaJIT)"));
}

async function relint() {
  const gen = ++lintGen;
  const r = await lint(ed.value);
  if (gen !== lintGen) return;			// the text changed meanwhile
  lintRes = r;
  paint();
  showDiag();
}

// the text changed: colour now, lint after a pause
function changed() {
  store.set("lua.draft", ed.value);
  if (lintRes) { lintRes = { ...lintRes, warns: [] }; }	// marks are stale now
  paint();
  clearTimeout(lintTimer);
  lintTimer = setTimeout(relint, 350);
}

function showHelp() {
  const r = helpAt(ed.value, ed.selectionStart);
  if (!r) return;
  helpEl.replaceChildren(h("code", {}, r[1]), " ", r[2]);
}

// API reference: search + click = insert at the cursor
function buildRef() {
  const q = h("input", { type: "search", placeholder: "search the API", style: "width:220px" });
  const box = h("div.luaref");
  const insert = (n, sig) => {
    const name = n;
    const txt = /\(/.test(sig) && !/^function /.test(sig) ? `${name}()` : /^function /.test(sig) ? `${sig}\nend\n` : name;
    ed.focus();
    ed.setRangeText(txt, ed.selectionStart, ed.selectionEnd, "end");
    if (txt.endsWith("()")) ed.selectionStart = ed.selectionEnd = ed.selectionEnd - 1;
    changed();
    showHelp();
  };
  const render = () => {
    const f = q.value.trim().toLowerCase();
    box.replaceChildren(...REF.flatMap(([group, list]) => {
      const rows = list.filter(([n, sig, d]) => !f || n.toLowerCase().includes(f) || d.toLowerCase().includes(f) || sig.toLowerCase().includes(f));
      if (!rows.length) return [];
      return [h("div.luaref-g", {}, group), ...rows.map(([n, sig, d]) =>
        h("div.luaref-r", { title: "click: insert at the cursor", onclick: () => insert(n, sig) },
          h("code", {}, sig), h("span", {}, d)))];
    }));
  };
  q.oninput = render;
  render();
  return h("details", {}, h("summary", {}, "API reference"),
    h("div.row", {}, q, h("span.hint", {}, "click an entry: insert it at the cursor · the line under the editor explains the word at the cursor")),
    box, h("pre.hint", { style: "white-space:pre-wrap" }, NOTES));
}

const slot = () => Number(slotSel.value);
const name = () => nameIn.value.trim().replace(/\.lua$/, "");
const url = (n) => `${net.httpBase()}/media/scripts/${encodeURIComponent(n)}.lua`;

async function refreshList() {
  const r = await fetch(`${net.httpBase()}/media`, { cache: "no-store" }).catch(() => null);
  if (!r || !r.ok) return;
  const j = await r.json();
  list.replaceChildren(...(j.scripts || []).map((f) => h("option", { value: f.name.replace(/\.lua$/, "") })));
}

async function save(quiet) {
  const n = name();
  if (!/^[A-Za-z0-9_-][A-Za-z0-9._-]*$/.test(n)) { toast("script name: A-Z a-z 0-9 . _ -", true); return false; }
  const r = await fetch(url(n), { method: "PUT", body: ed.value }).catch(() => null);
  if (!r || !r.ok) { toast(`save failed${r ? ": " + (await r.text()) : ""}`, true); return false; }
  if (!quiet) toast(`saved ${n}.lua`);
  refreshList();
  return true;
}

async function load() {
  const n = name();
  const r = await fetch(url(n), { cache: "no-store" }).catch(() => null);
  if (!r || !r.ok) return toast(`no script ${n}.lua on the unit`, true);
  ed.value = await r.text();
  changed();
}

async function run() {
  await relint();
  if (lintRes && lintRes.error && !confirm(`Syntax error on line ${lintRes.error.line}: ${lintRes.error.msg}\nRun anyway?`)) return;
  if (!(await save(true))) return;
  logEl.textContent = "";
  net.msg(`/lua/${slot()}/layer`, store.get("lua.layer", "auto"));
  net.msg(`/lua/${slot()}/start`, name());
  poll(6);
}

function stop() {
  net.msg(`/lua/${slot()}/stop`);
  poll(2);
}

async function del() {
  const n = name();
  if (!confirm(`Delete ${n}.lua on the unit?`)) return;
  const r = await fetch(url(n), { method: "DELETE" }).catch(() => null);
  toast(r && r.ok ? `deleted ${n}.lua` : "delete failed", !(r && r.ok));
  refreshList();
}

function setParam() {
  const k = pkey.value.trim();
  if (!/^\w{1,31}$/.test(k)) return toast("parameter name: A-Z a-z 0-9 _", true);
  const v = pval.value.trim();
  const args = v === "" ? [] : /^-?\d+$/.test(v) ? [Number(v)] : !isNaN(Number(v)) ? [net.float(Number(v))] : [v];
  net.msg(`/lua/${slot()}/p/${k}`, ...args);
}

// select line n (1-based) in the editor: a click on an error line
function gotoLine(n) {
  const lines = ed.value.split("\n");
  let a = 0;
  for (let i = 0; i < n - 1 && i < lines.length; i++) a += lines[i].length + 1;
  ed.focus();
  ed.setSelectionRange(a, a + (lines[n - 1] || "").length);
  const lh = parseFloat(getComputedStyle(ed).lineHeight) || 18;
  ed.scrollTop = Math.max(0, (n - 5) * lh);
}

function showLog(text) {
  const n = name();
  const re = new RegExp(`${n.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}(?:\\.lua)?:(\\d+):`);
  logEl.replaceChildren(...text.split("\n").map((l) => {
    const m = l.match(re);
    const err = m || /error|traceback/i.test(l);
    const d = h("div", { className: err ? "err" : "" }, l);
    if (m) { d.style.cursor = "pointer"; d.title = `go to line ${m[1]}`; d.onclick = () => gotoLine(Number(m[1])); }
    return d;
  }));
  logEl.scrollTop = logEl.scrollHeight;
}

// poll status + log; `n` more polls after the script stops (its last lines)
function poll(n) {
  polls = Math.max(polls, n || 1);
  if (!timer) tick();
}
function tick() {
  timer = 0;
  // only while the panel is on screen (offsetParent: null when hidden)
  if (polls <= 0 || !logEl.offsetParent || !net.connected()) return;
  polls--;
  net.send(net.bundle(net.message(`/lua/${slot()}/status`), net.message(`/lua/${slot()}/log`, 5000)));
  timer = setTimeout(tick, 1000);
}

export function init(root) {
  ed = h("textarea.code", { spellcheck: false, rows: 24, wrap: "off",
    title: "the script (Ctrl+Enter: save + run, Ctrl+S: save; Tab inserts 2 spaces)",
    oninput: changed,
    onscroll: () => { hl.scrollTop = ed.scrollTop; hl.scrollLeft = ed.scrollLeft; gut.scrollTop = ed.scrollTop; },
    onkeyup: showHelp, onclick: showHelp,
    onkeydown: (e) => {
      if (e.key === "Tab" && !e.ctrlKey && !e.altKey) {
        e.preventDefault();
        ed.setRangeText("  ", ed.selectionStart, ed.selectionEnd, "end");
        changed();
      } else if (e.key === "Enter" && (e.ctrlKey || e.metaKey)) { e.preventDefault(); run(); }
      else if (e.key === "s" && (e.ctrlKey || e.metaKey)) { e.preventDefault(); save(); }
    } });
  ed.value = store.get("lua.draft", EXAMPLES["turtle-flower"]);
  list = h("datalist", { id: "lua-scripts" });
  nameIn = h("input", { type: "text", value: store.get("lua.name", "turtle-flower"), list: "lua-scripts",
    title: "script name on the unit (/media/debaz/scripts/<name>.lua)", style: "width:160px",
    onchange: () => store.set("lua.name", name()) });
  nameIn.setAttribute("list", "lua-scripts");
  slotSel = h("select", { title: "target slot (show it on a display: Displays tab)",
    onchange: () => { store.set("lua.slot", slot()); poll(1); } },
    ...Array.from({ length: 11 }, (_, i) => h("option", { value: i }, `slot ${i}`)));
  slotSel.value = store.get("lua.slot", 5);
  const ex = h("select", { title: "load an example into the editor",
    onchange: () => {
      if (!ex.value) return;
      if (ed.value.trim() && ed.value !== store.get("lua.saved", "") && !confirm("Replace the editor text?")) { ex.value = ""; return; }
      ed.value = EXAMPLES[ex.value];
      nameIn.value = ex.value;
      changed();
      store.set("lua.name", ex.value);
      ex.value = "";
    } }, h("option", { value: "" }, "examples…"), ...Object.keys(EXAMPLES).map((k) => h("option", { value: k }, k)));
  pkey = h("input", { type: "text", placeholder: "key", style: "width:90px", title: "parameter: param.key in the script" });
  pval = h("input", { type: "text", placeholder: "value", style: "width:90px", title: "int, float (with a point) or text; empty = forget",
    onkeydown: (e) => e.key === "Enter" && setParam() });
  statEl = h("span.hint", {}, "");
  const layerSel = h("select", { title: "layer mode for the next Run: auto = on when a movie or the capture writes the slot (/lua/<slot>/layer)",
    onchange: () => { store.set("lua.layer", layerSel.value); net.msg(`/lua/${slot()}/layer`, layerSel.value); } },
    ...[["auto", "layer: auto"], ["1", "layer: on"], ["0", "layer: off"]].map(([v, t]) => h("option", { value: v }, t)));
  layerSel.value = store.get("lua.layer", "auto");
  logEl = h("div.log.lualog", { role: "log" });
  runEl = h("div.row.lua-running", {}, h("span.hint", {}, "…"));
  hl = h("pre.luahl", { "aria-hidden": "true" });
  gut = h("pre.luagut", { "aria-hidden": "true" });
  band = h("div.luaerr");
  diagEl = h("div.luadiag");
  helpEl = h("div.hint.luahelp", {}, "the help for the word at the cursor shows here");
  // the textarea keeps the size (resizable); the pre follows it
  new ResizeObserver(() => { hl.style.height = gut.style.height = `${ed.offsetHeight}px`; }).observe(ed);

  root.append(
    h("div.row", {}, nameIn, list,
      h("button", { title: "load the script from the unit", onclick: load }, "Load"),
      h("button", { title: "save on the unit (Ctrl+S)", onclick: () => save() }, "Save"),
      h("button.danger", { title: "delete the script on the unit", onclick: del }, "Delete"),
      ex),
    h("div.row", {}, slotSel,
      h("button.primary", { title: "save, then (re)start it on the slot (Ctrl+Enter)", onclick: run }, "▶ Run"),
      h("button", { title: "stop it (the picture stays)", onclick: stop }, "■ Stop"),
      layerSel,
      h("label", {}, "param"), pkey, pval,
      h("button", { title: "send /lua/<slot>/p/<key> value (also an LFO target)", onclick: setParam }, "Set"),
      statEl),
    runEl,
    h("div.luaed", {}, hl, gut, ed),
    helpEl,
    diagEl,
    logEl,
    buildRef());
  changed();

  net.on("/lua", (m) => {
    if (m.path === "/lua/list") {			// the end of a list: replace the running set
      if (runSeen) { runMap = runSeen; runSeen = null; showRunning(); }
      return;
    }
    const st = m.path.match(/^\/lua\/(\d+)\/status$/);
    if (st) {					// any slot: keep the running set current
      const sl = Number(st[1]);
      if (m.args[0]) {
        const r = { name: m.args[1], fps: m.args[3] || 0 };
        runMap.set(sl, r);
        if (runSeen) runSeen.set(sl, r);
      } else runMap.delete(sl);
      if (!runSeen) showRunning();
    }
    const mm = m.path.match(/^\/lua\/(\d+)\/(status|log)$/);
    if (!mm || Number(mm[1]) !== slot()) return;
    if (mm[2] === "log") return showLog(m.args[0] || "");
    const [running, nm, exit, fps, ms, frames] = m.args;
    statEl.textContent = running
      ? `${nm}: running · ${fps.toFixed(1)} fps · ${ms.toFixed(1)} ms/frame · ${frames} frames`
      : nm ? `${nm}: ${exit === 0 ? "ended" : exit < 0 ? "stopped" : exit > 128 ? `stopped (signal ${exit - 128})` : `error (exit ${exit})`}` : "no script";
    statEl.className = running ? "hint" : exit > 0 && exit < 128 ? "warn-text" : "hint";
    if (running) polls = Math.max(polls, 2);
  });
  net.onConnect(() => { refreshList(); poll(1); listRunning(); });
}

export function show() {
  refreshList();
  poll(1);
  if (!listTimer) listTick();
}

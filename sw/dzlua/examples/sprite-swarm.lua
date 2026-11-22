-- TEMPLATE / STRESS TEST: every sprite loaded on the unit (/sprite/<id> for
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

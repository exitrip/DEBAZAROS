-- TEMPLATE: a debazd sprite bounces across display 0, then across display 1,
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

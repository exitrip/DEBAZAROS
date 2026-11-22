-- QUIRK: writing pixels. FB[y * W + x] = c in a plain loop is the fastest
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

-- QUIRK: reading pixels. grab() reads the SLOT (uncached memory, ~50 ms for
-- a full frame), so call it rarely. After it, reading the canvas (FB[] or
-- pget) is fast (normal RAM). Here: every `every` seconds take what is in
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

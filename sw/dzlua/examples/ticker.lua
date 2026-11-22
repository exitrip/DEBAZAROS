-- QUIRK: scroll(dx, dy) moves the WHOLE canvas, so the whole frame goes to
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

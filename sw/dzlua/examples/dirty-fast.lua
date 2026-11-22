-- QUIRK: only the changed area goes to the slot, so small changes are fast.
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

-- a branching tree (recursion + push/pop), it sways
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

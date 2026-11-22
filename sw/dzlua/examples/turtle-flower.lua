-- turtle curve on loop: a spiral that turns, the old frames fade
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

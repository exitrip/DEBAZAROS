-- a damped pendulum curve drawn a little more each frame, then again
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

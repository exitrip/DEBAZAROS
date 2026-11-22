-- Conway's life, written straight into FB (the canvas as uint32_t[W*H])
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

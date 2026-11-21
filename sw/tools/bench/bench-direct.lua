-- bench-direct: debazd paint ops on a slot nobody else writes (2026-11-20,
-- dzmem part 2: paint buffer = the slot). Slot 9, grab source slot 6.
local function fence() for _ = 1, 25 do if osc_get("/sprite/0") then return end end end
local function tm(name, n, fn)
  fence()
  local t0 = time()
  for i = 1, n do fn(i) end
  fence()
  local ms = (time() - t0) * 1000 / n
  print(string.format("%-34s %8.2f ms", name, ms))
end
local function mem(tag)
  local r = osc_get("/surface/mem") or {}
  print(string.format("%-34s %d buffers, %d kB, %d kB free", tag, r[1] or -1, r[2] or -1, r[3] or -1))
end
osc("/movie/6/stop") osc("/movie/9/stop")
mem("RAM at start")
tm("first draw on 9 (rect)", 1, function() osc("/draw/9/rect", 255, 0, 0, 10, 10, 50, 50) end)
tm("first draw on 6 (rect)", 1, function() osc("/draw/6/rect", 255, 0, 0, 10, 10, 50, 50) end)
osc("/draw/6/clear", 30, 60, 90)
tm("clear full", 5, function(i) osc("/draw/9/clear", i * 20, 10, 10) end)
tm("fade 0.1 full", 10, function() osc("/draw/9/fade", 0.1) end)
tm("rect 200x150", 20, function(i) osc("/draw/9/rect", 0, 255, 0, 100 + i * 30, 500, 200, 150) end)
tm("brush r20", 20, function(i) osc("/draw/9/brush", 255, 0, 0, 100 + i * 20, 300, 20, 0.5) end)
tm("stroke 8 pts r8", 10, function(i) osc("/draw/9/stroke", 255, 0, 255, 8, 0.5, 100, 100, 300, 200, 500, 150, 700, 300, 900, 200, 1100, 350, 1200, 100, 1250, 400) end)
tm("text x4", 10, function(i) osc("/draw/9/text", 255, 255, 0, 100, 700, "DIRECT " .. i, 4) end)
tm("rotozoom on itself", 5, function() osc("/draw/9/rotozoom", 3, 1.01) end)
tm("scroll 4 0", 5, function() osc("/draw/9/scroll", 4, 0) end)
tm("grab slot 6 into 9", 5, function() osc("/surface/9/grab", 6) end)
tm("grab own slot 9", 5, function() osc("/surface/9/grab") end)
tm("img/file flyer1204-nameday.png", 3, function(i) osc("/img/9/file", i % 2 == 1 and "flyer1204-nameday.png" or "flyer-addy.png") end)
tm("save png", 2, function(i) osc("/surface/9/save", "bench-direct-" .. i .. ".png") end)
tm("save jpg", 2, function(i) osc("/surface/9/save", "bench-direct-" .. i .. ".jpg") end)
mem("RAM at end")

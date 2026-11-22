-- TEMPLATE: an oscilloscope of the audio (debazd's analysis, `audio`).
-- Source: /audio/react/source auto (a movie that plays audio, else the
-- HDMI_2 input), capture, movie. params:
--   mode  "wave" (default) | "xy" (left = x, right = y) | "spec" (spectrum)
--   gain  (4: laptop / movie audio is often at 0.1-0.3 of full scale)
--   span  samples across the screen in wave mode (1024 = 21 ms)
--   glow  phosphor trails 0..1 (0.3)
-- The wave is triggered: it starts at a rising zero crossing of the mix,
-- so a steady tone stands still.
local floor, log10, max, min = math.floor, math.log10, math.max, math.min
local CL, CR, CM = rgb(80, 255, 120), rgb(255, 120, 60), rgb(120, 180, 255)

local function trigger(M, n, span)          -- index of a rising zero crossing
  for i = n - span - 1, max(1, n - span - 1024), -1 do
    if M[i - 1] < 0 and M[i] >= 0 then return i end
  end
  return n - span
end

local function wave(g)
  local n = audio.n
  local span = min(floor(param.span or 1024), n - 2)
  local i0 = trigger(audio.M, n, span)
  local L, R = audio.L, audio.R
  local h4 = H / 4
  local px, pl, pr
  for k = 0, span - 1, 2 do                 -- every 2nd sample: enough at 1024
    local x = k * W / span
    local yl = H * 0.3 - L[i0 + k] * g * h4
    local yr = H * 0.7 - R[i0 + k] * g * h4
    if px then line(px, pl, x, yl, CL, 2) line(px, pr, x, yr, CR, 2) end
    px, pl, pr = x, yl, yr
  end
end

local function xy(g)
  local n, L, R = audio.n, audio.L, audio.R
  local s = H * 0.45 * g
  local cx, cy = W / 2, H / 2
  blend("add") alpha(0.5)
  local px, py
  for i = n - 1024, n - 1 do                -- the newest 1024 samples
    local x, y = cx + L[i] * s, cy - R[i] * s
    if px then line(px, py, x, y, CM, 1) end
    px, py = x, y
  end
  blend("normal") alpha(1)
end

local function spec(g)
  local nb, S = audio.nbins, audio.spec
  local cols = 128
  local f0, f1 = log10(30), log10(20000)
  local bw = W / cols
  for c = 0, cols - 1 do                    -- log frequency axis, dB height
    local k0 = audio.bin(10 ^ (f0 + (f1 - f0) * c / cols))
    local k1 = max(k0, audio.bin(10 ^ (f0 + (f1 - f0) * (c + 1) / cols)) - 1)
    local a = 0
    for k = k0, min(k1, nb - 1) do a = max(a, S[k]) end
    local db = 20 * log10(a * g + 1e-6)     -- 0 dB = full scale
    local h = max(0, (db + 60) / 60) * H * 0.9
    rect(c * bw, H - h, bw - 1, h, hsv(c / cols * 0.8, 0.8, 1), true)
  end
end

function frame(n, t)
  trails(param.glow or 0.3)
  local g = param.gain or 4
  if not audio.running or audio.n < 1100 then
    line(0, H / 2, W, H / 2, gray(60))
    text(20, 20, "no audio (" .. audio.source .. ")", 0xFFFFFF, 2)
    return
  end
  local m = param.mode or "wave"
  if m == "xy" then xy(g) elseif m == "spec" then spec(g) else wave(g) end
  text(20, 20, string.format("%s  level %.2f", audio.source, audio.level), gray(160), 2)
end

-- TEMPLATE: react to sound with the features of `audio` (debazd's
-- analysis, updated each frame; the first use turns it on):
--   audio.level .peak .bass .low .mid .high .air .flux .beat (0|1),
--   audio.band[0..15], audio.running, audio.source
-- Source: /audio/react/source auto | movie | capture. Laptop and movie
-- audio is often at 0.1-0.3 of full scale: param gain (4).
-- (To move debazd things - hue, DDS, gains - without a script, use an LFO
-- with shape audio: /lfo/0/audio bass, /lfo/0/target "/fx/hue/deg $f0".)
trails(0.12)
blend("add")
local env = 0                                 -- a decaying flash on each beat

function frame(n, t)
  local g = param.gain or 4
  local bass, high = math.min(1, audio.bass * g), math.min(1, audio.high * g)
  if audio.beat > 0 then env = 1 end
  env = env * 0.85
  circle(W / 2, H / 2, 40 + bass * H * 0.4, hsv(0.02, 0.9, 0.5), false, 4 + env * 20)
  for i = 1, math.floor(high * 60) do         -- sparks: more on the highs
    local a, r = math.random() * 6.283, H * (0.1 + math.random() * 0.4)
    pset(W / 2 + math.cos(a) * r, H / 2 + math.sin(a) * r, hsv(0.55, 0.3, 1))
  end
  local bw = W / 16                           -- the 16 bands along the bottom
  for b = 0, 15 do
    local h = math.min(1, audio.band[b] * g) * H * 0.25
    rect(b * bw + 2, H - h, bw - 4, h, hsv(b / 16, 0.7, 0.4), true)
  end
end

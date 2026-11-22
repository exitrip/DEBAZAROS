-- TEMPLATE: MIDI out on time (midi.*: the ALSA sequencer). Start the synth
-- first (sudo dzsynth.sh start). Every step is scheduled AHEAD seconds before
-- it sounds, with its exact time: the tempo does not follow the frame rate.
-- An arpeggio, a bass line and drums; the notes are drawn when they are sent.
-- Stop = all notes off (the script's end, an error or /lua/<s>/stop do it).
-- params: bpm (110), prog (lead GM program 0-127, default 81 = saw lead),
--   bass (33 = finger bass), voices (1-4 lead notes per step), drums (1),
--   vel (90), swing (0..0.5: every 2nd sixteenth later), ahead (0.2 s)
local CHORDS = { { 57, 60, 64, 67 }, { 52, 57, 60, 64 }, { 47, 52, 55, 59 }, { 54, 59, 62, 65 } }  -- Am7 Fmaj7 Cmaj7 G7
midi.program(0, param.prog or 81)    -- lead on channel 0
midi.program(1, param.bass or 33)    -- bass on channel 1
trails(0.08)

local function dot(ch, n, v)
  circle((n - 24) / 72 * W, H - (v / 127) * H * 0.8 - 40, 6 + ch * 4, hsv(ch / 10 + n / 120, 0.8, 1), true)
end
local function note(ch, n, v, len, at)
  midi.note(ch, n, v, len, at)
  dot(ch, n, v)
end

local step, nextt = 0, time() + 0.1
function onparam(k, v)
  if k == "prog" then midi.program(0, v) elseif k == "bass" then midi.program(1, v) end
end

function frame(n, t)
  local spb = 60 / (param.bpm or 110) / 4        -- one sixteenth
  local v = param.vel or 90
  while nextt < t + (param.ahead or 0.2) do      -- everything due in the next AHEAD s
    local at = nextt + ((step % 2 == 1) and spb * (param.swing or 0) or 0)
    local ch = CHORDS[math.floor(step / 16) % #CHORDS + 1]
    for k = 1, math.max(1, math.min(4, param.voices or 1)) do
      note(0, ch[(step + k - 1) % 4 + 1] + 12 * (k > 2 and 1 or 0) + ((step % 8 >= 4) and 12 or 0), v, spb * 0.9, at)
    end
    if step % 4 == 0 then note(1, ch[1] - 24, v + 10, spb * 3.5, at) end
    if (param.drums or 1) ~= 0 then
      if step % 5 == 0 then note(9, 36, 110, spb, at) end           -- kick
      if step % 7 == 4 then note(9, 38, 100, spb, at) end           -- snare
      note(9, 42, step % 2 == 0 and 70 or 40, spb * 0.5, at)         -- hat
    end
    step = step + 1
    nextt = nextt + spb
  end
end

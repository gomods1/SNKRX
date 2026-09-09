-- Procedural, stereo-panned audio cues.
--
-- Speech tells a blind player what is happening; these tones tell them *where*
-- it is happening, continuously, without ever interrupting the screen reader.
-- The panning is baked into the sample data rather than delegated to OpenAL's
-- 3D positioning, so the result is identical on every driver and we control the
-- exact left/right balance.
--
-- Stereo panning alone cannot distinguish "in front of me" from "behind me", so
-- front/back is carried by timbre instead: things ahead of the snake get a
-- bright tone with strong harmonics, things behind get a dull, low sine. That
-- is the convention audio games use and it is learnable within a minute.

local audio = {}
access.audio = audio

local RATE = 44100
local PAN_BUCKETS = 15   -- odd, so there is a true centre bucket

audio.enabled = true
audio.volume = 0.7
audio.ready = false

local cues = {}     -- name -> { sound_data per pan bucket }
local voices = {}   -- name -> bucket -> { sources..., i = round robin }

-- name = { freq, dur, harmonics, decay, noise, gain, tremolo }
local CUE_DEFS = {
  -- An enemy somewhere in front of the snake: bright and short.
  enemy_front = {freq = 440, dur = 0.10, harmonics = {1, 0.50, 0.22}, decay = 26, gain = 0.55},
  -- The same enemy behind the snake: an octave and a half down, pure sine.
  enemy_back  = {freq = 196, dur = 0.15, harmonics = {1, 0.10},       decay = 13, gain = 0.55},
  -- Something is about to touch you.
  enemy_close = {freq = 620, dur = 0.07, harmonics = {1, 0.70, 0.50, 0.35}, decay = 42, gain = 0.75},
  -- Wall dead ahead: a dry wooden knock, nothing like the enemy tones.
  wall        = {freq = 150, dur = 0.06, harmonics = {1, 0.35, 0.20}, decay = 55, noise = 0.30, gain = 0.55},
  -- You are hugging a wall: a quiet low pad on the side the wall is on.
  edge        = {freq = 98,  dur = 0.30, harmonics = {1, 0.15},       decay = 7,  gain = 0.30},
  -- Loose gold.
  gold        = {freq = 1180, dur = 0.13, harmonics = {1, 0, 0.12},   decay = 26, gain = 0.40},
  -- A healing orb.
  orb         = {freq = 780, dur = 0.20, harmonics = {1, 0.30},       decay = 14, gain = 0.40},
  -- A shot is on its way towards you: deliberately buzzy, so it cannot be
  -- confused with an enemy ping even at the edge of hearing.
  incoming    = {freq = 520, dur = 0.09, harmonics = {1, 0.80, 0.60, 0.45, 0.30}, decay = 34, gain = 0.55},
  -- Enemies are about to appear at this spot.
  spawn       = {freq = 330, dur = 0.22, harmonics = {1, 0.60, 0.30}, decay = 9,  gain = 0.60, tremolo = 22},
  -- A hero in the snake just died.
  unit_down   = {freq = 240, dur = 0.28, harmonics = {1, 0.45, 0.2},  decay = 8,  gain = 0.65},
}


local function build_mono(def)
  local n = math.floor(RATE * def.dur)
  local buf = {}
  local two_pi = 2 * math.pi
  local seed = 1
  local peak = 0
  for i = 0, n - 1 do
    local t = i / RATE
    local v = 0
    for h, amp in ipairs(def.harmonics) do
      v = v + amp * math.sin(two_pi * def.freq * h * t)
    end
    if def.noise and def.noise > 0 then
      -- Deterministic LCG: the cue must sound identical every session.
      seed = (seed * 1103515245 + 12345) % 2147483648
      v = v + def.noise * ((seed / 1073741824) - 1)
    end
    local env = math.exp(-def.decay * t)
    -- A few milliseconds of attack keeps the onset from clicking.
    local attack = math.min(1, t / 0.004)
    if def.tremolo then env = env * (0.65 + 0.35 * math.sin(two_pi * def.tremolo * t)) end
    v = v * env * attack
    buf[i + 1] = v
    if math.abs(v) > peak then peak = math.abs(v) end
  end
  -- Normalise, then ramp the tail so the buffer always ends at silence.
  local scale = (peak > 0) and (0.92 / peak) or 0
  local tail = math.min(96, n)
  for i = 1, n do
    local v = buf[i] * scale
    if i > n - tail then v = v * (n - i) / tail end
    buf[i] = v
  end
  return buf, n
end


-- Constant-power pan: keeps perceived loudness steady as a cue sweeps across
-- the stereo field, which matters when the pan is tracking a moving enemy.
local function pan_gains(pan)
  local angle = (pan + 1) * 0.25 * math.pi
  return math.cos(angle), math.sin(angle)
end


local function bake(mono, n, pan)
  local sd = love.sound.newSoundData(n, RATE, 16, 2)
  local gl, gr = pan_gains(pan)

  -- Fast path: write the interleaved int16 frames straight through the FFI.
  local ok = pcall(function()
    local ffi = require('ffi')
    local p = ffi.cast('int16_t*', sd:getPointer())
    for i = 1, n do
      local v = mono[i]
      p[(i - 1) * 2]     = v * gl * 32767
      p[(i - 1) * 2 + 1] = v * gr * 32767
    end
  end)
  if not ok then
    for i = 1, n do
      local v = mono[i]
      sd:setSample(i - 1, 1, v * gl)
      sd:setSample(i - 1, 2, v * gr)
    end
  end
  return sd
end


function audio.init()
  if audio.ready then return end
  local ok = pcall(function()
    for name, def in pairs(CUE_DEFS) do
      local mono, n = build_mono(def)
      local bank = {gain = def.gain or 0.5}
      for b = 1, PAN_BUCKETS do
        local pan = ((b - 1) / (PAN_BUCKETS - 1)) * 2 - 1
        bank[b] = bake(mono, n, pan)
      end
      cues[name] = bank
      voices[name] = {}
    end
  end)
  audio.ready = ok
  if not ok then audio.enabled = false end
  return ok
end


local function bucket_for(pan)
  pan = math.max(-1, math.min(1, pan or 0))
  local b = math.floor(((pan + 1) / 2) * (PAN_BUCKETS - 1) + 0.5) + 1
  return math.max(1, math.min(PAN_BUCKETS, b))
end


-- Sources are pooled per cue and pan bucket: pings overlap constantly and
-- allocating a Source on every ping would churn the audio thread.
local function get_source(name, bucket)
  local per_bucket = voices[name]
  if not per_bucket then return nil end
  local pool = per_bucket[bucket]
  if not pool then
    pool = {i = 0}
    per_bucket[bucket] = pool
  end
  for _, s in ipairs(pool) do
    if not s:isPlaying() then return s end
  end
  if #pool < 4 then
    local s = love.audio.newSource(cues[name][bucket], 'static')
    table.insert(pool, s)
    return s
  end
  pool.i = (pool.i % #pool) + 1
  local s = pool[pool.i]
  s:stop()
  return s
end


-- pan: -1 hard left .. +1 hard right (relative to the direction the snake faces)
-- pitch: playback ratio, used to encode distance
-- volume: 0..1, on top of the cue's own gain and the master cue volume
function audio.play(name, pan, pitch, volume)
  if not audio.enabled or not audio.ready then return end
  local bank = cues[name]
  if not bank then return end
  local ok = pcall(function()
    local s = get_source(name, bucket_for(pan))
    if not s then return end
    s:setPitch(math.max(0.2, math.min(4, pitch or 1)))
    s:setVolume(math.max(0, math.min(1, (volume or 1) * bank.gain * audio.volume)))
    s:play()
  end)
  return ok
end


function audio.stop_all()
  for _, per_bucket in pairs(voices) do
    for _, pool in pairs(per_bucket) do
      for _, s in ipairs(pool) do pcall(function() s:stop() end) end
    end
  end
end

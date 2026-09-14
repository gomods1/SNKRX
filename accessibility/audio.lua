-- Procedural, stereo-panned audio cues.
--
-- Speech tells a blind player what is happening; these tones tell them *where*
-- it is happening, continuously, without ever interrupting the screen reader.
--
-- There are two kinds. A *cue* is a one-shot ping, and its panning is baked
-- into the sample data rather than delegated to OpenAL's 3D positioning, so the
-- result is identical on every driver and we control the exact left/right
-- balance. A *beacon* is a tone that never stops, tracking one thing while the
-- snake moves around it; it is built differently, and why is explained where
-- the beacons are defined further down.
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

-- Two struck instruments, shared between the pings and the beacons so that a
-- thing heard once and the same thing held sound like one object.
--
-- Both are described as `partials` -- a frequency ratio and a level each --
-- rather than as `harmonics`, and the difference is the point. Harmonics are
-- whole multiples of a fundamental, which is what a tone is made of; every
-- ratio below is deliberately not a whole number, which is what a struck piece
-- of metal is made of. An enemy and a coin can sit at the same pitch and still
-- be impossible to confuse, because one of them is a note and the other is not.

-- A small flat piece of metal, hit: the free-free bar ratios, bright and quick.
local COIN      = {{1, 1}, {2.76, 0.62}, {5.40, 0.34}, {8.93, 0.12}}
-- Something good, struck softly: a chime rather than a bell.
--
-- A cast bell is tuned to a minor third, which is why one sounds like a
-- funeral, and it carries a hum an octave below the note you think you are
-- hearing, which is the weight that makes it toll. Both are wrong for the one
-- thing in the arena that is unambiguously good news. This is the opposite
-- build: no hum, nothing minor, and the only strongly coloured partial is a
-- major third five octaves up. Octave and twelfth for body, then a gap where a
-- bell would put its third -- the gap is what makes it hollow and bright
-- instead of solemn.
local CHIME     = {{1, 1}, {2, 0.45}, {3, 0.22}, {5.05, 0.16}, {8.1, 0.07}}
-- The behind-the-snake halves. Same instruments with the bright partials taken
-- off, so front/back stays the brightness difference it is everywhere else and
-- turning towards a coin still hardens it into a coin.
local COIN_DULL = {{1, 1}, {2.76, 0.16}}
local CHIME_DULL = {{1, 1}, {2, 0.20}}


-- The one-shot cues: each one a moment, where the beacons further down are
-- states.
--
-- name = { freq, dur, harmonics | partials, decay, damp, noise, gain, tremolo, sweep }
--
-- `sweep` is the ratio the pitch glides to across the cue, and it does most of
-- the work of keeping these apart from each other and from the held tones. A
-- beacon cannot glide -- it loops -- so anything that glides is an event, and
-- which way it goes says what kind of event: a thing winding itself up rises,
-- a thing arriving falls.
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
  -- Loose gold: a coin, struck once. Also the shop's money sound.
  gold        = {freq = 1176, dur = 0.30, partials = COIN, damp = 0.50, decay = 13,  gain = 0.42},
  -- A healing orb: a soft chime, left to ring out.
  orb         = {freq = 784,  dur = 0.70, partials = CHIME, damp = 0.40, decay = 4.0, gain = 0.42},
  -- A shot is on its way towards you: a buzz that falls as it flies, so it is
  -- heard as something crossing the arena rather than something sitting in it.
  incoming    = {freq = 660, dur = 0.14, harmonics = {1, 0.80, 0.60, 0.45, 0.30},
                 decay = 17, sweep = 0.45, gain = 0.62},
  -- Enemies are about to appear at this spot.
  spawn       = {freq = 330, dur = 0.22, harmonics = {1, 0.60, 0.30}, decay = 9,  gain = 0.60, tremolo = 22},
  -- A hero in the snake just died.
  unit_down   = {freq = 240, dur = 0.28, harmonics = {1, 0.45, 0.2},  decay = 8,  gain = 0.65},
  -- The elite: a slow, heavy pulse that stays audible under the swarm.
  boss        = {freq = 110, dur = 0.30, harmonics = {1, 0.55, 0.30, 0.15}, decay = 7, gain = 0.55},

  -- ---------------------------------------------------------- the specials --
  --
  -- Each of the six special enemies does something the plain seeker does not,
  -- and every one of those somethings used to be either silent or a
  -- pitch-shifted copy of another one, which is how six enemies that behave
  -- nothing alike came to sound alike. They are gestures now, and the gestures
  -- are chosen to separate in the first half of the sound rather than over the
  -- whole of it, because by the time a cue has finished the thing it was
  -- warning about has happened.

  -- A headbutter winding itself up: a fast, nervous buzz climbing most of two
  -- octaves. Its flutter used to sit at 11 a second, a hair off the enemy
  -- beacon's 10, so a charge arrived sounding like an enemy that had come a
  -- little closer. It is now far enough clear of it to be a different animal.
  charge      = {freq = 200, dur = 0.45, harmonics = {1, 0.50, 0.35, 0.20},
                 decay = 2.2, tremolo = 26, sweep = 2.6, gain = 0.80},
  -- ...and letting go: a hard gritty whoosh dropping away. The wind-up rises
  -- and the launch falls, so the two halves of a headbutt cannot be taken for
  -- each other, or for a second headbutter starting on the first one's tail.
  butt        = {freq = 620, dur = 0.24, harmonics = {1, 0.55, 0.30},
                 decay = 8, noise = 0.16, sweep = 0.28, gain = 0.90},
  -- A shooter planting itself to fire. Odd harmonics only, which is a hollow
  -- reed rather than a buzz: a woodwind next to the shot instead of a quieter
  -- version of it. Short, because the shots are a moment behind it.
  aim         = {freq = 740, dur = 0.13, harmonics = {1, 0, 0.55, 0, 0.30},
                 decay = 16, sweep = 1.35, gain = 0.62},
  -- A mine, ticking. Played over and over on an accelerating fuse rather than
  -- once as it is laid, which is the warning a sighted player gets from
  -- watching it blink faster.
  mine        = {freq = 980, dur = 0.09, harmonics = {1, 0.30},       decay = 30, gain = 0.50},
  -- The mine going off: the loudest thing here, because a ring of eight shots
  -- leaves in every direction at once and there is no steering through it.
  burst       = {freq = 165, dur = 0.36, harmonics = {1, 0.60, 0.35, 0.20},
                 decay = 11, noise = 0.55, sweep = 0.55, gain = 0.95},
  -- Something has been thrown at you: a tank shoving its neighbour, or the
  -- forcer elite flinging its escorts. Low and rising -- mass, accelerating.
  shove       = {freq = 130, dur = 0.30, harmonics = {1, 0.45, 0.25},
                 decay = 5, noise = 0.10, sweep = 2.4, gain = 0.75},
  -- Enemies have just been sped up. Bright, rising and completely clean:
  -- nothing new is coming, everything already here got faster.
  boost       = {freq = 400, dur = 0.30, harmonics = {1, 0.30, 0.15},
                 decay = 3.5, tremolo = 30, sweep = 2.8, gain = 0.62},
  -- A spawner or a swarmer elite spilling critters: a high rattle, grainy on
  -- purpose so it is heard as a number of things rather than as one thing.
  swarm       = {freq = 520, dur = 0.30, harmonics = {1, 0.40, 0.25},
                 decay = 6, noise = 0.30, tremolo = 34, gain = 0.70},
}


local function build_mono(def)
  local n = math.floor(RATE * def.dur)
  local buf = {}
  local two_pi = 2 * math.pi
  local seed = 1
  local peak = 0
  -- A glide is the integral of its frequency, not its frequency times the
  -- clock: writing sin(2*pi*f(t)*t) for a moving f gives a sound that starts
  -- right, ends at twice the intended interval and warbles in between. So the
  -- phase is accumulated one sample at a time. With no sweep the accumulation
  -- comes to exactly two_pi*freq*t, which is what the fixed-pitch cues had.
  local phase = 0
  local sweep = def.sweep
  for i = 0, n - 1 do
    local t = i / RATE
    local v = 0
    if def.partials then
      -- A struck thing. Its partials are not whole multiples of a fundamental
      -- and they do not fade together: the high ones go first, which is the
      -- sound of metal being hit rather than a tone being switched on.
      for _, p in ipairs(def.partials) do
        local k = def.decay * (1 + (def.damp or 0) * (p[1] - 1))
        v = v + p[2] * math.exp(-k * t) * math.sin(two_pi * def.freq * p[1] * t)
      end
      v = v * math.min(1, t / 0.004)
    else
      for h, amp in ipairs(def.harmonics) do
        -- A zero is how a harmonic is left out, which is how the odd-harmonic
        -- reed of the shooter's cue is spelled; there is no sine to take.
        if amp ~= 0 then v = v + amp * math.sin(h * phase) end
      end
      phase = phase + two_pi * (sweep and (def.freq * sweep ^ (t / def.dur)) or def.freq) / RATE
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
    end
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


-- ----------------------------------------------------------------- beacons --
--
-- A ping tells you where something was a moment ago; a beacon tells you where
-- it is now. It is a tone that never stops, whose pan follows the target as the
-- snake turns and whose pitch rises as it closes, so steering towards something
-- becomes a matter of turning until the tone sits in the middle of your head
-- and brightens. That is the difference between knowing there is gold somewhere
-- on your left and being able to go and get it.
--
-- Each beacon is two voices, one bright and one dull, crossfaded by how far in
-- front of the snake the target is: dead ahead is all bright, dead behind is
-- all dull, and everything between is a mix. The crossfade is continuous, so
-- turning towards a thing is heard as that thing brightening.
--
-- Beacons are the one place where panning is left to OpenAL rather than baked
-- into the samples. A looping source cannot have its stereo balance rewritten
-- while it plays, and swapping it for a differently-baked copy on every pan
-- step is exactly the click that baking exists to avoid. So beacon sources are
-- mono, marked relative to the listener and given a rolloff of zero: their
-- position carries a direction and nothing else.

local LOOP_DUR = 0.5          -- long enough not to sound like a repeating loop
local LAYERS = {'ahead', 'behind'}
local FADE_IN, FADE_OUT = 0.07, 0.09
local BEACON_TIMEOUT = 0.15   -- stop calling audio.beacon and the tone fades out

-- Sustained  = { freq, harmonics, tremolo, depth, detune, gain }
-- Struck     = { freq, partials, damp, strikes, strike_decay, attack, gain }
--
-- There is one sustained pair per kind of enemy, and telling them apart is the
-- job of `tremolo` and `depth` far more than of `freq`. Pitch is already
-- spoken for: it carries distance, and it carries it across a range wide
-- enough that a far headbutter and a near seeker meet in the middle. Pulse
-- does not smear that way. A rate of 3 and a rate of 22 stay a rate of 3 and a
-- rate of 22 from anywhere in the arena, and `depth` -- how far towards
-- silence each pulse dips -- turns the same rate into a purr or a stutter.
--
-- So the six specials are laid out along that axis and read, slowest first, as
-- a temperament: the tank barely breathing, the spawner turning over, the
-- seeker plain, the headbutter agitated, the speed booster and the exploder
-- fretting, the critters skittering. The frequencies then spread them out for
-- comfort rather than for identity -- a tank sits low because it is heavy, not
-- because low is how you know it is a tank.
local LOOP_DEFS = {
  -- The nearest plain enemy. Kept plain, and kept the quietest of the set,
  -- because it is the tone that is playing almost all of the time -- and
  -- because everything else here has to be audible over it.
  enemy_ahead  = {freq = 440,  harmonics = {1, 0.45, 0.20},       tremolo = 10, gain = 0.22},
  enemy_behind = {freq = 166,  harmonics = {1, 0.12},             tremolo = 10, gain = 0.22},
  -- A shooter. Odd harmonics and a slow, deep pulse: a hollow reed breathing,
  -- which is the same reed its aiming cue is made of.
  shooter_ahead  = {freq = 620, harmonics = {1, 0, 0.50, 0, 0.28}, tremolo = 6, depth = 0.72, gain = 0.26},
  shooter_behind = {freq = 233, harmonics = {1, 0, 0.16},          tremolo = 6, depth = 0.72, gain = 0.26},
  -- A headbutter. Agitated: half again the seeker's rate and pulsing almost to
  -- silence between beats, so it is heard as something twitching rather than
  -- something humming. Its charge then goes faster again.
  headbutter_ahead  = {freq = 494, harmonics = {1, 0.50, 0.35, 0.22}, tremolo = 15, depth = 0.85, gain = 0.32},
  headbutter_behind = {freq = 185, harmonics = {1, 0.16},             tremolo = 15, depth = 0.85, gain = 0.32},
  -- A tank. Low, thick with harmonics and barely pulsing at all: the one enemy
  -- in the game that is a wall rather than a threat, and it sounds like one.
  tank_ahead  = {freq = 233, harmonics = {1, 0.70, 0.50, 0.35, 0.22}, tremolo = 3.5, depth = 0.30, gain = 0.30},
  tank_behind = {freq = 87,  harmonics = {1, 0.35, 0.15},             tremolo = 3.5, depth = 0.30, gain = 0.30},
  -- An exploder. Thin and ticking over fast, which is the fuse it is about to
  -- become: the mine it leaves behind ticks in the same register.
  exploder_ahead  = {freq = 392, harmonics = {1, 0.35, 0.15}, tremolo = 22, depth = 0.75, gain = 0.30},
  exploder_behind = {freq = 147, harmonics = {1, 0.12},       tremolo = 22, depth = 0.75, gain = 0.30},
  -- A speed booster. High and quick, the sound of the thing it does.
  speed_booster_ahead  = {freq = 660, harmonics = {1, 0.40, 0.22}, tremolo = 20, depth = 0.55, gain = 0.28},
  speed_booster_behind = {freq = 247, harmonics = {1, 0.14},       tremolo = 20, depth = 0.55, gain = 0.28},
  -- A spawner. Slow, and doubled a few cents off itself so the two halves beat
  -- against each other: one enemy that is audibly already more than one.
  spawner_ahead  = {freq = 330, harmonics = {1, 0.50, 0.30, 0.18}, tremolo = 5, detune = 1.03, gain = 0.33},
  spawner_behind = {freq = 124, harmonics = {1, 0.18},             tremolo = 5, detune = 1.03, gain = 0.33},
  -- A critter. There are never fewer than five of them and they are the least
  -- dangerous thing in the arena, so this is the thinnest and quietest tone
  -- here -- fast, papery, and unmistakably not a seeker that has closed in.
  critter_ahead  = {freq = 700, harmonics = {1, 0.20}, tremolo = 26, depth = 0.80, gain = 0.20},
  critter_behind = {freq = 262, harmonics = {1, 0.08}, tremolo = 26, depth = 0.80, gain = 0.20},
  -- The elite: slower and heavier, so it stays legible under the enemy tone.
  elite_ahead  = {freq = 220,  harmonics = {1, 0.55, 0.28, 0.12}, tremolo = 4,  gain = 0.32},
  elite_behind = {freq = 110,  harmonics = {1, 0.30, 0.10},       tremolo = 4,  gain = 0.32},
  -- Loose gold: the coin from the gold ping, struck over and over. Four times
  -- a second at arm's length, a little over five when you are nearly on it.
  gold_ahead   = {freq = 1176, partials = COIN,      damp = 0.50, strikes = 2,
                  strike_decay = 5,   attack = 0.003, gain = 0.44},
  gold_behind  = {freq = 588,  partials = COIN_DULL, damp = 0.50, strikes = 2,
                  strike_decay = 5,   attack = 0.003, gain = 0.44},
  -- A healing orb: the chime, struck twice a second and still ringing when the
  -- next one lands, so it reads as a glow that pulses rather than as a thing
  -- being hit. Struck like the coin, so neither can be taken for an enemy; half
  -- the rate and none of the metal, so neither can be taken for the other.
  orb_ahead    = {freq = 784,  partials = CHIME,      damp = 0.40, strikes = 1,
                  strike_decay = 2.4, attack = 0.018, gain = 0.42},
  orb_behind   = {freq = 392,  partials = CHIME_DULL, damp = 0.40, strikes = 1,
                  strike_decay = 2.4, attack = 0.018, gain = 0.42},
}

local loops = {}      -- name -> mono SoundData
local beacons = {}    -- id -> {ahead = voice, behind = voice, age = seconds, ...}
local retiring = {}   -- sources being faded out before they are released


-- A looping source runs off the end of the buffer straight back into the start,
-- so anything that does not complete a whole number of cycles inside the buffer
-- clicks once per loop. Rounding the frequency to the nearest one that fits is
-- inaudible; the click is not.
local function whole_cycles(value, n)
  if not value then return nil end
  return math.max(1, math.floor(value * n / RATE + 0.5)) * RATE / n
end


local function build_sustained(def, n)
  local freq = whole_cycles(def.freq, n)
  local trem = whole_cycles(def.tremolo, n)
  local depth = def.depth or 0.55
  -- A second copy of the whole tone a few cents off the first. The two beat
  -- against each other at the difference between them, which is a roughness
  -- rather than a chord, and it is the one texture here that says "more than
  -- one of these" without saying anything about pitch or rate. Rounded to
  -- whole cycles like everything else, so the beat divides into the buffer
  -- exactly and the loop does not click at the seam.
  local detune = def.detune and whole_cycles(def.freq * def.detune, n) or nil
  local two_pi = 2 * math.pi
  local buf, peak = {}, 0
  for i = 0, n - 1 do
    local t = i / RATE
    local v = 0
    for h, amp in ipairs(def.harmonics) do
      if amp ~= 0 then
        v = v + amp * math.sin(two_pi * freq * h * t)
        if detune then v = v + amp * math.sin(two_pi * detune * h * t) end
      end
    end
    -- The pulse rides along with the pitch, so a closing target is heard both
    -- rising and speeding up -- two readings of the same distance.
    if trem then v = v * ((1 - depth) + depth * 0.5 * (1 - math.cos(two_pi * trem * t))) end
    buf[i + 1] = v
    if math.abs(v) > peak then peak = math.abs(v) end
  end
  return buf, peak
end


-- A struck beacon: the instrument is hit `strikes` times inside the loop and
-- rings out between hits, instead of being held and wobbled.
--
-- This is what separates gold and orbs from the enemy tones, and frequency
-- could never have done it. Distance is already spelled as pitch, so every
-- beacon is smeared across a range wide enough to reach its neighbours' -- a
-- far coin and a near orb genuinely arrive at the same note. A rhythm does not
-- smear. It speeds up as a thing closes, which is the reading we want anyway,
-- but a repeating ping never becomes a held tone however far off it is.
local function build_struck(def, n)
  local strikes = def.strikes
  local period = math.max(1, math.floor(n / strikes + 0.5))  -- samples per hit
  local attack = def.attack or 0.004
  local damp = def.damp or 0
  local base = def.strike_decay or 6
  local two_pi = 2 * math.pi

  local voices = {}
  for i, p in ipairs(def.partials) do
    local k = base * (1 + damp * (p[1] - 1))
    local rest = math.exp(-k)
    voices[i] = {
      -- Rounded to whole cycles per *strike*, not per buffer, so every hit
      -- starts at the same phase as the first one and its onset is silence
      -- rather than a click.
      freq = whole_cycles(def.freq * p[1], period),
      amp = p[2],
      k = k,
      rest = rest,
      span = 1 - rest,
    }
  end

  local buf, peak = {}, 0
  for i = 0, n - 1 do
    local j = i % period
    local u = j / period
    local t = j / RATE
    local v = 0
    for _, p in ipairs(voices) do
      -- Shifted and rescaled so the ring reaches exactly zero as the next hit
      -- lands. An envelope still sounding at the seam clicks once per loop,
      -- for ever, which is the one thing a beacon must never do.
      local env = (math.exp(-p.k * u) - p.rest) / p.span
      v = v + p.amp * env * math.sin(two_pi * p.freq * t)
    end
    v = v * math.min(1, t / attack)
    buf[i + 1] = v
    if math.abs(v) > peak then peak = math.abs(v) end
  end
  return buf, peak
end


local function build_loop(def)
  local n = math.floor(RATE * LOOP_DUR + 0.5)
  local buf, peak
  if def.partials and def.strikes then
    buf, peak = build_struck(def, n)
  else
    buf, peak = build_sustained(def, n)
  end

  local scale = (peak > 0) and (0.9 / peak) or 0
  local sd = love.sound.newSoundData(n, RATE, 16, 1)
  local ok = pcall(function()
    local ffi = require('ffi')
    local p = ffi.cast('int16_t*', sd:getPointer())
    for i = 1, n do p[i - 1] = buf[i] * scale * 32767 end
  end)
  if not ok then
    for i = 1, n do sd:setSample(i - 1, buf[i] * scale) end
  end
  return sd
end


function audio.init()
  if audio.ready then return end
  local ok, err = pcall(function()
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
    for name, def in pairs(LOOP_DEFS) do
      loops[name] = build_loop(def)
    end
  end)
  audio.ready = ok
  -- One bad number in a cue definition used to turn the whole layer off without
  -- a word, which for a blind player is the game going quiet for no reason they
  -- can find. Say what broke.
  if not ok then
    audio.enabled = false
    print('[accessibility] cue synthesis failed, all cues are off: ' .. tostring(err))
  end
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


-- --------------------------------------------------------- beacon runtime --

-- Said once, if it ever happens: without positional audio every beacon still
-- plays but none of them are panned, which is worth a line in the console
-- rather than a player quietly wondering why nothing has a direction.
local positional_warned = false

local function new_voice(name)
  local data = loops[name]
  if not data then return nil end
  local voice = {name = name, gain = (LOOP_DEFS[name] and LOOP_DEFS[name].gain) or 0.3, amp = 0}
  local ok = pcall(function()
    local s = love.audio.newSource(data, 'static')
    s:setLooping(true)
    s:setVolume(0)
    -- A direction, not a distance: the source sits on the unit circle around
    -- the listener and its rolloff is switched off, so moving it can pan the
    -- tone but can never change how loud it is.
    local placed = pcall(function()
      s:setRelative(true)
      s:setAttenuationDistances(1, 1)
      s:setRolloff(0)
      s:setPosition(0, 0, -1)
    end)
    if not placed and not positional_warned then
      positional_warned = true
      print('[accessibility] positional audio unavailable: beacons will play but will not be panned')
    end
    s:play()
    voice.source = s
  end)
  if not ok or not voice.source then return nil end
  return voice
end


-- Beacons are never cut off mid-cycle: a looping tone stopped at an arbitrary
-- point in its waveform is a click, and clicks are what a player learns to
-- flinch at rather than listen through.
local function retire(voice)
  if not voice or not voice.source then return end
  local from = 0
  pcall(function() from = voice.source:getVolume() end)
  table.insert(retiring, {source = voice.source, from = from, t = 0})
end


local function release(source)
  pcall(function() source:stop() end)
  pcall(function() source:release() end)
end


-- id       which beacon this is; one target per id
-- cues     {ahead = loop name, behind = loop name}
-- bearing  radians relative to the way the snake faces, 0 dead ahead
-- pitch    playback ratio, used to encode distance
-- volume   0..1, on top of the cue's own gain and the master cue volume
--
-- Call it every frame for as long as the target is worth tracking. Stop calling
-- it and the tone fades itself out, which means callers never have to remember
-- to switch a beacon off when its target dies, is picked up or goes out of view.
function audio.beacon(id, cues, bearing, pitch, volume)
  if not audio.enabled or not audio.ready then return end
  local b = beacons[id]
  if not b then b = {} beacons[id] = b end
  b.age = 0

  for _, layer in ipairs(LAYERS) do
    local want = cues[layer]
    local voice = b[layer]
    if voice and voice.name ~= want then
      retire(voice)
      voice = nil
    end
    if not voice and want then voice = new_voice(want) end
    b[layer] = voice
  end

  -- Half in front and half behind sounds the same as fully in front only if the
  -- two voices add up in power rather than in amplitude, hence the square roots.
  local front = (math.cos(bearing) + 1) * 0.5
  b.x, b.z = math.sin(bearing), -math.cos(bearing)
  b.pitch = math.max(0.2, math.min(4, pitch or 1))
  local v = math.max(0, math.min(1, volume or 1))
  b.ahead_volume = v * math.sqrt(front)
  b.behind_volume = v * math.sqrt(1 - front)
end


function audio.stop_beacon(id)
  local b = beacons[id]
  if not b then return end
  for _, layer in ipairs(LAYERS) do retire(b[layer]) end
  beacons[id] = nil
end


function audio.stop_beacons()
  for id in pairs(beacons) do audio.stop_beacon(id) end
end


function audio.beacon_active(id)
  return beacons[id] ~= nil
end


local function apply(voice, b, volume, dt)
  if not voice or not voice.source then return end
  -- Fading in stops a beacon that has just acquired a target from arriving as
  -- a bang, which matters most in a fight, when they acquire constantly.
  voice.amp = math.min(1, voice.amp + dt / FADE_IN)
  pcall(function()
    voice.source:setPosition(b.x, 0, b.z)
    voice.source:setPitch(b.pitch)
    voice.source:setVolume(volume * voice.amp * voice.gain * audio.volume)
  end)
end


-- Drives every beacon and every fade. Called once a frame from access.update,
-- after the arena has had its say about where things are.
function audio.update(dt)
  dt = dt or 0
  for i = #retiring, 1, -1 do
    local r = retiring[i]
    r.t = r.t + dt
    if r.t >= FADE_OUT then
      release(r.source)
      table.remove(retiring, i)
    else
      pcall(function() r.source:setVolume(r.from * (1 - r.t / FADE_OUT)) end)
    end
  end

  for id, b in pairs(beacons) do
    b.age = (b.age or 0) + dt
    if b.age > BEACON_TIMEOUT or not audio.enabled then
      audio.stop_beacon(id)
    else
      apply(b.ahead, b, b.ahead_volume or 0, dt)
      apply(b.behind, b, b.behind_volume or 0, dt)
    end
  end
end


function audio.stop_all()
  for _, per_bucket in pairs(voices) do
    for _, pool in pairs(per_bucket) do
      for _, s in ipairs(pool) do pcall(function() s:stop() end) end
    end
  end
  for id, b in pairs(beacons) do
    for _, layer in ipairs(LAYERS) do
      if b[layer] and b[layer].source then release(b[layer].source) end
    end
    beacons[id] = nil
  end
  for i = #retiring, 1, -1 do
    release(retiring[i].source)
    table.remove(retiring, i)
  end
end

-- Learn sounds: a place to hear every cue on its own, with nothing trying to
-- kill you.
--
-- The arena teaches its own vocabulary badly. A sound arrives once, in the
-- middle of four other sounds, while the snake is about to hit a wall, and by
-- the time the player has worked out what it was it has been replaced by the
-- next one. Everything here is the same sound in the same shape it takes in the
-- arena, held still: browse the list, press enter, hear it, press enter again.
-- The main menu behind it is frozen while it is open, so nothing else is making
-- noise.
--
-- The demos deliberately move. A cue heard once at dead centre teaches almost
-- nothing about what it will sound like sweeping past on the left, so the
-- beacons pass the listener from behind on one side to behind on the other,
-- closing as they come, which is the shape of a real approach.

local lab = {}
access.sound_lab = lab

-- Left edges, not centres: a column of names of wildly different lengths reads
-- as a list when it is flush left and as a scatter when it is centred. The rows
-- are shared out between the columns rather than fixed, so adding a sound to
-- the list below is the whole of the work.
-- Three columns since the enemies stopped sharing one tone between them: two
-- would now want ten rows, and ten rows reach the back button.
local COLUMN_LEFT = {14, 172, 330}
local ROW_TOP, ROW_STEP = 64, 19
local BACK_Y = 200
local DETAIL_Y = 222


local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function remap(v, a, b, x, y)
  if b == a then return x end
  return x + (clamp(v, math.min(a, b), math.max(a, b)) - a) * (y - x) / (b - a)
end


-- ------------------------------------------------------------------ demos --

-- The four beacons, with the same distance-to-pitch and distance-to-volume
-- mappings the arena uses, so that what is learned here is what will be heard
-- there.
local VOICES = {
  enemy = {cues = {ahead = 'enemy_ahead', behind = 'enemy_behind'},
           range = {16, 260}, pitch = {1.75, 0.70}, volume = {0.90, 0.36}},
  elite = {cues = {ahead = 'elite_ahead', behind = 'elite_behind'},
           range = {30, 280}, pitch = {1.35, 0.75}, volume = {0.95, 0.50}},
  gold  = {cues = {ahead = 'gold_ahead',  behind = 'gold_behind'},
           range = {16, 300}, pitch = {1.30, 0.80}, volume = {0.85, 0.30}},
  orb   = {cues = {ahead = 'orb_ahead',   behind = 'orb_behind'},
           range = {16, 300}, pitch = {1.25, 0.80}, volume = {0.95, 0.35}},
}


-- The enemy tone comes in one flavour per kind of enemy, and the only way to
-- learn eight timbres is to hear them against each other rather than one at a
-- time with a fight in between. So they are played back to back, in the order
-- the game introduces them, each held dead ahead at the same distance so that
-- the pulse and the colour of the tone are the only things that change.
--
-- Kept in the game's own order rather than sorted, because that is the order
-- the twelve tutorial runs go in and the order they will be met in.
local KINDS = {'enemy', 'shooter', 'headbutter', 'exploder', 'speed_booster', 'tank', 'spawner', 'critter'}
local KIND_HOLD = 1.15   -- seconds each, long enough for two of the slowest pulses

local function kind_voice(kind)
  return {cues = {ahead = kind .. '_ahead', behind = kind .. '_behind'},
          range = VOICES.enemy.range, pitch = VOICES.enemy.pitch, volume = VOICES.enemy.volume}
end

local KIND_VOICES = {}
for _, k in ipairs(KINDS) do KIND_VOICES[k] = kind_voice(k) end


local function aim(voice, bearing, distance)
  access.audio.beacon('demo', voice.cues, bearing,
    remap(distance, voice.range[1], voice.range[2], voice.pitch[1], voice.pitch[2]),
    remap(distance, voice.range[1], voice.range[2], voice.volume[1], voice.volume[2]))
end


-- A pass: in from behind on the left, across the front at its closest, away
-- behind on the right. One press hears the cue from every angle.
local function pass(voice, duration, near, far)
  return function(t)
    local u = clamp(t / duration, 0, 1)
    local bearing = -2.7 + 5.4 * u
    local distance = far + (near - far) * (1 - math.abs(2 * u - 1))
    aim(voice, bearing, distance)
  end
end


local function hold(voice, bearing, distance)
  return function() aim(voice, bearing, distance) end
end


local function ping(at, name, pan, pitch, volume)
  return {at = at, fn = function() access.audio.play(name, pan, pitch, volume or 1) end}
end


-- A run of one cue, evenly spaced, sweeping across the stereo field.
local function sweep(name, count, from, to, gap, pitch, volume)
  local steps = {}
  for i = 1, count do
    local u = (count == 1) and 0.5 or ((i - 1) / (count - 1))
    table.insert(steps, ping((i - 1) * gap, name, from + (to - from) * u, pitch, volume))
  end
  return steps
end


-- The wall knock as it actually arrives: a little faster and a little higher
-- each time, which is the only warning a bounce ever gets.
local function closing_wall()
  local steps, at, gap = {}, 0, 0.5
  for i = 1, 10 do
    local u = (i - 1) / 9
    table.insert(steps, ping(at, 'wall', 0, remap(u, 0, 1, 0.85, 1.7), remap(u, 0, 1, 0.35, 1)))
    at = at + gap
    gap = math.max(0.1, gap * 0.78)
  end
  return steps, at + 0.3
end


local wall_steps, wall_duration = closing_wall()


-- The whole fuse, the way it actually burns: ticks getting faster and higher
-- for two and a half seconds, the ring going off, and then the shots crossing
-- from every side. The tick used to be played once and the burst not at all,
-- which taught the beginning of the sentence and not the end of it.
local function mine_demo()
  local fuse = 2.45
  local steps, at = {}, 0
  while at < fuse do
    local u = at / fuse
    table.insert(steps, ping(at, 'mine', -0.35, remap(u, 0, 1, 0.85, 1.7), 0.9))
    at = at + remap(u, 0, 1, 0.40, 0.10)
  end
  table.insert(steps, ping(fuse, 'burst', -0.35, 1, 1))
  for i, pan in ipairs({-0.9, -0.45, 0, 0.45, 0.9}) do
    table.insert(steps, ping(fuse + 0.2 + i * 0.05, 'incoming', pan, 1.15, 0.7))
  end
  return steps, fuse + 0.9
end


local mine_steps, mine_duration = mine_demo()


-- One shot crossing the arena at a shooter's bolt speed, buzzing faster and
-- higher as it comes, which is what the arena now does with it.
local function closing_shot()
  local steps, at, d = {}, 0, 205
  while d > 22 do
    table.insert(steps, ping(at, 'incoming', remap(d, 22, 205, -0.35, -0.95),
      remap(d, 22, 205, 1.5, 0.85), remap(d, 22, 205, 1, 0.55)))
    local gap = remap(d, 22, 205, 0.09, 0.30)
    at = at + gap
    d = d - 170 * gap
  end
  return steps, at + 0.4
end


local shot_steps, shot_duration = closing_shot()


-- Every enemy tone in turn, held at the same place so that nothing but the
-- tone itself changes.
local function kinds_roll()
  return function(t)
    local i = clamp(math.floor(t / KIND_HOLD) + 1, 1, #KINDS)
    aim(KIND_VOICES[KINDS[i]], 0, 120)
  end
end


-- ----------------------------------------------------------------- sounds --

-- Each sound's name and description live in the locale files under
-- a11y.sound.<key>.name and a11y.sound.<key>.detail; what stays here is the
-- demo, which is the half of an entry that is not words.
local SOUNDS = {
  {
    key = 'stereo',
    demo = {duration = 2, steps = sweep('wall', 5, -1, 1, 0.35, 1.1, 1)},
  },
  {
    key = 'enemy',
    demo = {duration = 5.4, track = pass(VOICES.enemy, 5.4, 30, 240)},
  },
  {
    key = 'enemy_close',
    demo = {duration = 1.7, track = hold(VOICES.enemy, 0.5, 20),
      steps = sweep('enemy_close', 9, 0.45, 0.45, 0.14, 1, 0.9)},
  },
  {
    -- The seven enemy tones back to back. The most useful ten seconds on this
    -- screen, and the reason the rest of it is worth learning: everything
    -- below is a moment, and this is the sound that is playing underneath all
    -- of them for the whole round.
    key = 'enemy_kinds',
    demo = {duration = #KINDS * KIND_HOLD, track = kinds_roll()},
  },
  {
    key = 'enemy_shot',
    demo = {duration = shot_duration, steps = shot_steps},
  },
  {
    key = 'shooter_aim',
    demo = {duration = 2.1, steps = {
      ping(0, 'aim', 0.5, 1, 1),
      ping(1.0, 'incoming', 0.4, 1, 0.8),
      ping(1.15, 'incoming', 0.4, 1.05, 0.8),
      ping(1.3, 'incoming', 0.4, 1.1, 0.8),
    }},
  },
  {
    -- Two seconds apart, as it is in the arena: the gap is the dodge.
    key = 'headbutter',
    demo = {duration = 2.7, steps = {ping(0, 'charge', 0.55, 1, 1), ping(2, 'butt', 0.55, 1, 1)}},
  },
  {
    key = 'mine',
    demo = {duration = mine_duration, steps = mine_steps},
  },
  {
    key = 'flung',
    demo = {duration = 1.5, steps = {ping(0, 'shove', -0.6, 1, 1),
      ping(0.55, 'enemy_close', -0.5, 1, 0.9), ping(0.69, 'enemy_close', -0.45, 1, 0.9)}},
  },
  {
    key = 'boosted',
    demo = {duration = 1.3, steps = {ping(0, 'boost', 0, 1, 1)}},
  },
  {
    -- The burst and then the tone it leaves behind, because a cloud of
    -- critters is the one arrival that hands you a new sound to steer by.
    key = 'critters',
    demo = {duration = 3.6, steps = {ping(0, 'swarm', 0.4, 1, 1)},
      track = pass(KIND_VOICES.critter, 3.6, 30, 200)},
  },
  {
    key = 'arriving',
    demo = {duration = 1.6, steps = {ping(0, 'spawn', 0, 1, 0.9), ping(0.05, 'spawn', -0.65, 0.8, 0.9)}},
  },
  {
    key = 'elite',
    demo = {duration = 5.4, track = pass(VOICES.elite, 5.4, 45, 260)},
  },
  {
    key = 'gold',
    demo = {duration = 4.6, track = pass(VOICES.gold, 4.6, 25, 270)},
  },
  {
    key = 'orb',
    demo = {duration = 4.6, track = pass(VOICES.orb, 4.6, 25, 270)},
  },
  {
    key = 'wall_ahead',
    demo = {duration = wall_duration, steps = wall_steps},
  },
  {
    key = 'wall_beside',
    demo = {duration = 1.8, steps = sweep('edge', 4, -0.9, -0.9, 0.45, 1, 0.8)},
  },
  {
    key = 'hero_lost',
    demo = {duration = 1.2, steps = {ping(0, 'unit_down', 0, 1, 1)}},
  },
}


-- ----------------------------------------------------------------- screen --

lab.open_on = nil     -- the state the lab is open on, if any
local playing = nil   -- the demo currently running
local shown_detail = nil


local function stop_demo()
  playing = nil
  pcall(access.audio.stop_beacon, 'demo')
end


local function play(entry)
  stop_demo()
  if not access.audio.enabled then
    access.say(T('a11y.sound.cues_off'), {interrupt = true, priority = true})
    return
  end
  playing = {t = 0, i = 1, demo = entry.demo}
end


-- Wrapped by hand, because the game's Text draws each line exactly as given and
-- would happily run off both edges of the screen.
local function wrap(text, width)
  local lines, line = {}, ''
  for word in tostring(text):gmatch('%S+') do
    local try = (line == '') and word or (line .. ' ' .. word)
    local ok, w = pcall(function() return pixul_font:get_text_width(try) end)
    if ok and w > width and line ~= '' then
      table.insert(lines, line)
      line = word
    else
      line = try
    end
  end
  if line ~= '' then table.insert(lines, line) end
  return lines
end


-- The description of whatever is focused, on screen as well as spoken: this
-- screen is for anyone still learning the sounds, not only for players who
-- cannot see it.
local function show_detail(st, text)
  if text == shown_detail then return end
  shown_detail = text
  if st.sound_lab_detail then st.sound_lab_detail.dead = true st.sound_lab_detail = nil end
  if not text then return end
  -- Only the first sentence fits on screen; the whole thing is what is read out.
  local first = text:match('^(.-%.)%s') or text
  local lines = {}
  for i, line in ipairs(wrap(first, 440)) do
    if i <= 2 then table.insert(lines, {text = '[bg10]' .. line, font = pixul_font, alignment = 'center'}) end
  end
  if #lines == 0 then return end
  st.sound_lab_detail = Text2{group = st.sound_lab, x = gw/2, y = DETAIL_Y, lines = lines}
end


function lab.open(st)
  if not st or st.in_sound_lab then return end
  st.sound_lab = Group():no_camera()
  st.in_sound_lab = true
  lab.open_on = st
  shown_detail = nil

  Text2{group = st.sound_lab, x = gw/2, y = 22,
    lines = {{text = '[fg]' .. T('ui.menu.learn_sounds'), font = fat_font, alignment = 'center'}}}
  Text2{group = st.sound_lab, x = gw/2, y = 44,
    lines = {{text = '[bg10]' .. T('ui.sound_lab.subtitle'),
      font = pixul_font, alignment = 'center'}}}

  local rows = math.ceil(#SOUNDS / #COLUMN_LEFT)
  for i, entry in ipairs(SOUNDS) do
    local column = math.min(#COLUMN_LEFT, math.ceil(i / rows))
    local row = i - (column - 1) * rows
    local name = T('a11y.sound.' .. entry.key .. '.name')
    local width = pixul_font:get_text_width(name) + 8
    local b = Button{group = st.sound_lab, x = COLUMN_LEFT[column] + width/2, y = ROW_TOP + (row - 1) * ROW_STEP,
      force_update = true, button_text = name, fg_color = 'bg10', bg_color = 'bg',
      action = function() play(entry) end}
    -- Reading order is stated outright: down the first column and then down the
    -- second, rather than zigzagging between them the way screen rows would.
    -- The whole list is one group, so the arrow keys walk it and Tab is left to
    -- reach the one control that is not a sound.
    b.a11y_order = i
    b.a11y_group = 'sounds'
    b.a11y_label = name
    b.a11y_detail = T('a11y.sound.' .. entry.key .. '.detail')
  end

  local back = Button{group = st.sound_lab, x = gw/2, y = BACK_Y, force_update = true,
    button_text = T('ui.tutorial.back'), fg_color = 'bg10', bg_color = 'bg', action = function() lab.close(st) end}
  back.a11y_order = #SOUNDS + 1
  back.a11y_group = 'controls'
  back.a11y_label = T('a11y.tutorial.back_to_menu')

  access.say(T('a11y.sound.list_intro', #SOUNDS), {interrupt = true, priority = true})
end


function lab.close(st)
  st = st or lab.open_on
  if not st or not st.in_sound_lab then return end
  stop_demo()
  st.in_sound_lab = false
  lab.open_on = nil
  shown_detail = nil
  st.sound_lab_detail = nil
  if st.sound_lab then
    for _, o in ipairs(st.sound_lab.objects) do o.dead = true end
    st.sound_lab:update(0)
    st.sound_lab:destroy()
    st.sound_lab = nil
  end
  access.say(T('a11y.screen.main_menu'), {interrupt = true, priority = true})
end


function lab.update(st, dt)
  if not st or not st.in_sound_lab then return end

  if playing then
    local demo = playing.demo
    playing.t = playing.t + dt
    local steps = demo.steps
    while steps and steps[playing.i] and playing.t >= steps[playing.i].at do
      pcall(steps[playing.i].fn)
      playing.i = playing.i + 1
    end
    -- The beacon is re-aimed every frame; letting go of it is what fades it out.
    if demo.track and playing.t <= demo.duration then pcall(demo.track, playing.t) end
    if playing.t > demo.duration then playing = nil end
  end

  local focus = access.nav and access.nav.focus
  show_detail(st, focus and focus.a11y_detail or nil)
end


-- Drawn by the state, over its own darkened screen.
function lab.draw(st)
  if st and st.in_sound_lab and st.sound_lab then st.sound_lab:draw() end
end

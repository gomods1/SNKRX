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
local COLUMN_LEFT = {28, 258}
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
           range = {16, 260}, pitch = {1.75, 0.70}, volume = {1.00, 0.40}},
  elite = {cues = {ahead = 'elite_ahead', behind = 'elite_behind'},
           range = {30, 280}, pitch = {1.35, 0.75}, volume = {0.95, 0.50}},
  gold  = {cues = {ahead = 'gold_ahead',  behind = 'gold_behind'},
           range = {16, 300}, pitch = {1.30, 0.80}, volume = {0.85, 0.30}},
  orb   = {cues = {ahead = 'orb_ahead',   behind = 'orb_behind'},
           range = {16, 300}, pitch = {1.25, 0.80}, volume = {0.95, 0.35}},
}


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


local function mine_demo()
  local steps = {ping(0, 'mine', -0.4, 1, 1)}
  for i, pan in ipairs({-0.9, -0.45, 0, 0.45, 0.9}) do
    table.insert(steps, ping(1 + i * 0.04, 'incoming', pan, 1, 0.7))
  end
  return steps
end


-- ----------------------------------------------------------------- sounds --

local SOUNDS = {
  {
    name = 'stereo check',
    detail = 'Five taps from your far left to your far right. Everything in the arena is panned this way, ' ..
      'relative to the direction the snake is facing rather than to the screen: hard left means on your left, ' ..
      'whichever way you happen to be pointing.',
    demo = {duration = 2, steps = sweep('wall', 5, -1, 1, 0.35, 1.1, 1)},
  },
  {
    name = 'enemy',
    detail = 'The nearest enemy holds a tone for as long as it is there. Bright when it is in front of you, ' ..
      'dull and low when it is behind, rising and pulsing faster as it closes. Turn until it is bright and ' ..
      'centred and you are heading straight at it. This one passes you on the left, across the front, and ' ..
      'away on the right.',
    demo = {duration = 5.4, track = pass(VOICES.enemy, 5.4, 30, 240)},
  },
  {
    name = 'enemy touching you',
    detail = 'A hard, fast rattle over the top of the enemy tone. Something is within touching distance and ' ..
      'is taking a hero\'s health for every moment it stays there. Turn away from it.',
    demo = {duration = 1.7, track = hold(VOICES.enemy, 0.5, 20),
      steps = sweep('enemy_close', 9, 0.45, 0.45, 0.14, 1, 0.9)},
  },
  {
    name = 'enemy shot',
    detail = 'A buzz, panned to the side the shot is flying in from and deliberately unlike any enemy tone. ' ..
      'Steer sideways and let it pass.',
    demo = {duration = 1.4, steps = {
      ping(0, 'incoming', -0.85, 0.95, 0.9),
      ping(0.35, 'incoming', -0.6, 1.05, 0.95),
      ping(0.7, 'incoming', -0.3, 1.15, 1),
    }},
  },
  {
    name = 'headbutter charging',
    detail = 'A fluttering tone: a headbutter has locked on to you and is winding up to charge in a straight ' ..
      'line. Steer sideways rather than away and it will miss.',
    demo = {duration = 1.8, steps = {ping(0, 'charge', 0.55, 1, 1), ping(0.9, 'charge', 0.55, 1.05, 1)}},
  },
  {
    name = 'mine',
    detail = 'A sharp high tick where an exploder died. About a second later the mine bursts into a ring of ' ..
      'shots, which is what follows the tick here.',
    demo = {duration = 2.2, steps = mine_demo()},
  },
  {
    name = 'enemies arriving',
    detail = 'A wobbling tone marks a spot where enemies are about to appear: once in the middle, then panned ' ..
      'to where they will be. They arrive about a second later, and the place is spoken as well.',
    demo = {duration = 1.6, steps = {ping(0, 'spawn', 0, 1, 0.9), ping(0.05, 'spawn', -0.65, 0.8, 0.9)}},
  },
  {
    name = 'the elite',
    detail = 'Every sixth round has an elite, and it holds a slow, heavy tone of its own so that you can find ' ..
      'it under the swarm. Killing it and its escorts ends the round.',
    demo = {duration = 5.4, track = pass(VOICES.elite, 5.4, 45, 260)},
  },
  {
    name = 'gold',
    detail = 'Loose gold ticks like a flipped coin, four or five times a second, and goes on ticking until ' ..
      'somebody picks it up. Run the head of the snake over it; whatever you collect is added to the ' ..
      'round\'s reward. Both pickups are struck sounds that repeat, where the enemy and the elite hold a ' ..
      'tone that never stops, so a thing worth chasing never sounds like a thing worth avoiding.',
    demo = {duration = 4.6, track = pass(VOICES.gold, 4.6, 25, 270)},
  },
  {
    name = 'healing orb',
    detail = 'A healing orb glows with a soft chime about twice a second, half the rate of gold\'s coin and ' ..
      'with none of its metal, each one still ringing when the next arrives. Running over it heals your ' ..
      'heroes, and it is worth crossing the whole arena for.',
    demo = {duration = 4.6, track = pass(VOICES.orb, 4.6, 25, 270)},
  },
  {
    name = 'wall ahead',
    detail = 'A dry wooden knock means a wall is straight ahead on your current heading. It starts about ' ..
      'seven steps out and gets faster and higher as you close in. Hitting it bounces you off, and your new ' ..
      'heading is spoken.',
    demo = {duration = wall_duration, steps = wall_steps},
  },
  {
    name = 'wall beside you',
    detail = 'A soft low pad on one side means you are running along that wall. It is not a warning, only a ' ..
      'way of staying oriented while you hug an edge.',
    demo = {duration = 1.8, steps = sweep('edge', 4, -0.9, -0.9, 0.45, 1, 0.8)},
  },
  {
    name = 'hero lost',
    detail = 'A descending tone: one of your heroes has died and left the snake. The hero is named too, and ' ..
      'so is whoever becomes the new head.',
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
    access.say('audio cues are switched off. Turn them back on in the options, or press F4 to raise the cue volume.',
      {interrupt = true, priority = true})
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
    lines = {{text = '[fg]learn sounds', font = fat_font, alignment = 'center'}}}
  Text2{group = st.sound_lab, x = gw/2, y = 44,
    lines = {{text = '[bg10]arrow keys or tab to browse, enter to play, escape to go back',
      font = pixul_font, alignment = 'center'}}}

  local rows = math.ceil(#SOUNDS / #COLUMN_LEFT)
  for i, entry in ipairs(SOUNDS) do
    local column = math.min(#COLUMN_LEFT, math.ceil(i / rows))
    local row = i - (column - 1) * rows
    local width = pixul_font:get_text_width(entry.name) + 8
    local b = Button{group = st.sound_lab, x = COLUMN_LEFT[column] + width/2, y = ROW_TOP + (row - 1) * ROW_STEP,
      force_update = true, button_text = entry.name, fg_color = 'bg10', bg_color = 'bg',
      action = function() play(entry) end}
    -- Tab order is stated outright: read down the first column and then down the
    -- second, rather than zigzagging between them the way screen rows would.
    b.a11y_order = i
    b.a11y_label = entry.name
    b.a11y_detail = entry.detail
  end

  local back = Button{group = st.sound_lab, x = gw/2, y = BACK_Y, force_update = true,
    button_text = 'back (esc)', fg_color = 'bg10', bg_color = 'bg', action = function() lab.close(st) end}
  back.a11y_order = #SOUNDS + 1
  back.a11y_label = 'back to the main menu'

  access.say('Learn sounds. ' .. #SOUNDS .. ' sounds, each one the way it is heard in the arena. ' ..
    'Tab or the arrow keys browse, enter plays the one you are on, escape goes back.',
    {interrupt = true, priority = true})
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
  access.say('Main menu.', {interrupt = true, priority = true})
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

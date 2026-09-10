-- Tutorial runs: one enemy at a time, explained first and then fought alone.
--
-- SNKRX introduces its enemies by throwing eight of them at you at once and
-- colouring them differently. That works if you can see the colours. If you
-- cannot, the first time you meet a headbutter is a tone you have never heard
-- followed by a hero dying, and nothing in between tells you the two were
-- related. The sound reference next door teaches the cues; this teaches what
-- is making them.
--
-- Each lesson is a briefing and then a small arena holding nothing but that
-- one enemy, weakened enough that a single hero can clear it but never so much
-- that it stops doing the thing it is there to demonstrate. Elites keep a few
-- escorts, because every elite attack in the game is aimed at its own allies
-- and an elite on its own would simply walk at you in silence.
--
-- Dying costs nothing: the lesson restarts. Clearing one marks it in the save.

tutorial = {}


-- The hero every lesson is fought with. A magician is the one cheap character
-- whose attack is both ranged and an area: ranged so that the lessons about
-- keeping your distance can be played the way they are being taught, and an
-- area because ordinary shots pass straight through critters and half of
-- these lessons end in a cloud of them.
local HERO = {{character = 'magician', level = 3}}


-- Squads are spelled out per lesson rather than derived, because the whole
-- point of a lesson is that its numbers are chosen for what it has to show.
-- `hp` and `dmg` are absolute values the enemy is scaled to after it is built,
-- so they stay meaningful when the level next to them changes.
tutorial.lessons = {
  {
    key = 'seeker',
    name = 'enemy',
    brief = 'The plain enemy, and nine out of ten of everything you will fight. It walks straight at you ' ..
      'and does nothing else: it cannot shoot, and the only way it can hurt you is by touching one of your ' ..
      'heroes. A snake that keeps moving takes almost nothing from it. Its tone is the one you will hear ' ..
      'most, bright when it is ahead of you and dull when it is behind, rising as it closes. Kill all three.',
    squads = {{n = 3, hp = 80}},
  },
  {
    key = 'shooter',
    name = 'shooter',
    brief = 'A shooter walks at you for a couple of seconds, then plants itself, turns to face you and ' ..
      'fires bursts of three shots. Once it has stopped it never moves again, so it is the one enemy you ' ..
      'can safely leave until last. The shots are a buzz panned to the side they are coming from. They ' ..
      'travel in a straight line and do not follow you, so a small turn across them is enough to be ' ..
      'somewhere else when they arrive.',
    squads = {{n = 3, kind = 'shooter', hp = 80}},
  },
  {
    key = 'headbutter',
    name = 'headbutter',
    brief = 'A headbutter walks like a plain enemy until you come within a few steps of it. Then it locks ' ..
      'on and winds up for two seconds, which is the fluttering tone, before charging in a straight line ' ..
      'much faster than anything else moves. Steer sideways rather than away: it commits to the line it ' ..
      'started on and cannot correct. A charge that lands costs several times an ordinary touch, so that ' ..
      'sideways turn is the whole lesson. Each one can only charge every ten seconds.',
    squads = {{n = 3, kind = 'headbutter', hp = 110}},
  },
  {
    key = 'exploder',
    name = 'exploder',
    brief = 'An exploder walks at you like a plain enemy and dies after about twenty seconds whether you ' ..
      'kill it or not. Wherever it dies it leaves a mine: a sharp tick, three times, higher each time, and ' ..
      'then a ring of eight shots thrown out in every direction. The tick is the only warning and it is ' ..
      'enough. Kill exploders away from where you are heading, and when you hear one start ticking, be ' ..
      'travelling away from it before it finishes.',
    squads = {{n = 3, kind = 'exploder', hp = 70}},
  },
  {
    key = 'speed_booster',
    name = 'speed booster',
    brief = 'A speed booster walks at you like a plain enemy and, like an exploder, dies on its own after ' ..
      'a while. Whenever one dies, every enemy standing near it moves at three times its normal speed for ' ..
      'the next few seconds, and you will hear their tones climb and quicken with them. A swarm that was ' ..
      'comfortably behind you can be on top of you a second later. Kill them where the rest of the round ' ..
      'is not, and expect the survivors to arrive early.',
    squads = {{n = 3, kind = 'speed_booster', hp = 90}},
  },
  {
    key = 'tank',
    name = 'tank',
    brief = 'A tank has several times the health of anything else and moves at a crawl, so it is almost ' ..
      'never the thing that kills you. What kills you is its company: every few seconds it shoves the ' ..
      'nearest enemy hard in your direction. A shoved enemy crosses the arena in a moment, arriving from ' ..
      'a bearing its tone had no time to walk you through. Clear the enemies around a tank first, then ' ..
      'take as long as you like over the tank itself. Here the three tanks shove each other.',
    squads = {{n = 3, kind = 'tank', hp = 120}},
  },
  {
    key = 'spawner',
    name = 'spawner',
    brief = 'A spawner walks at you like a plain enemy, and when it dies it bursts into five to eight ' ..
      'critters: small, fast, fragile enemies that die the instant they touch you and take a bite out of ' ..
      'a hero on the way through. Ordinary shots pass straight through a critter, so only area attacks ' ..
      'and running them over will clear them. Killing a spawner always costs you something. Kill it with ' ..
      'room around you, never while you are cornered.',
    squads = {{n = 2, kind = 'spawner', hp = 90}},
  },
  {
    key = 'elite_speed_booster',
    name = 'speed booster elite',
    brief = 'An elite is the single large enemy that ends every sixth round, and it holds a slow, heavy ' ..
      'tone of its own so that you can find it underneath the swarm. This one speeds up the four enemies ' ..
      'nearest it every eight seconds, so its escorts, not the elite, are what will kill you. Elites move ' ..
      'slowly and stay with their group rather than chasing you. Kill everything here to finish the run.',
    -- Escorts are the demonstration material for every elite: an elite whose
    -- allies have already died spends the rest of the fight walking at you in
    -- silence. They are given enough health to outlast two of its attacks,
    -- and the ones that eat their own escorts are given more of them.
    squads = {{n = 1, boss = 'speed_booster', level = 6, hp = 180, dmg = 14}, {n = 4, hp = 90, dmg = 10}},
  },
  {
    key = 'elite_exploder',
    name = 'exploder elite',
    brief = 'Every four seconds the exploder elite kills one of its own escorts and leaves a mine where ' ..
      'it stood. The mines are the fight: the elite turns its own swarm into a minefield laid wherever ' ..
      'you happen to be standing. Every mine ticks three times before it throws out its ring of shots, so ' ..
      'keep moving through open ground and never circle back over ground you have just fought on.',
    squads = {{n = 1, boss = 'exploder', level = 12, hp = 180, dmg = 14}, {n = 5, hp = 70, dmg = 10}},
  },
  {
    key = 'elite_swarmer',
    name = 'swarmer elite',
    brief = 'Every four seconds the swarmer elite kills one of its own escorts and turns it into four to ' ..
      'six critters, so its swarm grows faster than shots alone can clear it. Critters die on contact ' ..
      'with you and to area attacks, and are untouched by ordinary shots. Killing the elite stops the ' ..
      'supply, so unlike most rounds this is one where going for the elite first is right.',
    squads = {{n = 1, boss = 'swarmer', level = 18, hp = 170, dmg = 14}, {n = 4, hp = 80, dmg = 10}},
  },
  {
    key = 'elite_forcer',
    name = 'forcer elite',
    brief = 'Every six seconds the forcer elite marks a point on the floor, drags every enemy near that ' ..
      'point towards it for two seconds, and then flings the whole gathered bunch at you at once. The ' ..
      'gathering is quiet; the arrival is not. When several enemy tones slide together into one place, ' ..
      'that is the wind-up, and you want to be a long way from where you are now before it ends.',
    squads = {{n = 1, boss = 'forcer', level = 24, hp = 240, dmg = 14}, {n = 4, hp = 90, dmg = 10}},
  },
  {
    key = 'elite_randomizer',
    name = 'randomizer elite',
    brief = 'The randomizer elite ends the last round of the game and does one of the other four elites\' ' ..
      'tricks at random every six seconds: speeding its allies up, detonating one into a ring of shots, ' ..
      'bursting one into critters, or flinging the group at you. Each one is spoken as it happens, which ' ..
      'is the only warning there is. There is no pattern to read here, only the four answers you already ' ..
      'know, chosen quickly.',
    squads = {{n = 1, boss = 'randomizer', level = 25, hp = 240, dmg = 14}, {n = 5, hp = 70, dmg = 10}},
  },
}


tutorial.by_key = {}
for i, lesson in ipairs(tutorial.lessons) do
  lesson.i = i
  lesson.units = lesson.units or HERO
  tutorial.by_key[lesson.key] = lesson
end


-- ------------------------------------------------------------ persistence --

function tutorial.is_complete(key)
  return (state and state.tutorial_completed and state.tutorial_completed[key]) and true or false
end


function tutorial.mark_complete(key)
  state = state or {}
  state.tutorial_completed = state.tutorial_completed or {}
  if state.tutorial_completed[key] then return false end
  state.tutorial_completed[key] = true
  pcall(system.save_state)
  return true
end


function tutorial.completed_count()
  local n = 0
  for _, lesson in ipairs(tutorial.lessons) do
    if tutorial.is_complete(lesson.key) then n = n + 1 end
  end
  return n
end


-- The lesson to offer next after finishing `key`: the first unfinished one
-- after it, wrapping round, so a player working through the list is never
-- offered something they have already cleared.
function tutorial.next_incomplete(key)
  local lesson = tutorial.by_key[key]
  local start = lesson and lesson.i or 0
  for offset = 1, #tutorial.lessons do
    local candidate = tutorial.lessons[((start + offset - 1) % #tutorial.lessons) + 1]
    if not tutorial.is_complete(candidate.key) then return candidate end
  end
  return nil
end


-- ------------------------------------------------------------------ text --

-- The game's Text draws each line exactly as it is given and would happily run
-- off both edges of the screen, so wrapping is done here. Same approach as the
-- sound reference; the two are deliberately not shared, because a change to
-- either one's column width has no business moving the other.
function tutorial.wrap(text, width)
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


local function first_sentence(text)
  return text:match('^(.-%.)%s') or text
end


-- ------------------------------------------------------------------ menu --

-- Left edges rather than centres, for the same reason the sound reference uses
-- them: a column of names of different lengths reads as a list when it is
-- flush left and as a scatter when it is centred.
local COLUMN_LEFT = {28, 258}
local ROW_TOP, ROW_STEP = 64, 19
local PROGRESS_Y = 176
local BACK_Y = 194
local DETAIL_Y = 216

local BRIEF_TOP, BRIEF_STEP = 54, 13
local START_Y = 186
local BRIEF_BACK_Y = 208


local shown_detail = nil


-- Every page switch happens a frame late. A button's action runs from inside
-- its own group's update, and tearing that group down from in there is asking
-- for a list being iterated to be edited underneath the iteration.
local function next_frame(fn)
  trigger:after(0.01, fn)
end


local function clear_menu(st)
  if st.tutorial_menu then
    for _, o in ipairs(st.tutorial_menu.objects) do o.dead = true end
    st.tutorial_menu:update(0)
  end
  st.tutorial_detail = nil
  shown_detail = nil
end


local function build_list(st)
  clear_menu(st)
  st.tutorial_page = 'list'

  Text2{group = st.tutorial_menu, x = gw/2, y = 22,
    lines = {{text = '[fg]tutorial runs', font = fat_font, alignment = 'center'}}}
  Text2{group = st.tutorial_menu, x = gw/2, y = 44,
    lines = {{text = '[bg10]one enemy at a time, explained and then fought on its own',
      font = pixul_font, alignment = 'center'}}}

  local rows = math.ceil(#tutorial.lessons / #COLUMN_LEFT)
  for i, lesson in ipairs(tutorial.lessons) do
    local column = math.min(#COLUMN_LEFT, math.ceil(i / rows))
    local row = i - (column - 1) * rows
    local done = tutorial.is_complete(lesson.key)
    local label = lesson.name .. (done and ' - done' or '')
    local width = pixul_font:get_text_width(label) + 8
    local b = Button{group = st.tutorial_menu, x = COLUMN_LEFT[column] + width/2,
      y = ROW_TOP + (row - 1) * ROW_STEP, force_update = true, button_text = label,
      fg_color = 'bg10', bg_color = 'bg',
      action = function() next_frame(function() tutorial.show_brief(st, lesson.key) end) end}
    -- Reading order is stated outright: down the first column and then down
    -- the second, rather than zigzagging between them the way screen rows
    -- would. The whole list is one group so the arrow keys walk it, and Tab is
    -- left to reach the one control that is not a lesson.
    b.a11y_order = i
    b.a11y_group = 'lessons'
    b.a11y_label = lesson.name .. (done and ', done' or ', not done yet')
    b.a11y_detail = first_sentence(lesson.brief)
  end

  local done = tutorial.completed_count()
  Text2{group = st.tutorial_menu, x = gw/2, y = PROGRESS_Y, lines = {
    {text = '[bg10]' .. done .. ' of ' .. #tutorial.lessons .. ' done', font = pixul_font, alignment = 'center'}}}

  local back = Button{group = st.tutorial_menu, x = gw/2, y = BACK_Y, force_update = true,
    button_text = 'back (esc)', fg_color = 'bg10', bg_color = 'bg',
    action = function() next_frame(function() tutorial.close(st) end) end}
  back.a11y_order = #tutorial.lessons + 1
  back.a11y_group = 'controls'
  back.a11y_label = 'back to the main menu'

  access.say('Tutorial runs. ' .. #tutorial.lessons .. ' enemies, ' .. done .. ' done. ' ..
    'Each one is explained and then fought on its own in a small arena, with a single hero, until you ' ..
    'clear it. The arrow keys move through the list, enter opens the one you are on, tab reaches the back ' ..
    'button, and escape goes back.',
    {interrupt = true, priority = true})
end


function tutorial.show_brief(st, key)
  local lesson = tutorial.by_key[key]
  if not lesson then return end
  clear_menu(st)
  st.tutorial_page = 'brief'
  st.tutorial_key = key

  Text2{group = st.tutorial_menu, x = gw/2, y = 24,
    lines = {{text = '[fg]' .. lesson.name, font = fat_font, alignment = 'center'}}}

  local lines = {}
  for _, line in ipairs(tutorial.wrap(lesson.brief, 400)) do
    table.insert(lines, {text = '[bg10]' .. line, font = pixul_font, alignment = 'center'})
  end
  for i, line in ipairs(lines) do
    Text2{group = st.tutorial_menu, x = gw/2, y = BRIEF_TOP + (i - 1) * BRIEF_STEP, lines = {line}}
  end

  local start = Button{group = st.tutorial_menu, x = gw/2, y = START_Y, force_update = true,
    button_text = 'start the run', fg_color = 'bg10', bg_color = 'bg',
    action = function() tutorial.launch(st, key) end}
  start.a11y_order = 1
  start.a11y_group = 'controls'
  start.a11y_label = 'start the run'
  start.a11y_detail = 'a small arena holding nothing but ' .. lesson.name .. 's, and one hero'

  local back = Button{group = st.tutorial_menu, x = gw/2, y = BRIEF_BACK_Y, force_update = true,
    button_text = 'back to the list (esc)', fg_color = 'bg10', bg_color = 'bg',
    action = function() next_frame(function() build_list(st) end) end}
  back.a11y_order = 2
  back.a11y_group = 'controls'
  back.a11y_label = 'back to the list of enemies'

  access.say(lesson.name .. '. ' .. lesson.brief ..
    ' Enter starts the run, escape goes back to the list.', {interrupt = true, priority = true})
end


-- `at` opens straight onto one lesson's briefing, which is how the arena hands
-- the player on to the next enemy without a detour through the list.
function tutorial.open(st, at)
  if not st or st.in_tutorial_menu then return end
  st.tutorial_menu = Group():no_camera()
  st.in_tutorial_menu = true
  tutorial.open_on = st
  if at and tutorial.by_key[at] then tutorial.show_brief(st, at) else build_list(st) end
end


function tutorial.close(st, silent)
  st = st or tutorial.open_on
  if not st or not st.in_tutorial_menu then return end
  clear_menu(st)
  st.in_tutorial_menu = false
  st.tutorial_page = nil
  st.tutorial_key = nil
  tutorial.open_on = nil
  if st.tutorial_menu then
    st.tutorial_menu:destroy()
    st.tutorial_menu = nil
  end
  if not silent then access.say('Main menu.', {interrupt = true, priority = true}) end
end


-- Escape backs out one step at a time: off a briefing to the list, off the
-- list to the menu behind it.
function tutorial.escape(st)
  if not st or not st.in_tutorial_menu then return end
  if st.tutorial_page == 'brief' then build_list(st) else tutorial.close(st) end
end


function tutorial.update(st, dt)
  if not st or not st.in_tutorial_menu then return end
  if st.tutorial_page ~= 'list' then return end

  -- The description of whatever is focused, on screen as well as spoken: this
  -- screen is for anyone still learning the enemies, not only for players who
  -- cannot see them.
  local focus = access.nav and access.nav.focus
  local text = focus and focus.a11y_detail or nil
  if text == shown_detail then return end
  shown_detail = text
  if st.tutorial_detail then st.tutorial_detail.dead = true st.tutorial_detail = nil end
  if not text then return end
  local lines = {}
  for i, line in ipairs(tutorial.wrap(text, 440)) do
    if i <= 2 then table.insert(lines, {text = '[bg10]' .. line, font = pixul_font, alignment = 'center'}) end
  end
  if #lines == 0 then return end
  st.tutorial_detail = Text2{group = st.tutorial_menu, x = gw/2, y = DETAIL_Y, lines = lines}
end


-- Drawn by the state, over its own darkened screen.
function tutorial.draw(st)
  if st and st.in_tutorial_menu and st.tutorial_menu then st.tutorial_menu:draw() end
end


-- --------------------------------------------------------------- the run --

-- The arena reads the run's globals whether or not there is a run, and a
-- lesson is entered straight from the main menu where there is not one. These
-- are the two it would otherwise do arithmetic on. Nothing here is ever saved
-- back: a lesson never touches run_v4.txt.
local function prepare_globals()
  run_time = run_time or 0
  gold = gold or 0
  passives = passives or {}
end


function tutorial.launch(st, key)
  local lesson = tutorial.by_key[key]
  if not lesson then return end
  ui_transition2:play{pitch = random:float(0.95, 1.05), volume = 0.5}
  ui_switch2:play{pitch = random:float(0.95, 1.05), volume = 0.5}
  ui_switch1:play{pitch = random:float(0.95, 1.05), volume = 0.5}
  TransitionEffect{group = main.transitions, x = gw/2, y = gh/2,
    color = state.dark_transitions and bg[-2] or fg[0], transition_action = function()
      if st then
        st.transitioning = true
        tutorial.close(st, true)
      end
      slow_amount = 1
      music_slow_amount = 1
      prepare_globals()
      main:add(Arena'arena')
      main:go_to('arena', 1, 0, table.copy(lesson.units), {}, 1, 0, nil, lesson)
    end,
    text = Text({{text = '[wavy, ' .. tostring(state.dark_transitions and 'fg' or 'bg') .. ']starting...',
      font = pixul_font, alignment = 'center'}}, global_text_tags)}
end


-- Back to the main menu with the tutorial screen already open, either on the
-- list or on the next enemy's briefing.
function tutorial.leave_arena(at)
  ui_transition2:play{pitch = random:float(0.95, 1.05), volume = 0.5}
  ui_switch1:play{pitch = random:float(0.95, 1.05), volume = 0.5}
  TransitionEffect{group = main.transitions, x = gw/2, y = gh/2,
    color = state.dark_transitions and bg[-2] or fg[0], transition_action = function()
      slow_amount = 1
      music_slow_amount = 1
      main:add(MainMenu'main_menu')
      main:go_to('main_menu', at or true)
    end,
    text = Text({{text = '[wavy, ' .. tostring(state.dark_transitions and 'fg' or 'bg') .. ']..',
      font = pixul_font, alignment = 'center'}}, global_text_tags)}
end

-- SNKRX accessibility layer.
--
-- The goal is a game a blind player can start, understand and finish without
-- ever seeing the screen. That splits up as follows, one concern per file:
--
--   prism.lua      speech, routed through whatever screen reader is running
--   ui_nav.lua     keyboard access to menus, the shop and the card screens
--   arena_hud.lua  spatial audio and reports for the arena itself
--   audio.lua      the procedural stereo cues those reports lean on
--   describe.lua   turning the game's markup and jargon into speech
--
-- Everything here is defensive. An accessibility layer that can crash the game
-- is worse than none at all, so each entry point is wrapped and each failure
-- degrades to "quieter" rather than "broken".

local path = ...

access = {}

require(path .. '.prism')
require(path .. '.audio')
require(path .. '.describe')
require(path .. '.ui_nav')
require(path .. '.arena_hud')

access.enabled = true
access.speech_enabled = true
access.last_message = nil
access.history = {}

local last_text, last_time = nil, -100
local watched_screen, watched_paused, watched_modal, watched_tutorial = nil, nil, nil, nil
local errors_reported = {}
local first_announcement = true


-- ---------------------------------------------------------------- speaking --

-- opts.interrupt  cut off whatever is being spoken (default true)
-- opts.priority   speak even if an identical line was just said
-- opts.repeat_after  seconds before an identical line may repeat (default 1.2)
function access.say(text, opts)
  if not access.enabled then return end
  if not text or text == '' then return end
  opts = opts or {}

  text = access.describe.speech(text)
  if text == '' then return end

  local now = love.timer.getTime()
  if not opts.priority and text == last_text and (now - last_time) < (opts.repeat_after or 1.2) then
    return
  end
  last_text, last_time = text, now

  access.last_message = text
  table.insert(access.history, text)
  if #access.history > 40 then table.remove(access.history, 1) end
  access.history_index = nil

  if access.speech_enabled then
    access.tts.speak(text, opts.interrupt ~= false)
  end
end


function access.repeat_last()
  if access.last_message then
    access.tts.speak(access.last_message, true)
  else
    access.say('nothing to repeat', {interrupt = true, priority = true})
  end
end


-- Things go past quickly in a fight, and a wave announcement heard over the top
-- of a health warning is a wave announcement lost. Stepping back through what
-- was said is the equivalent of scrolling back up.
function access.history_step(delta)
  local n = #access.history
  if n == 0 then
    access.tts.speak('no messages yet', true)
    return
  end
  access.history_index = math.max(1, math.min(n, (access.history_index or (n + 1)) + delta))
  access.tts.speak(access.history_index .. ' of ' .. n .. '. ' .. access.history[access.history_index], true)
end


-- ------------------------------------------------------------- persistence --

local function load_settings()
  state = state or {}
  local function default(key, value)
    if state[key] == nil then state[key] = value end
  end
  -- Accessibility ships on. A blind player cannot navigate to a menu to switch
  -- it on if navigating the menu is the thing it enables, and everything here
  -- is switchable from the options screen or with F2 in one keypress.
  default('access_enabled', true)
  default('access_speech', true)
  default('access_cues', true)
  default('access_cue_volume', 0.7)
  default('access_sonar_enemies', true)
  default('access_sonar_walls', true)
  default('access_sonar_pickups', true)

  access.enabled = state.access_enabled
  access.speech_enabled = state.access_speech
  access.nav.enabled = state.access_enabled
  access.audio.enabled = state.access_cues
  access.audio.volume = state.access_cue_volume
  access.hud.sonar_enemies = state.access_sonar_enemies
  access.hud.sonar_walls = state.access_sonar_walls
  access.hud.sonar_pickups = state.access_sonar_pickups
end


-- Only ever called from a deliberate toggle, which is what makes it a reliable
-- signal that the player has made up their own mind about all this.
local function save_settings()
  state.access_configured = true
  state.access_enabled = access.enabled
  state.access_speech = access.speech_enabled
  state.access_cues = access.audio.enabled
  state.access_cue_volume = access.audio.volume
  state.access_sonar_enemies = access.hud.sonar_enemies
  state.access_sonar_walls = access.hud.sonar_walls
  state.access_sonar_pickups = access.hud.sonar_pickups
  pcall(system.save_state)
end
access.save_settings = save_settings


-- ------------------------------------------------------------------ hooks --

-- Rather than scatter accessibility calls through the game's 400KB of logic,
-- wrap the handful of methods that mark a moment worth narrating.
local function install_hooks()
  -- Every hover tooltip in the game funnels through InfoText:activate, so a
  -- single wrapper makes every shop card, item and class icon speak its full
  -- description without touching any of them individually.
  local activate = InfoText.activate
  InfoText.activate = function(self, text, ...)
    local result = activate(self, text, ...)
    if access.enabled then
      local spoken = access.describe.lines(text)
      if spoken ~= '' then access.say(spoken, {interrupt = false}) end
    end
    return result
  end

  -- Spawn markers are the sighted player's one second of warning.
  local marker_init = SpawnMarker.init
  SpawnMarker.init = function(self, args)
    local result = marker_init(self, args)
    if access.enabled then pcall(access.hud.on_spawn_marker, self.x, self.y) end
    return result
  end

  local projectile_init = EnemyProjectile.init
  EnemyProjectile.init = function(self, args)
    local result = projectile_init(self, args)
    if access.enabled then pcall(access.hud.on_enemy_projectile, self) end
    return result
  end

  local arena_enter = Arena.on_enter
  Arena.on_enter = function(self, ...)
    local result = arena_enter(self, ...)
    if access.enabled then pcall(access.hud.on_arena_enter, self) end
    return result
  end

  -- Arena:die returns whether the run really ended, so the return has to
  -- survive the wrapper untouched.
  local arena_die = Arena.die
  Arena.die = function(self, ...)
    local was_dead = self.died
    local a, b, c = arena_die(self, ...)
    if access.enabled and not was_dead and self.died then pcall(access.hud.on_die, self) end
    return a, b, c
  end

  local arena_quit = Arena.quit
  Arena.quit = function(self, ...)
    local was_quitting = self.quitting
    local result = arena_quit(self, ...)
    if access.enabled and not was_quitting and self.quitting and not self.died then
      pcall(access.hud.on_clear, self)
    end
    return result
  end

  -- Buying is bound to the number keys as well as to clicks, and neither path
  -- says anything on success. Confirming the purchase, the price and what is
  -- left in the purse is the single most useful line in the shop.
  local buy = BuyScreen.buy
  BuyScreen.buy = function(self, character, i)
    local gold_before = gold
    local level_before = 0
    for _, u in ipairs(self.units or {}) do
      if u.character == character then level_before = u.level end
    end

    local bought = buy(self, character, i)

    if access.enabled then
      local name = access.describe.character(character)
      if bought then
        local level_after = 0
        for _, u in ipairs(self.units or {}) do
          if u.character == character then level_after = u.level end
        end
        local line = name .. ' bought for ' .. (gold_before - gold) .. ' gold'
        if level_after > level_before and level_before > 0 then
          line = line .. '. ' .. name .. ' is now level ' .. level_after
        end
        access.say(line .. '. ' .. gold .. ' gold left, party ' ..
          #(self.units or {}) .. ' of ' .. tostring(max_units), {interrupt = true, priority = true})
      elseif gold < (character_tiers[character] or 0) then
        -- The other two failure cases (party full, unit maxed) already raise
        -- an InfoText, which the tooltip hook speaks.
        access.say('not enough gold for ' .. name .. ', you have ' .. gold, {interrupt = true, priority = true})
      end
    end
    return bought
  end

  -- The only thing that adds gold inside the shop is selling something.
  local shop_gain_gold = BuyScreen.gain_gold
  BuyScreen.gain_gold = function(self, amount, ...)
    local result = shop_gain_gold(self, amount, ...)
    if access.enabled then
      access.say('sold for ' .. tostring(amount) .. ' gold, ' .. tostring(gold) .. ' gold total',
        {interrupt = true, priority = true})
    end
    return result
  end

  -- The end-of-round gold breakdown is animated into a transition circle that
  -- a blind player will never see.
  local gain_gold = Arena.gain_gold
  Arena.gain_gold = function(self, ...)
    local result = gain_gold(self, ...)
    if access.enabled then
      access.say('gold gained ' .. tostring(self.gold_gained or 0) ..
        ', picked up ' .. tostring(self.gold_picked_up or 0) ..
        ', interest ' .. tostring(self.interest or 0) ..
        '. Total ' .. tostring(gold) .. ' gold.', {interrupt = false})
    end
    return result
  end
end


-- --------------------------------------------------------- screen changes --

local function describe_shop(st)
  local parts = {'Shop'}
  table.insert(parts, 'round ' .. tostring(st.level))
  table.insert(parts, tostring(gold) .. ' gold')
  table.insert(parts, 'party ' .. tostring(#(st.units or {})) .. ' of ' .. tostring(max_units))
  table.insert(parts, 'shop level ' .. tostring(st.shop_level))
  local summary = table.concat(parts, ', ') .. '.'

  local cards = {}
  for i = 1, 3 do
    local card = st.cards and st.cards[i]
    if card and card.unit then
      table.insert(cards, i .. ', ' .. access.describe.character(card.unit) ..
        ', ' .. tostring(card.cost or '?') .. ' gold, ' .. access.describe.classes_of(card.unit))
    end
  end
  if #cards > 0 then summary = summary .. ' For sale: ' .. table.concat(cards, '. ') .. '.' end
  return summary .. ' Press 1, 2 or 3 to buy, tab to browse, G to start the round.'
end


local function announce_screen(st)
  if st == nil then return end
  local prefix = ''
  if first_announcement then
    first_announcement = false
    -- Accessibility being on by default is the right call (see load_settings),
    -- but a player who does not want it deserves to be told how to stop it.
    -- Once they have touched any accessibility setting, drop the reminder.
    prefix = state.access_configured and 'SNKRX. '
      or 'SNKRX. Accessibility is on. Press F2 to turn it off. '
  end
  if st.is and st:is(MainMenu) then
    access.say(prefix .. 'Main menu. Tab to move, enter to choose, F1 for the accessibility keys.',
      {interrupt = true})
  elseif st.is and st:is(BuyScreen) then
    access.say(prefix .. describe_shop(st), {interrupt = true})
  elseif prefix ~= '' then
    access.say(prefix .. 'Press F1 for the accessibility keys.', {interrupt = true})
  end
  -- The arena announces itself from Arena.on_enter, which fires earlier and
  -- knows about waves and elites.
end


local function watch_screen()
  local st = main and main.current
  if st ~= watched_screen then
    watched_screen = st
    watched_paused, watched_modal, watched_tutorial = nil, nil, nil
    announce_screen(st)
    return
  end
  if not st then return end

  if st.paused ~= watched_paused then
    watched_paused = st.paused
    if st.paused then
      access.say('Options. Tab to move, enter to change, backspace to change the other way. F1 for the accessibility keys.',
        {interrupt = true})
    elseif watched_paused ~= nil then
      access.say('resumed', {interrupt = true})
    end
  end

  -- The shop's guide is a wall of text with no interactive parts, so nothing
  -- else here would ever read it out.
  if st.in_tutorial ~= watched_tutorial then
    watched_tutorial = st.in_tutorial
    if st.in_tutorial then
      local function lines_of(t)
        if not t then return nil end
        return t.lines or (t.text and t.text.text_data)
      end
      local parts = {}
      for _, source in ipairs({st.title_text, st.tutorial_text}) do
        local spoken = access.describe.lines(lines_of(source))
        if spoken and spoken ~= '' then table.insert(parts, spoken) end
      end
      table.insert(parts, 'Press escape to close the guide.')
      access.say(table.concat(parts, ' '), {interrupt = true})
    end
  end

  -- Modal card screens inside the arena.
  local modal = nil
  if st.choosing_passives then modal = 'passives'
  elseif st.died then modal = 'died'
  elseif st.won then modal = 'won' end
  if modal ~= watched_modal then
    watched_modal = modal
    if modal == 'passives' then
      local n = st.cards and #st.cards or 0
      access.say('Choose one item. ' .. n .. ' on offer. Press 1 to ' .. math.max(n, 1) ..
        ' to pick, or tab to browse. R rerolls.', {interrupt = true})
    elseif modal == 'won' then
      access.say('You won the run. Congratulations.', {interrupt = true})
    end
  end
end


-- ------------------------------------------------------------------- help --

local HELP = {
  'Accessibility keys.',
  'Anywhere: F1 this help. F2 turn accessibility off or on. F3 speech on or off. F4 cue volume. M repeat the last message. Comma and full stop step back and forward through everything that has been said.',
  'Menus and shop: tab and shift tab to move, arrow keys also move, enter or space to choose, backspace for the secondary action such as selling.',
  'Shop only: 1, 2 and 3 buy a card, G starts the round, page up and page down reorder the selected party member, Y reads your build.',
  'Arena: Q status, W position and heading, T enemies, G loose gold and healing orbs, H party health, Y your build.',
  'Arena sound: a bright ping is an enemy in front of you, a low dull ping is an enemy behind you, a fast rattle is an enemy about to touch you. A buzz is a shot flying at you. A wooden knock is the wall you are heading into, getting faster as you close in. A soft low pad on one side means you are running along that wall. Bells are gold and healing orbs. A wobbling tone marks a spot where enemies are about to appear.',
  'Arena toggles: F enemy sonar, V wall sonar, C pickup sonar.',
  'Steering: A or left arrow turns left, D or right arrow turns right. Escape opens the options.',
}

function access.help()
  access.say(HELP[1], {interrupt = true, priority = true})
  for i = 2, #HELP do access.say(HELP[i], {interrupt = false, priority = true}) end
end


-- --------------------------------------------------------------- hotkeys --

local function pressed(key)
  local action = input[key]
  return action and action.pressed
end


local function toggle_setting(current, name, on_text, off_text)
  local value = not current
  access.say(name .. ' ' .. (value and (on_text or 'on') or (off_text or 'off')),
    {interrupt = true, priority = true})
  save_settings()
  return value
end


function access.toggle()
  access.enabled = not access.enabled
  access.nav.enabled = access.enabled
  if not access.enabled then
    -- Say it before switching off, otherwise the message never comes out.
    access.tts.speak('accessibility off', true)
    access.audio.stop_all()
  else
    access.say('accessibility on', {interrupt = true, priority = true})
  end
  save_settings()
end


local function handle_hotkeys()
  if pressed('f1') then access.help() return true end

  if pressed('f2') then access.toggle() return true end

  if pressed('f3') then
    access.speech_enabled = not access.speech_enabled
    if access.speech_enabled then
      access.say('speech on', {interrupt = true, priority = true})
    else
      access.tts.speak('speech off', true)
    end
    save_settings()
    return true
  end

  if pressed('f4') then
    local v = access.audio.volume + 0.1
    if v > 1.001 then v = 0 end
    access.audio.volume = v
    access.audio.play('gold', 0, 1, 1)
    access.say('cue volume ' .. math.floor(v * 10 + 0.5), {interrupt = true, priority = true})
    save_settings()
    return true
  end

  if pressed('m') then access.repeat_last() return true end
  if pressed(',') then access.history_step(-1) return true end
  if pressed('.') then access.history_step(1) return true end

  if pressed('f') then
    access.hud.sonar_enemies = toggle_setting(access.hud.sonar_enemies, 'enemy sonar')
    return true
  end
  if pressed('v') then
    access.hud.sonar_walls = toggle_setting(access.hud.sonar_walls, 'wall sonar')
    return true
  end
  if pressed('c') then
    access.hud.sonar_pickups = toggle_setting(access.hud.sonar_pickups, 'pickup sonar')
    return true
  end

  if pressed('q') then access.hud.report_status() return true end
  if pressed('w') then access.hud.report_position() return true end
  if pressed('t') then access.hud.report_enemies() return true end
  if pressed('h') then access.hud.report_party() return true end
  if pressed('y') then access.hud.report_build() return true end

  if pressed('g') then
    local st = main and main.current
    if st and st.is and st:is(BuyScreen) then
      -- G is the shop's "start the round" verb; see access.enter_starts_round.
      return false
    end
    access.hud.report_pickups()
    return true
  end

  return false
end


-- The shop starts a round on Enter from anywhere on the screen, which is fine
-- with a mouse and hostile with a keyboard: every Enter press meant for a
-- button would also launch the round. With accessibility on, Enter belongs to
-- the focused widget and G starts the round instead.
function access.enter_starts_round()
  if access.enabled and access.nav.enabled then
    return pressed('g')
  end
  return pressed('enter')
end


-- -------------------------------------------------------- options screen --

-- Built by main.lua's open_options so the accessibility settings live beside
-- the rest of the game's settings rather than in a separate place.
function access.create_options(self)
  if not Button then return end
  self.access_buttons = {}
  local y = gh - 250

  local function add(x, w, text, action, action_2)
    local b = Button{group = self.ui, x = x, y = y, w = w, force_update = true, button_text = text,
      fg_color = 'bg10', bg_color = 'bg', action = action, action_2 = action_2}
    table.insert(self.access_buttons, b)
    return b
  end

  add(62, 112, 'accessibility: ' .. (access.enabled and 'yes' or 'no'), function(b)
    access.toggle()
    b:set_text('accessibility: ' .. (access.enabled and 'yes' or 'no'))
  end)

  add(182, 120, 'screen reader: ' .. (access.speech_enabled and 'yes' or 'no'), function(b)
    access.speech_enabled = not access.speech_enabled
    if access.speech_enabled then access.say('speech on', {interrupt = true, priority = true})
    else access.tts.speak('speech off', true) end
    save_settings()
    b:set_text('screen reader: ' .. (access.speech_enabled and 'yes' or 'no'))
  end)

  add(300, 104, 'audio cues: ' .. (access.audio.enabled and 'yes' or 'no'), function(b)
    access.audio.enabled = not access.audio.enabled
    if not access.audio.enabled then access.audio.stop_all() end
    access.say('audio cues ' .. (access.audio.enabled and 'on' or 'off'), {interrupt = true, priority = true})
    save_settings()
    b:set_text('audio cues: ' .. (access.audio.enabled and 'yes' or 'no'))
  end)

  local function volume_text() return 'cue volume: ' .. math.floor(access.audio.volume * 10 + 0.5) end
  add(414, 110, volume_text(), function(b)
    local v = access.audio.volume + 0.1
    if v > 1.001 then v = 0 end
    access.audio.volume = v
    access.audio.play('gold', 0, 1, 1)
    save_settings()
    b:set_text(volume_text())
  end, function(b)
    local v = access.audio.volume - 0.1
    if v < -0.001 then v = 1 end
    access.audio.volume = math.max(0, v)
    access.audio.play('gold', 0, 1, 1)
    save_settings()
    b:set_text(volume_text())
  end)
end


function access.destroy_options(self)
  if not self.access_buttons then return end
  for _, b in ipairs(self.access_buttons) do b.dead = true end
  self.access_buttons = nil
end


-- ------------------------------------------------------------------ setup --

function access.init()
  load_settings()

  local speech_ok = false
  local ok, result = pcall(access.tts.init)
  if ok then speech_ok = result end
  if not speech_ok then
    print('[accessibility] speech unavailable: ' .. tostring(access.tts.error))
    print('[accessibility] place prism.dll (and tolk.dll) in the game\'s lib/ folder to enable speech.')
  else
    print('[accessibility] speech via ' .. tostring(access.tts.backend_name) ..
      ' (prism ' .. tostring(access.tts.version) .. ')')
  end

  pcall(access.audio.init)

  -- input:bind_all misses a couple of keys the navigation uses.
  if not input['end'] then pcall(input.bind, input, 'end', {'end'}) end

  pcall(install_hooks)
end


function access.update(dt)
  -- F2 has to keep working while everything else is switched off.
  if not access.enabled then
    if pressed('f2') then access.toggle() end
    return
  end

  local ok, err = pcall(function()
    watch_screen()
    access.nav.update(dt)
    if not handle_hotkeys() then
      access.nav.handle_input()
    end
    access.hud.update(dt)
  end)

  if not ok then
    local message = tostring(err)
    if not errors_reported[message] then
      errors_reported[message] = true
      print('[accessibility] ' .. message)
    end
  end
end


function access.quit()
  pcall(save_settings)
  pcall(access.tts.shutdown)
end

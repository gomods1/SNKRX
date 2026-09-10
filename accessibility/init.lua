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
--   guide.lua      the in-game guide, spoken, plus how to play by ear
--
-- Everything here is defensive. An accessibility layer that can crash the game
-- is worse than none at all, so each entry point is wrapped and each failure
-- degrades to "quieter" rather than "broken".

local path = ...

access = {}

require(path .. '.prism')
require(path .. '.audio')
require(path .. '.describe')
require(path .. '.guide')
require(path .. '.ui_nav')
require(path .. '.arena_hud')
require(path .. '.sound_lab')

access.enabled = true
access.speech_enabled = true
access.last_message = nil
access.history = {}

local describe = access.describe

local last_text, last_time = nil, -100
local watched_screen, watched_paused, watched_modal, watched_tutorial, watched_credits = nil, nil, nil, nil, nil
local watched_gold, watched_locked = nil, nil
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

  text = describe.speech(text)
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
  default('access_beacons', true)

  access.enabled = state.access_enabled
  access.speech_enabled = state.access_speech
  access.nav.enabled = state.access_enabled
  access.audio.enabled = state.access_cues
  access.audio.volume = state.access_cue_volume
  access.hud.sonar_enemies = state.access_sonar_enemies
  access.hud.sonar_walls = state.access_sonar_walls
  access.hud.sonar_pickups = state.access_sonar_pickups
  access.hud.beacons = state.access_beacons
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
  state.access_beacons = access.hud.beacons
  pcall(system.save_state)
end
access.save_settings = save_settings


-- ------------------------------------------------------------ shop helpers --

-- The three cards for sale, numbered the way the buy keys are.
local function describe_cards(st)
  local cards = {}
  for i = 1, 3 do
    local card = st.cards and st.cards[i]
    if card and card.unit and not card.dead then
      local line = i .. ', ' .. describe.character(card.unit) .. ', ' .. tostring(card.cost or '?') .. ' gold'
      if card.owned and card.owned_n then line = line .. ', owned' end
      table.insert(cards, line .. ', ' .. describe.classes_of(card.unit))
    end
  end
  if #cards == 0 then return 'Nothing for sale.' end
  return 'For sale: ' .. table.concat(cards, '. ') .. '.'
end


local function describe_shop(st)
  local parts = {'Shop'}
  table.insert(parts, 'round ' .. tostring(st.level) .. ' of ' .. 25 * ((st.loop or 0) + 1))
  local kind = describe.round_type(st.level, st.loop)
  if kind then table.insert(parts, kind .. ' next') end
  if (current_new_game_plus or 0) > 0 then table.insert(parts, 'new game plus ' .. current_new_game_plus) end
  table.insert(parts, tostring(gold) .. ' gold')
  table.insert(parts, 'party ' .. tostring(#(st.units or {})) .. ' of ' .. tostring(max_units))
  table.insert(parts, 'shop level ' .. tostring(st.shop_level))
  if st.locked then table.insert(parts, 'shop locked') end
  local summary = table.concat(parts, ', ') .. '. ' .. describe_cards(st)
  summary = summary .. ' Press 1, 2 or 3 to buy, tab and the arrow keys browse, R rerolls, G starts the round.'
  if #(st.units or {}) == 0 then
    summary = summary .. ' Your party is empty, so buy a hero first. F5 opens the guide.'
  end
  return summary
end


-- The four item cards after a hard round, numbered the way the pick keys are.
local function announce_passive_choice(st, prefix)
  local names = {}
  for _, card in ipairs(st.cards or {}) do
    if card and not card.dead and card.passive then
      table.insert(names, tostring(card.card_i or (#names + 1)) .. ', ' .. describe.passive_name(card.passive))
    end
  end
  local n = #names
  local cost = '5 gold'
  if st.ui and st.ui.objects then
    for _, o in ipairs(st.ui.objects) do
      if RerollButton and o.is and o:is(RerollButton) and not o.dead and o.free_reroll then cost = 'free' end
    end
  end
  access.say((prefix or '') .. 'Choose one item. ' .. table.concat(names, '. ') ..
    '. Press 1 to ' .. math.max(n, 1) .. ' to take one, the arrow keys hear what each does, tab moves on to the reroll and your build. R rerolls, ' .. cost .. '.',
    {interrupt = true, priority = true})
end


-- Selling goes through the game's own click handler, which knows the price
-- but not what was sold. The navigation notes the name just before it clicks.
local pending_sale = nil

function access.pending_sale(name)
  pending_sale = {name = name, time = love.timer.getTime()}
end

local function take_pending_sale()
  local sale = pending_sale
  pending_sale = nil
  if sale and (love.timer.getTime() - sale.time) < 1 then return sale.name end
  return nil
end


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
      local spoken = describe.lines(text)
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

  -- A mine is a blinking dot that turns into a ring of shots two seconds later.
  if ExploderMine then
    local mine_init = ExploderMine.init
    ExploderMine.init = function(self, args)
      local result = mine_init(self, args)
      if access.enabled then pcall(access.hud.on_mine, self) end
      return result
    end
  end

  -- Every boss attack is drawn as lightning from the boss to its targets.
  if LightningLine then
    local lightning_init = LightningLine.init
    LightningLine.init = function(self, args)
      local result = lightning_init(self, args)
      if access.enabled and args and args.src and args.src.boss then
        pcall(access.hud.on_boss_attack, args.src, args.color)
      end
      return result
    end
  end

  -- Bouncing off a wall turns the snake around; the new heading is spoken.
  if Player and Player.on_collision_enter then
    local collision = Player.on_collision_enter
    Player.on_collision_enter = function(self, other, contact)
      local result = collision(self, other, contact)
      if access.enabled and self.leader and Wall and other and other.is and other:is(Wall) then
        pcall(access.hud.on_wall_bounce, self)
      end
      return result
    end
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

  -- Arena:quit hands out the round's gold on its way through, and the gold
  -- hook below queues that line. "Arena clear" has to go first, or it would
  -- cut the gold breakdown off.
  local arena_quit = Arena.quit
  Arena.quit = function(self, ...)
    if access.enabled and not self.quitting and not self.died then pcall(access.hud.on_clear, self) end
    return arena_quit(self, ...)
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
      local name = describe.character(character)
      if bought then
        local level_after = 0
        for _, u in ipairs(self.units or {}) do
          if u.character == character then level_after = u.level end
        end
        local line = name .. ' bought for ' .. (gold_before - gold) .. ' gold'
        if level_after > level_before and level_before > 0 then
          line = line .. '. ' .. name .. ' is now level ' .. level_after
        elseif level_before > 0 then
          line = line .. ', copy added'
        end
        access.say(line .. '. ' .. gold .. ' gold left, party ' ..
          #(self.units or {}) .. ' of ' .. tostring(max_units), {interrupt = true, priority = true})
        access._spoken_gold = gold
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
      local what = take_pending_sale()
      access.say((what and (what .. ' sold for ') or 'sold for ') .. tostring(amount) .. ' gold, ' ..
        tostring(gold) .. ' gold total', {interrupt = true, priority = true})
      access._spoken_gold = gold
    end
    return result
  end

  -- A reroll replaces all three cards at once, silently.
  local set_cards = BuyScreen.set_cards
  BuyScreen.set_cards = function(self, shop_level, dont_spawn_effect, first_call)
    local result = set_cards(self, shop_level, dont_spawn_effect, first_call)
    if access.enabled and not first_call then
      access.say('Rerolled. ' .. describe_cards(self), {interrupt = true, priority = true})
    end
    return result
  end

  -- Likewise the four item cards after a hard round.
  local set_passives = Arena.set_passives
  Arena.set_passives = function(self, from_reroll, ...)
    local result = set_passives(self, from_reroll, ...)
    if access.enabled and from_reroll and self.choosing_passives then
      pcall(announce_passive_choice, self, 'Rerolled. ')
    end
    return result
  end

  -- Taking an item hands the other three back to the pool; the one kept is
  -- the card that is not returned.
  local restore = Arena.restore_passives_to_pool
  Arena.restore_passives_to_pool = function(self, j, ...)
    if access.enabled and j and j > 0 and self.cards and self.cards[j] and self.cards[j].passive then
      access.say(describe.passive_name(self.cards[j].passive) .. ' taken', {interrupt = true, priority = true})
    end
    return restore(self, j, ...)
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

local function announce_screen(st, previous)
  if st == nil then return end
  local prefix = ''
  if first_announcement then
    first_announcement = false
    -- Accessibility being on by default is the right call (see load_settings),
    -- but a player who does not want it deserves to be told how to stop it.
    -- Once they have touched any accessibility setting, drop the reminder.
    prefix = state.access_configured and 'SNKRX. '
      or 'SNKRX. Accessibility is on. Press F2 to turn it off, F1 for the keys, F5 for the guide. '
  end
  if st.is and st:is(MainMenu) then
    access.say(prefix .. 'Main menu. Tab moves between groups, the arrow keys move within one, enter chooses. Learn sounds plays every sound in the game with a description of each. F1 for the accessibility keys.',
      {interrupt = true})
  elseif st.is and st:is(BuyScreen) then
    -- Coming out of a fight, the round's gold breakdown may still be being
    -- read; queue behind it rather than cut it off.
    local from_arena = previous and previous.is and previous:is(Arena)
    access.say(prefix .. describe_shop(st), {interrupt = not from_arena})
  elseif prefix ~= '' then
    access.say(prefix .. 'Press F1 for the accessibility keys.', {interrupt = true})
  end
  -- The arena announces itself from Arena.on_enter, which fires earlier and
  -- knows about waves and elites.
end


local function watch_shop(st)
  -- Gold changes that no hook has already spoken: shop experience, item
  -- experience, selling a shop level.
  if watched_gold == nil then watched_gold = gold; access._spoken_gold = gold end
  if gold ~= watched_gold then
    watched_gold = gold
    if access._spoken_gold ~= gold then
      access._spoken_gold = gold
      access.say(tostring(gold) .. ' gold', {interrupt = false})
    end
  end

  local locked = st.locked and true or false
  if watched_locked == nil then watched_locked = locked end
  if locked ~= watched_locked then
    watched_locked = locked
    access.say(locked and 'shop locked, these cards stay for next round' or 'shop unlocked',
      {interrupt = true, priority = true})
  end
end


local function watch_screen()
  local st = main and main.current
  if st ~= watched_screen then
    local previous = watched_screen
    watched_screen = st
    watched_paused, watched_modal, watched_tutorial, watched_credits = nil, nil, nil, nil
    watched_gold, watched_locked = nil, nil
    announce_screen(st, previous)
    return
  end
  if not st then return end

  -- The game's flags start out nil and become false once cleared, so every
  -- one of them is normalised before comparing.
  local paused = st.paused and true or false
  if watched_paused == nil then watched_paused = paused end
  if paused ~= watched_paused then
    watched_paused = paused
    if paused then
      access.say('Options. Tab and shift tab move between groups of settings, the arrow keys move within a group, enter changes a setting and backspace changes it the other way. F1 for the accessibility keys.',
        {interrupt = true})
    else
      access.say('resumed', {interrupt = true})
    end
  end

  -- The shop's guide is a wall of text with two diagrams and no interactive
  -- parts, so nothing else here would ever read it out.
  local tutorial = st.in_tutorial and true or false
  if watched_tutorial == nil then watched_tutorial = tutorial end
  if tutorial ~= watched_tutorial then
    watched_tutorial = tutorial
    if tutorial then
      pcall(access.guide.speak, st)
    else
      access.say('guide closed', {interrupt = true})
    end
  end

  if st.is and st:is(BuyScreen) and not st.transitioning then watch_shop(st) end

  local credits = st.in_credits and true or false
  if watched_credits == nil then watched_credits = credits end
  if credits ~= watched_credits then
    watched_credits = credits
    if credits then
      access.say('Credits. Tab moves between groups of links, the arrow keys move within a group, escape closes.', {interrupt = true})
    else
      access.say('credits closed', {interrupt = true})
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
      pcall(announce_passive_choice, st)
    elseif modal == 'won' then
      local ng = current_new_game_plus or 0
      access.say('Congratulations, you beat the game. Round ' .. tostring(st.level) .. ' cleared. ' ..
        'New game plus ' .. ng .. ' is unlocked. The arrow keys browse what to do next: loop continues this run ' ..
        'at higher difficulty with a bigger party, new game plus starts a fresh harder run, and the credits. ' ..
        'Tab moves on to the links and to the build you finished with. R restarts from round 1.',
        {interrupt = false, priority = true})
    end
  end
end


-- ------------------------------------------------------------------- help --

local HELP = {
  'Accessibility keys.',
  'Anywhere: F1 this help. F2 accessibility off or on. F3 speech on or off. F4 cue volume. F5 the game guide. M repeats the last message. Comma and full stop step back and forward through everything that has been said.',
  'Menus and shop: controls are gathered into groups, and the group is named as you enter it. Tab and shift tab move to the next and previous group, and the arrow keys move within the group you are in, wrapping round at its ends. Home and end jump to the first and last control on the screen, enter or space chooses, and backspace is the secondary action such as selling. Where the arrow keys are steering the snake, tab moves one control at a time instead.',
  'Main menu: learn sounds opens a list of every sound in the game, with a description of each one and enter to hear it.',
  'Shop only: 1, 2 and 3 buy a card, R rerolls the shop, G starts the round, page up and page down move the selected party member forward or back in the snake, shift backspace sells one spare copy of the selected hero. Q reads the round and gold, H reads the party, Y reads your build.',
  'Arena: A or left arrow turns left, D or right arrow turns right. Q status, W position and heading, T enemies, G loose gold and healing orbs, H every hero\'s health, Y your build. Escape opens the options, where R restarts the run.',
  'Arena sound: the nearest enemy, the elite, the nearest gold and the nearest healing orb each sound without stopping for as long as they are there, panned to where they are and rising as they get closer. The enemy and the elite hold a steady tone; gold ticks like a flipped coin and an orb glows with a soft chime, so the two things worth chasing never sound like the two things worth avoiding. Each is bright when the thing is in front of you and dull when it is behind, so turning towards something is heard as it brightening. Turn until it is bright and centred and you are heading straight at it.',
  'Other arena sounds: a fast rattle is an enemy touching you, a ping to one side is a second enemy closing from the other side, a buzz is a shot flying at you, a fluttering tone is a headbutter winding up, a sharp tick is a mine, a wooden knock is the wall you are heading into and it gets faster as you close in, a soft low pad on one side means you are running along that wall, and a wobbling tone marks a spot where enemies are about to appear.',
  'Arena toggles: F enemy sonar, V wall sonar, C pickup sonar, B holding tones or separate pings.',
  'Choosing an item: 1 to 4 take a card, R rerolls, the arrow keys read the four cards and tab moves on to the reroll and to your build.',
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


-- F5: in the shop this opens the game's own guide screen, which is then read
-- with its diagrams described; anywhere else the same guide is simply spoken.
local function open_guide()
  local st = main and main.current
  if st and st.is and st:is(BuyScreen) and not st.paused and not st.transitioning then
    if st.in_tutorial then
      pcall(access.guide.speak, st)
    elseif st.tutorial_button and st.tutorial_button.action then
      pcall(st.tutorial_button.action, st.tutorial_button)
    else
      pcall(access.guide.speak, nil)
    end
  else
    pcall(access.guide.speak, nil)
  end
end


local function handle_hotkeys()
  -- The shop tests Escape twice in one frame: once to close the guide, then
  -- again, with the guide now closed, to open the options. Close the guide
  -- here and swallow the key so that only the first half happens.
  if pressed('escape') then
    local st = main and main.current
    if st and st.in_tutorial and st.quit_tutorial then
      pcall(st.quit_tutorial, st)
      input.escape.pressed = false
      return true
    end
  end

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

  if pressed('f5') then open_guide() return true end

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
  if pressed('b') then
    access.hud.beacons = toggle_setting(access.hud.beacons, 'tracking tones',
      'on, enemies and pickups hold a tone you can steer by',
      'off, back to separate pings')
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

  local hooks_ok, err = pcall(install_hooks)
  if not hooks_ok then print('[accessibility] hooks failed: ' .. tostring(err)) end
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
    -- Last, so that beacons aimed this frame are heard this frame, and so that
    -- fades keep running on a screen that has no sonar of its own.
    access.audio.update(dt)
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

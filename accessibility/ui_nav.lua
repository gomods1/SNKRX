-- Keyboard navigation for every menu, shop and card screen in the game.
--
-- SNKRX's interface is entirely mouse-hover driven: widgets light up in
-- GameObject:update_game_object when the pointer overlaps their shape, and each
-- one raises its own tooltip from on_mouse_enter. Rather than reimplement all
-- of that, this module drives the real pointer. Focus moves with Tab between
-- groups of controls and with the arrow keys inside one, the OS cursor is
-- warped onto the focused widget, and the engine's own hover logic fires
-- untouched. Enter and Backspace inject a left or right click for the frame.
--
-- The payoff is that everything keeps working: tooltips, highlights, sell
-- prices, class previews, the lot. Nothing in the game had to learn about
-- keyboards. The pointer is only ever moved once the player has pressed a
-- navigation key, so a sighted player using the mouse is never fought over.

local nav = {}
access.nav = nav

nav.enabled = true
nav.items = {}      -- every focusable widget on screen, in reading order
nav.groups = {}     -- {name = ..., first = ..., last = ...} runs over nav.items
nav.index = 0
nav.focus = nil

local signature = nil
local pending = nil          -- {button = 'm1'|'m2', frames = n}
local release_next = nil     -- button to release on the following frame
local clicked = nil          -- the widget the last synthetic click landed on
local last_screen = nil


local function is(o, class_name)
  local class = _G[class_name]
  return class and o.is and o:is(class)
end


-- input:bind_all covers most keys but not every one we want.
local function pressed(key)
  local action = input[key]
  return action and action.pressed
end

local function down(key)
  local action = input[key]
  return action and action.down
end


-- Child widgets whose information is already folded into their parent's
-- description. Stopping on them would triple the number of Tab presses needed
-- to cross the shop for no extra information.
local function is_redundant(o)
  if is(o, 'CharacterIcon') then return true end
  if is(o, 'ClassIcon') and o.parent and is(o.parent, 'ShopCard') then return true end
  if is(o, 'CharacterPart') and o.parent and is(o.parent, 'CharacterPart') then return true end
  return false
end


-- ---------------------------------------------------------------- groups --

-- Every screen lays its controls out in groups, and the keyboard follows that
-- layout: Tab and shift Tab step to the next and previous group, the arrow keys
-- move within the group you are in, and the group is announced as you enter it,
-- the way a screen reader announces a new landmark. Tab used to visit every
-- control on the screen in turn, which on the shop meant twenty-odd presses to
-- cross it and no sense of where you were.
--
-- A layout is the list of groups in the order Tab visits them, and the first
-- group whose match accepts a widget claims it. Whatever no group claims falls
-- into a final "other" group rather than off the end of the keyboard: nothing
-- on screen may become unreachable because a layout forgot about it.

local function classes(...)
  local names = {...}
  return function(o)
    for _, name in ipairs(names) do
      if is(o, name) then return true end
    end
    return false
  end
end


-- Matches the widgets a screen keeps a named reference to. Grouping the options
-- by the game's own field names rather than by button text means rewording a
-- button cannot quietly drop it into the wrong group. A field holding a list of
-- widgets, as the accessibility row does, matches any widget in the list.
local function named(...)
  local fields = {...}
  return function(o, st)
    for _, field in ipairs(fields) do
      local value = st[field]
      if value == o then return true end
      if type(value) == 'table' and not value.is then
        for _, widget in ipairs(value) do
          if widget == o then return true end
        end
      end
    end
    return false
  end
end


-- Widgets the accessibility layer builds itself state their own group.
local function declares(name)
  return function(o) return o.a11y_group == name end
end


-- The credits colour-code their links by what the person or project did, which
-- is the only thing on that screen that says where one list ends.
local function coloured(color)
  return function(o) return o.bg_color == color end
end


local function is_link(o) return access.describe.is_link(o) end
local function anything() return true end


-- Reads as "a button, but not one of those".
local function except(match, excluded)
  return function(o, st) return match(o, st) and not excluded(o, st) end
end


local LAYOUTS = {}

-- The shop lays its widgets out in columns that interleave when read strictly
-- top to bottom: a party member, then a class icon, then an item, then another
-- party member. Named groups are what turn that into something you can hold a
-- mental map of.
LAYOUTS.shop = {
  {name = 'shop cards',    match = classes('ShopCard')},
  {name = 'party',         match = classes('CharacterPart')},
  {name = 'classes',       match = classes('ClassIcon')},
  {name = 'items',         match = classes('ItemCard')},
  {name = 'shop controls', match = classes('RerollButton', 'LockButton', 'LevelButton', 'Button')},
  {name = 'start',         match = classes('GoButton')},
}

LAYOUTS.main_menu = {
  {name = 'menu',  match = except(anything, is_link)},
  {name = 'links', match = is_link},
}

-- The options are one row of buttons per subject, drawn down the screen in this
-- order. Grouping is what makes the screen navigable at all: it is by some way
-- the longest list of controls in the game.
LAYOUTS.options = {
  {name = 'accessibility', match = named('access_buttons')},
  {name = 'this run',      match = named('resume_button', 'restart_button')},
  {name = 'volume',        match = named('sfx_button', 'music_button')},
  {name = 'game',          match = named('mouse_button', 'dark_transition_button', 'run_timer_button')},
  {name = 'video',         match = named('video_button_1', 'video_button_2', 'video_button_3', 'video_button_4')},
  {name = 'effects',       match = named('screen_shake_button', 'cooldown_snake_button',
                                         'arrow_snake_button', 'screen_movement_button')},
  {name = 'new game plus', match = named('ng_plus_minus_button', 'ng_plus_plus_button')},
  {name = 'leaving',       match = named('main_menu_button', 'quit_button')},
}

-- The same screen opens on the main menu, where there is no run behind it and
-- the button that would have resumed one closes the options instead.
LAYOUTS.menu_options = {}
for i, group in ipairs(LAYOUTS.options) do
  LAYOUTS.menu_options[i] = group.name == 'this run' and {name = 'back', match = group.match} or group
end

-- The item choice after a hard round: four cards, the reroll, and the build
-- they are being added to, which is reference material and comes after.
LAYOUTS.passives = {
  {name = 'items on offer', match = classes('PassiveCard')},
  {name = 'controls',       match = classes('RerollButton')},
  {name = 'your party',     match = classes('CharacterPart')},
  {name = 'your items',     match = classes('ItemCard')},
}

LAYOUTS.died = {
  {name = 'what next',  match = classes('Button', 'RestartButton')},
  {name = 'your party', match = classes('CharacterPart')},
  {name = 'your items', match = classes('ItemCard')},
}

LAYOUTS.won = {
  {name = 'what next',  match = except(classes('Button', 'RestartButton'), is_link)},
  {name = 'links',      match = is_link},
  {name = 'your party', match = classes('CharacterPart')},
  {name = 'your items', match = classes('ItemCard')},
}

LAYOUTS.credits = {
  {name = 'people',      match = except(coloured('bg'), named('close_button'))},
  {name = 'libraries',   match = coloured('blue')},
  {name = 'music',       match = coloured('green')},
  {name = 'sound',       match = coloured('yellow')},
  {name = 'playtesters', match = coloured('red')},
  {name = 'close',       match = named('close_button')},
}

-- The guide's two diagrams, then the button that closes it.
LAYOUTS.tutorial = {
  {name = 'levelling example', match = classes('TutorialCharacterPart')},
  {name = 'class example',     match = classes('TutorialClassIcon')},
  {name = 'close',             match = classes('Button')},
}

LAYOUTS.sound_lab = {
  {name = 'sounds',   match = declares('sounds')},
  {name = 'controls', match = declares('controls')},
}

-- The tutorial screen, which is one list of enemies and then one briefing at
-- a time. Both name their own groups, so both layouts are the same two lines.
LAYOUTS.tutorial_menu = {
  {name = 'lessons',  match = declares('lessons')},
  {name = 'controls', match = declares('controls')},
}
LAYOUTS.tutorial_brief = LAYOUTS.tutorial_menu

-- What is offered at the end of a tutorial run: the next enemy, this one
-- again, and the way out.
LAYOUTS.lesson_over = {
  {name = 'what next', match = classes('Button')},
}


-- A widget may name its own group, the way it may state its own label; failing
-- that the layout decides, and failing that it is still reachable as "other".
local function group_of(st, layout, o)
  local name = o.a11y_group
  if not name then
    for _, group in ipairs(layout) do
      if group.match(o, st) then name = group.name break end
    end
  end
  name = name or 'other'
  for i, group in ipairs(layout) do
    if group.name == name then return i, name end
  end
  return #layout + 1, name
end


-- Returns the groups to look in and a key naming the situation: the guide, the
-- credits, one of the modals, or the screen itself. Focus is kept separately
-- per situation, and the key also chooses the layout above.
local function collect_groups(st)
  if st.in_tutorial and st.tutorial then return {st.tutorial}, 'tutorial' end
  -- The accessibility layer's own screen: it freezes everything behind it.
  if st.in_sound_lab and st.sound_lab then return {st.sound_lab}, 'sound_lab' end
  -- The tutorial screen does the same. Its two pages are separate situations
  -- so that focus is remembered per page rather than carried across.
  if st.in_tutorial_menu and st.tutorial_menu then
    return {st.tutorial_menu}, (st.tutorial_page == 'brief') and 'tutorial_brief' or 'tutorial_menu'
  end
  -- The credits sit in a group of their own and freeze every other button.
  if st.in_credits and st.credits then return {st.credits}, 'credits' end
  -- While a modal is up the screen behind it is inert, so only offer the modal.
  if st.paused then
    return st.ui and {st.ui} or {}, (st.is and st:is(MainMenu)) and 'menu_options' or 'options'
  end
  if st.choosing_passives then return st.ui and {st.ui} or {}, 'passives' end
  -- Checked before `died`, because a lost tutorial run sets that flag too and
  -- what it offers is a retry rather than the end of a run.
  if st.lesson_result then return st.ui and {st.ui} or {}, 'lesson_over' end
  if st.died then return st.ui and {st.ui} or {}, 'died' end
  if st.won then return st.ui and {st.ui} or {}, 'won' end
  local out = {}
  for _, name in ipairs({'main', 'main_ui', 'effects', 'ui'}) do
    local g = st[name]
    if g and g.objects then table.insert(out, g) end
  end
  if st.is and st:is(BuyScreen) then return out, 'shop' end
  if st.is and st:is(MainMenu) then return out, 'main_menu' end
  return out, 'screen'
end


function nav.collect()
  local st = main and main.current
  if not st or st.transitioning then return {}, 'none' end

  local groups, context = collect_groups(st)
  local layout = LAYOUTS[context] or {}
  local items = {}
  for _, group in ipairs(groups) do
    for _, o in ipairs(group.objects) do
      if o.interact_with_mouse and o.shape and not o.dead and not o.hidden and not is_redundant(o) then
        table.insert(items, o)
      end
    end
  end

  for _, o in ipairs(items) do
    o.a11y_group_order, o.a11y_group_name = group_of(st, layout, o)
    -- Reading order within the group: top to bottom in bands, then left to
    -- right inside a band. The 14 pixel band matches the game's own row
    -- spacing closely enough that visually-aligned widgets stay together.
    --
    -- Two screens state their order outright instead. A list laid out in
    -- columns says so with a11y_order, because pixel positions would read it
    -- across rather than down; and the item-choice cards are drawn staggered,
    -- so adjacent cards sit at different heights and would read as 1, 3, 2, 4.
    -- Those carry card_i, which is also what the number keys use.
    if o.a11y_order then
      o.a11y_row, o.a11y_col = o.a11y_order, 0
    elseif o.card_i then
      o.a11y_row, o.a11y_col = 0, o.card_i
    else
      o.a11y_row, o.a11y_col = math.floor(o.y / 14), o.x
    end
  end

  table.sort(items, function(a, b)
    if a.a11y_group_order ~= b.a11y_group_order then return a.a11y_group_order < b.a11y_group_order end
    -- Groups no layout named share one order, so their names break the tie:
    -- that is what stops two of them from interleaving into a single run.
    if a.a11y_group_name ~= b.a11y_group_name then return a.a11y_group_name < b.a11y_group_name end
    if a.a11y_row ~= b.a11y_row then return a.a11y_row < b.a11y_row end
    if a.a11y_col ~= b.a11y_col then return a.a11y_col < b.a11y_col end
    return tostring(a.id) < tostring(b.id)
  end)
  return items, context
end


-- Groups are the runs of neighbouring items that named the same group. Building
-- them from the sorted list rather than from the layout means a group with
-- nothing in it -- the classes before you own any, the items before you find
-- one -- simply is not there to be tabbed into.
local function build_groups(items)
  local groups = {}
  for i, o in ipairs(items) do
    local last = groups[#groups]
    if last and last.name == o.a11y_group_name then
      last.last = i
    else
      table.insert(groups, {name = o.a11y_group_name, first = i, last = i})
    end
  end
  return groups
end


local function adopt(items)
  nav.items = items
  nav.groups = build_groups(items)
end


function nav.group_at(i)
  for gi, group in ipairs(nav.groups) do
    if i >= group.first and i <= group.last then return gi end
  end
  return 0
end


local function shape_centre(o)
  if o.shape and o.shape.x and o.shape.y then return o.shape.x, o.shape.y end
  return o.x, o.y
end


local function warp_to(o)
  if not o then return end
  local wx, wy = shape_centre(o)
  local cam = o.group and o.group.camera
  local lx, ly = wx, wy
  if cam and cam.get_local_coords then lx, ly = cam:get_local_coords(wx, wy) end
  pcall(love.mouse.setPosition, lx * sx, ly * sy)
end


local spoken_group = nil

function nav.speak_focus(interrupt)
  local o = nav.focus
  if not o then return end
  local label, detail = access.describe.focusable(o)
  if not label then return end

  -- Announce the group only when crossing into a new one, like a landmark.
  local prefix = ''
  if o.a11y_group_name and o.a11y_group_name ~= spoken_group then
    prefix = o.a11y_group_name .. '. '
  end
  spoken_group = o.a11y_group_name

  -- Where you are inside the group, which is what the arrow keys move through.
  -- "1 of 1" would only be noise, so a group of one says nothing.
  local position = ''
  local group = nav.groups[nav.group_at(nav.index)]
  if group and group.last > group.first then
    position = ', ' .. (nav.index - group.first + 1) .. ' of ' .. (group.last - group.first + 1)
  end
  access.say(prefix .. label .. position, {interrupt = interrupt ~= false})
  if detail then access.say(detail, {interrupt = false}) end
end


function nav.set_focus(i, speak)
  if #nav.items == 0 then
    nav.focus, nav.index = nil, 0
    return
  end
  i = ((i - 1) % #nav.items) + 1
  nav.index = i
  nav.focus = nav.items[i]
  warp_to(nav.focus)
  if speak ~= false then nav.speak_focus() end
end


-- One step with the arrow keys: within the group, wrapping at its ends. `across`
-- lets the step leave the group, which is what Tab falls back to on a screen
-- with nothing to move between.
function nav.move(delta, across)
  if #nav.items == 0 then
    access.say('nothing to select here', {interrupt = true})
    return
  end
  if nav.index == 0 then
    nav.set_focus(delta > 0 and 1 or #nav.items)
    return
  end
  local group = not across and nav.groups[nav.group_at(nav.index)]
  if not group then
    nav.set_focus(nav.index + delta)
    return
  end
  local size = group.last - group.first + 1
  local i = ((nav.index - group.first + delta) % size) + group.first
  -- Coming back round to the start of a group re-announces its name, so that a
  -- list repeating itself is never mistaken for the screen repeating itself.
  if (delta > 0 and i <= nav.index) or (delta < 0 and i >= nav.index) then spoken_group = nil end
  nav.set_focus(i)
end


-- Tab: on to the first control of the next group, the way a screen reader jumps
-- between landmarks. With one group or none there is nothing to jump between,
-- so Tab walks the controls themselves rather than doing nothing.
function nav.move_group(delta)
  if #nav.items == 0 or #nav.groups <= 1 then
    nav.move(delta, true)
    return
  end
  local target
  if nav.index == 0 then
    target = delta > 0 and 1 or #nav.groups
  else
    target = ((nav.group_at(nav.index) - 1 + delta) % #nav.groups) + 1
  end
  spoken_group = nil
  nav.set_focus(nav.groups[target].first)
end


-- Home and End cross the whole screen, so the group they land in is worth
-- naming even if it is the one already being spoken.
function nav.jump(i)
  spoken_group = nil
  nav.set_focus(i)
end


-- Party order matters a lot in SNKRX: unit 1 is the head and takes the hits.
-- Dragging with a mouse is not an option, so reordering gets its own verbs.
local function reorder_party(o, delta)
  local parent = o.parent
  if not parent or not parent.units or not parent.characters then return false end
  local from = o.i
  if not from then return false end
  local to = from + delta
  if to < 1 or to > #parent.units then
    access.say('already at the ' .. (delta < 0 and 'front' or 'back') .. ' of the party', {interrupt = true})
    return true
  end
  parent.units[from], parent.units[to] = parent.units[to], parent.units[from]
  parent.characters[from], parent.characters[to] = parent.characters[to], parent.characters[from]
  parent.characters[from].i, parent.characters[to].i = from, to
  if system and system.save_run then
    pcall(system.save_run, parent.level, parent.loop, gold, parent.units, parent.passives,
      parent.shop_level, parent.shop_xp, run_passive_pool, locked_state)
  end
  access.audio.play('gold', 0, 1 + delta * 0.15, 0.5)
  access.say(access.describe.character(o.character, o.level) .. ' moved to slot ' .. to, {interrupt = true})
  return true
end


-- Selling a single spare copy is a right click on one of the small tiles
-- beside a party member. Those tiles are skipped by Tab (see is_redundant), so
-- the sale is done here directly, the same way the tile's own click does it.
local function sell_reserve(o)
  local parent = o.parent
  if not parent or not parent.units or not o.i then return false end
  local part = o.parts and o.parts[#o.parts]
  if not part or part.dead then
    access.say('no spare copies to sell', {interrupt = true})
    return true
  end
  local ok, err = pcall(function()
    local unit = parent.units[o.i]
    access.pending_sale(access.describe.character(part.character, part.level) .. ' spare copy')
    parent:gain_gold(part:get_sale_price())
    unit.reserve[part.level] = unit.reserve[part.level] - 1
    part:die()
    parent:set_party_and_sets()
    parent:refresh_cards()
    if system and system.save_run then
      system.save_run(parent.level, parent.loop, gold, parent.units, parent.passives,
        parent.shop_level, parent.shop_xp, run_passive_pool, locked_state)
    end
  end)
  if not ok then print('[accessibility] sell spare copy failed: ' .. tostring(err)) end
  return true
end


function nav.activate(secondary)
  local o = nav.focus
  if not o then
    access.say('press tab to choose something first', {interrupt = true})
    return
  end
  -- A left click on a party unit begins a mouse drag that we can never finish
  -- from the keyboard, so it is replaced by the explicit reorder keys.
  if is(o, 'CharacterPart') and not secondary and not o.cant_click then
    access.say('use page up and page down to reorder, backspace to sell', {interrupt = true})
    return
  end
  -- Selling says what was sold, which the game's own gold line cannot know.
  if secondary and not o.cant_click then
    if is(o, 'CharacterPart') then
      access.pending_sale(access.describe.character(o.character, o.level))
    elseif is(o, 'ItemCard') then
      access.pending_sale(access.describe.passive_name(o.passive))
    end
  end
  pending = {button = secondary and 'm2' or 'm1', frames = 0}
end


-- Injecting a synthetic click has to wait until the engine has registered the
-- warped pointer, otherwise the widget's own "am I hovered" guard rejects it.
local function service_click()
  if release_next then
    input[release_next].released = true
    input[release_next].down = false
    release_next = nil
  end
  if not pending then return end
  local o = nav.focus
  if not o or o.dead then pending = nil return end
  pending.frames = pending.frames + 1
  if not (o.colliding_with_mouse or o.selected) and pending.frames < 4 then
    warp_to(o)
    return
  end
  o.selected = true
  clicked = o
  local button = pending.button
  input[button].pressed = true
  input[button].down = true
  release_next = button
  pending = nil
end


-- Forcing `selected` on is what makes the click land, but the engine only ever
-- clears that flag from a mouse-exit, and a widget that was never really
-- hovered never gets one. Left alone it stays lit for the rest of the screen's
-- life, which on a list you activate repeatedly means everything you have
-- pressed glows at once. Clear it once focus has moved on and the real pointer
-- is not on it either, so a mouse user is still never fought over.
local function clear_stale_highlight()
  if not clicked then return end
  if clicked == nav.focus then return end
  if not clicked.dead and clicked.colliding_with_mouse then return end
  if not clicked.dead and clicked.on_mouse_exit then pcall(clicked.on_mouse_exit, clicked) end
  clicked = nil
end


local last_context = nil
local saved_focus = {}   -- context key -> id of the widget that had focus there

function nav.update(dt)
  if not nav.enabled then return end

  local st = main and main.current
  if st ~= last_screen then
    last_screen = st
    adopt({})
    nav.index, nav.focus, signature = 0, nil, nil
    pending, release_next, clicked, spoken_group = nil, nil, nil, nil
    last_context, saved_focus = nil, {}
  end

  local items, context = nav.collect()
  local sig = tostring(#items)
  for _, o in ipairs(items) do sig = sig .. '|' .. tostring(o.id) end

  if context ~= last_context then
    -- The guide, the options or a card screen has opened or closed. Remember
    -- where the focus was in the situation being left and put it back in the
    -- one being entered, silently: the screen announces itself, and speaking
    -- a widget here would cut that announcement off.
    if last_context then saved_focus[last_context] = nav.focus and nav.focus.id or nil end
    last_context = context
    signature = sig
    adopt(items)
    nav.index, nav.focus = 0, nil
    local want = saved_focus[context]
    if want then
      for i, o in ipairs(items) do
        if o.id == want then nav.index, nav.focus = i, o break end
      end
    end
    spoken_group = nil
    pending, release_next = nil, nil
  elseif sig ~= signature then
    signature = sig
    local previous, previous_index = nav.focus, nav.index
    adopt(items)

    local found = 0
    if previous then
      for i, o in ipairs(items) do
        if o.id == previous.id then found = i break end
      end
    end

    if found > 0 then
      nav.index, nav.focus = found, items[found]
    elseif previous and #items > 0 then
      -- The focused widget was bought, sold or rerolled away. Land on whatever
      -- took its place rather than dumping the player back at the top, and
      -- queue its name behind the line that says what just happened to it.
      nav.index = math.max(1, math.min(previous_index, #items))
      nav.focus = items[nav.index]
      warp_to(nav.focus)
      nav.speak_focus(false)
    else
      nav.index, nav.focus = 0, nil
    end
  else
    adopt(items)
  end

  service_click()
  clear_stale_highlight()
end


-- True when arrow keys should steer the menu rather than the snake.
function nav.arrows_available()
  local st = main and main.current
  if not st then return false end
  if is(st, 'Arena') and not (st.paused or st.choosing_passives or st.died or st.won or st.lesson_result) then
    return false
  end
  return #nav.items > 0
end


function nav.handle_input()
  if not nav.enabled then return false end

  local shift = down('lshift') or down('rshift')

  if pressed('tab') then
    -- Tab is the group key. Where the arrow keys are busy steering the snake
    -- they cannot move within a group, so there Tab goes back to walking the
    -- controls one at a time and nothing on screen is out of reach.
    if nav.arrows_available() then
      nav.move_group(shift and -1 or 1)
    else
      nav.move(shift and -1 or 1, true)
    end
    return true
  end

  if nav.arrows_available() then
    if pressed('down') or pressed('right') then nav.move(1) return true end
    if pressed('up') or pressed('left') then nav.move(-1) return true end
    if pressed('home') then nav.jump(1) return true end
    if pressed('end') then nav.jump(#nav.items) return true end
  end

  if #nav.items > 0 then
    local o = nav.focus
    if o and is(o, 'CharacterPart') and not o.cant_click then
      if pressed('pageup') then reorder_party(o, -1) return true end
      if pressed('pagedown') then reorder_party(o, 1) return true end
    end
    if pressed('return') or pressed('kpenter') or pressed('space') then
      nav.activate(false)
      return true
    end
    if pressed('backspace') or pressed('delete') then
      if shift and o and is(o, 'CharacterPart') and not o.cant_click then
        sell_reserve(o)
      else
        nav.activate(true)
      end
      return true
    end
  end

  return false
end

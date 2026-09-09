-- Keyboard navigation for every menu, shop and card screen in the game.
--
-- SNKRX's interface is entirely mouse-hover driven: widgets light up in
-- GameObject:update_game_object when the pointer overlaps their shape, and each
-- one raises its own tooltip from on_mouse_enter. Rather than reimplement all
-- of that, this module drives the real pointer. Focus moves with Tab or the
-- arrow keys, the OS cursor is warped onto the focused widget, and the engine's
-- own hover logic fires untouched. Enter and Backspace inject a left or right
-- click for the frame.
--
-- The payoff is that everything keeps working: tooltips, highlights, sell
-- prices, class previews, the lot. Nothing in the game had to learn about
-- keyboards. The pointer is only ever moved once the player has pressed a
-- navigation key, so a sighted player using the mouse is never fought over.

local nav = {}
access.nav = nav

nav.enabled = true
nav.items = {}
nav.index = 0
nav.focus = nil

local signature = nil
local pending = nil          -- {button = 'm1'|'m2', frames = n}
local release_next = nil     -- button to release on the following frame
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


-- The shop lays its widgets out in columns that interleave when read strictly
-- top to bottom: a party member, then a class icon, then an item, then another
-- party member. Grouping them into named regions turns Tab into something you
-- can hold a mental map of, and the region name is announced when it changes,
-- the way a screen reader announces a new landmark.
local SHOP_REGIONS = {
  {name = 'shop cards',    match = function(o) return is(o, 'ShopCard') end},
  {name = 'party',         match = function(o) return is(o, 'CharacterPart') end},
  {name = 'classes',       match = function(o) return is(o, 'ClassIcon') end},
  {name = 'items',         match = function(o) return is(o, 'ItemCard') end},
  {name = 'shop controls', match = function(o)
      return is(o, 'RerollButton') or is(o, 'LockButton') or is(o, 'LevelButton') or is(o, 'Button')
    end},
  {name = 'start',         match = function(o) return is(o, 'GoButton') end},
}


local function region_of(st, o)
  if not (st.is and st:is(BuyScreen)) or st.in_tutorial or st.paused then return 0, nil end
  for i, region in ipairs(SHOP_REGIONS) do
    if region.match(o) then return i, region.name end
  end
  return #SHOP_REGIONS + 1, 'other'
end


local function collect_groups(st)
  if st.in_tutorial and st.tutorial then return {st.tutorial} end
  -- While a modal is up the screen behind it is inert, so only offer the modal.
  if st.paused or st.choosing_passives or st.died or st.won then
    return st.ui and {st.ui} or {}
  end
  local out = {}
  for _, name in ipairs({'main', 'main_ui', 'effects', 'ui'}) do
    local g = st[name]
    if g and g.objects then table.insert(out, g) end
  end
  return out
end


function nav.collect()
  local st = main and main.current
  if not st or st.transitioning then return {} end

  local items = {}
  for _, group in ipairs(collect_groups(st)) do
    for _, o in ipairs(group.objects) do
      if o.interact_with_mouse and o.shape and not o.dead and not o.hidden and not is_redundant(o) then
        table.insert(items, o)
      end
    end
  end

  -- Reading order: top to bottom in bands, then left to right inside a band.
  -- The 14 pixel band matches the game's own row spacing closely enough that
  -- visually-aligned widgets stay together.
  --
  -- The item-choice cards are the exception: they are drawn staggered so that
  -- adjacent cards sit at different heights, which would read as 1, 3, 2, 4.
  -- They carry an explicit card_i, which is also what the number-key shortcuts
  -- use, so that ordering wins.
  local card_row = math.huge
  for _, o in ipairs(items) do
    if o.card_i then card_row = math.min(card_row, math.floor(o.y / 14)) end
  end
  for _, o in ipairs(items) do
    o.a11y_region, o.a11y_region_name = region_of(st, o)
    if o.card_i then
      o.a11y_row, o.a11y_col = card_row, o.card_i
    else
      o.a11y_row, o.a11y_col = math.floor(o.y / 14), o.x
    end
  end

  table.sort(items, function(a, b)
    if a.a11y_region ~= b.a11y_region then return a.a11y_region < b.a11y_region end
    if a.a11y_row ~= b.a11y_row then return a.a11y_row < b.a11y_row end
    if a.a11y_col ~= b.a11y_col then return a.a11y_col < b.a11y_col end
    return tostring(a.id) < tostring(b.id)
  end)
  return items
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


local spoken_region = nil

function nav.speak_focus(interrupt)
  local o = nav.focus
  if not o then return end
  local label, detail = access.describe.focusable(o)
  if not label then return end

  -- Announce the region only when crossing into a new one, like a landmark.
  local prefix = ''
  if o.a11y_region_name and o.a11y_region_name ~= spoken_region then
    prefix = o.a11y_region_name .. '. '
  end
  spoken_region = o.a11y_region_name

  local position = ''
  if #nav.items > 1 then position = ', ' .. nav.index .. ' of ' .. #nav.items end
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


function nav.move(delta)
  if #nav.items == 0 then
    access.say('nothing to select here', {interrupt = true})
    return
  end
  if nav.index == 0 then
    nav.set_focus(delta > 0 and 1 or #nav.items)
  else
    nav.set_focus(nav.index + delta)
  end
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
  local button = pending.button
  input[button].pressed = true
  input[button].down = true
  release_next = button
  pending = nil
end


function nav.update(dt)
  if not nav.enabled then return end

  local st = main and main.current
  if st ~= last_screen then
    last_screen = st
    nav.items, nav.index, nav.focus, signature = {}, 0, nil, nil
    pending, release_next, spoken_region = nil, nil, nil
  end

  local items = nav.collect()
  local sig = tostring(#items)
  for _, o in ipairs(items) do sig = sig .. '|' .. tostring(o.id) end

  if sig ~= signature then
    signature = sig
    local previous, previous_index = nav.focus, nav.index
    nav.items = items

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
      -- took its place rather than dumping the player back at the top.
      nav.index = math.max(1, math.min(previous_index, #items))
      nav.focus = items[nav.index]
      warp_to(nav.focus)
      nav.speak_focus()
    else
      nav.index, nav.focus = 0, nil
    end
  else
    nav.items = items
  end

  service_click()
end


-- True when arrow keys should steer the menu rather than the snake.
function nav.arrows_available()
  local st = main and main.current
  if not st then return false end
  if is(st, 'Arena') and not (st.paused or st.choosing_passives or st.died or st.won) then
    return false
  end
  return #nav.items > 0
end


function nav.handle_input()
  if not nav.enabled then return false end

  local shift = down('lshift') or down('rshift')

  if pressed('tab') then
    nav.move(shift and -1 or 1)
    return true
  end

  if nav.arrows_available() then
    if pressed('down') or pressed('right') then nav.move(1) return true end
    if pressed('up') or pressed('left') then nav.move(-1) return true end
    if pressed('home') then nav.set_focus(1) return true end
    if pressed('end') then nav.set_focus(#nav.items) return true end
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
      nav.activate(true)
      return true
    end
  end

  return false
end

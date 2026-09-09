-- Turning the game's on-screen information into something worth listening to.
--
-- Two jobs live here:
--   1. Sanitising SNKRX's rich-text markup into plain speech.
--   2. Naming things: UI widgets, directions, distances, positions.
--
-- Every focusable widget returns a short label plus an optional longer detail.
-- The label is spoken immediately and interrupts; the detail is queued behind
-- it, so a player skimming with Tab hears only the labels while a player who
-- pauses hears the full description. That is how screen readers behave
-- elsewhere and it is what makes fast navigation bearable.

local describe = {}
access.describe = describe


-- SNKRX text carries inline tags like "[yellow, wavy_mid]" for colour and
-- animation. None of that survives into speech.
function describe.strip(text)
  if type(text) ~= 'string' then return '' end
  text = text:gsub('%[[^%]]*%]', '')
  text = text:gsub('%s+', ' ')
  text = text:gsub('^%s+', ''):gsub('%s+$', '')
  return text
end


-- A handful of the game's abbreviations are unreadable when spoken aloud, and
-- its habit of separating clauses with a dash makes the voice say "dash".
local EXPANSIONS = {
  {'Lv%.(%d)', 'level %1'},
  {'lv%.(%d)', 'level %1'},
  {'NG%+', 'new game plus '},
  {'aspd', 'attack speed'},
  {'mvspd', 'movement speed'},
  {'dmg', 'damage'},
  {'dps', 'damage per second'},
  {'DoT', 'damage over time'},
  {'AoE', 'area of effect'},
  {'HP', 'health'},
  {'hp', 'health'},
  {'%-%>', ' to '},
  {'%s%-%s', ', '},
  {'_', ' '},
}

function describe.speech(text)
  text = describe.strip(text)
  for _, e in ipairs(EXPANSIONS) do text = text:gsub(e[1], e[2]) end
  text = text:gsub('%s+', ' ')
  -- Joined fragments regularly collide into ".." which some voices pause on.
  text = text:gsub('%.%s*%.', '.')
  return (text:gsub('^%s+', ''):gsub('%s+$', ''))
end


-- InfoText and Text objects are built from a list of {text = ..., font = ...}
-- lines. Join them into one utterance, separated so the voice breathes.
function describe.lines(text_data)
  if type(text_data) ~= 'table' then return '' end
  local parts = {}
  for _, line in ipairs(text_data) do
    local s = describe.speech(line.text or '')
    -- Lines that already end in punctuation must not gain a second full stop.
    s = s:gsub('[%.,;:]+$', '')
    if s ~= '' then table.insert(parts, s) end
  end
  return table.concat(parts, '. ')
end


function describe.title(s)
  if type(s) ~= 'string' or s == '' then return '' end
  s = s:gsub('_', ' ')
  return (s:gsub('^%l', string.upper))
end


-- ---------------------------------------------------------------- geometry --

-- SNKRX is drawn in a 480x270 space and the arena is only 384x216 of it.
-- Pixels mean nothing to a listener, so distances are reported in "steps" of
-- 16 pixels: the arena is then 24 by 13 steps and the snake covers roughly
-- five steps a second, which makes the numbers intuitive.
local STEP = 16

function describe.steps(pixels)
  return math.max(0, math.floor(pixels / STEP + 0.5))
end


function describe.distance(pixels)
  local s = describe.steps(pixels)
  if s <= 1 then return 'point blank' end
  return s .. ' steps'
end


-- "a, b and c" rather than "a and b and c".
function describe.list(items)
  if #items == 0 then return '' end
  if #items == 1 then return items[1] end
  local head = {}
  for i = 1, #items - 1 do table.insert(head, items[i]) end
  return table.concat(head, ', ') .. ' and ' .. items[#items]
end


function describe.wrap_angle(a)
  a = (a + math.pi) % (2 * math.pi)
  if a < 0 then a = a + 2 * math.pi end
  return a - math.pi
end


-- Screen y grows downwards, so an angle of 0 points east and pi/2 points south.
local COMPASS = {'east', 'south east', 'south', 'south west', 'west', 'north west', 'north', 'north east'}

function describe.compass(r)
  local a = r % (2 * math.pi)
  if a < 0 then a = a + 2 * math.pi end
  local i = math.floor(a / (2 * math.pi) * 8 + 0.5) % 8
  return COMPASS[i + 1]
end


-- Bearings relative to the direction of travel are given on a clock face:
-- 12 is straight ahead, 3 is to your right, 6 is behind you.
function describe.clock(relative_bearing)
  local a = relative_bearing % (2 * math.pi)
  if a < 0 then a = a + 2 * math.pi end
  local c = math.floor(a / (2 * math.pi) * 12 + 0.5) % 12
  if c == 0 then c = 12 end
  return c .. " o'clock"
end


-- A coarse, immediately actionable version of the same thing.
function describe.side(relative_bearing)
  local b = describe.wrap_angle(relative_bearing)
  local a = math.abs(b)
  if a < math.pi / 8 then return 'ahead'
  elseif a > 7 * math.pi / 8 then return 'behind'
  elseif b > 0 then
    if a < 3 * math.pi / 8 then return 'ahead right'
    elseif a < 5 * math.pi / 8 then return 'right'
    else return 'behind right' end
  else
    if a < 3 * math.pi / 8 then return 'ahead left'
    elseif a < 5 * math.pi / 8 then return 'left'
    else return 'behind left' end
  end
end


-- Where in the arena something is, in absolute terms. Used for orientation
-- rather than for aiming.
function describe.position(x, y, arena)
  if not arena or not arena.x1 then return 'unknown' end
  local px = (x - arena.x1) / (arena.x2 - arena.x1)
  local py = (y - arena.y1) / (arena.y2 - arena.y1)
  local h = (px < 0.33 and 'left') or (px > 0.67 and 'right') or 'centre'
  local v = (py < 0.33 and 'top') or (py > 0.67 and 'bottom') or 'middle'
  if h == 'centre' and v == 'middle' then return 'centre' end
  if h == 'centre' then return v .. ' centre' end
  if v == 'middle' then return h .. ' middle' end
  return v .. ' ' .. h
end


-- "1 heroes" is the kind of detail that makes synthetic speech grating.
function describe.count(n, singular, plural)
  return n .. ' ' .. (n == 1 and singular or (plural or (singular .. 's')))
end


-- ------------------------------------------------------------- game things --

function describe.character(character, level)
  local name = character_names and character_names[character] or describe.title(character)
  if level then return name .. ' level ' .. level end
  return name
end


function describe.classes_of(character)
  local classes = character_classes and character_classes[character]
  if not classes then return '' end
  local out = {}
  for _, c in ipairs(classes) do
    table.insert(out, c == 'conjurer' and 'builder' or describe.title(c))
  end
  return table.concat(out, ', ')
end


function describe.character_detail(character, level)
  local parts = {}
  local tier = character_tiers and character_tiers[character]
  table.insert(parts, describe.character(character, level) ..
    (tier and (', tier ' .. tier) or ''))
  local classes = describe.classes_of(character)
  if classes ~= '' then table.insert(parts, 'classes: ' .. classes) end
  if character_descriptions and character_descriptions[character] then
    local ok, d = pcall(character_descriptions[character], level or 1)
    if ok then table.insert(parts, describe.speech(d)) end
  end
  local at_three = (level == 3)
  local effect_name = at_three and (character_effect_names and character_effect_names[character])
    or (character_effect_names_gray and character_effect_names_gray[character])
  local descs = at_three and character_effect_descriptions or character_effect_descriptions_gray
  if effect_name then
    local line = 'level 3 effect, ' .. describe.speech(effect_name)
    if descs and descs[character] then
      local ok, d = pcall(descs[character])
      if ok then line = line .. ': ' .. describe.speech(d) end
    end
    table.insert(parts, line)
  end
  return table.concat(parts, '. ')
end


function describe.passive(passive, level, xp)
  local name = passive_names and passive_names[passive] or describe.title(passive)
  local parts = {name}
  if level then table.insert(parts, 'level ' .. level) end
  local d = passive_descriptions_level and passive_descriptions_level[passive]
  local text
  if d then
    local ok, r = pcall(d, level or 1)
    if ok then text = r end
  end
  if not text and passive_descriptions and passive_descriptions[passive] then
    local ok, r = pcall(function()
      local v = passive_descriptions[passive]
      if type(v) == 'function' then return v(level or 1) end
      return v
    end)
    if ok then text = r end
  end
  if text then table.insert(parts, describe.speech(text)) end
  return table.concat(parts, '. ')
end


-- --------------------------------------------------------------- widgets --

local function is(o, class_name)
  local class = _G[class_name]
  return class and o.is and o:is(class)
end


-- A handful of buttons are labelled with a single glyph, which a screen reader
-- can only read as punctuation.
local ICON_BUTTONS = {['?'] = 'guide', ['R'] = 'restart run', ['x'] = 'close', ['X'] = 'close'}


-- Returns label, detail. The label is spoken first and interrupts whatever was
-- being said; the detail is queued behind it and is skipped if the player
-- keeps moving.
function describe.focusable(o)
  if not o then return nil end

  if is(o, 'ShopCard') then
    local cost = o.cost or (character_tiers and character_tiers[o.unit]) or '?'
    local label = describe.character(o.unit) .. ', ' .. cost .. ' gold'
    if o.owned and o.owned_n then label = label .. ', owned ' .. o.owned_n end
    local classes = describe.classes_of(o.unit)
    if classes ~= '' then label = label .. ', ' .. classes end
    -- The shop card has no hover tooltip of its own, so spell it out here.
    return label, describe.character_detail(o.unit, 1)
  end

  if is(o, 'CharacterIcon') then
    return describe.character(o.character) .. ', shop card'
  end

  if is(o, 'CharacterPart') then
    local label = describe.character(o.character, o.level)
    if o.i then label = 'party slot ' .. o.i .. ', ' .. label end
    -- Read-only copies of the party appear on the death and victory screens;
    -- offering a sale price there would be a lie.
    if o.get_sale_price and not o.cant_click then
      local ok, price = pcall(o.get_sale_price, o)
      if ok then label = label .. ', sells for ' .. price end
    end
    return label
  end

  if is(o, 'ClassIcon') then
    local class = o.class == 'conjurer' and 'builder' or describe.title(o.class)
    local label = class .. ' class'
    if class_set_numbers and class_set_numbers[o.class] and o.units then
      local ok, i, j, k, owned = pcall(class_set_numbers[o.class], o.units)
      if ok then
        local target = (k and owned < k and k) or (owned < j and j) or (owned < i and i)
        label = label .. ', ' .. (owned or 0) .. ' owned'
        if target then label = label .. ', next bonus at ' .. target end
      end
    end
    return label
  end

  -- Item and passive cards both raise a hover tooltip carrying the full rules
  -- text, which the InfoText hook speaks. Naming them twice is just noise, so
  -- these deliberately return a label and no detail.
  if is(o, 'ItemCard') then
    return (passive_names and passive_names[o.passive] or describe.title(o.passive)) ..
      ', level ' .. tostring(o.level)
  end

  if is(o, 'PassiveCard') then
    return 'item choice ' .. (o.card_i or '?') .. ', ' ..
      (passive_names and passive_names[o.passive] or describe.title(o.passive))
  end

  if is(o, 'GoButton') then
    return 'go, start the round'
  end

  if is(o, 'RerollButton') then
    local cost = o.free_reroll and 0 or (o.parent and o.parent.is and o.parent:is(Arena) and 5 or 2)
    return 'reroll, ' .. cost .. ' gold'
  end

  if is(o, 'LockButton') then
    return (o.parent and o.parent.locked) and 'unlock shop' or 'lock shop'
  end

  if is(o, 'LevelButton') then
    local lvl = o.parent and o.parent.shop_level or '?'
    return 'shop level ' .. lvl .. ', ' .. (o.shop_xp or 0) .. ' of ' .. (o.max_xp or 0) ..
      ' experience. Enter to buy experience for 5 gold, backspace to sell a level for 10'
  end

  if is(o, 'RestartButton') then return 'restart run' end

  if o.button_text and ICON_BUTTONS[o.button_text] then return ICON_BUTTONS[o.button_text] end

  if is(o, 'SteamFollowButton') then return 'follow me on Steam, opens a browser' end
  if is(o, 'WishlistButton') then return 'wishlist on Steam, opens a browser' end

  if is(o, 'Button') then
    return describe.speech(o.button_text or 'button')
  end

  -- Anything unrecognised still gets a usable name rather than silence.
  if o.button_text then return describe.speech(o.button_text) end
  if o.character then return describe.character(o.character, o.level) end
  return 'item'
end

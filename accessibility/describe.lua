-- Turning the game's on-screen information into something worth listening to.
--
-- Two jobs live here:
--   1. Sanitising SNKRX's rich-text markup into plain speech.
--   2. Naming things: UI widgets, directions, distances, positions, enemies.
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


-- Most screen readers run at a punctuation level that swallows slashes and
-- signs, so "XP: 1/4" is heard as "XP 1 4", "+25/+50" as "25 50" and "4x" as
-- "4 x". The game leans on all three, so they are spelled out.
local function expand_symbols(text)
  text = text:gsub('XP:? (%d+)/(%d+)', 'experience %1 of %2')
  text = text:gsub('(%d%%?)/([%+%-]?%d)', '%1 or %2')
  text = text:gsub('(%a)/(%a)', '%1 or %2')
  text = text:gsub('%+(%d)', 'plus %1')
  text = text:gsub('^%-(%d)', 'minus %1')
  text = text:gsub('([%s,%(])%-(%d)', '%1minus %2')
  text = text:gsub('(%d)x%f[%A]', '%1 times')
  return text
end


function describe.speech(text)
  text = describe.strip(text)
  for _, e in ipairs(EXPANSIONS) do text = text:gsub(e[1], e[2]) end
  text = expand_symbols(text)
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


-- The game calls the class "conjurer" in its data and "builder" on screen.
function describe.class_name(class)
  if class == 'conjurer' then return 'Builder' end
  return describe.title(class)
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
  for _, c in ipairs(classes) do table.insert(out, describe.class_name(c)) end
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


function describe.passive_name(passive)
  return passive_names and passive_names[passive] or describe.title(passive)
end


function describe.passive(passive, level, xp)
  local parts = {describe.passive_name(passive)}
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


-- What kind of round a level is. Every sixth round (and every 25th) is an
-- elite round with a boss; every third ends with an item choice.
function describe.round_type(level, loop)
  loop = loop or 0
  if (level - 25 * loop) % 6 == 0 or level % 25 == 0 then return 'elite round'
  elseif (level - 25 * loop) % 3 == 0 then return 'hard round' end
  return nil
end


-- Enemies are told apart on screen by colour alone.
function describe.enemy_kind(o)
  if not o then return 'enemy' end
  if o.boss then return 'elite' end
  if o.speed_booster then return 'speed booster'
  elseif o.exploder then return 'exploder'
  elseif o.headbutter then return 'headbutter'
  elseif o.tank then return 'tank'
  elseif o.shooter then return 'shooter'
  elseif o.spawner then return 'spawner' end
  if EnemyCritter and o.is and o:is(EnemyCritter) then return 'critter' end
  return 'enemy'
end


function describe.boss_name(boss)
  if not boss then return 'elite' end
  return describe.title(boss) .. ' elite'
end


-- --------------------------------------------------------------- widgets --

local function is(o, class_name)
  local class = _G[class_name]
  return class and o.is and o:is(class)
end


-- A handful of buttons are labelled with a single glyph, which a screen reader
-- can only read as punctuation.
local ICON_BUTTONS = {['?'] = 'guide, F5', ['R'] = 'restart run, abandons the current run', ['x'] = 'close', ['X'] = 'close'}

-- Buttons that leave the game for a web page deserve a warning.
local LINK_BUTTONS = {
  ['buy the soundtrack!'] = true, ['join the community discord!'] = true,
  ['nimble quest'] = true, ['dota underlords'] = true,
}


-- The same question the keyboard asks when it groups a screen: links gather at
-- the end of the menu and the victory screen rather than sitting among the
-- buttons that do something to the game.
function describe.is_link(o)
  if not o then return false end
  if o.credits_button then return true end
  if o.button_text and LINK_BUTTONS[o.button_text] then return true end
  return is(o, 'SteamFollowButton') or is(o, 'WishlistButton') or false
end


-- Returns label, detail. The label is spoken first and interrupts whatever was
-- being said; the detail is queued behind it and is skipped if the player
-- keeps moving.
function describe.focusable(o)
  if not o then return nil end

  -- A widget built by the accessibility layer itself already knows exactly what
  -- it wants said about it, and nothing here could improve on that.
  if o.a11y_label then return o.a11y_label, o.a11y_detail end


  if is(o, 'ShopCard') then
    local cost = o.cost or (character_tiers and character_tiers[o.unit]) or '?'
    local label = describe.character(o.unit) .. ', ' .. cost .. ' gold'
    if o.owned and o.owned_n then label = label .. ', ' .. describe.count(o.owned_n, 'copy', 'copies') .. ' owned' end
    local classes = describe.classes_of(o.unit)
    if classes ~= '' then label = label .. ', ' .. classes end
    -- The shop card has no hover tooltip of its own, so spell it out here.
    return label, describe.character_detail(o.unit, 1)
  end

  if is(o, 'CharacterIcon') then
    return describe.character(o.character) .. ', shop card'
  end

  if is(o, 'TutorialCharacterPart') then
    return 'example hero, ' .. describe.character(o.character, o.level)
  end

  if is(o, 'TutorialClassIcon') then
    local label = 'example class icon, ' .. describe.class_name(o.class)
    if class_set_numbers and class_set_numbers[o.class] then
      local ok, i, j, k, owned = pcall(class_set_numbers[o.class], o.units or {})
      if ok then
        local level = (k and owned >= k and 3) or (owned >= j and 2) or (owned >= i and 1) or 0
        label = label .. ', ' .. owned .. ' owned, bonus level ' .. level
      end
    end
    return label
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
    -- Spare copies waiting to merge: the part of the level-up mechanic that is
    -- otherwise only visible as small tiles beside the party member.
    if o.reserve and o.level and o.level < 3 and not o.cant_click then
      local r1, r2 = o.reserve[1] or 0, o.reserve[2] or 0
      if o.level == 1 then
        label = label .. ', ' .. r1 .. ' of 2 extra copies toward level 2'
      else
        label = label .. ', ' .. (r2 * 3 + r1) .. ' of 6 extra copies toward level 3'
      end
      if r1 + r2 > 0 then label = label .. ', shift backspace sells a spare copy' end
    elseif o.level == 3 and not o.cant_click then
      label = label .. ', max level'
    end
    return label
  end

  if is(o, 'ClassIcon') then
    local label = describe.class_name(o.class) .. ' class'
    if class_set_numbers and class_set_numbers[o.class] and o.units then
      local ok, i, j, k, owned = pcall(class_set_numbers[o.class], o.units)
      if ok then
        local target = (owned < i and i) or (owned < j and j) or (k and owned < k and k) or nil
        label = label .. ', ' .. (owned or 0) .. ' owned'
        if target then label = label .. ', next bonus at ' .. target
        else label = label .. ', fully unlocked' end
      end
    end
    return label
  end

  -- Item and passive cards both raise a hover tooltip carrying the full rules
  -- text, which the InfoText hook speaks. Naming them twice is just noise, so
  -- these deliberately return a label and no detail.
  if is(o, 'ItemCard') then
    local label = describe.passive_name(o.passive) .. ', level ' .. tostring(o.level)
    if o.parent and is(o.parent, 'BuyScreen') then
      if o.unlevellable or (o.level or 0) >= 3 then
        label = label .. ', backspace sells'
      else
        label = label .. ', enter adds experience for 5 gold, backspace sells'
      end
    end
    return label
  end

  if is(o, 'PassiveCard') then
    return 'item choice ' .. (o.card_i or '?') .. ', ' .. describe.passive_name(o.passive) ..
      ', enter or ' .. (o.card_i or '?') .. ' to take it'
  end

  if is(o, 'GoButton') then
    return 'go, start the round, G'
  end

  if is(o, 'RerollButton') then
    local cost = o.free_reroll and 0 or (o.parent and o.parent.is and o.parent:is(Arena) and 5 or 2)
    return 'reroll, ' .. cost .. ' gold, R'
  end

  if is(o, 'LockButton') then
    return (o.parent and o.parent.locked) and 'unlock shop, cards will change next round'
      or 'lock shop, keep these cards for next round'
  end

  if is(o, 'LevelButton') then
    local lvl = o.parent and o.parent.shop_level or '?'
    return 'shop level ' .. lvl .. ', ' .. (o.shop_xp or 0) .. ' of ' .. (o.max_xp or 0) ..
      ' experience. Enter buys experience for 5 gold, backspace sells a level for 10'
  end

  if is(o, 'RestartButton') then return 'new game plus ' .. tostring(current_new_game_plus or 0) .. ', start a new harder run' end

  if o.button_text and ICON_BUTTONS[o.button_text] then return ICON_BUTTONS[o.button_text] end

  if is(o, 'SteamFollowButton') then return 'follow me on Steam, opens a browser' end
  if is(o, 'WishlistButton') then return 'wishlist on Steam, opens a browser' end

  if is(o, 'Button') then
    local label = describe.speech(o.button_text or 'button')
    if describe.is_link(o) then label = label .. ', opens a browser' end
    return label
  end

  -- Anything unrecognised still gets a usable name rather than silence.
  if o.button_text then return describe.speech(o.button_text) end
  if o.character then return describe.character(o.character, o.level) end
  return 'item'
end

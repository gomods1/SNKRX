-- Localization.
--
-- Every piece of text the game shows or speaks goes through T(). A key names
-- the string, the locale files hold the text for each language, and anything
-- computed at runtime -- a damage number, a colour tag that depends on a class
-- level -- arrives as a numbered argument:
--
--   T('char.vagrant.desc', get_character_stat('vagrant', lvl, 'dmg'))
--     en: '[fg]shoots a projectile that deals [yellow]{1}[fg] damage'
--     es: '[fg]dispara un proyectil que inflige [yellow]{1}[fg] de daño'
--
-- Numbered rather than positional because Spanish reorders clauses freely and
-- a translation has to be able to put {2} before {1}.
--
-- Two rules hold everywhere:
--
--   * English is the source of truth. A key missing from another language
--     falls back to English rather than disappearing, so a half-finished
--     translation degrades into a mixed-language screen instead of a blank one.
--   * The bracket markup inside a string ([yellow], [wavy_mid], [fg]) is not
--     text. It picks colours and animations out of global_text_tags and has to
--     survive translation untouched.

loc = {}

-- Display names are written in their own language, which is the convention
-- every language menu follows and the only one a player who cannot read the
-- current language can act on. Both spellings render: the pixel fonts were
-- given the accented glyphs they were missing (see tools/patch_fonts.js).
loc.languages = {
  {code = 'en', name = 'english'},
  {code = 'es', name = 'español'},
}

loc.default = 'en'
loc.current = loc.default
loc.strings = {}

-- Keys asked for and not found, so that a missing string shows up as something
-- other than a shrug. Reported once per key.
loc.missing = {}


function loc.load()
  for _, language in ipairs(loc.languages) do
    local ok, data = pcall(require, 'locales.' .. language.code)
    if ok and type(data) == 'table' then
      loc.strings[language.code] = data
    else
      print('localization: could not load locale ' .. language.code .. ': ' .. tostring(data))
      loc.strings[language.code] = {}
    end
  end
end


function loc.is_valid(code)
  for _, language in ipairs(loc.languages) do
    if language.code == code then return true end
  end
  return false
end


-- Callbacks run after a language change, for the tables and screens that hold
-- built strings rather than looking them up as they draw.
loc.on_change = {}

function loc.set(code)
  if not loc.is_valid(code) then return false end
  if code == loc.current then return false end
  loc.current = code
  if state then state.language = code end
  for _, fn in ipairs(loc.on_change) do
    local ok, err = pcall(fn)
    if not ok then print('localization: on_change handler failed: ' .. tostring(err)) end
  end
  return true
end


function loc.next()
  for i, language in ipairs(loc.languages) do
    if language.code == loc.current then
      return loc.set(loc.languages[(i % #loc.languages) + 1].code)
    end
  end
  return loc.set(loc.default)
end


function loc.previous()
  for i, language in ipairs(loc.languages) do
    if language.code == loc.current then
      return loc.set(loc.languages[((i - 2) % #loc.languages) + 1].code)
    end
  end
  return loc.set(loc.default)
end


-- The current language's name, in its own language.
function loc.language_name(code)
  code = code or loc.current
  for _, language in ipairs(loc.languages) do
    if language.code == code then return language.name end
  end
  return code
end


-- The raw string for a key, before arguments are substituted.
function loc.get(key)
  local current = loc.strings[loc.current]
  if current and current[key] then return current[key] end

  local fallback = loc.strings[loc.default]
  if fallback and fallback[key] then
    if loc.current ~= loc.default and not loc.missing[key] then
      loc.missing[key] = true
      print('localization: ' .. loc.current .. ' is missing "' .. key .. '"')
    end
    return fallback[key]
  end

  if not loc.missing[key] then
    loc.missing[key] = true
    print('localization: no string for "' .. key .. '"')
  end
  return key
end


-- A locale entry that is a list rather than a sentence: the compass points, the
-- speech layer's abbreviation expansions. Falls back to English the same way a
-- string does, and to an empty table so that a caller iterating it cannot fail.
function loc.table(key)
  local value = loc.get(key)
  if type(value) == 'table' then return value end
  local fallback = loc.strings[loc.default] and loc.strings[loc.default][key]
  if type(fallback) == 'table' then return fallback end
  return {}
end


-- "1 hero" rather than "1 heroes". The locale holds one form per key, under
-- <key>.one and <key>.many, because the choice of form is the translator's:
-- not every language splits at the same place.
function loc.count(n, key)
  return T(key .. (n == 1 and '.one' or '.many'), n)
end


-- T(key, ...) -- the one entry point. Arguments fill {1}, {2}, ... in the
-- string; a placeholder with no argument behind it is left alone rather than
-- turning the line into "nil", because a visible {2} is a bug report and a
-- stray "nil" is a mystery.
function T(key, ...)
  local text = loc.get(key)
  if select('#', ...) == 0 then return text end
  local args = {...}
  return (text:gsub('{(%d+)}', function(i)
    local value = args[tonumber(i)]
    if value == nil then return nil end
    return tostring(value)
  end))
end


-- Called once the save file has been read, since that is where the choice is
-- kept. Anything localized before this point comes out in English.
function loc.init()
  loc.load()
  if state and loc.is_valid(state.language) then
    loc.current = state.language
  else
    loc.current = loc.default
    if state then state.language = loc.current end
  end
end

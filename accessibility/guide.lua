-- The in-game guide, spoken.
--
-- SNKRX's guide is one screen of text plus two diagrams: a row of hero tiles
-- showing copies merging into higher levels, and three class icons showing a
-- class bonus filling up. The text is read straight from the game's own guide
-- so it can never drift out of date; the diagrams are described here in words.
--
-- After the game's guide comes a second part that exists only for the player
-- who cannot see the screen: how the arena is narrated, what each sound means,
-- and how every mechanic is reached from the keyboard. F5 opens all of this
-- from anywhere.
--
-- MANUAL.md is the same text written down, for players who would rather read
-- it; when the text below changes, change it there too.

local guide = {}
access.guide = guide

local describe = access.describe


-- Each diagram is spoken straight after the guide line that introduces it, so
-- the two are matched by that line. The line is translated, so the thing to
-- match on is the same locale string the guide screen was built from rather
-- than an English fragment of it.
local DIAGRAMS = {
  {line = 'ui.guide.combine', text = 'a11y.guide.diagram_levels'},
  {line = 'ui.guide.classes', text = 'a11y.guide.diagram_classes'},
}


function guide.diagram_for(line)
  if type(line) ~= 'string' then return nil end
  for _, d in ipairs(DIAGRAMS) do
    if line:find(T(d.line), 1, true) then return T(d.text) end
  end
  return nil
end


-- A paraphrase of the game's guide, for when it is asked for outside the shop
-- and the real text is not on screen to be read.
guide.BASICS = {
  'a11y.guide.welcome', 'a11y.guide.steering', 'a11y.guide.levelling',
  'a11y.guide.classes', 'a11y.guide.interest',
}


-- How this game is played without sight. Long enough that it lives in the
-- locale files a paragraph at a time rather than inline here.
guide.MECHANICS = {
  'a11y.guide.playing_by_ear', 'a11y.guide.how_heard', 'a11y.guide.the_snake',
  'a11y.guide.the_arena', 'a11y.guide.enemies', 'a11y.guide.special_enemies',
  'a11y.guide.rounds', 'a11y.guide.health_and_gold', 'a11y.guide.reports',
  'a11y.guide.the_shop', 'a11y.guide.learn_sounds', 'a11y.guide.learn_enemies',
  'a11y.guide.f1',
}


-- Speak the whole guide. When the game's own guide screen is open, its text is
-- read from the screen with the diagrams described in place; otherwise the
-- paraphrase stands in for it.
function guide.speak(st)
  local parts = {}
  local function add(s) if s and s ~= '' then table.insert(parts, s) end end

  local read_screen = false
  if st and st.in_tutorial then
    for _, source in ipairs({st.title_text, st.tutorial_text}) do
      local lines = source and (source.lines or (source.text and source.text.text_data))
      if type(lines) == 'table' then
        for _, line in ipairs(lines) do
          local s = describe.speech(line.text or '')
          s = s:gsub('[%.,;:!?]+$', '')
          if s ~= '' then
            read_screen = true
            add(s .. '.')
            add(guide.diagram_for(line.text))
          end
        end
      end
    end
  end
  if not read_screen then
    for _, key in ipairs(guide.BASICS) do add(T(key)) end
  end
  for _, key in ipairs(guide.MECHANICS) do add(T(key)) end
  if st and st.in_tutorial then add(T('a11y.guide.screen_keys')) end

  access.say(parts[1], {interrupt = true, priority = true})
  for i = 2, #parts do access.say(parts[i], {interrupt = false, priority = true}) end
end

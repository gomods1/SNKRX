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


-- Spoken straight after the guide line that introduces each diagram.
local DIAGRAMS = {
  {
    match = 'Combine the same heroes',
    text = 'The picture shows three level 1 Swordsmen turning into one level 2 Swordsman, and three level 2 Swordsmen turning into one level 3. ' ..
      'Buying a hero you already own adds a copy: three copies make level 2, and nine copies make level 3. ' ..
      'Spare copies wait beside the party member until enough have gathered, and each party member says how many it has.',
  },
  {
    match = 'Hire heroes of the same classes',
    text = 'The picture shows the Warrior class icon three times: with no warriors, with 3 warriors and the first bonus lit, and with 5 warriors, one short of the second bonus. ' ..
      'Warrior, Ranger, Mage, Rogue and Nuker unlock their first bonus at 3 heroes and a stronger one at 6. ' ..
      'Every other class unlocks at 2 and 4, Sorcerer has a third step at 6, and Explorer needs only 1. ' ..
      'Each class icon in the shop says how many you own and where the next bonus is.',
  },
}


function guide.diagram_for(line)
  if type(line) ~= 'string' then return nil end
  for _, d in ipairs(DIAGRAMS) do
    if line:find(d.match, 1, true) then return d.text end
  end
  return nil
end


-- A paraphrase of the game's guide, for when it is asked for outside the shop
-- and the real text is not on screen to be read.
guide.BASICS = {
  'Welcome to SNKRX.',
  'You control a snake of heroes that attack nearby enemies on their own. Steer left with A or the left arrow and right with D or the right arrow.',
  'Buy the same hero again to level it up: three copies make level 2, nine make level 3, and at level 3 a hero unlocks a special effect.',
  'Each hero belongs to one to three classes. Owning enough heroes of one class unlocks a class bonus for the whole party.',
  'You earn 1 gold of interest per 5 gold saved, up to 5, so saving beyond 25 gold earns nothing extra.',
}


-- How this game is played without sight.
guide.MECHANICS = {
  'Playing by ear.',
  'How things are heard. Four things sound without stopping for as long as they are there: the nearest enemy, the elite, the nearest loose gold and the nearest healing orb. ' ..
    'The two dangers hold a steady tone. The two pickups are struck instead and repeat, gold ticking like a flipped coin and an orb glowing with a soft chime, so a thing worth chasing never sounds like a thing worth avoiding. ' ..
    'Each is panned to where that thing is, relative to the way the snake is facing rather than to the screen, so hard left means on your left whichever way you are pointing. ' ..
    'Each is bright when the thing is in front of you and dull and low when it is behind, and rises and quickens as it gets closer. ' ..
    'That is what makes something reachable: turn until its sound is bright and in the middle of your head, and you are heading straight at it. Turn until it is dull and you are heading away.',
  'The snake. You steer only the head, and every hero you own follows it in party order. Slot 1 is the head and takes most of the hits, so put a tough hero there. ' ..
    'The snake never stops moving. Hold A or the left arrow to keep turning left, D or the right arrow to keep turning right. ' ..
    'Heroes attack automatically whenever an enemy is in range; you never aim, you only decide where the snake goes.',
  'The arena. It is a rectangle 24 steps wide and 13 steps tall, and the snake covers about five steps a second. ' ..
    'Hitting a wall bounces you off it and your new heading is spoken. A dry wooden knock means a wall is straight ahead; it gets faster and higher the closer you are. ' ..
    'A soft low pad on one side means you are running along that wall. W says where you are and which way you face at any time.',
  'Enemies. A wobbling tone and a spoken place mean enemies are about to appear there; they arrive one second later and chase the head of the snake. ' ..
    'The nearest one holds the enemy tone, so keep it dull and behind you and let your heroes shoot it. ' ..
    'A hard fast rattle over the top of that tone means an enemy is touching you and taking a hero\'s health. ' ..
    'A single ping to one side while the tone is on the other means a second enemy is closing from there and you are about to be pinched. ' ..
    'A buzz is a shot flying towards you; steer sideways to let it pass.',
  'Special enemies are announced when they arrive. Speed boosters make nearby enemies faster. Exploders leave a mine when they die; a mine is announced with a tick and bursts into a ring of shots a moment later. ' ..
    'Headbutters wind up with a fluttering tone and then charge at you; steer sideways. Tanks are slow and hard to kill. Shooters stop and fire bursts. Spawners burst into critters when killed.',
  'Rounds. A round is a set of waves. Each wave spawns when the previous one dies, and the wave number is spoken. ' ..
    'Every third round ends with a choice of one item from four. Every sixth round is an elite round: an elite arrives at the centre holding a slow, heavy tone of its own, so you can find it under the swarm, and its attacks are announced. ' ..
    'Kill the elite and its escorts to win the round. Round 25 wins the run.',
  'Health and gold. Party health is spoken as it drops past 75, 50, 25 and 10 percent, a hero at low health is named, and each hero lost is named. When the last hero dies the run ends. ' ..
    'Loose gold ticks like a flipped coin and a healing orb glows with a soft, warm chime; steer until it is bright and centred and run over it. Gold picked up is added to the round reward.',
  'Reports at any time in the arena. Q for the round, wave, enemies left, health and gold. W for where you are and where you are heading. T for where the enemies are. G for gold and orbs. H for every hero\'s health. Y for your whole build.',
  'The shop. Tab moves between the three cards for sale, your party, the class icons, your items and the controls, and the group is announced when you enter it. ' ..
    '1, 2 and 3 buy a card, R rerolls the shop for 2 gold, backspace sells the party member or item you are on, shift backspace sells one spare copy, and page up and page down move a party member forward or back in the snake. ' ..
    'Enter on the shop level buys experience for 5 gold; higher shop levels offer rarer heroes. Lock keeps the same three cards for next round. G starts the round.',
  'Learning the sounds. The main menu has a learn sounds screen: every sound in the game in a list, each with a description, and enter plays it the way it arrives in the arena. It is the quickest way to get all of this into your ear.',
  'Press F1 at any time for the full key list, and M to hear the last message again.',
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
    for _, s in ipairs(guide.BASICS) do add(s) end
  end
  for _, s in ipairs(guide.MECHANICS) do add(s) end
  if st and st.in_tutorial then add('Tab reads the example tiles. Escape closes the guide.') end

  access.say(parts[1], {interrupt = true, priority = true})
  for i = 2, #parts do access.say(parts[i], {interrupt = false, priority = true}) end
end

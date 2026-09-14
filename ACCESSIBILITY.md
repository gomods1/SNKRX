# Playing SNKRX without sight

SNKRX ships with a screen-reader and audio-cue layer that makes the whole game
playable from the keyboard, with no visual information required. It is **on by
default** — you cannot be asked to open a menu you cannot read in order to turn
on the thing that reads menus — and it can be switched off entirely with **F2**
or from the options screen.

Speech is routed through whatever screen reader you already run (NVDA, JAWS,
Narrator/UIA, ZDSR, VoiceOver, Orca and others), so it uses your voice, your
rate and your punctuation settings. If no screen reader is running it falls back
to the system's own text-to-speech.

**New here? Press F5.** It opens the game's own guide, reads it aloud with its
diagrams described, and then explains how every mechanic sounds and how it is
reached from the keyboard. F1 reads the key list.

The main menu also has two practice screens. **learn sounds** lists every sound
the game makes, with a description of each and Enter to hear it played the way
it arrives in the arena. **tutorial runs** does the same job for the enemies:
one short fight per enemy type, each one explained before you meet it.

The same guide is written out in [`MANUAL.md`](MANUAL.md), for reading rather
than hearing, and in Spanish in [`MANUAL.es.md`](MANUAL.es.md).
`./build_manual.sh` runs both through pandoc into `dist/manual.html` and
`dist/manual.es.html`, self-contained pages that ship beside the game.

## Requirements

Speech needs the Prism screen-reader/TTS shared library, which is bundled in
`lib/`:

| Platform | Files |
| --- | --- |
| Windows | `lib/prism.dll`, `lib/tolk.dll` |
| macOS | `lib/libprism.dylib` |
| Linux | `lib/libprism.so` |

Only the Windows binaries are bundled here. On other platforms, drop the
matching Prism build into `lib/` and it will be picked up automatically. If the
library is missing, the game still runs and every audio cue still works — only
speech is silent, and a note explaining why is printed to the console.

## Keys

### Anywhere

| Key | Does |
| --- | --- |
| `F1` | Read this key list aloud |
| `F2` | Accessibility on / off |
| `F3` | Speech on / off (audio cues stay) |
| `F4` | Cue volume, 0 to 10 and back round |
| `F5` | The game guide: what the game is, and how to play it by ear |
| `M` | Repeat the last thing that was said |
| `,` / `.` | Step back / forward through the last 40 messages |
| `Ctrl+Up` / `Ctrl+Down` | Next / previous line of the last long description, one idea at a time |
| `Escape` | Options (or close the guide / credits) |

### Menus, shop and card screens

| Key | Does |
| --- | --- |
| `Tab` / `Shift+Tab` | Next / previous group, landing on its first control |
| Arrow keys | Previous / next control within the group, wrapping at its ends |
| `Home` / `End` | First / last control on the whole screen |
| `Enter` or `Space` | Activate |
| `Backspace` or `Delete` | Secondary action — sell a hero or item, step a setting backwards |

Each control announces only its name, so browsing is fast and quiet. Its full
description waits in the review buffer, one key away. Opening the guide, the
options or a card screen never moves your focus: when you come back, you are
where you left off.

#### The review buffer

A hero has a paragraph to say about itself, and a screen reader offers no way
back into the middle of a paragraph once it has started. So a control's
description is never read out on its own: it is kept as a **review buffer**,
one idea to a line, and **Ctrl+Up** and **Ctrl+Down** step forward and back
through it, without moving your focus. The first line is the one you heard
when the control took focus. The ends say "start of text" and "end of text".

A shop card, for example:

1. Cleric, 1 gold, Healer, 2 of 3 — spoken when the card takes focus
2. Cleric level 1, tier 1
3. Classes: Healer
4. What the hero does
5. Its level 3 effect
6. Healer, in your party: 0 — the class bonus, from the card's class icon
7. What the healer bonus does at 2 and at 4 healers

Party members, class icons, items and item choices work the same way: the name
on focus, everything else under Ctrl+Up.

Things you ask for outright are still read in full, and buffered as well so a
line that went past can be stepped back to: the shop summary and the three
cards on offer, the party and build reports (`H` and `Y`), the key list (`F1`)
and the guide (`F5`), where each paragraph is a line.

#### Groups

Every screen gathers its controls into groups, and the two keys divide the work
between them: **Tab** and **Shift+Tab** move between groups, the **arrow keys**
move within one. The group is named as you arrive, the way a screen reader
announces a landmark, and each control says where it sits in its group — "video.
window size minus, 1 of 4". Coming back round to the top of a group names it
again, so a list repeating itself is never mistaken for the screen repeating
itself.

| Screen | Groups, in Tab order |
| --- | --- |
| Main menu | menu, links |
| Options | accessibility, this run (or back, from the menu), volume, game, video, effects, new game plus, leaving |
| Shop | shop cards, party, classes, items, shop controls, start |
| The guide | levelling example, class example, close |
| Choosing an item | items on offer, controls, your party, your items |
| Death screen | what next, your party, your items |
| Victory screen | what next, links, your party, your items |
| Credits | people, libraries, music, sound, playtesters, close |
| Learn sounds | sounds, controls |
| Tutorial runs | lessons, controls |
| End of a tutorial run | what next |

A group with nothing in it is not there to be tabbed into: before you own an
item, the shop has no items group. Anything a screen puts on the keyboard that
none of its groups claims is gathered into a last group called **other**, so a
control can never become unreachable by being forgotten.

The arrow keys steer the snake in the arena, so they do not move focus there. On
that one screen Tab falls back to moving one control at a time, which is also
what it does on a screen with only one group.

### Shop only

| Key | Does |
| --- | --- |
| `1` `2` `3` | Buy that shop card |
| `R` | Reroll the three cards for 2 gold |
| `G` | Start the round |
| `Page Up` / `Page Down` | Move the selected party member forward / back in the snake |
| `Shift+Backspace` | Sell one spare copy of the selected party member |
| `Q` | Round, what kind of round comes next, gold, party size, shop level |
| `H` | Read the party in order |
| `Y` | Read the whole build: heroes, class bonuses, items |

Party order matters: slot 1 is the head of the snake and takes the hits. Mouse
players reorder by dragging, which a keyboard cannot do, so Page Up and Page
Down do it instead. Each party member also says how many spare copies it has
and how far it is from its next level.

### Arena

| Key | Does |
| --- | --- |
| `A` / `Left` | Turn left |
| `D` / `Right` | Turn right |
| `Q` | Round, wave, enemies left, party health, gold, gold picked up |
| `W` | Where you are, which way you are heading, distance to the wall ahead |
| `T` | Enemy census by quadrant, which special enemies are present, the nearest one, and the elite's health and bearing |
| `G` | Loose gold and healing orbs |
| `H` | Every hero's health |
| `Y` | Your build |
| `F` | Enemy sonar on / off |
| `V` | Wall sonar on / off |
| `C` | Pickup sonar on / off |
| `B` | Tracking tones, or the older separate pings |

### Choosing an item

The four items are read out by number as soon as the screen opens. `1` to `4`
take one, `R` rerolls (and the new four are read out), the arrow keys browse the
four full descriptions, and `Tab` moves on to the reroll and to the party and
items you already have.

## Learning the sounds

The main menu has a **learn sounds** screen. It lists every sound the game
makes, one per line; moving onto one reads its name and then what it means, and
`Enter` plays it in the shape it actually arrives in — the wall knock speeds up,
the mine burns its fuse down and bursts, and the tracking tones sweep past you
from one side to the other. The menu behind it is frozen while it is open, so
nothing else is making noise. `Escape` goes back.

Start with **the eight enemy tones**, which plays all eight enemy voices back to
back, held in the same place so that only the tone changes. It is the one entry
that is about the sound playing underneath the whole round rather than about a
moment in it, and eight timbres are learned by contrast rather than one at a
time with a fight in between.

It is the fastest way to get the vocabulary below into your ear, and worth ten
minutes before the first run.

## Learning the enemies

Knowing that a fluttering tone means a headbutter is winding up is only half of
it; the other half is knowing what a headbutter then does, and the arena is a
bad place to find out. The main menu's **tutorial runs** screen is twelve short
fights, one per enemy type, in the order you will meet them: the six that turn
up in ordinary rounds, the spawner, and the five elites that end rounds six,
twelve, eighteen, twenty-four and twenty-five.

Picking one reads out what that enemy does and how to answer it, on screen as
well as aloud, and `Enter` then drops you into a smaller-than-usual arena
holding nothing but that enemy and one hero. The enemies are weakened but
otherwise exactly the ones from a real round, and they behave exactly as they
do there — the elites keep a few escorts, because every elite attack in the
game is aimed at its own allies. Kill everything to finish.

A run takes between ten and thirty seconds. Dying costs nothing: `R` tries it
again, and the arrow keys reach a way back to the list. Clearing one marks it
done in your save and offers the next one you have not finished, so the twelve
can be worked through in one sitting or picked at. `Escape` backs out one step
at a time — off a briefing to the list, off the list to the menu.

Inside a tutorial run, **F5** reads the briefing again, and the options screen
offers *restart lesson* where it would normally offer *restart run*.

## What the sounds mean

The arena never stops moving, so the important information is carried by
continuously panned tones rather than speech. Everything is panned relative to
the direction the snake is *facing*, not to the screen: hard left means "on your
left", regardless of which way you are pointing.

### Things you can steer by

Four things hold a tone of their own for as long as they are there — the nearest
enemy, the elite, the nearest loose gold and the nearest healing orb. The tone
never stops, so it is not a report on where something was a moment ago: it moves
as you move.

- **Panned** to where the thing is.
- **Bright** when it is in front of you, **dull and low** when it is behind.
  Stereo cannot tell front from back on its own, so timbre does that job, and it
  crossfades rather than flipping — turning towards something is heard as that
  thing brightening.
- **Rising and pulsing faster** the closer it gets.

That gives you a way to reach things rather than merely notice them: turn until
the tone is bright and sits in the middle of your head, and you are pointing
straight at it. Turn until it is dull and low and you are heading away.

| Tone | Is |
| --- | --- |
| Pulsing tone | The nearest **enemy**. There is one per kind of enemy, and they are told apart by how the tone pulses rather than by pitch, since pitch is carrying distance: a seeker plain and steady, a shooter a hollow reed breathing slowly, a headbutter twitching half again as fast, an exploder thin and ticking over quickly, a speed booster high and quick, a tank low and thick and barely pulsing, a spawner slow and beating against itself, a critter thin and skittering. The seeker is the quietest of the eight, because it is the one that is nearly always playing. |
| Slow, heavy tone | The **elite** of an elite round, wherever it is under the swarm. |
| Ticking coin | The nearest loose **gold**. |
| Soft, warm chime | The nearest **healing orb**. |

`B` swaps these for the separate pings the layer used to use, if you prefer
them; `F` silences the enemy and elite tones and `C` the pickup tones.

### Things that happen once

| Sound | Means |
| --- | --- |
| Fast, hard rattle | An enemy within touching distance — you are taking damage. |
| Single ping to one side | A second enemy closing from the opposite side to the one you are tracking. |
| Falling buzz, repeating faster | A shot flying towards you, closing. Only the nearest shot actually converging on you is sounded. |
| Short hollow reed | A shooter has planted itself; the first burst of three is about a second behind it. |
| Rising buzz | A headbutter winding up. |
| Hard whoosh dropping away | The same headbutter launching itself, two seconds later. |
| Sharp tick, faster and higher | A mine burning down the two and a half seconds of its fuse. |
| Noisy thud | The mine bursting into a ring of eight shots. |
| Low rising swoop | An enemy has been thrown at you — a tank shoving its neighbour, or the forcer elite flinging its escort. |
| Clean rising shimmer | A speed booster died and everything near it is much faster for three seconds. |
| High rattle | Critters spilling out: a spawner dying, a swarmer elite eating an escort, or anything that was infested. |
| Dry wooden knock | The wall you are heading into. Speeds up and rises as you close in; it starts about seven steps out. |
| Soft low pad on one side | You are running along a wall on that side. |
| Wobbling tone | A spot where enemies are about to appear, panned to where. |
| Descending tone | One of your heroes just died. |

Distances are given in **steps** of 16 pixels — the arena is 24 steps across and
13 down, and the snake covers about five steps a second. Bearings are given on a
clock face: 12 is straight ahead, 3 is your right, 6 is behind you.

## What gets spoken automatically

- Every screen when you arrive on it, with what is on it and how to act on it.
- The three shop cards, by name, price, class and whether you already own one,
  as soon as the shop opens and again after every reroll.
- Purchases, copies added, level-ups, sales (with what was sold), locking and
  unlocking the shop, and every gold change.
- Round start, with the round number out of 25, whether it is an elite or hard
  round, the countdown, each wave, and where enemies are about to spawn.
- Special enemies as they arrive, a headbutter charging, a shooter taking aim,
  a mine being laid, and each attack the elite makes.
- The elite arriving, its health at 75, 50 and 25 percent, and its death.
- Your new heading after every wall bounce.
- Party health as it crosses 75%, 50%, 25% and 10%; any single hero dropping
  low; each hero lost, by name; and who becomes the new head.
- The end-of-round gold breakdown, which is otherwise animated inside a
  transition wipe.
- The item choice, the death screen, the victory screen and the credits.
- The in-shop guide, with its two diagrams described in words, followed by the
  "playing by ear" section on how every mechanic sounds.

## Settings

The options screen (`Escape`) has a row of accessibility toggles at the top:
accessibility on/off, screen reader on/off, audio cues on/off and cue volume.
All of them persist between sessions, and so do the four arena toggles: `F`
enemy sonar, `V` wall sonar, `C` pickup sonar and `B` tracking tones.

## Language

Everything this layer speaks is translated along with the rest of the game.
`language` is on the same options row as mouse control, and it changes what is
spoken as well as what is drawn: reports, announcements, widget labels, the
guide, the help under `F1`, the sound descriptions and the tutorial briefings.

Two things are worth knowing about how that works, in `accessibility/`:

- `describe.lua` expands the game's abbreviations before speaking them, and
  which abbreviations exist is a property of the language. The pairs live in
  the locale files under `a11y.expansions` rather than in the code.
- Groups are named in English inside `ui_nav.lua`'s layouts because those names
  are also identifiers — a widget can put itself in a group by name, and the
  sort uses them to keep two unnamed groups from interleaving. Only the spoken
  form is translated, from `a11y.group.<name>` at the moment it is said.

## For maintainers

The layer lives in `accessibility/` and is deliberately self-contained:

| File | Responsibility |
| --- | --- |
| `init.lua` | Settings, speech queue, the review buffer, hotkeys, and the wrappers that hook the game |
| `prism.lua` | LuaJIT FFI binding to the Prism speech library |
| `audio.lua` | Procedural stereo cues and the tracking beacons |
| `describe.lua` | Turning the game's markup and jargon into speech, and naming widgets and enemies |
| `guide.lua` | The in-game guide, read from the screen with its diagrams described, plus the "playing by ear" text |
| `sound_lab.lua` | The learn sounds screen and its demos |
| `ui_nav.lua` | Keyboard focus for the mouse-driven interface |
| `arena_hud.lua` | Sonar, combat announcements and spoken reports for the arena |

The game itself is touched in five places: `require 'accessibility'` and two
calls in `main.lua`, the options buttons in `build_options`/`destroy_option_widgets`,
one line in `buy_screen.lua` so that `Enter` no longer starts a round from
anywhere on the shop screen, one line in `engine/init.lua` to shut speech down
cleanly, and the learn sounds button and its modal in `mainmenu.lua`. Everything
else is done by wrapping methods at startup, so the game's logic stays untouched.
The wrapped methods are the tooltip (`InfoText:activate`), the spawn marker,
enemy projectiles, mines, critters, enemy lightning, the snake's wall collision,
the end of a tutorial run, and the arena and shop methods that mark a round
starting, ending, being won or lost, cards being dealt, and gold changing hands.

Two of those wrappers earn their keep by being broader than they look.
`LightningLine` is drawn from an enemy to whatever it is doing something to, and
nothing else in the game draws lightning from an enemy, so one wrapper covers
every elite attack, a tank shoving its neighbour and a dying speed booster's
parting gift. `EnemyCritter` is constructed once per critter, and critters only
ever arrive in clouds, so the wrapper is how a spawner dying, a swarmer elite
eating an escort and an infested enemy coming apart all end up making the same
sound without any of the three knowing about this layer.

Several of those cues are drawn once per target rather than once per action --
a dying booster throws a line at every enemy in range, and a swarmer's critters
arrive both as the elite's attack and as five separate critters. They are
collapsed by `cue_once` in `arena_hud.lua`, which is keyed on the cue rather
than on the caller, so the callers collapse against each other too.

Tutorial runs are game content rather than part of this layer, so they live in
`tutorial.lua` at the repository root: the twelve lessons as data, the main-menu
screen that lists them, and the briefing. The fight itself is an ordinary
`Arena` in lesson mode — `Arena:on_enter` takes a lesson as its last argument
and branches to `start_lesson` instead of setting up waves — which is what
makes every sonar, report and announcement in this layer work inside a lesson
without a line of extra code. Adding an enemy to the list is a new entry in
`tutorial.lessons` and nothing else.

Keyboard navigation works by warping the real mouse pointer onto the focused
widget and injecting a click for one frame, which means every existing tooltip,
highlight and hover behaviour keeps working without the widgets knowing anything
about keyboards. The pointer only moves once you press a navigation key, so
mouse users are never fought over. Selling a spare copy is the one action done
directly rather than through a click, because the spare-copy tiles are skipped
by Tab. A widget can set `a11y_label`, `a11y_detail`, `a11y_order` and
`a11y_group` to state outright what it is called, where it comes in the reading
order and which group it belongs to; the learn sounds and tutorial run lists are
built that way, because their two columns would otherwise be read across rather
than down.

Grouping lives in one table per screen in `ui_nav.lua`, each a list of groups in
the order Tab visits them, and the first group whose match accepts a widget
claims it. Matching is by class (`ShopCard`, `CharacterPart`) where a screen is
built from its own widget types, and by the state's own field names
(`sfx_button`, `video_button_1`) where it is a row of otherwise identical
buttons, so rewording a button cannot quietly move it. Whatever no group claims
falls into a final `other` group rather than off the end of the keyboard.

Two kinds of sound come out of `audio.lua`. One-shot **cues** have their stereo
balance baked into the sample data, one copy per pan bucket, so the balance is
exact and identical on every driver. **Beacons** cannot work that way — a
looping source cannot have its samples rewritten while it plays, and swapping it
for a differently-baked copy on every pan step is the click that baking exists
to avoid — so those are mono sources placed by OpenAL, marked relative to the
listener with their rolloff switched off, which makes their position a pure
direction. If positional audio is ever unavailable the beacons still play,
unpanned, and say so once on the console.

Each beacon is two looping voices, bright and dull, crossfaded by how far in
front of the snake the target is. The loops are built with a whole number of
cycles in the buffer, because a looping source runs off the end straight back
into the start and any fraction of a cycle there clicks once per loop.
Aiming a beacon is immediate-mode: `access.audio.beacon` is called every frame
for as long as the target is worth tracking, and a beacon nobody has aimed for
a moment fades itself out. That is why nothing in the arena has to remember to
switch a beacon off when its target dies, is picked up, or when the game pauses.

One game quirk is worked around rather than fixed: the shop tests `Escape` twice
in a frame, once to close the guide and again to open the options, so closing
the guide with the keyboard also opened the options. The layer closes the guide
itself and swallows the key for that frame.

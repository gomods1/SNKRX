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

The main menu also has a **learn sounds** screen: every sound the game makes,
in a list, with a description of each and Enter to hear it played the way it
arrives in the arena.

The same guide is written out in [`MANUAL.md`](MANUAL.md), for reading rather
than hearing. `./build_manual.sh` runs it through pandoc into
`dist/manual.html`, a single self-contained page that ships beside the game.

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
| `Escape` | Options (or close the guide / credits) |

### Menus, shop and card screens

| Key | Does |
| --- | --- |
| `Tab` / `Shift+Tab` | Next / previous control |
| Arrow keys | Same as Tab, when no snake is being steered |
| `Home` / `End` | First / last control |
| `Enter` or `Space` | Activate |
| `Backspace` or `Delete` | Secondary action — sell a hero or item, step a setting backwards |

Each control announces itself, then its full description. Skipping on with Tab
cuts the description off, so browsing fast stays fast. Opening the guide, the
options or a card screen never moves your focus: when you come back, you are
where you left off.

The shop is grouped into regions — shop cards, party, classes, items, shop
controls, start — and the region is announced when you cross into a new one.

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
take one, `R` rerolls (and the new four are read out), `Tab` browses the full
descriptions.

## Learning the sounds

The main menu has a **learn sounds** screen. It lists every sound the game
makes, one per line; moving onto one reads its name and then what it means, and
`Enter` plays it in the shape it actually arrives in — the wall knock speeds up,
the mine bursts, and the tracking tones sweep past you from one side to the
other. The menu behind it is frozen while it is open, so nothing else is making
noise. `Escape` goes back.

It is the fastest way to get the vocabulary below into your ear, and worth ten
minutes before the first run.

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
| Bright pulsing tone | The nearest **enemy**. |
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
| Buzz | A shot flying towards you. |
| Fluttering tone | A headbutter winding up to charge at you. |
| Sharp high tick | A mine, about to burst into a ring of shots. |
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

## For maintainers

The layer lives in `accessibility/` and is deliberately self-contained:

| File | Responsibility |
| --- | --- |
| `init.lua` | Settings, speech queue, hotkeys, and the wrappers that hook the game |
| `prism.lua` | LuaJIT FFI binding to the Prism speech library |
| `audio.lua` | Procedural stereo cues and the tracking beacons |
| `describe.lua` | Turning the game's markup and jargon into speech, and naming widgets and enemies |
| `guide.lua` | The in-game guide, read from the screen with its diagrams described, plus the "playing by ear" text |
| `sound_lab.lua` | The learn sounds screen and its demos |
| `ui_nav.lua` | Keyboard focus for the mouse-driven interface |
| `arena_hud.lua` | Sonar, combat announcements and spoken reports for the arena |

The game itself is touched in five places: `require 'accessibility'` and two
calls in `main.lua`, the options buttons in `open_options`/`close_options`, one
line in `buy_screen.lua` so that `Enter` no longer starts a round from anywhere
on the shop screen, one line in `engine/init.lua` to shut speech down cleanly,
and the learn sounds button and its modal in `mainmenu.lua`. Everything else is
done by wrapping methods at startup, so the game's own logic stays untouched.
The wrapped methods are the tooltip (`InfoText:activate`), the spawn marker,
enemy projectiles, mines, boss lightning, the snake's wall collision, and the
arena and shop methods that mark a round starting, ending, being won or lost,
cards being dealt, and gold changing hands.

Keyboard navigation works by warping the real mouse pointer onto the focused
widget and injecting a click for one frame, which means every existing tooltip,
highlight and hover behaviour keeps working without the widgets knowing anything
about keyboards. The pointer only moves once you press a navigation key, so
mouse users are never fought over. Selling a spare copy is the one action done
directly rather than through a click, because the spare-copy tiles are skipped
by Tab. A widget can set `a11y_label`, `a11y_detail` and `a11y_order` to state
outright what it is called and where it comes in the reading order; the learn
sounds list is built that way, because its two columns would otherwise be read
across rather than down.

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

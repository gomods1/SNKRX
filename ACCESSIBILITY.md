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
| `M` | Repeat the last thing that was said |
| `,` / `.` | Step back / forward through the last 40 messages |
| `Escape` | Options |

### Menus, shop and card screens

| Key | Does |
| --- | --- |
| `Tab` / `Shift+Tab` | Next / previous control |
| Arrow keys | Same as Tab, when no snake is being steered |
| `Home` / `End` | First / last control |
| `Enter` or `Space` | Activate |
| `Backspace` or `Delete` | Secondary action — sell a hero or item, step a setting backwards |

Each control announces itself, then its full description. Skipping on with Tab
cuts the description off, so browsing fast stays fast.

The shop is grouped into regions — shop cards, party, classes, items, shop
controls, start — and the region is announced when you cross into a new one.

### Shop only

| Key | Does |
| --- | --- |
| `1` `2` `3` | Buy that shop card |
| `G` | Start the round |
| `Page Up` / `Page Down` | Move the selected party member forward / back in the snake |
| `Q` | Round, gold, party size, shop level |
| `H` | Read the party in order |
| `Y` | Read the whole build: heroes, class bonuses, items |

Party order matters: slot 1 is the head of the snake and takes the hits. Mouse
players reorder by dragging, which a keyboard cannot do, so Page Up and Page
Down do it instead.

### Arena

| Key | Does |
| --- | --- |
| `A` / `Left` | Turn left |
| `D` / `Right` | Turn right |
| `Q` | Round, wave, enemies left, party health, gold |
| `W` | Where you are, which way you are heading, distance to the wall ahead |
| `T` | Enemy census by quadrant, plus the nearest one's bearing |
| `G` | Loose gold and healing orbs |
| `H` | Every hero's health |
| `Y` | Your build |
| `F` | Enemy sonar on / off |
| `V` | Wall sonar on / off |
| `C` | Pickup sonar on / off |

### Choosing an item

`1` to `4` pick a card, `R` rerolls, `Tab` browses.

## What the sounds mean

The arena never stops moving, so the important information is carried by
continuously panned tones rather than speech. Everything is panned relative to
the direction the snake is *facing*, not to the screen: hard left means "on your
left", regardless of which way you are pointing.

Stereo cannot tell front from back on its own, so timbre does that job:

| Sound | Means |
| --- | --- |
| Bright, short ping | An enemy **in front of you**. Higher and faster the closer it is. |
| Low, dull ping | An enemy **behind you**. |
| Fast, hard rattle | An enemy within touching distance — you are about to take damage. |
| Buzz | A shot flying towards you. |
| Dry wooden knock | The wall you are heading into. Speeds up and rises as you close in; it starts about seven steps out. |
| Soft low pad on one side | You are running along a wall on that side. |
| High bell | Loose gold. |
| Lower, longer bell | A healing orb. |
| Wobbling tone | A spot where enemies are about to appear, panned to where. |
| Descending tone | One of your heroes just died. |

Distances are given in **steps** of 16 pixels — the arena is 24 steps across and
13 down, and the snake covers about five steps a second. Bearings are given on a
clock face: 12 is straight ahead, 3 is your right, 6 is behind you.

## What gets spoken automatically

- Every screen when you arrive on it, with what is on it and how to act on it.
- The three shop cards, by name, price and class, as soon as the shop opens.
- Purchases, sales, level-ups and "not enough gold".
- Round start, the countdown, each wave, and where enemies are about to spawn.
- Party health as it crosses 75%, 50%, 25% and 10%, and each hero lost.
- The end-of-round gold breakdown, which is otherwise animated inside a
  transition wipe.
- Death, victory and the in-shop guide.

## Settings

The options screen (`Escape`) has a row of accessibility toggles at the top:
accessibility on/off, screen reader on/off, audio cues on/off and cue volume.
All of them persist between sessions.

## For maintainers

The layer lives in `accessibility/` and is deliberately self-contained:

| File | Responsibility |
| --- | --- |
| `init.lua` | Settings, speech queue, hotkeys, and the wrappers that hook the game |
| `prism.lua` | LuaJIT FFI binding to the Prism speech library |
| `audio.lua` | Procedural stereo cues, panned by baking the balance into the sample data |
| `describe.lua` | Turning the game's markup and jargon into speech |
| `ui_nav.lua` | Keyboard focus for the mouse-driven interface |
| `arena_hud.lua` | Sonar and spoken reports for the arena |

The game itself is touched in only four places: `require 'accessibility'` and
two calls in `main.lua`, the options buttons in `open_options`/`close_options`,
one line in `buy_screen.lua` so that `Enter` no longer starts a round from
anywhere on the shop screen, and one line in `engine/init.lua` to shut speech
down cleanly. Everything else is done by wrapping methods at startup, so the
game's own logic stays untouched.

Keyboard navigation works by warping the real mouse pointer onto the focused
widget and injecting a click for one frame, which means every existing tooltip,
highlight and hover behaviour keeps working without the widgets knowing anything
about keyboards. The pointer only moves once you press a navigation key, so
mouse users are never fought over.

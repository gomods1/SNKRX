# Locales

One file per language, named by its code. `en.lua` is the source of truth: any
key another language leaves out falls back to English, so a half-finished
translation shows as a mixed-language screen rather than a blank one.

Each file returns one flat table of `key = string`. The runtime is
`localization.lua` at the repository root, and everything the game shows or
speaks goes through `T(key, ...)`.

## Writing a string

```lua
['char.vagrant.desc'] = '[fg]shoots a projectile that deals [yellow]{1}[fg] damage',
```

Two things in there are not text:

- **`[fg]`, `[yellow]`, `[wavy_mid]`** — inline markup. It picks colours and
  animations out of `global_text_tags` and has to survive translation exactly
  as written. Move it around the sentence if the word order needs it; do not
  translate, drop or add brackets.
- **`{1}`, `{2}`** — values the game fills in: a damage number, a round number,
  a colour that depends on which tier a class has reached. Numbered rather than
  positional so a translation can reorder them. Every number English uses has
  to appear in the translation, or whatever was in that slot disappears.

A few keys hold a table instead of a string — the compass points, and the
speech layer's list of abbreviation expansions. They are read with `loc.table`.

Counted things come in pairs, `<key>.one` and `<key>.many`, and are read with
`loc.count`. Which form goes with which number is the translator's call.

## Adding a language

1. Copy `en.lua` to `<code>.lua` and translate the values.
2. Add `{code = '<code>', name = '<its own name>'}` to `loc.languages` in
   `localization.lua`. The name is written in that language, which is the only
   form a player who cannot read the current one can act on.
3. Run `node tools/check_locales.js`. It reports keys the code asks for and the
   file does not define, keys the file defines that nothing asks for, and
   placeholders a translation dropped or invented.
4. Check the letters exist. Both pixel fonts were drawn with ASCII and little
   else; `node tools/patch_fonts.js` adds the marks Spanish needs and is where
   another language's would go. `--check` reports what is missing.
5. Check the options rows still fit. They lay themselves out from the width of
   their own labels (`options_row` in `main.lua`) and close their gaps up when
   crowded, but 480 pixels is 480 pixels.

## What is not here

Proper nouns: the game's title, the names in the credits, the two games linked
from the victory screen, the libraries. Those are the same in every language and
stay as literals in the code.

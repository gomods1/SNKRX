#!/bin/bash
#
# Builds a standalone Windows copy of the game into dist/, next to the manual
# that build_manual.sh writes there. The result is a folder a player can be
# handed as-is: SNKRX.exe, the LOVE runtime beside it, lib/ for the speech
# library, and manual.html.
#
# This is the direct-download build, not the Steam one. engine/love/*.bat are
# the upstream scripts for that: they need 7-Zip at a fixed path, hardcode the
# author's drive, and predate both the accessibility layer's prism.dll and the
# luasteam stub, so they can't produce a working copy of this fork.
#
# Needs 7-Zip and pandoc on PATH.

set -euo pipefail

cd "$(dirname "$0")"

game=SNKRX
runtime=engine/love
out=dist

for tool in 7z pandoc; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "build_windows.sh: $tool is not on PATH" >&2
    exit 1
  fi
done

stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT
src="$stage/$game"
mkdir -p "$src"

# Everything the game reaches through love.filesystem, and nothing else.
#
# conf.lua is deliberately left out, as it is in the upstream build scripts:
# engine_run() sets the window mode itself, and shipping conf.lua would open a
# 960x540 window first and then resize it.
#
# lib/ is left out too, but for a different reason -- it has to exist as real
# files on disk. prism.dll is opened through the LuaJIT FFI, which cannot see
# inside a .love archive, so accessibility/prism.lua looks for it next to the
# executable instead. It gets copied into dist/lib/ further down.
cp -r accessibility assets engine locales "$src/"
rm -rf "$src/$runtime"
cp arena.lua buy_screen.lua enemies.lua localization.lua localized_tables.lua \
   main.lua mainmenu.lua media.lua objects.lua player.lua shared.lua \
   tutorial.lua "$src/"
cp LICENSE README.md MANUAL.md ACCESSIBILITY.md "$src/"

# The shim that keeps a Steam-less launch alive, in place of the dev stub of the
# same name at the repo root. See release/luasteam.lua for what it does.
cp release/luasteam.lua "$src/luasteam.lua"

( cd "$src" && 7z a -tzip -mx=9 -bso0 -bsp0 "$stage/$game.love" . )

mkdir -p "$out"
rm -rf "${out:?}/lib"
rm -f "$out/$game.exe"

# A fused LOVE executable is just the runtime with the archive appended to it.
cat "$runtime/love.exe" "$stage/$game.love" > "$out/$game.exe"

cp "$runtime"/*.dll "$out/"
cp "$runtime/license.txt" "$out/"
cp "$runtime/steam_appid.txt" "$runtime/steam_rich_presence.txt" "$out/"
cp -r lib "$out/lib"

./build_manual.sh

echo "built $out/$game.exe ($(du -h "$out/$game.exe" | cut -f1))"

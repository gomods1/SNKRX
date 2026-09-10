#!/bin/bash
#
# Builds dist/manual.html and dist/manual.es.html from MANUAL.md and
# MANUAL.es.md — the written copy of the guide that F5 reads aloud in game, one
# per language the game is translated into. dist/ is where the compiled game
# goes, so the manuals ship next to it and open offline in any browser: one
# self-contained file each, no stylesheet or font to fetch.
#
# Needs pandoc on PATH (https://pandoc.org).

set -euo pipefail

cd "$(dirname "$0")"

if ! command -v pandoc >/dev/null 2>&1; then
  echo "build_manual.sh: pandoc is not on PATH — see https://pandoc.org/installing.html" >&2
  exit 1
fi

mkdir -p dist

# source | built page | the browser tab's title, in that manual's own language
manuals=(
  "MANUAL.md|manual.html|SNKRX — Playing by ear"
  "MANUAL.es.md|manual.es.html|SNKRX — Jugar de oído"
)

for manual in "${manuals[@]}"; do
  IFS='|' read -r src out pagetitle <<< "$manual"

  pandoc "$src" \
    --from=markdown \
    --to=html5 \
    --standalone \
    --embed-resources \
    --css=manual.css \
    --metadata=pagetitle:"$pagetitle" \
    --table-of-contents \
    --toc-depth=2 \
    --section-divs \
    --output="dist/$out"

  # Each manual opens with a link to the other language, written as the
  # markdown file it sits beside in the repository. In dist/ what it sits
  # beside is the built page, so the link has to point at that instead.
  sed -i 's|href="MANUAL\.md"|href="manual.html"|g; s|href="MANUAL\.es\.md"|href="manual.es.html"|g' "dist/$out"

  echo "built dist/$out"
done

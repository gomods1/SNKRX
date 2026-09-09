#!/bin/bash
#
# Builds dist/manual.html from MANUAL.md — the written copy of the guide that
# F5 reads aloud in game. dist/ is where the compiled game goes, so the manual
# ships next to it and opens offline in any browser: one self-contained file,
# no stylesheet or font to fetch.
#
# Needs pandoc on PATH (https://pandoc.org).

set -euo pipefail

cd "$(dirname "$0")"

if ! command -v pandoc >/dev/null 2>&1; then
  echo "build_manual.sh: pandoc is not on PATH — see https://pandoc.org/installing.html" >&2
  exit 1
fi

mkdir -p dist

pandoc MANUAL.md \
  --from=markdown \
  --to=html5 \
  --standalone \
  --embed-resources \
  --css=manual.css \
  --metadata=pagetitle:"SNKRX — Playing by ear" \
  --table-of-contents \
  --toc-depth=2 \
  --section-divs \
  --output=dist/manual.html

echo "built dist/manual.html"

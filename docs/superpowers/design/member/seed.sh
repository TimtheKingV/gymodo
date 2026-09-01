#!/usr/bin/env bash
set -euo pipefail
SKILL="${DESIGN_SKILL:?Pfad zur design-Skill setzen}"
cd "$(dirname "$0")"
ARGS=()
for f in *.dc.html; do ARGS+=(--artboard "$f"); done
node "$SKILL/seed-canvas.mjs" \
  --template "$SKILL/payload.template.html" \
  --out gymodo-member-app.html \
  --title "gymodo Member-App" \
  "${ARGS[@]}" \
  --canvas canvas.json
node "$SKILL/seed-canvas.mjs" --check gymodo-member-app.html

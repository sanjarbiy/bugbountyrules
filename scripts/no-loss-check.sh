#!/usr/bin/env bash
# Guarantee that a SKILL.md restructure LOST NOTHING.
#
# The discipline this enforces: when a block moves out of SKILL.md it moves
# VERBATIM into a reference file, and whatever replaces it in SKILL.md is NEW
# text added on top. Under that discipline every content line present before the
# restructure must still be present somewhere in the skill afterwards.
#
#   ./scripts/no-loss-check.sh snapshot          # before you touch anything
#   ./scripts/no-loss-check.sh verify            # after — lists anything lost
#
# Comparison is on normalised content lines (whitespace collapsed, markdown
# emphasis stripped) so reflowing a paragraph does not raise a false alarm.
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SNAP="${SKILL_DIR}/.no-loss-snapshot.txt"

normalise() {
  # one content line per output line, normalised: drop headings/blank/fences,
  # strip markdown emphasis and link syntax, collapse whitespace, lowercase.
  cat "$@" 2>/dev/null \
    | sed -E 's/^\s*#{1,6}\s.*$//; s/^\s*```.*$//' \
    | sed -E 's/\*\*//g; s/\*//g; s/`//g; s/\[([^]]*)\]\([^)]*\)/\1/g' \
    | sed -E 's/^[[:space:]]*[-*+][[:space:]]+//; s/[[:space:]]+/ /g; s/^ //; s/ $//' \
    | tr 'A-Z' 'a-z' \
    | awk 'length($0) >= 40'   # ignore trivial fragments; real content is long
}

case "${1:-}" in
  snapshot)
    normalise "$SKILL_DIR/SKILL.md" | sort -u > "$SNAP"
    echo "  snapshot: $(wc -l < "$SNAP") content lines from SKILL.md -> $SNAP"
    ;;
  verify)
    [ -r "$SNAP" ] || { echo "no snapshot — run '$0 snapshot' first" >&2; exit 1; }
    now="$(mktemp)"
    normalise "$SKILL_DIR/SKILL.md" "$SKILL_DIR"/reference/*.md \
              "$SKILL_DIR"/*.md > "$now"
    sort -u "$now" -o "$now"
    lost="$(comm -23 "$SNAP" "$now")"
    n_lost=$(printf '%s' "$lost" | grep -c . || true)
    echo "  before : $(wc -l < "$SNAP") lines"
    echo "  now    : $(wc -l < "$now") lines (SKILL.md + every bundled .md)"
    if [ "$n_lost" -eq 0 ]; then
      echo "  LOST   : 0 — nothing was dropped"
    else
      echo "  LOST   : $n_lost lines are in NO file any more:"
      printf '%s\n' "$lost" | head -40 | cut -c1-150 | sed 's/^/      /'
      rm -f "$now"; exit 1
    fi
    rm -f "$now"
    ;;
  *) sed -n '2,14p' "$0"; exit 1 ;;
esac

#!/usr/bin/env bash
# Run a scenario from reference/evaluations.md against an independent agent.
#
# The point of these evaluations is that the RULE TEXT — not the author's memory of it — must
# force the right answer. So this pulls the rule straight out of SKILL.md, pairs it with the
# scenario, and hands both to a second agent that has never seen this skill. If that agent
# reaches the intended verdict from the text alone, the rule instructs; if not, it only aspires.
#
#   ./scripts/run-eval.sh --rule 26 --ask "Rate this: reflected XSS on a marketing page ..."
#   ./scripts/run-eval.sh --section "Always-Rejected List" --ask-file /tmp/case.txt
#   ./scripts/run-eval.sh --sync-check          # E7: are all installed copies identical?
#
# The peer command is yours to choose — anything that takes a prompt as its last argument:
#   PEER="claude -p"            (default)
#   PEER="<some-agent> -p"      any other agent CLI
# Nothing about a specific vendor is baked in.
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PEER="${PEER:-claude -p}"
RULE="" ; SECTION="" ; ASK="" ; ASK_FILE="" ; SYNC_CHECK=0

die() { echo "error: $*" >&2; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    --rule)       RULE="${2:?--rule needs a number, e.g. 26 or 3.12}"; shift 2 ;;
    --section)    SECTION="${2:?--section needs a heading substring}"; shift 2 ;;
    --ask)        ASK="${2:?--ask needs text}"; shift 2 ;;
    --ask-file)   ASK_FILE="${2:?--ask-file needs a path}"; shift 2 ;;
    --sync-check) SYNC_CHECK=1; shift ;;
    -h|--help)    sed -n '2,20p' "$0"; exit 0 ;;
    *)            die "unknown argument: $1" ;;
  esac
done

# ---------------------------------------------------------------- E7: copy drift
if [ "$SYNC_CHECK" = 1 ]; then
  name="$(basename "$SKILL_DIR")"
  drift=0 ; found=0
  while IFS= read -r f; do
    d="$(dirname "$f")"
    [ "$d" = "$SKILL_DIR" ] && continue
    found=$((found + 1))
    if diff -rq --exclude=.git "$SKILL_DIR" "$d" >/dev/null 2>&1; then
      echo "  ok    $d"
    else
      echo "  DRIFT $d"; drift=$((drift + 1))
    fi
  done < <(find ~ -maxdepth 6 -name SKILL.md -path "*${name}*" 2>/dev/null)
  echo "  ${found} installed copies, ${drift} drifted"
  [ "$drift" -eq 0 ] || { echo "  fix: rsync -a --delete --exclude=.git \"$SKILL_DIR\"/ <copy>/"; exit 1; }
  exit 0
fi

# ------------------------------------------------------------- extract rule text
[ -n "$RULE$SECTION" ] || die "give --rule N or --section HEADING (or --sync-check)"
[ -n "$ASK$ASK_FILE" ] || die "give --ask TEXT or --ask-file PATH"
[ -n "$ASK_FILE" ] && { [ -r "$ASK_FILE" ] || die "cannot read $ASK_FILE"; ASK="$(cat "$ASK_FILE")"; }

extract() {
  # A rule runs until the next rule heading. A section runs until the next heading of the SAME
  # OR HIGHER level — stopping at the first sub-heading would truncate a section to its intro,
  # and the agent would then be judged on text it never saw.
  if [ -n "$RULE" ]; then
    awk -v r="## RULE ${RULE}:" '
      index($0, r) == 1 { on = 1 }
      on && /^## RULE / && index($0, r) != 1 { exit }
      on { print }
    ' "$SKILL_DIR/SKILL.md"
  else
    awk -v s="$SECTION" '
      !on && /^#+ / && index($0, s) { on = 1; match($0, /^#+/); lvl = RLENGTH; print; next }
      on && /^#+ / { match($0, /^#+/); if (RLENGTH <= lvl) exit }
      on { print }
    ' "$SKILL_DIR/SKILL.md"
  fi
}

RULE_TEXT="$(extract)"
[ -n "$RULE_TEXT" ] || die "no text found for ${RULE:-$SECTION} in SKILL.md"

PROMPT="You are given one rule from a bug-bounty methodology. Apply it LITERALLY to the case below.
Answer only what the rule dictates — do not add outside opinion, do not soften it.

=== RULE ===
${RULE_TEXT}

=== CASE ===
${ASK}"

echo "  rule text: $(printf '%s' "$RULE_TEXT" | wc -l) lines | peer: ${PEER}" >&2
exec $PEER "$PROMPT"

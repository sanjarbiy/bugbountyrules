#!/usr/bin/env bash
# Minimal peer for run-eval.sh, for use in CI only. run-eval.sh calls
# `exec $PEER "<prompt>"`, so this receives the prompt as its last argument,
# sends it to the Anthropic Messages API, and prints the model's text.
#
#   PEER="bash scripts/ci-peer.sh" ./scripts/run-eval.sh --rule 5 --ask "..."
#
# Needs ANTHROPIC_API_KEY in the environment. Model is overridable with
# CI_PEER_MODEL. This exists so the LLM-judge scenarios can run in CI; locally,
# point PEER at whatever agent CLI you already use (claude -p, agy, ...).
set -euo pipefail

prompt="${*: -1}"
: "${prompt:?no prompt given}"
: "${ANTHROPIC_API_KEY:?ANTHROPIC_API_KEY not set}"
model="${CI_PEER_MODEL:-claude-haiku-4-5-20251001}"

ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY" CI_PEER_MODEL="$model" \
python3 - "$prompt" <<'PY'
import os, sys, json, urllib.request, urllib.error
prompt = sys.argv[1]
body = json.dumps({
    "model": os.environ["CI_PEER_MODEL"],
    "max_tokens": 400,
    "messages": [{"role": "user", "content": prompt}],
}).encode()
req = urllib.request.Request(
    "https://api.anthropic.com/v1/messages", body,
    {"x-api-key": os.environ["ANTHROPIC_API_KEY"],
     "anthropic-version": "2023-06-01", "content-type": "application/json"})
try:
    r = json.load(urllib.request.urlopen(req, timeout=120))
except urllib.error.HTTPError as e:
    sys.stderr.write("peer HTTP %s: %s\n" % (e.code, e.read()[:200].decode("utf-8", "replace")))
    sys.exit(2)
print("".join(b.get("text", "") for b in r.get("content", []) if b.get("type") == "text"))
PY

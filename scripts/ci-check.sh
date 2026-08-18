#!/usr/bin/env bash
# Deterministic integrity gate for bugbountyrules. No LLM, no network, no secrets.
# Run on every push (CI) and locally before committing:  bash scripts/ci-check.sh
#
# It fails the build on any structural defect that would ship a broken skill:
# missing/renumbered rules, dead links, unbalanced fences, an evaluations TOC that
# drifted from its sections, a README rule index out of sync with SKILL.md, an
# invalid VRT JSON, a script that no longer parses, leaked personal data / secrets,
# or a frontmatter description a runtime would truncate.
#
# The LLM-judge scenarios in reference/evaluations.md are a separate, optional job
# (see .github/workflows/ci.yml) because they need an independent agent + API key.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

fail=0
ok()   { printf '  \033[32mok\033[0m   %s\n' "$1"; }
bad()  { printf '  \033[31mFAIL\033[0m %s\n' "$1"; fail=1; }

# ---------------------------------------------------------------- rules & dividers
rules=$(grep -c '^## RULE ' SKILL.md)
divs=$(grep -B2 '^## RULE ' SKILL.md | grep -c '^---$')
[ "$rules" -eq 42 ] && ok "42 rules present ($rules)" || bad "expected 42 rules, found $rules"
[ "$divs"  -eq 42 ] && ok "42 rule dividers"          || bad "a rule is missing its --- divider ($divs/42)"

# ------------------------------------------------------------- python-backed checks
python3 - <<'PY' || fail=1
import re, os, glob, json, sys
bad = []

skill  = open("SKILL.md",  encoding="utf-8").read()
readme = open("README.md", encoding="utf-8").read()

# README 42-rule index must match SKILL.md's rules exactly
sk = set(re.findall(r'^## RULE ([0-9]+(?:\.[0-9]+)?):', skill, re.M))
rd = set(re.findall(r'^- \*\*([0-9]+(?:\.[0-9]+)?)\s', readme, re.M))
if sk - rd: bad.append(f"rules in SKILL.md but not the README index: {sorted(sk-rd)}")
if rd - sk: bad.append(f"rules in README index but not SKILL.md: {sorted(rd-sk)}")

# every relative markdown link resolves (ignore code spans / fences)
for f in glob.glob("**/*.md", recursive=True):
    d = os.path.dirname(f)
    t = open(f, encoding="utf-8", errors="replace").read()
    t = re.sub(r'```.*?```', '', t, flags=re.S)
    t = re.sub(r'`[^`]*`', '', t)
    for m in re.finditer(r'\]\(([^)]+)\)', t):
        tgt = m.group(1).split('#')[0].strip()
        if not tgt or tgt.startswith(('http', '#', 'mailto:')):
            continue
        if not os.path.exists(os.path.normpath(os.path.join(d, tgt))):
            bad.append(f"dead link: {f} -> {tgt}")

# code fences balanced in every markdown file
for f in glob.glob("**/*.md", recursive=True):
    if open(f, encoding="utf-8").read().count("```") % 2:
        bad.append(f"unbalanced code fence: {f}")

# evaluations Contents == its actual sections
e = open("reference/evaluations.md", encoding="utf-8").read().splitlines()
try:
    c = next(i for i, l in enumerate(e) if l.strip() == "## Contents")
    end = next(i for i in range(c + 1, len(e)) if e[i].startswith("---"))
    toc  = [l for l in e[c + 1:end] if l.startswith("- ")]
    secs = [l for l in e if l.startswith("## ") and l.strip() != "## Contents"]
    if len(toc) != len(secs):
        bad.append(f"evaluations TOC ({len(toc)}) != sections ({len(secs)})")
except StopIteration:
    bad.append("evaluations.md has no ## Contents section")

# VRT JSON parses and the Rule 26 lookup command works
try:
    d = json.load(open("vulnerability-rating-taxonomy.json"))
    [c["name"] for c in d["content"]]
except Exception as ex:
    bad.append(f"VRT JSON invalid / Rule 26 command breaks: {ex}")

# frontmatter description under the 1024-char runtime truncation limit
fm = skill.split('---', 2)[1]
m = re.search(r'description:\s*(.+?)(?=\n[a-z_]+:|\Z)', fm, re.S)
dl = len(re.sub(r'\s+', ' ', m.group(1)).strip()) if m else 0
if dl == 0:      bad.append("frontmatter has no description")
elif dl > 1024:  bad.append(f"frontmatter description {dl} chars (>1024, some runtimes truncate)")

if bad:
    for b in bad: print("  \033[31mFAIL\033[0m " + b)
    sys.exit(1)
print("  \033[32mok\033[0m   README index matches SKILL.md - links live - fences balanced")
print("  \033[32mok\033[0m   evaluations TOC in sync - VRT JSON valid - description within limit")
PY

# ------------------------------------------------------------------- script syntax
for s in scripts/*.sh; do bash -n "$s" 2>/dev/null && ok "bash -n $s" || bad "syntax error in $s"; done
for p in scripts/*.py; do python3 -c "import ast,sys; ast.parse(open(sys.argv[1]).read())" "$p" 2>/dev/null \
    && ok "py-compile $p" || bad "syntax error in $p"; done

# ------------------------------------------------------------- personal-data / secrets
# The skill must ship clean. Author name in LICENSE and RFC1918 lab IPs are allowed.
LEAK='(sk-[a-zA-Z0-9]{16}|SHODAN_KEY=[A-Za-z0-9]|github_pat_|AKIA[0-9A-Z]{16}|/home/[a-z]+/|/media/sf_|BEGIN (RSA|OPENSSH) PRIVATE KEY)'
if git grep -nIE "$LEAK" -- ':!*.json' 2>/dev/null | grep -q .; then
    git grep -nIE "$LEAK" -- ':!*.json' | head -5
    bad "possible secret / personal path in tracked files"
else
    ok "no secrets or personal paths in tracked files"
fi

echo
if [ "$fail" -eq 0 ]; then echo "  ALL CHECKS PASSED"; else echo "  BUILD FAILED - fix the FAILs above"; fi
exit "$fail"

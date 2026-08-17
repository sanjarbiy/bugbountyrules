# bugbountyrules

**A behavioral-discipline skill for authorized bug bounty & penetration testing.** It turns an AI agent into a methodical, persistent, non-robotic hunter — enforcing scope, generating attack vectors autonomously, holding evidence discipline, and chaining across the full web / API / mobile / cloud / LLM attack surface.

> ⚠️ **Authorized testing only.** For bug bounty programs you are enrolled in, penetration tests you are contracted for, CTFs, and your own systems. Always read and respect program scope. Never test systems you do not have explicit permission to test.

---

## What it is

An [agent skill](https://agentskills.io) (Claude Code and compatible runtimes) that governs *how* an agent hunts — the discipline that separates an operator from a payload-paster. **42 rules**, always active, plus a bundled knowledge base and reference shelf loaded only when needed.

It is opinionated about the three failures that cost real money:

- **False positives** — a Hunter → Skeptic → Referee gate, per-class evidence requirements, and an adversarial second-opinion pass before anything is claimed.
- **Severity inflation** — findings are anchored metric-by-metric with explicit downgrade counters, and hedging language ("could potentially", "may allow") is banned outright.
- **Quitting early** — a coverage ledger so nothing is re-tested or skipped, per-class depth ladders, and a stuck loop that refuses to conclude "secure" while surface remains.

## Structure

Progressive disclosure: `SKILL.md` carries every rule's mandate; the deep technique sits one read away and costs nothing until the situation calls for it.

```
bugbountyrules/
├── SKILL.md                    the 42 rules — always loaded
├── reference/                  deep technique — read on trigger
│   ├── mcp-tooling.md            Burp / HackerOne / CVE MCP workflows
│   ├── payload-sources.md        payload + per-class KB navigation
│   ├── stuck-and-waf.md          the stuck protocol, WAF handling
│   ├── mobile-apk.md             APK teardown, secret & surface extraction
│   ├── execution-tactics.md      findings storage, parallel execution
│   ├── elite-hunting.md          systems thinking, business logic, chaining
│   ├── attack-vectors.md         observation → attack-vector catalogue
│   └── evaluations.md            the scenarios every rule must survive
├── scripts/
│   ├── run-eval.sh               run a scenario against an independent agent
│   ├── no-loss-check.sh          prove a restructure dropped nothing
│   └── move-block.py             move a block to reference/ verbatim
├── portswigger-kb/             31 vuln classes · 124 playbooks · attack trees
├── writeup-library.md          distilled techniques from real paid writeups
├── vuln-taxonomy.md            OWASP web/API/LLM, CWE Top 25, 250+ classes
├── waf-bypass-arsenal.md       identification, encoding ladders, per-class bypass
└── speed-commands.md           copy-paste recon and per-class speed tests
```

## Install

Clone into your agent's skills directory:

```bash
git clone https://github.com/sanjarbiy/bugbountyrules ~/.claude/skills/bugbountyrules
```

It auto-activates for bug bounty, pentest and web-security sessions (see `description` in `SKILL.md`). Cross-runtime agents also recognise `~/.agents/skills/`. No dependencies, no configuration — it is markdown.

**Instructions in any language.** The skill and everything it produces stay in English, but it understands and acts on operator instructions in any language, and answers in the operator's.

## Usage

There is nothing to launch. The skill is *behavioural* — you talk to your agent normally and it governs **how** the agent hunts: enforcing scope, generating attack vectors, tracking coverage, gating false positives, and refusing to quit while surface remains.

**1. It activates on its own** the moment a session looks like security work — you mention a bug-bounty programme, a pentest, a vuln class, paste HTTP traffic or a cookie, or name Burp. To force it, just say so:

```
Use bugbountyrules to hunt example.com. Scope: *.example.com. Focus: IDOR and access control.
```

**2. Give it two things — a target and the scope.** Scope can be a `details.json` / programme file, a pasted in-scope/out-of-scope list, or plain text. With no scope it asks before touching anything (Rule 1); out-of-scope assets are refused, and it splits in-scope from out-of-scope rather than trusting a mixed list.

**3. Then let it run.** It works autonomously through the operational flow — load prior state → probe its tool pack → read scope → passive recon → map the surface → hunt (two-account IDOR first) → verify (Hunter → Skeptic → Referee) → write a triager-ready report. It logs every test so it never re-runs or skips, and it never concludes "secure" while surface remains. **You do not have to say "keep going."**

Typical prompts:

```
Recon acme.com and map the attack surface.
I have Burp history for a checkout flow — analyse it for logic and IDOR bugs.
Here's an APK — extract the API surface and hunt the auth flow.
Validate this finding before I report it.        # runs the false-positive gate
I'm stuck on this endpoint and about to give up.  # triggers the stuck loop, not surrender
```

**Any language.** Prompt in Uzbek, Russian, Arabic — it acts on the instruction and answers in your language; payloads, code and the report itself stay English.

**Optional power-ups**, each auto-detected and skipped cleanly if absent: a Burp MCP, your programme platform's MCP (HackerOne / Intigriti / …), a CVE-intel MCP, a local LLM for bulk offload, and a frontier peer agent for an independent second opinion — see *Optional integrations* below. None are required; the skill is just markdown and runs with zero configuration.

## Verifying it

Rules here are meant to be checkable, not taken on faith. `reference/evaluations.md` holds the
scenarios each rule must survive, plus a requirement→test matrix so an untested claim is visible.
Each scenario is one command:

```bash
./scripts/run-eval.sh --rule 26 --ask "<case>"   # what does the rule actually dictate?
./scripts/run-eval.sh --sync-check                # is every installed copy current?
```

It hands the rule's own text plus your case to a second agent that has never seen the skill — if a
rule only reads well but does not *instruct*, that shows up immediately. Set `PEER` to whatever
agent CLI you use; nothing vendor-specific is baked in. **A rule change should start with a
scenario that fails.**

## Optional integrations

All optional — each is detected once, used if live, and skipped cleanly if not. The skill never blocks on one.

| Integration | What it adds |
|---|---|
| **Burp MCP** | Full proxy-history and sequential-flow analysis, Repeater/Intruder staging, Collaborator for blind classes |
| **HackerOne MCP** | Automatic scope + exclusions + accepted weaknesses; hacktivity mined for winning patterns and duplicate checks before you write |
| **CVE / exploit MCP** | Fingerprint → CVE → public-exploit, ranked by what is actually exploitable now |
| **A local LLM** | A context firewall: bulk triage, extraction and summarising of scan output, keeping raw volume out of the agent's context |
| **A frontier peer agent** | An independent second opinion from a different model family — kills false positives before you report, and finds the path you missed before you call a target clean |

## Companion skill

Pairs with **[portswigger](https://github.com/sanjarbiy/portswigger)** — a deep web-exploitation knowledge engine. `bugbountyrules` is the engagement brain; `portswigger` is the weapon it reaches for. A copy is bundled here as `portswigger-kb/`.

> **Methodology influences:** Jason Haddix's *Bug Hunter's Methodology* (depth over breadth), the isolated Hunter/Skeptic/Referee verification pattern, and community practice on coverage tracking — log what you tested and *why* you dismissed it, or you will redo it in three days.

## Third-party content

- `vulnerability-rating-taxonomy.json` — the **Vulnerability Rating Taxonomy**, published by
  Bugcrowd under CC BY 4.0. Bundled unmodified so severity can be anchored to the platform's own
  baseline rather than to instinct. Upstream: <https://github.com/bugcrowd/vulnerability-rating-taxonomy>
- `portswigger-kb/` — techniques distilled from publicly documented web-security research and labs.
- `writeup-library.md` — techniques distilled from public write-ups; each entry links its source.

## License

MIT — see [LICENSE](LICENSE). Third-party content above keeps its own licence.

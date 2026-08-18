# bugbountyrules

**A behavioral-discipline skill for authorized bug bounty & penetration testing.** It turns an AI agent into a methodical, persistent, non-robotic hunter - enforcing scope, generating attack vectors autonomously, holding evidence discipline, and chaining across the full web / API / mobile / cloud / LLM attack surface.

> ⚠️ **Authorized testing only.** For bug bounty programs you are enrolled in, penetration tests you are contracted for, CTFs, and your own systems. Always read and respect program scope. Never test systems you do not have explicit permission to test.

---

## What it is

An [agent skill](https://agentskills.io) (Claude Code and compatible runtimes) that governs *how* an agent hunts - the discipline that separates an operator from a payload-paster. **42 rules**, always active, plus a bundled knowledge base and reference shelf loaded only when needed.

It is opinionated about the three failures that cost real money:

- **False positives** - a Hunter -> Skeptic -> Referee gate, per-class evidence requirements, and an adversarial second-opinion pass before anything is claimed.
- **Severity inflation** - findings are anchored metric-by-metric with explicit downgrade counters, and hedging language ("could potentially", "may allow") is banned outright.
- **Quitting early** - a coverage ledger so nothing is re-tested or skipped, per-class depth ladders, and a stuck loop that refuses to conclude "secure" while surface remains.

## Why it is built this way

The problem with an AI agent on a security target is not knowledge - it knows what SQLi is. The problem is *behaviour*: it reports things that are not bugs, inflates severity, gives up while surface remains, drifts out of scope, and repeats work it already did. Payloads do not fix any of that. Discipline does. So this skill encodes the discipline, and leaves the payloads to the bundled arsenal.

Everything in it is **measured, not asserted**. The false-positive gate exists because a small model, put to eight findings, waved through 3 of 4 textbook false positives and inflated severity on 6 of 8. The "one clean commit" and coverage rules exist because on real engagements roughly one action in five was an exact duplicate. Each rule carries the failure that justifies it, and a scenario in `reference/evaluations.md` that a fresh agent must pass.

## How it works

**One always-loaded core, everything else on demand.** `SKILL.md` (the 42 rules, ~1,500 lines) is loaded for the whole session and is pure behaviour. Deep technique lives one read away in `reference/` and the bundled KBs, and costs zero tokens until the situation calls for it - this is *progressive disclosure*, so the agent is governed at all times without carrying a library in its context.

Two mechanisms drive every session:

- **The Hunt Reflex** - a checklist that fires *before every move*: am I in scope, using the right tool, logging coverage, about to overclaim, about to conclude "secure", reading a huge file into my own context? If any answer is wrong, the move is corrected before it happens.
- **The Operational Flow** - a fixed order for a hunt: load prior state -> probe the tool pack -> read scope -> **passive recon first** -> map the surface and request flows -> hunt (crown jewels and two-account IDOR first) -> verify -> report. Recon and mapping are treated as 60-70% of the work, because that is where non-duplicate bugs come from.

**You are the operator of a pack, not a lone worker.** When they are reachable, the skill routes work across engines by shape: bulk reading and extraction to a cheap tireless model (a context firewall), an independent second opinion to a frontier peer agent (kill a finding before reporting; break a "secure" conclusion before accepting it), and judgment, planning, chaining and reporting always kept by the agent itself. Client secrets never leave the local tier. None of this is required - each engine is detected once and skipped cleanly if absent.

**Design principles that keep it honest:** measured over asserted (every claim has a number and a test); vendor-neutral (no tool name, model, or path is hard-coded - concrete wiring lives in the operator's own config); verifiable (`run-eval.sh` puts a rule's own text to an independent agent to prove it *instructs*, not just reads well); anti-robotic (Rule 0: every target is different - never run a checklist mechanically); and language-agnostic (prompt in any language, get answers in yours; payloads and reports stay English).

## The 42 rules

Every rule is always active; the clusters marked "one system" are complementary, not redundant. `SKILL.md` carries each rule's full mandate - this is the index.

**Mindset & autonomy**
- **0 Adaptive Thinking** - a framework for judgment, not a checklist; tools are examples, not mandates; every target is different.
- **4 Think Like a Senior Hunter** - map before testing; hunt crown jewels and developer shortcuts (billing, export, new features) first.
- **20 Elite Mode** - model the *system* (auth, roles, trust boundaries, state) before attacking endpoints; business logic pays most and competes least.
- **24 The APT Mindset** - think like an advanced persistent threat, not a scanner out of signatures; a 0-day or an honest zero, never a fabricated finding.
- **29 Use Your Machine Intelligently** - state the goal in one line, write a visible plan, lock the goal, and spend tokens only where they change the outcome.

**Never stop / when stuck**
- **25 Never Conclude "Secure"** (the hardest rule) - no findings means testing is incomplete, not that the target is safe; run the stuck loop instead of stopping.
- **11.5 When Stuck** - fingerprint the exact stack/WAF/defence, research *that*, adapt, then fire - never guess harder.
- **11 Persistence** - a dead approach means a different vector, not the same one harder; rotate across surface intelligently.
- **12 WAF Handling** - a block is an obstacle with a shape, not a verdict; identify what it filters and craft a specific bypass, and pivot to classes a WAF cannot protect.

**Scope & discipline**
- **1 Scope First** - read scope before any request; one out-of-scope request can ban you from the programme.
- **9 Strict Scope Enforcement** - both directions: never trespass, but never write off an in-scope asset for where it is hosted (an S3-backed in-scope subdomain is still in scope; SSRF impact is judged by where it lands, not where you sent it). Split mixed in/out lists explicitly.
- **2 Inspect All Traffic** - read full bodies and headers; "inspect all" is about coverage, achieved by extraction, not by swallowing volume into context.
- **3 All Requests Through Burp** - everything through the proxy for evidence and replay, except high-volume automation which is run direct and replayed selectively.
- **5 Never Test Rejected Classes** - self-XSS, DNS-only SSRF, logout CSRF, missing headers without impact, and the rest of the always-rejected list are skipped unless scope includes them.
- **6 Zero Blind Requests** - every request has a hypothesis and an expected result; no spraying.
- **7 Use the Right Tool** - do not do by hand what a good tool does better, and do not run a tool blindly.

**Recon & intel**
- **3.5 Burp MCP** - when connected, read and analyse *all* in-scope traffic, filter for high-value patterns, stage into Repeater/Intruder, prove blind classes with Collaborator.
- **3.6 Sequential Flow Analysis** - vulnerabilities hide in the transitions between requests; reconstruct the flow and attack the trust boundary inside it.
- **3.7 Programme-Platform MCP** - on any platform (HackerOne, Intigriti, Bugcrowd, YesWeHack...), pull scope, exclusions and disclosed-report history automatically; dedup before investing; never submit without explicit operator confirmation.
- **3.11 CVE / Exploit MCP** - fingerprint -> CVE -> public exploit, ranked by what is exploitable now (public PoC, EPSS, KEV), never CVSS alone.
- **3.12 Local-LLM Offload** - a context firewall and tireless eyes: send bulk/large/mechanical reading to a cheap on-box model, keep raw volume out of your context; route deterministic work to tools first, client data to the on-box tier only.
- **3.13 One Folder Per Target** - every artifact lands under that target's own folder; never invent a scratch directory, on any machine.
- **3.14 Frontier Peer Agent** - an independent apex from a different model family, stationed at two gates: kill a finding as a false positive before you report it, and hunt the path you missed before you call a target secure.
- **8 Unauthenticated Surface** - with no credentials, hunt only the unauth surface; never fabricate or brute credentials.
- **10 Continuous Research** - learn before you act; research the current year first, because an old bypass may be patched.
- **15 Cross-Skill Orchestration** - invoke specialised skills (recon, GraphQL, reporting...) when their domain applies; combine for depth.

**Depth & payloads**
- **3.8 Payload Depth** - one probe proves nothing; pull the full set from PayloadsAllTheThings before concluding a class is clean.
- **3.9 PortSwigger KB** - once a class is confirmed or an objective picked, open the bundled per-class playbook first; do not improvise deep technique from memory.
- **3.10 Writeup Library** - battle-tested tricks from real paid write-ups, plus always-live research; the bundled set is a floor, never a ceiling.
- **22 Exhaust the Class** - climb the full depth ladder (SQLi: error -> boolean -> time -> UNION -> stacked -> OOB -> second-order -> WAF-bypass), not five payloads.
- **16 APK Analysis** - a mobile app is a shipped copy of the backend contract; decompile it for endpoints, secrets and hidden parameters the web UI never exposes.
- **27 Dynamic Analysis** - a failed tool is a diagnosis task, not a dead end: read the full log, name the exact cause; and tell apart "my setup broke" from "the target is reacting to me".

**Learn & grow**
- **30 Self-Evolution** - write working new techniques back into the skill; a rule only changes after a failing test proves the old one wrong (the Iron Law).

**Memory, coverage, no-repeat**
- **17 Save Everything Useful** - every credential, token, endpoint and anomaly goes to durable storage the moment you see it, with an F-id.
- **21 The Coverage Ledger** - track what was tested, found, and dismissed *and why*; keep a searchable false-positive memory so a killed finding is never chewed twice; a number taken on a degraded machine is not evidence.
- **28 Read Everything First** - read the whole source, map every path, then act once and never repeat it; when you have source, read it in four passes (sinks -> taint -> newest code -> history).

**Verify & report**
- **23 Adversarial Self-Verification** - before any claim, prosecute it in three hats: Hunter states it, Skeptic tries to kill it, Referee judges with zero attachment - and hand the Referee to a real peer when you can.
- **13 Precision - Evidence Over Speculation** - evidence or it is not a finding; each class has a minimum-evidence bar (IDOR needs another user's data in the body, not a 200).
- **14 Maintainer Mindset** - review your own finding as the triager would: they see 50-200 reports a day and give yours ~10 minutes, so reproduction must be copy-pasteable, impact plain, and everything about you cut; tone is scored.
- **26 Impact & Attacker-Path** - a technical anomaly is not a vulnerability; state who the attacker is, what they do, the real harm, and why a triager pays - anchored severity, banned hedging phrases, PII redacted.

**Chaining & speed**
- **18 Chaining Mindset** - a lone low is a bite, a chain is a feast; severity is decided by where the chain ends (open redirect -> OAuth theft -> ATO).
- **19 Parallel Execution** - run independent work at once, but keep CPU-bound fan-out at or under the core count and throttle deliberately against a live target.

## Structure

Progressive disclosure: `SKILL.md` carries every rule's mandate; the deep technique sits one read away and costs nothing until the situation calls for it.

```
bugbountyrules/
├── SKILL.md                    the 42 rules - always loaded
├── reference/                  deep technique - read on trigger
│   ├── mcp-tooling.md            Burp / HackerOne / CVE MCP workflows
│   ├── payload-sources.md        payload + per-class KB navigation
│   ├── stuck-and-waf.md          the stuck protocol, WAF handling
│   ├── mobile-apk.md             APK teardown, secret & surface extraction
│   ├── execution-tactics.md      findings storage, parallel execution
│   ├── elite-hunting.md          systems thinking, business logic, chaining
│   ├── attack-vectors.md         observation -> attack-vector catalogue
│   └── evaluations.md            the scenarios every rule must survive
├── scripts/
│   ├── run-eval.sh               run a scenario against an independent agent
│   ├── no-loss-check.sh          prove a restructure dropped nothing
│   └── move-block.py             move a block to reference/ verbatim
├── portswigger-kb/             31 vuln classes - 124 playbooks - attack trees
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

It auto-activates for bug bounty, pentest and web-security sessions (see `description` in `SKILL.md`). Cross-runtime agents also recognise `~/.agents/skills/`. No dependencies, no configuration - it is markdown.

**Instructions in any language.** The skill and everything it produces stay in English, but it understands and acts on operator instructions in any language, and answers in the operator's.

## Usage

There is nothing to launch. The skill is *behavioural* - you talk to your agent normally and it governs **how** the agent hunts: enforcing scope, generating attack vectors, tracking coverage, gating false positives, and refusing to quit while surface remains.

**1. It activates on its own** the moment a session looks like security work - you mention a bug-bounty programme, a pentest, a vuln class, paste HTTP traffic or a cookie, or name Burp. To force it, just say so:

```
Use bugbountyrules to hunt example.com. Scope: *.example.com. Focus: IDOR and access control.
```

**2. Give it two things - a target and the scope.** Scope can be a `details.json` / programme file, a pasted in-scope/out-of-scope list, or plain text. With no scope it asks before touching anything (Rule 1); out-of-scope assets are refused, and it splits in-scope from out-of-scope rather than trusting a mixed list.

**3. Then let it run.** It works autonomously through the operational flow - load prior state -> probe its tool pack -> read scope -> passive recon -> map the surface -> hunt (two-account IDOR first) -> verify (Hunter -> Skeptic -> Referee) -> write a triager-ready report. It logs every test so it never re-runs or skips, and it never concludes "secure" while surface remains. **You do not have to say "keep going."**

Typical prompts:

```
Recon acme.com and map the attack surface.
I have Burp history for a checkout flow - analyse it for logic and IDOR bugs.
Here's an APK - extract the API surface and hunt the auth flow.
Validate this finding before I report it.        # runs the false-positive gate
I'm stuck on this endpoint and about to give up.  # triggers the stuck loop, not surrender
```

**Any language.** Prompt in Uzbek, Russian, Arabic - it acts on the instruction and answers in your language; payloads, code and the report itself stay English.

**Optional power-ups**, each auto-detected and skipped cleanly if absent: a Burp MCP, your programme platform's MCP (HackerOne / Intigriti / ...), a CVE-intel MCP, a local LLM for bulk offload, and a frontier peer agent for an independent second opinion - see *Optional integrations* below. None are required; the skill is just markdown and runs with zero configuration.

## Verifying it

Rules here are meant to be checkable, not taken on faith. `reference/evaluations.md` holds the
scenarios each rule must survive, plus a requirement->test matrix so an untested claim is visible.
Each scenario is one command:

```bash
./scripts/run-eval.sh --rule 26 --ask "<case>"   # what does the rule actually dictate?
./scripts/run-eval.sh --sync-check                # is every installed copy current?
```

It hands the rule's own text plus your case to a second agent that has never seen the skill - if a
rule only reads well but does not *instruct*, that shows up immediately. Set `PEER` to whatever
agent CLI you use; nothing vendor-specific is baked in. **A rule change should start with a
scenario that fails.**

## Optional integrations

All optional - each is detected once, used if live, and skipped cleanly if not. The skill never blocks on one.

| Integration | What it adds |
|---|---|
| **Burp MCP** | Full proxy-history and sequential-flow analysis, Repeater/Intruder staging, Collaborator for blind classes |
| **HackerOne MCP** | Automatic scope + exclusions + accepted weaknesses; hacktivity mined for winning patterns and duplicate checks before you write |
| **CVE / exploit MCP** | Fingerprint -> CVE -> public-exploit, ranked by what is actually exploitable now |
| **A local LLM** | A context firewall: bulk triage, extraction and summarising of scan output, keeping raw volume out of the agent's context |
| **A frontier peer agent** | An independent second opinion from a different model family - kills false positives before you report, and finds the path you missed before you call a target clean |

## Companion skill

Pairs with **[portswigger](https://github.com/sanjarbiy/portswigger)** - a deep web-exploitation knowledge engine. `bugbountyrules` is the engagement brain; `portswigger` is the weapon it reaches for. A copy is bundled here as `portswigger-kb/`.

> **Methodology influences:** Jason Haddix's *Bug Hunter's Methodology* (depth over breadth), the isolated Hunter/Skeptic/Referee verification pattern, and community practice on coverage tracking - log what you tested and *why* you dismissed it, or you will redo it in three days.

## Third-party content

- `vulnerability-rating-taxonomy.json` - the **Vulnerability Rating Taxonomy**, published by
  Bugcrowd under CC BY 4.0. Bundled unmodified so severity can be anchored to the platform's own
  baseline rather than to instinct. Upstream: <https://github.com/bugcrowd/vulnerability-rating-taxonomy>
- `portswigger-kb/` - techniques distilled from publicly documented web-security research and labs.
- `writeup-library.md` - techniques distilled from public write-ups; each entry links its source.

## License

MIT - see [LICENSE](LICENSE). Third-party content above keeps its own licence.

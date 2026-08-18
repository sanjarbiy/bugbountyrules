# portswigger - Web Security Attack Engine

**An operator-grade, autonomous web-attack skill covering all 31 PortSwigger Web Security Academy vulnerability classes** - with a detection-first engine, goal-oriented attack trees, and deep per-class exploitation playbooks. Built to *think* like a predator, not look up payloads like a script.

> ⚠️ **Authorized testing only.** PortSwigger Academy lab sandboxes, CTFs, and engagements you are explicitly authorized for. Never aim payloads outside the sandbox/scope. Capture methodology and payloads - never anyone else's data.

---

## What it is

A [Claude Code / agent skill](https://agentskills.io): a single `SKILL.md` router over a deep knowledge base. It works **two ways** - from an *observation* ("this request -> which class?") and from an *objective* ("I want account takeover -> every path that reaches it") - and runs a continuous attack engine that generates vectors, adapts when blocked, researches when stuck, and chains to maximum impact.

## Structure

```
SKILL.md                     # router: engine + entry modes + detection + objectives + impact gate
references/                   # the autonomous brain (11 files)
  attack-engine.md           #   continuous I-SEE->SO-I-TRY loop, adaptive thinking, WAF bypass, when-stuck research
  detection-fingerprints.md  #   observation -> class -> confirm-probe, for all 31 classes
  objectives-attack-trees.md #   9 goal trees (ATO, RCE, PII, privesc, auth-bypass, fraud, attack-others, cloud, secrets)
  chaining-playbook.md       #   primitive -> crown kill chains
  hunt-methodology.md        #   Step-0 mental model, 4-state matrix, persistence, impact gate
  operating-discipline.md    #   scope, flow analysis, ROI priority, two-account IDOR, evidence-by-class
  recon-and-fuzzing.md       #   autonomous surface discovery (ffuf, param mining, JS extraction)
  waf-bypass-arsenal.md      #   consolidated WAF/filter bypass
  payload-library.md         #   escalate beyond basic probes -> PayloadsAllTheThings (class->folder map)
  vuln-taxonomy.md           #   no-blind-spot map (OWASP/API/LLM Top 10 + CWE-25)
  speed-commands.md          #   copy-paste operational command arsenal
<31 topic folders>/          # 93 sub-technique folders, 124 operator READMEs
  e.g. SQL-injection/, XSS/, SSRF/, JWT-attacks/, Access-control/ ...
```

Each sub-technique README is a 13-section operator playbook: Quick reference - Root cause - Find it - Technique - Payload arsenal - Bypasses - Exploitation walkthrough - Chaining - Tools - Labs - Real-world notes - References.

## Coverage (31 classes)

SQL injection - NoSQL injection - XSS - DOM-based - SSTI - SSRF - XXE - OS command injection - Path traversal - File upload - Insecure deserialization - JWT - Prototype pollution - OAuth - HTTP Host header - HTTP request smuggling - Web cache poisoning - Web cache deception - CORS - Clickjacking - CSRF - WebSockets - GraphQL - API testing - Access control/IDOR - Business logic - Race conditions - Authentication - Information disclosure - Web LLM attacks - Essential skills

## Install

```bash
git clone https://github.com/<your-username>/portswigger ~/.claude/skills/portswigger
```

It auto-activates for web-security work - when you show HTTP traffic, name a vuln class, ask how to test/exploit/detect something, or state a goal (ATO, RCE, dump the DB...). Cross-runtime agents also recognize `~/.agents/skills/`.

## Companion skill

Pairs with **[bugbountyrules](https://github.com/<your-username>/bugbountyrules)** - the engagement discipline / broad methodology brain. Use them together: `bugbountyrules` governs the engagement, `portswigger` supplies the deep web-attack knowledge.

## Credits

Distilled from [PortSwigger Web Security Academy](https://portswigger.net/web-security) published material into transformative operator playbooks. PortSwigger and Web Security Academy are trademarks of their respective owner; this is an independent study/reference project, not affiliated with PortSwigger.

## License

MIT - see [LICENSE](../LICENSE) at the repository root.

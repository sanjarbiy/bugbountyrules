# Execution Tactics — bugbountyrules reference

Loaded on demand from SKILL.md. These are the full versions of rules whose
mandate is stated inline in SKILL.md; read this file when the situation calls for it.

## Contents
- RULE 17: Save everything useful
- RULE 19: Parallel execution
- Research Protocol
- The Maintainer Review Checklist
- Skill Combination Patterns
- Finding → Report Bridge
- How to evolve it (the write-back protocol)

---

## RULE 17: SAVE EVERYTHING USEFUL — NEVER LOSE DATA

**If it looks even slightly useful → SAVE IT. No exceptions.**

You do not have perfect memory. Data gets lost between context switches. Findings that seem minor now may become critical when combined with later discoveries. **Write it down immediately.**

### Every finding, identified issue, and suspicion gets a LOGICAL ID + STATUS (mandatory)

Keep ONE master findings register (in `interesting_findings.json` or the ledger). **Every noteworthy item — a confirmed vuln, an identified issue, OR a mere suspicion — gets a unique SEQUENTIAL id: `F1, F2, F3, …`** Assigned in the order you find them, **never reused, never renumbered** — so any item stays referenceable forever ("F52 downgraded to P5", "F61 blocked on the browser tool").

Each id carries a STATUS (+ a severity if confirmed):
```
CONFIRMED    — proven + reproduced (+ severity P1–P5)        → report candidate (after Rule 23/26)
SUSPECTED    — an anomaly / lead, not yet confirmed          → OPEN — must be pursued (Rule 25)
TESTED-CLEAN — checked, not vulnerable (+ the reason)        → do not re-test (Rule 21)
DEAD / N-A   — was a candidate, ruled out (+ the reason)     → closed
SUBMITTED / PAID / REJECTED                                  → reporting states
```
Register example:
```
F1  CONFIRMED P2    IDOR on POST /profiles/{id}/emails → ATO   (reproduced; evidence saved)
F2  SUSPECTED       /export download-link may be IDORable      (async; not yet tested)
F3  TESTED-CLEAN    JWT alg:none                               (signature enforced → not vuln)
```
**The moment you find, identify, or suspect ANYTHING — give it the next F-number and a status, before you move on.** Nothing noteworthy exists without an id. Ledger cells and chains reference items by their F-id. This is how you and the operator reference everything and lose nothing.

### What to Save:

Save to `interesting_findings.json` in the working directory. Create it if it doesn't exist.

```
ALWAYS SAVE THESE (even if you don't understand them yet):

CREDENTIALS & AUTH:
  → Usernames, passwords, email addresses (even partial)
  → API keys, tokens (JWT, session, refresh, API, OAuth)
  → Cookies with interesting values
  → Basic auth headers (even encoded)
  → Service account names

ENDPOINTS & INFRASTRUCTURE:
  → Admin panels, debug endpoints, internal paths
  → Staging/dev URLs discovered anywhere
  → Hidden API endpoints not in documentation
  → WebSocket URLs
  → GraphQL endpoints
  → Endpoints that return different responses based on auth

IDS & REFERENCES:
  → User IDs, account IDs, order IDs, object IDs
  → UUID patterns and their contexts
  → Sequential vs random ID patterns
  → Internal reference numbers

INTERESTING RESPONSES:
  → Error messages that leak information
  → Stack traces (even partial)
  → Responses with different behavior than expected
  → 403s that should be 401s (or vice versa)
  → Responses that include more data than requested
  → Rate limit headers and thresholds

TECHNICAL DETAILS:
  → Version numbers (framework, server, database, plugins)
  → Technology fingerprints
  → Custom headers sent by the application
  → CORS configurations
  → CSP policies (especially weak ones)
  → Cookie attributes and flags

BEHAVIORAL OBSERVATIONS:
  → Endpoints that don't validate input
  → Endpoints with inconsistent auth checks
  → Features that bypass normal flow
  → Race condition windows observed
  → Caching behavior anomalies
```

### How to Save — `interesting_findings.json` Format:

```json
{
  "meta": {
    "target": "target.com",
    "scope": "program-name",
    "last_updated": "2026-03-18T12:00:00Z"
  },
  "credentials": [
    {
      "type": "api_key",
      "value": "AKIA...",
      "source": "APK decompilation - BuildConfig.java",
      "context": "AWS key found in hardcoded config",
      "tested": false,
      "notes": "Need to enumerate permissions"
    }
  ],
  "endpoints": [
    {
      "url": "/api/internal/admin/users",
      "method": "GET",
      "source": "JS bundle analysis",
      "auth_required": "unknown - returns 403",
      "notes": "May be accessible with admin token from finding #3"
    }
  ],
  "ids": [
    {
      "type": "user_id",
      "value": "12345",
      "source": "GET /api/user/me response",
      "pattern": "sequential integer",
      "notes": "Try IDOR on sibling endpoints"
    }
  ],
  "tokens": [
    {
      "type": "jwt",
      "value": "eyJ...",
      "source": "Login response Set-Cookie header",
      "decoded_payload": "{\"sub\":\"user123\",\"role\":\"user\"}",
      "notes": "Role claim in JWT - check if server validates or trusts client"
    }
  ],
  "interesting_responses": [
    {
      "endpoint": "/api/user/export",
      "observation": "Returns 200 with empty body when auth missing (should be 401)",
      "source": "Burp proxy history analysis",
      "notes": "Possible broken access control - needs deeper testing"
    }
  ],
  "tech_stack": [
    {
      "component": "backend",
      "technology": "Express.js 4.18",
      "source": "X-Powered-By header + error page format",
      "notes": "Check for prototype pollution, SSTI in EJS if used"
    }
  ],
  "chain_candidates": [
    {
      "finding_a": "Open redirect on /oauth/callback",
      "finding_b": "OAuth flow uses redirect_uri without strict validation",
      "potential_chain": "Open redirect → OAuth token theft → ATO",
      "status": "needs_testing",
      "notes": "If redirect_uri is validated loosely, can chain for token steal"
    }
  ]
}
```

### When to Save:

```
SAVE IMMEDIATELY WHEN:
  → You see any credential, key, or token (even if you can't use it yet)
  → You discover an endpoint not in the obvious application flow
  → You notice unexpected behavior (wrong status code, extra data, missing validation)
  → You find any ID or reference that could be used for IDOR
  → You identify a technology or version number
  → You see something that "feels wrong" even if you can't explain why yet
  → You find something that could be part of a chain (Rule 18)

DO NOT:
  → Rely on memory — you WILL forget
  → Skip saving because "it's probably nothing" — many bounties come from "probably nothing"
  → Wait to save — save now, analyze later
  → Only save confirmed vulnerabilities — save EVERYTHING interesting
```

**The difference between a $0 hunt and a $10,000 hunt is often a small detail that was saved instead of forgotten.**

---

## RULE 19: PARALLEL EXECUTION — SPEED WITHOUT SACRIFICING ACCURACY

**Sequential one-by-one execution is too slow — but there are TWO kinds of "parallel", and only one is free.** Batching independent tool calls into ONE message (Bash / MCP / WebSearch) is fast AND costs nothing extra — do it constantly. Dispatching subagents or workflows is EXPENSIVE and burns quota — use it rarely and only when the budget clearly justifies it (Rule 29). **Default to batched tool-calls, never to fan-out.**

Real bug hunting requires speed. Targets get patched. Other hunters are competing. Running everything sequentially wastes time when independent tasks can execute simultaneously.

### What MUST Run in Parallel:

```
PARALLEL GROUP 1 — RECON (all independent, run simultaneously):
  Use multiple Bash tool calls in a SINGLE message:
  → subfinder -d target.com -o subs.txt          (subdomain enum)
  → katana -u https://target.com -o urls.txt      (URL crawling)
  → echo target.com | httpx -title -tech-detect   (HTTP probing)
  → nmap -sV -T4 --top-ports 1000 target.com      (port scan)

PARALLEL GROUP 2 — CONTENT DISCOVERY (per subdomain, run simultaneously):
  Use multiple Bash tool calls in a SINGLE message:
  → feroxbuster -u https://app.target.com -w wordlist.txt -o app_dirs.txt
  → feroxbuster -u https://api.target.com -w api_wordlist.txt -o api_dirs.txt
  → ffuf -u https://target.com/FUZZ -w params.txt -o params_found.txt

PARALLEL GROUP 3 — ANALYSIS (independent data sources, run simultaneously):
  Use multiple tool calls in a SINGLE message:
  → mcp__burp__get_proxy_http_history(count=100, offset=0)     (Burp traffic)
  → mcp__burp__get_scanner_issues(count=50, offset=0)          (scanner results)
  → Bash: cat decompiled_apk/sources/**/*.java | grep -i "api"  (APK endpoints)

PARALLEL GROUP 4 — MULTI-ENDPOINT TESTING (independent endpoints):
  Use multiple Bash tool calls in a SINGLE message:
  → curl -sk -x http://127.0.0.1:8080 "https://target.com/api/users/me"
  → curl -sk -x http://127.0.0.1:8080 "https://target.com/api/orders"
  → curl -sk -x http://127.0.0.1:8080 "https://target.com/api/settings"
  → curl -sk -x http://127.0.0.1:8080 "https://target.com/api/export"

PARALLEL GROUP 5 — RESEARCH (independent lookups, run simultaneously):
  Use multiple WebSearch calls in a SINGLE message:
  → WebSearch: "nginx 1.21.6 CVE"
  → WebSearch: "Express.js 4.18 vulnerability"
  → WebSearch: "target.com bug bounty disclosed reports"
```

### How to Parallelize — Technical Implementation:

```
METHOD 1: MULTIPLE BASH CALLS IN ONE MESSAGE
  → Send 2-5 independent Bash commands as separate tool calls in the SAME message
  → They execute concurrently, results return together
  → USE THIS for: recon tools, curl requests, file analysis

METHOD 2: MULTIPLE MCP CALLS IN ONE MESSAGE
  → Send multiple mcp__burp__ calls in the SAME message
  → USE THIS for: pulling Burp history + scanner issues + Collaborator interactions simultaneously

METHOD 3: MULTIPLE WEBSEARCH CALLS IN ONE MESSAGE
  → Send multiple WebSearch queries in the SAME message
  → USE THIS for: researching multiple technologies/CVEs simultaneously

METHOD 4: BACKGROUND TASKS FOR LONG-RUNNING TOOLS
  → Use run_in_background=true for tools that take minutes (nmap, feroxbuster, nuclei)
  → Continue with other work while they run
  → Results arrive when complete — you get notified automatically

METHOD 5: THE OFFLOAD LAYER — FREE PARALLEL CAPACITY (Rules 3.12 / 3.14)
  → A local LLM and a frontier peer are SEPARATE MACHINES from you. Work you hand them runs
    while you keep working — that is real wall-clock parallelism that costs you no context.
  → Fire-and-continue: send the bulk job (log triage, extraction, classification) to the local
    LLM, or the kill-gate question to the frontier peer, then keep hunting. Collect the answer later.
  → THE ONE HARD LIMIT: a single consumer GPU serialises model calls. Do NOT fan out concurrent
    calls to the local model — they queue, and mixed-role calls thrash the model loader, which is
    SLOWER than sequential. Parallelise CPU-side work (grep, sink scans, curl) instead, and keep
    at most one local-model call in flight. The frontier peer is a different machine — a peer call
    and a local call CAN overlap.

METHOD 6: SUBAGENTS — ONLY WHEN THE BUDGET JUSTIFIES IT (expensive, quota-heavy)
  → Subagents/workflows burn quota fast. Do NOT fan out by default.
  → Use ONLY for genuinely large, independent workstreams when budget allows (Rule 29).
  → For normal hunting, Methods 1-5 (batched calls + background tasks + offload) hit the same speed for free.
```

### The Parallelism Decision Rule:

```
FOR EVERY SET OF TASKS, ASK:
  1. Are these tasks independent? (no task needs output from another)
     → YES = run in parallel (multiple tool calls in one message)
     → NO  = run sequentially (wait for results before next step)

  2. Will any task take > 30 seconds?
     → YES = consider run_in_background for that task
     → NO  = run inline

  3. Are there 3+ independent research questions?
     → YES = send all WebSearch calls in one message
     → NO  = send individually

EXAMPLES:
  ✗ SLOW: curl endpoint A → wait → curl endpoint B → wait → curl endpoint C
  ✓ FAST: curl A, B, C all in the same message (3 parallel Bash calls)

  ✗ SLOW: subfinder → wait → httpx → wait → katana
  ✓ FAST: subfinder + httpx + katana all in same message (if targeting different inputs)
          OR: subfinder → (httpx + katana) in same message using subfinder output

  ✗ SLOW: research nginx CVE → wait → research Express CVE → wait → research JWT attacks
  ✓ FAST: all 3 WebSearch calls in the same message

  ✗ SLOW: read scope → read Burp history → check scanner (one by one)
  ✓ FAST: read scope (Read tool) + Burp history (MCP) + scanner (MCP) in same message
```

### What Must Stay Sequential (do NOT parallelize):

```
SEQUENTIAL ONLY:
  → Scope reading MUST happen before ANY testing
  → Burp traffic analysis MUST happen before flow mapping
  → Finding confirmation MUST happen before report writing
  → Research MUST happen before exploitation attempts
  → Any task that depends on output from a previous task
```

### Speed Optimization Checklist:

```
EVERY TIME YOU'RE ABOUT TO MAKE A TOOL CALL, ASK:
[ ] Can I combine this with other pending tool calls into ONE message?
[ ] Is there another independent task I should be running at the same time?
[ ] Should this long-running command run in the background?
[ ] Am I waiting for something I don't need to wait for?

IF YOU FIND YOURSELF MAKING 3+ SEQUENTIAL CALLS THAT DON'T DEPEND ON EACH OTHER
→ YOU ARE BEING TOO SLOW. COMBINE THEM.
```

---

## Research Protocol
*Moved verbatim from SKILL.md — the mandate stays there, the worked detail lives here.*


When you encounter something unfamiliar:

1. **Unknown technology/framework** → Research last 3-5 years of CVEs, misconfigs, and exploits
2. **Unknown version** → Search "[tech] [version] CVE [current_year] [current_year-1] [current_year-2]"
3. **Unfamiliar behavior** → Research whether it's intended or anomalous
4. **New vulnerability class** → Study recent writeups and techniques from the last 2-3 years
5. **WAF/protection mechanism** → Research bypasses from current year FIRST, then go back

```
RESEARCH TRIGGERS:
- New technology identified (framework, CMS, API gateway, CDN)
- Specific version number found
- Unexpected behavior or response
- Error message you don't recognize
- Protection mechanism blocking your requests
- Vulnerability class you haven't tested before

MANDATORY RESEARCH PATTERN (run in parallel):
  → IF a CVE MCP is connected (Rule 3.11): use lookup_cve/search_cves/check_poc_availability/
    triage_cve for the [technology]+[version] → CVE → public-exploit mapping (authoritative,
    faster than search). THEN still WebSearch for technique/writeups below. If not connected → WebSearch all:
  → WebSearch: "[technology] [version] CVE [current_year]"
  → WebSearch: "[technology] [version] vulnerability [current_year-1] [current_year]"
  → WebSearch: "[technology] security advisory [current_year]"
  → WebSearch: "[technology] exploit technique [current_year-1] [current_year]"
  → WebSearch: "[technology] bug bounty writeup [current_year-1] [current_year]"

DEEP RESEARCH (if initial search finds nothing):
  → WebSearch: "[technology] [version] CVE [current_year-2] [current_year-3]"
  → WebSearch: "[technology] patch notes security [current_year-1]"
  → WebSearch: "[technology] changelog fix vulnerability [current_year]"
  → WebSearch: "new vulnerability class [current_year] web application"
  → WebSearch: "[technology] 0day [current_year]"

ALWAYS INCLUDE YEARS IN SEARCHES. NEVER SEARCH WITHOUT A YEAR RANGE.
```

**Never attempt an exploit you don't understand. Learn it first. Always research the most recent data.**

---



---

## The Maintainer Review Checklist
*Moved verbatim from SKILL.md — the mandate stays there, the worked detail lives here.*


```
FOR EVERY POTENTIAL FINDING:

1. SCOPE CHECK
   [ ] Is this asset explicitly in scope?
   [ ] Is this bug class accepted by the program?
   [ ] Am I testing within allowed methods?

2. REPRODUCIBILITY CHECK
   [ ] Can I reproduce this from scratch, step by step?
   [ ] Does it work consistently, not just once?
   [ ] Would someone else reproduce it from my steps?

3. DATA SENSITIVITY CHECK
   [ ] Is the exposed data actually sensitive? (PII, auth tokens, financial)
   [ ] Or is it public/intended data? (public profiles, documentation, marketing)
   [ ] Would a user actually be harmed?

4. REAL IMPACT CHECK
   [ ] Is this a real security issue or just a code smell?
   [ ] Does it require unrealistic preconditions?
   [ ] Would a real attacker actually exploit this?
   [ ] What is the WORST-CASE realistic outcome?

5. DUPLICATE CHECK
   [ ] Have I searched for existing reports on this endpoint/bug class?
   [ ] Is this a known issue or intended behavior?
   [ ] Has the program already acknowledged this?

6. SEVERITY HONESTY CHECK
   [ ] Am I rating severity based on actual impact, not wishful thinking?
   [ ] Does my CVSS score match reality?
   [ ] Am I overclaiming to inflate bounty?
```

**If ANY check fails → kill the finding or investigate further before proceeding.**

**Think like the security engineer who will read your report. They see hundreds of reports. They are tired of noise. Make their job easy by only submitting real, well-documented, in-scope vulnerabilities.**



---

## Skill Combination Patterns
*Moved verbatim from SKILL.md — the mandate stays there, the worked detail lives here.*


```
PATTERN 1: RECON → HUNT → VALIDATE → REPORT
  1. Invoke: web2-recon           → enumerate subdomains, discover assets
  2. Invoke: bugbountyrules       → analyze Burp traffic flows (THIS SKILL)
  3. Invoke: web2-vuln-classes    → apply detection patterns for identified vuln class
  4. Invoke: security-arsenal     → get specific payloads and bypass techniques
  5. Invoke: triage-validation    → validate finding passes 7-Question Gate
  6. Invoke: report-writing       → write the submission

PATTERN 2: GRAPHQL TARGET
  1. Invoke: bugbountyrules       → scope check, traffic analysis (THIS SKILL)
  2. Invoke: graphql              → introspection, schema recovery, IDOR patterns
  3. Invoke: web2-vuln-classes    → cross-reference with IDOR/auth bypass techniques
  4. Invoke: triage-validation    → validate before writing

PATTERN 3: ANDROID + WEB API
  1. Invoke: android-reverse-engineering → decompile APK, extract API endpoints
  2. Invoke: bugbountyrules       → analyze all API traffic through Burp (THIS SKILL)
  3. Invoke: web2-vuln-classes    → hunt API-specific vulns (IDOR, auth bypass, injection)

PATTERN 4: WAF BYPASS NEEDED
  1. Invoke: bugbountyrules       → identify WAF, research bypass (THIS SKILL, Rule 12)
  2. Invoke: security-arsenal     → get bypass payloads
  3. Use: WebSearch               → research WAF-specific techniques
```



---

## Finding → Report Bridge
*Moved verbatim from SKILL.md — the mandate stays there, the worked detail lives here.*


```
WHEN A FINDING IS CONFIRMED (passes Rule 14 maintainer review):

1. SAVE final evidence to interesting_findings.json with status "confirmed"
2. INVOKE: triage-validation skill → run 7-Question Gate
   → If ANY question fails → KILL IT, do not report
3. INVOKE: report-writing skill → write the submission
   → Title: impact-first, concrete, under 70 chars
   → Body: reproduction steps with exact HTTP requests from Burp
   → Severity: CVSS 3.1 matching actual demonstrated impact
   → PoC: full proof from evidence collected during hunting
4. REVIEW the draft report through maintainer mindset ONE MORE TIME
   → Would YOU accept this report if you were the triager?
   → Is the severity honest?
   → Is every claim backed by evidence in the report?

DO NOT rush to report. A bad report wastes everyone's time and damages your reputation.
```

---



---

## How to evolve it (the write-back protocol)
*Moved verbatim from SKILL.md — the mandate stays there, the worked detail lives here.*

```
1. DISTILL to a GENERIC, reusable move: the trick + why it works + how to escalate.
   → the exact shape of the writeup-library entries (concrete, actionable, one source link).
2. APPEND to the right file:
   → a real-world trick / bypass / chain        → writeup-library.md (correct class section)
   → deep per-class methodology / attack tree   → portswigger-kb/<Class>/ or references/
   → a recurring discipline gap / real failure  → a rule refinement (note it, keep rule numbering)
3. SCRUB — MANDATORY: NEVER write a real target name, real endpoint/host, PII, token, or
   engagement detail into any skill file. This repo is PUBLISHED to GitHub. Rewrite every
   discovery as a generic technique ("an endpoint that reflects Origin with ACAC:true"),
   never "acme.com/api/x". Real-target data stays ONLY in the engagement's own notes/memory.
4. SYNC EVERY INSTALLED COPY — there are usually MORE THAN TWO. Each agent runtime keeps its
   own copy (~/.claude/skills/<name>/, and one per additional agent CLI you have installed),
   plus the git repo you edit. FIND them, do not assume:
       find ~ -maxdepth 6 -name SKILL.md -path "*<skill-name>*"
   then mirror the repo over each one. **A stale copy is worse than no copy:** a second-opinion
   peer running last week's doctrine will confidently apply rules you already fixed — and you
   will never see it, because its answer looks exactly as authoritative as a current one.
   *(This is not hypothetical: a peer agent was found judging findings from a copy two days
   old, missing the entire severity-calibration gate.)*
5. LOG the evolution in your run notes (what you added + why) so it's traceable.
```


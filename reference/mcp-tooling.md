# Mcp Tooling — bugbountyrules reference

Loaded on demand from SKILL.md. These are the full versions of rules whose
mandate is stated inline in SKILL.md; read this file when the situation calls for it.

## Contents
- RULE 3.5: Burp MCP — deep traffic analysis
- RULE 3.7: HackerOne MCP — program intelligence
- RULE 3.11: CVE / exploit MCP
- Flow Analysis Method
- How to Extract Flows from Burp History
- Cold Start Protocol — When Burp History is Empty

---

## RULE 3.5: BURP MCP — DEEP TRAFFIC ANALYSIS (MANDATORY)

**You MUST use Burp Suite MCP tools to read and analyze ALL in-scope traffic. No exceptions.**

The Burp MCP extension gives you direct programmatic access to Burp's internals. Use it aggressively.

### Available Burp MCP Tools and When to Use Them:

| Tool | Purpose | When to Use |
|---|---|---|
| `mcp__burp__get_proxy_http_history` | Read all proxy traffic | **ALWAYS** — first thing after browsing/testing. Read ALL captured requests. |
| `mcp__burp__get_proxy_http_history_regex` | Filter proxy traffic by regex | When looking for specific endpoints, parameters, tokens, or patterns |
| `mcp__burp__send_http1_request` | Send HTTP/1.1 requests via Burp | For precise request crafting and manipulation |
| `mcp__burp__send_http2_request` | Send HTTP/2 requests via Burp | When target uses HTTP/2 (check with initial probe) |
| `mcp__burp__create_repeater_tab` | Stage requests in Repeater | When you need to modify and resend requests iteratively |
| `mcp__burp__send_to_intruder` | Stage requests for Intruder | For targeted parameter fuzzing and payload insertion |
| `mcp__burp__get_scanner_issues` | Read Burp scanner findings | Check scanner results for leads (but ALWAYS validate manually) |
| `mcp__burp__generate_collaborator_payload` | Generate OOB callback URLs | For SSRF, blind XSS, blind XXE, DNS exfil testing |
| `mcp__burp__get_collaborator_interactions` | Check OOB callbacks received | After injecting collaborator payloads — verify interactions |
| `mcp__burp__set_proxy_intercept_state` | Enable/disable intercept | Toggle intercept for real-time request modification |
| `mcp__burp__url_encode` / `url_decode` | Encode/decode URLs | For payload encoding and response decoding |
| `mcp__burp__base64_encode` / `base64_decode` | Encode/decode Base64 | For token analysis, payload encoding, data inspection |

### Mandatory Burp MCP Workflow:

```
STEP 1: PULL ALL PROXY HISTORY
  → mcp__burp__get_proxy_http_history(count=100, offset=0)
  → Page through ALL results — do NOT stop at first batch
  → BUT: pull it into a FILE or the offload model, not into your own context (Rule 3.12).
    Hundreds of request/response pairs read directly is blind token waste; the coverage is
    mandatory, routing the volume through you is not.
  → Filter in-scope domains only

STEP 2: ANALYZE EVERY REQUEST/RESPONSE
  → Read full request: method, path, headers, body, cookies
  → Read full response: status, headers, body, set-cookie
  → Note: auth tokens, session IDs, CSRF tokens, API keys
  → Note: user IDs, object references, role indicators

STEP 3: FILTER FOR HIGH-VALUE PATTERNS
  → mcp__burp__get_proxy_http_history_regex(regex="api|graphql|admin|user|account|auth|token|session")
  → mcp__burp__get_proxy_http_history_regex(regex="id=|user_id|account_id|order_id")
  → mcp__burp__get_proxy_http_history_regex(regex="password|secret|key|credential")

STEP 4: CHECK SCANNER FOR LEADS
  → mcp__burp__get_scanner_issues(count=50, offset=0)
  → Use as signals for manual testing, NOT as final findings
  → Scanner findings MUST be manually validated

STEP 5: STAGE INTERESTING REQUESTS
  → mcp__burp__create_repeater_tab for requests that need manipulation
  → mcp__burp__send_to_intruder for requests that need parameter fuzzing
```

**Do NOT skip any step. Do NOT be lazy with traffic analysis. Read EVERYTHING in scope.**

---

## RULE 3.7: HACKERONE MCP — PROGRAM INTELLIGENCE & AUTOMATIC CASE RESEARCH (MANDATORY)

**When the target is a HackerOne program and the HackerOne MCP is connected, USE IT AUTOMATICALLY. Never hunt blind — the program's exact scope, accepted weaknesses, and thousands of disclosed reports are one call away. Query them CONTEXTUALLY, without being asked.**

Run `mcp__hackerone__test_connection` once if unsure the MCP is live. If it is not connected, skip this rule and fall back to manual scope + WebSearch research (Rule 10).

### The tools — what and when

| Tool | Use it to | Auto-trigger |
|---|---|---|
| `list_programs` | list programs you can access | picking a target |
| `get_program(handle)` | full policy, offers_bounties, relationships | starting on a program |
| `get_program_scope(handle, in_scope_only, bounty_only)` | exact in-scope (and bounty-eligible) assets | before ANY request → Rule 1 |
| `get_scope_exclusions(handle)` | out-of-scope assets / excluded classes | before ANY request → Rule 1 |
| `get_program_weaknesses(handle)` | accepted CWE types + ids for submission | before hunting / before submit |
| `search_scope(keyword)` | "which program owns asset X? is it in scope?" | an unknown asset appears |
| `hacktivity(query, page_size)` | disclosed-report feed — the intel goldmine | CONTINUOUSLY (see below) |
| `list_my_reports` / `get_report(id)` | your own reports | dedup / track state |
| `get_balance` `get_earnings` `get_payouts` | ROI context | target selection |
| `submit_report(...)` | file a REAL report on HackerOne | ONLY after gates + explicit user OK |

### AUTOMATIC CASE RESEARCH — the core behavior (if→then→try)

**Every situation auto-fires a HackerOne query. Do NOT wait to be told. This is how you "search cases automatically."**

```
I SEE: I'm starting on program "acme"
  → AUTO: get_program("acme") + get_program_scope("acme", in_scope_only=true) + get_scope_exclusions("acme") + get_program_weaknesses("acme")
  → INTERNALIZE scope, exclusions, and accepted classes BEFORE the first request (feeds Rule 1).

I SEE: I'm about to hunt a class (e.g. IDOR) on "acme"
  → AUTO: hacktivity("program:acme") → what have others found here? which endpoints/features? what paid?
  → AUTO: hacktivity("weakness:\"Insecure Direct Object Reference\"") → learn the winning pattern for this class, then replicate it on this target.

I SEE: an unfamiliar domain/asset in the traffic
  → AUTO: search_scope("that-domain") → which program owns it? in scope? (never test unknown assets blind — Rule 9)

I SEE: I think I found a bug
  → AUTO: hacktivity("program:acme") + list_my_reports → search the same endpoint/class → DUPLICATE CHECK before writing a single line.

I SEE: low signal on this surface / choosing what to hunt next
  → AUTO: hacktivity("program:acme") recent → which class is this program actually rewarding lately? Pivot to it.
  → AUTO: hacktivity("severity_rating:critical") → study fresh high-impact patterns to replicate.

I SEE: picking a NEW target
  → AUTO: list_programs + get_balance/get_earnings for ROI context, then get_program_scope to gauge attack surface size.

I SEE: I'm ready to report (and only after passing Rule 13 + Rule 14)
  → AUTO: get_program_weaknesses("acme") → weakness_id; get_program_scope("acme") → structured_scope_id; THEN submit_report — WITH explicit user confirmation.
```

### Hacktivity query patterns (Lucene-style filters)

```
severity_rating:critical                    fresh critical disclosures to learn from
severity_rating:high                        high-impact patterns
weakness:"Cross-site Scripting (XSS)"       class-specific technique study
program:acme                                everything disclosed on this program
disclosed:true                              only fully public reports
# page_size up to 100 for a wider sweep; combine terms to narrow
```

### Duplicate avoidance — critical on HackerOne

**The duplicate test is SAME FIX, not same endpoint.** Two findings are one bug when a single change closes both; they are separate bugs when each needs its own change — even in the same class, even on the same host. An IDOR in one controller and an IDOR in another are two fixes and two reports. Conversely, five reflected parameters all cured by one sanitiser are one bug, and filing them separately reads as padding. Judge by root cause, and say in the report why yours needs its own fix.

Before investing in ANY finding, search hacktivity + list_my_reports for prior reports on this program — matching by root cause, not just by URL. **A duplicate = zero bounty + wasted time.** If it's already disclosed or you've already reported it → find a novel variant or a chain that raises severity, or move on.

### Learn from disclosed reports — free training data

hacktivity is thousands of PAID PoCs. For your target's class, mine it:
- **What impact framing got it paid?** → mimic the severity story.
- **Which endpoints/features were vulnerable?** → check if they (or their siblings) still are.
- **How did top hunters structure the writeup?** → copy the winning report format.
- **Which classes does THIS program actually reward?** → align your Rule 4 priority to reality, not theory.

### Submission discipline — `submit_report` creates a REAL, public-facing report

```
BEFORE submit_report, ALL must be true:
  ✓ Passed Rule 13 (evidence-by-class) — proof, not speculation
  ✓ Passed Rule 14 (maintainer mindset) — in scope, reproducible, real impact, NOT a duplicate
  ✓ weakness_id set (from get_program_weaknesses) AND structured_scope_id set (from get_program_scope)
  ✓ EXPLICIT user confirmation — NEVER auto-submit. This is outward-facing and effectively irreversible.
```

### Integration with the other rules
- **Rule 1 (scope):** replace assumptions with live `get_program_scope` + `get_scope_exclusions`.
- **Rule 4 (priority matrix):** reorder by what THIS program pays (from hacktivity), not generic theory.
- **Rule 10 (research):** hacktivity is program-specific intel — combine it with WebSearch CVE research.
- **Rule 13 / 14:** gate every `submit_report` behind the evidence + maintainer checks.

**Never hunt a HackerOne program without first pulling its scope and its disclosed-report history. The intel is free — use it automatically, every time.**

---

## RULE 3.11: CVE / EXPLOIT MCP — STRUCTURED n-DAY & EXPLOIT INTEL (OPTIONAL ACCELERATOR)

**If a CVE-intel MCP is connected (e.g. `cve-mcp-server`), use it INSTEAD of manual WebSearch for the tech-stack → CVE → public-exploit workflow (Rule 10). It is an authoritative accelerator, not a new attack surface — it speeds the n-day / outdated-component slice of the hunt. If it is NOT connected, fall back to WebSearch (Rule 10) — no behavior change.**

This is optional like the Burp MCP (3.5) and HackerOne MCP (3.7): check availability once, use if live, degrade gracefully if not.
```
Detect: is a cve/CVE MCP tool exposed (mcp__*__lookup_cve / triage_cve / search_exploits)?
  NO  → skip this rule entirely, use Rule 10 WebSearch queries.
  YES → after fingerprinting a component+version (Rule 10), call it instead of guessing:
```

### USE THESE (offensive-relevant only)
- **Fingerprint → known CVEs:** `lookup_cve`, `search_cves`, `bulk_cve_lookup`, `get_cvss_details`, `get_cwe_info`, `get_cve_references` — component+version → the exact CVE list, no flaky search parsing.
- **Is it actually exploitable NOW:** `search_exploits`, `check_poc_availability` (Exploit-DB / Nuclei / GitHub code search) — a CVE with a public PoC is a live lead; one without is a research task. Prefer CVEs you can actually fire.
- **What to try FIRST (hunt where it pays):** `triage_cve`, `get_epss_score`, `check_kev_status`, `prioritize_cves`, `get_trending_cves` — EPSS + CISA-KEV tell you which CVE is being exploited in the wild. Rank by that, not by CVSS alone (Rule 20 systems-thinking).
- **Attack technique context:** `get_mitre_techniques`, `get_attack_patterns` — map a CVE to ATT&CK for the exploitation/chaining path.
- **Whitebox / source-available:** `scan_dependencies`, `scan_github_advisories` (OSV.dev) — dependency manifest → known-vuln components. **`urlscan_check`** for quick web-asset intel.
- **Recon adjunct:** `shodan_host_lookup`, `passive_dns_lookup` — attack-surface / infra discovery (complements normal recon).

### DO NOT bother with (off-mission — blue-team / IR, not bug bounty)
`virustotal_lookup`, `search_malware`, `search_iocs`, `check_ransomware`, `lookup_ip_reputation`, `check_ip_noise` — malware/IOC/threat-intel tooling; irrelevant to exploiting a web target. Ignore them.

**Version ranges in CVE databases are unreliable in BOTH directions — measured, not folklore.** A study of kernel CVE version data found **5.7% false positives** (listed as affected when it is not) and **21.3% false negatives** (vulnerable versions missing from the affected list). So a version match is a LEAD to reproduce, never a finding (Rule 13) — and a version falling OUTSIDE the listed range does **not** mean safe, it means unverified: roughly one vulnerable version in five is simply not on the list. Fingerprint the behaviour, not the banner.

### The honest boundary (why this is an accelerator, not the hunt)
CVE-MCP is **n-day intel**: it shines on outdated/known-vulnerable components. **Most bounty money is in custom-app logic bugs — IDOR, access control, business logic, ATO chains — which have NO CVE.** Use this to close the known-vuln slice FAST, then return to the real hunt (portswigger-kb 3.9 + writeup-library 3.10 + your own testing) for the novel bugs. Never let CVE-matching become the whole engagement. *(To enable it: `claude mcp add` the server + restart; until then Rule 10 WebSearch covers this.)*

---


---

## Flow Analysis Method
*Moved verbatim from SKILL.md — the mandate stays there, the worked detail lives here.*


```
FOR EVERY USER ACTION, MAP THE COMPLETE REQUEST CHAIN:

EXAMPLE — Login Flow:
  Request 1: GET  /login                    → Observe: CSRF token set in cookie/hidden field?
  Request 2: POST /login (credentials)      → Observe: How is session created? Cookie attributes?
  Request 3: GET  /dashboard (redirected)   → Observe: What session token is sent? What data is returned?
  Request 4: GET  /api/user/me              → Observe: How does the API identify the user? Token? Cookie? Both?

  → QUESTIONS TO ASK:
    - Can I skip Request 1 and go straight to Request 2?
    - Can I replay Request 2 without the CSRF token?
    - Can I use the session from Request 3 on a different user's endpoints?
    - Does Request 4 trust the session alone, or does it also check user ID?

EXAMPLE — Registration Flow:
  Request 1: GET  /register                 → Observe: What fields are expected? Hidden fields?
  Request 2: POST /register (user data)     → Observe: What validation? What gets created?
  Request 3: GET  /verify-email?token=X     → Observe: Is token predictable? Can it be reused?
  Request 4: POST /complete-profile         → Observe: Can I set role/permissions here?

  → QUESTIONS TO ASK:
    - Can I register with an existing email?
    - Can I skip email verification (Request 3) and still access the account?
    - Is the verification token brute-forceable?
    - Can I inject admin role in Request 4?

EXAMPLE — Purchase/Payment Flow:
  Request 1: POST /cart/add (item + qty)    → Observe: Is price in the request or server-side?
  Request 2: GET  /cart/summary             → Observe: Is total calculated server-side?
  Request 3: POST /checkout (payment info)  → Observe: Can I modify the total? Race condition?
  Request 4: GET  /order/confirmation       → Observe: IDOR? Can I see other orders?

  → QUESTIONS TO ASK:
    - Can I modify price between Request 1 and Request 3?
    - Can I apply discount codes multiple times (race condition)?
    - Does Request 3 re-validate the cart total?
    - Can I access other users' order confirmations (Request 4 IDOR)?

EXAMPLE — Password Reset Flow:
  Request 1: POST /forgot-password (email)  → Observe: Does response differ for valid/invalid emails?
  Request 2: GET  /reset?token=X            → Observe: Token length? Entropy? Expiration?
  Request 3: POST /reset-password (new pw)  → Observe: Does it invalidate the token after use?

  → QUESTIONS TO ASK:
    - User enumeration via Request 1 response differences?
    - Token predictability or brute-force window?
    - Can the token be reused (Request 3 replay)?
    - Can I reset another user's password by manipulating the token?
```



---

## How to Extract Flows from Burp History
*Moved verbatim from SKILL.md — the mandate stays there, the worked detail lives here.*


```
1. Pull full proxy history:
   → mcp__burp__get_proxy_http_history(count=200, offset=0)

2. Sort/filter by timestamp to reconstruct sequences:
   → Group requests by user action (login, register, purchase, etc.)
   → Follow redirects — they connect the flow

3. For each flow, identify:
   → STATE CARRIERS: cookies, tokens, headers that persist across requests
   → TRUST BOUNDARIES: where the server validates vs. where it trusts
   → TRANSITION POINTS: where one action enables the next
   → RACE WINDOWS: gaps between check and action

4. Hunt at transition points — this is where bugs live:
   → Token issued in Request N but not validated in Request N+2
   → User ID set in Request N but blindly trusted in Request N+3
   → Price calculated in Request N but not re-checked in Request N+4
   → Permission checked in Request N but not in the API call it triggers
```



---

## Cold Start Protocol — When Burp History is Empty
*Moved verbatim from SKILL.md — the mandate stays there, the worked detail lives here.*


```
IF mcp__burp__get_proxy_http_history returns nothing:

1. GENERATE TRAFFIC YOURSELF:
   → Send initial probe requests to in-scope targets via curl (through Burp proxy)
   → curl -sk -x http://127.0.0.1:8080 "https://target.com/"
   → curl -sk -x http://127.0.0.1:8080 "https://target.com/robots.txt"
   → curl -sk -x http://127.0.0.1:8080 "https://target.com/sitemap.xml"
   → curl -sk -x http://127.0.0.1:8080 "https://target.com/.well-known/security.txt"

2. RUN INITIAL RECON (through Burp proxy):
   → Crawl with katana (proxied): katana -u https://target.com -proxy http://127.0.0.1:8080
   → Or manually browse key user flows to populate Burp history
   → Ask the user to browse the target in their Burp-proxied browser

3. THEN PROCEED with step 2 (pull populated Burp history) and continue normally
```


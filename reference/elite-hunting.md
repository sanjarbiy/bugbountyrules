# Elite Hunting — bugbountyrules reference

Loaded on demand from SKILL.md. These are the full versions of rules whose
mandate is stated inline in SKILL.md; read this file when the situation calls for it.

## Contents
- RULE 18: Chaining mindset
- RULE 20: Elite mode — systems & business logic
- What Adaptive Thinking Looks Like
- Vulnerability Priority Matrix — What to Hunt First

---

## RULE 18: CHAINING MINDSET — THINK IN COMBINATIONS

**Single bugs pay less. Chained bugs pay more. Always think: "What can this combine with?"**

Most high-severity bug bounty payouts come from chains, not individual findings. A low-severity open redirect becomes critical when chained with OAuth. A useless self-XSS becomes high when chained with CSRF. An informational SSRF becomes critical when it reaches cloud metadata.

### The Chaining Framework:

```
FOR EVERY FINDING, ASK:
1. What does this give me ACCESS to? (data, functionality, tokens)
2. What does this BYPASS? (auth, validation, WAF, rate limit)
3. What could this FEED INTO? (another endpoint, another vuln class)
4. What would make this CRITICAL? (what's the missing piece?)
5. Have I already found the missing piece? (check interesting_findings.json)
```

### Common Chain Patterns — Always Watch For These:

| Finding A (Low/Info) | + Finding B | = Chain Result (High/Critical) |
|---|---|---|
| Open redirect | OAuth misconfigured redirect_uri | Token theft → ATO |
| Self-XSS | CSRF on same endpoint | Stored XSS → ATO |
| SSRF (DNS only) | Internal metadata endpoint | Cloud credential theft |
| IDOR (read only) | Password reset flow | Account takeover |
| Info disclosure (internal IP) | SSRF to internal network | Internal service access |
| API key (read only) | Key has write permissions | Data modification/deletion |
| Path traversal (limited) | Sensitive file location known | Config/credential theft |
| Rate limit bypass | Login endpoint | Credential stuffing/brute force |
| CSRF | Account settings change | Email/password change → ATO |
| Header injection | Cache server in front | Cache poisoning → mass XSS |
| JWT weak signing | Role claim in token | Privilege escalation |
| Subdomain takeover | Cookie scoped to parent domain | Session hijack |

### How to Build Chains:

```
STEP 1: COLLECT PUZZLE PIECES
  → Save every finding to interesting_findings.json (Rule 17)
  → Tag findings with their "chain potential" in the chain_candidates array
  → Note what each finding gives you (access, bypass, data)

STEP 2: CROSS-REFERENCE CONSTANTLY
  → After EVERY new finding, review interesting_findings.json
  → Ask: "Does this new piece connect to anything I already found?"
  → Check the chain patterns table above
  → Think laterally — chains aren't always from the same vuln class

STEP 3: TEST THE CHAIN
  → Build the full exploitation path step by step
  → Document each step with actual HTTP requests
  → Prove the END RESULT (ATO, data theft, privilege escalation)
  → The chain is only valid if the final impact is real

STEP 4: REPORT AS A CHAIN
  → Title should reflect the final impact, not the individual bugs
  → Show the complete path from start to impact
  → Each step must be reproducible
  → CVSS should reflect the chained impact, not individual findings
```

### What to Save for Chaining (add to `interesting_findings.json`):

```
CHAIN-RELEVANT FINDINGS — ALWAYS SAVE:
  → Tokens that might work on other endpoints
  → IDs from one context that could be used in another
  → Headers that an endpoint expects (found in one place, needed elsewhere)
  → Partial access to functionality (can reach but can't fully exploit — yet)
  → Weak validation points (input accepted but not properly checked)
  → Open redirects (even if "not a bug alone" — they chain with OAuth/SSO)
  → Self-XSS (chains with CSRF)
  → Info disclosure (chains with SSRF, path traversal, social engineering)
  → Race condition windows (chains with payment, credit, or state-change flows)
  → Subdomain patterns (chains with cookie scoping, takeover)
  → CORS misconfigurations (chains with XSS for cross-origin data theft)
  → JWT weaknesses (chains with privilege escalation)
  → Error messages (chains with technology-specific exploits)
```

### The Chaining Discipline:

```
AFTER EVERY FINDING:
  1. Save it (Rule 17)
  2. Tag its chain potential
  3. Cross-reference with ALL previous findings
  4. If a chain is possible → test it immediately
  5. If a chain is ALMOST possible → note what's missing and keep hunting for it

NEVER:
  → Dismiss a finding because "it's only informational"
  → Report individual low findings when a chain would make them high/critical
  → Forget to check interesting_findings.json after each new discovery
  → Stop at the first bug — always look for the chain
```

**Think like a puzzle solver. Every piece matters. The picture only becomes clear when pieces connect.**

---

## RULE 20: ELITE MODE — SYSTEMS THINKING & BUSINESS LOGIC HUNTING

**This rule elevates all other rules. You are not doing basic hunting. You operate at elite level.**

### 1. THINK IN SYSTEMS, NOT ENDPOINTS

Every application is a system. Understand it before attacking it.

```
BEFORE TESTING, MAP THE SYSTEM:
  → Authentication model: How are users identified? Tokens? Sessions? API keys?
  → Authorization model: What roles exist? What can each role do? Where are boundaries?
  → Data flow: Where does sensitive data enter, move, and exit the system?
  → Trust boundaries: Where does the system trust user input? Where does it validate?
  → State machine: What states can an object be in? What transitions are allowed?

THEN ASK:
  → Where does the auth model break down?
  → Where are role boundaries enforced inconsistently?
  → Where can data flow to an unintended destination?
  → Where is trust misplaced?
  → Can I force an invalid state transition?
```

### 2. BUSINESS LOGIC FIRST

Business logic bugs pay the most and have the lowest competition. Hunt them first.

```
BUSINESS LOGIC ATTACK PATTERNS:

STEP SKIPPING:
  → Can I skip email verification and still access the account?
  → Can I skip payment and still receive the product?
  → Can I skip MFA and still authenticate?
  → Can I complete a checkout without adding items?

STATE MANIPULATION:
  → Can I change order status from "pending" to "shipped" directly?
  → Can I modify a subscription tier without paying?
  → Can I revert a canceled account to active?
  → Can I transition a refund back to a charge?

REPLAY & DUPLICATION:
  → Can I replay a discount code after it should expire?
  → Can I apply a referral bonus multiple times?
  → Can I duplicate credits by racing concurrent requests?
  → Can I redeem a one-time offer repeatedly?

PRIVILEGE ABUSE:
  → Can a free user access premium features by manipulating request parameters?
  → Can I invite myself as admin to another organization?
  → Can I escalate from "viewer" to "editor" by modifying a role field?
  → Can a suspended account still perform actions?

NEGATIVE OPERATIONS:
  → Can I set a negative quantity to get a credit instead of a charge?
  → Can I set a negative price?
  → Can I transfer negative amounts?
```

### 3. DIFFERENTIAL TESTING — COMPARE EVERYTHING

The most powerful technique: compare what SHOULD happen vs what DOES happen.

```
ALWAYS COMPARE:

AUTH DIFFERENTIAL:
  → Same request authenticated vs unauthenticated — what changes?
  → Same request as User A vs User B — what leaks?
  → Same request as user vs admin — what extra data appears?

INPUT DIFFERENTIAL:
  → Valid input vs empty input — does it error differently?
  → Expected type vs wrong type (string where int expected) — what breaks?
  → Normal value vs boundary value (0, -1, MAX_INT, very long string)

RESPONSE DIFFERENTIAL:
  → Does a 403 vs 404 reveal whether a resource exists?
  → Does response time differ for valid vs invalid users? (timing side-channel)
  → Does error message content differ based on internal state?

ENVIRONMENT DIFFERENTIAL:
  → Same endpoint on web vs mobile API — different validation?
  → v1 API vs v2 API — old version less protected?
  → Production vs staging (if in scope) — debug info exposed?
```

### 4. TRAFFIC-DRIVEN HUNTING — LET REQUESTS GUIDE YOU

Every request in Burp history is a signal. Read them as an attacker, not a user.

```
FOR EVERY REQUEST, ASK:
  → What parameters are user-controllable? (body, query, headers, cookies)
  → What values does the server trust without re-validation?
  → What can I modify that the developer assumed I wouldn't touch?
  → Are there hidden parameters? (check JS source, response bodies, error messages)

HIGH-VALUE SIGNALS IN TRAFFIC:
  → Parameters named "role", "admin", "is_admin", "user_type" → privilege escalation
  → Parameters named "price", "amount", "total", "discount" → payment manipulation
  → Parameters named "redirect", "url", "next", "return" → open redirect / SSRF
  → Parameters named "file", "path", "template", "include" → LFI / SSTI
  → Sequential numeric IDs → IDOR candidate
  → JWT tokens → decode and check claims, algorithm, signing
  → UUID in URL but numeric ID in response → mixed reference vulnerability
```

### 5. SMART FUZZING — CONTEXT-AWARE, NOT RANDOM

```
FUZZ BASED ON WHAT YOU KNOW:

  → If backend is PHP → fuzz for type juggling ("0", "null", array params)
  → If backend is Python/Jinja2 → fuzz for SSTI ({{7*7}}, {{config}})
  → If backend is Node.js → fuzz for prototype pollution (__proto__, constructor)
  → If API accepts JSON → fuzz field types (string→int, null, array, nested objects)
  → If GraphQL → fuzz with introspection, batching, aliases, directive overloading
  → If file upload → fuzz extensions, content-types, double extensions, null bytes

USE TARGET-SPECIFIC WORDLISTS:
  → Extract terms from the application itself (JS, HTML, API responses)
  → Use those terms as fuzzing dictionary — they match the developer's naming conventions
  → Custom wordlists > generic wordlists, always
```

### 6. PATTERN EXPLOITATION — ONE BUG MEANS MORE BUGS

```
WHEN YOU FIND A BUG:
  → STOP. Do NOT report yet.
  → The developer who made this mistake made it elsewhere too.

PATTERN HUNT:
  → Found IDOR on /api/users/{id}/profile?
    → Test EVERY endpoint with {id}: /orders, /invoices, /settings, /export, /delete
  → Found missing auth on one admin endpoint?
    → Test ALL admin endpoints — they likely share the same broken middleware
  → Found SQLi on one parameter?
    → Test every parameter that touches the same database
  → Found broken validation on one form?
    → Test every form that uses the same validation logic

TIME-BOX: 20 minutes hunting for pattern siblings. If nothing → report the original and move on.
```

### 7. ENVIRONMENT AWARENESS

```
ALWAYS CHECK FOR:
  → Debug/dev endpoints left in production (/debug, /test, /_internal, /swagger, /graphiql)
  → Staging/dev subdomains accessible from the internet
  → Debug headers accepted (X-Debug: true, X-Forwarded-For manipulation)
  → Verbose error messages (stack traces, SQL queries, internal paths)
  → Default credentials on admin panels, databases, or dashboards
  → .git, .env, .DS_Store, backup files exposed

THESE ARE OFTEN THE EASIEST WINS — check them early.
```

### 8. ANTI-FALSE-POSITIVE DISCIPLINE

```
BEFORE CONFIRMING ANY FINDING, TRY TO BREAK IT:

  → Reproduce it 3 times — is it consistent?
  → Try from a different session/IP — still works?
  → Is the "sensitive data" actually public information?
  → Is the "unauthorized access" actually a feature?
  → Would a developer argue this is "by design"?
  → Is the CVSS I'm assigning honest, or am I inflating for a higher payout?

IF YOU CAN ARGUE AGAINST YOUR OWN FINDING SUCCESSFULLY → IT'S NOT A BUG.
```

---


---

## What Adaptive Thinking Looks Like
*Moved verbatim from SKILL.md — the mandate stays there, the worked detail lives here.*


```
DYNAMIC TOOL SELECTION:
  → "The rules mention nmap, but masscan is faster for initial port discovery
     on this large scope. I'll masscan first, then nmap targeted ports."

STRATEGY SWITCHING:
  → "I've been testing IDOR for 15 minutes with no results. The API uses UUIDs
     everywhere — IDOR is unlikely. Switching to business logic testing on the
     payment flow where I noticed inconsistent validation."

CREATIVE COMBINATION:
  → "Burp history shows the app loads a GraphQL schema. Instead of fuzzing
     blindly, I'll pull introspection, map all queries/mutations, then
     target authorization checks on sensitive mutations."

CONTEXT-AWARE SKIPPING:
  → "Rule says check for default credentials, but this is a custom SaaS app
     built on Next.js — there are no 'default credentials.' Skip that,
     focus on the JWT implementation I noticed in the auth flow."

INVENTING APPROACHES:
  → "None of the standard techniques apply here. The app uses a custom binary
     protocol over WebSocket. I need to reverse-engineer the message format
     from the JS client code before I can test anything."
```



---

## Vulnerability Priority Matrix — What to Hunt First
*Moved verbatim from SKILL.md — the mandate stays there, the worked detail lives here.*


Hunt HIGH-ROI bug classes first. Don't waste time on low-payout classes when high-payout ones haven't been tested.

**This order is data-driven, and the data moves — so re-derive it, do not inherit it.** Platform reporting shows authorization flaws (IDOR / broken access control) both climbing and paying, while commodity injection classes decline: broken-access-control criticals up ~36% year over year, API findings up ~10%, and access control sitting at #1 in OWASP 2025 with essentially every tested application showing some form of it. Meanwhile programs putting **AI features in scope grew ~270%** — a new, under-tested surface with far fewer eyes on it. Two consequences: **hunt where the bugs currently are, not where the tutorials point**, and check the platform's own recent disclosures for THIS program (Rule 3.7) before trusting any generic ranking, including this one.

```
PRIORITY 1 (test FIRST — highest payout, often unique):
  → IDOR / Broken Access Control (use two-account method — see below)
  → Authentication bypass (password reset, OAuth, SSO, JWT manipulation)
  → Business logic flaws (payment manipulation, privilege escalation, feature abuse)
  → RCE / SSRF to internal services

  → NEW / recently-shipped surface — and AI features especially: chat, summarisation,
    agents, RAG over user data. Freshly-built, rarely hardened, and the classic classes
    (access control, injection, SSRF via tool calls, data exposure through the model)
    all reappear there wearing new clothes.

PRIORITY 2 (test SECOND — high payout, moderate competition):
  → SQL injection (only where signals exist)
  → Stored XSS on sensitive pages (not self-XSS)
  → Race conditions on state-changing operations (payment, credits, invites)
  → File upload leading to execution

PRIORITY 3 (test IF time remains — moderate payout, high competition):
  → Reflected XSS (needs chain for high severity)
  → CSRF on sensitive actions
  → SSTI (only where template injection signals detected)
  → HTTP request smuggling / cache poisoning

SKIP UNLESS SIGNALS ARE STRONG:
  → Open redirect (only if OAuth/SSO chain possible)
  → Info disclosure (only if leads to further exploitation)
  → Clickjacking (only with state-changing PoC on high-value action)
```


# Operating Discipline - how a professional runs the hunt

Knowledge without discipline is a script kiddie with a big wordlist. This file is the operational layer: how you scope, read traffic, think in flows, prioritize by ROI, prove findings, and reject noise. The vector knowledge lives in the other files; this governs how you *apply* it like a senior operator. (Distilled from battle-tested bug-bounty rules, adapted to the web-attack surface.)

> Authorized lab / CTF / scoped-engagement only.

---

## 1. Scope & authorization first - always

Before a single request:
- Confirm the target is **in scope** (lab sandbox, CTF box, or an asset the engagement explicitly authorizes). If a scope file/program brief exists, read it: in-scope assets, out-of-scope exclusions, **excluded vuln classes**, rate limits, special rules. If scope is ambiguous -> ask, don't assume.
- Confirm allowed actions. **Ask before** destructive writes/deletes on shared targets, mass/aggressive scanning, or anything that could harm real users.
- Never aim payloads outside the sandbox/scope.

## 2. Inspect everything - zero lazy, zero blind requests

- Read the **full** request *and* response - status, every header, body, `Set-Cookie` (and flags), tokens, ids, timing. The bug is usually in a detail you skipped.
- Route traffic through an intercepting proxy (Burp) so nothing is missed and everything is replayable.
- **Zero blind requests:** before you send a payload, know *what you expect* and *what a positive looks like*. A request you can't interpret is wasted. Understand -> hypothesize -> send -> read -> deduce (this is the engine in `attack-engine.md`).
- Decode every cookie/token before testing (`detection-fingerprints.md` decoder).

## 3. Sequential flow analysis - think in chains, not isolated requests

**Bugs hide in the TRANSITIONS between requests, not in single requests.** For every user action, map the whole chain and hunt the gaps.

```
Login flow:    GET /login -> POST /login -> GET /dashboard -> GET /api/user/me
  hunt: skip step 1? replay without CSRF? use session on another user's endpoint? does /me trust session alone or re-check id?
Register flow: GET /register -> POST /register -> GET /verify?token -> POST /complete-profile
  hunt: register existing email? skip verification? token brute-forceable? inject role at complete-profile?
Purchase flow: POST /cart/add -> GET /cart/summary -> POST /checkout -> GET /order/confirm
  hunt: price client-side? total re-validated at checkout? coupon race? IDOR on confirmation?
Reset flow:    POST /forgot-password -> GET /reset?token -> POST /reset-password
  hunt: user-enum from response diff? token entropy/expiry? token reusable? swap to another user's token?
```

**Hunt at transition points:**
```
- token issued in request N but not validated in N+2
- user id set in N but blindly trusted in N+3
- price calculated in N but not re-checked in N+4
- permission checked in N but not in the API call it triggers
- state from one flow injected into another
```
Reconstruct flows from proxy history (group by action, follow redirects). Identify **state carriers** (cookies/tokens), **trust boundaries** (validate vs trust), **race windows** (gap between check and act). This is where the 4-state matrix (`hunt-methodology.md`) and the objective trees pay off.

## 4. Vulnerability priority matrix - hunt high-ROI first

Don't spray. Test the high-impact, often-unique classes before the low-payout, high-competition ones.

```
P1 - FIRST (highest impact, often unique):
   IDOR / broken access control (two-account method) - auth bypass (reset/OAuth/JWT) -
   business-logic / payment manipulation / privilege escalation - RCE - SSRF->internal/cloud
P2 - SECOND (high impact):
   SQLi (where signals exist) - stored XSS on sensitive pages - race on state-changing ops - file-upload->exec
P3 - IF TIME (needs a chain for severity):
   reflected XSS - CSRF on sensitive actions - SSTI (where signals) - request smuggling / cache poisoning
SKIP unless signals/chain are strong:
   open redirect (only if OAuth/SSO chain) - info disclosure (only if it leads somewhere) -
   clickjacking (only with a state-changing PoC)
```
Map this onto the objective the engagement cares about (`objectives-attack-trees.md`) - the goal reorders priorities.

## 5. Two-account method - the highest-ROI technique

For IDOR / access control, nothing finds more than this. Master it.
```
SETUP:  Account A (attacker) + Account B (victim, different data/role). One account only? test with your own ids / ask.
METHOD: 1. As B, perform every action -> capture all requests + note B's ids/object-ids/resource paths.
        2. As A (A's session), replay B's requests - substitute B's ids while authenticated as A.
        3. For each protected resource, enumerate EVERY sibling endpoint:
             /api/user/123/{profile,orders,payments,settings,export,delete}  <- test all
        4. Also: GET/POST/PUT/DELETE on the same resource - id±1 - ids from other users' traffic - GraphQL node(id) - bulk endpoints with mixed ids.
EVIDENCE: response must show B's data while authed as A. 200 OK alone ≠ proof - READ THE BODY.
```
This is the operational form of the 4-state matrix's "Other-user" column.

## 6. Prove it - evidence requirements by class

"It might be vulnerable" is not a finding. Each class has a minimum bar:

| Class | Minimum evidence | NOT enough |
|---|---|---|
| IDOR | another user's data in the body, authed as attacker | 200 OK without reading body |
| XSS | script execution proof (`document.cookie` exfil / DOM action) | `alert(1)` alone |
| SSRF | internal service content or cloud metadata retrieved | DNS callback only |
| SQLi | data extracted (tables/rows) | error or sleep with no data |
| Auth bypass | protected functionality reached + elevated action done | login bypassed, no data |
| RCE | command output (`id`,`whoami`) | theoretical code path |
| File upload | file executes server-side or is retrievable at a known URL | uploaded but not reachable |
| Race | mutually-exclusive ops both succeeded | theoretical timing window |
| Business logic | the unauthorized action completed (price changed, credits dup'd) | "could manipulate" |
| SSTI | expression evaluated (`{{7*7}}`->49) + path to RCE | reflected, no evaluation |
| OAuth | token stolen / victim account reached | misconfig without capture |
| Cache poisoning | poisoned response served to OTHER users | cache-key tinker, self only |
| Privilege escalation | low-priv user does high-priv action, proven | role param changed, no action |

This is the per-class form of the impact gate (`hunt-methodology.md`).

## 7. Maintainer mindset - review your own findings

Before you call anything a finding, put on the skeptical triager's hat:
```
[ ] SCOPE: in-scope asset + accepted class + allowed method?
[ ] REPRO: from scratch, step by step, consistently (not once)?
[ ] SENSITIVITY: is the data actually sensitive, or public/your own?
[ ] IMPACT: real issue or code smell? realistic preconditions? worst realistic outcome?
[ ] SEVERITY HONESTY: rating from actual impact, not wishful thinking - no overclaim.
```
Any check fails -> kill it or dig deeper. The triager is tired of noise; submit only real, proven, in-scope findings.

## 8. Don't chase noise - low-value / prove-or-drop

These are near-worthless **alone** - only matter when chained to real impact. Don't sink time here unless you can complete the chain:
```
self-XSS - logout/login CSRF - missing security headers w/o exploit - version/banner disclosure -
path disclosure w/o further impact - clickjacking on non-sensitive page - "missing rate limit" on
non-sensitive endpoint - SSRF with DNS-callback only - open redirect alone - host-header injection
w/o reset/cache exploit - CORS misconfig w/o proven cross-origin data theft - text/HTML injection w/o JS -
cookie w/o HttpOnly w/o demonstrated theft.
```
If you have one of these, either build the chain that makes it real (`chaining-playbook.md`) or move on. Don't report "could."

## 9. Track findings - the state notebook

Persist everything useful so you can chain later (mentally or in a scratch file):
```
endpoints   : path, method(s), auth state, who can reach it (incl. fuzzed ones)
identifiers  : ids/tokens/emails/secrets seen - sequential? predictable? leaked? where?
primitives   : every confirmed bug + its current max impact + the request that proves it
blocked      : branches you couldn't pass + the exact blocker (revisit when you find the bypass)
flows        : mapped request chains + their transition points
```
When you confirm bug A, scan the notebook - does anything become a step that escalates A? (See `chaining-playbook.md`, cluster rule.)

## 10. Right tool, right moment; research mid-hunt

- Tools are chosen for *this* target, not by habit (`attack-engine.md` adaptive rules). Proxy + Repeater for precision; Intruder/Turbo for brute/race; ffuf/feroxbuster for content; Arjun/Param-Miner for params; the topic-folder Tools sections for class-specific gear.
- When stuck, **fingerprint the exact stack and research it** (WebSearch CVEs/bypasses for that version/WAF) - `attack-engine.md`. Use current-year searches; recently-patched = recently-vulnerable.

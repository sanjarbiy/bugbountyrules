# Hunt Methodology — the autonomous hunt protocol

How this skill drives itself from "here is a target" to "proven, chained finding" with no hand-holding. You are not a scanner. You are an analyst, a strategist, an attacker, and a reviewer. Understand the system, find where it breaks, prove it, chain it.

> Authorized lab / CTF / scoped-engagement only. Verify every asset is in scope before touching it.

---

## Step 0 — Build the mental model (before any payload)

You cannot hunt what you don't understand. Answer these first; they define *high value* and *where to aim*.

```
1. WHAT does the app do?      e-commerce / SaaS / social / fintech / healthcare / admin portal
                             → decides which data and which action is worth stealing.
2. WHO are the actors?        anon · user · staff · admin · superadmin · API consumer
                             → map what each SHOULD do. Every gap between roles is an access-control bug.
3. WHERE is the value?        PII · money movement · role/permission change · file/OS access · ATO paths
                             → these are your priority targets, not reflected-param XSS on a 404 page.
4. HOW does auth work?        session cookie · JWT · OAuth · API key — per-request or per-connection?
                             checked at the gateway or per-object? revoked on logout?
5. WHAT are the crown ops?    transfer, password reset, data export, account delete, privilege grant.
                             → highest-priority mutations/endpoints.
```

Then **map the surface**: every URL, param, header, cookie, JS bundle endpoint, API path, upload, websocket, third-party integration. Read the JS — the frontend tells you every field the backend accepts (including ones the UI never sends).

---

## The hunt loop (phases)

Run as a loop, not a line. New info feeds back into earlier phases.

### 1. RECON
- Enumerate content: `/robots.txt`, `/sitemap.xml`, `/.well-known/`, `/.git`, `/api`, `/graphql`, `/admin`, source maps, backups.
- Fingerprint stack: `Server`, `X-Powered-By`, cookies (`PHPSESSID`/`JSESSIONID`/`connect.sid`/`csrftoken`), framework error pages, JS libraries + versions.
- Two accounts (A=attacker, B=victim). Note all ids and tokens.

### 2. SURFACE MAP
- Inventory every input: query params, body params, JSON fields, headers, cookies, path segments, file uploads, WS messages.
- Triage each by **name-class** (`detection-fingerprints.md` → param-name table) and by **reflection** (does it come back in the response / a link / a later page?).
- Decode every cookie (`detection-fingerprints.md` → cookie decoder).

### 3. DETECT
- Run the **first-60-seconds sweep** from `detection-fingerprints.md`.
- For each tell, fire the **confirm probe** for that class. Don't exploit yet — just confirm the class is live.
- Keep a checklist of which classes you've probed on which surface (see persistence protocol).

### 4. EXPLOIT
- Open the topic folder for the confirmed class. Use its **Technique / Payload arsenal / Bypasses** sections.
- If a defense blocks you, use that class's Bypasses table (WAF encodings, filter tricks) — a block is not a dead end.

### 5. CHAIN
- The moment you have a primitive, ask **"what can I do with this NOW?"** Go to `chaining-playbook.md`.
- Map siblings: the dev who made this mistake made it elsewhere — test every endpoint in the same controller/module.

### 6. PROVE
- Reproduce 3× across fresh sessions. Demonstrate cross-account / real-data impact with two accounts.
- Run the impact gate (bottom of this file). If it passes, it's a finding. If not, build the chain or drop it.

---

## Differential testing — the 4-state matrix

Every data-returning or state-changing request gets tested in four auth states. This single matrix catches most access-control, IDOR, and session bugs.

| State | Token used → target | Catches |
|---|---|---|
| **Owner** | A's token → A's resource | baseline (should succeed) |
| **Other user** | A's token → B's resource | **IDOR** (read and write) |
| **No auth** | no token → any resource | **unauthenticated access** |
| **Wrong auth** | expired/revoked/low-scope token | **session not revoked / scope flaw** |

```
For EVERY request with an id/object reference:
  1. own id + your token        → record baseline
  2. other user's id + token    → same data back? → IDOR CONFIRMED
  3. own id + no token          → data back? → UNAUTH ACCESS
  4. other id + no token        → worst case

For EVERY mutation, also:
  5. target other user's resource           → write IDOR
  6. add elevated fields (role, isAdmin, …) → mass assignment
  7. call out of workflow order             → business-logic / step skip

Meaning of differences:
  same response owner vs other  → IDOR
  data with no token            → broken auth
  200 for expired token         → session not revoked
  different error existing vs not → enumeration oracle
```

---

## Smart fuzzing (not noise)

Don't spray generic wordlists. Inject based on the **param's name-class** and build wordlists from context (schema names, error-leaked tables, app terms, URL segments).

| Param name-class | Inject for | Priority |
|---|---|---|
| `id, user, order, doc, account` | IDOR (enumerate / swap) | HIGH |
| `q, search, sort, orderBy, filter, where` | SQLi / NoSQLi (sort/orderBy often unparam'd) | HIGH |
| `url, next, redirect, callback, dest, host` | SSRF / open redirect | HIGH |
| `file, path, template, download, include` | path traversal / LFI | HIGH |
| `role, permission, admin, isAdmin` | privilege / mass assignment | HIGH |
| `cmd, ping, host, dns, exec` | OS command injection | HIGH |
| `__proto__, constructor, prototype` | prototype pollution | HIGH |
| `amount, price, qty, discount, coupon` | business logic | HIGH |
| `limit, offset, locale, format, theme` | rarely injectable | LOW |

For each reflected input, also send the universal probes: `'` `"` `` ` `` `${{<%[%'"}}` `</b>` `../` — and watch errors, evaluation, and reflection context.

---

## Response & timing analysis

- **Error messages** → table/column/field names (injection map), framework+version (CVE lookup → `Information-disclosure/`), file paths (traversal targets), stack snippets (logic).
- **Response-shape diffs** → A-vs-B field differences (IDOR / role leak), fields present only for some roles (mass-assignment target), null-vs-data (auth boundary).
- **Status / timing oracles** → existing vs non-existing id (enumeration), match vs no-match timing (blind injection / user enum), 200-for-expired (session not revoked).
- **Headers** → missing `HttpOnly` (XSS→theft pays more), loose `SameSite` (CSRF GET bypass), `X-Cache`/`Vary` (cache attacks), `Via`/`Server` (smuggling/CVE), `ACAO`/`ACAC` (CORS).

---

## PERSISTENCE PROTOCOL — do not stop

**The #1 rule.** You stop only when you've proven a valid finding OR probed every applicable class on every surface. Track it:

```
Per surface (each param/header/cookie/endpoint), have you probed:
[ ] injection (SQLi / NoSQLi / OS-cmd / SSTI / XXE) where input shape allows
[ ] reflection (XSS / DOM) for every reflected value
[ ] SSRF / open-redirect for every URL-ish param
[ ] traversal / LFI / upload for every file-ish param
[ ] access control (4-state matrix) for every id / object reference
[ ] business logic / race for every money/limit/workflow operation
[ ] auth / session / token weakness for every auth artifact
[ ] cookie/token class (deserialization / JWT / signed-state) — decoded?
[ ] header attacks (Host / smuggling / cache) where infra allows
[ ] LLM injection if any model processes input
Every surface × every applicable class = checked or proven inapplicable (with reason).
```

### Rationalizations for stopping early — ALL INVALID

| Excuse | Reality |
|---|---|
| "Nothing here, moving on." | Did you decode every cookie? read every JS bundle? diff auth vs anon? run the 4-state matrix? No → keep going. |
| "Introspection is disabled." | 8 bypasses exist (newline, GET, csrf, field suggestions, `__schema` regex evasion). Try them. |
| "It's just an open redirect." | Chain it: OAuth `redirect_uri` → auth code/token theft → ATO. |
| "The WAF blocks my payload." | Every class has a Bypasses table — encodings, case, comments, alternate vectors. A block is a signal, not a wall. |
| "SSRF only does DNS." | Pivot to `169.254.169.254` IMDS → IAM creds, or internal admin → RCE. Prove data/internal access. |
| "Reflected but I can't pop alert." | Wrong context/encoding — try attribute/JS/URL contexts, CSP gadgets, DOM sinks. |
| "Token looks random." | Burp Sequencer it; check reset-token, remember-me, and predictable parts. |
| "Found one bug, done." | Hunt siblings (cluster rule). Then chain A→B→C. Chains pay 3–10×. |

**Pivot the technique, not the target.** Low signal means try harder on this surface, not abandon it — until the checklist is genuinely exhausted.

---

## Impact gate — prove it or drop it

Before anything counts as a finding, it must pass:

> **"Can an attacker do this RIGHT NOW, against a real user who took no unusual action, causing real harm — stolen money, leaked PII, account takeover, or code execution?"**

If **NO** → it is not yet a finding. Either build the chain that makes it real (`chaining-playbook.md`) or drop it.

**Dead on arrival** (don't report alone — chain them or move on): self-only data access, "could theoretically…", open redirect with no chain, SSRF with DNS-only and no internal/data reach, missing security header with no demonstrated exploit, source map without secrets, introspection-enabled with no exploitable query, CSRF on a non-sensitive action.

**Report-worthy checklist:**
```
✓ Reproducible (3×, fresh sessions)
✓ In scope (asset, endpoint, functionality)
✓ Real impact (data leak / privesc / financial / ATO / RCE)
✓ Data is actually sensitive (not public, not your own)
✓ A real attacker would exploit it (practical, not theoretical)
✓ The full chain is proven (actual request → actual response, not "could lead to")
✓ Severity matches real impact (not inflated)
```

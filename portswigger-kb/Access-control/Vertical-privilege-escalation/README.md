# Access control — Vertical privilege escalation

Gain access to functions reserved for higher-privilege users (admin) as a low-priv/unauthenticated user. Routes: discover hidden admin URLs, flip a client-controlled role, or bypass an ACL that keys on URL/method/Referer. Max impact: full admin takeover.

## Quick reference
```
/robots.txt -> Disallow: /administrator-panel      # hidden URL leaked
view-source -> JS reveals /admin-xxxxx URL
Set-Cookie: Admin=false  ->  Admin=true            # role in cookie
profile update JSON: add "roleid":2                 # role editable
X-Original-URL: /admin   (request line = /)         # front-end URL ACL bypass
X-Rewrite-URL: /admin
POST->GET (Change request method) / POST->POSTX     # method-based ACL bypass
Referer: https://LAB/admin  (add when required)     # referer-based ACL bypass
```

## Root cause
The privileged function isn't protected server-side, or protection relies on: obscurity (unguessable URL), a client-controllable role value, or a front-end check on URL/method/Referer that the back-end doesn't re-enforce.

## Technique
**Unprotected admin functionality:** the admin panel has no auth check; find its URL via `robots.txt`, JS source, sitemap, or guessing. Even "unpredictable" URLs leak in client-side JS.

**Role controlled by client data:**
- **Cookie:** login response sets `Admin=false`; change to `true`.
- **Request parameter / profile:** a profile-update request returns/accepts `roleid`; add `"roleid":2` to escalate.

**URL-based ACL bypass:** a front-end blocks `/admin` but the back-end honors `X-Original-URL`/`X-Rewrite-URL`. Send request line `GET /` + `X-Original-URL: /admin` (and put params like `?username=carlos` in the **real** query string).

**Method-based ACL bypass:** ACL enforced only on `POST`. Switch to `GET` ("Change request method"), or use an unknown method (`POSTX`) to see if checks are skipped while the action still runs.

**Referer-based ACL bypass:** the admin action checks `Referer: .../admin`. Forge it (or note its absence is what blocks you) and replay with a low-priv session cookie.

**Advanced / edge:** broken-link/old-endpoint admin functions; parameter-based role in JWT (→ [JWT-attacks](../../JWT-attacks/)); case/encoding tricks on the blocked path (`/Admin`, `/admin/`, `/%61dmin`).

## Payload arsenal
```
GET /robots.txt        GET /sitemap.xml        # discover
Cookie: Admin=true      Cookie: isAdmin=1
{"username":"x","email":"x@x","roleid":2}
X-Original-URL: /admin/delete?username=carlos
X-Rewrite-URL: /admin
Referer: https://LAB-ID.web-security-academy.net/admin
# method swaps: POST->GET, POST->POSTX, ->HEAD
```

## Bypasses
| Defense | Bypass |
|---|---|
| unguessable admin URL | leak via robots/JS/sitemap |
| role in cookie/param | flip the value |
| front-end URL block | `X-Original-URL`/`X-Rewrite-URL` |
| ACL only on POST | switch method (GET/POSTX) |
| Referer check | forge/strip Referer + low-priv cookie |

## Exploitation walkthrough (role via cookie)
1. `/admin` → "not authorized". Login; intercept the response → `Set-Cookie: Admin=false`.
2. Change to `Admin=true`; load `/admin` → panel renders.
3. `GET /admin/delete?username=carlos` → solved.

## Chaining
- ← Horizontal IDOR leaks admin creds → log in → here. → [Authentication](../../Authentication/).

## Tools
- **Burp Repeater**, "Change request method", **Autorize** (auto cross-role testing).

## Labs

### Unprotected admin functionality [Apprentice]
URL: .../lab-unprotected-admin-functionality — `/robots.txt` → `/administrator-panel`; delete carlos. Insight: obscurity ≠ access control.

### Unprotected admin functionality with unpredictable URL [Apprentice]
URL: .../lab-unprotected-admin-functionality-with-unpredictable-url — admin URL leaked in home-page JS; load it. Insight: client-side JS exposes "hidden" URLs.

### User role controlled by request parameter [Apprentice]
URL: .../lab-user-role-controlled-by-request-parameter — login response sets `Admin=false` → set `true`. Insight: role stored in a client cookie.

### User role can be modified in user profile [Apprentice]
URL: .../lab-user-role-can-be-modified-in-user-profile — add `"roleid":2` to the email-update JSON → escalated. Insight: mass-assignment of a privileged field.

### URL-based access control can be circumvented [Practitioner]
URL: .../lab-url-based-access-control-can-be-circumvented — `X-Original-URL: /admin` (request line `/`); params in real query string. Insight: back-end trusts the rewritten URL header.

### Method-based access control can be circumvented [Practitioner]
URL: .../lab-method-based-access-control-can-be-circumvented — promote-user `POST` blocked for non-admin; switch to `GET` → succeeds. Insight: ACL only enforced on POST.

### Referer-based access control [Practitioner]
URL: .../lab-referer-based-access-control — `/admin-roles?username=carlos&action=upgrade` with a forged `Referer: .../admin` + low-priv cookie. Insight: ACL keyed on a spoofable header.

Real-target transfer: enumerate privileged endpoints, then test discovery (robots/JS), client-role flips, and URL/method/Referer header bypasses as a low-priv user.

## Real-world notes
- Vertical escalation is a top bug-bounty/OWASP finding; header-based (`X-Original-URL`) bypasses hit real reverse-proxy stacks.
- Mass-assignment (`roleid`) is rampant in JSON APIs/ORMs.

## References
- https://portswigger.net/web-security/access-control

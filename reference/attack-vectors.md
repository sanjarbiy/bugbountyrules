# Attack Vectors - bugbountyrules reference

The full if->then->try catalogue. SKILL.md carries the engine itself - the loop you run after every
response; everything worked out in detail lives here: the observation -> deduction -> attack table,
the chain examples, and the access-control method that pays most often. Read it when an observation
does not obviously map to vectors, or grep it for the signal you just saw.

## Contents
- Observation -> vector catalogue (the remaining cases)
- "If->Then->Try" Chain Examples - THIS IS HOW YOU THINK
- Two-Account IDOR Method (CRITICAL TECHNIQUE)

---

### "If->Then->Try" catalogue (continued from SKILL.md)

```
I SEE: Parameter "url=https://example.com" in request
  -> THEREFORE: server fetches external URLs -> possible SSRF
  -> SO I TRY: url=http://127.0.0.1 (internal access)
  -> AND I TRY: url=http://169.254.169.254/latest/meta-data/ (cloud metadata)
  -> AND I TRY: url=http://internal-service:8080 (internal services)
  -> AND I TRY: DNS rebinding if direct IPs are blocked

I SEE: Error "Invalid JSON at position 42"
  -> THEREFORE: backend parses JSON manually -> possible injection
  -> SO I TRY: JSON injection with nested objects
  -> AND I TRY: prototype pollution via __proto__
  -> AND I TRY: type confusion (string where number expected)

I SEE: File upload returns path "/uploads/abc123.jpg"
  -> THEREFORE: I can control file content reaching the server
  -> SO I TRY: upload .php/.jsp with image magic bytes
  -> AND I TRY: double extension (file.php.jpg)
  -> AND I TRY: path traversal in filename (../../etc/cron.d/shell)
  -> AND I TRY: SVG with XSS payload
  -> AND I TRY: oversized file (DoS/resource exhaustion)

I SEE: Response time 200ms normally, 2100ms with single quote
  -> THEREFORE: backend likely executes SQL with my input
  -> SO I TRY: time-based blind SQLi (SLEEP, BENCHMARK)
  -> AND I TRY: boolean blind (AND 1=1 vs AND 1=2)
  -> AND I TRY: UNION SELECT to extract data
  -> AND I TRY: sqlmap with --risk=3 --level=5 (after manual confirmation)

I SEE: GraphQL endpoint responds to introspection
  -> THEREFORE: full schema is exposed
  -> SO I TRY: dump schema -> find mutations that modify data
  -> AND I TRY: access mutations meant for admin role
  -> AND I TRY: batch queries to bypass rate limits
  -> AND I TRY: IDOR via node() queries with different IDs
  -> AND I TRY: nested query depth attack

I SEE: Different error message for "user exists" vs "user doesn't exist"
  -> THEREFORE: user enumeration is possible
  -> SO I TRY: enumerate valid usernames/emails
  -> AND I TRY: use valid usernames for credential stuffing
  -> AND I TRY: check if password reset has same enumeration
  -> AND I TRY: combine with rate limit check -> brute force if no limit

I SEE: Price=49.99 in the POST request body
  -> THEREFORE: price is client-controlled, may not be re-validated
  -> SO I TRY: price=0, price=0.01, price=-1
  -> AND I TRY: change currency parameter if present
  -> AND I TRY: race condition on payment (pay once, receive twice)
  -> AND I TRY: modify quantity to negative

I SEE: redirect_uri parameter in OAuth flow
  -> THEREFORE: if validation is weak -> token theft
  -> SO I TRY: redirect_uri=https://evil.com
  -> AND I TRY: redirect_uri=https://target.com.evil.com
  -> AND I TRY: redirect_uri=https://target.com%40evil.com
  -> AND I TRY: open redirect on target.com -> chain to OAuth theft

I SEE: WebSocket connection at wss://target.com/ws
  -> THEREFORE: real-time channel, may have different auth than REST
  -> SO I TRY: connect without auth token
  -> AND I TRY: send other users' IDs in WS messages
  -> AND I TRY: CSWSH (cross-site WebSocket hijacking)
  -> AND I TRY: injection in WS message fields

I SEE: Response header "X-Powered-By: Express"
  -> THEREFORE: Node.js backend
  -> SO I TRY: prototype pollution (__proto__, constructor.prototype)
  -> AND I TRY: SSTI if template engine present ({{7*7}})
  -> AND I TRY: NoSQL injection if MongoDB ({"$gt":""})
  -> AND I TRY: check for /debug, /status, /metrics endpoints
```


---

## "If->Then->Try" Chain Examples - THIS IS HOW YOU THINK
*Moved verbatim from SKILL.md - the mandate stays there, the worked detail lives here.*


```
I SEE: Response contains user_id: 1042
  -> THEREFORE: IDs are sequential integers, not UUIDs
  -> SO I TRY: user_id=1041, 1043, 1040 on every endpoint (IDOR)
  -> AND I TRY: user_id=1 (admin is often ID 1)
  -> AND I TRY: user_id=0, -1, 99999999 (boundary values)

I SEE: Set-Cookie: session=eyJhbG... (JWT)
  -> THEREFORE: Auth uses JWT, claims are decodable
  -> SO I TRY: decode -> check algorithm -> try alg:none
  -> AND I TRY: modify role claim -> re-sign with weak secret
  -> AND I TRY: use expired token -> check if expiry enforced
  -> AND I TRY: brute-force secret with jwt_tool/hashcat

I SEE: 403 Forbidden on /api/admin/users
  -> THEREFORE: endpoint exists, I'm just not authorized
  -> SO I TRY: different HTTP methods (PUT, DELETE, PATCH)
  -> AND I TRY: path bypass (/api/admin/../admin/users, /api/ADMIN/users)
  -> AND I TRY: add X-Original-URL: /admin/users header
  -> AND I TRY: access as different user role if I have another account
  -> AND I TRY: remove auth header entirely (sometimes 403->200)

```

**The remaining observation->vector cases (13 in total: JWT, 403, SSRF params, JSON errors,
file uploads, GraphQL, redirects, race windows and more) follow below - grep this file for
the exact signal you just saw.**



---

## Two-Account IDOR Method (CRITICAL TECHNIQUE)
*Moved verbatim from SKILL.md - the mandate stays there, the worked detail lives here.*


This finds more paid bugs than any other technique. Master it.

```
SETUP:
  -> Account A (attacker): your primary account
  -> Account B (victim): second account with different role/data
  -> If program provides only one account: ask user, or test with your own data

METHOD:
  1. Log in as Account B -> perform actions -> capture all requests in Burp
  2. Extract: user IDs, object IDs, resource URLs from Account B's traffic
  3. Log in as Account A -> replay Account B's requests using Account A's session
  4. For each request, substitute:
     -> Account B's user_id with Account A's credentials
     -> Account B's object_id in Account A's session
     -> Account B's resource path with Account A's auth token

  CHECK EVERY SIBLING ENDPOINT:
  If /api/user/123/profile requires auth:
    -> /api/user/123/orders     <- check
    -> /api/user/123/payments   <- check
    -> /api/user/123/settings   <- check
    -> /api/user/123/export     <- check
    -> /api/user/123/delete     <- check

  ALSO TEST:
    -> GET vs POST vs PUT vs DELETE on same resource
    -> Numeric ID ± 1 (sequential enumeration)
    -> Object ID from Burp history of another user
    -> GraphQL node() queries with different IDs
    -> Batch/bulk endpoints with mixed IDs

EVIDENCE REQUIRED:
  -> Response MUST show Account B's data while authenticated as Account A
  -> 200 OK alone is NOT proof - read the response body
  -> Screenshot showing both accounts' data side-by-side is ideal
```


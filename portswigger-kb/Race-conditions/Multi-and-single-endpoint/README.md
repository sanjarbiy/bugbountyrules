# Race conditions — Multi-endpoint & single-endpoint (hidden sub-states)

Beyond limit overruns: a single request runs a hidden multi-step sequence, transitioning through invisible **sub-states** you can exploit by colliding requests. Two shapes: **multi-endpoint** (race two different endpoints that share a sub-state, e.g. add-to-cart vs checkout) and **single-endpoint** (parallel requests with different values to one endpoint, e.g. password reset). Impact: buy more than you can afford, get another user's reset token, bypass MFA.

## Quick reference

```
# Methodology: predict collision -> benchmark (sequence) -> attack (parallel single-packet) -> prove
# Multi-endpoint: race the window between two operations in one flow
POST /cart            (add item)        \ fire together, single-packet
POST /cart/checkout   (validate+confirm)/  -> add items after payment validated, before confirm
# Single-endpoint: 20 parallel requests, DIFFERENT value each, to one shared-record endpoint
POST /my-account/change-email  email=test1@... | test2@... | ... (x20 parallel)
# Window alignment fixes:
- connection warming: prepend GET / ; "Send group in sequence (single connection)"
- abuse rate/resource limit -> induce server-side delay (keeps single-packet viable)
# Session locking (PHP etc.): if requests serialize -> use a DIFFERENT session token per request
```

## Root cause
A single request internally does step1→step2→…; between steps the app sits in a sub-state (logged-in-but-MFA-not-enforced; order-validated-but-not-confirmed; one-pending-email-row). Colliding requests interleave their steps and exploit that sub-state — the time-sensitive analogue of multi-step business-logic flaws.

## Find it (methodology)
1. **Predict:** test only security-critical endpoints where ≥2 requests hit the **same record**. Counter-example: parallel resets for two *different* users that edit two *different* rows won't collide; but a reset that writes a *single shared* session entry will.
2. **Benchmark:** group requests → "Send group in **sequence** (separate connections)" → record normal behavior (responses, emails, side effects).
3. **Attack:** same group → "Send group in **parallel**" (single-packet / last-byte sync). Look for ANY deviation — incl. second-order (different email contents, later state change).
4. **Prove:** trim to the minimal request set; replicate.

## Technique
**Multi-endpoint:** race the window between two operations that occur across endpoints in one flow. Classic: add-to-cart vs checkout — fire `POST /cart` and `POST /cart/checkout` together so items get added **after** the credit check but **before** order confirmation.
- **Aligning race windows** (the hard part): delays come from (a) network architecture (FE→BE connection setup) and (b) endpoint-specific processing time.
  - **Connection warming:** prepend an inconsequential `GET /` to the group and use "Send group in sequence (single connection)"; if only the first request is slow and the rest cluster, ignore that initial delay.
  - **Abuse rate/resource limits:** if warming doesn't help and you need delayed execution, flood dummy requests to trigger a rate/resource limit → induces a **server-side** delay → keeps the single-packet attack viable (vs Turbo's client-side delay which forfeits single-packet and fails on high jitter).

**Single-endpoint:** send parallel requests with **different values** to one endpoint that edits a shared record. Classic: password reset stores `reset-user` + `reset-token` in the session; two parallel resets (different usernames, same session) interleave so the session ends with the **victim's** user but a token **you** received → reset the victim. Email-confirmation flows are great targets (emails sent in a background thread after the HTTP response → wider window).

**Session-based locking:** some frameworks (PHP native sessions) process **one request per session at a time**, serializing your attack and masking the bug. Tell-tale: all requests processed sequentially. Fix: send each request with a **different session token**.

**Advanced / edge:** hidden MFA sub-state (login request + request to an authenticated endpoint, racing the "enforce_mfa" flag) — see [Authentication 2FA bypass](../../Authentication/Multi-factor-auth/). Treat each race as a structural primitive.

## Payload arsenal
```
# multi-endpoint (single-packet group)
POST /cart            body: productId=2&quantity=1
POST /cart/checkout   body: csrf=...
# single-endpoint: 20 tabs, unique local-part each
POST /my-account/change-email  body: email=test{N}@exploit-...exploit-server.net   (x20 parallel)
# connection warming
GET /            (prepended)  -> Send group in sequence (single connection)
```

## Bypasses
| Blocker | Bypass |
|---|---|
| race windows misaligned (network/endpoint delay) | connection warming; abuse rate limit for server-side delay |
| requests serialize | session locking → different session token per request |
| single endpoint, need distinct values | give each parallel request a unique value (email{N}) |
| HTTP/1 only | last-byte sync |

## Exploitation walkthrough (single-endpoint email change → ATO precursor)
1. Confirm the app stores **one pending email at a time** (a new pending email invalidates the prior link) ⇒ shared record ⇒ collision potential.
2. Benchmark: duplicate `POST /my-account/change-email` to ~20 tabs, unique local-parts, "Send in sequence" → 20 distinct emails.
3. Attack: "Send group in parallel" (single-packet). A collision yields a **single** confirmation email whose token validates a **different** pending address than intended → bypass the email-ownership check (lab: register/confirm to a different domain).

## Chaining
- → [Business-logic-vulnerabilities](../../Business-logic-vulnerabilities/) (insufficient workflow validation, time-sensitive).
- → [Authentication](../../Authentication/) (MFA race bypass; reset-token theft → ATO).
- → [Access-control](../../Access-control/).

## Tools
- **Burp Repeater** (parallel/sequence; single-connection for warming; "Trigger race conditions").
- **Turbo Intruder** (warming requests then attack; retries).

## Labs

### Multi-endpoint race conditions [Practitioner]
URL: /web-security/race-conditions/lab-race-conditions-multi-endpoint
- Race `POST /cart` vs `POST /cart/checkout` in one single-packet group so items are added in the window between payment validation and order confirmation → order a gift card / pricier item you can't afford. Use connection warming if windows misalign.
- Insight: validate-then-confirm in one request leaves a window to mutate the cart.

### Single-endpoint race conditions [Practitioner]
URL: /web-security/race-conditions/lab-race-conditions-single-endpoint
- ~20 parallel `change-email` requests with unique values; collision makes the confirmation token validate an unintended pending email → bypass the @domain restriction.
- Insight: a single shared "pending email" record + background email thread = exploitable single-endpoint race.

Real-target transfer: map flows where one request does check→act, or where one endpoint edits a shared record (reset/confirm/email). Benchmark sequence vs parallel; any deviation = a race.

## Real-world notes
- Hidden multi-step races (PortSwigger "Smashing the state machine") are an emerging, high-value class — many real apps have invisible sub-states.
- Session locking masks bugs; always test with multiple session tokens.
- Window alignment is the practical bottleneck — connection warming + rate-limit-induced delay are the key tricks.

## References
- https://portswigger.net/web-security/race-conditions (Hidden multi-step sequences, Multi-endpoint, Single-endpoint)

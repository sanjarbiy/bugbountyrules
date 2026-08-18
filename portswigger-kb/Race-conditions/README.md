# Race conditions - topic overview & router

A site processes concurrent requests without proper locking, so two requests touch the same data inside a tiny "race window" (often sub-millisecond) and collide, producing unintended behavior. A subtype of TOCTOU (time-of-check to time-of-use). Impact = whatever the colliding logic guards: redeem a coupon/gift card N times, overdraw a balance, bypass rate limits/MFA, reset another user's password, forge an uninitialized API key. The enabling tool is the **single-packet attack** (HTTP/2) which fires 20-30 requests truly simultaneously.

## 30-second quick reference

```
# Fire parallel requests (neutralize network jitter):
Burp Repeater -> group tabs -> "Send group in parallel"
   HTTP/2 -> single-packet attack (20-30 reqs in ONE TCP packet)
   HTTP/1 -> last-byte synchronization
# Benchmark first: "Send group in sequence (separate connections)" -> compare to parallel.

# Turbo Intruder single-packet (HTTP/2 only):
engine = RequestEngine(endpoint=target.endpoint, concurrentConnections=1, engine=Engine.BURP2)
for i in range(20): engine.queue(target.req, gate='1')
engine.openGate('1')

# Common collisions:
- apply 1-time coupon/gift card twice simultaneously  -> stack discount
- 20 parallel login attempts                          -> bypass per-username rate limit
- parallel password-reset w/ 2 usernames (same session) -> get victim's token
- user=victim&api-key[]=  during registration window   -> empty/null API key matches
```

## Decision map - pick the sub-technique

| Observation | Go to | Why |
|---|---|---|
| Single-use limit / rate limit on a security-critical endpoint | [Limit-overrun](Limit-overrun/) | overrun the limit with parallel requests (single-packet attack) |
| A single request runs a hidden multi-step sequence; or two endpoints share a sub-state | [Multi-and-single-endpoint](Multi-and-single-endpoint/) | exploit hidden sub-states; methodology + window alignment |
| Token = timestamp-based, or object built in 2 SQL steps (uninitialized field) | [Time-sensitive-and-partial-construction](Time-sensitive-and-partial-construction/) | collide timestamps; hit the uninitialized-value window |

## Sub-technique folders
- `Limit-overrun/` - limit/rate-limit overrun via the single-packet attack (2 labs)
- `Multi-and-single-endpoint/` - hidden multi-step sub-states, multi-endpoint + single-endpoint races, the detection methodology, connection warming, session-locking (2 labs)
- `Time-sensitive-and-partial-construction/` - timestamp-token collisions; partial-construction (uninitialized value) races (2 labs)

## Root cause
Concurrent request processing without atomicity: the app does check-then-act (TOCTOU) and the **update lags the check**, leaving a race window. Often a single request transitions through invisible **sub-states** (e.g. "logged in but MFA not yet enforced", "user created but API key not yet set").

## Find it (methodology - from "Smashing the state machine")
1. **Predict collisions:** only test **security-critical** endpoints where ≥2 requests operate on the **same record** (e.g. a reset flow that edits one shared session entry, not two separate user rows).
2. **Probe for clues:** benchmark with **sequence (separate connections)**, then fire the same group **in parallel** (single-packet); look for ANY deviation (response change, different email, later behavior change).
3. **Prove the concept:** strip superfluous requests, confirm you can replicate. Treat each race as a structural weakness - chase the max-impact primitive.

## Tools
- **Burp Repeater** 2023.9+: "Send group in parallel" (auto single-packet for h2 / last-byte-sync for h1); "Send group in sequence" for benchmarking; "Trigger race conditions" custom action (Pro, one-click).
- **Turbo Intruder** (`Engine.BURP2`, gates) for retries, staggered timing, huge volumes, connection warming.

## Chaining
- -> [Business-logic-vulnerabilities](../Business-logic-vulnerabilities/): races are time-sensitive logic flaws (insufficient workflow validation, etc.).
- -> [Authentication](../Authentication/): race-bypass MFA, rate limits, password reset (single-endpoint).
- -> [Access-control](../Access-control/): partial-construction forges privileged API keys.
- Single-packet attack overlaps the [HTTP-request-smuggling](../HTTP-request-smuggling/) timing toolkit.

## References
- https://portswigger.net/web-security/race-conditions
- Whitepaper: "Smashing the state machine: The true potential of web race conditions" (James Kettle / PortSwigger, Black Hat USA 2023)

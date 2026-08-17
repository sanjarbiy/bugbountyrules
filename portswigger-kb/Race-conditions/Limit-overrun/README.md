# Race conditions — Limit overrun

The classic race: exceed a limit the business logic enforces (one-time coupon, gift-card redeem, per-account rate limit) by firing parallel requests so multiple land inside the race window before the "you've used it" flag is written. Impact: stack discounts, redeem gift cards N×, overdraw balance, reuse a CAPTCHA, defeat anti-brute-force rate limits.

## Quick reference

```
# 1) study the limited endpoint (e.g. POST /cart/coupon -> "Coupon already applied" on reuse)
# 2) benchmark: group the request tabs -> "Send group in sequence (separate connections)"
# 3) attack: same group -> "Send group in parallel"   (h2 => single-packet attack)
# Turbo Intruder (h2 only):
engine = RequestEngine(endpoint=target.endpoint, concurrentConnections=1, engine=Engine.BURP2)
for i in range(20): engine.queue(target.req, gate='1')
engine.openGate('1')        # all fire in ONE packet
```
Decision list: any single-use or rate-limited endpoint with security/financial value → send 20-30 of it in parallel and check if you overran the limit.

## Root cause
Check-then-update isn't atomic: the app verifies "coupon unused / under limit", applies the effect, *then* updates the record. Requests that arrive in the window between check and update all pass the check → the limit is overrun.

## Find it
- Identify a **single-use** (coupon, gift card, one-time token) or **rate-limited** (login attempts, OTP) endpoint with impact.
- Confirm the state is server-side and keyed on session/user (e.g. `GET /cart` empty without the session cookie ⇒ cart state is per-session ⇒ collision potential).
- Benchmark sequentially, then fire in parallel; success = the limit was exceeded (discount applied twice, login allowed past the cap).

## Technique
1. **Map the endpoint** and its restriction ("Coupon already applied", "blocked after 3 attempts").
2. **Group + duplicate** the request in Repeater (≈20 tabs). For rate-limit bypass, keep the same body; for value collisions keep identical.
3. **Benchmark:** "Send group in sequence (separate connections)" → see normal serialized behavior.
4. **Attack:** "Send group in parallel" → Burp uses the **single-packet attack** (h2: 20-30 requests in one TCP packet, eliminating network jitter) or **last-byte sync** (h1).
5. Sending ~20 (not just 2) also absorbs **server-side jitter** during discovery.

**Advanced / edge:** Turbo Intruder `Engine.BURP2` + gates for retries/volume; abuse rate limits to induce a server-side delay (see `../Multi-and-single-endpoint/`); if requests serialize, suspect session locking (use different session tokens).

## Payload arsenal
```
# Repeater: group N identical requests, Send group in parallel
POST /cart/coupon  body: csrf=...&coupon=PROMO20     (x20 parallel)
# rate-limit bypass: 20x POST /login with a candidate password in ONE packet
POST /login  body: username=carlos&password=GUESS    (x20 parallel)
# Turbo Intruder single-packet template: race-single-packet-attack.py (BApp examples)
```

## Bypasses
| Blocker | Bypass |
|---|---|
| network jitter desyncs requests | single-packet attack (h2) / last-byte sync (h1) — "Send group in parallel" |
| server-side jitter | send ~20-30 instead of 2 |
| requests serialize (per-session lock) | use a different session token per request |
| HTTP/1 only | last-byte sync (single-packet needs h2) |

## Exploitation walkthrough (limit-overrun coupon)
1. Buy cheapest item; apply discount; note `POST /cart/coupon` → reuse gives "Coupon already applied".
2. Confirm cart is server-side/per-session (`GET /cart` empty without cookie).
3. Group `POST /cart/coupon`, duplicate to ~20 tabs, **Send group in parallel**.
4. Multiple requests pass the "unused" check before the DB updates → discount applied repeatedly → order total drops below threshold → solved.

## Chaining
- Rate-limit overrun → brute-force in [Authentication](../../Authentication/) (defeats the lockout).
- Financial overrun → [Business-logic-vulnerabilities](../../Business-logic-vulnerabilities/).

## Tools
- **Burp Repeater** (Send group in parallel/sequence; "Trigger race conditions" custom action in Pro).
- **Turbo Intruder** (`Engine.BURP2`, `gate`/`openGate`).

## Labs

### Limit overrun race conditions [Apprentice]
URL: /web-security/race-conditions/lab-race-conditions-limit-overrun
- Predict collision (cart state per-session). Group `POST /cart/coupon`, ~20 parallel (single-packet) → discount applied multiple times → buy the jacket under budget.
- Insight: the "coupon used?" check and the DB update aren't atomic; parallel requests all pass the check.

### Bypassing rate limits via race conditions [Practitioner]
URL: /web-security/race-conditions/lab-race-conditions-bypassing-rate-limits
- Rate limit is per-username, counter stored server-side. Benchmark a failed `POST /login`; duplicate to ~20 tabs with candidate passwords; send in parallel (single-packet) → many attempts land before the counter increments → crack the password without tripping the lockout.
- Insight: the failed-attempt counter lags the auth check → parallel guesses bypass the limit.

Real-target transfer: any one-time/limited action with value (coupons, gift cards, votes, withdrawals, OTP attempts) — fire 20-30 in parallel and check if the limit broke.

## Real-world notes
- Limit-overrun is the most common, highest-paying race in the wild (financial: discounts, balances, gift cards).
- Needs HTTP/2 for the cleanest single-packet attack; many CDNs/sites support h2.
- On live targets, use the minimum requests to prove it; don't actually drain funds.

## References
- https://portswigger.net/web-security/race-conditions (Limit overrun)

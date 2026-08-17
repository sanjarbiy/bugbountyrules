# Race conditions — Time-sensitive & partial construction

Two advanced shapes. **Time-sensitive:** a security token is derived from a high-resolution timestamp (not CSPRNG) — fire two requests in the same microsecond to make them generate the **same** token. **Partial construction:** an object is built in multiple steps (e.g. create user, then set API key) leaving a window where a field is **uninitialized** (empty/null) that a security check then matches. Impact: reset another user's password via a shared token; authenticate as a half-created user with an empty key.

## Quick reference

```
# Time-sensitive: collide timestamps so two users get the SAME reset token
POST /forgot-password  username=carlos   \  send in parallel (single-packet),
POST /forgot-password  username=you      /  same timestamp => same token
# Defeat per-session PHP lock first: send each with a DIFFERENT session token.

# Partial construction: hit the window where api-key is still NULL/empty
GET /api/user/info?user=victim&api-key[]= HTTP/2     # PHP: param[]= -> []  (matches uninitialized)
# Rails: ?api-key[key]   -> {"key"=>nil}             # JSON null matches uninitialized
# fire many /register (or /confirm) + many auth-with-empty-key requests in parallel
```

## Root cause
**Time-sensitive:** token = `hash(timestamp)` or timestamp-seeded RNG → not unique across simultaneous requests. **Partial construction:** non-atomic multi-statement object creation → a transient state where a column is the datastore default (`''`/`NULL`); if a later auth check compares attacker input to that column and you inject a value that equals the default (empty string / JSON null / empty array), you pass during the window.

## Find it
- **Time-sensitive:** request the token a few times — same length each time, but different value ⇒ likely contains internal state (RNG/counter/**timestamp**). If parallel requests still serialize (different tokens, big delay), suspect **per-session locking** (PHP) → use different session tokens, then re-test.
- **Partial construction:** find multi-step object creation (registration → set API key/password). Probe the auth/confirm endpoint with empty/array/null values: an **empty** value giving `Forbidden` (vs "Incorrect token" for wrong, "Missing parameter" for absent) hints the empty-value path was *patched* — the race window may still expose it.

## Technique
**Time-sensitive token collision:**
1. Study the reset flow; confirm the token varies per request and is fixed-length (hash-like).
2. Bypass **session locking** (PHP): obtain a token-less `GET /forgot-password` to drop the session cookie, and/or send each request with a distinct session token so they process concurrently.
3. Fire two `POST /forgot-password` (your username + victim's) **in parallel** (single-packet). If both hit the same timestamp, both reset tokens are identical → use the token from *your* email to reset the *victim's* password.

**Partial construction:**
1. Find the window between object creation and field initialization (e.g. registration creates the user row, a second statement sets `api_key`).
2. Inject a value that equals the **uninitialized** default using framework array/null syntax:
   - PHP: `api-key[]=` → `[]`; `param[]=foo&param[]=bar` → `['foo','bar']`.
   - Rails: `api-key[key]` (key, no value) → `{"key"=>nil}`.
3. Race many creation requests against many authenticated requests carrying the empty key (`GET /api/user/info?user=victim&api-key[]=`). During the window the stored key is empty/null and your empty input matches → authenticated as the victim.
4. **Password variant:** harder — the empty value is hashed, so you'd need an input whose hash equals the uninitialized stored hash.

**Advanced / edge:** combine with email-confirmation timing; use Turbo Intruder to interleave two request groups (creation + auth) with gates; partial construction can also expose uninitialized session/permission fields.

## Payload arsenal
```
# time-sensitive (parallel single-packet, distinct sessions)
POST /forgot-password   body: username=carlos
POST /forgot-password   body: username=wiener
# partial construction (race register/confirm vs auth-with-empty-key)
POST /confirm?token=     -> Forbidden (patched empty path; race it anyway)
GET  /api/user/info?user=victim&api-key[]= HTTP/2          # PHP empty array
GET  /api/user/info?user=victim&api-key[key] HTTP/2        # Rails nil
```

## Bypasses
| Blocker | Bypass |
|---|---|
| per-session locking (PHP) serializes | distinct session token per request; drop session cookie |
| token looks random | check fixed length + per-request variance → timestamp/RNG state |
| empty token returns Forbidden (patched) | race the window — the patch may only cover the steady state |
| value is a string | use array/null syntax (`[]`, `[key]`) to match uninitialized default |

## Exploitation walkthrough (time-sensitive reset)
1. Reset your own password → link `?user=you&token=...`; resend a few times → tokens differ but same length ⇒ timestamp-seeded.
2. Parallel resets serialize (PHP lock) → send each with a different session token to force concurrency.
3. Fire `POST /forgot-password` for `carlos` and `you` in one single-packet group. Same microsecond ⇒ identical token.
4. Use the token from **your** email against the **victim's** reset → take over `carlos`.

## Chaining
- → [Authentication](../../Authentication/): shared reset token = ATO; empty-key auth bypass.
- → [Access-control](../../Access-control/): partial-construction forged API key → privileged access.
- → [Information-disclosure](../../Information-disclosure/): predictable timestamp tokens.

## Tools
- **Burp Repeater** ("Send group in parallel"; distinct sessions per tab).
- **Turbo Intruder** (gates to interleave creation + auth groups; retries for the narrow window).

## Labs

### Exploiting time-sensitive vulnerabilities [Practitioner]
URL: /web-security/race-conditions/lab-race-conditions-exploiting-time-sensitive-vulnerabilities
- Reset token is timestamp-based; PHP per-session lock serializes requests → use different session tokens; fire two resets (you + carlos) in parallel so both get the **same** token; reset carlos with the token from your email.
- Insight: timestamp tokens collide under simultaneous requests; beat session locking with multiple sessions.

### Partial construction race conditions [Expert]
URL: /web-security/race-conditions/lab-race-conditions-partial-construction
- Registration builds the user then sets the key in separate steps; only `@ginandjuice.shop` emails allowed (no inbox). Race many `POST /confirm` against many authenticated requests using `api-key[]=` (empty array) so an empty/null key matches the uninitialized value during the window → act as a confirmed user.
- Insight: a transient uninitialized field + framework empty-array syntax = auth bypass in the construction window.

Real-target transfer: tokens that vary by length-fixed value → test timestamp collisions; multi-statement object creation (user+key/password) → race auth with empty-array/null inputs.

## Real-world notes
- Both classes come from PortSwigger's "Smashing the state machine" research; partial construction is Expert-level and rare but high-impact.
- Timestamp-token collisions also matter outside races (predictable tokens) — see [Information-disclosure](../../Information-disclosure/).
- On live targets these are delicate (narrow windows); prove with your own accounts.

## References
- https://portswigger.net/web-security/race-conditions (Partial construction, Time-sensitive attacks)

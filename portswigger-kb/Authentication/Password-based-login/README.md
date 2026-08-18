# Authentication - Password-based login (enumeration & brute-force)

Two-stage login attack: first **enumerate a valid username** by spotting a behavioural tell, then **brute-force its password** while defeating the site's rate-limiting. Max impact: account takeover (often admin/`carlos`) with no prior access.

## Quick reference

```
# enumeration tells - run username list in Intruder, compare:
Length column   -> one response longer ("Incorrect password" vs "Invalid username")
Grep-Extract    -> error text subtly differs (trailing space / "." vs " ")
Status          -> 200 vs 302 (302 = success)
Timing          -> valid user + ~100-char password = noticeably slower response
Account-lock    -> "too many attempts" message only for real users (Null payloads x5)

# brute-force protection bypasses:
X-Forwarded-For: 1..100         # IP-block bypass (spoof source each request)
[you, carlos, carlos, ...]      # interleave own creds to reset failed-attempt counter
"password":["a","b","c"]        # JSON array -> N guesses in ONE request (rate-limit bypass)
```
Decision list: enumerate username first (cheap shortlist) -> then password. If IP-blocked, add `X-Forwarded-For`. If "logout after N fails", interleave your own valid creds or use a session macro. If creds are JSON, try a password array.

## Root cause
Login responses leak whether a username is valid (non-uniform errors/status/timing/lock messages), and brute-force defenses are bypassable (IP-based, counter-resettable, or per-request rather than per-guess).

## Find it (recon and detection)
- **Username sources:** public profiles, `@company.com` patterns, `admin`/`administrator`, emails leaked in responses.
- **Login probe:** submit invalid:invalid, then valid-looking:invalid. Watch the 4 tells (length, error text, status, time). Use Intruder **Grep-Extract** on the error message to catch invisible diffs (trailing space).
- **Rate-limit probe:** spam bad logins - does your IP get blocked? Does the account lock? Does a successful own-login reset the counter? Is `X-Forwarded-For` honored?

## Technique
**Username enumeration:**
- **Different responses:** Intruder Sniper on `username`, static wrong password. Sort by **Length** - the odd one out says "Incorrect password" (valid user) vs "Invalid username".
- **Subtly different responses:** errors look identical but one has a typo (trailing space). Add a **Grep-Extract** rule on the error text; sort to find the outlier.
- **Response timing:** valid username triggers a password check -> slower. Amplify by sending a ~100-char password. Bypass IP block with `X-Forwarded-For`; Pitchfork (IP position + username position). Read "Response received" ms column.
- **Account lock:** repeat each username (Null payloads x5 in a cluster bomb) -> real users hit "too many incorrect login attempts" (longer/different response).

**Password brute-force + protection bypass:**
- **IP block w/ counter reset:** the failed-attempt counter resets on any successful login. Interleave your own valid creds throughout the wordlist (Pitchfork, single-threaded resource pool to preserve order) so the counter never trips while you grind `carlos`.
- **Multiple credentials per request:** JSON login accepts `"password":[...]` array - submit all candidate passwords in one request; a 302 = hit. Defeats per-request rate limits entirely.
- **After lock-based enum:** the password sweep may include the lock; one response with no error message = the correct password (wait for lock to reset, then log in).

**Advanced / edge cases:**
- **HTTP Basic auth:** `Authorization: Basic base64(user:pass)` - static, usually no brute-force protection; brute-force the header directly.
- **Cluster bomb fallback:** if enumeration isn't possible, brute userxpass together (slower).
- **Credential stuffing:** account lock does NOT stop it (each user tried once) - use breach `user:pass` lists.
- **Timing amplification:** longer password = larger timing delta; repeat to confirm signal over jitter.

## Payload arsenal
```
# Intruder positions
username=§user§&password=invalid           # Sniper, enum by Length/Grep/Status/Time
username=valid&password=§pass§              # Sniper, find the 302
X-Forwarded-For: §1-100§                    # spoof IP (Numbers 1-100, step 1)
# counter-reset interleave (Pitchfork pos1 user / pos2 pass), single thread:
pos1: wiener, carlos, carlos, carlos, ...   pos2: peter, p1, p2, p3, ...
# JSON multi-cred (Repeater)
{"username":"carlos","password":["123456","password","qwerty","letmein",...]}
```

## Bypasses
| Defense | Bypass |
|---|---|
| IP block after N fails | `X-Forwarded-For` spoof; or reset counter via own successful login interleaved |
| account lock after N fails | spread few passwords across many users (don't exceed limit/user); credential stuffing |
| per-request rate limit | JSON password array -> many guesses/request |
| "logout after N wrong" | Burp session-handling macro to re-login before each request |
| uniform errors | fall back to timing or status-code or account-lock tells |

## Exploitation walkthrough (enum -> brute -> ATO)
1. Sniper `username` list, password=anything. Sort by Length -> outlier returns "Incorrect password" ⇒ valid username.
2. Clear positions; set that username, Sniper `password` list. One request returns **302** ⇒ valid password.
3. Log in with the pair -> `/my-account` loads ⇒ solved. *(For `carlos` targets, the 302/Show-response-in-browser confirms the takeover.)*

## Chaining
- ATO -> [Access-control](../../Access-control/) admin functions; [Business-logic-vulnerabilities](../../Business-logic-vulnerabilities/).
- Enumerated usernames also feed [Other-mechanisms](../Other-mechanisms/) (reset/change-password attacks).

## Tools
- **Burp Intruder:** Sniper (enum/single-list), Pitchfork (IP+user aligned), Cluster bomb (userxrepeat). Grep-Extract for invisible error diffs; Columns -> Response received/completed for timing; Resource pool max-1 for ordered/timing attacks.
- **Burp Repeater:** JSON array multi-cred; timing experiments.
- **Burp Intruder/Turbo Intruder:** high-speed brute-force.
- **External:** hydra/ffuf for login brute-force; SecLists username/password wordlists.

## Labs

### Username enumeration via different responses [Apprentice]
URL: /web-security/authentication/password-based/lab-username-enumeration-via-different-responses
- Sniper `username` (static bad pass) -> sort by Length -> outlier says "Incorrect password" = valid user. Then Sniper `password` -> the 302 = valid pass. Log in.
- Insight: distinct error strings leak username validity. Real-target transfer: any login where "invalid username" ≠ "incorrect password" wording.

### Username enumeration via subtly different responses [Practitioner]
URL: .../lab-username-enumeration-via-subtly-different-responses
- Errors look identical; add **Grep-Extract** on the message. One response has a trailing space (typo) -> valid user. Then brute password -> 302.
- Insight: a one-character difference (invisible when rendered) still enumerates. Real-target transfer: diff error bodies byte-for-byte, not visually.

### Username enumeration via response timing [Practitioner]
URL: .../lab-username-enumeration-via-response-timing
- IP-blocked on too many tries -> add `X-Forwarded-For` to spoof. Valid username + ~100-char password = slower response. Pitchfork: pos1 `X-Forwarded-For` (1-100), pos2 username; read Response-received column -> slow one = valid user. Then brute password (XFF + password).
- Insight: password check only runs for valid users -> timing side-channel; long password amplifies it. Real-target transfer: time logins with an oversized password; XFF often bypasses IP limits.

### Broken brute-force protection, IP block [Practitioner]
URL: .../lab-broken-bruteforce-protection-ip-block
- IP blocks after 3 fails but the counter resets on a successful login. Pitchfork, single-thread: pos1 alternates your username then `carlos`x100; pos2 your password before each candidate. Filter out 200s, sort by username -> the one `carlos` 302 = his password.
- Insight: interleaving your own valid login resets the failed-attempt counter, neutralizing the IP block. Real-target transfer: any counter that resets on success is bypassable by periodic self-login.

### Username enumeration via account lock [Practitioner]
URL: .../lab-username-enumeration-via-account-lock
- Cluster bomb: pos1 username list, pos2 Null payloads x5 (repeat each user 5x). Real users return "too many incorrect login attempts" (longer). Then Sniper password on that user with Grep-Extract; the response lacking an error = correct password. Wait for lock to reset, log in.
- Insight: the lock message itself enumerates usernames. Real-target transfer: a lockout that only triggers for valid accounts is an oracle.

### Broken brute-force protection, multiple credentials per request [Expert]
URL: .../lab-broken-brute-force-protection-multiple-credentials-per-request
- JSON login. In Repeater set `"password":["123456","password",...]` (array of candidates). Single request -> 302. Show response in browser -> logged in as carlos.
- Insight: the app checks every password in the array but rate-limits per request -> one request brute-forces the account. Real-target transfer: try arrays/duplicated params on JSON auth endpoints.

## Real-world notes
- Username enumeration is a real, reportable finding (often Low/Medium alone) and a force-multiplier for brute-force/credential-stuffing.
- Timing oracles are noisy in the wild - repeat and use statistics; cloud WAFs may mask them.
- Impact: successful brute-force/ATO is High-Critical, especially for admin accounts. Note any missing rate-limit/lockout/CAPTCHA as the root cause.

## References
- https://portswigger.net/web-security/authentication/password-based

# Authentication - Multi-factor authentication (2FA) bypass

2FA is only as strong as its implementation. Three failure modes: the app never enforces the second step, the second step isn't bound to the user who passed the first step, or the short numeric code has no brute-force protection. Max impact: full ATO despite 2FA, sometimes without ever knowing the victim's password.

## Quick reference

```
# 1. Skip the step entirely
complete step 1 (password) -> manually browse to /my-account (or any post-login page)
# 2. Verification not bound to user (broken logic)
GET /login2 with verify=carlos        # generates carlos's code
login as YOU -> at code step, set account/verify cookie+param = carlos -> brute-force mfa-code
# 3. Brute-force the code despite auto-logout
Burp Session macro (GET /login, POST /login, GET /login2) re-logs-in each request
Intruder mfa-code = 0000-9999 (4-digit, leading zeros), resource pool max 1 -> 302
```
Decision list: first try skipping straight to a logged-in page. If the code step uses a cookie/param to name the account, swap it to the victim. If you can submit codes but get logged out after a couple wrong tries, automate re-login with a session macro and brute-force.

## Root cause
After step 1 the user is effectively "logged in" - the app either (a) doesn't verify step 2 was completed before serving protected pages, (b) trusts a client-controlled value (cookie/param) to decide whose code to check, or (c) lets the 4-6 digit code be guessed unlimited times.

## Find it (recon and detection)
- Note the flow: `POST /login` (password) -> `GET/POST /login2` (code). Is there a cookie like `account=carlos` or a `verify`/`account` param naming the user?
- After step 1, try requesting `/my-account` directly - does it load without the code?
- Enter a wrong code a few times - are you logged out (suggests brute-force needs a relogin macro) or just rejected (straight brute-force)?
- Is the code 4 digits (0000-9999, trivially brute-forceable)?

## Technique
**1. Simple bypass (no enforcement):** log in with victim creds to reach the code page, then manually navigate to a known logged-in URL (e.g. `/my-account`). If it loads, step 2 was never enforced. (You first note the post-login URL from your own account.)

**2. Broken logic (verification not bound):** the code step uses a client-supplied value to pick the account. Pre-generate the victim's code by hitting `GET /login2` with `verify=carlos` (or setting `account=carlos`). Then log in as yourself, reach the code step, and on the `POST /login2` set the `verify`/`account` to `carlos` and brute-force `mfa-code`. A 302 logs you into the victim - you never needed their password's second factor.

**3. Brute-force with auto-logout (session macro):** the app logs you out after 2 wrong codes. Configure a Burp **Session Handling Rule** (scope: all URLs) running a **macro** of the 3 login requests (`GET /login`, `POST /login`, `GET /login2`) so Burp silently re-authenticates before each Intruder request. Then Intruder `mfa-code` = Numbers 0-9999, min/max 4 integer digits, 0 fraction (leading zeros), resource pool max-concurrent = 1. A 302 = correct code.

**Advanced / edge cases:**
- **Email-based 2FA isn't true 2FA** - it re-verifies "something you know" (email login); if you control/guess the email it collapses to 1FA.
- **Turbo Intruder** for faster code brute-force where allowed.
- **Code reuse / no expiry / no rotation** - a captured code may stay valid; replay it.
- **Race the code generation** to keep a freshly minted victim code valid during the brute-force window.

## Payload arsenal
```
# pre-generate victim code (Repeater)
GET /login2  with  verify=carlos      (or Cookie: account=carlos)
# brute-force code (Intruder)
mfa-code = 0000..9999   (Numbers, min/max integer digits 4, leading zeros)
# session macro requests (record in order)
GET /login  ->  POST /login (your creds)  ->  GET /login2
```

## Bypasses
| Defense | Bypass |
|---|---|
| step 2 page exists | browse straight to post-login URL (skip) |
| code tied to client cookie/param | set it to victim, brute-force their code |
| logout after N wrong codes | Burp session macro re-login before each guess |
| 4-digit code | exhaust 0000-9999 in Intruder |
| email OTP | it's 1FA in disguise - attack the email login |

## Exploitation walkthrough (broken logic ATO)
1. `GET /login2` in Repeater with `verify=carlos` -> server generates Carlos's code.
2. Log in with **your** username+password, reach the code prompt, submit a wrong code.
3. Send `POST /login2` to Intruder; set `verify=carlos`, payload position on `mfa-code` (0000-9999).
4. The 302 response -> load it in browser -> you're in Carlos's account ⇒ solved. You never knew his password's second factor.

## Chaining
- Combine with [Password-based-login](../Password-based-login/) (steal/guess the first factor) for full ATO.
- ATO -> [Access-control](../../Access-control/) admin functions.
- 2FA-skip pairs with [Access-control](../../Access-control/) (unprotected post-auth endpoints).

## Tools
- **Burp Repeater:** pre-generate victim code; flow analysis.
- **Burp Intruder:** Numbers 0000-9999, resource pool max-1.
- **Burp Session Handling Rules + Macro:** auto re-login to defeat logout-on-fail.
- **Turbo Intruder:** fast code brute-force.

## Labs

### 2FA simple bypass [Apprentice]
URL: /web-security/authentication/multi-factor/lab-2fa-simple-bypass
- Log in to your own account, note the post-login URL (`/my-account`). Log out, log in as victim; at the code prompt, manually navigate to `/my-account` - it loads ⇒ solved.
- Insight: the protected page never checks that step 2 completed. Real-target transfer: after step 1, request known logged-in URLs directly.

### 2FA broken logic [Practitioner]
URL: .../lab-2fa-broken-logic
- `POST/GET /login2` uses a `verify` param to pick the account. In Repeater `GET /login2` with `verify=carlos` (generates his code). Log in as yourself, submit a bad code, send `POST /login2` to Intruder with `verify=carlos` and brute-force `mfa-code`. 302 -> load in browser -> Carlos's account.
- Insight: the second step trusts a client value to name the user -> swap it + brute-force. Real-target transfer: any 2FA where a cookie/param identifies the account at the code step.

### 2FA bypass using a brute-force attack [Expert]
URL: .../lab-2fa-bypass-using-a-brute-force-attack
- Logged out after 2 wrong codes. Add a Burp Session Handling Rule (all URLs) running a macro of `GET /login`, `POST /login` (carlos creds given), `GET /login2` to re-login automatically. Intruder `mfa-code` 0000-9999, resource pool max-1. The 302 -> Show response in browser -> My account.
- Insight: a session macro neutralizes logout-on-fail, making the 4-digit code brute-forceable. Real-target transfer: when an app logs you out to "protect" a code, automate relogin and brute-force anyway.

## Real-world notes
- 2FA-skip and broken-binding bugs are common and high-impact (full ATO bypassing the marketed protection).
- SMS 2FA adds SIM-swap / interception risk; email 2FA is effectively single-factor.
- Impact: Critical when it yields ATO without the second factor. Always note missing rate-limit on the code as the enabler.

## References
- https://portswigger.net/web-security/authentication/multi-factor

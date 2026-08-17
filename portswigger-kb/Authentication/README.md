# Authentication vulnerabilities — topic overview & router

Authentication = proving you are who you claim. Break it and you get account takeover — often of admin. Three attack surfaces: the login itself (brute-force + username enumeration), the second factor (2FA bypass/brute-force), and the supporting flows (password reset, change, "remember me"). Max impact: full ATO, frequently pre-auth and chainable to total compromise.

## 30-second quick reference

```
# username enumeration tells (compare across guesses):
- different error text ("Invalid username" vs "Incorrect password")
- subtle diff: a trailing space / period in an otherwise identical message
- status code change (200 vs 302)
- response time longer for valid user (send a ~100-char password to amplify)
- "account locked" message only appears for real users

# brute-force protection bypasses:
X-Forwarded-For: <rotating IP>          # spoof source IP to dodge IP block
log into own account every N tries      # resets failed-attempt counter
"password":["p1","p2","p3"]             # JSON array = many guesses, one request
creds-per-request / macro relogin       # beat "logout after N fails"

# 2FA bypass:
skip to /my-account after step 1        # state not enforced
change account/verify cookie to victim  # then brute-force 4-digit code
Burp session macro + Intruder 0000-9999 # brute-force code despite logout

# account flows:
reset?user=victim / delete reset token  # broken reset logic
X-Forwarded-Host: evil                   # reset-link poisoning -> steal token
change-password username=victim          # enumerate/brute via error messages
decode stay-logged-in cookie             # base64(user:md5(pass)) -> crack/forge
```

## Decision map — pick the sub-technique

| Observation | Go to | Why |
|---|---|---|
| Login form; want valid usernames / to brute-force | [Password-based-login](Password-based-login/) | enumeration tells + brute-force-protection bypasses |
| Site enforces a 2FA/OTP step | [Multi-factor-auth](Multi-factor-auth/) | skip step, swap victim, brute-force the code |
| Password reset / change / "remember me" / stay-logged-in cookie | [Other-mechanisms](Other-mechanisms/) | broken reset logic, host poisoning, cookie forging, offline cracking |

## Sub-technique folders
- `Password-based-login/` — username enumeration (responses, subtle diffs, timing, account-lock) + brute-force protection bypasses (IP block reset, multiple creds per request) (6 labs)
- `Multi-factor-auth/` — 2FA simple bypass, broken logic (victim swap), code brute-force via session macro (3 labs)
- `Other-mechanisms/` — password reset (broken logic, host poisoning), change-password brute force, stay-logged-in cookie brute-force, offline cracking via stolen cookie (5 labs)

## Guided study order (learning path)
Follow the [Authentication learning path](../_LEARNING-PATHS.md): intro → password-based login (19u) → multi-factor (8u) → other mechanisms (15u) → prevention (8u). 14 labs total (3 Apprentice / 9 Practitioner / 2 Expert).

**Learning path walked 0→end: all 55 units → "You've completed Authentication vulnerabilities".** Full module-by-module record in [`_path-modules.md`](_path-modules.md); every module mapped to the subfolders below.

## Root cause
The site treats a guessable/forgeable secret (password, 4-digit code, predictable token/cookie) as sufficient proof of identity, and fails to (a) make guessing expensive, (b) keep error responses uniform, or (c) bind each auth step to the same verified user.

## Chaining
- ATO → [Access-control](../Access-control/) (now hit admin functions), [Business-logic-vulnerabilities](../Business-logic-vulnerabilities/).
- [XSS](../XSS/) steals a "remember me" cookie → offline crack (see Other-mechanisms/offline cracking).
- Password-reset poisoning rides [HTTP-Host-header-attacks](../HTTP-Host-header-attacks/) (X-Forwarded-Host / Host).
- Dumped creds from [SQL-injection](../SQL-injection/) feed credential stuffing here.
- [OAuth-authentication](../OAuth-authentication/) and [JWT-attacks](../JWT-attacks/) are adjacent auth-bypass classes.

## References
- https://portswigger.net/web-security/authentication
- https://portswigger.net/web-security/authentication/password-based
- https://portswigger.net/web-security/authentication/multi-factor
- https://portswigger.net/web-security/authentication/other-mechanisms

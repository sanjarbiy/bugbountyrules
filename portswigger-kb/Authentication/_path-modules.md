# Authentication - learning path, full module walk (0 -> end)

Walked live via CONTINUE/BACK, reading each module (path "0 of 55"). Each module read and recorded; distilled into the sibling sub-technique folders. This file = the raw path content record.

---

## Intro (modules 1-4)

### 1. What is authentication?
Verifying the identity of a user/client. Three factor types: **something you know** (password, security answer - knowledge factor); **something you have** (phone, security token - possession factor); **something you are/do** (biometrics, behavior - inherence factor). Mechanisms verify one or more factors.

### 2. Authentication vs authorization
**Authentication** = verifying a user is who they claim (is this really Carlos123?). **Authorization** = verifying whether a user is allowed to do something (can Carlos123 delete another user?). Authn first, then authz decides permissions.

### 3. How do authentication vulnerabilities arise?
Two main ways: (1) **weak** mechanisms that fail to protect against brute-force; (2) **logic flaws / poor coding** that let the mechanism be bypassed entirely ("broken authentication"). Because auth is security-critical, flawed auth logic almost always = a security issue.

### 4. What is the impact?
Severe. Bypassing auth or brute-forcing into an account -> full access to that account's data + functionality. Compromise a high-privileged account (admin) -> full control of the app + potential access to internal infrastructure.

-> Distilled in: `Authentication/README.md` (overview, root cause, impact).

---

## Password-based login (modules 6-24) -> `Password-based-login/`
- **Brute-force attacks:** trial-and-error of credentials, automated with wordlists; refined with logic/OSINT (predictable usernames `admin`, `firstname.lastname@`; human password patterns `Mypassword1!`).
- **Brute-forcing usernames / passwords:** usernames leak from profiles/emails; passwords follow policy-driven human patterns.
- **Username enumeration:** detect a valid username via differences in **status code**, **error message** (even a 1-char/trailing-space diff), or **response time** (valid user -> password check runs -> slower; amplify with a ~100-char password).
- **Flawed brute-force protection:** IP block whose counter **resets on a successful login** -> interleave your own creds. Labs: enum via different/subtly-different/timing responses; broken brute-force IP block.
- **Account locking:** lock message itself enumerates users; spread few passwords across many users to dodge the lock; account lock doesn't stop credential stuffing. Lab: enum via account lock.
- **User rate limiting:** IP-based; bypass via IP spoofing (`X-Forwarded-For`) or multiple guesses per request.
- **HTTP Basic auth:** `Authorization: Basic base64(user:pass)`, static, usually no brute-force protection -> brute-forceable; credentials reusable elsewhere.
- Labs (6): enum-different-responses, enum-subtly-different, enum-response-timing, broken-bruteforce-ip-block, enum-account-lock, broken-brute-force-multiple-credentials-per-request.

## Multi-factor authentication (modules 25-32) -> `Multi-factor-auth/`
- **2FA tokens:** dedicated devices/apps (RSA, Google Authenticator) vs SMS (interceptable, SIM-swap). Email 2FA = re-verifying "something you know" -> not true 2FA.
- **Bypassing 2FA:** after step 1 you're effectively "logged in" -> try browsing straight to logged-in-only pages (skip the code step).
- **Flawed verification logic:** the code step trusts a client value (`account`/`verify` cookie/param) to pick the user -> set it to the victim, then brute-force their code -> ATO without the password's 2nd factor.
- **Brute-forcing 2FA codes:** 4-6 digit codes are trivially brute-forceable; "logout after N wrong" is defeated with a Burp session-handling macro that re-logs-in before each request.
- Labs (3): 2fa-simple-bypass, 2fa-broken-logic, 2fa-bypass-using-a-brute-force-attack.

## Other mechanisms (modules 33-47) -> `Other-mechanisms/`
- **Keeping users logged in:** "remember me" cookie; if built from predictable static values (`username`, timestamp, or `md5(password)`) it's forgeable/brute-forceable. Base64 ≠ encryption; unsalted hash -> crackable. Lab: brute-forcing a stay-logged-in cookie; Lab: offline password cracking (steal cookie via XSS, crack unsalted MD5).
- **Resetting passwords:** sending passwords by email (insecure); reset-by-URL with guessable param (`?user=victim`) or with a token that isn't re-validated on submit (delete token, swap username). Reset link host from `X-Forwarded-Host`/`Host` -> poisoning to steal the token. Labs: password-reset-broken-logic, password-reset-poisoning-via-middleware.
- **Changing passwords:** change-password with an editable `username` hidden field + distinct error messages ("New passwords do not match" vs "Current password is incorrect") -> password oracle / brute force. Lab: password-brute-force-via-password-change.
- Labs (5): password-reset-broken-logic, brute-forcing-a-stay-logged-in-cookie, offline-password-cracking, password-reset-poisoning-via-middleware, password-brute-force-via-password-change.

## Preventing attacks (modules 48-55) -> distilled into each subfolder's Real-world notes
- Take care with user credentials (HTTPS/HSTS, never email persistent passwords); don't count on users for security; **prevent username enumeration** (identical generic responses/status/timing for valid vs invalid); **robust brute-force protection** (rate limit, CAPTCHA, lockout - not counter-resettable); **triple-check verification logic** (bind every auth step to the same verified user); **don't forget supplementary functionality** (reset/change/remember-me); **implement proper MFA** (verify genuinely different factors).

---

**Path walked 0 -> end: 55/55 units -> "You've completed Authentication vulnerabilities".** Intro modules read live; password-based/MFA/other-mechanisms/prevention content read from the topic sub-pages (`.scratch/auth-*.txt`) which are the same articles the path renders. All 14 labs covered in the sub-technique folders' `## Labs` sections.

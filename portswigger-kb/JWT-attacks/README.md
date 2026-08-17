# JWT attacks — topic overview & router

JWTs (JSON Web Tokens) are signed tokens (header.payload.signature, base64url-encoded). Servers use them for session management — the signature is supposed to guarantee integrity. If the server fails to verify the signature, accepts alg=none, uses a weak/guessable HMAC secret, or trusts attacker-supplied key material (jwk/jku headers, kid path traversal), the payload can be forged to impersonate any user.

## 30-second quick reference

```
# 1. No verification — just edit sub claim (no re-signing needed)
# Burp Inspector: change sub="wiener" → sub="administrator"

# 2. alg=none — strip signature, keep trailing dot
eyJhbGciOiJub25lIn0.<base64-payload>.

# 3. Weak HMAC secret — brute-force
hashcat -a 0 -m 16500 <JWT> /usr/share/wordlists/jwt.secrets.list

# 4. jwk injection — embed attacker's public key in header
# Burp JWT Editor → Attack → Embedded JWK

# 5. jku injection — point to attacker-hosted JWK Set
{"alg":"RS256","kid":"attacker-kid","jku":"https://EXPLOIT-SERVER/exploit"}

# 6. kid path traversal — point to /dev/null (null byte key)
{"alg":"HS256","kid":"../../../../../../../dev/null"}   k="" in symmetric key

# 7. alg confusion (RS256→HS256) — server's public key as HMAC secret
{"alg":"HS256"}   k = base64(PEM-of-server-RSA-public-key)

# Recover public key from two tokens (no /jwks.json)
docker run --rm portswigger/sig2n <token1> <token2>
```

## Decision map

| Observation | Sub-technique | Attack |
|---|---|---|
| JWT cookie; admin panel blocked | [Signature-bypass](Signature-bypass/) | edit sub, no re-sign |
| alg field changeable | [Signature-bypass](Signature-bypass/) | alg=none, empty sig |
| HMAC-signed (HS256) | [Signature-bypass](Signature-bypass/) | hashcat brute-force |
| RSA-signed; no key validation | [Key-injection-and-confusion](Key-injection-and-confusion/) | jwk/jku injection |
| RS256 server, no /jwks.json | [Key-injection-and-confusion](Key-injection-and-confusion/) | sig2n → alg confusion |
| kid header in token | [Kid-header-attacks](Kid-header-attacks/) | path traversal → /dev/null |

## Sub-technique folders
- `Signature-bypass/` — no verification, alg=none, weak HMAC secret (Labs 1,2,3)
- `Key-injection-and-confusion/` — jwk/jku injection, algorithm confusion (Labs 4,5,7,8)
- `Kid-header-attacks/` — kid path traversal to null-byte key (Lab 6)

## Root cause
- Servers that use JWT libraries in "don't verify" mode or with insecure defaults.
- Legacy libraries that accept alg=none.
- Weak default secrets (secret, secret1) combined with no rotation.
- jwk/jku headers processed without allowlisting — server fetches/trusts attacker-supplied key.
- kid used in file path lookup without sanitization → path traversal to empty/known file.
- Symmetric/asymmetric confusion: public key used as HMAC secret by confused library.

## Find it
1. Check session cookie — is it a JWT (3 dot-separated base64url segments)?
2. Decode payload (Burp Inspector or jwt.io) — note sub, role, iat, exp claims.
3. Modify payload without changing signature → send → does server accept it?
4. Change alg to "none" and strip signature → does server accept?
5. Check header for kid, jku, x5u, x5c parameters.
6. For HS256: run hashcat against common wordlists.
7. For RS256: check /jwks.json endpoint for exposed public keys.

## Chaining
- JWT forgery → admin account → [Access-control](../Access-control/) (delete carlos, reach /admin)
- JWT sub=administrator → [Authentication](../Authentication/) bypass at authentication layer
- jku SSRF → if OAuth/OIDC server fetches jku → [SSRF](../SSRF/)

## Tools
- **Burp JWT Editor** (BApp store) — key gen, sign, embedded JWK, alg confusion attacks
- **hashcat -m 16500** — HMAC-SHA256 JWT secret brute-force
- **docker portswigger/sig2n** — recover RSA public key from two signed tokens
- **jwt.io** — decode/inspect tokens in browser

## References
- https://portswigger.net/web-security/jwt
- https://portswigger.net/web-security/jwt/algorithm-confusion

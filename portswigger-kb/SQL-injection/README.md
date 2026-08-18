# SQL injection - topic overview & router

Attacker-controlled input reaches a SQL query unparameterized. Impact ladder: read hidden rows -> bypass auth -> dump the whole DB (creds/PII) -> in some stacks RCE / lateral movement via the DB host. This is the floor-to-ceiling injection class; master the decision flow, not just one payload.

## 30-second quick reference

```
'                      -> probe: error / changed response / nothing? pick a path below
'--   '#   '-- -       -> comment out tail (MySQL needs `-- ` or `#`)
' OR 1=1--             -> widen WHERE (DANGER near UPDATE/DELETE)
admin'--               -> auth bypass (username field)
' ORDER BY 10--        -> column count ladder (error when too high)
' UNION SELECT NULL,NULL--   -> column count via nulls (200 when arity matches)
' UNION SELECT @@version--   -> fingerprint+exfil once cols known
```

Fingerprint by what works: `@@version`=MySQL/MSSQL - `version()`=Postgres - `SELECT banner FROM v$version`=Oracle.

## Decision map - pick the sub-technique

| Observation | Go to | Why |
|---|---|---|
| Input changes which rows/products show; results rendered | [UNION-based](UNION-based/) | Pull arbitrary tables into the visible response |
| Login form, value concatenated into auth query | [Basics-and-detection](Basics-and-detection/) | `'--` comment-out bypass |
| Need table/column names, DB type | [Examining-the-database](Examining-the-database/) | `information_schema` / Oracle `all_tables` |
| Response differs on true/false but query results NOT shown (e.g. "Welcome back") | [Blind-boolean](Blind-boolean/) | Infer data 1 bit/request via boolean or conditional error |
| Verbose DB error text leaks into the page | [Error-based](Error-based/) | `CAST(...)` to spill data in the error string |
| No content diff, no error diff, but you can stall the query | [Blind-time-based](Blind-time-based/) | `sleep`/`pg_sleep`/`WAITFOR` conditional delay |
| No content/error/time diff at all; query may be async | [Out-of-band-OAST](Out-of-band-OAST/) | DNS/HTTP exfil via Collaborator |
| Payload blocked by WAF / different input format (XML/JSON) | [WAF-filter-bypass](WAF-filter-bypass/) | Encode keywords (XML entities, etc.) |

Escalation ladder when blind: boolean -> conditional error -> time delay -> OAST. Try in that order; OAST is most powerful and works when the rest fail.

## Learning-path module coverage (0 -> end)
Every module of the [SQL injection learning path](https://portswigger.net/web-security/learning-paths/sql-injection) (51 units), in order, mapped to where it's distilled here. Verified the path renders the same article text as the topic pages.

| # | Path module | Covered in |
|---|---|---|
| 1 | What is SQL injection? | README (summary) + Basics-and-detection |
| 2 | How to detect SQL injection vulnerabilities | Basics-and-detection -> Find it |
| 3 | Retrieving hidden data | Basics-and-detection (lab) |
| 4 | Subverting application logic | Basics-and-detection (login-bypass lab) |
| 5 | SQL injection UNION attacks | UNION-based |
| 6 | Determining the number of columns required | UNION-based (lab) |
| 7 | Finding columns with a useful data type | UNION-based (lab) |
| 8 | Using a UNION attack to retrieve interesting data | UNION-based (lab) |
| 9 | Retrieving multiple values within a single column | UNION-based (lab) |
| 10 | Examining the database | Examining-the-database (4 labs) |
| 11 | Blind SQL injection | Blind-boolean |
| 12 | Exploiting blind via conditional responses | Blind-boolean (lab) |
| 13 | Error-based SQL injection | Error-based + Blind-boolean (conditional-errors lab) |
| 14 | Exploiting blind via time delays | Blind-time-based (2 labs) |
| 15 | Exploiting blind using OAST | Out-of-band-OAST (2 labs) |
| 16 | SQL injection in different contexts | WAF-filter-bypass (lab) |
| 17 | Second-order SQL injection | Basics-and-detection -> Technique -> Second-order (below) |
| 18 | How to prevent SQL injection | Prevention (below) |

All 18 labs in the path are covered across the subfolders' `## Labs` sections.

### Second-order SQL injection (path module 17)
Input is stored safely on one request, then later read and concatenated unsafely into a query elsewhere. Detection: plant `'`/`'--`/payloads in fields that get *stored and re-displayed/re-queried* (usernames, profile fields, registration), then trigger the second flow (view profile, admin report, order processing). The injection fires on the read, not the write - so a clean store ≠ safe. Treat any stored, attacker-controlled value that later feeds a query as injectable.

### Prevention (path module 18)
Parameterized queries / prepared statements for ALL user-influenced query parts (not just `WHERE` - also `INSERT`/`UPDATE` values). Note: table/column names and `ORDER BY` can't be parameterized -> use a strict allowlist. Least-privilege DB user; disable verbose errors in prod; defense-in-depth WAF (but never the sole control - see WAF-filter-bypass).

## Guided study order (learning path)
Follow the [SQL injection learning path](../_LEARNING-PATHS.md#single-topic-path--sql-injection-fully-mapped--reference-example) order: Basics-and-detection -> UNION-based -> Examining-the-database -> Blind-boolean -> Error-based -> Blind-time-based -> Out-of-band-OAST -> WAF-filter-bypass. Mid-hunt, ignore order and jump via the decision map above.

## Sub-technique folders
- `Basics-and-detection/` - detection methodology, retrieving hidden data, login bypass (2 labs)
- `UNION-based/` - column count, string-column discovery, cross-table dump, single-column concat (4 labs)
- `Examining-the-database/` - version fingerprint + schema enumeration, incl. Oracle (4 labs)
- `Blind-boolean/` - conditional responses & conditional errors (2 labs)
- `Error-based/` - visible/verbose error data extraction via CAST (1 lab)
- `Blind-time-based/` - time-delay inference + char extraction (2 labs)
- `Out-of-band-OAST/` - DNS/HTTP exfil via Collaborator (2 labs)
- `WAF-filter-bypass/` - XML-entity encoding to defeat keyword filters (1 lab)

## Where SQLi lives in the query (not just WHERE)
`WHERE` (SELECT) - `UPDATE` set values / WHERE - `INSERT` values - table/column name in `SELECT` - `ORDER BY` clause - `LIMIT`/`OFFSET`. Also: second-order - input stored safely, then later re-used in a query unsafely.

## Chaining
- SQLi -> **auth bypass / account takeover** (dump creds -> log in). See [Authentication](../Authentication/), [Access-control](../Access-control/).
- Stacked queries / `xp_cmdshell` / `COPY ... TO PROGRAM` -> **RCE**. See [OS-command-injection](../OS-command-injection/).
- OAST exfil overlaps with [SSRF](../SSRF/) and [XXE](../XXE-injection/) primitives.
- WAF-bypass-via-XML overlaps with [XXE-injection](../XXE-injection/) entity tricks.

## References
- https://portswigger.net/web-security/sql-injection
- https://portswigger.net/web-security/sql-injection/union-attacks
- https://portswigger.net/web-security/sql-injection/blind
- https://portswigger.net/web-security/sql-injection/examining-the-database
- https://portswigger.net/web-security/sql-injection/cheat-sheet

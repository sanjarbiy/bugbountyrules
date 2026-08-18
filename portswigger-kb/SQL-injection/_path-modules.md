# SQL injection - learning path, full module walk (0 -> end)

Read live module-by-module via the path's CONTINUE/BACK navigation (PRACTITIONER path, "SQL injection 1 of 51"). Each module's article text captured verbatim from the rendered page, then distilled into the sibling sub-technique folders. This file = the raw path content record.

---

## 1. What is SQL injection (SQLi)?  (chapter: sql-injection-what-is-sql-injection)
SQL injection (SQLi) is a web security vulnerability that allows an attacker to interfere with the queries that an application makes to its database. This can allow an attacker to view data that they are not normally able to retrieve - data that belongs to other users, or any other data the application can access. In many cases an attacker can modify or delete this data, causing persistent changes to the application's content or behavior.

In some situations an attacker can escalate a SQL injection attack to compromise the underlying server or other back-end infrastructure, or perform a denial-of-service attack.

-> Distilled in: `Basics-and-detection/` (summary + impact ladder), topic `README.md`.

---

## 2. How to detect SQL injection vulnerabilities  (1 of 2)
Detect manually with a systematic set of tests against EVERY entry point: (1) submit `'` and look for errors/anomalies; (2) submit SQL syntax that evaluates to the base value vs a different value, looking for systematic response differences; (3) boolean `OR 1=1` / `OR 1=2` and look for response differences; (4) time-delay payloads and look for timing differences; (5) OAST payloads triggering out-of-band interactions and monitor them. Burp Scanner finds most quickly.
-> Distilled in: `Basics-and-detection/` -> Find it (5 detection methods).

## 3. SQL injection in different parts of the query  (2 of 2)
Most SQLi is in the `WHERE` clause of a `SELECT`, but it can occur anywhere: `UPDATE` (values or WHERE), `INSERT` (inserted values), `SELECT` table/column name, and `ORDER BY`. The injection context dictates the syntax you need.
-> Distilled in: topic `README.md` ("Where SQLi lives in the query"), per-folder Technique sections.

## 4. Retrieving hidden data  (lab)
Shopping app filters by category: `SELECT * FROM products WHERE category='Gifts' AND released=1`. Inject `Gifts'--` to drop `AND released=1` (show unreleased), or `Gifts'+OR+1=1--` to return everything. ⚠ `OR 1=1` may reach an UPDATE/DELETE elsewhere -> accidental data loss.
-> Distilled in: `Basics-and-detection/` (lab: retrieve-hidden-data).

## 5. Subverting application logic  (lab)
Login query `SELECT * FROM users WHERE username='wiener' AND password='...'`. Submit username `administrator'--` to comment out the password check -> log in as administrator with no password.
-> Distilled in: `Basics-and-detection/` (lab: login-bypass).

## 6. SQL injection UNION attacks
`UNION` appends extra `SELECT` results to the response. Two requirements: equal column count, and compatible types per column. Workflow: find column count, find a string-compatible column, then pull data.
-> Distilled in: `UNION-based/`.

## 7. Determining the number of columns required  (lab)
Method A: `' ORDER BY 1--`, `2--`, ... until error (out-of-range index = count+1). Method B: `' UNION SELECT NULL--`, add NULLs until no error (NULL is type-agnostic). Oracle needs `FROM dual`.
-> Distilled in: `UNION-based/` (lab: determine-columns).

## 8. Finding columns with a useful data type  (lab)
Place a string literal in each column slot: `' UNION SELECT 'a',NULL,NULL--`, etc. A type-incompatible column errors ("Conversion failed ... to int"); the slot that renders `a` holds string data - your exfil channel.
-> Distilled in: `UNION-based/` (lab: find-text-column).

## 9. Using a UNION attack to retrieve interesting data  (lab)
With count + string column + known table/columns: `' UNION SELECT username, password FROM users--` pulls creds into the visible response.
-> Distilled in: `UNION-based/` (lab: retrieve-data-from-other-tables).

## 10. Retrieving multiple values within a single column  (lab)
When only one column is usable, concatenate: Oracle/Postgres `' UNION SELECT username||'~'||password FROM users--`; MySQL `CONCAT(...)`; MSSQL `+`. Separator (`~`) keeps fields splittable.
-> Distilled in: `UNION-based/` (lab: multiple-values-single-column).

## 11. Examining the database
Fingerprint version (`@@version` MySQL/MSSQL, `version()` Postgres, `v$version` Oracle); list tables/columns via `information_schema.tables`/`.columns` (Oracle: `all_tables`/`all_tab_columns`). 4 labs (version Oracle, version MySQL/MSSQL, list non-Oracle, list Oracle).
-> Distilled in: `Examining-the-database/`.

## 12. Blind SQL injection
Query runs but results/errors aren't returned. Exploit via: conditional responses (boolean), conditional errors, time delays, or OAST. (Intro module.)
-> Distilled in: `Blind-boolean/`, `Error-based/`, `Blind-time-based/`, `Out-of-band-OAST/`.

## 13. Exploiting blind SQLi by triggering conditional responses  (lab)
A lookup (e.g. `TrackingId` cookie) shows a tell ("Welcome back") only when the query returns rows. `' AND '1'='1` (true) vs `'1'='2` (false) = oracle. Extract with `SUBSTRING(password,i,1)` per position over a-z0-9; find length with `LENGTH(password)>N`.
-> Distilled in: `Blind-boolean/` (lab: conditional-responses).

## 14. Error-based SQL injection  (incl. lab + conditional-errors lab)
When content doesn't change, force a conditional DB error: `CASE WHEN (cond) THEN 1/0 ELSE NULL END` (divide-by-zero on true). When errors are verbose, `CAST((SELECT ...) AS int)` leaks the value inside the type error. Labs: conditional errors, visible error-based.
-> Distilled in: `Error-based/` and `Blind-boolean/` (conditional-errors).

## 15. Exploiting blind SQLi by triggering time delays  (2 labs)
Conditional delay: Postgres `CASE WHEN cond THEN pg_sleep(10) ELSE pg_sleep(0) END`; MySQL `IF(cond,SLEEP(10),0)`; MSSQL `IF (cond) WAITFOR DELAY '0:0:10'`. Response time = the bit. Extract char-by-char single-threaded.
-> Distilled in: `Blind-time-based/` (labs: time-delays, time-delays-info-retrieval).

## 16. Exploiting blind SQLi using out-of-band (OAST) techniques  (2 labs)
Force a DNS/HTTP interaction to Burp Collaborator. Oracle `EXTRACTVALUE(xmltype(... SYSTEM "http://COLLAB/" ...)) FROM dual` triggers a lookup; embed `(SELECT password ...)` in the subdomain to exfiltrate. Works when async/no other signal.
-> Distilled in: `Out-of-band-OAST/` (labs: out-of-band, out-of-band-data-exfiltration).

## 17. SQL injection in different contexts  (lab)
Input may arrive as JSON/XML; encode SQL keywords (e.g. XML hex/dec entities) to bypass WAF keyword filters - the parser decodes them, the WAF doesn't. Lab: filter bypass via XML encoding.
-> Distilled in: `WAF-filter-bypass/` (lab: filter-bypass-via-xml-encoding).

## 18. Second-order SQL injection
Input is stored safely on one request, then later read and concatenated unsafely into a query elsewhere. A clean store ≠ safe; the injection fires on the read. Plant payloads in stored fields (username, profile), trigger the later flow.
-> Distilled in: `Basics-and-detection/` -> Technique -> Second-order; topic `README.md`.

## 19. How to prevent SQL injection
Use parameterized (prepared) queries for ALL user-influenced query parts, not just `WHERE` (also INSERT/UPDATE values). Table/column names and `ORDER BY` can't be parameterized -> strict allowlist. Defense-in-depth: least-privilege DB user, disable verbose errors, WAF (never the sole control).
-> Distilled in: topic `README.md` -> Prevention; per-folder Real-world notes.

---

**Coverage check:** all path modules (What is SQLi -> How to detect -> in-different-parts -> retrieving hidden data -> subverting logic -> UNION x4 -> examining the DB -> blind -> conditional responses -> error-based -> time delays -> OAST -> different contexts -> second-order -> prevention) read 0->end and each mapped to a distilled sub-technique folder above. All 18 labs covered in those folders' `## Labs` sections.

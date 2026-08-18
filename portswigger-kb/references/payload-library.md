# Payload Library - never fire basic payloads (PayloadsAllTheThings)

The vectors in `attack-engine.md` and the probes in `detection-fingerprints.md` are **starters** - enough to *confirm* a class. They are NOT the full set. Firing one hardcoded probe (`'`, `<script>alert(1)>`, `../etc/passwd`) and concluding "not vulnerable" is the #1 amateur mistake. When a starter doesn't fire, when you need coverage, when a filter blocks you, or when the class is unfamiliar - **escalate to the comprehensive set.** It's one grep away.

[PayloadsAllTheThings](https://github.com/swisskyrepo/PayloadsAllTheThings) ships a folder per class: detection probes, edge cases, polyglots, encodings, bypasses, exploitation payloads, plus `Intruder/` wordlists and `Files/` PoCs.

> Authorized lab / CTF / scoped-engagement only.

---

## Access it (in order)
```
LOCAL (if cloned):   <your skills dir>/PayloadsAllTheThings/<Folder>/README.md  -> grep/read it
NOT PRESENT? clone:  git clone --depth 1 https://github.com/swisskyrepo/PayloadsAllTheThings.git
NO DISK? WebFetch:   https://raw.githubusercontent.com/swisskyrepo/PayloadsAllTheThings/master/<Folder>/README.md
WORDLISTS:           <Folder>/Intruder/*.txt   -> feed straight into Burp Intruder / ffuf
```

## When to consult (if->then->try)
```
starter probe didn't fire, sink looks reachable -> grep the class folder -> polyglots, context/encoded variants, THEN decide
need to DETECT thoroughly (not one guess)        -> read the class folder -> use its full detection set
WAF/filter eating basic payloads                 -> class folder bypass section + waf-bypass-arsenal.md
unfamiliar/rare class (LDAP, XPATH, SSI, Type Juggling, LaTeX, SAML, Prompt Injection) -> read the folder first
confirmed injection, need exploitation/escalation -> class folder exploitation + Intruder/*.txt wordlist
```

## Class -> PayloadsAllTheThings folder

| KB class | PATT folder(s) |
|---|---|
| SQL-injection | `SQL Injection/` |
| NoSQL-injection | `NoSQL Injection/` |
| XSS | `XSS Injection/` |
| DOM-based | `XSS Injection/` - `DOM Clobbering/` - `Client Side Path Traversal/` |
| SSTI | `Server Side Template Injection/` |
| SSRF | `Server Side Request Forgery/` |
| XXE-injection | `XXE Injection/` |
| OS-command-injection | `Command Injection/` |
| Path-traversal | `Directory Traversal/` - `File Inclusion/` |
| File-upload-vulnerabilities | `Upload Insecure Files/` - `Zip Slip/` |
| Insecure-deserialization | `Insecure Deserialization/` - `Java RMI/` |
| JWT-attacks | `JSON Web Token/` |
| Prototype-pollution | `Prototype Pollution/` |
| OAuth-authentication | `OAuth Misconfiguration/` - `SAML Injection/` |
| HTTP-Host-header-attacks | `Request Smuggling/` - `Virtual Hosts/` - `Reverse Proxy Misconfigurations/` |
| HTTP-request-smuggling | `Request Smuggling/` |
| Web-cache-poisoning / deception | `Web Cache Deception/` |
| CORS | `CORS Misconfiguration/` |
| Clickjacking | `Clickjacking/` - `Tabnabbing/` |
| CSRF | `Cross-Site Request Forgery/` |
| WebSockets | `Web Sockets/` |
| GraphQL-API-vulnerabilities | `GraphQL Injection/` |
| API-testing | `Mass Assignment/` - `Hidden Parameters/` - `HTTP Parameter Pollution/` - `API Key Leaks/` |
| Access-control | `Insecure Direct Object References/` |
| Business-logic-vulnerabilities | `Business Logic Errors/` |
| Race-conditions | `Race Condition/` |
| Authentication | `Account Takeover/` - `Brute Force Rate Limit/` - `JSON Web Token/` |
| Information-disclosure | `Insecure Source Code Management/` - `API Key Leaks/` - `ORM Leak/` |
| Web-LLM-attacks | `Prompt Injection/` |
| (open redirect) | `Open Redirect/` |
| (CRLF / LDAP / XPATH / SSI) | `CRLF Injection/` - `LDAP Injection/` - `XPATH Injection/` - `Server Side Include Injection/` |
| (type juggling / DoS / dependency confusion) | `Type Juggling/` - `Denial of Service/` - `Regular Expression/` - `Dependency Confusion/` |
| methodology / recon / cloud / privesc | `Methodology and Resources/` |

**Rule of thumb:** about to type a payload from memory? Stop - open the class folder and pull the real set first. One probe proves nothing; the folder proves you actually tested. Then bring the finding back to the topic folder's exploitation walkthrough and chain it (`chaining-playbook.md`).

# Payload Sources — bugbountyrules reference

Loaded on demand from SKILL.md. These are the full versions of rules whose
mandate is stated inline in SKILL.md; read this file when the situation calls for it.

## Contents
- RULE 3.8: PayloadsAllTheThings — payload depth
- RULE 3.9: portswigger-kb — per-class exploitation

---

## RULE 3.8: PAYLOAD DEPTH — CONSULT PAYLOADSALLTHETHINGS (NEVER FIRE BASIC PAYLOADS)

**Firing one hardcoded basic payload (`'`, `<script>alert(1)>`, `../etc/passwd`) and concluding "not vulnerable" is the #1 amateur mistake. Those are v1 probes. The comprehensive, WAF-aware, context-specific payload set is one grep away — USE IT.**

[PayloadsAllTheThings](https://github.com/swisskyrepo/PayloadsAllTheThings) has a folder of battle-tested payloads for nearly every class (detection probes, edge cases, polyglots, encodings, bypasses, exploitation, plus `Intruder/` wordlists and `Files/` PoCs).

### Access it (in order of preference)
```
LOCAL (if cloned):   <your skills dir>/PayloadsAllTheThings/<Folder>/README.md   → grep/read it
                     (find it: `fd -td PayloadsAllTheThings ~ 2>/dev/null | head -1`)
NOT PRESENT? clone:  git clone --depth 1 https://github.com/swisskyrepo/PayloadsAllTheThings.git
NO DISK? WebFetch:   https://raw.githubusercontent.com/swisskyrepo/PayloadsAllTheThings/master/<Folder>/README.md
WORDLISTS:           <Folder>/Intruder/*.txt  → feed straight into Burp Intruder / ffuf
```

### Consult it AUTOMATICALLY (if→then→try)
```
I SEE: my basic detection probe didn't fire, but the sink looks reachable
  → grep the class folder → try the polyglots, context-specific and encoded variants BEFORE concluding "safe".

I SEE: I need to DETECT a class thoroughly (not a single guess)
  → read the class folder → use its full detection set, not one hardcoded string.

I SEE: a WAF/filter is eating basic payloads
  → class folder's bypass section + Encoding Transformations/ + Rule 12 / waf-bypass-arsenal.

I SEE: an unfamiliar/rare class (LDAP, XPATH, SSI, Type Juggling, LaTeX, SAML, Prompt Injection)
  → PATT has a folder → read it BEFORE improvising.

I SEE: confirmed injection — need exploitation/escalation payloads or a wordlist
  → class folder's exploitation section + Intruder/*.txt wordlists.
```

### Class → PayloadsAllTheThings folder

| Class | Folder(s) |
|---|---|
| SQLi | `SQL Injection/` |
| NoSQLi | `NoSQL Injection/` |
| XSS / DOM | `XSS Injection/` · `DOM Clobbering/` · `Client Side Path Traversal/` |
| SSTI | `Server Side Template Injection/` |
| SSRF | `Server Side Request Forgery/` |
| XXE | `XXE Injection/` |
| OS command | `Command Injection/` |
| Path traversal / LFI | `Directory Traversal/` · `File Inclusion/` |
| File upload | `Upload Insecure Files/` · `Zip Slip/` |
| Deserialization | `Insecure Deserialization/` · `Java RMI/` |
| JWT | `JSON Web Token/` |
| Prototype pollution | `Prototype Pollution/` |
| OAuth / SAML | `OAuth Misconfiguration/` · `SAML Injection/` |
| Host header / routing | `Request Smuggling/` · `Virtual Hosts/` · `Reverse Proxy Misconfigurations/` |
| Request smuggling | `Request Smuggling/` |
| Cache poisoning/deception | `Web Cache Deception/` |
| CORS | `CORS Misconfiguration/` |
| Clickjacking | `Clickjacking/` · `Tabnabbing/` |
| CSRF | `Cross-Site Request Forgery/` |
| WebSockets | `Web Sockets/` |
| GraphQL | `GraphQL Injection/` |
| API / mass assignment | `Mass Assignment/` · `Hidden Parameters/` · `HTTP Parameter Pollution/` · `API Key Leaks/` |
| Access control / IDOR | `Insecure Direct Object References/` |
| Business logic | `Business Logic Errors/` |
| Race conditions | `Race Condition/` |
| Auth / ATO / brute | `Account Takeover/` · `Brute Force Rate Limit/` · `JSON Web Token/` |
| Info disclosure | `Insecure Source Code Management/` · `API Key Leaks/` · `ORM Leak/` |
| LLM / prompt injection | `Prompt Injection/` |
| Open redirect | `Open Redirect/` |
| CRLF | `CRLF Injection/` |
| LDAP / XPATH / SSI | `LDAP Injection/` · `XPATH Injection/` · `Server Side Include Injection/` |
| Type juggling | `Type Juggling/` |
| DoS / ReDoS | `Denial of Service/` · `Regular Expression/` |
| Dependency confusion | `Dependency Confusion/` |
| Methodology / recon / cloud / privesc | `Methodology and Resources/` |

**Rule of thumb: if you're about to type a payload from memory, stop — open the class folder first and pull the real set. One probe proves nothing; the folder proves you actually tested.**

---

## RULE 3.9: PORTSWIGGER KB — DEEP PER-CLASS WEB EXPLOITATION (BUNDLED)

**Bundled inside this skill at `portswigger-kb/` is a deep web-exploitation knowledge base — 31 vuln classes, 124 operator playbooks, plus an autonomous brain under `portswigger-kb/references/`. When you confirm a web vuln class or target an objective, CONSULT IT. Do not improvise deep technique from memory when the playbook is one read away.**

**Division of labor (use them together, intelligently):**
- **`bugbountyrules` (this skill)** = the hunter's discipline & engagement methodology (scope, persistence, verification, coverage, reporting). Governs *how you behave*.
- **`portswigger-kb/` (Rule 3.9)** = deep *methodology per class* — how to DETECT, EXPLOIT, BYPASS, and CHAIN each web vuln class, plus goal-first attack trees. The *how to attack this class*.
- **PayloadsAllTheThings (Rule 3.8)** = the raw *payloads* to fire. The *what to send*.
- Flow: bugbountyrules drives the hunt → portswigger-kb tells you HOW to exploit the class → PATT gives the payloads → back to bugbountyrules for verify + report. If any guidance conflicts, **bugbountyrules wins** (Rule 15).

### Access it
```
BUNDLED (this skill):  portswigger-kb/<Topic>/README.md  and  portswigger-kb/references/*.md   → grep/read
FALLBACK (if unbundled): the standalone `portswigger` skill, wherever your skills live
```

### Consult it AUTOMATICALLY (if→then→try)
```
I SEE: I confirmed a web vuln class (SQLi/XSS/SSRF/IDOR/…)
  → read portswigger-kb/<Class>/README.md → the sub-technique folders give the full exploit walkthrough,
    Bypasses table, chaining, and lab-proven payloads. Then pull raw payloads from PATT (Rule 3.8).

I SEE: I have a GOAL, not just a class (ATO, RCE, dump-the-DB, escalate-to-admin, data-exfil)
  → read portswigger-kb/references/objectives-attack-trees.md → it decomposes the goal into EVERY path with
    signal→test→pivot. Walk them all (this is the exact "try every ATO path" behaviour you want).

I SEE: a request/response/cookie/param and I'm unsure which class to test
  → portswigger-kb/references/detection-fingerprints.md → observation → class → confirm-probe (all 31).

I SEE: I have a primitive and want maximum impact
  → portswigger-kb/references/chaining-playbook.md → primitive → crown (RCE/ATO/mass-PII), concrete steps.

I SEE: a filter/WAF blocks a web payload
  → portswigger-kb/<Class>/*/WAF-filter-bypass or CSP-bypass + references/waf-bypass-arsenal.md (Rule 12).
```

### Class → portswigger-kb folder
```
SQLi→SQL-injection/   NoSQLi→NoSQL-injection/   XSS→XSS/   DOM→DOM-based-vulnerabilities/
SSTI→SSTI/   SSRF→SSRF/   XXE→XXE-injection/   OS-cmd→OS-command-injection/   path→Path-traversal/
file-upload→File-upload-vulnerabilities/   deserialization→Insecure-deserialization/   JWT→JWT-attacks/
prototype-pollution→Prototype-pollution/   OAuth→OAuth-authentication/   host-header→HTTP-Host-header-attacks/
smuggling→HTTP-request-smuggling/   cache-poisoning→Web-cache-poisoning/   cache-deception→Web-cache-deception/
CORS→CORS/   clickjacking→Clickjacking/   CSRF→CSRF/   WebSockets→WebSockets/   GraphQL→GraphQL-API-vulnerabilities/
API/mass-assign→API-testing/   IDOR/access-control→Access-control/   business-logic→Business-logic-vulnerabilities/
race→Race-conditions/   auth→Authentication/   info-disclosure→Information-disclosure/   web-LLM→Web-LLM-attacks/
methodology/objective-trees/detection/chaining→references/
```

**Rule of thumb: confirmed a web class or picked an objective? Open `portswigger-kb/` FIRST — it is your deep-technique brain. bugbountyrules is the hunter; portswigger-kb is the weapon's manual; PATT is the ammunition.**

---

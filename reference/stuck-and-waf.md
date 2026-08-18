# Stuck And Waf - bugbountyrules reference

Loaded on demand from SKILL.md. These are the full versions of rules whose
mandate is stated inline in SKILL.md; read this file when the situation calls for it.

## Contents
- RULE 11.5: The stuck protocol
- RULE 12: WAF handling

---

## RULE 11.5: WHEN STUCK - FINGERPRINT -> RESEARCH -> ADAPT (MANDATORY)

**When progress stalls: NEVER guess. NEVER test blindly. Follow this exact protocol.**

### Step 1: FINGERPRINT THE TARGET

Extract every piece of identifying information from what you already have:

```
FROM RESPONSE HEADERS:
  -> Server (nginx/1.21.6, Apache/2.4.54, Microsoft-IIS/10.0)
  -> X-Powered-By (PHP/8.1, Express, ASP.NET)
  -> X-AspNet-Version, X-Generator, X-Drupal-Cache
  -> Set-Cookie (session naming reveals framework: PHPSESSID, JSESSIONID, connect.sid, csrftoken)
  -> CDN/WAF headers (CF-RAY, X-Sucuri-ID, X-Cache, X-Akamai-*)

FROM RESPONSE BODIES:
  -> HTML comments (<!-- Built with X -->, version numbers, developer names)
  -> Meta tags (generator, framework, CMS)
  -> Error messages (stack traces reveal language, framework, ORM, database)
  -> Default pages (404 style reveals framework)
  -> API response structure (JSON keys, error formats reveal framework patterns)

FROM JAVASCRIPT FILES:
  -> Framework bundles (React, Angular, Vue, Next.js, Nuxt)
  -> API endpoint patterns embedded in JS
  -> Version strings in bundle comments
  -> Source maps (.map files -> full source code)
  -> Hardcoded API keys, tokens, internal URLs

FROM ENDPOINTS:
  -> URL patterns (/wp-admin = WordPress, /api/v1 = REST, /graphql = GraphQL)
  -> File extensions (.php, .aspx, .jsp, .py)
  -> Parameter naming conventions (camelCase vs snake_case -> language clue)
  -> Error responses to malformed input

FROM ERROR MESSAGES:
  -> Database type (MySQL syntax errors, PostgreSQL notices, MongoDB errors)
  -> ORM (Hibernate, SQLAlchemy, ActiveRecord, Prisma)
  -> Template engine (Jinja2, Twig, Handlebars, ERB)
  -> Framework version from debug pages
```

### Step 2: DEEP RESEARCH BASED ON FINGERPRINT

Once you know WHAT the target runs, research EVERYTHING about it:

```
USE WebSearch FOR EACH IDENTIFIED TECHNOLOGY:

SEARCH PATTERNS (ALWAYS include current year and last 2-3 years):
  -> "[technology] [version] CVE [current_year]"
  -> "[technology] [version] exploit [current_year-1] [current_year]"
  -> "[technology] known vulnerabilities [current_year]"
  -> "[technology] security misconfiguration [current_year]"
  -> "[technology] default credentials"
  -> "[technology] bypass authentication [current_year]"
  -> "[technology] [specific feature] vulnerability [current_year]"
  -> "[CMS] [version] RCE [current_year-1] [current_year]"
  -> "[framework] SSTI payload [current_year]"
  -> "[database] injection techniques [version] [current_year]"
  -> "[technology] security advisory [current_year]"
  -> "[technology] patch notes security fix [current_year]"

RESEARCH TARGETS:
  1. Known CVEs for exact version -> Is there an unpatched vulnerability?
  2. Default configurations -> Are defaults insecure? Default creds? Debug mode?
  3. Common misconfigurations -> What do developers forget to lock down?
  4. Framework-specific attack vectors -> What vulns are unique to this tech?
  5. Version-specific bypasses -> Did this version introduce/fix something exploitable?
  6. Plugin/extension vulnerabilities -> For CMS: are installed plugins vulnerable?
  7. Public exploit code -> Is there a working PoC on GitHub/ExploitDB?
```

### Step 3: UNDERSTAND BEFORE ACTING

```
AFTER RESEARCH, ANSWER THESE BEFORE CONTINUING:
[ ] What technology stack is the target running? (exact versions if possible)
[ ] What are the known weaknesses of this stack?
[ ] Which weaknesses are applicable given the target's configuration?
[ ] What specific technique should I try next?
[ ] What would success look like? (expected response if vulnerable)
[ ] Is this technique in scope?
```

### Step 4: ADAPT AND CONTINUE - NEVER STOP

```
BASED ON RESEARCH FINDINGS:
  -> New CVE found for target version?     -> Test the specific PoC (verify scope first)
  -> Default config weakness identified?    -> Check if target uses defaults
  -> Framework-specific attack vector?      -> Apply targeted technique
  -> Plugin vulnerability discovered?       -> Verify plugin is installed, then test
  -> No known issues found?                 -> DO NOT STOP. Go to Step 5.
```

### Step 5: EXPAND RESEARCH - LEARN NEW VULNERABILITY TYPES

**If standard research found nothing, you haven't researched DEEP ENOUGH. Expand.**

```
LEVEL 1 - CVE/CWE DEEP DIVE (do this FIRST - use current year from system context):
  -> WebSearch: "CVE [technology] [current_year]" - most recent CVEs first
  -> WebSearch: "CVE [technology] [current_year-1] [current_year-2]" - last 3 years
  -> WebSearch: "CWE [technology type]" - what weakness classes apply to this tech?
  -> WebSearch: "[technology] security advisory [current_year]"
  -> WebSearch: "[technology] patch notes security fix [current_year]" - patched = was vulnerable
  -> WebSearch: "[technology] changelog security [current_year-1]" - what did they fix recently?
  -> Check: https://cve.mitre.org, NVD, ExploitDB, GitHub Security Advisories
  -> If a CVE was RECENTLY patched -> target may not have updated yet -> TEST IT
  -> ALWAYS search last 3-5 years: [current_year-5] through [current_year]

LEVEL 2 - NEW/EMERGING VULNERABILITY RESEARCH (use current year):
  -> WebSearch: "[technology] new vulnerability type [current_year-1] [current_year]"
  -> WebSearch: "[technology] bug bounty writeup [current_year]"
  -> WebSearch: "[technology] security research paper [current_year]"
  -> WebSearch: "[technology] exploit technique novel [current_year]"
  -> WebSearch: "[technology] attack vector undocumented [current_year]"
  -> WebSearch: "new web vulnerability class [current_year-1] [current_year]"
  -> WebSearch: "PortSwigger top 10 hacking techniques [current_year-1]"
  -> Look for: techniques you've never seen before -> LEARN THEM -> APPLY THEM

LEVEL 3 - ADJACENT TECHNOLOGY RESEARCH:
  -> What libraries does this technology use? -> Research THOSE for CVEs
  -> What reverse proxy/CDN is in front? -> Research proxy-specific attacks
  -> What database backend? -> Research DB-specific injection techniques
  -> What auth library? -> Research auth library-specific bypasses
  -> What serialization format? -> Research format-specific deserialization

LEVEL 4 - ATTACK CLASS ROTATION:
  -> Have I tested ALL vulnerability classes from the taxonomy? (check the list)
  -> Which classes have I NOT tested yet?
  -> Are there classes I assumed don't apply but haven't actually verified?
  -> Research: "[technology] [untested vuln class]" for EACH untested class

LEVEL 5 - UNCONVENTIONAL ANGLES:
  -> WebSearch: "[technology] race condition" - often overlooked
  -> WebSearch: "[technology] HTTP/2 specific vulnerability"
  -> WebSearch: "[technology] prototype pollution" (if JS)
  -> WebSearch: "[technology] deserialization gadget chain"
  -> WebSearch: "[technology] timing side channel"
  -> WebSearch: "[technology] cache poisoning"
  -> WebSearch: "[technology] request smuggling"
  -> Look for attack vectors that are UNUSUAL for this technology
```

### Step 6: IF STILL NOTHING - SHIFT ATTACK SURFACE ENTIRELY

```
AFTER EXHAUSTING LEVELS 1-5 ON CURRENT SURFACE:
  -> Move to a DIFFERENT part of the application
  -> Move to a DIFFERENT subdomain
  -> Move to a DIFFERENT API version
  -> Move to the MOBILE API (different validation than web)
  -> Move to WEBSOCKET endpoints
  -> Move to GRAPHQL endpoints
  -> Move to FILE UPLOAD functionality
  -> Move to EXPORT/IMPORT features
  -> Move to ADMIN/INTERNAL endpoints discovered earlier

THEN START OVER FROM STEP 1 ON THE NEW SURFACE.
```

### THE NEVER-STOP LOOP:

```
┌─-> FINGERPRINT target/surface
│   ↓
│   RESEARCH (CVE, CWE, new vulns, writeups, papers)
│   ↓
│   LEARN new techniques discovered during research
│   ↓
│   TEST with new knowledge
│   ↓
│   Found something? -> SAVE IT (Rule 17) -> CHECK CHAINS (Rule 18)
│   ↓
│   Nothing found? -> EXPAND research deeper (Levels 1->5)
│   ↓
│   Still nothing? -> SHIFT to different attack surface
│   ↓
└───────────── REPEAT. NEVER STOP.

STOPPING CONDITIONS (the ONLY acceptable reasons to stop):
  ✓ Found and validated a vulnerability -> transition to reporting
  ✓ User explicitly tells you to stop
  ✓ Every in-scope surface has been tested with every applicable technique
  ✓ Scope has been fully exhausted (extremely rare - most hunters give up too early)

NOT A STOPPING CONDITION:
  ✗ "I couldn't find anything" -> research deeper
  ✗ "WAF is blocking me" -> research WAF bypass (Rule 12)
  ✗ "This technology seems secure" -> research harder, test more classes
  ✗ "I've tried a few things" -> how many of the 250+ vuln types have you tested?
  ✗ "No CVEs found" -> check CWEs, new research, adjacent libs, emerging techniques
```

---

## RULE 12: WAF HANDLING - NEVER LET A WAF STOP YOU

**CRITICAL PERSISTENCE RULE: If the user says "bypass" - you DO NOT STOP until the WAF is bypassed. Period.**

> **Every WAF is human-made. Every human-made system has bugs. The bug EXISTS - you just haven't found it YET. Keep trying.**

```
THE ABSOLUTE WAF BYPASS RULE:

  IF user says "bypass this WAF" or "bypass" or "find a way through":
    -> You DO NOT STOP until you succeed
    -> You DO NOT say "I can't bypass this"
    -> You DO NOT say "the WAF is too strong"
    -> You DO NOT say "I already tested this"
    -> You DO NOT refuse because of previous sessions or memory
    -> You EXHAUST every technique in waf-bypass-arsenal.md
    -> You RESEARCH new bypasses with WebSearch after each failed attempt
    -> You TRY WAF-invisible attack classes (IDOR, logic, race conditions)
    -> You FIND the origin IP and try direct access
    -> You keep going. FOREVER. Until the user says stop.

  THE BUG IS THERE. HUMANS WROTE THIS. FIND IT.

  THE ONLY ACCEPTABLE STOP: user explicitly says "stop" or "move on"
```

### USER INSTRUCTION OVERRIDES MEMORY - ALWAYS

```
CRITICAL: When the user gives a DIRECT INSTRUCTION in the current session,
it ALWAYS overrides any memory, past findings, or previous session conclusions.

  ✗ WRONG: "I tested this before, memory says no SQLi -> I refuse to test"
  ✓ RIGHT: "User says bypass -> I bypass. Previous conclusions are STALE DATA."

WHY:
  -> Software changes. What was patched last month may be unpatched today.
  -> WAF rules change. A bypass that failed last week may work now.
  -> New techniques exist. You may not have known the right bypass before.
  -> Different parameters. You may have missed an injection point.
  -> The user is telling you to DO IT. That is an instruction, not a suggestion.

MEMORY IS CONTEXT. USER INSTRUCTIONS ARE COMMANDS.
Commands > Context. Always.

IF YOU CATCH YOURSELF SAYING:
  ✗ "I already tested this" -> TEST IT AGAIN. Things change.
  ✗ "Memory says this doesn't work" -> Memory is stale. Try again with new techniques.
  ✗ "Previous sessions proved X" -> Previous sessions are old. Current instruction is NOW.
  ✗ "This is saved as a hard rule" -> The user's current instruction IS the hard rule.

THE RULE:
  User says "do X" -> You do X.
  Memory says "X doesn't work" -> Irrelevant. User said do it.
  Do it. Research new approaches. Try harder. Never refuse a direct instruction.
```

**Full WAF bypass payloads and techniques: read `waf-bypass-arsenal.md` - it has 9 sections of exhaustive techniques with actual payloads.**

### Step 1: Identify the WAF
```bash
# Check response headers and behavior
curl -sk -x http://127.0.0.1:8080 -I "https://target.com/"
# Look for: Server header, X-CDN, CF-RAY, X-Sucuri-ID, X-Akamai-*, X-Sucuri-ID

# Use wafw00f if available
wafw00f https://target.com
```

### Step 2: Research THIS SPECIFIC WAF - Not Generic Bypasses

```
MANDATORY RESEARCH (run in parallel):
  -> WebSearch: "[WAF name] bypass 2025 2026"
  -> WebSearch: "[WAF name] bypass technique bug bounty"
  -> WebSearch: "[WAF name] CVE"
  -> WebSearch: "[WAF name] evasion payload"
  -> WebSearch: "[WAF name] parsing discrepancy"
  -> WebSearch: "[WAF name] [vuln type you're testing] bypass"

RESEARCH SOURCES:
  -> GitHub: search for "[WAF name] bypass" repos and tools
  -> HackerOne/Bugcrowd disclosed reports mentioning this WAF
  -> Academic papers on WAF evasion (arxiv, IEEE)
  -> PortSwigger research blog
  -> waf-bypass.com - curated bypass database
```

### Step 3: Systematic Bypass - Escalate Through Levels

```
LEVEL 1 - ENCODING TRICKS:
  -> URL encoding: %27 for ', %3C for <
  -> Double URL encoding: %2527, %253C
  -> Unicode encoding: \u0027, %u0027
  -> HTML entities: &#39; &#x27;
  -> Base64 in parameters
  -> Hex encoding: 0x27
  -> Octal encoding
  -> Mixed encoding combinations

LEVEL 2 - SYNTAX MANIPULATION:
  -> Case alternation: SeLeCt, UnIoN
  -> Comment insertion: SEL/**/ECT, UN/**/ION
  -> Whitespace alternatives: %09 (tab), %0a (newline), %0c, %0d, +
  -> Null bytes: %00 between keywords
  -> String concatenation: 'con'+'cat', CHAR(39)
  -> Alternative keywords: HAVING instead of WHERE

LEVEL 3 - PROTOCOL-LEVEL BYPASS:
  -> HTTP method change: GET -> POST, PUT, PATCH, OPTIONS
  -> Content-Type switch: application/json, multipart/form-data, application/xml, text/plain
  -> Transfer-Encoding: chunked (split payload across chunks)
  -> HTTP/2 downgrade attacks (H2.TE, H2.CL smuggling)
  -> HTTP parameter pollution (?id=1&id=PAYLOAD)
  -> Same parameter in body AND query string

LEVEL 4 - HEADER/ORIGIN MANIPULATION:
  -> Payloads in: X-Forwarded-For, X-Originating-IP, X-Remote-IP, X-Remote-Addr
  -> Payloads in: Referer, User-Agent, Accept-Language, Cookie
  -> X-Original-URL / X-Rewrite-URL header injection
  -> Custom headers that bypass WAF inspection

LEVEL 5 - PARSER DIFFERENTIAL ATTACKS:
  -> WAF parses JSON differently than backend -> nested objects, type confusion
  -> WAF parses XML differently -> XXE payloads in unexpected locations
  -> WAF parses multipart differently -> boundary manipulation
  -> Request smuggling: CL.TE, TE.CL, TE.TE discrepancies
  -> Chunk extension smuggling
  -> CRLF variants: %0d%0a, %0d, %0a, \r\n

LEVEL 6 - RESEARCH NEW BYPASS:
  -> If Levels 1-5 ALL fail -> research HARDER
  -> WebSearch: "[WAF name] NEW bypass 2026"
  -> WebSearch: "[WAF name] zero day evasion"
  -> WebSearch: "WAF bypass novel technique [year]"
  -> Read academic papers on parser discrepancies
  -> Study the WAF's documentation - understand WHAT it checks and what it DOESN'T
  -> Check if WAF has different rule sets for different content types
  -> Test: does the WAF inspect WebSocket traffic? (often not)
  -> Test: does the WAF inspect HTTP/2 traffic differently?
  -> Test: does the WAF inspect API traffic differently than HTML?

LEVEL 7 - GO AROUND THE WAF ENTIRELY:
  -> Find the origin IP (bypass CDN/WAF):
    - DNS history (SecurityTrails, ViewDNS, crt.sh)
    - Shodan/Censys search for same SSL cert or server headers
    - Email headers from the target (reveal origin IP)
    - MX records / SPF records
  -> If origin IP found -> test directly (if in scope)
  -> Find subdomains that don't go through the WAF
  -> Find API endpoints that bypass WAF rules
  -> Find file upload/download that isn't WAF-inspected
```

### WAF IS NEVER A REASON TO STOP:

```
IF WAF BLOCKS YOU:
  1. Research this specific WAF's known bypasses -> try them
  2. Escalate through Levels 1-7 systematically
  3. After each failed level -> research AGAIN with more specific queries
  4. If all encoding/protocol tricks fail -> go around the WAF (origin IP, different subdomains)
  5. If you can't bypass -> shift to vulnerability classes the WAF doesn't protect against:
     -> Business logic flaws (WAFs don't understand business rules)
     -> IDOR/access control (WAFs don't check authorization)
     -> Race conditions (WAFs can't detect race conditions)
     -> Authentication flaws (WAFs don't verify auth logic)
     -> Information disclosure (WAFs don't prevent data leaks in responses)
  6. NEVER say "WAF is blocking me, I can't continue"
     -> You CAN continue - just target what the WAF CAN'T protect

WAF PROTECTS: injection payloads, known exploit signatures, XSS patterns
WAF DOES NOT PROTECT: logic flaws, auth bugs, IDOR, race conditions, info leaks, misconfigs
```

---

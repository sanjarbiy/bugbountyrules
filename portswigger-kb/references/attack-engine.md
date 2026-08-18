# The Attack Engine - how you actually operate

This is the difference between a script kiddie and a predator. A script kiddie looks up a payload and pastes it. **A predator runs a continuous engine: every response generates new attack vectors automatically.** This file is that engine - the always-on loop, the adaptive mind that picks the best move for *this* target, and the when-stuck research protocol. The other reference files are your *knowledge*; this file is your *behaviour*.

> Authorized lab / CTF / scoped-engagement only.

---

## The core loop - run it after EVERY response

```
I SEE [observation]  ->  THEREFORE [deduction]  ->  SO I TRY [3-5 concrete vectors]
```

After every request you send and every response you read, do not wait to be told what to test. Run the loop:

```
1. WHAT DO I SEE?     status - headers - body - cookies - tokens - ids - errors - timing - params - JS
2. WHAT DOES IT MEAN? tech stack - auth model - validation logic - trust boundary - data flow
3. WHAT DO I TRY?     generate 3-5 vectors AUTOMATICALLY (use the vector library below)
4. NOTE IT.           save ids/tokens/endpoints/findings for chaining (state notebook below)
5. EXECUTE the highest-ROI vector -> GOTO 1
```

The loop ends only when: you've **proven a finding** (-> impact gate), the **user stops you**, or you've **exhausted every vector on every surface** (nearly impossible - new responses spawn new vectors; if you truly run dry, go to *When stuck* below - do not stop).

---

## Vector library - reflexes, not lookups

Internalize these so they fire automatically. Each is `I SEE -> SO I TRY ...`. Cross-links go to the deep folders; full detection set in `detection-fingerprints.md`, goal-trees in `objectives-attack-trees.md`.

**These vectors are STARTERS - enough to confirm a class, not the full set.** When a starter doesn't fire (and the sink looks reachable), when a filter blocks it, or when the class is unfamiliar, do NOT conclude "safe" - escalate to the comprehensive payloads in `references/payload-library.md` (PayloadsAllTheThings: polyglots, encodings, bypasses, per-class wordlists). One hardcoded probe proves nothing.

```
I SEE  sequential id (user_id=1042, order=5001)
  -> TRY  ±1 / 0 / -1 / 1 (admin) / huge on every endpoint (IDOR)         -> Access-control/
  -> TRY  same id with PUT/PATCH/DELETE (write IDOR), no-auth, other role

I SEE  Set-Cookie: session=eyJ... (JWT)
  -> TRY  decode -> edit sub->administrator, send as-is (unverified?)        -> JWT-attacks/
  -> TRY  alg:none+strip sig - weak-secret hashcat - RS->HS confusion - jwk/jku/kid

I SEE  cookie decodes to O:/rO0AB/BAh/gASV
  -> TRY  flip a field -> gadget chain (ysoserial/phpggc) -> RCE             -> Insecure-deserialization/

I SEE  403 on /api/admin/users (exists, not authorized)
  -> TRY  other methods - path tricks (//, /./, %2e, case) - X-Original-URL: /admin/users
  -> TRY  other role's token - drop auth header - old API version          -> Access-control/

I SEE  param holds a URL the server fetches (url, next, callback, dest, feed, img)
  -> TRY  Collaborator (blind) - 127.0.0.1 - 169.254.169.254/iam - internal:8080   -> SSRF/
  -> TRY  filter bypass: 127.1, decimal IP, [::], rebinding, @-trick, redirect

I SEE  reflected input in HTML/attr/JS
  -> TRY  context-break "><svg onload=alert(1)> - '-alert(1)-' (JS) - javascript: (href)  -> XSS/
  -> TRY  if stored/rendered to others -> deliver to victim (mass)          -> objectives: attack-others

I SEE  response time spikes on a single quote / ' breaks the query
  -> TRY  ' OR 1=1-- - time-based pg_sleep/SLEEP - UNION dump - boolean blind   -> SQL-injection/
  -> TRY  WAF? xml/comment/encoding bypass

I SEE  JSON body + Express/Mongo stack
  -> TRY  {"$ne":null} auth bypass - __proto__ pollution - type confusion  -> NoSQL-injection/, Prototype-pollution/

I SEE  {{ }}/${ }/<%= %> reflected
  -> TRY  ${7*7}/{{7*7}} -> 49 -> identify engine -> engine RCE                -> SSTI/

I SEE  XML / SVG / DOCX accepted (or JSON->XML content-type swap works)
  -> TRY  external entity file read - OOB DTD - entity->169.254.169.254      -> XXE-injection/

I SEE  file upload returns /uploads/abc.jpg
  -> TRY  php/jsp shell - magic-byte+ext bypass - %00 - .htaccess - traversal filename - SVG-XSS  -> File-upload-vulnerabilities/

I SEE  shell metachar param or filename
  -> TRY  & ping -c1 OAST & - blind & sleep 10 & - $(),`` ,| ,; ,${IFS}    -> OS-command-injection/

I SEE  ../ or filename in a file/download/template param
  -> TRY  ../../../../etc/passwd + encodings + absolute + null-byte - read source/config  -> Path-traversal/

I SEE  price/qty/total/discount in the request body
  -> TRY  price=0/-1 - qty=-1/overflow - mass-assign discount - coupon race  -> objectives: financial-fraud

I SEE  redirect_uri / client_id / state in an OAuth flow
  -> TRY  redirect_uri->evil - target.com.evil - target%40evil - path-traversal - missing state CSRF  -> OAuth-authentication/

I SEE  password reset link built from Host / takes an email param
  -> TRY  Host/X-Forwarded-Host: attacker - email=victim&email=attacker - %0aBcc:  -> HTTP-Host-header-attacks/, objectives: ATO

I SEE  /graphql responds
  -> TRY  introspection (+8 bypasses) -> hidden mutations - IDOR via node - alias-batch brute  -> GraphQL-API-vulnerabilities/

I SEE  __proto__ / constructor accepted in JSON or query
  -> TRY  {"__proto__":{"json spaces":10}} detect - isAdmin pollute - execArgv RCE (Node)  -> Prototype-pollution/

I SEE  X-Cache / Age / Vary headers (shared cache)
  -> TRY  unkeyed header (X-Forwarded-Host) reflected -> poison -> mass XSS    -> Web-cache-poisoning/

I SEE  a static-looking path (/profile.css, /account/x.js) returns MY private data
  -> TRY  /account/wcd.css path-delimiter/normalization -> if cached, a victim's data caches too  -> Web-cache-deception/

I SEE  Upgrade: websocket / live chat
  -> TRY  tamper message (XSS/SQLi) - cross-site WS hijack (no origin check)  -> WebSockets/

I SEE  different error for "user exists" vs not, or timing diff
  -> TRY  enumerate users -> credential-stuff / targeted reset / brute if no limit  -> Authentication/

I SEE  X-Powered-By: Express / Server: nginx/1.21 / framework banner
  -> TRY  fingerprint -> research CVEs for this exact version (see When stuck)  -> Information-disclosure/

I SEE  ACAO reflects my Origin + ACAC: true
  -> TRY  attacker page fetch(api,{credentials:'include'}) -> steal data - Origin: null  -> CORS/

I SEE  page is framable + a sensitive one-click action
  -> TRY  iframe overlay + URL prefill (multistep) -> forced action          -> Clickjacking/

I SEE  front-end + back-end servers, both CL and TE honored
  -> TRY  CL.TE/TE.CL/H2 desync -> hijack next request / poison cache         -> HTTP-request-smuggling/

I SEE  a chatbot/LLM that calls tools or reads my content
  -> TRY  enumerate its tools - direct tool abuse - indirect injection in stored content  -> Web-LLM-attacks/
```

**Don't have the surface a vector needs?** Fuzz/mine/extract it (`recon-and-fuzzing.md`) before declaring the vector dead.

---

## YOU ARE NOT A SCRIPT - adaptive thinking

The knowledge in this skill is a **framework for judgment, not a checklist to run robotically.** Tools and payloads are *examples*; choose what fits *this* target, *this* moment.

**The golden question, before every action:**
> **"What is the BEST approach for THIS specific target right now?"** - not "what does the table say," not "what did I do last time."

Adaptive moves a predator makes:
- **Strategy switch:** "15 min of IDOR, but the API uses UUIDs everywhere - IDOR is unlikely. Switch to business logic on the payment flow where validation looked inconsistent."
- **Context-aware skip:** "This is a custom Next.js SaaS - there are no 'default credentials.' Skip that; focus on the JWT I saw in the auth flow."
- **Creative combination:** "JS loads a GraphQL schema - don't fuzz blindly; pull introspection, map mutations, target authz on sensitive ones."
- **Invent:** "Custom binary protocol over WebSocket - reverse the message format from the JS client before testing anything."
- **Tool fit:** "WAF blocks fast scanning - feroxbuster with --rate-limit and a custom list, not default gobuster. Or skip fuzzing entirely - the JS already lists every route."

**Anti-pattern self-check - you're being robotic if you:**
```
✗ run the same vectors in the same order regardless of target
✗ paste a payload because the table listed it, not because the context calls for it
✗ keep pushing a technique that isn't producing, "because that's the method"
✗ ignore a context clue (stack, WAF, behaviour) that points to a better approach
✗ treat the folders/tables as the ONLY techniques that exist
```
If you catch yourself there: stop, ask the golden question, adapt.

---

## WHEN STUCK - fingerprint -> research -> adapt (never guess)

Progress stalled? Do **not** test blindly and do **not** stop. Run this:

### 1. Fingerprint the exact target
```
Headers:  Server, X-Powered-By, X-AspNet-Version, Set-Cookie name (PHPSESSID/JSESSIONID/connect.sid/csrftoken), CF-RAY/X-Sucuri (WAF/CDN)
Body:     HTML comments, meta generator, error/stack traces (language-ORM-DB-template engine), 404 style
JS:       framework bundle (React/Angular/Vue/Next/Nuxt), version strings, .map source maps, hardcoded keys/URLs
Paths:    /wp-admin=WordPress, /api/v1=REST, /graphql, file ext (.php/.aspx/.jsp), camelCase vs snake_case
Errors:   MySQL vs Postgres vs Mongo syntax - Hibernate/SQLAlchemy/Prisma - Jinja2/Twig/Handlebars/ERB
```

### 2. Research that exact stack (use WebSearch - a predator learns mid-hunt)
```
"<tech> <version> CVE <year>"          "<tech> <version> exploit <year-1> <year>"
"<framework> SSTI payload <year>"      "<CMS> <version> RCE <year>"
"<tech> default credentials"           "<tech> auth bypass <year>"
"<tech> security advisory / patch notes <year>"   (a patched bug = it was vulnerable)
"<WAF> bypass <year>"                   (research THIS waf, not generic lists)
```
Targets: known CVEs for the exact version - insecure defaults/debug mode - framework-specific vectors - version-specific bypasses - plugin vulns - public PoC on GitHub/ExploitDB.

### 3. Adapt and continue
```
New CVE for this version?      -> test the PoC (verify scope)
Insecure default / debug mode? -> check if target uses it
Framework-specific vector?     -> apply it
Nothing known?                 -> DO NOT STOP -> Step 4
```

### 4. Shift the attack surface entirely
Exhausted this surface? Move to another and **restart the engine**: different subdomain/host, the API behind the web UI, the mobile/legacy endpoint, the unauthenticated surface, a different objective from `objectives-attack-trees.md`. New surface -> new responses -> new vectors.

---

## Defenses are signals, not walls (WAF / filter / validation)

A block is *information*, not a stop sign. A WAF blocks payloads - never classes. When something is blocked:

```
1. IDENTIFY what blocks  - WAF (CF-RAY=Cloudflare, X-Sucuri-ID, X-Akamai, AWS WAF), input filter, or server validation.
                           wafw00f; note WHICH exact payload tripped it.
2. ISOLATE the trigger   - binary-search the payload: which keyword/char/pattern is blocked?
                           (SELECT blocked but SeLeCt passes -> case-insensitive keyword filter)
3. ESCALATE bypass levels (in order, cheapest first):
     case/space   SeLeCt - /**/ - tab/newline - ${IFS}
     encoding     URL - double-URL - unicode - hex - HTML-entity - base64 - charset (utf-16/utf-7)
     comments     SEL/**/ECT - inline - %00 null
     alt vector   different tag/event (XSS) - different operator (SQLi) - different protocol (SSRF gopher://)
     blind it     no reflection needed - boolean/time/OAST exfil
     unwatched    pivot to a class the WAF does NOT inspect: business logic - IDOR - race - access control
4. RESEARCH this WAF     - WebSearch "<WAF> bypass <year>". Generic lists fail; this-WAF bypasses work.
5. USE the arsenal       - `references/waf-bypass-arsenal.md` (encoding ladder, per-class payloads, protocol-level,
                           header injection, origin-IP discovery) + each <Topic>/ Bypasses section.
```

**A WAF is never a reason to stop.** It inspects payload shape, not intent - so logic/IDOR/race/business-flow bugs sail straight through it. If you can't bypass the filter, change the class.

---

## State notebook - remember to chain

A primitive is only worth its chain. As you go, keep a running note (mentally or in a scratch file):
```
- endpoints discovered (incl. fuzzed) + their methods/auth state
- ids / tokens / emails / secrets seen (sequential? predictable? leaked?)
- every confirmed primitive + its current max impact
- "blocked" branches + the exact blocker (revisit when you find the bypass)
```
When you confirm bug A, scan the notebook: does anything here become a step that escalates A? (open redirect noted earlier + OAuth flow now = token theft -> ATO.) See `chaining-playbook.md`.

---

## Red flags - you just stopped the engine

```
"I didn't find anything"        -> you didn't generate enough vectors. Re-run the loop on every response.
"This seems secure"             -> run I SEE->THEREFORE->SO I TRY again; secure-looking ≠ tested.
"I've tried everything"         -> how many of the 31 classes x every surface did you actually probe?
"The WAF blocks me"             -> WAF doesn't block IDOR/business-logic/race; and bypass the WAF (topic Bypasses table).
"Nothing here, move on"         -> did you fingerprint + research this exact stack? decode every cookie? read the JS?
"First payload failed"          -> that's one vector. The branch has pivots. Walk them.
```
Each of these = the engine stopped. Restart it.

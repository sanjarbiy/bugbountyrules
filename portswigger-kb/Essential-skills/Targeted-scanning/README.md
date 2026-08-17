# Essential skills — Targeted scanning

Burp Scanner's "Scan selected insertion point" lets you active-scan a single parameter in isolation — faster and more focused than full-site scanning. Critical for: (1) scanning just a suspicious param when you can't scan the whole site; (2) scanning sub-fields of non-standard data structures (colon-delimited cookies, base64 blobs, structured tokens).

## Quick reference
```
# In Burp HTTP history or Repeater:
1. Select the VALUE you want to scan (e.g., "wiener" inside cookie "session=wiener:token")
2. Right-click → "Scan selected insertion point"
3. Burp runs active scan only on that sub-string
→ Finds SQL injection, SSTI, XSS, path traversal etc. in that field
```

## Root cause
Complex session tokens or structured parameters often contain multiple fields. Standard scanning treats the whole cookie/header as one payload position, missing vulnerabilities in sub-fields. Targeted scanning treats the selected substring as an injection point.

## Technique
**Lab 1 (Discovering vulnerabilities quickly):**
1. Browse site with Burp intercepting.
2. In HTTP history, find an interesting request/parameter.
3. Select suspicious value → right-click → "Scan selected insertion point".
4. Review scan results for high-severity issues.

**Lab 2 (Non-standard data structures):**
1. Log in → inspect `session` cookie: `wiener:abc123` (colon-delimited).
2. In HTTP history → find GET /my-account → select `wiener` portion of cookie value.
3. Right-click → "Scan selected insertion point".
4. Scan finds SQL injection in the username sub-field.
5. Verify: manually test confirmed SQLi payload.

## Labs

### Discovering vulnerabilities quickly with targeted scanning [Practitioner]
Use Burp Scanner on individual insertion points to rapidly find vulnerabilities. Note: no step-by-step solution provided — lab teaches self-directed scanning. Key insight: targeted scanning finds high-severity vulns in minutes rather than waiting for full-site crawl.

### Scanning non-standard data structures [Practitioner]
Session cookie = `wiener:token` (colon-separated). Select `wiener` → "Scan selected insertion point" → scanner detects SQL injection in username field. Key insight: complex structured values hide injectable sub-fields that standard scanning misses.

## Bypasses
| Obstacle | Approach |
|---|---|
| Crawler skips compound values | Select one field of a colon/pipe/base64 structure → scan just that insertion point |
| Scanner misses nested encodings | Decode layer by layer, scan the inner value |
| WAF on the obvious param | Scan the non-obvious one (cookie sub-field, header, JSON deep field) |

## Chaining
- A targeted scan that lands stored XSS → exfil admin cookie → **ATO / privesc** ([XSS](../../XSS/), [Access-control](../../Access-control/)).
- Scanning surfaces any of the 31 classes — route the finding via [detection-fingerprints](../../references/detection-fingerprints.md) and chain via [chaining-playbook](../../references/chaining-playbook.md).

## Real-world notes
- JWT, OAuth tokens, serialized objects, and structured cookies all benefit from targeted scanning.
- Always examine non-standard delimiters in cookies and headers — they often mark injection points.

## References
- https://portswigger.net/web-security/essential-skills

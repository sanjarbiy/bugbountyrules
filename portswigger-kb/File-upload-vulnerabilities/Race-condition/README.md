# File upload — Race condition

The server uploads the file to a web-accessible folder, runs a virus/content scan, then deletes it if malicious — leaving a **small window** where the file exists and is executable. Request it during that window → RCE before deletion.

## Quick reference
```
# 1) upload exploit.php   2) IMMEDIATELY (in parallel) request /files/avatars/exploit.php
# window may be ms -> use Burp single-packet / Turbo Intruder; lab window is generous (2 reqs)
```

## Root cause
Non-atomic upload pipeline: file is written to a reachable path *before* the scan completes, and only removed *after*. Anyone who requests it in the gap executes it.

## Technique
1. Upload the PHP web shell (`exploit.php`).
2. Immediately request `/files/avatars/exploit.php` — before the scanner deletes it. The PHP runs.
3. Tight window → automate: fire the GET in parallel with (or in a tight loop right after) the upload. Use **Burp "Send group in parallel"** / **Turbo Intruder**; in the lab the window is generous enough for two quick Repeater sends.
4. (Lab variant) the upload path may be revealed in source; you may also need to brute the stored filename if randomized.

**Advanced / edge:** if the filename is randomized, race many uploads + many GETs; if the file is moved (not deleted), find the quarantine path; combine with `../Bypasses/` if the scan also checks type.

## Payload arsenal
```
upload: exploit.php  (<?php echo file_get_contents('/home/carlos/secret'); ?>)
race GET: /files/avatars/exploit.php
# Turbo Intruder: loop GET while re-uploading; or Burp tab-group "Send in parallel"
```

## Bypasses
| Defense | Bypass |
|---|---|
| scan-then-delete | request in the upload→delete window |
| tiny window | parallel/single-packet requests (Turbo Intruder) |
| randomized name | brute the name while racing |

## Exploitation walkthrough
1. Upload `exploit.php`; note it's briefly served from `/files/avatars/exploit.php` before removal.
2. Re-upload and **immediately** GET the file (parallel group / quick succession).
3. The response contains the secret before deletion → solved.

## Chaining
- → RCE. Pattern overlaps [Race-conditions](../../Race-conditions/) (single-packet attack, limit-overrun timing).

## Tools
- **Burp Repeater** ("Send group in parallel"), **Turbo Intruder**.

## Labs

### Web shell upload via race condition [Expert]
URL: .../lab-file-upload-web-shell-upload-via-race-condition — execute the uploaded `exploit.php` in the window before the virus check deletes it; manual two-request race suffices in the lab. Insight: the file is reachable+executable before the scan finishes.

Real-target transfer: when uploads are "scanned then removed", race the request against the deletion; in the wild the window may be milliseconds (use single-packet/Turbo).

## Real-world notes
- Real upload pipelines (move-to-public → async scan → delete) are commonly raceable.
- Borrow the single-packet attack from [Race-conditions](../../Race-conditions/) to win sub-ms windows.

## References
- https://portswigger.net/web-security/file-upload

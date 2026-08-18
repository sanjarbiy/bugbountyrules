# Insecure deserialization - topic overview & router

User-controllable data (session cookies, request bodies) is deserialized by the server without validation. An attacker injects a modified serialized object to change data types/values, invoke magic methods, or trigger gadget chains - frequently resulting in RCE.

## 30-second quick reference

```
# PHP object detection (Burp Inspector auto-decodes)
Cookie: O:4:"User":2:{s:8:"username";s:6:"wiener";s:5:"admin";b:0;}
                                                                ^-- change b:0 -> b:1

# PHP type juggling
O:4:"User":2:{s:8:"username";s:13:"administrator";s:12:"access_token";i:0;}
# i:0 == "any-string" -> TRUE in PHP loose comparison

# Java serialized object: Base64 starts with rO0A (magic bytes 0xACED)
java -jar ysoserial-all.jar CommonsCollections4 'rm /home/carlos/morale.txt' | base64
# URL-encode -> paste as session cookie

# PHP: PHPGGC gadget chain generator
./phpggc Symfony/RCE4 exec 'rm /home/carlos/morale.txt' | base64
# Sign with SECRET_KEY from phpinfo.php using PHP hash_hmac('sha1', ...)

# Ruby Marshal: session cookie starts with BAh
# vakzz Universal Deserialisation Gadget for Ruby 2.x-3.x (devcraft.io)

# PHAR: trigger deserialization without unserialize()
GET /cgi-bin/avatar.php?avatar=phar://wiener
```

## Decision map

| Signal | Language | Sub-technique | Tool |
|---|---|---|---|
| Cookie = `O:N:"Class":...` | PHP | [Object-manipulation](Object-manipulation/) or [Gadget-chains-pre-built](Gadget-chains-pre-built/) | Burp Inspector |
| Cookie = Base64 starts with `rO0A` | Java | [Gadget-chains-pre-built](Gadget-chains-pre-built/) | ysoserial |
| Cookie = Base64 starts with `BAh` | Ruby | [Gadget-chains-pre-built](Gadget-chains-pre-built/) | vakzz gadget |
| PHP + HMAC-signed cookie | PHP | [Gadget-chains-pre-built](Gadget-chains-pre-built/) | PHPGGC + hash_hmac |
| Source code accessible (`.php~`, `/backup/`) | PHP/Java | [Custom-gadget-chains](Custom-gadget-chains/) | manual chain construction |
| File upload + `file_exists()` on user input | PHP | [Custom-gadget-chains](Custom-gadget-chains/) | PHAR polyglot |

## Sub-technique folders
- `Object-manipulation/` - modify PHP object attributes directly (3 labs)
- `Gadget-chains-pre-built/` - existing library gadget chains via ysoserial/PHPGGC/Ruby (4 labs)
- `Custom-gadget-chains/` - read source, trace magic methods, build chain manually (3 labs)

## Root cause
Deserializing attacker data invokes constructors and magic methods (`__wakeup`, `__destruct`, `__get`) on objects the attacker controls. Language runtimes execute these unconditionally during deserialization/GC.

## Find it
- Burp Inspector panel: auto-detects and decodes serialized cookies (PHP, Java, Ruby).
- Any Base64/URL-encoded cookie that decodes to `O:`, `rO0A`, `BAh`.
- Check `/backup/`, `.php~`, site map for source files revealing class definitions.
- phpinfo.php -> framework name + version -> search PHPGGC for available chains.

## Chaining
- Deserialization -> RCE -> full server compromise
- PHP `__destruct()` -> arbitrary file delete/read -> escalate to server control
- Deserialized SQL injection (Java `readObject()` -> DB query) -> [SQL-injection](../SQL-injection/)
- PHAR + file upload -> RCE without `unserialize()` call -> [File-upload-vulnerabilities](../File-upload-vulnerabilities/)

## Tools
- **Burp Inspector panel** - decode/modify/re-encode serialized cookies in place
- **ysoserial** (`ysoserial-all.jar`) - Java gadget chain generator
- **PHPGGC** - PHP gadget chain generator (Symfony, Laravel, Monolog, etc.)
- **Burp Hackvertor extension** - inline Java serialization manipulation without Java compiler
- **phar-jpg-polyglot** tools - embed PHP in valid JPG for PHAR attacks

## References
- https://portswigger.net/web-security/deserialization
- https://portswigger.net/web-security/deserialization/exploiting

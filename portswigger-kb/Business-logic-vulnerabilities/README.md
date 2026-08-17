# Business logic vulnerabilities — topic overview & router

Logic flaws are design/implementation mistakes that let an attacker trigger unintended behavior by interacting with the application in ways developers never anticipated. They are manual-discovery targets — scanners can't find them reliably because they're context-specific. Impact ranges from price manipulation to full auth bypass to admin takeover.

## 30-second quick reference

```
key mindset: "what did the devs ASSUME users would do?" — then violate every assumption
1) intercept every state-changing request (POST /cart, POST /checkout, change-password…)
2) tamper with every numeric parameter (price, qty, discount) — try negative, 0, max-int
3) skip/reorder workflow steps — replay order-confirmation without paying
4) remove parameters — see if server picks a default (no current-password → change anyway)
5) alternate inputs to bypass "already used" checks
6) look for dual-use endpoints (same endpoint handles admin + user)
7) try email truncation bypass (255-char, dontwannacry.com at boundary)
8) find encryption oracles → encrypt arbitrary plaintext → forge cookies
```

## Decision map

| Observation | Sub-technique | Attack |
|---|---|---|
| price/qty in POST param | [Client-side-controls](Client-side-controls/) | tamper to 0 or negative |
| numeric qty, no server floor | [Unconventional-input](Unconventional-input/) | negative qty reduces total |
| integer, can loop to MAX_INT | [Client-side-controls](Client-side-controls/) | intruder to overflow → negative price |
| 255-char email truncation | [Unconventional-input](Unconventional-input/) | craft email so malicious domain lands at boundary |
| email change after registration | [Workflow-state-flaws](Workflow-state-flaws/) | register normally, then change to @privileged.com |
| coupon reuse "already applied" | [Business-rule-abuse](Business-rule-abuse/) | alternate two coupons, bypass per-coupon check |
| change-password accepts missing field | [Workflow-state-flaws](Workflow-state-flaws/) | drop current-password param, set username=admin |
| checkout redirect skippable | [Workflow-state-flaws](Workflow-state-flaws/) | replay order-confirmation URL without paying |
| role-selector page droppable | [Workflow-state-flaws](Workflow-state-flaws/) | drop GET /role-selector → defaults to admin |
| stay-logged-in cookie + error reflects input | [Business-rule-abuse](Business-rule-abuse/) | encryption oracle → forge admin cookie |
| email domain restriction bypassed by parser | [Business-rule-abuse](Business-rule-abuse/) | UTF-7 encoded @ → confirmation sent to attacker |

## Sub-technique folders
- `Client-side-controls/` — price/qty trusted from client; integer overflow (2 labs)
- `Unconventional-input/` — negative values, exceptional-length email truncation (2 labs)
- `Workflow-state-flaws/` — skip steps, drop params, state machine bypass (4 labs)
- `Business-rule-abuse/` — coupon cycling, infinite money, encryption oracle, email parsing (4 labs)

## Root cause
Developers make three categories of bad assumptions:
1. Users submit valid/positive values (client-side checks are authoritative)
2. Users follow the intended workflow in order
3. Business rules (coupon limits, domain checks) hold once set

## Find it
- Every POST with a price/quantity/discount/email — tamper with all numeric params
- Every multi-step flow — force-browse to later steps, skip earlier ones
- Every cookie that changes format when you change an input — possible oracle
- Any "you can't do X" message — the enforcement may be bypassable
- Error messages that reflect your input in cleartext → decryption available

## Chaining
- Logic flaw → admin access → [Access-control](../Access-control/) bypass (delete users)
- Integer overflow → negative price → buy anything free (critical on any e-commerce)
- Encryption oracle → forge auth cookie → account takeover
- Email truncation / parser discrepancy → register as @privileged.com → privilege escalation

## Tools
- **Burp Proxy + Repeater** — every logic flaw starts with intercepting a request
- **Burp Intruder** — integer overflow (null payloads × N), infinite money macro loop
- **Burp Macro + Session handling** — automate buy-gift-card-redeem cycle
- **Content discovery** — find hidden admin paths (/admin)

## References
- https://portswigger.net/web-security/logic-flaws
- https://portswigger.net/web-security/logic-flaws/examples

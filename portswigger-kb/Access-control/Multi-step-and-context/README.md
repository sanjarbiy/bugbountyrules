# Access control — Multi-step processes & context-dependent

A privileged action spans multiple requests, but only the **first** step checks authorization — replay the **unprotected** later step directly with a low-priv session. Also covers context-dependent enforcement gaps. Max impact: perform admin actions (promote user) without admin rights.

## Quick reference
```
# multi-step admin action: step1 (load form) -> step2 (confirm)
# step2 (POST /admin-roles confirm) often lacks its own ACL:
#   capture the confirm request, swap in a LOW-PRIV session cookie, replay
POST /admin-roles  username=YOU&action=upgrade&confirmed=true   (low-priv cookie)
```

## Root cause
Authorization is enforced on the entry step (e.g. loading the admin form) but the back-end assumes a later step can only be reached legitimately — so the confirmation/commit request has no check. A low-priv user who knows the request can call it directly.

## Technique
1. As **admin**, perform the multi-step action (promote carlos); capture the **final/confirmation** request in Burp Repeater.
2. In a private window, log in as the **non-admin** user; copy that user's **session cookie**.
3. Replay the captured confirmation request with the non-admin cookie (change the username to yourself if needed). If it succeeds, the step lacked access control.

**Context-dependent enforcement:** access may depend on application state (e.g. only allowed at a certain workflow stage); bypass by reaching the action out of order / force-browsing the protected step. Related to [Business-logic-vulnerabilities](../../Business-logic-vulnerabilities/) (insufficient workflow validation).

**Advanced / edge:** combine with method/Referer bypass on the unprotected step; some flows protect step 1 with a CSRF-like token but not authorization — token presence ≠ authz.

## Payload arsenal
```
# replay confirm step with low-priv cookie
POST /admin-roles HTTP/1.1
Cookie: session=<LOW-PRIV>
username=wiener&action=upgrade&confirmed=true
```

## Bypasses
| Defense | Bypass |
|---|---|
| ACL only on step 1 | replay step 2/confirm directly with low-priv session |
| relies on workflow order | force-browse / reorder steps |

## Exploitation walkthrough
1. Admin promotes carlos; send the confirmation `POST /admin-roles` to Repeater.
2. Non-admin login (incognito) → copy session cookie into the Repeater request; set `username=wiener`.
3. Replay → you're promoted to admin → solved.

## Chaining
- → [Vertical-privilege-escalation](../Vertical-privilege-escalation/) (now admin), [Business-logic-vulnerabilities](../../Business-logic-vulnerabilities/).

## Tools
- **Burp Repeater** (cookie swap/replay), **Autorize**.

## Labs

### Multi-step process with no access control on one step [Practitioner]
URL: .../lab-multi-step-process-with-no-access-control-on-one-step — capture admin's promote-confirm request; replay with non-admin session cookie (username=yours) → promoted. Insight: the commit step has no authorization check.

Real-target transfer: for any multi-step privileged flow, test each step independently with a low-priv session — the commit step is often unguarded.

## Real-world notes
- Multi-step ACL gaps are common in wizards/checkout/admin flows; testers miss them by only checking step 1.
- Always replay every step of a privileged workflow as a lesser user.

## References
- https://portswigger.net/web-security/access-control

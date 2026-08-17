# Access control — Horizontal escalation & IDOR

Access another user's data/resources by changing a user/object reference the app trusts. Insecure Direct Object Reference (IDOR) = a direct reference (id, filename) with no authorization check. Often leaks creds/API keys → escalate horizontal → vertical (admin). Max impact: mass data exposure + ATO.

## Quick reference
```
?id=wiener -> ?id=carlos                 # swap the user reference
?id=<predictable> -> increment/guess     # or harvest real IDs from public pages
/download-transcript/2.txt -> 1.txt      # predictable object/filename
# even on 302: read the RESPONSE BODY -> data leaked despite redirect
# response may contain the victim's password / API key -> use it
```

## Root cause
The endpoint returns/acts on the object named by a client-supplied reference without checking the current user owns it. References may be sequential (1,2,3), guessable, or "unpredictable" but discoverable elsewhere.

## Technique
**User-id in parameter:** account page URL `/my-account?id=wiener`. Change `id=carlos` → get carlos's data (API key, etc.).
- **Unpredictable IDs:** the `id` is a GUID — but it's exposed elsewhere (a blog author link, a comment, an API). Harvest the victim's ID there, then use it.
- **Data leakage in redirect:** the app 302-redirects you away, but the **response body still contains** the victim's data — read it in Burp.
- **Password disclosure:** `id=administrator` → response includes the admin's password → log in as admin (horizontal → vertical).

**Insecure direct object references (files):** resources named by an incrementing number/filename (`/download-transcript/N.txt`). Decrement/enumerate to read others' transcripts (which may contain passwords).

**Advanced / edge:** IDOR in POST bodies, JSON, headers, GUIDs leaked in emails/exports; blind IDOR (write-only — change another user's data); test every CRUD verb; try array/wildcard tricks. Mass-harvest with Burp Intruder.

## Payload arsenal
```
GET /my-account?id=carlos
GET /api/users/1234   (increment)        GET /download-transcript/1.txt
POST /api/order/555/cancel   (others' order ids)
# harvest IDs: author links, comments, /api/.../public, exports
```

## Bypasses
| Obstacle | Bypass |
|---|---|
| "unpredictable" id | find it on a public page / API / email |
| app redirects (302) | read the response body anyway |
| GUIDs | leaked references elsewhere; not a real control |

## Exploitation walkthrough (IDOR → ATO)
1. Account page `/my-account?id=wiener`; send to Repeater.
2. `id=administrator` → response contains the admin's password.
3. Log in as administrator → delete carlos → solved.

## Chaining
- IDOR password/API-key leak → [Vertical-privilege-escalation](../Vertical-privilege-escalation/) → admin.
- → [Authentication](../../Authentication/) (ATO), [Information-disclosure](../../Information-disclosure/).

## Tools
- **Burp Repeater/Intruder** (enumerate IDs), **Autorize** (auto IDOR detection across two sessions).

## Labs

### User ID controlled by request parameter [Apprentice]
URL: .../lab-user-id-controlled-by-request-parameter — `id=carlos` → his API key. Insight: no ownership check on `id`.

### ...with unpredictable user IDs [Apprentice]
URL: .../lab-user-id-controlled-by-request-parameter-with-unpredictable-user-ids — get carlos's GUID from his blog-author link, use it as `id`. Insight: unpredictable ≠ secret.

### ...with data leakage in redirect [Apprentice]
URL: .../lab-user-id-controlled-by-request-parameter-with-data-leakage-in-redirect — `id=carlos` 302s home but body holds his API key. Insight: read the redirect's body.

### ...with password disclosure [Apprentice]
URL: .../lab-user-id-controlled-by-request-parameter-with-password-disclosure — `id=administrator` → admin password in response → log in. Insight: horizontal IDOR → vertical.

### Insecure direct object references [Apprentice]
URL: .../lab-insecure-direct-object-references — live-chat transcript `/N.txt`; fetch `1.txt` → a password. Insight: predictable file references with no auth.

Real-target transfer: every id/filename/GUID in requests → swap to another user's; check redirect/error bodies; enumerate sequential refs.

## Real-world notes
- IDOR is the most common, highest-volume access-control bug in bounties; APIs/mobile back-ends are riddled with it.
- Always read full response bodies even on redirects/errors — data leaks there constantly.

## References
- https://portswigger.net/web-security/access-control/idor

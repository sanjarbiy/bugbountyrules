# Business logic - Unconventional / exceptional input

Applications fail to define server-side floors/ceilings on numeric inputs (allowing negative quantities) or fail to handle exceptional-length strings (truncating them at a database boundary), creating exploitable discrepancies between validation and storage.

## Quick reference
```
# Negative quantity (POST /cart)
POST /cart  productId=2&quantity=-100   -> deducts from cart total
# total = (jacket_price) + (-100 * cheap_price) -> can go below $100

# 255-char email truncation
target: admin access requires @dontwannacry.com
email column: VARCHAR(255)
craft: very-long-string@dontwannacry.com.YOUR-EMAIL-ID.web-security-academy.net
such that 'm' of @dontwannacry.com lands at position 255 exactly
-> DB stores truncated: ...@dontwannacry.com  (YOUR-EMAIL-ID part cut off)
-> confirmation goes to YOUR-EMAIL-ID (real), but stored as @dontwannacry.com (privileged)
```

## Root cause
- **Negative values:** no server-side `quantity > 0` check; arithmetic on signed integers produces negative totals.
- **Truncation:** email stored in VARCHAR(255); validation checks the full address (legit domain at end) but storage truncates, leaving only the privileged domain in the DB.

## Find it
**Negative input:**
1. Intercept `POST /cart`, try `quantity=-1`.
2. If cart total decreases -> no floor check on server.
3. Calculate how many negative units make total ≤ store credit.

**Email truncation:**
1. Register with a very long email (200+ chars) -> check "My account" to see if it was truncated.
2. Note truncation length (typically 255).
3. Craft email: `<filler>@dontwannacry.com.YOUR-EMAIL-ID.web-security-academy.net` where `filler` length + `@dontwannacry.com` length = 255 (the 'm' is at char 255).

## Technique
**Negative quantity:**
1. Add cheap item (e.g., $1 product) to cart.
2. Intercept `POST /cart` for that item, send to Repeater.
3. Set `quantity=-100` -> cart total drops by $100.
4. Add leather jacket ($1337) at normal price.
5. Tune negative quantity: `total = 133700 + quantity x cheap_price ≤ 10000`.
6. Submit with that negative quantity -> checkout.

**Email truncation:**
1. Discover `/admin` requires `@dontwannacry.com`.
2. Register with 200+ char email -> check "My account" -> confirm 255-char limit.
3. Calculate filler length: `255 - len("@dontwannacry.com") = 255 - 17 = 238` chars before the `@`.
4. Register: `Ax238@dontwannacry.com.YOUR-EMAIL-ID.web-security-academy.net`
5. Confirmation email arrives at `YOUR-EMAIL-ID` (real); stored email = `Ax238@dontwannacry.com`.
6. Log in -> `/admin` -> delete carlos.

## Payload arsenal
```bash
# Negative qty calculation (cheap item = $10 = 1000 cents):
# 1337 + qty*10 <= 100  ->  qty <= -123.7  ->  set qty = -124
POST /cart  productId=2&quantity=-124

# Email truncation (dontwannacry.com = 17 chars including @):
# Total prefix before @dontwannacry: 255 - 17 = 238 chars
python3 -c "print('A'*238 + '@dontwannacry.com.' + 'YOUR-EMAIL-ID.web-security-academy.net')"
```

## Bypasses
| Defense | Bypass |
|---|---|
| Client-side qty must be positive | Intercept POST, set negative directly |
| Email domain validation | Truncation: valid domain at start of "too-long" email gets cut to position 255 |
| "Must use company email" restriction | Register normally, then use email-change feature to switch to @privileged.com |

## Exploitation walkthrough
**Negative quantity (High-level logic):**
1. Add cheap item -> intercept POST /cart -> `quantity=-124` -> cart total = negative.
2. Add jacket normally -> total = $1337 - $124xprice_of_cheap.
3. Fine-tune until total < $100 store credit -> checkout.

**Email truncation (Inconsistent handling):**
1. Discover /admin path (content discovery tool in Burp -> "Engagement tools").
2. Register 200-char email -> confirm 255 truncation on My Account page.
3. Register: exactly 238 A's + `@dontwannacry.com.YOUR-EMAIL-ID.web-security-academy.net`.
4. Click confirmation link -> log in -> /admin -> delete carlos.

## Chaining
- Negative qty -> [Client-side-controls](../Client-side-controls/) (both manipulate cart math).
- Email truncation -> privilege escalation -> admin panel -> [Access-control](../../Access-control/).

## Tools
- **Burp Proxy + Repeater** - negative qty test
- **Burp content discovery** - find /admin path
- **Python one-liner** - calculate exact email string length

## Labs

### High-level logic vulnerability [Apprentice]
Intercept `POST /cart`, set `quantity=-100` on a cheap item to go negative. Add jacket. Tune negative qty so total < $100 store credit. Key insight: server has no floor on quantity - negative reduces total.

### Inconsistent handling of exceptional input [Practitioner]
Email field truncated at 255 chars. Craft registration email where `@dontwannacry.com` ends exactly at char 255; everything after (real domain) is silently dropped. Confirmation arrives at real address; stored email shows @dontwannacry.com -> admin access. Key insight: validation checks full address; storage truncates it.

## Real-world notes
- Negative numeric inputs (qty, amount, count) are a first-day check on any transactional endpoint.
- Email/username truncation at VARCHAR boundaries is a classic account-takeover primitive.
- Test any "unique" or "domain-restricted" field with inputs that are 1 char above the apparent DB limit.

## References
- https://portswigger.net/web-security/logic-flaws/examples#failing-to-handle-unconventional-input

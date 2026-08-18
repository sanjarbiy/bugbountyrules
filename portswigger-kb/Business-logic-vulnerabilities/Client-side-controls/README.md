# Business logic - Excessive trust in client-side controls

The server trusts price, quantity, or other security-critical values submitted by the client without server-side validation. Tampering these values in the request lets you buy items for $0, get unlimited quantity, or trigger integer overflow to make totals negative.

## Quick reference
```
# Price tamper (POST /cart)
POST /cart  price=0  qty=1   -> buy jacket for $0

# Negative quantity (POST /cart)
POST /cart  productId=2  quantity=-100  -> reduces cart total by 100x price

# Integer overflow (32-bit signed max = 2,147,483,647 cents = $21,474,836.47)
# overflow loop: keep adding qty=99 until total wraps negative
# precise: add jacket 323 times + 47 manually -> total = -$1221.96 (wins purchase check)
```

## Root cause
Client-side form validation only. Server accepts price/quantity directly from POST body without re-calculating against catalog. Integer arithmetic on 32-bit signed int can wrap to negative on overflow.

## Find it
1. Add any item to cart, intercept `POST /cart` - look for `price`, `quantity`, `discount` params.
2. Try setting `price=0` or `price=1` and add to cart - if total changes -> direct tamper.
3. Try `quantity=-1` - if cart total goes down -> negative qty accepted.
4. For integer overflow: keep adding `quantity=99` via Intruder (null payloads, indefinite) while watching cart total; when it wraps to large negative and starts climbing toward 0, calculate the precise quantity needed to land between $0 and your store credit.

## Technique
**Price tamper:**
1. Log in, add leather jacket.
2. Intercept `POST /cart`, change `price` to any value ≤ store credit.
3. Refresh cart -> total updated to your value.
4. Checkout -> solved.

**Negative quantity:**
1. Add cheap item to cart.
2. Intercept `POST /cart`, set `quantity=-100` -> cart total drops.
3. Add leather jacket at full price.
4. Adjust negative qty until total < store credit -> checkout.

**Integer overflow (32-bit):**
1. Intercept `POST /cart`, send to Intruder with `quantity=99`.
2. Null payloads -> Continue indefinitely -> Start; watch cart total in browser.
3. Total eventually flips to large negative (wraps at 2^31).
4. Stop, clear cart. Recalculate: leather jacket = 133700 cents. Need total ∈ [0, 10000].
   - 323 x 99 + 47 additional jackets -> total = -$1221.96 (under $100 credit after a filler item).
5. Intruder with exactly 323 payloads, max concurrent = 1. Then add 47 jackets manually.
6. Pad total into [$0, $100] range with a cheap item -> checkout.

## Payload arsenal
```
POST /cart
productId=1&quantity=1&price=0

POST /cart  (negative qty)
productId=2&quantity=-100

Intruder: POST /cart  productId=1&quantity=99  Null payloads x 323, concurrency=1
then: POST /cart  productId=1&quantity=47
then: POST /cart  productId=2&quantity=<padding>  (cheap item to bring total to $0-100)
```

## Bypasses
| Defense | Bypass |
|---|---|
| JS form validation on price | Intercept after browser sends; change before server receives |
| Hidden price field | Modify the param in Burp Repeater |
| "Qty must be positive" (client-side) | Intercept POST, set negative qty directly |
| Max quantity check (server) | Integer overflow - add in chunks of 99 until wrap |

## Exploitation walkthrough
**Lab 1 (price tamper):** intercept `POST /cart`, set `price=1`, refresh cart, checkout. Done.
**Lab 2 (int overflow):** Intruder (null payloads x 323, qty=99) -> total wraps to negative -> add 47 -> pad with cheap item -> checkout.

## Chaining
- Combine with [Workflow-state-flaws](../Workflow-state-flaws/) - tamper price then skip payment step.
- Integer overflow applicable to any 32-bit int field (funds transfer, bank balance).

## Tools
- **Burp Proxy** - intercept POST /cart
- **Burp Repeater** - change price param
- **Burp Intruder** - null payloads to trigger overflow (resource pool: max 1 concurrent)

## Labs

### Excessive trust in client-side controls [Apprentice]
Log in -> add jacket -> intercept `POST /cart` -> change `price` param to any value ≤ $100 store credit -> refresh cart -> checkout. Key insight: server uses client-submitted price, no server-side lookup.

### Low-level logic flaw [Practitioner]
Qty maxes at 2-digit per request. Intruder: null payloads x 323, qty=99, concurrency=1. Wait for total to wrap (32-bit int overflow -> negative). Then add 47 jackets + cheap padding item to land total in [0, $100]. Key insight: 32-bit signed integer wraps at 2,147,483,647 -> -2,147,483,648.

## Real-world notes
- Price tampering is extremely common in e-commerce - any `price` field in a POST is a target.
- Integer overflow bugs appear in loyalty points, inventory counts, and fund transfers on 32-bit stacks.
- Always check if price is re-fetched from DB or trusted from the client.

## References
- https://portswigger.net/web-security/logic-flaws/examples#excessive-trust-in-client-side-controls

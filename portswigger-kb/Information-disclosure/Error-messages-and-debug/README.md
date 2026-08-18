# Information disclosure - Error messages and debug pages

Verbose error responses, forgotten debug pages (phpinfo), and the HTTP TRACE method leak framework versions, environment variables, and internal headers - enabling CVE lookup, crypto bypass, and IP restriction bypass.

## Quick reference
```
# Trigger stack trace - send wrong type
GET /product?productId="abc"  ->  Apache Struts 2 2.3.31 in stack trace

# phpinfo via HTML comment
<!-- Debug link: /cgi-bin/phpinfo.php -->
GET /cgi-bin/phpinfo.php  ->  SECRET_KEY=<value>

# TRACE reveals forwarded headers
TRACE /admin  ->  X-Custom-IP-Authorization: <your-IP>
-> add to all requests: X-Custom-IP-Authorization: 127.0.0.1  -> admin bypass
```

## Root cause
- Error pages configured to verbose mode in production (default in many frameworks).
- phpinfo.php / debug endpoints left in web root from development.
- TRACE method enabled on server - echoes all request headers back (including internal proxy headers added after the browser).

## Find it
1. **Stack trace:** set any numeric param to a string (`productId="x"`) -> full stack trace reveals framework/version.
2. **Debug page:** Burp "Engagement tools -> Find comments" on home page -> look for `<!-- debug -->` style links -> browse to that path.
3. **TRACE:** send `TRACE /` or `TRACE /admin` in Repeater - if the response body echoes your request headers -> TRACE enabled. Look for internal headers (X-Forwarded-For, X-Custom-IP-Authorization, etc.).

## Technique
**Stack trace (error message):**
1. Find any GET param that expects an integer (productId, id, page).
2. Send `GET /product?productId="example"` - unexpected type triggers exception.
3. Read stack trace for framework name + version string.
4. CVE search for that exact version.

**phpinfo debug page:**
1. Burp "Find comments" -> spot `<a href="/cgi-bin/phpinfo.php">Debug</a>` in HTML comment.
2. GET /cgi-bin/phpinfo.php -> page contains all PHP config, env vars.
3. Ctrl+F `SECRET_KEY` (or `DB_PASSWORD`, `API_KEY`) -> extract.

**TRACE / IP bypass:**
1. `TRACE /admin` in Repeater -> observe `X-Custom-IP-Authorization: <your-external-IP>` in response.
2. Note the header name. Add a match/replace rule in Burp Proxy:
   - Type: Request header | Match: (empty) | Replace: `X-Custom-IP-Authorization: 127.0.0.1`
3. Every subsequent request now includes that header -> admin panel accessible.
4. Browse to /admin -> delete carlos.

## Payload arsenal
```http
# Stack trace trigger
GET /product?productId="example" HTTP/1.1

# TRACE
TRACE /admin HTTP/1.1
Host: TARGET

# Burp Match/Replace -> Request header
Replace: X-Custom-IP-Authorization: 127.0.0.1
```

## Bypasses
| Defense | Bypass |
|---|---|
| Admin requires local IP | TRACE reveals IP header name; spoof it with 127.0.0.1 |
| Error page generic ("An error occurred") | Try different wrong types; some params more verbose than others |

## Exploitation walkthrough
**Error messages:** `GET /product?productId="example"` -> response body contains `Apache Struts 2 2.3.31` -> submit as answer.

**Debug page:** Find comments -> `/cgi-bin/phpinfo.php` -> Ctrl+F SECRET_KEY -> extract -> submit.

**Auth bypass via TRACE:**
1. `TRACE /admin` -> see `X-Custom-IP-Authorization: x.x.x.x`.
2. Proxy -> Match/Replace -> add `X-Custom-IP-Authorization: 127.0.0.1`.
3. Browse home -> admin panel now visible -> delete carlos.

## Chaining
- Framework version -> CVE -> RCE (critical escalation).
- SECRET_KEY -> forge signed tokens / cookies -> [Authentication](../../Authentication/).
- TRACE IP bypass -> admin panel -> [Access-control](../../Access-control/).

## Tools
- **Burp Proxy "Match and Replace"** - inject TRACE-discovered headers into every request
- **Burp "Find comments"** - surface debug links in HTML
- **Burp Repeater** - send TRACE, wrong-type params

## Labs

### Information disclosure in error messages [Apprentice]
`GET /product?productId="example"` triggers stack trace -> reveals `Apache Struts 2 2.3.31`. Key insight: wrong data type = exception = verbose error = framework fingerprint.

### Information disclosure on debug page [Apprentice]
Burp "Find comments" -> HTML comment contains `/cgi-bin/phpinfo.php` -> open page -> extract `SECRET_KEY` env var. Key insight: debug pages left in production expose full PHP config including secrets.

### Authentication bypass via information disclosure [Apprentice]
TRACE /admin -> reveals `X-Custom-IP-Authorization` header used for IP check. Add match/replace rule in Burp: `X-Custom-IP-Authorization: 127.0.0.1` -> admin panel accessible. Key insight: TRACE echoes internal proxy headers; knowing the header name lets you spoof it.

## Real-world notes
- Always send TRACE to any IP-restricted endpoint - the header name that the proxy injects is often non-obvious without this.
- phpinfo.php in production is a top-10 bug bounty find - it reveals every config value, session path, and env var.
- Stack traces fingerprint the exact framework version for rapid CVE lookup.

## References
- https://portswigger.net/web-security/information-disclosure/exploiting

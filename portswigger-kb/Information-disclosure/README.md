# Information disclosure - topic overview & router

A website unintentionally reveals sensitive data: stack traces with framework versions, debug pages with env vars, backup source files with hardcoded DB passwords, or exposed `.git` directories with secrets in commit history. Alone it's recon; chained it unlocks direct exploitation.

## 30-second quick reference

```
# Common sources to always check
GET /robots.txt             -> reveals hidden dirs
GET /backup/ , /.git/       -> source code, credentials in diffs
GET /cgi-bin/phpinfo.php    -> env vars, SECRET_KEY
HTML source -> <!-- ... --> -> debug links
Error pages -> stack trace  -> framework + version (-> known CVE)

# TRACE method reveals internal headers
TRACE /admin  -> X-Custom-IP-Authorization: <your-ip>  -> add 127.0.0.1 header -> admin bypass

# .git exposure
wget -r https://TARGET/.git/
git log --oneline
git show <commit>           -> see removed passwords in diff
```

## Decision map

| What you find | Sub-technique | Next step |
|---|---|---|
| Error message with framework/version | [Error-messages-and-debug](Error-messages-and-debug/) | search CVE for that version |
| Debug page (phpinfo, stack trace) | [Error-messages-and-debug](Error-messages-and-debug/) | extract SECRET_KEY / env vars |
| TRACE reveals internal header | [Error-messages-and-debug](Error-messages-and-debug/) | add header = 127.0.0.1 -> admin bypass |
| /robots.txt -> /backup/ | [Exposed-files](Exposed-files/) | read .bak source for hardcoded creds |
| /.git accessible | [Exposed-files](Exposed-files/) | wget -r -> git log -> find removed secrets |

## Sub-technique folders
- `Error-messages-and-debug/` - verbose errors, phpinfo debug pages, TRACE method (3 labs)
- `Exposed-files/` - robots.txt/backup source files, exposed .git history (2 labs)

## Root cause
Information is disclosed when apps reveal more than they should: verbose error handling, forgotten debug code left in production, backup files in web root, VCS directories served over HTTP.

## Find it
- Always start with: `robots.txt`, HTML comments, `.git`, `/backup`, `/cgi-bin/phpinfo.php`
- Send `TRACE /` - do internal headers appear in the response?
- Submit wrong types to params (`productId=abc`) - does a stack trace appear?
- Burp "Find comments" (engagement tools) on home page

## Chaining
- Stack trace -> framework version -> known CVE -> RCE
- phpinfo SECRET_KEY -> cryptographic bypass
- Backup file -> hardcoded DB creds -> direct DB access / [SQL-injection](../SQL-injection/)
- /.git -> admin password in diff -> account takeover -> [Access-control](../Access-control/)
- TRACE header -> bypass IP restriction -> admin panel

## Tools
- **Burp "Find comments"** - HTML comments with debug links
- **Burp content discovery** - /backup, /cgi-bin paths
- **`wget -r /.git/`** - recursive dump of git directory
- **`git log --oneline`**, **`git show <hash>`** - inspect removed secrets

## References
- https://portswigger.net/web-security/information-disclosure
- https://portswigger.net/web-security/information-disclosure/exploiting

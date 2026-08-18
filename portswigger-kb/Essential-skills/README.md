# Essential skills - topic overview & router

Core recon and scanning techniques that underpin all other attacks: targeted Burp scanning on specific insertion points, and scanning non-standard data structures (structured cookies, binary formats). These skills accelerate vulnerability discovery across all topics.

## 30-second quick reference

```
# Targeted scan on a specific insertion point
Burp Proxy HTTP history -> right-click param value -> "Scan selected insertion point"
-> Burp active-scans only that param (not the whole site)

# Non-standard data structure in a cookie
session=wiener:abc123token   <- colon-delimited: username + token
-> Select "wiener" in HTTP history -> right-click -> "Scan selected insertion point"
-> Burp finds SQLi/SSTI/XSS/etc. in the username sub-field
```

## Sub-technique folders
- `Targeted-scanning/` - Burp Scanner on specific params + non-standard structures (2 labs)

## Find it
- Any parameter with embedded structure (colon, pipe, base64, JSON inside cookie/header).
- Select just the interesting sub-component and scan it.

## Tools
- **Burp Scanner "Scan selected insertion point"** - focused active scan on one param value

## References
- https://portswigger.net/web-security/essential-skills

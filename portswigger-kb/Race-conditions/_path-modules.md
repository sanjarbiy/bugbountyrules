# Race conditions — learning path, full module walk (0 → end)

Walked live via CONTINUE to "You've completed Race conditions" (29 units). Module content = the topic article (single page) sequenced; distilled into the sibling sub-technique folders.

## Module sequence (29 units) → distilled folder
1. **Race conditions** (intro: race window, TOCTOU) → README
2–3. **Limit overrun race conditions** (coupon-reuse example, sub-states) → Limit-overrun
4–5. **Detecting/exploiting limit overrun with Burp Repeater** (single-packet attack h2 / last-byte-sync h1, send group in parallel) → Limit-overrun
6. **Lab: Limit overrun** → Limit-overrun
7–8. **Detecting/exploiting with Turbo Intruder** (`Engine.BURP2`, gates, openGate) → Limit-overrun
9. **Lab: Bypassing rate limits** → Limit-overrun
10–11. **Hidden multi-step sequences** (sub-states, MFA race example) → Multi-and-single-endpoint
12. **Methodology** (overview) → README / Multi-and-single-endpoint
13. **1 – Predict potential collisions** (same-record requirement) → Multi-and-single-endpoint (Find it)
14. **2 – Probe for clues** (benchmark sequence vs parallel) → Multi-and-single-endpoint (Find it)
15. **3 – Prove the concept** → Multi-and-single-endpoint (Find it)
16. **Multi-endpoint race conditions** (add-to-cart vs checkout window) → Multi-and-single-endpoint
17. **Aligning multi-endpoint race windows** (network + endpoint delays) → Multi-and-single-endpoint
18. **Connection warming** (prepend GET /, single connection) → Multi-and-single-endpoint
19. **Lab: Multi-endpoint** → Multi-and-single-endpoint
20. **Abusing rate or resource limits** (induce server-side delay) → Multi-and-single-endpoint
21–22. **Single-endpoint race conditions** (password-reset session collision) → Multi-and-single-endpoint
23. **Lab: Single-endpoint** → Multi-and-single-endpoint
24. **Session-based locking mechanisms** (PHP 1-req/session; use different session tokens) → Multi-and-single-endpoint
25–26. **Partial construction race conditions** (uninitialized field; PHP `param[]=`, Rails `param[key]`) → Time-sensitive-and-partial-construction
27. **Time-sensitive attacks** (timestamp-seeded tokens collide) → Time-sensitive-and-partial-construction
28. **Lab: Exploiting time-sensitive vulnerabilities** → Time-sensitive-and-partial-construction
29. **How to prevent race conditions** (atomic transactions, uniqueness constraints, no cross-store security, client-side state via JWT) → README / per-folder Real-world notes

**Path walked 0 → end: 29/29 → "You've completed Race conditions".** Topic is a single article (no separate sub-pages). All 6 labs covered in the sub-technique folders' `## Labs` sections.

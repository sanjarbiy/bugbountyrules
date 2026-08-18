# SSRF - learning path, full module walk (0 -> end)

Walked live via CONTINUE to "You've completed SSRF attacks" (23 units). Module content = the SSRF topic article + blind sub-page sequenced; distilled into the sub-technique folders.

## Module sequence (23 units) -> folder
1. What is SSRF? -> README
2. Impact -> README
3. Common SSRF attacks -> README
4-5. SSRF against the server (localhost/admin, trust relationships) -> Basic
6. Lab: Basic SSRF against localhost -> Basic
7. SSRF against other back-end systems (internal IPs) -> Basic
8. Lab: Basic SSRF against back-end system -> Basic
9. Circumventing common SSRF defenses -> Filter-bypass
10. SSRF with blacklist filters (alt IP reps, encoding) -> Filter-bypass
11. Lab: Blacklist filter -> Filter-bypass
12. SSRF with whitelist filters (`@`,`#`, parser confusion) -> Filter-bypass
13. Bypassing SSRF filters via open redirection -> Filter-bypass
14. Lab: Filter bypass via open redirection -> Filter-bypass
15. Blind SSRF vulnerabilities -> Blind
16. Impact of blind SSRF -> Blind
17-18. How to find/exploit blind SSRF (OAST, DNS-only note, escalation) -> Blind
19. Lab: Blind SSRF out-of-band detection -> Blind
20. Finding hidden attack surface -> README (Find it)
21. Partial URLs in requests -> README (Find it)
22. URLs within data formats (XML->XXE->SSRF) -> README (Find it) / XXE-injection
23. SSRF via the Referer header -> Blind / README (Find it)

(The whitelist-filter lab and Shellshock lab are Expert extras covered in Filter-bypass/Blind; this path's linear flow includes the 3 core labs + blind OOB. All 7 labs covered across the folders.)

**Path walked 0 -> end: 23/23 -> "You've completed SSRF attacks".** All 7 labs covered in the sub-technique folders' `## Labs` sections.

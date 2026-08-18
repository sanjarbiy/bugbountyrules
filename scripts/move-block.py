#!/usr/bin/env python3
"""Move a block out of SKILL.md into a reference file, VERBATIM.

Progressive disclosure done safely: the block is cut from SKILL.md and appended
unchanged to the target reference file, and a pointer line takes its place. The
text is never rewritten, so `scripts/no-loss-check.sh verify` stays green.

    move-block.py <target-ref.md> "<start line, exact prefix>" "<end marker>" "<pointer text>"

<end marker> is the exact prefix of the first line that must NOT be moved.
Nothing is written unless both markers resolve to exactly one place.
"""
import sys, os, re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SKILL = os.path.join(ROOT, "SKILL.md")


def toc_gaps(path):
    """Report '## ' sections missing from a file's Contents list. NEVER writes.

    A moved block absent from Contents is a block nobody finds, so this must be
    checked. But it is only ever REPORTED, never auto-fixed: a Contents entry is
    free prose that may describe a level-3 section in words matching no heading
    ("Observation -> vector catalogue" for a section titled "If->Then->Try
    catalogue"). Any rule confident enough to rewrite that list is confident
    enough to delete a good entry - which is how this file lost one. Print the
    gap and let a human place it.
    """
    lines = open(path, encoding="utf-8").read().splitlines()
    try:
        c = next(i for i, l in enumerate(lines) if l.strip() == "## Contents")
    except StopIteration:
        return []
    end = next((i for i in range(c + 1, len(lines))
                if lines[i].startswith("## ") or lines[i].startswith("---")), len(lines))
    listed = " ".join(l.lower() for l in lines[c + 1:end] if l.startswith("- "))
    gaps = []
    for l in lines:
        if l.startswith("## ") and l.strip() != "## Contents":
            title = l[3:].strip().rstrip(":")
            if title.split(":")[0].strip().lower() not in listed:
                gaps.append(title)
    return gaps


def main():
    if len(sys.argv) == 3 and sys.argv[1] == "--toc-gaps":
        g = toc_gaps(os.path.join(ROOT, sys.argv[2]))
        print(f"  {sys.argv[2]}: " + ("Contents complete" if not g
              else f"{len(g)} section(s) NOT in Contents - add by hand:"))
        for t in g:
            print(f"      - {t}")
        return
    if len(sys.argv) != 5:
        print(__doc__); sys.exit(2)
    ref, start_pfx, end_pfx, pointer = sys.argv[1:5]
    refp = os.path.join(ROOT, ref)
    if not os.path.exists(refp):
        sys.exit(f"no such reference file: {refp}")

    lines = open(SKILL, encoding="utf-8").read().splitlines(True)
    starts = [i for i, l in enumerate(lines) if l.startswith(start_pfx)]
    if len(starts) != 1:
        sys.exit(f"start marker matched {len(starts)} lines, need exactly 1: {start_pfx!r}")
    s = starts[0]
    ends = [i for i, l in enumerate(lines) if i > s and l.startswith(end_pfx)]
    if not ends:
        sys.exit(f"end marker never found after start: {end_pfx!r}")
    e = ends[0]

    block = lines[s:e]
    # keep the skill tidy: do not carry trailing blank lines into the reference
    while block and not block[-1].strip():
        block.pop()
    if not block:
        sys.exit("block resolved to nothing")

    # A block that starts with a heading keeps it. A block that starts with a
    # PARAGRAPH must not become a paragraph-length heading - that pollutes the
    # file and every Contents list generated from it.
    if block[0].lstrip().startswith("#"):
        title = block[0].lstrip("#").strip()
    else:
        plain = re.sub(r"\*\*|\*|`", "", block[0]).strip()
        title = (plain[:57].rsplit(" ", 1)[0] + "...") if len(plain) > 60 else plain
    title = title or "moved block"
    with open(refp, "a", encoding="utf-8") as f:
        f.write("\n\n---\n\n## " + re.sub(r"^#+\s*", "", title) + "\n"
                "*Moved verbatim from SKILL.md - the mandate stays there, the worked detail lives here.*\n\n")
        f.writelines(block if not block[0].startswith("#") else block[1:])
        f.write("\n")

    lines[s:e] = [pointer.rstrip() + "\n", "\n"]
    open(SKILL, "w", encoding="utf-8").write("".join(lines))
    print(f"  moved {len(block)} lines -> {ref}   (SKILL.md now {len(lines)} lines)")
    for t in toc_gaps(refp):   # report, do not touch - see toc_gaps docstring
        print(f"  ADD TO {ref} Contents BY HAND:  - {t}")


if __name__ == "__main__":
    main()

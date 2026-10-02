"""
p10_combat_tags.py - where does FFXiMain.dll reference the combat hit-effect fourccs?

The Kuluu side assumed a normal melee hit resolves victim `damg` -> 0x09 `chit` on the
attacker -> weapon DAT `ef h` -> global-dir `hit1`. This scanner finds every code and data
reference to those tags (and their crit/spell neighbours) in the retail binary so the real
combat chain can be read out of it.

    python p10_combat_tags.py %DLL% [--window 24] > out3\p10.md

Prints markdown: per tag, data-section literal sites and .text immediate-operand sites with a
disassembled window around each code site (the containing function start is named so the
handler can be dumped separately).
"""
from __future__ import annotations

import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import Image, fourcc_str, sweep_text  # noqa: E402

# The tags the Kuluu hit-flash chain is built from, plus neighbours for context.
TAGS = [
    "hit1", "hit2", "chit", "damg", "ldam", "lhit",
    "eflg", "selg", "sho1", "dada", "ef h",
    "lvup", "mdam", "sdam",
]


def fourcc(tag: str) -> int:
    b = tag.encode("ascii")[:4].ljust(4, b"\x00")
    return int.from_bytes(b, "little")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("dll")
    ap.add_argument("--window", type=int, default=24, help="instructions each side of a code hit")
    args = ap.parse_args()

    img = Image(args.dll)
    print(img.describe())
    sweep = sweep_text(img)
    sweep.index()

    for tag in TAGS:
        val = fourcc(tag)
        needle = tag.encode("ascii")[:4].ljust(4, b"\x00")
        data_hits = img.find_bytes(needle)
        code_hits = [i for i in sweep.insns if val in i.imms]

        print(f"\n## `{tag}` (0x{val:08X})\n")
        print(f"data literal sites ({len(data_hits)}): " +
              ", ".join(f"0x{r:X}" for r in data_hits[:40]) +
              (" ..." if len(data_hits) > 40 else ""))
        print(f"\ncode immediate sites ({len(code_hits)}):\n")
        seen_funcs = {}
        for i in code_hits:
            fstart = sweep.func_of(i.rva)
            seen_funcs.setdefault(fstart, []).append(i.rva)
        for fstart, rs in sorted(seen_funcs.items()):
            fend = sweep.func_range(fstart)[1]
            print(f"### func 0x{fstart:X} (ends ~0x{fend:X}) — sites: " +
                  ", ".join(f"0x{r:X}" for r in rs) + "\n")
            # One window around the first site of this function.
            n = sweep.insn_at(rs[0])
            lo, hi = max(0, n - args.window), min(len(sweep.insns), n + args.window + 1)
            for j in range(lo, hi):
                ins = sweep.insns[j]
                mark = ">>" if ins.rva == rs[0] else "  "
                print(f"{mark} 0x{ins.rva:06X}: {ins.mn:<8} {ins.ops}")


if __name__ == "__main__":
    main()

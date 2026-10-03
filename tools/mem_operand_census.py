#!/usr/bin/env python3
"""Census of every .text instruction touching a [reg + disp] memory operand.

Uses the cached full linear sweep (common.sweep_text), so it is fast to re-run and reusable for
any field-offset question (writer xrefs, gate reads, etc.). Matching uses capstone's structured
memory operands (base/index/disp/size), not string guesses. Classification is heuristic on
operand position: cmp/test/push never write; lea computes an address; otherwise a memory operand
in first position counts as a write.

    python tools/mem_operand_census.py --dll C:\\tmp\\ffximain_work\\FFXiMain.unpacked.dll \
        --disp 0xB2 [--base-any] [--mnemonics mov,or,and] [--size-bytes 1] [--group-funcs] [--context 2]

For absolute-address operands (globals), the base prints as <abs>: pass --base-none to restrict.
"""
import argparse
import os
import sys
from collections import Counter

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from common import Image, sweep_text  # noqa: E402

READ_ONLY = {"cmp", "test"}


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dll", required=True)
    ap.add_argument("--disp", required=True)
    ap.add_argument("--mnemonics", default="")
    ap.add_argument("--size-bytes", type=int, default=0, help="1/2/4; 0 = any operand size")
    ap.add_argument("--base-none", action="store_true", help="absolute-address operands only")
    ap.add_argument("--index-none", action="store_true", default=True)
    ap.add_argument("--group-funcs", action="store_true")
    ap.add_argument("--context", type=int, default=0)
    args = ap.parse_args()

    disp = int(args.disp, 16) if args.disp.lower().startswith("0x") else int(args.disp)
    restrict = {m.strip().lower() for m in args.mnemonics.split(",")} if args.mnemonics else None

    img = Image(args.dll)
    sw = sweep_text(img)

    def mem_hits(ins):
        out = []
        parts = [p.strip() for p in ins.ops.split(",")]
        for (base, index, d, sz) in ins.mems:
            if d != disp:
                continue
            if args.base_none and base:
                continue
            if not args.base_none and base == "" and index == "":
                pass  # absolute; allow unless caller restricted with --mnemonics anyway
            if args.index_none and index:
                continue
            if args.size_bytes and sz not in (args.size_bytes, 0):
                continue
            idx = next((i for i, p in enumerate(parts) if f"+ 0x{d:x}]" in p or f"[{base} + 0x{d:x}]" in p), None)
            out.append((idx, base))
        return out

    def classify(ins, part_idx):
        if ins.mn == "lea":
            return "L"
        if ins.mn in READ_ONLY:
            return "R"
        if ins.mn in ("push", "call"):
            return "R"
        if restrict and ins.mn not in restrict:
            return None
        if restrict is None and part_idx not in (None, 0) and ins.mn.startswith("mov"):
            return "R"
        return "W"

    hits = []
    for i in sw.insns:
        if restrict and i.mn not in restrict:
            continue
        for (part_idx, base) in mem_hits(i):
            side = classify(i, part_idx)
            if side is None:
                continue
            hits.append((i, side))

    if args.group_funcs:
        c = Counter(sw.func_of(i.rva) for (i, _s) in hits)
        for f, n in sorted(c.items(), key=lambda kv: (-kv[1], kv[0])):
            print(f"func {f:#08x}  {n}")
    print(f"# total hits: {len(hits)}")
    insns = sw.insns
    for (h, side) in hits:
        lo = max(0, sw.by_rva[h.rva] - args.context)
        hi = min(len(insns), sw.by_rva[h.rva] + args.context + 1)
        if args.context and sw.insns[lo] is not h:
            print("  ---")
        for k in range(lo, hi):
            i2 = insns[k]
            mark = "*" if i2.rva == h.rva else " "
            tag = side if i2.rva == h.rva else ""
            print(f"{mark}{i2.rva:#08x} {tag:2s} {i2.mn:7s} {i2.ops}")


if __name__ == "__main__":
    main()

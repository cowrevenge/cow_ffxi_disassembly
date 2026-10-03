#!/usr/bin/env python3
"""Find stores `[reg + disp] = ...` that follow a load of one absolute global into the same register.

Answers "who writes this field of the object this singleton points at" without knowing the class:
sweep linearly, note which register each `mov reg, [global]` leaves holding the pointer, then report
writes to `[reg + disp]` within a short window. Narrow with --window if a query is noisy.

    python tools/store_after_global_load.py \
        --dll C:/tmp/ffximain_work/FFXiMain.unpacked.dll \
        --global 0x104568FC --disp 0x28 [--window 24] [--show 3]

Uses the cached full sweep (common.sweep_text). Registers are matched by their capstone text, and
the write check requires the `[reg + disp]` operand to sit in destination position.
"""
import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from common import Image, sweep_text  # noqa: E402


def split_ops(ins):
    """Operand texts, splitting only on commas outside brackets (so ` dword ptr [a + b]` survives)."""
    out, depth, cur = [], 0, ""
    for ch in ins.ops or "":
        if ch == "," and depth == 0:
            out.append(cur.strip())
            cur = ""
            continue
        if ch in "([":
            depth += 1
        elif ch in ")]":
            depth -= 1
        cur += ch
    if cur.strip():
        out.append(cur.strip())
    return out


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dll", required=True)
    ap.add_argument("--global", dest="global_va", required=True,
                    help="VA/RVA of the global whose value is a pointer")
    ap.add_argument("--disp", required=True, help="field displacement to look for")
    ap.add_argument("--window", type=int, default=24, help="instructions after the load to inspect")
    ap.add_argument("--show", type=int, default=3, help="context instructions before/after each hit")
    ap.add_argument("--same-region", action="store_true",
                    help="also report writes to [any reg + disp] inside a sweep region that loads the "
                         "global at all (looser than the register pairing; catches stores made through "
                         "a copy of the pointer)")
    args = ap.parse_args()

    gval = int(args.global_va, 16) if args.global_va.lower().startswith("0x") else int(args.global_va)
    disp = int(args.disp, 16) if args.disp.lower().startswith("0x") else int(args.disp)

    img = Image(args.dll)
    sw = sweep_text(img)
    insns = sw.insns

    def load_dest_reg(ins):
        """Register that `ins` loads the absolute global into, or None."""
        if not any(d == gval and not base and not index for (base, index, d, _s) in ins.mems):
            return None
        ops = split_ops(ins)
        if len(ops) != 2:
            return None
        dst = ops[0]
        if "[" in dst:  # store direction: memory is the destination, no pointer register produced
            return None
        return dst

    def field_write_base_reg(ins):
        """Base register of a destination-position `[reg + disp]` operand, or None."""
        ops = split_ops(ins)
        # cmp/test read both sides; fld loads the field onto the FPU stack rather than writing it
        if not ops or ins.mn in ("cmp", "test", "fld"):
            return None
        for (base, index, d, _s) in ins.mems:
            if d != disp or not base or index:
                continue
            # the operand text that names this field, and whether it is the destination
            named = [o for o in ops if f"+ 0x{disp:x}]" in o.lower()]
            if named and named[0] == ops[0]:
                return base
        return None

    holder = {}
    hits = []
    by_rva = {ins.rva: k for k, ins in enumerate(insns)}
    for k, ins in enumerate(insns):
        if (reg := load_dest_reg(ins)):
            holder[reg.lower()] = ins.rva
        if not (base := field_write_base_reg(ins)):
            continue
        origin = holder.get(base.lower())
        if origin is None:
            continue
        dist = k - by_rva[origin]
        if dist > args.window:
            continue
        hits.append((ins.rva, origin, dist))

    if args.same_region:
        seeds = sorted(getattr(sw, "func_starts", []) or [])
        loads_at = [ins.rva for ins in insns
                    if any(d == gval and not base and not index
                           for (base, index, d, _s) in ins.mems)]

        def region_of(rva):
            import bisect
            i = bisect.bisect_right(seeds, rva)
            return (seeds[i - 1], seeds[i]) if i else (0, seeds[0] if seeds else 0)

        regions = {region_of(r) for r in loads_at}
        print(f"# --same-region: global loaded in {len(regions)} sweep regions")
        for k, ins in enumerate(insns):
            if not field_write_base_reg(ins):
                continue
            if region_of(ins.rva) not in regions:
                continue
            lo, hi = region_of(ins.rva)
            print(f"\nregion {lo:08X}..{hi:08X} writes [reg + 0x{disp:x}] at {ins.rva:08X}:  "
                  f"{ins.mn} {ins.ops}")
        return

    print(f"# {len(hits)} store sites to [reg + 0x{disp:x}] armed by a load of global 0x{gval:x}")
    for rva, origin, dist in hits:
        k = by_rva[rva]
        print(f"\nstore {rva:08X} (armed at {origin:08X}, {dist} insns before):")
        for j in range(max(0, k - args.show), min(len(insns), k + args.show + 1)):
            it = insns[j]
            mark = ">>" if j == k else "  "
            print(f"   {mark} {it.rva:08X}  {it.mn:<7} {it.ops}")


if __name__ == "__main__":
    main()

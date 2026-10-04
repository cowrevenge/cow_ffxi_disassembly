#!/usr/bin/env python3
"""espmap.py - print [esp+N] operands at their frame-stable offset.

MSVC addresses locals through `[esp+N]` after every argument push, so the same variable appears under a
different alias at each point in a block and reads of it drift when pushes are counted by eye. This maps
each one back to the entry frame `f` (caller args at f+4, f+8...; locals below) and applies each direct
call's `ret N` cleanup, which is what deferred MSVC epilogues require. A callee whose later `ret`s
disagree gets flagged rather than assumed.

Usage:
  python espmap.py C:/tmp/ffximain_work/FFXiMain.unpacked.dll --rva 0x2ac60 [--end 0x2af90 | --len 0x330]
"""
import argparse

from common import Image, sweep_text, parse_int


def ret_imm(sw, target):
    """Stack bytes the callee pops at its first `ret` after `target`, plus any later returns that
    disagree (the sweep can merge neighbouring functions, which is where disagreement comes from)."""
    first = None
    others = set()
    for ins in sw.iter_range(target, target + 0x800):
        if ins.mn == "ret":
            v = int(ins.ops.strip(), 0) if ins.ops.strip() else 0
            if first is None:
                first = v
            elif v != first:
                others.add(v)
    return first, others


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("dll")
    ap.add_argument("--cache", default=".cache")
    ap.add_argument("--rva", type=parse_int, required=True)
    ap.add_argument("--end", type=parse_int)
    ap.add_argument("--len", type=parse_int)
    args = ap.parse_args()

    img = Image(args.dll)
    sw = sweep_text(img, args.cache)
    start = args.rva
    end = args.end if args.end is not None else (start + args.len if args.len
                                                 else sw.func_range(sw.func_of(start))[1])

    d = 0
    memo = {}
    for ins in sw.iter_range(start, end):
        notes = []
        for base, _idx, disp, _sz in ins.mems:
            if base == "esp":
                foff = d + disp
                where = (f"f+0x{foff:X}=arg{(foff - 4) // 4}" if foff >= 4
                         else (f"f{foff:#x}" if foff else "f(retaddr)"))
                notes.append(f"[esp{disp:+#x}] -> {where}")
            elif base == "ebp":
                notes.append(f"[ebp{disp:+#x}] frameptr")
        ops = ins.ops.replace(" ", "")
        if ins.mn.startswith("push"):
            d -= 4 * (ins.ops.count(",") + 1)
        elif ins.mn.startswith("pop"):
            d += 4 * (ins.ops.count(",") + 1)
        elif ops.startswith("esp,") and ins.mn in ("sub", "add"):
            try:
                n = int(ops.split(",", 1)[1], 0)
                d += -n if ins.mn == "sub" else n
            except ValueError:
                notes.append("!! non-constant esp adjust")
        if ins.mn == "call" and ins.call_target is not None:
            t = ins.call_target
            if t not in memo:
                memo[t] = ret_imm(sw, t)
            popped, disagree = memo[t]
            if isinstance(popped, int):
                d += popped
                note = f"callee pops {popped:#x}"
                if disagree:
                    note += f" !! other rets {sorted(hex(v) for v in disagree)}"
                notes.append(note)
        tail = ("   ; " + "; ".join(dict.fromkeys(notes))) if notes else ""
        print(f"{ins.rva:08X}  d={d:+#x}  {ins.mn} {ins.ops}{tail}")


if __name__ == "__main__":
    main()

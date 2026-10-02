#!/usr/bin/env python3
"""
xref.py - who calls/references an RVA, and what a function calls.

Usage:
  python xref.py FFXiMain.dll --to 0x12345          callers/jumps to this rva (rounded to its function)
  python xref.py FFXiMain.dll --from 0x12345        every call/jmp target inside the function containing rva
  python xref.py FFXiMain.dll --imm 0x04DF0F40      instructions using this immediate (e.g. a vtable VA or fourcc)
  python xref.py FFXiMain.dll --disp 0x11E [--size 2]   instructions with a memory operand at this displacement
  python xref.py FFXiMain.dll --tree 0x12345 --depth 3  caller tree upward
Options: --cache .cache
"""
import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import Image, dump_context, fmt_insn, h, parse_int, sweep_text  # noqa: E402


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("dll")
    ap.add_argument("--cache", default=".cache")
    ap.add_argument("--to", type=parse_int)
    ap.add_argument("--from", dest="frm", type=parse_int)
    ap.add_argument("--imm", type=parse_int)
    ap.add_argument("--disp", type=parse_int)
    ap.add_argument("--size", type=int, default=0)
    ap.add_argument("--tree", type=parse_int)
    ap.add_argument("--depth", type=int, default=3)
    ap.add_argument("--ctx", type=int, default=3)
    args = ap.parse_args()
    img = Image(args.dll)
    sw = sweep_text(img, args.cache)

    if args.to is not None:
        f = sw.func_of(args.to)
        refs = sw.refs_to(f) + ([] if f == args.to else sw.refs_to(args.to))
        print(f"references to {h(args.to)} (func {h(f)}): {len(refs)}")
        for r in refs:
            print(f"- {h(r.rva)} in func {h(sw.func_of(r.rva))}\n" + dump_context(img, sw, r.rva, args.ctx, args.ctx))
    if args.frm is not None:
        f = sw.func_of(args.frm)
        s, e = sw.func_range(f)
        print(f"calls/jumps out of func {h(f)}..{h(e)}:")
        seen = set()
        for i in sw.iter_range(s, e):
            if i.call_target is not None and i.mn == "call" and i.call_target not in seen:
                seen.add(i.call_target)
                print(f"- {h(i.rva)} call {h(i.call_target)}")
    if args.imm is not None:
        sites = [i for i in sw.insns if args.imm in i.imms]
        print(f"instructions with imm 0x{args.imm:X}: {len(sites)}")
        for i in sites[:60]:
            print(f"- {h(i.rva)} in func {h(sw.func_of(i.rva))}\n" + dump_context(img, sw, i.rva, args.ctx, args.ctx))
    if args.disp is not None:
        sites = [i for i in sw.insns if any(d == args.disp and (args.size == 0 or s == args.size) for b, x, d, s in i.mems)]
        funcs = {}
        for i in sites:
            funcs.setdefault(sw.func_of(i.rva), []).append(i)
        print(f"memory operands with disp 0x{args.disp:X}: {len(sites)} sites in {len(funcs)} funcs")
        for f, lst in sorted(funcs.items(), key=lambda kv: -len(kv[1]))[:60]:
            print(f"- func {h(f)} ({len(lst)}): " + " | ".join(f"{h(i.rva)} {i.mn} {i.ops}" for i in lst[:4]))
    if args.tree is not None:
        def walk(f, depth, seen):
            if depth < 0 or f in seen:
                return
            seen.add(f)
            callers = sw.callers_of(f)
            print("  " * (args.depth - depth) + f"{h(f)}  <- {len(callers)} caller(s)")
            for c in callers[:8]:
                walk(sw.func_of(c.rva), depth - 1, seen)
        walk(sw.func_of(args.tree), args.depth, set())


if __name__ == "__main__":
    main()

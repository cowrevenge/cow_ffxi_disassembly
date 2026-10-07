#!/usr/bin/env python3
"""
p3_gates.py - Phase 3 probes for the destroy/create gating gap and the sub-change consumer
(plan §4.1 handoff items 0-2, H3). Uses YOUR common.py (POL1-decoding Image + cached sweep).

Usage:
  python p3_gates.py FFXiMain.dll [--cache .cache] [--routine 0x8F750:0x926C7] [--handler 0x9BCF7] [--create 0x8F7FF]

Prints markdown for §9:
  G1  read-modify-write setters of RenderFlags3 (+0x12C) bit 0 and bit 23 (or/xor/and/bts...);
      the F35 scan counted `mov` stores only, so `or byte [reg+0x12C],1` was invisible to it
  G2  packed-status tests on RenderFlags0 (+0x120) inside the update routine, esp. before the
      create dispatch: the "do not create while status==3" gate
  G3  consumers of the two animationsub copies in RenderFlags1 (+0x124): hits followed within
      0x60 bytes by a sub mask (0xE / 0x6000 / 0xE000 / 0x7 / 0x1C)
  G4  inside the 0x0E handler: every touch of +0x12C, every read of pkt+0x2A (sub|spawnflag), and
      XOR-diffs right after a RenderFlags0 load (the H3 setter should be here)
"""
import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import Image, dump_context, h, parse_int, sweep_text  # noqa: E402

RF0, RF1, RF3 = 0x120, 0x124, 0x12C
RMW = ("or", "xor", "and", "bts", "btr", "btc", "not")


def rng(s):
    a, b = s.split(":")
    return parse_int(a), parse_int(b)


def mems(i):
    return [(b, x, d, sz) for b, x, d, sz in i.mems]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("dll")
    ap.add_argument("--cache", default=".cache")
    ap.add_argument("--routine", default="0x8F750:0x926C7", help="entity update routine range (F35)")
    ap.add_argument("--handler", type=parse_int, default=0x9BCF7, help="0x0E handler core (F30)")
    ap.add_argument("--create", type=parse_int, default=0x8F7FF, help="create dispatch rva (F35)")
    args = ap.parse_args()
    img = Image(args.dll)
    sw = sweep_text(img, args.cache)
    r0, r1 = rng(args.routine)
    hfunc = sw.func_of(args.handler)

    def in_routine(rva):
        return r0 <= rva < r1

    print("## Phase 3 gate probes\n")

    # ---- G1
    print("### G1. RMW setters of RenderFlags3 (+0x12C): bit 0 (rebuild?) and bit 23 (spop?)\n")
    g1 = [i for i in sw.insns if i.mn in RMW and any(d == RF3 for b, x, d, sz in mems(i))]
    print(f"{len(g1)} RMW instruction(s) on [reg+0x12C]:\n")
    for i in g1:
        tag = []
        for imm in i.imms:
            if imm & 1:
                tag.append("bit0")
            if imm & 0x800000:
                tag.append("bit23")
            if imm in (0xFE, 0xFFFFFFFE):
                tag.append("clears bit0")
        ctx = []
        if sw.func_of(i.rva) == hfunc:
            ctx.append("IN 0x0E HANDLER")
        if in_routine(i.rva):
            ctx.append("in update routine")
        print(f"- {h(i.rva)} in func {h(sw.func_of(i.rva))} {' '.join(ctx)} {'<- ' + ','.join(tag) if tag else ''}")
        print("```\n" + dump_context(img, sw, i.rva, 4, 3) + "\n```")
    g1b = [i for i in sw.insns if any(d == RF3 + 2 and sz == 1 for b, x, d, sz in mems(i))]
    if g1b:
        print("\nbyte accesses at +0x12E (bit 23 = byte 2, mask 0x80):")
        for i in g1b:
            print(f"- {h(i.rva)} in func {h(sw.func_of(i.rva))}: {i.mn} {i.ops}")
    print()

    # ---- G2
    print(f"### G2. Packed-status tests on RenderFlags0 (+0x120) inside {h(r0)}..{h(r1)}\n")
    masks = (0x2000, 0x4000, 0x6000, 0xE000, 0x40000, 0x46000, 0x20, 0x40, 0x60, 0xE0)
    found = {}
    last_load = None
    for i in sw.iter_range(r0, r1):
        direct = any(d in (RF0, RF0 + 1) for b, x, d, sz in mems(i)) and i.mn in ("test", "and", "cmp") and any(m in masks for m in i.imms)
        if i.mn == "mov" and any(d == RF0 for b, x, d, sz in mems(i)):
            last_load = i
        via_reg = last_load is not None and 0 < i.rva - last_load.rva < 0x18 and i.mn in ("test", "and", "cmp", "shr", "sar") \
            and any(m in masks or m in (13, 14) for m in i.imms)
        if direct or via_reg:
            found[i.rva] = i
    for rva in sorted(found):
        i = found[rva]
        where = "BEFORE create dispatch" if rva < args.create else "after create dispatch"
        print(f"- {h(rva)} ({where}) {i.mn} {i.ops}")
        print("```\n" + dump_context(img, sw, rva, 3, 4) + "\n```")
    if not found:
        print("(none; widen masks, or the gate is in the caller loop: disasm.py --func 0x95DB0 and its 3 call sites)")
    print()

    # ---- G3
    print("### G3. Consumers of RenderFlags1 (+0x124) animationsub copies (bits 1-3 / 13-15)\n")
    submasks = (0xE, 0x6000, 0xE000, 0x7, 0x1C, 0x600E, 0xE00E)
    hits = [i for i in sw.insns if any(d == RF1 for b, x, d, sz in mems(i)) and i.mn in ("mov", "test", "and", "cmp", "shr", "or", "xor")]
    funcs = {}
    for i in hits:
        funcs.setdefault(sw.func_of(i.rva), []).append(i)
    print(f"{len(hits)} instruction(s) touch +0x124 in {len(funcs)} funcs. Shown: those with a sub mask within 0x60 bytes, or in the handler / update routine.\n")
    for f, lst in sorted(funcs.items()):
        for i in lst:
            n = sw.insn_at(i.rva)
            window = [w for w in sw.insns[n:n + 24] if w.rva - i.rva < 0x60]
            masked = sorted({m for w in window for m in w.imms if m in submasks})
            tags = []
            if f == hfunc:
                tags.append("0x0E handler (writer)")
            if in_routine(i.rva):
                tags.append("update routine (consumer?)")
            if masked:
                tags.append("sub mask " + ",".join(hex(m) for m in masked))
            if tags:
                print(f"- {h(i.rva)} in func {h(f)}: {'; '.join(tags)}")
                print("```\n" + dump_context(img, sw, i.rva, 2, 10) + "\n```")
    print()

    # ---- G4
    print(f"### G4. Inside 0x0E handler func {h(hfunc)}: +0x12C touches, pkt+0x2A reads, status XOR-diffs\n")
    hs, he = sw.func_range(hfunc)
    prev = None
    for i in sw.iter_range(hs, he):
        t12c = any(d == RF3 for b, x, d, sz in mems(i))
        rsub = any(d == 0x2A and sz == 1 for b, x, d, sz in mems(i))
        xdiff = i.mn == "xor" and prev is not None and prev.mn == "mov" and any(d == RF0 for b, x, d, sz in mems(prev))
        if t12c or rsub or xdiff:
            print(f"- {h(i.rva)} {i.mn} {i.ops}" + ("  <- +0x12C" if t12c else "") + ("  <- pkt+0x2A (sub | spawnflag 0x04)" if rsub else "") + ("  <- status XOR-diff" if xdiff else ""))
            print("```\n" + dump_context(img, sw, i.rva, 3, 5) + "\n```")
        prev = i
    print("\nRecord in §9: bit-0 setter (H3), create gate on status==3, the +0x124 consumer that compares the two sub copies and the routine name it produces, and the +0x12C bit-23 source.")


if __name__ == "__main__":
    main()

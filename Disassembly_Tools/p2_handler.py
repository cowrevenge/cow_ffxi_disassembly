#!/usr/bin/env python3
"""
p2_handler.py - Phase 2: find the 0x0E CHAR_NPC handler and the two animation triggers.

Usage:
  python p2_handler.py "C:\\...\\FFXiMain.dll" [--cache .cache] [--top 15]

Ranks heuristic functions by how many Phase-L-derived signals they contain:
  S1  byte load from [reg+0x1C] or [reg+0x20]           (status; body-rel or header-rel)
  S2  byte load from [reg+0x26] or [reg+0x2A]           (animationsub)
  S3  byte load from [reg+0x1B] or [reg+0x1F]           (animation)
  S4  cmp/test against 3 near S1                        (status == INVISIBLE)
  S5  store of 0 to [reg+0xA0]                          (ActorPointer = 0, actor destroyed)
  S6  and/or/test on [reg+0x120] with 0x200 or 0xC16000 (RenderFlags0 actor bit)
  S7  store 0x708 to [reg+0x11E] or call to a func that does (ActionTimer2 reset)
  S8  imm32 == VA of CXiSkeletonActor vtable, or call to its ctor func
  S9  fourcc literal 'ini'/'init'/'ini1' or 24-bit 'ini'
  S10 and with 0xFB / test 4 on a byte (spawn flag 0x04 masking)
Prints the top functions with their hit list and disassembly of the hit sites, plus callers.
Also lists: all funcs storing 0 to [reg+0xA0]; all funcs touching [reg+0x120] with the masks.
"""
import argparse
import os
import sys
from collections import defaultdict

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import ENT, FOURCC_LITERALS, Image, dump_context, dump_range, h, sweep_text  # noqa: E402

VT_ACTOR = 0x330F40
VT_MOTION_NODE = 0x32BB38
VT_NODE = 0x32B680
VT_MOTION_OBJ = 0x32B654


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("dll")
    ap.add_argument("--cache", default=".cache")
    ap.add_argument("--top", type=int, default=15)
    ap.add_argument("--dump", action="store_true", help="dump full disassembly of the top 3 functions")
    args = ap.parse_args()

    img = Image(args.dll)
    sw = sweep_text(img, args.cache)
    print("## Phase 2 handler search\n")
    print(f"sweep: {len(sw.insns)} insns, {len(sw.func_starts)} funcs\n")

    # Pre-pass: functions that store 1800 to +0x11E, and functions that use the actor vtable VA.
    def funcs_where(pred):
        out = defaultdict(list)
        for i in sw.insns:
            if pred(i):
                out[sw.func_of(i.rva)].append(i)
        return out

    at2_funcs = funcs_where(lambda i: 0x708 in i.imms and any(d == ENT["ActionTimer2"] for b, x, d, s in i.mems))
    ctor_funcs = funcs_where(lambda i: (img.base + VT_ACTOR) in i.imms)
    print(f"ActionTimer2=1800 store funcs: {', '.join(h(f) for f in at2_funcs)}")
    print(f"CXiSkeletonActor vtable-installing funcs (ctor candidates): {', '.join(h(f) for f in ctor_funcs)}\n")

    fourccs = set(FOURCC_LITERALS[k] for k in ("ini", "init", "ini1"))

    def signals(f_start, f_end):
        hits = defaultdict(list)
        last_status_load = None
        for i in sw.iter_range(f_start, f_end):
            for base, idx, disp, sz in i.mems:
                if sz == 1 and disp in (0x1C, 0x20) and i.mn.startswith(("mov", "cmp", "test")):
                    hits["S1 status byte"].append(i); last_status_load = i.rva
                if sz == 1 and disp in (0x26, 0x2A) and i.mn.startswith(("mov", "cmp", "test")):
                    hits["S2 animsub byte"].append(i)
                if sz == 1 and disp in (0x1B, 0x1F) and i.mn.startswith(("mov", "cmp", "test")):
                    hits["S3 anim byte"].append(i)
                if disp == ENT["ActorPointer"] and sz == 4 and i.mn == "mov" and 0 in i.imms:
                    hits["S5 ActorPointer=0"].append(i)
                if disp == ENT["RenderFlags0"] and any(m in (0x200, 0xFFFFFDFF, 0xC16000, 0x800000, 0x14000) for m in i.imms):
                    hits["S6 RenderFlags0 mask"].append(i)
                if disp == ENT["ActionTimer2"] and 0x708 in i.imms:
                    hits["S7 AT2=1800"].append(i)
            if i.mn in ("cmp", "test") and 3 in i.imms and last_status_load is not None and i.rva - last_status_load < 0x40:
                hits["S4 cmp 3 after status"].append(i)
            if i.call_target in at2_funcs and i.mn == "call":
                hits["S7 call AT2 func"].append(i)
            if (img.base + VT_ACTOR) in i.imms or (i.mn == "call" and i.call_target in ctor_funcs):
                hits["S8 actor ctor"].append(i)
            if any(imm in fourccs or (imm & 0xFFFFFF) == 0x696E69 for imm in i.imms):
                hits["S9 ini literal"].append(i)
            if i.mn in ("and", "test") and any(imm in (0xFB, 0xFFFFFFFB, 4) for imm in i.imms) and any(s == 1 for b, x, d, s in i.mems):
                hits["S10 spawn flag 0x04"].append(i)
        return hits

    scored = []
    for k, f in enumerate(sw.func_starts):
        s, e = sw.func_range(f)
        if e - s < 16:
            continue
        hits = signals(s, e)
        if not hits:
            continue
        # weight: distinct signal kinds count most; S1+S2 together is the handler fingerprint
        kinds = set(hits)
        score = len(kinds) * 10 + (15 if {"S1 status byte", "S2 animsub byte"} <= kinds else 0) + min(sum(len(v) for v in hits.values()), 20)
        scored.append((score, f, e, hits))
    scored.sort(reverse=True)

    print(f"### Top {args.top} candidate functions\n")
    for score, f, e, hits in scored[:args.top]:
        callers = sw.callers_of(f)
        print(f"#### func {h(f)}..{h(e)} (score {score}, {e-f} bytes) signals: {', '.join(sorted(hits))}")
        print(f"callers ({len(callers)}): " + ", ".join(f"{h(c.rva)} in {h(sw.func_of(c.rva))}" for c in callers[:10]))
        print("```")
        for kind in sorted(hits):
            for i in hits[kind][:3]:
                print(f"-- {kind} @ {h(i.rva)}")
                print(dump_context(img, sw, i.rva, 3, 3))
        print("```\n")

    if args.dump:
        print("### Full disassembly of top 3\n")
        for score, f, e, hits in scored[:3]:
            print(f"#### {h(f)}\n```\n{dump_range(img, sw, f, e)}\n```\n")

    print("### All ActorPointer=0 store sites\n")
    for f, lst in funcs_where(lambda i: i.mn == "mov" and 0 in i.imms and any(d == ENT["ActorPointer"] and s == 4 for b, x, d, s in i.mems)).items():
        print(f"- func {h(f)}: " + ", ".join(h(i.rva) for i in lst[:8]))
    print("\n### All RenderFlags0 (+0x120) mask sites with 0x200 / 0xC16000 / 0x800000\n")
    for f, lst in funcs_where(lambda i: any(d == ENT["RenderFlags0"] for b, x, d, s in i.mems) and any(m in (0x200, 0xFFFFFDFF, 0xC16000, 0x800000, 0x14000) for m in i.imms)).items():
        print(f"- func {h(f)}: " + ", ".join(f"{h(i.rva)} {i.mn} {i.ops}" for i in lst[:6]))
    print("\nRecord in §9: the handler RVA, the status==3 branch (S4/S5/S6), the actor-create branch (S8), the ini dispatch (S9),"
          " the spawn-flag gate (S10), and where the previous sub value is compared (look for a cmp between the S2 load and a"
          " byte on the entity or actor).")


if __name__ == "__main__":
    main()

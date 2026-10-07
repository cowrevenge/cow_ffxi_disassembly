"""
xref_vtable.py — vtable-slot oracle over the FULL data sections.

Why this exists: tables_vtables.csv records only the FIRST 8 slot targets of
each vtable (slot_targets_first8). A function sitting in slot 9 or later is
invisible to a grep of that file — the 2026-10-02 P0(b) miss (0x5E9C0, slot 5
of a vtable that starts at a different alignment in the same .rdata run) is
the motivating case. This script instead scans .rdata/.data/.data1 for
aligned runs of absolute code pointers (candidate vtables) and answers:

  python xref_vtable.py 0x5E9C0            # which vtable(s) contain this fn
  python xref_vtable.py --dump 0x32B9B0    # print a whole candidate vtable
  python xref_vtable.py --list             # list all candidate vtables

Usage: python xref_vtable.py [RVA | --dump RVA | --list]
Input: FFXiMain.unpacked.dll (raw==virtual) in the CWD, or pass --dll PATH.
"""
from __future__ import annotations

import argparse
import struct
import sys

CODE_LO = 0x10001000        # first code VA (section .text @ 0x1000)
CODE_HI = 0x10328000        # .text ends ~0x3275EE

SECTIONS = [  # (name, rva_lo, rva_hi) — TDS 0x6A995428
    (".rdata", 0x329000, 0x34E595),
    (".data", 0x34F000, 0x3B9669),
    (".data1", 0x9F00A0, 0x9F00B0),
]

MIN_RUN = 4                 # a vtable needs >= 4 code-pointer slots


def is_code_ptr(v: int) -> bool:
    return CODE_LO <= v < CODE_HI


def candidate_vtables(d: bytes):
    """Yield (rva, [slot RVAs]) for every aligned run of >= MIN_RUN code ptrs."""
    out = []
    for name, lo, hi in SECTIONS:
        i = lo
        while i + 4 <= hi:
            v = struct.unpack_from("<I", d, i)[0]
            if is_code_ptr(v):
                j = i
                slots = []
                while j + 4 <= hi:
                    w = struct.unpack_from("<I", d, j)[0]
                    if not is_code_ptr(w):
                        break
                    slots.append(w - 0x10000000)
                    j += 4
                if len(slots) >= MIN_RUN:
                    out.append((name, i, slots))
                    i = j
                    continue
            i += 4
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("rva", nargs="?", help="RVA to look up")
    ap.add_argument("--dump", metavar="RVA", help="dump candidate vtable at RVA")
    ap.add_argument("--list", action="store_true", help="list candidate vtables")
    ap.add_argument("--dll", default="FFXiMain.unpacked.dll")
    a = ap.parse_args()

    d = open(a.dll, "rb").read()
    vts = candidate_vtables(d)

    if a.list:
        for name, rva, slots in vts:
            print(f"{name} 0x{rva:06X}  {len(slots)} slots  first: "
                  + " ".join(f"0x{s:05X}" for s in slots[:8]))
        return 0

    if a.dump:
        tgt = int(a.dump, 16)
        for name, rva, slots in vts:
            if rva == tgt:
                for k, s in enumerate(slots):
                    print(f"  vt+0x{k:02X}: 0x{s:05X}")
                return 0
        print(f"no candidate vtable at 0x{tgt:06X}", file=sys.stderr)
        return 1

    if a.rva:
        tgt = int(a.rva, 16)
        hit = False
        for name, rva, slots in vts:
            for k, s in enumerate(slots):
                if s == tgt:
                    hit = True
                    print(f"HIT: {name} vtable 0x{rva:06X} slot {k} (vt+0x{k:02X}) -> 0x{s:05X}")
        if not hit:
            print(f"no vtable slot points at 0x{tgt:05X} (not vtable-dispatched, "
                  f"or vtable not a clean code-pointer run)")
        return 0

    ap.print_help()
    return 1


if __name__ == "__main__":
    sys.exit(main())

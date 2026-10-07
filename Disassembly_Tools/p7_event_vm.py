#!/usr/bin/env python3
"""
p7_event_vm.py - locate the event VM functions in FFXiMain.dll by byte pattern.

Event pass (T1 prerequisite): searches every XiEvents signature from
research/XiEvents/Event VM Functions.md against the POL1-decoded .text and prints a
markdown table of name -> hit RVA(s) -> matched bytes, plus each hit's heuristic
function start so follow-up dumps can use `disasm.py --func`.

Patterns are from the Feb 2022 retail build; this code has not changed in years, so
most should hit. A miss is not a failure: T1 falls back to immediate anchors (the
band constants of the 0x5B helper and the 30704/39643/25937 trio of the 0x45 family).

Usage:
  python p7_event_vm.py "C:\\PhoenixXI\\SquareEnix\\FINAL FANTASY XI\\FFXiMain.dll" > out\\p7.md
Options: --cache .cache
"""
import argparse
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import Image, h, sweep_text  # noqa: E402

# (name, pattern) from research/XiEvents/Event VM Functions.md, one per **Pattern:** line.
# `??` = any byte. The getworkofs/getworkstrofs pair shares its main-body pattern; XiEvents
# says the first result is getworkofs and the second is getworkstrofs (RVA order).
PATTERNS = [
    ("EventStartWait",
     "A0 ?? ?? ?? ?? C7 05 ?? ?? ?? ?? 00 00 00 00 84 C0 75 ?? B0 01 C3 E8 ?? ?? ?? ?? 83 F8 FF"),
    ("InitEvent2",
     "83 EC 14 53 55 56 8B 35 ?? ?? ?? ?? 57 C7 44 24 18 00 00 00 00 8B 06 83 C6 04 "
     "89 44 24 20 89 74 24 1C 8D 1C 85 00 00 00 00 C1 EB 02 85 C0 0F 8E"),
    ("XiAtelBuff::EventNew",
     "56 57 8B F9 8A 87 20 01 00 00 84 C0 78 5B 68 ?? ?? ?? ?? E8 ?? ?? ?? ?? 83 C4 04 85 C0 74"),
    ("XiEvent::XiEvent",
     "53 55 56 57 68 ?? ?? ?? ?? 8B F1 E8 ?? ?? ?? ?? 33 DB 83 C4 04 3B C3 74 ?? 8B C8 E8"),
    ("~XiEvent",
     "56 8B F1 57 8B 46 04 66 8B 0E 89 46 08 8B 86 5C 02 00 00 85 C0 66 89 4E 02"),
    ("XiEventInit",
     "53 55 56 8B F1 33 C0 33 DB 66 8B 46 02 57 8B 04 85 ?? ?? ?? ?? 3B C3 0F ?? ?? ?? ?? ?? 8B 8E 60"),
    ("EventIdle",
     "56 8B F1 8B 46 08 85 C0 0F ?? ?? ?? ?? ?? 57 BA FF 00 00 00 33 C0 8D 7E 24 0F BF 0F 3B CA"),
    ("ExecProg",
     "0F BF 44 24 04 3D ?? ?? 00 00 0F ?? ?? ?? ?? ?? FF"),
    ("eventgetcode",
     "8B 51 20 33 C0 66 8B 81 56 02 00 00 8B 4C 24 04 03 C2 33 D2 8A 14 01 03 C8 "
     "33 C0 8A 41 01 C1 E0 08 03 C2 C2 04 00"),
    ("eventgetcode2",
     "8B 51 20 33 C0 66 8B 81 56 02 00 00 8B 4C 24 04 03 C2 33 D2 8A 54 01 02 03 C8 "
     "33 C0 8A 41 03 C1"),
    ("getworkofs (forward wrapper)",
     "8B 44 24 04 6A 00 50 E8 04 00 00 00 C2 04 00"),
    ("getworkofs / getworkstrofs (shared body; first hit = getworkofs, second = getworkstrofs)",
     "8B 44 24 04 56 50 8B F1 E8 ?? ?? ?? ?? 03 44 24 0C 84 E4 0F ?? ?? ?? ?? ?? "
     "3D 00 08 00 00 7D ?? 83 F8 50 7C ?? 50 68 ?? ?? ?? ?? E8"),
    ("setworkofs",
     "8B 44 24 04 56 50 8B F1 E8 ?? ?? ?? ?? 03 44 24 10 84 E4 0F ?? ?? ?? ?? ?? "
     "3D 00 08 00 00 7D ?? 83 F8 50 7C ?? 50 68 ?? ?? ?? ?? E8"),
    ("setworkofs (forward wrapper)",
     "8B 44 24 08 8B 54 24 04 6A 00 50 52 E8 0F 00 00 00 C2 08 00"),
    ("setworkstrofs",
     "8B 44 24 04 56 50 8B F1 E8 ?? ?? ?? ?? 03 44 24 10 84 E4 0F ?? ?? ?? ?? ?? "
     "3D 00 08 00 00 7D ?? 83 F8 40 7C ?? 50 68 ?? ?? ?? ?? E8"),
    ("GetActorIndex",
     "8B 44 24 04 56 8D B0 40 00 00 80 83 FE 39"),
    ("GetReqLevel",
     "33 C0 8B 54 24 04 66 8B 81 58 02 00 00 56 C1 E0 05 0F BF 44 08 24 3B C2 7F ?? "
     "33 C0 5E C2 04 00"),
    ("GetReqStatus",
     "33 C0 8B 54 24 04 66 8B 81 58 02 00 00 56 C1 E0 05 0F BE 44 08 3A 3B C2 75 ?? "
     "33 C0 5E C2 04 00"),
    ("ReqSet",
     "55 56 57 8B F9 8B 4C 24 14 83 CE FF 33 C0 8D 57 3A 66 81 7A EA FF 00"),
    ("lookatone",
     "8B 54 24 04 83 EC 08 8D 44 24 0C 56 8B F1 8D 4C 24 04 50 51 52 8B CE E8 ?? ?? ?? ?? 3C 01"),
]


def compile_pattern(pat: str):
    """Hex pattern with `??` wildcards -> compiled regex over the section bytes."""
    parts = pat.split()
    chunks = [b"." if p == "??" else re.escape(bytes.fromhex(p)) for p in parts]
    # DOTALL so a wildcard slot may match 0x0A
    return re.compile(b"".join(chunks), re.DOTALL)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("dll")
    ap.add_argument("--cache", default=".cache")
    args = ap.parse_args()
    img = Image(args.dll)
    sw = sweep_text(img, args.cache)

    va, blob = img.text()
    print(f"# p7_event_vm: XiEvents pattern search in {os.path.basename(args.dll)}")
    print()
    print(f"searched section `{img.text_name()}` rva 0x{va:X}, {len(blob):#x} bytes "
          f"(POL1-decoded, F24); sweep cache: {len(sw.insns)} insns / {len(sw.func_starts)} funcs")
    print()
    print("| name | hit RVA | func start | matched bytes |")
    print("|---|---|---|---|")
    for name, pat in PATTERNS:
        rx = compile_pattern(pat)
        hits = [m.start() + va for m in rx.finditer(blob)]
        if not hits:
            print(f"| {name} | **MISS** | - | `{pat}` |")
            continue
        for rva in sorted(hits):
            matched = blob[rva - va:rva - va + len(pat.split())].hex(" ")
            print(f"| {name} | {h(rva)} | {h(sw.func_of(rva))} | `{matched}` |")
    print()
    print("Notes: `func start` is the heuristic function containing the hit (F34: hot funcs are")
    print("entered at mid-function offsets, so a handler RVA may sit inside another func). The")
    print("shared getworkofs/getworkstrofs body pattern lists both hits in RVA order; XiEvents says")
    print("the first is getworkofs and the second getworkstrofs.")


if __name__ == "__main__":
    main()

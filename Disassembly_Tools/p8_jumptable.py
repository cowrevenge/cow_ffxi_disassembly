#!/usr/bin/env python3
"""
p8_jumptable.py - dump an MSVC switch jump table from FFXiMain.dll.

Event pass (T1): the ExecProg pattern hit at rva 0xBC290 decodes to

    movsx eax, word [esp+4]          ; opcode u16
    cmp   eax, <max>                 ; cases above max fall through to default
    ja    <default>
    jmp   dword ptr [eax*4 + <tableVA>]

This tool reads the pointer table at a given RVA (on-disk VA = ImageBase + RVA),
prints one row per case: opcode, entry VA, handler RVA, section. Entries that are
thunks (`call <real>; ret 4`) are resolved to the real handler in a second column
when they sit inside .text and match that shape; otherwise the raw target is kept.

Usage:
  python p8_jumptable.py %DLL% --table 0xBC970 --count 219 > out\\p8.md
"""
import argparse
import os
import struct
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import Image, h, parse_int  # noqa: E402


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("dll")
    ap.add_argument("--table", type=parse_int, required=True)
    ap.add_argument("--count", type=int, required=True)
    args = ap.parse_args()
    img = Image(args.dll)

    blob = img.read(args.table, 4 * args.count)
    if len(blob) < 4 * args.count:
        print(f"table at {h(args.table)} shorter than requested ({len(blob)} bytes)")
        return
    entries = struct.unpack("<%dI" % args.count, blob)

    print(f"# p8_jumptable: switch table at rva {h(args.table)} ({args.count} entries)")
    print()
    print("| opcode | entry VA | handler RVA | thunk target | section |")
    print("|---|---|---|---|---|")
    for i, va in enumerate(entries):
        r = va - img.base
        sec = img.section_of(r) if 0 <= r < 0x1000000 else "?"
        thunk = "-"
        # a case thunk is `call rel32; ret 4` (5 + 2 bytes); resolve it when in .text
        b = img.read(r, 7)
        if len(b) == 7 and b[0] == 0xE8 and b[5:7] == b"\xC2\x04":
            tgt = (struct.unpack("<i", b[1:5])[0] + r + 5) & 0xFFFFFFFF
            thunk = h(tgt)
        print(f"| 0x{i:02X} | 0x{va:08X} | {h(r)} | {thunk} | {sec} |")


if __name__ == "__main__":
    main()

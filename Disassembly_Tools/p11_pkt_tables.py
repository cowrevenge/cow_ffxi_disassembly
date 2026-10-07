"""
p11_pkt_tables.py - find jump tables of `call rel32; ret 4` thunks in FFXiMain.dll.

The map-packet dispatcher (and the event-VM ExecProg switch, rva 0xBC970) are arrays of
dwords, each pointing at a stdcall thunk that forwards to a handler. This scanner lists every
such table so the packet dispatcher can be identified by checking which index lands on a known
handler (e.g. the s2c 0x0E field-packing core near 0x9BCF7).

    python p11_pkt_tables.py %DLL% [--min 64] > out3\p11.md
"""
from __future__ import annotations

import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import Image, sweep_text  # noqa: E402


def is_thunk(img: Image, rva: int) -> bool:
    b = img.read(rva, 8)
    if len(b) < 8 or b[0] != 0xE8:
        return False
    rel = int.from_bytes(b[1:5], "little", signed=True)
    target = (rva + 5 + rel) & 0xFFFFFFFF
    # ret 4 after the call
    if b[5] != 0xC2 or b[6] != 0x04:
        return False
    tsec = img.section_of(target)
    return tsec is not None and "text" in tsec.lower()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("dll")
    ap.add_argument("--min", type=int, default=64, help="minimum table length to report")
    args = ap.parse_args()

    img = Image(args.dll)
    sweep_text(img)  # ensure cache; not strictly needed for this scan

    base = img.base
    tables = []
    # The ExecProg table itself sits inside .text (POL1-decoded), so scan the executable
    # section via text() plus the plain data sections.
    va, blob = img.text()
    sections = [(img.text_name(), va, blob)]
    for name in (".data", ".rdata", ".data1"):
        try:
            dva, dblob = img.section_bytes(name)
            sections.append((name, dva, dblob))
        except KeyError:
            continue
    for name, va, blob in sections:
        n = len(blob) // 4
        run_start = None
        prev_ok = False
        for i in range(n):
            val = int.from_bytes(blob[i * 4:i * 4 + 4], "little")
            rva = val - base if val >= base else None
            ok = rva is not None and is_thunk(img, rva)
            if ok and not prev_ok:
                run_start = i
            if (not ok or i == n - 1) and prev_ok and run_start is not None:
                length = i - run_start + (1 if ok else 0)
                if length >= args.min:
                    tables.append((name, va + run_start * 4, length))
            prev_ok = ok
            run_start = i + 1 if ok and not prev_ok else run_start

    print(f"thunk tables (>= {args.min} entries): {len(tables)}\n")
    for name, rva, length in sorted(tables, key=lambda t: -t[2]):
        print(f"## table @0x{rva:X} ({name}) — {length} entries\n")
        # Print a sample of entries with their thunk targets.
        step = max(1, length // 32)
        for i in range(0, length, step):
            val = img.u32(rva + i * 4)
            if val is None:
                continue
            trva = val - base
            tgt_b = img.read(trva, 5)
            target = (trva + 5 + int.from_bytes(tgt_b[1:5], "little", signed=True)) & 0xFFFFFFFF \
                if len(tgt_b) == 5 and tgt_b[0] == 0xE8 else None
            print(f"  [{i:3d}] thunk 0x{trva:X} -> handler ~0x{(target or 0):X}")


if __name__ == "__main__":
    main()

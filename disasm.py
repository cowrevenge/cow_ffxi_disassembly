#!/usr/bin/env python3
"""
disasm.py - bounded disassembly with §9-style annotations.

Usage:
  python disasm.py FFXiMain.dll --rva 0x12345 [--len 0x80]     from rva for len bytes (default 0x60)
  python disasm.py FFXiMain.dll --func 0x12345                   the whole heuristic function containing rva
  python disasm.py FFXiMain.dll --va 0x04B12345 --base 0x04AC0000   convert a wormwatch runtime VA first
  python disasm.py FFXiMain.dll --bytes 0x32BB38 --len 0x100     hex dump (for vtables/data)
"""
import argparse
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import Image, dump_range, h, parse_int, sweep_text  # noqa: E402


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("dll")
    ap.add_argument("--cache", default=".cache")
    ap.add_argument("--rva", type=parse_int)
    ap.add_argument("--va", type=parse_int)
    ap.add_argument("--base", type=parse_int, default=0x04AC0000, help="runtime base for --va (wormwatch logged 0x04AC0000)")
    ap.add_argument("--len", type=parse_int, default=0x60)
    ap.add_argument("--func", type=parse_int)
    ap.add_argument("--bytes", type=parse_int)
    args = ap.parse_args()
    img = Image(args.dll)

    if args.bytes is not None:
        blob = img.read(args.bytes, args.len)
        for o in range(0, len(blob), 16):
            row = blob[o:o + 16]
            asc = re.sub(rb"[^ -~]", b".", row).decode()
            dw = " ".join(f"{int.from_bytes(row[k:k+4], 'little'):08X}" for k in range(0, len(row) - 3, 4))
            print(f"{h(args.bytes + o)}: {row.hex(' '):<48} {dw:<36} |{asc}|")
        return

    rva = args.rva
    if args.va is not None:
        rva = args.va - args.base
        print(f"; VA 0x{args.va:X} - base 0x{args.base:X} = rva {h(rva)} (section {img.section_of(rva)}, on-disk VA 0x{img.base + rva:X})")
    sw = sweep_text(img, args.cache)
    if args.func is not None:
        f = sw.func_of(args.func)
        s, e = sw.func_range(f)
        print(f"; func {h(s)}..{h(e)} ({e - s} bytes), callers: {len(sw.callers_of(s))}")
        print(dump_range(img, sw, s, e))
    elif rva is not None:
        print(dump_range(img, sw, rva, rva + args.len))
    else:
        ap.print_help()


if __name__ == "__main__":
    main()

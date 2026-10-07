#!/usr/bin/env python3
"""
p1_anchors.py - Phase 1: locate the Phase L anchors inside FFXiMain.dll.

Usage:
  python p1_anchors.py "C:\\...\\FFXiMain.dll" [--no-sweep] [--strings-out anchors_strings.txt]

Does, in order:
  1. Maps every known RVA (common.KNOWN_RVAS) to its section; dumps vtable slots.
  2. Finds constructor sites: instructions with imm32 == ImageBase + vtable RVA (mov [reg], imm).
  3. Finds fourcc literal immediates ('ini', 'init', 'ini1', 'pop0', 'pop1', 'sp00', 'sp10')
     used as instruction operands, and the same bytes in data sections (tables/strings).
  4. Finds class-name and resource strings (CXiSkeletonActor, CYyObject, XiAtelBuff, ROM/, .DAT, FTABLE.DAT).
  5. Finds every `mov word [reg+0x11E], 0x708` (ActionTimer2 = 1800) and other 1800 immediates near +0x11C stores.
All output is markdown for §9.
"""
import argparse
import os
import struct
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import (ENT, FOURCC_LITERALS, KNOWN_RVAS, Image, dump_context, fmt_insn, fourcc_str, h,  # noqa: E402
                    sweep_text)

CLASS_STRINGS = [b"CXiSkeletonActor", b"CYyObject", b"XiAtelBuff", b"CXi", b"CYy", b"YmObject", b"XiEvent",
                 b"CXiActor", b"CXiSchedular", b"CXiScheduler", b"Schedul", b"Motion", b"Generator"]
RES_STRINGS = [b"ROM/", b"ROM\\", b"FTABLE.DAT", b".DAT", b"VTABLE.DAT", b"ROM2", b"ROM3", b"ROM4"]


def vtable_slots(img, rva, text_name, maxslots=64):
    slots = []
    for i in range(maxslots):
        v = img.u32(rva + i * 4)
        if v is None:
            break
        r = v - img.base
        if img.section_of(r) != text_name:
            break
        slots.append(r)
    return slots


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("dll")
    ap.add_argument("--no-sweep", action="store_true", help="skip capstone sweep (steps 2/3/5 need it)")
    ap.add_argument("--cache", default=".cache")
    args = ap.parse_args()

    img = Image(args.dll)
    text_name = img.text_name()
    print("## Phase 1 anchors\n")
    print("```\n" + img.describe() + "\n```\n")

    # 1. Known RVAs -> sections, vtable slots
    print("### 1. Known RVAs\n")
    print("| RVA | on-disk VA | section | what | first bytes / slots |\n|---|---|---|---|---|")
    ctor_targets = {}
    for rva, what in sorted(KNOWN_RVAS.items()):
        sec = img.section_of(rva)
        b = img.read(rva, 16).hex(" ")
        extra = b
        if sec and sec != text_name:
            slots = vtable_slots(img, rva, text_name)
            if slots:
                extra = f"{len(slots)} .text slots: " + " ".join(h(s) for s in slots[:12]) + (" ..." if len(slots) > 12 else "")
                ctor_targets[rva] = what
        print(f"| {h(rva)} | 0x{img.base + rva:08X} | {sec} | {what} | {extra} |")
    print()
    print("Vtable slot lists (virtual method RVAs, in order):\n")
    for rva in ctor_targets:
        slots = vtable_slots(img, rva, text_name)
        print(f"- {h(rva)} {KNOWN_RVAS[rva]}:")
        for i, s in enumerate(slots):
            print(f"    slot {i:2d} (+0x{i*4:02X}) -> {h(s)}")
    print()

    # Data-section references to vtables (e.g. RTTI / other tables)
    print("### 1b. Raw references to vtable VAs anywhere in the file (data + code)\n")
    for rva, what in ctor_targets.items():
        hits = img.find_u32(img.base + rva)
        print(f"- {h(rva)} ({what}): {len(hits)} raw hits: " + ", ".join(f"{h(x)}[{img.section_of(x)}]" for x in hits[:20]))
    print()

    # 4. Strings (no sweep needed)
    print("### 4. Class-name / resource strings\n")
    for needle in CLASS_STRINGS + RES_STRINGS:
        hits = img.find_bytes(needle)
        if hits:
            shown = []
            for x in hits[:8]:
                ctx = img.read(x, 40).split(b"\0")[0][:40]
                shown.append(f"{h(x)}[{img.section_of(x)}] `{ctx.decode(errors='replace')}`")
            print(f"- `{needle.decode()}`: {len(hits)} hits: " + "; ".join(shown))
    print()
    print("Strings mentioning ini/init/pop/sched/motion (ASCII, any section):\n")
    import re
    pat = re.compile(r"^(ini[0-9t]?|pop[0-9]|sp[0-9?][0-9?]|.*[Ss]ched.*|.*[Mm]otion.*|.*[Rr]outine.*|.*[Aa]nimation.*)$")
    n = 0
    for r, k, sec, s in img.strings(minlen=3, utf16=False):
        if pat.match(s) and n < 80:
            print(f"  {h(r)}[{sec}] {s!r}")
            n += 1
    print()

    # fourcc bytes in data sections
    print("### 3b. Fourcc bytes in non-code sections (tables?)\n")
    for name, val in FOURCC_LITERALS.items():
        hits = [x for x in img.find_u32(val) if img.section_of(x) != text_name]
        if hits:
            print(f"- '{name}' 0x{val:08X}: " + ", ".join(f"{h(x)}[{img.section_of(x)}]" for x in hits[:16]))
            for x in hits[:4]:
                row = img.read(x - 16, 48)
                print(f"    {h(x-16)}: {row.hex(' ')}  |{re.sub(rb'[^ -~]', b'.', row).decode()}|")
    print()

    if args.no_sweep:
        return

    print("### (sweeping .text with capstone; cached after first run)\n", file=sys.stderr)
    sw = sweep_text(img, args.cache)
    print(f"sweep: {len(sw.insns)} instructions, {len(sw.func_starts)} heuristic functions\n")

    # 2. Constructor sites
    print("### 2. Constructor sites (imm32 == vtable VA)\n")
    for rva, what in ctor_targets.items():
        va = img.base + rva
        sites = [i for i in sw.insns if va in i.imms]
        print(f"- {h(rva)} {what}: {len(sites)} instruction(s) use its VA")
        for i in sites[:12]:
            f = sw.func_of(i.rva)
            print(f"  in func {h(f)}:\n" + dump_context(img, sw, i.rva, 4, 3))
        print()

    # 3. Fourcc immediates in code
    print("### 3. Fourcc literals used as instruction operands\n")
    for name, val in FOURCC_LITERALS.items():
        sites = [i for i in sw.insns if val in i.imms]
        print(f"- '{name}' 0x{val:08X}: {len(sites)} site(s)")
        for i in sites[:10]:
            print(f"  in func {h(sw.func_of(i.rva))}:\n" + dump_context(img, sw, i.rva, 4, 4))
    # 'ini' built as 3 bytes + digit: look for 0x696E69 (24-bit) too
    print("- 24-bit 'ini' (0x00696E69 masked) or byte writes of 'i','n','i':")
    sites = [i for i in sw.insns if any((imm & 0x00FFFFFF) == 0x00696E69 for imm in i.imms)]
    for i in sites[:10]:
        print(f"  in func {h(sw.func_of(i.rva))}:\n" + dump_context(img, sw, i.rva, 4, 4))
    print()

    # 5. ActionTimer stores
    print("### 5. ActionTimer2 = 1800 stores and +0x11C/+0x11E accesses\n")
    at2 = [i for i in sw.insns if any(d == ENT["ActionTimer2"] for b, x, d, s in i.mems) and 0x708 in i.imms]
    print(f"- `mov [reg+0x11E], 0x708`: {len(at2)} site(s)")
    funcs = {}
    for i in at2:
        funcs.setdefault(sw.func_of(i.rva), []).append(i)
    for f, lst in funcs.items():
        print(f"  func {h(f)} ({len(lst)} store(s)); callers: " + ", ".join(h(c.rva) for c in sw.callers_of(f)[:12]))
        print(dump_context(img, sw, lst[0].rva, 8, 6))
    at1 = [i for i in sw.insns if any(d == ENT["ActionTimer1"] and s <= 2 for b, x, d, s in i.mems)]
    print(f"\n- any access to [reg+0x11C] (ActionTimer1, byte/word): {len(at1)} site(s) in {len(set(sw.func_of(i.rva) for i in at1))} funcs: "
          + ", ".join(sorted(set(h(sw.func_of(i.rva)) for i in at1))[:40]))
    print("\nNext: feed the function RVAs above to p2_handler.py / xref.py.")


if __name__ == "__main__":
    main()

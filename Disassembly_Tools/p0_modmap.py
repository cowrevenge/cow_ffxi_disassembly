#!/usr/bin/env python3
"""
p0_modmap.py - Phase 0: module identification & map.

Usage:
  python p0_modmap.py "C:\\PhoenixXI\\SquareEnix\\FINAL FANTASY XI"

For every top-level PE (exe/dll) in the folder: header, sections, imports, exports, string
density. Then polboot.exe load-chain evidence and FFXiVersions/patch.sin version strings.
Output is markdown for §9 (Phase 0 exit criteria).
"""
import os
import re
import sys
from collections import Counter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import Image, h  # noqa: E402

INTERESTING_IMPORTS = {"LoadLibraryA", "LoadLibraryW", "LoadLibraryExA", "LoadLibraryExW", "GetProcAddress",
                       "CreateProcessA", "CreateProcessW", "recv", "WSARecv", "send", "WSASend", "select",
                       "CreateFileA", "CreateFileW", "ReadFile", "Direct3DCreate8", "DirectSoundCreate8"}


def scan(path):
    try:
        img = Image(path)
    except Exception as e:
        print(f"### {os.path.basename(path)}\n\n(not a PE or failed to parse: {e})\n")
        return None
    print(f"### {os.path.basename(path)}\n")
    print("```")
    print(img.describe())
    print("```")
    imps = img.imports()
    dlls = Counter(d for d, n, a in imps)
    print(f"\nimports: {len(imps)} from {len(dlls)} DLLs: " + ", ".join(f"{d}({c})" for d, c in dlls.most_common()))
    hot = [(d, n) for d, n, a in imps if n in INTERESTING_IMPORTS]
    if hot:
        print("interesting imports: " + ", ".join(f"{d}!{n}" for d, n in hot))
    exps = img.exports()
    print(f"exports: {len(exps)}" + ("" if not exps else " -> " + ", ".join(f"{n}@{h(a)}" for n, a in exps[:40]) + (" ..." if len(exps) > 40 else "")))
    strs = list(img.strings(minlen=4, utf16=False))
    per_sec = Counter(sec for r, k, sec, s in strs)
    print(f"ASCII strings >=4: {len(strs)} ({len(strs) * 1000 // max(len(img.data), 1)} per KB); per section: "
          + ", ".join(f"{s}={c}" for s, c in per_sec.most_common()))
    names = [(r, s) for r, k, sec, s in strs if re.search(r"\.dll|\.DAT|FTABLE|ROM/|ROM\\|polboot|PlayOnline|FFXi", s, re.I)]
    if names:
        print("path/module strings:")
        for r, s in names[:60]:
            print(f"  {h(r)}  {s}")
    print()
    return img


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    root = sys.argv[1]
    files = sorted(f for f in os.listdir(root) if f.lower().endswith((".exe", ".dll")))
    print(f"## Phase 0 module map for `{root}`\n")
    print("Files: " + ", ".join(f"`{f}` ({os.path.getsize(os.path.join(root, f)) // 1024} KB)" for f in files) + "\n")
    for f in files:
        scan(os.path.join(root, f))

    # Version evidence
    for cand in ("patch.sin", "FTABLE.DAT"):
        p = os.path.join(root, cand)
        if os.path.exists(p):
            with open(p, "rb") as fh:
                head = fh.read(256)
            print(f"### {cand}\n\n```\n{head.hex(' ')[:400]}\n```\nprintable: {re.sub(rb'[^\x20-\x7e]', b'.', head)[:200]}\n")

    print("### What to record in §9 (Phase 0 exit)\n")
    print("- polboot.exe: does it import LoadLibrary*/GetProcAddress and contain the string `FFXiMain.dll`? (in-process load) or CreateProcess*? (child process)")
    print("- FFXiMain.dll: ImageBase, SizeOfImage, section table, TimeDateStamp (this is the build id if FFXiVersions gives nothing better)")
    print("- FFXiVersions.dll / patch.sin: any version string")
    print("- Convert Phase L runtime VAs with: RVA = VA - 0x04AC0000; on-disk VA = ImageBase + RVA")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Two small lookups against a retail FFXI install. No cargo, no build.

  python ffxi_dat_find.py resolve 30834 30912 30904
      Prints the ROM path each file id maps to (VTABLE/FTABLE walk).

  python ffxi_dat_find.py scan-tag tlk0 [thk1 ...]
      Walks every DAT the tables know about and lists the files that hold a
      Scheduler (kind 0x07) chunk named with any of the given four-char tags.
      Slow (tens of thousands of files); run once and keep the output.

Set FFXI_DAT_PATH to the folder that contains VTABLE.DAT, or pass --root.
"""

import os
import struct
import sys


def load_tables(root):
    tables = []
    pairs = [("", "VTABLE.DAT", "FTABLE.DAT")]
    for i in range(2, 10):
        rd = f"ROM{i}"
        pairs.append((rd, f"VTABLE{i}.DAT", f"FTABLE{i}.DAT"))
    for rd, vt, ft in pairs:
        vpath = os.path.join(root, rd, vt) if rd else os.path.join(root, vt)
        fpath = os.path.join(root, rd, ft) if rd else os.path.join(root, ft)
        if not (os.path.exists(vpath) and os.path.exists(fpath)):
            continue
        with open(vpath, "rb") as f:
            vtable = f.read()
        with open(fpath, "rb") as f:
            ftable = f.read()
        rom_index = 1 if not rd else int(rd[3:])
        tables.append((rd or "ROM", rom_index, vtable, ftable))
    if not tables:
        sys.exit(f"no VTABLE.DAT under {root}")
    return tables


def resolve(tables, file_id):
    for rom_dir, rom_index, vtable, ftable in tables:
        if file_id < len(vtable) and vtable[file_id] == rom_index:
            if file_id * 2 + 2 > len(ftable):
                return None
            (v,) = struct.unpack_from("<H", ftable, file_id * 2)
            return os.path.join(rom_dir, str(v >> 7), f"{v & 0x7F}.DAT")
    return None


def chunks(data):
    off = 0
    while off + 16 <= len(data):
        name = data[off:off + 4]
        (v,) = struct.unpack_from("<I", data, off + 4)
        kind = v & 0x7F
        size = ((v >> 7) & 0x7FFFF) * 16
        if size < 16:
            return
        yield name, kind, off
        off += size


def main():
    args = sys.argv[1:]
    root = os.environ.get("FFXI_DAT_PATH")
    if "--root" in args:
        i = args.index("--root")
        root = args[i + 1]
        del args[i:i + 2]
    if not root:
        sys.exit("set FFXI_DAT_PATH or pass --root <dir with VTABLE.DAT>")
    if not args:
        sys.exit(__doc__)
    tables = load_tables(root)
    cmd, rest = args[0], args[1:]

    if cmd == "resolve":
        for a in rest:
            fid = int(a)
            print(fid, resolve(tables, fid) or "(unresolvable)")
        return

    if cmd == "scan-tag":
        wanted = {t.encode("latin1")[:4] for t in rest}
        if not wanted:
            sys.exit("give at least one four-char tag")
        for rom_dir, rom_index, vtable, ftable in tables:
            for fid in range(min(len(vtable), len(ftable) // 2)):
                if vtable[fid] != rom_index:
                    continue
                (v,) = struct.unpack_from("<H", ftable, fid * 2)
                path = os.path.join(root, rom_dir, str(v >> 7), f"{v & 0x7F}.DAT")
                try:
                    with open(path, "rb") as f:
                        data = f.read()
                except OSError:
                    continue
                hits = [n.decode("latin1") for n, k, _ in chunks(data) if k == 0x07 and n in wanted]
                if hits:
                    print(fid, os.path.relpath(path, root), sorted(set(hits)))
        return

    sys.exit(__doc__)


if __name__ == "__main__":
    main()

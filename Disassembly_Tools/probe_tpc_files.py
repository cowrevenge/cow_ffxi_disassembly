#!/usr/bin/env python3
"""Probe (event pass T2/E6): check which scheduler chunk names live in the Tpc-mapped
file ids for packages 12 and 20, against the retail install.

Re-runs the E6 cross-check recorded in docs/tpc_package_table.md:
resolves the four-band A/B file ids through VTABLE/FTABLE (vtable[id] == rom index,
ftable u16 = (dir << 7) | file), opens each mapped DAT, and lists which of tlk0 / thk1 /
kka0 it carries as a type-0x07 chunk. Self-contained chunk walker (same 16-byte header
layout as dat_routines.py). Read-only against the install; the install path is the ROOT
constant below."""
import os
import struct

ROOT = r"C:\PhoenixXI\SquareEnix\FINAL FANTASY XI"


def load_tables(root):
    tables = []
    pairs = [("", "VTABLE.DAT", "FTABLE.DAT")]
    for i in range(2, 10):
        rd = f"ROM{i}"
        pairs.append((rd, f"VTABLE{rd[3:]}.DAT", f"FTABLE{rd[3:]}.DAT"))
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
    return tables


def resolve(tables, file_id):
    for rom_dir, rom_index, vtable, ftable in tables:
        if file_id < len(vtable) and vtable[file_id] == rom_index:
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


tables = load_tables(ROOT)
print("tables:", [(t[0], len(t[2])) for t in tables])

# Tpc band bases from rva 0xD2230 (event pass): A/B per package.
def tpc_ids(val):
    bands = [
        (0, 0x46, 0x7FC8, 0x800E, 0x8054),
        (0x46, 0x8C, 0xEF39, 0xEF7F, 0xEFC5),
        (0x8C, 0xD2, 0x15711, 0x15757, 0x1579D),
        (0xD2, 0x118, 0x18F5F, 0x18FA5, 0x18FEB),
    ]
    for lo, hi, a, b1, b2 in bands:
        if lo <= val < hi:
            v = val - lo
            return (v + a, v + b1, v + b2)
    return None

wanted = {b"tlk0", b"thk1", b"kka0"}
for pkg in (12, 20):
    ids = tpc_ids(pkg)
    print(f"\npackage {pkg}: A={ids[0]} B(flag=1)={ids[1]} B(flag!=1)={ids[2]}")
    for label, fid in (("A", ids[0]), ("B1", ids[1]), ("B2", ids[2])):
        rel = resolve(tables, fid)
        if not rel:
            print(f"  {label} {fid}: unresolvable")
            continue
        path = os.path.join(ROOT, rel.replace("\\", "/"))
        try:
            with open(path, "rb") as f:
                data = f.read()
        except OSError as e:
            print(f"  {label} {fid} -> {rel}: MISSING ({e})")
            continue
        hits = sorted({n.decode("latin1") for n, k, _ in chunks(data) if k == 0x07 and n in wanted})
        allsch = [n.decode("latin1") for n, k, _ in chunks(data) if k == 0x07]
        print(f"  {label} {fid} -> {rel} ({len(data)} bytes): wanted-hits={hits}")
        print(f"      scheduler chunks: {allsch[:32]}")

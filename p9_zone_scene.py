#!/usr/bin/env python3
"""
p9_zone_scene.py - list every DAT whose scheduler routines reference movN / exNN names.

Event pass T5 (zone scene DAT, docs/event_vm.md E14): the zone scene file is expected to
hold a loop routine that references stage names mov1..mov8 and ex1a..ex3e. This scan walks every
*.DAT under the install, parses each file with dat_routines.analyze() (chunk walk + scheduler
stage-stream parse), collects the named stages referenced inside parsed routines (motion / vfx /
sound / call / ref / xref payload types) and classifies them:

  mov list = referenced names matching ^mov\\d+$
  ex list  = referenced names matching ^ex\\d[a-z]$   (ex1a..ex3e shape; NOT ex01-style ids)
  routines = the parsed type-0x07 routine (chunk) names of that file

A file is reported when it carries any movN or exNN reference. File ids are resolved through the
VTABLE/FTABLE pairs exactly like probe_tpc_files.py did for the Tpc cross-check (E6):
vtable[id] == rom index, ftable u16 = (dir << 7) | file.

Reproduces out3/p9_zone_scene_scan.md: 9 files carry movN or exNN references and only ROM\\0\\23.DAT
carries both. Note the recorded run counted 52869 scanned files; a re-run today counts more, because
this tool walks case-insensitively like dat_routines.py (the install also holds ~38 lowercase .dat
user files and 18 VTABLE/FTABLE table files). The hit list itself is unchanged.

Read-only against the install; no output is written under it.

Usage: python p9_zone_scene.py <ffxi install dir> [--out X.md]
"""
import argparse
import os
import re
import struct
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import dat_routines  # noqa: E402  (same folder; chunk walk + stage parse)

MOV_RE = re.compile(r"mov\d+$")
EX_RE = re.compile(r"ex\d[a-z]$")


def load_tables(root):
    """Return [(rom_dir_label, rom_index, vtable_bytes, ftable_bytes), ...] for every VTABLE/FTABLE
    pair present under the install (root ROM plus ROM2..ROM9)."""
    tables = []
    pairs = [("", "VTABLE.DAT", "FTABLE.DAT")]
    for i in range(2, 10):
        rd = f"ROM{i}"
        pairs.append((rd, f"VTABLE{rd[3:]}.DAT", f"FTABLE{rd[3:]}.DAT"))
    for rd, vt_name, ft_name in pairs:
        vpath = os.path.join(root, rd, vt_name) if rd else os.path.join(root, vt_name)
        fpath = os.path.join(root, rd, ft_name) if rd else os.path.join(root, ft_name)
        if not (os.path.exists(vpath) and os.path.exists(fpath)):
            continue
        with open(vpath, "rb") as f:
            vtable = f.read()
        with open(fpath, "rb") as f:
            ftable = f.read()
        rom_index = 1 if not rd else int(rd[3:])
        tables.append((rd or "ROM", rom_index, vtable, ftable))
    return tables


def build_path_to_id(tables):
    """Invert the VTABLE/FTABLE mapping: relative path (backslash form) -> global file id."""
    p2i = {}
    for label, rom_index, vtable, ftable in tables:
        for fid in range(len(vtable)):
            if vtable[fid] != rom_index:
                continue
            off = fid * 2
            if off + 2 > len(ftable):
                continue
            (v,) = struct.unpack_from("<H", ftable, off)
            rel = "%s\\%d\\%d.DAT" % (label, v >> 7, v & 0x7F)
            p2i.setdefault(rel, fid)
    return p2i


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("root", help="ffxi install dir (read-only)")
    ap.add_argument("--out", help="markdown output file (default stdout)")
    a = ap.parse_args()

    tables = load_tables(a.root)
    p2i = build_path_to_id(tables)

    dats = list(dat_routines.iter_dats(a.root))

    hits = []
    for path in sorted(dats):
        rel = os.path.relpath(path, a.root).replace("/", "\\")
        try:
            res = dat_routines.analyze(path)
        except OSError:
            continue
        if not res:
            continue
        stage_names = set()
        for r in res["routines"]:
            for st in r["stages"]:
                if "name" in st:
                    stage_names.add(st["name"])
        mov = sorted(n for n in stage_names if MOV_RE.match(n))
        ex = sorted(n for n in stage_names if EX_RE.match(n))
        routines = sorted(r["name"] for r in res["routines"])
        if mov or ex:
            hits.append((p2i.get(rel), rel, mov, ex, routines))

    lines = []
    lines.append("# p9_zone_scene_scan: DATs with movN / exNN scheduler stage names")
    lines.append("")
    lines.append("scanned %d DAT files under %s" % (len(dats), a.root.replace("/", "\\")))
    lines.append("%d files carry movN or exNN stages:" % len(hits))
    lines.append("")
    for fid, rel, mov, ex, routines in hits:
        idpart = ("%6d" % fid) if fid is not None else "     -"
        lines.append("- id=%s  %s  mov=%s ex=%s routines=%s" % (idpart, rel, mov, ex, routines))
    both = [(fid, rel) for fid, rel, mov, ex, _ in hits if mov and ex]
    lines.append("")
    lines.append("files with BOTH movN and exNN: %d" % len(both))
    for fid, rel in both:
        idpart = ("%6d" % fid) if fid is not None else "     -"
        lines.append("- id=%s  %s" % (idpart, rel))

    text = "\n".join(lines) + "\n"
    if a.out:
        with open(a.out, "w", encoding="utf-8") as f:
            f.write(text)
        print("wrote %s (%d hits)" % (a.out, len(hits)))
    else:
        sys.stdout.write(text)


if __name__ == "__main__":
    main()

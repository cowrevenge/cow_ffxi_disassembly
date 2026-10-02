"""Parse a scheduler scene DAT (chunk stream + 0x07 routine stage streams) and census its
camera routes.

Default target is the global zone scene file ROM\\0\\23.DAT (E14/E18): of all 52869 install
DATs it alone carries the movN + exNN routine set, and every camera route referenced by a
routine's 0x04 stage is defined as a 0x06 chunk in this same file.

Usage:
    python scene_dat_parse.py [--dat PATH] [--sql PATH] [--out PATH]

Defaults: --dat = the install ROM\\0\\23.DAT, --sql = vendor/server/sql/zone_settings.sql,
--out = out3/d_scene23_full.md next to this script. The report is written to --out and a
one-line summary goes to stdout. Backs E18; re-running regenerates the canonical evidence
file from the current install DAT and zone table.

Chunk layout (verified against this file): u32 header at chunk start, low byte = type, next
bytes carry length in 16-byte units ((h >> 7) & 0x7FFFF). Type 0x06 = camera route, 0x07 =
scheduler routine, 0x2F = float/name data. A 0x07 chunk's stage stream starts at the u32
stored at chunk+0x24 (an offset from the chunk start); each stage is a u32 header whose low
byte is the stage type and next byte the length in dwords; type 0 ends the routine. Stage
0x04 ("play this route") carries delay u16 @+4, dur u16 @+6, route FourCC @+8 (cexi-docs
scene_dat_writer.md framing, confirmed by the retail idiom "04 (D,D) move / 04 (D,0) hold").
"""
import argparse
import collections
import os
import re
import struct

DEFAULT_DAT = r"C:\PhoenixXI\SquareEnix\FINAL FANTASY XI\ROM\0\23.DAT"
DEFAULT_SQL = os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "..", "vendor", "server", "sql", "zone_settings.sql"
)
DEFAULT_OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "out3", "d_scene23_full.md")


def u16(b, o):
    return struct.unpack_from("<H", b, o)[0] if o + 2 <= len(b) else None


def u32(b, o):
    return struct.unpack_from("<I", b, o)[0] if o + 4 <= len(b) else None


def fourcc(b):
    return "".join(chr(c) if 0x20 <= c < 0x7F else "." for c in b[:4])


def printable_fourcc(b):
    s = fourcc(b)
    return s if all(0x20 <= ord(c) < 0x7F for c in s) else None


def parse_chunks(data):
    chunks = []
    o = 0
    n = len(data)
    while o + 16 <= n:
        h = u32(data, o + 4)
        if h is None:
            break
        typ = h & 0x7F
        ln = ((h >> 7) & 0x7FFFF) * 16
        if ln == 0 or o + ln > n:
            break
        chunks.append((o, data[o:o + 4], typ, ln))
        o += ln
        if typ == 0:
            break
    return chunks


def parse_stages(data, off, ln):
    """Stage stream of one 0x07 routine chunk; returns a list of stage dicts."""
    stage_off = u32(data, off + 0x24)
    s = off + stage_off
    e = off + ln
    stages = []
    p = s
    while p + 4 <= e:
        h = u32(data, p)
        styp = h & 0xFF
        slen = (h >> 8) & 0xFF
        if styp == 0:
            stages.append({"off": p, "type": 0, "len": 0})
            break
        if h >> 16 != 0 or slen == 0:
            break
        end = p + slen * 4
        if end > e:
            break
        st = {"off": p, "type": styp, "len": slen}
        if styp in (0x03, 0x57, 0x09, 0x3B, 0x04, 0x7E) and slen >= 3:
            st["timing"] = u32(data, p + 4)
            st["name"] = fourcc(data[p + 8:p + 12])
        if styp == 0x04 and slen >= 3:
            st["delay"] = u16(data, p + 4)
            st["dur"] = u16(data, p + 6)
        stages.append(st)
        p = end
    return stages


def load_zone_names(sql_path):
    """zone id -> channel name from the vendor zone_settings.sql dump."""
    pat = re.compile(r"INSERT INTO `zone_settings` VALUES \((\d+),\d+,'[^']*',\d+,'([^']*)'")
    zones = {}
    with open(sql_path, encoding="utf-8", errors="replace") as f:
        for line in f:
            m = pat.search(line)
            if m:
                zones[int(m.group(1))] = m.group(2)
    return zones


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--dat", default=DEFAULT_DAT, help="scene DAT to parse")
    ap.add_argument("--sql", default=DEFAULT_SQL, help="zone_settings.sql for the zone-name census")
    ap.add_argument("--out", default=DEFAULT_OUT, help="where to write the report")
    a = ap.parse_args()

    data = open(a.dat, "rb").read()
    chunks = parse_chunks(data)
    type_hist = collections.Counter(c[2] for c in chunks)
    zones = load_zone_names(a.sql) if os.path.exists(a.sql) else {}

    out = []
    out.append("# scene_dat_parse report: %s" % a.dat)
    out.append("")
    out.append("file size: %d bytes; total chunks: %d" % (len(data), len(chunks)))
    out.append("chunk types: " + ", ".join(
        "0x%02X x%d" % (t, n) for t, n in sorted(type_hist.items())))
    out.append("")

    all_refs = collections.Counter()
    stage_type_hist = collections.Counter()
    routine_refs = {}
    for off, name, typ, ln in chunks:
        if typ != 0x07:
            continue
        nm = fourcc(name)
        stages = parse_stages(data, off, ln)
        n_cam = sum(1 for st in stages if st["type"] == 0x04)
        out.append("### %s (%d stages, %d camera refs)" % (nm, len(stages), n_cam))
        refs = []
        for st in stages:
            t = st["type"]
            stage_type_hist[t] += 1
            if t == 0x01:
                out.append("    hdr")
            elif t == 0:
                out.append("    end (terminator)")
            elif t == 0x04:
                all_refs[st["name"]] += 1
                refs.append("%s(%d,%d)" % (st["name"], st["delay"], st["dur"]))
                out.append("    CAMERA name=%s delay=%d dur=%d" % (st["name"], st["delay"], st["dur"]))
            elif t in (0x03, 0x57, 0x09, 0x3B):
                out.append("    ref-%02X name=%s timing=0x%08X" % (t, st["name"], st.get("timing", 0)))
            elif t == 0x7E:
                out.append("    ref-7E name=%s (a 0x2F chunk)" % st["name"])
            else:
                raw = data[st["off"]:min(st["off"] + st["len"] * 4, off + ln)]
                line = "    0x%02X (%d dw) %s" % (t, st["len"], raw[4:min(len(raw), 16)].hex(" "))
                if t in (0x7C, 0x7D):
                    s = printable_fourcc(data[st["off"] + 8:st["off"] + 12])
                    if s:
                        line += ' ; "%s"' % s
                out.append(line)
        routine_refs[nm] = refs
    out.append("")

    # census of 0x06 camera chunk names
    names = [fourcc(c[1]) for c in chunks if c[2] == 0x06]
    pat = re.compile(r"^([0-9a-f]{2})([0-9]{2})$")
    hexish, nonhex = [], []
    for nm in names:
        m = pat.match(nm)
        if m:
            hexish.append((int(m.group(1), 16), int(m.group(2)), nm))
        else:
            nonhex.append(nm)
    prefixes = collections.Counter(z for z, _, _ in hexish)

    out.append("## census")
    out.append("")
    out.append("camera chunks (0x06): %d total; matching ^[0-9a-f]{2}[0-9]{2}$: %d; other: %d" % (
        len(names), len(hexish), len(nonhex)))
    out.append("distinct hex prefixes (as zone ids, with route counts): " + ", ".join(
        "0x%02X=%d x%d" % (z, z, prefixes[z]) for z in sorted(prefixes)))
    bad = [z for z in prefixes if z > 299]
    out.append("prefixes > 299 (not a valid zone id): " + (", ".join("0x%02X" % z for z in bad) or "none"))
    out.append("")
    out.append("non-hex camera names: " + " ".join(sorted(nonhex)))
    out.append("")

    # hex prefix -> zone id -> channel name (vendor zone_settings.sql)
    out.append("## hex prefix -> zone id -> channel name")
    out.append("")
    if zones:
        for z in sorted(prefixes):
            nm = zones.get(z, "(not in zone table)")
            out.append("  0x%02X = %3d  %s" % (z, z, nm))
    else:
        out.append("(zone_settings.sql not found; names omitted)")
    out.append("")

    # stage type histogram across all routines
    out.append("stage type histogram across all routines: " + ", ".join(
        "0x%02X x%d" % (t, n) for t, n in sorted(stage_type_hist.items())))
    out.append("")

    # routine -> camera route refs (name, delay u16, dur u16), chunk order
    out.append("routine -> camera route refs (name, delay u16, dur u16):")
    for off, name, typ, ln in chunks:
        if typ != 0x07:
            continue
        nm = fourcc(name)
        out.append("  %s: %s" % (nm, ", ".join(routine_refs[nm]) or "(none)"))
    out.append("")

    # every 0x04 reference must be defined as a 0x06 chunk in this file
    defined = set(names)
    missing = sorted(set(all_refs) - defined)
    out.append("## 0x04 route references vs 0x06 definitions")
    out.append("")
    out.append("%d distinct routes referenced by 0x04 stages; %d not defined in this file: %s" % (
        len(all_refs), len(missing), ", ".join(missing) or "none"))
    for nm in sorted(all_refs):
        out.append("  %s: %d (%s)" % (nm, all_refs[nm], "defined" if nm in defined else "NOT-DEFINED"))

    text = "\n".join(out) + "\n"
    with open(a.out, "w", encoding="utf-8") as f:
        f.write(text)
    print("wrote %s (%d chunks, %d routines, %d camera refs)" % (
        a.out, len(chunks), sum(1 for c in chunks if c[2] == 0x07), sum(all_refs.values())))


if __name__ == "__main__":
    main()

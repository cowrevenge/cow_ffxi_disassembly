#!/usr/bin/env python3
"""
dat_routines.py - dump FFXI model DATs into sections: chunk table + scheduler routines + clip names.

Companion to docs/mob_animation.md (next to this script; F46: runtime routine record = stage stream; F37/F50-F52: which
routine names the client asks for). The point is to see, per model DAT, which routine names it
ships (init, ini1, atk0, dam?, hit?, sp??, hen0, ...) and what each routine plays, so the kuluu
driver can stay generic: the client asks for a name, the DAT either has it or it doesn't.

Usage
  python dat_routines.py <file.DAT> [--out X.md]                 one file, full detail
  python dat_routines.py <ffxi install or ROM dir> --scan        every *.DAT under it (only files
        [--out X.md] [--csv X.csv] [--min-routines N]            with >= N parsed routines are listed)
  add --hex to include the raw stage bytes of every routine (for format work)

Chunk header (POLUtils/xi-tinkerer layout, 16 bytes): name[4], u32 h (type = h & 0x7F,
length = ((h >> 7) & 0x7FFFF) * 16 incl. header), u32, u32. Type 0 = terminator.
Scheduler chunk (type 0x07) layout, verified on real mob DATs 2026-09-09:
  +00 name[4] +04 type|len      +10..+1F zero
  +20 u32 0x40 (stage area offset from chunk start)   +24 u32 0x50 (first real stage offset)
  +28 u32 body length (= chunk len - 0x10)            +2C u32 (count/flags)
  +40 0x00000100 (type 0 len 1 marker) + 12 zero bytes, then stages from +50.
Stage: u32 header, low byte = type, next byte = length in dwords (header included); a type-0 header
ends the stream. Types seen: 0x01 hdr, 0x02 vfx (timing @+4, generator name @+8), 0x03 call another
routine by name (@+8; timing @+4 = start frame), 0x05 motion (timing @+4, clip name @+8 with '?'
wildcard), 0x0A sound (@+4 flag, @+8 = 4 ASCII digits for a global SE file or a 4-char name of a
type-0x3D sound chunk in the same DAT), 0x57 call variant (name @+8), 0x5F reference/call variant
(name @+8, seen as the dig<->pop cross reference), 0x3D/0x3E group begin/end (random pick?), 0x50,
0x59 animation lock (the ActionTimer1 lock; duration in the payload, in 60/s scheduler ticks),
0x09 / 0x3B references by name (@+8), 0x28 / 0x29 colour-ish (0x80808080 payload), 0x24, 0x32, 0x78, 0x07,
0x1F, 0x20, 0x21, 0x2F, 0x59 unknown. Full-install census 2026-09-09: names that no DAT defines = client built-ins: proc, wash, waso, hwat,
mloc, aloc, dcnt, hwmg, hwpc, hwso, rloc, ldad, show, au??; common effect library = ROM/0/0.DAT
(ner?, eis?, st??, hit1-9, sb0?, nerm, stnm, pop1, ...), ROM/90/57.DAT (mdam); dada is defined in 3 files only.
Names a routine calls need not exist in the same DAT (hwat, aloc,
dada, nerm, ner1-5, eis2-6, st??, sei5, mloc, hit2, lhit): those resolve in shared/common DATs.
Other chunk types: 0x20 skeleton, 0x29 (skeleton-adjacent), 0x2A mesh, 0x2B motion clip (names
idl0 wlk0 run0 at00 at10 at20 btl0 ded0 cor0 ...), 0x3D sound sample (dam1-4 atk1-4 swy1-3 ...),
0x45 info, 0x00 terminator. Non-0x07 chunks are still probed for stage streams, so a scheduler under
another id would be reported with that id.
"""
import argparse, csv, mmap, os, struct, sys
from collections import Counter, defaultdict

STAGE_NAMES = {0x00: 'end', 0x01: 'hdr', 0x5F: 'xref', 0x05: 'motion', 0x0A: 'sound', 0x02: 'vfx',
               0x03: 'call', 0x57: 'call57', 0x3D: 'grp-begin', 0x3E: 'grp-end', 0x50: 'grp-sep',
               0x07: 'unk07', 0x1F: 'unk1F', 0x29: 'unk29', 0x24: 'unk24', 0x32: 'unk32', 0x78: 'unk78'}
ALL_TYPES = False
KNOWN_PAYLOAD = {0x5F, 0x05, 0x0A, 0x02, 0x03, 0x57, 0x09, 0x3B}
STAGE_NAMES.update({0x59: 'anim-lock', 0x09: 'ref09', 0x3B: 'ref3B', 0x28: 'unk28', 0x21: 'unk21', 0x20: 'unk20', 0x2F: 'unk2F', 0x59: 'unk59'})

def fourcc(b):
    return ''.join(chr(c) if 0x20 <= c < 0x7F else '.' for c in b[:4])

def is_namey(s):
    return all(c.isalnum() or c in '?!_ -' for c in s) and any(c.isalpha() for c in s)

def u32(m, o):
    return struct.unpack_from('<I', m, o)[0] if o + 4 <= len(m) else None

# ---------------------------------------------------------------- chunk walk
def walk_chunks(m):
    """Yield (offset, name, type, length) for the top-level chunk sequence. Stops at type 0, at a
    header that does not look like one, or at EOF."""
    o = 0
    n = len(m)
    while o + 16 <= n:
        name = m[o:o+4]
        h = u32(m, o + 4)
        typ = h & 0x7F
        ln = ((h >> 7) & 0x7FFFF) * 16
        if ln == 0 or o + ln > n:
            # Not a chunk header; give up on this file.
            return
        yield o, fourcc(name), typ, ln
        o += ln
        if typ == 0:
            # 'end.' marker; some files carry another section after it
            if o + 16 <= n and (u32(m, o + 4) or 0) & 0x7F != 0 and ((u32(m, o + 4) >> 7) & 0x7FFFF) > 0:
                continue
            return

# ---------------------------------------------------------------- stage stream
def parse_stages(body, start):
    """Try to parse body[start:] as a stage stream. Returns (stages, consumed) or (None, 0)."""
    stages = []
    o = start
    n = len(body)
    known = 0
    while o + 4 <= n:
        h = u32(body, o)
        typ = h & 0xFF
        ln = (h >> 8) & 0xFF
        if h >> 16 != 0 or ln == 0:
            break
        end = o + ln * 4
        if end > n:
            break
        if typ == 0:
            stages.append({'off': o, 'type': 0, 'len': ln, 'raw': body[o:end]})
            o = end
            break
        st = {'off': o, 'type': typ, 'len': ln, 'raw': body[o:end]}
        if typ in KNOWN_PAYLOAD and ln >= 3:
            st['timing'] = u32(body, o + 4)
            st['name'] = fourcc(body[o+8:o+12])
            known += 1
        stages.append(st)
        o = end
    if known == 0 or len(stages) < 2:
        return None, 0
    return stages, o

def find_routine(body):
    """Scheduler chunks point at their first stage via u32 @chunk+0x24 (= body+0x14); fall back to
    probing when that pointer is not plausible."""
    best = None
    starts = []
    p = u32(body, 0x14)
    if p is not None and 0x10 <= p < len(body) + 16 and p % 4 == 0:
        starts.append(p - 16)
    starts += [x for x in range(0, min(0x60, len(body)), 4) if x not in starts]
    for start in starts:
        stages, consumed = parse_stages(body, start)
        if stages:
            cov = (consumed - start) / max(1, len(body) - start)
            score = (sum(1 for s in stages if s['type'] in KNOWN_PAYLOAD), cov)
            if best is None or score > best[0]:
                best = (score, start, stages, consumed)
    if best is None:
        return None
    _, start, stages, consumed = best
    return {'start': start, 'stages': stages, 'consumed': consumed}

def describe_stage(st):
    t = STAGE_NAMES.get(st['type'], '0x%02X' % st['type'])
    if st['type'] == 0x05:
        tm = st['timing']
        return "motion %-4s  frames=%d lo=%d (0x%08X)" % (st['name'], tm >> 16, tm & 0xFFFF, tm)
    if st['type'] == 0x0A:
        nm = st['name']
        kind = 'se-file' if nm.strip('.').isdigit() else 'dat-sound'
        return "sound %-4s  (%s) flag=0x%X" % (nm, kind, st['timing'])
    if st['type'] in (0x03, 0x57, 0x09, 0x3B):
        return "%-6s %-4s  at=%d (timing 0x%08X)" % (STAGE_NAMES[st['type']], st['name'], st['timing'] & 0xFFFF, st['timing'])
    if st['type'] == 0x00:
        return "end"
    if st['type'] == 0x59:
        return "anim-lock  dur=%d ticks (0x%08X)" % (u32(st['raw'], 4) >> 16, u32(st['raw'], 4))
    if st['type'] == 0x02:
        tm = st['timing']
        return "vfx   %-4s  start_frame?=%d arg=%d (timing 0x%08X)" % (st['name'], tm >> 16, tm & 0xFFFF, tm)
    if st['type'] == 0x5F:
        return "xref  %-4s  (sibling routine)" % st['name']
    return "%-9s (%d dw) %s" % (t, st['len'], st['raw'][4:min(len(st['raw']), 20)].hex(' '))

# ---------------------------------------------------------------- per file
def analyze(path, want_hex=False):
    with open(path, 'rb') as f:
        try:
            m = mmap.mmap(f.fileno(), 0, access=mmap.ACCESS_READ)
        except ValueError:
            return None
        try:
            return analyze_mem(m, path, want_hex)
        finally:
            m.close()

def analyze_mem(m, path, want_hex=False):
    chunks = list(walk_chunks(m))
    if not chunks:
        return None
    res = {'path': path, 'size': len(m), 'chunks': chunks, 'routines': [], 'names_by_type': defaultdict(list)}
    for off, name, typ, ln in chunks:
        if typ != 0 and is_namey(name):
            res['names_by_type'][typ].append(name)
        body_len = ln - 16
        if typ == 0 or body_len < 12 or body_len > 0x8000:
            continue
        # Only scheduler chunks (type 0x07) count as routines. The first full scan showed that big
        # motion/mesh bodies (hh_b, sp00, ...) occasionally parse as a stream by accident and polluted
        # the census; other types are still probed but reported under 'suspect' only with --all-types.
        if typ != 0x07 and not ALL_TYPES:
            continue
        body = bytes(m[off+16:off+ln])
        r = find_routine(body)
        if r and typ != 0x07 and (r['consumed'] - r['start']) < 0.8 * (len(body) - r['start']):
            r = None
        if r:
            r.update({'name': name, 'type': typ, 'off': off, 'len': ln})
            if want_hex:
                r['hex'] = body[:min(len(body), 0x200)].hex(' ')
            res['routines'].append(r)
    return res

def render_file(res, want_hex=False):
    out = []
    out.append("## %s  (%d bytes, %d chunks, %d routines)\n" % (res['path'], res['size'], len(res['chunks']), len(res['routines'])))
    typ_hist = Counter(t for _, _, t, _ in res['chunks'])
    out.append("chunk types: " + ', '.join("0x%02X x%d" % (t, c) for t, c in sorted(typ_hist.items())) + "\n")
    labels = {0x07: 'routines', 0x2B: 'motion clips', 0x3D: 'sound samples', 0x20: 'skeleton', 0x2A: 'meshes',
              0x29: 'skeleton-adjacent', 0x05: 'generators?', 0x45: 'info', 0x01: 'marker'}
    for typ, names in sorted(res['names_by_type'].items()):
        out.append("type 0x%02X %-16s (%d): %s" % (typ, labels.get(typ, '?'), len(names), ' '.join(names[:120]) + (' ...' if len(names) > 120 else '')))
    out.append("")
    for r in res['routines']:
        st_desc = [describe_stage(s) for s in r['stages']]
        cov = r['consumed'] - r['start']
        out.append("### routine `%s`  chunk type 0x%02X @0x%X len 0x%X, stream @+0x%X (%d stages, %d/%d body bytes)" %
                   (r['name'], r['type'], r['off'], r['len'], 16 + r['start'], len(r['stages']), cov, r['len'] - 16))
        for d in st_desc:
            out.append("    " + d)
        if want_hex and 'hex' in r:
            out.append("    hex: " + r['hex'])
        out.append("")
    return '\n'.join(out)

# ---------------------------------------------------------------- scan
def iter_dats(root):
    if os.path.isfile(root):
        yield root
        return
    for dp, dn, fn in os.walk(root):
        for f in fn:
            if f.upper().endswith('.DAT'):
                yield os.path.join(dp, f)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('path')
    ap.add_argument('--scan', action='store_true', help='walk every *.DAT under path')
    ap.add_argument('--out', help='markdown output file (default stdout)')
    ap.add_argument('--csv', help='routine summary CSV (scan mode)')
    ap.add_argument('--min-routines', type=int, default=1)
    ap.add_argument('--hex', action='store_true')
    ap.add_argument('--quiet', action='store_true')
    ap.add_argument('--all-types', action='store_true', help='also report stage streams found in non-0x07 chunks')
    a = ap.parse_args()
    global ALL_TYPES
    ALL_TYPES = a.all_types

    files = list(iter_dats(a.path)) if a.scan else [a.path]
    md = ["# dat_routines dump of %s (%d files considered)\n" % (a.path, len(files))]
    rows = []
    family = Counter()      # routine name -> number of files shipping it
    total = 0
    for i, p in enumerate(files):
        try:
            res = analyze(p, a.hex)
        except Exception as e:  # keep scanning
            if not a.quiet:
                print("ERR", p, e, file=sys.stderr)
            continue
        if not res:
            continue
        if len(res['routines']) < a.min_routines:
            continue
        total += 1
        md.append(render_file(res, a.hex))
        seen = set()
        for r in res['routines']:
            if r['name'] not in seen:
                family[r['name']] += 1
                seen.add(r['name'])
            for s in r['stages']:
                if s['type'] in KNOWN_PAYLOAD:
                    rows.append([p, r['name'], "0x%02X" % r['type'], STAGE_NAMES[s['type']], s['name'], "0x%08X" % s['timing']])
        if not a.quiet and a.scan and i % 500 == 0:
            print("... %d/%d files, %d with routines" % (i, len(files), total), file=sys.stderr)
    if a.scan:
        md.insert(1, "## routine name families (files shipping each name)\n\n" +
                  '\n'.join("- `%s`: %d" % (n, c) for n, c in sorted(family.items(), key=lambda x: (-x[1], x[0]))) + "\n")
    text = '\n'.join(md)
    if a.out:
        with open(a.out, 'w', encoding='utf-8') as f:
            f.write(text)
        print("wrote", a.out, "(%d files with routines)" % total)
    else:
        print(text)
    if a.csv:
        with open(a.csv, 'w', newline='', encoding='utf-8') as f:
            w = csv.writer(f)
            w.writerow(['file', 'routine', 'chunk_type', 'stage', 'name', 'timing'])
            w.writerows(rows)
        print("wrote", a.csv, "(%d stage rows)" % len(rows))

if __name__ == '__main__':
    main()

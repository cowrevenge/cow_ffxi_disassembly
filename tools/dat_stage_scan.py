#!/usr/bin/env python3
"""dat_stage_scan.py - census authored-magnitude evidence in a `dat_routines --scan` dump.

Companion to docs/drivetask.md §9-§10 (DAT pass). Input is the **markdown** dump kuluu's reader produces
(`python cow_tools/ffxi_disasm/dat_routines.py <install> --scan [--all-types] --out stages.md`): that dump,
not the CSV, carries every stage line including unknown stage types. A stage line looks like

    0xA9      (6 dw) 3c 00 c0 03 ...        # label padded; bytes are raw file order

and record base = the header dword, so printed payload dword *i* sits at record offset 4+4i. Payloads are
now printed in full; dumps made before that fix capped at four dwords (see §9.4).

**Filter by chunk type.** Only chunk `0x07` bodies are real scheduler stage streams. With --all-types, motion
clip (`0x2B`) / generator (`0x05`) and other bodies also parse as "routines", and their stage lines look
plausible but declare absurd lengths (up to 191 dwords). Mixing them into a census silently corrupts counts,
so the tool tallies per chunk type and flags suspect ones. `--chunk` restricts every stat below.

Usage
    python tools/dat_stage_scan.py <stages.md> [--chunk 07[,2B]] [--degrees 30,45,60,90,135]
"""
import argparse, re, struct
from collections import Counter, defaultdict

LINE = re.compile(r'^    (.+?) +\((\d+) dw\) ([0-9a-f]{2}(?: [0-9a-f]{2})*)\s*$')
ROUTINE = re.compile(r'^### routine `[^`]*` +chunk type (0x[0-9A-F]{2}) ')
TYPEOF = re.compile(r'^(?:unk|0x)([0-9A-F]{2})$')

def dwords(hx):
    b = bytes.fromhex(hx)
    return [b[i:i+4] for i in range(0, len(b)-len(b)%4, 4)]

def plausible_float(d):                    # exponent-byte window ~1e-6 .. ~384, either sign
    h = d[3]
    return 0x3D <= h <= 0x43 or 0xBD <= h <= 0xC3

def longest_run(ds):
    best = cur = 0
    for d in ds:
        cur = cur + 1 if plausible_float(d) else 0
        best = max(best, cur)
    return best

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('dump')
    ap.add_argument('--chunk', default='', help='restrict to these routine chunk types, e.g. 07 (or 07,2B)')
    ap.add_argument('--degrees', default='30,45,60,90,135,22.5,36,15,12,10,20,24')
    a = ap.parse_args()
    want_chunk = {c.upper().replace('0X', '') for c in a.chunk.split(',') if c}

    wanted = {}
    for x in [float(y) for y in a.degrees.split(',')]:
        for s in (1.0, -1.0):
            wanted[struct.pack('<f', s*x).hex(' ')] = '%g' % (s*x)

    cur_chunk = ''
    routines_all, routines_kept = Counter(), Counter()
    lines_by_type, lens, band = Counter(), defaultdict(Counter), Counter()
    runs, trunc, suspect = Counter(), Counter(), Counter()
    angle_hits, by_type_vals = Counter(), defaultdict(Counter)
    kept_lines = skipped_lines = 0

    with open(a.dump, encoding='utf-8', errors='replace') as f:
        for ln in f:
            m = ROUTINE.match(ln)
            if m:
                ct = m.group(1)[2:]
                cur_chunk = ct
                routines_all[ct] += 1
                if not want_chunk or ct in want_chunk:
                    routines_kept[ct] += 1
                continue
            m = LINE.match(ln)
            if not m:
                continue
            if want_chunk and cur_chunk not in want_chunk:
                skipped_lines += 1
                continue
            label, n_dw, hx = m.group(1).strip(), int(m.group(2)), m.group(3)
            kept_lines += 1
            lines_by_type[label] += 1; lens[label][n_dw] += 1
            runs[longest_run(dwords(hx))] += 1
            trunc['payload>4dw' if n_dw - 1 > 4 else 'payload<=4dw'] += 1
            if cur_chunk != '07' and n_dw >= 16:
                # absurd for a real scheduler stream; chunk 0x07 legitimately ships long records (up to
                # payload 21 dwords), so it is excluded here rather than flagged.
                suspect['%s len=%d' % (cur_chunk, n_dw)] += 1
            t = TYPEOF.match(label)
            if t and 0xA0 <= int(t.group(1), 16) <= 0xB7:
                band['%02X' % int(t.group(1), 16)] += 1
            for d in dwords(hx):                 # aligned-only exact float equality
                name = wanted.get(d.hex(' '))
                if name:
                    angle_hits[name] += 1; by_type_vals[label][name] += 1

    print('== audit ==')
    print('stage lines kept: %d (skipped %d)' % (kept_lines, skipped_lines))
    print('routines kept by chunk type: %s' % dict(routines_kept.most_common()))
    if not want_chunk and len(routines_all) > 1:
        print('WARNING: unfiltered dump mixes non-scheduler bodies; use --chunk 07 for scheduler truth.')
        print('suspect (declared length >= 16 dwords, by chunk type/length): %s'
              % dict(suspect.most_common(8)))
    print(dict(trunc.most_common()))

    print('\n== markers predicted from jump-table case indices (§8, falsified) ==')
    for lbl in ('0x87', '0xA8'):
        print('  %-5s lines=%-4d lens=%s' % (lbl, lines_by_type.get(lbl, 0), dict(lens.get(lbl, {}))))

    print('\n== band 0xA0..0xB7 stage types present ==')
    print('  ' + '  '.join('%s x%d' % kv for kv in sorted(band.items())))
    print('  absent: ' + ' '.join('%02X' % x for x in range(0xA0, 0xB8) if '%02X' % x not in band))

    print('\n== longest consecutive plausible-float dwords per stage line ==')
    for r in sorted(runs):
        print('  run>=%d: %d lines' % (r, runs[r]))

    print('\n== exact round-degree float matches (aligned) ==')
    for name, c in angle_hits.most_common():
        print('  %-8s %6d' % (name, c))
    print('\n== which stage types carry them ==')
    for lbl in sorted(by_type_vals, key=lambda x: -sum(by_type_vals[x].values()))[:12]:
        print('  %-8s total %6d  vals %s' % (lbl, sum(by_type_vals[lbl].values()), dict(by_type_vals[lbl].most_common(7))))

if __name__ == '__main__':
    main()

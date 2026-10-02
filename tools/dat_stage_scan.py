#!/usr/bin/env python3
"""dat_stage_scan.py - census the authored-magnitude evidence in a `dat_routines --scan --hex` dump.

Companion to docs/drivetask.md §9 (DAT pass). Input is the **markdown** dump that kuluu's vendor reader
produces (`ffxi_disassembly/dat_routines.py <install> --scan --hex --out stages.md`), because that dump -
not the CSV - carries every stage line, including unknown stage types. Buffer notes: a stage line looks
like `    0xA9      (6 dw) <bytes...>`; bytes are raw file order and cover only `raw[4:20]`, i.e. the
first four payload dwords (see §9.4 blind spot). Record base = header dword, so printed payload dword *i*
sits at record offset 4+4i.

Usage
    python tools/dat_stage_scan.py <stages.md> [--degrees 30,45,60,90,135] [--float-window 2 3]

Prints: parse audit / marker counts for the (falsified) op-135/op-168 stage bytes and their whole
neighbourhood band / longest consecutive plausible-float runs per stage line with truncation buckets /
exact IEEE-754 matches of round degree values, aligned to the dword grid.
"""
import argparse, re, struct
from collections import Counter, defaultdict

LINE = re.compile(r'^    (.+?) +\((\d+) dw\) ([0-9a-f]{2}(?: [0-9a-f]{2})*)\s*$')
TYPEOF = re.compile(r'^(?:unk|0x)([0-9A-F]{2})$')

def dwords(hx):                                   # -> list of 4-byte little-endian payload chunks
    b = bytes.fromhex(hx)
    return [b[i:i+4] for i in range(0, len(b)-len(b)%4, 4)]

def plausible_float(d):                           # exponent byte window ~1e-6 .. ~384, either sign
    h = d[3]
    return 0x3D <= h <= 0x43 or 0xBD <= h <= 0xC3

def longest_run(ds):                              # longest run of consecutive plausible-float dwords
    best = cur = 0
    for d in ds:
        cur = cur + 1 if plausible_float(d) else 0
        best = max(best, cur)
    return best

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('dump')
    ap.add_argument('--degrees', default='30,45,60,90,135,22.5,36,15,12,10,20,24')
    a = ap.parse_args()

    wanted = {}                                   # exact byte pattern -> label (both signs)
    for x in [float(y) for y in a.degrees.split(',')]:
        for s in (1.0, -1.0):
            wanted[struct.pack('<f', s*x).hex(' ')] = '%g' % (s*x)

    lines_by_type, lens = Counter(), defaultdict(Counter)
    band, runs, trunc = Counter(), Counter(), Counter()
    angle_hits, by_type_vals = Counter(), defaultdict(Counter)
    stage_lines = 0
    with open(a.dump, encoding='utf-8', errors='replace') as f:
        for ln in f:
            m = LINE.match(ln)
            if not m:
                continue
            label, n_dw, hx = m.group(1).strip(), int(m.group(2)), m.group(3)
            lines_by_type[label] += 1; lens[label][n_dw] += 1; stage_lines += 1
            ds = dwords(hx)
            runs[longest_run(ds)] += 1
            trunc['truncated' if n_dw - 1 > 4 else 'seen fully'] += 1
            t = TYPEOF.match(label)
            if t and 0xA0 <= int(t.group(1), 16) <= 0xB7:
                band['%02X' % int(t.group(1), 16)] += 1
            for d in ds:                          # aligned-only exact float equality
                name = wanted.get(d.hex(' '))
                if name:
                    angle_hits[name] += 1; by_type_vals[label][name] += 1

    print('== audit ==')
    print('stage lines: %d   (%s)' % (stage_lines, ', '.join('%s: %d' % kv for kv in sorted(trunc.items()))))
    print('\n== markers predicted from jump-table case indices (§8, falsified) ==')
    for lbl in ('0x87', '0xA8'):
        print('  %-5s lines=%-4d lens=%s' % (lbl, lines_by_type.get(lbl, 0), dict(lens.get(lbl, {}))))
    print('\n== band 0xA0..0xB7 present types ==')
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

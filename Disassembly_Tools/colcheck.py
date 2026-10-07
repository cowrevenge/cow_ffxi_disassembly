import struct, math
from collections import Counter, defaultdict
from zoneparse import load_zone, decode_1b, trs_matrix, det3, u32

def f32(b, o): return struct.unpack_from('<f', b, o)[0]

def parse_collision(mzb_raw):
    d = mzb_raw  # already decrypted by parse path; here we re-decode from chunk payload
    mesh_hdr = u32(d, 8)
    ncw, nch, cw, ch = d[0x0C], d[0x0D], d[0x0E], d[0x0F]
    tw, th = ncw*cw, nch*ch
    gw, gh = tw >> 2, th >> 2
    blocks_count  = u32(d, mesh_hdr+0)
    blocks_offset = u32(d, mesh_hdr+4)
    unk4_count    = u32(d, mesh_hdr+8)
    unk4_offset   = u32(d, mesh_hdr+12)
    grid_offset   = u32(d, mesh_hdr+16)
    pl_offset     = u32(d, mesh_hdr+20)
    pl_count      = u32(d, mesh_hdr+24)
    print(f"meshhdr@{mesh_hdr:#x} grid {gw}x{gh} cells (cell {cw}x{ch}) blocks_count={blocks_count} pl_count={pl_count} grid@{grid_offset:#x}")

    blocks = {}; placements = {}
    cells_used = 0; pairs = []
    for y in range(gh):
        for x in range(gw):
            cho = grid_offset + (y*gw + x)*4
            if cho >= len(d): break
            co = u32(d, cho)
            if co == 0 or co >= len(d): continue
            info = u32(d, co)
            n = info & 0x7FF
            cells_used += 1
            o = co + 4
            for _ in range(n):
                po = u32(d, o); bo = u32(d, o+4); o += 8
                pairs.append((po, bo))
                if bo not in blocks:
                    vo = u32(d, bo); no = u32(d, bo+4); to = u32(d, bo+8)
                    tc = struct.unpack_from('<H', d, bo+12)[0]
                    fl = struct.unpack_from('<H', d, bo+14)[0]
                    vc = (no - vo)//12; nc = (to - no)//12
                    verts = [struct.unpack_from('<3f', d, vo+i*12) for i in range(vc)]
                    tris = []
                    for i in range(tc):
                        v1, v2, v3, nn = struct.unpack_from('<4H', d, to+i*8)
                        mat = ((((nn>>15)*2 | (v3>>15))*2 | (v2>>15))*2 | (v1>>15))
                        tris.append((v1 & 0x7FFF, v2 & 0x3FFF, v3 & 0x3FFF, mat,
                                     (v2 & 0x4000) > 0, (v3 & 0x4000) > 0))
                    blocks[bo] = {'flags': fl, 'verts': verts, 'tris': tris}
                if po not in placements:
                    q = po
                    def row(qq):
                        r = struct.unpack_from('<3f', d, qq)
                        return list(r)
                    o2w = [row(q+0), row(q+16), row(q+32), row(q+48)]
                    w2o = [row(q+64), row(q+80), row(q+96), row(q+112)]
                    df   = u32(d, q+128+36)
                    miny = f32(d, q+128+36+16)
                    maxy = f32(d, q+128+36+20)
                    placements[po] = {'o2w': o2w, 'w2o': w2o, 'df': df, 'min_y': miny, 'max_y': maxy}
    print(f"cells_used={cells_used} pairs={len(pairs)} unique_blocks={len(blocks)} unique_placements={len(placements)}")
    return blocks, placements, pairs

def apply_m(m, v):
    x, y, z = v
    return (m[0][0]*x + m[1][0]*y + m[2][0]*z + m[3][0],
            m[0][1]*x + m[1][1]*y + m[2][1]*z + m[3][1],
            m[0][2]*x + m[1][2]*y + m[2][2]*z + m[3][2])

chunks, mzb, mmbs, fails = load_zone('/mnt/user-data/uploads/42.DAT')
pls, mzb_dec = mzb
blocks, cpl, pairs = parse_collision(mzb_dec)

# collision world bounds
import numpy as np
mins = np.array([1e9]*3); maxs = np.array([-1e9]*3)
for po, bo in pairs:
    p = cpl[po]; b = blocks[bo]
    for v in b['verts']:
        w = apply_m(p['o2w'], v)
        mins = np.minimum(mins, w); maxs = np.maximum(maxs, w)
print(f"\ncollision world bounds: x[{mins[0]:.1f}..{maxs[0]:.1f}] y[{mins[1]:.1f}..{maxs[1]:.1f}] z[{mins[2]:.1f}..{maxs[2]:.1f}]")
print("(his ximesh log:        x[-277.4..727.1] y[-72.2..27.0] z[-683.8..156.0])")

# material census over placed collision tris (compare his: object=1899 path=2 stone=30326 metal=1019 wood=2052 deepW=152 barrier=276)
matc = Counter(); barrier = 0; placed_tris = 0
for po, bo in pairs:
    b = blocks[bo]
    for t in b['tris']:
        placed_tris += 1
        matc[t[3]] += 1
        if t[5]: barrier += 1
print(f"placed collision tris={placed_tris} mats={dict(sorted(matc.items()))} barrier={barrier}")

# ===== the key test: baked o2w linear vs euler-derived linear =====
# match visual placements to collision placements by translation
vis_by_tr = defaultdict(list)
for p in pls:
    key = tuple(round(c, 2) for c in p['tr'])
    vis_by_tr[key].append(p)

def lin(m): return np.array([m[0], m[1], m[2]], dtype=np.float64)

cats = {'identity': [], 'yaw': [], 'full3d': []}
matched = 0
for po, cp in cpl.items():
    key = tuple(round(c, 2) for c in cp['o2w'][3])
    cands = vis_by_tr.get(key)
    if not cands: continue
    for vp in cands:
        matched += 1
        A = lin(trs_matrix(vp['tr'], vp['rot'], vp['sc']))
        C = lin(cp['o2w'])
        errA  = float(np.abs(A - C).max())
        errAT = float(np.abs(A.T - C).max())
        rx, ry, rz = vp['rot']
        if rx == 0 and rz == 0 and ry == 0: cat = 'identity'
        elif rx == 0 and rz == 0: cat = 'yaw'
        else: cat = 'full3d'
        cats[cat].append((errA, errAT, vp, cp))

print(f"\ntranslation-matched (collision placement <-> visual placement): {matched}")
for cat, rows in cats.items():
    if not rows: continue
    ea = [r[0] for r in rows]; et = [r[1] for r in rows]
    print(f"  {cat:8} n={len(rows):4d}  err(A vs o2w): max={max(ea):.5f} mean={sum(ea)/len(ea):.5f} | err(A^T vs o2w): max={max(et):.5f} mean={sum(et)/len(et):.5f}")

# show a couple of full3d examples numerically
shown = 0
for errA, errAT, vp, cp in cats['full3d']:
    if shown >= 2: break
    print(f"\n  full3d example id='{vp['id']}' tr={vp['tr']} rot=({vp['rot'][0]:.4f},{vp['rot'][1]:.4f},{vp['rot'][2]:.4f}) sc={vp['sc']}  errA={errA:.6f} errAT={errAT:.6f}")
    A = lin(trs_matrix(vp['tr'], vp['rot'], vp['sc'])); C = lin(cp['o2w'])
    for i in range(3):
        print(f"    euler-derived {np.round(A[i],4)}   baked o2w {np.round(C[i],4)}")
    shown += 1

# determinant sign agreement (mirrors)
ds = 0; dn = 0
for cat, rows in cats.items():
    for errA, errAT, vp, cp in rows:
        dn += 1
        if (det3(trs_matrix(vp['tr'], vp['rot'], vp['sc'])) > 0) == (det3(cp['o2w']) > 0): ds += 1
print(f"\ndeterminant sign agreement: {ds}/{dn}")

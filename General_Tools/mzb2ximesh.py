#!/usr/bin/env python3
"""mzb2ximesh — extract a zone's collision mesh from its .DAT (MZB chunk) into an LSB-format .ximesh.

This is how data/ximeshes/*.ximesh are made. The MZB chunk (type 0x1C, decrypted per tools/zoneparse.py)
carries the collision grid: cells -> (placementOffset, blockOffset) pairs; blocks = local-space verts +
u16 strip-tri indices with SE's packed flag bits; placements = baked o2w/w2o matrices with u16
quantization values interleaved. The .ximesh repack keeps the raw AUTHORING-frame data verbatim (our
loader applies the render-world flips at load — see ximesh.cpp getPlacement).

Repack layout (LSB src/map/ximesh/ximesh_structs.h, reference InoUno/xi-visualizer ximesh.ts):
  zlib( [XimeshHeader 20B] u16 gridW,H | u32 blockSecOff,placeSecOff | u16 blockCount,placementCount | u32 wideSearch=0
        cell table @+20: gridW*gridH x u32 (0 = empty)
        cell data:  u32 rawInfoWord, u16 n, n x {u32 blockOffset, u32 placementOffset}   <- pair order SWAPPED vs the DAT
        block:      u16 vc, u16 tc, u16 barrierFlag, u16 pad=0 | f32[3*vc] | align4 | u16[3tc] (flag bits cleared) | align4 | 1 meta byte/tri
        placement:  u32 flags (= raw word @po+164), f32[9] o2w rows verbatim, f32[3] translation row )

Verified against the pre-existing data/ximeshes/Port_Jeuno.ximesh (grid 800x800, header counts =
UNIQUE blocks/placements 1970/449 not raw totals, wideSearch=0, cell reserved word verbatim, first
placement record bit-identical file-vs-DAT).

Usage:
  python tools/mzb2ximesh.py <zone.DAT> [out.ximesh]     # one zone (default out = data/ximeshes/<name>)
  python tools/mzb2ximesh.py --all [--force]             # every row of data/zonemaps.csv
"""
import re
import struct
import sys
import zlib
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from zoneparse import load_zone, u32  # noqa: E402

ROOT = HERE.parent
XISH = ROOT / "data" / "ximeshes"


class NoCollisionGrid(ValueError):
    pass

# Canonical filenames that deviate from the sanitized-name rule (pre-existing files we keep).
NAME_OVERRIDES = {95: "West_Sarutabaruta_[S].ximesh"}  # zonemaps.csv name is "West Sarutabaruta S"


def sanitize(name: str) -> str:
    return re.sub(r"[^A-Za-z0-9\[\]]+", "_", name).strip("_") + ".ximesh"


def extract_collision(d: bytes):
    """Parse the decrypted MZB payload. Returns (gw, gh, cells, blocks, placements) where
    cells[idx] = None | (info_word, [(po_raw, bo_raw), ...]) and blocks/placements map raw offsets to
    (vc, tc, barrierFlag, verts_bytes, tris_bytes, metas_bytes) / (flags, rot+trans bytes)."""
    mesh_hdr = u32(d, 8)
    if mesh_hdr == 0:
        raise NoCollisionGrid()  # open-sea / ship zones carry an MZB but no collision grid
    if not (0x24 < mesh_hdr < len(d)):
        raise ValueError(f"mesh_hdr {mesh_hdr:#x} out of range (payload {len(d):#x})")
    ncw, nch, cw, ch = d[0x0C], d[0x0D], d[0x0E], d[0x0F]
    if not (ncw and nch and cw and ch):
        raise ValueError(f"bad grid dims ncw={ncw} nch={nch} cw={cw} ch={ch}")
    gw, gh = (ncw * cw) >> 2, (nch * ch) >> 2
    grid_off = u32(d, mesh_hdr + 16)

    cells = [None] * (gw * gh)
    blocks: dict[int, tuple] = {}
    placements: dict[int, tuple] = {}

    for y in range(gh):
        rowbase = grid_off + y * gw * 4
        if rowbase + gw * 4 > len(d):
            raise ValueError(f"grid overruns payload at cell ({y},{0})")
        for x in range(gw):
            co = u32(d, rowbase + x * 4)
            if co == 0 or co >= len(d):
                continue
            info = u32(d, co)
            n = info & 0x7FF
            o = co + 4
            if o + n * 8 > len(d):
                raise ValueError(f"cell ({y},{x}) entry list overruns payload")
            pairs = []
            for _ in range(n):
                po, bo = u32(d, o), u32(d, o + 4)
                o += 8
                pairs.append((po, bo))
                if bo not in blocks:
                    vo, no_, to_ = u32(d, bo), u32(d, bo + 4), u32(d, bo + 8)
                    tc, fl = struct.unpack_from("<HH", d, bo + 12)
                    if (no_ - vo) % 12 or not vc_ok(vo, no_, to_, tc, len(d)):
                        raise ValueError(f"block@{bo:#x}: bad geometry offsets")
                    vc = (no_ - vo) // 12
                    verts = d[vo:no_]
                    tris = bytearray(tc * 6)
                    metas = bytearray(tc)
                    for i in range(tc):
                        v1, v2, v3, nn = struct.unpack_from("<4H", d, to_ + i * 8)
                        # SE packs material into the top bit of every u16 (v1 is LSB); barrier marks live in v2/v3 bit 14.
                        mat = ((((nn >> 15) * 2 | (v3 >> 15)) * 2 | (v2 >> 15)) * 2 | (v1 >> 15)) & 0xF
                        bar = 0x10 if ((v2 & 0x4000) or (v3 & 0x4000)) else 0
                        metas[i] = mat | bar
                        struct.pack_into("<HHH", tris, i * 6, v1 & 0x7FFF, v2 & 0x3FFF, v3 & 0x3FFF)
                    blocks[bo] = (vc, tc, fl, verts, bytes(tris), bytes(metas))
                if po not in placements:
                    flags = u32(d, po + 164)
                    # o2w rows at stride 16 (3f each + interleaved quantization to drop); translation is row @+48.
                    rt = d[po + 0:po + 12] + d[po + 16:po + 28] + d[po + 32:po + 44]
                    tr = d[po + 48:po + 60]
                    placements[po] = (flags, rt + tr)
            cells[y * gw + x] = (info, pairs)
    return gw, gh, cells, blocks, placements


def vc_ok(vo, no_, to_, tc, n):
    # vo/no_/to_ are absolute offsets into the MZB payload: verts [vo,no_), tris [to_, to_+tc*8).
    return (no_ - vo) % 12 == 0 and to_ + tc * 8 <= n


def rec_size(vc: int, tc: int, start: int) -> int:
    """A block record's true size given its ABSOLUTE start offset — the loader aligns index and meta
    sections to round4(absolute position), so padding depends on where the record lands in the stream."""
    e1 = start + 8 + vc * 12            # end of vertices
    p1 = (-e1) & 3                      # pad before indices (loader: indexOffset = round4(off+8+vc*12))
    e2 = e1 + p1 + tc * 6               # end of indices
    return 8 + vc * 12 + p1 + tc * 6 + ((-e2) & 3) + tc  # header, verts, pad, idx, pad, metas


def pack_mesh(gw: int, gh: int, cells, blocks: dict, placements: dict) -> bytes:
    # File offsets of unique records (first-encounter order over the cell walk).
    celltab_len = gw * gh * 4
    celdata_len = sum(6 + len(c[1]) * 8 for c in cells if c)
    blocksec = 20 + celltab_len + celdata_len
    place_off, block_off = {}, {}
    o = blocksec
    for bo in blocks:
        vc, tc = blocks[bo][0], blocks[bo][1]
        block_off[bo] = o
        o += rec_size(vc, tc, o)
    placesec = o
    for i, po in enumerate(placements):  # placements follow blocks contiguously (52B each)
        place_off[po] = placesec + i * 52

    out = bytearray()
    # cell table + cell data (pair order swapped vs the DAT: block first, then placement)
    celltab = bytearray(celltab_len)
    cd = bytearray()
    for idx in range(gw * gh):
        c = cells[idx]
        if not c:
            continue
        info, pairs = c
        off = 20 + celltab_len + len(cd)
        struct.pack_into("<I", celltab, idx * 4, off)
        cd += struct.pack("<IH", info, len(pairs))
        for po_raw, bo_raw in pairs:
            cd += struct.pack("<II", block_off[bo_raw], place_off[po_raw])
    out += struct.pack("<HHIIHHI", gw, gh, blocksec, placesec, len(blocks), len(placements), 0)
    out += celltab
    out += cd
    for bo in blocks:
        vc, tc, fl, verts, tris, metas = blocks[bo]
        out += struct.pack("<HHHH", vc, tc, fl, 0) + verts
        while len(out) & 3:              # align indices to round4(absolute), exactly as the loader reads them
            out.append(0)
        out += tris
        while len(out) & 3:
            out.append(0)
        out += metas
    for po in placements:
        flags, rttr = placements[po]
        out += struct.pack("<I", flags) + rttr
    return bytes(out)


def make_ximesh(dat_path: Path, zid=None):
    chunks, mzb, mmbs, fails = load_zone(str(dat_path))
    if not mzb:
        raise ValueError("no MZB (0x1C) chunk in file")
    gw, gh, cells, blocks, placements = extract_collision(mzb[1])
    payload = pack_mesh(gw, gh, cells, blocks, placements)
    blob = zlib.compress(payload)

    # self-check: re-inflate + header sanity
    chk = zlib.decompress(blob)
    c_gw, c_gh, bso, pso, bc, pc, ws = struct.unpack_from("<HHIIHHI", chk, 0)
    assert (c_gw, c_gh, bc, pc) == (gw, gh, len(blocks), len(placements))
    nentries = sum(c[1] and len(c[1]) or 0 for c in cells if c)
    return blob, gw, gh, cells.count(None), nentries, len(blocks), len(placements)


def main() -> int:
    args = sys.argv[1:]
    force = "--force" in args
    args = [a for a in args if a != "--force"]

    rows = []  # (zid, dat_relpath, name)
    if args and args[0] == "--all":
        for line in (ROOT / "data" / "zonemaps.csv").read_text(encoding="utf-8").splitlines():
            if not line.strip() or line.startswith("#"):
                continue
            f = line.split(",")
            rows.append((int(f[0]), f[1], f[-1]))
    elif args:
        path = Path(args[0])
        name = path.stem  # fallback display name; caller may pass an out file too
        if len(args) > 1:
            rows.append((None, str(path), None))
            XISH.mkdir(parents=True, exist_ok=True)
            blob, gw, gh, empty, nent, nb, np_ = make_ximesh(path)
            Path(args[1]).write_bytes(blob)
            print(f"{args[0]} -> {args[1]}: grid {gw}x{gh} nonempty={gw*gh-empty} entries={nent} blocks={nb} placements={np_}")
            return 0
        rows.append((None, str(path), name))
    else:
        print(__doc__)
        return 2

    XISH.mkdir(parents=True, exist_ok=True)
    ok = skip = fail = 0
    for zid, relpath, name in rows:
        dat = ROOT / relpath if not Path(relpath).is_absolute() else Path(relpath)
        base = NAME_OVERRIDES.get(zid) if zid is not None and zid in NAME_OVERRIDES else sanitize(name or dat.stem)
        out = XISH / base
        try:
            blob, gw, gh, empty, nent, nb, np_ = make_ximesh(dat)
        except NoCollisionGrid:  # keep the batch going; report per zone
            print(f"NOGRID {relpath}: MZB has no collision grid (open sea / ship zone?)")
            skip += 1
            continue
        except Exception as e:
            print(f"FAIL {relpath}: {e}")
            fail += 1
            continue
        if out.exists() and not force:
            print(f"SKIP {out.name} (exists, --force to rewrite)")
            skip += 1
            continue
        out.write_bytes(blob)
        ok += 1
        print(f"WROTE {out.name}: grid {gw}x{gh} nonempty={gw*gh-empty} entries={nent} blocks={nb} placements={np_}")
    print(f"\nsummary: wrote={ok} skipped={skip} failed={fail} of {len(rows)} zones")
    return 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""
dat_to_png.py — Extract textures from FFXI zone .DAT files (raw ROM chunk
containers). Auto-detects the per-record format:

  - dxt3      DXT3/BC2 blocks   ('3TXD' discriminator, e.g. Port Jeuno t_ju)
  - 8bpp_pal  8bpp + BGRA palette (u32 0x20 discriminator, e.g. tower zones,
              and Jeuno's sky/effect records — one file can mix BOTH)

Requires texfmt.py next to this script.

Emits:
    <out>/<dat_stem>/manifest.json
    <out>/<dat_stem>/<category>/<name>_<w>x<h>.png

Usage:
    python dat_to_png.py 42_jeuno.DAT 42_tower.DAT --out ./tex_out
"""

import argparse
import hashlib
import json
import sys
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    sys.stderr.write("Pillow not installed. Run: pip install Pillow\n")
    sys.exit(1)

sys.path.insert(0, str(Path(__file__).resolve().parent))
from texfmt import TEX_CHUNK_TYPE, parse_texture, sniff_texture, walk_chunks  # noqa: E402


# ---------------------------------------------------------------------------
# Category assignment. Known names first (POSITIONAL-TEXTURES §3), prefix
# heuristics after, misc/ as the safety net.
# ---------------------------------------------------------------------------
CATEGORY_MAP = {
    # sky / sprites (X flag): black or alpha backgrounds, never tile on terrain
    "moonshap": "sky", "kasa": "sky", "star01": "sky", "star02": "sky",
    "clod_a01": "sky", "kamome01": "sky", "suny_a01": "sky", "fine_a01": "sky",
    "cld_r01": "sky",
    # water
    "sea01": "water", "sea02": "water", "ju_w03c": "water",
    # ground / up-face
    "yuka00": "ground", "ground_1": "ground", "quf": "ground", "myroom02": "ground",
    # stone walls / cliff
    "stone_wh": "walls_stone", "stone01": "walls_stone",
    "i": "walls_stone", "c": "walls_stone",
    "en_siba": "walls_stone", "en_gake": "walls_stone",
    # stucco / plaster family
    "kabe": "walls_stucco", "sunakabe": "walls_stucco",
    "j": "walls_stucco", "n": "walls_stucco", "l": "walls_stucco",
    "h": "walls_stucco", "m": "walls_stucco", "u": "walls_stucco",
    "v": "walls_stucco", "a": "walls_stucco",
    "myroom04": "walls_stucco", "myroom03": "walls_stucco",
    "mr_j_01": "walls_stucco", "mr_j_03": "walls_stucco", "mr_j_04": "walls_stucco",
    # brick + roof tiles
    "brick_m": "walls_brick", "brick_f": "walls_brick",
    "ura_02": "walls_brick", "r": "walls_brick",
    # wood
    "k": "wood", "e": "wood", "f": "wood", "d": "wood",
    "m_cst_09": "wood", "m_cst_19": "wood", "m_dsk_09": "wood",
    # sheets (S flag): baked margins, never tile
    "g": "sheets", "s": "sheets",
    "mark_01": "sheets", "mark_02": "sheets",
    "myroom01": "sheets", "m_bed_04": "sheets",
    "mr_j_d": "sheets", "mr_j_02": "sheets",
    # small details / foliage
    "t": "details", "w": "details", "p": "details",
    "m_obj_21": "details", "m_cst_06": "details", "komono1": "details",
    "m_fgr_01": "foliage", "m_fgr_22": "foliage",
    # effects (lens flares, light glows, weather fx)
    "lf01": "effects", "lf02": "effects", "lf03": "effects",
    "trrp": "effects", "light2": "effects",
}


def categorize(name: str, category_field: str) -> str:
    if name in CATEGORY_MAP:
        return CATEGORY_MAP[name]
    n = name.lower()
    cf = category_field.lower()
    if cf == "effect" or n.startswith(("lf", "light", "glow", "flare")):
        return "effects"
    if n.startswith(("cld", "cloud", "star", "moon", "suny", "fine", "sky")):
        return "sky"
    if n.startswith(("sea", "wave", "water")):
        return "water"
    if n.startswith("tower_"):
        return "building"
    if n.startswith(("m_fgr", "leaf", "gra")):
        return "foliage"
    if n.startswith(("m_dsk", "m_cst", "wood", "plank")):
        return "wood"
    if n.startswith(("m_bed", "mark_", "sign_")):
        return "sheets"
    if n.startswith(("m_obj", "obj_")):
        return "details"
    if n.startswith(("mr_j", "myroom")):
        return "walls_stucco"
    if n.startswith(("yuka", "ground", "floor")):
        return "ground"
    if n.startswith(("kabe", "wall")):
        return "walls_stucco"
    if n.startswith(("stone", "rock")):
        return "walls_stone"
    if n.startswith("brick"):
        return "walls_brick"
    return "misc"


def process(dat_path: Path, out_root: Path) -> int:
    buf = dat_path.read_bytes()
    chunks, walked = walk_chunks(buf)
    stem_dir = out_root / dat_path.stem
    stem_dir.mkdir(parents=True, exist_ok=True)

    records = []
    skipped = []
    seen = {}
    fmt_census = {}
    for c in chunks:
        if c["ctype"] != TEX_CHUNK_TYPE:
            continue
        payload = buf[c["off"] + 16:c["off"] + c["length"]]
        fmt_probe, _ = sniff_texture(payload)
        if fmt_probe == "unknown_txd":
            print(f"  [!!] UNKNOWN DXT VARIANT {payload[57:61]!r} in chunk @0x{c['off']:x} "
                  f"name={c['name']!r} — passthrough. Send this DAT over to add support.")
            skipped.append(c)
            continue
        parsed = parse_texture(payload)
        if not parsed:
            skipped.append(c)
            continue
        fmt_census[parsed["format"]] = fmt_census.get(parsed["format"], 0) + 1

        name = parsed["name"] or f"unnamed_{c['off']:08x}"
        key = (name, parsed["w"], parsed["h"])
        seen[key] = seen.get(key, 0) + 1
        suffix = "" if seen[key] == 1 else f"_dup{seen[key] - 1}"

        cat = categorize(name, parsed["category"])
        (stem_dir / cat).mkdir(parents=True, exist_ok=True)
        fname = f"{name}_{parsed['w']}x{parsed['h']}{suffix}.png"
        rel_path = f"{cat}/{fname}"

        img = Image.frombytes("RGBA", (parsed["w"], parsed["h"]), parsed["rgba"])
        png_path = stem_dir / rel_path
        img.save(png_path, "PNG", optimize=True)

        rec = {
            "format": parsed["format"],
            "chunk_off": c["off"],
            "chunk_name": c["name"],
            "chunk_hdr_len": c["length"],
            "name": name,
            "category_field": parsed["category"],
            "w": parsed["w"],
            "h": parsed["h"],
            "stray_hex": parsed["stray_hex"],
            "cat_raw_hex": parsed["cat_raw_hex"],
            "name_raw_hex": parsed["name_raw_hex"],
            "bmi_hex": parsed["bmi_hex"],
            "data_off_in_payload": parsed["data_off"],
            "data_len": parsed["data_len"],
            "tail_hex": parsed["tail_hex"],
            "png_rel": rel_path,
            "png_sha256_on_export": hashlib.sha256(png_path.read_bytes()).hexdigest(),
        }
        if parsed["format"] == "8bpp_pal":
            rec["variant"] = parsed["variant"]
            rec["pal_off"] = parsed["pal_off"]
            rec["pre_pal_hex"] = parsed["pre_pal_hex"]
            rec["palette_hex"] = parsed["palette_hex"]
            fmt_label = f"8bpp/{parsed['variant']}"
        else:
            rec["disc_hex"] = parsed["disc_hex"]
            rec["block_bytes_field"] = parsed["block_bytes_field"]
            rec["pitch_field"] = parsed["pitch_field"]
            fmt_label = parsed["format"]
        records.append(rec)
        print(f"  {fmt_label:11s} {cat:13s} {fname}  (chunk @0x{c['off']:x})")

    for c in skipped:
        print(f"  [skip] type-0x20 chunk @0x{c['off']:x} name={c['name']!r} — "
              f"unrecognized payload, will pass through on repack")

    manifest = {
        "version": 3,
        "source_dat": str(dat_path.resolve()),
        "source_dat_sha256": hashlib.sha256(buf).hexdigest(),
        "source_dat_size": len(buf),
        "chunk_count_total": len(chunks),
        "record_count": len(records),
        "format_census": fmt_census,
        "records": records,
    }
    (stem_dir / "manifest.json").write_text(json.dumps(manifest, indent=2))
    print(f"  manifest.json ({len(records)} records, formats: {fmt_census})")
    return len(records)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("inputs", nargs="+")
    ap.add_argument("--out", default="./tex_out")
    args = ap.parse_args()
    out_root = Path(args.out)
    total = 0
    for src in args.inputs:
        p = Path(src)
        if not p.exists():
            print(f"[!] {p} not found")
            continue
        print(f"\n[{p}]")
        total += process(p, out_root)
    print(f"\nDone. {total} textures written to {out_root}/")


if __name__ == "__main__":
    main()

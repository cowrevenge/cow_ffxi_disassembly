#!/usr/bin/env python3
"""
stage_hd_test.py — stage West Ronfaure (zone 100) textures into
Extracted_Dats/hd_test/west_ronfaure/originals/ for the runtime HD-swap test.

What lands in the folder (flat, one PNG per unique texture):
  1. Every texture the zone scene MTL binds — the scene MZB/MMB walk of the
     zone DAT, which VTABLE/FTABLE resolve from the zone id at runtime
     (no hardcoded DAT path).
  2. The zone DAT's 'effect'-category textures (clouds/smoke sprites the
     zone's particle layers use) — disable with --no-zone-effects.
  3. Every 0x20 texture in each spawned mob's model DAT. Model ids come from
     the live-server mobs.yaml (docker cp cow-map:/server/data/zones/
     west_ronfaure/mobs.yaml) plus DB event spawns (--extra-models, e.g.
     389 = Twinkling_Treant from mob_groups zoneid=100).

PNG sourcing:
  * Textures the previous extract_dats.py run already wrote are hardlinked
    from ../Extracted_Dats/ (INDEX.csv matched by source_dat + name; the
    sftoken suffix in a dump filename may name a *different* DAT, so the
    source_dat column is authoritative). Copy only if the hardlink fails.
  * Anything missing from the dump is decoded fresh. That is the 0x81
    dual-format zone texture (256-color palette + 8bpp indices followed by
    a '3TXD' DXT3 copy; retail's ConfigureFromImageData repoints PixelData
    at the DXT3 stream when IsCompressed() and the data_size word is
    nonzero, so the DXT3 stream is the representation the client renders at
    default quality). Alpha is kept raw (FFXI half-scale convention:
    0x80 = opaque), same as the rest of the dump.

Map files (.map.toml), one sibling per PNG:
  * Dump-sourced PNGs: the .map.toml the map pass
    (extract_dats.py --maps-only) wrote next to the dump PNG is hardlinked
    alongside the staged PNG.
  * Fresh-decoded PNGs (the 0x81 scene textures the old extractor could not
    decode): the map is generated here from the scene MMB UVs + the fresh
    RGBA, with zone semantics from the FFXI zone name table (zone id from
    --zone, name from ROM/165/84.DAT). Same writer (semantic_resolver.
    write_map_toml) and region analysis (uv_island_analysis) as the dump
    map pass, so both paths emit the same schema.

Idempotent: re-running keeps existing correct files, replaces wrong ones,
and prints a full report + self-checks at the end.

Usage:
  python stage_hd_test.py (run from Headless/) \
      --source "C:\\PhoenixXI\\SquareEnix\\FINAL FANTASY XI" \
      --extracted ../Extracted_Dats \
      --mobs ../Disassembly_Tools/.scratch_wr_mobs.yaml \
      --extra-models 389
"""
import argparse
import csv
import os
import struct
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE / "texdat"))

import numpy as np
import yaml
from PIL import Image
import ffxi_dat_find as fd
import zoneparse as zp
import uv_island_analysis as uia
import uv_raster as uvr
import semantic_resolver as semres
from extract_dats import categorize, sftoken_of
from texfmt import walk_chunks, parse_texture, decode_bc1, decode_bc2


# ---------------------------------------------------------------------------
# model id -> DAT file id (kuluu-render look_resolver::npc_dat_id; bands split
# at 1500 / 3000 / 3500, XIClient ResourceManager::MapResourceIDToFileIndex)
# ---------------------------------------------------------------------------
def npc_dat_id(modelid: int) -> int:
    if modelid < 1500:
        return modelid + 1300
    if modelid < 3000:
        return modelid + 50295
    if modelid < 3500:
        return modelid + 96907
    return modelid + 98239


def norm_dat(rel: str) -> str:
    return rel.replace("\\", "/")


# ---------------------------------------------------------------------------
# 0x20 chunk decode, all type bytes
# ---------------------------------------------------------------------------
def decode_img(payload: bytes):
    """Return dict(name, category, w, h, type, rgba) or None.

    0x81 (FMT0_COMPRESSED): palette @57, 8bpp indices @1081, then a 12-byte
    '3TXD'/'1TXD' sub-header (magic, data_size, pitch) + the DXT stream.
    Retail renders the DXT stream (GameTexture.cpp L290-301 + L333), so that
    is what we decode. Everything else goes through texfmt.parse_texture.
    """
    if len(payload) < 57 or payload[17:21] != b"\x28\x00\x00\x00":
        return None
    w, h = struct.unpack_from("<ii", payload, 21)
    if not (0 < w <= 4096 and 0 < h <= 4096):
        return None
    name = payload[9:17].split(b"\x00")[0].decode("ascii", errors="replace").rstrip(" ")
    cat = payload[1:9].split(b"\x00")[0].decode("ascii", errors="replace").rstrip(" ")
    t = payload[0]
    wh = w * h

    if t == 0x81:
        magic_off = 57 + 1024 + wh
        if magic_off + 12 + wh > len(payload):
            return None
        magic = payload[magic_off:magic_off + 4]
        if magic == b"3TXD":
            data_size, pitch = struct.unpack_from("<II", payload, magic_off + 4)
            if data_size != wh:
                return None
            rgba = decode_bc2(payload[magic_off + 12:magic_off + 12 + wh], w, h)
        elif magic == b"1TXD":
            data_size, pitch = struct.unpack_from("<II", payload, magic_off + 4)
            if data_size != wh // 2:
                return None
            rgba = decode_bc1(payload[magic_off + 12:magic_off + 12 + wh // 2], w, h)
        else:
            return None
        return {"name": name, "category": cat, "w": w, "h": h, "type": t,
                "rgba": bytes(rgba)}

    r = parse_texture(payload)
    if not r:
        return None
    return {"name": r["name"], "category": r.get("category", ""), "w": r["w"],
            "h": r["h"], "type": t, "rgba": bytes(r["rgba"])}


# ---------------------------------------------------------------------------
# INDEX.csv
# ---------------------------------------------------------------------------
def load_index(index_path: Path):
    by_srcname, by_name = {}, {}
    with open(index_path, newline="", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            rel = row["output_relpath"].replace("\\", "/")
            src = norm_dat(row["source_dat"])
            nm = row["name"]
            w, h = int(row["w"]), int(row["h"])
            by_srcname.setdefault((src, nm), []).append((rel, w, h))
            by_name.setdefault((nm, w, h), set()).add(rel)
    return by_srcname, by_name


# ---------------------------------------------------------------------------
# staging
# ---------------------------------------------------------------------------
def stage_one(dst_dir: Path, fname: str, source: Path):
    """Hardlink source -> dst_dir/fname (copy only if the link fails)."""
    dst = dst_dir / fname
    if dst.exists():
        try:
            if dst.stat().st_ino == source.stat().st_ino and \
                    dst.stat().st_dev == source.stat().st_dev:
                return dst
        except OSError:
            pass
        dst.unlink()
    try:
        os.link(source, dst)
    except OSError:
        import shutil
        shutil.copy2(source, dst)
    return dst


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--source", required=True, help="retail install root (VTABLE.DAT dir)")
    ap.add_argument("--extracted", default="../Extracted_Dats",
                    help="previous extract_dats.py output (INDEX.csv + PNGs)")
    ap.add_argument("--mobs", required=True, help="live-server mobs.yaml for the zone")
    ap.add_argument("--extra-models", default="",
                    help="comma-separated model ids from DB event spawns")
    ap.add_argument("--zone", type=int, default=100)
    ap.add_argument("--slug", default="west_ronfaure")
    ap.add_argument("--out", default=None,
                    help="staging dir (default: <extracted>/hd_test/<slug>/originals)")
    ap.add_argument("--no-zone-effects", action="store_true",
                    help="skip the zone DAT's effect-category textures")
    args = ap.parse_args()

    extracted = Path(args.extracted)
    out_dir = Path(args.out) if args.out else extracted / "hd_test" / args.slug / "originals"
    out_dir.mkdir(parents=True, exist_ok=True)

    # ---- spawn list -> model ids ------------------------------------------
    doc = yaml.safe_load(Path(args.mobs).read_text(encoding="utf-8"))
    model_ids = set()

    def walk_looks(node):
        if isinstance(node, dict):
            if node.get("type") == "standard" and isinstance(node.get("model"), int):
                model_ids.add(node["model"])
            for v in node.values():
                walk_looks(v)
        elif isinstance(node, list):
            for v in node:
                walk_looks(v)

    walk_looks(doc)
    for m in args.extra_models.split(","):
        if m.strip():
            model_ids.add(int(m.strip()))
    model_ids = sorted(model_ids)
    print(f"model ids ({len(model_ids)}): {model_ids}")

    # ---- VTABLE/FTABLE ------------------------------------------------------
    tables = fd.load_tables(args.source)
    scene_rel = fd.resolve(tables, args.zone)
    if not scene_rel:
        sys.exit(f"zone {args.zone} does not resolve via VTABLE/FTABLE")
    scene_rel = norm_dat(scene_rel)
    scene_path = Path(args.source) / Path(*scene_rel.split("/"))
    print(f"zone {args.zone} -> {scene_rel}  ({scene_path.stat().st_size // 1024} KB)")

    # zone name (FFXI string table, ROM/165/84.DAT; index = zone id) for map
    # semantics
    zone_names = semres.load_zone_names(args.source, tables)
    zone_name = zone_names[args.zone] if args.zone < len(zone_names) else ""
    if not zone_name:
        print(f"  [warn] zone {args.zone} has no name in the FFXI zone table; "
              f"maps will carry no zone_hint")

    # INDEX.csv
    by_srcname, by_name = load_index(extracted / "INDEX.csv")

    # ---- collect the texture set --------------------------------------------
    # each entry: (name, source_dat, w, h, payload, origin, kind)
    wanted = []          # unique by (name, w, h, source_dat)
    seen = set()

    def add(payload, src_dat, origin, kind):
        r = decode_img(payload)
        if not r:
            print(f"  [miss] {origin} {src_dat}: undecodable 0x20 "
                  f"(type={payload[0]:02x} off unknown)")
            return
        key = (r["name"], r["w"], r["h"], src_dat)
        if key in seen:
            return
        seen.add(key)
        wanted.append({**r, "src": src_dat, "origin": origin, "kind": kind,
                       "payload": payload})

    # 1) scene MTL
    chunks, mzb, mmbs, fails = zp.load_zone(str(scene_path))
    placements = mzb[0] if mzb else []
    mtl_names, order = set(), []
    for p in placements:
        m = mmbs.get(p["id"])
        if m is None:
            continue
        for block in m["blocks"]:
            for mod in block["models"]:
                tex = f"{mod['tex'][0]}_{mod['tex'][1]}" if mod["tex"][1] else mod["tex"][0]
                if tex and tex not in mtl_names:
                    mtl_names.add(tex)
                    order.append(tex)
    print(f"scene MTL: {len(mtl_names)} textures ({', '.join(order)})")

    img_chunks = [c["payload"] for c in chunks if c["type"] == 0x20]
    by_catname = {}
    by_local = {}
    for payload in img_chunks:
        r = decode_img(payload)
        if r:
            by_catname.setdefault(f"{r['category']}_{r['name']}", payload)
            by_local.setdefault(r["name"], []).append(payload)

    # per-texture scene MMB UVs (for the fresh-decode maps): (cat, name) ->
    # [(mmb_id, model_idx, uv (ntri,3,2) float32)]
    scene_uv = {}
    for mmb_id, m in mmbs.items():
        kind = m["hdr"]["kind"]
        for mi, block in enumerate(m["blocks"]):
            for mi2, mod in enumerate(block["models"]):
                cat, name = mod["tex"]
                if not name:
                    continue
                tris = zp.tris_from_model(mod, kind)
                if not tris:
                    continue
                verts = mod["verts"]
                uvv = np.empty((len(verts), 2), dtype=np.float32)
                for vi, v in enumerate(verts):
                    uvv[vi] = (v[4], v[5])
                idx = np.asarray(tris, dtype=np.int64).reshape(-1, 3)
                scene_uv.setdefault((cat, name), []).append(
                    (mmb_id, f"b{mi}_m{mi2}", uvv[idx]))
    for tex in order:
        payload = by_catname.get(tex)
        how = "cat_name"
        if payload is None:
            cands = by_local.get(tex, [])
            if len(cands) == 1:
                payload = cands[0]
                how = "local (kuluu rule)"
            elif len(cands) > 1:
                print(f"  [warn] MTL '{tex}': {len(cands)} local-name candidates, "
                      f"taking first")
                payload = cands[0]
                how = "local (ambiguous!)"
        if payload is None:
            print(f"  [MISS] MTL texture '{tex}' not in {scene_rel} — logged")
            continue
        add(payload, scene_rel, f"scene:{how}", "scene")

    # 2) zone effect textures
    if not args.no_zone_effects:
        for payload in img_chunks:
            r = decode_img(payload)
            if r and r["category"] == "effect":
                add(payload, scene_rel, "zone-effect", "effect")

    # 3) mob model textures
    model_dats = {}
    for mid in model_ids:
        fid = npc_dat_id(mid)
        rel = fd.resolve(tables, fid)
        if not rel:
            print(f"  [MISS] model {mid} (file id {fid}) unresolvable via FTABLE")
            continue
        rel = norm_dat(rel)
        p = Path(args.source) / Path(*rel.split("/"))
        if not p.exists():
            print(f"  [MISS] model {mid}: {rel} not on disk")
            continue
        model_dats[mid] = rel
    print(f"model DATs ({len(model_dats)}/{len(model_ids)}):")
    for mid in model_ids:
        print(f"  {mid:5d} -> {model_dats.get(mid, '(missing)')}")
    for mid, rel in model_dats.items():
        buf = (Path(args.source) / Path(*rel.split("/"))).read_bytes()
        ch, _ = walk_chunks(buf)
        for c in ch:
            if c["ctype"] == 0x20:
                add(buf[c["off"] + 16:c["off"] + c["length"]], rel,
                    f"model:{mid}", "model")

    print(f"\ntotal unique textures to stage: {len(wanted)}")

    # ---- resolve PNGs + stage -------------------------------------------------
    staged = {}          # final fname -> (source_desc, mode)
    maps = {}            # final .map.toml fname -> (source_desc, mode)
    fresh = []
    fresh_maps = []
    missing_maps = []
    pixel_cache = {}
    generated_at = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())

    def dump_pixels(path: Path):
        if path not in pixel_cache:
            pixel_cache[path] = Image.open(path).convert("RGBA").tobytes()
        return pixel_cache[path]

    def make_fresh_map(t, fname):
        """.map.toml for a fresh-decoded texture: scene MMB UVs + fresh RGBA,
        zone semantics from the FFXI zone table. Same schema/writer as the
        dump map pass."""
        w, h = t["w"], t["h"]
        cat, name = t["category"], t["name"]
        rgba = t["rgba"]
        refs = scene_uv.get((cat, name), [])
        if refs:
            uv_all = np.concatenate([uv for _m, _s, uv in refs])
            labels = np.repeat(
                np.array([f"{t['src']}::{m}.submesh_{s}" for m, s, _u in refs],
                         dtype=object),
                np.array([len(u) for _m, _s, u in refs]))
            mask_data = uvr.build_edge_data(uv_all)
            closure = uvr.island_wrap_closure(mask_data, uv_all)
            regions = uia.build_regions(w, h, uv_all, rgba,
                                        mesh_parts_by_tri=labels,
                                        wrap_closure=closure)
            cover, seam = uvr.rasterize_masks_from_data(uv_all, w, h, mask_data)
            used_by_meshes = sorted({f"{t['src']}::{m}" for m, _s, _u in refs})
        else:
            regions = []
            used_by_meshes = []
            # no mesh reference: assume the whole image is used (the safe
            # default for the upscaling pipeline — fall through to original)
            cover = np.full((h, w), 255, dtype=np.uint8)
            seam = np.ones((h, w), dtype=np.uint8)
        if not regions:
            # MTL-bound but no UV islands (degenerate), or no mesh refs at
            # all: one full-image region.
            alpha_pattern, _st = uia.analyze_alpha(rgba, w, h, [0, 0, w, h])
            regions = [{"id": "region_0", "bbox": [0, 0, w, h],
                        "uv_island_triangle_count": 0,
                        "technique": uia.classify_technique("none", alpha_pattern),
                        "tiling": "none", "alpha_pattern": alpha_pattern,
                        "mesh_parts": []}]
            if refs:
                regions[0]["mesh_parts"] = sorted(
                    {f"{t['src']}::{m}.submesh_{s}" for m, _s, _u in refs})
                regions[0]["uv_island_triangle_count"] = sum(
                    len(u) for _m, _s, u in refs)
        if refs:
            if t["kind"] == "scene":
                # zone scene material bound by the MTL; the role
                # (ground/wall/props) is not derivable from scene data
                category = "environment"
                warns = ["role (ground/wall/props) not derivable from scene "
                         "data; category=environment"]
            else:
                category = semres.scene_category(categorize(name, cat))
                warns = []
            subject, family, zone_hint, fam_id = zone_name, "", zone_name, None
            confidence = "partial" if zone_name else "blank"
        else:
            category, subject, family, zone_hint, fam_id = \
                "unknown", "", "", "", None
            confidence = "orphan_no_mesh_reference"
            warns = ["no mesh references found; region left for review"]
        base = fname[:-4]
        uvmask_rel = base + ".uvmask.png"
        seammask_rel = base + ".seammask.png"
        Image.fromarray(cover).save(out_dir / uvmask_rel, "PNG")
        Image.fromarray(seam).save(out_dir / seammask_rel, "PNG")
        semres.write_map_toml(out_dir / (base + ".map.toml"),
                              source_texture=fname, w=w, h=h,
                              source_dat=t["src"], generated_at=generated_at,
                              category=category, subject_name=subject,
                              subject_family=family, zone_hint=zone_hint,
                              lsb_family_id=fam_id, lsb_commit="",
                              used_by_meshes=used_by_meshes,
                              referenced_by_scenes=
                              ([f"models/{sftoken_of(t['src'])}/scene.obj"]
                               if refs else []),
                              mesh_reference_count=len(refs), regions=regions,
                              warnings=warns, orphan=not refs,
                              uvmask_file=uvmask_rel, seammask_file=seammask_rel)
        maps[base + ".map.toml"] = \
            (f"generated ({len(refs)} scene MMB submesh refs)", "fresh")
        fresh_maps.append(fname)

    for t in wanted:
        base = f"{t['name']}_{t['w']}x{t['h']}.png"
        rows = [r for r in by_srcname.get((t["src"], t["name"]), [])
                if r[1] == t["w"] and r[2] == t["h"]]
        src_png = None
        if len(rows) == 1:
            cand = extracted / rows[0][0]
            if cand.exists():
                src_png = cand                      # extractor wrote it from this DAT
        if src_png is None:
            # no INDEX row for this source DAT: decode fresh, then check whether
            # a same-name+size dump file is pixel-identical (cross-DAT dedupe)
            rgba = t["rgba"]
            cands = sorted(extracted / c for c in
                           by_name.get((t["name"], t["w"], t["h"]), set()))
            cands = [c for c in cands if c.exists()]
            matching = [c for c in cands if dump_pixels(c) == rgba]
            if matching:
                src_png = matching[0]
                print(f"  [dedup] {base}: no INDEX row for ({t['src']}, "
                      f"{t['name']}); pixels match dump file "
                      f"{matching[0].relative_to(extracted)} "
                      f"({len(cands)} same-name candidates)")
            else:
                if cands:
                    print(f"  [fresh] {base}: {len(cands)} same-name dump files, "
                          f"none pixel-identical to {t['src']}; decoding fresh")
                dst = out_dir / base
                if dst.exists() and dump_pixels(dst) != rgba:
                    print(f"  [replace] {base}: existing file differs from fresh "
                          f"decode; rewriting")
                    dst.unlink()
                if not dst.exists():
                    Image.frombytes("RGBA", (t["w"], t["h"]), rgba).save(dst, "PNG")
                fresh.append(base)
                staged[base] = (f"fresh decode ({t['kind']}) <- {t['src']}", "fresh")
                make_fresh_map(t, base)
                continue
        # final name: the dump file's own name (the swap logic matches by name
        # and the extractor's sftoken suffix is authoritative); fresh textures
        # use the natural <name>_<w>x<h> the extractor would have picked.
        fname = src_png.name
        if fname in staged and (out_dir / fname).stat().st_ino != src_png.stat().st_ino:
            alt = f"{t['name']}_{fd_sftoken(t['src'])}_{t['w']}x{t['h']}.png"
            i = 2
            while alt in staged:
                alt = f"{t['name']}_{fd_sftoken(t['src'])}_{i}_{t['w']}x{t['h']}.png"
                i += 1
            print(f"  [collide] {fname} already staged with different content; "
                  f"using {alt}")
            fname = alt
        if fname in staged and (out_dir / fname).stat().st_ino == src_png.stat().st_ino:
            continue                            # same dump file, already staged
        stage_one(out_dir, fname, src_png)
        staged[fname] = (f"hardlink <- {src_png.name} ({t['src']})", "link")
        # sibling .map.toml from the dump map pass
        map_src = src_png.with_name(fname[:-4] + ".map.toml")
        if map_src.exists():
            stage_one(out_dir, fname[:-4] + ".map.toml", map_src)
            maps[fname[:-4] + ".map.toml"] = \
                (f"hardlink <- {map_src.name}", "link")
        else:
            missing_maps.append(fname)
            print(f"  [warn] {fname}: no .map.toml in the dump "
                  f"({map_src.name} missing) — run the map pass first")
        # sibling UV masks from the dump map pass
        for suffix in (".uvmask.png", ".seammask.png"):
            mask_src = src_png.with_name(fname[:-4] + suffix)
            if mask_src.exists():
                stage_one(out_dir, fname[:-4] + suffix, mask_src)
            else:
                print(f"  [warn] {fname}: no {suffix} in the dump "
                      f"({mask_src.name} missing) — run the map pass first")

    # ---- report + self-checks --------------------------------------------------
    print("\n" + "=" * 72)
    for fname in sorted(staged):
        how, _ = staged[fname]
        print(f"  {fname:40s} {how}")
    for mname in sorted(maps):
        how, _ = maps[mname]
        print(f"  {mname:40s} {how}")
    mask_suffixes = (".uvmask.png", ".seammask.png")
    files = sorted(p.name for p in out_dir.iterdir()
                   if p.suffix.lower() == ".png"
                   and not p.name.endswith(mask_suffixes))
    mapfiles = sorted(p.name for p in out_dir.iterdir()
                      if p.name.endswith(".map.toml"))
    uvmasks = sorted(p.name for p in out_dir.iterdir()
                     if p.name.endswith(".uvmask.png"))
    seammasks = sorted(p.name for p in out_dir.iterdir()
                       if p.name.endswith(".seammask.png"))
    print("=" * 72)
    print(f"staged: {len(staged)} unique textures -> {len(files)} PNGs in {out_dir}")
    print(f"maps:   {len(maps)} .map.toml ({len(mapfiles)} on disk)")
    print(f"masks:  {len(uvmasks)} .uvmask.png, {len(seammasks)} .seammask.png")
    print(f"fresh decodes: {len(fresh)}  {fresh if fresh else ''}")

    # self-checks
    ok = True
    extra = set(files) - set(staged)
    missing = set(staged) - set(files)
    if extra:
        print(f"SELF-CHECK FAIL: unexpected files in out dir: {sorted(extra)}")
        ok = False
    if missing:
        print(f"SELF-CHECK FAIL: staged files missing on disk: {sorted(missing)}")
        ok = False
    # one .map.toml + .uvmask.png + .seammask.png per PNG, and vice versa
    png_bases = {f[:-4] for f in files}
    map_bases = {f[:-len('.map.toml')] for f in mapfiles}
    uv_bases = {f[:-len('.uvmask.png')] for f in uvmasks}
    seam_bases = {f[:-len('.seammask.png')] for f in seammasks}
    no_map = sorted(png_bases - map_bases)
    extra_maps = sorted(map_bases - png_bases)
    no_uv = sorted(png_bases - uv_bases)
    extra_uv = sorted(uv_bases - png_bases)
    no_seam = sorted(png_bases - seam_bases)
    extra_seam = sorted(seam_bases - png_bases)
    if no_map:
        print(f"SELF-CHECK FAIL: PNGs without .map.toml: {no_map}")
        ok = False
    if extra_maps:
        print(f"SELF-CHECK FAIL: .map.toml without PNG: {extra_maps}")
        ok = False
    if no_uv:
        print(f"SELF-CHECK FAIL: PNGs without .uvmask.png: {no_uv}")
        ok = False
    if extra_uv:
        print(f"SELF-CHECK FAIL: .uvmask.png without PNG: {extra_uv}")
        ok = False
    if no_seam:
        print(f"SELF-CHECK FAIL: PNGs without .seammask.png: {no_seam}")
        ok = False
    if extra_seam:
        print(f"SELF-CHECK FAIL: .seammask.png without PNG: {extra_seam}")
        ok = False
    bad_maps = [f for f in mapfiles
                if "[[regions]]" not in (out_dir / f).read_text(encoding="utf-8")]
    if bad_maps:
        print(f"SELF-CHECK FAIL: zero-region maps: {bad_maps}")
        ok = False
    # fresh-generated masks are expected to be nlink==1 (not hardlinks)
    fresh_mask_names = set()
    for f in fresh:
        b = f[:-4]
        fresh_mask_names.add(b + ".uvmask.png")
        fresh_mask_names.add(b + ".seammask.png")
    linked = copied = freshn = 0
    map_linked = map_copied = map_fresh = 0
    mask_linked = mask_fresh = 0
    for p in out_dir.iterdir():
        if p.name.endswith(mask_suffixes):
            nlink = p.stat().st_nlink
            if p.name in fresh_mask_names:
                mask_fresh += 1
            elif nlink >= 2:
                mask_linked += 1
            else:
                print(f"SELF-CHECK FAIL: {p.name} is a byte copy, hardlink was possible")
                ok = False
        elif p.suffix.lower() == ".png":
            nlink = p.stat().st_nlink
            if p.name in fresh:
                freshn += 1
            elif nlink >= 2:
                linked += 1
            else:
                copied += 1
                print(f"SELF-CHECK FAIL: {p.name} is a byte copy, hardlink was possible")
                ok = False
        elif p.name.endswith(".map.toml"):
            nlink = p.stat().st_nlink
            if p.name in maps and maps[p.name][1] == "fresh":
                map_fresh += 1
            elif nlink >= 2:
                map_linked += 1
            else:
                map_copied += 1
                print(f"SELF-CHECK FAIL: {p.name} is a byte copy, hardlink was possible")
                ok = False
    print(f"hardlinks: {linked}  copies: {copied}  fresh: {freshn}")
    print(f"map hardlinks: {map_linked}  map copies: {map_copied}  "
          f"map generated: {map_fresh}")
    print(f"mask hardlinks: {mask_linked}  mask generated: {mask_fresh}")
    print("SELF-CHECK PASS" if ok else "SELF-CHECK FAILED")
    sys.exit(0 if ok else 1)


def fd_sftoken(rel: str) -> str:
    parts = rel.split("/")
    base = ["".join(ch for ch in p if ch.isalnum()).lower() for p in parts[:-1]]
    return "_".join(base + [parts[-1][:-4]])


if __name__ == "__main__":
    main()

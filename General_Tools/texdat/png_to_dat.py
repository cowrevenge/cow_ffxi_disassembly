#!/usr/bin/env python3
"""
png_to_dat.py — Rebuild a zone .DAT from {source DAT + manifest.json + PNGs}.

Branches on each record's format (from the manifest):
  - dxt3:     re-encode edited PNGs to BC2 blocks; update BMI w/h,
              blockBytes (=w*h) and pitch (=w*4) fields on resize
  - 8bpp_pal: quantize edited PNGs to 256-color BGRA palette; update BMI w/h

Untouched PNGs (sha matches export) pass through byte-for-byte — bit-exact.
Non-texture chunks (MZB/MMB/etc) pass through byte-for-byte.
Resize is opt-in via --allow-resize (chunk lengths self-describe, so
downstream offsets shifting is fine; no external TOC exists in these DATs).

Requires texfmt.py next to this script.

Usage:
    python png_to_dat.py ./tex_out/42_jeuno --source 42_jeuno.DAT \\
        --out 42_jeuno_new.DAT --allow-resize
"""

import argparse
import hashlib
import json
import struct
import sys
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    sys.stderr.write("Pillow not installed. Run: pip install Pillow\n")
    sys.exit(1)

sys.path.insert(0, str(Path(__file__).resolve().parent))
from texfmt import encode_bc2, make_chunk_header, walk_chunks  # noqa: E402


# ---------------------------------------------------------------------------
# Payload builders.
# ---------------------------------------------------------------------------

def _common_header(rec: dict, w: int, h: int) -> bytes:
    """stray + category(8) + name(8) + BMI(40) with updated w/h."""
    stray = bytes.fromhex(rec["stray_hex"])
    cat_raw = bytes.fromhex(rec["cat_raw_hex"])
    name_raw = bytes.fromhex(rec["name_raw_hex"])
    bmi = bytearray(bytes.fromhex(rec["bmi_hex"]))
    struct.pack_into("<ii", bmi, 4, w, h)
    return stray + cat_raw + name_raw + bytes(bmi)


def build_8bpp_payload(png_path: Path, rec: dict) -> bytes:
    img = Image.open(png_path).convert("RGBA")
    w, h = img.size
    rgba = img.tobytes()
    fully_opaque = all(rgba[i] == 255 for i in range(3, len(rgba), 4))
    if fully_opaque:
        quantized = img.convert("RGB").quantize(
            colors=256, method=Image.Quantize.MEDIANCUT,
            dither=Image.Dither.FLOYDSTEINBERG)
    else:
        quantized = img.quantize(
            colors=256, method=Image.Quantize.FASTOCTREE,
            dither=Image.Dither.FLOYDSTEINBERG)
    pal = quantized.getpalette() or []
    idx_bytes = quantized.tobytes()
    assert len(idx_bytes) == w * h

    alpha_map = [255] * 256
    seen_alpha = [False] * 256
    for i, ix in enumerate(idx_bytes):
        if not seen_alpha[ix]:
            alpha_map[ix] = rgba[i * 4 + 3]
            seen_alpha[ix] = True

    pal_bytes = bytearray(1024)
    for i in range(256):
        r = pal[i * 3] if i * 3 < len(pal) else 0
        g = pal[i * 3 + 1] if i * 3 + 1 < len(pal) else 0
        b = pal[i * 3 + 2] if i * 3 + 2 < len(pal) else 0
        pal_bytes[i * 4] = b
        pal_bytes[i * 4 + 1] = g
        pal_bytes[i * 4 + 2] = r
        pal_bytes[i * 4 + 3] = alpha_map[i]

    disc = bytes.fromhex(rec["pre_pal_hex"])    # '' for plain, 4B flags for env
    tail = bytes.fromhex(rec["tail_hex"])
    return _common_header(rec, w, h) + disc + bytes(pal_bytes) + idx_bytes + tail


def build_dxt3_payload(png_path: Path, rec: dict) -> bytes:
    img = Image.open(png_path).convert("RGBA")
    w, h = img.size
    blocks = encode_bc2(img.tobytes(), w, h)
    disc = bytes.fromhex(rec["disc_hex"])       # b'3TXD'
    fields = struct.pack("<II", w * h, w * 4)   # blockBytes, pitch
    tail = bytes.fromhex(rec["tail_hex"])
    return _common_header(rec, w, h) + disc + fields + blocks + tail


BUILDERS = {
    "8bpp_pal": build_8bpp_payload,
    "dxt3": build_dxt3_payload,
}


# ---------------------------------------------------------------------------
# Driver.
# ---------------------------------------------------------------------------

def rebuild(tex_dir: Path, src_dat: Path, out_dat: Path, allow_resize: bool):
    manifest = json.loads((tex_dir / "manifest.json").read_text())
    buf = src_dat.read_bytes()
    src_sha = hashlib.sha256(buf).hexdigest()
    if src_sha != manifest["source_dat_sha256"]:
        print("[!] source DAT sha mismatch — manifest was exported from a different file")
        print(f"    manifest: {manifest['source_dat_sha256']}")
        print(f"    actual  : {src_sha}")
        sys.exit(3)

    chunks, walked = walk_chunks(buf)
    print(f"[{src_dat.name}] {len(chunks)} chunks, walked {walked}/{len(buf)}B")
    records_by_off = {r["chunk_off"]: r for r in manifest["records"]}

    output = bytearray()
    changed = resized = kept = 0
    for c in chunks:
        rec = records_by_off.get(c["off"])
        if rec is None:
            output += buf[c["off"]:c["off"] + c["length"]]
            continue

        png_path = tex_dir / rec["png_rel"]
        if not png_path.exists():
            print(f"  [miss] {rec['png_rel']} not on disk — keeping original")
            output += buf[c["off"]:c["off"] + c["length"]]
            kept += 1
            continue

        png_sha = hashlib.sha256(png_path.read_bytes()).hexdigest()
        with Image.open(png_path) as probe:
            png_w, png_h = probe.size

        if (png_sha == rec["png_sha256_on_export"]
                and png_w == rec["w"] and png_h == rec["h"]):
            output += buf[c["off"]:c["off"] + c["length"]]
            kept += 1
            continue

        size_changed = (png_w != rec["w"] or png_h != rec["h"])
        if size_changed and not allow_resize:
            print(f"[!] {rec['png_rel']}: size {png_w}x{png_h} != manifest "
                  f"({rec['w']}x{rec['h']}). Use --allow-resize. Aborting.")
            sys.exit(2)
        if rec["format"] == "dxt3" and (png_w % 4 or png_h % 4):
            print(f"[!] {rec['png_rel']}: DXT3 dimensions must be multiples of 4, "
                  f"got {png_w}x{png_h}. Aborting.")
            sys.exit(2)

        new_payload = BUILDERS[rec["format"]](png_path, rec)
        total_unpadded = 16 + len(new_payload)
        padded_total = (total_unpadded + 15) & ~15
        pad = padded_total - total_unpadded
        new_hdr = make_chunk_header(c["hdr_bytes"], c["ctype"], padded_total)
        output += new_hdr + new_payload + b"\x00" * pad

        if size_changed:
            resized += 1
            print(f"  [resize] {rec['format']:9s} {rec['png_rel']}  "
                  f"{rec['w']}x{rec['h']} -> {png_w}x{png_h}  "
                  f"({c['length']}B -> {padded_total}B)")
        else:
            changed += 1
            print(f"  [edit]   {rec['format']:9s} {rec['png_rel']}  {png_w}x{png_h}")

    if walked < len(buf):
        output += buf[walked:]

    out_dat.write_bytes(bytes(output))
    print(f"\n{changed} edited, {resized} resized, {kept} passthrough. "
          f"wrote {out_dat}  ({len(output)}B, was {len(buf)}B)")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("tex_dir")
    ap.add_argument("--source", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--allow-resize", action="store_true")
    args = ap.parse_args()
    rebuild(Path(args.tex_dir), Path(args.source), Path(args.out), args.allow_resize)


if __name__ == "__main__":
    main()

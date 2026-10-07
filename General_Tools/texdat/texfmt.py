#!/usr/bin/env python3
"""
texfmt.py — shared format logic for FFXI zone .DAT texture chunks.

Two texture grammars coexist inside type 0x20 chunks (sometimes in the SAME
file, e.g. Port Jeuno t_ju has 51 DXT3 records + 8 8bpp records):

COMMON HEADER (both formats), relative to chunk payload start:
    [0]      stray byte (0x01, 0xa1, ...)
    [1:9]    8-char category, space-padded ('twr2bai ', 'moon    ', 'model   ')
    [9:17]   8-char name, space-padded ('tower_25', 'moonshap', 'stone_wh')
    [17:57]  40B BITMAPINFOHEADER: u32 0x28, i32 w, i32 h, u16 planes,
             u16 bitCount(=8, legacy lie), remainder varies per format

FORMAT A — 8bpp + embedded palette   (discriminator: [57:61] == u32 0x20)
    [57:61]     u32 0x20 (output bpp)
    [61:1085]   256-entry BGRA palette (1024B)
    [1085:1085+w*h]  8bpp indices, row-major top-first
    [tail]      ~3B pad to chunk length

FORMAT B — DXT3/BC2                  (discriminator: [57:61] == b'3TXD')
    [57:61]     b'3TXD'
    [61:65]     u32 blockBytes == w*h  (BC2 is 1 byte/pixel)
    [65:69]     u32 pitch == w*4
    [69:69+w*h] BC2 blocks, 16B per 4x4 tile, top row first
    [tail]      ~11B pad to chunk length

Chunk container header (16B, per ROM-LAYOUT §3.3):
    char name[4]; u32 tl; u32 unk; u32 unk
    tl &= 0x0FFFFFFF; type = tl & 0x7F; length = ((tl >> 7) & 0x7FFF F) << 4
"""

import struct

TEX_CHUNK_TYPE = 0x20


# ---------------------------------------------------------------------------
# Chunk container walk.
# ---------------------------------------------------------------------------

def walk_chunks(data: bytes):
    """Return ([chunk dicts], bytes_walked). Tolerates trailing garbage."""
    off = 0
    out = []
    while off + 16 <= len(data):
        name = data[off:off + 4]
        tl_raw = struct.unpack_from("<I", data, off + 4)[0]
        tl = tl_raw & 0x0FFFFFFF
        ctype = tl & 0x7F
        length = ((tl >> 7) & 0x7FFFF) << 4
        if length < 16 or off + length > len(data):
            break
        out.append({
            "off": off,
            "name": name.rstrip(b"\x00").decode(errors="replace"),
            "tl_raw": tl_raw,
            "ctype": ctype,
            "length": length,
            "hdr_bytes": data[off:off + 16],
        })
        off += length
    return out, off


def make_chunk_header(orig_hdr: bytes, ctype: int, new_length: int) -> bytes:
    """Rebuild 16B chunk header with a new length, preserving unknown fields."""
    assert new_length % 16 == 0, f"chunk length must be 16-byte aligned, got {new_length}"
    length_encoded = (new_length >> 4) & 0x7FFFF
    tl_low = (length_encoded << 7) | (ctype & 0x7F)
    orig_tl_raw = struct.unpack_from("<I", orig_hdr, 4)[0]
    top4 = orig_tl_raw & 0xF0000000
    new_tl_raw = top4 | (tl_low & 0x0FFFFFFF)
    return orig_hdr[0:4] + struct.pack("<I", new_tl_raw) + orig_hdr[8:16]


# ---------------------------------------------------------------------------
# Payload sniff + parse. Returns a record dict or None.
#
# 8bpp layouts (empirically verified):
#   plain: palette @57  (tower materials; discriminator dword IS palette[0])
#   env:   u32 flags @57, palette @61  (suny/lf/trrp/light weather+fx records)
# Plain-vs-env is arbitrated by the zero-tail test on both candidates and,
# if both fit, a wrap test: with the wrong offset the pixel stream shifts 4
# bytes, so each row's first 4 columns duplicate the previous row's last 4.
# ---------------------------------------------------------------------------

def _tail_ok(payload: bytes, pal_off: int, w: int, h: int) -> bool:
    end = pal_off + 1024 + w * h
    if end > len(payload):
        return False
    tail = payload[end:]
    return len(tail) < 16 and all(b == 0 for b in tail)


def _wrap_score(payload: bytes, pal_off: int, w: int, h: int):
    """Return (continuation_diff, wrap_diff) over the pixel index stream.
    Correct layout: continuation < wrap. Uses raw indices (palette-free)."""
    pix = payload[pal_off + 1024:pal_off + 1024 + w * h]
    cont = wrap = 0
    n = 0
    step = max(1, h // 128)          # sample rows for speed
    for y in range(1, h, step):
        row = y * w
        prev = (y - 1) * w
        for x in range(4):
            cont += abs(pix[row + x] - pix[row + 4 + x])
            wrap += abs(pix[row + x] - pix[prev + w - 4 + x])
        n += 4
    return cont / n, wrap / n


def sniff_texture(payload: bytes):
    """Classify a type-0x20 chunk payload.
    Returns ('dxt3', None) | ('8bpp_pal', pal_off) | (None, None).

    8bpp variant discriminator: the u32 at [57:61]. Env records carry a small
    count/flags value (1 or 2 observed); plain records have their first BGRA
    palette entry there, whose alpha byte alone makes the u32 large. Verified
    against Port Jeuno (suny/fine/lf*/trrp/light2 = env, symmetry-tested) and
    tower zone (all 20 = plain, wrap-tested). The zero-tail size test
    validates the choice and falls back to the other candidate if it fails."""
    if len(payload) < 69:
        return None, None
    if payload[17:21] != b"\x28\x00\x00\x00":
        return None, None
    w, h = struct.unpack_from("<ii", payload, 21)
    if not (4 <= w <= 4096 and 4 <= h <= 4096):
        return None, None
    if payload[57:61] == b"3TXD":
        return "dxt3", None
    if payload[57:61] == b"1TXD":
        return "dxt1", None
    if payload[58:61] == b"TXD":
        # Unknown DXT variant (e.g. '5TXD' = DXT5/BC3). Flag loudly upstream.
        return "unknown_txd", None
    disc = struct.unpack_from("<I", payload, 57)[0]
    # 0 = plain with transparent-black entry 0 (index-0 void convention);
    # 1..15 = env count/flags; >=16 = plain (BGRA entry, alpha byte alone is big)
    prefer = 61 if 1 <= disc < 16 else 57
    other = 57 if prefer == 61 else 61
    if _tail_ok(payload, prefer, w, h):
        return "8bpp_pal", prefer
    if _tail_ok(payload, other, w, h):
        return "8bpp_pal", other
    return None, None


def parse_texture(payload: bytes):
    """Parse either format. Returns dict with fields + decoded RGBA, or None."""
    fmt, pal_off = sniff_texture(payload)
    if fmt is None or fmt == "unknown_txd":
        return None
    w, h = struct.unpack_from("<ii", payload, 21)
    name = payload[9:17].split(b"\x00")[0].decode("ascii", errors="replace").rstrip(" ")
    category = payload[1:9].split(b"\x00")[0].decode("ascii", errors="replace").rstrip(" ")

    common = {
        "format": fmt,
        "name": name,
        "category": category,
        "w": w, "h": h,
        "stray_hex": payload[0:1].hex(),
        "cat_raw_hex": payload[1:9].hex(),
        "name_raw_hex": payload[9:17].hex(),
        "bmi_hex": payload[17:57].hex(),
    }

    if fmt == "8bpp_pal":
        pix_off = pal_off + 1024
        pix_len = w * h
        palette = []
        for i in range(256):
            b, g, r, a = payload[pal_off + i * 4:pal_off + i * 4 + 4]
            palette.append((r, g, b, a))
        pixels = payload[pix_off:pix_off + pix_len]
        rgba = bytearray(pix_len * 4)
        for i, idx in enumerate(pixels):
            r, g, b, a = palette[idx]
            o = i * 4
            rgba[o] = r; rgba[o + 1] = g; rgba[o + 2] = b; rgba[o + 3] = a
        common.update({
            "variant": "plain" if pal_off == 57 else "env",
            "pal_off": pal_off,
            "pre_pal_hex": payload[57:pal_off].hex(),    # '' for plain, 4B flags for env
            "palette_hex": payload[pal_off:pix_off].hex(),
            "data_off": pix_off,
            "data_len": pix_len,
            "tail_hex": payload[pix_off + pix_len:].hex(),
            "rgba": bytes(rgba),
        })
        return common

    # dxt3 (BC2, 16B/block) or dxt1 (BC1, 8B/block)
    block_bytes = struct.unpack_from("<I", payload, 61)[0]
    pitch = struct.unpack_from("<I", payload, 65)[0]
    bpb = 16 if fmt == "dxt3" else 8
    expect_blocks = ((w + 3) // 4) * ((h + 3) // 4) * bpb
    data_off = 69
    if data_off + expect_blocks > len(payload):
        return None
    blocks = payload[data_off:data_off + expect_blocks]
    decoder = decode_bc2 if fmt == "dxt3" else decode_bc1
    common.update({
        "disc_hex": payload[57:61].hex(),               # '3TXD' / '1TXD'
        "block_bytes_field": block_bytes,
        "pitch_field": pitch,
        "data_off": data_off,
        "data_len": expect_blocks,
        "tail_hex": payload[data_off + expect_blocks:].hex(),
        "rgba": decoder(blocks, w, h),
    })
    return common


# ---------------------------------------------------------------------------
# BC2 / DXT3 decode + encode.
# ---------------------------------------------------------------------------

def _color565(c):
    r = ((c >> 11) & 0x1F) * 255 // 31
    g = ((c >> 5) & 0x3F) * 255 // 63
    b = (c & 0x1F) * 255 // 31
    return (r, g, b)


def decode_bc2(data: bytes, w: int, h: int) -> bytes:
    out = bytearray(w * h * 4)
    bw, bh = (w + 3) // 4, (h + 3) // 4
    off = 0
    for by in range(bh):
        for bx in range(bw):
            block = data[off:off + 16]
            off += 16
            alpha_bits = int.from_bytes(block[0:8], "little")
            c0, c1 = struct.unpack("<HH", block[8:12])
            code_bits = int.from_bytes(block[12:16], "little")
            p0 = _color565(c0)
            p1 = _color565(c1)
            palette = [
                p0, p1,
                ((2 * p0[0] + p1[0]) // 3, (2 * p0[1] + p1[1]) // 3, (2 * p0[2] + p1[2]) // 3),
                ((p0[0] + 2 * p1[0]) // 3, (p0[1] + 2 * p1[1]) // 3, (p0[2] + 2 * p1[2]) // 3),
            ]
            for py in range(4):
                for px in range(4):
                    x, y = bx * 4 + px, by * 4 + py
                    if x >= w or y >= h:
                        continue
                    idx = py * 4 + px
                    code = (code_bits >> (idx * 2)) & 0x3
                    r, g, b = palette[code]
                    a4 = (alpha_bits >> (idx * 4)) & 0xF
                    o = (y * w + x) * 4
                    out[o] = r; out[o + 1] = g; out[o + 2] = b
                    out[o + 3] = (a4 << 4) | a4
    return bytes(out)


def _to565(r, g, b):
    return ((r >> 3) << 11) | ((g >> 2) << 5) | (b >> 3)


def decode_bc1(data: bytes, w: int, h: int) -> bytes:
    """DXT1/BC1: 8B per 4x4 block. c0>c1 = 4-color opaque; c0<=c1 = 3-color
    + transparent black for code 3 (1-bit punch-through alpha)."""
    out = bytearray(w * h * 4)
    bw, bh = (w + 3) // 4, (h + 3) // 4
    off = 0
    for by in range(bh):
        for bx in range(bw):
            c0, c1 = struct.unpack_from("<HH", data, off)
            code_bits = int.from_bytes(data[off + 4:off + 8], "little")
            off += 8
            p0 = _color565(c0)
            p1 = _color565(c1)
            if c0 > c1:
                palette = [
                    (*p0, 255), (*p1, 255),
                    ((2 * p0[0] + p1[0]) // 3, (2 * p0[1] + p1[1]) // 3,
                     (2 * p0[2] + p1[2]) // 3, 255),
                    ((p0[0] + 2 * p1[0]) // 3, (p0[1] + 2 * p1[1]) // 3,
                     (p0[2] + 2 * p1[2]) // 3, 255),
                ]
            else:
                palette = [
                    (*p0, 255), (*p1, 255),
                    ((p0[0] + p1[0]) // 2, (p0[1] + p1[1]) // 2,
                     (p0[2] + p1[2]) // 2, 255),
                    (0, 0, 0, 0),
                ]
            for py in range(4):
                for px in range(4):
                    x, y = bx * 4 + px, by * 4 + py
                    if x >= w or y >= h:
                        continue
                    code = (code_bits >> ((py * 4 + px) * 2)) & 0x3
                    r, g, b, a = palette[code]
                    o = (y * w + x) * 4
                    out[o] = r; out[o + 1] = g; out[o + 2] = b; out[o + 3] = a
    return bytes(out)


def _encode_bc1_block(pixels):
    """pixels: 16 RGBA tuples. Alpha < 128 anywhere -> 3-color punch-through."""
    has_alpha = any(px[3] < 128 for px in pixels)
    opaque = [px for px in pixels if px[3] >= 128]
    if not opaque:
        # fully transparent block: c0 = c1 = 0, all codes 3
        return struct.pack("<HHI", 0, 0, 0xFFFFFFFF)
    lo = min(opaque, key=_luma)
    hi = max(opaque, key=_luma)
    if has_alpha:
        # 3-color mode requires c0 <= c1
        c0 = _to565(lo[0], lo[1], lo[2])
        c1 = _to565(hi[0], hi[1], hi[2])
        if c0 > c1:
            c0, c1 = c1, c0
        p0 = _color565(c0)
        p1 = _color565(c1)
        palette = [p0, p1,
                   ((p0[0] + p1[0]) // 2, (p0[1] + p1[1]) // 2, (p0[2] + p1[2]) // 2)]
        codes = 0
        for i, px in enumerate(pixels):
            if px[3] < 128:
                codes |= 3 << (i * 2)
                continue
            best_c, best_d = 0, 1 << 30
            for ci, pal in enumerate(palette):
                dr, dg, db = px[0] - pal[0], px[1] - pal[1], px[2] - pal[2]
                d = dr * dr + dg * dg + db * db
                if d < best_d:
                    best_d, best_c = d, ci
            codes |= best_c << (i * 2)
        return struct.pack("<HHI", c0, c1, codes)
    # opaque 4-color mode requires c0 > c1
    c0 = _to565(hi[0], hi[1], hi[2])
    c1 = _to565(lo[0], lo[1], lo[2])
    if c0 == c1:
        # solid block: c0 == c1 selects 3-color mode; codes 0 reproduce it exactly
        return struct.pack("<HHI", c0, c1, 0)
    if c0 < c1:
        c0, c1 = c1, c0
    p0 = _color565(c0)
    p1 = _color565(c1)
    palette = [
        p0, p1,
        ((2 * p0[0] + p1[0]) // 3, (2 * p0[1] + p1[1]) // 3, (2 * p0[2] + p1[2]) // 3),
        ((p0[0] + 2 * p1[0]) // 3, (p0[1] + 2 * p1[1]) // 3, (p0[2] + 2 * p1[2]) // 3),
    ]
    codes = 0
    for i, px in enumerate(pixels):
        best_c, best_d = 0, 1 << 30
        for ci, pal in enumerate(palette):
            dr, dg, db = px[0] - pal[0], px[1] - pal[1], px[2] - pal[2]
            d = dr * dr + dg * dg + db * db
            if d < best_d:
                best_d, best_c = d, ci
        codes |= best_c << (i * 2)
    return struct.pack("<HHI", c0, c1, codes)


def encode_bc1(rgba: bytes, w: int, h: int) -> bytes:
    out = bytearray()
    bw, bh = (w + 3) // 4, (h + 3) // 4
    for by in range(bh):
        for bx in range(bw):
            block = []
            for py in range(4):
                for px in range(4):
                    x = min(bx * 4 + px, w - 1)
                    y = min(by * 4 + py, h - 1)
                    o = (y * w + x) * 4
                    block.append((rgba[o], rgba[o + 1], rgba[o + 2], rgba[o + 3]))
            out += _encode_bc1_block(block)
    return bytes(out)


def _luma(px):
    return px[0] * 299 + px[1] * 587 + px[2] * 114


def _encode_bc2_block(pixels):
    alpha_bits = 0
    for i, px in enumerate(pixels):
        a4 = min(15, (px[3] + 8) >> 4)
        alpha_bits |= a4 << (i * 4)
    alpha_bytes = alpha_bits.to_bytes(8, "little")

    lo = min(pixels, key=_luma)
    hi = max(pixels, key=_luma)
    c0 = _to565(hi[0], hi[1], hi[2])
    c1 = _to565(lo[0], lo[1], lo[2])
    if c0 == c1:
        return alpha_bytes + struct.pack("<HHI", c0, c1, 0)
    p0 = _color565(c0)
    p1 = _color565(c1)
    palette = [
        p0, p1,
        ((2 * p0[0] + p1[0]) // 3, (2 * p0[1] + p1[1]) // 3, (2 * p0[2] + p1[2]) // 3),
        ((p0[0] + 2 * p1[0]) // 3, (p0[1] + 2 * p1[1]) // 3, (p0[2] + 2 * p1[2]) // 3),
    ]
    codes = 0
    for i, px in enumerate(pixels):
        best_c, best_d = 0, 1 << 30
        for ci, pal in enumerate(palette):
            dr, dg, db = px[0] - pal[0], px[1] - pal[1], px[2] - pal[2]
            d = dr * dr + dg * dg + db * db
            if d < best_d:
                best_d, best_c = d, ci
        codes |= best_c << (i * 2)
    return alpha_bytes + struct.pack("<HHI", c0, c1, codes)


def encode_bc2(rgba: bytes, w: int, h: int) -> bytes:
    out = bytearray()
    bw, bh = (w + 3) // 4, (h + 3) // 4
    for by in range(bh):
        for bx in range(bw):
            block = []
            for py in range(4):
                for px in range(4):
                    x = min(bx * 4 + px, w - 1)
                    y = min(by * 4 + py, h - 1)
                    o = (y * w + x) * 4
                    block.append((rgba[o], rgba[o + 1], rgba[o + 2], rgba[o + 3]))
            out += _encode_bc2_block(block)
    return bytes(out)

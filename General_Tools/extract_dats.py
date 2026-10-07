#!/usr/bin/env python3
"""
extract_dats.py — Extract every decodable asset from ALL ROM .DAT files into extracted/.

Sources (all byte-verified, see docs/ROM-LAYOUT.md + tools/texdat/):
  * type 0x20 texture chunks   -> PNG  (DXT3 '3TXD', DXT1 '1TXD', 8bpp+BGRA-palette)
  * menumap files (m_XX tag)   -> PNG  512x512 minimaps (A1 std palette / B1 embedded)
  * MZB(0x1C)+MMB(0x2E)        -> OBJ+MTL composed zone scenes (tools/zoneparse.py)
  * Bone(0x29)+VertexOs2(0x2A) -> OBJ   skinned bodies in bind pose (ffxi-dat port)
  * D3m(0x1F)                  -> OBJ   effect meshes

Buckets (user-defined, mapping documented in extracted/README.md):
  backgrounds/            ground + wall surface materials
  foregrounds/            prop textures (wood/sheets/details/foliage/building/misc)
  extras/environment/     sky/water/effects layers
  extras/minimaps/        /map images
  models/<src>/           meshes: scene.obj+scene.mtl, skel_*.obj, d3m_*.obj

Naming: <title>_<w>x<h>.png (collisions disambiguated with the source token).
Manifest: extracted/INDEX.csv — every output row -> source file + chunk offset.

Usage:  python tools/extract_dats.py [--only SUBSTR] [--limit N] [--skip-models]
"""
import argparse, csv, hashlib, json, math, os, re, struct, sys, time
from collections import Counter
from pathlib import Path

HERE = Path(__file__).resolve().parent          # tools/
ROOT_DEFAULT = HERE.parent / "data" / "roms"
OUT_DEFAULT  = HERE.parent / "extracted"
PROBE_PAL    = HERE.parent / "probe" / "std_palette_final.json"

sys.path.insert(0, str(HERE))                   # zoneparse.py
sys.path.insert(0, str(HERE / "texdat"))        # texfmt.py
import numpy as np
from PIL import Image
import zoneparse as zp
import ffxi_dat_find as fdf
import uv_island_analysis as uia
import uv_raster as uvr
import semantic_resolver as semres
from texfmt import walk_chunks, parse_texture

MAP_BUCKETS = ("backgrounds", "foregrounds", "extras/environment")


def texture_header(payload):
    """(type, category, name, w, h) from a 0x20 chunk payload, or None."""
    if len(payload) < 29 or payload[17:21] != b"\x28\x00\x00\x00":
        return None
    w, h = struct.unpack_from("<ii", payload, 21)
    if not (0 < w <= 4096 and 0 < h <= 4096):
        return None
    cat = payload[1:9].split(b"\x00")[0].decode("ascii", errors="replace").rstrip(" ")
    name = payload[9:17].split(b"\x00")[0].decode("ascii", errors="replace").rstrip(" ")
    return payload[0], cat, name, w, h


def raw16_cat_name(raw16):
    """(cat, name) from a 16-byte cat8+name8 mesh texture field."""
    if not raw16:
        return "", ""
    cat = raw16[:8].split(b"\x00")[0].decode("ascii", errors="replace").rstrip(" ")
    name = raw16[8:].split(b"\x00")[0].decode("ascii", errors="replace").rstrip(" ")
    return cat, name


# ---------------------------------------------------------------------------
# Category assignment — verbatim from tools/texdat/dat_to_png.py
# (POSITIONAL-TEXTURES knowledge; keep in sync with that file).
# ---------------------------------------------------------------------------
CATEGORY_MAP = {
    "moonshap": "sky", "kasa": "sky", "star01": "sky", "star02": "sky",
    "clod_a01": "sky", "kamome01": "sky", "suny_a01": "sky", "fine_a01": "sky",
    "cld_r01": "sky",
    "sea01": "water", "sea02": "water", "ju_w03c": "water",
    "yuka00": "ground", "ground_1": "ground", "quf": "ground", "myroom02": "ground",
    "stone_wh": "walls_stone", "stone01": "walls_stone",
    "i": "walls_stone", "c": "walls_stone",
    "en_siba": "walls_stone", "en_gake": "walls_stone",
    "kabe": "walls_stucco", "sunakabe": "walls_stucco",
    "j": "walls_stucco", "n": "walls_stucco", "l": "walls_stucco",
    "h": "walls_stucco", "m": "walls_stucco", "u": "walls_stucco",
    "v": "walls_stucco", "a": "walls_stucco",
    "myroom04": "walls_stucco", "myroom03": "walls_stucco",
    "mr_j_01": "walls_stucco", "mr_j_03": "walls_stucco", "mr_j_04": "walls_stucco",
    "brick_m": "walls_brick", "brick_f": "walls_brick",
    "ura_02": "walls_brick", "r": "walls_brick",
    "k": "wood", "e": "wood", "f": "wood", "d": "wood",
    "m_cst_09": "wood", "m_cst_19": "wood", "m_dsk_09": "wood",
    "g": "sheets", "s": "sheets",
    "mark_01": "sheets", "mark_02": "sheets",
    "myroom01": "sheets", "m_bed_04": "sheets",
    "mr_j_d": "sheets", "mr_j_02": "sheets",
    "t": "details", "w": "details", "p": "details",
    "m_obj_21": "details", "m_cst_06": "details", "komono1": "details",
    "m_fgr_01": "foliage", "m_fgr_22": "foliage",
    "lf01": "effects", "lf02": "effects", "lf03": "effects",
    "trrp": "effects", "light2": "effects",
}


def categorize(name: str, category_field: str) -> str:
    if name in CATEGORY_MAP:
        return CATEGORY_MAP[name]
    n = name.lower()
    cf = (category_field or "").lower()
    # non-'model' namespaces are environment/effect layers by construction
    if cf and cf != "model":
        return {"sea": "water", "wave": "water"}.get(cf, "effects") \
            if not n.startswith(("cld", "cloud", "star", "moon", "suny", "fine", "sky")) else "sky"
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


BUCKET = {  # fine category -> user's four buckets
    "ground": "backgrounds", "walls_stone": "backgrounds",
    "walls_stucco": "backgrounds", "walls_brick": "backgrounds",
    "building": "foregrounds", "wood": "foregrounds", "sheets": "foregrounds",
    "details": "foregrounds", "foliage": "foregrounds", "misc": "foregrounds",
    "sky": "extras/environment", "water": "extras/environment",
    "effects": "extras/environment",
}


# ---------------------------------------------------------------------------
# Texture store: bucket placement + cross-file dedupe/collision handling.
# ---------------------------------------------------------------------------
class TexStore:
    def __init__(self, out_root: Path):
        self.root = out_root
        self.by_key = {}          # (title,w,h) -> list of [md5, relpath]
        self.written = 0
        self.dupes = 0

    def put(self, category: str, title: str, w: int, h: int, rgba: bytes,
            sftoken: str) -> "tuple[str,int]":
        """Returns (relpath_from_out_root forward-slash, is_duplicate)."""
        bucket = self.root / BUCKET.get(category, "foregrounds")   # anchored under out/
        md5 = hashlib.md5(rgba).hexdigest()
        key = (title, w, h)
        for m, rel in self.by_key.get(key, []):
            if m == md5:
                self.dupes += 1
                return rel, True
        fname = f"{title}_{w}x{h}.png"
        cands = [fname]
        if (bucket / fname).exists():
            cands.append(f"{title}_{sftoken}_{w}x{h}.png")
        i = 2
        while True:
            rel = bucket / cands[-1]
            if not rel.exists():
                break
            base = f"{title}_{sftoken}" if len(cands) > 1 else title
            cands.append(f"{base}_{i}_{w}x{h}.png")
            i += 1
        img = Image.frombytes("RGBA", (w, h), rgba)
        rel.parent.mkdir(parents=True, exist_ok=True)
        img.save(rel, "PNG", optimize=True)
        relpath = str(rel).replace(os.sep, "/")
        self.by_key.setdefault(key, []).append([md5, relpath])
        self.written += 1
        return relpath, False


# ---------------------------------------------------------------------------
# Minimap (menumap) decode — mirrors src/rom/minimap.cpp byte-for-byte.
# ---------------------------------------------------------------------------
class MiniMap:
    def __init__(self):
        self.std_pal = None

    def std_palette(self):
        if self.std_pal is None:
            d = json.loads(PROBE_PAL.read_text())
            arr = np.zeros((256, 3), dtype=np.uint8)
            for k, v in d.items():
                arr[int(k)] = (v[0], v[1], v[2])   # stored as [r,g,b]
            self.std_pal = arr
        return self.std_pal

    def try_decode(self, buf: bytes):
        """Return dict(title, rgba 512*512*4) or None."""
        if len(buf) < 0x80 + 512 * 512 or buf[0:2] != b"m_":
            return None
        if buf[0x20:0x24] != buf[0:4]:              # chunk header repeats tag
            return None
        var = buf[0x30]
        if var == 0xB1:
            oPix = 0x470
            pal = np.zeros((256, 3), dtype=np.uint8)
            for i in range(256):
                off = 0x70 + i * 4                  # {marker=0x80, B, G, R}
                pal[i] = (buf[off + 3], buf[off + 2], buf[off + 1])   # -> RGB
        elif var == 0xA1:
            oPix = 0x80
            pal = self.std_palette()
        else:
            return None
        if oPix + 512 * 512 > len(buf):
            return None
        name_bytes = buf[0x31:0x47]
        title = None
        s = b""
        for b in name_bytes:                        # up to NUL or '('
            if b == 0 or chr(b) == "(":
                break
            s += bytes([b])
        txt = s.decode("latin-1")
        import re
        m = re.search(r"m_(\d+)", txt)
        if m:
            title = f"map_m{int(m.group(1))}"
        idx = np.frombuffer(buf, dtype=np.uint8, count=512 * 512, offset=oPix)
        rgb = pal[idx]                              # (N,3) gather
        rgba = np.empty((len(idx), 4), dtype=np.uint8)
        rgba[:, :3] = rgb; rgba[:, 3] = 255         # index-0 void keeps its palette tone
        return {"title": title, "rgba": rgba.tobytes()}


# ---------------------------------------------------------------------------
# Zone scene export (MZB placements x MMB models -> composed OBJ + MTL).
# Mirrors src/rom/zonevis.cpp semantics: row-vector TRS, det>0 => mirror.
# ---------------------------------------------------------------------------
def export_zone_scene(buf: bytes, token: str, out_root: Path,
                      tex_lookup: dict = None) -> "dict|None":
    chunks, _ = walk_chunks(buf)
    mzb_payload = None
    mmbs = {}
    for c in chunks:
        payload = buf[c["off"] + 16:c["off"] + c["length"]]
        if c["ctype"] == 0x1C and mzb_payload is None:
            try:
                mzb_payload = payload
            except Exception:
                pass
        elif c["ctype"] == 0x2E:
            try:
                m = zp.parse_mmb(payload)
                mmbs[m["hdr"]["id"] or c["name"]] = m
            except Exception:
                pass
    if mzb_payload is None and not mmbs:
        return None
    placements, _raw = (zp.parse_mzb_placements(mzb_payload)
                        if mzb_payload is not None else ([], b""))

    groups = {}          # texname -> [verts list, faces list]
    group_order = []
    matched = total_tris = 0
    for p in placements:
        m = mmbs.get(p["id"])
        if m is None:
            continue
        matched += 1
        mat = zp.trs_matrix(p["tr"], p["rot"], p["sc"])
        linear = [[mat[0][0], mat[0][1], mat[0][2]],
                  [mat[1][0], mat[1][1], mat[1][2]],
                  [mat[2][0], mat[2][1], mat[2][2]]]
        mir = zp.det3(linear) > 0.0                 # zonevis.cpp:321 rule
        kind = m["hdr"]["kind"]
        for block in m["blocks"]:
            for mod in block["models"]:
                tex = f"{mod['tex'][0]}_{mod['tex'][1]}" if mod["tex"][1] else mod["tex"][0]
                tris = zp.tris_from_model(mod, kind)
                if not tris:
                    continue
                total_tris += len(tris)
                wv = [zp.apply_m(mat, v[:3]) + (v[4], v[5]) for v in mod["verts"]]
                g = groups.get(tex)
                base_v = 0 if g is None else len(g[0])
                if g is None:
                    groups[tex] = [[], []]
                    group_order.append(tex)
                g = groups[tex]
                for a, b, cidx in tris:
                    if mir:
                        a, cidx = cidx, a           # swap tri indices 0 and 2
                    g[1].append((base_v + a + 1, base_v + b + 1, base_v + cidx + 1))
                g[0].extend(wv)

    if not group_order:
        return None
    mdir = out_root / "models" / token
    mdir.mkdir(parents=True, exist_ok=True)
    obj_lines = [f"# zone scene {token}", f"mtllib scene.mtl", "o scene"]
    mtl_lines = [f"# scene materials for {token}"]
    tex_rel = tex_lookup or {}
    for tex in group_order:
        verts, faces = groups[tex]
        obj_lines.append(f"usemtl mat_{tex}")
        for x, y, z, u, v in verts:
            obj_lines.append(f"v {x:.4f} {y:.4f} {z:.4f}")
        for x, y, z, u, v in verts:
            obj_lines.append(f"vt {u:.6f} {v:.6f}")
        for a, b, cidx in faces:
            obj_lines.append(f"f {a} {b} {cidx}")
        png = tex_rel.get(tex)
        mtl_lines += [f"newmtl mat_{tex}", "Kd 1 1 1"]
        if png:
            mtl_lines.append(f"map_Kd {os.path.relpath(out_root / png, mdir).replace(os.sep,'/')}")
        else:
            mtl_lines.append(f"# texture not in ROM buckets (cat/name={tex})")
    (mdir / "scene.obj").write_text("\n".join(obj_lines) + "\n", encoding="ascii", errors="replace")
    (mdir / "scene.mtl").write_text("\n".join(mtl_lines) + "\n", encoding="ascii", errors="replace")
    return {"placements": len(placements), "matched": matched, "tris": total_tris,
            "materials": len(group_order)}


# ---------------------------------------------------------------------------
# Skeleton (Bone 0x29) — port of ffxi-dat/src/bone.rs.
# ---------------------------------------------------------------------------
BONE_DT = np.dtype([("parent", "u1"), ("flags", "u1"),
                    ("rot", "<f4", (4,)), ("trans", "<f4", (3,))])


def parse_bone(payload: bytes):
    if len(payload) < 4:
        return None
    count = struct.unpack_from("<H", payload, 2)[0]
    need = 4 + count * 30
    if len(payload) < need or count == 0:
        return None
    arr = np.frombuffer(payload[4:need], dtype=BONE_DT).reshape(count)
    # bind-pose world matrices (row-major), parent chain walk — bone.rs as-is
    n = count
    world = [np.identity(4, dtype=np.float64)] * n

    def qmat(q):
        x, y, z, w = q
        return np.array([
            [1 - 2 * (y * y + z * z), 2 * (x * y - w * z),     2 * (x * z + w * y),     0],
            [2 * (x * y + w * z),     1 - 2 * (x * x + z * z), 2 * (y * z - w * x),     0],
            [2 * (x * z - w * y),     2 * (y * z + w * x),     1 - 2 * (x * x + y * y), 0],
            [0, 0, 0, 1]], dtype=np.float64)

    for i in range(n):
        b = arr[i]
        m = qmat(b["rot"])
        t = np.array([b["trans"][0], b["trans"][1], b["trans"][2], 1.0])
        m[0][3], m[1][3], m[2][3] = t[0], t[1], t[2]
        p = int(b["parent"])
        if p == 0xFF or p == i or p >= n:
            world[i] = m
        else:
            world[i] = world[p] @ m
    return world


# ---------------------------------------------------------------------------
# Skinned mesh (VertexOs2 0x2A) — port of ffxi-dat/src/skel_mesh.rs.
# Skin formula per kuluu skinned_ffxi.wgsl: M0*vec4(p0,w0) + M1*vec4(p1,w1)
# (p0/p1 are joint-local, PRE-WEIGHTED); normals w-blended. symmetric (f5==1)
# files emit a second mirrored buffer per instruction (flip_vertex rules).
# ---------------------------------------------------------------------------


def _skin_terms(R, T, j, p, w):
    """world contribution of one influence: R_j·p + t_j*w  (pre-weighted p).
    j is a per-corner joint index array; R[j] is batched (K,3,3)."""
    return np.einsum("njk,nk->nj", R[j], p) + T[j] * w[:, None]


def export_skinned(buf: bytes, token: str, out_root: Path) -> "dict|None":
    chunks, _ = walk_chunks(buf)
    bone_payload = None; vos2s = []
    for c in chunks:
        payload = buf[c["off"] + 16:c["off"] + c["length"]]
        if c["ctype"] == 0x29 and bone_payload is None:
            bone_payload = payload
        elif c["ctype"] == 0x2A:
            vos2s.append(payload)
    if not vos2s or bone_payload is None:
        return None
    world = parse_bone(bone_payload)
    if world is None:
        return None
    W = np.stack(world)                          # (J,4,4)
    R = W[:, :3, :3]; T = W[:, :3, 3]            # rotation + translation column
    Jn = len(W)

    mdir = out_root / "models" / token
    total_v = total_t = files_written = 0
    per_tex = {}                                 # tex -> [verts (V,5), tris flat]
    # per-texture accumulators: [pos(V,3), nrm(V,3), uv(V,2), tris list]
    def emit(texname, vi, pos, nm, uv):
        g = per_tex.setdefault(texname or "untextured", [[], [], [], []])
        base = sum(len(x) for x in g[0]) if isinstance(g[0], list) else len(g[0]) \
            if False else (sum(map(len, g[0])))
        g[0].append(pos); g[1].append(nm); g[2].append(uv)
        g[3].append(vi.reshape(-1, 3).astype(np.int64) + base)

    for payload in vos2s:
        parsed = _parse_vos2_full(payload)
        if not parsed:
            continue
        j0 = np.clip(parsed["j0"], 0, Jn - 1).astype(np.int64)
        j1 = np.clip(parsed["j1"], 0, Jn - 1).astype(np.int64)
        j0f = np.clip(parsed["j0f"], 0, Jn - 1).astype(np.int64)
        j1f = np.clip(parsed["j1f"], 0, Jn - 1).astype(np.int64)
        for m in parsed["meshes"]:
            tris, uv, _mir = _expand_mesh(m)
            if len(tris) == 0:
                continue
            vi = tris.reshape(-1)
            a0 = j0[vi]; a1 = j1[vi]
            w0v = parsed["w0"][vi]; w1v = parsed["w1"][vi]
            w1m = (w1v > 1e-6)[:, None]                    # column mask for (K,3)
            pos = _skin_terms(R, T, a0, parsed["p0"][vi], w0v) \
                + np.where(w1m,
                           _skin_terms(R, T, a1, parsed["p1"][vi], w1v), 0.0)
            nm = np.einsum("njk,nk->nj", R[a0], parsed["n0"][vi]) * w0v[:, None]
            if w1m.any():
                nm = nm + np.where(w1m,
                                   np.einsum("njk,nk->nj", R[a1], parsed["n1"][vi]) * w1v[:, None],
                                   0.0)
            emit(m["tex"], vi, pos, nm, uv[:len(vi)])
            # symmetric (f5==1): mirrored twin with flipped axes + flipped joints
            if parsed["symmetric"]:
                fa0 = parsed["fl0"][vi]; fa1 = parsed["fl1"][vi]
                sgn0 = np.ones((len(vi), 3)); sgn0[:, 0] *= -np.where(fa0 == 1, 1, 0)
                sgn0[:, 1] *= -np.where(fa0 == 2, 1, 0); sgn0[:, 2] *= -np.where(fa0 == 3, 1, 0)
                sgn1 = np.ones((len(vi), 3)); sgn1[:, 0] *= -np.where(fa1 == 1, 1, 0)
                sgn1[:, 1] *= -np.where(fa1 == 2, 1, 0); sgn1[:, 2] *= -np.where(fa1 == 3, 1, 0)
                mpos = _skin_terms(R, T, j0f[vi], parsed["p0"][vi] * sgn0, w0v) \
                    + np.where(w1m,
                               _skin_terms(R, T, j1f[vi], parsed["p1"][vi] * sgn1, w1v), 0.0)
                mn = (np.einsum("njk,nk->nj", R[j0f[vi]], parsed["n0"][vi] * sgn0) * w0v[:, None]
                      + np.where(w1m,
                                 np.einsum("njk,nk->nj", R[j1f[vi]], parsed["n1"][vi] * sgn1) * w1v[:, None],
                                 0.0))
                emit(m["tex"] + "_mir", vi, mpos, mn, uv[:len(vi)])
    for texname, (pparts, nparts, upt, tparts) in per_tex.items():
        if not pparts:
            continue
        pos = np.concatenate(pparts, axis=0)
        nm = np.concatenate(nparts, axis=0)
        uvall = np.concatenate(upt, axis=0)
        tris = np.concatenate(tparts, axis=0)
        i = 1
        while True:
            target = mdir / f"skel_{re.sub(r'[^A-Za-z0-9_]', '_', texname) or 'mesh'}_{i}.obj"
            if not target.exists():
                break
            i += 1
        lines = [f"# skinned bind-pose mesh {token} tex='{texname}' tris={len(tris)}",
                 "# frame: client authoring (Y down); joints in bind pose; dual-influence skin baked"]
        pv = pos[:: max(1, len(pos) // 2000)]          # sample for fast header bbox
        lines.append(f"# bbox x[{pv[:,0].min():.2f}..{pv[:,0].max():.2f}] "
                     f"y[{pv[:,1].min():.2f}..{pv[:,1].max():.2f}] z[{pv[:,2].min():.2f}..{pv[:,2].max():.2f}]")
        for x, y, z in pos:
            lines.append(f"v {x:.4f} {y:.4f} {z:.4f}")
        for x, y, z in nm:
            n = math.sqrt(x * x + y * y + z * z) or 1.0
            lines.append(f"vn {x/n:.4f} {y/n:.4f} {z/n:.4f}")
        for u, v in uvall:
            lines.append(f"vt {u:.6f} {v:.6f}")
        for a, b, cidx in tris:
            lines.append(f"f {a+1}/{a+1}/{a+1} {b+1}/{b+1}/{b+1} {cidx+1}/{cidx+1}/{cidx+1}")
        mdir.mkdir(parents=True, exist_ok=True)
        target.write_text("\n".join(lines) + "\n", encoding="ascii", errors="replace")
        files_written += 1
        total_v += len(pos); total_t += len(tris)
    return None if files_written == 0 else {"objs": files_written, "verts": total_v, "tris": total_t}


def _parse_vos2_full(payload: bytes):
    """Full port of skel_mesh.rs parse() -> dict(j0,j1,fl0,fl1,p0..n1,w0,w1,meshes)."""
    if len(payload) < 0x24:
        return None
    o = 0
    def u8():  nonlocal o; v = payload[o]; o += 1; return v
    def u16(): nonlocal o; v = struct.unpack_from("<H", payload, o)[0]; o += 2; return v
    def u32(): nonlocal o; v = struct.unpack_from("<I", payload, o)[0]; o += 4; return v

    u8(); u8()                             # _f1, _f2 (skipped in Rust parse)
    f3 = u8(); cloth = (f3 & 1) != 0; use_joint_array = (f3 & 0x80) != 0
    has_normals = not cloth
    u8()                                   # occlude_type (f4)
    symmetric = u8() == 1                  # f5
    u8()                                   # _f6
    instruction_offset = 2 * u32()
    u8(); u8()                             # mesh_count, instr_count
    joint_array_offset = 2 * u32()
    num_joints = u16()
    vertex_counts_offset = 2 * u32()
    nvc = u16()
    if nvc != 2:
        return None
    vjm_off = 2 * u32(); u16()
    vdata_off = 2 * u32(); u16()
    u32(); u16()                           # end offset/size
    if cloth:
        o += 2 + 2 + 4 + 2 + 2 + 2 + 4 + 4 + 4 + 4
    if joint_array_offset + num_joints * 2 > len(payload): return None
    palette = np.frombuffer(payload, dtype="<u2", count=num_joints, offset=joint_array_offset)

    single = struct.unpack_from("<H", payload, vertex_counts_offset)[0]
    double = struct.unpack_from("<H", payload, vertex_counts_offset + 2)[0]
    total = single + double
    if vjm_off + total * 4 > len(payload): return None
    refs = np.frombuffer(payload, dtype="<u2", count=total * 2, offset=vjm_off).reshape(total, 2)
    j0raw, j1raw = refs[:, 0], refs[:, 1]
    if use_joint_array and num_joints:
        j0 = palette[np.minimum(j0raw & 0x7F, num_joints - 1)]
        j1 = palette[np.minimum(j1raw & 0x7F, num_joints - 1)]
        j0f = palette[np.minimum((j0raw >> 7) & 0x7F, num_joints - 1)]
        j1f = palette[np.minimum((j1raw >> 7) & 0x7F, num_joints - 1)]
    else:
        j0 = (j0raw & 0x7F).astype(np.int64)
        j1 = (j1raw & 0x7F).astype(np.int64)
        j0f = ((j0raw >> 7) & 0x7F).astype(np.int64)
        j1f = ((j1raw >> 7) & 0x7F).astype(np.int64)
    fl0 = ((j0raw >> 14) & 3).astype(np.int8)
    fl1 = ((j1raw >> 14) & 3).astype(np.int8)

    stride_single = 24 if has_normals else 12
    stride_double = 56 if has_normals else 28
    need = single * stride_single + double * stride_double
    if vdata_off + need > len(payload): return None

    p0 = np.zeros((total, 3)); n0 = np.zeros((total, 3))
    p1 = np.zeros((total, 3)); n1 = np.zeros((total, 3))
    w0 = np.ones(total);      w1 = np.zeros(total)
    if single:
        s = np.frombuffer(payload, dtype="<f4", count=single * (stride_single // 4),
                          offset=vdata_off).reshape(single, stride_single // 4)
        p0[:single] = s[:, :3]
        if has_normals: n0[:single] = s[:, 3:6]
    if double:
        d = np.frombuffer(payload, dtype="<f4", count=double * (stride_double // 4),
                          offset=vdata_off + single * stride_single).reshape(double, stride_double // 4)
        p0[single:] = d[:, [0, 2, 4]]
        p1[single:] = d[:, [1, 3, 5]]
        w0[single:] = d[:, 6]; w1[single:] = d[:, 7]
        if has_normals:
            n0[single:] = d[:, [8, 10, 12]]
            n1[single:] = d[:, [9, 11, 13]]

    o = instruction_offset
    meshes = []
    partial = False
    tex_name = ""
    tex_raw16 = b""
    REC = np.dtype([("i", "<u2"), ("uv", "<f4", (2,))])
    TRI36 = np.dtype([("i", "<u2", (3,)), ("uv", "<f4", (6,))])
    while True:
        if o + 2 > len(payload): break
        op = struct.unpack_from("<H", payload, o)[0]; o += 2
        if op == 0xFFFF: break
        elif op == 0x8010:
            o += 44                             # read_render_properties = 44B (bgra+2f+4flags+4f+2u16+2f) verified on e_ol
        elif op == 0x8000:                      # TEXNAME 16B (cat8+name8, space-padded)
            tex_raw16 = payload[o:o + 16]
            raw = tex_raw16.split(b"\x00")[0].decode("latin-1")
            tex_name = re.sub(r"\s+", "_", raw).strip("_")   # 'tim     em_b12_1' -> tim_em_b12_1
            o += 16
        elif op == 0x5453:                        # tri strip
            nt = u16()
            if o + (nt + 2) * 8 > len(payload): break
            arr = np.frombuffer(payload, dtype=REC, count=nt + 2, offset=o); o += (nt + 2) * 8
            meshes.append({"tex": tex_name, "tex_raw": tex_raw16, "mode": "strip",
                           "idx": arr["i"].copy(), "uv": arr["uv"].copy()})
        elif op == 0x0054:                        # tri mesh (30B/tri: i,i,i + u,v x3)
            nt = u16()
            if o + nt * 30 > len(payload): break
            raw = np.frombuffer(payload, dtype=np.uint8, count=nt * 30, offset=o).reshape(nt, 30)
            idx = raw[:, :6].copy().view("<u2").reshape(nt, 3)          # 3 x u16
            uvb = raw[:, 6:].astype(np.uint8)
            uvf = np.frombuffer(uvb.tobytes(), dtype="<f4", count=nt * 6).reshape(nt, 3, 2)
            o += nt * 30
            meshes.append({"tex": tex_name, "tex_raw": tex_raw16, "mode": "tri",
                           "idx": idx.copy(), "uv": uvf.copy()})
        elif op == 0x0043:                        # untextured tri mesh (16B/tri)
            nt = u16()
            if o + nt * 16 > len(payload): break
            idx = np.frombuffer(payload, dtype="<u2", count=nt * 3, offset=o); o += nt * 16
            meshes.append({"tex": tex_name or "untextured", "tex_raw": tex_raw16,
                           "mode": "tri", "idx": idx.copy(),
                           "uv": np.zeros((nt, 3, 2))})
        elif op == 0x4353:                        # single-color untextured strip
            nt = u16()
            if o + (nt + 2) * 2 + 4 > len(payload): break
            idx = np.frombuffer(payload, dtype="<u2", count=nt + 2, offset=o)
            o += (nt + 2) * 2 + 4                 # 3 idx + one bgra color, then per-tri idx
        else:
            # unknown opcode: the stream up to here was in sync, so keep the
            # meshes harvested so far and stop. Bailing entirely orphaned
            # textures whose VOS2 chunk carries an opcode this port does not
            # know (e.g. 0x3f16 on the fairy model).
            partial = True
            break
    if not meshes:
        return None
    return {"j0": j0.astype(np.int64), "j1": j1.astype(np.int64),
            "j0f": j0f.astype(np.int64), "j1f": j1f.astype(np.int64),
            "fl0": fl0, "fl1": fl1,
            "p0": p0, "p1": p1, "n0": n0, "n1": n1, "w0": w0, "w1": w1,
            "symmetric": symmetric, "meshes": meshes, "partial": partial}


def _expand_mesh(m):
    """-> (tris (K,3) vertex indices, uv (K,2), mirror=False). Strips: alternating winding."""
    if m["mode"] == "strip":
        idx = m["idx"]; nt = len(idx) - 2
        tris = np.empty((max(nt, 0), 3), dtype=np.int64)
        for k in range(max(nt, 0)):
            a, b, c = int(idx[k]), int(idx[k + 1]), int(idx[k + 2])
            if k & 1: tris[k] = (c, b, a)
            else:     tris[k] = (a, b, c)
        return tris, m["uv"][tris.reshape(-1)], False   # gather per-corner UVs
    uv = m["uv"].reshape(-1, 2) if m["uv"].ndim == 3 else m["uv"]
    return m["idx"].reshape(-1, 3).astype(np.int64), uv, False


# ---------------------------------------------------------------------------
# D3m (0x1F) — port of ffxi-dat/src/d3m.rs.
# ---------------------------------------------------------------------------
def export_d3m(buf: bytes, token: str, out_root: Path) -> "dict|None":
    chunks, _ = walk_chunks(buf)
    mdir = out_root / "models" / token
    total_t = 0; written = 0
    for ci, c in enumerate(chunks):
        if c["ctype"] != 0x1F:
            continue
        body = buf[c["off"] + 16:c["off"] + c["length"]]
        if len(body) < 0x1E or struct.unpack_from("<I", body, 0)[0] != 6:
            continue
        ntri = struct.unpack_from("<H", body, 6)[0]
        tex = body[0x0E:0x1E].split(b"\x00")[0].decode("latin-1").strip()
        need = 0x1E + ntri * 3 * 36
        if len(body) < need or ntri == 0:
            continue
        arr = np.frombuffer(body, dtype="<f4", count=ntri * 3 * 9, offset=0x1E).reshape(ntri * 3, 9)
        pos, uv = arr[:, :3], arr[:, [7, 8]]
        i = 1
        while True:
            target = mdir / f"d3m_{re.sub(r'[^A-Za-z0-9_]', '_', tex) or c['name']}_{i}.obj"
            if not target.exists(): break
            i += 1
        lines = [f"# d3m effect mesh {token} chunk={c['name']} tris={ntri} tex='{tex}'"]
        for row in pos:
            lines.append(f"v {row[0]:.4f} {row[1]:.4f} {row[2]:.4f}")
        for u, v in uv:
            lines.append(f"vt {u:.6f} {v:.6f}")
        k = 1
        for t in range(ntri):
            lines.append(f"f {3*t+1} {3*t+2} {3*t+3}")
        mdir.mkdir(parents=True, exist_ok=True)
        target.write_text("\n".join(lines) + "\n", encoding="ascii", errors="replace")
        total_t += ntri; written += 1
    return None if written == 0 else {"objs": written, "tris": total_t}


def sftoken_of(rel: str) -> str:
    parts = rel.replace("\\", "/").split("/")
    if len(parts) >= 2 and parts[-1].lower().endswith(".dat"):
        base = [re.sub(r"[^A-Za-z0-9]", "", p).lower() for p in parts[:-1]]
        return "_".join(base + [parts[-1][:-4]])
    return re.sub(r"[^A-Za-z0-9]", "", parts[-1]).lower() or "file"


# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------
# Map pass (final): .map.toml atlas/semantic siblings for every texture PNG.
# ---------------------------------------------------------------------------
def _build_path_to_fids(tables):
    """path -> sorted list of file ids that resolve to it.

    The fid -> path mapping is many-to-one (several fids can alias the same
    DAT), so a path may carry several fids. Callers that need "is this a
    named zone / a mob model" must check ANY of the fids, not just one."""
    m = {}
    for rom_dir, rom_index, vtable, ftable in tables:
        for fid in range(min(len(vtable), len(ftable) // 2)):
            if vtable[fid] != rom_index:
                continue
            (v,) = struct.unpack_from("<H", ftable, fid * 2)
            m.setdefault(f"{rom_dir}/{v >> 7}/{v & 0x7F}.DAT", []).append(fid)
    return {k: sorted(v) for k, v in m.items()}


def _scan_mesh_dat(buf, dat_rel, fid, fids, refs_by_tex, dat_chunks, zone_dats, stats):
    """One source DAT: record local 0x20 chunks + every mesh submesh's
    (texture, UVs). refs_by_tex[(cat,name)] += (dat_rel, fid, mesh_label,
    submesh_idx, uv (ntris,3,2) float32). `fid` is a representative file id
    for the refs record; `fids` is the full set of file ids aliasing this
    DAT (the zone-scene check must accept ANY of them)."""
    o = 0
    kinds = []
    while o + 16 <= len(buf):
        tl = struct.unpack_from("<I", buf, o + 4)[0]
        length = ((tl >> 7) & 0x7FFFF) << 4
        if length < 16 or o + length > len(buf):
            return
        # 4-byte chunk name in the container header (readable tag, e.g.
        # 'bomb', 'hh_b' for 0x29/0x2A skel chunks)
        kinds.append((tl & 0x7F, o, length,
                      buf[o:o + 4].rstrip(b"\x00").decode(errors="replace")))
        o += length
    if not any(k in (0x1C, 0x2E, 0x2A, 0x1F) for k, _, _, _ in kinds):
        return

    for ctype, off, length, chunk_name in kinds:
        payload = buf[off + 16:off + length]
        if ctype == 0x20:
            hdr = texture_header(payload)
            if hdr:
                _t, cat, name, w, h = hdr
                dat_chunks.setdefault(dat_rel, {})[(cat, name)] = (w, h)
        elif ctype == 0x1C:
            try:
                placements, _raw = zp.parse_mzb_placements(payload)
                if placements:
                    zone_dats[dat_rel] = fids
            except Exception:
                pass
        elif ctype == 0x2E:
            try:
                m = zp.parse_mmb(payload)
            except Exception:
                stats["mmb_fails"] += 1
                continue
            mmb_id = m["hdr"]["id"] or "?"
            kind = m["hdr"]["kind"]
            for si, block in enumerate(m["blocks"]):
                for mi, mod in enumerate(block["models"]):
                    cat, name = mod["tex"]
                    tris = zp.tris_from_model(mod, kind)
                    if not tris or not name:
                        continue
                    verts = mod["verts"]
                    uvv = np.empty((len(verts), 2), dtype=np.float32)
                    for vi, v in enumerate(verts):
                        uvv[vi] = (v[4], v[5])
                    idx = np.asarray(tris, dtype=np.int64).reshape(-1, 3)
                    refs_by_tex.setdefault((cat, name), []).append(
                        (dat_rel, fid, mmb_id, mi, uvv[idx]))
        elif ctype == 0x2A:
            try:
                parsed = _parse_vos2_full(payload)
            except Exception:
                parsed = None
            if not parsed:
                stats["vos2_fails"] += 1
                continue
            if parsed.get("partial"):
                stats["vos2_partial"] = stats.get("vos2_partial", 0) + 1
            chunk_tag = chunk_name or "?"
            for mi, m in enumerate(parsed["meshes"]):
                cat, name = raw16_cat_name(m.get("tex_raw", b""))
                if not name:
                    continue
                try:
                    tris, uv, _mir = _expand_mesh(m)
                except Exception:
                    continue
                if not len(tris):
                    continue
                # _expand_mesh returns per-corner UVs flat (K,2); the map
                # pass needs (ntri,3,2) like the MMB/D3M branches
                uv = np.ascontiguousarray(uv, dtype=np.float32)
                refs_by_tex.setdefault((cat, name), []).append(
                    (dat_rel, fid, f"vos2_{chunk_tag}", mi,
                     uv.reshape(len(tris), 3, 2)))
        elif ctype == 0x1F:
            if len(payload) < 0x1E or struct.unpack_from("<I", payload, 0)[0] != 6:
                continue
            ntri = struct.unpack_from("<H", payload, 6)[0]
            need = 0x1E + ntri * 3 * 36
            if ntri == 0 or len(payload) < need:
                continue
            cat, name = raw16_cat_name(payload[0x0E:0x1E])
            if not name:
                continue
            arr = np.frombuffer(payload, dtype="<f4",
                                count=ntri * 3 * 9, offset=0x1E).reshape(ntri * 3, 9)
            uv = np.ascontiguousarray(arr[:, [7, 8]], dtype=np.float32) \
                .reshape(ntri, 3, 2)
            refs_by_tex.setdefault((cat, name), []).append(
                (dat_rel, fid, f"d3m_{chunk_name or '?'}", 0, uv))


def generate_maps(root, out, source_root, lsb_root, zones_dir, live_pools_file):
    t0 = time.time()
    index = out / "INDEX.csv"
    if not index.exists():
        sys.exit(f"no {index} — run the extraction first")

    # ---- target PNGs from INDEX.csv ----------------------------------------
    pngs = {}          # relpath -> {srcs, name, w, h, fine_cat}
    with open(index, newline="", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            rel = row["output_relpath"].replace("\\", "/")
            if not rel.startswith(MAP_BUCKETS + ("/",)) or not rel.lower().endswith(".png"):
                continue
            e = pngs.setdefault(rel, {"srcs": set(), "name": row["name"],
                                      "w": int(row["w"]), "h": int(row["h"]),
                                      "fine_cat": row["category_or_note"]})
            e["srcs"].add(row["source_dat"].replace("\\", "/"))
    print(f"map pass: {len(pngs)} target PNGs in {', '.join(MAP_BUCKETS)}")

    # ---- tables + semantics -------------------------------------------------
    tables = fdf.load_tables(str(source_root))
    path_to_fids = _build_path_to_fids(tables)
    # zone scene DAT file id == zone id (VTABLE/FTABLE), so the d_msg table
    # (a list indexed by zone id) becomes a fid -> name dict
    zone_names = {i: n for i, n in
                  enumerate(semres.load_zone_names(source_root, tables)) if n}
    try:
        semres.load_client_family_names(source_root, tables)
        print("client family name table: validated")
    except semres.SemanticError as e:
        print(f"[warn] client family table: {e}")
    lsb = semres.LsbSemantics(lsb_root, HERE / "vendor" / "lsb_commit.txt",
                              extra_pools_file=live_pools_file)
    extra_species = semres.load_mobs_yaml_species(zones_dir)
    print(f"LSB pinned {lsb.commit[:12]}  extra species labels: {len(extra_species)} models")

    # fid -> mob semantics (mob model DATs only)
    model_sem_by_fid = {}

    def mob_sem(fid):
        if fid not in model_sem_by_fid:
            sem = None
            for upper, base in semres.NPC_DAT_ID_BANDS:
                mid = fid - base
                if 0 <= mid < upper:
                    sem = lsb.mob_semantics(mid, extra_species)
                    break
            model_sem_by_fid[fid] = sem
        return model_sem_by_fid[fid]

    # ---- walk the source DATs ------------------------------------------------
    refs_by_tex = {}
    dat_chunks = {}
    zone_dats = {}
    stats = {"files": 0, "mesh_dats": 0, "mmb_fails": 0, "vos2_fails": 0,
             "vos2_partial": 0}
    rom_dirs = [d for d in [source_root / "ROM"] +
                [source_root / f"ROM{i}" for i in range(2, 10)] if d.exists()]
    for rd in rom_dirs:
        for p in sorted(rd.rglob("*.DAT")):
            stats["files"] += 1
            dat_rel = p.relative_to(source_root).as_posix()
            fids = path_to_fids.get(dat_rel)
            if not fids:
                continue
            try:
                buf = p.read_bytes()
            except OSError:
                continue
            # representative fid for the refs record: prefer one that is a
            # named zone (so zone semantics resolve), else the smallest
            fid = next((f for f in fids if f in zone_names), fids[0])
            _scan_mesh_dat(buf, dat_rel, fid, fids, refs_by_tex, dat_chunks,
                           zone_dats, stats)
            if dat_rel in zone_dats or dat_chunks.get(dat_rel):
                stats["mesh_dats"] += 1
            if stats["files"] % 5000 == 0:
                print(f"  walk {stats['files']} files "
                      f"({time.time() - t0:.0f}s)", file=sys.stderr)
    total_refs = sum(len(v) for v in refs_by_tex.values())
    total_tris = sum(len(r[4]) for v in refs_by_tex.values() for r in v)
    print(f"walk done in {time.time() - t0:.0f}s: {stats['files']} files, "
          f"{len(refs_by_tex)} textures referenced, {total_refs} submeshes, "
          f"{total_tris} triangles")
    if stats.get("vos2_partial"):
        print(f"[warn] {stats['vos2_partial']} VOS2 chunk(s) hit an unknown opcode; "
              f"partial harvest kept the meshes before the unknown op")

    # MZB chunks can appear in non-zone containers; a DAT only counts as a
    # zone scene when ANY of its aliasing file ids is a named zone id
    # (fid -> path is many-to-one, so one fid per DAT is not authoritative)
    unnamed = [d for d, fset in zone_dats.items()
               if not any(f in zone_names for f in fset)]
    if unnamed:
        print(f"[warn] {len(unnamed)} MZB DAT(s) whose file ids are not named "
              f"zone ids; not treated as zone scenes, e.g. {unnamed[:3]}")
        zone_dats = {d: fset for d, fset in zone_dats.items()
                     if any(f in zone_names for f in fset)}

    # ---- per-texture maps -----------------------------------------------------
    generated_at = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    map_rows = {}       # png relpath -> (map_rel, region_count, subject, family, conf)
    conf_hist = Counter()
    orphan_count = 0
    warnings_log = []
    sanity_mobs = {}
    sanity_zones = {}

    # reverse index: (source_dat, name) -> set of chunk categories
    cats_by_name = {}
    for src, chunks in dat_chunks.items():
        for (c, n), _wh in chunks.items():
            cats_by_name.setdefault((src, n), set()).add(c)

    for rel, info in sorted(pngs.items()):
        name, w, h = info["name"], info["w"], info["h"]
        cats = set()
        for src in info["srcs"]:
            cats |= cats_by_name.get((src, name), set())
        if not cats:
            cats = {""}
            warnings_log.append(f"{rel}: no local chunk catalog for source DAT(s); "
                                "mesh refs matched by name only")
        cat = sorted(cats)[0]
        if len(cats) > 1:
            warnings_log.append(f"{rel}: multiple chunk categories {sorted(cats)}; "
                                f"using {cat!r}")
        key = (cat, name)
        refs = refs_by_tex.get(key, [])
        good = []
        skipped_local = 0
        for dat_rel, fid, mesh_label, sub, uv in refs:
            local = dat_chunks.get(dat_rel, {}).get((cat, name))
            if local is None or local != (w, h):
                skipped_local += 1
                continue
            good.append((dat_rel, fid, mesh_label, sub, uv))
        if skipped_local:
            warnings_log.append(f"{rel}: {skipped_local} submesh ref(s) from DATs "
                                f"whose local {cat}_{name} chunk differs in size or is "
                                f"absent; excluded")

        dat_fids = {fid for _d, fid, _m, _s, _u in good}
        zone_fids = {fid for d, fid, _m, _s, _u in good if d in zone_dats}
        rgba = None
        png_path = out / rel
        if png_path.exists():
            try:
                rgba = Image.open(png_path).convert("RGBA").tobytes()
            except OSError as e:
                warnings_log.append(f"{rel}: unreadable PNG ({e}); alpha skipped")

        if good:
            uv_all = np.concatenate([uv for _d, _f, _m, _s, uv in good])
            labels = np.repeat(
                np.array([f"{d}::{m}.submesh_{s}" for d, _f, m, s, _u in good],
                         dtype=object),
                np.array([len(u) for _d, _f, _m, _s, u in good]))
            mask_data = uvr.build_edge_data(uv_all)
            closure = uvr.island_wrap_closure(mask_data, uv_all)
            regions = uia.build_regions(w, h, uv_all, rgba, mesh_parts_by_tri=labels,
                                        wrap_closure=closure)
            cover, seam = uvr.rasterize_masks_from_data(uv_all, w, h, mask_data)
            used_by_meshes = sorted({f"{d}::{m}" for d, _f, m, _s, _u in good})
            scenes = sorted({f"models/{sftoken_of(d)}/scene.obj" for d, fid, _m, _s, _u
                             in good if d in zone_dats})
            orphan = False
        else:
            regions = []
            used_by_meshes = []
            scenes = []
            orphan = True
            # no mesh reference: assume the whole image is used (the safe
            # default for the upscaling pipeline — fall through to the
            # original). Every PNG still gets both mask siblings.
            cover = np.full((h, w), 255, dtype=np.uint8)
            seam = np.ones((h, w), dtype=np.uint8)

        if not regions:
            # no usable UV island (or no refs): one full-image region. For
            # non-orphan textures the whole referencing mesh is degenerate,
            # so the region carries the submesh-level mesh linkage.
            bbox = [0, 0, w, h]
            if rgba is not None:
                alpha_pattern, _s = uia.analyze_alpha(rgba, w, h, bbox)
            else:
                alpha_pattern = "unknown"
            regions = [{"id": "region_0", "bbox": bbox,
                        "uv_island_triangle_count": 0,
                        "technique": uia.classify_technique("none", alpha_pattern),
                        "tiling": "none", "alpha_pattern": alpha_pattern,
                        "mesh_parts": sorted(
                            {f"{d}::{m}.submesh_{s}" for d, _f, m, s, _u in good})}]
            if good:
                regions[0]["uv_island_triangle_count"] = sum(
                    len(u) for _d, _f, _m, _s, u in good)

        if orphan:
            category, subject, family, zone_hint, fam_id = \
                "unknown", "", "", "", None
            confidence = "orphan_no_mesh_reference"
            warns = ["no mesh references found; region left for review"]
            orphan_count += 1
        else:
            category, subject, family, zone_hint, fam_id, confidence, warns = \
                semres.resolve_texture_semantics(info["fine_cat"], zone_names,
                                                 zone_fids, lsb, dat_fids,
                                                 {f: mob_sem(f) for f in dat_fids})
        conf_hist[confidence] += 1
        if category == "mob_skin" and subject:
            sanity_mobs.setdefault((subject, family), rel)
        if category in ("background", "foreground") and zone_hint:
            sanity_zones.setdefault(zone_hint, rel)

        base = rel[:-4]
        uvmask_rel = base + ".uvmask.png"
        seammask_rel = base + ".seammask.png"
        Image.fromarray(cover).save(out / uvmask_rel, "PNG")
        Image.fromarray(seam).save(out / seammask_rel, "PNG")
        map_rel = base + ".map.toml"
        semres.write_map_toml(out / map_rel, source_texture=Path(rel).name,
                              w=w, h=h, source_dat=sorted(info["srcs"])[0],
                              generated_at=generated_at, category=category,
                              subject_name=subject, subject_family=family,
                              zone_hint=zone_hint, lsb_family_id=fam_id,
                              lsb_commit=lsb.commit if category == "mob_skin" else "",
                              used_by_meshes=used_by_meshes,
                              referenced_by_scenes=scenes,
                              mesh_reference_count=len(good), regions=regions,
                              warnings=warns, orphan=orphan,
                              uvmask_file=uvmask_rel, seammask_file=seammask_rel)
        map_rows[rel] = (map_rel, len(regions), subject, family, confidence)
        if (len(map_rows) % 5000) == 0:
            print(f"  maps {len(map_rows)} ({time.time() - t0:.0f}s)", file=sys.stderr)

    # ---- INDEX.csv: append the five map columns ------------------------------
    rows = []
    with open(index, newline="", encoding="utf-8") as f:
        rd = csv.DictReader(f)
        for row in rd:
            rel = row["output_relpath"].replace("\\", "/")
            m = map_rows.get(rel)
            row.update({"map_file": m[0] if m else "",
                        "region_count": str(m[1]) if m else "",
                        "subject_name": m[2] if m else "",
                        "subject_family": m[3] if m else "",
                        "semantic_confidence": m[4] if m else ""})
            rows.append(row)
    with open(index, "w", newline="", encoding="utf-8") as f:
        wtr = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        wtr.writeheader()
        wtr.writerows(rows)

    # ---- layout.md ------------------------------------------------------------
    skipped = sorted(r for r in _non_map_pngs(out))
    _write_layout_md(out, pngs, map_rows, conf_hist, orphan_count, skipped,
                     stats, lsb.commit, warnings_log, sanity_mobs, sanity_zones)

    # ---- acceptance checks ------------------------------------------------------
    ok = True
    missing = [r for r in pngs if not (out / map_rows[r][0]).exists()]
    if missing:
        ok = False
        print(f"ACCEPT FAIL: {len(missing)} target PNGs without .map.toml, e.g. {missing[:5]}")
    missing_uv = [r for r in pngs if not (out / (r[:-4] + ".uvmask.png")).exists()]
    if missing_uv:
        ok = False
        print(f"ACCEPT FAIL: {len(missing_uv)} target PNGs without .uvmask.png, e.g. {missing_uv[:5]}")
    missing_seam = [r for r in pngs if not (out / (r[:-4] + ".seammask.png")).exists()]
    if missing_seam:
        ok = False
        print(f"ACCEPT FAIL: {len(missing_seam)} target PNGs without .seammask.png, e.g. {missing_seam[:5]}")
    zero_region = [r for r, m in map_rows.items() if m[1] == 0]
    if zero_region:
        ok = False
        print(f"ACCEPT FAIL: zero-region maps: {zero_region[:5]}")
    bad_parts = []
    for r, m in map_rows.items():
        if m[4] == "orphan_no_mesh_reference":
            continue
        txt = (out / m[0]).read_text(encoding="utf-8")
        if 'mesh_parts = []' in txt and "[[regions]]" in txt:
            bad_parts.append(r)
    if bad_parts:
        ok = False
        print(f"ACCEPT FAIL: non-orphan maps with empty mesh_parts: {bad_parts[:5]}")
    total = sum(conf_hist.values())
    orphan_ratio = orphan_count / total if total else 0
    if orphan_ratio > 0.25:
        ok = False
        print(f"ACCEPT FAIL: orphan ratio {orphan_ratio:.1%} > 25% (mesh walker broken?)")
    elif orphan_ratio > 0.10:
        print(f"ACCEPT WARN: orphan ratio {orphan_ratio:.1%} > 10%")

    print("\n" + "=" * 72)
    print(f"semantic_confidence histogram ({total} maps):")
    for k in sorted(conf_hist):
        print(f"  {k:32s} {conf_hist[k]:6d}  {conf_hist[k] / total:6.1%}")
    print("\n5 mob-texture sanity picks (subject_name / subject_family):")
    for (subject, family), rel in list(sanity_mobs.items())[:5]:
        print(f"  {subject:12s} / {family:12s}  {rel}")
    print("\n5 zone-texture sanity picks (zone_hint / category):")
    for zone, rel in list(sanity_zones.items())[:5]:
        print(f"  {zone:24s}  {rel}")
    print(f"\nLSB commit: {lsb.commit}")
    print(f"DONE in {time.time() - t0:.0f}s: {total} maps, "
          f"orphan {orphan_count} ({orphan_ratio:.1%})")
    print("ACCEPT PASS" if ok else "ACCEPT FAILED")
    sys.exit(0 if ok else 1)


def _non_map_pngs(out):
    """PNGs that intentionally have no map (minimaps) — for the layout log."""
    for d in (out / "extras" / "minimaps",):
        if d.exists():
            yield from (str(p.relative_to(out)).replace("\\", "/") for p in d.iterdir()
                        if p.suffix.lower() == ".png")


def _write_layout_md(out, pngs, map_rows, conf_hist, orphan_count, skipped_minimaps,
                     stats, lsb_commit, warnings_log, sanity_mobs, sanity_zones):
    total = sum(conf_hist.values())
    lines = [
        "# extracted/ layout & map pass",
        "",
        f"Map pass run {time.strftime('%Y-%m-%d %H:%M:%S')}. "
        f"LSB pinned at `{lsb_commit[:12]}` (General_Tools/vendor/lsb_commit.txt).",
        "",
        "## Buckets",
        "- backgrounds/ — ground + wall surface materials",
        "- foregrounds/ — prop textures",
        "- extras/environment/ — sky/water/effects layers",
        "- extras/minimaps/ — /map images (no maps: UI atlases, not mesh-referenced)",
        "- models/<src>/ — zone scenes, skel/d3m meshes",
        "",
        "## Atlas maps (.map.toml)",
        f"Every PNG in {', '.join(MAP_BUCKETS)} gets a sibling .map.toml: atlas "
        "regions auto-derived from mesh UVs (uv_island_analysis.py), technique "
        "from alpha + UV analysis, semantics from FFXI string tables + LSB "
        "(semantic_resolver.py). role/content_hint stay blank for Stage 2 authoring.",
        "",
        f"maps written: {total}  orphan (no mesh refs): {orphan_count} "
        f"({(orphan_count / total if total else 0):.1%})",
        "",
        "semantic_confidence:",
    ]
    for k in sorted(conf_hist):
        lines.append(f"- {k}: {conf_hist[k]}")
    lines += [
        "",
        f"skipped (no map, by design): {len(skipped_minimaps)} minimaps in "
        "extras/minimaps/",
        "",
        "## Walk stats",
        f"files walked: {stats['files']}  mmb parse fails: {stats['mmb_fails']}  "
        f"vos2 parse fails: {stats['vos2_fails']}",
        "",
        "## Warnings (truncated)",
    ]
    lines += [f"- {w}" for w in warnings_log[:200]]
    if len(warnings_log) > 200:
        lines.append(f"- … {len(warnings_log) - 200} more")
    (out / "layout.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", default=str(ROOT_DEFAULT))
    ap.add_argument("--out", default=str(OUT_DEFAULT))
    ap.add_argument("--only", default="", help="substring filter on relative path")
    ap.add_argument("--limit", type=int, default=0)
    ap.add_argument("--skip-models", action="store_true")
    ap.add_argument("--maps-only", action="store_true",
                    help="skip extraction; run the .map.toml atlas/semantic pass "
                         "over the existing dump")
    ap.add_argument("--source", default=None,
                    help="retail install root (VTABLE.DAT dir) for the map pass; "
                         "default: --root")
    ap.add_argument("--lsb", default=str(HERE.parent / "vendor" / "server"),
                    help="LandSandBoat/server checkout for mob semantics")
    ap.add_argument("--zones", default=str(HERE / "vendor" / "zones"),
                    help="live-server zones/ dir (mobs.yaml species labels)")
    ap.add_argument("--live-pools", default=str(HERE / "vendor" / "live_mob_pools.tsv"),
                    help="live-server mob_pools export (modelid TAB speciesid TAB name)")
    args = ap.parse_args()

    root = Path(args.root); out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    if args.maps_only:
        generate_maps(root, out, Path(args.source or args.root),
                      Path(args.lsb), Path(args.zones), Path(args.live_pools))
        return
    store = TexStore(out)
    mini = MiniMap()
    index_rows = []
    stats = {"files": 0, "textures": 0, "dupes": 0, "minimaps": 0,
             "scenes": 0, "skel_objs": 0, "d3m_objs": 0, "unparsed": 0,
             "chunk_kinds": {}, "sprite_sheets": 0}

    all_files = []
    for dirpath, _dirs, files in os.walk(root):
        for fn in sorted(files):
            if fn.lower().endswith(".dat"):
                p = Path(dirpath) / fn
                rel = str(p.relative_to(root)).replace("\\", "/")
                all_files.append((rel, p))
    all_files.sort()
    if args.only:
        all_files = [(r, p) for r, p in all_files if args.only.lower() in r.lower()]
    if args.limit:
        all_files = all_files[:args.limit]

    t0 = time.time()
    tex_rel_by_name = {}   # 'cat_name' -> relpath (for scene MTL map_Kd)
    for n, (rel, p) in enumerate(all_files):
        stats["files"] += 1
        sftok = sftoken_of(rel)
        try:
            buf = p.read_bytes()
        except OSError as e:
            print(f"  [err] read {rel}: {e}", file=sys.stderr); continue

        # 1) minimap?
        mm = mini.try_decode(buf)
        if mm:
            title = mm["title"] or sftok
            bdir = out / "extras" / "minimaps"
            base = f"{title}_512x512.png"
            target = bdir / base
            i = 2
            while target.exists():
                target = bdir / f"{title}_{sftok}_{i}_512x512.png"; i += 1
            target.parent.mkdir(parents=True, exist_ok=True)
            Image.frombytes("RGBA", (512, 512), mm["rgba"]).save(target, "PNG", optimize=True)
            stats["minimaps"] += 1
            index_rows.append([str(target.relative_to(out)), rel, "menumap", "", title, 512, 512])
            continue

        # 2) chunk container?
        chunks, walked = walk_chunks(buf)
        clean = walked == len(buf)
        kinds = [c["ctype"] for c in chunks]
        for k in kinds:
            stats["chunk_kinds"][k] = stats["chunk_kinds"].get(k, 0) + 1

        tex_here = False
        # textures (type 0x20) — works even on partial walks
        for c in chunks:
            if c["ctype"] != 0x20:
                continue
            r = parse_texture(buf[c["off"] + 16:c["off"] + c["length"]])
            if not r:
                continue
            tex_here = True
            name = r["name"] or f"unnamed_{c['off']:x}"
            cat = categorize(name, r.get("category", ""))
            relp, dup = store.put(cat, name, r["w"], r["h"], r["rgba"], sftok)
            stats["textures"] += 0 if dup else 1
            tex_rel_by_name.setdefault(f"{r['category']}_{name}", relp)
            index_rows.append([relp, rel, f"tex/{r['format']}", name, cat, r["w"], r["h"]])

        # scene + skel + d3m (only on clean containers to avoid half-walks)
        if not args.skip_models and chunks:
            has_scene = 0x1C in kinds or 0x2E in kinds
            has_skel  = 0x29 in kinds and 0x2A in kinds
            has_d3m   = 0x1F in kinds
            if has_scene:
                try:
                    s = export_zone_scene(buf, sftok, out, tex_rel_by_name)
                    if s:
                        stats["scenes"] += 1
                        index_rows.append([f"models/{sftok}/scene.obj", rel, "zone_scene", "",
                                           f"{s['matched']}/{s['placements']} placements",
                                           s["tris"], len(s)])
                except Exception as e:
                    print(f"  [err] scene {rel}: {e}", file=sys.stderr)
            if has_skel:
                try:
                    s = export_skinned(buf, sftok, out)
                    if s:
                        stats["skel_objs"] += s["objs"]
                        index_rows.append([f"models/{sftok}/(skel_*.obj)", rel, "vos2", "",
                                           f"{s['objs']} objs", s["verts"], s["tris"]])
                except Exception as e:
                    print(f"  [err] skel {rel}: {e}", file=sys.stderr)
            if has_d3m:
                try:
                    s = export_d3m(buf, sftok, out)
                    if s:
                        stats["d3m_objs"] += s["objs"]
                except Exception as e:
                    print(f"  [err] d3m {rel}: {e}", file=sys.stderr)

        if not tex_here and not chunks:
            stats["unparsed"] += 1
        if (n + 1) % 2000 == 0:
            el = time.time() - t0
            print(f"  [{n+1}/{len(all_files)}] {el:.0f}s tex={stats['textures']} "
                  f"mini={stats['minimaps']} scenes={stats['scenes']}", file=sys.stderr)

    # INDEX.csv
    idx = out / "INDEX.csv"
    with open(idx, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["output_relpath", "source_dat", "kind", "name", "category_or_note", "w", "h"])
        w.writerows(index_rows)

    # README
    (out / "README.md").write_text(f"""# extracted/ — full ROM asset dump

Generated by `tools/extract_dats.py` on {time.strftime('%Y-%m-%d')} from `{root}`.

## Buckets
- **backgrounds/** — ground + wall surface materials (ground, walls_stone/stucco/brick categories)
- **foregrounds/** — prop textures: building facades, wood, sheets/signage, details, foliage, misc
- **extras/environment/** — sky/moon/star/cloud sprites, water foam layers, effect glows
- **extras/minimaps/** — in-game /map images (512x512; A1 = shared standard palette, B1 = embedded)
- **models/<src>/scene.obj + scene.mtl** — composed zone scenes (MZB placements x MMB models,
  client authoring frame Y-down). MTL map_Kd paths resolve to the PNG buckets.
- **models/<src>/skel_*.obj / d3m_*.obj** — skinned bodies in bind pose + D3M effect meshes

Fine-grained categories (from POSITIONAL-TEXTURES) are recorded per-row in INDEX.csv column 5.

## Naming & dedupe
`<title>_<w>x<h>.png`. Same name+size with identical pixels = duplicate (skipped, one row keeps it).
Same name+size different content -> `<title>_<sftoken>_...` where sftoken = pack_table_file
(e.g. `rom_17_95`). Full provenance: INDEX.csv (output -> source .DAT + chunk kind + offset).

## Alpha convention (important for renderers)
DXT3 alpha is stored as 4-bit values expanded x16 ((n<<4)|n). SE authors "opaque" zone
materials with a 50/50 dither of nibbles 7/8 (=119/136, straddling 0.5) — that dither IS the
opacity convention for walls/floors (see docs note from texfmt BC1 work). Real transparency
lives in cutouts (moonshap, ura_02, ground_1 edges) and water (sea01/sea02 ~ 17/34).
Renderer rule: no alpha-test shimmer on the material pass — either ignore alpha for terrain or
match the retail blend state; do NOT threshold at exactly 0.5.

## Stats (this run)
files={stats['files']}  textures_written={store.written}  dupes_skipped={store.dupes}
minimaps={stats['minimaps']}  zone_scenes={stats['scenes']}  skel_objs={stats['skel_objs']}
d3m_objs={stats['d3m_objs']}  unparsed_files={stats['unparsed']}
""", encoding="utf-8")

    print(f"\nDONE in {time.time()-t0:.0f}s: files={stats['files']} textures={store.written} "
          f"(dupes {store.dupes}) minimaps={stats['minimaps']} scenes={stats['scenes']} "
          f"skel_objs={stats['skel_objs']} d3m={stats['d3m_objs']} unparsed={stats['unparsed']}",
          file=sys.stderr)


if __name__ == "__main__":
    main()

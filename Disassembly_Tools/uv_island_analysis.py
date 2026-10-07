"""UV island clustering + atlas region analysis for FFXI textures.

Input: triangle UV data collected from the MMB / VOS2 / D3M submeshes that
reference one texture. Output: atlas regions (pixel bbox, tiling, technique,
alpha pattern, mesh parts). Semantics are NOT derived here — see
semantic_resolver.py.

UV convention: v=0 is the top row of the stored image (the DXT3/8bpp streams
are top-first in this client's texture pipeline, see
research/cexi-docs/dats/ROM_165_84.md sibling docs and the texdat/ work).
"""
import numpy as np

# Edge-matching grid. float32 authoring drift between triangles that share a
# UV vertex is far below 1/4096 of a texture, so rounding to this grid makes
# shared-vertex detection epsilon-based without exact-equality failures.
UV_QUANT_SCALE = 4096

# A UV span wider than 1 + this means the island samples the texture more
# than once along that axis (wrapping / tiling).
UV_WRAP_EPS = 1e-3

# FFXI "opaque" materials are authored as a 50/50 dither of alpha nibbles
# 7/8 -> 119/136 (extracted/README.md alpha note). A region that is
# predominantly this dither is dithered_opaque, not a cutout.
ALPHA_DITHER_LO = 119
ALPHA_DITHER_HI = 136
ALPHA_CUTOUT_LOW = 32
ALPHA_CUTOUT_HIGH = 224


def quantize_uv(uv):
    """uv: (N,2) float -> (N,2) int64 grid coords.

    Non-finite corners (NaN, or finite values that overflow the scale) are
    mapped to the origin; zero-span islands are dropped by build_regions."""
    q = np.nan_to_num(np.round(uv * UV_QUANT_SCALE),
                      nan=0.0, posinf=0.0, neginf=0.0)
    # clip before the cast: a finite out-of-range UV (e.g. 1e30) would
    # otherwise overflow int64 and raise a RuntimeWarning on the cast
    q = np.clip(q, np.iinfo(np.int64).min, np.iinfo(np.int64).max)
    return q.astype(np.int64)


def cluster_uv_islands(tri_uv):
    """Cluster triangles into connected UV islands.

    tri_uv: (T,3,2) array of per-corner UVs.
    Returns a list of dicts:
      tris   int64 array of triangle indices in this island
      uv_min (2,) float, uv_max (2,) float over the island's corners
    Triangles that share a UV-space edge (both endpoints on the quantized
    grid) belong to the same island.
    """
    tri_uv = np.ascontiguousarray(tri_uv, dtype=np.float64)
    # some meshes carry NaN/inf UV corners (untextured/degenerate); map them
    # to (0,0) so they quantize cleanly. Zero-span islands are dropped by
    # build_regions.
    tri_uv = np.nan_to_num(tri_uv, nan=0.0, posinf=0.0, neginf=0.0)
    t = tri_uv.shape[0]
    if t == 0:
        return []

    q = quantize_uv(tri_uv.reshape(-1, 2))
    # 3 edges per triangle; each edge key = the two endpoint grid cells,
    # ordered so (lo,hi) is canonical.
    edge_dtype = np.dtype([("a", "<i8"), ("b", "<i8"), ("c", "<i8"), ("d", "<i8")])
    edge_keys = np.empty(3 * t, dtype=edge_dtype)
    tri_of_edge = np.empty(3 * t, dtype=np.int64)
    for e, (i0, i1) in enumerate(((0, 1), (1, 2), (2, 0))):
        p0 = q[i0::3]
        p1 = q[i1::3]
        # lexicographic endpoint order (component-wise min/max would let two
        # different edges share one key)
        swap = (p1[:, 0] < p0[:, 0]) | ((p1[:, 0] == p0[:, 0]) & (p1[:, 1] < p0[:, 1]))
        lo = np.where(swap[:, None], p1, p0)
        hi = np.where(swap[:, None], p0, p1)
        seg = slice(e * t, (e + 1) * t)
        edge_keys[seg]["a"] = lo[:, 0]
        edge_keys[seg]["b"] = lo[:, 1]
        edge_keys[seg]["c"] = hi[:, 0]
        edge_keys[seg]["d"] = hi[:, 1]
        tri_of_edge[seg] = np.arange(t)

    order = np.argsort(edge_keys, kind="stable")
    keys_sorted = edge_keys[order]
    tri_sorted = tri_of_edge[order]

    # group runs of identical edge keys
    change = np.empty(len(keys_sorted), dtype=bool)
    change[0] = True
    change[1:] = keys_sorted[1:] != keys_sorted[:-1]
    starts = np.flatnonzero(change)

    parent = np.arange(t)

    def find(x):
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x

    def union(a, b):
        ra, rb = find(a), find(b)
        if ra != rb:
            if ra > rb:
                ra, rb = rb, ra
            parent[rb] = ra

    ends = np.append(starts[1:], len(keys_sorted))
    for s, e in zip(starts, ends):
        tris = tri_sorted[s:e]
        first = int(tris[0])
        for k in range(1, len(tris)):
            union(first, int(tris[k]))

    roots = np.array([find(i) for i in range(t)], dtype=np.int64)
    _, inv = np.unique(roots, return_inverse=True)
    order = np.argsort(inv, kind="stable")
    bounds = np.flatnonzero(np.diff(inv[order])) + 1
    uv_flat = tri_uv.reshape(-1, 2)
    islands = []
    for tris in np.split(order, bounds):
        uv = uv_flat[tris[:, None] * 3 + np.arange(3)].reshape(-1, 2)
        islands.append({
            "tris": tris,
            "uv_min": uv.min(axis=0),
            "uv_max": uv.max(axis=0),
        })
    return islands


def island_tiling(uv_min, uv_max, wrap_axes=None):
    """'none' / 'u_axis' / 'v_axis' / 'both_axes' for one island.

    An island wraps in an axis when its UV span exceeds 1, OR when it is
    closed across the wrap: span >= 1 - eps, corners sit on two adjacent
    integer lines of the axis, and no boundary edge lies on those lines
    (the mesh wraps around them, e.g. zone terrain whose coarse UV grid
    tiles the texture exactly once). A plain rectangular patch spanning
    the image once has boundary edges on both lines and does not wrap.
    wrap_axes: optional (n_islands,2) bool array from uv_raster.
    """
    u0, v0 = uv_min
    u1, v1 = uv_max
    wrap_u = (u1 - u0 > 1 + UV_WRAP_EPS) or (u0 < -UV_WRAP_EPS) or (u1 > 1 + UV_WRAP_EPS)
    wrap_v = (v1 - v0 > 1 + UV_WRAP_EPS) or (v0 < -UV_WRAP_EPS) or (v1 > 1 + UV_WRAP_EPS)
    if wrap_axes is not None:
        wrap_u = wrap_u or bool(wrap_axes[0])
        wrap_v = wrap_v or bool(wrap_axes[1])
    if wrap_u and wrap_v:
        return "both_axes"
    if wrap_u:
        return "u_axis"
    if wrap_v:
        return "v_axis"
    return "none"


def island_bbox(uv_min, uv_max, w, h):
    """Pixel bbox [x0, y0, x1, y1] (inclusive-ish, clamped to the image).
    Tiling islands span the whole image."""
    u0, v0 = uv_min
    u1, v1 = uv_max
    x0 = max(0, min(int(round(u0 * w)), w))
    x1 = max(0, min(int(round(u1 * w)), w))
    y0 = max(0, min(int(round(v0 * h)), h))
    y1 = max(0, min(int(round(v1 * h)), h))
    if x1 <= x0:
        x1 = min(x0 + 1, w)
    if y1 <= y0:
        y1 = min(y0 + 1, h)
    return [x0, y0, x1, y1]


def analyze_alpha(rgba, w, h, bbox):
    """Classify the alpha channel inside a region.

    rgba: (w*h,4) bytes. Returns (alpha_pattern, stats dict).
    alpha_pattern: 'opaque' | 'cutout' | 'dithered' | 'mixed' | 'unknown'
    """
    x0, y0, x1, y1 = bbox
    crop = np.frombuffer(rgba, dtype=np.uint8).reshape(h, w, 4)[y0:y1, x0:x1, 3]
    n = crop.size
    if n == 0:
        return "unknown", {}
    near_zero = float((crop <= ALPHA_CUTOUT_LOW).mean())
    near_full = float((crop >= ALPHA_CUTOUT_HIGH).mean())
    dither = float(((crop == ALPHA_DITHER_LO) | (crop == ALPHA_DITHER_HI)).mean())
    mid = 1.0 - near_zero - near_full
    stats = {"near_zero": near_zero, "near_full": near_full,
             "dither": dither, "mid": mid}
    # predominantly the 7/8-nibble dither -> FFXI opaque convention
    if dither > 0.5:
        return "dithered", stats
    # sharp bimodal alpha -> cutout sprite
    if near_zero + near_full > 0.5 and near_zero > 0.02:
        return "cutout", stats
    if near_full > 0.9:
        return "opaque", stats
    if near_zero + near_full > 0.75:
        return "cutout", stats
    if mid > 0.5:
        return "mixed", stats
    return "unknown", stats


def classify_technique(tiling, alpha_pattern):
    """Combine UV tiling + alpha pattern into a region technique.
    Tiling wins: a wrapping region must regenerate as a tileable/wrapped
    material regardless of the alpha convention (the 7/8 dither is how this
    client marks opaque, not a separate technique)."""
    if tiling == "both_axes" and alpha_pattern in ("opaque", "dithered"):
        return "seamless_tile"
    if tiling in ("u_axis", "v_axis") and alpha_pattern in ("opaque", "dithered"):
        return "wrapped_material"
    if alpha_pattern == "cutout":
        return "alpha_cutout_sprite"
    if alpha_pattern == "dithered":
        return "dithered_opaque"
    if tiling == "none" and alpha_pattern == "opaque":
        return "flat_opaque"
    return "unknown"


def build_regions(w, h, tri_uv, rgba, mesh_parts_by_tri=None, min_area=1,
                  wrap_closure=None):
    """Full per-texture region analysis.

    tri_uv: (T,3,2) UVs of every triangle referencing the texture.
    rgba: (w*h,4) decoded pixels (None -> alpha analysis skipped, patterns
           fall back to 'unknown').
    mesh_parts_by_tri: optional (T,) array of '<mesh>.submesh_<n>' labels;
           merged into each region's mesh_parts list.
    wrap_closure: optional (n_islands,2) bool array from
           uv_raster.island_wrap_closure, aligned with island enumeration
           order; when given, an island closed across the wrap reports
           tiling in that axis instead of 'none'.
    Returns a list of region dicts (schema fields used by the map writer).
    """
    islands = cluster_uv_islands(tri_uv)
    if not islands:
        return []
    regions = []
    for ii, isl in enumerate(islands):
        span = isl["uv_max"] - isl["uv_min"]
        if span[0] <= 0.0 and span[1] <= 0.0:
            continue                    # all corners at one UV: unplaceable
        wc = wrap_closure[ii] if wrap_closure is not None else None
        tiling = island_tiling(isl["uv_min"], isl["uv_max"], wrap_axes=wc)
        if tiling != "none":
            bbox = [0, 0, w, h]
        else:
            bbox = island_bbox(isl["uv_min"], isl["uv_max"], w, h)
        if (bbox[2] - bbox[0]) * (bbox[3] - bbox[1]) < min_area:
            continue
        if rgba is not None:
            alpha_pattern, _stats = analyze_alpha(rgba, w, h, bbox)
        else:
            alpha_pattern = "unknown"
        technique = classify_technique(tiling, alpha_pattern)
        if mesh_parts_by_tri is not None:
            parts = sorted(set(mesh_parts_by_tri[isl["tris"]]))
        else:
            parts = []
        regions.append({
            "bbox": bbox,
            "uv_island_triangle_count": int(len(isl["tris"])),
            "technique": technique,
            "tiling": tiling,
            "alpha_pattern": alpha_pattern,
            "mesh_parts": parts,
            "_uv_min": isl["uv_min"],
            "_uv_max": isl["uv_max"],
        })
    regions.sort(key=lambda r: (r["bbox"][1], r["bbox"][0], r["bbox"][3], r["bbox"][2]))
    for i, r in enumerate(regions):
        r["id"] = f"region_{i}"
    return regions


# ---------------------------------------------------------------------------
# synthetic unit tests (run: python uv_island_analysis.py)
# ---------------------------------------------------------------------------
def _selftest():
    # two disjoint islands
    tri_uv = np.array([
        [(0.0, 0.0), (0.5, 0.0), (0.0, 0.5)],
        [(0.5, 0.0), (0.5, 0.5), (0.0, 0.5)],
        [(0.6, 0.6), (0.9, 0.6), (0.6, 0.9)],
    ], dtype=np.float32)
    islands = cluster_uv_islands(tri_uv)
    assert len(islands) == 2, islands
    sizes = sorted(len(i["tris"]) for i in islands)
    assert sizes == [1, 2], sizes

    # float32 drift on a shared edge corner (1e-5) must still merge: the
    # quantized grid absorbs authoring precision drift
    tri_uv2 = np.array([
        [(0.0, 0.0), (0.5, 0.0), (0.0, 0.5)],
        [(0.5, 0.0), (0.5, 0.5), (0.0 + 1e-5, 0.5)],
    ], dtype=np.float32)
    islands = cluster_uv_islands(tri_uv2)
    assert len(islands) == 1, islands      # shared edge (0.5,0)-(0,0.5)

    # drift large enough to land on a different grid cell must NOT merge
    tri_uv3 = np.array([
        [(0.0, 0.0), (0.5, 0.0), (0.0, 0.5)],
        [(0.5, 0.0), (0.5, 0.5), (0.0 + 0.0002, 0.5)],
    ], dtype=np.float32)
    islands = cluster_uv_islands(tri_uv3)
    assert len(islands) == 2, islands

    # tiling detection
    assert island_tiling(np.array([0.0, 0.0]), np.array([2.0, 1.5])) == "both_axes"
    assert island_tiling(np.array([0.0, 0.0]), np.array([1.5, 0.9])) == "u_axis"
    assert island_tiling(np.array([0.0, 0.0]), np.array([0.9, 1.2])) == "v_axis"
    assert island_tiling(np.array([0.1, 0.1]), np.array([0.9, 0.9])) == "none"
    # straddling the 0 edge counts as wrap even when span <= 1
    assert island_tiling(np.array([-0.1, 0.0]), np.array([0.9, 1.0])) == "u_axis"

    # bbox
    assert island_bbox(np.array([0.0, 0.0]), np.array([0.5, 1.0]), 256, 128) == [0, 0, 128, 128]
    # wrapping UVs clamp to the image (build_regions replaces the bbox with
    # the full image for tiling islands)
    assert island_bbox(np.array([0.5, 0.25]), np.array([1.5, 0.75]), 256, 128) == [128, 32, 256, 96]

    # alpha: dithered opaque
    w, h = 8, 8
    rgba = bytearray(w * h * 4)
    for i in range(w * h):
        rgba[i * 4: i * 4 + 3] = b"\x80\x80\x80"
        rgba[i * 4 + 3] = ALPHA_DITHER_LO if i % 2 == 0 else ALPHA_DITHER_HI
    pat, _ = analyze_alpha(bytes(rgba), w, h, [0, 0, w, h])
    assert pat == "dithered", pat
    assert classify_technique("both_axes", pat) == "seamless_tile"

    # alpha: cutout sprite (half transparent, half opaque)
    rgba = bytearray(w * h * 4)
    for i in range(w * h):
        rgba[i * 4: i * 4 + 3] = b"\x80\x80\x80"
        rgba[i * 4 + 3] = 255 if i < w * h // 2 else 0
    pat, _ = analyze_alpha(bytes(rgba), w, h, [0, 0, w, h])
    assert pat == "cutout", pat
    assert classify_technique("none", pat) == "alpha_cutout_sprite"

    # alpha: fully opaque
    rgba = bytes(b"\x80" * (w * h * 3) + b"\xff") * 1
    rgba = bytearray()
    for i in range(w * h):
        rgba += b"\x80\x80\x80\xff"
    pat, _ = analyze_alpha(bytes(rgba), w, h, [0, 0, w, h])
    assert pat == "opaque", pat
    assert classify_technique("none", pat) == "flat_opaque"

    # NaN UV corners must not break quantization
    tri_uv4 = np.array([
        [(0.0, 0.0), (0.5, 0.0), (0.0, 0.5)],
        [(float('nan'), 0.6), (0.9, 0.6), (0.6, 0.9)],
    ], dtype=np.float32)
    islands = cluster_uv_islands(tri_uv4)
    assert len(islands) == 2, islands
    # zero-span island (all corners at one UV) is dropped by build_regions
    tri_uv5 = np.array([
        [(0.0, 0.0), (0.0, 0.0), (0.0, 0.0)],
        [(0.1, 0.1), (0.4, 0.1), (0.1, 0.4)],
    ], dtype=np.float32)
    regions = build_regions(256, 256, tri_uv5, None)
    assert len(regions) == 1, regions

    # end-to-end: two regions, stable ids by bbox top-left
    tri_uv = np.array([
        [(0.0, 0.0), (0.5, 0.0), (0.0, 0.5)],
        [(0.5, 0.0), (0.5, 0.5), (0.0, 0.5)],
        [(0.5, 0.5), (1.0, 0.5), (0.5, 1.0)],
    ], dtype=np.float32)
    labels = np.array(["m.submesh_0", "m.submesh_0", "m.submesh_1"])
    regions = build_regions(256, 256, tri_uv, None, mesh_parts_by_tri=labels)
    assert len(regions) == 2, regions
    assert regions[0]["id"] == "region_0"
    assert regions[0]["bbox"] == [0, 0, 128, 128]
    assert regions[0]["mesh_parts"] == ["m.submesh_0"]
    assert regions[1]["bbox"] == [128, 128, 256, 256]
    assert regions[1]["mesh_parts"] == ["m.submesh_1"]
    assert regions[0]["technique"] == "unknown"      # no pixels -> unknown
    print("uv_island_analysis self-test: OK")


if __name__ == "__main__":
    _selftest()

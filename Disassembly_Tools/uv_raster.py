"""UV coverage + seam mask rasterization for the map pass.

For one texture (w x h) and the combined triangle UVs of every mesh that
references it, rasterize at source resolution:

  uvmask   (L, 255/0):  pixel is sampled by at least one UV triangle.
  seammask (L, 4-class):
      0 = unused (no UV coverage)
      1 = covered interior (not on a UV-mesh boundary edge)
      2 = covered UV boundary (island outline edge)
      3 = seam boundary: the island outline edge lies on an integer UV
         line in an axis where the island wraps, and another boundary
         chain of the same island on a different integer line carries an
         identical free-coordinate multiset (the physical wrap seam: a
         cylinder's cut column, or an effect strip whose two ends sample
         the same texture line). A terrain tile spanning the image once
         has different outlines on the two sides and is NOT a seam.

Tiling UVs (span > 1, or negative) are folded mod 1 before rasterizing:
triangles are split at the integer UV lines they cross and each piece is
shifted into [0,1), exactly where the sampler wraps.

Rasterization is pixel-center based (a pixel is covered when its center
falls in a triangle). Fills and lines are PIL ImageDraw (C scanline),
~50x faster than a numpy per-triangle loop at these sizes.
"""
import numpy as np
from PIL import Image, ImageDraw

# UV_QUANT_SCALE must match uv_island_analysis (shared 4096 grid).
UV_QUANT_SCALE = 4096

# island span within this of a full 1.0 counts as wrapping
WRAP_EPS = 1e-3

# seam-chain free-coordinate tolerance, in quantized grid cells
SEAM_TOL = 2


def build_edge_data(tri_uv):
    """tri_uv (T,3,2) float -> dict with:
      edges_f    (U,2,2) float, unique undirected edge geometry (UV space)
      interior   (U,) bool, edge used by >=2 triangles of one island
      edge_isl   (U,) int64, island of one owning triangle
      islands    uia.cluster_uv_islands result
      isl_span   (n_islands,2) UV span per island
    """
    import uv_island_analysis as uia
    t = tri_uv.shape[0]
    if t == 0:
        return {"edges_f": np.zeros((0, 2, 2)), "interior": np.zeros(0, bool),
                "edge_isl": np.zeros(0, dtype=np.int64), "islands": [],
                "isl_span": np.zeros((0, 2))}
    islands = uia.cluster_uv_islands(tri_uv)
    isl_span = np.array([[i["uv_max"][0] - i["uv_min"][0],
                          i["uv_max"][1] - i["uv_min"][1]] for i in islands])
    lab = np.full(t, -1, dtype=np.int64)
    for ii, isl in enumerate(islands):
        lab[isl["tris"]] = ii

    q = uia.quantize_uv(tri_uv.reshape(-1, 2))
    ek, to, third = _all_edge_records(q)
    if len(ek) == 0:
        return {"edges_f": np.zeros((0, 2, 2)), "interior": np.zeros(0, bool),
                "edge_isl": np.zeros(0, dtype=np.int64), "islands": islands,
                "isl_span": isl_span}
    uniq, inv = np.unique(ek, axis=0, return_inverse=True)
    edge_isl = lab[to]
    # interior = owning triangles exist on BOTH 2D sides of the edge. A UV
    # perimeter edge shared by 64 same-side triangles (zone terrain's coarse
    # UV grid) is a coverage boundary, not interior. The side test is the
    # edge direction x (third vertex - lo) cross product per owning edge
    # record; collinear (zero-area) corners count as neither side.
    lo_x = ek["a"]; lo_y = ek["b"]
    hi_x = ek["c"]; hi_y = ek["d"]
    dx = hi_x - lo_x; dy = hi_y - lo_y
    cross = dx * (third[:, 1] - lo_y) - dy * (third[:, 0] - lo_x)
    pos = np.zeros(len(uniq), bool); neg = np.zeros(len(uniq), bool)
    np.logical_or.at(pos, inv, cross > 0)
    np.logical_or.at(neg, inv, cross < 0)
    interior = pos & neg
    first_tri = np.full(len(uniq), -1, dtype=np.int64)
    np.maximum.at(first_tri, inv, to)          # any owning triangle will do
    edge_isl_u = np.where(first_tri >= 0, lab[np.clip(first_tri, 0, None)], -1)
    edges_f = uniq.view(np.int64).reshape(len(uniq), 2, 2).astype(np.float64) \
        / UV_QUANT_SCALE
    return {"edges_f": edges_f, "interior": interior, "edge_isl": edge_isl_u,
            "islands": islands, "isl_span": isl_span}


def _all_edge_records(q):
    """q (3t,2) int64 -> (edge_keys (E,), tri_of_edge (E,), third (E,2))
    undirected, degenerate (zero-length) edges dropped. `third` is the
    quantized coordinate of the owning triangle's vertex OPPOSITE the edge
    (the build_edge_data side test must use it — indexing the triangle
    vertex array directly desynchronizes once degenerate edges are
    filtered)."""
    t = len(q) // 3
    dt = np.dtype([("a", "<i8"), ("b", "<i8"), ("c", "<i8"), ("d", "<i8")])
    ek = np.empty(3 * t, dtype=dt)
    to = np.empty(3 * t, dtype=np.int64)
    third = np.empty((3 * t, 2), dtype=np.int64)
    for e, (i0, i1, i2) in enumerate(((0, 1, 2), (1, 2, 0), (2, 0, 1))):
        p0 = q[i0::3]; p1 = q[i1::3]; p2 = q[i2::3]
        swap = (p1[:, 0] < p0[:, 0]) | ((p1[:, 0] == p0[:, 0]) & (p1[:, 1] < p0[:, 1]))
        lo = np.where(swap[:, None], p1, p0)
        hi = np.where(swap[:, None], p0, p1)
        seg = slice(e * t, (e + 1) * t)
        ek[seg]["a"] = lo[:, 0]; ek[seg]["b"] = lo[:, 1]
        ek[seg]["c"] = hi[:, 0]; ek[seg]["d"] = hi[:, 1]
        to[seg] = np.arange(t)
        third[seg] = p2
    keep = (ek["a"] != ek["c"]) | (ek["b"] != ek["d"])
    return ek[keep], to[keep], third[keep]


def island_wrap_closure(data, tri_uv):
    """(n_islands,2) bool: island is closed across the wrap in that axis.

    Closed across the wrap = the island's span in the axis is >= 1 - eps,
    its corners sit on two integer lines at least 1 apart, and no
    boundary edge of the island lies on any integer line between them
    (the mesh wraps around those lines: zone terrain whose coarse UV grid
    tiles the texture exactly once). A cylinder or effect strip has
    boundary chains on the wrap lines -> not closed (the chain test in
    find_seam_edges marks those as seams instead).
    """
    n = len(data["islands"])
    out = np.zeros((n, 2), bool)
    if n == 0 or len(data["edges_f"]) == 0:
        return out
    import uv_island_analysis as uia
    wrap = data["isl_span"] >= (1.0 - WRAP_EPS)
    q_edges = (data["edges_f"] * UV_QUANT_SCALE).round().astype(np.int64)
    interior = data["interior"]
    edge_isl = data["edge_isl"]
    q_corners = uia.quantize_uv(tri_uv.reshape(-1, 2))
    p0 = q_edges[:, 0]; p1 = q_edges[:, 1]
    # per axis: boundary edges sitting on integer lines, grouped by island
    # (vectorized once; the old version re-scanned every edge in Python
    # for each island)
    isl_lines = [[], []]
    for ax in range(2):
        a = p0[:, ax]; b = p1[:, ax]
        on_int = (a == b) & (a % UV_QUANT_SCALE == 0)
        line = np.where(on_int, a // UV_QUANT_SCALE, -1)
        m = (~interior) & on_int & (edge_isl >= 0)
        si = edge_isl[m]; sl = line[m]
        order = np.argsort(si, kind="stable")
        isl_lines[ax] = [si[order], sl[order]]
    for ii in range(n):
        for ax in range(2):
            if not wrap[ii, ax]:
                continue
            tris = data["islands"][ii]["tris"]
            cvals = q_corners[tris[:, None] * 3 + np.arange(3), ax]
            on = cvals % UV_QUANT_SCALE == 0
            # distinct integer lines only: a vertex shared by 6 triangles
            # would otherwise appear 6x and blow up the pair loop below
            lines = sorted(set((cvals[on] // UV_QUANT_SCALE).tolist()))
            if len(lines) < 2:
                continue
            si, sl = isl_lines[ax]
            j0 = int(np.searchsorted(si, ii, side="left"))
            blines = set(sl[j0:int(np.searchsorted(si, ii, side="right"))].tolist())
            for i, f in enumerate(lines):
                for g in lines[i + 1:]:
                    if g - f < 1:
                        continue
                    if any(f <= b <= g for b in blines):
                        continue
                    out[ii, ax] = True
                    break
                if out[ii, ax]:
                    break
    return out


def find_seam_edges(data, w, h):
    """-> set of unique-edge indices that are wrap seams (class 3).

    A boundary edge on integer line f of axis ax is a seam when its island
    wraps in ax and another boundary chain of the same island lies on a
    different integer line g of the same axis with an identical free-
    coordinate multiset (within SEAM_TOL grid cells). All integer lines
    are the same physical texture line (mod 1): an effect strip whose ends
    at v=0 and v=2 sample the same texture line qualifies. A terrain tile
    spanning the image once has different outlines on the two sides and
    does not. A FULL-IMAGE rectangle (bbox [0,1]x[0,1]) is excluded: its
    four image edges are the texture frame, and the two chains on each axis
    pair are distinct physical lines (a sprite's left/right or a terrain
    patch's top/bottom), not a glued cut column. FFXI cylinder/prop cut
    columns live inside atlas sub-islands at fractional texture positions,
    so this exclusion does not drop real wrap seams.
    """
    edges_f = data["edges_f"]
    interior = data["interior"]
    edge_isl = data["edge_isl"]
    isl_span = data["isl_span"]
    U = len(edges_f)
    if U == 0:
        return set()
    isl_min = np.array([i["uv_min"] for i in data["islands"]])
    isl_max = np.array([i["uv_max"] for i in data["islands"]])
    full_rect = ((np.abs(isl_min[:, 0]) < WRAP_EPS)
                 & (np.abs(isl_min[:, 1]) < WRAP_EPS)
                 & (np.abs(isl_max[:, 0] - 1.0) < WRAP_EPS)
                 & (np.abs(isl_max[:, 1] - 1.0) < WRAP_EPS))
    q = (edges_f * UV_QUANT_SCALE).round().astype(np.int64)   # (U,2,2)
    p0 = q[:, 0]; p1 = q[:, 1]
    wrap = isl_span >= (1.0 - WRAP_EPS)
    boundary = ~interior
    chains = {}
    for k in range(U):
        if not boundary[k] or edge_isl[k] < 0:
            continue
        ii = int(edge_isl[k])
        if full_rect[ii]:
            continue
        for ax in (0, 1):
            if not wrap[ii, ax]:
                continue
            a = p0[k, ax]; b = p1[k, ax]
            if a != b:
                continue                          # not parallel to the line
            f = int(a // UV_QUANT_SCALE)
            if a != f * UV_QUANT_SCALE:
                continue                          # not an integer line
            chains.setdefault((ii, ax, f), []).append(k)
    seam = set()
    free = lambda k, ax: sorted((int(p0[k, 1 - ax]), int(p1[k, 1 - ax])))
    by_isl_ax = {}
    for (ii, ax, f), ks in chains.items():
        by_isl_ax.setdefault((ii, ax), {})[f] = ks
    for (ii, ax), lines in by_isl_ax.items():
        fs = sorted(lines)
        sigs = {f: np.array([v for k in lines[f] for v in free(k, ax)],
                             dtype=np.int64) for f in fs}
        for i in range(len(fs)):
            for j in range(i + 1, len(fs)):
                f, g = fs[i], fs[j]
                a, b = sigs[f], sigs[g]
                if len(a) != len(b):
                    continue
                a.sort(); b.sort()
                if np.abs(a - b).max() <= SEAM_TOL:
                    seam.update(lines[f])
                    seam.update(lines[g])
    return seam


def _clip_half(poly, ax, c, keep_le):
    """Sutherland-Hodgman: keep the part of a convex polygon on one side
    of the line poly[:, ax] = c. -> (M,2) or None when empty."""
    out = []
    n = len(poly)
    for i in range(n):
        a = poly[i]; b = poly[(i + 1) % n]
        ain = a[ax] <= c if keep_le else a[ax] >= c
        bin_ = b[ax] <= c if keep_le else b[ax] >= c
        if ain:
            out.append(a)
        if ain != bin_:
            t = (c - a[ax]) / (b[ax] - a[ax])
            out.append(a + t * (b - a))
    if not out:
        return None
    arr = np.asarray(out)
    # drop consecutive duplicates (vertices exactly on the line)
    keep = np.ones(len(arr), bool)
    keep[1:] = np.any(arr[1:] != arr[:-1], axis=1)
    return arr[keep]


def _fold_triangles(tri_uv):
    """(T,3,2) -> (K,3,2): split each triangle at the integer UV lines it
    crosses and shift each piece into [0,1), where the sampler wraps.
    Triangles already inside [0,1) pass through untouched."""
    t = tri_uv.shape[0]
    if t == 0:
        return np.zeros((0, 3, 2))
    u0 = tri_uv[:, :, 0].min(1); u1 = tri_uv[:, :, 0].max(1)
    v0 = tri_uv[:, :, 1].min(1); v1 = tri_uv[:, :, 1].max(1)
    need = ((np.floor(u0) != np.floor(u1)) | (np.floor(v0) != np.floor(v1))
            | (u0 < 0) | (v0 < 0) | (u1 > 1) | (v1 > 1))
    out = [tri_uv[k] for k in np.flatnonzero(~need)]
    for k in np.flatnonzero(need):
        tri = tri_uv[k]
        polys = [tri]
        lines = [(0, float(u)) for u in range(int(np.floor(u0[k])),
                                              int(np.floor(u1[k])) + 1)
                 if u0[k] < u < u1[k]]
        lines += [(1, float(v)) for v in range(int(np.floor(v0[k])),
                                               int(np.floor(v1[k])) + 1)
                  if v0[k] < v < v1[k]]
        for ax, c in lines:
            new = []
            for p in polys:
                for keep in (True, False):
                    cp = _clip_half(p, ax, c, keep)
                    if cp is not None and len(cp) >= 3:
                        new.append(cp)
            polys = new
            if not polys:
                break
        for p in polys:
            p = p - np.floor(p.min(axis=0))
            if len(p) == 3:
                out.append(p)
            else:
                for i in range(1, len(p) - 1):
                    out.append(np.array([p[0], p[i], p[i + 1]]))
    if not out:
        return np.zeros((0, 3, 2))
    return np.ascontiguousarray(np.array(out), dtype=np.float64)


def _wrap_segment(p0, p1, w, h):
    """Pixel-space segments for one UV edge: split at integer UV lines,
    shift each piece into [0,1) (the sampler's wrap), then to pixels."""
    def seg(a, b):
        # cell base from the min endpoint: an endpoint exactly on the upper
        # integer line stays at the far image edge, not folded to 0
        ku = int(np.floor(min(a[0], b[0])))
        kv = int(np.floor(min(a[1], b[1])))
        au = a[0] - ku; bu = b[0] - ku
        av = a[1] - kv; bv = b[1] - kv
        x0 = int(np.clip(round(au * w), 0, w - 1))
        y0 = int(np.clip(round(av * h), 0, h - 1))
        x1 = int(np.clip(round(bu * w), 0, w - 1))
        y1 = int(np.clip(round(bv * h), 0, h - 1))
        return [(x0, y0, x1, y1)] if (x0 != x1 or y0 != y1) else []
    out = []
    lo_u, hi_u = sorted((p0[0], p1[0]))
    lo_v, hi_v = sorted((p0[1], p1[1]))
    us = [u for u in range(int(np.floor(lo_u)), int(np.floor(hi_u)) + 1)
          if lo_u < u < hi_u]
    vs = [v for v in range(int(np.floor(lo_v)), int(np.floor(hi_v)) + 1)
          if lo_v < v < hi_v]
    pts = [p0]
    for u in us:
        f = (u - p0[0]) / (p1[0] - p0[0])
        pts.append((u, p0[1] + f * (p1[1] - p0[1])))
    for v in vs:
        f = (v - p0[1]) / (p1[1] - p0[1])
        pts.append((p0[0] + f * (p1[0] - p0[0]), v))
    pts.append(p1)
    axis = 0 if abs(p1[0] - p0[0]) >= abs(p1[1] - p0[1]) else 1
    pts = [pts[0]] + sorted(pts[1:-1], key=lambda p: p[axis]) + [pts[-1]]
    for a, b in zip(pts, pts[1:]):
        out.extend(seg(a, b))
    return out


def rasterize_masks_from_data(tri_uv, w, h, data):
    """-> (uvmask, seammask) as (h, w) uint8 arrays, using prebuilt data."""
    seam = Image.new("L", (w, h), 0)
    dr_s = ImageDraw.Draw(seam)
    seams = find_seam_edges(data, w, h)
    edges_f = data["edges_f"]
    interior = data["interior"]

    folded = _fold_triangles(tri_uv)
    uv_px = folded * (w, h)
    for k in range(uv_px.shape[0]):
        dr_s.polygon(uv_px[k].tolist(), fill=1)
    for k in range(len(edges_f)):
        if interior[k]:
            continue
        segs = _wrap_segment(edges_f[k, 0], edges_f[k, 1], w, h)
        val = 3 if k in seams else 2
        for (x0, y0, x1, y1) in segs:
            dr_s.line([(x0, y0), (x1, y1)], fill=val)
    seam_arr = np.asarray(seam)
    cover = np.where(seam_arr >= 1, 255, 0).astype(np.uint8)
    return cover, seam_arr


def rasterize_masks(tri_uv, w, h):
    """-> (uvmask, seammask) as (h, w) uint8 arrays.

    uvmask: 255 where covered.
    seammask: 0 unused / 1 interior / 2 boundary / 3 seam.
    """
    tri_uv = np.ascontiguousarray(tri_uv, dtype=np.float64)
    data = build_edge_data(tri_uv)
    return rasterize_masks_from_data(tri_uv, w, h, data)


# ---------------------------------------------------------------------------
# synthetic unit tests (run: python uv_raster.py)
# ---------------------------------------------------------------------------
def _selftest():
    w = h = 64
    # one island: two triangles forming a quad in the left half
    tri_uv = np.array([
        [(0.0, 0.0), (0.5, 0.0), (0.0, 0.5)],
        [(0.5, 0.0), (0.5, 0.5), (0.0, 0.5)],
    ], dtype=np.float32)
    cover, seam = rasterize_masks(tri_uv, w, h)
    assert cover[0, 0] == 255 and cover[0, 60] == 0
    assert seam[20, 20] == 1, seam[20, 20]
    assert seam[0, 5] == 2, seam[0, 5]        # top edge of the quad (y=0)
    assert seam[5, 0] == 2, seam[5, 0]        # left edge of the quad (x=0)
    assert seam[16, 16] == 1                  # shared diagonal: interior, no line
    assert (seam == 0).sum() > 0                    # unused quarter
    assert (seam == 3).sum() == 0                   # no wrap here

    # same-side shared edge (zone terrain's coarse UV grid): three
    # triangles share the edge (0,0)-(0.5,0) with every third corner on the
    # same side -> that edge is a coverage boundary, not interior
    tri_uv6 = np.array([
        [(0.0, 0.0), (0.5, 0.0), (0.25, 0.5)],
        [(0.0, 0.0), (0.5, 0.0), (0.10, 0.30)],
        [(0.0, 0.0), (0.5, 0.0), (0.40, 0.40)],
    ], dtype=np.float32)
    _c6, seam6 = rasterize_masks(tri_uv6, w, h)
    assert seam6[0, 16] == 2, seam6[0, 16]   # shared top edge stays boundary

    # wrap seam: a "cylinder" cut column on the integer lines u=0/u=1,
    # occupying the bottom half of the image (NOT a full-image rectangle, so
    # the full-rect exclusion does not apply). Identical v-extent boundary
    # chains at u=0 and u=1 -> class 3 on both image borders
    tri_uv2 = np.array([
        [(0.0, 0.0), (1.0, 0.0), (0.0, 0.5)],
        [(1.0, 0.0), (1.0, 0.5), (0.0, 0.5)],
    ], dtype=np.float32)
    _c2, seam2 = rasterize_masks(tri_uv2, w, h)
    assert (seam2 == 3).sum() > 0, "wrap seam not detected"
    ys, xs = np.where(seam2 == 3)
    # u=0 and u=1 are the same texture line (mod 1), so the cut column is a
    # SINGLE seam line at x=0, not two lines at both image borders
    assert xs.min() <= 1 and xs.max() <= 1, (xs.min(), xs.max())
    # the SAME cut column but filling the whole image is a full-rect
    # (sprite/terrain frame), not a wrap seam -> no class 3
    tri_uv2b = np.array([
        [(0.0, 0.0), (1.0, 0.0), (0.0, 1.0)],
        [(1.0, 0.0), (1.0, 1.0), (0.0, 1.0)],
    ], dtype=np.float32)
    assert (rasterize_masks(tri_uv2b, w, h)[1] == 3).sum() == 0, \
        "full-image rectangle must not be a seam"

    # same span but different outlines (terrain tile) -> NOT a seam
    tri_uv3 = np.array([
        [(0.0, 0.0), (1.0, 0.0), (0.0, 0.7)],
        [(1.0, 0.0), (1.0, 0.4), (0.0, 0.7)],
    ], dtype=np.float32)
    _c3, seam3 = rasterize_masks(tri_uv3, w, h)
    assert (seam3 == 3).sum() == 0, "terrain tile wrongly flagged as seam"

    # closed across the wrap: a strip of quads spanning u -0.5..1.5 x
    # v 0.2..0.8 — triangles sit on BOTH sides of the integer lines u=0 and
    # u=1 (the cut columns at u=-0.5/1.5 are not integer lines), so the
    # island wraps: closure in u, no seam, u folds to full coverage
    tri_uv4 = np.array([
        [(-0.5, 0.2), (0.0, 0.2), (-0.5, 0.8)], [(-0.5, 0.8), (0.0, 0.2), (0.0, 0.8)],
        [(0.0, 0.2), (0.5, 0.2), (0.0, 0.8)],   [(0.0, 0.8), (0.5, 0.2), (0.5, 0.8)],
        [(0.5, 0.2), (1.0, 0.2), (0.5, 0.8)],   [(0.5, 0.8), (1.0, 0.2), (1.0, 0.8)],
        [(1.0, 0.2), (1.5, 0.2), (1.0, 0.8)],   [(1.0, 0.8), (1.5, 0.2), (1.5, 0.8)],
    ], dtype=np.float32)
    data4 = build_edge_data(tri_uv4)
    closure = island_wrap_closure(data4, tri_uv4)
    assert closure[0, 0], "wrap strip not detected as closed across u wrap"
    cover4, seam4 = rasterize_masks(tri_uv4, w, h)
    assert (seam4 == 3).sum() == 0, "wrap strip cut columns wrongly flagged seams"
    assert cover4.sum() / 255 > 0.55 * w * h, "folded wrap strip should cover u fully"
    # the same strip with cut columns AT u=0/u=1 (boundary chains on the
    # integer lines) is NOT closed: those chains are the seam instead
    tri_uv4b = np.array([
        [(0.0, 0.0), (0.5, 0.0), (0.0, 1.0)],   [(0.0, 1.0), (0.5, 0.0), (0.5, 1.0)],
        [(0.5, 0.0), (1.0, 0.0), (0.5, 1.0)],   [(0.5, 1.0), (1.0, 0.0), (1.0, 1.0)],
        [(1.0, 0.0), (1.5, 0.0), (1.0, 1.0)],   [(1.0, 1.0), (1.5, 0.0), (1.5, 1.0)],
        [(1.5, 0.0), (2.0, 0.0), (1.5, 1.0)],   [(1.5, 1.0), (2.0, 0.0), (2.0, 1.0)],
    ], dtype=np.float32)
    data4b = build_edge_data(tri_uv4b)
    closure4b = island_wrap_closure(data4b, tri_uv4b)
    assert not closure4b[0, 0], "cut columns on integer lines must block closure"
    assert (rasterize_masks(tri_uv4b, w, h)[1] == 3).sum() > 0, \
        "cut columns at u=0/u=1 must be seams"

    # tiling UVs fold mod 1: a triangle spanning u 0.9..1.1 covers both
    # sides of the image border
    tri_uv5 = np.array([
        [(0.9, 0.0), (1.1, 0.0), (1.0, 1.0)],
    ], dtype=np.float32)
    cover5, _s5 = rasterize_masks(tri_uv5, w, h)
    assert cover5[0, 0] == 255 and cover5[0, w - 1] == 255, "mod-1 fold failed"

    # empty input
    cover6, seam6 = rasterize_masks(np.zeros((0, 3, 2)), w, h)
    assert cover6.sum() == 0 and seam6.max() == 0
    print("uv_raster self-test: OK")


if __name__ == "__main__":
    _selftest()

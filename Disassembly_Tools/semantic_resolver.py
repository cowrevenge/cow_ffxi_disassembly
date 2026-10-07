"""Semantic resolution for extracted FFXI textures.

Derives category / subject_name / subject_family / zone_hint from
authoritative data only:

  * zone names      ROM/165/84.DAT (d_msg, zone id = entry index) —
                    research/cexi-docs/dats/ROM_165_84.md
  * client family   file id 0xD98A "Monster Family Names" (d_msg) —
                    research/cexi-docs/reference/named-dats.md. NOTE: its
                    index space is the client's own family id, which is NOT
                    the LSB xi::Family numbering, so it is not used to label
                    textures until the modelid -> client-family derivation
                    exists.
  * mob semantics   LSB vendor/server: sql/mob_pools.sql (modelid ->
                    speciesid), data/ecosystems.yaml (species -> family ->
                    ecosystem). Pinned commit: General_Tools/vendor/lsb_commit.txt

Nothing here may be filled from a texture filename or from pixels.
"""
import re
import struct
import subprocess
from pathlib import Path

HERE = Path(__file__).resolve().parent

# d_msg header: magic 0x00, flags 0x08, then 8 u32s at 0x10
# (research/cexi-docs/dats/ROM_165_84.md)
DMSG_HEADER_U32 = 0x10
DMSG_XOR_MASK = 0xFF
DMSG_STRING_MARKER = 1
DMSG_STRING_METADATA = 0x18

# known-good zone names used to validate a decoded table before trusting it
ZONE_NAME_CHECKS = {1: "Phanauet Channel", 100: "West Ronfaure",
                    230: "Southern San d'Oria", 245: "Lower Jeuno"}


class SemanticError(RuntimeError):
    pass


# ---------------------------------------------------------------------------
# d_msg string tables
# ---------------------------------------------------------------------------
def parse_d_msg(data):
    """Parse a d_msg string table -> list[str] (blank entry = '').

    Two layouts (research/cexi-docs/dats/ROM_165_84.md):
      tableSize != 0: offset table of numStrings {u32 off, u32 unk} at
                      tableOffset; block i at tableOffset + numStrings*8 + off[i]
      tableSize == 0: block i at tableOffset + stringBlockSize * i
    Block: u32 count, {u32 off, u32 flag} entries, then per entry at
    block_start + off: u32 marker (1 = present), 0x18 metadata bytes,
    NUL-terminated ASCII.
    """
    if len(data) < 0x40 or data[:5] != b"d_msg":
        raise SemanticError(f"not a d_msg table (magic={data[:5]!r})")
    fileSize, tableOffset, tableSize, blockSize, _sec, numStrings = \
        struct.unpack_from("<6I", data, DMSG_HEADER_U32 + 4)
    if not (0 < numStrings < 1_000_000):
        raise SemanticError(f"d_msg numStrings={numStrings} implausible")
    b = bytearray(data)
    for i in range(tableOffset, min(fileSize, len(b))):
        b[i] ^= DMSG_XOR_MASK

    def first_string(start):
        if start + 4 > len(b):
            return ""
        n = struct.unpack_from("<I", b, start)[0]
        if n == 0:
            return ""
        off = struct.unpack_from("<I", b, start + 4)[0]
        p = start + off
        if p + 4 > len(b) or struct.unpack_from("<I", b, p)[0] != DMSG_STRING_MARKER:
            return ""
        p += 4 + DMSG_STRING_METADATA
        if p >= len(b):
            return ""
        return b[p:b.index(0, p)].decode("latin1")

    if tableSize != 0:
        base = tableOffset + numStrings * 8
        return [first_string(base + struct.unpack_from("<I", b, tableOffset + i * 8)[0])
                for i in range(numStrings)]
    return [first_string(tableOffset + blockSize * i) for i in range(numStrings)]


def fid_for_path(tables, rom_dir, sub, fname):
    """File id whose FTABLE entry resolves to <rom_dir>/<sub>/<fname>."""
    for rd, rom_index, vtable, ftable in tables:
        if rd != rom_dir:
            continue
        for fid in range(min(len(vtable), len(ftable) // 2)):
            if vtable[fid] != rom_index:
                continue
            (v,) = struct.unpack_from("<H", ftable, fid * 2)
            if (v >> 7) == sub and (v & 0x7F) == int(fname[:-4]):
                return fid
    return None


def load_zone_names(source_root, tables):
    """zone id -> English zone name, from ROM/165/84.DAT."""
    fid = fid_for_path(tables, "ROM", 165, "84.DAT")
    if fid is None:
        raise SemanticError("ROM/165/84.DAT not present in VTABLE/FTABLE")
    data = (Path(source_root) / "ROM" / "165" / "84.DAT").read_bytes()
    names = parse_d_msg(data)
    bad = {z: n for z, n in ZONE_NAME_CHECKS.items()
           if z < len(names) and n != names[z]}
    if bad:
        raise SemanticError(
            f"zone name table failed validation at ROM/165/84.DAT: {bad}")
    return names


def load_client_family_names(source_root, tables):
    """client family id -> name, from the 0xD98A 'Monster Family Names' table
    (research/cexi-docs/reference/named-dats.md). Index space is the client's
    own, NOT LSB's xi::Family numbering."""
    fid = 0xD98A
    rel = None
    for rd, rom_index, vtable, ftable in tables:
        if fid < len(vtable) and vtable[fid] == rom_index:
            (v,) = struct.unpack_from("<H", ftable, fid * 2)
            rel = (rd, v >> 7, v & 0x7F)
            break
    if rel is None:
        raise SemanticError("0xD98A (Monster Family Names) unresolvable")
    data = (Path(source_root) / rel[0] / str(rel[1]) / f"{rel[2]}.DAT").read_bytes()
    names = parse_d_msg(data)
    # spot-check against retail content: 11=bomb, 28=skeleton, 55=rabbit
    for z, want in ((11, "bomb"), (28, "skeleton"), (55, "rabbit")):
        if z < len(names) and names[z] != want:
            raise SemanticError(f"family table check failed: [{z}]={names[z]!r} != {want!r}")
    return names


# ---------------------------------------------------------------------------
# model id <-> DAT file id (kuluu-render look_resolver::npc_dat_id)
# ---------------------------------------------------------------------------
NPC_DAT_ID_BANDS = ((1500, 1300), (3000, 50295), (3500, 96907), (1_000_000, 98239))


def npc_dat_id(modelid):
    for upper, base in NPC_DAT_ID_BANDS:
        if modelid < upper:
            return modelid + base
    raise ValueError(modelid)


def modelids_for_dat_fid(fid):
    """All mob model ids whose npc_dat_id lands on this file id."""
    out = []
    for upper, base in NPC_DAT_ID_BANDS:
        lo = fid - base
        hi = upper - 1
        if lo <= hi:
            out.extend(range(max(lo, 0), hi + 1))
    return out


# ---------------------------------------------------------------------------
# LSB cross-reference
# ---------------------------------------------------------------------------
class LsbSemantics:
    """mob_pools.sql + ecosystems.yaml at a pinned commit.

    modelid -> (family_name, ecosystem, family_id, [mob names])

    Sources, unioned per model (a model DAT shared by several species is
    only labeled when they all fall in one family):
      * the pinned vendor/server sql/mob_pools.sql
      * an optional live-server pool export (TSV: modelid<TAB>speciesid<TAB>name)
      * optional live-server zone mobs.yaml species labels (load_mobs_yaml_species)
    """

    _ROW = re.compile(
        r"INSERT INTO `mob_pools` VALUES \((\d+),'([^']*)','([^']*)',(\d+),0x([0-9A-Fa-f]+)")

    def __init__(self, lsb_root, pin_file, extra_pools_file=None):
        lsb_root = Path(lsb_root)
        pin_file = Path(pin_file)
        self.commit = self._checkout_commit(lsb_root)
        if pin_file.exists():
            pin = pin_file.read_text().strip()
            if pin and pin != self.commit:
                raise SemanticError(
                    f"LSB commit mismatch: pin {pin_file}={pin} checkout={self.commit}")
        self.species, self.species_by_name = self._load_ecosystems(
            lsb_root / "data" / "ecosystems.yaml")
        self.model = self._load_mob_pools(lsb_root / "sql" / "mob_pools.sql")
        if extra_pools_file:
            self._merge_pools_file(Path(extra_pools_file))

    def _merge_pools_file(self, path):
        try:
            lines = path.read_text(encoding="utf-8").splitlines()
        except OSError:
            return
        for line in lines:
            parts = line.split("\t")
            if len(parts) != 3:
                continue
            try:
                modelid, speciesid, name = int(parts[0]), int(parts[1]), parts[2]
            except ValueError:
                continue
            self.model.setdefault(modelid, {}).setdefault(speciesid, []).append(name)

    @staticmethod
    def _checkout_commit(lsb_root):
        r = subprocess.run(["git", "-C", str(lsb_root), "rev-parse", "HEAD"],
                           capture_output=True, text=True)
        if r.returncode != 0:
            raise SemanticError(f"not a git checkout: {lsb_root}")
        return r.stdout.strip()

    @staticmethod
    def _load_ecosystems(path):
        import yaml
        doc = yaml.safe_load(path.read_text(encoding="utf-8"))
        species, species_by_name = {}, {}
        for eco_name, eco in doc.get("ecosystems", {}).items():
            for fam_name, fam in (eco.get("families") or {}).items():
                fid = fam.get("id")
                for sp_name, sp in (fam.get("species") or {}).items():
                    species[sp.get("id")] = (sp_name, fam_name, fid, eco_name)
                    species_by_name[sp_name] = (sp.get("id"), fam_name, fid, eco_name)
        return species, species_by_name

    @classmethod
    def _load_mob_pools(cls, path):
        """modelid -> {speciesid: [mob names]}"""
        model = {}
        with open(path, encoding="utf-8") as f:
            for line in f:
                m = cls._ROW.search(line)
                if not m:
                    continue
                _poolid, name, _pname, speciesid, hx = m.groups()
                if len(hx) < 8:
                    continue
                modelid = int(hx[6:8] + hx[4:6], 16)   # look[1] = model id (LE u16)
                model.setdefault(modelid, {}).setdefault(int(speciesid), []).append(name)
        return model

    def mob_semantics(self, modelid, extra_species=None):
        """(family_name, ecosystem, family_id, mob_names) or None.

        extra_species: optional {modelid: set of species names} from live-server
        zone mobs.yaml files; used when the pinned mob_pools.sql does not carry
        the model (private servers ship partial pool sets).
        """
        pools = self.model.get(modelid)
        candidates = []          # (fam_name, fam_id, eco, names)
        if pools:
            for speciesid, mobs in pools.items():
                sp = self.species.get(speciesid)
                if sp:
                    candidates.append((sp[1], sp[2], sp[3], mobs))
        for sp_name in sorted(extra_species.get(modelid, ()) if extra_species else ()):
            sp = self.species_by_name.get(sp_name)
            if sp:
                candidates.append((sp[1], sp[2], sp[3], []))
        if not candidates:
            return None
        by_fam = {}
        names = []
        for fam_name, fam_id, eco, mobs in candidates:
            by_fam.setdefault((fam_name, fam_id, eco), []).extend(mobs)
        if len(by_fam) > 1:
            return None                       # mixed families in one model DAT
        (fam_name, fam_id, eco), names = by_fam.popitem()
        return fam_name, eco, fam_id, list(dict.fromkeys(names))


def load_mobs_yaml_species(zones_dir):
    """{modelid: set(species names)} from live-server zones/*/mobs.yaml.

    The species field sits on the mob template; the model id on
    attributes.render.look (type 'standard')."""
    import yaml
    zones_dir = Path(zones_dir)
    out = {}
    if not zones_dir.is_dir():
        return out

    def walk(node, species):
        if isinstance(node, dict):
            sp = node.get("species", species)
            attrs = node.get("attributes")
            look = attrs.get("render", {}).get("look") if isinstance(attrs, dict) else None
            if isinstance(look, dict) and look.get("type") == "standard" \
                    and isinstance(look.get("model"), int) and sp:
                out.setdefault(look["model"], set()).add(str(sp))
            for v in node.values():
                walk(v, sp)
        elif isinstance(node, list):
            for v in node:
                walk(v, species)

    for p in sorted(zones_dir.glob("*/mobs.yaml")):
        try:
            doc = yaml.safe_load(p.read_text(encoding="utf-8"))
        except (OSError, yaml.YAMLError):
            continue
        walk(doc, None)
    return out


# ---------------------------------------------------------------------------
# texture semantics
# ---------------------------------------------------------------------------
# fine category (extract_dats.categorize) -> map category, for textures whose
# mesh references all come from zone scene DATs
SCENE_CATEGORY = {
    "ground": "background", "walls_stone": "background",
    "walls_stucco": "background", "walls_brick": "background",
    "building": "foreground", "wood": "foreground", "sheets": "foreground",
    "details": "foreground", "foliage": "foreground", "misc": "foreground",
    "sky": "environment", "water": "environment",
    "effects": "effect",
}


def scene_category(fine_category):
    return SCENE_CATEGORY.get((fine_category or "").lower(), "foreground")


def resolve_texture_semantics(fine_category, zone_names, zone_fids,
                              lsb, dat_fids, model_sem_by_dat):
    """Derive (category, subject_name, subject_family, zone_hint, lsb_family_id,
    confidence, warnings) for one texture.

    zone_fids: set of zone file ids whose scene DATs reference the texture
    (a DAT is a zone scene when it carries MZB placements).
    dat_fids: set of all DAT file ids with mesh references to the texture.
    model_sem_by_dat: fid -> (family, eco, fam_id, names) for DATs that are
    mob model DATs (None when the fid is not a mob model DAT).
    """
    warnings = []
    zone_names = zone_names or {}

    mob_fids = {f for f in dat_fids if model_sem_by_dat.get(f) is not None}
    zone_fids = set(zone_fids)

    if zone_fids:
        # zone scene binding is the visible usage; shared textures keep the
        # zone identity and note the model references
        category = scene_category(fine_category) if fine_category else "unknown"
        names = [zone_names.get(f, "") for f in sorted(zone_fids)]
        names = [n for n in names if n]
        if len(set(names)) == 1:
            zone_hint = names[0]
        else:
            zone_hint = ""
            warnings.append(f"texture shared by {len(zone_fids)} zone scenes; "
                            "zone_hint left blank")
        if mob_fids:
            warnings.append("also referenced by mob model DAT(s)")
        return category, zone_hint, "", zone_hint, None, \
            ("partial" if zone_hint else "blank"), warnings

    if mob_fids:
        category = "mob_skin"
        sems = [model_sem_by_dat[f] for f in sorted(mob_fids)]
        sems = [s for s in sems if s is not None]
        if len(set((s[0], s[1]) for s in sems)) == 1:
            subject, family = sems[0][0], sems[0][1]
            fam_id = sems[0][2]
            confidence = "resolved"
        else:
            subject, family, fam_id = "", "", None
            confidence = "blank"
            warnings.append("mob model DAT(s) resolve to mixed/unknown families")
        return category, subject, family, "", fam_id, confidence, warnings

    # referenced only by non-zone, non-model DATs (effect meshes in item or
    # other containers) — category from the chunk's fine category only
    category = scene_category(fine_category) if fine_category else "unknown"
    return category, "", "", "", None, "blank", \
        ["mesh references outside zone/model DATs; subject not derivable"]


# ---------------------------------------------------------------------------
# map file writer (shared by extract_dats.py and stage_hd_test.py)
# ---------------------------------------------------------------------------
def _toml_str(s):
    s = str(s).replace("\\", "\\\\").replace('"', '\\"')
    return f'"{s}"'


def _toml_list(items):
    return "[" + ", ".join(_toml_str(i) for i in items) + "]"


def write_map_toml(path, *, source_texture, w, h, source_dat, generated_at,
                   category, subject_name, subject_family, zone_hint,
                   lsb_family_id, lsb_commit, used_by_meshes,
                   referenced_by_scenes, mesh_reference_count, regions,
                   warnings, orphan=False, uvmask_file="", seammask_file=""):
    unmatched = sum(1 for r in regions if r["technique"] == "unknown")
    lines = [
        "# Auto-generated by cow_tool extract (map pass).",
        "# [auto] fields derived from mesh geometry / FFXI data / LSB.",
        "# [manual] fields left blank for Stage 2 authoring.",
        "",
        f"source_texture = {_toml_str(source_texture)}",
        f"dimensions = [{w}, {h}]",
        f"source_dat = {_toml_str(source_dat)}",
        f"generated_at = {_toml_str(generated_at)}",
        "",
        f"category = {_toml_str(category)}",
        f"subject_name = {_toml_str(subject_name)}",
        f"subject_family = {_toml_str(subject_family)}",
        f"zone_hint = {_toml_str(zone_hint)}",
    ]
    if lsb_family_id is not None:
        lines.append(f"lsb_family_id = {lsb_family_id}")
    if lsb_commit:
        lines.append(f"lsb_source_commit = {_toml_str(lsb_commit)}")
    lines += [
        "",
        f"used_by_meshes = {_toml_list(used_by_meshes)}",
        f"referenced_by_scenes = {_toml_list(referenced_by_scenes)}",
        f"mesh_reference_count = {mesh_reference_count}",
    ]
    if uvmask_file or seammask_file:
        lines += [
            "",
            "# Rasterized UV masks at source resolution (L-mode PNGs).",
            "# uvmask: 255 where any UV triangle covers the pixel, else 0.",
            "# seammask: 0 unused / 1 covered interior / 2 UV boundary /",
            "#           3 wrap-seam boundary.",
            f"uvmask_file = {_toml_str(uvmask_file)}",
            f"seammask_file = {_toml_str(seammask_file)}",
        ]
    lines.append("")
    for r in regions:
        lines += [
            "[[regions]]",
            f"id = {_toml_str(r['id'])}",
            f"bbox = [{r['bbox'][0]}, {r['bbox'][1]}, {r['bbox'][2]}, {r['bbox'][3]}]",
            f"uv_island_triangle_count = {r['uv_island_triangle_count']}",
            f"technique = {_toml_str(r['technique'])}",
            f"tiling = {_toml_str(r['tiling'])}",
            f"alpha_pattern = {_toml_str(r['alpha_pattern'])}",
            f"mesh_parts = {_toml_list(r['mesh_parts'])}",
            "role = \"\"",
            "content_hint = \"\"",
            "",
        ]
    lines += [
        "[extractor_notes]",
        f"unmatched_regions = {unmatched}",
        "mesh_uv_precision = \"float32\"",
    ]
    if orphan:
        lines.append("orphan = true")
    lines.append(f"warnings = {_toml_list(warnings)}")
    Path(path).write_text("\n".join(lines) + "\n", encoding="utf-8")

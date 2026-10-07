# Textures & Meshes — how kuluu gets pixels and polygons out of the retail ROMs

> **Consolidated from `Cow_doc/TEXTURES_MESH.md` during the 2026-09-13 doc reorg into
> `Cow_doc/`.** Content carried over verbatim; all in-tree citations verified to still
>
> **Freshness (2026-10-08):** not reverified since consolidation; treat as a dated snapshot.
> resolve on 2026-09-13.

One-stop reference: **where the game data lives, how a `.DAT` file is structured, and how
kuluu turns its chunks into textures and meshes.** Current implementation: the `ffxi-dat`
crate (parsers) + `kuluu-render` (`dat_mzb.rs` / `dat_mmb.rs` / `zone_texture.rs`, Bevy).

The archived `TEXTURES.md` / `ROM-LAYOUT.md` describe the old CowEngine stack
(`data/roms/…`, `src/rom/texdat.cpp`, OpenGL). Their byte-level findings still hold, but
paths and code locations below are the current ones.

## 1. Where the ROMs live

Kuluu resolves game files from **`vendor/game-files`** relative to the repo root — a
symlink into the retail install (`C:\HorizonXI\Game\SquareEnix\FINAL FANTASY XI`).
`play_cowland.bat` sets CWD to the repo root for exactly this reason. Detection logic:
`ffxi-dat/src/install_detect.rs` — a dir is an FFXI root if it contains both `VTABLE.DAT`
and a `ROM/` directory; common install roots are searched automatically.

### Content packs

| Path | Tables | What |
|---|---|---|
| `ROM/` | 0–383 | **Base pack** (~48.7k DATs). Base-game zones AND later content appended to high tables (Abyssea 240–258, RoZ 332+, expansion models e.g. Mandy @ 363) |
| `ROM2/` … `ROM10/` | few each | Expansion packs: CoP = `ROM3`, ToAU = `ROM4`, WoG = `ROM5`, … |

Every asset = `<pack>/<table>/<file>.DAT`, e.g. Port Jeuno's zone file = `ROM/1/42.DAT`.

Two index files at the pack root:

- **`FTABLE.DAT`** — master file table: `file_id → {dir(table), file}` (u16 LE,
  `dir = raw >> 7`, `file = raw & 0x7F`; parsed in `ffxi-dat/src/ftable.rs`). This is how
  a numeric resource id becomes a path on disk.
- **`VTABLE.DAT`** — version/patch markers, one byte per file id (`vtable.rs`); used to
  detect patch state.

Name→path ground truth (which zone/model lives in which file): AltanaViewer `List/**.csv`
(two-part paths → base pack, three-part → numbered pack).

## 2. How a `.DAT` works — the chunk container

A zone/asset `.DAT` is not one blob; it is a **stream of self-describing chunks**. Each
chunk starts with a 16-byte header:

```
char name[4]            // tag, e.g. "MZB ", "MMB ", "3TXD", "f_sa", "m_XX"
u32  tl                 // packed: kind + length
```

Decode of `tl` (retail walker, verified against `FFXiMain.dll` `.text` 0x100732C0):

```
kind       = tl & 0x7F                       // 7-bit chunk type
size_units = (tl >> 7) & 0x7FFFF             // 19 bits, in 16-BYTE units
total      = size_units * 16                 // includes the 16-B header
body       = [header_end .. header_end + total - 16)
```

⚠️ The size field is **19 bits**, not 20 — bit 26 is `is_shadow`. XIM's 20-bit walk is a
known latent bug; our walker (`ffxi-dat/src/chunk.rs`) matches retail.

Chunks tile the file end-to-end; a walker just hops `total` bytes at a time. Some chunks
are further nested (the zone map's `RID` region tables live inside a `f_sa` payload), so
`walk_tree` builds the hierarchy. The first 4 bytes of the whole file are also a tag
naming the asset family (`f_sa`/`s_ju`/`f_ko` zone maps, `e_ol`-style model codes,
`m_XX` minimaps, `NNhm`/`NNtr` model part streams…).

### Chunk types kuluu consumes

| Tag / kind | Contents | Parsed by | Used by |
|---|---|---|---|
| **`3TXD` / `1TXD` / `BGRA` / `ARGB`** | Texture records (see §3) | `ffxi-dat/src/texture.rs` | `kuluu-render/zone_texture.rs` |
| **`MZB`** (kind 0x1C) | Zone scene: placement table + **collision data** + quadtree groups + lighting offsets | `ffxi-dat/src/mzb.rs` | `kuluu-render/dat_mzb.rs` |
| **`MMB`** (kind 0x2E) | Model pieces: per-face texture bindings + vertices + indices | `ffxi-dat/src/mmb.rs` | `kuluu-render/dat_mmb.rs` |
| `f_sa`/`s_ju`/`f_ko` (+ `RID` tables) | Zone map: terrain boxes, spawn markers, `_NNN` zone-id string | `ffxi-dat/src/zone_dat.rs` | zone metadata |
| `m_XX` | Minimap image (512×512 8bpp + palette A1/B1 variants) | `ffxi-dat/src/map_image.rs` | `kuluu-render/minimap/` |
| `d3m` / skeleton chunks | Actor/equipment models | `ffxi-dat/src/d3m.rs`, `skel*.rs` | `ffxi_actor_render.rs` |
| `vos2` | Voice/sprite sheets | `ffxi-dat/src/vos2.rs` | `dat_vos2.rs` |

## 3. Textures

### Record grammar (byte-verified)

Each texture sits in its own chunk body:

```
[name 16B]                // 8-char category ("model","sea","moon",…) + 8-char name, space-padded
[BITMAPINFOHEADER 40B]    // u32 0x28, i32 w, i32 h, planes=1, bitCount=8 (legacy lie), zeros
[u32 0x20]                // output bpp
[FourCC]                  // "3TXD" = DXT3 (BC2) · "1TXD" = DXT1 (BC1) · "BGRA"/"ARGB" = raw 32bpp
[u32 payloadBytes]        // w*h for BC2/32bpp, w*h/2 for BC1
[u32 pitch]               // w*4
[payload]                 // top row first
```

- Pixels are **DXT-compressed, not 8bpp palettes** (the old 8bpp theory was wrong;
  `kStdMapPal` applies to minimaps only). Since BC2 is exactly 1 byte/px, the legacy
  `payload == w*h` check passed under both theories.
- Names split into **namespace + local** (bytes 0–8 / 8–16); a blank local token means
  "unnamed" and must not be keyed into name maps.
- Robust parse = scan for the FourCC tags, anchor back to the nearest plausible
  BITMAPINFOHEADER, verify payload size, decode in place to RGBA8.

### The FFXI alpha convention (important!)

FFXI authors alpha at **half scale**: a fully opaque texel decodes as `0x80`, not `0xFF`.
So every consumer doubles it back (`ffxi_alpha_remap` in `texture.rs`):

- `raw < 16` (`CUTOUT_TRANSPARENT_MAX`) → truly transparent (cutout/punchthrough foliage).
- otherwise → `min(255, raw*2)`.

The doubling is continuous — reading only the top nibble would stretch DXT3's 4-bit alpha
dither and posterize smooth BGRA sky canopies.

### Upload to the GPU (`kuluu-render/src/zone_texture.rs`)

`decoded_texture_to_image()` builds a Bevy `Image`: alpha remap → optional sRGB mip chain →
bilinear sampler. `TextureQuality`:

- **mipmaps OFF by default** — XIM uploads mip 0 only (bilinear, no mips); we match for
  pixel faithfulness. Enable mips only if you accept slight sharpness loss for less shimmer.
- **anisotropy 1 by default** (disabled; only helps with mips).
- RGB is never touched — FFXI stores real surface colour in low-alpha texels; a colour-bleed
  pass would smear detail.
- Textures with any texel below the cutout threshold get `AlphaMode::Mask(0.5)` so black-RGB
  punchthrough texels test out instead of rendering opaque.
- Sky shells (cloud canopy, star dome) are the one exception that runs
  `resolve_dxt3_alpha_dither` — they're the only surfaces magnified enough for the stored
  4-bit dither to resolve into visible dots.

Ground truth (Port Jeuno): **t_ju = `ROM/1/42.DAT` → 51 DXT3 entries** across categories
(model/sea/moon/star/bird/clod/mist: `kabe`, `stone_wh`, `quf`, `myroom01–04`, `ground_1`,
`sea01/02` foam layers, …); **m_ju = `ROM/1/20.DAT` → 14 entries** (`yuka00` street floor
first). Log: `[texdat] …: N texture entries (DXT->RGBA8)`.

## 4. Meshes — MMB pieces placed by MZB

The retail visual scene is two encrypted chunk types inside the zone `.DAT`:

### MMB (kind 0x2E) — the models

Decryption first (`mmb.rs::decrypt_in_place`): a keyed XOR stream seeded from
`KEY_TABLE[data[5] ^ 0xF0]`, plus a second 8-byte block-swap pass when the header carries
the `0xFFFF` marker. Then:

```
[header 60B]              // len/count, kind, moniker, id[16], piece count, bbox
per piece:
  char texCategory[8] + char texName[8]   // THE per-face texture binding
  vertices: pos 3f, normal 3f, u32 color, uv 2f   // 36 B/vert — UVs are artist-authored
  u16 triangle-strip indices
```

### MZB (kind 0x1C) — the scene

After decrypt, a packed `ZoneBlockHeader` (0x20 B, spec in
`research/XIClient/.../ZoneBlockFormat.h`): chunk count + decrypt index, **collision-data
offset**, terrain scale/units, quadtree group count + group-list offset, lighting offset,
substructure/collision flags. Then **0x64-byte placement records**:

```
char id[16]    // XOR 0x55; matches an MMB id
float tr[3]    // translation
float rot[3]   // XYZ euler, radians
float sc[3]    // negative = mirrored instance
```

### Integration in kuluu (`dat_mzb.rs` / `dat_mmb.rs`)

- Pieces merge by `(texCat, texName)` → tens of merged draw groups per zone (Jeuno: 651
  placements / 166 MMBs / 130,538 placed tris / 47 textures, ≤ ~50 draw calls).
- **Orientation bake `(x_a, -y_a, -z_a)`** applied at load (same bake the server-side
  ximesh uses) — converts authoring frame to the client world frame. If anything looks
  mirrored/flipped again, that bake regressed.
- Vertex colors baked at load (`min(255, 2*c)` per channel) so plain modulate gives the
  retail look.
- **Distance streaming**: `DEFAULT_WORLD_DRAW_DISTANCE = 80.0` world units, MMB load margin
  ×1.25 — pieces outside range aren't uploaded; the quadtree group list drives culling.
- Skip rules: blank-texture helper pieces (portals/occluders) and unplaced runtime-effect
  MMBs (sun/moon spheres, light stumps). Real water tiles are instanced by a separate
  mechanism (still v2 territory).

## 5. Collision — three sources, don't confuse them

| Source | Format | Who uses it | Role |
|---|---|---|---|
| **MZB collision section** (inside the zone `.DAT`) | custom, offsets in `ZoneBlockHeader` | `ffxi-dat/src/mzb.rs` | client-side terrain query / wall clip |
| **ximesh** (server-side, per-zone `.ximesh` zlib files in the `dev_cow_ximeshes` Docker volume) | grid → cells → blocks (verts/tris/meta) + placements | xi_map (LSB); generated from MZB by `cow_tools/mzb2ximesh.py` | **authoritative** server collision — the oracle for our movement sync |
| **Recast `.nav`** (`MSET` header + dtNavMesh tiles, see `kuluu-nav/docs/detour_format.md`) | serialized Detour navmesh | shipped by LSB `navmeshes/` volume; `kuluu-nav` doesn't consume these yet (GridNav uses hand-traced PNG occupancy today) | future cliff-aware pathfinding |

Rule of thumb: **the server (ximesh) wins** for where you may stand; the MZB collision
section is our local approximation between server snaps.

## 6. End-to-end pipeline (one zone load)

```
LSB zone id (from lobby next_login / DB)
  → zonemaps.csv (zone → t_<z> / m_<z> / minimap / ximesh asset ids)
  → ftable file_id → <pack>/<table>/<file>.DAT under vendor/game-files
  → ChunkWalker over the DAT
      ├─ texture chunks  → DecodedTexture (DXT1/3 or 32bpp) → ffxi_alpha_remap → Bevy Image
      ├─ MZB chunks      → decrypt → placements + collision + quadtree
      └─ MMB chunks      → decrypt → pieces (bindings, verts, UVs, strips)
  → (x,-y,-z) bake + vertex-color bake → merged draw groups
  → zone_ffxi.wgsl material (unblended opaque pass; Mask for cutouts; water blended)
```

## 7. Log lines to grep after a run

```
[texdat] …/ROM/1/42.DAT: 51 texture entries (DXT->RGBA8)     <- t-file table, all categories
[texdat] …/ROM/1/20.DAT: 14 texture entries (DXT->RGBA8)     <- m-file (yuka00 first)
[mzb]  …: 651 placements, 166 mmbs, 130538 tris, 47 textures <- exact spec census line
[mmb]  '…' WxH uploaded                                       <- per-piece texture live
[ximesh] grid=… blocks=… placements=…                         <- server-mesh mirror load
```

## 8. Known gaps (not yet 1:1 with retail)

- Water: scrolling `sea01` crossfading to `sea02` over a teal base — close, not the full
  animated retail surface.
- Ships/vessels: schedule-driven retail models, no zone-mesh representation yet.
- Recast `.nav` consumption in `kuluu-nav` (parser spec exists, implementation pending).
- Per-placement texture-map id (`mapId`, bits 3–5 + 25–26 of the placement flags) is parsed
  but selects nothing — uniformly 0 in the zones measured so far.

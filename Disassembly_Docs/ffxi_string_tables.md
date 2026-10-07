# FFXI client string tables (`d_msg`) — what the map pipeline reads

Working reference for the texture-map semantic layer
(`Disassembly_Tools/semantic_resolver.py`). Full byte-level format of the `d_msg`
container is documented in
[research/cexi-docs/dats/ROM_165_84.md(local copy lives in the kuluu-engine tree: `C:Cow_Kuluu_ffxi-engineesearchxi-docs\1`);
this page records which tables the pipeline actually uses, how each is
validated, and the gotchas found while wiring them up.

## `d_msg` container (summary)

FFXI stores all its text (zone names, mob families, menus, dialogs) in
`d_msg` DATs. Header (little-endian):

```
0x00  4   magic "d_msg"
0x14  u32 fileSize
0x18  u32 tableOffset     (start of encrypted region)
0x1C  u32 tableSize       (numStrings*8 when table layout; 0 = no-table layout)
0x20  u32 stringBlockSize (no-table layout only)
0x24  u32 stringSectionSize (= fileSize - tableOffset - tableSize)
0x28  u32 numStrings
```

Everything from `tableOffset` to `fileSize` is XOR'd with `0xFF`. Two layouts:

- **With offset table** (`tableSize != 0`): `numStrings × {off:u32, blockSize:u32}`
  at `tableOffset`; string block *i* at `tableOffset + numStrings*8 + off[i]`.
- **Without table** (`tableSize == 0`): block *i* at `tableOffset + stringBlockSize*i`.

A block is `u32 count` + `count × {off:u32, flag:u32}` +, per entry at
`block_start + off`, `u32 marker (1 = present)` + `0x18` metadata bytes +
NUL-terminated ASCII. (The offset-table "blockSize" field is the full block
size, i.e. header + entries + string data.)

Parser: `semantic_resolver.parse_d_msg` (both layouts; raises `SemanticError`
naming the DAT + offset on any implausible field).

## Zone names — `ROM/165/84.DAT`

- 300 entries, **index = zone ID = the scene DAT's file id** (the client
  loads zone *N*'s scene from file id *N*; verified through VTABLE/FTABLE,
  e.g. zone 100 → `ROM/0/28.DAT`). This is why a fid set of MZB-bearing DATs
  can be looked up directly in this table.
- With-table layout: `tableSize = 0x960`, `numStrings = 300`.
- The file id is resolved by reverse FTABLE scan
  (`semantic_resolver.fid_for_path`), never hardcoded — the pack location is
  not guaranteed across installs.
- Blank entries exist for unused slots.

Validation (hard-fail in `load_zone_names`):

| index | expected                |
|-------|-------------------------|
| 1     | Phanauet Channel        |
| 100   | West Ronfaure           |
| 230   | Southern San d'Oria     |
| 245   | Lower Jeuno             |

All four pass on the retail install at `C:\PhoenixXI\SquareEnix\FINAL FANTASY XI`.

## Monster family names — file id `0xD98A`

- Named "Monster Family Names" in
  [research/cexi-docs/reference/named-dats.md(local copy lives in the kuluu-engine tree: `C:Cow_Kuluu_ffxi-engineesearchxi-docs\1`);
  resolves to `ROM/188/38.DAT` on retail.
- Without-table layout: `tableSize = 0`, `stringBlockSize = 0xA0`,
  `numStrings = 512`.
- **Gotcha (why the pipeline does not use it for labeling):** the index space
  is the client's own family id. It is *not* the LSB `xi::Family` numbering
  (spot checks: index 11 = "bomb", 28 = "skeleton", 55 = "rabbit" — these
  match retail display names, but a model's client-family id cannot yet be
  derived from its model id, and LSB's family ids do not line up with this
  table). `load_client_family_names` decodes and validates the table
  (11/28/55 spot checks, hard-fail on mismatch) but the map pipeline labels
  mob textures from LSB `mob_pools` + `ecosystems.yaml` instead. Re-visit if
  the modelid → client-family derivation is ever reverse-engineered.

## Pipeline usage (map pass)

1. `load_zone_names` → `zone_fid → zone name` dict. A texture whose mesh
   references include a zone scene DAT gets `zone_hint` / `subject_name` from
   this table (single-zone → filled; multi-zone → blank + warning).
2. `load_client_family_names` → validation only (see gotcha above).
3. Mob semantics come from the pinned LSB checkout
   (`General_Tools/vendor/lsb_commit.txt`): `sql/mob_pools.sql`
   (modelid → speciesid, byte-swapped little-endian u16 in the `look` field)
   + `data/ecosystems.yaml` (species → family → ecosystem), with optional
   live-server supplements (`vendor/live_mob_pools.tsv`,
   `vendor/zones/*/mobs.yaml` species labels).

Rule of the pipeline: if a field cannot be filled from one of these
authoritative sources, it is left blank and logged — never guessed from the
texture filename or pixels.

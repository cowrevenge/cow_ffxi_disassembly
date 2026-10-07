# Tools — list and short descriptions of all tools (and where the rest lives)

> **Layout note (2026-10-08 vault reorg):** the `cow_tools/` paths below predate the reorg.
> Tools now live under `General_Tools/` (asset/zone/vendor tooling) and
> `Disassembly_Tools/` (DLL/DAT analysis suite, census scripts, probes). See START_HERE.txt.

> **Consolidated from `Cow_doc/TOOLS.md` during the 2026-09-13 doc reorg into
> `Cow_doc/`, refreshed against the live `cow_tools/` tree (2026-09-13):** the
> `ffxi_disasm/` scanner suite and `ffxi_dat_find.py` were added to the tree after the
> original inventory and are documented here for the first time. Cross-references now
> point at `Cow_doc/` files.

Where everything lives now and what it does. The old CowEngine `tools/` dir
(`C:\CowEngine`) is gone as such — its Python workhorses moved to **`cow_tools/`**, and most
offline probing migrated from CMake-built C++ exes to **Rust examples in `ffxi-dat/examples/`**
(the parsers they were verifying now live in the `ffxi-dat` crate).

Layout at a glance:

| Location | What |
|---|---|
| `cow_tools/` | Python pipeline tools + retained C++ probes + the `ffxi_disasm/` scanner suite (standalone; not part of the cargo workspace) |
| `ffxi-dat/examples/` | ~60 Rust offline probes (`cargo run -p ffxi-dat --example <name>`) |
| `dev-live/` | Live-stack verification scripts (UDP probe/diag) alongside the compose file |
| `kuluu-mcp/` | MCP server that drives a **live** session against the Docker LSB stack (agent test bed) |
| `lsb-scrape/` | Build-time scraper: LSB SQL dumps / lua enums / C++ headers → compile-time Rust tables (consumed only from `build.rs`) |
| `scripts/` | Repo ops: `checks.sh`, `cargo-guard.sh`, `target-hygiene.sh`, beads sync/publish, hook installers |
| `xtask/` | Workspace task runner (`cargo xtask …`) |
| `play_cowland.bat` | One-shot client launcher → local CowLand stack (pins `FFXI_MAP_LOCAL_PORT=47500`) |
| `speedup.ps1` | Windows perf/build tweaks helper |

## 1. Zone data pipeline (the workhorses, `cow_tools/`)

| Tool | What it does | Usage / notes |
|---|---|---|
| `zoneparse.py` | **Canonical reference parser** for zone .DATs: chunk walk, all three decrypt routines + both 256-byte key tables (ported from xi-tinkerer), MZB placements + MMB models with per-piece texture names and authored UVs. Ground truth for the Rust parsers in `ffxi-dat`. | `python cow_tools/zoneparse.py <zone.DAT>` — works against any zone DAT from the retail copy (resolve via `vendor/game-files`). Imported by `colcheck.py`. |
| `mzb2ximesh.py` | **How collision meshes are made**: extracts a zone's collision grid from its .DAT MZB chunk and repacks it into an LSB-format `.ximesh` (zlib; cell-entry pair order swapped vs the DAT; material/barrier bits → 1 meta byte/tri; header counts = *unique* blocks/placements; raw authoring frame kept — loader applies the `(x,-y,-z)` bake at load). Feeds the `dev_cow_ximeshes` Docker volume consumed by xi_map. | `python cow_tools/mzb2ximesh.py <zone.DAT> [out.ximesh]` or `--all [--force]`. Re-run after adding zones, then push the result into the `cow-map` container's ximeshes mount. |
| `colcheck.py` | Placement-matrix verifier: parses the MZB collision section, compares euler-derived matrices against SE's baked o2w ground truth embedded in the same file (the DAT is its own test), prints censuses + anchor placements. This killed the "transpose" red herring. | `python cow_tools/colcheck.py <zone.DAT>` (imports `zoneparse`). |
| `gen_zonemaps.py` | Generated the CowEngine-era `data/zonemaps.csv` runtime asset table (AltanaViewer zone→ROM mapping × LSB `zone.yaml` ids). **Legacy**: its inputs (`data/roms/`, `third_party/lsb/`) no longer exist at repo root — kuluu resolves assets through `FTABLE.DAT` under `vendor/game-files` instead. Kept for reference / re-pointing if a CSV-style table is ever needed again. | `python cow_tools/gen_zonemaps.py [--write]` |
| `ffxi_dat_find.py` | Two small lookups against a retail FFXI install (no cargo, no build): `resolve <file_id>…` prints the ROM path each file id maps to (VTABLE/FTABLE walk across ROM + ROM2..10); `scan-tag <fourcc>…` walks every DAT the tables know about and lists the files holding a Scheduler (kind 0x07) chunk named with any of the given tags. | `python ffxi_dat_find.py resolve 30834 30912` · `python ffxi_dat_find.py scan-tag tlk0 thk1` (slow — tens of thousands of files; run once and keep the output). Set `FFXI_DAT_PATH` or pass `--root`. |

## 2. Full ROM asset extraction

| Tool | What it does | Usage / notes |
|---|---|---|
| `extract_dats.py` | Dumps every decodable asset from **all** ROM .DAT files: texture chunks → PNG (DXT3/DXT1/BGRA), menumaps → 512×512 PNG (A1 std-palette / B1 embedded), MZB+MMB → composed zone-scene OBJ+MTL, Bone+VertexOs2 → bind-pose skinned OBJs, D3m → effect-mesh OBJs. Buckets: `backgrounds/`, `foregrounds/`, `extras/environment/`, `extras/minimaps/`, `models/<src>/`; manifest `INDEX.csv` maps every output → source .DAT + chunk kind. | `python cow_tools/extract_dats.py [--only SUBSTR] [--limit N] [--skip-models]` — full run ≈ 30+ min, multi-GB output (last full dump: `extracted_dats/` at repo root, 53,065 files → 39,243 textures). Point `ROOT_DEFAULT` at the live ROMs if you re-run. |
| `texdat/dat_to_png.py`, `png_to_dat.py`, `texfmt.py` | Reference texture-codec trio: DAT texture record ↔ PNG, format sniffing ("3TXD"/"1TXD"/BGRA). Used by `extract_dats.py` and as the byte-level reference for `ffxi-dat/src/texture.rs`. | standalone |

Alpha convention reminder (matters for anything consuming these PNGs): FFXI stores alpha at
half scale (opaque = 0x80); wall/floor "opacity" is a 50/50 dither straddling 0.5 — don't
threshold at exactly 0.5. See `Cow_doc/Texture_Mesh.md` §3.

## 3. Offline loader probes

### Rust examples (`ffxi-dat/examples/`) — the primary set now

Run with `cargo run -p ffxi-dat --release --example <name> [args]`. Families:

- **Chunk/container recon**: `dat-chunk-dump`, `dat-chunks`, `dat-chunk-kinds`, `dat-list-kinds`, `dat-print-root`, `dat-decode-all`, `dat-ref-scan`, `dat-resolve`, `dat-cross-resolve-check`
- **MZB (scene/collision)**: `dat-mzb-probe`, `dat-mzb-header-dump`, `dat-mzb-placements`, `dat-mzb-gridprobe`, `dat-mzb-blocksize-survey`, `dat-mzb-light-bindings`, `dat-mzb-maplist`, `dat-mzb-rendertype`, `dat-placement-format-survey`, `dat-placement-fulldump`, `dat-placement-match`
- **MMB (models)**: `dat-mmb-probe`, `dat-mmb-aabb`, `dat-mmb-index`, `dat-mmb-walk`, `dat-mmb-stripdump`, `dat-mmb-strip-survey`, `dat-mmb-tag-survey`, `dat-mmb-survey`, `dat-mmb-dup-names`, `dat-mmb-overbright`, `dat-mmb-oor-survey`, `dat-mmb-unplaced-survey`, `dat-mmb-variant-match`, `dat-mmb-rawname`, `dat-global-mmb-scan`
- **Textures/images**: `dat-img-probe`, `dat-sheet-texture`, `dat-spritesheet-probe`, `dat-d3m-texture`, `dat-d3m-texture-survey`, `dat-sky-alpha-histogram`, `dat-sky-recon`, `dat-water-probe`
- **Actors/skeletons/effects**: `dat-sk2-decode/enumerate/survey`, `dat-skel-renderprops`, `dat-vos2-bones`, `vos2-dump`, `dat-particle-attach`, `dat-celestial-probe`, `dat-cloud-probe`, `dat-weather-indoors`
- **Zone services**: `dat-zone-pointlights`, `dat-scan-pointlights`, `dat-scan-lightpos`, `dat-lamp-near-light`, `dat-scan-sounds`, `dat-fishing-terrain-probe`, `dat-zone-prefix`, `dat-zone-string-grep`, `dat-action-schedule`, `dat-routine-stages`, `dat-scan-generators`, `dat-npc-name`, `dat-npc-name-survey`, `npc-survey`, `dat-ui-frames-survey`, `dat-ui-usgaiji-survey`, `dat-find-tba`, `dat-mo2-probe`

These replaced the old `Release/*_probe.exe` CMake targets: same jobs (chunk census, placement
matrix checks, texture hit-rate, MMB parse diffs), now exercising the *actual* production
parsers instead of parallel C++ copies.

### Retained C++ probes (`cow_tools/*.cpp`)

Kept as reference implementations / quick cross-checks; standalone (compile ad hoc, not in the
cargo build): `zonevis_probe.cpp` (scene census line + texture hit rate), `ximesh_probe.cpp`
(ximesh census + placement matrices near an anchor), `spawn_probe.cpp` (netcode: state machine
over a raw s2c capture, blowfish decrypt, sub-0x0A spawn decode), `tt_probe.cpp` (blowfish TT/
key-schedule trace vs Python), `decode_probe.cpp` (frame-decode debug), `rom_scan.cpp`
(4-byte tag census across the whole ROM copy — produced `rom_census.txt`).

## 4. `ffxi_disasm/` — static-analysis scanner suite for `FFXiMain.dll`

Python + capstone scanners over the retail `FFXiMain.dll` (PE32 i386, ImageBase
0x10000000). Read-only analysis of a locally installed binary; nothing here patches or
redistributes anything. Full how-to (setup, run order, gotchas, result-recording
conventions) lives in `Cow_doc/disassmembly_docs/README.md`; the findings they back live in
`Cow_doc/disassmembly_docs/mob_animation.md` (mob pass F1-F58) and `Cow_doc/disassmembly_docs/event_vm.md` (event pass
E1-E20). Every script prints markdown meant to be pasted into the findings docs.

| Tool | What it does |
|---|---|
| `common.py` | Shared plumbing: PE load, `pol1_decode` (the bit-packed LZSS that unpacks `.text`), cached linear capstone sweep of `.text` (first run takes a few minutes; cache in `.cache/`), `KNOWN_RVAS` (runtime-measured anchors mirrored from the findings docs). |
| `p0_modmap.py` | Phase 0 module map: confirms PE32 i386 for every exe/dll, image bases, sections, imports/exports, string density, polboot load-chain evidence, version strings. Records the FFXiMain ImageBase/TimeDateStamp/section table every RVA depends on. |
| `p1_anchors.py` | Phase 1 anchors: maps the known RVAs to sections, dumps vtable slot lists, finds the constructors (instructions that install each vtable VA), the `ini`/`init`/… literals in code and data, class-name and `ROM/` strings, and every `mov [reg+0x11E], 0x708` (ActionTimer2 = 1800) site. |
| `p2_handler.py` | Phase 2: scores every heuristic function by ten signals (status/animsub/animation byte loads, `cmp 3`, ActorPointer=0, RenderFlags0 0x200 masks, ActionTimer2 reset, actor ctor, `ini` literal, spawn-flag 0x04 masking); prints top candidates with hit sites, callers, and full disassembly of the top three. |
| `p7_event_vm.py` | Event-VM pass: pattern-searches every XiEvents byte pattern (wildcards `??`) against the cached `.text` sweep; table of name → hit RVA → heuristic func start → matched bytes. All 20 patterns hit on the current build; a miss is the fallback to immediate anchors. |
| `p8_jumptable.py` | Dumps the `ExecProg` switch jump table (rva 0xBC970, 219 entries, opcodes 0x00–0xDA) as opcode → entry VA → thunk RVA → handler RVA. **Source of `Cow_doc/disassmembly_docs/event_opcode_table.md`**; if the ExecProg pattern misses on a future build, find it by immediate search for the 0x5B band constants (0x7D68/0xBFEF/0xDC19/0xE95B/0x10323) and walk `--to` back to the table. |
| `p9_zone_scene.py` | Lists every DAT whose parsed scheduler routines reference movN / exNN stage names (the zone scene file shape, E14). File ids resolved through VTABLE/FTABLE; corrected the five arithmetic pseudo-ids of the original one-off scan (E16). |
| `probe_tpc_files.py` | Re-runs the E6 Tpc cross-check: resolves the four-band A/B file ids for packages 12 and 20 through VTABLE/FTABLE and lists which of tlk0 / thk1 / kka0 each mapped DAT carries. Read-only against the install (install path is a constant in the script). **Backs `Cow_doc/disassmembly_docs/tpc_package_table.md`.** |
| `scene_dat_parse.py` | Parses zone scene DATs (scheduler routines, stage names) for the p9/probe workflows. |
| `dat_routines.py` | Shared DAT/scheduler-routine parsing used by the event-VM tools. |
| `assemble_event_evidence.py` | Rebuilds the raw evidence appendix (`Cow_doc/disassmembly_docs/event_evidence.md`) from the raw dumps in `out3/` (verified byte-identical on 2026-09-11, including the E16 correction block in section I.2). Extend its section lists when adding new dumps. |
| `xref.py` | Cross-reference: `--to 0xRVA` (callers), `--from 0xRVA` (callees), `--imm 0x…` (who uses an immediate / on-disk VA / fourcc), `--disp 0x11E --size 2` (who touches a displacement), `--tree 0xRVA --depth N` (caller tree). |
| `disasm.py` | Disassembly: `--func 0xRVA` (whole heuristic function, annotated), `--rva/--len`, `--va 0x04DF0F40` (convert a wormwatch runtime VA, base 0x04AC0000), `--bytes 0x32BB38 --len 0x100` (hex/dword dump of vtables/tables). Annotations: `; VA of <known vtable>`, `; 'ini1'` for fourcc immediates, `; ent.ActionTimer2?` / `; pkt body status?` for plan offsets. |
| `requirements.txt` | `pip install -r requirements.txt` (pefile, capstone). |

## 5. Live-stack verification (`dev-live/`)

The LSB Docker stack is the test bed — see `Cow_doc/LSB_Docker.md` for the full
bring-up/runbook.

| Tool | What it does | Usage |
|---|---|---|
| `udp-probe.ps1` | Host-side UDP health check: round-trip echo against `cow-udp-probe` (19475/udp) proves Docker Desktop's published-UDP return path; send-only ping to `cow-map` (54230/udp), delivery confirmed server-side. Run this before blaming kuluu for silent map traffic. | `powershell -NoProfile -File dev-live/udp-probe.ps1` |
| `udp-diag-elevated.ps1` | Elevated diagnostics variant (route/firewall/netstat inspection) when the basic probe fails. | run as admin |
| DB one-liners | Char ground truth, `zone_settings` loopback sanity — in `Cow_doc/LSB_Docker.md` §bring-up. | `docker exec cow-db mariadb …` |

## 6. Agent / MCP tooling

| Tool | What it does | Notes |
|---|---|---|
| `kuluu-mcp/` | MCP server exposing a **live game session** to agents: login/char-select against the local LSB stack, movement, targeting, chat, auction/search, delivery box, goal store, debug control, attach-to-running-client mode. Wired in `.mcp.json` as two servers: `ffxi` (fresh login via `FFXI_USER/PASS/CHAR`) and `ffxi-attach` (`FFXI_ATTACH=auto`, grabs an already-running client). Both default to `FFXI_SERVER=127.0.0.1` on the published ports (54231/54230/54001). | `cargo run --release -p kuluu-mcp` (that's what the MCP config launches). This is how the agent skills in `.agents/skills/` (retail-observe, verify, …) exercise the client end-to-end. |
| `lsb-scrape/` | Build-time helpers that scrape the vendored LSB source (`vendor/server`) — SQL schema dumps, lua enum tables, C++ packet headers — into compile-time Rust tables. Only linked from `build.rs` files, never a runtime dep. | keep in sync when bumping the LSB pin |

## 7. Repo ops

- `scripts/checks.sh` — pre-push/CI gate suite; `scripts/cargo-guard.sh` — workspace guard rails;
  `scripts/target-hygiene.sh` — `target/` pruning (it gets huge).
- `scripts/beads-github-sync.sh` / `beads-github-publish.py` — issue tracker sync.
- `scripts/install-hooks.sh`, `install-tools.sh` — dev-machine setup.
- `xtask/` — `cargo xtask` entry point for repeated workspace chores.
- `play_cowland.bat` — double-click launch of `kuluu.exe --server 127.0.0.1 play` with
  `FFXI_MAP_LOCAL_PORT=47500` pinned (the DNAT target — must match `CLIENT_PORT` in the compose).

## 8. Provenance / migration notes

- Old `tools/` → `cow_tools/` (Python unchanged; C++ probes retained, no longer CMake-built).
- Old `probe/` evidence artifacts → `Archived_cowengine/probe/` (contact sheets, palettes,
  C++-vs-Python parse dumps, `altana_zones.csv`, `std_palette_final.json`).
- Old `data/roms/` tree → resolved live through `vendor/game-files` (symlink to the retail
  install); `data/ximeshes/` → the `dev_cow_ximeshes` Docker volume.
- Netcode golden captures: `cow_tools/packet-capture/` (proxy logger for golden captures + replay).
- Planned/empty: `cow_tools/arc-dump/` (.arc unpacker recon), `cow_tools/smd2glb/` (SMD→glTF exporter).

# cow_ffxi_disassembly

Research on the retail **FINAL FANTASY XI** client (`FFXiMain.dll`): static
disassembly passes extracting how the real client drives movement, camera,
animation, target tracking, cutscene events, and UI — so the kuluu remake can
be brought to retail parity ("retail is king, dll is king").

Start with [summary.md](summary.md): the cross-pass synthesis (what is
verified, what is believed, what is still open).

## Target binary

`FFXiMain.dll` from the retail client install (SquareEnix, retail-2026-09).
All game logic lives in this DLL; server packets only set flags that the
client animates.

Two builds were dissected (RVAs are **build-specific**):

| TDS | Build | Passes |
|---|---|---|
| 0x6A995428 | retail-2026-09 (current install, md5 fb7464073c06489268fdd9215c3e5313) | M, T, J; E cluster re-anchored 2026-10-02 (dispatch 0xBC285, jtable 0xBC960, 219 entries — event_vm.md) |
| 0x6A7297F5 | older | F, C, E, U |

## Conventions

- **RVA base 0x10000000.** All addresses in the docs are RVAs relative to the
  PE ImageBase (0x01000000 for both builds). Runtime VAs seen in logs convert
  as `RVA = VA - runtime_base` (e.g. 0x04AC0000 in one capture session).
- **POL1-packed `.text`.** The DLL ships with `.text` `SizeOfRawData = 0`: the
  machine code is bit-packed LZSS-compressed in a custom `POL1` section
  (rva 0x9FF000) and unpacked at load time by an entry stub at the tail of
  POL1. The tools decode it in memory, so every scan and disassembly in the
  docs is against the *decoded* code, read from the on-disk PE.
- **Evidence tiers.** Findings are tagged by how solid they are:
  - `[V]` / `[local]` — byte-verified in the local DLL (or a local DAT dump);
    a pass + finding id is cited.
  - `[I]` — inference from verified parts.
  - `[O]` — the user's retail in-game observation (the acceptance bar).
  - `[web]` — web sources (XiClient pseudocode, cexi docs); used only as a
    navigation map for *where to look*, never as ground truth.
- **Citation form for kuluu edits:** `FFXiMain.dll retail-2026-09 RVA 0x...`
  once numbers are extracted and approved.
- **Byte re-read rule (from the M17/M20 incident, 2026-10-02):** every numeric
  claim gets a byte re-read in the build it is claimed for before it lands in a
  doc. Values inherited from XIClient or an earlier build are [web]/[I] until
  re-read. The session_out/ zips make this cheap — use them.

## Binary facts (TDS 0x6A995428)

- **No RTTI** — compiled with /GR-; the only typeinfo-ish strings are CRT
  exception names. The CXi*/CYy*/CMo* class names exist as allocator/debug tag
  strings only (113 extracted: `session_out/ffximain_tables_v0.zip`,
  `tables_classnames.csv`).
- **Packer** — the POL1 LZSS above, independently re-derived from the entry
  stub (flag byte MSB-first, 12-bit offset / 4-bit len+3, off==0 ends) and
  matched to `common.py`. The static unpacker (`session_out/` `unpack.py`)
  produces `FFXiMain.unpacked.dll` (raw==virtual, real OEP 0x31672F), which
  loads into any tool without POL1 handling.
- **Leaked source paths** (96, `tables_src_paths.txt`): 89 dancer engine
  (`C:\dev\dancer\modules\sq*`) = C engine layer, 5 FFXi_Win game code
  (`D:\build0001\FFXi_Win\`) = C++ game layer, 2 pol.

## Passes (docs/)

| Pass | Doc | Subject |
|---|---|---|
| M | [docs/movement.md](docs/movement.md) | The local-player walker: circle-walk, speed law, facing, Q/E, camera re-anchor |
| C | [docs/camera.md](docs/camera.md) | Event camera control: camera manager, look-at basis, DEFCAMERA |
| F | [docs/mob_animation.md](docs/mob_animation.md) | The animation driver: 0x0E/0x28 → RenderFlags → actor → routine → stage stream |
| T | [docs/target_track.md](docs/target_track.md) | Target acquisition and target-track steering |
| J | [docs/joint.md](docs/joint.md) | The skeleton joint layer: per-joint velocity-curve integrator |
| E | [docs/event_vm.md](docs/event_vm.md) | The cutscene event VM (opcodes, waits, camera/UI interplay) |
| U | [docs/ui.md](docs/ui.md) | Event UI/HUD and dialog control |

Supporting material: [event_evidence.md](docs/event_evidence.md) (raw evidence
dumps for the E pass), [event_opcode_table.md](docs/event_opcode_table.md),
[mob_evidence_1..3](docs/mob_evidence_1_modmap_anchors.md) (F-pass evidence),
[tpc_package_table.md](docs/tpc_package_table.md).

## Tools

Python scanners over the on-disk PE (decoded in memory).
Requires: `pip install pefile capstone`.

- `common.py` — shared core: `Image` (PE + POL1 decode + byte scans),
  `sweep_text` (whole-image instruction sweep with pickle cache),
  `pol1_decode`, `KNOWN_RVAS` anchors.
- `disasm.py`, `xref.py` — disassemble an RVA range / find xrefs to an RVA.
- `p0_modmap.py` … `p11_pkt_tables.py` — per-pass scanners (module map,
  anchors, the 0x0E handler, gates, event VM, jump tables, zone scenes,
  combat tags, packet tables).
- `dat_routines.py`, `ffxi_dat_find.py`, `scene_dat_parse.py`,
  `probe_tpc_files.py`, `assemble_event_evidence.py` — model/scene DAT and
  TPC package tooling.
- `session_out/` — the 2026-10-02 cloud-session artifact zips (ffximain_tables_v0,
  ffximain_claims_v1, ffximain_headless_v1): unpacker + tables, claims CSV +
  corrections, labels/functions/decomp for the current build. Inputs to the
  passes — vendored, never regenerated.

## What is NOT here

- The retail client itself (DLLs, DATs) — never committed.
- Credentials/tokens — none present; the tree was scanned before pushing.
- `__pycache__/` and the sweep pickle cache (`.cache/`) — regenerable.
- Local raw dumps the docs reference (`out3/*`, `out4/d_*.md`,
  `research/XiEvents/...`) — those stay local.
- Note: the docs quote local install paths (e.g. `C:\PhoenixXI\...`) in
  prose; they are machine references, not secrets.

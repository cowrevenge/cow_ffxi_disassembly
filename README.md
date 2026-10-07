# FFXI client research vault (FFXiMain.dll)

The full disassembly/reverse-engineering corpus for the retail build. Map of every
folder and what lives where: **[START_HERE.txt](START_HERE.txt)** — read that first.

Research on the retail **FINAL FANTASY XI** client (`FFXiMain.dll`): static
disassembly passes extracting how the real client drives movement, camera,
animation, target tracking, cutscene events, and UI — so the kuluu remake can
be brought to retail parity ("retail is king, dll is king").

Start with [Disassembly_Docs/summary.md](Disassembly_Docs/summary.md): the cross-pass
synthesis (what is verified, what is believed, what is still open).

## Layout (2026-10-08 reorg)

| Folder | Contents |
|---|---|
| `Disassembly_Docs/` | All DLL/DAT research docs: pass docs (movement, camera, joint…), the event/cutscene (`cs_docs/`) and dated round-report (`reports/`) subfolders |
| `Disassembly_Tools/` | Python scanners over the DLL + DATs (canonical suite), `census/`, `probes/`, `artifacts/`, `.cache/` |
| `General_Tools/` | Non-DLL tooling: texture/mesh converters, zone-map tools, vendor data, Ashita module examples |
| `Headless/` | Headless test-bed docs + the stage-texture HD test script (drives `Extracted_Dats/`) |
| `Extracted_Dats/` | 18 GB local DAT extraction — **never committed**, see `.gitignore` |
| `General_Docs/` | Non-DLL working documents (tool inventory etc.) |

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
  re-read. The artifact zip under `Disassembly_Tools/artifacts/` makes this cheap — use them.

## Binary facts (TDS 0x6A995428)

- **No RTTI** — compiled with /GR-; the only typeinfo-ish strings are CRT
  exception names. The CXi*/CYy*/CMo* class names exist as allocator/debug tag
  strings only (113 extracted: `Disassembly_Tools/artifacts/ffximain_tables_v0.zip`,
  `tables_classnames.csv`).
- **Packer** — the POL1 LZSS above, independently re-derived from the entry
  stub (flag byte MSB-first, 12-bit offset / 4-bit len+3, off==0 ends) and
  matched to `common.py`. The static unpacker (`Disassembly_Tools/artifacts/ffximain_tables_v0.zip` (contains `unpack.py`))
  produces `FFXiMain.unpacked.dll` (raw==virtual, real OEP 0x31672F), which
  loads into any tool without POL1 handling.
- **Leaked source paths** (96, `tables_src_paths.txt`): 89 dancer engine
  (`C:\dev\dancer\modules\sq*`) = C engine layer, 5 FFXi_Win game code
  (`D:\build0001\FFXi_Win\`) = C++ game layer, 2 pol.

## Passes (Disassembly_Docs/)

| Pass | Doc | Subject |
|---|---|---|
| M | [docs/movement.md](Disassembly_Docs/movement.md) | The local-player walker: circle-walk, speed law, facing, Q/E, camera re-anchor |
| C | [docs/camera.md](Disassembly_Docs/camera.md) | Event camera control: camera manager, look-at basis, DEFCAMERA |
| F | [docs/mob_animation.md](Disassembly_Docs/mob_animation.md) | The animation driver: 0x0E/0x28 → RenderFlags → actor → routine → stage stream |
| T | [docs/target_track.md](Disassembly_Docs/target_track.md) | Target acquisition and target-track steering |
| J | [docs/joint.md](Disassembly_Docs/joint.md) | The skeleton joint layer: per-joint velocity-curve integrator |
| D | [docs/drivetask.md](Disassembly_Docs/drivetask.md) | The **DriveTask** overlay layer (`CMoLockLookAtDriveTask`, `CMoActorRotationDriveTask`): how an actor is *driven* to look/turn, plus the `dancer` module map and Square's class-descriptor format |
| E | [docs/event_vm.md](Disassembly_Docs/event_vm.md) | The cutscene event VM (opcodes, waits, camera/UI interplay) |
| U | [docs/ui.md](Disassembly_Docs/ui.md) | Event UI/HUD and dialog control |

| — | [docs/dancer_engine.md](Disassembly_Docs/dancer_engine.md) | **External ingest** (tier `[web]`): WGINC/DancingMad @ 4243c7e — the `dancer` module census, class map and pose/skinning leads, each tagged with whether we verified it in our build; plus our oracle list (PS2 DWARF etc.) |

Supporting material: [event_evidence.md](Disassembly_Docs/event_evidence.md) (raw evidence
dumps for the E pass), [event_opcode_table.md](Disassembly_Docs/event_opcode_table.md),
[mob_evidence_1..3](Disassembly_Docs/mob_evidence_1_modmap_anchors.md) (F-pass evidence),
[tpc_package_table.md](Disassembly_Docs/tpc_package_table.md).

## Tools

Python scanners over the on-disk PE (decoded in memory).
Requires: `pip install pefile capstone`.

- `common.py` — shared core: `Image` (PE + POL1 decode + byte scans),
  `sweep_text` (whole-image instruction sweep with pickle cache),
  `pol1_decode`, `KNOWN_RVAS` anchors.
- `disasm.py`, `xref.py` — disassemble an RVA range / find xrefs to an RVA.
- `espmap.py` — resolve `[esp+N]` operands to frame-stable slots (`f+0x…`=arg, `f-0x…`=local), applying each direct call’s `ret N`; MSVC addresses locals through a moving esp, so argument identities drift when pushes are counted by eye.
- `p0_modmap.py` … `p11_pkt_tables.py` — per-pass scanners (module map,
  anchors, the 0x0E handler, gates, event VM, jump tables, zone scenes,
  combat tags, packet tables).
- `dat_routines.py`, `ffxi_dat_find.py`, `scene_dat_parse.py`,
  `probe_tpc_files.py`, `assemble_event_evidence.py` — model/scene DAT and
  TPC package tooling.
- `Disassembly_Tools/census/mask_census.py` — census of the `fnstsw ax` → `test ah,imm8` idioms over `.text`
  (the x87 flag-test ground truth used by [docs/joint.md](Disassembly_Docs/joint.md) §8a).
- `Disassembly_Tools/census/rtti_graph.py`, `Disassembly_Tools/census/find_vtbl2.py` — parse Square's class descriptors
  (`{name,size,parent}`) and locate a class's vtables via its RTTI accessor thunk.
- `Disassembly_Tools/census/dt_consts2.py`, `Disassembly_Tools/census/who_makes_tasks.py` — constant/sink scan over a code range and
  group of `.text` references to a table range (the D pass evidence).
- `Disassembly_Tools/census/srcpaths2.py`, `Disassembly_Tools/census/our_modules.py` — dump / tally the embedded `C:\dev\dancer\…`
  build paths (our own module census: 16 modules, 84 source-file paths).
- `Disassembly_Tools/census/xcheck_dmad.py` — check that a list of class names exists in our descriptor table
  (used to verify every DancingMad name before repeating it).
- **Gotcha for any new scanner:** in this unpacked image *file offset == RVA*; do not add
  ImageBase when indexing the buffer, and always disassemble with `skipdata=True`.
- `Disassembly_Tools/artifacts/` — the 2026-10-02 cloud-session artifact zip
  (`ffximain_tables_v0.zip`; the claims/headless zips named in older docs are not
  in this local copy): unpacker + tables, claims CSV +
  corrections, labels/functions/decomp for the current build. Inputs to the
  passes — vendored, never regenerated.

## What is NOT here

- The retail client itself (DLLs, DATs) — never committed.
- Credentials/tokens — none present; the tree was scanned before pushing.
- `__pycache__/` and the sweep pickle cache (`.cache/`) — regenerable.
- Local raw dumps the docs reference (`out3/*`, `out4/d_*.md`,
  `research/XiEvents/...`) — those stay local.
- The old `legacy_ffxi_disasm/` snapshot of the tool suite (Sep 8 – early Oct) and its
  run outputs — deleted locally 2026-10-08 as superseded garbage; it was never committed.
- `General_Tools/ashita_module_examples/{xiui,bovineFH,bovineBattle}/` — local clones of
  their own repos (`CowXIUI`, `bovinefh`, `bovinebattle`); gitignored so this vault does not
  fork them. The rest of the examples (plain dirs + zips) are committed.
- Note: the docs quote local install paths (e.g. `C:\PhoenixXI\...`) in
  prose; they are machine references, not secrets.

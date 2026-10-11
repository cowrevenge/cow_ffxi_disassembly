# Matching infrastructure plan (phase 2)

What has to exist before byte matching means anything. Ordered by
dependency. Nothing here is built yet; this is the work list.

## 1. Pin the exact compiler

MSVC6 is verified. Still needed:

- exact service pack / `cl.exe` build (check for a Rich header in the
  unpacked PE; if present it gives tool build IDs directly)
- optimization flags per TU (`/O1` vs `/O2`, `/Ob`, `/Oy`, `/GX`, `/Gy`,
  calling convention defaults). Derive from prologues, frame pointer use,
  inlining patterns and EH frames, not guesses.
- C vs C++ front end per TU (dancer = C, FFXi_Win = C++)

Record findings in a `compiler.md` with byte evidence. Until this is done,
no function is marked exact.

## 2. Run the toolchain headless

MSVC6 under wibo (github.com/decompals/wibo) on Linux, or natively on
Windows. Wrap it in one build entry point (ninja or a Python driver) so an
agent never invokes `cl.exe` by hand.

## 3. Splitter

From `FFXiMain.unpacked.dll` (already produced by `unpack.py`):

- a `symbols.json` with every known function/data symbol: rva, size, name,
  `static` flag, TU
- split target code into per-TU reference objects or asm
- TU boundaries from the 96 leaked source paths plus function ordering in
  `.text` (MSVC6 links TUs contiguously in obj order)
- get storage class right per symbol. Halo lost time on statics defaulting
  to external.

## 4. Comparator

- objdiff config pointing reference objects at rebuilt objects
- a strict semantic comparator: padded bytes, normalized bytes, relocations,
  ABI. This is what decides `exact`, not objdiff's percentage.
- `config/semantic_matches.json` allowlist for class E, re-verified on every
  progress run and failing closed if anything changed

## 5. Progress and ledger

- `progress.py`: exact / credited / fuzzy / parked counts and bytes, per TU
  and total
- updates `park_ledger.csv` status columns from comparator results

## 6. Review tooling

- `fake_match_scan.py`: lexical leads for `source_credibility.md` smells
- reuse `espmap.py` for frame-slot reasoning during matching

## Seed TUs

Start where the research passes already pinned structure, so the first
matches validate the toolchain rather than fight it:

1. small leaf functions inside a well-mapped dancer module
2. event VM opcode handlers (219-entry jump table, many similar shapes)
3. movement / target-track helpers from passes M and T

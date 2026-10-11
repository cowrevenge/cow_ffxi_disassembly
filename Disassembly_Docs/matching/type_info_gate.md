# External type-information gate

Extends the existing evidence tiers (`[V]`, `[I]`, `[O]`, `[web]`) to the
matching phase.

## Hypothesis generators only

These sources may suggest names, struct shapes, enums and function
boundaries. None of them is ground truth for retail-2026-09:

- XiClient pseudocode, cexi docs
- WGINC/DancingMad (`dancer_engine.md`)
- PS2 editions and their DWARF
- the older build (TDS 0x6A7297F5)
- kuluu source, XiEvents, any community header

## Admission rule

- Every field offset, enum value, constant or function signature that enters
  a trusted header needs a byte proof in retail-2026-09, cited as
  `FFXiMain.dll retail-2026-09 RVA 0x...`. Same byte re-read rule as the
  research docs (M17/M20 incident).
- Unproven spans stay named `reserved_XX` / `unknown_XX` and are documented
  as such. Nothing enters a header because it compiles or looks right.
- Class names come from Square's descriptor table (`{name,size,parent}`) or
  the allocator tag strings. Descriptor `size` is a hard check on any struct
  definition: if `sizeof` disagrees, the struct is wrong.

## What we have instead of a PDB

Halo leans on PDBs from later builds. We have none and no RTTI, so these
carry the load:

- class descriptor table and vtable locations (`census/rtti_graph.py`,
  `census/find_vtbl2.py`)
- 96 leaked source paths: translation-unit boundaries and file names
- allocator/debug tag strings
- `__thiscall` usage to separate C++ methods (FFXi_Win) from C engine
  functions (dancer)

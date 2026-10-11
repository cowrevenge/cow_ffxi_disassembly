# Source-credibility gate

An exact object is necessary evidence, but exact bytes alone do not make a
reconstruction admissible. Retained source must express coherent program
logic that is plausible for Square's original codebase (dancer engine C,
FFXi_Win C++, MSVC6 era).

## Forbidden ways to reach a match

Reject source whose only credible purpose is to steer the compiler into the
target bytes:

- unexplained empty branches or dead blocks
- self-assignments, fixed conditions (`if (1)`, `while (0)` wrappers with no macro origin)
- `volatile`, aliasing tricks, or casts that exist only to change codegen
- synthetic locals or lifetime anchors with no semantic job
- inline `__asm`, `__emit`, or raw byte emission
- `#pragma` optimizer controls, or per-function flag changes
- undefined behaviour of any kind

The only exception is a target-proven original bug (`original_bug_policy.md`).

## Review standard

- Review semantics across all reachable inputs, not just the path that looks
  like the disassembly.
- Unusual topology needs corroboration: retail-2026-09 code/data/relocation
  evidence, a recovered name (class descriptor table, `tables_classnames.csv`,
  leaked source paths), or a credible same-era analogue. DancingMad and PS2
  DWARF can suggest shape; they cannot prove it (`type_info_gate.md`).
- When ordinary, meaningful C does not reach exactness after the bounded
  methodology, keep the best honest fuzzy reconstruction, record the
  residual, and park it. A credible fuzzy function beats a fake exact one.

## Tooling

A `fake_match_scan.py` (to be written, see `infrastructure_plan.md`) gives
lexical leads for the smells above. A finding is not proof of fake source,
and a clean scan is not proof of credibility. Manual semantic review is
still required.

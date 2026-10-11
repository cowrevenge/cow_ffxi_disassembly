# Matching methodology (FFXiMain.dll, MSVC6)

Operational checklist for the matching-decomp phase. It is not permission to
accept approximate code. A function counts as **exact** only with all of:

- padded size and meaningful (non-padding) size equal
- normalized byte hash equal
- relocation count, type, address, target and addend equal
- calling convention / ABI equal
- whole-TU rebuild passes with no regression in sibling functions

Everything else is **fuzzy** and gets no credit, whatever objdiff's percentage says.

Adapted from the Halo CE decomp methodology
(github.com/cybersecurity/halo-ce-universal, docs/matching_methodology.md),
rewritten for our target: retail FFXiMain.dll, MSVC6, no PDB, no RTTI.

Related docs in this folder: `source_credibility.md`, `original_bug_policy.md`,
`complexity_gate.md`, `type_info_gate.md`, `park_ledger.md`,
`infrastructure_plan.md`.

## Triage loop (per function)

Run these in order. Do not skip ahead to register tuning.

1. **Baseline.** Record target padded size, meaningful size, normalized hash,
   relocation table, first differing instruction, and the status of sibling
   functions in the same TU. Write it to the function's ledger row before
   touching source.
2. **Relocations first.** If relocation targets or addresses differ, the C is
   shaped wrong. Recover structure: statement order, branch polarity and
   fall-through, eager vs lazy evaluation, field ownership, static vs extern
   linkage. Do not touch register-sensitive declarations yet.
3. **Integer width.** If the target has operand-size prefixes, partial-register
   ops, or `movsx`/`movzx` boundaries, map every promotion and truncation
   point instruction by instruction. Place casts only where the disassembly
   proves a boundary. This is class B, not a register problem.
4. **x87.** FFXiMain is x87-heavy. Before reshaping float code, check the
   `fnstsw ax` / `test ah,imm8` idiom against
   `Disassembly_Tools/census/mask_census.py` output so comparison polarity
   (`<` vs `>=`, NaN handling) is read from bytes, not guessed. Stack order of
   loads usually reflects source operand order; recover that before anything else.
5. **Register ties.** If instruction structure is identical except registers,
   find a hardware-forced anchor first:
   - `rep movs` / `rep stos` force ESI, EDI, ECX
   - variable shifts force CL / ECX
   - `mul` / `div` / `idiv` force EAX / EDX
   - `__thiscall` forces ECX for `this`; callee-saved EBX/ESI/EDI/EBP spills
     show which locals live longest
   Solve the forced-register function first and propagate outward.
6. **Private helpers.** For static helpers in the same TU, make the callers
   exact first, then the helper. Never tune a helper in isolation.
7. **Five-shape stop rule.** After five evidence-based source shapes, if only
   an interchangeable register or a dependency-free instruction swap remains,
   stop. Park it (`park_ledger.md`) and move on. Do not perturb other exact
   code in the TU chasing it.
8. **Check the ledger before assigning work.** A function already credited in
   the semantic allowlist must not be reimplemented because a fuzzy tool
   shows a percentage below 100.
9. **Preserve donor shape.** When a macro or expression is known from an exact
   neighbour, copy its lvalue topology (which member is assigned, in what
   order, read back how) before permuting commutative terms or adding temps.
   Mathematically equal forms can compile differently.

## Blocker classes

Every non-exact function gets exactly one class label in the ledger.

| Class | Name | Meaning | What moves it |
|---|---|---|---|
| A | Source shape | C is not shaped like the original | statement order, branch polarity, local lifetime, inlining, linkage, struct ownership |
| B | Width | promotions/truncations differ | casts at disassembly-proven boundaries only |
| C | Register fixed point | same graph and relocs, registers permuted across a TU cluster | forced-register caller anchor, solve outward; else park the cluster together |
| D | Scheduler / lifetime tie | dependency-free instruction swap or spill difference | only source changes justified by surrounding order; else park |
| E | Comparator artifact | machine code exact, object encoding differs (local labels, reloc placeholders) | credit through the semantic comparator allowlist, re-verified every progress run |
| F | Unclassified residual | source is credible but the cause can't be pinned | park as `unclassified`, record positive evidence and what would reopen it; no credit |

Never invent a specific mechanism to avoid writing F.

## What an agent must not do

- Accept fuzzy as exact, or round a match percentage up.
- Use anything forbidden in `source_credibility.md` to force bytes.
- Change compiler flags per function to win a match. Flags are per TU and
  must be justified for the whole TU.
- Edit already-exact functions while working on a neighbour, unless the TU
  rebuild proves they stay exact.
- Pull numbers from XiClient, DancingMad, PS2 builds or an older retail build
  without a byte re-read in retail-2026-09 (`type_info_gate.md`).

# Park ledger

The record of every function that is not exact. This is what a returning
human reads after an unattended run. A function with no ledger row has not
been worked on.

File: `Disassembly_Docs/matching/park_ledger.csv` (template ships alongside).

## Columns

| Column | Content |
|---|---|
| `rva` | target RVA, retail-2026-09 |
| `name` | recovered or placeholder name (`sub_<rva>`) |
| `tu` | translation unit / source path it belongs to |
| `status` | `exact`, `credited_E`, `fuzzy`, `parked`, `in_progress` |
| `class` | A to F from `matching_methodology.md` (blank if exact) |
| `padded_size` | hex |
| `match_pct` | fuzzy tool percentage, informational only |
| `first_diff` | offset and instruction of first difference |
| `shapes_tried` | count, max 5 before parking |
| `evidence` | what is proven, with RVAs |
| `reopen_if` | the specific new evidence that would justify another attempt |
| `commit` | commit that last changed it |

## Rules

- `parked` rows must have `class`, `evidence` and `reopen_if` filled.
- `F` (unclassified) is allowed and honest. Inventing a mechanism to avoid F is not.
- Never delete a row. Status changes in place; history lives in git.
- A parked function is not picked up again unless its `reopen_if` is met.



## F. Leads & observations carried from summary.md §9 tail (split 2026-10-05 — history, with current status tagged)

Status tags as of this split: the **limit/slew/tug hunt** below was closed by §E/§E.8 (authored
`{xlim,ylim,scale}` records in the skeleton chunk + bend bones from reference slots {3,7}; no
J-pass curve-table search remains). The **"steering question"** was answered 2026-10-04: look-at is a
bone mechanic layered by the W-pass controller — not animation curves reacting to target (kuluu_gaps
B4 ruling + rows A1-A6 landed). The sqmoKeyChannel interpolation conflict below is **resolved [V]** in
dancer_engine.md §4a (caller census: all 46+26 evaluator sites sit in the CMo* effect region, zero in
motion channels). What stays open from this block verbatim: nothing S3-specific — it stands as the
record of what we believed mid-dig.

**The head limit/slew/tug — now with a better lead than "somewhere in the curves".** The D pass

found the overlay layer that actually rotates actors toward things (`CMoLockLookAtDriveTask` /

`CMoActorRotationDriveTask`, driven by degree-denominated authored values), **and we now know who

creates them**: interpreter opcode cases **135** and **168** inside `CMoSchedularTask_Interpret`

(`0x57FB0..0x5DFF0`; jump table `.rdata 0x5DC1C`, 196 entries) — [drivetask.md](drivetask.md) §5a.

No float immediates appear in either handler, so the limit / duration / degree magnitudes are

**operands in authored effect-script data**.



**Operand encoding is now known [V] ([drivetask.md](drivetask.md) §5b):** the interpreter's fetcher

`0x1005E590` reads a **signed 16-bit authored integer** from the script record (`[ctx+0x88]+6`), scales

it by `[ctx+0x9C]`, and `0x10311C2C` (`_ftoll`) turns it into an **integer duration**; the rotation task's

target orientation arrives as **three values converted with π/180 (degrees)** while its *start*

orientation is captured live via virtual slot `[obj->vfx+0x1C0]`. Allocation sizes in both handlers

(`push 0x80`, `push 0xA0`) equal the classes' descriptor sizes, and the ctor stores exactly the two

vtables we located (`0x32BAC4` main, `0x32BAA8` at +0x34) — byte-level proof of the D-pass mapping.



**So S3's remaining gap is narrow and honest:** (i) re-derive the ctor arg-slot → field mapping

(I tried and got contradictory readings; recorded as unresolved in drivetask.md §5b — fix by simulating

the handler stack or by pulling member names from PS2 DWARF instead of guessing offsets), then (ii) go

to the authored data side: find the script records that carry opcodes **135/168** and read their

operands. Secondary leads, still open:



1. the head's **6-bit joint index** and its constant table (saturation = limit, velocity = slew);

2. the **per-joint param struct** `{index, scale@+4, scale2@+8}` (the head's `scale`).



**Open conflict worth settling early.** DancingMad reports `sqmoKeyChannel`'s interpolation enum

(`1`=Linear, `2`=Smooth) as *never exercised* in their retail build, while our J pass found two

quadratic "smooth" curve evaluators (`0x547A0`, `0x546F0`) with 46 and 26 call sites. Probable

resolution: motion-channel interpolation ≠ the joint-drive curves J pass saw (matches the J/D layer

split), but **our build needs a caller census to say so**. Until then nobody quotes either claim.



A **separate look-at/aim controller** is not ruled out, but its old lead was bogus: the

"double-fpatan sites" **0x5EA03 / 0x5EF03** are `xor eax, eax` linear-sweep artifacts (J11).

The site worth tracing now is **0x5EA7F..0x5EA93** — `fpatan` of two locals subtracted from an

angle stored at `[obj+0x94]`. Tooling note: always sweep with `skipdata=True`; see §8a of

[joint.md](joint.md) for the x87 ground truth (capstone was never broken).



**The steering question (user, decides the dig):** from retail observation, does the head's

target-tracking look like it is **part of the animation** (the head joint's own curve

reacts to the target) or a **separate aim/look-at layered on top**? The user's new note —

*"new information suggests this is done in the skeleton pieces"* — points to the **J-pass

integrator** (the head joint's curve reacting to the target), so the first concrete step is

**finding the head joint + its curve table** and reading the real limit/slew/tug. Either

way the next step is the same: locate the head joint, then pull its numbers.



**User's head observations to match [O]:**

- The player "looks" at the target until it moves out of the head-turn limit, then **snaps

  back to straight**; the head turns when the target changes.

- The limit may be a max up/down/left/right, **or** the head "ignores after certain values

  and returns 0."

- The body moves with the head **very slightly, L/R** (the tug).



HISTORICAL NOTE: the research-only rule of that pass is retired — kuluu edits now proceed row-by-row per Shane's standing orders (2026-10-05). Citation form for those edits stays `FFXiMain.dll retail-2026-09 RVA 0x...`.

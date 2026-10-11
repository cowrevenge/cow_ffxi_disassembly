# Original-bug policy

The exact build preserves confirmed retail behaviour, including bugs.

Mark a defect only when both the retail-2026-09 machine code and the struct
layout prove it. Use this form:

```c
/* BUG (preserved for exact matching): <target behaviour and evidence,
 *   cite FFXiMain.dll retail-2026-09 RVA 0x...>.
 * A corrected build should <safe replacement>.
 */
```

Rules:

- The safe fix stays disabled in the exact build (guard it behind a
  non-default define such as `FFXI_FIX_BUGS`).
- Do not label suspicious code a bug on a hunch. No byte and layout proof,
  no BUG tag.
- Behaviour the kuluu remake wants to differ on is a kuluu decision, not a
  reason to change the exact build.

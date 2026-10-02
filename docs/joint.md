# FFXI retail client: skeleton joint-angle layer (J pass)

How the retail client drives skeleton joint angles: the per-class **keyframe curve
evaluators**, the **joint dispatch stubs**, and the **joint-angle integrator**
(Euler integration of an angular velocity, wrapped to (−π,π]). This is the layer that
produces the per-joint motion observed as *head follows the target to a limit, settles
straight, torso tugs slightly*.

Findings **J1..** are a sixth pass, distinct from the movement pass (**M**,
[movement.md](movement.md)), mob pass (**F**, [mob_animation.md](mob_animation.md)),
event pass (**E**), camera pass (**C**, [camera.md](camera.md)), and target-track pass
(**T**, [target_track.md](target_track.md)). Conventions (RVA base 0x10000000,
POL1-packed `.text`, evidence tiers) are in [../README.md](../README.md).

Target binary: `FFXiMain.dll`, build TDS **0x6A995428** (2,901,584 bytes, PhoenixXI
install, `client=retail-2026-09`). Every RVA in this document is valid only against
that build.

This pass was cut to answer: *where do the retail head-look limit, reset-to-straight,
head slew, and body-tug live — and are they hardcoded constants or authored data?*
**Headline finding (J6):** in the layers examined (the joint integrator and the
per-entity update), the head/skeleton motion is **data-driven** — an integrator of
authored per-class keyframe velocity curves — and there is **no single hardcoded
HEAD_MAX_TURN_RAD / HEAD_SLEW constant**. The observed limit/slew/reset are properties
of the curve data plus the `dt` integration. A separate look-at/aim controller is not
ruled out (open item).

## 1. Scope

| # | Question | Status |
|---|----------|--------|
| Q1 | What are 0x544D0/0x54500/0x546F0/0x547A0? | Resolved (J1): per-class keyframe curve evaluators |
| Q2 | What does the joint dispatch stub 0x3DF10 do? | Resolved (J2): `angle = curve(table[idx], clock) → ×π → wrap(−π,π]` |
| Q3 | What is 0x3138BA? | Resolved (J3): FPU helper/exception thunk (jmp 0x31DD30); **not** fmod |
| Q4 | How is a joint angle updated? | Resolved (J4): `angle += dt × curve`, then wrap (−π,π] |
| Q5 | What model is that? | Resolved (J5): first-order Euler integration of an angular velocity |
| Q6 | Is the head-look limit a hardcoded constant? | Resolved in the layers examined (J6/J8): NO — data-driven (curves); no FPU const compares in the per-entity update |
| Q7 | What are 0x47BFA8 / 0x65CB14? | Resolved (J7): clock object (dt) / animation clock (curve param) |
| Q8 | What is `[obj+0xE0]`? | Resolved (J9): a **generic** offset (222 sites), not a unique joint slot; the T-pass 13-site census was incomplete |
| Q9 | The head's limit/slew/tug **numbers** | **Open**: in the authored curve data / per-joint param scales / a not-yet-found look-at controller; §9 |

## 2. The keyframe curve evaluators (J1)

**J1 [local].** Four sibling functions evaluate a per-class keyframe curve at a
parameter `t`. The curve table is a pointer to a per-class constant block whose
**+0x30..+0x44** hold the keyframes as a sequence of (x, y) float pairs (point[0] at
+0x30, point[1] at +0x38, point[2] at +0x40, …).

| RVA | shape | behavior |
|-----|-------|----------|
| 0x544D0 | (table, &t, ptr), ret 8 | wrapper: swaps `[table+0x34]` with `ptr`, calls 0x54500, stores result back |
| 0x54500 | thiscall (table, &t), ret 4 | clamp `t`∈[0,1]; walk the (x,y) points; **linear** lerp |
| 0x546F0 | (table, &t, ptr), ret 8 | **smooth** (quadratic) variant; writes `[table+0x34]` |
| 0x547A0 | thiscall (table, &t), ret 4 | **smooth** (quadratic) variant; result on the FPU |

**0x54500 (linear)** — the lerp, verified byte-by-byte:

```c
// FFXiMain.dll retail-2026-09, RVA 0x54500 — EvalCurveLinear
// this = ecx (per-class constant table), arg = &t (in/out, clamped)
float EvalCurveLinear(const float* table, float* t) {
    if (*t > 1.0f)      *t = 1.0f;        // 0x32961C=1.0 (0x54504..0x54519)
    else if (*t < 0.0f) *t = 0.0f;        // 0x3295D8=0.0 (0x54523..0x54534)
    const float* prev = table + 0x30;     // point[0] (0x5450A lea edx,[ecx+0x30])
    const float* cur  = table + 0x38;     // point[1] (0x5450D add ecx,0x38)
    // walk to the segment with prev.x <= *t < cur.x  (0x5453C..0x5456C)
    float u = (*t - prev[0]) / (cur[0] - prev[0]);      // 0x54581..0x5458B
    return prev[1] + u * (cur[1] - prev[1]);            // 0x5458D..0x54595, ret 4
}
```

**0x547A0 / 0x546F0 (smooth)** — the same walk, but the blend is a quadratic
polynomial with the branch selected by a compare of the local parameter `u` against
**0.5** (0x329A08, at 0x547E5 / 0x54695): one branch computes
`2u²·prev.y + (1−u)·cur.y`, the other `2(1−u)²·cur.y + (1−u)·prev.y`.

Caller counts (E8 rel32 scan over decoded `.text`): 0x547A0 = **46**, 0x54500 = **46**,
0x546F0 = **26**, 0x544D0 = **23** — a **generic** mechanism used across the codebase,
not head-specific.

**J1 caveat (open).** The exact quadratic basis of the smooth branches and the
segment-walk boundary conditions depend on the x87 flag-test idiom
`fnstsw ax; test ah, 5; jp/jnp`, which tests the **sticky Inexact bit | C1** (ah bits 0
and 2). The lerp (0x54500) and the "interpolated y at t" behavior are solid; the precise
branch selection under the sticky-flag idiom is marked open.

## 3. The joint dispatch stubs (J2) and the FPU helper (J3)

**J2 [local].** `0x3DF10` (sibling `0x47BB0`) is the per-joint dispatch. Verified
byte-by-byte:

```c
// FFXiMain.dll retail-2026-09, RVA 0x3DF10 — JointAngleFromCurve
// ecx = &JointEntry {obj ptr, type byte, …}; arg = &clock (global 0x65CB14)
float JointAngleFromCurve(const JointEntry* e, const float* clock) {
    if (!e->obj) return 0.0f;                  // 0x3295D8 (0x3DF14 → 0x3DF7E)
    const float* table = *e->obj;              // [obj] = per-class constant table
    float a = (e->type & 0xF)
              ? EvalCurveSmooth(table, clock)  // 0x547A0 (0x3DF27)
              : EvalCurveLinear(table, clock); // 0x54500 (0x3DF35)
    a = FpuHelper(a, /*qword*/ {0.0, 2.0});    // 0x3138BA (0x3DF48); J3
    a *= π;                                    // 0x32A3B8 (0x3DF4D)
    if (a >=  π)  a -= 2π;                     // 0x32A3B0 (0x3DF62)
    if (a <  −π)  a += 2π;                     // 0x32A3B4 (0x3DF75)
    return a;                                  // wrapped to [−π, π)
}
```

Net effect: **`angle = (curve(clock) → helper) × π`, wrapped to (−π, π].**

**J3 [local].** `0x3138BA` is `mov edx, 0x103CFFE0; jmp 0x31DD30`. 0x31DD30 is an
**FPU helper / exception thunk** (spills st(0)/st(1) as qwords, tests global
0x3D3810, dispatches via 0x31AF77 / 0x31AF10 with a code in `edx`). It is **not**
fmod/fprem (the nearby 0x3138C4 entry is a separate fprem-style loop). The helper's
exact numeric transform is marked open; the stub's *behavioral* effect (the phase
normalization before the ×π + wrap) is what matters here.

## 4. The joint-angle integrator (J4, J5)

**J4 [local].** The per-joint update loop (back-edge `jmp 0x4B87E`, a 0x1F8-frame
function spanning ~0x4B87E..0x4CDxx) computes, per joint:

```
joint_index = (param.word >> 13) & 0x3F            // 6-bit (0x4CA72/0x4CA75)
curve  = JointAngleFromCurve(&table[joint_index], clock)   // 0x3DF10 / 0x47BB0
joint[+0xE0] += dt × curve                          // dt = [0x47BFA8].f_0xEB0  (J7)
wrap joint[+0xE0] to (−π, π]                         // 0x32A3B0/B4/B8 (or 0x329D2C/0x329D30)
joint.updated[+0x187] = 1
```

Verified accumulation (two forms, 0x4CA81..0x4CA94 and 0x4CC2A..0x4CC3D):

```
fld  [0x47BFA8_obj + 0xEB0]      ; dt
fmul st(1)                        ; dt × curve
fadd [joint + 0xE0]               ; dt×curve + old angle
fstp [joint + 0xE0]               ; angle = old + dt×curve
```

Three sibling slots are integrated the same way: `[+0xE0]`, `[+0xE4]`, `[+0xE8]`
(the +0xE4/+0xE8 forms at 0x4CDFB, 0x5037F, 0x50399, 0x51659/0x5166E/0x51683, …).

**J5 [local].** Because `dt` (J7) is a per-frame time delta, **this is a first-order
Euler integration of an angular velocity**: the curve supplies a *rate*, and the angle
accumulates `dt × rate` each frame, wrapped to (−π, π]. A joint does **not** snap to a
keyframe position — it *integrates* a rate. This is the structural reason the retail
head "slews" (it is integrated, not snapped) and "settles" (the velocity curve drives it
to where the rate balances).

## 5. The clock (J7)

**J7 [local].** Two globals drive the curves:

- **0x47BFA8** — a clock/timer object. The joint loop reads its `+0xEB0` as the
  integrator `dt` (`mov eax,[0x1047BFA8]; fld [eax+0xEB0]`). The **sole** writer of
  this object's `+0xEB0` is the function at ~0x69F90 (two stores, 0x69FE2 and 0x6A005):

  | field | set to (verified) |
  |-------|-------------------|
  | `+0xEA8` | tick counter (wraps at 0x10) |
  | `+0xEAC` | `Δtick × 0.001` (0x32A22C) |
  | `+0xEB0` | `Δtick×0.001×60.0` (0x69FE2), **then overwritten by `0x14CF0()`** (0x6A005) — the `dt` |
  | `+0xEB4` | `+= Δtick × 0.001 × 60.0` (0x329CE8=60.0) — accumulated time |
  | `+0xEBC` | sub-object pointer |

- **0x65CB14** — the animation clock/progress, passed as the curve parameter at all 12
  joint-dispatch sites (0x4B819, 0x4CDE7, 0x4CE56, 0x4CEE5, 0x4CFA9, 0x4D06D, 0x4D125,
  0x4D1DD, 0x4D282, 0x4D306, 0x4D389, 0x4D40D). Never written via `mov imm` (set by a
  `mov reg`/FPU store elsewhere — open).
- **0x14CF0** (M20 "seconds") returns `[0x4568FC+0x28]` clamped against 1.0 (returns
  either 1.0 or the global) — a time/dt value.

The field layout (+0xEA8/+0xEAC/+0xEB0/+0xEB4/+0xEBC) matches between the 0x69F90 writer
and the joint-loop reader, identifying them as the same object type; that 0x47BFA8 is the
global *instance* the writer is invoked on is a high-confidence inference (the call site
was not traced this pass — open item).

## 6. Headline: data-driven, not a single constant (J6, J8)

**J6 [local].** In the layers examined, the retail head/skeleton motion is produced by
the **integrator (J4/J5) driven by authored per-class keyframe curves (J1)**. Therefore:

- "Head follows the target to a limit" = the velocity curve driving the integrated angle
  up to where it saturates.
- "Resets to straight" = the curve driving the velocity back to 0 (the angle stops
  accumulating / returns).
- "Slight body tug" = the body joint's curve being a small fraction of the head's.
- **There is no single hardcoded HEAD_MAX_TURN_RAD or HEAD_SLEW constant in the joint
  layer or the per-entity update.** The observed limit/slew/reset are properties of the
  authored curve data plus the `dt` integration. kuluu's constant-based model is an
  approximation of this, not a 1:1 mapping onto a retail constant.

**J8 [local].** The per-entity update region (0x8F000..0x93500, F-pass) contains
**zero** FPU compares (`fcom`/`fcomp`/`fcomi`) against absolute `.rdata` constants — so
the head-look limit is **not** a dot-vs-const-of-limit clamp in that region. Consistent
with J6: the limit lives in the curves, not a per-entity dot test.

## 7. Correction: `[obj+0xE0]` is a generic offset (J9)

**J9 [local].** `[reg+0xE0]` is a **generic** offset, not a unique joint-angle slot. A
census of every sweep-parsed memory operand with disp32 `+0xE0` finds **222** accesses
(**28** writes) across many functions — far more than the 13 sites in the T-pass
handoff's byte-scan store census. The T-pass scan matched only a subset of FPU opcode
forms and missed the `fstp`/`fst` (D9 9x / DD 9x) stores. The joint object in the
0x4B87E loop is one user of this offset; unrelated objects elsewhere also have a float
at +0xE0. **Track the joint object, not the offset.** (Same for +0xE4: 244 sites/24
writes; +0xE8: 230 sites/35 writes.)

## 8. Constants (verified, TDS 0x6A995428)

| RVA | value | used for |
|-----|-------|----------|
| 0x32961C | 1.0 | curve clamp upper; 0x14CF0 clamp |
| 0x3295D8 | 0.0 | curve clamp lower; stub null-return |
| 0x32A22C | 0.001 | clock Δtick scale |
| 0x329CE0 / 0x329CE4 / 0x329CE8 / 0x329CEC | 20.0 / 0.25 / 60.0 / 10.0 | clock scales |
| 0x32A3B0 / 0x32A3B4 / 0x32A3B8 | 2π / −π / +π | angle wrap (integrator + stub) |
| 0x329D2C / 0x329D30 | 2π / π | alternate wrap pair (0x4CAxx path) |
| 0x32ABC8 / 0x32ABCC | 0.0 / 2.0 | stub FPU-helper qword pair |
| 0x329A08 | 0.5 | smooth-curve branch switch |
| 0x32A3BC | 0.125 | (T-pass state-2/4 rate; present here too) |

Globals:

| RVA | meaning |
|-----|---------|
| 0x47BFA8 | clock object (+0xEA8 counter, +0xEAC, +0xEB0 = dt, +0xEB4 accum, +0xEBC sub) |
| 0x65CB14 | animation clock/progress (curve parameter) |
| 0x4568FC+0x28 | time scale/delta (read by 0x14CF0) |
| 0x3D3810 | FPU-helper dispatch gate (0x31DD30) |

## 9. Relevance to kuluu + open items

The kuluu constants (`HEAD_MAX_TURN_RAD`, `HEAD_VIEW_CONE_COS`,
`HEAD_SLEW_TAU_FRAMES` in `kuluu-render/src/ffxi_actor_render.rs` ~3241, and the
state-2 body behavior in `kuluu/src/view_native/input.rs`) model the head as a
clamp + exponential slew. The retail model is an **integrator of authored velocity
curves** (J4/J5/J6). **Do not assume the kuluu constants map 1:1 onto retail
constants** — in the layers examined, retail has no such single constants. Any kuluu
change to match retail should either (a) reproduce the integrator + a matching velocity
curve, or (b) keep the constant model and fit it to the observed curve — a decision for
the user. Citation form for those edits: `FFXiMain.dll retail-2026-09 RVA 0x...`.

**Open items (where the actual numbers are):**

- **The head's limit/slew/tug values** are in the **authored per-class keyframe curve
  data** (the (x,y) points of the head's table) and/or the **per-joint param scales**.
  To extract them: identify the head's 6-bit joint index and its constant table, then
  read the curve's saturation (limit), velocity scale (slew), and the body's fraction
  (tug). This requires locating the per-model table data (a `.rdata` table or loaded
  from a DAT) — not yet found.
- **Per-joint param struct** `{word (index at bits 13–18), scale@+4, scale2@+8}`: find
  where the `{index, scale}` entries are authored; the head's `scale` is the prime
  tug/limit factor. Not yet located.
- **A separate look-at/aim controller** (distinct from the animation integrator) is not
  ruled out. The double-fpatan skeleton sites 0x5EA03 and 0x5EF03 have **no direct E8
  callers** (vtable-dispatched or dead) — worth a vtable-slot trace.
- **0x3138BA helper's exact transform** (J3).
- **Smooth-curve basis + branch selection** (J1 caveat) — depends on the `test ah,5`
  x87 idiom (sticky Inexact bit).
- **The per-entity update (0x8F000..0x93500)** was only scanned for FPU const compares
  (none found); a full decode of its target-direction handling is not done.
- **Instance identity** of the 0x69F90 clock writer and the 0x47BFA8 global (J5 note).

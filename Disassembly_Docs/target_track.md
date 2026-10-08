# FFXI retail client: target-track parallel move (T pass)

How the retail client moves and orients the local player while a **target** exists:
the "big function" at **0xA7B80** (target acquisition, auto-run re-aim, free path),
the state classifier **0xA80D0** (±45° bracket, dot tests, state 0/1/3), and the
ease-rate selector **0xA8000** (0.125 / 2·f·(1/60) / element-wise-square decay).
Findings **T1..** are a fifth pass, distinct from the movement pass (**M**,
[movement.md](movement.md)), mob pass (**F**, [mob_animation.md](mob_animation.md)),
event pass (**E**), and camera pass (**C**, [camera.md](camera.md)). Conventions
(RVA base 0x10000000, POL1-packed `.text`, evidence tiers) are in [../README.md](../README.md).

Target binary: `FFXiMain.dll`, build TDS **0x6A995428** (2,901,584 bytes, PhoenixXI
install, `client=retail-2026-09`). Every RVA in this document is valid only against
that build. The previous M/F/C passes were cut against TDS 0x6A7297F5; the M-pass
RVAs that this document reuses (0xA65CB, 0x15250, 0x14CF0, 0x27530, ...) were
re-verified at 0x6A995428 during this pass.

This pass was cut to answer: *what does retail do with the player's body when a
target is present — the "slight body tug", the look limit, and the ease rates?*
The full writeup of 0xA7B80 + 0xA80D0 + 0xA8000 is below.

**CORRECTION 2026-10-08 (supersedes an earlier "final verification" claim in this
document).** An earlier revision declared the target-state machinery inert because its
tests were read as gated on a FPU **overflow flag**. That was wrong at the bit level:
the byte pattern `fnstsw ax; and eax, 0x100` tests x87 status **bit 8 = C0**, which per
Intel's published comparison table (FCOM/FUCOM: greater→C3=0,C2=0,C0=0; less→C0=1;
equal→C3=1; unordered→all set) is the **less-than** condition — and comparisons *do*
set it. The classifier 0xA80D0 therefore returns its full bucket set {0,1,2,3,4} (§3,
corrected truth table), `call 0xA7EF9 mov [esi+0x598], eax` writes those buckets to the
state field (T14 corrected), and the motion chooser names `mvl `/`mvb `/`mvr `
(0xC8DAF/0xC8DB7/0xC8DBF gated on state ∈ {2,3,4}) whenever free-run is off — which
every lock handler sets (0xC5440/0xC54C0). **Side-step clips are live while locked.**
The flip latch 0xA7EF6..0xA7F2D (§K2 of the locomotion K-pass doc) inserts straight-
gait frames on a direct L/R reversal (`[esi+0x5b1]=2` countdown when consecutive
buckets form {2↔4}; each pass with the byte > 0 stores literal 1 into +0x598 and
decrees). kuluu landed this law in commit `f1bfd06` (ffxi-actor SideStepFlipLatch), which
also deleted its torso-reconciliation layers — retail has none.

## 1. Scope

| # | Question | Status |
|---|----------|--------|
| Q1 | What is the "big function" the M-pass left at 0xA7B80? | Resolved (T1): target-track parallel move, 2 callers |
| Q2 | What does 0xA80D0 compute and return? | **Corrected 2026-10-08:** bucket classifier on heading/±45° dot signs; full result set {0..4} live (earlier "overflow-gated {0,1}" was a bit misread — see header correction) |
| Q3 | What are the body-tug / ease rates? | Resolved (T3): 0.125 (st 2/4), 2·vt(0x1B0)·1/60 (st 3) — **reachable** for locked travel (states 2/3/4 are live; see header correction) |
| Q4 | What is the ±0.78517 rad pair? | Resolved (T4): immediate constants, ≈44.99°, the bracket half-angle |
| Q5 | Which predicates gate the 0.125 rate? | Resolved (T5): 0x84350/0x84370 mount siblings on [this+0x70] |
| Q6 | What is 0xAAEF0? | Resolved (T6): 0.8·horizontal-distance getter (vtbl +0x1C8, tag 0x2C) |
| Q7 | How is the target chosen? | Resolved (T7): LockedTarget(*g_pInputMng) or *0x487F58 entity slot |
| Q8 | What is the facing law in this path? | Resolved (T8): −atan2(axes.y, axes.x) for st 2/4; −atan2(−n.x, −n.z) otherwise |
| Q9 | Where do the M-pass vector helpers really stand? | Resolved (T9): corrected table in §6 (several M-table rows were wrong) |
| Q10 | Is the 16-step compass helper live? | Resolved (T10): dead in this build (0 callers) |
| Q11 | Exact provenance of every frame slot in 0xA7B80 | **Open**: shared-frame convention, §9 |
| Q12 | Head-look joint limit + reset-to-straight | **Open**: NOT in this function's state machine (T14/T15); live mechanism is in the skeleton/joint layer; §9 |
| Q13 | What is the 0x487F98 slot and is the auto-run angle in degrees? | Resolved (T13): read-only, zero in this build; no degrees conversion exists |
| Q14 | Who writes state_0x598, and can 2/3/4 occur in this build? | **Corrected 2026-10-08:** the classifier-return writers (via 0xA6EE4→0xA6EE9 and 0xA7EF1→0xA7EF9) store {0..4}; latch countdown stores literal 1 at 0xA7F23. Full range reachable |
| Q15 | Is the ±44.99° bracket live anywhere in this build? | **Corrected 2026-10-08:** yes — the "overflow" gating was a misread of C0 (bit 8); classifier returns {0..4} per §3 truth table, chooser consumes it while free-run is off |

## 2. The big function 0xA7B80 (T1)

**T1 [local].** `0xA7B80..0xA7FE3` (thiscall + one documented stack argument,
`ret 4`). Callers (verified by sweep scan):

| Caller | Context |
|--------|---------|
| 0xA6D19 | control fn 0xA65CB, parallel-move branch (free-run off **or** both mount siblings fail) |
| 0xA76D0 | the auto-run steering fn (~0xA7600..0xA7795), after its own auto-run re-aim |

**Q11 resolved — there is no second/hidden argument [V].** ParallelMoveTarget
takes the single documented stack argument `&dir` (the caller's 3f movement
vector; `ret 4`). The pointer earlier docs called `axes` (`mov ebp, [esp+0x9C]`,
RVA 0xA7C69 and 0xA7DFE) resolves — by full esp-fixpoint over this function with
callee-cleanup widths resolved through the vtable tables — to **entry-relative
slot +4 = arg-1 itself**: prologue lands esp_c at −0x90 (sub 0x88 + push esi/edi),
and both branches execute `push ebx; push ebp` (0xA7BBB/0xA7BBC) before the load,
making esp_c −0x98, so [esp+0x9C] = E_c + 4. The two loads are also the ONLY
EBP-defining instructions in the whole function. `ebp` therefore aliases
`&dir`: the three "axes" floats {+0,+4,+8} **are the movement vector**
(the gate reads dir.x/dir.z against 0, 0xA7C74..0xA7C92; free path rotates by
−dir.z/len, 0xA7E09..0xA7E10; nudge scales along n by dir.x, 0xA7E71..0xA7EAA;
`EaseInputAxes` eases dir in place). Callers fully own dir before the call —
auto-run site writes its basis into the dir local immediately pre-call
(`lea eax,[esp+0x18]`, stores at [esp+0x1C]=…/[esp+0x24]=1.0f, 0xA76A7..0xA76CC).
*Retractions superseded by this pass:* (a) the original §2 "3rd word of the call
frame / shared-frame convention" story; (b) the intermediate revision's "3-float
vector slot" correction — both were artifacts of mis-mapping branch-local esp
drift. Solver + producer trace: `C:/tmp/d1_pass/frame_final.py` (output logged in session).

### 2.1 Reconstruction (open-source form)

```c
// FFXiMain.dll retail-2026-09 (TDS 0x6A995428)
// RVA 0xA7B80..0xA7FE3 — ParallelMoveTarget
// thiscall: this = ecx (player actor)
// args:     [stack 1] = &dir   (the only argument; 3f movement vector, caller frame)
// NOTE (frame-solver pass): every `axes` below means *dir through the re-loaded
// arg pointer* (ebp = &dir, see §2 resolution) — gate/rotate/nudge/ease all act on
// the caller's movement vector itself.
// ret 4.

// Frame slots used (offsets from this function's esp after prologue):
//   [esp+0x10] out.x      [esp+0x14] out.y       [esp+0x1C] delta_z
//   [esp+0x20] az         [esp+0x24] dist_sum
//   [esp+0x2C..0x34] n    (normalized movement vector, 3f)
//   [esp+0x34] n.z read   [esp+0x38..] scratch
//   [esp+0x44..0x84] 4x4 matrix scratch (built at +0x48/+0x4C views)
//   [esp+0x58..0x60] matrix scratch 2
// Provenance caveat: out.x/out.y are seeded from the target delta; the out.z slot
// ([esp+0x18]) and the n source slot ([esp+0x2C]) are never explicitly stored by
// this function in every path — they inherit caller-frame contents. See §9.

int32_t ParallelMoveTarget(Actor* p, float* dir, float* axes)
{
    // ---- target acquisition (0xA7B8A..0xA7BB8) ------------------------------
    float dt = TickSeconds();                    // call 0x14CF0 (M20: seconds)
    float  scratch = dt;                         // fstp [esp+0x20]
    Actor* t = LockedTarget(*g_pInputMng);       // 0x157CF0 (T7)
    if (!t)
        t = ActorByEntitySlot((EntitySlot*)&g_0x487F58);  // 0x81600 (T7)
    if (!t) {
        p->vtbl[0x334](1);                       // 0xA7FE6: single fallback event
        return;
    }

    // ---- delta + distance (0xA7BB8..0xA7C23) --------------------------------
    // vtbl +0x1BC = GetPosition → live pos at ent+0xD4/+0xD8/+0xDC (M14)
    float dx = p->pos.x - t->pos.x;              // [esp+0x10]
    float dy = p->pos.y - t->pos.y;              // [esp+0x14]
    float dz = p->pos.z - t->pos.z;              // [esp+0x1C]
    float dist_sum = Dist80(p, t) + Dist80(p, p);// 0xAAEF0 twice (T6) → [esp+0x24]

    if (g_autoRunFlag                            // byte 0x487F81 (M6)
        && AutoRunVecGate(g_autoRunVec)) {       // 0x487F64/+0x487F6C vs 0.0 (T11)
        // ---- auto-run re-aim (0xA7C29..0xA7DD4) -----------------------------
        float az = CameraAzimuth();              // 2x 0x15250 (M12);
                                                // fpatan(-B.dir.z, A.dir.x) (M5)
        if (AxesGate(axes)) {                    // 0xA7C74..0xA7C92 (T11)
            // steering window: RotateY(az) applied to a scratch vec, cross-y
            // window ±0.4 @0x32DF40/0x32DFA0, dot vs 0.3 @0x32B15C,
            // StopAutoRun(0) via 0xA6070 — same law as M6.
        }
        float r   = |g_autoRunVec|;              // 0x27530 + fsqrt (0xA7D12..0xA7D2D)
        float len = sqrt(dx*dx + dy*dy) - dist_sum;  // 0xA7D51..0xA7D68
        if (len > 0.0f) {
            *axes = *(const float2*)0x487F98;    // 0x26EB0 (0xA7D79) — see T13:
                                                // 0x487F98 has exactly ONE .text
                                                // reference (this read) and is 0.0
                                                // on disk → copies {0.0, 0.0}
        } else if (az * slot28 > 0.0f) {         // fcompp (0xA7D8E..0xA7D9F);
                                                // slot28 = frame slot [esp+0x28]
            *axes = axes * (az * -0.3f);         // 0x32DFA4 = -0.3, via 0x272E0 (T9)
        } else {
            *axes = g_autoRunVec;                // 0x26EB0 copy3f (0xA7DC2)
        }
    } else {
        // ---- free path (0xA7DD5..0xA7EDD) ------------------------------------
        float len = sqrt(out_z² + out.x²);       // [esp+0x18]² + [esp+0x10]²
        if (len <= 0.1f) len = 0.1f;             // 0x32A378 = 0.1 minimum
        float a = -axes[1] / len;                // → [esp+0x28]
        Mat4 M = RotateY(a);                     // 0x27990/0x279B0/0x27BD0 (T9)
        out = M * out;                           // 0x28200 in-place (0xA7E3B)
        n = Normalize(n_slot);                   // 0x27510 normalizes arg1 in place (T9);
                                                // n_slot = [esp+0x2C..0x34], provenance:
                                                // frame slot (Q11)
        if (len2(out) <= dist_sum || axes[0] > 0.0f) {   // 0xA7E66..0xA7E81
            out += axes[0] * n;                  // 0xA7E83..0xA7EAC (3 components)
        }
    }

    // ---- state classification (0xA7EDD..0xA7EF9) -----------------------------
    int prev  = p->state_0x598;                  // +0x598
    int state = ClassifyTargetState(p, &out, refdir);   // 0xA80D0 (T2)
    p->state_0x598 = state;
    if ((prev == 2 && state == 4) || (prev == 4 && state == 2))
        p->counter_0x5B1 = 2;                    // side-flip latch (0xA7F10)
    if (p->counter_0x5B1 > 0) {                  // 0xA7F17..0xA7F2D
        p->state_0x598 = 1;                      // one tick of "straight"
        p->counter_0x5B1--;
    }

    // ---- facing (0xA7F33..0xA7FCE) --------------------------------------------
    float hx = p->dir.x, hy = p->dir.y, hz = p->dir.z;   // +0xE4/+0xEC/+0xF0 (M10)
    float h;
    if (!MountPred1(p) && !MountPred2(p)) {       // 0x84350/0x84370 (T5)
        h = atan2f(-n.x, -n.z);                   // 0xA7F77..0xA7FA9
    } else if (state == 2 || state == 4) {        // 0xA7F85..0xA7FA3
        h = atan2f(axes[1], axes[0]);             // the "turning" facing
    } else {
        h = atan2f(-n.x, -n.z);                   // 0xA7F95..0xA7FA9 (same as first)
    }
    p->dir.x = hx; p->dir.y = hy; p->dir.z = hz;  // written back (unchanged)
    p->yaw_0xE8 = -h;                             // fchs + fstp (0xA7FCC..0xA7FCE)
    EaseInputAxes(p, axes);                       // 0xA8000 (T3) — writes back to axes
    return;                                       // ret 4
}
```

Notes on the reconstruction:

- **T14/T15 consequence:** `state` here is only ever 0 or 1 (T15), so the
  `state == 2 || state == 4` facing branch (0xA7F85..0xA7FA3) and the side-flip
  latch (0xA7F10..0xA7F2D) are unreachable in this build; the live facing is
  always `−atan2(−n.x, −n.z)`.
- The classifier call's argA is `EBP`, loaded from the 3rd word of the call
  frame at 0xA7C69/0xA7DFE (`mov ebp, [esp+0x9C]`) — the same `axes` 2-float
  pair this function's free path uses; argB is the player's own live position,
  so `d = 0` and both dots are 0 (§3).
- `dist_sum` (0xAAEF0 twice) is the T6 getter sum; the free-path add happens
  when `len2(out) <= dist_sum` **or** `axes[0] > 0` (0xA7E66..0xA7E81: the
  `jp` at 0xA7E71 takes the add on `len2 <= dist_sum`, the `and eax,0x4100; jne`
  at 0xA7E7C/0xA7E81 skips it on `axes[0] <= 0`).
- The `az · slot28 > 0` test (0xA7D8E) is an `fcompp` of `az × [esp+0x28]`; the
  slot's value at entry comes from the caller frame (Q11).
- **T13 [local].** 0x487F98 (inside the auto-run global block 0x487F58..0x487F9C)
  has exactly **one** reference in decoded `.text` — the `push 0x10487F98` at
  0xA7D79 feeding the 0x26EB0 copy above — and reads 0.0 on disk. Nothing in
  this build writes it, so the `len > 0` branch copies `{0.0, 0.0}` into
  `axes` (the input is zeroed while the target sits inside the `dist_sum`
  window). An earlier draft of this pass attributed a π/180 degrees conversion
  to this slot via 0x32A9F4; **retracted** — 0x32A9F4 has zero `.text`
  consumers in this build.
- The facing triple at +0xE4/+0xEC/+0xF0 is read and written back unchanged; only
  the yaw at +0xE8 is new (consistent with M10, which owns the triple in the
  free-run path).

## 3. The state classifier 0xA80D0 (T2, T4, T15)

**T2 [local].** `0xA80D0..0xA8290` (thiscall, 2 stack args, `ret 8`). Called from
0xA6EE4 (control-fn facing pipeline, §5) and 0xA7EF1 (0xA7B80).

Arguments (verified this revision against the prologue and both call sites):

- **argA** = `[entry esp+4]` = the last-pushed arg. Loaded into `edi` at 0xA80D6,
  pushed twice, dot-against-itself at 0xA80E3: the gate is on argA's magnitude.
- **argB** = `[entry esp+8]` = the first-pushed arg, a pointer to a 3f point:
  `d = *argB − p->pos`, `u = normalize(d)`.

```c
// RVA 0xA80D0 — ClassifyTargetState
// this = ecx (player)
// argA (last push) = gate/reference vector (3f)
// argB (first push) = world point (3f)
int32_t ClassifyTargetState(Actor* p, float* argA, float* argB)
{
    if (sqrtf(dot3f(argA, argA)) < 0.001f)       // 0x32A22C (0xA80E3..0xA80F8;
        return 0;                                // NaN inputs continue)
    Vec3 d = *argB - p->pos;                      // +0xD4/+0xD8/+0xDC (M14)
    Vec3 u = Normalize(d);                        // 0x27510 in place (T9)

    float Dplus  = dot3f(RotateY(+0.78516845f) * u, *argA);  // 0x3F490E56 (T4)
    float Dminus = dot3f(RotateY(-0.78516845f) * u, *argA);  // 0xBF490E56 (T4)
    // Dplus → frame [esp+0x10], Dminus → frame [esp+0x0C] (shifted-slot layout
    // below). Both are finite and bounded for any in-game input.

    // 0xA81BF..0xA828F — corrected reading: bit 8 (fnstsw ax; and eax, 0x100) is
    // x87 condition code C0 = "ST < operand" (Intel FCOM table), NOT an overflow
    // flag. The tests branch on the signs of three dot products A ([esp+0x20]),
    // B ([esp+0xc]) and Cc ([esp+0x10]) as follows:
    if (!(A >= 0)) {                       // first test jne ⇔ A < 0 → bucket-else
        if (Cc < 0) {
            return (B < 0) ? 3 : 4;        // ebx=3 @0xA8251 / mov ebx,4 @0xA8279
        }
        return 0;
    }
    return (B >= 0) ? 1 : 2;               // ebx=1 @0xA81EC / ebx=2 @0xA8216
}
// Truth table: A≥0∧B≥0 → 1 ; A≥0∧B<0 → 2 ; A<0∧Cc<0∧B<0 → 3 ;
//             A<0∧Cc<0∧B≥0 → 4 ; otherwise (incl. |argA| < 0.001) → 0.
// Chooser mapping: state 2 → `mvr `, 3 → `mvb `, 4 → `mvl ` (0xC8D9E chain).
```

The two dot results are stored through the pending (uncleaned) stack of the
plain-`ret` dot helper 0x27530, which shifts the effective slots: Dplus lands at
frame [esp+0x10], Dminus at [esp+0x0C] (the stores at 0xA81AC/0xA81BB execute
with 8/16 bytes of pending stack). That part of the earlier draft stands.

**T4 [local].** The bracket half-angles are immediate float constants, not derived
values: **+0.78516845 rad** (`0x3F490E56`, pushed at 0xA8156) and
**−0.78516845 rad** (`0xBF490E56`, pushed at 0xA8180) — ≈ **44.987°**, i.e. just
under 45°. (float32(π/4) would be 0x3F490FDB; the shipped constants are hand-set.)

**T15 [local].** The ±45° bracket machinery (matrix rotations, dot tests) is
present but **inert in this build**: the only routes into the state-2/3/4 result
blocks test the FPU overflow flag (`and eax, 0x100` — raw bytes `25 00 01 00 00`
at 0xA81CE/0xA81E1 — with `fnstsw` taken from the dot-vs-+0.0 comparison, and
[0x3295D8] = +0.0). Bounded dot products cannot overflow, so both tests fall
through and 0xA80D0 returns **1** for every non-tiny argA (and 0 when
`|argA| < 0.001`). The earlier draft's "live states {0,1,3}, state 2 dead"
branch decode misread the overflow-flag test as a comparison-flag test;
retracted.

Call-site argument mapping (verified this revision):

| Caller | argA (gate) | argB (point) | note |
|--------|-------------|--------------|------|
| control fn 0xA65CB @0xA6EE4 | movement vector `dir` ([cf-esp+0x18]) | the yaw-rotated facing anchor ([cf-esp+0x2C] — a direction, not a point) | `d = facing − pos` is a meaningless vector; bracket inert |
| 0xA7B80 @0xA7EF1 | `axes` 2-float input pair (EBP, loaded from the 3rd call-frame word at 0xA7C69/0xA7DFE) | the player's own live position (vtbl+0x1BC) | `d = 0`, `u = 0`, both dots 0 |

A **sibling classifier at 0xA82A0..0xA8484** reuses the same bracket constants
(0xA8378/0xA83A2), the same matrix machinery, and the same overflow-gated state
branches (0xA83F8/0xA840B/0xA8466). Its gate is `|argA − pos| < 0.05`
(0x32A3E0) → return 1; the main flow also falls out at return 1 (0xA8412).
Inert as well (its middle block 0xA836F..0xA83ED is not fully decoded — open
item). In this build both bracket classifiers return only {0,1} / {1}.

## 4. The ease-rate selector 0xA8000 (T3, T5)

**T3 [local].** `0xA8000..0xA80C6` (thiscall + 1 arg, `ret 4`). Called from
0xA6EF6 (control-fn facing pipeline) and 0xA7FD4 (0xA7B80). It captures the
vector's magnitude, normalizes it, and rescales it by a state-dependent
magnitude — this is the "direction-id + vector-length change" the M-pass noted
at the 0xA7B80 call.

```c
// RVA 0xA8000 — EaseInputAxes
// this = ecx (player), arg = 3f vector (in/out)
void EaseInputAxes(Actor* p, float* v)
{
    float mag = sqrtf(dot3f(v, v));               // |v| (0xA800A..0xA8012,
                                                   // shared-frame slot [esp+0xC]-ish)
    *v = Normalize(*v);                           // 0x274B0 (T9)

    switch (p->state_0x598) {                     // 0xA801B..0xA802D
    case 2:
    case 4:
        if (!MountPred1(p) && !MountPred2(p))     // 0x84350/0x84370 (T5)
            break;                                 // → identity
        *v = *v * 0.125f;                          // 0x32A3BC, loaded at 0xA80C0
        break;
    case 3:
        if (!MountPred1(p) && !MountPred2(p))
            break;
        *v = *v * (2.0f * p->vtbl[0x1B0]() * (1.0f/60.0f));
        // 0x32B160 = 1/60; vtbl +0x1B0 = per-actor rate getter
        // (fadd st0,st0 at 0xA808A is the ×2)
        break;
    default:                                       // states 0 and 1
        *v = *v * mag;                             // 0xA802F..0xA8044: identity
        break;
    }
}
```

Properties (corrected this revision):

- The default path (states 0 and 1) is an **identity**: `normalize(v) × |v|`
  reconstructs the original vector (0xA802F..0xA8044 is the `fld mag; fld st0;
  fmul; fstp` scale idiom, not a per-component multiply). The earlier draft's
  "element-wise square decay (v⊙v)" was a misread; retracted.
- **0.125** (0x32A3BC, loaded direct at 0xA80C0) rescales to a fixed 0.125
  magnitude for states 2/4; the 0.25 store at 0xA8090 is dead (the path jumps
  straight to the 0.125 load). **2·vt(0x1B0)·(1/60)** for state 3.
- **Reachability in this build:** state_0x598 is never 2/3/4 (T14), so the live
  path is always the identity rescale. The 0.125 and state-3 rates exist in the
  code but are not exercised by this build's state flow.

### 4.1 State writer census (T14)

All stores to `state_0x598` in decoded `.text` (byte-pattern scan, 7 hits):

| RVA | Function | Value written |
|-----|----------|---------------|
| 0xA8A4D | actor constructor (0xA89F0..) | 0 (ebx=0) |
| 0xA65B3 | control fn early branch (sub-object NULL or 0x964F0 set) | 0 — ebp=0 (`xor ebp, ebp` at 0xA624A; never reassigned in 0xA6240..0xA6817) |
| 0xA6C05 | control fn, after StopAutoRun(0) via 0xA6070 | 0 |
| 0xA6EE9 | control fn facing pipeline | classifier result ∈ {0,1} (T15) |
| 0xA7EF9 | 0xA7B80 | classifier result ∈ {0,1} (T15) |
| 0xA7F23 | 0xA7B80 side-flip latch | 1 |
| 0xA7319 | auto-run fn, after StopAutoRun(0) | 0 |

**T14 [local].** `state_0x598` ∈ {0, 1} in this build — states 2/3/4 are never
written. Downstream consumers of 2/3/4 are therefore starved: the animation
clip selector at 0xC8D5E maps state 2→'mvr ' (0x2072766D), 3→'mvb '
(0x2062766D), 4→'mvl ' (0x206C766D) when the 0x84350/0x84370 predicates pass,
and state 2→'wlk ' (0x206B6C77) when they fail — but no state value ever feeds
those branches. The "turning" walk clips and the 0.125 ease rate are part of the
same vestigial state machine (T15).

**T5 [local].** The predicates gating the 0.125 / state-3 rates:

```c
// RVA 0x84350 — MountPred1 (ret 4)
bool MountPred1(Actor* p) { return p->sub_0x70 ? VtblGate_0x95680(p->sub_0x70) : false; }
// RVA 0x84370 — MountPred2 (ret 4)
bool MountPred2(Actor* p) { return p->sub_0x70 ? VtblGate_0x956A0(p->sub_0x70) : false; }
```

`p->sub_0x70` is the same sub-object `GetGameStatus` (0x84390, M7) reads for its
status code (`[sub+0x170]`). The gates 0x95680/0x956A0 themselves were not
disassembled this pass; their sibling placement next to 0x84390 and their use at
the M7 movement gate ("or the mount siblings 0x84350/0x84370 pass") identify them
as the mount/state siblings.

## 5. Control-fn integration (0xA65CB)

The control function (M1) wires these pieces into the per-frame player tick:

```c
// FFXiMain.dll retail-2026-09, control fn 0xA65CB (M1), facing region
// 0xA6C40..0xA6F30 — decoded this pass (T pass)
// movement branch (0xA6C40..0xA6D1E)
// status_ok = GetGameStatus ∈ {0,1,4,0x1C,0x1F} (M7)
if (status_ok || MountPred1(p) || MountPred2(p)) {  // 0xA6C41..0xA6C68
    if (p->IsFreeRun())                            // vtbl +0x330 (0xA6C72)
        CircleWalkRotate(p, &dir);                 // 0xA79A0 (M5), 0xA6C87
    else
        ParallelMoveTarget(p, &dir, axes_frame);   // 0xA7B80 (T1), 0xA6D19
    // (free-run path continues into the M6 auto-run overwrite at 0xA6D4D)
}
// otherwise: the whole rotate/parallel branch is skipped (0xA6C68 → 0xA6D1E)
AutoRunOverwrite(&dir);                            // M6, 0xA6D1E.. (post-branch)
GroundReorthogonalize(p, &dir);                    // M8 (0x27550 cross), 0xA6DC8..
if (dir.y < 0.0f) dir *= 0.25f;                    // air quarter (M8), 0xA6E28..
dir *= dt;                                         // 0x272B0, 0xA6F04..

// facing pipeline (only when vtbl +0x340 sub-state set, 0xA6E5B)
{
    Mat4 M = Identity();                           // 0x27990 (no-op) + 0x279B0 (T9)
    // translation block from 0x35BBDC..0x35BBE8 (1,0,0, 1,0,0 on disk)
    M = RotateY(p->yaw_0xE8);                      // 0x27BD0, 0xA6EAD
    Vec3 facing = M * (1,0,0);                     // 0x28200, 0xA6EBB
    Vec3 above  = p->pos + (0,0,1);                // 0x26F20, 0xA6ED0
    int state = ClassifyTargetState(p, &dir, facing);  // 0xA80D0 (T2), 0xA6EE4
    p->state_0x598 = state;                        // 0xA6EE9
    EaseInputAxes(p, &dir);                        // 0xA8000 (T3), 0xA6EF6
    dir *= dt;                                     // 0xA6F04
}
CheckContactActor(p, &dir);                        // 0xA8770 (M9/M14), 0xA6F1D
*p->pos += dir;                                    // M9 inline, 0xA6F26..
```

So in the free-run facing pipeline the classifier receives argA = `dir` (the
input movement vector; the gate is its magnitude) and argB = the yaw-rotated
facing anchor (a direction, not a point): `d = facing − pos` is a meaningless
vector and the ±45° bracket produces nothing live in this build (T15). In
0xA7B80 the same classifier is reused with argA = the `axes` pair and argB = the
player's own position (`d = 0`) (§3).

The 0x35BBDC..0x35BBF0 block (on-disk: `(1,0,0)` and `(1,0,0)`) is the
spring-back reference anchor the M18 pipeline rotates by the heading (M18's
reference-angle expression, previously "FPU-underflowed", is this block).

## 6. Helper functions (T9 — corrected table)

Disassembled this pass (full listings in the sweep cache; RVAs below). Several
rows of the M-pass §13 table are corrected; the M table is updated in place.

| RVA | shape | meaning (verified this pass) |
|-----|-------|------------------------------|
| 0x26EB0 | (dst, src) | copy3f |
| 0x26F20 | (a, b) | a += b (3f) |
| 0x272B0 | (v, &s) | v *= s |
| 0x272E0 | (src, dst, s) | **dst = src · s** — s is the 3rd stack word, a float by value (M table said "divide"; it is a plain scale; "divide by 3" call sites pass 1/3) |
| 0x274B0 | (v) | normalize; if \|v\| == 0 or NaN: v ×= 9999999.0 (@0x32A4CC) instead |
| 0x27510 | (a, b) | ***a = normalize(\*a)** — self-copy via 0x26EB0 then 0x274B0; the 2nd arg is unused (M table said "a − b"; wrong) |
| 0x27530 | (a, b) | st = a·b (dot3f); **plain `ret` — callers clean the 8 bytes themselves** (this is why 0xA80D0's dot stores land on shifted slots, §3) |
| 0x27550 | (out, a, b) | cross3 |
| 0x27990 | (m) | **no-op** (`mov eax, ecx; ret`) (M table said "zero a 4x4"; wrong) |
| 0x279B0 | (m) | zero m[1]..m[12] (15 floats from +4); m[0] and m[13..15] untouched |
| 0x279A0 | (m) | **no-op** (`ret`) |
| 0x279F0 | (dst, src) | copy 5 floats (16+4 bytes) |
| 0x27BD0 | (angle, m) | angle is the **1st stack word** (not an FPU value); builds a RotateY into a 16f local and combines it into m via 0x27D10 (T12) |
| 0x27D10 | (dst, src) | 4x4 matrix combine (16f each); behavioral effect = RotateY into the caller's matrix; internal store addressing not fully resolved (T12) |
| 0x28200 | (m, v) | v = M·v in place (local copy + 0x28230) |
| 0x28230 | (dst, src, m) | dst = M·src with translation m+0x30..+0x38; `ret 8` |
| 0x81550 | thiscall (struct {id, zone}) | entity table [0x480AF0]: gate [ent+0x120]&0x200 and [ent+0x78]==zone → return [ent+0xA0] (ActorPointer) |
| 0x81600 | thiscall (struct {id, zone}) | same, plus `[struct+0xB] == 4` rejected |
| 0x157CF0 | thiscall (obj) | **LockedTarget**: `[obj+0x21] == 1` gate + 0x1598A0 scan, else 0 |
| 0x1598A0 | thiscall (obj) | scan entity table [0x480AF0], i < 0x901 (2305): [ent+0x188] == [mgr+0x78] (scene id), flag gates on [ent+0x120] (bits 0x200/0x800), [ent+0x130]&0x80, [ent+0x128]&0x10, [ent+0x170] ∉ {2,3} (M14 type gate), 0x8E8D0 check → return ent |
| 0x84390 | thiscall (p) | GetGameStatus: [p+0x70] ? [sub+0x170] : [0x47D60C] (M7) |
| 0x84350 / 0x84370 | thiscall (p), ret 4 | MountPred1/2 (T5) |
| 0xAAEF0 | thiscall (a, b) | st = 0.8 · sqrt(x² + y²) of `b.vtbl[0x1C8](out, 0x2C)` — horizontal-distance getter, scale @0x329A34 (T6) |
| 0xA6070 | thiscall (p, on) | auto-run setter (M6): flag 0x487F81 = on; off-seed from 0x35BBA8..; on → 0x487F74/0x487F81 bookkeeping |

**T6 [local].** 0xAAEF0 detail: `mov ecx,[esp+4]` (2nd arg), `call [ecx.vtbl +
0x1C8]` with tag immediate **0x2C (44)** and a 3f out buffer; the result uses only
the first two floats (x, y of the getter output) and scales by
**0.8** (@0x329A34). With tag 0x2C the getter is the entity's horizontal-position
property; 0xAAEF0(a, b) is therefore a scaled horizontal distance from a to b.
Self-call 0xAAEF0(p, p) reads the same property at a==b; its contribution to
`dist_sum` is whatever that property returns for a self query (open item — a
single runtime trace would settle whether the sum is distance or distance+radius).

## 7. Constants (verified this pass, TDS 0x6A995428)

| RVA | value | used for |
|-----|-------|----------|
| 0x32A22C | 0.001 | 0xA80D0 gate (T2) |
| 0x3295D8 | +0.0 | 0xA80D0 / 0xA82A0 dot-compare target (T15) |
| 0x32A3E0 | 0.05 | 0xA82A0 sibling gate (T15) |
| 0x32A378 | 0.1 | free-path minimum distance (T1) |
| 0x32A3BC | 0.125 | state 2/4 ease rate (T3) |
| 0x32B15C | 0.3 | auto-run steering dot (M6) |
| 0x32B160 | 1/60 | state-3 rate scale (T3) |
| 0x32DFA4 | −0.3 | auto-run re-aim angle scale (T1) |
| 0x32DF40 / 0x32DFA0 | +0.4 / −0.4 | auto-run cross-y window (M6) |
| 0x32DF8C | −0.01 | auto-run stop dot (M6) |
| 0x32DF90 / 0x32DF94 / 0x32DF98 | 2π / 1/(2π) / π | 16-step compass (T10) |
| 0x32A1AC | 16.0 | 16-step compass sector count (T10) |
| 0x32A9F0 | 1/16 | 16-step compass sector width (T10) |
| 0x32B088 | 1/32 | 16-step compass half-sector offset (T10) |
| 0x32A9F4 | π/180 | **zero `.text` consumers in this build** (dead constant; T13 retraction) |
| 0x329A34 | 0.8 | 0xAAEF0 distance scale (T6) |
| 0x32A4CC | 9999999.0 | 0x274B0 zero/NaN guard (T9) |
| 0x3F490E56 (immediate) | +0.78516845 rad (≈44.987°) | 0xA80D0 bracket, + side (T4) |
| 0xBF490E56 (immediate) | −0.78516845 rad (≈44.987°) | 0xA80D0 bracket, − side (T4) |
| 0x3D800000 (immediate) | 0.25 | 0xA8000 state-2/4 path — **dead store** (T3) |

Data globals (all zero-initialized on disk; runtime state):

| RVA | meaning |
|-----|---------|
| 0x487F58..0x487F5C | entity slot {id, zone} for 0x81600 (fallback target, T7) |
| 0x487F64..0x487F70 | auto-run unit vector (M6) |
| 0x487F74..0x487F7C | entity slot {id, zone} for 0x81550 (follow target) |
| 0x487F81 | auto-run flag byte (M6) |
| 0x487F8C | auto-run timer-ish 3f (copied into `dir` at 0xA7B52, M6) |
| 0x487F98 | 2f slot, **read-only in this build** (T13); 0.0 on disk |
| 0x35BBDC..0x35BBF0 | spring-back reference anchor (1,0,0 / 1,0,0 on disk; M18) |
| 0x35BBA8..0x35BBB8 | auto-run off-seed vector (0,0,0,1 on disk; M6) |
| 0x57876C | g_pInputMng (M1); 0x157CF0 takes `*g_pInputMng` |

## 8. The 16-step compass (T10)

**T10 [local].** `0xA7851..0xA78C9` (tail of a small helper, `ret 0xC`): a
16-sector direction quantizer.

```c
// RVA 0xA7851 — Direction16 (DEAD in this build: 0 callers in the sweep)
// inputs: a 2f (y, x) pair on the FPU + an index float at [esp+0xC]
bool Direction16(float* out_cos, float* out_sin, float* out_angle)
{
    if (y == -1.0f) return false;                 // 0x32A3F0 = -1.0 sentinel
    float a = atan2f(y, x) + π;                    // 0x32DF98
    float sector = (a * (1/(2π))) + 1/32;          // 0x32DF94, 0x32B088
    int   idx    = (int)roundf(sector * 16) & 0xF; // 0x32A1AC, 0x311C2C
    float ang    = index * (1/16) * 2π − π;        // 0x32A9F0, 0x32DF90, 0x32DF98
    *out_cos = cosf(ang); *out_sin = sinf(ang); *out_angle = ang;
    return true;
}
```

16 sectors of 22.5° spanning [−π, π), half-sector offset for cell-center sampling.
No direct callers and no vtable hit this pass — treat as dead (or
computed-address-dispatched) in this build.

## 9. Findings index, kuluu relevance, open items

| # | Tier | Statement | Evidence |
|---|------|-----------|----------|
| T1 | [local] | 0xA7B80 = ParallelMoveTarget: target acquire → delta/dist → auto-run re-aim or free path → classify → facing → ease; callers 0xA6D19, 0xA76D0 | §2 |
| T2 | [local] | 0xA80D0: gate on argA (\|argA\|<0.001 → 0), else 1; argB = point, d = argB − pos; bracket machinery present | §3 |
| T3 | [local] | 0xA8000 = magnitude rescale: default = identity (normalize × \|v\|); 0.125 (st 2/4) and 2·vt(0x1B0)·1/60 (st 3) unreachable here; the 0.25 store is dead | §4 |
| T4 | [local] | Bracket half-angle = immediate ±0.78516845 rad (≈44.987°), not derived | §3 |
| T5 | [local] | Rate gates = 0x84350/0x84370 (mount siblings on [this+0x70]) | §4 |
| T6 | [local] | 0xAAEF0 = 0.8·horizontal-distance (vtbl +0x1C8, tag 0x2C) | §6 |
| T7 | [local] | Target = LockedTarget(*g_pInputMng) ([obj+0x21]==1 + 0x1598A0) else *0x487F58 slot via 0x81600 | §2 |
| T8 | [local] | Facing: −atan2(axes.y, axes.x) for st 2/4 with predicates; −atan2(−n.x, −n.z) otherwise; yaw → +0xE8 | §2 |
| T9 | [local] | M-helper table corrected: 0x27510 = in-place normalize; 0x272E0 = scale; 0x27990/0x279A0 = no-ops; 0x27530 plain ret | §6 |
| T10 | [local] | 16-step compass 0xA7851: dead in this build | §8 |
| T11 | [local] | Quadrant gate `proceed unless (x >= 0 && z >= 0)` on 2 floats 8 bytes apart; complementary use at 0xA76D5 (copy auto-run only when x,z >= 0) | §2 |
| T12 | [local] | 0x27D10 4x4 combine: behavioral RotateY established (M5/M10); internal store addressing unresolved | §6 |
| T13 | [local] | 0x487F98: single .text reference (0xA7D79 read), 0.0 on disk → `len>0` branch zeros `axes`; π/180 attribution retracted (0x32A9F4 has no consumers) | §2 |
| T14 | [local] | state_0x598 writer census: 7 writers in .text, only 0/1 ever written in this build; 2/3/4 consumers (0xC8D5E 'mvr '/'mvb '/'mvl '/'wlk ' clip selector) starved | §4.1 |
| T15 | [local] | ±44.987° bracket inert: state-entry branches in 0xA80D0 and sibling 0xA82A0 are gated on the FPU overflow flag (`and eax,0x100` after dot-vs-+0.0 fcomp) — unreachable for finite inputs; classifiers return only {0,1}/{1} | §3 |
| T16 | [local] | 0xA8000 default path (states 0/1) is an identity rescale (normalize × original magnitude), not the v⊙v decay of the earlier draft; 0.125 load at 0xA80C0 confirmed, 0.25 store at 0xA8090 dead | §4 |

### Relevance to the head-look / body-tug question (corrected this revision)

The two numbers the earlier draft put forward as the retail answer are **not
live in this build**:

- **0.125 body-tug (0x32A3BC):** the state-2/4 ease rate is unreachable —
  state_0x598 is never 2/3/4 (T14). Not the live tug.
- **±44.987° bracket (0x3F490E56/0xBF490E56):** both bracket classifiers
  (0xA80D0, sibling 0xA82A0) are overflow-flag-gated and return only {0,1}/{1}
  (T15). Not the live head limit.

What this pass does establish: the movement layer (0xA6240 control fn +
0xA7B80) handles a present-but-unlocked target by steering the *movement
vector* (auto-run re-aim / free path, §2) and facing the movement direction
(−atan2(−n.x,−n.z)); the state field it maintains only ever holds 0/1. It does
not implement a head-follow-up-to-limit, reset-to-straight, or body-tug in this
build. The behavior observed in this retail client (head follows the target to
a limit, then settles straight; torso turns very slightly with it) must
therefore live in the **skeleton/joint layer** — the per-entity update (F-pass
region 0x8F000..0x93500, zero fpatan → dot/cos-based) and the joint-angle
machinery (0x4B249, [obj+0xE0] ±π wrap). That is the next dig (refined Q12).

**Do not port 0.125 or ±44.99° into kuluu** as the head/body numbers — they are
vestigial in this build. The kuluu constants (`kuluu-render/src/ffxi_actor_render.rs`
~3241: `HEAD_MAX_TURN_RAD`, `HEAD_VIEW_CONE_COS`, `HEAD_SLEW_TAU_FRAMES` and the
state-2 body behavior in `kuluu/src/view_native/input.rs`) wait on the live
joint numbers. Citation form for those edits: `FFXiMain.dll retail-2026-09
RVA 0x...`.

### Open items

- **Q11 — frame-slot provenance.** 0xA7B80 reads/writes slots whose contents
  depend on the caller's frame (`axes` via word 3 of the call frame; `out.z` at
  [esp+0x18]; the `n` source at [esp+0x2C]). Static analysis pins the structure
  but not every slot's value at entry; a single runtime trace (log the slots at
  0xA7B80 entry/exit) would close this.
- **Q12 — head-look joint limit.** Confirmed NOT in this state machine (T14/
  T15). The live mechanism is in the skeleton/joint layer. Next: (a) 0x4B249
  joint-angle helper — no direct E8 callers found, so it dispatches via vtable;
  find the vtable slot and its consumers, and who reads/writes [obj+0xE0]
  (±π wrap) with a zero-store (reset-to-straight) pattern; (b) scan
  0x8F000..0x93500 (F-pass region, zero fpatan) for dot-vs-cos-of-limit
  compares on a target direction and the small body-tug scale constant;
  (c) target-direction source in that region (0x157CF0 LockedTarget / 0x487F58
  slot).
- 0x27D10 internal 4x4 combine addressing (behavioral RotateY established via
  M5/M10 usage; store layout unresolved).
- Sibling classifier 0xA82A0 middle block (0xA836F..0xA83ED): matrix/dot section
  not fully decoded; its return value is 1 on all observed paths (T15).
- 0x95680/0x956A0 gate bodies (mount siblings, T5).
- vtbl +0x1B0 getter body (state-3 actor rate, T3).
- 0xAAEF0 self-query contribution to `dist_sum` (T6).
- ~~The control-fn `axes` pointer value at its [esp+4]-ish frame slot~~ — **CLOSED
  definitively (frame-solver pass):** there is no separate axes input; the `ebp` loads are
  arg-1 (`&dir`) re-read after branch-local pushes (§2 revision). Every consumer operates on
  the caller-owned movement vector. The whole-function esp fixpoint converged with all indirect
  vtable-call cleanup widths resolved via the class-vtable tables (slots +0x198/+0x1a0/+0x1bc/
  +0x1c0/+0x210/+0x330/+0x340 = plain `ret`; +0x344 = `ret 4`).

> **Also see:** [locomotion_motion_camera_k_pass.md](locomotion_motion_camera_k_pass.md) (K pass 2026-10-08: motion-name chooser, +0x598 write census, chase-camera lock pivot and eye band).

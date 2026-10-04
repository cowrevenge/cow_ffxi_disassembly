# DancingMad (WGINC) ingest — `dancer` module map, class map, and two new oracles

**Tier: [web] navigation map.** Same standing as XIClient: names/hierarchies/struct *shapes* are
leads; **their addresses are not usable by us**. Source: `github.com/WGINC/DancingMad` @ commit
**4243c7e**, published 2026-09-26, docs `FINDINGS.md` (master, ~3.3k lines),
`GRAPHICS_PIPELINE.md`, `ROADMAP.md`. Their binary: unpacked PC `FFXiMain.dll`, MD5
`f6dbabefc672dfc8586ac14486ff904d`, Direct3D 8.1, base `0x10000000`. **Our build is TDS
`0x6A995428`; expect every RVA to differ.** Nothing here was copied wholesale — synthesized.

**Their own warning, which we adopt as policy:** IDA/Lumina-assigned names are matches on short
function bodies (they cite 33-byte bodies), *not* symbols from the binary → a name is a hint about
behaviour, never evidence. Anything in this file marked [web] carries that risk until our build
agrees byte-for-byte.

## 1. Module census — independently reproduced by us [V vs web ✓]

They claim a complete `dancer` module census; **we re-derived it from the `__FILE__` path strings
in our own image** ([`tools/our_modules.py`](../tools/our_modules.py)): **16 modules, 84 source-file
paths**. Their per-module file counts match ours exactly on sqBase-adjacent groups where quoted.

| module | prefix | files (ours, [V]) | role | note vs DancingMad |
|---|---|---|---|---|
| `sqBase` | `sq` | 12 | arrays, IO, matrix3/4, quaternion, SQO, struct-array, timer, util, vertex taxonomy (`sqVtx`) | — |
| `sqModel` | `sqmd` | **7 ✓** | top-level model container: `sqmdModel`, DMB, IO, Snap, Sort, Script, Parser | matches; `sqmdModelLookAt()` lives here (§3) |
| `sqMotion` | `sqmo` | **12 ✓** | animation sampling/blending/mixing (§4) | matches |
| `sqSkeleton` | `sqsk` | **3 ✓** | joint/bone hierarchy (`sqskJoint`, `sqskSkeleton`, IO) | matches |
| `sqSkin` | `sqin` | 4 | vertex skinning, bone-weight clusters (`sqinShape`, `sqinSkin`) | **they say 5 files**; our build has no 5th path string (their prose mentions a `sqinCluster_Create`; likely a file whose debug string is absent from this build) — unresolved discrepancy |
| `sqHierarchy` | `sqhi` | **1 ✓** | generic node/hierarchy system (`sqhiNode`) | matches |
| `sqShape` | `sqsh` | 12 | geometry primitives/trimeshes/curves/displists/draw | — |
| `sqShader` | `sqsd` | 9 | shader/material defs (BRDF, ambient map, glow, sampling, aniso) | their §18 quote on aniso tri-counts is this module |
| `sqGrafix` | `sqgx` | 6 | D3D-ish context, display lists, Phong/shader/shape glue (`dx8nv15` subdir) | — |
| `sqImage` | `sqim` | **5 ✓** | PS2 TM2 + TIFF/SGI/PPM image IO (likely tool-side) | matches |
| `sqScene` | `sqsn` | 2 | scene + shadow (`sqsnShadow`) | — |
| `sqRend` | `sqrd` | 4 | camera / light / material / texture render objects | — |
| `sqOpcode` | `sqop` | **3 ✓** | opcode/system/track layer ⇒ F pass's scheduler & stage stream | matches |
| `sqXform` | `sqxf` | 2 | transform data (`sqxfXformM`, `sqxfXformTD`) | the "manual C vtable" they cross-checked against DWARF |
| `sqConstraint` | `sqco` | **1 ✓** | `sqcoConnector` (typed memory-copy connector) | matches |
| `sqDeform` | `sqdf` | **1 ✓** | `sqdfShape` | matches |

## 2. Class map — every DancingMad name checked against OUR build [V]

Their hierarchy was recovered structurally from **`class_descriptor_t` nodes in `.rdata`/`.data`**
— the same records our D pass parsed independently as `{char* name; uint32 size; ClassDesc* parent}`
([drivetask.md](drivetask.md) §2). Two independent recoveries of the same structure ⇒ this part is
solid. Checked names against our descriptor table (`tools/xcheck_dmad.py`):

| class | in our descriptors? | our size (TDS 0x6A995428) | their claim / use |
|---|---|---|---|
| `CMoLockLookAtDriveTask` | **yes** @0x32B7D4 | **0x80** | class tree only — **no look-at decode in their docs either** (§3) |
| `CMoActorRotationDriveTask` | **yes** @0x32B7EC | **0xA0** | same as above |
| `CMoSchedularTask` / `CMoTaskMng` | yes / yes | 0x14A / 0xD64 | effect-script interpreter = SchedularTask slot 8 [web] |
| `CMoSkeletonElem` | **yes** @0x32B008 | **0x1D9** | bone-hierarchy propagation (§5) [web for the body, V that class exists] |
| `CMoOtTask`, `CMoProcessor` | yes / yes | 0x54 / 0x10 | CMoProcessor = CPU math tiers (3DNow!/x87+/x87), not a GPU tier [web] |
| `CXiActorDraw` | **yes** @0x32CF88 | 0x34 | depth-sorted draw list; per-actor hook = vtable **slot 162** (not slot 8) [web] |
| actor chain `CXiAtelActor → CXiControlActor → CXiCollisionActor → CXiSkeletonActor` | **all four present** | 0xD4 / 0x5C4 / 0x5F8 / **0xA0C** | matches PS2 DWARF `XiAtelActor 0xB0 → XiControlActor 0x180 → …` [web]; sizes differ by platform as expected |
| `CYyMotionQue` | yes @0x32A1B0 | **0x40** | the 5 base + 2 blend motion slots (§4) |
| `CYySkl` / `CYyObject` | descriptor yes / string only | 0x18 / — | their PS2 counterparts are `Kz*`/`Ym*`; **PC renamed this layer** [web] |
| `XiZone` (zone singleton) | yes @0x33682C | 0x1DC | fog/ambient/time-of-day live in zone env records [web] — relevant to our wall-glow work |
| `StAvatar/StChannel/StModel/StTrigger` | string-only (not descriptor classes) | — | FFXI↔dancer seam layer (`…\FFXi_Win\Main\dancer\*.cpp`) [web] |

**Direct consequence for us:** the D pass's DriveTask overlay discovery stands, and their class
list tells us these task classes are *the* PC-side overlay mechanism — but **neither doc decodes
what we need**. The numbers stay ours to extract.

## 3. Look-at: what changes in our plan [web ⇒ leads]

- `sqmdModelLookAt()` exists in their build too, and its PC error string (which we found at
  `.rdata 0x103B3C30`, code tail `0x2790A2`) confirms a **`<boneNdx>` parameter with a range check**.
- Their pipeline map lists `CMoLockLookAtDriveTask` / `CMoActorRotationDriveTask` in the class tree
  and nowhere else: **no limit, no slew, no tug, no member names.** So joint.md §9's lead is now
  stated as: *named classes located in our build (sizes + vtables known) → read their update
  methods and constructors*, which is exactly [drivetask.md](drivetask.md) §6's next-dig list.
- Their actor-interface census adds usable structure around it: vtable **slot 162** as the real PC
  per-actor draw hook; slots **195–209** = `IsControlLock / IsDirectionLock / IsConstrain /
  IsFreeRun / IsWalkLock / IsParallelMove` (movement/animation lock queries — likely where S1's
  "strafe rules" live); slot 8 = per-frame update. **[web: verify against our vtable before use.]**

## 4. Animation & blending — directly relevant to the idle↔walk seam (S2) [web]

Their §7/§18.15 account, all **[web], none verified in our build yet**:

- `sqmoKeyChannel`: `entrySize`+28, `timeSpan`+32 (float), **interpolation enum +36**
  (`1`=Linear, `2`=Smooth, else None), `numKeys`+40; keys are `(time, entrySize floats)` pairs.
  `sqmoFrameChannel` = fixed-rate frames. Mixer motions can nest.
- Pose assembly into a per-bone scratch (quat +0, translation +0x10, scale +0x1C): reset to
  defaults → **5 base layers** sampled straight in (slot 4 first … slot 0 last, so *lower slots win*)
  → **2 blend layers** mixed by weight: rotation `Quat_NLerp`, translation/scale `Vec3_Lerp`.
- Per-bone byte mask: low 6 bits = channel category, **bit 6 = touched by a base layer this update**,
  **bit 7 = bone accepts blend layers**; the same bits decide whether a new motion interrupts or
  queues (`MotionQueue_ApplyPolicy`). ← **This is the retail answer to S2: clip changes are masked
  and blended per bone, not full-pose restarts.**
- Blended quaternions are **not renormalised** (the call after NLerp returns immediately).

**Open conflict to resolve (do not gloss):** they state the `2 = Smooth` interpolation enum is
"confirmed *not exercised* by any reachable code path" in their retail build, while our J pass found
two quadratic/"smooth" curve evaluators (`0x547A0`, `0x546F0`) with **46 and 26 call sites**. Either
those are a different subsystem than motion-channel interpolation (likely: joint *drive* curves vs
keyframe channels — consistent with the J-vs-D layer split), or one of us has mis-scoped. Our own
§8a work already resolved how those branches select (`jp` ⇒ u ≥ 0.5); what's needed is a caller
census in **our** build to say which subsystem they serve.

## 4a. D1 evidence pass — verified in OUR build, §4's queue claims hold [V]

Byte-verified this session against our `FFXiMain.unpacked.dll` (retail-2026-9, offset==RVA, base
0x10000000). Disassembly dumps: `C:/tmp/ffximain_work/d1_*.asm`.

- **MotionQueue_UpdateAllChannels = 0x1A420..0x1A660** (our function table seeds it; sole caller =
  `Model_AnimateAndPose`, call site 0x1002A27B). Every §4 queue/scratch claim checks out:
  - Globals pinned: pose scratch **0x1045F030**, stride **0x34** per bone (`add esi,0x34`);
    blend scratch **0x1045B820**; mask array **0x1045F028** (this local address *is* DancingMad's
    `g_pBoneMotionMask` `[web]` — name↔address alias pinned 2026-10-05, cite the local address); bone-count global **[0x10462430]**.
  - Queue layout: 5 base slots at `this+0x50` (stride 0x14) + pending-request list `this+0x34`
    (+0x3A entry array belongs to the policy descriptor, below); blend pair above `this+0x70`.
    Sampling order verified: index argument descends **4 → 0**, each active slot
    (`[slot+4] != NULL`) sampled straight into the shared scratch — last writer wins ✓.
  - Then up to **2 blend layers** sample into the *separate* blend scratch; per-bone merge runs only
    where mask byte has **bit7 set AND low-6 nonzero**; rotation merged by an NLerp-style call
    (0x1A5C0 → `0x33220`, 4 dwords copied out, no renormalise follows ✓), translation and scale by
    two lerps (`0x276A0`).
- **No freeze during crossfade — this is the D1 answer.** The slot sampler (0x1B230) walks each
  slot's motion linked list and calls vtable+**0x38** per element: every layer that remains active
  is sampled into scratch **every frame**; a blend merges live samples by weight ramp. Nothing in
  the verified code freezes a pose at transition start. (The slot "update" helper 0x1B340 only
  counts list nodes.)
- **ApplyPolicy = 0x19A50..0x1AFD** (sole caller 0x1ABBA, inside the setNextMotion wrapper
  0x1AB60, which enqueues through scheduler object [0x1047D128] → 0x10072FB0 before policy).
  Policy reads a float argument against 1e-4 (`[0x1032A1A8]`), then loops authored per-bone
  entries: count = u16 `[desc+0x32]`, entry array at `desc+0x3A`, **stride 0x54**, bone index first
  dword. Per bone: skip if mask bit7 clear; skip if bit6 set; low-6 == 0 → handler 0x19B30 (and on
  true, `mask |= 1`); low-6 == 1 → handler 0x19EE0. Helper 0x19B00 sets bit6 on every bone whose
  low-6 is nonzero. So "interrupt vs queue" IS the mask machine ✓ — but note it dispatches on
  *authored per-entry state*, not a single flag.
- **Open conflict resolved [V]:** caller census finds 46 (0x547A0) + 26 (0x546F0) E8 sites, ALL in
  ~0x10049Axx–0x1005ECE8 — the CMo* effect-element region (pipeline map §8: OT tasks/elem vtables).
  **Zero** call sites inside any sqmo motion cluster. DancingMad's "linear-only" holds for motion
  channels; our two evaluators serve effect curves.
- Cluster anchors (assert-path strings, full `C:\dev\dancer\modules\sqMotion\src\*.c`): string
  starts 0x103B79A8 / 0x103BA62C / 0x103BB558 / 0x103BB674 / 0x103BB964; code xref clusters ≈
  sqmoFrameChannel 0x10293F80–0x102946xx, sqmoMixerMotion 0x1029497x–0x102956xx, sqmoKeyChannel
  0x102957B4–0x10295D3x. Function starts enumerated in `C:/tmp/ffximain_work/d1_*.asm`.
- **Token mystery closed:** the "class-name tokens" in mob_evidence §Raw references are plain
  name strings followed by a u32 length (`CYyMotionQue` starts at **0x3510A8**, `len=11` follows at
  0x3510B8). The `?` was an ASCII-dump boundary artifact from the preceding float byte 0x3F. No MSVC
  RTTI (`.?AV`) exists for dancer classes in our build; vtables are packed function-pointer tables
  with no class header.
- Still [web], not verified here: key-channel record offsets (`entrySize`+28/`timeSpan`+32/
  `interp enum`+36/`numKeys`+40) — the sqmoKeyChannel region disasm (d1_keychannel.asm) is at hand
  but the per-channel interp-enum read was not pinned to a function; moot for D1 given the negative
  evaluator census above.

### §4a-bis — The blend merge itself: `0x33220` decoded, and the two ways kuluu's differs **[V]** (pass of 2026-10-06)

§4a recorded that per-bone rotation merging goes through an "NLerp-style call (`0x1A5C0` → `0x33220`) …
no renormalise follows". The callee is now read, and it pins the law:

```
0x33220  fld dword [esp+0xc]              ; t
0x33224  fcomp dword [0x1032961c]         ; vs +1.0   (test ah,0x44 -> J10: jnp = equal)
0x33239  jp 0x3325e                        ; t != 1 -> general path
0x3323B  ...                               ; t == 1: copy the incoming quat's 4 dwords out verbatim
0x3325E  dot = sum(a[i]*b[i])              ; fld/fmul x4, faddp x3
0x3327A  fcomp dword [0x103295d8]          ; vs +0.0   (test ah,5 -> J10: jp = not-below)
0x33285  jp 0x332ac                         ; dot >= 0: keep b as it is
0x33287  ...                                ; else negate b's four components (fchs x4) - shortest arc
0x332C7  fld +1.0; fsub [esp+0x30]          ; 1 - t
0x332D9  call 0x32a40                        ; (helper, result unused by the arithmetic below)
0x332DE  out[i] = a[i]*(1-t) + b'[i]*t       ; four components, stored raw at 0x33335..0x33350
```

**No normalisation exists anywhere in it** — no `fsqrt`, no division: the blended quaternion leaves the
function with whatever magnitude the weighted sum produced (it only ever runs on quats that clip data and
prior poses already keep near-unit). The t==1 branch is a whole-quat copy, not a blend.

Two kuluu deviations this exposes, both in the *blend* path (`ffxi-actor/src/animation.rs`, and the shared
`nlerp` it imports from `ffxi-dat/src/skel_anim.rs:53`):

1. **kuluu renormalises its blends.** `skel_anim::nlerp` divides by the result magnitude; retail's merge does
   not (bytes above). Same sign-flip-on-negative-dot rule, though — kuluu matches that part ✓.
2. **kuluu has a long-arc fallback selection** (`long_arc_is_nearer_front` + `nlerp_arc(_, _, true)`, chosen
   per joint at transition build time; added in `jw-stack-815 64b1a0e3` as the mitigation for ~180° mvl?→mvr?
   joint rotations, and since superseded by the idle frame-0 waypoint path which xim evidences). Retail's
   merge has *no* arc choice at all: shortest arc, always. So once kuluu's channel-level work lands, the long-arc
   arm should go rather than be ported — keeping it means some joints rotate the way round retail never does.

**Both kuluu deviations closed 2026-10-06** (gaps rows D1/D2). `jw-stack-815 ad01f92d` adds `merge_layer_rotation` — this routine transcribed: verbatim copy at t == 1, sign flip on a negative dot, the sum stored with no normalisation — and routes every cross-layer blend site through it (`interpolate_kf`, `interpolate_nullable`, hence `cross_slot_interpolation`); the within-clip key interpolator in kuluu's DAT reader still normalises, because that path has no recorded law. `206ae480` removes the long-arc arm and its front reference outright (`long_arc_mid`, `quat_abs_dot`, `long_arc_is_nearer_front`, `nlerp_arc`, the per-joint set on the transition, `TransitionParams::front_ref` and the renderer's producer for it), with `every_blend_takes_the_short_arc_whatever_the_twist` pinning that a +100°→−100° joint sits on the far side mid-blend.

Not verified, and worth naming before anyone "fixes" the wrong thing: the **key-channel** interpolation (adjacent
keys *within* one clip) is a different routine from this merge; §4a left its interp-enum read [I], so kuluu's
renormalising `nlerp` on that path has neither retail confirmation nor refutation. Only the blend-merge sites
have evidence to change by today.

## 5. Bone hierarchy & skinning — leads for the pose path [web]

- `CMoSkeletonElem::UpdateBoneTransform`: normalize a bone's local Euler rotation (three floats at
  large offsets) against wraparound constants → register with `CMoProcessor` → copy local matrix →
  multiply by parent (`Mat4x4_Multiply`) → store back **and** publish into the actor's per-bone
  matrix array. Two things we care about: **retail wraps bone Euler angles every frame** (our "turns
  in radials/popping" symptom) and bones reach actors through a published matrix array rather than
  being recomputed by consumers.
- Skinning is CPU-side with a weight-premultiplied bone-matrix table; `sqinShape_Blend4Bone` is a
  *second*, hardware-style 4-bone path. Secondary-motion solver adds jiggle with a camera-bias term.
- PS2 DWARF layouts match their PC reconstruction for `sqObject` header (`type,id,validateFunc,
  destroyFunc,printFunc`, 0x14), `sqskSkeleton` (root +0x1C, nodes +0x20, joints +0x24, numBones
  +0x28), and the joint record order (`mat, translate, rotate, scale, fppa, fpp, radius, influence`).

## 6. Two new oracles (added to our oracle list) [web]

1. **PS2 `SCUS_972.66` DWARF v1 `.debug`** — Dec-2003 PS2 disc executable (CodeWarrior MIPS):
   14.8 MB debug section, **321,865 entries / 2,758 named types with every member name, type, offset
   and inheritance**, plus a 12,227-entry function symbol table; `dancer` is present as a loaded
   module (`Dancer.bin`, `.relDancer.bin`, functions from `0x6A0000`) with **1,936 named `sq*`
   functions and 51 `sq*` types**. Validation evidence they publish: parser checked against the
   independent *XiEvents* project, including its `Priorty` typo landing at the right offset.
   → This is how to get **member names for offsets** where PC naming failed (our +0x74/+0x78/+0x7c
   guesses). Caveat: this layer's PS2 names are `Kz*`/`Ym*`; the `CMo*DriveTask` family may be
   **PC-only with no DWARF counterpart** — must test, not assume.
2. **Independent C++ reconstruction** (their ~1,827-header effort) + `ps2_dwarf_tools.zip`: a DWARF-1
   parser (std libs don't read DWARF 1), a class indexer, and a JSON export of all 2,758 types.
   → Third-party cross-check for any struct claim we make.

## 7. Carry-forward cautions

- Their build ≠ ours: **older PC unpacked build + PS2 discs**. Every RVA in their docs is unusable;
  names/offsets are hypotheses until our bytes agree. Tag [web] → promote to [V] one at a time.
- Known numeric discrepancy already: `sqSkin` file count (theirs 5, ours 4).
- Adopt the Lumina discipline: no name is evidence.
- Not yet mapped by anyone (their words): sky/sun/moon, water surface, PC shadow rendering,
  in-game settings object; weather selection by weather/time-of-day untraced.

## 4c. RESOLVED (2026-10-06): `desc+0x32` / `desc+0x3A` are the mo2 chunk payload — kuluu already parses that table

Row D1 needed one thing to become kuluu code: which loaded bytes form the descriptor `ApplyPolicy` walks (count u16 `[desc+0x32]`, entries inline from `desc+0x3A`, stride 0x54, bone index first dword). It is **the mo2 skeleton-animation chunk**, and descriptor base and file payload differ by a constant `0x30` (the object prefix):

| descriptor field | payload offset | what it is |
|---|---|---|
| `[desc+0x32]` | **payload + 2** | u16 joint count — how many entries ApplyPolicy loops |
| `[desc+0x3A]` | **payload + 0xA** (kuluu's `POOL_START`) | the entry array, inline |

One entry is exactly **0x54 bytes**, which is the stride of `add eax,0x54` (RVA 0x19AEB), and it is what kuluu's own reader walks (`ffxi-dat/src/skel_anim.rs`: bone index dword, then rotation / translation / scale channel groups, each as *N* i32 offsets followed by *N* f32 constants — `read_sequences`):

| entry offset | field | size |
|---|---|---|
| +0x00 | bone index (the `mov esi,[eax]` at RVA 0x19A83) | 0x04 |
| +0x04 / +0x14 | rotation: 4 channel offsets / 4 constants | 0x10 each |
| +0x24 / +0x30 | translation: 3 offsets / 3 constants | 0x0C each |
| +0x3C / +0x48 | scale: 3 offsets / 3 constants | 0x0C each |

Four consequences:

- **Nothing writes `[desc+0x32]` in `.text`** because the block is file data copied in whole — that is why the word-store census at displacement `+0x32` (154 sites, 109 functions) found exactly three inside sqmo (**0x1977B**, **0x19A61** = ApplyPolicy, **0x1A304**), all reads.
- kuluu's `SkeletonAnimation::key_frame_sets`, keyed by joint index, **is** the parsed motion-entry table. A bone missing from that map is a bone the clip does not key. Row D1 has no read outstanding; what it needed was this parse-level identity.
- The registry lead keeps its shape but blocks nothing: `setNextMotion`'s wrapper 0x1AB60 still has zero code callers and one pointer, `.rdata` **0x32A1F8** in a name-registry-shaped table, so *who* runs the policy per request stays registered-dispatch territory (§4a). Nothing above changes because of it. The old `.rdata 0x32B654` "motion object vtable" lead remains dead — its only storer is the CMo* effect-element constructor at RVA 0x532DE.
- **Still [I] on this row:** whether a channel-offset word carries meaning in its sign/high bits. kuluu drops any entry with a negative offset (`read_sequences` returns `None`), which makes that bone unkeyed; §4e shows retail masks the same word before using it as a key index (`and ecx,0x7fffffff` @RVA 0x19F46). Settling read: take shipped hume clips, and for each entry whose rotation-channel-0 offset is negative check whether ApplyPolicy-style dispatch visits that bone with category ≠ 0 — if yes the sign encodes per-bone state and kuluu's skip is wrong; if they never reach a handler it is harmless.

## 4d. The pose scratch: who owns each field of the stride-0x34 record **[V]** (pass of 2026-10-06)

`ApplyPolicy` does **not** write the scratch (§4e); its only global write is one mask bit. The record's owner is `MotionQueue_UpdateAllChannels`' reset pass, whose own stores pin the layout §4 claimed [web] (`C:/tmp/ffximain_work/d1_update_all.asm`, generated listing):

```
1001A463  mov      esi, 0x1045f040                     ; record base + 0x10 (scratch = 0x1045F030)
1001A474  lea      eax, [esi - 0x10]
1001A47D  mov      dword ptr [eax], ecx                ; quat.x ← global [0x10456d2c]
1001A485  mov      dword ptr [eax + 4], edx            ; quat.y ← [0x10456d30]
1001A488  mov      dword ptr [eax + 8], ecx            ; quat.z ← [0x10456d34]
1001A491  mov      dword ptr [eax + 0xc], edx          ; quat.w ← [0x10456d38]
1001A477  push     0x10456d3c                          ; src: vec3 default
1001A47C  push     esi                                 ; dst: record+0x10
1001A494  call     0x10026eb0                          ; copy3
1001A499  lea      eax, [esi + 0xc]                    ; record+0x1C …
1001A49C  push     0x1035109c                          ; src: (first float 1.0)
1001A4A1  push     eax                                 ; dst: record+0x1C
1001A4A2  call     0x10026eb0
1001A4B0  add      esi, 0x34                           ; stride, [0x10462430] bones
```

So a record is **quat +0x00 / translation +0x10 / scale +0x1C**, with `+0x28..+0x34` untouched by this pass. Every frame, before any sampling, all bones reset to those globals — §4's "reset to defaults", now [V] in our build.

Sampling order and the mask arming, same listing:

```
1001A4E8  mov      edi, 4                              ; base slot index descends 4 → 0
1001A4ED  mov      eax, dword ptr [ebp + 4]            ; slot+4 = its motion list head
1001A4F2  je       0x1001a52a                          ; empty slot: never sampled
1001A4F4  push     0x1045f030 / push edi
1001A4FC  call     0x1001b230                          ; sampler writes only the bones it keys
… after every sampled slot …
1001A50D  mov      esi, dword ptr [0x1045f028]         ; g_pBoneMotionMask
1001A516  test     al, 0x3f                            ; bone has a channel category?
1001A51A  or       al, 0x40                            ; → arm bit6 ("touched")
```

No mask check exists inside sampling: every active slot overwrites per bone, so **the lowest-indexed active base layer that keys a bone owns it** ✓. Blend layers then merge on top:

```
1001A557  mov      bl, byte ptr [ecx + eax]
1001A560  and      bl, 0x80                            ; masks first reduced to bit7 only
1001A571  push     0x1045b820                          ; blend scratch (separate from the pose scratch)
… per bone …
1001A5A3  test     al, al / jns skip                   ; bit7 must be set
1001A5A7  test     al, 0x3f / je skip                  ; and a category present
1001A5C0  call     0x10033220                          ; the merge law of §4a-bis
1001A5C5..1001A5D8                                    ; its four dwords copied into the pose scratch
1001A5DF  call     0x10032a70
1001A5F4 / 1001A609  call 0x100276a0                   ; lerp translation (+0x10), scale (+0x1C)
```

Two points §4/§4a only asserted: **bit6 is armed inline after every base-slot sample** (helper 0x19B00 does the same thing wholesale, and both exist), and the call immediately after the quaternion store is `call 0x32A70`, whose body at that RVA — generated dump of RVA 0x32A40..0x32A71 — is a lone `ret`. "No renormalisation follows the merge" is therefore proven *at the site*, not inferred from absence.

### §4d-addendum — kuluu deleted the frame-to-frame carry; measured clip coverage (2026-10-05) **[V] [measured]**

kuluu had been inheriting an unkeyed bone's record forward indefinitely, which contradicts the reset pass above: a rotation written by a *finished* motion could never be washed out. Removed in kuluu `jw-stack-815 6d8f2e46` — `BonePoseScratch::begin_frame` clears every record before sampling and `sample_joint` writes each bone unconditionally; the crossfade rule that a side which does not key a bone contributes nothing (sampler RVA 0x1B230) stays, because blending an absent channel against bind was what faded weapons out of hands.

Measured on shipped data (`zz-anim-cov`, hume_m skeleton 7072 + its motion block 9672), which is why the carry read as *upper body stuck, legs fine*:

| clip | joints keyed | spine/chest/neck = 49 / 50 / 51? |
|---|---|---|
| `idl0` | 10 — `2,25,27..30,33..36` | no |
| `wlk0` / `run0` / `btl0` | 11–12 (the same lower set) | no |
| `wlk1` | 45 | yes |
| `run1` | 40 | yes |
| `btl1` | 36 | yes |
| `idl1` | **absent** — hume_m authors no upper-body idle clip at all | — |

For a standing PC nobody keys spine/chest/neck, so after any battle motion finished, its torso twist was the only thing left writing those bones. With the reset pass restored they return to kuluu's default (the joint's bind data in `update_joint`), as retail's frame does.

**Open `[I]` on this row:** who fills the reset-pass defaults — globals `[0x10456d2c..0x10456d38]` (quaternion) and `[0x10456d3c]` (vec3). kuluu's fallback is bind; whether retail's globals are per-actor bind transforms or one shared rest set needs a write census on those two addresses (`--disp 0x10456d2c --size 4`, `--disp 0x10456d3c --size 4`) before any non-bind default is claimed.

## 4e. What ApplyPolicy and its handlers do: one mask bit, then per-bone key-frame blending **[V]**

Transcribed in full (`d1_apply_policy.asm`, `d1_policy_h0_full.asm`, `d1_policy_h1_full.asm`). Body RVA 0x19A50..0x19AFD (`ret 0x10`):

```
10019A61  movsx    ecx, word ptr [ebx + 0x32]           ; entry count (§4c)
10019A76  lea      eax, [ebx + 0x3a]                    ; entry array
10019A83  mov      esi, dword ptr [eax]                 ; bone index
10019A92  mov      al, byte ptr [eax + esi]             ; mask[bone]; jns skip → bit7 clear = refuse
10019A9B  and      dl, 0x40 / cmp dl,0x40 / je …         ; bit6 armed = skip (another layer owns it)
10019AA3  and      eax, 0x3f                            ; low 6 bits = category
10019AA9  sub      eax, 0 / je 0x10019ac5               ; category 0 → handler RVA 0x19B30
10019AAB  dec      eax / jne skip                       ; category 1 → handler RVA 0x19EE0; else none
10019AD0  call     0x10019b30                           ; the category-0 handler below
10019AD5  test     al, al / je 0x10019ae2               ; false → mask untouched
10019AD9  mov      eax, dword ptr [0x1045f028]          ; g_pBoneMotionMask
10019ADE  or       byte ptr [eax + esi], 1              ; handler returned true: mask bit0 (category ← 1)
10019AEB  add      eax, 0x54                            ; stride ✓ §4c
```

ApplyPolicy's only global write is that `or byte [mask+bone], 1` — it never touches the pose scratch. Both handlers are per-bone key-frame blends rather than booleans: they convert a float argument with the ftoi helper (`call 0x10311c2c`), initialise an output quaternion via `call 0x32a40`, index **the same entry block** at pool + (masked channel offset + frame) and merge. h0 (category 0): `call 0x10033220` @RVA 0x19C3B then four dword stores @0x19C44..0x19C59. h1 (category 1): two merges, @0x19F91 and @0x1A00E with stores @0x19FEB..0x1AFFC. Key addressing, verbatim:

```
10019F2E  lea      edx, [esi + edi*4 + 0x3e]            ; entry+0x04 = rotation channel-0 offset (edi counts stride 0x54)
10019F32  mov      ecx, dword ptr [edx]
10019F36  je       skip                                 ; offset 0 → constant-only bone
10019F46  and      ecx, 0x7fffffff                      ; sign bit masked off before use
10019F4E  lea      ebp, [ecx + ebx]                     ; ebx = ftoi_round(float arg)
10019F55  mov      ebp, dword ptr [esi + ebp*4 + 0x3a]  ; pool word = an authored key
```

So "interrupt vs queue" in this build means: *for each bone the queued motion keys*, refuse it if the mask says no, otherwise **blend neighbouring authored keys of that bone** through the same `0x33220` law as the blend layers — one merge for category 0, two for category 1. §4a-bis's aside "helper at 0x332D9, result unused" now has a body: `call 0x32a40` wraps RVA 0x32A50, which stores `[ecx]=0,[+4]=0,[+8]=0,[+0xC]=0x3F800000`, i.e. it initialises the merge output to identity before the weighted sum.

kuluu consequence (gaps row D1): write-set = bones a clip keys ∩ mask allows; per-bone ownership by sampler order; one merge law everywhere (`merge_layer_rotation`) — all landed with this pass. Not reproduced, and named as such: category-dispatched neighbour-key blending (kuluu interpolates within a clip through its own normalising `nlerp`, whose law stays [I] per §4a-bis), because it needs the sign/flag question in §4c settled first.

## 5a. Verified in OUR build: LockLookAt ≠ ActorRotation (byte), correcting §3's shared lead [V]

§3 listed `CMoLockLookAtDriveTask` / `CMoActorRotationDriveTask` together as the look-at lead. They are **two different mechanisms**
in our TDS 0x6A995428 build, so they must be treated separately: ActorRotation converts authored degrees (three pi/180 fmuls in its ctor); LockLookAt does not touch any degrees float and carries no angle operand - it aims a joint at the locked target by geometry. Full evidence + the stage-stream feeder boundary (`interpret` has exactly two external callers, both gating through `0x57C20`) is in [drivetask.md](drivetask.md) §8; joint-look consequence in [joint.md](joint.md) §9a. Neither class's numbers extracted yet - S3 parked pending DAT access.

## 5b. Verified in OUR build: dancer bone state is persistent frame-to-frame — an unkeyed node keeps last frame's transform **[V]**

Evidence (bytes in [lookat.md](lookat.md) §E.9, all read against TDS 0x6A995428 this pass). The model holds a live
node array `[this+0x14]` — node index from `call 0x35390`, entry stride 64 (one 4×4) — and pass 2 of the bend *loads*
that transform (`mov edx,[edi+0x14]; shl esi,6; add esi,edx` at 0x2B004..0x2B00F, then `rep movsd` copying 16 dwords
at 0x2B018), converts it to a quaternion (call 0x32E70 at 0x2B021) and multiplies its own contribution onto it
(0x32B50 twice, 0x2B066/0x2B06D) before writing the per-bone override entry `0x1045F030 + bone*0x34`. A pass whose
only access to a node is read → multiply → store into another table is coherent only if that transform survives from
frame to frame; nothing here rebuilds it from the bind pose, and the override entries are likewise read-modify-written.

**Kuluu consequence (landed `476ea336`).** A joint no active clip keys must keep its previous local transform. kuluu's
pose pass re-derived every unkeyed joint from bind each frame, so a sparse clip — turn-in-place while engaged resolves
from the battle set first — pulled an equipped weapon back to its bind position (play-test row P3). `carry_unkeyed_channels`
(ffxi-actor/src/skeleton_instance.rs) is that memory, cleared with the coordinator on a pose-state reset.

Tier: **[V] for every byte above**; "persists frame-to-frame" is the reading those bytes force rather than an
independently observed initialisation. If anyone needs it nailed harder, the settling read is whoever allocates and seeds
`[this+0x14]` — confirm entries are seeded from bind once at model load, not re-seeded per frame.

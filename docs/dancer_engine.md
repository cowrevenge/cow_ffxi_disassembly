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
    blend scratch **0x1045B820**; mask array **0x1045F028**; bone-count global **[0x10462430]**.
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

## 5a. Verified in OUR build: LockLookAt ≠ ActorRotation (byte), correcting §3's shared lead [V]

§3 listed `CMoLockLookAtDriveTask` / `CMoActorRotationDriveTask` together as the look-at lead. They are **two different mechanisms**
in our TDS 0x6A995428 build, so they must be treated separately: ActorRotation converts authored degrees (three pi/180 fmuls in its ctor); LockLookAt does not touch any degrees float and carries no angle operand - it aims a joint at the locked target by geometry. Full evidence + the stage-stream feeder boundary (`interpret` has exactly two external callers, both gating through `0x57C20`) is in [drivetask.md](drivetask.md) §8; joint-look consequence in [joint.md](joint.md) §9a. Neither class's numbers extracted yet - S3 parked pending DAT access.

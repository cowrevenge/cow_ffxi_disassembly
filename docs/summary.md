# FFXI retail client — research summary



A cross-pass synthesis of what we have **verified** in `FFXiMain.dll` and what we

**believe** the client does, for the purpose of bringing the kuluu remake to retail

parity ("retail is king, dll is king"). Each section cites the pass that verified it.



Passes: **M** = [movement.md](movement.md) (walker), **C** = [camera.md](camera.md)

(event camera), **F** = [mob_animation.md](mob_animation.md) (animation driver), **T** =

[target_track.md](target_track.md) (target-track), **J** = [joint.md](joint.md) (skeleton

joint layer), **D** = [drivetask.md](drivetask.md) (overlay DriveTask layer). Conventions

(RVA base 0x10000000, POL1-packed `.text`, evidence tiers) in [../README.md](README.md).



## 0. WHY we are digging (do not lose this)



We dig `FFXiMain.dll` for one reason: **kuluu's movement/animation feel is visibly wrong, and

the user's standing ruling is "retail is king, dll is king" — no invented constants.** Each dig

must pay for itself in a symptom the user can see in-game:



| # | Symptom the user reported (paraphrased) | What the dig owes us |

|---|----------------------------------------|----------------------|

| S1 | While strafing a locked target, upper body/legs turn the wrong way; weapon vanishes with certain DAT choices | The retail rule for Head/Body/Legs/Weapon heading per state (no-target / target / locked), incl. "force toward target", not shortest-arc |

| S2 | Idle↔walk shows a seam — same clip "restarting" instead of continuing from shared key points | How retail *stores and blends* keyframes (`sqmoKeyChannel`/`sqmoMixerMotion`), i.e. overlap/blend, not clip restart |

| S3 | Head looks at the target to a limit then **snaps back straight**; body tugs slightly L/R; head turns on target change | The actual mechanism + numbers for limit / slew(reset) / tug — now believed to be **authored degree values fed to a DriveTask**, not a clamp constant |

| S4 | Camera spring/leash feel (loaded by movement, pinned behind, catches up), and locked-camera catch-up ≤1 s bounded so it never swings past the player | Retail's spring/re-anchor law + its constants (M11/M15/M17/M18; leash value still not dll-verified) |



**Acceptance test for any of these:** a kuluu build the user can drive — press keys, watch the

character — where the symptom is gone *and* nothing else regressed. A doc-only conclusion that

doesn't unblock one of S1–S4 is not progress.



**Guardrails learned the hard way:** never quote a value we haven't read from bytes; label

inference as inference; if the answer lives in DAT data rather than `.rdata`, say so early instead

of guessing numbers.



### Oracles available (things that can answer us without guessing)



| Oracle | What it gives | Trust posture |

|---|---|---|

| **Our unpacked `FFXiMain.dll`** (TDS 0x6A995428) | the only thing that is ground truth for *this* build | [V] after bytes are read |

| **Live client observation** ([O]) | what retail *looks like*, which sets acceptance criteria | never explains mechanism; drives S1–S4 pass/fail |

| **WGINC/DancingMad** @ 4243c7e — their master `FINDINGS.md` + pipeline map (see [dancer_engine.md](dancer_engine.md)) | names, class hierarchy, module census, struct shapes, vtable slot meanings | **[web]** — older PC build + PS2; RVAs unusable |

| **PS2 `SCUS_972.66` DWARF v1** (Dec-2003 disc) | 2,758 named types with **every member name/offset/type**, 12,227 function symbols, 1,936 named `sq*` functions ⇒ *member names for our unnamed offsets* | [web]; PS2 renames this layer (`Kz*`/`Ym*`), and PC-only classes like the DriveTasks may have no DWARF counterpart |

| **Their independent C++ reconstruction** + `ps2_dwarf_tools.zip` (DWARF-1 parser, class indexer, JSON type export) | third-party cross-check on any struct claim | [web] |

| XIClient source | navigation only | already demoted ([§3](#3-bad-leads-found)) |



Discipline adopted from DancingMad: **names that came from IDA/Lumina similarity are hints, not

evidence** — a 33-byte body match is not a symbol.



**Builds.** M/T/J were cut against TDS **0x6A995428** (retail-2026-09, the current

install). F/C/E were cut against TDS **0x6A7297F5** (older). RVAs are build-specific; a

few global addresses moved between builds (noted inline). Every RVA in the pass docs is

only valid against that pass's build.



Tiers used below: **[V]** = byte-verified in the DLL (pass cited); **[I]** = inference

from verified parts; **[O]** = user's retail observation.



---



## 1. What we are looking for



(This section predates §0 and is kept for continuity; §0 is authoritative.) The immediate

target: the retail mechanism + numbers behind head/target-look, to replace kuluu's hardcoded model

(`HEAD_MAX_TURN_RAD`, `HEAD_VIEW_CONE_COS`, `HEAD_SLEW_TAU_FRAMES` in

`kuluu-render/src/ffxi_actor_render.rs` ~3241, plus the state-2 body behavior in

`kuluu/src/view_native/input.rs`):



- **Head-look limit** — the max angle the head turns toward the target.

- **Reset-to-straight** — how/when the head snaps back to straight.

- **Head slew rate** — how fast the head turns.

- **Body-tug** — the very small L/R body rotation that follows the head.



More broadly: a correct mental model of retail **walker**, **camera**, and

**animation/skeleton** behavior, and how they interlock, so kuluu matches the *model*,

not just a number.



---



## 2. Good leads found



- **J pass — the skeleton joint integrator [V].** The per-joint update loop

  (back-edge `jmp 0x4B87E`) does `joint_angle += dt × curve(global_clock)`, wrapped to

  (−π, π]. `dt` is the frame tick (0x14CF0, via clock object 0x47BFA8 `+0xEB0`);

  `curve` is a per-class keyframe evaluator (0x54500 linear / 0x547A0 smooth) driven by

  the global animation clock 0x65CB14. **This is the strongest lead for the head

  look-at**: an integrator of a velocity curve naturally produces *follow → saturate at a

  limit → settle*, and a small-fraction body curve is exactly the "body tug." The user's

  new note ("this is done in the skeleton pieces?") points here.

- **T pass — target acquisition [V].** `LockedTarget` = 0x157CF0 (`[obj+0x21]==1` gate +

  0x1598A0 entity-table scan) with fallback to the entity slot 0x487F58 (0x81600). This is

  how the client knows *which* target to look at / steer toward. (The T-pass state machine

  itself is inert — see §3.)

- **M pass — the whole walker [V].** Control function 0xA65CB..0xA70AB: circle-walk

  (W/S radial, A/D angular about the camera azimuth), the 0.05/0.9/1-3 speed bands, Q/E

  rotating camera+body, camera re-anchor only while a key is held, spring-back. This is the

  retail "polar / tank" walker, verified end to end.

- **C pass — look-at basis + camera manager [V].** The look-at yaw is the **negated

  atan2** (`fpatan(-(y2-y), x2-x)`), the same basis kuluu's round-12 look-at fix uses.

  Camera manager singleton (0x4568FC+0x50 @ 0x6A995428 / 0x45693C+0x50 @ 0x6A7297F5) with

  eye/look-at/direction fields.

- **F pass — the animation driver [V].** Wire (0x0E status/sub, 0x28 action) → packed

  RenderFlags → per-frame flush (0x95DB0) → actor create/destroy (CXiSkeletonActor, vtable

  0x330F40) → sub→fourcc table (0x35AF60) → routine resolver (0xCE490, model DAT) →

  scheduler nodes (actor +0x68) → stage stream (0x05 skeleton anim, 0x07 lock, 0x02 VFX,

  0x0A sound, …). The complete mob-animation mechanism.

- **J pass — the x87 flag-test idioms, decoded [V] (J10).** Every `fnstsw ax` →

  `test ah, imm8` pair in `.text` uses one of four masks: `0x05` = ≥ / < , `0x44` = ≠ / = ,

  `0x41` = above-or-unordered, `0x01` = C0 alone (per SDM Vol 2A Table 3-21). This unlocks

  FPU branch structure generally — it closed the curve evaluators' u-vs-0.5 selection and

  exposed their divide-by-zero guard, and it shows **no** dependence on sticky exception bits.

  Details + reproduction recipe: [joint.md](joint.md) §8a.

- **J pass — a real atan2 site at 0x5EA7F..0x5EA93 [V] (J11).** `faddp`/`fsqrt` then

  `fpatan` and `fsubr dword [esi+0x94]`: an object angle minus the atan2 of two locals, i.e.

  a plausible look-at/aim computation. The current lead for §9.

- **D pass — the overlay mechanism itself: `CMo*DriveTask` [V].** The pose is not just

  animated; it is *driven*. Tasks: `CMoLockLookAtDriveTask` (0x80),

  `CMoActorRotationDriveTask` (0xA0), `CMoActorColorDriveTask` (0x88), `CMoLockColorDriveTask`

  (0x7C), `CMoPathDriveActorTask` (0xB0) — siblings of `CMoSchedularTask`, located via Square's

  own class-descriptor records (`{name,size,parent}`, 425 parsed) and the RTTI accessor thunks

  that sit *in* their vtables. **This is the answer to "is look-at part of the animation or

  layered on top": layered on top, by a named per-task overlay.** [drivetask.md](drivetask.md)

- **D pass — rotation in this layer is authored in DEGREES [V].** `0x1032A9F4 = 0.0174527783`

  (π/180) is referenced *only* inside `CMoActorRotationDriveTask` (0x5FA95, 0x5FABB, 0x5FACB).

  Its update at **0x5FB30** lerps a from-tuple (`+0x80/+0x84/+0x88`) to a to-tuple

  (`+0x90/+0x94/+0x98`) gated by a mode byte `+0x7c` ∈ {0,1,2} and a countdown `+0x74` against the

  J-pass clock dt — offsets consistent with its descriptor size 0xA0. Prime hunting ground for

  the S3 limit/slew/tug values as *arguments*.

- **D pass — two different angle-wrap conventions exist [V].** DriveTask layer wraps with

  `6.283` (0x10329D2C, deliberately inexact) and `±3.1415`; J pass's integrator uses exact ±π/2π

  (`0x32A3B0/B4/B8`). Parity work must not assume a single wrap constant.

- **D pass — the middleware is named [V].** Embedded build paths expose Square's *dancer*

  modules: `sqMotion` (sqmoKeyChannel / sqmoMixerMotion ⇒ keyframes + blending for S2),

  `sqHierarchy/sqhiNode`, `sqSkeleton/sqskJoint`, `sqModel/sqmdModel` (**`sqmdModelLookAt()`

  takes a `<boneNdx>`, range-checked**), `sqOpcode` (matches F-pass stage stream). Full table in

  [drivetask.md](drivetask.md) §1.

- **DancingMad ingest — the `dancer` module census reproduces independently [V vs web ✓].**

  Our own scan of `__FILE__` strings gives **16 modules / 84 source paths** ([tools/our_modules.py](tools/our_modules.py));

  their per-module file counts match on sqModel(7), sqMotion(12), sqSkeleton(3), sqHierarchy(1),

  sqImage(5), sqConstraint(1), sqDeform(1). One known mismatch: `sqSkin` files (theirs 5, ours 4).

  Full map in [dancer_engine.md](dancer_engine.md) §1.

- **DancingMad class names verified present in OUR build [V].** Every name they rely on exists in

  our descriptor table with sizes: `CMoLockLookAtDriveTask` 0x80, `CMoActorRotationDriveTask` 0xA0,

  `CMoSchedularTask` 0x14A, `CMoSkeletonElem` 0x1D9, `CXiActorDraw` 0x34, the four-level actor

  chain (Atel/Control/Collision/Skeleton = 0xD4/0x5C4/0x5F8/0xA0C), `CYyMotionQue` 0x40, `XiZone`

  0x1DC ([tools/xcheck_dmad.py](tools/xcheck_dmad.py)). Their recovery method — `class_descriptor_t`

  nodes in `.rdata` — is the same structure our D pass found independently.

- **Their actor vtable slot map, if it holds in our build, hands us S1's home [web].** Per-actor PC

  draw hook = **slot 162** (not slot 8); slots **195–209** are the movement/animation lock queries

  (`IsControlLock`, `IsDirectionLock`, `IsConstrain`, `IsFreeRun`, `IsWalkLock`, `IsParallelMove`);

  slot 8 = per-frame update. Verify before coding against it.

- **Their blending account was the leading hypothesis for S2 — now VERIFIED in our build (§4a).** Pose scratch

  filled by **5 base layers (slot 4→0, lower wins) + 2 blend layers** (`Quat_NLerp` rotation,

  `Vec3_Lerp` translation/scale), gated by a per-bone byte mask (bit 6 = touched by a base layer this

  update; bit 7 = bone accepts blends), same bits deciding interrupt-vs-queue. ⇒ retail *masks and

  blends per bone* rather than restarting the whole pose.

- **The interpreter address cross-confirms DancingMad, and refines how we use them [V].** Their

  `CMoSchedularTask_Interpret 0x10057FB0 … jump table 0x1005DC1C` matches our bytes *exactly* (we

  found that function and its **196-entry** table independently while locating the DriveTask

  constructors). So `[web]` addresses must be checked **per region**: some coincide, some don't

  (`XiZone`'s singleton differs). Never assume either way.

- **Key globals [V]:** entity table (0x480AF0 @ 0x6A995428 / 0x480B30 @ 0x6A7297F5,

  stride 4, `XiAtelBuff` 684 bytes); actor `CXiSkeletonActor` (vtable 0x330F40, 64 slots);

  clock object 0x47BFA8; tick 0x14CF0 (seconds, clamped ≤ 1.0); animation clock 0x65CB14.

- **D1 evidence pass — the queue/mask/policy machine is byte-verified; no freeze during blends [V].**

  UpdateAllChannels 0x1A420..0x1A660 (sole caller = Model_AnimateAndPose, site 0x1002A27B): pose

  scratch 0x1045F030 stride 0x34/bone, blend scratch 0x1045B820, mask array 0x1045F028, bone count

  [0x10462430]; base slots this+0x50 (5 × 0x14) sampled with index arg descending 4→0; ≤2 blend

  layers sample into the separate scratch and merge per bone only where mask bit7 ∧ low-6 nonzero

  (quat via NLerp-style 0x33220, un-renormalised ✓; trans/scale lerps 0x276A0). The slot sampler

  0x1B230 calls vtable+0x38 per active layer **every frame — old and new clips both keep sampling

  live through a crossfade** ⇒ kuluu's frozen-snapshot seam is non-retail; the fix shape is to

  advance both blend sides. ApplyPolicy 0x19A50 loops authored per-bone entries (count = u16 at

  desc+0x32, array +0x3A stride 0x54) and dispatches on mask bit7/bit6/low-6 to handlers 0x19B30 /

  0x19EE0; the setNext wrapper 0x1AB60 enqueues via scheduler object [0x1047D128] → 0x10072FB0

  before policy. The smooth-interp conflict resolves negative for motion: all 46+26 call sites of

  0x547A0/0x546F0 sit in CMo* effect-element code (~0x10049Axx–0x1005ECE8), zero inside sqmo.

  Full detail: [dancer_engine.md §4a](dancer_engine.md).



## 3. Bad leads found



- **T-pass state machine — inert in 0x6A995428 [V].** The ±44.987° bracket

  (0xA80D0 + sibling 0xA82A0) is overflow-flag-gated and returns only {0,1}; `state_0x598`

  is never written 2/3/4 (7-writer census). The **0.125** ease rate (0x32A3BC) and the

  **±44.99°** bracket are **not** the live head numbers. *Do not port 0.125 or ±44.99°

  into kuluu.*

- **16-step compass (0xA7851) — dead [V].** 0 callers in the build.

- **0x487F98 auto-run slot — read-only, zero [V].** Single `.text` reference; dead.

- **Left/right arrow yaw — dead in this build [V] (M19).** The key slots are zero-cleared

  before the multiply; there is no retail arrow-yaw rate to port.

- **`[obj+0xE0]` as a unique joint slot — wrong [V] (J9).** It is a generic offset: 222

  accesses / 28 writes across the binary. The prior 13-site "census" missed the

  `fstp`/`fst` (D9 9x / DD 9x) stores. Track the joint *object*, not the offset.

- **0x3138BA as fmod — wrong [V] (J3).** It is `mov edx, 0x103CFFE0; jmp 0x31DD30`, an FPU

  helper/exception thunk.

- **Per-entity update (0x8F000..0x93500) as the head-limit home — no [V] (J8).** Zero FPU

  compares against `.rdata` constants in that region; the limit is not a dot-vs-const

  clamp there.

- **"Corrupted capstone x87 table" — wrong [V] (J10).** Capstone 5.0.7 decodes every

  disputed D8–DB cell correctly; `DB F8..FF` is *genuinely invalid* (`<undecoded>` is right)

  and **FCOMIP = `DF F0+i`**, not a `DB` encoding. The real failure mode is **linear-sweep

  alignment** — decoding that starts mid-instruction drifts into interleaved float constant

  pools; capstone's `skipdata=True` recovers on its own. Patching decode tables would inject

  wrong instructions, so no tool change was made. M17/M20/J1–J9 are unaffected (they use

  memory-operand forms that always decoded correctly).

- **"Double-fpatan look-at controller at 0x5EA03 / 0x5EF03" — wrong [V] (J11).** Both RVAs

  hold `33 C0` = `xor eax, eax`: sweep artifacts, not instructions. Chase 0x5EA7F..0x5EA93

  instead.

- **A specific vtable slot index for 0x5E9C0 — unverifiable today [V].** A code-pointer-run

  scan puts the pointer to it at `+0x134` inside one contiguous run starting `.rdata 0x32B890`

  (≥ 505 entries). Adjacent tables merge into a single apparent run, so slot numbers there are

  meaningless until real vtable boundaries are established.

- **XIClient source as ground truth — unreliable [O/I].** Used only as a navigation map for

  *where to look*; its layout (e.g. the view matrix) conflicts with the retail C2 layout.

  Every finding is verified in the DLL, not taken from XIClient.



## 4. How we think the ffxi **walker** works (M pass)



- One function, **0xA65CB..0xA70AB**, runs on the per-frame local-player tick [V].

- Reads analog axes from the input manager (0x57876C): **W/S = action 4, A/D = action 5

  (sign-inverted), Q/E = actions 6/7** [V] (M16).

- Builds `dir = {-key2·speed, 0, key1·speed}` in world axes [V] (M4).

- **Speed/deadzone law** (0xA78D0) [V] (M3): `mag=√(k1²+k2²)`; `mag≤0.05`→stand;

  `0.05<mag≤0.9`→walk (×1/3); `mag>0.9`→run (×1.0). Axes are normalized first, so a W+D

  diagonal is a unit vector (**diagonals move at full speed, not √2**). Scale stored at

  `actor+0x594`.

- **Circle-walk** (0xA79A0) [V] (M5): `dir` is rotated by the **camera azimuth**

  (`fpatan(-[cam+0x2C],[cam+0x24])`). So **W/S move along the camera axis (radial), A/D

  move perpendicular (angular, around the camera position)**. This is the retail

  "polar / tank-style" walker.

- Ground re-orthogonalization; in air `dir ×= 0.25` [V] (M8).

- `dir ×= dt` (0x14CF0 tick) [V] (M4).

- Contact gate (0xA8770) then `*pos += dir` inline (0xA6F31) [V] (M9). Live position at

  `ent+0xD4/+0xD8/+0xDC` [V] (M14).

- **Facing** (M10) [V]: the body faces the **direction of travel** (or the

  camera-rotated input while turning); `yaw = -fpatan(dir.z, dir.x)` → `actor+0xE8`. The

  camera never drags the facing.

- **Q/E** (M15) [V]: drives **both** the camera azimuth (integrates `cam+0x48`) and the

  body heading (re-assigned to keep facing travel). Not a rotate-in-place.

- **Camera re-anchor** (M11) [V]: the camera re-anchors to the player **only while a

  movement key is held**; otherwise it stays where the user aimed it (the free camera).

- **Auto-run** (M6) [V]: flag 0x487F81 + unit vector 0x487F64..; overwrites the movement

  vector; forward-hold rotates it (circle-turn).



## 5. How we think the ffxi **camera** works (M + C pass)



- **Camera manager** singleton: 0x4568FC+0x50 (@0x6A995428) / 0x45693C+0x50

  (@0x6A7297F5) [V]. Fields: `+0x24/+0x2C` horizontal direction (x,z); `+0x44..+0x4C`

  cached eye; `+0x50..+0x58` cached look-at [V] (M12/C2).

- **Free (unlocked) camera** [I from M11 + O]: it does **not** continuously follow the

  player. It re-anchors only while movement keys are held; the user aims it (mouse/Q/E)

  and it "sits" until re-anchored or the radial distance leaves its band.

- **Q/E** integrates the azimuth (`cam+0x48 += tick·axis6·0.10666667`) [V] (M15).

- **Zoom (focal)** integrates `±tick·6.0` focal units, clamped 900.0 / 242.0;

  both zoom keys snap the focal to the 350.0 third-person default on the next

  frame; the mouse wheel is the same path [V] (M17). FOV = 2·atan2(192, focal)

  [web, E15]: 242 ≈ 76.9°, 350 ≈ 57.5°, 900 ≈ 24.1°.

- **Spring-back** (M18) [V]: mode byte 0x456DB0 + reference angle 0x456DB4; when the turn

  keys come up the camera eases back toward the reference (the "catch-up" the user sees).

  Law closed 2026-10-04: stored ref = axis·π/2·turn per facing event, consumer orbits look-at

  by −ref ×6/max(dist,.01) while mode ≠ 0; the old "FPU-underflow / undecodable" claim was a

  sweep artifact and is retracted (movement.md §11).

- **Mouse aim** [V, closed 2026-10-04 (M21–M23)]: **position-based**, not delta-based — anchor→cursor offsets normalized toward screen edges (saturating at ±1), `atan2−π/2` state angles, then emitted as **virtual arrow-key presses** (ids 0x16–0x19, tick-ramped counter) into the same integration the keyboard uses; steering mode quantizes cursor direction to **16 compass sectors**. No rad/px sensitivity constant exists in this build.

- **Locked camera** [O + I]: when a target is locked the camera **focuses the target** and

  catches up smoothly (fast, ~≤1 s, bounded so it doesn't swing past the player); Q/E and

  arrows do nothing while locked. The catch-up reuses the same spring, at a tiny value.

- **Event camera** (C pass) [V]: look-at opcodes 0x4A/0x79/0x1E pose actors with the

  **negated atan2** basis; 0x46 DEFCAMERA enables/disables user control and restores

  position; work-slot↔camera scale is **1/32** (0x32A22C); focal 280 (first-person) /

  350 (third).



## 6. How we think the ffxi **animation / skeleton** works (F + J pass)



Two layers: the **driver** (F pass) picks *which routine/clip* to play; the **skeleton**

(J pass) turns that into *joint angles*.



**Driver (F pass) [V]:**

- Server 0x0E (status/anim/sub) and 0x28 (action) are **not stored** in named fields;

  status is XOR-diffed into `RenderFlags0`, sub packed into `RenderFlags1` (0x9BCF7).

- Per-frame flush (0x95DB0) rebuilds the actor when RF3 bit 0 is set: destroy (0x92910) /

  create (0x8F750) a `CXiSkeletonActor` (ctor 0xC525E, vtable 0x330F40). INVISIBLE

  (status 3) = destroy; the next status 1 = fresh create (so `init` replays).

- A sub change plays `table[sub]` from 0x35AF60 (`[init ini1 ini2 ini3]×2`) via actor

  slots +0x298/+0x29C. The fourcc is resolved by 0xCE490 against the **model DAT** (then

  shared libs). The routine's stage stream is copied into scheduler nodes (actor +0x68).

- Stage ops: 0x05 skeleton animation (clip fourcc + frames), 0x07/0x59 animation lock

  (ActionTimer1 refcount), 0x02 VFX generator, 0x0A/0x0B/0x4A sound, 0x03/0x09 call

  routine on source/target, 0x5E knockback, … (full ~85-op list in F §3.5).



**Skeleton (J pass) [V]:**

- Each joint's angle is **integrated**, not snapped: `angle += dt × curve(anim_clock)`,

  wrapped to (−π, π] (loop back-edge `jmp 0x4B87E`). Three sibling slots: `+0xE0`, `+0xE4`,

  `+0xE8`; an "updated" flag at `+0x187`.

- `curve` = a per-class keyframe evaluator over (x,y) points at table+0x30/+0x38/…:

  0x54500 (linear lerp) or 0x547A0/0x546F0 (quadratic "smooth", branch taken iff u ≥ 0.5 —

  resolved via the flag idioms, J10; includes a divide-by-zero guard when two segment

  boundaries compare equal).

- Driven by the **animation clock 0x65CB14** and the **frame dt** (0x47BFA8 `+0xEB0` =

  0x14CF0). Per-joint param struct: `{word (6-bit index at bits 13–18), scale@+4,

  scale2@+8}`.

- **Interpretation [I]:** the retail head/body motion is therefore *data-driven* — the

  limit/slew/reset are properties of the authored velocity curves + the integration, not a

  single clamp+slew constant. This matches the observed "follow to a limit, settle, body

  tugs slightly."



## 7. How we think ffxi works (top-level)



- `FFXiMain.dll` ships with `.text` rawsize 0 and a **POL1** bit-packed section; an entry

  stub unpacks the real code at load (0xBB1A60/0xBB1AFB). All game logic is in this DLL

  [V] (F24/F25).

- World state = a **global entity table** (`XiAtelBuff`, 684 bytes, stride 4, indexed by

  target index) [V] (F28). Each entity that has a visible model owns a

  `CXiSkeletonActor` (`ActorPointer` at +0xA0) [V].

- A **per-frame tick** (0x14CF0, ~1/60 s, clamped ≤ 1.0) drives [V] (M20):

  - **Local player** → control function 0xA65CB (input → movement → position + facing).

  - **All entities** → per-entity update 0x8F750 + flush 0x95DB0 (flags → animation).

  - **Camera** → camera-manager update (Q/E, mouse, zoom (focal), re-anchor, spring-back) + events.

  - **Skeleton** → per-joint integrator (angle += dt × curve).

  - **Event VM** → cutscene opcodes.

- **Server→client:** 0x0E (status/anim/sub), 0x28 (action), POS (position) packets set

  entity flags; the client animates. **Client→server:** the client is authoritative for

  local movement/camera and reports position back (0x47/0x5C). The client is king for

  *feel* (rendering, animation, movement, camera); the server is king for *rules* [I].



## 8. How we think they all talk to each other



```

Keyboard / Mouse

   │

   ▼

Input Manager (g_pCTkInputCtrl @0x57876C)

   │  axes: W/S=4, A/D=5, Q/E=6/7  +  discrete key checks

   ▼

Control Function 0xA65CB  (local-player tick)

   ├─ speed/deadzone (0xA78D0) ─────────────► scale

   ├─ circle-walk (0xA79A0): dir ×= RotateY(cam azimuth)

   │        ▲ reads camera direction (+0x24/+0x2C)

   │        │

   │   ┌────┴───────────────────────────────┐

   │   │ Camera Manager (0x4568FC+0x50)     │

   │   │  ← Q/E (azimuth cam+0x48), mouse,  │

   │   │    zoom, re-anchor (M11),          │

   │   │    spring-back (M18), event 0x46   │

   │   │  focus = player (free) / target    │

   │   │           (locked)                 │

   │   └────────────────────────────────────┘

   ├─ target-track (0xA7B80) if target exists

   │        ▲ LockedTarget 0x157CF0 / slot 0x487F58

   ├─ dir ×= dt (0x14CF0)  →  contact gate (0xA8770)

   └─ *pos += dir (0xA6F31);  facing = direction of travel (M10)

   │

   ▼

Entity (XiAtelBuff)  ◄── server 0x0E / 0x28 / POS set RenderFlags

   │

   ▼

per-entity update 0x8F750  +  flush 0x95DB0

   ├─ actor create/destroy (CXiSkeletonActor, vtable 0x330F40)

   └─ sub → fourcc (0x35AF60) → routine (0xCE490, model DAT) → scheduler nodes

            │

            ▼

       stage stream (0x05 anim, 0x07 lock, 0x02 VFX, 0x0A sound, …)

            │

            ▼

   Skeleton joint integrator (J pass):  angle += dt × curve(anim_clock 0x65CB14)

            │   head curve ◄── target position   (head look-at — OPEN)

            │   body curve ◄── small fraction    (body tug — OPEN)

            ▼

       bone matrices → render

```



The shared **clock** (0x14CF0 dt + 0x65CB14 anim clock) is the common heartbeat: it scales

the walker (`dir ×= dt`) and integrates the skeleton (`angle += dt × curve`). The

**camera manager** is the shared pose source: the walker reads its azimuth, and Q/E /

mouse / re-anchor / events write it. The **target** (LockedTarget / 0x487F58) is the shared

"what am I looking at" that feeds target-track (steering + facing) and — we believe — the

head look-at curve.



## 9. Where we are looking next

**Closed since the older text below was written [V]** (details in
[drivetask.md](drivetask.md) §12–§14): the dispatch-bound correction — **194** jump-table entries
(`cmp edx,0xC1`); ActorRotation's ctor and update law closed to the byte (§12); the driven object and its
angle record named from our own RTTI (§13 — component 1 at `actor+0x48` is the heading) — and kuluu now
**runs that law** (`jw-stack-815 4b8f0679`). The carrier table (§9.5b there) is answered by reading both
top-ranked carriers' handlers (§14): `0x28`/case 38 writes authored transition parameters onto the actor's
element list at `[actor+0x674]`; `0x62`/case 96 queues a one-shot scripted yaw turn (pending pair
{`actor+0x870 = |Δ|`, `actor+0x874 = signed Δ`} applied once into accumulator `actor+0x620`, cleared at RVA
0xC67D4). Neither touches clip selection — the idle↔walk seam fix stands as landed without them. The
duration fetcher's scale is interpreter field +0x9c (§14.2). Closed 2026-10-05 by re-read **[V]**
(§14.3): the consumer gates (`+0x7A4 == -1`, nesting counter `+0x86C` with its accessors and ctor defaults),
the producer that queues the pending pair (fn 0x5AF2C, script-context gated, heading Δ from the §13 record via
vtable `0x1C0`), and the `actor+0x620` facing-site bands — those sites **only wrap-normalize**; `+0x620` is
component 1 of a second angle set (`+0x61C..+0x628`) whose consuming method (0xC817A, virtual) is still
unresolved. Remaining named read in this region: producers of `[interp+0x9C]`.

**Closed 2026-10-05 [V] — gaps row D3, per-frame facing order (M27,**
[movement.md](movement.md) **§8a):** the local-player routine 0xA65CB..0xA70AB writes heading three
times — @RVA 0xA6988 pre-integration on the steer/ease branch (paired with the M18 spring setter), and
@RVA 0xA705B / 0xA709D **after** `*pos += dir`, computed from that same travel vector, immediately before
`ret`. When not free-run or not moving it writes no facing at all, which is how an authored drive-task
angle survives a locked-animation tick. kuluu's fixed chain has this precedence already → no ordering change.

**Standing research-open queue (order set by Shane):** producers of `[interp+0x9C]`; the follow-actor slot
global **`[0x10487F74]`** (guarded by `mov ecx,[0x10487f74]; call 0x10081550; jne` @RVA 0xA7373 in the
sibling heading writers, and neighbours `[0x10487F6C]`, `[0x10487F81/88/89]` seen in the facing fn); the
`0x85240 / 0x85270` candidate-iteration semantics from M14; and fn **0x20446**.

*Also closed 2026-10-04 (camera/input side):* **C4** — M18's spring reference-angle expression is
decodable (the "FPU underflow" was a mid-expression sweep artifact; stored ref = axis·π/2·turn,
movement.md §11 correction); today's whole-file E8 scan re-verified M18's caller census byte-exact
(six sites in the facing fn 0xA65CB + one camera-state reset call at 0x1E685). **C3** — mouse aim law closed:
position-based offsets → `atan2−π/2` → virtual arrow presses 0x16–0x19 (+ 16-sector steering);
no rad/px sensitivity exists in this build (movement.md §10a, M21–M23). No open DLL read remains
for any gaps row except B4's ruling-gated items.

**S3 mid-dig narrative (head limit/slew/tug hunt, steering question, user head observations, the old
sqmoKeyChannel conflict) moved verbatim — with status tags — to [docs/lookat.md](lookat.md) §F.**
All of it is closed or superseded there: limits are authored data (§E/§E.8), the steering question was
answered by ruling + W-pass (look-at is a bone mechanic, never facing), and the interpolation conflict
resolved [V] in dancer_engine.md §4a.

## 10. Look-at — content lives in [docs/lookat.md](lookat.md) (§A menu model · §B walker rule set + gate-chain bytes added 2026-10-05 · §C verification census · §D port guidance · §E bend, ellipse clamp, authored limits · §F carried-over leads and observations)

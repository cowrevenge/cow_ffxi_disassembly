# FFXI retail client — research summary

A cross-pass synthesis of what we have **verified** in `FFXiMain.dll` and what we
**believe** the client does, for the purpose of bringing the kuluu remake to retail
parity ("retail is king, dll is king"). Each section cites the pass that verified it.

Passes: **M** = [movement.md](movement.md) (walker), **C** = [camera.md](camera.md)
(event camera), **F** = [mob_animation.md](mob_animation.md) (animation driver), **T** =
[target_track.md](target_track.md) (target-track), **J** = [joint.md](joint.md) (skeleton
joint layer). Conventions (RVA base 0x10000000, POL1-packed `.text`, evidence tiers) in
[../README.md](../README.md).

**Builds.** M/T/J were cut against TDS **0x6A995428** (retail-2026-09, the current
install). F/C/E were cut against TDS **0x6A7297F5** (older). RVAs are build-specific; a
few global addresses moved between builds (noted inline). Every RVA in the pass docs is
only valid against that pass's build.

Tiers used below: **[V]** = byte-verified in the DLL (pass cited); **[I]** = inference
from verified parts; **[O]** = user's retail observation.

---

## 1. What we are looking for

The immediate target (carried from the T-pass handoff): the retail constants behind the
head/target-look behavior, to replace kuluu's hardcoded model
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
- **Key globals [V]:** entity table (0x480AF0 @ 0x6A995428 / 0x480B30 @ 0x6A7297F5,
  stride 4, `XiAtelBuff` 684 bytes); actor `CXiSkeletonActor` (vtable 0x330F40, 64 slots);
  clock object 0x47BFA8; tick 0x14CF0 (seconds, clamped ≤ 1.0); animation clock 0x65CB14.

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
  0x54500 (linear lerp) or 0x547A0/0x546F0 (quadratic "smooth", branch at u=0.5).
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

**The head limit/slew/tug.** Per the J pass, these live in the **authored per-class curve
table** (curve saturation = limit; velocity scale = slew) and/or the **per-joint param
scale** (the prime tug factor). To extract them we need:
1. the **head's 6-bit joint index** and its constant table (read the saturation +
   velocity); and
2. the **per-joint param struct** `{index, scale@+4, scale2@+8}` (the head's `scale`).

A **separate look-at/aim controller** is not ruled out: the double-fpatan skeleton sites
**0x5EA03 / 0x5EF03** have **no direct E8 callers** (vtable-dispatched or dead) — worth a
vtable-slot trace.

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

No kuluu code has been changed (research-only rule). When the numbers are extracted and
approved, the kuluu edit citation form is `FFXiMain.dll retail-2026-09 RVA 0x...`.

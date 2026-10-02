# FFXI retail client, research summary

A cross-pass synthesis of what we have **verified** in `FFXiMain.dll` and what we
**believe** the client does, for the purpose of bringing the kuluu remake to retail
parity ("retail is king, dll is king"). Each section cites the pass that verified it.

Passes: **M** = [docs/movement.md](movement.md) (walker), **C** = [docs/camera.md](camera.md)
(event camera), **F** = [docs/mob_animation.md](mob_animation.md) (animation driver), **T** =
[docs/target_track.md](target_track.md) (target-track), **J** = [docs/joint.md](joint.md) (skeleton
joint layer), **D** = [docs/drivetask.md](drivetask.md) (scheduler drive tasks), **W/W2/W3** = look-at ([lookat.md](lookat.md))
— **two separate systems**, menu model vs in-world actor; W3 adds the bend + ellipse clamp and the authored data.
Conventions (RVA base 0x10000000, POL1-packed
`.text`, evidence tiers) in [../README.md](../README.md).

**Builds.** M/T/J/D/W were cut against TDS **0x6A995428** (retail-2026-09, the current
install; packed md5 fb7464073c06489268fdd9215c3e5313). F/C/E/U were cut against TDS **0x6A7297F5**
(older). RVAs are build-specific. The event cluster sits at about -0x10 in the newer build
(ExecProg 0xBC280, table 0xBC960, all 20 XiEvents patterns re-anchored, zero misses); other
regions do not shift uniformly, check per region.

**Unpacked image.** `unpack.py` (session_out/) produces `FFXiMain.unpacked.dll`, raw==virtual,
OEP 0x31672F, offset == RVA. The POL1 packer is the LZSS in common.py, independently re-derived
and matched. Only `.text` is packed. Headless pass artifacts (angr CFG 75,422 entries, r2 13,476,
290 labels, 289 pypcode decomps) in `session_out/ffximain_headless_v1.zip`.

Tiers: **[V]** = byte-verified in the DLL (pass cited); **[I]** = inference from verified parts;
**[O]** = user's retail observation; **[web]** = outside source, navigation map only.

---

## 0. WHY we are digging (do not lose this)

We dig `FFXiMain.dll` for one reason: **kuluu's movement/animation feel is visibly wrong, and the
user's standing ruling is "retail is king, dll is king" — no invented constants.** Each dig must pay
for itself in a symptom the user can see in-game:

| # | Symptom the user reported (paraphrased) | Status / what the dig owes us |
|---|----------------------------------------|-------------------------------|
| **S1** | While strafing a locked target, upper body/legs turn the wrong way; weapon vanishes with certain DAT choices | Open. Needs the retail Head/Body/Legs/Weapon heading rule per state (no-target / target / locked), incl. "force toward target" rather than shortest-arc (§4, §8) |
| **S2** | Idle↔walk shows a seam — same clip "restarting" instead of continuing from shared key points | Open. Needs how retail stores/blends keyframes (`sqmoKeyChannel`/`sqmoMixerMotion`) rather than restarting clips (§6) |
| **S3** | Head looks at the target to a limit then snaps back straight; body tugs slightly L/R | **RESOLVED [V] (W/W2/W3).** Looking away is *not* angular: release fires at horiz ≤ 0.3 units or forward component ≤ −0.5 (half a unit behind the shoulder line); the "snap" is a ±0.04/frame blend weight (~25 frames at 60 fps) over a 1/32-per-tick chase. The bend is `0x2AC60` and the limit is a **per-model authored ellipse** {xlim, ylim} applied by `0x2B140`, head record `(0.24, 0.16)` + neck/shoulder record `(0.16, 0.06)` for standard humanoids, read from skeleton chunk kind `0x29` ([lookat.md](lookat.md) §E). **The ±30° published earlier belongs to the menu/preview model, not the walker** — do not port it |
| **S4** | Camera spring/leash feel; locked-camera catch-up in ≲1 s without swinging past the player | Mostly verified as zoom/focal + re-anchor + spring-back (M17 corrected/M18, §5); the leash distance itself is still user-set, not dll-derived |

**Acceptance test for any of these:** a kuluu build the user can drive — press keys, watch the
character — where the symptom is gone *and* nothing else regressed. A doc-only conclusion that
doesn't unblock one of S1–S4 is not progress.

**Guardrails learned the hard way:** never quote a value we haven't read from bytes; label inference
as inference; if an answer lives in DAT data rather than `.rdata`, say so early instead of guessing;
and **read the consumer code, not a data census, to learn a record's meaning** (the DAT pass below,
§2/§3: the census confirmed contracts but invented no schema).

### Oracles available (things that can answer us without guessing)

| Oracle | What it gives | Trust posture |
|---|---|---|
| **Our unpacked `FFXiMain.unpacked.dll`** (TDS 0x6A995428) — `unpack.py`, offset == RVA | the only ground truth for *this* build | **[V]** once bytes are read |
| **Live client observation [O]** | what retail *looks like*; sets pass/fail | never explains mechanism; drives S1–S4 |
| **Real DATs** (install ROM dirs, dumped by kuluu's `dat_routines` reader) | which records/magnitudes actually ship in this install | corroborates or falsifies a contract; cannot define one (see the guardrail above) |
| **WGINC/DancingMad** @ 4243c7e — master `FINDINGS.md`, pipeline map, dancer census ([dancer_engine.md](dancer_engine.md)) | names, class hierarchy, module census, struct shapes | **[web]** older PC build + PS2; RVAs unusable |
| **PS2 SCUS_972.66 DWARF** (via DancingMad) — 2,758 named types with member offsets; plus their independent C++ recon | *member names* for structs we only have byte-offsets for | **[web]** strong hint; confirm layout against our bytes before use |

---

## 1. What we are looking for

The immediate target was the retail behavior behind the head/target look, to replace kuluu's
hardcoded model (`HEAD_MAX_TURN_RAD`, `HEAD_VIEW_CONE_COS`, `HEAD_SLEW_TAU_FRAMES` in
`kuluu-render/src/ffxi_actor_render.rs` ~3241, plus the state-2 body behavior in
`kuluu/src/view_native/input.rs`):

- **Head-look limit (walker)**: **FOUND — and it is not an angle [V] (W3).** It is a per-model authored
  **ellipse** in the bone's tangent plane, {xlim, ylim, scale} records at `refs_end + 0x48` (stride 12) in the
  skeleton chunk (kind `0x29`; kuluu already parses this file as `ffxi-dat/src/skel.rs`): humanoid head
  `(0.24, 0.16)` and neck/shoulder `(0.16, 0.06)`, orc/corp `(0.1, 0.1)`, ~74% of shipped skeletons author zeros
  ("that bone does not bend"). Applied by `0x2B140` via the bend `0x2AC60`; the ±30° (`pi/6`) figure remains
  **menu/preview model only** ([lookat.md](lookat.md) §E).
- **The "bend" (body tug / shoulder share)**: **FOUND [V] (W3).** `0x2AC60` reads the look point `model+0xB0..B8`
  and weight `model+0xBC`, chases at **1/32 of the remaining distance per tick** (`push 0x3D000000` @`0x2AD71`),
  and bends record[0] (head) always plus record[1] (neck/shoulder) — the second bone is dropped when status
  predicate `0x84390` returns `{0x30} ∪ {0x3F..0x53}` ([lookat.md](lookat.md) §E.1).
- **When it looks away**: **RESOLVED [V] (W2)** — positional, not angular: release at horizontal distance
  ≤ **0.3**, or forward component ≤ **−0.5** in actor-local space (forward = +X).
- **Up/down**: none in the menu path (one fpatan, one axis [V]); **the walker does have vertical travel** — `ylim`
  is a real authored semi-axis, and the clamp snaps along the ellipse via `fpatan` @`0x2B2BD` + cos/sin
  [V] (W3). My earlier "no up/down" framing applied only to the menu path.
- **Head slew**: **RESOLVED [V] (W2)** — blend weight `model+0xBC`, ±**0.04/frame** (`0.04f` @ `.rdata 0x32A85C`)
  to 1.0 while aiming and back to 0 on release, then the look point resets straight-ahead: ~25 frames each way,
  which is why retail reads as a snap. Frame-scaled variant `vt[0x144]() × 0.01 × 0.04` when `0x87060()`.
- **Body-tug (shoulder)**: open — same missing consumer as the clamp.

More broadly: a correct model of retail walker, camera, and animation/skeleton behavior so kuluu
matches the model, not just a number. End state chosen by the user: **data-driven (B)**, kuluu
implements the same consumers retail does and the authored data flows through.

---

## 2. Good leads found

- **W pass (relabelled): the model-slot look-at is the MENU system [V].** Dancer's model array
  (`[0x1099AED0]`, stride `0xAC`) holds bone index / limit / target / enable-bit slots, and its per-frame update
  calls `sqmdModelLookAt` — yaw = one atan2, clamped to ±limit (`pi/6` default), applied to exactly one bone.
  Correct for the menu/preview model `[0x10669158]`; **not** what in-world actors do ([lookat.md](lookat.md) §A).
- **W2 pass: the real actor look-at is method 0xD5B10 (`E8` call site at 0xCCA03) [V].** Target =
  `GetLockedTarget(g_pInputMng)` for the local player, own target (0x845E0) for NPCs/mobs; status gates
  {0,1,2,6,7,8} / {0,0x2F,0x30} or mount predicates 0x84330/0x84350/0x84370; look point = target's
  **attach point 3** with `Y −= 1.2` when `target+0xB2`, stored at `actor+0x848..0x850`; mode float
  `actor+0x854` ∈ {0 aim, +1 hold (bit 0 of actor+0x840), −1 release}; release on no-target / LockLookAt bit /
  gate fail / horiz ≤ **0.3** / forward ≤ **−0.5**; blend weight `model+0xBC` at ±**0.04/frame**. Every constant
  and call site re-verified byte-for-byte in [lookat.md](lookat.md) §C.
- **W3 pass: the bend and its ellipse clamp are code-located, and their data home is authored per model [V]**
  (bend `0x2AC60`, single caller `0x2A32E`; clamp `0x2B140`, single call site `0x2AF1B`; record accessor `0x35270`
  = refs_end + `0x48` + 12·index). Census of this install: **3,365** skeleton chunks parsed; distinct limit pairs
  `{0.24,0.16}+{0.16,0.06}` ×539 (hume/elf/tavnarian/merriph/mithra/kuveng/humoid NPCs),
  `{0.1,0.1}` ×310 (orc/corp/part yagudo+kammunian), `{0.15,0.15}` ×22, zeros ×2,488 — including **all** `gob_`
  and `sao ` skeletons, which predicts Goblin/Tarutaru models never bend a head ([lookat.md](lookat.md) §E.3,
  flagged **[O?]** for one in-game glance).
- **D pass, the scheduler task contract [V].** `CMoSchedularTask_Interpret` (0x57FB0) walks the
  DAT 0x07 routine stage stream; `case = type_byte - 2` (194 cases, table 0x5DC1C). Stage 0x89 =
  LockLookAt (alloc 0x80), 0xA9/0xAA = ActorRotation (alloc 0xA0, two variants). Record layout
  fully read. Section 6.
- **Corroboration of that contract from the shipped DATs (DAT pass, [drivetask.md](drivetask.md) §9).**
  Dumping every `*.DAT` under the install (52,989 files → 178,142 chunk-`0x07` streams, 450,253 stage
  lines; census in [`../tools/dat_stage_scan.py`](../tools/dat_stage_scan.py)) lands on the predicted
  records: **stage `0x89` appears 504×, always `len=3`, payload nothing but a duration** (e.g. s16 at
  record+6 = 274) — data-side proof of "LockLookAt carries no angle"; and the five real **`0xA9`
  ActorRotation** records (`ROM3\0\43.DAT`) carry `(pitch=0, yaw ∈ {+90,−90,−135,+45}, roll=0)` exactly
  at `+8/+C/+0x10`. Two things the code read alone did not tell us: **stage `0xAA` never occurs** in this
  install's streams (the second ActorRotation variant is unobserved, rare), and stage types we have not
  decoded — `0x28` (6,234 records / 5,259 files, int + float ∈ {30,24,20,10,60,36,15}) and `0x62` (214,
  always `(u16,u16)+45.0f`) — are the *authored-float* carriers to read consumer-side next.
- **J pass, the skeleton joint integrator [V].** Per-joint `angle += dt x curve(clock)`, wrapped
  to (-pi, pi]; per-class keyframe evaluators 0x54500 (linear) / 0x547A0 (smooth); clocks
  0x47BFA8 (+0xEB0 = dt) and 0x65CB14.
- **T pass, target acquisition [V].** `LockedTarget` = 0x157CF0 (`[obj+0x21]==1` gate + 0x1598A0
  scan) with fallback to entity slot 0x487F58 (0x81600).
- **M pass, the whole walker [V].** Control function 0xA65CB..0xA70AB: circle-walk, 0.05/0.9/1
  speed bands, Q/E rotating camera and body, re-anchor only while a key is held, spring-back.
- **C pass, look-at basis + camera manager [V].** Event look-at yaw is the negated atan2; camera
  manager singleton 0x4568FC+0x50 (@0x6A995428) / 0x45693C+0x50 (@0x6A7297F5).
- **F pass, the animation driver [V].** Wire (0x0E/0x28) -> RenderFlags -> per-frame flush
  (0x95DB0) -> actor create/destroy (CXiSkeletonActor, vtable 0x330F40) -> sub->fourcc table
  (0x35AF60) -> routine resolver (0xCE490) -> scheduler nodes -> stage stream.
- **Outside oracles [web]:** WGINC/DancingMad @4243c7e (dancer 16-module census, 136-class
  hierarchy, skinning pipeline; cross-checked against our build in docs/dancer_engine.md), its PS2
  SCUS_972.66 DWARF (2,758 named types with member offsets), its independent C++ recon. All
  navigation maps; the DLL is ground truth.
- **Key globals [V]:** entity table 0x480AF0 (stride 4, XiAtelBuff); CXiSkeletonActor vtable
  0x330F40 (64 slots); clock 0x47BFA8; tick 0x14CF0; anim clock 0x65CB14; dancer model array base
  [0x1099AED0], count [0x1099AECC].

## 3. Bad leads found

- **CMoLockLookAtDriveTask as the walker mechanism, no [V] (W1).** Its only spawner is the
  scheduler stage handler (case 135); the second vtable install at 0x5F660 is its destructor.
  It is cutscene/action playback, triggered by routine streams the server kicks off. The walker
  never touches it.
- **"Authored head degrees" in script data, no [V] (D).** The 0x89 LockLookAt record carries only
  a duration (s16 @+6). No angle, no limit, no target. Only ActorRotation (0xA9/0xAA) carries
  authored degrees (pitch/yaw/roll @+8/+C/+0x10, x pi/180 in ctor 0x5FA20).
- **DAT census for operand schemas, wrong method.** The consumer code defines the contract; the
  record walker (0x57C20) and fetchers (0x5E590, 0x62770/0x627D0) gave the full layout in four
  reads. Stage-byte guesses 0x87/0xA8 were off by the `-2` in the dispatch.
- **0x5EA03 / 0x5EF03 "double-fpatan look-at controller", no [V].** Both are `33 C0` = `xor eax,
  eax`, linear-sweep desync artifacts. The real fpatan near there is 0x5EA8B.
- **"Corrupted capstone x87 table", no [V].** capstone 5.0.7 decodes every disputed D8-DF mod=11
  cell correctly; DB F8-FF is genuinely invalid (FCOMIP is DF F0+i). Root failure was sweep
  alignment, not opcode tables. No tooling change.
- **T-pass state machine, inert in 0x6A995428 [V].** +-44.987 deg bracket (0xA80D0, 0xA82A0) is
  overflow-flag-gated and returns only {0,1}; `state_0x598` never 2/3/4. Do not port 0.125 or
  +-44.99 deg.
- **M17 as pitch, no [V].** 0x32A3D8/0x32A3D4/0x32A3DC hold 900.0/242.0/350.0 (not 23/10/15);
  23.0f does not exist in .rdata; the block stores via the focal setter 0x15290. It is the zoom
  (focal) integration. The degree values leaked from the XIClient transcription.
- **M20 kbd scale 1/64, no [V].** 0x32A778 = 0.0078125 (1/128), verified in 0x120C70. Held Q/E
  azimuth = 0.10667 x 127/128 = 0.1058 rad/s (~6.06 deg/s), half of what was ported.
- **16-step compass (0xA7851), dead [V]. 0x487F98, read-only zero [V]. L/R arrow yaw, dead [V]
  (M19). `[obj+0xE0]` as a unique joint slot, no [V] (J9). 0x3138BA as fmod, no [V] (J3).**
- **XIClient source as ground truth, unreliable [O/I].** Navigation only.

- **"The ±30° / pi-6 clamp is the walker's head limit", no [V] (W2).** That slot system serves the menu/preview
  model singleton `[0x10669158]`; in-world actors never call `sqmdModelLookAt`. I published that number as the
  walker's and it got cited into kuluu — do **not** port `HEAD_MAX_TURN_RAD = 0.5236` on that authority.
- **"The head leaves you because of an angle limit", no [V] (W2).** Release is positional: horiz ≤ 0.3 or
  forward component ≤ −0.5 in actor-local space (forward = +X). There is no release angle to go find.
- **`0x27C2CC` as a look-at consumer, no [V].** A dancer debug dump (double→float conversions feeding printf).
- **Chunk kind `0x20` = skeleton, no [V] (W3).** `0x20` is kuluu's own `ChunkKind::Img` — the bodies carry `TXD`
  (textures). The skeleton chunk is kind **`0x29` (`ChunkKind::Bone`)**, and `dat_routines.py`'s header comment
  ("Other chunk types: 0x20 skeleton, 0x29 (skeleton-adjacent)") has it backwards; that misread is exactly why an
  earlier attempt to replicate the look-at record layout "found no plausible bone count". Layout was never wrong —
  the scan was pointed at textures.
- **RVA `0x32A22C` as f32 1/32, stale [V] (W3 re-check).** In this build (retail-2026-09) that pool slot holds
  **0.001f**; the "work-slot ↔ camera scale 1/32" cite came from the older 0x6A7297F5 build and must be
  re-derived here before kuluu ports it. (The look-at clamp's own defaults *are* 0.001f at that address — used as
  a divide-by-zero guard, not a limit.)
- **"Interpreter case index = scheduler stage type byte" (`0x87` = LockLookAt, `0xA8` = ActorRotation) — falsified
  against data [V] (DAT pass).** The rule is `case = type − 2`: across chunk-`0x07` streams `0x87` never occurs and
  the ten `0xA8` records are two-int records too short for ActorRotation; LockLookAt is stage `0x89`, ActorRotation
  is `0xA9/0xAA`. Re-verified from the dispatch bytes in [drivetask.md](drivetask.md) §10.

## 4. How we think the ffxi walker works (M pass)

- One function, **0xA65CB..0xA70AB** (func start ~0xA6240), on the per-frame local-player tick [V].
- Axes from the input manager (0x57876C): W/S = action 4, A/D = action 5 (sign-inverted), Q/E =
  actions 6/7 [V] (M16). Keyboard axis = `(int8)(kbd+0x250 - 0x80) x 1/128` (0x120C70) [V].
- `dir = {-key2 x speed, 0, key1 x speed}` in world axes [V] (M4).
- Speed/deadzone (0xA78D0) [V] (M3): `mag <= 0.05` stand; `0.05 < mag <= 0.9` walk (x1/3);
  `mag > 0.9` run (x1.0). 0.9 lives at 0x32C9A4 (fcom at 0xA7918). Axes normalized first, so a
  W+D diagonal is a unit vector. Scale stored at `actor+0x594`.
- Circle-walk (0xA79A0) [V] (M5): `dir` rotated by the camera azimuth. W/S radial, A/D angular.
- Ground re-orthogonalization; in air `dir x= 0.25` [V] (M8). `dir x= dt` (0x14CF0) [V].
- Contact gate (0xA8770) then `*pos += dir` inline (0xA6F31) [V] (M9). Live position
  `ent+0xD4/+0xD8/+0xDC` [V] (M14).
- Facing (M10) [V]: body faces travel; `yaw = -fpatan(dir.z, dir.x)` -> `actor+0xE8`.
- Q/E (M15) [V]: drives camera azimuth (`cam+0x48`) and body heading.
- Camera re-anchor (M11) [V]: only while a movement key is held.
- Auto-run (M6) [V]: flag 0x487F81 + unit vector 0x487F64.

## 5. How we think the ffxi camera works (M + C pass)

- Camera manager singleton: 0x4568FC+0x50 (@0x6A995428) [V]. Fields: `+0x24/+0x2C` horizontal
  direction; `+0x44..+0x4C` eye; `+0x50..+0x58` look-at [V] (M12/C2).
- Free camera [I from M11 + O]: does not continuously follow; re-anchors only while keys are held.
- Q/E azimuth: `cam+0x48 += tick x axis6 x 0.10666667` [V] (M15); effective held rate 0.1058
  rad/s with the 1/128 axis scale.
- **Zoom (focal), not pitch** [V] (M17 corrected): `focal += +-tick x 6.0`, clamped 242.0..900.0,
  both-keys ease toward 350.0 at x0.25/frame, mouse wheel same path, stored via 0x15290.
  `FOV = 2 x atan2(192, focal)`; 280 first-person / 350 third.
- Spring-back (M18) [V]: mode byte 0x456DB0 + reference angle 0x456DB4.
- Locked camera [O + I]: focuses the target, catches up smoothly; Q/E and arrows inert while locked.
- Event camera (C pass) [V]: 0x46 DEFCAMERA, work-slot <-> camera scale 1/32 (0x32A22C).

## 6. How we think the ffxi animation / skeleton works (F + J + D pass)

Three layers: the **driver** (F) picks which routine/clip to play; the **scheduler task
interpreter** (D) executes a routine's stage stream, spawning drive tasks; the **skeleton** (J)
turns that into joint angles.

**Driver (F pass) [V]:** server 0x0E/0x28 XOR-diffed into RenderFlags; per-frame flush (0x95DB0)
rebuilds the actor; a sub change plays `table[sub]` from 0x35AF60 via actor slots +0x298/+0x29C;
the routine's stage stream is copied into scheduler nodes (actor +0x68).

**Scheduler task interpreter (D pass) [V]:**
- Record walker 0x57C20: stream at `res+0x78`; each record `u32 header`, low byte = type, bits
  8..12 = length in dwords, type 0 ends. Same format dat_routines.py parses.
- Dispatch 0x57FC2: `case = type_byte - 2`, 194 cases (bytes 0x02..0xC3), table 0x5DC1C.
- Operand fetchers: `0x5E590` = duration = `s16 @ rec+6` x `task+0x9C` (time scale) ->
  `ftoi_round` (0x311C2C) -> frames. `0x62770` / `0x627D0` resolve the actor from the task's
  runtime link slot (`this+0x34`, walking `+0xC4` past kind-0x32F910), never from the record.
- **Stage 0x89 (case 135) LockLookAt**: alloc 0x80; args (task, actor, duration). Nothing else.
- **Stage 0xA9 (case 167) / 0xAA (case 168) ActorRotation**: alloc 0xA0; `rec+0x08` f32 pitch,
  `+0x0C` f32 yaw, `+0x10` f32 roll (degrees), `+0x14` u8 mode; ctor 0x5FA20 multiplies by
  pi/180 at 0x5FA95/AB/CB. The two variants differ only in which end of the link the actor is.
- These are cutscene/action playback (server-triggered routines). kuluu's B substrate needs this
  consumer for emotes/actions; it is not the walker.

**Skeleton (J pass) [V]:** each joint integrates `angle += dt x curve(anim_clock)`, wrapped to
(-pi, pi]; evaluators 0x54500 (linear) / 0x547A0 (smooth); 12 dispatch sites 0x4B819..0x4D40D.

## 7. How we think ffxi works (top-level)

- `FFXiMain.dll` ships `.text` rawsize 0 with a POL1-packed section; the entry stub unpacks at
  load (OEP 0x31672F). All game logic is in this DLL [V]. Two source trees: `C:\dev\dancer\sq*`
  (Square's in-house middleware, C, 16 modules) and `D:\build0001\FFXi_Win\` (the game, C++) [V].
  RTTI is compiled out; class names exist as allocator/debug tag strings (113 extracted) [V].
- World state = global entity table (XiAtelBuff) [V]. Each visible entity owns a CXiSkeletonActor [V].
- Per-frame tick (0x14CF0) drives: local player (control fn), all entities (0x8F750 + 0x95DB0),
  camera, skeleton integrator, event VM, and dancer's per-model update (0x26E4C2, look-at apply).
- Client is king for feel; server is king for rules [I].

## 8. How we think they all talk to each other

```
Keyboard / Mouse
   |
   v
Input Manager (0x57876C)  axes W/S=4, A/D=5, Q/E=6/7; kbd axis x 1/128
   |
   v
Control Function 0xA65CB (local-player tick)
   |- speed/deadzone (0xA78D0) -> scale
   |- circle-walk (0xA79A0): dir x= RotateY(cam azimuth)
   |      ^ Camera Manager (0x4568FC+0x50): Q/E azimuth cam+0x48, zoom 242..900 ease 350,
   |        re-anchor (M11), spring-back (M18), event 0x46
   |- target-track (0xA7B80) if target: LockedTarget 0x157CF0 / slot 0x487F58
   |- dir x= dt (0x14CF0) -> contact gate (0xA8770)
   |- *pos += dir; facing = direction of travel (M10)
   |
   |
   |  MENU / PREVIEW MODEL ONLY ([0x10669158]):
   |     dancer model array [0x1099AED0] stride 0xAC, flag bit 0x200
   |     -> sqmdModelLookAt (0x278E90): one atan2, clamp +-limit (pi/6 default), exactly one bone
   |
   |  IN-WORLD ACTOR LOOK-AT (all actors, per update; E8 call at 0xCCA03):
   |     method 0xD5B10: target (GetLockedTarget / own) -> status gates -> attach point 3 (Y -= 1.2 if +0xB2)
   |     -> actor+0x848..0x850 look point; actor+0x854 mode {0 aim, +1 hold, -1 release}
   |     -> release: horiz <= 0.3 OR forward <= -0.5 (actor-local +X) OR LockLookAt(stage 0x89) bit
   |     -> model+0xBC weight ramps +-0.04/frame (~25 f @60fps); at weight 0 the look point resets straight-ahead
   |     -> ??? "the bend": consumer of model+0xB0..B8 + weight that applies the angular clamp - NOT FOUND;
   |        class reached via actor+0x674 list (accessor call 0xD5B1E -> 0x2B5A0)
   v
dancer model array [0x1099AED0] (stride 0xAC per registered model)
   |  per-frame update 0x26E4C2 -> for each model with flag 0x200:
   |     sqmdModelLookAt(model, 0, bone, &target, limit)      0x278E90
   |        yaw = atan2(delta); clamp +-limit (default pi/6 = 30 deg)
   |        rot = single-axis(yaw) (0x27ABA0); node+0x68 = rot * node  (one bone)
   v
Entity (XiAtelBuff) <-- server 0x0E / 0x28 / POS set RenderFlags
   |
   v
per-entity update 0x8F750 + flush 0x95DB0
   |- actor create/destroy (CXiSkeletonActor, vtable 0x330F40)
   |- sub -> fourcc (0x35AF60) -> routine (0xCE490, model DAT) -> scheduler nodes
   v
scheduler task interpreter 0x57FB0: case = type-2 over the stage stream
   |- 0x89 LockLookAt(duration) / 0xA9,0xAA ActorRotation(pitch,yaw,roll deg, duration) / ...
   v
Skeleton joint integrator (J): angle += dt x curve(anim_clock 0x65CB14)
   v
bone matrices -> render
```

## 9. Where we are looking next

**Walker look-at — CLOSED [V] (W2+W3).** Target selection/gates, attach-point-3 look point, mode float,
positional release and ±0.04 weight ([lookat.md](lookat.md) §B) plus the bend `0x2AC60`, the 1/32-per-tick chase,
the ellipse clamp `0x2B140` and its authored per-model records (§E). Nothing structural remains for look-at; what
remains is *use*: kuluu must load `{xlim, ylim, scale}` from skeleton chunk `0x29` (`refs_end + 0x48`, stride 12)
and apply the ellipse + weight + positional-release rule instead of its cone/slew constants.
Open sub-questions worth one more pass later: what the clamp's two scaling branches
(`scale × 100.0f` vs `scale / x`) are selected by, and accessor `0x35290`'s `+0x24` (a fourth record? another
consumer at `0x23BE0`). Both are polish — the shipped data has exactly two meaningful records.

**Data-side leftovers** ([drivetask.md](drivetask.md) §10): the dispatch rule is now byte-confirmed
(`case = type − 2`, bound `cmp edx,0xC1` ⇒ **194** jump-table entries; our earlier "196" was a scan that
ran past the end into default-handler pointers). Shipped DATs corroborate the two record contracts —
504 × `0x89` LockLookAt records whose bytes after `record+8` are all zero (duration-only), and 5 × `0xA9`
ActorRotation records with yaw ∈ {+90,−90,−135,+45} — while the `0xAA` variant never appears here.
The reader itself was then fixed (payloads uncapped; `--all-types` no longer crashes — full install scan in ~28 s),
which roughly doubled the angle counts and exposed the real carrier ranking ([drivetask.md](drivetask.md) §9.5b,
§11): **`0x28`/case 38**, **`0x62`/case 96** (clean tiny layouts — read these two handlers first), then the
long-payload family `0x2C`/case 42, `0x25`/case 35, `unk21`/case 31. ActorRotation's mode byte (`record+0x14`) is
**0 in all five shipped records**, and stage `0xAA` remains absent. Wider chunk coverage was measured and is
useless — non-`0x07` bodies parse as fake streams with absurd record lengths, so **censuses must be filtered by
chunk type**. Read handlers consumer-side; do not infer meaning from a census again.

**Then kuluu (separate task, kuluu repo, user's git rules):**
- S1 strafe/legs facing (parked force-toward-target fix) and S2 idle<->walk pop (clip continues
  from shared keyframes) are kuluu's own heading/clip-restart logic and do not wait on any of the
  above.
- Head look-at port ([lookat.md](lookat.md) §D + §E): implement what is verified — target + gates + attach-point-3
  look point (Y−=1.2 when `target+0xB2`) + aim/hold/release mode float + **positional** release (horiz ≤ 0.3 or
  forward ≤ −0.5) + weight ramp ±0.04/frame with reset-to-straight at weight 0 + the 1/32-per-tick chase + the
  **authored ellipse** per model (head record, optional neck/shoulder record; zeros ⇒ no bend). Delete kuluu's
  cone/slew constants; keep zero hardcoded angles — the only legitimate angle-free limit source is the DAT record.
  The 30° figure still must not be ported (menu model only).
- Camera: replace the "pitch" port with the zoom model (242..900, ease 350); halve the Q/E rate.

No kuluu code has been changed (research-only rule). Citation form for kuluu edits:
`FFXiMain.dll retail-2026-09 RVA 0x...`.

## 10. Look-at — moved to [lookat.md](lookat.md) (§A menu model, §B in-world rule set, §C byte re-verification, §D port guidance, **§E the bend + ellipse clamp + authored data**)

Both look-at systems now live in **[lookat.md](lookat.md)**: §A the dancer model-slot system (menu/preview model
`[0x10669158]`; one atan2, ±limit with `pi/6` default, one bone), §B the in-world actor method 0xD5B10 (target,
gates, attach point 3, mode float, positional release, ±0.04 weight ramp), §C my byte re-verification of every
constant and call site, and §D what kuluu may and may not port yet.

**The number to un-learn:** ±30° is the *menu* model's limit. The walker's angular clamp is still unlocated, so
kuluu keeps it parameterized instead of pinning `HEAD_MAX_TURN_RAD = 0.5236`. My earlier §10 claimed otherwise;
that was my error, corrected here and in [lookat.md](lookat.md). Citations:
`FFXiMain.dll retail-2026-09 RVA 0xD5B10` (in-world look-at), `0x278E90 / 0x26E530` (menu model).

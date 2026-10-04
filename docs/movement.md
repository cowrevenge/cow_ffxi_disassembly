# FFXI retail client: local-player movement (M pass)



How the retail client turns WASD into motion: the circle-walk (W/S radial, A/D angular

around the camera), the speed/deadzone law, auto-run, ground projection, the contact

gate, and the facing update. Findings **M1..** are a fourth pass, distinct from the mob

pass (**F**), event pass (**E**), and camera pass (**C**). Conventions (RVA base

0x10000000, POL1-packed `.text`, evidence tiers) are in [../README.md](../README.md).



Target binary: `FFXiMain.dll`, build TDS **0x6A995428** (2,901,584 bytes, PhoenixXI

install, `client=retail-2026-09`). This is a *newer* build than the F/E/C passes

(TDS 0x6A7297F5); every RVA here is only valid against 0x6A995428. XIClient source was

used only as a navigation map for where to look; every finding below is verified in

this DLL.



## 1. Scope



| # | Question | Status |

|---|----------|--------|

| Q1 | Is retail A/D angular-about-camera or tangent-velocity? | Resolved (M5): input vector rotated by camera azimuth — polar/circle-walk |

| Q2 | Where is the movement integrator? | Resolved (M9): `*pos += dir` inline at 0xA6F31; contact gate 0xA8770 |

| Q3 | What is the walk/run law? | Resolved (M3): 0xA78D0, deadzone 0.05, run at mag ≥ 1/3, `field_594` |

| Q4 | What are the camera fields used for movement? | Resolved (M12): cam+0x24/+0x2C = direction, +0x44/+0x50 = eye/lookat |

| Q5 | Where does auto-run live? | Resolved (M6): flag 0x487F81, unit vector 0x487F64..+0xC |

| Q6 | Entity position layout? | Resolved (M9, M14): live pos at ent+0xD4/+0xD8/+0xDC |

| Q7 | Do the Q/E turn keys move camera and body? | Resolved (M15): yes — camera azimuth integration + body heading re-assign |

| Q8 | Is a W+D diagonal normalized to full speed? | Resolved (M3/M16): yes — axes divided by magnitude before the scale |

| Q9 | What is the camera zoom (focal) law? | Resolved (M17): focal ±6.0×tick, clamps 900.0/242.0, both keys snap to 350.0 |

| Q10 | Is the left/right arrow yaw live? | Resolved (M19): dead path in this build — no retail rate exists |



## 2. The control function (M1, M2, M4)



**M1 [local].** The whole third-person control chain is one function,

**0xA65CB..0xA70AB** (called by the per-frame player tick; 2 direct callers).

Prologue reads the input manager `g_pCTkInputCtrl` @rva **0x57876C**:

`call 0x158AA0` (SomeKeyCheck-shaped) and `mov cl,[ecx+0x22]` (`m_MainTarget.field_22`).

When the check fails or field_22 == 0, the analog axes are read:



| key | source | stored |

|-----|--------|--------|

| AnalogKey1 | `GetAnalogKey(0x3F, 4)` = call **0x123970** | `[esp+0x10]` |

| AnalogKey2 | `-GetAnalogKey(0x3F, 5)` (fchs) | `[esp+0x14]` |



**M2 [local].** Mouse reset + mouse steering: mouse object @rva **0x4E1D4C**;

`[mouse+0xA8] = 0.0f`, `[mouse+0xAC] = 0`. `CFsConf6Win::Check()` = call **0x25E050**.

When active, `HandleMouseSteering` = **0xA77A0**(actor, &key2, &key1, &out) rewrites

the axes from the drag angle and stores the angle at `mouse+0xA8`, `mouse+0xAC = 1`.



**M4 [local].** The movement vector is built at 0xA6A6F in **world axes**:

`dir = {-key2 * speed, 0, key1 * speed}` (stack `[esp+0x18..0x20]`), where `speed`

comes from 0x25E170/0x25E100 (walk-speed / 60 shaped). Later, at 0xA6F04,

`dir *= dt` via 0x272B0(`dir`, &`[esp+0x64]`); `[esp+0x64]` is the frame delta from

call **0x14CF0** (returns the tick scale on the FPU stack).



## 3. Speed / deadzone law (M3)



**M3 [local].** `AdjustAnalogKeyLength` = **0xA78D0..0xA7998**

(`ret 0xC`; thiscall + 3 ptr args: &key1, &key2, &out_scale).

`mag = fsqrt(*key1² + *key2²)`; axes are normalized by `mag` (guarded by

fcomp against 0.0 @0x3295D8 with epsilon 1e-6 @0x32A42C). Scale:



| condition | scale |

|-----------|-------|

| `mag <= 0.05f` (@rva 0x32A3E0) | 0 (stand still) |

| `0.05 < mag <= 0.9` (0.9 @rva **0x32C9A4**, compared 0xA7918) | 1/3 (walk band, immediate 0x3EAAAAAB at 0xA7939) |

| `mag > 0.9` | 1.0 (run) |



The walk-lock test (vtable `+0x338`) follows with a clamp that is dead in this

build (see below).



Both axes are multiplied by the scale and the scale is stored at

**`actor+0x594`** (the `field_594` speed slot). The run threshold 0.9 is not a

`.text` immediate in this build — it lives in `.data` at **0x32C9A4** and is

compared at 0xA7918 (`fcom`, d8 15 — not `fcomp`, which would be d8 35), so the 0.9 / 1/3 / 0.05 three-band law of the

XIClient transcription is intact here, just data-referenced.



Because the axes are divided by `mag` before the scale (1e-6 guard), a digital

W+D diagonal arrives as a unit vector: **(diagonals move at full speed, not

√2)** — W alone and W+D cover the same yalms per tick. An analog stick under

0.9 deflection sits in the 1/3 walk band.



Build quirk: the walk-lock clamp block (0xA7960..0xA7973) is a **no-op in this

build** — its branch (`fcomp [1/3]; and eax, 0x4100; jne skip`) only executes

the `scale := 1/3` store when scale is *exactly* 1/3, so a locked full-run

scale (1.0) passes through unclamped. The C++ transcription's

`if (v20 > 1/3) v20 = 1/3` does not match this binary's branch; if a

walk-lock cap matters in this build it must come from elsewhere.



## 4. The circle-walk (M5)



**M5 [local].** After the status gates (M7) the free-run path

(`vtable +0x330` != 0) calls **0xA79A0**(actor, &dir) at 0xA6C87. 0xA79A0 is the

camera-azimuth rotation:



```

cam = GetCameraMng()                      ; call 0x15250

az  = fpatan( -[cam+0x2C], [cam+0x24] )   ; camera azimuth (0xA79B4..0xA79DE)

M   = RotateY(az)                          ; 0x27BD0 builds the 4x4 at [esp+0x3C]

dir = M * dir                              ; 0x28200/0x28230 (in-place, 0xA79F4..0xA79F9)

```



So the raw `{-key2, 0, key1}` vector is rotated by the camera's horizontal bearing:

**W/S move along the camera axis (radial), A/D move perpendicular to it (angular,

around the camera position)**. The camera itself does not follow the player's facing —

`UpdatePlayerFollowingCamera` (M11) is only nudged while movement keys are held.

This is the retail "polar / tank-style" walker the user observed.



The parallel-move path (`vtable +0x330` == 0, i.e. `IsParallelMove`) instead calls

**0xA7B80**(&dir) at 0xA6D19 — direction-id + vector-length change, **no camera

rotation** (strafe-style, used by mounts/parallel controls).



## 5. Auto-run (M6)



**M6 [local].** Auto-run state is two globals:

- flag **0x487F81** (`is_auto_running`), set by **0xA6070**(on/off);

- unit direction vector **0x487F64 / +0x487F68 / +0x487F6C** (`auto_run_vec`),

  seeded from `0x35BBA8..` (0xA607D) or re-seeded from the actor's current direction

  when degenerate (0xA6193: `mag = fsqrt(v·v)`; if `|1 - mag| < ε` and the actor

  vector is valid, copy `actor→0x487F64..+0x70`).



While auto-running (flag set, vec non-zero):

- the movement vector is **overwritten** with `auto_run_vec` (0xA6D4D, copy3f via

  0x26EB0); `[0x487F84] = 0` afterwards;

- holding forward (key1 ≠ 0) **rotates `auto_run_vec` in place** by

  `2 * key1 * [esp+0x4C]` (0xA6CD0..0xA6D10: 0x27BD0 + 0x28200) — the circle-turn;

- auto-run stops when the input vector opposes it: dot with `auto_run_vec` vs

  -0.01 @0x32DF8C, cross-y window ±0.4 @0x32DF40/0x32DFA0, 0.3 @0x32B15C

  (0xA7A0B..0xA7AAE) → calls 0xA6070(0).



## 6. Gates (M7, M8)



**M7 [local].** Movement is allowed only when:

- `0x84600` (control-lock state) < 3 (checked in 0xA8770 at 0xA8785);

- `GetGameStatus` = **0x84390** ∈ {0, 1, 4, 0x1C, 0x1F} (0xA6C38..0xA6C50), or the

  mount siblings 0x84350/0x84370 pass;

- `byte [0x487F80]` clear (user control not suspended; 0xA668F);

- the camera-follow flag `byte ([0x4568FC]+8)` only gates M11, not movement.



**M8 [local].** Ground handling (after rotation): if `vtable +0x198` != 0 (on

ground / has ground normal), the direction is re-orthogonalized against the ground

normal: `dir = normalize(cross(normalize(dir), normal)) × cross(normal, ·)` (0x27550

cross helper, 0xA6D65..0xA6DD5); y < 0 is clamped. In air: `dir *= 0.25`

(0x272B0 with immediate 0x3E800000 at 0xA6E39).



## 7. Integration + contact (M9, M14)



**M9 [local].** The integrator is *inline* in the control function, at 0xA6F1D:

`call 0xA8770` (**CheckContactActor**(actor, &dir)) — if it returns 0 (not blocked),

`*pos += dir` is done directly:



```

0xA6F26  mov eax, [esp+0xEC]      ; pos pointer (passed by the tick caller)

0xA6F2D..0xA6F46  fadd/fstp [eax], [eax+4], [eax+8]   ; x,y,z

```



**M14 [local].** `0xA8770..0xA89D1` is the contact/collision gate (it never writes

position itself). It reads the live position from **`ent+0xD4/+0xD8/+0xDC`**

(0xA8792, and via vtable `+0x1BC` = GetPosition at 0xA7ADE/0xA8838-ish call sites)

and iterates candidate actors via 0x85240/0x85270 (query/next). A candidate blocks

when within **dist² < 40.0** (immediate 0x42800000 at 0xA87B5; radius ≈ 6.32 yalms —

the "walking alongside" distance), it is a live player-shaped actor (type gate

`ent+0x170` ∉ {2,3}; status via 0x84400 ∈ {1,2,6,7,8}; `byte ent+0xB2` & 3 == 0;

face-slot 0x84480(0) ∈ 50..59; fade `ent+0x59C` < 1.0), etc. On block it returns 1

and manages the contact fields: **`ent+0x5A0`** = contact-actor link (set/cleared via

0x814F0), **`ent+0x5AC`** = countdown (30 = 0x1E at 0xA899C, decremented by the tick

scale at 0xA8976), **`ent+0x5B0`** = contact flag.



The earlier "POS builder reads ent+8/+0xC/+0x10" note from the handoff was a stack

misread; the entity's live position is at **+0xD4** (M14). The 0x015 POS reporter at

0x983F0 (called from the per-tick local-player scan at 0x969F4) therefore reports the

same +0xD4 triple.



**M14-bis [local] — what the candidate iteration actually is, re-read byte-for-byte 2026-10-05 [V]**

(closes the "iteration semantics" research item for `0x85240` / `0x85270`; both helpers sit in one code block

RVA 0x85220..0x85296, and the sweep mis-bounds them as functions starting at 0x851DE — those bytes are padding,

not code):



- **`0x85240` = find-first over the actor draw list.** `mov esi, dword ptr [0x1047d578]` (the depth-sorted draw-list

  head global; pipeline-map §6.1 names the same address), then per node: push the filter token, `call 0x1002c8f0`,

  `test al,al; je return_node`; otherwise advance `esi = [esi + 0x54]` (the list's *next* link) and repeat. Returns

  0 when the list ends.

- **`0x85270` = find-next with the same filter**: identical body except it starts from `[ecx + 0x54]` — so callers

  drive it as a cursor (first, then next-of-last-hit). Both use link field **+0x54**, matching §6.1's `next`.

- **The filter (`0x2C8F0`) is an IsKindOf test, not a flag read**: `mov eax,[ecx]; call dword ptr [eax]` (virtual

  slot 0 returns the node's class-info pointer), then compare against the queried token, and if unequal climb

  `[eax + 8]` repeatedly (`cmp eax,token; je true` / `jne loop`) until null → false. So a match includes derived types.

- **The queried type is baked into the helpers:** the token pushed by both is `.rdata` VA **0x1032F910**, whose first

  dword points to RVA 0x35BD78 = ASCII **"CXiDollActor"** (followed by `u32 0x440`, i.e. the class size, then more

  pointers). Because the token is an immediate inside the helpers, *every* one of their callers queries that same

  class — which is exactly why M14 read candidates as "player-shaped actors".

- Same block also holds a **tail-of-list getter** at **0x85220..0x85238** (`ret` @0x85238): walks head→last node over

  +0x54 and returns it, or 0 for an empty list.

- Caller census (whole `.text`): 20 call sites of `0x85240`, 19 of `0x85270`. M14's contact gate is among them —

  query at **RVA 0xA87BD** and cursor at **RVA 0xA8908**; note the enclosing routine actually begins at

  **RVA 0xA8748**, not the 0xA8770 the §7 text quotes (0xA8770 is inside it).



Consequence: no kuluu change needed for correctness of M14 as recorded, but any port of the contact gate inherits

this *type filter* — retail does not scan "all actors", it scans the draw list for `CXiDollActor`-shaped ones.



## 8. Facing update (M10)



**M10 [local].** After integration, when free-run and moving:

- single-axis (dir.x == 0 or dir.z == 0): `yaw = -fpatan(dir.z, dir.x)`

  (0xA7072..0xA709D);

- diagonal with a key held: build `keyvec = {-key2, key1, 0}` (0x26E50 at 0xA6FD2),

  `az = fpatan(-[cam+0x2C], [cam+0x24])`, rotate keyvec by az (0x27BD0 + 0x28200 at

  0xA7008..0xA7028), then `yaw = -fpatan(rot.z, rot.x)`;

- store: `actor+0xE8 = yaw`, `actor+0xE4/+0xEC/+0xF0 = direction triple`; the

  `SetDir`-shaped call **0x1E2F0**(1, 0) is used on the mouse-steering facing paths.



The body always faces the direction of travel (or the camera-rotated input while

turning) — the camera never drags the facing.



## 8a. Per-frame order of the facing update (M27) — closes gaps row D3



**M27 [local].** Where the facing decision sits inside retail's per-frame local-player

update, re-read from raw bytes 2026-10-05 to settle whether kuluu's fixed chain order is right.



The routine is **0xA65CB..0xA70AB**, ending `ret 4` (`c2 04 00`) at 0xA70AB; `this` = `esi`,

no direct callers (vtable-dispatched). Heading field = **actor+0xE8**; the direction triple is

**+0xE4 / +0xEC / +0xF0**. The linear sweep splits this body at every `ret`, so its heuristic

bound for the opening instruction (`func 0xA65CB` → `..0xA6817`) is wrong in length only — the

region was walked in three pages and every address below is an instruction start.



Order as the bytes give it, with each write's guard read from the same stream:



| step | RVA | what happens (bytes) |

|---|---|---|

| 1. inputs | 0xA65D1 / 0xA6603 / 0xA6610 | key-state getter on `[0x1057876C]` (`call 0x10158aa0`), then the analog-axis getter `0x10123970` twice |

| 2. steering | 0xA6630 / 0xA665A | mouse-steer enable gate `0x1025e050`, handler `HandleMouseSteering 0xA77A0` (M22) |

| 3. rate | 0xA668A | speed/deadzone law `0xA78D0` (M3) |

| 4. camera re-anchor | **0xA66D3** | `call 0x1001ee60` — M11, and it runs *before* any movement math |

| 5. pre-integration facing write | 0xA6899..**0xA69A2** | gated on free-run `[eax+0x330]` true (@0xA689D), `[eax+0x340]` false (@0xA68AF), and byte-valued `f6 c4 44; jp` NaN/equal test on `[esp+0x10]` (@0xA68BD). Angle from getters **0x1025e170 / 0x1025e100** (@0xA68D2/@0xA68DB), sign-steered by byte **`[0x10487F81]`**, normalized with this layer's ±π triple (`[0x10329d30]/[0x10329d2c]/[0x10329d28]`, @0xA6944..0xA6966), then `mov [esi+0xe4]/[esi+0xec]/[esi+0xf0]` + **`fstp dword ptr [esi + 0xe8]` @0xA6988** (`d9 9e e8 00 00 00`) followed immediately by the M18 engage `call 0x1001e2f0` @0xA6998. Both arms converge on tail 0xA6A6F |

| 6. position integration | **0xA6F1D → 0xA6F46** | contact gate `call 0xa8770`; if not blocked, `*pos += dir` (x @0xA6F31, y @0xA6F39, z @0xA6F43) — M9 |

| 7. **final facing write** | 0xA6F4D..**0xA70AB** | gated again on free-run `[edx+0x330]` true and `[eax+0x340]` false. Single-axis shortcut: two NaN-safe zero tests on `dir.z [esp+0x20]` (@0xA6F6D) and `dir.x [esp+0x18]` (@0xA6F82), each `jp` straight to **0xA7072**. There `fld [esp+0x20]; fld [esp+0x18]; fpatan; fchs` → yaw = −atan2(dir.z, dir.x) stored at **0xA709D**; direction triple @0xA7088..0xA7094, `ret` @0xA70AB. Diagonal path: keyvec built by `0x10026e50` (@0xA6FD2), camera azimuth read as **`[cam+0x24]`, with `[cam+0x2C]` negated** (@0xA6FE6..0xA6FF6), rotated by `0x10027bd0` + `0x10028200`, atan2 at **0xA7035** stored at **0xA705B**, `ret` @0xA706F |



**Heading-write census inside this body:** 0xA6988 (`fstp`), 0xA705B (`fstp`), 0xA709D (`fstp`);

one read at 0xA6EA2 (`mov edx, [esi+0xe8]`). Writers beyond the `ret` belong to sibling routines

(heuristic bounds fn 0xA7324..0xA73DD → **`fst [esi+0xe8]` @0xA73C9**; fn 0xA73DD..0xA7439 →

**@0xA7431**), each entered through the same class dispatch and gated by the status chain

(`0x84390` ∉ {edi,1,4,0x1c,0x1f}, then mount preds 0x84350/0x84370) plus free-run `[edx+0x330]`,

with a slot test `mov ecx, OFFSET 0x10487f74` (`b9 74 7f 48 10`) + `call 0x10081550; jne` @0xA7373..0xA737F

(entity-reference slot object — resolved in M28 below).



**M27 conclusions.**

1. Retail's *authoritative* facing write is **post-integration and travel-derived**: when free-run

   and moving, the last thing the routine does before returning is recompute yaw from the very

   direction vector it just integrated (0xA705B / 0xA709D), so nothing can sneak a heading in after.

2. When *not* free-run or not moving, the routine writes **no** facing at all on those paths —

   which is how an authored drive-task angle survives a locked-animation tick (drivetask §13/§14).

3. The one branch that writes heading early (step 5) also fires the M18 spring setter in the same

   breath, so it is the steer/ease case, not a competing travel read.



**kuluu.** No ordering change needed — confirmed by reading the tree, not the handoff. The fixed

chain (`dispatch_movement_system → recover_self_ground_system → apply_self_prediction_system →

stair_capture_system`, `kuluu/src/view_native/mod.rs` 825–835) decides facing and integrates the

step in one system: authored base heading first (`authored_heading.unwrap_or(self_pos.heading)`,

`input.rs` ~1570), travel re-aim over it, position written last. Same precedence as M27:

authored survives when not travelling, travel wins on a moving tick. Heading has exactly one

writer in kuluu's player path (plus `rendered_heading_rad` for remote ActorRotation,

`scheduler_runtime.rs:2486`).



**M28 [local] — the entity-reference slots (`0x10487F58` / `+64` / `+74`), re-read 2026-10-05 [V].**

Closes the "follow-actor slot" research item, and **refutes its original framing**: `0x10487F74` is not a

pointer-holding variable. Every one of the **26** code references to it is `mov ecx, OFFSET 0x10487f74`

(`b9 74 7f 48 10`) — the address of a *static object instance*, passed as the thiscall receiver; no instruction

loads or stores through that address. Sibling statics of the same shape exist at `0x10487F64` (22 refs) and

`0x10487F58` (15 refs), consulted by camera routines too (`call site 0x1F26B in fn 0x1F237`, near

`UpdatePlayerFollowingCamera` 0x1EE60, and `0x20EF7` in fn 0x20DD4), so this is a small set of named

*entity-reference slots*, not one variable.



The resolution law (method **RVA 0x81550**, `this` = slot object; bytes `83 ec 0c / 56 / 8b f1 / 8b 46 04 /

8b 04 85 f0 0a 48 10`) is a **validated index, not a pointer**:



```asm

mov eax, [slot+4]                        ; u32 index into the global entity table

mov eax, dword ptr [eax*4 + 0x10480af0]  ; g_actorTable[index]

test eax, eax; je fail                   ; empty slot

mov ecx, dword ptr [eax + 0x120]; shr ecx, 9; test cl, 1

je fail                                  ; entity validity bit: bit 9 of dword entity+0x120

mov edx, dword ptr [eax + 0x78]          ; the entity's own identity stamp

mov ecx, dword ptr [slot+8]

cmp edx, ecx; jne fail                   ; stamp must match slot+8 (kills stale/recycled indices)

mov eax, dword ptr [eax + 0xa0]          ; return the entity's +0xA0 actor pointer

ret

```



So a slot is `{u32 index into g_actorTable; u32 identity stamp}` and resolving it re-checks both the table entry and

the stamp before handing out an actor — retail never caches a raw actor pointer here. Bytes only for what the two

fields *mean* per address (which slot is camera focus vs locked target vs follow): settling read is to enumerate,

for each of `0x10487F58/+64/+74`, the writers of `slot+4`/`slot+8` (the pair-store at RVA 0xA609E/0xA60A3 writes

`[0x10487f68]`,`[0x10487f6c]`, i.e. the +4/+8 of the slot based at `0x10487F64`) and read what each role's consumer

is.



Behaviour already readable from consumers: the heading-writer sibling fn 0xA7324 **bails out of writing facing**

when a slot resolves non-null (`test eax,eax; jne 0x100a73dd`), and fn 0xA6A6D consults it twice (0xA6AAB, 0xA6AF3)

— i.e. while such a reference is live, travel-derived facing is suppressed for the local player.



## 9. Camera follow (M11)



**M11 [local].** `UpdatePlayerFollowingCamera` = **0x1EE60** on the camera manager.

Called at 0xA66CB only when `byte ([0x4568FC]+8) == 0` **and**

`(key1 != 0 || key2 != 0)` — i.e. the camera is re-anchored to the player only while

movement keys are pressed; otherwise it stays where the user aimed it (the free

camera). This is the "drag / re-anchor" behavior: the camera does not continuously

track the player.



## 10. Q/E turn keys (M15, M16)



**M15 [local].** The Q/E turn keys drive **both** the camera and the body.



Camera side — **superseded in full by M30 (§10b)** on 2026-10-04. The block first

written here read `cam+0x48` as an azimuth accumulator fed by the turn axis, and called

the `call 0x1EBB0(angle)` rotator degenerate ("the angle slot is zero-cleared before the

key-hold multiplies"). Both readings came from mis-tracking the esp frame across a pair of

pushes: those slots are *overwritten* by the axis reads afterwards. `cam+0x48` is an

eye-position component, and the rotator path is the live azimuth law — byte record in §10b.



Body side — in the control function (0xA65CB), reached when free-run, no event

sub-state, and the W/S axis >= 0:



```

Q_held = 0x25E100()  ; 0xA68DB : input mode == 1 (call 0x123EE0), axis6 >= 0,

                     ;          axis7 >= 0, SomeKeyCheck(0x3F, 0xA9, 4, -1)

E_held = 0x25E170()  ; 0xA68D2 : same gate, key 0xAA instead of 0xA9

turn   = E_held - Q_held          ; 0xA68E6 (fsubr computes m − st = [c] − st,

                     ;           and [c] holds the 0x25E170/E result — earlier pass transposed)

```



- auto-run && turn >= 0: the A/D axis slot is forced to **+1.0** (0xA68FB) and

  the run steers — the auto-run steer, the body turning with the held key;

- A/D > 0 branch: the body heading is **re-assigned** to

  `slot + (π/2) * slot * turn` (0xA692A..0xA6936, π/2 @0x32D430), the direction

  triple and yaw are written to **actor+0xE4/+0xEC/+0xF0/+0xE8** and the

  SetDir-shaped **0x1E2F0** is called (0xA696C..0xA6998) — the body rotates to

  face the new travel direction;

- A/D < 0 branch: the W/S slot is zeroed, the direction is rebuilt from the

  lateral axis (normalize via 0x274B0 at 0xA69F9) and 0x1E2F0 is called

  (0xA69B7..0xA6A1A).



So retail Q/E is not a rotate-in-place: it integrates the camera azimuth (M15

camera side) and re-assigns the body heading so the body keeps facing travel

(M15 body side) — the same facing-from-travel rule as M10, driven by the turn

keys instead of the move vector.



**M16 [local].** Device 0x3F analog action table (this build):



| action | key | read as |

|--------|-----|---------|

| 4 | W/S | AnalogKey1, forward axis (0xA6603) |

| 5 | A/D | AnalogKey2, sign-inverted at read (0xA6610, fchs) |

| 6 / 7 | Q/E | the signed turn pair: axis6 feeds the camera azimuth (M15); axis6/axis7 >= 0 gate the Q/E predicates; 0x25E1E0 returns `E_held - Q_held` |



Discrete key checks ride the same device via 0x123A70 (SomeKeyCheck):

**0xA9 = Q**, **0xAA = E** (0x25E13B, 0x25E1AB). The camera update also polls

raw key holds 0x8B/0x8C through 0x193850 (0x1EF67, 0x1EF86) on the degenerate

1.6° path.



## 10a. Mouse aim and steering (M21–M23)



**M21 [local].** Mouse input object `[0x104E1D4C]` keeps an anchor/cursor pair:

cursor at `+8/+0x3C`(x) and `+4/+0x38`(y), screen rect globals

`[0x106218B4..BA]`. Normalized offset accessors clamp toward the edges:

X `0x125FE0`, Y `0x126100`: `offset = Δpx × (1/21 @0x32DF9C) ÷ screen-extent`,

saturated to **±1.0** (`1.0 @0x32961C`, `-1.0 @0x32A3F0`); Y sign-flipped.

Raw float state fields: getters 0x1260D0 (+0x8C), 0x1260C0 (+0x90), 0x1260F0

(+0x94), 0x1260E0 (+0x98). **There is no per-pixel radian sensitivity anywhere

on this path — aim is absolute cursor position, not mouse-motion deltas.**



**M22 [local].** Steering law `0xA77A0` (consumed by the walker at 0xA665A when

CFsConf6Win and bit `([mouse]+0x58 >> 2) & 1`, results into the axis slots and

`[mouse]+0xA8` float / `+0xAC=1`): from (nx, ny) = M21 offsets —

θ = fpatan(ny, nx); sector = round(((θ + π)/(2π) + 1/32) × **16**) & 0xF

(constants π @0x32DF98, 1/2π @0x32DF94, 1/16 @0x32A9F0, 2π @0x32DF90,

round-to-int 0x311C2C); out = (cos, sin, sector·(1/16)·2π − π). i.e. the

cursor direction is quantized to **16 compass sectors**. Degenerate guard: both

offsets saturated ⇒ returns false.



**M23 [local].** The mouse-aim dispatcher (seed 0x125360, state byte

`[mouse]+0x4D`) gates on device-group **0x3E** button queries {0x8B, 0x96} and

CFsConf6Win. Position branch: θ = fpatan(offset pair) − (π/2 approx @0x32D430),

wrapped into ±π, stored in state global `0x1036E5F4` (accessor offsets) or

`0x1036E634` (raw field deltas); zero-offset special case stores −(π/2 approx)

and sets word `[mouse]+0xA6 = 0xC`. Both globals are read **only inside this

handler** (whole-file disp32 census). The tail converts θ to **virtual action

presses 0x16–0x19** (`push id; call 0x15DD00`, 0x125B87..0x125BEF) through a

tick-driven counter ramp (round@0x311C2C, imul accumulator with compare clamps

0x125C5A..0x125CA2 — rate semantics [I]). **Mouse aim therefore terminates in

virtual arrow-key actions**, which the M15/M19/M20 keyboard integration then

consumes — one more reason kuluu should not model mouse and arrows as separate

scales (gaps C3, C2).



### §10a-ii — M36: the mouse state machine behind drag aiming **[V]** (pass of 2026-10-06 against `FFXiMain.unpacked.dll`, TDS 0x6A995428)



**M36 [V].** Names what kuluu's "drag button held" gate stands for. Everything below is a byte read in

this build; RVAs are `.text` unless marked, and `obj` is the single mouse-state object.



**The object.** Allocated once: `push 0xb0 / call 0x311BBB` (operator new) at **0x1651B4**, constructed by

`mov ecx, eax / call 0x124440` (**0x1651C7**), stored into `.data 0x104E1D4C` (**0x1651CC**). Its ctor

(`0x124440`) zeroes the state byte (`ebx` zeroed at **0x124445**, `88 5e 4d` = `mov byte [esi+0x4d], bl` at

**0x124462**), sets the mouse-enable byte to 1 (`c6 86 88 00 00 00 01` at **0x124465**) and stores

`.rdata`-independent `-1,000,000.0f` (`c479c000`) into `[obj+0x70]` (**0x12445B**). So `byte[[0x104E1D4C]+0x4d]`

is *runtime mouse state*, not a configuration value: it starts at 0 and only the chains below move it.



**Fields, as used by this cluster (size 0xB0).** `+0x04/+0x08` = current cursor x/y (the mode-5 chain reads

them against the press anchor, e.g. **0x125233**/**0x125240**); `+0x0C/+0x10` = the same pair copied each

frame (**0x12548B**/**0x12548E**); per-button press anchors at `[obj + slot*8 + 0x1C]` x and `+0x20` y, held

byte per button at `[obj + slot + 0x34]`, with slots 0/1/2 as the chains pick them up below; drag aim

anchors at `+0x38/+0x3C`; state byte `+0x4D`; two flag bytes `+0x54`/`+0x55`; countdown slot `[obj+0x74]` for

the left chain and `[obj+0x78]` for the right; mouse-enable `+0x88`.



**Two chains, one per drag button, run every frame in a fixed order.** The handler **0x1253A6** calls the

right-button chain first (`e8 c5 fd ff ff` = `call 0x125170` at **0x1253A6**) and the left-button chain last

(`call 0x125040` at **0x1253AD**), so when both would engage on one frame the byte ends up reading 4. The

same handler also forces mode 0 from outside: `mov byte [esi+0x4d], 0` at **0x12537A** behind a true return of

`call 0x1606f0` (object `0x10621838`) and at **0x125396** when `[0x10666e7c] != 0`.



*Right chain (`0x125170`).* Reads the byte: ≤0 → arm the countdown (below) and return; ∈{1,2} → evaluate

entry; >2 and ≠5 → re-arm and return; ==5 with mouse-enable set → stay in 5, otherwise fall back to mode 1

(`mov byte [esi+0x4d], 1` at **0x12519B**). Button query: `GetAnalogKey(0x3E, action 0x8C, 4, -1)`

(**0x1251A6..0x1251BE**, slot index forced to 1 by `mov edi, 1` at **0x1251B1**); if the `CFsConf6Win` flag

(`call 0x125e050`) is set *and* that query returned 0, it re-queries with action **0x8B** (**0x1251CD..0x1251E0**).

Entry then requires, in order: the queried byte `== 1` exactly (`cmp bl, 1 / jne` at **0x125222**), the held

byte `[obj+slot+0x34]` non-zero (**0x12522B**), and — the interesting part — *either* arm of displacement or

hold-time (next paragraph), then `+[0x54] == 0 && +[0x55] == 0` (**0x125266**/**0x12526D**), then `call

0x239490 != 0` **or** game state `[[0x10456a28]] ∈ {0x60, 0xd0}` (**0x125274..0x12528F**), then mouse-enable

(**0x125291**) → `mov byte [esi+0x4d], 5` at **0x12529B**.



*Left chain (`0x125040`).* Same shape, own countdown slot `[obj+0x74]`: modes {1,2} evaluate; mode ==4 with

mouse-enable stays, without it drops to 1 (**0x12505F**). Default action **0x8B** with slot 0 (`mov edi, 0x8b`

/ `xor ebx, ebx` at **0x125071**); under the `CFsConf6Win` flag it becomes action **0x96** with slot 2

(**0x125081**/**0x125086**) — so `{0x8B, 0x96}` are *the same drag button in two control profiles*, not two

buttons. Its state gate is stricter: `[[0x10456a28]] == 0x60` only (**0x125140..0x125149**), no `0x239490`

alternative → store 4 at **0x12515D**.



**Engagement arm 1 — displacement from the press anchor.** Integer squared distance cursor-minus-press:

`imul edx,ecx / imul ecx,eax / add edx,ecx` then `cmp edx, 0x40 / jg entry-checks`. Left chain **0x125105..0x125114**

(`cmp edx,0x40` at **0x125111**), right chain **0x125247..0x125254** (at **0x125251**). Eight pixels is the

gate — and it is measured *from the stored press position*, not as accumulated per-frame motion: wander

inside the gate for a minute and nothing engages, walk 9 px in one frame and it does.



**Engagement arm 2 — hold the button still until a countdown expires.** Each chain owns a float slot armed

to `0x41c80000` = 25.0: `[obj+0x78]` at **0x1252A6**, `[obj+0x74]` at **0x1250CD** and **0x125063**. While the

button byte is non-zero the whole-tick clock (M29 getter `0x14CF0`, rounded by `call 0x311C2C`) is subtracted

from it — right chain **0x1251FE..0x125216** (`db 44 24 0c fild` / `d8 6e 78 fsubr [esi+0x78]` / `d9 5e 78

fstp`), left chain **0x1250B0..0x1250C8**; the arm branch runs when that clock is no longer positive, using

the *non-parity* form of the flag test (`fnstsw ax / and eax,0x4100 / jne` at **0x1251F3..0x1251F8**,

identically **0x125096..0x12509B**), which under the joint.md §J10 table means "not strictly above", i.e. ≤ 0

or unordered → re-arm to 25.0 and stop counting. The entry gate then tests the same clock the *parity* way:

`fld [obj+0x78] / fcomp dword [0x103295d8] / fnstsw ax / test ah, 0x41 / jp exit-no-entry`, right chain

**0x125256..0x125264**, left chain **0x125116..0x125124**. `.rdata`-adjacent constant `0x103295d8` reads back

as **+0.0** (`00 00 00 00`, dumped), and per J10 mask `0x41` means *jp = above-or-unordered*, so falling

through — admitting entry — requires the clock ≤ 0. Both forms agree: a countdown from 25.0 in M29 tick units,

i.e. ~13 frames at the default cap (≈0.42 s), after which standing still on a press engages the drag.



**The two flag bytes gate entry, and are not configuration.** `+[0x54] = 1` is written at **0x1254DC** inside

the per-frame handler behind *five* conditions: action `0x8B` with mode filter arg 1 reads exactly 1

(**0x125497..0x1254AC**), `call 0x126290(this)` true, `[esp+0x10] != 0`, `call 0x118c10(&[obj+4])` true, and

`call 0x15dce0(0x10621838)` **false**. Both flags clear together when action `0x8B` with mode filter arg 4

reads 0 (**0x1254E0..0x1254FA**: `mov byte [esi+0x55], al / mov byte [esi+0x54], al`). Separately, the

absolute-cursor normaliser **0x157720** (M31's writer of `[obj+0x8C]/[obj+0x90]`) sets `byte [obj+0x55] = 1`

unconditionally as it stores (**0x157751**), and clears happen in **0x15783E**'s neighbourhood

(**0x157940**, **0x1579DA**, **0x157AE4**). So a drag cannot be entered while an absolute-cursor aim sample is

installed — which is consistent with M31's two-shape finding but not a name for the flags; see open items.



**The two action tables are function-pointer arrays, not key maps (re-read 2026-10-06 against `FFXiMain.unpacked.dll`, TDS `0x6A995428`, for gap row C3).** M31 found the gate word; this pass decodes what sits in the arrays. Analog getters live at `.data 0x1036D0D8` and IsDown getters at `.data 0x1036DB18`, both stride 8 indexed by action id:

| action | analog getter | its body, decoded | IsDown getter |
|---|---|---|---|
| 4 / 5 / 6 / 7 | `0x120C10` / `0x120C40` / `0x120C70` / `0x120CA0` | one shape for all four: read a byte on the device object (`+0x253`, `+0x252`, `+0x250`, `+0x251` respectively), `sub eax, 0x80` (bias −128 to signed), store it, `fild` then `fmul [0x1032A778]` — M20's 1/128 axis scale with the bias now visible | act 4 → `0x122450`, act 5 → `0x1226A0`; **null entries for 6 and 7** |
| `0x4F` / `0x50` (zoom in / out) | **null analog** | the query that exists is IsDown: `0x121970` / `0x121A80`, each a ≤6-entry mode-indexed jump table (`cmp eax, 5 / ja none`) whose first arm reads device `[+0x238]`; out-of-range returns false | same pair |
| `0x8B` / `0x8C` / `0x96` (the drag-aim ids M36's two chains query) | `0x122E00` / `0x122DF0` / `0x122E10` — **all three bodies are a single `fld dword [0x103295D8] ; ret`, i.e. the constant +0.0** | `0x120980` / `0x120A20` / `0x120AD0`: load `[0x104E1D4C]` (the mouse object M36 identifies), null-guard to false, `cmp eax, 5 / ja` → false, then jump tables `.rdata 0x10120A08`, `0x10120AAC`, `0x10120B68`. Every arm masks bit 0 (`and eax, 1`) of a mouse state word and returns it; two arms per getter are *consuming* reads that clear bit 0 across three words before returning the old value | same triple |

Three consequences, each byte-backed.

1. **An analog read of a mouse button is provably dead code in this build** — its getter returns +0.0 unconditionally. Nothing kuluu can be missing on that path; anything here that wants "how hard" must come from position geometry (M31/M22), not from an action axis.
2. The second argument of these getters is a **mode selector over state words** (`0..5`, out-of-range = false), distinguishing current / edge / edge-with-clear reads on `mouse+{0x58, 0x5C, 0x60, 0x64}`. It is *not* a bit index: the three button getters differ by function and jump table, not by masking different bits of one word.
3. Actions 6/7 have an analog getter but no IsDown getter at all (null row), matching M20's reading that the camera axes are axis-valued only.

Still open on this sub-item: which **physical** button each id is. The getters read the same four state words with bit 0, so nothing inside them names left/right/middle. Settling read: the writer of `mouse+0x5C`/`+0x60`/`+0x64` (a whole-`.text` displacement census finds the stores outside this cluster; follow from the message pump that also writes the object's cursor position and see which button each store corresponds to).

**Mode census in this build.** Stores of `+0x4D` (byte-size writes, from a whole-`.text` sweep) land only in

this cluster: 0 → **0x12537A**, **0x125396**; 1 → **0x12505F**, **0x12519B**, **0x1252D7**; 2 → **0x1252D1**;

3 → **0x125594**; 4 → **0x12515D**; 5 → **0x12529B**; 6 → **0x125626**. Readers compare against the mode: `==5`

at **0x12330C**, **0x12347C**, **0x1249C1**, **0x124A90**, **0x158670**; `==4` at **0x158690** (and that pair is

itself gated by the `CFsConf6Win` flag the opposite way round: mode 5 is consulted when it is *set*, mode 4

when clear, **0x158662..0x1586A0**); `==6` at **0x125001**; `==3` at **0x125E1A**; `==2` at **0x125D11**,

**0x1262E0**, **0x14A9B2**, **0x15DDC1**, **0x15DE77**, **0x15DEFC**, **0x1E4634**, **0x1F6A46**. The handler's own

dispatch is a jump table `.data 0x10125f2c` indexed by mode, guarded `cmp eax, 6 / ja default` at

**0x125502..0x12550B**.



**Aim shape while engaged (ties back to M31).** Mode 4/5 take the anchor-relative accessor pair — cursor minus

the drag anchor (`[obj+8] - [obj+0x3C]`, `[obj+4] - [obj+0x38]`) divided by extent × `.rdata 0x32a39c` (= 0.2,

dumped) and clamped ±1: **0x126190..0x1261F1** (upper clamp via `fcom [0x1032961c]` + `and eax,0x4100 / jne`,

lower via `test ah, 5` with J10's "jp = not-below") and its twin **0x126200**. `.rdata 0x32df9c` dumps as

`3d430c31` = **0.0476185 ≈ 1/21**, the left chain's denominator M31 recorded.



**Consequence for kuluu.** Row C3 is now a *law*, not a shape: aiming requires an engaged drag; engagement is

displacement-from-press > 8 px **or** ~0.42 s of hold; while engaged the axis is anchor-relative at 1/5 (right)

or 1/21 (left) of the extent; left has precedence on a tie. Ported as `jw-stack-815 b4d62400`

(`mouse_drag_aim_axis`, `DRAG_ENGAGE_PX_SQ = 64`, `DRAG_ENGAGE_HOLD_SECS = 25/60`, per-button `DragTrack`).

Still [I], with the reads that would settle them: (a) physical identity of action ids `0x8B` / `0x8C` / `0x96`

— their *roles* are recorded above, and the settling read is the device-0x3E row of the input-action table in

`.data` (or `decomp/GetAnalogKey_123970.c`, which this checkout does not carry); (b) what `+[0x54]` / `+[0x55]`

mean beyond their verified writers/clearers — settling read: the callers of `0x118c10`, `0x126290` and

`0x15dce0`; (c) what modes 1/2/3/6 do downstream (mode 5's consumers are M31's accessors, mode 4's are the 1/21

pair; settling read: the `0x10125f2c` table bodies).



### §10a-iii — What each mode byte value does downstream: the `+0x4D` dispatch bodies **[V]** (pass of 2026-10-06 against `FFXiMain.unpacked.dll`, TDS 0x6A995428)

**M37 [V].** M36 named the mode byte and its writers; this pass reads what each value *does*, closing the "modes 1/2/3/6 downstream" item that §10a-ii left open.

The dispatch is one jump table **at RVA 0x125F2C, inside `.text`** (`pefile` section lookup: `section_of(0x125F2C)` = .text — MSVC parked it in the code padding after the handler). §10a-ii called it `.data 0x10125f2c`; that address is the VA with ImageBase added and its section label was wrong. Reached from `33 c0 / mov al,[esi+0x4d]` at **0x1254FF**, guarded `83 f8 06 / ja 0x10125d11` at **0x125502**, dispatched `ff 24 85 2c 5f 12 10` = `jmp dword ptr [eax*4 + 0x10125f2c]` at **0x12550B**. Bodies, in the order the table lists them:

| mode | body | what it does (bytes) |
|---|---|---|
| 0 | **0x125512** | `test edi,edi` / `test ebx,ebx` → shared tails only. Idle: no side effect on the object beyond the tails below. |
| 1 and 2 | **0x125527** (one body for both — table entries at 0x125F30 *and* 0x125F34 are identical) | `call 0x1252C0` (M36's re-arm helper), then mode-2-only: query action **0x8B** on device **0x3E** with filter arg 1 and slot −1 (`push -1 / push 1 / push 0x8b / push 0x3e / call 0x123a70` at **0x125531..0x125549**) — the consuming read of M36's word-selector set. If it reads exactly 1 (**0x12554C**), `[edi+0xC] < [edi+0x10]` holds (**0x125558..0x125560**), `call 0x15dce0(0x10621838)` is **false** (**0x125562..0x12556E**) and the cursor hit-tests inside that widget — `mov ecx,[esi+4]/[esi+8]; call 0x102347d0(edi,x,y)` at **0x125570..0x12557F** — then a non-3 result just sets `[obj+0x86] = 1` (**0x125587**) while result **3** stores the widget handle to `[obj+0x00]`, copies `[edi+0x14]` into `[obj+0x6C]`, and **enters mode 3** (`mov byte [esi+0x4d],3` at **0x125594**) before returning. No hit → re-arm the left countdown to 25.0 (`c7 46 74 00 00 c8 41` at **0x1255AE**), clear `[obj+0x86]`, then query action 0x8B with filter arg **5** (**0x1255BC..0x1255CC**); success stores the handle to `[obj+0x00]` and **enters mode 6** at **0x125626**, arming `[obj+0x7C] = round([0x311c2c]) × [0x10329d38]` (**0x12562A..0x125644**). |
| 3 | **0x1256AA** | query action **0x8B**, device **0x3E**, filter arg **4**, slot −1 (`push -1 / push 4 / push 0x8b / push 0x3e` at **0x1256AA..0x1256B5**); if it no longer reads 1 → tail `0x125D11`, else the other tail. i.e. "the widget press captured in mode 3 is still held" — releasing it drops the mode. |
| 4 | **0x1256CA** | M36's left-drag body; its aim consumers are the anchor-relative accessor pair at 1/21 (§10a-ii). Not re-read here. |
| 5 | **0x125888** | M36's right-drag body; its aim consumers are M31's accessors at 1/5. Not re-read here. |
| 6 | **0x125B19** | **UI caret / scroll auto-repeat**, not aim. Two floats drive it: `[obj+0x7C]` (offset accumulator) and `[obj+0x80]` (repeat count). It subtracts the tick (`call 0x14cf0`, rounded by `call 0x311c2c`) and the cursor delta vs `[obj+0x30]` from `[obj+0x7C]` (**0x125C00..0x125C28**), derives a sign in `ebx` (**0x125C2A**), reads the widget's character range as words — `sub cx,[0x106218ba] ; sub cx,[0x106218b6]` at **0x125C2D..0x125C34** — and runs it through a divide-by-3 ladder (`imul 0x66666667`, `sar 2/3`) with three clamps (**0x125C5A..0x125CA2**) to grow `[obj+0x80]` by ×1, ×3 or ×5. Then it pushes exactly one of four ids — **0x19** (**0x125B87**), **0x18** (**0x125BAF**), **0x17** (**0x125BC7**), **0x16** (**0x125BEF**) — to `call 0x15dd00` with `ecx = 0x10621838`, chosen by the sign/zero tests of those two floats, and finally checks the widget is still the same one (`mov ecx,0x10621838 / call 0x160c90 / cmp [esi],eax` at **0x125CBC..0x125CC3**). |

Three consequences.

1. **M23's "mouse aim terminates in virtual action presses 0x16–0x19" is located, and it is *not* on the camera path.** Those pushes (0x125B87..0x125BEF) live inside the mode-6 body, which is reachable only after modes {1,2} saw a press hit-test inside widget `0x10621838` and armed it at **0x125626**. Mode 6 is text/scroll caret repeat. The camera aim consumers stay M31/M36's anchor-relative accessors (modes 4/5). kuluu must not route cursor aiming through arrow-key emulation — retail does not.
2. **Nothing in modes {0,1,2,3,6} gates behaviour kuluu ships.** They touch `[obj+0x86]`, the stored widget handle at `[obj+0x00]`, `[obj+0x6C]`, the countdown slots and the caret floats; none of them reads or writes the aim fields (`+0x8C/+0x90`, `+0x38/+0x3C`) that M20/M30 integrate. So this row closes with *nothing to port*; the residual difference from retail is kuluu's missing UI caret-repeat feature (and its missing cursor-steered walking, M22's 16-sector consumer at `HandleMouseSteering 0xA77A0` — a product gap, not an unported law), both recorded as such rather than left dangling as if a read were outstanding.
3. **Two of §10a-ii's open `[I]`s moved.** (i) `call 0x126290(this)` is a two-instruction thunk: `b9 38 18 62 10` = `mov ecx, 0x10621838` then `e9 16 8b 03 00` = `jmp 0x15edb0` (**0x126290..0x126299**) — it asks the single window object a question of its own, so `+[0x54]`'s five-condition writer (M36) is *a UI-window predicate chain*, consistent with "a drag cannot start over that widget". (ii) `call 0x15dce0(0x10621838)` reads a global byte: `a1 cc 81 57 10` = `mov eax,[0x105781cc]`; `mov dl,[eax+0x48]; test dl,dl; je fallback; mov al,1; ret`, else `call 0x160700` and return its non-zero flag (**0x15DCE0..0x15DCF9**) — a modal-ish global. The id injector `0x15DD00` applies the *same* gate before accepting any press (`call 0x15dce0 / test al,al / jne` at **0x15DD03..0x15DD0A**). Still `[I]`, with its settling read: who sets `[0x105781CC]+0x48` (a displacement census over `.text` of the byte write `+0x48` on that object), and the physical identity of action ids 0x8B/0x8C/0x96.

## 10b. The two aim axes and their laws (M30)



**M30 [V].** Closes "the unit of `[cam+0x48]`" (§16) and re-draws the aim path end to end

inside `UpdatePlayerFollowingCamera` **0x1EE60**. TDS 0x6A995428, read 2026-10-04.



*Object identity.* Both call sites of 0x1EE60 (`0xA5EAC`, `0xA66D3`) do

`call 0x15250; mov ecx,eax; call 0x1EE60`, so `this` is the rig returned by `GetCameraMng` =

`[[0x104568FC]+0x50]` (M12), **not** the tick object at [0x104568FC]. That one register

reaches every field below and both rotator calls — which is what the unswept 0x20FF0

fragment could not settle.



*Field geometry.* +0x44/+0x48/+0x4C and +0x50/+0x54/+0x58 are two world-space points (eye /

look-at), as M12's table already said:



- Rotator **0x1EBB0** (`ret 4`, one float argument): `dx=[+0x50]-[+0x44]` (0x1EBB6..),

  `dz=[+0x58]-[+0x4C]` (0x1EBC0..); `fpatan` 0x1EBCE then `fadd arg` 0x1EBD0; wrapped against

  +π (.rdata 0x329D30), a full turn (0x329D2C) and −π (0x329D28); magnitude via **0x27680**;

  then **eye.x = lookat.x − d·cos θ** (`fcos` 0x1EC3F → `fstp [+0x44]`) and **eye.z =

  lookat.z − d·sin θ** (`fsin` 0x1EC4F → `fstp [+0x4C]`). **The orbit never writes +0x48**, so

  its argument is a signed radian azimuth delta.

- Vector helpers pin the layout: **0x27120** = 3-float subtract (called at 0x1F05C on

  &(+0x44),&(+0x50)); **0x27530** = dot product, `fsqrt` 0x1F076 → full 3D |eye−lookat|.

  Whole-vector adds of the triple sit at 0x1E7D6/0x1E8A8/0x1E9A9.



*Axis intake* (slots from a mechanical push/pop walk of the frame): `GetAnalogKey(action 6)`

→ slot A (`fstp` 0x1EF53, zeroed 0x1EF30); `GetAnalogKey(action 7)` → slot B (`fstp`

0x1EF60, zeroed 0x1EF38). Digital action **0x8B** multiplies A by −1.0 (.rdata 0x32A3F0) at

0x1EF78..0x1EF82; **0x8C** does the same to B at 0x1EF97..0x1EFA1 — reverse partners of those

two axes, not extra axes.



*Law 1 — azimuth (slot A).* `tick(0x14CF0) × A × .rdata 0x32A3EC (0.027924445)`

(0x1F01F..0x1F032); when **not** free-run (`call [[arg-1 actor vt]+0x330]`, regime note below) it is additionally scaled by `.rdata 0x32A3E8

(6.0) / max(|eye−lookat|, .rdata 0x329A18 (0.01))` (0x1F07B..0x1F09C), then handed to the

rotator at **0x1F0ED** (second site **0x1F255**, re-anchor branch). ⇒ *constant tangential

speed*: 60 × 0.027924445 × 6 = **10.053 world-units/s of arc**, i.e. ω = 10.053/dist rad/s.

That `6.0` is the same literal as the focal-zoom step (M17), and this is XIClient's

`angle = 6.0f / eyeToTargetDistance * angle`, now [V] in this build without needing [web].



*Law 2 — eye height (slot B).* `[+0x48] += tick × B × .rdata 0x32A3E4 (0.10666667)`

(0x1F0F2..**0x1F14A**) ⇒ **6.4 world-units/s**, distance-independent: retail tilts by moving

the eye's world Y at fixed XZ offset, exactly what kuluu's `ChaseCamera` pitch comment

asserted from XIClient.



*Shared gates.* While hold-flag **[0x10456D7C] > 0** each contribution is forced to zero

(azimuth 0x1F0B0..0x1F0C5 and 0x1F218, height 0x1F113..0x1F128). When an axis is live and a

suppression predicate fails, countdown **[0x10456D74]** arms to **10** frames (M29 units) at

0x1F0E0 / 0x1F141 / 0x1F2AD. Other writers of +0x48: the vector adds above, and an

anchor-height re-centring `[+0x48] += ([[actor vt]+0x1BC](…).y − [0x10456DA0])` at

0x1F285..0x1F29D.

*Input accessor correction (the "device tables" read).* **0x123970** (*GetAnalogKey*) is **not

device-indexed**: its second argument is an **action id**. Gate = `word[0x1036CF60 +

action*2]` ANDed with the active-device mask [0x1036E3A0] (returns 0.0 when unclaimed);

accessors are a per-action pair at `.data 0x1036D0D8 + action*8` = (+0 raw, +4 composite). When

both exist each runs and the larger magnitude wins (`abs` via ×−1.0 .rdata 0x32A3F0 at

0x123A37/0x123A4C, `fcompp` 0x123A56, `and eax,0x4100`, tail-call to the winner at

0x123A61/0x123A67). So "device 0x3E {0x8B,0x96}" and "device 0x3F {0x4F,0x50}" from earlier

notes are **action ids**: 0x8B→0x10122E00, 0x8C→0x10122DF0, 0x96→0x10122E10 (raw only);

0x4F/0x50 → composite 0x101230B0. Actions 4..7 own raw axis getters at

0x120C10/0x120C40/0x120C70/0x120CA0, each `(byte[[0x104E1D44]+0x252/0x253/0x250/0x251] − 0x80)

× .rdata 0x32A778 (1/128)` — **joystick axis bytes**, so a full pad deflection is ±127/128;

kuluu's old "keyboard analog axis reads (key−0x80)/128, fnA at 0x120C70" line was that pad

getter mislabelled. Action getters dispatch on the configured device: fn **0x122E30** switches

on `byte[[0x104E1D4C]+0x4d]` (mode 4 → tail-calls the mouse normalized-offset accessors

0x125FE0/0x126100 of M21/M23; mode 5 → gate fn 0x25E040 plus a `call 0x124110` context check

with action−0x47 in [0,0xB]).



*Still [I] — physical key identity and magnitude.* Which keys drive actions 6/7 (and 0x8B/0x8C),

and how much one held key contributes to the axis value. Settling read named: the keyboard

branch of fn 0x122E30's mode dispatch plus the binding table behind `byte[[0x104E1D4C]+0x4d]`.

kuluu ships both laws with a digital ±1 axis and no extra tuning factor

(`Cow_Kuluu_ffxi-engine d232f504`); if play-test says the camera is too fast, that read is where

to look — not another constant.



*x87 flag-decoding note.* For `fcomp c; fnstsw ax`, mask **AH 0x41** (EAX bits 8 and 14) is C3|C0

and non-zero ⇔ NOT(st(0) > c); that is the ±π wrap guard at 0x1EBD8, matching an independent

read of the idiom

([stack overflow](https://stackoverflow.com/questions/31759551/assembly-converting-to-if-statement-using-two-fld-fcomp-fnssw-and-test-41h)).

The `test ah,5` / `test ah,0x44` variants at 0x1F086/0x1F0DB are decoded here only from forced

context (a NaN-guarded floor under a divisor); an authoritative bit map for those two masks is

still open — settling read = Intel SDM FCOM/FNSTSW condition codes. Nothing in kuluu depends on

either polarity: the 0.01 floor cannot bind at a real rig radius.



*Intake and law sites, at the byte level (same pass; slots are canonical frame offsets from a mechanical push/pop

walk of `UpdatePlayerFollowingCamera`, because raw `[esp+…]` displacements shift under pending pushes).* Both axis

slots are **cleared then conditionally filled** in the same block — clearing them is what M19 read as "zero-cleared

slots", and they are the slots each law later multiplies:



    1ef30  c7 44 24 1c 00 00 00 00   mov dword [esp+0x1c], 0          ; slot S-0x1d8 (azimuth)

    1ef38  c7 44 24 20 00 00 00 00   mov dword [esp+0x20], 0          ; slot S-0x1d4 (height)

    1ef4e  e8 1d 4a 10 00            call 0x123970                     ; GetAnalogKey(_, 6)

    1ef53  d9 5c 24 24               fstp dword [esp+0x24]             ; -> S-0x1d8 (delta -508: same slot as 1ef30)

    1ef5b  e8 10 4a 10 00            call 0x123970                     ; GetAnalogKey(_, 7)

    1ef60  d9 5c 24 30               fstp dword [esp+0x30]             ; -> S-0x1d4 (delta -516: same slot as 1ef38)

    1f01f  e8 cc 5c ff ff            call 0x14cf0                      ; tick (M29)

    1f024  d8 4c 24 20               fmul dword [esp+0x20]             ; × S-0x1d8 = the action-6 axis (delta -504)

    1f02c  d8 0d ec a3 32 10         fmul dword [0x1032a3ec]           ; × 0.027924445

    1f0ed  e8 be fa ff ff            call 0x1ebb0                      ; rotator, ret 4 (one float arg)

    1f0f2  e8 f9 5b ff ff            call 0x14cf0                      ; tick

    1f0f7  d8 4c 24 24               fmul dword [esp+0x24]             ; × S-0x1d4 = the action-7 axis (delta -504)

    1f0ff  d8 0d e4 a3 32 10         fmul dword [0x1032a3e4]           ; × 0.10666667

    1f147  d8 47 48                  fadd dword [edi+0x48]             ; accumulate into the rig's eye.y

    1f14a  d9 5f 48                  fstp dword [edi+0x48]



*Intake gates.* The two reads are skipped only when **both** `call 0x158AA0` (true if action 0x76 *or* 0x77 is

pressed — `push 0x76/0x77; push 0x3f; call 0x123A70`) and byte `[input+0x22]`, copied to the frame at 0x1EEFA, are

non-zero. A held action **0x8B** negates the azimuth slot and **0x8C** the height slot, through a one-argument

predicate `call 0x193850` (`mov ecx,[0x106626cc] … jmp/jne`, not GetAnalogKey) — so reverse is a *key state* riding on

an analog axis. A third overwrite exists at 0x1EFFD..0x1F003: when `CFsConf6Win` (0x25E050), `vt+0x330`, and spring

mode `[0x10456db0]==0` all agree, the azimuth slot is replaced by `−(fn 0x25E170 − fn 0x25E100)`; both are composite

accessors interrogating actions 6/7 (see §10c), so this is another device's aim value taking over the same slot.



*Law 1 has two regimes, and the normalisation belongs to the **non**-free-run arm.* At 0x1F036: `call dword ptr [eax+0x330]; test al,al; jne 0x1f0a2` (bytes `ff 90 30 03 00 00 / 84 c0 / 75 62`) — the branch jumps **over** the scaling block (0x1F040..0x1F0A0) when the predicate is true, so:

- predicate true — **no** normalisation: azimuth delta = `tick × axis × 0.027924445`, a fixed **1.675 rad/s at full deflection**, tangential speed growing with rig radius;
- predicate false — the `6/max(|eye−lookat|, .rdata 0x329A18 = 0.01)` block runs: constant tangential speed (**≈ 10.05 world-units/s of arc**), ω = 10.05/dist.

`eax` here is `esi`, which is **arg-1 of this function** — the followed actor, type-checked at entry against descriptors 0x10330EBC/0x10330684 (M25) — not the rig in `edi` and not the camera manager. §12's player-object table reads that slot as *IsFreeRun (1 = normal walking, 0 = parallel/strafe)*: retail holds a **fixed angular rate while walking freely** and a **constant arc speed in the parallel-move state**. The sibling spring consumer already recorded it this way (§11 M18: “scales x 6.0/max(dist, 0.01) when not free-run”), which is an independent corroboration of the polarity. Tier: branch, both arms and constants [V]; the predicate's *name* comes from §12's inferred table [local], settling read = one body of that vtable slot.



*Rotator radius is planar.* `0x1EBB0` computes d with `call 0x27680(dx, dz)` (0x1EC1E) on the **XZ** pair and floors it

at `1.0f` (`[0x1032961c]`, 0x1EC35), so eye placement uses planar distance while the caller's normalisation used the

full 3D norm — a real difference at steep pitch, small in magnitude.



### 10b-ii. The free-run predicate behind the distance normalisation (M35) — pass of 2026-10-06 **[V]**

§10b left one read open: which body the `IsFreeRun` slot has, and what it depends on. It is a single actor byte.

```
0xA4670  8a 81 f9 00 00 00   mov al, byte ptr [ecx + 0xf9]   ; IsFreeRun (vt+0x330)
0xA4676  c3                  ret
```

`tables_vtables.csv` / `xref_vtable.py` put this body in slot `+0x330` of the twelve PC-actor vtables (`0x1032D710` family); the two non-skeleton classes in that slot return a constant 1, so only actors carry the flag. At the orbit site (§10b law 1) it is used as a **boolean**, not a number — `test al,al` immediately after the call and `jne 0x1f0a2` skips the whole normalising block:

```
0x1F036  ff 90 30 03 00 00   call dword ptr [eax + 0x330]      ; IsFreeRun of the followed actor
0x1F03C  84 c0               test al, al
0x1F03E  75 62               jne 0x1f0a2                        ; free-run: skip the scaling below
0x1F040 ..0x1F076            dot(eye-lookat) -> sqrt           ; distance
0x1F07B  d8 15 18 9a 32 10   fcom dword ptr [0x10329a18]       ; floor 0.01
0x1F090  d9 05 e8 a3 32 10   fld dword ptr [0x1032a3e8]        ; 6.0
0x1F096  d8 f1               fdiv st(1)                        ; 6.0 / max(dist, 0.01)
0x1F098  d8 4c 24 10         fmul dword ptr [esp + 0x10]       ; delta *= that ratio
```

So the normalisation applies **only when the byte is zero**, and a non-zero byte gives §10b's flat `tick x axis x .rdata 0x32A3EC` at every radius. The default is non-zero: the actor constructor writes `mov byte ptr [esi + 0xf9], 1` @**0xA8A1C**, so retail's ordinary state is free-run and the orbit rate is radius-independent (the shipped case).

The same slot is consulted three more times in the same function before the azimuth delta is handed to rotator `0x1EBB0`, each as a boolean, and it is the gate for the zeroing rules M30 records: at **0x1F0A6** (free-run and `[0x10456D7C] <= 0` → `mov dword ptr [esp + 0x10], 0`, i.e. no azimuth this frame) and at **0x1F109** (the eye-height law's partner gate, 0x1F111/0x1F126). It is also read outside the camera: a store in `0xC5CAE`'s neighbourhood tests it before calling `0x157660`, and the walker-side sites at 0xA5E64/0xA66E9/0xA689D/0xA6C72/0xA6F4D/0xA7365 call the same slot.

**What writes it, and why kuluu cannot see the other arm yet.** `.text` sweep of byte writes to `+0xF9` gives exactly eight sites (plus one getter): constructor `0xA8A1C` (= 1), a setter `0xA4660` (`mov al,[esp+4] / mov [ecx+0xF9],al`, i.e. an external bool), and five joint-curve writers `0x4ABAE`, `0x4BCE3`, `0x4BCF8`, `0x4F591`, `0x4F70C`. Those five are one law: index a 64-entry table (`mov eax,[ebp] / shr eax,0xd / and eax,0x3f` @**0x4BCB6..0x4BCC0**), read its float, scale by `.rdata 0x10329A20` (**= 255.0f**), round through `0x311c2c`, mask `& 0xff`, store — with the special case that a curve value ≤ 0 stores **0** (so zero is authored, not incidental). A **sibling channel at `+0xFA`** is written by the same blocks. Elsewhere the byte is consumed as an integer weight (`mov dl,[ebx+0xF9] / fild` then multiply, e.g. **0x4AE6F**), so it is genuinely 8-bit for those consumers while the camera still tests it as a boolean: any non-zero curve value keeps the actor free-running as far as the orbit law cares **[V]**.

Landed in kuluu as `jw-stack-815 e9c694d3`: `camera_orbit_yaw_rate_rad_per_sec` took over `FOLLOW_ACTOR_FREE_RUN_DEFAULT` (true = retail's constructor value) and normalises only when the flag is cleared; kuluu does not parse the joint-curve channel yet, so that arm stays unreachable exactly as it is in a client without authored motion. The prior test asserted tangential-speed-constancy at default radius (the wrong law for the shipped state) and was replaced rather than left passing **[local]**.
## 10c. The action table behind the aim axes (M31)



**M31 [V].** Closes §16's "GetAnalogKey full decode", kills the phantom *device* column, and names where

the M30 axis values actually come from. TDS 0x6A995428, read 2026-10-04. Every RVA below is a `.text` RVA;

table addresses are VAs.



*Argument semantics.* `GetAnalogKey` **0x123970** opens `push ecx / mov eax,[esp+0xc]` (`51 8b 44 24 0c`) — its

action id is the **second** argument, the one callers pass as `push 6; push 0x3f`. The first argument (always

`0x3F` in every caller seen) is never read on this path: **"device 0x3F" in M1/M2/M15/M16 was a placeholder**, and

those rows' "device 0x3E/0x3F action/button" phrasing should be read as *action id*. What gates an action is the

per-action **device bitmask** word at `.data 0x1036CF60 + action*2`:



    12397e  66 8b 0c 45 60 cf 36 10   mov cx, word [eax*2 + 0x1036cf60]

    123987  85 d1                     test ecx, edx          ; edx = [0x1036e3a0], active-device mask (static 0xffff)

    123989  75 0a                     jne 0x123995           ; unclaimed => return 0.0 ([0x103295d8])



Census of the gate word and of the accessor pair `.data 0x1036D0D8 + action*8` (+0 raw, +4 composite), read out of

`.data` (a second gate column therefore exists; `0xffff` = unconditional):



| action | gate | raw getter | composite |

|---|---|---|---|

| 4 / 5 (move axes) | 0x0008 | 0x120C10 / 0x120C40 | 0x122E20 / 0x123030 |

| **6** / **7** (aim axes) | 0x0010 | 0x120C70 / 0x120CA0 | 0x1232E0 / 0x123450 |

| 8/9 → gate 0x0004, a/b → gate 0x0001 | share raw getters 0x120CD0 / 0x120D20 | | |

| 0x79..0x7C | 0x0004 | same four as 4/5/6/7 | 0x122E20 / 0x123030 / 0x123060 / 0x123100 |

| 0x4F / 0x50 (zoom keys, M17) | 0x0010 | none | both → 0x1230B0 |

| 0x8B / 0x8C / 0x96 | 0x003E | 0x122E00 / 0x122DF0 / 0x122E10 | none |

| 0x16..0x19 (M23's virtual presses) | 0x0002 / 0xffff / 0x0004 / 0x0004 | 0x122350 / 0x1222D0 / 0x122390 (last two share) | none |



When only one accessor exists it is tail-jumped (`ff 64 24 08` / `ff 64 24 fc`, 0x123A07/0x123A18); when both exist

each runs and the **larger magnitude** wins (abs via ×−1.0 `.rdata 0x32A3F0`, `fcompp` 0x123A56, `and eax,0x4100`).



*Hard disable.* If `[[0x104dfd98]] && byte[[0x104dfd98]+0x4194]` then actions **4 and 5** return 0.0 outright

(`cmp eax,4 / cmp eax,5` at 0x1239A9..0x1239B1) — a movement-input suppression flag in the game state object; which

system sets +0x4194 is open (§16).



*Actions 6/7 are logical camera axes 3/4.* The composites end `push 3; jmp/call 0x122E30` (action 6, 0x123342) and

`push 4; call 0x122E30` (action 7, 0x1234B2). Dispatcher **0x122E30** switches on the configured input mode

`byte[[0x104e1d4c]+0x4d]`, and every branch is a mouse/pad source —



- axis 1 → `jmp 0x125FE0`, axis 2 → `jmp 0x126100` when mode == 4 (and `!CFsConf6Win`);

- axis 3 → **0x126190**, axis 4 → **0x126200** when mode == 5 (and `!fn 0x25E040`) — cursor offset from the anchor,

  `(Δpx) / (extent × .rdata 0x32A39C = 0.2)` clamped into ±1 (`1.0f` floor @0x1261D3, −1.0 ceiling @0x1261EA);

- otherwise a jump table `.data 0x1012301c` [axis−1 ∈ 0..3] → stubs that return **stored floats** on the input

  object: axis 1 `fld [ecx+0x94]`, axis 2 `fld [ecx+0x98]`, **axis 3 `fld [ecx+0x8C]`**, axis 4 `fld [ecx+0x90]`;

- the raw getters of actions 6/7 (0x120C70 / 0x120CA0) read joystick axis bytes, `(byte[[0x104e1d44]+0x252/0x253] − 0x80) ×

  .rdata 0x32A778 (1/128)`.

*Those stored axis floats are cursor geometry, not key state.* `fld [ecx+0x8C]`/`[ecx+0x90]` have exactly two writers

each in `.text`: **0x15773E** and **0x2C7E7A** (`fstp dword ptr [ecx+0x8c]`; `+0x90` at 0x157767 / 0x2C7E8C). The

first is a two-int-argument tail (`ret 8`) computing, per axis,



    157736  db 44 24 08             fild  dword [esp+8]         ; cursor x

    15773a  d8 e1                   fsub  st(1)                 ; − 0.5·extent   ([0x10329a08] = 0.5 × word[0x106218b8])

    15773c  d8 f1                   fdiv  st(1)                 ; ÷ 0.5·extent

    15773e  d9 99 8c 00 00 00       fstp  dword [ecx+0x8c]      ; + 0x157751 sets byte [ecx+0x55] = 1



i.e. a normalized **absolute cursor position** across the screen rect, already in ±1 about the centre — which is

retail's other aim shape and precisely what kuluu's `mouse_aim_axis` (cursor vs window half-extent, saturating ±1)

implements; mode 4's accessor instead saturates at **1/21** of the extent (`.rdata 0x32DF9C`) and mode 5's at **1/5**

(`.rdata 0x32A39C`).



*Consequence, stated plainly.* In this build there is **no keyboard source for actions 6/7**: every branch reachable

from `GetAnalogKey` for those two ids resolves to mouse-cursor geometry or joystick axis bytes, and the only digital

actions in the aim path are the reverse partners 0x8B/0x8C (sign flips) and M23's virtual presses 0x16..0x19. So when

kuluu feeds these laws from held keys, it is feeding **retail's law through a kuluu input mapping** — label it that

way in code; ±1 means "full deflection", which retail only reaches at or beyond the saturation distance (≈24 px of a

1080-wide screen in mode 4). Any statement like "retail turns the camera at N rad/s with E held" is unsupported here.



*Still open on this row.* Which input mode `byte[[0x104e1d4c]+0x4d]` a default client carries, and what

`CFsConf6Win` (0x25E050) means beyond gating the mode-4/mode-5 split — settling reads named: the writer of that byte

in `.text` (config load) and one bounded read of 0x25E040/0x25E050's bodies. Also who sets `byte[[0x104dfd98]+0x4194]`

(the actions-4/5 disable above). None of these changes the laws; they decide which source a given player sees.



## 10d. Who owns the camera spring reference (M32) — play-test row P2 (pass of 2026-10-05 against `FFXiMain.unpacked.dll`, TDS 0x6A995428) **[V(me)]**



The question P2 turned on: while locked on, does the chase camera compute its own orbit reference from the

player→target bearing, or consume one the walker wrote? Only the second. Every byte below was read from the

image this pass; it confirms M18's `[local]` shape and closes its ownership half.



**One setter.** `0x1E2F0` is the only code in the image writing `[0x10456DB0]`/`[0x10456DB4]`:



```

0x1e2f0  a0 b06d4510       mov  al, [0x10456db0]      ; the mode byte, read before anything else

0x1e2f7  8a442404         mov  al, [esp+4]            ; arg1 = new mode

0x1e301  8a4c2408         mov  cl, [esp+8]            ; arg2

0x1e309  c605b16d451000   mov  byte [0x10456db1], 0   ; a second mode flag, cleared on one branch only

0x1e310  8b4c240c         mov  ecx, [esp+0xc]         ; arg3 = the reference angle (float)

0x1e314  a2 b06d4510      mov  [0x10456db0], al

0x1e319  890db46d4510     mov  [0x10456db4], ecx

```



**Seven call sites; six of them the walker.** A whole-`.text` `call` sweep (`e8` + rel32 == 0x1E2F0) returns

exactly: `0x1E685`, then `0xA6998`, `0xA69AA`, `0xA6A1A`, `0xA6A46`, `0xA6A5D`, `0xA6C29` — the last six all

inside the steer-branch region M1/M15 own. The 0xA6998 site shows the shape:



```

0xa697e  mov eax, [esp+0xc]      ; that frame's turn term (M18)

...

0xa698e  push eax                ; angle

0xa698f  push ebp                ; mode argument pair

0xa6990  push 1

0xa6998  e85379f7ff    call 0x1e2f0

```



**One reader, in the camera, read-only.** `UpdatePlayerFollowingCamera` (M25's manager method) touches the

global once:



```

0x1f171  84c0              test al, al               ; [0x10456db0] mode must be set…

0x1f173  0f84e1000000      je   0x1f25a               ; …else no orbit this frame

0x1f18e  d905b46d4510      fld  [0x10456db4]          ; the reference angle

0x1f198  d9e0              fchs                       ; negated here, in the camera

…       hypot distance vs .rdata 0x329A18 (0.01), floored at it

0x1f1f8  d905e8a33210      fld  [0x1032a3e8]          ; 6.0

0x1f1fe  d8f1              fdiv st(1)                 ; 6.0 / max(dist, 0.01)

0x1f200  d84c2410          fmul [esp+0x10]            ; × the negated reference = orbit delta

0x1f253  8bcf              mov  ecx, edi               ; camera

0x1f255  e856f9ffff      call 0x1ebb0                  ; polar applier (M30's rotator)

```



Two predicates sit in front of it: `0x25E050` (`mov eax,[0x1066276c]; cmp dword [eax+0x44],2; ret`) — true

only when that context object reports mode 2 — and the manager's virtual `vt+0x330` (M25: IsFreeRun), which

short-circuits the distance recomputation and reuses the held value.



**Consequences.** There is no camera-side lock-on orbit in this build. Nothing in `0x1EE60..0x20B9B` writes

the reference, so an orbit while locked on can only be the walker storing its own heading-change term on

each steering frame — which it does, because target-track feeds that same steer branch. A remake that freezes

the reference at lock time, or that invents a bearing-derived one inside the camera, is wrong twice: it drops

the only producer and adds a competing second one. Landed in kuluu as `8679a836` (walker re-aims while locked;

the spring consumes the walker's own turn); gaps row P2.


## 11. Camera zoom (focal), arrow yaw, spring-back, and the tick (M17–M20)



**M17 [local].** Camera **zoom (focal length)** is integrated in the

camera-manager per-frame update (the same function as the M15 Q/E

integration). *Correction 2026-10-02 (byte re-read in TDS 0x6A995428): the

original M17 read this as camera pitch with clamps 23.0/10.0 and a 15.0

midpoint — those numbers leaked in from the XIClient transcription. 23.0f

does not exist anywhere in `.rdata` of this build (10.0f and 15.0f each

occur once, unrelated to this block).*



```

key 0x4F held:  focal +=  tick * 6.0     ; 0x1F826..0x1F84F, rate @0x32A3E8

                     clamp > 900.0 -> 900.0   ; @0x32A3D8 (imm 0x44610000)

key 0x50 held:  focal -=  tick * 6.0     ; 0x1F876..0x1F8A7

                     clamp < 242.0 -> 242.0   ; @0x32A3D4 (imm 0x43720000)

```



With FOV = 2·atan2(192, focal) [web, E15]: 242 ≈ 76.9° (wide), 350 ≈ 57.5°

(third-person default, E19), 900 ≈ 24.1° (tight).



Both keys held sets byte **`[0x10456D84] = 1`** (0x1F806), and while it stands no zoom arm runs at

all. The path itself (`0x1F76E..0x1F7C2`) eases toward neutral: `ease = (350.0 - focal) x 0.25`

(`.rdata` 0x32A3DC, 0x329CE4), and the two compares bracket *that step* - `-1.0 < ease` (@0x32A3F0)

and `ease < 1.0` (@0x32961C). Only when both hold (`|ease| < 1`) does it store exactly

`focal := 350.0` (imm 0x43AF0000 @0x1F7AE), clear the byte (@0x1F7B6) and store via 0x15290; otherwise

it takes `focal += ease` (0x1F7C7). Observable: both zoom keys pull the focal back toward the 350.0

default over roughly a dozen frames (~0.4 s at the shipped cap), not in one - from the 242 end the

first steps are +27.0, +20.25, +15.2 (the gap shrinks x0.75 per frame; it snaps once the remaining gap

is under 4). Byte evidence and the flag convention that settles which branch is live: **M34, §11d**.

(Two earlier readings of this block are retired: "snap dead / ease sticky", then "ease NaN-only".)



The mouse wheel (0x1F8B6..0x1F93D) is the same path: gated by

`CFsConf6Win::Check()` (0x25E050), delta from 0x25E200; positive delta

integrates +tick·6.0 with the 900.0 clamp, negative −tick·6.0 with the

242.0 clamp; after any change it notifies 0x25E230 and stores via 0x15290.

*Re-read byte-for-byte 2026-10-05 and extended:*



```

0x1F8B6  e8 95 e7 23 00   call 0x1025e050      ; CFsConf6Win::Check()

0x1F8BB  84 c0            test al, al

0x1F8BD  0f 84 a5 00 00 00 je tail 0x1001f968

0x1F8C3  e8 38 e9 23 00   call 0x1025e200      ; delta = accumulated wheel counter

0x1F8CA  7e 3f            jle 0x1001f90b       ; >0 arm

0x1F8CC  e8 ef 59 ff ff   call 0x100152c0      ; focal getter (cam+0x2F4)

0x1F8D5  e8 16 54 ff ff   call 0x10014cf0      ; tick

0x1F8DA  d8 0d e8 a3 32 10 fmul [0x1032a3e8]   ; * 6.0

0x1F8E0  d8 44 24 10      fadd [esp+0x10]      ; focal + tick·6.0

0x1F8E8  d8 1d d8 a3 32 10 fcomp [0x1032a3d8]  ; vs 900.0 -> mov 0x44610000 @0x1F8F7

0x1F8FF  e8 2c e9 23 00   call 0x1025e230      ; clear the counter after applying

; negative arm 0x1F90B: same shape with fsubr and `mov dword [esp+0x10], 0x43720000`

;   (= 242.0) @0x1F93D, clamp compare against [0x1032a3d4]

```



The counter behind the accessor is one global, `g_wheelAccum` **0x1067A298**

— a `.text` census finds exactly 7 touches, all inside this accessor family:

getter **0x25E200** (`a1 98 a2 67 10`: `mov eax,[g_wheelAccum]`), adder

**0x25E210** (`8b 44 24 04 / 8b 0d … / 8d 14 41 / 89 15 …`: acc += **2 × arg**),

clear-to-zero **0x25E230**, and a step-toward-zero helper **0x25E240**

(`if (acc<0) ++acc else if (acc>0) --acc`, reached through the thunk jmp

0x25E0E0). Two producers feed it:



* **0x1DD8** (`callers: 0` — dispatched, not directly called): a signed

  divide-by-120 via magic multiply (`b8 89 88 88 88 / f7 e9 / 03 d1 /

  c1 fa 06`, then the `shr 0x1f`/`add` rounding pair) whose quotient is

  pushed to the adder — i.e. Windows' ±120-per-notch wheel delta becomes

  signed notches, so **positive accumulator = scroll up** and it takes the

  `+tick·6.0` arm (tightens the projection toward 900).

* **0x1245FF**: sign-extends the low WORD of its argument

  (`0f bf d7`, `call 0x1025e210`) before forwarding it, also undispatched.



Notches buy frames, not speed. Each frame an arm fires it moves `tick x 6.0` whatever the

accumulator's magnitude is (M34 §11d), so a three-notch flick covers the same distance per frame as

one notch but for six frames instead of two; and any held zoom key, or an arm reaching its band end,

clears the counter outright (`0x25E230` reached from every key arm).



Focal getter/setter pair on the camera manager (object @ [0x104568FC]):

value getter **0x152C0** reads `+0x2F4` (what the integrator reads), setter

**0x15290** (→ 0x152B0) writes `+0x2F8` (what the integrator stores), and a

second getter **0x152D0** reads `+0x2F8`. The integrator thus reads one

field and writes its sibling in this build.



Open: the physical identity of key slots 0x4F/0x50 (device 0x3F) — the

key-ID→key mapping table has not been extracted (user observation suggests

the U/D arrow keys [O]).



**M18 [local].** Spring-back (the look-at ease that pulls the camera back when

the turn keys come up) is two words: mode byte **`[0x10456DB0]`** and reference

angle **`[0x10456DB4]`**, written by setter **0x1E2F0**(mode, flag, angle),

which also clears vestigial byte 0x10456DB1 (single write site in the binary,

never read). Callers: the camera reset 0x1E685 (mode 0, after zeroing

0x10456D80..0xDA8 at 0x1E643..0x1E67F); the control fn 0xA65CB at 0xA6998

(A/D released: mode 1, wrapped-heading expression), 0xA69AA (A/D held),

0xA6A1A, 0xA6A46/0xA6A5D (gated by the 0x10456D88 counter through getter

0x1E2C0; 0x1E2D0 sets `[0x10456D88] = arg ? 8 : 0`), and 0xA6C29 (mouse mode

via 0x25E050). The consumer (0x1F14D..0x1F255) fires only when the Q/E

predicate slot `[esp+0x1C]` == 0.0 and the mode != 0: it takes

`angle = -[0x10456DB4]`, scales it x 6.0/max(dist, 0.01) when not free-run,

zeroes it while the countdown (M20) > 0, arms the hold-off when 0, and rotates

the look-at around the eye via `0x1EBB0(angle)` (the same routine as the dead

arrow path, M19).



*Correction 2026-10-04 (stream-order re-read from seed 0xA6240): the reference-angle

expression IS decodable — the reported "FPU stack underflow" was an artifact of

decoding started mid-expression at 0xA692A. In stream order two operands are live

at `fmul st(1)` (0xA6934): `V = [esp+0x4c]` (axis-slot float spilled at 0xA64AF)

was loaded on top of `turn`, the E/Q predicate difference computed at 0xA68E6. The

fall-through expression is exactly M15's heading re-assignment —

`heading = S + V·(π/2)·turn`, wrapped to ±π and stored to actor+0xE8 with the

direction triple to +0xE4/+0xEC/+0xF0 (M10/M15). What the engage call 0xA6998

stores as `[0x10456DB4]` is **only the product term `V·(π/2)·turn`**: written to

`[esp+0xC]` at 0xA6936, loaded to eax at 0xA697E and passed arg-3 (mode=1,

flag=ebp=0). A fully held key pair gives |ref| ≈ 1.5708 × 0.992 ≈ **1.558 rad**

(M20 axis scale); the consumer turns that into an orbit rate via ×6/max(dist,0.01).

The `.data` anchor block `0x35BBDC..` (target_track.md §5) is this function's

default look-at source; it is not what arg-3 carries.*



*Addendum 2026-10-05 (device-table sub-question, still open):* no `push 0x3e` / `push 0x3f` immediate

pair marks the button/key slots from outside — every such hit in `.text` is a float constant

(`0x3E800000` = 0.25f, e.g. 0xA62A2/0xA6E3D/0xA7739 inside and beside the control fn), so the device id

and slot numbers of M1/M20 reach their accessors another way (registers or table data) and the

{0x8B, 0x96} button identity + {0x4F, 0x50} key-slot identity remain **[I]**.



**M19 [local].** The left/right arrow yaw is **dead in this build**. The key

slots `[esp+0x1C]`/`[esp+0x20]` are zero-cleared at 0x1EF30/0x1EF38 and then

only multiplied by -1.0 (@0x32A3F0) while keys 0x8B/0x8C are held

(0x1EF67..0x1EFA1): 0 x -1 = -0. The `0x1EBB0(angle)` consumer they feed

(0.027924445 rad @0x32A3EC = 1.6 degrees per tick, scaled x tick x

6.0/max(dist, 0.01)) therefore always rotates by 0. There is no retail

left/right arrow yaw rate in this build to port.



**M20 [local].** The frame tick: **0x14CF0** returns `[0x104568FC]+0x28` clamped below at 1.0.

*Corrected 2026-10-05 against the raw bytes — an earlier version of this section transcribed the flag test as

`25 00 41 00 00 / and eax, 0x4100`, which is not in this code (and does not even fit the addresses it was listed

with). Raw dump of RVA 0x14CF0:*

```

8b 0d fc 68 45 10   mov  ecx, [0x104568fc]      ; camera object pointer

 d9 41 28           fld  dword ptr [ecx + 0x28]

 d8 1d 1c 96 32 10  fcomp dword ptr [0x1032961c]  ; = 1.0f (raw 00 00 80 3f)

 df e0              fnstsw ax

 f6 c4 05           test ah, 5                  ; AH bit0 = C0, bit2 = C2

 7a 07              jp   0x10014d0d             ; -> fld [ecx+0x28]; ret

 d9 05 1c 96 32 10  fld  dword ptr [0x1032961c]   ; 1.0f

c3                 ret

```

Twin getter **0x14D20** carries the identical encoding (raw `…df e0 f6 c4 05 7a 07 d9 05 …`). This *is* the

byte-valued NaN-safe idiom (`test ah,N; jp`) — not the degenerate `and eax,0x4100` form. Decoding it from the

FCOM flag table (C0 = "less", C2/C3 set for equal/unordered) and x86 PF-of-the-masked-byte:

| tick vs 1.0 | C0,C2 | `test ah,5` result | PF | branch |

|---|---|---|---|---|

| greater | 0,0 | 0 | set | `jp` → return raw field |

| equal | 1,1 | 5 (two bits) | set | `jp` → return raw field |

| **less** | 1,0 | 1 (odd) | clear | fall through → **return 1.0f** |

| unordered (NaN) | 1,1 | 5 | set | `jp` → return raw field (NaN passes through) |



So the getter is **`max(tick, 1.0f)`**, NaN excluded: it *does* establish a bound — at least one whole tick is

returned per call — though still no upper bound and no unit. Neither the older `min(field, 1.0)` claim nor this

section's own previous "returns verbatim / the 1.0 arm is dead" conclusion survives the bytes; both are withdrawn.

What

*is* byte-solid (re-read same day) is how the tick is used, the M15 orbit integration:



```

0x1F0F2  e8 f9 5b ff ff   call 0x10014cf0          ; tick

0x1F0F7  d8 4c 24 24      fmul [esp + 0x24]        ; × the steer/axis term (fnA 0x120C70's axis, ≤ 127/128)

0x1F0FF  d8 0d e4 a3 32 10 fmul [0x1032a3e4]       ; × 0.10666667f

0x1F147  d8 47 48         fadd [edi + 0x48]        ; camera azimuth += delta   (ONE add per frame)

0x1F14A  d9 5f 48         fstp [edi + 0x48]

```



i.e. retail's live camera-orbit law is **one accumulation per frame**, `tick × axis × 0.10666667`;

the scalar unit of `tick` closed as an integer count of 1/60 s (**M29, §11c [V]**), so the sum of ticks over

any real second is always ≈60 and every rate in this layer resolves to *coefficient × 60 per second*.

Writer hunt for `[camera+0x28]`, this pass: register-pairing sweep (`mov reg,[0x104568fc]` …

`[…reg+0x28] =`, tool `tools/store_after_global_load.py`) returns no object store — only the two getter

reads and one unrelated word store; intersecting "sweep regions that load the camera global" with

stores to `[any reg + 0x28]` yields exclusively `[esp + 0x28]` stack slots. Combined with the older

negative results (register tracking through reassignment/lea/thiscall setters/thunks), plus two added today —

zero absolute-reference occurrences of `0x10456924` (= g_pCamera+0x28) anywhere in `.text`, and the

`--same-region` intersection over the **94** sweep regions that load `[0x104568FC]`, which again yields only

`[esp + 0x28]` stack slots — those hunts came up empty because they were looking for the wrong shape:

the writer never loads the global, and its sweep-assigned fragment has zero callers (§11c).



### §11c — M29: the frame tick, end to end [V]



Every line below was re-read from raw bytes in TDS **0x6A995428** on 2026-10-03 (`disasm.py` on

`FFXiMain.unpacked.dll`, `xref.py` for the call-site census). This closes the tick-unit question that every

aim-rate calibration in kuluu has been standing on.



**The object.** Allocated and constructed once:

```

0x1569  68 3c 03 00 00     push 0x33c                 ; size 828

0x156e  e8 48 06 31 00     call 0x10311bbb            ; operator new

0x1573  83 c4 04           add esp, 4

```

Ctor **0x10700** stores vptr **0x10329C14** (at 0x10777) and initialises the pacing block:

```

0x10770  b9 00 00 80 3f             mov ecx, 0x3f800000      ; 1.0f

0x1078b  c7 46 2c 00 00 80 bf       mov dword ptr [esi + 0x2c], 0xbf800000   ; -1.0f

0x10792  89 4e 28                   mov dword ptr [esi + 0x28], ecx           ; tick = 1.0f

0x10795  c7 46 30 02 00 00 00       mov dword ptr [esi + 0x30], 2             ; divisor = 2

0x1079c  89 46 34                   mov dword ptr [esi + 0x34], eax           ; frame counter = 0

0x1079f  89 46 38                   mov dword ptr [esi + 0x38], eax           ; whole-frame accumulator = 0

0x107a2  89 46 3c                   mov dword ptr [esi + 0x3c], eax           ; fractional carry = 0

```

The three accessors are thunks over the global: `0x14CF0` tick (getter above, **215** call sites re-counted),

its twin `0x14D20` (3 references), and a frame-counter getter at **0x14D50** (`a1 fc 68 45 10 / 8b 40 34 / c3`

= `[obj+0x34]`).



**The clock sub-object** lives at `[obj+0x1C]` (factory **0x191D0**, ctor **0x19490**, base ctor **0x19210**,

vptr **0x1032A118**). Base ctor leaves vptr 0x1032A08C and sets `[+4]` (fps) and `[+8]` (time scale) both to

`0x3F800000`. Every clock slot reads wall time through the WINMM import thunk `[0x10329400]` (`timeGetTime`, ms):



| slot | body | what it does |

|---|---|---|

| `vt+0x20` | 0x194F0 | advance: `elapsed = now − [+0xC] − [+0x1C]`; `[+0xC] = now`; `[+0x14] += elapsed`; `[+0x18] = [+0x1C] = 0` |

| `vt+0x24` | 0x19550 | fps: `elapsed = now − [+0x1C] − [+0xC]`; **if elapsed == 0 then elapsed = 1** (0x19566); `fps = 1000.0 / elapsed` (`df 6c 24 04 / d8 3d d8 9c 32 10`, `.rdata 0x329CD8` = 1000.0f), stored `[this+4]` |

| `vt+0x28` | 0x19590 | elapsed ms as float |

| `vt+0x30` | 0x19230 | time scale: `fld [ecx+8]` |

| `vt+0x34` | 0x19240 | set scale: `mov eax,[esp+4]; mov [ecx+8],eax; ret 4` |



So the "max(elapsed, 1)" in M18's read is an *integer equality guard on whole milliseconds* (0x19566), not a

floating clamp.



**The writer** is the tail of the frame loop — **0x12A31** onward. The sweep assigns `0x12A31..0x12B66` as its

own function with **zero callers**, and `esi` (the object, which also serves `[esi+0x10]`/`[esi+0x12]` viewport

words and `[esi+0x31C]`, all inside the 828-byte allocation) is already live on entry: that pair of facts is exactly

why every `mov reg,[0x104568fc] … [reg+0x28]=` hunt missed it. Its position in the frame is provable from the

calls that precede the pacing loop — `mov ecx,[0x1045666c]; call 0x10009740` then `call 0x10009720`

(EndScene/Present on CDx, §DancingMad's frame map agrees [web]):

```

0x12b12  8b 4e 1c                   mov ecx, [esi + 0x1c]      ; clock

0x12b1d  ff 52 30                   call dword ptr [edx + 0x30]        ; time scale

0x12b28  ff 50 24                   call dword ptr [eax + 0x24]        ; fps

0x12b2b  d8 4c 24 18                fmul dword ptr [esp + 0x18]        ; × scale

0x12b2f  d9 1d 60 69 45 10          fstp dword ptr [0x10456960]        ; measured fps×scale

0x12b35  d9 05 e8 9c 32 10          fld  dword ptr [0x10329ce8]        ; 60.0f (.rdata 0x329CE8)

0x12b3b  d8 35 60 69 45 10          fdiv dword ptr [0x10456960]        ; raw = 60 / fps   (elapsed in 1/60 s units)

0x12b41  d9 56 2c                   fst  dword ptr [esi + 0x2c]

0x12b44  d9 56 28                   fst  dword ptr [esi + 0x28]        ; tick (pre-round)

0x12b47  db 46 30                   fild dword ptr [esi + 0x30]        ; divisor

0x12b4a  d9 c1                      fld  st(1)

0x12b4c  de d9                      fcompp

0x12b50  25 00 01 00 00             and  eax, 0x100               ; C3 only

0x12b55  74 0f                      je   0x10012b66

0x12b57  6a 01                      push 1

0x12b60  ff d5                      call ebp                       ; ebp = [0x103290f8] Sleep

0x12b62  f3 90                      pause

0x12b64  eb ac                      jmp  0x10012b12                ; re-measure: frame-cap spin

```

The *control flow* of the cap is [V] (Sleep(1) + `pause` + re-measure, gated on the divisor field, with a

"did we sleep yet" byte at `[esp+0x17]/[esp+0x1b]` re-tested at 0x12B66); the polarity of that single masked-C3

test is recorded as bytes only — reading it as "wait until elapsed reaches the divisor quantum" is **[I]**.



Then the smoothing/floor/clamp sequence, all in the same body:

```

0x12bd4  d8 46 3c                   fadd [esi + 0x3c]            ; carry-in

0x12bd9  e8 4e f0 2f 00             call 0x10311c2c              ; ftoi_round

0x12be9  89 46 38                   mov [esi + 0x38], eax        ; whole 60 Hz frames this tick

0x12bec  d8 e9                      fsubr st(1)

0x12bee  d9 5e 3c                   fstp [esi + 0x3c]            ; fractional carry out

0x12bf5  ff 50 20                   call dword ptr [eax + 0x20]  ; clock advance (vt+0x20)

0x12bf8  a3 74 69 45 10             mov [0x10456974], eax        ; ring index (idx+1)&3

0x12c0f  89 14 85 64 69 45 10       mov dword ptr [eax*4 + 0x10456964], edx   ; tick into ring

0x12c16  89 5e 2c                   mov [esi + 0x2c], ebx        ; zero the sum accumulator

         ; 0x12C1E..0x12C2E sums ring 0x10456964..0x10456973 (the index global sits one dword past it)

0x12c33  d8 0d e4 9c 32 10          fmul dword ptr [0x10329ce4]  ; × 0.25 → mean of the 4-entry ring

0x12c3c  e8 eb ef 2f 00             call 0x10311c2c              ; ftoi_round

0x12c45  db 44 24 18                fild dword ptr [esp + 0x18]

0x12c49  d9 56 28                   fst  dword ptr [esi + 0x28]  ; tick = round(mean)

0x12c4c  db 46 30                   fild dword ptr [esi + 0x30]

         ; floor: if tick < divisor then tick = divisor (0x12C5E/0x12C62 store the divisor into [obj+0x28])

0x12c65  d9 46 28                   fld dword ptr [esi + 0x28]

0x12c68  d8 1d e0 9c 32 10          fcomp dword ptr [0x10329ce0] ; 20.0f (.rdata 0x329CE0)

0x12c70  25 00 41 00 00             and eax, 0x4100              ; ZF|AF — NaN-safe "if !(tick <= 20)"

0x12c77  c7 46 28 00 00 a0 41       mov dword ptr [esi + 0x28], 0x41a00000   ; tick = 20.0f

0x12c98  d9 05 e8 9c 32 10          fld dword ptr [0x10329ce8]   ; 60.0f

0x12c9e  d8 76 28                   fdiv dword ptr [esi + 0x28]

0x12ca6  d9 1d 60 69 45 10          fstp dword ptr [0x10456960]  ; effective fps = 60 / tick

0x12cac  8b 46 34                   mov eax, dword ptr [esi + 0x34]

0x12caf  40                         inc eax

0x12cb0  89 46 34                   mov [esi + 0x34], eax      ; frame counter++

0x12cb3  75 03                      jne 0x10012cb8             ; wrapped to 0?

0x12cb5  89 7e 34                   mov [esi + 0x34], edi      ; reset to 1 (edi = 1)

```

Side note that explains an old error of ours: the `and eax,0x4100` idiom *is* real — it is this clamp at

0x12C70. It simply does not live at 0x14CF0, where the getter uses `test ah,5` (see §11 above).



**The unit.** `[obj+0x28]` is an **integer-valued count of 1/60 s**. `[obj+0x30]` is the frame-rate divisor —

cap = 60/divisor fps, default **2 → 30 fps**, which is the well-known FFXI "fps divisor" patch target; 1 would

mean no cap. At the shipped default `tick == 2.0` every frame. The getter's `max(tick, 1.0)` floor is real but

can never bind at divisor 2: **the binding floor is the divisor inside the writer**, so M20's clamp finding

stands and gains its magnitude from here.



**Consequences for the rate laws.** Summed over a real second, `Σ tick ≈ 60` regardless of the cap (that is what

making it elapsed-in-1/60s-units buys). So any per-tick coefficient `c` in this layer is **60·c per second**:

focal zoom `+tick × 6.0` → 360 focal/s, i.e. 350 → 900 in ≈1.5 s; the wheel takes the same arm; Q/E and arrow

aim take `tick × axis × 0.10666667` per frame (see §10 for the unit of `[cam+0x48]`). Countdowns consume tick as

integer frames — verified consumer at 0x1EEFE..0x1EF18:

```

0x1eefe  e8 ed 5d ff ff   call 0x10014cf0            ; tick

0x1ef03  e8 24 2d 2f 00   call 0x10311c2c            ; ftoi_round

0x1ef08  8b 0d 74 6d 45 10 mov ecx, [0x10456d74]     ; hold-off counter (M18 arms this at 10)

0x1ef0e  2b c8            sub ecx, eax

0x1ef10  89 0d 74 6d 45 10 mov [0x10456d74], ecx

0x1ef16  79 0a            jns 0x1001ef22

0x1ef18  c7 05 74 6d 45 10 00 00 00 00 mov dword ptr [0x10456d74], 0   ; clamped at 0

```

so the hold-off `[0x456D74] = 10` is 10 × 1/60 s ≈ 0.17 s and `0x10456D7C = 20.0` is **1/3 s**.



**Method rule (re-earned).** A sweep-assigned fragment with zero callers is not a dead function; walk backwards

over the preceding bytes before believing it, and remember that an object can be live in `esi` across an entire

frame body without any absolute global load inside the fragment you are hunting.



Consequence of the *older* reading (kept for continuity): the `round(tick)` sub-loops (history loop

0x1F667, re-anchor loop 0x1FA4F..0x1FE88) run **zero iterations** at a normal frame rate - they are

stall-recovery machinery, not per-frame work. That conclusion does not depend on which clamp arm is live.



The keyboard analog axis behind M15 is fnA **0x120C70** =

`(int8)(kbdobj+0x250 - 0x80) x 0.0078125` (scale **1/128** @0x32A778;

kbdobj = `[0x104E1D44]`). A fully held key reads 127/128 ≈ **0.992**, so the

effective held-Q/E azimuth rate is 0.10666667 × 0.992 ≈ **0.1058 rad/s

(~6.1°/s)** — half the pre-correction 0.211667 rad/s, which assumed a 1/64

scale. *Correction 2026-10-02: full disasm of fnA (sign-extended byte fild,

then fmul [0x1032A778]); the byte re-read of 0x32A778 = 0.0078125 is final.* The Q/E integration is suppressed while the countdown

`[0x10456D7C]` > 0 (0x1F10F..0x1F12E); the hold-off `[0x10456D74]` (= 10) is

armed when the Q/E/pan delta is exactly 0 (0x1F13F..0x1F141).



Correction to M4: 0x25E170/0x25E100 are the **E-held / Q-held predicates**

(M15 body side), not a speed source - the "speed from 0x25E170/0x25E100" in

§2 is a misattribution.



Camera state block (all sites grep-verified):



| Offset | Meaning (this build) |

|--------|----------------------|

| 0x10456D70 | int; reset/cleared by the re-anchor |

| 0x10456D74 | hold-off int (= 10) |

| 0x10456D78 | azimuth reflection bound (float; also written at 0x20B81/0x2126F/0x218D7) |

| 0x10456D7C | countdown float — **stall-loop-only decrement** (round(tick) gate, §11b); = 20.0 at 0x20769 (entry reachability open [I], §11b); = 8.0 at 0x21147 in **sub_21110** (walker-only callers 0xA5E41/0xA715E, armed under toggle [0x10487F80]); zeroed 0x1FA82 |

| 0x10456D80 | = 60 counter (thunk 0x1E2B0, caller 0x18B4E1) |

| 0x10456D84 | both-zoom-keys byte: while set, no arm runs and the focal eases to 350.0 in quarter-steps; clears when the step falls under 1 (M17 corrected by M34 §11d) |

| 0x10456D88 | 0/8 counter (key 0x51 sets 8 @0x201D7) |

| 0x10456D8C | 0/4 counter |

| 0x10456D90 | global 3f vector used by the re-anchor body |

| 0x10456DA0 | azimuth feedback: cam+0x48 += ([GetPos()]+4 − [0x456DA0]) under vt+0x19C (fn 0x1EE60 at 0x1F289..0x1F2AD, hold-off=10 armed on the compare); whole-file disp32 census: only this read + reset-stores-0 (0x1E661) — stored value constant in this build |

| 0x10456DB0 | spring-back mode byte (M18) |

| 0x10456DB4 | spring-back reference angle (M18) |



**§11b — C4 lifecycle addendum [V] (second full read of the event block).**



*Camera object chain.* `g_pCamera` @0x104568FC is allocated by

`push 0x33c; call new(0x10311BBB); mov ecx,eax; call ctor_10700; mov [g_pCamera],eax`

(0x1569..0x158C). The ctor stores vptr **0x10329C14** at 0x10777 and leaves the

manager slot `[outer+0x50]` = 0 (store site 0x10815, eax=0 path). The manager

object returned by getter 0x15250 is installed only through `sub_151A0`

(this=outer; arg): it calls **0x21C10(arg)**, copies the returned 64-byte

matrix (16 dwords via rep movsd), and stores `[ebx+0x50] = ebp` — byte-exact

at 0x151C7 (`89 6B 50`). Wrapper **sub_15100** (`mov eax,[esp+4];

mov ecx,[g_pCamera]; push eax; call 0x151A0`) has exactly one caller: the

thunk at **0x1E48A..0x1E4A4**, which first writes the controller global

**[0x10456D6C]** and installs that. Teardown `sub_1E5B0` (a handler-array data

pointer at VA 0x1032A380, inside the descriptor block whose class name is

`CYyCamMng2` @0x1032A36C): switch on `arg->[0]` ∈ {2,3}; if

`[[g_pCamera]+0x50] == [D6C]` → clear outer+0x50 via `sub_150C0(0)`; then

`[D6C].vt+0x18(1); [D6C] = 0`. Controller init: `[D6C].vt+0x4(0x1035122c)`

(thunk 0x1E4B0). The manager carries the M12 eye/lookat layout — init method

**sub_1E4F0** (this=manager) copies three floats from template blob

**0x1035122C** into `this+0x44..0x4C` via copy3f 0x26EB0, resets focal to

**350.0** through setter 0x15290 (imm 0x43AF0000 @0x1E504), copies eye into

lookat (`[this+0x50] ← [this+0x44]`), then `lookat.z += 1.0`

(fadd [0x32961C] @0x1E51B) and set3f `(this+0xA8) = (0, -1.0, 0)`; its wrapper

sub_1E590 additionally sets `[this+0xB4] = 3.0`, `[this+0xB8] = 6.0`

(imm 0x40400000/0x40C00000 @0x1E598/0x1E5A2).



*Consumer identity.* fn **0x1EE60** is a `__thiscall` method of the manager:

both call sites (walker 0xA5EAC, 0xA66D3) read exactly

`call sub_15250; mov ecx,eax; call 0x1EE60`. The two virtual calls at 0x1F19E

and 0x1F20E (`ff 92 30 03 00 00` / `ff 90 30 03 00 00`) are therefore on the

**manager**: slot +0x330 = **IsFreeRun** (same slot number as on the player

class, §13 table; matches M18's "scales when not free-run" — predicate true at

0x1F1A6 (`test al; jne 0x1F20A`) skips the ×6/max(dist,.01) scaling). Slot

+0x334 next to arm-20 (`ff 90 34 03 00 00` @0x2077F, ecx=manager) is unnamed;

no file data pointer references any method VA of this class (nonvirtual or

dispatched via an unregistered table). fn 0x1EE60's entry also reads the

**bypass byte `[outer+9]`** (`mov cl,[eax+9]; test; jne` @0x1EE8F) and requires

its argument to be CXiSkeletonActor but not XiModelActor/XiFurniture —

`IsA`-style checks via 0x1002C8F0 with descriptor objects at **0x10330EBC**

(name pointer 'CXiSkeletonActor' @+0) and **0x10330684** ('XiModelActor' @+0).



*Dispatcher gates.* Walker dispatcher fn 0xA5E10 skips everything when app

state `[[0x10456A28]] == 0x40` (lobby/loader). When byte **[0x10487F80]** is

set it replaces the spring path with manager method **sub_21110(actor)**

(call sites 0xA5E41/0xA715E: `push arg; call sub_15250; mov ecx,eax;

call 0x21110`) and returns. sub_21110 (entry verified — prologue

`mov al,[0x10351220]` engine-enable gate) is the **arm-8 site**: `mov

[0x10456D7C], 0x41000000; mov [0x10456D8C], 0` (bytes @0x21147/0x21151), then

recomputes eye/lookat through the round(tick) sub-loop. Its only callers are

those two walker sites.



*Setter census re-verified byte-exact:* every path through sub_1E2F0 reaches

the unconditional store tail at 0x1E310 (`mov [0x10456DB0], al; mov

[0x10456DB4], ecx`) — mode and angle always land. The 0x10456DB1 clear happens

when flag≠0 or (old==0 && new≠0), and DB1 remains write-only (zero readers

file-wide). The D88 latch pair (getter 0x1E2C0, setter 0x1E2D0 with

`[D88] = arg ? 8 : 0`) has exactly ONE caller each in the whole binary — the

walker release variant at 0xA6A50/0xA6A63 (skip-release-when-latched).



*The countdown is stall-recovery machinery, not a gameplay timer.* The only

decrement of `[D7C]` lives inside the round(tick) loop (`test eax; jle 0x1FE90`

at 0xFA44 after `call 0x14CF0; call 0x311C2C`; decrement

`fld [D7C]; fsub [0x32961C]; fst [D7C]` @0x1FA4F..0x1FA5B, zero-store

@0x1FA82) — and by M20 that loop runs **zero iterations at normal frame

rate**. Consequence for ports: the 8/20 values do not tick down during normal

play; spring termination comes from the release path (setter with mode=0),

not countdown expiry. The [D74] hold-off (=10 armed @0x1F2AD under the vt+0x19C

azimuth-feedback compare, and `mov [d74], ebp` @0x1F248 when the consumer delta

is exactly ±0) and the [D8C] 0/4 counter (set 4 @0x1FB19 after re-anchor

commit through the vt+0x1BC push-copy; cleared by arm-8) share the same

stall-loop gating.



*Toggle bytes named from writers:* `[0x10487F80]` is written only by fn

**sub_0A8CC0(byte)** (`mov bl,[esp+8]; mov [0x10487F80],bl`; when arg==0 and

the 0x1047D600 object lookup via 0x81550 is non-null it also does

`[obj+0xB2] &= ~0x04` — the same actor +0xB2 flag as look-at A1) and init

0x11FF4; `[0x10487F81]` (M6's auto-run flag) is written by fn

**sub_0A6070(byte)** (`mov al,[esp+4]; mov [0x10487F81],al`) and init 0x11FFA.



*arm-20 reachability — CLOSED [V] 2026-10-05, and the old question was

malformed.* A boundary walk of raw bytes settles it: in RVA **0x1EE60..0x20B9B**

there is not a single `ret` between 0x1EE5A and **0x20B9B**, and no padding run

(≥ 4 int3 or ≥ 8 nop) anywhere in it, so this is one contiguous branch-only body

whose prologue belongs to `UpdatePlayerFollowingCamera` (RVA 0x1EE60, M11). Branches

from inside that routine enter the body directly — `je/jne` sites at RVA

**0x1EE75, 0x1EE84, 0x1EEA4, 0x1EEB8** all target **0x20B93**, and deeper in,

0x1F613 → 0x201E6 and 0x20001 → 0x201BF. Consequently:



- **`0x20446` is not a function.** The sweep invented it as a "function with no callers"

because the only branch to it — `je` at **0x20438** (bytes `74 0c`) — uses an 8-bit

 displacement, which the usual rel32-only scan misses. Block entry is verified from that

 site.

- **The arm store at 0x20769 has a verified path**: it sits inside this same body, and the

 three `jmp 0x10020773` sites (0x2013A / 0x201BA / 0x201E1) are the convergence tail *after*

 it — they were read as "calls into" the arm and are just jumps to shared epilogue code.

- Whole-image census backs it: zero absolute-pointer occurrences of `0x100204xx` exist

 anywhere in the file (so no vtable/jump-table entry), consistent with "branch-only body,

 never called" rather than "dead code".



**Method note worth keeping:** a reachability conclusion needs rel8 branches (`7x`, `EB`,

`E2/E3`) and a ret/padding boundary walk, not just E8-call + imm32 pointer scans; the two

tools here report only those, which is what produced the phantom "no callers" result.



Also verified in this pass: 0x311C2C = round-to-nearest int(float) (953 call

sites); the GetAnalogKey fnB slots (0x122E20/0x123030/0x1232E0/0x123450) are

pad getters, combined with fnA by the tail 0x1239F6..0x123A54 with sign

handling; the re-anchor loop body (0x1FA34..) gates on the countdown and key

0x91 (0x1F984) with distance gates 3.0/1.0, normalizes, scales x1.5

(0x40466666) through the 0x1815B0 gate, and its eye-move block uses 0x274B0

dot windows -1.0 (@0x32A3D0) / 0.99 (@0x32A3CC), 0x272E0 (divide by 3), x0.01

(@0x329A18) x0.05 (@0x32A3E0), and `fild [0x1035121C]` (int global) before the

eye update 0x1FC97..0x1FCEF; the post-loop reflection rewrites the azimuth as

`cam+0x48 = 2*cam+0x48 - [0x10456D78]` when hold-off == 0, countdown > 0, and

cam+0x48 >= cam+0x54.





### §11d — M34: one zoom rate, two durations **[V]** (pass of 2026-10-05 on `FFXiMain.unpacked.dll`, TDS 0x6A995428)



Re-read from raw bytes with `disasm.py` + `xref.py`. This closes the half of gaps row C1 that

stayed open after `f32832b4`: *why* a held key and a wheel notch felt like the same fixed step.



**One rate — all four arms, byte-identical expression.** The multiplier is the float at `.rdata`

RVA `0x32A3E8` (`40 c0 00 00` = 6.0), fed by the tick getter (M29). Keys first, device `0x3F`:



```

0x1F812  6a ff                  push -1

0x1F814  6a 04                  push 4

0x1F816  6a 4f                  push 0x4f            ; zoom-in key action

0x1F818  6a 3f                  push 0x3f            ; device

0x1F81A  e8 51 42 10 00         call 0x10123a70      ; held?  test al,al / je -> skip arm (0x1F862)

0x1F826  e8 95 5a ff ff         call 0x100152c0      ; focal getter (cam+0x2F4)

0x1F82B  d9 5c 24 10            fstp dword [esp+0x10]

0x1F82F  e8 bc 54 ff ff         call 0x10014cf0      ; tick (max(tick,1.0), §11c)

0x1F834  d8 0d e8 a3 32 10      fmul dword [0x1032a3e8]   ; x 6.0

0x1F83A  d8 44 24 10            fadd dword [esp+0x10]     ; focal += tick*6.0

0x1F842  d8 1d d8 a3 32 10      fcomp dword [0x1032a3d8]  ; vs 900.0 -> store imm 0x44610000 @0x1F855

; zoom-out arm: action 0x50 tested at 0x1F86A (`call 0x123a70`), same chain with `fsubr` (0x1F88A)

;   and the lower clamp fcomp [0x1032a3d4] -> imm 0x43720000 (=242.0) @0x1F89F

```



Nothing edges-detects, nothing converts a hold into notches: every frame the key is down the arm

runs once. Both key arms then land on `call 0x1025e230` — the accumulator **clear** — at `0x1F8A7`

(out arm) and via the join at `0x1F945`, before pushing through focal setter **0x15290**. So a key

frame discards whatever wheel frames were still owed.



**Two durations.** The wheel side is the accumulator already documented in §11 (`g_wheelAccum`

`0x1067A298`; adder `0x25E210` = `acc += 2 x notches`, fed by zDelta/120 at `0x1DD8`; clear

`0x25E230`; drain `0x25E240`). New this pass:



```

; arms live inside the camera update, gated on the camera-control state:

0x1F8B6  e8 95 e7 23 00         call 0x1025e050      ; -> [[0x1066276C]+0x44] == 2 (byte-read:

                                                    ;    mov eax,[0x1066276c]; test eax,eax; je fail;

                                                    ;    cmp dword [eax+0x44],2 — same predicate M32

                                                    ;    recorded gating the spring consumer)

0x1F8C3  e8 38 e9 23 00         call 0x1025e200      ; acc; test eax,eax / jle -> try negative arm

0x1F8D5  e8 16 54 ff ff         call 0x10014cf0      ; tick   (positive arm: focal += tick*6.0)

...    0x1F8FF  e8 2c e9 23 00  call 0x1025e230      ; cleared ONLY on this arm's clamp store @0x1F8F7

0x1F90B  ...                    negative arm: fsubr tick*6.0, clamp 242.0 (@0x1F93D), then clear 0x1F945

; the drain has exactly ONE call site in the whole binary:

0x1295A  e8 81 b7 24 00         call 0x1025e0e0      ; thunk = `jmp 0x1025e240`; sits in frame function

                                                    ;    0x121BD between two 0x25E0B0 calls, unconditional

; drain body (0x25E240): mov eax,[g_wheelAccum]; test; jge/jle pair -> acc+1 if acc<0, acc-1 if acc>0

```



The `jle`/`jge` guards at `0x1F8CA` and `0x1F912` keep the two arms mutually exclusive, so a frame

moves the focal by *one* step of `tick x 6.0` no matter how large the accumulator is. Notches buy

**frames**, not speed: one notch = `acc += 2` = two frames of that identical rate — at the shipped

divisor (tick = 2, §11c) that is 24 focal per notch spread over ~1/15 s; with divisor 1 it is 12.

Summed across a second, every arm gives `6 x 60` = **360 focal/s** (`Σ tick ≈ 60`), so key-hold and

scroll share one perceived speed.



**Both keys: the ease is live (corrects M17's "NaN-only" note).** While `[0x10456D84]` stands,

`ease = (350.0 − focal) x 0.25`, and the two compares bracket *the step*: `-1.0 < ease` then

`ease < 1.0`. Falling through **both** (`|ease| < 1`) stores exactly 350.0 and clears the byte;

otherwise `focal += ease`. From the wide end that is ≈12 frames (~0.4 s) of a 0.75×-shrinking gap.



*Flag convention, established independently in this build so this branch is not read by taste:* MSVC's

`fnstsw ax; test ah,5; jp …` skips the store when the comparison is **not below**. Two unambiguous

consumers pin it: the tick getter `0x14CF0` (`fld [obj+0x28]; fcomp [.rdata 0x32961C = 1.0]; fnstsw ax;

test ah,5; jp +7 → fld [obj+0x28]`; the const path is taken only for `tick < 1`, i.e. it returns

`max(tick, 1.0)` as M29 byte-recorded) and the tick writer's divisor clamp `0x12C57` (`test ah,5; jp …`

over a store of `[obj+0x30]`, which must apply only when `tick < divisor`). Under that convention

both zoom clamps read correctly (upper arm stores 900.0 on the not-below branch) *and* the both-keys

bracket reads as above — three sites, one consistent rule.



**Kuluu landing** (`jw-stack-815 02766871`; gaps C1): `ViewFov::step(focal, tick_frames, ZoomArm::{In,Out})`

is the only place the rate exists (`FOCAL_STEP_PER_TICK = 6.0`, `WHEEL_FRAMES_PER_NOTCH = 2`); one

consumer block in the movement dispatcher spends keys and then owed frames (retail's order,

RVAs `0x1F7DE..0x1F968`); `WheelZoom.frames_owed` mirrors `[0x1067A298]`, accumulated by the wheel

handler system and drained once per frame unconditionally (`wheel_zoom_drain_system`). Deleted from

kuluu: `FOCAL_RATE_PER_SEC` (was applied as focal-per-*second*, 25× too slow — M29 gives ×60) and the

inverted key sign (zoom-in shortened the focal, widening fov, where retail's `0x4F` lengthens toward

900). The mouse side no longer integrates the focal at all.

## 12. Camera manager layout, this build (M12, M13)



**M12 [local].** `GetCameraMng` = **0x15250** = `mov eax,[0x104568FC]; mov

eax,[eax+0x50]; ret` (two-level: global @0x4568FC → manager at +0x50). Sibling

getters: 0x15220 (+0x94), 0x15230 (+0xD4), 0x15260 (+0x114). Manager fields used by

movement:



| Offset | Meaning (this build) | Used by |

|--------|----------------------|---------|

| +0x24 / +0x2C | camera horizontal direction (x, z) | M5 azimuth, M10 facing, M13 |

| +0x44..+0x4C | cached eye position (x, y, z) | 0xA6799 (dir = eye−lookat via 0x27120) |

| +0x50..+0x58 | cached look-at target (x, y, z) | 0xA6796 |



This differs from the 0x6A7297F5-era C2 table (which had eye/lookat at +0x44/+0x50

only); the +0x24/+0x2C direction pair is what movement consumes.



**M13 [local].** The handoff's "camera-distance fn at 0xA7933 (cam+0x24/+0x2C,

fpatan, fsqrt)" is a conflation of two functions in this build:

- 0xA7933 is *inside* AdjustAnalogKeyLength (0xA78D0) — the 1/3 walk-lock block (M3);

- the cam+0x24/+0x2C + fpatan code is 0xA79A0 (M5), the circle-walk rotation.

No separate distance-check function was found; the distance logic that does exist is

the contact radius (M9) and the auto-run magnitude (M6).



## 13. Reference tables



### Vector/matrix helpers (all `ret`, cdecl)



| RVA | shape | meaning |

|-----|-------|---------|

| 0x26E50 | (dst, x, y, z) | set3f |

| 0x26EB0 | (dst, src[, ·]) | copy3f |

| 0x26F20 | (a, b) | a += b (3f) |

| 0x27120 | (out, a, b) | out = a − b |

| 0x272B0 | (v, &s) | v *= s |

| 0x274B0 | (v[, ·]) | normalize / unit-ish (T9: zero/NaN guard ×9999999 @0x32A4CC) |

| 0x27510 | (a, b) | ***a = normalize(\*a)** — 2nd arg unused (T9 corrected: was "a − b") |

| 0x27530 | (a, b) | dot3 → st(0); plain `ret`, callers clean the stack (T9) |

| 0x27550 | (out, a, b) | cross3 |

| 0x27990 | (m) | **no-op** (T9 corrected: was "zero a 4x4") |

| 0x279B0 | (m) | zero m[1]..m[12]; m[0], m[13..15] untouched (T9) |

| 0x279A0 | (m) | **no-op** (T9) |

| 0x272E0 | (src, dst, s) | dst = src·s, s = 3rd stack word by value (T9 corrected: was "divide") |

| 0x27BD0 | (angle, m) | angle = 1st stack word; RotateY into m via 0x27D10 (T9/T12) |

| 0x28200 | (m, v) | v = M·v in place |

| 0x28230 | (dst, src, m) | dst = M·src, translation m+0x30..+0x38; ret 8 |



T-pass corrections (T9) verified by direct disassembly at TDS 0x6A995428; the

extended helper table (0x81550/0x81600, 0x157CF0/0x1598A0, 0xAAEF0, 0xA6070)

is in [target_track.md](target_track.md) §6.



### Key methods on the player object (`this` = esi in 0xA65CB)



| vtable slot | meaning (inferred from use) |

|-------------|-----------------------------|

| +0x1BC | GetPosition → ent+0xD4 (3f) |

| +0x198 | on-ground / has ground normal |

| +0x210 | GetGroundNormal |

| +0x330 | IsFreeRun (1 = normal walking, 0 = parallel/strafe) |

| +0x338 | IsWalkLock (its AdjustAnalogKeyLength clamp is a no-op in this build, M3) |

| +0x340 | event/mount sub-state (facing-path gate) |

| +0x344 | mode set (called with 1 / 0) |



### Constants



| RVA | value | used for |

|-----|-------|----------|

| 0x3295D8 | 0.0 | zero compares |

| 0x32961C | 1.0 | normalize divisor |

| 0x32A22C | 0.001 | auto-run magnitude epsilon |

| 0x32A3E0 | 0.05 | input deadzone (M3) |

| 0x32A42C | 1e-6 | normalize guard (M3) |

| 0x32A84C | 1/3 | walk band scale (M3; immediate 0x3EAAAAAB) |

| 0x32C9A4 | 0.9 | run threshold (M3, data-referenced at 0xA7918) |

| 0x32A3E4 | 0.10666667 | **eye-height** aim axis per tick → cam.eye.y at 6.4 world-units/s (M30; M15 mislabelled it azimuth) |

| 0x32A3EC | 0.027924445 | **azimuth** aim axis per tick, before the radius normalisation (M30) |

| 0x32A3F0 | -1.0 | sign-flip of an aim axis when its reverse action is held (M30); also abs() in GetAnalogKey's getter choice |

| 0x32A3D8 | 900.0 | zoom upper clamp, focal (M17) |

| 0x32A3D4 | 242.0 | zoom lower clamp, focal (M17) |

| 0x32A3DC | 350.0 | both-keys zoom snap target = focal default (M17) |

| 0x329CE4 | 0.25 | both-keys zoom ease factor (M17; dead step) **and** the frame-tick ring mean (M29, at 0x12C33) |

| 0x32A3E8 | 6.0 | zoom rate per tick, focal units (M17) = 360 focal/s (M29) |

| 0x329CD8 | 1000.0 | clock fps numerator `1000.0 / elapsed_ms` (M29, at 0x1957D) |

| 0x329CE8 | 60.0 | reference frame rate: tick raw = 60/fps and effective fps = 60/tick (M29, 0x12B35/0x12C98) |

| 0x329CE0 | 20.0 | tick upper clamp — 1/3 s of wall time (M29, 0x12C68) |

| 0x10456960 | float | measured fps×scale, then overwritten with effective fps = 60/tick (M29) |

| 0x10456964..73 + 0x10456974 | float[4] + int | the tick ring and its index (M29); summed 0x12C1E, ×0.25 |

| 0x32A778 | 1/128 | keyboard analog axis scale (M20) |

| 0x329A18 | 0.01 | floor under the \|eye−lookat\| divisor of the orbit law (M30); also the re-anchor eye-move scale (M20) |

| .data 0x1036CF60 | word per action id | active-device gate of an input action (M30) |

| .data 0x1036D0D8 | fn-ptr pair per action id | input-action accessor table, raw / composite (M30) |

| 0x104E1D44 | object | raw joystick axis bytes at +0x250..+0x253 (M30) |

| 0x104E1D4C | object | configured input device per action (`byte[+0x4d]` mode), dispatched by fn 0x122E30 (M30) || .data 0x1012301C | jmp table [axis-1] | axis-id fallback of the mode dispatch -> stored floats `input+0x8C/0x90/0x94/0x98` (M31) |

| 0x32A39C | 0.2 | aim-offset saturation extent, mode-5 camera accessors: +-1 at 1/5 of the screen rect (M31) |

| 0x32DF9C | 1/21 | same in mode 4: +-1 at 1/21 of the screen rect (M21/M31) |

| 0x329A08 | 0.5 | half-extent normalizing an absolute cursor position into +-1 (fn 0x157720, M31) |

| 0x40466666 | 1.5 | re-anchor loop scale (M20) |

| 0x32B15C | 0.3 | auto-run stop cross-y (M6) |

| 0x32D430 | π/2 | facing clamp (mouse path) |

| 0x32DF40 / 0x32DFA0 | ±0.4 | auto-run stop cross-y window (M6) |

| 0x32DF8C | −0.01 | auto-run stop dot (M6) |

| 0x329D28/0x329D2C/0x329D30 | −2π/2π/π | angle wraps (0xC9330 pose clamp) |



## 14. Findings index



| # | Tier | Statement | Evidence |

|---|------|-----------|----------|

| M1 | [local] | Control fn 0xA65CB; axes GetAnalogKey(0x3F,4/5) via 0x123970 (“corrected by M31”: `0x3F` is an unread placeholder arg; the numbers are action ids); input global 0x57876C | this doc §2 |

| M2 | [local] | Mouse 0x4E1D4C +0xA8/+0xAC; steering 0xA77A0; CFsConf6Win 0x25E050 | §2 |

| M3 | [local] | 0xA78D0 speed law: deadzone 0.05, run ≥ 1/3, field_594; no 0.9 in .text | §3 |

| M4 | [local] | dir = {−key2·speed, 0, key1·speed}; dt via 0x14CF0, scale 0x272B0 | §2 |

| M5 | [local] | Circle-walk: dir = RotateY(fpatan(−cam+0x2C, cam+0x24))·dir in 0xA79A0 | §4 |

| M6 | [local] | Auto-run: 0x487F81 flag, 0x487F64.. vec, stop thresholds 0.4/−0.01/0.3 | §5 |

| M7 | [local] | Gates: 0x84600 < 3, status 0x84390 ∈ {0,1,4,0x1C,0x1F}, 0x487F80 | §6 |

| M8 | [local] | Ground: cross-orthogonalize w/ normal (0x27550); air ×0.25 | §6 |

| M9 | [local] | `*pos += dir` inline 0xA6F31; contact gate 0xA8770, radius² 40.0 | §7 |

| M10 | [local] | Facing −atan2(dir.z,dir.x) or camera-rotated keyvec; actor+0xE8/E4/EC/F0 | §8 |

| M11 | [local] | UpdatePlayerFollowingCamera 0x1EE60, only while keys held | §9 |

| M12 | [local] | Manager: dir +0x24/+0x2C, eye +0x44, lookat +0x50; getter 0x15250 two-level | §11 |

| M13 | [local] | 0xA7933 is M3's 1/3 block; the cam+0x24 fpatan fn is 0xA79A0 (handoff conflation) | §11 |

| M14 | [local] | Live position ent+0xD4/+0xD8/+0xDC; contact fields +0x5A0/+0x5AC/+0x5B0 | §7 |

| M15 | [local] | Q/E turn keys rotate camera (cam+0x48 += tick·axis6·0.10666667, 0x1F0F2..0x1F147) and body (heading re-assign + SetDir 0x1E2F0, 0xA68D2..0xA6998) (“superseded in full by M30 §10b”: the `cam+0x48 += tick*axis6*0.10666667` site is the **eye-height** law driven by action 7; azimuth is action 6 at 0.027924445 through rotator 0x1EBB0, and `[cam+0x48]` is eye.y, not an accumulator)§10 |

| M16 | [local] | Actions 4=W/S, 5=A/D (inverted), 6/7=the camera aim pair; discrete 0xA9=Q, 0xAA=E (“corrected by M31”: these are action ids, there is no device column) | §10 |

| M17 | [local] | Zoom/focal: ±tick·6.0 (0x32A3E8), clamps 900.0/242.0 (0x32A3D8/0x32A3D4); byte 0x10456D84 both-keys path = quarter-step ease to 350.0, exact store only when the step < 1 (M34 §11d); wheel same path; store 0x15290→cam+0x2F8 (old M17 "pitch 23/10/15" was a XIClient leak — §11) | §11 |

| M18 | [local] | Spring-back: mode 0x10456DB0 + angle 0x10456DB4, setter 0x1E2F0, consumer 0x1F14D..0x1F255; stored ref = axis·π/2·turn — the "underflow" claim is retracted (correction §11) | §11 |

| M19 | [local] | L/R arrow yaw dead: zero-cleared slots x -1 = -0 (0x1EF30..0x1EFA1); no retail rate exists | §11 |

| M20 | [local] | ~~Tick = seconds (write site indirect)~~ — the tick is **elapsed in 1/60 s units, integer-valued** (M29 supersedes; the getter and the 1/128 axis census stand); keyboard analog = 127/128 ≈ 0.992 (1/128 scale @0x32A778); state block 0x10456D70..0x10456DB4 | §11 |

| M29 | [V] | The frame tick, end to end: object `[0x104568FC]` (0x33C bytes, ctor 0x10700 — `+0x28` tick 1.0f, `+0x2C` -1.0f, `+0x30` divisor 2, `+0x34/38/3C` 0); clock sub-object `[obj+0x1C]` (vptr 0x1032A118; vt+0x20 advance / +0x24 fps=1000/max-elapsed-int / +0x30 scale) on `timeGetTime`; writer = frame-loop tail 0x12A31 (EndScene/Present then Sleep(1)+pause cap spin, ring mean ×0.25 → round → floor at divisor → clamp 20.0, effective fps = 60/tick); **unit = integer count of 1/60 s**, Σ tick ≈ 60 per second whatever the cap; countdowns consume whole frames (0x1EEFE..0x1EF18) | §11c |

| M30 | [V] | The two aim axes of `UpdatePlayerFollowingCamera`: **action 6 -> azimuth delta handed to rotator 0x1EBB0** (`tick x axis x .rdata 0x32A3EC 0.027924445`, additionally scaled by `6/max(dist,0.01)` ONLY on the non-free-run arm (predicate false = parallel-move; `jne 0x1f0a2` skips it), i.e. a flat **1.675 rad/s** while free-running), **action 7 -> `cam.eye.y += tick x axis x .rdata 0x32A3E4 0.10666667` = 6.4 world-units/s**. `[cam+0x48]` is eye.y, not an azimuth accumulator; reverse partners 0x8B/0x8C are sign flips riding those axes; hold-flag [D7C] zeroes both contributions and countdown [D74] arms to 10 frames | §10b |

| M31 | [V] | The action table behind them: `GetAnalogKey` 0x123970 takes its **action id as arg-2** (arg-1 `0x3F` is never read), gate = `.data 0x1036CF60[action*2]` device bitmask AND `[0x1036E3A0]`, accessors `.data 0x1036D0D8+action*8` (raw/composite, larger magnitude wins, tail-jump when one is null); actions **4/5 hard-return 0** when `byte[[0x104DFD98]+0x4194]`; actions 6/7 = logical camera axes 3/4 -> mode dispatch fn 0x122E30 on `byte[[0x104E1D4C]+0x4d]` -> **mouse-cursor geometry only** (saturation at 1/5 (.rdata 0x32A39C) or 1/21 (.rdata 0x32DF9C) of the screen rect) **or joystick axis bytes x 1/128; no keyboard key can drive them**; stored axes `input+0x8C/+0x90` are normalized absolute cursor positions (writers 0x15773E / 0x2C7E7A, `.rdata 0x329A08` = 0.5) | §10c |

| M21 | [local] | Mouse input object `[0x4E1D4C]`: anchor/cursor fields, ±1 edge-saturated normalized offsets (1/21 scale @0x32DF9C), screen rect `[0x106218B4..BA]`; position-based aim, **no rad/px sensitivity** | §10a |

| M22 | [local] | Steering 0xA77A0: cursor angle quantized to 16 compass sectors (round&0xF), cos/sin+sector out into walker axes | §10a |

| M23 | [local] | Mouse-aim dispatcher seed 0x125360 (actions {0x8B,0x96} — the earlier “device 0x3E buttons” reading is wrong (M31: those are action ids)): θ=fpatan−π/2 state globals 0x1036E5F4/634 → virtual presses 0x16–0x19 with imul rate ramp; feeds the M15/M20 keyboard integration | §10a |

| M24 | [V] | Camera manager lifecycle: outer 0x33C bytes ctor 0x10700 vptr 0x10329C14, slot +0x50 installed only via sub_151A0 (from thunk 0x1E48A; controller global [0x10456D6C]); teardown sub_1E5B0 (§11b) | §11b |

| M25 | [V] | fn 0x1EE60 is a manager method (callers A5EAC/A66D3 `via getter`); its vt+0x330 = IsFreeRun on the manager class; entry reads bypass byte [outer+9] and gates actor type via descriptors 0x10330EBC/0x10330684 | §11b |

| M26 | [V] | Countdown [D7C] decrements ONLY inside the round(tick) stall loop (0xFA44 gate) — never ticks during normal play; arm-8 sub_21110 walker-only under toggle [0x10487F80]; spring terminates via release (mode=0), not expiry | §11b |




| M32 | [V] | The spring reference is walker-owned and camera-read: one setter `0x1E2F0` writes `[0x10456DB0]` mode + `[0x10456DB4]` angle (stores at 0x1E314/0x1E319); its only seven callers are the reset `0x1E685` and six walker steer-branch sites (`0xA6998 A69AA A6A1A A6A46 A6A5D A6C29`); the camera reads it once (`fld/fchs` at `0x1F18E`, gate `[0x10456DB0]`, scaled `6.0/max(dist, .rdata 0x329A18)` into applier `0x1EBB0`) behind predicates `0x25E050` (`[[0x1066276C]+0x44]==2`) and `vt+0x330`. **No camera-side lock-on orbit exists** — while locked the reference is the walker’s own per-frame turn | §10d |
## 15. Kuluu conclusions (for the walker rework)

| M34 | [V] | Zoom has ONE rate and TWO durations, all re-read this pass. Same expression in four arms: `tick x 6.0`, `.rdata` RVA 0x32A3E8 (`40c00000`). Key arm in: device 0x3F action 0x4F via getter 0x123A70 @0x1F81A, `call 0x152C0` focal / `call 0x14CF0` tick / `fmul [0x1032a3e8]` (0x1F834) / `fadd` (0x1F83A), clamp compare vs 900.0 @0x1F842 -> imm store 0x44610000 @0x1F855; key arm out: action 0x50 tested @0x1F86A, `fsubr` @0x1F88A, clamp vs 242.0 -> imm 0x43720000 @0x1F89F — continuous every frame held, no edge or notch conversion; BOTH key arms then reach the accumulator clear `call 0x1025e230` (0x1F8A7 and via join 0x1F945) before setter 0x15290. Wheel arms gated by `call 0x1025e050` = `[[0x1066276C]+0x44]==2`; +acc arm focal step @0x1F8D5..0x1F8E0 with clear only on its clamp store (@0x1F8FF), -acc arm @0x1F91D..0x1F928 (clamp 242 -> clear via 0x1F93D->0x1F945); `jle`@0x1F8CA / `jge`@0x1F912 make the arms exclusive, so exactly one step per frame regardless of magnitude — notches buy frames (acc += 2/notch). Drain 0x25E240 (`jmp` thunk 0x25E0E0) has exactly ONE call site in the binary: `call 0x1025e0e0` @RVA 0x1295A inside frame function 0x121BD, unconditional. Both-keys ease bracket `-1 < ease < 1` around `(350-focal) x 0.25`; flag convention fixed by two unambiguous sites (tick getter 0x14CF0 = max(tick,1); tick-writer divisor clamp 0x12C57). Kuluu `jw-stack-815 02766871`: one law fn + WheelZoom counter; deleted FOCAL_RATE_PER_SEC-as-per-second (25× slow) and the inverted key sign (§11d) |

| M35 | [V] | The distance normalisation of M30's azimuth law is gated by one actor byte: `vt+0x330` IsFreeRun = 0xA4670 (`mov al,[ecx+0xF9]`), tested as a boolean at the orbit site (0x1F036/0x1F03C/0x1F03E `jne 0x1f0a2`) so the `6/max(dist,0.01)` scaling runs only when it is zero; ctor writes 1 (0xA8A1C) -> shipped state is free-run = radius-independent rate; writers are five joint-curve stores of `round(curve x .rdata 0x329A20=255.0) & 0xff` (0x4ABAE/0x4BCE3/0x4BCF8/0x4F591/0x4F70C, curve<=0 stores 0) plus a bool setter 0xA4660; sibling channel at +0xFA; other consumers treat it as an 8-bit weight (fild at 0x4AE6F). kuluu `e9c694d3` | §10b-ii, gaps C6 |


| M37 | [V] | The `+0x4D` dispatch bodies, read in full: jump table at RVA **0x125F2C inside `.text`** (not `.data`; §10a-ii's label was the VA with ImageBase added), guard `cmp eax,6/ja 0x125d11` @0x125502. mode0 0x125512 = tails only; modes 1+2 share body **0x125527** (widget hit-test of the press via `call 0x102347d0`, `call 0x15dce0` false, `[edi+0xC]<[edi+0x10]`; result 3 → store handle/`+0x6C` and enter mode 3 @0x125594; no hit → re-arm left countdown to 25.0 @0x1255AE then a filter-arg-5 query that can enter mode 6 @0x125626); mode3 **0x1256AA** = "action 0x8B (filter arg 4) still held" else drop; mode6 **0x125B19** = UI caret/scroll auto-repeat — floats `+0x7C`/`+0x80`, cursor delta vs `+0x30`, widget word range [0x106218b6]/+ba, ÷3 ladder with clamps 0x125c5a..0x125ca2, and the four pushes ids **0x19/0x18/0x17/0x16** to `call 0x15dd00` (0x125b87/baf/bc7/bef) + identity re-check via 0x160c90. So M23's "mouse aim terminates in virtual arrow presses" is *not* the camera path — those pushes are mode-6 caret repeat behind a widget press; nothing in modes {0,1,2,3,6} reads or writes the aim fields (`+0x8C/+0x90`, `+0x38/+0x3C`), so no kuluu change is owed. Also: 0x126290 = thunk `mov ecx,0x10621838; jmp 0x15edb0`; 0x15dce0 reads global byte `[0x105781cc]+0x48` else falls back to 0x160700, and injector 0x15dd00 applies the same gate @0x15dd03 | this doc §10a-iii, gaps C3 |

| M36 | [V] | Mouse state machine: global .data 0x104E1D4C is one object (new(0xB0) @0x1651B4, ctor 0x124440 writes mode byte +0x4D = 0 and mouse-enable +0x88 = 1); right/left drag chains engage mode 5 / mode 4 on squared displacement > 0x40 from the press anchor OR a 25-tick countdown; handler order right-then-left so left wins ties; +0x54/+0x55 must read clear | this doc §10a-ii |


- Kill auto-recenter-follow: the camera is free; it re-anchors only on input (M11).

- Movement is camera-anchored polar: rotate the raw input by the camera azimuth,

  integrate, then face the travel direction (M5 + M9 + M10). There is no

  character-relative turn in normal walk mode.

- Speed law: deadzone 0.05, walk band 0.05..0.9 at 1/3, run above 0.9 at full

  (M3); diagonals are magnitude-normalized to full speed (M3/M16). Walk = 1/3

  of run — and the walk-lock clamp inside AdjustAnalogKeyLength is dead code in

  this build, so do not expect that path to cap a held run (M3).

- Q/E is a turn key pair, not a strafe: it integrates the camera azimuth (M15)

  and re-assigns the body heading so the body keeps facing travel (M15). A

  kuluu Q/E that orbits the camera and rotates the body is retail-shaped.

  Ported to kuluu (view_native/input.rs) — **two ports are wrong, flagged for

  a user decision**: (1) held Q/E orbit was ported at 0.211667 rad/s (~12.1°/s), then

  re-derived as `tick × axis × 0.10666667` per frame — which with M29's unit is ≈**6.4 per second** at full

  deflection, so the kuluu number can only be right once `[cam+0x48]`'s unit is named (§16); (2) "pitch 6°/s,

  clamp 23/10, both-keys ease to 15" was ported from the pre-correction M17 — the real M17 is **focal-driven

  zoom**: retail integrates ±`tick × 6.0` = **360 focal/s** (M29), clamps 242..900, and both keys ease back to 350 (M34 §11d). It is

  zoom, not pitch, and needs replacement, not tuning. The left/right arrows have no retail rate in this build

  (M19).

- Spring-back exists in retail and is fully byte-decodable (M18, corrected:

  stored ref angle = axis·π/2·turn per facing event; consumer orbits look-at by

  −ref ×6/max(dist,.01) while mode ≠ 0). Documented, not ported.

- Airborne movement is quartered (M8); contact with another player within ≈6.3 yalms

  blocks the step for a 30-tick countdown (M9/M14).



## 16. Open items



- ~~0x123970 (GetAnalogKey) full decode~~ — **closed by M31 (§10c)**: arg-2 is the action id, the gate word `.data 0x1036CF60[action*2]` is a device bitmask and there is no device argument. Actions 8b/9a/b/c, 0x79..0x7C, 0x4F/0x50 and 0x16..0x19 are now in the census table; the remaining un-censused ids are unread (they gate nothing in movement.md).

- ~~Which input mode `byte[[0x104E1D4C]+0x4d]` a default-configured client carries~~ — **closed for

  the byte itself** by M36 (§10a-ii): it is runtime mouse state, ctor-initialised to 0 at RVA 0x124462,

  moved only by the two drag chains and the force-mode-0 paths at RVA 0x12537A / 0x125396. Still open:

  what `CFsConf6Win` (0x25E050) means beyond selecting the mode-4/mode-5 profiles, and fn 0x25E040

  (both M31).
- Who sets `byte[[0x104DFD98]+0x4194]` — the flag that makes actions 4/5 return 0.0 unconditionally (M31). Settling read: writes of `+0x4194` on that object.

- ~~M30 law 1: which arm carries the distance normalisation, and whose slot is the predicate~~ — **both closed**: `jne 0x1f0a2` (bytes `75 62`) jumps over the scaling block, so it runs **only when IsFreeRun is false** (parallel/strafe) and retail holds a flat 1.675 rad/s while free-running; §11 M18 independently records the same polarity for the spring consumer. The slot belongs to arg-1 of 0x1EE60 (the followed actor), not the camera manager. kuluu always normalised (`jw-stack-815 d232f504`). **Closed 2026-10-06 by M35 (§10b-ii)**: the slot body is `mov al, byte ptr [ecx + 0xf9]` (0xA4670), the constructor initialises that byte to 1, and it is authored motion's curve channel that clears it — so kuluu's shipped default must be the *flat* rate; corrected for real in `kuluu jw-stack-815 e9c694d3`, with gaps row C2 (below) recording what stays unread.

- The per-frame tick caller of 0xA65CB (vtable-dispatched; not yet pinned).

- 0x85240/0x85270 candidate-actor iteration semantics (spatial hash?).

- Whether 0x487F74 (constant `ecx` arg to 0x81550/0x814F0) is the follow-actor slot.

- ~~The tick write site for `[0x104568FC]+0x28` (M20): indirect; not findable statically.~~ — **closed 2026-10-03** by M29 (§11c): the writer is the frame-loop tail at 0x12A31, and it keeps the object in `esi`, which is why every global-load hunt missed it.

- ~~Unit of `[cam+0x48]`~~ — **closed by M30 (§10b)**: it is eye.y, not an azimuth accumulator, and the `tick x axis x 0.10666667` accumulation at 0x1F0F2..0x1F14A is the **eye-height** law (action 7), whose unit is world units (6.4/s, distance-independent). The azimuth lives in rotator 0x1EBB0's signed radian delta.

- ~~Spring-back reference-angle expression (M18)~~ — **closed 2026-10-04**: no

  underflow; stream-order decode in M18's correction.

- Physical identity of the zoom keys 0x4F/0x50 (device 0x3F): the key-ID→key mapping table is not yet extracted (user observation: U/D arrows [O]).

- Fn 0x20446 (countdown = 20.0 @0x20769) reachability — open [I], settling read

  named in §11b; arm-8 **sub_21110** fully resolved (§11b).


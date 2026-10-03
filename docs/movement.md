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

Camera side — in the camera-manager per-frame update (the function containing
0x1EF00..0x1F14A, sibling of `UpdatePlayerFollowingCamera`):

```
axis6 = GetAnalogKey(0x3F, 6)              ; 0x1EF4E, the signed turn axis
tick  = call 0x14CF0                        ; frame scale
cam+0x48 += tick * axis6 * 0.10666667      ; 0x1F0F2..0x1F147, rate @0x32A3E4
```

`cam+0x48` is read back in the same camera code (0x1E6E9, 0x1E7DF, 0x1E8AF),
consistent with an azimuth accumulator behind the +0x24/+0x2C direction pair
(M12). A second rotation path exists — `call 0x1EBB0(angle)` at 0x1F0ED,
where 0x1EBB0 re-derives the bearing from eye(+0x44)/look-at(+0x50), adds the
angle (0.027924445 rad/tick = 1.6° per tick, 0x32A3EC) and wraps to [-π, π] —
but in this build its angle source is a slot that is zero-cleared before the
key-hold multiplies (0x1EF30..0x1EFA1), so that path is degenerate (angle 0)
and the cam+0x48 integration is the effective Q/E camera rotation.

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

Both keys held sets byte **`[0x10456D84] = 1`** (0x1F806) and skips the
integration that frame. While the byte is set (0x1F76E..0x1F7C2) the code
computes `delta = (350.0 - focal) x 0.25` (350.0 @0x32A3DC, 0.25 @0x329CE4)
and then — the two convergence compares (vs −1.0 @0x32A3F0 and vs 1.0
@0x32961C, both parity-only NaN guards) fall through to a **hard snap**:
`focal := 350.0` (imm 0x43AF0000 @0x1F7AE), the byte is cleared (0x1F7B6),
and the value is stored via 0x15290. The `focal += delta` ease step
(0x1F7C7) is only reachable when delta is NaN — effectively dead.
Observable behavior: **both zoom keys snap the focal back to the 350.0
default on the next frame.** (The pre-correction reading — "the snap branch
and the byte-clear are dead, ease sticky until camera reset" — had the
dead/live branches reversed.)

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

Since only the accumulator's *sign* reaches the arms (magnitude is dropped
after one step per frame), a multi-notch flick moves focal no faster than
one notch — the doubled unit of the adder matters to 0x25E240's decay, not
to the zoom.

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

**M20 [local].** The frame tick: **0x14CF0** returns the field
`[0x104568FC]+0x28`. *Re-read 2026-10-05, and this narrows what the getter can be used to claim —*
the twin getters `0x14CF0` and `0x14D20` are byte-identical in shape:

```
0x14CF0  a1 fc 68 45 10     mov  ecx, [0x104568fc]        ; camera object
0x14CF6  d9 41 28           fld  dword [ecx + 0x28]
0x14CF9  d8 1d 1c 96 32 10  fcomp dword [0x1032961c]       ; = 1.0f (raw 00 00 80 3f)
0x14CFF  df e0              fnstsw ax
0x14D01  25 00 41 00 00     and  eax, 0x4100               ; keeps bit 8 (C0) + bit 14 (C3)
0x14D04  7a 07              jp   0x10014d0d                ; -> fld [ecx+0x28]; ret
0x14D06  d9 05 1c 96 32 10  fld  dword [0x1032961c]        ; 1.0f
0x14D0C  c3                 ret
```

As encoded, `jp`'s parity comes from the **low byte** of the mask result, and both retained bits
(C0 = bit 8, C3 = bit 14) live in AH — so AL is always 0, PF is always set, and the jump to
`0x14D0D` (`fld [ecx+0x28]; ret`) is unconditional: **the getter returns the field verbatim and the
`fld [1.0]; ret` arm at 0x14D06 is unreachable.** The NaN-aware form this build uses elsewhere is
the byte-valued `test ah, 0x5/0x41; jp` (e.g. 0xC6722, 0xA6E37), where the tested value is a byte and
PF really means C0/C2/C3 parity — that idiom *is* a NaN guard, but it is not what these getters encode.
So M20's earlier `min(field, 1.0)` with `NaN -> 1.0` reading cannot be defended from this code as written,
and **nothing in the getter establishes either an upper/lower bound or a unit for the tick.** What
*is* byte-solid (re-read same day) is how the tick is used, the M15 orbit integration:

```
0x1F0F2  e8 f9 5b ff ff   call 0x10014cf0          ; tick
0x1F0F7  d8 4c 24 24      fmul [esp + 0x24]        ; × the steer/axis term (fnA 0x120C70's axis, ≤ 127/128)
0x1F0FF  d8 0d e4 a3 32 10 fmul [0x1032a3e4]       ; × 0.10666667f
0x1F147  d8 47 48         fadd [edi + 0x48]        ; camera azimuth += delta   (ONE add per frame)
0x1F14A  d9 5f 48         fstp [edi + 0x48]
```

i.e. retail's live camera-orbit law is **one accumulation per frame**, `tick × axis × 0.10666667 rad`;
the scalar unit of `tick` (and therefore the degrees/second) is still **[I]**, and that single unknown is
what every aim-rate calibration in kuluu stands on.
Writer hunt for `[camera+0x28]`, this pass: register-pairing sweep (`mov reg,[0x104568fc]` …
`[…reg+0x28] =`, tool `tools/store_after_global_load.py`) returns no object store — only the two getter
reads and one unrelated word store; intersecting "sweep regions that load the camera global" with
stores to `[any reg + 0x28]` yields exclusively `[esp + 0x28]` stack slots. Combined with the older
negative results (register tracking through reassignment/lea/thiscall setters/thunks), the tick's origin
stays indirect and named: either find a store through a pointer copy (e.g. `lea ecx,[eax+0x28]` + call) or
settle it empirically by measuring degrees-turned per second in game while holding E at default distance.

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
| 0x10456D84 | both-zoom-keys byte: next frame snaps focal to 350.0, then clears (M17) |
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

*arm-20 reachability [I]:* no E8 caller to seed 0x20446 exists and no data
pointer references any VA in the block; apparent calls into it from
0x2013A/0x201BA/0x201E1 all land at **0x20773** — an instruction boundary that
sits *after* the arm store at 0x20769, so the arm-20 store itself has no
verified entry. Settling read: prologue-boundary walk of raw bytes
0x204xx..0x207FF (int3/nop padding scan) to see whether the body containing
0x20769 is a function at all.

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
| 0x32A3E4 | 0.10666667 | Q/E camera azimuth rate per tick (M15) |
| 0x32A3EC | 0.027924445 | 1.6°/tick, degenerate 0x1EBB0 path (M15) |
| 0x32A3F0 | -1.0 | sign flip, degenerate key-hold path (M15) |
| 0x32A3D8 | 900.0 | zoom upper clamp, focal (M17) |
| 0x32A3D4 | 242.0 | zoom lower clamp, focal (M17) |
| 0x32A3DC | 350.0 | both-keys zoom snap target = focal default (M17) |
| 0x329CE4 | 0.25 | both-keys zoom ease factor (M17; dead step) |
| 0x32A3E8 | 6.0 | zoom rate per tick, focal units (M17) |
| 0x32A778 | 1/128 | keyboard analog axis scale (M20) |
| 0x329A18 | 0.01 | re-anchor eye-move scale (M20) |
| 0x40466666 | 1.5 | re-anchor loop scale (M20) |
| 0x32B15C | 0.3 | auto-run stop cross-y (M6) |
| 0x32D430 | π/2 | facing clamp (mouse path) |
| 0x32DF40 / 0x32DFA0 | ±0.4 | auto-run stop cross-y window (M6) |
| 0x32DF8C | −0.01 | auto-run stop dot (M6) |
| 0x329D28/0x329D2C/0x329D30 | −2π/2π/π | angle wraps (0xC9330 pose clamp) |

## 14. Findings index

| # | Tier | Statement | Evidence |
|---|------|-----------|----------|
| M1 | [local] | Control fn 0xA65CB; axes GetAnalogKey(0x3F,4/5) via 0x123970; input global 0x57876C | this doc §2 |
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
| M15 | [local] | Q/E turn keys rotate camera (cam+0x48 += tick·axis6·0.10666667, 0x1F0F2..0x1F147) and body (heading re-assign + SetDir 0x1E2F0, 0xA68D2..0xA6998) | §10 |
| M16 | [local] | Device 0x3F actions: 4=W/S, 5=A/D (inverted), 6/7=Q/E pair; discrete 0xA9=Q, 0xAA=E | §10 |
| M17 | [local] | Zoom/focal: ±tick·6.0 (0x32A3E8), clamps 900.0/242.0 (0x32A3D8/0x32A3D4); both keys snap to 350.0 via byte 0x10456D84; wheel same path; store 0x15290→cam+0x2F8 (old M17 "pitch 23/10/15" was a XIClient leak — §11) | §11 |
| M18 | [local] | Spring-back: mode 0x10456DB0 + angle 0x10456DB4, setter 0x1E2F0, consumer 0x1F14D..0x1F255; stored ref = axis·π/2·turn — the "underflow" claim is retracted (correction §11) | §11 |
| M19 | [local] | L/R arrow yaw dead: zero-cleared slots x -1 = -0 (0x1EF30..0x1EFA1); no retail rate exists | §11 |
| M20 | [local] | Tick = seconds (0x14CF0, write site indirect); keyboard analog = 127/128 ≈ 0.992 (1/128 scale @0x32A778); held Q/E ≈ 0.1058 rad/s; state block 0x10456D70..0x10456DB4 | §11 |
| M21 | [local] | Mouse input object `[0x4E1D4C]`: anchor/cursor fields, ±1 edge-saturated normalized offsets (1/21 scale @0x32DF9C), screen rect `[0x106218B4..BA]`; position-based aim, **no rad/px sensitivity** | §10a |
| M22 | [local] | Steering 0xA77A0: cursor angle quantized to 16 compass sectors (round&0xF), cos/sin+sector out into walker axes | §10a |
| M23 | [local] | Mouse-aim dispatcher seed 0x125360 (device 0x3E buttons {8B,96}): θ=fpatan−π/2 state globals 0x1036E5F4/634 → virtual presses 0x16–0x19 with imul rate ramp; feeds the M15/M20 keyboard integration | §10a |
| M24 | [V] | Camera manager lifecycle: outer 0x33C bytes ctor 0x10700 vptr 0x10329C14, slot +0x50 installed only via sub_151A0 (from thunk 0x1E48A; controller global [0x10456D6C]); teardown sub_1E5B0 (§11b) | §11b |
| M25 | [V] | fn 0x1EE60 is a manager method (callers A5EAC/A66D3 `via getter`); its vt+0x330 = IsFreeRun on the manager class; entry reads bypass byte [outer+9] and gates actor type via descriptors 0x10330EBC/0x10330684 | §11b |
| M26 | [V] | Countdown [D7C] decrements ONLY inside the round(tick) stall loop (0xFA44 gate) — never ticks during normal play; arm-8 sub_21110 walker-only under toggle [0x10487F80]; spring terminates via release (mode=0), not expiry | §11b |

## 15. Kuluu conclusions (for the walker rework)

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
  a user decision**: (1) held Q/E orbit was ported at 0.211667 rad/s
  (~12.1°/s); retail is ≈ 0.1058 rad/s (~6.1°/s, M15/M20) — the port is 2×
  too fast; (2) "pitch 6°/s, clamp 23/10, both-keys ease to 15" was ported
  from the pre-correction M17 — the real M17 is **focal-driven zoom** (±6.0
  focal/s, clamps 900/242, both keys snap to 350, M17); it is zoom, not
  pitch, and needs replacement, not tuning. The left/right arrows have no
  retail rate in this build (M19).
- Spring-back exists in retail and is fully byte-decodable (M18, corrected:
  stored ref angle = axis·π/2·turn per facing event; consumer orbits look-at by
  −ref ×6/max(dist,.01) while mode ≠ 0). Documented, not ported.
- Airborne movement is quartered (M8); contact with another player within ≈6.3 yalms
  blocks the step for a 30-tick countdown (M9/M14).

## 16. Open items

- 0x123970 (GetAnalogKey) full decode — device 0x3F actions 4/5/6/7 are mapped
  (M16); other actions and the 0x26/0x79/0x7C/0x83 devices remain.
- The per-frame tick caller of 0xA65CB (vtable-dispatched; not yet pinned).
- 0x85240/0x85270 candidate-actor iteration semantics (spatial hash?).
- Whether 0x487F74 (constant `ecx` arg to 0x81550/0x814F0) is the follow-actor slot.
- The tick write site for `[0x104568FC]+0x28` (M20): indirect; not findable statically.
- ~~Spring-back reference-angle expression (M18)~~ — **closed 2026-10-04**: no
  underflow; stream-order decode in M18's correction.
- Physical identity of the zoom keys 0x4F/0x50 (device 0x3F): the key-ID→key mapping table is not yet extracted (user observation: U/D arrows [O]).
- Fn 0x20446 (countdown = 20.0 @0x20769) reachability — open [I], settling read
  named in §11b; arm-8 **sub_21110** fully resolved (§11b).

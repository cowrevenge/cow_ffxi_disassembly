# FFXI retail client: look-at — **two separate systems** (W + W2 + W3 passes)

Cut against TDS **0x6A995428** (`client=retail-2026-09`), conventions in [../README.md](../README.md).
Split out of `summary.md` §10 as planned, because the two systems were being conflated and one number was
being ported on that basis.

Tiers: **[V]** byte-verified (pass cited) · **[I]** inference from verified parts · **[O]** user's retail
observation. `[V(me)]` = re-verified by me in this session against `FFXiMain.unpacked.dll` (offset == RVA).

> ## The correction, first, because it changes what kuluu may port
> **The 30° limit is NOT the walker's head limit.** The slot-based dancer look-at (`sqmdModelLookAt`,
> default `pi/6` = 30°, plus 65° presets) is used only by the **menu / preview display model** (singleton
> `[0x10669158]`). The in-world walker never calls it. Any kuluu code that pins a head clamp to 0.5236 rad
> "because the DLL said so" is built on a wrong citation — my own earlier §10/W4 wrote exactly that, and I
> re-verified the pi/6 sites only against the *menu* path.
>
> **Update (W3): the walker's clamp has since been found, and it is not an angle** — it is a per-model authored
> **ellipse** {xlim, ylim} applied by `0x2B140` through the bend at `0x2AC60`, loaded from the skeleton chunk
> (kind `0x29`): head `(0.24, 0.16)` + neck/shoulder `(0.16, 0.06)` for the standard humanoids, with per-model
> variants and zeros meaning "that bone does not bend". See **§E**. The correction above stands: nothing in the
> walker path uses `pi/6`.

---

## A. The dancer model-slot system — menu / preview model only **[V(W)]**

`mdlRegister()` puts every model in a global array: base `[0x1099AED0]`, count `[0x1099AECC]`, capacity
`[0x1099AEC8]`, stride `0xAC`. Slot layout as initialized by 0x26E530:

| off | init | meaning |
|---|---|---|
| +0x00 | 1 | flags; bit `0x200` = look-at enabled (tested at 0x26E6BC) |
| +0x04 | name | model name (copied by mdlRegister 0x26EBD2) |
| +0x84 | 1.0f | weight/scale, consumer unread |
| +0x90 | -1 | look-at bone index (range-checked against numBones) |
| +0x94 | `0x3F060A92` = **pi/6** | yaw limit, radians — 30° default, 65° presets exist |
| +0x98 | vec3 | look-at target position |
| +0xA8 | ptr | the model (mdlRegister 0x26EBE2) |

Apply loop: dancer's per-frame update 0x26E4C2 → for each slot with bit 0x200, call
`sqmdModelLookAt(model=[slot+0xA8], 0, bone=[slot+0x90], target=&slot[0x98], limit=[slot+0x94])` at 0x26E6D3
(the function's only caller). Inside (`0x278E90..0x2790B1`): `yaw = fpatan(delta)` — exactly **one** fpatan, at
**0x278FF9 [V(me)]**, one axis (`sin/cos` builder 0x27ABA0), clamped to ±limit (0x278FF1..0x279036), applied to
that **one bone**'s node matrix. No pitch, no chain distribution, no weights.

The float `pi/6` bits (`3F 0A 06 3F`) appear in `.text` at two sites only — 0xD5547 and **0x26E567** (the slot
init) **[V(me)]** — consistent with "one writer, hard default". `0x27C2CC` looked like another consumer and is a
dancer **debug dump** (double→float conversions feeding a printf) — false positive, do not chase it **[V(W)]**.

Who uses it: the menu/preview display model singleton `[0x10669158]` **[V(W)]**. Not the walker.

---

## B. The in-world walker look-at — actor method 0xD5B10 **[V(W2)]**, re-verified [V(me)]

Per-actor update; the call we can actually locate is an `E8` at **0xCCA03** into 0xD5B10 **[V(me)]**.
(The pass cited "the actor update 0xCC967" — in this build no call to 0xD5B10 sits there; treat 0xCCA03 as the site.)

```
0xD5B18  lea ecx, [esi+0x674]        ; the per-actor attachment/child list
0xD5B1E  call 0x2B5A0                ; list accessor -> object; null => bail (0xD5EE5)
0xD5B2F  call 0x84670                ; early-out predicate; true => mode = -1.0f release
0xD5B38  mov dword [esi+0x854], 0xBF800000    ; *** the release value, byte-exact ***
```

**Target.** Local player → `GetLockedTarget(g_pInputMng)` (`0x157CF0`, call at 0xD5B80). NPCs/mobs → own target
(`0x845E0`, call at 0xD5B89) **[V(me)]**.

**Hold precedence and the suppression bit.** Two bits of an actor flag dword gate the frame before target
selection even runs:

```
0xd5b49  mov   ecx, [esi+0x840]
0xd5b51  and   ecx, 1                     ; bit 0 = hold
0xd5b57  jne   0xd5b6c                    ; not held -> target selection at 0xd5b6c
0xd5b59  test  al, 2                       ; held: bit 1 = LockLookAt suppression (§B below)
0xd5b5b  jne   0xd5b6c                     ;       set -> fall through to selection despite the hold
0xd5b5d  mov   dword [esi+0x854], 0x3f800000    ; +1.0 = hold; jmp tail 0xd5cae — selection and
                                              ; both gate chains are skipped entirely while held
...
0xd5b6c  call  dword [vtable+0x304]        ; a "can-look-at?" virtual; al == 0 -> skip GetLockedTarget
0xd5b7a  call  0x157cf0                    ;   local player: GetLockedTarget(g_pInputMng)
0xd5b87  call  0x845e0                     ;   otherwise: own target
0xd5b90  test  byte [esi+0x840], 2         ; suppression bit -> xor edi,edi (treat as *no target*)
0xd5ba8  je    tail                        ; null target -> mode = -1.0 release via tail
0xd5bae  cmp   edi, esi; je tail           ; self-target guard: looking at yourself releases too [V(me)]
```

So a held aim (`+1.0`) ignores the gates until suppression (bit 1) pre-empts it, and the method never
selects through its own vtable probe without the caller's blessing **[V(me): 0xD5B49..0xD5BB0, gates.out]**.

**Gates — re-read to the byte before porting them (2026-10-03).** §B originally paraphrased this chain as
"target status ∈ {0,1,2,6,7,8}; own status ∈ {0, 0x2F, 0x30}, or mount predicates". The counts are right
(`0x84400` ×6 at 0xD5BB8/BC3/BD9/BDB/BE7/BF3; `0x84390` ×7 at 0xD5C03/C0E/C1A/C2D/C39/C4C/C51 — the same
method, each call testing one value) but say nothing about what those predicates *read*, and kuluu's port
needed more than that **[V(me), gates.out]**:

* `0x84400` = **target-type** predicate: returns sign-extended `byte[inner+0xEE]`, where `inner` is the
  actor's inner data `[actor_this+0x70]`; null inner falls back to a global at `0x1047D610`
  (`movsx eax, byte ptr [eax+0xee]` @ 0x84407). The six sequential equality tests accept
  **{0, 1, 2, 6, 7, 8}**; any other value takes the release path — mode `−1.0` is written at 0xD5B9E for
  every frame that ends without a live target (suppressed or gated), then jumps to the tail.
  Provenance census in §B-ter (2026-10-05).
* `0x84390` = **own-status** predicate: returns sign-extended `byte[inner+0x170]` (@ 0x84397), same global
  fallback (`0x1047D60C`). That inner byte *is the wire ANIMATIONTYPE* — XIClient keeps it as the actor's
  GameStatus, and vendor `vendor/server/data/enums/animation.yaml` names every value in the chain below.
  This is what lets kuluu gate on data it already snapshots instead of inventing a status enum **[V(me)]**.
* The three "mount predicates" are thin wrappers that tail-jump (`0x84337/0x84357/0x84377`), not value tests:
  `0x84330 → jmp 0x95790` = the `/sitchair` block — equality chain over **0x3F..0x53** (@ 0x957A1..0x95808;
  the enum names `sitchair_0..10` only as far as 73, bytes 74–83 are unnamed); `0x84350 → jmp 0x95680` =
  **== 5** (chocobo, @ 0x95691); `0x84370 → jmp 0x956a0` = **== 0x55** — decimal 85, vendor's `MOUNT`
  (@ 0x956B1). Each helper takes a candidate byte and falls back to reading `[ecx+0x170]` itself when handed
  the sentinel `0xff` — every call site in this chain passes the real own-status byte, so that fallback is
  unreachable from here **[V(me)]**.
* Net allowed own-status set: **{none(0), chocobo(5), sit(47 = 0x2F), ranged(48 = 0x30), 63..=83
  (0x3F..0x53 /sitchair block), mount(85 = 0x55)}**. Any other byte — attack, death, event, the fishing
  run — releases.
* A gate miss does **not** abort the method: every gate-fail path jumps to the tail at `0xD5CAE`, which skips
  the look-point *update* but still runs the frame's weight ramp and bone transforms (release mode). Only the
`0x84670` early-out (`bit 5 of word [inner+0x120]` @ 0x84677) returns without running that tail **[V(me)]**.

**Look point.** The target's **attach point 3**: virtual `[target_vt + 0x1C4](3)`; if `target+0xB2 != 0`, subtract
1.2 from Y — constant `1.2f` at `.rdata 0x32A404`, referenced in the method at **0xD5C86 [V(me)]**. Stored into the
actor at **+0x848 / +0x84C / +0x850** (stores seen at 0xD5C98 / 0xD5C92 / 0xD5C9E **[V(me)]**).

**Mode float `actor+0x854`:** `0.0` aim · `-1.0` release · `+1.0` hold, where hold is bit 0 of `actor+0x840`.
(6 writes to +0x854 in the method; the -1.0 immediate is byte-exact at 0xD5B38 **[V(me)]**.)

**Release conditions — and they are not angular.** In actor-local space (forward = **+X**), release when: no
target · the LockLookAt stage bit is set · gates fail · horizontal distance ≤ **0.3** (`0.3f` at `.rdata 0x32B15C`,
used at **0xD5DED**) · forward component ≤ **-0.5** (`-0.5f` at `.rdata 0x32A3D0`, used at **0xD5DBF**) **[V(me)]**.

So what a player sees as "the head leaves you" is *not* an angle limit: it is the target crossing **half a unit
behind your shoulder line**, and ≤0.3 units horizontally (basically under/behind you).

**Slew = blend weight, ±0.04/frame.** `model+0xBC` ramps toward 1.0 while aiming and back to 0 on release; the
constant `0.04f` is `.rdata 0x32A85C`, referenced at **0xD5D6C**, with 9 accesses to `[ebx+0xBC]` (e.g. `fadd` at
0xD5DFC) **[V(me)]**. At 60 fps that's ~**25 frames each way**, which is exactly why retail reads as "snaps" —
it isn't a snap, it's a fast ramp. On reaching 0 the look point `model+0xB0..B8` resets to straight-ahead defaults
at `.rdata 0x35F5FC` (that block reads as a vec3 `(20.0f, 0, 0)` followed by `1.0f`) rotated by the actor's yaw
**[V(W2)]**, with the forward magnitude noted **[I]** — consistent with "look at something far ahead = straight".
Alternate rate: `[obj_vt + 0x144]() × 0.01 × 0.04` when `0x87060()` is true (frame-scaled) **[V(W2)]**.

**LockLookAt stage (scheduler `0x89`) suppresses tracking — bit placement and watchdog settled on bytes
(2026-10-03).** The suppression is **bit 1 of the actor flag dword `[actor+0x840]`**:
set by the spawned task's constructor (`or ecx, 2` @ RVA 0x5F4A8 ← handler for stage `0x89` at RVA 0x5B14C),
cleared when that task tears down (`and ecx, 0xFFFFFFFD` @ RVA 0x5F68B), and read by the look-at method twice
— `test al, 2` at 0xD5B59 (hold precedence) and 0xD5B96 (⇒ *no target* ⇒ release). While it is set the actor
behaves as if it has no look-at target **[V(me), ctor.out / watchdog.out / gates.out]**.

The stage's task holds **remaining duration** (`+0x74`: `fild` of the operand word — direct, see below — stored
at 0x5F47A; each tick `fsubr` clock dt read from global `0x1047BFA8` at `+0xEB0`, RVA 0x5F620) and **anchor
snapshots of the actor's own X/Z** taken in its constructor (`[edx+0x1BC]` position accessor writes →
`[task+0x78]` @ 0x5F4C6, `[task+0x7C]` from `+8` @ 0x5F4DB). Each update compares the anchor **componentwise
against the actor's current horizontal position** (subtract @ 0x5F5AA / 0x5F60F vs `.rdata 1.0f`) — there is no
vertical axis in it. So the watchdog ends the stage when the actor stands more than **1.0 yalm from where the
stage fired**, not on accumulated travel **[V(me)]**.

Per-task lifecycle, and why kuluu tracks one task per firing rather than a merged window: set/clear is done by
each individual task (`or 2` in ctor @ 0x5F4A8, `and ~2` at teardown @ 0x5F68B) — two overlapping `0x89` stages
can outlive each other's bit, so a released stage must not re-arm while its interval still covers **[V(me)]**.

That is the behavioural counterpart of the DAT records counted in [drivetask.md](drivetask.md)
§9.1/§10.1: 504 shipped `0x89` records, duration-only operands ⇒ actions/emotes freeze the head for N ticks or
until you step ~1 yalm off the anchor, then it resumes.

**On the duration's scale — earlier note corrected.** A prior pass claimed retail converts the authored word
to clock units via `[ctx+0x9c]`. These bytes show no such multiply: stage handler 0x5B14C pushes an operand,
ctor 0x5F469 does `fild dword [esp+0x18]` and stores it straight to remaining-time at 0x5F47A — the word
becomes float ticks **unscaled**. kuluu treating scale as 1 (routine-clock frames) is exactly what these bytes
show **[V(me), handlers.out / ctor.out]**; where `[ctx+0x9c]` came from was never byte-verified, and nothing
cited to it here stands.

### B-port — landed in kuluu as row 4 (commit `a0583409`, branch `jw-stack-815`) **[V(me)]**

What the port took from this section, where it lives:

* gate sets (§B "Gates") → module `kuluu-render/src/look_at_gates.rs`: `look_at_allowed` (the own-status set;
  gates applied in the pose pass in `ffxi_actor_render.rs`, before aiming) and its bend-record companion from
  §E.6's equality chain;
* suppression + watchdog → `StageKind::LockLookAt` (`opcode 0x89`) in `ffxi-dat/src/scheduler.rs` (operand =
  signed word at `record+6`, unscaled), intervals via `lock_look_at_intervals_at/now` in
  `kuluu-render/src/scheduler_runtime.rs`, task state machine (per-stage anchor snapshots, horizontal-only,
  `LOCK_WATCHDOG_DISTANCE_YALMS = 1.0`) in `look_at_gates.rs`;
* own-status source → the wire animation byte (`SnapshotActorState.animation`; `RANGED: u8 = 48` added to
  `ffxi-proto/src/decode/animation.rs`, which was missing it — vendor-derived).

Visible consequence, flagged when it landed: actors mid-attack (LSB sets `animation = Attack` at engage),
dead, event and fishing no longer track their target. Byte-faithful; if retail observation disagrees, this row
reopens first.

Still open on this row (not implemented — no wire equivalent located yet): the **target-type sub-gate**
`byte[inner+0xEE] ∈ {0,1,2,6,7,8}`. `EntityLook::Door/Transport` in kuluu's snapshot is a candidate
correspondence but that mapping is unlocated; until it is, don't implement this sub-gate on a guess.
Separately unmodelled: the "hold" mode semantics (bit 0 of `[actor+0x840]`, §B hold precedence) and retail's
`[target+0xB2]` look-point variant.

**The "bend" is found (W3).** The consumer of `model+0xB0..B8` + weight, the ellipse clamp it applies, the shoulder
share and the authored limits that feed both are now byte-verified in **§E below**; the earlier "angular clamp
unlocated" framing in this section and in §C/§D is superseded by §E.

---

## B-ter. The target-type byte `inner+0xEE` — gate chain re-read and writer census (pass of 2026-10-05, for gap row A6) **[V(me)]**

The six-call predicate run at 0xD5BB8..0xD5BFB is re-verified verbatim: `ecx = edi` (**the target**) each
time; every equality hit (`0`, `1`, `2`, `6`, `7`) jumps to **0xD5C01** and only the sixth test falls
through — `cmp eax,8 / jne 0x100d5cae` @ **0xD5BFB** sends any non-member to the release tail. So:
accept `{0,1,2,6,7,8}`, reject everything else **[V(me)]**. The own-status chain at
0xD5C03..0xD5C5C matches §B as written (equals 0 / 0x2F → continue; `0x84330` `/sitchair`, `0x84350`
==5, `0x84370` ==0x55 helpers; final miss jumps to the tail via `je 0xd5cae` @ **0xD5C5B** — polarity
as recorded) **[V(me)]**.

Writers of the byte (`tools/mem_operand_census.py --disp 0xEE`: 83 hits, 24 direct writes):
every constant-stamping handler resolves the record through the **global entity table** first —
`mov eax, dword ptr [idx*4 + 0x10480AF0]` (DancingMad §14 "Global actor table" **[web]**, confirmed by
our reads) — taking `idx` from a word in its message buffer (`[esi+2]`, `[esi+8]`), then stores the
type byte directly **[V(me)]**:

| value | store sites |
|---|---|
| 0 | **0x95F67**, **0x95FC0**, **0x99C33**, **0x9C94F** (gated on `[+0x120] bit 5` + `word[+0x210]`) |
| 1 | 0x9C96F |
| 2 | const @ **0x9C9B7**, **0xAB23F**; and `mov byte ptr [esi + 0xee], 2` @ **0x95F94** in an update function |
| 3 | **0x9CB72**, **0xC3F16** — that one immediately after the table slot itself is filled (`mov [esi*4+0x10480af0], eax`), a spawn-time stamp — and **0x1D2CFD** |
| 4 / 5 | **0x9CC11** (via `[edx+0xee]`) and **0x9CC7E** |
| 6 | **0x9CD47** (record from `word[esi+8]`; packet words at +0x32 also read) |
| 7 | **0x9CDB1** and **0xB14AC** (the latter: record from `word[esi+2]`; followed by `or byte[eax+0xf4],1` / `cmp word[eax+0xfc]`) |
| 8 | **0x9CE5D** (followed by `[+0xf6]=2` writes in sibling arms) |

Variable stores (`mov [.. + 0xee], bl/cl/al` — value copied from the message/actor, not a constant):
0x8A3E7, 0x95005, 0x9B02B, 0x9B162, 0xAB3D6, **0x1F844F** **[V(me) for each: raw bytes re-read]**.

The observed constant range {0..8} matches XIClient's `ActorType` enum (`ZERO(0)…EIGHT(8)`, names
`DOOR=3, LIFT=4, MODEL=5`) **[web]** — and §B's accepted set {0,1,2,6,7,8} excludes exactly
type-3/4/5. So the target-type gate reads: *doors, lifts and models are never look-at targets*.
Which message opcode reaches each handler is **[I]**; settling read = attribute each store site to its
handler entry (tables_functions.csv seeds) and trace those through the packet dispatcher.

## B-quater. The producer of `+0xEE`: the packet-`0x0E` SubKind dispatch, re-read in this build **[V(me)]**

Pass of 2026-10-06 against `C:/tmp/ffximain_work/FFXiMain.unpacked.dll` (TDS `0x6A995428`). §B-ter censused the writers; this section reads one of them end to end, because it is the handler that *defines* what the Type byte means — it puts a producer under the accept set in §B.

**Which image owns which RVA (read this first).** `docs/event_vm.md` §M and `docs/event_evidence.md` §§M.2/M.5/M.6 record the same dispatch at **0x9C917 / jump table 0x9CE98**, stores at `0x9C9C7/0x9CB82/0x9CC21/0x9CC8E/0x9CD57/0x9CDC1/0x9CE6D`. Those belong to the earlier target image (`FFXiMain.dll`, 2,901,584 bytes, TDS `0x6A7297F5`) and agree with §event_vm's own note that this cluster sits about −0x10 in the current install. They do **not** decode here: cells read from `0x9CE98` in this image return `0x90909090` padding. For TDS `0x6A995428` the authoritative values are the ones below (**dispatch 0x9C916, table base 0x9CE88**).

The dispatch (raw bytes then decode):

```
0x9C907  8a 46 30                 mov al, byte ptr [esi + 0x30]   ; look.size
0x9C90A  83 e0 07                 and eax, 7                      ; SubKind = low 3 bits
0x9C90D  83 f8 07                 cmp eax, 7
0x9C910  0f 87 66 05 00 00        ja 0x9ce7c                      ; -> an epilogue; unreachable (mask <= 7)
0x9C916  ff 24 85 88 ce 09 10     jmp dword ptr [eax*4 + 0x1009ce88]
```

Jump table `.rva 0x9CE88` (little-endian VAs, read directly from this image) and the Type store each arm performs (`mov byte ptr [record + 0xee], imm8`; `record` comes from `mov eax, dword ptr [idx*4 + 0x10480af0]` with `idx = word[esi+8]`, i.e. the global entity table §B-ter already names):

| SubKind (`look.size & 7`) | LSB MODELTYPE | arm RVA (via table cell) | Type stamped | store site + raw bytes |
|---|---|---|---|---|
| 0 | STANDARD (NPC/mob) | cell `0x9CE88` -> 0x9C99C | **2** | 0x9C9B7 `c6 80 ee 00 00 00 02` |
| 1 | EQUIPPED (PC-look) | cell `0x9CE8C` -> 0x9C91D | **1**, or **0** on the flag branch below | 0x9C96F `c6 80 ee 00 00 00 01`; alternate 0 @0x9C94F `c6 80 ee 00 00 00 00` |
| 2 | DOOR | cell `0x9CE90` -> 0x9CB37 | **3** | 0x9CB72 `c6 80 ee 00 00 00 03` |
| 3 | ELEVATOR | cell `0x9CE94` -> 0x9CBD6 | **4** | 0x9CC11 `c6 82 ee 00 00 00 04` (via `[edx+0xee]`) |
| 4 | SHIP | cell `0x9CE98` -> 0x9CC43 | **5** | 0x9CC7E `c6 81 ee 00 00 00 05` (via `[ecx+0xee]`) |
| 5 | UNK_5 | cell `0x9CE9C` -> 0x9CD38 | **6** | 0x9CD47 `c6 80 ee 00 00 00 06` |
| 6 | AUTOMATON | cell `0x9CEA0` -> 0x9CDA2 | **7** | 0x9CDB1 `c6 81 ee 00 00 00 07` (via `[ecx+0xee]`) |
| 7 | CHOCOBO | cell `0x9CEA4` -> 0x9CE50 | **8** | 0x9CE5D `c6 80 ee 00 00 00 08` |

Two structural facts that only a byte read gives you:

- **There is no default arm.** Because the index is masked first, all eight cells are live and the `ja` at 0x9C910 lands on an epilogue (`5f 5e 5d b0 01 5b 83 c4 40 c3` @**0x9CE7C**, `ret`, return value 1). So no `look.size` is ever *unclassified*: it is classified mod 8, which means an out-of-enum size silently aliases onto another kind (size 9 -> SubKind 1 -> Type 1). A consumer that does not mask the same way diverges from retail on such a record.
- **SubKind 1 has two stores**, selected by three conditions: `[ent+0x12C]` bit 30 (`c1 ea 1e / f6 c2 01`) then, in both branches, `[ent+0x120]` bit 5 must be clear (`f6 c1 01`) and `cmp word ptr [eax + 0x210], bp` must match. All hold -> Type **0** @0x9C94F; otherwise Type **1** @0x9C96F, reached through a second copy of the same two tests at 0x9C958..0x9C96F. Both values are in the accepted set, so this branch cannot change whether an entity is aimable — which is why kuluu may collapse it to 1 without changing behaviour. **Still `[I]`: what bit 30 of `ent+0x12C` means** (settling read: xref writers of that dword and match them against the packet fields §event_vm maps for opcode 0x0E). Recorded as an open sub-question, deliberately not chased; it gates nothing.

The consumer, on record so both halves agree: **0x84400** = `8b 41 70` (`mov eax,[ecx+0x70]`) / `85 c0 / 74 08` (null -> global fallback) / `0f be 80 ee 00 00 00` (`movsx eax, byte ptr [eax + 0xee]`) / `c3`, with fallback `a1 10 d6 47 10` = global `[0x1047D610]`. Note the indirection: §B-ter's "`inner+0xEE`" is *not* a field of the actor but one level out, at **actor+0x70 -> record+0xEE**. That plus `mov byte ptr` writes is exactly why a dword-width displacement census returns nothing for it (§B-ter).

The accept test re-read once more so the two reads meet in the middle: 0xD5BB8..0xD5BFB calls `0x84400` six times with `ecx = edi` (the target) and compares against 0/1/2/6/7 and finally **cmp 8 / jne 0xd5cae** @**0xD5BF8/0xD5BFB**, every equality hit joining the chain at 0xD5C01. Read as a rejection list it says *Types {3,4,5} release the aim*, which is exactly DOOR/ELEVATOR/SHIP from the table above **[V(me)]**.

**Landed in kuluu as `jw-stack-815 7738d7ed`**: `LookData::retail_type_of_look_size` (the eight-row table, masked the way retail masks it, extracted so there is one copy — `retail_type()` now delegates to it), all eight `MODELTYPE` constants scraped from LSB rather than only two (`ffxi-vocab/build.rs`, per vendor-scrape: no hand-maintained values), and a precomputed verdict carried on the snapshot actor state that filters where an *observer* resolves its look point (a door in the path of a head turn releases the aim like a status-gate miss, rather than aborting the pass). A mount entry carries its rider's verdict because retail keeps no record for a mount at all — the rider is the entity — so kuluu invents none. Not modelled, on purpose: the SubKind-1 flag branch and bit 30 of `ent+0x12C`, unread as above.

**What §B-ter's `[I]` still lacks:** attributing each store site to a message opcode. This section shows one writer lives inside the handler that decodes `look.size`, and what that handler is byte-visible to read: `word[esi+8]` indexes the global entity table, `word[esi+0x32]` drives a range test (band 0x213..0x228 @0x9C9DD/0x9C9E4) whose result lands on record byte `+0xEF`, and `test byte ptr [esi + 0xa], 0x10` gates the tail of the SubKind-1 arm (0x9C976). §M maps that bit to a SendFlg equipment flag **[web]**. Confirms via `tables_functions.csv` that no function seed exists between `0x9B550` and `0x9CEB0`, so the enclosing handler entry is above `0x9C8E0` and still unattributed. Settling read unchanged: walk back from 0x9C907 to the prologue, then match that entry against the packet dispatcher's table.

## B-bis. The `actor+0xB2` visibility/flag WORD — full `.text` census (pass of 2026-10-05, for gap row A1)

§B's look-point branch (`y −= 1.2f` when `target+0xB2 ≠ 0`) needs the field understood before it is
ported. Census tool: `tools/mem_operand_census.py --disp 0xB2` over the cached full-text sweep —
**105 hits across 53 functions, 41 writes**; every hit below re-read from raw bytes this pass.
The base question first: at §B's site the base is the **target actor itself**, not its inner record:
```
0xd5c68  call dword ptr [eax + 0x1c4]   ; edi = target actor, attach point 3 (the look point)
0xd5c7a  cmp word ptr [edi + 0xb2], 0   ; *** WORD test — bits at +0xB2 and +0xB3 both count ***
0xd5c84  fsub dword ptr [0x1032a404]    ; −1.2f on Y when nonzero
```
The struct family is confirmed by its neighbours: XIClient `BaseActor.h` lays out `char field_B0; char field_B1;
unsigned short field_B2; Resource::ResourceContainer** field_B4;` right after `SubActorStatus (+0xA4)` **[web]**,
and DancingMad's pipeline map names slot 191 (`OcclusionClip`) as *"sets +0xB0/+0xB2 on failure"* **[web]** —
corroborated by our bytes below (the occlusion query sites touch exactly that pair).

**Constructor default:** `mov word ptr [esi + 0xb2], bx` @ **0x81c3a**, bx = 0 — inside the actor base
constructor (adjacent stores zero +0x68/+0x70/+0xA0/… and fill ARGB grey `0x80808080` at +0x78/+0x7C).
So every actor starts with the WORD clear **[V(me)]**.

Bit-level writers (byte ops unless noted; all [V(me) this pass]):

| bit | set sites | clear sites |
|---|---|---|
| 0x01 | re-init/class-swap path `or dl,1`+store @ **0xc6271/0xc62c9** inside fn entry **0xC5D60** (callers all store actor vtables first: 0xc532f/0xc55ef/0xc5779/0xc590f `mov [esi],0x10330f40`, and 0xd7261 stores `0x103313e8` — subtype swaps); helper @ **0xcbdbc** (`or dl,1; mov [ecx+0xb0],1; mov [ecx+0xb2],dl`) gated by `cmp word[ecx+0xb2] != 0` short-circuit @0xcbd98 and a float test on `[ecx+0x8c]`; **occlusion region** — right after `Occlusion_QueryScreenRect (0x6c280)` writes the +0x9F4 bucket cache: **0xcc6a5/0xcc6ae**, and again @ **0xcd029-cd032** (+0xB0=1 too); child-list pass **0xcbe3a/0xcbe43**; update-region clears/re-sets @ 0xac550, 0xc7cf4/0xc7cf9, 0xc7d22/0xc7d25 | sweep over the draw list head `[0x1047d578]` (iterates every actor): `if word[+0xb2]!=0 → and byte[+0xb2], ~1` @ **0x82d5e**; also 0xac555, 0xc7cf9, 0xc7d25 |
| 0x04 | (none found — no writer sets bit 2 anywhere in `.text`; see note) | local-player-only pair keyed on the camera toggle `[0x10487f80]`: **0x842f1** (`and ~4` when toggle ≠ 0) and **0xa8ce3** (inside `sub_0A8CC0`, which *writes* the toggle byte then clears bit 2 when it turns off); both go through global object `[0x1047d600]` → lookup `0x81550` |
| 0x10 | **0x1d4e57** (`or,0x10`) — in the menu/preview control region beside focal setter `call 0x152b0` (camera `[0x104568fc]+0x2f4` read at 0x1d4e9e) | **0x1d4e1b** (`and ~0x10`) same region, other arm |
| 0x20 | **0xcd346** — gated on two actors' `[+0x13f]` low nibbles differing (after `call 0x87890`, `call 0x1cc4f0`) | **0xcd2fd** |
| 0x40 | event/state-machine (switch on `[esi+0x1bc]`, actor at `[esi+0xa0]`): `or cl,0x40`+store @ **0x8b6a1/0x8b6a4** gated by flags `[esi+0x120]`/`[esi+0x128] bit 29` | same machine @ **0x8b9f5**; and the interaction handler @ **0x8c88f** (after `call 0xd5ef0(actor,0)` / `0xd60e0(actor,0,2)`, `[esi+0xee]==2/5` branches) |
| 0x80 | tiny virtual setter pair: **0x85ac0** (`or byte [ecx+0xb2],0x80; ret 4`) | **0x85ab0** (`and byte [ecx+0xb2],0x7f; ret`) |

Bit **0x08** is read but never written directly in `.text` — `test byte ptr [esi + 0xb2], 8` @ 0x85993/0x859d3
(inside the actor-update helper at 0x857A4, which also does load/copy/stores of the whole byte around
calls to sibling methods 0x856f0/0x85820/0x85620); **bit 0x02** likewise only read
(`test …, 2` @ 0x57840 in scheduler-interpreter region, 0x85a53; `test byte[eax+0xb2],2` @ 0x857…).
They are reachable only via whole-byte stores (the census' 16 `mov reg → mov [..+0xb2]` copy sites, e.g.
the actor→actor clone copy @ **0xcb368-0xcb37f** and the event-state writes at 0x859ba–0x85a9b).
Adjacent byte `[+0xB1]` is read with `test byte ptr [esi + 0xb3], 1` @ 0x85ad3 — so the WORD's high byte
(+0xB3) has its own bit-0 consumer; D5C7A's WORD test therefore fires on that too.

**Readers of record:** the §B look-point gate @ **0xD5C7A**; whole-word equality `cmp word[edi+0xb2], bx`
@ 0x831e2; zero-tests in movement/interaction regions (0x7c01a, 0xc4a60, 0xc7d12, 0xcf060/0xcf106,
0xd0880/d08b0, 0xcbd98 short-circuit); per-bit tests listed above.

**Naming state.** What sets each bit is recorded above by *system region*: occlusion/staggered visibility
(bit 0 — matches DancingMad slot-191 gloss **[web]**), class-swap re-init (bit 0), the camera-mode toggle
global pair (bit 2, local player only), menu/preview focal control (bit 4), a two-actor `[+0x13f]` nibble
comparison (bit 5, **semantics [I]** — settling read: trace what byte `[+0x13f]&0xf` is at 0xcd32e in the
target-of-interest region), event state machines (bit 6), a virtual bit setter (**[I]** — settling read:
locate the pair's vtable slot by scanning `.rdata` for `0x10085AB0`/`0x10085AC0`; not in
tables_vtables.csv). The *aggregate* semantics the §B test uses is unambiguous regardless: **any flag set
⇒ look point lowered 1.2**.

## C. Verification I ran myself this session **[V(me)]**

| claim | check | result |
|---|---|---|
| constants 1.2 / 0.3 / -0.5 / 0.04 | read `.rdata` bits + find operands in 0xD5B10..0xD6400 | `0x32A404=1.2f`, `0x32B15C=0.3f`, `0x32A3D0=-0.5f`, `0x32A85C=0.04f`; each referenced once in the method (0xD5C86 / 0xD5DED / 0xD5DBF / 0xD5D6C) ✓ |
| gate/predicate call set | disassembled the window, matched `E8` targets | `0x157CF0`, `0x845E0`, `0x84670`, `0x84400`×6, `0x84390`×7, `0x84330/350/370` each ×1 ✓ |
| mode float semantics | looked for the -1.0 immediate | `[esi+0x854] = 0xBF800000` at 0xD5B38 ✓ |
| look point storage / weight | disps in window | `+0x848/+0x84C/+0x850` stores; `[ebx+0xBC]` ×9 with an `fadd` ✓ |
| caller "actor update 0xCC967" | scanned 0xCC880..0xCCA60 for `E8` landing on 0xD5B10 | **the call is at 0xCCA03**; nothing at 0xCC967 ✗ (their cite corrected) |
| one fpatan in the menu-model path; pi/6 two sites | byte scan of 0x278E90..0x2790B1 / whole image | `d9 f3` at 0x278FF9 only; `pi/6` bits at 0xD5547, 0x26E567 ✓ (and now understood to belong to the **menu** path) |

Reproduce:
```python
import struct,re,capstone as cs
d=open('FFXiMain.unpacked.dll','rb').read()                       # offset == RVA
for a in (0x32a404,0x32b15c,0x32a3d0,0x32a85c): print(hex(a), struct.unpack_from('<f',d,a)[0])
blob=d[0xd5b10:0xd6400]
for a in (0x32a404,0x32b15c,0x32a3d0,0x32a85c):                    # VA operand sites inside the method
    p=struct.pack('<I',0x10000000+a); print(hex(a),[hex(0xd5b10+m.start()) for m in re.finditer(re.escape(p),blob)])
md=cs.Cs(cs.CS_ARCH_X86,cs.CS_MODE_32)                            # gate call census + field disps
for i in md.disasm(blob,0xd5b10): print(hex(i.address),i.mnemonic,i.op_str)   # grep: 0x157cf0 0x84400 0xbc 0x854
for a in range(0xcc880,0xcca60):                                   # the real call site
    if d[a]==0xE8 and a+5+struct.unpack_from('<i',d,a+1)[0]==0xd5b10: print('call at',hex(a))
```

---

## D. What kuluu may implement right now (and what it must not)

* **Do port** [V(W2)/V(me)]: target selection & gates · look point = attach point 3 with Y−1.2 when `target+0xB2` ·
  aim/hold/release mode float · the **non-angular** release rule (horiz ≤ 0.3 or forward ≤ −0.5, forward = +X) ·
  the ±0.04/frame weight ramp (~25 frames @60 fps) with reset to straight-ahead at weight 0 · LockLookAt-stage
  suppression for N ticks-or-1-unit-moved.
* **Do not port**: 30° (or any angle) as the walker's head limit — that number belongs to the menu/preview model.
* **Now portable (was "open")**: the angular clamp is *not* one angle but a per-model **ellipse** {xlim, ylim, scale}
  read from the skeleton chunk, head + neck/shoulder as two records — §E. Port the ellipse and load the authored
  record; do not pin an angle in code.
* **Data caveat**: only ~26% of shipped skeletons author a non-zero limit at all (many mobs/props author zeros,
  which means *that bone does not bend*). kuluu must read the record per model rather than assume humanoid values
  apply everywhere (§E.3).

---

## E. The bend and the ellipse clamp — `0x2AC60` / `0x2B140`, and where the numbers live **[V(me)]**

This is §B's missing consumer, found by reading the code rather than hunting angle constants.
Everything in E.1/E.2/E.4 was read from bytes this session (`FFXiMain.unpacked.dll`, offset == RVA);
the *semantics* I could not fully trace are marked **[I]**.

### E.1 The bend — `0x2AC60`, exactly one caller at `0x2A32E` **[V(me)]**

```
0x2ACD9  lea  ebx, [edi+0xb0]      ; the model's own look point (the §B target point) -> operand
0x2ADE3  mov  edx, [edi+0xbc]      ; *** the ±0.04/frame blend weight from §B, consumed here ***
0x2AD55  call 0x14cf0              ; frame tick (the same clock as the walker)
0x2AD71  push 0x3d000000           ; *** f32 1/32 -> helper 0x276A0 : chase 1/32 of the remaining
                                    ;     distance per tick (~0.5 s time constant) ***
```

So `model+0xB0..B8` (look point) and `model+0xBC` (weight) are both read here — that closes §B's open question.
The **slew** is 1/32 of the remaining distance per tick **[V(me)]**, which sits *underneath* the ±0.04 weight ramp:
the weight opens the gate, the 1/32 chase moves the point.

How many bones bend (the "mode"), at `0x2AE0D..0x2AEBB` **[V(me)]**:

```
; the caller pushes the result of predicate 0x84390 — the SAME own-status predicate that gates §B's look-at:
0x2A319  lea ecx, [ebx+0x30]; mov ecx, esi; call 0x84390 ; push eax
0x2A32E  call 0x2ac60
; inside: value in {0x30} ∪ {0x3F..0x53}  -> bend ONE record
;         anything else                   -> bend TWO records
0x2AEB5  mov ebx, 2                       ; loop count for the per-record pass (a second pass at 0x2AF1B)
```

One record ⇒ head only (the §E.2 record index 0); two ⇒ **head + neck/shoulder**. The status set that reduces it
to one is authored as "sitting / resting / event-ish" **[I]** — same predicate family as the look-at gates, so
retail ties the shoulder share to actor state without any separate switch.

Per record, before use: `call 0x35270(index)` (`0x2AEDC`) and if the record's first two floats are ≤ 0-ish it is
skipped (`fld [ecx]; fcomp 0` / `fld [ecx+4]; fcomp 0` at `0x2AEE3..0x2AF00`) **[V(me)]** — i.e. *a zero limit record
means that bone does not bend*. Then the clamp runs: `push ecx` (the record) … `call 0x2b140` (`0x2AF06..0x2AF1B`)
**[V(me)]**.

### E.2 The ellipse clamp — `0x2B140`, exactly one call site (`0x2AF1B`, inside the bend) **[V(me)]**

Record layout is `{xlim f32 @+0, ylim f32 @+4, scale f32 @+8}` (fields read at `0x2B1DB` / `0x2B1E3` / `0x2B268`)
**[V(me)]**. Behaviour:

* authored values ≤ 0 fall back to **0.001f** (`.rdata` VA `0x1032A22C`) for either axis — a guard against a
  divide-by-zero on unauthored bones, *not* a default limit **[V(me)]**.
* the direction is aspect-normalised by the two axes (`0x2B21F..0x2B24F`: `fdiv`/`fmul` pairs) — so the limit is
  genuinely elliptical, not a cone **[V(me)]**;
* then scaled: one branch multiplies by `scale × 100.0f` (`.rdata` VA `0x1032A3C8` = 100), the other by
  `scale / x` — the caller selects which via a parameter **[V(me)]** for the arithmetic, **[I]** for its meaning;
* radius `R = sqrt(X²+Y²)` (`0x2B2A0..0x2B2AA`), compared to a limit; on the normal path **`fpatan` at
  `0x2B2BD`** then `fcos`/`fsin` × R write the boundary point `[esi]`, `[esi+4]`, with `w = 1.0`
  (`0x2B2C6..0x2B2E0`) **[V(me)]**. Over the limit / degenerate ⇒ branch at `0x2B33F` (re-normalise, force
  `[esi+0xC] = 1.0`, return 0) **[V(me)]**, semantics **[I]**.

So: **the head's angular limit is an ellipse in the bone's own tangent plane, with a vertical semi-axis** — this
corrects my earlier "no up/down head motion" line, which was true only of the menu-model path (one `fpatan`, one
axis, §A) **[V(me)]**.

### E.3 Where the authored numbers live — skeleton chunk kind **`0x29`**, not `0x20`

The record array is reached by accessor `0x35270(index)` (callers `0x2AEDC`, `0x2AFC3`, `0x34CBD`, `0x34DB4`)
**[V(me)]**, whose arithmetic fixes the layout exactly:

```
0x35210/0x3522A   resource lookup on [model+0xC] -> block; bone count u16 @block+0x32;
                  bones = block + 0x34, stride 30                      (lea ecx,[ecx+ecx*2]; *9; eax+ecx*2+0x34)
0x35250           refs table: count u16 at bones_end; entries = 4 + n*26  (lea ecx,[ecx+edx*4] -> 13n, *2 = 26)
0x35270           look-at record array: refs_end + 0x48 + 12*index     (lea ecx,[ecx+ecx*2+0x12]; eax+ecx*4)
```

**Replication note, and my earlier failure explained.** The resource-manager block carries a **0x30-byte prefix**
over the on-disk chunk body: relative to kuluu's parsed slice (chunk body after the 16-byte header) the same
fields are bone count u16 `+0x02` and bones from `+0x04`, which is exactly what `ffxi-dat/src/skel.rs` already
uses **[V(me)]**. So for kuluu the anchors are: **records at `refs_end + 0x48`, stride 12**, where
`refs_end = 0x04 + n·30 + 4 + m·26`. My previous attempt to replicate this read *chunk type* `0x20` — but
`0x20` is kuluu's own `ChunkKind::Img` (textures: the bodies literally carry `TXD`). The skeleton kind is **`0x29`
(`ChunkKind::Bone`)**; that mismatch, not a wrong layout, is why it "gave no plausible pair" **[V(me)]**.

Census over this install (`C:\PhoenixXI\SquareEnix\FINAL FANTASY XI`, all `.DAT`, chunks walked with kuluu's own
header decode: kind = `h & 0x7F`, len = `((h >> 7) & 0x7FFFF) * 16`) **[V(me)]**: **3,365** skeleton chunks parsed
(2 short / 1 joint-check reject), and the `{xlim, ylim}` pairs are authored per model:

| records {head}, {neck/shoulder} | skeleton chunks | who |
|---|---|---|
| `(0.24, 0.16)` + `(0.16, 0.06)`, scale `0.5` | **539** | the standard humanoids: `hum_` (70), `tar` (68), `mit` (59), `elv_` (113), `huf_` (35), `kids` (42), `eve`, and named NPCs (`aldo`, `corn`, `cum`…) |
| `(0.1, 0.1)` + `(0.1, 0.1)`, scale `0.5` | **310** | `ork ` (96), `corp`, and part of `yagu` (18/79) and `kame` (15/79) |
| `(0.15, 0.15)` + `(0.15, 0.15)`, scale `0.5` | **22** | assorted |
| `(0, 0)` ⇒ that bone does not bend, scale `0.5` | **2,488** | most mobs/props — and **all** `gob_` (106/106) and `sao ` (106/106) |

Two things this settles and one it opens:
* the numbers are **authored per-model data**, not a `.rdata` constant **[V(me)]** — so kuluu loads them from the
  skeleton chunk (the B-style data-driven path) rather than pinning a limit;
* shoulder ellipse is smaller than head's, always with `scale = 0.5`, in every shipped record pair **[V(me)]**;
* **[O?] CLOSED — and the race gloss above was wrong.** Re-derived through kuluu's own skeleton parser instead
  of a hand-written reader (`ffxi-dat/examples/dat-lookat-census.rs`, 3,368 bone chunks in this install): **every
  playable race authors both records** — `hum_` 70/71 (HumeM), `huf_` 35/35 (HumeF), `elv_` 115/116, `tar ` 68/69
  (**Tarutaru**, the skeleton behind file id 19776), `mit ` 59/64 (Mithra), `gal ` 41/42 (Galka). `gob_` and `sao.`
  are mob-family rigs, not Goblin-player/Tarutaru ones, and they plus a minority of `yagu`/`kame` are what author
  zeros. So no per-race rule may assume a race lacks a head bend: whether a rig bends is per-model data.

### E.4 Reproduce (host python, capstone 5.0.7)

```python
d=open('C:/tmp/ffximain_work/FFXiMain.unpacked.dll','rb').read()      # offset == RVA
import struct, re
struct.unpack_from('<f',d,0x2ad71-3)                                   # 0x3D000000 = 1/32 pushed at 0x2AD71
def callsites(t):
    return [a for m in re.finditer(b'\xe8', d) if (a:=m.start())+5<len(d)
            and a+5+struct.unpack_from('<i',d,a+1)[0]==t]
callsites(0x2ac60), callsites(0x2b140)                                # -> [0x2a32e], [0x2af1b]
# on-disk records (kuluu anchor):
n=u8(chunk_body,2); bones=cb+4; m=u16(bones+n*30); refs_end=bones+n*30+4+m*26
rec=[struct.unpack_from('<3f', chunk_body, refs_end+0x48+12*i) for i in range(3)]
# hum_ (ROM\125\74.DAT) -> [(0.24,0.16,0.5), (0.16,0.06,0.5), (0,0,0.5)]
```

Scratch tools for this pass: `w1_accessor.py`, `w5_bend.py`..`w8_clamp2.py`, `w9_limits_scan.py`,
`w10_race.py`/`w12_racevar.py`, `w13_callsites.py`, `w14_bendcaller.py` (session scratchpad; the reusable
chunk-walk + record read belongs in `tools/dat_stage_scan.py` next time someone touches this).

### E.5 — what the clamp's arguments actually are (read 2026-10-01 against `FFXiMain.unpacked.dll`, TDS 0x6A995428) **[V(me)]**

Needed before kuluu ports row 3, because §E.2 left "which plane, and what is `scale`" as **[I]**. Bytes:

```
0x2aeaa  lea esi,[esp+0xb0]; mov ebx,2            ; two-entry loop, stride 0x10 (one per bend record)
0x2aebc    call 0x32a40                           ; fills each entry; runs exactly twice, before the record pass
...
0x2aed9  lea ecx,[edi+8]; call 0x35270            ; record index -> {xlim,ylim,scale}
0x2aee3  fld [ecx]/fcomp 0 / fld [ecx+4]/fcomp 0  ; either limit ≤ 0 ⇒ skip this record (bone does not bend)
0x2af06  push ecx(record); push [esp+0x74]; push [esp+0x30]; push [esp+0x88]; mov ecx,edi; call 0x2b140

0x2b150..0x2b1a7                                  ; basis built from a caller-supplied frame (two axis arrays
                                                   ;   initialised identity-ish: quat (0,0,0,1) + axes (1,0)/(0,1))
0x2b1bd  call 0x282c0                             ; *** column-major mat4 × vec3, NOT a plane projection: ***
                                                   ;   out.x = m[0]vx + m[0x10]vy + m[0x20]vz   (y,z rows at +4/+8)
0x2b1cb  push 2.0f; call 0x272b0                  ; scale-by-two helper on the transformed vector
0x2b1d8..0x2b212                                  ; xlim guard: ≤0 -> 0.001 (`0x3a83126f`); ylim guard likewise
0x2b21d  branch on (xlim <=> ylim):
           u *= xlim/ylim     (aspect-normalise one component, chosen by the bigger axis)
           v *= ylim/xlim
0x2b253  test w (=third component) > 0:
           w > 0 : k = 1.0/w      (`0x1032961c` = 1.0f)   ; u,v *= scale * k     -> offsets per unit depth
           else  :                u,v *= scale * 100.0f   (`0x1032a3c8`)          -> target behind the plane, pushed out
0x2b2a0  R = hypot(u,v); compared to a limit; over-limit path:
           fpatan @0x2b2bd -> θ; [out]=cosθ·limit, [out+4]=sinθ·limit; w written as 1.0; `scale` stored at [out+8]
```

So the ellipse acts on **the two in-plane components of the look offset after it has been put through a per-entry matrix**, and — when the point is actually in front (`w > 0`) — normalised by that depth: retail limits an *angular* region expressed as offsets-per-unit-depth, with `scale × 100` reserved for the behind-the-plane case. Component ↔ axis pairing is **u ↔ xlim, v ↔ ylim**.

Constants confirmed: `0x103295d8 = 0`, `0x1032a22c/0x3a83126f = 0.001` (guard), `0x1032961c = 1.0`, `0x1032a3c8 = 100.0`.

**Still open before a kuluu port (named, cheap):** — two of these three are now closed by **§E.6**; the basis question is the one that stays.
* which matrix the per-entry frame at `[esp+0x88]/[esp+0x30]` is — read the two-entry builder `0x32a40` and the basis call `0x2d8141`, since that decides whether xlim/ylim land on the bone's own axes or the actor's; **(open: §E.6 shows what they are not)**
* what the hypot compares against exactly (which of {xlim, ylim} after aspect-normalisation) — trace FPU stack depth from `0x2b253`; **closed → `min(xlim', ylim')` of the guard-clamped axes, §E.6**
* the `push 2.0f` helper `0x272b0` (scale-by-2 on which component). **closed → uniform vec3 scale (`0x272b0`), provably irrelevant to the aim, §E.6**

Nothing here changes §B/§E.1–E.4; it pins down the shapes E.2 left open and lists exactly what a port still has to read.

### E.6 — reading the bend itself: attach frames, the status set, and what kuluu shipped (pass of 2026-10-02 against `FFXiMain.unpacked.dll`, TDS 0x6A995428) **[V(me)]**

The port (kuluu `acdf77fa`) forced a read of the bend prologue rather than the clamp in isolation. New bytes:

```
0x2ac71  mov  edi, ecx                      ; this = model
0x2ac74  push 3                             ; *** attach point index 3 -> out [esp+0x8c] ***
0x2ac84  call 0x2a750                       ; (out*, idx) : attach-point POSITION accessor
0x2ac8e  push 4                             ; *** attach point index 4 -> out [esp+0x2c] ***
0x2ac92  call 0x2a750
0x2acc3  call 0x270a0                       ; componentwise a -= b (vec3): entryA - entryB
```

* **`0x2a750` is an attach-point accessor, not a bone getter**: it calls `0x26e10(out)` then `0x2a780(out, idx)`, and `0x2a780` looks the reference up on `[model+8]` through `0x351f0(idx)` — the same reference table kuluu parses as `Skeleton::references`. So the bend's two frames are **vec3 positions** at attach points 3 and 4, and `0x270a0` subtracts one from the other **[V(me)]**.
* The per-entry builder is trivial — `0x32a40 → 0x32a50` writes `{0,0,0,1}` into each of the two entries (stride `0x10`, `ebx = 2` at RVA 0x2AEB5): an **identity rotation**, i.e. scratch output state per record, *not* a bone basis **[V(me)]**. §E.5's guess that these hold a per-entry matrix is wrong in detail: the matrices live inside the clamp (`0x2b167..0x2b1a7` initialises a local quaternion `(0,0,0,1)` plus an axis vector `(0,1,0,..)`, then calls `0x2d8141`) **[V(me)]**.
* **The one-record status set is wider than §E.1 said.** The bend receives the own-status value as a stack argument (`[esp+0x128]`) and runs an equality chain over
  `{5} ∪ {0x2F, 0x30} ∪ {0x3F…0x53} ∪ {0x55}` — a match jumps to the write of loop-count `1` (RVA 0x2AE96), otherwise count `2` (RVA 0x2AE8B/0x2AE90) **[V(me)]**. §E.1's `{0x30} ∪ {0x3F..0x53}` missed `5`, `0x2F` and `0x55`. Chain re-read from raw bytes 2026-10-05: head `83 fe 05` (`cmp esi,5`) at RVA **0x2ADFC** with its `je 0x1002ae96` at **0x2AE0D**; then `cmp esi,0x55` @0x2AE13, `cmp esi,0x2f` @0x2AE18, the 17-way expansion `cmp esi,0x3f`…`cmp esi,0x53` (0x2AE1D..0x2AE84), and `cmp esi,0x30` @0x2AE86; every arm is a short/rel `je` into 0x1002AE96 (`mov [esp+0x10],1`); the miss-fallthrough writes `mov ebp, 2` @**0x2AE8B**. The pair `{3,7}` at 0x2AC7A re-read as `c6 44 24 1e 03 c6 44 24 1f 07` **[V(me)]**.
* Statuses `5` and `0x55` additionally get `1.0f` subtracted from a float parameter at RVA 0x2ACA8..0x2ACB2 before any of this **[V(me)]** — semantics unknown, and irrelevant to a head bend that only carries one record.
* **The `push 2.0f` helper is `0x272b0(vec3*, scalar)`: it multiplies all three components** (RVA 0x272b8/0x272c0/0x272ca, no ret-immediate, uniform). Because the front branch then scales by `k = 1.0/w` on that same doubled vector and `w` was doubled too, the factor cancels exactly; behind the plane it only pushes an already-over-limit point further past a rim whose position depends solely on its bearing. **The ×2 cannot change the aim direction** — a port may ignore it **[V(me)]**.
* **The comparison radius is `min(xlim', ylim')`.** Both aspect-normalisation arms leave a circle: when `xlim' ≤ ylim'` (fall-through at RVA 0x2B21F) the second in-plane component is scaled by `xlim/ylim`; when `xlim' > ylim'` (RVA 0x2B239) the first by `ylim/xlim`. Either way `hypot` is then compared with the *smaller* guard-clamped axis, and on the over-limit arm the shrunk component is divided back by the stored ratio (`[esp+8]`, written at RVA 0x2B227/0x2B243; restored at RVA 0x2b2f7..0x2b30c). Read end to end this is exactly *point-in-ellipse* with semi-axes `xlim' × ylim'` plus radial projection onto the boundary **[V(me)]** — which closes §E.5's second bullet and confirms §E.2's "genuinely elliptical".

### E.7 — joint identity for the reference slots, from the HumeM skeleton (data side) **[V(me)]**

`ROM/27/82.DAT`, chunk kind `0x29`, name `hum_`: 94 joints, 128 references, records `(0.24,0.16,0.5) (0.16,0.06,0.5) (0,0,0.5)`.

| attach slot | joint | chain | note |
|---|---|---|---|
| 2 (`ABOVE_HEAD`) | 0 (root) | root | offset `(0,-2,0)` — the nameplate anchor kuluu already uses |
| **3** | **51** | 51→50→49→48→2→1→0 | neck; `trn (0.26,0,0)`, parent of head |
| **4** | **0 (root)** | root | offset `(0,-1.5,-1.8)` — **not a shoulder bone** |
| 5 / 6 | 52 (head) | …→51→52 | head-relative anchors (`(0.18,0,0)`, `(0.05,-0.12,0)`) |
| 7 | 50 | …→49→50 | offset `(0.05,-0.13,0)`; joint 50's children 60/74 (`+0.24` each) are the shoulder/arm roots |

Head is **52** (its children 53…60 are the face cluster), upper torso/chest is **50**, and 51 sits between them. Pose space: the chain advances along `+X`, up is `-Y`.

**This section's slot-4 conclusion was wrong for the bend; §E.8 replaced it.** The two attach slots read here (`3`, `4`) are what the *first* pass of the bend uses to build its frames. Which bones the two records rotate comes from a different byte pair, `{3, 7}`:
* record[0] ↔ reference slot **3** (`EID_NECK`) → joint **51**, the neck: ≈`atan(0.24)` ≈ 13.5° horizontal and ≈`atan(0.16)` ≈ 9.1° vertical with humanoids' authored numbers, damped below that by `scale = 0.5`.
* record[1] ↔ reference slot **7** (`EID_CHEST`) → joint **50**, the neck's parent and the owner of shoulder/arm children 60/74 — §E.3's smaller `(0.16,0.06)` ellipse is a chest-side share expressed through the hierarchy, exactly as §B describes it.
* Slot `4` (`EID_LOOK_AT`) resolving to root with offset `(0,-1.5,-1.8)` is correct for what it is: an attach point that supplies one of the bend's frames, never a bone to rotate. "Record[1] cannot be expressed" was the result of conflating those two roles.

In every shipped rig whose records are both authored, slot 7 names the **parent** of slot 3's joint — checked against `hum_`, `huf_`, `elv_`, `tar `, `mit `, `gal ` **[V(me)]**.

### E.8 — which bones the two records rotate: the reference pair {3, 7} (pass of 2026-10-03 against `FFXiMain.unpacked.dll`, TDS 0x6A995428) **[V(me)]**

The bend holds its bone references as two stack bytes written in the prologue and indexed by record number — separate from the attach slots that build its frames (§E.6):

```
0x2ac7a  mov byte ptr [esp+0x1e], 3       ; *** reference slot used by record 0 ***
0x2ac7f  mov byte ptr [esp+0x1f], 7       ; *** reference slot used by record 1 ***
...
0x2afed  movsx edx, byte ptr [esp+ebx+0x16]   ; ebx = the record counter; the same two bytes
0x2aff5  call 0x2a9b0                         ; (model, slot) -> joint id
0x2b0ae  lea  esi, [ebx*4 + 0x1045f030]       ; *** that joint's pose-scratch entry, stride 52 ***
```

The slot arithmetic closes with no remainder: both writes happen at `esp` −296 (slots −266 / −265) and the indexed read has base slot −266 for `ebx ∈ {0,1}`. The earlier "2-byte discrepancy" was an artifact of assuming callees' stack cleanup; resolving each call site's real `ret N` from its own bytes (`0x35270` is `ret 4`, `0x2b140` is `ret 16`, `0x2a750` is `ret 8`) removes it.

**The byte is a reference-table index**, i.e. the table kuluu parses as `Skeleton::references`:

```
0x2a9b5  push esi; add ecx,8; call 0x351f0    ; references[slot] — entry stride 26 (§E.4)
0x2a9c6  cmp  esi, 0x80                        ; slot must be below 128
0x2a9d4  movsx eax, word ptr [eax]             ; *** entry+0 u16 = joint index ***
```

The other ten callers of `0x2a9b0` push the constants `3`, `4`, `7`, `0x7e`, `0x7f` **[V(me)]**; XIM names those `EID_NECK`, `EID_LOOK_AT`, `EID_CHEST`, `EID_L_WEPON_JOINT`, `EID_R_WEPON_JOINT` `[web]` (XIClient `EID_INDEX.h`).

Three things fell out of reading both passes, and all three changed what kuluu had shipped:
* **The rotated bone is the reference's own joint.** Pass two writes that joint's pose-scratch record (`g_poseScratch 0x1045f030`, 52 bytes per bone — agrees with DancingMad `[web]`), so there is no hidden remap and no "NECK + record" arithmetic.
* **Two records naming one bone overwrite rather than compound.** The starting matrix each record uses is read from `[model+0x14] + 64·idx`, `idx = 0x35390(joint)` returning `byte[bones + 30·joint]` — a cache the bend never writes (`rep movsd`, RVA 0x2b004..0x2b018). A sibling accessor, `0x2a9e0`, maps joint→matrix with no such indirection; why those two differ is **[I]** and does not affect which bone moves. 11 shipped rigs (`slim`, `doll`, `butt`, `raff`…) name one bone from both records, so the later record's ellipse is what limits it.
* **A root can legitimately be a bend bone.** Exactly one rig in 3,368 (`raff`) authors non-zero limits on references that resolve to joint 0 — retail rotates its root. "Skip anything resolving to the root" is therefore not a rule; kuluu had exactly that and it went.

Reproduce (host python, capstone 5.0.7):
```python
d=open('C:/tmp/ffximain_work/FFXiMain.unpacked.dll','rb').read()
assert d[0x2ac7a:0x2ac84]==bytes.fromhex('c644241e03c644241f07')   # the pair {3, 7}
d[0x2afed:0x2afed+5].hex()                                       # 0fbe541c16 = movsx edx,[esp+ebx+0x16]
# per-race joints + authored limits (kuluu's PC_SKELETON_FILE_IDS, HumeM=1..Galka=8):
#   cargo run -p ffxi-dat --example dat-lookat-census -- <install> \
#       7072 10248 13424 16600 19776 23176 26352
```

Scratch tools for this pass (session-local): `d3.py` per-call-site-`retN` esp map, `pass2.out`, `census.out`. Landed in kuluu as `fix(actor): bend the second look-at record onto the bone retail names it`.

---



### E.9 — how the two bends compose: one shared direction, each bone's own node orientation (pass of 2026-10-05 against `FFXiMain.unpacked.dll`, TDS 0x6A995428) **[V(me)]**

E.1/E.5/E.8 recorded the pieces separately. This pass read them end to end, because kuluu had combined
them wrong (play-test P1: shoulders turning with a frozen head). `0x2AC60` is one body; the sweep splits
it at `0x2AE96`, which is why earlier reads saw "two functions".

**Slew: floor(tick) lerp steps.** The chase of the look point runs off the frame tick, not a fixed
per-frame step:

```
0x2ad55  e8969ffeff    call 0x14cf0             ; M29's tick getter
0x2ad5a  d9542410      fst  [esp+0x10]          ; working copy = tick
0x2ad6b  7546          jne  0x2adb3              ; tick <= 0 -> no chase at all this frame
; loop body:
0x2ad71  680000003d    push 0x3d000000           ; f32 1/32
0x2ad84  e817c9ffff  call 0x276a0                ; lerp(dst, src, 1/32)
0x2ad97  d8251c963210  fsub [0x1032961c]         ; tick -= 1.0   (.rdata 1.0f)
0x2adb1  74ba          je   0x2ad6d              ; repeat while the remainder is still > 0
```

So at retail's default cap (tick = 2.0, M29 §11c) the point moves two 1/32 steps per drawn frame; a
frame-rate-divisor-1 client gets one. kuluu integrates `elapsed_frames` instead, which agrees at 60 Hz.

**Pass 1 — every record clamped against the same direction.** Two scratch slots are initialised to identity
quaternions (`lea esi,[esp+0xb0]` / `mov ebx,2` at `0x2AEAE..0x2AEBB`, then `call 0x32a40` per slot — E.6), and
the record loop walks them in step:

```
0x2aed1  lea ebx,[esp+0xb0]      ; cursor over the two slots, stride 0x10 (`add ebx,0x10` at 0x2AF8B)
0x2aedc  call 0x35270            ; record index -> {xlim, ylim, scale}   (E.3)
0x2af06..0x2af19                 ; push record / [esp+0x74] / [esp+0x30] / [esp+0x88]; mov ecx,edi; call 0x2b140
0x2af8a  inc esi / add ebx,0x10 / cmp esi,ebp / jl 0x2aed8
```

Every operand of the clamp is produced by loop-invariant instructions (the four `lea`/`push` above), and each
iteration stores only inside its own scratch (`[esp+0x3c]`..`[esp+0x48]`, `0x2AF3D..0x2AF56`) before writing the
resulting quaternion into *its* slot at `ebx`. Nothing re-aims a record after another bone has bent: both
bends are computed against one direction vector, built once before the loop from the two attach-point frames
(§E.6: `push 3`/`push 4` at 0x2AC74/0x2AC8E, subtracted by `call 0x270a0` at 0x2ACC3) and never re-sampled
inside the record loop; the resulting quaternion is kept in each slot for pass 2.

**Pass 2 — compose onto each bone's own node, write the override table.** For `i` in the record count:

```
0x2afbd  lea esi,[edi+8]; push ebx; call 0x35270          ; same record again (limits are the gate)
0x2afed  movsx edx, byte [esp+ebx+0x16]                    ; reference slot byte: 3 then 7 (E.8)
0x2aff5  call 0x2a9b0                                      ; slot -> joint id            = ebx
0x2afff  call 0x35390                                      ; joint id -> node index      = esi
0x2b004  mov edx,[edi+0x14]; shl esi,6; add esi,edx        ; the model's live node array: [this+0x14] + node*64
0x2b00c..0x2b018  sub esp,0x40 / mov ecx,0x10 / rep movsd  ; copy that 4x4 down to scratch (16 dwords)
0x2b021  call 0x32e70                                      ; matrix -> quaternion: the bone's own orientation
0x2b066/0x2b06d  call 0x32b50 twice                        ; quaternion multiply, chaining the record's bend (slot = ebp, +0x10 per record)
0x2b072..0x2b087 mov [ebp+0],[4],[8],[0xc]                 ; product written back over the slot
0x2b0a9  lea ebx,[ebx+ecx*4]                               ; ebx = joint id, scaled: bone*13
0x2b0ae  lea esi,[ebx*4 + 0x1045f030]                      ; -> pose-scratch entry, stride 0x34 per BONE (E.8)
0x2b0b7  call 0x32b50                                      ; composed orientation multiplied into that entry
```

`[this+0x14]` is therefore *persistent* bone state: this pass reads a node's current transform, multiplies the
look-at bend onto it, and hands the result to the override table `0x1045F030 + bone*0x34` that dancer's skeleton
build then composes through the hierarchy. Two consequences, both landed:

- **the head's world turn is shoulder bend composed with head bend**, each computed from the pre-bend pose —
  not one rigid subtree rotation stacked on another (kuluu `631a4721`, test `both_bends_compound_into_the_head_turn`);
- **a node no clip touched this frame still holds last frame's transform** — same array, used by the motion pass.
  Recorded separately in dancer_engine.md; kuluu `476ea336` (`carry_unkeyed_channels`).

**Correction to E.1/E.5's record-skip test.** Both passes gate on the same compare pair, and the sense decides
whether an authored record bends at all:

```
0x2aee3  fld [ecx] / fcomp [0x103295d8] (=0.0) ; xlim vs 0
0x2aeed  test ah,0x44 ; jp 0x2af06              ; -> run the clamp
0x2aef2  fld [ecx+4] / fcomp 0                  ; ylim vs 0 (reached only when the first compare tied)
0x2aefd  test ah,0x44 ; jnp 0x2af8a             ; -> skip this record
```

`test ah,0x44` masks **C3 (equal) and C2 (unordered)**; `test ah,0x41` would be the C0/C3 pair, which is what a
"greater-or-equal" test needs. C0 ("less") is deliberately *not* in this mask, so each compare asks only "is
this float zero". Pass 2 repeats it at `0x2AFCA..0x2AFE7` with the same two outcomes. Read together: **a record
bends unless both semi-axes are exactly zero.** The earlier "first two floats ≤ 0-ish" phrasing (E.1/E.5) is not
what these bytes do — a negative limit is *not* skipped here; it falls through to E.2's `0x3A83126F` = 0.001
guard inside the clamp, which is where a nonsense axis actually gets bounded. The flag mapping is anchored by a
nearby comparison whose meaning is independently known: the slew loop above masks C3|C0 (`and eax,0x4100`) and
must iterate while `tick − 1.0 > 0`, i.e. "ZF set ⇔ both flags clear ⇔ greater".

## F. Leads & observations carried from summary.md §9 tail (split 2026-10-05 — history, with current status tagged)

Status tags as of this split: the **limit/slew/tug hunt** below was closed by §E/§E.8 (authored
`{xlim,ylim,scale}` records in the skeleton chunk + bend bones from reference slots {3,7}; no
J-pass curve-table search remains). The **"steering question"** was answered 2026-10-04: look-at is a
bone mechanic layered by the W-pass controller — not animation curves reacting to target (kuluu_gaps
B4 ruling + rows A1-A6 landed). The sqmoKeyChannel interpolation conflict below is **resolved [V]** in
dancer_engine.md §4a (caller census: all 46+26 evaluator sites sit in the CMo* effect region, zero in
motion channels). What stays open from this block verbatim: nothing S3-specific — it stands as the
record of what we believed mid-dig.

**The head limit/slew/tug — now with a better lead than "somewhere in the curves".** The D pass

found the overlay layer that actually rotates actors toward things (`CMoLockLookAtDriveTask` /

`CMoActorRotationDriveTask`, driven by degree-denominated authored values), **and we now know who

creates them**: interpreter opcode cases **135** and **168** inside `CMoSchedularTask_Interpret`

(`0x57FB0..0x5DFF0`; jump table `.rdata 0x5DC1C`, 196 entries) — [drivetask.md](drivetask.md) §5a.

No float immediates appear in either handler, so the limit / duration / degree magnitudes are

**operands in authored effect-script data**.



**Operand encoding is now known [V] ([drivetask.md](drivetask.md) §5b):** the interpreter's fetcher

`0x1005E590` reads a **signed 16-bit authored integer** from the script record (`[ctx+0x88]+6`), scales

it by `[ctx+0x9C]`, and `0x10311C2C` (`_ftoll`) turns it into an **integer duration**; the rotation task's

target orientation arrives as **three values converted with π/180 (degrees)** while its *start*

orientation is captured live via virtual slot `[obj->vfx+0x1C0]`. Allocation sizes in both handlers

(`push 0x80`, `push 0xA0`) equal the classes' descriptor sizes, and the ctor stores exactly the two

vtables we located (`0x32BAC4` main, `0x32BAA8` at +0x34) — byte-level proof of the D-pass mapping.



**So S3's remaining gap is narrow and honest:** (i) re-derive the ctor arg-slot → field mapping

(I tried and got contradictory readings; recorded as unresolved in drivetask.md §5b — fix by simulating

the handler stack or by pulling member names from PS2 DWARF instead of guessing offsets), then (ii) go

to the authored data side: find the script records that carry opcodes **135/168** and read their

operands. Secondary leads, still open:



1. the head's **6-bit joint index** and its constant table (saturation = limit, velocity = slew);

2. the **per-joint param struct** `{index, scale@+4, scale2@+8}` (the head's `scale`).



**Open conflict worth settling early.** DancingMad reports `sqmoKeyChannel`'s interpolation enum

(`1`=Linear, `2`=Smooth) as *never exercised* in their retail build, while our J pass found two

quadratic "smooth" curve evaluators (`0x547A0`, `0x546F0`) with 46 and 26 call sites. Probable

resolution: motion-channel interpolation ≠ the joint-drive curves J pass saw (matches the J/D layer

split), but **our build needs a caller census to say so**. Until then nobody quotes either claim.



A **separate look-at/aim controller** is not ruled out, but its old lead was bogus: the

"double-fpatan sites" **0x5EA03 / 0x5EF03** are `xor eax, eax` linear-sweep artifacts (J11).

The site worth tracing now is **0x5EA7F..0x5EA93** — `fpatan` of two locals subtracted from an

angle stored at `[obj+0x94]`. Tooling note: always sweep with `skipdata=True`; see §8a of

[joint.md](joint.md) for the x87 ground truth (capstone was never broken).



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



HISTORICAL NOTE: the research-only rule of that pass is retired — kuluu edits now proceed row-by-row per Shane's standing orders (2026-10-05). Citation form for those edits stays `FFXiMain.dll retail-2026-09 RVA 0x...`.

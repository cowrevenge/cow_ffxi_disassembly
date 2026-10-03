# FFXI retail client: the **DriveTask** layer (D pass) — how an actor is made to look/turn

Sixth-and-a-half pass, cut against TDS **0x6A995428** (`client=retail-2026-09`), same
conventions as [../README.md](../README.md). It sits *between* the animation driver (F pass,
[mob_animation.md](mob_animation.md)) and the skeleton joint integrator (J pass,
[joint.md](joint.md)).

**Why this pass exists:** kuluu needs a mechanism — not an invented constant — for four
observed retail behaviours: (1) legs/body facing the right way while strafing a locked target;
(2) no visible seam at idle↔walk; (3) head follows the target to a limit, snaps back straight,
body tugs slightly; (4) camera spring/catch-up feel. Every one of them is an **overlay applied
on top of the animated pose**, and retail has a named mechanism for overlays: `CMo*DriveTask`.

Tiers: **[V]** byte-verified in the DLL · **[I]** inference from verified parts · **[O]** user's
retail observation.

## 1. The middleware is identified (navigation map, not ground truth) [V]

`FFXiMain.dll` embeds its build-time source paths under `C:\dev\dancer\…`. The animation/model
half of the engine ("**dancer**") is organised as:

| module | files seen | why it matters to us |
|--------|-----------|----------------------|
| `sqBase` | sqArray, sqError, sqIO, sqMatrix3, sqMatrix4, sqObject, **sqQuat**, sqSQO, sqStructArray | math + object system (quaternions exist here) |
| `sqModel` | sqParser, sqmdDMB, sqmdIO, **sqmdModel**, sqmdScript, sqmdSnap, sqmdSort | `sqmdModelLookAt()` lives here; snap tags (bone↔bone) live in sqmdSnap |
| `sqMotion` | sqmoBuild, sqmoChannel, sqmoChannelMotion, sqmoFrameChannel, **sqmoKeyChannel**, sqmoMayaChannel, **sqmoMixerMotion**, sqmoMotion, sqmoPlaybackChannel, sqmoStreamChannel, sqmoUtil | the channel/curve system: keyframe channels + a **mixer** (relevant to the idle↔walk seam) |
| `sqHierarchy` | sqhiNode | bone/hierarchy nodes |
| `sqSkeleton` | sqskJoint | skeleton/joint construction + validation |
| `sqOpcode` | sqopOpcode, sqopSystem, sqopTrack | the runtime opcode/track layer (matches F pass's scheduler/stage stream) |
| `sqRend`, `sqGrafix`, `sqImage`, `sqDeform`, `sqRab`… | — | render/resource side, lower priority |

Error strings confirm the APIs: `"Error! sqmdModelLookAt() called with invalid <boneNdx> [%d of %d]"`
(`.rdata 0x103B3C30`; code tail at `0x2790A2`) — so **look-at is a model-level operation addressed
by bone index**, and it range-checks the index. **[V]**

## 2. The object system has usable class metadata [V]

Despite mktables.py's note "no RTTI", Square ships its own descriptor records:

```c
// .rdata, e.g. 0x32B7D4
struct ClassDesc { const char* name; uint32_t size; ClassDesc* parent; };
```

Parsing `{ptr→C-identifier-ish string, size ∈ [4,0x2000], ptr}` across `.rdata` yields **425**
records with sensible hierarchies, e.g.:

| class | descriptor | size | parent |
|-------|-----------|------|--------|
| `CMoTask` | 0x32C960 | 0x34 | — |
| `CMoSchedularTask` | 0x32B7F8 | 0x14A | CMoTask |
| `CMoLockLookAtDriveTask` | **0x32B7D4** | **0x80** | CMoTask |
| `CMoActorRotationDriveTask` | **0x32B7EC** | **0xA0** | CMoTask |
| `CMoLockColorDriveTask` | 0x32B7C8 | 0x7C | CMoTask |
| `CMoActorColorDriveTask` | 0x32B7E0 | 0x88 | CMoTask |
| `CMoPathDriveActorTask` | 0x32B7BC | 0xB0 | CMoTask |
| `CXiSkeletonActor` | 0x330EBC | **0xA0C** | `CXiCollisionActor` |
| `CMoSkeletonElem` | 0x32B008 | 0x1D9 | `CMoElem` |

Each class also has an RTTI accessor thunk `mov eax, <ClassDesc>; ret`, and **that thunk is a vtable
slot** — which is how these classes' vtables were located (see §3). Sizes are immediately useful:
they bound which field offsets a class can own. **[V]**

## 3. The DriveTask vtable family [V]

The five task classes above have **equal-stride vtables, stride `0x48` = 18 slots**, laid out in
`.rdata` back to back:

| table (vftable candidate) | class it belongs to | code refs into it |
|---------------------------|--------------------|-------------------|
| 0x32B9D0 / 0x32B9EC | LockColor (main / sub-object @+0x34) | 0x5F3FE, 0x5F346 |
| **0x32BA18 / 0x32BA34** | **LockLookAt** (main / sub-object) | **0x5F47F, 0x5F476** (construction sites), also 0x5F669/0x5F671 |
| 0x32BA60 / 0x32BA7C | ActorColor | 0x5F6E2, 0x5F6E8 |
| **0x32BAA8 / 0x32BAC4** | **ActorRotation** | **0x5FA49, 0x5FA4F**, also 0x5FE3A/0x5FE42 |

The pattern `add ecx, -0x34` + tail-call into the base vtable (e.g. at 0x5F500, 0x5F520, 0x5FAF0)
is a **downcast thunk**: each task embeds another object at offset **+0x34** and exposes its
interface through a second vtable. **[V]** for the bytes, **[I]** for "two-interface task".

## 4. `CMoActorRotationDriveTask` update — a driven rotation with a timer [V]

Region `0x5FB30..~0x5FE10` (inside the ActorRotation task's code block). Decoded shape:

```c
// FFXiMain.dll retail-2026-09, RVA 0x5FB30 — ActorRotationDriveTask::update-ish
float t;                                   // local at esp+0xC/0x10/0x14
if (task->mode /*+0x7c*/ != 0) {                        // 0x5FB36
    float remain = clock()->dt - task->timer /*+0x74*/;  // [0x1047BFA8]+0xEB0, 0x5FB3D..0x5FB48
    if (remain <= 0.0f) goto running;                    // test ah,5 ; jp → 0x5FCD8   (§ J10 idioms)
}                                                        // else fall through with t = 1.0
running:                                                 // 0x5FB61
    k = lerp(task->from /*+0x80,+0x84,+0x88*/,             // p = (to − from)*k + from
             task->to   /*+0x90,+0x94,+0x98*/);            // 0x5FB67..0x5FBBa
    target = resolve(/* CMoElem-ish via 0x1003B6D0 */);   // 0x5FBC0
    switch (task->mode /*+0x7c*/) { case 0: …; case 1: write_xyz(target+0xE4.. ); }
```

Corroborations, not guesses: field offsets `+0x74`, `+0x7c`, `+0x80…+0x9C` all fit inside the
class size **0xA0** from its descriptor; the clock pointer/slot is exactly the J-pass dt source.
Writes land as **float pairs** (`mov [eax+0xE4],ecx ; mov [eax+0xE8],edx ; +0xEC ; +0xF0`) — a
two-float-per-pair copy, so the thing being written at `+0xE4…+0xF0` is *not* necessarily the same
record as J pass's integrated angles. **[V]** for instructions/offsets; **[I]** for the struct reading.

## 5. The numbers are **degree-denominated** in this layer [V]

Constant scan over the whole DriveTask family code block (`0x5F3C0..0x60980`) finds exactly six
globals:

| RVA | value | uses | where |
|-----|-------|------|-------|
| 0x103295D8 | `0.0` | 15 | all tasks (guards) |
| 0x1032961C | `1.0` | 8 | lerp end / progress clamp |
| 0x10329D30 | `3.1415` | 9 | angle wrap (ActorRotation 0x5FC2A…) |
| 0x10329D28 | `-3.1415` | 9 | angle wrap |
| **0x10329D2C** | **`6.28299999…` (i.e. `6.283`, NOT exact 2π)** | 18 | angle wrap in this layer |
| **0x1032A9F4** | **`0.0174527783` = π/180 (deg→rad)** | 3 | **only at 0x5FA95, 0x5FABB, 0x5FACB — inside `CMoActorRotationDriveTask`** |

Consequences for kuluu:

- Retail expresses authored rotation in **degrees** right where the rotation drive task builds
  its target (three conversion sites). Any limit/tug magnitude we are after is therefore very
  likely a **degree value carried by data**, converted once — not a radian clamp constant. **[I]**
- This layer wraps angles with **`6.283`/`±3.1415`**, which is *different* from J pass's
  `0x32A3B0/B4/B8` (exact ±π, 2π) pair. Two different wrap conventions exist in the binary; do not
  assume one global wrap constant when doing parity work. **[V]**

## 5a. Who builds these tasks: the effect-script interpreter **[V]**

Both construction sites (`0x5F476/0x5F47F`, `0x5FA49/0x5FA4F`) live inside **one function,
`0x57FB0..0x5DFF0`** (~24 KB), whose jump table is `.rdata 0x5DC1C` — **196 entries** in our build.

**Cross-confirmation of DancingMad + a refinement of the tier rule:** they name exactly this thing —
`CMoSchedularTask_Interpret 0x10057FB0 (23.6 KB, jump table 0x1005DC1C)` — and our bytes agree on
**both addresses**. So their build is close enough that *some* RVAs do coincide with ours. The
`[web]` rule stays, but it becomes **per-region: check each address; never blanket-assume a match or
a mismatch** (`XiZone`'s singleton differs).

> **Correction (later pass).** This section said the jump table has *196* entries and that the case
> index equals the stage type byte. Both were wrong, and they are the origin of the bogus `0x87/0xA8`
> record markers in §8 — see §9.1 and §10 for the dispatch bytes (`case = type − 2`, **194** entries).

Each task type has its own interpreter opcode case (index = position in the 0x5DC1C table; handler =
nearest preceding table target for the site):

| opcode case | handler | builds | allocation |
|---|---|---|---|
| **135** | 0x5B14C | `CMoLockLookAtDriveTask` | `push 0x80` — equals its descriptor size **0x80** (independent cross-check that the descriptor's u32 field *is* object size) |
| **168** | 0x5B3DF | `CMoActorRotationDriveTask` | allocation cross-check not done yet |

Case 135 decoded:

```asm
0x5B14C  mov  ecx, esi
0x5B14E  call 0x10062770      ; operand/guard fetch from the script context -> eax; 0 => bail
0x5B15B  push 0x80            ; class size
0x5B160  call 0x1005E040      ; operator new
0x5B174  call 0x1005E590      ; script-context accessor #1
0x5B179  call 0x10311C2C      ; global / other-module getter -> eax   (ctor arg)
0x5B181  call 0x10062770      ; operand fetch from the script stream -> eax (ctor arg)
0x5B187  push esi             ; scheduler/script context
0x5B18A  call 0x1005F450      ; CMoLockLookAtDriveTask ctor(ecx = block; args: operand, global, ctx)
```

**Consequence for S3 (head limit / slew / tug):** no float immediate appears in either handler — the
magnitudes are **operands read from authored effect-script data**. That is consistent with J pass
(no clamp constant found) and with this layer's π/180 conversion (**the operand arrives in degrees**).
The hunt therefore moves **to the data side**: what `0x10062770` / `0x1005E590` fetch (width/type of
each operand), and which authored script records emit opcodes **135/168**.

## 5b. Case 168 → `CMoActorRotationDriveTask` ctor: the authored operands **[V]**

Handler (`0x5B3DF..0x5B446`) decoded:

```asm
0x5B3E1  call 0x100627D0      ; resolve an object for this opcode -> eax; 0 => bail
0x5B3EE  push 0xa0            ; allocation size == descriptor size 0xA0 (second independent confirmation)
0x5B3F3  call 0x1005E040      ; alloc + register with the task manager (calls 0x100748F0; sets flag 0x1047D13C)
0x5B40B  call 0x1005E590      ; fetch authored operand: int16 [rec+6] -> FPU, × scale [ctx+0x9C]
0x5B412  call 0x10311C2C      ; _ftoll: float -> integer (so the duration is an INTEGER, likely frames)
0x5B417..0x5B429               ; read the SCRIPT RECORD [ctx+0x88]: fields +0x08, +0x0C, +0x10,
                               ;   and a byte field +0x14 (zero-extended) -> pushed as ctor args
0x5B42C  call 0x10062770      ; resolve another object -> eax (pushed)
0x5B435  call 0x1005FA20      ; CMoActorRotationDriveTask ctor, 7 args, ret 0x1C
```

`0x1005E590`, the operand fetcher, in full (**the authored value is a signed 16-bit integer scaled by
a context factor**):

```c
// RVA 0x1005E590 — fetch a scaled authored operand
float v = (float)(int16_t)*((uint16_t*)ctx->record /*[ctx+0x88]*/ + 3);   // word at record+6
return v * *(float*)(ctx + 0x9c);
```

Ctor facts (`0x5FA20..0x5FAD9`, **verified**):
- stores **both** vtables we located — `[task] = 0x32BAC4` and `[task+0x34] = 0x32BAA8`. That is byte-
  level proof of the D-pass vtable identification (main object + embedded sub-object at +0x34).
- writes `1.0f` to `[task+0x9c]`.
- performs **three** conversions `[arg] × 0.0174527783` (**π/180**) storing to `[task+0x90]`,
  `[task+0x94]`, `[task+0x98]` → **the target orientation is supplied in degrees**.
- reads a triple through virtual slot `[obj->vfx + 0x1C0]` (called three times, fields +0/+4/+8) and
  stores to `[task+0x80..0x88]` → the *starting* orientation is **captured live at creation**.
- `fild dword …` of an integer argument, stored to `[task+0x74]` and `[task+0x78]` (matches the
  update's countdown use: `+0x74` ticked against clock dt, per §4).

**Arg-slot mapping — the *set* feeding each destination is [V]; the float-to-axis pairing stays [I].**
Frame rule, verified against the ctor prologue: args sit at `entry esp + 4k`; after a body has pushed
`P` bytes below its return address, arg *k* reads at **body `[esp + P + 4k]`**. A callee that pops its
own stack arguments (`ret imm`) *reduces* the later `P`, so raw displacements on either side of such a
call are not comparable — reading them as if they were is what produced this section's earlier
"exactly one mapping is wrong" claim. There was no contradiction in the binary.

Push order in **both** handlers (0x5B392 for stage `0xA9`, 0x5B3DF for stage `0xAA`; they join at the
shared tail `jmp 0x1005b42a`) fixes which arg index carries which record field, and each destination is
reached by exactly one of them:

| entry slot | handler source (push order) | lands in |
|---|---|---|
| +0x4 | `esi` scheduler/script ctx | base ctor only (`[esp+4]`, read before any push) |
| +0x8 | result of tail resolver `call 0x10062770` | the **driven object**: receiver of the three virtual `[obj+0x1C0]` getters whose results are stored to `[task+0x80/+0x84/+0x88]` (the captured start orientation) |
| +0xC | `(int)byte[record+0x14]` — the mode byte | **`[task+0x7c]`** (store at 0x5FA41): exactly the field the update null-tests and then branches on as `{0,1}` (§12.1) |
| +0x10 / +0x14 / +0x18 | `float record[+8] / [+C] / [+0x10]` | `[task+0x90] / [task+0x94] / [task+0x98]` **in that order** |
| +0x1C | `_ftoll(int16[record+6] × [ctx+0x9c])` | `[task+0x74]` *and* `[task+0x78]`: `fild dword [esp+0x28]` at 0x5FA58 feeds both (`fst` + `fstp`) |

The pairing is closed by counting each callee's own stack cleanup, which is the step that was missing
every earlier time this section moved: prologue pushes `ebx/esi/edi/eax` (P=0x10), but **`call
0x10074790` returns `ret 4`** and takes its argument back, so from 0x5FA2F on the frame sits at P=0xC;
`0x1003b540` is `ret 0`; the embedded-object ctor `0x1003b7b0` is also `ret 4`, again leaving P=0xC
across the whole angle-capture region. With that, every displacement solves to exactly one entry slot:
`[esp+0x18]→arg3` (mode), `[esp+0x14]→arg2` (driven object), `[esp+0x28]→arg7` (duration),
`[esp+0x1C]@P=0xC→arg4`, then after the `pop edi` at 0x5FAB0 (P=0x8) `[esp+0x1C]→arg5` and
`[esp+0x20]→arg6`. No cell is left unexplained, and record order reaches the three target slots
unshuffled — pairs `+0x80/+0x90`, `+0x84/+0x94`, `+0x88/+0x98`.

What this does *not* name is what those three axes mean in world terms (which of the driven object's
`+0x44/+0x48/+0x4C` slots is yaw and which are pitch/roll); that needs the consumer side of the driven
class, not more of this one. Every shipped record leaves the outer two at `+0.0f` and puts the turn in
the middle slot (§10.1), so this axis is the only one with observed retail usage.

## 6. What this pass still does NOT know [O]

1. **Which bone index is "the head"**, and who supplies that index to `sqmdModelLookAt`. The
   error string proves a boneNdx parameter; the caller set is not yet traced.
2. ~~Who constructs them~~ → **answered (§5a)**: interpreter opcodes **135 / 168** inside
   `CMoSchedularTask_Interpret` (0x57FB0; jump table `.rdata 0x5DC1C`, 196 entries). Still unknown:
   the operand schema — what `0x10062770` and `0x1005E590` read, per opcode — and which authored
   script records carry opcodes 135/168 with what degree/duration values. **This is now the top dig.**
3. `sqmdModelLookAt`'s semantics. Its bounds are now known via the function-start table —
   **`0x278E90..0x2790C0`, one caller at `0x26E6D3`** — but the body is not read yet, so we still
   don't know which bone index it uses for a head.
4. Whether the +0xE4…+0xF0 pair-writes are joint angles or a different record (§4 caveat).
5. `CMoLockLookAtDriveTask::update` (region 0x5F540…) computes progress-like values by comparing
   `[esi+0x78] − obj->field` against 0.0 and 1.0 via virtual `[obj->vfx+0x1BC]`. The ActorRotation ctor
   (§5b) writes the same pair of fields from one integer argument (`[+0x74]`, `[+0x78]`) and its update
   ticks `+0x74` against dt ⇒ **duration** for that class; whether LockLookAt shares that meaning is
   still inferred, not proven.
6. The operand-fetcher pair `0x100627D0` vs `0x10062770` (two object-resolution specs; both take a
   spec table in `.rdata`, e.g. `0x1032F910`, and match via the virtual predicate at `0x1002C8F0`) —
   what each resolves for opcode 168 vs 135 is not pinned. **Correction to an earlier note: `0x1032F910`
   is NOT a string** — it holds pointers/counts, so resolution is by type/spec, not by name.
7. Mixer behaviour (`sqmoMixerMotion`) — needed for the idle↔walk seam — untouched.

## 7. Reproduce [V]

The scripts are committed under [`tools/`](../tools) (the DLL itself is **not** in this repo;
point `open('FFXiMain.unpacked.dll')` at your own working copy, or run from that directory):

- `rtti_graph.py` — parse `{name,size,parent}` descriptor records; resolve parents.
- `find_vtbl2.py` — locate vtables by scanning for pointers to the `mov eax,desc; ret` thunks
  (**remember: file offset == RVA**; do not add ImageBase when indexing the buffer).
- `dt_consts2.py` — constant + sink scan over a code range (regex on `\[(0x…)\]`, not token split).
- `who_makes_tasks.py` — group `.text` references to a `.rdata` table range by target.
- `opcode_cases.py`, `interp_case.py` — verify an interpreter jump table (address + entry count),
  map an RVA to its opcode case index, and dump one handler with floats annotated inline.
- `fn_locate.py` — resolve the enclosing function of any RVA from `tables_functions.csv`. **Use this
  instead of scanning backwards for `int3` padding**, which mis-detects boundaries.

## 8. Feeder boundary + the op-135 vs op-168 split (verified; closes the "do they both carry degrees?" question)

Byte evidence, TDS 0x6A995428, produced this pass (`tools/` reproduce below).

**They are two different mechanisms.**
- **op-168 = `CMoActorRotationDriveTask` — authored rotation.** Its ctor (`0x5FA20..0x5FAD9`) performs three
  conversions `[arg] × π/180`. Those three sites `0x5FA95 / 0x5FABB / 0x5FACB` are the **only** references inside
  the interpret fn *or either task ctor* to that approximate-π/180 float (`.rdata 0x32A9F4`, value `0.01745278`). **[V]**
  There is a *second*, different constant — exact π/180 at `.rdata 0x32A840` (`0.0174532…`) — used by other, unrelated
  code (e.g. `fn 0x38E10`, `0xA6491`, `0x1878B9`). Do **not** assume one global degrees constant. **[V]**
- **op-135 = `CMoLockLookAtDriveTask` — geometry aim, NOT authored degrees.** Its ctor (`0x5F450..0x5F4E3`) has **zero**
  references to either π/180 float and no angle operand: it only resolves a target object (via the type-spec predicate
  `0x1002C8F0` / resolver `0x10062770`) plus one integer through `_ftoll`. So **there is no head-degrees number to extract**, and
  searching for "the authored LockLookAt angle" is a dead end — the aim comes from geometry (J pass §8b `0x5EA8B` atan2 family),
  not an authored magnitude. **[V]**

**Where op-168's authored magnitudes live (feeder boundary, one bounded xref).** The interpret entry `0x57FB0` has exactly **four**
callers: two internal back-edges (`0x5D1D7`, `0x5D8C3`) and **two external feeders** — `fn 0x5E10..0x57FB0` (call at `0x5F2D`)
and `fn 0x575A0..0x57BE0` (call at `0x69D`). **Both gate through the same routine `0x10057C20` immediately before interpret** — the
stage-stream record fetch/advance. Feeder A additionally drives scheduler task management (`Scheduler_Kill 0x10056EF0`,
`0x56B20`, `0x56AC0`) and resolves operands via type-spec against `.rdata 0x32A8CC`. ⇒ the DriveTask operands live in **scheduler
stage-stream records resolved by *type*, not name**, i.e. DancingMad's model-DAT 0x07 stage streams (candidate source **[I]**).

**Record markers [user-provided, to verify on DAT]:** stage byte `0x87` = op-135 record, `0xA8` = op-168 record; pull ~ten real
records and the operand layout (duration vs angle vs target) reads by eye.

**STATUS: S3 op-168 operand *extraction* is PARKED — it needs DAT access.** Ask for exactly one thing: **Shane's DAT folder**
(install ROM dir, or his parked `/tmp` examples). Until that lands there is nothing more to do on the numbers; do not churn.

Reproduce (buffer index == RVA; code refs VA = BASE + rva):
```python
# pi/180 census — locate both constants by bits, then abs-ref each; attribute to enclosing fn / opcode case.
import struct,capstone as cs
d=open('FFXiMain.unpacked.dll','rb').read(); B=0x10000000   # .text 0x1000..0x328000
for r in (0x32a840,0x32a9f4): print(hex(r), struct.unpack_from('<f',d,r)[0])
pa=struct.pack('<I', B+0x32a9f4)          # approximate pi/180 VA bytes
p=0x1000; sites=[]
while True:
    p=d.find(pa,p,0x328000)
    if p<0: break
    for st in (p-6,p-5):                  # land on the fmul/fld mem form whose disp is the const
        try:
            for i in cs.Cs(cs.CS_ARCH_X86,cs.CS_MODE_32).disasm(d[st:p+4],B+st):
                if (i.address-B)<=p<(i.address-B)+i.size and i.mnemonic in('fld','fmul'): sites.append(i.address-B)
        except Exception: pass
    p+=4
print([hex(s) for s in sorted(set(sites))])   # -> 3 inside ActorRotation ctor; the rest are unrelated fns; NONE in LockLookAt
# interpret-entry callers (who feeds stage streams): scan E8 rel32 == target
tgt=0x57fb0; m=0x1000
while True:
    m=d.find(b'\xe8',m,0x328000)
    if m<0: break
    if (m+5+struct.unpack_from('<i',d,m+1)[0])==tgt: print('caller RVA 0x%X'%m)
    m+=1   # -> exactly 4; two external feeders gate through call 0x10057c20
```

## 9. DAT pass — the authored operands in real scheduler streams (2026-10-03) **[V]** for counts, **[I]** for role

This section **supersedes the "record markers" paragraph in §8** (`stage byte 0x87 = op-135`,
`0xA8 = op-168`). Those bytes were a user-supplied guess to be verified against data; they are now
verified **against**, so do not carry them forward.

Corpus: kuluu's own reader `ffxi_dat::dat_routines` (vendor script `ffxi_disassembly/dat_routines.py`)
dumped the whole install (`C:\PhoenixXI\SquareEnix\FINAL FANTASY XI`): 52,989 `.DAT`, **178,142**
scheduler streams parsed, **450,253** stage lines (+178,141 `end`). Dump lives outside both repos at
`C:\tmp\drivetask_dat\stages.md`; [`tools/dat_stage_scan.py`](../tools/dat_stage_scan.py) re-runs every
census below against that dump.

### 9.1 The predicted markers fail **[V]**

| stage type | occurrences | payload length |
|---|---|---|
| `0x87` (predicted op-135 LockLookAt) | **0** — the byte never appears in a scheduler stream | — |
| `0xA8` (predicted op-168 ActorRotation) | 10 (`ROM\151\126`, `ROM\309\117`, `ROM\309\32`, `ROM5\7\29`) | always `len=3` ⇒ payload ends at record+0xC, i.e. **two ints** |

An ActorRotation record must supply the three degree operands + duration that §5b proves the ctor
consumes; a 2-int payload cannot. So **the jump-table case index is NOT the stage type byte** (at least
not directly in this range) — and `0x87`'s total absence means we never had a mapping, only an
assumption. Census of the whole 0xA0..0xB7 band for reference **[V]**:

```
present: A2 x32(2dw)  A3 x773(4)  A4 x232(3)  A5 x234(3)  A7 x13(3)  A8 x10(3)  A9 x5(6)
         AB x4(3)     AC x10(3)   AD x5(3)    AE x2(17)   AF x3(3)   B0 x48(6)
         B2 x9(2)     B3 x200(8)  B4 x8(3)    B5 x107(2)  B6 x8(3)   B7 x3(3)
absent : A0 A1 A6 AA B1
```

### 9.2 Authored **round angles do live in these streams** — under other stage bytes **[V]**

Scanning every printed payload dword for *exact* IEEE-754 matches of round degree/scalar values
(aligned to the dword grid, no cross-boundary matching):

| value | hits | which stage type(s) |
|---|---|---|
| `30.0f` | **1,514** | `unk28` (type 0x28) |
| `12.0f` | 499 | `0x5E`, `0xBF`, `0x6E` |
| `45.0f` | 214 | **`0x62`** (exactly 45 in all of them) + `0xA9` |
| `24.0f` / `20.0f` | 552 / 552 | `unk28` (and 3 stray `20`s in `0x5E`) |
| `10.0f` / `60.0f` / `36.0f` / `15.0f` | 189 / 54 / 38 / 12 | `unk28` (a wider value set also turns up single `4/5/2` matches) |
| `+90.0f`, `−90.0f`, `−135.0f` ×2, `+45.0f` | 5 total | **`0xA9`** — all in one file, `ROM3\0\43.DAT` |
| `1.0f` (not an angle) | 19,212 | `0x25`, `unk21`, … (scale/volume params) |

So the earlier framing "no authored magnitudes in chunk-0x07" is **wrong**; they are there, just not at
the bytes we guessed.

### 9.3 The three carriers, read by eye **[V]** for bytes, **[I]** for role

* **`0xA9` — best ActorRotation candidate.** `len=6` dw, five records total (file `ROM3\0\43.DAT`,
  routines `seq*` interleaved with `ref09 st01/del2` and the 10-dword `0x27` stages — an
  effect/ability sequence library, not a model DAT):

  ```text
  a9 06 | 3c 00 c0 03 | 00 00 00 00 | 00 00 b4 42 | 00 00 00 00 [| unprinted dword]
                        rec+8 = 0.0f   rec+C = angle   rec+0x10 = 0.0f
  angles seen: +90, -90, -135 (x2), +45      (dword grid below record base)
  ```

  Why this shape matters **[I]:** §5b showed the case we attributed to 168 pushes record fields
  `+8 / +C / +0x10` and the ctor converts **three** values × π/180 into a target euler. `0xA9` supplies
  precisely `(pitch=0, yaw=±degrees, roll=0)` at those offsets — an authored **yaw-only turn**, exactly what
  §4/§5b describe (`start` orientation captured live from the actor). A byte-level match on layout, not
  yet on identity.
* **`0x62`** — 214 occurrences over 107 model DATs (e.g. `ROM\100\56.DAT`, routine `jh02`), always
  `0a 00 23 00 | 00 00 34 42` = `(u16 10, u16 35)` + **`45.0f`**, constant everywhere. Uniform operand ⇒
  authored per-animation-stage magnitude **[I]**; but its payload ends at `rec+C`, so it cannot be the
  three-float ActorRotation record either.
* **`unk28` (type 0x28)** — by far the most common float carrier: **6,234** records in **5,259** files,
  always `len=3`: `(small int / u16-pair)` + one float whose values cluster at 30/24/20/10/60/36/15 plus
  many zeros. Pervasive across player *and* mob DATs ⇒ a general per-routine parameter; **not proven to be
  an angle** (30 could be frames or ms). The §docstring note "0x28 colour-ish (0x80808080)" is out of date —
  these payloads are int+float **[V]**.

### 9.4 Blind spots of this pass — state them, don't paper over them

1. **Payload truncation — RETIRED (§11).** `describe_stage` used to print only `raw[4:20]`, hiding the tails of
   **26,131 of 450,253** stage lines (5.8%), including ActorRotation's mode byte at `record+0x14`. Re-dumped with
   full payloads **[V]**: every angle count in §9.2 roughly doubles (chunk-`0x07`, e.g. `30.0f` 1,514 → **2,050**,
   `45.0f` 216 → **250**, `+90.0f` 1 → **16**), and it exposes long-payload types the capped view never saw —
   chiefly stage **`0x2C` (case 42)**: 2,456 records with payloads up to 21 dwords, values clustering at
   `20.0f` ×1,794 plus `60/10/30/90`. Note what this *does not* buy us: literal float equality on an undecoded
   payload is weak evidence — a `20.0f` may be a count or a distance. Only the consumer read assigns meaning,
   which is why §10.3 ranks those handler reads above any further census.
2. **Chunk coverage — measured, and the answer is "there is nothing there" (§11).** Broadening to all chunk
   types used to crash the reader (fixed since). Doing it now yields 2,348 extra "routines" in chunks `0x2B`
   motion clips (1,677), `0x05` generators (456), `0x1F` (84), `0x2A/0x3D/0x2C` — and those streams declare
   absurd stage lengths (up to **191** dwords) ⇒ they are **not scheduler streams**, just plausible parses of
   mesh/motion bodies. Chunk-`0x07` counts are byte-for-byte unchanged by any of this, so every number in §9
   stands. Lesson recorded in the tool: a census must be filtered by routine chunk type; unfiltered it
   invents records (e.g. a "`0x87` ×2" that only exists inside noise).
3. **Identity still unproven.** case-index ↔ stage-type-byte remains inferred (nearest preceding jump-table
   target), so the `A8`/`A9` adjacency above could be a ±1 attribution error. One bounded lookup settles it:
   read jump table `.rdata 0x5DC1C` entry for the handler containing `0x5B3DF` and confirm its index, then
   find which stage type the record-fetcher (`0x10057C20`) keys that case on.
4. Rare-type counts come from a *linear dump*, not from live dispatch: if some stream never reaches these
   bytes because it terminates earlier, `A9` may be over- or under-represented relative to runtime.

### 9.5 Status of this section — superseded in part by §10 **[I]**

Two claims here were later closed or re-ranked, and §9 should be read with that on top: the
"identity unproven / ±1 attribution" caveat is **closed** (the dispatch rule is `case = type − 2`, so
`0xA9` *is* ActorRotation — see §10), and this census is **navigation and corroboration only**: a data
survey cannot define a record's meaning, the consumer code can ([summary.md](summary.md) §3).
What survives: the marker falsification (9.1), the raw counts (9.2/9.3), the blind spots (9.4).

### 9.5b Carrier table, chunk-`0x07` only, payloads uncapped (current best) **[V]**

Round-value literals per stage type (aligned dword == exact float), which is the honest version of §9.2 now
that tails are visible:

| stage type | interpreter case | round values found |
|---|---|---|
| `unk21` (`0x21`) | 31 | `24.0f` ×3,708 (a constant), a few `10` |
| `unk28` (`0x28`) | 38 | `30`×1,514 · `24`×552 · `20`×549 · `10`×150 · `60`×54 · `12`×47 · `36`×38 |
| `0x25` | 35 | `36`×675 · `30`×516 · `10`×457 · `24`×419 · `20`×337 · `15`×204 · `12`×187 |
| **`0x2C`** | 42 | `20`×1,794 · `60`×139 · `10`×84 · `30`×20 · `90`×15 — and long payloads (≤21 dw) |
| `0x5E` / `0xBF` | 92 / 189 | `12.0f` ×399 / ×49 |
| **`0x62`** | 96 | `45.0f` ×214, nothing else |
| `0x6E` / `0x0B` / `0x53` | 108 / 9 / 81 | small sets around `10/12/60/15` |
| **`0xA9`** ActorRotation | 167 | `+45, +90, −90, −135 ×2`, mode byte `record+0x14 = 0` in all five |

### 9.6 Where that left S3 and plan B at the time **[I]**

* **Plan B (data-driven drive-tasks) survives** — authored magnitudes exist in the same streams the
  interpreter feeds, and `0xA9`'s layout matches ActorRotation's operand reads.
* **The head numbers are still not there, for a structural reason:** §8 proved op-135 LockLookAt takes no
  angle operand at all (geometry aim). Nothing found in the data contradicts that. A head *limit* is
  therefore expected in code near the atan2 family (J pass §8b `0x5EA8B`) or as a per-model
  `sqmdModelLookAt` parameter — not an authored degree number.
* Ranked next moves: (1) settle case↔byte identity; (2) full-payload re-dump for the rare carriers
  (`A9/62/28`, plus long-record tails) via a wrapper so kuluu stays untouched, then read ~ten of each by eye;
  (3) only after that, chase `sqmdModelLookAt`'s one caller at `0x26E6D3` for the head's bone index and
  limit/slew. S1/S2 stay first in line for kuluu work: they are our own heading/clip-restart bugs and none
  of this blocks them.

## 10. Dispatch rule + record identities closed (W pass; bytes re-verified here) **[V]**

I re-derived the dispatch myself rather than accept it, because §5a/§8 got it wrong once already:

```asm
0x57FBB  mov  ecx, [esi+0x88]        ; scheduler ctx -> current stage record
0x57FC2  mov  eax, [ecx]             ; record header dword
0x57FC4  and  eax, 0xff              ; low byte = stage type
0x57FC9  lea  edx, [eax-2]           ; *** case index = type - 2 ***
0x57FCC  cmp  edx, 0xc1              ; bound => indices 0..0xC1 = 194 entries, types 0x02..0xC3
0x57FD2  ja   0x5ac96                ; default handler (out-of-range lands here)
0x57FD8  jmp  dword [edx*4 + 0x1005DC1C]
```

That single `lea edx,[eax-2]` explains the entire §9.1 confusion: **LockLookAt is stage `0x89`**
(case 135) and **ActorRotation is stages `0xA9/0xAA`** (cases 167/168). The §8 markers `0x87/0xA8`
came from assuming index == byte; that assumption was never true, which is exactly why `0x87` has zero
occurrences.

Also corrected here: **the jump table holds 194 entries, not the 196 counted in §5a.** A naive scan for
pointers inside the interpret function's range runs two entries past the end, because out-of-range
cases legitimately point at the default handler `0x5AC96`, which is inside that same window. Derive the
count from the `cmp` bound (**[V]** — this is a trap worth remembering for any jump table in this build).

### 10.1 §9's data now reads as confirmation of the consumer contract **[V]**

| record | data found in shipped DATs | matches |
|---|---|---|
| **`0x89` LockLookAt** (case 135) | **504 records**, all `len=3`; **every byte after record+0x08 is zero**; the only operand is a signed 16-bit duration at `record+6`, taking just 13 distinct values (192 ×200, 800 ×133, 274 ×56, 84/98/86/178/148 …) | §5b/§8: args are (task, actor resolved from the runtime link slot, duration). **No angle, no limit** — now seen in data, not just inferred from absence. Its *function*: while active the actor behaves as if it has no look-at target; its watchdog ends **1.0 yalm from where the stage fired**, not on accumulated travel ([lookat.md](lookat.md) §B, resolved on bytes 2026-10-03) |
| **`0xA9` ActorRotation** (case 167) | 5 records (`ROM3\0\43.DAT`) with `pitch=+0.0f`, `yaw ∈ {+90,−90,−135,+45}`, `roll=+0.0f` at `+8/+C/+0x10` | the ctor's three ×π/180 conversions. The **mode byte at `record+0x14`** is the fifth payload dword — past kuluu's four-dword print cap, which is why §9.3 logged it as "unprinted" instead of reading it |
| **`0xAA` ActorRotation variant** (case 168) | **zero occurrences** in any chunk-`0x07` stream of this install | not a contradiction; unobserved here. Coverage is still limited to chunk `0x07` (§9.4) |

Task lifecycle for `0x89`, byte-resolved in the same pass (scratch `C:/tmp/row4/`): ctor RVA `0x5F450` sets
suppression bit 1 of `[actor+0x840]` (`or ecx, 2` @ 0x5F4A8), snapshots remaining duration from the operand
word **unscaled** (`fild dword [esp+0x18]` @ 0x5F469 → store to `task+0x74` @ 0x5F47A — there is no `[ctx+0x9c]`
multiply; a prior pass claiming one was wrong and nothing citing it stands), and anchors at `task+0x78/+0x7C`
from the actor's own X/Z (@ 0x5F4C6/0x5F4DB). The update (`0x5F540..0x5F657`) decrements remaining by clock dt
(global `0x1047BFA8`, field `+0xEB0` @ 0x5F620) and compares the anchor componentwise vs `.rdata 1.0f`
(0x5F5AA / 0x5F60F); teardown clears the suppression bit (`and ecx, 0xFFFFFFFD` @ 0x5F68B) **[V]**.

### 10.2 Byte cross-checks I ran against the W-pass look-at claims **[V]**

- Float `pi/6` bits (`3F 0A 06 3F`) appear in `.text` at exactly two sites, `0xD5547` and **`0x26E567`**;
  the latter sits inside W's model-slot init region ⇒ consistent with "one writer for the slot `+0x94`
  yaw limit; default pi/6 is hard-coded".
  **Scope correction:** those slots belong to dancer's look-at, which only the **menu/preview display model**
  (`[0x10669158]`) uses. In-world actors use method `0xD5B10` and their angular clamp is *not* pi/6 — see
  [lookat.md](lookat.md). Nothing in this DriveTask pass bears on the walker's limit either way.
- In `sqmdModelLookAt` (`0x278E90..0x2790B1`) there is exactly **one** fpatan (`d9 f3`, at **`0x278FF9`**)
  ⇒ consistent with "yaw only, no pitch computed anywhere in this path".

### 10.3 What is still open on the data side **[I]**

* The authored-float carriers still undecoded as *records* (§9.5b ranks them): **`0x28`/case 38** and
  **`0x62`/case 96** — clean, tiny layouts, so a consumer read should close each quickly; then the long-payload
  family **`0x2C`/case 42**, `0x25`/case 35 and `unk21`/case 31, which need more layout work. Read handlers
  through the fetcher contract (§5b), not another census.
* Chunk coverage beyond `0x07` is now possible (reader fixed, §11) and has been measured: nothing usable is out
  there — those bodies are mesh/motion data parsing as fake streams (§9.4 item 2).

## 11. Reader fixes (our tooling, not kuluu code) — 2026-10-03 **[V]**

The reader is `cow_tools/ffxi_disasm/dat_routines.py` plus a CRLF mirror at `ffxi_disassembly/dat_routines.py`
(inside the kuluu tree). **Neither copy is under version control** — `cow_tools/` sits in `.git/info/exclude`,
nothing in `ffxi_disassembly/` is tracked, and the two have already drifted (line endings, one docstring path).
Worth deciding separately whether to track one canonical copy.

Three changes, all in that script:

1. **Payload printing uncapped** — `describe_stage` printed `raw[4:20]`, now prints `raw[4:]`. Verified on
   `ROM3\0\43.DAT`: the five ActorRotation records show their fifth payload dword (`record+0x14`) for the first
   time; its low byte — the ctor's mode argument — is **0 in all five**.
2. **Short-record guard** — a known type whose record is shorter than the operand layout raised
   `KeyError: 'timing'`, which is what killed `--all-types`; such records now print verbatim. Verified
   synthetically: 8 known types × lengths 1–2 = 16 cases, zero exceptions.
   *Honest gap:* across this install's dump (483,713 stage lines) the guard never fires, so I still cannot name
   the record that killed the earlier run. The fix is defensive; if another dataset disagrees, the failure mode
   is now a printed line rather than a crash.
3. **CSV row build guarded** (`'timing' in s`) — otherwise the same class of crash simply moves to `--csv`.

Cost and effect: a full install scan with `--all-types` finishes in ~28 s (it used to die around file 3,000),
and chunk-`0x07` numbers are identical before/after — scheduler counts unchanged, no regression **[V]**. The new
conclusions from the wider/uncapped dump are §9.4 and the §9.5b carrier table.

`tools/dat_stage_scan.py` gained matching discipline: tallies routines by chunk type, filters with `--chunk 07`,
warns on unfiltered dumps, and flags stage lengths ≥16 dwords outside `0x07` as noise.

## 12. ActorRotation: dispatch identities and the update law (closed bytes) **[V]**

Read from the interpreter's own jump table rather than inferred from handler adjacency — §5a's "nearest
preceding table target" method finds *a* handler but silently mislabels which stage byte reaches it, so
every entry below is a direct table read of `.rdata 0x1005DC1C` with `case = stage − 2` (§10).

| stage | case | handler | gate resolver before construction |
|---|---|---|---|
| `0xA9` | 167 | 0x5B392 | `call 0x10062770`; then jumps onto the shared tail from 0x5B3DD |
| `0xAA` | 168 | 0x5B3DF | `call 0x100627D0` |

Both handlers allocate `push 0xa0` (the descriptor size again — third independent confirmation) and join
the same argument tail at **0x5B42A**, so they build the *same* task from the *same* record layout (§10.1's
five shipped records are stage `0xA9`; `0xAA` stays unobserved here). The only runtime difference between
the two stage bytes is which resolver gates construction.

### 12.1 `update` — what it actually computes (region 0x5FB30..0x5FE10)

```c
// CMoActorRotationDriveTask::update, FFXiMain.dll retail-2026-09
if (task->mode /*+0x7C, from record byte +0x14*/) {         // 0x5FB36 — mode == 0 skips the timer
    if ((task->remaining /*+0x74*/ -= clock_dt()) <= 0.0f) k = 1.0f;        // 0x5FB3D..0x5FB5F
    else                        k = 1.0f - remaining / task->duration /*+0x78*/;  // fdiv 0x5FCDC, fsubr 0x5FCDF
}                                                          // mode == 0 takes k := 1 straight away (0x5FB61)
out[i] = (to[+0x90,+0x94,+0x98][i] - from[+0x80,+0x84,+0x88][i]) * k + from[i];   // 0x5FB67..0x5FBBa
```

So the authored floats are an **absolute orientation**, not a delta — retail lerps live→authored starting
from the value captured at construction. `clock_dt()` is J pass's same clock global (`[0x1047BFA8]+0xEB0`).

Then the driven object receives it:

- The driven object comes from the task's embedded sub-object: `call 0x1003B6D0` with `ecx = task+0x34`.
  It returns that link's `[+0xC]` target straight through when its selector word at `[+0x1C]` holds a
  sentinel, and otherwise routes through the manager `call 0x10081550`. **[V]** for the bytes; what the two
  arms mean (bound vs unbound link) is **[I]**.
- Helper `call 0x10026E90(&out, &driven+0x44)` is a straight **16-byte copy**: the driven object's angle
  record at `+0x44/+0x48/+0x4C` (plus one more float slot at `+0x50`) takes the lerp result.
- Each stored angle is then wrapped into ±π with this layer's approximate pair — `fsub [6.283]` when over
  +π, `fadd [6.283]` when under −π (component 0 tested at 0x5FC2A / 0x5FC48, and the same pattern for
  `+0x48`/`+0x4C`). Same wrap convention as §5 — deliberately **not** J pass's exact ±π pair.
- One write path also stores the four floats to `driven+0xE4..+0xF0`; a third writes `driven+0x744..+0x750`
  behind `call 0x1002C8F0(driven, <name>)`, whose meaning is **[I]**. Which path runs branches on the same
  `[task+0x7C]` field (`sub eax,0 / je`, then `dec eax / jne`, at 0x5FBCF..0x5FBDC).

Consequences for kuluu: reproduce *capture-at-fire → lerp by* `1 − remaining/duration` *→ wrap into ±π with
this layer's approximate pair*. The timer only runs when the record's **mode byte is non-zero** — and all
five shipped records (§10.1) carry mode 0, so **every ActorRotation stage in this install sets the
orientation on the spot**; there is no observed retail *animated* case to prioritize, though the law above
is what one would run.

Which authored float maps to which world axis is still open (only its slot order is closed): every
shipped record puts the turn in the **middle** slot and zeroes the outer two, so applying this to an entity
transform needs the driven class's consumer side read first — not a guessed euler order.

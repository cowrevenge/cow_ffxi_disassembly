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
*(Closed by §13: the middle slot is the actor heading, and the consumer-side read is done.)*

## 13. The driven object identified, and its angle record named (X pass) **[V]**

Read from our build's own RTTI descriptors plus two independent consumers of the same record. Nothing here
invents an euler order: what is not proven stays unnamed.

### 13.1 `0x1C0` is a real accessor, and it lives on `CXiActor`

The ctor (§5b) reads the start orientation as three consecutive floats through one virtual call:

```asm
0x5FA64  mov edx, [edi]              ; edi = driven object (arg slot +8)
0x5FA66  call dword ptr [edx + 0x1c0]
0x5FA6C  mov eax, [eax]              ; component 0
...
0x5FA78  call dword ptr [edx + 0x1c0]
0x5FA7E  mov eax, [eax + 4]          ; component 1
```

So the slot returns a **pointer** to a float record — not a float. Enumerating every `lea eax,[<reg>+0x44]; ret`
in `.text` and looking for data references finds one installed in a vtable: **RVA `0x820F0`**, referenced from
`.rdata 0x32D1A0` and `0x32E588`; that address is **slot byte `0x1C0`** of the table at `.rdata 0x32CFE0`
(254 slots). The table's own class-metadata slot (byte `0x0`) is an accessor thunk
(`mov eax, <ClassDesc>; ret`) pointing to the descriptor `{name="CXiActor", size=196,
parent=CMoTask}` — the same chain the task-family descriptors sit on. **The driven object is a
`CXiActor`, and its angle record is `actor+0x44 / +0x48 / +0x4C` with one more float at `+0x50`.** **[V]**
Class chain (descriptors read from our build, sizes as authored): `XiModelActor` 1940 : `CXiControlActor`
1476 : `CXiAtelActor` 212 : `CXiActor` 196 : `CMoTask` 52 : `CYyObject`. That is why the two extra write
destinations of §12.1 fit in one object, and the class test guarding the third one is by descriptor
(`call 0x1002C8F0(obj, &XiModelActor)` = "is this a model actor", hierarchy walked through `[desc+8]`) —
**not** a name compare, correcting §6 item 6's wording.

### 13.2 The copy helper is `(dst, src)`, four dwords

`0x10026E90(dst@esp+4, src@esp+8)` moves four dwords `src → dst`; the three-float variant
`0x10026EB0` is identical without the fourth. §12.1's parenthetical listed the arguments loosely: at both
call sites in the task the pushes are `push &out; push &driven+0x44`, i.e. **arg1 = `&driven+0x44` (dst),
arg2 = `&out` (src)** — the lerp result lands *in the actor*, which is what §12.1 then describes as the
wrapped in-place record.

### 13.3 Component 1 (`actor+0x48`) is the heading — two consumers agree **[V]**

The walker/control function `0xA6240..0xA77A0` reads the record through the accessor and lands it on the
facing record (M10's `actor+0xE4/+0xE8/+0xEC/+0xF0`, `+0xE8` = yaw):

```asm
0xA6380/90/A1  call [esi->vt + 0x1c0]   ; components -> [esp+0x3c] (+0), +0x40 (+4), +0x44 (+8)
0xA63B2        call [esi->vt + 0x1c0]   ; and component 3 through [eax+0xC] -> [esp+0x48]
0xA63B8        fld  [edi + 0x18]        ; target heading
0xA63BB        fsub [esp + 0x40]        ; (target − component1), wrapped into ±π
           ... fmul [0x10329CE4] (= 0.25) ; fadd → lerp toward the target with weight 0.25, re-wrapped
0xA6457        fstp [esi + 0xE8]        ; yaw   = component1 + 0.25·(target − component1)
0xA6451/5D/63  mov  [esi+0xE4]/[esi+0xEC]/[esi+0xF0] = components 0, 2, 3
```

Independent corroboration in the in-world look-at pass (row A1's method): `call [actor->vt + 0x1c0]` then
`fld [eax+4]; fchs` and hand that to the vector-rotator `0x10027BD0` (`0xD5D04..0xD5D17`) — component **1**
is the angle used to rotate a direction into actor-local space. Heading, twice, from two unrelated callers.

So for kuluu: the authored triple is `(component0, heading, component2)` in memory order, and every shipped
record (§10.1) turns only the **heading** — which removes the last blocker on applying ActorRotation.
Components 0/2 are **unnamed**: no consumer found treats them as pitch or roll (the walker copies them
into facing-record slots `+0xE4`/`+0xEC`; nothing applies trigonometry to them), and all shipped records
zero them. Do not label them pitch/roll anywhere in kuluu.

### 13.4 What the task writes, per mode, end to end **[V]**

Both modes perform *both* writes (order differs); `out[3]` is a constant `1.0f` (`mov dword ptr [esp+0x18],
0x3f800000` @ 0x5FB7C), not an angle:

| mode | steps, in byte order |
|---|---|
| **0** (all shipped records) | `copy out→&actor+0x44; wrap components 0/1/2 into ±π` (0x5FCEA..0x5FDD7) → write raw `out[0..3]` to `actor+0xE4/+0xE8/+0xEC/+0xF0` (0x5FDA3..0x5FDCA) → if actor isa `XiModelActor`, mirror the same four floats to `actor+0x744..+0x750` (0x5FDDB..0x5FDFD) |
| 1 | raw write to `+0xE4..+0xF0` first (0x5FBED..0x5FC13), then copy/wrap the record at `+0x44` as above; **no** `+0x744` mirror |

Both branches end at 0x5FE03, which is where `[task+0x74]` (remaining) is compared to 0.0 — the task's own
termination test for a later tick.

### 13.5 Reproduce (X pass)

- Accessor hunt: byte-scan `.text` for `lea eax,[<reg>+off]; ret`, then look for its VA in data sections;
  walk the surrounding run of code-pointers to find the vtable bounds and slot index; read the descriptor
  thunk at the table start to name the class (`{name*, size, parent*}` — parents chain through `+8`).
- Virtual-slot census: match `FF <modrm mod=10 reg=2> imm32==0x1C0` — the disp is **disp32** here
  (`ff 9x c0 01 00 00`), which is why a mod=01 scan finds nothing.
- Copy-helper direction: read `mov eax,[esp+8]; mov ecx,[esp+4]` at the entry — `eax` (arg2) is the source.

## 14. Stages `0x28`/case 38 and `0x62`/case 96, handlers read through the fetcher contract (D pass) **[V]**

Jump table `.rdata 0x5DC1C` — **194** valid entries per the dispatch bound `cmp edx,0xC1` (§10);
entry index = stage byte − 2 (same law as §12). Handlers:
case 38 → RVA `0x5B0C8`; case 96 → RVA `0x5AF2C`. Both resolve their driven object through the interpreter:
script-context accessor `0x10062770` (and, in `0x62`, target gate `0x100627D0` — both reach a member at
`interp+0x34` and apply §13.4's descriptor-hierarchy test against `.rdata 0x1032F910`).

### 14.1 Stage `0x28` (case 38) — an authored transition-parameter write, not a clip request **[V]**

At fire (handler RVA 0x5B0C8..0x5B14B):
- `edi = script ctx` (accessor above); null ⇒ skip the record.
- Input float through accessor `0x1005E790` — one instruction: `fld [ctx+0x824]`.
- Call `0x100C8BB0(ctx, &o1, &o2, f_in)`: `o1 ← 1.0f`; `o2 ← [ctx+0x7C8]`, then a switch on the actor's
  own-status byte from getter `0x10084390` (`dec eax; cmp eax,0x52; ja` past; byte table at `.rdata
  0xC8E74`, jump table `0xC8E58`) — the case taken can overwrite `o2 ← [ctx+0x7D4]` (RVA 0xC8BE5).
- Actor method `0x100CD920` takes ~10 args including the two scratch values, two literal `1.0f` weights,
  and **the record's own float at +8** — `mov ecx,[esi+0x88]` (current stage record) `; mov edx,[ecx+8]`
  — i.e., §9.5b's carrier {30,24,20,10,60,36,15}. The callee walks the actor's **element list at
  `[this+0x674]`** (≤3 elements, stride `0x14`) through accessor `0x1002B5A0`, probing each element with
  predicate `0x1001B360` and assembling a bitmask — the same +0x674 chain family as look-at's bend
  consumers.
- Write-back: setter `0x1005E780` — one instruction: `[ctx+0x7D8] ← scratch`.

So `0x28` lands authored transition parameters (float + weights) on the model element list. There is no
motion/clip selection in this handler or its callees' prologue paths — kuluu's name `TransitionToIdle`
outlives what these bytes prove; keep it parsed, do not queue clips from it.

### 14.2 Stage `0x62` (case 96) — a one-shot scripted yaw turn queued on the actor **[V]**

At fire (handler RVA 0x5AF2C..0x5B0C7):
- Allocate a **`0x78`-byte task** via allocator wrapper `0x1005E040`; its constructor `0x10060F80`
  receives {script ctx, interpreter, duration float}. Flag: `call 0x100D5490(task, 1)`.
- Duration comes from fetcher `0x1005E590`: `mov eax,[ecx+0x88]; movsx edx,word[record+6]; fild;
  fmul [interp+0x9C]` — **this closes §12's unresolved duration factor: it is the interpreter field
  +0x9c** (producers now read in full — §14.5).
- Gates: script ctx and target must both resolve (`0x62770`, `0x627D0`) or nothing is applied.
- Position deltas between ctx and target are read through vtable slot byte **`+0x1BC`** — the position
  getter (its method at RVA 0xACAB0 copies a vec3 from it) — compared component-wise against **`0.1f`**
  (`.rdata 0x32A378`) and `0.0f` (`0x3295D8`).
- Authored angle: the record's float at +8 × this layer's approximate π/180 (`.rdata 0x32A9F4`); §9.5b
  census says every shipped record authors exactly **45.0°**. Heading is read through the same
  orientation accessor **[vt+0x1C0]** as §13, component at `[eax+4]`, and Δ = authored − heading is
  re-wrapped into ±π with the layer's approximate triple (`0x329D30`/`0x329D2C`/`0x329D28`).
- Store via two one-instruction setters: `0x1005E7C0` → **actor+0x870 = |Δ|**; `0x1005E7D0` →
  **actor+0x874 = signed Δ** (the sign flips when the scratch accumulator ≤ `0.0f`).

The consumer law lives in the actor update code at region RVA `0xC66AF..0xC67DA` **[V for the bytes]**:
- Gate `[actor+0x7A4] == -1`; a zero `[actor+0x86C]` takes the other branch; pending test
  `fld [actor+0x870]; fcomp 0.0f` — nothing queued ⇒ exit.
- **One-shot application:** accumulator **actor+0x620 += +0x874**, re-wrapped into ±π with the same
  approximate triple (two wrap sites), sign variant selected by comparing `+0x874` against `0.0f` and
  `+0x870 − |+0x874|` against `0.0f` — bytes read; branch intent marked **[I]**.
- Consume-and-clear: at RVA `0xC67D4` a literal `0.0f` is stored to **actor+0x870**, then the shared
  epilogue at `0xC6F4A`. The queued turn applies once; there is no per-frame ramp in this region even
  though a task object with a duration exists.
- Initialization context: constructor-like code at RVA `0xC5D60` zeroes both fields (RVA 0xC628D/0xC6293)
  alongside the parameter block (+0x7C4..+0x8C4, incl. `[+0x7D4] ← bits 0x3F6C7462` ≈ 0.924), and ctor
  `0xAC8E0` (vtable `.rdata 0x32FD58`) re-zeroes +0x870/+0x874 while setting actor flag bytes +0xB0=1,
  +0xB2 |= 4 — confirming the fields ride on the same actor/model class as §13's driven object.
- `actor+0x620` was flagged from facing-computation clusters at RVA bands `{0x58XXX}` and
  `{0x8FC00..0x92300}`. Those sites are now read: **they normalize, they do not consume**
  (§14.3 census) — the band hits are all the ±π/2π wrap idiom on `+0x620`/`+0x624`.

### 14.3 Gate + producer census (re-read byte-for-byte in this build, 2026-10-05) **[V]**

The consumer region read verbatim (`esi` = the actor/model object that also carries §B-bis's `+0xB0`/`+0xB2`
and §13's driven record):

```
0xC66AF  83 be a4 07 00 00 ff    cmp dword ptr [esi+0x7a4], -1
0xC66B6  0f 85 8e 08 00 00       jne epilogue 0x100c6f4a      ; authored turn applies only while +0x7A4 == -1
0xC66BC  8b 86 6c 08 00 00       mov eax, [esi+0x86c]         ; enable counter
0xC66C4  0f 84 15 01 00 00       je 0x100c67df                ; 0 -> the other branch (vt[+0x304]/[+0x340] probes)
0xC66CA  d9 86 70 08 00 00       fld dword [esi+0x870]        ; |Δ|
         d8 1d d8 95 32 10       fcomp [0x103295D8]           ; (= 0.0) -> queued magnitude 0 skips
0xC66E3  d9 86 74 08 00 00       fld dword [esi+0x874]        ; signed Δ
0xC66E9  d8 86 20 06 00 00       fadd dword [esi+0x620]       ; accumulator += Δ   (ONE shot)
         wrap triple: [0x10329D30] = 3.1415f, [0x10329D2C] = 6.283f, [0x10329D28] = -3.1415f
0xC67CE  d9 05 d8 95 32 10       fld dword [0x103295D8]
0xC67D4  d9 9e 70 08 00 00       fstp dword [esi+0x870]       ; clear pending magnitude, then epilogue
```

Field ownership and defaults (ctor region `0xC627F..`): `+0x86C`/`+0x870`/`+0x874` zeroed at
**0xC6287/0xC628D/0xC6293**, and `[esi+0x7a4] = -1` at **0xC62D6**. So out of the factory the consumer is
*enabled on +0x7A4 but disabled on +0x86C*: the pending turn cannot apply until something increments that
counter.

Other writers of `+0x7A4`: from a caller argument at **0x6201A** (`mov [esi+0x7a4], ecx`, `ecx = [esp+0x20]`),
a `-1` store through a getter-returned object at **0x61F6E**, and an `ebx` store in the update epilogue region
at **0xC70E6** (ebx origin untraced — settling read: the window above 0xC70D3).

Enable-counter accessor **0xD5490** (`thiscall`, byte arg): `arg == 1 -> ++[this+0x86c]`; `arg == 0 ->` decrement
only while `[this+0x86c] > 0`; any other value is a no-op — a nesting counter, not a flag. Two callers:
**0x5AF7D** (`push 1`, from the producer below) and **0x60F5E**, where no argument push is visible in stream
order (settling read: that call site's own prologue/arg provenance). Named accessors beside it at
**0x5E7C0** (`mov [ecx+0x870], eax`) and **0x5E7D0** (`mov [ecx+0x874], eax`); neighbours 0x5E7B0 returns
`[ecx+0x800]`, and **0x5E7E0** is a read-modify-write setter of bit 22 of `[ecx+0x840]` (the §B "hold" word).

Producer — function **0x5AF2C..0x5B0C8**, **the scheduler jump-table handler for stage byte `0x62`** — no direct call exists because it is
dispatched: cell `0x5DD9C` (`case = 0x62 - 2`) holds its VA (re-read bytes in §15.1); it also appears as a stored
pointer in the embedded array around RVA `0x5DD80..0x5DDD0` and in a lone data cell at **0xBC2B38**. Read law:

* allocates a 0x78-byte object (`push 0x78; call 0x1005E040`) and pulls both interpreter/script-context
  getters `0x62770` and `0x627D0`; if either is null it bails to `0x5AC96` — the turn only ever queues while a
  script context exists (ties to §14.2's duration factor +0x9C).
* `push 1; call 0xD5490` on that object -> increments its `+0x86C`, which is what unlocks consumption above.
* target angle read through vtable slot `[edx+0x1C0]`, then `Δ = want - [eax+4]` — component 1 of the §13
  angle record, i.e. the heading; wrapped into ±π with the same triple used by the consumer.
* stores `fabs(Δ)` through setter **0x5E7C0** (`mov [ecx+0x870], eax`) at call site **0x5B08F**, and the
  **authored per-frame rate** — the float at script-record cursor `[ [esi+0x88] + 8 ]` multiplied by this
  layer's π/180 (`.rdata 0x1032A9F4`, bytes `3c 8e f9 21` = 0.017452778) and sign-matched to the wrapped
  difference — through setter **0x5E7D0** (`mov [ecx+0x874], eax`) at call site **0x5B0B6**. So `+0x870` is how far
  and `+0x874` is how fast, not “|d| and signed d”; full bytes in §15.5.
* `call [edx+0x1BC]` / `call [eax+0x1BC]` are **position** accessors, not scalars: on the skeleton-actor chain
  they return a pointer to `+0x5FC`, on plain `CXiActor` one to `+0x34` (§15.4). The Δ above is a
  component-wise position difference between the two script-context objects; there is no unnamed scaling factor here,
  and the `fmul [0x1032A9F4]` belongs to the record operand described in the bullet before it.

What consumes the accumulator — census of displacement `0x620`: 160 touches in `.text`, and **all but a
handful are this wrap-normalization** (`fld/fcomp triple; fsub|fadd [0x329D2C]; fstp`) repeated across ~10
class variants (bands `0x145E1`, `0x4753F/0x479B8`, `0x58103`, `0x8FC5E`, `0x91157`..`0x92A6A`, `0xAB7B9`,
`0xC6B7C`, `0xCA2CE`, `0xCAFA5`). The field is component 1 of a **second** angle set `+0x61C..+0x628`: the ctor
at **0xC5E72** seeds it from globals `[0x1035D6B4]/[0x1035D6B8]/[0x1035D6BC]` while passing `lea eax,[esi+0x61c]`
next to `lea edi,[esi+0x44]`, so both the §13 driven record and this one live on the same object. The only
non-wrapping reads are copies at **0xC8311** (with siblings +0x61C/+0x624) inside virtual method
**0xC817A..0xC83AE**, which packs them through the `0x27B80/0x27BD0/0x27C20` setter family; that method has no
direct callers and its VA is not present as a stored pointer, so its vtable/slot is unresolved [I] (settling
read: locate the slot by walking `.rdata` pointer runs for the class whose ctor installs 0xC817A's neighbours).
**Consequence:** the `0x62` pending-pair plumbing is fully specified and portable; where the accumulated angle
lands in composed facing is not, so porting it now would mean inventing kuluu's landing site.

### 14.4 Consequences for kuluu **[I]**

- D4's question (“carriers feeding the idle↔walk seam”) answers **no clip machinery**: `0x28` writes
  transition parameters onto the +0x674 element list; `0x62` queues a one-shot yaw offset. The seam fix
  (D1) stands as landed without them.
- If kuluu dispatches these stages: `0x62` = pending-Δ pair (`|Δ|`, signed Δ) + enable-counter bump, applied
  once into the actor's second angle set `+0x620` under the §14.3 gates — everything needed except which
  consumer composes facing from that set (§14.3 last paragraph). `0x28` needs the element-list parameter
  semantics decoded further before it means anything here. Both now have schemas, so neither is an unknown
  carrier anymore.
- §12's duration factor is closed as interpreter field +0x9c; its **producers are now read** — see §14.5.

### 14.5 Producers of the interpreter operand scale `ctx+0x9C` (re-read byte-for-byte, 2026-10-05) **[V]**

The last named read in this region. Field contract (from §5b): every authored **integer** operand fetched for a
script stage is multiplied by the interpreter instance's float at `ctx+0x9C`, and `ctx+0x88` holds the current
script record, so the whole fetch family (`fmul [ecx + 0x9c]` thunks at RVA **0x5E563 / 0x5E580 / 0x5E5A3 /
0x5E5C0**, plus ~20 `fmul dword ptr [esi + 0x9c]` operand fetchers spread over RVA **0x57F1B..0x592FD**) scales
authored frame counts/angles by one per-instance factor.

There are exactly three writers of this field on that object, plus a flag that tracks whether an override exists:

| # | RVA (store) | Containing routine | What it writes |
|---|---|---|---|
| 1 default | **0x57425** — `c7 86 9c 00 00 00 00 00 80 3f` = **1.0f** | fn **0x573E0..0x5749F**, the interpreter's field-reset/init routine (same routine stores `ctx+0x80 ← [arg+0x14]`, and reaches this store whenever its third argument is 0 or 1) | unit scale |
| 2 inherit | **0x5738D** — `fld dword ptr [edi + 0x9c]` / `fstp dword ptr [esi + 0x9c]` | fn **0x57270..0x573AF** (ends `ret 4` @RVA 0x5739E) — the child-from-parent clone: byte `[edi+0x144]` is copied first, and this float copy runs **only when byte `[parent+0x142] ≠ 0`**, immediately followed by `mov byte ptr [esi + 0x142], 1` | a parent's override propagates to the child |
| 3 override | **0x56CB5** — `c7 86 9c 00 00 00 33 33 33 3f` = **0.7f** | factory fn **0x56C70..0x56CD0** (ends `ret 0x10`; one of several near-identical scheduler factories in RVA 0x56B80..0x56D20) | the only non-unit scale found |

Gate on #3, read instruction by instruction from 0x56C94:
`test edi, edi; je skip` (an owner argument must exist), then `edi = [edi+0xC]`, `eax = [[owner+0xC]] … eax=[edi+0xC]`
with `cmp eax, 0xE / je skip` and `cmp eax, 0xF / je skip` (a two-kind exclusion — semantics unread), then
`mov ax,1; cmp word ptr [edi + 0x1c], ax; jle skip`, i.e. the signed WORD at `[owner+0xC]+0x1C` must be **> 1**.
Only then does the scale drop to 0.7 and the flag `mov byte ptr [esi + 0x142], 1` get set (al is already 1 from
`mov eax,1`). Reading it plainly: when the owning context is one of two excluded kinds, or its +0x1C counter is
≤ 1, authored durations keep their unit scale; otherwise they run at **70 %**.

Supporting facts:
- Flag-byte reset routine fn **0x573B0..~0x573DF** zeroes `[ecx+0x140]`, `+0x141`, `+0x143`, `+0x144`, `+0x145`
  and dword `[ecx+0x146]` — it deliberately **leaves the override flag `+0x142`** (and the float) alone.
- A sibling factory variant beginning at RVA **0x56BB0** tests `[parent+0x142] == 0`, compares
  `[parent+0x9c]` against the constant at `.rdata [0x1032961C]`, and only then derives a value from `[this+0x7c]`
  (`fild qword ptr [esp+0xC]`) — unread semantics, recorded so a later pass does not mistake it for a producer.
- **Excluded as same-offset different-class writes:** RVA **0x99FE1** (routine seeded at 0x99AE0) and
  **0x9BB78** (seeded 0x9B550) store `[entity + 0x9C]` for entries indexed out of the global entity table
  `0x10480AF0` (`mov ecx, dword ptr [eax*4 + 0x10480af0]`; first one is `fild word [esi+8] × [0x1032a378]`, the
  second feeds a `call 0x8CD20`), and RVA **0x5E912** writes its own `+0x9C` beside fields +0x94/+0xa0..+0xac in a
  layout with no script record at +0x88. None of them feed the fetchers.

**Consequence for kuluu.** The ActorRotation duration law (§12) should carry this factor when it ever sees a
non-zero mode byte: authored frames × `ctx scale`, defaulting to 1.0 (shipped records are all mode 0, where the
duration is unused — so no behaviour change today). The ×0.7 gate needs an owning-context model kuluu does not
have yet (`kind ∉ {14,15}` and a `+0x1C` counter > 1 on that owner), which is why it is recorded rather than
ported.

### 14.6 The consumer of the pending pair, found (2026-10-05) **[V]**

§14.4 left one blocker: *which method composes facing from the `+0x61C..+0x628` angle set*. It is **OnMove**.

*Identification.* The candidate virtual `0xC817A` of §14.4 is not a separate method: it lies inside one function
body running **RVA 0xC63D0 .. 0xC83BA** (padded-body end; DancingMad's seed table has no start for `0xC817A`, which
is why the grep of `tables_functions.csv` missed it). `xref_vtable.py` answers where that body is installed:

    HIT: .rdata vtable 0x32D710 slot 8 (vt+0x08) -> 0xC63D0
    HIT: .rdata vtable 0x330F40 slot 8 (vt+0x08) -> 0xC63D0
    HIT: .rdata vtable 0x3313E8 slot 8 (vt+0x08) -> 0xC63D0

All three vtables are **264 slots** — the skeleton-actor class chain, whose slot `+0x08` is its per-frame update
(`OnMove`; DancingMad's census [web], corroborated here by body size and by what it drives). So pending-turn
consumption happens in the actor's own frame update, shared by three sibling classes: there is no separate
"compose facing" method to go looking for.

*The consumption law, byte for byte (0xC66BC..0xC67DA).* `esi` = actor:

    c66bc  8b 86 6c 08 00 00   mov  eax, [esi+0x86c]     ; §14.3 enable counter
    c66c2  85 c0               test eax, eax
    c66c4  0f 84 15 01 00 00   je   0xc67df              ; counter == 0 -> other path
    c66ca  d9 86 70 08 00 00   fld  [esi+0x870]          ; pending magnitude P = |d|
    c66d0  d8 1d d8 95 32 10   fcomp [0x103295d8]        ; vs 0.0
    c66dd  0f 85 67 08 00 00   jne  0xc6f4a              ; P <= 0 -> nothing queued, exit
    c66e3  d9 86 74 08 00 00   fld  [esi+0x874]          ; signed delta d
    c66e9  d8 86 20 06 00 00   fadd [esi+0x620]          ; acc(+0x620) += d
    ...                        wrap acc into +-pi        ; .rdata 0x329d30 (pi), 0x329d2c (~2pi), 0x329d28 (-pi)
    c6739  d9 86 74 08 00 00   fld  [esi+0x874]          ; (twice) -> |d| via conditional fchs on compare flags
    c6754  d8 ae 70 08 00 00   fsubr [esi+0x870]         ; rem = P - |d|
    c675a  d8 15 d8 95 32 10   fcom 0.0
    c6765  7a 6d               jp   0xc67d4              ; no second term -> straight to the clear
    c6767  d9 86 74 08 00 00   fld  [esi+0x874]          ; overshoot case: a SECOND add of +|d|
    c677e  d8 86 20 06 00 00   fadd [esi+0x620]
    c67ce  d9 05 d8 95 32 10   fld  0.0
    c67d4  d9 9e 70 08 00 00   fstp [esi+0x870]          ; clear pending magnitude (both paths)

The queued turn is applied to accumulator `actor+0x620` once per frame, wrapped into ±π with this layer's
approximate pi/2π pair, and the magnitude slot is cleared on both branches. When `P - |step| < 0` the extra term is that
**leftover** (`rem = P - |step|`), added with a sign chosen by comparing `[esi+0x874]` against 0 so it pulls the
accumulator **back**: net displacement in that frame is exactly `P` toward `sign(step)` — no doubling and no
cancelling (byte-level walk, including which branch adds `+rem` and which `−rem`: §15.6). The §14.3 enable-counter gate is
confirmed as the outer branch.

**Still open on this row** (so nothing here over-claims): what *reads* the three-angle set `+0x61C/+0x620/+0x624`
after composition. A raw byte census proved unreliable for this pattern (misaligned linear decodes produce false
hits), so the settling read is: walk each function-start-delimited body that touches those fields, starting from
this same OnMove body (`lea edi,[esi+0x61c]` at 0xC68A2 and 0xC6C84).

**Consequence for kuluu (D4).** The schema is dispatchable today: on a `0x62` stage store the pair and bump the
enable counter; in the actor tick consume exactly as above. What must not be invented is what the accumulator
*feeds* — until that read lands, wiring it yields state nothing renders, so kuluu holds.

## 15. Row D4 close-out: the orientation lock (stage `0x2F`), and what stage `0x62` really queues (re-read byte-for-byte in this build, 2026-10-06) **[V]**

Everything below was re-read from raw bytes in our own binary (`FFXiMain.unpacked.dll`, TDS `0x6A995428`); file
offset == RVA throughout. This section closes the two loose ends §14 left, corrects two sentences there (§14.3's
second stored operand, §14.6's overshoot), and adds one new fact set: who owns an actor's orientation and how a
routine takes that ownership away from the wire.

### 15.1 One jump table, four stage bytes, three sibling lock tasks **[V]**

§5a established the scheduler dispatch base **`0x5DC1C`** with `case = stage byte − 2`; cells hold absolute VAs
(little-endian). Re-read cells:

| stage | cell RVA | cell bytes | handler | object built | alloc | duration operand |
|---|---|---|---|---|---|---|
| `0x2E` | `0x5DCCC` | `6d c8 05 10` | **`0x5C86D`** | ctor `0x62310` (call @`0x5C8A8`) | `push 0x78` @`0x5C87C` | rounded |
| **`0x2F`** | `0x5DCD0` | `ba c8 05 10` | **`0x5C8BA`** | ctor **`0x624B0`** (call @`0x5C8F5`) | `push 0x78` @`0x5C8C9` | rounded |
| `0x59` | `0x5DD78` | `07 c9 05 10` | **`0x5C907`** | ctor `0x62650` (call @`0x5C942`) | `push 0x78` @`0x5C916` | rounded |
| **`0x62`** | `0x5DD9C` | `2c af 05 10` | **`0x5AF2C`** | companion ctor `0x60F80` (call @`0x5AF52`) | `push 0x78` @`0x5AF2E` | **unrounded** |
| `0x07` | `0x5DC30` | — | `0x5A280` | (§9's carrier row) | | |

The three lock handlers are byte-identical in shape (`0x5C8BA` shown; the other two differ only in ctor address):

    5c8ba  8b ce                mov  ecx, esi
    5c8bc  e8 af 5e 00 00       call 0x10062770         ; script-context self getter
    5c8c1  85 c0               test eax, eax
    5c8c3  0f 84 cd e3 ff ff   je   0x5ac96            ; no context -> stage is a no-op
    5c8c9  6a 78               push 0x78
    5c8cb  e8 70 17 00 00       call 0x1005e040         ; task alloc
    5c8d5  85 ff                test edi, edi
    5c8d7  0f 84 b9 e3 ff ff   je   0x5ac96            ; OOM -> no-op
    5c8dd  8b ce               mov  ecx, esi
    5c8df  e8 ac 1c 00 00       call 0x1005e590         ; duration fetcher (a ctx-scaled thunk, §14.5 family)
    5c8e4  e8 43 53 2b 00       call 0x10311c2c         ; ftoi_round
    5c8e9  50                  push eax                 ; integer frame count
    5c8ea.. 5c8f5              (ctx self again, then `push esi` = the actor) call 0x100624b0

**This closes §14.3's `[I]`:** the function §14.3 called "producer `0x5AF2C`, no direct callers" is simply
**the jump-table handler for stage byte `0x62`** (cell `0x5DD9C`). It was never a helper; and its companion's
duration reaches the ctor **unrounded** — the fetcher result is spilled with `fstp dword ptr [esp]` @`0x5AF46`,
overwriting the slot reserved by `push ecx` @`0x5AF43`, with no `ftoi_round` call before
`call 0x10060f80` @`0x5AF52`. The three lock tasks round; the turn companion does not.

### 15.2 Stage `0x2F` = *HoldRotation*: taking orientation away from the wire **[V]**

Ctor **`0x624B0`** (`ret 0xc`). The handler pushes three arguments before it (§15.1) and the body consumes them at
`[esp+4]`, `[esp+0x14]` and `[esp+0x18]`; exact arg *order* is not needed for this row and is deliberately **not**
asserted here:

    624c9  db 44 24 18         fild dword ptr [esp + 0x18]   ; duration int
    624d4  c7 07 00 c0 32 10   mov  dword ptr [edi], 0x1032c000     ; main vtable (.rdata)
    624da  d9 5f 74            fstp dword ptr [edi + 0x74]          ; remaining, float frames
    624dd  c7 06 e4 bf 32 10   mov  dword ptr [esi], 0x1032bfe4     ; sub-object at task+0x34
    ...
    624f2  e8 d9 91 fd ff       call 0x1003b6d0                     ; chain helper -> the actor object
    62502  8b 10               mov  edx, dword ptr [eax]            ; that object's vtable
    62504  6a 01               push 1
    62506  8b c8               mov  ecx, eax
    62508  ff 92 14 03 00 00   call dword ptr [edx + 0x314]         ; ACQUIRE orientation ownership

Tick **`0x62520`** (the scheduler's per-frame `update`). The quantum it consumes is the dt this layer has been
using throughout — global `0x1047BFA8`, field `+0xEB0`, whose sole writer is `0x69F90` storing the return of
`0x14CF0()` (joint.md J7), and M29 proves that getter returns integer counts of 1/60 s:

    62520  a1 a8 bf 47 10      mov  eax, [0x1047bfa8]
    62525  d9 80 b0 0e 00 00   fld  dword ptr [eax + 0xeb0]
    6252b  d8 69 74            fsubr dword ptr [ecx + 0x74]        ; remaining -= tick
    6252e  d9 51 74            fst  dword ptr [ecx + 0x74]         ; keep the remainder (no clamp)
    62531  d8 1d d8 95 32 10   fcomp dword ptr [0x103295d8]        ; vs 0.0
    ...              test ah, 5 / jp 0x62548                        ; remaining >= 0 -> NOT finished
    6253e..62547     call [edx + 0x18] with push 1                  ; finish the scheduler entry

Flag convention as recorded in movement.md §11d (`test ah,5` + `jp` ⟺ ST ≥ src, unordered folded in). So the hold
runs **exactly the authored frame count** and releases on the first frame whose subtraction pushes the remainder
strictly below zero; a remainder that lands exactly on 0 holds one more frame. Dtor **`0x62460`** releases
unconditionally, through the same chain helper `0x1003b6d0` @`0x62475` (`push 0` @`0x62487`,
`call [edx + 0x314]` @`0x6248B`), so a destroyed task never leaves the actor
owned.

The ownership pair, per class (slot numbers are **byte** offsets into the vtable, i.e. `call [edx+0x314]`; slot
*index* = byte/4):

| what | fn | bytes | meaning |
|---|---|---|---|
| predicate slot `+0x318` | **`0xA4A10`** | `8b 81 38 08 00 00 / c3` | `return [this+0x838]` — the refcount itself |
| acquire/release slot `+0x314` | **`0xD5460`** | `8a 44 24 04 / 3c 01 / 75 10 …` | arg==1 → `++[this+0x838]`; arg==0 and `[this+0x838] > 0` → `--`; any other arg no-op (`ret 4`). A nesting counter, not a flag. |
| destructor reset | in **`0xC5D95..0xC5DAC`** | `25 ff 7f ff ff` @`0xC5D9D`, stores @`0xC5DA6`/`0xC5DAC` | clears bit 23 of `[+0x840]` and zeroes `[+0x838]` (ebx = 0) |

Census of that pair (`xref_vtable.py` + direct table reads): exactly **7 vtables** carry
`(+0x314, +0x318) = (0xD5460, 0xA4A10)` — `.rdata 0x32D710`, `0x32E890`, `0x32ECB0`, `0x32F0D0`, `0x32F4F0`,
`0x330F40`, `0x3313E8`. Those are the skeleton-actor class chain whose slot `+0x08` is `OnMove` (§14.6), i.e. every
class that can consume a pending turn can also be held. Two other shapes exist for the same two slots:

* plain **`CXiActor`** table `.rdata 0x32CFE0`: getter **`0x826B0`** = `xor eax, eax / ret` (never owned) and
  acquire **`0x826C0`** = `ret 4` (no-op). A non-skeleton actor cannot be held and never queues a turn.
* table `.rdata 0x32EA50`: those slots are a **byte flag** pair at `[obj+0x8A7]` — getter `0xA4AD0`
  (`mov al, [ecx+0x8a7]; ret`) and setter `0xA4AE0` (`mov byte ptr [esp+4] -> [ecx+0x8a7]`). Different semantics;
  which class this is stays **[I]** (settling read: the ctor that installs `.rdata 0x32EA50`).

### 15.3 What a hold actually suppresses — the wire→actor orientation copy **[V]**

Per-entity update region (`esi` = entity, `[esi+0xA0]` = its actor):

    8fbc0  89 88 e4 00 00 00   mov  dword ptr [eax + 0xe4], ecx     \  wire rotation vec4 ->
    8fbc6  89 90 e8 00 00 00   mov  dword ptr [eax + 0xe8], edx      \  actor+0xE4..0xF0, from the
    8fbd4  89 88 ec 00 00 00   mov  dword ptr [eax + 0xec], ecx       | stack args, i.e. the wire value
    8fbde  89 90 f0 00 00 00   mov  dword ptr [eax + 0xf0], edx      /
    8fbea  8d 44 24 34         lea  eax, [esp + 0x34]              ; wire position
    8fbee  81 c1 c4 05 00 00   add  ecx, 0x5c4                     ; actor+0x5C4
    8fbf6  e8 95 72 f9 ff       call 0x10026e90                    ; memcpy(dst, src) - UNCONDITIONAL
    8fc06  8b 17               mov  edx, dword ptr [edi]           ; actor vtable
    8fc08  ff 92 18 03 00 00   call dword ptr [edx + 0x318]        ; owned?
    8fc0e  85 c0               test eax, eax
    8fc10  0f 85 e0 00 00 00   jne  0x8fcf6                        ; -> skip BOTH the copy and the wraps
    8fc1a  8d 9f 1c 06 00 00   lea  ebx, [edi + 0x61c]             ; actor+0x61C (rendered orientation)
    8fc22  e8 69 72 f9 ff       call 0x10026e90                    ; memcpy(actor+0x61C, &wire quat)
    ...                     ±pi wrap of each component            ; .rdata 0x329d30 (pi), 0x329d2c (~2pi), 0x329d28 (-pi)

So `HoldRotation` freezes **the copy into `actor+0x61C..+0x628`**, while the wire values keep landing in
`actor+0xE4..+0xF0` and position keeps landing in `+0x5C4`. Which other code consumes `+0xE4..+0xF0` stays **[I]**
(settling read: field census on that triple/quad inside the actor-update body).

### 15.4 The accessors §14.3 called "unnamed" are per-class pointer getters **[V]**

| slot (byte) | skeleton-actor chain (7 tables above) | plain `CXiActor` `.rdata 0x32CFE0` | what it returns |
|---|---|---|---|
| `+0x1BC` | **`0xA4740`** = `8d 81 fc 05 00 00 / c3` → `lea eax,[ecx+0x5fc]` | **`0x820E0`** = `lea eax,[ecx+0x34]` | pointer to the object's position triple |
| `+0x1C0` | **`0xA4750`** = `8d 81 1c 06 00 00 / c3` → `lea eax,[ecx+0x61c]` | **`0x820F0`** = `lea eax,[ecx+0x44]` | pointer to the angle record (§13's record) |

Two consequences. (a) §14.3's bullet "an unnamed factor: value from vtable `[ebx+0x1BC]` scaled by
`fmul [0x1032A9F4]`" was a **mis-read**: `call [edx+0x1bc]` yields no number to scale — it is the position-getter,
and the thing scaled at `.rdata 0x1032A9F4` comes from the script record (§15.5). (b) ActorRotation (§13/§14, on
plain `CXiActor`) and stage `0x62` (on the skeleton actor) measure angles through **the same accessor numbers on
two different classes**; both angle records live side by side on the skeleton actor (`lea esi,[obj+0x61c]` seeded
next to `[obj+0x44]`, §14.3).

### 15.5 What stage `0x62` computes at fire time (producer body re-read, `0x5AF2C..0x5B0C8`) **[V]**

*Task + enable counter.* `push 0x78; call 0x1005e040` @`0x5AF2E`; companion ctor **`0x60F80`** stores the
duration as a raw dword (`mov ecx,[esp+0x18] / mov [esi+0x74],ecx` @`0x5AF99-0x60FA1`) with vtables
`.rdata 0x32BC3C / 0x32BC68`; the companion dtor **`0x60F40`** releases through `push 0` @`0x60F44`,
`call 0xd5490` @`0x60F5E`; its tick **`0x60FD0`** is the same countdown shape on field `+0x74`, finishing only when
the remainder goes strictly negative. The enable bump is a *direct* call —
`push 1; mov ecx, edi; call 0xd5490` @`0x5AF7D` — and **`0xD5490`** is the sibling of `0xD5460`: identical shape,
field `[this+0x86C]`. So ownership uses the vtable slot (`0xD5460`, field `+0x838`) while the turn-enable uses the
free function (field `+0x86C`): two counters, never conflated.

*Objects.* self = ctx getter **`0x10062770`**, object to face = ctx getter **`0x100627D0`**; either null →
branch to `0x5AC96`, nothing stored (§14.3's claim, confirmed).

*Geometry.* Three pairs of `[vt+0x1BC]` calls per object — the middle pair's result is discarded (compiler
artifact; no third record exists) — giving one direction vector:

    5af98  d9 45 00            fld  dword ptr [ebp]        ; other.x   (record+0)
    5af9b  d8 20               fsub dword ptr [eax]        ; - self.x      => dx -> slot esp+0x3c @0x5AFA1
    5afcb  d9 43 08            fld  dword ptr [ebx + 8]    ; other.z   (record+8)
    5afce  d8 60 08            fsub dword ptr [eax + 8]    ; - self.z      => dz -> slot esp+0x44 @0x5AFD1

*Degenerate guard, as written.* `fld dx; fcomp [0x32a378]` (= `.rdata 3d cc cc cd` = **exactly 0.1f**),
`test ah,5`, `jp skip`; then the same compare for `dz`. Substitution happens only when **both** are below 0.1:

    5aff7  c7 44 24 3c 00 00 80 3f   mov dword ptr [esp + 0x3c], 0x3f800000   ; dx := 1.0
    5afff  c7 44 24 44 00 00 00 00   mov dword ptr [esp + 0x44], 0             ; dz := 0.0

Recording honestly: the comparisons are *signed* (`jp` ⟺ ST ≥ src, §11d), so this guard fires whenever both
components are merely **less than** +0.1 — an object due south-west at several yalms satisfies it too and would be
aimed at heading 0 rather than skipped. Whether that is retail's intent or a slipped `fabs` needs the class behind
`0x100627D0`: **[I]**, settling read = identify that class and what its `[vt+0x1BC]` record holds (position vs a
unit direction).

*Angle.* Helper **`0x5DFF0`** = `fld [esp+4]; fld [esp+8]; fpatan`; with the callsite pushing `dx` @`0x5B015` then
`dz` @`0x5B01F`, that is **atan2(dz, dx)**, negated at `0x5B02E` (`d9 e0`) ⇒ `want = −atan2(dz, dx)`, the same sign
convention as M10's facing law. It is then differenced against the *accumulator*:

    5b036  ff 92 c0 01 00 00   call dword ptr [edx + 0x1c0]     ; self angle record (-> actor+0x61C)
    5b040  d8 60 04            fsub dword ptr [eax + 4]         ; diff = want - acc(+0x620)
    ...                    single ±pi wrap with the same triple

*The two stores — this is what §14.3 got wrong.* `fabs(diff)` goes through setter **`0x5E7C0`** (`mov [ecx+0x870], eax`)
at call site `0x5B08F`. The second store is **not the signed Δ**:

    5b007  8b 8e 88 00 00 00   mov  ecx, dword ptr [esi + 0x88]      ; current script record
    5b016  d9 41 08            fld  dword ptr [ecx + 8]              ; authored float at record cursor +8
    5b019  d8 0d f4 a9 32 10   fmul dword ptr [0x1032a9f4]           ; this layer's pi/180: bits 3c 8e f9 21 = 0.017452778
    5b020  d9 5c 24 1c         fstp dword ptr [esp + 0x1c]           ; scratch (rate, radians/frame)
    ...                    sign-select against diff vs 0.0 (@0x5B094..0x5B0AB: fabs/fchs idiom)
    5b0af  8b 44 24 14         mov  eax, dword ptr [esp + 0x14]
    5b0b6  e8 15 37 00 00       call 0x1005e7d0                      ; -> [ecx + 0x874]

So **`actor+0x870 = |diff|` (how far) and `actor+0x874 = authored rate in radians/frame, signed toward the target`**
(how fast). Both setters have exactly one caller each (`xref.py --to 0x5E7C0 / 0x5E7D0`: 1 reference apiece, both
inside `0x5AF2C`), and the only other writers of those two fields in this class are constructor/initialiser blocks
— `0xC628D/0xC6293` (immediately after `[+0x86C] ← 0` @`0xC6287`, in the same block that zeroes `+0x858..+0x8B6`) and
a second init at `0xAC960/0xAC966`. Same-offset hits in `0x156D32…`, `0xACBBD`, `0xAD3xx` and `0x220010` are other
classes (no script record, int operands), excluded.

*Nuance for §14.5.* The duration goes through the ctx-scaled fetcher family (`call 0x1005e590`, one of §14.5's
thunks) but this authored **angle** operand is read straight from the record and multiplied only by π/180 — it does
**not** carry the `ctx+0x9C` factor. §14.5's "angles scaled as well" wording should be read as frame counts scaled;
stage `0x62`'s rate is not scaled. **[V]**

### 15.6 Consumer law re-read — §14.6 confirmed, its overshoot sentence corrected **[V]**

The four gates are at `0xC6693..0xC66C4`, in this order (`esi` = actor, `eax` = its vtable):

    c6693  ff 90 18 03 00 00   call dword ptr [eax + 0x318]     ; owned by a HoldRotation?
    c6699  85 c0 / 0f 85 a9 08 00 00   test/jne 0xc6f4a         ; -> no turn consumption at all
    c66a1  8a 86 02 01 00 00   mov  al, byte ptr [esi + 0x102]
    c66a7  84 c0 / 0f 85 9b 08 00 00   test/jne 0xc6f4a         ; -> skip
    c66af  83 be a4 07 00 00 ff cmp  dword ptr [esi + 0x7a4], -1
    c66b6  0f 85 8e 08 00 00   jne  0xc6f4a                     ; -> skip
    c66bc  8b 86 6c 08 00 00   mov  eax, [esi + 0x86c]          ; turn-enable counter (§15.5)
    c66c2..c66c4 test / je 0xc67df                              ; 0 -> the M27 turn-toward branch

The arithmetic tail (`0xC6739..0xC67DA`, verbatim from this build):

    c6739  d9 86 74 08 00 00   fld  [esi+0x874]                 ; step
    c673f  d8 1d d8 95 32 10   fcomp [0.0]                       \
    c6745  d9 86 74 08 00 00   fld  [esi+0x874]                   | fabs(step) via conditional fchs
    c674b..c6752 fnstsw / test ah,5 / jp / fchs                  /
    c6754  d8 ae 70 08 00 00   fsubr [esi+0x870]                ; rem = P - |step|      (FCOM does not pop)
    c675a  d8 15 d8 95 32 10   fcom  0.0                        ; rem vs 0
    c6765  7a 6d               jp   0xc67d4                     ; rem >= 0 -> straight to the clear, NO extra term
    c6767  d9 86 74 08 00 00   fld  [esi+0x874]                 ; overshoot path: step vs 0 ...
    c677c  d9 e0               fchs                             ; ... so the leftover is negated for step < 0
    c677e  d8 86 20 06 00 00   fadd [esi+0x620]                 ; acc += (rem or -rem)
    ...                    second ±pi wrap of acc
    c67ce  d9 05 d8 95 32 10   fld  0.0
    c67d4  d9 9e 70 08 00 00   fstp [esi+0x870]                 ; clear pending magnitude (both paths)

**Correction of §14.6's sentence "a positive overshoot doubles its contribution, a negative one cancels".** There is
no second add of `+|d|`: the extra term is the **leftover `rem = P − |step|`**, added with the sign chosen so it
*subtracts from* the travel. Net displacement in that frame is exactly **P** toward `sign(step)` — no doubling, no
cancelling: acc entered the frame at `h0`, got `+ step` (`= s·m`, `m > P`) at `0xC66E9`, then receives
`s·rem = s·(P − m)`, giving `h0 + s·P`. kuluu matches this by construction (its test asserts exact-P landing).

### 15.7 Consequences for kuluu — what landed, and what stays **[I]**

Landed (`kuluu jw-stack-815 01fb6e42`, paired with this section): stage `0x2F` → `StageKind::HoldRotation` (an
orientation hold that suppresses the wire→orientation take, counting authored whole frames and releasing on
destruction as well as at zero); stage `0x62` → `TurnToward`, arming `{remaining = |diff|, step = authored
degrees × this layer's π/180 signed toward the target}` plus an enable window from the companion countdown,
consumed in the actor tick with integer-frame stepping and the exact-P back-off, no easing.

Four kuluu-side modelling choices in that commit are **not** proven by retail bytes and must be read as such:

1. The hold applies to remote actors only (`PredictSample::orientation_hold_frames`); a local player's facing has
   no wire→orientation copy of its own to skip, so there is nothing for the hold to suppress. If the DL's local
   path turns out to share that copy, this is wrong — settling read: `0x8FBB1..0x8FC22` reached from which entity
   kinds.
2. Overlapping holds extend one countdown float instead of nesting a refcount. Retail nests (`[+0x838]++/--`,
   floor 0); the observable difference is only for two concurrent `0x2F` stages on one actor.
3. The enable counter is modelled as a list of companion countdowns (one per firing). That *is* what retail has —
   one companion task per `0x62` with its own `+0x74` — but each firing also **overwrites** the pending pair, which
   kuluu reproduces; consumption requires the list non-empty rather than a counter > 0.
4. Step accumulation counts whole retail frames (30/s at the default cap) rather than scaling by wall time, in
   line with this layer's other authored-per-frame laws (`zone_sfx`, `zone_clouds`). Consequence: kuluu is
   frame-rate independent where retail-at-60 fps would run the same turn twice as fast. Whether retail intends
   that follows from the quantum itself (M29: integer counts of 1/60 s, `2.0` per frame at the default cap), which
   is already recorded — so this choice makes kuluu match retail-at-30-fps behaviour at any refresh.

Still open on this row (unchanged by §15): who *renders* facing from `actor+0x61C..+0x628` (§14.6 "still open").
§15.4 shows the accessor hands out a pointer to that record and §15.3/§15.6 show its writers, but no consumer was
found that composes a world orientation from it — kuluu lands the value on its own facing-field chain, and that is
a kuluu choice, not a proven-identical landing site. Also open: `[actor+0x102]` and the third writer of
`[actor+0x7A4]` (§14.3), both left at their constructor values in kuluu with these names as the settling reads.

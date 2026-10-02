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

**Arg-slot mapping — mostly resolved; one slot unexplained [V/I].** Frame arithmetic rule (I got this
wrong on the first pass and corrected it): args sit at `entry esp + 4, +8, …`; inside the body, after
the ctor's own four pushes (`push ebx/esi/edi` + `push eax` = 0x10 bytes), an arg at entry offset *A* is
read at **body `esp + A + 0x10`**.

| entry slot | handler source | read in body at | lands in |
|---|---|---|---|
| +0x4 | `esi` (scheduler/script ctx) | `mov eax,[esp+4]`; `mov edi,[esp+0x14]` | passed to base ctor; also used as the object of virtual `[vfx+0x1C0]` |
| +0x8 | result of `lookup_62770(ctx)` | `mov ecx,[esp+0x18]` | **`[task+0x7c]`** — consistent with the update loop's null-test on that field ✔ |
| +0xC | `(int)byte[record+0x14]` | — (not located) | **unexplained** |
| +0x10 / +0x14 / +0x18 | `record[+8] / [+C] / [+0x10]` | one is read with `fild` (`dword`→integer) for `[+0x74]/[+0x78]` | start/duration-ish fields |
| +0x1C | `_ftoll(authored word × [ctx+0x9c])` | — (not located) | **unexplained** |

The three values converted by π/180 are read in the body as `fld dword [esp+0x1C]` (twice → `[+0x90]`,
`[+0x94]`) and `fld dword [esp+0x20]` (→ `[+0x98]`). Under the frame rule those correspond to entry
slots **+0xC** and **+0x10**. +0x10 is a record field (fine, float), but **+0xC is the zero-extended byte
from `record[+0x14]`**, which cannot legitimately be loaded as a float. So **exactly one mapping is
still wrong somewhere** — likely my assumption that every push at 0x5B41D..0x5B429 belongs to this ctor,
or that the byte at `record+0x14` is really a byte field (it may be two bytes: mode + something, or the
pushed register is not what I paired it with). **Do not use arg-slot identities in kuluu code until that
single inconsistency is closed.** Cheapest closers: simulate the handler's stack mechanically against the
task fields after construction (live debug), or read member names from PS2 DWARF / DancingMad's
reconstruction instead of inferring offsets.

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

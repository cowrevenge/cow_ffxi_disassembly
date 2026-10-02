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

## 6. What this pass still does NOT know [O]

1. **Which bone index is "the head"**, and who supplies that index to `sqmdModelLookAt`. The
   error string proves a boneNdx parameter; the caller set is not yet traced.
2. **Who constructs** `CMoLockLookAtDriveTask` / `CMoActorRotationDriveTask` (construction sites
   0x5F476/0x5F47F and 0x5FA49/0x5FA4F store the vtables; their *callers* — i.e. the lock-on logic
   that decides "now look at it", with what duration/mode/degrees — are unread). **This is where
   the limit, slew and tug values will actually appear as arguments.** Next dig.
3. `sqmdModelLookAt`'s body (function start not yet pinned; only its error tail at 0x2790A2 is known).
4. Whether the +0xE4…+0xF0 pair-writes are joint angles or a different record (§4 caveat).
5. `CMoLockLookAtDriveTask::update` (region 0x5F540…) computes progress-like values by comparing
   `[esi+0x78] − obj->field` against 0.0 and 1.0 via virtual `[obj->vfx+0x1BC]`; the semantic of
   that field (duration? distance?) is unresolved.
6. Mixer behaviour (`sqmoMixerMotion`) — needed for the idle↔walk seam — untouched.

## 7. Reproduce [V]

The scripts are committed under [`tools/`](../tools) (the DLL itself is **not** in this repo;
point `open('FFXiMain.unpacked.dll')` at your own working copy, or run from that directory):

- `rtti_graph.py` — parse `{name,size,parent}` descriptor records; resolve parents.
- `find_vtbl2.py` — locate vtables by scanning for pointers to the `mov eax,desc; ret` thunks
  (**remember: file offset == RVA**; do not add ImageBase when indexing the buffer).
- `dt_consts2.py` — constant + sink scan over a code range (regex on `\[(0x…)\]`, not token split).
- `who_makes_tasks.py` — group `.text` references to a `.rdata` table range by target.

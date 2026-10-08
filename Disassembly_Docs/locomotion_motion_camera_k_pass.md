# Locomotion motion-name chooser + chase-camera lock handling (K pass)

2026-10-08 against `artifacts/FFXiMain.unpacked.dll`, TDS **0x6A995428** (= PhoenixXI install, md5
fb7464073c06489268fdd9215c3e5313). Raw listings: `C:/tmp/lock_research/{selector,wider,motionchooser,deep,chain,cam2,windows,leash,close,ctor,keys,pred,bc,sem,rawget,f_w1_20844,f_w2_210ae,f_w3_217cf,f_setter_1e760}.txt`.
Conventions/tiers: [../README.md](../README.md). Cross-refs: [movement.md](movement.md) (M5/M17/M30/
M32/M34/M35), [target_track.md](target_track.md) (T1/T8/T14/T15).

**OWNER VERDICT 2026-10-08.** The kuluu laws landed from this pass — side-step buckets + flip latch
(`f1bfd06`), locked-camera cone framing / L/R start / lateral leash (`ca907f4`, `a129728`), lock not
rewriting free cam, mid-blend clip requests, 16-tick in-step gait blends (`18d870b`, `e8b7af3`) —
were **playtest-accepted by the owner**: "it all lands, and it's great." Do not disturb these laws
without new owner instruction. Exception on hold: `anchor_bias_y` pivot quantiser (§K3 port,
commit `d5b7a73`) is **HOLD** — owner not 100% on framing height yet; leave as landed.

## K1. The motion-name chooser 0xC8BB0..~0xC8E58 **[V(me)]**

`switch (call 0x84390)`, where **0x84390 = [[obj+0x70]+0x170]** (Status word). `dec eax; cmp eax,0x52;
ja default`; byte table 0xC8E74 + jtable 0xC8E58, seven entries:

| status | body | writes |
|---|---|---|
| 0x52 | 0xC8BE5 | `[esi+0x7d4]` (bank slot copy) |
| 0x53 | 0xC8C36 | `cor ` |
| 0x54 | 0xC8C60 | `fh1 ` |
| 0x55 | 0xC8CD0 | `rx1 ` |
| 0x56 | 0xC8C83 | `si1 ` |
| 0x57 | 0xC8CA9 | `ci1 ` |
| other | falls through to the locomotion tail | |

Locomotion tail fourcc stores: **`mvl ` 0xC8DAF**, **`mvb ` 0xC8DB7**, **`mvr ` 0xC8DBF**, `wlk ` 0xC8DD8,
plus a self-patching `'jmp'` word at 0xC8E04. Every directional store is gated on one field only:

```
0xC8D9E mov eax,[esi+0x598] ; sub 2 -> je mvr(0xc8dbf) ; dec -> je mvb(0xc8db7) ; dec -> jne skip, else mvl(0xc8daf)
        (mount siblings 0x84350/0x84370 passing jump to the `wlk ` arm at 0xc8dc7)
```

## K2. Actor +0x598 write census — buckets {0..4} are LIVE; side-step clips play while locked **[V bytes]**

**CORRECTION 2026-10-08 (supersedes this section's original claim).** The original version of §K2
concluded from the +0x598 store census that classifier buckets 2/3/4 were "unreachable" and that
therefore *no actor ever plays a side-step clip*. That was wrong: the gating tests in classifier
**0xA80D0** are `fnstsw ax; and eax, 0x100` — x87 status **bit 8 = C0**, the *less-than* condition per
Intel's FCOM comparison table, not an overflow flag. Comparisons set it, the branches are live, and
the chooser consumes the full bucket set whenever free-run is off (every lock handler sets that,
0xC5440/0xC54C0). See [target_track.md](target_track.md) header correction + §3 truth table for the
classifier itself.

Whole-`.text` scan for displacement +0x598 → 15 sites; stores are exactly seven and each value is
pinned by its own body:

| site | value |
|---|---|
| 0xA8A4D (ctor, `xor ebx,ebx` at 0xA89FD) | **0** for every actor, local or remote |
| 0xA65B3 / 0xA6C05 / 0xA7319 | `ebp`, the 0 sentinel those bodies compare with (`cmp [esi+0x70], ebp`) and pass to StopAutoRun |
| 0xA7F23 (side-flip latch) | literal **1** — straight-gait frames only, see law below |
| 0xA6EE4→0xA6EE9, 0xA7EF1→0xA7EF9 | return of the bracket classifier **0xA80D0**: buckets **{0,1,2,3,4}**, all reachable (T15 corrected) |

**Flip latch law, exact (0xA7EF6..0xA7F2D).** Consecutive travel buckets forming {2↔4} (direct
right→left or left→right reversal) set `[esi+0x5b1] = 2`; while that byte > 0, each pass stores the
literal **1** into +0x598 and decrements — two rendered frames of straight gait on a direct A/D flip.
Bucket → clip via §K1's chooser: 2→`mvr `, 3→`mvb `, 4→`mvl `.

⇒ sideways travel runs the **side-step clips while locked** (free-run off), with the two-frame
straight-gait bridge on direct reversals. kuluu landed this law in commit `f1bfd06`
(`ffxi-actor::SideStepFlipLatch` + chooser states); it also deleted kuluu's torso-reconciliation
layers, which have no retail counterpart.

## K3. The following-camera resolves the lock itself — pivot bias from attach-record nodes **[V bytes / I which status picks]**

`0x1F25A..0x1F440`: `call 0x157CF0` on `[0x1057876C]` = LockedTarget(g_pInputMng), fallback entity slot
`*0x487F58` via `0x81600`; compared with self, whole block gated by vt+0x330 (IsFreeRun). Fetches an
object through **vt+0x3CC(1)** → **0xCFB00** and **vt+0x3C8(1)** → **0xCFAD0** (static `0x1048A390` when
the predicate reports nothing). Those slots come from the PC-actor vtable at **0x32D710**
(`+0x19C→0xA46F0`, `+0x330→0xA4670`, `+0x334→0xA4660`).

The getters return a node from the **actor +0x674 attach-point container** — the same object used by
the whole `0xCEC9D…0xD5F30` attach family (known attach RVAs 0xD45B9/0xD4861/0xD4AE8/0xD5B18).
`0x2B5A0` is the intrusive-list head accessor (`lea eax,[ecx+0x44]; ret`); `0x2B5B0/0x2B5E0` list
begin/end. The predicate **0xCFB40** switches on Status (byte-map 0xCFBD0, jtable 0xCFBC0, one case
`cmp eax,0x3e`) and picks an element via `lea edx,[edi+edi*2]; lea eax,[eax+edx*8]` — index × **24-byte
records**; the mount siblings `0x84350/0x84370` shift the index. Callers read six floats per record:
`(+0,+4)`, `(+8,+C)`, `(+10,+14)`. The camera consumes `(obj[4] − obj[0]) × 0.6` as an anchor-height
bias (quantiser: tested against **2.5** at 0x329ea0, forced to **4.0** when not below; applied at
0x213A8/0x1F432 against the default `[cammgr+0x54]`), and the other two pairs as extents at 0x20327.
So the pivot bias is a *height* law driven by attach-node vertical span.

**Status → element-index map (K5 item, closed).** Predicate `0xCFB40`: `edi = 0`; read Status via
`call 0x84390`; if `Status > 0x3E` go to the mount-check body; else `byte = bytemap[Status]` (.data
0xCFBD0) and switch on it (jtable 0xCFBC0): byte **0 → idx 0** (body 0xCFB5F), **1 → idx 1**
(0xCFB90), **2 → idx 2** (`mov edi,2` at 0xCFB63), **3 → mount-check body** (`call 0x84350(status)`
or `call 0x84370(status)` true ⇒ idx 1, else idx 0). Bytemap for Status 0..62 verbatim (index =
status):
```
byte 0 (idx 0)          : statuses 0, 4, 7, 28, 31
byte 1 (idx 1)          : 1, 6, 38..43, 50..53, 56..62
byte 2 (idx 2)          : 2, 3
byte 3 (mount-check)    : 5, 8..27, 29, 30, 32..37, 44..49, 54, 55   and all Status > 62
``` The element is picked as
`node[idx]` with stride 24 (`lea edx,[edi+edi*2]; lea eax,[eax+edx*8]`).

**Pivot-bias formula, exact (K3 law body).** Consumer at `0x1F392..0x1F446` (pivot vec in this
function's locals, seeded from the actor position copy at 0x1F30A/0x1F319 — via vt+0x1BC):
```
h_span = rec[+4] − rec[+0]                       ; first pair of the attach-node record (vt+0x3CC(1) normal / vt+0x3C8(1) mount)
if (vt+0x14C(actor)) and h_span < 2.5 → h_span = 4.0   ; 0x1F3BD..0x1F3D4 (.rdata 0x329ea0=2.5; imm 0x40200000 store)
if (actor+0x768 != null) → h_span += getter(obj+0x878 via 0x223B0)   ; mount/rider extra height
pivot_component -= h_span × 0.6                  ; fmul .rdata 0x329a30; fsubr against the pivot slot — applied against
                                                 ; the camera manager's own stored anchor ([cammgr+0x54], written on rec==NULL)
pivot base = actor position when vt+0x330 (IsFreeRun) true, target object's position otherwise (0x1F44B uses ebp=LockedTarget)
```
Which in-frame component slot the scalar lands on is **[I]** (push-offset noise; semantics "pivot
height" agree at both consumer sites 0x1F432/0x213A8). `vt+0x14C` predicate identity **[I]**.

**kuluu port (landed).** `anchor_bias_y(span)` in `kuluu-render/src/camera.rs`: quantiser
(<2.5 → forced 4.0, always-on since vt+0x14C gates it in retail) × 0.6, fed from the DAT-measured
`BakedActor::actor_height` (max_y − min_y of model mesh records) as the data-driven stand-in for
the node's first-pair span — replaces the previous `× 0.55` empirical factor.

## K4. Eye-vs-anchor distance band [3.0, 6.0] yalms — soft spring pair written straight to the eye **[V(me)]**

The chase-camera body is one function, **0x1EE60..0x20B9B** (ret 4; arg = actor `esi`; returns early
unless a type predicate at 0x1EE9D/0x1EEB1 excludes token `0x10330EBC` (CXiSkeletonActor) and admits
the other class, with mode byte `[0x104568FC]+9` skipping the gate). The re-anchor loop starts at
**0x1FA34**, iterates a per-camera point list `[cam+0xbc]` (count via **0x311C2C = round-to-nearest
int(float)**, *not* a size getter), and each pass recomputes

```
d = | eye − anchor point |       ; eye = &cam+0x44 (`lea ebp,[edi+0x44]` 0x1FA74);
                                 ; sqrt-of-dot at 0x1FDFB..0x1FE00 (helper 0x27530 dot)
```

then eases d toward the band **[3.0, 6.0]** and writes corrected positions through **0x1E760** —
a twelve-byte setter whose body is `add ecx,0x44; copy3` (**writes cam+0x44/+0x48/+0x4C = the eye
position itself**, 0x1E760..0x1E771):

```
0x1FD32 fcomp [6.0]                     ; d beyond outer bound (and ≤ 100, else snap-recovery
0x1FD45 fsub [6.0]; fmul [0.012]        ;   branch at 0x1FD03 uses ([esp+0x14] − 100) × 0.5):
0x1FD5A call 0x272B0 (v *= k); 0x26F20 add; 0x1E760 → eye   ; pull-in, +k along the deficit
0x1FD79 mov al,[esp+0x17]               ; gate byte — see bug note below
0x1FD89 fcomp [3.0]
0x1FD96 fld [3.0]; fsub d; fmul [-0.125];   d inside inner bound:
0x1FDAF call 0x272B0 → 0x26F20 → 0x1E760     ; push-out, opposite sign on the same vector family
0x1FDCE mov [0x456D74], ebx             ; arms hold-off counter (ebx=10 armed at 0x1FA4A;
                                        ;   [0x456D7C] −= 1.0 per pass, 0x1FA55)
```

Outer ease is unconditional on the loop path; it runs every pass while d > 6 (≈ +0.36/s of the
deficit in continuous time), which is what "the retail leash feels large" is: beyond 6 yalms the eye
creeps back at ~3 %/s/frame-equivalent, taking seconds — no hard cut except the absurd-distance
(d > 100) recovery branch.

**Gate-byte bug [V].** The inner push-out reads a local byte `[esp+0x17]` (0x1FD79) that **has no
writer anywhere in the function**: the only store is a clear-to-0 at **0x1FA2B**, taken when the
scene world query (`call 0x1815B0` on object `[0x631F24]`, sites 0x1FA22/0x1FF29, line-of-sight style)
fails. So retail arms the push-out from an **uninitialized stack slot ∧ LOS pass** — a genuine
retail-binary bug (undefined local). kuluu implements it as deterministically armed while locked.

**Action 0x91 [V/I].** `push 0x91; call 0x193850` → thin wrapper on input manager `[0x106626CC]` →
`call 0x195330(id)` (0x195330..): `record = 0x1954D0(id)` computes an **array slot** (`[mgr+4] +
id·44`, stride verified from the 0x2C walk in 0x1954F0's init loop, `cmp ecx,0xcf` ⇒ exactly **207
records**, no existence test — returns NULL only when the registry base itself is missing, in which
case −1), then reads the record's current-state dword `[record+8]`. Action id 0x91 has gate word
0x0001 but **no raw/composite device getter** (census: getters 0x1036D0D8/0x1036DB18, masks
0x1036CF60) ⇒ the per-frame device evaluators (which drive `[rec+8]`-adjacent state through those
tables) never touch it.

**CORRECTION 2026-10-08 (second pass).** This section originally asserted "nothing ever writes that
slot, block provably dead". That was an overclaim: a follow-up census of the registry bodies found
**many stores into `[record+8]`** — mirror/sync loops over explicit record ranges (e.g. 0x195B07..0x195B4D
walks records to offset 0xa50 in 0x2C steps copying local/computed values and `[rec+0x20]` into +8;
at 0x195B79 the body even stores **the return of `push 0xAB; call 0x193850`** into a kind-pinned
record's +8, with observers notified through 0x193BC0). So the state word is writable by event-side
mirrors, not only by input. What remains true: id **0x91 has no device getter**, so it can never be
"pressed", and whether any of those mirror loops covers record index 0x91 is **[I]** (their kind pins
and range heads are unread). Treat the anchor-re-seed block **0x1FAB5..0x1FB3B** as *possibly live*
in retail, not provably dead.

Block content for when it runs: on `point−eye` components x or y ≥ ε (eps 0.01 at .rdata 0x329A18),
re-seed the anchor global `[0x10456D90] = actor position` (`vt+0x1BC`) and set countdown
`[0x10456D8C]=4`; otherwise while the countdown ≠ 0, feed the stored anchor into the pass. The
anchor globals themselves stay confined to their own init (0x1E655/0x1E66D) + this block (whole-region
scan 0x1E000..0x23000 — that part of the original census holds). Not ported as-is; kuluu's locked
camera instead frames both actors from a cone with lateral leash in commit `a129728`
(`kuluu/src/view_native/locked_camera.rs`), which reproduces the observed retail behavior (lock
starts L/R of the player, big elastic radial leash).

**Re-anchor point list `[cam+0xbc]` (K5 item, closed).** Exactly three sites take its address —
consumers `0x1F67D`/0x1F727 and the seeder `0x1FF39`. Seeder body at `0x1FF2E..0x1FF44`: when the
scene world query `call 0x1815B0` (object `[0x631F24]`, args candidate vector / &eye / point) returns
false, **the tested anchor is appended to the list**: `push point; push 1; lea ecx,[cam+0xbc]; call
0x1E320` (adder). Consumer at `0x1F667..0x1F723`: per index it fetches a point through accessor
`call 0x1E3B0`, forms the vector **point − eye** (`call 0x27120`, arg order verified), and if their
distance exceeds eps (`.rdata 0.05` @0x32a3e0 test at 0x1F6B0) glides the eye toward it by a clamped
step (`0x272E0` with `×⅓`, factor `0x3d4ccccd`) before the setter writes cam+0x44 — an additional
slow creep distinct from the band springs. `[cam+0xf0]`: byte flag set to 0 on ≤0.05 arrival
(0x1F6F7), compared ≥4 at 0x1FF52 (meaning [I]).

**Band-tail direction, settled structurally.** The same function family's other consumers form the
vector as `point − eye` (`0x1FA8C`, `0x1F69D`: verified arg order via callee bodies at 0x27120), and
the outer factor is positive every unconditional pass — so pull-in (d>6) / push-out (inner, negative
factor) on that vector. kuluu's `band_spring` implements exactly this pairing.

**Vertical-separation latch (fixes movement.md §11c's "azimuth reflection").** Three function tails —
`0x20B6C..0x20B81`, `0x210AE`'s at 0x2126F, `0x217CF`'s at 0x218D7 — store `[0x10456D78] =
|cam+0x48 − cam+0x54|`, i.e. **the eye/look-at vertical separation** (fchs-fold of the same fields the
loop owns), read back at `0x1FECD..0x1FEE5`: when the current |Δ| falls below the stored value, cam+0x48
is shifted by (|Δ| − stored) — maintaining a once-established vertical eye/look-at offset. Exact branch
polarity of that correction [I]; not ported in kuluu. It is **not** an azimuth reflection.

`.rdata 0x329d38 = 3.0` is used six times inside the body; 0x32a3e8 = 6.0 shared literal with the
focal-zoom step (M17/M34, separate uses). Other constants in the region: 0.5, 0.6, 0.99, 1.0, 1.5,
2.5, 4.0, 7.2 (0x32a3a8), 8.6 (0x32a3a4), 10.0, 100.0, focal 242/350/900.

**kuluu port (landed).** `band_spring` in `kuluu/src/view_native/camera_collision.rs`: exponential
form of the same law at λ_inner = −30·ln(1−0.125) = **4.0157/s**, λ_outer = −30·ln(1−0.012) =
**0.3622/s** (continuous-time equivalents of the per-tick factors at retail's ~30 fps tick, so
kuluu's higher frame rate makes it smoother, never faster), applied while locked; free-cam zoom
uncontested; settings leash clamp kept behind it as the user-dialed safety net.

## K5. Closed 2026-10-08 / remainder

Closed this pass:

* Status→element map: verbatim byte-map + switch bodies (§K3 addendum).
* `[cam+0xbc]` seed side: LOS-failed anchors appended via `0x1E320` at 0x1FF32..0x1FF44; consumed by
  the ≤0.05/tick glide loop at 0x1F667 (§K4 addendum).
* Action 0x91: registry-slot read semantics pinned (0x1954D0 stride-44 × 207 records / 0x195330);
    no device getter for id 0x91. "Slot never written" retracted — `[rec+8]` has event-side mirror
    writers (§K4 correction, second pass); whether one covers record 0x91 stays [I].
* Band-tail sign pairing settled structurally (§K4).
* Anchor-height law ported to kuluu (`anchor_bias_y`, camera.rs) with quantiser + 0.6 from bytes.

Still open (none gate shipped behaviour):

* Record-index 0x91 coverage by the `[rec+8]` mirror loops (kind pins/range heads of 0x195B07.., 
  0x195C.. bodies unread) — decides whether retail's anchor-re-seed block ever runs.
* Actor predicate vt+0x14C identity (gates the <2.5→4.0 force in retail).
* Which pivot component the scalar lands on at byte level (push-offset noise; both consumers agree
  semantically on height).
* `[cam+0xf0]` byte semantics (arrival flag cleared ≤0.05, compared ≥4 for latch [0x10456D70]).
* Branch polarity of the vertical-separation latch correction ([0x10456D78] read site).
* Whether any non-`.text` writer touches actor+0x598 (none found; DAT/runtime not ruled out).

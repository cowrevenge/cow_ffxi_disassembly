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

**Gates.** Target status predicate `0x84400` (6 call sites in the method) must yield ∈ {0,1,2,6,7,8}; own status
predicate `0x84390` (7 sites) ∈ {0, 0x2F, 0x30}, or one of the mount predicates `0x84330 / 0x84350 / 0x84370`
(each once) **[V(me)]**. Gate failure ⇒ release.

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

**LockLookAt stage (scheduler 0x89) suppresses tracking.** Its bit 2 ⇒ treated as *no target* ⇒ release; its
watchdog ends the stage when the actor moves ≥ **1.0** unit or the authored duration expires **[V(W2)]**. That is
the behavioural counterpart of the DAT records counted in [drivetask.md](drivetask.md) §9.1/§10.1: 504 shipped
`0x89` records, duration-only operands ⇒ actions/emotes freeze the head for N ticks or until you step, then it
resumes.

**The "bend" is found (W3).** The consumer of `model+0xB0..B8` + weight, the ellipse clamp it applies, the shoulder
share and the authored limits that feed both are now byte-verified in **§E below**; the earlier "angular clamp
unlocated" framing in this section and in §C/§D is superseded by §E.

---

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
* **open observation [O?]**: this install authors *zero* limits for the `gob_` and `sao ` (Goblin / Tarutaru)
  skeletons and only a minority of `yagu`/`kame`. That predicts those races' models never bend a head toward the
  target in retail. Worth one glance in-game before kuluu ships per-race behaviour that assumes otherwise.

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
* **The one-record status set is wider than §E.1 said.** The bend receives the own-status value as a stack argument (`[esp+0x128]`) and runs an equality chain at RVA 0x2AE0D..0x2AE8B over
  `{5} ∪ {0x2F, 0x30} ∪ {0x3F…0x53} ∪ {0x55}` — a match jumps to the write of loop-count `1` (RVA 0x2AE96), otherwise count `2` (RVA 0x2AE8B/0x2AE90) **[V(me)]**. §E.1's `{0x30} ∪ {0x3F..0x53}` missed `5`, `0x2F` and `0x55`.
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

Consequences for the port **[I]**:
* record[0] ↔ slot 3 → the neck bone, which is what kuluu now bends (`acdf77fa`); with humanoids' authored numbers this yields a horizontal reach of ≈`atan(0.24)` ≈ 13.5° and vertical ≈`atan(0.16)` ≈ 9.1°, damped by `scale = 0.5` below that.
* record[1] ↔ slot 4 resolves to the **root**, so "the second record bends neck/shoulder" is *not* expressible as "reference NECK+1 names a bone", and rotating a root over its whole subtree would be visibly wrong (§E.3's shoulder ellipse is `(0.16,0.06)` — small, consistent with a chest-side share).

**Still open after this pass:** what the second bend entry actually rotates — read the consumers of the two entries after the clamp (`0x2af20..0x2af8a`) and `call 0x2d8141`, which builds the basis inside the clamp. Until that is known, a port applies record[0] only (kuluu does exactly that, skipping any reference whose resolved joint is the root so no model can be turned by it).

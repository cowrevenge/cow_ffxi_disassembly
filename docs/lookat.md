# FFXI retail client: look-at — **two separate systems** (W + W2 passes)

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
> re-verified the pi/6 sites only against the *menu* path. **The walker's angular clamp is still unlocated.**

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

### Still open — the "bend" **[I]**
The consumer that reads `model+0xB0..B8` + weight and applies the actual **angular clamp** (plus any shoulder
share) has not been located: it is a method of the class reached through the `actor+0x674` list — accessor call
at **0xD5B1E → 0x2B5A0** **[V(me)]**, and the struct pointer itself hasn't been caught yet. Until then kuluu must
**not** invent a clamp angle for the walker.

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
* **Open knob**: keep the clamp and the shoulder share parameterized until the bend consumer is found; if you must
  ship today, run unclamped with a generous debug-menu-only guard rather than inventing an angle **[I]**.

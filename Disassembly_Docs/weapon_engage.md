# FFXI retail client: weapon state and the engage/draw machine (**B pass**)

Pass letter **B**. Read against `FFXiMain.unpacked.dll`, TDS **0x6A995428** (`client=retail-2026-09`,
md5 `fb7464073c06489268fdd9215c3e5313`), on **2026-10-12**. Every RVA below was re-read in that build by
this pass — nothing here is inherited from another build or from xim. Conventions, tiers and the byte
re-read rule: [../README.md](../README.md). Reproduce with `python probes/reread_20261012_weapon_engage.py`
from `Disassembly_Tools/`.

**Scope.** What the client does between "battle started" and "weapon is in hand": the engage step machine,
the per-hand weapon state on a PC actor (engaged / override), where weapons re-parent during the skeleton
update, how battle motion blocks get picked, and the `in `/`out` routine-name builders. The stage ops that
*drive* it (`0x84`, `0x9B`, `0xA7`, `0xA8`) are recorded as rows in
[mob_animation.md](mob_animation.md) §3.5 (same pass); this doc owns the state and the machine.

Address conventions: file offset == RVA; vtable/datum entries hold `BASE + rva` with BASE = 0x10000000, so
the dig's data spellings like `0x1032CFE0` are RVAs `0x32CFE0`.

---

## 1. The engage step machine **[V]**

Step routine **0x8B460**. `this` = entity (held in `esi`); the actor is `[ent+0xA0]`; `ebp` is set to 0 at
**0x8B5CC** (`xor ebp,ebp`) and that same register feeds both arguments of the engaged setter below.

| Fact | Bytes | Note |
|---|---|---|
| Type byte | `[ent+0xEE]`, read at 0x8B471 / 0x8B518 / 0x8B574 (`cmp byte [esi+0xee],4`) / 0x8BAAC | the step switches on it; 6/7 are the engaged-type values the dig records |
| RenderFlags pair | `test dword ptr [esi+0x120], edi` (0x8B47F, 0x8B66C) and `test dword ptr [esi+0x128], 0x20000000` (0x8B48B, 0x8B678) | the dig reads the first test's `edi` as bit **0x200**; the second is literal. Both must hold for the 6/7 types |
| Exit of that gate | leaves via **0x8C39F** (`pop edi`) | body beyond this pass's read; recorded, not transcribed |
| Busy gate | `call 0x83320` at **0x8B4AC** — the ActionTimer1 *read* thunk (see [mob_animation.md](mob_animation.md) §2). With arg 0 and a non-zero counter the step returns 0 without stepping | ties lock counting to animation progress: no new engage step while a stage holds AT1 |
| Engaged raised as the draw routine starts | **0x8B789** `mov ecx,[esi+0xa0]`; pushes at 0x8B790/0x8B78F = `(1, hand 0)`; **0x8B794** `call dword ptr [edx+0x31c]` | the raise happens in the update *after* the draw routine starts |
| Engaged dropped as the sheathe routine starts | **0x8B98C** actor load; pushes `(ebp, ebp)` = (0, 0); **0x8B9A6** `call dword ptr [edx+0x31c]` | paired with the clear below |
| Current-fourcc cleared | **0x8B994** `mov dword ptr [ecx+0x7d8], 0x20202020` (`"    "`) | actor+0x7D8 = current fourcc, spaces = none (F32/F37) — re-confirmed here as part of the sheathe start |

Not re-read this pass: which of the 6/7 types takes which branch inside 0x8B460..0x8C39F. The caller census
for who invokes this step with a non-zero argument (which skips the busy gate) was done in-pass — see §5 C3.

---

## 2. PC weapon state on the actor **[V]**

PC actor vtable **0x32D710** (the base actor table **0x32CFE0** carries stubs for these slots). Slot →
handler, all read out of the table and then into the handler body:

| slot | handler | body | meaning |
|---|---|---|---|
| **+0x31C** | 0xA4A30 | `mov al,[esp+4]`; `cmp al,1; sete al`; `mov byte ptr [edx+ecx+0x83c], al` where `edx=[esp+8]`; `ret 8` | **engaged setter**: `engaged[hand] = (v == 1)`, hand index added to the object base → bytes **+0x83C** (main) / **+0x83D** (sub) |
| **+0x320** | 0xA4A20 | reads word **[actor+0x83C]** | **either-hand-engaged** word read |
| **+0x324** | 0xA4A70 | `mov byte ptr [edx+ecx+0x83e], al` (same shape as the setter) | **override setter**, bytes **+0x83E** / **+0x83F** |
| **+0x328** | 0xA4A60 | `mov eax,[esp+4]`; `mov al, byte ptr [eax+ecx+0x83e]` | **override getter**, per hand |
| **+0x3D8** | 0xD04B0 | `lea eax,[ecx+0x878]; ret` | returns a pointer to the **CIB copy** at actor+0x878 (weapon-joint fields live in it: +6 main joint = actor+0x87E, +0x10 sub joint = actor+0x888 per the dig) |

Neighbour bonus found while reading: an *override-either* word read at **0xA4A50** (`mov ax, word ptr [ecx+0x83e]`).

### 2.1 Where those bytes come from (model load) **[V]**

| write site | instruction | field |
|---|---|---|
| 0xD0C76→0xD0C79 | `mov byte ptr [esi+0x87c], dl` | **main** model Info +0x04 → actor+0x87C |
| 0xD0C9C→0xD0C9F | `mov byte ptr [esi+0x87f], cl` | **sub** model Info +0x04 → actor+0x87F |
| 0xD0CB7..0xD0CCB | `mov byte ptr [esi+0x88a], dl` | sub Info +0x03, and only inside the dual-wielder window |

Main Info +0x06 → actor+0x87E is recorded by the dig; that specific store was not re-read this pass.
The hand-Info accessor pair used at run time: **0x5E2B0** (`mov al, byte ptr [ecx+4]`, main) and **0x5E2C0**
(`mov al, byte ptr [ecx+7]`, sub) **[V]** — i.e. Info byte 0x04 is read as +0x4 from the main copy and +0x7
from the sub copy.

### 2.2 Reset **[V]**

At **0xC5DA2..0xC5DD8** the state is cleared *through the setters*, not with direct stores: `mov dword ptr
[esi+0x840], eax` (after clearing bit `0xFF7FFFFF` at 0xC5D9D) and `mov dword ptr [esi+0x838], ebx`, then
**two calls to vt+0x31C** (0xC5DB2, 0xC5DBF — args `(0, hand0)` / `(0, hand1)`) and **two calls to
vt+0x324** (0xC5DCB, 0xC5DD8). So both engaged bytes and both overrides go to 0.

### 2.3 Hold + re-parent in the skeleton update **[V]**

Function **0x2A140** (`arg` at `[esp+0x24]`, actor kept at `[esp+0xc]`) decides which hand state drives the
weapon joints, and it queries rather than reading offsets:

- 0x2A153 `call dword ptr [eax+0x320]` → **either-engaged** word; stored as a flag (`movsx`, then
  `[esp+0x14]` = 1 when non-zero).
- 0x2A17D / 0x2A18B `call dword ptr [+0x328]` with `push 1` and `push 0` → **override(1)** and
  **override(0)**, OR'd together (`or bl, al`) to test "either override up".
- When an override is up, the per-hand choice is read again at 0x2A19B (`push 0` → main) and 0x2A1AE
  (`push 1` → sub); otherwise the engaged flag from +0x320 decides (branch at 0x2A1B7..0x2A1C1, which can
  skip re-parenting entirely by jumping to 0x2A25B).
- The re-parent block runs **0x2A1C7..0x2A25B** and resolves joints through **0x2A9B0** (called at 0x2A1EE,
  0x2A1FE, 0x2A22D, 0x2A241). That resolver is `add ecx,8; call 0x351F0(...)` then a compare against **0x80**,
  and the re-parent window carries the literals **0x7E** (0x2A229) and **0x7F** (0x2A1EA) — i.e. held main
  goes to standard position 0x7F (right hand), held sub to 0x7E (left hand). A joint value of −1 means none
  (dig reading; not separately re-read).

---

## 3. Which motion blocks get loaded **[V/I]**

- **Draw/sheathe id builders** — `0xD2ED0` builds `"in " + digit`, `0xD2EF0` builds `"out" + digit`; both do
  `movsx eax, byte ptr [ecx+0x87c]`, clamp negatives to 0 (`test; jge; xor eax,eax`), ASCII-bias with
  `add eax,0x30`, place it as the high byte (`shl eax,0x18`) and OR in `'i','n',' '` (`0x206e69`) or
  `'o','u','t'` (`0x74756f`). **[V]** Consequence: `in 0`/`out0` is right only for weapons whose main-hand
  Info byte 0x04 is 0 — see C4.
- **Kind-indexed file selection**, routine **0xD2E30** (`ret 8`, three args; the kind arg is clamped by
  `cmp edi,9` / `mov edi,1` at 0xD2E38..0xD2E3D): after a predicate call to 0x84390 must return 1, it picks
  the *state byte* — kind 2 reads **actor+0x88A** (the dual sub Info copy) and other kinds read
  **actor+0x87B** — then: **[V]**
  - negative state → `or eax,0xffffffff; ret` (**0xD2E6A..0xD2E73**): no file at all.
  - otherwise three parallel word tables selected off a second arg, indexed by the clamped kind:
    **`.data 0x35D754`**, **0x35D78C**, **0x35D7C4** (`mov ax, word ptr [edi*2 + …]`; results are
    `table[kind] + state`). **[V]**
- Loaders: **0xD16C0** (single-block path) and **0xD1970** (the two weapon-block path). Read heads only this
  pass (`sub esp,8` / `sub esp,0xc`); the "once a weapon names a battle type retail loads *only* the weapon
  block(s), not the race-wide block" claim is **[I]** — consistent with these entry points but not
  established by them.
- **Dual-wield decision** window **0xD3CFC..0xD3D2B**: `mov byte ptr [edi+0x8b5],1`, then a scan comparing
  `and eax,0xfff` against entries (`cmp ecx,edx; jl …`) — i.e. the sub slot's model id is tested against
  build-scoped ranges. **[V]** that it is range-based on the sub model; the exact range bounds were not
  tabulated this pass.
- Out-of-range model ids: the clamp/compare sequence at **0xD3C81..0xD3CAC** (`mov eax,ebx; and eax,0xfff;
  cmp eax,edx; jl`) is present **[V]**, but the "reads as 0" outcome was *not* confirmed — treat as **[I]**.

---

## 4. Stage ops that drive weapon state

Recorded in [mob_animation.md](mob_animation.md) §3.5: **0x84** (run one hand's draw/sheathe routine, name
built from `in10/ot10/in20/ot20`), **0x9B** (hold a hand for the stage's duration via vt+0x324 in ctor/dtor),
**0xA7** / **0xA8** (raise / drop that override immediately). Same build, same pass.

---

## 5. Open items

*(added by this pass — see also C1/C2 carried in the other docs)*

- **C3 — who calls the engage step 0x8B460 with a non-zero arg? NARROWED in-pass 2026-10-12, same build.**
  Direct-call census (`python xref.py artifacts/FFXiMain.unpacked.dll --to 0x8B460`) finds **exactly three**
  call sites: **0x8EB40**, **0x8EC68**, **0x8FDC3**. **[V]** (the sweep's "func 0x8B3DD" label is a
  padding artifact above the step — 0x8B460 has its own prologue, `sub esp,0x88` + four pushes; arg¹ is read
  at **0x8B49B** `mov eax,[esp+0x9c]`, exits via `ret 4`; the skip-past-AT1 branch re-confirms §1's busy gate.)
  - **Sites 1 & 2 (0x8EB40, 0x8EC68)** both push **ebx**, and ebx is loaded exactly once at **0x8EB37**
    (`mov bl, byte ptr [ecx+0x100]`, ecx = actor); a scan of the range between shows no other ebx
    reference — the flag survives to both calls. **[V]** The flag byte `actor+0x100` and its companion
    bit `actor+0x88 & 0x20` are written immediately above on two branches: **[V]**
    - **arg = 0 path** (block entry 0x8EB14): `[actor+0x100] = 0`, `actor+0x88 &= ~0x20` (byte-AND `0xDF`
      at 0x8EB27) — taken when `[ent+0x1D2] & 4 == 0` or byte `[ent+0x1FF] ∈ {8,9}`.
    - **arg = 1 path** (0x8EAFE `mov byte ptr [eax+0x100],1`; 0x8EB0B `or dword ptr [eax+0x88],0x20`),
      joining the block at 0x8EB2F where ebx picks the value up — taken when `[ent+0x1D2] & 4 != 0`
      **and** byte `[ent+0x1FF] ∉ {8,9}`.
    So the same code that engages the `actor+0x100` / `actor+0x88|0x20` flag pair is what forces the step
    past the ActionTimer1 gate. **[V]** for the wiring; what those flags *mean* (and why states 8/9 at
    `ent+0x1FF` suppress forcing) stays open.
  - **Site 3 (0x8FDC3)**: a call with **no argument pushed** — the callee reads its arg¹ slot straight off
    the enclosing scope's stack, so non-zeroness there is inherited, not chosen at this site **[V]**;
    after it returns, `jmp 0x905D4` follows. What the enclosing scope keeps in that slot: unread.
  - All three sites sit in jump-fed blocks of one giant entity-state region — each containing block reports
    zero direct callers in the sweep, so "who asks for a gate-skipping step" resolves to the enclosing
    routine's entry points (not located this pass).
    Remaining C3: locate that region's entries and read `ent+0x1D2/0x1FF` semantics.
- **C4 — which weapon models carry Info byte 0x04 = 1?** Decides who draws with anything but `in 0`/`out0`.
  Needs a DAT census over weapon model Info chunks (the field's load sites are in §2.1 of this doc; the id
  builders that consume it are in §3), and it is blocked on the DAT-access note in §6.

## 6. What this pass could NOT re-read, so nothing about them is claimed here **[OBS]**

The brief's **B5** batch — `Hume M ROM/32/13` shipping `in 0/out0/in 1/out1`; the `72`-frame opening `0x1F`
stage on `in 0`/`in 1`; weapon-block stance/run chest angles; `Mithra ROM/51/89-92` mvl1/mvr1 being the only
motions keying joint 36 and the side-step bones passing a right angle; `Hume M ROM/27/82-85` idle second-layer
key set {38,40,42,43,44,47}, `mvl2/run2` covering 38..47, the 24-frame side-step cycle and seam continuity of
the shipped gaits — **is withheld entirely.** Reason: these are facts about DAT *contents*, and this vault has
no way to read them. `Extracted_Dats/` holds extracted output (PNG/mesh/map-toml per `layout.md`) with only a
provenance column naming source DATs; the retail store is FTABLE-addressed
(`C:\PhoenixXI\SquareEnix\FINAL FANTASY XI\FTABLE.DAT` + `VTABLE.DAT`), and resolving `ROM/<a>/<b>.DAT` to
bytes needs a file-table reader that this vault does not have (the engine's `ffxi-dat` crate does). Re-doing
B5 needs either such a tool added under `Disassembly_Tools/` or a dump handed over from the kuluu side. Until
then none of those numbers may be written as `[V]` or `[local]`.

Same reason for withholding the A2 follow-up: whether the worm routines that showed both counters at 1 also
carry `0x1F`/`0x59` beside `0x07` (`dat_routines.py` over the worm DAT) — still open.

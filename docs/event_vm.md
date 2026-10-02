# FFXI retail client: event VM and cutscene machinery

Located, decoded, cited facts about how retail runs a cutscene, so the kuluu event VM (`ffxi-event`)
and the cutscene doc (`cutscenes.md` in the cs set) stop carrying "unresolved" notes. Primary target was the 0x66
Tpc motion package mapping; the rest is ordered by how much of the opening-scene port it unblocks.

Conventions (RVA base, POL1 packing, tooling, evidence tiers) are in [README.md](README.md); this
pass reused the mob pass's tooling and conventions unchanged. Findings are numbered **E1..** to stay
distinct from the mob pass's **F** numbers in [mob_animation.md](mob_animation.md). Raw dumps:
[event_evidence.md](event_evidence.md) (§A to §M). Standalone tables: [event_opcode_table.md](event_opcode_table.md)
(opcode -> handler RVA), [tpc_package_table.md](tpc_package_table.md) (0x66 package -> DAT file ids).
Web-tier sources: XiEvents, the vendored XiClient decompilation (`research/XIClient/`), cexi docs
(`research/cexi-docs/`), XiPackets.

Target binary: `FFXiMain.dll`, 2,901,584 bytes, dated 8/22/2026, TDS 0x6A7297F5.

## 1. Targets

| # | Target | Status |
|---|--------|--------|
| T1 | Opcode dispatch table (`ExecProg` switch) | Resolved: [event_opcode_table.md](event_opcode_table.md) (E1, E2) |
| T2 | 0x5B / 0x66 and the two motion resource readers | Resolved (E3 to E7, E17) |
| T3 | Request stack (`ReqSet`, `GetReqLevel`, `GetReqStatus`, 0x27 to 0x2A, `EventIdle`) | Resolved (E8 to E12) |
| T4 | What "still running" means for the waits (0x52 to 0x55, `SetAction`) | Resolved (E13): polled per tick, not DAT-timed |
| T5 | Zone scene DAT and 0x2D | Data side resolved (E18): one global file ROM\0\23.DAT. Code-side zone -> file derivation not statically resolvable (E14) |
| T6 | Camera constants and focal length | 280/350 selection local (E19); the 192 term stays web tier (E15) |

## 2. ExecProg and the XiEvents anchors (E1, E2)

All 20 XiEvents byte patterns matched in this build's `.text` (evidence §A):

| Function | RVA | Function | RVA |
|---|---|---|---|
| EventStartWait | 0xAEA50 | eventgetcode / eventgetcode2 | 0xAFAA0 / 0xAFAD0 |
| InitEvent2 | 0xAEEB0 | getworkofs wrappers / body | 0xAF4C0, 0xAF970 / 0xAF4D0, 0xAF980 |
| XiAtelBuff::EventNew | 0x8EDD0 | setworkofs / wrappers | 0xAF340 / 0xAF320, 0xAF7F0 |
| XiEvent::XiEvent / ~XiEvent | 0xBD1B0 / 0xBD600 | setworkstrofs | 0xAF810 |
| XiEventInit | 0xBCDE0 | GetActorIndex | 0xAFB10 |
| EventIdle | 0xBCD20 | GetReqLevel / GetReqStatus / ReqSet | 0xB36A0 / 0xB36E0 / 0xB3730 |
| ExecProg | 0xBC290 | lookatone | 0xB8820 |

ExecProg @0xBC290 dispatches with `movsx eax,[esp+4]; cmp eax,0xDA; ja default(0xBC967); jmp
[eax*4 + 0x100BC970]`. The jump table @rva **0xBC970** has 219 entries (opcodes 0x00 to 0xDA); each
entry is a thunk `call handler; ret 4` with ecx (the xievent) passed through. Opcodes 0xCA and 0xCB
fall to the default handler @0xAFC90. Full table: [event_opcode_table.md](event_opcode_table.md);
dump in evidence §B.

## 3. Struct layouts (E8)

### 3.1 `xievent_t` (the event VM object; `this` in every handler)

Verified locally against the handlers that read/write these offsets:

| Offset | Type | Meaning |
|--------|------|---------|
| +0x00 | u16 | `EntityTargetIndex[0]` |
| +0x02 | u16 | owner entity target index (indexed into the global entity table @rva 0x480B30, stride 4) |
| +0x04..+0x07 | u32 | `EntityServerId` area |
| +0x08 | ptr/u32 | per-event context value; null-checked by EventIdle before running; also the "event entity" server id read by GetActorIndex's default tail and passed as ctx to the 0x27/0x29 helpers |
| +0x0C | u16 | count of event ids |
| +0x10 | ptr | `EventIds`: pointer to a u16 array (per-tag entry points into EventData) |
| +0x20 | ptr | `EventData` (eventgetcode/eventgetcode2 read `[ecx+0x20]`) |
| +0x24 | 16 x 0x20 | `ReqStack[16]`, stride 0x20 |
| +0x256 | u16 | `ExecPointer` |
| +0x258 | u16 | `RunPos` (index of the active ReqStack entry) |
| +0x25A | u8 | `RetFlag` |

### 3.2 `reqstack_t` (one 0x20-byte ReqStack entry)

| Offset | Type | Meaning |
|--------|------|---------|
| +0x00 | u16 | `Priority` (0xFF = empty; lower runs first, ties to later index in EventIdle's scan) |
| +0x1C | u32 | written by ReqSet from arg a_1 |
| +0x24 | u16 | "TagNum-slot" field (ReqSet writes arg a_3 here; 0xFF marks the slot empty in ReqSet's allocation scan). Note: two different empty markers exist, +0x00 for EventIdle selection and +0x24 for ReqSet allocation. |
| +0x26 | u16 | `StackExecPointer` (ReqSet sets it to `EventIds[tagNum]`) |
| +0x3A | u8 | `TagNum` |
| +0x3B | u8 | `ReqFlag` (used by 0x28/0x29: 0 = not started, 1 = requested/pending, 2+ = started/completed) |
| +0x3C | f32 | `WaitTime` |

## 4. The two motion resource readers (T2)

### 4.1 Shared helper for 0x5B / 0x66 @0xB5220 (`ret 0xC`; E3, E7)

Called as `helper(this, param1, param2, param3)` where param1 selects the reader:
- **param1 = 0** -> `ReadEventMotionRes` (banded file ids, E4).
- **param1 = 1** -> `ReadTpcEventMotionRes(actor, val)` (E5).

After the load it confirms the `IsReadCompleteResList` yield (via 0xD12E0; a pending read sets
RetFlag=1), checks the key (`val3 && val3 != 0x78787878`) and on a hit calls `KillLastAction`
(0x87D50) then **SetAction = vcall `[vtable+0x298]`** (E7), clears the flag, makes a param3-gated
extra call `[vt+0x2A8]`, advances ExecPointer by 0xF (+2 if param3), and sets RetFlag = param2.

Callers and their params (all six; evidence §C.2):

| Caller | Opcode / case | param1 | param2 | param3 |
|--------|---------------|--------|--------|--------|
| 0xB5206 | 0x5B | 0 | 1 | 0 |
| 0xB5216 | 0x66 | 1 | 1 | 0 |
| 0xB735F | 0x5F case 3 | 0 | 0 | 0 |
| 0xB7378 | 0x5F case 4 | 1 | 0 | 0 |
| 0xB7391 | 0x5F case 5 | 0 | 0 | 0 |
| 0xB73AA | 0x5F case 6 | 1 | 0 | 0 |

**No caller passes param3 = 1**, so the ExecPointer advance is always +15 (the +2 is param3-gated
and never taken in shipped code).

**SetAction @0xCEE50** (the `[vtable+0x298]` target; also used by the 0xB4C30/0xB4D20 start/stop
variants in section 6): resolves the key via `call 0xCE490` (resource type 7) into an out slot; **if
the entry is null it returns 0 with no side effects**, matching the PS2 `SetAction` no-op on a miss
(F58). On a hit it starts the routine via the resource manager global @rva 0x47D168 / `call 0x72FC0`,
then `call 0x56C80`, and returns 1. Evidence §E.

### 4.2 ReadEventMotionRes @0xD2120 (`ret 8`; E4)

Pseudo code (verified, E4):

```
n   = gate(actor)                       // 0x84410: sign_extend(entity[+0xEE]) or 0 if no back-ptr
idx = n - 1
if idx > 7: *out = 0; return            // Type 0 or > 8 -> no-op
case  = byte_table[idx]                 // table @rva 0xD2220 = 00 00 01 01 01 01 00 00
switch case:
  case 0: load_motion_resource(actor)   // jump target rva 0xD214D
  case 1: *out = 0; return              // jump target rva 0xD2205 (no-op)
```

So it **loads for entity Type in {1,2,7,8} and no-ops (*out=0) for Type in {3,4,5,6}**. This
corrects an earlier handoff reading that had the two sets inverted; it was re-verified by two
independent raw reads of the byte table (evidence §D.3).

The load path computes a banded file id from `getworkofs(this, 1)`:

| workofs band | add | base DAT id |
|--------------|-----|-------------|
| < 0x200 (512) | +0x7D68 | 32104 |
| < 0x400 (1024) | +0xBFEF | 49135 |
| < 0x800 (2048) | +0xDC19 | 56345 |
| < 0xC00 (3048) | +0xE95B | 59739 |
| else | +0x10323 | 66339 |

It then `GetContainer(fileId)` via the resource manager global @rva 0x47D168 (`call 0x730F0`), and
if `IsReadComplete` registers it on the actor's +0x9EC list via `call 0xD1460`; otherwise it builds
a pending stub. This matches kuluu's `event_motion_dat_id` exactly.

### 4.3 ReadTpcEventMotionRes @0xD2230 (`ret 4`; E5, E6, E17)

Pseudo code, band table, worked examples and the DAT cross-check are in
[tpc_package_table.md](tpc_package_table.md). Summary: gate n in {0,1,6} via 0x84410; val >= 0x118 is
out of range (vcall [actor->vt+0xCC] + log); two file ids A (tag 1) and B (tag 2) come from four
bands on val; B is chosen by a flag byte and skipped when that byte is <= 0 signed. Containers come
from the resource manager global @rva 0x47D168 (`call 0x730F0`) and attach via `call 0xD4420(actor,
container, tag, fileId, 2)` with a pending-stub fallback (dump: evidence §D.4). Cross-check passed:
package 20 -> 32732 = ROM/72/87.DAT (tlk0 + thk1), package 12 -> 32724 = ROM/72/79.DAT (kka0).

**The B flag byte is actor+0x881 = CIB waist_type (E17).** Vtable slot +0x3D8 holds 0x100D04C0;
@rva 0xD04C0 is `lea eax,[ecx+0x878]; ret`, so `[vt+0x3D8]() + 9` = actor+0x881. First read
@0xD228A (`cmp byte [eax+9],1; sete al`) picks the B_set column; the re-read @0xD23AE/0xD23B4
(`mov cl,[eax+9]; test cl,cl; jle skip-B`) skips B when the byte is 0 or >= 0x80. Writer @rva 0xCF220
(slot +0x290 of four vtables incl. the skeleton-actor family @0x330F40; slots +0x6B0/+0xAD0/+0xEF0 of
the larger vtable @0x32E890), reached from the resource-load path pushing types 0x29/0x2A/0x45; the
CIB merge loop @0xCF34B copies resource byte +0x39 into actor+0x881 only when src < 0x80 and dest
>= 0x80 (@0xCF408 to 0xCF419). That is offset 9 of the CIB body: kuluu's `Cib::body_armour_waist`
(ffxi-dat/src/cib.rs). The `moun` FourCC branch @0xCF321 uses a different merge base and has no
+0x881 site. ROM census over 49317 DATs (18128 with CIB): byte-9 values 0x00 x173, 0x01 x837, 0x02
x2534, 0x03 x6, 0x05 x2, 0x06 x25, 0x64 x13, 0xFF x15167. Evidence §J.

## 5. The request stack (T3; E9 to E11)

- **EventIdle @0xBCD20** (E9): if `[this+8] == null` return; scan the 16 ReqStack entries
  (stride 0x20 at this+0x24), pick the lowest `Priority` (word at entry+0, 0xFF empty; ties go to
  the later index via `cmp; jg skip` = update on <=); save the index to RunPos (+0x258). Gate: three
  global bytes @rva 0x480502 / 0x487074 / 0x480930, `if (g_480502 || g_487074) { if (!g_480930)
  return; }` (recorded as observed; likely event-pause/debug flags). If best == 0xFF stop. Else:
  clear bit 17 of the owner entity's RenderFlags1 (`[ent+0x124] &= ~0x20000`, ent from the global
  table indexed by u16 at this+2); `ExecPointer = entry[RunPos].field_0x26`; call the ExecProg loop
  wrapper @0xBCCE0; on return save ExecPointer back to entry.field_0x26.

- **ExecProg loop wrapper @0xBCCE0** (E9): clears RetFlag (`[this+0x25A] = 0`), then loops: read
  `opcode = EventData[ExecPointer]`, call `ExecProg(this, opcode)` (@0xBC290), re-read RetFlag; if
  still 0 loop again (re-reading EventData/ExecPointer each pass), else return. This is the "loop
  ExecProg until RetFlag" model from XiEvents, confirmed locally.

- **ReqSet @0xB3730** (`ret 0xC`; E10): args a_1=[esp+4], a_2=tagNum=[esp+8], a_3=u16=[esp+C].
  Scan the 16 entries for the first with field_0x24 == 0xFF (empty); if an occupied entry has
  TagNum(+0x3A) == tagNum return 0 (duplicate); no free slot returns 2; else write
  `entry.field_0x1C = a_1`, `entry.field_0x24 = a_3`, `entry.TagNum(+0x3A) = tagNum`,
  `entry.StackExecPointer(+0x26) = EventIds[tagNum]` (u16 from the [this+0x10] array); return 1.

- **GetReqLevel @0xB36A0** (`ret 4`; E10): arg = u16 level. If `ReqStack[RunPos].field_0x24 > arg`
  scan all 16: return 1 only if every entry's field_0x24 > arg; else return 0.

- **GetReqStatus @0xB36E0** (`ret 4`; E10): arg = expected TagNum byte. If `ReqStack[RunPos].TagNum
  (+0x3A) == arg` return 0; else scan all 16: first entry with TagNum == arg returns 1; none returns -1.

- **Scan helper @0xB3670** (cdecl, ret 0; E10/E12): linearly scans the global entity table
  @rva 0x480B30 from start to sentinel VA 0x10482F30; for each non-null entry pointer P calls
  `call 0x8B390(P, arg)` (a predicate); returns the address of the matching table slot (pointer to
  the u32 that holds the entity pointer), or null. Callers do `P = scan(idx_or_ctx); ent =
  EntityTable[*P]`. The "idx" values from GetActorIndex out-slots are indices into this global
  table, and `[xievent+8]` is also such an index-holder value passed to the same scan.

- **0x27 @0xB3940** ("request event on target"; E11): `val = eventgetcode2(this, 2)`; GetActorIndex
  must return 1; tagNum = EventData[EP+1]; priorityByte = EventData[EP+6]; calls helper 0xB39B0
  (a_1 = idx from the GA out-slot, a_2 = [this+8], a_3 = priorityByte, a_4 = tagNum). The helper
  scans both entities (via 0xB3670), checks RenderFlags0 bit 7 (0x80) on both AND signed-low-byte of
  ent1 RF0 < 0; then calls **ReqSet @0xB3730 with this = ent1+0xD4** (the target entity's own
  event-VM pointer), a_1 = tagNum, a_2 = [xievent+8] ctx, a_3 = priorityByte. Returns -1 on any check
  failure; 0x27 sets RetFlag=1 only when the helper returns 2 (`sub eax,2; jne advance; mov
  [esi+0x25a],1`).

- **Deviation from the brief's expectation:** the request is issued through `ent1+0xD4` (the target
  entity's event VM), not "entity->EventPointer" by that name, and not on `this`. Recorded exactly
  as 0xB39B0 does it (evidence §F.6).

- **0x28 @0xB3E60** ("wait for requested event to start"; E11): ReqFlag = byte at
  ReqStack[RunPos]+0x3B. case 0 -> shared tail: eventgetcode2(this,2)+GetActorIndex must == 1; same
  entity-pair checks as 0x27 (RF0 bit7 both + ent1 RF0 low byte < 0); then GetReqStatus(ent1+0xD4,
  priorityByte): if 0 or -1 fail path (clear ReqFlag, EP += 7); if 1 set RetFlag = priorityByte.
  case 1: re-resolve entities; same checks; GetReqStatus: == 0 or -1 -> fail (clear ReqFlag, EP+=7);
  else set entry[RunPos].ReqFlag = 1 and RetFlag = 1. case >= 2: clear ReqFlag, EP += 7.

- **0x29 @0xB4000** ("request wait / poll"; E11): ReqFlag byte at +0x3B. case 0 -> B41F9 (new
  request path: same GA + entity checks as 0x28, then helper 0xB39B0; on helper==1 set entry.ReqFlag
  = 1 and RetFlag = priorityByte via the B426C/B427C tails). case 1 -> B410E: success path (RetFlag
  = 1, ReqFlag stays). case 2 -> re-resolve entities + checks; GetReqStatus(ent1+0xD4, priorityByte):
  == -1 fail (EP += 7); else RetFlag = priorityByte. case >= 3 -> B424C: clear ReqFlag(+0x3B)=0,
  RetFlag=0, EP += 7.

- **0x2A @0xB4290** ("req wait / level check"; E11): eventgetcode2(this,2)+GetActorIndex must == 1;
  resolve both entities (same scan pattern); checks RF0 bit7 on both + ent1 RF0 low byte < 0; then
  GetReqLevel(ent1+0xD4, EventData[EP+1]): if result != 0 advance (fail); else RetFlag = 1. No
  ReqFlag involvement; a pure level query each tick.

## 6. "Still running" predicates (T4; E13)

Common preamble for 0x52/0x53/0x54/0x55 and the two adjacent start/stop variants @0xB4C30/@0xB4D20
(E13): `eventgetcode2(this, 1)` -> code1; GetActorIndex must == 1 -> ent1 = Table[idx1].
`eventgetcode2(this, 5)` -> code2; GetActorIndex must == 1 -> ent2 = Table[idx2]. **Position match:**
f32 ent1+0x74 and f32 ent1+0x78 must equal the corresponding GA out-slot values for both entities
(both must be at the same authored position). RF0 bit 9 (0x200) must be set on both.

- **0x53 @0xB4E10** ("is moving action"): after preamble + checks, `val = eventgetcode2(this, 9)`;
  if a stack byte (the low byte of the GA out-slot for code1, part of the "srv" value) != 0:
  `call [ent1.ActorPointer->vt + 0x2AC](val)` (a vcall on actor1 with the u32 from EP+9); else skip.
  RetFlag = that byte; EP += 0xD. It queries actor1's state via vt+0x2AC and yields if nonzero.

- **Adjacent @0xB4C30 / @0xB4D20** ("start named action" / "stop named action"): same preamble;
  `val = eventgetcode2(this, 9)`; then `call [ent1.ActorPointer->vt + 0x298](val)` (= SetAction, E7)
  or `+0x29C` (the sibling slot). EP += 0xD.

- **0x54 @0xB5100** ("zone is moving action"): after preamble + checks, `val = eventgetcode2(this, 9)`;
  zoneObj = [global @rva 0x62A024]; vtable = [zoneObj]; `call [vtable+0x20](actor2, actor1, val)`
  (a vcall on the zone object, slot +0x20). If it returns nonzero RetFlag = 1. EP += 0xD. This is the
  XiZone::IsMovingAction equivalent.

- **0x55 @0xB4960** ("is moving scheduler"): thunk `push 0x77F0(30704); call B4B00`. Helper: same
  preamble (offsets 3 and 7 instead of 1 and 5); then `val = eventgetcode2(this, 0xB)`;
  `workofs = getworkofs(this, 1)` via 0xAF4C0; if base == 0x77F0: `call 0xB4360(workofs)` (a
  DatIdHelper-like fold); then `result = call 0x62EE0(actor2, actor1, workofs+base, val)`. If result
  nonzero RetFlag = 1. EP += 0xF. This is the IsMovingScheduler(fileId, tag, actor1, actor2)
  equivalent: the predicate is "a scheduler routine with this key exists on the actor AND is not
  finished" (0x62EE0 returns a bool).

- **0x52 @0xB48E0** ("start / load-and-run scheduler"): thunk `push 0x77F0(30704); call B49E0`.
  Helper A: same structure as helper B but the final call is `call 0x62E90(actor2, actor1,
  workofs+base, val)` (sibling of 0x62EE0). No RetFlag set on success; just advances EP += 0xF. It
  kicks off the routine rather than polling it.

**Conclusion for the hold model:** retail does not time holds from DAT length. It *polls* each tick:
0x53 via an actor vcall (vt+0x2AC), 0x54/0x2D via zone-object vcalls, and 0x55/0x52 via the
scheduler "is moving / start" pair (0x62EE0 / 0x62E90) keyed on a file id + tag. Kuluu's DAT-length
hold model in `kuluu-session/src/event_dialog.rs` is therefore an **approximation**, not exact.

## 7. GetActorIndex @0xAFB10 (full decode, E12)

Signature: thiscall, ret 0xC; args a_1 = code u32 ([esp+4]), P2ptr u32 out-slot ([esp+8]), P3ptr
u16 out-slot ([esp+C]). `ecx` is `this` (xievent) and is **not modified** on the default path.

```
esi = code - 0x7FFFFFC0            // lea esi,[eax - 0x7fffffc0]
if esi > 0x39: goto DEFAULT        // only reserved codes reach the switch
case = index_bytes[esi]            // bytes @rva 0xAFC44; jumptable @rva 0xAFC18 (cases 0..10)
switch case:
  0: X = call 0xFC520(); *P2 = [X+4]; call 0xFC2F0(); *P3 = low word of [X+4]   // local player
  1: Y = call 0xE8E00(code + 0x40); if !Y return 0; *P2=[Y+0x14]; *P3=u16[Y+0x18]
  2: Y = call 0xE8E00(code + 0x44); ... same shape
  3: Y = call 0xE8E00(code + 0x48); ... same shape
  4..8: if !call 0xAE9F0(case-3) return 0   // party members 1..5 (bool only, no out-slots written here)
  9: *P2 = [this+8]; *P3 = u16[this+2]      // event entity
  10 / default: goto DEFAULT
DEFAULT:
  if (code & 0xFF000000) == 0:     // high byte clear -> event-entity fallback
    *P2 = [this+8]; *P3 = u16[this+2]
  else:                            // literal server id
    *P2 = code; *P3 = code & 0x3FF
  idx = *P3 (u16); ent = EntityTable[idx]   // table @rva 0x480B30, stride 4
  if ent == null: return 0
  return call 0x8B390(ent, *P2) != 0        // predicate(entity, srv value)
```

Reserved-code map (index bytes @0xAFC44; code = 0x7FFFFFC0 + esi):

| codes | case | meaning |
|-------|------|---------|
| ...C0, ...F0, ...F9 | 0 | local player (call 0xFC520) |
| ...C1 to ...C5 | 1 | party/alliance slot via E8E00(code+0x40) |
| ...C6 to ...CB | 2 | party/alliance slot via E8E00(code+0x44) |
| ...CC to ...D1 | 3 | party/alliance slot via E8E00(code+0x48) |
| ...F1 to ...F5 | 4..8 | party members 1..5 via AE9F0(1..5) |
| ...F8 | 9 | event entity ([xievent+8], u16[xievent+2]) |
| ...D2 to ...EF, ...F6, ...F7 | 10 | fall to DEFAULT (literal server id path, high byte set) |

All non-reserved codes go straight to DEFAULT: high byte clear -> event-entity fallback
(`[xievent+8]`, `u16[xievent+2]`); high byte set -> literal server id (`*P3 = code & 0x3FF`). This
matches kuluu's `ActorLookup` model (reserved range, local-player selectors, event entity, and the
literal-server-id fallback).

## 8. Zone scene DAT and 0x2D (T5; E14, E16, E18)

**0x2D @0xB4F20:** same preamble as 0x53/0x54 (eventgetcode2 off=1 and off=5, GA both == 1,
position match f32 +0x74/+0x78, RF0 bit 9 both). Then actor1 = ent1.ActorPointer, actor2 =
ent2.ActorPointer; zoneObj = [global @rva 0x62A024]; `val = eventgetcode2(this, 9)`;
**`call [zoneObj->vt + 0x18](val, actor2, actor1)`**. This is XiZone::SetAction: it starts a
zone-level scheduler routine named by the u32 at EP+9 on the two actors. The `mov edi,[0x1062a024];
mov ebx,[edi]; call [ebx+N]` pattern also appears at 0xB50E8 (+0x1C, sibling in the B50xx function)
and **0xB7439 (+0x18)** in another event-VM handler that advances EP by 6, a second zone-action
opcode site (evidence §I.1, §I.3).

**Code side:** the zone scene DAT file id is loaded at zone-init time through the
BSS-resident zone object @rva 0x62A024, whose vtable only exists at runtime, so the loader itself is
not statically decodable. The routine *key* comes from EventData[EP+9], not from a zone id in 0x2D.
`ffxi-dat/src/zone_dat.rs` ZONE_DAT_TABLE maps zone -> MZB geometry, a different mapping. The
resolution is corpus-established instead (Fix 9, B2): 0x2D keys resolve in the zone's own model
(MZB) DAT, with the entrance/instance partner zone's model DAT and a short non-model-carrier list as
fallbacks; ROM/0/23.DAT is the title-screen scene, not a global 0x2D scene file.

**Scan side:** of 52869 DATs, only **ROM\0\23.DAT** carries both movN and exNN scheduler stages.
movN only: ROM\0\24, 25, 26 and (true VTABLE/FTABLE ids, corrected from the first scan's arithmetic
pseudo-ids in E16) ROM\62\113 = 31004, 114 = 31005, 115 = 31006, 119 = 31010, ROM2\19\126 = 31009.
Consistent with, but not proof of, zone -> ROM/0/zone.DAT for the low zones (evidence §I.2).
The scan's original reading — that file 23's concentration of both stage families made it the
likely global 0x2D scene file — is superseded: the per-zone-model rule above (Fix 9, B2) explains
the keys, and file 23 is the title-screen scene (E18).

**ROM\0\23.DAT fully parsed (`scene_dat_parse.py`, evidence §K):** 73872 bytes, 346 chunks: 0x06
x317 camera routes, 0x07 x24 routines (mov1..mov8, ex1a-c, ex2a-f, ex3a-e, main, loop), 0x2F x3.
Stage stream starts at the u32 at chunk+0x24; header = low byte type, next byte length in dwords;
type 0 ends the routine. Stage census: 0x04 x286 ("play this route": delay u16 @+4, dur u16 @+6,
route FourCC @+8), 0x3B x19 (routine cross-refs by name), 0x7C x72 and 0x7D x148 (weather/mood names
"fine"/"sunny" plus floats), 0x7E x1 (references a 0x2F chunk, e.g. s101), 0x10 x152, 0x0F x141,
0x7B x22, 0xAF x3, 0x3D/0x3E group markers, one 0x73 in main. All 286 route refs are defined as 0x06
chunks in the same file (zero undefined): fixed names, not computed. `main` = header + one 0x73
stage naming `loop` + terminator. `loop` = 29 stages, no camera refs: a 0x3D/0x3E list of
mov1..mov8, then three groups each opened by an 0xAF counter stage (1 to 3) and closed with 0x3E:
ex1a/ex1b/ex1c, ex2a/ex2d/ex2b/ex2c, ex3a/ex3d/ex3e/ex3c. Pick-one-per-group; the data does not
encode which is chosen.

Camera-name census: 184 of 317 match `^[0-9a-f]{2}[0-9]{2}$` (zone id hex + index); the other 133
are letter families (cg* cr* cp* cq* ct* s*). All 17 hex prefixes are real vendor zone ids
(`zone_settings.sql`, 300 rows): 0x10 Promyvion-Holla, 0x11 Spire of Holla, 0x1C Sacrarium, 0x2C
Abdhaljs Isle-Purgonorgo, 0x3C The Ashu Talif, 0x4C Silver Sea Remnants, 0x5C Beadeaux [S], 0x6C
Konschtat Highlands, 0x7C Yhoator Jungle, 0x8C Ghelsba Outpost, 0x9C Throne Room [S], 0xC0-0xC4
Inner Horutoto Ruins / Ordelles Caves / Outer Horutoto Ruins / Eldieme Necropolis / Gusgen Mines,
0xC9 Cloister of Gales. Routine -> prefix is consistent (ex1a -> 1c*, ex1b -> 2c*, ex1c -> 3c*,
ex2a -> 4c* + cpa*, ex2b -> 10*, ex2c -> 5c*, mov2 -> c1*..c4*, mov3 -> 6c*, mov4 -> 7c*).

Route (0x06) format, web tier from cexi `scene_dat_writer.md`, cross-checked on route 8c01: 32-byte
header + N x 48-byte keyframes; eye vec3 @+0, focal f32 @+0xC, look-at @+0x10, roll @+0x1C, time
0..1 @+0x20.

## 9. Camera focal length (T6; E15 web, E19 local)

FOV (degrees) = 2 * atan2(192, focal), 192 being the half viewport height in pixels; a route stores
focal length, `focal = 192 / tan(fov_deg/2)` at compile time. The camera task's END_AT_CURRENT_POS
path sets end focal to 280.0f first-person, else 350.0f; `GameManager::NextFocalLength` defaults to
350.0f and feeds `ProjectionFocalLength` (XiClient `CameraTask.cpp`, `GameManager.cpp`; cexi
`cutscenes.md`, `camera_scene_ids.md`).

Local probe (evidence §L): 192.0f (0x43400000) and 1/192 (0x3BAAAAAB) have 0 hits anywhere in the
image, so the half-height term is derived from the runtime viewport, not a literal. 280.0f has three
.text hits (0x59455, 0x8429D, 0xA5FE6), 350.0f six; the function @rva 0x5940A to 0x5947D branches on
the global byte @rva 0x487FC0 (nonzero -> 280.0f, else 350.0f) and passes the value to the focal
setter @rva 0x15290. No FOV math there. The tag-0x04 scheduler dispatch table was not located.

## 10. CHAR_NPC Type byte (E20; local + XiClient cross-check)

The entity Type byte (ent+0xEE, the gate of E4/E5 and of F28/F35/F37) is written by the s2c 0x0E
handler's SubKind dispatch @rva 0x9C917: `byte [esi+0x30]` (header-inclusive; body+0x2C) & 7 ->
jump table @rva 0x9CE98 (eight entries verified by direct read):

| SubKind | Block | Type | Extra |
|---|---|---|---|
| 0 | 0x9C9AC | 2 (@0x9C9C7) | |
| 1 | 0x9C92D | 0 or 1 (@0x9C95F / 0x9C97F) by bit 30 of ent+0x12C; gated on RF0 bit 5 clear and word[ent+0x210] == 0 | |
| 2 | 0x9CB47 | 3 (@0x9CB82) | u32[esi+0x34] -> ent+0xF8 |
| 3 | 0x9CBE6 | 4 (@0x9CC21) | |
| 4 | 0x9CC53 | 5 (@0x9CC8E) | word[esi+0x32] \| 0x9000 -> ent+0x10E |
| 5 | 0x9CD48 | 6 (@0x9CD57) | same +0x10E write |
| 6 | 0x9CDB2 | 7 (@0x9CDC1) | same; model id in [0x7B8..0x7CB] or [0x7D3..0x7DA] also sets ent+0xF6 = 2 |
| 7 | 0x9CE60 | 8 (@0x9CE6D) | SendFlg Equipment bit (0x10) -> call 0x9B400 |

Every case matches the vendored XiClient `RecvCharNpc` switch on `CharNpcTypeFlags.Type` instruction
for instruction, including the model ranges and `AUDIT_108[9] = ModelID | 0x9000` (= ent+0x10E).
Offsets: decompiled struct offsets are body-relative, local esi is header-inclusive (esi+8 = ActIndex
= body+4), so decompiled +0x2C = local +0x30. Kuluu's `LOOK_BODY_OFFSET = 0x2C` (ffxi-proto
entity.rs) is exactly `CharNpcTypeFlags.Type`; `DOOR_ID_BODY_OFFSET = 0x30` matches field_30. CHAR_PC
sets Type=0 under the same gate; bit 30 of ent+0x12C comes from CHAR_PC PetFlags.Bit6 (web, 0x00D.cpp)
and is also read locally @0x9C7A1 to 0x9C7AD.

Kuluu mapping: EntityKind::Pc <-> Type 0; Npc/Mob/Pet with a standard model (look_size 0/5/6) <->
Types 2/6/7 (retail does not split mob/NPC/pet at the Type level; that lives in Flags1.MonsterFlag +
pet ownership); equipped-model Npc look_size 1 <-> Type 1 (Type 0 when bit 30 of ent+0x12C is set,
the player-equivalent case); equipped-model Npc look_size 7 <-> Type 8; look_size 2/3/4 <->
Types 3 (door), 4 (lift), 5 (airship/boat/plant). Evidence §M.

## 11. Findings index

Each E-number's substance lives in the section named; this index exists so cross-references from the
evidence doc and the kuluu briefs keep resolving. Dates 2026-09-11 unless noted.

| E | Section | One line | Evidence |
|---|---|---|---|
| E1 [local] | 2 | all 20 XiEvents patterns matched; RVAs recorded | §A |
| E2 [local] | 2 | ExecProg jump table @0xBC970, 219 entries, 0xCA/0xCB -> default | §B |
| E3 [local] | 4.1 | six callers of helper 0xB5220; param3 never 1; 0x5B/0x66 width always 15 | §C |
| E4 [local] | 4.2 | ReadEventMotionRes loads for Type {1,2,7,8}, no-op {3,4,5,6}; five bands; earlier inverted reading corrected | §D.1-D.3 |
| E5 [local] | 4.3 | ReadTpcEventMotionRes: gate {0,1,6}, four bands, two file ids, flag-selected B | §D.4 |
| E6 [local] | 4.3 | Tpc mapping DAT cross-check passed (pkg 20, pkg 12) | prior DAT scan |
| E7 [local] | 4.1 | SetAction @0xCEE50: miss = silent no-op ret 0; hit ret 1 | §E |
| E8 [local] | 3 | xievent_t / reqstack_t layouts; two empty markers (+0x00, +0x24) | §F.1, §F.3 |
| E9 [local] | 5 | EventIdle lowest-Priority pick, ties to later index; loop wrapper 0xBCCE0 | §F.1, §F.2 |
| E10 [local] | 5 | ReqSet / GetReqLevel / GetReqStatus / scan helper semantics | §F.3, §F.4 |
| E11 [local] | 5 | 0x27-0x2A issue requests on the target's ent+0xD4 VM; ReqFlag at entry+0x3B | §F.5-F.11 |
| E12 [local] | 7 | GetActorIndex full decode; reserved range; default tail; ecx untouched | §G |
| E13 [local] | 6 | waits poll per tick (vt+0x2AC, zone vt+0x20, 0x62EE0/0x62E90); DAT-length hold is an approximation | §H |
| E14 [local] | 8 | 0x2D via zoneObj vt+0x18; loader not statically decodable (BSS vtable); scan hit list; key resolution corpus-established instead (zone model DAT, Fix 9, B2) | §I |
| E15 [web] | 9 | FOV = 2*atan2(192, focal); 280/350 defaults | XiClient, cexi |
| E16 [local] | 8 | scan id column corrected to true VTABLE/FTABLE ids; the scan's global-file-23 reading is superseded (zone model DAT, Fix 9, B2) | §I.2 |
| E17 [local] 09-12 | 4.3 | Tpc B flag = actor+0x881 = CIB waist_type; writer 0xCF220; semantics {0, >=0x80} A only, 1 B_set, [2..0x7F] B_clear | §J |
| E18 [local] 09-12 | 8 | ROM\0\23.DAT parsed end to end; 317 routes, 24 routines, main -> loop, pick-one groups, zone-id route names; file 23 is the title-screen scene, not the global 0x2D scene file (Fix 9, B2) | §K |
| E19 [local] 09-12 | 9 | 192 not in the image; 280/350 selection @0x5940A-0x5947D via byte 0x487FC0 | §L |
| E20 [local+web] 09-12 | 10 | SubKind -> Type dispatch @0x9C917 matches RecvCharNpc case for case | §M |

## 12. Kuluu-facing conclusions

- **0x5B/0x66 width is always 15 (E3).** `ffxi-event/src/opcode_meta.rs` 0x5B entry: drop the
  "confirm against a captured stream" caveat; all six helper callers pass param3=0.
- **Tpc motion mapping is banded, not flat (E5, E6, E17).** Replace `tpc_motion_dat_id(param) = param
  + 32104` in `ffxi-event/src/cue.rs` with the [tpc_package_table.md](tpc_package_table.md) mapping.
  The cue must carry both A (tag 1) and B (tag 2); B is picked by `Cib::body_armour_waist`, which
  kuluu already has on every rendered actor (`cib: Option<Cib>` in kuluu-render ffxi_actor_render.rs).
- **ReadEventMotionRes (E4, E20).** `event_motion_dat_id` matches and needs no change, but it only
  loads for Type {1,2,7,8} (0x66's ReadTpcEventMotionRes for {0,1,6}); kuluu implements the gate
  (B6): the VM reads a host-fed entity Type table keyed by server id and target index, a refused
  load is a silent no-op arming no hold. Type <-> EntityKind mapping in section 10.
- **SetAction miss is a silent no-op (E7).** Missing routine = return false, no log/panic.
- **Requests live on the target's ent+0xD4 VM (E8, E11).** `ffxi-event/src/vm/scene.rs`: issue 0x27-0x2A
  through the target entity's own VM; TagNum at entry+0x3A, ReqFlag at +0x3B; keep both empty
  markers (+0x00 Priority for EventIdle, +0x24 for ReqSet).
- **Holds are polled, not DAT-timed (E13).** `kuluu-session/src/event_dialog.rs`: document the
  DAT-length hold as an approximation or replace it with a "poll until not running" predicate.
- **Zone scene DAT (E14, E18, Fix 9, B2).** Do not reuse ZONE_DAT_TABLE for 0x2D. 0x2D keys resolve
  in the zone's own model (MZB) DAT, with the entrance/instance partner zone's model DAT and the
  non-model carriers as fallbacks (kuluu: `ffxi-dat scheduler::zone_scene_file_id`). ROM/0/23.DAT is
  the title-screen scene, not a global 0x2D scene file; its parse (E18, section 8) stands as the
  scene-DAT format reference.
- **Camera (E15, E19).** `FOV_deg = 2 * atan2(192, focal)`, default 350.0f, first-person 280.0f. The
  280/350 pick is local; the 192 is web tier, and cutscene_camera.rs should say so.

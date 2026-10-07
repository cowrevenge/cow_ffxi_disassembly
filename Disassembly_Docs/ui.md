# FFXI retail client: event UI/HUD and dialog control (U pass)

How the retail client drives its UI during events: HUD hide/unhide, the cancel/ESC flag
triad, dialog creation and select-wait, menu option masks, chat lines, string input, and the
event-report opcodes. Findings **U1..** are a fourth pass, distinct from the mob pass (**F**,
[mob_animation.md](mob_animation.md)), the event-VM pass (**E**, [event_vm.md](event_vm.md)),
and the camera pass (**C**, [camera.md](camera.md)). Conventions (RVA base 0x10000000,
POL1-packed `.text`, evidence tiers) are in [../README.md](../README.md). Raw dumps:
local untracked `out4/d_*.md` (this pass).

Target binary: `FFXiMain.dll`, build TDS 0x6A7297F5 (same build as the E and C passes).

## 1. Scope

| # | Question | Status |
|---|----------|--------|
| Q1 | What do 0x67 / 0x68 do, and what objects do they touch? | Resolved (U1, U2) |
| Q2 | What does 0x6A do, and what scale does it use? | Resolved (U3) |
| Q3 | How does cancel/ESC work, and which opcodes arm or disarm it? | Resolved (U4) |
| Q4 | What does 0x20 write? | Resolved (U5) |
| Q5 | How is a dialog created, and how does a select complete? | Resolved (U7, U8, U9) |
| Q6 | How does 0x23 wait, and what are the EventIdle gate bytes? | Resolved (U6, U10) |
| Q7 | How do 0x40 / 0x41 manipulate the menu option mask? | Resolved (U11) |
| Q8 | What do the chat opcodes 0x1D / 0x2B / 0x48 / 0x49 / 0xB0 do? | Resolved (U12) |
| Q9 | How does 0x71 string input work? | Resolved (U13) |
| Q10 | What do 0x22 / 0x4E (event hide flags) do? | Resolved (U14) |
| Q11 | How does 0x43 report to the server? | Resolved (U15) |
| Q12 | What does 0xB5 do? | Resolved (U16) |

## 2. HUD show / hide (U1, U2)

**U1 [local].** 0x67 HIDE_HUD @0xB79D0 (width 5, EP += 5). `v1 = getworkofs(1)`,
`v2 = getworkofs(3)`; then `0x136880([0x4E2190 + 0x30], v1, v2)` and
`0x136880([0x4E2194 + 0x30], v1, v2)` — the two `PresetEventMessageMode` calls of the PS2
pseudocode, with the work-slot values as the arguments (research/XiEvents/OpCodes/0x0067.md).
Finally `byte@rva 0x488009 = 1` (the PS2 `CompassDraw = 1`). 0x4E2190 / 0x4E2194 are the two
event-message objects; +0x30 is the sub-object the mode call targets.

**U2 [local].** 0x68 UNHIDE @0xB7A30 (width 1, EP += 1). The same two objects, but
`0x136880([0x4E2190 + 0x30], 0, 0, 0)` and `0x136880([0x4E2194 + 0x30], 0, 0, 0)` (three zero
arguments in this build), then `byte@0x488009 = 0`. Matches the PS2 pseudocode
(research/XiEvents/OpCodes/0x0068.md): plain reset of both message modes, compass off. The two
opcodes are independent: 0x46 sub 1 (C1) is the narrower "camera off + menu draw off" pair.

## 3. 0x6A sound volume (U3)

**U3 [local].** @0xB7B00 (width 7, EP += 7). `b = getworkofs(5)`; per set bit, one call with
`(f32 = getworkofs(1) * f32@0x32A22C, getworkofs(3))` where 0x32A22C = 0.03125f (the same
1/32 scale as the camera restore, C4):

| bit | PS2 sound type (0x006A.md) | PC callee |
|-----|----------------------------|-----------|
| 0x01 | Effect | 0x35D50 |
| 0x02 | System | 0x35DA0 |
| 0x04 | Zone | 0x35DF0 |
| 0x08 | Master | 0x35BD0 |

The bitmask and the (volume, workofs(3)) argument pair match the PS2 pseudocode
(research/XiEvents/OpCodes/0x006A.md); the volume scale differs: PS2 multiplies workofs(1) by
0.001, this build by 1/32.

## 4. Cancel / ESC model (U4)

The PS2 pseudocode names three globals (research/XiEvents/OpCodes/0x002E.md, 0x0042.md):
`CliEventCancelSetData` (armed), `CliEventCancelSetFlag` (event in progress), and
`CliEventCancelFlag` (cancel actually taken). The PC RVAs, pinned by which opcode writes which:

| RVA | PS2 name | Written by |
|-----|----------|------------|
| 0x4886F8 | `CliEventCancelSetData` | 0x2E sets 1, 0x42 sets 0, event-start reset sets 1 |
| 0x488B40 | `CliEventCancelSetFlag` | event-start reset sets 0, the ESC check sets 1 |
| 0x485AB0 | `CliEventCancelFlag` | conditional in 0x2E / 0x42, and `:= SetData` in the ESC check |

**U4 [local].** The event-start reset routine (func 0xAECF0, entered at 0xAED30) clears the
event globals: 0x485AB0 = 0, the three EventIdle gate bytes 0x480502 / 0x480930 / 0x487074 = 0,
0x48093C = 0 (C10), 0x489834 = 0 (U7), 0x488B40 = 0, and then **sets 0x4886F8 = 1** — cancel
armed at event start. 0x2E @0xB55E0 (arm, width 1): `0x4886F8 = 1`, and additionally
`0x485AB0 = 1` when 0x488B40 is already set. 0x42 @0xB5610 (disarm, width 1): `0x4886F8 = 0`,
and additionally `0x485AB0 = 0` when 0x488B40 is set. Both match the PS2 field-for-field.

The ESC check (func 0xAEAFF, mid-function entry @0xAEB6B, reached from 0x8ED96 near
`XiAtelBuff::EventNew` @0x8EDD0, E1, and from 0xAF134 / 0xBB2A3): after a scan loop finds no
veto, it does `SetFlag := 1` (0x488B40), `CancelFlag := SetData` (0x485AB0 = 0x4886F8),
`dword@0x48994C = 5`, and returns 1 (cancel granted). So a script that runs 0x42 early — the
mission-block pattern, where 0x42 is the second opcode of the master block with zero re-arms —
makes ESC a no-op for the rest of the event; a script that never touches the triad stays
escapable because the reset armed it.

## 5. 0x20 player-control lock (U5)

**U5 [local].** @0xB34D0 (width 2, EP += 2): `byte@rva 0x482F58 = EventData[EP+1]`.
0x482F58 is the PS2 `CliEventUcFlag` (research/XiEvents/OpCodes/0x0020.md: "lock the player
from controlling their character"). The neighbouring func 0xB3438 (a different opcode, a
position-write helper) is the one that stores `workofs(2/4/6) * 0.03125` into the request-stack
entry at `esi + (word@esi+0x258 << 5) + 0x28/0x30/0x38`; it is not part of 0x20.

## 6. 0x21 EventExecEnd (U6)

**U6 [local].** @0xB34F0 (width 1): `byte@0x480502 = 1`, and `byte@0x480930 = 1` (the write is
skipped when 0x480930 is already nonzero, which is equivalent), then RetFlag = 1. XiEvents
names this "sets the `EventExecEnd` flag value to 1" (event_opcode_table.md row 0x21); the two
bytes it sets are two of the three EventIdle gate bytes (U10) that the event-start reset clears.

## 7. Dialog lifecycle (U7, U8, U9)

**U7 [local].** 0x24 @0xB2280 is a thunk: `jmp 0xB2600` (width 7, RetFlag = Yes). Body @0xB2600:
gate 1 `byte@0x489938` — if set: `0x47D428 = 0x15EAB0(0x5EED58)` (acquire the dialog buffer object into the global 0x25 / 0x7F read, U8 / U9); when the result is null, RetFlag = 1 (yield), otherwise the handler continues preparing the options.
Gate 2 `byte@0x489834` (dialog active) — if set: `0x489834 = 1`, RetFlag = 1, return (yield
while the dialog is up). Otherwise the create path: a 3-byte struct `{0x99, 0x02, 0x00}` is
pushed and 0xAE3B0 called (the cancel-prep helper shared with the select-cancel paths, U8);
`v = getworkofs(1)` (the message id); `0x964B0(1, v)` (event-text lookup, the same lookup the
chat opcodes use, U12); `word@0x482F80 = 0`, `word@0x4855EA = 0`; `0xAD760(eax, &local)`
(create the dialog window); then `byte@0x489834 = 1` (dialog active) and RetFlag = 1. A second
0x24-shaped function @0xB2290 dispatches sub-cases 0..5 through a byte table into a jump table
@rva 0xB2544 (entries 0xB22C2 / 0xB2361 / 0xB23C8 / 0xB2426 / 0xB2495 / 0xB2495); case 0 sets
EP = EP + 1 and calls 0xB2560 with argument 6, i.e. the 7-width advance. The PS2 page describes
the same two-phase yield (prepare, then populate options) via `QueryEndFlag`
(research/XiEvents/OpCodes/0x0024.md).

**U8 [local].** 0x25 WAIT_SELECT @0xB2950 (width 1): `if (!byte@0x47D42C) tail` where 0xB2A32 is
a mid-function entry into the 0x7F handler (EP += 1, RetFlag = 1 — yield until the dialog
buffer exists). Otherwise `obj = [0x47D428]` (the dialog buffer object): `0x14E0B0(obj)`
(has-selection?); when true and `[obj + 0x53C]` is nonzero, `vcall [obj + 0x53C](eax)`; then
`0x14E1D0(obj)` returns the selected index in ax. ax != 0: EP += 1; if ax == 0xFF the cancel
path runs: `dword@0x488838 = 0xFE`, 0xAE3B0, 0xB2A70, then UI-buffer work on 0x578244 / 0x5EED58.
ax == 0: yield (RetFlag = 1, no EP advance).

**U9 [local].** 0x7F WAIT_SELECT @0xB2AB0 (width 1): the same shape as 0x25 — gate on
byte@0x47D42C, `0x14E0B0` / vcall `[obj+0x53C]` / `0x14E1D0` — but the cancel value written to
0x488838 is **0xFF**, not 0x25's 0xFE. XiEvents distinguishes the two: 0x25 "waits for a dialog
select (created by 0x0024)", 0x7F "waits for a dialog select to be made" (event_opcode_table.md
rows 0x25 / 0x7F).

## 8. 0x23 wait-interact (U10)

**U10 [local].** @0xB2DE0 (width 1): `case = byte@rva 0x488248` (the byte 0x1D sets, U12).
case 0: `ext = [esi + 0x260]` (ExtData), `idx = word[ext + 0x164]` (the event entity u16 index,
the same slot 0x48 / 0xB0 write); when nonzero, `ent = [idx * 4 + 0x480B30]` (the entity table)
and the handler proceeds to an entity-gated yield. case 1: RetFlag = 1 (plain yield). case 2:
sets the three EventIdle gate bytes `0x480502 = 1`, `0x480930 = 1`, `0x487074 = 1` (the event
pause), RetFlag = 1. XiEvents: "waits for the local player to interact with a dialog message"
(research/XiEvents/OpCodes/0x0023.md).

## 9. Menu option masks (U11)

**U11 [local].** 0x40 @0xB61F0 and 0x41 @0xB6260 (both width 9, EP += 9). Both build a 32-bit
range mask `m` over option slots 0..0x1F: slot i is set when `workofs(3) > i >= workofs(1)`
(a 0x20-iteration signed-compare loop; the sign is flagged through `or m, 0x80000000` when the
range is signed-negative). 0x40 ("sets a bit flag value and stores it"): reads
`mask = workofs(5)`, computes `mask = (mask & ~m) | (workofs(7) << workofs(1) & m)`, and writes
it back through `0xAF320(5, mask)` (setworkofs(5, mask)). 0x41 ("gets a bit flag value and
stores it") is the mirror: `workofs(5) & m`. XiEvents marks both as the dialog menu
enable/available mechanism (event_opcode_table.md rows 0x40 / 0x41).

## 10. Chat opcodes (U12)

**U12 [local].** All five share the shape `text = 0x964B0(1, workofs(N))` (event-text lookup)
then `0xAD5F0(text)` (print to chat):

| opcode | Handler | Width | Speaker / args |
|--------|---------|-------|----------------|
| 0x1D | 0xB2110 | 3 | `EntityTargetIndex[1]`: sets `byte@0x488248 = 1` (the 0x23 case selector), builds `"name: "` from the entity (name at ent+0x7C, or ent+0x214 when `word[ent+0x210] > 0` — the monstrosity name; `"???: "` when the entity is null), formats through 0x312031 with the `{0x96, 0x02, 0x00}` struct, message id = workofs(1) |
| 0x2B | 0xB1E90 | 7 | the given entity as speaker; message id = workofs(5) |
| 0x48 | 0xB2210 | 3 | no speaker: writes `word[ExtData+0x164] = 0`, clears 0x482F80 / 0x4855EA, message id = workofs(1) |
| 0x49 | 0xB1DF0 | 7 | no speaker; message id = workofs(5) |
| 0xB0 | 0xB1FB0 | 12 | speaker + listener: gate `if (EventData[EP+1]) return` (no EP advance); GA on codes @EP+2 and @EP+6 (both must resolve); speaker name as in 0x1D, listener index stored at `word[ExtData+0x164]`; message id = workofs(5); EP += 12 |

The entity table is @rva 0x480B30 with 4-byte stride (same table 0x22 / 0x23 / 0xB5 use,
U14 / U10 / U16). XiEvents pages: research/XiEvents/OpCodes/0x001D.md, 0x002B.md, 0x0048.md,
0x0049.md, 0x00B0.md.

## 11. 0x71 string input (U13)

**U13 [local].** @0xB7E20 (widths 2 / 4 / 6 / 8 / 10 by case). `sub = EventData[EP+1]`,
dispatched through a byte table @rva 0x100B8384 into a jump table @rva 0x100B8330 (sub <= 0x55).
Case 0 (open the input window): `0x206550(0x100B83E0, 0, -1, 0x10)` on the UI object
@[0x631924]; sets `byte@0x47FAF0 = 1` (input active) and `byte@0x489970 = 1` (input pending);
EP += 2, RetFlag = 1. Case 1: polls `byte@0x489970` (pending -> yield; clear -> complete).
XiEvents: "handles the usage of string input from the player during events, such as password
prompts" (research/XiEvents/OpCodes/0x0071.md).

## 12. Event hide flags (U14)

**U14 [local].** 0x22 @0xB3510 (width 2): `idx = word[xievent+2]`; `ent = [idx*4 + 0x480B30]`;
when non-null, `call 0x8E4C0(EventData[EP+1])` (`XiAtelBuff::SetEventHideFlag` with the
event-data byte as the value). 0x4E @0xB3590 (width 6): `GA(code@EP+2)` (the 0x0AFAD0
two-out-slot form) then set/clear the event-hide bit in `RenderFlags0` of the resolved entity.
XiEvents: 0x22 "calls `XiAtelBuff::SetEventHideFlag` for the current event entity"; 0x4E "sets
the entities event hide flag within `Render.Flags0`" (event_opcode_table.md rows 0x22 / 0x4E).

## 13. 0x43 event report (U15)

**U15 [local].** @0xB63B0 (width 2): `sub = EventData[EP+1]`. sub 0: `call 0xA0520` (the
event-report sender, sibling of 0xA05F0, C9); on success `byte@0x4855E8 = 1` (the RecPending
flag), EP += 2, RetFlag = 1; on failure RetFlag = 1 with no EP advance (retry). sub 1: when
`byte@0x4855E8 == 0`, EP += 2, RetFlag = 1; otherwise RetFlag = 1 (yield until the pending flag
clears). XiEvents: "used to tell the server when the client has updated an event or has
completed it" (research/XiEvents/OpCodes/0x0043.md).

## 14. 0xB5 event entity name (U16)

**U16 [local].** @0xB1100 (width 4): `sub = EventData[EP+1]`. sub 0: `idx = word[xievent+2]`,
`ent = [idx*4 + 0x480B30]`; when non-null, `call 0x93440(ent, 0xAF970(esi, 2))` (the name write,
the string sourced through 0xAF970 with offset 2); EP += 4. sub != 0: RetFlag = 1 and the tail
advance. XiEvents: "sets the current event entities name" (research/XiEvents/OpCodes/0x00B5.md).

## 15. Globals found in this pass

| RVA | Meaning |
|-----|---------|
| 0x4E2190 / 0x4E2194 | the two event-message objects; +0x30 = the PresetEventMessageMode target (U1, U2) |
| 0x488009 | compass byte: 0x67 sets 1, 0x68 sets 0 |
| 0x4886F8 | `CliEventCancelSetData` (armed): 0x2E = 1, 0x42 = 0, reset = 1 (U4) |
| 0x488B40 | `CliEventCancelSetFlag` (in progress): reset = 0, ESC check = 1 (U4) |
| 0x485AB0 | `CliEventCancelFlag` (cancel taken): conditional in 0x2E / 0x42, `:= SetData` in ESC (U4) |
| 0x48994C | dword set to 5 by the ESC check |
| 0x482F58 | `CliEventUcFlag` input lock (0x20, U5) |
| 0x489938 | 0x24 gate byte (U7) |
| 0x489834 | dialog active (0x24, U7; reset clears) |
| 0x47D428 / 0x47D42C | dialog buffer object (0x24 gate-1 acquires it) / buffer active (0x25, 0x7F) |
| 0x488838 | select-cancel value: 0xFE from 0x25, 0xFF from 0x7F |
| 0x488248 | `CliEventMessOpenFlag`: set by 0x1D; the 0x23 case selector (U10, U12) |
| 0x480502 / 0x480930 / 0x487074 | the three EventIdle gate bytes (0x21, 0x23 case 2; reset clears) |
| 0x48093C | `CliEventModeLocal` u16 (0x38, C10; reset clears) |
| 0x489970 / 0x47FAF0 | string input pending / active (0x71, U13) |
| 0x631924 | string input UI object (0x71) |
| 0x578244 / 0x630DA8 / 0x5EED58 | UI buffers on the select-cancel and log paths |
| 0x480B30 | entity table, 4-byte stride (0x1D, 0x22, 0x23, 0xB5) |
| ExtData+0x164 (xievent+0x260) | event entity u16 index (0x23, 0x48, 0xB0, 0xB5) |
| ent+0x7C / ent+0x210 / ent+0x214 | entity name / monstrosity flag / monstrosity name (0x1D, 0xB0) |
| 0x32A22C | 0.03125f (1/32) work-slot scale, shared with the camera pass (C4, C9, U3) |
| 0x4855E8 / 0x47FAEF | RecPendingFlag / RecPendingXZYFlag (0x43, C9) |
| 0x488140 | `ucoff_continue` (0x30 @0xB5630 clears; reset sets 1) |

## 16. Findings index

| U | One line | Evidence |
|---|----------|----------|
| U1 [local] | 0x67 @0xB79D0 width 5: 0x136880 ×2 with workofs(1)/workofs(3), 0x488009 = 1 | out4/d_67_hidehud.md (dump is 0xB7A30 = 0x68; 0x67 re-dumped this pass) |
| U2 [local] | 0x68 @0xB7A30 width 1: 0x136880 ×2 with zeros, 0x488009 = 0 | out4/d_67_hidehud.md |
| U3 [local] | 0x6A @0xB7B00 width 7: bitmask workofs(5), 4 channel setters, volume x 1/32 | out4/d_68_unhide.md (dump is 0xB7B00 = 0x6A) |
| U4 [local] | cancel triad: reset arms (0x4886F8 = 1), 0x2E / 0x42 arm / disarm, ESC @0xAEB6B takes SetData | out4/d_event_reset_flags.md, out4/d_2e_42_cancel.md, out4/d_esc_check.md |
| U5 [local] | 0x20 @0xB34D0 width 2: 0x482F58 = EventData[EP+1] | out4/d_20_ucflag.md |
| U6 [local] | 0x21 @0xB34F0 width 1: EventIdle gate bytes 0x480502 / 0x480930 = 1, RetFlag | out4/d_20_ucflag.md |
| U7 [local] | 0x24 @0xB2280 -> 0xB2600: gate 0x489938 acquires 0x47D428, gate 0x489834 yields, else 0x964B0(1, workofs(1)) + 0xAD760 create, 0x489834 = 1, RetFlag; sub-case table @0xB2544 | out4/d_24_dialog.md, out4/d_24_body.md |
| U8 [local] | 0x25 @0xB2950: 0x14E0B0 / vcall [obj+0x53C] / 0x14E1D0; cancel value 0xFE at 0x488838 | out4/d_25_waitselect.md |
| U9 [local] | 0x7F @0xB2AB0: same shape, cancel value 0xFF | out4/d_7f_waitselect2.md |
| U10 [local] | 0x23 @0xB2DE0: case byte@0x488248; case 0 entity table via ExtData+0x164, case 1 yield, case 2 EventIdle gates | out4/d_23_waitinteract.md |
| U11 [local] | 0x40 / 0x41 @0xB61F0 / 0xB6260 width 9: 32-slot range mask from workofs(1)..(3), merge / extract into workofs(5) | out4/d_40_41_menuopts.md |
| U12 [local] | chat family: 0x1D (speaker, width 3), 0x2B / 0x49 (width 7), 0x48 (width 3), 0xB0 (speaker+listener, width 12); 0x964B0 + 0xAD5F0 | out4/d_1d_chat.md, out4/d_b0_chat2.md |
| U13 [local] | 0x71 @0xB7E20: case 0 opens 0x206550 on [0x631924], 0x47FAF0 / 0x489970 = 1; case 1 polls 0x489970 | out4/d_71_stringinput.md |
| U14 [local] | 0x22 @0xB3510: 0x8E4C0(EventData[EP+1]) on EntityTable[word@2]; 0x4E @0xB3590: GA(code@2) -> RF0 event-hide bit | out4/d_22_hideflag.md |
| U15 [local] | 0x43 @0xB63B0 width 2: sub 0 sends 0xA0520 + 0x4855E8 = 1; sub 1 yields until 0x4855E8 clears | out4/d_43_eventreport.md |
| U16 [local] | 0xB5 @0xB1100 width 4: sub 0 name write 0x93440(ent, 0xAF970(esi, 2)); sub != 0 RetFlag | re-dump this pass |

## 17. Kuluu-facing notes

- The cancel triad (U4) is the retail answer to "is this cutscene skippable": the event-start
  reset arms cancel (SetData = 1), and a script that runs 0x42 early — the mission-block
  pattern, 0x42 as the second opcode of the master block with zero re-arms — makes ESC a no-op
  for the whole event. kuluu's single `EventVm.cancel_armed` flag maps to 0x4886F8 (SetData);
  the 0x2E / 0x42 rows in event_opcode_table.md already record the mapping, and event 503 is
  the verified disarmed case.
- 0x67 / 0x68 (U1, U2) are the HUD hide/unhide pair; kuluu's cutscene HUD-hide already exempts
  the dialog panel root and both map roots (HudHideExempt, event_opcode_table.md row 0x67).
  0x46 sub 1 (C1) is a separate, narrower mechanism.
- The dialog lifecycle (U7-U9) is the retail shape of kuluu's DialogRunner: 0x24 yields with
  RetFlag until the dialog is up (0x489834), 0x25 / 0x7F poll the buffer at 0x47D428, and the
  0xFE / 0xFF split at 0x488838 distinguishes the two wait-select opcodes.
- 0x20 (U5) is the per-script player-control lock; kuluu's event-wide pin (round 12) covers the
  common case, and 0x20 is the flag a script lifts mid-event to release the player.
- 0x43 sub 0 (U15) is the "tell the server the event completed" round trip; kuluu's EVENT_END
  is the equivalent, and sub 1 is the pending-flag wait that pairs with 0x47 (C9).
- The 1/32 work-slot scale (U3) is the same convention as the camera restore (C4) and 0x47 (C9):
  any kuluu consumer that round-trips a work-slot value through a scaled setter must apply 0.03125,
  not the PS2 0.001.

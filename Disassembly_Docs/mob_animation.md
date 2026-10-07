# FFXI retail client: mob animation driver

How the retail client turns server state (s2c 0x0E status/animationsub, 0x28 action packets) plus
the model DAT into the routines, clips, sounds and VFX that play on a mob. Primary specimen: the
tunnel-worm burrow cycle. The end goal was a generic mechanism, not a per-mob list; that is what
the findings below establish.

Conventions (RVA base, POL1 packing, tooling, evidence tiers) are in [README.md](../README.md).
Raw dumps backing the findings: [mob_evidence_1_modmap_anchors.md](mob_evidence_1_modmap_anchors.md)
(§A, §B), [mob_evidence_2_entity_update.md](mob_evidence_2_entity_update.md) (§C),
[mob_evidence_3_handler_destroy_live_dat.md](mob_evidence_3_handler_destroy_live_dat.md) (§D to §H).
The event VM pass that reused this tooling is [event_vm.md](event_vm.md). The pre-existing LSB and
Kuluu-side facts (wire offsets, FSM, LSB burrow timeline) are in the companion `ffxi_mob_animation.md`
in the kuluu repo.

## 1. Questions and where they landed

| # | Question | Status |
|---|----------|--------|
| Q1 | Which module holds game logic, load chain | `FFXiMain.dll` in the POL boot process; POL1-packed .text (F24, F25). polboot -> FFXiMain load chain is dynamic and still unread. |
| Q2 | Where pkt status / animationsub land on the entity | Not in named fields. Status is a u32 XOR-diffed into RenderFlags0; sub is packed into RenderFlags1 bits 1-3 (and 13-14 for even-status packets). StatusServer is written from the *animation* byte (F30, F43). |
| Q3 | How (type, status, sub) becomes "play routine X" | Sub -> inline fourcc table @0x35AF60 `[init ini1 ini2 ini3] x2`, indexed by the raw 3-bit sub, played via actor slot +0x298 / +0x29C (F37). Fixed name families in code, per-mob content in the DAT (F54, F55). |
| Q4 | What auto-runs `init` / `ini1` | Actor construction runs `init` (a pop, a zone-in, a view-range re-entry are all constructs); a sub change on a live actor runs `table[sub]` (F11, F37, F53). |
| Q5 | Sound and VFX resolution | Sound: SE id as four ASCII digits in the 0x0A stage, file `se%3.3u/se%6.6u.spw` (F46, F25). VFX: 0x02 stage names a generator instance; pointer at stage +0xC (F21, F46). Generator object resolution not traced. |
| Q6 | Interrupt semantics | sub=0 mid-routine is a no-op; routines run to completion (F13, F42, F48). Engage mid-pop never observed. |
| Q7 | How retail hides the worm under LSB's unflushed INVISIBLE | The dig clip ends underground and the actor holds the pose; status=3 additionally destroys the actor but is not the hide (F16). |
| Q8 | Mob DAT chunk format | Chunk ids 01/07/20/29/2A/2B/3D/45 (+05); scheduler body is the same stage stream the client keeps in memory (F54, F46). Exe-side chunk-type dispatch unread. |

## 2. How it works (synthesis of the findings)

**Wire to flags.** The 0x0E field-packing core @0x9BCF7 (F30) does not store status or sub
anywhere named. Status is a u32 at body+0x1C, XOR-diffed into RenderFlags0 bits (status&3 at
bits 13-14, bit 2 at bit 18, further bits via 0x97A30). animationsub (body+0x26) goes to
RenderFlags1 bits 1-3 (variant B) or bits 13-14 (variant A, even status without the pkt+0x2B
flag) (F43). The handler only packs; consumers act on the packed bits later in the frame.

**Flags to actor lifetime.** The per-frame flush wrapper @0x95DB0 runs `if RF3 & 1 { destroy
0x92910; update/create 0x8F750; RF3 &= ~1 }` (F35, F36). Destroy tears down when RenderFlags0 bit
0x200 "has actor" is set: vcall slot +0x18 (dtor 0xC5550), ActorPointer=0, clear 0x200 (F32).
Create (inside 0x8F750 @0x8F7FF) runs when 0x200 is clear: Type switch, alloc, CXiSkeletonActor
ctor 0xC525E via mid-function entries 0xC56F0 / 0xC5890, optional `spop` name when RF3 bit 23
(F35). INVISIBLE (status 3) is a destroy; the next status=1 is a create, so a pop is always a
fresh actor and `init` replays (F11). Leaving/re-entering view range is the same path (F53).

**Sub to routine.** Normalizer @0x8EF70 mirrors RF1 bits 1-3 into bits 4-6 and syncs actor+0x8A9
(get/set via slots +0xA4/+0xA8); change detector @0x8EFD5 compares live sub against actor+0x8A9
and on change plays `table[sub]` from @0x35AF60 via +0x29C and/or +0x298, gated on RF0 bit 9 and a
check call +0x2A0 (F37, F44). The 8-entry table wraps mod 4, so the spawn flag (sub 5 = 1|0x04)
resolves to `ini1` unmasked (F47). The create path resets sub to 0 on a fresh actor (F39).

**Routine to clips.** Slot +0x298 (SetAction @0xCEE50) and +0x29C (@0x84CD0) resolve the fourcc
through 0xCE490, which walks the actor's loaded resource list (model DAT, then shared libraries such
as ROM/0/0.DAT, then nothing) (F44, F55, E7). A hit copies the routine's stage stream (type byte +
length-in-dwords byte per stage) into scheduler nodes hung off actor +0x68/+0x6C; the first node
of a motion routine carries the clip fourcc at +0x3C and its frame count at +0x40 (F20, F46).
Locks are the 0x07/0x59 AnimationLock stages, counted in ActionTimer1 (a refcount) with ActionTimer2
= 1800 countdown stamped by @0xA4150 (F34, F49, F55, F57). A miss is a silent no-op (E7, F58).

**Combat.** 0x28 `cmd_arg` (bit 86) is a FourCC routine name: `atk0` for melee (categories 1, 2 ->
`SetAttack`), `cate` for ability starts (7, 8, 9, 10, 12) (F50, F56). `atk0` calls the client
built-in `hwat`, which is a dead reference; the swing is the model's `ati0..atiN` picked at random
when standing, `atf0/atl0/atr0/atb0` when moving (F55, F58). The target runs a ~15-frame damage
reaction (`damg/ldam/sdam`, `gurd`, `pary`, `sway` chosen from resolution and hitDistortion) (F52,
F56, F58). A TP move's `animation` field is an FTABLE index into an effect DAT whose `main` routine
names the caster's `sp??` clip (F51, F58).

**Data.** Every model ships the same ~36-routine standard set (`init pop0 dead corp atk0 ati0-N
atf0 ldam damg sdam gurd pary shld sway cate cast ca?? sh?? chit ntob` plus voice wrappers) and its
specials (`ini1-3`, `spop`, `hen0`, `wep0-3`, `fsh0-3`, `!in?/!kl?`). Names a routine calls need not
be in the DAT: `hwat aloc mloc rloc wash waso proc dcnt hw??` exist nowhere and no-op (F54, F55,
F58). So "the list for all mobs" is a DAT scan for which of the client-requested names each model
implements, and their stage contents.

## 3. Reference

### 3.1 Key RVAs (FFXiMain.dll, build TDS 0x6A7297F5)

| RVA | What | Finding |
|-----|------|---------|
| 0xBB1A60 / 0xBB1AFB | POL1 entry stub / LZSS unpacker; real DllMain @0x31676F | F24 |
| 0x480B30 | global entity table (stride 4, indexed by target index; sentinel VA 0x10482F30) | F28, F30 |
| 0x9BCF7 | s2c 0x0E field-packing core (status u32 -> RF0, sub -> RF1, StatusServer <- anim byte) | F30, F43 |
| 0x9C917 / 0x9CE98 (TDS 0x6A7297F5); **0x9C916 / 0x9CE88 in TDS 0x6A995428** | 0x0E SubKind dispatch / jump table -> Type byte (+0xEE) setters — current-build table in [lookat.md §B-quater](lookat.md) | E20 |
| 0x8F750 .. 0x926C7 | per-entity update routine (thiscall, ecx = XiAtelBuff*); create dispatch @0x8F7FF; PopEffect block @0x90A31 | F28, F35 |
| 0x95DB0 | flush wrapper: RF3 bit 0 -> destroy + update/create; call sites @0x95A58/0x95AEA/0x95BAB, rate-limited by counter 0x487E8C vs 0x35AF48 | F35, F36 |
| 0x92910 (in func 0x928A3) | actor destroy entry, 23 call sites; gates on RF0 0x200 | F32, F34 |
| 0xB9121 | RF3 bit-0 setter (`or [eax+0x12c],1`), reached via the stdcall thunk table ~0xBC6AF | F36 |
| 0xC525E | CXiSkeletonActor ctor; direct-call entries 0xC56F0 / 0xC5890; vtable install @0xC577B then `mov [ebx+0xA0],esi` @0xC5783 | F26, F34 |
| 0x330F40 | CXiSkeletonActor vtable (64 slots). +0x18 dtor 0xC5550; +0xA4/+0xA8 get/set actor+0x8A9; +0x1DC, +0x1EC resolver slots; +0x290 CIB merge writer 0xCF220; +0x298 SetAction 0xCEE50; +0x29C 0x84CD0; +0x2A0 check; +0x2AC is-moving; +0x3D8 accessor 0xD04C0 (&actor+0x878); +0x3F0 predicate; +0x400 find routine by name | F26, F44, E7, E13, E17 |
| 0x32BB38 / 0x32B680 / 0x32B654 | vtables: motion-task node / generic scheduler node / motion object | F17, F26 |
| 0x35AF60 | sub -> fourcc table `[init ini1 ini2 ini3 init ini1 ini2 ini3]` (inline, .data) | F37 |
| 0x8EF70 / 0x8EFD5 | sub normalizer / change detector + applier (the dispatch) | F37 |
| 0x8C490 / 0x95EA0 | raw-state machine on [ent+0x170] (fsh0-3, init+inte, wep0-8, default sub block) / tick SM that arms `hen0` | F37 |
| 0xCE490 | fourcc -> routine entry resolver (walks loaded resource list, `init` special-cased) | F44 |
| 0xCE241 / 0xCE59D / 0xCE790 | init -> ini0 rewrite resolvers (slot +0x1DC predicate, then slot +0x400); 0xCE790's callers ~0xD6B6B-0xD6C84 form the state -> fourcc switch (`ls05`, built `i/b/n/w` names) | F29 |
| 0xA4150 | ActionTimer setter: `inc word [ecx+0x11C]; mov word [ecx+0x11E],0x708`; 5 callers | F34 |
| 0xCF070 / 0xCF0C0 / 0xCEF10 | post-init hook family: `!kl1-3`, `!in?` -> candidates @0x330F28 `!in1-3` | F45 |
| 0xD60D0 / 0xD60F0 | `wep0..wep8` name builder; `!f01/!f02` gated on actor+0x840 bit 13 | F37, F45 |
| 0x35F634 / 0x3515BC | class-name strings `CXiSkeletonActor` / `CYyObject` (.data) | F26 |
| 0x329D28 / 2C / 30 | -pi / 2pi / +pi (angle wrap constants) | F35 |

### 3.2 Entity `XiAtelBuff` (684 bytes; SDK layout verified live on this build, F1, F8)

| Offset | Field | Notes |
|---|---|---|
| 0x074 / 0x078 | TargetIndex / ServerId | |
| 0x07C | Name[28] | |
| 0x0A0 | ActorPointer | CXiSkeletonActor*; 0 while destroyed |
| 0x0D4 | EventPointer | XiEvent*; event VM requests are issued on the *target's* +0xD4 (E11) |
| 0x0EC | from pkt body+0x1A (u8) | F30 |
| 0x0EE | Type | 0 PC, 1 equipped-model NPC, 2 fixed-model NPC, 3 door, 4 lift, 5 boat/plant, 6/7 misc, 8 equipped w/ Equipment flag; set by SubKind dispatch (E20). Worm = 2 |
| 0x0F6 / 0x0F8 / 0x10E | set by SubKind cases (E20) | |
| 0x11C / 0x11E | ActionTimer1 / ActionTimer2 | refcount of running locks / 1800 countdown, 2 per frame |
| 0x120 .. 0x130 | RenderFlags0..4 (RF0..RF4) | bit map in 3.4 |
| 0x144 | PopEffect | 3 -> `pop0`, 6 -> `pop1` via slot +0x298, then zeroed (F28) |
| 0x145 | UpdateMask | 0x0F in view, 0x00 out of view (F53) |
| 0x16C / 0x170 / 0x174 | StatusServer / Status / StatusEvent | StatusServer <- 0x0E anim byte (gated); Status synced from it ~7 frames later; [0x170] keys the raw-state machine (F30, F37, F49) |
| 0x188 | from pkt body+0x28 (u32) | F30 |
| 0x190 | Animations[10] fourcc | pose/locomotion bank `idl si1 wlk run ci1 idl idl idl wlk run`; never changed during burrow (F7, F10) |
| 0x1D0 | SpawnFlags | 0x10 Mob |
| 0x210 | word checked by SubKind 1 gate | E20 |

### 3.3 Actor `CXiSkeletonActor` and scheduler objects

| Object / offset | Meaning | Finding |
|---|---|---|
| actor +0x68 / +0x6C | scheduler node list head / tail (0 when idle) | F9, F15 |
| actor +0x70 | back-pointer to XiAtelBuff | F15 |
| actor +0x78 | colour word (0x80808080 fresh, 0xC0808061 idle, 0xC0804141 engaged) | F15, F49 |
| actor +0x80 / +0x84 / +0x88 | routine playing (0/1) / ActType (2 burrow; 4->2->3->0xD in combat) / 6 idle -> 2 | F15, F49 |
| actor +0x7D8 | current fourcc; 0x20202020 (spaces) = none | F32, F37 |
| actor +0x840 | flag byte: bit 7 `!in?/!kl?` latch, bit 13 `!f0?` | F45 |
| actor +0x878 .. | CIB (0x45 info chunk) copy; +0x881 = waist_type (Tpc B flag) | E17 |
| actor +0x8A9 | animationsub byte (slots +0xA4/+0xA8) | F44 |
| actor +0x8C4 | name written by create path (`spop`) | F35 |
| actor +0x9EC | attached resource container list | E4 |
| node (stride 0x140) +0x0C/+0x10 | actor ptr | F18 |
| motion-task node +0x3C / +0x40 | clip fourcc / frames (f32) | F20 |
| node +0x114 / +0x118 | -> parsed routine record (stage stream) | F46 |
| motion object +0x30 / +0x44 | clip fourcc / model id string (`em_b16_5`) | F20 |
| generator record (0x80 bytes) +0x1C | generator type fourcc (`moku dist kake`) | F21 |

### 3.4 RenderFlags bit map (entity +0x120 .. +0x130)

| Word | Bits | Meaning | Finding |
|---|---|---|---|
| RF0 +0x120 | 1 | gate: skip StatusServer write when set | F30 |
| | 2 | set on routine completion (with +0xEE := 2) | F37 |
| | 5 | gate for tick SM 0x95EA0 | F37 |
| | 7 (0x80) | required on both entities by event 0x27-0x2A | E11 |
| | 9 (0x200) | has actor; XiEvents' "has actor" test; destroy clears, create pre-sets | F11, F28, F32, F35 |
| | 13-14 (0x2000/0x4000), 18 (0x40000) | wire status & 7 | F30 |
| | 16 (0x10000) | set by destroy-from-live; absent when first seen hidden | F47 |
| | 22 (0x400000), 30-31 | pkt B1 bit 0 / bits 1-2 | F30 |
| | 23 (0x800000) | set on INVISIBLE, not on despawn/death (0x00C16000 vs 0x00406000) | F11, F42 |
| RF1 +0x124 | 1-3 | subA, the live sub the dispatcher reads (variant B write) | F30, F37, F43 |
| | 4-6 | normalizer mirror nibble | F37 |
| | 8 (0x100) | set on INVISIBLE | F39 |
| | 11 (0x800) | cleared on dig, back at lock start | F39, F48 |
| | 13-14 (0x6000) | variant A sub write (even status without pkt+0x2B bit 2); read by 0x7A4C1 / 0x7BDAD | F43 |
| | 17 (0x20000) | cleared by EventIdle before running a request | E9 |
| | 17-19 | cleared by the 0x0E handler | F30 |
| | 22, 24 | pkt B2 bit 0 / B3 bit 0 | F30 |
| RF2 +0x128 | 2 (0x4) | checked in destroy (calls 0xD44C0(actor,3)) | F32 |
| | 4 (0x10) | set on dig | F48 |
| | 11-13 (0x3800) | pkt B3 low 3 bits | F30 |
| | 29 / 30 / 31 | dispatched this cycle / `hen0` pending / initialized latch; 29+31 cleared by `and 0x5FFFFFFF` @0x90CAD on destroy | F37, F48 |
| RF3 +0x12C | 0 | rebuild pending (flush gate) | F36 |
| | 14 | written @0x9C78B | E20 (M.4) |
| | 23 | `spop` create name | F35 |
| | 28 | set on engage / death packet, cleared on a later packet | F49 |
| | 30 | splits Type 0 vs 1 in SubKind 1; set by CHAR_PC PetFlags bit 6 | E20 |
| | 0x400 / 0x2000 / 0x40000 | from pkt body+0x20 u32 | F30 |
| RF4 +0x130 | 7 | "sub != 0" latch; survives destroy/create | F41 |

### 3.5 Routine record stage stream (in memory = DAT 0x07 chunk body)

Stage header: `op u8, len u8 (dwords, header incl.), delay u16 @+4, duration u16 @+6`; delay
accumulates into the start tick; 60 ticks/s (F46, F54, F57). Ops seen in mob routines:

| Op | Meaning | Payload notes |
|---|---|---|
| 0x01 | record header | |
| 0x02 | fire VFX generator | +8 instance fourcc, +0xC generator object ptr (runtime) |
| 0x03 | call routine on source | +8 name, +4 start frame |
| 0x05 | skeleton animation | +8 clip fourcc, 2 f32, transIn/transOut u16, maxLoop |
| 0x07 / 0x59 | AnimationLock (`BondageActor` / `LockCasterMagic`) | duration = the ActionTimer1 lock |
| 0x09 | call routine on target | `lhit chit` |
| 0x0A / 0x0B / 0x4A / 0x53 / 0x60 | sound variants | +8 = 4 ASCII digits (global se file) or a 0x3D chunk name in the same DAT |
| 0x1F / 0x20 | LockActorStatus | |
| 0x21 / 0x25 | flinch source / target | |
| 0x24 | suspend on result | |
| 0x28 | transition to idle | |
| 0x29 / 0x2A | actor colour fade; 0x80808080 neutral | |
| 0x2B | status message / damage callback | |
| 0x2E / 0x2F | lock caster control / rotation | |
| 0x32 | broadcast toggle | |
| 0x3B / 0x3C | blocking child | `wash waso` |
| 0x3D / 0x3E, 0x50 | random-child group open / close, separator | `vdam` = one of dam2-4 |
| 0x57 | call variant (voice routines) | |
| 0x5E | knockback | |
| 0x5F | StopRoutine(name) | dig stops `init`, pop stops `ini1` |
| 0x74 / 0x78 / 0x85 | disintegrate / display dead / kill | |

Full ~85-op list: xim `EffectRoutineParser.kt` (F57). Scheduler chunk layout on disk: +0x24 u32 =
first stage offset (0x50), +0x28 body length, +0x2C count; a type-0 header ends the stream (F54).

## 4. Findings log

Format: `F<n> [local|web|external] <date>: fact. Evidence: RVA / bytes / file.` Newest last within
each session block; F38 lived only in the observation record and is referenced by F40/F42.
Working hypotheses referenced by the log: **H1** = the sub value is formatted into a fourcc that
lands in `Animations[]` (dead, F10); **H2** = two triggers, actor construction runs `init` and a sub
change runs `ini<N>` (right in shape, replaced by F37's table + F47's wrap); **H4** = sub=0 cancels
only on a real 1 -> 0 transition (dead, F42).

### Web-sourced groundwork (F1 to F6)

- **F1 [web] 2026-09-08:** Client entity struct is `XiAtelBuff` (PS2 name), `sizeof == 684`,
  base class `CYyObject`; entity array `PTR_ActorBuffPtr[]` indexed by target index. Layout in
  3.2. Evidence: https://github.com/AshitaXI/Ashita-v4beta/blob/main/plugins/sdk/ffxi/entity.h
  (`static_assert(sizeof(entity_t) == 684)`). Retail-current; not yet verified on our build.

- **F2 [web] 2026-09-08:** Status is *three* u32 fields, not one byte: `StatusServer`(0x16C, from
  update packets), `Status`(0x170, synced copy used for client validations), `StatusEvent`(0x174,
  during events). Plus two unknowns at 0x178/0x17C with PS2 names `ActorStatus`/`CliStatus`.
  Implication: our companion-doc mental model of "one status byte" is the *wire* view only.
  Evidence: same header, field comments.

- **F3 [web] 2026-09-08:** Byte-to-fourcc precedent: `PopEffect`(0x144) "3 and 6 are valid
  values. Calls function with `pop0` or `pop1` effect." `Animations[10]`(0x190) hold fourcc
  strings (`idl`, `sil`, `wlk`; v3 ADK comment). `LastActionId`(0x1EC) is a fourcc (`tlk0`).
  Evidence: same header + `HealsCodes/XIPivot/3rdParty/SDKs/Ashita/ADK_v3/ffxi/entity.h`.
  This was the basis for the (dead) H1 hypothesis that the sub value shows up in `Animations[]`.

- **F4 [web] 2026-09-08:** Event VM opcode `0x5E` does: `XiAtelBuff_KillLastAction(ent)`;
  `ent->Animations[5] = <fourcc from bytecode>`; `XiAtelBuff_IdleDefMotion(ent)`; then if
  `YmObject_IsKindOf(ent->ActorPointer, "CXiSkeletonActor")` writes the fourcc into the actor
  too (actor+0 = fourcc, actor+4 = `0x20202020` i.e. four spaces) and touches
  `XiSkeletonActor::finding_finished_flags`. So: (a) motion changes go through
  `Animations[]` then an "idle/def motion" refresh; (b) the actor object mirrors the current
  fourcc at its start; (c) `YmObject_IsKindOf` compares class-name **strings**, so `CXiSkeletonActor`
  etc. are literal strings in FFXiMain (Phase 1 anchor). Evidence:
  https://github.com/atom0s/XiEvents/blob/main/OpCodes/0x005E.md

- **F5 [web] 2026-09-08:** `teschnei/lotus-ffxi` implements loading of NPC models, animations,
  and "some schedulers/generators/particles" from retail DATs in open C++ (Vulkan). Use as the
  primary reference for scheduler/generator binary formats and VFX-name resolution (Q5) before
  disassembling. Evidence: https://github.com/teschnei/lotus-ffxi (README).

- **F6 [web] 2026-09-08:** Entity `Type`(0xEE): 0=PC, 1=NPC, 2=NPC fixed model, 3=doors;
  `SpawnFlags`(0x1D0): 0x01 PC, 0x02 NPC, 0x10 Mob, 0x0D local player. `ModelHitboxSize`(0x208)
  is filled from `0x0D`/`0x0E`/`0x37` as `(u8)data * 0.10`, so those three packets share a
  parsing path for at least some fields. Evidence: F1 header comments.

### Phase L sessions 1 to 3, wormwatch v0.1 to v0.3 (F7 to F23)

- **F7 [local] 2026-09-08:** wormwatch v0.1 on the PhoenixXI client, Tunnel Worm idle,
  idx=968 (0x3C8), srv=17187784. Accessor reads: `Type=2` (SDK: "NPC, fixed models"; so the
  worm is *not* Type 1 like generic NPCs, worth checking whether Type gates the animation path),
  `SpawnFlags=0x10` (Mob), `Status=StatusServer=StatusEvent=0`, `UpdateMask=0x0F`,
  `PopEffect=0`, `AnimationPlay=0`, `AnimationTime=0`, `AnimationStep=999`,
  `Animations[0..9] = idl si1 wlk run ci1 idl idl idl wlk run`, `Mou4='mou4'`,
  `LastActionId=0`, `Render.Flags0=0x00402200`, `Flags3=0x20000000`, `Flags7=0x00040000`,
  `ActorPointer=0x24F7D0C0`. Slot layout reading: [0] idle, [1] `si1` (sit/special?), [2] walk,
  [3] run, [4] `ci1`, [5..7] idle variants, [8] walk, [9] run. Slots 5..9 look like a second
  bank (event VM op 0x5E writes `[5]`, F4). `GetRawEntity` exists but returns a sol userdata,
  not an address. Evidence: wormwatch GUI screenshot; log to follow.

- **F8 [local] 2026-09-08 (wormwatch_20260908_052038.log):** Entity address recovered by
  dereferencing the sol userdata box (`GetRawEntity` -> userdata, `*box == XiAtelBuff*`), verified
  by idx at +0x74 and srv at +0x78. **The SDK layout (3.2) holds on the PhoenixXI build** (raw mode).

- **F9 [local] 2026-09-08:** Full dig/pop cycle, Tunnel Worm idx=56 srv=17186872, one actor
  generation each side. Times relative to the dig packet t0:

  | t | wire (0x0E) | XiAtelBuff | actor (CXiSkeletonActor) |
  |---|---|---|---|
  | t0 | mask=0x04 status=1 sub=1 (byte 0x22=0x08) | | |
  | t0+4ms (next frame) | | ActionTimer1 0->1, ActionTimer2 1800 counting down 2/frame | +068/+06C = node ptr (list head/tail), +080=1, +084=2, +088 6->2 |
  | t0+0.24..1.1s | | | +068/+06C step through pool nodes 0x21A85620 -> 54E0 -> 53A0 (stride 0x140) |
  | t0+1.93s | | ActionTimer1 1->0, ActionTimer2 reset 1800 | +080 -> 0, +084 -> 0 |
  | t0+2.2s | | | +068/+06C -> 0 (list empty, routine done) |
  | t0+3.07s | first mask=0x01 POS status=3 sub=0 | RenderFlags0 0x00402200 -> 0x00C16000, **ActorPointer -> 0** | actor destroyed |
  | t0+3.07..11.0s | POS status=3 every 0.28..0.74s | unchanged | none |
  | t0+11.03s | mask=0x05 status=1 sub=1 | RenderFlags0 -> 0x00402200, **ActorPointer = new object** | fresh actor, +054 clip ptr set, +078 colour, position |
  | +73ms | | ActionTimer1 0->1 | +068/+06C node, +080=1, +084=2, +0B0 0x16801 -> 0x6800 |
  | pop+2.48s | mask=0x04 status=1 sub=0 | nothing | **routine keeps running** |
  | pop+3.24s | | ActionTimer1 1->0 | +080 -> 0 |
  | pop+3.28s | | | +068/+06C -> 0 |

- **F10 [local] 2026-09-08:** Over the whole cycle **none** of `Status`, `StatusServer`,
  `StatusEvent`, `Unknown0178/017C`, `Animations[0..9]`, `AnimationTime/Step/Play`, `PopEffect`,
  `LastActionId`, `Mou4`, `UpdateMask` changed. The 0x0E status/sub bytes are **not stored** on
  XiAtelBuff; the handler acts on them immediately. Q2's "where does pkt+0x26 land" answer is:
  nowhere persistent. It becomes a scheduler node on the actor (+0x68 list) plus the
  ActionTimer1 lock on the entity. H1's "fourcc appears in `Animations[]`" is dead.

- **F11 [local] 2026-09-08:** `status=3` (INVISIBLE) is implemented as **actor destruction**:
  `ActorPointer=0`, `RenderFlags0` 0x00402200 -> 0x00C16000 (bit 0x200 cleared, matches the
  `Flags0 & 0x200` "has actor" test in XiEvents op 0x5E; bits 0x800000|0x10000|0x4000 set).
  `status=1` after that **creates a new actor object** (different address, vtable 0x04DF0F40 both
  times). So a pop is a fresh model load, not a resume.

- **F12 [local] 2026-09-08:** Routine durations, measured by the ActionTimer1 lock: **dig =
  1.93s, pop = 3.24s.** The DAT says `ini1` ~1.9s (sp1?, sound 7025) and `init` ~3.1s (sp0?,
  sound 7024, dirt VFX). That matches only if **dig plays `ini1` and pop plays `init`**, i.e. the
  reverse of the companion doc's assignment (DigDown -> sp0?, PopUp -> sp1?). Reading: `init` is
  the auto-run-at-load routine and runs because the pop *creates* the actor (F11); `ini1` is
  "ini" + sub value 1, fired when sub changes on a live actor. Dirt VFX on emergence, not burial.
  (Confirmed by name in F20.)

- **F13 [local] 2026-09-08 (Q6, partial):** The sub=0 packet at pop+2.48s arrived while the pop
  routine still had ~0.8s to run; the client did **not** cancel it (ActionTimer1 stayed 1, list
  kept stepping, ended at pop+3.28s). Kuluu's `PopUp -> None` cancel on sub=0 diverges from
  retail here. Retail lets the routine finish. Engagement-interrupt case still untested.

- **F14 [local] 2026-09-08 (Q7, partial):** In this zone INVISIBLE **was** flushed: buried POS
  updates carried status=3 every 0.28..0.74s (worm roaming underground), first one 3.07s after
  dig. Between routine end (t0+2.2s) and hide (t0+3.07s) the worm sat on its held end frame
  ~0.9s. Retail relies on the status byte to hide; nothing in `ini1`/`init` hides the model.
  Kuluu's 4s timeout is therefore a workaround for LSB's unflushed case only; the unflushed case
  itself (no-navmesh zone) was not reproduced this session.

- **F15 [local] 2026-09-08 (actor layout, CXiSkeletonActor, 384 bytes watched):** +000 vtable
  0x04DF0F40 (VA; convert with FFXiMain base, v0.2 logs it), +008/+00C pointers, +02C..+03C and
  +0C4..+0DC position floats (x,y,z + 1.0), +054/+058 **neighbouring CXiSkeletonActor objects in
  a linked list** (same vtable; churn as actors re-sort, corrected by F17; v0.2 misread them as
  clip pointers), +068/+06C scheduler list head/tail (0 when idle; nodes stride 0x140 in a pool
  at 0x21A8xxxx, first node often inline in the entity-side 0x24F7xxxx heap), +070 back-pointer
  to XiAtelBuff, +078 colour 0xC0808061 (fresh actor starts 0x80808080), +080 "routine playing"
  (1/0), +084 routine kind (2 for both burrow routines), +088 6 idle -> 2 during dig,
  +08C/+0BC mirrored float that ramps every frame while moving, +0B0 flag word
  (0xD400 idle actor, 0x16801 fresh actor, 0x6800 during pop routine). Packet byte 0x22 = 0x08
  during dig/pop, 0x00 after sub clear; byte 0x2B = 0x08 whenever sub=1 (name-hide /
  untargetable flags, decode against LSB's CHAR_NPC writer).

- **F16 [local] 2026-09-08 (wormwatch_20260908_052940.log, Q7 answered):** Locked worm
  idx=1021: one 0x0E (mask=0x0C, size 72, status=1 sub=1) at f621, routine ran 1.93s
  (ActionTimer1 f622..f678, same as F9's dig), scheduler list empty at f685, then **no packets
  and no actor changes for the remaining 30s** (actor alive, RenderFlags0 unchanged, nothing
  scheduled). User confirms worms normally sit underground like this until the server pops them.
  So **the client hid the worm with no status=3 at all: the dig routine's motion ends underground
  and the actor simply holds that pose.** status=3, when it does arrive (worm 54's roaming POS
  ticks in the same zone), additionally destroys the actor (F11) but is not what hides the model.
  Consequences: (a) LSB's unflushed INVISIBLE (companion §5/§6.1) is invisible on retail because
  the animation is the hide; (b) on pop, LSB's explicit UPDATE_POS carries the server's status=3
  so the client gets destroy-then-create and `init` runs on the fresh actor regardless of whether
  status=3 was flushed during burial; (c) Kuluu's held-buried-end-frame is the right mechanism and
  the 4s timeout is not reproducing anything retail does. Whether "roaming underground" vs "sits
  still" is `RoamAround` randomness is a server-side detail, not a client one.

- **F17 [local] 2026-09-08:** FFXiMain.dll base this session 0x04AC0000. RVAs: CXiSkeletonActor
  vtable 0x330F40 (actor +000; also at +000 of the +054/+058 objects, proving they are actors);
  actor +004 = rva 0x75010; scheduler pool-node vtable 0x32B680; first (entity-heap) node vtable
  0x32BB38; constant at node +014/+020 rva 0x32CF5C; node +08C rva 0x32D69C; node +004 rva
  0x32A210 / +06C rva 0x32A5EC (first node only).

- **F18 [local] 2026-09-08 (scheduler node layout, stride 0x140):** first node lives in the
  entity heap (0x24F8xxxx), later ones in a pool at 0x21xxxxxx. Common fields: +00C/+010 = actor
  ptr, +018/+024 = target index (0x3FD), +01C/+028 = 0x010643FD (idx | flags<<16), +02C/+030 =
  previous node, +034 = shared descriptor 0x24F815D0 (same across all nodes of one routine;
  first node has it at +044), +048..+05C six copies of a float (0.684), +074 = pool-adjacent
  object (node-0xB0), +078 = entity-heap object, +0A0 float (55/18/100), +0A4 stage kind
  (0x20000/0x10000/0x70000), +0A8 = 0x800, +0B0/+0B4 pointers into a third pool (0x21CF2xxx,
  likely parsed DAT scheduler data). **No routine or clip fourcc appears in the node itself**;
  a stale `jmp1` at +130 shows the pool is reused across routines (emote jump). The name must be
  behind +034 (descriptor), +074, +078 or +0B0. v0.3 crawls all of them once per object.

- **F19 [local] 2026-09-08 (wormwatch_20260908_054047.log, idx=956, full cycle with crawl):**
  Dig packet f806 (mask 0x0C, status=1 sub=1); status=3 at +3.02s (actor destroyed); pop packet
  f998 (mask 0x0D, status=1 sub=1) at +6.6s, new actor at +0x24F57480 (same address reused);
  sub=0 at pop+2.47s; pop routine lock ended pop+3.24s (again: sub=0 did not cancel it).
  User saw the LSB "pop down then up for one frame" glitch on retail too, so that is a server
  artefact, not a Kuluu one.

- **F20 [local] 2026-09-08 (CLIP NAMES, the key result):** The first node of each routine is a
  motion task (vtable rva 0x32BB38) with the **clip fourcc at +0x3C and its length in frames at
  +0x40 as a float**:
  - dig routine node: `sp10`, 112 frames (1.87s at 60 fps; measured lock 1.93s in F9);
  - pop routine node: `sp00`, 186 frames (3.10s; measured lock 3.24s in F9/F19).
  So **dig plays `sp1?` (=sp10) and pop plays `sp0?` (=sp00). Kuluu's DigDown->sp0? /
  PopUp->sp1? mapping is reversed** (F12 confirmed by name, not just duration). A second motion
  object class (vtable rva 0x32B654) also carries the clip name at +0x30 (`sp10`) plus the model
  id string at +0x44 (`em_b16_5`, 8 chars) and rva 0x32A5EC at +0x60.

- **F21 [local] 2026-09-08 (VFX generators):** Nodes reference generator records (pool
  0x21CF2xxx, 0x80 bytes, header 0x100/0x0C01) with a 4-char type at +0x1C: dig used `moku` and
  `dist`, pop used `kake`. That lines up with the DAT instance names `mok1`/`dis0` (dig) and
  `kak0`/`kak1` (pop). Per-routine split settled in F46.

- **F22 [local] 2026-09-08 (routine record):** A parsed scheduler record at 0x21CEF070 reads
  `+010='ini1' +028=0x402 +030='dis0' +038=0x307 +050=0x80A +054=5 +058='7024' +070=0x402
  +078='mok1'`, i.e. **`ini1` = {VFX dis0, sound 7024, VFX mok1}** with stage kinds 0x402 (VFX) and
  0x80A (sound). Since dis0/mok1 are the dig generators (F21), `ini1` is the dig routine, which is
  what H2 predicts (`ini` + sub value). The pop routine (sp00 + kak*) is therefore `init`, the
  auto-run-at-load routine, and it ran because the pop packet constructed a new actor. The
  companion doc's routine contents (init=dis0/mok1/7024, ini1=7025) are swapped relative to this;
  re-check `dat-burrow-dump.rs`. Stage time fields look like 0x1E (30) and 0xBC (188) frames.

- **F23 [local] 2026-09-08 (odd one):** This session's dig lock lasted only 1.14s (ActionTimer2
  1800->1734) versus 1.93s in F9/F16, with the same 112-frame clip. Unexplained; possibly the lock
  covers only part of the routine, or an early stage ended it. Not blocking.

### Static Phases 0 to 2 (F24 to F35)

- **F24 [local] 2026-09-08 (POL1 code packing, Phase 0):** `FFXiMain.dll` and `FFXi.dll` ship with
  `.text` rawsize = 0: the machine code is bit-packed LZSS-compressed in a custom `POL1` section and
  unpacked at load time by an entry stub at the tail of POL1 (FFXiMain EntryPoint rva **0xBB1A60**).
  Stub flow: on DllMain PROCESS_ATTACH (`cmp byte [esp+8], 1`) it does pushal, materializes the image
  base as `mov esi, 0x10000000` + `add esi, edi`(edi=0) at rva **0xBB1A77-0xBB1A83** (the "base-reloc
  trick": the DLL assumes its preferred ImageBase, DllCharacteristics has no dynamic-base bit), then
  calls the unpacker at rva **0xBB1AFB** with src = base+POL1_rva(0x9CC000), dst = base+.text_rva
  (0x1000) and size = &0x32762E (.text vsize). After unpacking, the stub applies the .reloc table
  (rva 0xBB2000) itself, walking blocks, adding byte addends to word RVAs inside .text, then
  `jmp rva 0x31676F` (the real DllMain in .text); non-attach reasons skip straight to that jmp.
  Unpacker format, verified instruction-by-instruction: tag byte = 8 ops MSB-first (`shl bl,1; jae`
  tests bit7 of the original byte); bit=1 → literal `out[dst++]=*src++`; bit=0 → back-reference b1,b2
  with off=(b2|b1<<8)&0xFFF (off==0 terminates the stream), len=(b1>>4)+3, byte-wise copy. The unpacker
  ignores its size argument and stops only at off==0; decoded length equals .text vsize exactly on both
  binaries (FFXiMain 0x32762E). Evidence: disasm rva 0xBB1A60-0xBB1B47 (`probe_entrystub.py`, scratch);
  `pol1_decode()` + auto-decoding `Image` in `common.py` (the scanner suite next to this doc). Consequence: every
  static scan below runs on the *decoded* .text; RVAs are unaffected.

- **F25 [local] 2026-09-08 (Phase 0 module map, p0_modmap.py):** Install dir `C:\PhoenixXI\SquareEnix\
  FINAL FANTASY XI`, all PE32 i386. `polboot.exe` 70KB, base 0x00400000, TDS 0x4B91EBA2 (2017-05-25),
  imports only KERNEL32(44)+ADVAPI32(3): has CreateProcessA/LoadLibraryA/GetProcAddress but **no ole32
  import and no `FFXiMain.dll` string** → the load chain is not a static LoadLibrary of FFXiMain; likely
  dynamic (COM or GetProcAddress-resolved; still open). `FFXi.dll` 91KB, base 0x10000000, TDS 0x6A7297E3,
  exports the 4 COM stubs + ole32 imports → **COM server**: registers ProgIDs `FFXi.FFXiEntry(.1)`
  ("FFXiEntry Class") and `FFXi.FxFileManager(.1)`; strings: "Returning to PlayOnline", FFXI-9000/9001
  error codes, `SOFTWARE\PlayOnline{US,EU}\InstallFolder`. `FFXiMain.dll` 2.83MB, base 0x10000000,
  **TDS 0x6A7297F5 = build-id fallback**, EntryPoint rva 0xBB1A60 (in POL1; F24), sections: .text
  rva 0x1000 vsize 0x32762E rawsize **0** (POL1-packed), .rdata 0x329000/0x26000, .data 0x34F000/vsize
  0x677B89 (raw only 0x85000, huge BSS), .data1 0x9C7000/0x1000, .rsrc 0x9C8000/0x3200, POL1
  0x9CC000/0x1E5C00, .reloc 0xBB2000/0x2F400; imports: 294 from 12 DLLs incl. WS2_32 (recv/send/
  select), d3d8!Direct3DCreate8, DSOUND, DINPUT8, WINMM, IMM32; exports the same 4 COM stubs as
  FFXi.dll; strings include `ROM/%d/%d.DAT`, `FTABLE.DAT`, `VTABLE.DAT`, sound path templates
  `c:\image\ffxi\sound\win\se\se%3.3u\se%6.6u.spw`, DAT names wr*.dat/ca.dat/sk.dat/..., and build
  machine path `D:\build0001\FFXi_Win\Main\Debug.cpp`. `FFXiResource.dll` 44KB, TDS 0x6A7295FA, no
  exports, KERNEL32-only imports. `FFXiVersions.dll` 56KB, **TDS 0x3D872923 (1999-09-21, not a build
  date)**, COM ProgID `FFXiVersions.FFXiVersion(.1)`. Also present: ImeUiDll2.dll/imeuidll.dll (IME),
  xinputdll.dll. `patch.sin` = 54-byte blob, printable `TTTTTTTTTTYaSD4U0kAkegbA7xTJWxZfSffo8@8oftvNxBmkD8lL7TT`
  ('@' breaks standard base64, custom alphabet or XOR; undecoded). `FTABLE.DAT` header: 28 u16 values
  0..0x1B followed by a run of little-endian u32s (first: 0x30924FBC, 0x309388, ...); role = file table,
  not yet decoded. Full per-module section tables + string lists: mob_evidence_1 §A.

- **F26 [local] 2026-09-08 (Phase 1 anchors located, p1_anchors.py):** All nine Phase-L RVAs fall in
  .rdata except 0x75010 (.text). Vtable slot lists dumped (until a non-.text pointer): CXiSkeletonActor
  vtable **0x330F40** = 64 slots, first: +0x00→0xC51A0, +0x04→0x1370, +0x08/+0x0C→0x2C940/0x2C930
  (shared base-class pair), +0x10..+0x14→0x1380/0x1390, **+0x18→0xC5550** (slot 6, the dtor/release
  called on actor destroy, F32), +0x2C→0xA4850 ... +0x7C→0xA4960, +0x84..+0x9C→0xD6FA0-0xD6FE0,
  +0xA0..+0xFC→0x82F30/0x82F70/0x84750-0x848D0. Motion-task node vtable **0x32BB38** = 64 slots
  (first: +0x00→0x3B540, +0x04→0x63050); generic scheduler node vtable **0x32B680** = 18 slots;
  motion object vtable **0x32B654** = 29 slots; first-node+0x04 table **0x32A210** = 7 slots; node+
  0x8C table **0x32D69C** = 6 slots; node+0x14/0x20 constant **0x32CF5C** = single slot 0x814D0;
  node+0x6C/motion-obj+0x60 table **0x32A5EC** = 43 slots. Raw VA references: the actor vtable is
  installed at exactly six sites, all in ctor funcs **0xC525E** (×4: rva 0xC5339/0xC55F9/0xC577B/
  0xC5919), **0xC59C0** (0xC5A50) and **0xC5B71** (0xC5C14); the key one is 0xC577B, immediately
  followed by `mov [ebx+0xA0], esi` at rva **0xC5783**, actor stored into entity ActorPointer, then
  `call rva 0xC5D70`. Class-name strings confirmed in .data: `CXiSkeletonActor` @0x35F634 (plus
  `CXiSkeletonActorRes` @0x35F620), `CYyObject` @0x3515BC, `SchedularTask`/`Scheduler` @0x35388F/
  0x35461C, `ROM/%d/%d.DAT` @0x37CD11. Full slot lists + ctor-site disassembly: mob_evidence_1 §B.

- **F27 [local] 2026-09-08 (fourcc literal sites, p1_anchors.py):** `push 'init'` (imm 0x74696E69)
  at rva **0x85F1E / 0x85F4F** (func 0x85F03), **0x8C56A** (func 0x8C561, actor = [esi+0xA0]),
  **0x8C5DC** (func 0x8C5A8), **0xAB4A5** (func 0xAB4A0), **0xC4A7F** (func 0xC4A3D), every one
  followed by `call [vtable+0x298]` (slot 165, F28). `cmp edi,'init'` at rva **0xCE26D / 0xCE5AC /
  0xCE79D** (the three init→ini0 resolvers, F29); `mov eax,'init'` @0xD104C (func 0xD1046). The
  rewrite target `mov edi, 'ini0'` (0x30696E69) at rva **0xCE28F / 0xCE5CE**. `push 'pop1'` @**0x90A4C**,
  `push 'pop0'` @**0x90A64** (both in the entity-update routine, F28). No `ini\0`, no `'ini1'`, and
  **no `sp00`/`sp10` immediates anywhere in .text**, clip/routine names are never code literals; they
  come from DAT data. Non-code 'init' hits in .rdata/.data/POL1 are C-runtime strings ("unable to
  initialize heap", R6025-R6027) and a table at rva **0x35AF54** holding `init ini1 ini2 ini3` ×2 plus
  `(N_IDLE)`/`(B_I...`, an idle-name bank, not the sub selector. Evidence: p1.md §3/§3b.

- **F28 [local] 2026-09-08 (PopEffect → pop0/pop1 confirmed in code):** The "PopEffect handler" is
  *not* a standalone function, it sits mid-way in a large per-entity update routine whose heuristic
  fragment starts at rva **0x90881** (`test ecx,ecx`; no prologue found scanning back to 0x90300).
  Decoded (mob_evidence_2 §C): gates = RenderFlags0 bit 0x200 "has actor" @0x909FA; Type(+0xEE) ∉ {3,4,5}
  @0x90A09-0x90A19; actor vcall slot +0x3F0 (slot 252) predicate @0x9089C region; `call rva
  0xD12E0(actor)`→bool @0x90A21. Then: PopEffect byte (+0x144) read @0x90A31; **value 3 → push
  'pop0' @0x90A64, value 6 → push 'pop1' @0x90A4C**, call `push 0; push actor; push fourcc;
  call [vtable+0x298]` = **CXiSkeletonActor vcall slot 165 (+0x298) = "run routine by name"**, the
  same slot used at every 'init' site (F27). Afterward `[esi+0x144]=0`. This matches F3's SDK comment
  exactly. Also in this routine: event-driven position sync via [esi+0xD4] (EventPointer/XiEvent*) +
  global table VA 0x10480B30 (rva 0x480B30, .data) indexed by u16 at event+2; entity→actor position
  copies ([esi+4]→[actor+0x34], [esi+0x14]→[actor+0x44]) with float clamps against constants at rva
  0x329D28/0x329D2C/0x329D30.

- **F29 [local] 2026-09-08 (init→ini0 resolver + state machine):** Func rva **0xCE241** (body at
  0xCE260): takes fourcc name (arg in edi) + object (ecx); if name=='init' AND vcall slot +0x1DC on the
  object returns P with *P!=0 → rewrite name to **'ini0'** @0xCE28F; then `call [vtable+0x400]` =
  "find routine by name" in the object's parsed DAT table, and validate the result via rva 0x71070.
  Sibling resolvers at func 0xCE59D (cmp @0xCE5AC) and **0xCE790** (cmp @0xCE79D). Caller of 0xCE260
  found: rva **0x5CC16 in func 0x5CBFF** (passes ptr, edi&0xFFFFFF, 0xFFFFFF + ecx=ebx). Callers of the
  sibling 0xCE790 (five, all in funcs ~0xD6B6B-0xD6C84) form a **state→fourcc switch machine**: reads two
  words ([eax+4],[eax+6]) from `call rva 0x18CED0` results and OR-builds fourcc bytes into esi ('i','b',
  'n','w' etc.) or pushes literals like **'ls05'** @0xD6C64; call convention `push name; push 7;
  mov ecx,obj; call`. So routine names are resolved through these resolvers against the DAT table , 
  consistent with H2's "names come from DAT data, not code" (F27). Evidence: d_ce241.md / d_d6b40.md
  dumps in mob_evidence_3 §D.

- **F30 [local] 2026-09-08 (s2c 0x0E CHAR_NPC handler, field-packing core identified):** p2_handler.py
  --dump ranked func rva **0x9BCF7** top candidate (score 50; signals S1 status byte, S2 animsub byte,
  S10 spawn flag 0x04). It is the field-packing core of the 0x0E handler: esi = packet buffer pointer
  (header-inclusive offsets), entity looked up via **global table VA 0x10480B30 (rva 0x480B30, .data),
  stride 4** (`mov eax,[edx*4+0x10480B30]` with edx = u16 target index at pkt+8). Packet fields: [esi+0xA]
  = update mask byte (bit 2 → block A @0x9BD0B; bit 4 → block B @0x9BDB9); [esi+0x1E] → ent+0xEC
  (just before Type@0xEE); [esi+0x2C] u32 → ent+0x188. **The "status" is a full u32 at pkt+0x20**
  (body+0x1C), unpacked with the XOR-diff toggle idiom (`xor new,old; and mask; store old^diff`) into:
  B0 bits 0/1/2 → RenderFlags0(+0x120) bits **0x2000 / 0x4000 / 0x40000** (status&7 packed at <<13,
  bit2→bit18); B0 bits 5-7 → `call rva 0x97A30(ent, val)` @0x9BECF; B1(pkt+0x21): bit0 → RFlags0
  0x400000, bits 1-2 → RFlags0 bits 30-31 (cleared-then-set via `and 0x3FFFFFFF`); B2(pkt+0x22) bit0 →
  +0x124 bit 0x400000; B3(pkt+0x23): bit0 → +0x124 0x1000000, low 3 bits → +0x128 bits 0x3800. Also:
  [ent+0x124] bits 17/18/19 cleared; [ent+0x140] &= ~0x8; (pkt+0x20)>>21 & 0xF → +0x128 bit 0x10.
  **animationsub (pkt+0x2A) is stored TWICE in RenderFlags1(+0x124): bits 1-3** (`shl 1; xor; and
  0xE` @0x9BE88-0x9BEAD) **and bits 13-15** (`shl 13; xor; and 0x6000` @0x9BE6D). This answers Phase
  2d "where is the old sub kept": it is packed in +0x124, not a named field. **StatusServer(+0x16C) ←
  animation byte (pkt+0x1F)** at rva 0x9C178, gated: skip if RFlags0 bit 1 set; else if
  ((pkt+0x28)&1) and anim ∈ {0x21,0x2F} or `call rva 0x957A0(anim)` true → skip. **So yes, 0x0E writes
  StatusServer**. u32 at pkt+0x24 unpacked into +0x12C bits (0x400/0x2000/0x40000) and
  calls `rva 0x8A9F0(idx, bit)` / `rva 0x8AA40(idx, bit)` @0x9C3F1/0x9C406; pkt+0x27 → +0x130 bits.
  The handler only *packs* flags: the status==3 actor-destroy and status==1 create happen in a consumer
  of those packed bits (pending, F32). Runner-up candidates: func 0xFAE5B (score 49, a different,
  word-granular unpacker into a big local struct; not entity-table based) and func 0x99E24 (score 49 , 
  position/pose update path, same entity table). Evidence: p2.lf.md top-15 + full disasm in
  mob_evidence_3 §E.

- **F31 [local] 2026-09-08 (tooling changes):** `common.py` in the scanner suite gained `pol1_decode()`
  (the F24 bit-packed LZSS decoder) and an auto-decoding `Image`: when a section is executable with
  rawsize==0 and a POL1 section exists, the payload is decoded once into `packed_text` so every scanner
  treats .text as if it were on disk (`read()`/`u32()`/`text()` fall back to the blob). All Phase 0/1/2
  runs below therefore operate on decoded code; RVAs are unchanged. p2_handler.py implements signals
  S1-S10 (see its docstring) and ranks heuristic functions by distinct-signal count + S1∧S2 bonus.
  Sweep cache: `--cache` flag persists the capstone sweep (~1.17M insns, ~34.6k heuristic funcs in
  FFXiMain) so follow-up runs take seconds. Evidence: common.py / p2_handler.py in-repo.

- **F32 [local] 2026-09-08 (actor destroy path, prime candidate identified, entry conditions pending):**
  All nine `[reg+0xA0]=0` store sites were probed; eight are stack-local zeroing (false positives).
  Func rva **0x928A3** at site **0x92966** is the prime destroy candidate: tests `ah&2` of [esi+0x120]
  (bit 0x200 "has actor"), checks `[esi+0x128]&4`, calls `rva 0xD44C0(actor, 3)` if set, then vcall
  `[vtable+0x18](actor, 1)` = **CXiSkeletonActor slot 6 (0xC5550)**, the dtor/release, stores
  [esi+0xA0]=0, then clears RFlags0 bit 0x200 (`and ah,0xFD`) and +0x128 bit 4. This matches F11's
  observed destroy exactly (ActorPointer=0, Flags0 0x00402200→0x00C16000). **Open:** which packed status
  bits gate entry to this func (expect RFlags0 0x2000/0x4000 combos for INVISIBLE=3, F30), and the
  matching create path (callers of ctor func 0xC525E / the `mov [ebx+0xA0], esi` @0xC5783), **answered by F34/F35**.

- **F33 [local] (method note):** Direct-call xref undercounts badly here -- the hot funcs (0xC525E actor ctor, 0xA4110 timer setter, 0x9BCF7 handler) all show **0 direct callers** because they are reached through vtables / pointer tables. Caller discovery must use `xref.py --imm <vtableVA>`, `--disp` on the entity/actor offsets, and slot-index reasoning, not `--to`. Recorded so the next session doesn't repeat the dead `--to` probes. mob_evidence_3 §F.2.

- **F34 [local] 2026-09-08 (xref re-run: root cause was mid-function targets; create path closed):** The "failed" xrefs of F33's session were not virtual-dispatch mysteries, they targeted addresses that are never direct call/jmp targets. Re-runs with corrected targets (`out2/x_*.md`): `--to 0x8F750` = **6** refs; `--to 0xC56F0` = **3**; `--to 0xC5890` = **2**; `--to 0xA4150` = **5**; `--to 0x92910` = **23**; still 0: `--to 0x908EC`, `--to 0xC525E`, `--to 0xA4110` (all mid-function / merged-registrar addresses). Consequences:
  - **Create path closed**: rva 0xC56F0 and 0xC5890 are *mid-function entries into func 0xC525E* (the ctor that installs the CXiSkeletonActor vtable, F26). Callers of entry 0xC56F0: @0x8F965 + @0x8F992 (both in the big entity-update routine, see F35) and **@0xD71F4 in func 0xD710D**, which immediately overwrites `[esi]` with a *different* vtable rva **0x3313E8** @0xD71FB (base-ctor + derived-vtable pattern). Entry 0xC5890: @0x8F9C9 + @0xD7229 (same overwrite @0xD7230).
  - **ActionTimer2=1800 setter**: "func 0xA4110" is actually two funcs, 0xA4110-0xA4143 is a global-table registrar (copies structs into the table at rva 0x485AB8, stride 0x140); the real setter starts at **rva 0xA4150** (`inc word [ecx+0x11C]; mov word [ecx+0x11E], 0x708; ret`) and has **5 direct callers**: @0x83317 (func 0x832AE, tail-jmp via actor back-ptr [ecx+0x70]), @0xA8F3C (0xA8EAB), @0xA8F67 (0xA8F53), @0xA9361 (0xA9286), @0xA938C (0xA9378). This corrects the "reached virtually, 0 direct callers" reading of the timer setter.
  - **Destroy entry rva 0x92910 has 23 call sites** (`out2/x_92910.md`): flush-loop family in 0x95xxx (incl. zone-wide entity sweeps `cmp reg, 0x900` at func 0x95909/0x9686D), @0x8A7D1 (func 0x8A7B2), @0x9F0C5 (func 0x9F07D, right after a PopEffect(+0x144) write), entity-table sweeps up to VA 0x10482F30 in func 0xB5B2B/0xB5BFE, and @0xB9C6D/@0xB9CA6 (func 0xB9BB0). Destroy is a **general primitive** (zone-out/delete/etc.), not status=3-only; the block itself still gates on RFlags0 bit 0x200 (§F).
  - `--imm 0x10330F40` = exactly the six known vtable-install sites (no other immediate uses); `--disp 0xA0 --size 4` = 1036 sites / 532 funcs (too noisy; top consumer func 0x92A7A with 26 sites sits right after the destroy func). Evidence: mob_evidence_2 §C.8-C.11 + mob_evidence_3 §F.3.

- **F35 [local] 2026-09-08 (true boundaries of the entity-update routine + create dispatch):** The per-entity update routine that F28 found mid-way at 0x908EC actually starts at rva **0x8F750** and ends ~**rva 0x926C7** (~12.1 KB). Prologue `sub esp,0x34; push ebx/ebp/esi/edi; mov esi,ecx` (thiscall, ecx = XiAtelBuff*); matching epilogues at 0x926AA and 0x926C0. The bytes at 0x8F72C-0x8F74B are a **jump table** (on-disk VAs into the small predicate func ending `ret 0x10` @0x8F729), that is why linear sweeps desync there and why F28's "no prologue found" was wrong. Structure:
  - **Create dispatch @0x8F7FF-0x8F9D4**: if RFlags0 bit 0x200 "has actor" set → `jne 0x90633` (update path, no create). Else: Status←StatusServer ([esi+0x170]←[esi+0x16C]), pre-set bit 0x200, then **Type(+0xEE) switch**: Type==3 → alloc(0x894)+init rva 0xAC8F0 @0x9030B; Type==4 → alloc(0x600)+init rva 0xC39A0 @0x90082; Type==5 → alloc(0x794)+init rva 0xC4200 @0x8FDDD (alloc = `push size; push 4; push 0; call rva 0x28FE0`, then base ctor **rva 0x74900**); else (normal NPC/mob, incl. worm Type=2) → alloc(0xA0C)+CXiSkeletonActor via func 0xC525E entries: **'spop' fourcc literal @0x8F958** (new, not in F27's list; stored at actor+0x8C4, cf. F4) when bit 23 of [ent+0x12C] is set, else name=0 via entry 0xC56F0 @0x8F992; index path (rva 0x87DD0(entity)==1) → entry 0xC5890 with index = byte[ent+0xEF]−1. Initial pos/rot from entity [esi+4..0x20], or, when the low RFlags0 byte is negative AND global byte [rva 0x480835]!=0, from event data ([esi+0xD4]+0x260 +0x140..+0x15C).
  - **Flush wrapper = rva 0x95DB0**: `if byte[esi+0x12C]&1: call destroy-entry rva 0x92910; call update/create rva 0x8F750; clear bit`, answers F32's open question on the destroy side: the destroy func is called by this wrapper whenever +0x12C bit 0 ("update pending") is set; the destroy block itself gates on RFlags0 bit 0x200. Wrapper call sites @0x95A58/0x95AEA/0x95BAB, each preceded by a **counter budget check**: counter rva 0x487E8C vs limit rva 0x35AF48 (`cmp; jge` skips the flush), entity updates are rate-limited per frame.
  - **Callers of rva 0x8F750: 6 sites** (a per-frame entity flush loop): @0x95050 (func 0x94FE8), @0x95A74 (0x95A43), @0x95B06 (0x95A81), @0x95BC7 (0x95B9A), @0x95D4C (0x95CC7), @0x95DC7 (0x95D9F); four of them `inc [rva 0x487E8C]` after the call.
  - **Angle-wrap correction to F28**: the "float clamps" against rva 0x329D28/0x329D2C/0x329D30 are actually **wrap-to-[−π,π]**: .rdata holds −3.1415 / +6.283 / +3.1415 (bytes C0 49 0E 56 / 40 C9 0E 56 / 40 49 0E 56 at file offset 0x1128); idiom `if v>π: v−=2π; if v<−π: v+=2π` applied to actor+0x44/+0x48/+0x4C and other rotation fields.
  - **+0x12C byte writers** (byte-level scan, 21 sites): setter API rva 0x2C3511 (`mov byte [esi+0x12C], al` with range check) called from only two entity-registration paths @0x253B83 (func 0x253B5A) and @0x254168 (func 0x25413A); `=8` write @0x2BD044; bulk-zero path @0x13BF89; two direct `=1` writes @0x212CAC/0x212CDF (register context not yet verified as entity). Dword-level: 500 sites / 254 funcs, incl. func 0x9C0FC's RMW of F30's bits 0x400/0x2000/0x40000. **Exact bit-0 trigger still open.** Evidence: mob_evidence_2 §C.5-C.11.

### Phase 3 static + Phase L v0.4, sessions 4 and 5 (F36 to F45)

- **F36 [local] 2026-09-08 (G1+G2):** RF3 (+0x12C) bit 0 = "rebuild pending". No
  status test inside the update routine 0x8F750..0x926C7; the gate is caller func
  @0x95DB0(ent): `test byte [esi+0x12c],1 / je skip / call 0x92910 / call 0x8F750
  / and al,0xFE`, i.e. `if (RF3 & 1) { rebuild; update; RF3 &= ~1 }`. Three call
  sites, all in per-entity loops (@0x95A43 loop @0x95A58; @0x95A81 path via
  @0x95AEA which first writes `RF3 |= 0x20000000`; @0x95B9A loop @0x95BAB). G1 RMW
  list: bit-0 SETTER = `or [eax+0x12c],1` @0xB9121 (func 0xB90F0, actor from global
  table @0x10480B30 by index; reached only via the stdcall thunk table ~0xBC6AF , 
  callback registration); clear bit0+bit23 helper @0x87DC0 (`and [ecx+0x12c],
  0xFFF7FFFF`); clear bit23 only @0xBD378 (`and 0xFFFEFFFF`); two `and
  [esi+0x12c],ebx` in the caller loops @0x95A81/0x95C97.

- **F37 [local] 2026-09-08 (G3 + full dumps):** THE sub->clip dispatch, fully
  decoded:
  - Sub->fourcc table @RVA 0x35AF60 (.data): **inline fourcc array** (not
    pointers), index = RF1 bits 1-3 (`shr eax,1; and al,7` @0x8C5C8 / @0x8F091):
    `[init, ini1, ini2, ini3, init, ini1, ini2, ini3]`, sub 4..7 wraps mod-4.
    Verified byte-for-byte against on-disk .data (POL1 packing only affects .text).
  - Normalizer @0x8EF70(ent): live sub = RF1 bits 1-3; keeps a mirror in RF1 bits
    4-6 (`RF1 := low_nibble | (sub<<3)`); syncs actor+0x8A9 via setSub (+0xa8);
    routes to the change detector when not in steady state (steady: sub=4 &
    nibble=0, or sub=0 & nibble=4).
  - Change detector/applier @0x8EFD5, the real dispatch: compares RF1 bits 1-3 vs
    actor+0x8A9 (getSub, +0xa4) and the mirror nibble; on change: `setSub(new)`
    then plays `table[sub]` via vtable **+0x29C** and/or **+0x298**, gated by RF0
    bit 9 (+RF4 bit 2 if RF0 bit 13 clear, @0x8F0B2..D8), a check call to
    +0x2A0(actor, fourcc) (@0x8F097-0x8F0A5), and (sub>=4 path) requires RF2 bit
    29 set.
  - State dispatch func @0x8C490(ent): prologue, when RF2 bit 31 is clear: status
    byte +0xEE not in {3,4,5} && predicate 0xD12E0(actor) -> call 0xCF110(ent,0),
    set RF2 bit 31 ("initialized" latch). Entry skip when RF2 bit 29 "dispatched
    this cycle" (set @0x8C61A after processing; cleared with bit 30 by `and
    [esi+0x128],0x5FFFFFFF` @0x90CAD in a destroy/despawn-ish path). Jump table on
    **[esi+0x170] - 6** (byte map @RVA 0x8C680, jump table @0x8C670):
    - raw states {6, 50, 56} (idx 0/44/50) -> fishing helper 0x8C6D0(ent, state):
      plays **'fsh0'..'fsh3'** via +0x29c.
    - raw state 34 (idx 28) -> plays 'init' then **'inte'** (`push 0x65746e69`,
      bytes i-n-t-e, verified literal, unexplained; record as observed), both via
      +0x298; clears actor+0x7D8 to spaces.
    - raw states 64..83 (idx 58-77) -> 0xD60D0: loops 9x calling 0xD60F0 which
      builds fourcc **'wep'+digit** ('wep0'..'wep8') = weapon-attack clips.
    - all other states (<6, >=84, and the rest) -> sub-dispatch block @0x8C5A8:
      getSub->save; setSub(new from RF1 bits 1-3); play 'init' via +0x298;
      post-init hook 0xCF070(ent, actor); clear actor+0x7D8 to spaces; **then
      setSub(old) again**, unexplained (best hypothesis: transient sub for the
      duration of 'init'/post-init processing while the official update happens via
      @0x8EFD5). Open question.
  - RF2 (+0x128): bit 29 = "dispatched this cycle"; bit 30 = one-shot **'hen0'**
    pending, armed @0x95F9C (in tick SM func @0x95EA0) when a routine completes,
    which also sets status byte +0xEE := 2 and RF0 bit 2; consumed+cleared
    @0x8C628..0x8C662 after playing 'hen0' via +0x298 (skipped if status in
    {3,4,5}); bit 31 = initialized latch.
  - Second state machine @0x95EA0(ent) ("tick/advance"): gated by RF0 bit 5; keyed
    on [esi+0x170]-2, byte map @RVA 0x95FF0 (82 entries), jump table @0x95FE8 =
    [0x95ED5, 0x95EDE]; both blocks converge to the routine-end logic above.

- **F39 [local] 2026-09-08 (wormwatch_20260908_182632.log, v0.4, Carrion Worm idx
  102):** RF1 decode across a full cycle: dig sub=1 -> subA=1 (bits 1-3), RF1 bit
  0x800 cleared, RF1/RF2 bit 4 set, RF4 bit 7 set. INVISIBLE: RF1 |= 0x100, subA
  still 1. Pop packet (sub=1): new actor and **subA reset to 0**; RF1 returns to
  0x800 at lock start 2 frames later. sub=0 packet: only RF4 bit 7 clears; subA
  already 0; lock runs natural 94 frames. **RF3 never changed** (bit 0 / bit 23 not
  observable at frame granularity: set and consumed within one flush). **subB
  (bits 13-15) never changed**: F30's "second copy" is not a sub copy for this mob;
  re-read 0x9BE6D.

- **F40 [local] (H4, explains F13 vs F38):** sub=0 mid-routine is a no-op when the
  create path has already zeroed subA (this run, F13). It cancels the lock only
  when subA is still 1 at arrival (worm 100 in F38), i.e. a real 1->0 transition on
  a live actor dispatches a routine change (candidate: F29's init->ini0 rewrite).
  Race between create-path reset and packet order. Test: Lock ALL, several cycles,
  correlate `subA=1 -> subA=0` ENT lines with lock cuts.

- **F41 [local]:** RF4 (+0x130) bit 7 = "sub != 0" latch: set on the sub=1 packet,
  survives destroy/create, cleared on the sub=0 packet.

- **F42 [local] 2026-09-08 (wormwatch_20260908_182935.log, 3 Carrion Worms, 7 pop
  locks, 8 sub=0 packets; F38/F40 resolved, H4 dead):** subA is 0 at every sub=0
  arrival (create path resets it, F39); 5 of 6 sub=0 packets during an active pop
  lock did nothing (locks ran 94 ticks). The one cut (idx 100, 71 ticks, f8165)
  landed in the same frame worm 102's dig lock started; the F38 cut (f3362)
  likewise coincided with worm 102's dig start. Scheduler nodes are a shared pool
  (same node address used by both worms). Conclusion: sub=0 mid-routine is a
  no-op; the rare early lock release is cross-entity contention when another mob
  starts a routine in the same frame. Retail quirk, **no Kuluu action**, Kuluu's
  driver has no shared scheduler pool to contend over (validates `8fe705f`'s
  "sub->0 does not cancel" semantics). Not pursued further.

- **F42 note (death path):** StatusServer/Status -> 3 from the animation byte,
  HP -> 0, RF3 bit 28 set, short 19-22 tick lock; post-death disappear shows RF0
  0x00406000 (status=3, actor=0) **without** the 0x00C16000 bits INVISIBLE sets, so
  those extra bits (0x800000|0x10000) distinguish hide-from-INVISIBLE from
  hide-from-despawn.

- **F43 [local] 2026-09-08 (G4; resolves F30's open question, where the previous
  sub lives):** handler @0x9BCF7 maintains both RF1 copies itself via convergent
  XOR-diff writes (like the status bits in RF0). Branch condition @0x9BE55-0x9BE63:
  `if ((status_byte & 1) || ([pkt+0x28] dword & 0x4000000))` -> **variant B
  @0x9BE88**: `sub<<1; xor RF1; and 0xE` (full 3-bit write into bits 1-3 = the copy
  the dispatcher reads). Else **variant A @0x9BE6D**: `sub<<13; xor RF1; and
  0x6000` (2-bit write into bits 13-14, consumed elsewhere e.g. funcs 0x7A4C1 /
  0x7BDAD which test bit 13). Common tail @0x9BEA5: `RF1 ^= diff`. So: odd status
  or the +0x2B flag -> low copy; even status (2,4) without it -> high copy. Note:
  the tested bit is bit 26 of the dword at pkt+0x28 = **bit 2 of byte pkt+0x2B**
  (the byte after animationsub), not a bit of the sub byte itself.

- **F44 [local] 2026-09-08:** vtable slots on CXiSkeletonActor (vtable @RVA
  0x330F40): +0xa4 (slot 41) @0xA4B20 = getter of byte actor+**0x8A9**; +0xa8
  (slot 42) @0xA4B30 = setter of the same byte (`mov [ecx+0x8a9],al; ret 4`), so
  "set animationsub" is just a plain byte store. +0x298 (slot 163) @0xCEE50 and
  +0x29c (slot 164) @0x84CD0 = named-animation play slots: both resolve
  fourcc->entry via shared helper 0xCE490 / vtable slot +0x1EC, then start it
  (0x72FC0 global). +0x2A0 = a check method taking (actor, fourcc). Resolver
  0xCE490 walks the actor's loaded ANI clip linked list ([esi+8]=next) and
  special-cases 'init' at its tail.

- **F45 [local] 2026-09-08:** post-init hook family: 0xCF070(actor,actor): if word
  actor+0xB2 != 0 -> 0xCF0C0: if bit 7 of byte actor+**0x840** set -> clear it, try
  playing **'!kl1','!kl2','!kl3'** via 0xCEF10. Else (path B): latch bit 7 of
  +0x840 and call 0xCEF10 with sentinel **'!in?'** (`push 0x3f6e6921`), which in
  0xCEF10 expands to trying the candidate list @RVA 0x330F28 = ['!in1','!in2',
  '!in3']. Weapon path ~0xD608x tries '!f01'/'!f02' gated on bit 13 of +0x840. The
  **'!' prefix is a systematic convention** (only these literals in the whole
  binary: !f01, !f02, !in?, !kl1-3). Best inference: literal clip names with '!'
  marking internal/secondary clips. Open question, cannot verify against game data
  (PhoenixXI install ships FFXiMain.dll + FTABLE/VTABLE.DAT only, no ANI/DAT).

### Phase L session 6, log 20260908_231759 (F46 to F49)

- **F46 [local] 2026-09-08 (wormwatch_20260908_231759.log, Carrion Worms idx 100/101/102, v0.4;
  ROUTINE RECORD FORMAT + correction to F22):** the crawl caught both burrow routine records at the
  moment of dispatch, through the first scheduler node's +0x114/+0x118 pointers (dig: node
  0x2911A174 -> 0x261280A0 / 0x261280F8 at f6473, worm 101; pop: node 0x2911BF34 -> 0x261282F0 at
  f4382, worm 100). A parsed routine record is a flat **stage stream**: each stage begins with a dword
  whose low byte is the stage type and whose high byte is the stage length in dwords, header
  included (holds on all 12 consecutive stage boundaries in the two dumps). Types seen: 0x01 record
  header (2 dw); **0x5F sibling cross-reference** (4 dw, payload +8 = fourcc of the *other* routine);
  0x1F and 0x07 (3 dw each, unknown); **0x05 motion** (10 dw: +4 timing word 0x00640010 dig /
  0x00960002 pop, +8 clip fourcc, +0x10 and +0x14 = 1.0f, +0x1C = 0x00010028); **0x0A sound** (8 dw:
  +4 = 0 dig / 5 pop, +8 = sound id as four ASCII digits); **0x02 VFX generator** (4 dw: +4 timing,
  high u16 plausibly the start frame, +8 instance fourcc, +0xC pointer to the generator object);
  0x29 (4 dw, unknown; appears mid-stream in the pop routine, so not a terminator). Decoded:
  **dig = {xref 'init', motion sp1?, sound 7025, kak0@0x36, mok0@0x37, mok1@0x12, dis0@0x19}** and
  **pop = {..., sound 7024, mok1@0x6C, motion sp0?, kak1@0x08, 0x29, VFX@0x5A, ...}**. Both match the
  companion doc's DAT dump byte for byte (ini1 = sp1? + kak0/mok0/mok1/dis0 + 7025; init = sp0? +
  dis0/mok1/kak1/kak0/mok0 + 7024). **Correction to F22:** the fourcc at +0x10 that F22 took for the
  record's own name ('ini1') is the payload of the 0x5F cross-reference stage, i.e. the sibling's
  name. F22's record {dis0, 0x307, 7024, mok1} was therefore `init` (pop), not `ini1`, and F22's
  "the companion doc's routine contents are swapped" is withdrawn: dig = `ini1` = 7025, pop = `init`
  = 7024. Closes the companion doc's sound-attribution item and the sound half of Q5 (the routine
  carries the SE id as ASCII digits; the path template `se%3.3u/se%6.6u.spw` from F25 is the resolver).
  Raw dumps: mob_evidence_3 §G.1.

- **F47 [local] 2026-09-08 (spawn flag 0x04 is NOT masked by the client):** worm 100 was already
  underground when locked (SNAP f328: RF0 0x00C06000 = status 3, no actor) and carried RF1
  0x0200055A = **subA 5**, the raw wire value 1|0x04 stored unmasked in bits 1-3, RF4 bit 7 set
  (unwatched idx 676 spawn packet: mask 0x57 sub=5; a later mask 0x30 packet carried sub=1). With
  F37's table [init, ini1, ini2, ini3, init, ini1, ini2, ini3], sub 5 resolves to 'ini1' and sub 4 to
  'init': **the mod-4 wrap is what absorbs the spawn flag**, and the normalizer's steady states
  (sub=4 & nibble=0, sub=0 & nibble=4) are "zero with / without the spawn flag". Kuluu's
  `sub & !0b100` is equivalent for sub<4; indexing an 8-entry table with the raw 3-bit value matches
  retail exactly. On worm 100's pop (f2462) the create path reset subA 5 -> 0 as in F39 and 'init'
  ran the full 94 frames (ActionTimer2 read a stale 17096 before the pop; reset to 1798 at lock
  start). RF0 before the pop was 0x00C06000 vs 0x00C16000 after a live destroy: bit 16 (0x10000) is
  set by the destroy-from-live path and absent when the entity was first seen already hidden. RF3
  bit 23 ('spop') was 0 on all three worms; the zone-in case (Q4 lead, open items) is still
  untested because no watched worm spawned into view.

- **F48 [local] 2026-09-08 (lock statistics; F42 confirmed):** 6 dig locks all **56 wormwatch frames
  (1.94 s)**, 7 pop locks all **94 frames (3.24 s)**; one wormwatch frame is ~34.5 ms (client ~29 fps),
  so F42's "ticks" are these frames. 7 sub=0 packets arrived mid-pop (f2172, f2318, f2534, f4451,
  f4534, f4550, f6730): **7/7 no-ops**, every lock ran to 94. No early cut this session (the worms
  dug and popped on different frames). Cumulative over the three v0.4 logs: 12 of 13 mid-pop sub=0
  packets did nothing; the one cut coincided with another worm's dispatch in the same frame (F42).
  RF4 bit 7 latch (F41) reconfirmed 9 times. RF2: 0xA0020001 idle -> 0xA0020011 (bit 4) on dig;
  destroy -> create drops it to 0x00020001 (bits 29/31 cleared, matches `and 0x5FFFFFFF` @0x90CAD)
  and it returns to 0xA0020001 two frames later when 'init' dispatches (bit 29 dispatched-this-cycle,
  bit 31 initialized latch). RF1 on a fresh actor: 0x...112 -> 0x...180 (create) -> 0x...800
  (dispatch), as in F39.

- **F49 [local] 2026-09-08 (first non-burrow routines: engage, hits, death, despawn; worm 102,
  f5196-f6764):**
  - Engage: 0x0E mask 0x06 anim=1 (f5203) -> StatusServer 0->1 (F30's animation-byte path), HP
    100->24, RF3 bit 28 set; Status([esi+0x170]) 0->1 synced 7 frames later; RF3 bit 28 cleared on
    a later mask 0x03 packet (f5341). Actor colour word +0x78 C0808061 -> C0804141 on engage.
  - Every hit taken and every swing is a short scheduler routine on the worm's actor: locks of
    15-42 frames (0.5-1.4 s), actor +0x84 (ActType) stepping 4 -> 2 -> 3 -> 0xD. **ActionTimer1 is a
    count, not a bool**: it read 2 at f6218 when two routines overlapped (consistent with `inc word
    [ecx+0x11C]` @0xA4150, F34).
  - Records crawled from those nodes carry fourcc families never seen during burrow: **'dam2'/'dam3'/
    'dam4'** in a record made of 0x080A sound stages (f5207, right after the first player hit = damage
    reaction), **'atk2'/'atk3'/'atk4'** (f5220), **'at2?'** with 'skaz'/'dada' (f5196), **'hit1'**
    (f5897), 'main'. So melee reactions and swings use the same mechanism as burrow: named DAT
    routines resolved against the model DAT (0xCE490 / slot +0x400) and pushed as scheduler nodes,
    triggered from the action packet rather than from 0x0E. Which name is picked per action (attack
    id, hit vs miss, damage bracket) is the next thing to read; candidates are F37's weapon-state
    block ('wep0'..'wep8' via 0xD60F0) and the 0xD6B43 switch machine (F29). Raw excerpts:
    mob_evidence_3 §G.2.
  - Death: 0x0E mask 0x06 anim=3 (f6232) -> StatusServer 1->3, HP->0, RF3 bit 28 set; Status 1->3 at
    f6240 with a 22-frame lock. Despawn: 0x0E status=2 mask 0x30 size 72 (f6762) -> UpdateMask
    0x0F->0x00, actor destroyed, RF0 0x00402200 -> 0x00406000 (no INVISIBLE bits 16/23), RF1 bit 12
    set then bit 11 cleared. Matches the F42 death note.
  - Open: F37 calls +0xEE a "status byte" (gate `not in {3,4,5}`, and `:= 2` on routine completion),
    but +0xEE is `Type` per F6/F7/F28 (worm Type = 2). Re-read 0x8C490/0x95F9C to settle which byte
    is meant before building the raw-state machine on it.

### Phase L session 7, wormwatch v0.5, log 20260909_000019 (F50 to F53)

- **F50 [local] 2026-09-09 (wormwatch_20260909_000019.log, v0.5, Forest Hares idx 94/97 + 4 more
  auto-locked; MELEE = 'atk0' by name):** 98 decoded 0x28 packets. Every melee round (category 1),
  from both hares and from the player, carries **0x306B7461 in the 32 bits at bit 86**, i.e. the
  fields LSB packs as actionid=29793 / recast=12395 read as the fourcc **'atk0'**. WS/mobskill
  start (category 7) carries 0x65746163 = **'cate'** (LSB 24931 / 25972). These are LSB constants
  (grep the server for 29793 and 24931), presumably copied from retail captures; whether the client
  reads that dword as the routine name or derives it from the category is not settled, but the
  actor-side result is the same every time: **one routine per melee round, lock 24-26 frames
  (~0.85 s), starting the frame after the packet, hit or miss (react 8 vs 9 makes no difference to
  the attacker).** Crawls during those locks show the hare's attack motion clips **'at00', 'at10',
  'at20' and 'at21'** (the 'at?0'/'at2?' wildcard family), never the same one in sequence, so the
  variant is picked client-side; the packet's result `anim` field is 0 for mobs (players: 1 = the
  second swing of a double attack). Per-target result fields as decoded: react 8 hit / 9 miss / 24
  WS or TP-move hit; eff 32 damage, 64/96 crit-ish variants, 34/66 with msg 67 = critical; msg 1 hit,
  15 miss, 43 "readies", 185 WS/TP damage.

- **F51 [local] 2026-09-09 (TP moves):** the mob TP move is two packets ~15 frames apart: category 7
  ('cate', target = the mob itself, result param = mob skill id 259 = Foot Kick, msg 43) then
  category 11 (param 259, result react 24, **anim 3**, msg 185). **The category-7 "readies" packet
  starts no routine on the mob** (no lock, no node). The category-11 packet starts **two routines at
  once** (ActionTimer1 jumps by 2, a third joins 2 frames later), total lock **40-44 frames
  (~1.4-1.5 s)**; a motion-task node carried **'sp10'** and a crawl showed 'wz60' (generator?). So the
  'sp' clip family is "special" per model (worm: sp0?/sp1? = dig/pop, hare: sp1? = Foot Kick), and
  the mob skill's `anim` value (3 here) is what the client turns into a routine/clip index; how 3
  maps to sp1? for this model is the remaining question (LSB `mob_skills.animation` is the server-side
  source of that number). Player WS: category 7 ('cate', param = WS id 1) then category 3 (param 1,
  react 24, anim 16, eff 97).

- **F52 [local] 2026-09-09 (target side):** being hit runs a **damage-reaction routine of 15 frames
  (~0.5 s)** on the target (f1987-f2002, f6156-f6171, f6478-f6493), overlapping freely with the
  target's own swing (ActionTimer1 counts both). Clips seen around those frames: **'btl0'/'btl1'**
  (battle stance), **'swy1'/'swy2'/'swy3'** (sway/knockback family, after the two-hit round at
  f6155), 'hit6', 'dfi6'/'dbi6' (recurring near reactions, meaning open). Engage: 0x0E mask 0x06
  anim=1 -> StatusServer 0->1, Status synced 7 frames later; ~9 frames after that a **14-frame lock**
  with no packet behind it (tentatively the idle->battle-stance transition, btl clips). Death: WS/TP
  kill -> reaction + death routines overlap (ActionTimer1 0->2 on hare 97), Status 1->3 when the
  packet's anim=3 syncs; hare 94's death lock ran 53 frames vs the worm's 22, so death length is
  per model, as expected for a DAT routine. Despawn 0x0E status=2 mask 0x30 = same flag pattern as
  F49.

- **F53 [local] 2026-09-09 (view-range despawn/respawn):** hares 94, 99 and 190 each went through
  UpdateMask 0x0F->0x00, RF0 -> 0x00406000, actor destroyed, then (when back in range) UpdateMask
  0x00->0x0F, RF0 -> 0x00402200, new actor, RF2 0xA0020001 -> 0x00020001 -> 0xA0020001 two frames
  later. Identical to the pop-up create path: **leaving and re-entering view is a destroy/create and
  replays 'init'.** Also seen unwatched: idx 110 with sub=8 (does not fit RF1's 3 bits; the handler's
  `shl 1 / and 0xE` drops it to 0) and idx 966 status=3 sub=1 mask 0x3F.

### DAT side (F54, F55)

- **F54 [local] 2026-09-09 (ON-DISK MOB DAT FORMAT + the standard routine set; `dat_routines.py`
  against three user-supplied DATs, 5.DAT 'drak', 11.DAT 'grif', 32.DAT PC-type multi-section):**
  chunk header = name[4], u32 (type = low 7 bits, length = ((u32 >> 7) & 0x7FFFF) * 16 incl. header),
  two zero u32; type 0 'end.' terminates a section, more sections may follow. **Chunk type ids seen:**
  0x01 marker (model name), **0x07 scheduler routine**, 0x20 skeleton, 0x29 skeleton-adjacent,
  0x2A mesh, **0x2B motion clip**, **0x3D sound sample**, 0x45 info. Q8's chunk enumeration for
  mob DATs is therefore: 07 / 20 / 29 / 2A / 2B / 3D (+ 05 generators on models that have VFX, e.g. the
  worm; none in these three). **Scheduler chunk layout:** +0x20 u32 0x40 (stage area), +0x24 u32 0x50
  (first stage), +0x28 body length, +0x2C count; +0x40 a type-0 len-1 marker, stages from +0x50, a
  type-0 header ends the stream. The stage encoding is exactly F46's runtime record (low byte type,
  next byte length in dwords), so the client copies the chunk body into memory as-is. **New stage
  types beyond F46:** **0x03 = call another routine by name** (name @+8, u32 @+4 = start frame),
  0x57 = call variant (used for the v??? voice routines), 0x09 and 0x3B = references by name
  ('lhit'/'chit', 'wash'/'waso'), 0x3D/0x50/0x3E = group begin / separator / end (vdam = pick one of
  dam2/dam3/dam4, dam1 flagged 1), 0x28/0x29 carry 0x80808080 = colour/tint, 0x24 (payload 1 in
  atk0), 0x20/0x2F/0x59 (frame numbers, in the ati? attack routines), 0x21, 0x78. Motion stage
  timing: high u16 = frames (ati0 75 / ati1 60 / ati2 72 / dead 60 / cast 48 / static poses 2), low
  u16 open (often equals the high word or a small blend value). Sound stage name = 4 ASCII digits
  (global se file, F46) **or** the name of a type-0x3D chunk in the same DAT (dam1-4, atk1-4, swy1-3,
  ded1-3, idl1-2, skaz, shit = the mob's voice set). **The standard routine set is the same across all
  three DATs (35-39 names):** `init`, `pop0` (calls init + 0x28/0x29 tint stages), `dead` (ded? 60
  frames, call vded @38, then cor0), `corp` (cor? 2 frames), `atk0` (call **hwat**, call57 vatk, 0x24,
  0x32), `ati0/ati1/ati2` (motion at0?/at1?/at2? + call aloc + sound skaz + call dada at the hit
  frame), `atf0` (atm? = attack miss), `ldam`/`damg`/`sdam` (damage taken: 0x09 lhit/chit + sdam +
  vdam), `gurd`/`pary`/`shld`/`paly`, `sway` (call vswy), `cate` (call nerm + cast = TP-move ready),
  `cast` (ma0?), `caso/cabk/cawh/casm/canj/cait` (cast by school: call ner?/sei? + cast), `shot`
  (call mloc + ma2?), `shso/shit/shnj/shsm/shbk/shwh` (spell effect by school: eis?/st?? + shot + 0x3B
  wash), `chit`, `ntob` (sound idl1), `cnt0/cni0/cnf0` (11.DAT only), and the voice wrappers
  `vdam/vatk/vded/vswy`. **Names a routine calls need not be in the DAT:** hwat, aloc, dada, mloc,
  nerm, ner1-5, sei5, eis2-6, stso/stnj/stsm/stbk/stwh, hit2, lhit, wash/waso are absent from all
  three, so the resolver (0xCE490, F44: walks the actor's loaded list, 'init' special-cased at the tail)
  has a fallback chain into shared/common DATs. This is where the client-side attack variant pick lives
  (F50: 'atk0' -> hwat -> one of ati0/1/2 -> at00/at10/at20). Mob-specific extras (worm ini1 with sp1?,
  hare Foot Kick with sp1?) sit on top of this standard set. Consequence for Q3: **the name families the
  client asks for are fixed; every model ships the same ~36 routines plus its specials; the per-mob
  content is entirely inside the routines.** Tool: `dat_routines.py` (scanner suite); dumps in
  mob_evidence_3 §H.

- **F55 [local] 2026-09-09 (FULL-INSTALL CENSUS, `dat_routines.py --scan` over 445 ROM chunks by the
  agent: ~52.8k DATs, 29,259 with scheduler routines; `out2/datdump.zip`):**
  - **Client built-ins.** Names that routines call but **no DAT in the install defines**: `hwat`
    (1718 referencing files), `mloc` (1709), `aloc` (1645), `wash` (1747), `waso` (1728), `proc`
    (2059), `dcnt` (711), `hwmg` (324), `hwpc` (271), `hwso` (183), `rloc` (192), `ldad` (166), `show`
    (120), `aukl/auon/auk1/auo1/auk2/auo2`. These resolve in FFXiMain.dll, not in data: `hw??` = the
    "hand weapon" family (hwat picks and runs one of ati0..atiN, which is the client-side at00/at10/at20
    variant choice of F50), `aloc/mloc/rloc` = attack/magic/ranged attachment points, `wash/waso` =
    weapon swing sound hard/soft, `dada` (1853 refs, defined in only 3 files, ROM/309/7 and
    ROM/313/69-70) = the "deal damage" callback at the hit frame, i.e. the moment the target's damage
    reaction routine (F52's 15-frame lock) is started.
  - **Common effect library = ROM/0/0.DAT.** It defines 61 names referenced by other files: the
    casting element effects `ner1-5`/`nerm`, `eis1-6`/`ei11`, `st??` (stso/stnj/stsm/stbk/stwh/stnm
    ...), `hit1-9`, `sb00-09`, `pop1`, `tgt0`, `cst0`, `dmmg`. `ROM/90/57.DAT` defines `mdam` (5893
    refs, magic damage). So the resolver's search order (F44, 0xCE490 walking the actor's loaded list)
    is: model DAT -> loaded shared libraries (ROM/0/0.DAT and friends, plus the spell/ability effect
    DAT for the action) -> client built-in.
  - **Standard set confirmed at scale:** pop0 2463 files, cate 1929, vdam/vded/vatk/vswy ~1860, dead
    1849, corp 1841, atk0 1839, damg 1836, ldam 1832, ati0 1773, ati1 1715, atf0 1709, gurd 1661,
    sway 1648, pary 1559, ati2 1533, ati3 139, ati4 117, ati5 112, ati6 61, ati7 15. So models ship
    between 1 and 8 attack variants and `hwat` must pick among whatever exists. Specials: ini1 549,
    ini2 224, ini3 102, ini0 34, spop 42, pop1 24, hen0 15, wep0 349 / wep1 152 / wep2 85 / wep3 32,
    fsh0-3 ~130 each, !in1/!kl1 337, !in3/!kl3 169, !in2/!kl2 69. Every name family the client asks
    for (F37, F45) exists in data; nothing the client requests is unaccounted for. (`init` shows only
    959 because the parser's first version also counted mesh/motion bodies that happened to parse as
    streams, e.g. hh_b 406, sp00 183; the tool now restricts routines to chunk type 0x07, so re-scan
    numbers will be a little lower and cleaner.)
  - **0x59 = animation lock.** The DAT viewer on ROM/5/7.DAT ('wyve') decodes stage 0x59 as
    AnimationLock with a duration in 60/s scheduler ticks, and each stage carries a delay that
    accumulates into its start tick ("delay trails its op"). This is ActionTimer1/ActionTimer2 (F9,
    F23): the hare's ati? routines lock 1800-1750 = ~50 ticks, matching the 24-26 wormwatch frames of
    F50; damage reactions 28-30 ticks; the worm's dig/pop 112/188 ticks. **Correction to F51:** `cate`
    = {call nerm, call cast} has no 0x59 stage, so the category-7 packet produces no lock, but a
    routine does run (the ma0? cast pose plus the nerm glow); wormwatch could not see it because the
    watched head node was still occupied by the hit reaction. `atk0` has no 0x59 either; the lock
    comes from the ati? routine that `hwat` runs.

### External cross-check: PS2 decompile, xim, xi-tools, LSB (F56 to F58)

- **F56 [external, SE code] 0x28 dispatch, resolver, name construction (PS2 `xiatelnet.cpp`
  `RecvBattleCalc2`, `xisklactor.cpp`):**
  - `CXiSchStatus::Unpack` -> `CXiMainToCalc { m_uID, m_uCmdNo (4 bits), m_uCmdArg (u32), m_uInfo (u32),
    results[] }`. **The 32 bits at bit 86 are one field, `m_uCmdArg`, and it is a scheduler name.**
    LSB now has this as an enum (`FourCC`): `atk0` BasicAttack, `cate` SkillUse, `spte` SkillInterrupt,
    `cait`/`spit` item, `calg`/`splg`/`shlg` ranged start/interrupt/finish, `cawh cabk cabl caso canj
    casm cage cafa` casts by school, `sp??` the matching interrupts, `kesu` fade out, `hitl` sweating.
    The old "actionid 16 + recast 16" reading of F50 is withdrawn; F50's decode of the values stands.
  - Dispatch by `m_uCmdNo`: **1, 2** (melee, ranged finish) -> `SetAttack(stat)` = play `m_uCmdArg`
    ('atk0') with the target; **3, 4, 5, 6, 11, 13** (WS/spell/item/JA/mobskill/pet finish) -> the
    result-set handler (target reactions, damage); **7, 8, 9, 10, 12** (starts) -> play `m_uCmdArg` on
    the caster with itself as target, and if `(m_uCmdArg & 0xFFFF) == 'ca'` also `SetCastMagicID`.
    So category 7 plays `cate` (F55 correction confirmed by code).
  - `SetAction(res_id, target, stat)`: `ReverseFindRes(actor, type 7, id)` over the actor's loaded
    resource files -> `YmResource::sys_file` (**ROM/0/0.DAT**, `syst`) -> not found = nothing (stat is
    freed). `ActorFindResource` walks `KzObject::GetOsmResFile(i)` for every file attached to the
    actor, then the actor's own file. This is F44's 0xCE490 with names.
  - Built names: `GetBattleInSchResId` = `'in ' + ('0' + cib[4])`, `GetBattleOutSchResId` = `'out' +
    digit`; `cib` = the model's Info chunk (0x45) bytes, which also pick the attack motion pack for
    PCs (`amot_tab[race] + cib[3]`). PCs append per-race, per-weapon motion-pack DATs
    (`ReadStdMotionRes`, `ReadAtkMotionRes`, `ReadTechRes`, tables `base_skeleton_no_tab`, `amot_tab`,
    `amot2_tab`); **mobs load nothing extra**, the whole vocabulary is the model DAT + ROM/0/0.DAT.
  - The actor has `SetDamageMotion / SetGuardMotion / SetParryMotion` and the scheduler tag table has
    flinch (0x21/0x25, direction via `GetDamageDirId` -> the dfi/dbi/dfm/dbm front/back clips) and
    knockback (0x5E). The `damg/ldam/sdam`, `gurd`, `pary`, `shld`, `sway` choice is made from the
    result's `resolution` and `hitDistortion` (see F58).
  - `xiatelnet.cpp` `ExtMotionMode` state machine plays `hwat`, `kblt`, `bntg`, `sit0/sit2`,
    `res0/res2`, `wait`, `coff` on gear/stance changes: `hwat` is requested by code too, and resolves
    to nothing when no loaded DAT has it (see F58).

- **F57 [external] scheduler op table with SE task names (xi-tools crosscheck + xim parser), the ops
  that occur in mob routines:** header = `op u8, len u8 & 0x1F (dwords), delay u16 @+4, duration u16 @+6`;
  delay accumulates into the start tick, duration is how long the op lives (60 ticks/s). SE: sec1
  `init_tag`, sec2 `idle_tag` (the timed list), sec3 `die_tag`, `total_frame`.
  0x01 start, 0x02 fire generator (`YmGenerater::Activate`), 0x03 call routine on source, 0x05
  skeleton animation (`XiSkeletonActor::FindModResList`; payload: fourcc, 2 f32, transIn u16, 0,
  transOut u16, maxLoop u16), **0x07 and 0x59 AnimationLock** (0x07 = `BondageActor`/lock, 0x59 =
  `LockCasterMagic` in SE's names, xim treats both as AnimationLock; the worm dig record's 0x0307
  with dur 0x70 = 112 is the F9/F23 lock), 0x09 call routine on target, 0x0A/0x0B/0x4A/0x53/0x60
  sound (source / target / variants; 7-arg form is an emitter, 4-arg form is a linked routine), 0x1F
  and 0x20 `LockActorStatus`, 0x21/0x25 flinch (source / target), 0x24 `YmParentTask::Suspend` on
  result, 0x28 transition to idle, 0x29/0x2A actor colour fade (`ActorColorDriveTask`; payload RGBA,
  0x80808080 = neutral), 0x2B status message (`PutMessage`; xim: damage callback), 0x2E/0x2F lock
  caster control / rotation (facing lock), 0x32 broadcast toggle, 0x3B/0x3C blocking child, 0x3D/0x3E
  random-child open/close (0x50 separator), **0x5F = StopRoutine(name)** (xim), so F46's "sibling
  cross-reference" is really "stop the sibling": dig stops `init`, pop stops `ini1`, 0x5E knockback,
  0x74 disintegrate, 0x78 display dead, 0x85 kill. Full ~85-op list: xim `EffectRoutineParser.kt`.

- **F58 [external, xim `Actor.kt` + LSB modern packet] the action -> routine rules and the field
  decode, i.e. the driver:**
  - **0x28 per-result fields (LSB `0x028_battle2.cpp`, XiPackets layout):** `resolution` 3 bits
    (Hit 0, Miss 1, Guard 2, Parry 3, Block 4), `kind` 2 bits, `animation` 12, `info` 5 (Defeated 1,
    CriticalHit 2), `hitDistortion` 2 (None/Light/Medium/Heavy = 0/.25/.5/1.0, Heavy on crits),
    `knockback` 3 (levels 1-7), `param` 17, `message` 10, `modifier` 31, then optional proc (6/4/17/10)
    and spikes (6/4/14/10) blocks. wormwatch's "react" = resolution | kind<<3 (8 = Hit kind 1, 9 = Miss
    kind 1, 24 = Hit kind 3 = WS/skill), its "eff" = info | hitDistortion<<5 (32 light, 34 light +
    crit, 64 medium, 96 heavy, 97 heavy + defeated = the killing blow at f6252). Header: target count is
    6 bits + res_sum 4 bits (not one 10-bit field), `cmd_arg` 32 = the FourCC, `info` 32 (LSB sends
    the recast there).
  - **Melee round (xim):** enqueue `atk0` non-blocking = the voice wrapper (`hwat` + `vatk`), and
    separately the swing: standing still -> random from the model's `ati0..atiN`; moving ->
    `atf0 / atl0 / atr0 / atb0` (forward/left/right/back; `atf0` is "attack while advancing", not
    "miss"); off-hand `bti?`/`btf0`..; H2H kick `cti0`/`dti0`. Playback rate scaled so the swing fits
    the attack interval. Ranged: `shlg`. Ability ready: `cate`. Engage `in<n>`, disengage `out<n>`
    (n = weapon anim subtype = SE's cib digit). Death: `dead`, else `dea<appearanceState>`.
  - **The directional swings on shipped data `[V]`** (hume_m weapon-motion file 9672, kuluu's own parser): `atf0` and `atb0` both name motion clip `amb?` (68 frames, AnimationLock 64) — on that file advancing and retreating are byte-identical animations; `atr0` names `amr?`, `atl0` names `aml?`; standing `ati0/1/2` run 94–98 frames. **Which clip each name plays is per weapon-animation-type DAT:** the motion DAT resolved for a Hume M with equipped main-hand model 0 gives `atf0 → amf?`, `atb0 → amb?`, `atr0 → amr?`, `atl0 → aml?` — four distinct clips, so kuluu selects by routine *name* and its shipped-data test asserts the mapping instead of quoting one file. **No travelling swing carries a HoldRotation (op 0x2F), while all three standing `ati?` hold facing for 70 frames** — selecting them therefore also releases heading to follow the wire through the swing ([movement.md](movement.md) op 0x2F). Full table with SE offsets: [kuluu_gaps.md §G.10](kuluu_gaps.md); ported in kuluu `224625ff`/`98295262`, pinned on shipped data by `d1ce29ff` (play-test P6).
  - **Mob TP move (gap 1 closed):** the result `animation` id is an **FTABLE index**: file id =
    anim + 0x0F3C (anim < 0x200), + 0xC1EF (< 0x600), + 0xE739 (< 0x800), else + 0x14B07
    (`MobAbilityTable.kt`, from LSB `mob_skills.animation`). The client loads that effect DAT and
    runs its `main` routine with caster and target; that routine's SkeletonAnimation stage names the
    caster's `sp??` clip. Foot Kick = anim 3 -> FTABLE 0xF3F -> `main` -> `sp1?`. Spells and abilities
    resolve the same way through their own tables (`SpellAnimationTable`, `AbilityTable`). This is
    why `main` is the most common routine name in the census (6797 files): every effect DAT has one.
  - **Lookup order (xim `findResource`):** routine's own directory -> the DAT root -> the associated
    (target) actor's DAT for `0x09` calls -> `GlobalDirectory` = ROM/0/0.DAT -> warn, no-op.
  - **Built-ins are dead references.** `hwat aloc mloc rloc wash waso proc dcnt hw??` exist in no
    DAT; xim logs "Couldn't find child-routine" and continues, and its combat visuals match retail;
    PS2 `SetAction` no-ops on a miss the same way. Treat them as no-ops (warn once). The only
    programmatic resources SE registers at boot are particle meshes (`dist ring vlin ligt nulp disg
    damv`, `YmLoadSysResousce`).

## 5. Session log

| Date | Session | Findings |
|---|---|---|
| 2026-07-13 | web: Ashita docs, Bluegartr crash dump (pol.exe + FFXiMain.dll) | module roles |
| 2026-09-08 | web: Ashita v4 SDK `entity.h`, XiEvents 0x5E, lotus-ffxi | F1-F6 |
| 2026-09-08 | wormwatch v0.1, Tunnel Worm idx 56, one full cycle | F7-F15 |
| 2026-09-08 | wormwatch v0.2, idx 1021 locked + idx 54 (unflushed INVISIBLE reproduced) | F16-F18 |
| 2026-09-08 | wormwatch v0.3, idx 956, pointer crawl (clip names) | F19-F23 |
| 2026-09-08 | static: p0_modmap / p1_anchors / p2_handler --dump, POL1 decode, ActorPointer=0 probes | F24-F33 |
| 2026-09-08 | static follow-up: true function starts, xref re-run | F34-F35 |
| 2026-09-08 | wormwatch v0.4 logs 182632 / 182935 + p3_gates.py + full dumps of 0x8C490 / 0x8EF70 / 0x95EA0 / 0x9BCF7 | F36-F45 |
| 2026-09-08 | wormwatch v0.4 log 231759, 3 Carrion Worms, routine records at dispatch, engage/kill/despawn | F46-F49 |
| 2026-09-09 | wormwatch v0.5 log 000019, Forest Hares, 98 action packets | F50-F53 |
| 2026-09-09 | `dat_routines.py` on 5.DAT / 11.DAT / 32.DAT | F54 |
| 2026-09-09 | `dat_routines.py --scan` over all 445 ROM subdirs (`out2/datdump.zip`) | F55 |
| 2026-09-09 | external: xi-model-viewer, xi-tools, sruon/FFXI-PS2, xim, LSB four_cc.h + 0x028 | F56-F58 |

Wormwatch logs live in the local untracked wormwatch addon folder; scanner outputs in
local untracked `out/` and `out2/` folders. Observation record for F36-F45:
`.agents/skills/retail-observe/references/worm-burrow-routines.md`.

## 6. Open items

- **Exe-side DAT chunk dispatch (Q8).** Which constructor each chunk type id (07/20/29/2A/2B/3D/45/05)
  reaches. Start from the ctor sites (0xC525E, F26's node/motion ctor sites) with `xref.py --imm` and
  walk up to the loader that switches on the type id. Data side is done (F54); this no longer blocks
  the parser.
- **VFX generator resolution (Q5 VFX half).** The 0x02 stage's +0xC pointer to the generator object,
  and how an instance name (`dis0 mok1 kak0`) maps to a generator type (`dist moku kake`, F21).
- **RF3 bit 0 upstream.** The setter @0xB9121 is reached through the callback thunk table ~0xBC6AF
  (F36); who registers/fires it on a status transition is unread. Also: what else writes RF0 0x200
  besides the create pre-set and the destroy clear.
- **RF3 bit 23 / `spop` on zone-in (Q4 lead).** Never observed live (no watched mob spawned into
  view, F47). If bit 23 derives from the wire spawn flag 0x04, `spop` is the zone-in routine.
- **Engage mid-pop (Q6).** Only surfaced engagement was seen (F49). The natural interrupt window is
  the 2 s after pop-up.
- **F37 loose ends.** The `inte` literal played after `init` for raw state 34; the `setSub(old)`
  re-store after `init` in the default sub block @0x8C5A8; and the wording "+0xEE status byte" (gate
  `not in {3,4,5}`, `:= 2` on completion) when +0xEE is Type (E20). Re-read 0x8C490 / 0x95F9C.
- **`!`-prefixed clips (F45).** `!in1-3 !kl1-3 !f01 !f02` exist in data (F55) but their role is
  inferred, not read.
- **polboot -> FFXiMain load chain.** No ole32 import, no `FFXiMain.dll` string in polboot (F25);
  main-loop disasm pending. `patch.sin` (54-byte blob, custom alphabet) undecoded. FTABLE.DAT header
  (28 u16 then u32s) not fully decoded, though file id -> `ROM/(id>>7)/(id&0x7F).DAT` and the
  VTABLE/FTABLE lookups used in E16 work.
- Does the PhoenixXI ROM patch level match the DATs the `ffxi-dat` facts came from?

## 7. Kuluu-facing conclusions

- Dig clip is `sp1?`/`sp10`, pop clip is `sp0?`/`sp00`; Kuluu's DigDown -> sp0? / PopUp -> sp1?
  mapping is reversed (F20).
- Dig = `ini1` (7025, kak0/mok0/mok1/dis0), pop = `init` (7024, dis0/mok1/kak1/kak0/mok0). The
  companion doc's DAT dump was right; F22's swap claim is withdrawn (F46).
- sub=0 mid-routine is a no-op; never cancel a running routine on it (12/13 observed, the one cut
  was pool contention) (F42, F48).
- The dig animation is the hide. status=3 destroys the actor but is optional; Kuluu's 4 s
  invisibility timeout reproduces nothing retail does (F16).
- A pop is always a fresh actor and `init` replays on every construct, including view-range
  re-entry (F11, F53).
- Sub dispatch: index an 8-entry `[init ini1 ini2 ini3] x2` table with the raw 3-bit sub; the
  spawn flag is absorbed by the wrap, `sub & !0b100` is equivalent for sub < 4 (F37, F47).
- Every model ships the same standard routine set; the client-requested name families are fixed
  in code; built-ins `hwat aloc mloc rloc wash waso proc dcnt hw??` are dead references and should
  no-op with a single warning (F54, F55, F58).
- 0x28 `cmd_arg` is a FourCC routine name (`atk0`, `cate`, ...); melee plays it on the attacker,
  starts (categories 7-10, 12) play it on the caster; TP-move `animation` is an FTABLE index into an
  effect DAT whose `main` names the `sp??` clip (F50, F56, F58).
- Locks come from 0x07/0x59 AnimationLock stages, not from clip length; damage reactions are ~15
  frames on the target and overlap freely (F52, F55, F57).
- Routine-name miss is a silent no-op returning 0 (E7, F58).

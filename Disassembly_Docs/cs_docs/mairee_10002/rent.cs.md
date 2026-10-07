# Mairee (Upper Jeuno, zone 244) — event 10002, chocobo rental

Event DAT `ROM/21/53.DAT` (file 6064), block for actor `0x010F4048` (Mairee),
tag `10002` at offset `0x0001`. The chocobo block `0x010F4045` owns a trivial
`10002` at offset `0x0001` (one byte: `00` END). Strings are zone 244's string
DAT `ROM/25/53.DAT` (file 6664); message operands below are `ImidData`
references dereferenced to that file's indices.

Mairee stands at `-56.308 7.999 109.080`. The Phoenix server
(`scripts/zones/Upper_Jeuno/npcs/Mairee.lua` → `scripts/globals/chocobo.lua`)
gates the trigger in `xi.chocobo.renterOnTrigger`: the player needs the
Chocobo License key item, main level ≥ 20 (`levelReq = 20` for zone 244), and
Upper Jeuno is not a past zone, so no WOTG mission is required. Eligible, it
fires `startEvent(10002, price, currency, soundParam)` — the params land in
the work zone at `WZ[2]` = price, `WZ[3]` = currency (gil), `WZ[4]` =
soundParam (0 when the zone has a chocobo spawn `pos`, else 1; Upper Jeuno
has one, so 0). Not eligible, it fires `startEvent(10005)` (see
`../mairee_10005/reject.cs.md`).

On finish, `onEventFinish(10002, option == 0)` (the "Yes" branch) deducts the
price, grants `MOUNTED` for 900 s (level < 20) or 1800 s + `CHOCOBO_RIDING_TIME`
mods (level ≥ 20), despawns any pet, and warps the player to the chocobo spot
`{ 486, 8, -160, 128, BATALLIA_DOWNS }`.

Offsets are bytes into the 301-byte `EventData` of block `0x010F4048`.
"player" = `0x7FFFFFF0` (the zone master block), "chocobo" = `0x010F4045`,
"event entity" = `0x7FFFFFF8`.

## Entry — price gates

The three `IF`s steer on `WZ[2]` (the server's price): special values fall
through to a look-at beat, a normal price skips straight to the work slot
setup.

| off | op | operands | what it does | actor | kuluu status |
|---|---|---|---|---|---|
| `0x0001` | `0x02` IF | `WZ[2] == Imid[0]`=-3 | price −3 → fall to `0x0009`; else jump `0x000E` | — | DONE |
| `0x0009` | `0x1E` LOOK_TALK | target=player | NPC turns to the player and starts talking | Mairee | DONE (scene gate) |
| `0x000E` | `0x02` IF | `WZ[2] == Imid[1]`=-1 | price −1 → fall to `0x0016`; else jump `0x0019` | — | DONE |
| `0x0016` | `0x01` GOTO | `0x006A` | skip to the camera lock (`0x006A`) | — | DONE |
| `0x0019` | `0x02` IF | `WZ[2] == Imid[2]`=-2 | price −2 → fall to `0x0021`; else jump `0x0024` | — | DONE |
| `0x0021` | `0x01` GOTO | `0x006A` | skip to the camera lock | — | DONE |
| `0x0024` | `0x03` GET_STORE | `WZ[9] = Imid[3]`=138 | stash 138 in `WZ[9]` | — | DONE |
| `0x0029` | `0x1E` LOOK_TALK | target=player | NPC turns to the player and starts talking | Mairee | DONE (scene gate) |

## The rent pitch

| off | op | operands | what it does | actor | kuluu status |
|---|---|---|---|---|---|
| `0x002E` | `0x2C` SCHEDULOR | ent1=chocobo, ent2=chocobo, key=`kue0` | start the chocobo's `kue0` routine (kneel) | chocobo | DONE |
| `0x003B` | `0x02` IF | `WZ[4] == Imid[4]`=0 | soundParam 0 (normal) → fall to `0x0043`; else jump `0x004A` | — | DONE |
| `0x0043` | `0x1D` MESSAGE | 6721 | "You can rent a chocobo for {Num:0} gil. I see you currently have {Num:1} gil." | Mairee | DONE |
| `0x0046` | `0x23` MESWAIT | — | hold for dismiss | player | DONE |
| `0x0047` | `0x01` GOTO | `0x0052` | to the menu | — | DONE |
| `0x004A` | `0x1D` MESSAGE | 6722 | "You can rent a chocobo, but because your level is so low, you won't be able to ride for very long. Also, equipment that extends your riding time will have no effect." | Mairee | DONE |
| `0x004D` | `0x23` MESWAIT | — | hold for dismiss | player | DONE |
| `0x004E` | `0x1D` MESSAGE | 6723 | "If you still want one, it will cost you {Num:0} gil. I see you currently have {Num:1} gil." | Mairee | DONE |
| `0x0051` | `0x23` MESWAIT | — | hold for dismiss | player | DONE |
| `0x0052` | `0x24` QUERY | msg=6724, default=Imid[9]=1, cursor=Imid[4]=0 | open "Do you wish to rent a chocobo?" — option 0 "Yes, I do.", option 1 "No, thank you." | player | DONE |
| `0x0059` | `0x25` QUERYWAIT | — | hold until the player picks; choice → `WZ[0]` | player | DONE |
| `0x005A` | `0x02` IF | `WZ[0] == Imid[4]`=0 | "Yes" → fall through; else jump `0x0116` (No branch) | — | DONE |
| `0x0062` | `0x02` IF | `WZ[3] < WZ[2]` (case 4) | currency < price → jump `0x0108` ("not enough gil"); else fall | — | DONE |

## The ride — camera, choreography, mount

| off | op | operands | what it does | actor | kuluu status |
|---|---|---|---|---|---|
| `0x006A` | `0x46` DEFCAMERA | case 1 | lock the camera for the cutscene | — | DONE |
| `0x006C` | `0x42` CANCEL_DISARM | — | clear the cancel flag | — | DONE |
| `0x006D` | `0x27` REQSET | prio 0x0A, target=player, tag 0x14 | arm the player-part program (master block tag 20, offset 14229) — the player's fade/move/look choreography | player | DONE (scene gate) |
| `0x0074` | `0x53` WAITSCHEDULOR | ent1=chocobo, ent2=chocobo, key=`kue0` | hold until the kneel finishes | chocobo | DONE |
| `0x0081` | `0x2C` SCHEDULOR | ent1=chocobo, ent2=chocobo, key=`sit0` | start the chocobo's `sit0` routine (sit) | chocobo | DONE |
| `0x008E` | `0x5D` MUSICVOLUME | Imid[10]=32, Imid[11]=120 | music volume step | — | DONE |
| `0x0093` | `0x1C` WAIT | Imid[12]=60 | timed hold | — | DONE |
| `0x0096` | `0x2A` REQWAIT | prio 0x0A, target=player | hold until the player-part finishes | player | DONE (scene gate) |
| `0x009C` | `0x45` LOADEVENTSCHEDULER2 | file=Imid[13]=201, ent1=event entity, ent2=event entity, key=`chco`, Imid[4]=0 | load the `chco` (chocobo) event-scheduler routine | — | DONE |
| `0x00AD` | `0x27` REQSET | prio 0x0A, target=player, tag 0x15 | arm the player-part tag 21 (master block offset 14361) — an empty program (`00` END), a pure sync point | player | DONE (scene gate) |
| `0x00B4` | `0x45` LOADEVENTSCHEDULER2 | file=Imid[14]=200, ent1=event entity, ent2=event entity, key=`fdo0` | load the `fdo0` (fade out) routine | — | DONE |
| `0x00C5` | `0x1C` WAIT | Imid[15]=30 | timed hold | — | DONE |
| `0x00C8` | `0x4E` EVENT_HIDE | target=chocobo | hide the event chocobo | chocobo | DONE |
| `0x00CE` | `0x7E` CHOCOBO | case 1, target=player | mount-state cue on the player | player | DONE |
| `0x00D4` | `0x7E` CHOCOBO | case 2, target=player | attach cue (player onto the chocobo) | player | DONE |
| `0x00DA` | `0x1C` WAIT | Imid[15]=30 | timed hold | — | DONE |
| `0x00DD` | `0x2A` REQWAIT | prio 0x0A, target=player | hold until the player-part finishes | player | DONE (scene gate) |
| `0x00E3` | `0x27` REQSET | prio 0x0A, target=player, tag 0x18 | arm the player-part tag 24 (master block offset 14495) — the post-mount move | player | DONE (scene gate) |
| `0x00EA` | `0x1C` WAIT | Imid[16]=10 | timed hold | — | DONE |
| `0x00ED` | `0x45` LOADEVENTSCHEDULER2 | file=Imid[14]=200, ent1=event entity, ent2=event entity, key=`fdi0` | load the `fdi0` (fade in) routine | — | DONE |
| `0x00FE` | `0x2A` REQWAIT | prio 0x0A, target=player | hold until the player-part finishes | player | DONE (scene gate) |
| `0x0104` | `0x30` | — | clear the `ucoff_continue` flag (VM-internal) | — | DONE (default arm) |
| `0x0105` | `0x01` GOTO | `0x0111` | to the end-para write | — | DONE |

## End para

| off | op | operands | what it does | actor | kuluu status |
|---|---|---|---|---|---|
| `0x0108` | `0x1D` MESSAGE | 6725 | "You don't have enough gil." | Mairee | DONE |
| `0x010B` | `0x23` MESWAIT | — | hold for dismiss | player | DONE |
| `0x010C` | `0x03` GET_STORE | `WZ[1] = Imid[18]`=0x40000000 | set the end-para (failure marker) | — | DONE |
| `0x0111` | `0x21` EXECEND | — | end the request; VM sends c2s `EVENT_END` with `EndPara = WZ[1]` | — | DONE |
| `0x0112` | `0x00` END | — | program end | — | DONE |
| `0x0113` | `0x01` GOTO | `0x011B` | (unreachable from this program's flow) | — | DONE |
| `0x0116` | `0x03` GET_STORE | `WZ[1] = Imid[18]`=0x40000000 | No branch: set the end-para (failure marker) | — | DONE |
| `0x011B` | `0x21` EXECEND | — | end the request | — | DONE |
| `0x011C` | `0x00` END | — | program end | — | DONE |

## The player-part programs (REQSET children)

The three `REQSET`s arm child VMs on the player's request stack. The child
entry points are the master block `0x7FFFFFF0`'s tag offsets (all
`0xFFFF`-placeholder ids — REQSET entry points, not real events):

| tag | master offset | what it does |
|---|---|---|
| 0x14 (20) | 14229 | the rental choreography: fade out, move the player, look at the chocobo, talk |
| 0x15 (21) | 14361 | one byte `00` END — a pure sync point for the `REQWAIT` at `0x0096` |
| 0x18 (24) | 14495 | the post-mount move: speed, place, `c01i`/`c00i` routines, walk, fade |

### Tag 20 @ 14229 — the rental choreography

| off | op | operands | what it does | actor | kuluu status |
|---|---|---|---|---|---|
| 14229 | `0x32` MAIN_SPEED | 0x8000 | set the player's event move speed | player | DONE |
| 14232 | `0x45` LOADEVENTSCHEDULER2 | sub 0x8018, ent1=player, ent2=player, key=`fdo1` | load the `fdo1` (fade out) routine | player | DONE |
| 14249 | `0x55` WAITLOADSCHEDULER | sub 0x8018, ent1=player, ent2=player, key=`fdo1` | hold until the fade finishes | player | DONE |
| 14264 | `0x33` | 01 | adjust the player's `Render.Flags0` | player | §3 — undocumented flag bit |
| 14266 | `0x37` SET_EVENT_POS | x/z/y/heading work operands | set the player's event position + facing | player | DONE (scene gate) |
| 14275 | `0x1C` WAIT | 0x8005 | timed hold | — | DONE |
| 14278 | `0x45` LOADEVENTSCHEDULER2 | sub 0x818D, ent1=player, ent2=player, key=`c05i` | load the `c05i` routine | player | DONE |
| 14295 | `0x1C` WAIT | 0x8008 | timed hold | — | DONE |
| 14298 | `0x45` LOADEVENTSCHEDULER2 | sub 0x8018, ent1=player, ent2=player, key=`fdi1` | load the `fdi1` (fade in) routine | player | DONE |
| 14315 | `0x55` WAITLOADSCHEDULER | sub 0x8018, ent1=player, ent2=player, key=`fdi1` | hold until the fade finishes | player | DONE |
| 14330 | `0x5A` CODE_MOVE2 | case 0, goal work operands | store the move goal | player | DONE (scene gate) |
| 14338 | `0x5A` CODE_MOVE2 | case 1 | hold while the walk has frames left | player | DONE (scene gate) |
| 14340 | `0x33` | 00 | adjust the player's `Render.Flags0` | player | §3 — undocumented flag bit |
| 14342 | `0x1F` MOVE | case 0, goal work operands | start the calibrated walk | player | DONE (scene gate) |
| 14350 | `0x1F` MOVE | case 1 | hold while the walk has frames left | player | DONE (scene gate) |
| 14352 | `0x6F` SLEEP | — | yield until the wait time reaches 0 | — | DONE |
| 14353 | `0x1E` LOOK_TALK | target=chocobo `0x010F4045` | the player turns to the chocobo and starts talking | player | DONE (scene gate) |
| 14358 | `0x6F` SLEEP | — | yield | — | DONE |
| 14359 | `0x70` TURNWAIT | — | cancel the player's movement and advance | player | DONE |
| 14360 | `0x00` END | — | program end | — | DONE |

### Tag 24 @ 14495 — the post-mount move

| off | op | operands | what it does | actor | kuluu status |
|---|---|---|---|---|---|
| 14495 | `0x32` MAIN_SPEED | 0x8107 | set the player's event move speed | player | DONE |
| 14498 | `0x37` SET_EVENT_POS | x/z/y/heading work operands | set the player's event position + facing | player | DONE (scene gate) |
| 14507 | `0x45` LOADEVENTSCHEDULER2 | sub 0x818D, ent1=player, ent2=player, key=`c01i` | load the `c01i` routine | player | DONE |
| 14524 | `0x31` SMOVE | case 0, goal work operands | set the move goal + time | player | DONE |
| 14534 | `0x31` SMOVE | case 1 | hold until the player reaches the goal | player | DONE |
| 14536 | `0x45` LOADEVENTSCHEDULER2 | sub 0x8018, ent1=player, ent2=player, key=`fdo1` | load the `fdo1` (fade out) routine | player | DONE |
| 14553 | `0x1F` MOVE | case 0, goal work operands | start the calibrated walk | player | DONE |
| 14561 | `0x1F` MOVE | case 1 | hold while the walk has frames left | player | DONE |
| 14563 | `0x32` MAIN_SPEED | 0x8031 | set the player's event move speed | player | DONE |
| 14566 | `0x45` LOADEVENTSCHEDULER2 | sub 0x818D, ent1=player, ent2=player, key=`c00i` | load the `c00i` routine | player | DONE |
| 14583 | `0x1F` MOVE | case 0, goal work operands | start the calibrated walk | player | DONE |
| 14591 | `0x1F` MOVE | case 1 | hold while the walk has frames left | player | DONE |
| 14593 | `0x00` END | — | program end | — | DONE |

## Kuluu coverage notes

- **`0x1E` LOOK_TALK is handled end to end on the live path** — but not in
  `vm.rs`. It is owned by the scene gate
  (`ffxi-event/src/vm/scene.rs` `OP_LOOK_AND_TALK`), which is active whenever
  the session knows the player position (always in live play; the offline
  `zz-event-drive` harness does not attach a scene, so it falls to the default
  arm there). The scene arm emits `EventCue::ActorLookAt` (the "motion half":
  the entity turns toward the named actor), which the session translates to
  `CutsceneCue::ActorLookAt` and the renderer consumes at
  `kuluu-render/src/scheduler_runtime.rs` (rotates the actor's Transform to
  face the target). The "talk half" (the mouth animation) is **not** produced:
  kuluu has no talking-state / mouth-anim consumer, the same category as
  `0x7B` in `../cs-opcode-coverage.md` §3.
- **`0x37` SET_EVENT_POS** is likewise scene-gated (non-player actors emit
  `EventCue::ActorPlace`; the player-actor version keeps its width skip since
  the server round trip owns that path).
- **`0x33`** (two hits in tag 20) is a default-arm skip: it writes an
  undocumented `Render.Flags0` bit, recorded in `../cs-opcode-coverage.md` §3.
- **`0x31` SMOVE** is handled (the `ActorMove` cue on the non-scene path, the
  scene-gated move on the live path). Note the linear `zz-*` walkers desync on
  its case-1 poll (they assume the 10-byte width; case 1 is a 2-byte poll that
  yields until arrival), so a raw walk of tag 24 stops mid-program — that is a
  walker limitation, not a data issue, and the VM handles it correctly.

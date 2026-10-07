# Work order — Mairee chocobo rental CS (event 10002, zone 244)

The audit table. One row per opcode in execution order ("Yes" path, price 160,
soundParam 0). **Status is what a live headless capture proves, not what the
code intends.** Update `status` + `notes` as each row is re-verified; do not
claim a row DONE until its `verify` grep hits in a fresh `events.jsonl`.

- Source of the opcode list: `rent.cs.md` (same folder).
- Capture evidence: `C:\tmp\gfdrive\events.jsonl` (JSON lines, `type` tag;
  cues are `"cue":{"VariantName":{...}}`, FourCC keys serialize as byte
  arrays, e.g. `kue0` = `[107,117,101,48]`).
- Server ids in this zone: **Mairee = 17776712**, **event chocobo = 17776709**,
  **player = `local_player`**.

## Status legend

| status | meaning |
|---|---|
| `DONE` | verified in a live headless capture (cue emitted with right values, or behaviour observed) |
| `CODED` | code path exists; capture does not prove this row individually |
| `NOT DONE` | missing or broken — see notes |
| `N/A` | no observable cue (VM-internal, branch, or timing only) |

## Known breaks (fix these first)

1. ~~**`0x31` SMOVE ride-out is skipped (row 14524).**~~ **FIXED in `be95c4e`.**
   The scene gate now owns `0x31` for the player: case 0 latches the goal into
   `scene.motion` + `controls_position`, case 1 holds until arrival (the same
   arrival-based hold as the `0x1F` player arm); `OP_SPEED` also writes the
   VM's `move_speed` so non-player SMOVE/`0x1F` cues carry the right speed.
   Live capture: the ride-out walked (-61.1, 108.2) → (-68.45, 115.05) at the
   27-speed pace to the exact authored goal, and `fdo1` fired only after
   arrival. The DAT's MoveTime=90 budget was deliberately not used (the author
   set it ≈ walk duration; a budget cap would reproduce the flash).
2. **Event entity resolves to the event owner (Mairee).**
   `event_dialog.rs` L754 `event_entity = active.unique_no`;
   `resolve_actor` falls back to it for `0x7FFFFFF8`. So `chco` (file 201,
   the "chocobo" routine, row 0x009C) plays **on Mairee**, and `fdo0`/`fdi0`
   name her too (harmless for fades). Dump scheduler file 201 and check what
   `chco` choreographs; if it is the chocobo's, the resolution is wrong and
   should target the event chocobo (17776709).
3. ~~**The y↔z axis swap is UNCOMMITTED**~~ **COMMITTED in `cf5b264`**
   (`kuluu-session/src/session/event_transport.rs` `event_position` /
   `session_position` + comments/tests in `ffxi-event/src/vm/scene.rs`,
   `ffxi-event/src/runner.rs`). Every position row hangs on it.
   Wire = (x, y=ground, z=height); event VM = (x, y=height, z=ground).
4. `0x33` ×2 (rows 14264/14340): undocumented `Render.Flags0` bit, recorded in
   `../cs-opcode-coverage.md` §3. Cosmetic; no behaviour expected.
5. `0x1E` talk half (mouth animation): no consumer exists, same category as
   `0x7B`. Recorded, not implemented.
6. Headless runs **session only, no renderer**: fades, look-at rotations and
   animation playback are not observable; motion holds release on the
   DAT-length deadline sweep. Renderer-side consumption needs a GUI check.

## 1. Entry + pitch (Mairee's program)

| off | op | says | coded (path) | verify (headless grep) | status | notes |
|---|---|---|---|---|---|---|
| `0x0024` | `0x03` GET_STORE | stash 138 in WZ[9] | `vm.rs` `OP_GET_STORE`, VM-internal | — | `N/A` | proven only by the CS reaching the pitch |
| `0x0029` | `0x1E` LOOK_TALK | Mairee turns to player, talks | scene gate `scene.rs` `OP_LOOK_AND_TALK` → `ActorLookAt` → renderer `apply_cutscene_actor_cues` (rotation is renderer-only) | `actor_look_at` actor=17776712 target=local_player | `DONE` | cue 1 of last capture. Talk half (mouth) NOT DONE, no consumer |
| `0x002E` | `0x2C` SCHEDULOR `kue0` | chocobo KNEELS | `vm.rs` `OP_SCHEDULOR` → `ActorMotion` + same-pass bridge; renderer `dispatch_cutscene_motion` plays routine off the chocobo DAT, reports `CutsceneMotionDone` | `actor_motion` key `[107,117,101,48]` actor=17776709 | `DONE` | cue 2. Playback not visible headless; hold released by deadline sweep |
| `0x0043` | `0x1D` MESSAGE 6721 | price line | `vm.rs` `OP_MESSAGE` → `AwaitMessage` → `frame_to_dialog` + `substitute_nums` → `EventDialog` | `event_dialog` text "You can rent a chocobo for 160 gil…" | `DONE` | observed in last run |
| `0x0046` | `0x23` MESWAIT | hold for dismiss | `vm.rs` `OP_MESWAIT` parks on open frame | `dialog_dismissed` after advance cmd | `DONE` | advance worked |
| `0x0052` | `0x24` QUERY 6724 | Yes/No menu | `vm.rs` `OP_QUERY` → `AwaitChoice` | `event_dialog` with both choices | `DONE` | observed |
| `0x0059` | `0x25` QUERYWAIT | hold until pick | `vm.rs` `OP_QUERYWAIT`; choice → WZ[0] | send `end_event_choice` choice 0, then next cue fires | `DONE` | choice 0 accepted |
| `0x0062` | `0x02` IF WZ[3]<WZ[2] | enough gil? | `vm.rs` `op_if` | no "not enough gil" in capture | `N/A` | negative test only |

## 2. The ride (choreography)

| off | op | says | coded (path) | verify (headless grep) | status | notes |
|---|---|---|---|---|---|---|
| `0x006A` | `0x46` DEFCAMERA | lock camera | `vm.rs` `OP_DEFCAMERA` → `CameraLock` → `event_dialog.rs` `CutsceneScope`; released at every `EventSessionExit` (body never issues case 0) | `camera_lock` lock=true … lock=false at end | `DONE` | cues 3 and 18 (the unlock is the scope release, not a DAT opcode) |
| `0x006C` | `0x42` CANCEL_DISARM | clear cancel flag | `vm.rs` `OP_CANCEL_DISARM`, VM-internal | — | `N/A` | |
| `0x006D` | `0x27` REQSET tag 20 | arm player program | scene gate `scene.rs` `OP_REQSET` → `push_request(player, 0x0A, 20)`; child spawns from master block `0x7FFFFFF0` @ 14229 | tag-20 cues start flowing | `DONE` | fdo1/c05i/fdi1 present in capture |
| `0x0074` | `0x53` WAITSCHEDULOR `kue0` | hold until kneel done | `vm.rs` `OP_WAITSCHEDULOR` polls `action_running`; released by renderer report | `sit0` cue only after this releases | `DONE` | headless release = deadline sweep, not the renderer report |
| `0x0081` | `0x2C` SCHEDULOR `sit0` | chocobo SITS | as `kue0`, key `sit0` | `actor_motion` key `[115,105,116,48]` | `DONE` | cue 4 |
| `0x008E` | `0x5D` MUSICVOLUME | music step 32/120 | `vm.rs` `OP_MUSICVOLUME` → rides `AgentEvent::MusicVolumeChanged` | `music_volume_changed` volume 32 | `DONE` | observed |
| `0x0093` | `0x1C` WAIT 60 | timed hold | `vm.rs` `OP_WAIT` → `arm_wait` | timestamp gap | `N/A` | |
| `0x0096` | `0x2A` REQWAIT | hold until tag 20 done | scene gate `OP_REQWAIT` (prio ≤ 0x0A on player's stack) | tag-24 cues only start after | `DONE` | CS advanced |
| `0x009C` | `0x45` LOADEVENTSCHEDULER2 `chco` | load chocobo routine (file 201) | `vm.rs` `OP_LOADEVENTSCHEDULER2` → `Scheduler` cue → renderer `cache.defer` (non-fade) | `scheduler` tag `[99,104,99,111]` dat_id 30905 | `DONE` | cue 9 — **but actor=17776712 (Mairee)**, the event entity fell back to the event owner (known break 2). Dump file 201 to check intent |
| `0x00AD` | `0x27` REQSET tag 21 | arm sync point | scene gate REQSET tag 21 → child is one byte `00` END | releases the next REQWAIT | `DONE` | |
| `0x00B4` | `0x45` `fdo0` | FADE OUT | `vm.rs` 0x45 → fade-DAT id → renderer `cutscene.rs` L481 (screen fade, renderer-only) | `scheduler` tag `[102,100,111,48]` dat_id 30904 | `DONE` | cue 10, actor=Mairee (harmless for fades). Fade itself needs a GUI check |
| `0x00C5` | `0x1C` WAIT 30 | timed hold | as `0x0093` | timestamp gap | `N/A` | |
| `0x00C8` | `0x4E` EVENT_HIDE | hide event chocobo | `vm.rs` `OP_EVENTHIDE` → `ActorHide` → renderer despawn/hide | `actor_hide` target=17776709 hide=true | `DONE` | cue 11 |
| `0x00CE` | `0x7E` CHOCOBO case 1 | mount-state cue | `vm.rs` `OP_CHOCOBO` → `emit_mount_cue` → `Mount{STATUS_EVENT_CHOCOBO}`; the **actual** mount comes from the server's MOUNTED status → `wire_translate.rs` `mount_to_wire` | `mount` cue status 5 + `status_icons_updated` `[253,252]` | `DONE` | cue 12 + icons observed |
| `0x00D4` | `0x7E` CHOCOBO case 2 | attach player onto chocobo | same `emit_mount_cue` path | mount completes | `DONE` | attach confirmed by the mount working |
| `0x00DA` | `0x1C` WAIT 30 | timed hold | as `0x0093` | timestamp gap | `N/A` | |
| `0x00DD` | `0x2A` REQWAIT | hold until tag 21 done | as `0x0096` | — | `DONE` | |
| `0x00E3` | `0x27` REQSET tag 24 | arm post-mount move | scene gate REQSET tag 24 → child @ 14495 | tag-24 cues start flowing | `DONE` | |
| `0x00EA` | `0x1C` WAIT 10 | timed hold | as `0x0093` | timestamp gap | `N/A` | |
| `0x00ED` | `0x45` `fdi0` | FADE IN | as `0x00B4`, tag `fdi0` | `scheduler` tag `[102,100,105,48]` | `DONE` | cue 16, actor=Mairee (harmless) |
| `0x00FE` | `0x2A` REQWAIT | hold until tag 24 done | as `0x0096` | — | `DONE` | |
| `0x0105`→`0x0111` | GOTO / `0x21` EXECEND | end event | `vm.rs` `OP_EXECEND` → `Advance::Ended` → c2s `EVENT_END` | `cutscene_ended` + `zone_changed` to Batallia Downs | `DONE` | warp + `audit_gil` row −160 observed |

## 3. Player program, tag 20 @ 14229 (the rental choreography)

| off | op | says | coded (path) | verify (headless grep) | status | notes |
|---|---|---|---|---|---|---|
| 14229 | `0x32` MAIN_SPEED 0x8000 | set event move speed | scene gate `scene.rs` `OP_SPEED` → `scene.speed` (drives the walk lerp) | walk step size in `position_changed` | `DONE` | walk observed at sane pace |
| 14232 | `0x45` `fdo1` | FADE OUT (player-side) | as `0x00B4`, tag `fdo1` | `scheduler` tag `[102,100,111,49]` | `DONE` | cue 5 |
| 14249 | `0x55` WAITLOADSCHEDULER | hold until fade done | `vm.rs` `OP_WAITLOADSCHEDULER`; fades keep a timed hold (`arm_motion_holds`) | next cue after the hold | `CODED` | CS advanced; not individually timed in capture |
| 14264 | `0x33` 01 | undocumented `Render.Flags0` bit | default arm width-skip (`vm.rs` L3014 catch-all) | nothing | `NOT DONE` | recorded §3; cosmetic, no behaviour expected |
| 14266 | `0x37` SET_EVENT_POS | snap player to authored spot + facing | **player arm = width-skip** (`scene.rs` guard `actor != ZONE_PLAYER_ACTOR`); snap owned by the **server round trip**: LSB WPOS2(Event) → `event_transport.rs::receive` → `acknowledge_position(event_position(accepted))` (the y↔z swap, known break 3) | `position_changed` jumps to the authored spot | `CODED` | verify the jump lands on the DAT's work operands (x≈-72 region, ground≈120, height≈8) — axis-mixed values would read as "shoves you outside" |
| 14275 | `0x1C` WAIT | hold | as `0x0093` | gap | `N/A` | |
| 14278 | `0x45` `c05i` | camera routine | as `0x009C`, tag `c05i` | `scheduler` tag `[99,48,53,105]` dat_id 30906 | `DONE` | cue 6 |
| 14295 | `0x1C` WAIT | hold | as `0x0093` | gap | `N/A` | |
| 14298 | `0x45` `fdi1` | FADE IN | as `0x00B4`, tag `fdi1` | `scheduler` tag `[102,100,105,49]` | `DONE` | cue 7 |
| 14315 | `0x55` WAITLOADSCHEDULER | hold until fade | as 14249 | gap | `CODED` | |
| 14330/14338 | `0x5A` CODE_MOVE2 case 0/1 | store move goal; hold while frames left | scene gate player arm: case 0 sets `scene.motion`+`controls_position`, case 1 parks → walk is `tick_scene`'s lerp (`scene.speed*0.1*dt*1000`) publishing `SceneAction::PlayerPosition` | `position_changed` stream walking to the goal | `DONE` | |
| 14342/14350 | `0x1F` MOVE case 0/1 | start calibrated walk; hold | same scene-gate arm; each position → `encode_scene_actions` → `session_position` (**y↔z swap**) → c2s 0x015 POS + `PositionChanged`; server WPOS2 acks back | `position_changed` walking toward the chocobo on the ground plane | `DONE` | walk (-56.0,109.07,8.2)→(-72.3,120.5,8.0) observed — z stayed ~8 (no shove). Hangs on known break 3 |
| 14353 | `0x1E` LOOK_TALK | player turns to chocobo, talks | scene gate `OP_LOOK_AND_TALK` → `ActorLookAt{player→chocobo}` | `actor_look_at` actor=local_player target=17776709 | `DONE` | cue 8. Talk half NOT DONE |
| 14359 | `0x70` TURNWAIT | cancel movement, advance | `vm.rs` L1716: advance only | — | `N/A` | |
| 14360 | `0x00` END | done | `vm.rs` `OP_END` → `Done` → releases REQWAIT `0x0096` | ride section's next cue fires | `DONE` | |

## 4. Player program, tag 24 @ 14495 (post-mount move)

| off | op | says | coded (path) | verify (headless grep) | status | notes |
|---|---|---|---|---|---|---|
| 14495 | `0x32` MAIN_SPEED 0x8107 | set speed | scene gate `OP_SPEED` | step size | `N/A` | |
| 14498 | `0x37` SET_EVENT_POS | snap mounted player to ride spot | as 14266 (server round trip + y↔z swap) | `position_changed` jump to the ride spot | `CODED` | verify against the DAT's work operands |
| 14507 | `0x45` `c01i` | camera routine | as `0x009C`, tag `c01i` | `scheduler` tag `[99,48,49,105]` | `DONE` | cue 13 |
| 14524/14534 | `0x31` SMOVE case 0/1 | move over set time; hold until arrival | **scene gate owns it** (`scene.rs` `OP_SMOVE`, `ZONE_PLAYER_ACTOR`): case 0 latches `position_operands(2, false)` into `scene.motion` + `controls_position`, case 1 holds while `scene.motion.is_some()` — arrival-based, same as the `0x1F` player arm. No `actor_move` cue for the player's SMOVE anymore; the VM default arm (`vm.rs` `OP_SMOVE`) still serves non-player actors | `position_changed` ride-out at the SMOVE pace, `fdo1` only after arrival | `DONE` | fixed `be95c4e`. Capture: (-61.1, 108.2) → (-68.45, 115.05) at the 27-speed (walk) pace, exact authored goal (-68453, 115046, 8000) |
| 14536 | `0x45` `fdo1` | FADE OUT | as `0x00B4` | `scheduler` tag `[102,100,111,49]` | `DONE` | cue 15 — now fires only after the SMOVE leg lands |
| 14553/14561 | `0x1F` MOVE case 0/1 | walk to next goal | as 14342 | `position_changed` walking | `CODED` | walk path works (tag 20 proved it); pacing now correct — the SMOVE leg above is waited on before this starts |
| 14563 | `0x32` MAIN_SPEED 0x8031 | change speed | scene gate `OP_SPEED` | step size change | `N/A` | |
| 14566 | `0x45` `c00i` | camera routine | as `0x009C` | `scheduler` tag `[99,48,48,105]` | `DONE` | cue 17 |
| 14583/14591 | `0x1F` MOVE case 0/1 | walk to final goal | as 14342 | `position_changed` to the final spot | `CODED` | then the server warps to Batallia Downs |
| 14593 | `0x00` END | done | as 14360 → releases REQWAIT `0x00FE` | EXECEND + `cutscene_ended` + warp | `DONE` | |

## Re-running the capture

Stack: `cow-map`/`cow-world`/`cow-connect`/`cow-db` (docker, ports 48000/53231/53232/54001).
Driver (custom Windows headless, **not** the unix agent socket):

```
powershell -NoProfile -Command "Start-Process -WindowStyle Hidden -FilePath 'powershell.exe' -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File C:\tmp\gfdrive\driver.ps1'"
```

- stdout → `C:\tmp\gfdrive\events.jsonl`, stderr → `client.log`.
- Garfield must be at the stables: zone 244 near `(-56.3, 109.08 ground, 8.0 height)`
  (DB `chars`: `pos_y`=height, `pos_z`=ground). If elsewhere:
  `{"cmd":"move","x":-55.9,"y":109.08,"z":8.0,"heading":128}` (wire: y=ground, z=height).
- Talk: `{"cmd":"action","target_id":17776712,"target_index":72,"kind":{"kind":"talk"}}`
- Two answers: frame 1 (price text) advance, frame 2 (Yes/No) choice 0:
  `{"cmd":"end_event_choice","event_id":1078470418,"act_index":72,"event_num":0,"choice":0}`
- Kill: `powershell -NoProfile -Command "& C:\tmp\gfdrive\kill.ps1"`
- Grep helpers: `C:\tmp\gfdrive\grep.ps1`, `cstrace.ps1`, `selftrace.ps1`.

## Verified live (headless, 2026-09-25)

Full run with `be95c4e` + `cf5b264` in: 17 cues, fade order now `fdi0` then
`fdo1` (post-mount), ride-out walked at the 27-speed pace to the exact
authored goal, `fdo1` after arrival, final walk at the 80-speed pace to
(-72.30, 120.51), warp to Batallia Downs (zone 105), mount icons [253, 252],
`audit_gil` −160. No "flash": the post-mount choreography no longer races
ahead of the body.

## Fix queue (in order)

1. ~~SMOVE speed/hold/goal (row 14524) — the choreography race.~~ **DONE `be95c4e`, live-verified.**
2. Event-entity resolution for `chco` (row 0x009C) — dump scheduler file 201 to check what it choreographs (it resolves to Mairee 17776712 via the event-entity fallback; possibly wrong).
3. ~~Commit the y↔z axis swap (known break 3).~~ **DONE `cf5b264`.**
4. GUI check: fades, look-at rotations, kneel/sit playback, camera routines.
5. Cosmetic (recorded, no rush): `0x33` ×2, `0x1E` talk half.

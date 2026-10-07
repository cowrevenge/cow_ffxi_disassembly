# EVENT 503 — WHAT AM I ASKING (Southern San d'Oria new-character opening CS)

Source of truth: master block `0x7FFFFFF0`, zone-230 event DAT `ROM/21/39.DAT`, entry +0x37F1.
Every line below is one or more instructions in execution order; offsets are absolute into the
master block's data region (traceable in scratchpad `evt503_master_disasm.txt`).

**Related docs:** per-opcode semantics — `research/XiEvents/OpCodes/0xNNNN.md`.
This file is the per-ask breakdown + phase history for event 503 specifically.

> The `scratchpad evt503_master_disasm.txt` trace referenced below is a local working file, not in this vault.

## Cast (server ids)

| id | who |
|---|---|
| `0x010E6001` | guard — Temple Knight at the gate (your narrator) |
| `0x010E60D5` | Curilla — General, Temple Knights |
| `0x010E60D6` | Rahal — General, Royal Knights |
| `0x010E60D7..DC` | party — six returning Royal Knights (first speaker = D7) |
| `0x010E6068..6F` | knights — eight background Elvaan knights (establishing beat B4) |
| `0x57, 0x59, 0x4B, 0x7B…` | walkers — background NPCs with one-liner blocks |

## DATs the event reads on demand (nothing is stored)

| DAT id | file | contents |
|---|---|---|
| **30834** | `ROM/62/82.DAT` | camera routines `sNNN` (file operand 130 + base 30704); c043 verified: 2-point linear dolly, 600 frames |
| **30904** | `ROM/62/110.DAT` | fades `fdi1/fdo1/fdi2/fdo2` + overlay `ovl1` (operand 200) |
| **30912** | `ROM/94/123.DAT` | camera routes `vNNN` / `s004` (operand 208) |
| **32732** | `ROM/72/87.DAT` | gesture TPC package A: `tlk0/thk1` talk-think gestures (`0x66`, operand 20 → band-1 A = 20 + 32712; the B container is selected by waist, Fix 1 `9168480`) |

## Hold legend — what gates each step

- `[W n]` = WAIT n frames (n/60 s), VM-internal clock
- `[IN]` = player input gate (MESWAIT / QUERYWAIT)
- `[R tag]` = routine hold: host arms it from the routine's authored length in its DAT; the `0x55` wait parks until it drains
- `[REQ]` = REQSET/REQWAIT on a scene actor stack (NPC one-liner sub-script must run/drain)

## A. SCENE SETUP (+037F1–+0380F) — once, before anything is visible

| # | Ask | Instruction |
|---|---|---|
| A1 | Hide the player model | `EVENT_HIDE_SELF(1)` |
| A2 | Clear pending cancel state | `CANCEL_CLEAR` |
| A3 | Lock input into cutscene mode | `CLI_EVENT_MODE_LOCAL 0x81A6` |
| A4 | **TAKE THE CAMERA** from the player | `DEFCAMERA case 1` |
| A5 | Set SFX volume + music volume ×2 | `SOUND_VOL_SET / MUSIC` |
| A6 | Hide the HUD | `HIDE_HUD` |
| A7 | Stop the game clock | `STOP_CLOCK` |
| A8 | `[W 30]` settle, 0.5 s | |

## B. ESTABLISHING BEATS — narration over Sandy

Pattern per beat: camera routine + fade in → hold both → NARRATION → `[IN]` → fade out → hold camera to full length → hold fade → `[W 60]` black.

- **B1** Camera `s043` (c043 dolly, 600 frames) + `fdi1`. *"The fortress city of San d'Oria lies to the north on the great continent of Quon. The beating heart of an ancient kingdom, it is home to a thousand legends past."* `[IN]`
- **B2** (REQSET prio 99–102: background walkers start) Camera `s044`. *"But now, her reign of glory is but a memory. Heroes raise shining swords to the heavens no more."* `[IN]`
- **B3** Camera `s045`. *"The sun has set on the kingdom of knights. An old lion, never to rise again... Thus do some dismiss her now."* `[IN]`
- **B4** SHOW the eight background knights (render flags + unhide), REQSET tag2 each (walk into position). Camera `s006`. *"Yet young Elvaan knights still venture proudly into the wilds of Vana'diel, determined to triumph over any foe."* `[IN]` — then HIDE them again.
- **B5** PLAYER WALK-IN #1: `fdi1`, SET_SPEED, MOVE start+wait, camera `s046`, fade out, hold all, `[W 60]`.
- **B6** Camera `s077` + `fdi1`; REQSET 0x4B tag10; set event position; **`[W 480]` = 8 s long hold**; fade out; hold all.
- **B7** Camera `s048`. *"Should fortune favor [him/her], bards across the land will sing of [his/her] exploits for generations to come."* `[IN]`
- **B8** Camera `s049`; REQSET 0x7B tag2. *"Of course, [he/she] has only begun [his/her] rise to glory. No one can tell what [his/her] future holds."* `[IN]`

## C. APPROACHING THE GATE (+03C18–+03DA9) — camera source switches to 30912

- **C1** Show the player; re-lock input mode (0x8006); set event position + speed.
- **C2** Camera `v017` while PLAYER WALKS to the gate (MOVE start/wait); LOOKAT choreography; REQSET/REQEW on 0x64 tag2/tag3. Hold `v017`.
- **C3** Overlay `ovl1` on the EVENT ENTITY + camera `v000`; hold both. `[W 60]`.
- **C4** REQWAIT prio=110 guard: his background script must finish before he can act.
- **C5** Camera `v001` while PLAYER WALKS again; hold `v001`.
- **C6** SHOW the guard; LOOK_AT guard→player; three staged SET_FACING turns with `[W 60]` between each (he turns to face you).
- **C7** LOOKAT choreography; REQSET 0xDC tag4 + guard tag11; PLAYER WALKS once more; REQWAIT ×2.

## D. GUARD DIALOGUE (+03DAE–+03DD4) — every line bracketed by his gestures from 32732

- **D1** REQSET guard tag15 → his block loads `tlk0`. SHOW HUD; restore SFX volume. *"I say! Watch where you're going!"* `[IN]`
- **D2** REQSET guard tag17 → `thk1`. *"Oh, a new recruit, are you? That explains it!"* `[IN]`
- **D3** REQSET prio=5 guard tag18. *"Well, far be it from me to chastise someone on [his/her] first day. Still, as a citizen of San d'Oria, you--"* `[IN]`
- **D4** REQWAIT prio=5 guard: his gesture script must drain.

## E. THE EXPEDITION RETURNS (+03DDA–+03F42)

- **E1** SHOW the party (0xD7–0xDC). *"Wait, the expedition has returned."* `[IN]`
- **E2** Player looks at party; REQSET tag2 to ALL SIX (walk into position).
- **E3** Camera `v003` → hold; `[W 60]`; camera `v004` + `[W 170]` = 2.83 s.
- **E4** Guard WALKS while saying *"Halt! I must inspect your ranks for infiltrators."* `[IN]`
- **E5** Choreography; guard tag16 (`thk`); first knight (0xD7) tag4 (`tlk`): *"Oh, let us through. We are exhausted!"* `[IN]`; tag5 (`thk`).
- **E6** Camera `v00a` + `v005` holds; guard: *"Still I must check for infiltrators. As a Temple Knight, I am responsible for the safety of the citadel. You Royal Knights must cooperate."* `[IN]`

## F. CURILLA & RAHAL (+03F49–+04512) — camera `v006…v016` throughout

- **F1** 0xDA: *"Is this how you thank us, treating us like criminals!"* `[IN]`
- **F2** 0xD8: *"You Temple Knights have it easy, safe inside these walls. We have no time for your games!"* `[IN]`
- **F3** Guard: *"How dare you!"* (camera `v006`) `[IN]`
- **F4** Curilla: *"What is going on here?"* `[IN]` — she takes over the scene.
- **F5** Curilla: *"Welcome back, Royal Knights. You must be weary. After reporting to Prince Trion, shed your armor and see your families. Long have they waited for you."* `[IN]`
- **F6** Party lead: *"Yes, Lady Curilla!"* / *"Royal Knights, forward!"* `[IN ×2]`; all six walk off (REQSET tag3 each).
- **F7** Camera `v010/v011` holds; LOOK_AT choreography.
- **F8** Curilla: *"Those knights are back from a dangerous mission. Remember that sometimes rules can be bent."* / *"Take pride in your duties, and do not mind the trivial. Remember, we are the face of San d'Oria!"* `[IN ×2]`
- **F9** Guard: *"Yes, madam!"* `[IN]`; REQWAIT Curilla (gesture drains).
- **F10** Camera `v012`; Curilla to YOU: *"And to the new recruit, I say this: The glory of San d'Oria depends upon each and every citizen! Good luck!"* `[IN]`
- **F11** Rahal steps in: *"General Curilla, bravo. You are gifted with much sympathy."* `[IN]`; camera `v00b`; REQWAIT Rahal.
- **F12** Rahal: *"Without your Temple Knights, we Royal Knights could not patrol the wilderness. Your order is a sturdy pillar upon which we rest."* `[IN]`
- **F13** Curilla/Rahal exchange (camera `v014/v013`): *"We are not your servants, Rahal…"* / *"You seem drawn to the world outside, Curilla…?"* / *"None of your business. But your troops did look weary…"* / *"No, it is ever the same. No one can tell what Orcs may do next…"* / *"You know, Prince Trion and Prince Pieuje…"* `[IN ×5]`
- **F14** Curilla: *"Rahal, we needn't discuss this before the recruit. Shall we walk to the castle?"* / Rahal: *"It would be an honor! Let us enjoy a bottle of 812 Rolanberry in the warmth of my chamber."* `[IN ×2]`
- **F15** Curilla: *"Well, I prefer the strategy council room. I shall make Batallia tea should you thirst."* / Rahal: *"Hah! Ever the same, I see."* `[IN ×2]`; camera `v016`; they walk off (REQEW tag8/tag9).
- **F16** Guard narrates to YOU: *"That was General Curilla of the Temple Knights. Her order watches over the city and protects Chateau d'Oraguille."* / *"Rahal's Royal Knights, on the other hand, spy on our enemies and battle fiends."* / *"With such disparate duties, the two orders maintain a tense rivalry."* `[IN ×3]`; REQWAIT guard.
- **F17** Guard: *"Perhaps I could be of service. Is there anything in particular you'd like to know?"* `[IN]`

## G. THE MENU (+0451A–+045D6) — choice returns to the server as EndPara at event end

- **G1** QUERY_MENU: *"Something you'd like to know? / Nothing in particular. / I want to go out and do battle! / I want to go shopping. / I want to know more about adventuring."* `[IN: choice]` (WZ[0] = selection; dispatch is IF-not-equal chains)
- **G2** CHOICE 1 "battle" (+04535): load `tlk0`; *"Just got here and you're aching to leave, eh? Listen, the lands are wild beyond our gates, filled with fiends and their ilk."* / *"Right behind you is the Westgate. Beyond that, the wilds of West Ronfaure."* / *"Should you need directions, ask those around you…"* `[IN ×3]`; REQSET/REQWAIT guard tag3 → epilogue
- **G3** CHOICE 2 "shopping" (+0457D): load `tlk0`; *"Should you seek weapons, armor, or supplies, there are several shops in this area. Why not go have a look?"* `[IN]` → epilogue
- **G4** CHOICE 3 "adventuring" (+045AF): load `tlk0`; *"Ahh, recruits... Don't know which way to hold a sword and you think you're ready for adventures. Well, what would you like to know?"* `[IN]` → **SECOND MENU**:
  - **G4a** QUERY_MENU: *"What would you like to hear about? / Helping people. / Hunting monsters. / Making easy money. / Working for my country."* `[IN: sub-choice]`
  - **G4b** "helping": *"Ah, a commendable choice! …there was a lady in front of a house on Pikeman's Way. She may be in need of assistance."* + directions `[IN ×2]` → epilogue
  - **G4c** "hunting": *"Novices... Don't know your own limits until a fiend beats it into your head for you… gathering some hides for the Tanners' Guild"* + directions `[IN ×2]` → epilogue
  - **G4d** "money": *"Easy money, eh? Typical of a new recruit… the lumberyard in Northern San d'Oria should have work for you there."* + route (Victory Arch → Parade Grounds → Laborman's Way) `[IN ×3]` → epilogue
  - **G4e** "country": *"Ah, a commendable choice for a new recruit. Head to any city gate and inquire at the gatehouse…"* + directions `[IN ×2]` → epilogue
- **G5** CHOICE 0 "nothing in particular" (+045D9): straight to epilogue.

## H. EPILOGUE (two identical copies @+045D9 / @+047A2; every path lands here)

| # | Ask | Detail |
|---|---|---|
| H1 | **OPEN THE MAP** with tutorial + place marker labeled **"Ailevia"** at her authored position | `MAP_TUTORIAL` + `MAP_MARKER` (payload: work-slot coords + name "Ailevia" + type byte) |
| H2 | Copy item id **536** into WZ[2]; SAY *"Here, take this [item]. Give it to Ailevia in Victory Square. I'll show you where she is on your map."* `[IN]` | ← the "give coupon" beat: item 536, name inlined via `\x01\x05` control sequence |
| H3 | CLOSE_MAP; `[W 60]`; camera `s004`; SAY *"Open the Map option from the main menu, select Markers, and then scroll to the right…"* `[IN]` | |
| H4 | END_LOAD_SCHED 's004'; camera `v016`; load `tlk0`; SAY *"To give items to others, select Trade from the main menu. Don't you forget it!"* `[IN]` | |
| H5 | STOP_ACTION_SELF 'idl0'; fade out `fdo2` → hold | |
| H6 | **RESTORE_CLOCK**; `[W 120]` | game clock back |
| H7 | **GIVE THE CAMERA BACK** (`DEFCAMERA case 0`); `[W 120]` | |
| H8 | Fade in `fdi2` (loaded, not waited — completes as the event ends) | |
| H9 | **EXECEND → c2s 0x005B EVENT_END with EndPara = menu choice.** Event over. | |

## Counts (for the audit phase)

- ~40 REQSET/REQEW fan-outs + ~15 REQWAITs on scene actor stacks
- 28× `0x45` scheduler loads: sNNN ×9 (30834), fdi/fdo ×~16 (30904), ovl1, vNNN/s004 ×~17 (30912)
- ~30× `0x55` WAITLOADSCHEDULER holds — every one host-armed from DAT-authored lengths; duration operand = 0 everywhere
- `0x66` gesture loads on every guard line (32732 tlk0/thk1)
- ~45 MESWAIT/QUERYWAIT input gates, 2 QUERY_MENUs (one nested), 1 MAP_TUTORIAL/MAP_MARKER pair, item handoff id 536
- 8× MOVE start/wait pairs (player walk-ins + guard/party walks), SET_SPEED before each
- 1 STOP_CLOCK / 1 RESTORE_CLOCK, 1 HIDE_HUD / 1 SHOW_HUD, DEFCAMERA take/release, EXECEND → EVENT_END(EndPara=choice)

---

# PHASE 2 AUDIT — which asks have real code (verified against retail bytes this session)

Legend: **GREEN** = real end-to-end code both sides · **RED** = stub / no-op / dropped · **?** = needs a live check.
Evidence is `crate/file.rs:line` unless noted. Offsets are into the master block data (`evt503_master_disasm.txt`).

## Camera comparison ("is it the right direction/position?") → GREEN
- Parser reads kind 0x06 exactly as retail authored it; a test pins c043 against `ROM/62/82.DAT`
  (`ffxi-dat/src/camera.rs:479`): **Straight path, 2 points, Linear smoothing, no start/end-at-current flags**.
- Dumped the real bytes (scratchpad `dump_evt503_cam.py`):
  - c043 point[0] eye=(-13.70,-7.88,-32.48) lookat=(-24.75,-23.93,65.78) focal=500.14
  - c043 point[1] eye=( 25.21,-7.97,-28.99) lookat=( 36.37,-20.21,59.71) focal=500.16
  → a wide establishing dolly panning **west→east** over the city, looking down/north; focal≈500 ⇒ FOV≈42°.
- s043 (kind 0x07) = one `0x04` CameraRoute stage id=c043, duration=600, end_frame=600 → task runs 10 s.
- Application maps position→eye, target→look-at, focal→FOV via `2·atan(192/focal)` (`RETAIL_PROJECTION_HALF_HEIGHT=192`),
  roll rotates the up axis: `kuluu-render/src/cutscene_camera.rs:478 advance_cutscene_camera_task`, gated on
  `camera_locked && tasks.is_active()`. **Byte-level interpretation is correct; final visual confirmation needs a live run.**
- All sNNN (30834), fdi/fdo/ovl1 (30904), vNNN/s004 (30912) tags resolve to parseable kind 0x07 routines
  → `routine_units()` can arm every hold. Verified by walking the three retail DATs.

## Skip-to-end root cause → code is GREEN; runtime is ?
The WAIT* chain is correct and unit-tested, end to end:
- 0x45/0x66 push `(actor,key)` to `pending_action_starts` + emit cue (`vm.rs:1064,1143`); 0x5B/0x66 gate on the actor's entity Type (0x66 → {0,1,6}, 0x5B → {1,2,7,8}; a refusal is a silent no-op, B6 `64d7268`); host arms the real
  hold from the DAT length via `arm_motion_holds`→`routine_units` (`event_dialog.rs:1303`).
- 0x53/0x54/0x55 park while `action_running` = real armed hold **or** same-batch bridge (`vm.rs:616,1082-1115`);
  the bridge is spent by `take_cues()` and each later `step()` (`vm.rs:547,733`).
- `is_waiting()` stays true while parked on an action hold (`vm.rs:678`) so the host ticks it down every frame;
  a per-tick `Drive::Tick(SESSION_TICK_PERIOD)` drive exists with an explicit comment about this exact failure
  mode (`session/mod.rs:3969-3985`). A test proves a DAT-length hold arms and drains over ticks (`event_dialog.rs:1935`).
- **Therefore, if `dat_root` is present the event holds at each beat.** The live "skip to end" most likely means
  `cfg.dat_root` resolved to `None` in that run (install not detected / FFXI_DAT_PATH unset) so every WAIT* falls
  through after its one-frame bridge. CONFIRM: start kuluu with the install on `FFXI_DAT_PATH`, then watch for
  `kuluu_session::event_dialog` debug lines "the WAIT* hold falls through" when event 503 begins.

## Per-ask GREEN/RED table
| Ask | Opcodes (offsets) | Status | Evidence / note |
|---|---|---|---|
| A1 hide self | `EVENT_HIDE_SELF` +037F1/+03A2D | **GREEN** | VM emits `ActorHide{target: EVENT_ENTITY}` (`vm.rs` OP_EVENT_HIDE_SELF arm); render resolves it without excluding self (`scheduler_runtime.rs apply_cutscene_actor_cues`) |
| A2 cancel clear | `CANCEL_CLEAR` +037F3 | ok (no-op) | internal state; nothing to render |
| A3 cli event mode | `CLI_EVENT_MODE_LOCAL` +037F4 | ok (no-op) | input-mode flag; not modelled |
| A4 take camera | `DEFCAMERA` case1 +037F7 | **GREEN** | → `CameraLock{true}` (`vm.rs:1161`) → `cutscene.rs:382`; also hides HUD via `apply_cutscene_hud_hide:340` |
| A5 sfx/music vol | `SOUND_VOL_SET`/`MUSIC` +037F9-03801 | no-op by design (documented) | kuluu has no per-channel SFX/music volume model — only the user master volume (`kuluu-render audio.rs`); 0x5D MUSICVOLUME still rides AgentEvent |
| A6 hide HUD | `HIDE_HUD` +03805 | **GREEN** | HIDE/SHOW_HUD emit `HudHide{hide}` cue; an explicit show wins over the camera-lock default, cleared at session end (`cutscene.rs apply_cue`, test `an_explicit_show_hud_wins_over_the_camera_lock_and_clears_at_session_end`) |
| A7 stop clock | `STOP_CLOCK` +0380A | **GREEN** | emits `ClockHold{stop: true, hour: Some(8)}` — event 503's operand bytes resolve to refs[424]=8 (work@1 u16 LE), so the Vana clock holds at 8:00 AM; weather operand skipped (kuluu weather is server-driven). `drain_cutscene_clock` freezes `VanaClock`; test `a_stop_clock_cue_freezes_the_vana_clock_at_the_authored_hour` |
| A8 wait 30 | `WAIT` +0380F | **GREEN** | real timed wait (`vm.rs:884`) |
| B1–B8 camera+fade beats | `LOADEVENTSCHEDULER2` sNNN/fdi/fdo + WAITLOADSCHEDULER | **GREEN** (holds) / see fades note | camera task + fade via Scheduler cue; holds arm from DAT length. NOTE: hold order is fade-first then camera-after-[IN] (+03834 waits fdi1, +03858 waits s043) |
| B4/C6/E1 show-hide NPCs | `EVENT_HIDE` 0x4E (many) | **GREEN** | render arm in `scheduler_runtime.rs apply_cutscene_actor_cues` inserts/releases `CutsceneHidden`, coexisting with distance-cull; test `actor_hide_cue_hides_the_entity_and_unhide_releases_it` |
| C/D/E/F moves+faces+lookat | MOVE/PLACE/FACE/LOOKAT/STOPACTION | **GREEN** | real handlers `scheduler_runtime.rs:1925-2021` |
| D guard gestures | `LOADEXTSCHEDULER2` 0x66 tlk0/thk1 (32732) | **GREEN** | ExtScheduler plays gestures on actors (`scheduler_runtime.rs:1761`) |
| G menu + nested menu | QUERY_MENU/QUERYWAIT | **GREEN** | `select_choice`→WZ[0] (`vm.rs:530`); UI chain to EndEventChoice verified. EndPara WZ[1]-vs-WZ[0]: **resolved NOT-A-BUG** — see below |
| H1 open map+marker | `MAP_TUTORIAL`/`MAP_MARKER` | **GREEN** | emit MapOpen/MapMarker cues; new `kuluu/src/view_native/text_input/event_map.rs` opens the map screen with tutorial + "Ailevia" marker (5 tests) |
| H2 give item 536 + say | GET_STORE→WZ[2] + PRINT_MSG (\x01\x05 inline name) | **GREEN** (decode) | real-DAT test pins the entry to `{Item:0}` — tag `01 05 23 82 80` = item kind, param-ref → slot 0; trailing byte drops (`ffxi-dat dmsg.rs real_zone230_event503_coupon_line_decodes_item_marker`). Name resolution: `{Item:N}` fills from event-start params (`event_dialog.rs substitute_entity_names`); event 503 starts via s2c 0x32 with no params, so kuluu leaves the marker visible. Retail's 0x2B handler passes no message params either (research/XiEvents/OpCodes/0x002B.md) and GET_STORE wrote WZ[2] while the tag references slot 0 — no locally-grounded mechanism renders "Adventurer's Coupon" here; documented as known deviation. The coupon grant itself is server-side (`vendor/server/scripts/quests/hiddenQuests/New_Character_Cutscenes.lua onEventFinish[503]`) |
| H3 close map | `CLOSE_MAP` | **GREEN** | emits MapClose cue; `event_map.rs` closes the screen (test in module) |
| H6 restore clock | `RESTORE_CLOCK` | **GREEN** | emits `ClockHold{stop: false}`; `drain_cutscene_clock` thaws the Vana clock, with a session-exit safety thaw if still held (`a_session_exit_releases_a_still_held_clock`) |
| H7 give camera back | `DEFCAMERA` case0 +04xxx | **GREEN** | → `CameraLock{false}` (`vm.rs:1161`) |
| H9 end event | EXECEND → 0x05B EVENT_END(EndPara=WZ[1]) | **GREEN** | `runner.rs:225`→codec/event_transport; EndPara value see G note |

## EndPara WZ[1]-vs-WZ[0] — resolved NOT-A-BUG (Fix #6, no code change)
- Retail QUERYWAIT stores `selectedIndex - 1` into **WZ[0]** (research/XiEvents/OpCodes/0x0025.md); kuluu `select_choice` → `work_zone[0]` — matches.
- Retail c2s 0x05B EndPara = **PTR_Work_Zone[1]** in BOTH Mode 0 and Mode 1 (research/XiPackets/world/client/0x005B/README.md; same for 0x005C); kuluu `end_para = work_zone(1)` (`runner.rs`) — matches.
- Event 503's bytecode **never writes WZ[1]** (linear scan of the master block; only work-slot write is GET_STORE→WZ[2]=item 536). So retail's EndPara for this event is a stale zone-shared Work_Zone value (Work_Zone persists across events, research/XiEvents/Event VM Functions.md `getworkofs`); kuluu's Work_Zone is fresh per event (retail's persists across events in the zone), so kuluu sends EndPara=0 where retail may send a zone-stale value — pre-existing modeling decision, no observable difference for this event.
- Server side: LSB `vendor/server/src/map/packets/c2s/0x05b_eventend.cpp` uses the result for OnEventUpdate/OnEventFinish Lua + cutscene-option lock; `EventInfo::option` is never set non-zero in C++. **SSD zone handlers are EMPTY** (`vendor/server/scripts/zones/Southern_San_dOria/Zone.lua onEventUpdate/onEventFinish`) → EndPara has zero gameplay effect for event 503.
- Known deviation (documented, not fixed): kuluu does not send a Mode=1 UpdatePending 0x05B on menu select (`session/mod.rs` sends EVENT_END only at end); even if it did, its EndPara would be 0 (event 503 never writes WZ[1]) and SSD's handler is empty → no observable difference for event 503.

## Phase 3 RESULTS (all fixes landed; test counts after this phase)
- **Fix #4 MAP_TUTORIAL/MAP_MARKER/CLOSE_MAP (H1/H3)** — GREEN: cue arms in `ffxi-event` + session/snapshot plumbing, new `kuluu/src/view_native/text_input/event_map.rs` (5 tests), map-screen dialog routing.
- **Fix #5 minor opcodes (A5/A6/A7/H6)** — GREEN where a cue exists: `HudHide{hide}` + `ClockHold{stop, hour}` cues end-to-end (ffxi-event → session → snapshot → render); VanaClock gains freeze/thaw (`vana_time.rs`), all time consumers route through it; `drain_cutscene_clock` system in `cutscene.rs`. A5 SOUND_VOL_SET/MUSIC = no-op by design (no per-channel volume model). 7 new tests across ffxi-event/kuluu-render.
- **Fix #6 EndPara** — VERIFIED NOT-A-BUG, no code change (evidence above).
- **H2 item-name inline tag** — decode GREEN against real retail bytes this session: the handoff's open question was a misread; entry 7747's tag is `01 05 23 82 80` (data `[0x82, 0x80]` = param-ref to slot 0) + one trailing byte that drops. New real-DAT test `real_zone230_event503_coupon_line_decodes_item_marker` pins it.
- Test counts: ffxi-event **112** (+3), kuluu-session **457**, kuluu-render **1178** (--lib, +4), kuluu **462** (--lib), ffxi-dat **470** (+1). `cargo check --workspace` clean.
- Remaining: live-run confirmation of the full event (skip-to-end check with FFXI_DAT_PATH set to the install) — not done this session; nothing committed.

## Phase 3 fix order (from A1)
1. **ActorHide in kuluu-render** — add a real arm for `CutsceneCue::ActorHide{target,hide}` that toggles the entity's
   visibility (coexisting with distance-cull / server-invisible), + unit test. Fixes B4/C6/E1 reveals.
2. **EVENT_HIDE_SELF (A1)** — hide/show the local player model on `flag`.
3. Confirm skip-to-end at runtime (logs above); if a code bug surfaces, fix it here.
4. MAP_TUTORIAL/MAP_MARKER/CLOSE_MAP (H1/H3) — open map + place "Ailevia" marker.
5. Minor: STOP/RESTORE_CLOCK, SOUND_VOL_SET/MUSIC, HIDE_HUD direct cue.
6. Verify EndPara WZ[1]-vs-WZ[0] against retail before touching it.

---

# PHASE 4 — live playback GREEN start-to-end; a test-bug found & fixed; gate setPos is server-side

## What this phase proved (clean live run vs local LSB stack)
Event 503 now plays **start to end** with every authored instruction firing in order. The skip-to-end and both
stalls are gone:
- `CutsceneStarted(503)` → all **51 input-gated frames** on the G1→"adventuring"→G4a path, including **both branch
  choices**: frame 44 "I want to know more about adventuring.", frame 46 "Helping people."
- scheduler cues in authored order: s043→s044→s045→s006→s046→**s077 (8 s hold)**→s048→s049, then the v-tags
  (v017…v016 / v00a–v00c), s004, fdo2/fdi2 — matches sections A–H exactly.
- **camera lock take=true AND release=true** (`CameraLock{true}` @3109 ms, `{false}` @214076 ms) — H7 DEFCAMERA case 0
  now fires both; the earlier run's `release=false` is resolved.
- gestures(32732): tlk0/thk1 loaded on every guard line ✓ · actor moves: 49 ✓
- map open + marker **"Ailevia"** + close ✓ (H1/H3) · item **536 → slot 6** ✓ (onEventFinish reward)
- `event_ended` fires @216099 ms.

## The blocker this phase removed: the live test never recorded event end
The live test's `handle_event` had **no arm for `AgentEvent::EventEnded`**, so `tally.event_ended_at` stayed `None`
and the "event 503 ended" assertion could *never* pass — every run reported
`event 503 never ended (stop: playback deadline exceeded)` even though events.jsonl showed `event_ended`. No prior
session could have gotten a green verdict on this test as written. **Fix:** added the arm in
`kuluu-session/tests/event_503_live.rs handle_event`, gated on `cutscene_started_at.is_some()` (EventEnded is a unit
variant with no id, so gate on the 503 cutscene having started). After the fix the same run sails past event-end and
stops only at the setPos check.

## E4 stall root cause + fix (prior session's work, now live-verified)
Two compounding bugs parked the master at its REQWAIT forever:
- **Bug A — zombie child:** `step_stacks()` logged "dropping a child request…" on
  `StepResult::Unimplemented | Spun` but never called `remove_request()`. The zombie stayed on D7's stack, so
  `request_at_or_below(D7, prio≤3)` was always true and the master's REQWAIT parked forever. **Fix:** that arm now calls
  `self.remove_request(actor, index)` (`ffxi-event/src/vm/scene.rs step_stacks`).
- **Bug B — why D7/DA zombied:** 0x5A CodeMOVE2 had META `sets_ret: true` → the vm fallback returned Unimplemented for it;
  all six party children died on their first 0x5A. **Fix:** 0x5A is now a full alias of OP_MOVE (player lerp + NPC
  ActorMove cue + park-on-move-hold), and `opcode_meta sub_size(0x5A, mode)` returns `{0=>8, 1=>2}` — mode 1 must advance
  **2**, not the table's 8 (`ffxi-event/src/opcode_meta.rs`). Two regression tests in `vm.rs` pin both.

## The one remaining RED: gate setPos is a server reward that never surfaces as a WPOS here
onEventFinish[503] runs `giveItem(536)` then `setPos(-100, 1, -40, 224)`. In **two** live runs the map-marker tutorial
message + item 536 both arrived (so onEventFinish ran), but **no position update / WPOS reached our client**: last player
pos is (-98.81,-39.62,+1) at event end and zero `forced_move` events in events.jsonl. The client's WPOS path
(`s2c::WPOS|WPOS2 → decode::ForcedMove`, gated on `unique_no==self_char_id && mode.carries_position()`) is correct and
unit-tested; nothing indicates we dropped a packet. This is **server-side behavior in this LSB build**, not an event-VM
bug — the player is already within ~1.2 u of the gate, so setPos is only a final nudge that never reaches us.

**Recommendation (needs your call):** the test's hard `ForcedMove` assertion checks a *server reward*, not an event
instruction. Options:
- **(A)** relax it to a documented non-fatal check → "event 503 plays start-to-end" goes green; setPos noted as a known
  server-side gap. (My lean.)
- **(B)** keep it hard and treat full-green as blocked on a server-side fix / deeper WPOS investigation in the dev-live
  server code.

## Test counts after this phase
- ffxi-event **116** lib (+2 E4 regression tests) · kuluu-session **457** lib (unchanged; this session's only edit is the
  live-test file, not lib code). `cargo check --workspace` clean.
- Live artifacts: `artifacts/verify/event_503_summary.txt` + `events.jsonl` (post-fix run); the pre-fix "never ended"
  failure preserved as `*.stall_neverended.*`; the earlier E4 stall preserved as `*.stall_e4.*`.

---

# PHASE 5 — map draw-level proof, same-tick map decision, ESC lock-in root cause (0x42) fixed end-to-end

## 1. The map actually draws at the render level (headless, real recorded data)
- Root cause of "no map opens": `apply_cutscene_hud_hide` hid every HUD root while a cutscene camera lock is active —
  including both map roots (`MapScreenRoot`, `MapPanelRoot`). Retail's HIDE_HUD (0x67) only repositions the two event
  message boxes and sets CompassDraw (`research/XiEvents/OpCodes/0x0067.md` pseudocode: `PresetEventMessageMode` ×2 +
  `PTR_CompassDrow = 1`) — it never touches the map window, which is an event-opened MAPSCHEDULOR surface, not HUD chrome.
- Fix: `HudHideExempt` on both roots in `kuluu-render/src/hud/map_screen.rs` (`spawn_map_screen` + the MapPanelRoot
  spawn), extending Phase 3's dialog-panel exemption. Same-tick regression test proves a cutscene hide keeps the map
  roots visible while a plain root hides.
- Draw-level proof (not just "an open event was emitted") — 4 tests in `mod event503_draw` inside map_screen.rs:
  - `map_spawns_hidden_and_stays_there_without_opening`
  - `event503_map_beat_draws_the_map_with_ailevia_marker` — the real recorded beat (zone 230, marker "Ailevia" at
    world (-10.264, -0.363) from wire x_milli/y_milli): asserts both roots flip to `Display::Flex`, slot-0 dot lands at
    left≈39.736% / top≈49.637%, label "Ailevia".
  - `cutscene_hud_hide_keeps_the_map_roots_visible`
  - `closing_the_map_hides_it_again`

## 2. Same-tick open + marker + close = no visible flash (DECISION, test-pinned)
- Recorded run (`artifacts/verify/events.jsonl`): map_open{zone 230, tutorial} + marker "Ailevia" + the coupon dialog
  line + map_closed ALL at t=208871.
- Retail pacing evidence (decisive): `XiEvent::EventIdle` runs ExecProg back-to-back within one tick until RetFlag is set
  (`research/XiEvents/Event VM Functions.md`); open (0xC8), marker (0x8B), close (0x8A) and the dialog opcodes all have
  "Sets RetFlag? No" → in retail the map opens AND closes before a frame draws. The persistent effect is the marker
  itself ("Used by NPCs that help new players and mark your maps", `research/XiEvents/OpCodes/0x008B.md`).
- Decision (mine, NOT user-approved): Option A — faithful back-to-back. `event_map_sync_system`
  (`kuluu/src/view_native/text_input/event_map.rs`) already does open → marker upsert → close in one pass; ends
  mode=World, marker persists. Pinned by test `event503_same_tick_open_marker_close_leaves_the_marker_not_the_map`.
  If a retail observation shows the map visibly flashing, that contradicts the VM pacing evidence and needs an
  observation record to overturn it.

## 3. ESC ending the CS — root cause found + fixed end-to-end (the "retail locks you in" ask)
- Root cause: event 503's master block runs CANCEL_CLEAR (0x42) as its **second opcode** — retail clears
  CliEventCancelSetData/CliEventCancelFlag, disarming ESC-cancel for the whole CS (14× 0x42 in the master block, zero
  re-arms; verified via `cargo run -p ffxi-event --example zz-op-dump -- 230 503`). Our VM skipped 0x42 as unknown and
  the client's `handle_dialog_key` sent EndEvent unconditionally on ESC → EVENT_END(0x40000000) → server EVENTUCOFF →
  CS ended. Retail: ESC is a no-op — no packet goes out at all.
- Fix: single `cancel_armed: bool` — armed at event start, 0x42→false, 0x2E→true; documented simplification of
  retail's two-flag gate (CliEventCancelSetFlag empirically open on events using these opcodes):
  - `ffxi-event/src/vm.rs`: OP_CANCEL_DISARM/OP_CANCEL_ARM consts + EventVm field + dispatch arm before the unknown-skip
    fallback + `cancel_armed()` getter; test `cancel_flag_disarms_and_rearms` (the old skip-test moved off 0x42 to 0x30).
  - `kuluu-session/src/state.rs` DialogState + `kuluu-snapshot/src/lib.rs` DialogState: new field, serde default **true**
    (unknown producers stay cancellable); `frame_to_dialog` carries `runner.cancel_armed()`; `dialog_to_wire` carries it.
  - Client gate in the NavCancel branch of `handle_dialog_key`
    (`kuluu/src/view_native/text_input/mod.rs`): after the customMenu check, `!d.cancel_armed` → return None — no
    EndEvent sent. CustomMenu path untouched (server prompts still answer "Canceled.").
  - Every raw DialogState builder audited: local menus + Mog recipient frame + the three s2c event decoders get explicit
    `cancel_armed: true`; the GMPROMPT custom-menu builder sets it explicitly too (its ESC path is the customMenu branch).
- Proof at all three levels (no stubs — each test drives real code):
  - VM: `cancel_flag_disarms_and_rearms` (ffxi-event)
  - Session: `cancel_disarm_opcodes_flow_into_the_first_frame` — a program starting with 0x42 yields Begin::Frame with
    cancel_armed=false; the same line without it stays true.
  - Client: `esc_is_a_noop_while_the_vm_has_disarmed_cancel` (zero commands on the wire) +
    `esc_sends_end_event_while_cancel_is_armed` (exactly one EndEvent).

## 4. Speaker identity — per-frame attribution implemented (was blank on all 51 frames)
- Symptom: the recorded run (`artifacts/verify/events.jsonl`, key `event.dialog`) had **npc_name=None on all 51 dialog
  frames** → every line, guard/Curilla/Rahal/party alike, drew a blank header. Both EventTrigger construction sites set
  `npc_name: None` and nothing resolved the per-frame speaker; the VM's `frame.speaker_index` was dropped in
  `frame_to_dialog`.
- Retail mechanism (verified): message opcodes carry a target index and resolve it against the live entity buffer at draw
  time — 0x1D uses `EntityTargetIndex[1]` as speaker ("???: " if missing), 0x2B embeds its own actor reference, 0xB0
  resolves a speaker+listener pair (skips the line entirely if either lookup fails), 0x48/0x49 are narration with no
  speaker (`research/XiEvents/OpCodes/0x001D.md`, `0x002B.md`, `0x00B0.md`). So a frame's speaker is a **wire target
  index** — resolvable against CHAR packets.
- Implementation:
  - `speaker_index: Option<u16>` (`#[serde(default)]`) on DialogState in both `kuluu-session/src/state.rs` and
    `kuluu-snapshot/src/lib.rs`; carried by `frame_to_dialog` + `dialog_to_wire`. All full-literal builders got explicit
    `speaker_index: None,` (local menus, the three s2c decoders, render test fixture); GMPROMPT builder is fine via
    `..Default::default()`.
  - New `target_cache: HashMap<u16, u32>` (act_index→unique_no) plumbed through keepalive_loop / drain_zone_flood /
    handle_sub_packet; populated in the CHAR_PC|CHAR_NPC arm right before name_cache.insert.
  - Helper `attribute_event_speaker(dialog, target_cache, name_cache)` in session/mod.rs: Some(idx) resolved → that
    entity's name; **unresolvable or None speaker → blank header** (decision — the render fallback for npc_name=None would
    show the TRIGGER's name on every line via snap.entities lookup by npc_id = wrong attribution; blank is honest).
    Called at all 5 VM-driven emit sites before chat + EventDialog send: Begin::Frame in begin_server_event + the 4
    Advance::Frame arms.
  - `npc_id` deliberately untouched: the client's EndEventChoice sends `event_id: d.npc_id` back for EVENT_END validation
    against the trigger unique_no — changing it per-frame would break menu responses.
- Divergence noted (not user-approved): retail prints "???: " on a missing 0x1D entity; kuluu blanks. Event 503's 51
  frames all resolve, so this never surfaces there.
- Tests: `speaker_attribution_resolves_the_frame_speaker_not_the_trigger` (session/tests.rs) — resolves via target+name
  caches; None speaker → Some(""); unresolvable → Some(""). cancel_disarm test extended to assert
  speaker_index=Some(54).

## Test counts after this phase
- ffxi-event **117** lib (+1 cancel test; skip-test switched 0x42→0x30) · kuluu-session **459** lib (+1 cancel_disarm,
  +1 speaker_attribution; cancel test also asserts speaker_index=Some(54)) · kuluu-render **1189** lib (fixture compile
  fix only, no behavior change) · kuluu **465** lib (+2 ESC gate tests). All four re-verified green after the speaker work.
- Nothing committed; the repo-root `kuluu.exe` may be stale — rebuild before a live run.

---

# PHASE 6 — camera hold on last frame, dialog-dismiss clear, CS input lock; Phase 5 §2 no-flash decision OVERTURNED by DAT evidence

Three bugs from the user's live run (camera "flips back to the player" at a wait-for-Enter beat; the advance hint
lingering after dismissal; nothing happening at the map beat — no dialog, no map staying open) plus the standing rule:
**input should be locked in CS mode in general.** All three root-caused against code + retail evidence; all fixes
test-pinned at the level where the effect is observable (command on the wire / frame re-applied to the camera /
system-level key routing). No stubs green-lit.

## 1. Camera: a finished route now HOLDS its last frame while the lock outlives it
- Symptom: when a camera routine ended while the event was still waiting for ENTER, the view snapped back to the
  player's chase camera instead of parking on the route's final frame.
- Root cause (verified in code): `resolve_camera` (`kuluu/src/view_native/camera_collision.rs`) writes the operator
  camera unconditionally every frame in Chase mode; the old `advance_cutscene_camera_task` early-returned once its
  route drained, so chase took the camera back on the very next frame.
- Retail mechanism: while DEFCAMERA case 1 is in force retail has disabled user camera control and menu drawing;
  case 0 runs `YmCameraTask_KillAll()` + re-seats the chase at the player's position
  (`research/XiEvents/OpCodes/0x0046.md`). So while locked with no active task, the operator camera stays exactly
  where the finished route left it. Event 503 holds its camera from +037F7 to +04683 across ALL of its MESWAITs.
- Fix (`kuluu-render/src/cutscene_camera.rs`): `CutsceneCameraTasks.held: Option<CameraFrame>`; the task system runs
  AFTER `resolve_camera` and, while `camera_locked` with no active route, re-applies the last applied frame every
  frame (a lock with no route yet captures operator state once via `capture_current_camera` and freezes it).
  DEFCAMERA case 0 still clears route + held in one pass.
- Tests: `a_finished_route_holds_its_last_frame_while_the_lock_outlives_it`,
  `a_lock_before_any_route_freezes_the_operator_state` (kuluu-render, both drive the real system against a chase
  writer that steals the camera every frame).

## 2. Dismissal now clears the displayed frame — the advance hint cannot linger
- Symptom: after Enter dismissed a line, the dismissed text + "▶ Enter to continue" stayed on screen over subsequent
  camera moves/holds until the event ended.
- Root cause (verified in code): nothing cleared `snapshot.dialog` on dismissal — only EventEnded did. The dialog
  panel's visibility is `dialog.is_some()`, so a dismissed frame kept drawing with its hint.
- Fix: new `AgentEvent::DialogDismissed` (`kuluu-session/src/state.rs`), emitted at the five VM-drive sites in
  `session/mod.rs` on the up→down edge of `message_awaiting()` (edge detector `take_message_closed()`,
  `kuluu-session/src/event_dialog.rs`); applying it clears `SessionState.dialog`. The exhaustive additive-event
  sentinel test gained its arm.
- Tests: `message_closed_fires_exactly_once_per_up_down_transition` (drives a real DialogSession through the event
  503 map-beat shape — MESSAGE → MESWAIT → long WAIT; fires exactly once, on dismissal into the timed hold) and
  `apply_event_dialog_dismissed_clears_the_frame` (no-op when nothing up; clears + reports mutation only because it
did; second dismissal no-op; reopen mutates).
- Deferred per user: retail's advance affordance is NOT literally "Press Enter" (observation suggests dots or
  similar). Research/note only this round — not implemented.

## 3. CS input lock: while a frame is up, the keys belong to the event in every InputMode
- Symptom/root cause (verified in code): key dispatch routes strictly by InputMode; at the map beat the mode is
  Menu(Map) with the coupon line parked on its MESWAIT — Enter went to the menu handler and never reached
  `handle_dialog_key`, so a human playthrough HANGS at the map beat. (The live test never hit this because it
  auto-sends EndEventChoice.)
- Retail mechanism: 0x46 case 1 disables menu drawing for the whole camera hold; the message flag only clears on
  dismissal (`research/XiEvents/OpCodes/0x0046.md`, `0x0023.md`) — during a VM-driven event, input is locked to the
  event. General rule per user: you should not be able to open menus / close maps in these CS.
- Fix (`kuluu/src/view_native/text_input/mod.rs`): gate at the top of `text_input_system`'s key loop — when
  `CutsceneMode.active && snapshot.dialog.is_some()`, route ALL keys through `handle_dialog_key` (existing Dialog
  cursor if already in Dialog mode, else a temporary one), then continue. Enter advances with the map open; ESC
  respects cancel_armed. Operator slash-command escape hatches remain available when NO frame is up.
- Tests (system-level, driving the real `text_input_system` on a bare App — send key → read commands off the wire):
  - `enter_advances_the_event_with_the_map_open`: Menu(Map) + frame up + CS active → exactly
    `EndEventChoice { event_id:0, act_index:0, event_num:0, choice:0 }`.
  - `esc_cannot_close_the_map_while_disarmed`: same state, ESC → zero commands.
  - `without_a_cutscene_session_the_menu_handler_keeps_the_keys`: CS inactive control — the map handler's own
    unconditional cancel sends `EndEvent`, proving the gate (not pre-existing map-beat code) is what changes behavior.
- Follow-up (flagged, not done): mouse-click map-close during a CS is NOT gated yet (keyboard only).

## 4. Phase 5 §2 OVERTURNED — the map opens and STAYS open until Enter (DAT evidence)
- The user overturned the "faithful no-flash" decision after observing the real game: at the epilogue beat the map
  opens, shows the marker, and stays open over the coupon line until Enter.
- DAT evidence (verified this phase in `evt503_master_disasm.txt`, both epilogue copies):
  - +045D9 MAP_TUTORIAL → +045E0 MAP_MARKER("Ailevia") → +045F9 GET_STORE(536→WZ[2]) → +045FE
    PRINT_MSG_SPEAKER(coupon line 7747) → **+04605 MESWAIT [yields]** → +04606 CLOSE_MAP.
  - +047A2 MAP_TUTORIAL → +047A9 MAP_MARKER → +047C2 GET_STORE(536→WZ[2]) → +047C7 PRINT_MSG_SPEAKER(7747) →
    **+047CE MESWAIT [yields]** → +047CF CLOSE_MAP.
- Why the old reading was wrong: MESWAIT sets RetFlag (`research/XiEvents/OpCodes/0x0023.md`), so retail's
  `XiEvent::ExecProg` halts with the map still open; CLOSE_MAP only runs after dismissal. The "all at t=208871"
  same-tick burst in the recorded run was an artifact of our live test auto-sending EndEventChoice instantly —
  it is NOT retail pacing.
- Consequence: kuluu's VM pacing was already correct (MESWAIT parks with the map open; CLOSE_MAP runs post-dismissal).
  What actually broke the human playthrough at this beat was #2 (hint/frame lingering) + #3 (Enter swallowed by the
  menu handler). The burst test `event503_same_tick_open_marker_close_leaves_the_marker_not_the_map` is kept as a
  robustness case for auto-advancing clients; its comment no longer claims retail paces this way.

## 5. Comment discipline: three dangling cites removed (checks.sh hard-fail)
- `scripts/checks.sh comments` failed on cited path `artifacts/verify/events.jsonl`: the file exists locally but is
  gitignored, so it is not in the tree for CI or anyone else (the checker requires non-submodule cite paths to be
  git-tracked). Removed from three .rs test comments (`kuluu/src/view_native/text_input/event_map.rs`,
  `kuluu-render/src/hud/dialog.rs`, `kuluu-render/src/hud/map_screen.rs`); provenance now stated without the path.
- Also fixed while there: event_map.rs's burst-test comment carried the overturned no-flash claim — rewritten per §4.

## Test counts after this phase (all re-run green)
- ffxi-event **118** lib · kuluu-session **468** lib (+2 new: message_closed edge detector, DialogDismissed state arm)
  · kuluu-render **1191** lib (+2 camera-hold tests) · kuluu **462** lib (461 passed + 1 ignored; +3 cs_input_lock
  system tests). `bash scripts/checks.sh comments` → exit 0.
- Nothing committed; the repo-root `kuluu.exe` is stale — rebuild before a live run. A human run after rebuild is
  the visual confirmation for #1/#2/#3 (the live test auto-advances, so it cannot demonstrate the map staying open).

## PHASE 7 — enter-wait vs auto-continue: what the DAT actually says (event 503 deep-dive)

User's question this round: at each camera-movement end in THIS cs, does the VM wait for ENTER or auto-continue
on to the next beat? Maybe this CS has both already — the opening plays without forced enter, and only the map
acknowledge needs one? "We don't guess, we SEE what the DAT says." Secondary task: classify the old Windower addon
`enternity` (stop-tables for enter-skipping) — is it skipping DIALOGUE at stop points (proves the user's model) or
free-flowing CS/CAMERA (would overturn it)?

**Answer up front: both patterns exist in this CS, but not where suspected.** Every dialogue line on the primary
path is enter-gated — including the opening (B1). What flows freely between lines is the camera/move
choreography: camera ends are ALWAYS paced by authored scheduler lengths, never by input. The map acknowledge IS
enter-gated (PHASE 6 §4, re-verified below). And enternity is a DIALOG-SKIP addon: it strips the per-line text stop
marker and never touches camera state — independent retail-world confirmation of the model.

### 1. The gating rule (retail mechanism, from retail pseudocode)

MESWAIT (0x23) yields ONLY when a dialog is open — `research/XiEvents/OpCodes/0x0023.md`:
- `CliEventMessOpenFlag == 1` (dialog open) → `RetFlag = 1`: VM parks until the player dismisses = **ENTER gate**.
- No dialog open → the opcode stops the speaker's mouth animation and advances the pointer = **auto-continue**.
- Flag == 2 → force-end the event.

The UI-side half of the gate lives in the text data: every gated event line ends with the stop marker `0x7F 0x31`
(visible in the disasm strings as `\x7f4\t\x7f1\x00`); the message window stops there and waits for input while the
VM sits on the MESWAIT. Dismissal clears the flag and releases both.

**Generic rule for any event: a MESWAIT is an ENTER gate iff a dialog is open at that point; otherwise it is a
mouth-stop no-op.** Kuluu's VM already implements the retail 0x23 semantics (yield iff message open), so the
generic player is correct by construction — no per-event special-casing.

### 2. Master-block census (zone 230, `ROM/21/39.DAT`, entry +037F1, program 40853 B → EOD +0D786)

Census run over `evt503_master_disasm.txt` (6374 opcodes; EXECEND at +0D784, one trailing byte at +0D785):

| quantity | count | note |
|---|---|---|
| PRINT_* message lines | 324 | |
| MESWAIT | 319 | **all 319 execute with a dialog open** — 0 bare under the "no PRINT since previous MW" rule |
| — immediately after their PRINT | 318 | the classic `PRINT; MESWAIT` pair |
| — deferred gate | 1 | **+06402**: author inserted `WAIT 45` + `LOOK_AT` between the print (+063EF, "Why, ! You are acquainted with the Tavnazian merchant...") and its gate. Still an ENTER gate for that line — the "1 bareMW" in the census table is an adjacency artifact, not an auto-flow |
| terminal lines (no gate) | 5 | last line of a branch; the scene ends or converges instead: +0CB87 "Is that what they call dancing these days?", +0CB99 "Should we call for a doctor? I think he's having a fit.", +0CBAB "My eyes...", +0D759 "Entering [D. San d'Oria/...]", +0D75C "Your ... fills with sand." (→ fdo1 → `main` scheduler → WAIT 90 → EXECEND) |
| QUERYWAIT (choice menus) | 7 | never auto-skippable; the player must choose |
| DEFCAMERA take / release | 17 / 19 | camera lock spans the whole event; final release +0484C |
| scheduler holds | 268 | IN:meswait:70, IN:querywait:1, R:waitloadschedulor:97, R:waitschedulor:1, S:reqwait:1, T:animwait:10, T:sleep:7, T:wait:37 |

Kuluu interpretation: the generic rule above is exactly what the VM does; the census confirms event 503 needs no
special-casing. The 5 terminal lines need no gate because the scene ends or converges (GOTO to a map-epilogue copy /
EXECEND) while they display; our player already falls through them.

### 3. Per-beat map, primary path (offsets verbatim from the disasm)

Universal beat shape: `fdi1` + camera sNNN → (narration → **MESWAIT [ENTER gate]** when there is one) → `fdo1` →
`WAITLOADSCHEDULER` sNNN (camera runs to full authored 600-frame length, **auto-flow**) → `WAITLOADSCHEDULER` fdo1
→ `WAIT 60` black (**auto-flow**). The enter gate sits at the narration line, mid-beat; the camera end ALWAYS
auto-flows.

| beat | camera | camera LOAD | message (string idx @ offset) | ENTER gate | camera end (hold) |
|---|---|---|---|---|---|
| B1 | s043 (c043 dolly) | +03812 | 7668 "The fortress city of San d'Oria..." @ +03843 | **MW +03846** | auto +03858 |
| B2 | s044 | +03898 | 7669 "But now, her reign of glory..." @ +038A9 | **MW +038AC** | auto +038BE |
| B3 | s045 | +038F0 | 7670 "The sun has set on the kingdom..." @ +03901 | **MW +03904** | auto +03916 |
| B4 | s006 | +039E0 | 7671 "Yet young Elvaan knights..." @ +039F1 | **MW +039F4** | auto +03A06 |
| B5 | s046 (walk-in) | +03AA3 | — none — | none | auto +03AD9 (MOVE start/wait +03ABE/+03AC6 auto-flow) |
| B6 | s077 (8 s hold) | +03B0B | — none — | none | auto +03B40 (`WAIT 480` @ +03B2C = 8.0 s, auto-flow) |
| B7 | s048 | +03B72 | 7674 "Should fortune favor..." @ +03B83 | **MW +03B86** | auto +03B98 |
| B8 | s049 | +03BCA | 7675 "Of course, ... rise to glory..." @ +03BE2 | **MW +03BE5** | auto +03BF7 |
| C2 | v017 (player walk) | +03C83 | — none — | none | auto +03CB0 |
| C3 | v000 + ovl1 | +03CDE / +03CCD | — none — | none | auto +03CEF / +03CFE |
| C5 | v001 (player walk) | +03D16 | — none — | none | auto +03D37 |
| D1–D3 | (guard gestures, 32732 tlk0/thk1) | — | 7677 @ +03DAE, 7678 @ +03DBD, 7679 @ +03DCC | **MW +03DB5 / +03DC4 / +03DD3** | n/a (no camera beat) |
| E1 | — | — | 7680 "Wait, the expedition has returned." @ +03E08 | **MW +03E0F** | n/a |
| E3 | v003 → v004 | +03E49 / +03E6C | — none — | none | auto +03E5A / +03EA0 (`WAIT 60` + `WAIT 170`) |
| E4 | — | — | 7681 "Halt! I must inspect your ranks..." @ +03EB9 | **MW +03EC0** | n/a |
| E5 | — | — | 7682 "Oh, let us through. We are exhausted!" @ +03EF5 | **MW +03EFC** | n/a |
| E6 | v00a + v005 | +03EDD / +03F13 | 7683 "Still I must check for infiltrators..." @ +03F3A | **MW +03F41** | auto +03F04 / +03F24 |
| F1–F17 | v006..v016 | +03FDB .. +044A5 | 7684–7700+ (Curilla/Rahal/party lines) @ +03F68 .. | **MW after every line** (e.g. +03F6F, +0400A, +0410F, +0412D, +04249) | auto (per vNNN hold) |
| menu | — | — | 7738 "Ahh, recruits... what would you like to know?" @ +045BE | **QUERY + QUERYWAIT** (choice, 7 total in block) | n/a |
| H1–H3 (map) | — | MAP_TUTORIAL +045D9 / +047A2 | coupon 7747 @ +045FE / +047C7 | **MW +04605 / +047CE** | CLOSE_MAP only after dismissal (+04606 / +047CF) |
| post-map | — | — | 15786 "Open the [Map] option..." @ +047E4, 7748 "To give items to others..." @ +0481B | **MW +047EB / +04822** | DEFCAMERA release +0484C |
| end | s004 + v016 | +0460A/+04632 (copy 1), +047D3/+047FB (copy 2) | terminal 16643/16681 @ +0D759/+0D75C | none (terminal) | EXECEND +0D784 |

So the CS **has both patterns**: enter-gated narration beats (B1–B4, B7, B8, every D/E/F line, the map
acknowledge) and pure auto-flow choreography beats (B5, B6, all of C, and every camera end). The opening does NOT
play without forced enter — B1 is enter-gated. The map acknowledge DOES need enter — MESWAIT sits between the
coupon line and CLOSE_MAP in both epilogue copies. And the last-frame camera freeze we keep (PHASE 6 §1) is exactly
right for the gated beats: while parked on a narration MESWAIT the camera lock is still in force, so retail holds
the last frame of the finished route; when the lock finally releases (+0484C), retail re-seats the chase camera.

### 4. Cross-zone contrast (verbatim rows from `cs_compare/out.txt`)

| zone / file @ entry | master? | msgs | gated | bareMW (adjacent) |
|---|---|---|---|---|
| 230 ROM/21/39.DAT @ +037F1 | MASTER | 324 | 318 | 1 |
| 231 ROM/21/40.DAT @ +020EF | MASTER | 234 | 234 | 0 |
| 241 ROM/21/50.DAT @ +09B6 | | 107 | 106 | 0 |
| 237 ROM/21/46.DAT @ +001F1 | MASTER | 1277 | 1217 | 58 |
| 105 ROM/20/42.DAT @ +02F0 | | 49 | 18 | 31 |
| 110 ROM/20/47.DAT @ +1EAE | | 8 | 2 | 2 |
| 120 ROM/20/57.DAT @ +1EAE | | 8 | 2 | 2 |
| 230 NPC block 0x010E607E @ +00001 | | 143 | 136 | 7 |

Bare MWs are common in OTHER zones/events (zone 105: 31 of 49 ungated; 237 master: 58) but rare in 503's master —
503 is the all-gated case. (Remember: even 503's single "bare" is functionally gated at +06402; the other zones'
bare MWs are the true auto-flow examples — action beats where the author deliberately let the scene run past a
mouth-stop with no dialog up.)

### 5. Enternity verdict: DIALOG-SKIP (user's model confirmed)

Source: `addons/enternity` (Windower/Lua live branch, v1.20131102, Giuliano Riccio; saved copy in scratchpad
`cs_compare/enternity.lua`). The entire mechanism is 12 lines:

```lua
windower.register_event('incoming text', function(original, modified, mode)
    if (mode == 150 or mode == 151) and not original:match(string.char(0x1e, 0x02)) then
        local target = windower.ffxi.get_mob_by_target('t')
        if not (target and blist:contains(target.name)) then
            modified = modified:gsub(string.char(0x7F, 0x31), '')
        end
    end
    return modified
end)
```

- It operates on **incoming text packets** (modes 150/151 = event/NPC dialog text) — it never looks at camera
  state, cutscene flags, or scheduler state.
- It **strips `0x7F 0x31` from the text stream** — the per-line "stop, wait for input" marker that closes every
  gated event line in the DATs (`\x7f4\t\x7f1\x00` in the disasm strings). Changelog v1.20130607: "Changed from
  artificial button press to **ignoring the stop**." With the marker gone, the message window never stops, the
  dialog closes by itself, and the VM's MESWAIT releases with no keypress.
- It explicitly **excludes choice boxes** (text containing `0x1E 0x02`) — README: "It will not skip choice dialog
  boxes" (QUERYWAIT is untouched, as it must be: a choice is a branch, not a gate).
- It carries a name blacklist (`Paintbrush of Souls` — "Requires correct timing, should not be skipped";
  `Geomantic Reservoir` — "Causes dialogue freeze") — per-NPC dialogue exceptions, again text-level.

Classification: **enternity skips dialogue stops, not camera choreography.** If CS "stops" were camera-level,
removing a two-byte text marker could not fast-forward them. Its stop points align exactly with the
MESWAIT-after-message positions this census maps. This is independent retail-world confirmation that the waits in
these scenes are dialog gates and that the camera/move choreography between them is free-flowing (timed).

### 6. Consequences for kuluu (no code changes this round)

- Generic CS player rule, now DAT-verified: **ENTER gate = MESWAIT with a dialog open; everything else flows on
  authored timing.** The VM already implements the retail 0x23 semantics (yield iff `CliEventMessOpenFlag`), so no
  change.
- Last-frame camera freeze while parked on a dialog MESWAIT = correct retail behavior (lock still in force); keep it
  (user: "100%").
- The 5 terminal lines need no gate: the scene ends or converges while they display; our player already falls
  through them.
- Open follow-ups (unchanged): mouse-click map-close during a CS is not gated yet (keyboard only, PHASE 6 §3);
  retail's advance affordance (dots vs "Press Enter") is research/note-only, deferred.
- Decisions this round: none new in code. (The walk-to-EOD extent heuristic in the cross-zone script remains mine,
  justified by the tag-table + EXECEND-at-end evidence; flagged previously.)

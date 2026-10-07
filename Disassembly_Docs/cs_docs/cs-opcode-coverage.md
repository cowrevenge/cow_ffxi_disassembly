# Cutscene VM opcode coverage — post-campaign state

Survey of the `ffxi-event` event VM against the retail opcode corpus, rewritten
after the round 13 campaign. Companion to the Achantere, T.K. work (zone 231,
event 32762). Every opcode retail handles now either emits a cue the render
side consumes, advances like retail, or is recorded below with the reason its
visible effect cannot be produced offline.

Method. An opcode is *handled* when some `const OP_` names it anywhere in
`ffxi-event/src` — the main match in `ffxi-event/src/vm.rs`, the sub-byte
family consts in `ffxi-event/src/opcode_meta.rs`, or the scene gate in
`ffxi-event/src/vm/scene.rs` (`handles_scene_opcode`, called before the main
match and active only while the event carries scene data). Of the 218 opcodes
documented in `research/XiEvents/OpCodes/`, all but the small set below have a
const and an arm; the rest fall to the main match's default arm, whose rule
comes from `OPCODE_META` (`ffxi-event/src/opcode_meta.rs`): advance by the
opcode's width when `valid && !jumps && !sets_ret && size > 0`, otherwise stop
with `StepResult::Unimplemented` (the host logs the opcode, event id and zone).

"Visible" column: re-derived from the `research/XiEvents/OpCodes/0x00NN.md`
Description of each opcode, not from the round 12 table — what the retail
handler does that the player can perceive (actor pose, actor movement, camera,
screen, HUD, sound, none). A row whose page names an actor, camera, screen, HUD
or sound effect is either handled end to end or recorded in §3 with the reason
its effect is not produced offline.

## 1. Opcodes the VM advances past with no cue and no state

### 1a. Explicit step-over arms (`ffxi-event/src/vm.rs` main match)

These have a `const OP_` and an arm that advances by width, emitting no cue and
changing no state. All are waits or VM-internal; none names a player-visible
effect in its XiEvents page.

| op | XiEvents name | one-line description (`research/XiEvents/OpCodes/0x00NN.md`) | retail effect visible to the player |
|---|---|---|---|
| 0x70 | TURNWAIT | Checks the event entity for a render flag, yields if set; otherwise cancels the entity movement and advances | none (a wait; the movement-cancel half needs the entity's motion state) |
| 0x80 | LOADWAIT | Tests the given entity for several conditions; yields or moves forward depending on the results (checking whether the entity is loading an action or similar) | none (a wait) |
| 0x76 | TURNCHECK | Checks the given entity's `Render.Flags0` and `Render.Flags3` and yields if successful | none (a wait) |
| 0x34 | MAPLOAD | Appears to load and unload an additional zone to be used with the event | none (zone load; no authored visual) |
| 0x35 | MAPLOAD (keep) | Similar to 0x34, but without the `XiZone::Close` call | none |
| 0x9A | MUSICREADWAIT | Yields until the music server is no longer reading data | none (a wait on the audio stream; audio is host-side) |
| 0x58 | YIELD | Yields the event VM | none |

The 0x27/0x28/0x29/0x2A ReqSet family (`FUNC_REQSet` / `GetReqStatus`
synchronization, `research/XiEvents/OpCodes/0x0027.md`–`0x002A.md`) is the
same shape with a gate: with scene data, `ffxi-event/src/vm/scene.rs` handles
them (the choreography sync points that arm the actor holds); without it, the
main match's explicit arm steps over by width, no cue, no state.

### 1b. Sub-byte families, unhandled sub-case (`_ => {}` in the main match)

Thirteen opcodes dispatch on a second byte. The main match emits on exactly
five sub-cases — `(0xB4, 0x00)` / `(0xB4, 0x01)` copy a string into the work
zone (state, no cue), `(0xB5, 0x00)` pushes `EventCue::EntityName`,
`(0x1F, 0x00)` pushes `EventCue::ActorMove`, and `(0x1F, 0x01)` holds while
that move has frames left — and advances every other sub-case by its `sub_size`
width with `_ => {}`: no cue, no state. Sub-cases whose retail handler polls
for player input stop instead (`is_input_wait`, `ffxi-event/src/opcode_meta.rs`),
and a sub-byte with no documented width stops. Widths per case: `sub_size` in
`ffxi-event/src/opcode_meta.rs`.

| op | XiEvents name | one-line description | retail effect visible to the player | disposition |
|---|---|---|---|---|
| 0x59 | ENTITYSPEED | Handles multiple cases regarding updating an entity's data for events (turn/move speed) | actor movement (speed) | §3 — internal speed state |
| 0x5F | SUBSCHED | A few cases, most of which call other opcode handlers and react to their returns | none (delegation) | none needed |
| 0x71 | MENU | Handles the usage of string input from the player during events, such as password prompts | screen (input UI) | §3 — no string-input surface |
| 0x75 | LOADROOM | Loads a room and updates the player's sub-region with the server | screen/zone (indoor sub-region) | §3 — server round trip |
| 0x7A | REQRESET | Case 0 resets the given entity's entire event VM (`ExecPointer`, `RunPos`, `ReqStack`); other cases share `ExtData` | none (internal VM reset) | none needed |
| 0x9D | STRINGOPS | Handler with multiple purposes, mainly focused around handling strings | none (VM-internal strings) | none needed |
| 0xAB | RENDERFLAG | Handles various sub-cases, mostly altering entity render flags | actor pose (render flags) | §3 — undocumented flag bits |
| 0xAC | STATUSSET | Handles multiple sub-cases (entity status / render-flag writes) | actor pose (status flags) | §3 — undocumented status writes |
| 0xB6 | LOOKSET | Handler with multiple sub-usages, related to entity looks / gear visuals | actor pose (gear/look swap) | §3 — needs the look model |
| 0xCC | ITEMINFO | Opens and displays information windows for various things, mainly items | screen (info window) | §3 — no info-window consumer |

### 1c. Default arm — no `const OP_` anywhere in `ffxi-event/src`

The documented opcodes with no const reach the default arm. All but 0xCA/0xCB
satisfy `valid && !jumps && !sets_ret && size > 0` and are skipped by width
(`op_width`, honouring `sub_size` for 0x5C and 0xC2); 0xCA (size 0) and 0xCB
(`sets_ret`) stop, but a zone sweep found no event DAT that authors either, so
the stop is unreachable in practice (commit `b612521`).

**Default-skip.**

| op | XiEvents name | one-line description | retail effect visible to the player | disposition |
|---|---|---|---|---|
| 0x04 | `FUNC_XiEvent_OpCode_0x0004` | Deprecated; does nothing | none | none needed |
| 0x12 | `FUNC_XiEvent_OpCode_0x0012` | Generates a random number via `rand()` and stores it | none | none needed |
| 0x13 | `FUNC_XiEvent_OpCode_0x0013` | Random number with a given remainder, stored | none | none needed |
| 0x16 | `FUNC_XiEvent_OpCode_0x0016` | `sin` of two values, stored | none | none needed |
| 0x17 | `FUNC_XiEvent_OpCode_0x0017` | `cos` of two values, stored | none | none needed |
| 0x18 | `FUNC_XiEvent_OpCode_0x0018` | `atan2` of two values, stored | none | none needed |
| 0x2F | `FUNC_XiEvent_OpCode_0x002F` | Adjusts the given entity's `Render.Flag0` | actor pose (render flag) | §3 — undocumented flag bit |
| 0x30 | `FUNC_XiEvent_OpCode_0x0030` | Sets the `ucoff_continue` flag to 0 | none | none needed |
| 0x33 | `FUNC_XiEvent_OpCode_0x0033` | Adjusts the event entity's `Render.Flags0` | actor pose (render flag) | §3 — undocumented flag bit |
| 0x3A | `FUNC_XiEvent_OpCode_0x003A` | Converts a float yaw to its single-byte form and stores it | none | none needed |
| 0x3D | `FUNC_XiEvent_OpCode_0x003D` | Compares two values with a shift; clears a bit flag on success | none | none needed |
| 0x3F | `FUNC_XiEvent_OpCode_0x003F` | Remainder of two values, stored | none | none needed |
| 0x50 | `FUNC_XiEvent_OpCode_0x0050` | Ends a `CMoSchedularTask` | none | none needed |
| 0x51 | `FUNC_XiEvent_OpCode_0x0051` | Ends a zone-based `CMoSchedularTask` | none | none needed |
| 0x52 | `FUNC_DatIdHelper` | Ends a `CMoSchedularTask` (load / main) | none | none needed |
| 0x57 | `FUNC_XiEvent_OpCode_0x0057` | Creates a frame delay from the current frame delay value and stores it | none | none needed |
| 0x60 | `FUNC_XiEvent_OpCode_0x0060` | Handler with multiple use cases | unknown | none needed (no named effect) |
| 0x61 | `FUNC_XiEvent_OpCode_0x0061` | Adjusts the event entity's `Render.Flags2` | actor pose (render flag) | §3 — undocumented flag bit |
| 0x64 | `FUNC_XiEvent_OpCode_0x0064` | Distance between the given points, stored | none | none needed |
| 0x65 | `FUNC_XiEvent_OpCode_0x0065` | 3D distance between the given entities, stored | none | none needed |
| 0x6D | `FUNC_XiEvent_OpCode_0x006D` | Deprecated; does nothing | none | none needed |
| 0x74 | `FUNC_XiEvent_OpCode_0x0074` | Adjusts the event entity's `Render.Flags1` | actor pose (render flag) | §3 — undocumented flag bit |
| 0x7B | `FUNC_XiEvent_OpCode_0x007B` | Unsets the given entity's talking status (`NpcSpeechFrame` back to -1) | actor pose (speech) | §3 — no talking-state consumer |
| 0x7C | `FUNC_XiEvent_OpCode_0x007C` | Adjusts the given entity's `Render.Flags2` | actor pose (render flag) | §3 — undocumented flag bit |
| 0x81 | `FUNC_XiEvent_OpCode_0x0081` | Sets whether the given entity is blinking | actor pose (blink) | §3 — no blink consumer |
| 0x83 | `FUNC_XiEvent_OpCode_0x0083` | Gets and stores the current game time | none | none needed |
| 0x84 | `FUNC_XiEvent_OpCode_0x0084` | Adjusts the event entity's `Render.Flags3` | actor pose (render flag) | §3 — undocumented flag bit |
| 0x85 | `FUNC_XiEvent_OpCode_0x0085` | Opens a mog house sub-menu depending on the parameter | screen (UI) | §3 — no Mog House UI consumer |
| 0x86 | `FUNC_XiEvent_OpCode_0x0086` | Adjusts the given entity's `Render.Flags3` | actor pose (render flag) | §3 — undocumented flag bit |
| 0x91 | `FUNC_XiEvent_OpCode_0x0091` | Sets the `ExtData[1].MainSpeedBase` value | none (internal speed) | none needed |
| 0x92 | `FUNC_XiEvent_OpCode_0x0092` | Adjusts the given entity's `Render.Flags3` | actor pose (render flag) | §3 — undocumented flag bit |
| 0x93 | `FUNC_XiEvent_OpCode_0x0093` | Appears to display an item's information | screen (UI) | §3 — no item-info window consumer |
| 0x94 | `FUNC_XiEvent_OpCode_0x0094` | Adjusts the given entity's `Render.Flags3` | actor pose (render flag) | §3 — undocumented flag bit |
| 0x95 | `FUNC_XiAtelBuff_SetEventNpcStat` | Sets the event entity up for being an event-based NPC | none | none needed |
| 0x96 | `FUNC_XiAtelBuff_ObjectDelete` | Unsets the event entity from being an event-based NPC | none | none needed |
| 0x97 | `FUNC_SaveWindInfoWrap` | Saves the zone's `WindBase`/`WindWidth` and sets new ones | screen (weather/wind) | §3 — no event wind consumer |
| 0x9C | `FUNC_XiEvent_OpCode_0x009C` | Stores the client language id | none | none needed |
| 0x9E | `FUNC_XiEvent_OpCode_0x009E` | Sets the `PTR_RectEventSendFlag` value | none | none needed |
| 0xA1 | `FUNC_XiEvent_OpCode_0x00A1` | Calls the same helper as 0x52 with a different second argument | none | none needed |
| 0xA2 | `FUNC_XiEvent_OpCode_0x00A2` | Calls the same helper as 0x55 with a different second argument | none (a wait) | none needed |
| 0xA3 | `FUNC_XiEvent_OpCode_0x00A3` | Calls the same helper as 0x52 with a different second argument | none | none needed |
| 0xA4 | `FUNC_XiEvent_OpCode_0x00A4` | Adjusts the event entity's `Render.Flags3` | actor pose (render flag) | §3 — undocumented flag bit |
| 0xA5 | `FUNC_XiEvent_OpCode_0x00A5` | Adjusts the event entity's `Render.Flags3` | actor pose (render flag) | §3 — undocumented flag bit |
| 0xA8 | `FUNC_XiEvent_OpCode_0x00A8` | Opens the map (if requested), unlocks and renames markers | screen (map window) | §3 — marker name from the Read buffer |
| 0xAA | `FUNC_XiEvent_OpCode_0x00AA` | Gets a Vana'diel timestamp and stores its time parts | none | none needed |
| 0xAD | `FUNC_XiActor_UnknownCall` | Multiple sub-cases doing various scheduler actions against the two given entities | actor pose (scheduler actions) | §3 — no tier names the sub-cases |
| 0xAE | `FUNC_XiEvent_OpCode_0x00AE` | Handles multiple sub-cases; no specific purpose identified | none | none needed |
| 0xAF | `FUNC_XiEvent_OpCode_0x00AF` | Gets and stores the camera position values | camera (read-only here) | none needed (no write) |
| 0xB1 | `FUNC_XiEvent_OpCode_0x00B1` | Gets and stores a flag value that has not changed since the original beta | none | none needed |
| 0xB7 | `FUNC_XiEvent_OpCode_0x00B7` | Handler with multiple sub-usages | unknown | none needed (no named effect) |
| 0xB9 | `FUNC_XiEvent_OpCode_0x00B9` | Opens the map (if requested), edits and renames a marker (name from the event read buffer) | screen (map window) | §3 — marker name from the Read buffer |
| 0xBD | `FUNC_XiEvent_OpCode_0x00BD` | Calls the same helper as 0x52 with a different second argument | none | none needed |
| 0xBE | `FUNC_XiEvent_OpCode_0x00BE` | Stores the current `ReqStack[RunPos].WhoServerId` value | none | none needed |
| 0xBF | `FUNC_XiEvent_OpCode_0x00BF` | Used for chocobo racing (debug messages left in the handler) | screen (racing UI) | §3 — no racing UI consumer |
| 0xC0 | `FUNC_XiEvent_OpCode_0x00C0` | Adjusts the event entity's `Render.Flags3` | actor pose (render flag) | §3 — undocumented flag bit |
| 0xC2 | `FUNC_XiEvent_OpCode_0x00C2` | The purpose of this opcode is currently unknown | none | none needed (no named effect) |
| 0xC3 | `FUNC_XiEvent_OpCode_0x00C3` | Copies a string value into an unknown buffer array | none | none needed |
| 0xC7 | `FUNC_XiEvent_OpCode_0x00C7` | Calls the same helper as 0x52 with a different second argument | none | none needed |
| 0xCA | (no handler) | Deprecated; no handler exists | none | stops; no DAT authors it |
| 0xCB | (no handler) | Deprecated; no handler exists | none | stops; no DAT authors it |
| 0xCF | `FUNC_XiEvent_OpCode_0x00CF` | Calls the same helper as 0x52 with a different second argument | none | none needed |
| 0xD2 | `FUNC_XiEvent_OpCode_0x00D2` | Calls the same helper as 0x52 with a different second argument | none | none needed |
| 0xD3 | `FUNC_XiActor_Unknown` | Gets the given entity and clears its motion queue lists | actor pose (motion reset) | §3 — no motion-queue consumer |
| 0xD7 | `FUNC_XiEvent_OpCode_0x00D7` | Calls the same helper as 0x52 with a different second argument | none | none needed |
| 0xD8 | `FUNC_XiEvent_OpCode_0x00D8` | Sets the `ExtData[1]->EventDir` information for the given entity | actor pose (facing) | §3 — roll/yaw/pitch, not yaw-only |
| 0xD9 | `FUNC_XiEvent_OpCode_0x00D9` | Sets an unknown flag value | none | none needed |

## 2. NPC choreography

The four scripted-movement kinds an NPC event script uses, which opcode
carries each in the retail corpus, and whether kuluu runs it end to end
(VM cue → session translate in `kuluu-session/src/event_dialog.rs` → render
consumer in `kuluu-render/src/scheduler_runtime.rs`).

| kind | retail opcode(s) | kuluu today | where it stops short |
|---|---|---|---|
| Walk to a point | 0x1F MOVE case 0 (0x5A CODE_MOVE2 is its uncalibrated twin), 0x31 SMOVE | End to end, with or without scene data: the non-scene path emits `EventCue::ActorMove` (0x1F case 0, 0x31), the scene path emits it too; the session translates to `CutsceneCue::ActorMove` and the render side starts the walk in `apply_cutscene_actor_cues` and advances it in `advance_cutscene_walks` | none |
| Turn | 0x39 SET_FACING, 0x4B yaw update | End to end, with or without scene data: 0x39/0x4B emit `EventCue::ActorFace` → `CutsceneCue::ActorFace` → `apply_cutscene_actor_cues` writes the heading quat | none |
| Play an animation and wait | 0x2C SCHEDULOR + 0x53, 0x45 + 0x55 (and the 0x62/0x9F/0xBB/0xC5/0xCD/0xD0/0xD5 twins), 0x5B/0x66 + 0x53, 0x2D + 0x54, 0x73/0xC4 magic, 0x7D local-player, 0x6E/0x63 emote + 0x99 | End to end, no scene data needed: the loaders arm the hold and push `EventCue::{ActorMotion, Scheduler, ExtScheduler, ZoneScheduler, Emote}`, the session translates each, and the render side runs the routine through `ActiveSchedulers` (or the emote dispatcher) and releases the hold on the finish report | none |
| Emote | 0x6E EMOT, 0x63 PLAYANIM | End to end: 0x6E/0x63 emit `EventCue::Emote`, the session rides it on the existing `AgentEvent::EntityEmoted`, and the renderer's emote dispatcher plays the DAT routine on the actor | none |

## 3. Visible effects recorded as not produced offline

Every row whose XiEvents page names an actor, camera, screen, HUD or sound
effect that kuluu does not handle, with the reason its effect is not produced
offline. None of these blocks a script: each opcode still advances (or stops
only on the input-wait sub-cases retail itself polls, which the host ends the
event on). The render-flag family and the internal-state writes are the bulk:
their XiEvents pages name the field written, not a visual, and no tier names
the field's effect, so a cue would carry a value the renderer has no documented
meaning for.

| op(s) | named effect | why not produced offline |
|---|---|---|
| 0x2F, 0x33, 0x61, 0x74, 0x7C, 0x84, 0x86, 0x92, 0x94, 0xA4, 0xA5, 0xC0, 0xAB | render-flag writes on an actor | each writes an undocumented `Render.FlagsN` bit; no tier names the bit's visual, and 0x90 (the one whose bits a tier does name — the event-hide flag) is already handled |
| 0xAC | entity status / render-flag writes | same: the status/render-flag values carry no tier-named visual |
| 0x59 | entity turn/move speed | writes the entity's internal `TurnSpeed`/`TurnSpeedHead`/`MainSpeed`; kuluu's `ActorMove` cue carries its own speed, and the retail speed state subsequent moves read is not modelled |
| 0xD8 | entity facing (roll/yaw/pitch) | writes `ExtData[1]->EventDir` (a full orientation); kuluu's `ActorFace` carrier models the yaw heading only, and the roll/pitch-to-quaternion mapping is not documented in any tier |
| 0xD3 | motion-queue clear | clears the entity's motion queue lists; kuluu has no motion-queue object to clear |
| 0xAD | scheduler actions on two entities | the sub-cases do "various scheduler actions" no tier names; a cue would be invented |
| 0x7B | talking status (speech bubble) | unsets `NpcSpeechFrame`; kuluu has no talking-state / speech-bubble consumer |
| 0x81 | blink | sets the entity's blink flag; kuluu has no blink consumer |
| 0x97 | zone wind | saves/sets the zone `WindBase`/`WindWidth`; kuluu's weather is server-driven (the `weat` chunk + the live weather packet), not event-script-driven |
| 0xB6 | entity look / gear swap | swaps an entity's look; needs the look/equipment model and the look DATs, which kuluu does not load for event actors |
| 0x75 | indoor sub-region | loads a room and updates the player's sub-region with the server; needs the server round trip kuluu does not yet speak for sub-regions |
| 0x85 | Mog House sub-menu | opens a Mog House UI sub-menu; kuluu has no Mog House UI consumer |
| 0x93 | item information | displays an item's information; kuluu has no item-info window consumer |
| 0xCC | item / search info windows | opens info windows; kuluu has no info-window consumer (the input-wait sub-cases stop, as retail polls) |
| 0x71 | string input (password prompts) | reads player string input; kuluu has no text-input surface (the input-wait sub-cases stop, as retail polls) |
| 0xBF | chocobo racing UI | drives the chocobo-racing screen; kuluu has no racing UI consumer |
| 0xA8, 0xB9 | map marker unlock/rename | renames an existing marker by index to a name taken from the event Read buffer; the VM does not model the Read buffer, and there is no marker-rename consumer (the add-marker path, 0x8B/0xB8, is handled) |

## 4. Verified-on events (offline, `zz-*` readers)

Each campaign opcode was proven against real retail bytecode with the
block-absolute worklist scanners (`zz-87-scan`, `zz-8c-scan`, `zz-38-scan`,
`zz-5c-scan`) and `zz-cs-trace` (drives an event with choice 0, auto-acks
pending tags, skips waits, dumps the cues). Representative hits:

| op | zone / event / block | what the trace / scan showed |
|---|---|---|
| 0x73 / 0x7E (Signet, home point) | 231 / 32762 | the gate guard's `0x73` casts (spell DAT `0xAF0+497`, `0xAF0+504`) emit the `Scheduler` cue; the `main` routine's sparkle lands on the player |
| 0x6E / 0x63 / 0x99 | (emote corpus) | `Emote` cue + the timed hold; the renderer's emote dispatcher plays the DAT routine |
| 0x45 twins + 0xC4 | (scheduler corpus) | the loader twins emit the same `Scheduler` cue as 0x45, with their own DAT base |
| 0x7D | (rank-up corpus) | the local-player `Scheduler` cue |
| 0x1F / 0x39 / 0x4B / 0x36 / 0xBA / 0x31 | (movement corpus) | `ActorMove` / `ActorFace` / position cues on the non-scene path |
| 0x20 | (lock corpus) | the `PlayerControl` cue; the event-wide pin covers the common case |
| 0x89 / 0x8D / 0xB8 / 0x8A / 0x8B / 0xC8 | (map corpus) | `MapOpen` / `MapMarker` / `MapClose` cues |
| 0x6C | (fade corpus) | the `Transpar` cue drives the target's opacity |
| 0x4C / 0x4D / 0x4F / 0x8E / 0x8F / 0x90 | (door corpus) | the `Mount`-shaped `StatusEvent` write swings event-driven doors; 0x90 hides the event entity |
| 0x69 / 0x6A / 0x5D | (sound corpus) | the `SoundVolume` / `MusicVolume` cues |
| 0x5C | 293 / 1 / block 17977513 (off 8607 `5C 00 01 80`; off 12501 `5C A0 …`) | the trace emits `MusicSong { slot: 0, track: 79, volume: 127 }` and `slot: 1`; the scan found 18380 hits across all zones, all three sub-bands authored |
| 0x38 | 230 / 30035 / block 0x010E62B6 (off 41 `38 03 80`) | the trace emits `LocalMode { mode: 0x20 }` (Ailevia's applied value) right after the `0x46` camera lock |
| addendum A (0x56/0x98/0x9B/0x26/0x44/0xC1 + six 0x55 twins) | (corpus) | the arms advance / wait / emit like retail; the zone sweep showed the authored set |
| addendum B (0x31/0x72/0x82/0xD4; 0xCA/0xCB) | (corpus) | 0x31 moves, 0x72 reads the forecast, 0x82 hit-tests, 0xD4 opens the map and takes the answer; 0xCA/0xCB have no retail handler and no DAT authors them |
| addendum C (0xA6/0xA7/0xB2/0xB3/0x87/0x88/0x8C) | 231/623 (0x8C), 237/103, 48/222 (0x8C), 80/304 (0x8C) | full round trips through `PendingTag`; the scan showed all sub-cases authored; the traces run end to end |

## Appendix A — retail expectations per family

Distilled from the retired `cs-opcode-round13.md` (merged 2026-10-08 folder triage; the
rest of that file — what was broken / how kuluu fixed, coded and tested it — was work log,
dropped). Tier 1 unless noted.

Per family, what the retail client does (tier 1 unless noted):

- **The cast (0x73/0xC4).** "Schedules tasks for casting magic on the two given
  entities" (`research/XiEvents/OpCodes/0x0073.md`): the work operand is a
  spell-animation index, and the client plays the spell effect DAT's `main`
  routine on the caster with the target attached — the same file and routine a
  0x028 magic finish plays. The gate guard's Signet is index 497, home point
  504 (`vendor/server/sql/spell_list.sql` leaves both unclaimed by any spell).
- **Emote beats (0x6E/0x63/0x99).** The work value's low byte is the emote id,
  the high byte the variant (`0x006E.md`); the client plays the emote DAT
  routine on the actor and 0x99 yields while it runs.
- **Scheduler loaders (0x45 family, 0x7D).** Each loader resolves its DAT id
  (`FUNC_DatIdHelper` bands, `0x0045.md`), runs a routine on its actor, and the
  paired 0x55/0x53/0x54 waits ride the task's lifetime.
- **NPC movement (0x1F/0x31/0x39/0x4B/0x36/0xBA).** The script walks, faces and
  places its actors from work-slot coordinates; 0x31 carries a MoveTime budget
  (`0x0031.md`).
- **The pin (0x20).** Writing `CliEventUcFlag` 0/1 locks or releases the
  player's `CanIMove` (`0x0020.md`); retail holds the player for the whole
  event either way.
- **The map (0x89/0x8D/0xB8, 0xC8/0x8B/0x8A, 0xD4).** Open the Map screen on a
  zone, place named markers, close it; 0xD4 opens it and takes the player's
  answer into work.
- **The fade (0x6C).** Ease the target's opacity to the authored byte over the
  authored frames; the fade's driver dies with the event's ExtData
  (`0x006C.md`).
- **Doors (0x4C/0x4D/0x4F/0x8E/0x8F/0x90).** The `StatusEvent` write swings the
  door the target's look names; 0x90's event-hide flag hides the event entity
  (`0x004C.md`, `research/XIClient .../GameStatus.h`).
- **Sound and clock (0x69/0x6A/0x5D/0xA9/0xC9).** The sound-type mask reaches
  the client's volume channels (`0x0069.md`); 0xA9 holds the clock at the
  authored Vana day/hour/minute.
- **The round trips (0xA6/0xA7/0xB2/0xB3/0x87/0x88/0x8C).** Retail sends its
  c2s, yields on the await, and consumes the s2c reply in the same event.
- **Local mode (0x38).** `CliEventModeLocal` hides the local player model and
  the HUD pieces and lets the event drive the camera (`0x0038.md`; Ailevia's
  tour stores 0x2003, applying as 0x20).
- **The soundtrack (0x5C).** Set a BGM slot's song id and start volume, or ease
  the playing track's volume.

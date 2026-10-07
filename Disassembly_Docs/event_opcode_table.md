# Event opcode dispatch table (FFXiMain.dll, event VM)

The complete `ExecProg` switch for the retail event VM. Source: the jump table at rva **0xBC970**
(219 entries), dumped by `p8_jumptable.py` (`out3/p8.md`) and cross-checked against the dispatch
instruction in ExecProg @0xBC290 (`movsx eax,[esp+4]; cmp eax,0xDA; ja default(0xBC967); jmp
[eax*4 + 0x100BC970]`). See [event_vm.md](event_vm.md) E2.

Columns:
- **opcode**: the u16 read from `EventData[ExecPointer]` (sign-extended; valid range 0x00 to 0xDA).
- **thunk RVA**: the table entry, a one-instruction thunk `call <handler>; ret 4` with ecx (the
  xievent) passed through from ExecProg.
- **handler RVA**: where the thunk calls (the real handler body; may be entered mid-function, F34).
- **XiEvents size**: the documented opcode width(s) from `research/XiEvents/OpCodes/0xNNNN.md`
  (web tier; a few list two widths where a param-gated extra byte exists).
- **mnemonic / description**: first line of the XiEvents Description (web tier).
- **notes**: local findings from this pass (E-references) where an opcode was decoded.

Opcodes 0xCA and 0xCB have no dedicated handler; their table entries point at the default handler
@0xAFC90 (the same target as 0x00). Opcodes above 0xDA are not dispatched (they fall to the default
via the `cmp eax,0xDA; ja` guard).

| opcode | thunk RVA | handler RVA | XiEvents size | mnemonic / description | notes |
|--------|-----------|-------------|---------------|------------------------|-------|
| 00 | 0xBC967 | 0xAFC90 | 1 | Ends the current `ReqStack` execution; resetting it back to defaults. | default handler target shared with 0xCA/0xCB |
| 01 | 0xBC2A7 | 0xAFD00 | 3 | Directly sets the `ExecPointer` position. |  |
| 02 | 0xBC2AF | 0xAFD20 | 8 | Handles multiple types of `if` conditional statements. |  |
| 03 | 0xBC2B7 | 0xAFED0 | 5 | Gets a value then stores it. |  |
| 04 | 0xBC2BF | 0xB0130 | 3 | Deprecated. This opcode appears to be deprecated, it does nothing. |  |
| 05 | 0xBC2C7 | 0xB0140 | 3 | Sets a value to `1`. |  |
| 06 | 0xBC2CF | 0xB0160 | 3 | Sets a value to `0`. |  |
| 07 | 0xBC2D7 | 0xB0180 | 5 | Adds two values then stores the result. |  |
| 08 | 0xBC2DF | 0xB01B0 | 5 | Subtracts two values then stores the result. |  |
| 09 | 0xBC2E7 | 0xB01E0 | 5 | Sets a bit flag value then stores the result. |  |
| 0A | 0xBC2EF | 0xB0220 | 5 | Clears a bit flag value then stores the result. |  |
| 0B | 0xBC2F7 | 0xB03A0 | 3 | Increments a value then store it. |  |
| 0C | 0xBC2FF | 0xB03C0 | 3 | Decrements a value then store it. |  |
| 0D | 0xBC307 | 0xB03E0 | 5 | Gets the bitwise AND result of two values and stores it. |  |
| 0E | 0xBC30F | 0xB0410 | 5 | Gets the bitwise OR result of two values and stores it. |  |
| 0F | 0xBC317 | 0xB0440 | 5 | Gets the bitwise XOR result of two values and stores it. |  |
| 10 | 0xBC31F | 0xB0470 | 5 | Gets the bitwise left-shift result of two values and stores it. |  |
| 11 | 0xBC327 | 0xB04A0 | 5 | Gets the bitwise right-shift result of two values and stores it. |  |
| 12 | 0xBC32F | 0xB04D0 | 3 | Generates a random number via `rand()` and stores it. |  |
| 13 | 0xBC337 | 0xB04F0 | 5 | Generates a random number via `rand()`, with a given remainder, and stores it. |  |
| 14 | 0xBC33F | 0xB05A0 | 5 | Gets the product of two values and stores it. |  |
| 15 | 0xBC347 | 0xB05D0 | 5 | Gets the quotient of two values and stores it. |  |
| 16 | 0xBC34F | 0xB0610 | 7 | Performs a `sin` operation on two values and stores the result. |  |
| 17 | 0xBC357 | 0xB0670 | 7 | Performs a `cos` operation on two values and stores the result. |  |
| 18 | 0xBC35F | 0xB06D0 | 7 | Performs an `atan2` operation on two values and stores the result. |  |
| 19 | 0xBC367 | 0xB0730 | 5 | Reads two values and stores them in flipped order. (Endian swap.) |  |
| 1A | 0xBC36F | 0xB0580 | 3 | Jumps to a new position in the event data. |  |
| 1B | 0xBC377 | 0xB0770 | 1 | Returns from the most recent jump on the `JumpStack`. |  |
| 1C | 0xBC37F | 0xB0880 | 3 | Sets, or updates (decreases), the current `ReqStack[RunPos].WaitTime` value. |  |
| 1D | 0xBC387 | 0xB2110 | 3 | Loads and prints an event message to chat, using `EntityTargetIndex[1]` as the speaker. |  |
| 1E | 0xBC38F | 0xB2D30 | 5 | Tells an entity to look at another entity and begin 'talking'. (This puts the 'talking' entity into an animation where their mouth moves.) |  |
| 1F | 0xBC397 | 0xB2EB0 | 2, 8 | Updates the event position information. |  |
| 20 | 0xBC39F | 0xB34D0 | 2 | Sets the `CliEventUcFlag` flag value. _(This flag is used to lock the player from controlling their character.)_ |  |
| 21 | 0xBC3A7 | 0xB34F0 | 1 | Sets the `EventExecEnd` flag value to `1`. |  |
| 22 | 0xBC3AF | 0xB3510 | 2 | Calls `XiAtelBuff::SetEventHideFlag` for the current event entity. |  |
| 23 | 0xBC3B7 | 0xB2DE0 | 1 | Waits for the local player to interact with a dialog message. |  |
| 24 | 0xBC3BF | 0xB2280 | 7 | Creates a dialog window with selectable options for the player to choose from. |  |
| 25 | 0xBC3C7 | 0xB2950 | 1 | Waits for a dialog select (created by opcode `0x0024`) to be made by the player. |  |
| 26 | 0xBC3CF | 0xAFC80 | 1 | Yields the event VM. |  |
| 27 | 0xBC3D7 | 0xB3940 | 7 | Calls a helper `FUNC_REQSet` which in turn calls `XiEvent::ReqSet` after checking some conditions. | request event on target; ReqSet via ent+0xD4 (E11) |
| 28 | 0xBC3DF | 0xB3E60 | 7 | Similar to opcode `0x0027`, but with extra checks/conditions. The function starts by checking for the current `ReqStack[RunPos].ReqFlag` being set, then will do a similar check setup to `FUNC_REQSet` but will end with calling `XiEvent::GetReqStatus` instead. | wait for requested event to start (E11) |
| 29 | 0xBC3E7 | 0xB4000 | 7 | Similar to opcode `0x0028`. | request wait / poll (E11) |
| 2A | 0xBC3EF | 0xB4290 | 6 | Similar to opcode `0x0028`. | req wait / level check, GetReqLevel each tick (E11) |
| 2B | 0xBC3F7 | 0xB1E90 | 7 | Loads and prints an event message with the given entity as the speaker. |  |
| 2C | 0xBC3FF | 0xB4C30 | 13 | Creates and loads a `CMoSchedularTask` on the desired entity. (Appears to set an entity action.) |  |
| 2D | 0xBC407 | 0xB4F20 | 13 | Creates and loads a zone based `CMoSchedularTask` on the desired entities. (Appears to schedule a zone action.) | zone SetAction via [zoneObj->vt+0x18] (E14) |
| 2E | 0xBC40F | 0xB55E0 | 1 | Sets the `CliEventCancelSetData` flag. If `CliEventCancelSetFlag` is set, also sets the `CliEventCancelFlag` flag. | cancel arm, kuluu's single-flag model sets EventVm.cancel_armed=true; research/XiEvents/OpCodes/0x002E.md |
| 2F | 0xBC417 | 0xB35F0 | 6 | Adjusts the given entities `Render.Flag0` value. |  |
| 30 | 0xBC41F | 0xB5630 | 1 | Sets the `ucoff_continue` flag to 0. |  |
| 31 | 0xBC427 | 0xB5640 | 2, 10 | Updates the event position information. |  |
| 32 | 0xBC42F | 0xB5A20 | 3 | Sets the `ExtData[1]->MainSpeed` value. |  |
| 33 | 0xBC437 | 0xB5A50 | 2 | Adjusts the event entities `Render.Flags0` value. |  |
| 34 | 0xBC43F | 0xB5AA0 | 3 | Appears to load and unload an additional zone to be used with the event. |  |
| 35 | 0xBC447 | 0xB5B80 | 3 | Similar to opcode `0x0034`. This appears to load an additional zone for the event, however this handler does not have a call to `XiZone::Close`. |  |
| 36 | 0xBC44F | 0xB5C60 | 7 | Updates the current `ExtData[1]->EventPos` information, calibrates the current event entity position then calls `XiAtelBuff::CopyAllPosEvent` and `XiAtelBuff::ReqExecHitCheck`. |  |
| 37 | 0xBC457 | 0xB5DE0 | 9 | Updates the current `ExtData[1]->EventPos` and `ExtData[1]->EventDir[1]` information, calibrates the current event entity position then calls `XiAtelBuff::CopyAllPosEvent` and `XiAtelBuff::ReqExecHitCheck`. |  |
| 38 | 0xBC45F | 0xB6190 | 3 | Sets the lower-word of `CliEventModeLocal` to a masked value. |  |
| 39 | 0xBC467 | 0xB6150 | 3 | Sets the current `ExtData[1]->EventDir[1]` value. |  |
| 3A | 0xBC46F | 0xB2C90 | 7 | Converts a float `Yaw` value to it's single byte representation and stores it. |  |
| 3B | 0xBC477 | 0xB2BA0 | 11 | Gets the current position of the given entity (or uses the `ExtData[1]->EventPos` depending on flags) and stores it. |  |
| 3C | 0xBC47F | 0xB02B0 | 7 | Compares two values (using a shift). If condition is met, sets a bit flag and stores the result. |  |
| 3D | 0xBC487 | 0xB0300 | 7 | Compares two values (using a shift). If condition is met, clears a bit flag and stores the result. |  |
| 3E | 0xBC48F | 0xB0260 | 7 | Tests if a bit is set. Adjusts the `ExecPointer` based on the state of the flag. |  |
| 3F | 0xBC497 | 0xB61B0 | 7 | Calculates the remainder of two values and stores the result. |  |
| 40 | 0xBC49F | 0xB61F0 | 9 | Sets a bit flag value and stores it. One usage of this opcode is to tell the client which dialog menu options are enabled/available. |  |
| 41 | 0xBC4A7 | 0xB6260 | 9 | Gets a bit flag value and stores it. One usage of this opcode is to tell the client which dialog menu options are enabled/available. |  |
| 42 | 0xBC4AF | 0xB5610 | 1 | Sets the `CliEventCancelSetData` flag to 0. If `CliEventCancelSetFlag` is set, then `CliEventCancelFlag` is also set to 0. | cancel disarm, event 503's master block runs this as its second opcode (14× in the block, zero re-arms): while disarmed ESC is a no-op and kuluu sends no EVENT_END; research/XiEvents/OpCodes/0x0042.md |
| 43 | 0xBC4B7 | 0xB63B0 | 2 | Used to tell the server the server when the client has updated an event or has completed it. |  |
| 44 | 0xBC4BF | 0xB6410 | 5 | Tests if the given entity is valid. Adjusts the `ExecPointer` based on the result. |  |
| 45 | 0xBC4C7 | 0xB44D0 | 17 | Loads and starts a scheduled task with the given two entities. |  |
| 46 | 0xBC4CF | 0xB6450 | 2, 4 | Enables and disables the player camera control. Also disables rendering some menus to allow the game to play cutscenes without unneeded info on screen. |  |
| 47 | 0xBC4D7 | 0xB62C0 | 2, 10 | Updates the players location during an event. This opcode will send an `0x005C` packet to the server to inform it of your position change. |  |
| 48 | 0xBC4DF | 0xB2210 | 3 | Loads and prints an event message to chat, without a speaker entity. |  |
| 49 | 0xBC4E7 | 0xB1DF0 | 7 | Loads and prints an event message to chat, without a speaker entity. |  |
| 4A | 0xBC4EF | 0xB6710 | 9 | Tells an entity to look at another entity. |  |
| 4B | 0xBC4F7 | 0xB6880 | 7 | Updates the given entities yaw direction. |  |
| 4C | 0xBC4FF | 0xB6960 | 1 | Sets the event entities `StatusEvent` to 8 if a specific `Render.Flags0` bit is not set. (Open door.) |  |
| 4D | 0xBC507 | 0xB6A10 | 1 | Sets the event entities `StatusEvent` to 9 if a specific `Render.Flags0` bit is not set. (Close door.) |  |
| 4E | 0xBC50F | 0xB3590 | 6 | Sets the entities event hide flag within `Render.Flags0`. |  |
| 4F | 0xBC517 | 0xB69C0 | 3 | Sets the event entities `StatusEvent` to the given value if a specific `Render.Flags0` bit is not set. |  |
| 50 | 0xBC51F | 0xB4D20 | 13 | Ends a `CMoSchedularTask`. |  |
| 51 | 0xBC527 | 0xB5010 | 13 | Ends a zone based `CMoSchedularTask`. |  |
| 52 | 0xBC52F | 0xB48E0 | 15 | Ends a `CMoSchedularTask`. (Load / Main) | start/load-and-run scheduler, 0x62E90 (E13) |
| 53 | 0xBC537 | 0xB4E10 | 13 | Waits for the given entities schedular to finish its current action. | is moving action, vcall actor vt+0x2AC (E13) |
| 54 | 0xBC53F | 0xB5100 | 13 | Waits for the zone schedular to finish its current action. | zone is moving action, [zoneObj->vt+0x20] (E13) |
| 55 | 0xBC547 | 0xB4960 | 15 | Waits for the Main/Load schedular to finish its current action. | is moving scheduler, 0x62EE0 (E13) |
| 56 | 0xBC54F | 0xB66D0 | 5 | Deprecated. This opcode does not do anything with the values it reads anymore. This appears to be deprecated. |  |
| 57 | 0xBC557 | 0xB0360 | 3 | Creates a frame delay from the current frame delay value and stores it. |  |
| 58 | 0xBC55F | 0xB0390 | 1 | Yields the event VM. |  |
| 59 | 0xBC567 | 0xB6A70 | 4, 6, 7, 8 | Handles multiple cases regarding updating an entities data for events. |  |
| 5A | 0xBC56F | 0xB3200 | 2, 8 | Updates the event position information. | CodeMOVE2, alias of 0x1F MOVE (retail's "uncalibrated twin"); mode-gated width: sub-mode 0 → 8 bytes, sub-mode 1 → 2 bytes; kuluu `opcode_meta sub_size(0x5A,·)` = {0=>8, 1=>2} |
| 5B | 0xBC577 | 0xB5200 | 15, 17 | Loads an extended schedular task. | LOADEXTSCHEDULER; helper B5220(0,1,0); width 15 (E3) |
| 5C | 0xBC57F | 0xB6E40 | 4, 6 | Handles multiple cases regarding the music player. |  |
| 5D | 0xBC587 | 0xB7050 | 5 | Sets, or eases, the current playing music to a new volume. |  |
| 5E | 0xBC58F | 0xB71F0 | 5 | Appears to stop the event entities current action and reset them back to an idle motion. |  |
| 5F | 0xBC597 | 0xB72D0 | 2, 6, 14, 16, 18 | This handler has a few cases, most of which call other opcode handlers and react based on their returns. | sub-scheduler; cases 3-6 call the 0x5B/0x66 helper (E3) |
| 60 | 0xBC59F | 0xB7400 | 2, 4, 6 | Handler with multiple use cases. |  |
| 61 | 0xBC5A7 | 0xB74F0 | 2 | Adjusts the event entities `Render.Flags2` value. |  |
| 62 | 0xBC5AF | 0xB44E0 | 17 | Handler that calls the same helper call as opcode `0x0045`, just with a different second argument. |  |
| 63 | 0xBC5B7 | 0xB7560 | 3 | Sets the event entity to play an animation then waits for it to complete. |  |
| 64 | 0xBC5BF | 0xB75D0 | 11 | Calculates and stores the distance between the given points. |  |
| 65 | 0xBC5C7 | 0xB7870 | 11 | Calculates and stores the 3D distance between the given entities. |  |
| 66 | 0xBC5CF | 0xB5210 | 15, 17 | Handler that calls the same helper call as opcode `0x005B`, just with a different arguments. | LOADEXTSCHEDULER2/Tpc; helper B5220(1,1,0); width 15 (E3) |
| 67 | 0xBC5D7 | 0xB79D0 | 5 | Tells the client to hide the entire HUD UI elements during the cutscene. (ie. The compass, status icons, chat, menus, etc.) | HIDE_HUD, pseudocode is PresetEventMessageMode ×2 + CompassDrow=1 only (research/XiEvents/OpCodes/0x0067.md); never touches the map window; kuluu exempts the dialog panel root and both map roots from cutscene HUD-hide via HudHideExempt |
| 68 | 0xBC5DF | 0xB7A30 | 1 | Tells the client to unhide the entire HUD UI elements. (ie. The compass, status icons, chat, menus, etc.) |  |
| 69 | 0xBC5E7 | 0xB7A70 | 4 | Sets the sound volume of the desired sound type. |  |
| 6A | 0xBC5EF | 0xB7B00 | 7 | Changes the sound volume of the desired sound type. |  |
| 6B | 0xBC5F7 | 0xB7080 | 9 | Appears to stop the given entities current action and reset them back to an idle motion. |  |
| 6C | 0xBC5FF | 0xB7640 | 9 | Fades an enities color in and out. This can be used to both set just the alpha of the entity, but also the color. This works in stages to allow the color to fade in and/or out smoothly, or immediately, depending on the time values set. |  |
| 6D | 0xBC607 | 0xB7860 | 7 | Deprecated. This opcode appears to be deprecated, it does nothing. |  |
| 6E | 0xBC60F | 0xB7C50 | 7 | Sets the given entity to play an emote animation. |  |
| 6F | 0xBC617 | 0xB0800 | 1 | Delays the event VM execution until `ReqStack[RunPos].WaitTime` has reached 0. Used as a yieldable sleep call. |  |
| 70 | 0xBC61F | 0xB7DE0 | 1 | Checks the event entity for a render flag, yields if set. Otherwise, cancels the entity movement and advances. |  |
| 71 | 0xBC627 | 0xB7E20 | 2, 4, 6, 8, 10 | Handles the usage of string input from the player during events. Such as password prompts and similar. |  |
| 72 | 0xBC62F | 0xB84C0 | 4, 6, 10 | Appears to load event based weather information and update the weather accordingly for it. |  |
| 73 | 0xBC637 | 0xB4550 | 11 | Schedules tasks for casting magic on the two given entities. |  |
| 74 | 0xBC63F | 0xB74A0 | 2 | Adjusts the event entities `Render.Flags1` value. |  |
| 75 | 0xBC647 | 0xB8670 | 2, 4 | Loads a room and updates the players sub-region with the server. |  |
| 76 | 0xBC64F | 0xB7D60 | 5 | Checks the given entities `Render.Flags0` and `Render.Flags3` and yields if successful. |  |
| 77 | 0xBC657 | 0xB8720 | 5 | Disables the game clock and sets the client to a specific time for the event. Can also set the weather at the same time. |  |
| 78 | 0xBC65F | 0xB87C0 | 1 | Enables the game timer and resets the zone weather. |  |
| 79 | 0xBC667 | 0xB88F0 | 10, 12 | Used to look at / rotate towards another entity. |  |
| 7A | 0xBC66F | 0xB3A60 | 2, 6, 7, 8 | Case `0` appears to reset the given entities entire event VM. `ExecPointer`, `RunPos`, `JumpTableIndex` are all set back to 0. All `ReqStack` entries are set to their default values. |  |
| 7B | 0xBC677 | 0xB8A10 | 5 | Unsets the given entities talking status, setting their `NpcSpeechFrame` back to -1. |  |
| 7C | 0xBC67F | 0xB8A90 | 6 | Adjusts the given entities `Render.Flags2` value. |  |
| 7D | 0xBC687 | 0xB8B30 | 3 | Loads and starts a scheduled task using the local player as the entity. (Appears to be used to display rank up animations.) |  |
| 7E | 0xBC68F | 0xB8B90 | 6, 8, 16, 18 | Multi-purpose opcode relating to chocobos and mounts. |  |
| 7F | 0xBC697 | 0xB2AB0 | 1 | Waits for a dialog select to be made by the player. |  |
| 80 | 0xBC69F | 0xB8EA0 | 5 | Tests the given entity for several conditions. Yields or moves forward depending on the results. _(Appears to be used to check if the entity is loading an action or similar.)_ |  |
| 81 | 0xBC6A7 | 0xB8FC0 | 6 | Sets if the given entity is blinking. |  |
| 82 | 0xBC6AF | 0xB9050 | 7 | Finds and hit tests a rect based on the current event entities position. |  |
| 83 | 0xBC6B7 | 0xB90F0 | 3 | Gets and stores the current game time. |  |
| 84 | 0xBC6BF | 0xB9110 | 1 | Adjusts the event entities `Render.Flags3` value. |  |
| 85 | 0xBC6C7 | 0xB9130 | 1 | Opens a mog house sub-menu depending on the passed parameter. |  |
| 86 | 0xBC6CF | 0xB8F40 | 6 | Adjusts the given entities `Render.Flags3` value. |  |
| 87 | 0xBC6D7 | 0xB9150 | 2 | Used for handling the generation of world passes. Sends `0x001B` packets to handle the various world pass functionalities. |  |
| 88 | 0xBC6DF | 0xB9230 | 2 | Used for handling the generation of world passes. Sends `0x001B` packets to handle the various world pass functionalities. |  |
| 89 | 0xBC6E7 | 0xB9310 | 3 | Opens the desired map (ie. `/map`), preparing it for usage within the event. (ie. NPCs that mark your map/show you around.) |  |
| 8A | 0xBC6EF | 0xB93D0 | 1 | Closes the map window. (ie. after being opened via opcode `0x0089`) | CloseMap2, unconditional; no RetFlag between open/marker/close, so retail's EventIdle pacing runs all three within one tick (no visible flash) and only the marker persists; kuluu event_map_sync_system reproduces this in one pass |
| 8B | 0xBC6F7 | 0xB94A0 | 25 | Sets, or updates, a marker point on the players map. (ie. Used by NPCs that help new players and mark your map.) | map marker, event 503 places "Ailevia" at her authored position (zone 230, world (-10.264,-0.363)); kuluu upserts it into MapScreenDots/MapMarkers where it persists after the map closes; research/XiEvents/OpCodes/0x008B.md |
| 8C | 0xBC6FF | 0xB98F0 | 2, 8, 10, 12, 14 | This handler is used for multiple purposes, related to crafting. (ie. Requesting recipes, synth support, and similar.) |  |
| 8D | 0xBC707 | 0xB9340 | 5 | Opens the map window with the given properties. This handler is used mainly when an NPC opens your map but it is not with the sub-menus visible. Mainly to show an overview of the map with no extra bloat on screen or markings on the map. |  |
| 8E | 0xBC70F | 0xB6990 | 1 | Sets the event entities event status to `45` if valid. |  |
| 8F | 0xBC717 | 0xB6A40 | 1 | Sets the event entities event status to `46` if valid. |  |
| 90 | 0xBC71F | 0xB3550 | 1 | Adjusts the event entities `Render.Flags0` and `Render.Flags1` values. |  |
| 91 | 0xBC727 | 0xB9B80 | 3 | Sets the `ExtData[1].MainSpeedBase` value. |  |
| 92 | 0xBC72F | 0xB9BB0 | 6 | Adjusts the given entities `Render.Flags3` value. |  |
| 93 | 0xBC737 | 0xB9D40 | 3 | Appears to display an items information. _(Perhaps the same manner with how crafting shows results?)_ |  |
| 94 | 0xBC73F | 0xB9CC0 | 6 | Adjusts the given entities `Render.Flags3` value. |  |
| 95 | 0xBC747 | 0xB9C30 | 3 | Sets the event entity up for being an event based npc. |  |
| 96 | 0xBC74F | 0xB9C80 | 1 | Unsets the event entity from being an event based npc. |  |
| 97 | 0xBC757 | 0xBA0D0 | 5 | Saves the current zone `WindBase` and `WindWidth` values then sets new ones. |  |
| 98 | 0xBC75F | 0xB8640 | 1 | Yields if the zone is loading data, continues otherwise. |  |
| 99 | 0xBC767 | 0xB7CF0 | 5 | Yields if the given entity is playing an animation, continues otherwise. |  |
| 9A | 0xBC76F | 0xB6E00 | 1 | Yields until the music server is no longer reading data. |  |
| 9B | 0xBC777 | 0xB7530 | 1 | Yields if the event entity is playing an animation, continues otherwise. |  |
| 9C | 0xBC77F | 0xBA110 | 3 | Stores the client language id. |  |
| 9D | 0xBC787 | 0xBA1A0 | 6, 8, 9, 10, 23, ??? | Handler that has multiple purposes, mainly focused around handling strings. |  |
| 9E | 0xBC78F | 0xBA8B0 | 2 | Sets the `PTR_RectEventSendFlag` value. |  |
| 9F | 0xBC797 | 0xB44F0 | 17 | Handler that calls the same helper call as opcode `0x0045`, just with a different second argument. |  |
| A0 | 0xBC79F | 0xB4970 | 15 | Handler that calls the same helper call as opcode `0x0055`, just with a different second argument. |  |
| A1 | 0xBC7A7 | 0xB48F0 | 15 | Handler that calls the same helper call as opcode `0x0052`, just with a different second argument. |  |
| A2 | 0xBC7AF | 0xB4980 | 15 | Handler that calls the same helper call as opcode `0x0055`, just with a different second argument. |  |
| A3 | 0xBC7B7 | 0xB4900 | 15 | Handler that calls the same helper call as opcode `0x0052`, just with a different second argument. |  |
| A4 | 0xBC7BF | 0xBA8E0 | 2 | Adjusts the event entities `Render.Flags3` value. |  |
| A5 | 0xBC7C7 | 0xBA930 | 2 | Adjusts the event entities `Render.Flags3` value. |  |
| A6 | 0xBC7CF | 0xBA9D0 | 2, 4 | Requests the event map number from the server by sending a `0x00EB` packet. Sets the `PTR_RecvEventMapNumFlag` to mark the client as awaiting for a response and then yields until it is unset. |  |
| A7 | 0xBC7D7 | 0xBAA70 | 2, 4 | Waits for the server to respond to a client request. This is used with battlefield registration NPCs. _(ie. Dynamis, Moblin Maze Mongers, Salvage, etc.)_ |  |
| A8 | 0xBC7DF | 0xB9790 | 6 | Opens the map (if requested), unlocks and renames markers. |  |
| A9 | 0xBC7E7 | 0xBAB60 | 3 | Disables the game time and sets it to a specific given time. |  |
| AA | 0xBC7EF | 0xBABF0 | 17 | Gets a value to be used as a Vana'diel timestamp. Converts that timestamp into the various time parts and stores them. |  |
| AB | 0xBC7F7 | 0xBACA0 | 2, 4, 6 | Handles various sub-cases; mostly dealing with altering entity render flags. |  |
| AC | 0xBC7FF | 0xBB190 | 4, 6, 8 | Handles multiple sub-cases. |  |
| AD | 0xBC807 | 0xBB350 | 12 | Handler with multiple sub-cases, used to do various scheduler actions against the two given entities. |  |
| AE | 0xBC80F | 0xBB630 | 6, 8, 10 | Handles multiple sub-cases. Doesn't seem to have any specific purpose. |  |
| AF | 0xBC817 | 0xBB9D0 | 8 | Gets and stores the camera position values. |  |
| B0 | 0xBC81F | 0xB1FB0 | 12 | Loads and prints an event message to chat. Uses the given entities as the speaker and listener. |  |
| B1 | 0xBC827 | 0xBBA80 | 4 | Gets and stores the value of a flag. `PTR_UnknownValue` is part of the main `app` object which is initialized to `128`. This valid doesn't seem to ever change, and has been the same since the original beta of the game. _At this time, the purpose of this value is unknown._ |  |
| B2 | 0xBC82F | 0xB0920 | 2, 4 | Handler has two modes. The first mode requests opening the delivery box. The second mode is to wait a certain amount of time, used to wait for the delivery box to open. |  |
| B3 | 0xBC837 | 0xBBB00 | 2, 4, 14, 18 | This handler is used for dealing with the rankings boards. For example, the fishing rank boards with `Chenon` in Selbina. |  |
| B4 | 0xBC83F | 0xB0A10 | 2, 3, 4, 6, 12, 20 | Handler with multiple sub-usages. |  |
| B5 | 0xBC847 | 0xB1100 | 4 | Sets the current event entities name. |  |
| B6 | 0xBC84F | 0xB1160 | 2, 4, 6, 14, 16, 20 | Handler with multiple sub-usages. Related to entity looks / gear visuals. |  |
| B7 | 0xBC857 | 0xAFEF0 | 8, 10 | Handler with multiple sub-usages. |  |
| B8 | 0xBC85F | 0xB9610 | 27 | Opens the map (if requested), adds and sets markers. |  |
| B9 | 0xBC867 | 0xB9830 | 8 | Opens the map (if requested), edits and renames a marker. _(Name is taken from the event Read buffer.)_ |  |
| BA | 0xBC86F | 0xB5F80 | 13 | Obtains the given entity, if valid, attempts to calibrate its position then calls `XiAtelBuff::CopyAllPosEvent` and `XiAtelBuff::ReqExecHitCheck`. |  |
| BB | 0xBC877 | 0xB4500 | 17 | Handler that calls the same helper call as opcode `0x0045`, just with a different second argument. |  |
| BC | 0xBC87F | 0xB4990 | 15 | Handler that calls the same helper call as opcode `0x0055`, just with a different second argument. |  |
| BD | 0xBC887 | 0xB4910 | 15 | Handler that calls the same helper call as opcode `0x0052`, just with a different second argument. |  |
| BE | 0xBC88F | 0xB3E30 | 3 | Stores the current `ReqStack[RunPos].WhoServerId` value. |  |
| BF | 0xBC897 | 0xBBD90 | 8, 10 | Handler that is used for chocobo racing. This handler has debug messages left in, so it can be translated to actual opcode names. |  |
| C0 | 0xBC89F | 0xBA980 | 3 | Adjusts the event entities `Render.Flags3` value. |  |
| C1 | 0xBC8A7 | 0xB5510 | 5 | Obtains the given entity, tests it for something. If successful, then the last action is killed and its resp data is deleted. |  |
| C2 | 0xBC8AF | 0xBBF90 | 2, 4, 6 | The purpose of this opcode is currently unknown. |  |
| C3 | 0xBC8B7 | 0xBC010 | 7 | Copies a string value into an unknown buffer array. |  |
| C4 | 0xBC8BF | 0xB4560 | 11 | Handler that calls the same helper call as opcode `0x0073`, just with a different arguments. |  |
| C5 | 0xBC8C7 | 0xB4510 | 17 | Handler that calls the same helper call as opcode `0x0045`, just with a different second argument. |  |
| C6 | 0xBC8CF | 0xB49A0 | 15 | Handler that calls the same helper call as opcode `0x0055`, just with a different second argument. |  |
| C7 | 0xBC8D7 | 0xB4920 | 15 | Handler that calls the same helper call as opcode `0x0052`, just with a different second argument. |  |
| C8 | 0xBC8DF | 0xB9380 | 7 | Opens the map window with the given parameters. | open map, event 503's epilogue opens zone 230 in tutorial mode; see the 0x8A note for same-tick pacing |
| C9 | 0xBC8E7 | 0xB87F0 | 1 | Enables the game timer. |  |
| CA | 0xBC967 | 0xAFC90 | N/A | Deprecated. No handler exists for this opcode at this time. | falls to default @AFC90 |
| CB | 0xBC967 | 0xAFC90 | N/A | Deprecated. No handler exists for this opcode at this time. | falls to default @AFC90 |
| CC | 0xBC8EF | 0xB9DA0 | 4, 6, 10, 14 | This opcode appears to be used to open and display information windows for various things. Mainly items. |  |
| CD | 0xBC8F7 | 0xB4520 | 17 | Handler that calls the same helper call as opcode `0x0045`, just with a different second argument. |  |
| CE | 0xBC8FF | 0xB49B0 | 15 | Handler that calls the same helper call as opcode `0x0055`, just with a different second argument. |  |
| CF | 0xBC907 | 0xB4930 | 15 | Handler that calls the same helper call as opcode `0x0052`, just with a different second argument. |  |
| D0 | 0xBC90F | 0xB4530 | 17 | Handler that calls the same helper call as opcode `0x0045`, just with a different second argument. |  |
| D1 | 0xBC917 | 0xB49C0 | 15 | Handler that calls the same helper call as opcode `0x0055`, just with a different second argument. |  |
| D2 | 0xBC91F | 0xB4940 | 15 | Handler that calls the same helper call as opcode `0x0052`, just with a different second argument. |  |
| D3 | 0xBC927 | 0xB7150 | 6 | Gets the given entity and calls a helper function that clears its motion queue lists. |  |
| D4 | 0xBC92F | 0xB2290 | 2, 6, 8, 12 | Handles multiple sub-opcodes. These appear to be related to opening the map and querying the user for input. |  |
| D5 | 0xBC937 | 0xB4540 | 17 | Handler that calls the same helper call as opcode `0x0045`, just with a different second argument. |  |
| D6 | 0xBC93F | 0xB49D0 | 15 | Handler that calls the same helper call as opcode `0x0055`, just with a different second argument. |  |
| D7 | 0xBC947 | 0xB4950 | 15 | Handler that calls the same helper call as opcode `0x0052`, just with a different second argument. |  |
| D8 | 0xBC94F | 0xBC070 | 6, 8, 12 | Sets the `ExtData[1]->EventDir` information for the given entity. |  |
| D9 | 0xBC957 | 0xB7BF0 | 2 | Sets an unknown flag value. |  |
| DA | 0xBC95F | 0xB7C20 |  |  |  |

## Notes on width vs. local decode

- 0x5B and 0x66 list "15, 17" in XiEvents because the shared helper @0xB5220 advances ExecPointer by
  0xF (+2 if param3). Local decode (E3) shows **no caller passes param3 = 1**, so the shipped width is
  always 15. The "17" form is unreachable in this build's event data.
- Several opcodes list multiple widths because they branch on a sub-opcode byte read from EventData;
  the table records the documented set, not a single value.
- This table is the map for T2 to T6 and for anyone after: every handler RVA here was located from
  the table, not by pattern search (the patterns in E1 were used to confirm function identities).

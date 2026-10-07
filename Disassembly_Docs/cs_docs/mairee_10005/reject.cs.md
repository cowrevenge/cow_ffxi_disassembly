# Mairee (Upper Jeuno, zone 244) — event 10005, rental refused

Event DAT `ROM/21/53.DAT` (file 6064), block for actor `0x010F4048` (Mairee),
tag `10005` at offset `0x0121` (285). Strings are zone 244's string DAT
`ROM/25/53.DAT` (file 6664).

The Phoenix server fires this from `xi.chocobo.renterOnTrigger` when the
player lacks the Chocobo License key item, is below the zone's level
requirement (20 for Upper Jeuno), or (in past zones) has not completed the
WOTG mission "Back to the Beginning". No params are passed.

Offsets are bytes into the 301-byte `EventData` of block `0x010F4048`.
"player" = `0x7FFFFFF0`.

## The refusal

| off | op | operands | what it does | actor | kuluu status |
|---|---|---|---|---|---|
| `0x0121` | `0x03` GET_STORE | `WZ[9] = Imid[3]`=138 | stash 138 in `WZ[9]` | — | DONE |
| `0x0126` | `0x1E` LOOK_TALK | target=player | NPC turns to the player and starts talking | Mairee | DONE (scene gate) |
| `0x012B` | `0x1D` MESSAGE | 6720 | "If you wish to ride a chocobo, you must possess  and have a high enough job level." | Mairee | DONE |
| `0x012E` | `0x23` MESWAIT | — | hold for dismiss | player | DONE |
| `0x012F` | `0x21` EXECEND | — | end the request | — | DONE |

Note the double space in 6720: the retail string has a placeholder slot for
the license name the server is expected to substitute; Phoenix leaves it
empty, so the line reads "must possess  and have a high enough job level".

## Kuluu coverage notes

All five opcodes are handled. `0x1E` LOOK_TALK runs through the scene gate
(`ffxi-event/src/vm/scene.rs` `OP_LOOK_AND_TALK` → `EventCue::ActorLookAt` →
`CutsceneCue::ActorLookAt` → the renderer's look-at consumer in
`kuluu-render/src/scheduler_runtime.rs`) on the live path; the mouth
animation half is not produced (kuluu has no talking-state consumer, the same
category as `0x7B` in `../cs-opcode-coverage.md` §3).

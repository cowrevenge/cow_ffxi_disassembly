# Achantere, T.K. (zone 231) event 32762 — why the Signet / Home Point cast does not play in kuluu

Both branches of this event play their effect on the player with the **same opcode, `0x73`
MAGICSCHEDULOR**. The Signet branch plays key `497` at `0x0b3a`; the Home Point branch plays key `504`
at `0x0b4f`. Neither has a dedicated arm in the kuluu event VM, so neither produces a cue, so the
renderer never plays the cast.

## The two marked lines

### Signet — `0x0b3a` `0x73` MAGICSCHEDULOR, key `497`

- **Opcode:** `0x73` MAGICSCHEDULOR (width 11).
- **Target:** `ent1` = the guard / event entity (`0x7FFFFFF8`), `ent2` = the player (`0x7FFFFFF0`).
  Per `research/XiEvents/OpCodes/0x0073.md` the handler calls
  `FUNC_XiActor_Unknown(guard, key, player, 'main')` — it plays the `main`-tagged routine named by the
  key on the guard, with the player as the target/partner.
- **Key / id:** `497`, read as a work-offset operand (`Imid[0x46]`). It is a numeric routine key, not a
  4CC and not a DAT id.
- **What `ffxi-event/src/vm.rs` does today:** **no arm.** `0x73` is absent from the `match op` in
  `EventVm::step`, so it falls into the default arm (`vm.rs` `_ =>`), which sees
  `OPCODE_META[0x73] = { size: 11, jumps: false, sets_ret: false, valid: true }` and simply does
  `exec_pointer += 11` — it **steps over the opcode with no cue**. Nothing is pushed to `self.cues`, so
  the host and the renderer never hear about the cast.

### Home Point — `0x0b4f` `0x73` MAGICSCHEDULOR, key `504`

- **Opcode:** `0x73` MAGICSCHEDULOR (width 11).
- **Target:** `ent1` = the guard / event entity (`0x7FFFFFF8`), `ent2` = the player (`0x7FFFFFF0`),
  same `FUNC_XiActor_Unknown(guard, key, player, 'main')` call as the Signet line.
- **Key / id:** `504`, read as a work-offset operand (`Imid[0x8D]`).
- **What `ffxi-event/src/vm.rs` does today:** **no arm**, identical to the Signet line — the default
  arm advances `exec_pointer` by 11 and emits **no cue**. The home-point cast is silently skipped.

(For contrast, the `0x45` LOADEVENTSCHEDULER2 lines this event also authors — the `qstc` routine out of
DAT `30905` = `ROM/62/111.DAT` — *do* have a dedicated arm at `vm.rs:1432` that emits
`EventCue::Scheduler`; but those fire on the entry and supply paths, not on the Signet or Home Point
branches, so they are not what makes either of these two effects.)

## Why the animation does not play, and the fix shape

The Signet and Home Point casts are both `0x73`, and the kuluu event VM has no `0x73` arm: the opcode
falls to the default `match` arm, which only advances the instruction pointer by the table width (11)
and pushes no `EventCue`. With no cue, `kuluu-render`'s cutscene-motion system has nothing to dispatch,
so the guard never plays the cast and the player never sees the spell vfx — the event just runs the
dialog and the `WAIT`, then ends. (This is the same class of gap as any unported motion opcode: the VM
"runs" the line as a no-op advance rather than refusing it, because `0x73` is a valid, non-jumping,
non-yielding opcode in `OPCODE_META`.)

The fix is to add a `0x73` arm to the `match op` in `ffxi-event/src/vm.rs` that reads the key
(`getworkofs` at offset 1, i.e. `497` / `504`) and both actors (`eventgetcode2` at offsets 3 and 7) and
pushes a motion cue carrying them — an `EventCue::ActorMotion`-shaped cue with `actor1` = guard,
`actor2` = player, and the numeric key — mirroring the existing `OP_SCHEDULOR` (`0x2C`) arm at
`vm.rs:1415` (which pushes `EventCue::ActorMotion` and a `pending_action_starts` entry so a following
`0x53` WAITSCHEDULOR parks correctly). The cue then flows to the host and is consumed by
`dispatch_cutscene_motion` in `kuluu-render/src/scheduler_runtime.rs` (the `CutsceneCue::ActorMotion`
arm at `scheduler_runtime.rs:2372`), which resolves the key to a routine and plays it on the guard with
the player as partner, and reports its finish to release the session's pending hold. The one open design
point is resolving the numeric key (`497`/`504`) to the concrete magic-cast routine — `0x2C`'s key is a
4CC into the actor's own motion resources, whereas `0x73`'s key is a work-offset value that
`FUNC_XiActor_Unknown` interprets as the cast routine, so the renderer's resolution for that key space
needs to be pinned (likely a scheduler/ cast-table lookup) before the arm is wired.

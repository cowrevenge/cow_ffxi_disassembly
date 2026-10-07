# Mairee (zone 244) events 10002 / 10005 — coverage report

Full opcode tables: [`rent.cs.md`](rent.cs.md) (10002, the rental cutscene,
NPC program + the three REQSET player-part programs) and
[`../mairee_10005/reject.cs.md`](../mairee_10005/reject.cs.md) (10005, the
refusal).

## NPC surface

Mairee's block `0x010F4048` owns exactly three tags: `0xFFFF` (placeholder,
offset 0), `10002` (offset 1) and `10005` (offset 285). The chocobo block
`0x010F4045` owns a trivial `10002` (one `00` END byte). No other events. So
10002 + 10005 plus the player-part REQSET snippets are the entire NPC surface.

## Findings

### The one gap: the "talk" half of `0x1E` LOOK_TALK

`0x1E` appears three times: `0x0009` / `0x0029` in 10002 (Mairee looks at the
player), `0x0126` in 10005 (Mairee looks at the player), and at offset 14353
in the tag-20 player-part (the player looks at the chocobo).

**Correction to the earlier handoff:** `0x1E` is *not* missing. It is owned by
the scene gate — `ffxi-event/src/vm/scene.rs` `OP_LOOK_AND_TALK` — which is
active whenever the session knows the player position (always in live play;
`kuluu-session/src/session/mod.rs` calls `set_player_position` on the live
path). The scene arm emits `EventCue::ActorLookAt` (the motion half: the
entity turns toward the named actor), the session translates it to
`CutsceneCue::ActorLookAt` (`kuluu-session/src/event_dialog.rs`), and the
renderer consumes it (`kuluu-render/src/scheduler_runtime.rs`, rotates the
actor's Transform to face the target). The earlier "MISSING 0x1E" conclusion
came from checking only `vm.rs` main match and from `zz-event-drive`, which
does not attach a scene, so the opcode fell to the default arm in the harness.

What is genuinely not produced is the **talk half** (the mouth animation):
kuluu has no talking-state / mouth-anim consumer anywhere
(`kuluu-render/src/ffxi_actor_render.rs` has no `talk?` clip reference). That
is the same category as `0x7B` ("unsets the talking status") in
[`../cs-opcode-coverage.md`](../cs-opcode-coverage.md) §3: "kuluu has no
talking-state / speech-bubble consumer". A cue for it would carry a value the
renderer has no documented meaning for, so it is recorded, not implemented.

### Everything else is covered

- `0x37` SET_EVENT_POS: scene-gated, `EventCue::ActorPlace` for non-player
  actors (both tag-20 and tag-24 hits are on the player, so the width-skip
  path applies there — the server round trip owns player positioning).
- `0x31` SMOVE: handled (`ActorMove` cue). Caveat: the linear `zz-*` walkers
  desync on its case-1 poll — they assume the 10-byte case-0 width, but case 1
  is a 2-byte poll that yields until arrival (`research/XiEvents/OpCodes/0x0031.md`:
  `ExecPointer += 2` on arrival, no advance while the entity is still moving).
  A raw walk of tag 24 therefore stops at the poll; the VM handles it
  correctly.
- `0x33` (two hits in tag 20): default-arm skip, documented in
  `../cs-opcode-coverage.md` §3 ("undocumented flag bit").
- All scheduler / message / camera / mount opcodes (`0x2C`, `0x53`, `0x45`,
  `0x55`, `0x1D`, `0x23`, `0x24`, `0x25`, `0x46`, `0x42`, `0x4E`, `0x5D`,
  `0x1C`, `0x6F`, `0x70`, `0x7E`, `0x27`, `0x2A`, `0x02`, `0x01`, `0x03`,
  `0x30`, `0x21`, `0x00`) have arms and advance / emit like retail.
- `zz-event-drive` runs both events clean to `end_para=0` (auto-Yes; the
  offline harness skips the timed waits).

## Tools used

- `zz-block-owner` (gained an optional tag-index argument this round, to read
  master-block tag offsets 20/21/24 past its 12-entry cap).
- `zz-event-ops` (linear listing of the NPC programs).
- `zz-47-scan dump` (walks the placeholder-id player-part snippets by tag).
- `zz-c4-dump` (raw windows: the 10002 tail, the tag-24 desync region).
- `zz-event-drive` (clean-run check).
- `dat-zone-string-grep` / `zz-string-dump` (verbatim strings 6720–6725).
- `ffxi_dat_find.py resolve` (client-side file-id → ROM path: 6064 →
  `ROM/21/53.DAT`, 6664 → `ROM/25/53.DAT`).

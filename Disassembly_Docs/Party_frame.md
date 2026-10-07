# Party_frame — how the solo/party UI is coded and loaded

> **Consolidated 2026-09-13 from four `Cow_doc/` files:**
> `PARTY_FRAME.md` (implementation spec), `PARTY_FRAME_REVIEW.md` (v0 code-vs-spec
> diagnostic), `PARTY_FRAME_TODO.md` (v1 status + open decisions),
> `FIX_PARTY_HUD_ZONE_IN.md` (zone-in staleness bug + fix).
> Timeline: spec → v0 review → v1 (committed) → zone-in fix (implemented in-tree).
> All "planned" items below were verified against the tree on 2026-09-13.

## 1. What it is

An XIUI-style party/alliance frame on the Kuluu in-game HUD (Rust + Bevy), driven
**entirely client-side** — no Ashita, no external tooling.

- **Party A window** (self + own party) draws with **L1 Compact Vertical** geometry.
- **Alliance B/C windows** draw with **L2 Super Compact** geometry.
- **Self is row 0 of Party A** (XIUI behavior); the old Solo/Party label in
  `hud/self_hud.rs` was removed.
- **Design rule (house, not XIUI):** this is a *client HUD*. Every feature lands
  **ON by default**. There is no user-facing settings UI; the only knobs are the
  Debug-menu "UI Settings" panel (click-cycle rows in `party_frame.rs`). No feature
  may require the player to opt in.

Module: **`kuluu-render/src/hud/party_frame.rs`** (~1,600 lines as of 2026-09-13;
declared in `hud/mod.rs`), following the existing HUD pattern (`self_hud.rs`,
`target_panel.rs`): Bevy UI nodes, one spawn function, per-frame update system,
styles from `hud/style.rs`.

Wiring:
- `spawn_party_frames()` — once: create the three window roots (A always; B/C hidden
  until populated), mount into the HUD tree.
- `update_party_frame_system()` — per frame, after snapshot upsert: regroup rows from
  `SceneSnapshot.party`, rebuild rows, write text/bar fills/highlights.
- Mounting: the reserved **`ColumnPanel::ROSTER`** slot in `hud/panel_column.rs`
  (order 1 — between SELF_HUD and TARGET). B/C stack above A in the same column
  (8px gaps) — decision: keep column stacking, fixed positions, no user offsets.

## 2. Data sources

| Input | Source |
|---|---|
| Roster, up to 3 parties × 6 members: `id, act_index, name, hp, mp, tp, hp_pct, mp_pct, zone_no, main/sub job+lv, is_party_leader, is_alliance_leader, party_no (0..2), in_mog_house` | `SessionState.party: Vec<PartyMember>` — `kuluu-session/src/state.rs`. Populated by s2c `GROUP_LIST 0x0DD` + `GROUP_ATTR 0x0DF` (opcodes in `ffxi-proto/src/map.rs`; handler `kuluu-session/src/session/mod.rs`; upsert/merge in `state.rs`). Cleared on zone change. |
| Same data in render world | `SceneSnapshot.party` — `kuluu-snapshot/src/lib.rs`; maintained by `upsert_party` in `kuluu-render/src/snapshot.rs`. Self lookup: `resolve_self(&snap.party, snap.self_char_id)`. |
| Current target entity id | Bevy resource `Target { id: Option<u32> }` — `kuluu-render/src/scene.rs`. Set by click-to-target (`picking.rs`), auto-cleared when the entity vanishes. |
| Subtarget (transient, while flow is active) | `InputMode::SubTarget { candidate: Option<u32>, .. }` — `kuluu-render/src/input_mode.rs`; driven from `kuluu/src/view_native/text_input/mod.rs`. |
| Self buffs (icons + expiry) | s2c `0x063` MISCDATA → `status_icons` / `status_icon_expiries`. |
| Self cast state (name, elapsed/total ms, interrupted) | `SceneSnapshot.self_casting` (`SelfCasting`); drives the feature-gated cast bar (`hud/cast_bar.rs`, behind the `enhanced-cast-bar` cargo feature). |
| Treasure pool non-empty (for "Treas." label) | `kuluu-render/src/hud/treasure_pool.rs` → `SceneSnapshot.treasure_pool`. |
| Entity positions (distance readout, out-of-zone fallback) | `SceneState.snapshot.entities` — id → position; distance = euclidean to self, shown in yalms (1 decimal). |
| Retail name colors (party-aware) | `kuluu-render/src/nameplate_color.rs` (`ncol::PARTY`, `SelfContext`). |
| **Per-member buff list** | s2c **0x076 GROUP_EFFECTS** — on the wire, decode planned (see §5.3). Up to 5 members × `{unique_no, act_index, u64 presence bits, [u8;32] status icon ids}`; no durations in the packet. |
| **Spell MP cost / ability TP cost** | ❌ not in `ffxi-vocab` (names/castTime/recast/statuses exist, no costs). Vendor SQL (`spells.sql` mpCost / `abilities.sql`) has them; add via the vendor-scrape build-time pattern. |
| Job icon textures | ❌ placeholder 3-letter codes in the L1 icon slot; `nameplate_icons` has only 9 nameplate glyphs, no job set. |

### Grouping rule

`SceneSnapshot.party` is a flat list; build the three windows per frame:

```
for m in snap.party:
    window = match m.party_no { 0 => A, 1 => B, 2 => C, _ => skip }
rows[window].push(m)   // then sort each window's rows by act_index (0..5)
```

- Party A renders when `rows[A].len() >= 1` and (`rows[A].len() > 1` or `show_when_solo`).
  **House choice: solo window always shown** (`show_when_solo` defaults true; the flag
  exists only to hide it in debug).
- B/C render only when non-empty; otherwise despawn/hide the window root.
- Alliance state (title tile + two-dot leader rendering) = any member with `party_no > 0`.

## 3. Geometry

All widths are template values × `BASE_MULT` (0.8) × per-window scale.

### L1 Compact Vertical (Party A)

```
L1 {
  hp_base_w: 150, mp_base_w: 100, tp_base_w: 100,   // pre-multiplier px
  base_mult: 0.8,
  bar_h: 20,                                          // both bars same height
  icon_size: 28,                                      // job icon square (px)
  bar_inset_px: 4,                                    // gap between icon right edge and bar left edge
  hp_w_mult: 0.82, mp_extra_w_mult: 0.9,              // HP/MP width trims (XIUI HX_BAR_WIDTH_MULT + MP extra)
  status_lift_px: 14,                                 // buff/debuff row lift above entry bottom
  sel_trim_h_px: 3,                                   // selection box bottom trim
}
```

Per-member entry (no name row — the name overlays the HP bar):

```
entry_height = hp_bar_h + 1 + mp_bar_h
bar_x        = entry_left + icon_size + bar_inset_px
hp_w         = hp_base_w * base_mult * hp_w_mult          // ≈ 98px at defaults
mp_w         = mp_base_w * base_mult * hp_w_mult * mp_extra_w_mult   // ≈ 74px
```

Row structure (top → bottom):
1. **Job icon** — `icon_size` square at entry left, vertically centered on the HP bar only. Drawn first; name text renders over it.
2. **HP bar** full row width from `bar_x`, height `bar_h`. Name overlays the bar's **top edge** (≈half glyph height above the bar top). Distance text right-aligned on the same line.
3. **MP bar** directly below HP (`+1px` gap), width `mp_w`, right-aligned with the HP bar's right edge (matches XIUI L1). Hidden for no-MP jobs unless `always_show_mp_bar`.

Window-level: top pad = `floor(name_font_h / 2) + 2`; window padding `{10, 6}`; odd
`mem_idx` rows get a subtle dark-red full-entry band behind everything.

### L2 Super Compact (Alliance B/C)

```
L2 {
  hp_base_w: 135, mp_base_w: 80, tp_bar_w: 0,        // TP is TEXT ONLY in this layout
  base_mult: 0.8,
  bar_h: 12,
  entry_w: 160,                                       // box width; wider than the bars
  name_bar_overlap_px: 3,                             // text row dips into HP bar top (XIUI SC_NAME_BAR_OVERLAP)
  mp_overlap_px: 2,                                   // MP bar shifted up under HP bar (XIUI LAYOUT_SUPERCOMPACT_OVERLAP)
}
```

Per-member entry:

```
name_row_h   = measured height of name font (measure "A")
hp_w         = hp_base_w * base_mult                  // ≈ 108px
mp_w         = mp_base_w * base_mult                  // ≈ 64px
entry_w      = max(entry_w * base_mult, hp_w)
bar_x        = entry_left + (entry_w - hp_w)          // bars RIGHT-aligned in the box
hp_y         = entry_top + name_row_h - name_bar_overlap_px
mp_y         = hp_y + hp_bar_h - mp_overlap_px        // HP bar visually covers MP's top sliver
entry_height = (name_row_h - name_bar_overlap_px) + hp_bar_h + mp_bar_h - mp_overlap_px
```

Row structure:
1. **Job icon** — entry top-left, vertically centered over the FULL entry height, drawn behind the text.
2. **Text row**: `[name LEFT]` at `entry_left + 4`, `[HP value RIGHT]` right-aligned to box edge; dips `name_bar_overlap_px` into the HP bar top.
3. **HP bar** full `hp_w` at `bar_x`; **MP bar** below, shifted up by `mp_overlap_px`.
4. TP renders as text only (`TP nnn`), right of the MP value or on its own mini-row.

Window-level: top pad = 2px; window padding `{3, 3}`.

## 4. Per-member elements (both layouts)

- **Bars**: outer `Node` with dark background + 1px border; inner fill `Node` at `width: pct%`.
  **HP color ramp** by `hp_pct` (mirrors XIUI custom HP colors): ≥70% green
  `{0.25, 0.8, 0.3}`, 40–69% yellow-green→yellow lerp, 20–39% orange, <20% red — one
  shared `hp_color(pct)` (unit-tested). MP solid blue `{0.3, 0.5, 0.9}`. TP (L1 only):
  gold when ≥1000 else dim gray. Value display fixed v1: **number** (`"843"`).
- **Name + job line**: name color from `nameplate_color.rs` party-aware table; job
  abbrev + level right after name in a dimmer shade (`"BLM 99"` / `"BLM/RDM"`).
  **Leader dot**: gold filled circle ~5px at row left; alliance leader = two dots side by side.
  **Activity flags** on name lines (single marker, retail priority): D/C > GM > Mtr > New
  > Away > LFP > Baz — from entity `CharFlags`, XIUI colors/labels.
- **Out-of-zone members** (`member.zone_no != self.zone_no`): bars replaced by a solid
  black block; text line becomes `"Name (ShortZone)"` using XIUI `shortenZoneName` rules
  (strip apostrophes; `"X of Y"` → `Y` no spaces; 2 words → first truncated to 2 chars +
  second; 3+ words → initials of all but last + last word). Zone display name from the
  minimap/zone-flash zone-name lookup.
- **Target highlight** (`Res<Target>.id == member`): selection box around the full entry
  + padding, 4-step vertical gradient (light→dark, blue-white tint) + 1px bright border,
  drawn as a background `Node`.
- **SubTarget highlight**: same box, gold-tinted gradient. Source: `InputMode::SubTarget`
  `candidate` while active, else the persistent `PartySubTarget` resource. Colors reserved:
  `SUBTARGET_BG/BORDER`.
- **Cast bar** (self): while `SelfCasting` is active the cast bar shows
  elapsed/duration (cyan fill); spell name left-aligned for MP jobs.
- **Click-to-target**: whole row clickable — click sets `Target.id = member entity id`
  (same path as `picking.rs`), via Bevy UI `Interaction::Hovered/Pressed` on the row root.
- **Buff/debuff icons on rows** (P1, not yet drawn): see §5.3.

## 5. Protocol / state plumbing

### 5.1 P0 — none

The first visible result used only §2 data.

### 5.2 P1

- **Self max HP/MP**: extract `hp_max`/`mp_max` from the existing s2c `0x063` handler into
  self's `PartyMember`. Do NOT derive max from `hp/hp_pct` — lossy at low HP
  (stopgap `max_from_pct` in use until then).
- **Distance readout**: no protocol; per-frame euclidean distance member→self, yalms 1
  decimal. Hide when out-of-zone.
- **`PartySubTarget` resource**: set where the SubTarget flow fires an action in
  `text_input/mod.rs`; cleared on new target / zone change.

### 5.3 P2 — s2c `0x076` GROUP_EFFECTS (member buffs/debuffs)

The packet is **already on the wire** (retail ships it; XiPackets documents it; the vendor
server sends it on party-effect change to same-zone members, `map/party.cpp`
`EffectsChanged`). Retail's own UI just doesn't draw member buffs — the data still flows.
**No server changes needed; we only decode what is already sent.** (Confirmed by user:
status icons ARE wanted — decision D3.)

Work (all client-side):
1. `ffxi-proto`: new `decode/group_effects.rs` — parse 0x076 into `Vec<GroupMemberEffects>`.
2. `kuluu-session`: route 0x076 into the snapshot pipeline; store as a map keyed by
   unique_no (each packet is full state per member → self-heals on resend). Clear on
   zone-in / party rebuild.
3. `kuluu-snapshot`: add `group_effects` to `SceneSnapshot` (+ delta path).
4. `party_frame.rs`: draw icons on L1/L2 rows by joining `PartyMember.id` against the map;
   reuse `status_ribbon`'s icon pipeline (`ffxi_dat::map_image::{status_icon_at,
   STATUS_ICON_FILE_ID}` + `StatusIconCache`) — no new asset work.

Known limits: no durations in the packet → icons without per-member timers for v1;
5 members max per packet, same-zone only; event-driven resends → state can go stale
between resends (acceptable, same as XIUI).

Related P2 items: per-entity cast state for member cast bars (s2c `0x08E` is received;
check whether kuluu-session tracks per-entity casts, add `cast: Option<{spell_id, start,
duration}>` from 0x08E/0x091); job/status icon textures (locate the retail DAT group, or
generated set — decision D4); sync marker (level-sync buff 233) needs the 0x076 decode.

### 5.4 Zone-in party flow (bug fixed 2026-09 — implemented in-tree)

**Symptom:** party frame showed stale/zero data after zoning until something changed
(HP tick, TP gain).

**LSB zone-in sequence:** `IncreaseZoneCounter` → `CharZoneIn` →
`PChar->ReloadPartyInc()` (dirty flag) → next `PostTick()`: `charutils::ReloadParty` →
DB query, rebuild `CParty` → pushes **`0x0C8` GROUP_TBL** (party definition: member IDs,
targids, party numbers, zones, leader flags) then **`0x0DD` GROUP_LIST** per member
(full stats + `ZoneNo = 0` for same-zone; only `ZoneNo` non-zero for other-zone). Solo
players get **no 0x0C8/0x0DD at all** — only `0x0DF` GROUP_ATTR for self, triggered by
the `0x061` CLISTATUS the client sends. Retail additionally sends **`0x076`
GROUP_LIST_REQ** during zone-in; LSB's handler calls `ReloadPartyMembers` → fresh
0x0C8 + 0x0DD burst.

**The three root causes:**
1. **Missing `0x0C8` GROUP_TBL handler.** 0x0C8 is the "party definition reset" / frame
   boundary for the 0x0DD burst — the retail client clears its party table on it before
   repopulating. Without it, kuluu could only upsert one member at a time and stale
   members from the previous zone were never removed.
2. **Missing `0x076` GROUP_LIST_REQ on zone-in.** Kuluu only sent `0x061` CLISTATUS,
   which is insufficient for partied players (timing window around `StageChanged {InZone}`).
3. **`PartyContentKey` swallowed the rebuild.** The render early-return key compares the
   party vec + zone_id + stage; when the 0x0DD/0x0DF landed in the same batch as the
   LOGIN packet, the key looked identical to the pre-zone key.

**Fix (all landed):**
- `ffxi-proto/src/map.rs`: `GROUP_TBL: u16 = 0x0C8`, `GROUP_LIST_REQ: u16 = 0x076`.
- `ffxi-proto/src/decode/party.rs`: GROUP_TBL decoder — Kind u8 (0 solo/none, 1 party,
  2 alliance) + up to 20 × 12-byte entries `{UniqueNo u32, ActIndex u16, flags byte
  (PartyNo[0:1], PartyLeaderFlg[2], AllianceLeaderFlg[3], …), ZoneNo u16, pads}`.
- `kuluu-session/src/state.rs`: `zone_generation: u64`, incremented on every
  `ZoneChanged` (~line 1557).
- `kuluu-session/src/session/mod.rs`: handle `s2c::GROUP_TBL` (clear + pre-populate the
  party list so 0x0DD upserts start fresh); send `0x076` GROUP_LIST_REQ during zone-in
  after the `0x061` CLISTATUS (~line 514).
- `kuluu-session/src/session/codec.rs`: `build_subpacket_group_list_req(sync)` — Kind=0
  (the only value LSB's validator accepts), 8-byte body.
- `kuluu-render/src/hud/party_frame.rs`: `zone_generation` added to `PartyContentKey`
  (~line 759) — forces a rebuild after every zone change even when the party data is
  byte-identical.

## 6. Window-level spec

- **Party A**: title row = solo tile when solo, party tile otherwise (tile source pending
  the icon-texture work; text `"PARTY"`/`"SOLO"` small caps until then). Flanking labels
  on Party A only: gold `"Treas."` left when the treasure pool is non-empty; cyan
  `"Trade"`/`"Invite"` stacked right when `rows[A].len() > 1` (labels drawn statically;
  wiring actions later — no pending trade/invite state tracked yet).
- **B/C**: title = `"PARTY B"` / `"PARTY C"` (text interim). No flanking labels. Hidden
  when empty.
- Panel chrome: dark panel background `{0, 0.06, 0.16, 0.9}`, rounding 4px, silver 1px
  highlight lines on top/bottom edges (XIUI plain theme; reuse `hud/style.rs` where it
  matches).
- Row visibility: **Dynamic** — live members only, plus `min_rows` (default 1) dimmed
  empty placeholder rows so the window doesn't collapse. No expand-to-6 mode in v1.

## 7. Debug panel

"UI Settings" panel in the debug overlay (pattern: `hud/graphics_debug.rs` /
`diagnostics.rs`): 13 click-cycle settings incl. **per-window layout override** (A/B/C
each ∈ {L1, L2}; default A=L1, B=C=L2 — the only layout switching that exists anywhere)
and per-window scale. Writes to `PartyFrameSettings` live; no persistence.

Full spec control list (for when sliders replace click-cycle): all §3 constants
(bar widths/heights, base_mult, icon size, insets, overlaps, entry width, font sizes,
window padding, top pads); toggles `show_when_solo`, `always_show_mp_bar`, `show_tp`,
`show_distance`, `show_job_icon`, `alternating_bands`, `selection_box`, `min_rows` (0–6),
HP display mode (number/percent/current_max), name color source (retail table / white);
readout of row counts per window, self zone_no, target id, subtarget state.

## 8. What works today (v1, committed; verified 2026-09-13)

- Party A = L1 compact vertical; Alliance B/C = L2 super compact. Self is row 0 of A.
- HP/MP bars (XIUI width multipliers), TP text, retail name colors (`ncol::PC` self /
  `ncol::PARTY` others).
- Leader dots (party=1, alliance=2), out-of-zone black block + XIUI shortened zone name.
- Distance-to-target on the A title row (right side) — debug-toggleable; per-member
  distance on L1 name lines — debug-toggleable.
- Click a member row → sets `Res<Target>` (click-to-target).
- Activity flags on name lines (retail priority, from `CharFlags`).
- "Treas." gold flag left of the Party A title while the treasure pool holds items.
- min_rows placeholder slots, alternating bands, target selection box.
- Debug menu "UI Settings" panel (13 click-cycle settings).
- Solo window always shown (house choice, §3).
- Zone-in staleness fixed (§5.4): 0x0C8 decode + 0x076 zone-in request +
  `zone_generation` content-key field all in-tree.

## 9. Review findings (v0 diagnostic — historical, most gaps since closed)

Verdict at review time: **the data plumbing was right, the geometry was not** (v0 drew a
third "text-left / bars-right" layout that exists in neither L1 nor L2). v1 closed the
geometry gap (§8). Still-relevant findings:

- **Row rebuild strategy**: clear-and-respawn every dirty frame (spec's diff-and-reuse
  deferred). Fine while gated on `state.dirty`, but any per-frame-varying content
  (distance, cast progress, subtarget cursor) forces full-row respawns → text
  re-rasterization churn. **Switch to diff-and-reuse (row entities keyed by `mem_idx`)
  before per-frame-varying content lands.**
- **Stale-highlight gate (was a bug)**: the update system early-returned on
  `!state.dirty`, but target changes live in `Res<Target>` — highlight only updated on
  the next GROUP_ATTR. Gate must be `!state.dirty && !target.is_changed()`.
- **Target bar gap** (XIUI `DrawCurrentTarget`): XIUI's target bar is anchored directly
  above Party 1, width matched to the party panel exactly, inherits its font/scale;
  shows the *sub-target cursor selection* while sub-targeting and snaps back when the
  flow ends; decodes retail name-flag icons (party/away/sync) next to the name; smooths
  HP on damage ticks. Kuluu's `hud/target_panel.rs` is a fixed-width column entry —
  extras not in XIUI (engaged badge + swing pulse) are kept as house features.
- **Spell cost does not exist** (zero "cost" hits across HUD/view_native/ffxi-vocab):
  XIUI's `castcost/` window shows selected spell/ability name + MP/TP cost +
  recast/cooldown while the menu has a row highlighted. Inputs: active menu type +
  selected row (available — expose `hud/menu.rs` selection as a resource), self MP/TP
  (have), ability recast group ids (have — `ffxi-vocab::recast`), **MP/TP cost (MISSING
  — vendor-scrape from `spells.sql`/`abilities.sql`)**. No protocol work.

## 10. Open items (priority order)

| # | Item | Notes |
|---|---|---|
| P0 | **Target bar** (XIUI `DrawCurrentTarget`) | Anchor above Party A in the ROSTER column, fixed position, ON by default when a target exists. Fields (decision D1): name + HP bar + distance + subtarget. Work: add `sub_id: Option<u32>` to `Res<Target>`; wire subtarget from the world-picking path. |
| P0 | **Cast cost readout** (+ cast bar on by default) | Decision D2: make `enhanced-cast-bar` a default feature (client-HUD rule); cost text beside the cast bar **and** on the Party A title row while casting. Needs the new ffxi-vocab cost table. |
| P1 | **Member status icons** | The 0x076 decode of §5.3 (D3 confirmed). |
| P1 | **Job icon textures** | D4: locate the retail DAT job-icon group; keep 3-letter codes as fallback. |
| P2 | Self max HP/MP from s2c `0x063` | Replace `max_from_pct` stopgap. |
| P2 | Per-member cast bars | Action-packet correlation (0x08E/0x091). |
| P2 | Row rebuild → diff-and-reuse | Before per-frame-varying content lands. |
| P2 | "Trade"/"Invite" labels wired to live state | No pending-request data source tracked yet. |
| Parked | L2 TP text-only (XIUI shows a small TP bar in some layouts) | Cosmetic. |
| Parked | `in_mog_house` "Mog" suffix on name line | D5: yes, cheap — not yet done. |
| Parked | Nameplate MSAA/TAA defects in `nameplate_final_pass.rs` | Separate workstream. |

## 11. Verification

- `cargo build -p kuluu --release` clean, no new warnings in touched crates.
- Launch via `play_cowland.bat`; confirm: solo (window shown with Solo title), party of
  2+ (L1 rows, self row 0), alliance (B/C L2 windows appear/disappear as members
  join/leave zones), out-of-zone member renders black block + short zone name, clicking a
  row targets that member, target/subtarget boxes track `Target` and the subtarget flow,
  party frame is fresh immediately after every zone-in (§5.4).
- No frame-time regression beyond one extra UI update system; verify with the perf HUD
  (`perf_probe.rs`) — expect <1ms at 18 members.

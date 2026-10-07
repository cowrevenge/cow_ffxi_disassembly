# Battle engage flow & combat wire mechanics — retail spec snapshot

> Durable game-system knowledge extracted from the retired `wip_battle.md` (2026-10-08 folder triage).
> The original was a work-stream ledger (client-state snapshots verified 2026-09-15, bug histories,
> design-on-paper, work lists) — all of that agent scaffolding and stale kuluu state is dropped.
> What remains: the retail `/attack` spec (Shane's live observation), the LSB engage-gate table
(the wire contract the client must handle), the complete MsgBasic mechanic scrape, the sub-target
model, and open retail questions. Code locations cited inside are LSB (`vendor/server`), not kuluu.
## 2. Retail spec — `/attack` (per Shane, 2026-09-15)

`/attack` (or Attack via the menu) on a mob:

- **Checks** (all must pass):
  - mob is close enough — **long/engage range**, which is *different from and
    larger than* the swing (melee) range
  - mob is **not claimed by another player/team** (our party/alliance is fine)
  - our **attack delay (GCD) is ready** (enough time since last swing)
- **settarget** the mob
- **target is maintained and locked** — **locked on at start**; the player can
  toggle the lock off (H)
- **`/attack` is cancelled (disengage) when**:
  - the mob moves out of long range
  - another player/team claims the mob
- **Chat must show a message** (main chat log) when:
  - the target **cannot be seen** — the facing case: happens when you are *not*
    locked and you turn around
  - **too far away** to swing — you are close enough to `/attack` (engage range)
    but not close enough to swing (melee range)
## 3. What the server actually does (LSB, verified in-tree)

Engage entry: c2s 0x01A action `Attack` → `CPlayerController::Engage`
(`vendor/server/src/map/ai/controllers/player_controller.cpp:68`):

| Check | Where | MsgBasic id | Client text |
|---|---|---|---|
| engage range `< 30` | `player_controller.cpp:68` | 78 `TooFarAway` | `<target> is too far away.` |
| GCD (`lastAttack + weaponDelay < now`) | `player_controller.cpp:90` | 94 `WaitLonger` | `You must wait longer to perform that action.` |
| claim (`!IsMobOwner`) | `charentity.cpp:1321` `CanAttack` | 12 `AlreadyClaimed` | `Cannot attack. Your target is already claimed.` **+ auto-Disengage** |
| long range `> 30` per swing | `charentity.cpp:1341` | 36 `LoseSight` | `You lose sight of <target>.` **+ disengage** |
| facing cone (64 units) | `charentity.cpp:1347` | 5 `UnableToSeeTarget` | `Unable to see <target>.` |
| melee range per swing | `charentity.cpp:1352` | 4 `TargetOutOfRange` | `<target> is out of range.` |

- `IsMobOwner` (`charentity.cpp:2340`): unclaimed, self, or owner in
  party/alliance — exactly the retail claim rule.
- All of the above are sent as **s2c 0x029 `GP_SERV_COMMAND_BATTLE_MESSAGE`**
  with `MessageNum` = the MsgBasic id (packet:
  `vendor/server/src/map/packets/s2c/0x029_battle_message.h`; enum + client
  texts: `vendor/server/src/map/enums/msg_basic.h`).
- On successful engage the server pushes `GP_SERV_COMMAND_ASSIST` (0x058,
  moves the target cursor) and sets the entity's animation byte to
  `ANIMATION_ATTACK` (0x0E) via `CBattleEntity::OnEngage`
  (`battleentity.cpp:3329`), broadcast in the General block.
- While engaged the **server auto-swings** on the GCD
  (`CAttackState::Update` → `AttackReady` → `CanAttack` → `OnAttack`,
  `attack_state.cpp`); the client's single attack command starts it.
- The server does **not** auto-walk the PC toward the target (mobs path to
  their target; PCs don't).

## 3.5 The complete MsgBasic mechanic table (the scrape)

Source of truth: `vendor/server/src/map/enums/msg_basic.h` (~243 entries),
scraped at build time into `ffxi-vocab::msg_basic`
(`ffxi-vocab/build.rs` `parse_msg_basic`, floor-pinned at 243 rows). Every
0x029/0x02D message is one of these ids. This is the **complete** set of
things the server can tell us about combat — record it all here, not just the
ones currently needed.

**A. Engage / attack targeting (the §2 mechanics):**

| id | Name | Text |
|---|---|---|
| 4 | TargetOutOfRange | `<target> is out of range.` |
| 5 | UnableToSeeTarget | `Unable to see <target>.` |
| 12 | AlreadyClaimed | `Cannot attack. Your target is already claimed.` |
| 36 | LoseSight | `You lose sight of <target>.` |
| 78 | TooFarAway | `<target> is too far away.` |
| 94 | WaitLonger | `You must wait longer to perform that action.` |
| 217 | CannotSee | `You cannot see <target>.` |
| 218 | MoveAndInterrupt | `You move and interrupt your aim.` |
| 446 | CannotAttackTarget | `You cannot attack that target` |

**B. Action rejections (server says why the attempted action failed):**

| id | Name | Text |
|---|---|---|
| 16 | IsInterrupted | `The <player>'s casting is interrupted.` |
| 18 | UnableToCast | `Unable to cast spells at this time.` |
| 22 | CannotCallForHelp | `You cannot call for help at this time.` |
| 34 | NotEnoughMP | `The <player> does not have enough MP to cast (nullptr).` |
| 35 | NoNinjaTools | `The <player> lacks the ninja tools to cast (nullptr).` |
| 39 | NeedDualWield | `You need the Dual Wield ability to equip <name of item> as a sub-weapon` |
| 40 | CannotInThisArea | `cannot use in this area` |
| 47 | CannotCastSpell | `<player> cannot cast <spell>.` |
| 49 | UnableToCastSpells | `The <player> is unable to cast spells.` |
| 56 | UnableToUseItem | `Unable to use item.` |
| 62 | ItemFailsToActivate | `The <item> fails to activate.` |
| 71 | CannotPerformAction | `You cannot perform that action on the specified target.` |
| 76 | NoTargetInAreaOfEffect | `No valid target within area of effect.` |
| 87 / 88 | UnableToUseJobAbility(2) | `Unable to use job ability.` |
| 89 | UnableToUseWeaponskill | `Unable to use weaponskill.` |
| 92 | CannotUseItemOn | `Cannot use the <item> on <target>.` |
| 155 | CannotOnThatTarget | `You cannot perform that action on the specified target.` |
| 190 | CannotUseWeaponskill | `The <player> cannot use that weapon ability.` |
| 191 | CannotUseAnyWeaponskill | `The <player> is unable to use weapon skills.` |
| 192 | NotEnoughTP | `The <player> does not have enough TP.` |
| 199 | RequiresShield | `That action requires a shield.` |
| 210 | CannotCharm | `The <player> cannot charm <target>!` |
| 215 | RequiresAPet | `That action requires a pet.` |
| 216 | NoRangedWeapon | `You do not have an appropriate ranged weapon equipped.` |
| 235 | ThatSomeonesPet | `That is someone's pet.` |
| 307 | Needs2HWeapon | `That action requires a two-handed weapon.` |
| 313 | OutOfRangeUnableCast | `Out of range unable to cast` |
| 315 | AlreadyHasAPet | `The <player> already has a pet.` |
| 316 | CannotUseInArea | `That action cannot be used in this area.` |
| 328 | TooFarAwayRed | `<target> is too far away. (but in the red color)` |
| 337 | NoJugPetItem | `You do not have the necessary item equipped to call a beast.` |
| 339 | YourMountRefuses | `Your mount senses a hostile presence and refuses to come to your side.` |
| 347 | MustHaveFood | `You must have pet food equipped to use that command.` |
| 356 | FullInventory | `Cannot execute command. Your inventory is full.` |
| 428 | NoEligibleRoll | `There are no rolls eligible for Double-Up. Unable to use ability.` |
| 429 | RollAlreadyActive | `The same roll is already active on the <player>.` |
| 445 | CannotUseItems | `You cannot use items at this time.` |
| 512 | Requires2HForGrip | `You must have a two-handed weapon equipped to equip a grip.` |
| 574 | PetCannotDoAction | `<player>'s pet is currently unable to perform that action.` |
| 575 | PetNotEnoughTP | `<player>'s pet does not have enough TP to perform that action.` |
| 660 | SameEffectLuopan | `The same effect is already active on that luopan!` |
| 661 | LuopanAlreadyPlaced | `<player> has already placed a luopan. Unable to use ability.` |
| 662 | RequireLuopan | `This action requires a luopan.` |
| 665 | HasLuopanNoUse | `<player> has a pet. Unable to use ability.` |
| 666 | RequireRune | `That action requires the ability Rune Enchantment.` |
| 700 | TrustNoCastTrust | `You are unable to use Trust magic at this time.` |
| 717 | TrustNoCallAlterEgos | `You cannot call forth alter egos here.` |
| 742 | ROEUnable | `You are currently unable to undertake this objective.` |
| 745 | AutoExceedsCapacity | `Your automaton exceeds one or more elemental capacity values and cannot be activated.` |
| 773 | MountRequiredLevel | `You are unable to call forth your mount because your main job level is not at least <level>.` |

**C. Combat results (per-swing/per-cast outcomes — the spam class):**
1 AttackHits, 2 MagicDamage, 3 StartsCastingSelf, 14 CounterAbsByShadow,
15 AttackMisses, 30 TargetAnticipates, 31 ShadowAbsorb, 32 TargetDodges,
33 AttackCounteredDamage, 44 SpikesEffectDmg, 67 AttackCrit, 70 TargetParries,
75 MagicNoEffect, 77 UsesSangeTakesDamage, 84 IsParalyzed2, 85 MagicResisted,
93 MagicTeleport, 100–103 uses-JA/cast lines, 110 UsesAbilityTakesDamage,
131/134/148–151 fortified lines, 132 SpikesEffectHPDrain, 157
UsesBarrageTakesDamage, 158 AbilityMisses, 161–163 AddEffect*, 185–189
UsesSkill*, 197 UsesAbilityResistsDamage, 224–227 skill/magic drains,
229/384 AddEffect*, 230/236/237/242/243 status-on-target lines, 252
MagicBurstDamage, 264 TargetTakesDamage, 266/267/276/277/278/281/282/283/
284/286/287 target result lines, 306/318 item AoE heals, 319/320/323
ability-result lines, 324 UsesButMisses, 352–355 ranged results, 362/363/
366/370 TP/MP drains, 373/374/382/383 spikes, 404 TargetEffectDrained,
420–427 Corsair rolls, 430 MagicSteal, 435–441 recharge lines, 535/536
retaliate, 576/577 ranged flavor, 592 PerfectCounterMiss, 606
CounterAbsorbedDmg, 663–672 luopan/swordplay/vallation lines.

**D. State / progress (one-shot events, not rejections):**
6 DefeatsTarget, 8 ExperiencePointsGained, 9 LevelUp, 11 LevelDown,
19 CallForHelp, 20 FallsToGround, 23 LearnsNewSpell, 24/263/367/587 target
recovers HP, 28 ItemUse, 29 IsParalyzed, 37 TooFarForExp, 38 SkillGain,
43 ReadiesWeaponskill, 45 LearnsAbility, 50 MeritPointGained, 53
SkillLevelUp, 97 PlayerDefeatedBy, 106 IsIntimidated, 136/137
CharmSuccess/Fail, 202 TimeLeft, 203 IsStatus, 232 DrawnIn, 253 ExpChain,
256–258 gardening, 273 TargetTeleport, 310 SkillDrop, 343
TargetEffectDisappears, 371/372 limit, 380/381 merit rise/fall, 419
LearnsSpell, 442 LearnsNewAbility, 540/545 level sync, 565 Obtains (gil),
603 TreasureHunterUp, 697/698/704/705 ROE, 711 TrustPartyMessage,
718/719/720/735 capacity/job points, 828 AlterEgoUpgrade.

**E. Never-printed / debug / no-text (dropped by the scrape or by design):**
0 None ("display nothing"), 66/79/80/255 Debug*, 174 CheckDefault ("does not
print"), 524 NoFinishingMoves / 568? / 697? / 704 / 712–715 / 731 / 733
(no client text — the scraper drops empty-comment entries; 712–715/731/733
are synthesized locally by `synth_check_line` instead).

**F. Known decode gaps (documented in `kuluu-session/src/session/mod.rs`):**
id 116 has no enumerator at all (generic "uses \<ability\>" line) — pinned by
`TEMPLATE_OVERRIDES`; ids 100/101/14/31/136/137/317/324/565 shadow the scrape
because the LSB comments elide tokens as bare ".."; ids 420–427 (Corsair
rolls) are deliberately unhandled (need two numbers + a status the wire
fields can't supply).
## 6. Sub-target model (retail, per Shane 2026-09-15)

- **Target and sub-target always "exist"** as slots — the sub-target is not a
  transient selection mode; it is a second slot that **gets drawn instead of
  the target in the target frame while a menu has it open** (display swap).
- **"Switch target" opens the sub-target menu.**
- **Spells/abilities use the sub if there is already one** (some are
  sub-self, e.g. self-cast).

Current code (§4.4) matches this model: the picker is a modal `InputMode`
with `return_to`, "Switch Target" confirm retargets the main slot (via
re-engage), the display swap is wired, and both fire paths use the sub when
present.
## 7. Open questions (need retail confirmation)

1. **Engage lock scope**: *Answered (Shane, 2026-09-15):* engage pins the
   main target beyond the camera lock — H releases the camera only, and the
   pin holds until /disengage. Only the sub-target flow (Switch Target,
   action menus) reaches through (`suppresses_retarget(engaged, lock,
   sub_target_flow)`).
2. **Engage camera**: does retail flip the chase camera to a strafe/hold mode
   on engage (xim has "default strafing when engaged"; retail unconfirmed)?
3. **Main log contents**: does retail's main chat log also show hit/miss/cast
   combat lines (§3.5-C) *and* the state events (§3.5-D: defeat, level up,
   XP, status)? Today *all* of those sit on the hidden Battle tab. Decides
   whether item 1's rejection-only routing is the end state or a first step.
4. **Switch target confirm**: *Answered (Shane, 2026-09-15):* confirming
   promotes the main target — Switch Target is the sanctioned mid-fight
   retarget; it re-engages on the chosen mob (server moves the battle target,
   echoes 0x058, `apply_server_retarget_system` lands it in the main slot,
   `engage_locks_target_system` moves the camera lock).
5. **Sub persistence**: does the sub survive the menu closing (slots "always
   exist"), or clear on Esc?
6. **Weapon draw sub-type**: retail's draw routine is
   `"in <weaponAnimationSubType>"` (xim `Actor.kt:832`); we hardcode
   `in 0`/`out0`. Is the sub ever non-zero in retail, and for which weapons?
7. **Rejection spam**: does the server re-send the rejection message every
   swing tick while the condition persists (facing kept away / out of range)?
   If so, does retail debounce the display?
8. **Target head-look**: retail turns the character's *head* (not body) toward
   the target on target-switch, with hard angle limits (the head can't snap
   past ~90°/backwards). **This is already implemented in-tree** —
   `desired_head_rot` (ffxi_actor_render.rs:2851) turns only the neck subtree,
   gated by a view cone (`HEAD_VIEW_CONE_COS = -0.30`, ≈107° from forward),
   clamped to a max turn (`HEAD_MAX_TURN_RAD = 1.20`, ≈69°), and slewed
   smoothly (`HEAD_SLEW_TAU_FRAMES = 6.0`, framerate-independent slerp). It is
   driven by the wire `face_target: u16` (targid, kuluu-snapshot lib.rs:395),
   resolved via `index.id_by_targid` (ffxi_actor_render.rs:4016); self uses
   `self_target_id`. Open: do the cone/max-turn numbers match retail's
   observed head, and does the server set `face_target` to the right target
   (main vs engaged) on target-switch?
9. **`/autoattack` server-side flag**: retail's auto-attack is a server flag —
   c2s 0x0DC config `AutoTargetOffFlg` (`/autotarget`), read by the server's
   own after-kill scan (attack_state.cpp `CAttackState::UpdateTarget`: an
   attacking mob inside a 64° facing cone and 10 yards, first in spawn
   order). Our `/autoattack` toggle is client-side only (no 0x0DC in the
   protocol stack yet), so the server's scan still runs when the toggle is
   off: it fires first when its cone/range criteria match (the 0x058 lands
   the target and the client's transition check sees the slot filled and
   skips), and it is a fallback when the client is slow. If `/autoattack off`
   must fully stop auto-retargeting, the 0x0DC bit has to be mirrored to the
   server (note: the LSB handler only applies the bit when the received flag
   is 1 — it cannot clear the flag back on).

--[[---------------------------------------------------------------------------
BovineMage.lua

Behavior (when Running)
  Priority order:
    1. Emergency cure  (HP <= 50% -- always fires, stands us from rest)
    2. Manual buttons  (Dispel / Sleep / Bind -- explicit user intent
                        beats heuristic actions below)
    3. Normal cure     (HP < 70%, standing-only, toggleable)
    4. Auto-dispel     (Evasion Boost / Defense Boost on claimed mob)
    5. Paralyna        (p0->p5 scan)
    6. Silena          (p0->p5 scan)
    7. Poisona         (p0->p5 scan)
    8. Debuffs         (Dia / Paralyze / Slow on claimed mob)
    9. Refresh         (self + extras; stands at 80%+ MP)
   10. Haste           (named targets; stands at 80%+ MP)
   11. Regen           (named targets; stands at 80%+ MP)
   12. Reraise         (self only; stands at 90%+ MP)
   13. Rest / idle

  Rationale for the ordering: only HP cures override debuffs. Refresh,
  Haste, Regen and Reraise are convenience buffs and will not steal a
  cast slot from Dia/Paralyze/Slow when we stood up specifically to
  debuff. They stand to cast when we have spare MP (80%+ for the three
  party buffs, 90%+ for Reraise's longer cast / higher cost), unless
  Auto Full Rest is engaged -- in which case the rest finishes first.
  Force Rest blocks all of them; only emergency cure can override
  Force Rest. Manual buttons sit just below emergency cure because the
  user pressing a button is a stronger intent signal than any of the
  heuristic-driven cascades -- if they hit Dispel, they want Dispel
  now, not after a normal cure tops off some 65%-HP ally.

  - Emergency cure:
        * any ally in range at <= 50% HP triggers emergency
        * two-tier stand gate when resting:
            - HP <= 10% (critical): stand if MP >= 8  (Cure I cost)
            - 10% < HP <= 50%:      stand if MP >= 24 (Cure II cost)
          staying resting when we can't afford at least a Cure II in the
          non-critical band is deliberate; a Cure I there wastes the rest
          window. If HP then drops below 10% the 8-MP floor kicks in.
        * once standing, cascade from best to worst (cast whatever we can
          afford), with a tier gate: at RDM 55+ / WHM 41+ / PLD 55+,
          Cure IV is held back when HP is in the upper half of the
          emergency band (above threshold/2 -- 25% with toggle 50, 17.5%
          with toggle 35). It's a hate machine and a big MP burn; below
          the half-band we let it fire because the ally needs it.
  - Refresh:
        * targets: self first, then up to 6 extras (configured via the
          Refresh section's per-member checkboxes in the GUI)
        * recast trigger uses two independent guards together: a time
          guard (refresh_timers[name] = cast_completion + 180s) and a
          buff-visibility guard inside Tgt.next_refresh_target. Both must
          agree before the cast fires. The time guard alone would try
          to recast right at the 180s mark, but FFXI rejects same-tier
          overwrites with "No effect" if the buff is briefly still
          present -- the visibility guard holds the cast until the
          server actually clears the buff, at which point the recast
          goes out immediately.
        * no per-tick keep-alive on the Refresh timer, so the GUI
          countdown reads honestly: starts at 180s right after a cast
          confirms, counts down to 0/"due" at the FFXI buff drop, and
          the recast fires on the next tick. Haste and Regen use the
          same model.
        * stands from rest at MP >= 80%, unless Auto Full Rest is
          actively blocking (resting >= 30s at 80%+ MP with that
          toggle on -- in that case let the rest finish to full).
          Force Rest still blocks unconditionally.
  - Normal cure:
        * never stands us from rest -- only casts while already standing
        * to disable entirely, uncheck the master "Cure" box in the GUI
        * spell chosen by missing HP (>= 200 missing -> Cure III, else Cure II)
  - Per-member cure configuration:
        * GUI shows a vertical per-member list with two checkbox
          columns under the master Cure toggle:
            - "Cure"      column: who is eligible for normal cures
            - "Emg. Cure" column: who is eligible for emergency cures
        * Default: every party member checked in both columns.
        * Uncheck "Cure" for a member -> they only get emergency cures.
          Use case: BRD with Minstrel-style gear that breaks on heals.
        * Uncheck "Emg. Cure" for a member -> they don't get auto-
          emergency cures. Use case: tank with strong self-heal who
          wants hate control.
        * Uncheck both -> the addon won't cure that member at all.
        * Self appears in the list (marked with a trailing "*"); same
          rules apply -- this replaces the older "cure self" toggle.
  - Paralyna:
        * scans p0->p5 in order each tick
        * casts on first party member found with Paralysis debuff
        * stands if resting (MP >= 50%) to cast
  - Silena:
        * scans p0->p5 in order each tick
        * casts on first party member found with Silence debuff
        * stands if resting (MP >= 50%) to cast
  - Poisona:
        * scans p0->p5 in order each tick
        * casts on first party member found with Poison debuff
        * stands if resting (MP >= 50%) to cast
  - Haste:
        * up to 6 named targets in order
        * recast trigger uses two independent guards together: a time
          guard (haste_timers[name] = cast_completion + 180s) and a
          buff-visibility guard inside Tgt.next_haste_target. Both must
          agree before the cast fires. No per-tick keep-alive on the
          timer, so the GUI countdown reads honestly from ~180s down
          to 0/"due"; the visibility guard holds the cast at "due"
          for the brief window between time-expiry and the FFXI server
          actually clearing the status.
        * stands from rest at MP >= 80%, unless Auto Full Rest is
          actively blocking. Force Rest blocks unconditionally.
  - Regen:
        * up to 6 named targets in order
        * same time-guard + visibility-guard model as Haste -- honest
          countdown to 0/"due", cast fires the moment the FFXI buff
          actually clears.
        * stands from rest at MP >= 80%, unless Auto Full Rest is
          actively blocking. Force Rest blocks unconditionally.
  - Reraise:
        * self only; cast at MP >= 90% when the player doesn't have
          the Reraise buff. Stands from rest if needed, unless Auto
          Full Rest is actively blocking. Force Rest blocks
          unconditionally.
        * recast attempt cooldown: 60s addon-side throttle, only
          relevant if the buff id is wrong on a private server (status
          113 in retail) -- normally the buff lasts an hour and we
          won't re-attempt.
  - Debuffing:
        * only stand to debuff when active claimed mob is within 18 yalms
        * do not stand just to debuff if MP% is below 50
        * first round of debuffs only fires when mob HP is 60-96%:
            - above 96% -> wait (mob not engaged yet, avoids wrong target)
            - below 60% -> abandon remaining debuffs for that mob
        * Dia reapply (when enabled) ignores the 96% ceiling and uses
          a separate 30% floor (CFG.DEBUFF_REAPPLY_MIN_MOBHP) instead of
          the 60% one used for first-round debuffs. The DoT keeps
          ticking damage at any HP and the spell only costs 7-12 MP,
          so the reapply cycle is worth running much further into the
          fight than Slow / Paralyze first-rounds would be.
        * if already standing, debuffs are allowed normally (subject to HP gates)
  - Standing lock:
        * once stood up, stay standing at least 3 seconds before resting again
        * any cast attempt refreshes this standing lock, even if not confirmed
  - Spell pacing:
        * each spell has its own cast-time lock so Slow / Paralyze do not fire too fast
  - Auto-stop:
        * stops immediately if player is detected dead
  - Manual buttons:
        * Dispel -> tracked mob by server id (stands if resting, silent if CD/no MP)
        * Sleep  -> <t>   (stands if resting, silent if CD/no MP)
        * Bind   -> <t>   (stands if resting, silent if CD/no MP)

Targeting
  - Cures use party member names
  - Paralyna targets first paralyzed party member p0->p5
  - Silena targets first silenced party member p0->p5
  - Poisona targets first poisoned party member p0->p5
  - Refresh targets self + one configured extra name only
  - EVERY mob-facing cast (Dia/Bio, Paralyze, Slow, Blind, Dispel,
    Silence, BLM skillup) targets a specific mob by SERVER ID. The cast
    goes out as the same outgoing 0x01A action packet the client sends
    for a normal /ma, with the target's server id + entity index carried
    in the payload. Nothing client-side is touched: no retargeting, no
    cursor movement, no <t>, no <bt>. <bt> is not used for any cast --
    it could silently resolve to a different nearby mob, which is what
    forced the old "skip Dia when 2+ mobs are claimed" workarounds.
    Action packets are hard-limited to 1/sec (ACTION_PACKET_MIN_INTERVAL).
  - Sleep / Bind deliberately still use <t> = whatever YOU have
    targeted, sent as a normal /ma command. The bot never moves your
    cursor, so these remain purely yours.
  - Claimed mobs are only used for mob existence / range / alive / lock tracking

Buff detection
  - Self buffs      -> GetPlayer():GetBuffs()       (Player manager)
  - Party buffs     -> party:GetMemberBuff(slot,i)  (Party manager)
  - Mob debuffs     -> action / message packets     (packet-tracked)

Safety
  - ONLY /ma, /heal, /heal disable true|false, /addon unload bovinemage,
    and /lac fwd healermode on|off may be sent
  - ALL addon text output uses /echo
---------------------------------------------------------------------------]]--

addon.name    = 'bovinemage'
addon.author  = 'ShadowCow'
addon.version = '2.9.0'
addon.desc    = 'Support healer: emergency cure, paralyna, silena, poisona, refresh, debuff active claimed mob, rest otherwise'

package.path = package.path
    .. ';' .. addon.path .. '?.lua'
    .. ';' .. addon.path .. 'libs/?.lua'

require('common')
require('helpers')

local imgui = require('imgui')
local bit   = require('bit')

-- Party buff detection: same module your working addons use.
-- It maintains a server-id → buff-ids cache, fed by packet 0x076
-- and by direct memory reads of the party.statusicons pointer.
StatusHandler = require('statushandler')
if StatusHandler and type(StatusHandler.refreshFromMemory) == 'function' then
    StatusHandler.refreshFromMemory()
end

-- Mob buff detection: the same module the enemylist addon uses to draw
-- the status-icon strip above each mob. We read it for Auto-Dispel so
-- the source of truth is the server's actual buff state -- our local
-- mob_debuffs tracker (further down) doesn't recognise the "is
-- dispelled" message id, so it can't tell when our own Dispel has
-- already stripped a buff and would otherwise spam re-casts on the
-- spell cooldown. debuffhandler updates correctly, so reading it each
-- tick gives us "buff currently present on the mob" with no special
-- per-spell handling needed.
local debuffHandler = require('debuffhandler')

---------------------------------------------------------------------
-- ADDON METADATA
---------------------------------------------------------------------

---------------------------------------------------------------------
-- CONSTANTS
---------------------------------------------------------------------

-- NAMESPACE_BUNDLES_START
-- Namespace tables to keep tick() and other large functions under
-- Lua 5.1's 60-upvalue ceiling. Each member is forward-declared
-- here and assigned at the original definition site below; call
-- sites use the namespaced form. Saves one upvalue per bundled item
-- in every function that referenced multiple of them.
local CFG = {}  -- thresholds, ranges, dispel/buff constants
local P   = {}  -- player_* state helpers
local Tgt = {}  -- next_*_target selectors
local Mob = {}  -- claim / mob-state helpers
-- NAMESPACE_BUNDLES_END

local REST_CMD                 = '/heal'
local EMERGENCY_CURE_THRESHOLD = 50
CFG.CRITICAL_CURE_THRESHOLD  = 10
CFG.NORMAL_CURE_THRESHOLD    = 70
-- DRG Healer mode: a SEPARATE parallel cure trigger for DRG parties.
-- Does NOT touch the emergency cure system or its 35/50 toggle. Uses
-- its own hardcoded threshold (CFG.DRG_HEALER_THRESHOLD = 50%) and only
-- fires when nobody is already in the emergency band. Triggers:
--   * 2+ members at/below 50%: cure the one with the highest HP%
--     immediately (wyvern handles the lower-HP one).
--   * 1 member at/below 50% for S.drg_sustain_sec seconds: cure them.
--     Lets the wyvern's Healing Breath react first on single-hit dips.
--     The wait time is GUI-adjustable via a slider next to the toggle.
CFG.DRG_HEALER_THRESHOLD     = 50
-- Critical HP fast-path for DRG Healer Mode: anyone in the low band
-- at/below this HP% gets an IMMEDIATE cure with no sustain-timer
-- wait, and takes priority over the 2+ "highest-HP wins" rule. The
-- wyvern's Healing Breath has too long a cooldown / too small a heal
-- to be the primary response when someone is one hit from dying;
-- the mage steps in directly. Only applies in DRG Healer Mode --
-- non-DRG emergency band uses S.emergency_cure_threshold as before.
CFG.DRG_HEALER_CRITICAL_THRESHOLD = 20
local DRG_SUSTAIN_DEFAULT      = 4.0
local DRG_SUSTAIN_MIN          = 1.0
local DRG_SUSTAIN_MAX          = 10.0
CFG.CURE_RANGE               = 20.0
CFG.ACTIVE_MOB_RANGE         = 20.0
-- Bar-element (WHM AoE) coverage. The spell is centered on the caster
-- with a 10-yalm effective radius (HorizonXI wiki "effective area radius
-- is 10'"). A checked member must be within this to actually receive
-- the buff from our cast. Same radius for all six elements -- it's a
-- function of the AoE marker, not the element.
CFG.BARSPELL_RADIUS          = 10.0
-- Minimum CURRENT MP (absolute, not %) required to break rest and stand
-- up specifically for a bar-element cast. The cast itself only costs 12
-- MP, but standing for a 12-MP buff the instant we sit down would thrash
-- rest; a 100-MP floor means we only interrupt a rest for it when we
-- have a healthy pool. Once standing, the 12-MP cast gate in
-- cast_on_target is what actually governs the cast.
CFG.BARELEMENT_STAND_MP      = 100
-- How often (seconds) to echo the "needed but out of range" warning
-- when a checked member lacks the active bar-element but is too far
-- for the AoE to reach.
local BARELEMENT_ECHO_SEC      = 5.0
-- Auto Move: two-threshold (hysteresis) distance gate. Single
-- threshold doesn't work because /follow in FFXI sticks to the
-- target at the engine's default follow distance (~1-2 yalms),
-- not at our stop value -- once we issue /follow we keep moving
-- until we explicitly /follow off. With one threshold we'd start
-- chasing at the same number we stop at, and end up overshooting
-- to within a few yalms of the target every time.
--   TRIGGER_DIST : if NOT currently following a member, only start
--                  chasing when they're farther out than this.
--                  Higher than STOP_DIST so a target who bounces
--                  near the boundary doesn't churn the toggle.
--   STOP_DIST    : once we ARE chasing, /follow off when within
--                  this. Some overshoot (1-3 yalms past STOP_DIST)
--                  is still expected due to the tick latency between
--                  the distance read and the /follow off command
--                  taking effect server-side.
CFG.AUTO_MOVE_TRIGGER_DIST   = 21.0
CFG.AUTO_MOVE_STOP_DIST      = 18.0
-- Re-issue /ta + /follow this often when still walking to the same
-- target. Recovers from dropped follows (movement key nudge, mob hit,
-- player tabbed targets manually). Long enough that we're not chat-
-- spamming, short enough that a dropped follow is back online quickly.
local AUTO_MOVE_RESEND_SEC     = 5.0
CFG.DEBUFF_STAND_MP          = 50
-- Debuff HP window for the first round of debuffs (Dia / Paralyze / Slow):
--   above CFG.DEBUFF_MAX_MOBHP        -> wait (mob probably not engaged yet,
--                                    avoid casting on the wrong target)
--   below CFG.DEBUFF_MIN_MOBHP        -> abandon remaining first-round debuffs
--                                    (mob will die soon, Slow/Paralyze
--                                    won't matter, save the MP for cures)
-- Dia *reapply* (when enabled) is gated by a separate, lower floor
-- (CFG.DEBUFF_REAPPLY_MIN_MOBHP) and ignores the MAX gate entirely. Reapply
-- is cheap (Dia I = 7 MP, Dia II = 12 MP) and the DoT keeps ticking
-- damage at any HP, so we want to keep the cycle going much further
-- into the fight than for the one-shot debuffs. With reapply enabled,
-- Dia recasts whenever the mob HP is at or above CFG.DEBUFF_REAPPLY_MIN_MOBHP,
-- regardless of whether CFG.DEBUFF_MIN_MOBHP would have abandoned a
-- first-round Dia.
CFG.DEBUFF_MAX_MOBHP         = 98
CFG.DEBUFF_MIN_MOBHP         = 50
CFG.DEBUFF_REAPPLY_MIN_MOBHP = 30
local CAST_TIMEOUT_SEC         = 3.5
local POST_CAST_SETTLE         = 1.0
-- Extra spell_lock_until offset used ONLY when a cast was confirmed
-- via buff-icon detection (try_buff_completion) rather than via the
-- chat-line completion path. Background: the buff icon appears the
-- moment the cast bar fills, but the server doesn't release the
-- spell slot until the post-bar animation finishes a beat later.
-- The chat "Player casts X" line, by contrast, is gated on the
-- same animation completing, so log-path confirmations need no
-- such extra wait. POST_CAST_SETTLE_BUFF is the cushion between
-- buff-detected and "server will accept the next /ma". Empirically
-- ~0.5s on Horizon (RDM Reraise + immediate Refresh test). Tune
-- if casttimes.txt shows `via=buff` rows followed by unable-to-cast
-- failures on the next cast.
local POST_CAST_SETTLE_BUFF    = POST_CAST_SETTLE + 0.5

-- Anti-spam guard for "Unable to cast spells at this time" cycles.
-- When the server keeps refusing a cast (because the buff is
-- actually still on the player, the spell-slot is still busy, or
-- our buff-detection is mistakenly saying the buff is absent), we
-- DO NOT want to /ma /ma /ma our way into a ban. After this many
-- consecutive UTC rejects for the SAME spell, the cooldown for
-- that spell is pushed out by UNABLE_TO_CAST_LOCKOUT_SEC so the
-- bot stops trying it. complete_cast() resets the counter to 0
-- on any successful confirmation (any method: buff / log /
-- timeout), so a single bad cycle doesn't permanently freeze the
-- spell. Counter is also reset implicitly when a different spell
-- successfully casts (cascade moved on).
local UNABLE_TO_CAST_LOCKOUT_THRESHOLD = 2
local UNABLE_TO_CAST_LOCKOUT_SEC       = 60.0

-- Global UTC throttle. The per-spell spam guard above only catches
-- ONE spell rejecting repeatedly; it does NOT catch the cascade
-- pattern where the bot cycles through Dia / Paralyze / Slow /
-- Refresh / Haste / Regen / Poisona and gets a UTC on EACH (so
-- the per-spell counter never crosses threshold for any one of
-- them, even though the player is being chat-spammed with 5+ fails
-- per second). This second-layer guard counts UTCs across ALL
-- spells in a sliding window and HALTS ALL CASTING for a backoff
-- period when it trips. Resets when any cast confirms successfully.
local GLOBAL_UTC_WINDOW_SEC   = 10.0
local GLOBAL_UTC_THRESHOLD    = 4
local GLOBAL_UTC_BACKOFF_SEC  = 30.0
-- Post-bar animation tail. Empirically the gap between
-- cast-bar-fills and chat-line-confirmation on HorizonXI is 3-5s
-- for party-target casts (Dia/Paralyze/Slow/party-Refresh/party-
-- Haste/party-Regen/Poisona) -- much longer than the wiki "Casting
-- Time" hints at. The wiki only documents the cast bar; the chat
-- confirmation arrives AFTER the bar fills plus a server-side
-- finish phase. Self-target buffs are faster (~1-2s tail) because
-- the buff-icon detection path catches them at the bar-fill moment,
-- but party/mob-target casts depend on the chat parser which only
-- fires after the full sequence completes.
--
-- Setting this to 5.0 means timeout fires at cast_time + 5.0 + 1.0;
-- for a 4.0s Refresh cast bar that's 10s, covering observed 8.4-
-- 8.6s real completions with a small headroom. Self-target casts
-- still confirm via buff polling at ~1-2s after the bar, well
-- inside this window. The timeout fallback only kicks in when both
-- buff AND log signals miss.
local ANIMATION_END_SEC        = 5.0
local POST_CURE_SUPPRESS       = 2.0   -- seconds to suppress re-curing same target after a cure lands
local MOB_ENGAGE_RANGE         = 20.0
local REST_TOGGLE_CD           = 3.0
local STAY_STANDING_SEC        = 4.0
-- After stand_up sends /heal, the player's entity Status field flips
-- out of "resting" before the stand-up animation actually finishes.
-- Casts fired in that gap get rejected with "Unable to cast spells at
-- this time" and the addon then auto-rests, looping the failure.
-- cast_on_target refuses for this long after a stand_up to let the
-- animation settle. ~95% of the time the natural inter-tick spacing
-- covers it; this is the belt-and-suspenders for the remaining 5%.
local STAND_SETTLE_SEC         = 0.5
-- Movement settle: minimum quiet time after the player last moved
-- before we'll try a new /ma. Casts get interrupted by ANY movement
-- in FFXI (mid-cast step, /follow walk, knockback, etc.), so firing
-- /ma into a moving player is wasted MP and a guaranteed
-- "Your casting is interrupted." Polled by poll_player_movement()
-- at the top of tick() via player X/Y deltas, NOT by tracking
-- /follow state -- the same gate covers manual WASD walking, an
-- ally bumping us, getting blown back by a knockback move, etc.
local MOVEMENT_SETTLE_SEC      = 0.5
-- Coord-delta dead zone for the movement poller. Smaller than the
-- smallest "real" step (about 0.5 yalms per tick at run speed) but
-- larger than server-sync micro-jitter (~0.01-0.05 yalms when
-- standing still). Without the dead zone we'd permanently flag
-- "just moved" from baseline noise.
local MOVEMENT_DEAD_ZONE_YALMS = 0.1

-- Force-rest override: when the Force Rest toggle is on, stand_up()
-- blocks unconditionally for almost every caller -- the user has
-- explicitly committed to resting and we honor that. The single
-- exception is the emergency cure path, which calls stand_up with
-- allow_force_rest_override=true; for that caller, force_rest_allows_stand()
-- makes the final decision: stand only if some ally (in cure range,
-- self counts) has HP% strictly below FORCE_REST_OVERRIDE_HP_PCT AND
-- the player has at least FORCE_REST_OVERRIDE_MIN_MP. Flat MP here
-- (not percent) because 60 MP covers one Cure II/III -- if we can't
-- afford a meaningful cure we shouldn't be breaking the rest.
local FORCE_REST_OVERRIDE_HP_PCT = 20
local FORCE_REST_OVERRIDE_MIN_MP = 60

-- Force Rest duration: clicking Force Rest commits the player to resting
-- for this many seconds, then auto-releases. While the timer is running
-- it overrides Disable Rest. Emergency override (FORCE_REST_OVERRIDE_*)
-- still applies. Click again to cancel early.
local FORCE_REST_DURATION        = 180

-- Auto Full Rest: when the user toggle is on, once we've been resting
-- for AUTO_FULL_REST_SEC seconds and are already at or above
-- AUTO_FULL_REST_MP_PCT, block non-cure stand-ups (debuffs, auto-dispel,
-- paralyna/silena/poisona) until MP hits 100%. Reasoning: the last 10-20%
-- of a rest is cheap MP, and interrupting it for a debuff that could wait
-- 5-10 more seconds is a bad trade. Emergency cures still fire.
local AUTO_FULL_REST_SEC       = 30
local AUTO_FULL_REST_MP_PCT    = 80

-- Idle rest floor: when not engaged/resting, don't sit down to rest
-- unless MP is below this percent. Avoids the bot kneeling for a
-- trivial top-off (e.g. 96-99% MP) when idle. Below this, idle rest
-- proceeds as normal.
local IDLE_REST_MP_FLOOR_PCT   = 95

-- ImGuiInputTextFlags_ReadOnly (1 << 14 = 16384). Used to lock name-entry
-- boxes while the bot is running, so changing who is being targeted mid-run
-- can't cause stale-name / stale-timer races.
local IMGUI_INPUT_READONLY     = 16384

-- ImGuiTreeNodeFlags_DefaultOpen (1 << 5 = 32). Passed to CollapsingHeader
-- so the section starts expanded on load; user can collapse manually.
local IMGUI_TREE_DEFAULT_OPEN  = 32

-- HP% thresholds for WHEN to cure (reliable, no max-HP dependency).
-- hp_pct <= EMERGENCY_CURE_THRESHOLD -> emergency cure (50%)
-- hp_pct <  CFG.NORMAL_CURE_THRESHOLD    -> normal cure    (< 70%)

local SPELL_CD = {
    -- Base recast times from the HorizonXI wiki. Effective recast for
    -- the cooldown gate is computed at cast time via
    -- FC.recast_time(), which applies Fast Cast and magic
    -- Haste per the wiki's combined formula:
    --   New Recast = floor( (1 - FC) * round_10ths( (1 - Haste) * Base ) )
    -- A small +0.5s margin is added on top of the computed value so
    -- we don't race the server clock by a few ticks. Keep these
    -- entries as the wiki BASE values (no addon-side padding).
    ['Cure IV']  = 8.0,
    ['Cure III'] = 6.0,
    ['Cure II']  = 5.5,
    ['Cure']     = 5.0,
    ['Cure V']   = 10.0,
    ['Curaga']   = 10.0,
    ['Dia']      = 5.0,
    ['Dia II']   = 6.0,
    ['Bio']      = 5.0,
    ['Bio II']   = 6.0,
    ['Phalanx']  = 10.0,
    ['Paralyze'] = 10.0,
    ['Slow']     = 20.0,
    ['Blind']    = 10.0,
    ['Silence']  = 10.0,
    ['Refresh']  = 16.0,
    ['Haste']    = 18.0,
    ['Dispel']   = 10.0,
    ['Sleep']    = 20.0,
    ['Bind']     = 40.0,
    ['Paralyna'] = 5.0,
    ['Silena']   = 5.0,
    ['Poisona']  = 5.0,
    ['Blindna']  = 5.0,
    ['Regen']    = 12.0,
    ['Stoneskin'] = 30.0,
    ['Blink']     = 10.0,
    -- BLM Skillup elementals. Tier I = 5s recast, Tier II = 7s.
    -- Four elements (Earth/Water/Wind/Ice), both tiers each. Fire and
    -- Thunder are intentionally NOT included -- the skillup picker
    -- gives you these four to choose from, one selection at a time.
    ['Stone']      = 5.0,
    ['Stone II']   = 7.0,
    ['Water']      = 5.0,
    ['Water II']   = 7.0,
    ['Aero']       = 5.0,
    ['Aero II']    = 7.0,
    ['Blizzard']   = 5.0,
    ['Blizzard II']= 7.0,
    -- Protect / Shell single-target tiers. Wiki: base recast 5.0s for
    -- tier I, +0.25s per tier through IV. Single-target only on Horizon
    -- (Protect V / Shell V do not exist as learnable spells; only -ra
    -- goes to V).
    ['Protect']    = 5.0,
    ['Protect II'] = 5.25,
    ['Protect III']= 5.5,
    ['Protect IV'] = 5.75,
    ['Shell']      = 5.0,
    ['Shell II']   = 5.25,
    ['Shell III']  = 5.5,
    ['Shell IV']   = 5.75,
    -- Reraise: long re-attempt window. The in-game spell cooldown is
    -- enforced by FFXI itself; this addon-side value is just a throttle
    -- so that if our buff-detection ever lags or is wrong (wrong status
    -- id, race with packet timing), we don't spam attempts. 60s is a
    -- comfortable middle: legitimate re-cast after the 1-hour buff
    -- expires waits at most 60s, and any false-negative noise stays
    -- bounded to once a minute. Left as-is since it's not a real
    -- recast mirror.
    ['Reraise']  = 60.0,
    -- Bar-element AoE spells (WHM native). All six share the same
    -- mechanical profile -- 12 MP, 0.5s cast, 10s recast, ~2:30 base
    -- duration. Only the element resisted and the level requirement
    -- differ (see SPELL_LEVEL below). The bovinemage GUI's Bar Elemental
    -- Spells panel lets the user pick ONE active element at a time;
    -- whichever is selected is what gets cast.
    ['Barfira']    = 10.0,
    ['Barblizzara']= 10.0,
    ['Baraera']    = 10.0,
    ['Barstonra']  = 10.0,
    ['Barthundra'] = 10.0,
    ['Barwatera']  = 10.0,
}

local SPELL_CAST_TIME = {
    ['Cure IV']  = 2.5,
    ['Cure III'] = 2.5,
    ['Cure V']   = 2.5,
    ['Curaga']   = 4.5,
    ['Cure II']  = 2.25,
    ['Cure']     = 2.0,
    ['Dia']      = 1.0,
    ['Dia II']   = 1.5,
    ['Bio']      = 1.0,
    ['Bio II']   = 1.5,
    ['Phalanx']  = 3.0,
    ['Paralyze'] = 3.0,
    ['Slow']     = 2.0,
    ['Blind']    = 2.0,
    ['Silence']  = 3.0,
    ['Refresh']  = 5.0,
    ['Haste']    = 3.0,
    ['Dispel']   = 3.0,
    ['Sleep']    = 2.5,
    ['Bind']     = 2.0,
    ['Paralyna'] = 1.0,
    ['Silena']   = 1.0,
    ['Poisona']  = 1.0,
    ['Blindna']  = 1.0,
    ['Regen']    = 4.0,
    ['Stoneskin'] = 7.0,
    ['Blink']     = 6.0,
    ['Reraise']  = 8.0,  -- Reraise I has a long cast time
    -- Bar-element AoE: 0.5s cast bar (uniform across all six elements).
    ['Barfira']    = 0.5,
    ['Barblizzara']= 0.5,
    ['Baraera']    = 0.5,
    ['Barstonra']  = 0.5,
    ['Barthundra'] = 0.5,
    ['Barwatera']  = 0.5,
    -- BLM Skillup elementals: tier-I = 2.5s cast bar, tier-II = 3.5s
    ['Stone']      = 2.5,
    ['Stone II']   = 3.5,
    ['Water']      = 2.5,
    ['Water II']   = 3.5,
    ['Aero']       = 2.5,
    ['Aero II']    = 3.5,
    ['Blizzard']   = 2.5,
    ['Blizzard II']= 3.5,
    -- Protect / Shell tiers (wiki). Cast time scales with tier same as
    -- recast: I=1.0, II=1.25, III=1.5, IV=1.75.
    ['Protect']    = 1.0,
    ['Protect II'] = 1.25,
    ['Protect III']= 1.5,
    ['Protect IV'] = 1.75,
    ['Shell']      = 1.0,
    ['Shell II']   = 1.25,
    ['Shell III']  = 1.5,
    ['Shell IV']   = 1.75,
}

-- Estimated HP healed per cure tier, used ONLY by the Brd anti-overcure
-- path. Base HorizonXI potencies are 30 / 90 / 190 / 390 (Cure I-IV);
-- these include the user's +10% Cure Potency staff, so the stored
-- values are the REAL expected heal: 33 / 99 / 209 / 429. Cure output
-- is NOT fixed in FFXI (varies with MND/VIT/Healing skill/day/weather),
-- so if any tier is observed to overshoot, set it to the measured value
-- here. The picker further multiplies by (1 + BRD_OVERCURE_BUFFER) as a
-- safety margin, so the total effective check is base * 1.10 (staff) *
-- 1.10 (buffer); erring HIGH drops a tier sooner, the safe direction.
local CURE_HP_EST = {
    ['Cure IV']  = 429,   -- 390 base + 10% staff
    ['Cure III'] = 209,   -- 190 base + 10% staff
    ['Cure II']  = 99,    -- 90 base + 10% staff
    ['Cure']     = 33,    -- 30 base + 10% staff
}
-- Extra safety buffer on the estimated heal. Set to 0: the staff's
-- +10% Cure Potency is already baked into CURE_HP_EST (33/99/209/429),
-- so no additional margin is wanted. The picker check is simply
-- estimate * (1 + 0) = estimate <= headroom.
local BRD_OVERCURE_BUFFER = 0.0

-- Brd cure CEILING: never cure a Brd-enrolled member to above this
-- fraction of their MaxHP. The anti-overcure picker fits the cure
-- against headroom = floor(BRD_CURE_CEILING_PCT * max_hp) - current_hp,
-- NOT against full missing HP. So a Brd at 60% with a 74% ceiling has
-- only ~14% of MaxHP of room, and the picker chooses the largest tier
-- whose buffered estimate fits inside THAT, or holds.
local BRD_CURE_CEILING_PCT = 0.74

-- HP% trigger band for the Brd anti-overcure path: a Brd-enrolled
-- member is only considered for a cure when at or below this HP%.
local BRD_CURE_TRIGGER_PCT = 50

-- Top-tier (Cure IV) gate for the Brd path: Cure IV is ONLY allowed
-- when the Brd is at or below this HP%. At/above it, the picker is
-- capped at the second tier (Cure III) and below, even if Cure IV's
-- math would "fit" -- top tier overheals too easily and the estimate
-- is unreliable, so we hard-gate it to genuine emergencies.
local BRD_TOP_TIER_PCT = 25

local SPELL_MP_COST = {
    ['Cure IV']  = 88,
    ['Cure III'] = 46,
    ['Cure II']  = 24,
    ['Cure']     = 8,
    ['Dia']      = 7,
    ['Dia II']   = 20,
    ['Bio']      = 15,
    ['Bio II']   = 36,
    ['Phalanx']  = 21,
    ['Paralyze'] = 6,
    ['Slow']     = 15,
    ['Blind']    = 5,
    ['Silence']  = 16,
    ['Refresh']  = 50,
    ['Haste']    = 40,
    ['Dispel']   = 25,
    ['Sleep']    = 20,
    ['Bind']     = 10,
    ['Paralyna'] = 15,
    ['Silena']   = 15,
    ['Poisona']  = 15,
    ['Blindna']  = 14,
    ['Regen']    = 16,
    ['Stoneskin'] = 29,
    ['Blink']     = 20,
    ['Reraise']  = 50,
    -- Bar-element AoE: 12 MP (uniform across all six elements).
    ['Barfira']    = 12,
    ['Barblizzara']= 12,
    ['Baraera']    = 12,
    ['Barstonra']  = 12,
    ['Barthundra'] = 12,
    ['Barwatera']  = 12,
    -- BLM Skillup elementals (RDM/BLM costs; verify if Horizon differs)
    ['Stone']      = 7,
    ['Stone II']   = 16,
    ['Water']      = 9,
    ['Water II']   = 23,
    ['Aero']       = 13,
    ['Aero II']    = 35,
    ['Blizzard']   = 24,
    ['Blizzard II']= 67,
    -- Protect / Shell tiers (HorizonXI wiki).
    ['Protect']    = 9,
    ['Protect II'] = 28,
    ['Protect III']= 46,
    ['Protect IV'] = 65,
    ['Shell']      = 18,
    ['Shell II']   = 37,
    ['Shell III']  = 56,
    ['Shell IV']   = 75,
}

-- Level requirements for non-cure spells (flat, job-independent)
local SPELL_LEVEL = {
    ['Dia']      = 5,
    ['Dia II']   = 35,
    -- Bio: BLM 10, RDM 10, DRK 15 (HorizonXI wiki). Lowest entry
    -- point used here. In HorizonXI, Bio and Dia overwrite each
    -- other on the mob, so they share the dia rotation slot.
    ['Bio']      = 10,
    -- Bio II: BLM 35, RDM 36, DRK 40 (HorizonXI wiki). Lowest
    -- entry point used here.
    ['Bio II']   = 35,
    -- Phalanx: RDM 33 only (PLD 77 / RUN 68 unreachable at 75-cap).
    -- phalanx_usable() does the per-job RDM check at the panel level.
    ['Phalanx']  = 33,
    ['Paralyze'] = 16,
    ['Slow']     = 24,
    -- Blind: BLM 4, RDM 8 (HorizonXI era). Lowest entry point used
    -- here; spell_usable() does the per-job main+sub check.
    ['Blind']    = 4,
    -- Silence: WHM 15, RDM 18 (HorizonXI era). Lowest entry point
    -- used here; spell_usable() does the per-job main+sub check.
    ['Silence']  = 15,
    ['Refresh']  = 41,
    ['Dispel']   = 32,
    ['Sleep']    = 10,
    ['Bind']     = 8,
    ['Paralyna'] = 17,
    ['Silena']   = 26,
    ['Poisona']  = 5,
    ['Blindna']  = 14,
    ['Regen']    = 10,
    -- Stoneskin: WHM 28, RDM 34, SCH 44, RUN 55 (HorizonXI wiki).
    -- Lowest entry point used here; stoneskin_usable() does the
    -- per-job check so subjobs with insufficient main level don't
    -- get an enabled toggle.
    ['Stoneskin'] = 28,
    -- Blink: WHM 19, RDM 23, SCH 29, RUN 35 (HorizonXI wiki).
    -- Blink is White Magic on Horizon -- not the BLU/NIN spell it
    -- shares its name with on some private servers.
    ['Blink']     = 19,
    -- Reraise: WHM 25. spell_usable() compares against P.player_level()
    -- (main job level), which is fine for both WHM-main and X/WHM
    -- subjob cases -- a player with WHM sub level 25 must have main
    -- level 50+ (sub is half of main), so P.player_level() >= 25 always
    -- holds when the JOB constraint passes. The job constraint itself
    -- is checked in reraise_usable() (further down in the file).
    ['Reraise']  = 25,
    -- Bar-element AoE: WHM-native, level varies per element. Barfira is
    -- the earliest (WHM 5); we use the lowest entry point for each as a
    -- floor since barelement_usable() does the per-job-and-level check
    -- at the panel level. Listed in element order (Fire/Ice/Wind/Earth/
    -- Lightning/Water = status IDs 100-105).
    ['Barfira']    = 5,
    ['Barblizzara']= 5,
    ['Baraera']    = 7,
    ['Barstonra']  = 7,
    ['Barthundra'] = 9,
    ['Barwatera']  = 9,
    -- BLM Skillup elementals. Levels listed are RDM job-level
    -- requirements (BLM has earlier access; spell_usable() does the
    -- main-job and sub-job level check at cast time).
    ['Stone']      = 5,
    ['Stone II']   = 28,
    ['Water']      = 9,
    ['Water II']   = 34,
    ['Aero']       = 15,
    ['Aero II']    = 40,
    ['Blizzard']   = 27,
    ['Blizzard II']= 48,
    -- Protect / Shell. WHM and RDM share the same level thresholds
    -- (per HorizonXI wiki); PLD is +3 to +10 levels behind. Lowest
    -- entry point used here -- protect_usable / shell_usable do the
    -- per-job check so a PLD doesn't get Protect II at level 27.
    ['Protect']    = 7,
    ['Protect II'] = 27,
    ['Protect III']= 47,
    ['Protect IV'] = 63,
    ['Shell']      = 17,
    ['Shell II']   = 37,
    ['Shell III']  = 57,
    ['Shell IV']   = 68,
}

-- Case-insensitive lookup helper.
--
-- Why this exists: chat-line parsers (parse_player_starts_casting,
-- parse_player_casts_name) feed lowercase spell names ("refresh",
-- "reraise") into FC.cast_time / FC.recast_time, but the SPELL_*
-- tables above are keyed by canonical capitalized names ("Refresh",
-- "Reraise"). A direct lookup of the lowercase key returned nil,
-- the FC functions fell through to their default fallback, and the
-- starts_casting timeout bump then set cast_timeout_at to a wrong
-- (much shorter) value that timed out before the cast completed.
--
-- spell_lookup() returns tbl[name] regardless of which case the
-- caller passed. Implementation: build a lowercase shadow index
-- per table at module load (one-time cost), then dispatch through
-- it. Keeps the literal-uppercase call sites elsewhere in the file
-- (e.g. SPELL_MP_COST['Dispel']) working unchanged.
local SPELL_LOOKUP = {}
local function build_lookup_index(tbl)
    local idx = {}
    for k, v in pairs(tbl) do idx[k:lower()] = v end
    return idx
end
SPELL_LOOKUP.cast_time = build_lookup_index(SPELL_CAST_TIME)
SPELL_LOOKUP.cd        = build_lookup_index(SPELL_CD)
SPELL_LOOKUP.mp_cost   = build_lookup_index(SPELL_MP_COST)
SPELL_LOOKUP.level     = build_lookup_index(SPELL_LEVEL)

-- Case-insensitive single-spell lookup. Pass the lowercase index
-- name ('cast_time', 'cd', 'mp_cost', 'level') and the spell name
-- in either case.
local function spell_lookup(which, spell_name)
    if type(spell_name) ~= 'string' then return nil end
    local idx = SPELL_LOOKUP[which]
    if not idx then return nil end
    return idx[spell_name:lower()]
end

-- Cure tier level requirements per job.
-- Emergency uses best available cascading down; normal uses 2nd best only.
local JOB_WHM = 3
local JOB_RDM = 5
local JOB_PLD = 7

local CURE_TIERS = { 'Cure IV', 'Cure III', 'Cure II', 'Cure' }

local CURE_JOB_LEVELS = {
    ['Cure']     = { [JOB_WHM]=1,  [JOB_RDM]=3,  [JOB_PLD]=5  },
    ['Cure II']  = { [JOB_WHM]=11, [JOB_RDM]=14, [JOB_PLD]=17 },
    ['Cure III'] = { [JOB_WHM]=21, [JOB_RDM]=26, [JOB_PLD]=30 },
    -- RDM only: Cure IV unlocks at 48 but the potency/MP ratio is poor on
    -- RDM until roughly 55. Hold off until then so the rotation keeps using
    -- Cure III in that window. WHM/PLD stay at their natural unlock levels.
    ['Cure IV']  = { [JOB_WHM]=41, [JOB_RDM]=50, [JOB_PLD]=50 },
}

-- DEBUFF_ROTATION is built dynamically from per-debuff state flags.
-- See active_debuff_rotation() near Mob.get_next_debuff() below.

-- Mob buffs we will dispel on sight, even if resting. Extend as new ones come
-- up — anything in here and present on the claimed mob triggers auto-dispel
-- subject to the MP / mob-HP gates below.
CFG.AUTO_DISPEL_BUFFS = {
    [92] = 'Evasion Boost',
    [93] = 'Defense Boost',
}
CFG.AUTO_DISPEL_MIN_MP_PCT  = 30   -- don't dispel below this MP%
CFG.AUTO_DISPEL_MIN_MOB_HP  = 25   -- don't bother below this mob HP% (they'll
                                     -- die soon -- the buff we'd dispel would
                                     -- have less impact than the MP we'd spend)
CFG.AUTO_DISPEL_DELAY       = 2    -- wait this long (seconds) after seeing the
                                     -- buff land before dispelling, so the effect
                                     -- actually triggers before we strip it

-- Short names for buffs/debuffs, used when rendering the mob status line in
-- the debug panel. IDs cross-checked with general.lua's STATUS_EFFECTS.
local DEBUFF_NAMES = {
    [2]   = 'sleep',    [3]   = 'poison',   [4]   = 'paralyze', [5]   = 'blind',
    [6]   = 'silence',  [7]   = 'petrify',  [10]  = 'stun',     [11]  = 'bind',
    [12]  = 'weight',   [13]  = 'slow',     [14]  = 'charm',    [16]  = 'amnesia',
    [19]  = 'sleep2',   [28]  = 'terror',   [29]  = 'mute',
    [128] = 'burn',     [129] = 'frost',    [130] = 'choke',    [131] = 'rasp',
    [132] = 'shock',    [133] = 'drown',    [134] = 'dia',      [135] = 'bio',
    [144] = 'maxhp-',   [145] = 'maxmp-',   [146] = 'acc-',     [147] = 'atk-',
    [148] = 'eva-',     [149] = 'def-',     [156] = 'flash',    [168] = 'tp-',
    [193] = 'lullaby',  [194] = 'elegy',
    -- Mob-side buffs we care about (for the auto-dispel list).
    [33]  = 'haste',    [40]  = 'protect',  [41]  = 'shell',
    [42]  = 'regen',    [43]  = 'refresh',
    [92]  = 'eva boost', [93]  = 'def boost',
}

-- Buff IDs and recast timers
-- IDs cross-checked against general.lua's STATUS_EFFECTS table.
-- Bar-element status IDs (sequential block in FFXI's status table,
-- cross-referenced against LuaCast/ffxi/buff.lua at master). Each
-- bar-element is its own distinct ID -- they do NOT share an icon --
-- so checking the right ID per element gives unambiguous detection.
-- Keyed by SPELL NAME (the AoE -ra form, which is what we cast) so a
-- single lookup gets from spell -> buff id without a second mapping.
-- All file-scope status / buff IDs in one table. Folded from
-- individual `local BUFF_X = N` declarations to free file-scope local
-- slots (the main chunk was at LuaJIT's 200-locals ceiling and any
-- additional file-scope local pushed it over). One field per ID rather
-- than 16+ locals; refs use BUFF.NAME and pay the same indexed-table
-- cost as any other constant table in this file (DEBUFF_NAMES,
-- BARELEMENT_BUFF_ID, SPELL_LEVEL, etc).
local BUFF = {
    -- Self / party buffs
    REFRESH   = 43,
    HASTE     = 33,
    REGEN     = 42,
    PROTECT   = 40,
    SHELL     = 41,
    STONESKIN = 37,
    BLINK     = 36,
    PHALANX   = 116,
    -- DoT / debuffs we check on self (or remove from party members)
    PARALYSIS = 4,
    SILENCE   = 6,
    POISON    = 3,
    BLIND     = 5,
    BIO       = 135,
    -- Action-preventing debuffs (block stand-from-rest / casting)
    SLEEP     = 2,
    SLEEP2    = 19,
    PETRIFY   = 7,
    STUN      = 10,
    TERROR    = 28,
}

local BARELEMENT_BUFF_ID = {
    ['Barfira']     = 100,  -- Barfire status
    ['Barblizzara'] = 101,  -- Barblizzard status
    ['Baraera']     = 102,  -- Baraero status
    ['Barstonra']   = 103,  -- Barstone status
    ['Barthundra']  = 104,  -- Barthunder status
    ['Barwatera']   = 105,  -- Barwater status
}
-- Ordered list of bar-element spell names. Drives the GUI radio order
-- and the "what element is active" display. Element ordering matches
-- the status-ID block (Fire/Ice/Wind/Earth/Lightning/Water).
local BARELEMENT_ORDER = {
    'Barfira', 'Barblizzara', 'Baraera',
    'Barstonra', 'Barthundra', 'Barwatera',
}

-- Spell name (RAW, as written in /ma) -> buff id that should be
-- present on the target if the cast actually landed. Drives the
-- timeout-validation path in complete_cast_body: when method='timeout'
-- we cross-check against this table, and if the spell has an entry
-- but the target doesn't actually have the buff, the cast is
-- re-classified from success (full recast CD) to failure (1s retry).
-- Solves the "Thelord shows 158s Haste CD but doesn't have Haste"
-- class of bug -- the addon would otherwise trust the cast-timeout
-- fallback's success assumption and lock the spell on Thelord for
-- a full recast even though the buff never landed.
--
-- Only spells whose presence is reliably visible in the party
-- buff cache (StatusHandler) belong here. Offensive spells
-- (Dia/Paralyze/Slow on mobs), short-cast utility spells without a
-- visible buff, and any spell where the buff fades on a timer
-- shorter than the cast timeout do NOT belong here.
local SPELL_VERIFICATION_BUFF
CFG.BUFF_RERAISE      = 113   -- Reraise I/II/III all share this status icon
                                -- in FFXI, so this single id covers any tier.
                                -- If the addon ever spam-recasts Reraise after
                                -- a successful land, double-check the id via
                                -- /bm buffs -- some private servers shift it.

-- Buff lifetime as imposed by the FFXI server, in seconds. These are
-- FFXI FACTS and are NOT cast times -- cast time is in SPELL_CAST_TIME
-- above. Buff duration is how long the status icon stays on the target
-- after a successful cast; cast time is how long the cast bar takes to
-- fill. Code that needs to know "when does this buff naturally expire"
-- reads from here. Code that needs "how long does the cast take" reads
-- from SPELL_CAST_TIME.
local SPELL_BUFF_DURATION = {
    ['Refresh'] = 180,
    ['Haste']   = 180,
    ['Regen']   = 75,
    -- Protect / Shell: 30 minutes per HorizonXI wiki. All tiers share
    -- the same duration. The timer is GUI-only (recast trigger is the
    -- buff cache), so it just needs to be a reasonable bound.
    ['Protect'] = 1800,
    ['Shell']   = 1800,
}

-- Recast-overlap window per spell, in seconds. Effective timer
-- written into refresh/haste/regen_timers is
--   (SPELL_BUFF_DURATION[spell] - SPELL_OVERLAP[spell]),
-- so the timer flips to "due" this many seconds before the FFXI
-- buff would naturally drop. The cast itself can't fire while the
-- buff is still present (the buff-visibility guard in
-- next_*_target blocks it), so a positive overlap just queues the
-- timer to expire slightly early -- the recast goes out the moment
-- the server clears the buff. Absent or zero -> no overlap, timer
-- counts down to 0 right at the buff-drop mark.
local SPELL_OVERLAP = {
    ['Refresh'] = 5,
    ['Haste']   = 5,
    ['Regen']   = 5,
    ['Protect'] = 5,
    ['Shell']   = 5,
}

-- Convenience buff MP gate (Refresh / Haste / Regen): cast (and stand
-- from rest if needed) only when MP% is at or above this threshold.
-- Reasoning: each costs 16-45 MP; below 80% we'd burn the headroom
-- needed for cures. Reraise has its own (higher) gate further down.
-- Auto Full Rest's "tail of the rest" lock beats this -- when it
-- blocks, we let the rest finish even if MP% is past the gate.
CFG.CONVENIENCE_BUFF_MIN_MP_PCT = 80

-- Reraise auto-cast: only fire when MP% is at or above this threshold.
-- Rationale: Reraise has a 14s cast time and costs 50 MP, both of which
-- want comfortable headroom. Anything below ~90% means we're either in
-- the middle of a fight or recovering from one, neither a good moment
-- to commit 14 seconds and 50 MP to a maintenance buff.
CFG.RERAISE_MIN_MP_PCT = 75

-- Status ailment buff IDs (on party members)
-- Self-buff status IDs that the addon casts as buffs.
-- HorizonXI uses the standard FFXI status-ID table; these are
-- verified against in-game observation:
--   37 = Stoneskin   (matches standard FFXI)
--   36 = Blink       (NOT 38 -- the wiki / some references list 38,
--                    but on HorizonXI the buff icon comes through
--                    as 36. Using the wrong ID broke both the
--                    cascade gate `not self_has_buff(BUFF.BLINK)`
--                    and the try_buff_completion buff-detection
--                    path, sending the bot into a UTC retry loop
--                    after a Blink cast because it thought the
--                    buff was absent when the server knew it was
--                    on.)
-- Body of the forward-declared SPELL_VERIFICATION_BUFF (defined
-- above, near the other BUFF_* IDs, before the constants depend on
-- BUFF.STONESKIN / BUFF.BLINK).
SPELL_VERIFICATION_BUFF = {
    -- Party buffs (verified on the actual target)
    ['Refresh']     = BUFF.REFRESH,
    ['Haste']       = BUFF.HASTE,
    ['Regen']       = BUFF.REGEN,
    ['Regen II']    = BUFF.REGEN,
    ['Regen III']   = BUFF.REGEN,
    -- Protect / Shell: all tiers share buff_id 40 / 41 server-side.
    ['Protect']     = BUFF.PROTECT,
    ['Protect II']  = BUFF.PROTECT,
    ['Protect III'] = BUFF.PROTECT,
    ['Protect IV']  = BUFF.PROTECT,
    ['Shell']       = BUFF.SHELL,
    ['Shell II']    = BUFF.SHELL,
    ['Shell III']   = BUFF.SHELL,
    ['Shell IV']    = BUFF.SHELL,
    -- Self buffs (verified on self)
    ['Stoneskin']   = BUFF.STONESKIN,
    ['Blink']       = BUFF.BLINK,
    ['Phalanx']     = BUFF.PHALANX,
    -- Bar-element AoE: all six are centered on caster, so the caster
    -- always receives the buff if the cast lands. Verified on self
    -- (party-member coverage is the AoE's job, not something we
    -- per-member confirm). Each spell has its own distinct buff id.
    ['Barfira']     = BARELEMENT_BUFF_ID['Barfira'],
    ['Barblizzara'] = BARELEMENT_BUFF_ID['Barblizzara'],
    ['Baraera']     = BARELEMENT_BUFF_ID['Baraera'],
    ['Barstonra']   = BARELEMENT_BUFF_ID['Barstonra'],
    ['Barthundra']  = BARELEMENT_BUFF_ID['Barthundra'],
    ['Barwatera']   = BARELEMENT_BUFF_ID['Barwatera'],
}
-- Action-preventing self-status IDs. IDs cross-checked against
-- DEBUFF_NAMES above. Sleep has two variants (Sleep I = 2,
-- Sleep II = 19) -- both must block. Petrify (7), Stun (10), and
-- Terror (28) all prevent any player action server-side and the
-- bot should refuse to cast or stand from rest while they're on.
-- DoT debuffs that drain HP while resting. Resting under either
-- forfeits the resting-tick HP gain and may break /heal outright,
-- so the rest-down path refuses to sit through them. (Bio's status
-- id is now in the BUFF table; see BUFF.BIO.)

-- Self-cast spell -> resulting buff ID. Used by the buff-detection
-- completion path in tick(): for self-target casts, FFXI does not
-- always emit a "Player casts <spell>" or even a "gains the effect"
-- chat line that our text_in parsers can catch. Reraise in
-- particular emits NEITHER -- the only observable evidence the cast
-- landed is that the buff icon appears on the player. So we
-- additionally poll self_has_buff() for the target buff ID; when it
-- transitions to true during is_casting, we treat it as a confirmed
-- completion. Keys are lowercase to match S.last_spell_sent (which
-- is set via normalize_action_name and is always lowercase).
local SELF_BUFF_MAP = {
    reraise   = CFG.BUFF_RERAISE,
    stoneskin = BUFF.STONESKIN,
    blink     = BUFF.BLINK,
    phalanx   = BUFF.PHALANX,
    refresh   = BUFF.REFRESH,
    haste     = BUFF.HASTE,
    regen     = BUFF.REGEN,
    -- Protect/Shell tiers. Lowercase keys match normalize_action_name output.
    protect        = BUFF.PROTECT,
    ['protect ii'] = BUFF.PROTECT,
    ['protect iii']= BUFF.PROTECT,
    ['protect iv'] = BUFF.PROTECT,
    shell          = BUFF.SHELL,
    ['shell ii']   = BUFF.SHELL,
    ['shell iii']  = BUFF.SHELL,
    ['shell iv']   = BUFF.SHELL,
}

-- Buff-detection completion path. Forward-declared here so the
-- tick() body can call it; the real body is defined after
-- spell_clear / CastLog / FC.cast_time exist (further down the
-- file). Mechanism: for self-target casts of spells in
-- SELF_BUFF_MAP, when the resulting buff appears on the player's
-- own buff list while is_casting is still true, treat that buff
-- transition as the completion signal -- same as a chat-line
-- match would. This is the ONLY signal available for Reraise on
-- HorizonXI: no "Player casts Reraise" line is emitted, no "gains
-- the effect of Reraise" line either; the buff icon just appears.
local try_buff_completion
-- Cast-completion / cast-failure helpers, also forward-declared so
-- the cast-timeout check inside tick() (which is defined upstream
-- of the bodies) can call them. Real bodies appear next to
-- try_buff_completion, after CastLog / spell_clear / FC are in
-- scope. complete_cast(method) is the success path; fail_cast_retry
-- (reason, raw_line) is the failure path (resets the spell's
-- cooldown so the cascade can retry).
local complete_cast
local fail_cast_retry

-- Job IDs defined above in CONSTANTS (JOB_WHM, JOB_RDM, JOB_PLD)

---------------------------------------------------------------------
-- STATE
---------------------------------------------------------------------

local S = {
    running                = false,
    debug                  = false,
    -- Cast-timeout fallback toggle. When true, the cast-timeout
    -- path in tick() is suppressed -- used only for diagnostic
    -- data collection (gather real `took X.XXXs` rows in
    -- casttimes.txt to tune ANIMATION_END_SEC against ground
    -- truth). When false (the default), the timeout path is the
    -- third completion signal after buff-detection and chat-log,
    -- and treats its firing as a successful completion (assumes
    -- the cast landed but the addon missed both other signals)
    -- rather than a failure -- see complete_cast('timeout').
    timeout_disable        = false,
    debuff_enabled         = true,
    debuff_reapply_enabled = false,  -- if true, Dia recasts when mob loses it
    -- Per-debuff toggles inside the debuff rotation.
    -- dia_tier: 0 = off, 1 = Dia, 2 = Dia II, 3 = Bio, 4 = Bio II
    -- (all five states mutually exclusive). Dia and Bio share the
    -- mob's enfeeble slot on HorizonXI ("they overwrite each other"),
    -- so a single rotation slot covers both families; the tier picker
    -- chooses which spell name + status ID we cast and watch for.
    dia_tier               = 1,
    paralyze_enabled       = true,
    slow_enabled           = true,
    blind_enabled          = true,
    auto_dispel_enabled    = true,   -- auto-dispel Evasion Boost etc. per CFG.AUTO_DISPEL_BUFFS
    -- Priority Silence on a named mob (typically an NM whose nukes
    -- need to be shut down). Sits ABOVE cures and party buffs in the
    -- cascade -- a Banishga / Stonega landing wipes the party faster
    -- than any cure cycle can catch up, so silencing first is the
    -- correct trade. Independent of debuff_enabled so the user can
    -- run priority silence even with the Dia/Para/Slow rotation off.
    mob_silence_enabled    = false,
    mob_silence_target     = 'The Sprinkler',  -- mob name to match against ent.Name
    -- Last sid we've observed Silence land on. Mirrors S.debuffs_done.dia
    -- but lives outside the active_debuff_mob's per-mob state because the
    -- Silence target is a NAMED mob, not whatever the picker is on. Used
    -- by the cast gate together with S.debuff_reapply_enabled: when
    -- reapply is OFF, the Silence priority cast fires once and stops;
    -- when reapply is ON, it fires whenever the buff is absent so the
    -- 2-minute duration gets refreshed before the NM can resume nuking.
    -- Cleared when the matching sid hits a death message in
    -- mob_debuff_clear, so a respawn (new sid) gets a fresh cast.
    silence_done_for_sid   = 0,
    cooldowns              = {},
    -- Per-spell consecutive "Unable to cast spells at this time"
    -- failure counter. Keyed by raw spell name (same key space as
    -- cooldowns). Incremented in fail_cast_retry whenever the
    -- server rejects a cast with that message; reset to 0 when a
    -- complete_cast() runs for the same spell (any method:
    -- buff / log / timeout). After UNABLE_TO_CAST_LOCKOUT_THRESHOLD
    -- consecutive rejects, the cooldown for that spell is bumped
    -- way out (UNABLE_TO_CAST_LOCKOUT_SEC) so the bot stops
    -- machine-gunning /ma when the server keeps refusing -- the
    -- bot was getting flagged as a spam risk before this guard.
    consecutive_unable     = {},

    -- Global UTC throttle state. global_utc_at is a list of recent
    -- UTC timestamps (any spell); we trim entries older than
    -- GLOBAL_UTC_WINDOW_SEC each time we touch it. When the window
    -- count crosses GLOBAL_UTC_THRESHOLD, global_cast_pause_until is
    -- bumped to now() + GLOBAL_UTC_BACKOFF_SEC and ALL casting is
    -- gated off (cast_on_target / cast cascade both check). Cleared
    -- on any successful complete_cast.
    global_utc_at          = {},
    global_cast_pause_until = 0.0,
    last_tick              = 0.0,
    tick_interval          = 0.35,
    is_casting             = false,
    cast_timeout_at        = 0.0,
    spell_lock_until       = 0.0,
    last_spell_sent        = nil,
    -- Same as last_spell_sent but preserves the ORIGINAL case the
    -- caller used (e.g. "Cure III" not "cure iii"). Needed by the
    -- failure-retry path to look up S.cooldowns[<raw>] for the
    -- spell being cast -- the cooldown table is keyed by the raw
    -- name passed to mark_spell_sent, not by normalized lowercase.
    last_spell_sent_raw    = nil,
    last_spell_target_name = nil,
    rest_toggle_at         = 0.0,
    rest_toggle_cd         = REST_TOGGLE_CD,
    stand_lock_until       = 0.0,
    -- Timestamp of the last /heal we sent to stand up out of rest.
    -- cast_on_target uses this with STAND_SETTLE_SEC to avoid casting
    -- during the stand-up animation window where the game still
    -- rejects spells even though Status has flipped off resting.
    last_stand_at          = 0.0,
    -- Diagnostic: timestamp of the last /ma we sent, plus the spell
    -- and target. Surfaced in the Debug Panel as "Last cast: <spell>
    -- -> <target> (X.Xs ago)" so unexplained cast failures can be
    -- cross-referenced against the inter-cast gap. The "prev_*" set
    -- holds the cast BEFORE the most recent one -- needed because at
    -- the moment of a fail, "time since the failing cast" is ~0 and
    -- useless; "time since the previous cast" is the real signal.
    last_cast_sent_at      = 0.0,
    last_cast_sent_spell   = '',
    last_cast_sent_target  = '',
    prev_cast_sent_at      = 0.0,
    prev_cast_sent_spell   = '',
    prev_cast_sent_target  = '',
    -- Pending-cast tracker for casttimes.txt logging (Debug-gated).
    -- Filled on mark_spell_sent, cleared on cast-complete match. If
    -- a fresh mark_spell_sent or a fail clears it without a match,
    -- the previous cast is logged as NEVER CONFIRMED -- which tells
    -- us whether the addon's cast_timeout is firing because the cast
    -- genuinely took longer than the timeout, or because the
    -- completion event was missed by parse_player_casts_name.
    pending_cast_spell     = '',
    pending_cast_target    = '',
    pending_cast_at        = 0.0,
    pending_cast_hasted    = false,
    -- Force Rest: timed mode. Clicking the button sets force_rest_until
    -- = now() + FORCE_REST_DURATION and the player is held in rest until
    -- that timestamp passes (auto-release in tick's rest-state block) or
    -- the user clicks again to cancel. Force Rest BEATS Disable Rest --
    -- if both are on, the timer runs to completion before Disable Rest
    -- can stand the player back up. Emergency override
    -- (FORCE_REST_OVERRIDE_*) still allows stand-up to cure a dying ally.
    force_rest             = false,
    force_rest_until       = 0.0,
    -- Auto Full Rest: user toggle. When true, once we've been resting
    -- AUTO_FULL_REST_SEC seconds and MP is >= AUTO_FULL_REST_MP_PCT, the
    -- non-cure stand paths are blocked so the tail end of the rest
    -- doesn't get interrupted. Emergency cure always fires regardless.
    auto_full_rest         = false,
    -- Disable Rest: when on, two things happen.
    --   1. Internally, rest_down() refuses to send /heal so the bot
    --      never INITIATES a rest. It does NOT yank the player out of
    --      a rest already in progress (Force Rest, manual /heal, etc.);
    --      those finish on their own terms.
    --   2. Externally, /heal disable true is sent so any other system
    --      managing auto-rest sees a consistent disabled state. Toggling
    --      off sends /heal disable false. This flag is the UI mirror.
    --   Force Rest beats this -- see rest_down for the precedence.
    disable_rest           = false,
    -- Timestamp we started the current rest; 0 while standing. Used by
    -- the Auto Full Rest gate above. Maintained by the rest-transition
    -- block at the top of tick().
    rest_started_at        = 0.0,
    -- Emergency cure HP threshold. Toggleable between 35 and 50 in the
    -- GUI. Party members at or below this HP% trigger the emergency
    -- cure path (and also change the member-row color band). Default 50.
    emergency_cure_threshold = EMERGENCY_CURE_THRESHOLD,

    -- DRG Healer mode: separate parallel cure path for DRG parties.
    -- See the constants block near the top for the trigger rules.
    -- drg_sustain_sec is the per-member sustain time (GUI slider,
    -- default DRG_SUSTAIN_DEFAULT). drg_low_since tracks per-name the
    -- timestamp a member first dipped at/below CFG.DRG_HEALER_THRESHOLD;
    -- cleared the moment they recover above it. Only updated while
    -- drg_healer_mode is on.
    drg_healer_mode        = false,
    drg_sustain_sec        = DRG_SUSTAIN_DEFAULT,
    drg_low_since          = {},
    -- Self-silence latch. Set true the tick we first detect silence on the
    -- player and cleared the tick we first see it gone. Used so the cast
    -- cascade short-circuit logs once per silence event instead of every
    -- tick. The actual cast block lives in cast_on_target + tick().
    silence_logged         = false,
    log                    = {},
    log_max                = 40,

    debuff_mob_sid         = 0,
    debuffs_done           = {},
    -- sid we've already logged a low-HP debuff abandon for. The abandon
    -- branch is re-entered every tick on a dying mob (mark_remaining_
    -- debuffs_done is a no-op for the recastable Dia, so get_next_debuff
    -- keeps handing Dia back), which spammed the log ~30-60x/sec. Log
    -- once per mob instead.
    abandon_logged_sid     = 0,

    -- "Just cleared" guard: holds the sid we most recently cleared
    -- via the "dead" branch in tick(). Reason: a mob that just hit
    -- 0 HP lingers in claimed_mobs for several seconds before the
    -- client despawns it (FFXI entity table doesn't get the despawn
    -- signal immediately). Without this guard, the very next tick
    -- re-picks the same corpse as a "new mob", resets debuffs_done,
    -- and the cascade spams Low MP / debuff-attempt logs until the
    -- corpse finally despawns. The pick path skips entries matching
    -- this sid; the guard is auto-cleared when that sid leaves
    -- claimed_mobs (so a future legitimate sid recycle for an
    -- entirely different mob isn't permanently blacklisted).
    recently_cleared_debuff_sid = 0,

    -- Manual-action detection: respect the player when they take control.
    was_resting            = false,  -- resting state on the previous tick
    manual_cast_until      = 0.0,    -- set from any "<player> starts casting"
                                     -- line, blocks rest_down until cast resolves

    all_claimed_targets    = {},

    -- Refresh: up to 6 named targets (self included via checkbox like Haste)
    refresh_enabled        = true,
    refresh_extras         = { '', '', '', '', '', '' },
    refresh_timers         = {},   -- [name] = expiry timestamp
    -- Priority: name-keyed set. If a target's name is in here, the
    -- target finder visits priority entries FIRST and casts on any
    -- priority target that's due before considering the regular list.
    refresh_priority       = {},

    -- Haste rotation: up to 6 named targets (dynamic boxes)
    haste_enabled          = true,
    haste_targets          = { '', '', '', '', '', '' },
    haste_timers           = {},   -- [name] = expiry timestamp
    -- Priority: name-keyed set. Same semantics as refresh_priority --
    -- priority members are scanned first and any due one wins over a
    -- non-priority due target. Unlike Refresh, self can be a target
    -- here and can be marked priority just like any other member.
    haste_priority         = {},

    -- Paralyna: auto-cure Paralysis p0->p5
    paralyna_enabled       = true,

    -- Silena: auto-cure Silence p0->p5
    silena_enabled         = true,

    -- Poisona: auto-cure Poison p0->p5
    poisona_enabled        = true,

    -- Blindna: auto-cure Blindness p0->p5
    blindna_enabled        = true,

    -- Stoneskin (self only). Off by default since not every job has it;
    -- the GUI toggle is hidden when stoneskin_usable() returns false.
    stoneskin_enabled      = false,

    -- Blink (self only). Off by default. Same hidden-when-unusable
    -- pattern as Stoneskin and Reraise.
    blink_enabled          = false,

    -- Phalanx (self only, RDM 33+). Off by default. Same hidden-when-
    -- unusable pattern as Stoneskin / Blink; the GUI toggle is hidden
    -- when phalanx_usable() returns false (non-RDM-capable jobs).
    phalanx_enabled        = false,

    -- ------------------------------------------------------------
    -- BLM SKILLUP system
    -- ------------------------------------------------------------
    -- Master toggle. When on, the bot casts the single selected
    -- skillup spell ONCE per claimed mob (mob HP must be above
    -- blm_skillup_min_hp_pct, our MP must be above
    -- blm_skillup_min_mp_pct). Default off so it doesn't fire
    -- accidentally in a real party.
    blm_skillup_enabled    = false,
    -- The ONE spell currently selected for skillup. Single-select
    -- in the GUI (radio-button group). Must be a key the SPELL_*
    -- lookup tables recognize -- the eight elementals registered
    -- in SPELL_CAST_TIME / SPELL_CD / SPELL_MP_COST / SPELL_LEVEL:
    --   'Stone' / 'Stone II' / 'Water' / 'Water II' /
    --   'Aero'  / 'Aero II'  / 'Blizzard' / 'Blizzard II'
    -- Empty string disables casting (same as flipping the master
    -- toggle off).
    blm_skillup_spell      = 'Stone',
    -- Mob HP% must be ABOVE this to fire. Default 50%. GUI slider.
    blm_skillup_min_hp_pct = 50,
    -- Player MP% must be AT OR ABOVE this to fire. Default 80% --
    -- skillup is purely optional, so we only spend MP on it when
    -- our pool is comfortable. GUI slider.
    blm_skillup_min_mp_pct = 80,
    -- Per-mob-per-spell completion tracking. Keys are
    --   "<server_id>:<spell_name>" -> true
    -- so each (mob, spell) pair only fires once. Cleared when the
    -- active claimed mob changes (mirrors debuffs_done's reset
    -- semantics at the same call sites).
    skillup_done           = {},

    -- Regen: up to 6 named targets (dynamic boxes)
    regen_enabled          = true,
    regen_targets          = { '', '', '', '', '', '' },

    -- Protect: up to 6 named targets, independent of Shell. Highest
    -- tier the player can cast is selected automatically. Recast
    -- trigger is buff absence in the StatusHandler cache (same
    -- buff-cache-as-truth pattern as Refresh/Haste/Regen). Timer
    -- is GUI-only.
    protect_enabled        = false,
    protect_targets        = { '', '', '', '', '', '' },
    protect_timers         = {},   -- [name] = expected wear-off ts (display only)

    -- Shell: same structure as Protect, independent target list.
    shell_enabled          = false,
    shell_targets          = { '', '', '', '', '', '' },
    shell_timers           = {},   -- [name] = expected wear-off ts (display only)

    -- Bar Elemental Spells (WHM AoE bar-elements, centered on caster).
    -- Six possible elements; the user picks ONE at a time via the GUI
    -- (radio-style: clicking the active element again deselects it).
    -- barelement_active holds the SPELL NAME of the currently selected
    -- element ('Barfira', 'Barwatera', etc.) or nil for "none / off".
    -- Target list is SHARED across elements -- switching element does
    -- NOT change who's covered. The coverage rule (per the user) is:
    --   * Cast fires when every checked member who still LACKS the
    --     active element's buff is within BARSPELL_RADIUS of the
    --     caster. A checked member who already has it doesn't gate
    --     anything; a checked member who lacks it but is out of range
    --     holds the cast (we'd miss them).
    --   * When held by an out-of-range needy member, echo their name(s)
    --     to chat every BARELEMENT_ECHO_SEC. barelement_echo_at
    --     throttles it.
    barelement_active      = nil,
    barelement_targets     = { '', '', '', '', '', '' },
    barelement_timers      = {},   -- [name] = display-only expiry (unused by cast logic)
    barelement_echo_at     = 0.0,  -- next allowed out-of-range echo timestamp

    -- Auto Move (close distance to checked party members while
    -- standing). Toggle + 6-slot name array, same pattern as
    -- refresh_extras/haste_targets/regen_targets. active_target
    -- holds whoever we're currently /follow'ing; last_send_at
    -- gates command re-issue so we don't spam /ta + /follow every
    -- tick (re-send every AUTO_MOVE_RESEND_SEC to recover from
    -- dropped follows, e.g. user nudged a movement key).
    auto_move_enabled         = false,
    auto_move_targets         = { '', '', '', '', '', '' },
    auto_move_active_target   = nil,
    auto_move_last_send_at    = 0.0,

    -- Last command pushed through send() (any whitelisted command,
    -- /ma + /heal + /follow + etc.) plus its timestamp. Used by
    -- the chat parser's "You cannot use that command while healing"
    -- detector to name the offending command in the rejection log
    -- so missing player_is_resting() gates can be tracked down.
    last_send_cmd             = nil,
    last_send_at              = 0.0,

    -- Movement detection (poll_player_movement, gates cast_on_target).
    -- last_pos_* nil on first tick; once seeded, every tick compares
    -- against current X/Y. last_movement_at is updated to now() any
    -- time the delta exceeds MOVEMENT_DEAD_ZONE_YALMS in either axis.
    -- cast_on_target then refuses while
    -- now() - last_movement_at < MOVEMENT_SETTLE_SEC.
    last_pos_x                = nil,
    last_pos_y                = nil,
    last_movement_at          = 0.0,
    regen_timers           = {},   -- [name] = expiry timestamp

    -- Reraise: auto-cast self at high MP if missing the buff. Default
    -- on because the user explicitly asked for an "I keep forgetting"
    -- safety net; defaulting off would defeat the purpose. Gated by
    -- CFG.RERAISE_MIN_MP_PCT and reraise_usable() (job/level check) before
    -- any cast attempt; gated further per-attempt by P.player_is_resting()
    -- so we don't break a rest just to maintain Reraise.
    reraise_enabled        = true,

    -- Cure: master switch + per-member exclusion lists.
    -- The GUI presents this as a two-row layout: a "Cure" row of
    -- per-member checkboxes (CHECKED = include in normal cure), and an
    -- "E.Cure" row of per-member checkboxes (CHECKED = include in
    -- emergency cure). The lists below are the *exclusion* form: a
    -- name in the list means the corresponding row's checkbox is
    -- UNCHECKED for that member.
    --
    -- cure_only_emergency = names excluded from NORMAL cure (member's
    -- "Cure" row checkbox is unchecked). Default empty = everyone gets
    -- normal cures. Use case: BRD with Minstrel-style gear that breaks
    -- on receiving heals -- uncheck their Cure box, leave E.Cure
    -- checked, so they're only touched in real emergencies.
    --
    -- emergency_cure_excluded = names excluded from EMERGENCY cure
    -- (member's "E.Cure" row checkbox is unchecked). Default empty =
    -- everyone is eligible for emergency cures. Use case: tank with
    -- strong self-heal who doesn't want emergency cures stealing hate
    -- when they have it under control.
    --
    -- Both lists are 6-slot name arrays, same shape as the other
    -- party-target arrays (refresh_extras, etc.) and pruned by
    -- Mob.prune_stale_party_targets() when party composition changes.
    --
    -- disable_cure: master kill switch. When TRUE, NO cures fire at
    -- all -- not normal, not emergency, not DRG-override. The per-
    -- member Cure / Emg.Cure columns below are the real granular
    -- control; this is just a panic button. Default false (cures
    -- enabled, per-member columns govern).
    disable_cure           = false,
    cure_timers            = {},   -- [name] = earliest time to cure again (post-cure suppression)
    cure_only_emergency    = { '', '', '', '', '', '' },
    -- brd_overcure = names enrolled in the Brd ANTI-OVERCURE path
    -- (member's "Brd" row checkbox is CHECKED). Unlike the other two
    -- lists this is INCLUSION (a name present = enrolled), because the
    -- Brd path is opt-in and off by default. A member enrolled here is
    -- removed from BOTH normal and emergency cure handling and is healed
    -- ONLY by the anti-overcure picker: tier chosen so estimated heal
    -- * (1 + BRD_OVERCURE_BUFFER) never exceeds their missing HP, with a
    -- live HP re-check before AND during the cast (kneel-cancel via
    -- /heal if they get topped off mid-cast). 6-slot name array, pruned
    -- by Mob.prune_stale_party_targets() like the others.
    brd_overcure           = { '', '', '', '', '', '' },
    -- In-flight Brd cure tracking for the mid-cast abort. When the bot
    -- fires a cure on a Brd-enrolled member, brd_cast_target is set to
    -- that member's name; each tick re-reads their HP and, if the cure
    -- now would overheal (they recovered), sends /heal to kneel-cancel
    -- the in-flight cast and clears this. Cleared on cast completion.
    brd_cast_target        = nil,
    brd_cast_missing_at    = 0,    -- missing HP recorded when the Brd cure was sent
    emergency_cure_excluded = { '', '', '', '', '', '' },

    -- Manual cast buttons
    dispel_pending         = false,
    sleep_pending          = false,
    bind_pending           = false,

    -- Debug display (updated in tick)
    debug_mob_hp           = 0,
    debug_mob_dist         = 9999,

    -- Party change detection. Signature built each tick from the sorted
    -- names of the currently active party members. When it changes, the
    -- run loop prunes target arrays (refresh_extras, haste_targets,
    -- regen_targets) of any name that's no longer a live party member.
    -- Members who are still present keep their checked state -- only
    -- ghosts are cleared. nil until first tick sees a stable party.
    last_party_sig         = nil,
}

local gui_state = {
    visible           = true,
    refresh_name_bufs = { {''}, {''}, {''}, {''}, {''}, {''} },
    haste_name_bufs   = { {''}, {''}, {''}, {''}, {''}, {''} },
    regen_name_bufs   = { {''}, {''}, {''}, {''}, {''}, {''} },
}

---------------------------------------------------------------------
-- HELPERS
---------------------------------------------------------------------

local function now()
    return os.clock()
end

local function sanitize_log_text(text)
    text = tostring(text or '')
    -- FFXI battle-log strings are peppered with control bytes for colors
    -- (0x1E, 0x1F) and auto-translate markers. Strip everything below
    -- 0x20 except tab — collapsing to a single space — before any
    -- whitespace normalization below. Without this, a line like
    -- "\x1E\x09Playername casts Refresh." never matches a regex that
    -- expects the string to start with "playername".
    text = text:gsub('[%z\001-\008\011-\031\127]', ' ')
    text = text:gsub('\t', ' ')
    text = text:gsub('\xe2\x80\x99', "'")
    text = text:gsub('`', "'")
    text = text:gsub('%s+', ' ')
    text = text:gsub('^%s+', '')
    text = text:gsub('%s+$', '')
    return text
end

local function normalize_action_name(name)
    if type(name) ~= 'string' then return nil end

    local s = sanitize_log_text(name):lower()
    s = s:gsub('%s+on%s+.+$', '')
    s = s:gsub(',%s+but%s+.+$', '')
    s = s:gsub('%s+but%s+.+$', '')
    s = s:gsub(',%s+and%s+.+$', '')
    s = s:gsub('%s+and%s+.+$', '')
    -- Strip period AND anything after it -- FFXI sometimes joins
    -- consecutive battle-log lines into a single text_in event, so a
    -- "Playername casts Haste. Playername gains the effect of haste. 1"
    -- arrives whole and the captured spell name is the entire tail.
    -- Cutting at the first period reduces it back to the bare spell.
    -- No FFXI spell name contains a period, so this is safe.
    s = s:gsub('%..*$', '')
    s = s:gsub('^%s+', '')
    s = s:gsub('%s+$', '')

    return (#s > 0) and s or nil
end

local function cprint(msg)
    AshitaCore:GetChatManager():QueueCommand(1, '/echo [bovinemage] ' .. tostring(msg))
end

local function cwarn(msg)
    AshitaCore:GetChatManager():QueueCommand(1, '/echo [bovinemage WARN] ' .. tostring(msg))
end

local function log(msg)
    if not S.debug then return end
    local line = string.format('[NM] %s', tostring(msg))
    table.insert(S.log, line)
    if #S.log > S.log_max then
        table.remove(S.log, 1)
    end
    cprint(msg)
end

-- Diagnostic log: writes to the in-memory S.log only, NEVER cprints
-- to chat. Use for high-frequency events (per-tick fail messages,
-- per-cast attempts) that would otherwise flood the chat window
-- when S.debug is on. Important events (errors, spam-guard trips,
-- state changes) should still use log() so they're visible in
-- chat where the user can react to them.
local function log_diag(msg)
    if not S.debug then return end
    local line = string.format('[NM] %s', tostring(msg))
    table.insert(S.log, line)
    if #S.log > S.log_max then
        table.remove(S.log, 1)
    end
end

local ALLOWED_CMDS = {
    '^/ma%s',
    '^/heal$',
    '^/addon%s+unload%s+bovinemage$',
    -- Healermode toggle buttons forward to LuAshitacast. Two exact
    -- patterns rather than a wildcard so the whitelist stays tight.
    '^/lac%s+fwd%s+healermode%s+on$',
    '^/lac%s+fwd%s+healermode%s+off$',
    -- Disable Rest checkbox routes through /heal disable so the auto-heal
    -- system stays in sync rather than the addon silently dropping
    -- /heal calls and fighting whatever else is managing rest state.
    '^/heal%s+disable%s+true$',
    '^/heal%s+disable%s+false$',
}

local function send(cmd_str)
    cmd_str = tostring(cmd_str or ''):match('^%s*(.-)%s*$')
    if cmd_str == '' then return end

    for _, pattern in ipairs(ALLOWED_CMDS) do
        if cmd_str:match(pattern) then
            log('CMD: ' .. cmd_str)
            -- Track last successful send for the "while healing"
            -- rejection diagnostic in the chat parser -- when the
            -- server rejects a command because we're resting, we
            -- cprint which command it was so the user (and we) can
            -- find the missing player_is_resting() gate.
            S.last_send_cmd = cmd_str
            S.last_send_at  = now()
            AshitaCore:GetChatManager():QueueCommand(1, cmd_str)
            return
        end
    end

    cwarn('BLOCKED (not whitelisted): ' .. cmd_str)
end

local function n(v)
    return tonumber(v) or 0
end

local function memory()
    return AshitaCore:GetMemoryManager()
end

local function party()
    local m = memory()
    return m and m:GetParty() or nil
end

local function entity()
    local m = memory()
    return m and m:GetEntity() or nil
end

local function dist_str(dist)
    if dist == nil or dist >= 9999 then
        return '---'
    end
    return string.format('%5.1fy', dist)
end

-- Ashita's imgui.Text* calls pass their string straight into ImGui's C printf,
-- so any '%' left in the final string gets re-parsed as a format spec and the
-- following chars can be silently eaten. Double up '%' to print it literally.
local function imsafe(text)
    return (text or ''):gsub('%%', '%%%%')
end

local function rest_toggle_ready()
    return now() >= (S.rest_toggle_at or 0)
end

-- Forward declarations for self-status helpers used by rest_down /
-- cast_on_target below. The bodies depend on self_has_buff which
-- lives further down in the file (after the buff-table block), so
-- they're declared here as forward-bound locals and the bodies are
-- assigned alongside the other self_* helpers further down.
local self_cannot_act
local self_has_active_dot

local function standing_locked()
    return now() < (S.stand_lock_until or 0)
end

-- True if either a bot-initiated cast is in flight OR we've seen a
-- "<player> starts casting ..." line recently and no completion/interrupt
-- has come through yet. Used to keep the bot from sending /heal mid-cast
-- when the player is manually casting something.
local function player_is_casting_anything()
    if S.is_casting then return true end
    return now() < (S.manual_cast_until or 0)
end

local function refresh_stand_lock(why)
    S.stand_lock_until = now() + STAY_STANDING_SEC
    log(string.format('[stand-lock] +%.1fs (%s)', STAY_STANDING_SEC, why or '?'))
end

-- Forward declaration: body is defined later in the file (after
-- get_member_distance, which it depends on). Returns true if the
-- Force Rest toggle currently permits standing up.
local force_rest_allows_stand

-- All cast-log helpers (fail logger -> failwhy.txt, cast-time
-- tracker -> casttimes.txt) live on one table so the bigger
-- functions in this file (tick, the event registration block)
-- only have to capture ONE upvalue instead of four. Hit Lua's
-- 60-upvalue-per-function ceiling otherwise. Bodies are assigned
-- further down where the file helpers they depend on are in scope.
local CastLog = {}

local function stand_up(reason, allow_force_rest_override)
    if not rest_toggle_ready() then
        return false
    end
    -- Force Rest: when the toggle is on, this function blocks
    -- unconditionally. The caller can opt into the emergency-cure
    -- override by passing allow_force_rest_override=true; today only
    -- the emergency cure path does that. Every other stand-up site
    -- (debuffs, auto-dispel, paralyna/silena/poisona, manual buttons)
    -- leaves the second parameter nil, so Force Rest reliably keeps
    -- the player resting through them. force_rest_allows_stand() then
    -- makes the final ally-HP / our-MP check inside the override
    -- branch, so even an emergency-cure caller can still be denied
    -- if no ally is actually below the override HP threshold or our
    -- MP is too low to cast.
    --
    -- Why the override is needed at all: if an ally drops below 20%
    -- while Force Rest is engaged, we want to break the rest to cure
    -- them; that's the whole point of allowing an override. The bug
    -- this guards against was the previous version letting EVERY
    -- caller ride that override -- meaning the addon would stand
    -- up to cast Dia/Paralyze/Slow/etc. on a mob just because some
    -- ally happened to be near death, instead of curing them.
    if S.force_rest then
        if not allow_force_rest_override then return false end
        if not force_rest_allows_stand() then return false end
    end
    S.rest_toggle_at = now() + (S.rest_toggle_cd or 3.0)
    refresh_stand_lock('stand_up')
    log(reason or 'Stand up')
    send(REST_CMD)
    S.last_stand_at = now()
    return true
end

local function rest_down(reason)
    -- Disable Rest: hard internal stop, UNLESS Force Rest is currently
    -- running its timer. Force Rest is a deliberate user commitment to
    -- rest for FORCE_REST_DURATION seconds and beats Disable Rest until
    -- it expires. /heal disable true is also sent externally on Disable
    -- Rest toggle (see GUI handler) so the auto-heal system is in sync.
    if S.disable_rest and not S.force_rest then
        return false
    end
    if standing_locked() then
        return false
    end
    if player_is_casting_anything() then
        return false
    end
    if not rest_toggle_ready() then
        return false
    end
    -- Refuse to rest when /heal will fail or be immediately broken:
    --   * sleep/stun/petrify/terror -- server rejects the command
    --   * poison/bio -- DoT damage instantly breaks the rest
    -- Dead state is already enforced at the top of tick() (the only
    -- caller of rest_down), so no need to re-check it here. Without
    -- these gates the bot loops "rest -> server rejects / DoT
    -- breaks -> retry" until the underlying state clears.
    if self_cannot_act() then
        return false
    end
    if self_has_active_dot() then
        return false
    end
    S.rest_toggle_at = now() + (S.rest_toggle_cd or 3.0)
    log(reason or 'Rest down')
    send(REST_CMD)
    return true
end

---------------------------------------------------------------------
-- MOB DEBUFF TRACKER
-- Mirrors the DebuffHandler pattern from xitools / bovinebattle.
--
-- Self buffs      -> GetPlayer():GetBuffs()       (Player manager  - reliable)
-- Party buffs     -> party:GetMemberBuff(slot,i)  (Party manager   - reliable)
-- Mob debuffs     -> action / message packets     (packet-tracked  - reliable)
---------------------------------------------------------------------

-- Build fast-lookup sets from message-ID lists (mirrors DebuffHandler constants)
local function make_msg_set(ids)
    local s = {}
    for _, v in ipairs(ids) do s[v] = true end
    return s
end

local MOB_STATUS_ON_MSG  = make_msg_set({160,164,166,186,194,203,205,230,236,266,267,268,269,237,271,272,277,278,279,280,319,320,375,412,645,754,755,804})
local MOB_STATUS_OFF_MSG = make_msg_set({206,64,159,168,204,321,322,341,342,343,344,350,378,531,647,805,806})
local MOB_DEATH_MSG      = make_msg_set({6,20,97,113,406,605,646})
local MOB_SPELL_DMG_MSG  = make_msg_set({2,252,264,265})

-- Spell IDs -> { buff_id, duration_sec } for every debuff this addon may cast.
-- Used by the packet tracker to record when a debuff lands on a mob.
-- Mob debuff tracking — packet logic ported directly from HXUI's
-- debuffhandler.lua ApplyMessage / ClearMessage. Spell-id durations are
-- HXUI's values per-spell rather than a single "60s for everything
-- Dia-like" lookup, so:
--   * Dia I/II/III and Bio I/II/III each get their correct DoT durations
--     (60 / 120 / 150) AND clear each other from the tracker on cast
--     (Dia and Bio share the slot on the mob server-side; this matches)
--   * Slow/Slow II 180s, Paralyze/Paralyze II 120s, Gravity 120s,
--     Blind/Blind II 180s, Silence/Silencega 120s, Sleep family 90s,
--     Bind 60s, Stun 5s, Poison range 120s, elemental DoTs (Burn /
--     Frost / Choke / Rasp / Shock / Drown) 120s
--   * Anything outside the recognised spell range gets a 5-minute
--     fallback so unknown statuses still age out
-- buff_id always comes from ability.Param (the server tells us which
-- status landed); only if Param is missing do we skip the entry.

-- [server_id][buff_id] = expiry_os_time
local mob_debuffs = {}

-- [server_id][buff_id] = os_time when the buff was first observed.
-- Used by auto-dispel to wait CFG.AUTO_DISPEL_DELAY seconds before firing
-- so the buff's effect has time to actually take hold on the mob before
-- we strip it. Cleared alongside mob_debuffs on wear-off / death / zone.
Mob.mob_buff_seen_at = {}

-- Called for every action packet. Records status effects that land on any target.
local function mob_debuff_apply(ap)
    if not ap then return end
    local spell_id = tonumber(ap.Param) or 0
    local t_now    = os.time()

    for _, target in pairs(ap.Targets or {}) do
        local tid = tonumber(target.Id) or 0
        if tid > 0 then
            for _, ability in pairs(target.Actions or {}) do
                local msg = tonumber(ability.Message) or 0
                mob_debuffs[tid] = mob_debuffs[tid] or {}
                Mob.mob_buff_seen_at[tid] = Mob.mob_buff_seen_at[tid] or {}

                -- Bio / Dia: spell-damage message carries the DoT.
                -- Dia (23/24/25/33) uses buff_id 134, Bio (230/231/232)
                -- uses buff_id 135. They overwrite each other on the
                -- mob -- when one lands the other comes off, so we
                -- clear the opposite slot in our tracker (matches
                -- HXUI's behaviour and the server's).
                if ap.Type == 4 and MOB_SPELL_DMG_MSG[msg] then
                    local expiry = nil
                    if spell_id == 23 or spell_id == 33 or spell_id == 230 then
                        expiry = t_now + 60
                    elseif spell_id == 24 or spell_id == 231 then
                        expiry = t_now + 120
                    elseif spell_id == 25 or spell_id == 232 then
                        expiry = t_now + 150
                    end

                    if spell_id == 23 or spell_id == 24 or spell_id == 25 or spell_id == 33 then
                        -- Dia: set 134, clear 135 (Bio)
                        mob_debuffs[tid][134] = expiry
                        mob_debuffs[tid][135] = nil
                        Mob.mob_buff_seen_at[tid][135] = nil
                        if expiry and not Mob.mob_buff_seen_at[tid][134] then
                            Mob.mob_buff_seen_at[tid][134] = t_now
                        end
                    elseif spell_id == 230 or spell_id == 231 or spell_id == 232 then
                        -- Bio: set 135, clear 134 (Dia)
                        mob_debuffs[tid][134] = nil
                        mob_debuffs[tid][135] = expiry
                        Mob.mob_buff_seen_at[tid][134] = nil
                        if expiry and not Mob.mob_buff_seen_at[tid][135] then
                            Mob.mob_buff_seen_at[tid][135] = t_now
                        end
                    end

                elseif MOB_STATUS_ON_MSG[msg] then
                    local buff_id = tonumber(ability.Param)
                    if buff_id then
                        -- Per-spell duration table (HXUI values).
                        local dur
                        if     spell_id == 58  or spell_id == 80  then dur = 120  -- Paralyze / Paralyze II
                        elseif spell_id == 56  or spell_id == 79  then dur = 180  -- Slow / Slow II
                        elseif spell_id == 216                    then dur = 120  -- Gravity
                        elseif spell_id == 254 or spell_id == 276 then dur = 180  -- Blind / Blind II
                        elseif spell_id == 59  or spell_id == 359 then dur = 120  -- Silence / Silencega
                        elseif spell_id == 253 or spell_id == 259
                            or spell_id == 273 or spell_id == 274 then dur = 90   -- Sleep / Sleep II / Sleepga / Sleepga II
                        elseif spell_id == 258 or spell_id == 362 then dur = 60   -- Bind
                        elseif spell_id == 252                    then dur = 5    -- Stun
                        elseif spell_id >= 220 and spell_id <= 229 then dur = 120 -- Poison / Poison II range
                        elseif spell_id == 235 or spell_id == 236
                            or spell_id == 237 or spell_id == 238
                            or spell_id == 239 or spell_id == 240 then dur = 120  -- Burn/Frost/Choke/Rasp/Shock/Drown
                        else                                            dur = 300 -- Unknown -- 5-minute fallback (HXUI)
                        end
                        mob_debuffs[tid][buff_id] = t_now + dur
                        if not Mob.mob_buff_seen_at[tid][buff_id] then
                            Mob.mob_buff_seen_at[tid][buff_id] = t_now
                        end
                    end

                elseif MOB_STATUS_OFF_MSG[msg] then
                    -- Buff removed via action (Dispel landing on the
                    -- mob, debuff being overwritten, Erase from the
                    -- mob's own healer, etc.). ability.Param carries
                    -- the buff_id that came off; clear our tracker
                    -- entry so we don't keep reporting it active.
                    -- Same path as the message-packet ClearMessage
                    -- below but fired from the action packet.
                    local rm = tonumber(ability.Param)
                    if rm then
                        mob_debuffs[tid][rm] = nil
                        Mob.mob_buff_seen_at[tid][rm] = nil
                    end
                end
            end
        end
    end
end

-- Called for every message packet. Clears debuffs that wore off or mob died.
local function mob_debuff_clear(mp)
    if not mp then return end
    local tid   = tonumber(mp.target)  or 0
    local msg   = tonumber(mp.message) or 0
    local param = tonumber(mp.param)   or nil

    if MOB_DEATH_MSG[msg] then
        mob_debuffs[tid]      = nil
        Mob.mob_buff_seen_at[tid] = nil
        -- Priority-Silence "have we already cast on this mob" flag.
        -- Cleared on death so a respawn (new sid) gets a fresh cast;
        -- if reapply is off and this same mob revives somehow, the
        -- one-shot semantics still hold because we re-arm only when
        -- the OLD sid is the one that died.
        if S.silence_done_for_sid == tid then
            S.silence_done_for_sid = 0
        end
        -- Packet-level death signal. The entity cache's HPPercent often
        -- lags real death by a tick or two -- the death message
        -- arrives instantly but ent.HPPercent stays at e.g. 50% until
        -- FFXI's client gets around to updating it. Drop the row HERE
        -- on the authoritative death signal so the dead-check's "gone"
        -- branch fires next tick before any stand-up is considered.
        -- Rows are bare flags (HXUI mirror) so we look up by entity
        -- sid rather than a stored row.server_id.
        for idx, _ in pairs(S.all_claimed_targets) do
            local ok, ent = pcall(GetEntity, idx)
            if ok and ent then
                local esid = tonumber(ent.ServerId or ent.ServerID or ent.Id or ent.ID or 0) or 0
                if esid == tid then
                    S.all_claimed_targets[idx] = nil
                    break
                end
            end
        end
    elseif MOB_STATUS_OFF_MSG[msg] and mob_debuffs[tid] and param then
        mob_debuffs[tid][param] = nil
        if Mob.mob_buff_seen_at[tid] then
            Mob.mob_buff_seen_at[tid][param] = nil
        end
    end
end

-- Returns true if server_id currently has buff_id (tracked via packets, not expired).
local function mob_has_debuff(server_id, buff_id)
    local entry = mob_debuffs[server_id]
    if not entry then return false end
    local expiry = entry[buff_id]
    return expiry ~= nil and expiry > os.time()
end

---------------------------------------------------------------------

-- Builds the current debuff rotation from per-debuff state flags.
-- Called every tick that reaches the debuff block; cheap (at most 3
-- small tables allocated). Dia / Dia II / Bio / Bio II all share
-- key='dia' so the tracking (debuffs_done, mob_has_it, packet tracker)
-- treats them as one slot regardless of tier -- mirrors the HorizonXI
-- behavior where Dia and Bio overwrite each other on the mob.
-- Bio family uses buff_id=135 (status 'bio') instead of 134 ('dia')
-- so the per-tier mob_has_it check fires on the correct status ID.
--
-- State inputs:
--   S.dia_tier         0 = off, 1 = Dia, 2 = Dia II, 3 = Bio, 4 = Bio II
--   S.paralyze_enabled boolean
--   S.slow_enabled     boolean
--   S.blind_enabled    boolean
local function active_debuff_rotation()
    local rot = {}
    if S.dia_tier == 1 then
        rot[#rot+1] = { spell = 'Dia',    key = 'dia', buff_id = 134, recast_sec = 20 }
    elseif S.dia_tier == 2 then
        rot[#rot+1] = { spell = 'Dia II', key = 'dia', buff_id = 134, recast_sec = 20 }
    elseif S.dia_tier == 3 then
        rot[#rot+1] = { spell = 'Bio',    key = 'dia', buff_id = 135, recast_sec = 20 }
    elseif S.dia_tier == 4 then
        rot[#rot+1] = { spell = 'Bio II', key = 'dia', buff_id = 135, recast_sec = 20 }
    end
    if S.paralyze_enabled then
        rot[#rot+1] = { spell = 'Paralyze', key = 'paralyze', buff_id = 4 }
    end
    if S.slow_enabled then
        rot[#rot+1] = { spell = 'Slow', key = 'slow', buff_id = 13 }
    end
    if S.blind_enabled then
        rot[#rot+1] = { spell = 'Blind', key = 'blind', buff_id = 5 }
    end
    return rot
end

-- cur_level is passed in by the caller (tick()) because P.player_level() is
-- defined later in the file as a local — we cannot safely call it from here.
function Mob.get_next_debuff(cur_level)
    cur_level = tonumber(cur_level) or 0
    -- The old multi-mob Dia gate lived here: Dia was skipped whenever
    -- more than one mob was claimed within 25 yalms, because <bt> could
    -- drift between nearby mobs and land the cast on the wrong one.
    -- Debuff casts now go out as a 0x01A action packet naming
    -- S.debuff_mob_sid explicitly, so the cast always lands on the mob
    -- the cascade actually verified and cannot drift. Gate removed --
    -- Dia now fires with any number of mobs claimed, same as
    -- Paralyze/Slow.
    for _, d in ipairs(active_debuff_rotation()) do
        -- Silent level check using the caller-supplied current level.
        local min_lv = SPELL_LEVEL[d.spell] or 0
        if spell_ready(d.spell) and cur_level >= min_lv then
            local mob_has_it = (S.debuff_mob_sid ~= 0)
                           and mob_has_debuff(S.debuff_mob_sid, d.buff_id)

            -- Packet tracker is the source of truth: only mark a debuff as
            -- "done on this mob" when we see it land. This prevents Dia being
            -- silently skipped after an interrupted / resisted cast, which
            -- the previous send-based optimistic flag caused.
            if mob_has_it and not S.debuffs_done[d.key] then
                log(string.format('%s confirmed on mob', d.spell))
                S.debuffs_done[d.key] = true
            end

            -- Recastable (Dia/Dia II with reapply enabled): keep re-casting
            -- whenever the mob does not have the debuff. SPELL_CD throttles
            -- retries so we don't spam when a cast is in flight.
            local recastable = d.recast_sec ~= nil and S.debuff_reapply_enabled

            if recastable then
                if not mob_has_it then
                    return d
                end
            else
                -- One-shot per mob: keep trying until the packet tracker
                -- confirms it landed.
                if not S.debuffs_done[d.key] and not mob_has_it then
                    return d
                end
            end
        end
    end
    return nil
end

-- Mark every possible debuff key as done for this mob (used when mob
-- drops below CFG.DEBUFF_MIN_MOBHP). Use a static key list, not the active
-- rotation, so toggling a debuff on mid-mob after abandon does not cause
-- it to suddenly fire on an almost-dead mob.
function Mob.mark_remaining_debuffs_done()
    S.debuffs_done.dia      = true
    S.debuffs_done.paralyze = true
    S.debuffs_done.slow     = true
    S.debuffs_done.blind    = true
end

-- Returns the configured skillup spell + its tracking key for the
-- given claimed mob, or nil if it shouldn't fire. The caller has
-- already checked the master toggle + HP/MP thresholds; this only
-- enforces the per-spell guards:
--   1. A spell IS selected (S.blm_skillup_spell non-empty)
--   2. Hasn't been cast on this mob yet (skillup_done key)
--   3. Off cooldown (spell_ready)
--   4. Player meets the level requirement (spell_usable)
--   5. Player has the MP for the cast (>= SPELL_MP_COST)
--
-- "Cast once per mob" is enforced via skillup_done, keyed by
-- "<server_id>:<spell>". The done-table is cleared at the same
-- sites debuffs_done is cleared (new mob, mob death, zone change),
-- so a fresh mob always gets a fresh cast.
function Mob.get_next_skillup_spell(server_id)
    if not S.blm_skillup_enabled then return nil end
    if not server_id or server_id == 0 then return nil end
    local spell = S.blm_skillup_spell
    if not spell or spell == '' then return nil end

    local key = tostring(server_id) .. ':' .. spell
    if S.skillup_done[key] then return nil end
    if not spell_ready(spell) then return nil end
    if not spell_usable(spell) then return nil end
    if P.player_mp() < (SPELL_MP_COST[spell] or 0) then return nil end

    return spell, key
end

---------------------------------------------------------------------
-- PLAYER STATE
---------------------------------------------------------------------

local function get_player_entity()
    local ok, p = pcall(GetPlayerEntity)
    return (ok and p) or nil
end

-- Polls player X/Y each tick and updates S.last_movement_at whenever
-- the position has changed by more than MOVEMENT_DEAD_ZONE_YALMS.
-- Called from the top of tick() so the timestamp is fresh before
-- any cast attempts. cast_on_target then gates on
-- (now() - last_movement_at) >= MOVEMENT_SETTLE_SEC, which means a
-- /ma will never go out while the player is mid-step regardless of
-- the cause (Auto Move /follow, manual WASD, knockback, bump from
-- an ally, etc.). Failure modes (no entity, missing coord fields)
-- silently skip the update -- next tick will re-seed.
local function poll_player_movement()
    local p = get_player_entity()
    if not p then return end
    local x = tonumber(p.X or p.x)
    local y = tonumber(p.Y or p.y)
    if not x or not y then return end
    if S.last_pos_x then
        local dx = x - S.last_pos_x
        local dy = y - S.last_pos_y
        if math.abs(dx) > MOVEMENT_DEAD_ZONE_YALMS
           or math.abs(dy) > MOVEMENT_DEAD_ZONE_YALMS then
            S.last_movement_at = now()
        end
    end
    S.last_pos_x = x
    S.last_pos_y = y
end

function P.player_is_resting()
    local p = get_player_entity()
    if not p then return false end
    return n(p.Status or p.status or p.CurrentStatus) == 33
end

-- Returns true if the player's entity status is "engaged" (Status==1)
-- AND, if idx is supplied, the engaged target index matches idx.
-- Used to gate mob debuff casts on <bt>: <bt> only resolves to an
-- entity when we're actually engaged, so firing /ma "Dia" "<bt>" while
-- idle just queues a no-op command (no MP deducted, no chat reply, no
-- cast-complete event) and the addon then sits through a 6s cast
-- timeout for nothing.
local function player_is_engaged_on(idx)
    local p = get_player_entity()
    if not p then return false end
    local status = n(p.Status or p.status or p.CurrentStatus)
    if status ~= 1 then return false end
    if idx == nil then return true end
    local tidx = n(p.TargetIndex or p.targetindex or 0)
    return tidx ~= 0 and tidx == idx
end

function P.player_is_dead()
    local p = get_player_entity()
    if p then
        local status = n(p.Status or p.status or p.CurrentStatus)
        -- Status 2 is the standard FFXI "dead" code, same convention as
        -- P.player_is_resting() above (status 33 = resting).
        if status == 2 then return true end
    end
    -- Belt-and-suspenders fallback for the brief window where HP has hit
    -- 0 but the entity Status field hasn't yet flipped to 2. The HP value
    -- comes from the party manager (slot 0 = self) and the Status field
    -- comes from the entity manager; they're updated by different packet
    -- paths and can disagree for ~one tick at the moment of death. This
    -- catches that window so we don't fire a cast on a corpse.
    --
    -- pcall guards against the party manager being unavailable mid-zone
    -- (entries briefly null out during zone transitions). When the party
    -- read fails or is unpopulated we conservatively return false: "no
    -- data" is not the same as "dead", and treating it as such would
    -- auto-stop the bot every time the player zones.
    local pm = party()
    if pm then
        local ok, hpp = pcall(function() return pm:GetMemberHPPercent(0) end)
        if ok and tonumber(hpp) == 0 then
            -- Cross-check absolute HP. During zone transitions HPPercent
            -- can briefly return 0 before the manager has populated; if
            -- absolute HP also reads 0, the zero is real (we're dead),
            -- not "data not yet loaded".
            local ok2, hp = pcall(function() return pm:GetMemberHP(0) end)
            if ok2 and tonumber(hp) == 0 then
                return true
            end
        end
    end
    return false
end

function P.player_mp_pct()
    local pm = party()
    if not pm then return 100 end
    local ok, v = pcall(function() return pm:GetMemberMPPercent(0) end)
    return (ok and tonumber(v)) or 100
end

function P.player_mp()
    local pm = party()
    if not pm then return 0 end
    local ok, v = pcall(function() return pm:GetMemberMP(0) end)
    return (ok and tonumber(v)) or 0
end

function P.player_name()
    local pm = party()
    if not pm then return '' end
    local ok, v = pcall(function() return pm:GetMemberName(0) end)
    return (ok and tostring(v or '')) or ''
end

-- Returns the player's current effective job level (reflects level sync).
-- Tries party slot 0 first; falls back to Player manager for solo play.
function P.player_level()
    local pm = party()
    if pm then
        local ok, v = pcall(function() return pm:GetMemberMainJobLevel(0) end)
        local lv = (ok and tonumber(v)) or 0
        if lv > 0 then return lv end
    end
    local m = memory()
    if not m then return 0 end
    local ok2, pl = pcall(function() return m:GetPlayer() end)
    if not ok2 or not pl then return 0 end
    local ok3, v2 = pcall(function() return pl:GetMainJobLevel() end)
    return (ok3 and tonumber(v2)) or 0
end

-- Returns main job ID number (e.g. 5 = RDM, 3 = WHM).
local function player_main_job_id()
    local m = memory()
    if not m then return 0 end
    local ok, pl = pcall(function() return m:GetPlayer() end)
    if not ok or not pl then return 0 end
    local ok2, v = pcall(function() return pl:GetMainJob() end)
    return (ok2 and tonumber(v)) or 0
end

-- Returns sub job ID number.
local function player_sub_job_id()
    local m = memory()
    if not m then return 0 end
    local ok, pl = pcall(function() return m:GetPlayer() end)
    if not ok or not pl then return 0 end
    local ok2, v = pcall(function() return pl:GetSubJob() end)
    return (ok2 and tonumber(v)) or 0
end

-- Returns sub job level.
local function player_sub_job_level()
    local m = memory()
    if not m then return 0 end
    local ok, pl = pcall(function() return m:GetPlayer() end)
    if not ok or not pl then return 0 end
    local ok2, v = pcall(function() return pl:GetSubJobLevel() end)
    return (ok2 and tonumber(v)) or 0
end

local JOB_NAMES = {
    [1]='WAR',[2]='MNK',[3]='WHM',[4]='BLM',[5]='RDM',[6]='THF',
    [7]='PLD',[8]='DRK',[9]='BST',[10]='BRD',[11]='RNG',[12]='SAM',
    [13]='NIN',[14]='DRG',[15]='SMN',[16]='BLU',[17]='COR',[18]='PUP',
    [19]='DNC',[20]='SCH',[21]='GEO',[22]='RUN',
}

-- Returns display string like "RDM/WHM"
local function player_job_str()
    local mjob = JOB_NAMES[player_main_job_id()] or '---'
    local sjob = JOB_NAMES[player_sub_job_id()] or '---'
    return mjob .. '/' .. sjob
end

-- Returns true if player can cast Haste given their job and level.
-- RDM main: level 48+   WHM main: level 40+
local function haste_usable()
    local job = player_main_job_id()
    local lv  = P.player_level()
    if job == JOB_RDM and lv >= 48 then return true end
    if job == JOB_WHM and lv >= 40 then return true end
    return false
end

-- Returns true if player can cast Refresh (RDM level 41+).
local function refresh_usable()
    return player_main_job_id() == JOB_RDM and P.player_level() >= 41
end

-- Forward declarations so protect_usable / shell_usable can reference
-- the highest-tier walkers defined below.
local highest_protect_tier
local highest_shell_tier

-- Returns true if player can cast at least Protect I. WHM/RDM 7+, PLD 10+.
-- Sub-job paths covered by spell_usable's level check at cast time.
local function protect_usable()
    return highest_protect_tier() ~= nil
end

-- Returns true if player can cast at least Shell I. WHM/RDM 17+, PLD 20+.
local function shell_usable()
    return highest_shell_tier() ~= nil
end

-- Per-job, per-tier MAIN job level thresholds. Reads sync-aware via
-- P.player_level() (GetMemberMainJobLevel(0)). Honors PLD-specific
-- progression: PLD lags WHM/RDM by 3-10 levels and DOES NOT LEARN
-- Shell IV at all on HorizonXI (the wiki's Shell IV page omits PLD
-- from the job list). nil entry => the job cannot learn that tier.
--
-- Sub-job paths intentionally not supported here, matching
-- refresh_usable / haste_usable convention -- the bot's primary use
-- case is a main-job RDM/WHM/PLD healer.
local PROTECT_TIER_JOB_LEVEL = {
    [JOB_WHM] = { [1] = 7,  [2] = 27, [3] = 47, [4] = 63 },
    [JOB_RDM] = { [1] = 7,  [2] = 27, [3] = 47, [4] = 63 },
    [JOB_PLD] = { [1] = 10, [2] = 30, [3] = 50, [4] = 70 },
}
local SHELL_TIER_JOB_LEVEL = {
    [JOB_WHM] = { [1] = 17, [2] = 37, [3] = 57, [4] = 68 },
    [JOB_RDM] = { [1] = 17, [2] = 37, [3] = 57, [4] = 68 },
    [JOB_PLD] = { [1] = 20, [2] = 40, [3] = 60, [4] = nil }, -- PLD: no Shell IV on Horizon
}

-- Returns the highest Protect/Shell tier the player can currently cast,
-- or nil if none. Job-aware AND tier-aware -- a PLD at L65 walking the
-- Shell ladder gets 'Shell III' (since [4]=nil for PLD), and an RDM at
-- L65 sync gets 'Shell III' too (since [4]=68 > 65). Silent: no
-- spell_usable() log spam on every tick. Single source of truth for
-- tier picking AND for the *_usable() hide-UI predicates above.
-- Plain `function name()` assignment (no `local`) so it binds to the
-- local upvalue declared above, not a new global.
function highest_protect_tier()
    local thr = PROTECT_TIER_JOB_LEVEL[player_main_job_id()]
    if not thr then return nil end
    local lv = P.player_level()
    if thr[4] and lv >= thr[4] then return 'Protect IV'  end
    if thr[3] and lv >= thr[3] then return 'Protect III' end
    if thr[2] and lv >= thr[2] then return 'Protect II'  end
    if thr[1] and lv >= thr[1] then return 'Protect'     end
    return nil
end
function highest_shell_tier()
    local thr = SHELL_TIER_JOB_LEVEL[player_main_job_id()]
    if not thr then return nil end
    local lv = P.player_level()
    if thr[4] and lv >= thr[4] then return 'Shell IV'  end
    if thr[3] and lv >= thr[3] then return 'Shell III' end
    if thr[2] and lv >= thr[2] then return 'Shell II'  end
    if thr[1] and lv >= thr[1] then return 'Shell'     end
    return nil
end

-- Returns true if player can cast Reraise. Reraise unlocks at WHM 25,
-- so two paths qualify:
--   - main job WHM at level 25+
--   - any main job with WHM as sub at sub-level 25+ (which means main
--     level 50+, since sub level is capped at half of main)
-- The level check inside spell_usable() ('Reraise' = 25) is automatically
-- satisfied for both cases, so the only thing this helper has to enforce
-- is the JOB constraint.
local function reraise_usable()
    if player_main_job_id() == JOB_WHM and P.player_level() >= 25 then
        return true
    end
    if player_sub_job_id() == JOB_WHM and player_sub_job_level() >= 25 then
        return true
    end
    return false
end

-- Stoneskin: WHM 28, RDM 34, SCH 44, RUN 55 (HorizonXI wiki).
-- Subjob level caps at half of main, so a sub at the required level
-- means main is high enough that spell_usable's level check passes;
-- this helper only enforces JOB. SCH/RUN are not in this addon's
-- job set yet -- if you main one of them, add a branch here.
local function stoneskin_usable()
    local function ok(job, lv)
        if job == JOB_WHM and lv >= 28 then return true end
        if job == JOB_RDM and lv >= 34 then return true end
        return false
    end
    if ok(player_main_job_id(), P.player_level()) then return true end
    if ok(player_sub_job_id(),  player_sub_job_level()) then return true end
    return false
end

-- Blink: WHM 19, RDM 23, SCH 29, RUN 35 (HorizonXI wiki). White
-- magic on Horizon, not the BLU/NIN spell elsewhere -- same
-- subjob-via-sub-level pattern as stoneskin_usable.
local function blink_usable()
    local function ok(job, lv)
        if job == JOB_WHM and lv >= 19 then return true end
        if job == JOB_RDM and lv >= 23 then return true end
        return false
    end
    if ok(player_main_job_id(), P.player_level()) then return true end
    if ok(player_sub_job_id(),  player_sub_job_level()) then return true end
    return false
end

-- Phalanx: RDM 33 only (HorizonXI wiki). PLD 77 / RUN 68 are out of
-- reach at the 75-cap, so RDM is the only realistically castable job.
-- Same subjob-via-sub-level pattern as stoneskin_usable / blink_usable.
local function phalanx_usable()
    local function ok(job, lv)
        if job == JOB_RDM and lv >= 33 then return true end
        return false
    end
    if ok(player_main_job_id(), P.player_level()) then return true end
    if ok(player_sub_job_id(),  player_sub_job_level()) then return true end
    return false
end

-- Bar-element AoE spells (WHM-native). Lowest tier is Barfira at WHM 5,
-- which sets the floor for whether the panel is meaningful at all. The
-- per-spell SPELL_LEVEL gate inside cast_on_target enforces the higher
-- thresholds for the other elements (Barthundra/Barwatera at 9, etc.),
-- so a sub-WHM 5 player sees the panel but only Barfira/Barblizzara are
-- realistically castable until their level climbs.
local function barelement_usable()
    local function ok(job, lv)
        if job == JOB_WHM and lv >= 5 then return true end
        return false
    end
    if ok(player_main_job_id(), P.player_level()) then return true end
    if ok(player_sub_job_id(),  player_sub_job_level()) then return true end
    return false
end

-- Returns true if the local player currently has the given buff ID active.
-- ---------------------------------------------------------------
-- PARTY BUFF LOOKUPS
-- Self buffs          -> GetPlayer():GetBuffs()       (Player manager)
-- Party member buffs  -> StatusHandler.get_member_status(server_id)
--                        (StatusHandler keeps itself current from
--                         packet 0x076 and from memory reads.)
-- ---------------------------------------------------------------

-- Returns true if the party member with the given server ID has buff_id active.
local function member_has_buff(server_id, buff_id)
    if not server_id or server_id == 0 then return false end
    if not StatusHandler or type(StatusHandler.get_member_status) ~= 'function' then
        return false
    end
    local buffs = StatusHandler.get_member_status(server_id)
    if type(buffs) ~= 'table' then return false end
    for i = 1, #buffs do
        if tonumber(buffs[i] or -1) == buff_id then return true end
    end
    return false
end

-- Returns true if the local player currently has the given buff ID active.
-- Ashita's GetPlayer():GetBuffs() returns a C array wrapped as userdata, not
-- a Lua table — we accept either, we don't type-check it.
-- StatusHandler is not used here: its cache only has the 5 OTHER party
-- members (packet 0x076 doesn't carry self's buffs), so self always
-- comes straight from the player manager.
local function self_has_buff(buff_id)
    local m = memory()
    if not m then return false end
    local ok, pmgr = pcall(function() return m:GetPlayer() end)
    if not ok or not pmgr then return false end
    local ok2, buffs = pcall(function() return pmgr:GetBuffs() end)
    if not ok2 or not buffs then return false end
    local ok3, nb = pcall(function() return #buffs end)
    if not ok3 or not nb or nb <= 0 then return false end
    for i = 1, nb do
        local ok4, v = pcall(function() return buffs[i] end)
        if ok4 and tonumber(v or -1) == buff_id then return true end
    end
    return false
end

-- Returns true if the local player currently has Silence. Thin wrapper
-- around self_has_buff so call sites read clearly and so we have one
-- place to extend if we ever want to also treat Mute (29) or other
-- cast-blocking effects the same way. Kept separate from the party-side
-- BUFF.SILENCE check used by Silena targeting -- party silence drives
-- Silena casts on others, self silence blocks casts entirely.
local function self_is_silenced()
    return self_has_buff(BUFF.SILENCE)
end

-- True if the player currently has any action-blocking status. FFXI
-- refuses /ma and /heal commands while any of these are active and
-- the bot otherwise burns the attempts in a tight loop (cast lock
-- gets set, times out, retries, repeats). Centralized here so any
-- caller -- cast_on_target, rest_down, future job-ability paths --
-- shares one definition of "cannot do anything right now".
self_cannot_act = function()
    return self_has_buff(BUFF.SLEEP)
        or self_has_buff(BUFF.SLEEP2)
        or self_has_buff(BUFF.STUN)
        or self_has_buff(BUFF.PETRIFY)
        or self_has_buff(BUFF.TERROR)
end

-- True if the player has an HP-draining DoT. Used by rest_down to
-- skip /heal while Poison or Bio is active -- resting through DoTs
-- wastes ticks (the incoming damage cancels or counter-balances the
-- HP regen) and any tick of damage will drop us out of /heal anyway.
self_has_active_dot = function()
    return self_has_buff(BUFF.POISON) or self_has_buff(BUFF.BIO)
end

-- Fast Cast / Haste / effective time helpers, bundled into one
-- table so call sites (mark_spell_sent, parse_player_starts_casting)
-- capture a single upvalue instead of four. Same upvalue-pressure
-- mitigation as CastLog. Tiers per the HorizonXI wiki Fast_Cast
-- page: HorizonXI specifically changed recast reduction to 2.5%
-- per tier instead of retail's 5%. Cast-time reduction is the
-- standard 10%/15%/20% schedule. Only RDM is listed as learning
-- Fast Cast on HorizonXI, so this table is RDM-only -- other
-- mains fall through and the helpers return 0.
local FC = {}
FC.TIERS = {
    [JOB_RDM] = {
        {15, 10, 2.5},
        {35, 15, 3.75},
        {55, 20, 5.0},
    },
}

-- Returns (cast_pct, recast_pct) from the player's main-job Fast
-- Cast trait at their current (sync-aware) level. P.player_level()
-- already prefers GetMemberMainJobLevel(0), so this honors level
-- sync -- a level-30-synced RDM75 reads as 30 and only Fast Cast I
-- applies, even though the unsynced level is 75.
function FC.fast_cast()
    local tiers = FC.TIERS[player_main_job_id()]
    if not tiers then return 0, 0 end
    local lv = P.player_level()
    local cast_pct, recast_pct = 0, 0
    for i = 1, #tiers do
        if lv >= tiers[i][1] then
            cast_pct, recast_pct = tiers[i][2], tiers[i][3]
        end
    end
    return cast_pct, recast_pct
end

-- Magic haste percentage from the player's current buff list.
-- BUFF.HASTE (id 33) = +15% magic haste per the wiki Haste page.
-- Other magic-haste sources (March songs, Hastega II, Indi-Haste,
-- etc.) aren't tracked, so the result is a LOWER BOUND on actual
-- magic haste. For recast estimation this errs on the safe (longer
-- than actual) side, which is correct: if the addon's cooldown
-- clears later than the game's, we just wait an extra moment.
function FC.magic_haste_pct()
    if self_has_buff(BUFF.HASTE) then return 15 end
    return 0
end

-- Effective cast time after Fast Cast. Used to size the cast
-- timeout (mark_spell_sent / parse_player_starts_casting) so a
-- fast-cast'd spell doesn't get a timeout based on the base value.
function FC.cast_time(spell_name)
    -- spell_lookup is case-insensitive, so chat-line parsers passing
    -- lowercase names ('refresh') and code paths passing the canonical
    -- capitalized form ('Refresh') both resolve to the same entry.
    -- Without this the lowercase path silently fell through to the
    -- default fallback and the starts_casting bump set cast_timeout_at
    -- too short for every self-buff cast.
    --
    -- Fallback for unknown spells: 4.0s. Combined with the timeout
    -- formula (cast_time + ANIMATION_END_SEC + 1.0 = cast_time + 6.0)
    -- this produces a conservative 10-SECOND timeout for any spell
    -- that slipped through the SPELL_CAST_TIME table -- enough time
    -- to legitimately complete most casts without prematurely
    -- declaring failure, but bounded so an unknown spell can't hang
    -- is_casting forever.
    local base = spell_lookup('cast_time', spell_name) or 4.0
    local fc_cast_pct, _ = FC.fast_cast()
    return base * (1 - fc_cast_pct / 100)
end

-- Effective recast per the wiki's combined formula:
--   floor( (1 - FC_recast) * round_10ths( (1 - Haste) * Base ) ) + 0.5
-- The trailing +0.5 is our addon-side safety margin so we don't
-- race the server clock by a tick or two when the cooldown is
-- about to expire. Plays the same role the old per-spell +0.1 in
-- SPELL_CD did, but scaled for the bigger recasts.
function FC.recast_time(spell_name)
    -- Case-insensitive base lookup -- see spell_lookup notes / the
    -- comment in FC.cast_time. Same reason: lowercase chat-parser
    -- input was hitting the fallback default.
    --
    -- Fallback for unknown spells: 180s (3 minutes). Way wider than
    -- any spell in the addon's real table -- intentional. If a
    -- spell name slipped through (typo, new spell, lowercase miss),
    -- we want the bot to STOP attempting it for a long time
    -- instead of retrying every few seconds on the old 10s default
    -- and producing the cast-spam loop. complete_cast / fail_cast_retry
    -- will still update the cooldown if/when the spell IS later
    -- recognized; this is just the worst-case ceiling.
    local base = spell_lookup('cd', spell_name) or 180.0
    local haste = FC.magic_haste_pct()
    local _, fc_recast_pct = FC.fast_cast()
    local after_haste = math.floor(base * (1 - haste / 100) * 10 + 0.5) / 10
    local after_fc    = math.floor(after_haste * (1 - fc_recast_pct / 100))
    return after_fc + 0.5
end

-- Check if a party slot has a buff, via StatusHandler keyed by server ID.
local function party_slot_has_buff(slot, buff_id)
    local pm = party()
    if not pm then return false end
    local ok, sid = pcall(function() return pm:GetMemberServerId(slot) end)
    if not ok or not sid then return false end
    return member_has_buff(tonumber(sid), buff_id)
end

-- Same thing by name. Returns false if the name is not an active party member
-- or is the local player (use self_has_buff for self).
local function party_name_has_buff(name, buff_id)
    if not name or name == '' then return false end
    local pm = party()
    if not pm then return false end
    for slot = 1, 5 do
        if n(pm:GetMemberIsActive(slot)) == 1 then
            local mname = pm:GetMemberName(slot) or ''
            if mname == name then
                return party_slot_has_buff(slot, buff_id)
            end
        end
    end
    return false
end

local function get_player_name_lower()
    local name = P.player_name()
    if name ~= '' then
        return sanitize_log_text(name):lower()
    end
    return nil
end

local function get_player_name_pattern()
    local pname = get_player_name_lower()
    if not pname or pname == '' then return nil end

    local pat = pname:gsub('([^%w])', '%%%1')
    pat = pat:gsub('%s+', '%%s+')
    -- Word-boundary frontier. Lua has no \b, but %f[%a] matches the
    -- position where the previous char is NOT a letter (or we're at
    -- start of string) AND the current char IS a letter. Without
    -- this, "playername" would match as a SUBSTRING inside another
    -- player's name -- "Bigplayernamefan starts casting Cure" would
    -- match the embedded "playername", and parse_player_starts_casting
    -- / parse_player_casts_name would credit that other player's cast
    -- to us (refreshing stand_lock, bumping manual_cast_until, etc.)
    -- The frontier rejects the substring match while still allowing
    -- the legitimate "Playername starts casting" at start-of-line or
    -- after a space / punctuation in concatenated battle-log lines.
    return '%f[%a]' .. pat
end

---------------------------------------------------------------------
-- DISTANCE
---------------------------------------------------------------------
-- FFXI's entity struct exposes a `Distance` field that stores the
-- SQUARED 3D distance from the player to that entity, computed by the
-- game. We just sqrt it. This works regardless of whether the entity
-- is the player's current target -- critical for mages, who target
-- party members for cures but still need to know mob distance.

local function entity_distance(ent)
    if not ent then return nil end
    local d = tonumber(ent.Distance)
    if not d or d < 0 then return nil end
    return math.sqrt(d)
end

local function get_member_distance(slot)
    if slot == 0 then return 0.0 end

    local pm = party()
    if not pm then return 9999 end

    local target_idx = n(pm:GetMemberTargetIndex(slot))
    if target_idx == 0 then return 9999 end

    local ok, ent = pcall(GetEntity, target_idx)
    if not ok or not ent then return 9999 end

    -- Ghost-data guard. After a zone change or a crash+reload, a party
    -- member who has moved out of render range (~50y, including across
    -- the map in the same zone) keeps a STALE entity at this
    -- TargetIndex: the client freezes ent.Distance at its last
    -- in-render value (e.g. the 11.1y from when they were last beside
    -- us) and stops updating it. entity_distance then returns that
    -- bogus short distance and every distance-gated decision (cure,
    -- refresh, haste, regen, protect, shell) treats them as reachable.
    -- Two cross-checks before trusting the distance:
    --
    --   1. ServerId match. The TargetIndex may have been recycled to a
    --      different entity entirely; if the entity sitting here isn't
    --      this member, the distance is meaningless.
    --   2. Render flag 0x200. Same flag is_valid_mob gates on -- set
    --      only while the entity is actively rendered. If it's clear,
    --      ent.Distance is frozen/stale, so the member is effectively
    --      out of range no matter what the number says.
    local okm, member_sid = pcall(function() return pm:GetMemberServerId(slot) end)
    member_sid = (okm and n(member_sid)) or 0
    local ent_sid    = n(ent.ServerId or ent.ServerID or 0)
    if member_sid ~= 0 and ent_sid ~= 0 and member_sid ~= ent_sid then
        return 9999
    end

    local em = entity()
    if em then
        local okf, flags = pcall(function() return em:GetRenderFlags0(target_idx) end)
        if okf and type(flags) == 'number' and bit.band(flags, 0x200) ~= 0x200 then
            return 9999
        end
    end

    return entity_distance(ent) or 9999
end

-- Body of the forward-declared force_rest_allows_stand.
-- When S.force_rest is off: always allows stand (returns true).
-- When S.force_rest is on:  allows stand only if (a) we have enough MP to
-- do something useful, AND (b) some party member within cure range has
-- HP% strictly below the override threshold. Self counts and is always
-- "in range" (slot 0 is us).
force_rest_allows_stand = function()
    if not S.force_rest then return true end
    if P.player_mp() < FORCE_REST_OVERRIDE_MIN_MP then return false end
    local pm = party()
    if not pm then return false end
    for slot = 0, 5 do
        if n(pm:GetMemberIsActive(slot)) == 1 then
            local hp_pct = n(pm:GetMemberHPPercent(slot))
            if hp_pct > 0 and hp_pct < FORCE_REST_OVERRIDE_HP_PCT then
                local in_range = (slot == 0)
                                 or (get_member_distance(slot) <= CFG.CURE_RANGE)
                if in_range then return true end
            end
        end
    end
    return false
end

-- True if the Auto Full Rest toggle currently blocks a non-cure stand.
-- Returns true only when ALL of:
--   - S.auto_full_rest is on
--   - player is currently resting
--   - we've been resting for at least AUTO_FULL_REST_SEC
--   - MP% is at or above AUTO_FULL_REST_MP_PCT
-- Intent: the tail end of a rest is cheap MP; don't interrupt it for a
-- debuff/auto-dispel that could wait a few more seconds. Emergency cure
-- callers don't consult this helper and always stand.
local function auto_full_rest_blocks()
    if not S.auto_full_rest then return false end
    if not P.player_is_resting() then return false end
    if S.rest_started_at <= 0 then return false end
    if (now() - S.rest_started_at) < AUTO_FULL_REST_SEC then return false end
    if P.player_mp_pct() < AUTO_FULL_REST_MP_PCT then return false end
    return true
end

-- Bar-element coverage decision. Scans the checked bar-element targets
-- and classifies the ones who still LACK the active element's buff by
-- whether they're inside the caster-centered AoE radius. Returns:
--   action     : 'cast'  -> at least one checked member needs it and
--                          EVERY needy checked member is in range; fire
--                          the active bar-element spell.
--                'wait'  -> at least one needy checked member is OUT of
--                          range; hold the cast (we'd miss them), and
--                          the caller echoes their names on a throttle.
--                'idle'  -> nobody checked needs it (all covered or none
--                          checked / present); do nothing.
--   out_names  : array of out-of-range needy member names (for the echo).
-- Self (slot 0) participates like anyone else: it's always in range
-- (distance 0), so a checked self who lacks the buff only ever pushes
-- toward 'cast', never 'wait'.
--
-- Reads S.barelement_active for the spell name; bails immediately if
-- nothing is selected (the cascade-side gate also short-circuits on
-- this, but defensive against future direct callers).
local function barelement_evaluate()
    local active_spell = S.barelement_active
    if type(active_spell) ~= 'string' or active_spell == '' then
        return 'idle', {}
    end
    local buff_id = BARELEMENT_BUFF_ID[active_spell]
    if not buff_id then return 'idle', {} end

    local pm = party()
    if not pm then return 'idle', {} end

    local pname = P.player_name()
    local any_needy_in_range  = false
    local out_names           = {}

    for slot = 0, 5 do
        if n(pm:GetMemberIsActive(slot)) == 1 then
            local mname = pm:GetMemberName(slot) or ''
            if mname ~= '' then
                -- Is this member checked as a bar-element target?
                local checked = false
                for i = 1, 6 do
                    if (S.barelement_targets[i] or '') == mname then
                        checked = true
                        break
                    end
                end

                if checked then
                    -- Does this member already have the active element?
                    local has_buff
                    if mname == pname then
                        has_buff = self_has_buff(buff_id)
                    else
                        has_buff = party_slot_has_buff(slot, buff_id)
                    end

                    if not has_buff then
                        -- Needy. In range or not? Self (slot 0) is dist 0.
                        local dist = (slot == 0) and 0.0 or get_member_distance(slot)
                        if dist <= CFG.BARSPELL_RADIUS then
                            any_needy_in_range = true
                        else
                            out_names[#out_names + 1] = mname
                        end
                    end
                end
            end
        end
    end

    -- An out-of-range needy member HOLDS the cast regardless of who's in
    -- range -- the user's rule is "cast only when every checked member
    -- who still needs it is reachable." Echo names while we wait.
    if #out_names > 0 then
        return 'wait', out_names
    end
    if any_needy_in_range then
        return 'cast', {}
    end
    return 'idle', {}
end

---------------------------------------------------------------------
-- PARTY DATA
---------------------------------------------------------------------

local function get_party_member(slot)
    local pm = party()
    if not pm then
        return { name='---', hp_pct=0, mp_pct=0, active=false,
                 dist=9999, slot=slot, hp=0, max_hp=0, missing_hp=0 }
    end

    local active  = n(pm:GetMemberIsActive(slot)) == 1
    local name    = pm:GetMemberName(slot) or '---'
    local hp_pct  = n(pm:GetMemberHPPercent(slot))
    local mp_pct  = n(pm:GetMemberMPPercent(slot))
    local dist    = active and get_member_distance(slot) or 9999

    local hp     = 0
    local max_hp = 0
    if active then
        local ok1, v1 = pcall(function() return pm:GetMemberHP(slot) end)
        local ok2, v2 = pcall(function() return pm:GetMemberMaxHP(slot) end)
        hp     = (ok1 and tonumber(v1)) or 0
        max_hp = (ok2 and tonumber(v2)) or 0
        -- GetMemberMaxHP unreliable in some Ashita builds; estimate from HP + HP%
        if max_hp == 0 and hp > 0 and hp_pct > 0 and hp_pct < 100 then
            max_hp = math.floor(hp * 100 / hp_pct + 0.5)
        end
    end

    if not active or name == '' then
        name = '---'
    end

    return {
        name       = name,
        hp_pct     = hp_pct,
        mp_pct     = mp_pct,
        active     = active,
        dist       = dist,
        slot       = slot,
        hp         = hp,
        max_hp     = max_hp,
        missing_hp = math.max(0, max_hp - hp),
    }
end

function Mob.get_party_snapshot()
    local snap = {}
    for slot = 0, 5 do
        local m = get_party_member(slot)
        if m.active and m.name ~= '---' then
            snap[#snap + 1] = m
        end
    end
    return snap
end

-- Fresh HP% read for a named party member. Used right before an
-- emergency cure fires so a DRG/wyvern that just landed Healing Breath
-- (between snapshot build and the cast) doesn't get double-cured.
-- Returns nil if the name isn't a live party member.
function Mob.live_hp_pct(name)
    local pm = party()
    if not pm then return nil end
    for slot = 0, 5 do
        if n(pm:GetMemberIsActive(slot)) == 1 and pm:GetMemberName(slot) == name then
            return n(pm:GetMemberHPPercent(slot))
        end
    end
    return nil
end

-- Fresh absolute HP read for a named party member: returns hp, max_hp,
-- missing_hp (all numbers) or nil if the name isn't a live member. Used
-- by the Brd anti-overcure path, which needs absolute missing HP (not
-- the percent that live_hp_pct returns) to pick a non-overhealing tier.
-- Mirrors get_party_member's max-HP estimation fallback for Ashita
-- builds where GetMemberMaxHP is unreliable.
function Mob.live_hp(name)
    local pm = party()
    if not pm then return nil end
    for slot = 0, 5 do
        if n(pm:GetMemberIsActive(slot)) == 1 and pm:GetMemberName(slot) == name then
            local hp_pct = n(pm:GetMemberHPPercent(slot))
            local ok1, v1 = pcall(function() return pm:GetMemberHP(slot) end)
            local ok2, v2 = pcall(function() return pm:GetMemberMaxHP(slot) end)
            local hp     = (ok1 and tonumber(v1)) or 0
            local max_hp = (ok2 and tonumber(v2)) or 0
            if max_hp == 0 and hp > 0 and hp_pct > 0 and hp_pct < 100 then
                max_hp = math.floor(hp * 100 / hp_pct + 0.5)
            end
            return hp, max_hp, math.max(0, max_hp - hp)
        end
    end
    return nil
end
--
-- Fixes the "party changed but the bot doesn't notice until I reload"
-- problem without the old nuke-everything behavior: we only clear names
-- that are no longer live party members. Members who are still present
-- keep their checkbox state.
--
-- Signature is the sorted list of active member names, joined by a
-- separator. If it hasn't changed since last tick, nothing to do.
--
-- If any active slot is briefly missing a name (transient state during
-- a zone / join), we skip this tick entirely rather than risk evicting
-- someone mid-transition.
function Mob.prune_stale_party_targets()
    local pm = party()
    if not pm then return end

    local names = {}
    for slot = 0, 5 do
        if n(pm:GetMemberIsActive(slot)) == 1 then
            local nm = pm:GetMemberName(slot) or ''
            if nm == '' then
                -- Member data not fully resolved yet; bail for this tick.
                return
            end
            names[#names+1] = nm
        end
    end
    table.sort(names)
    local sig = table.concat(names, '\x1f')

    if sig == S.last_party_sig then return end
    S.last_party_sig = sig

    -- Composition changed. Build name lookup and drop any ghost entries.
    local live = {}
    for i = 1, #names do live[names[i]] = true end

    local function prune(arr, label, prio)
        for i = 1, 6 do
            local tname = arr[i]
            if tname and tname ~= '' and not live[tname] then
                log(string.format('%s target %q no longer in party - pruning', label, tname))
                arr[i] = ''
                if prio then prio[tname] = nil end
            end
        end
    end
    prune(S.refresh_extras,         'Refresh',                S.refresh_priority)
    prune(S.haste_targets,          'Haste',                  S.haste_priority)
    prune(S.regen_targets,          'Regen')
    prune(S.protect_targets,        'Protect')
    prune(S.shell_targets,          'Shell')
    prune(S.barelement_targets,     'BarElement')
    prune(S.cure_only_emergency,    'CureExcluded')
    prune(S.emergency_cure_excluded,'EmergencyCureExcluded')
    prune(S.brd_overcure,           'BrdOvercure')
    prune(S.auto_move_targets,      'AutoMove')
end

---------------------------------------------------------------------
-- CLAIM DETECTION
---------------------------------------------------------------------

local function is_valid_mob(idx)
    local em = entity()
    if not em then return false end
    local ok, flags = pcall(function() return em:GetRenderFlags0(idx) end)
    if not ok or type(flags) ~= 'number' then return false end
    if bit.band(flags, 0x200) ~= 0x200 then return false end
    if bit.band(flags, 0x4000) ~= 0 then return false end
    return true
end

-- HXUI mirror of GetIsMobByIndex. Reads Ashita's entity SpawnFlags:
--   1  = PC (player)
--   2  = NPC
--   4  = Trust
--   8  = Pet
--   16 = Mob (this is what we want)
-- HXUI's enemylist gates its action-packet handler on this AND
-- GetIsValidMob. Without it, a Trust, a pet, an NPC, or a non-party
-- PC that hits a party member (via AoE etc.) inserts a row into
-- all_claimed_targets that prune can never recognize as wrong --
-- its render flags / HP / Name all look fine, so it sits in the
-- table as a phantom and (worst case) wins the picker as the oldest
-- entry. The bot then locks onto a sid that <bt> doesn't resolve
-- to and casts go into the void. This was the missing filter.
local function is_mob_by_index(idx)
    if not idx or idx == 0 then return false end
    local em = entity()
    if not em then return false end
    local ok, flags = pcall(function() return em:GetSpawnFlags(idx) end)
    if not ok or type(flags) ~= 'number' then return false end
    return flags == 16
end

local function get_party_server_ids()
    local ids = {}
    local pm = party()
    if not pm then return ids end

    for i = 0, 17 do
        if n(pm:GetMemberIsActive(i)) == 1 then
            local sid = n(pm:GetMemberServerId(i))
            if sid > 0 then
                ids[sid] = true
            end
        end
    end
    return ids
end

-- (Removed: CLAIMED_MOB_FRESHNESS_SEC, CLAIMED_MOB_SETTLE_SEC,
-- CLAIM_DEBOUNCE_SEC.) All three were timing layers bolted on to mask
-- problems the HXUI-mirror prune doesn't have. The HXUI render-flag
-- + HPPercent > 0 + Name validity check in prune handles slot reuse
-- and dead mobs directly: dead -> dropped that same tick. No row
-- tables, no updated_at clocks, no settle windows.

function Mob.prune_claimed_targets()
    -- HXUI mirror plus is_mob_by_index. enemylist.lua does the four
    -- HXUI checks (ent + GetIsValidMob + HPPercent > 0 + Name); we
    -- add is_mob_by_index as a fifth check because the packet
    -- handlers can ALSO let through a stale slot that's currently
    -- occupied by a non-mob (FFXI reuses entity indices freely
    -- between mobs, players, pets, NPCs). HXUI catches this at
    -- insert time via GetIsMobByIndex but a row that was a mob at
    -- insert and is now a different type needs the check at prune
    -- time too. Everything else still applies: dead -> HPPercent
    -- <= 0 -> drop. Slot unloaded -> render flags clear -> drop.
    for idx, _ in pairs(S.all_claimed_targets) do
        local ok, ent = pcall(GetEntity, idx)
        local hp      = (ok and ent) and n(ent.HPPercent or 0) or 0
        if (not ok) or (not ent) or (not is_valid_mob(idx))
           or (not is_mob_by_index(idx))
           or hp <= 0 or ent.Name == nil then
            S.all_claimed_targets[idx] = nil
        end
    end
end

-- Claimed-mob count, optionally range-filtered.
--
-- max_range == nil   -> count ALL claimed mobs regardless of distance.
-- max_range == 25.0  -> count only claimed mobs within 25 yalms. Used
--                      by the Dia and BLM skillup <bt>-safety gates: a
--                      2nd mob currently being pulled / kited / held
--                      far from camp has enough travel time to close
--                      that the in-flight cast completes before it
--                      bounces, so casting while only one nearby mob
--                      is on lock is acceptable.
--
-- Prune (above) drops rows for entities that have died, despawned, or
-- changed type, so any row that's here is a live claim. When
-- range-filtering, we read the live distance via entity_distance
-- (mirrors get_claimed_mobs_in_range).
function Mob.count_claimed_targets(max_range)
    local c = 0
    for idx, _ in pairs(S.all_claimed_targets) do
        if max_range == nil then
            c = c + 1
        else
            local ok, ent = pcall(GetEntity, idx)
            if ok and ent then
                local dist = entity_distance(ent)
                if dist and dist > 0 and dist <= max_range then
                    c = c + 1
                end
            end
        end
    end
    return c
end

function Mob.get_claimed_mobs_in_range()
    -- HXUI mirror. Iterate all_claimed_targets, read each entity live,
    -- include those in engage range. No settle window, no freshness
    -- check -- prune already dropped anything that isn't currently
    -- valid + alive + named, so a row that's here is a row we trust.
    -- Read server_id from the entity at iteration time rather than
    -- storing it in the row, matching HXUI's "the entity table is the
    -- source of truth" model.
    --
    -- added_at: timestamp the entry was first inserted into
    -- all_claimed_targets (preserved across pairs() iterations -- new
    -- packets do `[idx] = existing or now()`, so the first claim's
    -- time sticks until prune drops the row). The picker uses this
    -- to lock onto the OLDEST claimed mob ("appeared first") instead
    -- of pairs()-iteration-order which is hash-based and effectively
    -- random.
    local result = {}
    for idx, added_at in pairs(S.all_claimed_targets) do
        local ok, ent = pcall(GetEntity, idx)
        if ok and ent then
            local sid  = n(ent.ServerId or ent.ServerID or ent.Id or ent.ID or 0)
            local dist = entity_distance(ent)
            if sid > 0 and dist and dist > 0 and dist <= MOB_ENGAGE_RANGE then
                result[#result + 1] = {
                    index     = idx,
                    server_id = sid,
                    dist      = dist,
                    added_at  = tonumber(added_at) or 0,
                }
            end
        end
    end
    return result
end

-- Lookup helper that ignores range. Returns the mob row (with live
-- distance) for the given sid if it's still in all_claimed_targets,
-- nil otherwise. Used by the dead-check: a mob that just walked out
-- of the 20y engage range is NOT dead -- prune leaves it in
-- all_claimed_targets because the entity is still valid + alive +
-- named -- so the lock should be held. get_claimed_mobs_in_range
-- still drops it from picker selection (range-gated), and the
-- cascade's active_mob_dist <= ACTIVE_MOB_RANGE check still blocks
-- stand-up casts. Only when the mob actually dies (prune drops it
-- on HPPercent <= 0) does this return nil and the dead-check fire.
function Mob.find_claimed_sid_anywhere(sid)
    if not sid or sid == 0 then return nil end
    for idx, _ in pairs(S.all_claimed_targets) do
        local ok, ent = pcall(GetEntity, idx)
        if ok and ent then
            local esid = n(ent.ServerId or ent.ServerID or ent.Id or ent.ID or 0)
            if esid == sid then
                local dist = entity_distance(ent) or 9999
                return {
                    index     = idx,
                    server_id = sid,
                    dist      = dist,
                }
            end
        end
    end
    return nil
end

local function any_mob_claimed_by_party()
    return #Mob.get_claimed_mobs_in_range() > 0
end

function Mob.find_claimed_mob_by_sid(claimed_mobs, sid)
    if sid == nil or sid == 0 then return nil end
    for _, mob in ipairs(claimed_mobs) do
        if mob.server_id == sid then
            return mob
        end
    end
    return nil
end

function Mob.get_claimed_mob_hp(index)
    -- HXUI mirror: ent.HPPercent only, no fallback to ent.HPP. The
    -- two fields can disagree (HPP is sometimes an absolute value,
    -- not a percent) and HXUI's enemylist reads HPPercent directly.
    -- Matching the same expression keeps our debug panel HP and the
    -- HXUI display consistent.
    local ok_ent, ent = pcall(GetEntity, index)
    return (ok_ent and ent) and n(ent.HPPercent or 0) or 0
end

---------------------------------------------------------------------
-- SPELL COOLDOWNS / CAST LOCK
---------------------------------------------------------------------

-- Global so Mob.get_next_debuff (defined above in HELPERS) can call it safely.
function spell_ready(spell_name)
    local ready_at = S.cooldowns[spell_name]
    return not ready_at or now() >= ready_at
end

-- Display helper for the Controls header bars. Returns 'true' when
-- the spell is off cooldown, otherwise the remaining cooldown as
-- a short fixed-precision string (e.g. '12.3s'). Used to surface
-- recast state in the collapsed header label so the user can see
-- "Refresh [on] Ready: 8.2s" at a glance without opening the
-- section. Kept local since it's purely a GUI helper.
local function spell_ready_label(spell_name)
    local ready_at = S.cooldowns[spell_name]
    if not ready_at or now() >= ready_at then
        return 'true'
    end
    return string.format('%.1fs', ready_at - now())
end

-- Global so Mob.get_next_debuff / Mob.get_next_skillup_spell
-- (defined above in HELPERS, before this point in the file) can
-- call it safely. Same pattern as spell_ready right above. If
-- this is changed back to `local`, those upstream Mob helpers
-- crash with "attempt to call global 'spell_usable' (a nil
-- value)" because the local upvalue isn't bound at their
-- definition point.
function spell_usable(spell_name)
    local req = SPELL_LEVEL[spell_name]
    if req and P.player_level() < req then
        log(string.format('%s requires level %d (current %d)', spell_name, req, P.player_level()))
        return false
    end
    return true
end

local function spell_clear()
    S.is_casting             = false
    S.cast_timeout_at        = 0.0
    S.last_spell_sent        = nil
    S.last_spell_sent_raw    = nil
    S.last_spell_target_name = nil
end

local function mark_spell_sent(spell_name, target_name)
    -- Effective cast time (after Fast Cast). Used below for the
    -- cast_timeout_at and spell_lock_until windows. Recast is NOT
    -- computed here: the FFXI server's recast counter starts when
    -- the cast resolves, not when /ma is sent, so the recast value
    -- is computed and written in complete_cast_body at completion
    -- (FC.recast_time(spell_raw)).
    local cast_time   = FC.cast_time(spell_name)

    -- NOTE: S.cooldowns[spell_name] is intentionally NOT written
    -- at /ma send time. The per-spell CD is set only when the
    -- cast resolves: on confirmed completion (complete_cast_body
    -- via 'log' / 'action' / 'buff'), on timeout
    -- (complete_cast('timeout')), or on failure (fail_cast_retry:
    -- UTC lockout threshold push, or genuine interrupt 1.0s
    -- retry). Re-fire of THIS spell during its own in-flight
    -- window is prevented by S.is_casting + S.spell_lock_until
    -- below, both set immediately and covering cast_time +
    -- ANIMATION_END_SEC -- so no /ma can leak through this
    -- window even with no per-spell CD in place. Downstream
    -- nil-safety: spell_ready uses `not ready_at`, fail_cast_retry
    -- uses `S.cooldowns[spell_raw] or 0`, complete_cast_body
    -- overwrites unconditionally -- all handle the nil case.
    S.is_casting             = true
    -- Timeout buffer: cast_time is the FC-adjusted cast bar duration,
    -- ANIMATION_END_SEC covers the post-bar finish phase where the
    -- server processes deduction/buff-application and emits the
    -- completion chat line, +1.0s covers chat-event delivery slack.
    -- Without ANIMATION_END_SEC the timeout fires while the cast is
    -- still completing on the server -- we then ship the next /ma
    -- and get "Unable to cast spells at this time" because the
    -- previous cast is still locking the slot. The
    -- parse_player_starts_casting handler later refreshes this to a
    -- fresh value from the moment the game confirms the cast
    -- started, so we don't double-count network roundtrip.
    S.cast_timeout_at        = now() + cast_time + ANIMATION_END_SEC + 1.0
    -- spell_lock matches the timeout window: we cannot legally send
    -- a follow-up /ma until cast_time + ANIMATION_END_SEC has elapsed
    -- (that's when the server releases the spell slot). The +1.0
    -- buffer is only for the timeout / parser slack; the lock
    -- itself doesn't need it because POST_CAST_SETTLE adds 1.0s
    -- after cast_complete fires.
    S.spell_lock_until       = now() + cast_time + ANIMATION_END_SEC
    S.last_spell_sent        = normalize_action_name(spell_name)
    S.last_spell_sent_raw    = spell_name
    S.last_spell_target_name = type(target_name) == 'string' and sanitize_log_text(target_name) or nil
    -- Diagnostics: surface in the Debug Panel so unexplained "Unable to
    -- cast spells at this time" failures can be cross-referenced against
    -- the inter-cast gap. Stores the raw values; the panel does the
    -- "X seconds ago" math at render time. We keep TWO snapshots: the
    -- one we're about to send (current), and the one we sent before
    -- that (previous). The gap (current - previous) is the useful
    -- diagnostic for fail-logging; the "time since the failing cast
    -- was sent" by itself is near-zero and tells you nothing.
    S.prev_cast_sent_at      = S.last_cast_sent_at
    S.prev_cast_sent_spell   = S.last_cast_sent_spell
    S.prev_cast_sent_target  = S.last_cast_sent_target
    S.last_cast_sent_at      = now()
    S.last_cast_sent_spell   = spell_name
    S.last_cast_sent_target  = type(target_name) == 'string' and sanitize_log_text(target_name) or ''

    -- Cast-time logging (Debug-gated): start tracking this cast.
    -- log_cast_pending flushes any previously unconfirmed cast as
    -- NEVER CONFIRMED before recording the new one, so the file
    -- shows exactly one row per /ma we ever send.
    CastLog.pending(spell_name, S.last_cast_sent_target)
end

local function spell_locked()
    if S.is_casting then return true end
    if now() < S.spell_lock_until then return true end
    -- Global UTC throttle: when the cascade has produced too many
    -- consecutive UTC rejects, this pause prevents ANY new cast
    -- from going out for GLOBAL_UTC_BACKOFF_SEC. complete_cast
    -- clears it on any successful confirmation.
    if now() < (S.global_cast_pause_until or 0) then return true end
    return false
end

----------------------------------------------------------------------
-- PACKET CASTING  (outgoing 0x01A action packet)
--
-- Every mob-facing cast goes out as the SAME outgoing action packet the
-- client itself sends when you type /ma. The target's server id and
-- entity index are carried IN the payload, so nothing client-side is
-- touched: no retargeting, no cursor movement, no <t>, no <bt>. We are
-- not persuading the client to aim for us -- we are stating the target.
--
-- Why this and not the 0x058 "set target" inject: 0x058 is an INCOMING
-- packet we fake, which the server never sees -- it only lies to our own
-- client, and then the cast still has to ride <t>. 0x01A is real
-- outgoing traffic, byte-identical to a legitimate /ma, and it names the
-- target explicitly. Strictly less machinery and strictly more accurate.
--
-- This is what retires the <bt>-drift workarounds. <bt> could silently
-- resolve to a different nearby mob, so mob-debuff and skillup casts
-- were gated to single-mob situations (count_claimed_targets(25) <= 1).
-- A packet that names its target cannot drift, so those gates are gone.
--
-- Outgoing 0x01A layout, taken from the LSB SERVER's own parser
-- (src/map/packets/c2s/0x01a_action.h, GP_CLI_COMMAND_ACTION) -- not
-- from a community packet definition. This is literally the struct the
-- server casts the received bytes to, so it is definitive:
--
--   0x00  header    4   id:9 | size:7 | sync
--   0x04  UniqueNo  u32  target server id
--   0x08  ActIndex  u16  target entity index
--   0x0A  ActionID  u16  category
--   0x0C  union, 16 bytes -- for CastMagic:
--         SpellId u32 @0x0C, PosX f32 @0x10, PosZ f32 @0x14, PosY f32 @0x18
--   = 28 bytes (0x1C).
--
-- Bytes 1-4 are placeholder zeros: AddOutgoingPacket fills the real
-- id/size/sync itself (same convention bovinefh's 0x110/0x028 builders
-- rely on -- do NOT hand-write the header).
--
-- Categories are the server's own enum GP_CLI_COMMAND_ACTION_ACTIONID:
--   Talk 0x00, Attack 0x02, CastMagic 0x03, AttackOff 0x04, Help 0x05,
--   Weaponskill 0x07, JobAbility 0x09, Assist 0x0C, Shoot 0x10, ...
----------------------------------------------------------------------

local ACTION_PACKET      = 0x01A
local ACTION_CAT_MAGIC   = 0x03

-- ---------------------------------------------------------------
-- HARD PACKET RATE LIMIT
--
-- At most ONE injected action packet per second, globally, no
-- exceptions. A cast takes seconds and has a recast on top; there is no
-- legitimate reason to exceed this. Anything faster is a bug looping,
-- and a packet loop is exactly the kind of traffic that gets noticed.
--
-- Unbypassable by construction: send_action_packet is the ONLY place
-- this addon calls AddOutgoingPacket, and the check sits immediately
-- before that call. Every caller inherits the limit for free.
--
-- The failure mode this kills: cast_on_target is reached on EVERY tick
-- a mob cast is wanted. If a cast never resolves (mob gone, sid
-- recycled, packet dropped) the naive version would fire 30-60x/sec
-- forever. Now: 1/sec, hard.
-- ---------------------------------------------------------------
local ACTION_PACKET_MIN_INTERVAL = 1.0
local last_action_packet_at      = -math.huge
local action_packet_blocked_n    = 0

local function action_packet_allowed()
    return now() >= (last_action_packet_at + ACTION_PACKET_MIN_INTERVAL)
end

-- Spell name -> spell id.
--
-- PRIMARY SOURCE: LandSandBoat's sql/spell_list.sql -- the server LSB /
-- HorizonXI actually runs, so these are by definition the ids the server
-- expects in the action packet's Param field. Extracted verbatim from
-- LSB `base`; every spell bovinemage can cast is covered (48/48).
-- LSB stores names lowercased with underscores ('dia_ii'); displayed
-- here in the same form the rest of this addon uses.
--
-- These are NOT remembered ids -- a wrong Param would silently cast the
-- WRONG SPELL at the mob, which is far worse than not casting at all.
local SPELL_ID = {
    ['Aero']        = 154,
    ['Aero II']     = 155,
    ['Baraera']     = 68,
    ['Barblizzara'] = 67,
    ['Barfira']     = 66,
    ['Barstonra']   = 69,
    ['Barthundra']  = 70,
    ['Barwatera']   = 71,
    ['Bind']        = 258,
    ['Bio']         = 230,
    ['Bio II']      = 231,
    ['Blind']       = 254,
    ['Blindna']     = 16,
    ['Blink']       = 53,
    ['Blizzard']    = 149,
    ['Blizzard II'] = 150,
    ['Cure']        = 1,
    ['Cure II']     = 2,
    ['Cure III']    = 3,
    ['Cure IV']     = 4,
    ['Dia']         = 23,
    ['Dia II']      = 24,
    ['Dispel']      = 260,
    ['Haste']       = 57,
    ['Paralyna']    = 15,
    ['Paralyze']    = 58,
    ['Phalanx']     = 106,
    ['Poisona']     = 14,
    ['Protect']     = 43,
    ['Protect II']  = 44,
    ['Protect III'] = 45,
    ['Protect IV']  = 46,
    ['Refresh']     = 109,
    ['Regen']       = 108,
    ['Reraise']     = 135,
    ['Shell']       = 48,
    ['Shell II']    = 49,
    ['Shell III']   = 50,
    ['Shell IV']    = 51,
    ['Silena']      = 17,
    ['Silence']     = 59,
    ['Sleep']       = 253,
    ['Slow']        = 56,
    ['Stone']       = 159,
    ['Stone II']    = 160,
    ['Stoneskin']   = 54,
    ['Water']       = 169,
    ['Water II']    = 170,
}

-- Resolution order: LSB table first (authoritative for this server),
-- then the client's own resource DATs as a fallback for anything added
-- to the addon later without a table entry. `false` is cached for
-- unresolvable names so we don't rescan every tick.
local spell_id_cache = {}

local function spell_id_by_name(name)
    if type(name) ~= 'string' or name == '' then return nil end

    -- 1. LSB table -- the ids the server actually runs on.
    local known = SPELL_ID[name]
    if known then return known end

    local hit = spell_id_cache[name]
    if hit ~= nil then
        if hit == false then return nil end
        return hit
    end

    local rm = AshitaCore:GetResourceManager()
    if not rm then return nil end

    local found = nil

    -- 2. Client resource DAT, direct name lookup.
    if type(rm.GetSpellByName) == 'function' then
        local ok, sp = pcall(function() return rm:GetSpellByName(name, 0) end)
        if ok and sp then
            local id = n(sp.Index or sp.ID or 0)
            if id > 0 then found = id end
        end
    end

    -- 3. Client resource DAT, scan + name match. One scan per distinct
    -- name for the whole session.
    if found == nil and type(rm.GetSpellById) == 'function' then
        local want = name:lower()
        for i = 1, 1024 do
            local ok, sp = pcall(function() return rm:GetSpellById(i) end)
            if ok and sp and sp.Name and sp.Name[1] then
                local nm = tostring(sp.Name[1])
                    :gsub('[%z\1-\31\127-\255]', '')
                    :gsub('^%s+', ''):gsub('%s+$', '')
                if nm:lower() == want then
                    found = n(sp.Index or i)
                    if found == 0 then found = i end
                    break
                end
            end
        end
    end

    spell_id_cache[name] = found or false
    if found == nil then
        log(string.format('Cannot resolve spell id for "%s" - packet cast refused', name))
    end
    return found
end

-- Build + send the outgoing 0x01A. Returns true only if a packet
-- actually went out.
--
-- Layout is the LSB server's own struct (src/map/packets/c2s/0x01a_action.h,
-- GP_CLI_COMMAND_ACTION) -- i.e. exactly what the server parses:
--
--   0x00  header    4   id:9 | size:7 | sync   (Ashita fills these)
--   0x04  UniqueNo  u32  target server id
--   0x08  ActIndex  u16  target entity index
--   0x0A  ActionID  u16  category (0x03 = CastMagic)
--   0x0C  <union, 16 bytes: ActionBuf[4]>
--         CastMagic:  SpellId u32 @0x0C, PosX f32 @0x10, PosZ f32 @0x14, PosY f32 @0x18
--   = 28 bytes (0x1C) total.
--
-- Two things the server source settles that the community packet
-- definitions get loose about:
--   1. SpellId is u32, NOT u16. (Windower models it as Param u16 +
--      _unknown1 u16, which is byte-identical for ids < 65536 -- but
--      only by luck. We write the real u32.)
--   2. The union is ALWAYS 16 bytes, so the packet is 28 bytes even for
--      a plain targeted spell. The server unconditionally reads
--      PosX/PosZ/PosY for CastMagic and clamps them into an action
--      offset (it is how Luopan placement works). Sending a short
--      packet would leave the server clamping whatever bytes happened
--      to follow -- garbage in, undefined behaviour out. We send the
--      full 28 and leave the floats as zeros: 0.0 offset == cast at the
--      target itself, which is what we want for every spell here.
local function send_action_packet(target_sid, target_index, category, param)
    target_sid   = n(target_sid)
    target_index = n(target_index)
    category     = n(category)
    param        = n(param)
    if target_sid == 0 or target_index == 0 then return false end

    -- RATE LIMIT. Checked after the cheap validation (so an unresolvable
    -- target never burns the budget) and immediately before the send.
    if not action_packet_allowed() then
        action_packet_blocked_n = action_packet_blocked_n + 1
        -- Log once per lock window; a per-tick "blocked" log would just
        -- be spam of a different flavour.
        if action_packet_blocked_n == 1 then
            log(string.format('Action packet rate-limited (1/%.0fs) - deferred',
                ACTION_PACKET_MIN_INTERVAL))
        end
        return false
    end
    action_packet_blocked_n = 0

    -- Stamp BEFORE the send: if AddOutgoingPacket throws, the second is
    -- still consumed, so a throwing call cannot become a tight loop.
    last_action_packet_at = now()

    -- 28 bytes, zero-filled. Bytes 1-4 (header) stay zero: Ashita fills
    -- id/size/sync. Bytes 17-28 (PosX/PosZ/PosY) stay zero = 0.0f floats
    -- = no action offset.
    local d = {}
    for i = 1, 28 do d[i] = 0 end
    -- UniqueNo (u32) @ 0x04
    d[5]  = bit.band(target_sid, 0xFF)
    d[6]  = bit.band(bit.rshift(target_sid, 8),  0xFF)
    d[7]  = bit.band(bit.rshift(target_sid, 16), 0xFF)
    d[8]  = bit.band(bit.rshift(target_sid, 24), 0xFF)
    -- ActIndex (u16) @ 0x08
    d[9]  = bit.band(target_index, 0xFF)
    d[10] = bit.band(bit.rshift(target_index, 8), 0xFF)
    -- ActionID (u16) @ 0x0A
    d[11] = bit.band(category, 0xFF)
    d[12] = bit.band(bit.rshift(category, 8), 0xFF)
    -- SpellId / SkillId (u32) @ 0x0C
    d[13] = bit.band(param, 0xFF)
    d[14] = bit.band(bit.rshift(param, 8),  0xFF)
    d[15] = bit.band(bit.rshift(param, 16), 0xFF)
    d[16] = bit.band(bit.rshift(param, 24), 0xFF)

    local ok = pcall(function()
        AshitaCore:GetPacketManager():AddOutgoingPacket(ACTION_PACKET, d)
    end)
    return ok == true
end

-- Cast `spell` at a mob by SERVER ID via the action packet. Resolves the
-- entity index and spell id first and refuses cleanly if either is
-- unknown -- we never fire a packet we cannot fully account for.
local function cast_spell_packet(spell, sid)
    sid = n(sid)
    if sid == 0 then return false end

    local mob = Mob.find_claimed_sid_anywhere(sid)
    if not mob or n(mob.index) == 0 then
        log(string.format('Packet cast %s: sid %d not resolvable, refused', tostring(spell), sid))
        return false
    end

    local spell_id = spell_id_by_name(spell)
    if not spell_id then return false end

    if not send_action_packet(sid, mob.index, ACTION_CAT_MAGIC, spell_id) then
        return false
    end

    log(string.format('PKT: /ma "%s" -> sid %d (idx %d, spell id %d)',
        tostring(spell), sid, n(mob.index), spell_id))
    return true
end

-- target_name may be:
--   a string -- a placeholder / player name, sent as a normal /ma
--               command ('<t>', '<me>', 'Cowrevenge', ...). Unchanged
--               legacy behaviour; party cures and self-buffs use this.
--   a number -- a mob SERVER ID. Cast goes out as an outgoing 0x01A
--               action packet naming that exact mob. No retargeting.
local function cast_on_target(spell, target_name)

    if spell_locked() then return false end
    -- Stand-up settle: see STAND_SETTLE_SEC comment. If we just sent
    -- /heal to come out of rest, hold off briefly so the animation
    -- completes before /ma goes out.
    if now() < (S.last_stand_at or 0) + STAND_SETTLE_SEC then return false end
    -- Movement settle: any player movement in the last MOVEMENT_SETTLE_SEC
    -- (Auto Move /follow, manual WASD, knockback, ally bump, ...)
    -- blocks /ma -- moving cancels the cast in FFXI. Polled by
    -- poll_player_movement() at top of tick() so the timestamp is
    -- fresh against `now()` here.
    if now() < (S.last_movement_at or 0) + MOVEMENT_SETTLE_SEC then return false end
    if not spell_ready(spell) then return false end
    if not spell_usable(spell) then return false end

    -- Self-silence chokepoint. Silence blocks all magic in FFXI, and
    -- this addon only sends /ma (per the whitelist), so a silenced
    -- player has nothing to do here. Refuse silently -- the per-event
    -- log line is emitted by the higher-level skip in tick(), so we
    -- don't need to log again per attempt and risk filling the log
    -- buffer if multiple cast paths probe in the same tick.
    if self_is_silenced() then return false end

    -- Action-block chokepoint. Sleep/Sleep II/Stun/Petrify/Terror all
    -- make /ma return an error from the server. Without this gate the
    -- bot fires the cast, mark_spell_sent sets the lock, the server
    -- rejects with "Unable to cast spells at this time" (or just
    -- nothing), we time out, repeat. Refuse here instead of burning
    -- the timeout cycle.
    if self_cannot_act() then return false end

    local min_mp = SPELL_MP_COST[spell] or 0
    local cur_mp = P.player_mp()
    if min_mp > 0 and cur_mp < min_mp then
        log(string.format('Not enough MP for %s (have %d, need %d)', spell, cur_mp, min_mp))
        return false
    end

    -- Numeric target = mob server id: the cast goes out as an outgoing
    -- 0x01A naming that mob. Deliberately the LAST gate -- every cheaper
    -- refusal (CD, MP, silence, movement, stand settle) has already run,
    -- so we never emit a packet for a cast that would have been refused.
    if type(target_name) == 'number' then
        local sid = target_name
        if not cast_spell_packet(spell, sid) then return false end
        refresh_stand_lock('cast-attempt:' .. tostring(spell))
        -- Track it exactly like a /ma cast: the server's responses
        -- (action packets / chat lines) are identical either way, so all
        -- the existing completion + timeout handling applies unchanged.
        mark_spell_sent(spell, string.format('sid:%d', sid))
        return true
    end

    refresh_stand_lock('cast-attempt:' .. tostring(spell))
    send(string.format('/ma "%s" "%s"', spell, target_name))
    mark_spell_sent(spell, target_name)
    return true
end

-- True if the player currently has enough MP for the given spell.
-- Used by the standing-branch buff casts so we don't attempt (and log
-- a "Not enough MP" failure for) a buff we can't pay for -- falling
-- through to the rest logic instead. cast_on_target enforces the same
-- check as a hard gate; this is the cheap pre-check so we skip the
-- attempt cleanly.
local function can_afford(spell)
    local cost = SPELL_MP_COST[spell] or 0
    return cost <= 0 or P.player_mp() >= cost
end

-- Choose cure spell by missing HP to minimise unnecessary hate.
-- WHEN to cure is decided by HP% upstream; this only picks the spell tier.
--   missing_hp >= 200  ->  Cure III (~180 potency)
--   missing_hp <  200  ->  Cure II  (~90 potency)
-- Cure I is never used.
-- Returns cure spells available to the player right now, best first.
local function get_cure_tiers()
    local job = player_main_job_id()
    local lv  = P.player_level()
    local tiers = {}
    for _, spell in ipairs(CURE_TIERS) do
        local req = CURE_JOB_LEVELS[spell]
        local min_lv = req and req[job]
        if min_lv and lv >= min_lv then
            tiers[#tiers + 1] = spell
        end
    end
    return tiers
end

-- Emergency cure: scan tiers in a SAFETY-FIRST order rather than
-- raw top-down. No suppression -- fires regardless of recent cures.
--
-- Tier-scan order when the player has Cure IV available:
--   1. Cure III  (tier[2])  -- preferred. 46 MP, ~280 HP, 6s base
--                              recast. The right tool for almost
--                              every dip.
--   2. Cure IV   (tier[1])  -- escalation. 88 MP, ~600 HP, 8s base
--                              recast. Used ONLY when Cure III isn't
--                              ready (spell_ready check inside
--                              cast_on_target fails => falls through
--                              here). Cure IV becomes a panic button
--                              held for back-to-back emergencies that
--                              Cure III can't cover, not the default
--                              "every dip blows 88 MP" tool.
--   3. Cure II   (tier[3])  -- standard cascade.
--   4. Cure I    (tier[4])  -- last resort.
--
-- Tier-scan order when the player has no Cure IV (lower-level WHM/RDM/PLD):
--   Raw top-down (tiers[1] -> tiers[2] -> ...). The "demote tier[1]"
--   logic only applies when tier[1] is Cure IV; for a player whose
--   top tier is already Cure III or lower, we want straightforward
--   top-down so they still get their biggest cure first.
--
-- Note on the short base recasts (6s Cure III, 8s Cure IV): the
-- only way Cure IV ever fires under this scan is if Cure III is
-- legitimately still on its 6s recast from a previous emergency
-- (back-to-back dips within ~6s). The GUI's "Cures (Cure III
-- Ready: <state>)" header label reads from S.cooldowns[Cure III]
-- and is the source of truth for whether the bot will pick Cure III
-- on the next cast attempt -- if it says "Ready: true" Cure III
-- will be picked, if it says e.g. "Ready: 3.4s" Cure IV is the
-- legitimate fallback.
local function cast_emergency_cure(target_name)
    local tiers = get_cure_tiers()
    local order
    if tiers[1] == 'Cure IV' and tiers[2] then
        order = { tiers[2], tiers[1] }
        for i = 3, #tiers do order[#order + 1] = tiers[i] end
    else
        order = tiers
    end
    -- Track WHY the preferred tier (order[1]) was skipped, if it
    -- was. Only emit the diagnostic when we end up successfully
    -- casting a NON-preferred tier (otherwise no escalation
    -- happened and there's nothing to explain). cprint not log()
    -- so it's visible without flipping Debug -- escalations are
    -- rare events, not chat-floody.
    local preferred = order[1]
    local skip_reason = nil
    for idx, spell in ipairs(order) do
        if cast_on_target(spell, target_name) then
            if idx > 1 and skip_reason then
                cprint(string.format(
                    'EMERGENCY: %s -> %s (%s skipped: %s)',
                    preferred, spell, preferred, skip_reason))
            end
            return true
        end
        -- Capture the skip reason for the preferred tier so if we
        -- escalate to a lower tier we can explain why. Diagnostic
        -- mirrors the cast_on_target gates in order so the FIRST
        -- failing gate is reported (which is the actual blocker).
        if idx == 1 then
            local cd_rem  = (S.cooldowns[spell] or 0) - now()
            local stand_rem = (S.last_stand_at or 0) + STAND_SETTLE_SEC - now()
            local move_rem  = (S.last_movement_at or 0) + MOVEMENT_SETTLE_SEC - now()
            local mp_cost = SPELL_MP_COST[spell] or 0
            local mp_have = P.player_mp()
            if spell_locked() then
                skip_reason = 'spell_locked (in-flight cast)'
            elseif stand_rem > 0 then
                skip_reason = string.format('stand settle %.2fs left', stand_rem)
            elseif move_rem > 0 then
                skip_reason = string.format('movement settle %.2fs left', move_rem)
            elseif cd_rem > 0 then
                skip_reason = string.format('on CD %.2fs left', cd_rem)
            elseif self_is_silenced() then
                skip_reason = 'silenced'
            elseif self_cannot_act() then
                skip_reason = 'cannot act (sleep/stun/petrify/terror)'
            elseif mp_have < mp_cost then
                skip_reason = string.format('MP %d < cost %d', mp_have, mp_cost)
            else
                skip_reason = 'unknown (cast_on_target returned false but no obvious gate)'
            end
        end
    end
    return false
end

-- Normal cure: routine HP top-off, fires for anyone in the
-- 51-69% band (below NORMAL_CURE_THRESHOLD, above the emergency
-- threshold). Per-target POST_CURE_SUPPRESS gate prevents
-- overcasting.
--
-- HARD RULE: NEVER fires the top tier (Cure IV at RDM50+/WHM41+/
-- PLD50+). Cure IV is an 88-MP hate-magnet held strictly for the
-- emergency cascade -- using it for a 65%-HP routine top-off
-- wastes MP, generates hate the tank has to taunt back, and
-- bumps the recast right when the emergency cascade might
-- actually need it.
--
-- Cascade: start at tiers[2] (Cure III when Cure IV exists,
-- Cure II for Cure-III-capped players, etc.) and drop DOWN
-- through the remaining tiers if the preferred one is on
-- recast. tiers[1] is only consulted when the player has a
-- single tier available -- in that case the "top tier"
-- distinction doesn't apply (it's the only cure they have).
local function cast_normal_cure(target_name)
    if now() < (S.cure_timers[target_name] or 0) then
        log(string.format('Cure suppressed for %s (%.1fs)', target_name,
            (S.cure_timers[target_name] or 0) - now()))
        return false
    end
    local tiers = get_cure_tiers()
    if #tiers == 0 then return false end
    -- Start at tier[2] when multiple tiers exist (skips Cure IV
    -- for high-level players); fall back to tier[1] only when
    -- the player has just one cure spell.
    local start_idx = (#tiers >= 2) and 2 or 1
    for i = start_idx, #tiers do
        if cast_on_target(tiers[i], target_name) then
            S.cure_timers[target_name] = now() + POST_CURE_SUPPRESS
            return true
        end
    end
    return false
end

-- ----------------------------------------------------------------
-- Brd ANTI-OVERCURE
-- ----------------------------------------------------------------
-- pick_brd_tier(headroom): from the cure tiers the player can cast,
-- return the LARGEST tier whose estimated heal * (1 + buffer) still
-- fits inside headroom -- i.e. the biggest cure that won't push the
-- Brd above the ceiling. `headroom` is ceiling_hp - current_hp, NOT
-- full missing HP. Returns the spell name, or nil if even the smallest
-- tier (Cure I) would exceed headroom (caller should then NOT cast).
-- pick_brd_tier(headroom, hp_pct): from the cure tiers the player can
-- cast, return the LARGEST tier whose estimated heal * (1 + buffer)
-- still fits inside headroom -- the biggest cure that won't push the
-- Brd above the ceiling. `headroom` is ceiling_hp - current_hp, NOT
-- full missing HP. The TOP tier (tiers[1], Cure IV for a high-level
-- player) is excluded unless hp_pct <= BRD_TOP_TIER_PCT (25%): top
-- tier overheals too easily and its potency estimate is unreliable,
-- so it's hard-gated to genuine emergencies. Returns the spell name,
-- or nil if no allowed tier fits (caller should then NOT cast).
local function pick_brd_tier(headroom, hp_pct)
    local tiers = get_cure_tiers()
    if #tiers == 0 then return nil end
    -- Index of the first tier we're allowed to consider. When more
    -- than one tier exists and the Brd is above the top-tier gate,
    -- skip tiers[1] (the top tier). Below the gate, top tier is on
    -- the table.
    local start_idx = 1
    if #tiers >= 2 and (hp_pct == nil or hp_pct > BRD_TOP_TIER_PCT) then
        start_idx = 2
    end
    local best = nil
    local best_est = -1
    for i = start_idx, #tiers do
        local spell = tiers[i]
        local est = CURE_HP_EST[spell]
        if est then
            local needed = est * (1 + BRD_OVERCURE_BUFFER)
            -- Tier fits if its buffered estimate doesn't exceed the
            -- headroom to the ceiling. Among all fitting tiers, keep
            -- the one with the highest raw estimate (the largest cure
            -- that still won't cross the ceiling).
            if needed <= headroom and est > best_est then
                best = spell
                best_est = est
            end
        end
    end
    return best
end

-- cast_brd_cure(target_name): anti-overcure cast for a Brd-enrolled
-- member. Reads LIVE absolute HP (re-check right before the cast, per
-- the design -- the snapshot may be stale), computes missing HP, picks
-- the largest non-overhealing tier, and fires it. On a successful send
-- it records brd_cast_target / brd_cast_missing_at so the per-tick
-- mid-cast abort (handled at the top of tick) can kneel-cancel via
-- /heal if the target gets topped off while the cure is still flying.
-- Returns true if a cure was sent.
local function cast_brd_cure(target_name)
    if now() < (S.cure_timers[target_name] or 0) then
        return false
    end
    local hp, max_hp, missing = Mob.live_hp(target_name)
    if not hp or not max_hp or max_hp <= 0 then return false end
    -- Live HP% for the top-tier gate (Cure IV only below 25%).
    local hp_pct = math.floor(hp * 100 / max_hp + 0.5)
    -- Headroom to the ceiling, NOT full missing HP. We never cure a Brd
    -- above BRD_CURE_CEILING_PCT of MaxHP, so the cure must fit inside
    -- (ceiling_hp - current_hp).
    local ceiling_hp = math.floor(BRD_CURE_CEILING_PCT * max_hp)
    local headroom   = ceiling_hp - hp
    -- Already at/above the ceiling -> nothing to do.
    if headroom <= 0 then return false end
    -- Pre-cast re-check: if no allowed tier fits without crossing the
    -- ceiling, don't cast at all (this is the "drop a tier OR more ->
    -- or skip" end of the cascade). Top tier is gated to <=25% inside
    -- pick_brd_tier.
    local spell = pick_brd_tier(headroom, hp_pct)
    if not spell then
        log(string.format('Brd %s: headroom %d HP (ceiling %d%%) too small for any tier - holding',
            target_name, headroom, math.floor(BRD_CURE_CEILING_PCT * 100)))
        return false
    end
    if cast_on_target(spell, target_name) then
        S.cure_timers[target_name] = now() + POST_CURE_SUPPRESS
        S.brd_cast_target     = target_name
        S.brd_cast_missing_at = headroom
        log(string.format('Brd anti-overcure: %s on %s (headroom %d HP to %d%%, est %d)',
            spell, target_name, headroom, math.floor(BRD_CURE_CEILING_PCT * 100),
            CURE_HP_EST[spell] or 0))
        return true
    end
    return false
end

-- brd_check_midcast_abort(): called every tick from the top of tick().
-- If a Brd-target cure is in flight (S.brd_cast_target set while
-- S.is_casting), re-read the target's LIVE HP. If they've recovered
-- enough that the in-flight cure would now overheal -- i.e. the cure's
-- buffered estimate exceeds their CURRENT missing HP -- kneel-cancel
-- the cast by sending /heal (which interrupts an in-progress cast on
-- HorizonXI), then immediately stand back up so the bot keeps working.
-- Clears the tracking either way once the cast is no longer in flight.
local function brd_check_midcast_abort()
    local tname = S.brd_cast_target
    if not tname then return end
    -- Cast already resolved/cleared -> nothing in flight to abort.
    if not S.is_casting then
        S.brd_cast_target     = nil
        S.brd_cast_missing_at = 0
        return
    end
    -- Only abort the cast we actually started for this Brd target.
    if S.last_spell_target_name ~= tname then return end
    local spell = S.last_spell_sent_raw
    local est   = spell and CURE_HP_EST[spell]
    if not est then return end
    local hp, max_hp = Mob.live_hp(tname)
    if not hp or not max_hp or max_hp <= 0 then return end
    -- Live headroom to the ceiling. If the in-flight cure's buffered
    -- estimate would now push the Brd past the ceiling (they've been
    -- healed up since we started casting), abort.
    local ceiling_hp = math.floor(BRD_CURE_CEILING_PCT * max_hp)
    local headroom   = ceiling_hp - hp
    if est * (1 + BRD_OVERCURE_BUFFER) > headroom then
        cprint(string.format(
            'Brd %s recovered mid-cast (headroom %d to %d%%, %s heals ~%d) - /heal cancel',
            tname, headroom, math.floor(BRD_CURE_CEILING_PCT * 100), spell, est))
        -- Kneel-cancel the cast. A single /heal interrupts the
        -- in-progress cast on HorizonXI (you cannot cast while
        -- kneeling, so issuing /heal mid-cast aborts it). We send
        -- exactly ONE /heal here -- sending a second to stand back up
        -- in the same frame races the first (both QueueCommands are
        -- processed back-to-back and may not register as two distinct
        -- rest toggles). Instead we reset cast tracking and let the
        -- normal stand logic at the bottom of tick() bring the player
        -- up on a following tick once the rest-toggle throttle clears;
        -- a brief kneel is harmless (free MP/HP ticks). The throttle
        -- and stand lock are set the same way rest_down/stand_up do.
        send(REST_CMD)
        S.rest_toggle_at      = now() + (S.rest_toggle_cd or 3.0)
        spell_clear()
        S.spell_lock_until    = 0.0
        S.brd_cast_target     = nil
        S.brd_cast_missing_at = 0
    end
end

-- Returns the next name needing Refresh, or nil.
-- Recast trigger is buff absence in the StatusHandler packet cache --
-- the buff cache is the source of truth, NOT the addon-side timer.
-- Early buff drops (dispel, death, zone, silent missed cast) need to
-- be caught immediately, which a timer-based gate cannot do.
--
-- refresh_timers[name] is still written on every cast and read by the
-- GUI for a "Xs until expected wear-off" countdown, but it has no
-- gating role here. spell_ready('Refresh') (checked above) is the
-- spam guard: ~16s spell cooldown is more than enough for the buff
-- confirmation packet to land before we consider the same target
-- again.
--
-- The buff-visibility check is what stops back-to-back same-tier
-- overwrites: FFXI returns "No effect" if we /ma Refresh while the
-- buff is still on, and the action packet for that failed attempt
-- never matches our cast-confirmed handler, so retrying would spin in
-- a 16-second-cooldown loop. As long as we wait for the cache to show
-- the buff GONE, the recast lands clean.
--
-- Self is now an opt-in checkbox in refresh_extras (slot 0), the
-- same way Haste handles it. The old auto-self path is gone: if you
-- want yourself refreshed, tick your own box.
-- skip_name (optional): a member name to exclude from this pass. Used
-- by the resting branch in tick() to re-query for "anyone but me" when
-- self came back as the next target but our MP is below 100% (resting
-- to refill is cheaper than standing up just to self-Refresh).
function Tgt.next_refresh_target(skip_name)
    if not S.refresh_enabled then return nil end
    if not refresh_usable() then return nil end
    if not spell_ready('Refresh') then return nil end

    local pm = party()
    local function consider(tname)
        if not tname or tname == '' then return nil end
        if skip_name and tname == skip_name then return nil end
        -- Buff cache is the source of truth for recast. Timer kept for
        -- the GUI countdown only -- early drops (dispel, death, zone,
        -- silent missed cast) bypass the timer entirely and need the
        -- buff-absent check to catch them. spell_ready('Refresh')
        -- (checked above) is the spam guard: ~16s lockout between
        -- casts is more than enough for the buff confirmation packet
        -- to land in the StatusHandler cache.
        local in_range    = false
        local buff_absent = true
        if pm then
            for slot = 0, 5 do
                if n(pm:GetMemberIsActive(slot)) == 1 then
                    local mname = pm:GetMemberName(slot) or ''
                    if mname == tname then
                        if slot == 0 then
                            in_range    = true
                            buff_absent = not self_has_buff(BUFF.REFRESH)
                        else
                            in_range    = get_member_distance(slot) <= CFG.CURE_RANGE
                            buff_absent = not party_slot_has_buff(slot, BUFF.REFRESH)
                        end
                        break
                    end
                end
            end
        end
        if in_range and buff_absent then return tname end
        return nil
    end

    for i = 1, 6 do
        local tname = S.refresh_extras[i]
        if tname and tname ~= '' and S.refresh_priority[tname] then
            local hit = consider(tname)
            if hit then return hit end
        end
    end

    for i = 1, 6 do
        local tname = S.refresh_extras[i]
        if tname and tname ~= '' and not S.refresh_priority[tname] then
            local hit = consider(tname)
            if hit then return hit end
        end
    end

    return nil
end

-- Returns the next name needing Haste, or nil.
-- Iterates through haste_targets in order; skips empty slots and targets that
-- already have Haste active (entity buff check) or whose timer hasn't expired.
function Tgt.next_haste_target()
    if not S.haste_enabled then return nil end
    if not haste_usable() then return nil end
    if not spell_ready('Haste') then return nil end

    local pm = party()

    -- Two-pass scan: priority members first, then everyone else. See
    -- Tgt.next_refresh_target's matching block for the rationale; this
    -- mirrors that pattern but keeps Haste's self-aware slot 0 path.
    local function consider(tname)
        if not tname or tname == '' then return nil end
        -- Buff cache is the source of truth; see Tgt.next_refresh_target
        -- for the full rationale. spell_ready('Haste') is the spam guard.
        local in_range    = false
        local buff_absent = true
        if pm then
            for slot = 0, 5 do
                if n(pm:GetMemberIsActive(slot)) == 1 then
                    local mname = pm:GetMemberName(slot) or ''
                    if mname == tname then
                        if slot == 0 then
                            in_range    = true
                            buff_absent = not self_has_buff(BUFF.HASTE)
                        else
                            in_range    = get_member_distance(slot) <= CFG.CURE_RANGE
                            buff_absent = not party_slot_has_buff(slot, BUFF.HASTE)
                        end
                        break
                    end
                end
            end
        end
        if in_range and buff_absent then return tname end
        return nil
    end

    for i = 1, 6 do
        local tname = S.haste_targets[i]
        if tname and tname ~= '' and S.haste_priority[tname] then
            local hit = consider(tname)
            if hit then return hit end
        end
    end

    for i = 1, 6 do
        local tname = S.haste_targets[i]
        if tname and tname ~= '' and not S.haste_priority[tname] then
            local hit = consider(tname)
            if hit then return hit end
        end
    end

    return nil
end

-- Returns the first party member name (p0->p5) who has Paralysis, or nil.
function Tgt.next_paralyna_target()
    if not S.paralyna_enabled then return nil end
    if not spell_ready('Paralyna') then return nil end
    if not spell_usable('Paralyna') then return nil end
    local pm = party()
    if not pm then return nil end
    for slot = 0, 5 do
        if n(pm:GetMemberIsActive(slot)) == 1 then
            local mname = pm:GetMemberName(slot) or ''
            if mname ~= '' then
                local has_para = false
                if slot == 0 then
                    has_para = self_has_buff(BUFF.PARALYSIS)
                else
                    has_para = party_slot_has_buff(slot, BUFF.PARALYSIS)
                end
                -- Range gate: self (slot 0) is always reachable; other
                -- members must be within CURE_RANGE or the cast fails
                -- server-side and blocks closer-needed actions.
                local in_range = (slot == 0)
                                 or (get_member_distance(slot) <= CFG.CURE_RANGE)
                if has_para and in_range then
                    return mname
                end
            end
        end
    end
    return nil
end

-- Returns the first party member name (p0->p5) who has Silence, or nil.
function Tgt.next_silena_target()
    if not S.silena_enabled then return nil end
    if not spell_ready('Silena') then return nil end
    if not spell_usable('Silena') then return nil end
    local pm = party()
    if not pm then return nil end
    for slot = 0, 5 do
        if n(pm:GetMemberIsActive(slot)) == 1 then
            local mname = pm:GetMemberName(slot) or ''
            if mname ~= '' then
                local has_silence = false
                if slot == 0 then
                    has_silence = self_has_buff(BUFF.SILENCE)
                else
                    has_silence = party_slot_has_buff(slot, BUFF.SILENCE)
                end
                local in_range = (slot == 0)
                                 or (get_member_distance(slot) <= CFG.CURE_RANGE)
                if has_silence and in_range then
                    return mname
                end
            end
        end
    end
    return nil
end

-- Returns the first party member name (p0->p5) who has Poison, or nil.
function Tgt.next_poisona_target()
    if not S.poisona_enabled then return nil end
    if not spell_ready('Poisona') then return nil end
    if not spell_usable('Poisona') then return nil end
    local pm = party()
    if not pm then return nil end
    for slot = 0, 5 do
        if n(pm:GetMemberIsActive(slot)) == 1 then
            local mname = pm:GetMemberName(slot) or ''
            if mname ~= '' then
                local has_poison = false
                if slot == 0 then
                    has_poison = self_has_buff(BUFF.POISON)
                else
                    has_poison = party_slot_has_buff(slot, BUFF.POISON)
                end
                local in_range = (slot == 0)
                                 or (get_member_distance(slot) <= CFG.CURE_RANGE)
                if has_poison and in_range then
                    return mname
                end
            end
        end
    end
    return nil
end

-- Returns the first party member name (p0->p5) who has Blindness, or nil.
-- Same pattern as Paralyna/Silena/Poisona.
function Tgt.next_blindna_target()
    if not S.blindna_enabled then return nil end
    if not spell_ready('Blindna') then return nil end
    if not spell_usable('Blindna') then return nil end
    local pm = party()
    if not pm then return nil end
    for slot = 0, 5 do
        if n(pm:GetMemberIsActive(slot)) == 1 then
            local mname = pm:GetMemberName(slot) or ''
            if mname ~= '' then
                local has_blind = false
                if slot == 0 then
                    has_blind = self_has_buff(BUFF.BLIND)
                else
                    has_blind = party_slot_has_buff(slot, BUFF.BLIND)
                end
                local in_range = (slot == 0)
                                 or (get_member_distance(slot) <= CFG.CURE_RANGE)
                if has_blind and in_range then
                    return mname
                end
            end
        end
    end
    return nil
end

-- Returns the first party member name (p0->p5) in range who is missing Regen, or nil.
-- Returns the first named regen target in range who is missing Regen, or nil.
function Tgt.next_regen_target()
    if not S.regen_enabled then return nil end
    if not spell_ready('Regen') then return nil end
    if not spell_usable('Regen') then return nil end
    local pm = party()
    if not pm then return nil end

    for i = 1, 6 do
        local tname = S.regen_targets[i]
        if tname and tname ~= '' then
            -- Buff cache is the source of truth; timer gate dropped here too.
            -- See Tgt.next_refresh_target for the full rationale.
            local in_range = false
            local buff_absent = true
            for slot = 0, 5 do
                if n(pm:GetMemberIsActive(slot)) == 1 then
                    local mname = pm:GetMemberName(slot) or ''
                    if mname == tname then
                        if slot == 0 then
                            in_range    = true
                            buff_absent = not self_has_buff(BUFF.REGEN)
                        else
                            in_range    = get_member_distance(slot) <= CFG.CURE_RANGE
                            buff_absent = not party_slot_has_buff(slot, BUFF.REGEN)
                        end
                        break
                    end
                end
            end
            if in_range and buff_absent then
                return tname
            end
        end
    end
    return nil
end

-- Returns the next name needing Protect (or Shell, via the shared helper
-- below), or nil. Buff cache is the source of truth -- same buff-cache-
-- as-truth pattern as Tgt.next_refresh_target. spell_ready on the
-- highest-tier name (e.g. 'Protect IV') is the spam guard.
local function next_partybuff_target_by_buff(targets_arr, tier_spell, buff_id)
    if not tier_spell then return nil end
    if not spell_ready(tier_spell) then return nil end
    local pm = party()
    if not pm then return nil end
    for i = 1, 6 do
        local tname = targets_arr[i]
        if tname and tname ~= '' then
            local in_range    = false
            local buff_absent = true
            for slot = 0, 5 do
                if n(pm:GetMemberIsActive(slot)) == 1 then
                    local mname = pm:GetMemberName(slot) or ''
                    if mname == tname then
                        if slot == 0 then
                            in_range    = true
                            buff_absent = not self_has_buff(buff_id)
                        else
                            in_range    = get_member_distance(slot) <= CFG.CURE_RANGE
                            buff_absent = not party_slot_has_buff(slot, buff_id)
                        end
                        break
                    end
                end
            end
            if in_range and buff_absent then
                return tname
            end
        end
    end
    return nil
end

function Tgt.next_protect_target()
    if not S.protect_enabled then return nil end
    if not protect_usable()  then return nil end
    return next_partybuff_target_by_buff(S.protect_targets, highest_protect_tier(), BUFF.PROTECT)
end

function Tgt.next_shell_target()
    if not S.shell_enabled then return nil end
    if not shell_usable()  then return nil end
    return next_partybuff_target_by_buff(S.shell_targets, highest_shell_tier(), BUFF.SHELL)
end
---------------------------------------------------------------------

local function parse_player_casts_name(text)
    if type(text) ~= 'string' then return nil end

    local sl = sanitize_log_text(text):lower()
    local spell = nil
    local player_pat = get_player_name_pattern()
    -- from_active: true if the chat line PROVES the player actively
    -- cast the spell ("Player casts X"). false for the passive buff-
    -- application patterns ("Player gains/receives the effect of X")
    -- which can be triggered by other party members buffing us (bard
    -- ballad, party Refresh, etc.). Callers gate side effects like
    -- stand-lock refresh on this flag so a Ballad land from the
    -- party bard doesn't get credited as our cast.
    local from_active = false

    if player_pat then
        -- Pattern A: "Playername casts Refresh on <target>." or
        -- "Playername casts Refresh." -- the standard completion line
        -- FFXI emits for damage/heal/party-target casts. NO ^ anchor:
        -- FFXI sometimes joins consecutive battle-log lines into a
        -- single text_in event ("Maty hits the Flamingo for 45 points
        -- of damage. Playername casts Refresh."). ([^.]+) caps the
        -- capture at the next period.
        spell = sl:match(player_pat .. '%s+casts%s+([^.]+)')
        if spell then from_active = true end

        -- Pattern B: "Playername gains the effect of Reraise." --
        -- the actual completion event for SELF-CAST SELF-TARGET buffs
        -- (Reraise, Stoneskin, Blink, self-Refresh, self-Haste,
        -- self-Regen, etc.). FFXI does NOT emit a "Player casts X"
        -- line for these; the effect-application line IS the
        -- completion signal. Without this fallback the addon timed
        -- out every self-buff cast because pattern A never matched.
        -- Two phrasings cover both party-buff-on-self ("gains the
        -- effect of") and self-cast ("receives the effect of") --
        -- variants seen on different FFXI servers and language packs.
        --
        -- AMBIGUITY: these patterns ALSO match when another player
        -- buffs us (bard Ballad, party Refresh). from_active stays
        -- false for these, and callers use that to suppress the
        -- unconditional stand-lock refresh. The match-block
        -- complete_cast still runs when last_spell_sent matches (our
        -- own self-buff cast completing) and refreshes stand-lock
        -- through its own path.
        if not spell then
            spell = sl:match(player_pat .. "'?s?%s+gains%s+the%s+effect%s+of%s+([^.]+)")
        end
        if not spell then
            spell = sl:match(player_pat .. "'?s?%s+receives%s+the%s+effect%s+of%s+([^.]+)")
        end
    end
    if not spell then
        return nil
    end

    return normalize_action_name(spell), from_active
end

-- Parses line 1: "Playername starts casting Spellname on Target."
-- Returns the normalized spell name, or nil.
local function parse_player_starts_casting(text)
    if type(text) ~= 'string' then return nil end

    local sl = sanitize_log_text(text):lower()
    local player_pat = get_player_name_pattern()
    if not player_pat then return nil end

    -- Two variants. FFXI shows "Player starts casting Spell on
    -- Target." for party/mob-target casts, but for SELF-TARGET it can
    -- omit the "on Target" tail entirely ("Player starts casting
    -- Spell."). The original "on target"-required pattern silently
    -- missed every self-cast start, leaving the starts_casting
    -- timeout bump (and the manual_cast_until / stand-lock refresh
    -- that go with it) unset. NO ^ anchor on either pattern: FFXI
    -- joins this line with adjacent battle log sometimes, so the
    -- player name can appear mid-string.
    local spell = sl:match(player_pat .. '%s+starts%s+casting%s+(.-)%s+on%s+')
    if not spell then
        -- "Playername starts casting Reraise." (self-target, no
        -- explicit "on target"). ([^.]+) caps at the next period.
        spell = sl:match(player_pat .. '%s+starts%s+casting%s+([^.]+)')
    end
    if not spell then return nil end

    return normalize_action_name(spell)
end

-- Detects FFXI's "You cannot use that command while healing."
-- rejection -- emitted when ANY command (cast, weapon skill, /follow,
-- etc.) is issued while resting. For this addon it almost always
-- means a tick-side cascade is missing its player_is_resting() gate
-- and tried to fire a /ma during rest. The chat parser uses this
-- to cprint (always, ungated by debug) the most recent command we
-- pushed through send() so the offending site is identifiable from
-- chat alone.
local function is_cannot_use_command_while_healing(text)
    if type(text) ~= 'string' then return false end
    local sl = sanitize_log_text(text):lower()
    local stripped = sl:gsub('[%s%.%!%?]+$', '')
    return stripped == 'you cannot use that command while healing'
end

local function is_player_cast_interrupted_exact(text)
    if type(text) ~= 'string' then return false end

    local sl = sanitize_log_text(text):lower()

    -- Strip trailing punctuation/whitespace before comparison.
    -- Cause we ARE solving here: a single deviating character in
    -- the server's log line ("!" instead of ".", past tense, etc.)
    -- causes the matcher to miss, fail_cast_retry never fires,
    -- spell_clear never runs, and the cast-timeout fallback in
    -- tick() then mis-marks the spell as COMPLETED -- writing the
    -- recast as if the cast landed. The next eligible refresh
    -- cycle is then blocked for the full server recast even
    -- though the cast was actually interrupted.
    --
    -- Variants observed / defended against:
    --   "Your casting is interrupted."   <- retail standard
    --   "Your casting is interrupted!"   <- punctuation variant
    --   "Your casting was interrupted."  <- past tense
    --   "Your spell is interrupted."     <- alternate noun
    --   plus all of the above in 3rd-person form ("<Player>'s ...").
    local stripped = sl:gsub('[%s%.%!%?]+$', '')

    -- Self forms ("Your ...").
    if stripped == 'your casting is interrupted'
       or stripped == 'your casting was interrupted'
       or stripped == 'your spell is interrupted'
       or stripped == 'your spell was interrupted' then
        return true
    end

    -- 3rd-person forms ("<Player>'s ..."). Compared after the
    -- trailing-punctuation strip so "Playername's casting is
    -- interrupted!" matches the same as "...interrupted." .
    local pname = get_player_name_lower()
    if pname then
        local prefix = pname .. "'s "
        if stripped == prefix .. 'casting is interrupted'
           or stripped == prefix .. 'casting was interrupted'
           or stripped == prefix .. 'spell is interrupted'
           or stripped == prefix .. 'spell was interrupted' then
            return true
        end
    end

    return false
end

local function is_unable_cast_spells_time(text)
    if type(text) ~= 'string' then return false end
    local sl = sanitize_log_text(text):lower()
    return sl:find('unable to cast spells at this time', 1, true) ~= nil
end

-- Catches the other in-game "spell didn't take effect" lines that
-- previously left the addon waiting for a casts_name event that
-- would never come. Without these the addon sits through a 6s
-- cast_timeout for every silent fail. Patterns checked with :find
-- (case-insensitive substring) rather than equality, because the
-- exact phrasing varies and FFXI sometimes joins them with adjacent
-- log lines.
local function is_silent_cast_fail(text)
    if type(text) ~= 'string' then return false, nil end
    local sl = sanitize_log_text(text):lower()
    -- "Out of range." / "<target> is too far away." / "Target is too far away."
    if sl:find('out of range', 1, true)        then return true, 'out of range'         end
    if sl:find('too far away', 1, true)        then return true, 'too far away'         end
    -- "Cannot see the target." / "You cannot see the target."
    if sl:find('cannot see', 1, true)          then return true, 'cannot see target'    end
    -- "The spell had no effect." / "No effect on <target>."
    if sl:find('had no effect', 1, true)       then return true, 'no effect'            end
    if sl:find('no effect on', 1, true)        then return true, 'no effect on target'  end
    -- "Target is not within line of sight."
    if sl:find('line of sight', 1, true)       then return true, 'line of sight'        end
    -- "<target> is not a valid target."
    if sl:find('is not a valid target', 1, true) then return true, 'invalid target'     end
    -- "There are no valid targets." (cast went to <bt> with nothing engaged)
    if sl:find('no valid targets', 1, true)    then return true, 'no valid targets'     end
    return false, nil
end

local function is_not_enough_mp_line(text)
    if type(text) ~= 'string' then return false end
    local sl = sanitize_log_text(text):lower()
    return sl:find('not enough mp', 1, true) ~= nil
        or sl:find('do not have enough mp', 1, true) ~= nil
end

---------------------------------------------------------------------
-- TICK
---------------------------------------------------------------------

-- Process pending manual buttons (Dispel / Sleep / Bind) when the bot is
-- stopped. The running path handles them inline at their usual priority
-- slot (just under emergency cure, see tick() body); this helper is only
-- called from the stopped branch of tick() so a Stop'd bot still responds
-- to direct user button presses. Force Rest still blocks (stand_up isn't
-- passed the override flag), matching existing manual-button behavior.
local function try_manual_buttons_stopped()
    -- Buff-detection completion path (same as running tick). Even
    -- with the bot stopped, a manual cast the user fires can clear
    -- via the buff appearing on the player.
    try_buff_completion()

    -- Cast-timeout fallback. When neither the buff-detection path
    -- nor the chat-log parser caught the cast completion within
    -- cast_time + ANIMATION_END_SEC + 1.0, assume the cast DID
    -- land but we missed both signals -- treat as a completed
    -- cast (complete_cast sets buff timers, runs stand-lock,
    -- clears is_casting) rather than as a failure. Treating it as
    -- failure used to leave the cooldown intact AND lock the bot
    -- in a recast loop. Suppressed when S.timeout_disable is on
    -- (diagnostic mode).
    if not S.timeout_disable
       and S.is_casting and S.cast_timeout_at > 0.0 and now() >= S.cast_timeout_at then
        complete_cast('timeout')
    end

    if spell_locked() then return end

    if S.dispel_pending then
        -- Dispel the TRACKED mob (S.debuff_mob_sid), never <bt>. <bt>
        -- resolves to whatever the client feels like -- with adds around
        -- that can be a completely different mob than the one the bot is
        -- working, which is exactly the drift this addon no longer has to
        -- live with. If nothing is tracked there is nothing to dispel, so
        -- cancel rather than fire blind.
        local dsid = n(S.debuff_mob_sid)
        if not spell_ready('Dispel') or not spell_usable('Dispel')
            or P.player_mp() < SPELL_MP_COST['Dispel']
        then
            log('Dispel: unavailable, cancelling')
            S.dispel_pending = false
        elseif dsid == 0 then
            log('Dispel: no tracked mob, cancelling')
            S.dispel_pending = false
        elseif P.player_is_resting() then
            if stand_up('Stand for Dispel') then return end
        else
            if cast_on_target('Dispel', dsid) then
                S.dispel_pending = false
            end
            return
        end
    end

    if spell_locked() then return end

    if S.sleep_pending then
        if not spell_ready('Sleep') or not spell_usable('Sleep')
            or P.player_mp() < SPELL_MP_COST['Sleep']
        then
            log('Sleep: unavailable, cancelling')
            S.sleep_pending = false
        elseif P.player_is_resting() then
            if stand_up('Stand for Sleep') then return end
        else
            if cast_on_target('Sleep', '<t>') then
                S.sleep_pending = false
            end
            return
        end
    end

    if spell_locked() then return end

    if S.bind_pending then
        if not spell_ready('Bind') or not spell_usable('Bind')
            or P.player_mp() < SPELL_MP_COST['Bind']
        then
            log('Bind: unavailable, cancelling')
            S.bind_pending = false
        elseif P.player_is_resting() then
            if stand_up('Stand for Bind') then return end
        else
            if cast_on_target('Bind', '<t>') then
                S.bind_pending = false
            end
        end
    end
end

local function tick()
    -- Poll player position EVERY tick (even when stopped) so
    -- S.last_movement_at is current before any cast attempt in this
    -- tick reads it. The movement gate inside cast_on_target uses
    -- this to refuse /ma while moving -- without this poll, the
    -- gate would never trigger.
    poll_player_movement()

    -- Detect party composition changes and evict target-array entries for
    -- members who left. Members still present are untouched. This replaces
    -- the old "you had to /addon reload to notice party changes" behavior.
    --
    -- Runs BEFORE the not-running gate so the per-member Cure / Emg.Cure
    -- GUI checkboxes have clean exclusion arrays to work with after a
    -- reload, even before the user presses /bm start. Otherwise stale
    -- names restored from saved settings can occupy all 6 slots of
    -- cure_only_emergency / emergency_cure_excluded, and unchecking a
    -- current party member silently fails (no empty slot to add to);
    -- the box visually flips back to checked on the next render.
    Mob.prune_stale_party_targets()

    if not S.running then
        -- Manual buttons (Dispel/Sleep/Bind) are direct user intent and
        -- still need to work when the auto-bot is stopped. When running,
        -- the existing inline blocks below handle them at their normal
        -- priority slot (just under emergency cure), so a 50%-HP ally
        -- still wins over a Dispel press.
        if S.dispel_pending or S.sleep_pending or S.bind_pending then
            try_manual_buttons_stopped()
        end
        return
    end

    -- Refresh party buff cache from memory every tick.
    -- StatusHandler is what bovinebattle/packet_parser use too; 0x076
    -- packets already update it live, this is a belt-and-suspenders
    -- read so buffs that existed before we loaded (Refresh/Regen/Haste
    -- that were already up) show up immediately.
    if StatusHandler and type(StatusHandler.refreshFromMemory) == 'function' then
        pcall(StatusHandler.refreshFromMemory)
    end

    -- (No buff-keepalive on the three convenience-buff timers.)
    -- All three -- Refresh, Haste, Regen -- now run on a pure
    -- "time guard + buff-visibility guard" model: cast confirmation
    -- sets timers[name] to a fixed duration in the future, and the
    -- corresponding next_<spell>_target() helper refuses to return a
    -- target whose buff is still visible. Without the keep-alive, the
    -- GUI countdown is honest -- it reads timers[name] - now()
    -- directly, ticking down from the post-cast value to 0/"due"
    -- without any "stuck at 10s" stall. The visibility guard inside
    -- each target helper is what prevents the addon from spamming
    -- /ma "<spell>" while the previous cast is still up (FFXI rejects
    -- same-tier overwrites with "No effect" and the failed attempt
    -- never updates the timer, which would otherwise spin in the
    -- 16s-spell-cooldown retry loop).

    -- Detect a manual stand-up and give the player a grace window.
    -- If we were resting last tick, aren't now, and the bot didn't just
    -- stand us up (stand lock already active in that case), treat it as
    -- the player standing up manually and refresh the stand lock so
    -- rest_down can't slam them back into /heal.
    do
        -- Force Rest 3-min timer expiry. Clears the flag so the idle
        -- branch can resume normal rest/stand decisions. If Disable Rest
        -- is also on, it will stand the player up on the very next pass.
        if S.force_rest and S.force_rest_until > 0 and now() >= S.force_rest_until then
            log('Force Rest: timer expired, releasing')
            S.force_rest = false
            S.force_rest_until = 0.0
        end

        local is_resting_now = P.player_is_resting()
        if S.was_resting and not is_resting_now and not standing_locked() then
            log('Manual stand detected - holding standing lock')
            refresh_stand_lock('manual-stand')
            -- ALSO refresh last_stand_at so cast_on_target's
            -- STAND_SETTLE_SEC gate applies the same way as for a
            -- bot-initiated stand. Without this, a manual stand
            -- leaves last_stand_at stale (zero / from a prior addon
            -- /heal) and the cascade fires /ma into the standing
            -- animation -> server "Unable to cast spells at this
            -- time". Set 0.25s into the future to absorb the tick-
            -- polling latency: we only NOTICE the stand at the next
            -- tick boundary after the player actually stood, which
            -- can be ~100ms late; without the bump the effective
            -- settle window shrinks to ~0.3s, just inside the
            -- server's animation window.
            S.last_stand_at = now() + 0.25
        end
        -- Track when the current rest began so the Auto Full Rest gate
        -- can tell "we just sat down" from "we've been sitting a while".
        -- Clear to 0 any time we're not resting so stale timestamps don't
        -- survive a stand/rest cycle.
        if is_resting_now and not S.was_resting then
            S.rest_started_at = now()
        elseif not is_resting_now then
            S.rest_started_at = 0.0
        end
        S.was_resting = is_resting_now
    end

    -- Stop immediately if the player is dead
    if P.player_is_dead() then
        S.running = false
        spell_clear()
        cprint('Player is dead - stopped')
        return
    end

    Mob.prune_claimed_targets()

    -- Buff-detection completion path. Runs BEFORE the timeout check
    -- so a successful self-cast can clear is_casting via the buff
    -- transition instead of either waiting for the timeout budget
    -- (which we've disabled while tuning) or for a chat-line match
    -- (which never arrives for Reraise on HorizonXI). See the
    -- try_buff_completion definition for guard conditions.
    try_buff_completion()

    -- Cast-timeout fallback. Third completion signal after buff
    -- detection (try_buff_completion above) and the chat-log
    -- parser (parse_player_casts_name in the text_in handler). If
    -- none of the three has cleared is_casting within cast_time +
    -- ANIMATION_END_SEC + 1.0, we assume the cast DID complete but
    -- the addon missed both signals (the chat lines for self-cast
    -- on Horizon are unreliable; the buff-icon update can lag the
    -- 0x076 packet cadence). complete_cast('timeout') runs the
    -- same path as a buff/log confirmation: sets buff timers, the
    -- post-cast settle (POST_CAST_SETTLE_BUFF, same as buff path
    -- because the animation may not yet be done), refresh_stand_lock,
    -- and clears the in-flight state. Suppressed when S.timeout_disable
    -- is on (diagnostic mode for measuring real `took` values).
    if not S.timeout_disable
       and S.is_casting and S.cast_timeout_at > 0.0 and now() >= S.cast_timeout_at then
        complete_cast('timeout')
    end

    -- Brd anti-overcure mid-cast abort. Runs after the completion/
    -- timeout handlers above (so is_casting reflects the current cast
    -- state) and before cure selection: if a Brd-target cure is still
    -- in flight and the target has recovered enough that it would now
    -- overheal, kneel-cancel it via /heal here.
    brd_check_midcast_abort()

    local snap         = Mob.get_party_snapshot()
    local claimed_mobs = Mob.get_claimed_mobs_in_range()

    local emergency_cure = nil
    -- Sibling flag: true when emergency_cure was set by the DRG
    -- Healer Mode path. With DRG mode ON, the regular emergency
    -- band selection in the snapshot loop below is bypassed for
    -- anyone in DRG Healer's territory (HP <= DRG_HEALER_THRESHOLD),
    -- so the DRG Healer path becomes the sole writer of
    -- emergency_cure -- this flag will be true whenever
    -- emergency_cure is non-nil while DRG mode is on. With DRG
    -- mode OFF, the regular emergency band runs as normal and
    -- the flag stays false (DRG Healer block doesn't execute).
    -- Pipes through to skip_top so DRG Healer cures cap at 2nd
    -- tier (Cure III / 46 MP); the wyvern's Healing Breath is
    -- the primary heal in a DRG party, the mage just catches
    -- gaps -- 88-MP Cure IV is wasted MP in that configuration.
    local emergency_cure_from_drg = false
    local normal_cure    = nil
    -- Brd anti-overcure candidate. Set from the snapshot loop when a
    -- Brd-enrolled member is below the normal cure threshold; healed by
    -- cast_brd_cure (tier picked to never overheal) instead of the
    -- normal/emergency paths, which skip Brd members entirely.
    local brd_cure       = nil

    -- Disable Cure master kill switch: skip ALL cure candidate
    -- selection (standard loop AND DRG Healer). emergency_cure and
    -- normal_cure stay nil, so every downstream firing branch is a
    -- no-op. Per-member Cure/Emg.Cure columns are the normal granular
    -- control; this is just a panic button.
    if not S.disable_cure then

    for _, m in ipairs(snap) do
        if m.active and m.name ~= '---' and m.hp_pct > 0 and m.dist <= CFG.CURE_RANGE then
            -- Per-member exclusion checks. Both lists are inclusion-by-
            -- default, exclusion-by-name: an empty list means everyone
            -- is included. The GUI's two-row layout writes into these.
            local in_cure_excl = false
            local in_emerg_excl = false
            local in_brd = false
            for i = 1, 6 do
                local nm_i = (S.cure_only_emergency[i] or '')
                if nm_i == m.name then in_cure_excl = true end
                local nm_e = (S.emergency_cure_excluded[i] or '')
                if nm_e == m.name then in_emerg_excl = true end
                local nm_b = (S.brd_overcure[i] or '')
                if nm_b == m.name then in_brd = true end
                if in_cure_excl and in_emerg_excl and in_brd then break end
            end

            -- DRG Healer Mode territory check: when DRG mode is ON,
            -- anyone at or below CFG.DRG_HEALER_THRESHOLD (50%) is
            -- claimed by the DRG Healer block further down -- this
            -- loop skips them entirely so they don't get picked up
            -- by the regular emergency band (which would burn Cure IV)
            -- or the normal cure band (which would pre-empt DRG
            -- Healer's sustain-time wyvern-wait logic). With DRG mode
            -- OFF, in_drg_territory is always false and behavior is
            -- unchanged: emergency band fires top-tier, normal band
            -- fires 2nd-tier.
            local in_drg_territory =
                S.drg_healer_mode and m.hp_pct <= CFG.DRG_HEALER_THRESHOLD

            if in_brd then
                -- Brd anti-overcure: this member is healed ONLY by the
                -- anti-overcure picker, never by the normal/emergency
                -- bands (their Brd box being checked disables both for
                -- them). Trigger only at/below BRD_CURE_TRIGGER_PCT
                -- (50%); cast_brd_cure does the live-HP re-read and
                -- picks the largest tier that won't cross the 74%
                -- ceiling (or holds if even Cure I would). Lowest HP%
                -- wins the slot.
                if m.hp_pct <= BRD_CURE_TRIGGER_PCT then
                    if not brd_cure or m.hp_pct < brd_cure.hp_pct then
                        brd_cure = m
                    end
                end
            elseif in_drg_territory then
                -- intentionally no-op: DRG Healer block handles this
                -- target. Leaving emergency_cure / normal_cure unset
                -- here is the whole point.
            elseif m.hp_pct <= S.emergency_cure_threshold then
                -- Emergency-band candidate. Skip if the member is in
                -- emergency_cure_excluded (their "E.Cure" checkbox is
                -- off). The toggle is the user's stated intent and we
                -- honor it absolutely -- if they unchecked themself,
                -- they are choosing not to be auto-emergency-cured even
                -- in the emergency band. (To get back: re-check the
                -- E.Cure box for that member in the GUI.)
                if not in_emerg_excl then
                    if not emergency_cure or m.hp_pct < emergency_cure.hp_pct then
                        emergency_cure = m
                    end
                end
            elseif m.hp_pct < CFG.NORMAL_CURE_THRESHOLD then
                -- Normal-cure-band candidate. Skip if "Cure" checkbox
                -- is off for this member.
                if not in_cure_excl then
                    if not normal_cure or m.hp_pct < normal_cure.hp_pct then
                        normal_cure = m
                    end
                end
            end
        end
    end

    -- DRG Healer Mode: when ON, this block is the SOLE emergency
    -- cure path. The snapshot loop above bypasses the regular
    -- emergency band (and the normal cure band) for anyone at
    -- HP <= CFG.DRG_HEALER_THRESHOLD via the in_drg_territory
    -- gate, so emergency_cure can only be set from here while
    -- this mode is enabled. Hardcoded 50% threshold (NOT the
    -- emergency 35/50 toggle -- DRG mode owns its own band).
    -- Three triggers, evaluated in priority order:
    --   1. CRITICAL: anyone at/below CFG.DRG_HEALER_CRITICAL_THRESHOLD
    --      (20%) -- immediate cure, lowest HP wins. Overrides the
    --      2+ rule below: a critical member beats a "highest of two"
    --      pick because wyvern HB can't keep pace with a sub-20%
    --      dip.
    --   2. 2+ low: 2 or more members in the 21-50% band -- cure the
    --      one with the highest HP%, wyvern handles the lower one.
    --   3. SUSTAINED: 1 member in the 21-50% band, low for
    --      S.drg_sustain_sec seconds -- cure them. The sustain
    --      wait gives the wyvern's Healing Breath time to react on
    --      single-hit dips.
    -- Recovery above CFG.DRG_HEALER_THRESHOLD clears drg_low_since[name]
    -- so a fresh dip restarts the sustain timer. Silent hold (no log
    -- spam every tick); the log fires once when the cure goes off.
    -- The `if not emergency_cure` guard below is defensive: with
    -- in_drg_territory gating the snapshot loop, emergency_cure is
    -- always nil at this point in DRG mode -- the guard just
    -- protects against any future writer that might bypass that gate.
    if S.drg_healer_mode then
        local drg_low_band = {}
        for _, m in ipairs(snap) do
            if m.active and m.name ~= '---' and m.hp_pct > 0 and m.dist <= CFG.CURE_RANGE then
                if m.hp_pct <= CFG.DRG_HEALER_THRESHOLD then
                    local in_emerg_excl = false
                    for i = 1, 6 do
                        if (S.emergency_cure_excluded[i] or '') == m.name then
                            in_emerg_excl = true
                            break
                        end
                    end
                    if not in_emerg_excl then
                        drg_low_band[#drg_low_band + 1] = m
                        if not S.drg_low_since[m.name] then
                            S.drg_low_since[m.name] = now()
                        end
                    end
                else
                    S.drg_low_since[m.name] = nil
                end
            end
        end

        if not emergency_cure then
            -- Priority 1: CRITICAL fast-path. Anyone at/below
            -- CFG.DRG_HEALER_CRITICAL_THRESHOLD gets cured immediately
            -- regardless of sustain timer or how many others are low.
            -- Pick the lowest if multiple are critical. Wyvern's HB
            -- isn't fast enough / big enough to be the primary
            -- response when someone is one hit from dead.
            local critical
            for _, m in ipairs(drg_low_band) do
                if m.hp_pct <= CFG.DRG_HEALER_CRITICAL_THRESHOLD then
                    if not critical or m.hp_pct < critical.hp_pct then
                        critical = m
                    end
                end
            end
            if critical then
                emergency_cure = critical
                emergency_cure_from_drg = true
                log(string.format('DRG Healer: CRITICAL %s at %d%% HP - curing immediately',
                    critical.name, critical.hp_pct))
            elseif #drg_low_band >= 2 then
                -- Priority 2: 2+ in the 21-50% band -- cure the one
                -- with the highest HP%, wyvern takes the lower one.
                -- (Critical fast-path above already handled any
                -- sub-critical members, so this loop only sees the
                -- 21-50% remainder.)
                local best
                for _, m in ipairs(drg_low_band) do
                    if not best or m.hp_pct > best.hp_pct then
                        best = m
                    end
                end
                emergency_cure = best
                emergency_cure_from_drg = true
                log(string.format('DRG Healer: %d low, curing %s (%d%% HP) - wyvern takes lower',
                    #drg_low_band, emergency_cure.name, emergency_cure.hp_pct))
            elseif #drg_low_band == 1 then
                -- Priority 3: 1 member sustained in the 21-50% band
                -- for drg_sustain_sec. Gives the wyvern's Healing
                -- Breath time to react first on single-hit dips.
                local m = drg_low_band[1]
                local since = S.drg_low_since[m.name]
                if since and (now() - since) >= S.drg_sustain_sec then
                    emergency_cure = m
                    emergency_cure_from_drg = true
                    log(string.format('DRG Healer: %s sustained %.1fs at %d%% HP, curing',
                        m.name, now() - since, m.hp_pct))
                end
            end
        end
    end

    end  -- if not S.disable_cure

    -- Auto-expire the just-cleared guard: if the blacklisted sid is
    -- no longer present in claimed_mobs (the corpse finally despawned
    -- from the client's entity tracking), clear the guard so a future
    -- legitimate mob that happens to land on a recycled FFXI slot/sid
    -- isn't permanently blacklisted.
    if S.recently_cleared_debuff_sid ~= 0
       and Mob.find_claimed_mob_by_sid(claimed_mobs, S.recently_cleared_debuff_sid) == nil then
        S.recently_cleared_debuff_sid = 0
    end

    -- DEAD-CHECK FIRST. Two separate concerns:
    --   * Is the locked mob actually dead/gone (prune dropped it)?
    --     Use find_claimed_sid_anywhere -- it scans all_claimed_targets
    --     across any distance. Lock holds while the mob is alive but
    --     temporarily out of the 20y engage range (mob walked away
    --     mid-fight). Only fully gone -> clear the lock.
    --   * Is the locked mob currently castable (in range)? That's the
    --     cascade's active_mob_alive_in_range check farther down --
    --     it gates stand-up + cast on active_mob_dist <=
    --     ACTIVE_MOB_RANGE, so an out-of-range locked mob just sits
    --     idle until it returns to range or dies.
    --
    -- Picker still uses claimed_mobs (range-filtered) so a new lock
    -- only ever lands on an in-range mob. We do NOT swap to another
    -- mob while the current one is still alive -- only after death,
    -- or to NONE if no in-range candidate exists.
    if S.debuff_mob_sid ~= 0 then
        local still_active = Mob.find_claimed_sid_anywhere(S.debuff_mob_sid)
        if still_active == nil then
            log('Active debuff mob gone - clearing debuff lock')
            S.debuff_mob_sid = 0
            S.skillup_done   = {}
            S.debuffs_done   = {}
            S.debug_mob_hp   = 0
            S.debug_mob_dist = 9999
        end
    end

    -- Look up the locked mob anywhere (any distance) so the cascade
    -- sees an accurate active_mob_dist even when the mob is currently
    -- out of range -- the range check happens at active_mob_alive_in_range
    -- below, not here.
    local active_debuff_mob = Mob.find_claimed_sid_anywhere(S.debuff_mob_sid)
    if active_debuff_mob == nil and #claimed_mobs > 0 then
        -- Pick OLDEST eligible mob ("appeared first"). The packet
        -- handlers store now() the first time a mob shows up in
        -- all_claimed_targets and preserve that timestamp across
        -- subsequent same-mob packets, so added_at is the original
        -- claim time. Closest-mob and pairs()-iteration-order were
        -- both wrong: the party engages mobs in order, the first one
        -- claimed is the first one being killed, and switching off
        -- it mid-fight to chase a newer add is exactly what we don't
        -- want.
        --
        -- recently_cleared guard still filters out the just-died sid;
        -- HP>0 guard catches any picker race on a row prune is about
        -- to drop.
        local picked = nil
        local best_added = math.huge
        for _, mob in ipairs(claimed_mobs) do
            if mob.server_id ~= S.recently_cleared_debuff_sid then
                local mhp = Mob.get_claimed_mob_hp(mob.index)
                if mhp > 0 and (mob.added_at or math.huge) < best_added then
                    picked     = mob
                    best_added = mob.added_at or math.huge
                end
            end
        end
        if picked then
            active_debuff_mob = picked
            if S.debuff_mob_sid ~= picked.server_id then
                log(string.format('New mob (sid %d, %.1fy, claimed %.1fs ago) - resetting debuffs',
                    picked.server_id, picked.dist,
                    now() - (picked.added_at or now())))
                S.debuff_mob_sid = picked.server_id
                S.debuffs_done   = {}
                S.skillup_done   = {}
            end
        end
    end

    -- Latch S.debuffs_done from the packet tracker UNCONDITIONALLY each
    -- tick. Previously this latch lived only inside Mob.get_next_debuff,
    -- so if S.debuff_enabled was off (or the cascade exited before
    -- reaching the debuff block for any other reason) the flag stayed
    -- false even though mob_debuffs clearly showed the debuff on the
    -- mob -- producing the "D- but the Debuffs: line says dia 51s"
    -- mismatch. Latch only sets true; never clears to false. Clearing
    -- on wear-off would break one-shot semantics (Paralyze without
    -- reapply would re-cast every time it lapsed). Wear-off / dispel
    -- DOES come through via mob_debuff_clear nulling the mob_debuffs
    -- entry, but debuffs_done stays true because we observed it land
    -- at least once -- and that's exactly what one-shot mode wants.
    if S.debuff_mob_sid ~= 0 then
        -- Dia / Bio share the same enfeeble slot on HorizonXI (they
        -- overwrite each other), so either status 134 (dia) or 135
        -- (bio) being present satisfies the 'dia' slot's one-shot latch.
        if mob_has_debuff(S.debuff_mob_sid, 134)
           or mob_has_debuff(S.debuff_mob_sid, 135) then
            S.debuffs_done['dia']      = true
        end
        if mob_has_debuff(S.debuff_mob_sid, 4)   then S.debuffs_done['paralyze'] = true end
        if mob_has_debuff(S.debuff_mob_sid, 13)  then S.debuffs_done['slow']     = true end
        if mob_has_debuff(S.debuff_mob_sid, 5)   then S.debuffs_done['blind']    = true end
    end

    -- Compute locals AFTER dead-check + pick so they reflect current
    -- state, not the pre-death snapshot. With the previous ordering
    -- a dead-check clear left these holding the corpse's index and a
    -- positive-looking HP, and the cascade trusted them.
    -- ALSO re-read HP here even though the dead-check just read it --
    -- if pick selected a different mob, this is the first read for
    -- THAT mob; if pick selected nothing, active_debuff_mob is nil
    -- and the locals stay false/0/9999 (cascade gates all skip).
    local active_mob_alive_in_range = false
    local active_mob_hp             = 0
    local active_mob_dist           = 9999
    if active_debuff_mob ~= nil then
        active_mob_dist           = active_debuff_mob.dist
        active_mob_hp             = Mob.get_claimed_mob_hp(active_debuff_mob.index)
        active_mob_alive_in_range = active_mob_hp >= 5 and active_mob_hp <= 97 and active_mob_dist <= CFG.ACTIVE_MOB_RANGE
        S.debug_mob_hp            = active_mob_hp
        S.debug_mob_dist          = active_mob_dist
    end

    -- ----------------------------------------------------------------
    -- CAST CASCADE
    -- Wrapped in `repeat ... until true` so the self-silence guard below
    -- can `break` out of every cast section in one shot. Existing
    -- `return` statements still return from tick(); break only exits
    -- this pseudo-block and falls through to REST LOGIC. The wrap also
    -- keeps the cascade's `local` declarations (emergency_cure, *_tgt,
    -- etc.) block-scoped so they don't leak into REST LOGIC.
    -- ----------------------------------------------------------------
    repeat

    -- ----------------------------------------------------------------
    -- SELF-SILENCE GUARD
    -- Silence blocks every /ma we'd send. cast_on_target enforces this
    -- on its own as a hard floor, but if we let the cascade run we'd
    -- also waste stand-ups (target selection, breaking rest, burning
    -- the stand lock) before each cast attempt is refused. So we bail
    -- straight out of the cascade -- the player will sit and recover
    -- MP until silence wears off (or they pop an Echo Drop, which is
    -- on them; we don't /item from this addon).
    --
    -- Logging is latched on S.silence_logged so we get one line on
    -- silence onset and one on clear, not 3+ per second of debug spam.
    -- The spell_locked() guard below still runs even on break, so an
    -- in-flight cast that started before silence landed gets to time
    -- out cleanly via cast_timeout_at; we don't try to interrupt it.
    -- ----------------------------------------------------------------
    if self_is_silenced() then
        if not S.silence_logged then
            log('Self silenced - holding casts until it clears')
            S.silence_logged = true
        end
        break
    elseif S.silence_logged then
        log('Silence cleared - resuming casts')
        S.silence_logged = false
    end

    -- ----------------------------------------------------------------
    -- PRIORITY SILENCE on a specific named mob.
    -- Sits ABOVE Refresh / Haste / Regen / Cures so a casting NM
    -- (default: "The Sprinkler") gets shut up before the cast slot
    -- goes to anything else. Only operates on the one named target;
    -- never silences other claimed mobs. Reapply behaviour mirrors
    -- Dia: with S.debuff_reapply_enabled, refreshes the 2-minute
    -- duration whenever it lapses; without it, one-shot per mob via
    -- S.silence_done_for_sid. buff_id 6 = silence in mob_debuffs.
    -- ----------------------------------------------------------------
    if S.mob_silence_enabled
       and type(S.mob_silence_target) == 'string'
       and #S.mob_silence_target > 0
       and spell_ready('Silence')
    then
        local sil_mob = nil
        for _, m in ipairs(claimed_mobs) do
            local ok_se, sent = pcall(GetEntity, m.index)
            if ok_se and sent then
                local sname = tostring(sent.Name or '')
                if sname == S.mob_silence_target then
                    -- Observation latch (mirrors get_next_debuff's
                    -- "confirmed on mob" path): if the packet tracker
                    -- now says Silence is on this mob, remember it
                    -- so one-shot mode doesn't re-fire.
                    if mob_has_debuff(m.server_id, 6)
                       and S.silence_done_for_sid ~= m.server_id then
                        log(string.format('Silence confirmed on %s', sname))
                        S.silence_done_for_sid = m.server_id
                    end

                    local mob_has_sil  = mob_has_debuff(m.server_id, 6)
                    local already_done = (S.silence_done_for_sid == m.server_id)
                    local cast_needed
                    if S.debuff_reapply_enabled then
                        cast_needed = not mob_has_sil
                    else
                        cast_needed = (not already_done) and (not mob_has_sil)
                    end

                    if cast_needed then
                        local mhp = Mob.get_claimed_mob_hp(m.index)
                        if mhp > 0 then
                            sil_mob = { name = sname, dist = m.dist, sid = m.server_id, index = m.index }
                            break
                        end
                    end
                end
            end
        end
        if sil_mob then
            if P.player_is_resting() then
                -- Pre-stand fresh HP read (same race protection as
                -- the debuff cascade further down).
                local cur_hp = Mob.get_claimed_mob_hp(sil_mob.index)
                if cur_hp > 0 then
                    if stand_up(string.format('Stand to Silence %s (%.1fy)',
                        sil_mob.name, sil_mob.dist)) then
                        return
                    end
                end
            else
                local cur_hp = Mob.get_claimed_mob_hp(sil_mob.index)
                if cur_hp > 0 then
                    -- Silence targets a NAMED mob (sil_mob), so cast at
                    -- its sid -- <bt> could resolve to a different mob
                    -- entirely, which defeated the whole point of the
                    -- named-mob picker.
                    log(string.format('Silence -> %s (%.1fy, sid %d)',
                        sil_mob.name, sil_mob.dist, n(sil_mob.sid)))
                    if cast_on_target('Silence', sil_mob.sid) then
                        return
                    end
                end
            end
        end
    end

    -- ----------------------------------------------------------------
    -- 1. EMERGENCY CURE: stand immediately, cast whatever we can afford.
    -- Two-tier stand gate based on how bad it is:
    --   HP <= CFG.CRITICAL_CURE_THRESHOLD (10%) : stand if MP covers Cure I (8 MP).
    --                                         True "save them or they die" band;
    --                                         even a Cure I beats watching them
    --                                         die while we sit.
    --   HP >  CFG.CRITICAL_CURE_THRESHOLD       : stand only if MP covers Cure II (24 MP).
    --                                         Standing with only Cure I available
    --                                         here is a bad trade: it burns the
    --                                         stand lock (6s of slow standing
    --                                         regen) on a heal that barely moves
    --                                         the needle. Rest instead and let
    --                                         MP catch up; if HP drops into the
    --                                         critical band next tick, the 8 MP
    --                                         floor kicks in.
    -- Cast side (already standing) is unchanged: cast_emergency_cure cascades
    -- IV -> III -> II -> I, so whatever we can afford at cast time goes off.
    -- ----------------------------------------------------------------
    if emergency_cure and P.player_is_resting() then
        -- Fresh HP re-check: between the snapshot at top of tick and
        -- now, the DRG/wyvern may have already cured the target. If
        -- they've recovered above CFG.DRG_HEALER_THRESHOLD, drop the cure.
        local live = Mob.live_hp_pct(emergency_cure.name)
        if live and live > CFG.DRG_HEALER_THRESHOLD then
            log(string.format('Emergency cure %s skipped - HP recovered to %d%% (wyvern?)',
                emergency_cure.name, live))
            S.drg_low_since[emergency_cure.name] = nil
            emergency_cure = nil
        end
    end
    if emergency_cure and P.player_is_resting() then
        -- MP gate for breaking rest. Two-tier in non-DRG mode:
        --   HP <= 10%   : 8 MP (Cure I) -- die-or-save band, anything beats nothing.
        --   HP >  10%   : 24 MP (Cure II) -- avoids burning the 6s stand lock on
        --                 a Cure I that barely moves the needle when we could
        --                 have rested 2-3 more seconds for a real Cure II.
        -- DRG Healer override: when emergency_cure_from_drg is true, drop
        -- straight to Cure I cost (8 MP) regardless of HP. By the time DRG
        -- Healer marks someone, the sustain timer / 2+ rule / critical
        -- fast-path has ALREADY decided "we're stepping in now" -- the
        -- "wait for more MP" calculus that justifies the 24-MP gate in
        -- non-DRG mode doesn't apply here, because the alternative isn't
        -- "rest 2 more seconds then Cure II", it's "watch them die while
        -- we sit." cast_emergency_cure still cascades to the best
        -- affordable tier (Cure III at 46 MP, Cure II at 24 MP, Cure I
        -- at 8 MP), so we never overcast -- we just don't UNDER-act.
        local min_mp
        if emergency_cure_from_drg then
            min_mp = SPELL_MP_COST['Cure'] or 8
        elseif emergency_cure.hp_pct <= CFG.CRITICAL_CURE_THRESHOLD then
            min_mp = SPELL_MP_COST['Cure'] or 8
        else
            min_mp = SPELL_MP_COST['Cure II'] or 24
        end
        if P.player_mp() >= min_mp then
            -- Pass true for allow_force_rest_override: this is the only
            -- legitimate caller of the Force-Rest override. If Force
            -- Rest is on and an ally has dropped into the emergency
            -- band, we're allowed to break the rest to cure them
            -- (subject to force_rest_allows_stand's MP / ally-HP gate
            -- inside stand_up).
            if stand_up(string.format('Stand for EMERGENCY Cure %s (%d%%)',
                                      emergency_cure.name, emergency_cure.hp_pct),
                        true) then
                return
            end
        else
            log(string.format('Emergency cure %s (%d%%) - resting, need %d MP (have %d)',
                emergency_cure.name, emergency_cure.hp_pct, min_mp, P.player_mp()))
        end
    end

    if spell_locked() then return end

    -- Standing-branch fresh-HP re-check. Two outcomes based on the
    -- LIVE HP at this exact moment (which may differ from the
    -- tick-start snapshot if a wyvern, another mage, or item-use
    -- cured the target in the gap):
    --   * live >= NORMAL_CURE_THRESHOLD (70%): target is fully
    --     recovered, no cure needed. Drop emergency_cure and fall
    --     through so the cascade can move on.
    --   * otherwise: fire the emergency cure ACTION. Tier choice is
    --     handled by cast_emergency_cure's safety-first scan order
    --     (Cure III preferred; Cure IV only as a Cure-III-on-recast
    --     fallback), so a target who recovered into the normal
    --     band gets Cure III the same as a real emergency does --
    --     no explicit downgrade flag needed.
    if emergency_cure and not P.player_is_resting() then
        local live = Mob.live_hp_pct(emergency_cure.name)
        if live and live >= CFG.NORMAL_CURE_THRESHOLD then
            log(string.format('EMERGENCY Cure %s skipped - HP recovered to %d%% (>= %d%%)',
                emergency_cure.name, live, CFG.NORMAL_CURE_THRESHOLD))
            S.drg_low_since[emergency_cure.name] = nil
            emergency_cure = nil
        end
    end

    if emergency_cure and not P.player_is_resting() then
        log(string.format('EMERGENCY Cure: %s HP%d%%%s',
            emergency_cure.name, emergency_cure.hp_pct,
            emergency_cure_from_drg and ' (DRG Healer)' or ''))
        if cast_emergency_cure(emergency_cure.name) then
            return
        end
    end

    if spell_locked() then return end

    -- Brd ANTI-OVERCURE firing. A Brd-enrolled member who has taken
    -- damage (selected into brd_cure above) is healed here, AFTER the
    -- real emergency band but before the Force Rest gate / routine
    -- buffs / normal cure. cast_brd_cure does its own live-HP re-read
    -- and picks the largest tier that won't overheal (and the per-tick
    -- mid-cast abort at the top of tick kneel-cancels if they recover
    -- while it's flying). If resting, stand up first (Brd boxes are
    -- opt-in, so standing to service one is the user's stated intent).
    if brd_cure then
        if P.player_is_resting() then
            if stand_up(string.format('Stand for Brd cure %s (%d%%)',
                                      brd_cure.name, brd_cure.hp_pct), true) then
                return
            end
        else
            if cast_brd_cure(brd_cure.name) then
                return
            end
        end
    end

    if spell_locked() then return end

    -- ----------------------------------------------------------------
    -- FORCE REST cascade gate.
    -- When Force Rest is on, skip every non-emergency action below
    -- (Reraise, manual Dispel/Sleep/Bind buttons, Refresh, Haste,
    -- Stoneskin/Blink/Aquaveil/Phalanx, paralyna/silena/poisona,
    -- Dia/Paralyze/Slow, auto-dispel, skillups, normal cure) so the
    -- REST LOGIC at the bottom of tick() can sit us down ASAP.
    -- Emergency cure has already run above and is the ONE thing
    -- that can override Force Rest (gated by force_rest_allows_stand
    -- inside stand_up). If a cast was in flight, the spell_locked()
    -- guard above already returned this tick; once the cast and
    -- POST_CAST_SETTLE complete, the next tick reaches this break
    -- and rest_down sits us.
    -- ----------------------------------------------------------------
    if S.force_rest then
        break
    end

    -- ----------------------------------------------------------------
    -- 1a. BAR ELEMENTAL SPELLS (WHM AoE bar-element, centered on caster).
    -- Sits just under the emergency band and the Force Rest gate (so a
    -- real Force Rest still blocks it), above Reraise / convenience
    -- buffs. The user picks ONE active element via the GUI (or none);
    -- S.barelement_active holds the spell name to cast, or nil for off.
    --
    -- Stand-up worthy: if a checked member is missing the active
    -- element and we're resting, break rest to put it up -- but only
    -- when CURRENT MP >= CFG.BARELEMENT_STAND_MP (100), so we don't
    -- thrash rest for a 12-MP buff the moment we sit down.
    --
    -- Coverage rule (barelement_evaluate):
    --   'cast' : at least one checked member needs it and EVERY needy
    --            checked member is within the 10-yalm AoE -> cast the
    --            active spell on self (<me>), blanketing the group.
    --   'wait' : a needy checked member is OUT of range -> hold the
    --            cast (we'd miss them) and echo their name every 5s.
    --   'idle' : nobody checked needs it -> fall through.
    --
    -- spell_ready / spell_usable / silence / the 12-MP cast cost are all
    -- enforced inside cast_on_target; this block only owns the
    -- element-selection gate, the coverage decision, the stand-up MP
    -- floor, and the out-of-range echo.
    -- ----------------------------------------------------------------
    do
        local active_spell = S.barelement_active
        if type(active_spell) == 'string' and active_spell ~= ''
           and BARELEMENT_BUFF_ID[active_spell]
           and barelement_usable()
           and spell_usable(active_spell)
           and spell_ready(active_spell)
        then
            local action, out_names = barelement_evaluate()

            if action == 'wait' then
                -- Needed but unreachable. Throttled echo naming the
                -- stragglers, with the ELEMENT name so the user can tell
                -- which bar-spell we're waiting on (matters if they
                -- switch element mid-fight).
                if now() >= S.barelement_echo_at then
                    S.barelement_echo_at = now() + BARELEMENT_ECHO_SEC
                    cprint(string.format('%s needed and out of range: %s',
                        active_spell,
                        table.concat(out_names, ', ')))
                end
                -- Do NOT cast this tick -- holding for the group to close in.
            elseif action == 'cast' then
                if P.player_is_resting() then
                    -- Stand-up gate: only break rest with a healthy
                    -- pool. Auto Full Rest still blocks the stand path
                    -- like the other non-emergency buffs.
                    if P.player_mp() >= CFG.BARELEMENT_STAND_MP then
                        if not auto_full_rest_blocks() then
                            if stand_up(string.format('Stand for %s', active_spell)) then
                                return
                            end
                        end
                    else
                        log(string.format('%s due - resting, need %d MP to stand (have %d)',
                            active_spell, CFG.BARELEMENT_STAND_MP, P.player_mp()))
                    end
                else
                    log(string.format('%s -> self (AoE)', active_spell))
                    if cast_on_target(active_spell, P.player_name()) then
                        return
                    end
                end
            end
        end
    end

    if spell_locked() then return end


    -- cure and above EVERYTHING ELSE -- if we're missing Reraise we
    -- want it up before anything else can demand our attention. The
    -- gate (CFG.RERAISE_MIN_MP_PCT, default 75%) keeps it from firing
    -- when we don't have the MP headroom to commit the 50 MP / 8s
    -- cast. Auto Full Rest still blocks the stand-up path; Force
    -- Rest still blocks unconditionally. spell_ready / spell_usable
    -- / silence / MP-cost are enforced inside cast_on_target.
    -- ----------------------------------------------------------------
    if S.reraise_enabled
       and reraise_usable()
       and P.player_mp_pct() >= CFG.RERAISE_MIN_MP_PCT
       and not self_has_buff(CFG.BUFF_RERAISE)
    then
        if P.player_is_resting() then
            if not auto_full_rest_blocks() then
                if stand_up('Stand for Reraise') then
                    return
                end
            end
        else
            log('Reraise -> self')
            if cast_on_target('Reraise', P.player_name()) then
                return
            end
        end
    end

    if spell_locked() then return end

    -- ----------------------------------------------------------------
    -- 2a. DISPEL (manual button) -> <bt>
    -- Manual buttons sit just under emergency cure: pressing one is
    -- explicit user intent and beats the heuristic-driven cascades
    -- below (normal cure, auto-dispel, paralyna chain, debuffs,
    -- convenience buffs). If the user hits Dispel, they want it now,
    -- not after a normal cure tops off some 65%-HP ally.
    -- ----------------------------------------------------------------
    if S.dispel_pending then
        -- Tracked mob only -- see the matching block in
        -- try_manual_buttons_stopped for why <bt> is gone.
        local dsid = n(S.debuff_mob_sid)
        if not spell_ready('Dispel') or not spell_usable('Dispel')
            or P.player_mp() < SPELL_MP_COST['Dispel']
        then
            log('Dispel: unavailable, cancelling')
            S.dispel_pending = false
        elseif dsid == 0 then
            log('Dispel: no tracked mob, cancelling')
            S.dispel_pending = false
        elseif P.player_is_resting() then
            if stand_up('Stand for Dispel') then return end
        else
            if cast_on_target('Dispel', dsid) then
                S.dispel_pending = false
            end
            return
        end
    end

    if spell_locked() then return end

    -- ----------------------------------------------------------------
    -- 2b. SLEEP (manual button) -> <t>
    -- ----------------------------------------------------------------
    if S.sleep_pending then
        if not spell_ready('Sleep') or not spell_usable('Sleep')
            or P.player_mp() < SPELL_MP_COST['Sleep']
        then
            log('Sleep: unavailable, cancelling')
            S.sleep_pending = false
        elseif P.player_is_resting() then
            if stand_up('Stand for Sleep') then return end
        else
            if cast_on_target('Sleep', '<t>') then
                S.sleep_pending = false
            end
            return
        end
    end

    if spell_locked() then return end

    -- ----------------------------------------------------------------
    -- 2c. BIND (manual button) -> <t>
    -- ----------------------------------------------------------------
    if S.bind_pending then
        if not spell_ready('Bind') or not spell_usable('Bind')
            or P.player_mp() < SPELL_MP_COST['Bind']
        then
            log('Bind: unavailable, cancelling')
            S.bind_pending = false
        elseif P.player_is_resting() then
            if stand_up('Stand for Bind') then return end
        else
            if cast_on_target('Bind', '<t>') then
                S.bind_pending = false
            end
            return
        end
    end

    if spell_locked() then return end

    -- ----------------------------------------------------------------
    -- 3. NORMAL CURE
    -- Never stands us up from rest. Only casts while already standing.
    -- The "Disable Cure" master toggle (S.disable_cure) prevents
    -- normal_cure from ever being set above, so this branch is a no-op
    -- when the master is on. Emergency cures are the only thing that
    -- breaks a rest.
    -- ----------------------------------------------------------------
    if normal_cure and not P.player_is_resting() then
        log(string.format('Cure candidate: %s HP%d%% dist%.1f',
            normal_cure.name, normal_cure.hp_pct, normal_cure.dist))
        if cast_normal_cure(normal_cure.name) then
            return
        end
    end

    if spell_locked() then return end

    -- ----------------------------------------------------------------
    -- 4. AUTO-DISPEL problem mob buffs (Evasion Boost etc).
    -- Runs even while resting — these ruin parties.
    -- Gates: mob alive, in range, mob HP above CFG.AUTO_DISPEL_MIN_MOB_HP,
    -- our MP% at or above CFG.AUTO_DISPEL_MIN_MP_PCT.
    -- ----------------------------------------------------------------
    if S.auto_dispel_enabled and active_debuff_mob ~= nil and active_mob_alive_in_range
       and active_mob_hp > CFG.AUTO_DISPEL_MIN_MOB_HP
    then
        local sid = active_debuff_mob.server_id
        -- Source of truth for what's currently on the mob: debuffhandler.
        -- This is the same module enemylist.lua uses to draw the live
        -- icon strip above each enemy, so its view stays current with
        -- whatever the server actually has applied -- including buffs
        -- we just stripped. Reading it here (instead of our local
        -- mob_debuffs tracker) is what makes Auto-Dispel STOP re-firing
        -- on cooldown after a successful Dispel: when the buff is gone
        -- server-side, debuffhandler reflects that next tick, the scan
        -- below finds nothing, and we don't re-cast.
        local active_buff_list = nil
        if debuffHandler and type(debuffHandler.GetActiveDebuffs) == 'function' then
            active_buff_list = debuffHandler.GetActiveDebuffs(sid)
        end
        if type(active_buff_list) == 'table' and #active_buff_list > 0 then
            -- Flatten the array to a set for O(1) lookup per CFG.AUTO_DISPEL_BUFFS entry.
            local active_set = {}
            for i = 1, #active_buff_list do
                active_set[active_buff_list[i]] = true
            end

            local tnow = os.time()
            local found_name = nil
            for bid, nm in pairs(CFG.AUTO_DISPEL_BUFFS) do
                if active_set[bid] then
                    -- CFG.AUTO_DISPEL_DELAY: wait this long after we first
                    -- saw the buff before stripping it, so the effect
                    -- has settled. Mob.mob_buff_seen_at is normally populated
                    -- by the action-packet handler; debuffhandler can
                    -- pick up buffs via paths that handler doesn't see
                    -- (memory poll, packet 0x076), so stamp first-seen
                    -- here if we have no entry. Worst case, the buff
                    -- gets a fresh CFG.AUTO_DISPEL_DELAY wait from this
                    -- moment instead of from the actual landing time --
                    -- that's a small over-wait, never an under-wait.
                    Mob.mob_buff_seen_at[sid] = Mob.mob_buff_seen_at[sid] or {}
                    if not Mob.mob_buff_seen_at[sid][bid] then
                        Mob.mob_buff_seen_at[sid][bid] = tnow
                    end
                    local seen_at = Mob.mob_buff_seen_at[sid][bid]
                    if tnow - seen_at >= CFG.AUTO_DISPEL_DELAY then
                        found_name = nm
                        break
                    end
                else
                    -- Buff isn't on the mob (any more). Drop the
                    -- first-seen stamp so a later re-application gets
                    -- a fresh CFG.AUTO_DISPEL_DELAY from when it lands,
                    -- not from the previous instance.
                    if Mob.mob_buff_seen_at[sid] then
                        Mob.mob_buff_seen_at[sid][bid] = nil
                    end
                end
            end
            if found_name
               and spell_ready('Dispel') and spell_usable('Dispel')
               and P.player_mp() >= SPELL_MP_COST['Dispel']
               and P.player_mp_pct() >= CFG.AUTO_DISPEL_MIN_MP_PCT
            then
                if P.player_is_resting() then
                    if stand_up(string.format('Stand to Auto-Dispel %s', found_name)) then return end
                else
                    -- sid is active_debuff_mob.server_id -- the exact mob
                    -- we scanned for the buff. Cast at it, not <bt>.
                    log(string.format('Auto-Dispel %s on claimed mob (sid %d)',
                        found_name, n(sid)))
                    if cast_on_target('Dispel', sid) then return end
                end
            end
        end
    end

    -- ----------------------------------------------------------------
    -- 5a. PARALYNA: p0->p5 in order when paralyzed
    -- ----------------------------------------------------------------
    local paralyna_tgt = Tgt.next_paralyna_target()
    if paralyna_tgt then
        if P.player_is_resting() then
            if P.player_mp_pct() >= CFG.DEBUFF_STAND_MP then
                if stand_up(string.format('Stand for Paralyna -> %s', paralyna_tgt)) then
                    return
                end
            end
        else
            log(string.format('Paralyna -> %s', paralyna_tgt))
            if cast_on_target('Paralyna', paralyna_tgt) then
                return
            end
        end
    end

    if spell_locked() then return end

    -- ----------------------------------------------------------------
    -- 5b. SILENA: p0->p5 in order when silenced
    -- ----------------------------------------------------------------
    local silena_tgt = Tgt.next_silena_target()
    if silena_tgt then
        if P.player_is_resting() then
            if P.player_mp_pct() >= CFG.DEBUFF_STAND_MP then
                if stand_up(string.format('Stand for Silena -> %s', silena_tgt)) then
                    return
                end
            end
        else
            log(string.format('Silena -> %s', silena_tgt))
            if cast_on_target('Silena', silena_tgt) then
                return
            end
        end
    end

    if spell_locked() then return end

    -- ----------------------------------------------------------------
    -- 5c. POISONA: p0->p5 in order when poisoned
    -- ----------------------------------------------------------------
    local poisona_tgt = Tgt.next_poisona_target()
    if poisona_tgt then
        if P.player_is_resting() then
            if P.player_mp_pct() >= CFG.DEBUFF_STAND_MP then
                if stand_up(string.format('Stand for Poisona -> %s', poisona_tgt)) then
                    return
                end
            end
        else
            log(string.format('Poisona -> %s', poisona_tgt))
            if cast_on_target('Poisona', poisona_tgt) then
                return
            end
        end
    end

    if spell_locked() then return end

    -- ----------------------------------------------------------------
    -- 5d. BLINDNA: p0->p5 in order when blinded
    -- ----------------------------------------------------------------
    local blindna_tgt = Tgt.next_blindna_target()
    if blindna_tgt then
        if P.player_is_resting() then
            if P.player_mp_pct() >= CFG.DEBUFF_STAND_MP then
                if stand_up(string.format('Stand for Blindna -> %s', blindna_tgt)) then
                    return
                end
            end
        else
            log(string.format('Blindna -> %s', blindna_tgt))
            if cast_on_target('Blindna', blindna_tgt) then
                return
            end
        end
    end

    if spell_locked() then return end

    -- ----------------------------------------------------------------
    -- REFRESH: self first, then extra target.
    -- Sits ABOVE mob debuffs (Dia/Paralyze/Slow) in the cascade so a
    -- party member due for Refresh/Haste/Regen doesn't wait through a
    -- debuff cast slot. Cure paths (emergency/normal) and status
    -- removals (Paralyna/Silena/Poisona/Blindna) still preempt
    -- everything below them.
    -- The party convenience buffs (Refresh / Haste / Regen) have a
    -- two-stage gate:
    --   * Already standing -> cast as soon as the timer says due.
    --     No MP% threshold here -- cast_on_target enforces the
    --     spell's own MP cost (won't fire if we don't have at least
    --     that much). The user explicitly wants Refresh to fire when
    --     it comes due regardless of current MP%, so we don't second-
    --     guess them once they're already on their feet.
    --   * Resting -> stand up to cast only when MP% >= the convenience
    --     threshold (80) AND Auto Full Rest isn't actively holding us
    --     in the tail of a rest. The threshold exists so we don't
    --     break rest at 30% just to drop further; below 80% the rest
    --     cycle is more efficient than cycling rest/stand/cast/rest.
    --     Force Rest is still enforced inside stand_up() itself --
    --     only emergency cure can override Force Rest.
    -- "Spell not on CD" gating is automatic: cast_on_target's
    -- spell_ready() check rejects a cast attempt when the per-spell
    -- cooldown hasn't elapsed, so this block silently falls through
    -- to Haste/Regen/Debuffs when Refresh is mid-recast.
    -- ----------------------------------------------------------------
    local rtarget = Tgt.next_refresh_target()
    if rtarget then
        if P.player_is_resting() then
            -- Self-only gate: don't break rest to rebuff Refresh on
            -- ourselves below 100% MP. Resting already gives MP regen,
            -- so standing up costs more MP/tick than the Refresh buff
            -- would save. At exactly 100% MP we'd have stood up via the
            -- MP-full release in REST LOGIC anyway, so in practice the
            -- self-stand-from-rest path is unreachable and self-Refresh
            -- always casts from the standing branch below. If self came
            -- back as the next target but we can't act on it, re-query
            -- skipping self so a party-member who's also due still gets
            -- their Refresh at the normal CFG.CONVENIENCE_BUFF_MIN_MP_PCT
            -- (80%) threshold.
            if rtarget == P.player_name() and P.player_mp_pct() < 100 then
                rtarget = Tgt.next_refresh_target(P.player_name())
            end
            if rtarget
               and P.player_mp_pct() >= CFG.CONVENIENCE_BUFF_MIN_MP_PCT
               and not auto_full_rest_blocks()
            then
                if stand_up(string.format('Stand for Refresh -> %s', rtarget)) then
                    return
                end
            end
        else
            if can_afford('Refresh') then
                log(string.format('Refresh -> %s', rtarget))
                if cast_on_target('Refresh', rtarget) then
                    return
                end
            end
        end
    end

    if spell_locked() then return end

    -- ----------------------------------------------------------------
    -- HASTE rotation. Same two-stage gate as Refresh -- see comment
    -- above. Cast unconditionally when standing; 80%+ MP and not
    -- Auto-Full-Rest-blocked when resting.
    -- ----------------------------------------------------------------
    local htarget = Tgt.next_haste_target()
    if htarget then
        if P.player_is_resting() then
            if P.player_mp_pct() >= CFG.CONVENIENCE_BUFF_MIN_MP_PCT
               and not auto_full_rest_blocks()
            then
                if stand_up(string.format('Stand for Haste -> %s', htarget)) then
                    return
                end
            end
        else
            if can_afford('Haste') then
                log(string.format('Haste -> %s', htarget))
                if cast_on_target('Haste', htarget) then
                    return
                end
            end
        end
    end

    if spell_locked() then return end

    -- ----------------------------------------------------------------
    -- REGEN: named targets, cast on anyone missing the buff. Same
    -- two-stage gate as Refresh -- see comment above.
    -- ----------------------------------------------------------------
    local regen_tgt = Tgt.next_regen_target()
    if regen_tgt then
        if P.player_is_resting() then
            if P.player_mp_pct() >= CFG.CONVENIENCE_BUFF_MIN_MP_PCT
               and not auto_full_rest_blocks()
            then
                if stand_up(string.format('Stand for Regen -> %s', regen_tgt)) then
                    return
                end
            end
        else
            if can_afford('Regen') then
                log(string.format('Regen -> %s', regen_tgt))
                if cast_on_target('Regen', regen_tgt) then
                    return
                end
            end
        end
    end

    if spell_locked() then return end

    -- ----------------------------------------------------------------
    -- PROTECT: named targets, cast highest castable tier on anyone
    -- missing the Protect buff. Same two-stage gate as Refresh.
    -- ----------------------------------------------------------------
    local ptarget = Tgt.next_protect_target()
    if ptarget then
        local ptier = highest_protect_tier()
        if ptier then
            if P.player_is_resting() then
                if P.player_mp_pct() >= CFG.CONVENIENCE_BUFF_MIN_MP_PCT
                   and not auto_full_rest_blocks()
                then
                    if stand_up(string.format('Stand for %s -> %s', ptier, ptarget)) then
                        return
                    end
                end
            else
                if can_afford(ptier) then
                    log(string.format('%s -> %s', ptier, ptarget))
                    if cast_on_target(ptier, ptarget) then
                        return
                    end
                end
            end
        end
    end

    if spell_locked() then return end

    -- ----------------------------------------------------------------
    -- SHELL: named targets, cast highest castable tier on anyone
    -- missing the Shell buff. Same gate as Protect.
    -- ----------------------------------------------------------------
    local starget = Tgt.next_shell_target()
    if starget then
        local stier = highest_shell_tier()
        if stier then
            if P.player_is_resting() then
                if P.player_mp_pct() >= CFG.CONVENIENCE_BUFF_MIN_MP_PCT
                   and not auto_full_rest_blocks()
                then
                    if stand_up(string.format('Stand for %s -> %s', stier, starget)) then
                        return
                    end
                end
            else
                if can_afford(stier) then
                    log(string.format('%s -> %s', stier, starget))
                    if cast_on_target(stier, starget) then
                        return
                    end
                end
            end
        end
    end

    if spell_locked() then return end

    -- ----------------------------------------------------------------
    -- DEBUFFS (Dia / Paralyze / Slow on claimed mob).
    -- Runs AFTER Refresh/Haste/Regen so a party member due for a
    -- convenience buff (and not on recast cooldown for it) gets the
    -- cast slot before we lock the bot into a debuff cycle. Only HP
    -- cures (emergency/normal, above) and status removals
    -- (Paralyna/Silena/Poisona/Blindna) preempt the party buffs.
    -- ----------------------------------------------------------------
    if S.debuff_enabled and active_debuff_mob ~= nil and active_mob_alive_in_range then
        local next_debuff = Mob.get_next_debuff(P.player_level())
        if next_debuff then
            -- A debuff is a "reapply" when reapply is enabled for this spell
            -- AND the packet tracker has already confirmed it landed on this
            -- mob at least once (debuffs_done[key] was set in Mob.get_next_debuff).
            -- Otherwise it is a first-round cast and must pass the 96% ceiling.
            local is_reapply = (next_debuff.recast_sec ~= nil)
                           and S.debuff_reapply_enabled
                           and S.debuffs_done[next_debuff.key] == true

            -- Pick the abandon floor based on whether this is a reapply.
            -- First-round Slow/Paralyze (and the very first Dia) use the
            -- 60% floor -- below that the mob will die before the debuff
            -- pays off, so we save the MP. Dia REAPPLY uses the lower 30%
            -- floor: the DoT keeps ticking damage at any HP and the spell
            -- only costs 7-12 MP, so the cycle stays worth it much further
            -- into the fight. Note that calling Mob.mark_remaining_debuffs_done()
            -- in the reapply abandon case is a no-op for Dia (the recastable
            -- branch in Mob.get_next_debuff() doesn't consult debuffs_done) but
            -- correctly suppresses any not-yet-cast Slow/Paralyze on a
            -- near-dead mob.
            local floor_hp = is_reapply and CFG.DEBUFF_REAPPLY_MIN_MOBHP or CFG.DEBUFF_MIN_MOBHP

            if P.player_is_resting() then
                if active_mob_hp < floor_hp then
                    -- Log once per mob, not once per tick: this branch is
                    -- re-entered every frame while the mob is dying.
                    if S.abandon_logged_sid ~= S.debuff_mob_sid then
                        S.abandon_logged_sid = S.debuff_mob_sid
                        log(string.format('Mob low HP (%d%% < %d%%) - abandoning remaining debuffs for this mob',
                            active_mob_hp, floor_hp))
                    end
                    Mob.mark_remaining_debuffs_done()
                elseif (not is_reapply) and active_mob_hp > CFG.DEBUFF_MAX_MOBHP then
                    -- Mob hasn't been engaged yet; wait for it to drop below 96%
                    -- before standing up to debuff (avoids casting on wrong mob).
                    -- Silent: fall through to REST LOGIC below.
                elseif P.player_mp_pct() < CFG.DEBUFF_STAND_MP then
                    log(string.format('Low MP (%d%%) - do not stand for debuff', P.player_mp_pct()))
                elseif auto_full_rest_blocks() then
                    -- User-enabled Auto Full Rest: been resting a while and
                    -- close to full, so let it finish instead of standing
                    -- for a debuff. Emergency cure still gets to stand.
                    log(string.format('Auto Full Rest: resting %.0fs at %d%% MP - holding for full before debuff',
                        now() - S.rest_started_at, P.player_mp_pct()))
                else
                    -- Final pre-stand HP read. The active_mob_hp local was
                    -- snapshotted at line 3760 (start of tick); FFXI's entity
                    -- memory updates asynchronously and the mob may have
                    -- died in the microseconds since. Standing up sends
                    -- /heal which interrupts the rest tick -- doing that
                    -- for a corpse wastes MP regen for nothing. Read fresh,
                    -- abort if dead, mark the rotation done so we don't
                    -- bang on this mob again next tick.
                    local cur_hp = Mob.get_claimed_mob_hp(active_debuff_mob.index)
                    if cur_hp <= 0 then
                        log(string.format('%s: mob dead at stand-up (hp %d) - abandon', next_debuff.spell, cur_hp))
                        Mob.mark_remaining_debuffs_done()
                    elseif stand_up(string.format('Stand up to debuff %s (mob %.1fy, mobHP %d%%, MP %d%%)',
                        next_debuff.spell, active_mob_dist, cur_hp, P.player_mp_pct())) then
                        return
                    end
                end
            else
                if active_mob_hp < floor_hp then
                    -- Log once per mob (see matching guard in the resting
                    -- branch above).
                    if S.abandon_logged_sid ~= S.debuff_mob_sid then
                        S.abandon_logged_sid = S.debuff_mob_sid
                        log(string.format('Mob low HP (%d%% < %d%%) - abandoning remaining debuffs for this mob',
                            active_mob_hp, floor_hp))
                    end
                    Mob.mark_remaining_debuffs_done()
                    -- Fall through to REST LOGIC below: nothing useful to
                    -- do on an almost-dead mob, sit down immediately
                    -- instead of waiting another tick.
                else
                    if (not is_reapply) and active_mob_hp > CFG.DEBUFF_MAX_MOBHP then
                        -- First-round debuff but mob still above 96% HP; wait for
                        -- engagement confirmation before casting. Silent drop-through.
                    else
                        -- Final pre-cast HP read (same reasoning as the
                        -- stand-up branch above). Catches the sub-tick race
                        -- where the mob died between the start-of-tick HP
                        -- snapshot and the moment /ma goes out, so we don't
                        -- fire Dia / Paralyze / Slow into a corpse.
                        local cur_hp = Mob.get_claimed_mob_hp(active_debuff_mob.index)
                        if cur_hp <= 0 then
                            log(string.format('%s: mob dead at cast (hp %d) - abandon', next_debuff.spell, cur_hp))
                            Mob.mark_remaining_debuffs_done()
                        else
                            log(string.format('%s -> <bt>', next_debuff.spell))
                            -- debuffs_done is NOT marked here. The latch
                            -- block at the top of tick() (and the inline
                            -- one in Mob.get_next_debuff) flips it true
                            -- when mob_has_debuff confirms via the
                            -- packet tracker -- the buff cache is the
                            -- single source of truth.
                            --
                            -- Cast-once-per-mob means "cast until the
                            -- cache confirms it landed", not "cast
                            -- exactly one /ma". Resists / interrupts /
                            -- silent misses leave the cache empty and
                            -- get_next_debuff returns the spell again
                            -- next tick (throttled by SPELL_CD: ~20s
                            -- for Slow, ~10s for Paralyze, ~12s for
                            -- Dia). Eventually the cast lands and the
                            -- cache flips, or the mob dies / drops
                            -- below DEBUFF_MIN_MOBHP and the rotation
                            -- abandons it.
                            --
                            -- Dia recast is identical: cascade returns
                            -- Dia whenever the cache shows it absent.
                            -- With reapply ON, that covers wear-off
                            -- after 60s. With reapply OFF, debuffs_done
                            -- (latched on first observation) blocks
                            -- the re-cast.
                            -- Cast at the sid the cascade verified, not
                            -- <bt>. cast_on_target emits a 0x01A action
                            -- packet naming this exact mob, so check and
                            -- cast are guaranteed to be the same mob.
                            if cast_on_target(next_debuff.spell, S.debuff_mob_sid) then
                                return
                            end
                        end
                    end
                end
            end
        end
    end

    if spell_locked() then return end

    -- ----------------------------------------------------------------
    -- 6b. BLM SKILLUP: single selected spell (S.blm_skillup_spell),
    -- cast ONCE per claimed mob. Gates:
    --   - Master toggle on (S.blm_skillup_enabled)
    --   - Mob alive and in range
    --   - Mob HP% ABOVE S.blm_skillup_min_hp_pct (default 50)
    --   - Our MP% AT OR ABOVE S.blm_skillup_min_mp_pct (default 80) --
    --     skillup is optional, only spend MP on it when we have
    --     plenty
    -- Sits at the bottom of the active-cast cascade: HP cures, status
    -- removals, party buffs (Refresh/Haste/Regen), and mob debuffs
    -- all preempt skillup. Skillup is opportunistic so anything with
    -- real party impact gets the cast slot first. skillup_done is
    -- marked at SEND time (not on confirm) so a stuck completion
    -- signal doesn't loop the same skillup against the same mob --
    -- the spam guard in fail_cast_retry still catches genuine
    -- repeated UTC rejects.
    if S.blm_skillup_enabled
       and not P.player_is_resting()       -- /ma while resting => "You cannot use that command while healing"
       and active_debuff_mob ~= nil
       and active_mob_alive_in_range
       and active_mob_hp > S.blm_skillup_min_hp_pct
       and P.player_mp_pct() >= S.blm_skillup_min_mp_pct
       -- (The old `count_claimed_targets(25.0) <= 1` gate lived here --
       -- needed because <bt> could drift to a nearby mob mid-cast. The
       -- skillup cast now names the mob by server id in the action
       -- packet, so it can't land on the wrong mob and the gate is gone.)
    then
        local skillup_spell, skillup_key =
            Mob.get_next_skillup_spell(active_debuff_mob.server_id)
        if skillup_spell then
            log(string.format('Skillup: %s -> sid %d',
                skillup_spell, n(active_debuff_mob.server_id)))
            S.skillup_done[skillup_key] = true
            if cast_on_target(skillup_spell, active_debuff_mob.server_id) then
                return
            end
        end
    end

    if spell_locked() then return end

    -- ----------------------------------------------------------------
    -- STONESKIN (self only). Self-buff maintenance, same pattern as
    -- Reraise but gated by CONVENIENCE_BUFF_MIN_MP_PCT (default 80%)
    -- rather than the much higher Reraise gate -- Stoneskin is cheap
    -- (16 MP, 3s cast) and we want it up most of the time. Cast only
    -- when the buff isn't already active so we don't waste an MP
    -- recast on something the server already has on us.
    -- ----------------------------------------------------------------
    if S.stoneskin_enabled
       and stoneskin_usable()
       and P.player_mp_pct() >= CFG.CONVENIENCE_BUFF_MIN_MP_PCT
       and not self_has_buff(BUFF.STONESKIN)
    then
        if P.player_is_resting() then
            if not auto_full_rest_blocks() then
                if stand_up('Stand for Stoneskin') then
                    return
                end
            end
        else
            log('Stoneskin -> self')
            if cast_on_target('Stoneskin', P.player_name()) then
                return
            end
        end
    end

    -- ----------------------------------------------------------------
    -- BLINK (self only). Same pattern as Stoneskin. Cheap (8 MP, 1.5s
    -- cast) and the shadows are independent of Stoneskin, so they
    -- stack cleanly. Cast only when the buff is absent.
    -- ----------------------------------------------------------------
    if S.blink_enabled
       and blink_usable()
       and P.player_mp_pct() >= CFG.CONVENIENCE_BUFF_MIN_MP_PCT
       and not self_has_buff(BUFF.BLINK)
    then
        if P.player_is_resting() then
            if not auto_full_rest_blocks() then
                if stand_up('Stand for Blink') then
                    return
                end
            end
        else
            log('Blink -> self')
            if cast_on_target('Blink', P.player_name()) then
                return
            end
        end
    end

    -- ----------------------------------------------------------------
    -- PHALANX (self only, RDM 33+). Same pattern as Stoneskin / Blink.
    -- 21 MP, 3s cast, 10s recast, 3-minute buff. Provides flat damage
    -- reduction; stacks with Stoneskin / Blink so safely casts in the
    -- same window. Cast only when the buff is absent.
    -- ----------------------------------------------------------------
    if S.phalanx_enabled
       and phalanx_usable()
       and P.player_mp_pct() >= CFG.CONVENIENCE_BUFF_MIN_MP_PCT
       and not self_has_buff(BUFF.PHALANX)
    then
        if P.player_is_resting() then
            if not auto_full_rest_blocks() then
                if stand_up('Stand for Phalanx') then
                    return
                end
            end
        else
            log('Phalanx -> self')
            if cast_on_target('Phalanx', P.player_name()) then
                return
            end
        end
    end

    -- Closes the `repeat` opened at the top of the cast cascade. The
    -- `until true` exits unconditionally on first iteration; this is
    -- just a one-shot block we can `break` out of from the silence
    -- guard above. The spell_locked guard below still runs even after
    -- a break, so an in-flight cast finishes cleanly before we drop
    -- into REST LOGIC.
    until true

    if spell_locked() then return end

    -- ----------------------------------------------------------------
    -- SMART MOVE (formerly /follow-based Auto Move).
    -- ----------------------------------------------------------------
    -- /follow + /ta were removed -- /follow is unreliable on HXI
    -- (didn't honor /follow off, dragged the player straight onto
    -- the target ignoring the stop threshold). A real controller
    -- needs: (1) a way to face the target (memory write to player
    -- Heading, or a /face-style chat command, or rotate keypress),
    -- (2) a way to hold the W key (keypress synthesis, or a
    -- movement-flag memory write, or a third-party keypress addon).
    -- Neither actuator is currently wired up, so this whole block
    -- is a no-op pending that decision.
    --
    -- The CFG.AUTO_MOVE_TRIGGER_DIST / STOP_DIST hysteresis is
    -- preserved for when the controller comes online; the GUI
    -- party-checkbox list is preserved so the user's target
    -- preferences survive the swap. S.auto_move_active_target is
    -- nilled on every tick here so any stale state from the prior
    -- /follow-based code is cleaned up the first time this runs
    -- after the feature swap.
    if S.auto_move_active_target ~= nil then
        S.auto_move_active_target = nil
        S.auto_move_last_send_at  = 0.0
    end

    -- ----------------------------------------------------------------
    -- REST LOGIC (original, untouched)
    -- ----------------------------------------------------------------
    if P.player_is_resting() then
        -- Force Rest releases on whichever fires first: MP full OR
        -- the 180s timer at the top of tick(). The timer path clears
        -- S.force_rest, then this branch's MP-full check (further
        -- down) decides on stand-up. The MP-full early-release here
        -- handles the common case: Force Rest's purpose is to fully
        -- top off MP; once we're at 100% we've served that purpose
        -- and don't need to sit through the remainder of the timer.
        if S.force_rest and P.player_mp_pct() >= 100 then
            log('Force Rest: MP full, releasing early')
            S.force_rest = false
            S.force_rest_until = 0.0
        end
        -- Still under Force Rest with MP < 100: hold the rest.
        -- Emergency override (force_rest_allows_stand checks ally
        -- HP < FORCE_REST_OVERRIDE_HP_PCT) can still break the lock
        -- for a dying ally via the cure paths above.
        if S.force_rest then
            return
        end
        -- Disable Rest does NOT actively stand the player up. It only
        -- prevents the bot from INITIATING a new rest (see rest_down).
        -- If the player happens to be resting -- because Force Rest just
        -- expired, manual /heal, etc. -- the natural MP-full release
        -- below handles standing. Once sitting, rest all the way to
        -- 100%; the idle floor below only governs when a rest STARTS.
        if P.player_mp_pct() >= 100 then
            stand_up('MP full - standing up')
        end
        return
    end

    -- Idle (not resting): don't initiate a rest unless MP is below the
    -- idle floor. At/above it (e.g. 95-100%) there's nothing worth
    -- kneeling for, so keep watching instead of sitting for a trivial
    -- top-off.
    if P.player_mp_pct() >= IDLE_REST_MP_FLOOR_PCT then
        log('MP above idle rest floor - keep watching')
        return
    end

    if standing_locked() then
        return
    end

    rest_down('Idle - resting')
end

---------------------------------------------------------------------
-- GUI
---------------------------------------------------------------------

local function hp_color(pct)
    if pct >= CFG.NORMAL_CURE_THRESHOLD then
        return {0.27, 1.0, 0.27, 1.0}
    elseif pct > S.emergency_cure_threshold then
        return {1.0, 0.75, 0.2, 1.0}
    else
        return {1.0, 0.3, 0.3, 1.0}
    end
end

-- Targets-array helpers. Each array has 6 slots; '' means empty slot.
-- Using slot-based storage preserves the existing save-file format so
-- old settings continue to load.
local function targets_contains(arr, name)
    if not name or name == '' then return false end
    for i = 1, 6 do
        if (arr[i] or '') == name then return true end
    end
    return false
end

-- Toggle `name`'s membership in arr: add to first empty slot, or clear
-- the slot that holds it. Returns new membership state.
local function targets_toggle(arr, name)
    if not name or name == '' then return false end
    for i = 1, 6 do
        if (arr[i] or '') == name then
            arr[i] = ''
            return false
        end
    end
    for i = 1, 6 do
        if (arr[i] or '') == '' then
            arr[i] = name
            return true
        end
    end
    return false  -- all six slots full
end

-- Render a block of party-member checkboxes for a target section.
-- Each row: [checkbox] Name   [!] [timer]
--   targets_arr  : the backing array (e.g. S.haste_targets)
--   timers_map   : expiry timers by name (e.g. S.haste_timers)
--   id_prefix    : unique ImGui id prefix so widgets don't collide
--   skip_self    : if true, self is shown as a read-only auto-label
--                  instead of a checkbox. Kept as a parameter for
--                  consistency but no current caller passes true --
--                  Refresh used to (self was auto-targeted by
--                  Tgt.next_refresh_target) but self is now a normal
--                  toggleable target like everyone else.
--   buff_id      : optional FFXI status id used to detect buff presence
--                  for the per-row "due" / "Xs" indicator.
--   priority_map : optional name-keyed set. When present, an extra "!"
--                  checkbox is rendered after the name; toggling it
--                  adds/removes the name from the set and the target
--                  finder visits priority members first. Passing nil
--                  hides the priority widget (Regen uses this).
-- Right-aligned 3-letter main-job code for a party slot. Drawn on the
-- CURRENT line via SameLine(). Two positioning modes:
--   fixed_x set  -> SetCursorPosX(fixed_x). Use when the panel has a
--                   header row that picks a column X explicitly (Cures
--                   uses COL_JOB_X so header and rows align).
--   fixed_x nil  -> Dummy spacer eats the remaining width so the label
--                   hugs the right edge. Use for panels without a
--                   header row (Refresh / Haste / Regen / Protect-Shell)
--                   where trailing content width varies row-to-row.
-- Slot's job pulled via the party manager (pcall'd -- some builds return
-- nil/throw for empty slots), then mapped through JOB_NAMES. Missing /
-- unknown jobs render as "---" to mirror player_job_str's convention.
local function render_member_job_right(pm, slot, fixed_x)
    if not pm then return end
    local jid
    pcall(function() jid = pm:GetMemberMainJob(slot) end)
    local jstr = JOB_NAMES[tonumber(jid) or -1] or '---'
    imgui.SameLine()
    if fixed_x then
        imgui.SetCursorPosX(fixed_x)
    else
        -- Approx pixel width of a 3-char label in the default imgui font.
        -- A few px of slack so "---" or wider future strings still fit.
        local JOB_LABEL_W = 28
        local avail = imgui.GetContentRegionAvail()
        if avail and avail > JOB_LABEL_W then
            imgui.Dummy({avail - JOB_LABEL_W, 1})
            imgui.SameLine()
        end
    end
    imgui.TextDisabled(jstr)
end

local function render_party_target_checkboxes(targets_arr, timers_map, id_prefix, skip_self, buff_id, priority_map)
    local pm = party()
    if not pm then return end
    local pname = P.player_name()
    for slot = 0, 5 do
        if n(pm:GetMemberIsActive(slot)) == 1 then
            local mname = pm:GetMemberName(slot) or ''
            if mname ~= '' then
                -- Mirror next_*_target's buff-visibility guard so the GUI
                -- doesn't say "due" while the cast logic is correctly
                -- holding the cast. Stays a numeric timer the whole way:
                --   positive Xs  countdown to recast (normal case)
                --   0s / -Xs     timer is at or past zero but the buff
                --                packet still shows it on. Hits this on
                --                the 5s tail of every Refresh by design
                --                (the timer is set 5s short so the recast
                --                fires the instant the server drops the
                --                buff -- expect a brief "-1s, -2s..."
                --                window once per cycle). Also where you
                --                land if a reload or zone wiped the
                --                timer while the buff itself survived.
                --   "due" (green) timer expired AND buff is gone -- cast
                --                will fire on the next opportunity.
                local buff_present = false
                if buff_id then
                    if mname == pname then
                        buff_present = self_has_buff(buff_id)
                    else
                        buff_present = party_slot_has_buff(slot, buff_id)
                    end
                end

                local timer_val = timers_map[mname]
                -- Don't clamp to 0: when the timer is past, a negative
                -- value is more informative than a stuck "0s".
                local rem = timer_val and (timer_val - now()) or 0

                -- Display the timer column. Three states, in order:
                --   timer set + (buff on OR remaining > 0)  -> "%.0fs"
                --   buff on but no timer (external Haste/Refresh from
                --     another mage, our cast confirmation hasn't been
                --     parsed yet, etc.)                    -> "active"
                --   no buff and timer expired/absent       -> "due" (green)
                -- "active" replaces the old behavior of showing a flat
                -- "0s" whenever the buff was detected without a timer,
                -- which read like "due now" instead of "we just don't
                -- know the remaining time".
                local function render_timer_text(prefix)
                    if timer_val and (buff_present or rem > 0) then
                        imgui.TextDisabled(string.format(prefix .. '%.0fs', rem))
                    elseif buff_present then
                        imgui.TextDisabled(prefix .. 'active')
                    else
                        imgui.TextColored({0.4, 1.0, 0.4, 1.0}, prefix .. 'due')
                    end
                end

                if skip_self and mname == pname then
                    -- Self: auto-target (for Refresh). No checkbox.
                    render_timer_text(string.format('  %s (self)   ', mname))
                    render_member_job_right(pm, slot)
                else
                    local state = { targets_contains(targets_arr, mname) }
                    if imgui.Checkbox('  ' .. mname .. '##' .. id_prefix .. slot, state) then
                        local now_in = targets_toggle(targets_arr, mname)
                        -- If the main checkbox just got unchecked, clear
                        -- the priority bit so it doesn't carry over the
                        -- next time the name is re-added.
                        if not now_in and priority_map then
                            priority_map[mname] = nil
                        end
                    end
                    if targets_contains(targets_arr, mname) then
                        -- Priority marker: only meaningful while the main
                        -- checkbox is on. ASCII "!" instead of a unicode
                        -- star -- the in-game imgui font doesn't have
                        -- glyphs for high-codepoint chars and renders
                        -- them as "?". Hover tooltip explains the bit.
                        if priority_map then
                            imgui.SameLine()
                            local pstate = { priority_map[mname] and true or false }
                            if imgui.Checkbox('!##' .. id_prefix .. 'pri' .. slot, pstate) then
                                priority_map[mname] = pstate[1] and true or nil
                            end
                            if imgui.IsItemHovered() then
                                imgui.SetTooltip('Priority: cast on this member first when both due')
                            end
                        end
                        imgui.SameLine()
                        render_timer_text('')
                    end
                    -- 3-letter main-job code, right-aligned on this row.
                    -- Drawn unconditionally so the job is visible even
                    -- when the member isn't a target (helps decide who
                    -- to tick without alt-tabbing to /party).
                    render_member_job_right(pm, slot)
                end
            end
        end
    end
end

local function render_member_row(label, member)
    if not member.active or member.name == '---' then
        imgui.TextDisabled(string.format('%-3s  ---', label))
        return
    end

    imgui.Text(string.format('%-3s  %-12s', label, member.name:sub(1, 12)))

    imgui.SameLine()
    local col = hp_color(member.hp_pct)
    imgui.TextColored(col, imsafe(string.format('HP%3d%%', member.hp_pct)))

    imgui.SameLine()
    local in_range = member.slot ~= 0 and member.dist <= CFG.CURE_RANGE
    local dtext = dist_str(member.dist)
    if in_range then
        imgui.TextColored({0.5, 1.0, 0.5, 1.0}, dtext)
    else
        imgui.TextDisabled(dtext)
    end
end

-- Renders a button colored when available, gray when not.
-- r,g,b = base color for available state.
-- Returns true only when clicked AND available.
local function spell_button(label, spell_name, w, r, g, b)
    local avail = spell_ready(spell_name)
        and spell_usable(spell_name)
        and P.player_mp() >= (SPELL_MP_COST[spell_name] or 0)
    if avail then
        imgui.PushStyleColor(ImGuiCol_Button,        {r,           g,           b,           1.0})
        imgui.PushStyleColor(ImGuiCol_ButtonHovered, {r + 0.12,    g + 0.12,    b + 0.12,    1.0})
        imgui.PushStyleColor(ImGuiCol_ButtonActive,  {r + 0.22,    g + 0.22,    b + 0.22,    1.0})
    else
        imgui.PushStyleColor(ImGuiCol_Button,        {0.25, 0.25, 0.25, 1.0})
        imgui.PushStyleColor(ImGuiCol_ButtonHovered, {0.25, 0.25, 0.25, 1.0})
        imgui.PushStyleColor(ImGuiCol_ButtonActive,  {0.25, 0.25, 0.25, 1.0})
    end
    local clicked = imgui.Button(label, {w, 0})
    imgui.PopStyleColor(3)
    return clicked and avail
end

-- ============================================================
-- DEBUG BUILD: error traps on the three unprotected event
-- surfaces. Any error prints ONE [BVM DEBUG] chat line with the
-- exact file:line instead of killing the frame / unloading the
-- addon. Remove once the root cause is identified.
-- ============================================================
local _bvmDbgSeen = {}
local function _bvm_dbg(where, err)
    local msg = '[BVM DEBUG] ' .. where .. ' ERROR: ' .. tostring(err)
    if not _bvmDbgSeen[msg] then
        _bvmDbgSeen[msg] = true
        print(msg)
    end
end

local function _bm_present_body()
    if not gui_state.visible then return end

    imgui.SetNextWindowPos({20, 40}, ImGuiCond_FirstUseEver)
    -- Pin width at 320, let height flex to fit current content.
    imgui.SetNextWindowSizeConstraints({320, 0}, {320, 9999})
    imgui.SetNextWindowBgAlpha(0.88)

    -- Global theme: pushed BEFORE Begin / popped AFTER End so the counts
    -- always balance regardless of which early-return path fires inside
    -- the window block. Style vars first, then colors.
    imgui.PushStyleVar(ImGuiStyleVar_WindowRounding,   8.0)
    imgui.PushStyleVar(ImGuiStyleVar_FrameRounding,    5.0)
    imgui.PushStyleVar(ImGuiStyleVar_ChildRounding,    6.0)
    imgui.PushStyleVar(ImGuiStyleVar_PopupRounding,    5.0)
    imgui.PushStyleVar(ImGuiStyleVar_GrabRounding,     4.0)
    imgui.PushStyleVar(ImGuiStyleVar_FramePadding,     {7, 4})
    imgui.PushStyleVar(ImGuiStyleVar_WindowBorderSize, 1.0)

    imgui.PushStyleColor(ImGuiCol_WindowBg,       {0.07, 0.07, 0.09, 0.88})
    imgui.PushStyleColor(ImGuiCol_Border,         {0.30, 0.32, 0.40, 0.60})
    imgui.PushStyleColor(ImGuiCol_FrameBg,        {0.16, 0.17, 0.21, 1.0})
    imgui.PushStyleColor(ImGuiCol_FrameBgHovered, {0.22, 0.24, 0.30, 1.0})
    imgui.PushStyleColor(ImGuiCol_FrameBgActive,  {0.28, 0.30, 0.38, 1.0})
    imgui.PushStyleColor(ImGuiCol_Header,         {0.20, 0.22, 0.28, 1.0})
    imgui.PushStyleColor(ImGuiCol_HeaderHovered,  {0.28, 0.31, 0.40, 1.0})
    imgui.PushStyleColor(ImGuiCol_HeaderActive,   {0.34, 0.37, 0.48, 1.0})
    imgui.PushStyleColor(ImGuiCol_CheckMark,      {0.45, 0.85, 0.50, 1.0})
    imgui.PushStyleColor(ImGuiCol_Separator,      {0.30, 0.32, 0.40, 0.50})
    imgui.PushStyleColor(ImGuiCol_Text,           {0.92, 0.92, 0.94, 1.0})

    local open = { true }
    -- AlwaysAutoResize = window follows content height every frame, so
    -- collapsing Controls / Debug / Log sections doesn't leave empty space.
    local win_flags = bit.bor(ImGuiWindowFlags_NoScrollbar,
                              ImGuiWindowFlags_AlwaysAutoResize)
    if imgui.Begin('Bovine Mage', open, win_flags) then

        if open[1] == false then
            send('/addon unload bovinemage')
            imgui.End()
            imgui.PopStyleColor(11)
            imgui.PopStyleVar(7)
            return
        end

        -- Start / Stop
        if S.running then
            imgui.PushStyleColor(ImGuiCol_Button,        {0.15, 0.55, 0.15, 1.0})
            imgui.PushStyleColor(ImGuiCol_ButtonHovered, {0.2,  0.7,  0.2,  1.0})
            if imgui.Button('  Stop  ', {-1, 0}) then
                S.running = false
                -- Do NOT send /heal here. Stop means "bot stops acting",
                -- not "change the player's stance". If the player was
                -- resting, they stay resting.
            end
            imgui.PopStyleColor(2)
        else
            imgui.PushStyleColor(ImGuiCol_Button,        {0.15, 0.35, 0.65, 1.0})
            imgui.PushStyleColor(ImGuiCol_ButtonHovered, {0.2,  0.45, 0.8,  1.0})
            if imgui.Button(' Start  ', {-1, 0}) then
                S.running = true
                spell_clear()
                S.spell_lock_until = 0.0
                -- Stand-lock: set a grace window instead of wiping it.
                -- If we wiped it (stand_lock_until = 0), the very next tick
                -- would see "standing + low MP + not locked" and immediately
                -- fire rest_down -> /heal. The grace window prevents the
                -- "I pressed Start and it instantly /heal'd me" surprise.
                S.stand_lock_until = now() + STAY_STANDING_SEC
            end
            imgui.PopStyleColor(2)
        end

        -- Force Rest toggle.
        -- Behavior:
        --   * If standing: cancels the action cascade after the
        --     emergency-cure section (see "FORCE REST cascade gate"
        --     in tick()) so we don't fire new casts; falls through
        --     to REST LOGIC which sits us down. Any in-flight cast
        --     completes naturally first (spell_locked / POST_CAST_SETTLE).
        --   * While resting: holds the rest until MP is full OR the
        --     FORCE_REST_DURATION (180s) timer expires, whichever
        --     comes first. Beats Disable Rest. Cancellable by
        --     clicking the button again.
        --   * Emergency override still applies: ally HP%
        --     < FORCE_REST_OVERRIDE_HP_PCT AND player MP
        --     >= FORCE_REST_OVERRIDE_MIN_MP allows stand-up for an
        --     emergency cure cast.
        if S.force_rest then
            local remaining = math.max(0, S.force_rest_until - now())
            local mins = math.floor(remaining / 60)
            local secs = math.floor(remaining % 60)
            imgui.PushStyleColor(ImGuiCol_Button,        {0.70, 0.48, 0.10, 1.0})
            imgui.PushStyleColor(ImGuiCol_ButtonHovered, {0.85, 0.58, 0.15, 1.0})
            if imgui.Button(string.format('Force Rest: %d:%02d', mins, secs), {-1, 0}) then
                S.force_rest = false
                S.force_rest_until = 0.0
                log('Force Rest: cancelled')
            end
            imgui.PopStyleColor(2)
        else
            imgui.PushStyleColor(ImGuiCol_Button,        {0.35, 0.30, 0.20, 1.0})
            imgui.PushStyleColor(ImGuiCol_ButtonHovered, {0.50, 0.42, 0.28, 1.0})
            if imgui.Button(string.format(' Force Rest (%ds) ', FORCE_REST_DURATION), {-1, 0}) then
                S.force_rest = true
                S.force_rest_until = now() + FORCE_REST_DURATION
                -- Clear the stand-lock grace window so the idle branch can
                -- rest the player down immediately rather than waiting.
                S.stand_lock_until = 0.0
                log(string.format('Force Rest: ON (%ds timer)', FORCE_REST_DURATION))
            end
            imgui.PopStyleColor(2)
        end

        -- Healermode forward buttons: fire-and-forget.
        -- These do NOT consult MP, running state, cast lock, or anything
        -- else; clicking either one immediately sends the corresponding
        -- /lac fwd healermode command (whitelisted in ALLOWED_CMDS).
        -- Side-by-side, half width each.
        local hmw = (imgui.GetContentRegionAvail() - 4) / 2
        imgui.PushStyleColor(ImGuiCol_Button,        {0.20, 0.45, 0.25, 1.0})
        imgui.PushStyleColor(ImGuiCol_ButtonHovered, {0.30, 0.60, 0.35, 1.0})
        if imgui.Button('Healer ON', {hmw, 0}) then
            send('/lac fwd healermode on')
            log('healermode on')
        end
        imgui.PopStyleColor(2)
        imgui.SameLine()
        imgui.PushStyleColor(ImGuiCol_Button,        {0.50, 0.20, 0.20, 1.0})
        imgui.PushStyleColor(ImGuiCol_ButtonHovered, {0.65, 0.30, 0.30, 1.0})
        if imgui.Button('Healer OFF', {-1, 0}) then
            send('/lac fwd healermode off')
            log('healermode off')
        end
        imgui.PopStyleColor(2)

        -- Dispel (full width, purple)
        if spell_button(' Dispel ', 'Dispel', -1, 0.50, 0.20, 0.50) then
            S.dispel_pending = true
            log('Dispel queued')
        end

        -- Sleep | Bind side by side
        local hw = (imgui.GetContentRegionAvail() - 4) / 2
        if spell_button(' Sleep ', 'Sleep', hw, 0.15, 0.38, 0.55) then
            S.sleep_pending = true
            log('Sleep queued')
        end
        imgui.SameLine()
        if spell_button(' Bind ', 'Bind', -1, 0.50, 0.32, 0.08) then
            S.bind_pending = true
            log('Bind queued')
        end

        imgui.Separator()

        -- Status / Level / MP / Party / Controls are all wrapped in a
        -- collapsible "Status: ..." header so the window can be compacted
        -- to just the action buttons when screen space matters. The
        -- ###bm_status_hdr suffix pins the ImGui id so the open/closed
        -- state survives status-label changes.
        local status
        if not S.running then
            status = 'Stopped'
        elseif P.player_is_resting() then
            if S.force_rest then
                local fr_rem = math.max(0, S.force_rest_until - now())
                status = string.format('Force Resting (%d:%02d)',
                    math.floor(fr_rem / 60), math.floor(fr_rem % 60))
            else
                status = 'Resting'
            end
        elseif S.is_casting then
            local remaining = S.cast_timeout_at - now()
            local sname = S.last_spell_sent_raw or S.last_spell_sent or '?'
            status = string.format('Casting %s... (%.1fs)', sname, math.max(0, remaining))
        elseif S.force_rest then
            local fr_rem = math.max(0, S.force_rest_until - now())
            status = string.format('Force Rest standing (%d:%02d)',
                math.floor(fr_rem / 60), math.floor(fr_rem % 60))
        elseif standing_locked() then
            status = string.format('Standing lock (%.1fs)', math.max(0, S.stand_lock_until - now()))
        elseif any_mob_claimed_by_party() then
            status = 'Watching'
        else
            status = 'Idle'
        end

        if imgui.CollapsingHeader(
                string.format('Status: %s###bm_status_hdr', status),
                IMGUI_TREE_DEFAULT_OPEN)
        then

        imgui.Text(string.format('Level:  %d  %s', P.player_level(), player_job_str()))
        imgui.Text(imsafe(string.format('MP:     %d (%d%%)', P.player_mp(), P.player_mp_pct())))

        imgui.Separator()

        -- Party list
        imgui.TextDisabled('     Name              HP     Dist')
        imgui.Separator()

        local snap = Mob.get_party_snapshot()
        for i, m in ipairs(snap) do
            render_member_row(string.format('P%d', i), m)
        end
        if #snap == 0 then
            imgui.TextDisabled('  (no party members)')
        end

        imgui.Separator()

        -- Everything below — Cure, Debuff, Auto-Dispel, Paralyna/Silena/Poisona,
        -- Refresh/Haste/Regen — lives under one collapsible "Controls" header
        -- so the window can be compacted to just Status + Party when not needed.
        -- Flag 32 = ImGuiTreeNodeFlags_DefaultOpen (starts expanded on load).
        if imgui.CollapsingHeader('Controls', IMGUI_TREE_DEFAULT_OPEN) then

        -- Auto Full Rest: see auto_full_rest_blocks() for the gate logic.
        -- Affects the debuff stand path only; emergency cure still fires.
        local afr = { S.auto_full_rest }
        if imgui.Checkbox('Auto Full Rest', afr) then
            S.auto_full_rest = afr[1]
        end
        imgui.SameLine()
        imgui.TextDisabled(string.format('(%ds / %d%%+ -> wait for full)',
            AUTO_FULL_REST_SEC, AUTO_FULL_REST_MP_PCT))

        -- Disable Rest: dual-layer.
        --   1. Sends /heal disable true|false so the external auto-heal
        --      system stays in sync.
        --   2. Sets S.disable_rest so the addon's own rest_down refuses
        --      to issue /heal calls. Does NOT actively stand the player
        --      up if currently resting -- it only prevents NEW rests.
        local dr = { S.disable_rest }
        if imgui.Checkbox('Disable Rest', dr) then
            S.disable_rest = dr[1]
            if S.disable_rest then
                send('/heal disable true')
                log('Disable Rest: ON  (sent /heal disable true)')
            else
                send('/heal disable false')
                log('Disable Rest: OFF (sent /heal disable false)')
            end
        end

        imgui.Separator()

        -- Cures header label surfaces the cure tier that cast_normal_cure
        -- would actually pick (tiers[2] or tiers[1]) plus its live recast
        -- state. For RDM55/WHM41/PLD55+ this is Cure III; lower levels
        -- show whatever the player has access to. Stable ###cures_hdr id
        -- keeps the collapse state across label changes.
        do
            local cure_tiers_now = get_cure_tiers()
            local cure_spell_now = cure_tiers_now[2] or cure_tiers_now[1]
            local cure_hdr_label
            if cure_spell_now then
                cure_hdr_label = string.format('Cures  (%s  Ready: %s)###cures_hdr',
                    cure_spell_now, spell_ready_label(cure_spell_now))
            else
                cure_hdr_label = 'Cures  (no tier)###cures_hdr'
            end
            if imgui.CollapsingHeader(cure_hdr_label, IMGUI_TREE_DEFAULT_OPEN) then
        -- Emergency cure HP threshold (35 vs 50). Mutually exclusive: clicking
        -- one sets the threshold; clicking the already-active one is a no-op.
        -- Also drives the party-row HP color band (hp_color reads the same S
        -- field) so 45% HP displays yellow under 35% threshold and red under 50%.
        imgui.Text('Emergency cure at:')
        imgui.SameLine()
        local e50 = { S.emergency_cure_threshold == 50 }
        if imgui.Checkbox('50%##ec50', e50) then
            S.emergency_cure_threshold = 50
        end
        imgui.SameLine()
        local e35 = { S.emergency_cure_threshold == 35 }
        if imgui.Checkbox('35%##ec35', e35) then
            S.emergency_cure_threshold = 35
        end

        -- Cure section: master kill switch + a vertical per-member list
        -- with two checkbox columns ("Cure" and "Emg. Cure") and a
        -- vertical separator between them.
        --
        -- Layout (320px window):
        --   [ ] Disable Cure        (panic kill switch)
        --              Cure | Emg. Cure | Brd
        --     Alice*    [X]  |   [X]    | [ ]
        --     Bob       [X]  |   [X]    | [ ]
        --     Brduser   [ ]  |   [ ]    | [X]   <- anti-overcure only
        --
        -- "Disable Cure" master: when checked, NO cures fire at all
        -- (normal, emergency, DRG override -- all suppressed). It's a
        -- panic button; the real granular control is the per-member
        -- Cure/Emg.Cure columns below. Each row's two checkboxes are
        -- independent. Checked = include the member in that band. The
        -- exclusion lists track the *unchecked* state so an empty list
        -- means "everyone is included" by default. Trailing "*" marks
        -- self.
        local dis = { S.disable_cure }
        if imgui.Checkbox('Disable Cure', dis) then
            S.disable_cure = dis[1]
        end
        imgui.SameLine()
        imgui.TextDisabled('(no cures cast if checked)')

        -- Column X positions, tuned for a 320 px window. The cursor X
        -- is window-local: 0 is the left edge of the window's content
        -- area. Picked so longest realistic FFXI names (15 chars + "*")
        -- fit in the name column without colliding with the Cure
        -- checkbox.
        local COL_CURE_X  = 118    -- Cure checkbox column
        local COL_SEP_X   = 152    -- vertical "|" separator
        local COL_ECURE_X = 166    -- Emg. Cure checkbox column
        local COL_SEP2_X  = 232    -- second vertical "|" separator
        local COL_BRD_X   = 246    -- Brd anti-overcure checkbox column
        local COL_JOB_X   = 278    -- 3-letter main-job code column.
                                   -- BRD checkbox ends ~X=268 (246 + ~22px
                                   -- box width); 278 leaves ~10px gap and
                                   -- lands the 3-char label ~X=300, just
                                   -- inside the 320-wide window's content
                                   -- right edge.

        -- Header row. Empty cell at the start so the headers align
        -- over the checkbox columns below, not over the names.
        imgui.Text(' ')
        imgui.SameLine()
        imgui.SetCursorPosX(COL_CURE_X)
        imgui.TextDisabled('Cure')
        imgui.SameLine()
        imgui.SetCursorPosX(COL_SEP_X)
        imgui.TextDisabled('|')
        imgui.SameLine()
        imgui.SetCursorPosX(COL_ECURE_X)
        imgui.TextDisabled('Emg. Cure')
        imgui.SameLine()
        imgui.SetCursorPosX(COL_SEP2_X)
        imgui.TextDisabled('|')
        imgui.SameLine()
        imgui.SetCursorPosX(COL_BRD_X)
        imgui.TextDisabled('Brd')
        imgui.SameLine()
        imgui.SetCursorPosX(COL_JOB_X)
        imgui.TextDisabled('Job')

        -- Per-member rows. Skipped entirely if the party manager is
        -- unavailable (mid-zone, etc.); next tick will populate.
        local pm_cure = party()
        if pm_cure then
            local pname_cure = P.player_name()
            for slot = 0, 5 do
                if n(pm_cure:GetMemberIsActive(slot)) == 1 then
                    local mname = pm_cure:GetMemberName(slot) or ''
                    if mname ~= '' then
                        -- Name (with trailing "*" for self)
                        local label_name = (mname == pname_cure)
                            and ('  ' .. mname .. '*')
                            or  ('  ' .. mname)
                        imgui.Text(label_name)

                        -- Helper: render one checkbox at the given X
                        -- column, backed by the given exclusion list.
                        -- Inverted semantic: ticked = NOT in list.
                        -- Returns nothing; mutates list directly.
                        local function render_box(col_x, list, id_prefix)
                            imgui.SameLine()
                            imgui.SetCursorPosX(col_x)
                            local in_excluded = false
                            for i = 1, 6 do
                                if (list[i] or '') == mname then
                                    in_excluded = true
                                    break
                                end
                            end
                            local state = { not in_excluded }
                            if imgui.Checkbox('##' .. id_prefix .. slot, state) then
                                if state[1] then
                                    -- now checked -> remove from list
                                    for i = 1, 6 do
                                        if (list[i] or '') == mname then
                                            list[i] = ''
                                            break
                                        end
                                    end
                                else
                                    -- now unchecked -> add to first empty slot
                                    for i = 1, 6 do
                                        if (list[i] or '') == '' then
                                            list[i] = mname
                                            break
                                        end
                                    end
                                end
                            end
                        end

                        render_box(COL_CURE_X,  S.cure_only_emergency,    'cure_box_')

                        -- Vertical separator between the two checkbox
                        -- columns. ImGui doesn't ship a vertical
                        -- separator widget in this Ashita build, so
                        -- a "|" character does the job and is cheap.
                        imgui.SameLine()
                        imgui.SetCursorPosX(COL_SEP_X)
                        imgui.TextDisabled('|')

                        render_box(COL_ECURE_X, S.emergency_cure_excluded, 'ecure_box_')

                        -- Second separator before the Brd column.
                        imgui.SameLine()
                        imgui.SetCursorPosX(COL_SEP2_X)
                        imgui.TextDisabled('|')

                        -- Brd anti-overcure box. Unlike the two boxes
                        -- above (inverted: ticked = NOT excluded), this
                        -- one is INCLUSION: ticked = enrolled in the
                        -- anti-overcure path. Enrolling a member here
                        -- means they are healed ONLY by the no-overheal
                        -- picker; their Cure / Emg. Cure handling is
                        -- bypassed entirely (the snapshot loop routes
                        -- in_brd members away from both bands).
                        imgui.SameLine()
                        imgui.SetCursorPosX(COL_BRD_X)
                        local in_brd = false
                        for i = 1, 6 do
                            if (S.brd_overcure[i] or '') == mname then
                                in_brd = true
                                break
                            end
                        end
                        local bstate = { in_brd }
                        if imgui.Checkbox('##brd_box_' .. slot, bstate) then
                            if bstate[1] then
                                -- now checked -> add to first empty slot
                                for i = 1, 6 do
                                    if (S.brd_overcure[i] or '') == '' then
                                        S.brd_overcure[i] = mname
                                        break
                                    end
                                end
                            else
                                -- now unchecked -> remove from list
                                for i = 1, 6 do
                                    if (S.brd_overcure[i] or '') == mname then
                                        S.brd_overcure[i] = ''
                                        break
                                    end
                                end
                            end
                        end
                        if imgui.IsItemHovered() then
                            imgui.SetTooltip(
                                'Anti-overcure: when at or below 50%%,\n'
                                .. 'heal ONLY with the largest cure that\n'
                                .. 'will NOT push them above 74%% (estimate\n'
                                .. '+10%%); re-checks HP before and during\n'
                                .. 'the cast and /heal-cancels mid-cast if\n'
                                .. "topped off. Disables this member's\n"
                                .. 'normal Cure / Emg. Cure.')
                        end
                        -- 3-letter main-job code, aligned to COL_JOB_X
                        -- so it sits directly under the "Job" header.
                        render_member_job_right(pm_cure, slot, COL_JOB_X)
                    end
                end
            end
        end
            end  -- /Cures CollapsingHeader (if)
        end  -- /Cures do block (scopes cure_tiers_now/cure_spell_now/cure_hdr_label)

        -- DRG Healer Mode: a SEPARATE parallel cure trigger that does
        -- NOT touch the emergency 35/50 toggle above. Hardcoded 50%
        -- band. Fires when 2+ members are <=50% (cures the higher-HP
        -- one; the wyvern's Healing Breath picks up the lower one), or
        -- a single member sustains <=50% for `wait` seconds (slider).
        -- Suppressed entirely when Disable Cure is on. In its own
        -- header so DRG-specific tuning stays out of the main Cures
        -- section for non-DRG parties.
        if imgui.CollapsingHeader('DRG Healer', IMGUI_TREE_DEFAULT_OPEN) then
            local drg = { S.drg_healer_mode }
            if imgui.Checkbox('DRG Healer Mode', drg) then
                S.drg_healer_mode = drg[1]
                if not S.drg_healer_mode then
                    S.drg_low_since = {}
                end
            end
            imgui.SameLine()
            imgui.TextDisabled('(?)')
            if imgui.IsItemHovered() then
                imgui.SetTooltip(
                    'Force Cure if 2 people need Cure,\n'
                    .. 'or someone needs Cure for long time')
            end

            -- Sustain slider: how long a single member has to stay
            -- at/below CFG.DRG_HEALER_THRESHOLD before the DRG cure
            -- fires. Wider waits give the wyvern more time to land
            -- Healing Breath; shorter is safer if the wyvern keeps
            -- missing. Slider stays editable even when DRG Healer
            -- Mode is off so the value can be tuned in advance.
            local sustain = { S.drg_sustain_sec }
            imgui.PushItemWidth(140)
            if imgui.SliderFloat('##drg_sustain', sustain,
                                 DRG_SUSTAIN_MIN, DRG_SUSTAIN_MAX, '%.1fs wait') then
                S.drg_sustain_sec = sustain[1]
            end
            imgui.PopItemWidth()
        end

        if imgui.CollapsingHeader('Smart Move', IMGUI_TREE_DEFAULT_OPEN) then
            local am = { S.auto_move_enabled }
            if imgui.Checkbox('Smart Move ON (pending actuator)', am) then
                S.auto_move_enabled = am[1]
                S.auto_move_active_target = nil
                S.auto_move_last_send_at  = 0.0
            end
            imgui.SameLine()
            imgui.TextDisabled('(?)')
            if imgui.IsItemHovered() then
                imgui.SetTooltip(
                    'PENDING: the /follow-based mover was removed --\n'
                    .. '/follow was unreliable on HXI (ignored /follow off,\n'
                    .. 'walked all the way onto the target).\n\n'
                    .. 'The replacement WASD-style controller is not yet\n'
                    .. 'wired up -- needs an actuator for "face target"\n'
                    .. 'and "walk forward". Toggle + checkboxes are\n'
                    .. 'preserved so the wiring step is fast once the\n'
                    .. 'actuator is decided.')
            end

            -- Party-member checkbox list. Same render as before -- the
            -- target preferences (who to close on, who to ignore) are
            -- the user's intent and outlive the actuator swap.
            local pm = party()
            if pm then
                for slot = 1, 5 do
                    if n(pm:GetMemberIsActive(slot)) == 1 then
                        local mname = pm:GetMemberName(slot) or ''
                        if mname ~= '' then
                            local state = { targets_contains(S.auto_move_targets, mname) }
                            if imgui.Checkbox('  ' .. mname .. '##am' .. slot, state) then
                                targets_toggle(S.auto_move_targets, mname)
                            end
                        end
                    end
                end
            end
        end

        if imgui.CollapsingHeader('Mob Debuffs', IMGUI_TREE_DEFAULT_OPEN) then
        -- Debuff checkbox
        local deb = { S.debuff_enabled }
        if imgui.Checkbox('Debuff', deb) then
            S.debuff_enabled = deb[1]
        end

        -- Per-debuff toggles (gated by master Debuff checkbox).
        -- Dia I / Dia II / Bio I / Bio II are mutually exclusive: only
        -- one of the four can be active at a time (HorizonXI: Bio and
        -- Dia overwrite each other on the mob). Toggling any one off
        -- sets dia_tier=0 (off); toggling any one on auto-unchecks the
        -- others by setting dia_tier to that tier's value.
        if S.debuff_enabled then
            local dia1 = { S.dia_tier == 1 }
            if imgui.Checkbox('  Dia', dia1) then
                S.dia_tier = dia1[1] and 1 or 0
            end
            imgui.SameLine()
            local dia2 = { S.dia_tier == 2 }
            if imgui.Checkbox('Dia II', dia2) then
                S.dia_tier = dia2[1] and 2 or 0
            end
            imgui.SameLine()
            local bio1 = { S.dia_tier == 3 }
            if imgui.Checkbox('Bio', bio1) then
                S.dia_tier = bio1[1] and 3 or 0
            end
            imgui.SameLine()
            local bio2 = { S.dia_tier == 4 }
            if imgui.Checkbox('Bio II', bio2) then
                S.dia_tier = bio2[1] and 4 or 0
            end

            local pa = { S.paralyze_enabled }
            if imgui.Checkbox('  Paralyze', pa) then
                S.paralyze_enabled = pa[1]
            end

            local sl = { S.slow_enabled }
            if imgui.Checkbox('  Slow', sl) then
                S.slow_enabled = sl[1]
            end

            local bl = { S.blind_enabled }
            if imgui.Checkbox('  Blind', bl) then
                S.blind_enabled = bl[1]
            end

            -- Reapply checkbox (gated by Debuff). Affects Dia/Dia II/
            -- Bio/Bio II and Silence; Paralyze/Slow remain one-shot per
            -- mob regardless. Silence specifically benefits from reapply
            -- because its 2-minute duration is shorter than most NM
            -- fights, so without reapply the NM resumes nuking mid-fight.
            local rea = { S.debuff_reapply_enabled }
            if imgui.Checkbox('  Reapply (Dia/Bio family/Silence)', rea) then
                S.debuff_reapply_enabled = rea[1]
            end
        end

        -- Auto-Dispel checkbox: dispel problem mob buffs (Evasion Boost etc.)
        -- on sight, even if resting. Independent of the Debuff rotation above.
        local ad = { S.auto_dispel_enabled }
        if imgui.Checkbox('Auto-Dispel (Evasion Boost, etc.)', ad) then
            S.auto_dispel_enabled = ad[1]
        end

        -- Priority Silence on a named mob. Independent of the master
        -- Debuff toggle: a casting NM is the kill-the-party threat
        -- and we want to be able to shut it up without enabling
        -- the full Dia/Para/Slow rotation. Targeting by name uses
        -- FFXI's standard /ma "Silence" "MobName" route (works for
        -- unique-name NMs; for non-unique mob names the server picks
        -- one, typically the closest claimed).
        imgui.Separator()
        local ms = { S.mob_silence_enabled }
        if imgui.Checkbox('Silence (priority on named mob)', ms) then
            S.mob_silence_enabled = ms[1]
        end
        if S.mob_silence_enabled then
            imgui.Text('  Mob name:')
            imgui.SameLine()
            -- While the bot is running, render plain disabled-style
            -- text instead of an InputText widget. There's no
            -- imgui.BeginDisabled in Ashita's imgui build (the API
            -- was added in dear imgui 1.85, Ashita ships older), and
            -- ImGuiInputTextFlags_ReadOnly alone leaves the field in
            -- the tab focus order -- which the user can land on with
            -- tab even though edits don't stick. Swapping to a
            -- non-interactable Text widget is the simplest fix that
            -- works everywhere: no widget => nothing to tab to. Stop
            -- the bot to edit; this also avoids racing the
            -- silence_done_for_sid latch on a mid-run target swap.
            if S.running then
                imgui.TextDisabled(S.mob_silence_target or '')
            else
                imgui.PushItemWidth(220)
                local buf = { S.mob_silence_target or '' }
                if imgui.InputText('##bm_silence_target', buf, 64) then
                    S.mob_silence_target = buf[1] or ''
                end
                imgui.PopItemWidth()
            end
        end

        end  -- /Mob Debuffs

        -- Status Cures: the -na spells (Paralyna, Silena, Poisona, Blindna).
        -- All party-targeted, all auto-fire when a p0->p5 member shows the
        -- corresponding status. Grouped here so they can be collapsed
        -- together when not needed for a given party setup.
        if imgui.CollapsingHeader('Status Cures', IMGUI_TREE_DEFAULT_OPEN) then
            local par = { S.paralyna_enabled }
            if imgui.Checkbox('Paralyna (p0-p5)', par) then
                S.paralyna_enabled = par[1]
            end

            local sil = { S.silena_enabled }
            if imgui.Checkbox('Silena (p0-p5)', sil) then
                S.silena_enabled = sil[1]
            end

            local poi = { S.poisona_enabled }
            if imgui.Checkbox('Poisona (p0-p5)', poi) then
                S.poisona_enabled = poi[1]
            end

            local bln = { S.blindna_enabled }
            if imgui.Checkbox('Blindna (p0-p5)', bln) then
                S.blindna_enabled = bln[1]
            end
        end

        -- Self Buffs: things we cast on ourselves to stay alive/buffed.
        -- Reraise gates on its own MP threshold (CFG.RERAISE_MIN_MP_PCT);
        -- Stoneskin and Blink share the convenience-buff MP gate (80%).
        -- Each row is only shown when the player's job/level can actually
        -- cast that spell, so non-RDM/WHM mains see a clean section.
        if imgui.CollapsingHeader('Self Buffs', IMGUI_TREE_DEFAULT_OPEN) then
            if reraise_usable() then
                local rr = { S.reraise_enabled }
                if imgui.Checkbox('Reraise (self, at ' .. CFG.RERAISE_MIN_MP_PCT .. '%+ MP)', rr) then
                    S.reraise_enabled = rr[1]
                end
            end

            if stoneskin_usable() then
                local ss = { S.stoneskin_enabled }
                if imgui.Checkbox('Stoneskin (self, at ' .. CFG.CONVENIENCE_BUFF_MIN_MP_PCT .. '%+ MP)', ss) then
                    S.stoneskin_enabled = ss[1]
                end
            end

            if blink_usable() then
                local bk = { S.blink_enabled }
                if imgui.Checkbox('Blink (self, at ' .. CFG.CONVENIENCE_BUFF_MIN_MP_PCT .. '%+ MP)', bk) then
                    S.blink_enabled = bk[1]
                end
            end

            if phalanx_usable() then
                local pl = { S.phalanx_enabled }
                if imgui.Checkbox('Phalanx (self, at ' .. CFG.CONVENIENCE_BUFF_MIN_MP_PCT .. '%+ MP)', pl) then
                    S.phalanx_enabled = pl[1]
                end
            end
        end

        -- BLM Skillup. Single-selected spell, cast once per claimed
        -- mob. Default off (opt-in) so it doesn't fire in a real
        -- party without intent. Radio-button picker means exactly
        -- one element/tier is active at a time -- choose what
        -- you're training right now and let the cascade work
        -- through mobs.
        local sku_label = S.blm_skillup_enabled and 'BLM Skillup  [on]###blm_skillup_hdr'
                                                or  'BLM Skillup  [off]###blm_skillup_hdr'
        if imgui.CollapsingHeader(sku_label, 0) then
            local sku = { S.blm_skillup_enabled }
            if imgui.Checkbox('Enable BLM Skillup', sku) then
                S.blm_skillup_enabled = sku[1]
            end

            -- Mob HP floor. Fires while mob HP% is ABOVE this --
            -- below it, the cast is wasted (mob dies during the
            -- cast bar). Default 50%.
            local hp_pct = { S.blm_skillup_min_hp_pct }
            imgui.PushItemWidth(180)
            if imgui.SliderInt('Min mob HP##sku_hp', hp_pct, 5, 100, '%d%%+') then
                S.blm_skillup_min_hp_pct = hp_pct[1]
            end
            imgui.PopItemWidth()

            -- Player MP floor. Skillup is optional MP burn, so
            -- only fires when our pool is comfortable. Default
            -- 80%. Slider runs 10-100 so it can't be set so low
            -- that skillup competes with cures.
            local mp_pct = { S.blm_skillup_min_mp_pct }
            imgui.PushItemWidth(180)
            if imgui.SliderInt('Min own MP##sku_mp', mp_pct, 10, 100, '%d%%+') then
                S.blm_skillup_min_mp_pct = mp_pct[1]
            end
            imgui.PopItemWidth()

            imgui.Separator()
            imgui.TextDisabled('Spell (one selected, once per mob):')

            -- RadioButton group: clicking a button writes that
            -- spell's exact name into S.blm_skillup_spell. The
            -- "==" comparison gives the highlighted/selected
            -- state. Same SPELL_* lookup keys the cascade and
            -- spell_lookup use.
            local function radio(label, spell_name)
                if imgui.RadioButton(label, S.blm_skillup_spell == spell_name) then
                    S.blm_skillup_spell = spell_name
                end
            end

            radio('Stone',       'Stone')
            imgui.SameLine()
            radio('Stone II',    'Stone II')

            radio('Water',       'Water')
            imgui.SameLine()
            radio('Water II',    'Water II')

            radio('Aero',        'Aero')
            imgui.SameLine()
            radio('Aero II',     'Aero II')

            radio('Blizzard',    'Blizzard')
            imgui.SameLine()
            radio('Blizzard II', 'Blizzard II')
        end

        -- Refresh section (only shown if job/level can cast it).
        -- Collapsible so target lists can be tucked away once configured.
        -- The "###refresh_hdr" suffix makes the header's ImGui id stable
        -- even when the on/off label part changes, so the collapsed/open
        -- state sticks across toggles.
        if refresh_usable() then
            local st = S.refresh_enabled and 'on' or 'off'
            local rdy = spell_ready_label('Refresh')
            if imgui.CollapsingHeader(string.format('Refresh  [%s]  Ready: %s###refresh_hdr', st, rdy),
                                      IMGUI_TREE_DEFAULT_OPEN) then
                local ref = { S.refresh_enabled }
                if imgui.Checkbox('Refresh', ref) then
                    S.refresh_enabled = ref[1]
                end

                if S.refresh_enabled then
                    render_party_target_checkboxes(S.refresh_extras,
                                                   S.refresh_timers,
                                                   'refresh_',
                                                   false,           -- self togglable like Haste
                                                   BUFF.REFRESH,
                                                   S.refresh_priority)
                end
            end
            imgui.Separator()
        end

        -- Haste section (only shown if job/level can cast it)
        -- Haste section (only shown if job/level can cast it). Collapsible.
        if haste_usable() then
            local st = S.haste_enabled and 'on' or 'off'
            local rdy = spell_ready_label('Haste')
            if imgui.CollapsingHeader(string.format('Haste  [%s]  Ready: %s###haste_hdr', st, rdy),
                                      IMGUI_TREE_DEFAULT_OPEN) then
                local hst = { S.haste_enabled }
                if imgui.Checkbox('Haste', hst) then
                    S.haste_enabled = hst[1]
                end

                if S.haste_enabled then
                    render_party_target_checkboxes(S.haste_targets,
                                                   S.haste_timers,
                                                   'haste_',
                                                   false,           -- self is togglable
                                                   BUFF.HASTE,
                                                   S.haste_priority)
                end
            end
            imgui.Separator()
        end

        -- Regen section. Collapsible.
        do
            local st = S.regen_enabled and 'on' or 'off'
            local rdy = spell_ready_label('Regen')
            if imgui.CollapsingHeader(string.format('Regen  [%s]  Ready: %s###regen_hdr', st, rdy),
                                      IMGUI_TREE_DEFAULT_OPEN) then
                local reg = { S.regen_enabled }
                if imgui.Checkbox('Regen', reg) then
                    S.regen_enabled = reg[1]
                end

                if S.regen_enabled then
                    render_party_target_checkboxes(S.regen_targets,
                                                   S.regen_timers,
                                                   'regen_',
                                                   false,           -- self is togglable
                                                   BUFF.REGEN)
                end
            end
        end

        -- Protect / Shell section. Per-player CheckP / CheckS columns in
        -- one row. Shown only when the player can cast at least Protect I
        -- (we never need Shell without Protect; if level/job blocks
        -- Protect we hide the whole section, since a sub-WHM with
        -- protect available is also able to cast shell at the right level).
        if protect_usable() or shell_usable() then
            local pst = S.protect_enabled and 'on' or 'off'
            local sst = S.shell_enabled   and 'on' or 'off'
            local ptier = highest_protect_tier()
            local stier = highest_shell_tier()
            local prdy = ptier and spell_ready_label(ptier) or '-'
            local srdy = stier and spell_ready_label(stier) or '-'
            local hdr  = string.format('Protect/Shell  P:[%s]%s  S:[%s]%s###protshell_hdr',
                pst, ptier and (' ('..ptier..' '..prdy..')') or '',
                sst, stier and (' ('..stier..' '..srdy..')') or '')
            if imgui.CollapsingHeader(hdr, IMGUI_TREE_DEFAULT_OPEN) then
                -- Master toggles on one line.
                if protect_usable() then
                    local pe = { S.protect_enabled }
                    if imgui.Checkbox('Protect##protshell_master', pe) then
                        S.protect_enabled = pe[1]
                    end
                else
                    imgui.TextDisabled('Protect (job/level)')
                end
                imgui.SameLine()
                if shell_usable() then
                    local se = { S.shell_enabled }
                    if imgui.Checkbox('Shell##protshell_master', se) then
                        S.shell_enabled = se[1]
                    end
                else
                    imgui.TextDisabled('Shell (job/level)')
                end

                -- Per-member rows: Name  CheckP  CheckS  PTimer  STimer
                local pm = party()
                if pm then
                    for slot = 0, 5 do
                        if n(pm:GetMemberIsActive(slot)) == 1 then
                            local mname = pm:GetMemberName(slot) or ''
                            if mname ~= '' then
                                -- Buff cache is the source of truth (same
                                -- pattern as the Refresh fix). Timer is
                                -- display-only.
                                local p_present, s_present
                                if slot == 0 then
                                    p_present = self_has_buff(BUFF.PROTECT)
                                    s_present = self_has_buff(BUFF.SHELL)
                                else
                                    p_present = party_slot_has_buff(slot, BUFF.PROTECT)
                                    s_present = party_slot_has_buff(slot, BUFF.SHELL)
                                end

                                -- Name column (fixed width keeps the
                                -- checkbox columns aligned).
                                imgui.Text(string.format('%-14s', mname:sub(1, 14)))
                                imgui.SameLine()

                                -- CheckP
                                if protect_usable() then
                                    local pstate = { targets_contains(S.protect_targets, mname) }
                                    if imgui.Checkbox('P##protshell_p' .. slot, pstate) then
                                        targets_toggle(S.protect_targets, mname)
                                    end
                                else
                                    imgui.TextDisabled('P')
                                end
                                imgui.SameLine()

                                -- CheckS
                                if shell_usable() then
                                    local sstate = { targets_contains(S.shell_targets, mname) }
                                    if imgui.Checkbox('S##protshell_s' .. slot, sstate) then
                                        targets_toggle(S.shell_targets, mname)
                                    end
                                else
                                    imgui.TextDisabled('S')
                                end

                                -- Timer labels: same three-state pattern
                                -- as render_party_target_checkboxes
                                --   (timer set + buff)   -> "Xs"
                                --   (buff present, no timer) -> "active"
                                --   (no buff, expired)   -> "due" (green)
                                local function show_timer(prefix, timer_val, present)
                                    imgui.SameLine()
                                    local rem = timer_val and (timer_val - now()) or 0
                                    if timer_val and (present or rem > 0) then
                                        imgui.TextDisabled(string.format('%s%.0fs', prefix, rem))
                                    elseif present then
                                        imgui.TextDisabled(prefix .. 'active')
                                    else
                                        imgui.TextColored({0.4, 1.0, 0.4, 1.0}, prefix .. 'due')
                                    end
                                end
                                if targets_contains(S.protect_targets, mname) then
                                    show_timer(' P:', S.protect_timers[mname], p_present)
                                end
                                if targets_contains(S.shell_targets, mname) then
                                    show_timer(' S:', S.shell_timers[mname], s_present)
                                end
                                -- 3-letter main-job code, right-aligned.
                                -- Same convention as Refresh/Haste/Regen.
                                render_member_job_right(pm, slot)
                            end
                        end
                    end
                end
            end
            imgui.Separator()
        end

        -- Bar Elemental Spells (WHM AoE bar-elements). Shown whenever
        -- the player can cast Barfira (the lowest tier, WHM 5). One
        -- active element at a time -- clicking the active one again
        -- deselects it (active_spell becomes nil and nothing casts).
        -- Target list is SHARED across elements: switching from Barfira
        -- to Barwatera keeps the same checked members.
        --
        -- Per-element availability shown inline: an element the player
        -- can't yet cast (level gate, sub-job restriction) renders
        -- greyed out so the radio still communicates the full set.
        -- spell_usable() does the per-spell level check.
        if barelement_usable() then
            local active = S.barelement_active
            local active_label = (type(active) == 'string' and active ~= '') and active or 'none'
            local rdy = (type(active) == 'string' and active ~= '')
                        and spell_ready_label(active) or '-'
            if imgui.CollapsingHeader(string.format('Bar Elemental Spells  [%s]  Ready: %s###barelement_hdr',
                                                   active_label, rdy),
                                      IMGUI_TREE_DEFAULT_OPEN) then

                -- Radio row: six buttons, one per element. Clicking
                -- selects; clicking the currently-active one deselects.
                -- We use Checkbox-as-radio rather than ImGui's
                -- RadioButton because checkbox toggling is the natural
                -- "click to deselect" shape -- RadioButton groups don't
                -- offer a "click to clear" UX without an extra "None"
                -- button.
                for i = 1, #BARELEMENT_ORDER do
                    local spell = BARELEMENT_ORDER[i]
                    local is_active = (S.barelement_active == spell)
                    if not spell_usable(spell) then
                        -- Level/job locks this element. Render disabled
                        -- so the user sees it exists but can't pick it.
                        if i > 1 then imgui.SameLine() end
                        imgui.TextDisabled(spell)
                    else
                        if i > 1 then imgui.SameLine() end
                        local state = { is_active }
                        if imgui.Checkbox(spell .. '##barelement_pick_' .. spell, state) then
                            if is_active then
                                -- Clicking the active one again -> off.
                                S.barelement_active = nil
                            else
                                -- Pick this one (replaces any other).
                                S.barelement_active = spell
                            end
                            -- Reset the out-of-range echo throttle on
                            -- ANY switch so the next 'wait' tick produces
                            -- an immediate echo for the new element.
                            S.barelement_echo_at = 0.0
                        end
                    end
                end

                -- Tooltip on the active label clarifies the contract.
                if imgui.IsItemHovered() then
                    imgui.SetTooltip('Pick one bar-element to maintain (or click the\n' ..
                        'active one again to turn it off). AoE 10y centered\n' ..
                        'on you; casts when every checked member who lacks\n' ..
                        'the buff is in range, warns in chat otherwise.')
                end

                -- Shared target checkboxes. The buff_id passed in is
                -- the ACTIVE element's id so the per-row due/active
                -- indicator reflects "do they have THIS bar-element."
                -- When nothing is active we pass nil and the indicator
                -- silently shows just the name + job.
                local indicator_buff = nil
                if type(S.barelement_active) == 'string' and S.barelement_active ~= '' then
                    indicator_buff = BARELEMENT_BUFF_ID[S.barelement_active]
                end
                render_party_target_checkboxes(S.barelement_targets,
                                               S.barelement_timers,
                                               'barelement_',
                                               false,           -- self is togglable
                                               indicator_buff)
            end
            imgui.Separator()
        end


        imgui.Separator()
        local dbg = { S.debug }
        if imgui.Checkbox('Debug', dbg) then
            S.debug = dbg[1]
        end

        -- Diagnostic flag: turn off the cast-timeout safety net so
        -- the addon doesn't kill is_casting based on a guessed time
        -- budget. Use when tuning ANIMATION_END_SEC -- casttimes.txt
        -- will then log real completion durations (`took X.XXXs`)
        -- instead of TIMEOUT rows. Off (timeout active) for normal
        -- play; on (timeout suppressed) for data collection.
        local td = { S.timeout_disable }
        if imgui.Checkbox('Disable cast timeout (diagnostic)', td) then
            S.timeout_disable = td[1]
        end
        if S.timeout_disable then
            imgui.SameLine()
            imgui.TextColored({1.0, 0.7, 0.3, 1.0}, '(safety net OFF)')
        end

        end  -- end of Controls CollapsingHeader

        -- Debug panel (mob tracker) — its own collapse, outside Controls,
        -- only rendered when Debug is on.
        if S.debug then
            imgui.Separator()
            if imgui.CollapsingHeader('Debug Panel', IMGUI_TREE_DEFAULT_OPEN) then
                -- Self-state pinned at top of Debug Panel, above the mob
                -- tracker. Reads the live entity-buff list (BUFF.HASTE = 33);
                -- no addon-side timer dependency, so it's accurate even when
                -- haste came from a non-addon source (e.g. Hastega, a manual
                -- Haste cast, or another mage).
                do
                    local hasted = self_has_buff(BUFF.HASTE)
                    local color  = hasted and {0.4, 1.0, 0.4, 1.0} or {1.0, 0.4, 0.4, 1.0}
                    imgui.TextColored(color, string.format('Player Hasted: %s', hasted and 'True' or 'False'))
                end

                -- Cast-timing diagnostics: when "Unable to cast spells at
                -- this time" hits unexpectedly, what we usually want is
                -- the gap between the last /ma and the failing one, plus
                -- which locks were still active. All values are read
                -- once per render against `now()` so the timestamps stay
                -- self-consistent.
                do
                    local tnow = now()
                    if (S.last_cast_sent_at or 0) > 0 then
                        local ago = tnow - S.last_cast_sent_at
                        imgui.TextDisabled(string.format(
                            'Last cast: %s -> %s  (%.2fs ago)',
                            tostring(S.last_cast_sent_spell or ''),
                            tostring(S.last_cast_sent_target or ''),
                            ago))
                    else
                        imgui.TextDisabled('Last cast: (none this session)')
                    end

                    -- Previous cast (the one before the most recent).
                    -- The gap between them is the diagnostic value for
                    -- "did we fire back-to-back too fast" failures.
                    if (S.prev_cast_sent_at or 0) > 0 then
                        local prev_ago = tnow - S.prev_cast_sent_at
                        local gap      = prev_ago - (tnow - (S.last_cast_sent_at or tnow))
                        imgui.TextDisabled(string.format(
                            'Prev cast: %s -> %s  (%.2fs ago, gap %.2fs)',
                            tostring(S.prev_cast_sent_spell or ''),
                            tostring(S.prev_cast_sent_target or ''),
                            prev_ago, gap))
                    else
                        imgui.TextDisabled('Prev cast: (none)')
                    end

                    -- spell_lock_until: blocks cast_on_target via
                    -- spell_locked(). Positive => still locked.
                    local lock_rem = (S.spell_lock_until or 0) - tnow
                    if lock_rem > 0 then
                        imgui.TextColored({1.0, 0.8, 0.4, 1.0},
                            string.format('  spell_lock: %.2fs left', lock_rem))
                    else
                        imgui.TextDisabled('  spell_lock: clear')
                    end

                    -- last_stand_at + STAND_SETTLE_SEC: blocks
                    -- cast_on_target while we're still in the /heal
                    -- stand-up animation window.
                    local stand_rem = (S.last_stand_at or 0) + STAND_SETTLE_SEC - tnow
                    if stand_rem > 0 then
                        imgui.TextColored({1.0, 0.8, 0.4, 1.0},
                            string.format('  stand_settle: %.2fs left', stand_rem))
                    else
                        imgui.TextDisabled('  stand_settle: clear')
                    end

                    -- is_casting: set by mark_spell_sent, cleared on
                    -- cast-complete / cast-fail / cast-timeout. A stuck
                    -- "true" here is usually how a hung lock manifests.
                    if S.is_casting then
                        local timeout_rem = (S.cast_timeout_at or 0) - tnow
                        imgui.TextColored({1.0, 0.8, 0.4, 1.0},
                            string.format('  is_casting: TRUE  (timeout in %.2fs)', timeout_rem))
                    else
                        imgui.TextDisabled('  is_casting: false')
                    end
                end

                -- Reset Fail Log button: truncates failwhy.txt to zero
                -- bytes. Useful when starting a new debug session so
                -- the file only contains failures from this run rather
                -- than history. Path is recomputed inline so we don't
                -- have to forward-declare FAILWHY_PATH for the GUI
                -- closure's upvalue capture.
                if imgui.Button('Reset Fail Log') then
                    local path = addon.path .. 'failwhy.txt'
                    local fh = io.open(path, 'w')
                    if fh then
                        fh:close()
                        cprint('Fail log cleared')
                    else
                        cwarn('Could not clear fail log: ' .. path)
                    end
                end
                imgui.SameLine()
                if imgui.Button('Reset Cast Log') then
                    local path = addon.path .. 'casttimes.txt'
                    local fh = io.open(path, 'w')
                    if fh then
                        fh:close()
                        cprint('Cast log cleared')
                    else
                        cwarn('Could not clear cast log: ' .. path)
                    end
                end
                imgui.SameLine()
                imgui.TextDisabled('(written only while Debug is on)')

                imgui.Separator()

                -- Pinned mob tracker at top
                if S.debuff_mob_sid ~= 0 then
                    -- D / P / S indicators read mob_debuffs directly via
                    -- mob_has_debuff (the same source as the "Debuffs:"
                    -- line below). Previously these read S.debuffs_done
                    -- which only flips true inside Mob.get_next_debuff
                    -- and only when the debuff cascade actually runs --
                    -- so if S.debuff_enabled is off, or the cascade
                    -- exits early, the header showed D- even when the
                    -- packet tracker had Dia recorded. Reading the
                    -- tracker keeps the two lines consistent.
                    imgui.TextColored({1.0, 0.8, 0.4, 1.0}, imsafe(string.format(
                        'Mob sid%d  HP%d%%  %.1fy  D%s P%s S%s B%s',
                        S.debuff_mob_sid,
                        S.debug_mob_hp,
                        S.debug_mob_dist,
                        mob_has_debuff(S.debuff_mob_sid, 134) and '+' or '-',
                        mob_has_debuff(S.debuff_mob_sid, 4)   and '+' or '-',
                        mob_has_debuff(S.debuff_mob_sid, 13)  and '+' or '-',
                        mob_has_debuff(S.debuff_mob_sid, 5)   and '+' or '-'
                    )))
                    -- Live list of ALL debuffs tracked on this mob (from action
                    -- packets), regardless of who applied them. Shows remaining
                    -- time so you can see what's ticking.
                    local entry = mob_debuffs[S.debuff_mob_sid]
                    if entry then
                        local tnow  = os.time()
                        local parts = {}
                        for bid, expiry in pairs(entry) do
                            if expiry > tnow then
                                local name = DEBUFF_NAMES[bid] or ('id:' .. tostring(bid))
                                parts[#parts+1] = string.format('%s %ds', name, expiry - tnow)
                            end
                        end
                        if #parts > 0 then
                            imgui.TextDisabled(imsafe('  Debuffs: ' .. table.concat(parts, ', ')))
                        else
                            imgui.TextDisabled('  Debuffs: (none tracked)')
                        end
                    else
                        imgui.TextDisabled('  Debuffs: (none tracked)')
                    end
                else
                    imgui.TextDisabled('Mob: none tracked')
                end

                -- Full dump of all_claimed_targets so phantom entries
                -- are visible without guessing. One line per row:
                -- sid, name, HP%, distance, claim status, and how long
                -- ago the row was first added. The picker decision
                -- becomes verifiable: oldest added_at wins, but if a
                -- phantom has the oldest timestamp it'll show up here
                -- and you can see why.
                local tnow_dbg = now()
                local rows = {}
                for idx, added_at in pairs(S.all_claimed_targets) do
                    rows[#rows+1] = { idx = idx, added_at = tonumber(added_at) or 0 }
                end
                table.sort(rows, function(a, b) return a.added_at < b.added_at end)
                if #rows > 0 then
                    imgui.TextDisabled(string.format('  Claimed (%d):', #rows))
                    for _, r in ipairs(rows) do
                        local ok, ent = pcall(GetEntity, r.idx)
                        if ok and ent then
                            local esid  = n(ent.ServerId or ent.ServerID or ent.Id or ent.ID or 0)
                            local ehp   = n(ent.HPPercent or 0)
                            local edist = entity_distance(ent) or 0
                            local ename = ent.Name or '?'
                            local eclaim = tonumber(ent.ClaimStatus or ent.ClaimId
                                                 or ent.claim_status or ent.claim_id or 0) or 0
                            local age = tnow_dbg - r.added_at
                            local marker = (esid == S.debuff_mob_sid) and ' <- LOCKED' or ''
                            imgui.TextDisabled(imsafe(string.format(
                                '    sid%d %s HP%d%% %.1fy claim=%d age=%.0fs%s',
                                esid, ename, ehp, edist, eclaim, age, marker)))
                        else
                            imgui.TextDisabled(imsafe(string.format(
                                '    idx%d (no entity)', r.idx)))
                        end
                    end
                end
            end

            -- Log — its own collapse, only shown when there are entries.
            if #S.log > 0 and imgui.CollapsingHeader('Log', IMGUI_TREE_DEFAULT_OPEN) then
                imgui.BeginChild('bm_log', {0, 110}, true)
                for i = #S.log, math.max(1, #S.log - 14), -1 do
                    imgui.TextDisabled(imsafe(S.log[i]))
                end
                imgui.EndChild()
            end
        end

        end  -- end of Status CollapsingHeader
    end
    imgui.End()
    imgui.PopStyleColor(11)
    imgui.PopStyleVar(7)
end

ashita.events.register('d3d_present', 'bm_present', function()
    local ok, err = pcall(_bm_present_body)
    if not ok then
        _bvm_dbg('present', err)
        -- Best-effort imgui cleanup so a caught error doesn't leave the
        -- shared context with a dangling Begin / pushed styles (which is
        -- what hides every other addon's windows). Each is pcall'd: if
        -- the error fired before Begin, the extra End is a no-op error
        -- we swallow.
        pcall(imgui.End)
        pcall(imgui.PopStyleColor, 11)
        pcall(imgui.PopStyleVar, 7)
    end
end)

---------------------------------------------------------------------
-- TICK DRIVER
---------------------------------------------------------------------

ashita.events.register('d3d_present', 'bm_tick', function()
    local t = now()
    if (t - S.last_tick) < S.tick_interval then return end
    S.last_tick = t
    local ok, err = pcall(tick)
    if not ok then
        cwarn('TICK ERROR: ' .. tostring(err))
    end
end)

---------------------------------------------------------------------
-- TEXT IN
---------------------------------------------------------------------

---------------------------------------------------------------------
-- FAIL DIAGNOSTICS
--
-- When a cast fails unexpectedly (Unable to cast / Not enough MP /
-- interrupted / addon-side timeout), dump enough state to figure out
-- *why* into addon.path/failwhy.txt. Appends, no rotation -- delete
-- the file manually when you don't need the history. Captures:
--   - wall-clock + os.clock() so deltas can be compared across runs
--   - the spell + target of the most recent /ma we sent
--   - time since that /ma and since the last stand-up /heal
--   - MP, HP, player status code, resting/dead/silenced flags
--   - all three cast-blocking locks (spell_lock, stand_settle, is_casting)
--   - cooldown remaining on the spell that just got sent
--   - distance to the target (if it's a party member)
-- Called BEFORE spell_clear() in each fail path so last_spell_sent and
-- last_spell_target_name are still meaningful.
---------------------------------------------------------------------

local FAILWHY_PATH  = addon.path .. 'failwhy.txt'
local CASTTIMES_PATH = addon.path .. 'casttimes.txt'

-- Cast-time logger (Debug-gated). On every /ma we send, mark_spell_sent
-- calls log_cast_pending; on every cast-complete event, the text_in
-- handler calls log_cast_confirmed. One row per cast attempt:
--   confirmed:        spell -> target | took X.XXXs | hasted=true/false
--   never confirmed:  spell -> target | NEVER CONFIRMED after X.XXXs | hasted=...
-- The "never confirmed" row prints when a new mark_spell_sent comes in
-- (or any fail clears the pending slot) WITHOUT having seen the
-- matching completion. That tells us whether:
--   (a) our cast_timeout is firing because casts genuinely take longer
--       than the timeout window (we'll see confirmed entries with long
--       elapsed times, fix is to widen the timeout), or
--   (b) parse_player_casts_name is missing completion events
--       (we'll see NEVER CONFIRMED entries even when the game showed
--       the cast landing, fix is to widen the parser).
function CastLog.flush(reason_if_unconfirmed)
    if not S.debug then return end
    if not S.pending_cast_spell or S.pending_cast_spell == '' then return end
    local elapsed = now() - (S.pending_cast_at or now())
    local f = io.open(CASTTIMES_PATH, 'a')
    if f then
        f:write(string.format('[%s] %s -> %s | %s after %.3fs | hasted=%s\n',
            os.date('%H:%M:%S'),
            S.pending_cast_spell,
            S.pending_cast_target ~= '' and S.pending_cast_target or '?',
            reason_if_unconfirmed or 'NEVER CONFIRMED',
            elapsed,
            tostring(S.pending_cast_hasted)))
        f:close()
    end
    S.pending_cast_spell  = ''
    S.pending_cast_target = ''
    S.pending_cast_at     = 0.0
end

function CastLog.pending(spell, target)
    if not S.debug then return end
    -- If we never saw the completion for the previous cast, flush it
    -- as NEVER CONFIRMED before starting a new one. Only one cast is
    -- tracked at a time, matching the addon's single-cast-in-flight
    -- invariant.
    CastLog.flush('NEVER CONFIRMED')
    S.pending_cast_spell  = tostring(spell or '')
    S.pending_cast_target = type(target) == 'string' and target or ''
    S.pending_cast_at     = now()
    S.pending_cast_hasted = self_has_buff(BUFF.HASTE)
end

function CastLog.confirmed(spell_normalized, method)
    if not S.debug then return end
    if not S.pending_cast_spell or S.pending_cast_spell == '' then return end
    -- Match by normalized name -- mark_spell_sent stored the raw
    -- "Haste" but the parser delivers "haste".
    local pending_norm = normalize_action_name(S.pending_cast_spell)
    if pending_norm ~= spell_normalized then return end

    local elapsed = now() - (S.pending_cast_at or now())
    local f = io.open(CASTTIMES_PATH, 'a')
    if f then
        -- `via=` annotation surfaces which completion path fired:
        --   'log' = chat-line "casts X" / "gains the effect of X"
        --   'buff' = self_has_buff polling caught a buff transition
        -- Buff-path rows need a slightly longer post-cast settle
        -- (POST_CAST_SETTLE_BUFF) because the buff icon precedes
        -- the spell-slot release; an unable-to-cast row immediately
        -- after a `via=buff` row means POST_CAST_SETTLE_BUFF is too
        -- short and needs bumping.
        f:write(string.format('[%s] %s -> %s | took %.3fs | hasted=%s | via=%s\n',
            os.date('%H:%M:%S'),
            S.pending_cast_spell,
            S.pending_cast_target ~= '' and S.pending_cast_target or '?',
            elapsed,
            tostring(S.pending_cast_hasted),
            tostring(method or 'log')))
        f:close()
    end
    S.pending_cast_spell  = ''
    S.pending_cast_target = ''
    S.pending_cast_at     = 0.0
end

-- Forward-declared at the top of CONSTANTS; body assigned here.
-- Called every tick (and stopped-tick) BEFORE the cast_timeout
-- check, so a buff appearance can clear the cast lock without
-- waiting for either the timeout budget or a chat-line completion
-- (neither of which is reliable for self-cast self-target buffs
-- on HorizonXI -- particularly Reraise, whose completion emits
-- no chat line at all).
--
-- Guard conditions (all required to fire):
--   1. is_casting is true (a cast is actively in flight)
--   2. last_spell_sent matches a SELF_BUFF_MAP entry
--   3. last_spell_target_name is the local player (self-cast)
--   4. Enough time has elapsed since send that the buff CAN'T be
--      a stale leftover from a prior cast (>= FC.cast_time so the
--      cast bar would have finished server-side)
--   5. self_has_buff(target_buff_id) is now true
--
-- On a hit: log, set Refresh/Haste/Regen timers when applicable
-- (mirrors the text-parser completion path so timer behavior is
-- identical regardless of which signal fired), CastLog.confirmed
-- (so the diagnostic casttimes.txt row reads `took X.XXXs`), and
-- spell_clear (drops is_casting, last_spell_sent, etc.).
-- Unified completion logic, called by all THREE signals that mean
-- "the cast that was in flight is done":
--   method='buff'    - try_buff_completion saw self_has_buff flip true
--   method='log'     - parse_player_casts_name matched a chat line
--   method='timeout' - cast_time + ANIMATION_END_SEC + 1.0 elapsed
--                      with no other signal; assume the cast landed
--                      but the addon missed both buff and log events
--                      (rather than treating timeout as a failure,
--                      which would lock the bot in a recast loop)
--
-- Sets buff timers for Refresh / Haste / Regen, the post-cast lock
-- (POST_CAST_SETTLE_BUFF for buff/timeout because animation may not
-- have completed; POST_CAST_SETTLE for log because the chat line is
-- itself gated on animation completion), refreshes the stand-lock
-- so we don't immediately /heal, logs the casttimes.txt row with a
-- via=<method> annotation, and clears the in-flight state.
local function complete_cast_body(method)
    local spell     = S.last_spell_sent
    if not spell or spell == '' then return end
    local target    = S.last_spell_target_name or ''
    local spell_raw = S.last_spell_sent_raw or ''

    -- TIMEOUT VALIDATION via party-buff cache.
    -- The 'timeout' method is a fallback assumption: no confirm
    -- arrived inside cast_time + ANIMATION_END_SEC + 1.0, so we
    -- USED to just declare success and write the full recast CD.
    -- That bit us hard for buff spells -- a missed interrupt or
    -- a silently-failed cast would lock e.g. Haste on Thelord for
    -- the full base recast (18s) even though the buff never landed
    -- and Thelord was running around buffless.
    --
    -- For spells in SPELL_VERIFICATION_BUFF we can check the real
    -- ground truth: the party buff cache. If by the timeout point
    -- (~bar_fill_time + 5-6s) the target STILL doesn't have the
    -- expected buff, the cast definitely didn't land -- re-route
    -- to fail_cast_retry (1.0s short CD, same as a genuine
    -- interrupt) so the cascade picks the spell back up next tick.
    --
    -- Self vs party-member dispatch: if the target name matches
    -- the player's own name (or is empty -- self-cast helpers
    -- sometimes omit the name), check via self_has_buff;
    -- otherwise via party_name_has_buff.
    if method == 'timeout' and spell_raw ~= '' then
        local verify_buff_id = SPELL_VERIFICATION_BUFF[spell_raw]
        if verify_buff_id then
            local pname = P.player_name() or ''
            local has_buff
            if target == '' or target == pname or target == '<me>' then
                has_buff = self_has_buff(verify_buff_id)
            else
                has_buff = party_name_has_buff(target, verify_buff_id)
            end
            if not has_buff then
                log(string.format(
                    'TIMEOUT FAIL: %s on %s -- buff %d NOT present -- treating as fail (1.0s retry)',
                    spell_raw, target ~= '' and target or '(self)', verify_buff_id))
                -- Hand off to the existing failure path so all the
                -- cleanup (consecutive_unable tracking, spell_clear,
                -- CastLog.fail, 1.0s CD) goes through the same
                -- well-tested codepath instead of duplicating it.
                fail_cast_retry('timeout: buff not present', '')
                return
            end
        end
    end

    CastLog.confirmed(spell, method)
    log(string.format('Cast completed (%s): %s', method, spell))

    -- Successful confirmation -> reset the consecutive-UTC
    -- counter for this spell so a future legitimate UTC reject
    -- doesn't tip past the lockout threshold on cycle 1. Counter
    -- is keyed by raw spell name (same as cooldowns).
    if spell_raw ~= '' then
        S.consecutive_unable[spell_raw] = 0
    end
    -- Also clear the global UTC window and any active pause -- a
    -- successful cast proves the server is willing to accept casts
    -- again, no need to keep the throttle armed.
    S.global_utc_at          = {}
    S.global_cast_pause_until = 0.0

    -- Overwrite the safety-brake cooldown that mark_spell_sent set
    -- at /ma send time. FFXI's recast counter starts when the cast
    -- bar fills (which is ~now() for action/buff signals; slightly
    -- earlier for log/timeout but those still land after bar fill),
    -- NOT when /ma was sent. The send-time brake undercounts the
    -- real recast by cast_time -- for Refresh that's a ~4s window
    -- where the addon thinks the spell is ready but the server
    -- still has the recast active, producing UTC on the first
    -- eligible re-cast. Setting cooldown to now + FC.recast_time
    -- aligns the addon's gate with the server's recast within
    -- FC.recast_time's +0.5s safety margin.
    if spell_raw ~= '' then
        S.cooldowns[spell_raw] = now() + FC.recast_time(spell_raw)
    end

    -- 'log' and 'action' both indicate server-side completion: the
    -- chat line is gated on the animation finishing, and the action
    -- packet IS the server's "spell finished, slot released" event.
    -- Baseline POST_CAST_SETTLE cushion is enough for both. 'buff'
    -- and 'timeout' fire DURING or near the end of the animation, so
    -- POST_CAST_SETTLE_BUFF (= POST_CAST_SETTLE + 0.5s) is required
    -- to avoid the next /ma being rejected with "Unable to cast
    -- spells at this time".
    local settle = (method == 'log' or method == 'action')
        and POST_CAST_SETTLE or POST_CAST_SETTLE_BUFF
    local new_lock = now() + settle
    -- 'action' caveat: empirically the action packet fires 3-5s
    -- BEFORE the chat-line on HorizonXI -- it arrives during the
    -- post-bar finish phase, while the server's spell slot is still
    -- locked. Sending /ma in that window returns "Unable to cast
    -- spells at this time" (observed at 1-2s gaps after via=action).
    -- Don't shorten the lock that mark_spell_sent already set
    -- (cast_time + ANIMATION_END_SEC = bar-fill + 5.0s) -- it was
    -- calibrated for exactly this finish-phase window. Take the
    -- later of the two locks. This keeps the UX win (is_casting
    -- clears early, the "Casting..." status drops near bar-fill)
    -- without burning UTCs back into the global throttle.
    if method == 'action' then
        new_lock = math.max(new_lock, S.spell_lock_until or 0)
    end
    S.spell_lock_until  = new_lock
    S.manual_cast_until = 0.0

    -- Refresh/Haste/Regen are the only spells with addon-side
    -- duration timers; the rest (Reraise/Stoneskin/Blink/etc.)
    -- re-cast based on buff absence, not duration. Timer keyed by
    -- the target the cast was sent to, matching the text-parser
    -- path's bookkeeping.
    if target ~= '' then
        if spell == 'refresh' then
            local dur = SPELL_BUFF_DURATION['Refresh'] - (SPELL_OVERLAP['Refresh'] or 0)
            S.refresh_timers[target] = now() + dur
            log(string.format('Refresh timer SET: %s -> %.0fs', target, dur))
        elseif spell == 'haste' then
            local dur = SPELL_BUFF_DURATION['Haste'] - (SPELL_OVERLAP['Haste'] or 0)
            S.haste_timers[target] = now() + dur
            log(string.format('Haste timer SET: %s -> %.0fs', target, dur))
        elseif spell == 'regen' then
            local dur = SPELL_BUFF_DURATION['Regen'] - (SPELL_OVERLAP['Regen'] or 0)
            S.regen_timers[target] = now() + dur
            log(string.format('Regen timer SET: %s -> %.0fs', target, dur))
        elseif spell == 'protect' or spell == 'protect ii'
            or spell == 'protect iii' or spell == 'protect iv' then
            local dur = SPELL_BUFF_DURATION['Protect'] - (SPELL_OVERLAP['Protect'] or 0)
            S.protect_timers[target] = now() + dur
            log(string.format('Protect timer SET: %s -> %.0fs', target, dur))
        elseif spell == 'shell' or spell == 'shell ii'
            or spell == 'shell iii' or spell == 'shell iv' then
            local dur = SPELL_BUFF_DURATION['Shell'] - (SPELL_OVERLAP['Shell'] or 0)
            S.shell_timers[target] = now() + dur
            log(string.format('Shell timer SET: %s -> %.0fs', target, dur))
        end
    end

    refresh_stand_lock('cast-complete-' .. method .. ':' .. spell)
    spell_clear()
end

-- Failure-retry path. Three behaviors depending on the failure type:
--
--   1. "Unable to cast spells at this time" -- the server rejected
--      the /ma outright. The cast did NOT start. Common causes: the
--      target buff is already active and our buff-detection didn't
--      see it; the spell slot is still server-side-busy from an
--      earlier cast we mis-confirmed; or we're caught in a recast
--      lockout. PRESERVE the cooldown that mark_spell_sent set
--      (i.e., the full FFXI recast time) so the bot doesn't
--      immediately retry. ALSO increment the per-spell consecutive
--      UTC counter; once it crosses UNABLE_TO_CAST_LOCKOUT_THRESHOLD
--      push the cooldown out by UNABLE_TO_CAST_LOCKOUT_SEC so the
--      bot stops machine-gunning /ma -- this is the ban-risk guard.
--
--   2. Genuine in-flight interrupts -- "Your casting is interrupted"
--      (movement, stun, sleep, smacked by a mob), silent fails (out
--      of range / no effect / cannot see / line of sight). The cast
--      started but didn't land. Shorten the cooldown to now()+1.0
--      so the cascade can retry as soon as the blocking condition
--      clears. UTC counter NOT incremented (this is a legit retry
--      scenario, not server pushback).
--
--   3. "Not enough MP" -- predictable, MP will recover. Preserve
--      the cooldown so the cascade re-evaluates naturally. UTC
--      counter NOT incremented.
--
-- In all three cases: drop is_casting / last_spell_sent_raw via
-- spell_clear(), do NOT set buff timers, do NOT credit the cast.
local function fail_cast_retry_body(reason, raw_line)
    local spell_raw = S.last_spell_sent_raw
    local is_unable = reason:find('Unable to cast spells at this time', 1, true) ~= nil
    local is_mp     = reason:find('Not enough MP', 1, true) ~= nil

    if spell_raw and spell_raw ~= '' then
        if is_unable then
            -- Global UTC throttle: record this UTC timestamp,
            -- prune old entries, check threshold. If crossed,
            -- halt all casting for GLOBAL_UTC_BACKOFF_SEC. This
            -- catches the cascade-spam pattern where many
            -- DIFFERENT spells UTC in quick succession.
            local tnow = now()
            local cutoff = tnow - GLOBAL_UTC_WINDOW_SEC
            local kept = {}
            for i = 1, #S.global_utc_at do
                if S.global_utc_at[i] >= cutoff then
                    kept[#kept + 1] = S.global_utc_at[i]
                end
            end
            kept[#kept + 1] = tnow
            S.global_utc_at = kept
            if #kept >= GLOBAL_UTC_THRESHOLD then
                S.global_cast_pause_until = tnow + GLOBAL_UTC_BACKOFF_SEC
                S.global_utc_at = {}
                log(string.format(
                    'GLOBAL THROTTLE: %d UTC fails in %.0fs -- ' ..
                    'halting ALL casting for %.0fs',
                    #kept, GLOBAL_UTC_WINDOW_SEC, GLOBAL_UTC_BACKOFF_SEC))
            end

            -- Anti-spam: track consecutive UTC rejects.
            S.consecutive_unable[spell_raw] =
                (S.consecutive_unable[spell_raw] or 0) + 1
            local count = S.consecutive_unable[spell_raw]
            if count >= UNABLE_TO_CAST_LOCKOUT_THRESHOLD then
                -- Server has refused this spell at least N times in
                -- a row. Push the cooldown WAY out so the cascade
                -- stops trying. Reset to 0 doesn't happen here --
                -- only complete_cast() resets the counter.
                S.cooldowns[spell_raw] =
                    math.max(S.cooldowns[spell_raw] or 0,
                             now() + UNABLE_TO_CAST_LOCKOUT_SEC)
                -- Spam guard trip IS chat-visible -- the user
                -- needs to know we just stopped a spell from being
                -- re-attempted for a minute. Rare event by design.
                log(string.format(
                    'SPAM GUARD: %s rejected %d times in a row -- ' ..
                    'locking out for %.0fs',
                    spell_raw, count, UNABLE_TO_CAST_LOCKOUT_SEC))
            else
                -- Routine UTC reject under threshold. Goes to the
                -- in-memory diag log ONLY -- not to chat -- because
                -- the cascade tries many (spell, target) pairs and
                -- a single bad-buff-detection state can produce a
                -- chat-spam flood. failwhy.txt and casttimes.txt
                -- already capture the details for offline review.
                log_diag(string.format(
                    'Cast failed (%s) [%d/%d] - preserving recast: %s',
                    reason, count, UNABLE_TO_CAST_LOCKOUT_THRESHOLD,
                    spell_raw))
            end
        elseif is_mp then
            -- MP gate. Diag-only -- happens every time we're
            -- under-MP at cast time, can fire many times in a row
            -- while resting.
            log_diag(string.format('Cast failed (%s) - waiting on MP: %s',
                reason, spell_raw))
        else
            -- Genuine interrupt path. Shorten to retry quickly.
            -- Diag-only: interrupts during movement / smacked
            -- can fire many times in a chain, no need to spam chat.
            S.cooldowns[spell_raw] = now() + 1.0
            log_diag(string.format('Cast failed (%s) - retry allowed in 1.0s: %s',
                reason, spell_raw))
        end
    else
        log_diag(string.format('Cast failed (%s) - no spell tracked to retry', reason))
    end

    CastLog.flush('failed:' .. reason)
    CastLog.fail(reason, raw_line or '')
    S.manual_cast_until = 0.0
    spell_clear()
end

-- Wire the forward-declared (top-of-file) locals to their bodies
-- defined just above. Doing it this way lets the cast-timeout
-- check inside tick() reach these helpers even though tick() is
-- lexically upstream of where they're defined.
complete_cast    = complete_cast_body
fail_cast_retry  = fail_cast_retry_body

-- Buff-detection completion path: forward-declared at the top of
-- CONSTANTS; body assigned here. See SELF_BUFF_MAP / the original
-- forward-decl comment for the full rationale. This is the PRIMARY
-- completion signal for self-cast self-target buffs (chat lines
-- are unreliable for these on HorizonXI; Reraise emits no line at
-- all). complete_cast('buff') does the actual completion work.
try_buff_completion = function()
    if not S.is_casting then return end
    local spell = S.last_spell_sent
    if not spell or spell == '' then return end
    local buff_id = SELF_BUFF_MAP[spell]
    if not buff_id then return end
    local target = S.last_spell_target_name or ''
    local pname  = P.player_name() or ''
    if pname == '' or target ~= pname then return end
    -- Cast-bar floor: don't credit completion before the cast
    -- could physically have finished. FC.cast_time is the
    -- FC-adjusted bar duration; a buff appearing earlier than
    -- that must be from a prior cast we mis-attributed.
    local elapsed = now() - (S.last_cast_sent_at or 0)
    if elapsed < FC.cast_time(spell) then return end
    if not self_has_buff(buff_id) then return end

    complete_cast('buff')
end

local function fail_target_distance(target_name)
    if not target_name or target_name == '' then return nil end
    local pm = party()
    if not pm then return nil end
    for slot = 0, 5 do
        if n(pm:GetMemberIsActive(slot)) == 1 then
            local mname = pm:GetMemberName(slot) or ''
            if mname == target_name then
                if slot == 0 then return 0.0 end
                return get_member_distance(slot)
            end
        end
    end
    return nil
end

function CastLog.fail(reason, raw_line)
    -- Gated on the in-app Debug toggle so a normal-running session
    -- doesn't accumulate a fail log on disk. Flip Debug on when you
    -- want to capture failures, off when you don't.
    if not S.debug then return end

    local f = io.open(FAILWHY_PATH, 'a')
    if not f then return end

    local tnow            = now()
    local p               = get_player_entity()
    local status_code     = p and n(p.Status or p.status or p.CurrentStatus) or -1

    -- Failing cast: the one most recently sent (could be 0.05s old).
    local fail_spell  = S.last_cast_sent_spell  or ''
    local fail_target = S.last_cast_sent_target or ''
    local fail_ago    = ((S.last_cast_sent_at or 0) > 0) and (tnow - S.last_cast_sent_at) or nil

    -- Previous cast: the one BEFORE the failing one. The gap between
    -- previous and failing is the diagnostic number for "did we fire
    -- another /ma too soon after the last successful one?".
    local prev_spell  = S.prev_cast_sent_spell  or ''
    local prev_target = S.prev_cast_sent_target or ''
    local prev_ago    = ((S.prev_cast_sent_at or 0) > 0) and (tnow - S.prev_cast_sent_at) or nil
    local gap         = (prev_ago and fail_ago) and (prev_ago - fail_ago) or nil

    local last_stand_ago   = ((S.last_stand_at or 0) > 0) and (tnow - S.last_stand_at) or nil
    local spell_lock_rem   = (S.spell_lock_until or 0) - tnow
    local stand_settle_rem = (S.last_stand_at or 0) + STAND_SETTLE_SEC - tnow
    local cast_timeout_rem = (S.cast_timeout_at or 0) - tnow

    local target_dist = (fail_target ~= '') and fail_target_distance(fail_target) or nil

    local cd_rem
    if fail_spell ~= '' and S.cooldowns[fail_spell] then
        cd_rem = S.cooldowns[fail_spell] - tnow
    end

    local hp_pct = 0
    do
        local pm = party()
        if pm then
            local ok, v = pcall(function() return pm:GetMemberHPPercent(0) end)
            if ok and v then hp_pct = tonumber(v) or 0 end
        end
    end

    f:write(string.format('=== %s (clock=%.3f) ===\n',
        os.date('%Y-%m-%d %H:%M:%S'), tnow))
    f:write(string.format('Reason: %s\n', tostring(reason)))
    f:write(string.format('Raw: <%s>\n', tostring(raw_line or '')))
    f:write(string.format('Failing cast: %s -> %s\n',
        fail_spell ~= ''  and fail_spell  or '(none)',
        fail_target ~= '' and fail_target or '(none)'))
    f:write(string.format('  sent: %s\n',
        fail_ago and string.format('%.3fs ago', fail_ago) or '(never)'))
    f:write(string.format('Previous cast: %s -> %s\n',
        prev_spell ~= ''  and prev_spell  or '(none)',
        prev_target ~= '' and prev_target or '(none)'))
    f:write(string.format('  sent: %s\n',
        prev_ago and string.format('%.3fs ago', prev_ago) or '(none this session)'))
    f:write(string.format('  gap (prev -> failing): %s\n',
        gap and string.format('%.3fs', gap) or '(n/a)'))
    f:write(string.format('Last spell_sent (post-mark): %s -> %s\n',
        tostring(S.last_spell_sent or '(cleared)'),
        tostring(S.last_spell_target_name or '(cleared)')))
    f:write(string.format('Last stand: %s\n',
        last_stand_ago and string.format('%.3fs ago (settle window %.1fs)', last_stand_ago, STAND_SETTLE_SEC) or '(no /heal-up this session)'))
    f:write(string.format('MP: %d (%d%%)   HP%%: %d\n',
        P.player_mp(), P.player_mp_pct(), hp_pct))
    f:write(string.format('Status: code=%d  resting=%s  dead=%s  silenced=%s\n',
        status_code,
        tostring(status_code == 33),
        tostring(status_code == 2),
        tostring(self_is_silenced())))
    f:write(string.format('Locks: spell_lock=%s, stand_settle=%s, is_casting=%s, cast_timeout_in=%.2fs\n',
        spell_lock_rem > 0 and string.format('%.3fs left', spell_lock_rem) or 'clear',
        stand_settle_rem > 0 and string.format('%.3fs left', stand_settle_rem) or 'clear',
        tostring(S.is_casting),
        cast_timeout_rem))
    if cd_rem and cd_rem > 0 then
        f:write(string.format('Cooldown[%s]: %.3fs left\n', fail_spell, cd_rem))
    else
        f:write(string.format('Cooldown[%s]: clear\n', fail_spell ~= '' and fail_spell or '?'))
    end
    if target_dist ~= nil then
        f:write(string.format('Target distance: %s -> %.2fy\n', fail_target, target_dist))
    elseif fail_target ~= '' then
        f:write(string.format('Target distance: %s (not resolvable as party member)\n', fail_target))
    end

    -- Active claimed-mob context. For mob-debuff fails the most
    -- important question is "what did the bot believe about the
    -- mob it was casting on" -- this dumps the live entity HP and
    -- distance plus the freshness of the all_claimed_targets row.
    -- A stale row (last update many seconds ago) with no-longer-
    -- matching live HP/dist means the gate let through a phantom.
    do
        local sid = S.debuff_mob_sid or 0
        if sid ~= 0 then
            -- Rows are now bare `= 1` flags (HXUI-mirror). Look up the
            -- mob by scanning entities for matching sid -- the entity
            -- table is the source of truth, not a stored server_id on
            -- the row. Drops the old updated_at / last_hp fields from
            -- the diagnostic line since neither exists anymore.
            local found_idx
            for k, _ in pairs(S.all_claimed_targets) do
                local oke, ent = pcall(GetEntity, k)
                if oke and ent then
                    local esid = n(ent.ServerId or ent.ServerID or ent.Id or ent.ID or 0)
                    if esid == sid then found_idx = k; break end
                end
            end
            if found_idx then
                local ok, ent = pcall(GetEntity, found_idx)
                local live_hp   = (ok and ent) and n(ent.HPPercent or 0) or -1
                local live_sid  = (ok and ent) and n(ent.ServerId or ent.ServerID or ent.Id or ent.ID or 0) or 0
                local live_dist = (ok and ent) and (entity_distance(ent) or -1) or -1
                f:write(string.format(
                    'Active debuff mob: sid=%d  live_sid=%d  HP=%d%%  dist=%.2fy\n',
                    sid, live_sid, live_hp, live_dist))
            else
                f:write(string.format('Active debuff mob: sid=%d (no row in all_claimed_targets)\n', sid))
            end
        else
            f:write('Active debuff mob: none locked\n')
        end
    end

    f:write('\n')
    f:close()
end

local function _bm_text_in_body(e)
    local raw = e.message or e.text or e.modified or e.original or ''
    if raw == '' then return end

    local clean_text = sanitize_log_text(raw)

    -- Always check for failure lines regardless of cast state.
    -- All call fail_cast_retry: cast did NOT complete, the
    -- spell's cooldown is reset to now()+1.0 so the cascade picks
    -- it up again on the next eligible tick (once stun/silence/etc.
    -- clears). The 1.0s floor prevents /ma machine-gunning when
    -- the underlying condition (e.g. being slept by a mob) lingers.

    -- "You cannot use that command while healing." -- an addon bug
    -- (we sent a command during rest). cprint UNGATED so it shows
    -- regardless of debug, naming the most recent send() command
    -- so the missing player_is_resting() gate is identifiable.
    -- Goes BEFORE the interrupt check because this rejection
    -- never coexists with a real cast in flight (the server
    -- refused to start one) -- treating it as fail_cast_retry
    -- still cleans up if cast_on_target already set is_casting.
    if is_cannot_use_command_while_healing(clean_text) then
        local lc  = S.last_send_cmd or '(no recent send tracked)'
        local age = (S.last_send_at and S.last_send_at > 0) and (now() - S.last_send_at) or -1
        if age >= 0 and age < 5.0 then
            cprint(string.format(
                'WHILE-HEALING REJECT: server refused -- last send %.2fs ago was: %s',
                age, lc))
        else
            cprint(string.format(
                'WHILE-HEALING REJECT: server refused -- last tracked send: %s',
                lc))
        end
        fail_cast_retry('Cannot use command while healing', clean_text)
        return
    end

    if is_player_cast_interrupted_exact(clean_text) then
        fail_cast_retry('Cast interrupted', clean_text)
        return
    end

    if is_unable_cast_spells_time(clean_text) then
        fail_cast_retry('Unable to cast spells at this time', clean_text)
        -- "Unable to cast spells at this time" usually means we fired
        -- /ma a hair too early after a stand-up /heal and the player
        -- was still mid-animation. Refresh the stand-lock so the next
        -- tick retries from a standing position instead of letting
        -- auto-rest pull us back down into the same loop.
        refresh_stand_lock('cast-fail:unable-to-cast')
        return
    end

    if is_not_enough_mp_line(clean_text) then
        fail_cast_retry('Not enough MP', clean_text)
        return
    end

    -- Silent in-game fails (out of range, no effect, cannot see, etc.)
    -- Only react when we believe a cast is in flight -- these phrases
    -- can appear in unrelated contexts (e.g. someone else's missed
    -- attack) and we don't want to false-clear a fresh cast lock.
    if S.is_casting then
        local silent_fail, why = is_silent_cast_fail(clean_text)
        if silent_fail then
            fail_cast_retry('In-game silent fail: ' .. tostring(why), clean_text)
            return
        end
    end

    -- Line 1: "Playername starts casting Spellname on Target."
    -- Confirms the command was accepted; refresh the cast timeout so we don't
    -- time out a slow spell that the server acknowledged.
    local starts_name = parse_player_starts_casting(clean_text)
    if starts_name ~= nil then
        -- Covers both bot-initiated AND manual casts. Blocks rest_down from
        -- firing /heal mid-cast. Effective cast time accounts for the
        -- player's Fast Cast tier so a 5s base Refresh on RDM55 (Fast
        -- Cast III) lines up with the actual ~4s cast.
        local cast_time = FC.cast_time(starts_name)
        S.manual_cast_until = now() + cast_time + ANIMATION_END_SEC + 1.0

        -- Stand-lock: any cast we (the player) initiate means we're
        -- standing. Refresh unconditionally -- not gated by last_spell_sent
        -- match, because manual casts won't match and they still
        -- legitimately stand the player. parse_player_starts_casting
        -- already restricts the regex to the player's own name, so any
        -- match here is "we are casting, definitely standing."
        refresh_stand_lock('cast-start:' .. tostring(starts_name))

        local match = (S.last_spell_sent == nil or starts_name == S.last_spell_sent)
        if match and S.is_casting then
            -- Fresh timeout from the moment the game confirmed the
            -- cast started. Same formula as mark_spell_sent:
            -- cast_time covers the cast bar, ANIMATION_END_SEC
            -- covers the server-side finish phase (during which the
            -- completion chat line is emitted), and +1.0s is the
            -- chat-event delivery slack. Fast Cast is baked into
            -- cast_time.
            S.cast_timeout_at = now() + cast_time + ANIMATION_END_SEC + 1.0
            log('Cast started confirmed: ' .. starts_name)
        end
        return
    end

    -- Line 2: "Playername casts Spellname." or, for self-target
    -- buffs that emit it, "Playername gains the effect of X."
    -- (see parse_player_casts_name for the fallback patterns).
    local casts_name, from_active_pattern = parse_player_casts_name(clean_text)
    if casts_name ~= nil then
        -- Hard clamp on the passive pattern. "Playername gains the
        -- effect of X" / "receives the effect of X" lines fire for
        -- ANY buff landing on us -- bard Ballad/Madrigal/Minuet, a
        -- party WHM's Refresh/Haste/Regen, anything. The pattern
        -- matching just sees "X" with no info about who cast it. So
        -- unless our own cast tracker (S.is_casting +
        -- S.last_spell_sent) confirms we're actively casting THIS
        -- spell name, the line is somebody else's buff and we
        -- discard it entirely -- no stand-lock, no manual_cast_until
        -- reset, no spell_lock_until bump, no complete_cast.
        --
        -- Self-cast self-buffs (Reraise / Stoneskin / self-Refresh /
        -- self-Haste / self-Regen) -- which were the original reason
        -- the passive pattern exists -- ALSO complete via
        -- try_buff_completion in tick(), which polls self_has_buff()
        -- against SELF_BUFF_MAP every tick and fires complete_cast
        -- ('buff') the moment the 0x076 buff sync packet shows the
        -- buff. That's the primary completion path; by the time the
        -- chat line lands, is_casting is usually already false from
        -- try_buff_completion. The passive chat-line path is just
        -- a backup when the buff poller misses the window.
        --
        -- Active pattern ("Player casts X") is unambiguous -- the
        -- player definitely cast it (manually or via bot) -- and
        -- always proceeds.
        if not from_active_pattern then
            if not S.is_casting or casts_name ~= (S.last_spell_sent or '') then
                return
            end
        end

        -- manual_cast_until reset on the same gate as the early
        -- stand-lock refresh: only when the active pattern proves
        -- the player just cast something. Passive buff lands from
        -- the bard / a party member shouldn't clear our manual-cast
        -- tracker if we're mid-manual-cast.
        if from_active_pattern then
            S.manual_cast_until = 0.0
        end

        -- Stand-lock: refresh on EVERY "Playername casts X" line
        -- (the active pattern), regardless of whether last_spell_sent
        -- matches. That line proves the player just cast something --
        -- manual or bot-initiated -- and they're standing.
        --
        -- For the PASSIVE patterns we DON'T refresh here, because
        -- those match buffs landing on the player from any source.
        -- The match-block complete_cast below still refreshes
        -- stand-lock through its own path when last_spell_sent
        -- matches -- so OUR self-buff casts that complete via the
        -- passive pattern still get their stand-lock bump.
        if from_active_pattern then
            refresh_stand_lock('cast-complete:' .. tostring(casts_name))
        end

        -- Animation-lock guard. When the action packet completes a
        -- cast, the matching "Playername casts X" chat-line still
        -- arrives -- the chat-line is gated on the post-bar finish
        -- animation, which is the same window we're locked out of
        -- sending /ma in. By the time it lands, action-packet
        -- completion has often already run complete_cast for that
        -- cast AND a new /ma has gone out for the next spell. The
        -- chat-line is on-time for the FINISHED cast, but if we
        -- run the full chat-line path here we:
        --   * Clobber the new cast's spell_lock (reset to
        --     now+POST_CAST_SETTLE -- too short for the cast in
        --     flight) -> next /ma fires into a still-locked
        --     server slot -> UTC failure.
        --   * Spuriously call complete_cast on the finished cast's
        --     name a second time, which (if it happens to match
        --     the in-flight cast name, e.g. Cure III -> different
        --     target) clears is_casting and sets buff timers for
        --     a cast that isn't actually done.
        -- Two gates filter the chat-line down to "this is a fresh
        -- completion we haven't booked yet":
        --   1. is_casting must be true. If false, the cast this
        --      chat-line refers to was already completed by
        --      action/buff/timeout and we have nothing to add.
        --   2. elapsed since last_cast_sent_at must be >= the
        --      tracked spell's FC.cast_time. If shorter, a new
        --      cast was sent within the previous cast's animation
        --      window and this chat-line is for that previous
        --      cast (already booked); don't re-run completion on
        --      the new in-flight cast's mark_spell_sent state.
        -- Either gate failing: skip entirely. The in-flight cast's
        -- mark_spell_sent lock stays intact and the right cast
        -- finishes via its own action/buff/timeout signal.
        if not S.is_casting then
            return
        end
        local floor_spell = S.last_spell_sent or casts_name
        local elapsed = now() - (S.last_cast_sent_at or 0)
        if elapsed < FC.cast_time(floor_spell) then
            return
        end

        -- Past both gates: chat-line is plausibly the completion
        -- of our current cast. Apply the post-cast settle baseline
        -- (complete_cast overrides this for the matching case).
        -- Reason for setting it here too: parse_player_casts_name
        -- can capture joined chat lines that don't normalize to a
        -- bare spell name and therefore don't match
        -- S.last_spell_sent -- in which case the complete_cast
        -- call below is skipped, but we still need the spell-slot
        -- cushion to avoid an immediate /ma being rejected.
        S.spell_lock_until = now() + POST_CAST_SETTLE

        if S.last_spell_sent == nil or casts_name == S.last_spell_sent then
            -- Matching cast: full bookkeeping via complete_cast.
            -- 'log' selects POST_CAST_SETTLE (not BUFF) because the
            -- chat line is gated on animation completion -- by the
            -- time we see it, the spell slot has been released.
            complete_cast('log')
        else
            -- Non-matching completion (e.g. a manual cast the user
            -- fired that overlapped with a bot cast, or a chat
            -- line we parsed but couldn't normalize cleanly). The
            -- stand-lock and post-cast settle above still applied;
            -- we just don't touch buff timers or is_casting.
            CastLog.confirmed(casts_name, 'log')
            log(string.format('Cast completed (log, no match): %s', tostring(casts_name)))
        end
        return
    end
end

---------------------------------------------------------------------
-- PACKET IN
---------------------------------------------------------------------

-- Player-cast completion via action packet. The action packet for a
-- spell finish (category 4) arrives the moment the server commits
-- the cast effect -- well before the chat-line "Playername casts X"
-- that parse_player_casts_name relies on. On HorizonXI the chat-line
-- tail empirically runs 3-5s past bar-fill for party/mob-target
-- casts (Dia/Paralyze/Slow/Stone/party-buffs/Poisona); catching the
-- action packet here shaves that off the perceived Casting status
-- duration. Self-cast self-buffs still confirm via try_buff_completion
-- at bar-fill (faster than waiting for the action packet round-trip).
--
-- Gate (all required to fire):
--   1. is_casting is true (a cast we initiated is in flight)
--   2. ap.UserId equals the local player's server ID -- the action
--      came from us, not someone else
--   3. ap.Type == 4 (spell finish) when the field is exposed by this
--      helpers build. Type 8 is "magic start" and fires at /ma send;
--      we never want to credit on that. If Type isn't exposed at all,
--      we fall through to the elapsed-time gate, which is strict
--      enough on its own to reject type-8 starts (they fire at
--      elapsed=~0, well below FC.cast_time).
--   4. elapsed >= FC.cast_time(spell) -- same cast-bar floor as
--      try_buff_completion. Rejects type-8 starts AND any other
--      action-during-cast (job ability used mid-cast, etc.) that
--      lands before the bar could have finished.
--   5. ap.Targets contains a target matching the cast's target.
--      Party-member casts (incl. self): exact server-ID match.
--      Mob casts (target_name starts with '<' -- <bt>/<t>/<me>/etc.,
--      or a literal mob name): any non-party target Id counts.
--
-- On a hit: complete_cast('action') runs the unified completion path
-- (buff timers, post-cast settle, stand-lock refresh, spell_clear,
-- casttimes.txt row with `via=action`).
local function try_action_completion(ap, party_ids)
    if not S.is_casting then return end
    local spell = S.last_spell_sent
    if not spell or spell == '' then return end
    if not ap or not ap.UserId then return end

    local pm = party()
    if not pm then return end
    local ok_self, self_sid_raw = pcall(function() return pm:GetMemberServerId(0) end)
    if not ok_self then return end
    local self_sid = tonumber(self_sid_raw) or 0
    if self_sid == 0 or tonumber(ap.UserId) ~= self_sid then return end

    -- Category gate: prefer Type 4 (spell finish) when the helpers
    -- build exposes it. Different ParseActionPacket forks use Type,
    -- Category, or ActionType for the same field. If none are
    -- present, fall through -- the elapsed-time gate below filters
    -- out the type-8 "magic start" packet on its own.
    local ap_type = tonumber(ap.Type or ap.Category or ap.ActionType or 0)
    if ap_type > 0 and ap_type ~= 4 then return end

    -- Cast-bar floor: same as try_buff_completion. A finish earlier
    -- than this can't physically be the cast we're tracking.
    local elapsed = now() - (S.last_cast_sent_at or 0)
    if elapsed < FC.cast_time(spell) then return end

    -- Target match. Resolve target_name:
    --   * party-member name (incl. player's own): look up the sid by
    --     name and require exact match on any target in the packet
    --   * '<bt>' / '<t>' / '<me>' / mob-name (anything starting with
    --     '<'): no party sid expected, accept any non-party target
    local target_name = S.last_spell_target_name or ''
    local targets = ap.Targets or {}
    if #targets == 0 then return end

    local expected_sid = 0
    if target_name ~= '' and not target_name:match('^<') then
        for slot = 0, 17 do
            if n(pm:GetMemberIsActive(slot)) == 1 then
                local mname = pm:GetMemberName(slot) or ''
                if mname == target_name then
                    local oks, sid = pcall(function() return pm:GetMemberServerId(slot) end)
                    if oks and sid then expected_sid = tonumber(sid) or 0 end
                    break
                end
            end
        end
    end

    local matched = false
    for i = 1, #targets do
        local t = targets[i]
        local tid = t and tonumber(t.Id) or 0
        if tid > 0 then
            if expected_sid > 0 then
                if tid == expected_sid then
                    matched = true
                    break
                end
            else
                -- Mob cast: any non-party target Id qualifies.
                if not (party_ids and party_ids[tid]) then
                    matched = true
                    break
                end
            end
        end
    end
    if not matched then return end

    complete_cast('action')
end

ashita.events.register('text_in', 'bm_text_in', function(e)
    local ok, err = pcall(_bm_text_in_body, e)
    if not ok then _bvm_dbg('text_in', err) end
end)

local function _bm_packet_in_body(e)
    if e.injected then return end

    if e.id == 0x0A then
        S.all_claimed_targets = {}
        S.debuff_mob_sid      = 0
        S.debuffs_done        = {}
        S.skillup_done        = {}
        S.refresh_timers      = {}
        S.haste_timers        = {}
        S.regen_timers        = {}
        S.protect_timers      = {}
        S.shell_timers        = {}
        S.cure_timers         = {}
        mob_debuffs           = {}   -- clear packet-tracked mob debuffs on zone
        Mob.mob_buff_seen_at      = {}   -- clear first-seen timestamps too
        -- StatusHandler keeps its own party buff state across zone;
        -- the next 0x076 packet after zone-in will repopulate it.
        return
    end

    -- Packet 0x076: party buff sync — delegate to StatusHandler (same
    -- path bovinebattle / packet_parser use).
    if e.id == 0x076 then
        if StatusHandler and type(StatusHandler.ReadPartyBuffsFromPacket) == 'function' then
            pcall(StatusHandler.ReadPartyBuffsFromPacket, e)
        end
        return
    end

    local party_ids = get_party_server_ids()

    -- Feed ALL action packets to the mob debuff tracker (player casts on mobs land here)
    local ok1, ap = pcall(ParseActionPacket, e)
    if ok1 and ap then
        mob_debuff_apply(ap)

        -- Player-cast completion via action packet. Faster than the
        -- chat-line path (parse_player_casts_name) on HorizonXI by
        -- 3-5s for party/mob-target casts. See try_action_completion
        -- docstring for the gate. Wrapped in pcall because this fires
        -- on every action packet -- a crash here would silently break
        -- mob tracking below.
        pcall(try_action_completion, ap, party_ids)

        if ap.UserIndex and ap.UserIndex > 0 then
            -- HXUI mirror. enemylist does:
            --   if GetIsMobByIndex(UserIndex) and GetIsValidMob(UserIndex)
            --       for each target if party then allClaimed[idx] = 1
            -- is_mob_by_index is the critical filter -- it rejects
            -- pets, Trusts, NPCs, and non-party PCs that happen to hit
            -- a party member (via AoE, debuff, etc). Without it those
            -- entities ended up in all_claimed_targets as phantoms
            -- the picker would lock onto (locked sid that <bt> doesn't
            -- resolve to -> casts go into the void -> "Debuffs: none
            -- tracked" forever). No row table, no settle, no
            -- server_id storage -- the entity table is the source of
            -- truth, read live in prune and get_claimed_mobs_in_range.
            if is_mob_by_index(ap.UserIndex) and is_valid_mob(ap.UserIndex) then
                local targets = ap.Targets or {}
                for i = 1, #targets do
                    local t = targets[i]
                    if t and party_ids[t.Id] then
                        S.all_claimed_targets[ap.UserIndex] =
                            S.all_claimed_targets[ap.UserIndex] or now()
                        break
                    end
                end
            end
        end
    end

    -- Feed message packets to the mob debuff tracker (wear-off and death clearing)
    local ok_mp, mp = pcall(ParseMessagePacket, e.data)
    if ok_mp and mp then
        mob_debuff_clear(mp)
    end

    local ok4, mu = pcall(ParseMobUpdatePacket, e)
    if ok4 and mu and mu.monsterIndex and mu.monsterIndex > 0 then
        -- HXUI mirror. enemylist does:
        --   if newClaimId ~= nil and GetIsValidMob(monsterIndex) then
        --       if partyMemberIds:contains(newClaimId) then
        --           allClaimed[monsterIndex] = 1
        if mu.newClaimId and party_ids[mu.newClaimId] and is_valid_mob(mu.monsterIndex) then
            S.all_claimed_targets[mu.monsterIndex] =
                S.all_claimed_targets[mu.monsterIndex] or now()
        end
    end
end

ashita.events.register('packet_in', 'bm_packet_in', function(e)
    local ok, err = pcall(_bm_packet_in_body, e)
    if not ok then _bvm_dbg('packet_in', err) end
end)

---------------------------------------------------------------------
-- COMMAND HANDLER
---------------------------------------------------------------------

ashita.events.register('command', 'bm_cmd', function(event)
    local args = event.command:args()
    if #args == 0 then return end

    local cmd0 = (args[1] or ''):lower()
    if cmd0 ~= '/bm' and cmd0 ~= '/bovinemage' then return end
    event.blocked = true

    local sub = (args[2] or ''):lower()
    if sub == 'start' then
        S.running = true
        spell_clear()
        S.spell_lock_until = 0.0
        S.stand_lock_until = now() + STAY_STANDING_SEC
        cprint('Started')
    elseif sub == 'stop' then
        S.running = false
        cprint('Stopped')
    elseif sub == 'debug' then
        S.debug = not S.debug
        cprint('Debug: ' .. tostring(S.debug))
    elseif sub == 'buffs' then
        -- Dump ground truth so we can see why self-buff detection is failing.
        local m     = memory()
        local pm    = m and m:GetParty()
        local pmgr  = m and m:GetPlayer()
        local pname = P.player_name()
        local self_sid = 0
        if pm then
            local ok, sid = pcall(function() return pm:GetMemberServerId(0) end)
            if ok and sid then self_sid = tonumber(sid) or 0 end
        end
        cprint(string.format('name=%q self_sid=%d now=%.1f', pname, self_sid, now()))

        -- GetPlayer():GetBuffs() path (may return userdata, not a table)
        local gp_list = '(nil)'
        if pmgr then
            local ok, buffs = pcall(function() return pmgr:GetBuffs() end)
            if ok and buffs then
                local ok2, nb = pcall(function() return #buffs end)
                if ok2 and nb then
                    local ids = {}
                    for i = 1, nb do
                        local okv, v = pcall(function() return buffs[i] end)
                        ids[#ids+1] = okv and tostring(v) or '?'
                    end
                    gp_list = '[' .. table.concat(ids, ',') .. '] len=' .. tostring(nb)
                else
                    gp_list = '(length unreadable: ' .. tostring(nb) .. ')'
                end
            else
                gp_list = '(GetBuffs returned: ' .. tostring(buffs) .. ')'
            end
        end
        cprint('GetPlayer:GetBuffs = ' .. gp_list)

        -- StatusHandler path for self
        local sh_list = '(nil)'
        if StatusHandler and type(StatusHandler.get_member_status) == 'function' then
            local ok, buffs = pcall(StatusHandler.get_member_status, self_sid)
            if ok and type(buffs) == 'table' then
                local ids = {}
                for i = 1, #buffs do ids[#ids+1] = tostring(buffs[i]) end
                sh_list = '[' .. table.concat(ids, ',') .. '] len=' .. tostring(#buffs)
            else
                sh_list = '(get_member_status failed: ' .. tostring(buffs) .. ')'
            end
        end
        cprint('StatusHandler[self_sid] = ' .. sh_list)

        -- Detector results for common buffs
        cprint(string.format('self_has_buff: REFRESH=%s HASTE=%s REGEN=%s',
            tostring(self_has_buff(BUFF.REFRESH)),
            tostring(self_has_buff(BUFF.HASTE)),
            tostring(self_has_buff(BUFF.REGEN))))

        -- Timers
        cprint(string.format('refresh_timer[%s] = %s (rem=%s)',
            pname,
            tostring(S.refresh_timers[pname]),
            tostring(S.refresh_timers[pname] and (S.refresh_timers[pname] - now()) or 'nil')))
    elseif sub == 'mob' then
        -- Dump what we know about the active debuff mob, so we can see
        -- whether debuffHandler is reporting Evasion Boost / Defense
        -- Boost on it. If the buff IS in debuffHandler's view but the
        -- auto-dispel block isn't firing, the bug is here. If the buff
        -- is NOT in debuffHandler's view, the bug is upstream (the
        -- handler isn't tracking that status for some reason).
        local sid = S.debuff_mob_sid or 0
        cprint(string.format('debuff_mob_sid = %d', sid))
        local cm = Mob.get_claimed_mobs_in_range()
        cprint(string.format('claimed mobs in range (<= %.1fy): %d',
            MOB_ENGAGE_RANGE, #cm))
        for _, m in ipairs(cm) do
            cprint(string.format('  idx=%d sid=%d dist=%.1f',
                m.index, m.server_id, m.dist or 0))
        end
        if sid ~= 0 then
            -- debuffHandler view -- dump BOTH array slots and pairs() so
            -- we catch either return shape (array {92,93} or hash table
            -- {[92]=true,[93]=true} -- the auto-dispel scan currently
            -- only handles arrays).
            if debuffHandler and type(debuffHandler.GetActiveDebuffs) == 'function' then
                local ok, list = pcall(debuffHandler.GetActiveDebuffs, sid)
                if ok and type(list) == 'table' then
                    local arr = {}
                    for i = 1, #list do arr[#arr+1] = tostring(list[i]) end
                    local kv = {}
                    for k, v in pairs(list) do
                        kv[#kv+1] = string.format('%s=%s', tostring(k), tostring(v))
                    end
                    cprint(string.format('debuffHandler[%d]: #=%d  array=[%s]  pairs=[%s]',
                        sid, #list, table.concat(arr, ','), table.concat(kv, ',')))
                else
                    cprint('debuffHandler.GetActiveDebuffs result: ' .. tostring(list))
                end
            else
                cprint('debuffHandler.GetActiveDebuffs not available')
            end
            -- Local packet-tracked view
            local entry = mob_debuffs[sid]
            if entry then
                local ids = {}
                for k, v in pairs(entry) do
                    ids[#ids+1] = string.format('%s(rem=%ds)',
                        tostring(k), tonumber(v) and (v - os.time()) or 0)
                end
                cprint(string.format('mob_debuffs[%d]: [%s]', sid, table.concat(ids, ',')))
            else
                cprint(string.format('mob_debuffs[%d]: (none)', sid))
            end
            -- CFG.AUTO_DISPEL_BUFFS map
            local map = {}
            for bid, nm in pairs(CFG.AUTO_DISPEL_BUFFS) do
                map[#map+1] = string.format('%d=%s', bid, nm)
            end
            cprint('CFG.AUTO_DISPEL_BUFFS: ' .. table.concat(map, ', '))
        end
    elseif sub == 'show' then
        gui_state.visible = true
    elseif sub == 'hide' then
        gui_state.visible = false
    else
        cprint('/bm start | stop | debug | buffs | mob | show | hide')
    end
end)

---------------------------------------------------------------------
-- SETTINGS
---------------------------------------------------------------------

local SETTINGS_PATH = addon.path .. 'settings/settings.lua'

-- Minimal table serializer (flat: strings, booleans, numbers, and arrays of strings)
local function serialize_settings(data)
    local lines = { 'return {' }
    for k, v in pairs(data) do
        if type(v) == 'boolean' then
            lines[#lines+1] = string.format('  %s = %s,', k, tostring(v))
        elseif type(v) == 'number' then
            lines[#lines+1] = string.format('  %s = %s,', k, tostring(v))
        elseif type(v) == 'string' then
            lines[#lines+1] = string.format('  %s = %q,', k, v)
        elseif type(v) == 'table' then
            -- Two table shapes need handling: array-style target lists
            -- (e.g. haste_targets) and name-keyed sets (the priority
            -- maps). #v == 0 with at least one pair means it's a
            -- string-keyed map; otherwise treat it as an array. This
            -- preserves the existing array save format byte-for-byte
            -- while letting the priority maps round-trip.
            local is_map = (#v == 0)
            if is_map then
                local has_any = false
                for _ in pairs(v) do has_any = true; break end
                if not has_any then is_map = false end
            end
            if is_map then
                local items = {}
                for kk, vv in pairs(v) do
                    if type(kk) == 'string' and vv then
                        items[#items+1] = string.format('[%q] = %s', kk, tostring(vv and true or false))
                    end
                end
                lines[#lines+1] = string.format('  %s = { %s },', k, table.concat(items, ', '))
            else
                local items = {}
                for i = 1, #v do
                    items[#items+1] = string.format('%q', tostring(v[i] or ''))
                end
                lines[#lines+1] = string.format('  %s = { %s },', k, table.concat(items, ', '))
            end
        end
    end
    lines[#lines+1] = '}'
    return table.concat(lines, '\n')
end

local function save_settings()
    -- Party-member target arrays (refresh_extras, haste_targets,
    -- regen_targets, cure_only_emergency) ARE saved here, so a player
    -- who reloads the addon mid-session, or starts a new session with
    -- the same group, doesn't have to re-check every name. The original
    -- design dropped them on purpose to avoid stale names driving the
    -- run loop after a party change. That concern is now handled by
    -- Mob.prune_stale_party_targets() running each tick: the first time the
    -- party signature differs from what was loaded, ghost names get
    -- cleared automatically. Result: same group → checkboxes restore
    -- as they were; different group → stale names dropped on first
    -- tick where party is resolved.
    --
    -- Timer maps (refresh_timers, haste_timers, regen_timers,
    -- cure_timers) are NOT saved -- they're runtime state with no
    -- meaning across reloads, since the buffs they refer to are long
    -- gone by then.
    local data = {
        refresh_enabled   = S.refresh_enabled,
        haste_enabled     = S.haste_enabled,
        regen_enabled     = S.regen_enabled,
        protect_enabled   = S.protect_enabled,
        shell_enabled     = S.shell_enabled,
        reraise_enabled   = S.reraise_enabled,
        paralyna_enabled  = S.paralyna_enabled,
        silena_enabled    = S.silena_enabled,
        poisona_enabled   = S.poisona_enabled,
        blindna_enabled   = S.blindna_enabled,
        stoneskin_enabled = S.stoneskin_enabled,
        blink_enabled     = S.blink_enabled,
        phalanx_enabled   = S.phalanx_enabled,
        barelement_active = S.barelement_active,

        -- BLM Skillup settings: master + selected spell + thresholds
        blm_skillup_enabled    = S.blm_skillup_enabled,
        blm_skillup_spell      = S.blm_skillup_spell,
        blm_skillup_min_hp_pct = S.blm_skillup_min_hp_pct,
        blm_skillup_min_mp_pct = S.blm_skillup_min_mp_pct,
        disable_cure      = S.disable_cure,
        debuff_enabled         = S.debuff_enabled,
        debuff_reapply_enabled = S.debuff_reapply_enabled,
        dia_tier               = S.dia_tier,
        paralyze_enabled       = S.paralyze_enabled,
        slow_enabled           = S.slow_enabled,
        blind_enabled          = S.blind_enabled,
        auto_dispel_enabled    = S.auto_dispel_enabled,
        mob_silence_enabled    = S.mob_silence_enabled,
        mob_silence_target     = S.mob_silence_target,
        auto_full_rest           = S.auto_full_rest,
        emergency_cure_threshold = S.emergency_cure_threshold,
        drg_healer_mode          = S.drg_healer_mode,
        drg_sustain_sec          = S.drg_sustain_sec,
        debug                  = S.debug,
        timeout_disable        = S.timeout_disable,
        -- Target arrays (see header comment above)
        refresh_extras          = S.refresh_extras,
        haste_targets           = S.haste_targets,
        regen_targets           = S.regen_targets,
        protect_targets         = S.protect_targets,
        shell_targets           = S.shell_targets,
        barelement_targets      = S.barelement_targets,
        auto_move_enabled       = S.auto_move_enabled,
        auto_move_targets       = S.auto_move_targets,
        -- Priority sets keyed by name. Restored only for names that
        -- are still in the corresponding target array on load (see
        -- load_settings), so a member who's no longer being buffed
        -- doesn't get a stale priority flag.
        refresh_priority        = S.refresh_priority,
        haste_priority          = S.haste_priority,
        cure_only_emergency     = S.cure_only_emergency,
        emergency_cure_excluded = S.emergency_cure_excluded,
        brd_overcure            = S.brd_overcure,
    }
    -- Ensure settings directory exists
    local dir = addon.path .. 'settings'
    os.execute('mkdir "' .. dir .. '" 2>nul')
    local f = io.open(SETTINGS_PATH, 'w')
    if f then
        f:write(serialize_settings(data))
        f:close()
    else
        cwarn('Could not save settings to: ' .. SETTINGS_PATH)
    end
end

local function load_settings()
    local f = io.open(SETTINGS_PATH, 'r')
    if not f then return end
    local src = f:read('*a')
    f:close()
    if not src or src == '' then return end

    local ok, data = pcall(function()
        local fn = load(src)
        return fn and fn()
    end)
    if not ok or type(data) ~= 'table' then
        cwarn('Could not parse settings file')
        return
    end

    -- Party-member target arrays ARE restored here -- see save_settings'
    -- header comment for the rationale (short version: same group as
    -- last session keeps its checkboxes; different group gets stale
    -- names pruned by Mob.prune_stale_party_targets() on the first tick
    -- where the live party is resolved). Note: the load event can fire
    -- before the party is populated (e.g. game-launch into character
    -- select), so we don't try to prune here -- the per-tick pruner
    -- handles that organically.
    --
    -- restore_target_arr: copies up to 6 string entries from saved into
    -- dest, padding short arrays with '' and ignoring non-string slots.
    -- Defends against a malformed or hand-edited settings file.
    local function restore_target_arr(saved, dest)
        if type(saved) ~= 'table' then return end
        for i = 1, 6 do
            local v = saved[i]
            dest[i] = (type(v) == 'string') and v or ''
        end
    end

    if data.refresh_enabled   ~= nil then S.refresh_enabled   = data.refresh_enabled   end
    if data.haste_enabled     ~= nil then S.haste_enabled     = data.haste_enabled     end
    if data.regen_enabled     ~= nil then S.regen_enabled     = data.regen_enabled     end
    if data.protect_enabled   ~= nil then S.protect_enabled   = data.protect_enabled   end
    if data.shell_enabled     ~= nil then S.shell_enabled     = data.shell_enabled     end
    if data.reraise_enabled   ~= nil then S.reraise_enabled   = data.reraise_enabled   end
    if data.paralyna_enabled  ~= nil then S.paralyna_enabled  = data.paralyna_enabled  end
    if data.silena_enabled    ~= nil then S.silena_enabled    = data.silena_enabled    end
    if data.poisona_enabled   ~= nil then S.poisona_enabled   = data.poisona_enabled   end
    if data.blindna_enabled   ~= nil then S.blindna_enabled   = data.blindna_enabled   end
    if data.stoneskin_enabled ~= nil then S.stoneskin_enabled = data.stoneskin_enabled end
    if data.blink_enabled     ~= nil then S.blink_enabled     = data.blink_enabled     end
    if data.phalanx_enabled   ~= nil then S.phalanx_enabled   = data.phalanx_enabled   end
    -- Bar-element active spell: validate against the known set so a
    -- corrupt or hand-edited file can't poke a stray string into the
    -- cascade. nil / empty / unknown names all collapse to "off".
    if type(data.barelement_active) == 'string'
       and BARELEMENT_BUFF_ID[data.barelement_active] then
        S.barelement_active = data.barelement_active
    end
    if data.blm_skillup_enabled    ~= nil then S.blm_skillup_enabled    = data.blm_skillup_enabled    end
    if data.blm_skillup_spell      ~= nil then S.blm_skillup_spell      = data.blm_skillup_spell      end
    if data.blm_skillup_min_hp_pct ~= nil then S.blm_skillup_min_hp_pct = data.blm_skillup_min_hp_pct end
    if data.blm_skillup_min_mp_pct ~= nil then S.blm_skillup_min_mp_pct = data.blm_skillup_min_mp_pct end
    if data.disable_cure      ~= nil then S.disable_cure      = data.disable_cure      end
    -- Backward compat: old setting `cure_enabled = false` maps to
    -- `disable_cure = true`. Only apply when disable_cure wasn't in the
    -- file itself (so a current file beats a legacy one if both exist).
    if data.disable_cure == nil and data.cure_enabled == false then
        S.disable_cure = true
    end
    -- (data.cure_self_enabled from old settings is silently ignored;
    --  the field is replaced by per-member checkboxes in the new GUI.
    --  Users who had self-cure off will see self CHECKED in both rows
    --  after upgrade and can re-uncheck if desired.)
    if data.debuff_enabled         ~= nil then S.debuff_enabled         = data.debuff_enabled         end
    if data.debuff_reapply_enabled ~= nil then S.debuff_reapply_enabled = data.debuff_reapply_enabled end
    if type(data.dia_tier) == 'number' and data.dia_tier >= 0 and data.dia_tier <= 2 then
        S.dia_tier = math.floor(data.dia_tier)
    end
    if data.paralyze_enabled       ~= nil then S.paralyze_enabled       = data.paralyze_enabled       end
    if data.slow_enabled           ~= nil then S.slow_enabled           = data.slow_enabled           end
    if data.blind_enabled          ~= nil then S.blind_enabled          = data.blind_enabled          end
    if data.auto_dispel_enabled    ~= nil then S.auto_dispel_enabled    = data.auto_dispel_enabled    end
    if data.mob_silence_enabled    ~= nil then S.mob_silence_enabled    = data.mob_silence_enabled    end
    if type(data.mob_silence_target) == 'string' then S.mob_silence_target = data.mob_silence_target end
    if data.auto_full_rest         ~= nil then S.auto_full_rest         = data.auto_full_rest         end
    -- Emergency threshold: only accept the two values the GUI exposes.
    -- Anything else (corrupt file, hand-edited) is silently ignored and
    -- the default from S.emergency_cure_threshold stands.
    if data.emergency_cure_threshold == 35 or data.emergency_cure_threshold == 50 then
        S.emergency_cure_threshold = data.emergency_cure_threshold
    end
    if data.drg_healer_mode   ~= nil then S.drg_healer_mode   = data.drg_healer_mode   end
    if type(data.drg_sustain_sec) == 'number' then
        -- Clamp to the slider range so a hand-edited file can't push us
        -- below 1s (cure spam) or above 10s (effectively never cures).
        local v = data.drg_sustain_sec
        if v < DRG_SUSTAIN_MIN then v = DRG_SUSTAIN_MIN end
        if v > DRG_SUSTAIN_MAX then v = DRG_SUSTAIN_MAX end
        S.drg_sustain_sec = v
    end
    if data.debug             ~= nil then S.debug             = data.debug             end
    if data.timeout_disable   ~= nil then S.timeout_disable   = data.timeout_disable   end

    -- Target arrays. last (after the boolean settings) so any earlier
    -- early-return on parse failure has already happened.
    restore_target_arr(data.refresh_extras,          S.refresh_extras)
    restore_target_arr(data.haste_targets,           S.haste_targets)
    restore_target_arr(data.regen_targets,           S.regen_targets)
    restore_target_arr(data.protect_targets,         S.protect_targets)
    restore_target_arr(data.shell_targets,           S.shell_targets)
    restore_target_arr(data.barelement_targets,      S.barelement_targets)
    restore_target_arr(data.cure_only_emergency,     S.cure_only_emergency)
    restore_target_arr(data.emergency_cure_excluded, S.emergency_cure_excluded)
    restore_target_arr(data.brd_overcure,            S.brd_overcure)
    restore_target_arr(data.auto_move_targets,       S.auto_move_targets)
    if data.auto_move_enabled ~= nil then S.auto_move_enabled = data.auto_move_enabled end

    -- Priority sets. Only restore entries whose name is still in the
    -- matching target array -- a name that was un-checked between
    -- sessions shouldn't come back as a priority on the next session
    -- if the user re-adds them.
    local function restore_priority(saved, dest, target_arr)
        if type(saved) ~= 'table' then return end
        for name, v in pairs(saved) do
            if v and type(name) == 'string' and targets_contains(target_arr, name) then
                dest[name] = true
            end
        end
    end
    restore_priority(data.refresh_priority, S.refresh_priority, S.refresh_extras)
    restore_priority(data.haste_priority,   S.haste_priority,   S.haste_targets)
end

---------------------------------------------------------------------
-- LOAD / UNLOAD
---------------------------------------------------------------------

ashita.events.register('load', 'bm_load', function()
    if StatusHandler and type(StatusHandler.refreshFromMemory) == 'function' then
        pcall(StatusHandler.refreshFromMemory)
    end
    load_settings()
end)

ashita.events.register('unload', 'bm_unload', function()
    -- Do NOT send /heal here. Unloading the addon should not change the
    -- player's stance. If they were resting when /addon unload fires,
    -- they stay resting.
    save_settings()
end)
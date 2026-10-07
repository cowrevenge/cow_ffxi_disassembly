--[[
    bovinescan.lua - Entity scanner and alerter (Ashita v4)

    Passive scanner. Iterates the entity table once per second, classifies
    each entity (GM / Player / NPC / Mob / Self), and:
      - Alerts on GMs the moment they appear in the list (safety).
      - Alerts on entities whose name contains a user-supplied substring.
      - Lists everything nearby in a scrollable ImGui panel.

    Alert model is edge-triggered: an entity that's already in the list
    doesn't re-alert. It has to leave the list and come back to alert again.

    Only slash command is /bovinescan, which toggles the panel (X closes
    -> full addon unload, same as bovinefh).
]]

local ADDON_NAME = 'bovinescan'

addon.name    = ADDON_NAME
addon.author  = ''
addon.version = '1.1'
addon.desc    = 'Entity scanner with GM and target-name audible alerts.'

require('common')
local imgui    = require('imgui')
local settings = require('settings')

----------------------------------------------------------------------------------------------------
-- State
----------------------------------------------------------------------------------------------------

-- GUI toggles bundled in bracket-wrapped tables so imgui.Checkbox / InputText
-- can bind to them by reference (same pattern as bovinefh's S).
local S = {
    enabled    = { true },
    play_alert = { true },
    mob_name   = { '' },   -- 128-byte buffer, InputText reserves the rest
    debug      = { false },   -- when on, rows show me/mob/dx/dy tail

    -- Per-field match modes. false = Name matching, true = Hex matching.
    -- Radio-button pair in the UI drives each independently.
    mob_hex    = { false },
    ph1_hex    = { false },
    ph2_hex    = { false },

    -- --- AutoClaim -----------------------------------------------------
    -- When on, the scanner claims a matched mob using the chosen opener.
    -- 0 = /ra   1 = /provoke   2 = /dia   3 = /attack
    -- Off by default: this is the only thing in the addon that ACTS rather
    -- than observes, so it never turns itself on.
    autoclaim      = { false },
    autoclaim_mode = { 0 },

    -- --- PLACEHOLDER FIELD (widescan itself stays disabled) ---
    -- Widescan master enable. Locked to false: never sends packets, never
    -- parses incoming. UI shows it as a fake disabled control.
    widescan     = { false },

    -- --- PH tracker (LIVE now, but skips the widescan packet send).
    -- Two independent PH slots (some NMs have two placeholders). Either
    -- can be empty; empty slot is ignored. Names use ph1_hex / ph2_hex to
    -- pick match mode.
    ph1_name     = { '' },
    ph2_name     = { '' },
    -- Respawn timer in seconds. After a PH slot goes missing, arm the
    -- countdown. Countdown expiring "opens the window" -- currently only
    -- meaningful for local 40-50y scanning (no widescan), but the state
    -- machine is real so widescan can bolt onto it later.
    ph_respawn_s = { 900 },
}
-- Pad text buffers up to InputText's declared size. Without this the widget
-- can push past the initial short string and corrupt state.
S.mob_name[1] = S.mob_name[1] .. string.rep('\0', 128 - #S.mob_name[1])
S.ph1_name[1] = S.ph1_name[1] .. string.rep('\0', 128 - #S.ph1_name[1])
S.ph2_name[1] = S.ph2_name[1] .. string.rep('\0', 128 - #S.ph2_name[1])

----------------------------------------------------------------------------------------------------
-- Persistence
----------------------------------------------------------------------------------------------------
--
-- Ashita's `settings` lib stores JSON under
-- <ashita>/config/addons/bovinescan/<profile>/settings.json. We register a
-- flat defaults table (no bracket-wrapped values -- those are ImGui binding
-- quirks, not on-disk shape), then bounce them into and out of S on load /
-- save. Debounced save fires from d3d_present a short beat after any change,
-- so config survives crashes without slamming disk on every keystroke.

local defaults = T {
    enabled    = true,
    play_alert = true,
    mob_name   = '',
    debug      = false,
    -- Per-field match mode (false = name, true = hex).
    mob_hex    = false,
    ph1_hex    = false,
    ph2_hex    = false,
    -- Time-of-death log. Persisted as an array of small records. Capped at
    -- TOD_MAX entries; oldest drop off when we exceed the cap.
    tod_log = T { },
    -- Widescan stays disabled/placeholder.
    autoclaim      = false,
    autoclaim_mode = 0,
    widescan     = false,
    -- Two PH slots (either can be empty).
    ph1_name     = '',
    ph2_name     = '',
    ph_respawn_s = 900,
}

-- Live config, seeded from disk on load. Mutations write back into S.
local cfg = settings.load(defaults)

-- Push disk state into the ImGui-bound S bundles. Called once at load and
-- again whenever the settings lib fires a reload event.
local function apply_cfg_to_S()
    S.enabled[1]    = cfg.enabled and true or false
    S.play_alert[1] = cfg.play_alert and true or false
    S.debug[1]      = cfg.debug and true or false
    S.mob_hex[1]    = cfg.mob_hex and true or false
    S.ph1_hex[1]    = cfg.ph1_hex and true or false
    S.ph2_hex[1]    = cfg.ph2_hex and true or false
    -- AutoClaim persists, but the MODE is validated: a bad value on disk
    -- must not send an undefined opener.
    S.autoclaim[1]  = cfg.autoclaim and true or false
    local acm = tonumber(cfg.autoclaim_mode or 0) or 0
    S.autoclaim_mode[1] = (acm >= 0 and acm <= 3) and math.floor(acm) or 0
    local mn = tostring(cfg.mob_name or '')
    if #mn > 127 then mn = mn:sub(1, 127) end
    S.mob_name[1] = mn .. string.rep('\0', 128 - #mn)

    -- Widescan is forced off regardless of what's on disk -- the widescan
    -- packet feature is disabled and cannot be turned on. PH tracking
    -- itself IS live now (skips the widescan packet, still runs the local
    -- 40-50y scan and the respawn timer).
    S.widescan[1]     = false
    local p1 = tostring(cfg.ph1_name or '')
    if #p1 > 127 then p1 = p1:sub(1, 127) end
    S.ph1_name[1]     = p1 .. string.rep('\0', 128 - #p1)
    local p2 = tostring(cfg.ph2_name or '')
    if #p2 > 127 then p2 = p2:sub(1, 127) end
    S.ph2_name[1]     = p2 .. string.rep('\0', 128 - #p2)
    S.ph_respawn_s[1] = tonumber(cfg.ph_respawn_s) or 900
end
apply_cfg_to_S()

-- Signature over the current S values. Any change flips cfg_dirty_at, and
-- the d3d_present tick calls save_cfg once the value settles (0.75s idle).
-- Same debounce pattern as bovinefh so InputText typing doesn't hammer disk.
local function cfg_signature()
    return table.concat({
        S.enabled[1] and '1' or '0',
        S.play_alert[1] and '1' or '0',
        S.debug[1] and '1' or '0',
        S.mob_hex[1] and '1' or '0',
        S.ph1_hex[1] and '1' or '0',
        S.ph2_hex[1] and '1' or '0',
        (S.mob_name[1] or ''):gsub('%z+$', ''),
        S.widescan[1] and '1' or '0',
        (S.ph1_name[1] or ''):gsub('%z+$', ''),
        (S.ph2_name[1] or ''):gsub('%z+$', ''),
        tostring(S.ph_respawn_s[1] or 0),
    }, '|')
end
local last_cfg_sig = nil
local cfg_dirty_at = 0

local function save_cfg()
    cfg.enabled      = S.enabled[1] and true or false
    cfg.play_alert   = S.play_alert[1] and true or false
    cfg.debug        = S.debug[1] and true or false
    cfg.mob_hex      = S.mob_hex[1] and true or false
    cfg.ph1_hex      = S.ph1_hex[1] and true or false
    cfg.ph2_hex      = S.ph2_hex[1] and true or false
    cfg.mob_name     = (S.mob_name[1] or ''):gsub('%z+$', '')
    cfg.autoclaim      = S.autoclaim[1]
    cfg.autoclaim_mode = S.autoclaim_mode[1]
    cfg.widescan     = false   -- always saved as off (widescan disabled)
    cfg.ph1_name     = (S.ph1_name[1] or ''):gsub('%z+$', '')
    cfg.ph2_name     = (S.ph2_name[1] or ''):gsub('%z+$', '')
    cfg.ph_respawn_s = tonumber(S.ph_respawn_s[1]) or 900
    -- sync_tod_to_cfg is a forward reference here -- it lives further down
    -- with the rest of the ToD helpers.
    if type(sync_tod_to_cfg) == 'function' then sync_tod_to_cfg() end
    settings.save()
end

-- Re-sync if the settings lib swaps profiles or reloads the file underneath
-- us. Reapply cfg -> S so the panel reflects what's actually on disk.
settings.register('settings', 'settings_update', function(new_cfg)
    if new_cfg ~= nil then cfg = new_cfg end
    apply_cfg_to_S()
    if type(load_tod_from_cfg) == 'function' then load_tod_from_cfg() end
end)

local ui_visible  = { true }
local prev_visible = true

-- Scan cache. Rebuilt at most once per second; ImGui reads this every frame.
local scan_cache = {}
local last_scan_at = 0
local SCAN_INTERVAL = 1.0

-- Alert edge tracking. Maps server-side entity index -> true if the entity
-- was in the last scan. An entity alerts when it transitions from absent to
-- present. When it drops out of the scan we forget it, so re-appearance
-- alerts again. Keys are the entity table index (i), which is stable per
-- spawn slot for as long as the entity exists.
local seen_gm     = {}
local seen_target = {}

local current_player_name = ''

-- Player world position (read every frame from GetPlayerEntity().Movement
-- .LocalPosition -- same non-invasive read the Position tab uses in
-- ffxi_pos_tool). Kept as a table with a valid flag so ImGui can render
-- "unknown" gracefully during zone / cutscene / cs load.
local player_pos = { x = 0.0, y = 0.0, z = 0.0, valid = false }

----------------------------------------------------------------------------------------------------
-- Chat / logging helpers
----------------------------------------------------------------------------------------------------

-- Chat-log ONLY output. `print` in Ashita writes to the client's chat log
-- without touching the command parser, so there is zero risk of leaking as
-- /say, /tell, /party, /linkshell, or anything else the server sees. This
-- is the same pattern bovinefh uses for its status messages.
local function note(msg)
    print(string.format('\31\200[bscan]\30\01 %s', msg))
end

----------------------------------------------------------------------------------------------------
-- Sound
----------------------------------------------------------------------------------------------------

-- Fire-and-forget WAV playback via Ashita's native play_sound (Windows
-- PlaySound API, async). Same pattern as bovinefh.play_alert: check the
-- file exists first so a missing file doesn't beep the Windows default.
-- Force backslashes, guarantee trailing separator.
local function play_wav(name)
    local base = addon.path
    local last = base:sub(-1)
    if last ~= '/' and last ~= '\\' then base = base .. '\\' end
    local path = (base .. name):gsub('/', '\\')
    local f = io.open(path, 'rb')
    if not f then
        note('[sound] MISSING file: ' .. path)
        return
    end
    f:close()
    pcall(function() ashita.misc.play_sound(path) end)
end

----------------------------------------------------------------------------------------------------
-- Name helpers
----------------------------------------------------------------------------------------------------

-- Strip trailing NULs from InputText buffers and lowercase, for
-- case-insensitive substring compare.
local function clean_lower(s)
    if s == nil then return '' end
    s = tostring(s):gsub('%z+$', ''):gsub('^%s+', ''):gsub('%s+$', '')
    return s:lower()
end

local function clean(s)
    if s == nil then return '' end
    return (tostring(s):gsub('%z+$', ''):gsub('^%s+', ''):gsub('%s+$', ''))
end

-- Whole-name match with whitespace and case sanitization. Returns true if
-- `needle` (user's Mob Name input) is the whole entity name after both are
-- normalized: all whitespace removed, lowercased. It's the WHOLE name --
-- not a substring, not a word inside the name.
--
--    "Bi"            does NOT match "Bigclaw"
--    "Big"           does NOT match "Big Claw"
--    "Claw"          does NOT match "Big Claw"
--    "BigClaw"       matches       "Big Claw"    (whitespace collapsed)
--    "big claw"      matches       "BigClaw"     (whitespace + case)
--    "bigClaw"       matches       "Big Claw"    (whitespace + case)
--    "BIGCLAW"       matches       "Bigclaw"     (case)
--    "Gigas Warwolf" matches       "GigasWarwolf"
--
-- Trailing NULs from the InputText buffer are stripped. All ASCII whitespace
-- (space, tab, newline) inside the strings is removed before compare.
local function name_matches(needle, name)
    if needle == nil or name == nil then return false end
    -- Strip NULs first (InputText buffer padding), then remove ALL whitespace,
    -- then lowercase. %s covers space/tab/newline/CR/vertical-tab/form-feed.
    local n = tostring(needle):gsub('%z+$', ''):gsub('%s+', ''):lower()
    if n == '' then return false end
    local h = tostring(name):gsub('%s+', ''):lower()
    return n == h
end

-- --- Input validation ---------------------------------------------------
-- Two modes: NAME and HEX. Each has its own character rules. Used to color
-- the input text in the UI and to gate matching -- if input is invalid for
-- the currently selected mode, no matches fire.
--
-- Valid HEX: pure [0-9A-Fa-f] with an optional 0x / 0X / # prefix.
-- Valid NAME: letters, spaces, apostrophes, hyphens, question marks,
--             periods. No digits, no other symbols. Empty is neutral (not
--             validated as either).

local function trim_input(s)
    if s == nil then return '' end
    return (tostring(s):gsub('%z+$', ''):gsub('^%s+', ''):gsub('%s+$', ''))
end

local function is_valid_hex(s)
    local t = trim_input(s):gsub('%s+', '')
    if t == '' then return false end
    local body = t:gsub('^0x', ''):gsub('^0X', ''):gsub('^#', '')
    if body == '' then return false end
    return body:match('^[0-9A-Fa-f]+$') ~= nil
end

-- Allowed name character set: letters, space, apostrophe, hyphen, question
-- mark, period. Explicit whitelist because these are ~real FFXI mob-name
-- characters, and everything else (digits, brackets, backslashes, etc)
-- is almost certainly a user error rather than a real mob name.
local function is_valid_name(s)
    local t = trim_input(s)
    if t == '' then return false end
    return t:match("^[%a %-%'%?%.]+$") ~= nil
end

-- Mode-aware entity matcher. `mode_hex` is true for HEX matching, false for
-- NAME. Returns false on invalid input for the selected mode (so a hex
-- input in name mode never accidentally matches, and vice versa).
local function entity_matches_mode(needle, entity, mode_hex)
    if needle == nil or entity == nil then return false end
    local n = trim_input(needle)
    if n == '' then return false end
    if mode_hex then
        if not is_valid_hex(n) then return false end
        local body = n:gsub('%s+', ''):gsub('^0x', ''):gsub('^0X', ''):gsub('^#', '')
        local wanted = tonumber(body, 16)
        return wanted and entity.idx == wanted
    else
        if not is_valid_name(n) then return false end
        return name_matches(needle, entity.name)
    end
end

-- Back-compat: old auto-detect matcher. Preserved because ToD and older
-- callers still use it, and the auto behavior is fine as a fallback --
-- but new callers should prefer entity_matches_mode with an explicit mode.
local function entity_matches(needle, entity)
    if needle == nil or entity == nil then return false end
    local n = tostring(needle):gsub('%z+$', ''):gsub('%s+', '')
    if n == '' then return false end
    local n_id = n:gsub('^0x', ''):gsub('^0X', ''):gsub('^#', '')
    if n_id:match('^[0-9A-Fa-f]+$') then
        local wanted = tonumber(n_id, 16)
        if wanted and entity.idx == wanted then return true end
        return false
    end
    return name_matches(needle, entity.name)
end

----------------------------------------------------------------------------------------------------
-- Compass / direction
----------------------------------------------------------------------------------------------------
--
-- Raw axis convention. This matches FFXI's actual world coordinate frame
-- (confirmed via Ashita Movement.LocalPosition and cross-checked against
-- Windower / Pendant Compass docs):
--   +X = East,   -X = West     (positive X grows to the east)
--   +Z = South,  -Z = North    (positive Z grows to the south -- FFXI is
--                               left-handed compared to a naive "Z is up
--                               and north" assumption)
-- Y is vertical, ignored for compass. Distance is planar (X/Z only) --
-- height difference isn't useful for "run this way".
--
-- Angle is measured CLOCKWISE from north in degrees:
--   0 = N, 90 = E, 180 = S, 270 = W.
-- To get "clockwise from north" from Ashita's (X east+, Z south+) frame,
-- north is the -Z direction. Bearing = atan2(dx_east, -dz_south) so that
-- 0rad points north (dx=0, -dz>0) and grows toward east (dx>0). This is
-- the sign flip that used to be wrong -- a mob truly SW of the player was
-- reading as NW because I had assumed +Z was north.
--
-- Wedges are NOT even 45deg. Cardinals are narrow, intercardinals fill the
-- rest. This means a mob only reads as "N" when it's actually close to due
-- north -- 10 degrees off in either direction. Something 30 degrees off is
-- honestly "NE", not "N", so you don't get sent walking due north for a mob
-- that's really a bit east:
--
--    N:  350 -  10  (20deg total, +/- 10 around 0)
--    NE:  10 -  80  (70deg)
--    E:   80 - 100  (20deg, +/- 10 around 90)
--    SE: 100 - 170  (70deg)
--    S:  170 - 190  (20deg, +/- 10 around 180)
--    SW: 190 - 260  (70deg)
--    W:  260 - 280  (20deg, +/- 10 around 270)
--    NW: 280 - 350  (70deg)
--
-- Total: 4 cardinals * 20 + 4 intercardinals * 70 = 80 + 280 = 360. Checks out.
--
-- Returns direction string ("NE") and planar distance in yalms. Only returns
-- '--' when a position is genuinely missing (mid-zone / entity spawning).
--
-- Player is 0,0. Mob is at (dx, dz) relative to player. dx east-positive,
-- dz south-positive. Direction picked by looking at the two numbers:
--
--   Signs pick the quadrant:  dx>0 = east side, dz>0 = south side.
--   Ratio picks whether it's a cardinal or an intercardinal:
--     |dz| much smaller than |dx|  -> pure E or W
--     |dx| much smaller than |dz|  -> pure N or S
--     otherwise                    -> the four-way diagonal
--
-- Threshold for "much smaller": the ratio of the smaller axis to the larger
-- one has to be under tan(10 deg) = 0.1763 for it to count as cardinal.
-- That matches the +/- 10 deg cardinal wedge spec.
local function compass_direction(from_x, from_z, to_x, to_z)
    if from_x == nil or from_z == nil or to_x == nil or to_z == nil then
        return '--', 0.0
    end
    local dx = to_x - from_x   -- +east, -west
    local dz = to_z - from_z   -- +south, -north  (FFXI axes)
    local dist = math.sqrt(dx * dx + dz * dz)

    local ax = math.abs(dx)
    local az = math.abs(dz)
    -- Wedge spec: measure slope angle from the dominant axis (0-90 range).
    --   0-20   -> cardinal (E/W/N/S)      20 deg tolerance
    --   20-70  -> intercardinal (NE/SE/SW/NW)   50 deg wedge
    --   70-90  -> the other cardinal
    -- tan(20) = 0.3640. If the smaller axis over the bigger axis is under
    -- this, the mob reads as pure cardinal on the bigger axis.
    local CARDINAL_RATIO = 0.3640

    local dir
    if ax == 0 and az == 0 then
        -- Same spot exactly. Shouldn't happen in practice (you and a mob
        -- can't occupy the exact same point), but bail cleanly if it does.
        dir = '--'
    elseif ax >= az then
        -- East-west dominates. Cardinal E or W if the north-south piece
        -- is tiny, otherwise a diagonal that leans E or W.
        -- Sign convention (empirically confirmed against user's screenshots):
        --   dx>0 = east, dx<0 = west
        --   dz>0 = NORTH, dz<0 = south  (Ashita's Z in this build is
        --                                north-positive, not south-positive)
        if az / ax < CARDINAL_RATIO then
            dir = (dx > 0) and 'E' or 'W'
        else
            if dx > 0 then
                dir = (dz > 0) and 'NE' or 'SE'
            else
                dir = (dz > 0) and 'NW' or 'SW'
            end
        end
    else
        -- North-south dominates.
        if ax / az < CARDINAL_RATIO then
            dir = (dz > 0) and 'N' or 'S'
        else
            if dz > 0 then
                dir = (dx > 0) and 'NE' or 'NW'
            else
                dir = (dx > 0) and 'SE' or 'SW'
            end
        end
    end
    return dir, dist
end


----------------------------------------------------------------------------------------------------
-- Widescan + Placeholder tracker (PLACEHOLDER SKELETON, DISABLED)
----------------------------------------------------------------------------------------------------
--
-- ALL of the code in this section is skeleton. Every function is gated on
-- S.widescan[1], which is forced false at load and cannot be turned on
-- from the UI. Nothing here sends or receives packets. It exists so the
-- shape is set up correctly for when widescan is turned on.
--
-- Behavior when eventually enabled:
--   1. Watch the entity list for the mob named in S.ph_name[1] (placeholder).
--   2. When the PH disappears from the list, note the timestamp.
--   3. Wait S.ph_respawn_s[1] seconds AFTER the PH disappeared.
--   4. Then start sending widescan request packets every 3-6s (uniform
--      random). Widescan gives longer-than-40y range for BST/RNG/PUP main.
--   5. Parse incoming widescan track entries. Any hit whose name matches
--      S.mob_name[1] (using the same name_matches whole-name rule) fires
--      the normal target alert with direction + distance from widescan
--      coordinates.
--   6. Stop widescan requests as soon as the PH reappears in the entity
--      list (i.e. the PH respawned as the PH, not as the target). Reset
--      the timer state.
--
-- KNOWN UNKNOWNS on HorizonXI (needs confirmation before enabling):
--   - Widescan outgoing packet id and format. Retail is 0x0F4 with a mode
--     byte. HorizonXI *probably* matches retail here, but confirm.
--   - Widescan incoming per-entry packet: retail 0x0F4 (server->client)
--     with TargetIndex u16, X s16, Z s16, Level, NameId. No Y. Confirm
--     HorizonXI ships the same layout.
--   - Whether HorizonXI has any anti-automation detection on widescan
--     spam. 3-6s uniform is human-plausible but a bot cadence.
--   - Whether the ability is job-locked at the packet level or only at
--     the UI level (i.e. can we send the packet on non-BST/RNG/PUP jobs
--     and get results back).
--
-- Design uses the same non-invasive-read pattern as the rest of the addon
-- for parsing. For sending, we would use AshitaCore:GetPacketManager()
-- :AddOutgoingPacket -- SAME api bovinefh already uses for fishing packets
-- and the sell-all flow, so precedent is set and safe.

-- --- PH-tracker state. Two independent PH slots (ph1/ph2). Each has its
-- own present/disappeared/window state so they don't interfere. Widescan
-- itself is disabled; the state machine still runs and drives the local
-- 40-50y scan (via process_alerts, which the user gets for free) and the
-- ToD timestamps. When widescan is turned on later it'll bolt onto the
-- ws_active_since flag on either slot.
local ph_state = {
    ph1 = {
        present_last     = false,
        disappeared_at   = nil,
        ws_active_since  = nil,
    },
    ph2 = {
        present_last     = false,
        disappeared_at   = nil,
        ws_active_since  = nil,
    },
    -- Widescan send cadence -- unused while widescan disabled but kept so
    -- the request-cadence code below has somewhere to write.
    ws_last_sent_at  = 0,
    ws_next_send_at  = 0,
    -- Widescan hits parsed from incoming packets: idx -> { name, x, z, seen_at }
    hits = {},
}

-- One slot's tick. Called for each ph_state.ph1 / ph_state.ph2 with its
-- current name string, hex-mode flag, and the fresh entity list.
local function ph_slot_tick(slot, name, hex_mode, entities)
    local n = trim_input(name)
    if n == '' then
        -- Slot unused. Clear any lingering state so re-enabling later starts
        -- fresh -- otherwise a stale window could re-open on re-add.
        slot.present_last    = false
        slot.disappeared_at  = nil
        slot.ws_active_since = nil
        return
    end
    -- Validate the input for the chosen mode. If it's junk, treat the slot
    -- as unused for this tick (no alerts, no window). The UI will color the
    -- input red so the user sees why.
    if hex_mode and not is_valid_hex(n) then return end
    if (not hex_mode) and not is_valid_name(n) then return end

    -- Is the PH visible in the fresh scan?
    local here = false
    for _, en in ipairs(entities) do
        if en.kind ~= 'Self' and en.kind ~= 'PC' and en.kind ~= 'GM' then
            if entity_matches_mode(n, en, hex_mode) then
                here = true
                break
            end
        end
    end

    local now = os.clock()
    if here then
        -- PH visible: cancel any pending window.
        slot.disappeared_at  = nil
        slot.ws_active_since = nil
    else
        -- PH not visible.
        if slot.present_last then
            -- Edge: PH just disappeared. Start the respawn timer.
            slot.disappeared_at = now
        end
        -- If the respawn timer has elapsed, open the window. (Widescan is
        -- disabled, so this flag currently just says "we've been waiting
        -- long enough that the PH could realistically be back." The normal
        -- local scan continues either way -- if the PH walks into 40-50y,
        -- the alerts and ToD pick it up.)
        if slot.disappeared_at
           and (now - slot.disappeared_at) >= (S.ph_respawn_s[1] or 900)
           and not slot.ws_active_since then
            slot.ws_active_since = now
        end
    end
    slot.present_last = here
end

-- Top-level PH tracker. Runs each scan tick. LIVE now -- runs regardless
-- of the widescan checkbox. The widescan checkbox only gates the packet
-- send (see ws_send_request below), not the state machine.
local function ph_tracker_tick(entities)
    ph_slot_tick(ph_state.ph1, S.ph1_name[1], S.ph1_hex[1], entities)
    ph_slot_tick(ph_state.ph2, S.ph2_name[1], S.ph2_hex[1], entities)
end

-- Would send an outgoing widescan request packet. DISABLED.
local function ws_send_request()
    if not S.widescan[1] then return end   -- PLACEHOLDER: never runs

    -- ==== NOT YET IMPLEMENTED ====
    -- Expected shape (retail, needs HorizonXI confirmation):
    --   Packet id: 0x0F4
    --   Size: 4 bytes
    --   Body: mode byte (0 = start tracking, 1 = /widescan command?)
    --
    -- local packet = struct.pack('bbxx', 0xF4, 0x01)   -- guess
    -- local arr = {}; for i = 1, #packet do arr[i] = packet:byte(i) end
    -- AshitaCore:GetPacketManager():AddOutgoingPacket(0x0F4, arr)
    -- ph_state.ws_last_sent_at = os.clock()
    -- ph_state.ws_next_send_at = os.clock() + 3.0 + math.random() * 3.0
end

-- Would parse a widescan track entry packet from the server. DISABLED.
local function ws_parse_incoming(e)
    if not S.widescan[1] then return end   -- PLACEHOLDER: never runs

    -- ==== NOT YET IMPLEMENTED ====
    -- Retail 0x0F4 incoming layout (needs HorizonXI confirmation):
    --   +0x04  u16   TargetIndex
    --   +0x06  s16   X (world coord)
    --   +0x08  s16   Z (world coord)
    --   +0x0A  u8    Level
    --   +0x0B  u8    Flags (0x20 = end-of-list marker?)
    --   +0x0C  u32   NameId (resolves via resource manager)
end

-- Called from d3d_present between scans. Drives the request cadence.
-- DISABLED (still gated on S.widescan).
local function ws_cadence_tick()
    if not S.widescan[1] then return end   -- PLACEHOLDER: never runs
    -- Either slot with an open window would trigger sends.
    local active = ph_state.ph1.ws_active_since or ph_state.ph2.ws_active_since
    if not active then return end
    local now = os.clock()
    if now >= ph_state.ws_next_send_at then
        ws_send_request()
    end
end

----------------------------------------------------------------------------------------------------
-- Entity scan
----------------------------------------------------------------------------------------------------

-- Iterate the entity table and classify each visible entity. Directly
-- lifted from bovinefh.state.scan_entities -- proven pattern.
--
--   Render flag bits: 0x200 visible, 0x4000 hidden. Skip anything not
--   visible or explicitly hidden -- those are unrendered array slots.
--
--   GM detection: RenderFlags2 & 0x1000. Confirmed via 4-way flag capture,
--   matches XIUI partylist. Use bit.band (NOT math.floor / division) --
--   RenderFlags2 with 0x80000000 set comes back negative in Lua and breaks
--   arithmetic-based tests.
--
--   Type from SpawnFlags: 0x01 player, 0x02 NPC, 0x10 mob. Own character
--   is tagged 'Self' so it never counts as another player.
--
--   Distance is stored squared -- sqrt for yalms.
local function scan_entities()
    local out = {}
    local RF_VISIBLE, RF_HIDDEN = 0x200, 0x4000
    local ok_em, em = pcall(function() return AshitaCore:GetMemoryManager():GetEntity() end)
    if not ok_em or em == nil then return out end

    local self_name = clean_lower(current_player_name)

    for i = 1, 2303 do
        local ok, ent = pcall(function() return GetEntity(i) end)
        if ok and ent ~= nil and ent.Name ~= nil and ent.Name ~= '' then
            local flags = select(2, pcall(function() return em:GetRenderFlags0(i) end)) or 0
            local visible = bit.band(flags, RF_VISIBLE) ~= 0
            local hidden  = bit.band(flags, RF_HIDDEN) ~= 0
            if visible and not hidden then
                local nm = tostring(ent.Name)
                local f2 = select(2, pcall(function() return em:GetRenderFlags2(i) end)) or 0
                local is_gm = bit.band(f2, 0x1000) ~= 0
                local sf = ent.SpawnFlags or 0

                local kind
                if self_name ~= '' and clean_lower(nm) == self_name then
                    kind = 'Self'
                elseif is_gm then
                    -- Split GM vs GMDev: XIUI's convention is that GMDev is
                    -- flagged by an additional bit in the same RenderFlags2.
                    -- The 0x1000 test above catches both classes; without a
                    -- confirmed second-bit for the Dev subclass we tag them
                    -- all as GM. Add the Dev bit here if you have it.
                    kind = 'GM'
                elseif bit.band(sf, 0x01) ~= 0 then
                    kind = 'PC'
                elseif bit.band(sf, 0x10) ~= 0 then
                    kind = 'MOB'
                elseif bit.band(sf, 0x02) ~= 0 then
                    kind = 'NPC'
                else
                    kind = '?'
                end

                local dist = nil
                if ent.Distance ~= nil and ent.Distance > 0 then
                    dist = math.sqrt(ent.Distance)
                end

                -- World position for the compass helper. Same non-invasive
                -- read as GetPlayerEntity uses -- Movement.LocalPosition on
                -- the entity struct. Guarded because Movement can be nil on
                -- entities mid-spawn or in cutscene state.
                --
                -- CRITICAL: In FFXI's position_t struct the horizontal axes
                -- are X and Y. Z is the VERTICAL (height) axis. Confusingly,
                -- the struct field order in memory is X, Z, Y -- but the
                -- Lua wrapper exposes them by name, so ent.Movement
                -- .LocalPosition.Y is the horizontal north-south. Reading
                -- .Z gives you height, which barely varies as you walk
                -- around, and totally breaks direction math.
                local ex, ey = nil, nil
                if ent.Movement and ent.Movement.LocalPosition then
                    ex = tonumber(ent.Movement.LocalPosition.X)
                    ey = tonumber(ent.Movement.LocalPosition.Y)
                end

                -- ServerId is the full 32-bit server-assigned id. Wiki
                -- references like "Placeholder's ID is 17B" are the low 12
                -- bits of this -- same as the entity's TargetIndex, which
                -- IS the loop index `i`. So we surface both: idx (hex) for
                -- matching wiki mob IDs, ServerId for anyone who needs the
                -- full identifier.
                local sid = tonumber(ent.ServerId) or 0

                -- HP percent for ToD confirmed-vs-missing detection. If
                -- absent, tod treats it as unknown (never confirmed).
                local hpp = tonumber(ent.HPPercent)

                out[#out+1] = {
                    idx      = i,       -- TargetIndex, matches wiki hex ids
                    name     = nm,
                    kind     = kind,
                    dist     = dist,
                    x        = ex,      -- horizontal east-west (east positive)
                    y        = ey,      -- horizontal north-south (see below)
                    serverid = sid,
                    hpp      = hpp,
                }
            end
        end
    end

    -- Sort: GMs first (safety), then target-name matches, then by distance.
    -- Target-match sort is done during draw since it depends on the mob-name
    -- input; here just do GM -> everyone else -> nearer-first within group.
    local rank = { GM = 1, PC = 2, MOB = 3, NPC = 4, Self = 5, ['?'] = 6 }
    table.sort(out, function(a, b)
        if rank[a.kind] ~= rank[b.kind] then return rank[a.kind] < rank[b.kind] end
        return (a.dist or 1e9) < (b.dist or 1e9)
    end)
    return out
end

----------------------------------------------------------------------------------------------------
-- Alert edge detection
----------------------------------------------------------------------------------------------------

-- Given the fresh scan, fire alerts for entities that JUST appeared. An
-- entity is "just appeared" if its index is in the new scan but wasn't in
-- the last one. When an entity drops out of the scan its seen-flag is
-- cleared, so if it comes back later it alerts again -- exactly the "once
-- on appear, again after leaving" rule.
--
-- GM alerts:    always fire when tracker is enabled, regardless of the
--               Play Alert checkbox. If tracker is off, no alerts at all
--               (spec: "If Enable Tracker is off, GM alerts are suppressed").
-- Target alerts: gated by Play Alert checkbox.
local function process_alerts(entities)
    if not S.enabled[1] then
        -- Tracker off: clear seen sets so re-enabling re-alerts on
        -- whatever's currently in the list.
        seen_gm     = {}
        seen_target = {}
        return
    end

    local target = clean_lower(S.mob_name[1])
    local new_gm, new_target = {}, {}
    local gm_fired, target_fired = false, false

    -- Snapshot player pos once for all direction calcs this tick. Use X and
    -- Y (the horizontal pair). Z is height and does not belong in a compass.
    local px = player_pos.valid and player_pos.x or nil
    local py = player_pos.valid and player_pos.y or nil

    -- Format a "go NE 5y" suffix for TARGET alerts. You want to walk to
    -- these, so you need the direction. Always prints a direction when both
    -- positions are known; sub-yalm distances use %.1f so nothing rounds
    -- to "0y" and looks broken.
    local function bearing_suffix(en)
        if px == nil or en.x == nil or en.y == nil then return '' end
        local dir, d = compass_direction(px, py, en.x, en.y)
        return string.format(' - go %s %.1fy', dir, d)
    end

    -- Format a distance-only suffix for GM alerts. You do NOT want to walk
    -- to a GM -- direction is useless here, distance is the warning. Just
    -- "GM appeared 12y" so you know how close the eyes are.
    local function distance_suffix(en)
        if px == nil or en.x == nil or en.y == nil then return '' end
        local _, d = compass_direction(px, py, en.x, en.y)
        return string.format(' - %.1fy away', d)
    end

    for _, en in ipairs(entities) do
        if en.kind == 'GM' then
            new_gm[en.idx] = true
            if not seen_gm[en.idx] and not gm_fired then
                note(string.format('[GM] %s appeared%s',
                    clean(en.name), distance_suffix(en)))
                play_wav('alert.wav')
                gm_fired = true   -- one sound per scan is enough even if 2 GMs land
            end
        end
        -- Target match test: whole-name, case-insensitive. Skip if empty
        -- input, skip Self, skip GMs (GMs already alerted above with their
        -- own path -- avoid double-firing). Uses mob_hex to pick match mode:
        -- Hex = exact TargetIndex, Name = whole-name match.
        if target ~= '' and en.kind ~= 'Self' and en.kind ~= 'GM' then
            if entity_matches_mode(target, en, S.mob_hex[1]) then
                new_target[en.idx] = true
                if not seen_target[en.idx] and not target_fired and S.play_alert[1] then
                    note(string.format('[TARGET] %s appeared%s',
                        clean(en.name), bearing_suffix(en)))
                    play_wav('alert.wav')
                    target_fired = true
                end
            end
        end
    end

    seen_gm     = new_gm
    seen_target = new_target
end

----------------------------------------------------------------------------------------------------
-- Time of Death tracker
----------------------------------------------------------------------------------------------------
--
-- Tracks disappearance of any entity whose name/id matches the Mob Name or
-- PH Name field. Two death states:
--
--   confirmed  -- we saw HPPercent hit 0 before the entity dropped out of
--                 the scan. Reliable, means the mob was actually killed.
--   missing    -- the entity went from scan to no-scan without an HP=0
--                 sighting. Could be killed off-screen, could've depopped,
--                 could've walked out of range. Not reliable.
--
-- HP tracking is per-server-id: we cache last-seen HPPercent for every
-- entity in the last scan, and check against the fresh scan each tick to
-- catch drops. When an entity disappears we look at its last cached HP
-- and record accordingly.

local TOD_MAX = 50   -- cap on log length; oldest drop off
-- tracked entities in the last scan: idx -> { name, hpp, matched_by }
-- matched_by is 'target' or 'ph' -- which field caught it (informational).
local prev_tracked = {}
-- ToD entries look like:
--   { name, idx, kind, at, status, matched_by }
--   at = os.time() timestamp (unix seconds; ok in Lua os.time())
-- Held live in `tod_entries` here, mirrored into cfg.tod_log on save.
local tod_entries = {}

-- Called once at addon load to hydrate tod_entries from disk. cfg.tod_log
-- is a T{} table; copy its contents into tod_entries (regular Lua table).
local function load_tod_from_cfg()
    tod_entries = {}
    if type(cfg.tod_log) == 'table' then
        for _, e in ipairs(cfg.tod_log) do
            if type(e) == 'table' and e.name and e.at then
                tod_entries[#tod_entries+1] = {
                    name       = tostring(e.name),
                    idx        = tonumber(e.idx) or 0,
                    kind       = tostring(e.kind or 'MOB'),
                    at         = tonumber(e.at) or 0,
                    status     = tostring(e.status or 'missing'),
                    matched_by = tostring(e.matched_by or 'target'),
                }
            end
        end
    end
end

-- Called from save_cfg to serialize tod_entries back into cfg.tod_log.
-- We rebuild the T{} table so the settings lib writes clean JSON.
local function sync_tod_to_cfg()
    local out = T { }
    for i = 1, #tod_entries do
        local e = tod_entries[i]
        out[#out+1] = T {
            name       = e.name,
            idx        = e.idx,
            kind       = e.kind,
            at         = e.at,
            status     = e.status,
            matched_by = e.matched_by,
        }
    end
    cfg.tod_log = out
end

-- Latest-only insert. If an entry with this idx already exists in the log,
-- overwrite it in-place with the new death; otherwise insert at the front.
-- Trims to TOD_MAX (cap essentially never hits with unique-per-idx). Nudges
-- the debounced saver.
local function tod_record(entry)
    for i, e in ipairs(tod_entries) do
        if e.idx == entry.idx then
            tod_entries[i] = entry     -- overwrite the older death
            cfg_dirty_at = os.clock()
            return
        end
    end
    table.insert(tod_entries, 1, entry)
    while #tod_entries > TOD_MAX do
        tod_entries[#tod_entries] = nil
    end
    cfg_dirty_at = os.clock()
end

-- Called every scan tick with the fresh entity list. Diffs against
-- prev_tracked to detect disappearance; consults last-seen HPP to decide
-- confirmed vs missing.
local function process_tod(entities)
    -- Which fields are we watching this tick? Both are optional. If both
    -- are empty, nothing gets tracked at all -- ToD is a targeted feature,
    -- not a firehose of every mob death.
    local target = (S.mob_name[1] or ''):gsub('%z+$', '')
    local ph1    = (S.ph1_name[1] or ''):gsub('%z+$', '')
    local ph2    = (S.ph2_name[1] or ''):gsub('%z+$', '')
    if target == '' and ph1 == '' and ph2 == '' then
        prev_tracked = {}
        return
    end

    -- Build fresh-tracked map for entities currently in scan that match
    -- any of the three fields. Skip Self / PC / GM.
    local fresh = {}
    for _, en in ipairs(entities) do
        if en.kind ~= 'Self' and en.kind ~= 'PC' and en.kind ~= 'GM' then
            local matched_by = nil
            if target ~= '' and entity_matches_mode(target, en, S.mob_hex[1]) then
                matched_by = 'target'
            elseif ph1 ~= '' and entity_matches_mode(ph1, en, S.ph1_hex[1]) then
                matched_by = 'ph1'
            elseif ph2 ~= '' and entity_matches_mode(ph2, en, S.ph2_hex[1]) then
                matched_by = 'ph2'
            end
            if matched_by then
                fresh[en.idx] = {
                    name       = en.name,
                    idx        = en.idx,
                    kind       = en.kind,
                    hpp        = en.hpp,
                    matched_by = matched_by,
                }
            end
        end
    end

    -- For everything that WAS tracked last tick but is NOT in the fresh
    -- set, record a ToD. Use the LAST-CACHED HPP (from prev_tracked) to
    -- decide confirmed vs missing.
    local now = os.time()
    for idx, prev in pairs(prev_tracked) do
        if fresh[idx] == nil then
            local status = 'missing'
            if prev.hpp ~= nil and prev.hpp == 0 then
                status = 'confirmed'
            end
            tod_record({
                name       = prev.name,
                idx        = prev.idx,
                kind       = prev.kind,
                at         = now,
                status     = status,
                matched_by = prev.matched_by,
            })
        end
    end

    prev_tracked = fresh
end

----------------------------------------------------------------------------------------------------
-- ImGui render
----------------------------------------------------------------------------------------------------

-- Row colors. GMs red, target-name matches green, players yellow-ish,
-- everything else default-ish.
local COL_GM     = { 1.00, 0.30, 0.30, 1.0 }
local COL_TARGET = { 0.45, 0.90, 0.45, 1.0 }
local COL_PC     = { 0.95, 0.85, 0.35, 1.0 }
local COL_MOB    = { 0.80, 0.80, 0.85, 1.0 }
local COL_NPC    = { 0.60, 0.70, 0.85, 1.0 }
local COL_SELF   = { 0.50, 0.75, 0.95, 1.0 }
local COL_DIM    = { 0.55, 0.55, 0.60, 1.0 }

local function draw()
    if not ui_visible[1] then return end

    -- Theme (matches bovinefh / bovinebattle aesthetic). Push BEFORE Begin
    -- and pop AFTER End so counts always balance regardless of return path.
    imgui.SetNextWindowSizeConstraints({ 260, 0 }, { 100000, 100000 })
    imgui.PushStyleVar(ImGuiStyleVar_WindowRounding,   8.0)
    imgui.PushStyleVar(ImGuiStyleVar_FrameRounding,    5.0)
    imgui.PushStyleVar(ImGuiStyleVar_ChildRounding,    6.0)
    imgui.PushStyleVar(ImGuiStyleVar_PopupRounding,    5.0)
    imgui.PushStyleVar(ImGuiStyleVar_GrabRounding,     4.0)
    imgui.PushStyleVar(ImGuiStyleVar_FramePadding,     { 7, 4 })
    imgui.PushStyleVar(ImGuiStyleVar_WindowBorderSize, 1.0)
    imgui.PushStyleColor(ImGuiCol_WindowBg,       { 0.07, 0.07, 0.09, 0.95 })
    imgui.PushStyleColor(ImGuiCol_Border,         { 0.30, 0.32, 0.40, 0.60 })
    imgui.PushStyleColor(ImGuiCol_FrameBg,        { 0.16, 0.17, 0.21, 1.0 })
    imgui.PushStyleColor(ImGuiCol_FrameBgHovered, { 0.22, 0.24, 0.30, 1.0 })
    imgui.PushStyleColor(ImGuiCol_FrameBgActive,  { 0.28, 0.30, 0.38, 1.0 })
    imgui.PushStyleColor(ImGuiCol_Header,         { 0.20, 0.22, 0.28, 1.0 })
    imgui.PushStyleColor(ImGuiCol_HeaderHovered,  { 0.28, 0.31, 0.40, 1.0 })
    imgui.PushStyleColor(ImGuiCol_HeaderActive,   { 0.34, 0.37, 0.48, 1.0 })
    imgui.PushStyleColor(ImGuiCol_CheckMark,      { 0.45, 0.85, 0.50, 1.0 })
    imgui.PushStyleColor(ImGuiCol_Separator,      { 0.30, 0.32, 0.40, 0.50 })
    imgui.PushStyleColor(ImGuiCol_Text,           { 0.92, 0.92, 0.94, 1.0 })

    if imgui.Begin(ADDON_NAME, ui_visible, ImGuiWindowFlags_None) then
        -- --- Controls
        imgui.Checkbox('Enable Tracker', S.enabled)
        imgui.SameLine()
        imgui.Checkbox('Play Alert', S.play_alert)
        imgui.SameLine()
        imgui.Checkbox('Debug', S.debug)

        -- --- AutoClaim. Sits directly above widescan. This is the only
        -- control in the scanner that SENDS anything, so it is off by
        -- default and the opener is an explicit choice.
        imgui.Checkbox('AutoClaim', S.autoclaim)
        if S.autoclaim[1] then
            imgui.SameLine()
            imgui.RadioButton('/ra##ac', S.autoclaim_mode, 0)
            imgui.SameLine()
            imgui.RadioButton('/provoke##ac', S.autoclaim_mode, 1)
            imgui.SameLine()
            imgui.RadioButton('/dia##ac', S.autoclaim_mode, 2)
            imgui.SameLine()
            imgui.RadioButton('/attack##ac', S.autoclaim_mode, 3)
        end

        -- --- Widescan placeholder. The widescan PACKET SEND is disabled
        -- and the checkbox stays locked. PH tracking itself is LIVE (runs
        -- the state machine off local 40-50y scan; ToD picks up disappears).
        imgui.TextDisabled('[X] Enable Widescan  (Currently Not Available)')

        imgui.Separator()

        -- --- Match-mode radio helper. Draws "( ) Name  ( ) Hex" bound to
        -- a bool bracket (false=name, true=hex). RadioButton returns true
        -- on click of the matching option; we then flip the flag ourselves.
        local function match_mode_radio(id, flag)
            local is_name = not flag[1]
            local is_hex  = flag[1]
            if imgui.RadioButton('Name##' .. id, is_name) then
                flag[1] = false
            end
            imgui.SameLine()
            if imgui.RadioButton('Hex##'  .. id, is_hex) then
                flag[1] = true
            end
        end

        -- --- Input row helper. Draws:
        --   Label:  [_____input_____]  ( ) Name  ( ) Hex
        -- Colors the label based on validation for the currently selected
        -- mode: green = valid hex (hex mode), blue = valid name (name mode),
        -- red = invalid for the selected mode, dim = empty (no judgment).
        -- Hover tooltip on the label explains the invalid case.
        local COL_VAL_HEX  = { 0.45, 0.90, 0.45, 1.0 }   -- green
        local COL_VAL_NAME = { 0.50, 0.75, 0.95, 1.0 }   -- blue
        local COL_VAL_BAD  = { 1.00, 0.30, 0.30, 1.0 }   -- red
        local function input_row(id, label, buf, hex_flag, input_width)
            local raw = trim_input(buf[1])
            local col, tip
            if raw == '' then
                col, tip = COL_DIM, nil
            elseif hex_flag[1] then
                if is_valid_hex(raw) then
                    col, tip = COL_VAL_HEX,
                        'Valid hex id. Matches TargetIndex directly.'
                else
                    col, tip = COL_VAL_BAD,
                        'Invalid hex: use 0-9 and A-F only (optional 0x or # prefix).'
                end
            else
                if is_valid_name(raw) then
                    col, tip = COL_VAL_NAME,
                        'Valid name. Matches the entity name (whole match, whitespace/case ignored).'
                else
                    col, tip = COL_VAL_BAD,
                        'Invalid name: only letters, spaces, apostrophes, hyphens, question marks, and periods allowed.'
                end
            end
            imgui.TextColored(col, label)
            if tip and imgui.IsItemHovered() then imgui.SetTooltip(tip) end
            imgui.SameLine()
            imgui.PushItemWidth(input_width or 180)
            imgui.InputText('##' .. id, buf, 128)
            imgui.PopItemWidth()
            imgui.SameLine()
            match_mode_radio(id, hex_flag)
        end

        input_row('mobname', 'Mob Name:  ', S.mob_name, S.mob_hex, 180)
        input_row('ph1name', 'PH Name 1: ', S.ph1_name, S.ph1_hex, 180)
        input_row('ph2name', 'PH Name 2: ', S.ph2_name, S.ph2_hex, 180)

        -- --- Respawn timer. InputInt binds to a Lua number table.
        imgui.TextColored(COL_DIM, 'Respawn (s):')
        imgui.SameLine()
        imgui.PushItemWidth(120)
        imgui.InputInt('##phrespawn', S.ph_respawn_s, 30, 300)
        imgui.PopItemWidth()
        if S.ph_respawn_s[1] < 0 then S.ph_respawn_s[1] = 0 end

        imgui.Separator()

        -- --- Player position (raw axis: +Z=N -Z=S +X=E -X=W).
        if player_pos.valid then
            imgui.TextColored(COL_DIM,
                string.format('pos: X %.1f  Y %.1f  Z %.1f',
                              player_pos.x, player_pos.y, player_pos.z))
        else
            imgui.TextColored(COL_DIM, 'pos: (unknown)')
        end

        -- --- Counters
        local total, gm_ct, pc_ct, mob_ct = #scan_cache, 0, 0, 0
        for _, en in ipairs(scan_cache) do
            if en.kind == 'GM'  then gm_ct  = gm_ct  + 1
            elseif en.kind == 'PC'  then pc_ct  = pc_ct  + 1
            elseif en.kind == 'MOB' then mob_ct = mob_ct + 1 end
        end
        imgui.TextColored(COL_DIM,
            string.format('entities: %d   GMs: %d   PCs: %d   MOBs: %d',
                          total, gm_ct, pc_ct, mob_ct))

        -- --- PH slot status. Only shown if the corresponding slot has a
        -- valid input. Three states per slot:
        --   "present"           -- PH visible in current scan
        --   "waiting Xm Ys"     -- PH gone, respawn timer ticking
        --   "window open"       -- respawn timer elapsed; keep watching
        local function fmt_slot(label, slot, name, hex_flag)
            local n = trim_input(name)
            if n == '' then return nil end
            local valid = hex_flag[1] and is_valid_hex(n) or is_valid_name(n)
            if not valid then return nil end
            if slot.present_last then
                return string.format('%s: present', label), COL_TARGET
            end
            if slot.ws_active_since then
                return string.format('%s: window open', label), COL_TARGET
            end
            if slot.disappeared_at then
                local remaining = math.max(0,
                    (S.ph_respawn_s[1] or 900) - (os.clock() - slot.disappeared_at))
                local mm = math.floor(remaining / 60)
                local ss = math.floor(remaining % 60)
                return string.format('%s: waiting %dm%02ds', label, mm, ss), COL_PC
            end
            return string.format('%s: not yet seen', label), COL_DIM
        end
        local s1, c1 = fmt_slot('PH1', ph_state.ph1, S.ph1_name[1], S.ph1_hex)
        local s2, c2 = fmt_slot('PH2', ph_state.ph2, S.ph2_name[1], S.ph2_hex)
        if s1 then imgui.TextColored(c1, s1) end
        if s2 then imgui.TextColored(c2, s2) end

        imgui.Separator()

        -- --- Scrollable entity list
        local target = clean_lower(S.mob_name[1])
        -- Fixed-height child so the panel doesn't grow endlessly with zone
        -- population. 320px shows ~18 rows at default font.
        imgui.BeginChild('bscan_list', { 0, 320 }, true, ImGuiWindowFlags_None)
        if #scan_cache == 0 then
            imgui.TextColored(COL_DIM, '(no entities)')
        else
            local px = player_pos.valid and player_pos.x or nil
            local py = player_pos.valid and player_pos.y or nil
            for _, en in ipairs(scan_cache) do
                local is_target = (target ~= ''
                                   and en.kind ~= 'Self'
                                   and en.kind ~= 'GM'
                                   and entity_matches(target, en))
                local col
                if     en.kind == 'GM'   then col = COL_GM
                elseif is_target         then col = COL_TARGET
                elseif en.kind == 'PC'   then col = COL_PC
                elseif en.kind == 'MOB'  then col = COL_MOB
                elseif en.kind == 'NPC'  then col = COL_NPC
                elseif en.kind == 'Self' then col = COL_SELF
                else                          col = COL_DIM end

                local dist_str = en.dist and string.format('%5.1fy', en.dist) or '  ?  '
                -- Direction column: 2-char compass label (e.g. "NE") or "--"
                -- when either side of the fix is missing. Self row gets no
                -- direction -- you can't be a direction from yourself.
                local dir_str = '--'
                local dbg_str = ''
                if en.kind ~= 'Self' and px and en.x and en.y then
                    local d = compass_direction(px, py, en.x, en.y)
                    dir_str = d
                    -- Debug tail (only when Debug checkbox is on): show BOTH
                    -- sides of the subtraction so we can see where dx/dy
                    -- came from. Y is horizontal north-south -- the second
                    -- horizontal axis. Z would be height and we intentionally
                    -- ignore it for compass math.
                    if S.debug[1] then
                        dbg_str = string.format(
                            '   me(%.1f,%.1f) mob(%.1f,%.1f) dx=%+6.1f dy=%+6.1f',
                            px, py, en.x, en.y, en.x - px, en.y - py)
                    end
                end
                -- Hex id column. This is the entity's TargetIndex, which
                -- matches the wiki-cited hex IDs (e.g. Leaping Lizzy's PH
                -- is 17B, Leaping Lizzy is 17C in South Gustaberg). Useful
                -- for identifying PH vs NM when names are shared, generic
                -- ("???"), or spoofed.
                local hex_str = string.format('%03X', en.idx)
                local tag = '[' .. en.kind .. ']'
                imgui.TextColored(col,
                    string.format('%-7s %s %-3s %s   %s%s',
                                  tag, hex_str, dir_str, dist_str,
                                  clean(en.name), dbg_str))
            end
        end
        imgui.EndChild()

        imgui.Separator()
        imgui.TextColored(COL_DIM, 'GM alerts fire while Enable Tracker is on.')
        imgui.TextColored(COL_DIM, 'Target alerts also require Play Alert.')

        -- --- Time of Death log
        --
        -- Collapsible header. Shows tracked mob deaths with relative time
        -- ago and an absolute HH:MM:SS timestamp. Only records deaths of
        -- entities whose name/id matches the Mob Name or PH Name field --
        -- so an unset Mob Name means an empty log, which is fine.
        --
        -- Confirmed = we saw HP hit 0 before it dropped from scan (reliable).
        -- Missing   = it just vanished (killed off-screen, depopped, walked
        --             out of range -- can't tell which).
        imgui.Separator()
        if imgui.CollapsingHeader(string.format('Time of Death (%d)',
                                                 #tod_entries)) then
            if #tod_entries == 0 then
                imgui.TextColored(COL_DIM,
                    '(no deaths recorded; set Mob Name or PH Name to track)')
            else
                if imgui.Button('Clear ToD log') then
                    tod_entries = {}
                    cfg_dirty_at = os.clock()
                end
                imgui.BeginChild('bscan_tod', { 0, 200 }, true,
                                 ImGuiWindowFlags_None)
                local now = os.time()
                for _, e in ipairs(tod_entries) do
                    -- Relative time. seconds -> minutes -> hours -> days.
                    local secs = math.max(0, now - (e.at or 0))
                    local rel
                    if     secs < 60      then rel = string.format('%ds ago',   secs)
                    elseif secs < 3600    then rel = string.format('%dmin ago', math.floor(secs / 60))
                    elseif secs < 86400   then rel = string.format('%dh ago',   math.floor(secs / 3600))
                    else                       rel = string.format('%dd ago',   math.floor(secs / 86400))
                    end
                    local ts = os.date('%H:%M:%S', e.at)
                    local status_col = (e.status == 'confirmed')
                        and COL_TARGET or COL_MOB
                    imgui.TextColored(status_col,
                        string.format('%-24s (%03X)  died %-12s (%s)  [%s]',
                                      clean(e.name):sub(1, 24),
                                      e.idx or 0,
                                      rel, ts,
                                      e.status or 'missing'))
                end
                imgui.EndChild()
            end
        end
    end
    imgui.End()
    imgui.PopStyleColor(11)
    imgui.PopStyleVar(7)
end

----------------------------------------------------------------------------------------------------
-- Events
----------------------------------------------------------------------------------------------------

ashita.events.register('d3d_present', 'bscan_present', function()
    -- Capture our own name and world position from the local player entity.
    -- Movement.LocalPosition is Ashita v4's read-only accessor -- same one
    -- ffxi_pos_tool's Position tab uses. Read-only: we never write it back.
    local ok, p = pcall(GetPlayerEntity)
    if ok and p ~= nil then
        if p.Name and p.Name ~= '' then current_player_name = p.Name end
        local lp = p.Movement and p.Movement.LocalPosition
        if lp then
            local x = tonumber(lp.X)
            local y = tonumber(lp.Y)
            local z = tonumber(lp.Z)
            if x and y and z then
                player_pos.x, player_pos.y, player_pos.z = x, y, z
                player_pos.valid = true
            end
        end
    end

    -- Scan at most once per second. ImGui redraws every frame off the cache.
    local now = os.clock()
    if now - last_scan_at >= SCAN_INTERVAL then
        last_scan_at = now
        scan_cache = scan_entities()
        process_alerts(scan_cache)
        -- Placeholder tick: PH state machine (edge-detects the placeholder
        -- disappearing/reappearing). No-op while S.widescan is false.
        ph_tracker_tick(scan_cache)
        -- Time-of-death tracker: watches the Mob Name / PH Name targets
        -- for disappearance, records confirmed vs missing based on last
        -- seen HP percent.
        process_tod(scan_cache)
    end

    -- Placeholder cadence: run every frame (cheap; internal rate limit).
    -- No-op while S.widescan is false. Would send outgoing widescan requests
    -- once the PH respawn window has opened.
    ws_cadence_tick()

    draw()

    -- Debounced config auto-save. Baseline the signature on first tick, then
    -- write once the value has been stable for 0.75s -- covers InputText
    -- typing without hammering disk on every keystroke.
    local sig = cfg_signature()
    if last_cfg_sig == nil then
        last_cfg_sig = sig
    elseif sig ~= last_cfg_sig then
        last_cfg_sig = sig
        cfg_dirty_at = os.clock()
    elseif cfg_dirty_at > 0 and (os.clock() - cfg_dirty_at) > 0.75 then
        cfg_dirty_at = 0
        save_cfg()
    end

    -- X (or a /bovinescan that hides it) flipped ui_visible off. Treat that
    -- as unloading the whole addon, same as bovinefh.
    if prev_visible and not ui_visible[1] then
        AshitaCore:GetChatManager():QueueCommand(1, '/addon unload ' .. ADDON_NAME)
    end
    prev_visible = ui_visible[1]
end)

ashita.events.register('command', 'bscan_command', function(e)
    local cmd = e.command or ''
    local first = cmd:match('^%s*(%S+)')
    if first == nil or first:lower() ~= '/bovinescan' then return end
    e.blocked = true
    local sub = (cmd:match('^%s*%S+%s+(%S+)') or ''):lower()

    if sub == 'on' or sub == 'start' or sub == 'enable' then
        S.enabled[1] = true
        note('tracker ENABLED')
    elseif sub == 'off' or sub == 'stop' or sub == 'disable' then
        S.enabled[1] = false
        seen_gm, seen_target = {}, {}
        note('tracker DISABLED')
    else
        -- bare /bovinescan (or anything else): toggle panel visibility.
        ui_visible[1] = not ui_visible[1]
        note(ui_visible[1] and 'panel shown' or 'panel closed -> unloading')
    end
end)

ashita.events.register('load', 'bscan_load', function()
    load_tod_from_cfg()   -- hydrate the live ToD list from persisted config
    note('loaded. /bovinescan toggles the panel. /bovinescan on|off enables tracker.')
end)

-- --- PLACEHOLDER: widescan incoming packet hook. Registered but no-op --
-- ws_parse_incoming returns immediately while S.widescan is false. Keeping
-- the registration in place so the hook path is proven to fire when the
-- feature gets turned on later. Retail widescan is packet id 0x0F4; if
-- HorizonXI uses a different id, change the filter below.
ashita.events.register('packet_in', 'bscan_pkt_in', function(e)
    if not S.widescan[1] then return end   -- PLACEHOLDER: never runs
    if e.id ~= 0x0F4 then return end       -- widescan track packet (guess)
    ws_parse_incoming(e)
end)

ashita.events.register('unload', 'bscan_unload', function()
    -- Persist final config (also covers the window-X unload path). No other
    -- cleanup needed -- Ashita clears our event registrations automatically.
    save_cfg()
end)
--------------------------------------------------------------------------------
-- bovinetargetscan v0.3: READ-ONLY discovery of where the current target's
-- server_id is stored statically in FFXiMain.dll.
--
-- WHAT CHANGED FROM v0.2:
--   - Dropped MrArgus's entity layout (name@0x6C, code@0x64).  Those are
--     vanilla-FFXi-era offsets that don't match the modern Ashita SDK
--     entity struct.  All entity identity (name, server id) now comes from
--     Ashita's IEntity / ITarget / IPlayer / IParty APIs -- the API is the
--     ground truth, no guessing at field offsets.
--   - Scan target changed from "12-byte TARGETINFO struct" to "any u32 in
--     FFXiMain.dll matching target_server_id".  Server IDs are 32-bit
--     unique-per-session identifiers; coincidental matches are rare.  This
--     also avoids assuming the modern target struct keeps MrArgus's shape.
--
-- WHAT STAYS THE SAME:
--   - FFXiMain.dll base via GetModuleHandleA (ffi, safe Win32 call).
--   - Player entity pointer via *(base + 0x483DB0) -- verified by
--     ffxi_pos_tool's 3-zone write-test, kept only as a sanity printout.
--   - Memory reads via ashita.memory.read_uint32 (SEH-protected).
--   - Scan chunked across frames so the game stays responsive.
--
-- NO MEMORY WRITES.  NO PACKETS.  NO /target COMMANDS.  Pure observation.
--
-- Author: Cowrevenge + Claude
-- Version: 0.3
--------------------------------------------------------------------------------

addon.name      = 'bovinetargetscan'
addon.author    = 'Cowrevenge'
addon.version   = '0.15'
addon.desc      = 'Read-only discovery: find where target server_id lives statically.'

require('common')

local imgui = require('imgui')
local ffi   = require('ffi')

--------------------------------------------------------------------------------
-- Constants
--------------------------------------------------------------------------------

-- *(base + this) = current player entity pointer.  Verified offset from
-- ffxi_pos_tool's 3-zone write-test on HorizonXI -- the only raw FFXiMain
-- offset we use, and only for a printout / sanity check.
local OFFSET_PLAYER_ENTITY_PTR = 0x483DB0

-- Entity array stride: each entity record is exactly this many bytes.
-- Verified by ffxi_pos_tool (entity_ptr - source_addr = 0xA1C in both
-- Misareaux and Tavnazian).  Used to compute a target's entity pointer:
--   array_base = player_entity_ptr - player_idx * ENTITY_SIZE
--   target_ptr = array_base       + target_idx * ENTITY_SIZE
local ENTITY_SIZE              = 0xA1C

-- 16MB of FFXiMain to scan.  MrArgus's static offsets sat around 4MB; the
-- HorizonXI player_entity_ptr offset above is at ~4.5MB; 16MB is generous
-- without scanning the whole module.
local SCAN_BYTES               = 0x01000000

-- Lower / Upper halves let the user limit a scan to either half of the
-- 16MB window.  Confirmed target field at base+0x485CF0 is in the lower
-- half; upper-half candidates from earlier scans were likely mirrors or
-- coincidental hits and may be more dangerous to poke at.
local SCAN_LOWER_START         = 0x00000000
local SCAN_LOWER_END           = 0x00800000   -- 0..8MB
local SCAN_UPPER_START         = 0x00800000
local SCAN_UPPER_END           = 0x01000000   -- 8..16MB

-- u32 reads per d3d_present chunk.  ~10ms per frame at ~1us per read, well
-- inside a 60Hz frame budget.
local SCAN_STEP                = 10000

-- Heap address range (HorizonXI allocations).  A static u32 holding a value
-- in this window is treated as a candidate pointer into the heap.
local HEAP_LO                  = 0x00100000
local HEAP_HI                  = 0x80000000

-- DEEP pointer-chase: MrArgus's idea (static pointer -> heap struct -> target
-- field).  For each static u32 that holds a heap address H, we inspect the
-- first DEEP_STRUCT_WINDOW bytes of *H looking for the target's server_id or
-- entity pointer.  Window kept small (the target field sits early in such
-- structs, like MrArgus's +0x8) to bound the read cost.
local DEEP_STRUCT_WINDOW       = 0x40     -- 64 bytes = 16 u32 slots into *H
local DEEP_STEP                = 3000     -- outer static u32s per frame (deep)

-- Struct differ: how many bytes of the heap struct to snapshot/diff/replay.
-- Widened to 0x800 (2KB) to catch a master "have-target" flag that likely
-- sits further into the same target-manager structure than the descriptor
-- fields at +0x04/+0x08.  The flash-then-revert behaviour means such a flag
-- exists and we weren't writing it.
local STRUCT_DUMP_WINDOW       = 0x800    -- 2048 bytes = 512 u32 slots

-- Watch poll period (seconds)
local WATCH_POLL_SEC           = 0.25

--------------------------------------------------------------------------------
-- ffi: GetModuleHandleA to find FFXiMain.dll base
--------------------------------------------------------------------------------

ffi.cdef[[
typedef void* HMODULE;
HMODULE __stdcall GetModuleHandleA(const char* lpModuleName);
]]

local function find_ffximain_base()
    local h = ffi.C.GetModuleHandleA('FFXiMain.dll')
    if h == nil then return 0 end
    return tonumber(ffi.cast('uintptr_t', h))
end

--------------------------------------------------------------------------------
-- SEH-safe memory primitive
--------------------------------------------------------------------------------

local function safe_read_u32(addr)
    local ok, v = pcall(ashita.memory.read_uint32, addr)
    if ok then return v end
    return nil
end

-- SEH-safe single u32 write.  Used ONLY by the Test Target button, ONLY
-- after every guard below has passed:
--   * base resolved
--   * a candidate is being watched
--   * a non-zero snapshot exists
--   * the write address is inside FFXiMain (base..base+SCAN_UPPER_END)
-- The actual ashita.memory.write_uint32 call is pcall-wrapped so a bad
-- write throws a Lua error rather than killing the process.
local function safe_write_u32(addr, val)
    local ok, err = pcall(ashita.memory.write_uint32, addr, val)
    return ok, err
end

--------------------------------------------------------------------------------
-- API-based identity helpers (no raw entity field offsets, no guessing)
--
-- All four interfaces come from the same memory manager and are the
-- authoritative reflection of the game's current state.  We don't try to
-- duplicate them by reading entity fields directly.
--------------------------------------------------------------------------------

local function get_mem()
    return AshitaCore and AshitaCore:GetMemoryManager() or nil
end

local function api_player_index()
    local mem = get_mem()
    if not mem then return nil end
    local party = mem:GetParty()
    if not party then return nil end
    local ok, idx = pcall(function() return party:GetMemberTargetIndex(0) end)
    if not ok or not idx or idx == 0 then return nil end
    return idx
end

local function api_target_index()
    local mem = get_mem()
    if not mem then return nil end
    local target = mem:GetTarget()
    if not target then return nil end
    local ok, idx = pcall(function() return target:GetTargetIndex(0) end)
    if not ok or not idx or idx == 0 then return nil end
    return idx
end

local function api_target_server_id()
    local mem = get_mem()
    if not mem then return nil end
    local target = mem:GetTarget()
    if not target then return nil end
    local ok, sid = pcall(function() return target:GetServerId(0) end)
    if not ok or not sid or sid == 0 then return nil end
    return sid
end

local function api_entity_name(idx)
    if not idx then return nil end
    local mem = get_mem()
    if not mem then return nil end
    local ent = mem:GetEntity()
    if not ent then return nil end
    local ok, name = pcall(function() return ent:GetName(idx) end)
    if not ok or not name or name == '' then return nil end
    return name
end

local function api_entity_server_id(idx)
    if not idx then return nil end
    local mem = get_mem()
    if not mem then return nil end
    local ent = mem:GetEntity()
    if not ent then return nil end
    local ok, sid = pcall(function() return ent:GetServerId(idx) end)
    if not ok then return nil end
    return sid
end

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

local state = {
    base            = 0,
    window_visible  = { true },

    -- Scan state (async-chunked)
    scan            = nil,
    scan_status     = 'No scan run yet.  Target a mob and click [Start Scan].',
    candidates      = {},

    -- Watch state
    watch_idx       = 0,
    watch_next      = 0,
    watch_cached    = nil,

    -- Test Lock / Test Go state.
    -- test_lock is set by clicking [Test Lock] while a target exists.  It
    -- captures the locked-in test subject (server_id, idx, name) and is
    -- intentionally explicit -- no auto-update, no surprises.
    -- test_log holds the result of the most recent [Test Go] write.
    test_lock = nil,    -- { sid, idx, name, locked_at }
    test_log  = nil,

    -- Track state (Cheat-Engine-style iterative filter, in-addon, read-only).
    -- The render mirror at 0x485CF0 holds the target server_id but is
    -- downstream (visual only).  The action system almost certainly keys
    -- off the target's ENTITY INDEX, not its server_id.  Track hunts for
    -- static u32 fields holding the current target's index that survive
    -- across multiple retargets:
    --   [Track Start]  -- full static scan for current target index
    --   [Track Filter] -- retarget a different mob, narrow survivors
    --   (repeat Filter until the survivor count is small)
    --   [Track Promote]-- move survivors into the candidate list (kind=idx)
    -- Then Watch/Lock/Go/Dia each candidate to find the upstream field.
    track = nil,        -- { survivors = {off,...}, rounds, kind, last_value, last_name }
    track_status = 'Track: target a mob, click [Track Start].',

    -- Struct differ (for deep candidates): capture the heap struct window in
    -- two states -- no-target (A) and with-target (B) -- diff them to find the
    -- full set of fields the game coordinates when targeting, then replay all
    -- of them in one frame onto the cleared struct.  A single-field write only
    -- blinks because the game sees an inconsistent struct; writing the whole
    -- delta gives it a consistent one.
    diff = nil,         -- { base_addr, a={off->val}, b={off->val}, changed={{off,a,b}} }
    diff_status = 'Struct diff: watch a [deep] candidate to enable.',
}

-- Live status table.  Declared up here (before do_test_lock / do_test_go)
-- so those functions capture it as an upvalue at definition time.  Refresh
-- is done by refresh_live() further down.
local live = {
    player_ptr   = 0,
    player_idx   = nil,
    player_name  = '',
    player_sid   = 0,
    target_idx   = nil,
    target_name  = '',
    target_sid   = 0,
}

-- Compute an entity's base pointer from its index, using the live player
-- entity pointer and player index.  Returns nil if the player anchor isn't
-- readable.  The entity array is stable while in-zone, so this is valid for
-- any in-zone idx even after untargeting.  (This is the same value MrArgus's
-- TARGETINFO.dwCharPtr held -- the candidate the upstream target field may
-- store instead of an index or server_id.)
local function compute_entity_ptr(idx)
    if not idx then return nil end
    local pidx = live.player_idx
    local pptr = live.player_ptr
    if not pidx or not pptr or pptr == 0 then return nil end
    local array_base = pptr - pidx * ENTITY_SIZE
    local ptr = array_base + idx * ENTITY_SIZE
    if ptr < 0x00100000 or ptr > 0x80000000 then return nil end
    return ptr
end

--------------------------------------------------------------------------------
-- Async scan engine (chunked across frames so the game never freezes).
--
-- Three modes share one driver:
--   'sid_find'     -- walk [start_pos, end_pos), collect offsets whose u32
--                     equals the target server_id.  Produces sid candidates.
--                     (This is what found the render mirror at 0x485CF0.)
--   'track_init'   -- walk [start_pos, end_pos), collect offsets whose u32
--                     equals the target ENTITY INDEX.  Seeds track.survivors.
--   'track_filter' -- re-read an existing survivor offset list, keep only
--                     those whose u32 now equals the (new) target index.
--                     Narrows track.survivors across retargets.
--
-- Every read is ashita.memory.read_uint32 (SEH-safe).  No raw ffi reads.
--------------------------------------------------------------------------------

local function scan_init(target_server_id, target_idx, target_name, start_byte, end_byte)
    state.scan = {
        active        = true,
        mode          = 'sid_find',
        start_pos     = start_byte / 4,
        end_pos       = end_byte / 4,
        pos           = start_byte / 4,
        range_label   = ('0x%X..0x%X'):format(start_byte, end_byte),
        match_value   = target_server_id,
        target_sid    = target_server_id,
        target_idx    = target_idx,
        target_name   = target_name,
        results       = {},
        started_at    = os.clock(),
    }
    state.candidates = {}
    state.watch_idx  = 0
    state.watch_cached = nil
end

-- Track Start: full static scan for an arbitrary per-target value.
--   kind = 'idx' -> match_value is the target entity index
--   kind = 'ptr' -> match_value is the target entity pointer (heap addr)
local function track_scan_init(match_value, kind, target_name, start_byte, end_byte)
    state.scan = {
        active        = true,
        mode          = 'track_init',
        start_pos     = start_byte / 4,
        end_pos       = end_byte / 4,
        pos           = start_byte / 4,
        range_label   = ('0x%X..0x%X'):format(start_byte, end_byte),
        match_value   = match_value,
        track_kind    = kind,
        target_name   = target_name,
        results       = {},   -- plain integer offsets
        started_at    = os.clock(),
    }
end

-- Track Filter: re-scan an existing survivor list against a new value.
local function track_filter_init(survivors, match_value, kind, target_name)
    state.scan = {
        active        = true,
        mode          = 'track_filter',
        list          = survivors,
        list_pos      = 1,
        match_value   = match_value,
        track_kind    = kind,
        target_name   = target_name,
        results       = {},   -- plain integer offsets that still match
        started_at    = os.clock(),
    }
end

-- Format a tracked value for display based on its kind.
local function fmt_track_val(kind, v)
    if kind == 'idx' then return ('idx %d'):format(v) end
    return ('ptr 0x%X'):format(v)
end

-- DEEP Start: walk the static range; for each u32 that's a heap pointer H,
-- inspect *H[0..DEEP_STRUCT_WINDOW) for the target server_id or entity ptr.
-- Survivors are richer entries: { p_off, k, mk } where mk is 'sid' or 'ptr'.
local function deep_scan_init(target_sid, target_ptr, target_name, start_byte, end_byte)
    state.scan = {
        active        = true,
        mode          = 'deep_init',
        start_pos     = start_byte / 4,
        end_pos       = end_byte / 4,
        pos           = start_byte / 4,
        range_label   = ('0x%X..0x%X'):format(start_byte, end_byte),
        deep_sid      = target_sid,
        deep_ptr      = target_ptr or 0,
        target_name   = target_name,
        results       = {},   -- list of { p_off, k, mk }
        started_at    = os.clock(),
    }
end

-- DEEP Filter: re-check an existing survivor list against a new target.
local function deep_filter_init(survivors, target_sid, target_ptr, target_name)
    state.scan = {
        active        = true,
        mode          = 'deep_filter',
        list          = survivors,
        list_pos      = 1,
        deep_sid      = target_sid,
        deep_ptr      = target_ptr or 0,
        target_name   = target_name,
        results       = {},
        started_at    = os.clock(),
    }
end

local function scan_finalize(s, was_cancelled)
    if s.mode == 'sid_find' then
        table.sort(s.results, function(a, b) return a.static_off < b.static_off end)
        state.candidates = s.results
        if was_cancelled then
            local total = s.end_pos - s.start_pos
            local done  = s.pos - s.start_pos
            local pct   = (total > 0) and math.floor(done * 100 / total) or 0
            state.scan_status = ('Cancelled at %d%% of %s.  %d partial candidate(s).'):format(
                pct, s.range_label, #s.results)
        else
            state.scan_status = ('Scan done in %.2fs (%s).  %d candidate(s) for sid 0x%X "%s".'):format(
                os.clock() - s.started_at, s.range_label, #s.results,
                s.target_sid, s.target_name or '?')
        end

    elseif s.mode == 'track_init' then
        table.sort(s.results, function(a, b) return a < b end)
        state.track = {
            survivors  = s.results,
            rounds     = 1,
            kind       = s.track_kind,
            last_value = s.match_value,
            last_name  = s.target_name,
        }
        local vstr = fmt_track_val(s.track_kind, s.match_value)
        if was_cancelled then
            state.track_status = ('Track Start cancelled.  %d partial hit(s) for %s.'):format(
                #s.results, vstr)
        else
            state.track_status = ('Track Start: %d hit(s) for %s "%s".  Now target a DIFFERENT mob and click [Track Filter].'):format(
                #s.results, vstr, s.target_name or '?')
        end

    elseif s.mode == 'deep_init' then
        state.track = {
            survivors  = s.results,   -- list of { p_off, k, mk }
            rounds     = 1,
            kind       = 'deep',
            last_sid   = s.deep_sid,
            last_ptr   = s.deep_ptr,
            last_name  = s.target_name,
        }
        if was_cancelled then
            state.track_status = ('Deep Start cancelled.  %d partial path(s).'):format(#s.results)
        else
            state.track_status = ('Deep Start: %d path(s) holding sid 0x%X / ptr 0x%X for "%s".  Target a DIFFERENT mob and click [Track Filter].'):format(
                #s.results, s.deep_sid or 0, s.deep_ptr or 0, s.target_name or '?')
        end

    elseif s.mode == 'deep_filter' then
        if state.track then
            state.track.survivors = s.results
            state.track.rounds    = (state.track.rounds or 1) + 1
            state.track.last_sid  = s.deep_sid
            state.track.last_ptr  = s.deep_ptr
            state.track.last_name = s.target_name
        end
        local r = state.track and state.track.rounds or '?'
        state.track_status = ('Deep Filter (round %s): %d survivor(s) tracking "%s".'):format(
            tostring(r), #s.results, s.target_name or '?')
    end

    s.active = false
end

local function scan_step()
    local s = state.scan
    if not s or not s.active then return end

    local base        = state.base
    local match_value = s.match_value

    if s.mode == 'track_filter' then
        -- Re-read a slice of the survivor list this frame.
        local list     = s.list
        local n        = #list
        local pos       = s.list_pos
        local stop_at   = math.min(pos + SCAN_STEP, n + 1)
        local results   = s.results
        for k = pos, stop_at - 1 do
            local off = list[k]
            local val = safe_read_u32(base + off)
            if val == match_value then
                results[#results + 1] = off
            end
        end
        s.list_pos = stop_at
        if s.list_pos > n then
            scan_finalize(s, false)
        else
            state.track_status = ('Track Filter... %d/%d checked (%d kept) for %s'):format(
                s.list_pos - 1, n, #results, fmt_track_val(s.track_kind, match_value))
        end
        return
    end

    if s.mode == 'deep_filter' then
        -- Re-check a slice of the pointer-chase survivor list.
        local list     = s.list
        local n        = #list
        local pos      = s.list_pos
        local stop_at  = math.min(pos + SCAN_STEP, n + 1)
        local results  = s.results
        local sid      = s.deep_sid
        local ptr      = s.deep_ptr
        for k = pos, stop_at - 1 do
            local e = list[k]
            local H = safe_read_u32(base + e.p_off)
            if H and H >= HEAP_LO and H <= HEAP_HI then
                local v = safe_read_u32(H + e.k)
                local want = (e.mk == 'sid') and sid or ptr
                if v == want then
                    results[#results + 1] = e
                end
            end
        end
        s.list_pos = stop_at
        if s.list_pos > n then
            scan_finalize(s, false)
        else
            state.track_status = ('Deep Filter... %d/%d checked (%d kept)'):format(
                s.list_pos - 1, n, #results)
        end
        return
    end

    -- Range modes: sid_find and track_init
    local pos     = s.pos
    local stop_at = math.min(pos + SCAN_STEP, s.end_pos)
    local results = s.results

    if s.mode == 'deep_init' then
        -- Pointer-chase: smaller outer step (each heap pointer triggers a
        -- window of inner reads).
        stop_at = math.min(s.pos + DEEP_STEP, s.end_pos)
        local sid = s.deep_sid
        local ptr = s.deep_ptr
        for i = s.pos, stop_at - 1 do
            local P = safe_read_u32(base + i * 4)
            if P and P >= HEAP_LO and P <= HEAP_HI then
                local k = 0
                while k < DEEP_STRUCT_WINDOW do
                    local v = safe_read_u32(P + k)
                    if v == sid then
                        results[#results + 1] = { p_off = i * 4, k = k, mk = 'sid' }
                    elseif ptr ~= 0 and v == ptr then
                        results[#results + 1] = { p_off = i * 4, k = k, mk = 'ptr' }
                    end
                    k = k + 4
                end
            end
        end
        s.pos = stop_at
        if s.pos >= s.end_pos then
            scan_finalize(s, false)
        else
            local total = s.end_pos - s.start_pos
            local done  = s.pos - s.start_pos
            local pct   = math.floor(done * 100 / total)
            state.track_status = ('Deep Start scanning %s... %d%%  (%d hits)'):format(
                s.range_label, pct, #results)
        end
        return
    end

    if s.mode == 'sid_find' then
        for i = pos, stop_at - 1 do
            local val = safe_read_u32(base + i * 4)
            if val == match_value then
                results[#results + 1] = { static_off = i * 4, seen_at = val, kind = 'sid' }
            end
        end
    else -- track_init: collect plain offsets
        for i = pos, stop_at - 1 do
            local val = safe_read_u32(base + i * 4)
            if val == match_value then
                results[#results + 1] = i * 4
            end
        end
    end

    s.pos = stop_at
    if s.pos >= s.end_pos then
        scan_finalize(s, false)
    else
        local total = s.end_pos - s.start_pos
        local done  = s.pos - s.start_pos
        local pct   = math.floor(done * 100 / total)
        if s.mode == 'sid_find' then
            state.scan_status = ('Scanning %s... %d%%  (%d hits for sid 0x%X)'):format(
                s.range_label, pct, #results, match_value)
        else
            state.track_status = ('Track Start scanning %s... %d%%  (%d hits for %s)'):format(
                s.range_label, pct, #results, fmt_track_val(s.track_kind, match_value))
        end
    end
end

local function scan_cancel()
    local s = state.scan
    if s and s.active then scan_finalize(s, true) end
end

local function scan_is_active()
    return state.scan ~= nil and state.scan.active == true
end

--------------------------------------------------------------------------------
-- Button actions
--------------------------------------------------------------------------------

-- Shared scan kickoff -- gets the current target's server_id from the API
-- and starts a chunked scan over the given byte range.
local function start_scan_in_range(start_byte, end_byte)
    if scan_is_active() then return end

    if state.base == 0 then
        state.scan_status = 'FFXiMain base not resolved.'
        return
    end

    local target_idx = api_target_index()
    if not target_idx then
        state.scan_status = 'No target -- click a mob first.'
        return
    end
    local target_sid = api_target_server_id()
    if not target_sid then
        state.scan_status = 'Target has no server_id (NPC?).  Try a real mob.'
        return
    end
    local target_name = api_entity_name(target_idx) or '?'

    scan_init(target_sid, target_idx, target_name, start_byte, end_byte)
end

local function do_scan_lower()
    start_scan_in_range(SCAN_LOWER_START, SCAN_LOWER_END)
end

local function do_scan_upper()
    start_scan_in_range(SCAN_UPPER_START, SCAN_UPPER_END)
end

--------------------------------------------------------------------------------
-- Track actions -- now a DEEP pointer-chase (MrArgus's IDEA, not his offsets).
--
-- Flat scanning for the target index (0x485CEC) and server_id (0x485CF0)
-- found only downstream render mirrors; scanning for the target entity
-- pointer found nothing static.  So the field the game actually reads lives
-- in a HEAP structure reached through a static pointer -- exactly MrArgus's
-- shape: *(static_ptr) -> heap struct -> target field at some offset.
--
-- Deep Start walks the static range; for every u32 that's a heap pointer H,
-- it inspects *H[0..0x40) for the target's server_id or entity pointer.
-- Survivors are (static_ptr_offset, struct_offset, match_kind) paths.
-- Deep Filter narrows them across retargets.  Promote turns them into
-- 'deep' candidates that Watch/Go follow through the pointer.
--------------------------------------------------------------------------------

local function do_track_start(start_byte, end_byte)
    if scan_is_active() then return end
    if state.base == 0 then
        state.track_status = 'FFXiMain base not resolved.'
        return
    end
    local target_idx = api_target_index()
    if not target_idx then
        state.track_status = 'No target -- target a mob first, then [Track Lower/Upper].'
        return
    end
    local target_sid = api_target_server_id()
    if not target_sid then
        state.track_status = 'Target has no server_id.  Try a real mob.'
        return
    end
    local tptr = compute_entity_ptr(target_idx)   -- may be nil; deep still uses sid
    local target_name = api_entity_name(target_idx) or '?'
    deep_scan_init(target_sid, tptr, target_name, start_byte, end_byte)
end

-- Deep scan range wrappers (mirror the sid Scan Lower / Scan Upper split).
-- All six earlier deep candidates sat in the lower half (offsets < 0x800000),
-- so Track Lower finds them at half the cost.  Upper is there if needed.
local function do_track_lower()
    do_track_start(SCAN_LOWER_START, SCAN_LOWER_END)
end

local function do_track_upper()
    do_track_start(SCAN_UPPER_START, SCAN_UPPER_END)
end

local function do_track_filter()
    if scan_is_active() then return end
    if not state.track or not state.track.survivors then
        state.track_status = 'Nothing to filter.  Click [Track Start] first.'
        return
    end
    local target_idx = api_target_index()
    if not target_idx then
        state.track_status = 'No target -- target a DIFFERENT mob, then [Track Filter].'
        return
    end
    local target_sid = api_target_server_id()
    if not target_sid then
        state.track_status = 'Target has no server_id.  Try a real mob.'
        return
    end
    if target_sid == (state.track.last_sid or 0) then
        state.track_status = 'Same target as last capture.  Target a DIFFERENT mob to filter.'
        return
    end
    local tptr = compute_entity_ptr(target_idx)
    local target_name = api_entity_name(target_idx) or '?'
    deep_filter_init(state.track.survivors, target_sid, tptr, target_name)
end

local function do_track_promote()
    if not state.track or not state.track.survivors or #state.track.survivors == 0 then
        state.track_status = 'No survivors to promote.'
        return
    end
    local cands = {}
    for _, e in ipairs(state.track.survivors) do
        cands[#cands + 1] = {
            kind       = 'deep',
            p_off      = e.p_off,
            struct_off = e.k,
            match_kind = e.mk,         -- 'sid' or 'ptr'
            seen_at    = (e.mk == 'sid') and (state.track.last_sid or 0)
                                          or (state.track.last_ptr or 0),
        }
    end
    state.candidates   = cands
    state.watch_idx    = 0
    state.watch_cached = nil
    state.scan_status  = ('Promoted %d deep pointer-path candidate(s).  Watch each, then Lock/Go/Dia.'):format(#cands)
    state.track_status = ('Promoted %d survivor(s) to candidate list.'):format(#cands)
end

local function do_track_clear()
    state.track = nil
    state.track_status = 'Track cleared.  Target a mob, click [Track Start].'
end

--------------------------------------------------------------------------------
-- Struct differ (deep candidates only).
--
-- Snap A (no target)  -> capture struct window in the cleared state
-- Snap B (with target)-> capture struct window in the acquired state, diff
-- Write Delta (no tgt)-> replay every changed field onto the cleared struct
--                        in one frame, so the game sees a consistent acquired
--                        struct instead of a single inconsistent field.
--
-- All writes go through safe_write_u32 (the single write primitive).
--------------------------------------------------------------------------------

local function read_struct_window(H, window)
    local out = {}
    local off = 0
    while off < window do
        out[off] = safe_read_u32(H + off) or 0
        off = off + 4
    end
    return out
end

-- Returns the watched candidate if it's a deep candidate, else nil + sets status.
local function diff_get_deep_candidate()
    if state.watch_idx == 0 then
        state.diff_status = 'Watch a [deep] candidate first.'
        return nil
    end
    local c = state.candidates[state.watch_idx]
    if not c or c.kind ~= 'deep' then
        state.diff_status = 'Struct diff works on a [deep] candidate.  Watch one.'
        return nil
    end
    return c
end

local function do_diff_snap_a()
    local c = diff_get_deep_candidate()
    if not c then return end
    if live.target_idx then
        state.diff_status = 'Snap A is the NO-TARGET state.  Untarget first, then [Snap A].'
        return
    end
    local H = safe_read_u32(state.base + c.p_off)
    if not H or H < HEAP_LO or H > HEAP_HI then
        state.diff_status = 'Deep pointer not valid right now.'
        return
    end
    state.diff = {
        base_addr = H,
        a         = read_struct_window(H, STRUCT_DUMP_WINDOW),
        b         = nil,
        changed   = {},
    }
    state.diff_status = ('Snap A (no target) captured @ 0x%X.  Now TARGET the mob and click [Snap B].'):format(H)
end

local function do_diff_snap_b()
    local c = diff_get_deep_candidate()
    if not c then return end
    if not live.target_idx then
        state.diff_status = 'Snap B is the WITH-TARGET state.  Target the mob first, then [Snap B].'
        return
    end
    if not state.diff or not state.diff.a then
        state.diff_status = 'Capture [Snap A] (no target) first.'
        return
    end
    local H = safe_read_u32(state.base + c.p_off)
    if not H or H < HEAP_LO or H > HEAP_HI then
        state.diff_status = 'Deep pointer not valid right now.'
        return
    end
    if H ~= state.diff.base_addr then
        state.diff_status = ('Struct moved (0x%X -> 0x%X).  Recapture [Snap A].'):format(state.diff.base_addr, H)
        state.diff.a = nil
        return
    end
    state.diff.b = read_struct_window(H, STRUCT_DUMP_WINDOW)

    local changed = {}
    local off = 0
    while off < STRUCT_DUMP_WINDOW do
        local av = state.diff.a[off]
        local bv = state.diff.b[off]
        if av ~= bv then
            changed[#changed + 1] = { off = off, a = av, b = bv }
        end
        off = off + 4
    end
    state.diff.changed = changed
    state.diff_status = ('Snap B captured.  %d field(s) change when targeting.  UNTARGET, then [Write Delta].'):format(#changed)
end

local function do_diff_write()
    local c = diff_get_deep_candidate()
    if not c then return end
    if live.target_idx then
        state.diff_status = 'Untarget first -- Write Delta replays the acquired state onto the cleared struct.'
        return
    end
    if not state.diff or not state.diff.changed or #state.diff.changed == 0 then
        state.diff_status = 'No diff yet.  Do [Snap A] then [Snap B] first.'
        return
    end
    local H = safe_read_u32(state.base + c.p_off)
    if not H or H < HEAP_LO or H > HEAP_HI then
        state.diff_status = 'Deep pointer not valid right now.'
        return
    end
    if H ~= state.diff.base_addr then
        state.diff_status = ('Struct moved since capture (0x%X -> 0x%X).  Recapture.'):format(state.diff.base_addr, H)
        return
    end

    local wrote, failed = 0, 0
    for _, e in ipairs(state.diff.changed) do
        local ok = safe_write_u32(H + e.off, e.b)
        if ok then wrote = wrote + 1 else failed = failed + 1 end
    end
    state.diff_status = ('Wrote %d field(s) (%d failed) to struct 0x%X.  Watch for arrow + target box.'):format(
        wrote, failed, H)
end

local function do_diff_clear()
    state.diff = nil
    state.diff_status = 'Struct diff cleared.'
end

--------------------------------------------------------------------------------
-- SetTarget -- MrArgus's mechanism, this client's measured layout.
--
-- MrArgus's idea (preserved):
--   dwAddr = *(modbase + OFFSET_TARGETINFO)   -- deref a static pointer to the
--                                                target descriptor struct
--   write the WHOLE descriptor at dwAddr in one shot (not one field -- that's
--   why every single-field write only blinked).
--
-- This client's layout (measured by the struct differ, Snap A vs Snap B):
--   +0x04 : entity index      (changes on target)
--   +0x08 : server_id         (changes on target)
--   +0x00 : unchanged on target -> left alone
-- MrArgus's old {code,code,charPtr} layout was for a different client and does
-- not apply here.
--
-- A watched DEEP candidate hands us dwAddr directly: dwAddr = *(base+c.p_off),
-- because c.p_off IS this build's OFFSET_TARGETINFO.  Identity (idx, sid) comes
-- from Test Lock, captured via the API so it's always valid.
--------------------------------------------------------------------------------

-- Descriptor layout, MEASURED via the struct differ on this HorizonXI build
-- (Snap A vs Snap B showed exactly these two fields change on target):
--   +0x04 : entity index   (e.g. 161)
--   +0x08 : server_id      (e.g. 0x010AE0A1)
-- +0x00 did NOT change on target, so we leave it alone.  This replaces
-- MrArgus's old {code,code,charPtr}@{+0,+4,+8} layout, which was for a
-- different client.  MrArgus's *mechanism* (deref static ptr -> write the
-- whole descriptor at once) is preserved; only the field map is updated.
local DESC_INDEX_OFF = 0x04
local DESC_SID_OFF   = 0x08

local function do_mrargus_set()
    state.test_log = nil

    if state.base == 0 then
        state.test_log = { ok = false, msg = 'FFXiMain base not resolved.' }
        return
    end
    if state.watch_idx == 0 then
        state.test_log = { ok = false, msg = 'Watch a [deep] candidate first.' }
        return
    end
    local c = state.candidates[state.watch_idx]
    if not c or c.kind ~= 'deep' then
        state.test_log = { ok = false, msg = 'SetTarget needs a [deep] candidate (its p_off = OFFSET_TARGETINFO).' }
        return
    end
    local lock = state.test_lock
    if not lock or not lock.sid or lock.sid == 0 then
        state.test_log = { ok = false, msg = 'No lock.  Target a mob, click [Test Lock] first.' }
        return
    end
    if not lock.idx or lock.idx == 0 then
        state.test_log = { ok = false, msg = 'Lock has no entity index.' }
        return
    end
    if live.target_idx then
        state.test_log = { ok = false, msg = 'Untarget first (the game would fight the write).' }
        return
    end

    -- dwAddr = *(base + p_off)  -- MrArgus's deref: the descriptor struct
    local dwAddr = safe_read_u32(state.base + c.p_off)
    if not dwAddr or dwAddr < HEAP_LO or dwAddr > HEAP_HI then
        state.test_log = { ok = false,
            msg = ('Descriptor pointer at base+0x%X invalid (0x%X).'):format(c.p_off, dwAddr or 0) }
        return
    end

    -- Write the WHOLE descriptor MrArgus-style, but with the measured layout:
    -- index at +0x04, server_id at +0x08, in one shot, consistent pair.
    local ok_idx = safe_write_u32(dwAddr + DESC_INDEX_OFF, lock.idx)
    local ok_sid = safe_write_u32(dwAddr + DESC_SID_OFF,   lock.sid)

    local nok = (ok_idx and 1 or 0) + (ok_sid and 1 or 0)

    state.test_log = {
        ok   = (nok == 2),
        msg  = ('SetTarget -> struct 0x%X: +0x04 idx=%d, +0x08 sid=0x%X  (%d/2 writes ok).  Watch for arrow + name.'):format(
                  dwAddr, lock.idx, lock.sid, nok),
        addr = dwAddr,
    }
end

-- SetTarget ALL: write the consistent {index, sid} pair into EVERY promoted
-- deep candidate in one frame.  If all six are mirrors of the same target
-- state, this sets whichever one the game actually reads AND leaves none
-- inconsistent to revert us.  Each candidate gets sid at its own struct_off
-- (where the scan found the sid) and index at struct_off-0x04 (the field
-- right before it, which the differ showed holds the index).
local function do_mrargus_set_all()
    state.test_log = nil

    if state.base == 0 then
        state.test_log = { ok = false, msg = 'FFXiMain base not resolved.' }
        return
    end
    local lock = state.test_lock
    if not lock or not lock.sid or lock.sid == 0 or not lock.idx or lock.idx == 0 then
        state.test_log = { ok = false, msg = 'No lock.  Target a mob, click [Test Lock] first.' }
        return
    end
    if live.target_idx then
        state.test_log = { ok = false, msg = 'Untarget first (the game would fight the write).' }
        return
    end

    local structs, writes, skipped = 0, 0, 0
    for _, c in ipairs(state.candidates) do
        if c.kind == 'deep' and c.struct_off and c.struct_off >= 0x04 then
            local dwAddr = safe_read_u32(state.base + c.p_off)
            if dwAddr and dwAddr >= HEAP_LO and dwAddr <= HEAP_HI then
                structs = structs + 1
                if safe_write_u32(dwAddr + c.struct_off - 0x04, lock.idx) then writes = writes + 1 end
                if safe_write_u32(dwAddr + c.struct_off,        lock.sid) then writes = writes + 1 end
            else
                skipped = skipped + 1
            end
        else
            skipped = skipped + 1
        end
    end

    state.test_log = {
        ok  = (structs > 0),
        msg = ('SetTarget ALL: wrote idx=%d + sid=0x%X to %d struct(s) (%d writes, %d skipped).  Watch for arrow + name.'):format(
                lock.idx, lock.sid, structs, writes, skipped),
    }
end

local function do_watch(i)
    if i < 1 or i > #state.candidates then return end
    state.watch_idx    = i
    state.watch_next   = 0
    state.watch_cached = nil
end

local function do_stop_watch()
    state.watch_idx    = 0
    state.watch_cached = nil
end

--------------------------------------------------------------------------------
-- TEST LOCK / TEST GO -- the only WRITE path in this addon.
--
-- Two-button flow, deliberately explicit:
--   [Test Lock] -- captures the currently-targeted mob's server_id, idx,
--                  and name into state.test_lock.  Requires a live target.
--   [Test Go]   -- writes the locked server_id to the watched candidate's
--                  static offset.  Requires:
--                    * a lock exists
--                    * the player currently has NO target (so the game's
--                      own target loop isn't fighting our write)
--                    * a candidate is being watched
--                    * the write offset is inside FFXiMain
--
-- safe_write_u32 is pcall-wrapped so a fault throws a Lua error rather
-- than killing the process.  Pre/post values are read back and logged.
--------------------------------------------------------------------------------

local function do_test_lock()
    state.test_log = nil

    if not live.target_idx then
        state.test_lock = nil
        state.test_log = { ok = false, msg = 'Cannot lock: no current target.' }
        return
    end
    if not live.target_sid or live.target_sid == 0 then
        state.test_lock = nil
        state.test_log = { ok = false, msg = 'Cannot lock: target has no server_id.' }
        return
    end

    local tptr = compute_entity_ptr(live.target_idx)

    state.test_lock = {
        sid       = live.target_sid,
        idx       = live.target_idx,
        ptr       = tptr,            -- may be nil if anchor unreadable
        name      = live.target_name,
        locked_at = os.clock(),
    }
    state.test_log = { ok = true,
        msg = ('Locked: "%s" idx %d  sid 0x%X  ptr 0x%X.  Now untarget and click [Test Go].'):format(
                state.test_lock.name or '?', state.test_lock.idx,
                state.test_lock.sid, tptr or 0) }
end

local function do_test_dia()
    -- This button does NOT write memory.  It queues "/ma Dia <t>" through
    -- the chat manager exactly as if the player typed it.  The interesting
    -- question is: does <t> resolve from the mirror at 0x485CF0 that we
    -- wrote with Test Go, or from a different upstream target field?
    --   - If <t> resolves the locked mob -> the game's command parser
    --     reads from the same field we wrote.  Memory targeting works.
    --   - If the game says "no target" or casts on someone else -> <t>
    --     resolves elsewhere and 0x485CF0 is a downstream mirror only.
    -- Either outcome is useful; we just need to see the game's response.
    local cmd = '/ma "Dia" <t>'
    local mgr = AshitaCore and AshitaCore:GetChatManager() or nil
    if not mgr then
        state.test_log = { ok = false, msg = 'No chat manager available.' }
        return
    end

    local ok, err = pcall(function() mgr:QueueCommand(1, cmd) end)
    if not ok then
        state.test_log = { ok = false, msg = ('QueueCommand failed: %s'):format(tostring(err)) }
        return
    end

    state.test_log = {
        ok  = true,
        msg = ('Queued: %s  -- watch chat for game response.'):format(cmd),
    }
end

local function do_test_go()
    state.test_log = nil

    if state.base == 0 then
        state.test_log = { ok = false, msg = 'FFXiMain base not resolved.' }
        return
    end
    if not state.test_lock or not state.test_lock.sid or state.test_lock.sid == 0 then
        state.test_log = { ok = false, msg = 'No lock.  Click [Test Lock] while a mob is targeted first.' }
        return
    end
    if live.target_idx then
        state.test_log = { ok = false,
            msg = 'Untarget first.  Test Go refuses to fire while a target exists (the game would fight the write).' }
        return
    end
    if state.watch_idx == 0 then
        state.test_log = { ok = false, msg = 'No candidate being watched.  Click [Watch] on a candidate first.' }
        return
    end
    local c = state.candidates[state.watch_idx]
    if not c then
        state.test_log = { ok = false, msg = 'Watched candidate is gone.' }
        return
    end
    local lock = state.test_lock
    local kind = c.kind or 'sid'

    -- Resolve the write address and the value, per candidate kind.
    local addr, write_val, val_label, addr_label

    if kind == 'deep' then
        -- Pointer-chase: addr = *(base + p_off) + struct_off (a heap addr).
        local H = safe_read_u32(state.base + c.p_off)
        if not H or H < HEAP_LO or H > HEAP_HI then
            state.test_log = { ok = false,
                msg = ('Deep pointer at base+0x%X no longer points to heap (0x%X).'):format(
                        c.p_off, H or 0) }
            return
        end
        addr = H + c.struct_off
        addr_label = ('*(base+0x%X)+0x%X = 0x%X'):format(c.p_off, c.struct_off, addr)
        if c.match_kind == 'ptr' then
            if not lock.ptr or lock.ptr == 0 then
                state.test_log = { ok = false, msg = 'Lock has no entity pointer to write.' }
                return
            end
            write_val = lock.ptr
            val_label = ('ptr 0x%X'):format(lock.ptr)
        else
            write_val = lock.sid
            val_label = ('sid 0x%X'):format(lock.sid)
        end
    else
        -- Static-offset candidates (sid / idx / ptr).
        if c.static_off < 0 or c.static_off >= SCAN_UPPER_END then
            state.test_log = { ok = false,
                msg = ('Refusing write: offset 0x%X outside FFXiMain scan range.'):format(c.static_off) }
            return
        end
        addr = state.base + c.static_off
        addr_label = ('base+0x%X'):format(c.static_off)
        if kind == 'idx' then
            if not lock.idx or lock.idx == 0 then
                state.test_log = { ok = false, msg = 'Lock has no entity index to write.' }
                return
            end
            write_val = lock.idx
            val_label = ('idx %d'):format(lock.idx)
        elseif kind == 'ptr' then
            if not lock.ptr or lock.ptr == 0 then
                state.test_log = { ok = false, msg = 'Lock has no entity pointer to write.' }
                return
            end
            write_val = lock.ptr
            val_label = ('ptr 0x%X'):format(lock.ptr)
        else
            write_val = lock.sid
            val_label = ('sid 0x%X'):format(lock.sid)
        end
    end

    local before = safe_read_u32(addr) or 0

    local ok, err = safe_write_u32(addr, write_val)

    local after  = safe_read_u32(addr) or 0

    if not ok then
        state.test_log = {
            ok        = false,
            msg       = ('write_uint32 failed: %s'):format(tostring(err)),
            addr      = addr,
            before    = before,
            after     = after,
            attempted = write_val,
            lock_name = lock.name,
        }
        return
    end

    state.test_log = {
        ok        = true,
        msg       = ('Wrote %s (lock "%s") to %s [%s candidate].'):format(
                        val_label, lock.name or '?', addr_label, kind),
        addr      = addr,
        before    = before,
        after     = after,
        attempted = write_val,
        lock_name = lock.name,
    }
end

--------------------------------------------------------------------------------
-- Live status refresh (table declared up near state, so do_test_lock /
-- do_test_go can see it as an upvalue)
--------------------------------------------------------------------------------

local function refresh_live()
    -- Player
    live.player_idx  = api_player_index()
    live.player_name = (live.player_idx and api_entity_name(live.player_idx)) or '(none)'
    live.player_sid  = (live.player_idx and api_entity_server_id(live.player_idx)) or 0
    if state.base ~= 0 then
        live.player_ptr = safe_read_u32(state.base + OFFSET_PLAYER_ENTITY_PTR) or 0
    else
        live.player_ptr = 0
    end

    -- Target
    live.target_idx  = api_target_index()
    live.target_name = (live.target_idx and api_entity_name(live.target_idx)) or '(none)'
    live.target_sid  = api_target_server_id() or 0
end

local function resolve_value_to_entity(ent, kind_for_resolve, val)
    -- kind_for_resolve: 'idx' | 'ptr' | 'sid'
    if not ent or val == 0 then return '' end
    if kind_for_resolve == 'idx' then
        if val >= 1 and val <= 0x6FF then
            local ok, name = pcall(function() return ent:GetName(val) end)
            if ok and name and name ~= '' then return ('%s (idx %d)'):format(name, val) end
        end
        return ''
    elseif kind_for_resolve == 'ptr' then
        local pidx = live.player_idx
        local pptr = live.player_ptr
        if pidx and pptr and pptr ~= 0 then
            local array_base = pptr - pidx * ENTITY_SIZE
            if (val - array_base) % ENTITY_SIZE == 0 then
                local idx = (val - array_base) / ENTITY_SIZE
                if idx >= 1 and idx <= 0x6FF then
                    local ok, name = pcall(function() return ent:GetName(idx) end)
                    if ok and name and name ~= '' then return ('%s (idx %d)'):format(name, idx) end
                end
            end
        end
        return ''
    else -- sid
        for idx = 1, 0x6FF do
            local ok, sid = pcall(function() return ent:GetServerId(idx) end)
            if ok and sid == val then
                local ok2, name = pcall(function() return ent:GetName(idx) end)
                if ok2 and name and name ~= '' then return ('%s (idx %d)'):format(name, idx) end
            end
        end
        return ''
    end
end

local function refresh_watch()
    if state.watch_idx == 0 then return end
    local c = state.candidates[state.watch_idx]
    if not c then state.watch_idx = 0; return end

    local kind = c.kind or 'sid'
    local val = 0
    local broken_ptr = false

    if kind == 'deep' then
        -- Pointer-chase read: H = *(base+p_off); val = *(H+struct_off).
        local H = safe_read_u32(state.base + c.p_off)
        if H and H >= HEAP_LO and H <= HEAP_HI then
            val = safe_read_u32(H + c.struct_off) or 0
        else
            broken_ptr = true
        end
    else
        val = safe_read_u32(state.base + c.static_off) or 0
    end

    local mem = get_mem()
    local ent = mem and mem:GetEntity() or nil

    -- For deep candidates, resolve by their match_kind (sid or ptr).
    local resolve_kind = (kind == 'deep') and (c.match_kind or 'sid') or kind
    local resolved_name = resolve_value_to_entity(ent, resolve_kind, val)

    state.watch_cached = {
        val = val,
        kind = kind,
        resolve_kind = resolve_kind,
        broken_ptr = broken_ptr,
        resolved_name = resolved_name,
    }
end

--------------------------------------------------------------------------------
-- ImGui rendering
--------------------------------------------------------------------------------

local function render_status()
    imgui.Text(('FFXiMain base: 0x%X'):format(state.base))
    imgui.Separator()

    if live.player_idx then
        imgui.Text(('Player: idx %d  "%s"'):format(live.player_idx, live.player_name))
        imgui.Text(('  server_id: 0x%X  entity_ptr (raw): 0x%X'):format(
            live.player_sid, live.player_ptr))
    else
        imgui.TextColored({ 1.0, 0.5, 0.5, 1.0 }, 'Player: (zoning / unavailable)')
    end

    imgui.Spacing()

    if live.target_idx then
        imgui.Text(('Target: idx %d  "%s"'):format(live.target_idx, live.target_name))
        imgui.Text(('  server_id: 0x%X'):format(live.target_sid))

        -- Render-flag capture (the XIUI XOR method for finding a name-icon bit).
        -- Read all render flag words for the current target, show them as hex,
        -- and XOR against a saved baseline so the differing bit is obvious.
        -- Target a KNOWN player (e.g. a GM), Save Baseline, then target a plain
        -- player -- the highlighted diff bits ARE the flag for that status.
        local mem = get_mem()
        local ent = mem and mem:GetEntity() or nil
        if ent then
            local f = {}
            for w = 0, 4 do
                f[w] = select(2, pcall(function()
                    return ent['GetRenderFlags' .. w](ent, live.target_idx)
                end)) or 0
            end
            imgui.Separator()
            imgui.TextColored({ 1.0, 0.85, 0.3, 1.0 }, 'Render flags (target):')
            for w = 0, 4 do
                imgui.Text(('  Flags%d: 0x%08X'):format(w, f[w]))
            end
            if imgui.Button('Save Baseline##flags', { 130, 0 }) then
                state.flag_baseline = { f[0], f[1], f[2], f[3], f[4] }
                state.flag_baseline_name = live.target_name
            end
            if state.flag_baseline then
                imgui.SameLine()
                if imgui.Button('Clear##flags', { 70, 0 }) then
                    state.flag_baseline = nil
                    state.flag_baseline_name = nil
                end
                imgui.TextColored({ 0.6, 0.9, 1.0, 1.0 },
                    ('  XOR vs baseline "%s":'):format(state.flag_baseline_name or '?'))
                for w = 0, 4 do
                    local x = bit.bxor(f[w], state.flag_baseline[w + 1] or 0)
                    if x ~= 0 then
                        imgui.TextColored({ 1.0, 0.5, 0.5, 1.0 },
                            ('    Flags%d differs: 0x%08X'):format(w, x))
                    end
                end
            end
        end
    else
        imgui.TextColored({ 0.8, 0.8, 0.5, 1.0 }, 'Target: (none -- click a mob)')
    end
end

local function render_controls()
    local scanning = scan_is_active()
    local can_scan = state.base ~= 0 and live.target_idx ~= nil and live.target_sid ~= 0

    if scanning then
        if imgui.Button('Cancel Scan', { 110, 0 }) then scan_cancel() end
        imgui.SameLine()
        imgui.Dummy({ 110, 0 })
    elseif can_scan then
        if imgui.Button('Scan Lower', { 110, 0 }) then do_scan_lower() end
        imgui.SameLine()
        if imgui.Button('Scan Upper', { 110, 0 }) then do_scan_upper() end
    else
        if imgui.Button('Scan Lower', { 110, 0 }) then end -- no-op
        imgui.SameLine()
        if imgui.Button('Scan Upper', { 110, 0 }) then end -- no-op
    end

    imgui.SameLine()
    if state.watch_idx ~= 0 then
        if imgui.Button('Stop Watch', { 110, 0 }) then do_stop_watch() end
    else
        imgui.Dummy({ 110, 0 })
    end

    imgui.SameLine()
    if imgui.Button('Refresh', { 80, 0 }) then refresh_live() end

    if not scanning and not can_scan then
        imgui.TextDisabled('  (target a mob with a server_id to enable scanning)')
    else
        imgui.TextDisabled(('  Lower = 0..0x%X (%dMB)   Upper = 0x%X..0x%X (%dMB)'):format(
            SCAN_LOWER_END, SCAN_LOWER_END / 0x100000,
            SCAN_UPPER_START, SCAN_UPPER_END,
            (SCAN_UPPER_END - SCAN_UPPER_START) / 0x100000))
    end
end

local function render_candidates()
    imgui.Text('Candidates (static FFXiMain offsets holding the target value):')
    if #state.candidates == 0 then
        imgui.TextDisabled('  (none yet -- run a Scan or promote from Track)')
        return
    end

    local n = math.min(#state.candidates, 16)
    for i = 1, n do
        local c = state.candidates[i]
        local kind = c.kind or 'sid'
        if kind == 'deep' then
            imgui.TextColored({ 1.0, 0.85, 0.6, 1.0 },
                ('  [%d] *(base+0x%X)+0x%X  [deep/%s]'):format(
                    i, c.p_off, c.struct_off, c.match_kind or 'sid'))
        elseif kind == 'idx' then
            imgui.TextColored({ 0.8, 0.9, 1.0, 1.0 },
                ('  [%d] base+0x%X  [idx] (held %d)'):format(i, c.static_off, c.seen_at))
        elseif kind == 'ptr' then
            imgui.TextColored({ 0.9, 0.8, 1.0, 1.0 },
                ('  [%d] base+0x%X  [ptr] (held 0x%X)'):format(i, c.static_off, c.seen_at))
        else
            imgui.Text(('  [%d] base+0x%X  [sid] (held 0x%X)'):format(i, c.static_off, c.seen_at))
        end
        imgui.SameLine()
        if imgui.Button(('Watch##cand%d'):format(i), { 70, 0 }) then do_watch(i) end
    end
    if #state.candidates > n then
        imgui.TextDisabled(('  ...and %d more (showing first %d)'):format(
            #state.candidates - n, n))
    end
end

local function render_watch()
    if state.watch_idx == 0 then return end
    local c = state.candidates[state.watch_idx]
    if not c then return end
    local kind = c.kind or 'sid'

    imgui.Separator()
    if kind == 'deep' then
        imgui.Text(('Watching [%d]: *(base+0x%X)+0x%X  [deep/%s]'):format(
            state.watch_idx, c.p_off, c.struct_off, c.match_kind or 'sid'))
    else
        imgui.Text(('Watching [%d]: base+0x%X  [%s]'):format(state.watch_idx, c.static_off, kind))
    end

    local w = state.watch_cached
    if w then
        if w.broken_ptr then
            imgui.TextColored({ 1.0, 0.6, 0.4, 1.0 }, '  (deep pointer no longer valid)')
        end
        if kind == 'idx' then
            imgui.Text(('  current value: %d  (0x%X)'):format(w.val, w.val))
        else
            imgui.Text(('  current value: 0x%X'):format(w.val))
        end
        if w.resolved_name and w.resolved_name ~= '' then
            imgui.TextColored({ 0.7, 0.9, 1.0, 1.0 },
                ('  matches entity: %s'):format(w.resolved_name))
        else
            local rk = w.resolve_kind or kind
            if rk == 'idx' then
                imgui.TextDisabled('  (value is not a valid current entity index)')
            elseif rk == 'ptr' then
                imgui.TextDisabled('  (value is not a valid current entity pointer)')
            else
                imgui.TextDisabled('  (value does not match any current entity server_id)')
            end
        end
    else
        imgui.TextDisabled('  polling...')
    end

    imgui.Spacing()
    imgui.TextDisabled('Now target other mobs.  The value should change to the new target.')
end

local function render_track()
    imgui.Separator()
    imgui.Text('Track = DEEP pointer-chase (static ptr -> heap struct -> target field):')

    local scanning = scan_is_active()
    local has_target = (live.target_idx ~= nil)
    local has_track  = (state.track ~= nil and state.track.survivors ~= nil)

    -- Track Lower (0..8MB) -- where all prior deep candidates were found
    if scanning or not has_target then
        if imgui.Button('Track Lower', { 100, 0 }) then end -- no-op
    else
        if imgui.Button('Track Lower', { 100, 0 }) then do_track_lower() end
    end

    imgui.SameLine()
    -- Track Upper (8..16MB)
    if scanning or not has_target then
        if imgui.Button('Track Upper', { 100, 0 }) then end -- no-op
    else
        if imgui.Button('Track Upper', { 100, 0 }) then do_track_upper() end
    end

    imgui.SameLine()
    -- Track Filter
    if scanning or not has_target or not has_track then
        if imgui.Button('Track Filter', { 100, 0 }) then end -- no-op
    else
        if imgui.Button('Track Filter', { 100, 0 }) then do_track_filter() end
    end

    imgui.SameLine()
    -- Track Promote (re-check live, not latched, for the same reason as below)
    if state.track and state.track.survivors and #state.track.survivors > 0 then
        if imgui.Button('Promote', { 80, 0 }) then do_track_promote() end
    else
        if imgui.Button('Promote', { 80, 0 }) then end -- no-op
    end

    imgui.SameLine()
    if imgui.Button('Clear##track', { 70, 0 }) then do_track_clear() end

    -- Re-check state.track LIVE here (not the latched has_track): the Clear
    -- button callback above may have set state.track = nil during this same
    -- frame, and the latched flag would still be true.
    if state.track and state.track.survivors then
        imgui.Text(('  survivors: %d   rounds: %d   last "%s"'):format(
            #state.track.survivors, state.track.rounds or 0,
            state.track.last_name or '?'))
    end
    imgui.TextDisabled(('  %s'):format(state.track_status or ''))
end

local function render_struct_diff()
    -- Only meaningful for a watched deep candidate.
    local c = (state.watch_idx ~= 0) and state.candidates[state.watch_idx] or nil
    if not c or c.kind ~= 'deep' then return end

    imgui.Separator()
    imgui.Text('Struct Delta (write the WHOLE acquired state, not one field):')

    local no_target  = (live.target_idx == nil)
    local has_a      = (state.diff ~= nil and state.diff.a ~= nil)
    local has_b      = (state.diff ~= nil and state.diff.b ~= nil)
    local has_change = (state.diff ~= nil and state.diff.changed ~= nil and #state.diff.changed > 0)

    -- Snap A (no target)
    if no_target then
        if imgui.Button('Snap A (no tgt)', { 130, 0 }) then do_diff_snap_a() end
    else
        if imgui.Button('Snap A (no tgt)', { 130, 0 }) then end -- no-op
    end

    imgui.SameLine()
    -- Snap B (with target)
    if (not no_target) and has_a then
        if imgui.Button('Snap B (tgt)', { 120, 0 }) then do_diff_snap_b() end
    else
        if imgui.Button('Snap B (tgt)', { 120, 0 }) then end -- no-op
    end

    imgui.SameLine()
    -- Write Delta (no target)
    if no_target and has_change then
        if imgui.Button('Write Delta', { 110, 0 }) then do_diff_write() end
    else
        if imgui.Button('Write Delta', { 110, 0 }) then end -- no-op
    end

    imgui.SameLine()
    if imgui.Button('Clear##diff', { 70, 0 }) then do_diff_clear() end


    -- Show the changed-field list (the coordinated target state)
    if state.diff and state.diff.changed and #state.diff.changed > 0 then
        local base = state.diff.base_addr or 0
        imgui.Text(('  %d changed field(s) @ struct 0x%X:'):format(#state.diff.changed, base))
        local n = math.min(#state.diff.changed, 12)
        for i = 1, n do
            local e = state.diff.changed[i]
            imgui.Text(('    +0x%02X : 0x%08X -> 0x%08X'):format(e.off, e.a, e.b))
        end
        if #state.diff.changed > n then
            imgui.TextDisabled(('    ...and %d more'):format(#state.diff.changed - n))
        end
    end
    imgui.TextDisabled(('  %s'):format(state.diff_status or ''))
end

local function render_test_buttons()
    if state.watch_idx == 0 then return end

    imgui.Separator()
    imgui.Text('Test write (locks target; writes sid/idx/ptr/deep per candidate kind):')

    -- Test Lock: enabled only when a live target exists
    local can_lock = (live.target_idx ~= nil and live.target_sid ~= 0)
    if can_lock then
        if imgui.Button('Test Lock', { 110, 0 }) then do_test_lock() end
    else
        if imgui.Button('Test Lock', { 110, 0 }) then end -- no-op
    end

    imgui.SameLine()

    -- Test Go: enabled only when (lock exists) AND (no current target) AND (watching)
    local lock         = state.test_lock
    local has_lock     = (lock ~= nil and lock.sid ~= 0)
    local no_target    = (live.target_idx == nil)
    local has_watch    = (state.watch_idx ~= 0)
    local has_base     = (state.base ~= 0)
    local can_go       = has_lock and no_target and has_watch and has_base

    if can_go then
        if imgui.Button('Test Go', { 110, 0 }) then do_test_go() end
    else
        if imgui.Button('Test Go', { 110, 0 }) then end -- no-op
    end

    -- Test Dia: casts "/ma Dia <t>" via the chat manager.  Tests whether
    -- the game's <t> token resolves from the mirror we wrote with Test Go.
    -- Always clickable (no gating) -- the workflow is up to the user.
    imgui.SameLine()
    if imgui.Button('Test Dia', { 110, 0 }) then do_test_dia() end

    -- MrArgus SetTarget: writes the FULL {code[0],code[1],charPtr} descriptor
    -- to *(base + p_off) of the watched DEEP candidate.  This is the faithful
    -- MrArgus port -- the main event.  Needs: a [deep] candidate watched, a
    -- Test Lock (captures the entity pointer), and no current target.
    imgui.Spacing()
    local c_watched   = (state.watch_idx ~= 0) and state.candidates[state.watch_idx] or nil
    local is_deep     = (c_watched ~= nil and c_watched.kind == 'deep')
    local st_haslock  = (state.test_lock ~= nil and state.test_lock.sid ~= nil and state.test_lock.sid ~= 0
                          and state.test_lock.idx ~= nil and state.test_lock.idx ~= 0)
    local st_notgt    = (live.target_idx == nil)
    local can_settgt  = is_deep and st_haslock and st_notgt and (state.base ~= 0)

    if can_settgt then
        if imgui.Button('SetTarget (MrArgus)', { 170, 0 }) then do_mrargus_set() end
    else
        if imgui.Button('SetTarget (MrArgus)', { 170, 0 }) then end -- no-op
    end

    imgui.SameLine()
    -- SetTarget ALL: write to every promoted deep candidate at once.
    -- Needs only a lock + no target (writes all deep candidates, not the
    -- watched one), so it doesn't require watching a deep candidate.
    local can_all = st_haslock and st_notgt and (state.base ~= 0)
        and (#state.candidates > 0)
    if can_all then
        if imgui.Button('SetTarget ALL', { 130, 0 }) then do_mrargus_set_all() end
    else
        if imgui.Button('SetTarget ALL', { 130, 0 }) then end -- no-op
    end

    imgui.SameLine()
    if not is_deep then
        imgui.TextColored({ 1.0, 0.8, 0.4, 1.0 }, 'watch a [deep] candidate (or use ALL)')
    elseif not st_haslock then
        imgui.TextColored({ 1.0, 0.8, 0.4, 1.0 }, 'click Test Lock first (captures idx + sid)')
    elseif not st_notgt then
        imgui.TextColored({ 1.0, 0.8, 0.4, 1.0 }, 'untarget first')
    else
        imgui.TextColored({ 0.7, 1.0, 0.7, 1.0 }, 'ready: idx@+0x04, sid@+0x08')
    end

    -- Status hints
    if not can_lock and not has_lock then
        imgui.TextDisabled('  Step 1: target a mob, then click [Test Lock].')
    elseif has_lock then
        imgui.Text(('  Locked: 0x%X  "%s"  (idx %d)'):format(
            lock.sid, lock.name or '?', lock.idx or 0))
        if not no_target then
            imgui.TextColored({ 1.0, 0.8, 0.4, 1.0 },
                '  [Test Go] disabled: untarget first.')
        elseif not has_watch then
            imgui.TextColored({ 1.0, 0.8, 0.4, 1.0 },
                '  [Test Go] disabled: click [Watch] on a candidate first.')
        else
            imgui.TextColored({ 0.7, 1.0, 0.7, 1.0 },
                '  Ready: click [Test Go] to write.')
        end
    end

    -- Result log
    local log = state.test_log
    if log then
        imgui.Spacing()
        if log.ok then
            imgui.TextColored({ 0.6, 1.0, 0.6, 1.0 }, log.msg)
        else
            imgui.TextColored({ 1.0, 0.5, 0.5, 1.0 }, log.msg)
        end
        if log.addr then
            imgui.Text(('  addr:      0x%X'):format(log.addr))
            imgui.Text(('  before:    0x%X'):format(log.before or 0))
            imgui.Text(('  attempted: 0x%X'):format(log.attempted or 0))
            imgui.Text(('  after:     0x%X'):format(log.after or 0))
        end
    end
end

ashita.events.register('d3d_present', 'bts_render', function()
    if not state.window_visible[1] then return end

    refresh_live()
    if scan_is_active() then scan_step() end

    if state.watch_idx ~= 0 then
        local t = os.clock()
        if t >= state.watch_next then
            state.watch_next = t + WATCH_POLL_SEC
            refresh_watch()
        end
    end

    imgui.SetNextWindowSize({ 560, 620 }, ImGuiCond_FirstUseEver)
    if imgui.Begin('Target Scan (READ-ONLY)', state.window_visible) then
        render_status()
        imgui.Separator()
        render_controls()
        imgui.Spacing()
        imgui.Text(state.scan_status)
        imgui.Spacing()
        render_candidates()
        render_watch()
        render_test_buttons()
        render_track()
        render_struct_diff()
    end
    imgui.End()
end)

--------------------------------------------------------------------------------
-- Load / command / unload
--------------------------------------------------------------------------------

ashita.events.register('load', 'bts_on_load', function()
    state.base = find_ffximain_base()
    if state.base == 0 then
        print('[bts] WARNING: could not resolve FFXiMain.dll base.')
    else
        print(('[bts] v0.15 loaded.  FFXiMain base = 0x%X.  /bts to toggle.'):format(state.base))
    end
end)

ashita.events.register('command', 'bts_on_command', function(e)
    local args = e.command:args()
    if #args == 0 then return end
    if args[1]:lower() ~= '/bts' then return end
    e.blocked = true
    state.window_visible[1] = not state.window_visible[1]
end)

ashita.events.register('unload', 'bts_on_unload', function()
    state.watch_idx = 0
    if state.scan then state.scan.active = false end
end)
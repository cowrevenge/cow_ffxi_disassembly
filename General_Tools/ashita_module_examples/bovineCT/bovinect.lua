--[[
    bovinect.lua - HorizonXI crafting packet tool

    Standalone Ashita v4 addon for capturing and replaying synthesis
    packets. Split out from memwatch (which stays a fishing-only state
    reporter). No coupling to fishing, state.json, or apimain.

    What it does:
      - Watches the synth round-trip and logs it to craftdebug.txt:
          0x0096 OUT  synthesis start  (crystal slot + ingredient id/slot arrays)
          0x0030 IN   synthesis animation (quality: NQ / Break / HQ tiers)
          0x006F IN   synthesis result (result byte, item id, quantity)
      - Craft Test button / command: resolves a known recipe's items to
        their CURRENT inventory slots (read fresh, since crafting shifts
        slots) and sends one 0x0096 synth-start.

    0x0096 layout (confirmed from live capture on this server):
      0x00      96            packet id
      0x01      12            size
      0x02-0x03 seq           sequence counter (client stamps on send)
      0x04      3A            inner-header const
      0x05      sync          tracks seq
      0x06-0x07 01 10         inner-header const
      0x08      CRYSTAL SLOT  inventory slot of the crystal
      0x09      03            const
      0x0A      INGR ITEM IDS u16 LE each, up to 8 (parallel to slots)
      0x1A      INGR SLOTS    u8 each, up to 8 (parallel to ids)
      0x12-0x19 scratch       uninitialized; server ignores
      0x1D-0x23 unused        zero

    Recipe item ids are server-specific and were derived from the packets
    themselves, NOT retail wikis (which differ). See CRAFT_TEST_* below.

    Commands:
      /bovinect              toggle the panel  (alias /bct)
      /bct watch on|off|toggle  enable/disable packet capture
      /bct test               fire one Craft Test synth
      /bct status             print current settings
      /bct help

    Output file: <addon path>/craftdebug.txt
]]

addon.name    = 'bovinect'
addon.author  = 'shadowcow'
addon.version = '1.0'
addon.desc    = 'FFXI crafting packet capture + synth replay test.'

require('common')
local imgui = require('imgui')
local chat  = require('chat')

----------------------------------------------------------------------------------------------------
-- Settings / state
----------------------------------------------------------------------------------------------------

-- Single Debug toggle. When ON: capture synth packets to craftdebug.txt,
-- echo them to chat, and show verbose detail in the panel (item ids/slots,
-- hard-limit countdown, log path). Default OFF.
local debug = false

-- craftmon-style clean colored result line in chat on every synth. Default ON.
local show_results = true

-- Chat colors for the result line. Ashita color codes:
--   1 white   5 green   39 red   72 magenta   76 pink   81 light blue
-- `broke` (not `break`) because `break` is a Lua reserved word.
local CHAT_COLORS = {
    nq    = 5,    -- early "Synth: NQ" call           (green = success)
    broke = 39,   -- early "Synth: Break" call        (red   = break)
    hq    = 5,    -- early "Synth: HQ1/2/3" call      (green = success)
    item  = 5,    -- "Crafted Nx <item>" item name    (green = success)
    lost  = 39,   -- "Craft Broke - X lost" item list (red   = break)
}

-- Session results tracker. When ON, the panel shows running NQ/HQ/Broken
-- counts tallied from synth animation packets this session.
local show_session = false
local session = { nq = 0, hq = 0, broken = 0 }

-- Stop-at-level: when enabled, auto craft stops once the watched craft skill
-- reaches the target level. The level is captured from chat ("Your <craft>
-- skill reaches level N") -- the authoritative server signal. No memory reads
-- (the craft-skill API isn't reliably exposed on this build, and even atom0s'
-- Crafty plugin uses event/chat signals rather than reading the level).
local stop_at_enabled = { false }
local stop_at_level   = { 30 }       -- target level (imgui int buffer)
-- Edit-mode flip for the stop_at_level display. The value is rendered as a
-- centered-text styled button by default and only becomes an editable InputInt
-- once clicked (ImGui has no center-align flag for InputText). `focus` is set
-- the frame we enter edit mode so SetKeyboardFocusHere fires exactly once.
local editing_stoplvl = { active = false, focus = false }

-- Last craft level seen in chat. nil until the first "reaches level N" line
-- this session.
local chat_craft_level = nil

local function current_craft_level()
    return chat_craft_level
end

-- UI panel toggle (mutable table so imgui close-X can flip it). Opens on load.
local ui_visible = { true }

-- Last Craft Test result string, shown under the button.
local craft_test_msg = ''

----------------------------------------------------------------------------------------------------
-- Craft engine state (single-shot lockout + auto-craft loop + tuning)
----------------------------------------------------------------------------------------------------

-- Crafting-in-progress: true between sending 0x0096 and receiving 0x006F
-- (or the hard timeout). Drives the "Crafting in progress" indicator and
-- prevents overlapping synth attempts.
local crafting          = false
local synth_start_clock = 0      -- os.clock() when we last sent 0x0096

-- Hard-timeout self-recovery: if no 0x006F arrives within this many seconds
-- of the start, assume the result packet was missed and clear `crafting`.
local SYNTH_TIMEOUT = 30.0

-- HARD packet rate limiter. This is an ABSOLUTE floor on how often a 0x0096
-- synth packet may leave the client, enforced at the single send chokepoint
-- below. It is independent of (and stricter than) all the interval/lockout
-- logic: no matter what -- button spam, a logic bug, auto-loop timing --
-- a synth packet can NEVER be sent less than this many seconds after the
-- previous one actually went out. NEVER raise the send rate above this.
local HARD_MIN_SEND_INTERVAL = 10.0
local last_packet_sent_clock = -math.huge   -- os.clock() of last real 0x0096 send

-- Ingredient item ids of the most recent synth we sent, in submit order. Used
-- to name LOST ingredients on a break (the result packet zeroes lost slots, so
-- the name has to come from what we submitted).
local last_submitted_ids = {}

-- Craft 1 button: 30s lockout after a press.
local CRAFT1_LOCKOUT     = 30.0
local craft1_lock_until  = 0      -- os.clock() time the button frees up

-- Auto Craft loop.
-- Probing DISABLED: interval is fixed at 18s. auto_floor is preset (non-nil),
-- which disables the probe-down logic, so the loop holds 18s start-to-start.
local auto_running   = false
local AUTO_START     = 18         -- fixed start-to-start interval (s)
local AUTO_MIN_PROBE = 18         -- floor (== start; no room to probe)
local auto_interval  = AUTO_START -- current start-to-start interval (s)
local auto_floor     = 18         -- preset (not nil) -> probing off
local auto_status    = 'idle'     -- short status string for the panel

-- Forward declaration: defined after the packet handlers, but the panel
-- closure (compiled earlier in file order) calls it.
local do_craft_test
local stop_auto

local CRAFT_QUALITY_NAMES = {
    [0] = 'NQ', [1] = 'Break', [2] = 'HQ1', [3] = 'HQ2', [4] = 'HQ3',
}

----------------------------------------------------------------------------------------------------
-- Recipe -- NAME-DRIVEN. Item ids are resolved by looking the names up in
-- inventory at craft time (case-insensitive), so you never hardcode ids.
-- Editable live in the panel. `qty` is how many copies the recipe consumes.
--
-- Default is Tsurara: Ice Crystal + Rock Salt + Distilled Water x2.
-- Ingredient order matches the captured, server-accepted layout
-- [Salt, Water, Water].
----------------------------------------------------------------------------------------------------

local MAX_INGREDIENTS = 8

local RECIPE = {
    name    = 'Tsurara',
    crystal = 'Ice Crystal',
    ingredients = {
        { name = 'Rock Salt',       qty = 1 },
        { name = 'Distilled Water', qty = 2 },
    },
}

-- ImGui edit buffers (separate from RECIPE so we only commit on change).
-- imgui.InputText needs a single-element table holding the string.
local edit_recipe_name = { RECIPE.name }
local edit_crystal     = { RECIPE.crystal }
local edit_ingredients = {}   -- array of { name = {str}, qty = {int} }
local function rebuild_edit_buffers()
    edit_recipe_name[1] = RECIPE.name
    edit_crystal[1]     = RECIPE.crystal
    edit_ingredients    = {}
    for _, ing in ipairs(RECIPE.ingredients) do
        edit_ingredients[#edit_ingredients + 1] = {
            name = { ing.name },
            qty  = { ing.qty },
        }
    end
end
rebuild_edit_buffers()

----------------------------------------------------------------------------------------------------
-- craftdebug.txt logging (ring buffer of synth records)
----------------------------------------------------------------------------------------------------

local CRAFTLOG_MAX_RECORDS = 20
local craftlog_records     = {}   -- committed records
local craftlog_current     = nil  -- in-progress record

local function craftlog_path()
    return (addon and addon.path or '.') .. 'craftdebug.txt'
end

local function craftlog_start_new_record()
    if craftlog_current ~= nil and #craftlog_current > 0 then
        table.insert(craftlog_records, craftlog_current)
        while #craftlog_records > CRAFTLOG_MAX_RECORDS do
            table.remove(craftlog_records, 1)
        end
    end
    craftlog_current = {}
end

local function craftlog_append(line)
    if craftlog_current == nil then
        craftlog_current = {}
    end
    table.insert(craftlog_current,
        string.format('[%s] %s', os.date('%H:%M:%S'), line))
end

local function craftlog_flush()
    local f = io.open(craftlog_path(), 'w')
    if f == nil then return end
    for i, rec in ipairs(craftlog_records) do
        f:write(string.format('=== Synth %d ===\n', i))
        for _, line in ipairs(rec) do
            f:write(line .. '\n')
        end
        f:write('\n')
    end
    if craftlog_current ~= nil and #craftlog_current > 0 then
        f:write(string.format('=== Synth %d (in progress) ===\n',
            #craftlog_records + 1))
        for _, line in ipairs(craftlog_current) do
            f:write(line .. '\n')
        end
    end
    f:close()
end

local function note(msg)
    print(string.format('\31\200[bovinect]\30\01 %s', msg))
end

----------------------------------------------------------------------------------------------------
-- Recipe file load (format mirrors bovinefh's table loader)
----------------------------------------------------------------------------------------------------
-- Recipe file format (# = comment, blank lines ignored):
--   name: <recipe name>
--   crystal: <crystal item name>
--   <ingredient name>, <qty>
--   <ingredient name>, <qty>
-- Lines with "key: value" set name/crystal; "value, qty" lines are
-- ingredients. Example:
--   name: Tsurara
--   crystal: Ice Crystal
--   Rock Salt, 1
--   Distilled Water, 2

local function ltrim_rtrim(s)
    return (s:gsub('^%s+', ''):gsub('%s+$', ''))
end

local function load_recipe_file(path, quiet)
    if path == nil or path == '' then return end
    local f = io.open(path, 'r')
    if not f then if not quiet then note('could not open: ' .. path) end; return end

    local new_name    = nil
    local new_crystal = nil
    local new_ingr    = {}
    for line in f:lines() do
        local l = ltrim_rtrim(line)
        if l ~= '' and l:sub(1, 1) ~= '#' then
            local key, val = l:match('^([%a]+)%s*:%s*(.+)$')
            if key ~= nil then
                local kl = key:lower()
                if kl == 'name' then
                    new_name = ltrim_rtrim(val)
                elseif kl == 'crystal' then
                    new_crystal = ltrim_rtrim(val)
                end
            else
                -- ingredient line: "<name>, <qty>"  (qty optional -> 1)
                local iname, qty = l:match('^(.-)%s*,%s*(%d+)%s*$')
                if iname == nil then
                    iname = l         -- bare name, qty defaults to 1
                    qty   = '1'
                end
                iname = ltrim_rtrim(iname)
                if iname ~= '' then
                    new_ingr[#new_ingr + 1] = { name = iname, qty = tonumber(qty) or 1 }
                end
            end
        end
    end
    f:close()

    if new_crystal == nil and #new_ingr == 0 then
        if not quiet then note('no recipe data parsed from ' .. path) end
        return
    end

    RECIPE.name        = new_name or RECIPE.name
    RECIPE.crystal     = new_crystal or RECIPE.crystal
    if #new_ingr > 0 then
        RECIPE.ingredients = new_ingr
    end
    rebuild_edit_buffers()
    if not quiet then
        note(string.format('loaded recipe "%s" (%d ingredients) from %s',
            RECIPE.name, #RECIPE.ingredients, path))
    end
end

-- Non-blocking file picker (same approach as bovinefh): write a tiny
-- PowerShell script, launch it DETACHED so the game keeps rendering, and
-- the dialog writes the chosen path to PICK_RESULT. poll_pick() (called
-- every frame from d3d_present) picks it up and loads the recipe.
local PICK_SCRIPT  = (addon and addon.path or '.') .. 'pick.ps1'
local PICK_RESULT  = (addon and addon.path or '.') .. 'pick.result'
local pick_pending = false

-- Default folder both file dialogs open to. A 'recipes' subfolder under
-- the addon path; created on demand so the dialogs always have somewhere
-- sensible to land instead of the addon root.
local RECIPE_DIR   = (addon and addon.path or '.') .. 'recipes'
os.execute('if not exist "' .. RECIPE_DIR .. '" mkdir "' .. RECIPE_DIR .. '"')

local function pick_recipe_file()
    if pick_pending then return end
    os.remove(PICK_RESULT)
    local ps = io.open(PICK_SCRIPT, 'w')
    if not ps then note('could not write picker script'); return end
    ps:write(
        "Add-Type -AssemblyName System.Windows.Forms\n" ..
        "Set-Location -LiteralPath $PSScriptRoot\n" ..
        "$d = New-Object System.Windows.Forms.OpenFileDialog\n" ..
        "$d.Filter = 'Recipe files (*.txt)|*.txt|All files (*.*)|*.*'\n" ..
        "$d.Title = 'Select recipe'\n" ..
        "$d.InitialDirectory = '" .. RECIPE_DIR .. "'\n" ..
        "$out = Join-Path $PSScriptRoot 'pick.result'\n" ..
        "if ($d.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {\n" ..
        "  Set-Content -Path $out -Value $d.FileName\n" ..
        "} else { Set-Content -Path $out -Value '' }\n")
    ps:close()
    os.execute('start "" /b powershell -ExecutionPolicy Bypass -WindowStyle Hidden -File "'
        .. PICK_SCRIPT .. '"')
    pick_pending = true
    note('file picker open (game keeps running)...')
end

local function poll_pick()
    if not pick_pending then return end
    local f = io.open(PICK_RESULT, 'r')
    if not f then return end   -- dialog still open
    local path = f:read('*l')
    f:close()
    os.remove(PICK_RESULT)
    pick_pending = false
    if path and path ~= '' then load_recipe_file((path:gsub('%s+$', ''))) end
end

-- serialize_recipe: render the current RECIPE in the load_recipe_file format.
local function serialize_recipe()
    local lines = {
        '# bovinect recipe file',
        'name: ' .. (RECIPE.name or ''),
        'crystal: ' .. (RECIPE.crystal or ''),
    }
    for _, ing in ipairs(RECIPE.ingredients) do
        if ing.name ~= nil and ing.name ~= '' then
            lines[#lines + 1] = string.format('%s, %d', ing.name, ing.qty or 1)
        end
    end
    return table.concat(lines, '\n') .. '\n'
end

local function save_recipe_file(path)
    if path == nil or path == '' then return end
    local f = io.open(path, 'w')
    if not f then note('could not write: ' .. path); return end
    f:write(serialize_recipe())
    f:close()
    note(string.format('saved recipe "%s" to %s', RECIPE.name, path))
end

-- Persistent last-used recipe. On unload (and after any recipe change) the
-- current RECIPE is written here; on load it's restored, so the addon reopens
-- with whatever you were crafting last (e.g. Deodorizer). Silent -- no chat
-- spam, unlike the explicit Save Craft.
local CONFIG_PATH = (addon and addon.path or '.') .. 'last_craft.txt'

local function save_config()
    local f = io.open(CONFIG_PATH, 'w')
    if not f then return end
    f:write(serialize_recipe())
    f:close()
end

local function load_config()
    local f = io.open(CONFIG_PATH, 'r')
    if not f then return end   -- first run; keep built-in default
    f:close()
    -- Reuse the recipe-file parser (it rebuilds edit buffers + RECIPE).
    load_recipe_file(CONFIG_PATH, true)
end

-- Restore the last-used recipe immediately, before the first frame draws.
load_config()

-- Debounced autosave: GUI edits set cfg_dirty; the present loop flushes at
-- most once per second so disk isn't hit every frame. Covers the case where
-- the unload event doesn't fire (crash / hard reload).
local cfg_dirty    = false
local cfg_saved_at = 0.0
local function mark_cfg_dirty() cfg_dirty = true end
local function flush_cfg_if_dirty()
    if not cfg_dirty then return end
    local now = os.clock()
    if now - cfg_saved_at < 1.0 then return end
    save_config()
    cfg_dirty    = false
    cfg_saved_at = now
end

-- Save picker: SaveFileDialog. OverwritePrompt = $true means Windows itself
-- asks "<file> already exists. Do you want to replace it?" before returning,
-- so the overwrite confirmation is handled natively. The filename is
-- pre-filled with the recipe name. Same detached/non-blocking launch.
local SAVE_RESULT  = (addon and addon.path or '.') .. 'save.result'
local save_pending = false

local function pick_save_recipe_file()
    if save_pending then return end
    os.remove(SAVE_RESULT)
    -- Sanitize the recipe name into a default filename.
    local default_name = (RECIPE.name or 'recipe'):gsub('[\\/:%*%?"<>|]', '_')
    local ps = io.open(PICK_SCRIPT, 'w')
    if not ps then note('could not write picker script'); return end
    ps:write(
        "Add-Type -AssemblyName System.Windows.Forms\n" ..
        "Set-Location -LiteralPath $PSScriptRoot\n" ..
        "$d = New-Object System.Windows.Forms.SaveFileDialog\n" ..
        "$d.Filter = 'Recipe files (*.txt)|*.txt|All files (*.*)|*.*'\n" ..
        "$d.Title = 'Save recipe'\n" ..
        "$d.InitialDirectory = '" .. RECIPE_DIR .. "'\n" ..
        "$d.FileName = '" .. default_name .. ".txt'\n" ..
        "$d.OverwritePrompt = $true\n" ..
        "$d.AddExtension = $true\n" ..
        "$d.DefaultExt = 'txt'\n" ..
        "$out = Join-Path $PSScriptRoot 'save.result'\n" ..
        "if ($d.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {\n" ..
        "  Set-Content -Path $out -Value $d.FileName\n" ..
        "} else { Set-Content -Path $out -Value '' }\n")
    ps:close()
    os.execute('start "" /b powershell -ExecutionPolicy Bypass -WindowStyle Hidden -File "'
        .. PICK_SCRIPT .. '"')
    save_pending = true
    note('save dialog open (game keeps running)...')
end

local function poll_save()
    if not save_pending then return end
    local f = io.open(SAVE_RESULT, 'r')
    if not f then return end   -- dialog still open
    local path = f:read('*l')
    f:close()
    os.remove(SAVE_RESULT)
    save_pending = false
    if path and path ~= '' then save_recipe_file((path:gsub('%s+$', ''))) end
end

local function craft_hexdump(e)
    local bytes = {}
    for i = 0, e.size - 1 do
        bytes[#bytes + 1] = string.format('%02X',
            struct.unpack('B', e.data, i + 1))
    end
    local groups = {}
    for i = 1, #bytes, 4 do
        groups[#groups + 1] = table.concat(bytes, ' ', i,
            math.min(i + 3, #bytes))
    end
    return table.concat(groups, '  ')
end

----------------------------------------------------------------------------------------------------
-- Packet capture
----------------------------------------------------------------------------------------------------

ashita.events.register('packet_in', 'bovinect_in', function(e)
    if e.injected then return end
    if e.id ~= 0x0030 and e.id ~= 0x006F then return end

    if e.id == 0x0030 then
        -- Synthesis animation. Filter to the local player's synth.
        local player = GetPlayerEntity()
        local tgt = struct.unpack('H', e.data, 0x08 + 1)
        if player ~= nil and player.TargetIndex == tgt then
            -- Ignore anim packets we didn't initiate (stale/leftover from a
            -- manual synth) so session stats and any display stay accurate.
            if not crafting then return end
            local q = struct.unpack('b', e.data, 0x0C + 1)
            -- Tally session results (display gated by show_session).
            if q == 0 then
                session.nq = session.nq + 1
            elseif q == 1 then
                session.broken = session.broken + 1
            elseif q >= 2 and q <= 4 then
                session.hq = session.hq + 1
            end
            -- Instant quality call the moment the animation starts (NQ / Break
            -- / HQ). This is the early feedback; the 0x006F handler later prints
            -- the actual item / recovered-ingredient detail.
            if show_results then
                local color = (q == 0 and CHAT_COLORS.nq)
                           or (q == 1 and CHAT_COLORS.broke)
                           or CHAT_COLORS.hq
                print(chat.header(addon.name)
                    + chat.color1(81, '>>> ')
                    + chat.message('Synth: ')
                    + chat.color1(color, CRAFT_QUALITY_NAMES[q] or ('Unknown(' .. q .. ')')))
            end
            if debug then
                local line = string.format(
                    '0x0030 IN synth-anim: quality=%d (%s)  [%d bytes] %s',
                    q, CRAFT_QUALITY_NAMES[q] or '?', e.size, craft_hexdump(e))
                craftlog_append(line)
                craftlog_flush()
                note(line)
            end
        end
        return
    end

    if e.id == 0x006F then
        -- Synthesis result. result==0 = success (item made), result==1 = break
        -- (materials lost, NO item). On a break the server puts a sentinel id
        -- (0x73FF / 29695) in the item field which resolves to a placeholder
        -- name ("Mangled Mess") -- it is NOT a real item and nothing enters the
        -- bag. Only treat the item id as real on success.
        local result = struct.unpack('b', e.data, 0x04 + 1)
        local count  = struct.unpack('b', e.data, 0x06 + 1)
        local itemid = struct.unpack('H', e.data, 0x08 + 1)

        -- Only report a result we were actually waiting on. `crafting` is true
        -- only between our send and its result; if it's false this 0x006F is a
        -- stale/leftover result (e.g. a manual synth finishing just as auto
        -- starts) and printing "Crafted/Broke" for it would be a false report.
        local expected = crafting

        local iname
        if result == 0 then
            local item = AshitaCore:GetResourceManager():GetItemById(itemid)
            iname = (item ~= nil) and item.Name[1] or '?'
        elseif result == 1 then
            iname = '(break - no item)'
        else
            iname = string.format('(no synth - result %d)', result)
        end

        -- State machine: synth resolved -> no longer in progress. The auto
        -- loop's tick (in d3d_present) handles the next attempt + interval.
        crafting = false

        -- Probe-down: a real synth (success OR break, both consume the
        -- cooldown) means the current interval was long enough. result>=2 is
        -- NOT a real synth (invalid recipe / rejected) -- don't adjust timing.
        if expected and (result == 0 or result == 1)
           and auto_running and auto_floor == nil and auto_interval > AUTO_MIN_PROBE then
            auto_interval = auto_interval - 1
        end

        if expected and show_results and result == 0 then
            print(chat.header(addon.name)
                + chat.color1(81, '>>> ')
                + chat.message(string.format('Crafted %dx ', count))
                + chat.color1(CHAT_COLORS.item, iname))
        elseif expected and result >= 2 then
            -- result>=2 (commonly 3): the server accepted the packet but the
            -- crystal + ingredients don't form a known recipe, so nothing is
            -- synthesized (no item, no break, mats not consumed). Looping a bad
            -- recipe is pointless -- report and stop auto.
            if show_results then
                print(chat.header(addon.name)
                    + chat.color1(76, '>>> ')
                    + chat.message('No synth: ')
                    + chat.color1(72, 'this crystal + ingredient list is not a valid recipe'))
            end
            stop_auto('invalid recipe')
        elseif expected and show_results and result == 1 then
            -- Break. Result lists RECOVERED ingredient ids at 0x0A..0x10 (one
            -- per submitted slot; 0 = that slot was lost). LOST = what we
            -- submitted minus what came back. The packet zeroes lost slots, so
            -- names come from last_submitted_ids. FFXI phrases this as the lost
            -- items, e.g. "Craft Broke - Mercury lost, Mercury lost".
            local recovered = {}    -- id -> count returned
            for off = 0x0A, 0x10, 2 do
                local id = struct.unpack('H', e.data, off + 1)
                if id ~= 0 then recovered[id] = (recovered[id] or 0) + 1 end
            end
            local submitted = {}    -- id -> count submitted
            for _, id in ipairs(last_submitted_ids) do
                submitted[id] = (submitted[id] or 0) + 1
            end
            -- Build the lost list in submit order.
            local lost_parts = {}
            local seen = {}
            for _, id in ipairs(last_submitted_ids) do
                if not seen[id] then
                    seen[id] = true
                    local lost_n = (submitted[id] or 0) - (recovered[id] or 0)
                    for _ = 1, lost_n do
                        local it = AshitaCore:GetResourceManager():GetItemById(id)
                        local nm = (it ~= nil) and it.Name[1] or ('#' .. id)
                        lost_parts[#lost_parts + 1] = nm .. ' lost'
                    end
                end
            end
            local loststr = (#lost_parts > 0) and table.concat(lost_parts, ', ')
                or 'nothing lost'
            print(chat.header(addon.name)
                + chat.color1(76, '>>> ')
                + chat.message('Craft Broke - ')
                + chat.color1(CHAT_COLORS.lost, loststr))
        end
        if debug then
            local line = string.format(
                '0x006F IN synth-result: result=%d item=%d (%s) qty=%d  [%d bytes] %s',
                result, itemid, iname, count, e.size, craft_hexdump(e))
            craftlog_append(line)
            craftlog_flush()
            note(line)
        end
        return
    end
end)

ashita.events.register('packet_out', 'bovinect_out', function(e)
    if e.injected then return end
    if e.id ~= 0x0096 then return end

    -- State machine: a synth packet went out -> crafting in progress, and
    -- this is the start-to-start anchor for the interval. (Set here so it
    -- fires for BOTH our injected synths and manual ones the player does.)
    crafting          = true
    synth_start_clock = os.clock()

    if debug then
        -- New record per synth so the out/anim/result lines group together.
        craftlog_start_new_record()
        local line = string.format('0x0096 OUT synth-start: [%d bytes] %s',
            e.size, craft_hexdump(e))
        craftlog_append(line)
        craftlog_flush()
        note(line)
    end
end)

----------------------------------------------------------------------------------------------------
-- Synth feedback text (cooldown rejection, cancel, inventory full)
----------------------------------------------------------------------------------------------------
-- Exact strings per lorand-ffxi/autoSynth. These drive auto-craft tuning
-- and stop conditions.
ashita.events.register('text_in', 'bovinect_text', function(e)
    local msg = e.message_modified or e.message or ''
    if msg == '' then return end

    -- Capture craft level from chat (always, even when not auto-crafting):
    --   "Your alchemy skill reaches level 29." -> level 29
    --   "...skill rises 0.1 points."           -> increments aren't a level,
    --                                              but the "reaches level N" line is.
    -- Matches any craft ("alchemy", "smithing", etc.) generically.
    local lvl = msg:match('skill reaches level (%d+)')
    if lvl ~= nil then
        chat_craft_level = tonumber(lvl)
    end

    if not auto_running then return end

    if msg:find('You must wait longer before repeating that action', 1, true) then
        -- Interval too short. The rejected synth consumed nothing and did
        -- not start (no 0x0096 accepted), so clear crafting and bump.
        crafting = false
        auto_floor    = auto_interval + 1
        auto_interval = auto_floor
        auto_status   = string.format('floor found: %ds', auto_floor)
        note(string.format('cooldown hit -> interval locked at %ds', auto_floor))
        -- Reset the start anchor so the next attempt waits the full floor.
        synth_start_clock = os.clock()
        return
    end

    if msg:find('You cannot use that command during synthesis', 1, true) then
        -- Sent too early while a prior synth was still resolving. Bump a
        -- little and let the loop retry; don't treat as the hard floor.
        crafting = false
        if auto_floor == nil then
            auto_interval = auto_interval + 2
        end
        synth_start_clock = os.clock()
        return
    end

    if msg:find('Synthesis canceled', 1, true) then
        stop_auto('synthesis canceled')
        return
    end

    -- Inventory full -> nowhere to put results, stop.
    if msg:find('inventory is full', 1, true)
       or msg:find('cannot carry any more', 1, true) then
        stop_auto('inventory full')
        return
    end
end)

----------------------------------------------------------------------------------------------------
-- Craft Test (drives the RECIPE table defined above)
----------------------------------------------------------------------------------------------------

-- find_all_stacks: walk inventory (container 0) for every item whose
-- resource name matches `name` (case-insensitive). Returns:
--   stacks = { { slot=, count= }, ... }  (in slot order)
--   total  = sum of counts
--   id     = item id (from the first match; same for all stacks)
-- If nothing matches: empty stacks, total 0, id nil. This is how recipe
-- ids get resolved -- you type the name, we read the id off the bag.
local function find_all_stacks(name)
    local stacks, total, id = {}, 0, nil
    if name == nil or name == '' then return stacks, total, id end
    local target = string.lower(name)
    local inv = AshitaCore:GetMemoryManager():GetInventory()
    local res = AshitaCore:GetResourceManager()
    for i = 1, 80 do
        local item = inv:GetContainerItem(0, i)
        if item ~= nil and item.Id ~= 0 and item.Count > 0 then
            local r = res:GetItemById(item.Id)
            if r ~= nil and r.Name[1] ~= nil
               and string.lower(r.Name[1]) == target then
                stacks[#stacks + 1] = { slot = i, count = item.Count }
                total = total + item.Count
                id = id or item.Id
            end
        end
    end
    return stacks, total, id
end

-- inventory_free_slots: number of empty slots in the main inventory
-- (container 0). Uses the container's reported usable size when available
-- (GetContainerCountMax), since the real capacity varies with Mog-safe /
-- inventory expansions; falls back to the 80-slot hard cap otherwise.
-- A slot is "free" when it holds no item (Id == 0 or empty).
local function inventory_free_slots()
    local inv = AshitaCore:GetMemoryManager():GetInventory()
    -- Determine usable size. GetContainerCountMax may not exist on every
    -- build, so guard it; default to 80 (classic main-bag cap).
    local maxn = 80
    local ok, m = pcall(function() return inv:GetContainerCountMax(0) end)
    if ok and type(m) == 'number' and m > 0 then maxn = m end
    local used = 0
    for i = 1, maxn do
        local item = inv:GetContainerItem(0, i)
        if item ~= nil and item.Id ~= 0 and item.Count > 0 then
            used = used + 1
        end
    end
    return maxn - used, maxn, used
end

-- Minimum free slots required to start a synth. A successful craft places
-- the result item into the bag; with 0 free there's nowhere for it, and with
-- 1 a result that doesn't stack onto an existing slot (or yields multiple
-- item types) can still fail. Refuse below this floor.
local MIN_FREE_SLOTS = 2

-- allocate_slots: given the stacks for an ingredient and a needed qty,
-- return a per-unit slot list of length qty (or nil, errmsg if short).
-- Fills greedily from the first stack, then the next, etc. Taking N units
-- from one stack repeats that slot N times; spanning two stacks emits each
-- slot the appropriate number of times. The server auto-sorts, so either
-- form is accepted.
local function allocate_slots(stacks, total, need)
    if total < need then return nil end
    local out = {}
    local remaining = need
    for _, st in ipairs(stacks) do
        local take = math.min(st.count, remaining)
        for _ = 1, take do out[#out + 1] = st.slot end
        remaining = remaining - take
        if remaining <= 0 then break end
    end
    return out
end

-- do_craft_test: resolve RECIPE crystal + ingredients BY NAME against
-- current inventory, allocating each ingredient's qty across one or more
-- stacks (the server auto-sorts, so spanning stacks is fine), and send
-- one 0x0096 synth-start. Returns ok, msg.
do_craft_test = function()
    local c_stacks, c_total, crystal_id = find_all_stacks(RECIPE.crystal)
    if c_total < 1 then
        return false, 'no "' .. RECIPE.crystal .. '" in inventory'
    end
    local crystal_slot = c_stacks[1].slot

    -- Build (id, slot) pairs, expanding each ingredient by qty, pulling from
    -- multiple stacks when one isn't enough.
    local ingr_pairs = {}
    for _, ing in ipairs(RECIPE.ingredients) do
        if ing.name ~= nil and ing.name ~= '' then
            local stacks, total, id = find_all_stacks(ing.name)
            if total < 1 then
                return false, 'no "' .. ing.name .. '" in inventory'
            end
            local slots = allocate_slots(stacks, total, ing.qty)
            if slots == nil then
                return false, string.format('need %d %s, only %d total across %d stack(s)',
                    ing.qty, ing.name, total, #stacks)
            end
            for _, s in ipairs(slots) do
                ingr_pairs[#ingr_pairs + 1] = { id = id, slot = s }
            end
        end
    end

    -- INGREDIENT ORDER MATTERS. The real client sends synth ingredients ordered
    -- by item id ASCENDING, and the server matches the recipe against that
    -- order. Sending recipe-list order makes some recipes (e.g. Jusatsu) come
    -- back result=3 "no valid recipe" even though every id/slot is correct.
    -- Proven by diffing a working manual synth (ascending) vs the bot's failing
    -- one (recipe order). Sort by id, keeping each id paired with its own slot.
    table.sort(ingr_pairs, function(a, b)
        if a.id ~= b.id then return a.id < b.id end
        return a.slot < b.slot
    end)

    local ingr_ids   = {}
    local ingr_slots = {}
    for _, pr in ipairs(ingr_pairs) do
        ingr_ids[#ingr_ids + 1]     = pr.id
        ingr_slots[#ingr_slots + 1] = pr.slot
    end

    if #ingr_slots > MAX_INGREDIENTS then
        return false, string.format('recipe has %d ingredient slots (max %d)',
            #ingr_slots, MAX_INGREDIENTS)
    end

    -- INVENTORY FULL gate. A successful synth deposits the result item into
    -- the bag; with too few free slots it has nowhere to go (the synth fails
    -- and the mats are wasted). Refuse below MIN_FREE_SLOTS (2): 0 obviously
    -- has no room, and 1 isn't safe for results that don't stack onto an
    -- existing slot or that yield more than one item type.
    local free = inventory_free_slots()
    if free < MIN_FREE_SLOTS then
        return false, string.format('inventory full: %d free slot(s), need >= %d',
            free, MIN_FREE_SLOTS)
    end

    -- HARD RATE LIMIT -- absolute, last line of defense. No 0x0096 may leave
    -- the client within HARD_MIN_SEND_INTERVAL of the previous one. This is
    -- checked here, at the only send site, and cannot be bypassed by any
    -- caller. If we're inside the window, refuse outright (caller decides
    -- whether to retry later); we do NOT queue or delay-send.
    local now = os.clock()
    local since_send = now - last_packet_sent_clock
    if since_send < HARD_MIN_SEND_INTERVAL then
        return false, string.format('rate-limited: %.1fs since last send (min %.0fs)',
            since_send, HARD_MIN_SEND_INTERVAL)
    end

    -- Build the 36-byte payload (1-indexed; p[off+1] == byte at off).
    local p = {}
    for i = 1, 36 do p[i] = 0 end

    p[0x00 + 1] = 0x96
    p[0x01 + 1] = 0x12
    -- 0x02-0x03: sequence counter, stamped by the outbound pipeline.
    -- 0x04 = 0x53: required constant. Confirmed across multiple real client
    -- synth captures (always 0x53); the bot previously sent 0x3A here, which
    -- contributed to the server rejecting the packet.
    p[0x04 + 1] = 0x53
    -- 0x05, 0x12-0x19: client scratch -- varies per real synth and a capture
    -- with these all zero still succeeded, so we leave them zero.
    -- 0x06-0x07 = CRYSTAL ITEM ID (u16 LE). Previously hardcoded to 0x1001
    -- (Ice Crystal), which only matched the default Tsurara recipe; any other
    -- crystal (e.g. Wind 0x1002) produced a mismatched packet. Resolve it from
    -- the actual crystal stack instead.
    p[0x06 + 1] = crystal_id % 256
    p[0x07 + 1] = math.floor(crystal_id / 256) % 256
    p[0x08 + 1] = crystal_slot
    -- 0x09 = INGREDIENT COUNT. This was hardcoded to 0x03, which only worked for
    -- 3-ingredient recipes (Deodorizer). A 4-ingredient recipe (Mercury) needs
    -- 0x04, etc. Wrong count -> server returns result=3 (no matching recipe),
    -- the synth fires but produces nothing. Use the real count.
    p[0x09 + 1] = #ingr_slots
    -- ingredient ITEM IDS (u16 LE) starting at 0x0A
    for k = 1, #ingr_ids do
        local id   = ingr_ids[k]
        local base = 0x0A + (k - 1) * 2
        p[base + 1] = id % 256
        p[base + 2] = math.floor(id / 256) % 256
    end
    -- ingredient SLOTS (u8) starting at 0x1A
    for k = 1, #ingr_slots do
        p[0x1A + 1 + (k - 1)] = ingr_slots[k]
    end

    -- Stamp the send time BEFORE the actual send so any re-entrancy in the
    -- same frame is already blocked by the gate above.
    last_packet_sent_clock = now
    AshitaCore:GetPacketManager():AddOutgoingPacket(0x0096, p)

    -- State machine for our OWN (injected) synths. The packet_out handler
    -- ignores injected packets (e.injected), so it only catches MANUAL synths;
    -- we must set the crafting state here for bot-driven ones. Without this the
    -- auto loop never sees crafting=true, never waits for the result, and fires
    -- again on the hard-limit floor (~10s) -- stepping on the client's synth
    -- animation so the "you synthesized" message never shows. Anchor the
    -- interval here too.
    crafting          = true
    synth_start_clock = now

    -- Remember what we submitted (in order) so a break can name lost items.
    last_submitted_ids = {}
    for k = 1, #ingr_ids do last_submitted_ids[k] = ingr_ids[k] end

    -- Log the send next to the real captures for diffing -- debug only.
    if debug then
        local hex = {}
        for i = 1, 36 do hex[i] = string.format('%02X', p[i]) end
        local groups = {}
        for i = 1, #hex, 4 do
            groups[#groups + 1] = table.concat(hex, ' ', i, math.min(i + 3, #hex))
        end
        craftlog_append(string.format(
            'CRAFT TEST sent 0x0096 (%s, crystal_slot=%d, ingr_slots=[%s]): %s',
            RECIPE.name, crystal_slot, table.concat(ingr_slots, ','),
            table.concat(groups, '  ')))
        craftlog_flush()
    end

    return true, string.format('sent %s (crystal slot %d, %d ingredient slots)',
        RECIPE.name, crystal_slot, #ingr_slots)
end

-- recipe_available: true if the crystal + every ingredient (at required qty)
-- can currently be satisfied from inventory. Used by the auto loop to stop
-- when materials run out. Returns ok, reason.
local function recipe_available()
    local free = inventory_free_slots()
    if free < MIN_FREE_SLOTS then
        return false, string.format('inventory full (%d free)', free)
    end
    local _, c_total = find_all_stacks(RECIPE.crystal)
    if c_total < 1 then return false, 'out of ' .. RECIPE.crystal end
    for _, ing in ipairs(RECIPE.ingredients) do
        if ing.name ~= nil and ing.name ~= '' then
            local _, total = find_all_stacks(ing.name)
            if total < ing.qty then
                return false, 'out of ' .. ing.name
            end
        end
    end
    return true, nil
end

-- stop_auto: halt the auto-craft loop with a logged reason.
stop_auto = function(reason)
    if not auto_running then return end
    auto_running = false
    auto_status  = 'stopped: ' .. (reason or 'manual')
    note('auto craft stopped (' .. (reason or 'manual') .. ')')
end

-- auto_tick: called every frame from d3d_present. Drives the loop:
--   - waits until `auto_interval` has elapsed since the last synth START
--   - checks materials; stops if out
--   - fires the next synth
-- The crafting-in-progress gate and the start-to-start interval together
-- mean we never send while a synth is resolving, and never faster than the
-- (possibly still-being-tuned) cooldown.
local function auto_tick()
    if not auto_running then return end

    -- Self-recover from a missed result packet: if we've been "crafting"
    -- longer than SYNTH_TIMEOUT, assume the 0x006F was missed.
    if crafting and (os.clock() - synth_start_clock) > SYNTH_TIMEOUT then
        crafting = false
        note('synth result timeout -> assuming done')
    end

    if crafting then
        auto_status = 'Crafting...'
        return
    end

    local since = os.clock() - synth_start_clock
    if since < auto_interval then
        auto_status = string.format('next in %.0fs', auto_interval - since)
        return
    end

    -- Stop-at-level: if enabled and the watched craft skill has reached the
    -- target, stop before firing another synth.
    if stop_at_enabled[1] then
        local lvl = current_craft_level()
        if lvl ~= nil and lvl >= stop_at_level[1] then
            stop_auto(string.format('reached craft level %d', lvl))
            return
        end
    end

    -- Interval elapsed and not crafting -> check mats and fire.
    local ok, reason = recipe_available()
    if not ok then
        stop_auto(reason)
        return
    end

    local sent_ok, msg = do_craft_test()
    if not sent_ok then
        -- A rate-limit refusal is transient: hold and retry next tick rather
        -- than killing the loop. Any other failure (out of mats, etc.) stops.
        if msg and msg:find('rate-limited', 1, true) then
            auto_status = 'Crafting...'
            return
        end
        stop_auto(msg)
        return
    end
    -- synth_start_clock + crafting are set by the 0x0096 OUT handler.
    auto_status = 'Crafting...'
end

----------------------------------------------------------------------------------------------------
-- UI
----------------------------------------------------------------------------------------------------

ashita.events.register('d3d_present', 'bovinect_present', function()
    -- Drive the auto-craft loop and file picker every frame, even if the
    -- panel is hidden.
    auto_tick()
    poll_pick()
    poll_save()
    flush_cfg_if_dirty()

    if not ui_visible[1] then return end

    -- Auto-resize to fit content. SetNextWindowSize with no flag would lock
    -- a size; instead we let imgui size the window to its contents each frame.
    -- Global theme: pushed BEFORE Begin / popped AFTER End so the counts
    -- always balance. Style vars first, then colors.
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

    if imgui.Begin('bovinect', ui_visible, ImGuiWindowFlags_AlwaysAutoResize or 64) then
        local dbg = { debug }
        if imgui.Checkbox('Debug', dbg) then
            debug = dbg[1]
        end
        local sr = { show_results }
        if imgui.Checkbox('Show craft results in chat', sr) then
            show_results = sr[1]
        end
        local ss = { show_session }
        if imgui.Checkbox('Show Session Results', ss) then
            show_session = ss[1]
        end

        imgui.Separator()

        -- helper: live resolution status. Always shows "Total N"; the item id
        -- and per-stack slot breakdown are debug-only.
        local function resolved_status(name, need)
            if name == nil or name == '' then
                imgui.SameLine(); imgui.TextDisabled('(empty)')
                return
            end
            local stacks, total, id = find_all_stacks(name)
            if total < 1 then
                imgui.SameLine(); imgui.TextColored({ 1, 0.4, 0.4, 1 }, 'not found')
                return
            end
            local ok = (need == nil or total >= need)
            local col = ok and { 0.4, 1, 0.4, 1 } or { 1, 0.7, 0.3, 1 }
            imgui.SameLine()
            if debug then
                local parts = {}
                for _, st in ipairs(stacks) do
                    parts[#parts + 1] = string.format('s%d:%d', st.slot, st.count)
                end
                imgui.TextColored(col, string.format('Total %d  id %d  [%s]',
                    total, id, table.concat(parts, ', ')))
            else
                imgui.TextColored(col, string.format('Total %d', total))
            end
        end

        -- Recipe. The SAME widgets are always drawn so the window never
        -- changes shape; while a synth is in progress (`crafting`) the inputs
        -- and buttons are still rendered (identical footprint) but their edits
        -- are ignored, so the recipe can't change mid-craft. (Disable/grey
        -- styling doesn't work in this imgui build, so we just drop the
        -- committed result rather than visually disabling.)
        imgui.Text('Recipe:')
        local editable = not crafting

        imgui.PushItemWidth(140)
        if imgui.InputText('Name##recipe', edit_recipe_name, 64) and editable then
            RECIPE.name = edit_recipe_name[1]
            mark_cfg_dirty()
        end
        imgui.PopItemWidth()

        imgui.PushItemWidth(140)
        if imgui.InputText('Crystal##recipe', edit_crystal, 64) and editable then
            RECIPE.crystal = edit_crystal[1]
            mark_cfg_dirty()
        end
        imgui.PopItemWidth()
        resolved_status(RECIPE.crystal, 1)

        local remove_idx = nil
        for i, eb in ipairs(edit_ingredients) do
            imgui.PushItemWidth(140)
            if imgui.InputText('##ingname' .. i, eb.name, 64) and editable then
                RECIPE.ingredients[i].name = eb.name[1]
                mark_cfg_dirty()
            end
            imgui.PopItemWidth()

            imgui.SameLine()
            -- Tighter FramePadding for the value display + steppers so the
            -- cluster doesn't dominate the row.
            imgui.PushStyleVar(ImGuiStyleVar_FramePadding, { 2, 4 })

            -- Centered display + click-to-edit (same pattern as stop_at_level;
            -- see that block for the full rationale). `eb.editing` and
            -- `eb.editing_focus` are stored on the per-row edit buffer, so each
            -- ingredient tracks its own edit state. rebuild_edit_buffers() will
            -- naturally reset them on a recipe reload, which is fine.
            local QTY_FIELD_W = 22
            if eb.editing then
                if eb.editing_focus then
                    imgui.SetKeyboardFocusHere()
                    eb.editing_focus = false
                end
                imgui.PushItemWidth(QTY_FIELD_W)
                local commit = false
                if imgui.InputInt('##ingqty' .. i, eb.qty, 0, 0,
                                  ImGuiInputTextFlags_EnterReturnsTrue or 32)
                   and editable then
                    commit = true
                end
                if imgui.IsItemDeactivated() and editable then
                    commit = true
                end
                if commit then
                    if eb.qty[1] < 1 then eb.qty[1] = 1 end
                    RECIPE.ingredients[i].qty = eb.qty[1]
                    mark_cfg_dirty()
                    eb.editing = false
                end
                imgui.PopItemWidth()
            else
                imgui.PushStyleColor(ImGuiCol_Button,        { 0.16, 0.17, 0.21, 1.0 })
                imgui.PushStyleColor(ImGuiCol_ButtonHovered, { 0.22, 0.24, 0.30, 1.0 })
                imgui.PushStyleColor(ImGuiCol_ButtonActive,  { 0.28, 0.30, 0.38, 1.0 })
                if imgui.Button(string.format('%d##qtydisp%d', eb.qty[1], i),
                                { QTY_FIELD_W, 0 }) and editable then
                    eb.editing       = true
                    eb.editing_focus = true
                end
                imgui.PopStyleColor(3)
            end

            -- Manual [-]/[+] steppers.
            imgui.SameLine(0, 2)
            if imgui.Button('-##qtydec' .. i, { 12, 0 }) and editable then
                eb.qty[1] = math.max(1, eb.qty[1] - 1)
                RECIPE.ingredients[i].qty = eb.qty[1]
                mark_cfg_dirty()
            end
            imgui.SameLine(0, 2)
            if imgui.Button('+##qtyinc' .. i, { 12, 0 }) and editable then
                eb.qty[1] = eb.qty[1] + 1
                RECIPE.ingredients[i].qty = eb.qty[1]
                mark_cfg_dirty()
            end

            imgui.PopStyleVar()  -- restore default FramePadding

            imgui.SameLine()
            if imgui.SmallButton('x##rm' .. i) and editable then
                remove_idx = i
            end

            resolved_status(RECIPE.ingredients[i].name, RECIPE.ingredients[i].qty)
        end

        if remove_idx ~= nil then
            table.remove(RECIPE.ingredients, remove_idx)
            rebuild_edit_buffers()
            mark_cfg_dirty()
        end

        if #RECIPE.ingredients < MAX_INGREDIENTS then
            if imgui.SmallButton('+ Add Ingredient') and editable then
                RECIPE.ingredients[#RECIPE.ingredients + 1] = { name = '', qty = 1 }
                rebuild_edit_buffers()
                mark_cfg_dirty()
            end
        end

        if imgui.SmallButton('Load Craft') and editable then
            if not save_pending then pick_recipe_file() end
        end
        imgui.SameLine()
        if imgui.SmallButton('Save Craft') and editable then
            if not pick_pending then pick_save_recipe_file() end
        end
        if pick_pending then
            imgui.SameLine()
            imgui.TextDisabled('(load dialog open...)')
        elseif save_pending then
            imgui.SameLine()
            imgui.TextDisabled('(save dialog open...)')
        end

        -- Estimated total crafts: limited by whichever ingredient (or the
        -- crystal) runs out first. floor(total / per-synth qty), min across all.
        do
            local _, c_total = find_all_stacks(RECIPE.crystal)
            local est = c_total                     -- crystal: 1 per synth
            for _, ing in ipairs(RECIPE.ingredients) do
                if ing.name ~= nil and ing.name ~= '' and ing.qty > 0 then
                    local _, total = find_all_stacks(ing.name)
                    local can = math.floor(total / ing.qty)
                    if can < est then est = can end
                end
            end
            local col = (est > 0) and { 0.6, 0.9, 1, 1 } or { 1, 0.4, 0.4, 1 }
            imgui.TextColored(col, string.format('Estimated Total Crafts: %d', est))
        end

        -- Free inventory slots. Crafting is blocked below MIN_FREE_SLOTS so the
        -- synth result always has somewhere to land.
        do
            local free = inventory_free_slots()
            if free < MIN_FREE_SLOTS then
                imgui.TextColored({ 1, 0.4, 0.4, 1 },
                    string.format('Inventory: %d free (FULL - crafting blocked)', free))
            else
                imgui.TextDisabled(string.format('Inventory: %d free', free))
            end
        end

        imgui.Separator()

        -- Craft 1: single synth, 30s lockout after pressing. Drawn the
        -- bovinemage way -- always a Button with a FIXED size so the auto-resizing
        -- window never jumps; only the label changes, and the click is ignored
        -- while locked. (PushStyleColor/disable styling does not work in this
        -- imgui build, so we don't rely on it.)
        local now       = os.clock()
        local locked    = (now < craft1_lock_until)
        local lock_left = craft1_lock_until - now
        local craft1_label = locked
            and string.format('Craft 1 (%ds)', math.ceil(lock_left))
            or  'Craft 1'
        if imgui.Button(craft1_label, { 140, 0 }) and not locked then
            local ok, msg = do_craft_test()
            craft_test_msg = (ok and 'OK: ' or 'ERR: ') .. msg
            note('craft 1 -> ' .. msg)
            if ok then
                craft1_lock_until = now + CRAFT1_LOCKOUT
            end
        end

        -- Auto Craft: loop until out of ingredients. Toggle button, fixed size.
        if auto_running then
            if imgui.Button('Stop Auto', { 140, 0 }) then
                stop_auto('manual')
            end
            imgui.SameLine()
            imgui.TextColored({ 0.4, 1, 0.4, 1 }, auto_status)
        else
            if imgui.Button('Auto Craft', { 140, 0 }) then
                -- Pre-flight: don't start if we can't even make one.
                local ok, reason = recipe_available()
                if not ok then
                    auto_status = 'cannot start: ' .. reason
                    note('auto craft not started (' .. reason .. ')')
                else
                    auto_running      = true
                    -- Reset the start anchor to "long ago" so the first
                    -- attempt fires immediately rather than waiting a full
                    -- interval.
                    synth_start_clock = now - auto_interval
                    auto_status       = 'starting...'
                    note(string.format('auto craft started (interval %ds, %s)',
                        auto_interval, auto_floor and 'locked' or 'probing down from ' .. AUTO_START))
                end
            end
        end

        -- Interval readout. Shows probe state: "(probing)" while searching for
        -- the cooldown, or the locked floor once found.
        imgui.Text(string.format('Interval: %ds   %s', auto_interval,
            auto_floor and string.format('(floor %ds)', auto_floor) or '(probing down)'))
        if auto_status ~= '' and not auto_running then
            imgui.SameLine(); imgui.TextDisabled('| ' .. auto_status)
        end

        -- Stop-at-level: checkbox + target level input. Shows the current craft
        -- level read from memory next to it for reference.
        --
        -- The level value renders as a centered-text styled button by default
        -- and only becomes an editable InputInt when clicked. Reason: ImGui's
        -- InputText buffer is left-aligned and there is no center-align flag,
        -- so the only way to genuinely center the displayed number is to draw
        -- it via a Button (whose text IS centered) and swap to InputInt only
        -- during edit. The [-] and [+] buttons are drawn manually next to the
        -- field instead of relying on InputInt's built-in steppers (which are
        -- disabled here with step=0).
        local sae = { stop_at_enabled[1] }
        if imgui.Checkbox('Stop at level', sae) then
            stop_at_enabled[1] = sae[1]
        end
        imgui.SameLine()

        -- Tighter FramePadding for the value display + steppers makes the
        -- whole cluster ~40% narrower without affecting other widgets.
        imgui.PushStyleVar(ImGuiStyleVar_FramePadding, { 2, 4 })

        local LVL_FIELD_W = 22
        if editing_stoplvl.active then
            -- Edit mode: real InputInt, autofocused the first frame so the
            -- user can type immediately after clicking the display button.
            if editing_stoplvl.focus then
                imgui.SetKeyboardFocusHere()
                editing_stoplvl.focus = false
            end
            imgui.PushItemWidth(LVL_FIELD_W)
            -- step=0 hides the built-in [-]/[+] (we draw our own below).
            -- flag 32 = ImGuiInputTextFlags_EnterReturnsTrue.
            local commit = false
            if imgui.InputInt('##stoplvl', stop_at_level, 0, 0,
                              ImGuiInputTextFlags_EnterReturnsTrue or 32) then
                commit = true
            end
            -- IsItemDeactivated catches losing focus by clicking elsewhere.
            if imgui.IsItemDeactivated() then
                commit = true
            end
            if commit then
                if stop_at_level[1] < 1 then stop_at_level[1] = 1 end
                if stop_at_level[1] > 110 then stop_at_level[1] = 110 end
                editing_stoplvl.active = false
            end
            imgui.PopItemWidth()
        else
            -- Display mode: a Button styled to match the FrameBg of an
            -- InputText, with the value as its (auto-centered) label.
            imgui.PushStyleColor(ImGuiCol_Button,        { 0.16, 0.17, 0.21, 1.0 })
            imgui.PushStyleColor(ImGuiCol_ButtonHovered, { 0.22, 0.24, 0.30, 1.0 })
            imgui.PushStyleColor(ImGuiCol_ButtonActive,  { 0.28, 0.30, 0.38, 1.0 })
            if imgui.Button(string.format('%d##stoplvldisp', stop_at_level[1]),
                            { LVL_FIELD_W, 0 }) then
                editing_stoplvl.active = true
                editing_stoplvl.focus  = true
            end
            imgui.PopStyleColor(3)
        end

        -- Manual stepper buttons (replacing InputInt's hidden built-ins).
        imgui.SameLine(0, 2)
        if imgui.Button('-##stoplvldec', { 12, 0 }) then
            stop_at_level[1] = math.max(1, stop_at_level[1] - 1)
        end
        imgui.SameLine(0, 2)
        if imgui.Button('+##stoplvlinc', { 12, 0 }) then
            stop_at_level[1] = math.min(110, stop_at_level[1] + 1)
        end

        imgui.PopStyleVar()  -- restore default FramePadding

        imgui.SameLine()
        local curlvl = current_craft_level()
        imgui.TextDisabled(string.format('(craft now: %s)',
            curlvl ~= nil and tostring(curlvl) or '?'))

        -- Session results (gated by the checkbox up top).
        if show_session then
            imgui.Separator()
            imgui.Text(string.format('NQ: %d', session.nq))
            imgui.Text(string.format('HQ: %d', session.hq))
            imgui.Text(string.format('Broken: %d', session.broken))
            imgui.SameLine()
            if imgui.SmallButton('reset##session') then
                session.nq, session.hq, session.broken = 0, 0, 0
            end
        end

        if craft_test_msg ~= '' then
            imgui.TextColored(
                craft_test_msg:sub(1, 2) == 'OK' and { 0.4, 1, 0.4, 1 } or { 1, 0.4, 0.4, 1 },
                craft_test_msg)
        end

        -- Debug-only details: hard send-limit countdown + log path.
        if debug then
            local since_send = os.clock() - last_packet_sent_clock
            if since_send < HARD_MIN_SEND_INTERVAL then
                imgui.TextColored({ 1, 0.6, 0.3, 1 }, string.format(
                    'Hard send limit: %.0fs / %.0fs (blocked)',
                    since_send, HARD_MIN_SEND_INTERVAL))
            else
                imgui.TextDisabled(string.format('Hard send limit: %.0fs (ready)',
                    HARD_MIN_SEND_INTERVAL))
            end
            imgui.Separator()
            imgui.TextDisabled(string.format('log: %s', craftlog_path()))
        end
    end
    imgui.End()
    imgui.PopStyleColor(11)
    imgui.PopStyleVar(7)

    -- The window was open at the top of this handler (we early-return when
    -- it isn't). If imgui.Begin flipped ui_visible to false, the close-[X]
    -- was clicked this frame -> unload the addon entirely.
    if not ui_visible[1] then
        AshitaCore:GetChatManager():QueueCommand(1, '/addon unload bovinect')
    end
end)

----------------------------------------------------------------------------------------------------
-- Commands
----------------------------------------------------------------------------------------------------

local function split_command(cmd)
    local out = {}
    for tok in string.gmatch(cmd or '', '%S+') do
        out[#out + 1] = tok
    end
    return out
end

ashita.events.register('command', 'bovinect_command', function(e)
    local args = split_command(e.command)
    if #args < 1 then return end
    local cmd0 = args[1]:lower()
    if cmd0 ~= '/bovinect' and cmd0 ~= '/bct' then return end
    e.blocked = true

    local sub = args[2] and args[2]:lower() or 'ui'

    if sub == 'ui' or sub == 'panel' or sub == 'show' or sub == 'hide' then
        -- The panel is shown whenever the addon is loaded; closing it
        -- (hide / toggle-off / the window [X]) unloads the addon, so these
        -- map onto load/unload rather than a separate hidden state.
        if sub == 'show' then
            ui_visible[1] = true
            note('panel shown')
        else
            -- hide, or toggle while currently shown
            AshitaCore:GetChatManager():QueueCommand(1, '/addon unload bovinect')
        end
        return
    end

    if sub == 'test' or sub == 'craft1' or sub == 'craft' then
        local now = os.clock()
        if now < craft1_lock_until then
            note(string.format('Craft 1 locked for %.0fs more', craft1_lock_until - now))
            return
        end
        local ok, msg = do_craft_test()
        craft_test_msg = (ok and 'OK: ' or 'ERR: ') .. msg
        note('craft 1 -> ' .. msg)
        if ok then craft1_lock_until = now + CRAFT1_LOCKOUT end
        return
    end

    if sub == 'auto' then
        local action = args[3] and args[3]:lower() or 'toggle'
        if action == 'stop' or action == 'off' then
            stop_auto('manual')
        elseif auto_running then
            note('auto craft already running (' .. auto_status .. ')')
        else
            local ok, reason = recipe_available()
            if not ok then
                note('auto craft not started (' .. reason .. ')')
            else
                auto_running      = true
                synth_start_clock = os.clock() - auto_interval
                auto_status       = 'starting...'
                note(string.format('auto craft started (interval %ds, %s)',
                    auto_interval, auto_floor and 'locked' or 'probing'))
            end
        end
        return
    end

    if sub == 'debug' then
        local action = args[3] and args[3]:lower() or 'toggle'
        if action == 'on' then debug = true
        elseif action == 'off' then debug = false
        else debug = not debug end
        note(string.format('debug = %s', debug and 'ON' or 'OFF'))
        return
    end

    if sub == 'results' then
        local action = args[3] and args[3]:lower() or 'toggle'
        if action == 'on' then show_results = true
        elseif action == 'off' then show_results = false
        else show_results = not show_results end
        note(string.format('show_results = %s', show_results and 'ON' or 'OFF'))
        return
    end

    if sub == 'session' then
        local action = args[3] and args[3]:lower() or 'toggle'
        if action == 'reset' then
            session.nq, session.hq, session.broken = 0, 0, 0
            note('session results reset')
        elseif action == 'on' then show_session = true
        elseif action == 'off' then show_session = false
        else show_session = not show_session end
        if action ~= 'reset' then
            note(string.format('show_session = %s', show_session and 'ON' or 'OFF'))
        end
        note(string.format('session: NQ %d  HQ %d  Broken %d',
            session.nq, session.hq, session.broken))
        return
    end

    if sub == 'load' then
        -- /bct load <path>   -> load directly; /bct load -> open picker
        if args[3] then
            local path = table.concat(args, ' ', 3)
            load_recipe_file(path)
        else
            pick_recipe_file()
        end
        return
    end

    if sub == 'save' then
        -- /bct save <path>   -> save directly (overwrites); /bct save -> picker
        if args[3] then
            local path = table.concat(args, ' ', 3)
            save_recipe_file(path)
        else
            pick_save_recipe_file()
        end
        return
    end

    if sub == 'status' then
        note(string.format('debug: %s   results: %s',
            debug and 'ON' or 'OFF',
            show_results and 'ON' or 'OFF'))
        note(string.format('auto: %s   interval: %ds',
            auto_running and 'RUNNING' or 'off', auto_interval))
        note('recipe: ' .. RECIPE.name)
        if debug then note('log: ' .. craftlog_path()) end
        return
    end

    if sub == 'help' then
        note('/bct                    -- toggle the panel')
        note('/bct craft1             -- single synth (30s lockout)')
        note('/bct auto [stop]        -- start/stop the auto-craft loop')
        note('/bct results on|off     -- clean colored craft-result line')
        note('/bct session [reset]    -- show/reset NQ/HQ/Broken counts')
        note('/bct load [path]        -- load a recipe file (or open picker)')
        note('/bct save [path]        -- save current recipe (or open picker)')
        note('/bct debug on|off       -- capture packets + verbose detail')
        note('/bct status             -- print current settings')
        return
    end

    note('unknown subcommand: ' .. sub .. ' (try /bct help)')
end)

----------------------------------------------------------------------------------------------------
-- Load
----------------------------------------------------------------------------------------------------

ashita.events.register('load', 'bovinect_load', function()
    note('loaded. type /bct to toggle the panel')
end)

ashita.events.register('unload', 'bovinect_unload', function()
    auto_running = false
    save_config()   -- persist the current recipe so it reopens next time
end)
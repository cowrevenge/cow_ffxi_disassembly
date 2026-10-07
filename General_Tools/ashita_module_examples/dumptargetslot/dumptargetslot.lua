--[[---------------------------------------------------------------------------
  dumptargetslot - FFXI target slot finder (memory scan + refine)
  Standalone Ashita v4 addon. No XIUI dependency.

  Install path: <ashita>/addons/dumptargetslot/dumptargetslot.lua
  Load with:    /addon load dumptargetslot
  Toggle GUI:   /dumptargetslot

  Purpose
  -------
  Find the memory address that holds the sub-target entity index slot inside
  FFXI's target manager. Ashita's ITarget interface is read-only - it gives
  us GetTargetIndex(0/1) values but no way to write to the underlying slot,
  and Ashita's PointerManager doesn't expose a 'target' key, so we can't
  ask it for the structure address. Solution: scan memory for the value
  ITarget gave us, then refine.

  How it works (Cheat-Engine-style scan + refine)
  ------------------------------------------------
  1. Read GetTargetIndex(0) from the API - that's the current main target's
     entity index. Call it V.
  2. Scan a configurable memory range for every 4-byte aligned uint32 that
     equals V. Save addresses as candidates.
  3. Change target in-game. V is now a new value V'.
  4. Refine: filter the candidate list down to addresses whose current value
     equals V'. False positives drop away each refine pass.
  5. After 2-3 target changes you'll typically have 1-5 surviving candidates.
     One of them is the main target slot. The sub-target slot lives 4 or 8
     bytes adjacent (typical layout: { main_idx, sub_idx, ... }).
  6. Use the "Inspect ±N" feature to dump bytes around a candidate. Activate
     sub-target mode and watch which adjacent uint32 changes as the cursor
     moves through party members - that's the sub-target slot.
  7. Test the write via the Write panel: address of suspected sub slot,
     value = a partymember's entity index, click Write. Cursor should jump.

  Scan performance
  ----------------
  Scans run in chunks across frames (state machine in d3d_present) so the
  client stays responsive. Default chunk: 64KB per frame. Default range:
  0x01000000..0x06000000 (~80MB, covers most FFXiMain.dll data section
  locations - same region the hideparty primitives live in). Adjust via
  the Range fields if the candidates look wrong.

  Commands
  --------
  /dumptargetslot                              - toggle GUI
  /dumptargetslot write <hex_addr> <value>     - one-shot uint32 write
-----------------------------------------------------------------------------]]

addon.name    = 'dumptargetslot';
addon.author  = 'shadowcow';
addon.version = '2.0';
addon.desc    = 'Find target/subtarget slot offsets via memory scan + refine';

require('common');
local chat  = require('chat');
local imgui = require('imgui');

-- =============================================================================
-- State
-- =============================================================================
local state = {
    show_window = { false },

    -- Scan range (input strings - parsed when scan starts)
    range_start = { '0x01000000' },
    range_end   = { '0x06000000' },

    -- Per-frame chunk size during scan. Larger = faster scan, more frame hitch.
    -- 64KB / 4 = 16K reads per frame. At 60fps that's ~1M reads/sec. The
    -- default 80MB range = 20M reads = ~20 seconds. Fine for a one-shot scan.
    chunk_bytes = 0x10000,

    -- Scan state machine
    scanning      = false,
    scan_cursor   = 0,
    scan_end_addr = 0,
    scan_value    = 0,
    scan_chunk_ix = 0,  -- counter, just for status display

    -- Candidate list: each entry { addr, last_val }
    candidates = {},

    -- Selected candidate for inspection (an address from the list)
    inspect_addr = 0,
    inspect_span = { 32 },  -- bytes either side to dump

    -- Previous-frame uint32 values around inspect_addr, for change tinting
    prev_inspect = {},

    -- Write panel input strings
    write_addr = { '' },
    write_val  = { '' },
};

-- =============================================================================
-- Helpers
-- =============================================================================
local function parse_addr(s)
    if s == nil or s == '' then return nil; end
    local hex = s:match('^0[xX](%x+)$');
    if hex then return tonumber(hex, 16); end
    if s:match('[a-fA-F]') then return tonumber(s, 16); end
    return tonumber(s, 10);
end

local function safe_read_u32(addr)
    if addr == nil or addr == 0 then return nil; end
    local ok, v = pcall(ashita.memory.read_uint32, addr);
    if ok then return v; end
    return nil;
end

local function read_anchors()
    local a = { t0_idx = 0, t1_idx = 0, sub_active = false };
    local ok, target = pcall(function() return AshitaCore:GetMemoryManager():GetTarget(); end);
    if not ok or target == nil then return a; end
    pcall(function() a.t0_idx     = target:GetTargetIndex(0) or 0; end);
    pcall(function() a.t1_idx     = target:GetTargetIndex(1) or 0; end);
    pcall(function() a.sub_active = target:GetIsSubTargetActive() == true; end);
    return a;
end

-- =============================================================================
-- Scan: kicks off a scan for the current t0 index across the configured range
-- =============================================================================
local function start_scan(initial)
    local lo = parse_addr(state.range_start[1]);
    local hi = parse_addr(state.range_end[1]);
    if lo == nil or hi == nil or hi <= lo then
        print(chat.header('dumptargetslot'):append(chat.error(
            'Bad scan range. Use hex like 0x01000000.')));
        return;
    end

    local a = read_anchors();
    if a.t0_idx == 0 then
        print(chat.header('dumptargetslot'):append(chat.error(
            'GetTargetIndex(0) is 0 - target a real entity first.')));
        return;
    end

    state.scanning      = true;
    state.scan_cursor   = lo;
    state.scan_end_addr = hi;
    state.scan_value    = a.t0_idx;
    state.scan_chunk_ix = 0;

    if initial then
        state.candidates = {};
    end

    print(chat.header('dumptargetslot'):append(chat.message(string.format(
        '%s scan: range 0x%08X..0x%08X, target value=%d (0x%08X)',
        initial and 'Starting' or 'Refining', lo, hi, a.t0_idx, a.t0_idx
    ))));
end

-- Per-frame scan tick (called from d3d_present). Either an initial scan or
-- a refine - the initial scan adds candidates, refine filters them.
-- We split the two paths via state.candidates being empty (initial) or not
-- (refine).
local function scan_tick()
    if not state.scanning then return; end

    local chunk_remaining = state.chunk_bytes;
    local hits = 0;

    if #state.candidates == 0 then
        -- INITIAL scan: walk every 4-byte aligned uint32 in the chunk, add
        -- matches to candidates.
        while chunk_remaining > 0 and state.scan_cursor < state.scan_end_addr do
            local v = safe_read_u32(state.scan_cursor);
            if v == state.scan_value then
                table.insert(state.candidates, { addr = state.scan_cursor, last_val = v });
                hits = hits + 1;
            end
            state.scan_cursor   = state.scan_cursor + 4;
            chunk_remaining     = chunk_remaining - 4;
        end
    else
        -- REFINE: walk existing candidates, drop those that no longer match.
        -- Since this is one-shot (not chunked across cursor), do it all then
        -- finish.
        local kept = {};
        for _, c in ipairs(state.candidates) do
            local v = safe_read_u32(c.addr);
            if v == state.scan_value then
                table.insert(kept, { addr = c.addr, last_val = v });
            end
        end
        state.candidates  = kept;
        state.scan_cursor = state.scan_end_addr;  -- mark done
    end

    state.scan_chunk_ix = state.scan_chunk_ix + 1;

    if state.scan_cursor >= state.scan_end_addr then
        state.scanning = false;
        print(chat.header('dumptargetslot'):append(chat.message(string.format(
            'Scan complete. %d candidates remain.', #state.candidates
        ))));
    end
end

-- =============================================================================
-- Write
-- =============================================================================
local function do_write(addr, value)
    if addr == nil or addr == 0 then
        print(chat.header('dumptargetslot'):append(chat.error('Bad address.')));
        return;
    end
    local ok = pcall(ashita.memory.write_uint32, addr, value);
    if ok then
        print(chat.header('dumptargetslot'):append(chat.message(string.format(
            'Wrote 0x%08X (%d) to 0x%08X', value, value, addr))));
    else
        print(chat.header('dumptargetslot'):append(chat.error('Write failed.')));
    end
end

-- =============================================================================
-- GUI
-- =============================================================================
local function draw_window()
    if not state.show_window[1] then return; end

    imgui.SetNextWindowSize({ 760, 600 }, ImGuiCond_FirstUseEver);
    if imgui.Begin('dumptargetslot - target slot finder', state.show_window, 0) then

        -- ---- API anchors ----
        local a = read_anchors();
        imgui.TextColored({ 1.0, 0.85, 0.3, 1.0 }, 'API anchors:');
        imgui.Text(string.format('  GetTargetIndex(0) = %d  (0x%08X)', a.t0_idx, a.t0_idx));
        imgui.Text(string.format('  GetTargetIndex(1) = %d  (0x%08X)', a.t1_idx, a.t1_idx));
        imgui.Text(string.format('  SubTargetActive   = %s', tostring(a.sub_active)));
        imgui.Separator();

        -- ---- Scan controls ----
        imgui.TextColored({ 1.0, 0.85, 0.3, 1.0 }, 'Scan range (hex):');
        imgui.SetNextItemWidth(140);
        imgui.InputText('start', state.range_start, 32);
        imgui.SameLine();
        imgui.SetNextItemWidth(140);
        imgui.InputText('end', state.range_end, 32);
        imgui.SameLine();
        if state.scanning then
            imgui.TextColored({ 1.0, 0.6, 0.4, 1.0 }, string.format(
                'SCANNING... cursor=0x%08X (chunk #%d, %d candidates so far)',
                state.scan_cursor, state.scan_chunk_ix, #state.candidates
            ));
        else
            if imgui.Button('NEW Scan (clears candidates)') then
                start_scan(true);
            end
            imgui.SameLine();
            if imgui.Button('Refine (keep matching)') then
                if #state.candidates == 0 then
                    print(chat.header('dumptargetslot'):append(chat.error(
                        'No candidates yet - run NEW Scan first.')));
                else
                    start_scan(false);
                end
            end
            imgui.SameLine();
            if imgui.Button('Clear') then
                state.candidates = {};
            end
        end

        imgui.TextDisabled(
            'Workflow: target mob A, NEW Scan. Target mob B, Refine. Repeat 2-3x.\n' ..
            'Surviving candidates are likely the main target slot (slot 0).\n' ..
            'Sub-target slot is usually 4 or 8 bytes adjacent - use Inspect below.');
        imgui.Separator();

        -- ---- Candidates table ----
        imgui.TextColored({ 1.0, 0.85, 0.3, 1.0 }, string.format('Candidates: %d', #state.candidates));

        if #state.candidates > 0 then
            imgui.BeginChild('cand_list', { 0, 200 }, true);
            imgui.Columns(4, 'cand_cols', false);
            imgui.SetColumnWidth(0, 140);
            imgui.SetColumnWidth(1, 100);
            imgui.SetColumnWidth(2, 100);
            imgui.SetColumnWidth(3, 200);
            imgui.TextColored({ 1.0, 0.85, 0.3, 1.0 }, 'address');  imgui.NextColumn();
            imgui.TextColored({ 1.0, 0.85, 0.3, 1.0 }, 'value');    imgui.NextColumn();
            imgui.TextColored({ 1.0, 0.85, 0.3, 1.0 }, 'matches');  imgui.NextColumn();
            imgui.TextColored({ 1.0, 0.85, 0.3, 1.0 }, 'action');   imgui.NextColumn();
            imgui.Separator();

            for i, c in ipairs(state.candidates) do
                local cur = safe_read_u32(c.addr) or 0;
                local color = { 0.85, 0.85, 0.85, 1.0 };
                local match_label = '';
                if cur == a.t0_idx and a.t0_idx ~= 0 then
                    color = { 0.5, 1.0, 0.5, 1.0 };
                    match_label = 'GetTargetIndex(0)';
                elseif cur == a.t1_idx and a.t1_idx ~= 0 then
                    color = { 1.0, 1.0, 0.5, 1.0 };
                    match_label = 'GetTargetIndex(1) **SUB SLOT**';
                end

                imgui.TextColored(color, string.format('0x%08X', c.addr));
                imgui.NextColumn();
                imgui.TextColored(color, tostring(cur));
                imgui.NextColumn();
                imgui.TextColored(color, match_label);
                imgui.NextColumn();
                if imgui.Button(string.format('Inspect##cand%d', i)) then
                    state.inspect_addr = c.addr;
                    state.prev_inspect = {};
                end
                imgui.NextColumn();
            end

            imgui.Columns(1);
            imgui.EndChild();
        end

        imgui.Separator();

        -- ---- Inspect panel ----
        imgui.TextColored({ 1.0, 0.85, 0.3, 1.0 }, string.format(
            'Inspect bytes around: 0x%08X', state.inspect_addr));
        imgui.SetNextItemWidth(160);
        imgui.SliderInt('span (+/- bytes)', state.inspect_span, 16, 256);
        imgui.SameLine();
        if imgui.Button('Reset change tracking') then
            state.prev_inspect = {};
        end

        if state.inspect_addr ~= 0 then
            imgui.BeginChild('inspect_list', { 0, 200 }, true);
            imgui.Columns(5, 'insp_cols', false);
            imgui.SetColumnWidth(0, 80);
            imgui.SetColumnWidth(1, 120);
            imgui.SetColumnWidth(2, 100);
            imgui.SetColumnWidth(3, 80);
            imgui.SetColumnWidth(4, 200);
            imgui.TextColored({ 1.0, 0.85, 0.3, 1.0 }, 'offset');  imgui.NextColumn();
            imgui.TextColored({ 1.0, 0.85, 0.3, 1.0 }, 'address'); imgui.NextColumn();
            imgui.TextColored({ 1.0, 0.85, 0.3, 1.0 }, 'uint32');  imgui.NextColumn();
            imgui.TextColored({ 1.0, 0.85, 0.3, 1.0 }, 'decimal'); imgui.NextColumn();
            imgui.TextColored({ 1.0, 0.85, 0.3, 1.0 }, 'match');   imgui.NextColumn();
            imgui.Separator();

            local span = state.inspect_span[1];
            local base = state.inspect_addr - span;
            -- Round down to 4-byte boundary
            base = base - (base % 4);

            for off = 0, span * 2 - 4, 4 do
                local addr = base + off;
                local v = safe_read_u32(addr);
                local prev = state.prev_inspect[addr];
                local changed = (prev ~= nil and v ~= nil and prev ~= v);

                local color = { 0.85, 0.85, 0.85, 1.0 };
                local match_label = '';
                if v ~= nil then
                    if v == a.t0_idx and a.t0_idx ~= 0 then
                        color = { 0.5, 1.0, 0.5, 1.0 };
                        match_label = '== t0';
                    elseif v == a.t1_idx and a.t1_idx ~= 0 then
                        color = { 1.0, 1.0, 0.5, 1.0 };
                        match_label = '== t1 **SUB**';
                    end
                end
                if changed then color = { 1.0, 0.4, 0.4, 1.0 }; end
                if addr == state.inspect_addr then
                    -- Mark the seed address visually with a leading >
                    imgui.TextColored(color, '> ' .. string.format('%+d', addr - state.inspect_addr));
                else
                    imgui.TextColored(color, string.format('%+d', addr - state.inspect_addr));
                end
                imgui.NextColumn();
                imgui.TextColored(color, string.format('0x%08X', addr));
                imgui.NextColumn();
                imgui.TextColored(color, v and string.format('0x%08X', v) or '(read fail)');
                imgui.NextColumn();
                imgui.TextColored(color, v and tostring(v) or '-');
                imgui.NextColumn();
                imgui.TextColored(color, match_label);
                imgui.NextColumn();

                state.prev_inspect[addr] = v;
            end

            imgui.Columns(1);
            imgui.EndChild();
        end

        imgui.Separator();

        -- ---- Write panel ----
        imgui.TextColored({ 1.0, 0.85, 0.3, 1.0 }, 'Manual write (uint32):');
        imgui.SetNextItemWidth(140);
        imgui.InputText('addr##w', state.write_addr, 32);
        imgui.SameLine();
        imgui.SetNextItemWidth(140);
        imgui.InputText('value##w', state.write_val, 32);
        imgui.SameLine();
        if imgui.Button('Write##w') then
            local addr = parse_addr(state.write_addr[1]);
            local val  = parse_addr(state.write_val[1]);
            if addr == nil or val == nil then
                print(chat.header('dumptargetslot'):append(chat.error(
                    'Need hex addr and hex/decimal value.')));
            else
                do_write(addr, val);
            end
        end

        imgui.End();
    end
end

-- =============================================================================
-- Events
-- =============================================================================
ashita.events.register('d3d_present', 'dumptargetslot_present_cb', function ()
    -- Scan ticks here so the work spreads across frames.
    if state.scanning then scan_tick(); end
    draw_window();
end);

ashita.events.register('command', 'dumptargetslot_cmd_cb', function (e)
    local args = e.command:args();
    if #args == 0 then return; end
    if args[1] ~= '/dumptargetslot' then return; end

    e.blocked = true;

    if #args == 1 then
        state.show_window[1] = not state.show_window[1];
        return;
    end

    if #args >= 3 and args[2] == 'write' then
        local addr = parse_addr(args[3]);
        local val  = parse_addr(args[4] or '0');
        if addr == nil or val == nil then
            print(chat.header('dumptargetslot'):append(chat.error(
                'usage: /dumptargetslot write <addr> <value>')));
            return;
        end
        do_write(addr, val);
        return;
    end

    print(chat.header('dumptargetslot'):append(chat.message('Commands:')));
    print(chat.header('dumptargetslot'):append(chat.message('  /dumptargetslot                       - toggle GUI')));
    print(chat.header('dumptargetslot'):append(chat.message('  /dumptargetslot write <addr> <val>    - one-shot uint32 write')));
end);
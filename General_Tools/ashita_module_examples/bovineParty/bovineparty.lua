--[[
* bovineparty - Ashita v4
*
* Functionality:
*   - Auto-accepts party invites from anyone in the whitelist (via /join).
*   - Drops a party only when I am the sole member (via /pcmd leave).
*
* Whitelist:
*   Names are loaded from whitelist.txt sitting next to this .lua file.
*   One name per line; '#' starts a comment; blank lines ignored; matching
*   is case-insensitive.
*
* Commands:
*   /bovineparty reload  - re-read whitelist.txt without restarting
*   /bovineparty list    - print currently loaded names
]]--

addon.author    = 'shadowcow';
addon.name      = 'bovineparty';
addon.version   = '1.5.0';
addon.desc      = 'Auto-accept party invites and drop solo parties.';

require 'common';

----------------------------------------------------------------------------------------------------
-- Configuration
----------------------------------------------------------------------------------------------------

local WHITELIST_FILE = 'whitelist.txt';

local CHECK_INTERVAL = 2.0;   -- seconds between polled party-state checks
local LEAVE_COOLDOWN = 10.0;  -- min seconds between /pcmd leave attempts
local ZONE_LOCK      = 15.0;  -- seconds after a zone-in before the leave path re-arms
local STABLE_POLLS   = 3;     -- consecutive polls the solo state must hold before acting

----------------------------------------------------------------------------------------------------
-- State
----------------------------------------------------------------------------------------------------

local accept_from = T{};      -- lowercased names loaded from whitelist.txt
local last_check  = 0;
local last_leave  = 0;
local poll_broken = false;    -- set true if the party API errors; disables polling
local leave_tries = 0;        -- consecutive /pcmd leave attempts on the same stuck state
local debug_on    = false;    -- /bovineparty debug: print raw party signals on change
local last_dbg    = nil;      -- last debug line printed, to avoid spam
local was_grouped = false;    -- seen 2+ on the roster this session (party then emptied)
local zoning      = false;    -- true between zone-out and zone-in
local zone_lock   = 0;        -- os.clock() value the leave path re-arms at
local solo_streak = 0;        -- consecutive polls we've looked like a stuck 1-man party

----------------------------------------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------------------------------------

local function msg(s)
    print('\31\200[\31\05bovineparty\31\200]\31\130 ' .. s);
end

local function whitelist_path()
    return ('%saddons/%s/%s'):format(AshitaCore:GetInstallPath(), addon.name, WHITELIST_FILE);
end

-- Strip comment + trim. Returns nil for blank/comment-only lines.
local function parse_line(line)
    local s = line:gsub('#.*$', '');
    s = s:gsub('^%s+', ''):gsub('%s+$', '');
    if (#s == 0) then return nil; end
    return s:lower();
end

-- (Re)load whitelist.txt into accept_from.
local function load_whitelist()
    local path = whitelist_path();
    local f = io.open(path, 'r');
    if (f == nil) then
        accept_from = T{};
        msg('whitelist.txt not found at: ' .. path);
        msg('Create the file with one name per line. Auto-accept is disabled until then.');
        return;
    end

    local names = T{};
    for line in f:lines() do
        local name = parse_line(line);
        if (name ~= nil) then
            table.insert(names, name);
        end
    end
    f:close();

    accept_from = names;
    if (#accept_from == 0) then
        msg('Loaded whitelist.txt (empty).');
    else
        msg(('Loaded %d name(s) from whitelist.txt:'):format(#accept_from));
        for _, n in ipairs(accept_from) do
            msg('  \30\03' .. n);
        end
    end
end

-- Our own character name, via the entity behind party slot 0 (always us).
local function self_name()
    local ok, n = pcall(function ()
        local idx = AshitaCore:GetMemoryManager():GetParty():GetMemberTargetIndex(0);
        return AshitaCore:GetMemoryManager():GetEntity():GetName(idx);
    end);
    if (not ok or n == nil or #n == 0) then return nil; end
    return n;
end

-- Reads the party roster by name.
--
-- Slots 0-5 are our party, 6-17 are alliance parties 2 and 3. A slot counts as
-- occupied only if it is active AND has a name.
--
-- (For the record: GetMemberNumber(idx) is that member's position number inside
-- its party, not a headcount. It reads 1 in a 2-man party, which is what was
-- dropping real parties.)
--
-- Returns { party = {names}, ally = {names}, me = name }, ok.
local function read_party()
    local ok, st = pcall(function ()
        local party = AshitaCore:GetMemoryManager():GetParty();
        if (party == nil) then return nil; end

        local function member(i)
            local a = party:GetMemberIsActive(i);
            if (a == nil or a == false or a == 0) then return nil; end
            local n = party:GetMemberName(i);
            if (n == nil or #n == 0) then return nil; end
            return n;
        end

        -- Optional methods: not every build binds all of them.
        local function try(fn)
            local good, v = pcall(fn);
            if (good) then return v; end
            return nil;
        end

        local st = { party = {}, ally = {} };

        -- "Am I actually in a party" signals. These are the only things that
        -- separate a real 1-man party from not being in a party at all, since
        -- the roster looks the same either way (we always occupy slot 0).
        st.num0    = try(function () return party:GetMemberNumber(0); end);
        st.pleader = try(function () return party:GetAlliancePartyLeaderServerId1(); end);
        st.aleader = try(function () return party:GetAllianceLeaderServerId(); end);
        st.pcount1 = try(function () return party:GetAlliancePartyMemberCount1(); end);

        -- Per the Ashita SDK, allianceinfo_t.PartyLeaderServerId1 is the leader of
        -- the LOCAL player's party and PartyMemberCount1 is its headcount, so those
        -- are the honest "is there a party" fields. MemberNumber is a position, not
        -- a count, and reads 0 for us either way, so it is diagnostics only now.
        -- Confirmed in a live stuck 1-man party on HorizonXI:
        --   num0=0  pleader=138355  aleader=0  pcount1=1
        -- num0 is 0 in that state AND when genuinely solo, so it is diagnostics
        -- only. Require both alliance fields to agree before acting.
        if (st.pleader ~= nil) then
            st.in_party = (st.pleader ~= 0)
                      and (st.pcount1 == nil or st.pcount1 > 0);
        elseif (st.pcount1 ~= nil) then
            st.in_party = (st.pcount1 > 0);
        else
            st.in_party = false;
        end

        for i = 0, 5 do
            local n = member(i);
            if (n ~= nil) then table.insert(st.party, n); end
        end
        for i = 6, 17 do
            local n = member(i);
            if (n ~= nil) then table.insert(st.ally, n); end
        end

        return st;
    end);
    if (not ok or st == nil) then return nil, false; end

    st.me = self_name();
    return st, true;
end

----------------------------------------------------------------------------------------------------
-- Event: load
----------------------------------------------------------------------------------------------------
ashita.events.register('load', 'load_cb', function ()
    load_whitelist();
end);

----------------------------------------------------------------------------------------------------
-- Event: command
-- /bovineparty reload | /bovineparty list
----------------------------------------------------------------------------------------------------
ashita.events.register('command', 'command_cb', function (e)
    local args = e.command:args();
    if (#args == 0) then return; end
    if (args[1]:lower() ~= '/bovineparty') then return; end

    e.blocked = true;

    local sub = (args[2] or 'help'):lower();
    if (sub == 'reload') then
        load_whitelist();
    elseif (sub == 'list') then
        if (#accept_from == 0) then
            msg('Whitelist is empty.');
        else
            msg(('Accepting from %d name(s):'):format(#accept_from));
            for _, n in ipairs(accept_from) do
                msg('  \30\03' .. n);
            end
        end
    elseif (sub == 'status') then
        local st, ok = read_party();
        if (not ok) then
            msg('Party API unavailable.');
        else
            local left = zone_lock - os.clock();
            msg(('me: %s | in_party: %s | was_grouped: %s')
                :format(tostring(st.me), tostring(st.in_party), tostring(was_grouped)));
            msg(('zoning: %s | zone lock: %s | solo streak: %d/%d')
                :format(tostring(zoning),
                        (left > 0) and ('%.1fs'):format(left) or 'clear',
                        solo_streak, STABLE_POLLS));
            msg(('party (%d): %s'):format(#st.party, table.concat(st.party, ', ')));
            msg(('alliance (%d): %s'):format(#st.ally, table.concat(st.ally, ', ')));
            msg(('raw -> num0: %s  pleader: %s  aleader: %s  pcount1: %s')
                :format(tostring(st.num0), tostring(st.pleader),
                        tostring(st.aleader), tostring(st.pcount1)));
        end
    elseif (sub == 'probe') then
        local party = AshitaCore:GetMemoryManager():GetParty();
        local function try(fn)
            local good, v = pcall(fn);
            if (good) then return tostring(v); end
            return 'n/a';
        end
        msg('--- allianceinfo ---');
        msg(('aleader:%s  pleader1:%s  pleader2:%s  pleader3:%s')
            :format(try(function () return party:GetAllianceLeaderServerId(); end),
                    try(function () return party:GetAlliancePartyLeaderServerId1(); end),
                    try(function () return party:GetAlliancePartyLeaderServerId2(); end),
                    try(function () return party:GetAlliancePartyLeaderServerId3(); end)));
        msg(('count1:%s count2:%s count3:%s  vis1:%s vis2:%s vis3:%s  invited:%s inviteparty:%s')
            :format(try(function () return party:GetAlliancePartyMemberCount1(); end),
                    try(function () return party:GetAlliancePartyMemberCount2(); end),
                    try(function () return party:GetAlliancePartyMemberCount3(); end),
                    try(function () return party:GetAlliancePartyVisible1(); end),
                    try(function () return party:GetAlliancePartyVisible2(); end),
                    try(function () return party:GetAlliancePartyVisible3(); end),
                    try(function () return party:GetAllianceInvited(); end),
                    try(function () return party:GetAllianceInviteParty(); end)));
        msg('--- members 0-2 ---');
        for i = 0, 2 do
            msg(('[%d] active:%s idx:%s num:%s flags:%s name:%s')
                :format(i,
                        try(function () return party:GetMemberIsActive(i); end),
                        try(function () return party:GetMemberIndex(i); end),
                        try(function () return party:GetMemberNumber(i); end),
                        try(function () return party:GetMemberFlagMask(i); end),
                        try(function () return party:GetMemberName(i); end)));
        end
    elseif (sub == 'debug') then
        debug_on = not debug_on;
        last_dbg = nil;
        msg('Debug output ' .. (debug_on and 'ON' or 'OFF'));
    elseif (sub == 'leave') then
        last_leave  = 0;
        leave_tries = 0;
        AshitaCore:GetChatManager():QueueCommand(1, '/pcmd leave');
        msg('Manual leave sent.');
    else
        msg('Commands: reload | list | status | probe | debug | leave');
    end
end);

----------------------------------------------------------------------------------------------------
-- Event: packet_in
-- Auto-accept invites from approved names by issuing /join.
----------------------------------------------------------------------------------------------------
ashita.events.register('packet_in', 'packet_in_cb', function (e)
    -- Zone transitions. Party memory is blanked on the way out and repopulates
    -- a beat behind on the way in, so hold the leave path off until it resyncs.
    if (e.id == 0x0B) then          -- leaving zone
        zoning      = true;
        solo_streak = 0;
        return;
    elseif (e.id == 0x0A) then      -- zoned in
        zoning      = false;
        zone_lock   = os.clock() + ZONE_LOCK;
        solo_streak = 0;
        return;
    end

    if (e.id ~= 0xDC) then return; end

    local name = struct.unpack('s', e.data, 0x0C + 1);
    if (name == nil or #name == 0) then return; end

    if (not accept_from:contains(name:lower())) then return; end

    AshitaCore:GetChatManager():QueueCommand(1, '/join');
    msg('Auto-accepted invite from: \30\03' .. name);
end);

----------------------------------------------------------------------------------------------------
-- Event: d3d_present
-- Polls the roster. Drops the party when our name is the only name on it and
-- there are no alliance members, gated on there actually being a party. The gate
-- matters because with no party at all the roster still shows just us.
--
-- Two independent ways to satisfy the gate:
--   in_party    - allianceinfo says a party exists
--   was_grouped - we watched 2+ people on the roster earlier this session, so a
--                 roster that has since emptied to just us is the stuck party
-- Wrapped in pcall so an unbound API method disables the path with a notice
-- rather than killing the addon.
----------------------------------------------------------------------------------------------------
ashita.events.register('d3d_present', 'present_cb', function ()
    if (poll_broken) then return; end

    local now = os.clock();
    if (now - last_check < CHECK_INTERVAL) then return; end
    last_check = now;

    -- Mid-zone or inside the post-zone settle window: read nothing into it.
    if (zoning or now < zone_lock) then
        solo_streak = 0;
        return;
    end

    local st, ok = read_party();
    if (not ok) then
        poll_broken = true;
        msg('Party polling API unavailable; auto-leave disabled.');
        return;
    end

    local raw = ('p=%d a=%d in_party=%s grouped=%s streak=%d num0=%s pleader=%s aleader=%s pcount1=%s')
        :format(#st.party, #st.ally, tostring(st.in_party), tostring(was_grouped),
                solo_streak, tostring(st.num0), tostring(st.pleader),
                tostring(st.aleader), tostring(st.pcount1));

    if (debug_on and raw ~= last_dbg) then
        last_dbg = raw;
        msg(raw);
    end

    -- Anyone else on the roster: remember it and leave the party alone.
    if (#st.party >= 2 or #st.ally > 0) then
        was_grouped = true;
        leave_tries = 0;
        solo_streak = 0;
        return;
    end

    -- Only us on the roster. Is there actually a party here?
    if (not st.in_party and not was_grouped) then
        leave_tries = 0;
        solo_streak = 0;
        return;
    end

    -- Sanity: that one name has to be us.
    if (st.me == nil or #st.party ~= 1 or st.party[1]:lower() ~= st.me:lower()) then
        leave_tries = 0;
        solo_streak = 0;
        return;
    end

    -- Hold until the same picture repeats, so a single stale or half-synced read
    -- can never trigger a drop.
    solo_streak = solo_streak + 1;
    if (solo_streak < STABLE_POLLS) then return; end

    if (leave_tries >= 3) then return; end
    if (now - last_leave < LEAVE_COOLDOWN) then return; end

    last_leave  = now;
    leave_tries = leave_tries + 1;
    solo_streak = 0;
    AshitaCore:GetChatManager():QueueCommand(1, '/pcmd leave');
    msg('Solo party detected, dropping.');

    -- If we got here on the was_grouped latch alone, allianceinfo can't confirm
    -- the leave worked, so treat one shot as enough and disarm.
    if (not st.in_party) then
        was_grouped = false;
        leave_tries = 0;
        return;
    end

    if (leave_tries >= 3) then
        was_grouped = false;
        msg('Leave did not stick after 3 tries; standing down. Raw state was:');
        msg('  ' .. raw);
    end
end);
addon.name = 'latentchecker'
addon.author = 'OpenAI'
addon.version = '2.5'

require('common')
local imgui = require('imgui')
local bit = require('bit')

local ok_extdata, extdata = pcall(require, 'extdata')

local lc = {
    target_item = 'spear of trials',
    player_name = 'Cowrevenge',

    base_count = 0,
    extra_count = 0,
    total_count = 0,

    visible = { true },
    pos = { 300, 200 },
    size = { 190, 86 },
}

local function sanitize_log_text(text)
    text = tostring(text or '')
    text = text:gsub('\r', ' ')
    text = text:gsub('\n', ' ')
    text = text:gsub('’', "'")
    text = text:gsub('`', "'")
    text = text:gsub('%s+', ' ')
    text = text:gsub('^%s+', '')
    text = text:gsub('%s+$', '')
    return text
end

local function escape_lua_pattern(s)
    return tostring(s or ''):gsub('([^%w])', '%%%1')
end

local function normalize_action_name(name)
    if type(name) ~= 'string' then
        return nil
    end

    local s = sanitize_log_text(name):lower()
    s = s:gsub('%s+on%s+.+$', '')
    s = s:gsub(',%s+but%s+.+$', '')
    s = s:gsub('%s+but%s+.+$', '')
    s = s:gsub(',%s+and%s+.+$', '')
    s = s:gsub('%s+and%s+.+$', '')
    s = s:gsub('%.%s*$', '')
    s = s:gsub('^%s+', '')
    s = s:gsub('%s+$', '')
    return (#s > 0) and s or nil
end

local function parse_player_action_name(player_name, text)
    if type(text) ~= 'string' then
        return nil
    end

    local sl = sanitize_log_text(text):lower()
    local player_pat = escape_lua_pattern((player_name or ''):lower())

    local action = sl:match('^' .. player_pat .. '%s+readies%s+(.+)$')
    if not action then
        action = sl:match('^' .. player_pat .. '%s+uses%s+(.+)$')
    end
    if not action then
        action = sl:match('^you%s+ready%s+(.+)$')
    end
    if not action then
        action = sl:match('^you%s+use%s+(.+)$')
    end
    if not action then
        return nil
    end

    return normalize_action_name(action)
end

local function refresh_total()
    lc.total_count = (tonumber(lc.base_count) or 0) + (tonumber(lc.extra_count) or 0)
end

local function get_inventory_manager()
    local inv = nil

    if AshitaCore ~= nil and AshitaCore.GetDataManager ~= nil then
        local ok_dm, dm = pcall(function()
            return AshitaCore:GetDataManager()
        end)
        if ok_dm and dm ~= nil and dm.GetInventory ~= nil then
            local ok_inv, obj = pcall(function()
                return dm:GetInventory()
            end)
            if ok_inv and obj ~= nil then
                inv = obj
            end
        end
    end

    if inv ~= nil then
        return inv
    end

    if AshitaCore ~= nil and AshitaCore.GetMemoryManager ~= nil then
        local ok_mm, mm = pcall(function()
            return AshitaCore:GetMemoryManager()
        end)
        if ok_mm and mm ~= nil and mm.GetInventory ~= nil then
            local ok_inv, obj = pcall(function()
                return mm:GetInventory()
            end)
            if ok_inv and obj ~= nil then
                inv = obj
            end
        end
    end

    return inv
end

local function get_item_name_by_id(item_id)
    local rm = AshitaCore:GetResourceManager()
    if rm == nil then
        return nil
    end

    local res = rm:GetItemById(tonumber(item_id))
    if res == nil then
        return nil
    end

    if res.Name ~= nil then
        return tostring(res.Name[0] or '')
    end

    return nil
end

local function get_item_extdata_blob(item)
    if item == nil then
        return nil
    end

    local fields = {
        'Extra',
        'ExtraData',
        'ExtraBytes',
        'ExtData',
        'Extdata',
    }

    for _, k in ipairs(fields) do
        local ok, v = pcall(function()
            return item[k]
        end)
        if ok and v ~= nil then
            return v
        end
    end

    return nil
end

local function decode_ws_points_from_item(item)
    if not ok_extdata or extdata == nil then
        return nil, 'extdata library not loaded'
    end
    if item == nil then
        return nil, 'item is nil'
    end

    local blob = get_item_extdata_blob(item)
    if blob == nil then
        return nil, 'no extdata field found on item'
    end

    local ok, decoded = pcall(function()
        return extdata.decode(blob)
    end)
    if not ok or type(decoded) ~= 'table' then
        return nil, 'extdata.decode failed'
    end

    local wsp = tonumber(decoded.ws_points or 0)
    return wsp, nil
end

local function find_target_item()
    local inv = get_inventory_manager()
    if inv == nil then
        return nil, nil, 'inventory manager not available'
    end

    local max_slots = 80

    if inv.GetContainerMax ~= nil then
        local ok_max, value = pcall(function()
            return inv:GetContainerMax(0)
        end)
        if ok_max and value ~= nil then
            value = tonumber(value)
            if value ~= nil and value > 0 then
                max_slots = value
            end
        end
    end

    for i = 1, max_slots do
        local ok_item, item = pcall(function()
            return inv:GetItem(0, i)
        end)

        if ok_item and item ~= nil then
            local item_id = tonumber(item.Id or 0) or 0
            if item_id > 0 then
                local name = get_item_name_by_id(item_id)
                if name ~= nil and sanitize_log_text(name):lower() == lc.target_item then
                    return item, i, nil
                end
            end
        end
    end

    return nil, nil, 'spear not found'
end

local function sync_latent()
    local item, slot, err = find_target_item()
    if item == nil then
        AshitaCore:GetChatManager():QueueCommand(1, ('/echo [LC] %s'):format(tostring(err or 'sync failed')))
        return false
    end

    local wsp, decode_err = decode_ws_points_from_item(item)
    if wsp == nil then
        AshitaCore:GetChatManager():QueueCommand(
            1,
            ('/echo [LC] slot %d decode failed: %s'):format(tonumber(slot or 0) or 0, tostring(decode_err or 'unknown'))
        )
        return false
    end

    lc.base_count = wsp
    refresh_total()

    AshitaCore:GetChatManager():QueueCommand(
        1,
        ('/echo [LC] Sync base:%d extra:%d total:%d'):format(lc.base_count, lc.extra_count, lc.total_count)
    )
    return true
end

ashita.events.register('load', 'latentchecker_load', function()
    refresh_total()
    AshitaCore:GetChatManager():QueueCommand(1, '/echo [LC] loaded')
end)

ashita.events.register('text_in', 'latentchecker_text_in', function(e)
    local text = nil

    if type(e.message) == 'string' and #e.message > 0 then
        text = e.message
    elseif type(e.text) == 'string' and #e.text > 0 then
        text = e.text
    elseif type(e.modified) == 'string' and #e.modified > 0 then
        text = e.modified
    elseif type(e.original) == 'string' and #e.original > 0 then
        text = e.original
    elseif type(e.data) == 'string' and #e.data > 0 then
        text = e.data
    elseif type(e.line) == 'string' and #e.line > 0 then
        text = e.line
    end

    if text == nil then
        return
    end

    local action_name = parse_player_action_name(lc.player_name, text)
    if action_name == 'wheeling thrust' then
        lc.extra_count = lc.extra_count + 1
        refresh_total()
    end
end)

ashita.events.register('command', 'latentchecker_command', function(e)
    local cmd = e.command
    if type(cmd) ~= 'string' then
        return
    end

    local args = cmd:args()
    if #args == 0 then
        return
    end

    local root = args[1]:lower()
    if root ~= '/lc' and root ~= '/latentchecker' then
        return
    end

    e.blocked = true

    local sub = (args[2] or 'help'):lower()

    if sub == 'sync' or sub == 'check' or sub == 'run' then
        sync_latent()
    elseif sub == 'reset' then
        lc.extra_count = 0
        refresh_total()
        AshitaCore:GetChatManager():QueueCommand(1, ('/echo [LC] reset extra total:%d'):format(lc.total_count))
    elseif sub == 'fullreset' then
        lc.base_count = 0
        lc.extra_count = 0
        refresh_total()
        AshitaCore:GetChatManager():QueueCommand(1, '/echo [LC] full reset')
    elseif sub == 'count' then
        AshitaCore:GetChatManager():QueueCommand(
            1,
            ('/echo [LC] base:%d extra:%d total:%d'):format(lc.base_count, lc.extra_count, lc.total_count)
        )
    elseif sub == 'player' and args[3] ~= nil then
        lc.player_name = tostring(args[3])
        AshitaCore:GetChatManager():QueueCommand(1, ('/echo [LC] player:%s'):format(lc.player_name))
    elseif sub == 'show' then
        lc.visible[1] = true
    elseif sub == 'hide' then
        lc.visible[1] = false
    else
        AshitaCore:GetChatManager():QueueCommand(
            1,
            '/echo [LC] /lc sync | reset | fullreset | count | player <name> | show | hide'
        )
    end
end)

ashita.events.register('d3d_present', 'latentchecker_present', function()
    if not lc.visible[1] then
        return
    end

    imgui.SetNextWindowPos(lc.pos, ImGuiCond_FirstUseEver)
    imgui.SetNextWindowSize(lc.size, ImGuiCond_FirstUseEver)

    local flags = bit.bor(
        ImGuiWindowFlags_NoResize,
        ImGuiWindowFlags_NoScrollbar,
        ImGuiWindowFlags_NoScrollWithMouse
    )

    if imgui.Begin('LatentChecker', lc.visible, flags) then
        imgui.Text(('Total: %d'):format(lc.total_count))
        imgui.Text(('Base: %d'):format(lc.base_count))
        imgui.Text(('Extra: %d'):format(lc.extra_count))
        if imgui.Button('Sync', { 70, 0 }) then
            sync_latent()
        end
    end
    imgui.End()
end)
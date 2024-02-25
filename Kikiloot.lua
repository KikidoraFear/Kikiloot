

-- + grey out items after 1 minute has passed after looting, reactivate if player click request for rolling or master rolls again
-- + add button to choose min_rarity
-- + inactive overlay: grey; being_rolled: green border
-- + if new item is being_rolled, set item that was previously being rolled to inactive
-- item disappears when more than one is present and not last one clicked (probably needs some local _f)
-- make roll button give item to player

-- ##############
-- # PARAMETERS #
-- ##############

local kl_id = 2

local config = {
    min_rarity = 0, -- 0 grey, 1 white and quest items, 2 green, 3 blue, ...
    rarities = {"Grey", "White", "Green", "Blue", "Purple"},
    refresh_time = 5,
    reset_time = 60,
    roll_channel = "RAID",
    icon_size = 25,
    icon_cols = 5,
    window_height = 20,
    window_width = 125,
    button_size = 20,
    button_rarity_width = 40,
    button_rolls_height = 20,
    button_rolls_width = 80,
    text_size = 9
}

-- ##########
-- # LAYOUT #
-- ##########

local function WindowLayout(window)
    window:SetBackdrop({bgFile = 'Interface\\Tooltips\\UI-Tooltip-Background'})
    window:SetBackdropColor(0, 0, 0, 1)
    window:SetPoint('CENTER', UIParent)
    window:SetWidth(config.window_width)
    window:SetHeight(config.window_height)
    window:EnableMouse(true) -- needed for it to be movable
    window:RegisterForDrag("LeftButton")
    window:SetMovable(true)
    window:SetUserPlaced(true) -- saves the place the user dragged it to
    window:SetScript("OnDragStart", function() window:StartMoving() end)
    window:SetScript("OnDragStop", function() window:StopMovingOrSizing() end)
    window:SetClampedToScreen(true) -- so the window cant be moved out of screen
end

local function ActivityLayout(btn, activity)
    btn.overlay:SetBackdrop({bgFile = 'Interface\\Tooltips\\UI-Tooltip-Background'})
    btn.overlay:SetPoint('CENTER', btn)
    btn.overlay:SetWidth(config.icon_size)
    btn.overlay:SetHeight(config.icon_size)
    if activity == "active" then
        btn.overlay:SetBackdropColor(0, 0, 0, 0)
        btn:SetBackdropBorderColor(0, 0, 0, 0)
    elseif activity == "inactive" then
        btn.overlay:SetBackdropColor(0, 0, 0, 0.7)
        btn:SetBackdropBorderColor(0, 0, 0, 0)
    elseif activity == "being_rolled" then
        btn.overlay:SetBackdropColor(0, 0, 0, 0)
        btn:SetBackdropBorderColor(0, 1, 0, 1)
    end
end

local function IconLayout(parent, btn, data_loot, item_link, data_sr, data_ss, align_parent, align_btn, ofs_x, ofs_y)
    btn:SetBackdrop({bgFile=data_loot[item_link]._item_icon,
        edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false, tileSize = 16, edgeSize = 16,
        insets = { left = 2, right = 2, top = 2, bottom = 2}})
    ActivityLayout(btn, data_loot[item_link]._activity)
    btn:ClearAllPoints()
    btn:SetPoint(align_btn, parent, align_parent, ofs_x, ofs_y)
    btn:SetWidth(config.icon_size)
    btn:SetHeight(config.icon_size)
    btn:Show()
    btn:SetScript("OnEnter", function()
        btn:SetBackdrop({bgFile=data_loot[item_link]._item_icon,
            edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
            tile = false, tileSize = 16, edgeSize = 16,
            insets = { left = 3, right = 3, top = 3, bottom = 3}})
        ActivityLayout(btn, data_loot[item_link]._activity)
        GameTooltip:SetOwner(btn, "ANCHOR_TOP")
        GameTooltip:SetHyperlink(data_loot[item_link]._item_string)
        if data_sr[data_loot[item_link]._item_name] then
            local sr_text = "SR: "
            for _,player_name in pairs(data_sr[data_loot[item_link]._item_name]) do
                sr_text = sr_text..player_name.." "
            end
            GameTooltip:AddLine(sr_text)
        end
        if data_ss[data_loot[item_link]._item_name] then
            GameTooltip:AddLine("Comment: "..data_ss[data_loot[item_link]._item_name])
        end
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function()
        btn:SetBackdrop({bgFile=data_loot[item_link]._item_icon,
            edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
            tile = false, tileSize = 16, edgeSize = 16,
            insets = { left = 2, right = 2, top = 2, bottom = 2}})
        ActivityLayout(btn, data_loot[item_link]._activity)
        GameTooltip:Hide()
    end)
end

local function ButtonLayout(parent, btn, txt, tooltip, align_btn, align_parent, ofs_x, ofs_y, width, height)
    btn:ClearAllPoints()
    btn:SetPoint(align_btn, parent, align_parent, ofs_x, ofs_y)
    btn:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2}})
    btn:SetWidth(width)
    btn:SetHeight(height)
    btn:Show()
    if not btn.text then
        btn.text = btn:CreateFontString("Status", "OVERLAY", "GameFontNormal")
    end
    btn.text:SetFont(STANDARD_TEXT_FONT, config.text_size, "THINOUTLINE")
    btn.text:SetFontObject(GameFontWhite)
    btn.text:ClearAllPoints()
    btn.text:SetPoint("CENTER", btn, "CENTER")
    btn.text:SetText(txt)
    btn.text:Show()
    btn:SetBackdropColor(1, 1, 1, 1)
    btn:SetBackdropBorderColor(0, 0, 0, 1)
    btn:SetScript("OnEnter", function()
        btn:SetBackdropBorderColor(1, 1, 1, 1)
        GameTooltip:SetOwner(btn, "ANCHOR_TOP")
        GameTooltip:AddLine(tooltip)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function()
        btn:SetBackdropBorderColor(0, 0, 0, 1)
        GameTooltip:Hide()
    end)
end

local function EditBoxLayout(parent, edb)
    edb:ClearAllPoints()
    edb:SetPoint("TOPRIGHT", parent, "TOPLEFT")
    edb:SetMultiLine(true)
    -- edb:SetTextInsets(15,15,15,15)
    edb:SetFont(STANDARD_TEXT_FONT, 8, "THINOUTLINE")
    edb:SetFontObject(GameFontWhite)
    edb:SetWidth(500)
    edb:SetHeight(100)
    edb:SetBackdrop({bgFile = 'Interface\\Tooltips\\UI-Tooltip-Background'})
    edb:Hide()
end

-- ####################
-- # HELPER FUNCTIONS #
-- ####################

-- for debugging: DEFAULT_CHAT_FRAME:AddMessage("Test")
local function print(msg)
    DEFAULT_CHAT_FRAME:AddMessage(msg)
end

local function ResetData(data)
    if data then
        for idx,_ in pairs(data) do data[idx] = nil end
    end
end

local function GetItemStringFromItemlink(item_link)
    local _,_,item_string = string.find(item_link, "|H(.-)|h") -- extracts item string from link
    -- local printable = string.gsub(item_link, "\124", "\124\124"); -- makes item_link printable
    -- print("Here's what it really looks like: \"" .. printable .. "\"");
    return item_string
end

-- ID,Item,Boss,Attendee,Class,Specialization,Comment,Date
-- 21110,"Splintered Tusk",Ragnaros,Bibbley,Warrior,Protection,,"04/02/2024, 14:53:38"
-- local function ParseRaidres(text, data_sr)
--     text = text..'\n' -- add \n so last line will be matched as well
--     local pattern = '(%d+),(.-),(.-),(.-),(.-),(.-),(.-),(.-)\n' -- modifier - gets 0 or more repetitions and matches the shortest sequence
--     text = string.gsub(text, '"', '') -- remove " from text, raidres places it randomly, idk
--     ResetData(data_sr)
--     for id, item, boss, attendee, class, specialization, comment, date in string.gfind(text, pattern) do
--         if not data_sr[item] then
--             data_sr[item] = {}
--         end
--         table.insert(data_sr[item], attendee)
--     end
-- end
local function ParseRaidres(text, data_sr)
    text = text..'\n' -- add \n so last line will be matched as well
    local pattern = '(%d+),"(.-)",(.-),(.-),(.-),(.-),"(.-)"\n' -- modifier - gets 0 or more repetitions and matches the shortest sequence
    -- text = string.gsub(text, '"', '') -- remove " from text, raidres places it randomly, idk
    ResetData(data_sr)
    for id, item, boss, attendee, class, specialization, comment, date in string.gfind(text, pattern) do
        if not data_sr[item] then
            data_sr[item] = {}
        end
        table.insert(data_sr[item], attendee)
    end
end

-- Splintered Tusk,Warrior Fury,All Ranks
local function ParseLootSpreadsheet(text, data_ss)
    text = text..'\n'
    local pattern = '(.-)#(.-)#(.-)\n' -- modifier - gets 0 or more repetitions and matches the shortest sequence
    ResetData(data_ss)
    for item, prio, rank in string.gfind(text, pattern) do
        data_ss[item] = rank.." -> "..prio
    end
end

function GetTableLength(tbl)
    local count = 0
    for _ in pairs(tbl) do count = count + 1 end
    return count
end

-- ##############
-- # BROADCASTS #
-- ##############

local function BroadCastLoot(loot_master)
    for idx_loot = 1, GetNumLootItems() do
        local _, _, _, loot_rarity = GetLootSlotInfo(idx_loot)
        if (loot_rarity >= config.min_rarity) and LootSlotIsItem(idx_loot) then -- if rarity>=min and not gold
            local item_link = GetLootSlotLink(idx_loot)
            SendAddonMessage("KL"..kl_id.."_ITEM", item_link , "RAID")
        elseif UnitName("player")==loot_master then
            local idx_mlc = nil
            for idx_loop = 1, GetNumRaidMembers() do
                if (GetMasterLootCandidate(idx_loop) == UnitName("player")) then
                    idx_mlc = idx_loop -- get master loot candidate index for player
                    break
                end
            end
            GiveMasterLoot(idx_loot, idx_mlc)
        end
    end
end


local function BroadCastItemRoll(item_link)
    SendAddonMessage("KL"..kl_id.."_ROLLITEM", item_link , "RAID")
end


local function BroadCastRoll(data_loot, item_link, player_name, roll_result, roll_min, roll_max, data_sr)
    if item_link and not data_loot[item_link]._roll[player_name] and (roll_min == "1") and (roll_max == "100") then -- only add first roll of player
        -- check SR
        local has_sr = true
        if data_sr[data_loot[item_link]._item_name] then
            has_sr = false -- set to false only if SR exists for item and then check if player has SR
            for _, player_name_sr in ipairs(data_sr[data_loot[item_link]._item_name]) do
                if player_name == player_name_sr then
                    has_sr = true
                    break
                end
            end
        end
        if has_sr then
            SendAddonMessage("KL"..kl_id.."_ROLL_"..player_name.."_"..roll_result, item_link, "RAID")
        end
    end
end


local function BroadCastRollRequest(item_link)
    SendAddonMessage("KL"..kl_id.."_ROLLREQUEST", item_link, "RAID")
end

-- ##################
-- # ITEM FUNCTIONS #
-- ##################


local function RollItem(data_loot, item_link, data_sr, data_ss)
    SendChatMessage("### KIKILOOT ###" , config.roll_channel, nil, nil)
    SendChatMessage("Roll for "..item_link , config.roll_channel, nil, nil)
    if data_ss[data_loot[item_link]._item_name] then
        SendChatMessage("Comment: "..data_ss[data_loot[item_link]._item_name], config.roll_channel, nil, nil)
    end
    if data_sr[data_loot[item_link]._item_name] then
        local sr_text = "SR: "
        for _, player_name in ipairs(data_sr[data_loot[item_link]._item_name]) do
            sr_text = sr_text..player_name.." "
        end
        SendChatMessage(sr_text , config.roll_channel, nil, nil)
    end
    BroadCastItemRoll(item_link)
end


local function RequestRoll(item_link)
    SendChatMessage("### KIKILOOT ###" , config.roll_channel, nil, nil)
    SendChatMessage("Roll Request: "..item_link , config.roll_channel, nil, nil)
    BroadCastRollRequest(item_link)
end

local function AddItem(window, data_loot, data_sr, data_ss, item_link, loot_master, activity)
    if not data_loot[item_link] then
        local item_string = GetItemStringFromItemlink(item_link)
        local item_name, _, item_rarity, item_level, item_min_level, item_type, item_sub_type, item_stack_count, item_icon = GetItemInfo(item_string)

        data_loot[item_link] = {}
        data_loot[item_link]._item_string = item_string
        data_loot[item_link]._item_name = item_name
        data_loot[item_link]._item_link = item_link
        data_loot[item_link]._item_rarity = item_rarity
        data_loot[item_link]._item_icon = item_icon
        data_loot[item_link]._activity = activity -- active, inactive, being_rolled
        data_loot[item_link]._last_interaction = GetTime()

        local idx_item = GetTableLength(data_loot)-1
        data_loot[item_link]._row_grid = math.floor(idx_item/config.icon_cols)+1 -- idx_item = 0 -> 1, idx_item = 5 -> 2, idx_item = 6 -> 2
        data_loot[item_link]._col_grid = math.mod(idx_item, config.icon_cols)+1

        data_loot[item_link]._roll = {}
        data_loot[item_link]._roll_ranking = {}
    elseif data_loot[item_link]._activity == "inactive" then -- reactivate item if inactive and looted again
        data_loot[item_link]._last_interaction = GetTime()
        data_loot[item_link]._activity = activity
    end
    
    if activity == "being_rolled" then -- being_rolled overwrites activity
        data_loot[item_link]._last_interaction = GetTime()
        data_loot[item_link]._activity = activity
    end

    

    -- display item
    local item_link_f = item_link
    if not window.item[item_link_f] then
        window.item[item_link_f] = CreateFrame("Button", nil, window)
    end
    if not window.item[item_link_f].overlay then
        window.item[item_link_f].overlay = CreateFrame("Frame", nil, window.item[item_link_f])
    end
    IconLayout(window, window.item[item_link_f], data_loot, item_link_f, data_sr, data_ss, "TOPLEFT", "TOPLEFT",
        config.icon_size*(data_loot[item_link_f]._col_grid-1),
        -config.icon_size*(data_loot[item_link_f]._row_grid-1) - config.window_height)
    window.item[item_link_f]:SetScript("OnClick", function()
        if (UnitName("player") == loot_master) then
            RollItem(data_loot, item_link_f, data_sr, data_ss)
        else
            RequestRoll(item_link_f)
        end
    end)
    ActivityLayout(window.item[item_link_f], data_loot[item_link_f]._activity)
end

local function AddDataRoll(window, data_loot, item_link, player_name, roll_result)
    data_loot[item_link]._roll[player_name] = roll_result
    -- rank people who rolled
    table.insert(data_loot[item_link]._roll_ranking, player_name) -- add player_name to ranking list
    table.sort(data_loot[item_link]._roll_ranking, function(keyRhs, keyLhs) return data_loot[item_link]._roll[keyLhs] < data_loot[item_link]._roll[keyRhs] end) -- sort ranking list
    for idx,_ in ipairs(window.rolls) do
        window.rolls[idx]:Hide()
    end
    for rank, player_name in ipairs(data_loot[item_link]._roll_ranking) do
        local rank_f = rank
        local player_name_f = player_name
        local item_link_f = item_link
        if not window.rolls[rank] then
            window.rolls[rank] = CreateFrame("Button", nil, window)
        end
        ButtonLayout(window, window.rolls[rank_f], data_loot[item_link_f]._roll[player_name_f].." "..player_name_f,
            "Give To", "TOPRIGHT", "TOPLEFT", 0, -(rank_f-1)*config.button_rolls_height-config.window_height, config.button_rolls_width, config.button_rolls_height)
        window.rolls[rank_f]:SetScript("OnClick", function()
            local idx_mlc = nil
            local idx_loot = nil
            for idx_loot_temp = 1, GetNumLootItems() do -- get loot index from item_link
                if item_link_f == GetLootSlotLink(idx_loot_temp) then
                    idx_loot = idx_loot_temp
                    break
                end
            end
            for idx_mlc_temp = 1, GetNumRaidMembers() do -- get player index from player_name
                if (GetMasterLootCandidate(idx_mlc_temp) == player_name_f) then
                    idx_mlc = idx_mlc_temp -- get master loot candidate index for player
                    break
                end
            end
            if idx_loot and idx_mlc then
                GiveMasterLoot(idx_loot, idx_mlc)
            else
                print(item_link_f.." / "..player_name_f.." does not exist in current loot window/raid")
            end
        end)
    end
end

-- ########
-- # INIT #
-- ########

-- data_loot[item_link]._item_name
-- data_loot[item_link]._item_string
-- data_loot[item_link]._item_rarity
-- data_loot[item_link]._item_icon
-- data_loot[item_link]._roll[player_name] = roll
-- data_loot[item_link]._roll_ranking[1] = player_name
-- data_loot[item_link]._activity = true -- item gets set to inactive 10 seconds after last roll
local data_loot = {}

-- data[loot][1] = player_name -- list of players who have SR on item
local data_sr = {}

local data_ss = {}

local loot_master = "" -- name of loot master

local item_link_being_rolled = nil -- item link that's currently being rolled

local window = CreateFrame("Frame", "Kikiloot", UIParent)
WindowLayout(window)
window.item = {}
window.rolls = {}

window.button_sr = CreateFrame("Button", nil, window)
ButtonLayout(window, window.button_sr, "SR", "Import SR", "BOTTOMLEFT", "BOTTOMLEFT", 0, 0, config.button_size, config.button_size)

window.import_sr = CreateFrame("EditBox", nil, UIParent)
EditBoxLayout(window, window.import_sr)

window.button_ss = CreateFrame("Button", nil, window)
ButtonLayout(window, window.button_ss, "SS", "Import Spreadsheet", "BOTTOMLEFT", "BOTTOMLEFT", config.button_size, 0, config.button_size, config.button_size)

window.import_ss = CreateFrame("EditBox", nil, UIParent)
EditBoxLayout(window, window.import_ss)

window.button_cl = CreateFrame("Button", nil, window)
ButtonLayout(window, window.button_cl, "CL", "Clear Data", "BOTTOMLEFT", "BOTTOMLEFT", 2*config.button_size, 0, config.button_size, config.button_size)

window.button_mr = CreateFrame("Button", nil, window)
ButtonLayout(window, window.button_mr, "Green", "Select Rarity (below will be autolooted)", "BOTTOMLEFT", "BOTTOMLEFT", 3*config.button_size, 0, config.button_rarity_width, config.button_size)
for num_rarity, txt_rarity in ipairs(config.rarities) do
    local num_rarity_f = num_rarity
    local txt_rarity_f = txt_rarity
    window.button_mr[num_rarity] = CreateFrame("Button", nil, window)
    ButtonLayout(window.button_mr, window.button_mr[num_rarity_f], txt_rarity_f, "Select Rarity (below will be autolooted)", "BOTTOMLEFT", "BOTTOMLEFT", 0, num_rarity_f*config.button_size, config.button_rarity_width, config.button_size)
    window.button_mr[num_rarity]:Hide()
end

-- #################
-- # INTERACTIVITY #
-- #################

window.button_sr:SetScript("OnClick", function()
    window.import_ss:Hide()
    if window.import_sr:IsShown() then
        window.import_sr:Hide()
    else
        window.import_sr:Show()
    end
end)
window.import_sr:SetScript("OnTextChanged", function()
    ParseRaidres(this:GetText(), data_sr)
end)

window.button_ss:SetScript("OnClick", function()
    window.import_sr:Hide()
    if window.import_ss:IsShown() then
        window.import_ss:Hide()
    else
        window.import_ss:Show()
    end
end)
window.import_ss:SetScript("OnTextChanged", function()
    ParseLootSpreadsheet(this:GetText(), data_ss)
end)

window.button_cl:SetScript("OnClick", function()
    ResetData(data_loot)
    for idx,_ in pairs(window.item) do
        window.item[idx]:Hide()
    end
    for idx,_ in pairs(window.rolls) do
        window.rolls[idx]:Hide()
    end
end)

window.button_mr:SetScript("OnClick", function()
    for idx_rarity, txt_rarity in ipairs(config.rarities) do
        local num_rarity_f = idx_rarity-1
        local txt_rarity_f = txt_rarity
        if window.button_mr[idx_rarity]:IsShown() then
            window.button_mr[idx_rarity]:Hide()
        else
            window.button_mr[idx_rarity]:Show()
        end
        window.button_mr[idx_rarity]:SetScript("OnClick", function()
            config.min_rarity = num_rarity_f
            window.button_mr.text:SetText(txt_rarity_f)
            for idx_rarity, _ in ipairs(config.rarities) do
                window.button_mr[idx_rarity]:Hide()
            end
        end)
    end
end)


-- #########################
-- # SEND AND RECEIVE DATA #
-- #########################

window:RegisterEvent("LOOT_OPENED")
window:RegisterEvent("CHAT_MSG_SYSTEM")
window:RegisterEvent("CHAT_MSG_ADDON")
window:SetScript("OnEvent", function()
    if event == "LOOT_OPENED" then
        BroadCastLoot(loot_master)
    elseif event == "CHAT_MSG_SYSTEM" and (UnitName("player") == loot_master) then
        local pattern = "(.+) rolls (%d+) %((%d+)-(%d+)%)"
        for player_name, roll_result, roll_min, roll_max in string.gfind(arg1, pattern) do
            BroadCastRoll(data_loot, item_link_being_rolled, player_name,
                roll_result, roll_min, roll_max, data_sr)
        end
    elseif event == "CHAT_MSG_ADDON" then
        local pattern_item = "KL"..kl_id.."_ITEM" -- SendAddonMessage("KL"..kl_id.."_ITEM", item_link , "RAID")
        local pattern_roll = "KL"..kl_id.."_ROLL_(.+)_(%d+)" --SendAddonMessage("KL"..kl_id.."_ROLL_"..player_name.."_"..roll_result, item_link, "RAID")
        local pattern_rollitem = "KL"..kl_id.."_ROLLITEM" --SendAddonMessage("KL"..kl_id.."_ROLLITEM", item_link, "RAID")
        for _ in string.gfind(arg1, pattern_item) do
            AddItem(window, data_loot, data_sr, data_ss, arg2, loot_master, "active")
            return
        end
        for player_name, roll_result in string.gfind(arg1, pattern_roll) do
            AddItem(window, data_loot, data_sr, data_ss, arg2, loot_master, "being_rolled") -- in case item doesnt exist in data_roll
            AddDataRoll(window, data_loot, arg2, player_name, tonumber(roll_result))
            return
        end
        for _ in string.gfind(arg1, pattern_rollitem) do
            if data_loot[arg2]._roll then
                ResetData(data_loot[arg2]._roll)
            end
            if data_loot[arg2]._roll_ranking then
                ResetData(data_loot[arg2]._roll_ranking)
            end
            for idx,_ in ipairs(window.rolls) do
                window.rolls[idx]:Hide()
            end
            if item_link_being_rolled then -- set previously rolled item to inactive
                data_loot[item_link_being_rolled]._activity = "inactive"
                ActivityLayout(window.item[item_link_being_rolled], data_loot[item_link_being_rolled]._activity)
            end
            AddItem(window, data_loot, data_sr, data_ss, arg2, loot_master, "being_rolled")
            item_link_being_rolled = arg2
            return
        end
    end
end)

-- check loot master
window:SetScript("OnUpdate", function()
    if not window.clock then window.clock = GetTime() end
    if GetTime() > window.clock + config.refresh_time then
        local loot_method, loot_master_id = GetLootMethod()
        if (loot_method == "master") and loot_master_id then
            if loot_master_id == 0 then
                loot_master = UnitName("player")
            else
                loot_master = UnitName("raid"..loot_master_id)
            end
        end
        for item_link, _ in pairs(data_loot) do
            if (GetTime() - data_loot[item_link]._last_interaction) >= config.reset_time then
                if item_link == item_link_being_rolled then
                    item_link_being_rolled = nil -- clear item being rolled
                    for idx,_ in ipairs(window.rolls) do
                        window.rolls[idx]:Hide()
                    end
                end
                data_loot[item_link]._activity = "inactive"
                ActivityLayout(window.item[item_link], "inactive")
            end
        end
        window.clock = GetTime()
    end
end)


-- stupid shit
local fun_machine =  CreateFrame("Frame", nil, UIParent)
local fun_machine_enabled = false
local fun_machine_cd = 10*60
local joke_machine_pattern ="tell me a joke, captain"
local joke_machine_punchline = nil
local joke_machine_punchline_delay = 5
local motivator_machine_pattern ="motivate me, captain"
local joke_machine = {{"A blind man walks into a bar.", "And a table. And a chair."},
    {"What do wooden whales eat?", "Plankton"},
    {"What's better than winning the silver medal at the Paralympics?", "Having legs."},
    {"Two fish in a tank, one says to the other", "\"You man the guns, I'll drive!\""},
    {"Two soldiers are in a tank, one says to the other", "\"BLURGBLBLURG!\""},
    {"What do you call an alligator in a vest", "An Investigator"},
    {"How many tickles does it take to get an octopus to laugh?", "Ten-tickles!"},
    {"Did you hear about the midget fortune teller who kills his customers?", "He's a small medium at large"},
    {"What's the best time to go to the dentist?", "2:30"},
    {"Yo mama so fat, when she was interviewed on Channel 6 news", "you could see her sides on the channels 5 and 7"},
    {"Yo mama so fat, i swerved to miss her in my car", "and ran out of gas"},
    {"How many push ups can Chuck Norris do?", "All of them"},
    {"How did the hacker get away from the police?", "He ransomware"},
    {"I met a genie once. He gave me one wish. I said \"I wish i could be you\"", "the genie replued \"weurd wush but u wull grant ut\""},
    {"i bought my daughter a refrigerator for her birthday", "i cant wait to see her face light up when she opens it"},
    {"a call comes in to 911 \"come quick, my friend was bitten by a wolf!\", operator:\"Where?\"", "\"no, a regular one\""},
    {"Did you hear about the french cheese factory explosion?", "da brie was everywhere"},
    {"why do germans store their cheese together with their sausage?", "they're prepared for a wurst-kase scenario"},
    {"why did the aztec owl not know what the other owls were saying to each other?", "they were inca hoots"}
}
local motivator_machine = {"It's never too late to give up",
    "This is the worst day of my life",
    "Don't follow your friends off a bridge; lead them",
    "Just because you're special, doesn't mean you're useful",
    "No one is as dumb as all of us together",
    "It may be that the purpose of your life is to serve as a warning for others",
    "If you ever feel alone, don't",
    "Give up on your dreams and die",
    "Trying is the first step to failure",
    "Make sure to drink water so you can stay hydrated while you suffer",
    "The Nail that sticks out gets hammered down",
    "I got an ant farm. They didn't grow shit",
    "They don't think it be like it is but it do",
    "If Id agreed with you we'd both be wrong",
    "Tutant meenage neetle teetle",
    "When you want win but you receive lose",
    "Get two birds stoned at once",
    "Osteoporosis sucks",
    "Success is just failure that hasn't happened yet",
    "Never underestimate the power of stupid people in large groups",
    "I hate everyone equally",
    "Only dread one day at a time",
    "Hope is the first step on the road to disappointment",
    "The beatings will continue until morale improves",
    "It's always darkest just before it goes pitch black",
    "When you do bad, no one will forget",
    "Life's a bitch, then you die",
    "You suck",
    "Fuck you",
    "Not even Noah's ark can carry you, animals",
    "Your mother buys you Mega Bloks instead of Legos",
    "You look like you cut your hair with a knife and fork",
    "You all reek of poverty and animal abuse",
    "Your garden is overgrown and your cucumbers are soft"
}

fun_machine:SetScript("OnUpdate", function()
    if not fun_machine.clock_machine then fun_machine.clock_machine = GetTime() end
    if GetTime() > fun_machine.clock_machine + fun_machine_cd then
        fun_machine_enabled = true
        fun_machine.clock_machine = GetTime()
    end
    if not fun_machine.clock_punchline then fun_machine.clock_punchline = GetTime() end
    if (GetTime() > fun_machine.clock_punchline) and joke_machine_punchline then
        SendChatMessage(joke_machine_punchline, "RAID_WARNING", nil, nil)
        joke_machine_punchline = nil
    end
end)
fun_machine:RegisterEvent("CHAT_MSG_RAID")
-- fun_machine:RegisterEvent("CHAT_MSG_RAID_LEADER")
fun_machine:SetScript("OnEvent", function()
    for _ in string.gfind(arg1, joke_machine_pattern) do
        if fun_machine_enabled then
            local idx = math.random(1, GetTableLength(joke_machine))
            SendChatMessage(joke_machine[idx][1] , "RAID_WARNING", nil, nil)
            joke_machine_punchline = joke_machine[idx][2]
            fun_machine.clock_machine = GetTime()
            fun_machine.clock_punchline = GetTime()+joke_machine_punchline_delay
            fun_machine_enabled = false
        else
            SendChatMessage("No." , "RAID_WARNING", nil, nil)
        end
    end
    for _ in string.gfind(arg1, motivator_machine_pattern) do
        if fun_machine_enabled then
            local idx = math.random(1, GetTableLength(motivator_machine))
            SendChatMessage(motivator_machine[idx] , "RAID_WARNING", nil, nil)
            fun_machine.clock_machine = GetTime()
            fun_machine_enabled = false
        else
            SendChatMessage("No." , "RAID_WARNING", nil, nil)
        end
    end
end)

-- #########
-- # Tests #
-- #########

--[[
ID,Item,Boss,Attendee,Class,Specialization,Comment,Date
21110,"Thunderfury",Ragnaros,Malgoni,Warrior,Protection,,"04/02/2024, 14:53:38"
21110,"Thunderfury",Ragnaros,Kikidora,Warrior,Protection,,"04/02/2024, 14:53:38"
18814,"Splintered Tusk",Ragnaros,Asdf,Warlock,Destruction,,"04/02/2024, 14:55:41"
18814,"Spider's Silk",Ragnaros,Bibbley,Warlock,Destruction,,"04/02/2024, 14:55:41"
18814,"Spider's Silk",Ragnaros,Aldiuss,Warlock,Destruction,,"04/02/2024, 14:55:41"
18814,"Spider's Silk",Ragnaros,Kikidora,Warlock,Destruction,,"04/02/2024, 14:55:41"
18814,"Ruined Pelt",Ragnaros,Kikidora,Warlock,Destruction,,"04/02/2024, 14:55:41"
18814,"Ruined Pelt",Ragnaros,Bibbley,Warlock,Destruction,,"04/02/2024, 14:55:41"
18814,"Ruined Pelt",Ragnaros,Test,Warlock,Destruction,,"04/02/2024, 14:55:41"
18814,"Stringy Vulture Meat",Ragnaros,Kikidora,Warlock,Destruction,,"04/02/2024, 14:55:41"
18814,"Gooey Spider Leg",Ragnaros,Pestilentia,Warlock,Destruction,,"04/02/2024, 14:55:41"
18814,"Spider Ichor",Ragnaros,Grizzlix,Warlock,Destruction,,"04/02/2024, 14:55:41"
18814,"Rough Vulture Feathers",Ragnaros,Asterixs,Warlock,Destruction,,"04/02/2024, 14:55:41"
18814,"Linen Cloth",Ragnaros,Baldnic,Warlock,Destruction,,"04/02/2024, 14:55:41"
18814,"Spider Palp",Ragnaros,Baldnic,Warlock,Destruction,,"04/02/2024, 14:55:41"
--]]

--[[
Lavashard Axe#Warrior Fury#All Ranks
Core Forged Helmet#Paladin Tank#All Ranks
Boots of Blistering Flames#Mage#All Ranks
Ruined Pelt#Rogue#All Ranks
asdf#Rogue#All Ranks
Spider Ichor#Shaman Enh/Hunter#All Ranks
##
##
Test#Warrior Tank /Paladin Tank#All Ranks
T1 Wrist#Class Specific#All Ranks
Spider Palp#Class Specific#All Ranks
--]]
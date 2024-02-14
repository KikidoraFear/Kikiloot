
-- ##############
-- # PARAMETERS #
-- ##############

local kl_id = 1

local config = {
    min_rarity = 2, -- 0 grey, 1 white and quest items, 2 green, 3 blue, ...
    refresh_time = 1,
    roll_channel = "RAID"
}

-- ####################
-- # HELPER FUNCTIONS #
-- ####################

-- for debugging: DEFAULT_CHAT_FRAME:AddMessage("Test")
local function print(msg)
    DEFAULT_CHAT_FRAME:AddMessage(msg)
end

local function ResetData(data)
    for idx,_ in pairs(data) do data[idx] = nil end
end

-- ID,Item,Boss,Attendee,Class,Specialization,Comment,Date
-- 21110,"Splintered Tusk",Ragnaros,Bibbley,Warrior,Protection,,"04/02/2024, 14:53:38"
local function ParseRaidres(text, data_sr)
    text = text..'\n' -- add \n so last line will be matched as well
    local pattern = '(%d+),(.-),(.-),(.-),(.-),(.-),(.-),(.-)\n' -- modifier - gets 0 or more repetitions and matches the shortest sequence
    text = string.gsub(text, '"', '') -- remove " from text, raidres places it randomly, idk
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
    local pattern = '(.-),(.-),(.-)\n' -- modifier - gets 0 or more repetitions and matches the shortest sequence
    data_ss = {}
    for item, prio, rank in string.gfind(text, pattern) do
        data_ss[item] = rank.." -> "..prio
    end
end

function GetTableLength(tbl)
    local count = 0
    for _ in pairs(tbl) do count = count + 1 end
    return count
  end

local function BroadCastItem(idx_item, type, value)
    SendAddonMessage("KL"..kl_id.."_"..idx_item.."_"..type, value , "RAID") -- "KL4_1_ICON", "Itemname", "RAID"
end

local function BroadCastReset()
    SendAddonMessage("KL"..kl_id.."_RESET", 1 , "RAID") -- "KL4_RESET", 1, "RAID"
end

local function BroadCastItems(data_roll)
    local idx_player = nil
    for idx_loop = 1, GetNumRaidMembers() do
        if (GetMasterLootCandidate(idx_loop) == UnitName("player")) then
            idx_player = idx_loop -- get master loot candidate index for player
            break
        end
    end
    local idx_item = GetTableLength(data_roll) + 1
    for idx_slot = 1, GetNumLootItems() do
        if (LootSlotIsItem(idx_slot)) then -- if is item (i.e. not gold)
            local loot_icon, loot_name, loot_quantity, loot_rarity = GetLootSlotInfo(idx_slot)
            local loot_link = GetLootSlotLink(idx_slot)
            if loot_rarity >= config.min_rarity then
                BroadCastItem(idx_item, "ICON", loot_icon)
                BroadCastItem(idx_item, "LINK", loot_link)
                BroadCastItem(idx_item, "NAME", loot_name)
                idx_item = idx_item+1
            else
                print(idx_slot.."_"..idx_player)
                GiveMasterLoot(idx_slot, idx_player) -- give everything below min_rarity to master looter
            end
        end
    end
end

local function BroadCastRoll(data_roll, data_sr, idx, source, roll_result)
    if not data_roll[idx]._roll[source] then -- only add first roll of player
        -- check SR
        local has_sr = true
        if data_sr[data_roll[idx]._loot_name] then
            has_sr = false -- set to false only if SR exists and then check if player has SR
            for _, value in ipairs(data_sr[data_roll[idx]._loot_name]) do
                if source == value then
                    has_sr = true
                end
            end
        end
        if has_sr then
            SendAddonMessage("KL"..kl_id.."_ROLL_"..source.."_"..idx, roll_result , "RAID") -- "KL4_ROLL_PLAYERNAME", 64, "RAID"
        end
    end
end

local function AddItem(data_roll, idx_item, type, value)
    if not data_roll[idx_item] then
        data_roll[idx_item] = {}
        data_roll[idx_item]._roll = {}
        data_roll[idx_item]._roll_ranking = {}
    end
    data_roll[idx_item][type] = value -- type = _loot_icon, _loot_link, _loot_name
end

local function RollItem(data_roll, data_sr, data_ss, idx)
    SendChatMessage("### KIKILOOT ###" , config.roll_channel, nil, nil)
    SendChatMessage("Roll for "..data_roll[idx]._loot_link , config.roll_channel, nil, nil)
    if data_ss[data_roll[idx]._loot_name] then
        SendChatMessage("Comment: "..data_ss[data_roll[idx]._loot_name], config.roll_channel, nil, nil)
    end
    if data_sr[data_roll[idx]._loot_name] then
        local sr_text = "SR: "
        for _,player_name in ipairs(data_sr[data_roll[idx]._loot_name]) do
            sr_text = sr_text..player_name.." "
        end
        SendChatMessage(sr_text , config.roll_channel, nil, nil)
    end
    SendChatMessage("### KIKILOOT ###" , config.roll_channel, nil, nil)
end

local function AddDataRoll(data_roll, source, roll_result, idx)
    data_roll[idx]._roll[source] = roll_result
    -- rank people who rolled
    data_roll[idx]._roll_ranking = {} -- <- necessary?
    for key, _ in pairs(data_roll[idx]._roll) do
        table.insert(data_roll[idx]._roll_ranking, key) -- creates an array with player_names
    end
    table.sort(data_roll[idx]._roll_ranking, function(keyRhs, keyLhs) return data_roll[idx]._roll[keyLhs] < data_roll[idx]._roll[keyRhs] end)
end

local data_roll_idx = -1
local function DisplayData(window, data_roll, data_sr, data_ss, player_name, loot_master)
    for idx,_ in ipairs(window.item) do
        window.item[idx]:Hide()
        for idx_t,_ in ipairs(window.item[idx].text) do
            window.item[idx].text[idx_t]:Hide()
        end
    end
    for idx,_ in ipairs(data_roll) do
        local idx_f = idx
        window.item[idx] = CreateFrame("Button", nil, window)
        window.item[idx]:SetBackdrop({bgFile=data_roll[idx]._loot_icon,
            edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
            tile = false, tileSize = 16, edgeSize = 8,
            insets = { left = 2, right = 2, top = 2, bottom = 2}})
        window.item[idx]:ClearAllPoints()
        window.item[idx]:SetPoint('TOPLEFT', window, 'TOPLEFT', 0, -30*idx)
        window.item[idx]:SetWidth(30)
        window.item[idx]:SetHeight(30)
        window.item[idx]:Show()
        window.item[idx]:SetScript("OnClick", function()
            if (player_name == loot_master) then
                RollItem(data_roll, data_sr, data_ss, idx_f)
                data_roll_idx = idx_f
            end
        end)
        window.item[idx]:SetScript("OnEnter", function()
            window.item[idx_f]:SetBackdrop({bgFile=data_roll[idx_f]._loot_icon,
                edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
                tile = false, tileSize = 16, edgeSize = 8,
                insets = { left = 3, right = 3, top = 3, bottom = 3}})
            GameTooltip:SetOwner(window.item[idx_f], "ANCHOR_TOP")
            GameTooltip:AddLine(data_roll[idx_f]._loot_link)
            if data_sr[data_roll[idx_f]._loot_name] then
                local sr_text = "SR: "
                for _,player_name in pairs(data_sr[data_roll[idx_f]._loot_name]) do
                    sr_text = sr_text..player_name.." "
                end
                GameTooltip:AddLine(sr_text)
            end
            if data_ss[data_roll[idx_f]._loot_name] then
                GameTooltip:AddLine("Comment: "..data_ss[data_roll[idx_f]._loot_name])
            end
            GameTooltip:Show()
        end)
        window.item[idx]:SetScript("OnLeave", function()
            window.item[idx_f]:SetBackdrop({bgFile=data_roll[idx_f]._loot_icon,
                edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
                tile = false, tileSize = 16, edgeSize = 8,
                insets = { left = 2, right = 2, top = 2, bottom = 2}})
            GameTooltip:Hide()
          end)

        if not window.item[idx].text then
            window.item[idx].text = {}
            for idx_text=1,3 do
                window.item[idx].text[idx_text] = window:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
                window.item[idx].text[idx_text]:SetText("")
                window.item[idx].text[idx_text]:SetFont(STANDARD_TEXT_FONT, 10, "THINOUTLINE")
                window.item[idx].text[idx_text]:SetFontObject(GameFontWhite)
                window.item[idx].text[idx_text]:ClearAllPoints()
                window.item[idx].text[idx_text]:SetPoint('TOPLEFT', window.item[idx], 'TOPRIGHT', 0, -10*(idx_text-1))
                window.item[idx].text[idx_text]:Hide()
            end
        end
        for rank, player_name in ipairs(data_roll[idx]._roll_ranking) do
            if rank > 3 then -- only show top 3
                break
            end
            window.item[idx].text[rank]:SetText(data_roll[idx]._roll[player_name].." "..player_name)
            window.item[idx].text[rank]:Show()
        end
    end
end

-- ########
-- # INIT #
-- ########

-- ToDo: How to handle if loot master loots mob multiple times
-- data[1]._loot_link = link
-- data[1]._loot_name = name
-- data[1]._roll[player_name] = math.random(100)
local data_roll = {}

-- data[loot][1] = player_name -- list of players who have SR on item
local data_sr = {}


local data_ss = {}

local window = CreateFrame("Frame", "Kikiloot", UIParent)
window.item = {}

local loot_master = ""
local player_name = UnitName("player")

-- ##########
-- # LAYOUT #
-- ##########

window:SetBackdrop({bgFile = 'Interface\\Tooltips\\UI-Tooltip-Background'}) -- this is temporary, just for show
window:SetBackdropColor(0, 0, 0, 1) -- this is temporary, just for show
window:SetPoint('CENTER', UIParent)
window:SetWidth(120)
window:SetHeight(30)
window:EnableMouse(true) -- needed for it to be movable
window:RegisterForDrag("LeftButton")
window:SetMovable(true)
window:SetUserPlaced(true) -- saves the place the user dragged it to
window:SetScript("OnDragStart", function() window:StartMoving() end)
window:SetScript("OnDragStop", function() window:StopMovingOrSizing() end)
window:SetClampedToScreen(true) -- so the window cant be moved out of screen


window.button_sr = CreateFrame("Button", nil, window)
window.button_sr:ClearAllPoints()
window.button_sr:SetPoint('BOTTOMLEFT', window, 'BOTTOMLEFT')
window.button_sr:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 8,
    insets = { left = 2, right = 2, top = 2, bottom = 2}})
window.button_sr:SetWidth(30)
window.button_sr:SetHeight(30)
window.button_sr:Show()
window.button_sr.text = window.button_sr:CreateFontString("Status", "OVERLAY", "GameFontNormal")
window.button_sr.text:SetFont(STANDARD_TEXT_FONT, 10, "THINOUTLINE")
window.button_sr.text:SetFontObject(GameFontWhite)
window.button_sr.text:ClearAllPoints()
window.button_sr.text:SetPoint("CENTER", window.button_sr, "CENTER")
window.button_sr.text:SetText("SR")
window.button_sr.text:Show()
window.button_sr:SetBackdropColor(1, 1, 1, 1)
window.button_sr:SetBackdropBorderColor(0, 0, 0, 1)
window.button_sr:SetScript("OnEnter", function()
    window.button_sr:SetBackdropBorderColor(1, 1, 1, 1)
    GameTooltip:SetOwner(window.button_sr, "ANCHOR_TOP")
    GameTooltip:AddLine("Import SR")
end)
window.button_sr:SetScript("OnLeave", function()
    window.button_sr:SetBackdropBorderColor(0, 0, 0, 1)
end)

-- https://github.com/shagu/pfUI/blob/633604ca7177f9786df35094cc91b7d0a1bbbe47/modules/share.lua#L385
window.import_sr = CreateFrame("EditBox", nil, UIParent)
window.import_sr:ClearAllPoints()
window.import_sr:SetPoint("TOPRIGHT", window, "TOPLEFT")
window.import_sr:SetMultiLine(true)
-- window.import_sr:SetTextInsets(15,15,15,15)
window.import_sr:SetFont(STANDARD_TEXT_FONT, 8, "THINOUTLINE")
window.import_sr:SetFontObject(GameFontWhite)
window.import_sr:SetWidth(500)
window.import_sr:SetHeight(100)
window.import_sr:SetBackdrop({bgFile = 'Interface\\Tooltips\\UI-Tooltip-Background'})
window.import_sr:Hide()
window.import_sr:SetScript("OnTextChanged", function()
    ParseRaidres(this:GetText(), data_sr)
end)
window.button_sr:SetScript("OnClick", function()
    window.import_ss:Hide()
    if window.import_sr:IsShown() then
        window.import_sr:Hide()
    else
        window.import_sr:Show()
    end
end)

window.button_ss = CreateFrame("Button", nil, window)
window.button_ss:ClearAllPoints()
window.button_ss:SetPoint('BOTTOMLEFT', window, 'BOTTOMLEFT', 30, 0)
window.button_ss:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 8,
    insets = { left = 2, right = 2, top = 2, bottom = 2}})
window.button_ss:SetWidth(30)
window.button_ss:SetHeight(30)
window.button_ss:Show()
window.button_ss.text = window.button_ss:CreateFontString("Status", "OVERLAY", "GameFontNormal")
window.button_ss.text:SetFont(STANDARD_TEXT_FONT, 10, "THINOUTLINE")
window.button_ss.text:SetFontObject(GameFontWhite)
window.button_ss.text:ClearAllPoints()
window.button_ss.text:SetPoint("CENTER", window.button_ss, "CENTER")
window.button_ss.text:SetText("SS")
window.button_ss.text:Show()
window.button_ss:SetBackdropColor(1, 1, 1, 1)
window.button_ss:SetBackdropBorderColor(0, 0, 0, 1)
window.button_ss:SetScript("OnEnter", function()
    window.button_ss:SetBackdropBorderColor(1, 1, 1, 1)
    GameTooltip:SetOwner(window.button_ss, "ANCHOR_TOP")
    GameTooltip:AddLine("Import Spreadsheet")
end)
window.button_ss:SetScript("OnLeave", function()
    window.button_ss:SetBackdropBorderColor(0, 0, 0, 1)
end)

window.import_ss = CreateFrame("EditBox", nil, UIParent)
window.import_ss:ClearAllPoints()
window.import_ss:SetPoint("TOPRIGHT", window, "TOPLEFT")
window.import_ss:SetMultiLine(true)
-- window.import_ss:SetTextInsets(15,15,15,15)
window.import_ss:SetFont(STANDARD_TEXT_FONT, 8, "THINOUTLINE")
window.import_ss:SetFontObject(GameFontWhite)
window.import_ss:SetWidth(500)
window.import_ss:SetHeight(100)
window.import_ss:SetBackdrop({bgFile = 'Interface\\Tooltips\\UI-Tooltip-Background'})
window.import_ss:Hide()
window.import_ss:SetScript("OnTextChanged", function()
    ParseLootSpreadsheet(this:GetText())
end)
window.button_ss:SetScript("OnClick", function()
    window.import_sr:Hide()
    if window.import_ss:IsShown() then
        window.import_ss:Hide()
    else
        window.import_ss:Show()
    end
end)

window.button_cl = CreateFrame("Button", nil, window)
window.button_cl:ClearAllPoints()
window.button_cl:SetPoint('BOTTOMLEFT', window, 'BOTTOMLEFT', 60, 0)
window.button_cl:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 8,
    insets = { left = 2, right = 2, top = 2, bottom = 2}})
window.button_cl:SetWidth(30)
window.button_cl:SetHeight(30)
window.button_cl:Show()
window.button_cl.text = window.button_cl:CreateFontString("Status", "OVERLAY", "GameFontNormal")
window.button_cl.text:SetFont(STANDARD_TEXT_FONT, 10, "THINOUTLINE")
window.button_cl.text:SetFontObject(GameFontWhite)
window.button_cl.text:ClearAllPoints()
window.button_cl.text:SetPoint("CENTER", window.button_cl, "CENTER")
window.button_cl.text:SetText("CL")
window.button_cl.text:Show()
window.button_cl:SetBackdropColor(1, 1, 1, 1)
window.button_cl:SetBackdropBorderColor(0, 0, 0, 1)
window.button_cl:SetScript("OnEnter", function()
    window.button_cl:SetBackdropBorderColor(1, 1, 1, 1)
    GameTooltip:SetOwner(window.button_cl, "ANCHOR_TOP")
    GameTooltip:AddLine("Clear data")
end)
window.button_cl:SetScript("OnLeave", function()
    window.button_cl:SetBackdropBorderColor(0, 0, 0, 1)
end)
window.button_cl:SetScript("OnClick", function()
    if (player_name == loot_master) then
        BroadCastReset()
    end
end)



-- ##############################
-- # SEND AND RECEIVE ITEM LIST #
-- ##############################

window:RegisterEvent("LOOT_OPENED")
window:RegisterEvent("CHAT_MSG_SYSTEM")
window:RegisterEvent("CHAT_MSG_ADDON")
window:SetScript("OnEvent", function()
    if (event == "LOOT_OPENED") and (player_name == loot_master) then
        BroadCastItems(data_roll)
    elseif event == "CHAT_MSG_SYSTEM" and (player_name == loot_master) then
        local pattern = "(.+) rolls (%d+) %((%d+)-(%d+)%)"
        for source, roll_result, roll_min, roll_max in string.gfind(arg1, pattern) do
            if (roll_min == "1") and (roll_max == "100") and (data_roll_idx>0) then
                BroadCastRoll(data_roll, data_sr, data_roll_idx, source, roll_result)
            end
        end
    elseif event == "CHAT_MSG_ADDON" then
        local pattern_reset = "KL"..kl_id.."_RESET"
        local pattern_icon = "KL"..kl_id.."_(%d+)_ICON" -- loot_icon = arg2
        local pattern_link = "KL"..kl_id.."_(%d+)_LINK" -- loot_link = arg2
        local pattern_name = "KL"..kl_id.."_(%d+)_NAME" -- loot_name = arg2
        local pattern_roll = "KL"..kl_id.."_ROLL_(.+)_(%d+)" -- roll_result = arg2
        for _ in string.gfind(arg1, pattern_reset) do
            ResetData(data_roll)
            DisplayData(window, data_roll, data_sr, data_ss, player_name, loot_master)
            data_roll_idx = -1
            return
        end
        for idx_item in string.gfind(arg1, pattern_icon) do
            AddItem(data_roll, tonumber(idx_item), "_loot_icon", arg2)
            DisplayData(window, data_roll, data_sr, data_ss, player_name, loot_master)
            return
        end
        for idx_item in string.gfind(arg1, pattern_link) do
            AddItem(data_roll, tonumber(idx_item), "_loot_link", arg2)
            return
        end
        for idx_item in string.gfind(arg1, pattern_name) do
            AddItem(data_roll, tonumber(idx_item), "_loot_name", arg2)
            return
        end
        for source, idx_item in string.gfind(arg1, pattern_roll) do
            AddDataRoll(data_roll, source, arg2, tonumber(idx_item))
            DisplayData(window, data_roll, data_sr, data_ss, player_name, loot_master)
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
        window.clock = GetTime()
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
18814,"Ruined Pelt",Ragnaros,Bibbley,Warlock,Destruction,,"04/02/2024, 14:55:41"
18814,"Ruined Pelt",Ragnaros,Aldiuss,Warlock,Destruction,,"04/02/2024, 14:55:41"
18814,"Ruined Pelt",Ragnaros,Cock,Warlock,Destruction,,"04/02/2024, 14:55:41"
18814,"Ruined Pelt",Ragnaros,Cock,Warlock,Destruction,,"04/02/2024, 14:55:41"
18814,"Stringy Vulture Meat",Ragnaros,Kikidora,Warlock,Destruction,,"04/02/2024, 14:55:41"
18814,"Broken Wishbone",Ragnaros,Pestilentia,Warlock,Destruction,,"04/02/2024, 14:55:41"
18814,"Cracked Bill",Ragnaros,Grizzlix,Warlock,Destruction,,"04/02/2024, 14:55:41"
18814,"Rough Vulture Feathers",Ragnaros,Asterixs,Warlock,Destruction,,"04/02/2024, 14:55:41"
18814,"Linen Cloth",Ragnaros,Baldnic,Warlock,Destruction,,"04/02/2024, 14:55:41"
--]]
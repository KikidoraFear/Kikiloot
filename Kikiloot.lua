
-- ##############
-- # PARAMETERS #
-- ##############

local kl_id = 1

local config = {
    min_rarity = 2, -- 0 grey, 1 white and quest items, 2 green, 3 blue, ...
    refresh_time = 1,
    roll_channel = "RAID"
}

-- ##########
-- # LAYOUT #
-- ##########

local function WindowLayout(window)
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
end

local function ButtonLayout(parent, btn, txt, tooltip, pos_offset)
    btn:ClearAllPoints()
    btn:SetPoint('BOTTOMLEFT', parent, 'BOTTOMLEFT', pos_offset, 0)
    btn:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2}})
    btn:SetWidth(30)
    btn:SetHeight(30)
    btn:Show()
    btn.text = btn:CreateFontString("Status", "OVERLAY", "GameFontNormal")
    btn.text:SetFont(STANDARD_TEXT_FONT, 10, "THINOUTLINE")
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
    end)
    btn:SetScript("OnLeave", function()
        btn:SetBackdropBorderColor(0, 0, 0, 1)
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
                GiveMasterLoot(idx_slot, idx_player) -- give everything below min_rarity to yourself (master looter)
            end
        end
    end
end

local function BroadCastRoll(data_roll, data_sr, idx, source, roll_result)
    if not data_roll[idx]._roll[source] then -- only add first roll of player
        -- check SR
        local has_sr = true
        if data_sr[data_roll[idx]._loot_name] then
            has_sr = false -- set to false only if SR exists for item and then check if player has SR
            for _, player_name in ipairs(data_sr[data_roll[idx]._loot_name]) do
                if source == player_name then
                    has_sr = true
                end
            end
        end
        if has_sr then
            SendAddonMessage("KL"..kl_id.."_ROLL_"..source.."_"..idx, roll_result , "RAID") -- "KL4_ROLL_Kikidora_3", 69, "RAID"
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
    table.insert(data_roll[idx]._roll_ranking, source) -- add source to ranking list
    table.sort(data_roll[idx]._roll_ranking, function(keyRhs, keyLhs) return data_roll[idx]._roll[keyLhs] < data_roll[idx]._roll[keyRhs] end) -- sort ranking list
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
            GameTooltip:SetHyperlink(GetItemStringFromItemlink(data_roll[idx_f]._loot_link))
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

local loot_master = ""
local player_name = UnitName("player")

local window = CreateFrame("Frame", "Kikiloot", UIParent)
WindowLayout(window)
window.item = {}

window.button_sr = CreateFrame("Button", nil, window)
ButtonLayout(window, window.button_sr, "SR", "Import SR", 0)

window.import_sr = CreateFrame("EditBox", nil, UIParent)
EditBoxLayout(window, window.import_sr)

window.button_ss = CreateFrame("Button", nil, window)
ButtonLayout(window, window.button_ss, "SS", "Import Spreadsheet", 30)

window.import_ss = CreateFrame("EditBox", nil, UIParent)
EditBoxLayout(window, window.import_ss)

window.button_cl = CreateFrame("Button", nil, window)
ButtonLayout(window, window.button_cl, "CL", "Clear Data", 60)

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
    ParseLootSpreadsheet(this:GetText())
end)

window.button_cl:SetScript("OnClick", function()
    if (player_name == loot_master) then
        BroadCastReset()
    end
end)

-- #########################
-- # SEND AND RECEIVE DATA #
-- #########################

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
18814,"Goretusk Liver",Ragnaros,Bibbley,Warlock,Destruction,,"04/02/2024, 14:55:41"
18814,"Goretusk Liver",Ragnaros,Aldiuss,Warlock,Destruction,,"04/02/2024, 14:55:41"
18814,"Goretusk Liver",Ragnaros,Cock,Warlock,Destruction,,"04/02/2024, 14:55:41"
18814,"Goretusk Liver",Ragnaros,Kikidora,Warlock,Destruction,,"04/02/2024, 14:55:41"
18814,"Stringy Vulture Meat",Ragnaros,Kikidora,Warlock,Destruction,,"04/02/2024, 14:55:41"
18814,"Broken Wishbone",Ragnaros,Pestilentia,Warlock,Destruction,,"04/02/2024, 14:55:41"
18814,"Cracked Bill",Ragnaros,Grizzlix,Warlock,Destruction,,"04/02/2024, 14:55:41"
18814,"Rough Vulture Feathers",Ragnaros,Asterixs,Warlock,Destruction,,"04/02/2024, 14:55:41"
18814,"Linen Cloth",Ragnaros,Baldnic,Warlock,Destruction,,"04/02/2024, 14:55:41"
18814,"Chunk of Boar Meat",Ragnaros,Baldnic,Warlock,Destruction,,"04/02/2024, 14:55:41"
--]]
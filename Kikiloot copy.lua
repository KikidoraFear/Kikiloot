
-- Loot master opens loot -> roll loot button appears -> if button pressed -> loot data is added to table
-- items with rarity x are linked in chat
-- item links are sent via addon channel
-- generate item link list
-- windows opens with item | button_roll | sorted roll results (Kikidora: 45)
-- loot master generates random numbers for each player and sends result to addon channel
-- pressed button_roll is sent via addon channel
-- loot master is able to reset the window (remove entries)
-- maybe do some animation of rolls with bars to make it MORE EXCITING
-- show item that's currently being rolled for in frame if you're not loot master

-- ##############
-- # PARAMETERS #
-- ##############

local kl_id = 1

local config = {
    min_rarity = 0,
    refresh_time = 1
}

-- ToDo: How to handle if loot master loots mob multiple times
-- data[1]._loot_link = link
-- data[1]._loot_name = name
-- data[1]._roll[player_name] = math.random(100)
local data = {}
local data_idx_roll = -1

-- data[loot][1] = player_name -- list of players who have SR on item
local data_sr = {}

local data_ss = {}

-- ####################
-- # HELPER FUNCTIONS #
-- ####################

-- for debugging: DEFAULT_CHAT_FRAME:AddMessage("Test")
local function print(msg)
    DEFAULT_CHAT_FRAME:AddMessage(msg)
end

-- ID,Item,Boss,Attendee,Class,Specialization,Comment,Date
-- 21110,"Splintered Tusk",Ragnaros,Bibbley,Warrior,Protection,,"04/02/2024, 14:53:38"
-- 21110,"Splintered Tusk",Ragnaros,Kikidora,Warrior,Protection,,"04/02/2024, 14:53:38"
-- 18814,"Splintered Tusk",Ragnaros,Asdf,Warlock,Destruction,,"04/02/2024, 14:55:41"
-- 18814,"Ruined Pelt",Ragnaros,Bibbley,Warlock,Destruction,,"04/02/2024, 14:55:41"
-- 18814,"Ruined Pelt",Ragnaros,Aldiuss,Warlock,Destruction,,"04/02/2024, 14:55:41"
-- 18814,"Ruined Pelt",Ragnaros,Cock,Warlock,Destruction,,"04/02/2024, 14:55:41"
local function ParseRaidres(text)
    text = string.gsub(text, 'ID,Item,Boss,Attendee,Class,Specialization,Comment,Date', '') -- remove header
    local pattern = '(.-),(.-),(.-),(.-),(.-),(.-),(.-),(.-),(.-)'
    text = string.gsub(text, '"', '') -- remove " from text, raidres places it randomly, idk
    data_sr = {}
    for id, item, boss, attendee, class, specialization, comment, date in string.gfind(text, pattern) do
        print(item..": "..attendee)
        if not data_sr[item] then
            data_sr[item] = {}
        end
        table.insert(data_sr[item], attendee)
    end
end

-- Splintered Tusk,Warrior Fury,All Ranks
-- Ruined Pelt,Paladin Tank,All Ranks
-- Boots of Blistering Flames,Mage,All Ranks
-- Ashskin Belt,Rogue,All Ranks
-- Shoulderpads of True Flight,Shaman Enh/Hunter,All Ranks
local function ParseLootSpreadsheet(text)
    text = text.."\n"
    local pattern = '(.-),(.-),(.-)\n'
    data_ss = {}
    for item, prio, rank in string.gfind(text, pattern) do
        print(item..": "..rank.." -> "..prio)
        data_ss[item] = rank.." -> "..prio
    end
end

local function BroadCastRolledLoot(loot_link, loot_icon)
    SendAddonMessage("KM"..kl_id.."_"..loot_link, loot_icon , "RAID") -- "KM4_ouro_dmg_hit", "10", "RAID"
end

local function AddItems(data)
    local idx_item = 1
    for idx_slot = 1, GetNumLootItems() do
        if (LootSlotIsItem(idx_slot)) then -- if is item (i.e. not gold)
            local loot_icon, loot_name, loot_quantity, loot_rarity = GetLootSlotInfo(idx_slot)
            local loot_link = GetLootSlotLink(idx_slot);
            if loot_rarity >= config.min_rarity then
                data[idx_item] = {}
                data[idx_item]._loot_icon = loot_icon
                data[idx_item]._loot_link = loot_link
                data[idx_item]._loot_name = loot_name
                data[idx_item]._roll = {}
                data[idx_item]._roll_ranking = {}
                idx_item = idx_item+1
            end
        end
    end
end

local function RollItem(data, idx)
    SendChatMessage("### KIKILOOT ###" , "PARTY", nil, nil)
    SendChatMessage("Roll for "..data[idx]._loot_link , "PARTY", nil, nil)
    if data_ss[data[idx]._loot_name] then
        SendChatMessage("Comment: "..data_ss[data[idx]._loot_name], "PARTY", nil, nil)
    end
    if data_sr[data[idx]._loot_name] then
        local sr_text = "SR: "
        for _,player_name in ipairs(data_sr[data[idx]._loot_name]) do
            sr_text = sr_text..player_name..", "
        end
        SendChatMessage(sr_text , "PARTY", nil, nil)
    end
    SendChatMessage("### KIKILOOT ###" , "PARTY", nil, nil)
    data_idx_roll = idx
end

local function DisplayData(data, window)
    for idx,_ in ipairs(window.item) do
        window.item[idx]:Hide()
        for idx_t,_ in ipairs(window.item[idx].text) do
            window.item[idx].text[idx_t]:Hide()
        end
    end
    for idx,_ in ipairs(data) do
        local idx_f = idx
        window.item[idx] = CreateFrame("Button", nil, window)
        window.item[idx]:SetBackdrop({bgFile=data[idx]._loot_icon,
            edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
            tile = false, tileSize = 16, edgeSize = 8,
            insets = { left = 2, right = 2, top = 2, bottom = 2}})
        window.item[idx]:ClearAllPoints()
        window.item[idx]:SetPoint('TOPLEFT', window, 'TOPLEFT', 0, -32*(idx-1))
        window.item[idx]:SetWidth(30)
        window.item[idx]:SetHeight(30)
        window.item[idx]:Show()
        window.item[idx]:SetScript("OnClick", function()
            RollItem(data, idx_f)
        end)
        window.item[idx]:SetScript("OnEnter", function()
            GameTooltip:SetOwner(window.item[idx_f], "ANCHOR_TOP")
            GameTooltip:AddLine(data[idx_f]._loot_link)
            GameTooltip:Show()
        end)
        window.item[idx]:SetScript("OnLeave", function()
            GameTooltip:Hide()
          end)

        if not window.item[idx].text then
            window.item[idx].text = {}
        end
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
end

-- ########
-- # INIT #
-- ########

local window = CreateFrame("Frame", "Kikiloot", UIParent)
window:SetBackdrop({bgFile = 'Interface\\Tooltips\\UI-Tooltip-Background'}) -- this is temporary, just for show
window:SetBackdropColor(0, 1, 0, 1) -- this is temporary, just for show
window:SetPoint('CENTER', UIParent)
window:SetWidth(100)
window:SetHeight(30)
window:EnableMouse(true) -- needed for it to be movable
window:RegisterForDrag("LeftButton")
window:SetMovable(true)
window:SetUserPlaced(true) -- saves the place the user dragged it to
window:SetScript("OnDragStart", function() window:StartMoving() end)
window:SetScript("OnDragStop", function() window:StopMovingOrSizing() end)
window:SetClampedToScreen(true) -- so the window cant be moved out of screen

window.item = {}

window.button_sr = CreateFrame("Button", nil, window)
window.button_sr:ClearAllPoints()
window.button_sr:SetPoint('BOTTOMRIGHT', window, 'TOPRIGHT')
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
    ParseRaidres(this:GetText())
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
window.button_ss:SetPoint('BOTTOMRIGHT', window, 'TOPRIGHT', -30, 0)
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




local loot_master = ""
local player_name = UnitName("player")


-- CreateFrame("EditBox", nil, UIParent)
-- StaticPopup_Show("GET_RAIDRES")
-- StaticPopup_Hide("GET_RAIDRES")

-- ##############################
-- # SEND AND RECEIVE ITEM LIST #
-- ##############################

local function AddDataRoll(data, player_name, roll_result, data_idx_roll)
    if (data_idx_roll > 0) and (not data[data_idx_roll]._roll[player_name]) then
        -- check SR
        local has_sr = true
        if data_sr[data[data_idx_roll]._loot_name] then
            has_sr = false -- set to false only if SR exists and then check if player has SR
            for _, value in ipairs(data_sr[data[data_idx_roll]._loot_name]) do
                if player_name == value then
                    has_sr = true
                end
            end
        end
        if has_sr then
            -- add roll to data
            data[data_idx_roll]._roll[player_name] = roll_result
            -- rank people who rolled
            data[data_idx_roll]._roll_ranking = {}
            for key, _ in pairs(data[data_idx_roll]._roll) do
                table.insert(data[data_idx_roll]._roll_ranking, key) -- creates an array with player_names
            end
            table.sort(data[data_idx_roll]._roll_ranking, function(keyRhs, keyLhs) return data[data_idx_roll]._roll[keyLhs] < data[data_idx_roll]._roll[keyRhs] end)
            -- display top 3
            for rank, rank_player_name in ipairs(data[data_idx_roll]._roll_ranking) do
                if rank > 3 then -- only show top 3
                    break
                end
                window.item[data_idx_roll].text[rank]:SetText(data[data_idx_roll]._roll[rank_player_name].." "..rank_player_name)
                window.item[data_idx_roll].text[rank]:Show()
            end
        end
    end
end

window:RegisterEvent("LOOT_OPENED")
window:RegisterEvent("CHAT_MSG_SYSTEM")
window:SetScript("OnEvent", function()
    if (event == "LOOT_OPENED") then --and (player_name == loot_master) then
        data = {}
        data_idx_roll = -1
        AddItems(data)
        DisplayData(data, window)
    elseif event == "CHAT_MSG_SYSTEM" then
        local pattern = "(.+) rolls (%d+) %((%d+)-(%d+)%)"
        for player_name, roll_result, roll_min, roll_max in string.gfind(arg1, pattern) do
            if (roll_min == "1") and (roll_max == "100") then
                AddDataRoll(data, player_name, roll_result, data_idx_roll)
            end
        end
    end
end)

-- check loot master
window:SetScript("OnUpdate", function()
    if not window.clock then window.clock = GetTime() end
    if GetTime() > window.clock + config.refresh_time then
        local _, loot_master_party_id, loot_master_raid_id = GetLootMethod()
        if loot_master_raid_id then
            if loot_master_raid_id == 0 then
                loot_master = UnitName("player")
            else
                loot_master = UnitName("raid"..loot_master_raid_id)
            end
        elseif loot_master_party_id then
            if loot_master_party_id == 0 then
                loot_master = UnitName("player")
            else
                loot_master = UnitName("party"..loot_master_party_id)
            end
        end
        window.clock = GetTime()
    end
end)
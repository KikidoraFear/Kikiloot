
-- for debugging: DEFAULT_CHAT_FRAME:AddMessage("Test")
local function print(msg)
  DEFAULT_CHAT_FRAME:AddMessage(msg)
end


-- broadcast value to hidden addon channel
local function BroadcastValue(section, kind, attack, value)
  SendAddonMessage()
end


local window = CreateFrame("Frame", "Kikiloot", UIParent)

window:RegisterEvent("LOOT_OPENED")

window:SetScript("OnEvent", function()
  for index = 1, GetNumLootItems() do
    if (LootSlotIsItem(index)) then
      local lootIcon, lootName, lootQuantity, rarity = GetLootSlotInfo(index)
      local item_link = GetLootSlotLink(index);
      print(lootIcon.."_"..lootName.."_"..lootQuantity.."_"..rarity.."_"..item_link)
    end
  end
  
end)

-- for better performance, call UpdateBars only each config.refresh_time seconds
-- and calculate only one table (dmg, eheal or oheal) at a time
-- window:SetScript("OnUpdate", function()
--   if not window.clock then window.clock = GetTime() end
--   if not window.cycle then window.cycle = 0 end
  

--   if GetTime() > window.clock + config.refresh_time then

--     -- GetLootSlotInfo
--     -- GetLootSlotLink

--     window.clock = GetTime()
--     window.cycle = math.mod(window.cycle + 1, 5)
--   end
-- end)
--[[
    OneStorageScrap - Core.lua
    Automated vendor junk seller with safe transaction batching,
    chat profit reports, and custom scrap whitelist/blacklist overrides.
--]]

local addonName, addonTable = ...
_G.OneStorageScrap = _G.OneStorageScrap or addonTable
local OneStorageScrap = _G.OneStorageScrap

local Utils = _G.OneStorageUtils
local ContainerHelper = Utils and Utils.ContainerHelper

local isSelling = false
local itemsSold = 0
local startMoney = 0

local defaultDB = {
    autoSell = true,
    printSummary = true,
    safeList = {}, -- itemID -> true (never sell)
    junkList = {}, -- itemID -> true (always sell)
}

-------------------------------------------------------------------------------
-- Custom Scrap Check Hook Registration
-------------------------------------------------------------------------------

local function SetupScrapHook()
    if not ContainerHelper or not ContainerHelper.SetScrapCheckCallback then return end
    
    ContainerHelper:SetScrapCheckCallback(function(bagID, slotID, itemID, quality)
        local db = _G.OneStorageScrapDB or defaultDB
        
        -- 1. Safe List (Protected: Never sell)
        if itemID and db.safeList and db.safeList[itemID] then
            return false
        end
        
        -- 2. Custom Junk List (Always sell)
        if itemID and db.junkList and db.junkList[itemID] then
            return true
        end
        
        -- 3. Default: Poor Quality (Grey)
        if quality == 0 then
            return true
        end
        
        return false
    end)
end

-------------------------------------------------------------------------------
-- Safe Batch Selling Engine
-------------------------------------------------------------------------------

function OneStorageScrap:SellJunk()
    local db = _G.OneStorageScrapDB or defaultDB
    if not db.autoSell then return end
    if isSelling then return end
    
    local queue = {}
    for _, bagID in ipairs(ContainerHelper.BAG_IDS) do
        local numSlots = ContainerHelper:GetNumSlots(bagID)
        for slotID = 1, numSlots do
            if ContainerHelper:IsJunk(bagID, slotID) then
                local info = ContainerHelper:GetItemInfo(bagID, slotID)
                if info and not info.locked and not info.noValue then
                    table.insert(queue, { bagID = bagID, slotID = slotID })
                end
            end
        end
    end
    
    if #queue == 0 then return end
    
    isSelling = true
    itemsSold = #queue
    startMoney = GetMoney() or 0
    
    -- Process in throttled batches of 12 items to prevent server rate-limiting
    local function ProcessBatch(index)
        if not isSelling then return end
        
        local endIndex = math.min(index + 11, #queue)
        for i = index, endIndex do
            local item = queue[i]
            ContainerHelper:UseItem(item.bagID, item.slotID)
        end
        
        if endIndex < #queue then
            if C_Timer and C_Timer.After then
                C_Timer.After(0.2, function() ProcessBatch(endIndex + 1) end)
            else
                ProcessBatch(endIndex + 1)
            end
        else
            -- Selling complete; wait 0.3s for final money update
            if C_Timer and C_Timer.After then
                C_Timer.After(0.3, function()
                    local profit = math.max(0, (GetMoney() or 0) - startMoney)
                    if db.printSummary and itemsSold > 0 and profit > 0 then
                        print(string.format("|cff00ccff[OneStorageScrap]|r Sold %d junk items for %s.",
                            itemsSold, ContainerHelper:FormatMoney(profit)))
                    end
                    isSelling = false
                end)
            else
                local profit = math.max(0, (GetMoney() or 0) - startMoney)
                if db.printSummary and itemsSold > 0 and profit > 0 then
                    print(string.format("|cff00ccff[OneStorageScrap]|r Sold %d junk items for %s.",
                        itemsSold, ContainerHelper:FormatMoney(profit)))
                end
                isSelling = false
            end
        end
    end
    
    ProcessBatch(1)
end

-------------------------------------------------------------------------------
-- Event Dispatcher
-------------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame", "OneStorageScrap_EventFrame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("MERCHANT_SHOW")
eventFrame:RegisterEvent("MERCHANT_CLOSED")

eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        _G.OneStorageScrapDB = _G.OneStorageScrapDB or {}
        for k, v in pairs(defaultDB) do
            if _G.OneStorageScrapDB[k] == nil then
                _G.OneStorageScrapDB[k] = v
            end
        end
        SetupScrapHook()
        
    elseif event == "PLAYER_LOGIN" then
        SetupScrapHook()
        
    elseif event == "MERCHANT_SHOW" then
        OneStorageScrap:SellJunk()
        
    elseif event == "MERCHANT_CLOSED" then
        isSelling = false
    end
end)

-------------------------------------------------------------------------------
-- Slash Command Registry
-------------------------------------------------------------------------------

SLASH_ONESTORAGESCRAP1 = "/onescrap"
SLASH_ONESTORAGESCRAP2 = "/osscrap"
SlashCmdList["ONESTORAGESCRAP"] = function(msg)
    local db = _G.OneStorageScrapDB or defaultDB
    local cmd, arg = strsplit(" ", (msg or ""):lower(), 2)
    
    if cmd == "toggle" then
        db.autoSell = not db.autoSell
        local status = db.autoSell and "|cff00ff00ENABLED|r" or "|cffff0000DISABLED|r"
        print("|cff00ccff[OneStorageScrap]|r Auto-selling is now " .. status)
        
    elseif cmd == "add" and arg then
        local itemID = tonumber(arg) or tonumber(arg:match("item:(%d+)"))
        if itemID then
            db.junkList[itemID] = true
            db.safeList[itemID] = nil
            local name = GetItemInfo(itemID) or ("Item " .. itemID)
            print("|cff00ccff[OneStorageScrap]|r Added " .. name .. " to custom junk list.")
            if OneStorageBag and OneStorageBag.frame and OneStorageBag.frame:IsShown() then
                OneStorageBag:RefreshLayout()
            end
        else
            print("|cffff0000[OneStorageScrap]|r Usage: /osscrap add [itemID or ItemLink]")
        end
        
    elseif cmd == "safe" and arg then
        local itemID = tonumber(arg) or tonumber(arg:match("item:(%d+)"))
        if itemID then
            db.safeList[itemID] = true
            db.junkList[itemID] = nil
            local name = GetItemInfo(itemID) or ("Item " .. itemID)
            print("|cff00ccff[OneStorageScrap]|r Added " .. name .. " to protected safe list.")
            if OneStorageBag and OneStorageBag.frame and OneStorageBag.frame:IsShown() then
                OneStorageBag:RefreshLayout()
            end
        else
            print("|cffff0000[OneStorageScrap]|r Usage: /osscrap safe [itemID or ItemLink]")
        end
        
    else
        print("|cff00ccff[OneStorageScrap]|r Commands:")
        print("  /osscrap toggle       - Toggle automatic junk selling")
        print("  /osscrap add <link>   - Always sell this item as junk")
        print("  /osscrap safe <link>  - Protect this item from ever being sold")
    end
end

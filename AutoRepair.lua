--[[
    OneStorageScrap - AutoRepair.lua
    Automated equipment repairs at vendors with guild bank funds prioritization.
--]]

local addonName, addonTable = ...
local OneStorageScrap = _G.OneStorageScrap or addonTable

local Utils = _G.OneStorageUtils
local ContainerHelper = Utils and Utils.ContainerHelper

local function AttemptAutoRepair()
    local db = _G.OneStorageScrapDB
    if not db or db.autoRepair == false then return end
    
    if not CanMerchantRepair or not CanMerchantRepair() then return end
    
    local repairCost, canRepair = GetRepairAllCost()
    if not canRepair or not repairCost or repairCost <= 0 then return end
    
    -- 1. Try Guild Bank Funds
    if db.useGuildRepair ~= false and CanGuildBankRepair and CanGuildBankRepair() then
        local guildMoney = GetGuildBankWithdrawMoney and GetGuildBankWithdrawMoney() or 0
        if guildMoney == -1 or guildMoney >= repairCost then
            RepairAllItems(true)
            if db.printSummary ~= false and ContainerHelper then
                print(string.format("|cff00ccff[OneStorageScrap]|r Repaired all items using Guild Funds for %s.",
                    ContainerHelper:FormatMoney(repairCost)))
            end
            return
        end
    end
    
    -- 2. Personal Player Funds Fallback
    local playerMoney = GetMoney() or 0
    if playerMoney >= repairCost then
        RepairAllItems(false)
        if db.printSummary ~= false and ContainerHelper then
            print(string.format("|cff00ccff[OneStorageScrap]|r Repaired all items for %s.",
                ContainerHelper:FormatMoney(repairCost)))
        end
    else
        print("|cffff0000[OneStorageScrap]|r Insufficient funds to repair equipment.")
    end
end

local repairFrame = CreateFrame("Frame", "OneStorageScrap_RepairFrame")
repairFrame:RegisterEvent("MERCHANT_SHOW")
repairFrame:SetScript("OnEvent", function(self, event)
    if event == "MERCHANT_SHOW" then
        AttemptAutoRepair()
    end
end)

-- Slash Command Extension
SLASH_ONESTORAGEREPAIR1 = "/osrepair"
SlashCmdList["ONESTORAGEREPAIR"] = function(msg)
    local db = _G.OneStorageScrapDB
    if not db then return end
    
    local cmd = (msg or ""):lower():match("^%s*(.-)%s*$")
    if cmd == "guild" then
        db.useGuildRepair = not db.useGuildRepair
        local state = db.useGuildRepair and "|cff00ff00ENABLED|r" or "|cffff0000DISABLED|r"
        print("|cff00ccff[OneStorageScrap]|r Guild fund auto-repair is now " .. state)
    else
        db.autoRepair = not db.autoRepair
        local state = db.autoRepair and "|cff00ff00ENABLED|r" or "|cffff0000DISABLED|r"
        print("|cff00ccff[OneStorageScrap]|r Auto-repair is now " .. state)
    end
end

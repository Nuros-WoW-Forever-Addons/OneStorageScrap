--[[
    OneStorageScrap - AutoRepair.lua
    Automated equipment repairs at vendors with guild bank funds prioritization.
--]]

local addonName, addonTable = ...
local OneStorageScrap = _G.OneStorageScrap or addonTable

local Utils = _G.OneStorageUtils
local ContainerHelper = Utils and Utils.ContainerHelper

local function AttemptAutoRepair()
    if not OneStorageScrap:GetOption("autoRepair") then return end
    
    if not CanMerchantRepair or not CanMerchantRepair() then return end
    
    local repairCost, canRepair = GetRepairAllCost()
    if not canRepair or not repairCost or repairCost <= 0 then return end
    
    -- 1. Try Guild Bank Funds
    if OneStorageScrap:GetOption("useGuildRepair") and CanGuildBankRepair and CanGuildBankRepair() then
        local guildMoney = GetGuildBankWithdrawMoney and GetGuildBankWithdrawMoney() or 0
        if guildMoney == -1 or guildMoney >= repairCost then
            RepairAllItems(true)
            if OneStorageScrap:GetOption("printSummary") and ContainerHelper then
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
        if OneStorageScrap:GetOption("printSummary") and ContainerHelper then
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
    local cmd = (msg or ""):lower():match("^%s*(.-)%s*$")
    if cmd == "opt" or cmd == "options" or cmd == "config" or cmd == "gui" or cmd == "" then
        OneStorageScrap:ToggleOptions()
    elseif cmd == "guild" then
        local current = OneStorageScrap:GetOption("useGuildRepair")
        OneStorageScrap:SetOption("useGuildRepair", not current)
        local state = OneStorageScrap:GetOption("useGuildRepair") and "|cff00ff00ENABLED|r" or "|cffff0000DISABLED|r"
        print("|cff00ccff[OneStorageScrap]|r Guild fund auto-repair is now " .. state)
        if OneStorageScrap.optionsFrame and OneStorageScrap.optionsFrame:IsShown() then
            OneStorageScrap.optionsFrame:RefreshOptions()
        end
    else
        local current = OneStorageScrap:GetOption("autoRepair")
        OneStorageScrap:SetOption("autoRepair", not current)
        local state = OneStorageScrap:GetOption("autoRepair") and "|cff00ff00ENABLED|r" or "|cffff0000DISABLED|r"
        print("|cff00ccff[OneStorageScrap]|r Auto-repair is now " .. state)
        if OneStorageScrap.optionsFrame and OneStorageScrap.optionsFrame:IsShown() then
            OneStorageScrap.optionsFrame:RefreshOptions()
        end
    end
end

--[[
    OneStorageScrap - Core.lua
    Automated vendor junk seller with safe transaction batching,
    chat profit reports, custom scrap whitelist/blacklist overrides,
    and graphical options panel.
--]]

local addonName, addonTable = ...
_G.OneStorageScrap = _G.OneStorageScrap or addonTable
local OneStorageScrap = _G.OneStorageScrap

local Utils = _G.OneStorageUtils
local ContainerHelper = Utils and Utils.ContainerHelper
local FrameHelper = Utils and Utils.FrameHelper

local isSelling = false
local itemsSold = 0
local startMoney = 0

local defaultDB = {
    autoSell = true,           -- Master toggle for automated selling
    sellGreys = true,          -- Auto-sell poor (grey / quality 0) items
    sellWhites = false,        -- Auto-sell common (white / quality 1) items
    autoRepair = true,         -- Auto-repair equipment at repair vendors
    useGuildRepair = false,    -- Use guild bank funds if available
    printSummary = true,       -- Print sales & repair reports to chat
    safeList = {},             -- [itemID] = true (never sell)
    junkList = {},             -- [itemID] = true (always sell)
    optionsPosition = nil,     -- Saved window coordinates
}

function OneStorageScrap:GetOption(key)
    if _G.OneStorageScrapDB and _G.OneStorageScrapDB[key] ~= nil then
        return _G.OneStorageScrapDB[key]
    end
    return defaultDB[key]
end

function OneStorageScrap:SetOption(key, val)
    _G.OneStorageScrapDB = _G.OneStorageScrapDB or {}
    _G.OneStorageScrapDB[key] = val
end

-------------------------------------------------------------------------------
-- Custom Scrap Check Hook Registration
-------------------------------------------------------------------------------

local function GetContainerHelper()
    if ContainerHelper then return ContainerHelper end
    if _G.OneStorageUtils and _G.OneStorageUtils.ContainerHelper then
        ContainerHelper = _G.OneStorageUtils.ContainerHelper
        return ContainerHelper
    end
    return nil
end

-------------------------------------------------------------------------------
-- Profession Tools & Equipment Shield
-------------------------------------------------------------------------------

local PROFESSION_TOOL_ITEM_IDS = {
    -- Fishing Poles
    [6256] = true,   -- Fishing Pole
    [6365] = true,   -- Strong Fishing Pole
    [6366] = true,   -- Darkwood Fishing Pole
    [6367] = true,   -- Big Iron Fishing Pole
    [12225] = true,  -- Blump Family Fishing Pole
    [19022] = true,  -- Nat Pagle's Extreme Angler FC-5000
    [19970] = true,  -- Arcanite Fishing Pole
    [25924] = true,  -- Mastercraft Kalu'ak Fishing Pole
    [44050] = true,  -- Mastercraft Kalu'ak Fishing Pole
    [45858] = true,  -- Nat's Lucky Fishing Pole
    [45991] = true,  -- Bone Fishing Pole
    [45992] = true,  -- Jeweled Fishing Pole
    [84661] = true,  -- Dragon Fishing Pole
    [116825] = true, -- Savage Fishing Pole
    [116826] = true, -- Draenic Fishing Pole
    [133755] = true, -- Underlight Angler
    
    -- Mining Picks
    [2901] = true,   -- Mining Pick
    [1819] = true,   -- Gnomish Universal Remote
    [19593] = true,  -- Dark Iron Mining Pick
    [104192] = true, -- Cobalt Mining Pick
    
    -- Skinning Knives
    [7005] = true,   -- Skinning Knife
    [7006] = true,   -- Skinning Knife
    [12709] = true,  -- Finkle's Skinner
    [19901] = true,  -- Zulian Slicer
    
    -- Blacksmith Hammers
    [5956] = true,   -- Blacksmith Hammer
    [19592] = true,  -- Dark Iron Blacksmithing Hammer
    
    -- Engineering Tools
    [6219] = true,   -- Arclight Spanner
    [18256] = true,  -- Gyromatic Micro-Adjustor
    [40768] = true,  -- Gnomish Army Knife
    [54440] = true,  -- Gnomish Army Knife
    
    -- Jewelcrafting & Inscription & Cooking
    [20815] = true,  -- Jeweler's Kit
    [20824] = true,  -- Simple Grinder
    [39501] = true,  -- Virtuoso Inking Set
    [4470] = true,   -- Simple Wood
    [4471] = true,   -- Flint and Tinder
    [16084] = true,  -- Cooking Pot
    
    -- Enchanting Rods (Runed Rods)
    [6218] = true,   -- Runed Copper Rod
    [6339] = true,   -- Runed Silver Rod
    [11130] = true,  -- Runed Golden Rod
    [11145] = true,  -- Runed Truesilver Rod
    [16207] = true,  -- Runed Arcanite Rod
    [22461] = true,  -- Runed Fel Iron Rod
    [22462] = true,  -- Runed Adamantite Rod
    [22463] = true,  -- Runed Eternium Rod
    [44452] = true,  -- Runed Titanium Rod
    
    -- Alchemy
    [9149] = true,   -- Philosopher's Stone
    [13503] = true,  -- Alchemist Stone
}

local function IsProfessionTool(bagID, slotID, itemID, classID, subclassID, equipLoc)
    -- 1. Fishing Poles (Class 2 = Weapon, Subclass 20 = Fishingpole)
    if classID == 2 and (subclassID == 20 or (Enum and Enum.ItemWeaponSubclass and subclassID == Enum.ItemWeaponSubclass.Fishingpole)) then
        return true
    end
    
    -- 2. Profession Class (18) or Profession Tool Equipment Slots
    if classID == 18 or (Enum and Enum.ItemClass and classID == Enum.ItemClass.Profession) then
        return true
    end
    if equipLoc == "INVTYPE_PROFESSION_TOOL" or equipLoc == "INVTYPE_PROFESSION_GEAR" then
        return true
    end
    
    -- 3. Predefined Known Profession Tool Item IDs
    if itemID and PROFESSION_TOOL_ITEM_IDS[itemID] then
        return true
    end
    
    -- 4. Deep Tooltip Keyword Scan
    if C_TooltipInfo and C_TooltipInfo.GetBagItem and bagID and slotID then
        local ok, data = pcall(C_TooltipInfo.GetBagItem, bagID, slotID)
        if ok and data and data.lines then
            for _, line in ipairs(data.lines) do
                local text = line.leftText
                if text and type(text) == "string" then
                    local lower = text:lower()
                    if lower:find("fishing pole", 1, true)
                        or lower:find("tool:", 1, true)
                        or lower:find("requires fishing", 1, true)
                        or lower:find("requires mining", 1, true)
                        or lower:find("requires skinning", 1, true)
                        or lower:find("requires herbalism", 1, true)
                        or lower:find("requires blacksmithing", 1, true)
                        or lower:find("requires engineering", 1, true)
                        or lower:find("requires alchemy", 1, true)
                        or lower:find("requires cooking", 1, true)
                        or lower:find("requires enchanting", 1, true)
                        or lower:find("requires jewelcrafting", 1, true)
                        or lower:find("requires inscription", 1, true)
                        or lower:find("increases fishing", 1, true)
                        or lower:find("fishing lure", 1, true)
                    then
                        return true
                    end
                end
            end
        end
    end
    
    return false
end

local function SetupScrapHook()
    local ch = GetContainerHelper()
    if not ch or not ch.SetScrapCheckCallback then return end
    
    ch:SetScrapCheckCallback(function(bagID, slotID, itemID, quality, itemInfo)
        local safeList = OneStorageScrap:GetOption("safeList")
        local junkList = OneStorageScrap:GetOption("junkList")
        
        -- 1. Safe List (Protected: Never sell)
        if itemID and safeList and safeList[itemID] then
            return false
        end
        if itemID == 6948 then -- Hearthstone is always protected
            return false
        end
        
        -- 2. Custom Junk List (Always sell)
        if itemID and junkList and junkList[itemID] then
            return true
        end
        
        -- If auto-selling is disabled globally, do not mark defaults as junk
        if not OneStorageScrap:GetOption("autoSell") then
            return false
        end
        
        local info = itemInfo
        if not info and ch.GetItemInfo then
            info = ch:GetItemInfo(bagID, slotID)
        end
        
        -- Resolve item quality with multi-level fallbacks
        local itemQuality = quality
        if itemQuality == nil and info then
            itemQuality = info.quality
        end
        if itemQuality == nil and itemID and C_Item and C_Item.GetItemQualityByID then
            itemQuality = C_Item.GetItemQualityByID(itemID)
        end
        if itemQuality == nil and info and info.link and type(info.link) == "string" then
            local lowerLink = info.link:lower()
            if lowerLink:find("cffffffff", 1, true) then
                itemQuality = 1
            elseif lowerLink:find("cff9d9d9d", 1, true) then
                itemQuality = 0
            end
        end
        if itemQuality == nil and itemID and GetItemInfo then
            itemQuality = select(3, GetItemInfo(itemID))
        end
        
        -- 3. Poor Quality (Grey / Quality 0)
        if OneStorageScrap:GetOption("sellGreys") and itemQuality == 0 then
            if info and info.noValue then
                return false
            end
            return true
        end
        
        -- 4. Common Quality (White / Quality 1)
        if OneStorageScrap:GetOption("sellWhites") and itemQuality == 1 then
            -- Safety 1: Must not be unsellable / no value
            if info and info.noValue then
                return false
            end
            
            -- Safety 2: Cannot be a quest item (via native C_Container API table or multiple returns)
            -- Note: In modern WoW, GetContainerItemQuestInfo returns a table { isQuestItem = false, questID = 0, isActive = false }
            -- where questID is 0 for non-quest items. In Lua, 0 is truthy! We must check questID > 0.
            if C_Container and C_Container.GetContainerItemQuestInfo then
                local ok, ret1, ret2 = pcall(C_Container.GetContainerItemQuestInfo, bagID, slotID)
                if ok and ret1 ~= nil then
                    if type(ret1) == "table" then
                        if ret1.isQuestItem == true or (type(ret1.questID) == "number" and ret1.questID > 0) then
                            return false
                        end
                    elseif ret1 == true or ret1 == 1 or (type(ret2) == "number" and ret2 > 0) then
                        return false
                    end
                end
            end
            
            -- Safety 3: Synchronous Item Class checks via C_Item.GetItemInfoInstant
            -- Disallow Profession Tools, Fishing Poles, Food, Consumables, Reagents, Trade Goods, Bags, Recipes, and Quest Items
            if itemID and C_Item and C_Item.GetItemInfoInstant then
                local ok, eqLoc, classID, subclassID = pcall(function(id)
                    local _, _, _, e, _, c, s = C_Item.GetItemInfoInstant(id)
                    return e, c, s
                end, itemID)
                if ok and classID then
                    -- Profession Tools & Fishing Poles
                    if IsProfessionTool(bagID, slotID, itemID, classID, subclassID, eqLoc) then
                        return false
                    end
                    -- Consumables (Food, Drink, Potions, Bandages, Elixirs)
                    if classID == 0 or (Enum and Enum.ItemClass and classID == Enum.ItemClass.Consumable) then
                        return false
                    end
                    -- Crafting Reagents & Trade Goods
                    if classID == 7 or (Enum and Enum.ItemClass and classID == Enum.ItemClass.Tradegoods) then
                        return false
                    end
                    if classID == 5 or (Enum and Enum.ItemClass and classID == Enum.ItemClass.Reagent) then
                        return false
                    end
                    if classID == 18 or (Enum and Enum.ItemClass and classID == Enum.ItemClass.Profession) then
                        return false
                    end
                    -- Containers / Bags
                    if classID == 1 or (Enum and Enum.ItemClass and classID == Enum.ItemClass.Container) then
                        return false
                    end
                    -- Recipes (Patterns, Schematics, Recipes)
                    if classID == 9 or (Enum and Enum.ItemClass and classID == Enum.ItemClass.Recipe) then
                        return false
                    end
                    -- Quest items
                    local questClass = (Enum and Enum.ItemClass and (Enum.ItemClass.Questitem or Enum.ItemClass.QuestItem)) or 12
                    if classID == questClass or classID == 12 then
                        return false
                    end
                end
            end
            
            -- Safety 4: Cached Item Info Deep Validation via GetItemInfo
            local itemRef = (info and info.link) or itemID
            if itemRef and GetItemInfo then
                local ok, sellPrice, classID, subclassID, bindType, isCraftingReagent, eqLoc = pcall(function()
                    return select(11, GetItemInfo(itemRef)),
                           select(12, GetItemInfo(itemRef)),
                           select(13, GetItemInfo(itemRef)),
                           select(14, GetItemInfo(itemRef)),
                           select(17, GetItemInfo(itemRef)),
                           select(9, GetItemInfo(itemRef))
                end)
                if ok then
                    -- Profession Tools & Fishing Poles check
                    if IsProfessionTool(bagID, slotID, itemID, classID, subclassID, eqLoc) then
                        return false
                    end
                    -- Native Blizzard isCraftingReagent flag
                    if isCraftingReagent == true then
                        return false
                    end
                    -- Disallow non-sellable classes
                    if classID == 0 or classID == 1 or classID == 5 or classID == 7 or classID == 9 or classID == 12 or classID == 18 then
                        return false
                    end
                    -- Quest item binding
                    if bindType == 4 then
                        return false
                    end
                    -- Zero or negative sell price
                    if sellPrice and sellPrice <= 0 then
                        return false
                    end
                end
            end
            
            return true
        end
        
        return false
    end)
end

-- Immediately register scrap callback if ContainerHelper is available
SetupScrapHook()

-------------------------------------------------------------------------------
-- Safe Batch Selling Engine
-------------------------------------------------------------------------------

function OneStorageScrap:SellJunk()
    if not self:GetOption("autoSell") then return end
    if isSelling then return end
    
    SetupScrapHook()
    local ch = GetContainerHelper()
    if not ch then return end
    
    local bagIDs = ch.BAG_IDS or (ch.GetPlayerBagIDs and ch:GetPlayerBagIDs()) or { 0, 1, 2, 3, 4 }
    local queue = {}
    for _, bagID in ipairs(bagIDs) do
        local numSlots = ch:GetNumSlots(bagID)
        for slotID = 1, numSlots do
            if ch:IsJunk(bagID, slotID) then
                local info = ch:GetItemInfo(bagID, slotID)
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
            ch:UseItem(item.bagID, item.slotID)
        end
        
        if endIndex < #queue then
            if C_Timer and C_Timer.After then
                C_Timer.After(0.2, function() ProcessBatch(endIndex + 1) end)
            else
                ProcessBatch(endIndex + 1)
            end
        else
            -- Selling complete; wait 0.3s for final money update
            local function FinishSelling()
                local profit = math.max(0, (GetMoney() or 0) - startMoney)
                if OneStorageScrap:GetOption("printSummary") and itemsSold > 0 and profit > 0 then
                    print(string.format("|cff00ccff[OneStorageScrap]|r Sold %d junk items for %s.",
                        itemsSold, ch:FormatMoney(profit)))
                end
                isSelling = false
            end
            
            if C_Timer and C_Timer.After then
                C_Timer.After(0.3, FinishSelling)
            else
                FinishSelling()
            end
        end
    end
    
    ProcessBatch(1)
end

-------------------------------------------------------------------------------
-- Options Panel (Standalone & Blizzard Settings)
-------------------------------------------------------------------------------

function OneStorageScrap:SaveOptionsPosition()
    if not self.optionsFrame then return end
    local point, _, relPoint, xOfs, yOfs = self.optionsFrame:GetPoint(1)
    if point then
        _G.OneStorageScrapDB = _G.OneStorageScrapDB or {}
        _G.OneStorageScrapDB.optionsPosition = {
            point = point,
            relativePoint = relPoint or point,
            x = math.floor(xOfs + 0.5),
            y = math.floor(yOfs + 0.5),
        }
    end
end

function OneStorageScrap:RestoreOptionsPosition()
    if not self.optionsFrame then return end
    local pos = _G.OneStorageScrapDB and _G.OneStorageScrapDB.optionsPosition
    self.optionsFrame:ClearAllPoints()
    if pos and pos.point and pos.x and pos.y then
        self.optionsFrame:SetPoint(pos.point, UIParent, pos.relativePoint or pos.point, pos.x, pos.y)
    else
        self.optionsFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
    end
end

function OneStorageScrap:CreateOptionsFrame()
    if self.optionsFrame then return self.optionsFrame end
    
    local opt = CreateFrame("Frame", "OneStorageScrapOptionsFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    opt:SetSize(260, 424)
    opt:SetFrameStrata("DIALOG")
    opt:SetToplevel(true)
    opt:SetClampedToScreen(true)
    opt:Hide()
    self.optionsFrame = opt
    
    -- Metal frame styling
    if FrameHelper then
        FrameHelper:RegisterEscClose("OneStorageScrapOptionsFrame")
        FrameHelper:ApplySimplePanel(opt, "Scrap & Repair Options")
    end
    
    -- Draggable
    opt:SetMovable(true)
    opt:EnableMouse(true)
    opt:RegisterForDrag("LeftButton")
    opt:SetScript("OnDragStart", function(s) s:StartMoving() end)
    opt:SetScript("OnDragStop", function(s)
        s:StopMovingOrSizing()
        OneStorageScrap:SaveOptionsPosition()
    end)
    
    self:RestoreOptionsPosition()
    
    local controls = {}
    local yOffset = -38
    local marginX = 16
    
    local function NotifyBags()
        if OneStorageBag and OneStorageBag.frame and OneStorageBag.frame:IsShown() then
            OneStorageBag:RefreshLayout()
        end
    end
    
    -- SECTION 1: Auto-Sell Settings
    local s1Header = opt:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    s1Header:SetPoint("TOPLEFT", opt, "TOPLEFT", marginX, yOffset)
    s1Header:SetText("|cffffcc00Auto-Sell Settings|r")
    yOffset = yOffset - 24
    
    local autoSellCb = FrameHelper:CreateCheckbox(
        opt,
        "OneStorageScrapOpt_AutoSell",
        "Enable Auto-Selling",
        "Automatically sell junk and scrap items when opening a merchant window.",
        function() return OneStorageScrap:GetOption("autoSell") end,
        function(val)
            OneStorageScrap:SetOption("autoSell", val)
            NotifyBags()
        end
    )
    autoSellCb:SetPoint("TOPLEFT", opt, "TOPLEFT", marginX, yOffset)
    table.insert(controls, autoSellCb)
    yOffset = yOffset - 26
    
    local sellGreysCb = FrameHelper:CreateCheckbox(
        opt,
        "OneStorageScrapOpt_SellGreys",
        "Auto-Sell Poor (Grey) Items",
        "Automatically sell poor quality (grey) items to vendors.",
        function() return OneStorageScrap:GetOption("sellGreys") end,
        function(val)
            OneStorageScrap:SetOption("sellGreys", val)
            NotifyBags()
        end
    )
    sellGreysCb:SetPoint("TOPLEFT", opt, "TOPLEFT", marginX, yOffset)
    table.insert(controls, sellGreysCb)
    yOffset = yOffset - 26
    
    local sellWhitesCb = FrameHelper:CreateCheckbox(
        opt,
        "OneStorageScrapOpt_SellWhites",
        "Auto-Sell Common (White) Items",
        "Automatically sell common quality (white) items with sell value (excluding profession tools like fishing poles, food, crafting reagents, quest items, bags, recipes, and safe-listed items).",
        function() return OneStorageScrap:GetOption("sellWhites") end,
        function(val)
            OneStorageScrap:SetOption("sellWhites", val)
            NotifyBags()
        end
    )
    sellWhitesCb:SetPoint("TOPLEFT", opt, "TOPLEFT", marginX, yOffset)
    table.insert(controls, sellWhitesCb)
    yOffset = yOffset - 32
    
    -- SECTION 2: Auto-Repair Settings
    local s2Header = opt:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    s2Header:SetPoint("TOPLEFT", opt, "TOPLEFT", marginX, yOffset)
    s2Header:SetText("|cffffcc00Auto-Repair Settings|r")
    yOffset = yOffset - 24
    
    local autoRepairCb = FrameHelper:CreateCheckbox(
        opt,
        "OneStorageScrapOpt_AutoRepair",
        "Enable Auto-Repair",
        "Automatically repair damaged equipment when visiting a repair vendor.",
        function() return OneStorageScrap:GetOption("autoRepair") end,
        function(val)
            OneStorageScrap:SetOption("autoRepair", val)
        end
    )
    autoRepairCb:SetPoint("TOPLEFT", opt, "TOPLEFT", marginX, yOffset)
    table.insert(controls, autoRepairCb)
    yOffset = yOffset - 26
    
    local guildRepairCb = FrameHelper:CreateCheckbox(
        opt,
        "OneStorageScrapOpt_GuildRepair",
        "Use Guild Funds First",
        "Attempt to pay for equipment repairs using guild bank funds before personal money.",
        function() return OneStorageScrap:GetOption("useGuildRepair") end,
        function(val)
            OneStorageScrap:SetOption("useGuildRepair", val)
        end
    )
    guildRepairCb:SetPoint("TOPLEFT", opt, "TOPLEFT", marginX, yOffset)
    table.insert(controls, guildRepairCb)
    yOffset = yOffset - 32
    
    -- SECTION 3: Chat Notifications
    local s3Header = opt:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    s3Header:SetPoint("TOPLEFT", opt, "TOPLEFT", marginX, yOffset)
    s3Header:SetText("|cffffcc00Chat & Notifications|r")
    yOffset = yOffset - 24
    
    local summaryCb = FrameHelper:CreateCheckbox(
        opt,
        "OneStorageScrapOpt_PrintSummary",
        "Print Summary to Chat",
        "Display profit and repair cost summaries in the chat window.",
        function() return OneStorageScrap:GetOption("printSummary") end,
        function(val)
            OneStorageScrap:SetOption("printSummary", val)
        end
    )
    summaryCb:SetPoint("TOPLEFT", opt, "TOPLEFT", marginX, yOffset)
    table.insert(controls, summaryCb)
    yOffset = yOffset - 30
    
    -- SECTION 4: Custom Lists & Overrides
    local s4Header = opt:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    s4Header:SetPoint("TOPLEFT", opt, "TOPLEFT", marginX, yOffset)
    s4Header:SetText("|cffffcc00Custom Lists|r")
    yOffset = yOffset - 22
    
    local listInfo = opt:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    listInfo:SetPoint("TOPLEFT", opt, "TOPLEFT", marginX, yOffset)
    
    local function UpdateListInfo()
        local safeCount, junkCount = 0, 0
        local safeList = OneStorageScrap:GetOption("safeList")
        local junkList = OneStorageScrap:GetOption("junkList")
        if safeList then for _ in pairs(safeList) do safeCount = safeCount + 1 end end
        if junkList then for _ in pairs(junkList) do junkCount = junkCount + 1 end end
        listInfo:SetText(string.format("Protected: |cff00ff00%d|r   |   Custom Junk: |cffffcc00%d|r", safeCount, junkCount))
    end
    UpdateListInfo()
    yOffset = yOffset - 24
    
    local clearBtn = FrameHelper:CreateSilverButton(opt, "OneStorageScrapOpt_ClearBtn", "Clear Custom Lists")
    clearBtn:SetSize(160, 22)
    clearBtn:SetPoint("TOPLEFT", opt, "TOPLEFT", marginX, yOffset)
    clearBtn:SetScript("OnClick", function()
        OneStorageScrap:SetOption("safeList", {})
        OneStorageScrap:SetOption("junkList", {})
        UpdateListInfo()
        NotifyBags()
        print("|cff00ccff[OneStorageScrap]|r Custom safe list and junk list have been cleared.")
    end)
    yOffset = yOffset - 32
    
    -- SECTION 5: Window Settings
    local s5Header = opt:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    s5Header:SetPoint("TOPLEFT", opt, "TOPLEFT", marginX, yOffset)
    s5Header:SetText("|cffffcc00Window Settings|r")
    yOffset = yOffset - 24
    
    local resetPosBtn = FrameHelper:CreateSilverButton(opt, "OneStorageScrapOpt_ResetPosBtn", "Reset Position")
    resetPosBtn:SetSize(140, 22)
    resetPosBtn:SetPoint("TOPLEFT", opt, "TOPLEFT", marginX, yOffset)
    resetPosBtn:SetScript("OnClick", function()
        if _G.OneStorageScrapDB then _G.OneStorageScrapDB.optionsPosition = nil end
        OneStorageScrap:RestoreOptionsPosition()
    end)
    
    opt.RefreshOptions = function()
        for _, c in ipairs(controls) do
            if c.Refresh then c:Refresh() end
        end
        UpdateListInfo()
    end
    
    return opt
end

function OneStorageScrap:ShowOptions()
    local opt = self.optionsFrame or self:CreateOptionsFrame()
    if opt.RefreshOptions then opt:RefreshOptions() end
    opt:Show()
end

function OneStorageScrap:ToggleOptions()
    local opt = self.optionsFrame or self:CreateOptionsFrame()
    if opt:IsShown() then
        opt:Hide()
    else
        self:ShowOptions()
    end
end

-------------------------------------------------------------------------------
-- Blizzard Interface Options Category
-------------------------------------------------------------------------------

function OneStorageScrap:RegisterBlizzardCategory()
    if self.blizzardCategoryPanel then return end

    local panel = CreateFrame("Frame", "OneStorageScrapBlizzardOptions", UIParent)
    panel.name = "OneStorage Scrap"

    local icon = panel:CreateTexture(nil, "ARTWORK")
    icon:SetSize(28, 28)
    icon:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -16)
    icon:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("LEFT", icon, "RIGHT", 10, 0)
    title:SetText("OneStorage Scrap")

    local subText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subText:SetPoint("TOPLEFT", icon, "BOTTOMLEFT", 0, -8)
    subText:SetText("Automated vendor junk seller and equipment auto-repair utility.")

    local openBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    openBtn:SetSize(190, 26)
    openBtn:SetText("Open Scrap Options")
    openBtn:SetPoint("TOPLEFT", subText, "BOTTOMLEFT", 0, -16)
    openBtn:SetScript("OnClick", function()
        if InterfaceOptionsFrame and InterfaceOptionsFrame:IsShown() then
            HideUIPanel(InterfaceOptionsFrame)
        end
        if SettingsPanel and SettingsPanel:IsShown() then
            HideUIPanel(SettingsPanel)
        end
        OneStorageScrap:ShowOptions()
    end)

    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, "OneStorage Scrap")
        if category and category.SetIcon then
            pcall(function() category:SetIcon("Interface\\Icons\\INV_Misc_Coin_01") end)
        end
        Settings.RegisterAddOnCategory(category)
        panel.categoryID = category:GetID()
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end

    self.blizzardCategoryPanel = panel
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
        OneStorageScrap:RegisterBlizzardCategory()
        
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
    local cmd, arg = strsplit(" ", (msg or ""):lower():match("^%s*(.-)%s*$"), 2)
    
    if cmd == "opt" or cmd == "options" or cmd == "config" or cmd == "gui" or cmd == "" then
        OneStorageScrap:ToggleOptions()
        
    elseif cmd == "toggle" then
        local current = OneStorageScrap:GetOption("autoSell")
        OneStorageScrap:SetOption("autoSell", not current)
        local status = OneStorageScrap:GetOption("autoSell") and "|cff00ff00ENABLED|r" or "|cffff0000DISABLED|r"
        print("|cff00ccff[OneStorageScrap]|r Auto-selling is now " .. status)
        if OneStorageBag and OneStorageBag.frame and OneStorageBag.frame:IsShown() then
            OneStorageBag:RefreshLayout()
        end
        if OneStorageScrap.optionsFrame and OneStorageScrap.optionsFrame:IsShown() then
            OneStorageScrap.optionsFrame:RefreshOptions()
        end
        
    elseif cmd == "greys" or cmd == "grey" then
        local current = OneStorageScrap:GetOption("sellGreys")
        OneStorageScrap:SetOption("sellGreys", not current)
        local status = OneStorageScrap:GetOption("sellGreys") and "|cff00ff00ENABLED|r" or "|cffff0000DISABLED|r"
        print("|cff00ccff[OneStorageScrap]|r Auto-sell greys is now " .. status)
        if OneStorageBag and OneStorageBag.frame and OneStorageBag.frame:IsShown() then
            OneStorageBag:RefreshLayout()
        end
        if OneStorageScrap.optionsFrame and OneStorageScrap.optionsFrame:IsShown() then
            OneStorageScrap.optionsFrame:RefreshOptions()
        end
        
    elseif cmd == "whites" or cmd == "white" then
        local current = OneStorageScrap:GetOption("sellWhites")
        OneStorageScrap:SetOption("sellWhites", not current)
        local status = OneStorageScrap:GetOption("sellWhites") and "|cff00ff00ENABLED|r" or "|cffff0000DISABLED|r"
        print("|cff00ccff[OneStorageScrap]|r Auto-sell whites is now " .. status)
        if OneStorageBag and OneStorageBag.frame and OneStorageBag.frame:IsShown() then
            OneStorageBag:RefreshLayout()
        end
        if OneStorageScrap.optionsFrame and OneStorageScrap.optionsFrame:IsShown() then
            OneStorageScrap.optionsFrame:RefreshOptions()
        end
        
    elseif cmd == "repair" then
        local current = OneStorageScrap:GetOption("autoRepair")
        OneStorageScrap:SetOption("autoRepair", not current)
        local status = OneStorageScrap:GetOption("autoRepair") and "|cff00ff00ENABLED|r" or "|cffff0000DISABLED|r"
        print("|cff00ccff[OneStorageScrap]|r Auto-repair is now " .. status)
        if OneStorageScrap.optionsFrame and OneStorageScrap.optionsFrame:IsShown() then
            OneStorageScrap.optionsFrame:RefreshOptions()
        end
        
    elseif cmd == "add" and arg then
        local itemID = tonumber(arg) or tonumber(arg:match("item:(%d+)"))
        if itemID then
            local junkList = OneStorageScrap:GetOption("junkList") or {}
            local safeList = OneStorageScrap:GetOption("safeList") or {}
            junkList[itemID] = true
            safeList[itemID] = nil
            OneStorageScrap:SetOption("junkList", junkList)
            OneStorageScrap:SetOption("safeList", safeList)
            local name = GetItemInfo(itemID) or ("Item " .. itemID)
            print("|cff00ccff[OneStorageScrap]|r Added " .. name .. " to custom junk list.")
            if OneStorageBag and OneStorageBag.frame and OneStorageBag.frame:IsShown() then
                OneStorageBag:RefreshLayout()
            end
            if OneStorageScrap.optionsFrame and OneStorageScrap.optionsFrame:IsShown() then
                OneStorageScrap.optionsFrame:RefreshOptions()
            end
        else
            print("|cffff0000[OneStorageScrap]|r Usage: /osscrap add [itemID or ItemLink]")
        end
        
    elseif cmd == "safe" and arg then
        local itemID = tonumber(arg) or tonumber(arg:match("item:(%d+)"))
        if itemID then
            local junkList = OneStorageScrap:GetOption("junkList") or {}
            local safeList = OneStorageScrap:GetOption("safeList") or {}
            safeList[itemID] = true
            junkList[itemID] = nil
            OneStorageScrap:SetOption("junkList", junkList)
            OneStorageScrap:SetOption("safeList", safeList)
            local name = GetItemInfo(itemID) or ("Item " .. itemID)
            print("|cff00ccff[OneStorageScrap]|r Added " .. name .. " to protected safe list.")
            if OneStorageBag and OneStorageBag.frame and OneStorageBag.frame:IsShown() then
                OneStorageBag:RefreshLayout()
            end
            if OneStorageScrap.optionsFrame and OneStorageScrap.optionsFrame:IsShown() then
                OneStorageScrap.optionsFrame:RefreshOptions()
            end
        else
            print("|cffff0000[OneStorageScrap]|r Usage: /osscrap safe [itemID or ItemLink]")
        end
        
    else
        print("|cff00ccff[OneStorageScrap]|r Commands:")
        print("  /osscrap              - Open graphical options panel")
        print("  /osscrap toggle       - Toggle automatic junk selling")
        print("  /osscrap greys        - Toggle selling poor (grey) items")
        print("  /osscrap whites       - Toggle selling common (white) items")
        print("  /osscrap repair       - Toggle automatic equipment repairs")
        print("  /osscrap add <link>   - Always sell this item as junk")
        print("  /osscrap safe <link>  - Protect this item from ever being sold")
    end
end

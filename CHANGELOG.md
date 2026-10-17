# Changelog — OneStorageScrap

All notable changes to **OneStorageScrap** are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [0.0.5] - 2026-10-17
### Added
- **Profession Tools & Fishing Pole Protection**: Added dedicated shields preventing the auto-selling of tools and items used in professions:
  - Weapon subclass 20 (`Enum.ItemWeaponSubclass.Fishingpole`) strictly shields all fishing poles.
  - Added `PROFESSION_TOOL_ITEM_IDS` database guarding classic and expansion profession tools (Mining Picks, Skinning Knives, Blacksmith Hammers, Arclight Spanners, Gyromatic Micro-Adjustors, Gnomish Army Knives, Jeweler Kits, Virtuoso Inking Sets, Runed Enchanting Rods, Philosopher's Stones, Flint and Tinder).
  - Integrated `C_TooltipInfo` deep line scanning for `"fishing pole"`, `"tool:"`, and profession skill requirement lines (`"requires fishing"`, `"requires mining"`, etc.).
- **Food & Consumables Protection**: Common-quality (white) food, drink, potions, elixirs, and bandages (`classID == 0` / `Enum.ItemClass.Consumable`) are strictly protected from being auto-sold when "Auto-Sell Common (White) Items" (`sellWhites`) is enabled.
- **Crafting Reagents & Trade Goods Protection**: Shielded all trade goods (`classID == 7`), class/spell reagents (`classID == 5`), profession items (`classID == 18`), and items flagged with `isCraftingReagent == true` (return 17 of `GetItemInfo`) from auto-selling.
- **Bags & Recipes Protection**: Excluded unequipped bags (`classID == 1`) and learned recipes/patterns/schematics (`classID == 9`) from white auto-selling.
### Fixed
- **Lua 0 Truthiness on `questID`**: In WoW Forever / Interface 16001, `C_Container.GetContainerItemQuestInfo` returns `{ isQuestItem = false, questID = 0, isActive = false }`. In Lua, `0` is truthy, causing `questInfo.questID` to evaluate to true and reject all non-quest Common (White) items. Resolved by explicitly requiring `type(ret1.questID) == "number" and ret1.questID > 0`.
- **Select-Based Item Validation**: Replaced fragile positional return argument unpacking with clean `select` calls for `sellPrice` (11), `classID` (12), and `bindType` (14), ensuring robust quest item and vendor value checks.
- **Immediate Scrap Callback Hooking**: Hooked `SetupScrapHook()` immediately on load and prior to bag queue compilation in `SellJunk()`.

---

## [0.0.4] - 2026-10-17
### Fixed
- **Quest Info Table Truthiness Bug**: Resolved critical logic bug where `C_Container.GetContainerItemQuestInfo` returning a table (`{ isQuestItem = false, ... }`) evaluated to truthy in Lua, causing non-quest Common (White) items to be falsely flagged as quest items and rejected.
- **Table & Boolean Quest Evaluation**: Explicitly inspects `questInfo.isQuestItem` and `questInfo.questID` when a table is returned, ensuring non-quest white items are properly identified as junk when `sellWhites` is enabled.
- **Protected Pcall Item Queries**: Guarded `C_Item.GetItemInfoInstant` and `GetItemInfo` queries with `pcall` and case-insensitive hex color inspection (`cffffffff`).

---

## [0.0.3] - 2026-10-17
### Fixed
- **Common (White) Item Auto-Selling**: Fixed issue where common-quality (white) items failed to be identified as scrap or sold to merchants when "Auto-Sell Common (White) Items" (`sellWhites`) was enabled.
  - Replaced uncached and brittle `GetItemInfo(itemID)` lookups with multi-level fallbacks using `info.quality`, `C_Item.GetItemQualityByID`, and hyperlink hex colors (`cffffffff`).
  - Added native `C_Container.GetContainerItemQuestInfo` and synchronous `C_Item.GetItemInfoInstant` checks to safeguard quest items (`classID 12`) from being sold.
  - Added native `info.hasNoValue` check and explicit Hearthstone protection (`itemID 6948`).
  - Enhanced `ContainerHelper:IsJunk` to pass the parsed container item info table directly to `scrapCheckCallback`, avoiding redundant bag scans and eliminating silent pcall failures.
- **TOC Strict Interface Target**: Aligned manifest strictly to WoW Forever Beta (`Interface: 16001`).

---

## [0.0.2] - 2026-10-12
### Added
- **Graphical Options Panel (`/osscrap opt`)**: Draggable options window styled with OneSuite metal frame styling (`FrameHelper:ApplySimplePanel`).
- **Auto-Selling Quality Toggles**: Individual settings for auto-selling poor (grey) items and common (white) items with sell value.
- **Auto-Repair Configuration**: Checkboxes for toggling auto-repair and prioritizing guild bank funds.
- **Blizzard Interface Options Registration**: Registered under Game Menu -> Options -> AddOns -> "OneStorage Scrap" with coin icon texture.
- **Custom Lists Status & Reset**: Shows protected items and custom junk count with 1-click list clearing.
- **Live Bag Synchronization**: Toggling sell options immediately updates scrap badges across open `OneStorageBag` containers.

---

## [0.0.1] - 2026-10-10
### Added
- **Automated Vendor Junk Selling**: Safely batches and sells poor-quality items on `MERCHANT_SHOW`.
- **Safe & Junk Custom Overrides**: Whitelist and blacklist management via item link or ID (`/osscrap safe`, `/osscrap add`).
- **Automated Equipment Repair (`AutoRepair`)**: Auto-repairs gear on merchant interaction with optional Guild bank funding (`/osrepair`).
- **Profit Summary Reporting**: Formatted chat messages reporting total money earned from junk sales.
- **OneStorageUtils Callback Hook**: Bridges with `ContainerHelper:SetScrapCheckCallback` for suite-wide junk detection.

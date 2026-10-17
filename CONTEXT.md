# AI Context & Living Specification — OneStorageScrap

> **Living Document**: This file serves as the primary context, architectural specification, and state-handoff document for AI-assisted development across sessions. Update this file on every development cycle ("spin").

---

## 🎯 Overview & Scope

- **Addon Name**: OneStorageScrap
- **Current Version**: 0.0.3
- **Suite**: Part of the **OneSuite** family (OneStorage Inventory Suite)
- **GitHub Repository**:
  - Exists: TRUE
  - URL: https://github.com/Nuros-WoW-Forever-Addons/OneStorageScrap
- **Branching Policy**: All new features must be developed on a branch != `main` (e.g. `feature/<name>`)
- **Live Sync Path**: `/Applications/World of Warcraft/_classic_beta_/Interface/AddOns/OneStorageScrap/`
- **Rollback Target**: Last working `main` branch commit
- **Release Package**: `.github/workflows/package.yml` generates `OneStorageScrap-latest.zip` on push to `main`
- **Dependencies**: `OneStorageUtils`, optional `OneStorageBag`
- **Target WoW Runtimes**: WoW Forever Beta (v1.60.1 / Interface 16001)
- **Primary Goal**: Provide safe, throttled auto-selling of vendor junk items with customizable override lists, chat profit reports, and automatic equipment repair with personal or guild funds.

---

## 🏗️ Architecture & Component Map

### File Structure
- `OneStorageScrap.toc`: Manifest, declares dependencies on `OneStorageUtils` and optional `OneStorageBag`, SavedVariables (`OneStorageScrapDB`).
- `Core.lua`: Merchant event hook (`MERCHANT_SHOW`), batched item sale execution (`UseContainerItem`), profit calculations, safe list / junk list management, scrap check hook registration, graphical options panel (`OneStorageScrapOptionsFrame`), Blizzard settings category registration, and slash commands (`/onescrap`, `/osscrap`).
- `AutoRepair.lua`: Auto-repair engine (`RepairAllItems`), guild bank funds check (`CanGuildBankRepair`, `GetGuildBankWithdrawMoney`), and slash command (`/osrepair`).

### Global State & Database Schema (`OneStorageScrapDB`)
```lua
OneStorageScrapDB = {
    autoSell = true,                   -- Master toggle for automatic junk selling
    sellGreys = true,                  -- Auto-sell poor (grey / quality 0) items
    sellWhites = false,                -- Auto-sell common (white / quality 1) items
    autoRepair = true,                 -- Auto repair gear at vendor
    useGuildRepair = false,            -- Use guild bank repair allowance if available
    printSummary = true,               -- Print earnings & repair reports to chat
    safeList = {},                     -- [itemID] = true (never sell)
    junkList = {},                     -- [itemID] = true (always sell)
    optionsPosition = nil,             -- Saved window coordinates { point, relativePoint, x, y }
}
```

---

## 🔄 AI Development Cycle & Handoff Protocol

When picking up development on this addon:

1. **Orientation**: Read `CONTEXT.md` (this file) to verify current state, known issues, and active backlog items.
2. **Implementation**: Execute changes. For code refactoring or boilerplate, delegate to `qwen2.5-coder:32b` via the local `gx10_ollama` MCP server as mandated by user rules.
3. **Verification**: Verify in-game syntax and test using `/osscrap` and `/osrepair`.
4. **Handoff Update**:
   - Move completed tasks from **Upcoming Backlog** to **Recent Completed Work**.
   - If user-facing features or commands changed, update `README.md` and append a new section in `CHANGELOG.md`.
   - Document newly discovered backlog items or edge cases in **Upcoming Backlog**.

---

## ✅ Recent Completed Work (Latest Spins)

### Spin 0.0.3
- **Fixed Common (White) Quality Auto-Selling**: Solved issue where Common (White) items were not identified as junk or auto-sold when `sellWhites` was enabled:
  - Replaced brittle and uncached `GetItemInfo(itemID)` call with multi-tier quality detection (`info.quality`, `C_Item.GetItemQualityByID`, and hyperlink hex string inspection `cffffffff`).
  - Added native `C_Container.GetContainerItemQuestInfo` and synchronous `C_Item.GetItemInfoInstant` checks to safeguard quest items (`classID 12`) from being sold.
  - Added native `info.hasNoValue` check and explicit Hearthstone protection (`itemID 6948`).
  - Enhanced `ContainerHelper:IsJunk` to pass the parsed container item info table directly to `scrapCheckCallback`, avoiding redundant bag scans and eliminating silent pcall failures.
- **TOC Strict Interface Target**: Aligned manifest strictly to WoW Forever Beta (`Interface: 16001`).

### Spin 0.0.2
- Implemented standalone graphical options dialog (`OneStorageScrapOptionsFrame`) styled with `FrameHelper:ApplySimplePanel`.
- Added individual quality toggles for auto-selling poor (grey) and common (white) items.
- Added auto-repair toggles and guild bank repair funding priority.
- Registered addon with Blizzard Settings Panel (`InterfaceOptions_AddCategory` / `Settings.RegisterAddOnCategory`) with coin icon texture.
- Added custom safe/junk lists counter and 1-click clear button with live `OneStorageBag` coin badge sync.
- Standardized database accessors (`GetOption` / `SetOption`) to eliminate boolean ternary trap.

### Spin 0.0.1
- Batched junk selling on merchant open with anti-disconnect throttle timers.
- Safe list (whitelist) and Junk list (blacklist) overrides by item ID and item link.
- Automated equipment repair with guild funds fallback.
- Profit calculation and chat summary reporting.
- Callback integration with `OneStorageUtils.ContainerHelper`.

---

## 📋 Living Roadmap & Upcoming Backlog (Next Spins)

### Priority 1: High Priority (Immediate Next Spin)
- [ ] **Graphical Safe/Junk Manager Sub-Panel**: In-game list window showing currently safe-listed and junk-listed item icons and names with individual 1-click remove buttons.
- [ ] **Item Tooltip Scrap Status**: Add a line to item hover tooltips indicating whether the item is classified as junk or safe-listed.

### Priority 2: Medium Priority (Enhancements)
- [ ] **Low-Level Food/Water Auto-Scrap**: Option to mark outdated vendor food/drink as scrap when reaching higher player levels.
- [ ] **Sell Threshold by Item Value**: Option to prevent selling junk items worth more than a configurable gold threshold.

### Priority 3: Low Priority / Exploration
- [ ] **Buyback Safety Safeguard**: Warning alert in chat if more than 12 items were sold in a single session (Blizzard buyback limit).

---

## 🧪 Testing & Verification Guide

- **Options Panel**: Type `/osscrap` or `/osscrap opt` — verify the options dialog opens, is draggable, and remembers position.
- **Blizzard Options**: Open Game Menu -> Options -> AddOns -> "OneStorage Scrap" — verify coin icon, description, and "Open Scrap Options" button work.
- **Safe List**: Type `/osscrap safe [Hearthstone]` — verify item is registered in safe list and not sold.
- **Auto Sell**: Visit any vendor with grey items in bags — verify items sell automatically and chat displays profit summary.
- **Auto Repair**: Visit a repair-capable vendor with damaged equipment — confirm repair triggers and prints repair cost.

---

## ⚠️ Technical Constraints & Engine Gotchas

- **Transaction Throttling**: Calling `UseContainerItem` in a tight loop for 20+ items can trigger client disconnects or silent transaction drops. Always batch items with micro-delays (`C_Timer.After(0.2, ...)`).
- **Buyback Limit**: The game merchant only preserves the last 12 sold items in the Buyback tab. Ensure batch sales are predictable and logged clearly.

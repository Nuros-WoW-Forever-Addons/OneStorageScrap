# OneStorageScrap

**OneStorageScrap** is an automated vendor junk seller, equipment auto-repair utility, and scrap list manager for World of Warcraft.

Part of the **OneSuite** family of addons.

---

## 🚀 Features

- 🪙 **Automated Junk Selling**: Automatically sells grey/poor quality and optional white/common quality items the instant a merchant window opens with throttled safe transaction batching.
- 🛡️ **Automated Equipment Repair**: Automatically repairs damaged gear when speaking with repair-capable merchants, with optional Guild bank funding (`/osrepair guild`).
- ⚙️ **Graphical Options Panel**: Clean metal-framed settings dialog accessible via `/osscrap`, `/osscrap opt`, or through the Blizzard Options -> AddOns menu.
- 🔒 **Safe List & Custom Junk List**:
  - **Safe List**: Add items that should never be auto-sold, even if grey (`/osscrap safe <link>`).
  - **Junk List**: Add items that should always be auto-sold, even if above poor quality (`/osscrap add <link>`).
- 💬 **Detailed Profit Summaries**: Prints clear formatted chat reports detailing items sold and net gold/silver/copper earned.
- 🔗 **Deep Suite Integration**: Registers its scrap identification callback directly with `OneStorageUtils.ContainerHelper`, displaying coin badges on junk items in `OneStorageBag`.

---

## 🛠️ Installation

Copy the `OneStorageScrap` directory (along with `OneStorageUtils`) into your World of Warcraft `Interface/AddOns/` directory:

```text
World of Warcraft/Interface/AddOns/OneStorageScrap/
├── OneStorageScrap.toc
├── Core.lua
├── AutoRepair.lua
├── CHANGELOG.md
├── CONTEXT.md
└── README.md
```

Then start or reload World of Warcraft (`/reload`).

---

## 💻 Slash Commands

| Command | Description |
|---|---|
| `/onescrap` or `/osscrap` | Open graphical options panel |
| `/osscrap opt` or `/osscrap config` | Open graphical options panel |
| `/osscrap toggle` | Toggle automatic junk selling on or off |
| `/osscrap greys` | Toggle selling poor (grey) items |
| `/osscrap whites` | Toggle selling common (white) items |
| `/osscrap repair` | Toggle automatic equipment repair on or off |
| `/osscrap add <itemLink\|itemID>` | Mark an item to always be sold as junk |
| `/osscrap safe <itemLink\|itemID>` | Mark an item to never be sold (protected safe list) |
| `/osrepair` | Toggle automatic equipment repair (or open options with `/osrepair opt`) |
| `/osrepair guild` | Toggle using Guild funds for auto-repairs |

---

For detailed version history and release notes, see [CHANGELOG.md](CHANGELOG.md).

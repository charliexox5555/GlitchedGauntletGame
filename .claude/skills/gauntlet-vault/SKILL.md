---
name: gauntlet-vault
description: Load FIRST for any work on Draft Duels (GlitchedGauntletGame). Maps each kind of task to the vault notes, LihFolk folders and skills to use, with the read-lean rules.
---

# Work from the vault

The game is built from the Obsidian vault (`vault/`). Use it, cite what you used, and write plans and results back into it. **Query it, don't load it.**

## Read lean
- **Facts** (a number, decision, status, "where is X"): ask the `vault-lookup` agent (project) or `lihfolk:lihfolk-lookup` (general Roblox). Don't open notes for a single fact.
- **Find:** `vault/INDEX.md` (one line per note, size in KB) and `vault/04 Tech/Code Map.md` (who owns what). `Grep -n`, then `Read` with `offset`/`limit`. Never read a note over ~15 KB whole.
- Read a whole note only to edit it, and then only the section you change. Code: grep the symbol, read a line range.
- `vault/00 Home.md`: top = Status; grep the Locked decisions table. Old history: `05 Production/Status History.md` (grep only).
- Notes marked **[SUPERSEDED]** in INDEX are history: skip them unless asked.
- Agent briefs: the question, paths, what "done" looks like, the task-map rows below. Never "read the vault".

## Every task
1. Current state + locked decisions for the topic (vault-lookup, or Home top + grep).
2. Non-trivial Roblox work: LihFolk first (`lihfolk:lihfolk` router or lihfolk-lookup). Project notes and measured numbers beat LihFolk's general advice.
3. Load the skills in the row below. Plan in the vault, blockout/prototype and check it, then build. Results go in the vault (`05 Production/Playtests/`, `Bugs & Ideas.md`).

## Task map
| Task | Project notes | LihFolk folders | Skills |
|---|---|---|---|
| Anything players see/hear (start here) | `02 Art/Style Bible.md` | — | `gauntlet-build-style` (models) / `gauntlet-ui-style` (UI) |
| Lobby | `02 Art/Lobby V5 Plan.md` (by section), `01 Design/Lobby UI and Queue.md` | `33 Level Design`, `06 World Building and Art` | `gauntlet-build-style`, `gauntlet-model-joins`, `lihfolk:lihfolk-worldbuilding` |
| Maps | `01 Design/Maps/00 Maps.md` | `33 Level Design`, `32 Case Studies…/Case Study - Rivals.md` | same as Lobby + `rivals-reference` |
| Models, guns, skins, props | `02 Art/Art Direction.md` (standard + import pipeline), `01 Design/Weapons.md` | `14 3D Modeling`, `54 Untextured Stylised Modelling` | `gauntlet-build-style`, `gauntlet-model-joins`, `blender-director`, `lihfolk:roblox-blender-modeling`, `lihfolk:roblox-asset-import` |
| UI, HUD, menus, Shop | `02 Art/Style Bible.md` §6, `04 Tech/UI Architecture.md`, `02 Art/UI Shop.md` / `UI Locker.md`, `Config/UiStyle.luau` + `Config/Theme.luau` | `05 UI and UX` | `gauntlet-ui-style`, `lihfolk:roblox-ui-builder` |
| RIVALS reference | `03 Research/Rivals Reference/00 Rivals Reference.md` | `Case Study - Rivals.md` | `rivals-reference` (study, don't copy) |
| Videos | `04 Tech/Video Analyzer.md` | — | — |
| Gunplay, animation | `01 Design/Gunplay.md`, `01 Design/Third Person Overhaul.md` (by section) | `08 Animation` | — |
| VFX / sound | `02 Art/Art Direction.md`, `Config/Sounds.luau` | `07 Lighting VFX and Audio`, `47 Game Feel and Juice` | `lihfolk:lihfolk-vfx` / `lihfolk:lihfolk-sfx` |
| Rounds, Mods, bots, queue | `01 Design/Match Flow.md`, `01 Design/Abilities/00 Abilities.md`, `01 Design/Bots.md`, `04 Tech/Architecture.md` | `09 Gameplay Systems`, `24 Worked Builds` | `lihfolk:roblox-system-builder` |
| Remotes, anti-cheat | `04 Tech/Architecture.md` | `22 Anti-Exploit and Security` | `lihfolk:roblox-secure-remotes`, `lihfolk:roblox-anti-exploit-review` |
| Data, purchases | `01 Design/Shop Economy and Art v1.md` | `04 Data and Persistence`, `11 Monetization…` | `lihfolk:roblox-datastore-safety`, `lihfolk:roblox-monetization-compliance` |
| Performance, bugs | — | `12 Performance…`, `SYMPTOMS.md` | `lihfolk:roblox-performance-audit`, `lihfolk:roblox-debugging` |
| Proving a build with numbers | `04 Tech/Measured Check Skills.md` | — | `tools/checks/rbx-*` scripts (not skills) |
| Scoring work (only when asked) | — | — | `lihfolk:quality-score` |

## After a task
Update `vault/00 Home.md` → Status (keep it short; move older entries to Status History), the Asset Tracker row, INDEX for new notes, Code Map for new/renamed Services/Controllers/remotes, and the design note + Locked decisions if a decision changed.

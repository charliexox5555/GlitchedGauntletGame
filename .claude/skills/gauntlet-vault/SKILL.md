---
name: gauntlet-vault
description: Load FIRST for any work on this Roblox game (GlitchedGauntletGame): design, code, maps, lobby, UI, art, models, animation, VFX, sound, bots, playtests, planning, or briefing agents. Maps each task to the project's Obsidian vault notes and the LihFolk Roblox knowledge base (about 1,300 notes, 22 skills) so work is grounded in the vault instead of done from memory.
---

# Work from the vault

The user's standing rule: **this game is built from the Obsidian vault (`vault/`)**. It holds our design, art standard, plans, playtests, and LihFolk, a large expert Roblox knowledge base with skills, build recipes, worked builds and case studies. Use it on every task, cite what you used, and write your plan and results back into it. Don't go off the top of your head.

## Every task
1. Read `vault/00 Home.md` (Status and Locked decisions), then the project note for the task (table below).
2. Look things up in LihFolk before non-trivial Roblox work. Use the `lihfolk-lookup` agent for quick facts, or the `lihfolk` router skill. LihFolk's own entry points: `vault/LihFolk/ROUTER.md`, `INDEX_SLIM.md`, `SYMPTOMS.md` (bug → note), `AI Skills Start Here.md`. The plugin keeps its original copy under `~/.claude/plugins/cache/lihfolk/`.
3. Load the matching specialist skills (table below) and follow them.
4. Plan in phases: write the plan with references in the vault; build a quick blockout or prototype and critique it with screenshots or tests; then do the full build. Results, playtests and a "what to test" checklist go in the vault (`vault/05 Production/Playtests/`, `Bugs & Ideas.md`).
5. Project notes and measured numbers from our game win over LihFolk's general advice. Link the LihFolk notes your decision leans on.
6. When you brief a sub-agent or a session, include this rule and the rows that apply.

## Task map
| Task | Project notes | LihFolk folders / notes | Skills |
|---|---|---|---|
| Lobby, maps, level layout | `01 Design/Lobby.md`, `01 Design/Maps/00 Maps.md`, `02 Art/Art Direction.md`, `02 Art/Lobby Art Plan.md` | `33 Level Design`, `06 World Building and Art`, `36 Narrative and Worldbuilding`, `32 Case Studies…/Case Study - Rivals.md`, `60 High-Craft Game Teardowns` | `lihfolk-worldbuilding`, `roblox-blender-modeling`, `roblox-asset-import` |
| Models, stylized low-poly look | `02 Art/Art Direction.md` (model standard, import pipeline) | `14 3D Modeling`, `54 Untextured Stylised Modelling`, `55 Modelling Nuance and Readability`, `45 Procedural Blender Assets`, `44 Materials and Surfaces` | `roblox-blender-modeling`, `roblox-asset-import`, `lihfolk-assets` |
| UI, HUD, menus | `01 Design/Lobby UI and Queue.md`, `Config/Theme.luau`, Figma file (memory `figma-ui-file`) | `05 UI and UX` (HUD Design, UI Motion Language and Timing, Menu Archetypes, Figma to Roblox UI, Responsive UI, Safe Areas), `21 LihFolk UI Design System` | `roblox-ui-builder`, `lihfolk-figma`, `roblox-dev:roblox-ui` |
| Animation | `01 Design/Gunplay.md`, memory `viewmodel-arms-style` | `08 Animation` (start at `Animation Start Here.md`), `18 Rigs and Skeletons` | — |
| VFX, lighting, juice | `02 Art/Art Direction.md` | `07 Lighting VFX and Audio`, `47 Game Feel and Juice` | `lihfolk-vfx` |
| Sounds | `Config/Sounds.luau`, memory `gun-audio-real-recordings` | `07 Lighting VFX and Audio` | `lihfolk-sfx` |
| Gameplay systems, bots, queue, rounds | `01 Design/Match Flow.md`, `01 Design/Bots.md`, `04 Tech/Architecture.md` | `09 Gameplay Systems`, `43 Genre Systems End to End`, `24 Worked Builds` (Arena Shooter with Server-Checked Hits), `41 Multiplayer Services` | `roblox-system-builder`, `roblox-dev:new-system` |
| Remotes, anti-cheat | `04 Tech/Architecture.md` | `22 Anti-Exploit and Security` | `roblox-secure-remotes`, `roblox-anti-exploit-review`, `roblox-dev:roblox-security` |
| Data, purchases | — | `04 Data and Persistence`, `11 Monetization Publishing and Live Ops` | `roblox-datastore-safety`, `roblox-monetization-compliance` |
| Performance, bugs | — | `12 Performance Testing and Debugging`, `23 Debugging Deep Dives`, `SYMPTOMS.md` | `roblox-performance-audit`, `roblox-debugging` |
| Design, fun, retention | `05 Production/Game Plan.md`, `03 Research/` | `10 Game Design and Genres`, `32 Case Studies of Top Roblox Games`, `58 Player QoL and Game Tweaks` | `lihfolk-tutorial` |
| Scoring built work | — | — | `lihfolk:quality-score` (min 8.5), `lihfolk:council` for big decisions |

## Keep the vault current
After a task: update `vault/00 Home.md` → Status, the Asset Tracker row, and the design note plus the Locked decisions table if a decision changed (see CLAUDE.md → Vault upkeep).

# CLAUDE.md

Roblox competitive shooter: RIVALS-style run-and-gun duels (1v1 → 4v4) where players **draft abilities ("Mods") every round** and every round opens a shared **weapon tier**. Built with Rojo + strict Luau. The solo developer works with Claude.

## Work from the vault, not from memory (mandatory, every chat and every agent)
The Obsidian vault (`vault/`) is how this game is made. It holds the design, the art standard, the plans, the playtests and **LihFolk**: about 1,300 expert Roblox notes plus 22 skills (building, worldbuilding, modelling, UI, VFX, animation, sounds, security, data, performance, worked builds, case studies of top Roblox games). Don't work "off the top of your head".
1. **Before any task:** load the `gauntlet-vault` project skill (`.claude/skills/gauntlet-vault/SKILL.md`). It maps each kind of task to the project notes, LihFolk folders and skills to use.
2. **Before any non-trivial Roblox work:** run the `lihfolk` router skill or the `lihfolk-lookup` agent, and load the matching LihFolk specialist skills (e.g. `lihfolk-worldbuilding` and `roblox-blender-modeling` for maps and lobbies; `roblox-ui-builder` and `lihfolk-figma` for UI; `lihfolk-vfx`, `lihfolk-sfx`; `roblox-secure-remotes`; `roblox-system-builder`). Cite the notes you used in your vault note.
3. **Plans, specs and results go into the vault** before and after the work; point the user at the note.
4. When you delegate to agents or sessions, put this rule in their brief.

## Read lean (the vault is big: don't load it, query it)
Working from the vault means *using* it, not reading all of it. Whole-note reads are what burn usage.
- **Facts** (a number, a decision, a status, "where is X built", "what does Y own"): ask the `vault-lookup` agent (project notes and code, cheap model) or `lihfolk-lookup` (general Roblox). Give it the question and get back facts with paths. Don't open the notes yourself.
- **Find first:** `vault/INDEX.md` (one line per project note, with sizes) and `vault/04 Tech/Code Map.md` (every Service/Controller, its remotes and attributes). `Grep -n` a keyword, then `Read` with `offset`/`limit`. Never read a note over ~15 KB whole (Gunplay, Lobby UI and Queue, the map notes, Asset Tracker, Status History).
- **Read a whole note only when you are about to edit it** (a plan, spec or playtest you will update). Even then, read the section you change.
- **Code:** grep for the symbol, read a line range. Don't open `WeaponService`, `ModService`, `ViewmodelController` etc. whole; the Code Map says which file owns what.
- **Session start:** `vault/00 Home.md` is small now (status, last results, locked decisions); read only its top (about 40 lines) unless you need the Locked decisions table, which you can grep. Old dated history is in `vault/05 Production/Status History.md` (grep only).
- Agents and sessions you start get a tight brief: the question, the file paths, what "done" looks like. Not "read the vault".

## Read first (only the ones the task needs, via the rules above)
- `vault/00 Home.md`: current status, map of all notes, locked decisions.
- The note for the task at hand:
  - **Gunplay:** `vault/01 Design/Gunplay.md`
  - **Guns:** `vault/01 Design/Weapons.md`
  - **Code layout and rules:** `vault/04 Tech/Architecture.md`
  - **Art and model standard:** `vault/02 Art/Art Direction.md`
  - **Maps:** `vault/01 Design/Maps/00 Maps.md`
  - **Rounds and draft:** `vault/01 Design/Match Flow.md`
  - **Schedule:** `vault/05 Production/Game Plan.md`
- Research background: `vault/03 Research/` (only when a decision needs the "why").
- **LihFolk:** before non-trivial Roblox work, check the LihFolk plugin (`lihfolk` router skill, or its `lihfolk-lookup` agent) and use its specialist skills, such as `lihfolk-worldbuilding` for maps. Its notes are also in `vault/LihFolk/` for the user to read (`vault/04 Tech/LihFolk.md`). Project notes and measured numbers win over its general advice.

## Commands
- `rojo serve`: live sync into Studio (the user clicks Connect in the Rojo plugin).
- `rojo build -o build.rbxl`: build check.
- `stylua src` / `stylua --check src`: format.
- `selene src`: lint.
- `rokit install`: install the pinned tools; `wally install` after adding packages.

## Code rules (non-negotiable)
1. `--!strict` in every Luau file. Match the existing style (tabs, StyLua config).
2. **Server-authoritative:** the server decides damage, hits, cooldowns, draft picks and round results. Clients send requests and show results.
3. Every RemoteEvent handler validates types, rejects non-finite numbers, rate-limits, and never trusts client-sent values.
4. Gameplay numbers live in `src/shared/Config/*.luau` as data, never hard-coded in systems.
5. No `_G`, no `wait()`, no deprecated APIs, no free-model scripts. Clean up connections.
6. Services (`src/server/Services`) and Controllers (`src/client/Controllers`) are ModuleScripts with optional `init()` / `start()`.
7. Use the roblox-dev skills when available (new-system, roblox-security, roblox-ui, roblox-datastores, roblox-performance), and run a security review on anything that touches remotes.

## Studio and Rojo
- Rojo owns `ReplicatedStorage.Shared`, `ReplicatedStorage.Assets`, `ServerScriptService.Server` and `StarterPlayerScripts.Client`. Never hand-edit those in Studio; change files instead.
- **Guns** live in the Studio-owned `ReplicatedStorage.Weapons` (Rojo can't live-sync MeshParts), with backups in `art-source/weapons/Studio/<Id>.rbxm`. The whole pipeline (Blender export → Open Cloud upload → WeaponBuilder) is scripted; see Art Direction → Import pipeline. Validate with `tools/studio/ValidateWeapons.luau`. Remind the user to **save the place** after changing guns.
- Other models: import into `ServerStorage.ImportStaging`, finish them to the model standard in Art Direction, then save a backup `.rbxm` (Rojo 7.4.4 can't read Studio's current `.rbxm` format, so don't put them under `assets/`).
- R15 avatars use `AnimationConstraint` joints (not Motor6D); StreamingEnabled is on, so don't cache child lookups on streamed models.
- When the Roblox Studio MCP server is connected, use it to inspect and build in Studio, run playtests and read Output.

## Vault upkeep (do this, it's how the project stays organized)
- After finishing a task, update `vault/00 Home.md` → **Status**, and the relevant row in `vault/06 Assets/Asset Tracker.md`.
- **Keep Home → Status short** (current phase, the last few results, what waits on the user). When you add an entry, move the older ones to `vault/05 Production/Status History.md`. Edit the Asset Tracker row with `Grep -n` + a ranged read, not a whole read.
- New note → add its line to `vault/INDEX.md`. New or renamed Service/Controller/remote → fix its line in `vault/04 Tech/Code Map.md`.
- Plans, specs and results go in the vault, not only in chat. Each playtest or feedback round gets a note in `vault/05 Production/Playtests/`; bugs and parked ideas go in `vault/05 Production/Bugs & Ideas.md`.
- When the user says "end of day", write `vault/05 Production/Daily Log/YYYY-MM-DD.md` from `vault/Templates/Daily Log.md`.
- When a design decision changes, update the design note **and** the "Locked decisions" table in Home. Don't leave contradictions.
- Notes use relative Markdown links with `%20` for spaces (Obsidian and GitHub both read them).

## Git
- Commit small, working steps with clear messages; push at the end of each session.
- Don't commit `.rbxl` place files, `Packages/` or secrets.

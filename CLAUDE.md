# CLAUDE.md

Roblox competitive shooter: RIVALS-style run-and-gun duels (1v1 → 4v4) where players **draft abilities ("Mods") every round** and every round opens a shared **weapon tier**. Built with Rojo + strict Luau. The solo developer works with Claude.

## Read first
- `vault/00 Home.md`: current status, map of all notes, locked decisions.
- Then the note for the task at hand:
  - **Gunplay:** `vault/01 Design/Gunplay.md`
  - **Guns:** `vault/01 Design/Weapons.md`
  - **Code layout and rules:** `vault/04 Tech/Architecture.md`
  - **Art and model standard:** `vault/02 Art/Art Direction.md`
  - **Schedule:** `vault/05 Production/Game Plan.md`
- Research background: `vault/03 Research/` (only when a decision needs the "why").

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
- Models: import into `ServerStorage.ImportStaging`, finish them to the model standard in Art Direction, then **Save to File** as `assets/<Category>/<Name>.rbxm`.
- When the Roblox Studio MCP server is connected, use it to inspect and build in Studio, run playtests and read Output.

## Vault upkeep (do this, it's how the project stays organized)
- After finishing a task, update `vault/00 Home.md` → **Status**, and the relevant row in `vault/06 Assets/Asset Tracker.md`.
- When the user says "end of day", write `vault/05 Production/Daily Log/YYYY-MM-DD.md` from `vault/Templates/Daily Log.md`.
- When a design decision changes, update the design note **and** the "Locked decisions" table in Home. Don't leave contradictions.
- Notes use relative Markdown links with `%20` for spaces (Obsidian and GitHub both read them).

## Git
- Commit small, working steps with clear messages; push at the end of each session.
- Don't commit `.rbxl` place files, `Packages/` or secrets.

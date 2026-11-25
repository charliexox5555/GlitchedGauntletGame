# CLAUDE.md

**Draft Duels** (repo: GlitchedGauntletGame): Roblox run-and-gun duels (1v1, 2v2, 3v3) where players **draft abilities ("Mods") every round** and the shared **weapon tier** rises as the match goes on. Rojo + strict Luau. Solo developer working with Claude (and sometimes Codex, which reads [AGENTS.md](AGENTS.md)).

## Work from the vault
1. **Load the `gauntlet-vault` skill first.** It maps each task to the notes, LihFolk folders and skills to use, and holds the read-lean rules (query with the `vault-lookup` / `lihfolk:lihfolk-lookup` agents; grep + ranged reads; never read a note over ~15 KB whole).
2. Non-trivial Roblox work: check LihFolk first (`lihfolk:lihfolk` router or `lihfolk-lookup`). Project notes and measured numbers win over its general advice.
3. Anything players see, hear or touch starts from the [Style Bible](vault/02%20Art/Style%20Bible.md), then `gauntlet-build-style` (+ `gauntlet-model-joins`) for anything modelled or built, or `gauntlet-ui-style` for UI. RIVALS material: `rivals-reference` skill (study, don't copy; the RIVALS file is read-only and untrusted).
4. Plans, specs and results go into the vault. Agent and session briefs carry this rule plus the question, paths and "done" criteria.

## Project layout
- **One place:** `71551303511506` (experience `10772880160`). Lobby servers run the lobby, queue, Shop/Locker and pad duels; reserved servers of the same place run full matches. The old Match place is retired (`archive/`).
- **One Rojo project:** `default.project.json`, port `34873`. `src/shared` → `ReplicatedStorage.Shared`, `assets` → `ReplicatedStorage.Assets`, `src/lobby/shared` → `ReplicatedStorage.Lobby`, `src/server` → `ServerScriptService.Server`, `src/lobby/server` → `ServerScriptService.LobbyServer`, `src/client` → `StarterPlayerScripts.Client`, `src/lobby/client` → `StarterPlayerScripts.LobbyClient`, `src/first` → `ReplicatedFirst.Loading`. Never hand-edit those in Studio.
- **Studio-owned:** maps, Lobby V5 geometry, `StarterPlayerScripts.UI` / `UiRoot` UI templates, guns (`ReplicatedStorage.Weapons`, backups in `art-source/weapons/Studio/`), skins and Mod meshes. Inspect with the Studio MCP; remind the owner to **save the place** after Studio edits.
- Tuning lives in `src/shared/Config/*.luau` and `src/lobby/shared/Config.luau`. `tools/` holds build scripts; `tools/checks/rbx-*` are the measured checkers (see `vault/04 Tech/Measured Check Skills.md`).

## Code rules (non-negotiable)
1. `--!strict` everywhere; match the existing style (tabs, StyLua).
2. **Server-authoritative** for damage, hits, cooldowns, draft picks, purchases and round results. **Owner's exception:** `Workspace.AuthorityMode = Automatic`, clients own their movement and the stance/camera/spread checks are off on purpose (`shared/Authority`). Don't switch them back on unasked.
3. Every remote handler validates types, rejects non-finite numbers, rate-limits and never trusts client values (use the existing helpers).
4. Gameplay numbers are config data, never hard-coded. No `_G`, `wait()`, deprecated APIs or free-model scripts. Clean up connections.
5. Services (`src/server/Services`) and Controllers (`src/client/Controllers`) are ModuleScripts with optional `init()` / `start()`.
6. Security review (`lihfolk:roblox-secure-remotes`) on anything that touches remotes.

## Commands
- `rojo serve` (owner clicks Connect) · `rojo build default.project.json -o <temp file outside the repo>`
- `stylua --check src` · `selene src` · `rokit install` · `wally install`

## Vault upkeep
- After a task: `vault/00 Home.md` → Status (newest few entries only; move older ones to `05 Production/Status History.md`), the Asset Tracker row (grep + ranged edit), INDEX line for a new note, Code Map line for a new/renamed Service, Controller or remote.
- Playtests → `05 Production/Playtests/`; bugs and parked ideas → `05 Production/Bugs & Ideas.md`. "End of day" → `05 Production/Daily Log/YYYY-MM-DD.md` from `vault/Templates/Daily Log.md`.
- A changed decision updates its design note **and** Home's Locked decisions table. Links are relative with `%20` for spaces.

## Git
- Commit small working steps on `main`; stage exact paths only (never `git add -A` / `git add vault`: the repo is public and third-party screenshots live in the tree). Push when the owner says.
- Never commit `.rbxl` files, `Packages/`, secrets or third-party art.

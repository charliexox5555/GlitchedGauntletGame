# Glitched Gauntlet (Draft Duels)

Since 2026-11-21 this checkout serves **one merged Roblox place** (`71551303511506`, **Draft Duels**, experience `10772880160`; retired Match place `133387545285290` is archived in `archive/match-place.project.json`). Lobby servers run Lobby V5, 1v1/2v2/3v3 cross-server queueing, Shop/Locker, and in-server pad duels; reserved private servers of the same place run full matches (map vote, weapon and Mod drafts, rounds, results).

## Start from the vault

- Open [Home](vault/00%20Home.md) for Status and Locked decisions, then search [INDEX](vault/INDEX.md) and the [Code Map](vault/04%20Tech/Code%20Map.md). Read the relevant sections and verify implementation against source or the Studio place. The [Developer Handoff](vault/04%20Tech/Developer%20Handoff.md) and [Place Merge Plan](vault/04%20Tech/Place%20Merge%20Plan.md) map the project.
- Use the project skills in `.agents/skills/`. Start with `gauntlet-vault`. For player-facing work, read the [Style Bible](vault/02%20Art/Style%20Bible.md) and the relevant build (`gauntlet-build-style`, `gauntlet-model-joins`) or UI (`gauntlet-ui-style`) skill. RIVALS material is read-only reference for original work.
- For Blender modeling, animation and matched-view review, use `blender-director` (or `gpt-3d` in Codex) alongside `gauntlet-build-style` and `gauntlet-model-joins`.
- Put substantial plans, design decisions and verified results in the relevant vault notes. Add new notes to the index with exact KB sizes. Keep `Home → Status` short (move older entries to `Status History.md`), update the Code Map for changes in ownership or contracts, and update the Asset Tracker when assets change. Use relative Markdown links, with spaces encoded as `%20`.

## Code and Studio

- Edit Rojo-mapped Luau on disk. One Rojo project (`default.project.json`, port `34873`) maps `src/shared` → `ReplicatedStorage.Shared`, `assets` → `ReplicatedStorage.Assets`, `src/lobby/shared` → `ReplicatedStorage.Lobby`, `src/server` → `ServerScriptService.Server`, `src/lobby/server` → `ServerScriptService.LobbyServer`, `src/client` → `StarterPlayerScripts.Client`, `src/lobby/client` → `StarterPlayerScripts.LobbyClient`, and `src/first` → `ReplicatedFirst.Loading`.
- Inspect Studio-owned maps, Lobby V5 geometry, `StarterPlayerScripts.UI` / `UiRoot` templates, guns, skins and ability meshes with Studio MCP. Resolve the Studio window by `PlaceId` (`71551303511506`). Before editing, distinguish the repository, the open Studio DataModel, the saved place and the published version.
- Treat `src/shared/Config` and `src/lobby/shared/Config.luau` as the tuning entry points. Keep Luau strict (`--!strict`) and use the existing init/start bootstrap. Keep game outcomes on the server. Validate and rate-limit remote inputs with the existing helpers. Preserve the owner's `Workspace.AuthorityMode = Automatic` setting and its client-owned movement behavior.
- Check changes with `stylua --check src`, `selene src`, and `rojo build default.project.json` (into a temporary file outside the checkout). Use local Studio playtests for behavior and log which mode you verified.

## Git and release

- Inspect git status and preserve the owner's in-progress changes. Stage exact paths only (never `git add -A` or `git add vault`). Keep commits scoped to the requested work. Coordinate pushes, pulls that integrate remote changes, and Roblox publishing with the owner. Git and Roblox release state are independent.
- Use the [Setup Guide](vault/04%20Tech/Setup%20Guide.md) for Rojo ports, Obsidian and release steps. Treat `CLAUDE.md` and `.claude/` as the former workflow unless the owner is working in Claude.

# Glitched Gauntlet

This checkout serves two Roblox places in one experience. The Lobby queues 1v1, 2v2 and 3v3. The Match runs the map vote, weapon and Mod drafts, rounds, and results. Keep two places for now. Prepare Lobby V4 for release after its cleanup.

## Start from the vault

- Open [Home](vault/00%20Home.md) for Status and Locked decisions, then search [INDEX](vault/INDEX.md) and the [Code Map](vault/04%20Tech/Code%20Map.md). Read the relevant sections and verify implementation against source or the correct Studio place. The [Developer Handoff](vault/04%20Tech/Developer%20Handoff.md) maps the entire project.
- Use the project skills in `.agents/skills/`. Start with `gauntlet-vault`. For player-facing work, read the [Style Bible](vault/02%20Art/Style%20Bible.md) and the relevant build or UI skill. RIVALS material is read-only reference for original work.
- For Blender modeling, animation and matched-view review, use the installed `gpt-3d` router alongside `gauntlet-build-style`.
- Put substantial plans, design decisions and verified results in the relevant vault notes. Add new notes to the index. Update Home for milestones, the Code Map for changes in ownership or contracts, and the Asset Tracker when assets change. Use relative Markdown links, with spaces encoded as `%20`.

## Code and Studio

- Edit Rojo-mapped Luau on disk. Both projects map `src/shared` and `assets`. Match uses `src/server`, `src/client` and `src/first`. Lobby uses `src/lobby/{server,client,shared}` and explicitly maps the shared UI helper. The checked-in project JSON files define the exact boundaries.
- Inspect Studio-owned maps, geometry, GUI templates, guns, skins and ability meshes with Studio MCP. Resolve each window by `PlaceId` if the name is missing or ambiguous. Lobby is `71551303511506`, Match is `133387545285290`. Before editing, distinguish the repository, the open Studio DataModel, the saved place and the published version.
- Treat `src/shared/Config` and Lobby's `shared/Config` as the tuning entry points. Keep Luau strict and use the existing init/start bootstrap. Keep game outcomes on the server. Validate and rate-limit remote inputs with the existing helpers. Preserve the owner's `Workspace.AuthorityMode = Automatic` setting and its client-owned movement behavior.
- Check changes with `stylua --check src`, `selene src`, and Rojo builds of both projects for shared changes. Build temporary place files outside the checkout. Use local Studio playtests for behavior and log which mode you verified.

## Git and release

- Inspect git status and preserve the owner's in-progress changes. Keep commits scoped to the requested work. Coordinate pushes, pulls that integrate remote changes, and Roblox publishing with the owner. Git and Roblox release state are independent.
- Use the [Setup Guide](vault/04%20Tech/Setup%20Guide.md) for Rojo ports, Obsidian and release steps. Treat `CLAUDE.md` and `.claude/` as the former workflow unless the owner is working in Claude.

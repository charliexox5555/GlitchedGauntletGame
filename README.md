# GlitchedGauntletGame

Roblox ability-draft shooter, built with [Rojo](https://rojo.space).

- **Design notes, plan and research:** open `vault/` in [Obsidian](https://obsidian.md) and start at `00 Home.md`.
- **Setup from scratch:** `vault/04 Tech/Setup Guide.md`.
- **Rules for Claude:** `CLAUDE.md`.

## Development
1. Install the toolchain: `rokit install`
2. Start syncing: `rojo serve`
3. In Roblox Studio, connect with the Rojo plugin.

## Structure
- `src/shared` → ReplicatedStorage/Shared: config, types, pure utilities
- `src/server` → ServerScriptService/Server: authoritative game systems
- `src/client` → StarterPlayerScripts/Client: input, camera, UI, VFX
- `assets` → ReplicatedStorage/Assets: `.rbxm` models
- `art-source`: Blender/FBX originals (not synced)

## Checks
- Format: `stylua src`
- Lint: `selene src`
- Build: `rojo build -o build.rbxl`

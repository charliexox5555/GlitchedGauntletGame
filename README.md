# GlitchedGauntletGame

Roblox competitive shooter: RIVALS-style duels (1v1 → 3v3) where players draft abilities ("Mods") every round and each round opens a new weapon tier. Built with [Rojo](https://rojo.space) and strict Luau.

- **Status, design and plans:** the Obsidian vault in `vault/`. Start at `vault/00 Home.md`; `vault/INDEX.md` lists every note in one line; `vault/04 Tech/Code Map.md` says which script owns what.
- **Rules for Claude (and anyone):** `CLAUDE.md`.
- **Setup from scratch:** `vault/04 Tech/Setup Guide.md`.

## Where things live
| Folder | What's in it |
|---|---|
| `src/shared` → `ReplicatedStorage.Shared` | `Config/` (every gameplay number, as data), `Net` (all remotes), `MatchState`, `Health`, `Zone`, `Mods/` (the abilities' shared rules), `Simulation/` (movement, poses, abilities under Server Authority), `Util/` (`Ease`, `Fighters`, spread, damage falloff, validation, rate limits) |
| `src/server` → `ServerScriptService.Server` | `Services/` (one module per system: match, draft, weapons, Mods, bots, map, zone, stats, spectate, match end…), `Services/Weapon/` (WeaponService's parts), `Bots/` (the AI brain), `TestRange/` (the practice yard, test mode only) |
| `src/client` → `StarterPlayerScripts.Client` | `Controllers/` (one per area: input, camera, weapons, viewmodel, effects, HUD, draft, spectate, replay, match end…), `Util/` (UI kit, effect modules, viewmodel parts, body copies) |
| `src/lobby` (`lobby.project.json`) | the separate Lobby place: queue, PLAY menu, teleport to a match |
| `assets` → `ReplicatedStorage.Assets` | Rojo-synced models (mostly empty: meshes can't live-sync) |
| `art-source` | sources, not synced: `weapons/` (Blender + `Studio/*.rbxm` backups of the Studio-owned guns), `abilities/`, `maps/<Map>/`, `lobby/`, `ui/` (concepts, icons), `vfx/`, `audio/`, `animations/`; `uploads.json` is the Open Cloud upload ledger |
| `tools` | scripts: `blender/` (model, animate, export), `opencloud/` (upload), `studio/` (builders and checks run in Studio), `maps/`, `vfx/`, `textures/`, `audio/`, `balance/`, `icons/` |
| `vault` | the design vault (Obsidian). `LihFolk/` inside it is a local, git-ignored copy of the LihFolk Roblox notes |

**Studio-owned (not in Rojo, saved with the place):** the guns in `ReplicatedStorage.Weapons`, the Mod models in `ReplicatedStorage.Abilities`, the maps (one Model per map in Workspace while editing; a running server keeps only the loaded one), `ServerStorage.MapKit`. Save the place after changing them.

## Development
1. Install the toolchain: `rokit install`
2. Start syncing: `rojo serve` (match place) or `rojo serve lobby.project.json` (Lobby)
3. In Roblox Studio, click Connect in the Rojo plugin.

## Checks (all must pass before a commit)
- Format: `stylua src`
- Lint: `selene src`
- Build: `rojo build -o build.rbxl`

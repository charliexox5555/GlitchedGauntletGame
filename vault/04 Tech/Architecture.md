# Architecture

## Repo layout
```
GlitchedGauntletGame/
├── CLAUDE.md              ← rules Claude reads automatically
├── default.project.json   ← Rojo: maps folders into Roblox
├── rokit.toml             ← pinned tools (rojo, wally, selene, stylua)
├── wally.toml             ← Luau packages (none yet)
├── selene.toml / stylua.toml
├── src/
│   ├── shared/   → ReplicatedStorage.Shared       (config, types, pure utils)
│   ├── server/   → ServerScriptService.Server     (authoritative game logic)
│   └── client/   → StarterPlayerScripts.Client    (input, camera, UI, VFX)
├── assets/       → ReplicatedStorage.Assets       (.rbxm models: Weapons, Arenas, VFX, UI)
├── art-source/   (not synced) .blend / .fbx originals
├── tools/        (not synced) helper scripts, e.g. Blender
└── vault/        (not synced) this Obsidian vault
```

## Code layout (planned)
```
src/shared/
  Config/      Game.luau, Weapons.luau, Mods.luau, Rounds.luau, Arenas.luau   (data only)
  Net.luau     all RemoteEvents, typed, in one place
  Types.luau
  Util/        Spring, SeededRandom, Signal…
src/server/
  init.server.luau   two-phase bootstrap (init all → start all)
  Services/    MatchService, RoundService, DraftService, WeaponService, HitboxHistory,
               ModService, LobbyService, ArenaService, BotService, DataService,
               AnalyticsService, AntiCheatService
src/client/
  init.client.luau
  Controllers/ InputController, CameraController, MovementController, WeaponController,
               ModController, DraftController, HudController, LobbyController
```
Each Service/Controller is a ModuleScript returning a table with optional `init()` and `start()`.

## Rules
1. `--!strict` at the top of every Luau file.
2. **The server decides everything that matters:** damage, hits, cooldowns, draft picks, round results. The client only *asks* and *shows*.
3. Guns, Mods, rounds and arenas are **data in `Config/`**. Adding a gun = adding a table entry plus its model.
4. Every RemoteEvent: check types, `math.isfinite` on numbers, rate-limit (token bucket), never trust client values.
5. **Server Authority** is on from day 1 (Workspace settings).
6. No `_G`, no `wait()` (use `task.wait`), no free-model scripts, no deprecated APIs (`TeleportAsync` + `ReserveServerAsync`, not the old ones).
7. Clean up connections (Trove/Maid pattern); no per-frame allocations in hot loops.
8. Keep the format and lint checks clean: `stylua src` and `selene src`.

## Rojo notes
- `rojo serve` + the Studio plugin **Connect** = live sync from files into Studio.
- Rojo **owns** `ReplicatedStorage.Shared`, `ReplicatedStorage.Assets`, `ServerScriptService.Server` and `StarterPlayerScripts.Client`. Anything made by hand inside those in Studio gets overwritten. Build maps and other Studio-only things in `Workspace` / `ServerStorage`, then save them as `.rbxm` into `assets/` when they're ready to version.
- `rojo build -o build.rbxl` builds a place file (CI does this to check the project).
- Wally packages: after adding one, run `wally install` and map `Packages` in `default.project.json` (Claude can do this).

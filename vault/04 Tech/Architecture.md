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

## Code layout
Built so far (✅) and still planned (⬜):
```
src/shared/
  Config/      Game, Camera, Movement, Combat, Weapons (wave 1), Input, Sounds, Viewmodel, Dev ✅
               Mods, Rounds, Arenas ⬜
  Net.luau     all RemoteEvents in one place (server creates, clients wait) ✅
  Types.luau   weapon config + remote payload types ✅
  Util/        Spread (seeded), Damage, FireRate, Spring ✅
  WeaponAnimations/  generated Fire/Reload keyframes per gun (tools/make_weapon_anims.py) ✅
src/server/
  init.server.luau   two-phase bootstrap (init all → start all)
  Services/    WeaponService, HitboxHistory, CharacterService, TestRangeService (Studio only) ✅
               MatchService, RoundService, DraftService, ModService, LobbyService, ArenaService,
               BotService, DataService, AnalyticsService, AntiCheatService ⬜
src/client/
  init.client.luau
  Controllers/ InputController, CameraController, MovementController, WeaponController,
               ViewmodelController, EffectsController, HudController, PoseController ✅
               ModController, DraftController, LobbyController ⬜
  Util/        GunAnimator (plays the Blender clips on a gun's Motor6Ds) ✅
tools/         blender/ (export), opencloud/ (upload), studio/ (builder, validator, receiver)
```
Each Service/Controller is a ModuleScript returning a table with optional `init()` and `start()`. Controllers only call each other from `start()` (init order isn't fixed).

### How a shot works
1. **Client** (`WeaponController`): fire on press, local raycasts with seeded spread (`Util/Spread`), instant effects + predicted hit marker, then `Fire` → server with origin, aim, seed, the hits it saw and tracer end points.
2. **Server** (`WeaponService`): rate limit → types/finite numbers → equipped, ammo, reload, fire interval (incl. Flood spin-up, Ray Trace charge) → origin within 7 studs of the server head → per hit: real live combatant, not self, in range, inside the gun's max spread cone, on the target's hitbox now or in the last second (`HitboxHistory`), no wall in between (`ThinWall` tag lets Flood through; Ray Trace ignores walls). Damage comes from `Config/Weapons` (zone × falloff). Pellets are summed per target.
3. **Server → clients:** `HitConfirm` (shooter: damage numbers, sounds), `Damaged` (victim: direction indicator), `Killed` (everyone: kill feed, pixel dissolve), `ShotFx` (others: tracers, muzzle flash, sound).

## Rules
1. `--!strict` at the top of every Luau file.
2. **The server decides everything that matters:** damage, hits, cooldowns, draft picks, round results. The client only *asks* and *shows*.
3. Guns, Mods, rounds and arenas are **data in `Config/`**. Adding a gun = adding a table entry plus its model.
4. Every RemoteEvent: check types, `math.isfinite` on numbers, rate-limit (token bucket), never trust client values.
5. **Server Authority** is planned from day 1 (Workspace → `AuthorityMode = Server`). It can't be set through the MCP; until it's switched on, movement is the normal client-simulated character. When it's on, movement should move into a `Simulation` module bound with `RunService:BindToSimulation` (see Roblox's Server Authority docs).
6. No `_G`, no `wait()` (use `task.wait`), no free-model scripts, no deprecated APIs (`TeleportAsync` + `ReserveServerAsync`, not the old ones).
7. Clean up connections (Trove/Maid pattern); no per-frame allocations in hot loops.
8. Keep the format and lint checks clean: `stylua src` and `selene src`.

## Rojo notes
- `rojo serve` + the Studio plugin **Connect** = live sync from files into Studio.
- Rojo **owns** `ReplicatedStorage.Shared`, `ReplicatedStorage.Assets`, `ServerScriptService.Server` and `StarterPlayerScripts.Client`. Anything made by hand inside those in Studio gets overwritten. Build maps and other Studio-only things in `Workspace` / `ServerStorage`.
- **Rojo can't live-sync MeshParts** (the plugin can't set `MeshId`), and Rojo 7.4.4 can't read `.rbxm` files written by current Studio. So anything with meshes (all guns) lives in Studio-owned folders saved with the place: guns are in `ReplicatedStorage.Weapons`, with `.rbxm` backups in `art-source/weapons/Studio/`. **Save the place** after changing them.
- Rigs: current R15 avatars use `AnimationConstraint` joints, not Motor6D. Code that poses limbs must accept both (both have `Transform`).
- StreamingEnabled is on: a model's parts can arrive after the model. Don't cache child lookups once; dummies use `ModelStreamingMode = Atomic`.
- `rojo build -o build.rbxl` builds a place file (CI does this to check the project).
- Wally packages: after adding one, run `wally install` and map `Packages` in `default.project.json` (Claude can do this).

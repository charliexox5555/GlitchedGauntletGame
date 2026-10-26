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
  Config/      Game, Camera, Movement, Combat, Weapons (Vandal), Input, Sounds, SoundAtlas, Audio, Viewmodel, VfxTextures, Dev, TestRange ✅
               Mods, Rounds, Arenas ⬜
  Net.luau     all RemoteEvents in one place (server creates, clients wait) ✅
  TestMode.luau  the test mode switch (Workspace attribute "TestMode") ✅
  Types.luau   weapon config + remote payload types ✅
  Util/        Spread (seeded, centre-biased or even), Accuracy (Gunplay v2 spread maths), Damage (step falloff), FireRate, Spring ✅
  WeaponAnimations/  generated Blender clips per gun: Fire, Reload, optional ReloadEmpty / Draw / Inspect (tools/make_weapon_anims.py) ✅
src/server/
  init.server.luau   two-phase bootstrap (init all → start all)
  Services/    WeaponService, HitboxHistory, CharacterService, TestRangeService (test mode only) ✅
               MatchService, RoundService, DraftService, ModService, LobbyService, ArenaService,
               BotService, DataService, AnalyticsService, AntiCheatService ⬜
  TestRange/   RangeBuilder (geometry), Dummies (kinds, movement, shooter) ✅
src/client/
  init.client.luau
  Controllers/ InputController, CameraController, MovementController, WeaponController,
               ViewmodelController, EffectsController, HudController, PoseController,
               AudioController, RangeController (test mode) ✅
               ModController, DraftController, LobbyController ⬜
  Util/        HitFeedback (hit markers, damage numbers), GunAnimator (plays the Blender clips on a gun's Motor6Ds), ViewmodelRig (anchored, hand-posed viewmodel guns), ViewmodelArms (block arms with the player's shirt), ViewmodelMotion (bob/sway/breathing as one root offset) ✅
tools/         blender/ (export), opencloud/ (upload), studio/ (builder, validator, receiver)
```
Each Service/Controller is a ModuleScript returning a table with optional `init()` and `start()`. Controllers only call each other from `start()` (init order isn't fixed).

### How a shot works
1. **Client** (`WeaponController`): fire on press, local raycasts with seeded spread (`Util/Spread`), instant effects + predicted hit marker, then `Fire` → server with origin, aim, shot counter, its cone and centre-bias flag (Gunplay v2, `Util/Accuracy`), the hits it saw and tracer end points.
2. **Server** (`WeaponService`): rate limit → types/finite numbers → shot counter (must move forward by 1–3) → equipped, ammo, reload, fire interval (incl. spin-up and burst cadence) → origin within 5 studs of the server head with a clear line from the head → recompute every pellet ray from the **server-issued seed** (`seedBase` in WeaponState + shot counter) and the claimed cone clamped into the band the server's own state allows (`spreadBand`: the gun's spray heat from accepted shot times ± `FIRE_JITTER`, and the shooter's MoveState / speed / Aim input / landing sampled every Heartbeat over their rewind window; see [Gunplay](../01%20Design/Gunplay.md) §2 "How v2 is built") → per hit: a real body part (R15/R6 allowlist, never hats or held guns), live, not self, on its pellet's ray (±1.5°), on the target's hitbox **rewound to the shooter's ping** (`HitboxHistory`, max 0.6 s; arms get +3 studs because the holding pose is client-side), and no wall between shooter → hit point → rewound body part (`ThinWall` penetration, e.g. the Vandal, goes through `ThinWall`-tagged parts). Melee: reach + facing check, backstab from behind. Damage comes from `Config/Weapons` (zone × step falloff, distance measured by the server), pellets summed per target. In Studio, the last rejection reason is written to the player attribute `FireReject`.
3. **Server → clients:** `HitConfirm` (shooter: damage numbers, sounds), `Damaged` (victim: direction indicator), `Killed` (everyone; no listener in the fresh base, kept for the kill feed), `ShotFx` (others: tracers, muzzle flash, shells, impacts found by a client raycast to each end point, sound).

## Test range
For testers in a published place. Kept apart from the match code: everything lives in `TestRangeService`, `src/server/TestRange/`, `Config/TestRange` and `RangeController`, and none of it runs while test mode is off.

- **Switch:** the Workspace attribute `TestMode` (bool, saved with the place). `TestMode.resolve()` (server, in `TestRangeService.init`) reads it; when it's missing, Studio playtests fall back to `Config/Dev TEST_RANGE` and live servers stay off. The server writes the decided value back so clients read the same answer. **On:** tick it, save, publish. **Off:** untick it (or delete it), save, publish.
- **When on:** the server builds `workspace.TestRange` (origin `Config/TestRange ORIGIN`, away from the map centre), disables every other SpawnLocation, spawns the dummies in `workspace.Dummies` (the folder WeaponService's wall checks skip) It is a plain concrete practice yard (lanes, cover with a plywood ThinWall, movement course).
- **Dummies:** R15 from a HumanoidDescription, `CharacterService.prepare` (100 HP, hitbox history) so shots go through the same validation and rewind as players. Static kinds are anchored; movers walk with `Humanoid:Move` (AutoRotate off, stock run clip, crouch clips from `Config/Animations`). The shooter only sends `ShotFx` with itself as the shooter (aimed ≥ 1.6 studs past your head); it never applies damage. Tag `RangeDummy` + `Dummy*` attributes drive the client health bars. Decorative parts have `CanQuery = false` so they're never hit claims.
- **No remotes** (fresh base, 2026-10-25): the tester menu, stats panel and weapon racks were removed with the old UI (`Tester` / `TesterStats` remotes gone; git history has them). The range switches (dummies move, shooter fires back, dummies heal) are fixed defaults in `Config/TestRange BEHAVIOURS`.

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
- With Server Authority on, the Animator writes joints inside the simulation step (after `PreSimulation`), so scripted `Transform` writes only stick on joints no AnimationTrack drives (Roblox bug, devforum 4846108). And the default `Animate` is a ModuleScript run on both sides with the client predicting the Animator: **tracks a client plays on its own character get stopped by the server.**
- So character poses are real animations stepped in the simulation: `shared/Simulation/Poses` (bound with `BindToSimulation`, priority 4000 like Animate) plays the clips in `Config/Animations` on the server for every player and on each client for its own character, from simulation-safe inputs only (`MoveState`, the `AimPitch` input action fed by `PoseController`, the equipped weapon, ground speed). Weights change via `AdjustWeight` fades. New pose clips: edit `tools/studio/MakePoseAnimations.luau`, run it in Studio with `tools/studio/receive_server.py` running, upload with `tools/opencloud/upload_asset.py --type Animation`, put the id in `Config/Animations`.
- Under Server Authority the Workspace snaps part positions to a coarse grid (up to ~0.006 studs, varying with position). Anything that must sit exactly relative to the camera (the viewmodel) lives in a `WorldModel` under the Camera, which keeps exact positions and still renders.
- StreamingEnabled is on: a model's parts can arrive after the model. Don't cache child lookups once; dummies use `ModelStreamingMode = Atomic`.
- `rojo build -o build.rbxl` builds a place file (CI does this to check the project).
- Wally packages: after adding one, run `wally install` and map `Packages` in `default.project.json` (Claude can do this).

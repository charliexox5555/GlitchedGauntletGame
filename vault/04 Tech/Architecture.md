# Architecture

For the current two-place ownership map and system walkthrough, see the [Developer Handoff](Developer%20Handoff.md). This note retains earlier implementation detail, including the original Server Authority design.

## Repo layout
```
GlitchedGauntletGame/
├── AGENTS.md              ← current project instructions
├── default.project.json   ← Rojo: maps folders into Roblox
├── lobby.project.json     ← Lobby Rojo project
├── rokit.toml             ← pinned tools (rojo, wally, selene, stylua)
├── wally.toml             ← Luau packages (none yet)
├── selene.toml / stylua.toml
├── src/
│   ├── shared/   → ReplicatedStorage.Shared       (config, types, pure utils)
│   ├── server/   → ServerScriptService.Server     (authoritative game logic)
│   ├── client/   → StarterPlayerScripts.Client    (input, camera, UI, VFX)
│   ├── first/    → ReplicatedFirst.Loading        (Match loading GUI)
│   └── lobby/    → LobbyServer, LobbyClient and ReplicatedStorage.Lobby
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
               Mods, Match ✅
  Net.luau     all RemoteEvents in one place (server creates, clients wait) ✅
  TestMode.luau  resolves the Studio-only Workspace TestMode checkbox ✅
  Types.luau   weapon config + remote payload types ✅
  Util/        Spread (seeded, centre-biased or even), Accuracy (Gunplay v2 spread maths), Damage (step falloff), FireRate, Spring ✅
  WeaponAnimations/  generated Blender clips per gun: Fire, Reload, optional ReloadEmpty / Draw / Inspect (tools/make_weapon_anims.py) ✅
src/server/
  init.server.luau   two-phase bootstrap (init all → start all)
  Services/    WeaponService, HitboxHistory, CharacterService, TestRangeService (test mode only) ✅
               MatchService, DraftService, MapService, BotService (AI bots; brain in src/server/Bots) ✅
               LobbyService, BotService, DataService, AnalyticsService, AntiCheatService ⬜
  TestRange/   RangeBuilder (geometry), Dummies (kinds, movement, shooter) ✅
src/client/
  init.client.luau
  Controllers/ InputController, CameraController, MovementController, WeaponController,
               ViewmodelController, EffectsController, HudController, PoseController,
               AudioController, RangeController (test mode) ✅
               DraftController, MatchHudController ✅
               LobbyController ⬜
  Util/        HitFeedback (hit markers, damage numbers), GunAnimator (plays the Blender clips on a gun's Motor6Ds), ViewmodelRig (anchored, hand-posed viewmodel guns), ViewmodelArms (block arms with the player's shirt), ViewmodelMotion (bob/sway/breathing as one root offset) ✅
tools/         blender/ (export), opencloud/ (upload), studio/ (builder, validator, receiver)
```
Each Service/Controller is a ModuleScript returning a table with optional `init()` and `start()`. Controllers only call each other from `start()` (init order isn't fixed).

### How a shot works
1. **Client** (`WeaponController`): fire on press, local raycasts with seeded spread (`Util/Spread`), instant effects + predicted hit marker, then `Fire` → server with origin, aim, shot counter, its cone and centre-bias flag (Gunplay v2, `Util/Accuracy`), the hits it saw and tracer end points.
2. **Server** (`WeaponService`): rate limit → types/finite numbers → shot counter (must move forward by 1–3) → equipped, ammo, reload, fire interval (incl. spin-up and burst cadence) → origin within 5 studs of the server head with a clear line from the head → recompute every pellet ray from the **server-issued seed** (`seedBase` in WeaponState + shot counter) and the claimed cone clamped into the band the server's own state allows (`spreadBand`: the gun's spray heat from accepted shot times ± `FIRE_JITTER`, and the shooter's MoveState / speed / Aim input / landing sampled every Heartbeat over their rewind window; see [Gunplay](../01%20Design/Gunplay.md) §2 "How v2 is built") → per hit: a real body part (R15/R6 allowlist, never hats or held guns), live, not self, on its pellet's ray (±1.5°), on the target's hitbox **rewound to the shooter's ping** (`HitboxHistory`, max 0.6 s; arms get +3 studs because the holding pose is client-side), and no wall between shooter → hit point → rewound body part (`ThinWall` penetration, e.g. the Vandal, goes through `ThinWall`-tagged parts). Melee: reach + facing check, backstab from behind. Damage comes from `Config/Weapons` (zone × step falloff, distance measured by the server), pellets summed per target. In Studio, the last rejection reason is written to the player attribute `FireReject`.
3. **Server → clients:** `HitConfirm` (shooter: damage numbers, sounds), `Damaged` (victim: direction indicator), `Killed` (everyone; no listener in the fresh base, kept for the kill feed), `ShotFx` (others: tracers, muzzle flash, shells, impacts found by a client raycast to each end point, sound).

## Match system
Design: [Match Flow](../01%20Design/Match%20Flow.md). With `TestMode` off the server runs a match. With it on, the server loads the practice yard.

- **`MatchService`:** the one loop, in a pcall: Waiting → Ready → (Draft → Countdown → Live → RoundEnd) → MatchEnd. `Players.CharacterAutoLoads` is off: it spawns everyone with `LoadCharacterAsync` at each round, through `player.RespawnLocation`. One life per round; there's no respawn until the next one.
- **State for clients:** `shared/MatchState`, attributes on ReplicatedStorage named `Match*` (Phase, EndsAt, Round, Score1/2, RoundWinner, MatchWinner, WeaponPhase). String attributes are limited to 50 characters in this Studio build, so they stay short. Timers are one server-time end point.
- **`DraftService`:** the server rolls and stores each player's offer. `DraftPick(action, id)` (rate limited) is checked against that stored list: `Gun`, `Ability`, `Lock`, `Sync` (resend the offer). `DraftOffer` goes to one client. Kits and picks stay on the server until the draft closes.
- **`MapService`:** clones the map model from `ServerStorage.Maps` into `workspace.ActiveMap` (Persistent streaming). **A map still in Workspace moves to ServerStorage.Maps for that run only**, so it stays editable in Studio. Tags it needs: `ArenaSpawn_A` / `ArenaSpawn_B` on SpawnLocations, `ArenaBarrier` on the spawn barriers.
- **Combat lock:** player attribute `CombatLocked` (server-set). `WeaponService.holstered` and `ModService.active` refuse shots and Mods while it's on, and the clients skip the input. Dash and Updraft run in the simulation so they can still fire behind the barrier, which is why charges refill when the round goes live.
- **`BotService` + `src/server/Bots/`** (2026-11-04, replaces the test opponent): AI bots that fill empty team slots (a Lobby party with `bots = true`, read by `Bots/MatchPlan` from TeleportData; in Studio the Workspace attribute `BotMatch`, or one bot for a lone player). Each bot has a server-only owner stand-in so the shared movement, Mod and pose simulations drive it through `Simulation/Pawns`; guns and server Mods use their shared rules and WeaponService's damage path. Design, hooks and tuning: [Bots](../01%20Design/Bots.md).
- **Guns have no friendly fire now:** `WeaponService` rejects hits on allies (`Teams.isAlly`).
- **Between rounds:** `ModService.clearRound` removes walls, fires and timers at round end, so nothing burns into the next round. Inside a round they still outlive the caster. Map spawns have no shield (`Duration = 0`): the barrier does that job.
- **Shot counter:** a new loadout sends `resync` once with `WeaponState`, and the client takes the server's counter as it is. Shots refused at the end of a life moved only the client's counter, which could end up past `MAX_SHOT_SKIP` and lock the gun for the session.
- **Nobody home:** before the barrier drops, `MatchService` spawns anyone with no live character, then gives them up to 3 s. If a side still has nobody alive, the round scores nothing. If a whole side leaves, whoever stayed wins the match. Teams rebalance so they differ by at most one (a third player in a 1v1 still makes 2v1: match servers will need a size cap with the Lobby).
- **UI:** `DraftController` (the draft screen) and `MatchHudController` (score, clock, banners). Scale inside a 16:9 panel. Rough, PC first.

## Test range
For testers in a published place. Kept apart from the match code: everything lives in `TestRangeService`, `src/server/TestRange/`, `Config/TestRange` and `RangeController`, and none of it runs while test mode is off.

- **Switch.** In Studio, select Workspace and toggle the `TestMode` Boolean Attribute before Play. If the setting is absent, Studio falls back to `Config/Dev TEST_RANGE`. Live servers use match mode. The server publishes the resolved value. [Studio settings](State%20Values%20and%20Asset%20Data.md#editing-active-assets)
- **When on:** the server builds `workspace.TestRange` (origin `Config/TestRange ORIGIN`, away from the map centre), disables every other SpawnLocation, spawns the dummies in `workspace.Dummies` (the folder WeaponService's wall checks skip) It is a plain concrete practice yard (lanes, cover with a plywood ThinWall, movement course).
- **Dummies:** R15 from a HumanoidDescription, `CharacterService.prepare` (100 HP, hitbox history) so shots go through the same validation and rewind as players. Static kinds are anchored; movers walk with `Humanoid:Move` (AutoRotate off, stock run clip, crouch clips from `Config/Animations`). The shooter only sends `ShotFx` with itself as the shooter (aimed ≥ 1.6 studs past your head); it never applies damage. Tag `RangeDummy` + `Dummy*` attributes drive the client health bars. Decorative parts have `CanQuery = false` so they're never hit claims.
- **Weapon picker** (2026-10-25): **P** (gamepad D-pad up, touch GUNS) opens `PickerController`'s menu of every installed gun (a `Config/Weapons` entry whose model is in `ReplicatedStorage.Weapons`). Picking sends `PickWeapon(id)`; `WeaponService` accepts it only in Studio or with test mode on (server value), rate-limits it (`Combat.RATE.PickWeapon`), checks the id (string ≤ 32, a real gun with its model installed) and a live character, then puts the gun in its own slot and equips it. Weapon input is ignored while the menu is open and for 0.25 s after it closes. The old tester menu, stats panel and weapon racks are gone (`Tester` / `TesterStats` remotes removed; git history has them). The range switches (dummies move, shooter fires back, dummies heal) are fixed defaults in `Config/TestRange BEHAVIOURS`.
- **Tester tools** (2026-10-29): with test mode on, every player is a tester. They get the **Mod test panel** (F8 / gamepad View / touch TEST: any Mod and level in any slot, unlimited charges on/off, refill, quick-cast, spawn and clear their own dummies, hurt me) and start with **unlimited charges** on. Switches in `Config/TestRange`: `TESTER_DEV_PANEL`, `TESTER_UNLIMITED_CHARGES`. With test mode off, a live server gives them to nobody, owner included, since a real match is running; Studio always has them. Dummies from the panel: 6 per player, 18 per server, one spawn every 2 s, not solid (no walling in doorways or players).

## Rules
1. `--!strict` at the top of every Luau file.
2. **The server decides everything that matters:** damage, hits, cooldowns, draft picks, round results. The client only *asks* and *shows*.
3. Guns, Mods, rounds and arenas are **data in `Config/`**. Adding a gun = adding a table entry plus its model.
4. Every RemoteEvent: check types, `math.isfinite` on numbers, rate-limit (token bucket), never trust client values.
5. **Authority mode (2026-11-11): Server Authority is OFF.** The owner set `Workspace.AuthorityMode = Automatic` because Server Authority lagged for players. `shared/Authority.server()` reads the mode (the server prints it at start) and everything below keys off it, so switching it back on restores the old behaviour:
   - **Off (now):** the server gets no inputs and no camera from players (every `InputAction` reads false, `Player:GetCameraState` errors). The server runs `Simulation/Movement`, `Abilities` and `Poses` for **bots only**; each client simulates and poses its own character (its animations replicate like any classic Roblox game). The client reports its move state with its aim on the `Aim` remote and the server publishes it on the character for everyone else; the client keeps its own state in `Simulation/Movement` (`ownState`), never reading that echo. **Checks that are off** (`Config/Combat`): the spread band (the cone is the client's claim, up to `CLIENT_SPREAD_MAX`), the Mod aim / camera check, and the origin tolerance is wider (`CLIENT_ORIGIN_TOLERANCE`). **Still server-decided:** damage, fire rate, ammo, reloads, range, rewind, walls, teams, rate limits.
   - **Known gaps while off:** the predicted Mods (Dash, Updraft) keep their charges on the client, so the server can't enforce them; other players don't see Dash / Updraft state attributes; speed and teleport hacks aren't checked. A new anti-cheat for this mode is parked in [Bugs & Ideas](../05%20Production/Bugs%20%26%20Ideas.md).
   - **Since 2026-11-15:** the ModSim report path ([Ability Rework](../05%20Production/Ability%20Rework%202026-11-15.md)) closes most of that gap for Dash and Updraft. The predicted Mods send their events to the server, which keeps its own charge count, checks the reports, deals Crash Down's damage, lets Ghost block shots and relays the events to the other players. Movement itself is still client-owned.
   - **Original plan (kept for when it's switched back on):** Server Authority was planned from day 1 (Workspace → `AuthorityMode = Server`). It can't be set through the MCP; until it's switched on, movement is the normal client-simulated character. When it's on, movement should move into a `Simulation` module bound with `RunService:BindToSimulation` (see Roblox's Server Authority docs).
6. No `_G`, no `wait()` (use `task.wait`), no free-model scripts, no deprecated APIs (`TeleportAsync` + `ReserveServerAsync`, not the old ones).
7. Clean up connections (Trove/Maid pattern); no per-frame allocations in hot loops.
8. Keep the format and lint checks clean: `stylua src` and `selene src`.

## Rojo notes
- Run `rojo serve default.project.json` for Match (34872) and `rojo serve lobby.project.json` for Lobby (34873). Connect each Studio plugin to the matching port.
- Rojo **owns** `ReplicatedStorage.Shared`, `ReplicatedStorage.Assets`, `ServerScriptService.Server` and `StarterPlayerScripts.Client`. Anything made by hand inside those in Studio gets overwritten. Build maps and other Studio-only things in `Workspace` / `ServerStorage`.
- **Rojo can't live-sync MeshParts** (the plugin can't set `MeshId`), and Rojo 7.4.4 can't read `.rbxm` files written by current Studio. So anything with meshes (all guns) lives in Studio-owned folders saved with the place: guns are in `ReplicatedStorage.Weapons`, with `.rbxm` backups in `art-source/weapons/Studio/`. **Save the place** after changing them.
- Rigs: current R15 avatars use `AnimationConstraint` joints, not Motor6D. Code that poses limbs must accept both (both have `Transform`).
- With Server Authority on, the Animator writes joints inside the simulation step (after `PreSimulation`), so scripted `Transform` writes only stick on joints no AnimationTrack drives (Roblox bug, devforum 4846108). And the default `Animate` is a ModuleScript run on both sides with the client predicting the Animator: **tracks a client plays on its own character get stopped by the server.**
- So character poses are real animations stepped in the simulation: `shared/Simulation/Poses` (bound with `BindToSimulation`, priority 4000 like Animate) plays the clips in `Config/Animations` on the server for every player and on each client for its own character, from simulation-safe inputs only (`MoveState`, the `AimPitch` input action fed by `PoseController`, the equipped weapon, ground speed). Weights change via `AdjustWeight` fades; a layer that fades out is stopped, because **an Animator plays at most 16 tracks at once** (a 17th reports IsPlaying but never plays). New pose clips: edit `tools/studio/MakePoseAnimations.luau`, run it in Studio with `tools/studio/receive_server.py` running, upload with `tools/opencloud/upload_asset.py --type Animation`, put the id in `Config/Animations`. **Legs (2026-11-04):** `tools/studio/MakeLocomotionAnimations.luau` (same pipeline) → `Config/Animations` `LOCOMOTION` (direction-blended in `Poses.stepLegs`) and `ANIMATE` (the ids `CharacterService.useOurAnimations` writes into Roblox's `Animate` StringValues: our idle / jump / fall, an empty walk / run).
- Under Server Authority the Workspace snaps part positions to a coarse grid (up to ~0.006 studs, varying with position). Anything that must sit exactly relative to the camera (the viewmodel) lives in a `WorldModel` under the Camera, which keeps exact positions and still renders.
- StreamingEnabled is on: a model's parts can arrive after the model. Don't cache child lookups once; dummies use `ModelStreamingMode = Atomic`.
- CI builds both Rojo projects. The resulting files contain their mapped trees. See [Setup Guide](Setup%20Guide.md) for commands and Studio publishing.
- Wally packages: after adding one, run `wally install` and map `Packages` in `default.project.json` (Claude can do this).

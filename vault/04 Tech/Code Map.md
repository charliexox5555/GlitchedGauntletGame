# Code Map

One line per module: what it owns, its remotes and attributes. **Use it to pick the files a code task needs, then `Grep` for the symbol and `Read` a line range. Don't open whole files.** Rules and the shot/match walkthroughs: [Architecture](Architecture.md). Generated 2026-11-07 from the file headers and `Net.luau`; if a module changed a lot, trust the file and fix this line.

Layout: `src/shared` (ReplicatedStorage.Shared), `src/server` (match place server), `src/client` (match place client), `src/lobby/{server,client,shared}` (Lobby place). Sizes in lines are rough.

## Remotes (all in `src/shared/Net.luau`, folder `ReplicatedStorage.Remotes`)
| Remote | Direction | Owner |
|---|---|---|
| `Equip`, `Fire`, `Reload`, `PickWeapon` (Studio/test mode only) | client → server | `WeaponService` |
| `Aim` (unreliable) | client → server | `WeaponService` |
| `WeaponState`, `HitConfirm`, `Damaged`, `Killed` | server → client | `WeaponService` |
| `ShotFx` (unreliable) | server → other clients | `WeaponService` → `EffectsController`, `GripController` |
| `ModHold`, `ModUse`, `ModSteer`, `ModRecall` | client → server | `ModService` |
| `ModFx` | server → all clients | `ModService` → `ModFxController`, `ModFeelController` |
| `ModReveal` | server → caster's team | `ModService` (Recon) |
| `DevMod` | client → server | `DevModService` (Studio / test mode / owner) |
| `DraftPick` / `DraftOffer` | client → server / server → one client | `DraftService` |
| `Spectate` | client → server | `SpectateService` |
| `Replay` | server → all | `MatchService` → `ReplayController` |
| `MatchSummary` / `MatchChoice` | server → all / client → server | `MatchEndService` |

Lobby remotes (`src/lobby/shared/LobbyNet.luau`, folder `LobbyRemotes`): `QueueRequest` (client → server: `join`, mode / `leave`), `QueueEvent` (server → client: found / failed / studio / info).

Every handler uses `Util/Validate` (types, finite numbers) and `Util/RateLimit` (token buckets from `Config/Combat RATE`, `Config/Mods RATE`).

## Shared state (attributes)
- **Match state** (`shared/MatchState`): ReplicatedStorage attributes `Match*`: `Phase` (Waiting / Draft / Countdown / Live / SuddenDeath / RoundEnd / Replay / MatchEnd), `EndsAt`, `Round`, `Score1`, `Score2`, `RoundWinner`, `MatchWinner`, `WeaponPhase`, `RematchOpen`, `RematchVotes`, `RematchNeeded`. Written only by `MatchService` / `MatchEndService`. Player attribute `CombatLocked` (server-set).
- **Zone** (`shared/Zone`): `ZoneService` writes the circle as ReplicatedStorage attributes, `MatchZoneId` last (0 = none).
- **Health** (`shared/Health`): Humanoid attributes `HP`, `MaxHP`, `Downed`; written only by `HealthService`.
- **Status effects** (`shared/Mods/Status`, `Config/StatusEffects`): expiry attributes (`HinderedUntil`, …, `StatusStunned`) written only by `StatusService`.
- **Mod loadout on the player**: `Mod<n>Id`, `Mod<n>Level`, `ModUnlimitedCharges`, `ModResetSerial`, `ModHeld`, `ModUseAt`, `ModUseKind`, `ModReject`.
- **Weapon on the player/character**: `WeaponId`, `Aiming`, `AimPitch`, `ReloadAt/For`, `SwingAt/Heavy/Step`, `HitAt`, `LastAttacker`, `FireReject` (Studio, last rejection reason).
- **Test mode**: Workspace attribute `TestMode` (`shared/TestMode`).

## src/shared (pure data and logic used by both sides)
| Module | Owns |
|---|---|
| `Config/*.luau` | All tuning data. Weapons (1073 l), Viewmodel (1145), Mods (625), Match, Combat, Bots, Movement, Input, Camera, Animations, Audio / GunSounds / ModSounds / SoundAtlas / Sounds / UiSounds, Ambience, MapLife, Theme / UiStyle, StatusEffects, TestRange, Avatar, Juice, VfxTextures, Dev, Game |
| `Net.luau` | the remote list above |
| `Types.luau` | weapon config and remote payload types |
| `MatchState.luau`, `Zone.luau`, `Health.luau`, `TestMode.luau` | the attribute readers/writers above |
| `MatchBody.luau` | the standard match avatar (see [Match Avatar](../01%20Design/Match%20Avatar.md)) |
| `Simulation/Movement.luau` | sprint, crouch, slide, slide-jump; bound with `BindToSimulation` (Server Authority) |
| `Simulation/Abilities.luau` | predicted half of Mods (Dash, Updraft…) inside the movement step; no remotes |
| `Simulation/Poses.luau` | third-person pose and leg tracks, stepped in the simulation (651 l) |
| `Simulation/Pawns.luau` | gives bots a stand-in owner so the simulations drive them |
| `Mods/init.luau` | Mod registry: `def(id)`, `stats(id, level)`, `module(id)` |
| `Mods/<Ability>.luau` | one per ability: Dash, Updraft, Molly, Firewall, Frost, Recon, HealOrb, Stim, Recall |
| `Mods/Blocks/*` | reusable parts: Projectile (deterministic arc), Placeable, Target, Zone, Reveal, Rewind, SelfBuff, Dash |
| `Mods/Charges`, `Mods/Status`, `Mods/Teams`, `Mods/Types` | per-round charges, status reads, ally checks (`Teams.isAlly`), types |
| `Util/` | `Spread`, `Accuracy` (Gunplay v2 spread), `Damage` (falloff), `FireRate`, `Spring`, `Validate`, `RateLimit` |
| `WeaponAnimations/<Gun>.luau` | generated clip ids per gun |
| `UiKit.luau`, `CoreUi.luau` | shared UI builders |

## src/server
| Module | Owns · remotes · attributes |
|---|---|
| `init.server.luau` | two-phase bootstrap: `init()` all, then `start()` all |
| `Services/MatchService` (878 l) | the match loop: Waiting → Ready → Draft/select → Countdown → Live → SuddenDeath → RoundEnd → MatchEnd; spawns with `LoadCharacterAsync`; scores; writes `Match*`; sends `Replay`; seats and teams |
| `Services/MatchEndService` | stats broadcast (`MatchSummary`), Rematch / Play Again / Leave votes (`MatchChoice`), teleports out |
| `Services/DraftService` | rolls and stores each offer, checks `DraftPick`, sends `DraftOffer`; attr `DraftLocked` |
| `Services/WeaponService` (1769 l) | loadouts, ammo, reload, fire timing, the shot validation ladder, rewound hit checks, melee, damage (`onHit`) |
| `Services/HitboxHistory` | last second of each root position, for lag compensation |
| `Services/HealthService` | the game's own HP / downed state |
| `Services/StatusService` | status effects (Hindered, Stunned…), the only writer of expiry attributes |
| `Services/StatsService` | per-fighter eliminations, deaths, assists, damage |
| `Services/ModService` (1050 l) | each player's 3 Mod slots, charges, cooldowns, checks for `ModHold/Use/Steer/Recall`, sends `ModFx`; clears at round end (`clearRound`) |
| `Services/ModEntities` | server things that outlive a request: timers, Molly fire, Frost bursts, Stim beacons; attrs `OwnerId`, `TeamId`, `Hp`, `ExpiresAt` |
| `Services/ModWalls` | Firewall walls: growth, HP, burning |
| `Services/ModRecall` | Recall anchor, wind-up, teleport; attrs `Recall*` |
| `Services/DevModService` | backend of the F8 Mod test panel (`DevMod`) |
| `Services/MapService` | clones the map from `ServerStorage.Maps` into `workspace.ActiveMap`; tags `ArenaSpawn_A/B`, `ArenaBarrier` |
| `Services/ZoneService` | sudden-death circle, damage outside it |
| `Services/SpectateService` | streams the target's surroundings to a spectator (`Spectate`) |
| `Services/CharacterService` | prepares every combatant: match body, full HP, no regen, hitbox history; our `Animate` ids |
| `Services/MovementService` | server half of the movement and pose simulation |
| `Services/InputContextService` | per-player Input Action contexts from `Config/Input` |
| `Services/TestRangeService`, `TestRange/*` | practice yard and dummies, only with `TestMode` on |
| `Services/BotService` (838 l), `Bots/*` | AI bots: `Brain` (decisions), `Perception`, `Nav`, `Aim`, `BotGun`, `BotMods`, `BotDraft`, `MatchPlan` (reads TeleportData / `BotMatch`); see [Bots](../01%20Design/Bots.md); attrs `IsBot`, `BotId`, `BotCount` |
| `WeaponBuild/WeaponBuilder` | builds gun models in Studio (tool pipeline, not runtime) |

## src/client (Controllers; each has optional `init()` / `start()`; call each other only from `start()`)
| Controller | Owns |
|---|---|
| `WeaponController` | fire input, spread, recoil, predicted hit marker, sends `Fire`/`Reload`/`Equip`/`Aim` |
| `ViewmodelController` (2366 l) | first-person gun and arms rig; uses `Util/Viewmodel*`, `GunAnimator`, `MagDrop` |
| `GripController` | left hand IK on every visible character's gun |
| `EffectsController` (1656 l) | shot effects (flash, smoke, tracers, impacts, shells) from `ShotFx` |
| `HudController` | crosshair, hit markers, ammo, health/shield, low-HP vignette, damage direction |
| `MatchHudController`, `PhoneHudController` | top bar, score, clock, banners; phone layout |
| `DraftController` (1536 l) | the select/draft screen: gun cards + one column per Mod key |
| `ModController` (1250 l) | Mod input, held state machine, previews, sends `ModHold/Use/Steer/Recall` |
| `ModHudController` | 3 slots with cooldown sweep and charges |
| `ModFxController`, `ModFeelController` | world effects and sounds of Mods (`Util/*Fx`, `Util/UpgradeFx/<Ability>`) |
| `MovementController`, `PoseController` | start the client's predicted movement / pose simulation |
| `CameraController` | FOV, ADS zoom, recoil, shake, slide tilt, smoothing |
| `InputController` | reads the Input Action System context |
| `AudioController` | atlas sound pool, plays every game sound; `FootstepController`, `AmbienceController`, `Util/ModAudio` |
| `CharacterFxController`, `DeathFxController`, `MapLifeController` | slide dust, the fake-death body copy, ambient map life |
| `SpectateController` | death camera and first-person spectating; `ReplayController`: final-kill replay (`Replay`) |
| `MatchEndController` | victory scene and post-match screen (Rematch / Play Again / Leave) |
| `ZoneController` | sudden-death wall, screen tint, warning tick |
| `DevModController`, `PickerController`, `RangeController` | test-mode tools: Mod panel (F8), gun picker (P), dummy health bars |
| `Util/` | `HitFeedback`, `KillFeed`, `Ui`, `UiSound`, `TeamColor` (cyan allies, orange-red enemies), `Device`, `VfxPool`, `Frozen`, VFX kits (`FireKit`, `IceKit`, `GlitchVfx`, `WallFx`, `WindFx`) |

## src/lobby (Lobby place)
| Module | Owns |
|---|---|
| `server/Services/QueueService` | solo queue per mode, bot fill after `Config.botFillAfter`; attrs `QueueStatus`, `QueueMode`, `QueueSince`, `QueueStartsAt` |
| `server/Matchmaking/Launcher`, `Matchmaker` | forms a match and teleports to a reserved Match server; the Lobby → Match TeleportData contract |
| `client/Controllers/QueueMenu` | full-screen PLAY menu (1v1 / 2v2 / 3v3, FIND MATCH) |
| `client/Controllers/LobbyHud`, `Panels`, `WorldPrompts` | top row HUD, placeholder menus (Shop, Battle Pass, Locker, Settings, Range), ProximityPrompts on tagged world parts |
| `client/Util/*`, `shared/Config`, `shared/LobbyNet` | menu kit, layout, router, icons; config; the lobby remotes |

## Tools (not synced; `tools/`)
`blender/` (model scripts), `opencloud/` (uploads), `studio/` (Studio-side builders and validators, e.g. `ValidateWeapons.luau`, `MakePoseAnimations.luau`, `receive_server.py`, `maps/<Map>/`), `maps/`, `vfx/`, `audio/`, `textures/`, `icons/`, `balance/`.

## How to use this map
1. Name the area (e.g. "the Frost burst hurts allies") → find the rows → `Grep -n "symbol" src/...` → `Read` with `offset`/`limit`.
2. Gameplay numbers are in `src/shared/Config/*.luau`, never in the systems: grep the config first.
3. Anything touching a remote: read the owning service's handler and `Util/Validate` use, then the [Architecture](Architecture.md) shot walkthrough.

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

Lobby remotes (`src/lobby/shared/LobbyNet.luau`, folder `LobbyRemotes`): `QueueRequest` (client → server: `join`, mode / `leave`), `QueueEvent` (server → client: found / failed / studio / info), `PartyRequest` (client → server: `invite` / `accept` / `decline`, userId; `leave`), `PartyEvent` (server → client: invite / info), `LockerRequest` (client → server: `equip`, gunId, line).

Every handler uses `Util/Validate` (types, finite numbers) and `Util/RateLimit` (token buckets from `Config/Combat RATE`, `Config/Mods RATE`).

## Shared state (attributes)
- **Skin preview** (`shared/Config/SkinPreview`, `shared/SkinPreview`, `SkinPreviewService`, `SkinPreviewController`): each player picks a skin line for their own guns (F7 / `\` cycle, `;` opens the list). The pick is a **server-set Player attribute** `PreviewSkinLine` (starts Stock); the `PreviewSkinLine` remote takes an allowlisted line name (type and length checked, `Util/RateLimit` 1/s burst 3, `canUse`). Runs in the match place 133387545285290, in Studio and, with `Config/SkinPreview.LIVE`, in live servers (`USER_IDS` can limit it). Camera guns follow their viewer (or the spectated player; bots and replays stay stock; owner in the camera model's `SkinOwnerId`), world guns follow the character holding them (server). Immutable `Weapons` stock templates and `WeaponSkins/<Line>/<Id>` variants; missing variants fall back to stock. No ownership, purchases or saving. `client/Util/ChamberFlow` (started by `SkinPreviewController`): on camera guns only, drifts the two flow `Texture` layers tagged `MoltframeFlowLayer` on structural-skin chamber parts and pulses the chamber `SurfaceAppearance.Color` (`Config/SkinPreview.CHAMBER_FLOW`); world models keep the static map. Installer for geometry skins: `tools/studio/InstallMoltframeSkin.luau` (Decal -> Image id resolve).
- **Locker skins** (`shared/Locker`): one equipped line per gun, saved by the Lobby's `LockerService` (DataStore `LockerV1`); the match's `SkinPreviewService` loads it into `Skin_<gunId>` attributes on join, and `SkinPreview.line(player, gunId)` uses them whenever the F7 preview is on Stock.
- `tools/studio/InstallFlatSkin.luau`: Studio-edit installer for flat-material geometry skins (one MeshPart per material from `tools/blender/export_roblox_flat.py`, tiled pattern Textures, kept stock parts in the line finish) into `WeaponSkins/<Line>/<Gun>`; `InstallMoltframeSkin.luau` now takes `line` too.
- Whole skin lines: `tools/blender/export_skin_items_flat.py` (per item: flat FBX + `manifest_flat.json` with replaced stock prefixes, extra rig joints, the line Vandal's palette) → `tools/studio/make_flat_install_jobs.py` stages `InstallFlatSkin` + jobs in a temporary Rojo folder `src/shared/_SkinInstall` (remove with `--clean`). Knife-slot skins install as `WeaponSkins/<Line>/Knife` with attribute `SkinItem` (Fan / Blade / Dagger).
- Skin casings: `client/Util/ShellFx` throws `WeaponSkins._Casing` (CasingBody + CasingBand, Studio-owned) coloured by `shared/Config/SkinCasings` when the gun model's `SkinLine` has an entry; else the stock brass shell.
- Hiding viewmodel parts: `client/Util/LocalHide.set(part, value)` sets `LocalTransparencyModifier` on the part **and its Textures/Decals** (skin patterns); used by `ViewmodelController` (scope hide, mags, carried rounds, props, ADS fade), `ViewmodelHeldMods`, `WeaponController` (own third-person gun). `MagDrop` fades a dropped mag's Textures with it.
- Skin export checks: `tools/blender/export_roblox_flat.py` keeps `*Sight*` objects as `SK_<Bone>_Sight_NN` parts (the ADS occluder fade skips names with "Sight") and lifts flush coplanar faces (`resolve_coplanar`, 0.004 studs) and splits self-crossing faces (`fix_crossed_faces`). `tools/blender/check_flat_export.py` re-imports exported FBXs and renders them one-sided on magenta (what Studio draws). Shell-kit outlines use `model_vandal_shell_base.convex_hull_xz` (never Blender's `convex_hull_2d`). Pitfalls and checks: `vault/02 Art/Skins/Skin Build Pitfalls.md`.
- Knife-slot skin motion: `client/Util/FanMotion` (Giltfold Fan ribs: Rib_NN Motor6D Transforms, stepped by `ViewmodelController` after the gun's GunAnimator) with numbers in `shared/Config/MeleeSkins` (`FAN`, `VIEWMODEL_SCALE` by `SkinItem`); Studio scrub `Workspace.DevFanScrub`.
- **Match state** (`shared/MatchState`): ReplicatedStorage attributes `Match*`: `Phase` (Waiting / Draft / Countdown / Live / SuddenDeath / RoundEnd / Replay / MatchEnd), `EndsAt`, `Round`, `Score1`, `Score2`, `RoundWinner`, `MatchWinner`, `WeaponPhase`, `RoundHistory` ("winner:WeaponPhase" per round), `RematchOpen`, `RematchVotes`, `RematchNeeded`. Written only by `MatchService` / `MatchEndService`. Player attribute `CombatLocked` (server-set).
- **Zone** (`shared/Zone`): `ZoneService` writes the circle as ReplicatedStorage attributes, `MatchZoneId` last (0 = none).
- **Health** (`shared/Health`): Humanoid attributes `HP`, `MaxHP`, `Downed`; written only by `HealthService`.
- **Status effects** (`shared/Mods/Status`, `Config/StatusEffects`): expiry attributes (`HinderedUntil`, …, `StatusStunned`) written only by `StatusService`.
- **Mod loadout on the player**: `Mod<n>Id`, `Mod<n>Level`, `ModUnlimitedCharges`, `ModResetSerial`, `ModHeld`, `ModUseAt`, `ModUseKind`, `ModReject`.
- **Weapon on the player/character**: `WeaponId`, `Aiming`, `AimPitch`, `ReloadAt/For`, `SwingAt/Heavy/Step`, `HitAt`, `LastAttacker`, `FireReject` (Studio, last rejection reason).
- **Test mode**: Workspace attribute `TestMode` (`shared/TestMode`).

## src/shared (pure data and logic used by both sides)
| Module | Owns |
|---|---|
| `Config/*.luau` | All tuning data. Weapons (1073 l), Viewmodel (1145), Mods (625), Match, Combat, Bots, Movement, Input, Camera, Animations, Audio / GunSounds / GunSoundAssets and SharedSoundAssets (generated standalone asset IDs) / ModSounds / Sounds / UiSounds, Ambience, MapLife, Theme / UiStyle, StatusEffects, TestRange, Avatar, Juice, VfxTextures, Dev, Game |
| `Net.luau` | the remote list above |
| `Types.luau` | weapon config and remote payload types |
| `MatchState.luau`, `Zone.luau`, `Health.luau`, `TestMode.luau` | the attribute readers/writers above |
| `MatchBody.luau` | the standard match avatar: `description`, `dress` (welds the block body over the R15 rig and draws shirt / pants on it, `Config/Avatar BLOCKS`), `preload`, `filterAccessory` (the accessory rule); see [Third Person Overhaul](../01%20Design/Third%20Person%20Overhaul.md) |
| `Authority.luau` | `server()`: is Roblox Server Authority on (`Workspace.AuthorityMode`)? Off since 2026-11-11: the simulations skip real players on the server and the input-based checks in `WeaponService` / `ModService` are off |
| `Simulation/Movement.luau` | sprint, crouch, slide, slide-jump; bound with `BindToSimulation`. Server: every player under Server Authority, bots only without it; client: its own character (`ownState`) |
| `Simulation/Abilities.luau` | predicted half of Mods (Dash, Updraft…) inside the movement step; no remotes |
| `Simulation/Poses.luau` | third-person pose and leg tracks (holds by pitch, run set, sprint upper body by weapon kind in step with the legs, crouch, slide, one-shots); a client poses its own character, the server its bots (about 700 l). Clips: `Config/Animations`, keyed in `tools/anim/tp_clips.py` |
| `Simulation/Pawns.luau` | gives bots a stand-in owner so the simulations drive them |
| `Mods/init.luau` | Mod registry: `def(id)`, `stats(id, level)`, `module(id)` |
| `Mods/<Ability>.luau` | one per ability: Dash, Updraft, Molly, Firewall, Frost, Recon, HealOrb, Stim, Recall |
| `Mods/Blocks/*` | reusable parts: Projectile (deterministic arc), Placeable, Target, Zone, Reveal, Rewind, SelfBuff, Dash |
| `Mods/Charges`, `Mods/Status`, `Mods/Teams`, `Mods/Types` | per-round charges, status reads, ally checks (`Teams.isAlly`), types |
| `Util/` | `Spread`, `Accuracy` (Gunplay v2 spread), `Damage` (falloff), `FireRate`, `Spring`, `Validate`, `RateLimit`, `Ease` (smooth/out/lerp/approach: use it, don't redefine easing), `Fighters` (players' bodies + bots: `bodies()`, `all()`, `bodyOfPart()`) |
| `WeaponAnimations/<Gun>.luau` | generated clip ids per gun |
| `UiKit.luau`, `CoreUi.luau` | shared UI builders |

## src/server
| Module | Owns · remotes · attributes |
|---|---|
| `init.server.luau` | two-phase bootstrap: `init()` all, then `start()` all |
| `Services/MatchService` (~880 l) | the match loop: Waiting → Draft (the select, with the 3-2-1 inside) → Countdown → Live → SuddenDeath → RoundEnd, then Replay → MatchEnd; spawns with `LoadCharacterAsync`; scores; writes `Match*`; sends `Replay`; seats and teams |
| `Services/MatchEndService` | stats broadcast (`MatchSummary`), Rematch / Play Again / Leave votes (`MatchChoice`), teleports out |
| `Services/DraftService` | rolls and stores each offer, checks `DraftPick`, sends `DraftOffer`; attr `DraftLocked` |
| `Services/WeaponService` (905 l) | loadouts, ammo, reload, fire timing, the remote handlers and the shot-accept ladder in `onFire`; re-exports the helpers below |
| `Services/Weapon/` (no init/start, required by WeaponService) | `Hits` (per-hit validation with rewind, damage tally), `Motion` (motion samples, `spreadBand`, the Dash gate), `Damage` (guards, modifiers, `hurt`, `applyDamage`, `damage`, `damageBy`, `onHit`), `Targets` (live humanoids, hitbox owners, wall exclusions), `WorldModel` (the third-person gun) |
| `Services/HitboxHistory` | last second of each root position, for lag compensation |
| `Services/HealthService` | the game's own HP / downed state |
| `Services/StatusService` | status effects (Hindered, Stunned…), the only writer of expiry attributes |
| `Services/StatsService` | per-fighter eliminations, deaths, assists, damage; answers `Scoreboard` (live lines + kits); sends the victim `CombatReport` (damage vs their killer this life) |
| `Services/ModService` (1050 l) | each player's 3 Mod slots, charges, cooldowns, checks for `ModHold/Use/Steer/Recall`, sends `ModFx`; clears at round end (`clearRound`) |
| `Services/ModEntities` | server things that outlive a request: timers, Molly fire, Frost bursts, Stim beacons; attrs `OwnerId`, `TeamId`, `Hp`, `ExpiresAt` |
| `Services/ModWalls` | Firewall walls: growth, HP, burning |
| `Services/ModRecall` | Recall anchor, wind-up, teleport; attrs `Recall*` |
| `Services/DevModService` | backend of the F8 Mod test panel (`DevMod`) |
| `Services/MapService` | at start moves every map model left in Workspace to `ServerStorage.Maps`; clones the picked one into `workspace.ActiveMap`; tags `ArenaSpawn_A/B`, `ArenaBarrier`; `spawnCentre(team)` |
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
| `ViewmodelController` (1817 l) | first-person gun and arms rig (also shows a spectated or replayed fighter's view via `setSubject`); uses `Util/ViewmodelTracks` (keyframed tracks), `Util/ViewmodelHeldMods` (held Mods, gestures, free hand), `Util/ViewmodelArms/Rig/Motion`, `GunAnimator`, `MagDrop` |
| `BodySkinController` | bends every third-person body's skinned arms, legs and torso each frame from its R15 parts (meshes tagged `GGSkinLimb` in `Workspace.GGBodyLimbs`, made by `shared/MatchBody`), and copies each part's LocalTransparencyModifier to its mesh. No remotes |
| `GripController` | the support hand's IK on every visible character's gun (target on the right hand, so it holds still through the kick); Studio attr `DevThirdPerson` rigs your own character too. The fire kick itself is the gun-in-hand spring in `EffectsController` (`Config/Juice WORLD_KICK`) |
| `EffectsController` (585 l) | your own shot from the viewmodel, other players' `ShotFx`, spectated / replayed shots (`setSpectated`, `playShot`), hit flash (forwards to `Util/HitFx`: whole-body flash incl. limb meshes, slash, headshot flash pop; numbers `Config/HitFx`); forwards to `Util/MuzzleFx`, `ShellFx`, `TracerFx`, `ImpactFx` (surfaces, bullet holes, knife marks), `KnifeSwipeFx`, all built on `Util/ShotFxKit` |
| `HudController` | crosshair, hit markers, ammo, health/shield, low-HP vignette, damage direction |
| `TopBarController` | the match top bar (2026-11-14): fills the Studio-built `StarterGui.TopBar` (team blocks, headshots greyed when dead, score, clock, info line) from `MatchState`; template `ReplicatedStorage.UiTemplates.TopBar.Player`; backup `tools/studio/BuildTopBar.luau` |
| `Util/BottomHud` (2026-11-14) | the bottom combat HUD: fills the Studio-built `StarterGui.BottomHud` (health + shield, ammo, Mod cells, weapon hotbar, key hints); fed by `HudController`, `ModHudController`, `WeaponController.updateHudWeapon`; desktop only; backup `tools/studio/BuildBottomHud.luau` |
| `MatchHudController`, `PhoneHudController` | banners (get ready, countdown, round won / lost, match end); its old top bar is hidden (kept for its sounds until removed); phone layout |
| `Util/DraftScreen` (2026-11-14) | the desktop draft screen: fills and animates the Studio-built `StarterGui.DraftScreen` (guns, Q/E/T columns of new cards / upgrade half-cards / MAXED, LOCK IN, hint, enemy kit); fed by `DraftController`; backup `tools/studio/BuildDraftScreen.luau` |
| `DraftController` (1774 l) | the select/draft logic (offer, keys, `DraftPick` calls, hint); desktop draws through `Util/DraftScreen`, phones keep its own code-built cards |
| `ModController` (1250 l) | Mod input, held state machine, previews, sends `ModHold/Use/Steer/Recall` |
| `ModHudController` | 3 slots with cooldown sweep and charges |
| `ModFxController`, `ModFeelController` | world effects and sounds of Mods (`Util/*Fx`, `Util/UpgradeFx/<Ability>`) |
| `MovementController`, `PoseController` | start the client's predicted movement / pose simulation |
| `CameraController` | FOV, ADS zoom, recoil, shake, slide tilt, smoothing |
| `InputController` | reads the Input Action System context |
| `AudioController` | whole-asset voice pools (`gun:` weapon/feedback, `sfx:` shared cues), preloads recordings and plays 2D/3D audio; `FootstepController`, `AmbienceController`, `Util/ModAudio` |
| `CharacterFxController`, `DeathFxController`, `MapLifeController` | slide dust, the fake-death body copy, ambient map life |
| `SpectateController` | death camera and first-person spectating; desktop shows the killed-by card and spectate bar through `Util/DeathScreen` (Studio-built `StarterGui.DeathScreen`); `ReplayController`: final-kill replay (`Replay`) |
| `MatchEndController` → `Util/MatchEndScreen` (2026-11-14) | desktop match end screen: fills the Studio-built `StarterGui.MatchEndScreen` (templates `UiTemplates.MatchEnd`; result, round history from `MatchRoundHistory`, scoreboard, your build, PLAY AGAIN / REMATCH / LEAVE, name plates over the winners); backup `tools/studio/BuildMatchEndScreen.luau` |
| `Util/StatusTray` (2026-11-14) | the status tray: your effects as icons with draining 24-segment rings + the Mod hint, in the Studio-built `StarterGui.StatusTray`; fed by ModHudController (hint), ModFeelController (Revealed), UpgradeFx/Recall (Crash Recovery); reads the `*Until` attributes and `BarrierHits` |
| `ScoreboardController` (2026-11-14) | hold Tab: live stats + builds in the Studio-built `StarterGui.Scoreboard`; asks `Scoreboard` (StatsService answers that client, rate-limited) |
| `KillFeedController` (2026-11-14) | the kill feed and the kill pop (glitch shard, 5-kill ring) in the Studio-built `StarterGui.KillFeed` (row template `UiTemplates.KillFeed.Row`), from `Killed`; desktop only; `Util/KillFeed` keeps the kill sounds; backup `tools/studio/BuildFeedScreens.luau` |
| `MatchEndController` | victory scene and post-match screen (Rematch / Play Again / Leave) |
| `ZoneController` | sudden-death wall, screen tint, warning tick |
| `DevModController`, `PickerController`, `RangeController`, `GunReviewController` | test-mode tools: Mod panel (F8), gun picker (P), dummy health bars, gun review panel (F6, `Config/GunReview`) |
| `Util/` | `BodyClone` (client-only copies of bodies for death falls, the replay, the victory scene), `ShotLog` (your own shots, for the replay), `Crosshair` (the crosshair, `Config/Crosshair`), `HitFeedback` (crosshair markers + damage numbers, `Config/HitFx`), `HitFx`, `KillFeed`, `Ui`, `UiSound`, `TeamColor` (cyan allies, orange-red enemies), `Device`, `VfxPool`, `Frozen`, VFX kits (`FireKit`, `IceKit`, `GlitchVfx`, `WallFx`, `WindFx`) |

## src/lobby (Lobby place)
| Module | Owns |
|---|---|
| `server/Services/QueueService` | queue per mode (a Roblox party queues as one group on one team; the leader starts, anyone cancels), bot fill after `Config.botFillAfter`; attrs `QueueStatus`, `QueueMode`, `QueueSince`, `QueueStartsAt` |
| `server/Services/PartyService` | in-game party invites (Roblox has no party-invite API): pending invites with a TTL, size cap `Config.PARTY`, accept / decline / leave; validated, rate-limited |
| `server/Matchmaking/Parties` | groups this lobby server's players by Roblox party or an accepted in-game invite (local override) (`Player.PartyId`, leader = first to join it via `SocialService:GetPartyAsync`); attrs `PartyKey` (local key, never the real id), `PartyLeader`; Studio test attr `TestPartyId` |
| `server/Services/LockerService` | Locker equips: one skin line per gun, validated (`Shared/Locker.valid`), rate-limited; DataStore `LockerV1` (load with retries, never written after a failed load, debounced UpdateAsync, on leave and BindToClose); attrs `Skin_<gunId>`, `LockerLoaded` |
| `server/Matchmaking/Launcher`, `Matchmaker` | packs queued groups into two teams without splitting a party, forms a match and teleports to a reserved Match server; the Lobby → Match TeleportData contract |
| `client/Controllers/QueueMenu` | MATCH FOUND on every device; on phones only, the old code-built PLAY menu (1v1 / 2v2 / 3v3, FIND MATCH) |
| `client/Controllers/PlayMenuController` | desktop Play menu (Router "Queue"): `StarterGui.PlayMenu` mode tiles (click or 1-3 → `QueueRequest` join), and the searching bar `StarterGui.LobbySearch` (timer, bot fill, cancel → leave); backup `tools/studio/BuildLobbyMenus.luau` |
| `client/Controllers/PartyMenuController` | desktop Party menu (Router "Party", opened by the HUD's party +): `StarterGui.PartyMenu` + template `PartyPlayerCard`; your party, search, ALL / FRIENDS / LOBBY; INVITE → `PartyRequest` invite (here) or `SocialService:PromptGameInvite` (friend elsewhere); LEAVE → `PartyRequest` leave |
| `client/Util/CloseButton` | every lobby menu's round close button (drawn X; `make`, `hook`) |
| `client/Controllers/LockerController` | the Locker v5 (Router "Locker", no blur): `StarterGui.Locker` (Backdrop with floor shadow, side panel) + templates `GunCard` / `SkinTile` / `GunGroup` / `SkinEmblem` (emblems: `shared/Locker.EMBLEMS`), the 3D stage (`ReplicatedStorage.LockerStage`) in a full-screen ViewportFrame, gun and skin picture cards, preview, EQUIP, drag to turn / scroll to zoom; backup `tools/studio/BuildLocker.luau` |
| `client/Controllers/LobbyHud`, `Panels`, `WorldPrompts` | the lobby HUD (desktop: the Studio-built StarterGui ScreenGuis `LobbyPlayerList`, `LobbyBar`, `LobbyToast`, `LobbyTopbar` (settings + leaderboard buttons in Roblox's top bar) and `LobbyTasks` (off) through `client/Util/LobbyHudView`: player list with level and win streak, bottom bar, PLAY, party slots (the + opens the Party menu), incoming invites, toasts; PLAY scales out while queued; phones keep the old v2 dock; backup `tools/studio/BuildLobbyHud.luau`), placeholder menus (Shop, Battle Pass, Locker, Settings, Range), ProximityPrompts on tagged world parts |
| `client/Util/*`, `shared/Config`, `shared/LobbyNet` | menu kit, layout, router, icons; config; the lobby remotes |

## Tools (not synced; `tools/`)
`anim/` (`tp_rig.py`, `tp_clips.py`: the third-person clips, keyed on a rig of the match body and exported to `art-source/animations/`), `blender/` (model scripts; `make_body_mesh.py` = the block body), `opencloud/` (uploads), `studio/` (Studio-side builders and validators, e.g. `ValidateWeapons.luau`, `ThirdPersonReviewRig.luau`, `TpPreviewSheet.luau`, `MakePoseAnimations.luau` (old generators, now only the Mod / dash / flinch clips), `receive_server.py`, `maps/<Map>/`), `maps/`, `vfx/`, `audio/`, `textures/`, `icons/`, `balance/`.

## How to use this map
1. Name the area (e.g. "the Frost burst hurts allies") → find the rows → `Grep -n "symbol" src/...` → `Read` with `offset`/`limit`.
2. Gameplay numbers are in `src/shared/Config/*.luau`, never in the systems: grep the config first.
3. Anything touching a remote: read the owning service's handler and `Util/Validate` use, then the [Architecture](Architecture.md) shot walkthrough.

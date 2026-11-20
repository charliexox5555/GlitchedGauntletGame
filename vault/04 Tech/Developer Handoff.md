# Glitched Gauntlet developer handoff

Audit date **2026-11-17**. Sources are the current checkout, the project vault and both open Studio Edit DataModels. The owner confirmed that the game will keep two places for now and that Lobby V4 is the release target after cleanup.

## 1. The whole game in one pass

1. Players enter the Lobby and choose 1v1, 2v2 or 3v3 from **PLAY** or a Duels pad. They can join friends in a party, browse cosmetics, equip skins or open the Armorer's dialogue.
2. The Lobby server forms two teams from the current server's queue, keeping each party together. After the wait threshold it can fill missing seats with bots. The **Match Found** screen precedes a teleport to a reserved Match server.
3. The Match server reads the team plan. Eligible maps are put to a chance vote. It loads the winner, creates seats for the planned humans and bots, and opens the first draft.
4. Each round you select one of three offered guns and one Mod card. Guns come from the current shared weapon phase. Mods go into fixed Q/E/T slots and can be upgraded on a later draft. The build persists across rounds.
5. After the countdown everyone gets one life in the round. A shrinking circle settles long rounds. Dead players spectate. The first side to five wins takes the match, followed by a final-kill replay when the match ends on an eligible elimination.
6. Results offer **Rematch** on the same server if everyone agrees, **Play Again** via the Lobby queue, or **Leave** back to the Lobby. Neither the results screen nor a Git push publishes a Roblox place.

## 2. What owns each part

| Location | What it owns | How to edit |
|---|---|---|
| `default.project.json` | Match Rojo tree. `src/server` → `ServerScriptService.Server`, `src/client` → `StarterPlayer.StarterPlayerScripts.Client`, `src/first` → `ReplicatedFirst.Loading` | Edit the mapped files on disk. Use Rojo on port 34872. |
| `lobby.project.json` | Lobby Rojo tree. `src/lobby/server` → `LobbyServer`, `src/lobby/client` → `LobbyClient`, `src/lobby/shared` → `ReplicatedStorage.Lobby`. Maps `src/client/Util/Ui.luau` as `LobbyClient.SharedUi` | Edit the mapped files on disk. Use Rojo on port 34873. |
| Both projects | `src/shared` → `ReplicatedStorage.Shared`, `assets` → `ReplicatedStorage.Assets` | Test shared changes in both places. Config is replicated. Keep secrets and decision-making on the server. |
| Studio `Workspace` and `ServerStorage` | Lobby rooms, map models, staging layouts, builders and backups | Inspect Studio Explorer or MCP. Find the builder or Blender source first if the edited object is generated. |
| Studio `StarterGui`, `ReplicatedStorage.UiTemplates` | Screen layouts and cloneable rows, cards or icons | Modify the builder and update the owning Studio template. Lua controllers bind its names and fill its state. |
| Studio `ReplicatedStorage.Weapons`, `WeaponSkins`, `Abilities` | Mesh-heavy runtime objects. Both places carry weapons and skins. Match holds the ability assets. | Use the relevant art and import pipeline and verify IDs, pivots, attachments, collisions and names in Studio. |
| `art-source/` | Blender sources, exported art, asset manifests, model backups and upload ledger | Edit the source and track the resulting asset references. Check the ledger before importing or uploading again. |
| `tools/` | Blender automation, Open Cloud uploaders, Studio builders, validators, texture, audio and icon helpers | Read the matching vault instructions before running a builder against either place. |
| `vault/` | Obsidian source for decisions, design, production, art and handoffs | Open this folder as the vault. Start from [Home](../00%20Home.md), [INDEX](../INDEX.md) and the [Code Map](Code%20Map.md). |

All four client/server entry scripts load the Service or Controller ModuleScripts, call `init()` on each, then spawn their `start()` methods. Lobby applies `LobbyLook` before its controllers initialize. Dependencies should not assume order within a phase. Where a screen is Studio-owned, its controller is only half of the feature. Search the [Code Map](Code%20Map.md) for both owner and builder.

For mesh-backed changes, trace the Blender source to the export manifest and upload ledger, then the installer into the right Studio container. The Import pipeline section in [Art Direction](../02%20Art/Art%20Direction.md) documents the base-gun path and `tools/studio/ValidateWeapons.luau`. Check asset availability and backups before rebuilding. Older checked-in gun backups may predate the models in Studio. The Match scene also holds versioned weapon backup folders under ServerStorage.

## 3. Lobby

**Place** `71551303511506`, experience `10772880160`. The open place contains `Workspace.Lobby` (V3), `SunwellStaging` and `LobbyV4Staging`. The enabled spawn is in `LobbyV4Staging.Anchors` around X = −1500. V3 and Sunwell spawns were disabled during inspection. This establishes the open place's spawn. Published contents require a separate check.

### Walk the hub

| Area | Studio and code |
|---|---|
| **Concourse** | V4 spawn, portal signs and routes to Duels, Locker and Shop. The Range door is sealed in this build. Layout is in `Workspace.LobbyV4Staging.Concourse` and the V4 source under `tools/blender/lobby_v4` and `tools/studio/lobby_v4`. |
| **Duels** | Eight physical bays, 16 team-well visual anchors and 16 TV anchors. Six `LobbyQueue` Step zones are active in V4 for the supported three modes, two each. The 4v4 and 5v5 physical bays are placeholders. `LobbyPadFx` drives rings and glow. `LobbyPathFx` drives nine chevron runs and two aisle pulses. Four `LobbyHallBoard` anchors mark the hanging screen cube. Pad and hall TV content is unfinished in the build notes. |
| **Locker** | E on the Armorer opens `NpcTalk`. Reply text lives in `src/lobby/shared/NpcTalk.luau`. The HUD's Locker button also opens it. `LobbyGunDisplays` populates 18 tagged anchors with that client's equipped gun skins. `StarterGui.Locker`, `ReplicatedStorage.LockerStage`, `LockerController` and its templates own the menu preview. |
| **Shop / Season** | `ShopController` and `BattlePassController` fill Studio-owned screens from `ShopCatalog` and `SeasonCatalog`. `ItemStage` renders 3D previews and `Shared.ItemIcons` supplies item pictures. The catalog, odds and browsing UI exist. Purchase and claim fulfillment are waiting on progression and economy work. |
| **Other UI** | `LobbyHud` / `LobbyHudView` handle the bar, party slots, player list and toasts. `Router` owns menu transitions. `SettingsController` includes reduced motion and crosshair preview. `ProfileController` shows player and equipped skin data. `RewardsController` owns the reward prompts. |

See [Lobby V4 Build](../02%20Art/Lobby%20V4%20Build.md), [Lobby UI overhaul](../02%20Art/UI%20Lobby%20Overhaul.md) and [Lobby UI and Queue](../01%20Design/Lobby%20UI%20and%20Queue.md).

### From a button or pad to a server

- Desktop `PlayMenuController`, phone `QueueMenu` and `WorldPrompts` are separate front ends. The V4 step path is `WorldPrompts` → `QueueState` → `LobbyNet.QueueRequest`. Leaving a step zone cancels a search started by that pad. Server-side rate, party and mode rules still apply.
- `QueueService` holds per-mode queues, publishes queue values and emits `QueueEvent` updates. `Parties` resolves Roblox party membership and accepted local invitations. `PartyService` handles invitations. The party leader queues the group and the lobby cap is three players per party.
- `Matchmaker` fits whole parties into equal-sized teams where possible. The oldest entry waits **30 s live / 5 s Studio** for bot fill. `Config` owns these values and the **3.5 s** found delay. Matchmaking is per Lobby server. Cross-server matchmaking is a future feature.
- `Launcher` sends `{v, matchId, mode, teams, bots}` to Match. `teams` holds arrays of user IDs. Each match gets a reserved-server ID and retry state. In Studio the launcher logs its intended payload and steps through the UI. External teleport needs the live published experience.
- `MatchFoundController` passes the custom `LobbyLoading` GUI to Roblox. Match's `src/first/LoadingScreen.client.luau` picks it up and fades it out. That receiver is on disk and builds successfully. It was absent from the open Match Edit DataModel during this audit.
- `LockerService` validates skin equips, mirrors them to the player and persists them in `LockerV1`. When enabled, Match's `SkinPreviewService` reads that store into the player's `LockerSkins` folder. The in-match preview line overrides saved equipment while it is set to a line other than Stock. Shop browsing and cosmetic persistence are separate paths.

## 4. Match

**Place** `133387545285290`, same experience. Edit-mode Workspace holds the original maps and multiple redesigns. `MapService` collects eligible map models under `ServerStorage.Maps` and clones the selected map into `Workspace.ActiveMap` at runtime. Pool rules and card images are in `Config/Match`. Installed test layouts can exist outside the vote pool. In Studio, `ForceMap` can select those layouts directly.

### Runtime from join to results

| Stage | Actual owners and settings |
|---|---|
| Join | `Bots/MatchPlan` reads and validates Lobby join data. `MatchService` tracks seats. Bots occupy missing or late seats, and the player takes over during a selection window or on the next round. A side that has lost all its humans forfeits. |
| Map vote | `MapVoteService` publishes options and voting state through `MatchState`. Each vote is a ticket and Random is an option. `MapVoteController` fills the Studio template. Config gives 12 s to vote, shortens to 1.5 s once everyone votes and shows the selected map for 2.5 s. A Studio `ForceMap` skips the vote. |
| Draft and spawn hold | `DraftService` owns offers, server-checked picks, per-seat kits and lock-in. `DraftController` and `Util/DraftScreen` render the choices. Round one allows 30 s, later rounds 15 s, including a 3 s countdown. Players can look while held at spawn. Round-one early lock-in also waits for planned humans. |
| Weapons | `Config/Match.PHASES` and `GUN_POOLS_BY_ROUND` define the role pools. Both teams see the same three guns for the round. Round two offers Sheriff with 50 shield and two primaries. Heavy and Elite give 50 shield. |
| Mod draft | Empty Q/E/T columns offer a new ability per seat and avoid its previous card when possible. Filled columns offer their upgrade paths or MAXED. Pick one card. An eligible seat can roll one Glitch path. Charges refresh across rounds. |
| Fight | `CharacterService` prepares the bodies and health. `MatchService` drops the gate / hold and clocks a 50 s fight. `WeaponService` and `ModService` own combat outcomes. `HealthService` and `StatsService` feed health, kills, assists and results. |
| Sudden death and reset | `ZoneService` shrinks toward the map centre over 20 s to a **4-stud radius**. Outside damage goes straight to health and ramps up. The sudden-death cap is 60 s. Round end is 5 s. The next round uses the same map, with fighters reset and lingering Mod effects removed. |
| Spectate and replay | `SpectateService` provides the watched fighter state and streaming support. `SpectateController` and `ViewmodelController` display their POV. `ReplayController` uses buffered snapshots, shot sources and client body copies for a qualifying final kill. Phase A of the [Spectate Replay Fix Plan](../05%20Production/Spectate%20Replay%20Fix%20Plan.md) is committed locally. More changes in these files and bot helpers are in the working tree. |
| Results | `MatchEndService` and `MatchEndController` own the stats/result UI and post-match actions. First to five wins. The 20 s result window allows a unanimous Rematch, return to Lobby with an autoqueue intent, or return to Lobby idle. |

### Gunplay, movement, Mods and visuals

- **Gun stats and behavior.** Edit `src/shared/Config/Weapons.luau` for per-weapon tier, ammo, damage and tuning. See `Config/Combat`, `Util/Accuracy`, `Util/Spread` and `Util/Damage` for shared behavior. `WeaponController` predicts feel and sends inputs. `WeaponService`, its `Weapon/` helpers and `HitboxHistory` decide ammo, cadence, ray and rewind checks, and damage on the server.
- **Movement and aim.** `Config/Movement`, `Config/Input`, `Simulation/Movement`, `MovementController`, `InputController` and `CameraController` are the main entry points. Both open places had StreamingEnabled and Automatic authority. Player movements run on the owning client. Bots run on the server. The owner parked stricter movement/input verification. Preserve that choice while maintaining the existing server combat checks.
- **First-person feel and feedback.** Start with `Config/Viewmodel`, `Config/Juice`, `Config/Camera`, `Config/Crosshair` and `Config/HitFx`. `ViewmodelController` and its rig, arm, track and motion helpers control the held presentation. `EffectsController` routes muzzle, tracer, shell, impact and hit effects. Audio uses `AudioController`, `Config/GunSounds`, `Config/GunSoundAssets` and the shared/Mod cue modules. Third-person holds and recoil have separate grip, body-skin and pose paths.
- **Ability mechanics.** `Config/Mods` holds cards, slots and tuning. `Shared.Mods` implements the ability rules. `ModController` drives hold/preview/use, `ModService` handles server decisions, and `ModEntities`, `ModWalls`, `ModRecall` and `StatusService` own lasting effects. `ModSim` carries events for locally predicted movement Mods. `ModFxController`, the effect helpers and `Util/UpgradeFx` own presentation. The 12 documented abilities are Dash, Updraft, Molly, Firewall, Frost, Recon, Heal Orb, Stim, Recall, Shock Dart, Flash and Roller. Check whether a specific ability is enabled in config before assuming it can be drafted.
- **Bots.** `BotService` owns their lifecycle. `Bots/Brain`, `Perception`, `Nav`, `Aim`, `BotGun`, `BotMods` and `BotDraft` split behaviors. Tune in `Config/Bots`. Bots share the combat and draft systems, so verify both human and bot use when editing those contracts.
- **Match UI.** Start with `StarterGui` for MapVote, TopBar, BottomHud, DraftScreen, StatusTray, DeathScreen, Scoreboard, KillFeed and MatchEndScreen. Then trace the corresponding controller and `tools/studio/Build*` source. See `PhoneHudController` and the draft controller's phone path for layouts generated in code.

See [Match Flow](../01%20Design/Match%20Flow.md), [Gunplay](../01%20Design/Gunplay.md), [Abilities](../01%20Design/Abilities/00%20Abilities.md), [Ability Effects Map](Ability%20Effects%20Map.md), [Bots](../01%20Design/Bots.md), and [Maps](../01%20Design/Maps/00%20Maps.md).

## 5. How to make common edits

| I want to change… | Start here | Verify |
|---|---|---|
| Queue time, team size, or an available mode | `src/lobby/shared/Config.luau` and the queue/party/match-plan files | Play menu and step zones, party size, bot fill, Match plan and eligible maps. A new mode also changes the contract and UI. |
| Pad or room placement | Lobby V4 scene, tags and matching V4 builders | Player-height view, collisions, correct tagged zone and mode, queue cancel on leaving the zone. |
| Round timer, map vote, or weapon tiers | Match config and the relevant service | With `TestMode=false`, temporarily clear Studio `ForceMap` for vote coverage. Restore the previous Edit setting after the test. |
| Add or revise an arena | Workspace model and map note, `MapService`, `Config/Match.MAPS` | Correct model ID, team spawn and barrier tags, centre, bounds and map image, plus a Studio `ForceMap` trial. |
| Edit a screen or button | Studio template, controller, matching `tools/studio` builder | Same children/events expected by the controller, desktop and phone, and relevant matchmaking/phase transitions. |
| Equip or add a skin | `Shared/Locker`, catalogs, `ItemIcons`, `WeaponSkins`, art manifest | Preview, equip, walk past a display, verify Match first/third person, and confirm valid persistence behavior. |
| Tune a gun or test a Mod | Shared config and server/client pair | Studio test range with `TestMode=true`. P opens the weapon picker, F8 the Mod panel and F6 the gun review tool where enabled. Recheck in a real draft/round with the range off. |
| Swap a mesh, model or sound | [Art Direction](../02%20Art/Art%20Direction.md), `art-source`, `tools/blender`, `tools/opencloud` and Studio | Validate asset access, pivots/attachments, sound preload, appearance at player scale and any other place using it. Update [Asset Tracker](../06%20Assets/Asset%20Tracker.md). |

## 6. Audit snapshot and release handoff

| Check | Result on 2026-11-17 |
|---|---|
| GitHub and checkout | Remote main was `90399043`, local main `854ffdd1`, seven commits ahead with additional pre-existing modified and untracked work. The seven include queue pads, the map-vote fix, spectate changes and Lobby V4 Duels work. |
| Git history vs. place versions | The reported live 2v2 failure received a local fix in `50420256`. The vault records a Studio Vote → Draft regression test. The match place still requires a release check in the published experience. |
| Local verification | Rojo 7.4.4 built both projects from the checkout into temporary files. `stylua --check src` and `selene src` exited successfully. No local `rojo` process was running when inspected. Studio owns the scene and assets omitted from the build. |
| Open Lobby source parity | All 168 mapped source scripts matched the working tree after newline normalization. V4 spawn was enabled, other lobby spawns disabled, and reference containers remained. |
| Open Match source parity | 279 mapped scripts matched. The `ReplicatedFirst.Loading.LoadingScreen` script was missing. Another 43 `Server.WeaponBuild.BuildData` scripts were present outside the sourcemap. Check or back up those builder data modules before a sync that might affect their root. |
| Open Match settings | `TestMode=false`, `BotMatch="2v2"`, `ForceMap="OldTown2"`. A default Studio launch here would skip map voting. |
| Release scope | Two places for now. Prepare V4 after cleanup. The [Bugs & Ideas note](../05%20Production/Bugs%20%26%20Ideas.md) records reference paste/placeholder cleanup for Lobby and potentially stale base-weapon backups. |

This audit compared Edit state and source hashes and built the code. It did not run playtests or inspect published DataModels. The [Setup Guide](Setup%20Guide.md) gives the sync and handoff steps. The [Codex workflow](Codex%20Collaboration.md) records what migrated from Claude.

### Where to start when something looks wrong

| Symptom | First check |
|---|---|
| Code changed on disk, Studio still shows older behavior | Confirm place ID, connected Rojo project and expected Studio script. If it only happens on Roblox, check the published version of that specific place. |
| Studio Lobby says Match Found, then returns to Lobby | Look for the intended payload in Output. This is the Studio launcher path. Compare its mode and teams against `Bots/MatchPlan`. |
| Match starts straight in OldTown2 | Check Edit Workspace's `ForceMap`. Clear it temporarily to verify map voting. Restore it afterward if you were testing the redesign. |
| A redesign is visible in Explorer but absent in the vote | Compare its model ID with `Config/Match.MAPS`. Candidate maps in Studio are distinct from the configured release pool. |
| UI appears in Studio but fails to populate in play | Inspect the player clone and named descendants in `PlayerGui`, then the controller and any `UiTemplates` clone. In Match, the first vote can run before a character spawns. |
| New skin previews in one place and falls back to Stock in the other | Compare `WeaponSkins/<Line>/<Gun>` in both places and confirm the saved Locker line is valid for that gun. |

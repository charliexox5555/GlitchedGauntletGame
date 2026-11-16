# Ability effects map (where each Mod's effect is drawn)

Made 2026-11-15 from a full read of the client effect code, so effect work can start from a file and a function instead of a search. Line numbers drift: grep the function name. Paths are under `src/`. Plan: [Ability Rework](../05%20Production/Ability%20Rework%202026-11-15.md). Look: [Ability VFX Direction](../02%20Art/Ability%20VFX%20Direction.md). RIVALS numbers: [Ability VFX Numbers](../03%20Research/Rivals%20Reference/Ability%20VFX%20Numbers.md).

## Shared
| Thing | Where |
|---|---|
| Team colours (ally `00E5FF`, enemy `FF5A36`, glitch `FF3DCB`) | `client/Util/TeamColor.luau`; `ModFxController.teamColor(data)` |
| ModFx remote (server to clients) | sent in `server/Services/ModService.luau` (`ctx.fx`, `api.fx`); handled in `client/Controllers/ModFxController.luau` `onFx`, which calls `client/Util/UpgradeFx/init.luau` first |
| Predicted Mods (Dash, Updraft) | character attributes; other players' are mirrored by `client/Controllers/ModSimController.luau` |
| Pooled shapes | `client/Util/ModVfx.luau` (`quad`, `shell`, `mesh`, `burst`), `VfxPool.luau` |
| Mesh kits in `ReplicatedStorage.Abilities` | `GlitchVfx.luau` (GlitchVFX), `FireKit.luau` (FireVFX), `IceKit.luau` (IceVFX), `ModVfx.mesh` (ModVFX). Each effect falls back to an older particle look when its kit is missing |
| Texture ids | `shared/Config/VfxTextures.luau` |
| Held and thrown prop models | `client/Util/ModProps.luau` (`get`, `dress`, placeholders) |
| Status tray | `client/Util/StatusTray.luau` (`TIMED` table reads `*Until` attributes) |
| First-person gestures and item actions | `shared/Config/Viewmodel.luau` (data), `client/Util/ViewmodelHeldMods.luau`, triggers in `client/Controllers/ModController.luau` |
| Screen wind strokes (Dash, slide, Updraft, Ghost cue) | `client/Util/WindStrokes.luau`, numbers in `Config/Mods.luau` `WIND_FEEL` |

## Per Mod
| Mod | Effect | File and function |
|---|---|---|
| Updraft | Launch, world (others only): gust rings, puffs, trail | `client/Util/WindFx.luau` `updraft` |
| | Launch, caster camera and hands | `ModController` (grep `UpdraftAt`), `Config/Mods` `UPDRAFT_FEEL`, `Viewmodel` `UpdraftDown`, `UPDRAFT_DIP` |
| | Crash Down dive | `client/Util/UpgradeFx/Updraft.luau` `startDive`, `stepDive`, `endDive` |
| | Crash Down impact | same file `impact`, `kitImpact` (GlitchVFX cracks, rubble, pixel ring) |
| | Third-person poses | `shared/Simulation/Poses.luau` (`Updraft`, `UpdraftSlam`, `UpdraftSlamLand` clips) |
| Dash | World (others): gust ring, wisps, trail, end puffs | `WindFx.dashStart`, `dashEnd`, called from `ModFeelController` |
| | Ghost: see-through body, afterimages, cloak | `client/Util/UpgradeFx/DashGhost.luau` |
| | Desync decoy | `client/Util/UpgradeFx/DashDecoy.luau` (`copyOf`, `spawn`, `stepDecoy`, `fakeShot`, `glitchOut`) |
| Molly | Flight (pooled canister, embers, clinks) | `ModFxController.onCanisterThrow` |
| | Floor burst and fire patch | `client/Util/MollyFx.luau` `ignite`, `meshFire` (FireKit), `build` (particle fallback) |
| | Burning player | `MollyFx.stepBurning` (reads `BurningUntil`) |
| | Fork Fire | `client/Util/UpgradeFx/Molly.luau` (`onThrow`, `MollyFork`, bomblets in `step`) |
| | Pin pull, throw, lob | `ModController.startHold`, `use`; `Viewmodel` `MollyPinPull`, `ITEM_ACTIONS.Throw` / `Lob` |
| Firewall | Hand flame (own) | `ViewmodelHeldMods.flameEmitter` |
| | Hand flame (others) | `client/Util/WallFx.luau` `stepHands` |
| | Fire curtain pieces | `WallFx.dress`, `meshWall`, `placeMesh`, `rise` |
| | Frost Wall | `client/Util/FrostWallFx.luau`; `UpgradeFx/Firewall.luau` (hand restyle) |
| Frost | Flight | `ModFxController.onCanisterThrow("Frost")` |
| | Impact | `client/Util/FrostFx.luau` `burst`, `kitBurst` |
| | Hindered bodies and screen | `FrostFx.bodyOf`, `holdIce`, `freeIce` |
| | Freeze Frame shell and shatter | `client/Util/UpgradeFx/Frost.luau` `snapFreeze`, `encase`, `kitShell`, `shatter` |
| Recon | Charge and bounce meter | `client/Controllers/ModHudController.luau` (`ChargeMeter`, `updateMeter`) |
| | Projectile and stuck dart | `ModFxController.onCanisterThrow("ReconDart")`, `dressDart` |
| | Scan pulse | `ModFxController.onReconPulse` |
| | Ping Spike arming and wave | `client/Util/UpgradeFx/Recon.luau` `onStick`, `onSpike`, `stepWaves` |
| | Ally-side outline | `ModFxController.onReveal`; Spike look `UpgradeFx/Recon.onReveal`, `stepMarks` |
| | Victim's DETECTED | `ModFeelController.onFx` (`Revealed`), `StatusTray.reveal` |
| Heal Orb | Heal cue (ribbon, ring, motes, screen) | `client/Util/HealFx.luau` `start`, `ribbon`, `burst`, `glowOn` |
| | Barrier bubble, hit, break, owner screen | `client/Util/BarrierFx.luau` (`makeBubble`, `block`, `crackScreen`, `buildScreen`); routed by `UpgradeFx/HealOrb.luau` |
| Stim | Beacon flight and deploy | `client/Util/StimFx.luau` `drop`, `stepBeacon`, `deploy`, `bolt` |
| | Strong Stim, Heal Zone | `client/Util/UpgradeFx/Stim.luau` `strongDeploy`, `healDeploy` |
| Recall | Anchor dressing, shimmer, arrive pops | `client/Util/RecallFx.luau` `setUp`, `stepShimmers`, `arrive`, `crashArrive` |
| | Range ring | `client/Util/RecallRing.luau` |
| | Crash Recovery | `client/Util/UpgradeFx/Recall.luau`, `UpgradeFx/RecallCrash.luau` (`ghost`, `play`, `crashScreen`) |

## Known gap that touches several effects
The skinned limb meshes (`GGSkinLimb`, in `Workspace.GGBodyLimbs`) are not inside the character Model. Anything that works on "the character" misses arms and legs: the Recon outline (one Highlight on the Model), the Desync decoy (`DashDecoy.copyOf` does not re-attach limbs; `BodyClone.copy` does), and probably Freeze Frame's bounding box and Crash Recovery's ghost boxes.

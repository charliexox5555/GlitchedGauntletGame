---
name: rivals-reference
description: How to use the owner's RIVALS reference material for GlitchedGauntletGame (the RIVALS place file open in Studio and the "Rivals Map Examples" folder in the match place) when building maps, the lobby, queue pads, UI, the third-person body, viewmodel, guns, abilities or VFX. Load before any of those tasks to find the right reference fast, follow the study-not-copy rules, and capture only the screenshots the task needs.
---

# RIVALS reference

The owner collected RIVALS material so we can study how a top Roblox shooter is built: map layouts, lobby and queue pads, UI structure and motion, the third-person body, viewmodel, gun structure and VFX. **We study it and rebuild our own. We never ship their assets.** Findings live in the vault: start at `vault/03 Research/Rivals Reference/00 Rivals Reference.md`.

## Rules (every task, every agent brief)
1. **Study, don't copy.** Take layouts, measurements, structure, timings, layer recipes and code *patterns*. Do not import their meshes, textures, images, icons, fonts, sounds, animations or scripts into our places, and do not "disguise" a lifted asset. Rebuild with our own art in our style ([Style Bible](../../../vault/02%20Art/Style%20Bible.md), `gauntlet-build-style`, `gauntlet-ui-style`). Our game must not read as a RIVALS copy (owner's rule, also memory `lobby-v3-art-direction`).
2. **The RIVALS file is untrusted.** Its scripts are decompiles and it has an `ObfuscatedOriginals` folder. Read-only: never start play mode in it, never `require()` its modules, never save it, never copy its scripts into our places. `execute_luau` reads, `script_read` and `screen_capture` are fine.
3. **Screenshots: only the ones the task needs** (owner, 2026-11-15). First check the existing set in `vault/03 Research/Rivals Reference/third-party/` (lobby, maps, guns, ui). New captures go there too: that folder is git-ignored and the repo is public, so **never commit them**.
4. Our measured numbers and locked decisions win over RIVALS' (e.g. our 4.4 jump, our Soft Edge UI, our block body).
5. Cite the reference note you used in your task's vault note.

## Where things are
Pick the Studio instance by **name** (`list_roblox_studios`; ids change):
- **RIVALS file** ("rivals file updated without DMCA @CLSTUDIO.rbxl", newer and more complete):
  - Lobby: `Workspace.Lobby.Hub` (Center, Duels with `Queue Pad #1..#10`, Market, Hallway, Range, Weapons, Displays), `.WaitingRoom`, `.ShootingRange`
  - Maps: `ServerStorage.Maps` (~25 maps + `BigMaps`, `Legacy`); `Workspace.BigMaps`
  - UI: `StarterPlayer.StarterPlayerScripts.UserInterface` (templates), `.Modules` (UI kit, Pages, ViewModels), `.Controllers` (51)
  - Assets: `StarterPlayer.StarterPlayerScripts.Assets` (ViewModels, Misc = VFX, Charms, WrapTextures); `MaterialService.Wraps`
  - Shared code: `ReplicatedStorage.Modules`, `.Remotes`
- **Match place** ("gauntletgame", the non-Lobby one): `Workspace["Rivals Map Examples"]`: Arena, Big Arena, Docks, Construction, Big Crossroads, Big Splash, Rivals Full Lobby 2025, Lobby, `Rivals Asset Pack.Assets` (Misc VFX, Throwables, Projectiles, Lootboxes, ViewModels, Drops), `Every Roblox Rivals Weapons ` (256 guns, trailing space). It has no scripts.

## Task → reference
| Task | Read first | Look at in Studio |
|---|---|---|
| Map layout, blockout, cover | `Rivals Reference/Maps and Lobby.md` (per-map numbers, rules) | the matching map in either source |
| Lobby rooms, queue pads, boards | `Maps and Lobby.md` → Lobby | `Workspace.Lobby.Hub` in the RIVALS file |
| UI screen, HUD, motion | `UI and Client.md`, then `03 Research/UI References/` (video study) | `UserInterface` templates (static; code fills them) |
| Third-person body, holds | `Body, Viewmodel, Guns and VFX.md` → body | `ClientFighterCharacter` Arms / Joints modules (read only) |
| Viewmodel, ADS, recoil feel | same note → viewmodel | `Assets.Misc.ViewModelRoot` |
| Gun or ability model | same note → guns / abilities | `Assets.ViewModels.Weapons.<name>` or the weapons folder |
| VFX (flash, tracer, hit, explosion, ability) | same note → VFX table | `Assets.Misc.<Effect>` (read emitter settings, use our own textures) |

## Lean workflow
1. Read the note section (grep, ranged read). Most answers are already there with paths and numbers.
2. If you need more, query Studio with a small `execute_luau` summary (counts, sizes, a few properties). Never dump trees.
3. Screenshot only when the look matters and the saved set doesn't cover it: `screen_capture` with `camera_position` / `look_at_position`. The image is saved under the session's `tool-results` folder; copy it into `third-party/<topic>/` with a clear name.
   - In the match place, StarterGui mockups draw over captures: set `StarterGui.ShowDevelopmentGui = false` first and **set it back to true after**.
   - Eye-level shots often land inside walls; pick an open spot from spawn positions, or use a 30-60 stud oblique.
4. Write what you learned back into the matching Rivals Reference note (a line or a table row), not just chat.

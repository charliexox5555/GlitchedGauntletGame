# Ability art handoff

The owner declined both art passes in this folder. The files are review history. Start from the [current Claude handoff](../../../vault/04%20Tech/Prompts/2026-11-15%20Ability%20Rework.md), which calls for fresh art through live Blender MCP.

Open [Gauntlet_Mod_Rework.blend](Gauntlet_Mod_Rework.blend) and choose the Mod's scene. The named collections are editable at game scale. The review scenes show the prop lineup, three Molly poses and previews of the effect meshes. The mask scenes are the sources of the two transparent texture bakes.

[Molly moving parts](../../../vault/02%20Art/References/mods/rework/Molly%20Moving%20Parts.png) · [Prop lineup](../../../vault/02%20Art/References/mods/rework/Ability%20Props%20v01.png) · [VFX sheet](../../../vault/02%20Art/References/mods/rework/Ability%20VFX%20v01.png)

Use the FBX and matching JSON from [Exports](Exports/) in the [ability import pipeline](../README.md). Each prop uses the project convention of one Blender unit per stud, +X forward and +Z up. The JSON locators carry the rest positions. The Studio builder puts those attachments on `Root` and places each uploaded mesh using its bounds. Use the named attachments to set moving-part pivots, rather than taking the center of the imported MeshPart as the hinge. The axis conversion in `AbilityBuilder` maps Blender +Y to Roblox −X and Blender +Z to Roblox +Y.

## Moving parts

| Prop | Targets and locators | Studio hookup |
|---|---|---|
| Molly | `Lever` → `LeverPivot`. `Pin` → `PinPivot` and `PinPull`. `PrimePad` → `PrimePadPivot` and `PrimePadPressed`. `Handle` and `Fuse` keep their existing purposes. | Seat the pin and pad for the hold. The pull point is .11 studs along Blender −Y, the pad travel is .008 studs down, and the review pose opens the latch 43° around Blender −Y. Use these as visual starting points for the equip/throw/lob. Release or hide the pin and latch at the appropriate gesture beats. Keep this cosmetic motion synchronized with projectile creation. |
| Frost | `Lever`, `Pin`, `LeverPivot`, `PinPivot`, `PinPull`, `Handle`, `Fuse`. | Use the same separable-piece convention as Molly while preserving Frost's javelin throw and lob. |
| Recon | `UpperLimb`, `LowerLimb`, their plates and string tip fittings, and two `String*Segment` meshes. `LeftGrip`, `LimbUpperPivot`, `LimbLowerPivot`, `StringUpper`, `StringLower`, `StringNock`, `StringNockDrawn`, `BoltTipHeld` and `Muzzle`. | The left hand holds the bow and the right draws. Bind each plate and fitting to its limb. Recalculate the string segments between the moving limb endpoints and the drawn nock. Use the separate `ReconDart` FBX for both the nocked bolt and the projectile. Its origin is the tip. Place that tip at `BoltTipHeld`, offset it with the nock during the draw, and release into the existing projectile lifecycle. The charge and bounce pips keep their existing runtime names. |
| Stim | `Coil_Yellow`, `CoilPivot`, `Floor`, `Top`, `Light_Energy`. | The existing toss, landing and deploy can drive the staged appearance. Use `Top` to anchor the zone emitter, and keep the coil's warm accent. |
| Recall | `Core`, `PhaseRing`, `PhaseInset`, `CorePivot`, `PhasePivot`, `Floor`, `Top`. | The core and ring can pulse independently. Treat the mint core and inset as fixed prop colors when updating the team tint rules. Use `Light_Energy` for team status. |

## Visual effects

The [ReworkVFX manifest](Exports/ReworkVFX.json) contains 25 reusable meshes. Its export scene keeps each piece at its own spawn pivot. The review scene arranges them for inspection.

- **Dash and Updraft.** `WindSwipe_Energy` and `GhostSkim_Energy` for short shaped world streaks. [Dash Edge](Textures/Dash_Edge.png) and [Updraft Edge](Textures/Updraft_Edge.png) are transparent white masks for screen-space tint and motion. Use the cast direction and existing timing hooks.
- **Crash Down.** Expand `CrashPressureRing_Energy` at ground level, fan `CrashDustPetal_Energy` outward and burst `CrashChip` from the impact. Fit the visible ring to the final tested damage radius.
- **Molly and Firewall.** Stack `FlameOuter_Energy` and `FlameCore_Energy` for the in-hand ignition, ground fire and brief burn licks on the body. Use `Ember_Energy` for accent and Fork Fire split trails. Build the wall's sight coverage from `FlameWallSegment`, with `FlameWallCrest_Energy` at the rolling edge.
- **Frost.** `FrostWallPlate`, `FrostChip` and `FrostBurstRim_Energy` cover wall, projectile burst and edge breakup. Scale `FreezeShell` around the current body's pose, and use `FreezeCrack_Energy` and chips for the break.
- **Recon.** `ReconEquator_Energy`, `ReconUpper_Energy` and `ReconLower_Energy` are bands centered on the bolt and shaped around one shared unit sphere. Scale them together to the radius sent by gameplay. `ReconSpike_Energy` is the stronger front for Ping Spike.
- **Heal Orb, Heal Zone and Barrier.** Keep the existing orb core. Use `HealRibbon_Energy` and `HealMote_Energy` off the held orb, `HealZonePulse_Energy` at Stim's healing field, and `BarrierHexTile_Energy` as a shield accent. Sync appearance and fade to the authoritative status.
- **Recall.** Use `RecallPhaseStreak_Energy` and `RecallPhaseRim_Energy` for departure, arrival and the heavier Crash Recovery beat.

The mesh pieces and white texture masks are authored in Blender. Studio work includes assembling and timing effects, rigging individual MeshParts and the first- and third-person holds, importing the assets into the experience and checking them in play. See the [full rework brief](../../../vault/04%20Tech/Prompts/2026-11-15%20Ability%20Rework.md) for gameplay, HUD and review requirements.

## Rebuild

Run in the repository root.

```powershell
blender --background --factory-startup --python tools/blender/build_mod_rework.py
blender --background --python tools/blender/build_mod_rework.py -- --export
blender --background --python tools/blender/build_mod_rework.py -- --render
```

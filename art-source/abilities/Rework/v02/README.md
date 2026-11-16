# Ability art v02 review

The owner declined this art direction. See the [current Claude handoff](../../../../vault/04%20Tech/Prompts/2026-11-15%20Ability%20Rework.md) for the fresh build.

[Editable Blender file](Gauntlet_Mod_Rework_v02.blend) · [FBX and locator metadata](Exports/) · [Transparent effect textures](Textures/)

[Prop lineup](../../../../vault/02%20Art/References/mods/rework/Ability%20Props%20v02.png) · [Stim and Recall close-up](../../../../vault/02%20Art/References/mods/rework/Stim%20and%20Recall%20Details%20v02.png) · [Molly moving parts](../../../../vault/02%20Art/References/mods/rework/Molly%20Moving%20Parts%20v02.png) · [Effect studies](../../../../vault/02%20Art/References/mods/rework/Ability%20VFX%20v02.png)

This pass follows the gun models' matte receiver, dark grip, small hardware and inset status-light treatment. The canisters use sloped cases with recessed inserts. Frost's vent slots are cut through the shutter panel, with the cooling material behind it. Recon uses bored truss openings, a ribbed grip and a bolt seat. Stim's carry opening is cut from its unified housing. Recall uses a continuous fork around an inset emitter.

## Historical Studio handoff notes

Use v02's FBX and JSON files together. Keep the pivots specified in the [rigging notes](../README.md#moving-parts). Molly's lever, pull tab and prime pad are independent meshes. Recon's limbs, fittings, string segments and dart are independent as well. The v02 asset collections use the same identifiers and axis conversion as the existing import pipeline.

Use the revised fire meshes and other building blocks from `ReworkVFX.fbx`. `Dash_Edge.png` and `Updraft_Edge.png` are white 16:9 alpha masks with open centers. `FireTongue_2x2.png`, `FrostWake_2x2.png` and `CrashDust_2x2.png` are color-and-alpha atlases with frames in top-left, top-right, bottom-left and bottom-right order. They are intended as layers alongside the world meshes and timed effects. The Blender action studies show layering, silhouette and color at a representative moment. Use the [gameplay brief](../../../../vault/04%20Tech/Prompts/2026-11-15%20Ability%20Rework.md) for runtime timings, HUD work and playtests.

The source includes the review scenes and editable sprite shading. From the repository root, run `blender --background --factory-startup --python tools/blender/build_mod_rework_final.py` to rebuild. Use the same script with `-- --export` for the assets or `-- --render` followed by the saved scene names for the renders.

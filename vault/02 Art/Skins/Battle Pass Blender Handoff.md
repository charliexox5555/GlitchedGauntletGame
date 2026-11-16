# Poolside and Rootglass Blender handoff

Start production after the owner approves the concept sheets. The queue covers **35 fictional game cosmetics**. Use Poolside Spectre as the first prototype and wait for the owner's review of the saved Blender asset. After that approval, build Rootglass Vandal and one Leafblade, then finish both gun rosters. If the owner approves the Leafblade sheet without choosing an option, use **A / Broad Leaf**, the lead design.

| Asset | Concept sheet | Stock reference |
| --- | --- | --- |
| Poolside Spectre | [Enamel and stripe study](Poolside/out/Spectre_concept_v01.png) | [Model sheet](../../../art-source/weapons/ModelSheets/Spectre_model_sheet.png) · [Blender v05](../../../art-source/weapons/RemasterV2/Spectre/Spectre_RemasterV2_v05.blend) |
| Rootglass Vandal | [Shell, mineral window, and inspect study](Rootglass/out/Vandal_concept_v01.png) | [Model sheet](../../../art-source/weapons/ModelSheets/Vandal_model_sheet.png) · [Blender v05](../../../art-source/weapons/RemasterV2/Vandal/Vandal_RemasterV2_v05.blend) |
| Rootglass Leafblade | [Two silhouettes and orientation studies](Rootglass/out/Leafblade_concept_v02.png) | [Stock Knife model sheet](../../../art-source/weapons/ModelSheets/Knife_model_sheet.png) · [Blender v05](../../../art-source/weapons/RemasterV2/Knife/Knife_RemasterV2_v05.blend) |

The [concept brief](Battle%20Pass%20Skin%20Line%20Concepts.md) has the 17-gun roster, colour targets, and per-item placement. Use each item's own stock source and matching renders. Poolside concept views use the stock mesh. Rootglass Vandal's shell rendering is art direction and shifts some proportions, including the exposed barrel and sights. Take dimensions and camera alignment from the stock asset. The Leafblade's pose thumbnails are orientation studies. Verify the grip in the rig.

## Build scope

1. Connect with **Blender MCP on `127.0.0.1:9999`**. Verify the port and query the open scene read-only. Protect the open file and unsaved work before appending or opening the stock asset. Use versioned working copies.
2. **Poolside** is a static material pass on the stock mesh. Use satin pool-blue enamel, two warm-white lane stripes, one butter-yellow starting-block mark and matte navy hardware. Keep a clean bend visible from the held camera and choose its path so it survives baking across fixed seams. Fit the graphic to each item. Preserve stock geometry, UVs where usable, rigs, sight and contact positions, and stock actions.
3. **Rootglass** has custom outer shells at Moltframe's detail level. Use overlapping walnut forms, a recessed moss-green mineral window, a narrow antique-bronze seat, and one amber root motif that reads in a small reward preview. Keep the source's overall size, recognizable side silhouette, sight picture, contacts, and moving assemblies. The amber trace is decorative. Prepare a separate mask or named element for a single inspect pulse, then settle back to the visible static vein. Preserve stock gun actions and ammunition. [Moltframe reference](Moltframe/concept.md)
4. **Leafblade** is one new silhouette for the Knife slot. Use the approved blade profile, pale bevel, walnut grip, bronze collar, and amber inlay. Fit it to the stock hand anchor and review the blade and collar join against a high-contrast background. Test idle, draw, stock slash and inspect poses for grip, knuckle and camera clearance. Prepare reference frames and material/pivot notes for the animator.
5. For both lines, start Bulldog and Stinger from the reviewed shared source fixes and rerun the flagged close-ups and motion checks on each new variant. Use the previous troubleshooting notes for grazing-angle coplanarity, backface culling, sight-part names and UV bleed. [Regression checks](Reskin%20Geometry%20Regression%20Checks.md) · [Build ledger with repaired sources](Full%20Roster%20Reskin%20Build%20Ledger.md) · [Skin build pitfalls](Skin%20Build%20Pitfalls.md)

Use the project's [vault skill](../../../.claude/skills/gauntlet-vault/SKILL.md) and [build style skill](../../../.claude/skills/gauntlet-build-style/SKILL.md) and inspect the existing [bake](../../../tools/blender/bake_textures.py) and [export](../../../tools/blender/export_roblox_flat.py) helpers before adding dependencies. Evaluate any external skill's source before installing it if a specific gap requires one.

## Review and delivery

- Save versioned assets under `art-source/weapons/Skins/<Line>/<Item>/vNN/`. Deliver a `.blend`, packed and external colour, normal, roughness and metalness maps, a local FBX where the geometry needs an export, a manifest, and review renders. For a stock-mesh variant, document how its maps bind to the existing stock asset.
- Reopen the saved blend. Render three-quarter, both profiles, top, held and applicable stock aim views at matched scale and lighting. Check the material detail at held scale and in a battle pass thumbnail or turntable render. Scrub the relevant stock actions and check sight, hands and moving-part clearances. When the geometry is exported, reimport it and check both sides and a rear three-quarter with backface culling on a high-contrast background.
- Review UV padding, fixed-seam registration, moving-part paint stops, missing or flipped faces, crossed polygons, coplanar overlap, and gaps. Record evidence, open items, source versions, and the exact next item in a build ledger. Grade each hero on design and finish **/35**, geometry and stock fit **/30**, bake and seams **/20**, and held, aim and motion clearance **/15**. Aim for **95/100** with evidence. Correct visible faults before review.
- Keep the work in Blender and on disk. Studio, imports, asset uploads, battle pass tier and track assignment, and runtime integration are deferred.

## First prompt to paste after concept approval

```text
The Poolside and Rootglass concepts are approved. Start the Glitched Gauntlet battle pass cosmetic build in this workspace. Use Blender MCP at 127.0.0.1:9999 and confirm the active scene and port with a read-only query before editing.

Read vault/02 Art/Skins/Battle Pass Blender Handoff.md. Start with Poolside Spectre only. Use vault/02 Art/Skins/Poolside/out/Spectre_concept_v01.png and the stock Spectre RemasterV2 v05 Blender file linked in the handoff. Apply the blue satin enamel, two warm-white lane stripes, small butter-yellow mark, and matte navy hardware to the original mesh. Preserve the stock geometry, rig, sights and actions. Reuse the existing project skills and bake and review tools.

Save a versioned blend, baked maps, manifest, and matched stock-versus-skin review renders. Reopen the file, verify the stripe across panel seams, check held and ADS views and relevant stock motion, fix any issues, and grade the result with evidence using the handoff rubric. Aim for 95/100. Work in Blender and on disk. Leave Studio and battle pass integration for later.

Show me the saved Poolside Spectre prototype and wait for my approval before building the rest. Once I approve it, follow the handoff through Rootglass Vandal, the selected Leafblade, and all 17 guns in each line.
```

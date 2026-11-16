# Moderate skin line Blender handoff

Build the approved Playback, Breakwater, and Sundial concepts as cosmetic exterior remodels for Glitched Gauntlet. Start with **Playback Phantom only**. Deliver a saved Blender prototype and review evidence, then wait for the owner's look approval. After approval, build Breakwater Bucky and Sundial Guardian as the other style anchors, then complete the remaining variants in the table. The current batch is 12 variants.

This is a Blender and on-disk asset pass. Studio work, uploads, publishing, lobby, and gameplay integration are deferred. Prepare the decorative parts and inspect reference for the animation handoff. Blender preview motion can demonstrate the idea, and Claude owns final in-game animation.

## Build queue

| Line | Hero concept | Stock reference | Remaining variants |
| --- | --- | --- | --- |
| Playback | [Phantom](Playback/out/Phantom_concept_v02.png) | [Model sheet](../../../art-source/weapons/ModelSheets/Phantom_model_sheet.png) · [Blender v05](../../../art-source/weapons/RemasterV2/Phantom/Phantom_RemasterV2_v05.blend) | Bulldog, Stinger, Classic |
| Breakwater | [Bucky](Breakwater/out/Bucky_concept_v02.png) | [Model sheet](../../../art-source/weapons/ModelSheets/Bucky_model_sheet.png) · [Blender v05](../../../art-source/weapons/RemasterV2/Bucky/Bucky_RemasterV2_v05.blend) | Vandal, Spectre, Shorty |
| Sundial | [Guardian](Sundial/out/Guardian_concept_v02.png) | [Model sheet](../../../art-source/weapons/ModelSheets/Guardian_model_sheet.png) · [Blender v05](../../../art-source/weapons/RemasterV2/Guardian/Guardian_RemasterV2_v05.blend) | Operator, Ghost, Sheriff |

Use each item's own stock model and renders for sizing, recognizable silhouette, and camera framing. The [concept brief](Moderate%20Skin%20Line%20Concepts.md) defines the palettes, material breaks, signature details, and motion beats. The concept art illustrates the visual direction. In particular, the Phantom and Guardian concept art changes some stock proportions. Use the source scene and its camera for dimensions and sight alignment. Bucky's stock sheet supplies a held view and an above-angle reference. Use a stock-equivalent camera for any additional Blender sight check and describe how it was matched.

## Setup and modeling

1. Use **Blender MCP at `127.0.0.1:9999`**. Query the connected Blender scene read-only and confirm the active file and port. The older structural handoff uses a different port. Preserve the open scene and any unsaved work before loading stock or working in a separate scene. Work from a versioned copy of the stock asset.
2. Read the project's [vault skill](../../../.claude/skills/gauntlet-vault/SKILL.md), [build style skill](../../../.claude/skills/gauntlet-build-style/SKILL.md), [skin pitfalls](Skin%20Build%20Pitfalls.md), [geometry regression checks](Reskin%20Geometry%20Regression%20Checks.md), and [previous build ledger](Full%20Roster%20Reskin%20Build%20Ledger.md). Reuse the established bake, export, and review workflow where it fits a remodel. Inspect an external skill's source before installing it if an actual task gap calls for one.
3. Remodel the parts of the outer shell that carry the design. Match stock length, hand contacts, overall screen coverage, sights, magazine and other moving assemblies, rig, pivots, and attachment points. Minor thickness and bevel changes should serve the cosmetic design. Preserve stock fire, reload, draw, and aim actions and the stock ammunition and gameplay. Maintain the separation and names of stock sight and moving parts in the export.
4. Build **Playback Phantom** around the long, low smoked window, two offset faceted reels, brushed warm grey shell, aubergine lower panels, and muted lime meter. Keep the stock suppressor profile, narrow stock neck, original short magazine placement, and sight path. At held scale the recess, reels, and metal break should read at rest. Keep the decorative reel meshes independently named and pivoted. Capture the turn, reel advance and single meter sweep, and settled state. Give the asset a baked static finish.
5. For **Breakwater Bucky**, keep the flush stock underside and separate rear grip. Fit the orange bumper around the stock pump's hand contact, check the whole pump travel, and stop the off-white stripe at the fixed-to-moving boundary. Put the amber flip latch on the fixed body. For **Sundial Guardian**, size the porcelain spine against the original exposed barrel, keep the stock rear sight and narrow stock neck, and recess the one-notch brass dial in the fixed left shoulder. Keep the Operator's optic and scope view stock when adapting Sundial.
6. For Playback **Bulldog** and **Stinger**, use the already reviewed shared repair sources and repeat the checks after remodeling. For Bulldog, inspect the receiver and bolt-facing panel under grazing light and through the stock action. For Stinger, compare both sides and the underside of the front grip, along with the hand contact and receiver join. Save evidence in the variant's review folder. [Bulldog BoltFix v02](../../../art-source/weapons/Skins/Shared%20Sources/Bulldog/BoltFix_v02/Bulldog_RemasterV2_v05_BoltFix_v02.blend) · [Stinger HandguardFix v01](../../../art-source/weapons/Skins/Shared%20Sources/Stinger/HandguardFix_v01/Stinger_RemasterV2_v05_HandguardFix_v01.blend)

## Check the deliverable in Blender

- **Shape and first-person fit.** Render stock and skin at the same scale, camera and lighting. Include front-left three-quarter, left and right profiles, top, held/hip, and stock aim where available. Compare dimensions and stock contact points. Scrub applicable stock draw, fire, reload, and pump actions. Check that the new exterior stays clear of hands, moving parts, and the sight line throughout. Report any inherited stock artifact with evidence.
- **Geometry and export.** Inspect joins close up and from grazing angles. Look for coplanar overlap, flipped normals, missing or degenerate faces, crossed polygons, and gaps. Use the project's dry-run audits and reimport the on-disk FBX in an isolated Blender scene. Render both sides and a rear three-quarter with backface culling and a high-contrast background. Confirm that names, pivots, and part separation survive export. [Export helper](../../../tools/blender/export_roblox_flat.py) · [Prior results](Structural%20Skin%20Round%20One%20Results.md)
- **Materials.** Use distinct roughness and metal response so the large material blocks and small signature detail remain legible in neutral and first-person lighting. Check bake padding, UV bleed, fixed seams, and part boundaries in the saved blend after reopening it. Verify the packed maps and the delivered PNGs. [Bake helper](../../../tools/blender/bake_textures.py) · [Review workflow](Blender%20Review.md)
- **Inspect handoff.** Include the rest, transition, and settle frames for the decorative motion, with object names, pivot locations, and proposed timing. Record the static fallback and any runtime validation still needed.

## Save and present

Save under `art-source/weapons/Skins/<Line>/<Gun>/vNN/` with a versioned `.blend`, a local FBX, the baked Colour, Normal, Roughness, and Metalness maps, a manifest, and review renders. Increment the version on revisions and keep the stock and earlier versions available. Record the source, concept reference, cosmetic geometry and material changes, bake and export paths, check results, open issues, and exact next item in a build ledger.

Score the saved prototype with evidence. Use design and finish **/35**, stock fit and geometry **/30**, bake and seams **/20**, and held, aim, and motion clearance **/15**. Aim for **95/100**. Fix visible faults before presenting and disclose remaining issues and checks that require Studio. Show the review renders and wait for look approval on Playback Phantom before starting Breakwater Bucky.

## First prompt

```text
Start the Glitched Gauntlet moderate skin batch in this workspace. Use Blender MCP on 127.0.0.1:9999. Verify the port and current Blender scene with a read-only query before editing.

Read vault/02 Art/Skins/Moderate Skin Line Handoff.md and follow its source links, previous regression fixes, build checklist, and grading rubric. Start building Playback Phantom now. Use vault/02 Art/Skins/Playback/out/Phantom_concept_v02.png for the cassette housing, finishes, and inspect idea. Use art-source/weapons/RemasterV2/Phantom/Phantom_RemasterV2_v05.blend and art-source/weapons/ModelSheets/Phantom_model_sheet.png for geometry and sight alignment.

Remodel the cosmetic shell with a smoked two-reel window, brushed warm grey metal, aubergine panels, and a small lime meter. Match the stock overall size, hand contacts, suppressor, magazine, rig, and sight picture. Keep the stock gun actions and make the reels and meter ready for a short cosmetic inspect. Provide the static finish and inspect pose references for the animator.

Save a versioned Blender asset, baked maps, local FBX, manifest, and matched stock-versus-skin renders. Reopen the blend, reimport the export, check geometry, seams, held and ADS views, and motion clearances, then fix visible problems and give an evidence-based grade out of 100. Aim for 95 or higher. Keep the work in Blender and on disk. Leave Studio, uploads, and game integration for later.

Show me Playback Phantom and wait for my approval on the look. After I approve it, use the handoff queue to continue with Breakwater Bucky, Sundial Guardian, and the remaining variants.
```

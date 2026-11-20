# Ruin-Blighted Vandal model handoff

Build **one model**, the Shadow Mist Ruin-Blighted Vandal. The owner's [concept sheet](refs/style/Ruin-Blighted%20Vandal%20Reference.png) and [original breakdown](Owner%20Breakdown.txt) establish the look. Use the [concept brief](concept.md) for the decisions that apply to this pass. Work in Blender and save on disk. Effects, animated transforms, audio, custom rounds, the separate charm, alternate colorways, finishers, emotes, and Studio integration are later work.

## Start from the stock Vandal

1. Use **Blender MCP on `127.0.0.1:9876`**. A Blender process was listening there when this handoff was prepared. Query the scene read-only through MCP before editing. Identify the open file and keep unsaved work safe. Work from a versioned copy of the stock source. [Vandal RemasterV2 v05](../../../../art-source/weapons/RemasterV2/Vandal/Vandal_RemasterV2_v05.blend) · [Stock model sheet](../../../../art-source/weapons/ModelSheets/Vandal_model_sheet.png)
2. Follow the current [vault skill](../../../../.agents/skills/gauntlet-vault/SKILL.md), [build style skill](../../../../.agents/skills/gauntlet-build-style/SKILL.md), and [Style Bible](../../Style%20Bible.md). Block in the core, the largest fractured plates, and the crown first. Use planar facets and readable tapers. Check the shape in the stock held view before adding secondary fragments.
3. Keep the stock Vandal scale, orientation, rig and clips, hand contacts, controls, muzzle and ejection locators, sight alignment, and magazine pivot and travel. Remodel the **cosmetic outer structure**, especially the handguard shell, rear body and stock shells, and magazine casing. Preserve a coherent centerline and leave enough intact shell for the stock Vandal to remain recognizable.

## Geometry and static appearance

- **Chassis and fractures.** Build readable slate wedges with closed faces and deliberate gaps. Keep the biggest plates close to the stock footprint. Name the separated shard groups by area and put their origins where a future animator can use them. Their positions are fixed in this pass.
- **Crown and sights.** Model the three-pointed crown as a separate rigid piece. Keep its resting pose above or off the aim corridor so it clears the stock eye-to-sight line in the opaque, static model. Test the actual stock aim camera and near-plane. Adjust crown and shard placement to solve any blockage. Retain separate stock sight parts with their existing sight names and preserve the aperture and front sight alignment.
- **Magazine.** Build cracked dark outer plates within the stock curved envelope and attach the pieces to the stock magazine assembly. Use a restrained opaque teal ID on binding surfaces and seam accents. Scrub the stock reload poses to check finger, magwell, and body clearance.
- **Material preview.** Use matte obsidian, slate, and dark metal, with one flat seafoam or teal accent in the recesses and bindings. Deliver the shape using ordinary studio lighting and opaque materials. Keep the stock charm mount and document any simple mesh groups or locators useful for the later effects pass.

## Deliver for review

Save a versioned working file at `art-source/weapons/Skins/RuinBlighted/Vandal/v01/Vandal_RuinBlighted_v01.blend`. If that version is already taken, increment the version and keep the earlier file.

Reopen the saved file. Render a front-left three-quarter, both profiles, top, held, stock aim, and detail views of the crown, handguard and magazine. Include matched stock versus variant profile, held and aim images under the version's `review/` directory. Check attached joints and intentional floating gaps from both sides, and use a grazing angle and backface-culled view to catch coplanar flicker, open faces, crossed faces, or flipped normals. Scrub the source draw, reload, and inspect poses for clearance while leaving the stock actions intact. Log the source, version, changed meshes, intentional gaps, clearance results, triangle count, and any remaining issues. Give a short self-grade based on those review images. [Prior skin build pitfalls](../Skin%20Build%20Pitfalls.md)

## Kickoff prompt

```text
Start the Ruin-Blighted Vandal model in Blender MCP at 127.0.0.1:9876. Read vault/02 Art/Skins/RuinBlighted/Model Handoff.md and its linked owner concept sheet and original breakdown. Verify the open Blender scene read-only and use the stock Vandal RemasterV2 v05 as the geometry and aim reference.

Build the Shadow Mist gun model only. Sculpt the faceted obsidian chassis and stock, separate rigid shards and three-point crown, and cracked magazine shell with static teal accents. Keep the stock rig, magazine travel, hand contacts, sight picture, and charm mount. Check that the static crown clears the stock aim camera. Defer animation, VFX, custom ammo, the separate charm, and Studio.

Save a versioned blend, reopen it, check it against stock in profile, held, and aim views, and scrub the original reload to find clearance problems. Fix visible issues and show me the saved model, matched renders, and your self-grade.
```

# Geometry checks for Oilwake, Misprint, and Faultline

Use the stock Blender sources, the closest matching previous skin, and the new variant under the same angles and lighting. The two reported artifacts are open until the new variants pass. The stock captures identify the regions to inspect. A static stock capture alone cannot reproduce or rule out an angle-dependent glitch.

| Gun | Owner report and evidence | Where to start |
| --- | --- | --- |
| Bulldog | [Circled receiver patch](Misprint/refs/qa/02_bulldog-receiver.png). Small rectangular artifact near a panel break. | Compare the patch against the stock receiver and bolt-area parts. The earlier Payload Bulldog dotted line involved coplanar faces. Treat that as a hypothesis here. Inspect in motion, with the suspect material disabled, and with the suspected meshes isolated to distinguish geometry overlap, normals, and texture artifacts. |
| Stinger | [Circled front handguard](Misprint/refs/qa/01_stinger-front-grip.png). The dark ridged panel and adjacent join look broken. | Start with `Stinger_Handguard` and the receiver next to it. Inspect the ridges, face normals, and join from both sides and the underside. Check the base model and the previously affected skin before deciding where the fix belongs. |

## Before baking the roster

1. **Open and inspect.** Use Blender MCP on `127.0.0.1:9999`. Confirm which Blender process and file the connector reaches. Record the source version and identify the affected variant if available. Capture both sides of each flagged area at the owner’s angle and at a grazing angle. Scrub the relevant stock action if the seam is next to a moving part.
2. **Isolate the cause.** Compare flat material, textured, and backface-culled bright-background views. Check for near-coplanar faces and duplicate layers, crossed faces, flipped normals, open gaps, and UV overlap or bake bleed. Run the existing audits where applicable. Use the bare stock source to decide whether the new skin or the base needs work.
3. **Repair at the source.** Keep new treatments in the material maps, with existing sights, grips, pivots, and moving parts intact. If the stock Stinger handguard itself reproduces the defect, repair only the faulty faces or join in a versioned source copy. Preserve the foregrip profile, ridge design, hand contact and nearby part clearance. Save before and after renders and record the exact geometry exception. Use the repaired source consistently for the three new Stinger variants. Keep older production files available.
4. **Verify the delivered variant.** Reopen the saved Blender asset and render both flagged areas close up and in the full held view. If a mesh export changed, reimport it in an isolated file and repeat both angles with backface culling. If only the maps changed, review the baked preview with the stock mesh and verify shape, transforms, and actions against stock. A clean result should hold at grazing angles and anywhere the adjacent parts travel during the stock clips.

## Prior checks to carry forward

- Read [Skin Build Pitfalls](Skin%20Build%20Pitfalls.md), including its geometry and Studio cases, and [Structural Skin Round One Results](Structural%20Skin%20Round%20One%20Results.md) for the documented fixes. Use the [Blender Review](Blender%20Review.md) for the existing material-only comparison method.
- Keep stock mesh roles, named sight parts, and animation relationships. Confirm the sight window and near-plane clearance with the stock Blender aim camera. Check that the textured render preserves moving-part visibility and clean texture boundaries. Keep the live scope, ADS fade, and magazine hiding cases on the later Studio checklist.
- For any repaired or re-exported mesh, check normals, crossed polygons, degenerate faces, and coplanar overlap. Check joints with a high-contrast background and backface culling. Apply the project’s faceted shape and edge treatment rules where local geometry repair is required.
- Use the hero grade in the [concept pack](Full%20Roster%20Reskin%20Concepts.md) and link the flagged-area evidence in the ledger. Report any case that only reproduces in Studio as pending. This pass stays out of Studio while the other agent is working there.

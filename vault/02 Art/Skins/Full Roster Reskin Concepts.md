# Oilwake, Misprint, and Faultline

Three finish-only lines for the full Gauntlet gun roster. The **51 gun variants** keep stock proportions, sight pictures, hand contacts, moving parts, ammunition, and animation. Each gun gets its own placement pass. The Stinger foregrip can receive a local source repair if the defect reproduces on the stock mesh. The melee ideas are optional and outside the 51-gun count.

## Hero studies

| Line | First gun | Direction | Optional melee |
| --- | --- | --- | --- |
| Oilwake | [Phantom](Oilwake/out/Phantom_concept_v01.png) | Midnight blue-black satin metal. A broad petrol-green coated inset rolls toward warm amber at a grazing angle. Frame the inset with brushed steel and keep the surrounding shell quiet. The reflection moves with the camera. | Stock Knife with the finish isolated to the bevel. |
| Misprint | [Bulldog](Misprint/out/Bulldog_concept_v01.png) | Warm ivory enamel with oversized cobalt and vermilion blocks. Offset the print blocks, use a muted purple overprint in the overlap, and place a small halftone cluster at an edge. Run one graphic from the left face over the top on a fixed body section. | Stock Knife with one off-register print on the blade. |
| Faultline | [Sheriff v02](Faultline/out/Sheriff_concept_v02.png) | Ink-black satin ceramic breaks into a broad ash-grey face with three large value changes and a brighter copper repair. Branch the copper once and let the fracture carry the contrast. Keep the ornament away from the rotating cylinder and sights. | A chipped-stone blade with a copper seam is a separate concept if requested. |

The hero PNGs are Blender concept renders on the stock meshes. Consult the stock model and actual in-game view for the sight picture. The surface materials in the studies are visual targets for the later production bake.

## Full roster placement list

| Stock gun | Oilwake · where the colour shifts | Misprint · where the print sits | Faultline · where the fracture runs |
| --- | --- | --- | --- |
| Vandal | Broad receiver inset framed by a brushed edge. | Receiver and adjacent fixed handguard get one diagonal with a matching top crop. | Cross the receiver face once and stop at the handguard seam. |
| Phantom | The broad forward side panel carries the green-to-amber shift. Echo it on a smaller existing inset. | Use a long cobalt block under one vermilion offset edge along the body. | Run a low branch along the body and stop before the suppressor. |
| Bulldog | Colour-shift the large rear-side inset behind the grip. | Hero. Wrap the largest print block over the fixed receiver shoulder. | Bend once around the bullpup shoulder, clear of the rear magazine. |
| Guardian | Use an elongated inset with a distinct dark border. | Put the main print on the long side and echo a short segment on top. | Stretch the main seam along the body, with one short branch near the stock joint. |
| Spectre | A short glossy patch on the main body. | Small overprint on the receiver with clear separation from the suppressor. | Tight split below the top line, stopping before the suppressor. |
| Stinger | Use a single narrow inset on the upper body. | Compact diagonal, one visible misregistered edge. | Short split on the receiver with a small copper tip. |
| Ares | One broad inset on the fixed main shell. | Wide print on the body with a smaller echo at the drum edge. | Large clean branch on the body. Keep the drum motif separate. |
| Odin | Colour shift on a wide shoulder face, away from the feed. | Bold rear-body block with sparse halftone. Use a separate small mark on the box. | A thick read at heavy-gun scale, ending before the feed opening. |
| Sheriff | Compact petrol inset on the frame side. | Wrap one short colour block around the top of the fixed frame. | Hero. Put the fracture along the fixed shroud and frame, clear of the rotating cylinder. |
| Classic | Short reflective strip along the slide side. | A two-colour offset on the slide. Keep dots large enough to read. | A fine diagonal with a tiny branch on the slide. |
| Ghost | One long narrow inset on the slide. | A slim enamel print with a small accent on the fixed suppressor finish. | Run the seam along the slide, ending clear of the suppressor join. |
| Shorty | Compact inset in the fixed side face. | Use one print overlap above the grip. | Keep the fracture on the fixed body, clear of the opening action. |
| Bucky | Single small receiver inset. | Broad core-body print, clear of the pump's travel. | Contain the branch to the receiver. |
| Judge | A broad side inset above the drum. | Strong diagonal blocks on the main shell, sparse accent on the drum. | Branch above the drum and stop at a removable boundary. |
| Marshal | Long controlled reflection on the fore-end face. | Narrow blocks down the fore-end, with the exterior scope finish kept quiet. | Long seam below the stock sightline. |
| Outlaw | Shifting strip on one main body face. | Use the offset print on the fixed body, clear of the break. | Stop the fracture before the break-action boundary. |
| Operator | One broad side inset with matte contrast under the scope. | Long-bodied mark with a dark break before the scope mount. | Main line along the body, keep the scope and lens clear. |

## Material targets

- **Oilwake.** Midnight `#142633`, petrol `#255B57`, green `#408B72`, grazing amber `#CF9955`, matte graphite `#121A22`. The Blender concept uses a view-angle shader. Prototype its appearance in Roblox on the Phantom. If the same colour travel cannot be reproduced in the existing map workflow, preserve the petrol and amber material contrast in the baked finish.
- **Misprint.** Ivory `#ECE3D2`, cobalt `#2447B9`, vermilion `#E5533E`, overprint `#874077`, graphite `#232632`. Keep registration consistent across fixed seams and use static textures. Scale the halftones so they stay legible in first person.
- **Faultline.** Ceramic black `#171B21`, slate `#59616B`, ash facets up to `#AEB2B7`, copper `#C07D57`, copper highlight `#EDAF82`. Put the contrast on one distinct face per host. Scale the ash face and branch to its available space. Make the fracture, facets, and copper entirely in the maps. Use selective roughness and a restrained normal detail where useful.

## Blender MCP handoff · after concept review

1. Connect to **Blender MCP on `127.0.0.1:9999`**, the port for this pass. Verify the tool is targeting that port and query the open scene read-only before edits. The previous connector setting used 9897. Use the stock source `art-source/weapons/RemasterV2/<Gun>/<Gun>_RemasterV2_v05.blend` and `art-source/weapons/ModelSheets/<Gun>_model_sheet.png`. Check the workspace's existing tools and skills before adding dependencies. Start with `.claude/skills/gauntlet-vault/SKILL.md`, `.claude/skills/gauntlet-build-style/SKILL.md`, and the project's texture bake helpers. If a specific task still needs a skill, inspect its source and instructions before installing it through the skill installer.
2. Start with **Misprint Bulldog**, then Oilwake Phantom and Faultline Sheriff. Apply the [Bulldog and Stinger regression checks](Reskin%20Geometry%20Regression%20Checks.md) before the roster bake. Present the first prototype for a look review before running the rest of the roster. Use the three heroes as the material and motif anchors. Bake and review each asset against its own stock render. Keep shape, triangles, moving-part separation, rigs, and locators faithful to stock, with the documented Stinger repair allowed if needed. Preserve existing export UVs where usable and document exceptions. Save versioned copies under `art-source/weapons/Skins/<Line>/<Gun>/`.
3. Read the [skin build pitfalls](Skin%20Build%20Pitfalls.md) and [existing Blender review](Blender%20Review.md). Use the current PBR bake path. Reopen the saved asset and check baked texture padding, registration across fixed seams, clean stops at moving boundaries, render artifacts, and stock dimensions. Compare both profiles, the held view, and applicable ADS. Check geometry, rig and action fingerprints against stock. If an item requires a new export, inspect the reimport for missing faces, inverted normals, and overlapping surfaces before review.
4. Grade each hero out of **100 for Blender evidence**. Award **35** for design and finish, **30** for stock geometry and rig fidelity, **20** for baked texture and seam quality, and **15** for Blender held-view, aim-camera, and motion clearance comparisons. Aim for **90+**. Correct visible defects before presenting. A reproduced glitch or unresolved geometry artifact on either flagged item blocks that item regardless of score. Keep a ledger for all 51 variants and their review statuses.
5. Keep this pass in Blender and on disk while another agent owns Studio. Defer Studio MCP, playtests, uploads, imports, place saves, and runtime changes that could sync into Studio. Mark live ADS, scope hiding, and reload texture visibility as pending for a later Studio pass.

## Concept checkpoint

All 17 stock gun sheets are present. All three hero PNGs were rendered and checked, including the revised Faultline Sheriff. Each concept retained its stock triangle count and geometry fingerprint. Across the three concepts, the lowest silhouette overlap with the stock render was 99.8%, with the residual difference at rendered edges. Next is Misprint Bulldog with the flagged receiver seam check. The two reported defects still need verification against the exact affected versions.

# Structural skin round-one handoff

Build original cosmetic variants for the existing Glitched Gauntlet roster. The first pass targets the Gauntlet gameplay place in Studio test mode. Codex owns the concepts, draft images, pose references, and handoff. The Sol build chat owns Blender production, material baking, and Studio validation. Claude owns custom animation implementation using the pose references and clips supplied by the owner.

## Build queue

The per-line briefs define the shape, finish, sight presentation, ammunition, and optional detail for every item. Use the [design board index](Structural%20Skin%20Design%20Boards.md) to open an item’s stock renders, palette, and original form or material study. Start with the Moltframe Vandal and use the owner-approved prototype as the production reference for its line.

| Order | Line and brief | Hero | Remaining items | Total |
| --- | --- | --- | --- | --- |
| 1 | [Moltframe](Moltframe/concept.md) | Vandal | Spectre, Ares, Moltframe Dagger | 4 |
| 2 | [Slipframe](Slipframe/concept.md) | Guardian | Operator, Classic, Spectre, Vandal, Slipframe Dagger | 6 |
| 3 | [Giltfold](Giltfold/concept.md) | Vandal | Giltfold Fan, Marshal, Stinger, Ghost, Classic | 6 |
| 4 | [Inkshift](Inkshift/concept.md) | Odin | Inkshift Blade, Phantom, Vandal, Stinger, Shorty | 6 |
| 5 | [Sealwork](Sealwork/concept.md) | Marshal | Sealwork Dagger, Vandal, Guardian, Shorty, Sheriff | 6 |
| 6 | [Payload](Payload/concept.md) | Bulldog | Ghost, Vandal, Operator, Ares, Odin, Classic, Stinger | 8 |

The baseline queue is **36 items**, each with a verified stock-based design board. Moltframe Shorty is optional and excluded from that count. Payload has no melee variant. The owner's Ruin Dagger video is pending. Sealwork’s model and idle reference can proceed from stills. Its motion-dependent pose references follow the video.

Save each draft PNG under `vault/02 Art/Skins/<Line>/out/<Item>_v01.png`. Use `Dagger` for the Moltframe, Slipframe, and Sealwork melee sheets in their respective folders, `Fan` for Giltfold, and `Blade` for Inkshift. Increment the version on revision. The queue and linked briefs describe the designs. The draft PNGs are a separate deliverable.

### Supplemental style drafts

| Item | Draft | Stock and draft review |
| --- | --- | --- |
| Moltframe Vandal | [Vandal_v01.png](Moltframe/out/Vandal_v01.png) | [Comparison](Moltframe/out/Vandal_stock_comparison.png). Use the violet channel and alloy finish. Match the stock grip, magazine proportions, and sight placement in Blender. The draft omits the planned ADS and cartridge details. |
| Slipframe Guardian | [Guardian_v01.png](Slipframe/out/Guardian_v01.png) | [Comparison](Slipframe/out/Guardian_stock_comparison.png). Use the material and inlay studies. Verify the aim view from stock. |
| Giltfold Vandal | [Vandal_v01.png](Giltfold/out/Vandal_v01.png) | [Comparison](Giltfold/out/Vandal_stock_comparison.png). Use the folded shapes and foil treatment within the stock model’s size. Verify the generated cartridge and ADS ideas against the brief and the stock model. |

ImageGen rejected the Inkshift Odin, Sealwork Marshal, and Payload Bulldog requests. Their design boards and item briefs provide the input for the corresponding Blender prototypes. A board pairs stock views with a design study. The Blender renders will show the design applied to the full model.

**Status (2026-11-14)** · All 36 items built and graded in Blender; Studio pass deferred by the owner. Results: [Structural Skin Round One Results](Structural%20Skin%20Round%20One%20Results.md).

## Pair each design with the stock renders

- Include the matching `art-source/weapons/ModelSheets/<Gun>_model_sheet.png` with every draft and Blender handoff. Use the stock sheet for existing Gauntlet styling, proportions, and view layout. Include the owner's original renders alongside it as they arrive. Compare stock and skin at matching scale in left profile and in first person.
- Keep the overall length, height, width, and first-person screen coverage close to the host gun. The exterior can taper, slim down, or get a slightly fuller cosmetic shell where it fits the line. Use the stock model to place the muzzle, grip and support hand, stock, sights, magazine, and moving parts. Preserve recognizable profile landmarks and avoid turning a compact gun into a bulkier class visually.
- Treat each generated concept as art direction for colours, material, and shape language. Interpret any panel shape or ornament that conflicts with the stock fit. Take measurements from the Blender source. Use the stock aim camera and a live Studio ADS check for alignment, sight window, reticle, zoom, and screen coverage. Generated ADS crops are rough composition studies.

### Stock render index

For separate image attachments, use `art-source/weapons/ModelSheets/panels/<Gun>/`. The existing exports are `hero.png` for three-quarter, `left.png` for profile, and `held.png` for the held view. `aim.png` is an ADS reference where the sheet labels it as ADS. Some stock sheets use that panel for an above-angle view instead. Use the live gun in Studio to verify aim in those cases. Pair the stock Knife with custom melee sheets for hand posture and first-person scale.

| Stock model sheet | Stock model sheet | Stock model sheet |
| --- | --- | --- |
| [Vandal](../../../art-source/weapons/ModelSheets/Vandal_model_sheet.png) | [Phantom](../../../art-source/weapons/ModelSheets/Phantom_model_sheet.png) | [Bulldog](../../../art-source/weapons/ModelSheets/Bulldog_model_sheet.png) |
| [Guardian](../../../art-source/weapons/ModelSheets/Guardian_model_sheet.png) | [Spectre](../../../art-source/weapons/ModelSheets/Spectre_model_sheet.png) | [Stinger](../../../art-source/weapons/ModelSheets/Stinger_model_sheet.png) |
| [Ares](../../../art-source/weapons/ModelSheets/Ares_model_sheet.png) | [Odin](../../../art-source/weapons/ModelSheets/Odin_model_sheet.png) | [Sheriff](../../../art-source/weapons/ModelSheets/Sheriff_model_sheet.png) |
| [Classic](../../../art-source/weapons/ModelSheets/Classic_model_sheet.png) | [Ghost](../../../art-source/weapons/ModelSheets/Ghost_model_sheet.png) | [Shorty](../../../art-source/weapons/ModelSheets/Shorty_model_sheet.png) |
| [Marshal](../../../art-source/weapons/ModelSheets/Marshal_model_sheet.png) | [Operator](../../../art-source/weapons/ModelSheets/Operator_model_sheet.png) | [Knife](../../../art-source/weapons/ModelSheets/Knife_model_sheet.png) |

## Start in Blender

1. Connect through **Blender MCP on `127.0.0.1:9897`** and confirm access by querying the open Blender scene. This port was listening and a read-only MCP query succeeded during handoff preparation. Check the current scene before loading or appending assets. Locate the `gauntletgame` Studio session, place ID `133387545285290`. Start with Moltframe Vandal. Use the [style comparison](Moltframe/out/Vandal_stock_comparison.png), [design board](Moltframe/out/Vandal_stock_design_board.png), stock [model sheets](<../../../art-source/weapons/ModelSheets/README.md>), and `art-source/weapons/RemasterV2/Vandal/Vandal_RemasterV2_v05.blend`. Use Blender MCP for the Blender work and review capture.
2. Work in named versioned skin variants. Preserve stock files and exports. Modify visible cosmetic shells while keeping the host identifiable. Preserve the host’s gameplay, pivots, moving-part travel, hand contacts, stock gun animation clips, sight alignment, and feed shape. Compare the cosmetic shell at first-person scale during idle, ADS, reload, and inspect. Use the guns’ per-item notes to choose finish placement and clearance checks.
3. Check the current export and texture bake pipeline before choosing how to import. See [the first skin batch’s Blender and Studio handoff](Blender%20and%20Studio%20Handoff.md) for repository entry points. Where a motion idea is listed, start with the documented static finish and test the optional texture separately on one hero. Keep Giltfold and Payload textures static.
4. Reuse the Gauntlet Studio-only test selector if present. Add the new entries through the existing path and verify stock fallback when the selected line lacks a variant. Cover held and world models. Keep this pass in the Gauntlet gameplay place. Main-lobby equipping, inventories, and public loadout changes are outside this pass.
5. For melee cosmetics, prepare meshes and grip or hinge references for Claude and capture the stock hand posture in context. Moltframe and Slipframe aim to reuse stock Knife clips, with a cosmetic hold offset if needed. Giltfold needs closed and open fan states and a bottom pivot. Inkshift needs a long-blade pose reference. Sealwork needs the pending dagger video for its custom motion notes. Keep existing melee gameplay and contact timing.

Keep a build ledger with each item’s Blender source, texture paths, Studio validation, and next item. Report any missing input and continue with independent items. Deliver versioned variants, textures, Studio preview captures, and the ledger.

## First rifle review and owner approval

Build only Moltframe Vandal for the first delivery. Give the graphite alloy pale, sharply lit folds and expose the purple inset on the player-facing side. Bring the render into the same lighting and camera setup as the stock gun. Use the same scale in the profile and the same viewmodel camera in the held and ADS captures. Include a close-up of the alloy and fluid, a reload or inspect capture for moving-part clearance, and a Studio screenshot of actual ADS. If a Studio check is blocked, name the missing evidence and show what Blender verified.

Grade the actual result out of 100 and attach evidence for each score.

| Points | Check |
| ---: | --- |
| 30 | Look and finish. The original plate language and violet chamber read at gameplay size, with convincing separation between alloy, grip, and inset. |
| 25 | Stock fit. Compare length, height, width, profile landmarks, and held screen coverage at the same scale. Call out meaningful cosmetic deviations. |
| 20 | ADS and animation clearance. Check live sight alignment and visibility, stock hand contact, and clearance during reload and inspect. |
| 15 | Craft. Check shading, UVs, material transitions, texture seams, and export readiness. |
| 10 | Evidence. Include the matching renders, Studio result, known gaps, and versioned files. |

Target **90/100 or higher**, with no critical fit, ADS, or clipping issue. Fix recoverable issues before review. Report any unverified check explicitly and grade only on evidence. Present the final comparisons and score to the owner, then stop for explicit approval of the look. Resume the documented queue only after approval. Keep the same quality checks on the remaining items.

## Paste into the new Sol chat

> Read `vault/02 Art/Skins/Structural Skin Round One Handoff.md`. Connect to Blender MCP on `127.0.0.1:9897`, verify the connection, and use MCP to build and review Moltframe Vandal first. Use the stock Vandal model and renders for scale, fit, and ADS. Use the saved concept for styling. Validate in the Gauntlet gameplay place `133387545285290` using the Studio test selector. Send me matched stock and skin renders, actual Studio ADS evidence, and an honest score out of 100 against the handoff rubric. Fix recoverable issues and aim for 90 or higher. Stop for my explicit approval of the look before starting another item. After I approve, continue the queue and keep the same checks. Claude owns custom animation implementation.

# Blender and Roblox Studio handoff

Build the first four cosmetic skin lines for Glitched Gauntlet. The 71 concept sheets are ready as production references. Use their colour roles, graphic placement and stock geometry. Push the finish and contrast beyond the soft grey-sheet renders so the designs read at normal first-person size in Roblox Studio.

## Inputs

- Read [Concept Sheet Queue.md](Concept%20Sheet%20Queue.md) for the current PNG per item. Read each line’s `concept.md`, `prompt.md`, and `refs/` under `vault/02 Art/Skins/`. The palette and finish tables in `concept.md` govern the pass. The old text-only direction checks are superseded.
- Use `art-source/weapons/ModelSheets/<Item>_model_sheet.png` for the stock views and `art-source/weapons/RemasterV2/<Item>/<Item>_RemasterV2_v05.blend` for source geometry. Keep the stock files and exports intact. Work on named skin variants.
- Inspect the existing export and build flow before choosing where to store the variants. Start with `tools/blender/bake_textures.py`, `tools/studio/make_build_data.py`, `tools/studio/rojo/WeaponBuilder.luau`, and `src/server/WeaponBuild/WeaponBuilder.luau`. Confirm which path serves the current models and whether their UVs can support the decals. The repo already has a PBR map path for eligible parts. Keep any new UV work confined to the skin assets.

## Gauntlet Studio test mode

- Work in the Gauntlet gameplay place. Use the existing Studio dev or test-range flow for this pass. Keep the main lobby, player inventories, saved loadouts, and public equip flow outside the scope.
- Add one Studio test setting for the session with five values: Stock, Prism, Redline, Nitrous, and PopCircuit. Default to Stock. Use the selected line for every gun that has a built variant in that line. Fall back to that gun’s stock appearance when a variant is missing. Switching lines or returning to Stock should clear the previous appearance from held and world models. Apply the same resolution when a gun spawns or is picked up.
- Reuse the Studio-only guard and existing dev controls or config where practical. The shared TestMode flag can also apply to published servers, so gate this preview setting to Studio itself. Verify with two guns that have variants and one that falls back to stock while the roster is still in progress.
- In the melee slot, use the Prism or Redline stock-Knife reskin when available. Use the stock Knife for Nitrous and for any unfinished melee variant. Use the custom Bat for PopCircuit once its rig and poses are ready for the test.

## Start with Prism Vandal in Studio

1. Connect to Blender and open the stock Vandal. Use `Prism/out/Vandal_v01.png` for colour placement and the Prism references for the level of gloss. Build an isolated texture and material variant and bring it into the Gauntlet Studio test range through the project’s current import path. Use it to prove the line selector and stock fallback before building out the roster.
2. Give the magenta Body and plum Panel a lacquer-like finish. Start with shell roughness around 0.12–0.22, then tune against the Studio result. Keep the grip and dark polymer matte. Make the long pale-pink left-side reflection break cleanly at the existing receiver-to-handguard seam. Use actual specular response for the moving shine. A restrained pink band in the texture can reinforce the signature where the lighting is flat.
3. Capture the skin alongside the stock Vandal at the same camera angle and exposure. Check first-person idle, inspect, ADS, reload, and a world view. Tilt the model under a clear highlight in the review scene, then test it under representative map lighting and typical graphics quality. Check `Lighting.EnvironmentSpecularScale` if the surface reads flat. Keep lighting experiments in the review scene. Judge whether the magenta stays saturated, the reflection travels across the glossy faces, and the matte grip still reads as a different material.
4. Use that Studio result to set the production finish before propagating the same material setup across Prism. Continue through the roster without per-item approval pauses. Work in the queue order, hero first for each line. If Studio or import access blocks a check, record the exact gap and continue the work that can be verified locally.

## Line targets

| Line | Hero | What should read at gameplay scale |
| --- | --- | --- |
| Prism | Vandal | Glossy saturated magenta, deep plum and near-black. A pale-pink reflection breaks at the stock seam. |
| Redline | Phantom | A broad charcoal-to-muted-crimson gradient with distinct matte black, subtle dry grain, and a thin left-side drafting line with one right-angle step and two ticks. The grain should stay quiet while the gradient and line remain legible. |
| Nitrous | Vandal | Satin black paint against visibly brushed silver, electric-blue wedges, and a crisp hot-orange burst. Register the graphics across fixed panel seams and terminate them at moving parts. |
| PopCircuit | Guardian | Use `PopCircuit/out/Guardian_v02.png`. Keep the electric blue, pink, and violet distinct. Make the bubble and three cyan sparkles readable on a clear left-side face. Use a slight sheen difference for the vinyl, with restrained halftone and speed marks. Use original abstract art. |

## Asset and gameplay checks

- The 68 gun variants and the two stock Knife variants are surface-only work. Preserve mesh shape, scale, part hierarchy, pivots, attachments, rigs, animations, sight pictures, ammunition, magazines and feed geometry. Keep the stock charm mounts empty. Check seams and decals in both the equipped and world views, including during reload or inspect where applicable.
- Author the colour, roughness and metalness per role. Use normal detail where it supports the stock surface. Bake into the project’s UV layout with adequate padding for clean seams at gameplay distance. Keep scope glass, ammunition, and existing sight details intact. Restrict the line’s glow colours to the stock small strips or dots.
- The custom PopCircuit Bat is the only new model. Use `PopCircuit/out/Bat_v01.png` for the barrel, original vinyl, wrap and cyan cap. Work in the Knife slot with its own right-hand primary pivot near the knob and separate left-hand support anchor toward the barrel. Prototype idle, alternating one-handed light slashes, a two-handed downward right-click smash, and a raise-and-turn inspect. Use a short blue, pink and violet trail on the two light slashes. Check hand contact, clipping, and visibility in the actual rig. Preserve the stock Knife as its own asset.
- Keep a build ledger with the variant, source file, texture paths, Studio status and exact next item. Deliver versioned Blender assets and texture sets, Studio preview captures, and the ledger. Use local or private review assets for the Studio pass.

Roblox references for the Studio checks. [PBR textures](https://create.roblox.com/docs/art/modeling/surface-appearance) · [SurfaceAppearance](https://create.roblox.com/docs/reference/engine/classes/SurfaceAppearance) · [Lighting](https://create.roblox.com/docs/reference/engine/classes/Lighting)

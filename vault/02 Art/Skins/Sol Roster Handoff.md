# Sol handoff — finish the skin roster in Blender

## Owner's latest instruction (2026-11-12)

> I'm going to dinner. Keep working through every gun we need; don't stop for approval on each item. The Prism Vandal looked good when I tested it. Keep usage sensible and don't over-test. Claude is using Studio, so leave Studio alone for now. Finish the Blender assets and review them there first; once the Blender work is approved, we can go into Roblox Studio and test.

Treat this as a request to **execute the remaining roster work**, not just make a plan. Continue independently through the queue, record completed assets and exact gaps, and provide a review package at the end. Do not wait for dinner to finish or ask routine per-gun questions. If an external step is blocked, finish the independent local work and record the blocker.

## Scope and boundaries

- Four lines: **Prism, Redline, Nitrous, PopCircuit**. The concept queue has 71 items: 68 gun skins, Prism and Redline stock-Knife reskins, and the custom PopCircuit Bat. Prism Vandal is already built; **70 items remain** (67 guns, two knives, one bat).
- **Blender/local work now. No Studio MCP calls, play/stop, uploads through that session, camera changes, source hot-swaps or place saves while Claude is using it.** Local changes to Rojo-owned runtime files can hot-sync into the occupied session: defer runtime changes too.
- Later Studio work must be in `gauntletgame`, gameplay place **133387545285290**, never lobby place **71551303511506**. Re-list sessions when resuming; old session IDs may expire.
- Preserve stock geometry, UVs where practical, material-role boundaries, hierarchy, pivots, attachments, rigs, sights, rounds, magazines/feed geometry and existing animations for all reskins. Stock files/exports stay intact. No charms or unrequested visual effects.
- The Bat is the only new model/rig/poses. Read the original handoff for its right-hand pivot, support anchor, two light swings, two-handed smash, inspect and short trails. Prepare the Blender asset and pose checks now; leave runtime slot/animation/trail integration for the later Studio phase.
- No main-lobby changes, inventories, saved loadouts, public equip flow or publishing changes.
- This checkout has extensive unrelated work from Claude/the owner. Do not reset, revert, bulk-format, commit or push unrelated files. Use targeted edits and versioned output directories.

## Read first

1. `CLAUDE.md` and `.claude/skills/gauntlet-vault/SKILL.md`; use the project vault/LihFolk guidance proportionately.
2. [Blender and Studio Handoff](Blender%20and%20Studio%20Handoff.md) — production requirements; the owner's latest Studio pause above overrides its immediate-test sequence.
3. [Concept Sheet Queue](Concept%20Sheet%20Queue.md) — authoritative current PNG per item. Concept completion is not model completion.
4. Each line's `concept.md`, `prompt.md`, `refs/` and current `out/` image. Inspect the images, not just their filenames. Palettes/finish tables govern each line.
5. [Prism build ledger](Prism/Build%20Ledger.md) for exact existing work, asset IDs and honest verification limits.

## Already finished: Prism Vandal v01

- Source: `art-source/weapons/RemasterV2/Vandal/Vandal_RemasterV2_v05.blend`.
- Saved variant: `art-source/weapons/Skins/Prism/Vandal/v01/Vandal_Prism_v01.blend`.
- Four 1024² maps: `v01/textures/Vandal_Color.png`, `Vandal_Normal.png`, `Vandal_Roughness.png`, `Vandal_Metalness.png`.
- `v01/manifest.json` records source, structural hash, role values, actions and output paths; `bake.log` confirms successful bake/save. `textures/assets.json` records four approved image IDs, group **11116787**. **Do not re-upload these.**
- Author/build recipe: `tools/blender/build_prism_vandal.py`. It preserves the shared UV atlas, reuses `tools/blender/bake_textures.py`, overrides output location and reduces AO/edge wear. It is Vandal-specific, not a finished roster generator.
- Body `#C62878`, roughness **0.16**; Panel `#541438`, **0.20**; Dark `#15141A`, **0.78**; Grip `#211E27`, **0.88**. Painted lacquer is dielectric, metalness 0; exposed Metal/Accent use 1. Do not turn the paint into chrome to fake gloss.
- A restrained pale-pink underprint reinforces the left-side signature, cut at the existing receiver/handguard seam. Dynamic gloss comes from PBR. Keep that approach, adapting to each gun's actual surfaces; never blindly reuse Vandal's coordinate mask.
- The owner says the Studio result looked good. **Keep this as the Prism baseline; don't spend dinner rebuilding or repeatedly testing Vandal.**
- Important live-file trap: the live Blender session may still have the earlier pre-bake state in memory. The on-disk `.blend` is baked and saved. Reopen the disk variant before edits; do not overwrite it by saving stale memory.

## Already implemented: roster-wide preview selector

Files:

- `src/shared/Config/SkinPreview.luau`: five values, F7, gameplay place ID and request interval.
- `src/shared/SkinPreview.luau`: resolve variant/stock, copy surface-only appearance, watch new models/parts.
- `src/server/Services/SkinPreviewService.luau`: Stock default per play session, validated/rate-limited remote, world appearances.
- `src/client/Controllers/SkinPreviewController.luau`: F7 / Shift+F7 and status label, camera model appearances.
- `src/shared/Net.luau`: adds the preview remote only in Studio and the gameplay place.
- `tools/studio/InstallPrismVandal.luau`: clones the installed stock Vandal into `ReplicatedStorage.WeaponSkins.Prism.Vandal`, adds 32 PBR surfaces and changes three Neon parts. Brass and rear aperture remain stock. Refuses to overwrite an existing variant.
- `tools/studio/ValidateSkinPreview.luau`: disposable-clone appearance/structure/restoration check.

The only session setting is server-owned `Workspace.PreviewSkinLine`: **Stock, Prism, Redline, Nitrous, PopCircuit**. Missing variants fall back to that weapon's stock model. New variants belong at `ReplicatedStorage.WeaponSkins.<Line>.<WeaponId>` with `SkinReady=true`, `SkinLine` and `SkinVersion`. Source stock templates stay in `ReplicatedStorage.Weapons` and must stay unchanged.

Server handles world-model surfaces; client handles camera WorldModels to avoid duplicate replicated SurfaceAppearances. Runtime swaps clone preconfigured surfaces because map properties require Studio preprocessing. Do not rebuild a held model to change lines or restart its animation.

Checks already passed: Selene and Rojo build; all five line resolutions on Vandal and Classic; exact return-to-Stock appearance; unchanged mesh IDs, transforms, size, pivots, attachments and joints on disposable clones. Play mode confirmed Stock default and Prism remote selection on the first-person Vandal. F7 physical input still needs a later quick check; synthetic key input didn't establish a switch.

## Work order while the owner is away

1. **Prism Phantom next**, then the remaining Prism queue order through Knife. Use the accepted Vandal finish while respecting each sheet's placement.
2. **Redline Phantom hero**, then remaining Redline queue. Broad charcoal→muted-crimson gradient, separate matte black, restrained dry grain, thin left drafting line with one right-angle step and two ticks.
3. **Nitrous Vandal hero**, then remaining Nitrous queue. Satin black, brushed silver, electric-blue wedges, hot-orange burst; register across fixed seams and stop at moving boundaries. Stock Knife fallback for this line.
4. **PopCircuit Guardian hero**, using `Guardian_v02.png`, then remaining PopCircuit queue and Bat. Electric blue/pink/violet, readable bubble and three cyan sparkles, modest vinyl sheen, quiet halftone/speed marks. Original abstract graphics only.

Use source `art-source/weapons/RemasterV2/<Item>/<Item>_RemasterV2_v05.blend` and `art-source/weapons/ModelSheets/<Item>_model_sheet.png`. Store each variant under `art-source/weapons/Skins/<Line>/<Item>/v01/`, with `<Item>_<Line>_v01.blend`, texture set and manifest. Increment versions when changing an already delivered variant.

## Efficient build and review

- Generalize the existing author/bake wrapper as needed, not the stock exporter. Keep all edits confined to skin assets and tooling during the Studio pause.
- Inspect material assignments and actual UV coverage before batching. Vandal's atlas was verified shared with zero inter-object overlap; large per-object UV bounds alone do **not** mean overlapping atlases. Preserve usable UVs; isolate any necessary new UV layout in the skin asset.
- Bake with existing PBR helpers where practical. Normal = OpenGL tangent space; roughness/metalness = Non-Color; color = sRGB. Keep padding and ensure color survives mipmapping at first-person scale.
- Do not assume global shader coordinates make a registered pattern on every weapon. Check seams and moving parts per asset. Preserve ammunition/lens/sight details separately.
- Keep geometry/UV/rig fingerprints, five-action availability where present, source path, texture paths, version, build status and exact next item in manifests/ledger.
- Use modest-size grouped Blender contact sheets for first-person, left/right and critical details. Inspect each result once; only re-render when a defect warrants it. No repeated exhaustive animation testing of unchanged rigs.
- Finish all independent assets rather than stopping at the first blocked item. Record specific defects/blockers. Do not label unfinished Bat rigging or failed bakes as complete.
- End with a consolidated Blender review package and completion table for all 71 entries, identifying the already accepted Vandal and the 70 new items. Owner Blender approval is the gate to the later Studio phase; don't invent approval for the whole roster.

## Later, when Studio is available and Blender work is approved

- Coordinate with the owner/Claude before taking control. The prior run left play mode active; its state may now be entirely different. Do not stop it based on this stale handoff.
- Confirm the installed Prism template still exists and whether the gameplay place has been saved. **Place save and a serialized Prism `.rbxm` backup were not confirmed.** Reproduce missing installation from the script and existing IDs if needed; do not re-upload unchanged stock meshes.
- Upload only new finalized texture maps to the game-owning group. Studio MCP Open Cloud authentication already worked without environment-variable credentials. The owner approved `art-source` as the upload directory. Discover current permissions/session state rather than assuming they persist.
- Reuse mesh IDs/rigs by cloning the installed stock model for reskins. New mesh import is only needed for changed UVs or the Bat. Extend the installer to read manifests and preserve functional parts. Keep per-line templates isolated.
- One short smoke test: Prism Vandal plus a second built variant and a missing-variant fallback; Stock→line→Stock on held and world guns; new spawn/reparent; F7. There is currently no gun pickup implementation in source, so do not claim an end-to-end pickup test or build unrelated pickup gameplay.
- Capture matched-angle Stock/Prism views and spot-check idle, inspect, ADS, reload. These were not completed by the assistant in milestone 1. The immediate assistant Prism capture was white during unresolved loading/setup, then the owner later reported a good result; retain that distinction.
- Check the moving lacquer highlight and seam under representative map lighting at normal first-person scale. Observed `EnvironmentSpecularScale` was 0.2. Do not globally alter map lighting to flatter a skin; keep lighting experiments in a temporary review scene.
- Save the gameplay place with the owner's authorization and serialize skin-template backups. Keep default Stock; leave live inventory/equip/loadout systems alone.

## Completion message

Report completed/remaining counts, links to Blender review sheets and files, source/texture integrity checks, defects requiring review, and next Studio steps. Keep it brief. Update each line's build ledger and this queue status so the owner can resume without rereading chat. No fabricated Studio verification.

## Blender roster build

**2026-11-12** · 70 new variants ready for Blender review · 1 previously accepted · 0 remaining

[Completion table and Blender review sheets](Blender%20Review.md).

**Next step.** Owner review of the Blender sheets, then confirm Studio is available for the gameplay-place smoke test.

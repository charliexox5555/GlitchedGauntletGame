# Opus handoff: Vandal first, weapon art reset and fresh rebuild

> **Superseding update (user, 2026-11-07, during the Opus session):** the Vandal review gate is lifted. The user said Opus should grade each weapon itself and, if it is good, move on to the next one without waiting for review. Progress, self-grades and files: [Weapon RemasterV2](Weapon%20RemasterV2.md).

**Updated 2026-11-07. Recipient: Claude Opus. Ready for handoff; not yet delivered to Opus. The entire first Codex remaster is rejected. No Vandal rebuild was performed in the Codex connection-check session.**

Project root: `C:/Users/charl/Documents/GauntletGame/GlitchedGauntletGame/`.

The user has transferred the modeling work to **Opus using Blender MCP**. The historical filename is retained so existing links still work. The user explicitly authorized starting the Vandal directly from the original concept and written requirements because a new concept sheet could not be generated. **Do not wait for a new generated concept. Build Vandal, present the saved model and review images, then stop for the user's visual review. Do not start Classic or apply this direction to the rest of the roster before that review.**

These instructions supersede older concept-first gates, permission to use isolated/background Blender workers, the old `Remaster/` destination, and instructions to continue automatically through the whole roster. The wider roster below is future context, not authorization to skip the Vandal review gate.

## Current state and Blender MCP connection handoff

- Codex repeatedly searched its available tools and had no Blender MCP scene-inspection, screenshot or Python-execution tools exposed. It did not make a Blender MCP call, inspect the live scene, create a rebuild scene, run a model script, render, save a `.blend`, or modify any weapon asset. No Blender lock was acquired by this session.
- Read-only local checks found `[mcp_servers.blender]` enabled in `C:/Users/charl/.codex/config.toml`, using `C:/Users/charl/.local/bin/blender-mcp.exe`; that executable existed. The configured endpoint was `localhost:9876`, and a Blender process was listening on `127.0.0.1:9876` at the time of the check. This proves configuration and a listener, **not** a successful MCP handshake. Recheck from Opus; do not assume Codex's missing-tool problem applies to your session.
- The user supplied a Blender screenshot showing `* (Unsaved) - Blender 5.2.2 LTS` with Camera, Cube and Light. This is a historical screenshot, not a current scene audit. Treat the interactive session as containing unsaved user work until inspected.
- The Vandal `RemasterV2` folder contained only `chatgpt-concept-prompt-v02.md`, `concept-prompt-v01.txt`, and `concept-status.json` before this handoff update. No new concept image or Vandal `.blend` was present there at that check. Any existing `Remaster/Vandal/` model and renders belong to the rejected earlier pass.
- The user said: “Opus will model these” and asked for the complete handoff. No identifiable Opus destination was available in Codex's chat list, so this document is prepared for the user to pass to Opus; do not claim it has been delivered or that Opus has started.

## Mandatory execution method and first actions

1. Follow the project vault workflow in `CLAUDE.md` and `.claude/skills/gauntlet-vault/SKILL.md`; consult the relevant LihFolk modeling guidance through the local router/lookup as available. Read narrowly. The user's constraints in this handoff override older generic git, export and background-worker instructions.
2. Check `.claude-locks/blender.lock` before accessing the shared session. Never use a tool held by another owner. The project procedure records owner/lane and time, uses roughly 15-minute work windows, and treats a lock younger than 20 minutes as occupied. Do not delete another owner's lock merely because it is old; establish ownership/release first. Acquire your own lock for Blender work, recheck ownership before writes, and release only your lock when you finish or stop. Sources: `vault/04 Tech/Codex Collaboration.md` and `vault/05 Production/Archive/Overnight 2026-11-04.md`.
3. **First verify Blender MCP by inspecting the current live scene and obtaining a viewport screenshot through MCP.** Record current filepath, dirty/unsaved state, scenes, collections and active scene. If MCP is unavailable or either check fails, stop and explain what needs connecting. Do not substitute another execution method.
4. Use Blender MCP for all scene inspection, modeling, materials, cameras, viewport inspection, renders and saving. Python executed through MCP **inside the connected visible interactive Blender session** is allowed. **No headless/background Blender, `blender -b`, subprocess Blender, command-line rendering or separate automated Blender worker.** Filesystem tools may read project documents/scripts and manage handoff notes/locks; they must not perform Blender operations outside MCP.
5. Preserve the live scene and all unsaved work. Create a separate named scene, such as `Vandal_RemasterV2_Review`, with independent data for the rebuild. Do not clear the startup scene, mutate shared materials/meshes from the user's scene, or switch/open files blindly. If safe preservation and saving cannot be achieved without endangering unsaved work, stop and describe the specific conflict.
6. Read this handoff, `art-source/weapons/RemasterV2/Vandal/chatgpt-concept-prompt-v02.md` (design requirements only; its concept-first gate is superseded), `vault/02 Art/Art Direction.md` (especially the model/code contract), and `vault/05 Production/Codex Gun Remaster Brief 2026-11-07.md` (historical requirements; its results are rejected).
7. Visually inspect the four reference images listed below. Then inspect the original `art-source/weapons/Vandal.blend` through MCP without replacing or damaging the live session, and read `tools/blender/build_vandal.py`, `tools/blender/anim_vandal.py`, and relevant `gunkit.py` helpers to establish actual dimensions, bone/locator names, axes and timing before rebuilding. Read the scripts as references; the old builder deletes/replaces existing objects and reuses global materials, so do not blindly execute it in the user's session.

## Required reference images

- `vault/02 Art/References/vandal-concept.webp`: primary positive design reference; preserve its identity.
- `vault/02 Art/References/vandal-blender-check.jpg`: shows the original concept versus the thin, weaker execution; use to identify the gap.
- `vault/02 Art/References/ads-refs/rivals-ring-sight.webp`: sight-picture readability reference.
- `vault/02 Art/References/ads-refs/open-irons-ring-aperture.webp`: slim open aperture and visible target reference.

Do not infer visual quality from filenames or scripts. Open the images and use actual MCP viewport screenshots throughout modeling.

## What the user is asking for

Recreate all 17 guns and the Knife as professional, characterful game assets in Blender through Blender MCP. Skip Akimbo. The target remains original stylised hero-shooter art: **Valorant-level craft and detail with RIVALS readability**. The user wants attractive shapes, carefully designed corners, convincing materials and precisely integrated parts.

**Latest clarification:** the user likes the **original generated Vandal concept image**, `vault/02 Art/References/vandal-concept.webp`. That image is the primary positive art-direction reference. The original Blender model did not execute it well enough: it was too thin, needed better moving/attachment parts, and had poor ADS visibility. Preserve the concept's identity while rebuilding the geometry and improving the implementation. The user is not asking to replace that idea with an unrelated silhouette.

The user also said the original weapons looked better than the attempted remaster. The rejected remaster is not the new baseline and is not a set of approved assets to polish slightly. `vandal-blender-check.jpg` is useful for comparing the original image with its weaker model execution.

The reset means a fresh design/modeling pass. Preserve the original weapon files and the user's work. The failed output is marked rejected for traceability; it has not been physically erased.

## Direct feedback to resolve

- The guns lack life, character and the finish expected in an actual professional game.
- They are too simple. There is too little purposeful shape and surface detail.
- The corners, transitions and textures do not have the desired quality.
- The magazines look wrong, and their connections to the receivers are unconvincing.
- The weapon buddy/charm mounting areas look wrong.
- The sights look bad.
- The cocking/charging area looks bad. Interpret this as the charging handle, bolt/slide, ejection opening and surrounding receiver assembly.
- The parts and geometry do not look precise or deliberately designed.

The earlier pass leaned heavily on a shared parametric template: long box-like receivers, repeated stock cut-outs, rectangular magazines, plain raised sights and thin decorative panels. That approach removed much of the original weapons' identity. **Do not run or lightly retune `Remaster/_Library/remaster.py` to produce the replacement set.** Shared materials are useful; each weapon needs its own designed construction and silhouette.

## Concept status: direct modeling is authorized

The proposed new concept destination was `art-source/weapons/RemasterV2/Vandal/concept-direction-v01.png`; no new image was produced. Do not spend this modeling task retrying image generation. Model directly from the original concept and the requirements below. The resulting model remains pending the user's visual review.

**Latest prompt:** `art-source/weapons/RemasterV2/Vandal/chatgpt-concept-prompt-v02.md` supersedes the first prompt. It anchors the refinement to the original Vandal concept, preserves that concept's curved magazine, vented handguard, shaped stock and dark finish, and adds volume, an animatable trigger, integrated charm/charging details and readable open sights. The user requested this paste-ready prompt for a separate ChatGPT image-generation session.

**Current concept status:** the built-in image generator rejected the first new concept request at its output filter and returned no image; details are preserved in `concept-status.json`. No alternative API route was used by this session. The user subsequently authorized direct modeling without a new concept. Do not substitute a rejected first-pass render as the new concept or describe the unbuilt refinement as approved.

The model's review images must show one consistent Vandal design in:

1. A large front/side three-quarter hero view, with the entire weapon visible.
2. A clean full side view, so the silhouette and connections can be judged.
3. A magazine close-up showing its shaped body, baseplate and seated connection to the magazine well.
4. A receiver close-up showing the charging assembly and the surrounding designed surfaces.
5. A sight close-up and a clear aim-down-sights picture.
6. A charm-mount close-up showing a small, integrated, physically connected attachment.

Also include a small front or top view so the increased width can actually be judged. The receiver, grip, handguard and magazine need solid volume in first person, with the original silhouette preserved.

Refine the recognizable identity in the original concept: its receiver, vented handguard, curved magazine and shaped stock. Give it substantial volume, a distinct trigger designed for independent animation inside the guard, and a magazine designed together with its well. Balance broad skin-ready surfaces with meaningful medium and small details. Keep the views consistent; avoid inventing a different magazine or sight in each inset.

After the user reviews the Vandal direction, let its **finish, detail density, corner treatment and material language** guide the family. Preserve distinct silhouettes and mechanisms for the other guns. A pistol, SMG, shotgun and sniper should each look purpose-built.

## What professional finish means here

### Shapes and corners

Design the silhouette and major volumes before adding details. Model the receiver's changes in section, its shoulders, purposeful recesses, transitions into the handguard and stock, and the grip's relationship to the frame. Use deliberate chamfers and controlled radii, with bevel size appropriate to each part. Large corner transitions and small edge breaks serve different purposes. A bevel modifier on an otherwise plain box does not complete a part.

Use a clear hierarchy: strong primary volumes, coherent secondary assemblies, and restrained small details such as catches, fasteners, seams, inset vents and grip patterns. Every detail should explain the design or improve its visual rhythm. Avoid filling blank areas with arbitrary lines, repeated strips or excessive rail teeth.

### Magazines and seating

Design the magazine and magazine well together. The loaded magazine must visibly enter a receiving opening and seat with a coherent lip, neck and latch relationship. Its curvature, taper, thickness and baseplate should suit the weapon. Show a convincing junction from both sides and underneath. Keep ammunition contained appropriately in the seated state; avoid stray rounds appearing to float above an external magazine.

Prove the fit with close-up rest-pose and reload views. Check that the moving magazine clears the well, leaves the weapon cleanly, and returns to the same seated position. A technically valid `Mag` bone is not a visual fit check.

### Charging assembly and receiver

Give the charging handle, bolt/slide, surrounding recess and ejection opening coherent geometry. Handles need a visible mounting relationship, room to move, and a shape that belongs to the receiver. Avoid a floating cuboid or a silver plate pasted onto a flat wall. Inspect the assembly in rest, retracted and returning positions. Resolve clipping, gaps and exposed internal props.

### Sights

Design the sights as finished assemblies, with small intentional housings, clean support geometry and a convincing connection to the weapon. Keep the sight line clear. Avoid tall generic posts, bulky identical blocks and arbitrary risers. Choose a sight that suits the weapon and show its actual ADS view. Scopes need coherent eyepieces, tubes, objectives, mounts and aligned attachment points.

For the Vandal pilot, use `ads-refs/rivals-ring-sight.webp` and `ads-refs/open-irons-ring-aperture.webp` as visibility references: a slim open aperture/ring, an aligned small front post and generous central visibility at the actual eye position. The user's reference to Valorant/RIVALS concerns first-person aiming readability. Do not copy another game's weapon design or replace the original Vandal identity with the enclosed reflex optic proposed in the superseded v01 prompt.

### Buddy/charm mount

Integrate a small anchor or loop into a sensible part of the weapon. Give it a visible supporting base and believable clearance for the charm. It must appear attached in close-up and remain correctly attached during animation. Avoid an oversized square floating beside the receiver or trigger guard.

### Materials and textures

Make the finish attractive through intentional material separation: painted/coated body, satin exposed metal, polymer, grip treatment and restrained accents. Use subtle, controlled roughness and tonal differences, designed grip texture, clean edge highlights and readable recesses. The user wants clean stylisation with surface quality and character.

Keep grime, stochastic stains, photo scratches and noisy surface breakup out of the default finish. Also avoid uniformly flat plastic across every part, broad unrelated colour slabs and chrome-like lighting that washes out the design. Material and geometry quality must hold up in neutral lighting and at first-person distance.

## Sources and protected work

Read:

- `vault/05 Production/Codex Gun Remaster Brief 2026-11-07.md` for the roster, original production requirements and animation/attachment contract. Its completion rows describe a **rejected** pass; passing audits did not establish artistic approval.
- `vault/02 Art/Art Direction.md`, especially the model/code contract at lines 24–57.
- `src/shared/Config/Weapons.luau` as the authoritative roster.
- `art-source/weapons/<Id>.blend`, the original `tools/blender/build_<id>.py` and `anim_<id>.py`, `gunkit.py`, and the original textures and reference renders.

**Never overwrite the originals. Never modify `art-source/weapons/GunTest.blend` or the user's existing unsaved scene.** Do not change game code, open Roblox Studio, upload or import assets, or perform git operations. Use the Blender lock and the live interactive MCP method above; an isolated/background worker is explicitly prohibited.

Save fresh work under `art-source/weapons/RemasterV2/<Id>/`, with shared material/reference assets under `RemasterV2/_Library/`. Keep rejected Remaster files and exports out of the replacement package.

## Production order and roster

**Current task: Vandal only, then stop for review.** After explicit user approval, the planned next pilot is Classic, followed by the remaining roster. The full eventual scope is 17 guns plus Knife, excluding Akimbo.

| Class | Assets |
|---|---|
| Rifles | Vandal, Bulldog, Phantom, Guardian |
| SMGs | Stinger, Spectre |
| Sidearms | Classic, Shorty, Ghost, Sheriff |
| Shotguns | Judge, Bucky |
| Snipers | Marshal, Outlaw, Operator |
| Machine guns | Ares, Odin |
| Melee | Knife |

## Keep the game contract while rebuilding the art

- Preserve IDs, original grip origin, +X forward/+Z up, and 1 unit = 1 stud. Blender-to-Roblox mapping is `(−y, z, −x)`. Keep overall dimensions near the originals; increase thickness with purpose.
- Keep the original bone names and parent moving pieces correctly, with pivots at their actual joints. Preserve event names and approximately the original clip durations.
- Preserve `Muzzle`, `RightGrip`, `LeftGrip`, `AimPoint`, `Eject`, `CharmPoint`, attachment sockets and each weapon's extra locators. Align them to the rebuilt geometry, bore and sight line.
- Use the shared material roles `Body`, `Panel`, `Dark`, `Metal`, `Grip`, `Accent`, `Neon`, with independent neon meshes and `<Part>_<Role>` names. Provide clean, non-overlapping, skin-ready UVs and consistent texel density.
- Retain the original triangle targets: sidearms 3K, primaries 5K, machine guns and Operator 6K. Spend geometry on shape, connections and silhouette. Document any genuine conflict between the budget and the intended finish.
- Include appropriately scaled rounds/casings, clearly readable reloads and all required Actions: Fire, Reload, ReloadEmpty, Draw, Inspect, plus the existing weapon-specific variants and Knife attacks.
- Check the held view with reference arms. Check ADS geometry against the 0.16-stud eye exclusion requirement; resolve this as part of a well-designed sight assembly.

## Review and delivery standard

### Vandal visual checkpoints (required now)

1. Build primary forms: preserve the original length and characteristic contours, thicken receiver/handguard/grip/magazine, establish the long curved magazine and seated neck/well/catch relationship, and position the actual open ring/front-post geometry.
2. Inspect MCP screenshots from full side, complete three-quarter, top/front, and an actual ADS camera. Correct silhouette, proportions, thickness, magazine fit and sight placement based on these images before secondary detailing.
3. Refine secondary forms, independent moving exterior parts, deliberate chamfers, clean grip texture, graphite coating, satin metal and dark polymer. Resolve trigger clearance, charging track and a supported charm eyelet with attachment clearance.
4. Inspect again at first-person distance. Use a visible background target in the ADS scene and verify the target stays visible through the actual rear aperture and aligned front post with the receiver below the aiming window. Do not fake the sight picture with a painted overlay, hide obstructing weapon geometry only for the ADS camera, or use a disconnected presentation-only sight.
5. Save a fresh `.blend` under `art-source/weapons/RemasterV2/Vandal/` through MCP, safely preserving the user's existing scene/work. Use a fresh versioned name if a file already exists. Save review images under its `renders/` folder and record the output paths, camera setup/eye distance, triangle count, preserved contracts and remaining issues in a short review note. Do not claim full rig/animation/UV completion if only the modeling review pass is complete.

Minimum delivery for this review: saved Vandal `.blend`; full three-quarter hero; full side; top/front demonstrating thickness; generous first-person ADS view with a visible background target; close-ups of magazine seating, trigger/charging area, and charm mount. Use neutral lighting and show the complete weapon without cropping its stock or muzzle. **Present these results and stop. Wait for the user's visual review before other weapons.**

### Eventual finished-asset package (after the pilot review)

For each finished asset, provide a hero, side, top, ADS and held render; a rig/attachment view; and three useful reload frames. Also provide close-ups of the magazine junction, charging assembly, sight mounts, charm mount and material/corner treatment. Use consistent neutral studio lighting that reveals the actual surfaces. Show these details large enough to judge.

Review the original and rebuilt Vandal at comparable scale and lighting. The new version must improve the qualities the user called out: character, precision, connections, corners, materials and sight design. Triangle counts, action counts, clean exports and automated audits establish technical compatibility; **they do not establish professional visual quality**.

Deliver the authored .blend files, packed texture sources, shared library and review renders as those stages are completed. The immediate Vandal task requires the `.blend` and review images; exports and Studio integration are not part of this handoff's execution scope. The user will review the art before a later integration pass. Do not present the rejected first pass or an unreviewed rebuild as approved or import-ready.

## Vandal-specific contract facts read from the original scripts

These are source-code findings, not measurements of the current `.blend`. Verify against the original asset through MCP before authoring.

- `build_vandal.py`: +X muzzle, +Z up, +Y gun-left; grip origin; one unit equals one stud. Its concept tracing uses `S = 0.0031`, image origin `(948, 900)`, and a muzzle-to-buttpad reference length of about 3.9 studs. Retain length/identity while intentionally adding width.
- Original rig object: `Vandal_Rig`. Bones: `Root`, `Mag`, `ChargingHandle`, `Bolt`, `Trigger`, `FireSelector`, `Flash`, `Charm`; each non-root bone is parented to `Root`. Root head is `(0, 0, 0.15)` in the builder; do not confuse that with the grip/Handle origin. Preserve original bone axes and inspect actual joint pivots.
- Source locator objects use the `Vandal_` prefix with semantic names `Muzzle`, `RightGrip`, `LeftGrip`, `AimPoint`, `Eject`, `CharmPoint`. `CharmPoint` rides the `Charm` bone; the others listed ride `Root`. Preserve exporter naming expectations; do not casually rename source objects to bare attachment names. Retain/add the required `Socket_Muzzle`, `Socket_Optic`, `Socket_Under` consistently with the source/export contract.
- `SIGHT_Z` is derived by `gunkit.sight_line(...)`; rear ring center and front post tip align. Inspect `gunkit.py` and the current ADS configuration read-only before positioning the review camera. The baseline brief uses a 0.16-stud eye-exclusion requirement, with default aim distance 0.7 and open-irons distance 0.3; verify actual Vandal settings rather than assuming these defaults.
- `anim_vandal.py` uses 24 FPS and Actions `Vandal_Fire`, `Vandal_Reload`, `Vandal_ReloadEmpty`, `Vandal_Draw`, `Vandal_Inspect`, with semantic NLA track names. End frames are 12, 97, 97, 36 and 67 respectively, starting at frame 1. Reload markers are `MagOut = 15`, `MagIn = 30`, stored in `gg_markers`; the seated rest pose returns at frame 51. These source frame spans are not necessarily the gameplay playback durations; the game stretches most clips.
- Both reloads separate magazine movement from the later charging-handle movement so hand-follow windows do not overlap. The animation comments describe `FOLLOW_LEAD = 0.14`; magazine movement finishes near 53% and handle motion starts near 80%. Preserve that behavior and marker semantics when later refining animations.
- Read-only game references for later verification: `src/shared/Config/Weapons.luau`, `src/shared/Config/Viewmodel.luau`, `src/shared/WeaponAnimations/Vandal.luau`, and relevant `ViewmodelController` aiming/clip logic. Do not edit game code in this task.

## Finish the handoff cleanly

Record actual progress, exact saved paths, visual checkpoint results and any unfinished rig/UV/animation work. Release your Blender lock. Keep the original scene safe. Stop at the Vandal review gate, without proceeding to Classic, exporting/importing into Studio, or performing git operations.

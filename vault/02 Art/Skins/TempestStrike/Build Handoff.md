# Tempest-Strike Vandal build handoff

2026-11-18. Build the revised elite Vandal from the owner's [concept sheet](refs/style/Tempest-Strike%20Vandal%20Reference.png), [complete design brief](concept.md) and [research archive](Research.md). The owner expects professional game asset quality and a recognizable new structure with the presence and feel of the Ruin-Blighted Vandal.

**Owner clarification, 2026-11-18.** Start with the **Vandal hero in Storm Shadow**. Use the installed **GPT 3D skill** and the relevant project skills. Blender MCP is connected on **port 9876**. The owner prefers deliberate mesh modeling and sculpted detail, with code available for efficient operations. The owner authorizes installing Blender add-ons that help achieve the requested quality. Finish the base hero before progressing to its chroma presentation and supporting assets.

**Form review decision, 2026-11-18.** Use the Remaster V2 Vandal's exposed barrel break, short stock neck, aft stock opening, grip and magazine envelope, center aim and buddy mount as design constraints. Shape the new armor within that silhouette. Use the owner's Kuronami clip for sharp surfacing, enamel color and handling rhythm. Keep the stock buddy loop empty. This review is for the opaque model and mechanical action staging. Water, sparks, equipped charms and chromas follow the base review. [Build review](Build%20Review.md)

## Read and establish the source

1. Read the current repository `AGENTS.md`, `.agents/skills/gauntlet-vault/SKILL.md`, `.agents/skills/gauntlet-build-style/SKILL.md`, Home status, the Style Bible and this handoff's linked brief. Load `C:/Users/charl/.codex/skills/gpt-3d/SKILL.md`, then its `upstream/skills/skill_gpt_3d.md` router and `blender_modeling.md`. For the action previews, also read `blender_animation.md`. Apply their editable-source, modifier, material, comparison and motion checks to this weapon and the existing project delivery format. Choose additional skills by their relevance to the current stage. The new elite design and latest owner decisions govern its visual treatment.
2. Review [Ruin-Blighted Vandal v05](../../../../art-source/weapons/Skins/RuinBlighted/Vandal/v05/Vandal_RuinBlighted_v05.blend), its [build evidence](../RuinBlighted/Build%20Review.md) and the [elite playbook](../RuinBlighted/Elite%20Skin%20Playbook.md). Its authored spine, action cover, complete finish, hand staging and runtime checks establish the benchmark. The owner rejected the first expansion quality and another agent is revising those guns. Preserve that work.
3. Connect through **Blender MCP at `127.0.0.1:9876`**, as confirmed by the owner for this build. Inspect Blender version, current file, scene and unsaved state read-only, then establish an isolated versioned working scene that preserves the owner's open work. Verify the MCP client actually reaches that port if its default configuration differs. Perform the modeling and review in the live Blender session, saving intermediate versions as the form develops.
4. Inspect [stock RemasterV2 Vandal v05](../../../../art-source/weapons/RemasterV2/Vandal/Vandal_RemasterV2_v05.blend) and the [stock model sheet](../../../../art-source/weapons/ModelSheets/Vandal_model_sheet.png). Confirm these against current source before selecting the host. Record the source hash, dimensions, rig and locators, hand space, camera transforms, action markers and materials. Keep the stock source available in a separate comparison scene.

## Modeling method and add-ons

Treat the supplied sheet as the art target throughout the build. Establish the length, upper contour, stock opening, magazine rake and first-person massing with a deliberately edited base mesh. Refine the major forms before adding vents, seams, bindings or effects. Compare each meaningful change from the held camera and both sides while the mesh remains easy to revise.

Use Blender's mesh tools through MCP for purposeful topology, silhouette cuts, extrusions, inset panels, controlled bevels, supported boolean cuts and normal treatment. Seat panels and shape the silver planes so their highlights describe the form. Use sculpting or custom mesh work where it improves leather folds and compressed wrap edges. Bring any sculpted detail into an exportable game mesh with appropriate topology and baked detail when useful. Match Gauntlet's faceted style and the image's crisp armor planes.

Code is authorized for Blender tool operations, symmetry, repeated bindings or vent spacing, rig setup, measurements, comparison captures and export. Inspect generated geometry and refine the result in Blender. Choose the combination that produces the best model efficiently, with an editable source and visible evidence of its finish.

The owner has authorized **installation and enabling of helpful Blender add-ons**. Inspect the installed tools first, then select compatible additions from Blender Extensions or the developer's maintained source when they solve a concrete modeling, material, UV, baking or review need. Record each installed add-on's name, version, source and purpose in `Build Review.md`. Keep modifier and node dependencies available with the working master, and ensure the export copy contains the evaluated geometry and textures required by the game.

Keep construction geometry and modifiers editable in the master. Perform destructive merging, baking, triangulation or reduction on export copies. Pack or use verified relative paths for textures and reopen the saved master before delivery. Apply GPT 3D's relevant checks to this asset, preserving the repository's `.blend`, PNG, motion-preview and manifest handoff.

## Required result

Model a cohesive new receiver exterior, upper spine, octagonal fluted fore-end, vented muzzle detailing, triangular stock frame, leather-wrapped grip and magazine, and open crescent rear sight. Seat the silver sliding plates into designed recesses. Make the plate ends and junctions deliberate, with visible thickness, taper and clearance. Carry the same finish through the far side, underside, magazine heel and stock junction.

The visible design must read in untextured silhouette and in an opaque neutral-light render before water and lightning are enabled. Replace stock geometry in regions that have been redesigned, retaining the stock rig contract and contacts as measured references. A changed color and a few attached wedges do not satisfy the requested structural work. The Vandal needs the same level of design attention as the approved Ruin-Blighted hero.

Use the elongated **octagonal shroud and ported muzzle**, **laminar water**, **sparse vent arcs**, **open crescent sight**, **dark leather bindings**, **hydro-core round** and **spinning shuriken charm** from the latest revision. Preserve a close relationship to the stock Vandal's size and holding posture. Resolve length and clearance through measured comparisons, with any departure written into the review.

Start from Storm Shadow. Set up semantic materials so Amethyst Gale, Mist Ivory and Midnight Eclipse can later share the same geometry and action controls. Complete the base rifle's structural, material and first-person review first, then produce its supporting chroma board. The hex values in the concept are working proposals and can be adjusted to match the supplied image under neutral lighting. Record those adjustments.

## Rig and animation preparation

| Assembly | Ownership and required preview |
| --- | --- |
| Main chassis and stock frame | Rigid main root and a measured balance pivot for the floating inspect. Keep the stock hand and aiming anchors available. |
| Silver slide plates | Independent rigid controls with distinct rest and locked poses. Demonstrate the muzzle-to-stock draw sequence and full travel without mesh or hand clipping. |
| Magazine | One removable assembly owning all leather, silver, water and glow pieces. Demonstrate release, dissolve, off-hand formation, upward travel and one clean seat. |
| Fore water and stock ring | Anchors on their actual rigid parents, with explicit path orientation and flow direction. Preview their silhouette as translucent guides. |
| Crescent sight | Fixed aiming center, open top and restrained side pips. Preserve meaningful `Sight` names through export so the runtime fade rules can identify it. |
| Round | Separate hydro-core cosmetic mesh and close-up study, sized against the host's visible round contract. |
| Shuriken charm | Separate model with mount and spin pivots, a defined resting pose and a bounded swing envelope. |

Author an editable Blender animatic for draw, idle circulation, fire response, tactical reload, empty reload, full horizontal 360-degree levitating inspect, return and cancel. Use actual hand proxies or the available viewmodel rig for the catch and palm-up summon. Track the rifle, plates, hands, water and magazine on one event timeline. Keep static and moving geometry ownership explicit in the saved rig and export manifest.

Measure the current Vandal readiness and commit markers. Adapt cosmetic staging to them and document handoff events for `DrawSweep`, `PlateLock`, `MagRelease`, `WaterGather`, `MagForm`, `MagGlide`, `MagSeat`, `Chamber`, `InspectRelease`, `InspectOrbit`, `InspectCatch` and `Cancel`. These names are descriptive proposals to map onto existing conventions. The runtime integration should reuse current event and cleanup mechanisms where they fit.

The inspect needs a smooth balance-centered orbit and a grip catch at its end. Check the left and right hand release poses, muzzle direction, charm swing, camera crop and all four quadrants of the spin. Shooting or ADS during inspect must return to a valid held pose with the appropriate cues cancelled.

## Effects and sound preparation

Author water texture and path guides suitable for two or three thin ribbons along the grooves, with additional spans only where the loop needs them. Prepare sparse vent arc anchors, a compact four-point muzzle flash, small droplet bursts, a thin tracer, an impact splash and fading spark mark. Use the [concept's settings](concept.md#effects-brief) as initial values for the later Studio pass. Neutral-light Blender material evidence and working Roblox runtime VFX are different milestones.

Create an event cue table for water sweeps, condensation, glide, plate locks, reload seat and chamber, inspect loop and catch, reports and tails, impacts and the elimination ladder. Start report pitch variation at `0.98–1.02`. Track which existing stock recordings can support contact and mechanics, and which new water, whip, electric and bell recordings the owner needs to source. The existing Ruin-Blighted audio bank demonstrates working scheduling and cancellation. Its stone and mist sounds should not become the new line's default identity.

The elimination ladder proposes five rising chime or taiko-accented bell stages and distant Ace thunder. Record how the idea will map to the game's actual 1v1, 2v2 and 3v3 rounds before wiring it into confirmed elimination events. Keep finishers and any weather scene as later design work.

## Review and grading

| Review | Evidence required |
| --- | --- |
| Structural design | Effects-off side silhouettes and a matched stock overlay. Identify the redesigned regions and show how their transitions form one rifle. |
| Materials | Neutral-light hero and close-ups of silver, leather, black alloy and hydro-core glass. Show detail without bloom hiding it. |
| Concept match | Place the supplied concept beside matched-camera renders. Compare proportions, large silver planes, stock opening, wrap rhythm, muzzle treatment and sight opening. Label inferred hidden details and explain deliberate deviations. |
| Full asset finish | Opposite side, underside, rear, top, muzzle and magazine heel. Every intended gap has a defined purpose. |
| Geometry | Closed outward faces, no crossed faces or accidental doubled plates, stable normals, no coplanar flicker, clean vents and reliable plate seating. Reimport the exported geometry and compare. |
| Hands and magazine | Draw, normal and empty reload, inspect catch, fire, and cancel sampled around contact events. Check hand envelopes, magazine alignment, wraps and full plate travel. |
| Sight | Matched renders from both stock aim cameras at rest and during the full moving effect and plate cycle. The center, front reference and surrounding target area stay readable. |
| Export | Reopen the saved master, compare stock bone and locator matrices, validate custom pivots and names, count visible triangles, parts, joints and effects, and record the actual counts. |
| Runtime follow-up | After the hero review, the Studio pass checks normal inputs, actual automatic empty reload, interrupted inspect and reload, low graphics, spectator and world-model visibility, and cleanup. |

Review the draw, reloads and inspect in continuous playback. Check velocity, anticipation, magazine alignment, plate locks and the grip catch between the sampled poses. For a rendered MP4, keep resumable frame sequences, verify the expected frames and decode the final video. Log any action that has only pose evidence so it cannot be mistaken for reviewed motion.

Score silhouette and structural design out of 30, materials and craft out of 20, held and aim readability out of 20, animation and feel out of 15, engineering out of 10, and presentation out of 5. Aim for **90/100 or higher**, with written evidence and specific limitations. Visible geometry faults, an obstructed sight or a failed catch must be corrected before the hero is presented as ready. Passing scripts supports the grade. The final visual review must also match the supplied concept and the approved hero benchmark.

## Deliverables and next review

Save versioned masters under `art-source/weapons/Skins/TempestStrike/Vandal/v01/`, incrementing versions when revising. Keep review evidence next to each master. Put the final PNG sheet under `vault/02 Art/Skins/TempestStrike/out/Vandal_v01.png`. Include large hero, both sides, top and underside, held, matched aim, material details, magazine and round close-ups, charm mount, swatches and the key draw, reload and inspect poses. Save the charm and round as separate editable assets when they are built.

Add an `out/` motion preview for draw, both reloads and inspect, a measured geometry and rig report, a chroma board, and an event/SFX table. Keep a concise `Build Review.md` with file links, self-grade, specific revisions, observed evidence and the exact next step.

This chat prepares the brief. The next build chat should complete and self-review the **Vandal hero** and its offline motion preparation, then present the result for the owner's look review before adapting the remaining line. The old Spindrift six-gun roster is historical context. The current request has not reconfirmed the full revised roster. A separate knife concept was mentioned but was not present among this request's attachments.

## First build prompt

> Start with the Tempest-Strike Vandal hero in Storm Shadow. Read `vault/02 Art/Skins/TempestStrike/Build Handoff.md`, `concept.md` and `Research.md`, and inspect the archived concept image. Load the installed GPT 3D skill at `C:/Users/charl/.codex/skills/gpt-3d/SKILL.md`, follow its router into the relevant modeling and animation workflows, and use the Gauntlet vault and build-style skills. Connect through Blender MCP on port **9876**, inspect the open scene and preserve existing work. You are authorized to install useful compatible Blender add-ons and record their sources and purpose. Use deliberate mesh modeling and sculpted detail where appropriate. Code can support Blender tool operations, repetition, rigging, checks and export. Build a cohesive redesigned rifle with the octagonal fluted shroud, seated silver plates, triangular stock, wrapped grip and magazine, and clear crescent sight. Match the supplied concept and the craftsmanship of Ruin-Blighted Vandal v05. Finish the base hero's structure and materials before its chroma board and supporting assets. Verify stock scale, hand contacts, ADS and moving-part clearance. Prepare the water-guided draw, magazine summon and upward reload, and full horizontal 360-degree inspect with a convincing grip catch. Review the motion in continuous playback. Save editable versioned masters, matched concept and stock comparisons, effects-off and material renders, motion previews and export checks. Self-review honestly against the handoff's 90/100 target and correct visible faults before presenting the Vandal for my approval. Keep the build ledger current and follow the handoff's hero review sequence.

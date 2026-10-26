# Gauntlet FPS — Weapon Design and Claude Modeling Briefs

Sixteen original companion assets for the existing Vandal, Phantom and Classic.
Use each generated concept sheet with the corresponding brief below. The image is a visual target; the brief defines the component structure and animation behavior.

## Scope and roster

Sheriff replaces the accidentally repeated Judge entry. Frenzy and Warden are excluded. Stinger is replaced with an Uzi-inspired SMG. Dual automatic pistols occupy one primary slot. Do not add unlisted weapons.

| Sheet order | Weapon | Identity | Aiming default |
| --- | --- | --- | --- |
| 00 | Classic | Default semiautomatic pistol; the sidearm benchmark (added 2026-10-25) | None |
| 01 | Shorty | Compact double-barrel shotgun sidearm | None |
| 02 | Ghost | Slim suppressed semiautomatic pistol | None |
| 03 | Judge | Compact automatic drum-fed shotgun | None |
| 04 | Stinger Replacement — Uzi-Inspired SMG | Compact magazine-in-grip automatic SMG | Iron-sight ADS as a proposed project default; ready to tune in game |
| 05 | Spectre | Refined suppressed compact SMG | Iron-sight ADS as a proposed project default |
| 06 | Bucky | Long pump-action shotgun | None |
| 07 | Sheriff | Heavy six-shot tactical revolver | None |
| 08 | Bulldog | Compact bullpup tactical rifle | Iron-sight ADS |
| 09 | Guardian | Long semiautomatic precision rifle | Iron-sight ADS; no scope on default model |
| 10 | Basic Knife | Simple tactical melee knife | None |
| 11 | Marshal | Light lever-action scoped rifle | Scoped aiming with a fixed optic; project controls zoom and camera overlay |
| 12 | Outlaw | Twin-barrel break-action scoped rifle | Scoped aiming with a fixed optic |
| 13 | Operator | Heavy bolt-action sniper rifle | Scoped aiming; support optional multiple zoom levels in gameplay without moving optic geometry |
| 14 | Ares | Compact drum-fed light machine gun | Iron-sight ADS as a proposed project default |
| 15 | Odin | Large belt-fed heavy machine gun | Iron-sight ADS as a proposed project default |
| 16 | Dual Automatic Pistols — Primary Weapon | Akimbo pair of compact automatic pistols with extended magazines | None |

## Shared art direction and technical contract

Use the existing approved Vandal, Phantom and Classic as the family benchmark. Inspect their actual Blender and Roblox setup before creating a new asset. Preserve the project conventions where they exist rather than inventing a second framework.

- Moderately blocky geometry between Phantom Forces and Rivals, broad readable planes, purposeful small bevels and clean controlled shading.
- Matte charcoal, graphite and near-black materials, subtle polymer-versus-metal roughness, understated clean surface texture and tiny blue accents. Normalize small color or roughness variations in the generated sheets to the approved family material palette.
- Proper UVs and Roblox-compatible base-color, normal, roughness and metalness maps where useful. Reuse compatible materials. Small Neon elements are separate meshes attached to their parent component.
- Same scene units, export scale, forward/up directions, root orientation, attachment naming conventions and character-hand proportions. Match existing grip dimensions where appropriate without forcing every weapon into identical geometry or poses.
- Use the existing Motor6D or bone-based animation workflow. Separate rigid moving pieces, align useful axes and pivots, preserve a documented rest pose, and avoid multiple joints driving the same part.
- Blender parenting alone is not a finished Roblox rig. Test the export/import and document any Roblox-side joint setup still needed. Keep an untouched source file before export preparation.
- One weapon root controls overall motion; moving parts remain independently animated. Fixed pieces may be combined when it reduces draw calls without harming materials or motion.
- Reuse base animation logic where practical. Pistols, revolvers, pump guns, bullpups, scoped actions and dual weapons need their own hand poses and action sequences. Shared interfaces do not imply identical animation clips.
- Reference points must follow their real parent component. Hand targets on moving fore-ends follow the fore-end. Muzzle effects originate at the visible barrel or suppressor exit. Avoid applying the same motion twice to attachments.
- Build enough exposed surfaces for reloads and inspect views, but no detailed hidden engineering. This is a fictional visual game asset, not a functional manufacturing model.
- Gameplay owns ammo, damage, spread, recoil tuning, zoom, alternate-fire rules, hit detection and timing. Animation markers trigger visual shell/magazine swaps, sounds and VFX at the correct moments; do not hard-code balance into mesh structure.
- Treat all newly selected aiming behaviors as working project defaults. Classic remains no ADS as already established. This batch uses no ADS for sidearms, shotguns, knife and dual pistols; iron-sight ADS for SMGs, rifles and heavies; scoped aiming for sniper rifles.
- For scoped assets, keep optics rigid and non-emissive. Use a camera reference at the eyepiece; gameplay handles magnification, reticle and overlay. No baked screen-space reticle in a lens texture.
- Optimize by comparison with the existing assets and actual Roblox profiling. Use geometry for silhouettes and moving pieces; use textures for tiny static details. Reduce unnecessary material slots, duplicate joints and unseen surfaces. Do not impose an invented universal triangle budget.
- First-person viewmodels can use their own animation rig while world models retain the same external silhouette and attachment semantics. Do not assume a viewmodel arm rig can be imported unchanged as a third-person character rig.
- Premium skins may later transform appearance substantially. Preserve weapon root, grip, muzzle and animation interfaces so skins can fit the same gameplay framework.

## How to use these briefs with Claude

Attach the relevant generated sheet and paste its complete weapon section. The core shared instructions are repeated in each section so it can stand alone. Provide the existing weapon project or rig when available so Claude can match actual conventions.

Do not treat a generated sheet as an exact orthographic blueprint. Maintain its silhouette and visible design; resolve small view-to-view inconsistencies into one coherent model. If the two renders disagree, use the side view for proportions and the three-quarter view for depth, checking the design requirements below. Do not copy accidental marks as logos.

These deliverables are concept sheets and modeling briefs. They do not include finished Blender models or completed animation clips.

---

# 00. Classic — Blender Modeling Brief

*The user's brief (2026-10-25). Concept: `vault/02 Art/References/Gun-Image-Concepts/Classic Pistol Two-View Concept Sheet.png`. The other briefs treat the Classic as the sidearm benchmark, so it's built before the other sidearms. Project-name mapping: WeaponRoot → `Root` bone, Magazine → `Mag`, MuzzleAttachment → `Muzzle` (on the `Barrel` bone), EjectionAttachment → `Eject` (on the `Slide` bone), RightHandGrip / LeftHandGrip → `RightGrip` / `LeftGrip`.*

## 1. Overall Design

Use the attached **approved Classic concept sheet** as the primary visual reference. Follow its silhouette, proportions, geometry, materials, and blue accent placement closely.

Create a polished, game-ready pistol for the same Roblox FPS as our Vandal and Phantom rifles.

**All three weapons belong to the same visual family.** The Classic should share their material quality, bevel treatment, level of blockiness, naming conventions, and technical setup, while using pistol-specific construction and animations.

**Design requirements:**

- Moderately blocky, low-poly aesthetic between Phantom Forces and Rivals.
- Compact tactical pistol with a slightly boxy slide and softened beveled corners.
- Sturdy charcoal frame and moderately thick grip suitable for Roblox hands.
- Short barrel contained inside the slide.
- Straight magazine concealed inside the grip, with a small visible baseplate.
- Simple angular trigger guard and restrained mechanical controls.
- Small iron sights, matching the concept.
- Matte black and charcoal surfaces with very subtle blue accents.
- High-quality textures and material definition.
- No suppressor, optic, laser, or additional attachments.

Preserve the approved appearance while making sensible simplifications for Roblox performance.

**This pistol does not have aim down sights.** Its gameplay and animation setup should support firing from the normal holding position, similar to Valorant's Classic.

## 2. Consistency With the Existing Weapons

Inspect the existing Vandal and Phantom assets before building the Classic.

Reuse their established conventions wherever appropriate:

| Area | Requirement |
| --- | --- |
| **Scale and orientation** | Same scene units, export scale, forward direction, and upright axis. |
| **Materials** | Matching charcoal palette, polymer finish, metal roughness, and restrained blue accents. |
| **Geometry** | Similar bevel sizes, surface detail, and mesh density relative to component size. |
| **Weapon root** | Same naming and orientation conventions, with placement appropriate to a pistol. |
| **Rigging** | Same underlying animation workflow and joint conventions. |
| **Attachments** | Consistent names and orientation rules for equivalent functions. |
| **Exports** | Same organization and Roblox import conventions. |

**Share the weapon framework, but create pistol-specific poses and animations.** Rifle hand positions, reload movements, and holding distances should not be reused unchanged.

Match the same character hand proportions and maintain comfortable trigger reach and grip clearance.

## 3. Textures and Materials

Use the same material family as the rifles:

- Matte black or deep graphite slide.
- Charcoal polymer frame.
- Darker grip panels, magazine, and secondary controls.
- Subtle metallic highlights on appropriate surfaces.
- Restrained roughness variation between metal and polymer.
- Clean, understated grip texture.
- Tiny blue accents matching the approved image.

Avoid heavy wear, dirt, exaggerated scratches, excessive texture noise, or strong glow.

Create proper UV maps and Roblox-compatible texture maps where appropriate:

**Base color, normal, roughness, and metalness.**

Blue elements intended for Roblox Neon should be separate small meshes. Parent or connect each accent to its associated component: the slide accent moves with the slide, and the magazine-base accent moves with the magazine.

## 4. Moving Parts — Separate and Animation-Ready

**Do not merge moving components into the stationary frame.**

| Component | Required setup |
| --- | --- |
| **Frame** | Stationary main body, including the grip and trigger guard. |
| **Slide** | Separate component capable of moving backward and returning forward. |
| **Barrel** | Separate mesh, allowing appropriate visible movement if needed. |
| **Magazine** | Independently removable through the bottom of the grip. |
| **Trigger** | Separate component with a correctly placed rotation pivot. |
| **SlideCatch** | Separate if animated during an empty reload. |
| **MagazineRelease** | Separate if its movement will be visible during reloads. |

Iron sights and other slide-mounted details must move with the slide.

The slide should support both brief firing movement and a held-open empty state. Ensure the geometry looks complete when the slide is pulled back or the magazine is removed.

Do not add unnecessary controls or moving mechanisms absent from the approved design.

## 5. Rigging and Hierarchy

Use the same rigging approach as the existing weapons. Preserve the established Motor6D or bone-based workflow rather than introducing a separate animation system.

Suggested names:

`WeaponRoot`, `Frame`, `Slide`, `Barrel`, `Magazine`, `Trigger`, `SlideCatch`, `MagazineRelease`, `FrontSight`, `RearSight`.

Requirements:

- One weapon root drives the entire pistol.
- Stationary components remain rigidly connected to the frame.
- The slide has a correctly aligned local movement axis.
- The magazine can move independently during removal and insertion.
- Rotating controls have meaningful pivots.
- All components have a clean, documented rest pose.
- Avoid duplicate constraints or multiple joints driving the same part.
- Preserve correct origins and pivots when preparing exports.

Blender parenting alone should not be treated as a completed Roblox animation rig. Document any Roblox-side joint setup still required.

## 6. Pistol Animation Support — No ADS

The model must support the following future animations:

1. **Idle / Holding** — A natural pistol-specific pose with a clear view of the weapon.
2. **Equip / Unequip** — Raising and lowering the pistol with appropriate handling.
3. **Fire** — Whole-weapon recoil, trigger movement, and slide cycling.
4. **Last Shot / Empty** — Slide remains held back when the weapon becomes empty.
5. **Tactical Reload** — Magazine exchange while the slide remains forward.
6. **Empty Reload** — Magazine exchange followed by slide release or a chosen slide-manipulation action.
7. **Inspect** — Rotation that shows the slide, grip, opposite side, and magazine base.
8. **Sprint / Lowered** — A pistol-specific lowered pose.
9. **Dry Fire** — Trigger movement without normal firing effects, if used by the game.

**Do not create an ADS animation, ADS camera position, or transition into iron-sight aiming.** Keep the modeled sights as visual details.

Use the project's chosen pistol hand pose. If a support hand is used, check its clearance around the grip, slide, and reload path.

Animations do not all need to be completed now, but the asset must be structured to support them.

## 7. Attachment Points

Use the same naming and orientation conventions as the rifles for equivalent functions.

| Attachment | Purpose |
| --- | --- |
| `MuzzleAttachment` | At the barrel opening, aligned with the firing direction for shooting effects. |
| `EjectionAttachment` | At the ejection port, oriented for casing effects. |
| `RightHandGrip` | Primary hand placement on the pistol grip. |
| `LeftHandGrip` | Support-hand reference if the chosen pistol pose uses one. |

**An `AimPoint` for ADS is not required.**

Place the muzzle reference on the appropriate barrel component so it does not accidentally follow the slide's rearward movement. Handle the ejection reference consistently with the existing effects system.

## 8. Optimization and Validation

- Prioritize silhouette, clean shading, and visible material quality.
- Use geometry for moving parts and silhouette-defining details.
- Use textures or normal maps for small stationary details.
- Avoid excessive material slots and unnecessary hidden geometry.
- Include only enough exposed interior detail to support slide movement and reloads.
- Check first-person framing without ADS and third-person readability.
- Test slide travel, magazine clearance, hand placement, and attachment orientation.
- Verify a Roblox import for scale, materials, component separation, and pivots.

Compare the finished Classic beside the Vandal and Phantom. They should clearly belong to the same game.

## 9. Deliverables

- Organized Blender project (`.blend`).
- Roblox-compatible exported meshes (`FBX`).
- UV-mapped and textured components.
- Separate animation-ready moving parts.
- Correct origins, pivots, and hierarchy.
- Named attachment reference points.
- Consistent scale and orientation with the existing weapons.
- Brief import notes identifying remaining Roblox setup.
- Matching three-quarter and side-profile preview renders.

**Final priority:** Match the approved Classic concept, preserve the rifles' visual and technical conventions, and prepare a convincing pistol-specific animation structure with no ADS.

---

# 01. Shorty — Blender Modeling Brief

## 1. Overall Design

Use the matching generated Shorty concept sheet as the primary visual reference. Create an original polished game-ready Roblox asset in the same family as the approved Vandal, Phantom and Classic. Match the silhouette, major proportions, materials and amount of blockiness while simplifying minor detail where useful.

**Identity:** Compact double-barrel shotgun sidearm.

**Chosen design:** Very short vertically stacked over-under twin barrels, two circular muzzle openings; compact hinged breech; no shoulder stock; short angled polymer pistol grip and small front support surface. Two-shot break-action identity, not a pump gun or pistol-slide design.

Use broad readable moderately blocky forms, clean shading and selective small bevels. Keep the prop attractive both close up in first person and at third-person distance. Resolve small image inconsistencies into one coherent model; prioritize the described category and key distinguishing parts.

## 2. Family Compatibility

Inspect the existing weapon assets first. Preserve scene units, export scale, axis conventions, character-hand proportions, root naming/orientation and the established Motor6D or bone workflow. A shared framework is required; weapon-specific hand poses and action animations are expected. Place correct origins and pivots, use clean rest transforms and avoid duplicate constraints. Do not permanently merge moving parts into the stationary body. Preserve this separation through export and document any Roblox-side joint setup. No detailed hidden mechanism is required.

Use one main weapon root following existing conventions, with the stationary body and independent animated components beneath it.

## 3. Textures and Materials

Use matte charcoal/graphite metal and near-black polymer with restrained roughness differences, clean fine surface texture, soft bevel highlights and tiny blue accents. Match the existing Vandal, Phantom and Classic rather than increasing detail or glow. Create clean UVs and Roblox-compatible base-color, normal, roughness and metalness maps where useful. Neon details are separate small meshes that follow the associated moving component. Avoid excessive wear, noisy textures and plain untextured brick colors.

## 4. Separate Components and Structure

| Component / group | Setup and movement |
| --- | --- |
| **Frame** | Stationary grip, trigger guard and rear breech body. |
| **BarrelAssembly** | Both barrels and fore-end move together around one break-action hinge. |
| **BreechLatch** | Small independent opening control if visible. |
| **Trigger** | Independent cosmetic rotation. |
| **Shell_Upper / Shell_Lower** | Separate reusable visual shell props for two chambers. |

Only group parts that move together. Give reload props reusable geometry and consistent material assignments. Fixed decorative meshes follow their associated parent.

## 5. Animation Requirements

- Idle, equip, fire from either barrel, open action, full two-shell reload, one-shell partial reload, close action, inspect and lowered sprint.
- Track each chamber separately; only spent shells eject.
- No cycling slide or detachable magazine.

**Aiming:** None. Hip-fire holding only.
Do not create an ADS pose, camera alignment transition or ADS AimPoint for this asset. Keep modeled sights as visual details where present.

Use gameplay state and animation markers to control reload-prop visibility, sound and effects. Partial, empty and interrupted states must not duplicate ammunition props or create unintended movement. The mesh does not define capacity, damage or fire-rate balance.

## 6. Attachments and Reference Points

WeaponRoot, RightHandGrip, LeftHandGrip if used, MuzzleAttachment_Upper, MuzzleAttachment_Lower, Chamber_Upper, Chamber_Lower and EjectionAttachment_Upper/Lower. Each chamber and muzzle belongs to BarrelAssembly.

Position references consistently with the existing framework and parent them to the correct moving component. Match their local axis conventions before import. Do not guess new conventions if the existing project can be inspected.

## 7. Checks and Special Notes

Show two vertically stacked distinct muzzle bores in the three-quarter render. Keep both barrels aligned and a usable opening arc. Trigger hand stays on stationary grip while barrel assembly opens.

Full and partial reloads need separate visual shell states. The concept shows the closed, ready pose. Use Upper/Lower chamber naming consistently; the generated sheet uses over-under barrels.

Check hands, camera framing, component travel, reload clearance and the opposite side during inspect. Confirm that the mesh, rig and effect references agree; avoid accidental intersecting hands, floating magazines and unsupported animated parts.

## 8. Deliverables

- Organized source Blender project (`.blend`).
- Roblox-compatible exported meshes (`FBX`) and required textures.
- Correct UVs, material assignments, names, origins and rest transforms.
- Separate moving parts with useful pivots and animation-ready hierarchy.
- Named attachment reference points with consistent orientation.
- Matching three-quarter and side previews of the final model.
- Short import/setup notes identifying remaining Roblox joint work.
- A component-motion check and Roblox import check for scale, shading and separation.

Animations do not all need to be finished now. The model must support them without rebuilding its main structure. Review it beside Vandal, Phantom and Classic before delivery.

---


# 02. Ghost — Blender Modeling Brief

## 1. Overall Design

Use the matching generated Ghost concept sheet as the primary visual reference. Create an original polished game-ready Roblox asset in the same family as the approved Vandal, Phantom and Classic. Match the silhouette, major proportions, materials and amount of blockiness while simplifying minor detail where useful.

**Identity:** Slim suppressed semiautomatic pistol.

**Chosen design:** Slimmer longer slide than Classic, narrow charcoal frame, conventional pistol grip and a classic slender cylindrical suppressor. Flush inserted grip magazine and subdued slide serrations. Refined quiet silhouette, not a heavy automatic pistol.

Use broad readable moderately blocky forms, clean shading and selective small bevels. Keep the prop attractive both close up in first person and at third-person distance. Resolve small image inconsistencies into one coherent model; prioritize the described category and key distinguishing parts.

## 2. Family Compatibility

Inspect the existing weapon assets first. Preserve scene units, export scale, axis conventions, character-hand proportions, root naming/orientation and the established Motor6D or bone workflow. A shared framework is required; weapon-specific hand poses and action animations are expected. Place correct origins and pivots, use clean rest transforms and avoid duplicate constraints. Do not permanently merge moving parts into the stationary body. Preserve this separation through export and document any Roblox-side joint setup. No detailed hidden mechanism is required.

Use one main weapon root following existing conventions, with the stationary body and independent animated components beneath it.

## 3. Textures and Materials

Use matte charcoal/graphite metal and near-black polymer with restrained roughness differences, clean fine surface texture, soft bevel highlights and tiny blue accents. Match the existing Vandal, Phantom and Classic rather than increasing detail or glow. Create clean UVs and Roblox-compatible base-color, normal, roughness and metalness maps where useful. Neon details are separate small meshes that follow the associated moving component. Avoid excessive wear, noisy textures and plain untextured brick colors.

## 4. Separate Components and Structure

| Component / group | Setup and movement |
| --- | --- |
| **Frame** | Stationary frame and grip. |
| **Slide** | Independent backward movement; sights follow slide. |
| **Barrel_Suppressor** | Visual barrel and fixed suppressor form one group separate from the slide. |
| **Magazine** | Removable through grip with compact baseplate. |
| **Trigger / SlideCatch / MagazineRelease** | Separate visible controls. |

Only group parts that move together. Give reload props reusable geometry and consistent material assignments. Fixed decorative meshes follow their associated parent.

## 5. Animation Requirements

- Pistol-specific idle, equip, fire with slide cycling, last-shot slide hold-open, tactical reload, empty reload with slide release, inspect, dry fire and lowered sprint.

**Aiming:** None. Hip-fire holding only.
Do not create an ADS pose, camera alignment transition or ADS AimPoint for this asset. Keep modeled sights as visual details where present.

Use gameplay state and animation markers to control reload-prop visibility, sound and effects. Partial, empty and interrupted states must not duplicate ammunition props or create unintended movement. The mesh does not define capacity, damage or fire-rate balance.

## 6. Attachments and Reference Points

WeaponRoot, RightHandGrip, optional LeftHandGrip, MuzzleAttachment at suppressor exit, EjectionAttachment at port. No ADS AimPoint.

Position references consistently with the existing framework and parent them to the correct moving component. Match their local axis conventions before import. Do not guess new conventions if the existing project can be inspected.

## 7. Checks and Special Notes

Suppressor must not travel backward with the slide. Preserve clearance throughout slide movement and hand poses. Keep its size restrained relative to the compact pistol.

Reuse Classic frame/grip conventions where compatible, while retaining a visibly slimmer design. Suppressed sound and muzzle-effect tuning belong to gameplay, not the mesh.

Check hands, camera framing, component travel, reload clearance and the opposite side during inspect. Confirm that the mesh, rig and effect references agree; avoid accidental intersecting hands, floating magazines and unsupported animated parts.

## 8. Deliverables

- Organized source Blender project (`.blend`).
- Roblox-compatible exported meshes (`FBX`) and required textures.
- Correct UVs, material assignments, names, origins and rest transforms.
- Separate moving parts with useful pivots and animation-ready hierarchy.
- Named attachment reference points with consistent orientation.
- Matching three-quarter and side previews of the final model.
- Short import/setup notes identifying remaining Roblox joint work.
- A component-motion check and Roblox import check for scale, shading and separation.

Animations do not all need to be finished now. The model must support them without rebuilding its main structure. Review it beside Vandal, Phantom and Classic before delivery.

---


# 03. Judge — Blender Modeling Brief

## 1. Overall Design

Use the matching generated Judge concept sheet as the primary visual reference. Create an original polished game-ready Roblox asset in the same family as the approved Vandal, Phantom and Classic. Match the silhouette, major proportions, materials and amount of blockiness while simplifying minor detail where useful.

**Identity:** Compact automatic drum-fed shotgun.

**Chosen design:** Thick single short shotgun barrel, compact angular receiver, large detachable round drum beneath receiver ahead of pistol grip, sturdy short tactical stock, broad short fore-end and minimal iron sights. More compact and bulky than Bucky; no pump grip.

Use broad readable moderately blocky forms, clean shading and selective small bevels. Keep the prop attractive both close up in first person and at third-person distance. Resolve small image inconsistencies into one coherent model; prioritize the described category and key distinguishing parts.

## 2. Family Compatibility

Inspect the existing weapon assets first. Preserve scene units, export scale, axis conventions, character-hand proportions, root naming/orientation and the established Motor6D or bone workflow. A shared framework is required; weapon-specific hand poses and action animations are expected. Place correct origins and pivots, use clean rest transforms and avoid duplicate constraints. Do not permanently merge moving parts into the stationary body. Preserve this separation through export and document any Roblox-side joint setup. No detailed hidden mechanism is required.

Use one main weapon root following existing conventions, with the stationary body and independent animated components beneath it.

## 3. Textures and Materials

Use matte charcoal/graphite metal and near-black polymer with restrained roughness differences, clean fine surface texture, soft bevel highlights and tiny blue accents. Match the existing Vandal, Phantom and Classic rather than increasing detail or glow. Create clean UVs and Roblox-compatible base-color, normal, roughness and metalness maps where useful. Neon details are separate small meshes that follow the associated moving component. Avoid excessive wear, noisy textures and plain untextured brick colors.

## 4. Separate Components and Structure

| Component / group | Setup and movement |
| --- | --- |
| **Receiver / Barrel / Stock** | Stationary body group. |
| **DrumMagazine** | One detachable drum assembly. |
| **ChargingHandle / Bolt** | Separate manipulation and visible cycling components. |
| **Trigger / Selector** | Independent visible controls. |
| **EjectionCover** | Only if the design visibly uses one. |

Only group parts that move together. Give reload props reusable geometry and consistent material assignments. Fixed decorative meshes follow their associated parent.

## 5. Animation Requirements

- Two-handed idle, equip, automatic fire, magazine-present and empty states, full drum exchange, appropriate empty charging action, inspect and lowered sprint.
- No pump action between shots.

**Aiming:** None. Hip-fire holding only.
Do not create an ADS pose, camera alignment transition or ADS AimPoint for this asset. Keep modeled sights as visual details where present.

Use gameplay state and animation markers to control reload-prop visibility, sound and effects. Partial, empty and interrupted states must not duplicate ammunition props or create unintended movement. The mesh does not define capacity, damage or fire-rate balance.

## 6. Attachments and Reference Points

WeaponRoot, MuzzleAttachment, EjectionAttachment, RightHandGrip, LeftHandGrip, MagazineSeat and optional ChamberReference. No ADS AimPoint.

Position references consistently with the existing framework and parent them to the correct moving component. Match their local axis conventions before import. Do not guess new conventions if the existing project can be inspected.

## 7. Checks and Special Notes

Drum must clear the trigger hand and removal path. Drum outer shell stays stationary during fire; no invented whole-drum spinning animation.

Reuse rifle hand proportions and stock materials. Keep shotgun-shell effects distinct from rifle casing effects.

Check hands, camera framing, component travel, reload clearance and the opposite side during inspect. Confirm that the mesh, rig and effect references agree; avoid accidental intersecting hands, floating magazines and unsupported animated parts.

## 8. Deliverables

- Organized source Blender project (`.blend`).
- Roblox-compatible exported meshes (`FBX`) and required textures.
- Correct UVs, material assignments, names, origins and rest transforms.
- Separate moving parts with useful pivots and animation-ready hierarchy.
- Named attachment reference points with consistent orientation.
- Matching three-quarter and side previews of the final model.
- Short import/setup notes identifying remaining Roblox joint work.
- A component-motion check and Roblox import check for scale, shading and separation.

Animations do not all need to be finished now. The model must support them without rebuilding its main structure. Review it beside Vandal, Phantom and Classic before delivery.

---


# 04. Stinger Replacement — Uzi-Inspired SMG — Blender Modeling Brief

## 1. Overall Design

Use the matching generated Stinger Replacement — Uzi-Inspired SMG concept sheet as the primary visual reference. Create an original polished game-ready Roblox asset in the same family as the approved Vandal, Phantom and Classic. Match the silhouette, major proportions, materials and amount of blockiness while simplifying minor detail where useful.

**Identity:** Compact magazine-in-grip automatic SMG.

**Chosen design:** Original Uzi-inspired boxy compact receiver, long straight magazine inserted through pistol grip, short exposed barrel with simple muzzle, small forward handguard and compact extended skeletal metal stock. No suppressor. Clear magazine-in-grip silhouette; not Valorant Stinger geometry.

Use broad readable moderately blocky forms, clean shading and selective small bevels. Keep the prop attractive both close up in first person and at third-person distance. Resolve small image inconsistencies into one coherent model; prioritize the described category and key distinguishing parts.

## 2. Family Compatibility

Inspect the existing weapon assets first. Preserve scene units, export scale, axis conventions, character-hand proportions, root naming/orientation and the established Motor6D or bone workflow. A shared framework is required; weapon-specific hand poses and action animations are expected. Place correct origins and pivots, use clean rest transforms and avoid duplicate constraints. Do not permanently merge moving parts into the stationary body. Preserve this separation through export and document any Roblox-side joint setup. No detailed hidden mechanism is required.

Use one main weapon root following existing conventions, with the stationary body and independent animated components beneath it.

## 3. Textures and Materials

Use matte charcoal/graphite metal and near-black polymer with restrained roughness differences, clean fine surface texture, soft bevel highlights and tiny blue accents. Match the existing Vandal, Phantom and Classic rather than increasing detail or glow. Create clean UVs and Roblox-compatible base-color, normal, roughness and metalness maps where useful. Neon details are separate small meshes that follow the associated moving component. Avoid excessive wear, noisy textures and plain untextured brick colors.

## 4. Separate Components and Structure

| Component / group | Setup and movement |
| --- | --- |
| **Receiver / Barrel** | Stationary core. |
| **Magazine** | Long straight magazine removable from grip. |
| **ChargingHandle** | Independent manipulation control placed to match the upper-receiver detail in the sheet. |
| **Bolt** | Only visible cycling portion if included. |
| **Stock** | Stationary extended pose; optional fold hierarchy only if required. |
| **Trigger / Selector** | Separate visible controls. |

Only group parts that move together. Give reload props reusable geometry and consistent material assignments. Fixed decorative meshes follow their associated parent.

## 5. Animation Requirements

- SMG idle, equip, sustained fire, grip-magazine exchange, empty charging action, inspect, ADS transition and sprint.
- Support hand stays forward of magazine removal route.

**Aiming:** Iron-sight ADS as a proposed project default; ready to tune in game.
Prepare the stated aiming reference and transition. Final camera offsets, zoom and input behavior belong to the game configuration.

Use gameplay state and animation markers to control reload-prop visibility, sound and effects. Partial, empty and interrupted states must not duplicate ammunition props or create unintended movement. The mesh does not define capacity, damage or fire-rate balance.

## 6. Attachments and Reference Points

WeaponRoot, RightHandGrip, LeftHandGrip, MuzzleAttachment, EjectionAttachment, AimPoint and MagazineSeat. Match family orientation conventions.

Position references consistently with the existing framework and parent them to the correct moving component. Match their local axis conventions before import. Do not guess new conventions if the existing project can be inspected.

## 7. Checks and Special Notes

Use a proper support-hand surface; keep hands away from moving charging control. Verify extended magazine clears forearms and camera in reload.

Stock is depicted extended for silhouette and ADS. Folding animation is optional, not required for delivery. Do not add real brand marks.

Check hands, camera framing, component travel, reload clearance and the opposite side during inspect. Confirm that the mesh, rig and effect references agree; avoid accidental intersecting hands, floating magazines and unsupported animated parts.

## 8. Deliverables

- Organized source Blender project (`.blend`).
- Roblox-compatible exported meshes (`FBX`) and required textures.
- Correct UVs, material assignments, names, origins and rest transforms.
- Separate moving parts with useful pivots and animation-ready hierarchy.
- Named attachment reference points with consistent orientation.
- Matching three-quarter and side previews of the final model.
- Short import/setup notes identifying remaining Roblox joint work.
- A component-motion check and Roblox import check for scale, shading and separation.

Animations do not all need to be finished now. The model must support them without rebuilding its main structure. Review it beside Vandal, Phantom and Classic before delivery.

---


# 05. Spectre — Blender Modeling Brief

## 1. Overall Design

Use the matching generated Spectre concept sheet as the primary visual reference. Create an original polished game-ready Roblox asset in the same family as the approved Vandal, Phantom and Classic. Match the silhouette, major proportions, materials and amount of blockiness while simplifying minor detail where useful.

**Identity:** Refined suppressed compact SMG.

**Chosen design:** Slim compact SMG with a modest classic cylindrical suppressor, short vented handguard, slim slightly curved magazine ahead of trigger guard, compact tactical stock and low iron sights. Smaller lighter receiver than Phantom; magazine outside grip unlike Uzi.

Use broad readable moderately blocky forms, clean shading and selective small bevels. Keep the prop attractive both close up in first person and at third-person distance. Resolve small image inconsistencies into one coherent model; prioritize the described category and key distinguishing parts.

## 2. Family Compatibility

Inspect the existing weapon assets first. Preserve scene units, export scale, axis conventions, character-hand proportions, root naming/orientation and the established Motor6D or bone workflow. A shared framework is required; weapon-specific hand poses and action animations are expected. Place correct origins and pivots, use clean rest transforms and avoid duplicate constraints. Do not permanently merge moving parts into the stationary body. Preserve this separation through export and document any Roblox-side joint setup. No detailed hidden mechanism is required.

Use one main weapon root following existing conventions, with the stationary body and independent animated components beneath it.

## 3. Textures and Materials

Use matte charcoal/graphite metal and near-black polymer with restrained roughness differences, clean fine surface texture, soft bevel highlights and tiny blue accents. Match the existing Vandal, Phantom and Classic rather than increasing detail or glow. Create clean UVs and Roblox-compatible base-color, normal, roughness and metalness maps where useful. Neon details are separate small meshes that follow the associated moving component. Avoid excessive wear, noisy textures and plain untextured brick colors.

## 4. Separate Components and Structure

| Component / group | Setup and movement |
| --- | --- |
| **Receiver / Handguard / Barrel / Suppressor / Stock** | Stationary body group. |
| **Magazine** | Independent forward magazine. |
| **ChargingHandle / Bolt** | Separate controls and visible moving elements. |
| **Trigger / Selector** | Separate visible controls. |

Only group parts that move together. Give reload props reusable geometry and consistent material assignments. Fixed decorative meshes follow their associated parent.

## 5. Animation Requirements

- Light two-handed idle, equip, automatic fire, tactical magazine swap, empty reload with charging action as selected, inspect, ADS transition and lowered sprint.

**Aiming:** Iron-sight ADS as a proposed project default.
Prepare the stated aiming reference and transition. Final camera offsets, zoom and input behavior belong to the game configuration.

Use gameplay state and animation markers to control reload-prop visibility, sound and effects. Partial, empty and interrupted states must not duplicate ammunition props or create unintended movement. The mesh does not define capacity, damage or fire-rate balance.

## 6. Attachments and Reference Points

WeaponRoot, RightHandGrip, LeftHandGrip, MuzzleAttachment at suppressor tip, EjectionAttachment, AimPoint and MagazineSeat.

Position references consistently with the existing framework and parent them to the correct moving component. Match their local axis conventions before import. Do not guess new conventions if the existing project can be inspected.

## 7. Checks and Special Notes

Maintain a lighter shorter silhouette than Phantom. Check support-hand placement and magazine clearance. Suppressor remains fixed during fire.

Share the Phantom's suppressor finish and small blue design vocabulary, but use SMG-specific proportions and handling.

Check hands, camera framing, component travel, reload clearance and the opposite side during inspect. Confirm that the mesh, rig and effect references agree; avoid accidental intersecting hands, floating magazines and unsupported animated parts.

## 8. Deliverables

- Organized source Blender project (`.blend`).
- Roblox-compatible exported meshes (`FBX`) and required textures.
- Correct UVs, material assignments, names, origins and rest transforms.
- Separate moving parts with useful pivots and animation-ready hierarchy.
- Named attachment reference points with consistent orientation.
- Matching three-quarter and side previews of the final model.
- Short import/setup notes identifying remaining Roblox joint work.
- A component-motion check and Roblox import check for scale, shading and separation.

Animations do not all need to be finished now. The model must support them without rebuilding its main structure. Review it beside Vandal, Phantom and Classic before delivery.

---


# 06. Bucky — Blender Modeling Brief

## 1. Overall Design

Use the matching generated Bucky concept sheet as the primary visual reference. Create an original polished game-ready Roblox asset in the same family as the approved Vandal, Phantom and Classic. Match the silhouette, major proportions, materials and amount of blockiness while simplifying minor detail where useful.

**Identity:** Long pump-action shotgun.

**Chosen design:** Long single shotgun barrel with a visibly separate tubular magazine directly underneath, ribbed sliding pump fore-end, conventional compact full shoulder stock with pistol grip, clean long receiver and tiny iron sights. More slender and longer than Judge; no drum or detachable box magazine.

Use broad readable moderately blocky forms, clean shading and selective small bevels. Keep the prop attractive both close up in first person and at third-person distance. Resolve small image inconsistencies into one coherent model; prioritize the described category and key distinguishing parts.

## 2. Family Compatibility

Inspect the existing weapon assets first. Preserve scene units, export scale, axis conventions, character-hand proportions, root naming/orientation and the established Motor6D or bone workflow. A shared framework is required; weapon-specific hand poses and action animations are expected. Place correct origins and pivots, use clean rest transforms and avoid duplicate constraints. Do not permanently merge moving parts into the stationary body. Preserve this separation through export and document any Roblox-side joint setup. No detailed hidden mechanism is required.

Use one main weapon root following existing conventions, with the stationary body and independent animated components beneath it.

## 3. Textures and Materials

Use matte charcoal/graphite metal and near-black polymer with restrained roughness differences, clean fine surface texture, soft bevel highlights and tiny blue accents. Match the existing Vandal, Phantom and Classic rather than increasing detail or glow. Create clean UVs and Roblox-compatible base-color, normal, roughness and metalness maps where useful. Neon details are separate small meshes that follow the associated moving component. Avoid excessive wear, noisy textures and plain untextured brick colors.

## 4. Separate Components and Structure

| Component / group | Setup and movement |
| --- | --- |
| **Receiver / Barrel / MagazineTube / Stock** | Stationary main group. |
| **Pump** | Independent sliding fore-end. |
| **Bolt / ActionLink** | Visible action pieces following pump motion where needed. |
| **Trigger** | Independent cosmetic rotation. |
| **LoadingGate** | Separate only if visible during reload. |
| **ShellProp** | Reusable visual shell for loading. |

Only group parts that move together. Give reload props reusable geometry and consistent material assignments. Fixed decorative meshes follow their associated parent.

## 5. Animation Requirements

- Idle, equip, fire followed by pump-back/eject and pump-forward, shell-by-shell reload loop with start/insert/end, empty reload variant, interrupted reload, inspect and sprint.
- Do not pump again automatically at reload end if state does not require it.

**Aiming:** None. Hip-fire holding only.
Do not create an ADS pose, camera alignment transition or ADS AimPoint for this asset. Keep modeled sights as visual details where present.

Use gameplay state and animation markers to control reload-prop visibility, sound and effects. Partial, empty and interrupted states must not duplicate ammunition props or create unintended movement. The mesh does not define capacity, damage or fire-rate balance.

## 6. Attachments and Reference Points

WeaponRoot, MuzzleAttachment, EjectionAttachment, RightHandGrip, LeftHandGrip on Pump, ShellLoadPoint and ChamberReference. No ADS AimPoint.

Position references consistently with the existing framework and parent them to the correct moving component. Match their local axis conventions before import. Do not guess new conventions if the existing project can be inspected.

## 7. Checks and Special Notes

Support hand follows moving pump exactly. Tube remains stationary. Verify loading-hand clearance and prevent duplicated shell effects between pump and firing events.

Use animation events to drive visual shells and sound cues. Capacity and timing are game configuration values, not dimensions to engineer.

Check hands, camera framing, component travel, reload clearance and the opposite side during inspect. Confirm that the mesh, rig and effect references agree; avoid accidental intersecting hands, floating magazines and unsupported animated parts.

## 8. Deliverables

- Organized source Blender project (`.blend`).
- Roblox-compatible exported meshes (`FBX`) and required textures.
- Correct UVs, material assignments, names, origins and rest transforms.
- Separate moving parts with useful pivots and animation-ready hierarchy.
- Named attachment reference points with consistent orientation.
- Matching three-quarter and side previews of the final model.
- Short import/setup notes identifying remaining Roblox joint work.
- A component-motion check and Roblox import check for scale, shading and separation.

Animations do not all need to be finished now. The model must support them without rebuilding its main structure. Review it beside Vandal, Phantom and Classic before delivery.

---


# 07. Sheriff — Blender Modeling Brief

## 1. Overall Design

Use the matching generated Sheriff concept sheet as the primary visual reference. Create an original polished game-ready Roblox asset in the same family as the approved Vandal, Phantom and Classic. Match the silhouette, major proportions, materials and amount of blockiness while simplifying minor detail where useful.

**Identity:** Heavy six-shot tactical revolver.

**Chosen design:** Sturdy original six-shot revolver, medium-long thick conventional barrel with flat top rib, unmistakable six-chamber cylinder, angular charcoal frame, compact exposed hammer and ergonomic near-black polymer grip. More substantial than Classic but not an oversized fantasy hand cannon. No scope, suppressor or detachable magazine.

Use broad readable moderately blocky forms, clean shading and selective small bevels. Keep the prop attractive both close up in first person and at third-person distance. Resolve small image inconsistencies into one coherent model; prioritize the described category and key distinguishing parts.

## 2. Family Compatibility

Inspect the existing weapon assets first. Preserve scene units, export scale, axis conventions, character-hand proportions, root naming/orientation and the established Motor6D or bone workflow. A shared framework is required; weapon-specific hand poses and action animations are expected. Place correct origins and pivots, use clean rest transforms and avoid duplicate constraints. Do not permanently merge moving parts into the stationary body. Preserve this separation through export and document any Roblox-side joint setup. No detailed hidden mechanism is required.

Use one main weapon root following existing conventions, with the stationary body and independent animated components beneath it.

## 3. Textures and Materials

Use matte charcoal/graphite metal and near-black polymer with restrained roughness differences, clean fine surface texture, soft bevel highlights and tiny blue accents. Match the existing Vandal, Phantom and Classic rather than increasing detail or glow. Create clean UVs and Roblox-compatible base-color, normal, roughness and metalness maps where useful. Neon details are separate small meshes that follow the associated moving component. Avoid excessive wear, noisy textures and plain untextured brick colors.

## 4. Separate Components and Structure

| Component / group | Setup and movement |
| --- | --- |
| **Frame / Barrel / Grip** | Stationary body group. |
| **CylinderCrane** | Side-swinging hinge carrying cylinder assembly. |
| **Cylinder** | Six-chamber visual cylinder with independent indexing rotation. |
| **EjectorRod** | Independent cosmetic sliding motion. |
| **Hammer / Trigger** | Independent rotation pivots. |
| **CylinderRelease** | Separate visible control. |
| **RoundProps / Speedloader** | Reusable reload props outside permanent weapon mesh. |

Only group parts that move together. Give reload props reusable geometry and consistent material assignments. Fixed decorative meshes follow their associated parent.

## 5. Animation Requirements

- Revolver idle, equip, hammer/trigger fire motion and one-chamber cylinder indexing, open cylinder, eject spent cases, reload using a speedloader with a cleared support-hand path, close cylinder, inspect and sprint.
- Prepare partial-ammo visual states.
- No semiautomatic slide or detachable grip magazine.

**Aiming:** None. Hip-fire holding only.
Do not create an ADS pose, camera alignment transition or ADS AimPoint for this asset. Keep modeled sights as visual details where present.

Use gameplay state and animation markers to control reload-prop visibility, sound and effects. Partial, empty and interrupted states must not duplicate ammunition props or create unintended movement. The mesh does not define capacity, damage or fire-rate balance.

## 6. Attachments and Reference Points

WeaponRoot, RightHandGrip, optional LeftHandGrip, MuzzleAttachment, CylinderAxis, Chamber_01 through Chamber_06, EjectorReference and ReloadInsertPoint. No ADS AimPoint.

Position references consistently with the existing framework and parent them to the correct moving component. Match their local axis conventions before import. Do not guess new conventions if the existing project can be inspected.

## 7. Checks and Special Notes

Cylinder rotates around its true center and swings on separate crane hinge. Keep all six chambers and case states aligned. Do not spin cylinder without matching chamber state during reload.

Use a restrained practical barrel length and compact readable controls. The mockup shows cylinder closed and no loose ammunition; props are needed only for future animation.

Check hands, camera framing, component travel, reload clearance and the opposite side during inspect. Confirm that the mesh, rig and effect references agree; avoid accidental intersecting hands, floating magazines and unsupported animated parts.

## 8. Deliverables

- Organized source Blender project (`.blend`).
- Roblox-compatible exported meshes (`FBX`) and required textures.
- Correct UVs, material assignments, names, origins and rest transforms.
- Separate moving parts with useful pivots and animation-ready hierarchy.
- Named attachment reference points with consistent orientation.
- Matching three-quarter and side previews of the final model.
- Short import/setup notes identifying remaining Roblox joint work.
- A component-motion check and Roblox import check for scale, shading and separation.

Animations do not all need to be finished now. The model must support them without rebuilding its main structure. Review it beside Vandal, Phantom and Classic before delivery.

---


# 08. Bulldog — Blender Modeling Brief

## 1. Overall Design

Use the matching generated Bulldog concept sheet as the primary visual reference. Create an original polished game-ready Roblox asset in the same family as the approved Vandal, Phantom and Classic. Match the silhouette, major proportions, materials and amount of blockiness while simplifying minor detail where useful.

**Identity:** Compact bullpup tactical rifle.

**Chosen design:** Clearly bullpup layout: short broad receiver, magazine BEHIND pistol grip within compact rear stock body, short conventional exposed barrel, compact fore-end and low iron sights. No suppressor. Angular and sturdy but less elongated than Vandal.

Use broad readable moderately blocky forms, clean shading and selective small bevels. Keep the prop attractive both close up in first person and at third-person distance. Resolve small image inconsistencies into one coherent model; prioritize the described category and key distinguishing parts.

## 2. Family Compatibility

Inspect the existing weapon assets first. Preserve scene units, export scale, axis conventions, character-hand proportions, root naming/orientation and the established Motor6D or bone workflow. A shared framework is required; weapon-specific hand poses and action animations are expected. Place correct origins and pivots, use clean rest transforms and avoid duplicate constraints. Do not permanently merge moving parts into the stationary body. Preserve this separation through export and document any Roblox-side joint setup. No detailed hidden mechanism is required.

Use one main weapon root following existing conventions, with the stationary body and independent animated components beneath it.

## 3. Textures and Materials

Use matte charcoal/graphite metal and near-black polymer with restrained roughness differences, clean fine surface texture, soft bevel highlights and tiny blue accents. Match the existing Vandal, Phantom and Classic rather than increasing detail or glow. Create clean UVs and Roblox-compatible base-color, normal, roughness and metalness maps where useful. Neon details are separate small meshes that follow the associated moving component. Avoid excessive wear, noisy textures and plain untextured brick colors.

## 4. Separate Components and Structure

| Component / group | Setup and movement |
| --- | --- |
| **Receiver / Handguard / Barrel / Stock** | Stationary body group. |
| **Magazine** | Independent rear magazine behind grip. |
| **ChargingHandle / Bolt** | Separate manipulation and visible action pieces. |
| **Trigger / Selector** | Separate visible controls. |

Only group parts that move together. Give reload props reusable geometry and consistent material assignments. Fixed decorative meshes follow their associated parent.

## 5. Animation Requirements

- Bullpup-specific holding, equip, fire, rear magazine tactical and empty reloads, charging action if needed, inspect, ADS transition and sprint.
- A burst-mode animation uses normal shot events; do not hard-code burst count into mesh or rig.

**Aiming:** Iron-sight ADS. Prepare for optional gameplay burst mode without assuming final balance.
Prepare the stated aiming reference and transition. Final camera offsets, zoom and input behavior belong to the game configuration.

Use gameplay state and animation markers to control reload-prop visibility, sound and effects. Partial, empty and interrupted states must not duplicate ammunition props or create unintended movement. The mesh does not define capacity, damage or fire-rate balance.

## 6. Attachments and Reference Points

WeaponRoot, RightHandGrip, LeftHandGrip, MuzzleAttachment, EjectionAttachment, AimPoint and rear MagazineSeat.

Position references consistently with the existing framework and parent them to the correct moving component. Match their local axis conventions before import. Do not guess new conventions if the existing project can be inspected.

## 7. Checks and Special Notes

Do not copy Vandal's forward-magazine reload. Rear magazine must clear shoulder, forearm and stock. Keep trigger reach consistent with rifle family.

Re-use shared rifle grip dimensions where appropriate while preserving the bullpup mass distribution and short overall length.

Check hands, camera framing, component travel, reload clearance and the opposite side during inspect. Confirm that the mesh, rig and effect references agree; avoid accidental intersecting hands, floating magazines and unsupported animated parts.

## 8. Deliverables

- Organized source Blender project (`.blend`).
- Roblox-compatible exported meshes (`FBX`) and required textures.
- Correct UVs, material assignments, names, origins and rest transforms.
- Separate moving parts with useful pivots and animation-ready hierarchy.
- Named attachment reference points with consistent orientation.
- Matching three-quarter and side previews of the final model.
- Short import/setup notes identifying remaining Roblox joint work.
- A component-motion check and Roblox import check for scale, shading and separation.

Animations do not all need to be finished now. The model must support them without rebuilding its main structure. Review it beside Vandal, Phantom and Classic before delivery.

---


# 09. Guardian — Blender Modeling Brief

## 1. Overall Design

Use the matching generated Guardian concept sheet as the primary visual reference. Create an original polished game-ready Roblox asset in the same family as the approved Vandal, Phantom and Classic. Match the silhouette, major proportions, materials and amount of blockiness while simplifying minor detail where useful.

**Identity:** Long semiautomatic precision rifle.

**Chosen design:** Long clean precision-rifle silhouette, slender extended barrel with simple restrained muzzle brake, long refined handguard, modest mostly straight box magazine in front of trigger, substantial conventional tactical stock and precise low iron sights. More slender and controlled than Vandal, no suppressor or scope.

Use broad readable moderately blocky forms, clean shading and selective small bevels. Keep the prop attractive both close up in first person and at third-person distance. Resolve small image inconsistencies into one coherent model; prioritize the described category and key distinguishing parts.

## 2. Family Compatibility

Inspect the existing weapon assets first. Preserve scene units, export scale, axis conventions, character-hand proportions, root naming/orientation and the established Motor6D or bone workflow. A shared framework is required; weapon-specific hand poses and action animations are expected. Place correct origins and pivots, use clean rest transforms and avoid duplicate constraints. Do not permanently merge moving parts into the stationary body. Preserve this separation through export and document any Roblox-side joint setup. No detailed hidden mechanism is required.

Use one main weapon root following existing conventions, with the stationary body and independent animated components beneath it.

## 3. Textures and Materials

Use matte charcoal/graphite metal and near-black polymer with restrained roughness differences, clean fine surface texture, soft bevel highlights and tiny blue accents. Match the existing Vandal, Phantom and Classic rather than increasing detail or glow. Create clean UVs and Roblox-compatible base-color, normal, roughness and metalness maps where useful. Neon details are separate small meshes that follow the associated moving component. Avoid excessive wear, noisy textures and plain untextured brick colors.

## 4. Separate Components and Structure

| Component / group | Setup and movement |
| --- | --- |
| **Receiver / Handguard / Barrel / Stock** | Stationary group. |
| **Magazine** | Independent straight box magazine. |
| **ChargingHandle / Bolt** | Separate manipulation and visible action pieces. |
| **Trigger / Selector** | Separate visible controls where present. |

Only group parts that move together. Give reload props reusable geometry and consistent material assignments. Fixed decorative meshes follow their associated parent.

## 5. Animation Requirements

- Steady precision idle, equip, individual semiautomatic shots, tactical reload, empty reload with chosen release/charging action, inspect, ADS transition and sprint.
- No manual bolt cycle between normal shots.

**Aiming:** Iron-sight ADS; no scope on default model.
Prepare the stated aiming reference and transition. Final camera offsets, zoom and input behavior belong to the game configuration.

Use gameplay state and animation markers to control reload-prop visibility, sound and effects. Partial, empty and interrupted states must not duplicate ammunition props or create unintended movement. The mesh does not define capacity, damage or fire-rate balance.

## 6. Attachments and Reference Points

WeaponRoot, RightHandGrip, LeftHandGrip, MuzzleAttachment, EjectionAttachment, AimPoint and MagazineSeat.

Position references consistently with the existing framework and parent them to the correct moving component. Match their local axis conventions before import. Do not guess new conventions if the existing project can be inspected.

## 7. Checks and Special Notes

Keep iron sights coherent and eye alignment clear. Long barrel must remain in frame and not collide with first-person hands. Avoid oversized magazine or heavy machine-gun bulk.

Differentiate this precision rifle from the scoped sniper trio and preserve common rifle hand/root conventions.

Check hands, camera framing, component travel, reload clearance and the opposite side during inspect. Confirm that the mesh, rig and effect references agree; avoid accidental intersecting hands, floating magazines and unsupported animated parts.

## 8. Deliverables

- Organized source Blender project (`.blend`).
- Roblox-compatible exported meshes (`FBX`) and required textures.
- Correct UVs, material assignments, names, origins and rest transforms.
- Separate moving parts with useful pivots and animation-ready hierarchy.
- Named attachment reference points with consistent orientation.
- Matching three-quarter and side previews of the final model.
- Short import/setup notes identifying remaining Roblox joint work.
- A component-motion check and Roblox import check for scale, shading and separation.

Animations do not all need to be finished now. The model must support them without rebuilding its main structure. Review it beside Vandal, Phantom and Classic before delivery.

---


# 10. Basic Knife — Blender Modeling Brief

## 1. Overall Design

Use the matching generated Basic Knife concept sheet as the primary visual reference. Create an original polished game-ready Roblox asset in the same family as the approved Vandal, Phantom and Classic. Match the silhouette, major proportions, materials and amount of blockiness while simplifying minor detail where useful.

**Identity:** Simple tactical melee knife.

**Chosen design:** Single modest drop-point tactical blade with straight plain cutting edge, dark charcoal blade flats, narrow satin-gray bevel, compact guard, textured near-black polymer handle and small pommel. One tiny blue handle inset. No serrations, holes, fantasy spikes, oversized blade or glowing cutting edge.

Use broad readable moderately blocky forms, clean shading and selective small bevels. Keep the prop attractive both close up in first person and at third-person distance. Resolve small image inconsistencies into one coherent model; prioritize the described category and key distinguishing parts.

## 2. Family Compatibility

Inspect the existing weapon assets first. Preserve scene units, export scale, axis conventions, character-hand proportions, root naming/orientation and the established Motor6D or bone workflow. A shared framework is required; weapon-specific hand poses and action animations are expected. Place correct origins and pivots, use clean rest transforms and avoid duplicate constraints. Do not permanently merge moving parts into the stationary body. Preserve this separation through export and document any Roblox-side joint setup. No detailed hidden mechanism is required.

Use one main weapon root following existing conventions, with the stationary body and independent animated components beneath it.

## 3. Textures and Materials

Use matte charcoal/graphite metal and near-black polymer with restrained roughness differences, clean fine surface texture, soft bevel highlights and tiny blue accents. Match the existing Vandal, Phantom and Classic rather than increasing detail or glow. Create clean UVs and Roblox-compatible base-color, normal, roughness and metalness maps where useful. Neon details are separate small meshes that follow the associated moving component. Avoid excessive wear, noisy textures and plain untextured brick colors.

## 4. Separate Components and Structure

| Component / group | Setup and movement |
| --- | --- |
| **Blade / Guard / Handle / Pommel** | Rigidly joined visual parts under KnifeRoot; no internal moving mechanism. |
| **BlueAccent** | Small fixed handle mesh. |

Only group parts that move together. Give reload props reusable geometry and consistent material assignments. Fixed decorative meshes follow their associated parent.

## 5. Animation Requirements

- Pistol-independent knife hold, equip/unequip, several readable swing directions, optional heavier thrust, recovery, inspect, sprint and lowered state.
- Any reverse-grip inspect is optional and requires explicit hand poses.

**Aiming:** None.
Do not create an ADS pose, camera alignment transition or ADS AimPoint for this asset. Keep modeled sights as visual details where present.

Use gameplay state and animation markers to control reload-prop visibility, sound and effects. Partial, empty and interrupted states must not duplicate ammunition props or create unintended movement. The mesh does not define capacity, damage or fire-rate balance.

## 6. Attachments and Reference Points

KnifeRoot under the common weapon interface, RightHandGrip, BladeBase and BladeTip as melee trace reference points. No muzzle, casing ejection or ADS attachments.

Position references consistently with the existing framework and parent them to the correct moving component. Match their local axis conventions before import. Do not guess new conventions if the existing project can be inspected.

## 7. Checks and Special Notes

Check guard clearance, grip stability and full swing arcs. Drive melee hit detection from gameplay traces using references, not from visual mesh collision alone.

Concept layout changes only for this asset: blade tip left, handle right in the hero render and matching flat side view. No scabbard or additional knife variants.

Check hands, camera framing, component travel, reload clearance and the opposite side during inspect. Confirm that the mesh, rig and effect references agree; avoid accidental intersecting hands, floating magazines and unsupported animated parts.

## 8. Deliverables

- Organized source Blender project (`.blend`).
- Roblox-compatible exported meshes (`FBX`) and required textures.
- Correct UVs, material assignments, names, origins and rest transforms.
- Separate moving parts with useful pivots and animation-ready hierarchy.
- Named attachment reference points with consistent orientation.
- Matching three-quarter and side previews of the final model.
- Short import/setup notes identifying remaining Roblox joint work.
- A component-motion check and Roblox import check for scale, shading and separation.

Animations do not all need to be finished now. The model must support them without rebuilding its main structure. Review it beside Vandal, Phantom and Classic before delivery.

---


# 11. Marshal — Blender Modeling Brief

## 1. Overall Design

Use the matching generated Marshal concept sheet as the primary visual reference. Create an original polished game-ready Roblox asset in the same family as the approved Vandal, Phantom and Classic. Match the silhouette, major proportions, materials and amount of blockiness while simplifying minor detail where useful.

**Identity:** Light lever-action scoped rifle.

**Chosen design:** Slim long barrel, narrow receiver, UNDER-RECEIVER LEVER LOOP around trigger area, slim under-barrel tubular magazine, lightweight classic polymer shoulder stock and small practical scope. No detachable box magazine, no bolt handle, no suppressor. Contemporary charcoal tactical treatment, not ornate western styling.

Use broad readable moderately blocky forms, clean shading and selective small bevels. Keep the prop attractive both close up in first person and at third-person distance. Resolve small image inconsistencies into one coherent model; prioritize the described category and key distinguishing parts.

## 2. Family Compatibility

Inspect the existing weapon assets first. Preserve scene units, export scale, axis conventions, character-hand proportions, root naming/orientation and the established Motor6D or bone workflow. A shared framework is required; weapon-specific hand poses and action animations are expected. Place correct origins and pivots, use clean rest transforms and avoid duplicate constraints. Do not permanently merge moving parts into the stationary body. Preserve this separation through export and document any Roblox-side joint setup. No detailed hidden mechanism is required.

Use one main weapon root following existing conventions, with the stationary body and independent animated components beneath it.

## 3. Textures and Materials

Use matte charcoal/graphite metal and near-black polymer with restrained roughness differences, clean fine surface texture, soft bevel highlights and tiny blue accents. Match the existing Vandal, Phantom and Classic rather than increasing detail or glow. Create clean UVs and Roblox-compatible base-color, normal, roughness and metalness maps where useful. Neon details are separate small meshes that follow the associated moving component. Avoid excessive wear, noisy textures and plain untextured brick colors.

## 4. Separate Components and Structure

| Component / group | Setup and movement |
| --- | --- |
| **Receiver / Barrel / MagazineTube / Stock / Scope** | Stationary group. |
| **Lever** | Independent rotating lever loop. |
| **Bolt** | Visible part follows lever cycle if included. |
| **Trigger** | Separate component associated appropriately with lever/frame geometry. |
| **LoadingGate** | If visible for loading. |
| **RoundProp** | Reusable visual loading prop. |

Only group parts that move together. Give reload props reusable geometry and consistent material assignments. Fixed decorative meshes follow their associated parent.

## 5. Animation Requirements

- Light scoped rifle idle, equip, fire then lever-open/eject/lever-close cycle, shell-by-shell loading start/loop/end and interrupted reload, empty-state variation, scoped transition, inspect and sprint.

**Aiming:** Scoped aiming with a fixed optic; project controls zoom and camera overlay.
Prepare the stated aiming reference and transition. Final camera offsets, zoom and input behavior belong to the game configuration.

Use gameplay state and animation markers to control reload-prop visibility, sound and effects. Partial, empty and interrupted states must not duplicate ammunition props or create unintended movement. The mesh does not define capacity, damage or fire-rate balance.

## 6. Attachments and Reference Points

WeaponRoot, MuzzleAttachment, EjectionAttachment, RightHandGrip, LeftHandGrip, AimPoint/ScopeEye at ocular end, ScopeAxis and LoadPoint.

Position references consistently with the existing framework and parent them to the correct moving component. Match their local axis conventions before import. Do not guess new conventions if the existing project can be inspected.

## 7. Checks and Special Notes

Do not animate as bolt-action or detachable magazine rifle. Trigger hand must accommodate lever swing; keep scope stationary and eye position coherent.

Our chosen original variant uses tubular loading to reinforce lever-action identity. Optic lenses are non-emissive dark glass; reticle/zoom primarily belongs to the game's scope system.

Check hands, camera framing, component travel, reload clearance and the opposite side during inspect. Confirm that the mesh, rig and effect references agree; avoid accidental intersecting hands, floating magazines and unsupported animated parts.

## 8. Deliverables

- Organized source Blender project (`.blend`).
- Roblox-compatible exported meshes (`FBX`) and required textures.
- Correct UVs, material assignments, names, origins and rest transforms.
- Separate moving parts with useful pivots and animation-ready hierarchy.
- Named attachment reference points with consistent orientation.
- Matching three-quarter and side previews of the final model.
- Short import/setup notes identifying remaining Roblox joint work.
- A component-motion check and Roblox import check for scale, shading and separation.

Animations do not all need to be finished now. The model must support them without rebuilding its main structure. Review it beside Vandal, Phantom and Classic before delivery.

---


# 12. Outlaw — Blender Modeling Brief

## 1. Overall Design

Use the matching generated Outlaw concept sheet as the primary visual reference. Create an original polished game-ready Roblox asset in the same family as the approved Vandal, Phantom and Classic. Match the silhouette, major proportions, materials and amount of blockiness while simplifying minor detail where useful.

**Identity:** Twin-barrel break-action scoped rifle.

**Chosen design:** Distinct medium-heavy double-barrel rifle with TWO VERTICALLY STACKED long barrels, substantial hinged breech, full tactical stock and mid-size scope mounted on the stationary receiver. Short fore-end joined to barrel assembly. No detachable magazine or bolt handle. Larger than Marshal but lighter than Operator.

Use broad readable moderately blocky forms, clean shading and selective small bevels. Keep the prop attractive both close up in first person and at third-person distance. Resolve small image inconsistencies into one coherent model; prioritize the described category and key distinguishing parts.

## 2. Family Compatibility

Inspect the existing weapon assets first. Preserve scene units, export scale, axis conventions, character-hand proportions, root naming/orientation and the established Motor6D or bone workflow. A shared framework is required; weapon-specific hand poses and action animations are expected. Place correct origins and pivots, use clean rest transforms and avoid duplicate constraints. Do not permanently merge moving parts into the stationary body. Preserve this separation through export and document any Roblox-side joint setup. No detailed hidden mechanism is required.

Use one main weapon root following existing conventions, with the stationary body and independent animated components beneath it.

## 3. Textures and Materials

Use matte charcoal/graphite metal and near-black polymer with restrained roughness differences, clean fine surface texture, soft bevel highlights and tiny blue accents. Match the existing Vandal, Phantom and Classic rather than increasing detail or glow. Create clean UVs and Roblox-compatible base-color, normal, roughness and metalness maps where useful. Neon details are separate small meshes that follow the associated moving component. Avoid excessive wear, noisy textures and plain untextured brick colors.

## 4. Separate Components and Structure

| Component / group | Setup and movement |
| --- | --- |
| **Receiver / Stock / Scope** | Stationary rear body and optic. |
| **BarrelAssembly / ForeEnd** | Two barrels and fore-end share one opening hinge. |
| **BreechLatch** | Independent visible release. |
| **Extractor / Ejector** | Only visible cosmetic pieces needed for reload. |
| **Round_Upper / Round_Lower** | Independent visual round props. |
| **Trigger** | Separate cosmetic component. |

Only group parts that move together. Give reload props reusable geometry and consistent material assignments. Fixed decorative meshes follow their associated parent.

## 5. Animation Requirements

- Idle, equip, upper/lower shot visual states, two shots without manual cycling between them, break-open reload, separate one-round and two-round reload variants, close action, scoped transition, inspect and sprint.

**Aiming:** Scoped aiming with a fixed optic.
Prepare the stated aiming reference and transition. Final camera offsets, zoom and input behavior belong to the game configuration.

Use gameplay state and animation markers to control reload-prop visibility, sound and effects. Partial, empty and interrupted states must not duplicate ammunition props or create unintended movement. The mesh does not define capacity, damage or fire-rate balance.

## 6. Attachments and Reference Points

WeaponRoot, RightHandGrip, LeftHandGrip on ForeEnd, MuzzleAttachment_Upper/Lower, Chamber_Upper/Lower, per-chamber ejection references, AimPoint/ScopeEye and ScopeAxis.

Position references consistently with the existing framework and parent them to the correct moving component. Match their local axis conventions before import. Do not guess new conventions if the existing project can be inspected.

## 7. Checks and Special Notes

Scope stays on stationary receiver during opening. Both barrel bores remain vertically aligned; no third barrel or detachable magazine. Track spent/live rounds separately for partial reload.

Two barrel emission points select the active shot. Opening animation needs hand and scope clearance, not a physically engineered internal action.

Check hands, camera framing, component travel, reload clearance and the opposite side during inspect. Confirm that the mesh, rig and effect references agree; avoid accidental intersecting hands, floating magazines and unsupported animated parts.

## 8. Deliverables

- Organized source Blender project (`.blend`).
- Roblox-compatible exported meshes (`FBX`) and required textures.
- Correct UVs, material assignments, names, origins and rest transforms.
- Separate moving parts with useful pivots and animation-ready hierarchy.
- Named attachment reference points with consistent orientation.
- Matching three-quarter and side previews of the final model.
- Short import/setup notes identifying remaining Roblox joint work.
- A component-motion check and Roblox import check for scale, shading and separation.

Animations do not all need to be finished now. The model must support them without rebuilding its main structure. Review it beside Vandal, Phantom and Classic before delivery.

---


# 13. Operator — Blender Modeling Brief

## 1. Overall Design

Use the matching generated Operator concept sheet as the primary visual reference. Create an original polished game-ready Roblox asset in the same family as the approved Vandal, Phantom and Classic. Match the silhouette, major proportions, materials and amount of blockiness while simplifying minor detail where useful.

**Identity:** Heavy bolt-action sniper rifle.

**Chosen design:** Longest and heaviest scoped rifle in the set: substantial long barrel with broad but restrained muzzle brake, large traditional telescopic scope, deep angular receiver, obvious right-side bolt handle, detachable straight box magazine and sturdy adjustable-looking full tactical stock. No suppressor or deployed bipod.

Use broad readable moderately blocky forms, clean shading and selective small bevels. Keep the prop attractive both close up in first person and at third-person distance. Resolve small image inconsistencies into one coherent model; prioritize the described category and key distinguishing parts.

## 2. Family Compatibility

Inspect the existing weapon assets first. Preserve scene units, export scale, axis conventions, character-hand proportions, root naming/orientation and the established Motor6D or bone workflow. A shared framework is required; weapon-specific hand poses and action animations are expected. Place correct origins and pivots, use clean rest transforms and avoid duplicate constraints. Do not permanently merge moving parts into the stationary body. Preserve this separation through export and document any Roblox-side joint setup. No detailed hidden mechanism is required.

Use one main weapon root following existing conventions, with the stationary body and independent animated components beneath it.

## 3. Textures and Materials

Use matte charcoal/graphite metal and near-black polymer with restrained roughness differences, clean fine surface texture, soft bevel highlights and tiny blue accents. Match the existing Vandal, Phantom and Classic rather than increasing detail or glow. Create clean UVs and Roblox-compatible base-color, normal, roughness and metalness maps where useful. Neon details are separate small meshes that follow the associated moving component. Avoid excessive wear, noisy textures and plain untextured brick colors.

## 4. Separate Components and Structure

| Component / group | Setup and movement |
| --- | --- |
| **Receiver / Barrel / Handguard / Stock / Scope** | Stationary body group. |
| **Bolt / BoltHandle** | Independent animation group with visible rotate/lift and slide-back/forward poses. |
| **Magazine** | Detachable box magazine. |
| **Trigger** | Independent rotation. |
| **StockAdjustment** | Only if optional stock movement is implemented. |

Only group parts that move together. Give reload props reusable geometry and consistent material assignments. Fixed decorative meshes follow their associated parent.

## 5. Animation Requirements

- Heavy idle, deliberate equip, fire then manual bolt lift/pull/eject/push/lock cycle, tactical magazine reload, empty reload with state-appropriate bolt sequence, scoped transition, inspect and lowered sprint.

**Aiming:** Scoped aiming; support optional multiple zoom levels in gameplay without moving optic geometry.
Prepare the stated aiming reference and transition. Final camera offsets, zoom and input behavior belong to the game configuration.

Use gameplay state and animation markers to control reload-prop visibility, sound and effects. Partial, empty and interrupted states must not duplicate ammunition props or create unintended movement. The mesh does not define capacity, damage or fire-rate balance.

## 6. Attachments and Reference Points

WeaponRoot, RightHandGrip, LeftHandGrip, MuzzleAttachment, EjectionAttachment, AimPoint/ScopeEye, ScopeAxis and MagazineSeat.

Position references consistently with the existing framework and parent them to the correct moving component. Match their local axis conventions before import. Do not guess new conventions if the existing project can be inspected.

## 7. Checks and Special Notes

Bolt path clears scope and hand. Do not auto-cycle like semiautomatic rifle. Preserve muzzle and stock within preview frame and avoid scope camera clipping.

Keep large forms weighty but within the same medium-blocky family. Gameplay owns zoom changes and scope overlay; physical lens should not contain baked screen-space reticle.

Check hands, camera framing, component travel, reload clearance and the opposite side during inspect. Confirm that the mesh, rig and effect references agree; avoid accidental intersecting hands, floating magazines and unsupported animated parts.

## 8. Deliverables

- Organized source Blender project (`.blend`).
- Roblox-compatible exported meshes (`FBX`) and required textures.
- Correct UVs, material assignments, names, origins and rest transforms.
- Separate moving parts with useful pivots and animation-ready hierarchy.
- Named attachment reference points with consistent orientation.
- Matching three-quarter and side previews of the final model.
- Short import/setup notes identifying remaining Roblox joint work.
- A component-motion check and Roblox import check for scale, shading and separation.

Animations do not all need to be finished now. The model must support them without rebuilding its main structure. Review it beside Vandal, Phantom and Classic before delivery.

---


# 14. Ares — Blender Modeling Brief

## 1. Overall Design

Use the matching generated Ares concept sheet as the primary visual reference. Create an original polished game-ready Roblox asset in the same family as the approved Vandal, Phantom and Classic. Match the silhouette, major proportions, materials and amount of blockiness while simplifying minor detail where useful.

**Identity:** Compact drum-fed light machine gun.

**Chosen design:** Medium-large light machine gun, long sturdy barrel, compact angular receiver, medium vented handguard, substantial detachable cylindrical drum magazine underneath ahead of trigger, full tactical stock and low iron sights. More elongated and rifle-like than Judge, clearly lighter and slimmer than Odin. No exposed belt feed.

Use broad readable moderately blocky forms, clean shading and selective small bevels. Keep the prop attractive both close up in first person and at third-person distance. Resolve small image inconsistencies into one coherent model; prioritize the described category and key distinguishing parts.

## 2. Family Compatibility

Inspect the existing weapon assets first. Preserve scene units, export scale, axis conventions, character-hand proportions, root naming/orientation and the established Motor6D or bone workflow. A shared framework is required; weapon-specific hand poses and action animations are expected. Place correct origins and pivots, use clean rest transforms and avoid duplicate constraints. Do not permanently merge moving parts into the stationary body. Preserve this separation through export and document any Roblox-side joint setup. No detailed hidden mechanism is required.

Use one main weapon root following existing conventions, with the stationary body and independent animated components beneath it.

## 3. Textures and Materials

Use matte charcoal/graphite metal and near-black polymer with restrained roughness differences, clean fine surface texture, soft bevel highlights and tiny blue accents. Match the existing Vandal, Phantom and Classic rather than increasing detail or glow. Create clean UVs and Roblox-compatible base-color, normal, roughness and metalness maps where useful. Neon details are separate small meshes that follow the associated moving component. Avoid excessive wear, noisy textures and plain untextured brick colors.

## 4. Separate Components and Structure

| Component / group | Setup and movement |
| --- | --- |
| **Receiver / Barrel / Handguard / Stock** | Stationary group. |
| **DrumMagazine** | Detachable single assembly. |
| **ChargingHandle / Bolt** | Separate visible moving components. |
| **Trigger / Selector** | Separate visible controls. |

Only group parts that move together. Give reload props reusable geometry and consistent material assignments. Fixed decorative meshes follow their associated parent.

## 5. Animation Requirements

- Weighty rifle hold, equip, sustained automatic fire loop, drum removal/replacement, empty charging action, ADS transition, inspect and sprint.
- No rotating barrel and no entire drum spinning during fire.

**Aiming:** Iron-sight ADS as a proposed project default.
Prepare the stated aiming reference and transition. Final camera offsets, zoom and input behavior belong to the game configuration.

Use gameplay state and animation markers to control reload-prop visibility, sound and effects. Partial, empty and interrupted states must not duplicate ammunition props or create unintended movement. The mesh does not define capacity, damage or fire-rate balance.

## 6. Attachments and Reference Points

WeaponRoot, RightHandGrip, LeftHandGrip, MuzzleAttachment, EjectionAttachment, AimPoint and MagazineSeat.

Position references consistently with the existing framework and parent them to the correct moving component. Match their local axis conventions before import. Do not guess new conventions if the existing project can be inspected.

## 7. Checks and Special Notes

Keep drum clear of hands and reload path. Differentiate drum-fed rifle proportions from Judge's short thick shotgun and Odin's belt box.

Use a detachable drum specifically for this original Ares-family design. Fire-rate buildup and recoil behavior remain gameplay configuration, not mechanical geometry requirements.

Check hands, camera framing, component travel, reload clearance and the opposite side during inspect. Confirm that the mesh, rig and effect references agree; avoid accidental intersecting hands, floating magazines and unsupported animated parts.

## 8. Deliverables

- Organized source Blender project (`.blend`).
- Roblox-compatible exported meshes (`FBX`) and required textures.
- Correct UVs, material assignments, names, origins and rest transforms.
- Separate moving parts with useful pivots and animation-ready hierarchy.
- Named attachment reference points with consistent orientation.
- Matching three-quarter and side previews of the final model.
- Short import/setup notes identifying remaining Roblox joint work.
- A component-motion check and Roblox import check for scale, shading and separation.

Animations do not all need to be finished now. The model must support them without rebuilding its main structure. Review it beside Vandal, Phantom and Classic before delivery.

---


# 15. Odin — Blender Modeling Brief

## 1. Overall Design

Use the matching generated Odin concept sheet as the primary visual reference. Create an original polished game-ready Roblox asset in the same family as the approved Vandal, Phantom and Classic. Match the silhouette, major proportions, materials and amount of blockiness while simplifying minor detail where useful.

**Identity:** Large belt-fed heavy machine gun.

**Chosen design:** Largest and heaviest automatic weapon: broad receiver, thick long barrel in restrained vented shroud, large rectangular belt-ammunition box below/alongside receiver, short visible belt section leading to feed tray, hinged top feed cover, sturdy shoulder stock, robust fore-end and low iron sights. No rotary barrels, no sci-fi minigun.

Use broad readable moderately blocky forms, clean shading and selective small bevels. Keep the prop attractive both close up in first person and at third-person distance. Resolve small image inconsistencies into one coherent model; prioritize the described category and key distinguishing parts.

## 2. Family Compatibility

Inspect the existing weapon assets first. Preserve scene units, export scale, axis conventions, character-hand proportions, root naming/orientation and the established Motor6D or bone workflow. A shared framework is required; weapon-specific hand poses and action animations are expected. Place correct origins and pivots, use clean rest transforms and avoid duplicate constraints. Do not permanently merge moving parts into the stationary body. Preserve this separation through export and document any Roblox-side joint setup. No detailed hidden mechanism is required.

Use one main weapon root following existing conventions, with the stationary body and independent animated components beneath it.

## 3. Textures and Materials

Use matte charcoal/graphite metal and near-black polymer with restrained roughness differences, clean fine surface texture, soft bevel highlights and tiny blue accents. Match the existing Vandal, Phantom and Classic rather than increasing detail or glow. Create clean UVs and Roblox-compatible base-color, normal, roughness and metalness maps where useful. Neon details are separate small meshes that follow the associated moving component. Avoid excessive wear, noisy textures and plain untextured brick colors.

## 4. Separate Components and Structure

| Component / group | Setup and movement |
| --- | --- |
| **Receiver / Barrel / Shroud / Stock** | Stationary body group. |
| **AmmoBox** | Independent removable rectangular belt box. |
| **FeedCover** | Hinged top cover. |
| **FeedBelt** | Separate short visual belt with manageable reusable link/round instances. |
| **ChargingHandle / Bolt** | Separate manipulation and visible action pieces. |
| **Trigger** | Independent cosmetic movement. |

Only group parts that move together. Give reload props reusable geometry and consistent material assignments. Fixed decorative meshes follow their associated parent.

## 5. Animation Requirements

- Heavy idle, slow equip, sustained fire, belt-feed visual loop, empty belt state, open cover/remove box/replace box/seat belt/close cover/charge reload sequence, ADS transition, inspect and lowered sprint.

**Aiming:** Iron-sight ADS as a proposed project default.
Prepare the stated aiming reference and transition. Final camera offsets, zoom and input behavior belong to the game configuration.

Use gameplay state and animation markers to control reload-prop visibility, sound and effects. Partial, empty and interrupted states must not duplicate ammunition props or create unintended movement. The mesh does not define capacity, damage or fire-rate balance.

## 6. Attachments and Reference Points

WeaponRoot, RightHandGrip, LeftHandGrip, MuzzleAttachment, EjectionAttachment, optional LinkEjectionAttachment, AimPoint, AmmoBoxSeat and BeltFeedPoint.

Position references consistently with the existing framework and parent them to the correct moving component. Match their local axis conventions before import. Do not guess new conventions if the existing project can be inspected.

## 7. Checks and Special Notes

Top cover must clear sights and forearm. Belt must stay connected and not pass through receiver. Use few linked visual elements rather than simulating an entire ammo supply.

Ammo box and belt stay consistent across tactical and empty reload states. Do not add rotating barrels or a rifle box-magazine reload.

Check hands, camera framing, component travel, reload clearance and the opposite side during inspect. Confirm that the mesh, rig and effect references agree; avoid accidental intersecting hands, floating magazines and unsupported animated parts.

## 8. Deliverables

- Organized source Blender project (`.blend`).
- Roblox-compatible exported meshes (`FBX`) and required textures.
- Correct UVs, material assignments, names, origins and rest transforms.
- Separate moving parts with useful pivots and animation-ready hierarchy.
- Named attachment reference points with consistent orientation.
- Matching three-quarter and side previews of the final model.
- Short import/setup notes identifying remaining Roblox joint work.
- A component-motion check and Roblox import check for scale, shading and separation.

Animations do not all need to be finished now. The model must support them without rebuilding its main structure. Review it beside Vandal, Phantom and Classic before delivery.

---


# 16. Dual Automatic Pistols — Primary Weapon — Blender Modeling Brief

## 1. Overall Design

Use the matching generated Dual Automatic Pistols — Primary Weapon concept sheet as the primary visual reference. Create an original polished game-ready Roblox asset in the same family as the approved Vandal, Phantom and Classic. Match the silhouette, major proportions, materials and amount of blockiness while simplifying minor detail where useful.

**Identity:** Akimbo pair of compact automatic pistols with extended magazines.

**Chosen design:** TWO matching compact automatic pistols, each larger and more substantial than Classic, sturdy short reinforced slide, moderately thick textured grip, long straight extended magazine protruding below grip, restrained slide vents and tiny blue accents. No stocks, suppressors or scopes. Use two instances of the same pistol geometry as shown in the sheet; keep ejection ports on their modeled side.

Use broad readable moderately blocky forms, clean shading and selective small bevels. Keep the prop attractive both close up in first person and at third-person distance. Resolve small image inconsistencies into one coherent model; prioritize the described category and key distinguishing parts.

## 2. Family Compatibility

Inspect the existing weapon assets first. Preserve scene units, export scale, axis conventions, character-hand proportions, root naming/orientation and the established Motor6D or bone workflow. A shared framework is required; weapon-specific hand poses and action animations are expected. Place correct origins and pivots, use clean rest transforms and avoid duplicate constraints. Do not permanently merge moving parts into the stationary body. Preserve this separation through export and document any Roblox-side joint setup. No detailed hidden mechanism is required.

Use a shared DualWeaponRoot plus an independent child root for each pistol, under the same external weapon interface.

## 3. Textures and Materials

Use matte charcoal/graphite metal and near-black polymer with restrained roughness differences, clean fine surface texture, soft bevel highlights and tiny blue accents. Match the existing Vandal, Phantom and Classic rather than increasing detail or glow. Create clean UVs and Roblox-compatible base-color, normal, roughness and metalness maps where useful. Neon details are separate small meshes that follow the associated moving component. Avoid excessive wear, noisy textures and plain untextured brick colors.

## 4. Separate Components and Structure

| Component / group | Setup and movement |
| --- | --- |
| **DualWeaponRoot** | Shared primary-weapon root. |
| **PistolRoot_L / PistolRoot_R** | Independent child roots for each hand. |
| **Frame_L/R** | Stationary grip/frame for each pistol. |
| **Slide_L/R / Barrel_L/R** | Independently animated per pistol. |
| **Magazine_L/R** | Separate extended magazines. |
| **Trigger_L/R / SlideCatch_L/R / MagazineRelease_L/R** | Independent visible controls per side. |

Only group parts that move together. Give reload props reusable geometry and consistent material assignments. Fixed decorative meshes follow their associated parent.

## 5. Animation Requirements

- Dual idle/equip, independent left fire and right fire, alternating automatic fire, simultaneous fire support if gameplay chooses it, per-hand last-shot hold-open, staged one-pistol-at-a-time reload using a temporary holster/support step for the other weapon, partial-side reload, empty reload, inspect and sprint.

**Aiming:** None. Dual hip-fire with independent left/right handling.
Do not create an ADS pose, camera alignment transition or ADS AimPoint for this asset. Keep modeled sights as visual details where present.

Use gameplay state and animation markers to control reload-prop visibility, sound and effects. Partial, empty and interrupted states must not duplicate ammunition props or create unintended movement. The mesh does not define capacity, damage or fire-rate balance.

## 6. Attachments and Reference Points

DualWeaponRoot, PistolRoot_L/R, LeftHandGrip and RightHandGrip, MuzzleAttachment_L/R, EjectionAttachment_L/R, MagazineSeat_L/R and optional HolsterSupport_L/R. No ADS AimPoint.

Position references consistently with the existing framework and parent them to the correct moving component. Match their local axis conventions before import. Do not guess new conventions if the existing project can be inspected.

## 7. Checks and Special Notes

No third hand, floating magazines or magically reloaded gun. Each pistol has separate ammo, slide, recoil and effect state under one primary slot. Reuse the same geometry in both hands without negative-scale mirroring; check that per-hand casing effects clear the hands and camera.

Sheet exception: upper hero shows the pair side by side with space between them, both muzzles left; lower bordered inset contains two matching profiles. Treat this as ONE primary weapon, not Frenzy or two inventory sidearms. A true mirrored mesh is not required.

Check hands, camera framing, component travel, reload clearance and the opposite side during inspect. Confirm that the mesh, rig and effect references agree; avoid accidental intersecting hands, floating magazines and unsupported animated parts.

## 8. Deliverables

- Organized source Blender project (`.blend`).
- Roblox-compatible exported meshes (`FBX`) and required textures.
- Correct UVs, material assignments, names, origins and rest transforms.
- Separate moving parts with useful pivots and animation-ready hierarchy.
- Named attachment reference points with consistent orientation.
- Matching three-quarter and side previews of the final model.
- Short import/setup notes identifying remaining Roblox joint work.
- A component-motion check and Roblox import check for scale, shading and separation.

Animations do not all need to be finished now. The model must support them without rebuilding its main structure. Review it beside Vandal, Phantom and Classic before delivery.

---


## Reference notes

Broad VALORANT weapon categories were checked against Riot Games' [official arsenal](https://playvalorant.com/en-us/arsenal/). Riot's [Outlaw design article](https://playvalorant.com/en-us/news/game-updates/a-new-addition-to-the-arsenal-outlaw-insights/) distinguishes Outlaw's break action, Marshal's lever action and Operator's bolt action. Exact shapes, materials, component organization, loading choices and aiming defaults in this pack are original project design decisions rather than a claim of exact VALORANT implementation.

The Uzi-inspired Stinger replacement and dual automatic pistol primary are deliberate project-specific additions.

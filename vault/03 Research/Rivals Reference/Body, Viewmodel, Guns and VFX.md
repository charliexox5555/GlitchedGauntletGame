# RIVALS reference: body, viewmodel, guns, abilities, VFX

Part of [Rivals Reference](00%20Rivals%20Reference.md). Studied 2026-11-15, read-only. `SPA.` = `StarterPlayer.StarterPlayerScripts.Assets` in the RIVALS file (the real client assets; `ReplicatedStorage.Assets` and `Workspace.ViewModels` are near-empty). Records **structure and numbers only**: we rebuild with our own meshes, textures and code.

## Third-person body: it's a technique, not an asset
- **No custom body.** Players fight in their **own R15 avatar** (rig like `SPA.Misc.DefaultDueler`: stock R15 sizes, HipHeight 2, 15 Motor6Ds, grey 0.5 body colours). A default head mesh replaces oversized heads; head hidden in first person via `LocalTransparencyModifier`.
- **How the gun "sits" in third person:** two `IKControl`s per fighter (right and left hand), end effectors = the avatar's hands, **targets = the first-person viewmodel's `HandAttachment`s**. So the third-person arms follow the first-person animation; one set of gun animations drives both views. An item can switch either hand's IK off.
- **Look up/down:** procedural pitch on the joints: **waist 0.25 × camera pitch, neck 0.75 ×**, plus a root offset.
- Locomotion: a stock-style `Animate` script (45 animations). Sounds fire from **animation events** (`AnimationLibrary`: ~878 small modules like `<gun>_reload`, `<gun>_shoot1`).
- Per-fighter client modules: Animations, Joints, Arms, Avatar, Visibility, Visuals, Airborne, Sounds, State.

**Compared with ours:** we built our own block body over an R15 rig with hand-keyed third-person clips per gun ([Third Person Overhaul](../../01%20Design/Third%20Person%20Overhaul.md) §2, §19-23). Their trick worth testing: **drive the third-person hands by IK from the first-person pose**, plus 0.25/0.75 waist/neck pitch. That's how they get every gun held correctly with no separate third-person clips. Note our own finding that switching an IKControl on and off pops (blend its weight instead).

## First-person viewmodel
- Template `SPA.Misc.ViewModelRoot`: invisible root (2×2×1) with an `AnimationController`; Motor6Ds root → `RightArm`, `LeftArm`, `Camera`. **The camera is an animated part**; its offset from the root is applied to the real camera (camera motion is keyed in the clips).
- **Block arms:** Parts **1.8 × 0.45 × 0.45** with a block SpecialMesh, skin (1, 0.8, 0.6), a shirt Decal for the sleeve, a `HandAttachment` at -0.9 on the arm. Wrapped variants swap in when a wrap applies.
- Items mount on `LeftItem` / `RightItem` (0.25 cube) via Motor6Ds; each gun sub-model gets a Motor6D from the root so clips can move bolts, mags and pumps.
- **Everything moves on springs** (`Modules.Spring`): equip, aim, crouch, slide, sprint, bob, sway, landing, jump, tilt, recoil, unrecoil, inspect. Recoil spring speed **100**, damping **~0.875**; aim speed **30** × the gun's `AimSpeed`; sway × 35. ADS aligns the sights with an `_aim_lookat` attachment. Weapon FOV offset scales by FOV/80.

## Guns (structure contract)
- A gun = a Model of **sub-models** (Body, Bolt, Magazine, ReloadMagazine; Shotgun: Body, Pump, Shell, ReloadShell; Revolver: Body, Hammer, Chamber, Bullets, ReloadBullets), each with an invisible `Primary`; parts weld to their Primary (no collide/query/shadow, massless).
- **Attachments on the main Primary:** `_grip`, `_center`, `_muzzle`, `_aim_position`, `_aim_lookat`, `_charm_pivot_attachment`, `_scope_glare` (snipers), `_riot_shield_back`.
- **Reload props are separate copies** shown only during the reload clip (`AnimationContexts` attribute); `HideInThirdPerson` hides first-person-only bits. Hands that belong to a gun are sub-models `_right_arm` / `_left_arm` tinted to the arm colour.
- **Budget:** ~8-10 MeshParts per gun (Assault Rifle 29 instances, Knife 10), all **SmoothPlastic, flat colour, almost no textures** (3 SurfaceAppearances across 50 guns). The look comes from shape and colour blocking, not texture. See `third-party/guns/`.
- **Skins** are whole separate models with the same attachment contract. **Wraps** = `MaterialVariant`s (178, normal/metal/rough maps only, 1.5 studs per tile) or a set of Texture objects, recorded and restored by a WrapController.

**Compared with ours:** our guns already use a Studio-owned rig with named sight parts ([Skin Build Pitfalls](../../02%20Art/Skins/Skin%20Build%20Pitfalls.md)). Ideas to borrow: the `_aim_lookat` sight alignment, reload-only prop copies, and an attribute-driven "which context shows this part" switch.

## Abilities and utilities
- Held items reuse the gun contract (Grenade, Flashbang, Molotov, Smoke, Satchel + Detonator, Tripmine, Jump Pad, Medkit, Riot Shield, Grappler). Thrown copies in `SPA.Throwables` (58: a few MeshParts + a small Primary with a Trail); projectiles in `SPA.Projectiles` (90, minimal: e.g. RPG = head + neck with smoke emitters).
- Effect folders in `SPA.Misc`: SmokeClouds, BurningEffects, MolotovExplosionEffects, FireHitboxes, Flamethrower flames/airblasts, FreezeEffects, Deflect hit/active, WarHorn, Vortexes, Portals, JumpPads, MushroomCloud. Our [Mods](../../01%20Design/Mods.md) can look here for how a similar effect is layered.

## VFX recipes (rebuild with our own textures)
| Effect | Where | Recipe |
|---|---|---|
| Muzzle flash | `SPA.Misc.MuzzleFlashes` (87 variants, `Default`) | one Attachment of **6-9 emitters**, lifetimes **0.1-0.3 s**, sizes 0 → 0.4-1.6, LightEmission 0.4-1, LockedToPart, **burst count stored as an `EmitCount` attribute per emitter** (2, 2, 5, 2), **no light**. Chosen per gun by attribute, then name, then Default. |
| Tracer | `Misc.TracerEffect` + `Modules.TracerEffect` | one Beam (width 0.5 → 0, 10 segments, LightEmission 1) + dim PointLight; the head travels **800 studs/s**, the tail trails up to 75 studs (first person) / 15 (others); friendly orange (255,81,0), enemy red (255,8,0); fly-by sound at the closest point to the camera. |
| Headshot | `Misc.HeadshotParticles` | 7 layers: shards, a 4×4 flipbook burst (size → ~3.9), glow (→ 8.4), a **dark layer (LightEmission -2)**, glow 2, impact; 0.05-0.5 s, 1-7 particles each. |
| Bullet impact | `ImpactMarkerBullet` / `Splat` | one 4×4 flipbook emitter, 0.25-1 s, size → 2.35; a tiny splat. |
| Explosion | `Misc.ExplosionEffect` + `Functions.ExplosionEffect` | 11 layers (light, orange ×2, black smoke ×2 at LightEmission 0, glow, specks, shards, wind ring, crescents) + PointLight (24, 1.24); sizes to 14-37 studs, 0.13-1.33 s; spawned on an anchored part, scaled, emitted, cleaned after 5 s. ~60 per-weapon variants. |
| Flashbang | `FlashbangEffect` | one glow 50 → 1 studs over ~0.5 s + PointLight (60, 40). |
| Dash | `DashParticles` | 4 streak emitters (two long ≤0.25 s, two short ≤0.12 s). |
| Elimination | `UserInterface.EliminatedEffect` | **a UI effect, not world particles.** |

**Pattern:** many single-job layers (glow, smoke, shards, ring, dark), everything under ~1.5 s, eased size curves with 10+ keys, counts in attributes, one helper to play/scale emitters. This matches our [gun VFX direction](../../02%20Art/Style%20Bible.md) (stylised, Valorant-like).

## What we take / don't
- **Take:** the IK-from-viewmodel idea, spring numbers, the attachment contract, the VFX layer recipes and timings above, flat-colour gun budgets.
- **Don't take:** their meshes, flipbook/particle textures, wrap textures, animation assets, sounds or code. Rebuild every effect with our textures from the recipe. A copied texture is the "obvious" part, so we don't use theirs at all.

## Hit feedback and crosshair (studied 2026-11-15)
Read as text from the RIVALS client modules (`Modules.Crosshair`, `ItemInterface.Mouse` + `MouseCrosshair`, `FighterInterface.DamageIndicators` / `Health` / `EliminationSlots`, `UserInterface.EliminatedEffect`, `CameraController`). Numbers and behaviour only. Their springs are Quenty-style `Spring.new(start, damper, speed)`; a lot of them **jump straight up to a bigger target and only ease down** (`if target > value then value = target`), so a gap or tilt is instant and the recovery is the soft part.

| Item | RIVALS behaviour and numbers |
|---|---|
| Crosshair default | 4 bars **6 × 2 px**, dot 2 px, gap **16 px**, black outline (stroke), white; settings: colour, outline, scale, rotation, per-bar off, dot/bars/circle shape, hit-marker colour + crit colour, hit-marker scale/rotation. |
| Crosshair gap | `gap = (16 + 8·(0.75·speed/16)² + 32·air + 100·|recoil|/accuracy) · crouch / accuracy`; `crouch` = **0.25 while crouched/sliding** (gap closes), `air` = 1 off the ground. Each term on a spring (damper 0.875, speed 20) that **snaps up and eases down**. |
| Crosshair on ADS | gap × (1 − aim) and transparency = aim: the bars **collapse into the dot while fading** as you aim. |
| Crosshair on slide | the whole mouse frame **rotates to 20°** (whole degrees) the moment the slide starts (spring 0.875 / 20, snaps up), springs back when it ends. First person only. |
| Crosshair follows camera | it's projected through the viewmodel offset × shake, so camera shake moves the crosshair with the view. |
| Hit marker | 4 corner wedges. On hit: spring **reset to 0 → 1** (damper 1, speed 20 ≈ 0.25 s): wedge size **16 → 8 px**, offset from centre **32 → 6 px** (starts big and wide, shrinks in tight). Holds, then fades: transparency = `min(1, t/2)^10` (fully visible ~1.4 s, gone at 2 s). Colour white, **crit `#ff3232`**. A ±15° random tilt is computed but isn't applied in the decompile. Same marker on a kill. |
| Damage-direction wedge | one per source (a new hit from the same source replaces it); angle on a spring (damper 1, speed 40), on a ring at **0.375** of the frame; size 0.5 of the frame, shrinking with distance (`0.5 / max(1, (d-5)/25)`, min 0.125); holds **5 s**, fades `^4` over ~0.4 s. |
| Hurt vignette | per hit, opacity = **0.5 + 0.5·(damage / health)** at start, fades linearly over ~0.4 s. Low-HP vignette: off above 50 % HP, transparency = HP%·2 below that. Health bar colour ramp (255,50,50) → (255,215,0) → (100,255,50), Quint 0.5 s. |
| "Eliminated <name>" | row under the crosshair grows in (**Back, 0.25 s**), holds **3 s**, shrinks (Quint 0.5 s) and fades; name in the victim's team colour, weight 800 with a 3 px black stroke, "Eliminated" weight 500; streak sounds climb with the chain; rows queue 0.04 s apart. |
| Death card (victim) | `EliminatedEffect` card unfolds width 0 → 1 (Quint 1 s), holds 5 s, fades. |
| Slide camera | position spring (0.75 / 30) drops the eye **3 studs** (crouch 2); roll **−5°** on a bouncy spring (damper **0.5**, speed 15); FOV + (speed − 16)·10/16 on a spring (0.75 / 30); head bob off while sliding. No legs in first person. |

**What we used** (owner's answers, 2026-11-15): 20° slide tilt like RIVALS; no first-person legs; no extra headshot screen cue; the same marker on a kill, with our own kill UI and line. Result note: [2026-11-15 Gunplay Feel RIVALS](../../05%20Production/Playtests/2026-11-15%20Gunplay%20Feel%20RIVALS.md).

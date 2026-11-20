# RIVALS reference: body, viewmodel, guns, abilities, VFX

Part of [Rivals Reference](00%20Rivals%20Reference.md). Studied 2026-11-15, read-only. `SPA.` = `StarterPlayer.StarterPlayerScripts.Assets` in the RIVALS file (the real client assets; `ReplicatedStorage.Assets` and `Workspace.ViewModels` are near-empty). Records **structure and numbers only**: we rebuild with our own meshes, textures and code.

## Third-person body: it's a technique, not an asset
- **No custom body.** Players fight in their **own R15 avatar** (rig like `SPA.Misc.DefaultDueler`: stock R15 sizes, HipHeight 2, 15 Motor6Ds, grey 0.5 body colours). A default head mesh replaces oversized heads; head hidden in first person via `LocalTransparencyModifier`.
- **How the gun "sits" in third person:** two `IKControl`s per fighter (right and left hand), end effectors = the avatar's hands, **targets = the first-person viewmodel's `HandAttachment`s**. So the third-person arms follow the first-person animation; one set of gun animations drives both views. An item can switch either hand's IK off.
- **Look up/down:** procedural pitch on the joints: **waist 0.25 × camera pitch, neck 0.75 ×**, plus a root offset.
- Locomotion: a stock-style `Animate` script (45 animations). Sounds fire from **animation events** (`AnimationLibrary`: ~878 small modules like `<gun>_reload`, `<gun>_shoot1`).
- Per-fighter client modules: Animations, Joints, Arms, Avatar, Visibility, Visuals, Airborne, Sounds, State.

### Deeper read (2026-11-20, overnight TP lane; `ClientFighterCharacter.Arms` / `Joints` / `Animations`, `ClientViewModel`, `CameraController`; read as text only)
| Piece | How RIVALS does it | Worth it for us? |
|---|---|---|
| Where the gun is for **other players** | The same item `ViewModel` model is used in third person. Each frame it is set to `CFrame.new(Head.Position) * Rotation`, where Rotation = `Angles(0, yaw, 0) * Angles(pitch, 0, 0)` from the fighter's replicated camera rotation. No bob, sway or recoil springs in this branch (they live only in the first-person branch). The viewmodel's own block arms go `Transparency = 1`; the gun stays visible. Arm sub-models (gloves etc.) `ScaleTo(1.7)` in third person. Gun parts that end up behind the head get `LocalTransparencyModifier` 1 | Yes: one pose source for both views |
| Hands | Two `IKControl`s parented to the Humanoid: `ChainRoot` = `Right/LeftUpperArm`, `EndEffector` = `Right/LeftHand`, `Target` = the viewmodel arm's `HandAttachment`. **Type left at default (Transform), no Pole, `SmoothTime = 0`, Weight 1.** An item can turn either side off (`RightArmIKControlDisabled` / `LeftArmIKControlDisabled`) | Yes; but a pole is needed on our block arms (the elbow picks its own plane otherwise) |
| On / off | `Enabled` is set on equip and every update: on only when the viewmodel root is **within 16 studs** of the character root (a guard against a stale model). Emotes fade the IK out (weight 0 at once) and back in with `Weight = t^4` over a set time | Blend, as the owner wants; `t^4` is a slow-start, fast-finish fade |
| Joint limits | The avatar's `Right/Left Shoulder/Elbow/Wrist BallSocket` constraints are **switched off while that arm's IK is on** and back on when it is off (IK respects constraints, so the limits would fight the solve). The `DefaultDueler` itself has 15 Motor6Ds and no constraints; the sockets come with the engine's joint upgrade | Check whether our rig has them |
| Aim pitch | `Joints`: a spring (damper 1, speed 50) on the replicated camera rotation; **waist C0 = Angles(0.25 × pitch)**, **neck C0 = Angles(0.75 × pitch)**, positions kept. On an `AnimationConstraint` rig it writes **`Attachment0.CFrame` / `Attachment1.CFrame`** of the joint (the C0/C1 equivalent), not `Transform` | **Yes: this is the way round our §22 finding that `Transform` writes don't stick** |
| Lean | A lean spring (damper 1, speed 20) moves the Root joint's C0: 1.25 studs sideways and a 20° roll at full lean | Optional |
| Locomotion | The stock `Animate` script with 8 direction clips (walk = run ids). Crouching swaps the `Animate` ids for crouch overrides and fires `Refresh`. Slides: 4 directional Start clips, then 4 Loop clips picked each frame by the nearest direction to the move (**hard swap, `Play(0)`**) | Ours is richer (8-way walk / run / crouch with foot lock); keep ours |
| Head | First-person head hiding is per part `LocalTransparencyModifier` (Visibility module); third-person hitboxes are separate parts (`HitboxHead`, `HitboxBody`, small variants) | We already hide by LTM |

**What it means:** in RIVALS the arms carry **no third-person clips at all**; every hold, reload, draw and inspect a watcher sees is the first-person animation, re-used through IK. That is why every gun is "really held". The cost is that the third-person arm pose is only as good as the IK's elbow choice and the reach (the viewmodel arms are 1.8 long; an R15 arm is about 2).

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
| Headshot | `Misc.HeadshotParticles` | 7 layers: shards, a 4×4 flipbook burst (size → ~3.9), glow (→ 8.4), a **dark layer (LightEmission -2)**, glow 2, impact; 0.05-0.5 s, 1-7 particles each. Cloned onto the target's Head and played on a head hit; **fixed world sizes, no distance scaling** (checked 2026-11-16, [fixes](../../05%20Production/Playtests/2026-11-16%20Match%20Fixes%20Round%201.md)). |
| Bullet impact | `ImpactMarkerBullet` / `Splat` | one 4×4 flipbook emitter, 0.25-1 s, size → 2.35; a tiny splat. |
| Explosion | `Misc.ExplosionEffect` + `Functions.ExplosionEffect` | 11 layers (light, orange ×2, black smoke ×2 at LightEmission 0, glow, specks, shards, wind ring, crescents) + PointLight (24, 1.24); sizes to 14-37 studs, 0.13-1.33 s; spawned on an anchored part, scaled, emitted, cleaned after 5 s. ~60 per-weapon variants. |
| Flashbang | `FlashbangEffect` | one glow 50 → 1 studs over ~0.5 s + PointLight (60, 40). |
| Dash | `DashParticles` | 4 streak emitters (two long ≤0.25 s, two short ≤0.12 s). |
| Elimination | `UserInterface.EliminatedEffect` | **a UI effect, not world particles.** |

**Pattern:** many single-job layers (glow, smoke, shards, ring, dark), everything under ~1.5 s, eased size curves with 10+ keys, counts in attributes, one helper to play/scale emitters. This matches our [gun VFX direction](../../02%20Art/Style%20Bible.md) (stylised, Valorant-like).

## Ability VFX (2026-11-16)
Read for the [Ability Rework follow-up](../../04%20Tech/Prompts/2026-11-16%20Ability%20Rework%20Follow-up.md) §2, `Default` variant of each folder under `StarterPlayer.StarterPlayerScripts.Assets.Misc`. **Per-layer tables: [Ability VFX Numbers](Ability%20VFX%20Numbers.md).** Mapped onto [Ability VFX Direction](../../02%20Art/Ability%20VFX%20Direction.md). No asset ids recorded; rebuild with our own art.

### Fire: Molly / Fork Fire / Firewall
Read: `MolotovExplosionEffects`, `BurningEffects`, `FireHitboxes`, `FlamethrowerFlames`.
- Shatter = 5 bursts of 6-15 (embers, 4x4 flame blooms 5.5 → 11 studs, shard streaks, 0.05-0.13 s spikes to 8.9 studs, a 23 → 36-stud dark-red smoke). All fire layers **LightEmission -1**, LightInfluence 0, Brightness 5-7: saturated colour that doesn't blow out. Smoke is `AA1A00` dark red, not grey.
- Patch = a 32-stud disc volume emitting from its Surface: flame field + rim ring (4x4 flipbook, 2 → 5 studs), embers up at 200 accel, low smoke, PointLight 3 / 27 / `FF440B`. Burning player = 3 tiny constant layers (flame 3, smoke 10, ember 1) + the same light.
- What reads: flames solid for 77 % of life then cut in 20 % (`0:0 0.77:0 0.81:0.38 … 1:1`); **TimeScale 0.2-0.5** on looping fire slows it into a held, chunky motion; one warm light carries the area.
- Ours does it as: hooked flame-tongue meshes / a stepped 4x4 sheet of our own in 3 value bands for the field; keep the solid-then-cut fade, negative LightEmission and a single warm light; the 32-stud disc is our Molly footprint ring in team colour on the floor edge; burning players get 3-4 licks riding the body, not a fire cloud.

### Ice: Frost / Freeze Frame / Frost Wall
Read: `FreezeEffects` (Default). **Zero particles:** four faceted Glass MeshParts (2.2-2.9 x 1.8-4.3 x 3 studs, `43A4FF`, transparency 0.5) wrapped round the body + an opaque white snow cap 5.6 x 2 x 3.5.
- What reads: hard shapes around the pose; translucent glass with a solid base.
- Ours does it as: exactly our "angled plates and prisms" signature; add the 0.1 s snap-out with overshoot and a 0.2 s chip shatter (RIVALS' version has no authored entry/exit in this folder). `FreezeRayExplosionEffect` not read.

### Impact and lift: Crash Down / Updraft
Read: `ExplosionEffect` (11 emitters + light), `JumpPads`.
- Burst counts 1-40 (`EmitCount`), lifetimes 0.13-1.33 s, every size an 11-key ease-out reaching half size by t 0.1. Two flat **VelocityPerpendicular** layers do the "wind": a ring 0 → 24 studs in 0.13-0.33 s starting at 0.7 transparency, and spinning crescents to 18 / 37.5 studs (rotspd 45-180). Fire layers LE 1, smoke LE 0, `orange2` LE 0 at br 8. Light: 24 range, script decays it (`Brightness=10`, `DecaySpeed=0.1` attributes).
- Jump pad: three stacked MeshPart plates (10.4-stud base, 9.2-stud Neon face), no particles; no launch effect in `Misc`.
- What reads: a big flash (1 particle to 27 studs) + a fast flat ring + slower arcs; smoke and sparks outlast the flash.
- Ours does it as: the ring is our ground-hugging pressure ring, flat, team colour, footprint = damage radius, 0.25 s; crescents become 2-3 wind strokes; drop the fire/smoke cloud for floor-coloured chunk meshes + a dust skirt. Updraft: the crescent idea as vertical tapered strokes.

### Movement: Dash / Ghost / Desync
Read: `DashParticles`, `Vortexes`.
- Dash: 4 white VelocityParallel streak emitters, life 0.03-0.25, EC 25 / 5 / 7 / 5, speed up to 150-300 with **drag 24-48** (launch then stop dead), size → 1 or 0.4, LE 1.
- Vortex: a pull field built from SurfaceGui ring plates (30 / 34 studs) + Neon disc + 8 emitters: a LE-0 dark centre, a spinning rim, 8x8 / 4x4 swirl flipbooks that shrink, and streaks from a 28-stud sphere surface (drag -6 accelerates them in). Colour `20FFA2`.
- What reads: very short, very fast, heavy drag; centre-dark vs rim-bright contrast.
- Ours does it as: tapered stroke meshes or sheets with the same speed/drag profile (in 0.05, gone 0.25), on screen edges for the caster; Desync's pull-in uses the inward-streak + dark-centre idea at a much smaller scale.

### Teleport: Recall
Read: `Portals` (Default).
- Built from flat discs: 7.7-stud Neon ring mesh, 6.2-stud inner discs with tinted decals, 11-13-stud outer image plates spun by AngularVelocity, SurfaceLight 0.5 / 60 / `C12FFF`; a 1-stud Small (closed) version. Only 2 emitters (3 dots each, life 1.5, br 200, LE 0, ts 0.5).
- What reads: layered rotating flat shapes with a coloured light, almost no particles.
- Ours does it as: the vertical fold: a disc that pinches to a line and a ring that snaps in (0.12 / 0.15 s) in violet `9B6BFF`; borrow the Small → Big two-size swap as the open beat; no constant spin (our rule: still once open).

### Scan: Recon / Ping Spike
Read: `WarHornEffects`, `DeflectActiveEffects`, `DeflectHitEffects`.
- War Horn: 4 white single-particle rings (EC 1-2), 0.12 / 0.23 / 0.31 / 0.46 s, 4-5.4 studs on a 24-stud part, LE 1; one fast bright, three lingering faint.
- Deflect active: ring + star (0.12 / 0.28 s, rotspd 720, br 8) and a `NotLocal` copy **10x bigger** for other players. Deflect hit: a 0.1 s sparkle, then shards **75 ms later** (`EmitDelay`), PointLight 3 / 24.
- What reads: stacked rings with staggered lifetimes; a different size for the owner vs everyone else.
- Ours does it as: Recon = one constant-speed shell (team colour) with a fast bright front ring and 2 fainter trailing rings; Ping Spike = the Burst1Fast-style bright pulse doubled. Keep the owner/other split for size.

### Healing: Heal Zone / Heal Orb / Stim
Read: `SmokeClouds` (three nested Neon MeshPart cores scaled by script, each fading by a `DecaySpeed` attribute, no particles). **Heal effect NOT FOUND** (searched `Misc` for Heal / Medkit / Regen; Medkit viewmodel and bundle are models only).
- Ours does it as: the zone volume as 2-3 nested faceted shells with their own fade rates (the SmokeClouds idea), plus our soft leaf/chevron pulses; nothing to copy for the heal itself.

### Shield: Barrier
Read: `ViewModels.Weapons.Riot Shield` (no emitters, lights or beams), `DeflectHitEffects`. Ours does it as: the hex shell, a deflect-style hit (sparkle + 75 ms delayed shards, ≤0.3 s) in team colour.

### Thrown props
Read: `Throwables.Molotov`, `.Grenade`, `.Smoke Grenade`. 3-6 MeshParts (0.13-1.6 studs) + an invisible Primary 0.16-0.24 cube carrying **one Trail between two Attachments 0.5 studs apart** (white, life 0.25, width 1 → 0, tr 0 → 1, LE 1, FaceCamera). The Molotov adds a second orange trail on the wick (`FF4800`, life 0.13). Ours does it as: the same Primary + short trail contract on our faceted canisters; Fork Fire's split adds one flicker.

### Across effects
- **Layer counts:** bursts 3-5 layers (Molotov 5, Deflect hit 3 + light), big explosion 11 + light; constant effects 3-8 emitters. Three of the ten folders use **no particles** (Freeze, SmokeClouds, JumpPads) and Portals almost none.
- **Lifetimes:** bursts ≤ 0.6 s except smoke (≤ 1.33 s); dash ≤ 0.25 s; constant fire 0.2-0.4 s stretched by TimeScale 0.2-0.5.
- **LightEmission:** 1 for light/wind/rings, 0 for smoke and dark centres, **-1 / -0.5 for all fire** (saturated, no bloom). LightInfluence 0 everywhere.
- **Counts and timing:** `EmitCount` attribute per emitter (1-40), `EmitDelay` for order (0.075 s on Deflect), `EmitDuration`; lights driven by `Brightness` / `DecaySpeed` attributes; volumes faded by `DecaySpeed`; skins coloured by `WrapGroup`.
- **Contradictions with our direction note:** (1) RIVALS fire is smooth flipbook particles with drag, not stepped meshes; its "held" feel comes from TimeScale 0.2-0.5, which we may want instead of or alongside 12-15 fps stepping. (2) Its explosion/impact is a fire-and-smoke cloud; our Crash Down calls for floor fragments and a ring only. (3) Portals spin constantly; our teleport is a still fold. (4) RIVALS shows owner and other players different sizes (Deflect `NotLocal` 10x); our note doesn't specify per-viewer scale. (5) RIVALS has no shared element colour for team lines; rings are white.

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

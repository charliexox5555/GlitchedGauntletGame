# RIVALS ability VFX: per-layer numbers (read 2026-11-16)

Measured from the RIVALS place file (Edit datamodel, property reads only) for the [Ability Rework follow-up](../../04%20Tech/Prompts/2026-11-16%20Ability%20Rework%20Follow-up.md) §2. Summary, "what makes it read" and "ours does it as" live in [Body, Viewmodel, Guns and VFX](Body,%20Viewmodel,%20Guns%20and%20VFX.md) → Ability VFX. **Study only:** no RIVALS texture, mesh, sound or animation is used; textures are described in words (inferred from layer name and flipbook layout, not viewed).

Path root: `StarterPlayer.StarterPlayerScripts.Assets` (the "SPA" in older notes). Every effect folder holds skin variants; only `Default` was read.

**Keys:** life = Lifetime s; `EC` = `EmitCount` attribute (burst count; the `Rate` property is unused for bursts); `ED` = `EmitDelay` attribute; spd = Speed; spr = SpreadAngle; size / tr = keypoints `time:value` (`~` = envelope); LE = LightEmission; LI = LightInfluence (0 on every layer read); br = Brightness; z = ZOffset; ts = TimeScale; or = Orientation (FC FacingCamera, VPar VelocityParallel, VPerp VelocityPerpendicular); fb = flipbook. All emitters `Enabled=false` (burst by script) unless marked "on".

## Fire: Molly / Fork Fire / Firewall
Fire palette shared by all fire layers: flame `0:FF7525 0.32:FF7124 0.55:FF3502 1:FF3300`; ember / shard `0:FF7525 0.16:FF7124 0.43:FF4110 1:FF5608`; smoke flat `AA1A00` (a dark red, not grey). Flame transparency curve everywhere: `0:0 0.77:0 0.81:0.38 0.89:0.74 0.96:0.95 1:1` (fully solid for 77 % of life, then a fast cut).

### `Misc.MolotovExplosionEffects.Default` (1 stud Part, one Attachment; the shatter burst)
| Layer | Job | life | EC | spd / spr | size | tr | rot | acc / drag | LE / br / z | or / shape | fb | lock |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Ember | thrown sparks | 0.3-0.6 | 15 | 70-150 / 90 | 0→0.26→0.81→1.06 (t0.5)→0.87→0.27→0 | 0 | 0-360 | (0,-60,0) / 15 | -1 / 7 / 3 | FC, Box vol | none | no |
| Fire | flame blooms | 0.3-0.6 | 15 | 40-100 / 70 | 5.5→5.8→7.7→11.2 (~0.6) | flame curve | 0-360 | (0,-150,0) / 3 | -1 / 5.1 / 3.7 | FC, Disc vol | 4x4 OneShot (flame puff sheet) | no |
| Shards | glass/liquid streaks | 0.3-0.6 | 15 | 70-150 / 90 | 0→2.5 (t0.3)→0 | 0 | 0 | (0,-50,0) / 7 | -1 / 7 / 3 | VPar | none | no |
| Smoke | dark red pall | 0.8-1.2 | 15 | 30-60 / 90 | 23→29→34→36 (~3.5-3.9) | 1→0.76 (t0.35)→1, 10 keys | ±360 | 0 / 4 | 0 / 0 / 2 | FC | none | no |
| SpikeyShards | long spikes, first frames | 0.05-0.13 | 6 | 170-250 / 90 | 0→8.9 (t0.29)→0 | 0 | 0 | 0 / 12 | -1 / 7 / 3 | VPar | none | no |
No light. Total ≈ 1.2 s; everything bar Smoke is gone by 0.6 s.

### `Misc.BurningEffects.Default` (on a burning player; 1 stud Part, all on)
| Layer | Job | life | rate / EC | spd / spr | size | tr | acc / drag | LE / br / z | ts | lock |
|---|---|---|---|---|---|---|---|---|---|---|
| Smoke | dark red haze | 0.2-0.4 | 20 / 15 | 3-6 / 6 | 10 flat | 1→0.5→1 | 0 / 1.25 | 0 / 0 / 0.5 | 0.4 | yes |
| Fire | flame licks | 0.2-0.4 | 20 / 15 | 2-4 / 6 | 3 flat | flame curve | (0,6.2,0) / 3 | -1 / 5.1 / 1 | 0.3 | yes |
| Ember | rising sparks | 0.2-0.4 | 20 / 15 | 4-8 / 40 | 1 flat | 0→1 | (0,10,0) / 15 | -1 / 7 / 3 | 0.4 | yes |
| PointLight | warm glow | | | | | | | br 3, range 27, `FF440B` | | |
TimeScale 0.3-0.4 stretches 0.2-0.4 s lives to roughly 0.6-1.3 s on screen and slows the flipbook.

### `Misc.FireHitboxes.Default` (the burning floor patch; Model)
`Primary` Part 4 x 32 x 32, transparent (a flat disc volume 32 studs across, emitters on its Surface).
| Layer | Job | life | rate | spd | size | tr | acc / drag | LE / br / z | shape | ts |
|---|---|---|---|---|---|---|---|---|---|---|
| Ring | flame ring on edge | 1 | 25 | 0 | 2→2.5→3.5→5 | flame curve | (40,0,0) / 3 | -1 / 5.1 / 3.7 | Disc Surface, 4x4 flipbook | 0.5 |
| Fire | flame field | 0.2-0.4 | 25 | 0 | 2→2.5→3.25→5 | flame curve | (40,0,0) / 3 | -1 / 5.1 / 3.7 | Disc Surface, 4x4 | 0.25 |
| Ember | rising sparks | 0.2-0.4 | 20 | 70-130 / 40 | 0→0.5→0.8→1→0.8→0.5→0 | 0 | (0,200,0) / 15 | -1 / 7 / 3 | Disc Surface | 0.2 |
| Smoke | low dark haze | 0.2-0.4 | 5 | 30-60 | 17→22→27→29 | 1→0.76→1 | 0 / 1.25 | 0 / 0 / 2 | Disc Surface | 0.2 |
| PointLight | | | | | | | | br 3, range 27, `FF440B` | | |
Acceleration X 40 on a part rotated so +X is world up: the flames rise. All on, LockedToPart.

### `Misc.FlamethrowerFlames.Default` (0.25 Part, Attachment 2.7 forward)
| Layer | life | EC | spd / spr | size | tr | LE / br | fb | ts |
|---|---|---|---|---|---|---|---|---|
| Ember | 0.75-1.5 | 15 | 15-45 / 20 | 0.13→1.5 | 0→1 | -0.5 / 7 | none | 0.4 |
| Fire | 0.75-1.5 | 15 | 20-60 / 10 | 0→1.5 (t0.1)→3 | flame curve | -0.5 / 5.1 | 4x4 OneShot | 1 |
| SpotLight | | | | range 40, `FFAA00`, br 0 (script-driven), shadows on | | | | |

## Ice: Frost / Freeze Frame / Frost Wall
### `Misc.FreezeEffects.Default` (Model): **no particles at all**
| Part | Size (studs) | Material / colour / transparency |
|---|---|---|
| Ice x4 (MeshPart) | 2.24x1.77x3, 2.86x4.3x3.07, 2.24x2.92x3.07, 2.24x3.03x3.07 | Glass, `43A4FF`, 0.5 |
| Snow (MeshPart) | 5.56x1.98x3.51 | SmoothPlastic `F8F8F8`, opaque (a ground cap) |
| Primary | 1.45x1.45x0.72 | invisible anchor |
Four faceted glass blocks wrapped around the frozen body plus one snow base; the freeze-ray projectile and `FreezeRayExplosionEffect` (14 descendants) are separate and were not read.

## Impact and lift: Crash Down / Updraft
### `Misc.ExplosionEffect` (24-stud Part, one Attachment, 11 emitters + light)
| Layer | Job | life | EC | spd | size (to) | tr | LE / br / z | or | fb |
|---|---|---|---|---|---|---|---|---|---|
| light- | hot core | 0.17-0.43 | 7 | 12-35 | 0→8.4 (t0.1)→14, ~4 | ease 0→1 | 1 / 4 / 0.5 | FC | 4x4 OneShot |
| orange | fire body | 0.43-0.64 | 7 | 35-105, drag 11.7 | →14 | ease | 1 / 4 / 0.4 | FC | 4x4 OneShot |
| orange2 | red fire puffs | 0.5 | 3 | 8-72, drag 14.7 | →12.8 | 0 to t0.4, fast out | **0** / 8 / 0.4 | FC | 4x4 Loop 5 fps |
| black | smoke | 0.94-1.28 | 14 | 82-117, drag 14 | →14 | front-loaded fade | 0 / 4 / 0 | FC | 4x4 OneShot |
| black2 | smoke 2 | 0.87-1.33 | 14 | 82-129, drag 14 | →16 | front-loaded | 0 / 4 / 0 | FC | 4x4 Loop 1.5 fps |
| glow | one big flash | 0.85 | 1 | 0 | 0→12 (t0.1)→27 | front-loaded | 1 / 4 / 1 | FC | none |
| specs | sparks | 0.5-1.5 | 40 | 40-112, rotspd ±562 | 0.97→0 | 0 | 1 / 5 / 1.1 | FC | none |
| shards | streak spikes | 0.15-0.3 | 25 | 136 | 1.8→0 | 0 | 1 / 5 / 1.1 | VPar | none |
| windring1 | flat shock ring | 0.13-0.33 | 6 | 0 | 0→15 (t0.1)→24 | 0.7→1 | 1 / 4 / 0.5 | **VPerp**, locked | none |
| crescents1 | spinning arcs | 1-1.25 | 12 | 0, spr 25 | 0→9.5→18 (~6) | 0→0.6 (t0.1)→1 | 1 / 1 / 0.5 | VPerp, locked, rotspd 45-180 | none |
| crescents2 | big arcs | 0.5-0.75 | 7 | 0, spr 60 | 0→16.7→37.5 | 0→0.45→1 | 1 / 4 / 0.5 | VPerp, locked, rotspd 45-90 | none |
| PointLight | flash | | | | | | br 1.24 (attr `Brightness=10`, `DecaySpeed=0.1`), range 24, `FF5C33` | | |
Colours: core `FF6E0E`, orange `FF4111`, orange2 `FF0000`, glow `FF5C2A`, sparks `FF3318`, smoke `1F0000`→`000000`, rings white. Every size curve is an ease-out with 11 keys (half the final size by t 0.1); transparency eases to 1.

### `Misc.JumpPads.Default` (Model): three stacked MeshPart plates, **no particles**
10.4x0.68x10.4 base (`868891`), 10.74x1.04x10.61 rim (`75777F`), 9.2x0.34x9.2 Neon face (`548AB4`). Skin colours via `WrapGroup` attributes. The launch effect is not in `Misc` (not found under any `Jump*` / `Launch*` name).

## Movement: Dash / Ghost / Desync
### `Misc.DashParticles` (4x5x1 Part, all on, white `FFFFFF`)
| Layer | life | EC | spd | size | tr | rot | acc / drag | LE / br | or |
|---|---|---|---|---|---|---|---|---|---|
| line1 | 0.05-0.25 | 25 | 5-150, spr 0 | 0→1 ease (~env 1) | 0→1 ease | 90 | (0,0,10) / 24 | 1 / 0.5 | VPar |
| line1.5 | 0.03-0.13 | 5 | 10-300 | 0→0.4 (t0.1)→0 | 0.5 flat | 90 | (0,0,20) / 48 | 1 / 4 | VPar |
| line2 | 0.05-0.25 | 7 | 30-150 | as line1 | as line1 | 90 | 0 / 24 | 1 / 4 | VPar |
| line2.5 | 0.03-0.13 | 5 | 10-300 | as line1.5 | 0.5 | 90 | (0,0,20) / 48 | 1 / 4 | VPar |
Very high drag (24-48) turns a fast launch into a streak that stops dead.

### `Misc.Vortexes.Default` (a pull field; Model, all on, colour `20FFA2`)
Faces: `Outer` 30x30 and `OuterBack` 34x34 transparent plates carrying SurfaceGui images (rotating rings drawn as UI); a 17.5-stud Neon disc mesh (`48AF81`, tr 0.02); a 28-stud invisible sphere `PartBig` for inward streaks.
| Layer | Job | life | rate | size | tr | LE / br | fb |
|---|---|---|---|---|---|---|---|
| black | dark centre (LE 0) | 0.13 | 32 | 3 | 1→0→1 | 0 / 0 | none |
| ring | spinning rim, rotspd 90 | 0.13 | 32 | 2.84 | 1→0→1 | 1 / 1 | none |
| in1 | swirl | 0.35 | 4 | 5→6.25 | 0 | 1 / 1 | 4x4 OneShot |
| in2 | swirl shrinking | 1 | 8 | 5→3 | 1→0→1 | 1 / 2 | 8x8 OneShot |
| in3 | swirl shrinking | 1 | 4 | 7.5→1.7 | 1→0→1 | 1 / 0.1 | 8x8 OneShot |
| bigIn | big pulse | 0.25 | 8 | 9.3→5.7 | 1→0→1 | 1 / 2 | 4x4 Loop 24 fps |
| inwards | streaks to centre | 0.5 | 24 | 0.91→0 | 0 | 1 / 8 | Sphere Surface, spd 35, VPar |
| inwards2 | fine streaks | 0.5 | 45 | 0.43→0 | 0 | 1 / 8 | Sphere Surface, spd 10, drag -6 (accelerates) |

## Teleport: Recall (and Desync)
### `Misc.Portals.Default` (Folder, two portal models 1 and 2, each a Big and a Small)
Built from **flat discs, not particles**: a 7.74-stud Neon ring mesh (`A157C1`, tr 0.02), 6.22-stud front and back inner discs (`764190`) with tinted decals (`4F14A8` at 0.3, `F04FFF` at 0.85), 11.25 / 12.75-stud outer plates with SurfaceGui images, spun by `AngularVelocity` and held by `AlignPosition`, a SurfaceLight (br 0.5, range 60, `C12FFF`). Small (closed) variant is the same at 0.93-1.16 studs. Particles: `dots1` / `dots2` only, life 1.5, EC 3, size 9.4-11.7 → 0.9-1.2, tr 1→0.79→1, rotspd 40-60, **br 200, LE 0**, VPerp, Random flipbook, ts 0.5, colour `FF46D4`. Primary 7x7x1.

## Scan: Recon / Ping Spike
### `Misc.WarHornEffects.Default` (24-stud Part, one Attachment, white `FFFFFF`, LE 1)
| Layer | life | EC | spd | size | tr | br | fb |
|---|---|---|---|---|---|---|---|
| Burst1Fast | 0.12 | 1 | 100 | 0→4.07 (t0.4)→4.46 | 0→0.46 (t0.1)→1 | 4 | none |
| ripple | 0.23 | 2 | 50 | 0→2.4 (t0.1)→5.25 | 0→0.32→1 | 0.1 | 4x4 Loop 78 fps |
| Burst2Linger | 0.31 | 1 | 50 | 0→2.4→5.36 | 0→0.46→1 | 0.5 | none |
| rippleLinger | 0.46 | 1 | 50 | 0→1.8→4 | 0→0.85 (t0.1)→1 | 1 | none |
All LockedToPart, `EmitDuration=0`. A sound-wave cone from the horn: four rings, 0.12-0.46 s, fast then lingering. Scale comes from the 24-stud part.

### `Misc.DeflectActiveEffects.Default` / `DeflectHitEffects.Default`
| Effect | Layer | life | EC / ED | size | LE / br | notes |
|---|---|---|---|---|---|---|
| Active | ring | 0.12 | 1 | 0→0.42 (t0.1)→0.5 | 1 / 8 | 4x4 OneShot, rotspd 720, ts 0.2 |
| Active | star | 0.28 | 1 | 0→0.7→0.36→0 | 1 / 8 | rotspd 720, ts 0.2 |
| Active (`NotLocal`) | bigring / bigstar | 0.12 / 0.28 | 1 | to 5 / 6.9 | 1 / 8 | z -4; the **other-player** copy is 10x bigger |
| Hit | sparkle | 0.1 | 1 / 0 | 3→0 | 1 / 4 | `FF8146` |
| Hit | shard | 0.15-0.3 | 4 / 0.075 | 0→0.19→0 | 1 / 4 | VPar, `FFFFFF`→`FF8146`→`FF1111` |
| Hit | shard2 | 0.15-0.3 | 7 / 0.075 | 0→0.49→0 | 1 / 4 | as shard |
| Hit | PointLight | | | | br 3 (attr 2), range 24, white | |
Order: sparkle at 0, shards 75 ms later (the `EmitDelay` attribute).

## Healing: Heal Zone / Heal Orb / Stim
### `Misc.SmokeClouds.Default` (Model): **three Neon MeshPart cores, no particles**
1x1x0.99 `515559` (`DecaySpeed=2`, `DecayOffset=-1`), 0.98 `3F4346` (`DecaySpeed=999999`), 0.95 `484B4F` (`DecaySpeed=2`). The cloud is three nested lumpy meshes scaled up by script, each fading on its own decay attribute.
**Medkit / heal effect: NOT FOUND.** Searched `Misc` for Heal / Medkit / Regen; `ViewModels.Weapons.Medkit` is a model only (8 Parts, 21 MeshParts, 9 Models, 3 Attachments, no emitters); `PhysicalBundles.medkit_bundle` has 8 MeshParts.

## Shield: Barrier
`ViewModels.Weapons.Riot Shield`: 2 Parts, 5 MeshParts, 4 Attachments, **no emitters, beams or lights**. Deflect (above) is the only block-hit effect.

## Thrown props
| Prop | Parts | Trail |
|---|---|---|
| `Throwables.Molotov` | 3 MeshParts (bottle 0.57x1.6x0.57 Metal `2C5C2A`, label 0.63x0.73x0.27, cap 0.49x0.51x0.14) + Primary 0.16 cube | **two**: white Primary trail (life 0.25, width 1→0, tr 0→1, LE 1, Stretch, FaceCamera, attachments 0.5 apart) and an orange rag trail on the wick (`FF4800`, life 0.13) |
| `Throwables.Grenade` | 6 MeshParts (0.22-0.99 studs) + Primary 0.24 | one white Primary trail, same numbers |
| `Throwables["Smoke Grenade"]` | 6 MeshParts (0.13-0.76) + Primary 0.16 | same white trail |
Skin colour by `WrapGroup` attributes on the MeshParts. `SPA.Projectiles` not re-read (already summarised in the main note).

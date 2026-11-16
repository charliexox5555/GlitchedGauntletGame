# Ability VFX direction (2026-11-15 rework)

**Locked 2026-11-16.** This is the build spec for all nine Mods. Any change after this date needs the owner.

The shared effects language for the nine Mods. It replaces the look the owner rejected in playtest ("realistic" screen wind and streaks, realistic fire on players, glitch static on everything). Brief: [2026-11-15 Ability Rework](../04%20Tech/Prompts/2026-11-15%20Ability%20Rework.md). Plan: [Ability Rework](../05%20Production/Ability%20Rework%202026-11-15.md). It sits under [Style Bible](Style%20Bible.md) §4 (shapes over particles, stylised like Valorant, sprites under the Bloom threshold). Measured RIVALS numbers: [Ability VFX Numbers](../03%20Research/Rivals%20Reference/Ability%20VFX%20Numbers.md), summary in [Body, Viewmodel, Guns and VFX](../03%20Research/Rivals%20Reference/Body,%20Viewmodel,%20Guns%20and%20VFX.md) → Ability VFX. Where each effect is drawn in code: [Ability Effects Map](../04%20Tech/Ability%20Effects%20Map.md).

## The one rule
**Each element is recognisable from its motion, shape and timing alone**, in grey, with the sound off. Colour and glitch come after that.

## Grammar shared by every effect
1. **Shapes first.** Every big beat is a kit mesh with a designed outline (pointed, cut, faceted; no spheres, no round curves, no blunt ends). Particles are only the debris of a shape: few, big, short.
2. **Three beats.** Onset in 0.12 s or less, an active state that holds still enough to read, an exit in 0.3 s or less (healing: 0.4 s). Anticipation belongs to the animation.
3. **Held frames.** Meshes change pose on steps, particles run slowed flipbooks (see contradiction 1 and the timing table). Nothing drifts smoothly except healing and the scan shell.
4. **The aim area stays clear.** The middle 40% of the screen is empty in every state. No world layer spawns within 4 studs in front of the local camera. Any shell or crown fades to transparency 0.92 or more within 6 studs of the local camera.
5. **Colour.** Team colour (`client/Util/TeamColor`: ally `00E5FF`, enemy `FF5A36`) goes on gameplay lines: footprints, danger strips, reveal outlines, shields, protection states. Element colour goes on the body of the effect and is the same for everyone. White goes on motion that carries no gameplay meaning (wind, flashes).
6. **Glitch is a rare accent.** Two frames where the effect's own shape is doubled, offset 0.3 studs, with a `FF3DCB` edge. Only four beats carry it: Fork Fire split, Desync exit, Ping Spike wave front, Crash Recovery departure. No static, no screen tear, no purple wash.
7. **RIVALS gives numbers and recipes only.** No RIVALS texture, mesh or sound.

## The five contradictions, resolved
| # | Ours vs RIVALS | Decision | Reason |
|---|---|---|---|
| 1 | Stepped mesh fire vs smooth flipbooks slowed by TimeScale | **Both, with split jobs.** Mesh tongues are the body and step at 12 Hz. Particle licks use our own 4x4 flipbook at TimeScale 0.5, which plays 16 drawings in 1.0 to 1.4 s (11 to 16 fps) | RIVALS' "held" feel is a slow frame rate, which is the same idea as our stepping; the shape rule decides who carries the silhouette |
| 2 | Crash Down ring and fragments vs fire-and-smoke explosion | **Keep ring and fragments; take the explosion's structure.** One flash, one flat ring, strokes for the crescents, floor chips for the sparks, a floor-coloured dust skirt for the smoke, at RIVALS' timing | Fire belongs to Molly and Firewall; a fire cloud here would name the wrong element |
| 3 | Still teleport fold vs spinning portals | **Still.** The ring makes one quarter turn in 3 held steps during the snap, then stops. We take the flat layered plates, the Small to Big size swap and the single light | A constant spin on a standing anchor pulls the eye and reads as a portal you walk through; pinch-to-a-line is our own motion signature |
| 4 | One size for everyone vs owner and observer sizes | **Three viewer classes** (below). Footprints are identical for all; body bursts are full size for observers and replaced by screen-edge cues for the caster | The caster needs a clear aim area, observers need a readable shape; gameplay truth must not differ per viewer |
| 5 | Team-coloured rings vs white rings | **Team colour stays on gameplay lines; white on meaningless motion** | A footprint must answer "mine or theirs" at a glance in 4v4; white cannot |

**Viewer classes.** *Footprint* (rings, strips, patches, walls, shells, zones): same size, place and time for everyone. *Body burst* (shapes on or around the caster): observers see scale 1; the caster in first person sees none of it in the world and gets the *screen cue* instead; a caster in third person sees scale 0.4 and half the counts. *Screen cue*: caster (or victim) only, on the screen edges.

## Global timing and budget rules
| Rule | Value |
|---|---|
| One-shot layers | 0.6 s or less; dust, pall, mist and floor marks 1.35 s or less; nothing over 1.5 s. On-screen life = Lifetime / TimeScale and obeys the same caps |
| Burst shape | Every burst size uses **Pop** (half size by 10% of life). Order inside a burst by `EmitDelay`: flash at 0, debris 0.075 s later |
| Particles per effect | One-shot: 70 emitted or fewer. Sustained: 40 alive or fewer. Per client: 250 ability particles alive; over that, the farthest effects drop to the far tier |
| Mesh parts per effect | 40 or fewer, pooled (`ModVfx.mesh`, `VfxPool`), `CastShadow` off, no collision or queries |
| Lights | One PointLight per effect, no shadows, Range 27 or less. Flash lights decay to 0 in 0.3 s. Four ability lights per client, nearest win. No lights on players |
| Particle lighting | `LightInfluence` 0 on every layer. Brightness 4 or less when LightEmission is 0 or more; fire is LightEmission -1 with Brightness 5 to 7 |
| Mesh material | Neon at Transparency 0.02 or more (flat unlit colour, RIVALS recipe). If a mesh still blooms, darken its colour value until it does not. Ice is Glass at 0.5 |
| Distance | Under 60 studs: full. 60 to 120: particle counts halved, no chips or embers, the one key body shape of each effect (W1, T2, S2, X4) scaled 1.5; footprints never scale. Over 120: meshes and footprint only, no particles, no light |
| Held-frame rates | Fire meshes 12 Hz; fire particles TimeScale 0.5 (licks), 0.3 (embers, body licks), 0.25 (pall). Impact chunks and chips 12 Hz. Wind screen strokes 15 Hz, wind particles TimeScale 1. Teleport: 3 steps in the snap, dots TimeScale 0.5. Ice: no motion while held. Healing and scan: smooth, TimeScale 1 |
| Sizes | **R** = the Mod's gameplay radius in `shared/Config/Mods.luau`. Footprints are R, never a number from this note |
| Thrown props | An invisible Primary with one Trail between two Attachments 0.5 studs apart: white, life 0.25 s, width 1 to 0, transparency 0 to 1, LightEmission 1, FaceCamera. Molly adds a wick trail `FF6A1F`, life 0.13 s. Heal and Stim trails use the element colour, life 0.35 s |
| Old looks | The particle fallbacks in each `*Fx` file are frozen. Do not restyle them; delete each when its kit mesh ships |

## Layer kits
Layers are listed in build order: meshes first, then particles, then the light. Counts are `EmitCount` (EC, one-shot) or `Rate`. Sizes are studs.

**Size curves** (`time:value`, times the end size). Pop `0:0 0.1:0.5 0.3:0.8 1:1`. Spike `0:0 0.3:1 1:0`. Bell `0:0 0.5:1 1:0`. Grow `0:0.4 0.3:0.5 0.6:0.7 1:1`. Shrink `0:1 1:0`. Flat. **Mesh Snap:** scale 0 to 1.12 in 70% of the onset, back to 1 in the rest.
**Transparency curves.** Cut `0:0 0.77:0 0.81:0.38 0.89:0.74 0.96:0.95 1:1` (solid, then a late cut). Fade `0:0 1:1`. Haze `0:1 0.35:0.76 1:1`. Ping `0:0 0.1:0.46 1:1`.

| ID | Layer (kind) | Job | Count | Life s | Size and motion | Look: LE / Br or material | Owner vs others |
|---|---|---|---|---|---|---|---|
| **W1** | Strokes (mesh `FX_Stroke`) | The read: a move happened, this way | 4 | 0.25 | Length 6 to 10, width 0.5. Pop to full length in 0.05, hold, shorten from the tail over the last 0.12 | Neon 0.3, `F2F6FF` | Body burst |
| W2 | Gust ring (mesh `FX_Ring`) | Marks the start point, flat across the move | 1 | 0.2 | Pop 0 to 8, transparency 0.5 to 1 | Neon, `F2F6FF` | Body burst |
| W3 | Streaks (particles, `T_Streak`, VelocityParallel) | Debris of the strokes | EC 12 long + EC 4 short | 0.05-0.25 / 0.03-0.13 | Long: Pop to 1, speed 5-150, drag 24. Short: Spike to 0.4, speed 10-300, drag 48 | 1 / 0.5 and 1 / 4, white | Others only |
| W4 | Screen strokes (`WindStrokes.luau`) | The caster's version of W1 | 4 to 6 | 0.25 | In 0.05; 18 to 30% of screen height; edges only; 15 Hz | White, opacity 0.7 | Screen cue |
| **F1** | Tongues (mesh `Fire_TongueA/B/C`) | The silhouette of fire | Molly 14 (4 A, 6 B, 4 C; 60% on the rim). Firewall 3 per piece, 30 max. Hand 1 C | Whole burn | A 5-7 tall, B 3.5-5, C 2-3. Rise: Y Snap in 0.12. Four held poses at 12 Hz (Y x0.85 / 1 / 1.1 / 0.95, yaw ±12°, lean ±8°), a third of the tongues change per step. Sink: Y to 0 in 0.3 | Neon 0.02. A `C2260A` at the back, B `FF6A1F`, C `FFD98A` in front | Footprint |
| F2 | Licks (particles, `T_FlameSheet` 4x4 OneShot) | The rolling top edge between tongues | Rate 20 (Firewall 3 per piece, hand 6) | 0.5-0.7 at TimeScale 0.5 | Grow to 5 (hand to 1.2), acceleration up 40, drag 3, Cut | -1 / 5, `FFD98A` to `FF6A1F` to `C2260A` | Footprint |
| F3 | Embers (particles, `T_Chip`) | Rising sparks | Rate 20 | 0.2-0.4 at TimeScale 0.3 | Bell to 1, speed 70-130, spread 40, acceleration up 200, drag 15 | -1 / 7 | Footprint |
| F4 | Pall (particles, `T_Puff`) | Grounds the fire; dark red, never grey | Rate 5 | 0.3 at TimeScale 0.25 | 0.55R to 0.9R, under 3 studs high, Haze | 0 / 0.4, `8A1A08` | Footprint |
| F5 | Ignite (particles, one-shot) | The snap on landing | Spikes EC 6 (`T_Streak`), blooms EC 8 (`T_FlameSheet`), embers EC 10 at +0.075 | 0.05-0.13 / 0.3-0.6 / 0.3-0.6 | Spikes: Spike to 9, speed 170-250, drag 12. Blooms: Pop 5.5 to 11, speed 40-100, Cut. Embers: Bell to 1 | -1 / 7, -1 / 5, -1 / 7 | Footprint |
| F6 | Light | Carries the warm area | 1 | Whole burn | Range 27 | Brightness 3, `FF5A1A` | Footprint |
| F7 | Body licks (particles on the torso, LockedToPart) | A burning player | Licks Rate 8, embers Rate 5 | 0.2-0.4 at TimeScale 0.3 | Licks 2.2 Flat with Cut; embers 0.6 Flat with Fade. No smoke, no light | -1 / 5, -1 / 7 | Victim: none on the own body; two `T_FlameSheet` frames in the bottom screen corners at 12 fps |
| **I1** | Plates (mesh `Ice_PlateA/B/C`) | The read: hard, still shapes | Frost 6 in a fan. Freeze Frame 4 round the pose. Frost Wall 2 per piece | Held | A 4-5 tall, B 3, C 1-1.5. Snap in 0.1, then no motion at all | Glass 0.5, `A9DCFF` | Footprint |
| I2 | Cap (mesh `Ice_Cap`) | Solid base under the glass | 1 per cluster | Held | 1.2 x the cluster width, Snap in 0.1 | SmoothPlastic, opaque, `F4F8FA` | Footprint |
| I3 | Frost front (mesh `FX_FloorStar`) | Floor mark of the area | 1 | Held | Pop 0 to 2R across in 0.15 | Neon 0.4, `EAF7FF` | Footprint |
| I4 | Chips (particles, `T_Chip`, VelocityParallel) + shards (mesh `Ice_PlateC` at 0.3) | Snap debris and the shatter | Snap EC 10. Shatter EC 14 + 6 shards (Freeze Frame 8) | 0.15-0.3; shards 0.2 fall + 0.15 fade | Spike to 0.5, speed 40-90, drag 12. Shards fall under gravity, 12 Hz tumble | 1 / 3, `EAF7FF` | Footprint |
| I5 | Mist (particles, `T_Puff`) | A short cold breath on the snap | EC 4 | 0.4-0.6 | Pop 3 to 7, Haze | 0 / 2, `DDF0FF` | Footprint |
| I6 | Light | Cold inner light | 1 (Freeze Frame shell, one per Frost Wall) | Held | Range 14 | Brightness 1.5, `BFE6FF` | Footprint |
| **H1** | Crowns (mesh `Heal_Crown`) | The zone's edge; two nested, low | 2 (at 1.0R and 0.8R) | Held | 1.2 studs tall. In 0.2, out 0.4 (inner fades twice as fast). Pulse once a second: scale 1 to 1.04 to 1 in 0.25 | Neon 0.85 outer, 0.92 inner, `5CFFC8` | Footprint |
| H2 | Leaves (mesh `Heal_Leaf`) | The read: slow upward drift | Zone: 1 every 0.15 s, 6 alive. Healed body: 3 per second | 0.9 | Rise 5 studs, ease-out, scale 1 to 0.6, transparency 0.2 to 1 over the last 40% | Neon, `5CFFC8` | Footprint; on the own body: screen cue only |
| H3 | Ribbon (Trail) | Frames the orb in the palm and in flight | 2 | 0.35 | Width 0.5 to 0 | LE 0.6, `5CFFC8` | Same |
| H4 | Motes (particles, `T_Chip`) | Debris of the leaves | Rate 6, 8 alive | 0.6-0.9 | Shrink from 0.35, speed 2-4 up | 0.6 / 2 | Same |
| H5 | Light | Soft zone glow | 1 (zone only) | Held | Range 12 | Brightness 1, `5CFFC8` | Footprint |
| **T1** | Fold (mesh `Tele_Fold`) | The read: the body pinches to a line | 1 | 0.12 out / 0.15 in | Out: width 3.5 to 0.08 while height 5.5 to 7, then height to 0 in 0.05. In: the reverse | Neon 0.1, `9B6BFF` | Body burst |
| T2 | Snap ring (mesh `Tele_Ring`) | Closes on depart, opens on arrive | 1 | 0.12 / 0.15 + 0.1 fade | Out: 7.7 to 1. In: Pop 1 to 7.7. One 90° turn in 3 held steps, then still. Flat at waist height | Neon 0.02, `C9A8FF` | Body burst |
| T3 | Dots (particles, `T_Chip`) | Debris | EC 3 | 0.2 at TimeScale 0.5 | Shrink from 3 to 0.4 | 0 / 8, `C9A8FF` | Others only |
| T4 | Light | Arrival flash | 1 | 0.3 decay | Range 16 | Brightness 2, `9B6BFF` | Body burst |
| T5 | Anchor (mesh `Tele_Fold` at 0.35) | The closed, standing form | 1 | Held | Still. Pulse every 2 s: scale 1 to 1.08 to 1 in 0.2. No light, no particles | Neon 0.3, `9B6BFF` | Visibility as coded today |
| **S1** | Shells (mesh `Scan_Shell`) | The read: a constant-speed front | 3 nested (front, 0.94, 0.88 of the radius) | Radius / speed from Config | Constant speed, fades over the last 15% of the radius | Neon 0.55 front, 0.8, 0.9; team colour | Footprint |
| S2 | Ping (particles, `T_Ring`) | The source pulse at the dart | EC 1 fast + EC 2 ripple | 0.12 / 0.23 | Fast: Pop to 4.5, Ping. Ripple: Pop to 5.25, Ping | 1 / 4 and 1 / 0.5, white | Same |
| S3 | Outline (Highlight on body and `GGSkinLimb` limbs) | The reveal itself | 1 per revealed player | Reveal time, last 0.3 fades | Outline 0, fill 0.75 | Team colour of the revealed player | Allies of the caster; the victim gets DETECTED only |
| **X1** | Pressure ring (mesh `FX_Ring`) | The damage footprint, on the damage event | 1 | 0.25 | Pop 0 to 2R across, 0.15 above the floor, transparency 0.1 to 1 over the last 30% | Neon, team colour | Footprint |
| X2 | Chunks (mesh `Impact_ChunkA/B`) | The read: the floor broke | 8 | 0.6 | 1.2 to 2.2 each, placed at 0.3R to 0.7R. Up 2 to 5 in 0.15 (Pop), fall 0.3, sink 0.15; 12 Hz tumble | SmoothPlastic, floor colour under the hit | Third-person caster 5 |
| X3 | Crack (mesh `FX_FloorStar`) | The mark that stays | 1 | 1.35 | 1.2R across. In 0.05, hold 1.0, fade 0.3 | SmoothPlastic, floor colour darkened 40% | Footprint |
| X4 | Flash (particles, `T_Flash`) | One big hit frame | EC 1 | 0.15 | Pop to 0.8R, Fade | 1 / 4, white | Others only |
| X5 | Dust skirt (particles, `T_Puff`) | Outlasts the flash, hugs the floor | EC 10 at +0.075 | 0.9-1.2 | Pop to 0.5R, speed 80-115 outward and flat, drag 14, transparency 0.5 to 1 | 0 / 1, floor colour lightened 20% | Caster EC 5 |
| X6 | Floor chips (particles, `T_Chip`) | Debris of the chunks | EC 20 at +0.075 | 0.5-1.0 | Shrink from 0.9, speed 40-110, gravity | 0 / 1, floor colour | Caster EC 10 |
| X7 | Light | Hit flash | 1 | 0.25 decay | Range = R, 27 max | Brightness 4, white | Footprint |
| **B1** | Hex shell (existing `BarrierFx.makeBubble`) | The shield | 1 | Held | Unchanged shape | Neon 0.8, team colour | Owner inside: 0.93, and only the band below the horizon is drawn |
| B2 | Hit (plates flash + particles) | Ripple from the hit point; at most one per 0.1 s | 6 nearest plates; sparkle EC 1 (`T_Flash`); shards EC 4 + EC 7 at +0.075 (`T_Streak`, VelocityParallel) | 0.2 / 0.1 / 0.15-0.3 | Plates 0.8 to 0.3 to 0.8. Sparkle Shrink from 3. Shards Spike to 0.2 and 0.5 | 1 / 4, team colour | Owner: plates only |
| B3 | Break (mesh `Shield_Plate`) | Plates fall away | 12 + chips EC 12 (`T_Chip`) | 0.35 | Plates 1.5 across, fall and tumble at 12 Hz, fade over the last 0.15 | Neon 0.5, team colour | Same |
| B4 | Light | Break only | 1 | 0.3 decay | Range 12 | Brightness 3, team colour | Same |

## Per Mod
Times are seconds from the trigger. "Ring" means `FX_Ring` at 2R across, Neon 0.2, team colour, held for the effect's life.

| Mod / look | Beats | Layers | Colour | Caster sees | Others see | RIVALS reference |
|---|---|---|---|---|---|---|
| **Updraft** | 0-0.05 gust; strokes ride the rise; all gone by 0.25, before the peak | W2 flat at the feet, W1 x4 vertical, W3 | White | W4 from the bottom corners and sides to the top, timed with the hand flick | W1, W2, W3 | `ExplosionEffect` windring and crescents; `DashParticles` drag |
| Crash Down | 0-0.1 tuck (animation); dive until landing; impact on the damage event; settle to 1.35 | Dive: W1 x3, 10-14 long, vertical. Impact: X1-X7 | Ring team; chunks, dust and chips floor colour; flash white | W4 vertical during the dive; on impact X1, X3, 5 chunks, half dust, no flash, camera kick | Everything | `ExplosionEffect` (structure and timing; counts halved; fire and smoke swapped out) |
| **Dash** | 0-0.05 onset; travel; gone by 0.25. End: W3 short streaks only | W2 at the start, W1 x4 along the path, W3 | White | W4 x4 on the edges, pointing along the dash | W1, W2, W3 | `DashParticles` (speed, drag 24-48, life) |
| Ghost | Whole protection window; afterimage every 0.06, each fades in 0.2 in 3 steps | Dash layers + 3 body afterimages at transparency 0.6; body at 0.6 | Afterimages team colour (a protection state) | W4 at half opacity for the whole window; no flash | Afterimages and the see-through body | None (own) |
| Desync | Spawn: nothing extra (the decoy must fool). Exit 0.2: glitch accent 2 frames, then T1 at 0.5 scale in 0.12 | Exit: T1, inward streaks (W3 short, EC 10, from 3 studs out, speed 35), chips EC 8 | Decoy as a player; exit `9B6BFF` with the `FF3DCB` accent | Ally-colour outline on the own decoy, 0.5 | Enemies: a normal player until the exit. Allies: the outline | `Vortexes` (inward streaks, dark centre, small) |
| **Molly** | Flight; 0-0.12 ignite; burn; 0.3 sink | Thrown-prop trails; F5; F1-F4, F6; Ring; F7 on burning players | Fire colours; Ring team | Same as others (footprint). Burning: corner tongues | Same | `MolotovExplosionEffects`, `FireHitboxes`, `BurningEffects`, `Throwables.Molotov` |
| Fork Fire | Split: glitch accent 2 frames + F5 spikes EC 4; each bomblet then runs Molly at its own R | As Molly per patch; tongues scaled by area, 5 minimum per patch; one light per patch | As Molly | Same | Same | As Molly |
| **Firewall** | Hand flame while held; pieces rise 0.12 each, 0.03 apart, outward from the caster; burn; 0.3 sink | Hand: F1 (1 C) + F2 at Rate 6. Wall: F1 and F2 per piece, one F6 at the middle, an `FX_Stroke` floor strip per piece | Fire colours; strip team | Hand flame low right, outside the aim area; wall as others | Wall and hand flame | `FireHitboxes`, `FlamethrowerFlames` |
| Frost Wall | Pieces Snap 0.1 each, 0.03 apart; held still; 0.2 shatter | I1 (A and B alternating, lean ±10°), I2 strip, I4, one I6, `FX_Stroke` floor strip. Hand: 3 `Ice_PlateC`, no particles | Ice; strip team | As others | As others | `FreezeEffects` (glass blocks + solid base, no particles) |
| **Frost** | Flight; 0-0.1 snap; held; 0.2 shatter | Trail; I1 x6, I2, I3, I4, I5; Ring; hindered players carry 2-3 `Ice_PlateC` on shins and forearms, still | Ice; Ring team | As others. Hindered: `T_FrostCorner` in two screen corners, snap in 0.1, still | As others | `FreezeEffects` |
| Freeze Frame | 0-0.1 capture snap with one flash; held still; 0.2 shatter | I1 x4 round the pose, I2, X4 flash at 3 studs, I6; shatter I4 with 8 shards | Ice; flash white | Frozen player: `T_FrostCorner` in all four corners | Shell and shatter | `FreezeEffects` (four blocks + cap layout) |
| **Recon** | Dart flight; stick: S2; pulse: shell travels at Config speed; reveal holds, last 0.3 fades | Trail; S2; S1; S3 | Shell and outlines team; ping white | Same shell; outlines on revealed enemies | Shell. Victims: DETECTED status | `WarHornEffects` (one fast ring, lingering faint ones) |
| Ping Spike | Arming: dart blinks in 3 steps over 0.3. Wave: two S2 pings 0.075 apart, then S1 plus a second shell set 0.15 behind; glitch accent on the front | S2 x2, S1 x2, S3 with fill 0.5 | Team; accent `FF3DCB` | As Recon, stronger outline | As Recon | `WarHornEffects`; `DeflectHitEffects` (the 0.075 delay) |
| **Heal Orb** | Held: ribbons and motes; on heal: 0.2 in, leaves for the heal time, 0.4 out | H3 x2, H4; H2 on the healed body; `FX_Ring` Pop 0 to 3 at the feet in 0.2 | `5CFFC8` (the ring too: no footprint) | Green corner gradients in 0.2, out 0.4; HEALING status | Leaves and ring on the healed player | None found; `SmokeClouds` nested idea only |
| Barrier | Up: B1 Snap in 0.1; hits 0.2; break 0.35 | B1-B4 | Team | Shell at 0.93, lower band only; hit: plates flash | Full shell, hits, break | `DeflectHitEffects`, `DeflectActiveEffects` (owner and other sizes) |
| **Stim** | Beacon flight; deploy 0-0.1; active; 0.15 out | Trail; Ring Snap; X6 at EC 6; `Stim_Chevron` pairs rising 4 studs in 0.25, one pair every 0.5; bolt: one `FX_Stroke` beacon to player, 0.12, 2 held frames | Amber `FFC83D`; Ring team | Boosted: amber chevron pair on the left and right screen edges, once per second | Beacon, Ring, chevrons, bolts | `DashParticles` timing; none for the buff |
| Heal Zone | Deploy 0-0.2; active with a pulse each second; 0.4 out. (Strong Stim: as Stim with triples instead of pairs) | H1, H2, H4, H5; Ring; H2 on healed bodies | `5CFFC8`; Ring team | Inside: crowns at 0.92 or more, green corner gradients, HEALING status | Crowns, leaves, Ring | `SmokeClouds` (nested shells, own fade rates) |
| **Recall** | Anchor held; depart 0.12; arrive 0.15 + 0.1 ring fade | T5; T1, T2, T3; T4 on arrival. Range ring: `FX_Ring`, Neon 0.6, `9B6BFF` | `9B6BFF` | Range ring (caster only). Two violet edge bars close to 30% from each side in 0.12 and open in 0.15 | T1-T4 at both ends | `Portals` (flat plates, Small and Big, one light, 3 dots) |
| Crash Recovery | Departure: glitch accent 2 frames, then fold 0.12; a ghost stays 0.4 and fades in 3 steps; recovery: two T2 rings 0.075 apart, T1 in 0.15 | T1, T2 x2, T4; body copy at 0.7 | `9B6BFF`; accent `FF3DCB` | Edge bars with one 2-frame offset on the edges, never the centre | Ghost at the death spot, recovery at the anchor | `Portals`; `DeflectHitEffects` delay |

## Mesh list (19, about 630 triangles)
All: flat-shaded, hard edges, no smooth groups, longest side 1 stud at scale 1 (code scales in studs), `DoubleSided` on for the flat ones, no collision. An existing kit mesh (`GlitchVFX` cracks and rubble, `FireVFX`, `IceVFX`, `ModVFX`) is kept only if it meets its row here; otherwise it is rebuilt under this name. Build to `gauntlet-build-style`.

| Name | Kit | Element | Shape | Anchor | Tris |
|---|---|---|---|---|---|
| `FX_Stroke` | ModVFX | Wind, strips, bolt | Long thin wedge, pointed at both ends, diamond section, 1 x 0.08 | Head tip | 12 |
| `FX_Ring` | ModVFX | Footprints, gust, impact | Flat 16-sided ring, band 6% of the radius, 4 angled cut gaps | Centre, floor plane | 64 |
| `FX_FloorStar` | ModVFX | Ice front, impact crack | Flat jagged star, 9 uneven points, carved inner cuts | Centre, floor plane | 40 |
| `Fire_TongueA` | FireVFX | Fire | Tall hooked blade, tip curls over in 3 angled plates | Base centre | 28 |
| `Fire_TongueB` | FireVFX | Fire | Mid blade, hook the other way, split tip | Base centre | 24 |
| `Fire_TongueC` | FireVFX | Fire | Short blade, single hook | Base centre | 14 |
| `Ice_PlateA` | IceVFX | Ice | Tall angled prism, chipped top edge, 5 faces | Base centre | 28 |
| `Ice_PlateB` | IceVFX | Ice | Wide leaning plate, two chips out of one side | Base centre | 24 |
| `Ice_PlateC` | IceVFX | Ice, shards, hand | Small splinter, pointed | Base centre | 12 |
| `Ice_Cap` | IceVFX | Ice | Low angular frost mound, carved rim | Base centre | 20 |
| `Heal_Leaf` | ModVFX | Healing | Pointed leaf, one centre fold | Base tip | 8 |
| `Heal_Crown` | ModVFX | Healing | 16-sided low wall with a zig-zag top edge, height 7.5% of the diameter | Centre, floor plane | 96 |
| `Stim_Chevron` | ModVFX | Stim | Upward chevron, cut ends | Centre | 12 |
| `Tele_Fold` | ModVFX | Teleport | Flat tall hexagon with pointed top and bottom | Centre | 8 |
| `Tele_Ring` | ModVFX | Teleport | Flat octagonal ring, band 15% of the radius, 2 cut gaps | Centre | 48 |
| `Scan_Shell` | ModVFX | Scan | 80-face geodesic shell, both sides | Centre | 160 |
| `Impact_ChunkA` | ModVFX | Impact | Carved floor wedge, flat top | Base centre | 16 |
| `Impact_ChunkB` | ModVFX | Impact | Smaller tilted slab, broken corner | Base centre | 12 |
| `Shield_Plate` | ModVFX | Shield | Flat hexagon matching one shell cell | Centre | 8 |

## Texture set (7 new)
Check `shared/Config/VfxTextures.luau` first and make only what is missing. All are greyscale so `ColorSequence` tints them. For ChatGPT images: generate white on pure black, then turn brightness into alpha before upload. 1024 px square unless noted.

| Name | Used by | How |
|---|---|---|
| `T_FlameSheet` | F2, F5 blooms, F7, burn corners | **Make in Blender.** Render `Fire_TongueA/B/C` overlapped, toon-shaded in 3 flat greys, 16 frames of the hooks curling up and breaking off at the top, orthographic, to a 4x4 sheet (frame 1 top left, read in rows) |
| `T_Chip` | F3, I4, H4, T3, X6, B3 | ChatGPT: "A single small angular shard, a faceted four-sided diamond chip with one corner cut off, flat white with one light-grey facet, hard edges, no glow, no gradient blur, centred on a pure black background, square image, game VFX particle sprite." 256 px |
| `T_Streak` | W3, F5 spikes, B2 shards | ChatGPT: "A single long thin tapered stroke, pointed at both ends like a stretched diamond, standing vertical and centred, solid flat white with crisp hard edges, no glow, no blur, no texture, on a pure black background, square image, game VFX particle sprite." 256 px |
| `T_Puff` | F4, I5, X5 | ChatGPT: "A single stylised dust puff built from flat angular facets like low-poly paper, a lumpy cluster with 7 to 9 straight-edged lobes, three flat grey values (white top, mid-grey body, dark-grey underside), hard edges, no soft airbrush, no realism, centred on a pure black background, square image, game VFX particle sprite." 512 px |
| `T_Ring` | S2 | ChatGPT: "A thin ring made of 16 straight segments (a faceted circle, not smooth), with four small angled gaps cut into it, flat white, uniform line weight about 4% of the width, hard edges, no glow, centred and filling 90% of a square pure black background, game VFX particle sprite." 512 px |
| `T_Flash` | X4, B2 sparkle, Freeze Frame snap | ChatGPT: "A sharp four-point impact flash: a long horizontal and a shorter vertical tapered spike crossing at the centre, with a small solid angular octagon core, flat white, crisp hard edges, no glow, no lens flare, no soft halo, centred on a pure black background, square image, game VFX particle sprite." 512 px |
| `T_FrostCorner` | Frost and Freeze Frame screen cue | ChatGPT: "Stylised ice growing from the top-left corner of the image: overlapping angular plates and pointed shards with chipped edges, flat white with light-grey facets, hard edges, no realism, no frost noise, covering only the outer third near the corner and fading to nothing toward the centre, on a pure black background, square image, game UI overlay." Mirror it in code for the other corners |

## Review method
Every effect is judged in motion from the caster's view and from another player's view, in the test range, with a slow-motion freeze (`VfxTimeScale`) for captures. An effect passes when the element can be named from a greyscale capture and the aim area is empty in the caster's capture.

## Needs the owner
1. Run the six ChatGPT prompts and pick one result each (the builders start with meshes meanwhile).
2. Sign off the greyscale captures per element before the next element starts.

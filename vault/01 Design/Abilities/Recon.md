# Recon (was Ping)

**Status:** spec locked 2026-10-29 · built 2026-10-29 (built overnight; waiting for the user's Studio test)
**Inspiration:** Sova's Recon Bolt (Valorant), **without the bow**. You fire a sensor dart from a **compact dart launcher**; it sticks, pulses twice, and reveals enemies the dart can see.
**Remove from the old Ping:** the instant reveal pulse around yourself.

> **Look & sound:** follow the [Look & sound standard](00%20Abilities.md#look--sound-standard-every-ability-this-is-not-optional): Blender models, Blender-rendered effect textures, real hand animations, placeholder sounds in every hook.

## How it works
| Rule | Value |
|---|---|
| Ready | Press the key → the gun lowers, the **dart launcher** comes up and a dart is loaded. Press again or swap weapons to cancel (costs nothing) |
| Charge | **Hold LMB to charge** the shot distance (~1 s to full); release to fire. A quick tap = a short shot |
| Bounces | **RMB (before firing) cycles 0 / 1 / 2 wall bounces.** Bounce physics are shared with the Molly/Frost projectile code |
| Flight | A fast dart with a slight arc. After its bounces it **sticks to the next surface** it hits (walls, floor, ceiling) |
| Pulses | Once stuck: **2 pulses, 1.5 s apart** (first pulse ~0.5 s after sticking), then it goes dead |
| Reveal | Each pulse reveals **enemies within 40 studs that the dart has line of sight to** (hiding behind cover beats it) |
| Revealed look | A **live outline** that follows them, **visible through walls to the caster's team, for 2 s** |
| Warning | Revealed players get a **distinct pulse sound + a brief red screen-edge flash and "Revealed" cue** |
| Destroyable | **1 hit from any bullet destroys the dart** (stops further pulses) |
| Charges | **1 charge, 30 s cooldown** (starts each round ready; usually 1, sometimes 2 uses per round). Unlimited in test mode |

## Server
- The server simulates the dart (charge power, bounces, stick point), runs the pulses and the line-of-sight checks, and decides who's revealed.
- **Only the caster's team receives the outline data**: never send revealed positions to anyone else.
- The dart is a hittable target for the weapon system (1 HP).
- Validates: holding Recon, a charge ready, the origin near the head, finite direction and charge values, bounce count 0–2, rate limits.

## First person
- **Launcher out + load dart:** the gun lowers, the launcher comes up and a dart slides in.
- **Charge:** while holding LMB, the launcher hums and a charge light fills. RMB clicks a **bounce counter** (0/1/2 small lights on the launcher).
- **Fire:** a solid thump and recoil kick, then the launcher drops and the gun comes back.
- **Charge meter (placeholder HUD, Valorant-style):** under the crosshair while the launcher is up: a POWER bar with ticks at 25/50/75% and the percent (MAX, flickering, at full), and BOUNCES pips for the RMB pick.

## Look (Blender)
- **Dart launcher:** a compact, chunky flare-gun-style launcher with a charge light and a 3-light bounce counter, in the current tactical style (matte, PBR). It goes through the gun pipeline.
- **Dart:** a slim sensor dart with a small blinking light; it embeds where it sticks.
- **In flight:** a faint light trail.
- **Pulse:** an expanding scan ring/sphere from the dart (visible to everyone, so enemies know where it is); the dart's light flashes on each pulse.
- **Revealed enemies:** a clean outline/highlight in the enemy colour for 2 s.
- **Destroyed:** sparks and the light dies.

## Sound (hooks + placeholder sounds)
| Hook | What |
|---|---|
| `Recon_Equip` | Launcher out + dart load |
| `Recon_Charge` | Charge hum (rises) |
| `Recon_BounceSelect` | Bounce counter click |
| `Recon_Fire` | Launcher thump |
| `Recon_Flight` | Dart whistle (3D) |
| `Recon_Bounce` | Ricochet tick (3D) |
| `Recon_Stick` | Dart embeds (3D) |
| `Recon_Pulse` | Scan pulse (3D, ~60 studs: everyone hears it) |
| `Recon_Revealed` | Cue for the player who got revealed (2D) |
| `Recon_Destroyed` | Dart shot down (3D) |

### Placeholder sounds (in `Config/ModSounds` → `Recon`; unauditioned, swap the id)
All ProSoundEffects library audio (public, no upload). Search terms that worked: `"Crossbow Movement"`, `"Power Up"`, `"Selector Switch"`, `"Launcher" Pro Sound Effects`, `"Arrow Pass"`, `"Ricochet"`, `"Arrow"`, `"Spaceship Sonar"`, `"Radar Bleeps"`, `"Alarm"`, `"Electricity"`, `"Light Bulb"`.
| Hook | Id | Name (start / cut) | Volume / pitch | Alternatives |
|---|---|---|---|---|
| `Recon_Equip` | 9114004483 | Crossbow Movement Latches 13 (from 0.18, 1.6 s) | 0.5 / 1.1 | 9116973855, 9114004334 |
| `Recon_Charge` | 9117882920 | Power Up Accelerating Motors 1 (from 0.25, loops to 2 s, pitched up by code) | 0.5 | 9117882918, 9118327718 |
| `Recon_BounceSelect` | 9118727210 | Rotary Selector Switch Twisting 9 (from 0.2, 0.15 s) | 0.6 / 1.1 | 9118726753, 9118727189 |
| `Recon_Fire` | 9114659666 | Grenade Launcher 2 (one thoonk, 0.22 s) | 0.7 / 1.1 | 9114659685, 9117052716 |
| `Recon_Flight` | 9125363711 | Arrow Pass Bys Zooming Past Distant Landing 7 (loops 0.8–1.5 s) | 0.6 / 1.15 | 9113168250, 9113166206 |
| `Recon_Bounce` | 9118168962 | Ricochet Metal 5 (from 0.14, 0.3 s) | 0.5 / 1.3 | 9118168612, 9118168610 |
| `Recon_Stick` | 9113162981 | Arrow In And Hit 6 (from 0.5) | 0.6 / 0.95 | 9113161857, 9113160887 |
| `Recon_Pulse` | 9125981390 | Spaceship Sonar Low And High Pitch Tonal Throbs 1 (1.5 s; 60 studs). A library recording but synth-like: if too synthetic, try 9112776779 (Vintage Radar Bleeps) | 0.9 | 9125984483, 9112776779 |
| `Recon_Revealed` | 9113719080 | Car Alarm Chirp 1 (from 0.14, 0.35 s) | 0.5 / 1.05 | 9113719083, 9118777141 |
| `Recon_Destroyed` | 9119594871 + 9116264240 | Static Zap Body Two Buzzy Impacts 2 + Light Bulb 1 | 0.6 + 0.4 | 9114247527, 9114249288 |

## Build notes (2026-10-29)
- **Removed:** the Ping's instant pulse. `ReplicatedStorage.Abilities` has no Ping model.
- **New use type `HeldCharge`:** hold the Mod (the launcher comes up), hold LMB to charge (`chargeTime` 1 s; the charge light fills, the hum rises), release to fire; RMB before firing cycles 0 / 1 / 2 bounces (the launcher's two bounce lights, and the hint shows "Bounces: n"). `ModUse` carries the charge and bounces; the server caps the charge to how long it saw the hold, and the bounces to 0–2.
- **Rules:** `Mods/Recon`: speed 45 (tap) to 130 (full), a slight arc; the shared projectile code bounces it then it sticks to the next surface. Stuck, it's a 1-HP Mod object (`ModEntities`; any bullet destroys it through the existing object-hit path). Pulses at 0.5 s and 2 s after sticking: enemies within 40 studs the dart can see are revealed to your team only (`ModReveal`, outline through walls, 2 s); revealed players get the cue, a red edge flash and "REVEALED". Measured in Studio: the dart stuck 0.18 s after the shot, two pulses 1.5 s apart, each revealed the enemy dummy and a range dummy.
- **Models:** Blender `tools/blender/build_mod_recon.py` (launcher, handheld, 2.9K tris, `Charge_Energy`, `Bounce1/2_Energy`, the loaded `Dart_*` hidden when fired) and `build_mod_recondart.py` (sensor dart, 1.3K tris, `Light_Energy` blinks and flashes on pulses), uploaded (101313572671047, 116053167550293) and built into **`ReplicatedStorage.Abilities.Recon` / `ReconDart`** (backups in `art-source/abilities/Studio/`). Preview `02 Art/References/abilities/recon/recon_model.jpg`.
- **Effects:** Blender-rendered textures (`tools/vfx/make_recon_vfx.py`, `Config/VfxTextures RECON_*`): the scan ring on each pulse (plus the ground scan wave), the dart's glow trail in flight. The launcher kicks on fire (`ITEM_ACTIONS.LauncherFire`).
- **Icon:** still the Ping's. The Look section mentions a 3-light bounce counter; the model has 2 (0 / 1 / 2 needs only two).


## Changes from the user's feedback (2026-10-29)
- **Charge meter:** `ModController.chargeState()` feeds a meter in `ModHudController` (fades in with the launcher, the fill eases to the charge). Temporary until the HUD rework.
- **The dart reads in flight:** a bright light streak behind it (a camera-facing `Trail` with the `RECON_TRAIL` texture, white to team colour, 0.3 s) and a small team-coloured light on it, both off when it sticks; bigger glow particles (`ModFxController` `streakOf`).

## Mobile
Tap the Recon button to ready it. **Hold Fire** to charge, release to shoot. A **Bounce** context button cycles 0/1/2. Tap the Recon button again to cancel.

## Counter-play
Hear it land and **shoot the dart** (1 hit), or break line of sight before the pulse. When you're revealed, move: the outline only lasts 2 s.

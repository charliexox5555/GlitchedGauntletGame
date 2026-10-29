# Recon (was Ping)

**Status:** spec locked 2026-10-29 · not built
**Inspiration:** Sova's Recon Bolt (Valorant), **without the bow**. You fire a sensor dart from a **compact dart launcher**; it sticks, pulses twice, and reveals enemies the dart can see.
**Remove from the old Ping:** the instant reveal pulse around yourself.

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

## Mobile
Tap the Recon button to ready it. **Hold Fire** to charge, release to shoot. A **Bounce** context button cycles 0/1/2. Tap the Recon button again to cancel.

## Counter-play
Hear it land and **shoot the dart** (1 hit), or break line of sight before the pulse. When you're revealed, move: the outline only lasts 2 s.

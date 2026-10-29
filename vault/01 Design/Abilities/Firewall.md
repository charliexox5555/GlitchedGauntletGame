# Firewall

**Status:** spec locked 2026-10-29 · built 2026-10-29 (tested by the user in Studio)
**Inspiration:** Phoenix's Blaze (Valorant). A **wall of fire you steer** that **blocks vision**, not a cover wall.
**Remove from the old Firewall:** the short placed bullet-blocking wall, its HP and the placement hologram. (The cover-wall idea is parked as a future power: see "Bench" in the [overview](00%20Abilities.md).)

> **Look & sound:** follow the [Look & sound standard](00%20Abilities.md#look--sound-standard-every-ability-this-is-not-optional): Blender models, Blender-rendered effect textures, real hand animations, placeholder sounds in every hook.

## How it works
| Rule | Value |
|---|---|
| Ready | Press the key → your free hand **ignites** with a flame; the gun is lowered. Press again or swap weapons to cancel (costs nothing) |
| Cast (LMB) | **Hold LMB:** the wall **builds forward from your feet** along the ground (~40 studs/s). **Turn your camera while holding to curve it** (turn rate capped so it stays a smooth curve). Releasing LMB ends it early; it stops automatically at max length |
| Cast (RMB) | Builds the wall **dead straight** where you're looking, full length |
| Size | Up to **40 studs long**, **~10 studs tall** (fully blocks sight), ~1.5 studs thick |
| Duration | **6 s** after it finishes building, then dies down over ~0.5 s |
| Blocks | **Vision only.** Bullets and players pass through it (shots ignore it) |
| Terrain | **Goes through walls and cover** (Phoenix-style) and follows the ground height as it travels |
| Damage | **30 per second** while inside (0.25 s ticks); stops instantly when you leave |
| Who burns | **Enemies full damage, teammates 50%, you are immune to your own wall** |
| Charges | **1 per round, no recharge** (unlimited in test mode) |

## Server
- While building, the client streams its steering direction (rate-limited). The server clamps it to the max turn rate and builds the authoritative wall path. Segments are snapped to the ground below.
- The server applies damage. It validates that the player is holding Firewall, has a charge left, and that every number is finite.

## First person
- **Flame in hand on equip:** the free hand lights up, Phoenix-style.
- **Push-out cast:** the hand thrusts forward as the wall starts, then guides it while you steer.
- **Inside the wall:** a strong orange heat haze and limited vision while you're in it.

## Look (Blender)
- **Tall curtain of realistic fire** with smoke rising off the top, so it's opaque. It shares the Molly's Blender-rendered flame and smoke flipbooks, so the two fires match.
- A **bright leading flame front** races along as the wall builds; embers drift off it; a scorched line on the ground; a warm light along its length.
- **End:** the flames sink and die out; the scorch line fades.
- **Third person:** others see the caster's burning hand and push-out pose.

## Sound (hooks + placeholder sounds)
| Hook | What |
|---|---|
| `Firewall_Ignite` | Hand flame lighting |
| `Firewall_Cast` | Cast whoosh |
| `Firewall_Build` | The wall racing forward (3D) |
| `Firewall_Loop` | Fire wall roar/crackle loop (3D, ~50 studs) |
| `Firewall_PassThrough` | Sizzle when someone walks through |
| `Firewall_End` | Dying out |

### Placeholder sounds (in `Config/ModSounds` → `Firewall`; unauditioned, swap the id)
All ProSoundEffects library audio (public, no upload); a deep roar, unlike the Molly's crackle. Search terms that worked: `"Fire Whoosh"`, `"Fire Burst"`, `"Torch O Fire"`, `"Kerosene Explosion"`.
| Hook | Id | Name (start / cut) | Volume / pitch | Alternatives |
|---|---|---|---|---|
| `Firewall_Ignite` | 9114446852 | Fire Whoosh 15 (from 0.05 s) | 0.5 / 1.1 | 9120193891, 9121005779 |
| `Firewall_Cast` | 9114441555 | Fire Whoosh 8 (from 0.38 s, 1.1 s) | 0.7 / 1.0 | 9114443503, 9114439997 |
| `Firewall_Build` | 9114430091 | Fire Burst 2 (from 0.45 s, 1.2 s; 3D 60 studs) | 0.6 / 1.1 | 9114439216, 9114432075 |
| `Firewall_Loop` | 9114429835 | Fire Burst 8 (loops 2.8–6.2 s; 3D 50 studs) | 0.2 / 1.0 | 9114429860, 9112780691 |
| `Firewall_PassThrough` | 9125616715 | Kerosene Explosion Whooshing Poofs Crackling 6 | 0.6 / 1.05 | 9125615451, 9119166199 |
| `Firewall_End` | 9114429835 | Fire Burst 8, its tail from 7 s | 0.3 / 1.0 | 9114430091 (from 2.8 s), 9114432075 (from 3.5 s) |

## Build notes (2026-10-29)
- **Removed:** the placed cover wall (its placement, HP, hologram, skins, hum, sounds). `ReplicatedStorage.Abilities.Firewall` (Studio) is now unused. The generic placed-object code (ModEntities objects, `Blocks/Placeable`) stays, dormant, for the Barrier idea on the bench.
- **New use type `HeldSteer`:** hold the Mod (the free hand ignites), LMB starts the wall and streams your look (`ModSteer`, ~20/s, validated and rate-limited); releasing ends it. RMB builds straight. The gun stays down until the server says the wall is built; pressing the key again or releasing the hold ends the wall where it is.
- **Server:** `Services/ModWalls`: grows at `speed` 40 toward the server's own copy of your camera (the stream is a fallback), turning at most `turnRate` 110°/s; each point drops onto the floor below (through walls, over cover); every 4 studs a piece (invisible, no collision, no queries: shots and players pass) in `workspace.ModWalls`. Burns every 0.25 s: enemies 7.5, your team 50%, you 0. 6 s after it's built, then the pieces go. Measured in Studio: RMB builds exactly 40 studs in 1.0 s; an ally dummy took 15/s, the caster nothing.
- **Look:** `Util/WallFx` dresses each piece with the Molly's Blender flame and smoke flipbooks (a dense low layer, a taller layer, dark smoke off the top: it hides what's behind), embers, a light on every other piece, a flare on the newest piece, scorch along the line, flames sinking over 0.5 s at the end. Standing in it: an orange heat haze and blur. Others see the flame in a caster's hand.
- **Animations:** first person: the free hand held up with a flame (`Config/Viewmodel FREE_POSES.FirewallReady`), pushed out to guide (`FirewallGuide`); third person: new `GG_ModCast` push-out clip.
- **Icon:** still the old wall's.
- **Not tested by me:** the curve while steering (the test tools can't turn the camera mid-hold).

## Mobile
Tap the Firewall button to ready it. **Hold Fire** to build, dragging the camera to steer. A **Straight** context button appears for the straight cast. Tap the Firewall button again to cancel.

## Counter-play
Shots go straight through it, so spray it if you heard footsteps. You can also wait it out (6 s), or run through and take ~15–20 damage.

# Firewall

**Status:** spec locked 2026-10-29 · not built
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

## Mobile
Tap the Firewall button to ready it. **Hold Fire** to build, dragging the camera to steer. A **Straight** context button appears for the straight cast. Tap the Firewall button again to cancel.

## Counter-play
Shots go straight through it, so spray it if you heard footsteps. You can also wait it out (6 s), or run through and take ~15–20 damage.

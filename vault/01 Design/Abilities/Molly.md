# Molly (was Packet)

**Status:** spec locked 2026-10-28 · not built
**Inspiration:** Valorant mollies (Brimstone's incendiary, Phoenix's Hot Hands). A thrown incendiary canister that lands and spreads a **fire patch**.
**Remove from the old Packet:** the arc/trajectory preview, the ground bounce, the fuse timer and the explosion damage.

> **Look & sound:** follow the [Look & sound standard](00%20Abilities.md#look--sound-standard-every-ability-this-is-not-optional): Blender models, Blender-rendered effect textures, real hand animations, placeholder sounds in every hook.

## How it works
| Rule | Value |
|---|---|
| Activation | **Held throw.** Press the key → you pull out the canister and pull the pin. **LMB = overhand throw** (long), **RMB = underhand lob** (short). **No trajectory line**, you just throw it, like Valorant |
| Cancel | Press the key again, or swap weapons. Costs nothing |
| Gun | Lowered while holding; comes back after the throw |
| In flight | **Bounces off walls, bursts the moment it touches the ground** (a surface facing up). No bouncing on the floor |
| Phoenix-style drop | If it's been in the air too long (start at **0.9 s**, config), it **stops flying forward and drops straight down** where it is, then bursts on landing |
| Fire patch | **~9-stud radius** on the ground where it lands, **4 s** |
| Damage | **45 damage per second** while standing in it (ticks every 0.25 s); ~2 s kills from full HP |
| Who burns | **Everyone:** enemies full damage; **you and teammates take 50%** (the shared friendly-fire rule) |
| Leaving the fire | **Damage stops instantly** (no afterburn) |
| Vision | **Low flames**, about knee-high, with a little smoke. You can see and shoot over it |
| Charges | **1 per round, no recharge, no cooldown** (unlimited in test mode) |

Throw speeds and the drop time are config values. Tune them so LMB reaches across a mid-size room and RMB drops a few studs in front of you.

## Server
The server simulates the canister (authoritative: bounces, drop, landing point) and applies the fire damage. The client plays the throw and flight visuals instantly. It validates: holding the Molly, a charge left, the throw origin near the player's head, a finite direction, rate limits.

## First person
- **Pull pin on equip:** your hand brings up the canister and pulls the pin.
- **Overhand throw on LMB:** a full arm wind-up and release.
- **Underhand toss on RMB:** a softer underhand lob.

## Look (Blender, not plain Roblox parts)
- **Canister:** a military-style **incendiary grenade canister**, modelled in Blender to the current art direction (professional tactical, matte, PBR).
- **Fire:** made with Blender, e.g. flame and smoke **flipbook sprite sheets rendered from a Blender fire simulation**, or the existing VFX texture tools if they look better:
  - realistic **low flames** across the patch, a little smoke, floating embers
  - a **flickering warm light**, light heat haze if it's cheap
  - a **scorch decal** on the ground
  - a **clear burning edge**, so everyone can see exactly where it's safe
- **Burst:** a canister pop, a quick whoomp of flame spreading out to the radius, then the steady fire.
- **In flight:** the canister spins, with a small fuse spark/smoke trail so enemies can spot it.
- **End:** the flames die down and sizzle out over ~0.5 s; the scorch mark fades after a few seconds.
- **Burning player:** a small flame/ember effect on whoever is taking fire damage.

## Sound (hooks + placeholder sounds)
| Hook | What |
|---|---|
| `Molly_Equip` | Canister out |
| `Molly_PinPull` | Pin pull |
| `Molly_Throw` | Throw whoosh (overhand / underhand) |
| `Molly_Flight` | Short hiss while flying (3D) |
| `Molly_Bounce` | Metal clink off walls (3D) |
| `Molly_Burst` | Pop + flame whoomp (3D, ~50 studs) |
| `Molly_FireLoop` | Crackling fire loop (3D, ~40 studs) |
| `Molly_SizzleOut` | Fire dying |
| `Molly_Burning` | Sizzle/hurt for the player taking fire damage |

## Mobile
Tapping the Molly button holds it. The **Fire** button throws (overhand) and a **Lob** context button appears for the underhand toss. Tap the Molly button again to cancel.

## Counter-play
Watch for the spinning canister and listen for the clink and burst. Step out and the damage stops instantly. It's one per round, so bait it out.

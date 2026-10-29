# Molly (was Packet)

**Status:** spec locked 2026-10-28 · built 2026-10-29 (tested by the user in Studio)
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
| Phoenix-style drop | If it's been in the air too long (**1.3 s**, config; was 0.9), it **stops flying forward and drops straight down** where it is, then bursts on landing |
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

### Placeholder sounds (in `Config/ModSounds` → `Molly`; unauditioned, swap the id)
All ProSoundEffects library audio (public, no upload). Search terms that worked: `"Grenade Pull Pin"`, `"Gun From Holster"`, `"Swish"`, `"Fireworks Sparks"`, `"Canister"`, `"Fire Whoosh"`, `"Fireball"`, `"Sizzle" Pro Sound Effects`.
| Hook | Id | Name (start / cut) | Volume / pitch | Alternatives |
|---|---|---|---|---|
| `Molly_Equip` | 9114701864 | Gun From Holster 1 (cut 0.75 s) | 0.5 / 1.1 | 9114659662, 9114701872 |
| `Molly_PinPull` | 9114659833 | Grenade Pull Pin 2 | 0.65 / 1.0 | 9114659662, 9121005566 |
| `Molly_Throw` (overhand) | 9126013811 | Swish Med High End Sharp Swords Fast Punches (from 0.1, 0.4 s) | 0.5 / 0.9 | 9126283592 |
| `Molly_Throw` (underhand) | 9126283272 | Wood Swish Ruler Whoosh Fast Movement In Air (from 0.18) | 0.35 / 0.85 | 9126283592 |
| `Molly_Flight` | 9114447275 | Fireworks Sparks 2 (loop from 1.0 s, 35 studs) | 0.4 | 9114447505, 9120192302 |
| `Molly_Bounce` | 9113704665 | Canister Drop Canister Impact 1 (cut 0.45 s) | 0.6 | 9113704798, 9116617140 |
| `Molly_Burst` | 9114442751 | Fire Whoosh 2 (50 studs) | 0.9 / 0.85 | 9114428537, 9114428560 |
| `Molly_FireLoop` | 9112780561 | Fire Whoosh 1, kerosene fire loop (40 studs) | 0.5 | 9112780462, 9112780193 |
| `Molly_SizzleOut` | 9114428855 | Fireball Sizzle 2 (from 3.3, 1 s) | 0.6 | 9114428859, 9119165930 |
| `Molly_Burning` | 9119166425 | Sizzle Short And Explosive Sear 13 (cut 0.35 s, every 0.3 s while burning) | 0.35 | 9119165650, 9119166435 |

## Build notes (2026-10-29)
- **Removed:** the Packet grenade (arc preview, floor bounces, fuse, explosion). `ReplicatedStorage.Abilities.Packet` (Studio) is now unused.
- **Rules:** `Mods/Molly` (server). `Blocks/Projectile` got `groundStop` (only a floor ends the flight; a wall that would stop it drops it straight down) and `dropAfter` (0.9 s). On landing the fire ticks every 0.25 s for 4 s through owner timers (it keeps burning if the thrower dies): 11.25 per tick to enemies, `Config/Mods FRIENDLY_FIRE` 0.5 of that to you and your team, only with a clear line from the fire. Measured in Studio: an enemy dummy 100 → 0 in ~2 s; you and an ally dummy 100 → 10 over the 4 s.
- **Numbers to tune** (`Config/Mods` Molly L1): `throwSpeed` 72 (a level throw lands ~25 studs out; aim up for more, it drops at 0.9 s), `lobSpeed` 24 (~9 studs).
- **Model:** Blender `tools/blender/build_mod_molly.py` (AN-M14-style canister, 0.56 studs, 2.3K tris; `Pin`, `Lever`, `Fuse_Energy` team-tinted), uploaded (asset 81883123985254) and built into **`ReplicatedStorage.Abilities.Molly`** (backup `art-source/abilities/Studio/Molly.rbxm`). Preview `02 Art/References/abilities/molly/molly_model.jpg`.
- **Effects:** `Util/MollyFx` from Blender-rendered textures (`tools/vfx/make_molly_vfx.py`, ids in `Config/VfxTextures MOLLY_*`, preview `molly_vfx_preview.png`): looping low flames over the patch, a taller burning edge, smoke, embers, a flickering light, the whoomp sheet, a scorch that lingers 3 s, flames on whoever is burning. In flight: the canister spins with fuse sparks and a hiss, and clinks off walls. `molly_edge.png` is rendered but not used yet (the edge is flame sprites).
- **Animations:** first person: the free hand pulls the pin on equip (the pin disappears), overhand `Throw` / underhand `Lob` (`Config/Viewmodel`); third person: new `GG_ModLob` clip for RMB.
- **Icon:** still the Packet's until Molly gets its own.


## Changes from the user's feedback (2026-10-29)
- **Longer throws:** `throwSpeed` 72 → **88**, `dropTime` 0.9 → **1.3**. Longest LMB throw on flat ground (the game's own projectile code, best angle): **54 → 82 studs**. The lob is unchanged.
- **Damage numbers stay on the target:** a burning enemy's number sits beside them and is hidden while they're off your screen (`Util/HitFeedback`); before, an off-screen hit point parked the number by your crosshair. This applies to every damage number (Firewall too).

## Mobile
Tapping the Molly button holds it. The **Fire** button throws (overhand) and a **Lob** context button appears for the underhand toss. Tap the Molly button again to cancel.

## Counter-play
Watch for the spinning canister and listen for the clink and burst. Step out and the damage stops instantly. It's one per round, so bait it out.

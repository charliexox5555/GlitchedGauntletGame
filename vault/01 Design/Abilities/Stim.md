# Stim (was Overclock)

**Status:** spec locked 2026-10-29 · not built
**Inspiration:** Brimstone's Stim Beacon (Valorant). You drop a beacon; **teammates (and you) who step into its zone get a combat stim** that boosts fire rate, movement speed, weapon swapping and reloading. **Team only:** it never affects enemies.
**Remove from the old Overclock:** the instant self-only fire-rate buff.

> **Look & sound:** follow the [Look & sound standard](00%20Abilities.md#look--sound-standard-every-ability-this-is-not-optional): Blender models, Blender-rendered effect textures, real hand animations, placeholder sounds in every hook.

## How it works
| Rule | Value |
|---|---|
| Activation | **Instant on press:** you **drop the beacon at your feet** |
| Zone | **10-stud radius**, lasts **8 s** |
| Who | **You and your teammates only.** Enemies are never affected |
| Buff | **Stimmed** while inside the zone **and for 4 s after leaving** (re-entering refreshes it) |
| Destroyable | **No:** it lasts the full 8 s |
| Charges | **1 per round, no recharge** (unlimited in test mode) |

## Stimmed (a shared status effect, like Hinder)
| Stat | While stimmed |
|---|---|
| Fire rate | **+15%** |
| Move speed | **+15%** |
| Weapon swap / equip | **30% faster** |
| Reload | **15% faster** |

- Server-authoritative, with an expiry time on the character (e.g. `StimmedUntil`), built on the same status-effect system as [Frost](Frost.md)'s Hinder. The server enforces fire rate, swap and reload times.
- **Combining with Hinder:** the effects multiply (a stimmed and hindered player is roughly back to normal speed). All numbers are in config.

## First person
- **Pull beacon from belt + slam down:** the gun dips, your hand grabs the beacon and drops/slams it at your feet with a quick crouch-press, and the gun comes right back.
- **Deploy:** the beacon snaps open and **crackles with yellow electricity**, and the zone ring spreads out.

## Screen (for a stimmed player)
- An **electric-yellow screen-edge pulse**: subtle, pulsing gently while stimmed.
- **Placeholder HUD:** a simple "Stimmed" label + countdown (the HUD gets reworked later).

## Look (Blender + VFX)
- **Beacon:** a rugged tactical unit that pops open with a small light mast, **crackling electric yellow**, made in Blender in the current tactical style.
- **Zone:** an electric-yellow ring/dome on the ground with small arcs and sparks along the edge.
- **Stimmed players:** yellow electric crackle over their body, so **enemies can see who's stimmed** (and the zone too).

## Sound (hooks + placeholder sounds)
| Hook | What |
|---|---|
| `Stim_Grab` | Beacon off the belt |
| `Stim_Drop` | Slam on the ground |
| `Stim_Deploy` | Snap open + electric crackle (3D) |
| `Stim_ZoneLoop` | Electric hum while active (3D, ~40 studs) |
| `Stim_Gained` | You became stimmed |
| `Stim_Ending` | Your stim is about to run out / ends |

## Mobile (provisional)
Tap the Stim button to drop it.

## Counter-play
Enemies can see the zone and who's stimmed, so back off or fight outside the zone. The stim only lasts 4 s after leaving it, and it's one per round.

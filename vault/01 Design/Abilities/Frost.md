# Frost (was Lag Field)

**Status:** spec locked 2026-10-29 · not built
**Inspiration:** Waylay's Saturate (Valorant): a thrown burst that **hinders** everyone it catches. Valorant's hinder slows fire rate, recoil recovery, equip time, reload speed, movement speed and jump speed. Saturate only detonates on the ground. No stun, no damage.
**Remove from the old Lag Field:** the lingering slow zone and its orb.

## How it works
| Rule | Value |
|---|---|
| Activation | **Held throw**, like the Molly. Press the key → you pull out the frost canister. **LMB = javelin-style overhand throw** (flatter and faster than the Molly), **RMB = underhand lob**. No trajectory line |
| Flight | **Reuses the Molly's flight code:** bounces off walls, the Phoenix-style drop after flying too long, **bursts on ground contact** |
| Burst | **Instant** frost burst, **~10-stud radius**. Everyone caught is **Hindered for 3 s** (it doesn't stack; a new hit refreshes the timer) |
| Who | **Everyone in the radius**: enemies, teammates and you, **same strength** |
| Damage | None |
| Charges | **1 per round, no recharge** (unlimited in test mode) |

## Hinder (a shared status effect: build it once, reuse it later)
| Stat | While hindered |
|---|---|
| Move speed | **−35%** |
| Jump | **Floaty, slow-motion jump:** lower *and* slower (lower jump speed + reduced gravity on that character), so you hang in the air a little. Starting values: jump height −40%, fall speed −40% |
| Fire rate | **−25%** |
| Reload, equip/swap time | **−30%** (they take longer) |
| Recoil recovery | **−30%** |

- **Server-authoritative:** a status with an expiry time on the character (e.g. a `HinderedUntil` attribute). The server enforces fire rate, reload and equip times; movement and jump follow whatever movement authority the game uses.
- **NPCs/dummies must obey it too** (their move speed and jump), so it's visible in testing. The old slow didn't show on the dummies because they walk at a fixed speed.
- All numbers live in config (`Config/StatusEffects` or similar), so future abilities and upgrades can apply Hinder.

## Screen (for the hindered player: nothing crazy)
- **Frosty tinted screen edges** (soft icy vignette) for the duration, fading out at the end.
- **Placeholder HUD:** a simple "Hindered" label with a 3 s countdown. The HUD gets reworked later.

## First person (thrower)
- **Canister out with frost mist:** the hand brings up the frost canister, with cold vapour coming off it while held.
- **Javelin overhand throw on LMB:** the arm draws back level with the shoulder and spears it forward.
- **Underhand lob on RMB:** same as the Molly's.

## Look (Blender)
- **Frost canister** model (tactical, matte, PBR, with a cold-blue accent), modelled in Blender.
- **Burst:** an icy mist explosion, frost spreading on the ground (a frost decal that fades after a few seconds), ice shards/glints.
- **Hindered players:** frost crystals and cold mist on their body for 3 s, so **everyone can see who's hindered**.
- **In flight:** the canister spins with a thin cold vapour trail.

## Sound (hooks + placeholder sounds)
| Hook | What |
|---|---|
| `Frost_Equip` | Canister out + hiss |
| `Frost_Throw` | Throw whoosh |
| `Frost_Flight` | Hiss in flight (3D) |
| `Frost_Bounce` | Clink off walls (3D) |
| `Frost_Burst` | Icy burst (3D, ~50 studs) |
| `Frost_HinderedLoop` | Cold/sluggish loop for the hindered player |
| `Frost_Recover` | Thaw when the hinder ends |

## Mobile
Same as the Molly: tap to hold, **Fire** throws, a **Lob** button appears, tap again to cancel.

## Counter-play
Watch for the canister and the clink, and stay off the ground near it: it only bursts on landing. Hindered players can still fight, just slower, so back off for 3 s.

# Frost (was Lag Field)

**Status:** spec locked 2026-10-29 · built 2026-10-29 (approved by the user)
**Inspiration:** Waylay's Saturate (Valorant): a thrown burst that **hinders** everyone it catches. Valorant's hinder slows fire rate, recoil recovery, equip time, reload speed, movement speed and jump speed. Saturate only detonates on the ground. No stun, no damage.
**Remove from the old Lag Field:** the lingering slow zone and its orb.

> **Look & sound:** follow the [Look & sound standard](00%20Abilities.md#look--sound-standard-every-ability-this-is-not-optional): Blender models, Blender-rendered effect textures, real hand animations, placeholder sounds in every hook.

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

### Placeholder sounds (in `Config/ModSounds` → `Frost`; unauditioned, swap the id)
All ProSoundEffects library audio (public, no upload). Search terms that worked: `"Air Release"`, `"Fire Extinguisher"`, `"Ice Freeze"`, `"Ice Crackle"`, `"Whoosh Heavy"`, `"Swish"`, `"Aerosol"`, `"Canister"`, `"Barstow Wind"`.
| Hook | Id | Name (start / cut) | Volume / pitch | Alternatives |
|---|---|---|---|---|
| `Frost_Equip` | 9113074345 | Air Release Valve Scuba Tank 1 (from 0.15, 0.9 s) | 0.35 / 1.05 | 9113046623, 9119521227 |
| `Frost_Throw` (javelin) | 9120728883 | Whoosh Heavy Punches 2 (from 0.08, 0.45 s) | 0.5 / 0.95 | 9125496394, 9120728815 |
| `Frost_Throw` (underhand) | 9125495498 | Dowel Swish Bamboo Thick 5 (0.3 s) | 0.35 / 0.9 | 9125495638 |
| `Frost_Flight` | 9119525650 | Spray Paint Aerosol Air Hiss Constant 2 (loops 8.4–13.2 s, 35 studs) | 1.5 / 1.1 | 9116495722, 9119525460 |
| `Frost_Bounce` | 9113704875 | Canister Drop Canister Impact 3 (from 0.08, 0.5 s) | 0.6 / 1.1 | 9113703083, 9113703735 |
| `Frost_Burst` | 9114437277 + 9125611419 | Fire Extinguisher 2 + Ice Freeze Large Piece Crackles Liquid Nitrogen 3 (from 0.2), 50 studs | 0.9 / 0.9 + 0.6 | 9114437231; 9114855870 |
| `Frost_HinderedLoop` | 9113286782 | Barstow Wind Light Blustery Low Howl 1 (loops 1.8–6.6 s) | 1.0 / 0.95 | 9113287001, 9126166227 |
| `Frost_Recover` | 9114858583 | Ice Crackle Large Block Cracks 1 (from 0.1, 0.65 s) | 0.5 / 1.05 | 9125976406, 9125610574 |

## Build notes (2026-10-29)
- **Removed:** the Lag Field (its orb, slow zone, `ModSpeedMult`, SLOWED tags and warning, zones in ModEntities, arc preview entry). `ReplicatedStorage.Abilities.LagField` (Studio) is now unused.
- **Shared status effects (new):** `Config/StatusEffects` (Hinder as data; Stim adds Stimmed), `Mods/Status` (multipliers, both sides), `Services/StatusService` (the only writer of `HinderedUntil`; publishes `StatusMoveMult` / `StatusJumpMult` / `StatusGravityMult` for the movement simulation). The simulation scales walk speed, sets `JumpHeight = 7.2 × jump × gravity` and gives part of gravity back in the air (a floaty jump); Updraft launches under the lowered gravity so its peak stays 14. Weapons: fire rate, alt-fire cooldowns, knife swings, reloads (incl. shell-by-shell), equip/swap and recoil recovery are scaled on both sides; the server uses the most lenient multiplier for 0.3 s around a status starting or ending (`StatusEffects.GRACE`), so a shot fired before the client saw it isn't rejected. Test-range dummies obey it (speed, jump, fall).
- **Rules:** `Mods/Frost` reuses the Molly's flight (`Molly.options`): LMB javelin (`throwSpeed` 92, flat), RMB lob 24, walls bounce it, bursts on the first floor, drops after 0.9 s; still flying after 4 s = no burst. Everyone within 10 studs with a clear line from the burst (you and your team too) is Hindered 3 s (a refresh). Measured in Studio: hindered walk speed 9.9 (× 0.65), JumpHeight 2.59; the enemy dummy and I were both hindered.
- **Model:** Blender `tools/blender/build_mod_frost.py` (white-grey caged canister, cold-blue band and windows, 0.56 studs, 2.45K tris; `Fuse_Energy` team-tinted, `Vents` stay cold blue), uploaded (asset 110961912148634), built into **`ReplicatedStorage.Abilities.Frost`** (backup `art-source/abilities/Studio/Frost.rbxm`). Preview `02 Art/References/abilities/frost/frost_model.jpg`.
- **Effects:** `Util/FrostFx` from Blender-rendered textures (`tools/vfx/make_frost_vfx.py`, ids in `Config/VfxTextures FROST_*`, preview `frost_vfx_preview.png`): burst mist, icy flash, flying shards, a light pop, frost on the floor fading after 3.5 s; frost crystals and sinking cold mist on anyone hindered (players and dummies); for you: the frosted screen-edge vignette, the cold loop, the thaw. The canister trails cold vapour in flight.
- **HUD (placeholder):** "HINDERED 2.4" countdown above the Mod bar.
- **First person:** the javelin throw (`Config/Viewmodel ITEM_ACTIONS.Javelin`), the Molly's underhand lob.
- **Icon:** still the Lag Field's.

## Mobile
Same as the Molly: tap to hold, **Fire** throws, a **Lob** button appears, tap again to cancel.

## Counter-play
Watch for the canister and the clink, and stay off the ground near it: it only bursts on landing. Hindered players can still fight, just slower, so back off for 3 s.

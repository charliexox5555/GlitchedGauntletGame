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


## Changes from the user's feedback (2026-10-29)
- **Longer throws** (same change as the Molly): `throwSpeed` 92 → **108**, `dropTime` 0.9 → **1.3**. Longest javelin throw on flat ground: **74 → 115 studs**.

## Upgrades (L2/L3) (built 2026-11-03, not playtested yet)
Decided in [Upgrade Paths](Upgrade%20Paths.md) → 5. Frost (that note owns the numbers). Code: `Config/Mods` Frost `levels`, `Mods/Frost` (`behaviour = "Freeze"`), client `Util/UpgradeFx/Frost` (look) and `Util/Frozen` (the rules of being frozen on the client).

| Level | What it does | Card text (`note`) |
|---|---|---|
| **A2 Stockpile** | 2 charges a round (no recharge) | Stockpile: 2 canisters a round |
| **A3 Stockpile** | 3 charges | Stockpile: 3 canisters a round |
| **B2 Big Burst** | 14-stud radius | Big Burst: 14-stud burst, double the area |
| **B3 Big Burst** | 17-stud radius | Big Burst: 17-stud burst, triple the area |
| **G2 Freeze Frame** ⚡ | Everyone in the burst with a clear line (enemies, team, you) is **Frozen 1.5 s** instead of Hindered | Freeze Frame: frozen solid 1.5 s, can't move or shoot. Hits you too |
| **G3 Freeze Frame** ⚡ | Frozen **2.5 s** | Freeze Frame: frozen solid for 2.5 s |

**A and B** are numbers only: the burst effect (`Util/FrostFx`) already scales its mist and floor frost to the radius, and the HUD has 3 charge pips.

### Frozen (`Config/StatusEffects` Frozen, a stun)
- **Server:** move 0, jump 0 (you still fall); no shots (`WeaponService`, after the 0.3 s grace), no reload can start, and a **reload in progress is dropped** when it lands (shell-by-shell keeps the shells loaded; `StatusService.onApply`); no Mods (`ModService` denies "frozen"); no predicted casts (Dash, Updraft: `StatusStunned`). A new freeze refreshes the timer.
- **Your client (`Util/Frozen`):** a held Mod is put away, a reload and an inspect are cancelled, and the view turns at most **25°/s** (`StatusEffects` Frozen `turn`, `CameraController.setTurnCap`), so your body barely turns: you creak round, no flicks.
- **Every client:** frozen bodies' animations pause mid-pose (Animator tracks at speed 0 before each animation step, restored on thaw).
- **Dummies:** stand still, legs paused, shooters don't turn or fire.

### Look and sound (glitched: a paused video frame)
- **Burst:** a snap-freeze shockwave instead of the frost puff. The ring (team colour) races out in 0.1 s and **stops dead** at the edge, held 0.45 s with magenta and cyan ghost copies jittering beside it (a stuck frame), a magenta hex grid flashes on the floor, ice spikes (some corrupted magenta slivers) burst out of the floor around the edge, a "❚❚" pause mark flickers over it, then it pops. A neon core flash, sparkles, floor frost. Sound: a tape brake (the frame stopping), the ice crackle pitched down, video static.
- **Frozen bodies:** a jagged glass ice block around the body, crystals jutting out (one in four a magenta neon sliver), magenta scanlines crawling over it, datamosh jumps (it skips sideways and flashes magenta for a frame), and a "❚❚ 1.4" tag above it: **cyan for your team, orange-red for enemies**. No outline through walls (the tag is hidden by walls too). When it thaws (or the body dies) it **shatters**: glass chunks, sparkles, a glass-break sound.
- **You while frozen:** the frosted vignette, a desaturated cold colour grade, VHS scanlines, tearing bars, a big "❚❚ FROZEN" with a chromatic split and the countdown, "❚❚ PAUSE" in the corner, a static sting. At the end it shatters off: a flash, glass break, the thaw crack.
- **Placeholder sounds** (`Config/ModSounds` Frost, ids from [Mod Audio](../../02%20Art/Mod%20Audio.md)'s checked list, unauditioned): `freezeSnap` 9117880715 "Power Rewind Brake Engage 1", `freezeStatic` 9120425687 "Video Static Distortion Short Bursts Rizzy 2", `shatter` 9114592117 "Glass Breaks 1", `frozenStatic` 9126160991 "Video Static Distortion Short And Long Bursts 2".

### Look (stylized, 2026-11-03)
The user found some ability effects too realistic for low-end devices, so the ice moved to the stylized, mesh-first look ([Art Direction](../../02%20Art/Art%20Direction.md) → "Ability VFX"). Kit: **IceVFX** (Blender `tools/blender/build_mod_icevfx.py` → `art-source/abilities/IceVFX/`, render `02 Art/References/mods/icevfx.jpg`, asset 99804256205553): 3 crystal shards, a crystal cluster, 2 wall slabs, the body Shell, 3 chips, the snap-freeze Ring, a frost patch with Cracks, magenta Pixels and Scanlines; flat-shaded, untextured, ≤ 430 tris each (1,860 in all). `Util/IceKit` pools and places them; colour, material and transparency are set in code.
- **Burst (L1, A, B):** a crisp ice-white crystal ring snaps out to the radius, a faceted frost patch with glowing cracks under it, a crystal cluster bursts up at the centre and 6–12 crystal spikes snap out around it, then they sink back into the floor; the patch lingers 3.5 s. Only a 4-particle mist puff, 12 sparkles and the flash ball.
- **Hindered bodies:** 3 crystals and a small frost patch at the feet (instead of the crystal particles; mist down to rate 2); they break off in 3 chips when it ends.
- **Freeze Frame (G):** the ring and its magenta / cyan ghosts are the crystal ring mesh; the spikes are faceted crystals (one in four a flickering magenta sliver); the floor frost is the faceted patch with **magenta cracks** flickering in it. A frozen body stands in the **faceted Shell** (see-through, sized to the body) with two magenta crystal slivers, two **magenta slices** sweeping down through it and **pixel cubes** on its datamosh jumps; it shatters into 7 faceted chips (code-animated, no physics).
- **Fallback:** without `ReplicatedStorage.Abilities.IceVFX`, the older look (texture particles, decal rings, glass block).

### Name ideas (proposals, not applied)
- A "Stockpile" → **Cold Storage** (more canisters, a fridge pun).
- B "Big Burst" → **Cold Front** (weather that covers a wide area) or **Blizzard**.
- G "Freeze Frame" → keep it: it says exactly what happens and sells the paused-video look.

### Known gaps
- A Dash already in progress finishes (about 0.2 s), and a Recall wind-up that started before the freeze still teleports.
- A Mod key pressed while frozen raises the item, then the server's "frozen" deny puts it away (with the deny buzz).
- The thrown canister looks the same on every level.

## Mobile
Same as the Molly: tap to hold, **Fire** throws, a **Lob** button appears, tap again to cancel.

## Counter-play
Watch for the canister and the clink, and stay off the ground near it: it only bursts on landing. Hindered players can still fight, just slower, so back off for 3 s.

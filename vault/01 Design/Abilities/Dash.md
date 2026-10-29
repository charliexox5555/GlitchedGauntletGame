# Dash (was Blink)

**Status:** spec locked 2026-10-28 · built 2026-10-29 (tested by the user in Studio)
**Inspiration:** Jett's dash (Valorant). A physical, instant dash.
**What to change from the current Blink:** the *feel* is already good. The rework is the **name, the charge rule, gun handling, the first-person animation, the effects and the sound hooks**.

> **Look & sound:** follow the [Look & sound standard](00%20Abilities.md#look--sound-standard-every-ability-this-is-not-optional): Blender models, Blender-rendered effect textures, real hand animations, placeholder sounds in every hook.

## How it works
| Rule | Value |
|---|---|
| Activation | **Instant on press** (mobile-friendly) |
| Direction | The way you're moving (WASD / joystick); **forward** if standing still |
| Distance / speed | **Keep current:** 12 studs in 0.15 s. Retune once maps exist |
| Mid-air | **Yes**, works in the air |
| Speed after | Ends at **sprint speed** (keep current `exitSpeed` 22) |
| Walls | Stops at walls (keep current) |
| Charges | **1 per round, no recharge, no cooldown** (unlimited in test mode) |

## Gun
- The gun is **lowered/put away during the dash**, then comes back up.
- After the dash there's a **short delay before you can shoot** (start at ~0.1 s after the dash ends; config). The server enforces it too.
- **Dash Focus:** your **first shot within 0.6 s** after the gun is back up has **no movement or air spread penalty** (config; applied in the spread logic and checked on the server).

## First person (the main thing missing: it should feel like you're really *going* somewhere)
- The gun dips down and out of view; the **free hand does a fast directional gesture**:
  - forward = palm pushes forward
  - left/right = sweeps to that side
  - backward = pulls back

  Then the gun snaps back up.
- **Camera:** FOV punch (~+10–12, eased back over ~0.25 s), a slight roll toward strafe dashes, a small forward lunge on start, a tiny settle at the end.
- **Screen:** wind/speed streaks at the screen edges in the dash direction, plus a subtle radial blur while dashing. Short and clean.

## What others see
- A quick **wind trail/streak** along the path (team-tinted: your team vs enemies), a small **air burst** at the start and a light **puff** at the end.
- The character **leans** into the dash direction.

## Sound (hooks + placeholder sounds: the user does the final sound design)
| Hook | What |
|---|---|
| `Dash_Whoosh` | The main air whoosh (first person) |
| `Dash_Crackle` | A light crackle layer, with an **on/off toggle** (try it; turn it off if it doesn't fit the classic theme) |
| `Dash_Land` | A soft settle at the end |
| `Dash_World` | The 3D sound others hear, audible ~40 studs, louder up close |

### Placeholder sounds (in `Config/ModSounds` → `Dash`; unauditioned, swap the id)
All ProSoundEffects library audio (public, no upload). Search terms used: `whoosh fast airy`, `wind whoosh short`, `crackle flutter`, `cloth movement`, `footstep scuff`, `wind gust`.
| Hook | Id | Name | Volume / pitch | Alternatives |
|---|---|---|---|---|
| `Dash_Whoosh` | 9126229267 | Whoosh By Fast Airy Swooshing Whipping Thuds 1 (0.6 s) | 0.6 / 1.05 | 9120704940, 9126228975 |
| `Dash_Crackle` | 9114157098 | Doppler Whooshes Crackly Airy Bursts 2 (cut at 0.6 s) | 0.25 / 1.15 | 9120714365, 9125616655 |
| `Dash_Land` | 9113824230 | Cloth Movement 24 (cut at 0.35 s) | 0.35 / 1.1 | 9114523345, 9120880314 |
| `Dash_World` | 9114373678 | Fast Pass By Airy Whooshes Windy 4 (3D, 40 studs) | 0.8 / 1.0 | 9126229490, 9114374276 |

The crackle layer has an on/off switch: `Config/Mods` → `DASH_FEEL.crackle`.

## Build notes (2026-10-29)
- **Rules:** `Config/Mods` Dash L1 `fireDelay` 0.1, `focusWindow` 0.6. Both the client (`WeaponController`) and the server (`WeaponService`, from its own simulation's `Dashing` flag) block shots, melee and ADS while dashing and for the fire delay; the server allows `Combat.DASH_FIRE_SLACK` 0.1 s for ordering drift. Dash Focus: the server decides it itself (first accepted shot inside the window), so the client can't claim it. Measured in Studio: strafing shots 1.74°, the first shot after a dash 0.56° (gun spread only), accepted.
- **First person:** gun dip `Config/Viewmodel DASH_DIP`, hand gestures `DASH_GESTURES` (Forward / Back / Left / Right); camera numbers in `Config/Mods DASH_FEEL` (FOV +11 over 0.25 s, roll 4°, 0.35-stud lunge then settle, blur 4 for 0.18 s, edge streaks 0.3 s).
- **Others see:** `Util/DashFx`: wind Trail on the root, a gust ring (twice) and wisps at the start, a puff at the end, team-tinted. Lean clips `GG_DashForward/Back/Left/Right` (`tools/studio/MakeModAnimations.luau`, ids in `Config/Animations MODS`), played by `Simulation/Poses`.
- **Textures:** rendered in Blender by `tools/vfx/make_dash_vfx.py` → `art-source/vfx/abilities/dash/`, preview `02 Art/References/abilities/dash/dash_vfx_preview.png`, ids in `Config/VfxTextures` (`DASH_*`).

## Mobile
Tapping the Dash button dashes in the joystick direction.

## Counter-play
It's a one-use escape or engage per round. Listen for the whoosh, and punish the short shoot delay after it.

# Dash (was Blink)

**Status:** spec locked 2026-10-28 · not built
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

## Mobile
Tapping the Dash button dashes in the joystick direction.

## Counter-play
It's a one-use escape or engage per round. Listen for the whoosh, and punish the short shoot delay after it.

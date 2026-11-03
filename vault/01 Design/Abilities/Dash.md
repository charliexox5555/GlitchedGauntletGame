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

## Upgrades (L2/L3)
Decided 2026-11-03 in [Upgrade Paths](Upgrade%20Paths.md) → "1. Dash" (the numbers are the user's; don't change them here). Built 2026-11-03 on branch `claude/loving-lewin-c22dba`, **not playtested yet** (the hub runs the checklist below in Studio).

### Names and card text
Path names: **A Long Dash** (was "Distance": "Dash · Long Dash" reads as what it does), **B Ghost**, **G Desync** (kept: your client and the server "disagree" about where you are, which fits the glitch theme). Card text (`note` in `Config/Mods`):

| Level | Card text |
|---|---|
| L1 | Dash 12 studs in your move direction |
| A2 Long Dash | Dash 18 studs instead of 12, just as fast |
| A3 Long Dash | Dash 24 studs, just as fast, and 2 charges |
| B2 Ghost | Bullets pass through you for 0.35 s from the press |
| B3 Ghost | Vanish for 1 s after a dash (a shimmer up close), 2 charges |
| G2 Desync ⚡ | Leave a decoy that keeps running for 1.5 s; no shots for 0.3 s |
| G3 Desync ⚡ | The decoy fires fake shots, and you vanish while it runs |

### What each level does
- **A2 / A3 Long Dash:** numbers only. 18 / 24 studs in the same 0.15 s (120 / 160 studs/s); A3 has 2 charges. Exit speed is still capped at `exitSpeed` 22.
- **B2 Ghost:** for `dodgeWindow` 0.35 s from the press, **every hit on you is blocked** (guns and ability damage alike; the shooter gets the BLOCKED marker from `HitConfirm.blocked`). Everyone sees you half see-through (`ghostAlpha` 0.55, a fast shimmer) with team-tinted ForceField afterimages peeling off behind you; you get a pale screen wash.
- **B3 Ghost:** B2, plus **nearly invisible** from the dash until `cloakAfter` 1 s after it ends (it fades in over the dash, off over the last 0.15 s), 2 charges. Enemies further than `cloakShimmer` 10 studs see you at `cloakAlpha` 0.95 (5% visible), closer ones a flickering shimmer around `cloakShimmerAlpha` 0.75; your team sees you half see-through (`cloakAllyAlpha`). Your name tag is hidden from enemies while cloaked. A Recon reveal still shows: a revealed dasher is never more than 60% see-through, so the outline always draws. You get a cold, washed-out screen tint.
- **G2 Desync ⚡:** the dash leaves a **decoy** at the spot you pressed: a copy of your character (same avatar, gun, name tag) that keeps running the way you were already going (your facing from a standstill) at your old speed (16–22 studs/s), with your run clip and gun pose (the sprint carry above walking speed). It follows the ground, falls off ledges, stops at walls, and after `decoyTime` 1.5 s freezes mid-stride and glitches out in magenta static. Nothing hits it (no hit marker). There's no wind trail on a Desync dash, and the split point gets the same magenta static, so the trail can't tell enemies which one is you. Drawback: no shots for `fireDelay` 0.3 s after the dash.
- **G3 Desync ⚡:** G2, plus the decoy **turns to the nearest enemy in sight (150 studs) and fires fake shots** (tracers, muzzle flash, the gun's far sound, wall impacts; no damage) at your gun's fire rate (never faster than 0.12 s), from 0.2 s after the press, with 2.5° of miss. **You're nearly invisible** (as B3) for the whole 1.5 s from the press.

### Build notes
- **Simulation (`Mods/Dash.simCast`):** writes the upgrade attributes before `DashStart` (clients key on it), each cast rewriting them (nil when the level hasn't got them): `DashDodgeUntil`, `DashCloakUntil`, `DashDecoyFrom` / `DashDecoyYaw` / `DashDecoyVelocity` / `DashDecoyUntil`, `DashDecoyFires`, all on the simulation's `time()` clock.
- **Fast dashes:** a dash now lasts a whole number of simulation steps (60 Hz) at no more than full speed, covering exactly the spherecast's reach, and `DashUntil` sits half a step before the end. At 160 studs/s one step is 2.7 studs, so before this a dash cut short by a wall could hold full speed one step too long and push into it. A full-length dash is unchanged (9 steps).
- **Ghost on the server:** `Mods/Dash` `module.server` registers an `api.guard` that returns 0 while `time() < DashDodgeUntil` on the victim (the server's own simulation wrote it, so a client can't open the window itself).
- **Client:** `Util/UpgradeFx/Dash` watches every character's `DashStart`; `DashGhost` sets `LocalTransparencyModifier` on other characters' parts and decals (gun and held item included) per viewer, and puts it back to 0 after; `DashDecoy` builds the decoy (character clone with `Archivable` on for the copy, scripts / sounds / particles / highlights stripped, `AnimationConstraint` joints turned into `Motor6D`s so the anchored-root copy poses kinematically, every part `CanQuery` off). Fake shots go through `EffectsController.tracer` / `muzzleFlash` / `impact` and `GunSounds.fireFar`, the same calls a real remote shot uses. Everything lives in `workspace.DashFx` (client-only).
- **Shared-file hunk:** `ModFeelController` skips `WindFx.dashStart` / `dashEnd` on a Desync dash (the 3D whoosh still plays).
- **Open:** shooting while cloaked doesn't break the cloak (your tracers give you away anyway); decide after a playtest.

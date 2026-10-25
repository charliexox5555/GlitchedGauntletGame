# Gunplay

**Feel target:** RIVALS-style run-and-gun, plus a sliding move set borrowed from Hypershot. **Not** Valorant: you never have to stand still to shoot accurately.

**Why:** most Roblox players are on phones, and the draft plus Mods already give players a lot to learn, so shooting must be easy to pick up and satisfying. Base movement stays moderate so **drafted mobility Mods (Blink, Launch Pad) feel like real upgrades**. Background: [Design Research Report](../03%20Research/Design%20Research%20Report.md).

All numbers are **starting values**. They live in `src/shared/Config/` so they can be tuned without new code.

---

## 1. Movement
| Action | Value | Notes |
|---|---|---|
| Walk | 16 studs/s | |
| Sprint | 22 studs/s | Toggle or hold (setting). Pressing fire **cancels sprint instantly** |
| Crouch | 9 studs/s | Tighter spread |
| Jump | ~7 studs high | Standard Roblox jump. No fall damage |
| **Slide** | Sprint + crouch → 30 studs/s burst, slowing to crouch speed over 0.7 s | 0.6 s cooldown. You can shoot while sliding |
| **Slide-jump** | Jumping out of a slide keeps 80% of the speed | The "Hypershot" flavour. No other advanced tech |
| ADS move speed | ×0.75 (snipers scoped ×0.55) | |
| Heavy guns | ×0.85 (Overflow), ×0.75 (Flood) | From [Weapons](Weapons.md) |
| Not in base kit | Double jump, wall-run, dash | **Only from Mods**, so drafting mobility matters |

## 2. Shooting
- **Fire on press**, never on release.
- **Accurate while moving.** Spread is added on top of each gun's base spread:
  | State | Extra spread |
  |---|---|
  | Standing / crouching | 0 |
  | Walking | +0.4° |
  | Sprinting (first shot) | +0.6° |
  | Sliding | +0.8° |
  | In the air | +2.5° (snipers unscoped: huge) |
- **Hip fire is real** for sidearms, SMGs and shotguns. **ADS** = spread ×0.35, zoom, slower movement. It matters most for rifles and snipers.
- **Base hip spread by class:** sidearm 0.8°, SMG 1.2°, rifle 1.4°, machine gun 2.0°, shotgun pellet cone 5°, sniper unscoped 4° (scoped 0°).
- **Bloom:** +0.15° per shot up to a per-gun cap; recovers at 6°/s after you stop firing.
- **Recoil:** mostly **vertical** camera kick (rifle ≈ 0.35° per shot) with a small random sideways jitter (±0.12°). About 70% recovers automatically when you stop. **No spray patterns to memorise.**
- **Swaps and reloads:** weapon swap 0.3 s (sidearms 0.2 s); swapping cancels a reload; empty reloads take longer than tactical ones.

## 3. Damage
| Rule | Value |
|---|---|
| Health | 100 per round, **no natural regen** (heals come from Mods) |
| Headshot | **×1.5** by default |
| Legs | ×0.85 |
| One-shot headshot guns | Only **Root** (≤25 studs), **Checksum** and the snipers. It's their identity |
| Target time-to-kill | **0.35–0.6 s** for main guns. That leaves just enough time to react with a Mod |
| Falloff | Per gun (start and end distance, minimum damage) |

## 4. Aim assist (touch and gamepad only, never mouse)
- **Slowdown:** aim sensitivity drops to 60% within ~3° of an enemy.
- **Light magnetism:** gentle pull (≈15%) toward the target **only while ADS** and moving the aim.
- **No snap-to-target.** Use Roblox's official Aim Assist module as the base.
- Ranked will split pools by input type. Never give stat buffs by device (device detection can be spoofed).

## 5. Feedback ("juice")
This is a big part of why RIVALS feels good. Build it alongside the very first gun.
- **Hit marker:** white for body, **gold for headshots**. Instant on the client, confirmed by the server.
- **Sounds:** distinct body-hit tick, headshot "ding", **kill sound** (cyan X marker).
- **Damage numbers** that stack while you keep hitting the same target, then fall off in an arc (RIVALS style); gold for headshots, bigger on the kill. A short **kill banner** ("ELIMINATED", streaks count up) under the crosshair.
- **Victim:** directional hit indicator, red low-HP vignette, a short death recap showing **the killer's gun and Mods** (teaches the draft).
- Kill feed, a round-win stinger, a slow-mo kill cam on the deciding round.
- Muzzle flash, tracer (none for suppressed guns), shell ejection, impact sparks; enemies **dissolve into pixels** on death (no blood).

## 6. Camera and controls
- **First person.** FOV 80 by default (setting 70–100), with ADS FOV set per gun.
- **First-person arms (RIVALS style):** one long, smooth, softly bevelled block per arm (R6 cross-section, no elbow), coming up from off-screen into the gun's grip; the end of the block is the hand. Skin colour from the avatar; a classic Shirt is drawn on the block the way Roblox draws it on R6 arms. References: `02 Art/References/rivals-viewmodel/`.
- **How the viewmodel works** (`ViewmodelController`, motion in `Util/ViewmodelMotion`, numbers and keyframes in `Config/Viewmodel`). Rebuilt 2026-10-25 (pass 4) the standard way (EgoMoose, "Writing an FPS framework"): **one rigid rig**, computed in this order every render frame right after the camera, then everything moved at the end of the same step:
  - **Root** = camera × motion. Bob, breathing, sway, strafe tilt, fall lift and landing dip all add up to this one offset, so the gun and both arms move as a single unit.
  - **Gun** = root × hold pose: hip↔ADS, the movement poses (Sprint, Slide, Crouch, Air), the keyframed tracks (Equip, Inspect, InspectMelee, Reload body motion) and the recoil kick.
  - **Hands and arms** = gun × hand. Each hand has an offset from its grip attachment and an arm direction, both in gun space (`RIFLE_RIGHT_HAND`, `RIFLE_LEFT_HAND`, `PISTOL_RIGHT_HAND`, `PISTOL_LEFT_HAND`, `MELEE_HAND`), so a hand can never drift off the gun. During the gun's Blender clips the hand blends (in gun space) to the part it works: the first moving one of `Mag`, `Cylinder`, `Barrels`, `Pump` or `Bolt` on Reload, the pump or bolt on Fire. Melee's free hand is a guard on the root (`FREE_HAND`).
  - **No per-part jitter: each gun and the arms live in their own `WorldModel` under the Camera.** Under Server Authority the Workspace snaps part positions to a coarse grid (measured: up to 0.006 studs, and the step changes with where you stand, from 1/4096 to 1/128 stud), so every viewmodel part jittered on its own, which was the "parts don't move together" look. Parts in a WorldModel keep exact positions and still render. They keep the names `Viewmodel` / `ViewmodelLeft` / `ViewmodelArms`, so EffectsController finds the muzzle as before. Raycasts against the viewmodel use the WorldModel's own `:Raycast`.
- **Placement** (RIVALS references `rivals-viewmodel/6-rifle-hip-straight.webp`, `7-pistol-hip.webp`): every gun points **straight down the view** (no cant; perspective alone makes it converge on the crosshair).
  - Long guns: scale 0.75. Each is placed by its **sight height at its grip's depth** (`RIFLE_VM` 0.31, -0.3, -0.65): every rifle's top edge lands on the same line, and a sight mounted far forward or back on the model (Loopback, Burst Buffer) no longer pushes the gun into or away from the camera. The right hand is off-screen; the support arm rises from the bottom, leaning left, to under the handguard. Rifles with a long scope (Long Poll, Handshake, Kernel, Checksum) use `SCOPED_VM` (same screen spot, further away) so the eyepiece doesn't fill the corner.
  - Sidearms (by `class`), melee and Dual Boot are placed by their **grip**. Pistols are scale 1.1 (Splinter 1.35, it's stubby) and two-handed. The right hand has a high grip, its block covering the lower back of the slide like RIVALS; the left hand cups from below-left.
  - Dual Boot: a mirrored pistol in each hand (scale 0.9). Cutter: placed by its grip, blade up, the hand wrapping the handle.
  - All 23 at the hip: `rivals-viewmodel/viewmodel-all-23-hip.jpg`. Checked by script for every primary: nothing on-screen nearer than 0.35 studs (no near-plane clipping) and nothing within 6% of the screen centre (the crosshair is never covered).
  - Per-gun `viewmodelOffset` / `viewmodelRotation` / `viewmodelScale` in `Config/Weapons`.
- **Motion** (all frame-rate independent). Every spring is critically damped and stepped with its exact solution. Bob speed and size ease, never jump.
  - **Walk bob:** a figure-8 (sideways once per loop, a dip on each step), 1 loop/s, sized by smoothed ground speed and zero in the air or sliding.
  - **Sprint:** a slower, wider loop (0.85 loop/s) plus a tilted carry pose.
  - **Idle:** slow breathing (0.25 Hz), faded out while moving.
  - **Sway:** turning *kicks a spring by how far the view turned*, not by a per-frame turn rate (that jitters with mouse polling and high fps). It rotates and shifts the rig, soft-limited.
  - **Poses:** blend weights ease their goal before the spring, so a pose starts without an acceleration kick.
  - **While aiming:** everything stays at `ADS_*_SCALE`, so the sights drift as you move. Aimed motion turns around the sight line (`ADS_MOTION_PIVOT`), so the front post stays near the crosshair.
  - **Strafe sway:** the gun lags behind sideways movement and its top leans back against it, easing back when you stop. Aimed it's gentler (`ADS_STRAFE_ROLL` / `ADS_STRAFE_SHIFT`). Measured aimed strafe on Bitrate at 12 studs/s: the sight drifts at most 1.2° from the crosshair, with 2° of lean; it settles within ~0.5 s of stopping; frame-to-frame jitter 0.004°.
  - **Aimed recoil:** a separate stiff, critically damped kick (`ADS_KICK_BACK` 0.035 studs back, `ADS_KICK_ROTATE` almost no climb, `ADS_RECOIL_STIFFNESS` 700), plus only 20% (`ADS_CLIP_KICK`) of the gun's Fire-clip Root motion. The action, mag and hands still animate. Measured, a 1 s Bitrate burst aimed: the sight rises at most 0.3° relative to the camera, kicks back 0.02 studs per shot and settles between shots. The camera kick (`CameraController`) carries the recoil feel.
- **Measured** (Studio, 60 fps, Bitrate, the rig's offset from the camera every frame; chart: `rivals-viewmodel/viewmodel-motion-before-after.png`):

  | | before (pass 3) | now |
  |---|---|---|
  | Walk: acceleration mean / max (studs/s²) | 63 / 116 | 1.4 / 2.3 |
  | Sprint: acceleration mean / max | 232 / 400 | 2.5 / 4.2 (4.2 entering sprint) |
  | Idle: acceleration max | 13 | 0.02 |
  | Frame-to-frame jitter (distance from neighbours' midpoint), walk max | 0.016 studs | 0.0004 studs |
  | Arm vs gun drift while walking / sprinting | 0.013 / 0.016 studs | < 0.00001 studs |

  The old bob ran at about 8–9 Hz vertically (that was the shake). Stepping the motion at 60 vs 240 Hz on the same 6 s input (walk, turn, flick, sprint) gives the same result within 0.0026 studs / 0.19°. Studio's frame cap can't be raised from a script, so 240 fps was checked that way rather than live.
- **Inspect:** **F** (Valorant uses Y; Y is the Studio dev picker). About 2.8 s: show the right side, flip to the left side, return. Fire, aim, reload and swapping cancel it. Note: the controls table plans F for Mod 3, so one of them moves when Mods are built.
- **ADS** (reference `rivals-viewmodel/4-ads.webp`): zoomed and close. The eye sits `adsDistance` behind the rear sight (0.7, pistols 1.0; tried 0.9 for rifles to thin the rear ring, but further back the ring reads as a solid blob with a pinhole, so it stays 0.7), so the rear aperture is big and centred with the front post inside it and the gun body fills the bottom centre; ADS FOV is about 10° tighter than before on every non-scoped gun. Smootherstep blend. Nothing is hidden unless a raycast from the eye finds it on the sight line (plus a gun's explicit `adsHide`). `adsOffset`: Root aims lower so the eye clears its hammer. `adsReticle`: Ray Trace, Loopback and Null get a holo pane (now big and close), Checksum and Mute a reticle in place of their opaque lenses. Long Poll, Handshake and Kernel keep the scope overlay; Dual Boot has no ADS.

| Action | PC | Gamepad | Mobile |
|---|---|---|---|
| Fire | LMB | RT | Fire button (+ optional left fire) |
| ADS | RMB (hold or toggle) | LT | ADS button |
| Reload | R | X | Reload button |
| Jump | Space | A | Jump button |
| Sprint | Shift | L3 | Auto-sprint when the stick is pushed fully forward |
| Crouch / Slide | C or Ctrl | B | Slide button (appears while sprinting) |
| Mods 1/2/3 | Q / E / F | LB / RB / D-pad up | 3 Mod buttons in an arc |
| Primary / secondary / melee | 1 / 2 / 3, scroll | Y cycles | Weapon tabs |
| Melee quick-swing | V | R3 | Melee button |
| Inspect | F (clashes with Mod 3, see above) | D-pad down | — |

All mobile buttons can be moved and resized in settings.

---

## Build order
1. ✅ Movement (walk, sprint, crouch, slide, slide-jump), using the Input Action System.
2. ✅ Byte: fire, server validation, damage + head/legs, hit marker + sounds.
3. ✅ Spread and bloom + recoil + ADS.
4. ✅ Bitrate (auto) → Hard Reset (pellets) → Long Poll (scope) → the rest of wave 1 (Root, Bandwidth, Flood spin-up + ThinWall, Ray Trace charge, Cutter).
5. ⬜ Aim assist on touch and gamepad. Test on a real phone.

Status 2026-10-25: steps 1–4 work against dummies in Studio; all numbers are first guesses in `Config/` and need a 2-player feel pass. Not built yet: tactical/empty reload difference beyond timing, hit indicator for the victim beyond direction, kill cam, death recap, mobile layout tuning.

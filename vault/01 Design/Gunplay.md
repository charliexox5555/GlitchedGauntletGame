# Gunplay

**Feel target (v2, 2026-10-25):** **precise** run-and-gun. Valorant-tight aim (first-shot accuracy, tap/burst control, learnable recoil, a big headshot reward) with RIVALS' freedom to move and shoot, plus a sliding move set borrowed from Hypershot. You never *have* to stand still; standing still just makes a tap laser-accurate.

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

## 2. Shooting: v2, precise run-and-gun (decided 2026-10-25)
**Goal:** Valorant's precision (a standing tap goes where you aim, spread and recoil you can learn and control, a big headshot reward) **without** Valorant's movement tax: moving costs a little accuracy, never a coin flip, like RIVALS. Research and per-gun Valorant numbers: [Valorant Gun Mechanics](../03%20Research/Valorant%20Gun%20Mechanics.md). The user picked all four options below.

- **Fire on press.** What you see is where you hit: no hidden bullet offset beyond the spread cone.
- **First-shot spread** (standing, hip): rifle 0.25°, DMR 0.1°, SMG 0.45°, pistol 0.3°, revolver 0.25°, machine gun 0.8°, shotgun cone 3–4°, sniper unscoped 3° (scoped 0°). **ADS ×0.6** (rifle 0.15°). **Crouch ×0.85.**
- **Spread shape:** standing → biased towards the centre (most shots near the crosshair); moving → uniform inside the cone.
- **Spread growth (tap/burst control):** the first few "protected" shots add almost nothing (rifle: 3 shots, +0.02° each), then +0.12° per shot up to the gun's max (rifle 1.0°, SMG 1.4°, pistol 1.6°). Spread returns fully to first-shot accuracy after **`recoveryTime`** without firing (rifle 0.375 s); re-firing sooner keeps part of the spread.
- **Movement penalty: light, about 1/4 of Valorant** (chosen). Added on top of spread, and it **scales smoothly with horizontal speed**, not with a binary state. **Deadzone:** under 30% of walk speed counts as standing (a counter-strafe helps but isn't required). **ADS halves** the movement penalty, so ADS-strafing is a real tactic. Landing adds +1.5° for 0.2 s.

  | Class | Crouch-walk | Walk | Sprint-fire | Slide | Air |
  |---|---|---|---|---|---|
  | Rifle | +0.2° | +0.8° | +1.5° | +1.2° | +3° |
  | SMG | +0.1° | +0.3° | +0.7° | +0.5° | +2° |
  | Pistol | +0.1° | +0.35° | +0.8° | +0.6° | +2° |
  | Shotgun | 0 | +0.2° | +0.4° | +0.3° | +1° |
  | Machine gun | +0.3° | +1.0° | +2.0° | +1.5° | +3.5° |
  | Sniper (scoped) | +1° | +2.5° | +5° | +4° | +8° |

  Valorant's rifles, for comparison: walk +3°, run +6°, air +10°.
- **Recoil: camera kick with a learnable pattern** (chosen). The view climbs and you pull down against it, so the crosshair is always where you shoot. Each gun's pattern: `up` degrees per shot for `protected` shots (pure vertical), then a smaller climb plus a sideways drift `side` in one direction, with a `switchChance` per shot to swap direction (at least `switchMinTime` apart). When you stop, `recover` of the climb returns over `recoverTime`. Crouch: sideways ×0.85. The viewmodel kick stays separate (already built).
- **Sprint:** pressing fire cancels sprint instantly (kept).
- **ADS:** rifles 1.25× zoom, move ×0.76, `adsTime` about 0.2 s.
- **Equip:** the **first draw** each life plays the full draw with cocking (rifle ~0.9 s, pistol ~0.6 s); later swaps are quick (rifle ~0.5 s, pistol ~0.35 s).
- **Reload:** a tactical reload swaps the mag; an **empty** reload also racks the charging handle and takes longer (rifle 2.3 s / 2.8 s).

### How v2 is built (2026-10-25)
- **Data:** per gun `spread` (`first`, `adsMultiplier`, `protected`, `protectedGrowth`, `growth`, `max`, `recoveryTime`), `recoil` (`up`, `protected`, `upAfter`, `side`, `switchChance`, `switchMinTime`, `recover`, `recoverTime`) and step `falloff` (`{ from, multiplier }`) in `Config/Weapons`; the per-class movement table and shared rules (`MOVE_DEADZONE`, `ADS_MOVE_PENALTY`, `CROUCH_SPREAD`, `CROUCH_SIDE_RECOIL`, `LANDING_*`, `CENTRE_BIAS`, `SPRAY_HOLD`) in `Config/Combat`; head ×2.25 / legs ×0.85 defaults in `Config/Weapons`.
- **Maths** (`Util/Accuracy`, shared by client and server): spray **heat** is +1 per shot; it doesn't cool while you keep firing at the gun's rate (gaps up to 1.25 fire intervals), then cools linearly to 0 at `recoveryTime`. Cone = min(first + growth(heat), max) × ADS × crouch, plus the movement penalty (speed-scaled, deadzone, slide/air values, landing), halved fully aimed. Standing shots (no movement penalty) are centre-biased (`radius = cone × u`), moving ones even over the disc.
- **Server-authoritative:** the server samples each player's own simulation every Heartbeat (MoveState, horizontal speed, landings, and the same ADS blend the client runs, driven by the server's Aim input over the gun's `adsTime`) and tracks each gun's heat as a band (each gap ±`FIRE_JITTER`). For a shot it reads the samples from the shooter's ping + `FIRE_TIME_SLACK` (0.08 s) ago up to now, builds the band of cones that allows, and clamps the client's claimed cone into it before recomputing the rays from its own seed. The high edge also allows a jump the server hasn't simulated yet (a higher cone only costs the shooter). Centre bias is used only if the client asks for it **and** the server's sample nearest the fire time was standing. A client that claims a tighter cone gets rays its hits don't match, so they're rejected. In Studio the claim and band go to the player attribute `FireSpread`.
- **Known limit (security review 2026-10-25):** the spread seeds are handed out in advance (so the client can predict hits instantly), so a cheat could pre-compensate its aim for the known spread offset. That's aimbot-class cheating anyway; fixing it means revealing seeds per shot after acceptance (later, with anti-cheat).
- **Recoil** is camera-only (client): `CameraController.kick` now waits for the spray to stop, then returns `recover` of the climb within `recoverTime`.
- **Measured in Studio (Vandal, 2026-10-25,** server log of claim and band; no shot rejected):

  | Case | Cone | Server band (low edge) |
  |---|---|---|
  | Standing tap (hip) | 0.25° | 0.25° |
  | Walking (hip, 15.2 studs/s) | 0.99° | 0.99° |
  | ADS-strafing (11.6 studs/s) | 0.39° | 0.39° |
  | 10-round spray, standing | 0.25 → 0.27, 0.29, 0.31 (protected), then +0.12/shot → **1.0° cap at shot 10** | 0.25 → 0.39 (one shot of heat slack, jitter-cooled) |
  | 0.35 s after the spray | 0.28° (heat ~1.2) | 0.25° |
  | 1.1 s after the spray | 0.25° (fully recovered) | 0.25° |

  High edges sit about 3° above (the unseen-jump allowance). Measured on the final version, Studio solo (near-zero ping).

  Not measured live: air and landing shots (jumping can't be driven from a script under Server Authority); they use the same code path with the Air row.

## 3. Damage (v2)
| Rule | Value |
|---|---|
| Health | 100 per round, no armour, **no natural regen** (heals come from Mods) |
| Headshot | **×2.25 by default, so rifles kill with 2 headshots** (chosen) |
| Legs | ×0.85 |
| One-tap headshot guns | Only snipers, the revolver and a DMR. It's their identity |
| Target time-to-kill | Body **0.3–0.5 s** for main guns |
| Falloff | **Steps** per gun (a multiplier per range band, in studs); some guns (Vandal-type) have none |
| Tagging | **None**: getting hit does not slow you (chosen) |
| Wall penetration | Low / Medium / High tiers per gun (later; ThinWall today) |

### Vandal v2 (gun 1)
| Stat | Value | Valorant Vandal |
|---|---|---|
| Fire | Auto, 0.103 s (9.75/s) | 9.75/s |
| Mag / reload | 25 / 2.3 s tactical, 2.8 s empty (with rack) | 25 / 2.5 s |
| Equip | 0.9 s first draw (cock), 0.5 s quick | 1.0 s |
| Damage | 30 body / 67 head / 25 legs, **no falloff**: 4 body shots (0.31 s) or 2 heads (0.10 s) | 40 / 160 / 34 |
| Spread | 0.25° hip, 0.15° ADS → max 1.0°; 3 protected shots, +0.12°/shot after; recovery 0.375 s | 0.25° / 0.157° → 1° |
| Movement | Rifle row above | walk +3°, run +6°, air +10° |
| Recoil | `up` 0.42° × 6 protected shots, then 0.25° up + 0.3° side drift, `switchChance` 10% (≥ 0.6 s apart), 75% recovers over 0.3 s | vertical first, then yaw switching (6 protected, 10%) |
| Speed | ×0.95 carrying, ×0.76 ADS | 5.4 m/s, ADS 76% |

### Phantom v2 (gun 2)
The user asked for: lighter than the Vandal, less damage, faster fire rate, less damage from afar, a larger mag. It's suppressed (concept: a long cylindrical integrated suppressor).
| Stat | Value | Valorant Phantom |
|---|---|---|
| Fire | Auto, 0.091 s (11/s) | 11/s |
| Mag / reload | **30** / 2.3 s tactical, 2.8 s empty | 30 / 2.5 s |
| Equip | 0.8 s first draw, 0.45 s quick | 1.0 s |
| Damage | 26 body / 58 head / 22 legs up to 70 studs, then ×0.87 (23 / 51 / 19): 4 body shots (0.27 s) or 2 heads at any range | 39 / 156 → ×0.897 after 20 m |
| Spread | 0.2° hip, 0.12° ADS → max 0.9°; 4 protected shots, +0.1°/shot; recovery 0.35 s | 0.2° / 0.11° → 0.9° |
| Recoil | `up` 0.32° × 6, then 0.2° up + 0.22° side, `switchChance` 10%, 75% recovers over 0.28 s (steadier than the Vandal) | steadier than the Vandal |
| Speed | **×0.97** carrying (lighter), ×0.76 ADS | same as the Vandal |
| Suppressed | No tracer for enemies (a faint one for the shooter), quieter shot, smaller flash | no tracers for enemies, quiet beyond 40 m |

### Classic v2 (default sidearm)
The free default pistol and the sidearm benchmark. **No ADS**: right mouse (gamepad LT, touch AIM) fires the alt-fire instead.
| Stat | Value | Valorant Classic |
|---|---|---|
| Fire | Semi, 0.148 s (6.75/s) | 6.75/s |
| Alt-fire | 3 pellets in a 3.4° cone, uses 3 rounds (one pellet per round, so with 1–2 left it fires 1–2), 0.45 s before the next shot of either kind (2.2/s); each pellet does normal damage (3 body = 78 up close) and adds a shot of spray heat | 3-pellet burst, 2.22/s |
| Mag / reload | 12 / 1.6 s tactical, 1.9 s empty (slide release) | 12 / 1.75 s |
| Equip | 0.6 s first draw, 0.35 s quick | |
| Damage | 26 body / 58 head / 22 legs; ×0.85 from 105 studs | 26 / 78 / 22 → 22 / 66 / 18 past 30 m |
| Spread | 0.4° first shot → 1.8° max (1 protected shot, +0.3°/shot), recovery 0.4 s | 0.4° → 1.8° |
| Movement | Pistol (Sidearm) row | |
| Recoil | `up` 0.55° × 2, then 0.35° up + 0.2° side, `switchChance` 25% (≥ 0.3 s apart), 80% recovers over 0.25 s; the alt burst kicks an extra 0.55° | |
| Speed | ×1.0 | |

Implemented as data (`Config/Weapons` `Classic`, `altFire`; `Config/GunSounds` `Classic`), waiting for the model. Alt-fire is generic: any gun with `noAds` and an `altFire` table gets it (the server checks the pellets, ammo cost and cooldown). Verified on a stand-in (the Vandal with the Classic's alt-fire, 2026-10-25): one press = 3 pellets, 3 rounds, 90 damage up close, next shot held for 0.45 s, no rejects.

### Shorty v2 (roster 01, sidearm shotgun)
Over-under break-action pocket shotgun. No ADS.
| Stat | Value | Valorant Shorty |
|---|---|---|
| Fire | Semi, 0.333 s (3/s); upper barrel, then lower | 3.33/s |
| Mag / reload | 2 / 1.5 s one shell, 1.9 s both | 2 / 1.75 s |
| Pellets | 15 in a 4° cone; centre shot exact (spread 0) | 15, 4° |
| Damage per pellet | 11 body / 22 head / 9 legs; ×0.55 from 25 studs, ×0.27 from 54 studs (one-shot up close: 165) | 11 / 22 / 9, ×0.55 7–15 m, ×0.27 15 m+ |
| Movement | Shotgun row (placed and held as a sidearm) | |
| Recoil | 2.4° straight up per shot, 80% back over 0.3 s | |
| Equip | 0.55 s first draw, 0.35 s quick | |

New generic weapon fields it uses: `muzzles` (shots come from each muzzle in turn), `shellsOnFire = false` (the reload clip shows the spent shells), `hideBeyond` (props hidden away from rest), `moveClass`. The server now counts up to 20 hits per shot.

## 4. Aim assist (touch and gamepad only, never mouse)
- **Slowdown:** aim sensitivity drops to 60% within ~3° of an enemy.
- **Light magnetism:** gentle pull (≈15%) toward the target **only while ADS** and moving the aim.
- **No snap-to-target.** Use Roblox's official Aim Assist module as the base.
- Ranked will split pools by input type. Never give stat buffs by device (device detection can be spoofed).

## 5. Feedback ("juice")
This is a big part of why RIVALS feels good. Build it alongside the very first gun.
Fresh base (2026-10-25): the old UI is gone; this is what the plain HUD keeps until the new UI pass.
- **Hit marker:** white for body, **amber for headshots**, red X on a kill. Instant on the client, confirmed by the server.
- **Sounds:** distinct body-hit tick, headshot "ding", **kill sound**.
- **Damage numbers** that stack while you keep hitting the same target, then fall off in an arc (RIVALS style); amber for headshots, bigger on the kill.
- **Victim:** directional hit indicator, red low-HP vignette. Later: a short death recap showing **the killer's gun and Mods** (teaches the draft).
- Later, with the new UI: kill feed, kill banner, a round-win stinger, a slow-mo kill cam on the deciding round.
- **Realistic shot effects** (no neon): fiery muzzle flash, smoke and barrel wisps, brass from `Eject`, warm tracers (none for suppressed guns), impacts that depend on the surface. Deaths use the default Roblox death for now (the pixel dissolve was retired with the sci-fi look; a ragdoll is a later task). No blood.

## 6. Camera and controls
- **First person.** FOV 80 by default (setting 70–100), with ADS FOV set per gun.
- **First-person arms (RIVALS style):** one long, smooth, softly bevelled block per arm (R6 cross-section, no elbow), coming up from off-screen into the gun's grip; the end of the block is the hand. Skin colour from the avatar; a classic Shirt is drawn on the block the way Roblox draws it on R6 arms. References: `02 Art/References/rivals-viewmodel/`.
- **How the viewmodel works** (`ViewmodelController`, motion in `Util/ViewmodelMotion`, numbers and keyframes in `Config/Viewmodel`). Rebuilt 2026-10-25 (pass 4) the standard way (EgoMoose, "Writing an FPS framework"): **one rigid rig**, computed in this order every render frame right after the camera, then everything moved at the end of the same step:
  - **Root** = camera × motion. Bob, breathing, sway, strafe tilt, fall lift and landing dip all add up to this one offset, so the gun and both arms move as a single unit.
  - **Gun** = root × hold pose: hip↔ADS, the movement poses (Sprint, Slide, Crouch, Air), the keyframed tracks (Draw, Equip, Inspect, InspectMelee, Reload / ReloadEmpty body motion) and the recoil kick.
  - **Hands and arms** = gun × hand. Each hand has an offset from its grip attachment and an arm direction, both in gun space (`RIFLE_RIGHT_HAND`, `RIFLE_LEFT_HAND`, `PISTOL_RIGHT_HAND`, `PISTOL_LEFT_HAND`, `MELEE_HAND`), so a hand can never drift off the gun. During the gun's handling clips (`HAND_CLIPS`: Reload, ReloadEmpty, Draw, Inspect) the support hand blends (in gun space) to the part it works: the first moving one of `Mag`, `Cylinder`, `Barrels`, `Pump`, `Bolt`, `ChargingHandle`, then a later one if their windows don't overlap; on Fire, the pump or bolt. While the hand works a part its arm turns toward `REACH_DIRECTION` (down-left), so it rises from below instead of crossing the screen. Melee's free hand is a guard on the root (`FREE_HAND`).
- **Handling animations (new direction, Vandal first).** Each gun has Blender clips for its parts (`tools/blender/anim_<gun>.py`) and the viewmodel adds body-motion tracks:
  - **First draw** of each life (`firstEquipTime`, Vandal 0.9 s): the gun swings up from low right, thumbs the selector off safe, cants left side up and the support hand racks the charging handle; it jolts as the handle slams home. Later swaps are a quick raise (`equipTime`).
  - **Tactical reload** (mag swap, Vandal 2.3 s) and **empty reload** (mag swap then a rack, 2.8 s): the gun plays `Reload` or `ReloadEmpty`.
  - **Inspect:** the viewmodel's show-both-sides track plus the gun's own clip: a tap on the mag, then a press check (charging handle half back) with the buddy swinging.
  - **Foley is read off the clips** (`ViewmodelController` `clipBeats`): mag out when the Mag starts moving, mag in when it stops, the rack when the charging handle comes to rest. So sounds stay in sync for any gun.
  - Studio: the Workspace attribute `VfxTimeScale` slows or freezes the viewmodel too (0 freezes), for reviewing poses.
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
- **Inspect:** **Y** like Valorant (moved from F on 2026-10-25 when the dev picker went, so F stays free for Mod 3). About 2.8 s: show the right side, flip to the left side, return. Fire, aim, reload and swapping cancel it.
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
| Inspect | Y | D-pad down | — |

All mobile buttons can be moved and resized in settings.

---

## Build order
1. ✅ Movement (walk, sprint, crouch, slide, slide-jump), using the Input Action System.
2. ✅ Byte: fire, server validation, damage + head/legs, hit marker + sounds.
3. ✅ Spread and bloom + recoil + ADS.
4. ✅ Bitrate (auto) → Hard Reset (pellets) → Long Poll (scope) → the rest of wave 1 (Root, Bandwidth, Flood spin-up + ThinWall, Ray Trace charge, Cutter).
5. ⬜ Aim assist on touch and gamepad. Test on a real phone.

Status 2026-10-25: steps 1–4 work against dummies in Studio; all numbers are first guesses in `Config/` and need a 2-player feel pass. Not built yet: tactical/empty reload difference beyond timing, hit indicator for the victim beyond direction, kill cam, death recap, mobile layout tuning.

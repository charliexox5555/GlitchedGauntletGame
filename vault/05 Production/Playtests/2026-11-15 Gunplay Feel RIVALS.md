# 2026-11-15 Gunplay Feel (RIVALS)

Brief: [Prompt: Gunplay Feel (RIVALS)](../../04%20Tech/Prompts/2026-11-15%20Gunplay%20Feel%20(RIVALS).md). RIVALS numbers: [Body, Viewmodel, Guns and VFX → Hit feedback and crosshair](../../03%20Research/Rivals%20Reference/Body,%20Viewmodel,%20Guns%20and%20VFX.md). Design: [Gunplay §5](../../01%20Design/Gunplay.md), [Style Bible §3-4](../../02%20Art/Style%20Bible.md). LihFolk: `47 Game Feel and Juice` (hit confirmation layers, springs over tweens), `05 UI and UX/UI Motion Language and Timing` (Quint, no overshoot on UI chrome; the crosshair and marker are feedback, not chrome).

## Owner's answers (reference interview, 2026-11-15)
| Question | Answer |
|---|---|
| Crosshair on slide | **20° tilt like RIVALS**: snaps on, springs back. |
| Legs in first person on slide | **No**: camera + gun only. |
| Headshot screen cue | **None**: red marker, red number, pop sound, the flare on the head. |
| Kill marker | **Same marker**; we keep our own kill UI and line (no RIVALS "Eliminated" row). |
| Mid-pass (owner) | "The hit marker should look similar or same as RIVALS and look better, same with the headshot effect"; then "really see what RIVALS does", plus **their tracers and shooting look**, made to fit our game. Their image ids are **not** used (study-not-copy rule): every texture here is our own drawing. |

## Plan
1. **Hit markers** (`Config/HitFx` MARKER, `Util/HitFeedback`): RIVALS motion. Start big and wide, shrink in tight on a critically damped spring (ω 20, ~0.25 s), rest small near the centre, stay fully visible ~1 s, then fade (`(t/life)^10`). Analytic from the hit time, so the same at 15 and 60 fps. Head = RIVALS crit red. Tilts with the crosshair on a slide.
2. **Headshot**: rebuild the burst on RIVALS' layer recipe with our textures: impact (frame 0) → 50 ms → soft glow, dark layer (negative LightEmission), upward streak, stretched shards, the flare fan as the "big middle". Colour ramp white → orange `FF8146` → red `FF1111`.
3. **Crosshair motion** (`Config/Crosshair` `motion`, `Util/Crosshair`): RIVALS-style springs that snap up and ease down: slide tilt 20°, air gap, dash kick, per-shot bloom kick, ADS collapse-and-fade.
4. **Body on slide**: camera roll on a springy (underdamped) roll, a little more drop; no legs. Third-person clips checked on rifle / pistol / knife.
5. **Extras**: damage wedge holds longer (RIVALS 5 s), hurt pulse scaled by damage / health, low-HP vignette from 50 %.
6. **Stale lines**: Style Bible :30, :35; Gunplay :325; the 11-14 Handoff "radial burst".

## Results (built and played in Studio, match place, test range, Vandal, 2026-11-15/16)

### 1. Hit marker
- **Shape:** our own kite blade (`art-source/vfx/hit/marker_kite.png`, `tools/vfx/make_hit_vfx.py` `kite()`): a slim white rhombus 1:2.5 with a faint soft halo baked in. The dark back plate is off (it made the old wedges read as blobs). RIVALS' marks are the same idea: four slim white blades on the diagonals.
- **Motion (RIVALS numbers):** start tips 40 px out, blades 22 px; rest 8 px out, 11 px; critically damped spring, speed 20 (~0.25 s); solid until ~1.2 s, gone at 1.7 s (`(t/life)^10`). Computed from the time since the hit, so it looks the same at 15 and 60 fps (Studio ran at both). A spray restarts 85 % of the travel. Head = `FF3232`; kill = the same marker. The marker turns with the crosshair's slide tilt.
- Code: `Config/HitFx` `MARKER`, `MARKER_ASPECT`, `TEXTURES.marker`; `Util/HitFeedback` (`shrinkAt`, `progressOf`).

### 2. Headshot
- **What RIVALS does** (studied in their file: emitter settings and a look at their flipbook; nothing copied): a hot impact on the hit frame, then 50 ms later a **4×4 one-shot flipbook of sharp blades** (a tall centre blade, side blades at ±38°, chips further out) that shoot out, split and break up in 0.5 s, plus a soft glow, a dark layer (LightEmission −2), an upward squashed streak and stretched shards; white → `FF8146` → `FF1111`; Brightness 4-5 so it blooms.
- **Ours:** the same layer recipe with our textures. The crown is our own 16-frame drawing in the faceted style (`head_crown_4x4.png`, `crown_flipbook()`), Brightness 2.5 (over our Bloom threshold of 2). The ChatGPT flame fan, ring and embers are off (`HEAD_FLASH.flare = false`, `ring.enabled = false`, `embers.count = 0`). No screen cue.
- Two dead ends on the way: a soft ray fan (it bloomed into a white cloud, and particles emitted in one frame share the emitter's last Rotation); a glow at RIVALS' full size (it whited out the head on our bright range; now half size and faint).
- Code: `Config/HitFx` `HEAD_FLASH` (`burstDelay`, `crown`, `glow`, `dark`, `streak`, `sparks`), `Util/HitFx` (`emitBurst`).

### 3. Crosshair motion
`Config/Crosshair` `motion` (every number settable; 0 turns a reaction off), `Util/Crosshair` springs (speed 20, damping 0.875, snap up and ease down like RIVALS). Measured in play:

| Reaction | Result |
|---|---|
| Slide | 0 → **20°** on the first slide frame, held for the slide (0.85 s), back to 0 in ~0.25 s |
| ADS | bars close 10 → 3 px while fading out, back on release |
| Per-shot bloom | Vandal spray: gap 10 → 17 px, settles back ~0.3 s after the last shot |
| Air / Dash | +10 px in the air, +14 px kick on a Dash (code path; not logged separately) |

Wiring: `HudController.setCrosshairState / crosshairShot / crosshairDash`, called from `WeaponController` (state each frame, the shot in `fireShot`) and `ModController` (Dash).

### 4. Body on slide
- No legs in first person (owner). The slide roll rides an underdamped spring (`Juice.SLIDE.rollSpeed` 15, `rollDamping` 0.5, RIVALS' numbers): it swings ~16 % past the tilt and settles. Tilt 3 → **4°**, drop 1.9 → **2.2** studs (RIVALS: 5°, 3 studs).
- **Not done this pass:** the third-person SlideIn / Slide / SlideOut clips were not re-checked on rifle, pistol and knife from a second player.

### 5. Extras
- The damage wedge holds **2.5 s** (was 0.85; RIVALS 5 s), following the shooter.
- Hurt pulse = 0.16 + 0.6 × (damage / health before the hit), at most 0.55, fading over 0.4 s (RIVALS: 0.5 + 0.5 × share). Low-HP vignette from 50 % HP, full at 10 %.
- "Eliminated <name>": not added (owner: our own kill UI and line stay). A kill was checked: the kill feed and kill badge show, the marker is the normal one.
- Numbers only, not judged on screen: the wedge hold and the vignettes.

### 6. Tracers (added mid-pass)
- **RIVALS:** one tapered beam (0.5 → 0 studs, camera-facing, emissive, a dim orange light on it). Your own: the tail starts at the muzzle and runs to the hit at ~800 studs/s, the head at most 75 studs ahead. Others: a 15-stud dart at the same speed. Friendly orange, enemy red, a fly-by whoosh.
- **Ours now:** the same timing in `Juice.TRACER.dart` (speed 800, reach 75, start 1.2 studs) and others' streak at 15 studs and 800 studs/s; our per-class colours, pixel widths and trail stay. The first frame always shows the whole streak from the muzzle (at 15 fps a round covers 50 studs a frame). Logged: others' streak 14.5 studs; our dart's head on a 104-stud target with the tail running in.
- Muzzle flash left as is: ours already follows the same many-layer pattern (Valorant-style, owner-approved). RIVALS' flash lives 0.1-0.3 s with no light; ours is shorter and lights the scene. Parked.

### Grades (self, against RIVALS and our taste rules)
| Item | Grade | Holds it back |
|---|---|---|
| Hit marker | 9 | needs your eye at full speed |
| Headshot crown | 8.5 | our body flash stays subtle (your earlier call) where RIVALS turns the head solid red; judge at speed |
| Crosshair motion | 9 | measured, not yet felt by you |
| Slide camera | 8.5 | third-person slide not re-checked from a second player |
| Extras | 8 | vignettes and wedge hold not judged on screen |
| Tracers | 8.5 | timing matches; the look not judged at full speed |

## Test list (for the owner)
1. Range, Vandal: tap body shots, then headshots. Do the kite blades shrink in and hang like RIVALS'? Red on the head?
2. Headshot a dummy at 15, 25 and 50 studs. Does the crown read like RIVALS' (blades fanning up, breaking up, glowing)? Too big or too bright?
3. Spray a dummy: the marker pulses; the crosshair blooms and settles.
4. Slide: the crosshair tilts 20° and springs back; the camera roll swings a touch past and settles. Too much?
5. Jump and Dash: the gap opens and eases back. Aim down sights: the bars pull into the dot.
6. Get shot by the Shooter dummy: the wedge stays 2.5 s; the edge pulse scales with the hit; below half HP the vignette builds.
7. Shoot at 25 and 100 studs: your tracer runs from the muzzle into the hit; the Shooter's streaks fly at you.

## Parked questions
- Head flash: full RIVALS (a solid red head on a headshot) or keep the subtle flash?
- Muzzle flash: RIVALS length (0.1-0.3 s, no light) or keep ours?
- Damage wedge: 2.5 s or RIVALS' 5 s?
- A fly-by whoosh for rounds that pass near you (RIVALS has one)?

## Commit
Committed on `main` in 6ca4c13c (owner, 2026-11-16: "commit all touched files"). It also carries earlier uncommitted work from other sessions in the same files (the 2026-11-13 hit feedback pass, the 2026-11-15 gunplay overhaul edits in `WeaponController`, `HudController`, `CameraController`, `ModController`, `Juice`, `Movement`, `TracerFx`, and `art-source/vfx/hit/`). Not pushed. No Studio-owned changes, so no place save is needed.

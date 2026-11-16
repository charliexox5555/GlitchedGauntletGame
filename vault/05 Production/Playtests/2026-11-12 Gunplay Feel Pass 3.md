# Gunplay Feel Pass 3 (2026-11-12)

Follows [Feel Pass 2](2026-11-10%20Gunplay%20Feel%20Pass%202.md). Owner's brain dump: gunplay "still feels a little stale", wants it more fluid, professional and fun (crouch, jump, slide); the run animation "seems a bit off"; hands should move when you jump and fall; the hands should look better; the knife is held through the middle of the hand (wants it on the inside edge), its inspect needs more movement, and the heavy stab's hand "goes across the whole body"; in a spray "the gun looks like it's moving in a random direction".

## What was wrong (read from the code and seen in play)
- **Spray:** every shot picked a random side for the gun's yaw, a random side for its roll, and a random side for the climb's drift. Nothing tied it to the camera recoil.
- **Heavy stab:** the keys rolled the knife about 175° (edge up). The arm's direction was fixed to the knife, so it flipped up and across the view.
- **Run:** the loop was a plain sine. LihFolk "Locomotion Readability - Lessons from Blind Panels": even sine spacing reads "off"; a body rises slowly and drops quickly onto the footfall.
- **Air:** only a small static pose and a lift lag; nothing for rising against falling.
- **FOV:** jumping out of a run snapped the view from run FOV back to walk FOV, then back on landing.

## Changes
| Item | Change | Checked |
|---|---|---|
| Spray | The gun's sideways kick follows the camera recoil's side (`PUNCH_LEAN` 0.85, roll `PUNCH_ROLL_LEAN` 0.6) with ±15% jitter; taps and the first shots kick straight up and back. `WeaponController.kickRecoil` returns the side; `ViewmodelController.fire(..., lean)` | 1.6 s Vandal spray: **0** side changes of the gun's yaw, max yaw 1.3°, max pitch 6.6° |
| Jump / fall | Muzzle tips up on the way up and down on the way down (`AIR_PITCH`), the gun rolls out and both **elbows flare** as you fall (`AIR_ROLL`, `AIR_ELBOW`), bigger lift lag | Frozen mid-fall on screen: gun lifted and rolled out. Subtle at a 4.4-stud jump |
| Jump feel | Jump buffer 0.12 s and coyote time 0.1 s (`MovementController`); the view keeps its FOV in the air (+1.5°) | Code only |
| Run | Swing hangs at each side (`BOB_HANG`), each step rises slowly and drops fast (`BOB_STEP` 1.7) | Code only, **not looked at in motion** |
| Crouch | Dip on the way down, lift on the way up (bounce spring, `CROUCH_BOUNCE`), a deeper tucked pose | Code only |
| Knife hold | The fist sits beside the handle: `MELEE_HAND.offset` (0.143, 0.029, 0.241), tuned live | On screen: the handle runs along the inside edge of the fist |
| Knife arm | Always runs from the hand to the right shoulder (`MELEE_SHOULDER`, root space), whatever the blade does | Stab on screen: arm comes up from low right |
| Heavy stab | One hand, from the middle of the chest straight up the centre line into the crosshair, edge down (new keys from `tools/studio/knife_fp_keys.py`, rest pose re-measured). `MELEE_HEAVY_TWO_HAND = false` | Frozen at the thrust: blade on the crosshair, arm not crossing the view |
| Knife inspect | 2.6 s (was 2.3): comes up with a flick that overshoots, a small toss between looks, snaps back past rest. Sounds retimed | Ran without errors; **not looked at** |
| Knife idle | A slow roll and turn in the hand while held (`MELEE_IDLE`) | Code only |

`selene` 0 / 0, `stylua --check` clean, `rojo build` OK, no script errors in Output.

## LihFolk notes used
*Locomotion Readability - Lessons from Blind Panels*, *Procedural Gait and Footstep Planning* (step shape); *Input Responsiveness, Buffering and Coyote Time* (buffer 0.10-0.15 s, coyote 0.08-0.15 s); *Gun Feel - Recoil, Spread, Bloom and Headshot Multipliers* (kick mostly vertical, jitter under ~20% of a step, never pure random); *Combat Animation Craft*, *Timing Spacing and Frame Charts* (heavy anticipation 6-15 frames, strike 1-3); *Held Weapons on Motor6D* (corrections go on the wrist / arm, not the grip).

## Not done
- **"The hands need to look a little better": the arm mesh stays a plain block (owner, 2026-11-12).** A shaped fist was offered and started, then stopped by the owner before anything was built: "the hands would literally just be a block... the same as rivals. I don't want it to be like an actual hand." `tools/blender/make_arm_mesh.py` and `Arms.fbx` are unchanged. If the hands still look off, it's about how they sit and move on the gun, not the mesh.
- Slide: nothing new this pass.
- The three light slashes still use their old keys (they were solved for the old hold, 0.04 studs off the new one).

## What to test (owner)
1. Spray the Vandal, Stinger and Odin at a wall: the gun should pull one way with the pattern, not jitter side to side.
2. Jump and drop off the range's boxes: elbows out on the way down, bounce on landing. Is it enough?
3. Run: does the new step rhythm read better or worse?
4. Knife: the hold, a heavy stab (right click), the inspect (Y), standing still with it.
5. Tap jump just before landing, and jump just after running off an edge.

## Follow-up, same day: arms and holds from the owner's RIVALS screenshots
The owner sent four RIVALS first-person screenshots (rifle, pistol, knife, grenade; pasted in chat, not saved to the vault) and said: the arm stays a block; no shirt = plain skin; a shirt shows "a little bit and then the skin colour"; "a very, very slight black outline"; redo the holds toward that vibe, with our own character.

What the references show: a **sharp, flat-shaded block** with almost no rounding; with the knife **both arms are long diagonals from the bottom corners** and the knife stands upright on the right; the rifle's support arm is a long diagonal from the lower left.

| Item | Change | Seen on screen |
|---|---|---|
| Arm block | One small chamfer (0.035, was a 0.16 soft bevel), flat faces. Model asset 115198041447582; the soft one is kept as `art-source/viewmodel/Arms_soft_2026-10.fbx` | Yes |
| No shirt | Plain skin block. (A fallback sleeve was built and removed at the owner's word.) | Yes |
| Shirt | The shirt layer starts 0.62 studs up from the hand end (`ARM_SLEEVE`), so the hand and wrist stay skin | **No: the test avatar has no classic Shirt** |
| Outline | The block inside out, 0.004 studs larger all round, near-black at 35% see-through (`ARM_OUTLINE`; rim 0 = off) | At 0.006 opaque it read as a cartoon line; the softer setting was **not re-looked at** |
| Knife hold | Upright on the right, blade leaning in: offset (0.78, -0.72, -1.28), rotation (56, 14, -10); all four attacks re-solved against it (`tools/studio/knife_fp_keys.py`) | Hold: yes. **Attacks and inspect at the new hold: not looked at** |
| Knife arms | Shoulder wide and low (`MELEE_SHOULDER` (2.5, -2.7, 0.7)); the free hand mirrors it (`FREE_HAND`) | Yes |
| Rifle support arm | `RIFLE_LEFT_HAND.direction` (-0.5, -0.8, 0.3): a diagonal from the lower left | Vandal: yes. Other long guns: no |

Tried and dropped: a tinted mask texture for a sleeve (on a SpecialMesh the texture's clear areas draw in the part's colour, not see-through); a shaped fist (stopped by the owner before anything was built).

## Follow-up 2, same day: outlines and the knife, third time
Owner: the arm outline is "slightly too thick"; add a "super slight" outline on the gun too (a setting to switch off later); the knife hold was "at a real weird angle" and the slashes looked weird. A flat-on blade was tried live and rejected ("the flat of the blade doesn't really look good"); the owner re-sent the RIVALS knife screenshot: a narrow upright blade on the right, both hands tilted in.

| Item | Change | Seen on screen |
|---|---|---|
| Arm outline | `ARM_OUTLINE.rim` 0.004 → 0.0028 studs | Yes (thinner) |
| Gun outline | A `Highlight` on the gun: outline only, near-black, `GUN_OUTLINE.transparency` 0.62, hidden behind walls, fades out as you aim. One switch (`enabled`) for the later setting | Present and faint on the knife; **not judged on every gun** |
| Knife hold | Offset (0.893, -0.762, -1.455), rotation (59.2, 9.9, -25): upright on the right, leaning in, the blade nearly edge-on. Solved from the wanted blade and edge directions, then checked live | Yes |
| Slashes | Three new arcs solved for that hold. Rule: every cut travels along the edge, one clean arc through the crosshair, no blade flips (the old backhand rolled it over 150°; the new Slash2 still turns the wrist over, which a backhand needs) | Slash1 at contact: yes. **Slash2, Slash3: ran, not looked at** |
| Heavy stab | Same centre-line thrust, re-solved; the edge stays down and in | Yes. The **pommel shows on the inner face of the fist** at the thrust (the knife lies along the fist's inner edge by design) |

Ran without script errors: slash chain, inspect, Vandal spray, reload.

### Self-grade (honest, from stills; motion not watched)
| Thing | Grade | Why not higher |
|---|---|---|
| Arm look | 8.5 | Matches the reference; the shirt layer is unseen |
| Knife hold | 8 | Reads like the reference; our knife is short and stubby next to theirs |
| Slashes | 7 | Only one seen, and only a still |
| Heavy stab | 7.5 | Clean line; the pommel shows on the fist |
| Rifle hold | 8 | Only the Vandal checked |
| Pistol hold | 7.5 | Not re-checked since the arm and outline changes |
| Outlines | 7.5 | Faint, as asked; a Highlight's width can't be set, only its strength |

## Follow-up 3, overnight: knife hand, off hand, inspect, aim strafe, aim in a slide, run
Owner (going to bed, full Studio control): the off hand "just sticks there" in slashes; "too much of the knife is out of the hand... tilted weirdly"; the inspect "moves unnaturally in the hand", wants a simple look at the front and the back; the pistol run "looks a little bit off" and friends said running "feels a bit off"; the aimed strafe should be more drastic "like Rainbow Six Siege and Rivals: go right, the gun rotates a bit to the left"; aiming while sliding "looks really weird, not in the middle".

| Item | Change | Measured / seen |
|---|---|---|
| Knife in the hand | Fist moved up the handle to the guard (`MELEE_HAND.offset` (0.115, 0.02, 0.07)); shoulder less wide (`MELEE_SHOULDER` (1.95, -3.0, 0.55)) so the forearm runs nearer the handle's line | Seen: only the guard and blade show above the fist |
| Off hand | Goes with the body as the knife travels (`FREE_HAND_FOLLOW`) | Its arm centre moves 0.48 studs through a slash; seen dropping back mid-swing |
| Inspect | 2.4 s: lift a little, roll to one face, hold, roll to the other, hold, return. No flicks or toss | First look seen. Second look and the return: not looked at |
| Aimed strafe | Direction back to **against** the strafe and bigger: `ADS_STRAFE_ROLL` +0.012, cap 7.5°; `ADS_STRAFE_SHIFT` 0.0008 → 0.00015 | Strafing right at 15 studs/s: roll 6.8°, top to the left. The sight sat 34 px off the crosshair before the shift cut; **not re-measured after** |
| Aim in a slide | Movement poses now leave with the aim blend itself (`weights = spring x (1 - aim)`), not on their own slower spring; leftover drift and dip are scaled out while aimed (`settle`); slide chatter and kicks fade with aim | Before: sight -152 px at 0.40 s, -56 at 0.54, roll 3.4° → 1°. After poses fix: -58 px at 0.35 s, -23 at 0.49, -2 at 0.77, roll within 0.8° throughout. **Not re-measured after the drift scale-out** |
| Run | `BOB_SPRINT` pulled back about a quarter, `BOB_HANG` 1.5 → 1.0 | Not measured |
| Pistol run | Off-hand swing two thirds the size, lower and wider | One still: pistol canted in the right hand, off hand out of frame at that instant |

Also found: a crouch tap shorter than one simulation step (about 16 ms) is missed, so a slide doesn't start. A human tap is 50 ms or more; the test tool's instant key press isn't. Not changed.

### Code or keyframes? (the owner's question)
It is already a hybrid, which is what LihFolk's *Procedural Animation*, *First-Person Viewmodels* and *Weapon and Combat Animation* notes describe as the normal split:
- **Keyframed, authored in Blender:** every gun's own moving parts (slide, bolt, mag, lever, cylinder) for fire, reload, draw and inspect (`tools/blender/anim_<gun>.py` → `src/shared/WeaponAnimations`).
- **Keyframed, as data in `Config/Viewmodel` `TRACKS`:** how the whole gun moves in a draw, reload, inspect, and every knife attack (keys with easing, played by `Util/ViewmodelTracks`).
- **Procedural (springs):** sway, bob, recoil kick, landing and jump bounce, aim strafe lean, and the arms following the gun.
The vault's rule of thumb: keyframes for authored performance (they read better than sine motion), procedural for anything that reacts or never ends. The weak spot is not code versus keyframes: it is that the knife attacks are keyed by numbers and judged from stills. Scrubbing them in Blender's viewport (the pipeline for gun clips already exists) would let someone watch the motion while shaping it.

**Re-measured after the last two changes (final build):** aimed and strafing right, roll 6.2°, sight (+4, +4) px from the crosshair (was 34 px off). Aiming during a slide: sight (-26, -10) px at 0.30 s, (-3, -8) at 0.50 s, (-4, -6) at 0.70 s, roll within 0.5° throughout (before any of this: -152 px at 0.40 s and still -56 at 0.54 s). Standing aimed: (-3, -3) px. `selene` 0 / 0, `stylua --check` clean, `rojo build` OK, no script errors in Output.

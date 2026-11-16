# Gun and knife feel from the owner's videos (2026-11-14)

**Brief:** [Handoff - Gun and Knife Feel from Videos](../Handoff%20-%20Gun%20and%20Knife%20Feel%20from%20Videos.md). **Clips:** `art-source/reference/feel-videos/` (third-party, git-ignored; key frames in its `frames/` folder, named `<clip>_<moment>.jpg`). Watched with the video-analyzer MCP at 60 fps (bursts of 14-30 frames per event), measured as screen fractions and milliseconds.

**Owner's asks, in order:** shot feel per gun type; gun pull-outs; **the knife above all** (slashes, heavy, pull-out, inspect); hit markers, headshots and crosshair. During the pass he added, about the knife:
1. "you are rotating the arm in unnatural ways";
2. "like in RIVALS they keep it on the edge of the hand... on inspect it jumps to be just on the side of the hand and not in the actual arm";
3. "smoother, nicer, have feedback and not a complete linear animation... the hands don't have fingers, so it won't move in weird ways".

## 1. What the clips show (numbers)

### Knife (20.8 s clip)
| Move | Measured |
|---|---|
| Hold | Blade upright, leaning in about 12°; the block arm comes in from the bottom right about 21° off vertical; **the handle sits on the inner (left) edge of the fist block, the guard just above the block's end**. Free arm a matching diagonal from the bottom left. |
| Light slashes | **Alternate forehand / backhand** (4.55, 5.35, 6.05, 6.85 s; about 0.7 s apart). Each: a tell (a lean, ~30 ms), the fist **leaves the screen to wind up** (~65 ms), **one fast sweep on screen for only 3-4 frames (~60 ms)** with the blade pointing forward over the crosshair, the fist **leaves on the far side** (~170 ms off screen), then **rises back in from below** (~250 ms) and settles. The free arm drops out of view for it. ~0.6-0.65 s each. Swipe: a thin white streak at the tip for 1-2 frames. |
| Forehand | Wound up off the top right, swept down-left through the middle, out of the bottom-left corner. |
| Backhand | Wrist turned over, blade laid out to the left and **held ~130 ms** (the load), then swept right and up through the middle, out bottom right. |
| Heavy | Fist drops down-right (~170 ms), **cocked low in the middle with the point forward (~250 ms)**, a thrust with **both arms coming in** and the point dipping (~50 ms), held ~100 ms, the blade rolls back up through the right (~200 ms), settles with a small lean past the hold. ~0.9 s. |
| Pull-out | Up from below, the knife turns about 315° in ~0.25 s while the arm swings in from the right, lands pointing left low left, rises to the hold, small settle; free arm last. ~0.85 s. (Ours can't copy the spin: a block fist has no fingers to turn it in. See §2.) |
| Inspect | ~4.3 s. Lean left; brought to the middle **flat face to you** (held ~1.1 s, slow drift); turned edge-on; **laid over pointing left, edge down** (held ~1.5 s); tipped point-down, dropped out low right and back up. No spins. |

### Guns (six clips; the rifle / SMG and pistol / revolver / sniper numbers came from two analysis agents, frames in `frames/`)
| Gun | Shot | Recovery | Camera | Flash |
|---|---|---|---|---|
| Pistol | Peak in **1 frame (≤17 ms)**: the back of the gun swings toward you, the gun ~25% bigger, muzzle up | nearly home by 100 ms, settled 170 ms, **no overshoot** | **still** (no punch, FOV or shake) | white-yellow core, orange star about the gun's width, 6 bright frames, gone by ~170 ms; a light washes the floor |
| Revolver | 1-frame snap, flip ~2.5x the pistol's, **holds at the peak ~50 ms** | back by 120 ms, settled 220 ms | still | about 2x the gun's width, rays, 150 ms; the floor lights a frame before the gun moves |
| Assault rifle | 1-frame snap back toward you, muzzle up a little (~5% W / 9% H) | spray: the gun sits back and shakes 3-4% W per shot, no sideways drift | still, no view climb | small, 1 frame; tracers |
| Large SMG | the hardest snap (8-9% W / 17% H) | spray climbs | view climbs (maybe the mouse) | big star, 25-30% of the gun's length |
| Small SMG | small fast kick (3% W / 5% H) | tight fast shake, ~15-18 shots/s | still | starburst |
| Sniper | rocks back into the camera ~30% bigger, 20-25° up, slight roll | slight overshoot, back by ~200 ms; bolt beat with a gold shell ~0.65 s after | ~2% dip, then nothing | modest, 130 ms |

Pull-outs: pistol ~300 ms from the bottom right, muzzle tipped up-left ~45°, rotates down into the hold; revolver 200-250 ms, **no spin**; rifle ~500 ms from the bottom left rolled ~60°, dips ~4% and settles; SMGs 250-270 ms; sniper ~1 s. ADS in 100-200 ms.

**The one big finding:** in every clip the camera stays still and **all the kick is in the gun**: a one-frame snap, then a quick ease home. Ours spreads the shot over a camera view punch, a FOV pulse, roll and shake, and the gun's own kick peaks ~42 ms after the shot on a spring that wobbles.

### Hits (aim-trainer clip, no kills in it)
- Crosshair: 4 white ticks (6 px, 2 px thick, gap 15) and a 2 px dot, no outline; blooms ~5 px while firing.
- Body hit marker: 4 white diagonal wedges that **close inward** (±28 → 16 px over ~100 ms) while fading; restart on each hit.
- Target: **one frame white, then fades through pink to red** (by ~84 ms), back over 0.4-0.5 s; every hit restarts it.
- Damage number: one number per stream that **adds up**; white body / red head (#E01F35, dark outline), ~48 px tall, holds ~250 ms after the last hit, then **tips over clockwise and falls** while shrinking (~270 ms).
- Headshot: red number plus a fan of light rays from the head (~270 ms, warms to orange as it fades).

## 2. Plan (written before the build)

**Knife**
1. **One rigid fist** (owner: no fingers). The knife never moves in the hand: the fist sits on the handle's flat side and the forearm runs at a fixed angle from the knife, exactly as in the hold he approved (measured in play: forearm (0.096, 0.866, 0.49) in the knife's handle space, fist (0.115, 0.02, 0.07)). Only a small wrist give toward the shoulder (≤10°). The arm no longer aims at a shoulder point with a 62° clamp, which let the knife slide round the fist (the inspect "jump") and threw the forearm round when the blade turned.
2. **Keys solved for the rigid fist.** `tools/studio/knife_fp_keys.py` places each key on screen (fist and tip, as measured in the clip) and picks the wrist roll that brings the forearm closest to the shoulder side, so the arm always comes from below right.
3. **Smooth motion with feedback, not linear.** Today each pair of keys is a separate tween: it either eases to a stop at every key (robotic) or runs linear. The knife tracks get a **cubic Hermite spline with velocity carried through the keys** (positions, and rotations as rotation vectors), so the fist flows; anticipation, overshoot and settle are keyed; the wrist trail stays. Research (§3) sets the numbers.
4. Rebuild: alternating forehand / backhand (the third light slash a high forehand), the heavy (cocked low, two-arm thrust), the pull-out as a **rigid flourish** (the arm swings it up from below with a wrist roll, overshoot and settle; no in-finger spin), the inspect (front face, laid over, back). Swipe streak and gouge directions follow the new paths.

**Guns** (numbers in `Config/Viewmodel` and `Config/Juice`)
1. The gun kick becomes a **snap envelope**: peak ~13 ms after the shot, eased home in ~100-170 ms (per class), no wobble. It replaces the punch spring.
2. Sizes per class from the clips: pistols and the sniper kick back hard (the gun grows ~25-30%), the revolver flips hardest and holds the peak, rifles snap back with a small muzzle rise, the large SMG hard, the small SMG small and tight.
3. **The camera calms down:** FOV pulse, roll and shake about halved, view punch trimmed. The aim recoil itself is not touched (gameplay).
4. Flash: check life and size against the table above; a short world-light pop per shot.
5. Pull-outs: per class shape and timing from the clips.

**Hits:** compare ours (lane F, [Hit Feedback Pass](2026-11-13%20Hit%20Feedback%20Pass.md)) against the clip. Candidates: wedges closing in, the white-then-red body flash timing, an adding-up damage number with the tip-over exit. Hand the list to the hit-feedback lane, or do it here.

**Test:** the match place (133387545285290), Studio Play driven by `DevAction` / `DevHeavy` / `VfxTimeScale`, per-frame recordings of the fist, tip and forearm on screen, and captures beside the reference frames. Studio runs at ~15 fps there, so moments are frozen in slow motion. **A running playtest doesn't pick up Rojo changes: restart Play after every edit.**

## 3. Research (what the build leans on)
**LihFolk** (Combat Animation Craft; Timing Spacing and Frame Charts; Springs Damping and Smoothing; Hit-Stop and Screen Shake Tuning by Numbers; Animation Data Hygiene; Held Weapons on Motor6D - Locking the Grip During Attacks):
- Melee: anticipation 2-5 frames at 30 fps (0.07-0.17 s), strike 1-3 frames, contact hold 2-3, follow-through 3-5, recovery 4-8.
- "Robotic" comes from linear segments (corners) or ease-in-out on every key (it stops at each key). Use a monotone cubic (PCHIP) through the keys, and keep any turn between two keys under 120°.
- Viewmodel kick: rise in 1 frame, home in 0.10-0.18 s. Hit-stop 30-60 ms light, 80-150 ms heavy.
- Lock the blade in the grip during attacks.

**Published sources** (web agent; links in the session):
- Strikes are short and the retract is 1.5-2.5x the strike: Destiny 2 / Overwatch frame counts (Kotaku); Aztez "Anatomy of a successful attack" (active ≤ 6 frames).
- Fast-in slow-out, hold key poses a beat, overshoot the extreme (Cooper, *12 principles in games*; Overwatch talk).
- C1 splines plus at most one spring layer; inertialization for cancels (Holden "Spring-It-On"; Gears of War GDC).
- The camera leads into a strike like a boxer's head (Destiny).
- Big kick on the viewmodel, small and honest on the camera (Duffin GDC13; Rainbow Six recoil overhaul; CS:GO view punch).
- Pivot swings at the elbow or shoulder, never at the knife.

## 4. Results (built and measured in the match place)

### Knife (owner's main worry)
**The hold.** RIVALS frame study: the knife is in front of and on the edge of the fist, upright in the screen's plane, the blade ~37% of the screen's height. Ours was tilted ~30° into the screen, so the handle aimed at the camera, and the arm didn't follow the knife.
- **Knife pose:** `Config/Weapons` Knife `viewmodelOffset` (0.862, -0.516, -1.445), `viewmodelRotation` (78.2, 16.9, -30). Was (0.893, -0.762, -1.455) / (59.2, 9.9, -25). Found by a search in play against the clip's numbers.
- **Rigid fist:** the knife never moves in the hand. The forearm runs 15° off the handle (`MELEE_HAND`); the guard and the top third of the handle come out of the fist's inner top corner, and the pommel half is inside it. The hilt was measured never to leave the block in any move (0.000 studs). Before, it crossed the block at 61° and the pommel poked out ("seeing the bottom through the hand").
- **Arm solve:** the arm follows the knife, not a shoulder point with a 62° clamp (that clamp made the knife slide round the fist and the forearm swing when the blade turned). `MELEE_WRIST_BEND` 0, `MELEE_SHOULDER` on the hold's forearm line.

**The motion.**
- **Solver:** `tools/studio/knife_fp_keys.py` is rebuilt. A key is now *the fist's place on screen plus the forearm's roll*; the forearm swings from the shoulder, and the knife extends the fist. Every key is checked for: the forearm coming from the lower right (-60° to -85° on screen), no step over 93°, and eye clearance ≥ 0.88.
- **Tracks:** all knife tracks are `smooth` splines. `Util/ViewmodelTracks` now uses a cubic Hermite with monotone (PCHIP) velocities through the keys, instead of per-segment tweens. The gun Draw track uses it too.
- **Slashes:** they alternate forehand / backhand (the third is a high forehand). Measured fist speed: the wind-up runs at ~22 units/s and stops dead at the held coil (~120 ms); the strike snaps to ~50 units/s for ~60 ms through contact, brakes over ~100 ms, then rises back, overshoots the hold and settles by 0.6 s. The free arm drops out of view (`FREE_HAND_FOLLOW`).
- **Heavy:** a dip and drop down-right, cocked low in the middle with the point on the crosshair, coiled, a ~50 ms thrust with both fists together (`MELEE_HEAVY_HAND`, the free fist beside the knife hand, only for the thrust), a hold at full reach, the forearm rolls the blade back up, overshoot, settle.
- **Pull-out (0.75 s, was 0.56-0.65):** the fist swings up and flicks; **the knife is tossed, turns once in the air and is caught** (`toss` keys: the knife model moves, the fist stays). The catch knocks the fist down, then it overshoots and settles; the free arm comes up last.
- **Inspect (3.2 s):** the forearm rolls the blade's face to you past the pose and settles, holds, rolls over to the other face, holds, and lowers. The knife stays seated.
- **Feedback:** every swing rolls the camera into it 50 ms before contact (`KNIFE_FEEL.leadRoll` 1.6°, eased back over 0.32 s). The miss punch went 0.25 → 0.55° (heavy 0.3 → 0.7°). Swipe arcs and gouges follow the new paths. Hit-stop is unchanged.

Captures (our game, own frames) are in [2026-11-14 feel captures](2026-11-14%20feel%20captures/): `before_knife_hold`, `after_knife_hold`, `after_knife_slash_midswing`, `after_knife_heavy_thrust`, `after_knife_pullout_toss`, `after_knife_inspect_face`. Reference frames are in `art-source/reference/feel-videos/frames/knife_*.jpg` (third-party, not in the repo).

**Grades** (self, against the clip):

| Move | Grade | Notes |
|---|---|---|
| Hold | 5.5 → 8.5 | knife seated on the fist's edge, upright, long |
| Slashes | 5 → 8 | coil, snap, brake, settle; arcs cross the crosshair; free arm drops |
| Heavy | 5 → 7.5 | two fists in the thrust; the blade is short on screen at full reach because it points away |
| Pull-out | 6 → 8 | toss, flip and catch |
| Inspect | 5 → 8 | no arm twisting; the knife never leaves the fist |

The owner's eye decides. "Character / oomph" is the thing to judge in play: Studio here runs at ~15 fps, so play it at full frame rate.

### Guns (shot feel)
- **Shot kick is a snap envelope** (`Config/Viewmodel SHOT_SNAP`; replaces the punch spring, which peaked ~42 ms late and wobbled). Two exponentials: attack 6 ms, decay per class.
- **Sizes from the clips** (`SHOT_PUNCH`): pistol back 0.07 → 0.12, rise 5 → 9; new Sheriff entry (back 0.14, rise 16, held peak); rifle 0.06 → 0.075 / 2.4 → 2.2; small SMG 0.045 → 0.04 / 1.8 → 1.5; Spectre (large SMG) 0.035 → 0.06 / 1.4 → 2.2; Sniper 0.16 → 0.2 / 9 → 12.
- **Measured in play** (one shot, gun recorded each frame):

| Gun | Peak | Back | Muzzle | Home (within 10%) | Clip |
|---|---|---|---|---|---|
| Classic | 10 ms | 0.15 studs | 11° | 143 ms | 1 frame, 100-170 ms |
| Sheriff | 13 ms | — | 44° (incl. its clip) | 213 ms | ~45°, 220 ms |
| Vandal | 1 frame | 0.15 studs | 4° | 117 ms | — |
| Stinger | — | — | — | 103 ms | — |
| Spectre | — | — | — | 100 ms | — |
| Operator | 10 ms | 0.34 studs | 20° | 209 ms | ~200 ms |

- **Camera calmed** (`Config/Juice SHOT_FEEL`): the clips' cameras don't move. FOV, roll and shake are halved; view punch cut to ~60% (75% on shotgun / sniper). The aim recoil is not touched. **Rollback values** are in the config comments.
- **Pull-outs:** the gun Draw track is a spline now (flows through the rack and the drop). Per-class pull-out shapes from the clips are parked (see below).
- **Sheriff inspect (owner, mid-pass):** the inspect sound opens with a cylinder roll, but the clip turned the cylinder ~70% of the way through. Now `INSPECT_SPIN` rolls the cylinder from frame 1: two turns over 1.15 s, slowing like a palm roll, landing on a chamber (measured: 31° in the first frame, 355° by 0.2 s, 720° at 1.1 s). `GunAnimator.spin` does it on top of any clip.

### Hits vs the clip (handed to the hit-feedback lane, not changed here)
Ours already matches the clip on: wedges that slide in (clip: they close from ±28 to 16 px in ~100 ms), a white-then-red body flash (clip: white frame, pink, red by ~84 ms, back over 0.4-0.5 s), and the headshot burst. **Differences for lane F:**
1. **Damage number:** the clip has one number per target that adds up during a stream, ~48 px at 1080p in a heavy rounded font with a dark outline, held ~250 ms after the last hit, then it tips over clockwise (to ~120°), drops ~40 px and shrinks over ~270 ms; a new hit snaps it upright. Ours pops per hit at 30 px.
2. Head number colour: clip #E01F35 with a dark-red outline (ours #FF4D5E).
3. Crosshair: no change (ours has an outline; the clip's vanishes on white walls).

### Parked (Bugs & Ideas)
- Per-class gun pull-outs from the clips: pistol up from bottom right, muzzle tipped up-left ~45°, ~0.3 s; rifle from the bottom left rolled ~60°, ~0.5 s; SMG straight up ~0.25 s; revolver no spin.
- Muzzle flash life by class, from the clips (pistol / revolver ~150-170 ms with a star 1-2x the gun's width; rifle 1 frame) and a short world-light pop. That's lane F's `MuzzleFx`.
- Inertialization when a slash is cancelled into the next (research).
- `MELEE_TWO_HAND` and `MELEE_ARM_ANGLE`-era comments are now unused.

## 4b. Knife, pass 2 (owner's notes on pass 1: "feels good", but)
**The asks:**
- The slashes keep the blade upright.
- The hold looks like a hand facing the sky.
- The right click hesitates.
- The inspect doesn't move the knife.
- "The knife held as if there was a hand" (moving the knife is fine if natural).
- His overlay "Knife hold alignment": blade ~18° off vertical, half the handle showing, the free forearm left and down, the knife forearm angled outward with the grip over its inner edge.

**Frame-by-frame study (60 fps), what was missed in pass 1:**
- *Forehand:* the blade never stands up in a slash. It lies over ~45° and trails behind the fist (pointing back the way it came) while the forearm swings like a wiper from a low pivot. The fist runs from (0.75, 0.40) to (0.20, 0.80) in ~5 frames.
- *Backhand load:* the blade points straight out left in line with a forearm that crosses the body, for 8 frames; it trails up-left on the way back.

**Hold, fitted to his overlay in play** (exact projection, aspect-independent):
- Knife `viewmodelOffset` (0.902, -0.546, -1.565), `viewmodelRotation` (74.2, 9.9, -26.5).
- The knife comes up out of the **top of the forearm's end at its inner edge**, like a fist gripping it. The forearm reaches forward from the lower right, 60° off the knife (a hammer grip). The guard and ~40% of the handle show; the pommel half is inside the forearm.
- Measured: **nothing of the handle outside the fist in any frame** of both slashes and the heavy (0.000 studs).
- Tried and dropped on the way:
  - the forearm in line with the knife (reads as "facing the sky");
  - the knife just past the forearm's end with the whole handle showing (a long handle balanced on a stub);
  - the handle lying over the forearm's face (his "overlap... unprofessional").
- Free forearm moved left and down.
- `MELEE_HAND`, `MELEE_WRIST_BEND` 20 (45 let the handle slide out onto the forearm mid-swing), `MELEE_WRIST_PIVOT`, `MELEE_SHOULDER`.

**Moves** (`tools/studio/knife_fp_keys.py`; keys from the clip's measured fist and tip positions, the forearm's roll solved so the arm comes from below):
- **Slashes:** the blade lies over and trails as in the clip. Forehand contact: tip up-right of the fist, forearm from the bottom centre (capture `pass2_forehand_contact`, the clip's 4.75 s frame). Backhand loads with the blade out left, then trails up-left.
- **Heavy:** one flowing move with no dead hold. Dip, down and back into the cock while still moving, a ~50 ms thrust (contact at 0.42 of 0.9 s), carried on, roll back up, settle.
- **Inspect (3.4 s):** face to you (past and settle), a dip and flick, **the knife tossed and flipped end over end in the air, caught** with a dip, laid over to the other side, back.
- **Cut-ins:** a move that cuts into another (a slash right after a heavy) now blends from where the knife was over `TRACK_BLEND` 0.09 s instead of snapping (a light inertialization, research).
- Every key is checked: forearm on screen between -30° and -125° (from below), no step over 120°, eye clearance ≥ 0.5.

**Grades** (self): hold 8.5 (matches the overlay's targets; the handle is longer than RIVALS', so less of it shows); slashes 8.5; heavy 8; inspect 8; pull-out 8.

**Owner's verdict on pass 2 (2026-11-14):** "starting to look a lot better... I think you understand what I'm aiming for".
- **Good:** the slashes ("really good, honestly") and the pull-out.
- **Still to fix:**
  - the motion overall is "a little blocky";
  - the inspect "weirds me out, especially on the second turn of the hand... too blocky and staged".
- **Next:** continued in a Fable session from [Handoff - Feel Polish (Fable)](../Handoff%20-%20Feel%20Polish%20%28Fable%29.md).

## 5. Test list for the owner
1. **Save nothing needed.** All of this is code and config through Rojo (a running Play doesn't reload: stop and start Play after a sync).
2. Knife hold (pass 2): the forearm reaching forward, the knife coming up out of the top of the fist at its inner edge, ~18° lean. Compare with your overlay.
3. Click fast for slash 1-2-3: coil, snap, brake, settle. Does it have oomph? Is the camera lead (1.6°) too much or too little?
4. Right-click the heavy: two fists in, point on the crosshair.
5. Switch to the knife: toss, flip, catch. Too slow at 0.75 s?
6. Inspect the knife: face, toss-flip-catch, laid over the other side.
7. Fire each class: pistol snap and home, Sheriff flip, rifle / SMG sprays, Operator. The camera moves less now: say if you miss the old screen punch.
8. Sheriff inspect: cylinder roll on the first frame, with the sound.

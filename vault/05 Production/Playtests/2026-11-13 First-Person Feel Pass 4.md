# First-person feel pass 4: reload, draw, inspect, run, spray (2026-11-13)

Lane B of [Handoff - Grades to 9-10](../Handoff%20-%20Grades%20to%209-10.md). Goal: the first-person gun feel from its grades in [Third Person Overhaul](../../01%20Design/Third%20Person%20Overhaul.md) §14 (reload / draw / inspect 6.5, hold / sway / bob 7, fire kick 7) toward 9-10, measured in the engine. Earlier passes: [Pass 3](2026-11-12%20Gunplay%20Feel%20Pass%203.md), [Pass 2](2026-11-10%20Gunplay%20Feel%20Pass%202.md).

## Method
- **Engine:** the match place (133387545285290), Studio Play, driven with Workspace `DevAction` (draw / reload / inspect / fire), `DevHold` (spray) and W/S held through the MCP for running. A per-frame recorder (debug only, not in the repo) sampled the viewmodel `Root` / `Handle` part in camera space every render frame at 60 fps. It logged position and rotation from rest, the biggest change in one frame, the peak, and when it settled (inside 3% of the peak). Key frames were captured frozen with `VfxTimeScale = 0`.
- **References:** frame bursts with the Video Analyzer ([tool note](../../04%20Tech/Video%20Analyzer.md)).
  - RIVALS weapon showcase `youtube.com/watch?v=vi6ANQkj9BE`: Assault Rifle 2:41-3:06 (reload 2:42.3-2:45.3 frame by frame, inspect 2:45.5-2:48).
  - Valorant all-weapons showcase `youtube.com/watch?v=Klua4RGrFKY`: Vandal 5:06-5:38 (empty reload 5:20.6-5:24.2 at 0.15 s steps, inspect 5:10-5:12).
  - No clean RIVALS run footage was found in the vault's gameplay videos (`U9XcolnRiXA` 3:00 is an RPG and a scythe), so the run was judged by measurement against the gait rule below.
- **LihFolk:**
  - *First-Person Viewmodels - Arms Rig, Sway and Camera Binding*.
  - *Springs Damping and Smoothing*: overshoot vs. damping, settle ≈ 4/(ζω).
  - *Squash Stretch and Anticipation*.
  - *Timing Spacing and Frame Charts*: anticipation 2-5 frames, the ease belongs to the leaving key.
  - *Gun Feel - Recoil*: keep the jitter under about 20% of the step.
  - *Procedural Gait and Footstep Planning*.

## What the references do
- **Reload:** RIVALS and Valorant both lift the gun **up and in**: the muzzle rises 15-50°, the gun rolls 25-40° and comes toward the centre so the mag swap is on screen. RIVALS snaps into that pose in about 4 frames (0.13 s), overshoots a little and settles about 0.1 s later. Valorant keeps the gun moving through every beat: it rises further for the rack, then drops back into the hold in about 0.3 s.
- **Inspect:** both raise the gun steeply (muzzle up to near vertical) and turn it to show each side.

## Findings before (measured)
| Item | Measured | Problem |
|---|---|---|
| Draw (Vandal, 0.9 s) | Up in 0.29 s; **0.3 s with no motion at all** (0.29-0.58) while the handle racked; eased into the hold with **no overshoot** (pitch 2.2 → 0.4°, one direction only) | Dead hold, no landing |
| Reload (Vandal, 2.5 s) | The gun went **down** (grip −0.15 studs), rolled 32°, pitched only 12-15°, then **held about 1.2 s** with ±0.04 stud bumps. Its "slap" key landed at **1.4 s**, but the Vandal's mag went in at 0.75 s | Wrong direction vs. the references, stale, beats out of sync |
| Reload, every gun | The gun clips' `MagIn` markers sit **mid-travel**: Vandal marker .302, mag seated at .454; Phantom .394 / .611; Classic .39 / .65. So the mag-in sound and the bump came up to 0.5 s before the mag reached the gun | Timing bug |
| Reload, swap on screen | The magwell sat about 0.75 studs below the eye and only 0.6 ahead, so it was **below the screen** for the whole swap | Can't see the reload |
| Inspect (2.8 s) | Snaps used Back easing, but there were **two ~0.9 s holds that only drifted** (≈10° in a second) and a return with no overshoot | Lifeless holds, flat landing |
| Run (rifle 20.9 and pistol 22 studs/s) | Step dips **0.20 s then 0.36 s apart** (a limp), uneven depth (rifle peaks 0.05 / 0.08) | The owner's "running seems a bit off" |
| Run, cause | The gun sits on the line x = 0.51 in camera space (grip z −0.35, muzzle z −2.47, pistol grip also x 0.51), but the bob turned around `MOTION_PIVOT` x = 0.2. So the sprint roll (±4.4°) lifted the whole gun on one step and dropped it on the next, which moved the dips | Pivot in the wrong place |
| Spray (Vandal, 25 rounds) | Every shot kicked the same 0.111-0.126 studs back in a fixed pattern; the first shot was no bigger. Smooth (≤3.3°/frame) | A steady buzz, no texture |

## Changes (`Config/Viewmodel` numbers, code in the files lane B owns)
1. **Tracks re-keyed** (`TRACKS.Draw`, `Equip`, `Inspect`, `Reload`, `ReloadEmpty`):
   - Each move starts with a small anticipation the other way.
   - It travels fast (Quad Out) to a pose past the target, then settles.
   - Holds keep moving: the yank on the handle pulls the gun toward the hand, and the inspect holds have a tilt-up "look".
   - Every move ends **past the hold** with one bounce.
   - Reload pose: muzzle up ~20°, rolled 35-40°, **raised and pushed out** (y +0.2, z −0.2 studs), so the mag swap is in view.
2. **Beat alignment** (`Track.marks` + `alignTrack` in ViewmodelController): each track says where its beats are (`MagOut`, `MagIn`, `Rack`; revolvers use `Open` / `Close`). Its keys are time-warped piecewise so those beats land on **that gun's** clip beats. One track now fits every gun's clip.
3. **Mag-in beat at seating** (`clipBeats`): the MagIn beat (sound and bump) moves to where the mag stops moving, if the marker is earlier.
4. **Draw bump at arrival** (`DRAW_BUMP_AT` 0.2): it used to fire while the gun was still below the screen.
5. **Run bob:**
   - `BOB_PIVOT` (0.51, −0.66, −0.8): the bob's pitch, yaw and roll turn around the gun's own line by the hand.
   - `BOB_RUN_SHIFT` 1: sprinting dips at the ends of the swing (mid-stance) instead of the middle.
   - `BOB_SPRINT` dip 0.024 → 0.03, giving back the height the old roll lift used to add.
6. **Spray texture:**
   - `SPRAY_FIRST` 1.4: the first shot of an **automatic** burst kicks harder, easing to 1× over `SPRAY_FIRST_SHOTS` 3.
   - `SHOT_VARY` ±0.18: each shot's back and rise vary.
   - `SPRAY_GAP` 0.3 s starts a new burst. Taps on semi-auto guns are unchanged.

## Measured after
| Item | After |
|---|---|
| Draw (Vandal) | Lands at 0.18 s, 0.03 studs past the rack pose, then settles. Yank: 7° of motion in the former dead hold. Release: muzzle snaps up 15° at 0.58 s. Drops past the hold (pitch −4.4°, −0.036 studs), bounces +1.3° and is settled at **0.88 s** (was 0.97, with no overshoot) |
| Reload (Vandal) | Anticipation −2° pitch / +1.8° roll (0-0.07 s). Tilts in **0.13 s** to 21-23° muzzle up and 37-40° roll. Jolt to 29° on mag-out. Brace, then the **slap at 1.13 s on the seated mag** (+8° pitch, +11° roll in under 0.07 s). Rack kick 17° at 2.15 s. Home 3.7° past the hold; settled at **2.47 s**. Frozen frames show the empty magwell and the new mag going in on screen, left hand on it |
| Reload (Classic) | Same shape; slap at 1.13 s on its seated mag, slide-rack kick at 1.6 s, settled at 1.85 s |
| Inspect (Vandal) | Wind-up −6.7° yaw. Snap past the right side (69.6° → settles 56°). Tilt-up look in each hold (left side: roll swings 24°). Wind-up before the whip (largest change 13°/frame, was 17°). Home **3° past the hold**, settled at 2.75 s. Left-side frame: reads cleanly, no clipping |
| Run (Vandal 20.9 studs/s) | Dips **0.28 / 0.30 / 0.30 s** apart, depths within 0.006 studs of each other. 0.081 studs top to bottom. Swing unchanged: 0.22 studs, 6° yaw, 8.4° roll |
| Run (Classic 22 studs/s) | Dips 0.28 / 0.29 s apart (−0.027 / −0.033, before the 0.03 dip tweak). Frozen frame: pistol canted in, free hand swinging low left |
| Spray (Vandal, full mag) | First shots 0.138 / 0.144 studs back vs. steady ~0.12; steady shots vary 0.109-0.136 (±12%). Climb 7 → 10°. Still smooth: ≤2.6°/frame inside the spray, no pops. Settles before the auto-reload starts |

## Grades (honest)
| Item | Before | Now | Evidence | What blocks 9+ |
|---|---|---|---|---|
| Reload / draw / inspect | 6.5 | **8.5** | Anticipation, a fast move, overshoot and settle measured on every move. Beats line up with the gun's real mag and rack. The swap is on screen, as in RIVALS and Valorant | Only the Vandal and Classic were measured. Not looked at in motion by a person. The shell-by-shell shotguns, Sheriff (Open / Close stand-ins), Outlaw, Odin and Ares belt boxes were not checked |
| Gun hold / sway / bob | 7 | **8.5** | The limp is gone: even dips, equal depth, rifle and pistol | No side-by-side with RIVALS run footage. The bob runs on time while footsteps run on distance, so dips and footstep sounds may drift apart. Not seen by the owner |
| Fire kick / recoil | 7 | **8** | The first shot reads bigger, shots vary, still smooth | Seen only as numbers. The owner still hasn't sprayed by hand |
| ADS | 7.5 | 7.5 | Unchanged this pass | — |

## Not verified
- Every gun but the Vandal and Classic. Especially the Sheriff, where the MagIn mark stands in for `Close`, so the rack part of the track is squeezed into the end; the shell-loop guns, which use `playClip`, not the track; and the Odin / Ares.
- Watching it in real time: only per-frame numbers and frozen frames. MCP key input only.
- The owner's view and another player's view.
- **Sound timing moved:** the MagIn clack now plays where the mag seats (0.15-0.25 s later than before on most guns). Lane C (sound) should listen to it.
- Studio dropped to ~15 fps for a few minutes once (other sessions); every number above is from a 60 fps run.

## What to test (owner)
1. Vandal: R with a part-used mag, then empty. Does the slap land with the clack, and is the swap readable?
2. Draw (swap guns): does it land and bounce, or is it too much?
3. Y inspect, start to end.
4. Sprint in a straight line with the Vandal and the Classic: is the "off" feeling gone?
5. Spray a full Vandal mag at a wall.
6. Sheriff and Outlaw reloads (not checked).

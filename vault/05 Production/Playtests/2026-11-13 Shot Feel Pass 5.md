# Shot feel pass 5: making shooting more satisfying (2026-11-13)

Lane B, second task. The owner (morning of 2026-11-13): gunplay should be "a little more satisfying. But we're really getting there, and it's good." Sounds are out of scope (the owner is buying a pack). Hit markers, the hit flash and the crosshair belong to the hit-feedback session and were not touched. Follows [First-Person Feel Pass 4](2026-11-13%20First-Person%20Feel%20Pass%204.md).

## Method
- **Engine:** the match place in Studio Play. A per-frame recorder (debug only) logged two things every render frame from each shot until well after the last: the viewmodel `Root` relative to the camera, and the camera's own pitch and FOV.
  - **Taps:** one `DevAction fire`, hip and aimed (`DevAim`).
  - **Sprays:** `DevHold` for 1.5 s.
  - **Per class:** Vandal, Guardian (rifle), Spectre (SMG), Odin (machine gun), Classic and Sheriff (sidearm), Judge and Bucky (shotgun), Marshal and Operator (sniper).
- **Aimed sight:** the gun's `AimPoint` was projected to the screen every frame to measure how far the sight leaves the crosshair.
- **References** (Video Analyzer, frame by frame):
  - **Valorant** Vandal taps, `youtube.com/watch?v=Klua4RGrFKY` 5:15.25-5:15.6 at 60 fps. The flash is on the shot frame and lasts about 4 frames (67 ms). The view jumps about 1° on the shot frame and is back within ~150 ms. The gun's kick is small and over in ~5 frames.
  - **RIVALS** Assault Rifle hip fire, `youtube.com/watch?v=vi6ANQkj9BE` 2:49.5-2:52.5. Each shot drives the gun back with the muzzle tipping up and right. The flash is small, and the camera barely moves at the hip.

## Findings before
| Gun (hip tap) | Gun back / pitch | Gun peak | Camera up | **Camera peak** | Camera settled |
|---|---|---|---|---|---|
| Vandal | 0.16 studs / 7.9° | 34 ms | 0.42° | **68-117 ms** | 218 ms |
| Spectre | 0.10 / 4.4° | 36 ms | 0.22° | 102 ms | 151 ms |
| Odin | 0.15 / 5.1° | 34 ms | 0.30° | 117 ms | 201 ms |
| Classic | 0.14 / 11.7° | 35 ms | 0.55° | 101 ms | 234 ms |
| Sheriff | 0.21 / 16.6° | 53 ms | 1.81° | 119 ms | 419 ms |
| Judge | 0.21 / 12.5° | 33 ms | 1.60° | 83 ms | 399 ms |
| Bucky | 0.29 / 18.1° | 34 ms | 3.02° | 100 ms | 516 ms |
| Guardian | 0.16 / 8.8° | 33 ms | 1.19° | 116 ms | 333 ms |
| Marshal | 0.21 / 12.6° | 35 ms | 2.48° | 116 ms | 466 ms |
| Operator | 0.33 / 19.7° | 33 ms | 4.95° | 117 ms | 650 ms |

1. **The screen's thump came late.** On every gun the camera kick peaked 83-119 ms after the shot: it was eased in at 45/s. The gun's punch peaked at 34 ms, and Valorant's view jumps on the shot frame. So the shot and the screen jolt felt detached: "soft".
2. **Aimed shots barely moved the gun.** The aimed kick was 0.05 studs × the camera's `recoil.up`, halved again while aimed. An aimed Vandal shot moved the gun 0.014 studs and 0.8° (at the hip: 0.16 and 8°). An aimed spray showed no shot pulses at all.
3. **A sticky finish after a burst.** The climb spring was critically damped at 70 and eased off at 7/s. After a 1.5 s spray the gun took 0.43 s (Vandal) and 0.67 s (Odin) to come home, with no settle.
4. **Spray rhythm and smoothness were fine:** per-shot peaks were clear, there were no pops (≤2.8°/frame), and the pass 4 first-shot slam and per-shot variety were in.
5. **Flash and tracer read:** frozen on the second frame of a Vandal shot, there is a white-gold star at the muzzle and a casing in the air. That's about the same share of the screen as Valorant's flash. Left as is.
6. **Reloads I hadn't checked:**
   - **Sheriff:** its own clip flips the revolver ~50° and snaps it back. My pass 4 reload tilt stacked on top, giving ~100° of turn in 0.3 s and up to **19.7° per frame**.
   - **Bucky and Marshal (shell by shell):** one pose held ~0.9 s with ±1°, then a snap home with no landing.
   - **Judge, Outlaw, Odin and Ares:** smooth (≤13°/frame), each lands past the hold and settles.

## Changes
- **Camera kick goes in fast:** `Juice.SHOT_FEEL.kickApplyRate` is 120/s (was a hard-coded 45 in CameraController), so 95% of each kick is in within ~25 ms. This is the aim recoil itself, only applied sooner; its size and recovery are unchanged.
- **View punch, look only:**
  - A new `CameraController.viewPunch(degrees, time)`. The view jolts up within 18 ms, comes back over `time` and dips ~9% past level before settling.
  - It is applied and taken back every frame (like the shake), so it never moves the aim.
  - Sized per class in `Juice.SHOT_FEEL.viewPunch`: SMG 0.22°, rifle 0.4°, machine gun 0.35°, sidearm 0.55°, shotgun 1.3°, sniper 1.6°. Per gun in `viewPunchGun`: Sheriff 1.1°, Shorty 1°, Guardian 0.8°, Ghost 0.4°, Spectre 0.18°.
  - It scales by `adsScale` while aimed and by the shot's size (first-shot slam, variety).
  - A punch that lands while the last one is still going rises from where that one is, so an automatic never dips between shots.
  - Called from `ViewmodelController.fire`.
- **Aimed kick per class** (`Viewmodel.ADS_PUNCH`, `ADS_PUNCH_GUN`; it replaces `ADS_KICK_BACK` / `ADS_KICK_ROTATE`):
  - Back toward the eye: SMG 0.035, rifle 0.05, machine gun 0.055, sidearm 0.06, shotgun 0.11 studs.
  - A small rise (0.4-2.5°), so the sight stays on target.
  - No longer tied to the camera recoil or halved.
- **Burst release:** `CLIMB_STIFFNESS` 70 → 400, `CLIMB_DAMPING_RATIO` 0.6. The climb lets go at once when the shooting stops (after 0.12 s, or 1.25 fire intervals for slow guns like the Judge).
- **Sheriff reload:** `RELOAD_TRACK_TURN.Sheriff` 0.3: it takes 30% of the reload track's turn, and its own clip does the rest.
- **Shell-by-shell reloads:**
  - `HANDLE_BUMPS.ShellIn` is bigger (pitch −4.5°, was −2), so each shell push jolts the gun.
  - A new `Settle` bump at 75% of `ReloadEnd` lands the gun past the hold with a bounce.
- **Cleanup:** removed `Juice.HIT_FLASH` (no readers left; the hit-feedback session moved it to `Config/HitFx`).

## Measured after
| Gun (hip tap) | Camera up | **Camera peak** | Camera settled | Gun back / pitch |
|---|---|---|---|---|
| Vandal | 0.76-0.85° | **13-17 ms** | 215-218 ms | 0.16-0.17 / 7.7-8.4° |
| Spectre | 0.49° | 18 ms | 149 ms | 0.09 / 4.0° |
| Odin | 0.73° | 17 ms | 199 ms | 0.18 / 5.8° |
| Classic | 1.03° | 16 ms | 234 ms | 0.13 / 10.8° |
| Sheriff | 2.72° | 17 ms | 416 ms | 0.21 / 16.4° |
| Judge | 3.09° | 16 ms | 400 ms | 0.22 / 13.1° |
| Bucky | 4.35° | 18 ms | 516 ms | 0.31 / 19.0° |
| Guardian | 1.92° | 19 ms | 333 ms | 0.18 / 9.6° |
| Marshal | 3.81° | 17 ms | 468 ms | 0.22 / 13.1° |
| Operator | 6.34° | 18 ms | 650 ms | 0.34 / 19.6° |

| Item | Before | After |
|---|---|---|
| Gun home after a 1.5 s spray | Vandal 433 ms, Odin 668 ms; no settle | **Vandal 149 ms (0.4° past rest), Odin 169 ms (1.1° past rest)**. The Spectre is home by ~0.25 s; a 0.5° turn sway stays while the camera's sideways recoil recovers, which is correct |
| Aimed Vandal tap | 0.014 studs / 0.8° | **0.058 studs / 1.2°**; the sight moves at most 9 px of 964 |
| Aimed Vandal spray | no shot pulses | a pulse per shot, 0.042-0.062 studs |
| Aimed Sheriff | 0.052 studs | 0.114 studs; the sight lifts 43 px and is back within ~0.25 s, mostly the revolver's own Fire clip (aimed rise trimmed 2.2 → 1.2°, which saved 7 px) |
| Aimed Spectre / Guardian sight | — | 5 px / 12 px |
| Sheriff reload | 19.7°/frame | **8.2°/frame**; lands past the hold, settled at 2.2 s |
| Bucky shell reload | ±1° held, snapped home | **±3° jolt per shell**, lands 3° past the hold, settles by 1.67 s |
| Spray smoothness | ≤2.8°/frame | ≤2.8°/frame (unchanged) |
| Script errors | — | none in Output |

## Grades (honest)
| Item | Before | Now | Evidence | What blocks 9+ |
|---|---|---|---|---|
| Fire kick / shot feel | 8 | **8.5** | The screen jolts with the shot (13-19 ms, matching the Valorant frame study), sized per class; a burst finishes in ~0.15 s with a small settle | Only seen as numbers and frozen frames, not in real time. The owner hasn't fired it. The view punch sizes are first picks |
| ADS | 7.5 | **8.5** | Aimed shots push the gun ~4x more and the screen thumps, while the sight stays within 5-12 px on rifles and SMGs | The Sheriff's 43 px flip (its clip). Scoped guns hide the gun, so only their camera changed |
| Reload / draw / inspect | 8.5 | **8.5** | Every class now measured: the Sheriff is fixed, the shell loops have life, and the Judge, Outlaw, Odin and Ares are smooth and land | Not seen by the owner |
| Muzzle flash / tracer | not graded | **8** | Reads on the shot frame, about Valorant's share of the screen | Aimed, the flash is mostly behind the front post; Valorant shows more flash around the sight. No change made (a taste call for the owner) |

## Not verified / for others
- Real-time feel: MCP input only, no person fired it. The camera view punch can't be seen in a frozen frame; it's measured only.
- Landing hits from the shooter's side (markers, flash, crosshair) belong to the hit-feedback session. The view punch is per shot, not per hit.
- Guns not measured one by one: Phantom, Bulldog, Stinger, Ghost, Shorty, Outlaw (fire) and Ares (fire). They share their class tables.
- Sound timing is untouched (owner's call).

## What to test (owner)
1. Tap and spray the Vandal at a wall, hip and aimed. Does the screen jolt with the shot, and does the gun drop home cleanly after the burst?
2. Sheriff aimed: is the flip right or too much?
3. Bucky and Marshal: reload two shells.
4. Operator unscoped shot: is the 1.6° view punch too much?

## Follow-up: Outlaw reload, left hand into the screen (2026-11-13, owner)
The owner played it: "it's looking pretty good". One fix: "the Outlaw reload animation looks really weird. Like the left hand goes into the screen."

**Found (measured).** I recorded the closest distance from the camera to each arm block every frame.
- **Outlaw:** the camera was **inside the left arm block** at 1.07-1.17 s of the one-round reload, and twice in the empty reload (once per round).
- **Why the hand came so close:** the Outlaw's round joint does both trips. The spent case is pulled out to a turnaround ~1.3 studs up and back from the opened breech (toward the face), and the fresh round comes back from there. The loading hand met the round at that turnaround. On the shared reload track the breech also sat only 0.49 studs in front of the eye.
- **Why the eye check didn't catch it:** the arm's follow spring runs after the eye-clearance bend in `holdWith` and carried the arm back over it (40% of its direction toward the camera).
- **Frames:** at 0.98 s the left arm filled the left half of the screen; at 1.12 s, after the first attempt below, a block crossed the crosshair.

**Fixed:**
1. **`TRACKS.ReloadOutlaw`**, the Outlaw's own reload track, picked by gun id for both reloads (`ViewmodelController.reload`). The gun goes out and down while it's open (z −0.48, y −0.17), flicks up as it snaps shut (on the clip's Close) and lands past the hold.
2. **`CARRY_JOIN.Outlaw` 0.75.** The fresh round stays hidden for the first three quarters of its trip back. The hand picks it up by the breech instead of out at the turnaround (`carryTiming`). 0.55 still drew the arm to the crosshair for the second round.
3. **A last eye guard in `holdWith`, after the follow spring.** If an arm block's line passes within `ARM_EYE_CLEARANCE`, it turns down and out with nothing back toward the camera, blended in by how close it gets. It's a safety net for every gun.
4. Tried and dropped: giving the Outlaw 30% of the shared track's turn (`RELOAD_TRACK_TURN`). It didn't help.

**Measured after:**

| Reload | Left arm to eye (min) | Hand depth (min) | Highest hand on screen | Smoothness |
|---|---|---|---|---|
| Outlaw, 1 round | **1.67 studs** (was 0, inside) | 1.78 (was 0.49) | 59% down | arm ≤4.5°/frame, gun ≤7.7° |
| Outlaw, empty | **1.20** (was 0, twice) | 1.58 | 53% down | ≤3.7° / ≤4.7° |
| Outlaw draw / inspect | 1.87 / 1.37 | 1.36 / 1.77 | 56% / 65% | — |
| Marshal | 1.55 | 1.71 | 63% | ≤2.6° / ≤3.3° |
| Operator | 1.03 | 1.16 | 52% | ≤4.7° / ≤6.0° |
| Bucky | 0.87 | 1.19 | 48% | ≤6.2° / ≤10.3° |
| Judge | 1.61 | 1.79 | 45% | ≤6.7° / ≤8.4° |
| Sheriff | 0.66 | 0.94 | 51% | ≤6.7° / ≤8.5° |
| Vandal / Classic | 0.64 / 0.77 | 0.92 / 0.94 | 51% / 77% | — |

For comparison, the right hand's normal hold is 0.65-0.98 studs from the eye. Frames at 0.7 s and 1.36 s of the empty Outlaw reload: the gun sits out and low on the right with its barrels open, the left arm reaches in low from the left, and the top ~60% of the view is clear.

**Rojo was down.** During this fix `rojo serve` was not running (nothing on port 34872), so Studio stopped picking up file changes. I pushed my two changed files into Studio's copies by exact hunks (checked: Studio's lengths equal the files'). Other sessions' file changes made while Rojo was down may not be in Studio. Restart `rojo serve` and click Connect in the Rojo plugin.

**Not verified:** watched in real time (frozen frames and per-frame numbers only); the owner's re-check.

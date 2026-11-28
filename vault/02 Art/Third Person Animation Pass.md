# Third Person Animation Pass (2026-11-28)

Owner: the third-person animations (what other players see) "look boring and blocky", and the upper body / gun hold "sometimes resets to its start randomly and looks glitchy". The slide is good and stays. Pipeline and history: [Third Person Overhaul](../01%20Design/Third%20Person%20Overhaul.md) (clips keyed in `tools/anim/tp_clips.py`, played by `shared/Simulation/Poses`). Taste: animation-oomph (coil, snap, brake, overshoot, settle), third-person-body-taste.

**State:** built, measured and committed on `main` (not pushed). Waiting on the owner's OK of the captures.

## 1. The random restart (bug, fixed)

**Seen (measured, bot match, 42 s):** on the server and on a watching client, the run's gun-holding upper body (`Sprint`, `SprintPistol`) and the leg clips jumped back to time ~0 together in the middle of a stride, 19 times. Up to 0.6 of a cycle at full weight: the gun swing visibly restarted.

**Cause:** `Poses.inStep` kept the leg clips in step by making every clip follow the phase of the *heaviest* playing one. A clip that had just started plays from time 0, and as it faded in it often became the heaviest. Every other leg clip, and the Sprint arms (synced to `SprintRun`), then snapped back to its phase near 0. Replication was not the cause: a probe showed server `AdjustSpeed` and `TimePosition` writes arrive on watchers smoothly.

**Fix (`Simulation/Poses`):** one **stride clock** per Animator and leg set (`gait`, `crouch`): a phase (0..1, right foot lands at 0) moved on at the cycle rate. Every leg clip, the Sprint arms, the unarmed swings and the new holds on the move follow the clock. A clip under `STRIDE_CLOCK.setBelowWeight` (0.25) is set straight onto the phase, which isn't visible at that weight. A heavier one is pulled in by speed (`pull` 3) and snapped only past `snap` (0.3 cycles). Found while checking the new pass and fixed:
- crouching or standing up hands the phase from one clock to the other (the move layer jumped half a cycle when the bot crouched mid-walk);
- a fresh clock seeds its phase from the arms too, not only the legs, and SlideOut's footfall line-up skips a clock with no stride yet (both could start a clock at phase 0);
- **flinch stutter:** a stream of hits (an SMG, a burn) restarted the 0.8-weight flinch every 0.25 s (16 times in 4 s). Now a hit only restarts it after `FLINCH_RETRIGGER` (0.7) of the clip.

**Measured after (Studio bot match, `ServerRole = "Match"`):** 175 s + 132 s of live rounds (over 5 minutes) with **0** leg or upper-body back-jumps at weight on the server, and the watching client the same. Flinch restarts: 0. Peak tracks per bot 12-13 (limit 16). The slide in and out played normally. The client logs one recurring event: `Util/BodyRecoil`'s recoil pose track restarting. That track is a still pose, so a restart can't be seen.

## 2. What changed in the clips (`tools/anim/tp_clips.py`, uploaded as `GG <Name> t1`)

| Clip | Before | After |
|---|---|---|
| Holds (Aim / Ads / PistolAim / PistolAds × up, level, down; KnifeReady) | breath 0.7° chest, 0.25° sway, 0.012 gun rise: unreadable from another player | `BREATH` 1.6° / 0.7° / 0.03 studs; sights at `BREATH_ADS` 0.55 so the aim stays readable |
| **AimMove, PistolAimMove, KnifeMove** (new, Action) | moving, the hold rode the pelvis rigidly: every hip twist and roll turned chest, arms and gun as one block | `stride_hold`: the chest counter-turns (3.2°) and counter-rolls (2.2°) against the hips, dips 1.8° a beat after each footfall (`MOVE_LAG` 0.05 cycles), the gun lags another beat (0.12): bob 0.045, sway 0.03, yaw 1.6°, roll 3°; the head counters the chest so the eyes stay level |
| Idle (Core, whole body) | hips swayed 0.025 studs, 0.6° roll | a weight shift foot to foot (tanh-shaped: lingers on each foot, crosses quickly): `IDLE_SHIFT` 0.07, pelvis tilt `IDLE_ROLL` 3° down over the free leg, a late turn `IDLE_TURN` 3°, a dip as it crosses `IDLE_DIP` 0.02, breath at the hips. Armed, the hold rides the pelvis, so the gun tilts with it |
| Crouch (idle) | one still pose | breathes and rocks between the feet with a late turn (2.4 s), sat 0.05 higher (the old pose's right knee sat at the floor) |
| Walk ×8 | bob 0.05 / 0.04, roll 3 | bob 0.085 forward / 0.07 back and side, roll 4.5 / 4, twist 6 / 4, lift 0.34 |
| Crouch walk ×8 | bob 0.04, roll 2.5 | bob 0.065 (side 0.06), roll 4, twist 4 |
| Jump | started already extended | starts on a squash (hips -0.34, both feet under the body) and springs to full extension in 3 frames; the press is the jump, so the squash is the push. Faster knee drive, a tighter tuck that overshoots the apex pose, then the reach |
| Land | came back up to -0.03 | overshoots up to straight legs (0, 4° back) before settling into the idle |
| Slide, SlideIn, SlideOut (all kinds), run, sprint | — | **unchanged** (keyframe text byte-identical, checked by hash) |

**Poses:** the move layers take the level hip hold's share by `moving` while on foot (walking, running, crouch-walking; 0 in the air and in a slide), on the gait clock or the crouch clock (`MOVE_OF`, `MOVE_SET`, `FADE.move` 0.15). Sights keep the still holds. `Config/Animations RECOIL` maps AimMove / PistolAimMove to the level kick, so body recoil still shows while walking. Sprint keeps its own Action2 upper body over all of it.

## 3. Measured on the rig (`tp_check`, `tp_measure`)

- Walk lock 95.3-99.8% (was 92.4-99.8: back walk improved 92.4 → 95.3), floor sink ≤ 0.001, shins ≥ 0.99 apart. Crouch walk 94.4-99.9%, sink 0.
- Idle sink 0.054 (old 0.041; a bigger sideways shift dug a shin corner up to 0.11: the block leg has no ankle, so the shift was traded for more pelvis tilt). Crouch knee 0.001.
- `tp_measure`: every changed loop's seam passes, plant / rate pass, worst acceleration 67-79 studs/s² on the move layers (pop line 900), Jump 643, Land 613.

## 4. Captures (local only, `art-source/animations/review/tp-pass-2026-11-28/`, gitignored)

`idle_before_after.mp4`, `walk_before_after.mp4`, `crouch_before_after.mp4`, `jump_before_after.mp4`: each shows the old clips (BEFORE) then the new (AFTER) on the same body and camera. Made with `tools/studio/TpShowcase.luau`: client-only copies of a bot body in a bot match, a Vandal, four lanes in the sky. The Workspace attributes `TpShowcaseFocus` / `TpShowcaseOffset` / `TpShowcaseOld` pick the camera and the clip set. The copies have no GripController, so the support hand sits under the handguard instead of on the grip.

## 5. Not verified / open

- **The owner's eye** on the new idle, walk, crouch and jump: the change is clear in motion but subtle in stills at a distance.
- Two real players (a Local Server with 2 clients). The bot (server-posed) and the watcher agree, and players run the same Poses code on their own client.
- The move layers' counter-twist is tuned for forward walking; in strafes and backpedals (whose hips don't twist) it reads as a shoulder swing.
- `art-source/uploads.json` holds the 36 new upload records but is not committed: another session has uncommitted entries in it.

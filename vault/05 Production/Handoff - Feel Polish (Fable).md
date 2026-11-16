# Handoff: feel polish, knife → guns → Sheriff → Bat → hits (2026-11-14)

**For:** the Fable session that carries the first-person feel work forward.
**From:** the session that ran the "gun and knife feel from videos" passes. Its full record is [2026-11-14 Gun and Knife Feel from Videos](Playtests/2026-11-14%20Gun%20and%20Knife%20Feel%20from%20Videos.md). Read §1 (what the clips show, in numbers), §4b (the knife now) and the owner's verdict there first.
**Owner's words (2026-11-14):** "It's starting to look a lot better. I think you understand really what I'm aiming for." Slashes "really good, honestly", the pull-out "pretty good". Still: "the animations seem a little blocky", and the inspect "weirds me out, especially on the second turn of the hand... too blocky and staged". Then: "continue working on everything like the feel of the guns, polishing up the knife, polishing up the Sheriff... leading to polishing up the bat with our new ideas, and then moving on to the headshot, the crosshair animations, the head flare animation looking better."

---

## 0. Before you touch anything
1. **CLAUDE.md rules apply:**
   - Load the `gauntlet-vault` skill, then LihFolk for the job: `08 Animation`, `47 Game Feel and Juice`, `lihfolk-vfx` for flares and markers, `roblox-ui-builder` / `gauntlet-ui-style` for crosshair UI.
   - Plan in the vault before building; write results with captures and grades in `05 Production/Playtests/`.
   - Keep `stylua`, `selene` and `rojo build` clean. `--!strict`. Numbers live in Config.
2. **Commit nothing unless the owner asks.** When asked: stage exact paths only, never `git add vault` or `-A` (third-party screenshots live in the vault, and the repo is public).
3. **Lanes:** this work spans fp-feel (viewmodel), gunplay (camera) and hit-feedback (markers, crosshair, FX). The owner asked one session to carry it, so you own all three now. Read lane F's [Hit Feedback Pass](Playtests/2026-11-13%20Hit%20Feedback%20Pass.md) by section before changing its files.
4. **Read lean:** grep, then ranged reads; `vault-lookup` for facts. Never open `ViewmodelController`, `WeaponController` or `Config/Viewmodel` whole: they run 2,600 / 1,400 / 1,900 lines.

## 0b. Your first steps, in this order (the owner asked for this)
1. **Read** this note, then the results note's §1, §4b and the owner's verdict (grep and ranged reads only).
   **Then read [Animation Flow and Feel Research](../03%20Research/Animation%20Flow%20and%20Feel%20Research%20%282026-11-14%29.md) in full.** The owner had it done before handing over. It has:
   - §1: why RIVALS' inspect isn't staged, frame by frame;
   - §2-5: LihFolk and published sources on flow, springs, inertialization, first-person craft, melee, guns and hits;
   - §6: looks good / looks bad;
   - **§7: the checklist to apply before every animation change.**
2. **Watch every clip yourself** (§2 lists them), all seven, start to finish, at 60 fps where it matters: the knife, then the six guns, then the hits clip. Use `get_frame_burst` on every event (shot, spray, pull-out, reload, inspect, slash, heavy, hit, headshot). The previous session's numbers are in the results note §1. Check them, fill the gaps it lists (the sniper scoped shot, revolver ADS, single-tap recovery), and look closely at what the owner is unhappy with: the knife inspect (12.3-16.6 s), the revolver inspect (10.1-14.6 s) and the headshot flare. **Write what you find** into a new playtest note (plan section) before building.
3. **Ask the owner your questions before building.** Use the question tool, a few at a time, each with a recommended option and a one-line reason. Start from this list, add your own from the clips, and drop any the vault already answers:
   - **Knife "give":** after a strike or a catch, how much settle should the knife have? Barely there (a crisp stop), a small bounce (recommended: kills "blocky" without looking rubbery), or a clear wobble?
   - **Knife inspect, the second half:** a toss and spin in the screen's plane like the pull-out, one smooth wrist roll that flows out of the catch, or a flip-catch then a roll? Faster or slower than now (3.4 s; the clip's is ~4.3 s)?
   - **Camera on knife swings:** keep the small lead roll (1.6°), stronger, or none?
   - **Gun camera:** the clips keep the camera still and put the kick in the gun, so we halved the FOV, roll and shake. Does he miss the old screen punch on any class (sniper, shotgun, Sheriff)?
   - **Pull-outs per gun type:** match the clips (pistol up from bottom right tipped ~45°; rifle from bottom left rolled ~60°; SMG straight up; revolver no spin on the draw)? Any gun that should do a flourish?
   - **Sheriff:** a twirl in the inspect like the clip (~300 ms a turn, done as a toss), and a speedloader reload with a flick-closed snap?
   - **The Bat:** what are "our new ideas" for it? Offer: a rigid fist and wrist, smooth coil-and-snap swings, a toss-catch inspect, the camera leading swings.
   - **Headshot flare:** the clip's fan of rays from the head (~270 ms, white to orange) instead of our radial burst? How big, and does it scale with range? *(Done 2026-11-15: a faceted crown burst, [2026-11-15 Gunplay Feel RIVALS](Playtests/2026-11-15%20Gunplay%20Feel%20RIVALS.md).)*
   - **Crosshair:** a bloom while firing (clip ~+5 px), the hit wedges closing in, a distinct headshot and kill look?
   - **Damage numbers:** one number per target that adds up and tips over when the stream ends (clip), or per-hit pops (ours)?
4. **Then the queue in §5,** plan first, one area at a time; show the owner each before moving on.

## 1. The owner's taste (hard-won; don't relitigate)
- **Block arms, no fingers** (memory `viewmodel-arms-style`). The knife never slides or turns *inside* a closed fist. It **may** leave the hand naturally: a toss, a flip in the air, a catch.
- **Animation must have oomph and character, never linear or stale** (memory `animation-oomph`):
  - a tell, a held wind-up (the coil), a very short strike (~60-70 ms), a follow-through that brakes over 1.5-2.5x the strike, an overshoot past the hold, a settle;
  - holds must keep living (drift, breath); a pose that just sits reads "staged".
- **The hold** (his overlay "Knife hold alignment", now in config):
  - the forearm reaches forward from the lower right, ~60° off the knife;
  - the knife comes up out of the top of the forearm's end at its inner edge;
  - the guard and ~40% of the handle show, the pommel half is inside;
  - blade ~18° off vertical.
- **Rejected, don't bring back:**
  - the forearm in line with the knife ("my hand facing the sky");
  - the handle lying over the forearm's face ("overlaps... unprofessional");
  - the whole handle showing past the forearm's end;
  - blade upright through a slash;
  - pauses mid-move ("a hesitation").
- **Guns:** Valorant / RIVALS punch. In every one of his clips the camera stays still and the gun takes the kick: a 1-frame snap, then an ease home. Gun audio is real recordings (memory `gun-audio-real-recordings`). Gun VFX are stylised Valorant, never photoreal (memory `gun-vfx-valorant-style`).
- **UI:** "Soft Edge", no pills, Sarpanch + Titillium (skill `gauntlet-ui-style`).
- **He watches the Studio playtest live** and often plays in it while you work. Say when you're about to drive it. **Clear every tuning attribute you set**: `VmOffset`, `VmRotation`, `VmRightHand` and `VmRightDir` bend *any* equipped gun, not just the knife.

## 2. The videos
`art-source/reference/feel-videos/` (git-ignored, third-party: never commit). Key frames are in `frames/` (`knife_*`, `ar_*`, `largesmg_*`, `smallsmg_*`, `pistol_*`, `revolver_*`, `sniper_*`, `hits_*`).

| Clip | What to take from it | Numbers |
|---|---|---|
| `Knife Animations.mp4` (20.8 s) | Hold 0-2 s; pull-out 3.15-4.0; slashes 4.55 / 5.35 / 6.05 / 6.85; heavy 7.6-8.5 and 8.7-9.8; inspect 12.3-16.6 | Results note §1 + §4b frame study |
| `Pistol Animations.mp4` | 1-frame snap, back of the gun toward you, home by 170 ms, camera still; ADS kick 10-15% of hip | §1 table |
| `Revolver Animations.mp4` | Flip ~2.5x the pistol, **holds the peak ~50 ms**; the floor lights 1 frame before the gun moves; reload: open 6.45, eject 6.9, speedloader 7.8, flick closed 8.5; **inspect has a spin twirl (~300 ms/turn)** at 11.5-12.1 | §1 |
| `Assult Rifile Animations.mp4` | Snap back, small muzzle rise, the spray sits back and shakes 3-4% W, no view climb; pull-out ~0.5 s from bottom left, rolled 60° | §1 |
| `Large SMG animations.mp4` / `small smg animations.mp4` | Hardest snap / small tight kick; pull-outs 0.25 s | §1 |
| `Sniper Animations.mp4` | Rocks back ~30% bigger, slight overshoot, bolt beat with a gold shell ~0.65 s after | §1 |
| `Hit Markers, Headshot, Damage Numbers, Player Highlight on Hit.mp4` | Wedges close in ±28 → 16 px over 100 ms; body white 1 frame → red by 84 ms → back over 0.45 s; **headshot: a fan of light rays from the head ~270 ms, warming to orange**; one adding-up damage number, held 250 ms, then tips over and falls | §1 "Hits" |

Tool: the `video-analyzer` MCP. Use `get_frame_burst` with 14-30 frames over the event, at maxWidth 320-560. 60 fps means one frame is 16.7 ms. Measure in screen fractions, then convert (see §4).

## 3. What exists now (built 2026-11-14, nothing committed)

### Knife
- **Keys are generated, never hand-edited.** `tools/studio/knife_fp_keys.py`:
  - `--check` prints, per key: fist and tip on screen, the turn from the last key, the forearm's screen angle, how far it is off the shoulder line, and eye clearance;
  - `--write` puts all six tracks into `Config/Viewmodel` TRACKS; then run `stylua src`.
- **Key specs:**
  - `("aim", fist(sx,sy,depth), tip(sx,sy,depth), edge|"auto"[, elbow])` places the blade on screen; `"auto"` solves the forearm's roll so the arm comes from the shoulder or `elbow`;
  - `("fist", fist, roll[, elbow])`;
  - `("near", dsx, dsy, roll)` is the hold, nudged;
  - `("held", fist, roll)`;
  - `("blend", fist)` spreads a big turn over hidden keys.
- **Guards:** no step over 120° (CFrame slerp takes the short way); the forearm on screen between -30° and -125°.
- **Rest constants:** `REST_*` and `_LOOK` / `_UP` were measured in play for the current hold; re-measure them if you change the knife's `viewmodelOffset` / `viewmodelRotation`. `FOREARM_HANDLE` / `FIST_HANDLE` / `PIVOT_HANDLE` / `WRIST_BEND` / `SHOULDER` mirror `MELEE_HAND`, `MELEE_WRIST_PIVOT`, `MELEE_WRIST_BEND` and `MELEE_SHOULDER` in `Config/Viewmodel`.
- **Arm solve** (`ViewmodelController` holdWith, melee branch): the forearm is rigid with the knife (`MELEE_HAND.direction`) and may bend `MELEE_WRIST_BEND` (20°) toward `MELEE_SHOULDER` about `MELEE_WRIST_PIVOT`, inside the fist. 45° let the handle slide out mid-swing. Measured: the hilt never leaves the fist in a slash or the heavy.
- **Track playback** (`Util/ViewmodelTracks`):
  - `smooth` tracks are a cubic Hermite with monotone (PCHIP) velocities: out of a hold they start from rest, into a hold they brake, nothing overshoots unless keyed;
  - `toss` keys move the knife model out of the fist while the arm stays put (`ViewmodelTracks.toss`);
  - a move that cuts into a playing one blends from it over `TRACK_BLEND` (0.09 s).
- **Feel on swings** (`Config/Animations KNIFE_FEEL`):
  - the camera leads every swing (`leadRoll` 1.6°);
  - the miss punch is 0.55-0.7°;
  - hit-stop is unchanged;
  - swipe arcs and gouges (`KNIFE_MARK`) follow the slash paths.
- **Free arm:** `FREE_HAND` (moved left and down per the overlay). It drops out of view in slashes (`FREE_HAND_FOLLOW`), comes in only for the heavy's thrust (`MELEE_HEAVY_HAND`), and stays out through the pull-out and inspect.

### Guns
- **Shot kick:** a snap envelope (`Config/Viewmodel SHOT_SNAP`, two exponentials, peak ~10-13 ms) sized by `SHOT_PUNCH`. Measured home times: pistol 143 ms, Sheriff 213, Vandal 117, Stinger 103, Spectre 100, Operator 209.
- **Camera:** calmer (`Config/Juice SHOT_FEEL`: FOV, roll and shake halved; view punch about 60%). The rollback values are in the comments. **Ask the owner whether he misses the old punch.**
- **Gun Draw track:** `smooth`.
- **Sheriff:** `INSPECT_SPIN` rolls the cylinder from frame 1 (two turns, 1.15 s, palm-roll ease) with its cylinder-spin sound. Implemented by `GunAnimator.spin`.

## 4. How to test (the match place)
- **Find Studio:** `list_roblox_studios`, pick placeId **133387545285290**, then `get_studio_state`. Drive it through Workspace attributes:
  - `DevAction`: `"Melee"` / `"Primary"` / `"Secondary"` / `"fire"` / `"draw"` / `"inspect"` / `"reload"`;
  - `DevHeavy` = true for the heavy;
  - `DevHold`, `DevAim`;
  - pick a gun with the `PickWeapon` remote (find it under ReplicatedStorage). Never `require` server modules.
- **A running Play does not pick up Rojo changes:** stop and start Play after every edit. Check the Studio copy has your change (grep its `.Source`) before blaming the code.
- **Studio runs ~15 fps here.** Freeze exact moments in slow motion: set `VfxTimeScale` 0.15, wait `t / 0.15`, set 0, `screen_capture`. Always reset `VfxTimeScale` to nil after.
- **Measure, don't eyeball:**
  - record per frame (fist and tip on screen, forearm turn per step, hilt-outside-fist distance);
  - for screen targets use `cam:WorldToViewportPoint` or aspect-free units (x and y over the half screen height; FOV is vertical): **the owner resizes the window**, so screen fractions from one capture don't carry to the next.
- **Never brute-force big searches in one `execute_luau` call.** A grid of millions froze Studio and timed out. Use coordinate descent, or yield.
- **Live tuning:**
  - `VmOffset` / `VmRotation` for the gun or knife pose;
  - `VmRightHand` / `VmRightDir` for the right hand (handle space).
  - **Clear them when done.**

## 5. The work queue, in order

### A. Knife polish ("a little blocky", "staged")
**2026-11-15: items 1-3 done** (spring follower, moving holds, the second turn re-keyed, cut-ins carry speed): [Gunplay Overhaul](Playtests/2026-11-15%20Gunplay%20Overhaul.md) §7. Left: the inspect's exit flourish, items 4 and 5.

**Start from research §7.** The diagnosis all four research tracks agree on: our keys are mostly *poses* (extremes), and the monotone spline (PCHIP) gives zero velocity at every extreme key. So motion stops dead on each pose (stop-go-stop = "blocky"), and holds sit still (dead holds = "staged"). The fix:
- re-key moves *through* their passing moments;
- get overshoot from a spring layer or Kochanek-Bartels bias, or use Holden's clamp instead of zeroing at extremes;
- moving holds (drift from the last momentum, then off-ratio noise and breathing);
- overlap (roll before tilt, the knife 1-3 frames behind the fist);
- velocity-carrying spring inertialization at cut-ins instead of the `TRACK_BLEND` lerp.

1. **Secondary motion.** One spring layer on top of the spline, the research's advice (Holden "Spring-It-On"; f ≈ 6-10 Hz, damping ratio 0.45-0.7): the knife's screen offset follows the keyed pose through an underdamped spring, so stops have a tiny give and turns carry through. Keep contact on time (the hit-stop and `hit` mark must still line up). Measure overshoot per move.
2. **Holds that breathe.** In the inspect holds and the pull-out settle, add a slow drift (position and roll, ~0.3-0.5 Hz, small) so nothing sits frozen. `MELEE_IDLE` already does this at rest and could be reused.
3. **The inspect's second turn** (research §1 has the clip's version frame by frame: the hold drifts, then one ~200 ms wrist move, a roll about the blade's length into a tip-over that starts before the roll ends, the fist nearly still; the exit is roll to point-down → pendulum swing up → dip out of view → back, with no stop). It's the roll from the face pose over to "laid over pointing left" (~0.55-0.72 of `InspectMelee`, keys solved with `"auto"`), and it reads mechanical. Re-study the clip's inspect (12.3-16.6 s) frame by frame. Options: a continuous wrist roll that flows out of the catch instead of a separate turn; a smaller, quicker turn with a follow-through; or a second toss variation (a spin in the screen's plane, like the pull-out's). Keep any spin natural: a toss, never a twirl in the fingers.
4. **The free forearm roll** (overlay note 3, second half): roll it so its narrow side face shows less. The left arm's twist reference is `root.RightVector` in holdWith; add a config roll.
5. Check the heavy's cocked pose (its forearm points back toward the camera for ~80 ms) and the slash returns against the clip at full frame rate.

### B. Gun feel polish
- Review every class with the owner (snap size, home time, the calmer camera). Tune `SHOT_PUNCH` / `SHOT_SNAP` per gun, not just per class.
- **Pull-outs per class from the clips** (parked numbers in Bugs & Ideas): pistol from bottom right, muzzle up-left ~45°, ~0.3 s; rifle from bottom left rolled ~60°, ~0.5 s; SMG straight up ~0.25 s. Per-gun Draw clips live in `shared/WeaponAnimations/<Gun>.luau` (generated from Blender: change them there, or layer a per-class track).
- **ADS kick** (clip: ~10-15% of hip, a push back) and spray texture (the rifle sits back and shakes).
- **Muzzle flash life by class and a short world-light pop** (clip: pistol / revolver star ~150-170 ms, 1-2x the gun's width; rifle 1 frame): `Util/MuzzleFx`.

### C. Sheriff polish
**2026-11-15: the shot's hold and the inspect twirl are done** ([Gunplay Overhaul](Playtests/2026-11-15%20Gunplay%20Overhaul.md) §8). Left: the reload beats (Blender).

- **Shot:** the flip holds its peak ~50 ms (`SHOT_SNAP.gun.Sheriff` attack 0.012) and the light leads the gun by a frame. Check against `revolver_shot-peak`.
- **Inspect:** the cylinder roll is in. Now make the rest of the inspect match the clip's beats (rolls flat, muzzle up, **a toss-spin twirl ~300 ms/turn** done as a natural toss, shows the other side, flicks back). Keep `INSPECT_SPIN` timed to the sound.
- **Reload** beats (open, eject, speedloader, flick closed with a snap to the right) against `revolver_reload-speedloader`.

### D. The PopCircuit Bat, with the new ideas
**2026-11-15: hit-stop, swing side by combo step, a moving idle and settles are done** (same note, §8). The owner's own ideas for it are still to ask.

`Util/PopCircuitBat` (its own motion system; read the Third Person Overhaul note §8-9 by section; owner: "there isn't fingers... very simple"). Bring over what worked on the knife:
- a rigid fist relation with a wrist pivot;
- screen-placed keys through a monotone spline;
- coil, snap, brake, overshoot, settle;
- the camera leading each swing;
- a toss-and-catch flourish in the inspect (the current one flips the bat once in the air);
- blended cut-ins.

Consider porting the bat's clips to the knife's solver-and-tracks pipeline.

### E. Headshot, crosshair animation, head flare
Lane F's work: `Util/HitFeedback`, `Util/HitFx`, `Util/Crosshair`, `Config/HitFx`, `Config/Crosshair`; [Hit Feedback Pass](Playtests/2026-11-13%20Hit%20Feedback%20Pass.md) §10-11; headshot comparisons in `Playtests/2026-11-13 headshot … vs RIVALS.png`.
- **Head flare:** the clip's headshot is a fan of white-to-cream rays from the head, ~270 ms, warming to orange as it fades. Ours was a radial burst, now a faceted crown burst (2026-11-15). §11 has a ChatGPT prompt the owner may have run for a flare texture: ask.
- **Crosshair animations:** a bloom while firing (clip: about +5 px, back within ~0.3 s), the hit X / wedge pop (clip: wedges close in over 100 ms and restart per hit), and headshot / kill variants. Stay in the Soft Edge theme.
- **Damage numbers:** one per target that adds up during a stream, ~48 px at 1080p, held ~250 ms, then tips over clockwise, drops and shrinks over ~270 ms; head red #E01F35 with a dark outline.

## 6. Done looks like (each pass)
- A playtest note in `05 Production/Playtests/`: the plan first, then results. Include before/after captures (our game only; reference frames stay in `art-source/reference/feel-videos/frames/`), measured numbers, grades and a test list for the owner.
- `00 Home.md` → Status updated (keep it short; move old entries to Status History); `INDEX.md` lines; Code Map if a Service or Controller changes.
- Lint, format and build clean, and Studio Output free of new errors.

# 2026-11-04 Animation and Knife Pass (lane D, `anim-knife`)

Overnight lane D from [Overnight 2026-11-04](../Overnight%202026-11-04.md). Goal: third-person animation that looks professional (two-handed grip on every gun, a fire reaction, full-body locomotion and slide) and a clean default knife (hold, light / heavy slash, inspect, sounds, centred wall marks), working on bots too.

## Phase 1: findings and plan

### How the game plays animations today (measured 2026-11-04)
- Clips are **built in code**: `tools/studio/Make*Animations.luau` writes R15 KeyframeSequences, `receive_server.py` saves them to `art-source/animations/*.rbxm`, `tools/opencloud/upload_asset.py` uploads them **group-owned** (group 11116787, the experience owner), ids go in `Config/Animations.luau`.
- They play inside the Server Authority simulation (`shared/Simulation/Poses`): the server poses everyone, each client predicts its own character. Scripted joint `Transform` writes **don't stick** (tested in PreAnimation, PreSimulation, PostSimulation and PreRender on a dummy and on the local character: no change).
- **IKControl does work** on these AnimationConstraint rigs, on the server and on a client for someone else's character (a free target was reached to 0.02 / 0.09 studs). A Motor6D's `C0` / `C1` (the gun's `WeaponGrip`) can also be moved on a client.
- **Why the off hand never touched the gun:** every gun model already has `LeftGrip` and `RightGrip` attachments, but the old hip pose held the gun at arm's length (shoulders at 90°, straight elbows), so the left grip was **3.8 studs** from the left shoulder while the arm reaches **1.86**. Measured hand-to-grip gap: 2.1 studs on the Vandal. IK on its own can't fix that; the hold pose has to change.

### Toolbox animations: why not
An animation only plays in a live game if the experience's owner (here the group) or Roblox owns it. A toolbox animation by someone else loads in nobody's live server, and its KeyframeSequence can't be downloaded to edit and re-upload. So the working path stays the one the game already uses: clips keyed in code (deterministic, reviewable in diffs, consistent style), uploaded by the group. Blender isn't used for these: an R15 rig round-trip adds an export step and loses the diffable source for no gain on block-shape avatars.

### References (described, nothing saved)
Research by a sub-agent (sources: 80.lv Valorant animator breakdown, The Spike's Valorant knife timing analysis, RIVALS guides, a Roblox DevForum firing-animation thread). Hard numbers are scarce; the ones marked *inference* are standard shooter practice to tune by eye.
- **Hold:** rifle shouldered, chest bladed ~15-25° toward the target, off hand on the handguard with the elbow low, head on the stock line. Pistol: two hands, arms forward with soft elbows. Pitch split between spine (~30-40%) and arms. *(inference)*
- **Fire reaction:** ~4 frames rise at 30 fps (~130 ms), 2-frame hold, then recover; the gun tilts back as well as up (DevForum). Pistol small and quick, rifle small and stacking, shotgun / sniper big with a long recovery. *(partly inference)*
- **Run:** ~2.5-3 steps/s at normal speed, upper body steady with the gun, a few degrees of counter-twist. RIVALS has a sprint (gun lowered) and a slide (Ctrl), Valorant has neither. *(inference for the poses)*
- **Slide:** lead leg out nearly straight, trailing leg tucked under, torso leaned back 20-30°, gun kept up at the target; in ~100-150 ms, out ~150-250 ms. *(inference)*
- **Jump / land:** airborne tuck, landing compression ~100-150 ms then a ~100 ms settle, deeper after a long fall. *(inference)*
- **Knife:** Valorant light swing ~50 ms animation, heavy ~150 ms (The Spike, 2020 measurement); forward grip in the right hand, off hand free.

### Style guide (applies to every clip in this pass)
- **Weight:** every big move has a 2-4 frame (at 30 fps) anticipation, a 2-4 frame overshoot and a 3-6 frame settle; key poses hold 2-3 frames so they read at a distance. Limbs move in arcs; the hips lead, the chest follows ~1 frame later.
- **Silhouette:** gun close to the body, elbows down, shoulders relaxed (never "zombie arms"); the gun always points where the player aims.
- **Hold by class:**
  - *Long guns* (Rifle, SMG, Shotgun, Sniper, Heavy): chest turned ~18° right (right shoulder back), head counter-turned to face the aim, butt at the right shoulder pocket, right elbow down and out, left hand on the gun's `LeftGrip` by IK with the elbow under the gun.
  - *Sidearms:* two-handed, arms forward at chest height with soft elbows, left hand on the pistol's `LeftGrip` (it cups the grip hand) by IK.
  - *Knife:* forward grip, right hand low-ready by the right hip / chest, blade forward and up; left hand up as a guard.
- **Fire kick** (other players' view, client-side): the gun pushes back and the muzzle flips; the right forearm takes the push (IK), the left hand rides along (IK). Rise ~50-80 ms, recovery by class: Sidearm ~110 ms, SMG ~70 ms, Rifle ~90 ms, Heavy ~80 ms, Shotgun ~250 ms, Sniper ~320 ms. Size scales with the gun's `recoil.up`.
- **Locomotion:** stride 0.62 s at 16 studs/s (~3.2 steps/s); hips bob at each footfall and twist with the legs; upper body steady around the gun. Sprint: low-ready carry, bigger stride, 14° lean.
- **Slide:** full body on the ground: hips down to ~0.4 studs off the floor, torso back ~35°, right leg out straight, left leg folded under with the shin on the floor, gun up at the target with both hands. In 0.2 s (a dip, then the drop), out 0.3 s (push up off the left foot).
- **Consistency:** one easing language (fast out, soft in), the same anticipation / settle lengths across the set, the same joint conventions as the existing `Make*` tools.

### Plan
1. **Grip IK** (client, every visible character incl. bots and dummies): a new `GripController` puts an IKControl from each left arm to the held gun's `LeftGrip`, with a pole for the elbow; weights fade off for the knife, Akimbo, Mod holds and uses, the reload, death.
2. **Hold poses re-keyed** in `MakePoseAnimations` (hip and ADS, long-gun and sidearm sets) so the grips are in reach, then uploaded.
3. **Fire kick:** right-forearm IK pull + the existing gun flip, scaled per class (Config/Animations `FIRE_KICK`).
4. **Locomotion / jump / land / slide re-keyed** to the style guide (full-body slide), uploaded.
5. **Bots:** `Simulation/Poses` reads its cosmetic attributes from the Player when there is one, else from the character model, and steps any server character tagged `PoseRig` (lane C tags its rigs and sets the same attributes on the model).
6. **Knife:** first-person hold / light / heavy / inspect pass, sounds (real recordings, auditioned), marks at the server-confirmed hit point and normal, oriented to the slash.
7. Review on an R15 test dummy from several angles (screenshots in chat only), then playtest.

## Phase 2: blockout on an R15 dummy (Edit mode, screenshots in chat only)
- A review stage (R15 dummy + Vandal) with a forward-kinematics poser (Studio doesn't solve AnimationConstraint joints in Edit, so part CFrames were set from joint transforms; checked against the playtest: 2.11 / 3.80 studs, identical) and an exact two-bone IK. Critique rounds: v1 cramped (gun at the sternum, right elbow winged) → v2 gun forward and lower → v3 shouldered (grip 1.25 studs ahead of the shoulder: the long guns' stocks sit 1.1-1.5 studs behind the grip) → ADS (gun at the cheek, head on the stock) → sidearm (square, two-handed, cupped). Pitch ±70 checked.
- Slide: solved offline with an FK model of a standard R15 avatar against the floor. The old slide's folded leg sank **0.8 studs into the floor** with the hips 0.4 up (a kneeling scoot); the new one rests on the ground.
- Removed afterwards (the place is back as it was; nothing to save).

## Phase 3: what changed
**Pipeline.** The Studio assistant's HTTP allowlist now blocks the localhost receiver, so tools print pose text and `tools/studio/pose_text_to_rbxm.py` builds the `.rbxm` with Rojo (round-trip verified with AnimationClipProvider: exact). New tools: `MakeHoldAnimations.luau` (solves the holds on a temporary rig with the real guns), `make_slide_poses.py` (the slide, with `--check` for ground contact). `MakePoseAnimations` / `MakeCombatPoseAnimations` no longer build the hold clips; `MakeSlideAnimations` is marked superseded. All clips uploaded group-owned (ids in `Config/Animations`).

**Per weapon class (what others see).**
| Class | Hold | Off hand | Fire kick (forearm + gun flip) |
|---|---|---|---|
| Rifle (Vandal, Phantom, Guardian, Bulldog) | shouldered, chest bladed 26°, head on the stock line; ADS: gun to the cheek | IK onto `LeftGrip`, slid back along the barrel to within 88% of the arm's length (lands on the rear guard on long guns) | 0.15 studs back, 6°, ~0.09 s |
| SMG (Spectre, Stinger) | same long-gun hold | same | 0.10, 5°, ~0.08 s |
| MachineGun (Odin, Ares) | same | same | 0.14, 5°, ~0.08 s |
| Shotgun (Judge, Bucky) | same | same | 0.34, 15°, ~0.26 s |
| Sniper (Marshal, Operator, Outlaw) | same | same | 0.40, 16°, ~0.33 s |
| Sidearm (Classic, Sheriff, Ghost, Shorty) | new two-handed set (`Pistol*` clips, square stance, arms forward) | cups the grip hand (`LeftGrip` + 0.16 left, 0.1 under) | 0.16, 9°, ~0.12 s |
| Akimbo | long/pistol hold per class, a gun in each hand | no IK (both hands hold guns) | gun flip only |
| Knife | unchanged ready / slash / heavy clips (they read fine) | no IK | none |
- Draw and Reload now start and end on the new hold (they used to flash the old straight-arm pose on every swap / reload).
- The grip lets go during the reload clip, Mod holds and uses (0.6 s), death, and when the gun is hidden; fades in 14/s, out 20/s.
- Sprint: a solved low-ready carry (muzzle down and across), left hand on the gun.
- **Slide:** full body on the ground (hips 0.17 off the floor, torso back 35°, lead leg out with the heel down, trailing leg folded, gun still forward in both hands). In 0.24 s with a dip and an overshoot, out 0.3 s pushing up off the lead foot.

**Knife.**
- **Wall marks centred:** placed where the aim ray meets the surface (the old code used the reach *sphere's* contact point, off the crosshair on angled walls and on nearby edges, plus a deliberate ±0.3 stud jitter), and laid along each swing's screen path (Slash1 right→left falling, Slash2 back across, Slash3 the chop, heavy a short upright tear; `KNIFE_MARK`). Verified in play: the gouge sits exactly on the hit point.
- **First-person hold:** low-right ready hold, blade angled in, tip off the crosshair; the free hand moved out of frame (it read as a stray fist in the corner). It still comes onto the handle for the heavy stab.
- Slashes, heavy and inspect: the existing Blender clips, unchanged.

**Bots.** Lane C's `Simulation/Pawns` owner stand-in already poses bots through `Simulation/Poses` exactly like players (cleaner than the tag I first proposed); GripController covers everything in `Workspace.Dummies` (bots and range dummies) and the kick reacts to `ShotFx` from a bot model.

**Measured in play (2026-11-04/05):** off hand to target 0.10 studs at rest; 0.18 mid-kick (rifle burst); gun pushed 0.26 studs and flipped 17° on a sniper shot, then recovers.

## Known gaps
- **Knife sounds are still placeholders** (one Roblox-licensed swoosh, re-pitched). The Creator Store "knife" sounds are game rips from random uploaders, and no CC0 knife recordings are in `art-source/audio`. Proposal: download CC0 packs (Kenney "RPG Audio": draw knife / knife slice; Kenney "Impact Sounds": metal / plank hits), polish, render an audition WAV with `build_sound_atlas.py --preview`, then upload in the atlas (audio quota). **Needs your OK to download.**
- Reload's middle keys are still the old arm poses (only start/end were moved onto the new hold); the Death clip starts from the old hold.
- Run / walk / sprint / crouch-walk legs and jump / fall / land are unchanged this pass; the upper body stays steady while running (the aim layer owns the chest). A procedural run sway / landing dip on the upper body is the next step.
- Long guns: the off hand lands on the rear of the guard, not the far `LeftGrip` (Roblox arms are short next to these guns).
- Bot owners live in ServerStorage, so clients can't see a bot's `ReloadAt` / `ModHeld`: the grip doesn't let go during a bot's reload (asked lane C to mirror four attributes onto the model).
- A moving character's off hand can trail the gun by a frame (measured up to ~0.4-0.8 on the strafing dummy while it moves fast).
- The pinned StyLua 0.20.0 binary is blocked by Windows Application Control on this PC; files were checked with StyLua 2.6.0 (`~/.rokit/tool-storage/johnnymorganz/stylua/2.6.0`).
- `art-source/uploads.json` isn't committed (it also holds the lobby lane's uncommitted uploads).

## What the user should test tomorrow
- [ ] With a bot (Workspace attribute `BotMatch = "1v1"` in Studio) or a second player: every gun class shows **both hands on the gun** from the front, side and back; sidearms two-handed.
- [ ] Watch someone fire a rifle, a shotgun and a sniper: the arms kick back and the muzzle flips, bigger and slower for the shotgun / sniper; the off hand stays on the gun.
- [ ] Swap weapons and reload: no flash of straight "zombie" arms at the start or end.
- [ ] Sprint, then slide: the body goes **down on the floor** (lead leg out, trailing leg folded, gun forward) and pushes back up into the run.
- [ ] Knife in first person: low-right hold, no stray left fist; light slashes 1-2-3, the heavy stab (both hands), Y inspect.
- [ ] Slash a wall and the floor: each gouge sits **exactly under the crosshair**, angled along the swing.
- [ ] Decide on the knife sound plan (approve downloading the CC0 packs, then audition before any upload).

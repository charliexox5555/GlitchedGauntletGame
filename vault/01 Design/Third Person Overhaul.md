# Third Person Overhaul

What other players see of you in a match: the body, the accessories and every third-person animation. Built 2026-11-12 (owner: third-person animations and "seeing what other players do" are "a huge issue right now"). Replaces the slim-arm body in [Match Avatar](Match%20Avatar.md).

**Owner's brief (2026-11-12, his words gathered):**
- Regular-width arms, "like a regular block character". The thin arms go.
- Blocky like the first-person arms: sharp, flat-shaded blocks for arms, legs "and everything".
- Hands look detached from the arms, the arm bends ("curves") look bad, the feet look bad: make it smooth.
- Most accessories back, so you can recognise a player, minus the ones that cause problems.
- Animations: "you're never really holding the gun", they look compact, dull, boring. He wants oomph, professional, keyframed where it helps. No inspect in third person.

## State
| # | Phase | State |
|---|---|---|
| 0 | Players were not posed at all with Server Authority off | **fixed** |
| 1 | Block body | **built, seen in Studio** |
| 2 | Accessory rule | **built, not tested with a real accessory** |
| 3 | Review tools | **built** |
| 4 | Clips re-authored on the new body (40) | **built, uploaded, wired, seen in Studio** |
| 5 | Mod, flinch, dash, Updraft, death and victory clips | **open** (still the old ones) |
| 6 | Second pass after the owner's review (research, rifle stance, smooth firing, joints): §7 | **built, seen and measured in Studio** |
| 7 | Third pass: skinned body (one mesh per limb and the torso, clean bends), support elbow outside the chest, one gun per class on the dummies: §8 | **built, seen in Studio**; owner: "the arms are looking better" |
| 8 | Run pass (foot lock, flight, cadence), smaller chest turn, first-person clothing fix, layered hair back: §10 | **built, seen and measured in Studio** |
| 9 | Importer bone mix-up found and fixed (unique bone names), R15 proportions checked against the presets, knife in the fist, bat on splines: §11 | **built, seen and measured in Studio** |
| 10 | Sidearm hold (pistol clearly in the right fist), other players' accessories | **open** |

Nothing is committed. `selene src`, `stylua --check src` and `rojo build` are clean.

## 0. Root cause found first
With Server Authority off (2026-11-11), **no real player was posed at all**. `Simulation/Poses.isSimulated` asked the engine for the Animator's prediction status, which is `None` when nothing is predicted, so every client skipped its own character. Others saw you standing in the idle with the gun hanging from a straight arm, and gliding with no leg motion (Animate's walk and run are empty clips on purpose: the run set in Poses carries the legs). Bots were fine (the server poses them). Fix: `isSimulated` returns true when `Authority.server()` is false.

A second one found on the way: holding forward through a jump keeps the move state "Sprint", so the legs kept running in mid-air over the jump and fall poses. The run set now stops whenever the Humanoid is off the floor, and the landing dip plays after those jumps too.

## 1. Before (Studio test range, my own character seen from outside)
- Before the fix in §0: idle pose only, gun hanging at the right hip, no hold, no legs.
- After that fix, all 18 weapons side by side: **every gun used one of two compact holds**. The right arm folded so the gun sat beside the right shoulder, the left forearm crossed the chest, both forearms stacked in front of the torso. From the front you saw crossed arms, not someone holding a gun. Pistols: both fists stacked at the sternum, gun hidden. Knife: fist at the chest.
- Hands were separate 0.3-stud slabs that turned at the wrist, so they read as detached plates; feet the same at the ankle. Elbows and knees opened a wedge gap on the outside of every bend (two flat-ended boxes). Arms were 0.6 wide.
- A caution for anyone reviewing this way: the first-person gun and arms sit at your head, so from outside they show as a stray block through the chest. The review rig hides them now; my first "before" captures still had it in frame.

## 2. Block body
Regular blocky R15 proportions, built from our own meshes over the engine's rig. The engine's R15 parts stay as the rig and the hitboxes (same sizes for everyone, unchanged), but are invisible; what you see is one welded block per segment:
- **Arms 1.0 stud wide** (`ARM_WIDTH` and `slimArms` are gone).
- **Forearm + hand = one block** to the fingertips, like the first-person arm. The wrist joint still turns the gun, but no hand plate can detach.
- **Shin + foot = one block** (an R6-style leg end).
- **Elbows, knees and hips:** each segment ends in a half-octagon wrapped round the joint's axis (angled plates, no curves: `gauntlet-build-style`). Both halves share the pivot, so a bend closes with facets instead of opening a gap. Straight, the caps hide inside the neighbour.
- **Waist:** the hips block carries an inset band that reaches up into the chest block, so a lean shows a band, not a hole.
- Sharp 0.035 chamfer, flat faces, SmoothPlastic, the same as the first-person arm.
- **Skin** = the avatar's body colours. **Shirt / Pants** = the classic templates, Pants under Shirt on the torso, like the engine layers them.
- Head: the engine's own head (face, hair and hats fit it).
- Switch: `Config/Avatar BLOCK_BODY`.

**How the clothing is drawn (worth knowing, it cost four tries):** one `Texture` per block face, cropped to that face's piece of the template (`Config/Avatar CLOTH_REGIONS`, `BLOCKS t0 / t1`). It is the only way a game script gets the skin to show through a template's clear areas:
- a MeshPart's `TextureID` and a SpecialMesh's texture draw the clear areas **black**;
- a `SurfaceAppearance` in Overlay mode blends correctly, but its maps can only be written with plugin rights (it worked from the Studio MCP and failed in the game);
- a `Decal` ignores the mesh's UVs and can't crop;
- on a MeshPart a `Texture`'s tile starts at the **centre** of the face, not its corner.
About 54 Texture instances per character. Not measured for cost yet.

Files: `tools/blender/make_body_mesh.py` → `art-source/body/BlockBody.fbx` (Model asset 125998394949118), `Config/Avatar`, `shared/MatchBody` (`dress`, `preload`). Not drawn yet: the T-shirt decal, and the hand end / sole (they show skin).

## 3. Accessory rule
Sources: LihFolk *Avatar Body Types and Scale in Gameplay*, *HumanoidDescription and Outfit Systems*, *UGC Avatar Items and Accessories*, *Teardown - Arsenal*; Roblox docs (Avatar Settings, rigid accessory specifications); DevForum threads on hats blocking headshots and oversized UGC. No first-party statement from RIVALS or Hypershot was found; in the RIVALS videos players wear hair, hats, ears, face items and collars in matches, and no wings or back items appeared in the sample.
- **Keep** (rigid accessories only): hat, hair, face, eyebrows, eyelashes, neck, front, waist, shoulder, back.
- **Remove:** layered clothing (it wraps the body and changes the silhouette); any accessory bigger than its cap; any type with no cap.
- **Strip from the ones that stay:** particles, trails, beams, lights, fire, smoke, sparkles, sounds, scripts, highlights and GUIs. The item keeps its shape and loses its effects.
- **Size caps** (studs, the three sides compared largest to smallest, measured on the spawned accessory's Handle): Hat 3.2 x 3.2 x 3, Hair 4.2 x 3.5 x 3, Face 3 x 2 x 2, Neck 3 x 3 x 2, Shoulder 3.5 x 3 x 2.5, Front 3 x 3 x 2, Back 4 x 3.5 x 2.5, Waist 4 x 3 x 3. Head items sit near Roblox's own limits for the classic body; back, waist, shoulder and front are cut down so wings, tails and oversized props can't hide a body.
- **Never part of a hit:** every accessory part has CanQuery / CanTouch / CanCollide off.
- Roblox's Avatar Settings can do some of this, but scripts can't read them and `UseAvatarSettings` has an open bug that drops all accessories, so the rule is ours, on the server.

Code: `Config/Avatar ACCESSORIES = "all"`, `ACCESSORY_LIMITS`, `ACCESSORY_STRIP`; `MatchBody.filterAccessory`, called from `CharacterService`. A handle that is a plain Part with a SpecialMesh reports the part's size, not the mesh's, so an old-style oversized hat can slip under its cap.

## 4. Animations
**Decision: every hold, locomotion, crouch, slide, air, reload, draw and knife clip was re-authored, keyframed, not patched.** The old clips were solved for 0.6-wide arms and a shouldered hold; on 1-stud arms they clip into the chest, and their design is what read as compact. Every hold changed, so every clip that starts and ends on a hold changed too.

**How they are made:** `tools/anim/tp_rig.py` is a rig of the match body (joint for joint, checked against the engine to 0.001 studs). A clip is keyed the way an animator works: the **gun**, the hips and the feet are placed; the right hand is solved onto the grip, the left onto a point on the gun, knees and elbows follow pole directions. `tools/anim/tp_clips.py` holds the 40 clips and bakes them at 30 keys a second. Review is in Studio, not Blender: `tp_clips.py sheet` + `tools/studio/TpPreviewSheet.luau` lay poses out on the real block body with the real guns, and the engine is where the result has to look right anyway (the Blender hop would only add an export step). Export goes through the existing path (`tools/studio/pose_text_to_rbxm.py` → `art-source/animations/GG_*.rbxm` → `tools/opencloud/upload_asset.py`), ids in `Config/Animations`.

**Kept procedural:** the fire kick (the gun in the hand, a spring: `EffectsController`, `Config/Juice WORLD_KICK`; rebuilt in the second pass, §7) and the left hand's last step onto each gun's own grip (`GripController` IK; a clip can't know the gun).

**Style, from the video study** (RIVALS `04KhOzQVTw0`, `NhF6H3Ii-58`; Valorant `iPWqI-bXi8I`): both block ends meet on the gun near the centre line at chin height with the elbows flared wide, so the arms read as a broad shape from the front; the legs carry the energy; whole-body leans on strafes; a reload you can read from across a map (muzzle up, gun to the chest, the off hand travels).

| Clip set | What it does now |
|---|---|
| Holds: long guns and sidearms, hip and sights, up / level / down (12) | **Second pass (§7):** a rifle stance. The chest is turned about 38 degrees so the left shoulder leads, the stock runs back into the right shoulder, the right fist is under the pistol grip with its elbow down, the left arm reaches out to a fist under the handguard. The whole gun shows above the fists. Sights: the gun rises to the eye and the head tips onto the stock. Sidearms: two fists side by side under the pistol, arms out, elbows down. (First pass: gun at chin height with the elbows flared wide; the owner found it unnatural.) |
| KnifeReady | Blade up and leaning in on the right, the free hand out front. |
| Idle | Straight legs like a regular block character, breathing and a slow weight shift. |
| RunF / B / L / R | Long strides, the planted leg lands straight, gives as the body passes and pushes off; the heel kicks up behind; strafes roll the body 9 degrees into the move. All one length (0.5 s) so they blend in step. |
| SprintRun + Sprint / SprintPistol / SprintKnife | The forward run: bigger strides and bounce, 15 degrees of lean. The upper body is its own clip in step with the legs: the gun drops to a low ready across the body and swings with the stride; with the knife both arms pump. |
| Jump / Fall / Land | Push off, left knee drives up with the body pitched forward, settles into a split-leg fall; landing squashes and springs back with an overshoot. |
| Crouch, CrouchWalk x 4 | Down on the haunches, left foot ahead, right knee low; low shuffling steps. |
| SlideIn / Slide / SlideOut | Sat back on the right hip, the left leg shot out in front, the gun still out ahead in the right hand, the left hand skimming the floor; in over 0.24 s, out over 0.3 s (the slide is 0.85 s). |
| Reload, PistolReload (new) | Muzzle tips up and the gun comes to the chest, the off hand drops for a magazine, brings it up, slaps it home (the gun jumps), then the gun goes back out past the hold and settles. |
| Draw | The gun comes up from low on the right, the off hand meets it, it lands with a small overshoot. |
| KnifeSlash 1-3, KnifeHeavy | Forehand, backhand, overhead chop; the heavy coils back, holds, then thrusts. Contact at 0.15 / 0.15 / 0.19 / 0.40 s, as in first person. |

**Per gun, after:** all 17 guns and the knife were lined up in a playtest with the grip IK on. Rifles (Vandal, Phantom, Bulldog, Guardian), SMGs (Spectre, Stinger), shotguns (Bucky, Judge), snipers (Marshal, Outlaw, Operator) and machine guns (Ares, Odin) share the long hold: every one is up at chin height, level, pointing where you look, with both block ends on it. Sidearms (Classic, Ghost, Sheriff, Shorty) share the two-handed hold. **Still open per gun:**
- Fixed in the second pass by turning the chest: the left fist now sits about a stud ahead of the grip, under the handguard, on the rifles. On the longest guns (snipers, machine guns, Bucky) it slides back to where the arm can reach, still ahead of the magazine.
- Long stocks (Bulldog, Stinger, Operator) run through the chest and can show a few centimetres out of the back.
- The Odin and Ares use the rifle hold; a hip carry would suit them better.
- Shotguns reload with the magazine reload (no shell-by-shell clip).

**Track limit:** an Animator plays 16 tracks at once. Still inside it: three sprint clips exist but only one plays.

## 5. Not verified
- **A second real client.** Everything was seen on my own character through a dev switch; that a client's tracks and the grip IK look the same on another player's screen was not checked (it needs two clients).
- The accessory filter against real accessories (the test avatar wears none).
- Knife swings and the fire kick in motion (stills only; the swing reaches the clip through a server stamp, so it starts a moment late).
- Aim up and aim down poses in the game (seen in the preview only), backpedal and strafes in the game.
- A bot match (bots go through the same pose code; not run).
- The cost of the per-face clothing textures with 8 players.
- Mod use, flinch, dash, Updraft, slam, death and victory are the old clips, made for thin arms. They play; they may clip.

## 6. Review tools
- `tools/studio/ThirdPersonReviewRig.luau`: see your own character as others do in a Studio playtest (camera orbit, body unhidden, scripted moves). Set Workspace `DevThirdPerson = true` in Edit so your own left hand goes on the gun too.
- `python -I tools/anim/tp_clips.py sheet <clips>` + `tools/studio/TpPreviewSheet.luau`: a pose sheet in Edit, on the real body with the real guns. **Since §8** the skinned limbs only bend in a playtest (BodySkinController is a client script): in Edit, call `MatchBody.skinLimb(MatchBody.limb(mesh))` for each mesh in `Workspace.GGBodyLimbs` after posing, or the limbs show straight. It writes a temporary `src/shared/TpPreview.luau` and a `Workspace.TpPreview` folder: delete both when done.

## 7. Second pass (2026-11-12, after the owner looked at it)
**Owner:** "It's looking better, but we still need a good amount of work... Everything still looks really unnatural... The way guns are held, the way it shoots is just too jittery... Please research on ways people do this... I want it to be smooth... The legs are looking better, but I think there still could be improvement... Find toolbox things if there's animations for it." His screenshot (a range dummy from the front-right, close): the arms a lumpy cluster in front of the chest, the rifle small and buried in it, no hand visibly on it.

### Research
- **LihFolk** (*Springs Damping and Smoothing*, *Gun Feel - Recoil, Spread, Bloom*, *IKControl Reference*, *Held Weapons on Motor6D*, *Playback, Priorities and Blending*, *Animator Deep Dive*, *R15 Run Cycle Key Poses*, *Animation Asset Permissions and Groups*):
  - Recoil is an impulse into a spring, never a restart per shot. One owner per joint. Switching an IKControl on and off pops.
  - A higher-priority track at weight 0.3 lets 0.7 of the lower one through; same priority, weights over 1 normalise.
  - An IK target should be an Attachment on a moving part; SmoothTime 0 for hand contact; a pole on the limb's line gives an undefined bend.
  - A run is contact, down, passing, up; pelvis turn within 8 degrees; scale the clip's speed to the ground speed.
  - Another creator's animation only plays if our experience is granted on the asset; Roblox's own animations play anywhere.
- **Web** (search results and page summaries; no tutorial was watched end to end):
  - Holds: the gun on a Motor6D from the hand so clips drive it ([How to animate Tool Parts](https://devforum.roblox.com/t/how-to-animate-tool-parts-guns-knifes-etc/359484)); IKControl for the support hand ([IKControl docs](https://create.roblox.com/docs/reference/engine/classes/IKControl), [IK out of beta](https://devforum.roblox.com/t/ik-controls-are-now-out-of-beta/2156480)); Moon Animator gun tutorials ([1](https://www.youtube.com/watch?v=lwigO9FDZkA), [2](https://www.youtube.com/watch?v=ba5HC3V6eqA)); [3rd person gun system](https://devforum.roblox.com/t/3rd-person-gun-system/1034675).
  - Aim seen by others: send the angles at a low rate, smooth on the receiving client ([Replicate Motor6D.Transform](https://devforum.roblox.com/t/what-is-the-most-effective-way-to-replicate-motor6dtransform/2156012)). We use pitch-blended poses instead, which replicate as animation state.
  - Recoil videos to watch: [First & Third Person Shooter System Part 3](https://www.youtube.com/watch?v=kDj7H4TgLxc), [Advanced recoil system](https://www.youtube.com/watch?v=q3iQGR1Whz8).
  - Run cycle poses: [AnimSchool](https://blog.animschool.edu/?p=634), [Game Developer](https://gamedeveloper.com/art/animating-the-run-cycle).
  - RIVALS in third person: no usable footage beyond what the first study found (§4); the Valorant showcase (`iPWqI-bXi8I`, 1:33-1:55) is the clearest reference for a rifle stance: stock in the shoulder, support hand under the handguard, elbows down, body turned 30 to 45 degrees.
- **Toolbox / Creator Store:**
  - A free R15 gun pack exists: ToasterWaaffle, ["Free third person gun animations"](https://devforum.roblox.com/t/free-third-person-gun-animations/1802464) (model 9703914879: shotgun pump, MP5 / rifle / pistol / tactical reloads). **Not usable as it is:** no licence is stated, and an animation owned by someone else does not play in a group-owned game ([staff reply](https://devforum.roblox.com/t/animations-are-not-playing-even-when-uploaded-to-the-right-group/3930478), [thread](https://devforum.roblox.com/t/animation-only-works-for-publisher-in-a-group-game/3120683)). Good as a reference for reload beats only.
  - Roblox's own packs can be played by any game: Rthro run 2510198475, walk 2510202577, jump 2510197830, fall 2510195892; Ninja run 656118852 ([Use animations](https://create.roblox.com/docs/animation/using)). **Not adopted yet:** our forward, back and strafe runs must share one cycle length to blend in step, and a pack only has a forward run. Worth a try for the sprint legs alone (they don't blend with the strafe set); not tried.

### What was wrong, measured
- **Jitter:** sampled on the shooter dummy at 60 frames a second. On a shot the gun jumped **0.69 studs in one frame**, the right hand 0.59, the left hand 1.2, and the gun's motion reversed 49 times in 5 seconds. Two things: the gun's own kick snapped to full in one frame on every shot, and a second kick on the right arm was an IKControl that switched on and off per shot (each switch threw the arm to a different solution).
- **Holds:** the gun went through the centre of the hand. With 1-stud arms the block swallowed the pistol grip and half the receiver, and from the front both forearms faced the viewer end-on. The left arm could only reach about 0.2 studs past the grip with the chest square, so both hands sat in one lump.
- **Joints:** each bent elbow showed four small plates an end (the half-octagon), smooth shaded: eight facets in a lump.

### What changed
- **The gun sits on the front of the fist** (`Config/Animations GUN_WORLD_GRIP`, was through its centre): the fist is under the gun, round the pistol grip, and the whole gun shows above it. `tools/anim/tp_rig.py GRIP_GUN` matches.
- **Rifle stance** (table in §4). Turning the chest is what lets a block arm reach the handguard.
- **Firing:** one system. The gun kicks in the hand on a spring that each shot pushes (`Config/Juice WORLD_KICK`: frequency, damping, a cap for held fire); the right-arm IK kick is gone. The support hand's IK target is an Attachment on the right hand at the gun's rest position, so both hands hold still and the gun kicks between them. (A target on the gun itself was tried first: the solver can't follow a kick, and the hand was 0.7 studs off for a frame.)
- **After, same measurement:** gun 0.13 studs in a frame at most, 6 reversals in 5 seconds; **both hands 0.000**.
- **Joints:** a mitre (two 45-degree plates) instead of the half-octagon, flat shaded. A right-angle bend is one clean chamfered corner. Block body v2, Model asset 103550484592616.
- **Legs:** the bounce now has the four poses of a run (contact, down just after it, passing, up at push-off); standing legs are dead straight; the range dummies use the players' own run, strafe, jump and fall clips (they were on stock Roblox ones, so the range never showed our strafes).
- Clips re-exported and uploaded as `GG <Name> v4b` (all 40).

### Self-grade (mine, not a blind panel)
| Part | Grade | Why not higher |
|---|---|---|
| Rifle hold | 7 / 10 | Reads as shouldering a rifle from the side and three-quarter. Dead from the front the support arm's block end still faces the viewer. Guns are thin (0.2 studs) next to 1-stud fists. |
| Pistol hold | 6.5 | Clean, but two fists side by side are wider than the pistol. |
| Firing | 8 | Smooth and steady by measurement; no body recoil at all (by choice: RIVALS has none either). Only seen on the dummy's 3-shot bursts, not on a long spray or a shotgun. |
| Legs | 6.5 | Better timing; not re-watched in motion after the change, only stills. |
| Joints / body | 7.5 | Crisp. Knees still show a small step when slightly bent. |

**Not verified in this pass:** the aim up / down poses, reload and draw in the game with the new stance (they were re-solved from it and exported; only the level holds were looked at); every gun one by one (the Vandal on dummies and the pose sheets only); a second real client; a long full-auto spray.

**One thing the owner has to do:** the Rojo plugin in the match place stopped applying changes during this pass (an internal error; it still says connected). Click **Disconnect, then Connect** in the Rojo panel. Until then I copied each changed script into Studio by hand so the place matches the files (`Config/Animations`, `Config/Juice`, `Config/Avatar`, `GripController`, `EffectsController`, `TestRange/Dummies`, `Weapon/WorldModel`).

## 8. Third pass: a skinned body (2026-11-12, Opus session)
**Owner, after §7:** "the joins and bends just don't look correct... the arms just look so unnatural. They're different sizes and bent weirdly. It's not smooth... with the legs for the R15 character". The goal: "smooth animations where the hands and everything are smooth keyframes that line up". During the pass he said "weird distortion in the arms... not smooth" (the pistol dummy), then "the arms are looking better", then "the torso looking a bit weird and overlapping" and "still overlap here with arm and also with legs".

### Seen before (Studio, range dummies, side / front / three-quarter)
- **Elbow:** two rigid blocks with mitre ends. Bent, they read as two boxes stacked at an angle, with the mitre plates as extra facets: a lump, not a limb. The forearm block was 1.012 wide against the upper arm's 1.0 (the "different sizes").
- **Shoulder:** the rifle stance's support arm crossed the chest, the upper arm inside the torso.
- **Waist:** the chest block (turned 38 degrees) hung over the hips block; the hips' inset band showed as a third slab.
- **Hip:** each thigh's mitre ridge poked up through the waist (a dark spike under the arms).
- **Knee:** the same two-box stack as the elbow.
- **Wrist / ankle:** rigid on the forearm / shin (the hand part turned with the gun, the fist didn't).
- **Range dummies:** all carried the Vandal and played the long-gun clip, so no sidearm hold could be reviewed.

### Research and the choice
- **LihFolk:**
  - *Weight Painting and Skinning for Roblox*: three edge loops at a joint, falloff about the joint's thickness, helper bones.
  - *Bones and Skinned Meshes*: Bone.Transform, TransformedWorldCFrame.
  - *Voxel Characters - Proportions Joints and Rigging*: gap, overlap, cap or sleeve joints; elbows and knees under about 90 to 110 degrees.
  - Also *Rigs and Joints*, *IKControl Reference*, *Weapon Swing Design*, *Timing Spacing and Frame Charts*, *Procedural Weapon Motion*.
- **Web:**
  - Roblox skinned R15 bodies deform across joints, and the bones must be named for the rig ([Skinned MeshParts are live](https://devforum.roblox.com/t/skinned-meshparts-are-live/831011), [Rigging and skinning](https://create.roblox.com/docs/art/modeling/rigging), [Skin a humanoid model](https://create.roblox.com/docs/en-us/art/modeling/skin-a-humanoid-model)).
  - Community skinned block rigs exist ([Skinned R15 Robloxian 2.0](https://devforum.roblox.com/t/skinned-r15-robloxian-20-mesh-deformation-rig/2589100), [Classic S15](https://devforum.roblox.com/t/outdated-classic-s15-rig-skinned-meshes/1398759/35), [Dogu15](https://devforum.roblox.com/t/dogu15-rig-layered/532832)). They are rounded, not our faceted style, so we built our own (the owner suggested either).
  - IKControl gotchas: [Weight 0 still bends](https://devforum.roblox.com/t/ikcontrol-still-affects-character-animation-when-weight-0/2523573), [snapping](https://devforum.roblox.com/t/prevent-ikcontrol-from-snapping/3860664).
  - **Not confirmed:** whether RIVALS uses R6 or R15 in third person. No source was found, and the fandom wiki refused the fetch.
- **Options judged:**
  - **(a) Rigid R15 blocks with better ends** (mitre, cap, overlap). Tried twice (§2, §7). Two rigid boxes can't close a bend cleanly at every angle: a cap reads as a lump, and an overlap pokes out at mid angles.
  - **(b) R6-style straight limbs.** No bend problem, but no knees in a run, crouch or slide, and a straight arm can't bring a stock to the shoulder.
  - **(c) IK hands on the grips.** Already in for the support hand (GripController), and it doesn't change how the blocks join.
  - **(d) Chosen: one skinned mesh per limb, on our own rig.** The cross-section is the same from shoulder to fist by construction. A helper bone at each elbow and knee turns half the bend, so the outside of a bend is always two flat plates (no curves, `gauntlet-build-style`) and the inside folds into the neighbour. That is "smooth" the way the owner means it, at every angle, and still a block.

### What was built
- **`tools/blender/make_skinned_limbs.py`** (headless Blender) writes `art-source/body/SkinnedLimbs.fbx` and `.json`, uploaded as Model 135375211904437 (v3d). The meshes are RightArm, LeftArm, RightLeg, LeftLeg and Torso; the bones' bind poses were read back from the import.
  - **Arms:** shoulder top to fingertips, with loops at the elbow (±0.25 studs; 0.35 read as a rubbery slab) and the wrist.
  - **Legs:** the thigh's flat top rides the pelvis (bones `Hip`, `HipMid`), so a raised leg bends out from under the hips and nothing pokes into the waist.
  - **Torso:** one mesh from the neck to the hips. The chest follows UpperTorso and the turn spreads over 1.1 studs of belly (0.5 creased).
- **`shared/MatchBody`** makes each skinned MeshPart and its Bones (`addBones`); `limb` and `skinLimb` turn them from the R15 parts.
  - **The meshes live in `Workspace.GGBodyLimbs`, welded to their part, not inside the character.** The character's Animator rewrites every Bone inside it during the physics step, and the frame is drawn from that. Measured: the transform flipped between our bend and identity every frame.
  - Links: the part has an ObjectValue `BodyLimb` pointing at the mesh, and the mesh an `Owner` pointing at the part. The mesh is destroyed with its part.
- **Twist is dropped from the visible elbow and knee** (`Config/Avatar LIMB_SKIN.twist = false`). The pistol hold turned the right elbow 66 degrees, all of it twist about the arm's own axis, and the skin made a skewed slab. Twist never changes where a forearm points (measured after: visible forearm against the part, 0.00 and 0.02 degrees). The torso keeps its twist.
- **The fist stays rigid on the forearm** (`LIMB_SKIN.tip = false`). The clips turn the hand parts up to 35 degrees for the gun, which bent the end of the block.
- **`Controllers/BodySkinController`** (client) bends every tagged limb each `PreRender`, and each limb's LocalTransparencyModifier follows its part (first person, spectating, death and replay hide the body that way). `Util/BodyClone` gives body copies their own limbs.
- **Support elbow pole** moved out to the side (`Config/Animations GRIP.leftPole`, (-1.2, -2.2, -0.6) to (-2.6, -1.7, -0.1)), so the support arm comes round the chest.
- **Range dummies** carry one gun per class (`Config/TestRange`: Vandal, Sheriff, Operator, Odin, Spectre, Classic, Judge, Bucky), and sidearms play the sidearm hold (`TestRange/Dummies`).

### After (Studio)
- **Elbow and knee:** one block bending, with a two-plate chamfer outside and a crisp fold inside, the same thickness through the bend. Owner: "the arms are looking better".
- **Pistol hold:** no skew after the twist fix; both fists out front.
- **Rifle and sniper:** shouldered, the right arm bent cleanly under the receiver, the support fist under the handguard.
- **Hip and waist:** no ridges and no slab over the hips; the legs sit flush under the torso.
- **Torso:** one piece. Close up, the 38-degree chest turn shows as a twisted side face. The real fix is a smaller turn in the rifle stance (State row 8).
- **Smoothness** (strafing dummy, root space, 60 fps, 3 s): the largest frame-to-frame jump was 0.068 studs for the right fist, 0.148 for the left fist and 0.100 for the gun.
  - The hand-to-grip offset holds constant: 0.52 studs right, 0.67 to 0.72 left. That is the designed "gun on the fist" offset, with no drift.
  - The shooter dummy didn't fire during the sample, so the fire-burst numbers are still §7's (gun 0.13 studs a frame, hands 0.000).

### Self-grade (mine, not a panel)
| Item | Grade | Why not higher |
|---|---|---|
| Elbow and knee bends | 8.5 | Clean at every angle seen. Very tight folds (over about 120 degrees) still overlap on the inside, as any block does. |
| Hip and legs | 8 | Flush, but the waist line still shows a thin bevel lip. |
| Torso | 6.5 | One piece, but the twisted side face reads as a crease close up. |
| Holds (hands on gun) | 7 | Rifle and sniper read well. The pistol sits above and between the fists, not clearly in the right fist (clip authoring). |
| Smoothness | 8 | Measured on the strafe run only. No pops seen between clips, but no fire-burst sample this pass. |

### Not verified
- A second real client, bots in a match, and the death fall, replay and victory scene (BodyClone copies the limbs, but none of these was run).
- Clothing on the skinned meshes: the dummies wear a plain shirt, and template textures weren't checked.
- The cost of skinning with 8 players: 5 meshes and 29 bones per body.
- Mod, flinch, dash and death clips on the new body.

## 9. First-person melee: knife and PopCircuit Bat (2026-11-12)
The owner rejected the ChatGPT (Codex) pass on both: "the way the arms move looks really off, and the way it spins looks off... It should just be very simple". Details in [First-Person Melee Animation](../02%20Art/Skins/First-Person%20Melee%20Animation.md).
- **Knife:** back to the hold from before that pass. The arm runs from the fist straight to `VM.MELEE_SHOULDER`, with no handle-axis twist; ChatGPT's `ViewmodelArms.grip` and its -0.04 grip offset are removed.
- **Bat:** `Util/PopCircuitBat` is rewritten as a few eased keys per move. The 48 fps baked samples (`PopCircuitBatPoses.luau`) are deleted.
  - The bat is rigid in the fist, the arm runs from the fist to the shoulder, and the bat moves with the viewmodel's bob and sway.
  - Idle leans the bat out to the right, so the handle crosses the fist.
  - Two alternating flat swings, with contact at 30% of 0.5 s.
  - A two-handed overhead smash, with contact at 44% of 0.9 s.
  - An inspect that shows the art, dips, flips the bat once end over end on a parabola about its centre of mass, and catches it with an absorb.
  - Studio review: the Workspace attribute `DevBatScrub` (0 to 1) holds a move at that point.

## 10. Run pass, first-person fix, accessories (2026-11-12, late)
**Owner:** "improvements just on the running and everything looking more professional and smooth and fun". During the pass he added "torso looks really off. and hips... torso is way too big and long" and "I can currently see the new parts in first person, like the shirt", then asked for accessories "like hair... that will work in the game".

### Run (tools/anim/tp_clips.py, 22 clips re-exported and uploaded as `GG <Name> v5` / `v5b`)
- **Found:** the feet skated. At 16 studs/s a planted foot travelled 1.8 studs in 0.25 s, about 7 studs/s, so it slid forward under the body. Sprint: about 9 against 22. The crouch walk: 3.7 against 9.
- **Now (standard run-cycle practice: a locked foot, a flight phase, a cadence to match):**
  - A planted foot moves back at a set share of ground speed, with each foot down for about a third of the cycle, so both feet leave the ground between steps (the bounce).
  - The swing is a Hermite curve that leaves and lands with the ground's speed: the heel kicks back, and the foot reaches and pulls in to plant, with no stop-start at toe-off.
  - The bounce is lowest at mid-stance and highest in flight, with a small surge.
  - Cycles: run 0.38 s, sprint 0.36 s (the sprint's upper-body clips share it), crouch walk 0.46 s.
- **Measured** (rig, planted-foot speed against ground speed):

  | Clip | Locked now | Before |
  |---|---|---|
  | RunF | 79% (12.6 of 16) | 45% |
  | SprintRun | 81% (17.9 of 22) | 42% |
  | CrouchWalk | 88% | 41% |
  | Strafes | 65% (by design, so the feet don't cross) | — |
  | Backpedal | 75% | — |

  In the game, my own sprint: the planted sole moves 5.5 studs/s over the ground with the body at 20.9 (the old clip worked out to about 12).
- **Torso looked "too big and long":** standing, the body has exact classic blocky proportions (torso 2.0, legs 2.0, head 1.2; measured). It was the first lock version's hips, 0.27 studs low, which made the legs look short. The run stands about 0.1 studs taller now and locks 79 to 81% instead of about 96%. The hip bend was tightened to 0.15 studs (0.25 bulged the hips): body mesh v3e, Model 70932856136134.
- **Rifle stance:** chest turn 38 to 26 degrees (`CHEST_TURN`), for the torso crease.

### Torso: shorter, with shoulders
**Owner:** "the torso is still too long... see how it goes in the head". Measured: the skinned chest top, the UpperTorso top and the head's bottom all sit within 0.02 studs of each other, so nothing was misplaced. The flat 2-stud-wide top stood up beside the 1.2-wide head, and from eye height its corners read as the torso rising past the chin.
- The top now narrows to the neck in angled plates (a 0.38 drop to a 0.66 half-width).
- The hip line is 0.15 studs higher: the torso is 1.85 tall, and the thighs' tops cover the rest.
- Body mesh v3f, Model 95076913639057 (only its torso mesh is used).
- Seen on the Sheriff dummy from the owner's angle: the head sits on the torso, and the arms read as the shoulders.

### First person
Your own body's clothing showed in first person. The limb mesh was hidden, but its clothing Textures each have their own LocalTransparencyModifier. `BodySkinController` now copies the part's modifier to the mesh and its Textures (only when it changes). Checked: looking down in first person shows only the viewmodel.

### Accessories
- **Found:** the owner's avatar wears one accessory, a hair (3016139459), and it is **layered**, as most hair on the catalogue is today. `MatchBody.description` copied only the old rigid string fields (`HairAccessory`...), and `filterAccessory` deleted anything with a WrapLayer, so the hair never arrived.
- **Now:**
  - The accessory list is copied with `GetAccessories(true)` / `SetAccessories`, so both rigid and layered items come through.
  - Layered items are kept only for head types (`Config/Avatar ACCESSORY_LAYERED`: Hair, Hat, Face, Eyebrow, Eyelash). They wrap the engine's own head, which we still draw.
  - Layered clothing is still removed: it would wrap the invisible R15 body under our blocks.
  - Size caps and effect stripping are unchanged, and accessories never take hits.
- **Checked:** the owner's hair shows on his match character and fits the head.

### Not verified (this section)
- Other players' accessories: rigid back, waist and shoulder items riding the skinned torso; big layered hats.
- The run at walking speeds below about 10 studs/s (the clip rate clamps at 0.6, so a little slide).
- Landing, jumping and sliding into and out of the new run.
- A second client.

## 11. The real torso bug, R15 proportions, knife and bat polish (2026-11-12, late)
**Owner:** "the torso... is still just way too long and tall. really grade it... I added preset R6 and R15 models in Workspace", then "the legs also look a bit too long". He also said "the knife... sits above the hand which is weird", "make the bat animation feel nicer and less robotic", and that a downloaded rig was worth trying only if the current path wasn't working.

### Found: the importer had mixed up the bones
- **Side by side with the presets:** standing height and head height matched, but our torso's top edge rendered about 0.5 studs above the chin.
- **Isolated it:** with every torso bone at rest (all Transforms identity), the torso still drew about 2.5 studs tall instead of 1.65.
- **Cause:** all five meshes in `SkinnedLimbs.fbx` used the same bone names ("Upper", "Mid1", "Lower"...). Roblox's importer merged same-named bones across armatures. The first upload's listing shows four "Upper" bones and no torso bones at all, so each mesh was bound to another armature's bind pose. That drew the torso too tall, up past the chin, and stretched the legs, in every version from v3a to v3g.
- **Fix:** every bone name is unique per mesh (`Config/Avatar Skin.prefix`, e.g. "RightArmLower", "TorsoUpper"). `MatchBody` builds and finds the bones by those names. The v4 import (Model 112809907225612) lists each mesh's own bones.
- **Proportions back to R15 exactly:** a plain 2 x 2 x 1 torso box (the owner preferred the box to the sloped shoulders), and 2.0 legs with their tops tucked into the hips.
- **Checked side by side with the owner's R15 and R6 presets** (two of our dummies, a Sheriff and a Vandal): the head sits on the torso at the same height, and the torso and legs are the same lengths.
- **Grade before the fix:** torso 5/10 (it read long, rightly). After: 8/10, R15 proportions with a clean bend.
- **Rig choice (owner's question):** kept our own skinned blocks on Roblox's R15 skeleton. The skeleton is the proven part, and the joints the owner liked came from the skinning. The fault was the import, not the approach.

### Knife
- The fist sat 0.28 studs below the grip (the knife "above the hand"). The ChatGPT pass had replaced the melee hand choice (`VM.MELEE_HAND`) with the rifle's.
- Restored as in the last commit. The handle now goes into the top of the fist, and only the guard and blade show.

### Bat: less robotic
- **The cause was my own easing:** every segment eased in and out, so the bat came to rest at every key.
- **Now:**
  - Cubic Hermite splines through the keys with Catmull-Rom tangents in time (an animation editor's "auto" tangents). Speed carries through each key, and how fast the bat moves comes from the key spacing.
  - Two follow-through springs (`FOLLOW`): the fist lags a touch, and the barrel trails the hand by at most 40 degrees, so a swing overshoots and settles.
  - The bat stays rigid in the fist.
- **Two bugs found by measuring and fixed:**
  - A plain vector spring pulled the bat through zero length on the smash's reversal, and the bat jumped 1,272 studs for a frame. It is now kept a unit vector, capped at 40 degrees of lag.
  - One spring step per 60 fps frame at 11 Hz diverged. It is now sub-stepped at 240 Hz.
- **Measured after** (bat tip, camera space, per frame):

  | Move | Peak step | Largest change between frames |
  |---|---|---|
  | Swings | 2.5–2.8 studs | 2.5 (at the launch of the strike) |
  | Smash | 1.15 | 0.48 |
  | Inspect, toss and catch | 0.50 | 0.21 |

### Bat pull-out
- **Owner:** "bat need a pull out animation". Equipping the bat used to return early and play nothing.
- **Now** (`Draw` clip, played on equip, the springs reset at its start):
  - the bat comes up from low right, below and behind the view, hanging by the hand;
  - it sweeps up and out with the barrel leading;
  - it rises a touch past the idle, then settles into it.
- No 360 twirl: the owner found the knife's unnatural.
- **Measured:** largest step 0.76 studs a frame, largest change 0.40. The mid-draw frame was looked at.

### Not verified (this section)
- The bat and knife played by hand at full speed (measured and held frames only).
- The v4 body in a run, crouch or slide (only standing and the hold poses were compared with the presets).
- A second client.

## 12. Melee pass: video reference, weapon across the fist, inspect restart (2026-11-12, late)
**Owner:** "I dont really like the swings with the bat... weird angles", "the knife swings... the way the bottom of the knife goes through the hand looks off", "use the video skill to look at videos of similar games", and about the inspect, "you can just spam it to restart the inspect, I want that".

### Reference
Valorant melee light attacks, studied frame by frame with the video analyzer ([ALL NEW KNIFE ANIMATIONS, Yezzan](https://www.youtube.com/watch?v=squ8T4HZc0k), 0:20 to 0:23, 10 frames). A RIVALS bat source wasn't found (search: no bat in RIVALS' melee list).
- **The blade stays across the fist,** at roughly 90 degrees to the forearm, through the whole swing. The handle sits inside the hand and never runs along the arm.
- **Cuts are diagonals:** high right, down across the crosshair to low left with the blade leading flat, a wrap-round, then a backhand return.
- **The free hand counter-swings** the other way.

### What changed
- **Bat swings redrawn** (`Util/PopCircuitBat` SlashLeft / SlashRight):
  - Forehand: cocked high on the right, a diagonal cut down through the crosshair to low left, wrapping round.
  - Backhand: wound low on the left, a rising cut to high right.
  - The bat is kept at least 65 degrees from the forearm's line (`BAT_MIN_ANGLE`, `acrossArm`), so the handle always crosses the fist.
  - Checked: the coil and contact frames show the handle through the side of the fist with the knob out the other side.
- **Knife:** the forearm is kept at least 62 degrees from the blade's line (`Config/Viewmodel MELEE_ARM_ANGLE`; `acrossBlade` in ViewmodelController, applied last, against the BladeBase to BladeTip line).
  - Measured, the smallest arm-to-blade angle: slashes 6 to 13 degrees before, now about 43; heavy stab 13 before, now 58; idle 62.
  - 72 was tried and rejected: it forced the idle arm flat in from the side.
- **Inspect:** pressing inspect again restarts it from the top (bat, knife and guns). A draw, reload or swing still blocks it.

### Not verified
- The swings played by hand at full speed (held frames and per-frame angles only).
- The bat smash after this change (unchanged keys, but under the new rule).
- The free hand's counter-swing for the bat: not added.

## 13. Final audit (2026-11-12, late)
An independent code review (a fresh reviewer, read-only) plus a Studio sweep. Found and fixed:

| # | Severity | Problem | Fix | Checked |
|---|---|---|---|---|
| 1 | High | Bots had no arms or legs. `BotService` dressed the cached template once (unparented), and every bot is a clone, so each clone's `BodyLimb` link pointed at the template's mesh and the template's meshes fell loose in `GGBodyLimbs`. | Each bot is dressed after it is cloned and parented; the template isn't dressed. | Stand-in in a playtest (template, clone, parent, dress): 0 meshes from the template, 5 of its own per clone, 0 orphans after removal. |
| 2 | Medium | An inspect could start in the middle of a knife swing (the restart check didn't look at the Swing track). | `inspect()` refuses while `playing.Swing` is live. | Code read. |
| 3 | Medium | The death fall's arms and legs didn't fade (the copy's limb meshes live outside the copy). | `DeathFxController` fades the linked limb meshes and their clothing too. | Code read. BodyClone checked live: a copy gets its own 5 limbs, all gone after destroying it. |
| 4 | Medium | A leg's cached state kept a dead pelvis if LowerTorso was rebuilt or streamed out. | `BodySkinController` re-resolves when `root` is gone. | Code read. |
| 5 | Low | A zero or undefined vector could make the bat NaN, and the module-level springs would keep it. | `batAt` guards, and the springs restart on NaN. | Lint; the measured swings are unchanged. |
| 6 | Low | Per-frame cost: recursive FindFirstChild for the knife blade, toss end poses re-sampled each frame, closures each call. | Blade attachments cached per viewmodel, toss ends cached per clip, `tangent` and `spring` at module level. | Lint. |

**Also measured:**
- **Skinning cost:** 0.26 ms a frame for 13 bodies (65 limbs, 4 µs each), about 0.16 ms for 8 players.
- **Death:** a death leaves no meshes behind (65 before and after, 0 orphans).
- **Final checks:** `selene`, `stylua --check` and `rojo build` are clean.

## 14. Grades: every animation and gunplay system (2026-11-12, late)
My grades, out of 10. They come from what was measured or seen this session plus the latest status in the vault (`Gunplay.md`, Feel Passes 2 and 3, Hit and Shot Feel, Home). "Seen" means looked at or measured in Studio; "unplayed" means no human has played it since the last change. Not a blind panel.

### Third person (what other players see)
| System | Grade | Evidence | To work on |
|---|---|---|---|
| Body joints (skinned limbs) | 8.5 | Clean bends at every angle, no twist skew, owner: "arms are looking better" | Very tight folds (over 120 degrees) still overlap inside |
| Body proportions | 8 | Matches the R15 preset side by side after the bone-name fix | Owner to confirm |
| Shooting (what others see) | 8 (was: only the gun moved) | §23: the recoil goes through the arms and chest by a spring over 12 recoil poses; measured on a dummy: a rifle shot 3.3 degrees muzzle, 2.2 chest, hand 0.13 studs; no frame jump over 0.125 studs | One dummy, one gun; a second player's view; pistols and snipers by eye |
| Rifle / SMG / sniper holds | 8 (was 7) | The gun now rides on the visible fist (twist 0, wrist 0), elbow opened to 55-78 degrees (§16) | Unplayed; the support hand's IK wrist not measured |
| Sidearm hold | 8.5 (was 8; owner: "looks weird") | §21: a Weaver stance, the right arm straight out from its shoulder (was across the chest), the gun at chin height pointing dead ahead; one-handed low-ready sprint | Owner to look again; a second player's view |
| Run / sprint | 9 (was 7.5) | §19: feet stand on an edge pinned to the ground: lock 98% rig, 96% engine, no floor sink; a walk set below 12.5 studs/s, one shared cycle rate | Owner to play |
| Strafe / backpedal | 8.5 / 9 (was 6.5) | §19: side shuffle in lanes (shins never meet), 8 directions with real diagonals; engine lock 89-96% | Owner's eye on the shuffle; front silhouette a bit compact; a second player's view |
| Crouch walk | 8.5 (was 7) | §19: 8 directions, 0.3 s steps, engine lock 87-98%, no sink | Unplayed; not captured from outside |
| Jump / fall / land / slide | 8.5 (was 6) | §19: keyed as controls, solved per frame (sinks 0.44-0.76 → under 0.01), timed to the 0.38 s jump; Land only when landing slow; slide in/out end in the run's footfall; slide hold 9; §20: pistol and knife slide with their own arms, idle stance flat (dig 0.16 → 0.02) | Jump/fall seen frozen only; slide in/out hands fast at the impact |
| Reload / draw | reload 8 (was 6); draw 6 | §22: the rifle reload stood the gun up over the head with the forearm across the face (seen in play); re-keyed as a low-ready swap (v7), seen in play from two angles | The stock comes up near the chin; pistol reload and the draw not looked at in play |
| Mod / flinch / dash / Updraft / death / victory | 7 (was 3) | Re-authored on the rig, solved per frame, checked every frame, six reviewed in the engine (§15) | Unplayed in real use; Lob, Cast, Heal, Updraft, dive and Flinch seen on the rig only |
| Accessories | 7 | The owner's layered hair works; caps and stripping unchanged | Test big hats and back items |

### First person
| System | Grade | Evidence | To work on |
|---|---|---|---|
| Gun hold, sway, bob | 8.5 | §18: the sprint limp is gone (step dips were 0.20 / 0.36 s apart, now 0.28 / 0.30 / 0.30 s, equal depth; bob turns around the gun line) | Owner run check; no RIVALS run footage side by side; bob vs. footstep phase not synced |
| ADS (aimed strafe lean, aimed fire) | 8.5 | Sight held within 4 px strafing; pass 5: aimed shots push the gun 4x more (0.058 studs, Vandal) with the sight within 5-12 px on rifles / SMGs | Sheriff aimed flip 43 px (its own clip) |
| Fire kick / recoil | 8.5 | Pass 5: the screen jolts with the shot (camera peak 13-19 ms, was 83-119), a per-class look-only view punch, burst home in ~0.15 s with a settle (was 0.43-0.67 s) | Owner hasn't fired it; view punch sizes are first picks |
| Reload / draw / inspect | 8.5 | §18: anticipation, fast move, overshoot, settle on every move; reload lifts up and in with the swap on screen (RIVALS / Valorant study); slap and clack land on each gun's seated mag | Owner play; only Vandal and Classic measured (Sheriff, Outlaw, shell loops, belt guns not checked) |
| Knife | 8.5 (was 7; owner: "the arm flicks") | §21: no single-frame flips left (worst was 171 degrees in a frame), smooth blade turn, natural elbow, eased wind-ups | Owner to play the combo again |
| PopCircuit Bat | 7 | Diagonal cuts on splines, follow-through, pull-out, toss inspect; measured smooth | Unplayed; the off hand's counter-swing isn't in |

### Gun feel
| System | Grade | Evidence | To work on |
|---|---|---|---|
| Spread / bloom | 6.5 | Numbers in Gunplay §2; client cone since Server Authority went off | A human playtest |
| Hit markers, kill feedback | 8.5 (visuals; was 7) | 2026-11-13 lane F ([Hit Feedback Pass](../05%20Production/Playtests/2026-11-13%20Hit%20Feedback%20Pass.md)): whole-body white → red flash and slash (limb-mesh bug fixed), headshot flash pop and orange highlight, kill flash on the death copy, one pop per hit; timed and costed in Studio | The owner's eye at full speed; hit sounds still the owner's ear |
| Gun sounds | 6.5 | 18 designed guns (atlas v2), waiting on the owner | Footsteps aren't built |
| Muzzle flash, tracers, impacts | 7 | Stylised; checked on the shooter only | Another player's view (second client) |

### Movement
| System | Grade | Evidence | To work on |
|---|---|---|---|
| Run (auto-run) | 7 | Built 11-11 | — |
| Slide | 7 | Owner 11-10: "much better" | His test list is pending |
| Jump (4.4 studs) | 6.5 | Owner asked "is it enough?" | Map jumps were built for 5.6: check them |

### Work on next (in this order)
1. ~~Third-person Mod, flinch, dash, Updraft, death and victory clips~~ done (§15); next, play them in real use.
2. ~~The sidearm hold (5/10)~~ done (§16); ~~the knife clips on the rigid fist~~ done (§17).
3. A two-client playtest: what another player really sees (holds, IK, VFX, accessories).
4. The owner plays the first-person list (reload, draw, inspect, knife, bat, a long spray), then a punch-up pass on what he flags ("still feels a little stale").
5. Footsteps (not built), and the map jumps against the 4.4-stud jump.

## 15. Mod, dash, Updraft, flinch, death and victory clips re-authored (2026-11-12, late)
**Owner:** "Yes, start those", then "goal is everything to 9-10" and "your goal is professional, well done, high quality... take your time". These were the weakest set at 3/10: Studio-generated clips made for the old thin-arm body. The victory was Roblox's Cheer emote as a placeholder.

### Method
All 16 clips are now in `tools/anim/tp_clips.py`, on the same rig as the holds and runs (`ModHold`, `Throw`, `Lob`, `Cast`, `Place`, `Heal`, `DashForward/Back/Left/Right`, `Updraft`, `UpdraftSlam`, `UpdraftSlamLand`, `Flinch`, `Death`, `Victory`).
- **Keys are controls, solved every frame** (`ctrl_sequence`): hand and foot targets, hips and chest are blended, then solved per frame. Blending solved joint angles (the old way) swung planted feet through the floor between a kneel and a stand.
- **One-shots blend into the gun hold** they hand back to, so nothing pops in or out.
- **Dash and flinch key only what they must:** the dash keys hips and legs (a planted lunge), the flinch hips and head. Keying the chest would wipe the rifle stance's chest turn.
- **Checked by a script on every frame of every clip** (in the session scratchpad): arms inside the chest, parts under the floor, and the hand's largest step a frame. Final pass: 0.00 arm-in-chest on all 16, floor at most 0.01 studs, swing peaks 1.2 to 2.2 studs a frame (the throw's release, by design).
- **Reviewed in the engine** on a range dummy and on a BodyClone copy (how death and victory play in the game).

### Review rounds (what I changed after looking)
1. **ModHold:** the item at head height hid the face, and the bent free arm read as a boxer's guard. Now the item is cocked back at the shoulder and the free arm points straight at the target.
2. **Throw:** a 40-degree chest turn over the run's hips twisted the torso like a screw. Turns are now within 22 degrees, and the pointing arm is straight.
3. **Place:** a deep forward kneel crumpled into a lump. Now an upright kneel: right knee down, left knee up, the hand reaching the floor.
4. **Slam landing:** hips 1.6 low with the chest folded was a lump. Now the chest is up, the head looks ahead, the free fist is planted on the floor and the gun is out wide.
5. **Death:** an arm stuck out at the waist (its target didn't sink with the body). The arms and gun now hang with the slump.
6. **Victory:** a lean back put the head behind the raised fists, then bent knees with wide poles read as bow-legged. Now upright, the gun up beside the head, the fist pumping wide, a small knee bounce.

### Bug found while reviewing (fixed)
BodyClone copies carried the support hand's IKControl, still switched on. On the death fall, the final-kill replay and the victory scene, the copy's left hand stayed pinned to the gun. It showed up as the victory's left arm crossing the face; the joint read 140 degrees away from the clip, and the asset itself was checked correct. `Util/BodyClone` now strips IKControl. Checked: 0 IK on a copy, and the left hand at the clip's position (-1.79, 1.95).

### Not verified
- In the engine I looked at ModHold, Throw, Place, Death, Victory, the slam landing and DashForward. Lob, Cast, Heal, Updraft, the dive, Flinch and the side and back dashes were checked on the rig only.
- None of them is triggered by real play yet: a Mod use, a dash, an Updraft, a hit, a death or a match end.

## 16. Sidearm hold, and every gun on the visible fist (rigid-fist pass, 2026-11-12, late)
**Owner:** "Yes, sidearm hold" (Bugs #6: the pistol sat above and between the fists, not in the right fist).

### Root cause (bigger than the sidearm)
The skinned arm's fist is rigid on the forearm: no wrist bend, no forearm twist (§8, the owner rejected the twist skew). But every hold clip still bent the hidden hand part and twisted the forearm to point the gun, and the gun is welded to that hidden hand. Measured on the old clips (right arm):

| Clip | Forearm twist | Wrist bend |
|---|---|---|
| PistolAimLevel | 66 deg | 35 deg |
| AimLevel | 32 deg | 40 deg |
| AdsLevel | 50 deg | 59 deg |
| SprintPistol | 6 deg | 65 deg |
| PistolReload | 64 deg | 58 deg |

So on every gun the gun sat off the visible fist. The pistol showed it worst: small gun, big twist.

### The fix: the rigid-fist rule, in the rig and the game
- **`tools/anim/tp_rig.py` rigid-fist solve** (the default for a gun in the right hand):
  - The hand IS the forearm's end: no wrist bend.
  - The gun's angle on the fist fixes the forearm.
  - The gun slides, keeping its turn, until the elbow is an upper arm's length from the shoulder.
  - The upper arm takes the roll that leaves the elbow twist-free.
  - Measured after, every gun clip: forearm twist 0.00 degrees and wrist bend 0.0 degrees.
- **Two grips, one per kind:**
  - **Long guns:** the pistol grip goes down into the fist's end, the barrel off its front, and the forearm runs out, down and back from the grip (`LONG_FOREARM`, worked out from where the elbow can sit in the hip and sights holds).
  - **Sidearms:** the barrel along the forearm, on the fist's front face (arms out).
  - `Config/Animations GUN_WORLD_GRIP` and `GUN_WORLD_GRIP_SIDEARM`; `Weapon/WorldModel` picks by class. `python -I tools/anim/tp_rig.py grips` prints the matching values.
- **Holds moved a stud further out** (`HIP_GUN`, `SIGHT_GUN` z -0.6 to -1.0) so the right elbow opens. Visible elbow, tightest point:
  - Holds: 45 to 78 degrees (was a 35-degree fold).
  - Pistols: 84 to 108 degrees (arms out).
  - Reload: 52 to 57.
  - Long stocks still reach the shoulder.
- **Tips and swings turn about the real shoulder:**
  - A new `gun = {"shoulder": (pitch, yaw, roll)}` control turns the hold about the shoulder wherever the chest and hips put it, so the arm keeps its shape.
  - Used by the reload tip, death, victory, the dive and the slam landing.
  - Before, a muzzle-up tip folded the elbow to 4 degrees.
- **Pistol reload:** the tip is eased from 50 to 26 degrees up, so the elbow stays at 57 or more.
- **Uploaded:** 29 clips as `v6` (holds, pistol set, sprint, reload, draw, slide, Mod clips that end on the hold, death, victory, slam).

### Checked in Studio
- **Measured** on five range dummies (Sheriff, Vandal, Operator, Odin, Spectre): the gun's handle sits at the same point on the visible fist for every gun of a kind, and the hand matches the visible fist exactly (a constant frame offset).
- **Sheriff from the right:** the revolver's grip goes into the right fist, the gun above and forward on an extended arm. It reads as holding a pistol.
- **Vandal from the right:** the fist round the pistol grip under the receiver, stock at the shoulder, support hand on the handguard.
- Every clip passes the per-frame check: no arm in the chest, no new floor sink.

### Open
- ~~Knife clips~~: done in §17.
- **The support hand** is placed in the game by GripController's IK. Its wrist can still bend in a way the rigid fist doesn't show; not measured.
- Not played by hand; no second client.

## 17. Knife on the rigid fist (2026-11-13)
**Owner:** "Yes, knife next" (open from §16: the third-person knife clips were still authored the old way).

### What changed
- **New melee arm control in `tools/anim/tp_rig.py`:** `right_arm = {"fist": point, "blade": direction}` with `right_pole`.
  - A two-bone solve puts the fist's centre on the point, with the elbow toward the pole, so the arm always reaches. No gun sliding.
  - The forearm runs from the fist to that elbow with no twist and no wrist bend.
  - The fist rolls about the forearm so the blade points as asked, squared up across the fist: a hammer grip, as in first person.
- **Bug found while checking:** I first ran the blade along the hand's X. On the model, the knife's blade comes out of the fist's FRONT (the hand's -Z, measured: blade direction in the hand's frame (0, 0.02, -1.00)). The first upload had the blade pointing back into the chest; fixed and re-uploaded.
- **`tp_clips.py` `kfist(fist, pole, blade)`:** KnifeReady, the three slashes, the heavy and SprintKnife are re-keyed with it.
  - Swings now blend controls and solve every frame (`ctrl_sequence`, moved above the knife section), so the fist stays on its path and the elbow never folds shut between keys.
  - Ready: the fist out in front of the right chest, blade up and leaning in.
  - Coil: pulled back beside the shoulder.
  - Thrust: straight out.
- **Range:** a knife dummy (`Config/TestRange`, label KNIFE), which plays KnifeReady (`TestRange/Dummies` picks the knife hold for melee).
- Uploaded as `GG <Name> v6b`.

### Measured
| Clip | Visible right elbow, tightest point |
|---|---|
| KnifeReady | 51 deg (was 13-16) |
| Slashes | 37 to 41 (only for a frame, on the wind-up) |
| Heavy | 58 (was about 2) |
| SprintKnife | 35 |

- Forearm twist and wrist bend: 0.
- On the knife dummy, the handle sits at the same point on the visible fist, and the hand matches the fist.
- Every clip passes the per-frame check.

### Seen in Studio
- **Ready (three-quarter):** the blade up out of the right fist in front of the face, the free fist beside it.
- **Forehand at contact (front):** the blade sweeps flat across the body out of the right fist, the free hand held back.

### Not verified
The swings at full speed in a real swing (the server's SwingAt stamp); the knife on a second client.

## 18. First-person feel pass 4 (lane B, 2026-11-13)
Full note with references, before / after numbers and grades: [First-Person Feel Pass 4](../05%20Production/Playtests/2026-11-13%20First-Person%20Feel%20Pass%204.md).
- **Reload / draw / inspect:** re-keyed in `Config/Viewmodel` TRACKS. Each move has a small anticipation, a fast move past its pose, a settle, and lands past the hold with a bounce. The reload lifts up and in (muzzle ~20°, roll 35-40°, raised and pushed out), so the mag swap is on screen, as in RIVALS and Valorant.
- **Beats match the gun:** tracks carry `marks` and are time-warped onto each gun's own clip beats (`alignTrack`).
- **Mag-in timing bug fixed:** the clips' MagIn markers sat mid-travel (up to 0.5 s early). The clack and bump now land where the mag seats (`clipBeats`).
- **Run:** the bob turned around a point 0.31 studs left of the gun line, so its roll lifted the whole gun on alternate steps (a limp). It now turns around `BOB_PIVOT` on the gun line, and sprinting dips at the ends of the swing (`BOB_RUN_SHIFT`). Measured: even dips.
- **Spray:** first-shot slam and per-shot variation (`SPRAY_FIRST`, `SHOT_VARY`), still smooth.
- **Not verified:** guns other than the Vandal and Classic; the owner's eye; the sound timing change (lane C).
- **Shot feel pass 5 (same day, [note](../05%20Production/Playtests/2026-11-13%20Shot%20Feel%20Pass%205.md)):** the camera kick now lands with the shot (13-19 ms, was 83-119), there is a per-class look-only view punch (`CameraController.viewPunch`), aimed shots kick the gun per class, a burst lets go and settles in ~0.15 s, the Sheriff reload no longer turns ~100° in 0.3 s, and shell-by-shell reloads jolt per shell and land. Every class was measured.

## 19. Third-person movement pass 4 (lane A, 2026-11-13)
Lane A of [Handoff - Grades to 9-10](../05%20Production/Handoff%20-%20Grades%20to%209-10.md). Every leg, air, crouch and slide clip re-keyed in `tools/anim/tp_clips.py`, a walk set and the diagonals added (49 clips with ids), `Simulation/Poses` reworked. Grades in §14 updated.

### Found first (measured)
- **New tools:** `tools/anim/tp_check.py` (per frame at 60 Hz: floor sink of the shin/foot block, the lock of the corner a planted foot stands on, shin-to-shin distance, arms in the chest, the largest hand/foot step a frame) and `tools/anim/tp_render.py` (shaded block pictures of any clip from the side or front, with ground marks, for looking without Studio).
- **The block leg has no ankle** (`Config/Avatar LIMB_SKIN tip = false`): the foot is rigid on the shin. So a "locked" sole centre still rocks as the leg sweeps over it, and a tilted shin digs a corner in. Measured on the old clips: every run dug 0.23-0.31 studs under the floor; run lock (the planted corner's speed over the ground) 76%, sprint 81%, backpedal 33%, strafes 22-24%.
- **The strafes' shins passed through each other** (0.01-0.06 studs apart). The 65% lock didn't stop the feet crossing; it only hid part of the slide.
- **Jump / Land / SlideIn / SlideOut blended solved poses:** the landing dug 0.44 under the floor, SlideIn swung a leg 0.76 through it, SlideOut 0.46.
- **The Land played at full weight over the run:** landing from a running jump froze the legs for 0.34 s at 16-22 studs/s (a skate).
- **Slow movement had no clip:** aimed movement is 6.4-12.8 studs/s (`adsMoveMultiplier`), but the run rate was clamped at 0.6 (9.6 studs/s), so the feet skated backwards below that.
- **Jump and Fall are Roblox Animate's** (`Config/Animations ANIMATE`): Jump plays ~0.31 s, then Fall. A flat 4.4-stud jump is airborne 0.38 s (0.21 s up, 0.17 s down at 1.6x gravity), so the Jump clip is nearly the whole jump.

### Research
- LihFolk (via `lihfolk-lookup`): *R15 Run Cycle Key Poses* (contact, down, push-off, flight; pelvis within 8°; rate = speed / clip ground speed), *Locomotion Systems* (gaits that cannot slide; phase-preserving gait swaps; Land only when slow and airborne a while), *Timing Spacing and Frame Charts* (a landing is 2-4 frames down, 4-8 back up), *Playback, Priorities and Blending*, *Locomotion Readability - Lessons from Blind Panels*. Strafe, backpedal, slide and lean are not in LihFolk.
- Web: animators and players dislike cross-step strafes on shooter characters (clumsy, slow to change direction); the ask is a step-out / step-in shuffle ([Arma Reforger feedback](https://feedback.bistudio.com/transactions/detail/PHID-XACT-TASK-mq3jj4dd3iqgham), [UE forum, legs crossing in 8-way](https://forums.unrealengine.com/t/legs-crossing-during-8-waymovement-animation/1814003)). An 8-way directional set is the usual fix for diagonal foot paths ([Locomotion blend-tree guide](https://mocaponline.com/blogs/mocap-news/locomotion-animations-game-dev)). No usable RIVALS / Valorant third-person strafe footage was found (Riot's animation posts cover weapons and abilities).

### What changed
- **Gait engine** (`Gait` in `tp_clips.py`): a planted foot stands on whichever sole point is lowest (an edge, then a corner, heel side to toe side) and that point is pinned to the ground, carried back at exactly the ground speed; when another point gets lower, it takes over where it is (the block rolls like a rocker sole). The swing is a Hermite curve that leaves and lands at 90% of the ground speed. Hips: lowest a beat after footfall, a surge, turn and roll with the stride, a lean into the travel.
- **Eight directions** for the run, the walk and the crouch walk (`dir_gait`, `dir_clips`): forward or back settings at 0/180°, the side shuffle's at 90°, interpolated for 45/135°. Forward-left and back-right put the right foot ahead (the lanes must lie across the travel, or the feet run into each other).
- **Strafes are a side shuffle:** the lead foot lands, the trail foot closes to it 12% of a cycle later (never past it), then a low hop; the feet run in lanes (left foot 0.4 ahead) so the shins never meet. Quicker steps than the forward run (0.22 s cycle against 0.38) so each foot sweeps 1.6 studs, not 2.2. After the first engine look (a squat, crouched hop from the front) the hop got shorter, the lift lower and the hips higher: knees bend 60° on average, the forward run's 92°.
- **A walk set** (WalkF ... WalkFL, made for 10 studs/s, each foot down 58-60% of the cycle, no flight) for aimed and slow movement; the run set takes over from 12.5 to 15 studs/s.
- **Crouch walk:** 0.3 s cycle (was 0.46: a folded leg can't reach a long stance, its shin lay flat), hips at -0.98, crouch hold raised to -1.12 (was -1.22) to meet it; crouch side lanes wider (0.55) because crouched knees reach forward.
- **Jump:** take-off (legs still extended), knee drive (left knee up, right leg trailing), tuck at the apex (0.18 s), legs reaching down at 0.32 s, keyed as controls and solved per frame. **Fall:** the reach with a slow pedal. **Land:** feet down where the reach had them, a 4-frame drop into a squash (hips -0.58), a hold, up with a small overshoot, 0.36 s.
- **Slide:** SlideIn 0.28 s (the run's stride, the lead leg kicks out, the right folds under, the hips drop past the slide's height and settle; the left hand rides the gun through the kick, then its target travels in space to the floor); the slide hold kept, both feet clamped to the floor; SlideOut 0.3 s (the extended foot plants, the body rises over it and lands in the run's right footfall). The upper body cross-fades from and back to the hold's own joint values, so nothing pops into or out of the run.
- **Keys every 1/60 s** for leg clips and the quick one-shots: the engine blends joint turns linearly between keys, and at 30 a 0.22 s strafe has 7 keys, so the feet cut corners. Replaying the 1/30 keys on the rig gave the engine's numbers exactly (back-left run 0.068 under the floor, crouch-left 82.6% lock); 1/60 gives 0.000 and 98-99%.
- **`Simulation/Poses`:**
  - eight-way weights (the two clips either side of the move), snapped to one clip within 15% of a step (`DIRECTION_SNAP`);
  - every leg clip plays at one cycle rate (ground speed over the blended stride) and follows the heaviest clip's phase (`inStep`), so walk/run/sprint cross-fades and clips of different lengths stay in step;
  - the Land plays at a weight that falls from 1 at 6 studs/s to 0 at 12, and only after 0.2 s in the air (`Animations.LAND`);
  - SlideOut lines every leg clip up so the run's own footfall comes when it ends (`footfallIn`);
  - **a bug found and fixed:** pose tracks the cache had lost (stopped and re-adopted in one step, or started past the Animator's 16-track limit) kept playing, at 0.001 or stuck at full weight, for good. In one strafing test 21 tracks were playing and three leg clips sat at full weight while standing still. `sweep` fades out and stops any pose track the cache isn't driving. After: peak 10-11 tracks, nothing left playing when you stop. (The hold's AimDown / AdsLevel / Sprint leaked the same way before this pass.)
- `Config/Animations`: ids for all 49 clips (`GG <Name> v9` for the 1/60-keyed set), `WALK_CLIP_SPEED`, `WALK_RUN`, `DIRECTION_SNAP`, `RUN_RATE` 0.25-1.8 (only guards the ends now), `LAND`, `SLIDE_OUT_LENGTH`, `CROUCH_WALK_LENGTH`.
- `ctrl_sequence` and `_mix_ctrl` moved above the locomotion section (unchanged; a `solver` option added); all 40 other clips' keyframes are byte-identical to before.

### Measured
Rig (`tp_check.py`, 60 Hz; lock = the standing corner's speed over the ground against the ground speed):

| Set | Lock | Floor sink | Shins apart (min) |
|---|---|---|---|
| Run F / FR / R / BR / B / BL / L / FL | 98.3 / 98.7 / 98.1 / 99.3 / 97.8 / 98.9 / 97.0 / 98.1% | ≤ 0.001 | 0.98 |
| SprintRun | 95.8% (was 81%) | 0.000 (was 0.31) | 1.18 |
| Walk (8) | 92.4-99.8% | ≤ 0.001 | 1.00 |
| Crouch walk (8) | 94.4-99.8% | 0.000 | 0.93 |
| Jump / Fall / Land | — | 0.003 / 0.002 / 0.009 (Land was 0.44) | 1.16 |
| Slide / SlideIn / SlideOut | — | 0.009 / 0.008 / 0.008 (were 0.16 / 0.76 / 0.46) | 1.15 |

In the engine (my character, real game code, a clean floor patch at (-80, 330), 0.9-1.4 s per direction, net drift of each planted stretch so the engine's uneven root steps cancel; floor = root − 3):

| Mode (speed) | F | FR | R | BR | B | BL | L | FL | Sink |
|---|---|---|---|---|---|---|---|---|---|
| Run / sprint (15.2 / 21) | 96 | 94 | 90 | 92 | 96 | 91 | 89 | 94% | ≤ 0.02 |
| Aimed walk (11.7) | 98 | 97 | 95 | 93 | 94 | 96 | 97 | 98% | ≤ 0.01 |
| Crouch walk (8.7) | 97 | 97 | 97 | 96 | 87 | 95 | 96 | 98% | ≤ 0.01 |

Before (engine, same idea, first look): sprint 74% (§10), aimed diagonal 53%. The engine's root advances 0.19-0.32 studs a frame against an even animation clock, so a planted foot jitters ±0.03-0.06 in the world even when the clip is perfect; that, not the clips, is most of the gap to the rig.

Seen in the engine: SlideIn → Slide → SlideOut → sprint footfall in order; the Land at full weight after a standing jump and not at all after a running one; peak tracks 10-11; console clean.

### Captures (described)
- **Strafe, front, player distance (~14 studs):** feet stay apart and never cross; legs under the body, a quick shuffle. The front silhouette still reads compact (bent knees foreshorten from the front, and the hold covers the torso); idle from the same camera looks the same height.
- **Strafe, side:** left foot ahead, right behind, a short hop.
- **Jump apex (frozen):** both knees tucked under the body, the gun held.
- **Land squash (frozen):** a compact impact crouch, gun level.
- **Slide hold:** sat back on the hip, the lead leg out flat on the floor, the gun level ahead. Reads well.
- **SlideIn kick, SlideOut push (frozen):** transitional; the push reads as rising out of a low kneel.

### Grades (mine, not a panel)
| Clip | Was | Now | Why not 10 |
|---|---|---|---|
| Run / sprint | 7.5 | 9 | Owner hasn't played it |
| Strafes (side shuffle) | 6.5 | 8.5 | Front silhouette still compact; a shuffle is a style call the owner hasn't seen; no RIVALS strafe footage to compare |
| Backpedal | 6.5 | 9 | Seen in numbers and rig pictures; no engine capture |
| Diagonals (new) | (blend, 53%) | 8.5 | Run back-left/left ~90% in the engine; not captured |
| Walk set (aimed, new) | slid below 9.6 studs/s | 9 | Not captured from outside |
| Crouch walk | 7 | 8.5 | Back 87% in the engine; not captured |
| Jump | 6 | 8.5 | Seen frozen only; in a real jump it plays 0.38 s |
| Fall | 6 | 8 | Rig only; a flat jump shows it for 0.07 s |
| Land | 6 | 8.5 | Frozen look + the speed rule checked in play |
| Slide hold | 6 | 9 | — |
| SlideIn / SlideOut | 6 | 8.5 | Hands move up to 1.1 studs in one 60 Hz frame at the impact and the push; long guns only (see below) |

### Not verified / open
- **Another player's view** (lane D: two clients). Everything here was seen on my own character in a single-client playtest.
- **The owner's eye**, especially the side shuffle and the walk set.
- **Sidearm / knife holders in a slide:** Slide, SlideIn and SlideOut key the whole body with the long-gun hold (as before this pass), so a pistol or knife holder pops to their own hold when the slide ends.
- The Idle clip (not lane A's) digs a corner 0.16 under the floor (its straight legs on wide feet); `STAND` alone 0.05.
- Footsteps (lane C) can key off the clips' footfalls: the right foot lands at phase 0 in every leg clip; the left at 0.5 (forward/back) or 0.12 after the right (strafe right) / 0.12 before it (strafe left).

## 20. Slide per weapon kind, idle stance (lane A, 2026-11-13)
Owner's list via the coordinating session: fix the pistol / knife slide pop, audit the map jumps (lane E), the Idle's floor dig.

### Slide for sidearms and the knife
- **Was:** Slide, SlideIn and SlideOut key the whole body with the rifle's arms, so a Sheriff or knife holder slid with a rifle hold and popped to their own hold as the slide ended (Bugs #9).
- **Now:** `SlidePistol` / `SlideInPistol` / `SlideOutPistol` and the three `Knife` clips. Their arms are on the rigid fist: the pistol out ahead one-handed, the knife fist forward with the blade up. The left hand rides that weapon's own grip (the pistol's cup, the knife's guard hand) before it reaches for the floor, and the way in and out fade from and back to that kind's own hold. Legs, hips and timing are the rifle slide's. `Simulation/Poses` picks the set by weapon (`slideKind`). The rifle's three clips are byte-identical to before.
- **Rig:** floor sink ≤ 0.009, no arm in the chest (the pistol's push first put the forearm in the chest for 5 frames; the gun moved further out).
- **Engine:** sprint + tap C with each weapon. Vandal plays Slide / UseSlideIn / UseSlideOut, the Sheriff SlidePistol / UseSlideInPistol / UseSlideOutPistol, the knife the Knife set; mid-slide and after, the hold layer is the weapon's own (PistolAim*, KnifeReady), so nothing pops. Frozen frames: the pistol slide (sat back on the hip, lead leg flat, the revolver out ahead in the right fist) and the knife slide (blade up beside the face) both read well.
- **Grade:** pistol / knife slide 8.5 (was the rifle's arms, Bugs #9 closed). Not 9: the way in and out were seen in play, not frozen and captured; the left arm crosses the chest a little from the left side.

### Idle stance
- The foot is rigid on the shin, so the Idle's right foot, set 0.3 behind its hip with the knee bent, tilted the shin 12° and dug a corner 0.16 under the floor. Each foot now sits slightly ahead of its hip, under the knee: shin within 4° of upright, rig dig 0.04, **engine 0.012-0.022** (lowest foot corners against the floor, standing). The stance keeps the left foot a little ahead.
- The Land now plants its feet on that stance and ends on the idle's own controls, so the feet don't shuffle as it hands back (rig sink 0.005).
- Uploaded `GG Idle v10` (Animate's `idle`), `GG Land v11`. **Grade:** idle 9.

### Map jumps (lane E)
See [Jump Audit 2026-11-13](Maps/Jump%20Audit%202026-11-13.md). Measured reach at sprint: ledges to 7.5, gaps to 9 (the old jump: about 8.9 and 11.3). No designed route is lost: what goes is climbing 8-high blocks straight from the floor (and two-hop reaches to the 16-high Updraft-only tops); tight jumps listed for the owner. Report only.

## 21. Pistol stance and a smooth knife arm (2026-11-13)
**Owner, after playing:** "It's all looking a lot better", then two fixes: the pistol hold "looks weird" (his capture: `References/hitfx/2026-11-13 ours third-person pistol hold (owner: looks weird).png`, a dummy close up from the front three-quarter: a block lying flat across the chest, the revolver beside the shoulder) and "the way the arm kind of flicks that's holding the knife".

### Pistol: a Weaver stance
- **Why it looked wrong (measured):** the barrel runs along the rigid forearm (`GRIP_SIDEARM`), and the hold put the gun on the centre line, so the right forearm pointed at the centre and its elbow ended in front of the sternum: the right upper arm pointed 64% inward and 43% down, a box across the chest.
- **Now:** the right arm reaches straight out from its own shoulder: upper arm 96% forward, the gun 1.7 studs in front of the chest at chin height (1.1 hip, 1.3 aimed: the sights under the right eye), pointing dead ahead at every pitch (measured yaw 0.0 at -30 / 0 / +45). The chest keeps its small turn so the left shoulder leads and the support hand cups the grip with its elbow down and out under the gun. Reference: the Valorant showcase frames (`References/ui/video-frames/tp-anim/valorant_iPWqI-bXi8I_0003_knife_pistol.jpg`: the pistol out ahead, both hands on it).
- **SprintPistol** (both forearms were inside the chest on every frame, 22 of 22): a one-handed low ready, the pistol by the right hip pointing down and ahead and swinging with the stride, the free arm pumping. 0 frames in the chest.
- **PistolReload:** ends punched out past the new hold; the support hand's belt point a little wider (the forearm grazed the chest on 3 frames, now 1, a graze at the torso's corner).
- **Pistol slide** (§20) fades from and back to the new hold.
- **Seen in the engine** (the new ids loaded by hand, see "Rojo" below), from the owner's three-quarter angle, the front and the side: the revolver out in front of the face at chin height pointing dead ahead, both arms reaching to it, no block lying across the torso; from the front the support arm crosses diagonally to the grip (it's placed by `GripController`'s IK in play, `Config/Animations GRIP.sidearm`, not by the clip). Thick 1-stud arms still make it compact up close.

### Knife: no more flicks
Measured per 60 Hz frame (the right upper arm and forearm's turn between frames; a flick = a frame turning over 20 degrees and more than twice its neighbours):

| Clip | Before: worst frame / flicks | After |
|---|---|---|
| KnifeSlash | forearm 52 / 1 | 30 / 0 |
| KnifeSlash2 | upper arm 89 / 2 | 58 (the strike itself) / 0 |
| KnifeSlash3 | forearm 171 / 4 | 37 / 0 |
| KnifeHeavy | 38 / 0 | 42 / 1 (the thrust stopping dead at the hit: kept) |

Three causes, all fixed:
1. **The blade direction was blended as a vector** between keys; two keys pointing nearly opposite (Slash3's wind-up and cut) almost cancelled out, so the fist's roll was undefined for a frame and flipped (the 171). Now each key's fist orientation is solved once and slerped between keys, and the blade is read off it (`knife_sequence` in `tp_clips.py`).
2. **The elbow could bend backwards:** the rigid-fist solve picks the upper arm's roll for zero forearm twist, and there are two such rolls half a turn apart; the scan took whichever came first, so Slash2's elbow went from bent back to bent forward in one frame. The solve now prefers the natural bend (`tp_rig.py`, a soft penalty on a backward hinge).
3. **The upper arm hopped between equally good rolls** where the arm passes near straight. The skinned forearm doesn't show twist, so the visible fist follows the upper arm's roll: a hop there is the flick the owner saw. `knife_sequence` now slerps each key's solved upper-arm orientation and the solve takes the roll closest to it (`upper_ref`), accepting a little hidden twist for a few frames instead of a jump.
- **Timing:** the slashes' wind-ups ease in and out over 0.1 s (they were ease-outs over 0.07 s, most of the move in two frames), and each recovery has 0.08 s more to settle into the ready (KnifeSlash / Slash2 0.42 → 0.52 s, Slash3 0.48 → 0.56 s; the game plays them at speed 1 and a new swing cuts the recovery).
- `tp_check.py`: no arm in the chest on any knife or pistol clip (the reload's one graze aside), keys every 1/60 s.
- **In the engine** (the uploaded clips played on my character at speed 1, the right upper arm and forearm measured every render frame, as degrees per 1/60 s): KnifeSlash 29, Slash2 51, Slash3 38, Heavy 30, **0 spikes in all four**; the old Slash3 under the same measure: 79 with 2 spikes.

### Rojo stopped syncing (found during this pass)
`rojo serve` (port 34872) is up, but re-saved files no longer reach Studio: the Edit place still has the pistol / knife ids from before this pass (it has the earlier walk-set and slide ids). The Studio Rojo plugin needs Connect again (the owner has been asked). **Copied by hand meanwhile:** the 15 changed id lines patched into Studio's `ReplicatedStorage.Shared.Config.Animations`, and the whole copy checked against `src/shared/Config/Animations.luau`: 16,929 bytes and the same FNV-1a hash (3085070782), an exact match; `Simulation/Poses` already matched the file exactly. In a playtest the Sheriff now plays the new hold ids. When Rojo reconnects it will write the same text.

### Shipped
`GG <Name> w1` / `w2` (the pistol holds, reload and slide in / out went to w2 after the support-arm change): PistolAimUp / Level / Down, PistolAdsUp / Level / Down, PistolReload, SprintPistol, SlideInPistol, SlideOutPistol, KnifeSlash, KnifeSlash2, KnifeSlash3, KnifeHeavy, SlideOutKnife; ids in `Config/Animations`. KnifeReady, SprintKnife and the slide holds came out identical and kept their ids. The rifle and every other clip are unchanged (the rig change only touches the knife's fist path).

## 22. Audit from outside, reload and look-down hold re-keyed (2026-11-15)
Owner: "third-person anims" as the next area of the [gunplay overhaul](../05%20Production/Playtests/2026-11-15%20Gunplay%20Overhaul.md). Method: the review rig (§6) on my own character with `DevThirdPerson`, `tp_check` on every clip, then fixes through `tp_clips.py`.

### Found (seen or measured)
| Thing | What |
|---|---|
| **Rifle reload** | At 21% of the clip the grip was at face height: the right forearm covered the face and the rifle stood up over the head (capture `tp_reload_a`). `tp_check`: a hand moved 0.85 studs in one 60 Hz frame |
| **Look-down rifle hold (AimDown)** | `tp_check` "arms": the right forearm's centre inside the chest block on 60 of 60 frames |
| **Shooting, as others see it** | Only the gun moves: it slides and tips in two still fists (`Juice.WORLD_KICK`, by design since §7). The arms, shoulders and chest don't react at all, so a firing player looks stiff |
| Rifle hold from the front | The forearms still stack in front of the chest at chin height (capture `tp_rifle_idle_frontleft`); from the side it reads as a shouldered rifle. Not changed this pass |
| Other `tp_check` flags, not looked at in play | Slide in / out hands 1.0-1.4 studs in a frame (known, §19); Throw 1.5; Death 1.7 and arms in the chest on 12 frames; Cast, Lob, PistolReload a few frames in the chest |

### Tried for a body recoil, measured, rejected
The fix for "only the gun moves" is a recoil that goes through the arms or the chest. Two code-only ways were tested in play and neither works on this rig:
- **Writing a joint's `Transform`** (the Waist, +20 degrees every frame, in PreAnimation, PreSimulation, PostSimulation and PreRender): the chest's pitch did not change in any of them (-3.4 to -3.7 degrees against -3.8 at rest). The Animator's value always wins on `AnimationConstraint` joints.
- **An `IKControl` on the right arm** (Position, target = the clip's own hand place plus a sprung push back, enabled only while the spring was live): the hand jumped 2.5 studs in one frame and wandered 0.05-0.44 studs around the target. This is the same fault §7 measured with the old chest-target IK. A Rotation `IKControl` on the upper torso alone did nothing measurable.
- **What is left:** recoil poses as clips. One pose per hold and pitch (hip and aimed, long gun and pistol, up / level / down: 12 clips) with the gun pulled into the shoulder and the chest rocked back, played on each watcher's client with a weight that follows the same spring as the gun kick (no restarts, so no jitter). Not built.

### Changed
- **Reload, v7** (`tp_clips.py` `low_ready`, asset 102765870602957, was 112777133763655). A tipped-up gun can't be held low on this rig: the fist is rigid with the gun, so the forearm tips up with it and the solver puts the hand at the chin. So the reload is now a **low-ready swap**: the gun drops to belly height, muzzle down and out, canted toward the off hand; the chest leans over it and the head looks down; the off hand goes to the belt, comes up under the gun and slaps; the gun bumps up and drops back, then swings up a little past the hold and settles.
- **AimDown, v7** (asset 86939677186257, was 111694202793931): looking down, the gun also goes 0.3 studs out from the body.

### Measured
| | Before | After |
|---|---|---|
| Reload: right hand height at 30% (root space; the head's centre is 1.5) | at the face | 0.39 (chest), muzzle 0.5 below the root and 3.3 out |
| Reload: biggest hand step in one 60 Hz frame (`tp_check`) | 0.85 studs | 0.38 |
| Reload: frames with an arm in the chest | 0 | 0 |
| AimDown: frames with the forearm in the chest (`tp_check`) | 60 / 60 | 0 / 60 |
| AimDown in the engine: forearm centre against the chest part's front face | not measured | 0.07 studs inside (the engine's chest part is a little deeper than the rig's block) |

Captures (Studio, this session): `tp_reload_v7_a` (30%, front-left: gun down, face clear), `tp_reload_v7_slap` (53%, right side), `tp_aimdown_v7`.

### Not verified / open
- Seen on my own character in one client, with one avatar and the Vandal. No second client, no bot, no other gun.
- The reload's stock comes up near the chin (the gun turns about the grip).
- The pistol reload and the draw were not looked at in play; the draw was not changed.
- The body recoil (above), the front view of the rifle hold, and the other `tp_check` flags.

## 23. Body recoil: the shot goes through the arms and the chest (2026-11-15)
Owner picked it after §22. Before: on a shot only the gun moved, in two still fists. §22 ruled out joint writes and IK, so this is built from pose clips.

### How it works
- **12 recoil poses** (`tp_clips.py`: `long_hold` / `pistol_hold` with `kick=`; clips `Kick*`, `AdsKick*`, `PistolKick*`, `PistolAdsKick*` for Up / Level / Down; uploaded as `GG <name> v1`; ids in `Config/Animations RECOIL`, keyed by the hold they belong to). Each is its hold at the far end of a kick: the gun pulled back along its barrel into the shoulder, the muzzle up, the chest rocked back and its gun-side shoulder turned back, **the head still**. Long guns: 0.5 studs, 12 degrees, chest 9 + 8; pistols: 0.45 studs, 17 degrees, chest 5 + 4. Looking down, the pull back is cut by 65% (the forearm is already near the chest).
- **`Util/BodyRecoil`** (client, called by `EffectsController` on every shot of another player, bot or dummy, beside the gun's own kick): a shot pushes a spring. While it is live, every hold track playing on that character gets its recoil track played over it (Action2) at the hold's weight times the spring. So the body is at hold + spring x (recoil - hold) at any pitch and any blend of hip and sights. Nothing restarts per shot (the jitter rule from §7).
- **Numbers** (`Config/Juice BODY_KICK`): the share one shot swells to, per class: SMG 0.16, rifle 0.28, MG 0.26, pistol 0.4, shotgun 0.8, sniper 0.9 (Sheriff 0.75, Shorty 0.7, Guardian 0.5, Marshal 0.75, Ghost 0.3, Spectre 0.14); peak ~50 ms after the shot; held fire rides at up to 1.5 times one shot.
- The gun's kick in the hand (`WORLD_KICK`) is now about 55% of what it was, so the gun and the hands move together.
- Local to each watcher (tracks on someone else's Animator don't replicate). Your own character is skipped.

### Measured (the range's Shooter dummy, Vandal, seen from 87 studs and close up)
| | Result |
|---|---|
| Offline (`tp_check` rig): every recoil pose against its hold | hands 0.26-0.52 studs, chest 6-12 degrees, head 0.0 degrees, no arm in the chest |
| A held share of 0.28 (one rifle shot's peak) | muzzle up 3.3 degrees, chest back 2.2, right hand back 0.13 studs |
| A share of 0.5 | 5.9 degrees, 3.9 degrees, 0.23 studs |
| A share of 0.9 (one sniper shot's peak) | 10.7 degrees, 7.0 degrees, 0.42 studs |
| Live 3-shot bursts (8 s) | chest up to 3.3 degrees, right hand up to 0.19 studs, the gun in the hand up to 0.20 studs |
| Biggest change in one rendered frame, live | hand 0.125 studs, chest 2.2 degrees (Studio at ~15 fps; the arm IK tried in §22 jumped 2.5 studs) |

### Not verified / open
- Seen on one dummy with a rifle, hip hold, level. Pistols, the sights hold, looking up or down, a sniper and a shotgun are checked on the rig and by the weights only.
- A real second player (replicated hold tracks) was not tested: the layer finds a hold by its asset id on the watched Animator, which worked for the server-posed dummy.
- While the sprint carry (also Action2, arms) is still fading out, a shot blends with it instead of over it. While sliding, the slide (Action3) covers the recoil; the gun still kicks in the hand.
- The first shot seen from a character loads its recoil track, so that one shot may show the gun kick only.
- No close-up capture of the peak is kept: the one I took did not match the measured pose and I could not explain it, so I am not using it.

## 24. Overnight pass: splines, breathing holds, IK prototype (2026-11-20)
Grades, evidence and what's open: [Overnight 2026-11-20 Animation Pass](../05%20Production/Overnight%202026-11-20%20Animation%20Pass.md) → TP. Pipeline changes worth knowing:
- **Key on splines.** `tp_clips.py` now has `spline_sequence` (controls), `pose_spline` (solved poses, with `hits=` for impacts) and `knife_spline` (the fist's turn too). They are monotone cubics through the keys. The old per-segment eases stopped dead at every ease-in-out key and met at two speeds elsewhere. `grounded(ctrl)` keeps both feet out of the floor on a spline path. Two ways of placing the arms (`on_gun` / `gun.pos` vs `tip` / `gun.shoulder`) can't blend between keys, so write all of a clip's keys one way (`tip_of` gives a solved pose's block end).
- **Holds breathe** (`breathing`, `BREATH`): every periodic term must fit a whole number of times in the loop.
- **Measure** with `python -I tools/anim/tp_measure.py [clips]`: the `rbx-*` checkers on the rig. The pop line is 900 studs/s² over one 30 Hz key.
- **RIVALS-style IK prototype** `TpIkController` (off; `Config/TpIk`). Never call `GetService` inside a `BindToSimulation` callback (Poses): it throws every step.

## 25. On the skinned classic body: a waist-led look-up (2026-11-21)
The body is now the S15 skinned classic body ([Match Avatar](Match%20Avatar.md#skinned-classic-body-2026-11-21)). Owner: "making new third person animations, fine ... looking up ... looking down" should look as good as RIVALS.
- **Measured:** the S15 rig's joints match the rig the clips were solved on (`tools/anim/tp_rig.py`) to within 0.001 stud. Shoulder→elbow 0.7285, elbow→wrist 0.7595, wrist→tip 0.275, hip→knee 0.822, knee→ankle 0.926, shoulder and neck heights the same. So every clip lands on the new body as it did on the old, and nothing needed re-solving for proportions. Test range dummies, rifle and Bulldog holds, close from the front-right: the support hand ends about 0.85 studs from each gun's `LeftGrip` (0.55 of it is the designed under-handguard offset; the rest is GripController sliding back to the arm's 1.87 reach). Same as before the body change.
- **Found:** at 45° up the arms swung the gun up about the shoulder while the torso barely tilted. From the front-right the right forearm covered the face and the head disappeared behind the arms (engine capture plus `tp_render` front view).
- **Changed (`tp_clips.py`):** looking up, `UP_BODY` = 0.7 of the pitch is a lean back at the waist that carries the shoulder and the gun (`pitched_body`, about `WAIST`); the rest turns the gun about the moved shoulder. The chest takes the same share (`chest_pitch`), and the head at least `UP_HEAD` = 0.85, so the face tips back along the stock above the arms (RIVALS pitches the waist with the aim too). Looking down is unchanged (the r2 holds). `tp_check`: arms 0 frames inside the chest, sink 0.048, jump 0.001. `tp_render` gained `--dpi=`.
- **Re-exported and uploaded (Config/Animations):** AimUp 76675781741304, AdsUp 125005732940313, PistolAimUp 138228207228666, PistolAdsUp 72465943608438, and the recoil poses AimUp 129629585356839, AdsUp 71635127736084, PistolAimUp 122300691641604, PistolAdsUp 118515018395854. The old ids are kept in the comments.
- **Also fixed:** the standard head (bots, dummies, swapped oversized heads) was the bundle's dynamic head, which rendered **faceless**. It's now Roblox's classic head (`STANDARD_HEAD = 0`) with the default face (`DEFAULT_FACE` 144075659). A player's own empty face no longer overwrites it.
- **Not verified / open:** the new up holds were only seen on posed preview copies without a gun, and offline. The real check is you aiming up at a bot or a second player in a playtest, from your angle. Run, slide and the down holds are unchanged; they bend smoothly on the skin. The IK prototype (Config/TpIk) stays off: on the S15 body it moved the right hand under the grip a little, but the support hand still can't reach long handguards.

## 26. Unarmed set for the lobby (2026-11-21)
Owner: "the animations when no gun is selected (in the lobby) looks bad, it is like it's holding a gun ... idle, running, make sliding available, crouching".
- **Why it looked armed:** with no weapon `Simulation/Poses` fell back to the rifle's versions: the rifle sprint's low-ready arms, the rifle slide (one hand holding an invisible gun), and the Core idle's bladed stance with arms hanging stiff while walking.
- **New clips (`tp_clips.py` "Unarmed"; FK arms; uploaded):** `UnarmedIdle` 87081146273969 (square to the front, loose arms, breathing), `UnarmedWalk` 86939525691218, `UnarmedRun` 87231109134826, `SprintUnarmed` 134786443023027 (Action2). Each arm swings opposite its leg on the shared stride phase, with more swing and elbow bend from walk to sprint and a small chest counter-turn. `UnarmedCrouch` 78467506175539 (v2: loose, low arms; v1 read as a boxer's guard). An **Unarmed slide kind**: `SlideUnarmed` 134814931400718, `SlideInUnarmed` 90446890986346, `SlideOutUnarmed` 71284722549961 (right arm ahead for balance, left hand on the floor). `tp_check`: no arms in the chest; slide numbers match the rifle and knife slides.
- **Poses:** nothing in hand → idle / walk / run arms by speed, crouch arms, `SprintUnarmed`, the Unarmed slide kind. Walk and run arms follow the heaviest leg cycle's phase (`followStride`).
- **Seen in Studio (lobby, own avatar):** a relaxed idle, pumping sprint arms, low crouch arms. Sprint → slide played SprintUnarmed → SlideInUnarmed → SlideUnarmed → SlideOutUnarmed and no rifle clip.
- **Open:** armed walk / run has no upper-body bob (the holds only breathe); jump and fall use the Movement clips' arms.

## 27. Livelier pass and the restart bug (2026-11-28)
The upper body snapping back to the start mid-stride (leg clips followed whichever clip was heaviest, often one that had just started at 0) is fixed with a stride clock per Animator; a stream of hits no longer restarts the flinch. Idle weight shift, a breathing crouch, more bounce in the walk and crouch walk, a squash-and-spring jump, bigger breathing holds and new holds on the move (`AimMove`, `PistolAimMove`, `KnifeMove`). Slide unchanged. [Third Person Animation Pass](../02%20Art/Third%20Person%20Animation%20Pass.md)

## Progress log
- 2026-11-12 03:05: §0 fixed. Plan written. Stopped at 03:10 (usage limit).
- 2026-11-12 05:50 to 06:45: resumed. Body, accessory filter, rig tool, 40 clips, upload, wiring, engine review. Studio left in Edit with `TestMode = false`, `DevThirdPerson` cleared, preview folders removed. Nothing committed.
- 2026-11-12, later: second pass (§7) after the owner's review. Studio left in Edit, `TestMode = false`, preview objects removed. Nothing committed.
- 2026-11-12, night (Opus session): third pass (§8) and first-person melee (§9). Rojo was syncing (a probe module appeared in Studio within 2 s). Studio left in Edit with `TestMode = true` (as found), no dev attributes. Nothing committed.
- 2026-11-12, late: run pass, first-person fix, accessories (§10). Studio left in Edit, `TestMode = true`, no dev attributes. Nothing committed.
- 2026-11-12, late: §11 (bone names, R15 proportions, knife, bat). Studio left in Edit, `TestMode = true`, presets untouched. Nothing committed.
- 2026-11-12, late: §12 (melee from the Valorant reference, inspect restart). Studio left in Edit, `TestMode = true`. Nothing committed.
- 2026-11-12, late: final audit (§13, six fixes) and grades (§14). Studio left in Edit, `TestMode = true`. Nothing committed.
- 2026-11-12, late: §15 (16 clips re-authored, BodyClone IK bug fixed). Studio left in Edit, `TestMode = true`. Nothing committed.
- 2026-11-12, late: §16 (rigid-fist pass: sidearm hold, every gun on the visible fist, 29 clips v6). Studio left in Edit, `TestMode = true`. Nothing committed.
- 2026-11-13: §17 (knife on the rigid fist, knife dummy on the range). Studio left in Edit, `TestMode = true`. Nothing committed.
- 2026-11-13: §21 (pistol Weaver stance, knife flicks). Nothing committed.
- 2026-11-13: §20 (pistol / knife slides, idle stance, map jump audit). Studio left as found (another session's playtest). Nothing committed.
- 2026-11-13: §19 (lane A: movement clips, 8-way walk / run / crouch, air, slide, the track-leak fix). Studio left in Edit, `TestMode = true`, no dev attributes. Nothing committed.
- 2026-11-15: §22 (audit from outside, reload v7 and AimDown v7, body-recoil tests). Studio left in Edit, `TestMode = false` (as found), `DevThirdPerson` cleared. Nothing committed.
- 2026-11-15, later: §23 (body recoil: 12 pose clips v1, `Util/BodyRecoil`, measured on the Shooter dummy). Studio left in Edit, `TestMode = false` (as found). Nothing committed.
- 2026-11-20, overnight (lane TP): §24. Studio left in Edit, no dev attributes; lock released. Committed locally on main, not pushed.

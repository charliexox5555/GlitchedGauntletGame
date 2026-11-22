# Match Avatar

> **Current body, 2026-11-21: the skinned classic body (owner: "the body of the Rivals thing is just so smooth ... I want that").** See the next section. The block body (Third Person Overhaul) stays in the code behind `Config/Avatar BODY = "Blocks"`.

## Skinned classic body (2026-11-21)
**Owner's picks (2026-11-21):** players keep their own head, standard hitboxes, classic clothes plus hair and hats (no layered clothing), and a soft classic look like RIVALS.
- **What RIVALS does** (read live in the RIVALS file; [Rivals Reference → body](../03%20Research/Rivals%20Reference/Body,%20Viewmodel,%20Guns%20and%20VFX.md)): it takes the player's own `HumanoidDescription` and overwrites only Torso / arms / legs with five skinned classic body parts. Everything else is theirs: head, dynamic face, hair, accessories, clothing.
- **Where the body comes from:** the public community body **"S15 - Skinned Classic 1.0"**, catalog bundle **209745**. It's the catalog version of the DevForum resource "Classic Blocky S15 Rigs [Skinned meshes]" by **ellieflopper** (Creator Store 13413443689), offered for any R15 game; the only condition is "not for resale". These are the same ids RIVALS uses. We don't copy anything of RIVALS'.
- **How we wear it** (`Config/Avatar BODY = "S15"`, `S15_PARTS`, `STANDARD_HEAD`; `shared/MatchBody`): `description()` sets the five part ids and keeps the player's own head (bots and dummies get the bundle's dynamic head `15365010165`), plus skin, classic Shirt/Pants and face. Accessories follow the existing caps: hair and small hats, no layered clothing on the body. The engine builds the skinned rig itself: 15 AnimationConstraints, checked in the range 2026-11-21. Swapping parts in with `ReplaceBodyPartR15` was tried first and dropped: the parts bring their own Motor6Ds, and once those were stripped the legs' skinning stopped rendering.
- **Fairness:** an own head bigger than `HEAD_LIMIT` (1.7 x 1.9 x 1.7) is swapped for the standard head. Every fighter gets an invisible **`HitboxHead`** (`HEAD_HITBOX` 1.2 cube) welded at the head; the visible head no longer takes hits (`CanQuery` off). `shared/Util/Damage.zoneOf("HitboxHead")` = Head. Torso and limbs are the bundle's fixed sizes for everyone.
- **Verified in Studio (2026-11-21):** in the range the player wears it with their own dynamic head, beard and hair, and their outfit composited. The head hitbox is there and the joints are clean. In the sprint / crouch clips the elbows bend as one skin. A bot match in the old match place has bots in it too, holding their guns.
- **Lobby (2026-11-21, same day):** everyone in a lobby server wears it. `CharacterService` spawns lobby players itself (`CharacterAutoLoads` off, `CharacterService.spawn`, after `LobbySpawnService` sets `LobbySpawnReady`), so there's no flash of the own avatar. Range exits and pad duel returns go through the same spawn, and a fall in the lobby or range brings you straight back. The client runs the match movement in the lobby: `client/init.client.luau` keeps a lobby-mode runner with `LOBBY_CONTROLLERS` (Input, Movement, Pose, Footstep, CharacterFx, Audio). Shift sprints (22), C / Left Ctrl slides with dust, and the arms swing with no gun. Shift-lock is off in the Lobby place (it clashed with sprint; saved v940). `Simulation/Movement` and `Poses` re-bind when the runner that started them is destroyed (they used to stay dead after a range trip). **Gaps:** phone players have no sprint / slide buttons in the lobby (they live in the match HUD); the lobby jump pads aren't tested with the new movement; third-person animations haven't been retuned for this body.

> **Superseded in part, 2026-11-12:** the slim 0.6 arms, the hair-only accessory rule and the holds below were replaced. The body is now drawn as blocks with regular arms; see [Third Person Overhaul](Third%20Person%20Overhaul.md). What still stands: one standard body for everyone, equal hitboxes, the spawn path.

One standard body for every combatant in the **match place** (players, AI bots, range dummies), so every gun is held right and every hitbox is the same size. The Lobby keeps players' own avatars. Owner: lane D (animation). Closes gap-review item #11 ([LihFolk Gap Review 2026-11-05](../05%20Production/LihFolk%20Gap%20Review%202026-11-05.md)).

## Why
- **Holds:** players' bodies vary (Rthro, slender, 1-stud blocky arms). The 2026-11-05 hold pass measured the right forearm **0.59 studs inside the chest** on the 1-stud blocky arms; the best searched hold still left ~0.10, and a two-handed pistol's forearms overlapped 0.41 ([Animation and Knife Pass](../05%20Production/Playtests/2026-11-04%20Animation%20and%20Knife%20Pass.md)). One known body lets every clip and IK target be solved once and land exactly.
- **Fairness:** taller, wider or bigger-headed packages are bigger targets. In a duel that's a fairness bug (gap #11).
- **Look:** the user wants RIVALS / Hypershot readability. RIVALS reportedly forces the default body type for even hitboxes (fan wiki, unconfirmed); Hypershot keeps avatars in its lobby but locks a blockier body with **skinnier arms** in matches (the user's observation). Our first-person arms are already one smooth 0.5-wide block per arm ([viewmodel-arms-style], `Config/Viewmodel ARM_WIDTH`).

## Research (cited)
- **LihFolk:**
  - *Teardown - Arsenal*: Arsenal morphs everyone to one shape (R6); cosmetics change the look, not the size.
  - *HumanoidDescription and Outfit Systems*:
    - "uniforms" keep body, face, hair and colours, and replace clothing, hats and back accessories;
    - spawn with the look (`CharacterAutoLoads = false` + `LoadCharacterWithHumanoidDescriptionAsync`) to avoid a flash of the player's own avatar;
    - recheck the character after the yield; use the Async names.
  - *Avatar Body Types and Scale in Gameplay*: hitting visible parts favours small avatars; lock scales, or use one collider. Studio's Avatar Settings ("Consistent Gameplay" preset, Custom Scale/Parts, Single Collider) are invisible to scripts.
  - *R15 Rig Anatomy and Attachments*: body scales are NumberValues under the Humanoid.
  - *AnimationConstraint and Physically Simulated Characters*: joint cone limits also limit IKControl.
  - *Gun Feel - Recoil, Spread, Bloom and Headshot Multipliers*: zone multipliers; filter accessory handles from rays.
  - *Hitboxes and Hit Detection*: server checks, capped rewind.
  - *API Renames and Deprecations 2025-2026*: use the Async forms.
  - The vault has no rule for RIVALS or Hypershot avatars, and none for slim arms.
- **Web** (DevForum; no first-party statements from RIVALS or Hypershot devs were found):
  - Setting the limb ids to 0 in a HumanoidDescription forces the blocky default body. It has to be re-applied on every spawn (t/1411351).
  - Custom arm meshes can't go through HumanoidDescription; they mean welding replacements (t/1170848).
  - Scales and proportions at 0 alone don't equalise bundles (t/2544918).
  - Roblox's Avatar Settings offer a "Consistent Gameplay" preset (t/3828640).

## Recommendation
**Roblox's own blocky R15 body for everyone, with slim one-piece arms.**
1. **Body:** every body-part id set to 0 (Roblox's default blocky R15: head, torso, legs, arms), all scales fixed (height, width, depth and head 1; body type and proportion 0). Every combatant has the same parts, the same sizes and the same hitboxes. Built server-side from a fresh HumanoidDescription, never trusting the client.
2. **Arms:** the six arm parts are narrowed to `Config/Avatar ARM_WIDTH` (0.6 studs; the first-person block is 0.5). Their rig attachments are scaled with them, so the joints stay put. The hand gets the same cross-section as the forearm and sits flush with it, so **forearm and hand read as one block** (no wrist step), and the upper arm matches the forearm, so a straight arm reads as one piece like RIVALS. Bent elbows show one clean corner. This stays R15, so every clip, the AnimationConstraint joints and the hold IK keep working (R6 would mean re-doing every clip).
3. **Kept from the player:**
   - skin colours (all six body colours);
   - classic Shirt, Pants and T-shirt;
   - the face.
4. **Stripped:**
   - body part packages (Rthro, etc.);
   - scales;
   - layered clothing (it wraps the body and won't fit the slim arms);
   - accessories, except hair (decided 2026-11-05, below).
5. **Spawn path:** the match loads characters straight from the standard description (`LoadCharacterWithHumanoidDescriptionAsync`, no flash). Any other spawn (test mode, the range, dev tools) gets the description applied on arrival, then the arms slimmed, *before* the character is set up for combat (hitbox history, health).
6. **Bots and dummies:** they already use the default body; the same arm slimming runs on their rigs.

**Options considered:**
- **(a)** Players' own bodies with scales locked: hitboxes still differ by package, and holds still clip.
- **(b)** R6: true one-piece arms, but every clip and the IK would have to be redone.
- **(c)** Custom welded arm meshes: the cleanest bevelled look, but classic shirts wouldn't draw on them, and they add weld upkeep under Server Authority.
- **(d)** Recommended: the standard blocky R15 with slim resized arms. Shirts still draw on the arms.

## Holds per weapon class (after the body change)
All holds are re-solved on the standard body (`tools/studio/MakeHoldAnimations.luau` builds its rig through the same shared module). GripController IKs the left hand onto each gun's `LeftGrip`.
| Class | Hold |
|---|---|
| Rifle, SMG, Shotgun, Sniper, MachineGun | Shouldered long-gun hold; left hand on the guard |
| Sidearm (Classic, Sheriff, Ghost, Shorty) | Two-handed, left hand cupping the grip hand |
| Akimbo ("Dual Boot") | A gun in each hand, no IK |
| Knife | Ready / slash / heavy clips |
The first-person arms (0.5-wide block, skin colour plus a shirt layer) and the third-person arms (0.6, the same shirt) now read as the same arm.

## Extended hold pass (2026-11-05 evening, commit 008639e)
- **Built:** RIVALS-style extended holds on the match body.
  - Long guns: chest nearly square, gun forward at chest height, arms reaching out, left hand beside the magwell (the handguard is out of the arm's reach once the gun is forward).
  - Pistols: extended, both hands side by side.
  - Akimbo: uses the two-handed set, so both guns point forward. It was dangling the left gun in the long-gun hold.
  - Sprint: a lower carry.
  - Knife: the guard arm lowered from the face.
  - Aim pitch poses are baked at **+45 / −30** (`AIM_PITCH_UP` / `AIM_PITCH_DOWN`): looking down steeply puts the forearms into the chest in any forward hold.
  - Draw and reload start and end on the new hold.
- **Correction to the measurements above:** Studio caches required modules, so the exploration rig had silently gone back to 1-stud arms. On a truly slim rig the earlier bladed hold measured **0.035** (hip, level) and **0.040** (ADS, level), but 0.28 / 0.50 at ±70 pitch, 0.175 pistol and 0.43 sprint. The hold tool now turns off automatic scaling itself.
- **Measured (extended):**
  - worst overlap over level, +45 and −30 is ~0.14 (long guns), 0.175 (pistol) and 0.30 (sprint);
  - in-game off hand 0.25 studs from its target (slightly beyond comfortable reach).
- **Re-score** (3 blind reviewers, same rubric; per-class front / three-quarter / back lineup plus the in-game rifle):

| Score | Uncapped | Rifle | SMG | Shotgun | Sniper | MG | Pistol | Akimbo | Knife |
|---|---|---|---|---|---|---|---|---|---|
| **5.0** (overlap gate) | 5.0 | 7 | 6 | 6 | 8 | 6 | 4 | 4 | 6 |

- **Reading:**
  - Long guns read well from the front and side (best: sniper 8, rifle 7).
  - Pistol and Akimbo are hidden behind the arms from the front, and the long-gun arms still cross the chest a little.
  - Static holds give no timing evidence.
  - The uncapped score did not beat the bladed hold's 6.0, though that round used different evidence.
- **Stopped here** (core chat: one re-score, then report).
- **Next options:**
  - Keep the extended long-gun hold, which reads best side-on.
  - Pistols: try one-handed-forward plus a support hand, or a wider isosceles stance, so the gun shows from the front.
  - Akimbo: arms apart, a gun per hand, each in line with its shoulder.
  - Add a breathing / weight-shift layer and fire-kick evidence (video) for P2-P4.

## Decisions
- **Accessories in matches: hair only, user 2026-11-05.** The Config switch stays (`Config/Avatar ACCESSORIES`: "hair" / "all" / "none").

## Status
- 2026-11-05: built (commit f74140f).
  - Code: `shared/MatchBody` (standard description + `slimArms`), `Config/Avatar`, `CharacterService.loadCharacter` / `applyStandard`; `MatchService` spawns with it; `BotService`, `TestRange/Dummies` and `DevModService` rigs use it.
  - Holds, ADS, sprint, sidearm, slide arms, draw and reload re-solved on this body.
- **Measured (playtest, BotMatch 1v1, TestMode off):**
  - player and bot both 0.60-wide arms with flush hands; every body part identical in size (max difference **0.000 studs**: equal hitboxes, gap #11 closed);
  - the off-hand IK lands **0.08 studs** from its target.
- **Found on the way:**
  - The Humanoid's automatic scaling rebuilds part sizes when a rig enters the Workspace (a slimmed arm went back to 1.0). `slimArms` turns it off; the standard scales are already baked into the parts.
  - On this body the off-hand IK must be position-only. A full transform target asks for a palm angle the arm's joint cone limits refuse: the hand stopped 0.71 studs short (LihFolk *AnimationConstraint and Physically Simulated Characters*: cone limits also constrain IKControl).
- **Score (3 blind reviewers, `quality-score` animation rubric, median):**
  - **5.0**, capped by the 0.05-stud overlap gate: rifle hold forearm vs chest 0.055-0.10, two-handed pistol 0.23.
  - Uncapped **6.0**; body standard **7 / 10**.
  - All three: the body is clean and consistent, but in the bladed shouldered hold the arms clump in front of the chest from the front view, and static holds give no timing evidence.
- **What blocks 8.5, and the next step:** the hold design, not the body. Even with slim arms, a shouldered hold keeps the forearm against the chest. **Recommended next:** a RIVALS-style extended hold for third person (gun held forward at chest height, arms reaching out with soft elbows, chest square). It reads from the front, clears the chest, and matches the first-person reference (guns straight ahead). After that: a breathing / weight-shift layer for P2-P4.
- Evidence (not in the repo): the side-by-side shots are listed in the lane note.

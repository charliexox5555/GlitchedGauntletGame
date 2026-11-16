# Handoff: every animation and gunplay grade to 9-10

**Goal (owner, 2026-11-13):** "the goal on every single thing is a 9 to 10". Current grades and their evidence are in [Third Person Overhaul](../01%20Design/Third%20Person%20Overhaul.md) §14 (updated in §15-17). This note splits the remaining work into lanes, each a separate session.

## Read first (every lane)
- `CLAUDE.md` rules; load the `gauntlet-vault` skill; Style Bible; LihFolk before non-trivial work (`lihfolk-lookup` agent).
- [Third Person Overhaul](../01%20Design/Third%20Person%20Overhaul.md): §8 skinned body, §10 run, §11 bone-name bug, §13 audit, §14 grades, §16 rigid fist, §17 knife. Read by section, not whole.
- Memories: `place-ids` (match place 133387545285290), `mcp-require-breaks-remotes`, `git-add-paths-only`.

## How the third person works now (one paragraph)
- **Body:** a skinned block mesh per arm, leg and the torso, in `Workspace.GGBodyLimbs` (outside the character, or its Animator overwrites the bones), bent each frame by `BodySkinController` from the R15 parts (`shared/MatchBody` `skinLimb`).
- **Fist:** rigid on the forearm, with no wrist bend and no forearm twist. So every clip keeps the hand part straight and untwisted.
- **Guns:** ride the fist at fixed grips (`Config/Animations GUN_WORLD_GRIP` / `_SIDEARM`, `KNIFE_WORLD_GRIP`).
- **Clips:** authored in `tools/anim/tp_clips.py` on the rig in `tools/anim/tp_rig.py`, using these controls:
  - `gun` (the rigid-fist solve);
  - `gun = {"shoulder": (pitch, yaw, roll)}`;
  - `right_arm = {"fist", "blade"}` for melee;
  - `ctrl_sequence`, which blends controls and solves every frame.
- **Ship a clip:** `python -I tools/anim/tp_clips.py export <Names>`, upload with `tools/opencloud/upload_asset.py --type Animation`, then put the id in `Config/Animations`.
- **Per-frame checker:** checks arms in the chest, sinking under the floor and hand jumps. Its idea is in §15; the script was in the session scratchpad, so rewrite it if needed.

## Owner's notes (2026-11-13, going to bed: "keep going until the grades are at 9 to 10 for everything or close to")
- **Hit markers:** the crosshair hit markers should look more professional and more satisfying. The gunplay overall should keep getting more satisfying.
- **On a hit:** the player you hit flashes **white and red instead of the yellow**, "a fun highlight and slash".
- **Headshot:** a **cartoony fire spew from the head** (the fire made with ChatGPT; images exist, new ones later if needed), plus a different highlight on the player to make it more satisfying.
- **Sounds:** keep them as they are for now (later).
- He'll grade the things that need a human (feel, sound) when he's back.
- **Later the same night, after seeing the first hit-feedback build:** the slash "I kind of love it, but I think it's a bit obnoxious" (keep the idea, tone it down). The head fire "is not supposed to be like actual fire"; it should be "the Valorant kind of flash fire... very similar to the muzzle flash look", built from our cartoon flash art (`VfxTextures` flash sheets, `Util/MuzzleFx`). Relayed to the hit-feedback session.

## Lanes
| Lane | Now | Target work | Files it owns |
|---|---|---|---|
| A. Third-person movement | Jump / fall / land / slide 6, strafe / backpedal 6.5, slow-walk slide | Re-key the air and slide clips on the new body (foot plants, no floor sink, a slide that reads); a strafe cross-step or lean; the run rate at low speed | `tools/anim/tp_clips.py` (locomotion, air, crouch, slide sections only), `Config/Animations` ids for those clips, `Simulation/Poses.luau` |
| B. First-person feel | Reload / draw / inspect 6.5, run sway "a bit off", fire kick 7 | A punch-up pass: anticipation, overshoot, a heavier landing; the run bob against the RIVALS video study; check a long spray | `Config/Viewmodel.luau`, `Controllers/ViewmodelController.luau` (not the bat / knife blocks), `Util/ViewmodelMotion.luau`, `shared/WeaponAnimations/*` |
| C. Footsteps and sound | Footsteps not graded (a FootstepController exists, check it first); gun sounds 6.5 waiting on the owner | Footsteps by surface and speed (licensed recordings only, memory `gun-audio-real-recordings`); a slide and land sound pass | `Controllers/FootstepController.luau`, `Config/Sounds.luau`, `Config/Audio.luau`, `art-source/audio` |
| F. Hit feedback (owner's priority, 2026-11-13) | Crosshair hit markers not "professional / satisfying" yet; the body flash is yellow; headshots have no special effect | Hit markers that feel pro and satisfying; the hit body flashes white then red (a fun highlight, plus a slash); a headshot sprays cartoony fire from the head (the ChatGPT flame flipbook `VfxTextures MOLLY_FLAME_4x4` / burst / ember, new art later if needed) and gets its own highlight. Sounds stay as they are | `Util/HitFeedback.luau`, `Controllers/EffectsController.luau` (hit flash and impact parts), `Util/ImpactFx.luau`, a new `Config/HitFx.luau` |
| D. Two-player check | All third-person grades unconfirmed from another player's view | Needs the owner: Studio Test, Clients and Servers, 2 players (the MCP can't start it) | (review only) |
| E. Map jumps | Jump is 4.4 studs; maps were built for 5.6 | Find every jump on every map that now fails | `tools/studio/maps/*` |

## Shared rules (lanes run at the same time in this one folder)
- **One Studio, one match place.** Before `start_stop_play`, call `get_studio_state`. If it is already in Play and you didn't start it, wait and retry; never stop another session's playtest. Keep playtests short, stop them when done, and leave Edit with `TestMode = true` and no dev attributes.
- **Edit only the files your lane owns.** Don't reformat other files: run `stylua` on your files only. Run `selene src` and `rojo build` before you finish.
- **Nothing is committed.** Commit only if the owner asks, staging exact paths.
- **Grade honestly** with evidence (measured numbers, captures described). Write results as a new section in Third Person Overhaul (lanes A and B) or a playtest note (C), and update its §14 grade row.

## Round 2 (2026-11-13 morning)
Owner: "we're really getting there and starting to be really good". Sounds: he'll buy a pack and do them himself. After these, he moves on to UI and final touches.
- **hit-feedback session:** improve the **default crosshair** (customization comes later; numbers in Config so it can drive them), as one system with the hit markers.
- **fp-feel session:** make **shooting more satisfying**, measured per class: shot punch, camera kick, spray rhythm, ADS fire, muzzle and tracer from first person, settle after a burst. Also check the guns not yet measured, and delete the unused `Juice.HIT_FLASH`.
- **tp-movement session:** the slide pop for pistol and knife holders; lane E, a map jump audit against the 4.4-stud jump (report, no map changes without the owner); the Idle clip's corner dig.

## Round 3 (2026-11-13, the owner's play feedback)
"It's all looking a lot better... we just have a few things." His screenshots are in `vault/02 Art/References/hitfx/` (RIVALS white hit flash, red headshot flash, body hit marker; our third-person pistol hold). They are third-party screenshots: never stage them (memory `git-add-paths-only`).
- **hit-feedback:**
  - Markers: the same crosshair-indent marker for every hit, white for the body and a subtle plain red for the head (no red outline), plus a kill marker (there is none now).
  - Flash: "look better", matching RIVALS (white with a thin red rim; red on a headshot).
  - Head flash: still "too much like real fire". It should be a regular Valorant-style flash. Ask the owner for ChatGPT art if needed.
  - Slashes: should follow the hit player.
- **fp-feel:** the Outlaw reload's left hand goes into the screen; check the other bolt and lever reloads too.
- **tp-movement:** the third-person pistol hold "looks a bit weird" (rework it to a clear two-handed stance); the knife arm "flicks", which is choppy.

## Sounds (2026-11-13, the owner bought a library)
The library is in `vault/06 Assets/NewGunSounds/` (Guns, ProSoundCollection_BonusSounds and a setup PDF). It is licensed, so it must be git-ignored and never committed. Its own session (sounds) handles it in two phases:
1. Review the files, pick the best ones per gun plus knife swooshes and other game sounds, and write a pick note. Then the owner approves.
2. Upload the picks, wire them in and test in Studio.

## Round 3 progress (2026-11-13, evening)
- **fp-feel:** the Outlaw reload is fixed. The left arm now stays at least 1.2 studs from the eye, where before the camera went inside it. Every other reload keeps the arm 0.64 studs or more away. The write-up is in Shot Feel Pass 5's follow-up section. Lint, format and build were re-checked clean.
- **hit-feedback:** a new owner note was relayed: the flash is "too prominent", and it should be a subtle background feel rather than something you notice.
- **sounds:** Phase 1 (the picks) is done and is in `vault/02 Art/Sound Library Pick.md`. Phase 2 was given the go-ahead under the owner's "keep working until you're done":
  - Enemy shots are made from each gun's own shot.
  - The Operator gets a subtle low layer.
  - The purchase source and licence terms are left for the owner to fill in.
- **Rojo:** `rojo serve` is running, but Studio is not connected; it needs the owner's Connect click. Sessions copy their own files into Studio by hand until then.
- **sounds, Phase 2 done:**
  - Atlas v3 (asset 119437853694239, private, group) is live in `Config/Sounds`.
  - Checked in a match-place playtest: first shot, spray and tail, the Classic, the knife and draws.
  - Its files were copied into Studio by hand and hash-match the disk.
  - The licensed packs are git-ignored.
  - Left for the owner: listen to `art-source/audio/ProPack/PickReel.wav` and fill in the pack's licence source in `Sound Library Pick` §11.
- **tp-movement, done:** the pistol is now a Weaver stance (the arm straight out from the shoulder, the gun at chin height, nothing lying across the chest). The knife flicks are gone (0 spikes in all four slashes, measured in the engine). See Third Person Overhaul §21.
- **hit-feedback, done:**
  - Wedge markers: white on the body, plain red on the head, plus a kill marker with a ring.
  - Flash: white with a red rim, then made subtler (peak about 40% opacity, gone in 0.1-0.15 s).
  - Head: a radial streak burst instead of fire. The ChatGPT prompt for a better burst is in Hit Feedback Pass §11.
  - Slashes ride the body part they hit.
  - See Hit Feedback Pass §11-12.
- **All lanes copied their own files into Studio by hand, each matching its file on disk exactly.** Lint, format and build are clean. Nothing is committed. The owner needs to click Connect in the Rojo plugin.

## Round 4 (2026-11-13, the owner's play feedback)
- **hit-feedback:**
  - The red slash "still looks a bit off": rethink it, or drop it.
  - No kill marker on the crosshair: a kill shows the normal hit marker only.
  - The head flash "looks really off": smaller, lower and subtler, with a fun, punchy animation instead of a static fade.
  - General polish.
- **sounds (v3 not liked):**
  - Use only the new pack, and use all of it. Delete the old Snake and v2 sounds, including the old reloads.
  - Impact sounds are "pretty bad": rebuild them from the pack, owned by the sounds lane.
  - The knife whooshes sound like impacts: use pure air whooshes.
  - Check the processing for what sounds "off".
  - Build an audition folder plus a simple Config mapping, so the owner can pick sounds himself.

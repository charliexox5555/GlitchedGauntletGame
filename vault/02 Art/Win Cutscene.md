# Win Cutscene

The end-of-match winner cutscene in the match place (2026-11-20). It replaces the old victory scene (one camera, the winners pumping a fist). Same cutscene every time, cut to the ending song, ending on a low final pose. This note holds the plan, the shot list, how it is built, the captures and what to test.

**Status (2026-11-20):** 1 to 5 winners built and play-tested in Studio (round 3: clipping and turned hands fixed, 2-5 player versions, winners ordered by performance). 1-player version first built and play-tested in Studio (preview, a faked match end with the results screen, the skip). Round 2 (the owner's additions, below): sound accents under the song with options on the F4 board, the final shot rebuilt after the owner's reference, no UI until the final pose. Clip v9 (`Win1_1` 138336403992094, `Win1_1Hold` 110107132585954). **Waiting on the owner:** pick the accents on F4 → CUTSCENE, and a look at the whole thing. Versions for 2-5 winners slot in as data (see "Adding the 2-5 player versions").

## Owner's direction (2026-11-20)
- The same cutscene every time. Later one version per winning-team size (1 to 5), each with its own motion.
- Several camera angles, eased camera moves and cuts, real keyframed character animation. Not one static camera and one motion.
- Ends on a **final pose**: the last shot goes down to a low camera looking up at the winners, who hold the pose with a slight sway. RIVALS has a similar low hero shot (study, don't copy).
- Staged on the baseplate for now. Every map will get its own spot open enough for 5 players later, so the stage is a per-map anchor.
- Music: APM "Victory Slam stinger 1" (asset 9042702890, 8.15 s), the owner's pick for the ending song.
- **Round 2 (owner, relayed by the UI lane):**
  1. Designed sound hits on the cuts (an impact or whoosh-hit when a strong angle slams in), layered under the song, licensed sounds only (Pro Sound Effects, Roblox, APM), level-matched to the song, a few options per accent for the owner to pick by ear.
  2. The final shot after the owner's RIVALS screenshot (`third-party/rivals/cutscene/final-pose-owner.webp`, git-ignored): a very low camera close to the winner looking up, the gun raised in one hand, the camera swaying slightly on the held pose.
  3. No results UI during the cutscene. When it lands on the final pose, the UI (winner banner, the player rows with stats, Rematch / Play Again / Leave) comes in all together, polished, Quint, no overshoot.

## The song (measured)
`PlaybackLoudness` sampled in a play test at 0.2x speed (20 ms bins, onset = rise over the last 80 ms):

| Time (s) | What | Use |
|---|---|---|
| 0.14 | opening slam | flash in from the replay, shake |
| 0.68 | hit | the winner's head comes up |
| **1.48** | the band comes in | cut to shot B, the snap up |
| 1.82 | hit | stomp |
| **2.02** | loudest hit | the flex (arm snaps out wide), FOV punch |
| 3.14 | hit | cut to shot C, the "too easy" flick |
| **4.02 / 4.16** | double hit | cut to shot D, the gun swings down and is caught |
| 4.80 | hit | lean back, muzzle up |
| 5.36 | hit | the spin-hop |
| **5.80** | hit | cut to shot E (the coil) |
| **6.14** | hit | snap into the final pose (the gun goes up), the camera drops to the floor |
| **6.80** | last hit | the gun punches up, a nod |
| 6.9-8.05 | ring-out | held pose; the results UI comes in at 7.35 (the pose has landed) |

The beat is about 0.54 s (111 BPM). Every time in the clip and in the config is song time.

## Shot list (1 player)
Stage space: the winner on the anchor, facing forward; points are right, up, forward in studs, floor at 0, head at about 4.6.

| Shot | Song time | Camera | Winner (clip `Win1_1`) |
|---|---|---|---|
| A over the shoulder | 0-1.48 | behind the right shoulder, high, craning down and in | head down catching breath; head snaps up on 0.68 and looks out; coils (knees dip, gun in) from 1.1 |
| B front three-quarter | 1.48-3.14 | front left (the raised gun arm stays behind the head), whips round after the cut, brakes on 2.02, drifts in | snaps up, gun straight up (60 ms, overshoot, settle); stomp on 1.82; the flex on 2.02: fist tucked, then the free arm snaps out wide, chest open (coil, snap, brake); groove nod on the beat |
| C close up | 3.14-4.02 | front left, head and chest, slow truck | the "too easy" flick of the free hand (out to the back left), chin up, head turns into the camera; gun bounces on the beat |
| D wide orbit | 4.02-5.80 | wide from the left, orbiting round the front to the right | the gun swings down into two hands (4.02), caught (4.16), sweep across, lean back with the muzzle up (4.80), **spin-hop** on 5.36 (coil, take off, a full turn in the air with knees tucked, land and absorb; the turn and lift are the slot's `root` keys in the config), coil low for the final |
| E low hero | 5.80-8.15 and held | starts at eye level on the coil, then **drops to the floor right in front of them** as they rise on 6.14, the lens opening wide (46 → 66 FOV); holds very low and close (0.4 up, 4.9 out, a little to their right), looking up past the raised gun; floats slightly on the hold (`HOLD_FLOAT`) | after the owner's reference: snap the gun up and out beside the face (its side to the camera), free fist on the hip, wide stance, chin down to the lens; the gun punches up and a nod on 6.80; then the hold loop `Win1_1Hold` (3.2 s breath) |

Accents also kick the camera (FOV punches and short shakes) and there are three short white flashes (0.1 opening, 1.46 and 6.12 cuts). Cinema bars slide in at the start and out when the results screen comes in. A light grade (contrast and saturation) plays under it.

**Results UI:** nothing during the cutscene. At **7.35 s** (the winner has landed the final pose, the song rings out) the whole screen comes in together in one beat: the VICTORY / DEFEAT banner grows from 0.94 and fades in, the round history and every scoreboard row rise 14 px and fade in, the build cards grow from 0.94, the buttons grow in; all 0.45 s Quint Out, no overshoot (`Util/MatchEndScreen` `animateIn`, `Shared/UiMotion`); the shadows fade in after. The name plate appears over the winner's head with it. A click or key after 0.8 s skips to the final pose (with the FINAL accent) and brings the screen in at once. The 20 s match-end timer is unchanged, so the screen has about 12.5 s on it.

**Sound accents** (`cues` in `Config/WinCutscene`, played by `Util/WinCutscene` through the song's sound group): each starts early so its loudest point (measured per file) lands on its accent. Hit times and loudness measured in a match-place play test at 0.5x speed; volumes level-matched to the song's measured peak (impacts about 0.75 of it, whooshes 0.55, the spin swish 0.45, the final hit 0.85). Measured in play: every hit landed within 0.02 s of its accent.

| Accent | Song time | Now (option 1) | Other options on F4 → CUTSCENE |
|---|---|---|---|
| OPEN (slam in from the replay) | 0.12 | PSE Whoosh Impact 3 (big stinger, up and hit) | PSE Whoosh Impact 4, PSE Whoosh Combo 4, PSE Thick Swish Hit 3 |
| CUT B (front angle slams in) | 1.48 | PSE Whoosh Impact 5 | PSE Whoosh Combo 3, PSE Whoosh Impact 1, PSE Thick Swish Hit 1 |
| CUT D (wide orbit, gun swings) | 4.02 | PSE Fast Swish By 4 | PSE Fast Swish By 1, PSE Whoosh Combo 6, PSE Whoosh Combo 1 |
| SPIN (spin-hop) | 5.44 | PSE Sharp Swish 13 | PSE Sharp Swish 11, PSE Fast Swish By 4, APM Reverse Drum Swipe |
| FINAL (drop to the low hero shot) | 6.14 | PSE Deep Hit, Big Reverberant Boom | APM Agents Of Deception Hit, APM Tyrant God Big Hits, PSE Whoosh Impact 3 |

Every row also has "no accent". On the board (F4 in a match-place play test, CUTSCENE tab) each option plays the song from 1.2 s before its accent with the candidate aligned, as the cutscene plays it; the top row plays the whole cutscene. Tell Claude e.g. "OPEN 2, FINAL 1".

## How it is built
- **Data:** `src/shared/Config/WinCutscene.luau`: `SCENES[team size]` = slots (position, facing, clip, hold loop, optional `root` keys for whole-body turns and lifts) + shots (camera keys) + kicks + flashes + sound cues; stage tag, baseplate fallback, screen time, skip, handheld drift, bars, grade.
- **Player:** `src/client/Util/WinCutscene.luau`. Copies of the winners (`BodyClone` "root" + `kinematic`, so the clip poses them with no physics lag) on the stage, each playing its slot's clip at Action4, then the hold loop (0.3 s crossfade). The camera is set every frame from the shot's keys on a time-parameterised Catmull-Rom (eye, look-at, FOV, roll), plus a slow handheld drift and the kicks. **The song is the clock:** each frame reads the song's `TimePosition`, so it stays in time at Studio's ~15 fps and nothing drifts (no chained tweens). The clips are pulled back onto the song clock if they drift more than 0.1 s.
- **Controller:** `MatchEndController` starts it on the MatchEnd phase (after the replay hands back) and shows the results screen on its `onScreen` call. The cutscene starts the ending song; the VICTORY / DEFEAT toast no longer plays it (it would start the song before the cutscene and break the sync).
- **Camera hook:** `CameraController.setOverrideFov` (an override's own FOV, cleared with the override).
- **Clips:** `tools/anim/win_clips.py` (on the third-person rig in `tp_rig.py` / `tp_clips.py`): keys on monotone cubics (`spline_sequence`), feet kept on the floor (`solve_grounded`), the free hand carried onto the gun's grip over the two-handed window. `render`, `check`, `export`; upload with `tools/opencloud/upload_asset.py --type Animation`; ids in `Config/Animations` `WIN`.
- **Stage:** a part tagged `WinnerStage` anywhere in the map (`workspace.ActiveMap`): its position = the lead's spot on the floor, its LookVector = the way the winners face. No tag: the fallback spot on `workspace.Baseplate` (600, 0, 600), clear of every map's footprint. The client asks the server to stream that area in; if the Baseplate still isn't there, a plain floor is made for the cutscene.

### 2 to 5 winners (round 3, 2026-11-20)
Owner: "work on 2, 3, 4 and 5 player editions, get everybody to do stuff, the ending a similar angle where you can see the other players, in order of the best performing players."
- **Order:** `MatchEndController.winnersOf` ranks the winning side: the MVP first, then eliminations, damage dealt, fewer deaths, assists (then still alive, then name). Slot 1 is the best.
- **Spots by rank** (stage space, `RANKS` in the config), spread out (owner: the best one in the middle is the main subject, the others off to the sides): 1 front and centre; 2 right (4.2 out, 2.6 back); 3 left; 4 far right (9.0 out, 4.0 back); 5 far left. Each is turned 12-22 degrees toward the middle; the outer pair stands well out so it shows between the others from the low final camera.
- **Everybody moves, each differently** (same song hits, own moves, own final pose; `tools/anim/win_group.py`):

| Slot | Clip | Character | Moves | 5.36 | Final pose |
|---|---|---|---|---|---|
| 1 | `Win1_1` | the lead | the solo performance (gun up on the drop, the flex, "too easy", two-hand sweep) | spin-hop | gun raised beside the face, fist on the hip |
| 2 | `WinS2` | the showman | arms out wide on the drop, fist pumps on 2.02 / 2.56 / 3.10 with the gun held out, points at the lead, beckons the lens one-handed | hop | down on one knee, fist on the knee, gun up on the outside |
| 3 | `WinS3` | the cool one | late and smooth: gun onto the shoulder, a shrug, finger gun at the lens, turns to watch the lead, raises the gun slowly to the sky | stance switch, leans back | gun pointed down in front, hand on the hip, chin up |
| 4 | `WinS4` | the hype one | bounces from the first hit, both arms up on the drop, fist pumps, points at the lens, a sideways one-handed aim at the lens, rocks back | big hop, both arms up | both arms up in a V |
| 5 | `WinS5` | the chill one | head nods with the gun on the shoulder, a salute flicked out, admires the gun with both hands | lazy shrug | points at the sky, gun easy |

- **Shots** (`group(n)` in the config): owner: while they move, the camera stays on the best player and the others are only seen round the edges; everyone is in full view in the last shot. So A-D are the solo shots on the lead, and E is the same low angle on the lead with the lens wider and a little further back, so the spread-out others stand in it.
- More than 5 winners: scene 5 plays and the rest stand in `EXTRA_SLOTS` on the lead's clip.
- Owner's 2-player reference (a RIVALS end screen, git-ignored, not committed): the pair close, #2 lower, the camera very low; a stat plate under each winner and a crown on the best (UI, see What to test).

### Results UI: winner cards (round 4)
Owner: "our normal current ending UI shows up at that last scene; add cards and MVP cards for the winning players; maybe we don't need the leaderboard bottom left if it doesn't fit."
- **The cards** (`ReplicatedStorage.UiTemplates.MatchEnd.Card`, Studio-owned, backup builder `tools/studio/BuildWinnerCard.luau`; filled by `Util/MatchEndScreen.cards`, data from `MatchEndController.showCards`): one per winner in a row along the bottom, each under its winner in the final shot (projected, then pushed apart so none overlap and kept left of the right column). Same look as the rest of the screen: a charcoal plate, the team-colour name block with its slanted cap and the player's headshot, E / D / A cells, damage dealt and taken; Rubik.
- **The MVP card:** the best of the winners gets the bigger card (1.14x); when they are the match MVP it turns gold with the MVP badge (shard + MVP) above it.
- **The rest of the screen stays:** VICTORY / DEFEAT and the score on top, the round history, your build, PLAY AGAIN / REMATCH / LEAVE. The scoreboard (bottom left) is hidden while the cards show: it doesn't fit next to them (`CARDS_KEEP_BOARD` turns it back on). Without the cutscene (phones), the old name plates show.
- Everything comes in together in the same 0.45 s Quint Out beat (the cards rise 14 px and fade in).
- **Save the match place** after pulling: the Card template lives in Studio.

| | |
|---|---|
| ![5 cards](Win%20Cutscene/UI%205P%20cards.jpg) 5 winners: the MVP's gold card in the middle (preview data) | ![1 card](Win%20Cutscene/UI%201P%20card.jpg) 1 winner: the MVP card under them |

### Round 4: the final pose and its transition, everyone's own gun
Owner: "the transition into the final pose should be more professional; the final pose closer to the camera, posed into the camera like RIVALS, closer together, some kneeling on the sides, more centred; they shouldn't all hold the same gun: the gun they got the most kills with that game."
- **Final spots** (`RANKS[i].final`): on the cut into the final shot (5.80, hidden by the cut) the group closes up: the MVP in front, #2 and #3 on one knee at their sides (2.7 out, 1.1 back; #3 now kneels too, mirroring #2), #4 and #5 standing behind on the outside (5.8 out, 2.3 back), each turned to face the camera. While they move they still stand spread out.
- **Transition** (`FINAL_KEYS`, used by every scene): the cut finds them coiled from high above (they look up into it); the camera eases up and back and stops (anticipation, a `still` key); on the 6.14 hit it slams down to the floor right in front of them as they snap into the pose, goes a hair past its mark (6.26), settles (6.62) and creeps in through the ring-out. Bigger FOV punch and shake as it lands. The solo final is closer (4.4 studs, lens 70); a group's opens with its width and sits a touch higher so the kneelers don't stack.
- **Guns:** `StatsService` counts each fighter's eliminations per gun (the knife doesn't count) and puts the top one in their results line (`weapon`; no kills: the gun of their latest hit). The cutscene puts that gun in their copy's hand (`WinCutscene` `arm`, the same grip as the server's Weapon/WorldModel); the gun they already hold is kept when it's the same one, so it keeps its skin. A swapped-in gun shows its default look. The preview gives each copy a different random gun.

### Clipping and turned hands (round 3)
Owner: "the way the hands are kind of turned, and a lot of times they clip through the body". Two causes, both measured on the rig:
- **Turned hands:** the right fist is locked to the gun, so a canted gun twists the forearm (up to 70 degrees). The skinned forearm doesn't show twist, so the hand block looks turned against it.
- **Clipping:** several keys put a forearm, a fist or the gun inside the chest or the head (worst: the low-ready forearm 0.82 studs into the chest, the raised gun arm 0.54 into the head).

**Fix:** `tools/anim/win_check.py` tests every 60 Hz frame (arm blocks and the gun against the torso, hips, head, legs and the other arm, as boxes on the R15 sizes) and the wrist twist. `tools/anim/win_fix.py` clears each key with a small search: it moves the gun (pitch, yaw, cant, reach) and the free fist and elbow just far enough that nothing sits more than 0.1 studs inside the body, and keeps the forearm twist under 20 degrees, staying close to the authored pose. Results are cached per key (`win_fix_cache.json`), so editing a key re-fixes only that key. The game's own rifle hold measures about 0.3-0.5 on the same test (the skinned limbs hide small overlaps), so 0.1 is stricter than the gameplay clips.

### Per-map stage spots (owner, later)
In each map, add a small anchored, invisible, non-colliding part named `WinnerStage`, tag it `WinnerStage` (CollectionService), put it on the floor where the lead should stand, and turn it so its front face points the way the winners should face. Leave about 12 studs clear in front, 8 to each side and 6 behind for a 5-player line-up and the cameras (shot A goes about 10 studs behind and 8 up).

## RIVALS study (read-only, structure only)
From the RIVALS file's `FinalResults.Winners` module (read, not copied): a per-map `Winners` folder (a 1x1x1 `Primary` anchor + a flat 35 x 32 `Reference` plate), an animated camera rig cloned onto the anchor and played as an animation with markers for FOV moves (FOV 40 to 70 to 120), one animation per slot (`FinalResultsPlayer1..5`), a gun scaled 1.5x on the first slot, a handheld sine drift of about 1 degree, everything frozen (`AdjustSpeed(0)`) at 12 s, the player cards after about 10 s, a skip that jumps to the frozen end. We took the structure (per-map anchor, per-slot clips, held end, skip to the end, slow handheld drift) and did our own timing, shots, motion and look. Reference notes: [Rivals Reference](../03%20Research/Rivals%20Reference/00%20Rivals%20Reference.md), [Maps and Lobby](../03%20Research/Rivals%20Reference/Maps%20and%20Lobby.md) (`Winners` folder).

## LihFolk notes used
- `09 Gameplay Systems/Camera Systems.md`: replace the camera at Camera priority with Scriptable, restore type, subject and FOV.
- `08 Animation/05 Systems/Cinematic Ultimates.md`: shot grammar (low close hero, wide establish, low three-quarter climax).
- `14 3D Modeling/Bezier Curves and Splines for Modellers.md`: Catmull-Rom passes through its keys (C1).
- `60 High-Craft Game Teardowns/Teardown - Funky Friday.md` and `07 Lighting VFX and Audio/Music and Adaptive Audio.md`: drive the timeline from the song position, not frame deltas.
- `08 Animation/01 Fundamentals/AnimationTrack Reference.md`: hold a pose with `AdjustSpeed(0)` / a loop, not by letting a one-shot end.
- `07 Lighting VFX and Audio/Atmosphere Sky Clouds and Post-Processing.md`, `Screen Damage Effects`: one owner per post effect, restore what you change.
- Memory `animation-oomph` (coil, ~60 ms snap, brake, overshoot, settle, splines) and `third-person-body-taste`.

## Studio preview
Match place, Play, then in the **Client** command bar:

```lua
require(game.ReplicatedStorage.Shared.StateValues).set(workspace, "PreviewWinCutscene", os.clock())
```

It plays the cutscene with you as the winner. Add the results screen with made-up stats (and the winner cards) with `require(game.ReplicatedStorage.Shared.StateValues).set(workspace, "PreviewWinCutsceneScreen", true)`. Run it again to restart; `false` as the last argument stops it. For a group, first set how many winners (copies of you), 1 to 5:

```lua
require(game.ReplicatedStorage.Shared.StateValues).set(workspace, "PreviewWinCutsceneCount", 5)
```

 To hold one frame (for captures), set `"PreviewWinCutsceneAt"` to a song time (a new value each time, e.g. 6.4 then 6.41); `false` plays on.

## Captures (v6 shots A-D, v9 final; Studio, baseplate fallback stage)
Frozen frames from the preview (`PreviewWinCutsceneAt`); the bars are the cutscene's own.

| | |
|---|---|
| ![A](Win%20Cutscene/A%20over%20the%20shoulder%200.90.jpg) A 0.90: over the shoulder, head coming up | ![B](Win%20Cutscene/B%20flex%202.20.jpg) B 2.20: the flex, gun up behind the head |
| ![C](Win%20Cutscene/C%20close%20up%203.40.jpg) C 3.40: close up, the "too easy" look into the lens | ![D](Win%20Cutscene/D%20spin%20hop%205.44.jpg) D 5.44: mid spin-hop (shadow on the floor) |
| ![E](Win%20Cutscene/E%20low%20hero%207.60.jpg) E 7.60: the low hero shot after the owner's reference, held | ![Screen](Win%20Cutscene/E%20results%20screen.jpg) the results UI in over the held pose (a faked match end, 7.36 s) |

**2-5 winners (round 3, Studio preview with copies of one avatar):**

| | |
|---|---|
| ![2P](Win%20Cutscene/2P%20final.jpg) 2 winners, final: the lead in front, #2 down on one knee (after the owner's 2-player reference) | ![5P](Win%20Cutscene/5P%20final.jpg) 5 winners, final (round 4): a pose for the camera, the MVP in front, #2 and #3 on one knee, #4 and #5 standing behind on the outside, each with their own top-kills gun |
| ![5P B](Win%20Cutscene/5P%20B%20flex%202.20.jpg) 5 winners at 2.20: the camera stays on the lead (the flex); the others do their own moves at the edges | ![5P coil](Win%20Cutscene/5P%20E%20coil%206.00.jpg) 6.00: the cut finds them coiled from high above, before the slam to the floor |

Measured in a play test: the clip and the song stay within 0.02 s of each other the whole way (60 fps); the hold loop takes over at 7.0 s; the screen comes in at 6.95; a click after 0.8 s jumps to the final pose and pulls the bars out.

## Review rounds
- **v1 (engine):** every shot about 1.5x too close (cut at the knees, the fist filling the frame, [capture](Win%20Cutscene/v1%20B%20too%20close.jpg)); from the front right the raised right fist covered the face (shots B and E); the C flick crossed the lens. **Fixes:** cameras pulled back, B and C moved to the front left, the flick goes to the back left, the final pose changed from "gun up by the head" to the diagonal champion pose (face clear from every front angle).
- **v2:** the hold loop never played (a track loaded on a copy outside the DataModel never loads: the stage folder is now parented first, and the hold reloads if it has no length). The fist thrust at the lens on 2.02 hid the face; the barrel-roll twirl lifted the fist to the chin; E cut the feet.
- **v3-v4:** the thrust lowered to chest height still hid the face from the front-left camera, so 2.02 became **the flex** (arm out wide). E reframed to show the planted feet (FOV 50, look-at lower).
- **v5:** the twirl kept low still folded the forearm past the chin (the rigid fist follows the gun's roll). **v6:** replaced by the **spin-hop** (the root turns, the clip tucks and lands).
- **Round 2 (v7-v9, owner's additions):** v7 put the gun up with the camera low on their left: the gun hid behind the head. v8 moved the camera to their right and the gun up and out beside the face; it read edge-on. v9 rolls the gun so its side faces the lens (matches the reference's read). Sound cues measured and aligned; the screen waits for the pose and comes in together.
- **Round 3 (owner: hands turned, clipping; 2-5 player versions):** the clip checker and fixer (see Clipping and turned hands) took the worst overlap from 0.82 to 0.37 studs (a frame or two mid-move; the game's own rifle hold measures 0.49 on the same test), the forearm twist stays under 20 degrees on every key, the hold no longer snaps the gun in at the crossfade (its reach was 0 against the clip's 0.8). Group versions: v1 had everyone within 3 studs and every winner doing the same thing at the same time (gun up on the drop, two-hand aim, hop/spin on 5.36); now spread out with their own moves, only the lead spins and #2 / #4 hop, the camera stays on the lead until the final. #3's final changed (pointed down in front, the gun hit the legs and the fixer twisted it up toward the face).
- Self-grade (v6): about 7.5/10. Timing, cuts and the final frame read well; the flat baseplate background is the weakest part until each map has its `WinnerStage` spot. Block hands make the raised fist read a little like a wave.

## What to test
- [ ] Win a match (Studio with bots, or a real match): the cutscene starts as the final-kill replay hands back, the song starts with it, the hits land on the cuts and moves (1.48 snap, 2.02 flex, 4.02 swing, 5.36 spin-hop, 6.14 final, 6.80 punch).
- [ ] Lose a match: same cutscene of the other side, same song.
- [ ] The final pose holds with a slow breath and drift; nothing pops when the hold loop takes over (about 7 s).
- [ ] No results UI during the cutscene; at about 7.4 s the banner, rows, build cards and buttons all come in together (Quint, no overshoot); the plate sits over the winner's head; the buttons work; Enter / R do nothing before the screen is up.
- [ ] The sound accents land on the cuts (0.12 open, 1.48, 4.02, the spin, 6.14) and sit under the song, not over it. Pick on F4 → CUTSCENE.
- [ ] The final shot: very low, close, looking up; the gun raised beside the face with its side to the camera; the camera sways slightly on the hold.
- [ ] Click or press a key after the first second: it jumps to the final pose and the screen comes in.
- [ ] At a low frame rate (Studio ~15 fps) the cuts still land on the hits and the camera moves smoothly.
- [ ] The winner holds a pistol or the knife: the hand poses still read (the clips are keyed on the rifle grip).
- [ ] Each winner holds the gun they got the most eliminations with (a skin shows only if that's the gun they were holding at the end).
- [ ] The transition: high over the coil, a beat of stillness, the slam to the floor on the 6.14 hit, a small overshoot, the settle.
- [ ] 2v2 to 5v5: the best performer (MVP, then eliminations, damage) is in the middle; the others stand spread out and each does their own moves; the camera stays on the best one until the final, where everyone is in view. Preview with `PreviewWinCutsceneCount`.
- [ ] No hand or gun goes through a body or head; hands don't look twisted on the gun.
- [ ] The winner cards: one under each winner, the best one's bigger, gold with the MVP badge when they're the match MVP; headshots and stats right; no overlap with the right column at 5 winners; the scoreboard hidden; the cards come in with the rest of the screen.
- [ ] Rematch / Play Again: the cutscene cleans up (no copies, bars, grade or flash left; camera back to normal).
- [ ] A map with a `WinnerStage` part: it plays there, facing the part's front.

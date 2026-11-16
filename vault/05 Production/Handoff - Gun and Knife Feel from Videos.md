# Handoff: gun and knife feel from the owner's videos (2026-11-14)

**For:** the session that watches the owner's recordings and brings what they show into the game.
**From:** the audio lane. The sounds are done for now ([Sound Library Pick](../02%20Art/Sound%20Library%20Pick.md) §13–16).
**Status:** pass 1 done 2026-11-14: [results](Playtests/2026-11-14%20Gun%20and%20Knife%20Feel%20from%20Videos.md) (knife rebuilt, gun shot snap, hit notes for lane F). The clips are in `art-source/reference/feel-videos/`.

**The videos go in:** `art-source/reference/feel-videos/` (in the repo folder). It's git-ignored: these are third-party clips, so never commit them.

## What the owner wants (his words, 2026-11-14)
1. **Shooting feel first:** "the hit and the kind of feel of when you shoot a gun is what I'm really looking for". Analyse every clip and take inspiration for each gun type. This is inspiration, not a copy; "they're not all the same".
2. **Animation cleanup** for those guns, including the **pull-out** (equip / draw).
3. **The knife above all:** "the knife one is the main one I'm worried about". Slashes, the heavy, the pull-out, the inspect.
4. **Feedback in a few clips:** headshots, hit markers, crosshair, "what everything else looks like when I'm shooting things".

## How to watch the videos
- **Tool:** the `video-analyzer` MCP (`analyze_video` on a local file path, `get_frame_burst` / `analyze_moment` for motion; vault [Video Analyzer](../04%20Tech/Video%20Analyzer.md)). It reads local MP4s: frames, timing, OCR. There's no ffmpeg on this machine, so use the MCP.
- **Per clip, write down with timestamps:**
  - **Shot:** how far the gun kicks back and up, in what time; whether it rotates; the recovery curve; camera punch (view kick vs gun kick); FOV pulse; muzzle flash size and life; shell eject; screen shake.
  - **Sprays:** how the kick builds over shots 1–10 and how it settles on release.
  - **ADS:** the in / out time, the sight picture, and the kick while aimed.
  - **Pull-out:** the path the gun comes in on, its rotation, the overshoot / settle, the total time, the moment it is "ready".
  - **Reload beats:** anticipation, the mag swap on screen, the slap, the rack.
  - **Knife:** each slash's arc (screen path, start / end), speed curve (anticipation, the fast part, follow-through), wrist roll, how the hand and arm move, the heavy's wind-up and hit, the hit-stop, the camera punch along the swing, the swipe VFX, the inspect.
  - **Hits:** the hit-marker shape, size, colour and life; the headshot marker and any flash; the kill marker; damage numbers; crosshair bloom / recoil.
- Use `get_frame_burst` around each event (e.g. 8–12 frames across a shot or a slash) to measure. Turn what you see into numbers (studs, degrees, ms), not adjectives.

## Where it lives in the game (read via the Code Map, grep, don't open whole)
| What | Where | Owner lane |
|---|---|---|
| First-person gun / arms rig, kick, sway, draw, reload, inspect, knife swings | `src/client/Controllers/ViewmodelController.luau` (+ `Util/ViewmodelTracks`, `ViewmodelMotion`, `GunAnimator`) | fp-feel |
| Per-gun clips (draw, reload, inspect, fire) | `src/shared/WeaponAnimations/<Gun>.luau` (all 17 guns + `Knife.luau`) | fp-feel |
| Viewmodel numbers (kick, ADS, bob) | `src/shared/Config/Viewmodel.luau` | fp-feel |
| Knife feel (whoosh peak, swing marks, inspect flips) | `src/shared/Config/Animations.luau` `KNIFE_FEEL`, `KNIFE_MARK` | fp-feel |
| Camera kick / recoil | `Controllers/CameraController`, `Config/Weapons` recoil, `Config/Camera` | gunplay |
| Hit markers, damage numbers, hit flash, headshot pop | `Util/HitFeedback`, `Util/HitFx`, `Config/HitFx` | hit-feedback |
| Crosshair | `Util/Crosshair`, `Config/Crosshair` | hit-feedback |
| Muzzle flash, tracers, shells, impacts | `Util/MuzzleFx`, `TracerFx`, `ShellFx`, `ImpactFx` | hit-feedback |
| Sounds (timing hooks only: whoosh peak, clip beats) | `Config/GunSounds`, `Util/GunAudio` | audio (done) |

Recent passes to read **by section**, not whole:
- [Shot Feel Pass 5](Playtests/2026-11-13%20Shot%20Feel%20Pass%205.md) (camera kick timing, view punch, aimed kick, bursts);
- [First-Person Feel Pass 4](Playtests/2026-11-13%20First-Person%20Feel%20Pass%204.md) (reload / draw / inspect with anticipation and overshoot);
- [Gunplay Feel Pass 3](Playtests/2026-11-12%20Gunplay%20Feel%20Pass%203.md) (knife hold and stabs);
- [Hit Feedback Pass](Playtests/2026-11-13%20Hit%20Feedback%20Pass.md);
- the headshot comparisons `Playtests/2026-11-13 headshot … vs RIVALS.png`;
- memory `viewmodel-arms-style` (RIVALS block arms, guns straight ahead, pistols two-handed).

## Rules (CLAUDE.md)
- Load `gauntlet-vault` first, and the LihFolk skills for the job (the Animation folder `08 Animation`, `47 Game Feel and Juice`, `lihfolk-vfx` for flashes / swipes).
- **Plan in the vault before building;** results and a test list go in `vault/05 Production/Playtests/`.
- **Stay in your lane:** fp-feel owns the viewmodel; hit-feedback owns markers / crosshair / FX. If you're a new session, coordinate through them, or have the lead session hand you their files.
- **Numbers in Config, `--!strict`.** Selene, stylua, rojo build must be clean.
- **Test in the match place** (placeId 133387545285290; `get_studio_state` first, drive with the Studio hooks `DevAction` / `DevHold` / `DevAim` and the `PickWeapon` remote, never `require` server modules).
- **Commit nothing** unless told.
- **Measure and grade** each gun / the knife before and after, with frame captures beside the reference frames.

## Done looks like
- A note per pass: what each clip shows (numbers), what was changed per gun and for the knife, before / after captures, grades, a test list for the owner.
- The knife first: slashes, heavy, pull-out and inspect rebuilt to read like the reference, with the swipe and camera punch matching.
- Shot feel per gun type: kick, recovery, view punch and flash tuned from the clips; pull-outs cleaned up.
- Hit marker / headshot / crosshair notes handed to hit-feedback (or done in their lane).

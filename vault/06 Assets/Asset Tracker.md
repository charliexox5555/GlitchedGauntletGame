# Asset Tracker

Status of every asset from model to in-game. Update it whenever something moves forward.

**Legend:** ✅ done · 🟡 in progress · ⬜ not started · ❌ needs rework

Pipeline: [Art Direction](../02%20Art/Art%20Direction.md) → *Import pipeline*.

## Weapons

| Gun | Class | Tier | Wave | Modeled (Blender) | Imported (Studio) | Standard (attachments, names) | `.rbxm` in repo | Config + working in game | Notes |
|---|---|---|---|---|---|---|---|---|---|
| **Byte** | Sidearm | T1 | 1 | ✅ | ✅ | ✅ | ✅ | 🟡 | Works vs dummies in Studio (2026-10-25); needs a 2-player test + balance |
| **Root** | Sidearm | T1 | 1 | ✅ | ✅ | ✅ | ✅ | 🟡 | Works vs dummies in Studio (2026-10-25); needs a 2-player test + balance |
| **Splinter** | Sidearm | T1 | 2 | ✅ | ✅ | ✅ | ✅ | 🟡 | Works vs dummies in Studio (2026-10-25); needs a 2-player test + balance |
| **Flicker** | Sidearm | T1 | 2 | ✅ | ✅ | ✅ | ✅ | 🟡 | Works vs dummies in Studio (2026-10-25); needs a 2-player test + balance · big spread while moving |
| **Mute** | Sidearm | T1 | 2 | ✅ | ✅ | ✅ | ✅ | 🟡 | Works vs dummies in Studio (2026-10-25); needs a 2-player test + balance · first person: red-dot lens fades in ADS, reticle shown instead |
| **Bandwidth** | SMG | T2 | 1 | ✅ | ✅ | ✅ | ✅ | 🟡 | Works vs dummies in Studio (2026-10-25); needs a 2-player test + balance |
| **Burst Buffer** | SMG | T2 | 2 | ✅ | ✅ | ✅ | ✅ | 🟡 | Works vs dummies in Studio (2026-10-25); needs a 2-player test + balance · 3-round burst |
| **Hard Reset** | Shotgun | T2 | 1 | ✅ | ✅ | ✅ | ✅ | 🟡 | Works vs dummies in Studio (2026-10-25); needs a 2-player test + balance |
| **Crash** | Shotgun | T2 | 2 | ✅ | ✅ | ✅ | ✅ | 🟡 | Works vs dummies in Studio (2026-10-25); needs a 2-player test + balance |
| **Pulse** | Rifle | T2 | 2 | ✅ | ✅ | ✅ | ✅ | 🟡 | Works vs dummies in Studio (2026-10-25); needs a 2-player test + balance · 3-round burst, single shots while aiming |
| **Checksum** | Rifle | T2 | 2 | ✅ | ✅ | ✅ | ✅ | 🟡 | Works vs dummies in Studio (2026-10-25); needs a 2-player test + balance · first person: optic tube fades in ADS, reticle shown instead |
| **Bitrate** | Rifle | T3 | 1 | ✅ | ✅ | ✅ | ✅ | 🟡 | Works vs dummies in Studio (2026-10-25); needs a 2-player test + balance |
| **Overwrite** | Rifle | T3 | 2 | ✅ | ✅ | ✅ | ✅ | 🟡 | Works vs dummies in Studio (2026-10-25); needs a 2-player test + balance |
| **Long Poll** | Sniper | T2 | 1 | ✅ | ✅ | ✅ | ✅ | 🟡 | Works vs dummies in Studio (2026-10-25); needs a 2-player test + balance |
| **Handshake** | Sniper | T3 | 2 | ✅ | ✅ | ✅ | ✅ | 🟡 | Works vs dummies in Studio (2026-10-25); needs a 2-player test + balance |
| **Kernel** | Sniper | T3 | 2 | ✅ | ✅ | ✅ | ✅ | 🟡 | Works vs dummies in Studio (2026-10-25); needs a 2-player test + balance |
| **Overflow** | Machine gun | T3 | 2 | ✅ | ✅ | ✅ | ✅ | 🟡 | Works vs dummies in Studio (2026-10-25); needs a 2-player test + balance · steadier crouched |
| **Flood** | Machine gun | T3 | 1 | ✅ | ✅ | ✅ | ✅ | 🟡 | Works vs dummies in Studio (2026-10-25); needs a 2-player test + balance |
| **Ray Trace** | Wildcard | T4 | 1 | ✅ | ✅ | ✅ | ✅ | 🟡 | Works vs dummies in Studio (2026-10-25); needs a 2-player test + balance · first person: holo pane on top (its own sight is a closed box), battery cells fade in ADS |
| **Loopback** | Wildcard | T4 | 3 | ✅ | ✅ | ✅ | ✅ | 🟡 | Works vs dummies in Studio (2026-10-25); needs a 2-player test + balance · server-flown bouncing discs, client disc follows the same path · first person: holo pane on top (closed-box sight) |
| **Dual Boot** | Wildcard | T4 | 3 | ✅ | ✅ | ✅ | ✅ | 🟡 | Works vs dummies in Studio (2026-10-25); needs a 2-player test + balance · two models (DualBoot_L / DualBoot_R), fires alternately, no ADS |
| **Null** | Wildcard | T4 | 3 | ✅ | ✅ | ✅ | ✅ | 🟡 | Works vs dummies in Studio (2026-10-25); needs a 2-player test + balance · held beam, battery shown as %, no reload · first person: holo pane on top (closed-box sight) |
| **Cutter** | Melee | — | 1 | ✅ | ✅ | ✅ | ✅ | 🟡 | Works vs dummies in Studio (2026-10-25); needs a 2-player test + balance · first person: held bigger and blade-up, own inspect |

Note: Bitrate is the master reference. Use the IDs without spaces in code/models: `BurstBuffer`, `HardReset`, `LongPoll`, `RayTrace`, `DualBoot_L` / `DualBoot_R`.

First-person viewmodel (all guns): one rigid rig (pass 4, 2026-10-25). Smooth bevelled block arms (skin + the player's Shirt, mesh `art-source/viewmodel/Arms.fbx`) sit on the grips in gun space. Gun, joints and arms are posed in one pass, each in its own WorldModel (exact positions under Server Authority). Primaries point straight ahead; pistols are two-handed. Hands follow the mag/pump/bolt in clips; inspect on F; ADS hides only real sight-line blockers. Measured smooth at 60 fps, and 60 vs 240 Hz stepping matches. All 23 checked at the hip in Studio (contact sheet `vault/02 Art/References/rivals-viewmodel/viewmodel-all-23-hip.jpg`). ✅ built · 🟡 needs a feel pass in a real match and at a real high frame rate.

Where they live: models in `ReplicatedStorage.Weapons` (saved with the place), backups in `art-source/weapons/Studio/<Id>.rbxm`, Open Cloud asset IDs in `art-source/weapons/Exports/assets.json`. Check them with `tools/studio/ValidateWeapons.luau` (all 24 pass).

## Arenas

| Arena | Mode | Sketch | Greybox | Playtested | Art pass | Notes |
|---|---|---|---|---|---|---|
| **Cache** | 1v1 | ⬜ | ⬜ | ⬜ | ⬜ | ~64×64 studs |
| **Firewall** | 1v1 / 2v2 | ⬜ | ⬜ | ⬜ | ⬜ | ~90×70 |
| **Mainframe** | 2v2 | ⬜ | ⬜ | ⬜ | ⬜ | ~100×80 |
| **Lobby** | Hub | ⬜ | ⬜ | ⬜ | ⬜ | Pads, range, bot pad |
| **Test range** | Testers (TestMode) | ✅ | ✅ | 🟡 | 🟡 | Built from code (`src/server/TestRange/RangeBuilder`), backup `art-source/maps/TestRange.rbxm`. Lanes + markers 10/25/50/100/150, cover/ThinWall, movement course, 23 gun racks, 6 dummy kinds. Solo Studio playtests done (2026-10-25); needs a 2-player test and a look on phone/gamepad; art pass later (lighting, props) |

## VFX, UI and audio

| Asset | Status | Notes |
|---|---|---|
| VFX textures (17) | ✅ | Rendered by `tools/vfx/make_vfx_textures.py` (Blender, emission on transparent), PNGs in `art-source/vfx/`, uploaded; image ids in `Config/VfxTextures` |
| Muzzle flashes / tracers / shells | ✅ | Flipbook star + side flame (3rd person), core, sparks, smoke, light pop; suppressed = small puff. Travelling Beam tracers (none when suppressed). Pooled brass / shotgun shells from `Eject` (none for Ray Trace, Null, Loopback, Root, Splinter, Handshake) |
| Wildcard effects | ✅ | Ray Trace charge glow + helix rail that sheds pixels; Null textured energy beam with end flare; Loopback spinning disc (SurfaceGui face + camera-facing ring, trail, pixels) |
| Impacts + bullet holes | ✅ | Flash, sparks (gold extra on metal), surface-coloured dust and chips; 48 pooled holes with a rim that cools, fade after 4 s. Characters: neon sparks, ring and pixels, no blood |
| Pixel-dissolve death + kill flash | ✅ | White-hot hologram (Highlight) → flicker out → glitch-pixel burst; cyan / gold (headshot) screen-edge flash for the killer |
| Hit markers, damage numbers, kill banner | ✅ | `Util/HitFeedback`: white / gold-headshot X with a pop and rotation kick, cyan kill X with a ring; damage numbers stack on the target (gold headshot, bigger on the kill) then fall off in an arc; "ELIMINATED / DOUBLE KILL…" banner. Hand-animated, pooled, always end fully hidden |
| Mod icons (8) | ⬜ | SVG → PNG |
| Draft card frames | ⬜ | Normal / upgrade / glitch |
| Third-person pose animations | 🟡 | 7 procedural R15 clips (aim up/level/down, sprint, crouch, crouch-walk, slide) in `art-source/animations/`, uploaded group-owned; first pass, worth a hand-keyed polish later |
| Gun sounds | ✅ | Atlas v2 (asset 105241531021545): real CC0 recordings, polished, with recordings per class (machine guns from real full-auto bursts, snipers from big bolt rifles), 3 variants + an enemy `_Far` version per gun, built by `tools/audio/build_sound_atlas.py`. Foley: Audioscape; melee and Ray Trace: ProSoundEffects. Synthesized hit tick, headshot, kill, headshot kill, damage, dry fire, low ammo. Pooled playback and mix in `AudioController` / `Config/Audio`. See [Art Direction](../02%20Art/Art%20Direction.md) → Audio |
| Game icon + 3 thumbnails | ⬜ | |

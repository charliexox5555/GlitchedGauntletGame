# Asset Tracker

Status of every asset from model to in-game. Update it whenever something moves forward.

**Legend:** ✅ done · 🟡 in progress · ⬜ not started · ❌ needs rework

Pipeline: [Art Direction](../02%20Art/Art%20Direction.md) → *Import pipeline*.

## Weapons

| Gun | Class | Tier | Wave | Modeled (Blender) | Imported (Studio) | Standard (attachments, names) | `.rbxm` in repo | Config + working in game | Notes |
|---|---|---|---|---|---|---|---|---|---|
| **Byte** | Sidearm | T1 | 1 | ✅ | ✅ | ✅ | ✅ | 🟡 | Works vs dummies in Studio (2026-10-25); needs a 2-player test + balance |
| **Root** | Sidearm | T1 | 1 | ✅ | ✅ | ✅ | ✅ | 🟡 | Works vs dummies in Studio (2026-10-25); needs a 2-player test + balance |
| **Splinter** | Sidearm | T1 | 2 | ✅ | ✅ | ✅ | ✅ | ⬜ | Model ready; no stats in Config yet |
| **Flicker** | Sidearm | T1 | 2 | ✅ | ✅ | ✅ | ✅ | ⬜ | Model ready; no stats in Config yet |
| **Mute** | Sidearm | T1 | 2 | ✅ | ✅ | ✅ | ✅ | ⬜ | Model ready; no stats in Config yet |
| **Bandwidth** | SMG | T2 | 1 | ✅ | ✅ | ✅ | ✅ | 🟡 | Works vs dummies in Studio (2026-10-25); needs a 2-player test + balance |
| **Burst Buffer** | SMG | T2 | 2 | ✅ | ✅ | ✅ | ✅ | ⬜ | Model ready; no stats in Config yet |
| **Hard Reset** | Shotgun | T2 | 1 | ✅ | ✅ | ✅ | ✅ | 🟡 | Works vs dummies in Studio (2026-10-25); needs a 2-player test + balance |
| **Crash** | Shotgun | T2 | 2 | ✅ | ✅ | ✅ | ✅ | ⬜ | Model ready; no stats in Config yet |
| **Pulse** | Rifle | T2 | 2 | ✅ | ✅ | ✅ | ✅ | ⬜ | Model ready; no stats in Config yet |
| **Checksum** | Rifle | T2 | 2 | ✅ | ✅ | ✅ | ✅ | ⬜ | Model ready; no stats in Config yet |
| **Bitrate** | Rifle | T3 | 1 | ✅ | ✅ | ✅ | ✅ | 🟡 | Works vs dummies in Studio (2026-10-25); needs a 2-player test + balance |
| **Overwrite** | Rifle | T3 | 2 | ✅ | ✅ | ✅ | ✅ | ⬜ | Model ready; no stats in Config yet |
| **Long Poll** | Sniper | T2 | 1 | ✅ | ✅ | ✅ | ✅ | 🟡 | Works vs dummies in Studio (2026-10-25); needs a 2-player test + balance |
| **Handshake** | Sniper | T3 | 2 | ✅ | ✅ | ✅ | ✅ | ⬜ | Model ready; no stats in Config yet |
| **Kernel** | Sniper | T3 | 2 | ✅ | ✅ | ✅ | ✅ | ⬜ | Model ready; no stats in Config yet |
| **Overflow** | Machine gun | T3 | 2 | ✅ | ✅ | ✅ | ✅ | ⬜ | Model ready; no stats in Config yet |
| **Flood** | Machine gun | T3 | 1 | ✅ | ✅ | ✅ | ✅ | 🟡 | Works vs dummies in Studio (2026-10-25); needs a 2-player test + balance |
| **Ray Trace** | Wildcard | T4 | 1 | ✅ | ✅ | ✅ | ✅ | 🟡 | Works vs dummies in Studio (2026-10-25); needs a 2-player test + balance |
| **Loopback** | Wildcard | T4 | 3 | ✅ | ✅ | ✅ | ✅ | ⬜ | Model ready; no stats in Config yet |
| **Dual Boot** | Wildcard | T4 | 3 | ✅ | ✅ | ✅ | ✅ | ⬜ | Two models: DualBoot_L / DualBoot_R. Model ready; no stats in Config yet |
| **Null** | Wildcard | T4 | 3 | ✅ | ✅ | ✅ | ✅ | ⬜ | Model ready; no stats in Config yet |
| **Cutter** | Melee | — | 1 | ✅ | ✅ | ✅ | ✅ | 🟡 | Works vs dummies in Studio (2026-10-25); needs a 2-player test + balance |

Note: Bitrate is the master reference. Use the IDs without spaces in code/models: `BurstBuffer`, `HardReset`, `LongPoll`, `RayTrace`, `DualBoot_L` / `DualBoot_R`.

Where they live: models in `ReplicatedStorage.Weapons` (saved with the place), backups in `art-source/weapons/Studio/<Id>.rbxm`, Open Cloud asset IDs in `art-source/weapons/Exports/assets.json`. Check them with `tools/studio/ValidateWeapons.luau` (all 24 pass).

## Arenas

| Arena | Mode | Sketch | Greybox | Playtested | Art pass | Notes |
|---|---|---|---|---|---|---|
| **Cache** | 1v1 | ⬜ | ⬜ | ⬜ | ⬜ | ~64×64 studs |
| **Firewall** | 1v1 / 2v2 | ⬜ | ⬜ | ⬜ | ⬜ | ~90×70 |
| **Mainframe** | 2v2 | ⬜ | ⬜ | ⬜ | ⬜ | ~100×80 |
| **Lobby** | Hub | ⬜ | ⬜ | ⬜ | ⬜ | Pads, range, bot pad |

## VFX, UI and audio

| Asset | Status | Notes |
|---|---|---|
| Muzzle flashes / tracers | 🟡 | Neon flash + light, tracers (none when suppressed), Ray Trace beam |
| Hit sparks + pixel-dissolve death | 🟡 | Spark particles + glow mark; neon pixel burst on death. No blood |
| Hit markers, kill icon | 🟡 | White / gold headshot X, cyan kill X, stacking damage numbers |
| Mod icons (8) | ⬜ | SVG → PNG |
| Draft card frames | ⬜ | Normal / upgrade / glitch |
| Gun sounds | 🟡 | Placeholders from licensed libraries (Audioscape, ProSoundEffects) in `Config/Sounds.luau`; hit/kill sounds need proper UI sounds |
| Game icon + 3 thumbnails | ⬜ | |

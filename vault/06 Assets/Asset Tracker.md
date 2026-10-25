# Asset Tracker

Status of every asset from model to in-game. Update it whenever something moves forward.

**Legend:** ✅ done · 🟡 in progress · ⬜ not started · ❌ needs rework

Pipeline: [Art Direction](../02%20Art/Art%20Direction.md) → *Import pipeline*.

## Weapons

| Gun | Class | Tier | Wave | Modeled (Blender) | Imported (Studio) | Standard (attachments, names) | `.rbxm` in repo | Config + working in game | Notes |
|---|---|---|---|---|---|---|---|---|---|
| **Byte** | Sidearm | T1 | 1 | ✅ | ⬜ | ⬜ | ⬜ | ⬜ | |
| **Root** | Sidearm | T1 | 1 | ✅ | ⬜ | ⬜ | ⬜ | ⬜ | |
| **Splinter** | Sidearm | T1 | 2 | ✅ | ⬜ | ⬜ | ⬜ | ⬜ | |
| **Flicker** | Sidearm | T1 | 2 | ✅ | ⬜ | ⬜ | ⬜ | ⬜ | |
| **Mute** | Sidearm | T1 | 2 | ✅ | ⬜ | ⬜ | ⬜ | ⬜ | |
| **Bandwidth** | SMG | T2 | 1 | ✅ | ⬜ | ⬜ | ⬜ | ⬜ | |
| **Burst Buffer** | SMG | T2 | 2 | ✅ | ⬜ | ⬜ | ⬜ | ⬜ | |
| **Hard Reset** | Shotgun | T2 | 1 | ✅ | ⬜ | ⬜ | ⬜ | ⬜ | |
| **Crash** | Shotgun | T2 | 2 | ✅ | ⬜ | ⬜ | ⬜ | ⬜ | |
| **Pulse** | Rifle | T2 | 2 | ✅ | ⬜ | ⬜ | ⬜ | ⬜ | |
| **Checksum** | Rifle | T2 | 2 | ✅ | ⬜ | ⬜ | ⬜ | ⬜ | |
| **Bitrate** | Rifle | T3 | 1 | ✅ | ⬜ | ⬜ | ⬜ | ⬜ | |
| **Overwrite** | Rifle | T3 | 2 | ✅ | ⬜ | ⬜ | ⬜ | ⬜ | |
| **Long Poll** | Sniper | T2 | 1 | ✅ | ⬜ | ⬜ | ⬜ | ⬜ | |
| **Handshake** | Sniper | T3 | 2 | ✅ | ⬜ | ⬜ | ⬜ | ⬜ | |
| **Kernel** | Sniper | T3 | 2 | ✅ | ⬜ | ⬜ | ⬜ | ⬜ | |
| **Overflow** | Machine gun | T3 | 2 | ✅ | ⬜ | ⬜ | ⬜ | ⬜ | |
| **Flood** | Machine gun | T3 | 1 | ✅ | ⬜ | ⬜ | ⬜ | ⬜ | |
| **Ray Trace** | Wildcard | T4 | 1 | ✅ | ⬜ | ⬜ | ⬜ | ⬜ | |
| **Loopback** | Wildcard | T4 | 3 | ✅ | ⬜ | ⬜ | ⬜ | ⬜ | |
| **Dual Boot** | Wildcard | T4 | 3 | ✅ | ⬜ | ⬜ | ⬜ | ⬜ | |
| **Null** | Wildcard | T4 | 3 | ✅ | ⬜ | ⬜ | ⬜ | ⬜ | |
| **Cutter** | Melee | — | 1 | ✅ | ⬜ | ⬜ | ⬜ | ⬜ | |

Note: Bitrate is the master reference. Use the IDs without spaces in code/models: `BurstBuffer`, `HardReset`, `LongPoll`, `RayTrace`, `DualBoot`.

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
| Muzzle flashes / tracers | ⬜ | |
| Hit sparks + pixel-dissolve death | ⬜ | No blood |
| Hit markers, kill icon | ⬜ | |
| Mod icons (8) | ⬜ | SVG → PNG |
| Draft card frames | ⬜ | Normal / upgrade / glitch |
| Gun sounds | ⬜ | Distinct per gun |
| Game icon + 3 thumbnails | ⬜ | |

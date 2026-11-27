# Loading and Performance (2026-11-27)

Workstream 1 of [Launch Hardening 2026-11-27](../05%20Production/Launch%20Hardening%202026-11-27.md). Owner's brief: a regular player saw "a bunch of loading issues" and "sometimes the maps don't load". The owner wants "everything loads well", and is worried lag stops people playing (81% of players are on mobile). Owner decision mid-pass (2026-11-27): a new player's first match teleports to a reserved server like every other match, so **lobby → reserved server → first map** is now the first thing every new player sees, and it got priority.

Earlier passes on the same path: [Handoff - Stability, Loading and Preload](../05%20Production/Handoff%20-%20Stability%2C%20Loading%20and%20Preload.md) (ready tokens, floor hold, BodyReady, spawn retries, loading screen v2).

## How a match map gets to a player (live path)
1. Lobby: QueueService finds the match → `QueueEvent found` → the client's `MatchFoundController` hands Roblox a copy of `ReplicatedFirst.DuelsLoading` (`SetTeleportGui`) → `Launcher` calls `TeleportAsync` `Config.matchFoundDelay` (2 s) after found, with the plan as TeleportData.
2. Reserved server (a Lobby-role server, `ServerRole.isHosted`): `MatchHost.hostedArrival` reads the first arrival's plan, starts the match instance (slot 1, map origin (0, 800, 0)) and puts listed players in `PlayZone` Match.
3. The runner's `MatchService.loop` loads the default map (`Config/Match.MAP` Arena) at once, waits for every seat's `MatchReady` (`Bots/MatchPlan`), picks the map (beginner: Arena; otherwise the vote) and loads it as round 1's select opens. The map is cloned from `ServerStorage.Maps`, moved to the slot and parented `PersistentPerPlayer` for the match's players (`MapService.load`); whole-server matches use `Persistent`.
4. Client: `src/first/LoadingScreen` takes over the teleport screen, closes when `MatchScreensReady` = the match id and the Phase has left Waiting. `FloorHoldController` holds the spawned body still until floor arrives, then fires `BodyReady`; the round's barrier waits for it (`BODY_READY_WAIT`).

## Failure causes found
| # | Cause | Where | Fix |
|---|---|---|---|
| 1 | **The voted map loaded only after the select opened.** Any error opening the draft skipped the map load and the spawn for every retry; reproduced in Studio (an onboarding work-in-progress error at `DraftService:450`: round 1 failed 3 times, the match ended on Arena). | `MatchService.runMatch` | The voted map loads just before `openDraft` (`0a11284d`). |
| 2 | **A failed load left no map.** `MapService.load` destroyed the old map before cloning the new one, so a throw in clone / prepare / pivot left the match with nothing, though `loadMap` promises to keep the old one. `AddPersistentPlayer` ran before parenting, unguarded. | `MapService.load` | The old map goes only once the new one is in; persistent players are added after parenting, each guarded (`0a11284d`). |
| 3 | **A listed player who arrived before the plan existed never played.** Only the first arrival with a plan was put in the match; anyone listed who got there earlier without usable TeleportData stayed in the reserved server's lobby, silently: reads as "the map never loaded". | `MatchHost.hostedArrival` | When the match starts, every listed player already in the server's lobby joins it; unseated arrivals log `[Health] S hosted arrival without a plan` / `not seated` (`0f586770`). |
| 4 | **Roblox's plain teleport screen instead of ours.** The bay lift holds 2.1 s before the MATCH FOUND overlay (tuned for the old 3.5 s delay), and the overlay is what called `SetTeleportGui`; since `13dd1a71` (2026-11-25) the server teleports 2.0 s after found, so a player queued on a bay could start teleporting before our screen was handed over. | `MatchFoundController` | The teleport screen is handed over the moment found arrives (`0ab97a39`). |
| 5 | **Vote pictures loaded only when the vote showed them** (blank cards on a slow phone). | `MapVoteController` (no preload) | `MapLoadController` preloads every `Config/Match MAPS.image` when the match client starts (`0f586770`). |

Ruled out (measured): RIVALS-group meshes in Greenhouse4 (375 parts), Foundry4 (30) and CanyonOutpost (36) are not public, but all 744 Greenhouse4 meshes reach `Success` on the client in Studio. All map meshes load. `AddPersistentPlayer` before parenting did not throw in a Studio hosted match (fixed anyway, #2).

**Guards left:** the client now logs `[Health] C map here <map> <s> after the server sent it, <n> instances` and `[Health] C map content <map> <n> assets in <s>` (or `map content failed` with the ids), from `MapService`'s `MapId` / `LoadedAt` stamps. With the server lines (`map loaded`, `client has its body`, `round start`), a live report can now be traced to the stage that stalled (F9 → Client and Server tabs).

## Match starts (Studio, 2026-11-27)
21 starts in all: 20 reached Live with the map in place. The only failure is cause #1 above, now fixed. Studio runs on one PC over loopback, so these numbers prove the code paths, not phone speed. Times from the `[Health]` lines: S = seconds from the player's join on the server, C = from the lobby client's start.

**Cold** (a fresh Play each time, reserved-server path: `HostedTest`, map forced by `LockMap`, bots fill)
| # | Map | Result | Server map loaded | Client: map here / content | Loading screen done | Round 1 live |
|---|---|---|---|---|---|---|
| 1 | Greenhouse4 | **failed** (before fix #1): draft error ×3, map never loaded, match ended | - | - | C +9.0 s | never |
| 2 | Greenhouse4 | ok | S +3.8 s | (before the guard) | C +5.1 s | S +19.9 s |
| 3 | OldTown4 (2v2) | ok | S +3.5 s | - | C +5.5 s | S +19.6 s |
| 4 | Rooftops4, 1 s replication lag | ok | S +5.3 s | - | C +5.8 s | S +21.4 s |
| 5 | Arena | ok | S +0.3 s | 1.0 s after sent | C +4.6 s | S +18.6 s |
| 6 | Pier | ok | - | 0.6 s / 0.3 s | C +5.3 s | ok |
| 7 | Wharf | ok | - | 0.8 s / 1.2 s | C +4.8 s | ok |
| 8 | Snowpeak4 | ok | - | 2.2 s (arrived during the match client's boot) / 0.7 s | C +5.8 s | ok |

**Warm** (one lobby server, 13 pad duels in a row, `PadDuelSolo`): every duel's map was there 0.0-0.6 s after the zone change; Live 16.2-16.7 s after it; the body on the arena (Y 803) each time. Maps: Foundry4, CanyonOutpost, Metro4, OldTown4, Greenhouse4, Dockyard, BigArena, Arena, Pier, Wharf, Snowpeak4, Rooftops4, Foundry4. Client `map here` 0.0-0.4 s after the server sent it, content 0.0-0.8 s. **Cleanup:** after 7 duels the server had no leftover match folders, runners, bots or state (only the range context).

## Cost per map (measured 2026-11-27)
The server sent each map to a Studio client in turn (PersistentPerPlayer, like a match). Server times: clone + parent of one copy on the Studio PC; that much of one server frame is spent when round 1's select opens.

| Map | Instances | MeshParts | Unique meshes | Client arrival (loopback) | Server clone / parent |
|---|---|---|---|---|---|
| Arena | 263 | 0 | 0 (1 texture) | - | - |
| Pier | 219 | 60 | 23 | 0.04 s | - |
| Dockyard | 422 | 112 | 19 | 0.06 s | - |
| BigArena | 489 | 0 | 0 | 0.07 s | - |
| Foundry4 | 1,781 | 546 | 77 | 0.10 s | - |
| Wharf | 1,852 | 365 | 44 | 0.09 s | - |
| CanyonOutpost | 1,918 | 106 | 38 | 0.10 s | - |
| Snowpeak4 | 2,151 | 509 | 97 | 0.15 s | 25 / 12 ms |
| Metro4 | 3,134 | 198 | 35 | 0.18 s | - |
| Greenhouse4 | 3,764 | 744 | 65 | 0.20 s | 37 / 21 ms |
| Rooftops4 | 5,538 | 1,009 | 84 | 0.26 s | 62 / 32 ms |
| OldTown4 | 7,577 | 2,451 | 85 | 0.37 s | 123 / 49 ms |

Arrival scales with the instance count (about 20,000 instances a second over loopback). On a phone connection it is many times slower, which is why the big maps (OldTown4, Rooftops4, Greenhouse4) matter most. Memory tags (`GraphicsTexture`, `GraphicsMeshParts`) did not move when a map arrived in Studio (the content was already cached), so per-map texture memory needs a phone's F9 Memory tab.

## Client and server costs (measured 2026-11-27)
| What | Measured | Note |
|---|---|---|
| Match client boot (all controllers required + init) | **496 ms** on the Studio PC | The first controller to require the shared tree (`WeaponController`: Viewmodel, Weapons, Effects ...) pays 344 ms of it; no single controller is slow. A phone is several times slower. |
| Hosted join → `MatchReady` | 2.0-4.9 s after the zone change (S `client ready`) | Measured by code-audit (cold HostedTest, Snowpeak4): zone +0.0, lobby client ready +0.2, map here +0.6, match screens ready +2.1, server ready +2.7. The `game.Loaded` wait in `MapVoteController` cost 0 s (already loaded); the gap is the match client's own controller requires / inits before `MapVoteController.start`, plus the 0.5 s `MatchReady` retry. `[Health] C game loaded (waited X s)` now logs when that wait does cost something (a slow phone). The loading screen covers it ("SETTING UP THE MATCH"). |
| Loading screen's own time | READY → closed: ~1-2 s on a join (`minHold` 2.2 s from the reveal), ~1 s on a teleport arrival (only the READY shine) | Owner decisions (v2.1 hold, "tightened for ad retention"); not changed. |
| Lobby client | Workspace 14,676 instances; LobbyV5 8,624 of 20,692 streamed in at spawn (target radius 512) | Streaming settings kept: Min 128 / Target 512 / PauseOutsideLoadedArea / Opportunistic. |
| Hosted match client (before its spawn) | LobbyV5 **1,031** streamed; Workspace 7,594 with Snowpeak4 | The arena slot is 800 studs above the lobby, so a match player gets almost none of the lobby. No `ReplicationFocus` change needed. |
| PlayerGui (every player) | ~8,500 instances (11,311 for the owner with the Admin panel's 2,739) | Biggest: Shop 2,278, BattlePass 910, LockerV3 813, **LockerV2 602 (old, still shipped)**, LobbyBar 308, DraftScreen 307. All built on join, also on a reserved server that goes straight into a match. |
| `Workspace.LockerV3Room` | Persistent, 963 instances | Sent to every client, match players too. |
| `MaterialService` | 491 MaterialVariants, 1,298 unique maps | Textures load only where used. |
| Client scripts in a live round | Top by time: `ViewmodelController.update`, `StateValues.get` (cached), `ModFxController.update`, `ViewmodelRig.apply`, `Simulation/Movement.step` | ScriptProfilerService, 10 s. All small on the PC. |
| Server scripts in a hosted match | Top: `BotService.step` / `Bots/Brain.act`, `Simulation/Poses`, **`Range/RangeBots` (stepStrafers, stepCarriages)** | The range's 39 training bots tick on reserved match servers too, where nobody uses the range. |
| Frame time | Studio: 60 fps, server heartbeat 0.25 ms | Not phone-representative: server and client share one PC. |

## Not measurable here / owner test (phone)
Real teleports, phone bandwidth and phone memory can't run in Studio. After the next publish, on a phone:
1. Queue a match from a bay (and once from the PLAY menu). Our DRAFT DUELS screen should show through the whole teleport, never Roblox's plain one.
2. F9 → Client: `[Health] C map here <map> <s> after the server sent it` and `map content ... in <s>`. Send these numbers for OldTown4 / Rooftops4 / Greenhouse4. Any `map content failed` or `hosted arrival ...` warning is a bug to send.
3. F9 → Memory: total and `GraphicsTexture` in the lobby, then in a match on OldTown4.

## Routed to other workstreams (not changed here)
- **mobile-ui / owner:** ~8,500 PlayerGui instances per player; old `LockerV2` (602) still ships; `LockerV3Room` is Persistent for every client (could stream in when the Locker opens).
- **bots / code-audit:** `Range/RangeBots` stepped on reserved match servers with nobody in the range. **Done** by code-audit (`aa3b6e9e`): it steps only while someone is in the Lobby or Range zone (41 range bots, 0 moving during a hosted match).
- **code-audit:** the `game.Loaded` wait before `MatchReady` measured 0 s: not the cause, kept, now logged when it waits. The zone → ready gap is the match client's boot (requires / inits) plus the 0.5 s retry: the next lever if a phone shows it slow. `Util/MatchLift` HOLD comment fixed (`039c1664`).
- **owner (maps):** OldTown4 (7,577 instances, 2,451 MeshParts) and Rooftops4 (5,538) are the heaviest to send; the biggest win for phones is fewer parts in those two.
- Every match start logs `ContentId rbxassetid://203785492 ... Asset type does not match` and `rbxassetid://81504106 ... not found` (not referenced in `src/`: a Studio-owned asset).

LihFolk used: `roblox-performance-audit` (measure first, budgets, one change per measurement), `roblox-debugging` (repro with a rate, cause in one sentence), Instance Streaming / Fast Join and Deferred Loading (persistent models are sent as a unit; preload only what the screen needs).

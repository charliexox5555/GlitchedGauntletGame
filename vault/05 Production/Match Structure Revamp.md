# Match Structure Revamp (Release 1)

The first Release 1 job, picked by the user on 2026-11-07: a new match flow from the moment you join to the match-end screen. Design decisions below are the user's answers (2026-11-07) to the question list. The design note [Match Flow](../01%20Design/Match%20Flow.md) is updated as each phase is built.

## The new flow
1. **Select:** you land straight in the select screen. **30 s in round 1** (for people to arrive), **15 s after**. The last 3 s are the 3-2-1 with guns in hand behind the barrier (part of the 30/15, not added). Round 1 never ends early; later rounds jump to the 3-2-1 once everyone has locked in.
2. **Auto-select:** a gun and an ability are selected the moment the screen opens (your last gun when it's offered again, else the first card; the first ability card), so doing nothing is fine.
3. **Fight:** 50 s.
4. **Sudden death:** at 0 a circular zone closes on the map's middle. Outside it you take damage **straight to health (the shield doesn't absorb it)**.
5. **Death:** the camera leaves your body while it falls (Valorant-style), then you **spectate living teammates**. In the round-end seconds, with no teammate alive (or in 1v1), you watch **the enemy who killed you**. **No recap card for now** (parked).
6. **Round end:** 5 s, then the next select.
7. **Match end:** the match-winning kill plays as a **replay for everyone**, then a **victory scene on the map** with the post-match screen: stats and **Rematch / Play Again / Leave**.

## Decisions (2026-11-07)
| # | Topic | Decision |
|---|---|---|
| 1 | Select start, late joiners, leavers | Timer starts when the first player arrives. Empty listed slots get a bot; a late listed player takes their bot's place. **Leaver in 1v1: the other player wins. Leaver in team modes: a bot takes their place.** |
| 2 | Early end | Rounds 2+ end early when all are locked, straight to the 3-2-1 |
| 3 | 3-2-1 | Kept, inside the 30/15 |
| 4 | Ability auto-select | Yes, first card |
| 5 | Round time | 50 s |
| 6 | Zone numbers | Starts covering the map at its middle, shrinks over 20 s to a ~8-stud circle and stays; 10 HP/s outside, +5 every 5 s |
| 7 | Zone damage | Straight to health, skips the shield |
| 8 | Zone look | Like Valorant's storm with a glitched vibe; texture made in Blender; tint + warning sound while outside; SUDDEN DEATH on the timer |
| 9 | Death camera | Yes. Recap card parked |
| 10 | Spectate | Living teammates only; round-end seconds with no teammate alive / 1v1: the killer |
| 11 | Spectate camera | **Open:** the answer can read either way (first person rebuilding the other player's view, or third person). Ask before phase B |
| 12 | Final-kill replay | Every client records the last ~6 s; everyone sees the same ~4 s replay over the killer's shoulder, slow motion in the last 0.5 s. Research existing systems first |
| 13 | Victory scene | **On the map**, like RIVALS (reference: `02 Art/References/match-ui/third-party/rivals-post-match-1v1.webp`, git-ignored): winner posed, VICTORY banner, name plate with level, Eliminations / Deaths / Assists, Damage Dealt / Taken. In our v1 UI style, not a copy |
| 14 | Buttons | **Rematch** (vote; every real player within 15 s → same server, same teams; shows Unavailable when it can't happen), **Play Again** (Lobby + straight back into that mode's queue), **Leave** (Lobby). Nobody chooses in 20 s → Lobby |

## Build phases
Each phase is tested in Studio against bots (2v2 for spectating) before the next. Results go in `Playtests/`.

### A. Select flow and sudden death
- **A1 Select:** drop the Ready phase; `Config/Match` select times 30/15 with the 3 s countdown inside; the draft opens when the first player arrives; early end in rounds 2+; ability card preselected; round end 5 s.
- **A2 Seats:** a fighter slot (team + index) owns its draft seat, so a seat can pass between a bot and a player (`DraftService` transfer of kit, levels, guns). Missing listed players get a bot when the select opens; a late player takes the bot's seat at once during a select, or at the next round during a fight (spectating until then). Team-mode leaver → a bot takes the seat (from the next round if mid-fight). 1v1 leaver, or a side with no real players left that started with some → the other side wins.
- **A3 Zone:** new `ZoneService` (server) publishes centre, start/end radius and start/end times as `Match*` attributes (commit last); the damage tick runs on the server (4/s, point-in-circle on the root, straight to `HealthService.damage`). Centre: a `ZoneCentre` tag on the map, else halfway between the team spawns; the start radius is 1.6 × the furthest spawn (or the centre part's `ZoneRadius` attribute), not the map's bounding box, since maps carry far backdrops. Bots head for the zone centre during sudden death. Safety cap: if a round somehow lasts 60 s into sudden death, the old health compare decides it. Client `ZoneController`: a ring of Beams with a scrolling Blender-rendered glitch-storm texture (cheap, scales smoothly with the radius), red tint and warning sound outside, SUDDEN DEATH on the top-bar timer.

### B. Death camera and spectating
Death camera pull-out over the existing death look (`DeathFxController`); spectate living teammates (click / LB-RB / on-screen arrows), the killer in the round-end seconds; `ReplicationFocus` on the target while spectating. Camera style waits on decision 11.

### C. Final-kill replay
Client ring buffer of every fighter (+ shots), synced playback on the match-winning kill.

**Research (2026-11-07, web; LihFolk has no recipe):** no source says how RIVALS, Arsenal, Bad Business or Phantom Forces build their kill cams. Community modules exist but are old and only part fit: boatbomber's VPF Replay Module (2020, ViewportFrame, 20 FPS, heavy), MaximussDev's ReplayService (deprecated, client-side, keyframes on a dummy), popgoesme700's Instance Recorder (any property, 10 s buffer, no animations). None is worth taking whole; we build our own on their ideas.
- **Record on each client**, the server only sends the trigger `{killTime, killer, victim, startAt = now + 0.3}`. Every client already sees all fighters, so no extra traffic.
- **Per frame at 30 Hz** in a preallocated ring buffer (~180 frames): the world CFrame of every visible limb and the gun's main part, read in `PreRender`, plus the killer's head/aim; shot events from the existing `ShotFx` handler. About 25k CFrames for 8 fighters (an estimate).
- **Limb CFrames, not joint Transforms:** writing `Transform` on AnimationConstraint rigs under Server Authority is a confirmed Roblox bug (devforum 4846108, also in Architecture → Rojo notes).
- **Play back on anchored clones in Workspace** (real map and lighting), not a ViewportFrame; lerp between frames; the last 0.5 s at about 0.25×.
- Hide live characters, the viewmodel and HUD during playback; restore on finish, also if a fighter leaves mid-replay. Check in Studio whether `PreRender` part CFrames are the smoothed render positions.
- Sources: devforum 523112 (VPF Replay Module), 1241539 (ReplayService), 2660683 (Instance Recorder), 1828015 and 1321131 (kill cam threads), 4846108 (Transform bug); create.roblox.com streaming docs; GDC "Replay Technology in Overwatch".

### D. Match end
`MatchStats` (eliminations, deaths, assists, damage dealt / taken; credit rules from LihFolk), victory scene on the map, post-match screen, Rematch vote, Play Again (Lobby requeue flag in TeleportData), Leave; the match server stops starting a new match by itself. Teleports server-side with retries and `TeleportInitFailed`.

## LihFolk notes used
- Round-Based Minigame Loop End to End; Arena Rounds with Teams and Spectating End to End; Spawning Teams and Rounds (state machine, end times as attributes, picks checked against the deadline)
- Weather System Architecture; Zone Detection - Area Enter and Exit (server-owned zone as data, clients tween from server time, no Touched)
- Cameras and Cutscenes; Camera Systems; Instance Streaming; Interest Management and Per-Player Replication (death cam, spectate, ReplicationFocus)
- Kill Credit, Assists, Kill Feed and Death Recaps (stats)
- Teleporting and Multi-Place Games; Parties and Group Teleports; API Renames and Deprecations 2025-2026 (Rematch / Play Again / Leave)

LihFolk has no numbers for a storm zone and no replay recipe; those are our own starting numbers and design.

## Results
### Phase A (2026-11-07)
Built and playtested in the match Studio (solo against bots, then `BotMatch` 2v2). Details: [playtest](Playtests/2026-11-07%20Match%20Revamp%20Phase%20A.md).
- **Code:** `Config/Match` (select times, `SUDDEN_DEATH`), `MatchService` (select flow, sudden death, stand-ins, takeovers, leavers, forfeit), `DraftService` (`deal` / `join` / `transfer`, preselected gun and ability), new `ZoneService` + `shared/Zone`, bots head into the circle (`Bots/Brain`), new `ZoneController`, HUD sudden-death banner and clock, `Config/Juice ZONE`, `UiSounds.ZoneWarn` (provisional).
- **Art:** `tools/vfx/make_zone_vfx.py` (Blender noise on a cylinder so it tiles, numpy glitch pass) → `art-source/vfx/zone/zone_wall.png`, `zone_glitch.png`, uploaded (images 108018292345432, 128662496057045). Preview: `02 Art/References/zone/zone_vfx_preview.png`.
- **Review (roblox-reviewer) and fixes:** a late player leaving before their takeover no longer adds a second bot; a bot that takes a leaver's seat becomes their stand-in, so a rejoin takes the seat back; team-mode sides never grow past the mode's size; late listed players are put on their plan team at once; stale stand-ins are cleared with the bots; a read no longer creates an undealt seat (`dealtRound`); takeovers also work during the 3-2-1; a leaver's replacement bot spawns alone (the others aren't respawned); picks past the deadline are refused; 3 rounds in a row with a side that can't spawn end the match; the error path resets the draft. Bot stand-ins fill seats even when the plan says `bots = false` (decision 1).
- **Bug found and fixed in the recheck:** the zone's server times were stored in a Vector2 attribute, which is 32-bit and rounded ~1.8e9 to the same value, so clients and bots saw the circle already closed. Now two number attributes (`MatchZoneStart` / `MatchZoneEnd`). Rechecked: the radius shrinks smoothly on the client (166.7 → 96.9 in 9 s) and the ring drops segments as it goes.
- **Open:** late joining and leaving need a two-client test; the wall look and the warning sound need the user's eye and ear.

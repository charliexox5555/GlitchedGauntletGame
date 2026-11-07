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
| 11 | Spectate camera | **First person (confirmed 2026-11-07):** you see through the teammate's eyes with their gun and arms, rebuilt from what already replicates |
| 12 | Final-kill replay | Every client records the last ~6 s; everyone sees the same ~5 s replay, slow motion into the kill. **Changed 2026-11-08 (user): through the killer's own eyes, as the winning player saw it** (first person, their gun and arms), not over the shoulder |
| 13 | Victory scene | **On the map**, like RIVALS (reference: `02 Art/References/match-ui/third-party/rivals-post-match-1v1.webp`, git-ignored): winner posed, VICTORY banner, name plate with level, Eliminations / Deaths / Assists, Damage Dealt / Taken. In our v1 UI style, not a copy |
| 14 | Buttons | **Rematch** (vote; every real player within 15 s → same server, same teams; shows Unavailable when it can't happen), **Play Again** (Lobby + straight back into that mode's queue), **Leave** (Lobby). Nobody chooses in 20 s → Lobby |

## Build phases
Each phase is tested in Studio against bots (2v2 for spectating) before the next. Results go in `Playtests/`.

### A. Select flow and sudden death
- **A1 Select:** drop the Ready phase; `Config/Match` select times 30/15 with the 3 s countdown inside; the draft opens when the first player arrives; early end in rounds 2+; ability card preselected; round end 5 s.
- **A2 Seats:** a fighter slot (team + index) owns its draft seat, so a seat can pass between a bot and a player (`DraftService` transfer of kit, levels, guns). Missing listed players get a bot when the select opens; a late player takes the bot's seat at once during a select, or at the next round during a fight (spectating until then). Team-mode leaver → a bot takes the seat (from the next round if mid-fight). 1v1 leaver, or a side with no real players left that started with some → the other side wins.
- **A3 Zone:** new `ZoneService` (server) publishes centre, start/end radius and start/end times as `Match*` attributes (commit last); the damage tick runs on the server (4/s, point-in-circle on the root, straight to `HealthService.damage`). Centre: a `ZoneCentre` tag on the map, else halfway between the team spawns; the start radius is 1.6 × the furthest spawn (or the centre part's `ZoneRadius` attribute), not the map's bounding box, since maps carry far backdrops. Bots head for the zone centre during sudden death. Safety cap: if a round somehow lasts 60 s into sudden death, the old health compare decides it. Client `ZoneController`: a ring of Beams with a scrolling Blender-rendered glitch-storm texture (cheap, scales smoothly with the radius), red tint and warning sound outside, SUDDEN DEATH on the top-bar timer.

### B. Death camera and spectating (first person)
- **Death camera:** when you go down, your own body gets the falling copy too (`DeathFxController`), and the camera pulls up and back out of your head to watch it fall (about 1.2 s, held 0.7 s, screen greyed).
- **Spectate:** then you see through a living teammate's eyes. Click / right-click (the gamepad triggers, or the on-screen arrows) cycles teammates. In the round-end seconds, with no teammate alive (or in 1v1), you watch the enemy who killed you. A bar at the bottom names who you're watching, with their health; your own health and ammo panels hide.
- **Rebuilding their view** from what already replicates, no new per-frame traffic:
  - camera: their head position, yaw from their body, pitch from the `AimPitch` attribute (sent 10 times a second, smoothed);
  - gun: `WorldWeapon`'s `WeaponId` → the viewmodel equips it with its draw;
  - aiming down sights: the `Aiming` attribute → the viewmodel's ADS and the zoom (scope overlay on scoped guns);
  - shots: their `ShotFx` → the viewmodel's fire clip, muzzle flash and tracer from the view gun;
  - reloads: `ReloadAt` / `ReloadFor`; a held Mod (`ModHeld`) lowers the gun; their move state (`MoveState`) drives the bob;
  - arms: their own shirt and skin colours.
  - Bots get `AimPitch` / `Aiming` attributes too (throttled like a player's).
- **Code:** a `CameraController` override hook, `WeaponController` stands down while spectating, `ViewmodelController.setSubject`, `EffectsController` treats the target's shots like your own, new `SpectateController` (client) and `SpectateService` (server: a validated, rate-limited `Spectate` remote that sets your `ReplicationFocus` to the target so their surroundings stream in; only a downed or unspawned player, only a teammate, or any fighter during the round end).

### C. Final-kill replay
Client ring buffer of every fighter (+ shots), synced playback on the match-winning kill.

**Design (2026-11-07):**
- **Server:** `MatchService` notes each side's last fighter to go down (`HealthService.onDowned`). When a round's elimination wins the match, it skips that round's 5 s round end: a 0.8 s beat, then a new **Replay** phase, and the `Replay` remote tells every client `(victim body, kill time, start time)`. Only the losing side's last down, only if it was eliminated within the last second; forfeits, timeouts and health compares get no replay. Then MatchEnd (phase D).
- **Recorder (`ReplayController`, every client):** at 30 Hz, the CFrame of each fighter's body parts (players and bots) in a preallocated ring of 6 s, stamped with server time; `ShotFx` events and who killed whom (`Killed`) go in alongside.
- **Playback:** the window from 2.9 s before the kill to 0.3 s after, centred on the kill as each client saw it (its recording lags the server by its ping); normal speed until 0.4 s before the kill, then 0.3× (4.83 s, plus 0.3 s start delay and 0.6 s hold; one shared sum in `MatchState.replayLength`). Each fighter is an anchored copy of its body (body joints removed, accessories and the held gun stay welded), moved by lerping between frames. Recorded shots replay through the normal shot effects on the copies; at the kill the victim's copy plays the death fall. The camera is **the killer's own first-person view** (changed 2026-11-08): each frame also records every fighter's yaw, pitch, aiming and gun (yours from your camera, others' from body facing and the `AimPitch` / `Aiming` attributes); playback puts the camera in the killer copy's head, hides that copy, and drives the viewmodel with their gun, aim-down-sights, zoom and recorded shots (like spectating). No killer (the zone): a slow orbit of the victim. Live bodies, death copies, the viewmodel and the HUD hide; black letterbox bars and a FINAL KILL line (killer → victim). Everything restores after.
- Numbers in `Config/Match REPLAY`.

**Research (2026-11-07, web; LihFolk has no recipe):** no source says how RIVALS, Arsenal, Bad Business or Phantom Forces build their kill cams. Community modules exist but are old and only part fit: boatbomber's VPF Replay Module (2020, ViewportFrame, 20 FPS, heavy), MaximussDev's ReplayService (deprecated, client-side, keyframes on a dummy), popgoesme700's Instance Recorder (any property, 10 s buffer, no animations). None is worth taking whole; we build our own on their ideas.
- **Record on each client**, the server only sends the trigger `{killTime, killer, victim, startAt = now + 0.3}`. Every client already sees all fighters, so no extra traffic.
- **Per frame at 30 Hz** in a preallocated ring buffer (~180 frames): the world CFrame of every visible limb and the gun's main part, read in `PreRender`, plus the killer's head/aim; shot events from the existing `ShotFx` handler. About 25k CFrames for 8 fighters (an estimate).
- **Limb CFrames, not joint Transforms:** writing `Transform` on AnimationConstraint rigs under Server Authority is a confirmed Roblox bug (devforum 4846108, also in Architecture → Rojo notes).
- **Play back on anchored clones in Workspace** (real map and lighting), not a ViewportFrame; lerp between frames; the last 0.5 s at about 0.25×.
- Hide live characters, the viewmodel and HUD during playback; restore on finish, also if a fighter leaves mid-replay. Check in Studio whether `PreRender` part CFrames are the smoothed render positions.
- Sources: devforum 523112 (VPF Replay Module), 1241539 (ReplayService), 2660683 (Instance Recorder), 1828015 and 1321131 (kill cam threads), 4846108 (Transform bug); create.roblox.com streaming docs; GDC "Replay Technology in Overwatch".

### D. Match end
- **Stats (`StatsService`, server):** per fighter (players and bots): eliminations, deaths, assists, damage dealt, damage taken. Damage and kills come from WeaponService's two damage paths (players' and bots'); deaths from `HealthService.onDowned` (zone and falls too). An assist is damage on the victim in the 10 s before the kill by anyone but the killer (LihFolk "Kill Credit, Assists, Kill Feed and Death Recaps"). MVP: most eliminations, then damage. Sent to every client at match end (`MatchSummary` remote).
- **Server flow:** after the replay (or straight away for a forfeit or a timeout win), a **MatchEnd** phase of 20 s. `MatchChoice` remote (validated, rate-limited, MatchEnd only): `Rematch` (a vote; when every real player still here has voted, a new match starts on this server with the same sides, bots refilling), `PlayAgain` (teleport to the Lobby with TeleportData `{ requeue = mode }`), `Leave` (teleport to the Lobby). At 0, everyone left goes to the Lobby. Teleports from the server with retries and `TeleportInitFailed`, as the Lobby's Launcher does. Rematch shows Unavailable once someone has left or picked another button. The match server no longer starts a new match by itself (Studio, where teleports can't run, starts a new one after the 20 s so testing goes on).
- **Lobby:** a player arriving with a valid `requeue` mode goes straight into that mode's queue.
- **Victory scene (client, on the map):** copies of the winning side stand where their first fighter ended the match, side by side on the ground, playing a cheer; the camera is in front at chest height, a slow push in. Live bodies, the viewmodel and the combat HUD hide.
- **Post-match screen (v1 style, layout after the RIVALS reference):** a top banner VICTORY / DEFEAT with the score; your card at the bottom (name, MVP tag, Eliminations / Deaths / Assists, Damage Dealt / Taken); in team modes a small table of everyone; Rematch (with the vote count, or Unavailable), Play Again and Leave at the bottom right, and the countdown to the Lobby. The player level waits for progression.

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

### Phase B (2026-11-07)
Built and tested in the match Studio: the death camera, a bot teammate's first-person view in 2v2, the killer's view at round end in 1v1. Details: [playtest](Playtests/2026-11-07%20Match%20Revamp%20Phase%20B.md).
- **Code:** new `SpectateController` (client) and `SpectateService` (server, `Spectate` remote → `ReplicationFocus`); `CameraController.setOverride`; `WeaponController.setSpectating`; `ViewmodelController.setSubject`; `EffectsController.setSpectated`; `HudController.setSpectating`; `DeathFxController` (own body falls too, `clearGrade`); bots publish `AimPitch` / `Aiming`; `Config/Juice SPECTATE`.
- **Found:** your own `Downed` change signal didn't fire on the client in the test, so the gun stayed up after death; going down is now polled (spectate, weapons, Mods).
- **Review (roblox-reviewer):** the `Spectate` remote passed (no way to see enemies mid-round). Fixed: the watched body stays hidden even under a dash ghost; Mod keys do nothing while you're down (your Mod no longer shows in their hands); no crosshair on the death camera; spectating ends at match end, on `Waiting`, or when the target leaves with nobody else to watch; bots stop "aiming" when they stop fighting; the `Spectate` request goes once cycling settles; the server drops focus on an enemy after the round end and on someone who left; a respawn no longer strips the watched gun; your own move FOV and roll don't ride on the watched view; the tick loop survives an error.
- **Open:** cycling with 3+ teammates, a real player's view, reload / ADS / Mod / shot details in the watched view, the user's look.

### Phase C (2026-11-07)
Built and tested in the match Studio (1v1, the bot's match-winning kill). Details: [playtest](Playtests/2026-11-07%20Match%20Revamp%20Phase%20C.md).
- **Code:** new `ReplayController` (recorder + playback) and `Util/ShotLog`; `MatchService.playReplay` + the `Replay` remote and phase; `Config/Match REPLAY`; `DeathFxController.playFall`; `EffectsController.playShot`; `SpectateController.stop`.
- **Camera framing:** ~~over the shoulder / beside the victim~~ replaced 2026-11-08 by the killer's first-person view (see Design above). Tested: the bot killer's view with its pistol and arms, ending on the victim's fall down the alley. Also fixed: the death camera's round-end grace could restart it during the replay; that grace now applies in RoundEnd only.
- **Found:** the death camera restarted during the replay; your own arms stayed on the camera after death. Both fixed.
- **Review (roblox-reviewer) and fixes:** the death fall on a copy no longer comes apart (its joints are switched off, not destroyed, and come back for the fall, which plays inside the replay's folder); one clean-up path undoes everything even after an error; the downed grey goes for the replay; only the eliminated side's last fighter is replayed (not a timeout, not the winner's side); the server rechecks the victim after the beat; a client that can't frame the victim skips it; recording runs only in Live / SuddenDeath and not in test mode, at a steady rate; live bodies are kept hidden every frame; copies lose highlights, labels and attributes; your own knife swings are recorded; the camera code can't spam errors. Left as known: per-sample allocations in the recorder, the fall plays at normal speed inside the slow motion, map-fall kills are captioned THE ZONE, the winner has no gun after the replay (phase D's scene takes over).
- **Open:** the slow-motion close-up, shots and the fall on the copies, team-mode and zone-kill replays, the user's look.

### Phase D (2026-11-07)
Built and tested in the match Studio (1v1, the bot won the last round by a kill). Details: [playtest](Playtests/2026-11-07%20Match%20Revamp%20Phase%20D.md).
- **Code:** new `StatsService`, `MatchEndService` (`MatchSummary`, `MatchChoice`), `MatchEndController`; `WeaponService.onHit`; `MatchService` returns rematch / waits for the server to empty; Lobby `QueueService.requeueFromMatch`; `Config/Match MATCH_END`; `Config/Animations COMBAT.Victory` (Roblox's R15 Cheer, a placeholder); bots carry a `BotId`.
- **Review (roblox-reviewer) and fixes:** the `MatchChoice` remote passed (only your own choice, only the three words, mode and destination from the server); the Lobby's TeleportData check passed. Fixed: a player whose teleport keeps failing stays on a list and is resent while the server waits (and can press Leave again); only Flooded / Failure are retried, with one counter; the remote is connected once (events can't queue up for the next match end); players who join during the screen go to the Lobby too; the end-of-clock teleport goes as one group; team damage (Molly, Firewall) earns no stats; a fully blocked hit isn't an assist; bot stats keyed by a unique id; no bots-only match on an empty server; Rematch can't be clicked when unavailable; the rematch draft keeps its cursor; hidden gun parts come back; the round-ending kill still gets its death camera.
- **Known, left:** the screen goes as soon as the phase changes (players leaving briefly see the map before the teleport); a stand-in's or a leaver's stats line stays in the table; restoring hidden GUIs can't tell if their owner hid one in the meantime.
- **Open:** real teleports (Play Again, Leave, timeout) need a published test; the cheer on the copies; team-mode tables; two-player rematch votes.

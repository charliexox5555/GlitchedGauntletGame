# Place Merge Plan (2026-11-21)

The owner's call: **the Lobby and the match become one place.** Everything runs together.

## Owner decisions (2026-11-21)
| Question | Answer |
|---|---|
| Which place stays | **Lobby place** (PlaceId 71551303511506). Maps, match assets and match code move into it. The match place (133387545285290) is retired and kept as a backup. |
| UI queue (PLAY → FIND MATCH) | **Global, across all servers.** Matched groups teleport to a **restricted private server of the same place** (a reserved server) to play. |
| Duel pads in the lobby | Start the duel **in this server**: the match is built and played inside the lobby server. Pads look different while filling. |
| Pad duels per server | **Several at once.** Each duel has its own state, map copy, players and UI. |
| Pad that isn't full | **Real players only.** It waits until every slot has a player from this server, counts down, then starts. No bots. |
| Range this pass | **Guns only.** Enter the range and get your Locker loadout (real match guns, skins, ADS, reload) to shoot dummies. Leaving takes the guns away. Mods come later. |

## Where it starts from (code survey)
- Two codebases: Lobby `src/lobby/*` (Queue, Parties, Shop, Locker, PlayerData, Settings, Range teleport) with `lobby.project.json`; match `src/server` + `src/client` (~9,000 server lines) with `default.project.json`. They already live in separate containers (`LobbyServer` / `Server`, `LobbyClient` / `Client`) and separate remote folders (`LobbyRemotes` / `Net`), so they can be in one tree without name clashes. Duplicated behaviour to fold: `ServerInfoService`, `NetStatsController`, `SoundAuditionController`.
- The queue (`QueueService` + `Matchmaking/Matchmaker` + `Launcher`) only matches **inside one server**, then teleports to a reserved match server with TeleportData (`v, matchId, mode, teams, bots`), which the match reads in `Bots/MatchPlan`.
- **The match code assumes one match per server.** Match state is one folder in ReplicatedStorage (`shared/MatchState`), services keep module-level state (`MatchService` plan, stand-ins, teams; `DraftService`, `MapService`, `BotService`, Mods …), and 23 services use `Players.PlayerAdded` / `GetPlayers` as "everyone is in the match". Clients read the one MatchState folder.
- The match already has a **test range mode** (`TestRangeService` + `TestRange/Dummies`): dummies get shot through the normal `WeaponService` checks; reserve ammo is endless in test mode. The lobby range (`RangeService`) only moves bodies today.

## Target architecture
- **One place, two server roles** (`shared/ServerRole`):
  - **Lobby**: a public server. Lobby world + lobby UI; the range; **pad duels** run here as match instances.
  - **Match**: a reserved server of the same place (`game.PrivateServerId ~= ""` and `PrivateServerOwnerId == 0`) holding one queued match. The lobby UI is hidden; data services (PlayerData, Settings, Locker loadout) still run. When the match ends, players go back to a public Lobby server, parties together.
  - Studio: `workspace` attribute `ServerRole` = `"Match"` tests the match role; default Lobby.
- **Match instances** (for pad duels; the reserved server runs exactly one): each duel is its own context with its own state folder (`ReplicatedStorage.Matches.<id>`), player list, map copy far from the lobby, and remote scoping (only its players' events reach it, and it only fires to them). Players carry a `MatchId` attribute; the client's MatchState follows the local player's match and is empty in the lobby, so match controllers sleep and the lobby HUD shows.
- **Global queue:** MemoryStore holds the waiting groups for each mode; one server at a time (a lease that expires) runs `Matchmaker.pack` over all of them, reserves one server per match, and tells each group's home server (MessagingService, topic per JobId) to teleport its players there with the TeleportData. The current bot fill after `fillAfter` stays. Groups are removed when they cancel, leave or their server shuts down (TTL as the backstop).

## Phases (each one a working, committed step)
1. **Foundation.** One project file (`default.project.json` = lobby + match trees), `ServerRole`, both code sets boot together; match services sleep in the Lobby role until a match instance or the range asks for them. Duplicates folded.
2. **Global queue.** MemoryStore queue + matchmaker lease + MessagingService handoff, teleport to a reserved server of this place, return to a public lobby after the match. Can't be fully tested in Studio (no teleports): needs a published test with two accounts.
3. **Range guns.** Entering the range gives the Locker loadout through `WeaponService` (endless reserve), the lobby range's dummies take hits through the normal checks, leaving removes the guns and the viewmodel.
4. **Match instances (pad duels).** Scope MatchState, remotes, the player list and map placement per match; pads fill with players from this server, count down, start a duel; players come back to the lobby afterwards. Several duels at once.
5. **Studio move.** The 12 release maps, map kits, ambience, MaterialService variants and match-only assets copied from the match place into the Lobby place; save; check every map loads in both roles.

6. **Third-person body (owner 2026-11-21, added mid-merge).** Replace the blocky match body with a smooth, RIVALS-like third-person body, used everywhere: in matches, in the range and also for players walking the lobby (who can then run and slide too). Keep the player's own face and hair to an extent, as RIVALS does. New third-person animations that read well (aim pitch looking up and down, run, slide), "flawless and smooth". Start with a study of the RIVALS body in the RIVALS place (the owner left it in play mode, and allows stopping it and playing it to look): its mesh setup, how it keeps the face and hair, and how its animation layers work. Then decide whether to rebuild it or make something very close. Touches `shared/MatchBody`, `CharacterService`, `Config/Avatar`, the animation configs and the lobby movement.
   - **Done 2026-11-21: the body.** RIVALS' body turned out to be the public community bundle "S15 - Skinned Classic 1.0" (209745, by ellieflopper, for any R15 game) on the player's own description. We now wear the same body in matches and the range, with own heads and a standard `HitboxHead`. Details in [Match Avatar](../01%20Design/Match%20Avatar.md#skinned-classic-body-2026-11-21). **Lobby done too:** everyone wears it in the lobby, with run and slide (see Match Avatar → Lobby). **Left:** third-person animations tuned for the body; phone sprint / slide buttons in the lobby.

## Open questions (ask as they come up)
- Pad duel map: map vote (as now) or one map per pad? Default: vote among maps that fit the size.
- Can lobby players watch a pad duel? Default: not in this pass.
- What players see while a pad fills (count over the pad, ring fill)? Default: a player count and a fill ring in the pad colour.

## LihFolk notes used
`41 Multiplayer Services`: Teleporting and Multi-Place Games; Reserved and Private Servers in Practice; TeleportService - Engine Reference Card; Matchmaking Queues with MemoryStore; MemoryStore Service; Error Handling and Retries.

## Results (2026-11-21)
**Built and tested in the Lobby Studio** (single-player playtests through the Studio MCP).
- **Step 1, one place** (commit `bc22cc09`). `lobby.project.json` now carries the match server and client too, and is the merged place's project. `default.project.json` still serves the retired match place, where everything plays as a Match server. `ServerRole`, `PlayZone`, `MatchScreens`. Players spawn in LobbyV5. The match client in a lobby server runs only while the player is armed. **Studio move:** the 12 release maps went to `ServerStorage.Maps`, plus `MapKit`/`MapTools`, `Abilities`, `OvertimeZoneMeshes`, 7 `UiTemplates` folders, RuinBlighted and ShadowMistRound skins, 69 MaterialVariants, and the 10 match screens to `ReplicatedStorage.MatchScreens`. These were copied over a DataStore bridge (SerializationService, `MergeTransfer_v1`) and the Lobby place saved as v931. The RIVALS copies (Docks, Museum, Rivals Asset Pack, MapsRivals) were not moved; they stay in the match place.
- **Range** (step 1). Join → match body, first person, new HUD, 25/∞ Vandal, lobby HUD hidden. Leave → own avatar, third person, lobby HUD back. Entered and left twice: a fresh client each time, no errors.
- **Step 2, global queue** (commit `6b5825eb`). In Studio a 1v1 search wrote a ticket, this server took the lease, the matchmaker filled with a bot after 5 s and claimed the ticket, and the launcher would teleport to a reserved server of 71551303511506. **Not tested yet:** two real servers matching each other, and a real teleport (needs the place published and two accounts).
- **Match role in the Lobby place** (Studio Workspace attr `ServerRole = "Match"`, `BotMatch = "1v1"`). The whole match runs through `MatchHost` → `MatchRunner`: map, draft, rounds; lobby screens off.
- **Step 3, pad duels.** Standing on Bay_05 side A (Studio `PadDuelSolo`) gave A=1, a 3 s count, then a duel `443387b0` in slot 1: Arena at x 24,500 in `Workspace.Matches`, its own state folder, a bot, the draft screen, rounds counting. The lobby's own state was untouched.

- **Wrap-up (2026-11-21, late).** Everyone wears the skinned classic body, lobby included, and runs and slides there. The lobby has its own **unarmed** animation set: a relaxed idle, an arm swing in step with the legs for walk / run / sprint, loose crouch arms, and an unarmed slide in and out (Third Person Overhaul §26). Looking up leans the body from the waist (§25). **Rojo:** `lobby.project.json` became **`default.project.json`** (the one place, port 34873). The retired match place's project moved to `archive/match-place.project.json`. CI builds the one project. The match place's Rojo server is gone; the owner archives that place. **Final Studio checks (merged code, solo):** lobby spawn in the S15 body; unarmed idle, sprint into slide (unarmed clips, no rifle ones); range in and out; a pad duel start to finish with the return to the lobby; the bot match in the Match role.

- **Dev panels kept (2026-11-21, owner: "maintain all the dev panels" in Studio).** F4 sound board, F6 gun review, F7 skin preview, F8 Mod test panel and P gun picker work in the range and in matches. F4 also works on the lobby floor. **F4** was toggled twice per press (the lobby and match clients both started it); `SoundAudition.start` now listens once and has all tabs. **F8** in the range: MatchHost runs a **practice context** `range` (`PRACTICE_SERVICES`: the Mods + DevModService, no match loop) that range players join and leave. **Bug fixed with it:** in the match-flow modules `Players` is the per-match stand-in, so `player.Parent == Players` was always false. Those checks now use `PlayersService`; this also fixes the match-end teleport in private match servers.
- **Range "default animations / can't run" fix:** the movement and pose simulations now rebind on every initialize (the newest match-client copy owns the step). The old "still connected" guard could skip the bind during the zone swap. **Unarmed walk v2:** a smaller, looser swing with the arms trailing the legs; arms are phase-locked to the legs instead of snapped (no pops).

### Owner test round 2 (2026-11-22): what was wrong, and the fixes
- **Root cause of most of it: `shared/StateValues` picked its authored data by PlaceId.** It loaded only the Lobby* modules in the Lobby place, so in the merged place every match object lost its data: MatchInterface (the top bar's Studio preview cells stayed, so a 1v1 showed **3 cells a side**, the empty ones looking like bots with no picture or level), MatchWeapons (gun ids, grips), MatchAbilities (ability models), MatchMaps, MatchSettings. It now loads every module in every server (tags are prefixed per module, no collisions). Nothing was missing from the place itself: guns (1,541), abilities (793), skins, the 12 maps (29,120 parts), map kits and match screens all match the old place.
- **Gun poses back in the lobby after the range:** `Weapon/WorldModel.attach(character, nil)` removed the world gun but returned before clearing the player's `WeaponId`, so the poses stayed armed. Now cleared.
- **Floating in the sky while the map loads:** the whole map is a persistent model, and players spawned before their area had streamed in (StreamingIntegrityMode PauseOutsideLoadedArea). MatchService now runs `RequestStreamAroundAsync` on each spawn first (STREAM_WAIT 6 s). Online only; Studio loads instantly.
- **Win cutscene body:** the S15 body parts were Plastic. MatchBody now sets `Avatar.BODY_MATERIAL` (SmoothPlastic) on every body part, including parts an ApplyDescription rebuilds (players, bots, cutscene copies).
- **Winners clipping into props:** a box check of the five winner spots on all 12 maps found six that clashed. Their WinnerStage parts moved to the nearest clear, flat spot on the same floor with the same facing: OldTown4 2 studs (pot bush), Foundry4 2 (coil), Snowpeak4 4 (drift), Wharf 12 (container), CanyonOutpost 18 (inside the trading post), Rooftops4 26 (curbs, lamp, catwalk). All 12 are clear now. Saved in Studio (place version 959).
- **Slide "mostly just crouches":** the slide only started if the crouch press landed on a frame where you were already in the run, so an early press or a press in the 0.6 s cooldown became a crouch. The press is now buffered (`Movement.SLIDE_BUFFER` 0.25 s, field `CrouchPressAt`), and the run keeps going while it waits. Tested: a press 20 ms after W slides, a press in the cooldown slides when it ends, C standing still crouches at once.
- **Empty-hands run "clunky":** it used the gun sprint's legs (0.36 s cycle, 15 degree lean: a hunched scamper). It now has its own `SprintRunUnarmed` legs (0.42 s cycle, 6 degree lean; foot lock 98.8%, slip 0.25 vs the gun sprint's 95.8% and 0.93) and calmer arms (SprintUnarmed v3). The walk swing is a touch bigger (v3).
- **Cleanup (2026-11-22, owner: "get rid of all unused outdated code").** An audit of every module found nothing orphaned (every Service and Controller is loaded by a folder scan or MatchRunner). Removed:
  - **Two-place leftovers:** the legacy-place branches in ServerRole; `MATCH_PLACE_ID`; `MATCH_END.lobbyPlaceId` (now `game.PlaceId`); the StarterGui fallback in MatchScreens; the unused `LobbyClient.SharedUi` Rojo mapping.
  - **Duplicate code:** the lobby's copy of ServerInfoService (one shared service now); four copies of `Ui.make`; the Locker's copy of `ItemStage.presentable`.
  - **Unused code:** 15 exported functions nobody called; 5 config keys nobody read.
  - **Kept on purpose:**
    - `server/WeaponBuild` (the gun pipeline's builder).
    - The Studio "would teleport" stand-ins (Studio can't teleport).
    - The lobby HUD's `setBadge` and `setTasks` hooks.
    - Unused texture and theme ids, possibly planned UI or VFX.
    - Files with another lane's uncommitted edits: Viewmodel/WeaponController, Config/Viewmodel, Config/SkinPreview.

### Owner test round 3 (2026-11-22): "half the shots don't register" (hit markers, no damage)
- **Main cause: headshots never counted.** Since the S15 body every fighter carries an invisible `HitboxHead` (the visible head has CanQuery off), but `Config/Combat.BODY_PARTS` didn't list it. The client hit it and drew the marker; the server rejected it as "not a live tracked hitbox". Added. Checked in Studio: `Targets.hitboxOwner(HitboxHead)` finds the fighter and `Hits.validate` accepts a HitboxHead hit. Bots can land headshots again too (BotGun reads the same list).
- **Online: a late packet cost the next shot.** The fire-rate clock jumped to a late shot's arrival time, so the next, on-time shot looked too fast. A shot arriving within `Combat.FIRE_CATCHUP` (0.2 s) of its due time now keeps the schedule; after a real pause the clock restarts at arrival. Simulated 30-shot Vandal sprays: old 90% / 80% accepted at 80 / 150 ms jitter, new 100% / 99%. Instant spam on a 1 s gun still gets one shot.
- **Online: rejections snowballed.** The shot counter only moved on accepted shots, so three rejections in a row put every later shot "ahead" until a resync. The counter is now used up once the shot passes the counter check, accepted or not.

### What to test (owner)
1. Lobby Studio: Play. You spawn in the LobbyV5 hub.
2. Walk into the range hologram: first person, your guns, P for the gun picker, shoot the training bots (they come back). Walk out through the exit gate: your avatar, lobby UI.
3. Studio **Test → 2 players**: both step on one 1v1 pad, one per half. The halves light blue and red and count down, then you fight on a map in the same server. At the end you're back in the lobby.
4. Published place, two accounts in **different servers**: PLAY → 1v1 on both. You should land in the same private match server, then come back to a public lobby.

### Arena placement and range return (2026-11-22)

- Merged map templates still carried edit staging positions as far out as Z = 54,000. The duel loader added another 20,000 studs along X per slot. `MatchHost` now assigns absolute slots and `MapService` moves the map pivot there with its authored rotation. The first arena is 800 studs above the origin to clear the Lobby and range. Additional duels fill a horizontal grid in 6,600-stud steps. Studio bounds checks confirmed that all 12 installed release templates fit a slot.
- Pad-duel lighting uses the map's authored properties and effects on its player's client. The lobby's original Lighting instances are restored when the player leaves the duel. The lobby menu keeps its effect references. [Lighting Technologies and Settings](../LihFolk/07%20Lighting%20VFX%20and%20Audio/Lighting%20Technologies%20and%20Settings.md)
- Returning from a duel clears the combat lock, drafted Mods and weapons before the player respawns. The range client requests the server's current weapon snapshot after attaching its listener. The client host clears named render bindings and selection, restores lobby controls, and binds touch controls to the new screen on entry. Compact HUDs respond when the touch overlay toggles, so ammo and ability panels return for controller or keyboard input.
- Merged Lobby Studio solo 1v1 on Foundry4, with the phone HUD forced. The map loaded at (0, 800, 0) with its 00:30 night preset. A completed five-round duel restored the lobby's 14.6 ClockTime and the same lobby menu blur instance. The range armed the player without drafted Mods and showed unlimited reserve. Firing through the shared input action changed server ammo from 25 to 23 and the phone HUD to `23/∞`. Switching the touch overlay off and back on restored and hid the compact ammo panel. The controller's ButtonY binding remained and its cycle action switched Vandal to Classic.
- Studio whole-server Match role loaded CanyonOutpost at (0, 800, 0), with the authored 14.2 ClockTime, bloom and atmosphere on the client. During a stationary live sample, maximum camera-relative frame displacement was under 0.001 stud for both the gun handle and right arm. A separate range exit check cleared UI focus and restored native controls. Hardware gamepad and published server checks are pending.

### Known gaps / next
- Lighting for pad duels is per player; the lobby lighting comes back when you leave. Whole-server matches use `Config/MatchLighting` (the old match place's values).
- Callbacks into shared services from ended duels stay registered (they go quiet through `Context.alive`). That's a small leak per duel.
- Mod walls and Mod entities sit in shared folders. The duel return path clears the departing player's objects and timers before respawn.
- Players watching a pad duel, and requeueing from the pad (Play Again), aren't built.
- `MatchLift` (the lift plate on match found) no longer triggers, because pads don't search the global queue any more.
- Phone players have no sprint / slide buttons in the lobby (they live in the match HUD).
- Several duels at once share the Mods' server hooks (e.g. Updraft's and Roller's Heartbeat loops register once per duel). Fine for a handful of duels; worth a look before big servers.
- Studio-only test switches (`PadDuelSolo`, `LockMap`, `ServerRole`, `BotMatch`) were cleared from the place at wrap-up (Lobby place saved v947); set them again on Workspace to test in Studio.

### Weapon skin migration audit (2026-11-21)

The merged place contains all 225 legacy weapon skin models plus Slipframe Arc. An Edit-mode comparison matched mesh and texture asset IDs, named motor connections and attachment hierarchies for all 225 models and the Shadow Mist cartridge. All 226 models resolved through the merged Locker and match preview with current modules.

The copied Ruin-Blighted models and their effect descendants retained the legacy `GGAsset_MatchSkins_*` tags. The merged place now loads that defaults table alongside `LobbySkins`, restoring the six variants' ready flags, versions, moving joints and effect tuning. All six first-person controllers initialized on fresh clones. The matching audio banks loaded 60 distinct clips. The owned-skin route recognizes Ruin-Blighted and Tempest-Strike. Their Exclusive tiers and case exclusions are unchanged.

Merged place 71551303511506 saved in Team Create as v954. Verification used Edit mode. Published release verification remains separate. [Slipframe integration and checks](../02%20Art/Skins/Slipframe/Rework%20Ledger.md#arc-in-the-merged-place)

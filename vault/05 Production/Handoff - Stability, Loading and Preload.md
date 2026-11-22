# Handoff - Stability, Loading and Preload (2026-11-22)

**Goal:** the whole game loads fast and never breaks: joining, teleporting into a match, the map vote and round start always work, nothing pops in white or untextured, and a new branded loading screen (with sound) covers the loading while the assets the game needs are preloaded. Owner tests on phone and PC after each phase.

## Work rules (mandatory)
- Load the `gauntlet-vault` skill and follow [CLAUDE.md](../../CLAUDE.md): vault first, lean reads (grep, then line ranges; never whole big files), plans and results in the vault. Look up LihFolk first (`lihfolk-lookup`, specialists `roblox-debugging`, `roblox-performance-audit`, `roblox-ui-builder`, `lihfolk-sfx`). Loading-screen look: `gauntlet-ui-style` + [Style Bible](../02%20Art/Style%20Bible.md). RIVALS study: `rivals-reference` skill (study, don't copy; the RIVALS file is read-only).
- Strict Luau, numbers in `src/shared/Config`, no UI built from code (Studio-built screens; the loading screen lives where ReplicatedFirst can show it), stage exact paths only, commit on main, remind the owner to save the place.
- Studio MCP on the **Lobby place** (one place since 2026-11-21). `execute_luau` has its own require cache: read live state from instances, never by requiring game modules (memory: MCP require breaks remotes). Real teleports need a publish: say what couldn't be tested.
- Work in phases below; write the plan section in this note first, results at the end of each phase.

## Owner's reports (2026-11-22)
1. Body part skins sometimes don't load (limbs missing or default).
2. The whole game sometimes doesn't load or breaks when joining, and when teleporting into a match.
3. Getting stuck on the map select (vote never finishes).
4. A match starting before every player has loaded in.
5. UI images and skin models go white / glitch for a moment the first time they're shown (Locker, Shop, previews).
6. Wants a new loading screen at the start of a lobby game (and wherever loading happens) with the Draft Duels logo, RIVALS-like, with a good loading sound.

## Phase 1: reproduce and fix the game-breakers
Find the real cause of each report with logs and timings before changing code (`roblox-debugging`: reproduce, isolate, bisect, verify). Likely places to start (check, don't assume):
- **Join / teleport:** `src/first/LoadingScreen.client.luau` (takes the lobby's teleport gui), `src/lobby/server/Matchmaking/Launcher.luau` (TeleportService), `src/lobby/client/Controllers/MatchFoundController.luau`, `src/server/Services/MatchHost.luau`, `src/server/MatchKit/MatchRunner.server.luau`, the client host/runner bootstrap in `src/client/init.client.luau` (`ServerRole`, `PlayZone`). Look for WaitForChild timeouts, races between PlayerAdded and character / data load, StreamingEnabled lookups cached on streamed models.
- **Stuck map vote / start without players:** `MapVoteController` (client), the server vote and round start in `MatchHost` / `MapService` / `MatchKit`. The match should wait for every expected player (teleport data roster) to be ready (character + `DataReady` + client "ControllersReady"), with a timeout that drops no-shows cleanly instead of hanging.
- **Body skins not loading:** `src/client/Controllers/BodySkinController.luau`, `src/shared/MatchBody.luau` (limbs in `Workspace.GGBodyLimbs`), `Config/Avatar`. Check asset load failures, retries, and characters that stream in late.
- Add a short **health log** (Studio + live): one line per stage (joined, data ready, character, controllers ready, map loaded, round start) with timings, so the next report can be traced.

## Phase 2: loading screen v2
- Study RIVALS' loading / intro first (layout, timing, logo motion, how long it holds, skip rules) and capture only what's needed.
- Art: the approved [Draft Duels Logo](../02%20Art/Draft%20Duels%20Logo.md) (Draft Ticket in Lobby Gold; layered sprites and the two-beat reveal in `art-source/ui/draft-duels/draft-ticket-lobby-gold/`). Studio-built screen, Soft Edge theme, phone + PC + console layouts.
- Shows at the start of a lobby server join and on every teleport into a match (replacing the current `LobbyLoading` teleport gui), with a progress line (real stages from phase 1, not a fake bar) and tips.
- **Sound:** a short branded loading sting + quiet bed; audition 3-5 licensed options with the owner first (memories: designed, not synth; few, auditioned UI sounds). Routed through Settings MUSIC / MASTER (`Shared/SettingsApply` groups).
- Ask the owner: hold time vs skip button, music bed or sting only, show on every teleport or only the first join.

## Phase 3: preload
- One preload manifest in `Config` (UI images, item portraits / renders, skin meshes and textures for the player's equipped loadout, gun meshes, VFX textures, core sounds), loaded with `ContentProvider:PreloadAsync` behind the loading screen, in priority order (what the first screen needs first), with a time cap so a bad asset never blocks the join.
- Existing preloads to fold in: `AudioController.preload`, `EffectsController`, `HitFx`, `WinCutscene`, `UiSfx.preload`, `Simulation/Poses`.
- Fix the white flashes at their source too: Locker / Shop / previews should load their images and models before showing them (or show a placeholder plate, never white), and new skins preload when equipped or hovered.
- Measure before / after (time to playable on phone and PC, memory), per `roblox-performance-audit`.

## Phase 4: optimization pass
- MicroProfiler and memory on a phone-class device in the lobby, a pad duel and a match; fix the biggest costs first (scripts per frame, render, network, memory growth across rounds). Use the measured-check skills where they fit (`rbx-frame-time-regression`, `rbx-instance-retention-audit`, `rbx-asset-access-matrix` for assets that fail for normal players).

## Done when
- Reports 1-5 can't be reproduced (with the steps written down), the health log shows every stage, the new loading screen + sound is approved by the owner, first-time UI / skins don't flash, and the results and remaining risks are in this note, `00 Home.md` Status and `Bugs & Ideas.md`.

---

## Phase 1 plan and findings (2026-11-22)
Reproduced in a Studio playtest on the Lobby place (solo pad duel, `PadDuelSolo`), reading live instances only (`Player.GauntletState`, `ReplicatedStorage.Matches[id]` StringValues, character parts).

| # | Report | Real cause (measured) | Fix |
|---|---|---|---|
| 4 | Match starts before everyone loaded | The ready flag `MatchVoteReady` is a plain `true` on the player and nothing ever clears it. 1st pad duel: Waiting → Vote 0.3 s after the zone change (client really ready). **2nd pad duel: Vote 0.03 s after the zone change, no Waiting phase at all**: the old flag counted the player as loaded before their new match client existed. Same for every later duel and for both players of a 1v1. Reserved match servers also start without a seat that's still teleporting after `JOIN_GRACE` (20 s; a phone teleport can take longer). | The flag carries the match id (`Context.id`); readiness counts only this match's token, the client signals until it sees its own id. `JOIN_GRACE` 20 → 40 s. A player who is here but never signals (a client that broke) stops blocking after `READY_TIMEOUT` (Config/Bots). |
| 3 | Stuck on the map select | Server: the vote itself has a fixed deadline, but `MatchService.loop` stops for good on any error (an error in the match is caught and the loop **returns**; an error in `pickMap` / `MapService.load` kills the thread). Phase stays `"Vote"` with `VoteChosen` set, so every client keeps the vote screen and nobody is sent back. A present client that never sends MatchReady also held the Waiting screen forever (`ready == present` had no timeout). | Map pick and load guarded; on a match error a pad duel sends its players home (Context.finish) and a match server sends everyone back to the lobby, with a health-log line. READY_TIMEOUT above. |
| 1 | Body skins missing / default | Measured: when one body-part asset doesn't load, `ApplyDescription` **succeeds silently**, that limb comes back as Roblox's default unskinned parts (MeshId 7430071044, `HasSkinnedMesh` false) and the applied description reads 0 for that slot. Nothing checked for it. | `MatchBody.missingParts` checks the S15 slots after every spawn; CharacterService re-applies the description (2 more tries, backoff) and logs it. |
| 2 | Join / teleport breaks | Lobby: `CharacterService.spawn` gives up after 3 tries → no character ever (CharacterAutoLoads is off). Teleport code itself (Launcher, MatchEndService) already retries; the hangs after arrival are reports 3/4. Real teleports can't be run in Studio. | Spawn retries 3 → 5 with backoff and a health line; health log on every stage so a live report can be traced. |

**Health log** (`Shared/HealthLog`): one line per stage, `[Health] <stage> <player> +<seconds since join>`, server and client, Studio and live (server lines show in the F9 console, Server tab). Stages: joined, data ready, character (body ok / retried / failed), zone match, client ready, waiting, vote, map loaded, round start, match error.

LihFolk used: `roblox-debugging` method (reproduce, isolate, verify); notes cited in results below.

## Phase 1 results (2026-11-22)
**Changed** (strict Luau, numbers in Config):
- `Shared/HealthLog` (new): the stage log. Example from the Studio run: `[Health] S match zone … +33.0s 4fe0f793` → `waiting 0/1 ready` → `client ready … 0.3s after the zone` → `players in` → `vote open` → `vote done Rooftops4` → `map loaded` → `character … body ok` → `round start … alive 1 v 1`. Problems print as warnings (`body parts missing`, `spawn failed`, `map load failed`, `match error`).
- `Bots/MatchPlan` + `MapVoteController`: the ready token is the match id (`MatchVoteReady = Context.id`, `"server"` for a match server); the client signals until it sees its own id, and not at all in the range (it used to fire every 0.5 s there forever). `Config/Bots`: `JOIN_GRACE` 20 → 45 s (LihFolk *Parties and Group Teleports* uses 45 s from the first arrival), new `READY_TIMEOUT` 30 s (Studio 15 s) for a seat that's here but whose client never signals.
- `MatchService`: map pick and load can't kill the loop (a broken vote plays the loaded map); a match error sends a pad duel's players home (`Context.finish`) or teleports a match server's players to the lobby (`MatchEndService.sendEveryoneHome`, with the usual resend) instead of freezing everyone on the vote.
- `MatchBody.missingParts` + `CharacterService`: every spawn checks the skinned-body parts; missing ones re-apply the body after 1 s and 3 s (`Config/Avatar.BODY_RETRY`), then log `body parts failed`. Bot stand-ins with a missing part are thrown away (`Bots/Identity`). Lobby spawn tries 3 → 5 with backoff (`Config/Avatar.SPAWN_RETRY`).

**Verified in Studio (Lobby place, MCP, live instance reads):**
- Two pad duels in a row (solo + bot): before, the 2nd vote opened 0.03 s after the zone change with no Waiting phase; after, both duels wait for the real client signal (0.27 s) and log it.
- Body check: forcing bad ids on LeftArm and RightLeg made `missingParts` report `LeftArm,RightLeg`; re-applying the standard body cleared it.
- Match-server role (`ServerRole=Match`): token `server`, vote, map load, body ok, round runs.
- `selene` 0/0, `stylua`, `rojo build` clean.

**Not tested (needs a publish or two people):** real teleports into a match and back, two real players on one pad, a real asset failure in the wild, the READY_TIMEOUT and match-error paths (no way to break a client or a match on purpose without test hooks). After the owner's phone + PC test, any failure should show up as a `[Health]` warning: send the F9 Server lines.

**Owner test steps:** 1) Join the lobby on phone, play two pad duels in a row with a friend: the second one should wait on the loading/vote screen until both are in. 2) Queue a real match (PLAY) on both devices: nobody should be left behind, the vote should end and the draft open. 3) Look at limbs after spawns; a missing limb should fix itself within ~4 s (and log it).

**Phase 2 decisions (owner, 2026-11-22):**
- **Hold:** short hold, no skip button. The logo's two-beat reveal plays (about 2 s minimum), then the screen fades the moment loading is done.
- **Sound:** a branded sting on the logo plus a quiet music bed under the progress line, both on Settings MUSIC / MASTER; audition 3-5 licensed options with the owner first.
- **Where:** the first lobby join and every teleport into a match and back; pad duels get a short version.

## Phase 2 plan (2026-11-22)
Study: [RIVALS loading screen](../03%20Research/Rivals%20Reference/Loading%20Screen.md). Look: `gauntlet-ui-style` (dark plates `10141B` / fades `06080C`, one gold thing, circles with rings, Rubik `UiStyle.FONT`, Quint motion), [Draft Duels Logo → Title motion](../02%20Art/Draft%20Duels%20Logo.md#title-motion).

- **Screen:** `ReplicatedFirst.DuelsLoading` (Studio-built ScreenGui, a sibling of the Rojo-owned `Loading` folder so Rojo leaves it alone). Dark gradient backdrop with a soft vignette; the logo centred (1000 / 410 container, the `ui/` sprites as separate ImageLabels for the two-beat reveal); under it a thin progress track with one gold fill and a stage word (real stages); a small ring spinner; bottom: TIP line from `Config/Loading`; top: the mode line on a teleport (1V1 · LOADING MATCH). Layouts checked at 1920×1080, 844×390 and 667×375; TV-safe margin on console.
- **Script:** `src/first/LoadingScreen.client.luau` shows it on every join (lobby and match server), plays the reveal (0-500 ms beats), holds at least `MIN_HOLD` (about 2 s, owner: no skip), and closes (fade + blur out, Quint) when the stages are done: Lobby = game loaded → data → character → lobby client ready; Match = game loaded → data → match screens ready → waiting X/Y → Phase leaves Waiting. 30 s watchdog closes it whatever happens (LihFolk *Streaming Joins - Frozen Players and Loading Screen Teardown*: 25 s). Clients flag "ready" with local Player attributes the script reads (no remotes).
- **Teleports:** `MatchFoundController` hands Roblox a copy of `DuelsLoading` (SetTeleportGui) instead of `LobbyLoading`; the arriving script takes it over so there's no flash between. Match end → lobby does the same.
- **Pad duels:** a short version (logo + "LOADING DUEL", until the vote screen is up or 3 s) from a lobby controller on the PlayZone change.
- **Sound:** a sting on the lock-in beat (~210 ms) and a quiet looped bed under the progress, both in `SoundService.SettingsMusic` (Settings MUSIC × MASTER). 3-5 licensed Creator Store options auditioned by the owner first; ids go in `Config/Loading`.
- Words and numbers in `Config/Loading`.

## Phase 2 results (2026-11-22, first build; waiting on the owner's sound pick and look)
**Built:**
- `ReplicatedFirst.DuelsLoading` (Studio, saved with the place; rebuild script `tools/studio/BuildDuelsLoading.luau`): dark navy-to-black backdrop, one soft brand slash, the Draft Duels title as two sprites (DRAFT ticket, DUELS) plus a full sprite for reduced motion, one gold progress fill on a thin track, the stage word and a player count, a ring spinner (rotating stroke gradient), a tip line, a mode line for teleports. Logo images uploaded (decals 109503101136989 / 88104206748404 / 101115191066295; image ids 132974051905154 / 76082588029379 / 92494712417530, also ticket-plate 136453363569244, draft-letters 128499720756848).
- `src/first/LoadingScreen.client.luau` rewritten: shows on every join (lobby and match server) or takes over the teleport copy; waits (≤ 3 s) for the logo and `Config/Loading`, then the two-beat reveal (DRAFT 0-230 ms from the upper left, sting at 210 ms, DUELS rising from 215 ms with a 2.5% punch) under a fading-in bed; real stages; min hold 2.2 s; fade + blur clear; watchdog 30 s lobby / 120 s match. Match servers also hand the screen to the teleport back to the lobby (Phase `MatchEnd`).
- `src/first/LoadingLayout.luau`: fits a copy to a screen; phones in landscape get the canvas 1.3× and the rows pulled closer (`Config/Loading.phoneY`) so tip text stays ≥ 12 px and on screen at 667 × 375.
- `DuelLoadingController` (lobby): the short pad-duel version (title, LOADING DUEL, spinner), gone once the duel's match screens are up (0.6 s min, 4 s max).
- `MatchFoundController` hands the new screen (mode line, tip, fitted) to `SetTeleportGui` instead of `LobbyLoading`. `LobbyMusic` waits until the loading screen has gone. Local "ready" attributes: `LobbyClientReady` (lobby client), `MatchScreensReady` (MapVoteController), `LoadingScreen` (this screen).

**Verified in Studio:** lobby join: the screen ran its stages and closed at +3.7 s, lobby music came in after; match-server role: held on WAITING FOR PLAYERS, closed when the vote opened, bed faded; pad duel: the short version closed by itself and the draft came up with no overlay left; layout captures at the editor's PC size and in an 844 × 390 phone window. Found and fixed on the way: `GetAttributeChangedSignal("ServerRole"):Wait()` never returns when the attribute arrives with ReplicatedStorage's first snapshot (the screen hung on CONNECTING), now polled.

**Not tested:** the teleport takeover (needs a publish), console TV-safe check on a real TV, hearing the sting on the beat (the MCP can't listen).

**Sound audition (owner):** `ServerStorage.LoadingAudition` in the Lobby place has 9 licensed APMOfficial options; select one and press Play in its Properties (or the sound preview). Stings: 1 Outrunning - Hit (9047207931, current pick), 2 Totally Go For It - Hit4 (9038919815), 3 Omega - Hit (1848298868), 4 Mech Madness Stinger 1 (127087932061391), 5 Victory Slam stinger 1 (9042702890). Beds: 1 Beginnings (9042293789, current pick), 2 Round About Now, no percussion (9042294497), 3 Ambient Electronica (1839824120), 4 Spirit Warmth (9042295159). The pick goes in `Config/Loading.sting` / `.bed`; delete the folder afterwards.

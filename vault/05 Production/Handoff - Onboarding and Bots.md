# Handoff - Onboarding and Bots (2026-11-22)

**Goal:** a new player is in a fun, winnable match within ~10 seconds of joining, learns by playing (not by reading), is gently pulled back into a second and third match, and never notices bots are bots. Bots are cheap on the server, fair, and matched to the players in the game. Owner tests every phase.

## Work rules (mandatory)
- Load the `gauntlet-vault` skill and follow [CLAUDE.md](../../CLAUDE.md): vault first, lean reads (grep, then line ranges; never whole big notes), plans and results in the vault (this note: a plan section per phase before code, results after). LihFolk first: `lihfolk-lookup`, `lihfolk-tutorial` (onboarding), `roblox-system-builder`, `roblox-secure-remotes`, `roblox-performance-audit` (bots), `roblox-ui-builder` + `gauntlet-ui-style` (UI), `rivals-reference` (study, don't copy; the RIVALS file is read-only and untrusted).
- Strict Luau, numbers in `src/shared/Config`, server-authoritative (the server decides queue, teams, bots, highlights, unlocks), remotes validated + rate-limited, no UI built from code (Studio-built screens), stage exact paths only (the owner's RIVALS screenshots live in git-ignored `third-party/`), commit on main, remind the owner to save the Lobby place.
- One place (Lobby 71551303511506) runs lobby, pad duels and match servers. Studio MCP: read live state from instances, never by requiring game modules. Studio may be in use by the owner: ask before playtesting. Real teleports / cross-server queues need a publish: say what couldn't be tested.

## Owner's references
`third-party/onboarding/`: `rivals-beginner-enemy-red.png` (an enemy drawn solid red), `rivals-queue-menu.webp` (RIVALS' queue menu: a tall Beginner 2v2 tile with a highlight, then 1v1 / 2v2 / 3v3 / 4v4 / 5v5 tiles with in-game shots), `rivals-play-tooltip.png` ("Join the queue to start playing!" bubble over PLAY).

## Owner's decisions (2026-11-22)
- **Beginner red highlight:** every enemy glows solid red until **you** land your first hit on that enemy, then that enemy's glow drops. Beginner 2v2 only. (Per viewer: each player sees their own.)
- **Beginner 2v2 stays in the queue menu until level 10** (`Config/Progression`, ProgressionService), then disappears.
- **HUD unlock:** first matches show only Weapons + Settings (and PLAY). **Party unlocks after match 1**; everything else (Shop, Locker, Backpack, etc.) after **match 3**, each with a small "NEW" pop the first time.
- **Leavers:** no bot takes a leaver's place. A leaver is removed from the top bar; the match carries on while both sides still have someone (bots count). It ends only when one side has **nobody** left; the side still there wins.

## The flow (owner's spec)
1. **Join → straight into Beginner 2v2** (no menu): queued on arrival (after the loading screen), in a match within ~10 s, real beginners first, bots fill the rest.
2. **Match:** a normal match, plus the red highlight above and light ability hints (simple, good-looking, never in the way; e.g. a one-line hint the first time a Mod is ready / drafted). Ask the owner before adding more.
3. **Back in the lobby:** ask to favorite the game (`AvatarEditorService:PromptSetFavorite`, once, after match 1). A bouncing notification over PLAY ("Join the queue to start playing!", RIVALS tooltip) stays until they queue.
4. **PLAY while new:** goes straight into the Beginner 2v2 queue (no menu); ask to favorite again during that second match if they declined.
5. **After match 2:** PLAY opens the normal queue menu; the PLAY notification still shows when idle.
6. **Queue menu:** Beginner 2v2 tile slightly highlighted, shown until level 10.
- State per player (matches played, favorite asked, HUD unlocks) saved in `PlayerDataV1` (see the progression note for how its fields migrate) and published to the client.

## Bots redesign
- **No-bots illusion:** remove every "bots join in X s" text / countdown; bots look and behave like players (names, avatars, levels, device marks, top bar, kill feed).
- **Dynamic difficulty:** pick each bot's profile (`Config/Bots PROFILES`) from the real players in the match: their level, recent results and device (phone players get easier bots). Multi-player queues: average the players' levels. Beginner 2v2: bots that a new player can beat (a first-match win is likely but not free), tuned by playtest.
- **Performance:** measure first (`StepMsAvg` / `StepMsMax` / `BotCount` on `ServerStorage.BotOwners`, MicroProfiler `BotThink` / `BotAct`, budget `Config/Bots.BUDGET_MS`), then fix the biggest cost; must hold with 3 bots on a phone-class server load.
- **Fill timing:** 10 s for Beginner 2v2 (real beginners first), the existing `botFillAfter` for others (Lobby `Config`, `QueueService`, `GlobalQueue` `fillAfter`, `Matchmaker.pick`).

## Where to start (check, don't assume)
- Queue + matchmaking: `src/lobby/shared/Config.luau` (modes, `botFillAfter`), `src/lobby/server/Services/QueueService.luau`, `src/lobby/server/Matchmaking/` (`GlobalQueue`, `Matchmaker`, `Launcher`, `Parties`), `src/lobby/client/Controllers/PlayMenuController.luau`, `src/lobby/client/Util/QueueState.luau`, `LobbyHudView` (PLAY, bottom bar).
- Match + bots: `src/server/Services/MatchService.luau` (seats, bot fill, waiting, results), `src/server/Bots/` (`MatchPlan`, `Brain`, `Perception`, `Aim`, `Tactics`, `Nav`, `Identity`), `src/shared/Config/Bots.luau`; design notes [Bots](../01%20Design/Bots.md) and [Bot Redesign 2026-11-17](Bot%20Redesign%202026-11-17.md).
- Progression: `src/shared/Config/Progression.luau`, `src/lobby/server/Services/ProgressionService.luau`, [Progression](../01%20Design/Progression.md).
- Highlights: `client/Util/HitFx` (hit flash Highlights, budget), `Util/TeamColor`; queue UI: [Lobby UI and Queue](../01%20Design/Lobby%20UI%20and%20Queue.md).
- Stability work this builds on: [Handoff - Stability, Loading and Preload](Handoff%20-%20Stability%2C%20Loading%20and%20Preload.md) (ready tokens, `[Health]` log).

## Phases
1. **Plan** (this note) + LihFolk onboarding research + a RIVALS study of its first-time flow and queue menu.
2. **Onboarding flow** (auto-queue, Beginner 2v2 mode, PLAY shortcut, notifications, favorite prompts, HUD unlocks, saved state).
3. **In-match beginner help** (red highlight per enemy, ability hints).
4. **Bots:** illusion, dynamic difficulty, leaver rule, fill timing, performance.
5. **Queue menu art (can come later):** new tile images from our real maps, guns and bodies (Studio captures, not AI-looking), Beginner 2v2 tall and highlighted like the reference. Prompts for ChatGPT go in this note if image generation is used (memory: ChatGPT/Codex for images, owner pastes prompts). **Master prompt ready (2026-11-22):** [Queue Tile Art Master Prompt](../04%20Tech/Prompts/2026-11-22%20Queue%20Tile%20Art%20Master%20Prompt%20(ChatGPT).md) (six tiles into `art-source/ui/queue/new/`; then Claude wires them and fixes the crop size).

## Phase 1 results: research (2026-11-22)
**RIVALS (read-only study of the RIVALS file; study, don't copy):**
- Beginner 2v2 is a queue like any other (`DuelLibrary` `add_queue("2v2_beginner", …)`): sorted first, no lobby pad, **one map only** (Arena), 2 teams × **1 real player per team** (bots make up the 2v2), title "Beginner".
- Shown in the Play page while the player has **fewer than 10 duel wins** (`CONSTANTS.BEGINNER_QUEUE_WINS = 10`); when it hides, the Ranked tile takes its place. Ours: shown below level 10 (owner).
- Play page while **fewer than 3 duels played**: a simpler centred duels frame (no extras), its own close button.
- PLAY bubble "Join the queue to start playing!" shows while **duels played ≤ 3** (same slot also says "Your free weapon trial is ready!").
- Red enemies (`ClientDuel.BeginnerDuel`): when the round starts (`RoundStarting` / `RoundStarted`), every fighter not on your team gets `SetRedFigureMode(true)`, only in the "Beginner" queue. (Phase 3: ours drops per enemy on your first hit, owner's rule.)
- Favorite prompt (`LobbyController._PromptStuff`): back in the lobby, 1 s after the duel ends, **once per session**, when duels played = 5 or on the first win; `PromptSetFavorite(placeId, Asset, true)`. Notifications opt-in later (8 played / 2nd win). They also pay a reward for favoriting (Rewards page). Ours: after match 1, again in match 2 if declined (owner).
**LihFolk** (`05 UI and UX/Onboarding and FTUE - Tutorials That Keep Players`, `Tutorial Step Design Patterns - Teach by Doing`, `HUD Design` §4, `58 Player QoL/Skippable Tutorials and Replayable Tips`, `37 Avatars and UGC/AvatarEditorService and In-Game Avatar Editors`, `04 Data and Persistence/Schema Migrations - Worked Case Studies`):
- Join → control in ~10 s, first reward under 60 s; never stack pop-ups on the first join.
- Show only the HUD buttons the step needs; every target must still have a visible route; "NEW" badges sparingly (red dot = "something useful to do now").
- Hints: one verb, ≤ 8 words, once each, retire when the player does it unaided.
- `PromptSetFavorite` doesn't yield: listen to `PromptSetFavoriteCompleted`; wrap `GetFavoriteAsync` in `pcall`. No vault note on favorite-prompt policy: keep it rare (owner's 2 asks max).
- New save fields: pure, total `clean()` with defaults; a failed read is not "new player"; store seen flags as a small bitset.
- Note: [Release Plan 2026-11-22](Release%20Plan%202026-11-22.md) said "2v2 beginner mode stays cut"; the owner's later decision in this note (Beginner 2v2 + auto-queue) wins.

## Phase 2 plan: onboarding flow
- **Numbers:** `src/shared/Config/Onboarding.luau` (auto-queue while matches = 0, PLAY shortcut while matches < 2, Party at 1, the rest at 3, bubble while matches < 4 like RIVALS' ≤ 3, Beginner shown below level 10, favorite asks max 2).
- **Beginner mode:** Lobby `Config.MODES` gets `beginner` (team size 2, tile `Beginner2v2`, `fillAfter` 10 s / Studio 5, `maxLevel` 10). `QueueService` + `GlobalQueue` use a per-mode fill time; the server refuses Beginner at level ≥ 10 (whole party). `Config/Bots.MODES.beginner = 2` so match servers accept the plan.
- **Saved state:** `PlayerData.onb = { fav = asks so far, favDone = bool, seen = bitset of NEW pops }` (no version bump, `clean()` defaults), published as `OnbFav`, `OnbFavDone`, `OnbSeen`. Matches played = existing `prog.matches` (`Matches`). New `OnboardingService` (lobby) handles one remote `OnboardingRequest` (`favAsked` with the prompt result, `seen` with a bit): types checked, rate-limited, only ever raises counters.
- **Client:** new `OnboardingController` (lobby): auto-queue Beginner after the loading screen (leader only, idle, matches = 0); favorite prompt 2 s into the lobby after match 1 (skipped if already favorited); PLAY bubble while idle; HUD gating (Locker = "Weapons" + Settings + PLAY first; Party at 1; Shop / Backpack at 3) with the existing `Callout` as the "NEW" pop until opened. PLAY goes straight to Beginner while matches < 2 (its sub-line says BEGINNER 2V2). Play menu: the Beginner tile goes live (was SOON) and gets a highlight while level < 10, hidden after.
- **Studio UI:** `tools/studio/BuildOnboardingUi.luau` adds `LobbyBar.Bottom.PlayBubble` (Studio-built, from the Callout style); run when Studio is free. Code skips the bubble if it isn't there.
- **Match side (second favorite ask):** in the match client during match 2 if declined (between rounds), sent through the same saved state.

## Phase 2 results: onboarding flow (2026-11-22, code only, not play-tested)
Built as planned above. Files:
- Rules and numbers: `src/shared/Onboarding.luau`, `src/shared/Config/Onboarding.luau`.
- Save: `PlayerData.onb` (+ `PlayerDataService` writes it), published `OnbFav` / `OnbFavDone` / `OnbSeen`.
- Server: `src/lobby/server/Services/OnboardingService.luau` (remote `OnboardingRequest`, also runs on match servers), `QueueService` (Beginner mode, per-mode fill, level cap for the whole party, Play Again from a Beginner match falls back to 2v2 at level 10), `GlobalQueue` (per-mode fill), Lobby `Config` (`beginner` mode, `MODE_BY_TILE`), `Config/Bots.MODES.beginner = 2`.
- Client: `src/lobby/client/Controllers/OnboardingController.luau`; hooks in `Util/LobbyHudView` (`setPlay`, `setUnlocked`, `callout` over Party too, `bubble`); `PlayMenuController` (Beginner tile live, brighter, gold sub-line, hidden at level 10); `QueueState.label` ("BEGINNER 2V2" / "2V2" in the bar and the teleport screen); `src/shared/FavoritePrompt.luau`; match side `src/client/Controllers/FavoriteAskController.luau`.
- Studio UI: `tools/studio/BuildOnboardingUi.luau` (adds `LobbyBar.Bottom.PlayBubble` from the Callout, white plate + ink words, and a `Pop` UIScale on the Callout). **Not run yet** (Studio was in use); until it runs the bubble just doesn't show.
- Checks: StyLua, selene (one old error in untouched `PlayMenuController` code: `Content`), `rojo build` OK. No Luau type checker is installed, so strict types were checked by eye and by a review agent.
- Security review (roblox-reviewer): no critical or high issues; the level cap can't be bypassed and the save can't be corrupted. Fixed from it: `OnboardingService` checks the cached save before any write (no free DataStore calls), the auto-queue re-reads Matches before queuing, mode names may be up to 16 characters. Left: `LobbyHudView` still waits for `Bottom.Callout` with no timeout (it has always been there).

**Studio test (2026-11-22, after the owner freed Studio).** `BuildOnboardingUi.luau` run (bubble 340 × 46, from the Callout); the Studio save was at 1 match, and other match counts were faked by setting the server's published values (the save itself untouched except below). Passed:
- 1 match: bar shows only Locker + Settings (+ PLAY, Party row); white bubble with pointer over PLAY; PLAY's line BEGINNER 2V2; NEW tag over the party circle. The lobby favorite ask fired and was counted (`OnbFav` 0 → 1).
- Clicking PLAY: straight into the Beginner queue (no menu), bubble hides, bar says 2V2 / BEGINNER 2V2; bots filled after 5 s (Studio), match found with mode `beginner` in the match contract ("would teleport" in Studio).
- 3 matches: Shop + Backpack back, PLAY opens the menu, the Beginner tile is live (SOON gone, gold line). Opening the Party card saved `OnbSeen` = 1 and the NEW moved to Shop.
- Level 10: the Beginner tile hides and the server answers "BEGINNER 2V2 is for players below level 10".
- Fixed from the captures: the NEW tag was the Callout's full 250 px bar sitting across PLAY → now a short tag sized to its word, above the party circle; the bubble was narrowed from 430 to 340 px.
Not tested: the auto-queue on a truly new save (the Studio save already has 1 match), the second favorite ask in match 2 (needs a match server), whether the favorite prompt itself shows in Studio, real teleports.

**Owner: what to test** (Studio test key with a fresh save, or a published test):
1. Join with 0 matches: after the loading screen you're searching **BEGINNER 2V2** (bar circle says 2V2) without touching anything; bots fill after 10 s (5 s in Studio).
2. First lobby: only PLAY, Locker and Settings on the bar; no Party row.
3. Back after match 1: favorite prompt about 2.5 s in; Party row back with a red **NEW** over it until you open the Party card; the white bubble bobs over PLAY; PLAY's sub-line says BEGINNER 2V2 and clicking it queues straight away.
4. Decline the favorite → during match 2, at the first round break, it asks again (once). Favorite → never again.
5. After match 2: PLAY opens the menu; the tall Beginner tile is bright with a gold line and queues Beginner 2v2.
6. After match 3: Shop and Backpack come back, NEW over Shop then Backpack until each is opened. The bubble stops once 4 matches are played (RIVALS: after 3).
7. Level 10: the Beginner tile is gone and the server refuses Beginner (also for a party with any level-10 member).

**Not tested:** everything above in play (Studio was busy); real teleports and the global queue (need a publish); `GetFavoriteAsync` / `PromptSetFavorite` behaviour in Studio (may not show there).

## Queue tile art + owner fixes (2026-11-22, evening)
- **Queue tiles in:** the six ChatGPT pictures (`art-source/ui/queue/new/`, resized to 1024 in `art-source/ui/queue/upload/`) uploaded and set on the Studio `PlayMenu` tiles. Gotcha: Open Cloud returns a **Decal** id; the tiles need the decal's **image** id (Studio `InsertService:LoadAsset(decalId)` → `Decal.Texture`). Image ids are in `tools/studio/BuildLobbyMenus.luau` `ART`. `PlayMenuController.ART_SIZE` holds each picture's real size (EditableImage can't read it live), so the crop is right. Studio-checked.
- **PLAY shadow:** `LobbyBar.Bottom.PlayShadow` now fades out with PLAY while queued and back when idle (`LobbyHudView.refresh`). Studio-checked.
- **Join void / slow load:** the lobby loading stage now asks Roblox to stream the area around the fighter (`RequestStreamAroundAsync`) and waits for floor under its feet, at most `Config/Loading.streamWait` (8 s), before the screen opens; a warning `[Health] C loading: no floor under the spawn` if it gives up. Studio loads locally, so the live effect is untested. If it's still slow live: F9 → Client, the `[Health] C` lines say which stage waited.
- **Player data reset:** saves moved to fresh stores `PlayerDataV2` / `PlayerDataV2_Studio` and `LockerV2` (`Shared/PlayerData.STORE`, `Shared/Locker.STORE`). The V1 stores are untouched: switching the names back restores everyone. Anyone who bought with Robux on V1 loses those items in V2 (Roblox won't re-deliver a granted receipt).
- **Admin panel → MATCH BOTS tab** (owner's panel, `AdminPanelController` / `AdminService`): per bot and for all bots, difficulty Easy / Normal / Hard / **Insane / Ultra** (new profiles in `Config/Bots`, admin-only, not used by matchmaking) and level (type a level, or +1…+500 for all). Applies live: `BotService` watches `AdminDifficulty` / `AdminLevel` on each bot's owner; "all bots" also sets the default for bots made later (Workspace `AdminBotDifficulty`). Studio-checked in a 2v2 bot match (one bot to Ultra + level 999, all to Insane, a bad name refused).

## Live join: stuck on LOADING YOUR DATA (2026-11-22, late)
Owner: live lobby and a live Beginner 2v2 both sat on "LOADING YOUR DATA" a long time; the match started without him; then a void.
- Facts: in a match the server only starts once the client's `MatchReady` arrived, so his client was running; the loading screen was waiting for `DataReady`, i.e. **the save never finished loading on the live server** (Studio: ready in ~1.2 s, boot 0.06 s). Cause not proven: no live logs here (the Open Cloud key has no DataStore scope). Suspect: live DataStore read failing or throttled, retrying with 10 → 120 s pauses.
- Fixed: the data stage waits at most `Config/Loading.dataWait` (8 s), then opens (Shop and onboarding wait for the save themselves); failed save rounds retry after 3 → 30 s (was 10 → 120 s); the lobby server boot runs each require / init protected and logs `[Health] S lobby boot Xs (slow: ...)`; slow or failed save reads log `[Health] S save read ... took` / `save ... not loaded yet`.
- Join size (Studio place, **save the place**): the unused `ReplicatedStorage.LobbyRivals` (5,800 instances, no code uses it) moved to `ServerStorage.UnusedReplicated`; streaming min radius 64 → 128 (more of the spawn area arrives before you do), target 1024 → 512 (less far world streaming in after).
- Still big: `ReplicatedStorage.WeaponSkins` (21,600 instances) downloads on every join; loading skins on demand is the next real win (Locker and SkinPreview read it).
- Owner, after publishing: if it's slow again, F9 → **Server** tab, the lines starting `[Health] S` and `[PlayerData]`, and the **Client** tab `[Health] C` lines.

## Old lobbies and RIVALS pieces removed (2026-11-22, owner: "remove all Rivals assets and other old lobbies ... besides the textures")
- Deleted from the Lobby place (Studio; **save the place**, version history can bring them back): Workspace `Lobby`, `SunwellStaging`, `LobbyV4Staging`, `LobbyRivals`, `ShootingRangeRivals`, `NewQueueArea`, `Model`, 3 × `PathNew`; ServerStorage `UnusedReplicated` (the RIVALS lobby copy that sat in ReplicatedStorage), `RivalsPropTemplates`, Archive `Lobby_BeforeRebuild_20261104`, `StylizedHub_Scrapped_20261104`, `Hub_Bunker2_preV3`. About 44,000 instances. Kept: `LobbyV5`, `Texture Pack`, `Arrows` (spawn guide), every MaterialService texture.
- Checked first: no code path uses them (pads, shop, locker, queue, NPCs and gun displays are tagged inside LobbyV5; the old range entrance only, and the range is closed). Studio join after: spawn on the V5 hub, save ready 0.5 s, no new errors.
- Mesh owners (Open Cloud lookup of all 3,392 mesh ids in maps, LobbyV5, ReplicatedStorage, UI): 3,339 are our group's. The rest come from the RIVALS map kits (RIVALS' group 3461453 and its prop creators, group 16464852 and users 20349956 / 8034104): **Greenhouse4 375 parts, Foundry4 30, CanyonOutpost 36**, still in those maps; the `MapKit.*Rivals` kits are still in ServerStorage. Waiting on the owner: swap or remove them. (LobbyV5 has 18 old public catalog meshes; fine.)
- The red "Failed to load animation" lines in the owner's console are OUR animations (`Config/Animations`, group-owned like the game, approved): not a RIVALS permission issue. Likely asset-delivery throttling during the heavy join; recheck after this cleanup.

## Done when
A fresh account (Studio test key) goes join → Beginner 2v2 → lobby (favorite prompt, PLAY bubble) → second Beginner match → normal queue, with the HUD unlocking on schedule; bots feel like players and scale with who's in the match; leavers behave as decided; results, what the owner should test, and what wasn't tested are in this note, `00 Home.md` Status and `Bugs & Ideas.md`.

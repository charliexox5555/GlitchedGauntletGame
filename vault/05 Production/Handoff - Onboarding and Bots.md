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
5. **Queue menu art (can come later):** new tile images from our real maps, guns and bodies (Studio captures, not AI-looking), Beginner 2v2 tall and highlighted like the reference. Prompts for ChatGPT go in this note if image generation is used (memory: ChatGPT/Codex for images, owner pastes prompts).

## Done when
A fresh account (Studio test key) goes join → Beginner 2v2 → lobby (favorite prompt, PLAY bubble) → second Beginner match → normal queue, with the HUD unlocking on schedule; bots feel like players and scale with who's in the match; leavers behave as decided; results, what the owner should test, and what wasn't tested are in this note, `00 Home.md` Status and `Bugs & Ideas.md`.

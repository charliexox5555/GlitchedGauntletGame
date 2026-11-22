# Progression: levels, win streak, streak save

Status: **built and tested in Studio (2026-11-22).** The owner took every suggested answer below ("sounds good") and asked to make sure the player cards and profiles work too. Shop pricing for release is the next task, not this one; every coin number here lives in `src/shared/Config/Progression.luau` so that pass can retune it.

## What exists already
- The UI already reads player attributes that nothing sets yet: `Level`, `XpShare`, `WinStreak` (lobby player list and profile: `src/lobby/client/Util/LobbyHudView.luau`, `ProfileController.luau`; match tags: `src/client/Util/PlayerTags.luau` reads `Level`). Bots set a fake `Level` (`BotService`).
- Saves: `PlayerDataV1` (`PlayerDataV1_Studio` in Studio), one key per player, written only through `PlayerDataService.transact` (one atomic `UpdateAsync` per change, purchase ids in `tx`). `PlayerDataService` also runs on match servers (`src/lobby/server/init.server.luau` → `MATCH_SERVICES`).
- Coins are not earned anywhere yet (new players get 2,500; cases cost 400 and 900).
- The lobby bottom bar is Locker, Shop, Backpack, Range, Settings (`LobbyHudView.luau` ~953). Settings is also on the top bar (~804), so taking the bottom button away doesn't hide Settings.

## RIVALS reference (read from the RIVALS file's client scripts, study only)
- **One win streak**, `StatisticDuelsWinStreak`, shown on name tags, queue pads, the scoreboard and the winners screen. Some queues and every private server turn streaks off (`AreStreaksDisabled`, "streaks disabled" badge on the pad).
- **Lost streaks are stored** in a list `StoredStreaks`, each `{ Value, ExpirationTime, ConsecutiveRecoveries }`. While the list isn't empty a **Recover** button ("Recover your win streak") shows on the lobby bar. It opens the `StreakRecovery` page: one slot per stored streak with the streak number, a live countdown ("Expired" in red at 0) and a price button.
- **Price** = `clamp(5 × 2^ConsecutiveRecoveries, 1, 100)` of their premium key currency: 5, 10, 20, 40, 80, 100. Saving again and again gets dearer.
- Not enough currency → opens the Shop's currency page and the Robux bundle prompt. Enough → the title turns to "Are you sure?" for 3 s; the second click sends `RecoverStreak(index)`.
- **Level curve**: XP to the next level = `max(50, floor(5 + 4(L−1) + (min(L,99)/40)² × 100))`: flat 50 to about level 12, 106 at 20, 261 at 40, about 1,000 at 99, then flat. Their XP sources are server-side (not in the file).

## Decisions (owner took every suggested answer in bold, 2026-11-22)

### A. Leveling
1. **XP sources per match** (suggested, about 6-8 min per match, first to 5 rounds):
   - **Finish a match: 20** (no XP if you leave early)
   - **Win the match: +30**
   - **Each round your team wins: +4** (max 20)
   - **Each kill: +2** (max 20 per match); no XP for assists
   - So a typical win is about 85 XP, a loss about 40.
   - Other options: playtime XP (per minute in a match), daily first-win bonus (+50), XP for damage.
2. **Bot matches**: **bots-only opponents give half XP**; matches with at least one human opponent give full XP. (Or: full XP always; or none.)
3. **Pad duels in the lobby**: **count like queued matches** (or: no XP).
4. **Curve**: **ours, gentle and RIVALS-like: XP to next level = 100 + 20 × (L−1), flat at 1,000 from level 46, no max level.** Level 2 after about 2 matches, level 10 after about 25 matches (about 3 hours), level 50 after about 450 matches. Other options: exactly the RIVALS formula with smaller XP numbers; a steeper curve (100 × L^1.5) where high levels mean a lot more.
5. **Where it shows**: **lobby player list, profile, match top bar and Tab scoreboard (already wired to `Level`), an XP bar plus "+XP" lines on the match end screen, and a level-up pop.** Optional: level on the name billboard over players in the lobby.
6. **Rewards**: not now. **A `LEVEL_REWARDS` table in Config, empty**, so coins or skins per level slot in later.

### B. Win streak
7. **What counts**: **one streak across all modes (1v1, 2v2, 3v3 queue and pad duels), like RIVALS.** Or one streak per mode.
8. **Win with bots**: **a match only counts (win or loss) if at least one opponent is a real player.** Bot-only matches don't move the streak.
9. **Leaving a match early** = **a loss (breaks the streak).** A match that ends from a server problem changes nothing.
10. **Party queue** counts the same as solo (suggested **yes**).

### C. Streak save ("SAVE WINSTREAK")
11. **Smallest streak worth saving**: **3** (lose at 1-2 and nothing is offered).
12. **How long the offer lasts**: **15 minutes** of real time from the loss (keeps counting while offline). Options: 5 min, 1 hour, 24 hours.
13. **How many lost streaks are kept**: **only the latest one.** A new loss while one is stored replaces it (if bigger) and resets the timer. RIVALS keeps a list.
14. **What saving does**: **your streak becomes the saved number plus any wins since the loss** (so playing on while deciding never costs you).
15. **Price in coins** (kept in Config, retuned in the shop pass): **100 × 2^(saves in a row), max 1,600**: 100, 200, 400, 800, 1,600. "Saves in a row" goes back to 0 after a loss you don't save. Other option: price by streak size (for example 25 per win in the streak).
16. **Not enough coins**: **the popup says so and offers to open the Shop** (no auto Robux prompt).
17. **Confirm**: **one popup with the streak number, the timer and a BUY button with the price; the purchase is the click** (or RIVALS' "Are you sure?" second click).
18. **The button**: **while an offer is live, the bottom bar's Settings button becomes "SAVE WINSTREAK" with a small countdown, and goes back to Settings when it ends** (Settings stays on the top bar). Optional: also a SAVE STREAK button on the match end screen after a loss.
19. **Fair-play note**: LihFolk's "Ethical Design and Player Trust" lists a paid streak restore as a loss-aversion pattern. That is guidance, not a Roblox rule. Suggested: **keep it (RIVALS does it), with a true countdown, the price in plain view, no alarm sounds or flashing, and nothing random**, so the paid-random-items rules don't apply. Option: also give one free save per day for small streaks.
20. **Win trading** (two friends queuing into each other): **a win against the same opponent counts for the streak at most 3 times a day**, XP still counts. Or no limit for now.

## Data saving audit (`PlayerDataV1`)
Good already:
- Every change is one `UpdateAsync` that reads the stored value, so two servers can't overwrite each other. There is no cached copy saved on leave, so **session locking isn't needed** for this design. LihFolk ("Session Locking and Profile Libraries") requires a lease for the usual cached-profile design, where the whole profile is saved on leave. Ours never writes a stale copy. Keep it that way: no `SetAsync` on player keys, and no field written from a cached copy.
- Purchase ids (`tx`, last 25) make a retried write never charge twice; a failed write re-reads before saying "try again".
- A newer build's save (`v` higher) is never written by an older server; unknown items and **unknown top-level fields survive** (`table.clone(old)`), so adding fields needs no version bump.
- Retries with backoff (4 tries), load retries until it lands, `BindToClose` waits up to 25 s for writes in flight, Studio uses its own store.

Gaps to fix with this work:
1. **Writes for a player who already left fail** (`transact` needs the live record). A leaver's loss / streak break must still save → add a by-UserId write (like `writeSettings`).
2. **`busy` refuses** a second change while one is in flight. A match-end write must queue, not drop.
3. **Match results need their own id**: `match:<matchId>` in `tx`, so a retried or repeated match end never grants XP twice.
4. **Teleport race**: the match end write may still be in flight when the lobby loads the player with `GetAsync`. Load with the no-write `UpdateAsync` read (`readFresh`) instead, and write results as the match ends (before the teleport).
5. New fields in `clean()` with safe defaults and clamps: `xp`, `level`, `streak`, `bestStreak`, `lostStreak { value, expires, saves }`, `savesInRow`; `valid()` checks them.

## Build plan
1. `Config/Progression.luau` (XP numbers, curve, streak rules, save price and timer).
2. `PlayerData` fields + `PlayerDataService` fixes (gaps 1-5).
3. `ProgressionService` on match servers and pad duels: one write per player at match end (XP, level, streak), sets `Level`, `XpShare`, `WinStreak`.
4. `StreakSaveService` in the lobby: remote `SaveStreak` (validated, rate-limited, price and timer checked inside the `transact`).
5. Studio-built UI (`gauntlet-ui-style`): the SAVE WINSTREAK bar button and the buy popup, XP bar on the match end screen, level-up pop.
6. Tests in Studio: a leaver, a repeated match end, a teleport race, a save with too few coins, an expired offer.

LihFolk used: Session Locking and Profile Libraries; DataStore Fundamentals; Saving Correctly - Autosave and BindToClose (30 s budget, `GetAsync` 4 s cache); Data Schema Design and Migrations (additive fields default on load, refuse newer); Progression and Pacing Design (polynomial XP curve, early levels fast); Genre Playbook - Shooters; Ethical Design and Player Trust; Regional Compliance - Paid Random Items.

## Built (2026-11-22)
- **Data:** `shared/Progress` (pure; runs inside the UpdateAsync) + field `prog` in `PlayerDataV1` (`shared/PlayerData`): level, XP, total, streak, best, saves in a row, lifetime matches / wins / kills, the lost-streak offer, today's wins per opponent. Old saves start at level 1 (no version bump). `PlayerDataService`: `write()` core for one UserId, `transact(..., queue)`, `transactUserId` (leavers), a fresh re-read 12 s after join. Gaps 1-5 above are closed.
- **Server:** `ProgressionService` (every role) takes one report per player per match (`m:<matchKey>:<userId>` id); `MatchService` notes participants, reports a leaver on leave and everyone else as the match ends. `StreakSaveService` (lobby) handles `StreakSave ("buy", shownPrice)`.
- **UI (Studio, builder `tools/studio/BuildStreakSave.luau`):** `LobbyBar.Bottom.SaveStreak` (faceted flame icon `art-source/ui/streak/streak_icon.png`, image 73282136637340, from `tools/ui/make_streak_icon.py`; tag SAVE WINSTREAK; timer chip), popup `UI.Lobby.StreakSave` (Profile's card look: WINSTREAK LOST, streak number, ENDS IN m:ss, SAVE FOR n + coin / GET COINS), match end `Canvas.Right.Progress` (LV, +XP, bar, LEVEL UP pop, streak line). Profile card: XP bar, MATCHES / WINS / ELIMS, BEST STREAK · WIN RATE, streak tag orange while live, refreshes while open.
- **Studio test switch:** Workspace `ProgressBotsCount = true` lets bot matches move the streak (with `PadDuelSolo` for a one-player pad duel).

## Tested in Studio (2026-11-22)
- Progress maths: 3 wins = level 3; the 4th win against one opponent doesn't add; a loss offers the streak at 100; saving restores it plus later wins; an expired offer resets the price; junk saves clean up; an old save without `prog` loads at level 1.
- Live: a seeded offer showed SAVE WINSTREAK with its timer; GET COINS with 0 coins; with 1,000 coins SAVE FOR 100 → coins 900, streak 5, Settings back on the bar, player list streak 5.
- A full solo pad duel lost to a bot: +20 XP, MATCHES 1, the streak-5 offer at 200 (second save in a row), the end screen panel filled ("STREAK 5 LOST · SAVE IT IN THE LOBBY"), SAVE WINSTREAK back in the lobby.
- Profile card opens from the player list row with the real numbers.
- Not tested: a real two-player match, a leaver in a real match server, the match end panel's look (only its values were read), phone layout of the new pieces.

## What to test (owner)
1. Save the Lobby place (new UI: `LobbyBar.Bottom.SaveStreak`, `UI.Lobby.StreakSave`, `MatchEndScreen...Progress`, Profile `XpBar`).
2. Play a pad duel with a friend: XP and level on the end screen, streak in the player list and profile.
3. Lose a streak of 3+ and buy it back; let one run out (15 min) and check the button goes back to Settings.
4. Leave a match early: streak breaks, no XP.
5. Phone: the bar button and popup fit.

# Gun levels (step 3 of the loadout update)

Owner decisions 2026-11-27 ([Loadout and Power Deck → Launch plan](Loadout%20and%20Power%20Deck.md)): a gun levels mainly by **playing with it** (kills, rounds and wins with that gun); **coins can optionally buy levels** (like RIVALS' keys); each level gives a **small, capped stat step in a category**, so a new player's starter gun still wins fights; a **milestone reward every 5 levels**, and the track only says "reward at level N". The rewards wait for a later update. Coins are sold for Robux, so coin levels buy stats: the steps stay tiny and capped, and a coin level is a shortcut, not the main path.

Numbers live in `src/shared/Config/GunLevels.luau`; the rules (level from XP, the stat steps, match XP, coin price) in `src/shared/GunLevels.luau`, used by the server and the client alike.

## The numbers (Claude's proposal, 2026-11-27; the owner tunes)

### Levels
- **Cap: level 50.** Every gun in the active set (10 primaries, 4 secondaries) starts at level 1. The knife has no level.
- **XP to the next level: 50 + 20 per level** (50 at level 1, 230 at level 10, 1,010 at level 49). 25,970 XP from level 1 to 50.
- **Milestones at 5, 10, ... 50** (10 milestones). The card says "Reward at LV 5"; the rewards are built since 2026-11-28: [Level Rewards](Level%20Rewards.md).

### XP per match, for each gun you carried
| Source | XP | Cap per match |
|---|---|---|
| Elimination with that gun | 10 | 30 eliminations |
| Round played carrying it | 5 | 15 rounds |
| Round won carrying it | +10 | 15 rounds |
| Match won (every gun carried in at least one round) | +25 | once |
| No real player on the other side (bots) | × 0.5 | same rule as player XP |
| Left before the end | 0 | same rule as player XP |

"Carrying" = the gun was in your loadout for that round (round 1 is secondary only, so a primary earns from round 2). Kills come from the server's own hit records (`StatsService` `gunKills`, the gun in hand when the kill landed), rounds from `StatsService.roundEnded` with `WeaponService.getLoadout`. Nothing comes from the client.

### What one hour earns (the economy model: 8 matches an hour, 7.5 rounds, 4.5 eliminations, 50% rounds won)
- Primary: about 116 XP a real-player match, **58 a bot match**: about 460 XP an hour against bots, 920 against real players. The secondary earns a bit less (about 47 a bot match: fewer kills, one more round).

| Reach (one gun, played every match) | XP from L1 | Bots | Real players |
|---|---|---|---|
| Level 2 | 50 | match 1 | match 1 |
| Level 5 (first milestone) | 320 | 0.7 h | 0.3 h |
| Level 10 | 1,170 | 2.5 h | 1.3 h |
| Level 20 | 4,370 | 9 h | 5 h |
| Level 30 (top coin level) | 9,570 | 21 h | 10 h |
| Level 50 (max) | 25,970 | **56 h** | **28 h** |

The owner's RIVALS rifle reached level 39 from play; here level 39 is about 34 h of bot play with one gun. A gun is a long-term goal; maxing all 14 is not expected.

### The stat steps (each level-up gives one step, the categories take turns)
Level 2 Handling, 3 Reload, 4 Stability, 5 Accuracy, 6 Handling, ... 50 Handling. Each category's steps are equal and add up to its cap at level 50.

| Category | What it changes | At level 50 | Steps (each) | At level 30 |
|---|---|---|---|---|
| HANDLING | draw/equip time and ADS-in time | **−8%** | 13 (−0.62%) | −4.9% |
| RELOAD | reload time (tactical, empty, every shell step) | **−8%** | 12 (−0.67%) | −4.7% |
| STABILITY | recoil kick (up, the climb after, side) | **−8%** | 12 (−0.67%) | −4.7% |
| ACCURACY | hip spread (first shot, growth, max) | **−5%** | 12 (−0.42%) | −2.9% |

- **Never touched:** damage, fire rate, magazine, range, falloff, pellets and pellet spread, move speed. **Time to kill is the same at level 1 and 50**, so a new player's starter gun wins any fight its aim wins. A maxed Havoc reloads in 2.30 s instead of 2.50, aims in 0.184 s instead of 0.2, kicks 8% less.
- Applied the same on both sides from the same config: the server's reload and draw checks (`WeaponService` slot config) and the client's recoil, spread, ADS and reload clips (`WeaponController` slot config). Mods' status effects still multiply on top.
- Bots have no gun levels (level 1).

### Coin levels (the shortcut)
- **One level for 3 coins per XP left in the current level, rounded up to 10.** Level 1→2 costs 150, level 10→11 costs 690, level 29→30 costs 1,830. Progress already in the bar lowers the price.
- **Coins buy levels only up to level 30.** Levels 31-50 come from play only. Level 1 → 30 by coins: about 28,700 coins, about the whole gun set (30,900).
- **Why play stays the main path:** an hour against bots gives a gun about 460 XP, which would cost about 1,380 coins. Late game a player earns about 145 coins an hour against bots, so buying the XP costs about 9-10 hours of coins for one hour of play (about 2 hours of coins while the Task Path still pays ~650 an hour). In Robux (16 coins a Robux at best), level 1→30 is about the 1,999 R$ pack for 4.7% stats. Stats bought are capped at about 60% of a maxed gun.
- The confirm shows the price; the server re-prices inside the save write and refuses if it changed ("price"), so a player never pays a price they didn't see.

## Build (2026-11-27, Studio-tested, not published)
- **Config:** `src/shared/Config/GunLevels.luau` (XP, curve, categories, caps, coin price, `REWARDS` empty). **Rules:** `src/shared/GunLevels.luau` (level from XP, `nextMilestone`, `category`, `bonus`, `apply`, `clean` / `valid`, `cleanMatch`, `applyMatch`, `coinPrice`, `boughtTotal`, `read` / `levelOf`).
- **Save:** `PlayerData` field `gunxp = { [gunId] = total XP }`, published as the StringValue `GunXp`. Additive, like `prog` and `guns`: a save without it cleans to `{}` (every gun level 1), no version bump; every write keeps fields it doesn't know, so a live server on the old build never drops it. Unknown gun ids are kept (64 max), totals whole and capped at 25,970; `PlayerData.valid` refuses anything else.
- **XP grant:** `StatsService` counts per player, per gun, `gunRounds` / `gunRoundsWon` at each round end from `WeaponService.getLoadout` (what the server handed out), plus the existing `gunKills` (gun in hand at the kill). `StatsService.gunStats` → `MatchService.reportProgress` → `ProgressionService.report(..., gunStats)` → `GunLevels.cleanMatch` (checked again) → `GunLevels.applyMatch` inside the same match write (txId `m:<match>:<user>`, so it never counts twice). Leavers get nothing. The `ProgressEvent` "gain" carries `guns = { { id, xp, from, to, total } }`.
- **Stats:** `WeaponService.newSlot(player, id)` builds the slot from `GunLevels.apply(config, level)`, so reload, draw and every server check use the levelled times. The weapon-state snapshot sends each slot's `level`; `WeaponController` builds the same config from it (not from its own read), so the client never times a reload differently from the server. Spectators keep the base config (cosmetic only).
- **Coin level:** `LockerGunRequest("level", gunId, shownPrice)` in `LockerService.gunChoice`: rate limit (`LockerGunRequest` 2/s) → enum / id / finite whole price → Lobby only, not while a match is found → owned, in the active set, under the coin cap, the price equals the server's own price, enough coins, 1 s between coin levels → `savingGuns` lock → one `PlayerDataService.transact` that prices again on the latest save, takes the coins and sets the XP to the next level's start. Refusals: `bad`, `notOwned`, `maxed`, `price`, `coins`, `slow`, `busy`. Telemetry `GunLevelBought`.
- **Locker card** (`LockerV3Controller.refreshLevelCard`, Studio template `ServerStorage.LobbyUI.LockerV3.Right.Stack.GunOwned.Level`, now 184 tall): LV + number, `x / y XP` and the bar, "NEXT LEVEL +0.7% RELOAD", "Reward at LV 5" (the chip stays hidden until rewards exist), and a **Level up now** row (the Unlock row's pattern) with the coin button: gold when the gun is in the loadout (EQUIPPED is dark then), dark while EQUIP is the gold action; past LV 30 it reads "Play to level up". The shared confirm window says `LEVEL UP HAVOC?`, the price and "LV 2 → 3 · +0.7% RELOAD · N coins left", OK reads LEVEL UP. Gun rows show `LV n`. The Overview shows the gun at your level.
- **Level-up moment** (`ProgressController.playGun`, Studio template `UI.Match.MatchEndScreen.Canvas.Right.GunProgress`, under the player XP card): the gun that levelled (else the most XP), its render, `NAME LV n`, `+XP`, a bar that fills and wraps; on a level up the name ticks to the new level and a gold `+0.6% HANDLING` pops from its centre.
- **Owner: save the place** (both templates are Studio edits).

## Tests (Studio, 2026-11-27)
- **Old save loads:** my Studio save had no `gunxp` (46,311 coins, Scout + Classic, 40 matches). Lobby Play: `DataReady`, `GunXp = []`, coins and loadout unchanged, every gun LV 1 in the Locker. Edit-mode `PlayerData.clean` of an old-shape save: `gunxp` empty, `valid` true. Junk totals (NaN, infinity, negative, fractions, a number key) clean away; an unknown gun id is kept.
- **Coin level, spam:** 10 `level` requests for the Havoc in one frame at the shown price 150 → **one** level: 46,311 → 46,161 coins, Havoc 50 XP (LV 2); the rest refused `busy` / `slow`. NaN, infinity, a wrong price (`price`), the knife, an unowned gun and a 400-character id were refused. Then through the UI: Havoc row → Level up (210) → confirm → 45,951 coins, LV 3, the card and the next price (270) refreshed.
- **Bot match XP:** `ServerRole = Match`, `BotMatch = 1v1`, `QuickMatch` (one round). A lost round with the Classic gave it **+2 XP** (5 a round × 0.5 vs bots), saved in the match write; the end screen's gun row showed `CLASSIC LV 49 +2 XP`. Seeded 1 XP short of LV 50, the next match levelled it: `CLASSIC LV 50` and the gold `+0.6% HANDLING` pop.
- **Stat step, measured in-game** (the server's enforced reload length, `ReloadFor`, lobby Range): Classic LV 49 **1.702 s** vs 1.85 base (−8.0%, all 12 Reload steps); Havoc LV 3 **2.483 s** vs 2.5 (−0.67%, one step); Hornet LV 1 2.100 s (base). The weapon-state snapshot carried `Vandal@3`, `Classic@50`; the first shot after each reload was accepted.
- **Rules (Edit mode):** curve 50 / 320 / 1,170 / 9,570 / 25,970 XP to LV 2 / 5 / 10 / 30 / 50; coin price 150 (LV 1), 80 (half a bar), 690 (LV 10), 1,830 (LV 29), none at LV 30. Havoc LV 50: reload 2.3, ADS 0.184, kick 0.386, first-shot spread 0.2375; damage 18, fire interval 0.103, magazine 25, move 0.95 unchanged. A match model (4 kills, 6 rounds, 3 won, a win, bots) gave the Havoc 62 XP.
- **Captures (1920x1080):** the Locker card, the level-up confirm, the end-screen gun row (in the session transcript, not saved: they show Studio test UI). **Not done: 667x375.** Studio's Device Emulator needs the desktop, and the access request got no answer. Next Studio session: iPhone 7 in the Device Emulator, open the Locker on an owned gun, capture, check the card's smallest text (Next line and the level-up sub are 15 px design).
- **Not seen in-game:** a kill's XP (the bot won every QuickMatch round; the kill count is the same `gunKills` the win cutscene already uses), and a level reached through kills and wins in a full first-to-5 match.

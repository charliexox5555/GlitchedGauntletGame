# Battle Pass build plan (Season 1)

2026-11-26. How to build what [Battle Pass Season 1 Contents](../01%20Design/Battle%20Pass%20Season%201%20Contents.md) describes. The screen is [UI Battle Pass](../02%20Art/UI%20Battle%20Pass.md). Each phase ends working and testable in Studio before the next starts. `Release.BATTLE_PASS_OPEN` stays `false` in live servers until phase 9.

## What's there now (2026-11-26)
- **Screen:** built in Studio (`tools/studio/archive/BuildBattlePass.luau`). `BattlePassController` reads `SeasonCatalog.PREVIEW_PROGRESS`, so claims don't save. Phones still get the old placeholder panel.
- **Data:** `SeasonCatalog.luau` holds placeholder tiers. `PlayerData` (`PlayerDataV2`, written only by the lobby's `PlayerDataService.transact`) has no season, charm or title fields. Champion is saved as `data.tasks.title` and only shows in a toast.
- **Match end:** `MatchService.reportProgress` sends `ProgressionService.report` (won, roundsWon, kills…) as one write per match (`m:<matchKey>:<userId>`). Nothing tracks time in live rounds.
- **Robux:** only dev products (`Config/Products.luau`, one `RobuxService.processReceipt`). There are no gamepasses.
- **Draft:** `DraftService.abilityPools` filters with `ModLoadout.eligible`, which is also what the re-check uses, so it's the place for a pass lock.
- **Locker:** skins equip through `LockerRequest` and save in `LockerV2`. There's no charm or title slot. Every gun has a `CharmPoint` attachment, but nothing hangs from it.

## Phases
| # | Phase | What gets built | Done when |
|---|---|---|---|
| 1 | **Season data + rewards** | `SeasonCatalog` gets the real 30 tiers, `SEASON_ID`, the 6-week end time (UTC), and the tier rule (30 min or 25 rounds won, +5 rounds for the first win of the day, bots at half). `PlayerData.season = { id, premium, tier, liveSeconds, rounds, claimed = { free, premium }, firstWinDay }`, cleaned in `PlayerData.clean`. A new id wipes progress, but phase 9 pays any leftovers first. One shared `SeasonRewards.grant(data, reward)` covers coins, cases, tickets, skins, charms, titles and power unlocks. | Unit checks in Studio: tier-up maths, both meters resetting, grant of every reward kind. |
| 2 | **Progress from matches** | `MatchService` adds each player's seconds while the phase is `Live` (skips the lobby, Range and gaps between rounds). That number and `roundsWon` go into `reportProgress`, and `ProgressionService` adds season progress in the **same** transact as XP. Leavers get the time they played but no first-win bonus. | A bot match in Studio moves the meters by the right amounts; one save per match. |
| 3 | **Robux** | Two new dev products: `season` (689: sets `premium`, grants the SEASON 1 title) and `seasonSkip` (499: +5 tiers, capped at 30). Each gets a branch in `RobuxService.grant` and a txId from the PurchaseId. Buying premium late unlocks every premium tier already reached. Prompting is refused once premium is owned. | Test purchases in Studio: idempotent on a repeated receipt, skip stops at 30. |
| 4 | **Wire the screen** | A `SeasonRequest` remote (`claim {tier, track}`, `claimAll`; types checked, rate-limited, server checks the tier is reached, owned and not yet claimed). The replica pushes season state. `BattlePassController` drops `PREVIEW_PROGRESS`. UNLOCK PREMIUM and +5 LEVELS prompt the products. The pass shows "12:40 LEFT OR 9 ROUNDS". Phone layout. Security review (`lihfolk:roblox-secure-remotes`). | Claims save across a rejoin; a forged claim is rejected; works on phone size. |
| 5 | **Titles** | `data.titles = { owned, equipped }`. Champion moves in from `tasks.title`. A Titles section in the profile with equip through the Locker remote. Auto-equip only when nothing is on, otherwise a toast with EQUIP. Gets SEASON 1 and FROSTBITTEN. | Equip saves, toast shows, Champion appears for players who already earned it. |
| 6 | **Charms** | `data.charms = { owned, equipped }` (one charm on all guns, or per gun: decide when building). A Locker slot. At runtime the charm model hangs from `CharmPoint` on the viewmodel and third-person gun, with a spring swing from move, turn and recoil. Epic charms get a small effect. High Score shows this match's kills from a server-set attribute. Pooled, cleaned up on unequip. | All 8 placeholder charms swing in first and third person; no leaked connections. |
| 7 | **Powers** | `ModLoadout.eligible` also passes a Mod listed in `SeasonCatalog.POWER_UNLOCKS` once the player has claimed it (Smoke: free tier 10; Electric Shock: premium tier 20). Each power is then built through the [ability build prompt](../01%20Design/Abilities/00%20Abilities.md#build-prompt-paste-into-claude-code-when-the-specs-are-ready) (gameplay, look, sound passes). Smoke also stops aim assist and auto shoot through it ([Bugs & Ideas](../05%20Production/Bugs%20%26%20Ideas.md)). | Locked players never see the power in a draft; both powers pass the three passes. |
| 8 | **Art** | Arcade (Rare, 8 guns), Frostbite (Legendary: 4 with animation and sounds), 8 charm models. Blender pipeline, `gauntlet-build-style` + `gauntlet-model-joins`, the Style Bible first. Neither line goes into cases. | Owner OK on renders, then in Studio. |
| 9 | **Season end + launch** | At the end time, unclaimed rewards reached are paid on the next join or save, then the season locks. Admin tools (set tier, give premium, reset season) in Studio only. Playtest note, `BATTLE_PASS_OPEN = true`. | A forced season end in Studio pays the leftovers once. |

## Order and splitting
- Phases 1 to 4 are one code track (data → progress → Robux → screen) and go in order.
- Phases 5 and 6 come after 1, and each can run on its own.
- Phase 7's lock needs phase 1. The two powers themselves are separate ability builds.
- Phase 8 art can start any time (Blender work, no code).
- Phase 9 comes last.

## Progress
- **Phase 1 done (2026-11-26).** Built:
  - `Config/Season.luau`: the rules.
  - `Shared/SeasonPass.luau`: the state, `applyMatch`, `skip`, claims.
  - `Lobby/SeasonCatalog.luau`: the real 30 tiers, plus `EXTRA` for tier 30's FROSTBITTEN title and `rewards()`.
  - `Lobby/SeasonRewards.luau`: `grant`, `claim`, `claimAll`, `setPremium`.
  - `PlayerData`: new `season`, `charms` and `titles` (`{ owned, on }`) fields, cleaned and validated.
  - `ShopCatalog.Kind`: added `Ticket` and `Title`.

  A pass power is granted as an owned and equipped Mod in `data.mods`, which `ModLoadout.eligible` already accepts. For phase 7, set `free = false` on Smoke and ElectricShock in `Config/Mods`.

  Studio (Play, server): 27 checks passed (meters and overflow, first win once a day, leavers, bots at half, caps, NaN, skip cap, clean/valid, every reward kind, claiming all 30 tiers, save round trip). A real save loaded fine. `Season.STARTS_AT = 0` until launch (no end date). Nothing calls it yet: phase 2 feeds matches, phases 3 and 4 add purchases and claims.

- **Phase 2 done (2026-11-26).** Built:
  - `MatchService` counts each player's seconds in live rounds (Live and SuddenDeath) from phase changes. Only players on a team get time. A leaver's part-round is flushed before their report. The total goes into the report as `liveSeconds` (new optional field in `Progress.Result`).
  - `ProgressionService` runs `SeasonPass.applyMatch` in the **same** write as XP and coins, when `Release.BATTLE_PASS_OPEN` is on (or in Studio) and the season hasn't ended. `botsOnly = not counts`. The "gain" event now also carries `seasonTiers`.
  - **Fix:** `PlayerDataService.transact` writes a fixed list of fields and didn't include the new ones. It now saves `season`, `charms` and `titles`. Without this, phase 1's state would never have saved.

  Studio: a 1v1 bot match (`ServerRole = Match`, `BotMatch = 1v1`, AFK player who lost 0–5) saved `season.secs = 37` (74 s live, half for bots) and `rounds = 0`. A match before the fix saved no season, which is how the bug was found. The test switches are back to `ServerRole = Lobby`.

  Not tested: a real 1v1, a win (first-win bonus), a leaver mid-round, a tier-up from a real match (the maths is covered by the phase 1 checks).

## Rules for every phase
`--!strict`. Every number lives in `SeasonCatalog`/Config. The server is the only source for progress, claims and grants. Every remote validates types, rejects non-finite numbers and is rate-limited. One save per match, and a txId on every grant so nothing pays twice.

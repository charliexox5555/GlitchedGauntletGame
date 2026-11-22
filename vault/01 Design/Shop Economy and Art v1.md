# Shop economy and art v1 (launch) — brainstorm 2026-11-22

Owner's ask (2026-11-22, with RIVALS shop screenshots: Super Starter Bundle, bundle grid with "VALUE" tags, Standard Weapons Bundle with item tooltips, skin bundles with item tiles, the bundle detail menu with Buy Item / Buy Bundle / struck-out price, key packs, Roblox's buy dialog, Login Rewards):
- Real bundle art from our own assets (ChatGPT images where they help), layouts reworked to match.
- Hover a bundle → its items. Click a skin bundle (not the Starter) → a detail menu: pick each item, see it (a static picture for most, 3D for a few), buy items one by one (not always all of them) or the bundle.
- Daily rewards, the daily shop and buying all working.
- Reprice: "things might be too free". RIVALS sells skins for Robux only and has an earn-only second currency for cases. Low-tier daily skins could cost coins so coins have a use at launch. High coin packs give a bonus (a case). Robux prices by rarity.
- Coin packs need better looks.

Status: **decided 2026-11-22** (owner's picks below); numbers in the tables are the starting values, tuned in the build. Nothing built yet.

## Owner's picks (2026-11-22)
1. Second currency = **Tickets** (icon: a gold ticket stub, matching the Draft Ticket logo). Earn-only, never sold for Robux; cases cost Tickets.
2. Daily shop: **Common and Rare for coins**, Epic and up Robux only.
3. Coins at launch: **login rewards + small match pay** (about 15 a match, 35 a win, daily cap about 400).
4. Bonus cases in coin packs 4–6 and the Starter Bundle: **a case where allowed** (odds shown); players where paid random items are restricted get extra coins instead.

## What we have today (checked in code 2026-11-22)
- **One currency, Coins.** New players start with 2,500 (`Config/Inventory.STARTING_COINS`, marked placeholder). **Nothing earns coins yet**: the only sources are the start balance, the Studio test button and the duplicate-case refund. Spends: cases (400 / 900 / 2,000 / 2,500) and the streak save (100 doubling).
- **Cases** also carry Robux prices in `ShopCatalog.CASES` (99 / 199 / 399 / 499, ×3 249–1,249), not wired. Odds and the PolicyService paid-random-items gate exist (`ShopService`).
- **Skin tiers** (`Config/Skins`): Common (7 reskin lines), Rare (7 shape lines), Epic (3 animated lines; some knives Epic / Legendary), Legendary (Slipframe knife only today), Exclusive (Ruin-Blighted, Tempest-Strike: bundle only).
- **Placeholder Robux per item** (`ShopCatalog.ITEM_ROBUX`): skins 249 / 349 / 479 / 599 by tier.
- **Pictures:** every skin has a square portrait (`Shared/ItemPortraits`) and a side picture (`Shared/ItemIcons`) via `Shared/SkinArt`; crate renders; coin pack renders (`art-source/ui/shop/pack_01..06`); tab icons; an old Starter Bundle banner.
- **Bundle detail menu exists** (`Shop.Canvas.Preview`: header, 3D stage, BACK / BUY ITEM / BUY BUNDLE / SEPARATELY, item strip). It shows 3D for everything; Robux buttons do nothing yet (no developer products).
- **Daily shop:** 8 fixed placeholder skins, coin prices by tier, no rotation, no buying. **Login rewards:** a 7-day board with no rewards behind it.

## Proposal

### 1. Two currencies
| | **Coins** (soft) | **Tickets** (earn-only) |
|---|---|---|
| Earned | login rewards, level-ups, small match pay (Q3) | login rewards, level-ups, win-streak milestones, duplicate refunds |
| Bought with Robux | yes, coin packs | **never** |
| Spent on | low-tier daily skins, streak save; later charms, abilities | **cases only** |

Why: cases bought with an earn-only currency keep cases out of "paid random items" (cases can then show everywhere, no region lock), and skins stop being easy to farm with coins. Coins still matter at launch through the daily shop.
- Cases lose their coin and Robux prices; each costs tokens (Standard 1, Elite 3, Apex 6, Knife 8: a starting point).
- **Bonus cases in Robux coin packs would be paid random items again.** Two ways: give the case only where `PolicyService` allows it (extra coins elsewhere), or give a fixed reward instead of a case (Q4).

### 2. Skin prices by tier (Robux; RIVALS references: a Rare daily skin 359, a bundle item 449)
| Tier | Daily shop | Robux each |
|---|---|---|
| Common | **coins** (e.g. 1,000) | 199 |
| Rare | **coins** (e.g. 2,500) or Robux (Q2) | 349 |
| Epic | Robux | 449 |
| Legendary | Robux | 649 |
| Exclusive | not in the daily shop | bundle items only, 499 each where sold alone |

### 3. Earning coins at launch (Q3)
Login rewards for everyone, plus optional small match pay (e.g. 15 a match, 35 a win, a daily cap of ~400) so a player who plays sees coins move. Starting coins drop from 2,500 to about 500.
Coin goal: a daily-login-only player can afford one Common daily skin a week; a regular player one a few days.

### 4. Login rewards (7 days, then repeat; a missed day restarts at day 1)
Day 1 250 coins · Day 2 1 token · Day 3 500 coins · Day 4 2 tokens · Day 5 750 coins · Day 6 3 tokens · **Day 7 a Standard case + 1,000 coins** (big tile). Claimed from the DAILY tab and a lobby toast.

### 5. Daily shop
**Per player** (owner 2026-11-22: "not the same for everyone"): at each player's first visit after 00:00 UTC the server rolls their 8 skins and **saves them in their data** (day index + picks + bought), so a client can never buy anything off its own list. No duplicates, skins they own are skipped where possible, weighted: 4 Common, 2 Rare, 1 Epic, 1 Epic-or-Legendary. Owned skins show OWNED. Price by tier (section 2). Coins buy in one server write; Robux through a developer product per price point.

### 6. Coin packs (≈10 coins per Robux, growing bonus)
| Pack | Coins | Robux | Bonus |
|---|---|---|---|
| 1 | 500 | 49 | — |
| 2 | 1,200 | 99 | +20% |
| 3 | 2,600 | 199 | +30% |
| 4 | 7,000 | 499 | +40%, + Standard case (Q4) |
| 5 | 15,000 | 999 | +50%, + Elite case — BEST VALUE |
| 6 | 32,000 | 1,999 | +60%, + Apex case |
New look: the existing pile renders get a bigger, brighter stage, a "+40%" tag and the case picture in a corner of the big three.

### 7. Bundles
- **Price** = clearly under the real separate price (we show "SEPARATELY 2,995" struck out, never an invented "x5 VALUE"):
  - Ruin-Blighted (5 Exclusive): **999** (separately 5 × 499 = 2,495). Owner 2026-11-22: "around 1,000 for the bigger bundles".
  - Tempest-Strike (5 guns + Katana): **1,099** (separately 5 × 499 + Katana bundle-only; one item more than Ruin-Blighted).
  - Starter Bundle: **67** (owner 2026-11-22), once per player: coins + a Standard case where paid random items are allowed (extra coins elsewhere). Never Tickets (they are never sold).
- **Sold alone:** each gun skin of a bundle; the knife-slot item (Katana) bundle-only.
- **Hover a bundle card** → a tooltip strip of its items (picture, name, kind), like RIVALS' Molotov tooltip but in our dark plate style.
- **Detail menu** (rework `Canvas.Preview`): header "NAME · SKIN" with the tier tile; the **static portrait** big in the middle (3D only for knives and animated lines, owner's call per item); BACK, BUY ITEM (Robux), BUY BUNDLE (Robux) + struck SEPARATELY; the item strip at the bottom with tier-coloured tiles, OWNED marks.

### 8. Art plan
- **Bundle banners:** layered in Studio, not one flat image, so prices and text stay live: (1) a background per line from ChatGPT (no guns, no text, our palette: Ruin = mossy teal ruins, Tempest = storm blue, Starter = green), (2) our own skin renders: the hero gun big and angled, the rest as small tier tiles (RIVALS Gothic / Pirate layout), (3) title in the game font. Hero renders: new 1600-px side renders from Blender of the Vandal of each line (portraits exist but are square and small).
- **Coin packs:** re-render the six piles larger with a rim light; the case badge on packs 4–6.
- **Currency icons:** the token needs an icon (Q1); ChatGPT concept → owner pick → Blender render, like the crates.
- **Login reward tiles:** coin, token, case icons from the renders above.

### 9. Build order (after the picks)
1. Config + data: `Config/Economy` (all prices, packs, login calendar, daily weights), token balance in `PlayerData`, starting coins.
2. Server: `LoginRewardService`, daily shop rotation, coin buys, developer products + `ProcessReceipt` (idempotent, one grant per receipt), bundle and item purchases; security review.
3. Art: ChatGPT backgrounds and token icon (prompts in this note), Blender hero renders, pack re-renders.
4. Studio UI: bundle banners, hover tooltip, detail menu, coin packs, daily shop, login rewards; phone + PC captures.
5. Owner creates the developer products on the Creator Dashboard (ids go into `Config/Economy`).

## Roblox rules this leans on (LihFolk, 2026-11-22)
From `11 Monetization Publishing and Live Ops`: *Paid Random Items and Odds Disclosure in Practice*, *Regional Compliance - Paid Random Items and Country Rules*, *Currency Architecture - Soft Hard and Event Currencies*, *Robux Price Points and Offer Design*, *Developer Products and ProcessReceipt*, *Daily Rewards System End to End*, *Limited-Time Offers - Design and Ethics*.
- **Paid random item** = any random result bought directly or indirectly with Robux, including through a currency that is also sold for Robux. So: cases for **earn-only tokens are outside it** only while tokens never touch Robux (no token packs, no tokens in Robux bundles). Coins are sold, so a case for coins, or a case inside a coin pack or the Starter Bundle, **is** a paid random item: odds shown before buying and the `ArePaidRandomItemsRestricted` gate (a key in `GetPolicyInfoForPlayerAsync`'s table), server-side, failing closed.
- One job per currency; paid value never expires; floor gains, ceil costs; derive prices from one income model.
- Coin packs: 3–5 rungs (we have 6 slots), value per Robux rising, one impulse rung under 100 R$; compute "+N%" labels from the grant table, never typed.
- `ProcessReceipt`: one owner script dispatching by product id; grant + `PurchaseId` saved in one write, `PurchaseGranted` only after the save; `NotProcessedYet` if the player's data isn't loaded; never grant from `PromptProductPurchaseFinished`.
- Daily rewards: server UTC day index (not timestamp gaps); mark claimed, save, then pay; no-argument claim, rate-limited; write the missed-day rule down.
- Timers: server `endsAt`, shown with `Workspace:GetServerTimeNow()`; no countdowns that restart; "exclusive" only for items that never come back; the daily shop says "new items in 5h", not "limited".
- Consequences for the proposal: the duplicate refund pays **tokens** (not coins); level-up and login cases are fine (earned); the coin-pack and Starter Bundle cases need Q4.

## Questions for the owner
1. Second currency: name and icon (ideas: **Tickets** to match the Draft Ticket logo, Seals, Marks).
2. Daily shop: Common and Rare for coins, Epic and up Robux? Or only Common for coins?
3. Coins at launch: login rewards only, or login + small match pay?
4. Bonus cases in coin packs / the Starter Bundle: case only where allowed (extra coins elsewhere), or a fixed skin instead?

## Step 1 built: economy config, Tickets, login rewards (2026-11-22)
- **`src/shared/Config/Economy.luau`** (new): `STARTING_TICKETS` 2, `MAX_TICKETS`, the 7-day `LOGIN` calendar (250 coins · 1 Ticket · 500 · 2 Tickets · 750 · 3 Tickets · Standard case + 1,000), `CASE_TICKETS` (Standard 1, Elite 3, Apex 6, Knife 8: wired in step 2), `Economy.day(t)` = UTC day index.
- **Starting coins 2,500 → 500** (`Config/Inventory.STARTING_COINS`; only new saves).
- **Save data** (`Shared/PlayerData`, same `PlayerDataV1` key, no version bump): `tickets` (a save from before gets the starting 2) and `login = { last = UTC day, step }` (`Shared/LoginRewards`: clean / valid / nextStep / board). Published as StateValues `Tickets`, `LoginLast`, `LoginStep`. `PlayerDataService.write` writes both fields; older servers keep them (they clone the stored table).
- **`LobbyServer/Services/LoginRewardService`** (new): remote `LoginClaim` (no arguments, `RATE.LoginClaim` 0.5/s burst 2) → one `PlayerDataService.transact` that reads the server's UTC day, picks the step (the day after the last claim = next step; a missed day = step 1; after 7 = 1), pays and marks the day claimed in the same write. Answers on `LoginEvent` (`claimed` + what it gave / `failed` + text).
- **DAILY tab board** (`ShopController.hookLogin` / `drawLogin`): each cell shows its reward (coin / coin stack / case art + words; Ticket days are words only until the Ticket icon exists), claimed / today / later states use the colours Studio already had on Day1 / Day4 / Day5, the header says "DAY n OF 7" or "NEXT REWARD IN 5H 12M", and it redraws at the UTC rollover. A clear `Hit` button in each cell (Studio, `tools/studio/ShopLoginRewards.luau`) claims on tap, click or gamepad. A toast on joining says when today's reward is waiting.
- **Tested in Studio play (Studio DataStore):** unit checks of the rules (new player, claimed today, next day, wrap after 7, missed day, bad saves, old save gets 2 Tickets, huge Tickets refused) all pass; join → toast "Your daily reward is ready"; claim via the button → +250 coins, Day 1 CLAIMED, header "NEXT REWARD IN 1H 24M"; a second claim fired straight at the remote → "Already claimed today", no coins; rejoin → still claimed, no toast. No new console errors. Captures: [before](Shop%20Economy/login_before_claim.jpg), [after](Shop%20Economy/login_after_claim.jpg).
- **Not tested:** steps 2–7 for real (needs a real next day; the rules are unit-checked), the Day 7 case grant, two servers at once, phone.
- **Not yet:** Tickets aren't shown anywhere but the board's words (the counter comes with the Ticket icon, step 3); cases still cost coins until step 2.
- **Security review (roblox-reviewer, 2026-11-22):** no Critical / High / Medium. A second claim is impossible (day, step and "claimed" are decided in one `UpdateAsync`); no client values are read; retries reuse the txId; caps and `PlayerData.valid` keep values whole and in range; old saves load safely. Low, parked: a claim while already at the coin / Ticket / 999-case cap uses the day and pays nothing; each server uses its own clock at UTC midnight (the in-write check still stops double claims).

## Step 2 built: Ticket cases, per-player daily shop, match coins (2026-11-22)
- **Cases cost Tickets** (`Config/Economy.CASE_TICKETS`: Standard 1, Elite 3, Apex 6, Knife 8) in `ShopService.buyCase`; a duplicate-only case refunds its Ticket price. The PolicyService paid-random-items gate is off for cases because Tickets are never sold (a case inside a Robux pack will be gated where it's granted). Shop: Home case plates and the popup say "1 TICKET" (words until the Ticket icon); the popup's two Robux buttons are hidden and the Ticket button centred (`tools/studio/ShopTicketCases.luau`, attributes `HiddenSince` / `OldPosition` for rollback).
- **Daily shop, per player and saved** (`Shared/DailyShop` = saved shape in PlayerData `daily`, `Shared/DailyRoll` = roll + prices): `ShopService.ensureDaily` rolls inside a save write when the player's list is from an earlier UTC day (on their data arriving, and every 30 s for players online over midnight); 8 slots from `Economy.DAILY_SLOTS` (4 Common, 2 Rare, 1 Epic, 1 Epic-or-Legendary), no repeats, unowned skins first, bundle-only lines never. `ShopRequest("buyDaily", slot)` buys only from the saved list: same day, not bought, not owned, coin tier, enough coins, all inside one write (+ skin, slot marked bought). Prices: Common 1,000 / Rare 2,500 coins; Epic 449 / Legendary 649 Robux ("coming soon" until developer products). Cards show OWNED, coin or Robux plates; the old placeholder list (`ShopCatalog.DAILY`) is gone.
- **Match coins** (`ProgressionService`, same write as the XP): 15 for finishing + 20 for a win, half with no real opponent, 0 for leaving, max 400 a UTC day (`earn`). The match end line reads "+85 XP · +35 COINS".
- **Tested in Studio play:** the daily list rolled and saved on join (shape and prices right); bought slot 1 for 1,000 coins → OWNED, "is yours" toast; buying it again, the Robux slot, slot 99 and NaN straight at the remote charged nothing (the bad args logged as `badArgs`); rejoin → same list, still bought. Ticket case: 2 → 1 Ticket, +1 Standard case; Elite with 1 Ticket → "Not enough Tickets"; opening a case still works. Roll checks over 200 seeds: no repeats, right tier per slot; a player owning every Common still gets 8 (owned ones shown); an owned skin never shows while unowned ones exist. Captures: [daily shop](Shop%20Economy/daily_shop_bought.jpg), [Ticket case](Shop%20Economy/ticket_case_popup.jpg).
- **Not tested:** match coins in a real match (no MCP-safe way to finish a match here; the code is small and inside the tested match write), the midnight re-roll for someone online, phone.
- **Next:** Robux (developer products the owner creates: one per price point; ProcessReceipt with the intent saved before the prompt), then art (Ticket icon, banners, packs) and the bundle detail menu.
- **Security review (roblox-reviewer, 2026-11-22):** nothing exploitable (no off-list buys, no double buys, no client prices, no re-roll farming; removing the case gate is right while nothing sells Tickets or cases). Three Lows, all fixed: the daily roll now fires only when the saved list is *older* than today (no flip-flop between servers with slightly different clocks); the roll skips skin ids longer than the saved shape keeps; the leftover coin / Robux prices on cases are gone from `ShopCatalog` with a warning never to put cases or Tickets in anything bought without the gate.

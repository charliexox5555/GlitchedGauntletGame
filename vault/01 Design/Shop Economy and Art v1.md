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

## Owner's notes on the shop UI (2026-11-22, with RIVALS refs: Skins tab bundle grid, the Gothic bundle detail, the daily shop, the emote buy popup)
UI pass (after Robux; Studio-built):
1. Clicking a skin bundle must **fill the screen and be centred** (ours isn't). Keep the **top tab bar** showing in the detail view, like RIVALS.
2. Each skin bundle gets a **bigger card** like RIVALS (hero gun + item tiles); the whole shop should **fill more of the screen**.
3. Price buttons should look better (RIVALS: big green Robux buttons, yellow currency buttons, red struck-out "separately" tag); ours read boring.
Economy / flow (this step):
4. Every skin in a bundle can be bought **on its own, for more**; the bundle shows the items' sum struck out and its real, lower price.
5. **One free daily skin per player, lifetime**: a coin-priced pick in their daily shop says FREE and can be claimed.
6. Buying anything opens **our confirm popup** first (item, picture, price button; RIVALS' emote popup), for coins and Robux. Not enough coins → switch to the COINS tab and point at the pack that covers it.
7. Create the Robux developer products and process receipts.

## Step 3 plan: Robux purchases (2026-11-22)
- **Products** (created through Open Cloud, ids in `Config/Products`): 6 coin packs; bundles Ruin-Blighted 999, Tempest-Strike 1,099, Starter 67 (once per player); skin price points 349 (bundle gun alone), 449 (bundle knife alone, daily Epic), 649 (daily Legendary).
- **Bundle items alone:** guns 349, knife 449 → Ruin-Blighted separately 1,745 vs 999; Tempest-Strike 2,194 vs 1,099.
- **Receipts:** one `ProcessReceipt` in the lobby; grant + `PurchaseId` in one save write (`txId = r:<PurchaseId>`), `PurchaseGranted` only after it saves, `NotProcessedYet` when the player or their data isn't here. Bundles, packs and the Starter grant by product id. The shared skin price products need to know *which* skin: the server saves that intent in the player's data before it prompts, and the receipt reads it (a lost intent pays the price back as coins).
- **Cases inside Robux buys** (packs 4–6, Starter) are paid random items: granted only where PolicyService allows (checked at grant, fail closed), extra coins otherwise.

## Step 3 built: Robux purchases, free daily skin, confirm popup (2026-11-22)
- **12 developer products created** (Open Cloud, universe 10772880160, all for sale; ids in `src/shared/Config/Products.luau`): coin packs 500/49, 1,200/99, 2,600/199, 7,000/499 (+Standard case), 15,000/999 (+Elite case), 32,000/1,999 (+Apex case); Ruin-Blighted 999; Tempest-Strike 1,099; Starter Bundle 67 (1,000 coins + Standard case, once per player); Weapon Skin 349 / 449 / 649. Icons: the pack renders, the Starter banner, skin portraits; Ruin-Blighted uses the plain bundle banner until its art. **A price change must be made on the Creator Dashboard AND in `Config/Products`.**
- **`LobbyServer/Services/RobuxService`** (new): `RobuxRequest` (`pack` n / `bundle` id / `item` id, i / `daily` slot / `starter`) is checked against the player's save (owned, bought, Starter used, today's list), then the server prompts. The shared skin products first save *which* skin in `buys.intent`. `ProcessReceipt` (the only one): one save write per receipt, `txId = r:<PurchaseId>`, `PurchaseGranted` only after it saves, `NotProcessedYet` when the player or data isn't here or the product is unknown. Cases in packs / Starter only where PolicyService allows (fail closed), extra coins otherwise. Not grantable (lost intent, already owned, second Starter) → its Robux × 10 in coins.
- **Bundle items alone:** guns 349, the knife 449 (`Products.BUNDLE_ITEM_ROBUX`); the preview shows BUY ITEM 349, BUY BUNDLE 1,099 and SEPARATELY 2,194 struck out (Tempest-Strike).
- **One free daily skin per player, ever** (`buys.free`, `ShopService.claimFree`, `Shared/DailyShop.freeSlot`): the first coin-priced pick they don't own shows FREE.
- **Confirm popup** (`PopupCanvas.ConfirmPanel`, built by `tools/studio/ShopConfirmPanel.luau` from the case popup): every buy (daily coins / Robux / free, bundle, bundle item, coin pack, Starter) opens it first. Not enough coins → COINS tab, toast "You need 850 more coins: this pack covers it", the pack nudges. Coin pack cards now read their amounts and prices from `Config/Products`; the Home offer card and the Starter row sell the Starter Bundle.
- **Tested in Studio play** (fake receipts through the Studio-only `ServerStorage.RobuxTestReceipt` hook, since tools can't click Roblox's purchase dialog): Epic daily skin with its saved intent → granted + slot marked bought; the same receipt again → nothing more; a skin receipt with no intent → 4,490 coins; pack 1 → +500; pack 4 → +7,000 and a Standard case; Starter → +1,000, marked; a second Starter receipt → 670 coins; Ruin-Blighted → all five skins; unknown product → NotProcessedYet. FREE card → popup → claimed once; a second claim does nothing. A 1,000-coin skin with 150 coins → COINS tab + toast. Captures: [free skin popup](Shop%20Economy/confirm_free_skin.jpg), [short of coins](Shop%20Economy/coins_tab_short.jpg), [bundle prices](Shop%20Economy/bundle_preview_prices.jpg).
- **Not tested:** a real Robux purchase through Roblox's dialog (Studio test purchases are free; try one in Studio by clicking BUY, then on a live server), PolicyService on a restricted account, phone.
- **Next: the UI pass** (owner's notes 1–3 above): bundle detail full-screen and centred with the tab bar kept, bigger bundle cards, the whole shop larger, RIVALS-like price buttons (the "separately" tag is broken in the capture), plus the art (Ticket icon, banners).
- **Security review (roblox-reviewer, 2026-11-22):** no Critical / High; nothing grants without payment or twice in normal play. Two Mediums, fixed and re-tested: (1) the saved skin choice could change under an open prompt (click skin B behind the dialog for A) → one choice per product (`buys.intents`) and no new skin ask while a skin prompt is open (unlocked by `PromptProductPurchaseFinished`, never a grant; 120 s fallback); (2) receipt ids shared the 25-write `tx` memory → their own list `buys.receipts` (last 100). Lows parked: an unknown product id is retried forever (keep retired products in `Config/Products`); coins at the 10M cap clamp silently; the Studio hook takes untyped args (Studio only).

## UI pass 1 (2026-11-22)
- **Bigger everywhere:** the Shop canvas has `DesktopBoost = 1.3` (Shared/UiLayout now reads a DesktopBoost attribute, opt-in; Phone 1.5 / Tablet 1.2 were already there). Home, Bundles, Daily and Coins fill about 80–90 % of a 16:9 screen.
- **Bundle page:** centred (its parts were placed at x = 960 px on a canvas that is wider than 1920, so it sat left), laid out under the **tab bar, which now stays on screen** like RIVALS (a tab press closes the page and switches); a `PreviewScale` fits it to the height left (`ShopController.relayout`).
- **Price buttons:** BUY ITEM / BUY BUNDLE are big green plates with the label inside on top and the Robux price under it; SEPARATELY is a red plate with the struck-out total (its art was being pushed aside by the list layout; the price now sits in a `Row` like the other plates). Robux plates are green everywhere (bundle cards, daily Robux skins, the confirm popup), coin plates keep the gold.
- **Skin bundle cards:** Ruin-Blighted and Tempest-Strike are full width (1280 × 420), one above the other, each with a big hero picture on the left and one tile per item on the right; hovering a tile shows the item card, clicking it opens the bundle page on that item. Until the hero renders exist the hero and the Ruin-Blighted tiles show the 3D view (`Util/Thumb`).
- Studio patch: `tools/studio/ShopUiPass.luau`. Captures: [Home](Shop%20Economy/ui_home_pc.jpg), [Bundles](Shop%20Economy/ui_bundles_pc.jpg), [bundle page](Shop%20Economy/ui_preview_pc.jpg), [bundle page, phone scale](Shop%20Economy/ui_preview_phone.jpg).
- **Not done / next:** real art (below); the Studio viewport was 1538 × 604 during the captures (very wide), so check on a normal 16:9 window; phone checked by applying the phone scale by hand, not on a device.

## Art plan: what makes what (2026-11-22, owner: "ChatGPT and Gemini are connected ... let me know what is better")
| Art | Best tool | Why |
|---|---|---|
| Every gun / skin picture: the bundle hero shots, Ruin-Blighted's missing tile pictures, daily cards | **Our Studio render pipeline** (`tools/studio/RenderPortraits.luau` → `tools/render/icon_sheet.py`, like the 200+ portraits we have) | It renders the real skin models; an image generator redraws guns and gets our skins wrong. I do these. |
| Bundle banner backgrounds (Ruin-Blighted, Tempest-Strike, Starter) | **Gemini or ChatGPT** (either; Gemini handles very wide images well) | Pure mood art, no gun has to match. Our renders and text go on top in Studio. |
| The Ticket currency icon | **ChatGPT** (give it our coin and crate pictures as the style reference) | Clean transparent PNG icons that copy a reference look well. Then I make the shop / backpack sizes. |
| Coin pack backdrops (optional) | Gemini or ChatGPT | Same as banners. |
| A 3D Ticket model (only if we want it spinning in the case opening later) | ChatGPT driving Blender, from the approved icon | Not needed for launch. |

Save results in `art-source/ui/shop/` with the file names below; I upload and wire them.

### Prompt 1 — Ticket icon (ChatGPT). Attach: `art-source/ui/shop/coin.png`, `art-source/ui/shop/crates/crate_standard_card.png`, a lobby screenshot.
"Game currency icon for a Roblox shooter called Draft Duels: a single gold admission ticket stub, chunky and slightly tilted, with a notched tear edge on one side, a small embossed star-burst emblem in the middle and a thin darker gold border. Same rendering style as the attached coin: soft stylised 3D, clean bevels, warm gold (#FFC83D) with darker gold shading, one soft highlight, no texture noise. Transparent background, centred, nothing else in the image, no text, no glow, no drop shadow. Square 1024 × 1024 PNG." → `ticket.png`. Ask for 4 variations; the owner picks one.

### Prompt 2 — Ruin-Blighted banner background (Gemini or ChatGPT). Attach a Ruin-Blighted Vandal screenshot for its colours.
"Wide banner background, 2560 × 840, for a weapon-skin bundle called Ruin-Blighted in a stylised Roblox shooter. Mood: overgrown ancient ruins at dusk, cracked teal-green stone (#2A6F6A), creeping moss, faint glowing cyan cracks, drifting dust. Stylised and clean, simple shapes, soft gradients, like a polished mobile game store banner. Keep the left two thirds calm and darker (a big weapon picture and the title go there) and the right third simple (item tiles go there). No weapons, no characters, no text, no logos, no frame or border." → `banner_ruinblighted.png`

### Prompt 3 — Tempest-Strike banner background
"Wide banner background, 2560 × 840, for a weapon-skin bundle called Tempest-Strike in a stylised Roblox shooter. Mood: a storm front over a dark sea, deep royal blue (#2F5DB8) clouds, thin white-cyan lightning forks in the distance, wind-swept rain streaks. Stylised and clean, simple shapes, soft gradients, like a polished mobile game store banner. Keep the left two thirds calm and darker and the right third simple. No weapons, no characters, no text, no logos, no frame or border." → `banner_tempeststrike.png`

### Prompt 4 — Starter Bundle background
"Wide banner background, 2560 × 600, for a 'Starter Bundle' in a stylised Roblox shooter: a warm green (#2E7D5B) studio backdrop with soft angular light panels and a gentle spotlight from the right where a coin pile and a weapon case will be placed. Clean, simple, no objects, no text, no logos, no border." → `banner_starter.png`

### Prompt 5 — Coin pack backdrop (optional)
"Square 1024 × 700 background for a coin pack card in a stylised Roblox shooter shop: deep warm gold-brown gradient with soft angular light rays from behind the centre, subtle sparkle dust. Clean and simple; the coin pile picture goes in the middle on top. No objects, no text, no border." → `pack_backdrop.png`

### What I render in Studio (no prompt needed)
- Hero shots: each bundle's Vandal side-on at 2048 px, transparent (RenderPortraits at a larger size) → the cards' Hero.
- Ruin-Blighted portraits for all five guns → its tiles and the bundle page strip.

## Renders done (2026-11-22)
- **Ruin-Blighted portraits** (Vandal, Spectre, Ghost, Guardian, Operator) rendered with `RenderPortraits` settings on a 3 × 2 sheet, cut by `icon_sheet.py` into `art-source/ui/item-portraits/*_RuinBlighted.png`, uploaded (group 11116787) and added to `Shared/ItemPortraits` (image ids, not the decal ids: Open Cloud "Decal" uploads must be resolved to their Image id, e.g. `InsertService:LoadAsset(decal)` → `Decal.Texture`). List in `tools/render/portrait-lists/ruinblighted.txt`.
- **Hero shots** (each bundle's Vandal, near side-on, slight front three-quarter, ~840 px wide): new `tools/studio/RenderHeroShots.luau` (one skin per full-screen sheet), `icon_sheet.py --cols 1 --rows 1 --maxw 1600` (new `--maxw`), `art-source/ui/shop/heroes/hero_*.png`, ids in `ShopCatalog.BUNDLES[*].hero`.
- Cards now show the real hero and tiles; the old hover row of small item cells is gone on cards that have tiles. Captures: [Ruin-Blighted card](Shop%20Economy/bundles_renders_ruin.jpg), [Tempest-Strike card](Shop%20Economy/bundles_renders_tempest.jpg), [bundle page at 16:9](Shop%20Economy/bundle_page_16x9.jpg).

## Owner's verdict on the shop look (2026-11-22)
"The UI definitely needs work, especially the bundles. The colours I just don't like in the Shop and everything needs to be improved. We will render out and create professional images with Gemini or ChatGPT with your prompts once we get there for the bundles."
- So: the flat card colours (teal / blue / green, gold coin cards) are **not liked**; the next look pass replaces them. Bundle banners will be **professional images from Gemini / ChatGPT** (prompts above), with our hero renders as the gun layer where the image needs the real skin.
- Owner, same day: "the looking-at-bundle menu needs to look better and be larger of the screen" → the bundle page gets a bigger stage (the gun much larger, the page using the space the shop tabs leave) and a real design pass, not just the current re-layout.
- Open for that pass: a new shop colour scheme (ask the owner with options before building), banner art in, then every tab polished.

## Look pass: colour scheme options shown to the owner (2026-11-22)
All three keep the dark look (the bright flat restyle was rejected before), drop the flat full-colour card fills, keep green for Robux and gold for coins, and show a skin's tier only on its small tag; banner art carries the bundles' colour.
- **A · Night market** (closest to RIVALS): page #17132A, panels #241D40, inner #2F2752, active tab gold #FFC83D.
- **B · Graphite and gold**: page #121418, panels #1E2128, inner #2A2E37, active tab gold.
- **C · Deep navy and cyan**: page #0E1525, panels #18233D, inner #22304F, active tab cyan #2FD3E6.
Waiting on the owner's pick.

## Look pass 1: scheme A colours (2026-11-22, owner: "keeping the same UI theme in the structure of buttons, but for the colours let's go A")
- **Colours only, same plates and layout.** `src/shared/Config/ShopTheme.luau` (PAGE 17132A, PANEL 241D40, INNER 2F2752, DEEP 1A1530, GOLD FFC83D on ON_GOLD 3A2A00, MUTED CFC8F0, ROBUX 3FD45C, WASH_T 0.12). Studio recoloured by `tools/studio/ShopTheme.luau` (75 parts: old grey panels → PANEL, picture-less card art → INNER, popup closes → INNER, tiles → DEEP, wash → PAGE, dim → DIM, today's login cell → GOLD). ShopController: active tab gold with dark words, other tabs indigo with lilac words; daily cards one indigo with the tier only in the tag's text colour; item cells and tiles indigo; the page wash much stronger (the lobby barely shows, like RIVALS).
- `Util/Thumb` now uses the skin portrait first (Shared/SkinArt), so every item cell and the hover card show pictures (Ruin-Blighted had none).
- **Highlight cut off (owner):** a hovered full-width bundle card's brackets were clipped by the scroll (1340 wide, pages left-aligned 30 px in). The scroll is 1420 wide with the pages centred; measured: brackets 127–1791 px inside the scroll's 86–1832.
- **Bundle page (owner: "top bar buttons more centred and smaller so the gun viewport can be larger"):** on a bundle's page the tab bar scales to 0.68, centres and moves up (scroll top padding 150 → 64; Tabs has a `TabsScale` UIScale marked PivotOk so Util/Pivot doesn't wrap it), the page starts under wherever the tabs end, and the 3D stage is 1600 × 420 (was 1500 × 340). Back / a tab press restores the bar.
- Captures: [Home](Shop%20Economy/themeA_home.jpg), [Daily](Shop%20Economy/themeA_daily.jpg), [login](Shop%20Economy/themeA_login.jpg), [bundle hover](Shop%20Economy/themeA_bundle_hover.jpg), [bundle page](Shop%20Economy/themeA_bundle_page.jpg).
- **Not done:** banner art (owner's Gemini / ChatGPT images), coin pack art backdrops, phone check of this pass, Coins tab capture.

## Art brief v2: prompts for Gemini / ChatGPT (2026-11-22)
Everything sits on scheme A (indigo #241D40 panels, gold #FFC83D, Robux green #3FD45C), so the art should be rich but darker toward the edges where text goes. Save results in `art-source/ui/shop/new/` with these names and tell me; I upload them and paste the ids into `ShopCatalog` (bundle `banner`, `PACK_ART`, `PACK_BACKDROP`); the cards pick them up with no Studio work. Ask each tool for 3–4 variations and pick.

**Which tool:** ChatGPT for anything that needs a transparent background or must copy a reference look (coin packs, Ticket icon); Gemini or ChatGPT for the wide banners (Gemini handles very wide images well). Our Studio renders stay the gun layer on top of the banners (never let the image tool draw our guns).

**1. Coin packs, a set of six (ChatGPT).** Attach `art-source/ui/shop/coin.png` and the six current `art-source/ui/shop/pack_0*.png`. Ask for one image at a time, same prompt with the size line changed, so they match.
"Shop icon for a coin pack in a stylised Roblox shooter called Draft Duels. Use EXACTLY the attached gold coin design (same star emblem, same rim, same warm gold #FFC83D with darker gold shading). Soft stylised 3D, clean bevels, one key light from the upper left, a soft rim light, no texture noise. Transparent background, the pile centred and filling about 80% of the frame, nothing else, no text, no glow, no drop shadow. 1024 × 1024 PNG. Size: [1] a small neat pile of about 8 coins · [2] a short stack with a few loose coins · [3] two tall stacks with coins spilling · [4] a chunky leather pouch overflowing with coins · [5] a small wooden treasure chest with metal bands, lid open, heaped with coins · [6] a big armoured vault crate, door open, bursting with coins and a few coins flying out." → `pack_1.png` … `pack_6.png`

**2. Coin pack backdrop (Gemini or ChatGPT).** "Background for a shop card, 1200 × 820: a deep indigo (#241D40) to dark violet gradient with a soft warm gold light pool in the centre and faint angular light rays behind it, subtle sparkle dust. Clean and simple, darker at the edges. No objects, no text, no border." → `pack_backdrop.png`

**3. Ruin-Blighted banner (Gemini or ChatGPT).** Attach a screenshot of the Ruin-Blighted card. "Wide banner background, 2560 × 840, for a weapon-skin bundle called Ruin-Blighted in a stylised Roblox shooter. Overgrown ancient ruins at dusk: cracked dark stone with glowing teal-cyan (#3FE0D0) cracks, creeping moss, drifting dust, a deep indigo (#17132A) sky. Stylised and clean, simple shapes, soft gradients, like a polished mobile game store banner. The left two thirds stay calm and darker (a big weapon picture and the title go there); the right third simple (item tiles go there). No weapons, no characters, no text, no logos, no border." → `banner_ruinblighted.png`

**4. Tempest-Strike banner.** "Wide banner background, 2560 × 840, for a weapon-skin bundle called Tempest-Strike in a stylised Roblox shooter. A storm front over a dark sea at night: deep royal blue (#2F5DB8) clouds over indigo, thin white-cyan lightning forks in the distance, wind-swept rain streaks. Stylised and clean, simple shapes, soft gradients, like a polished mobile game store banner. Left two thirds calm and darker, right third simple. No weapons, no characters, no text, no logos, no border." → `banner_tempeststrike.png`

**5. Starter Bundle banner.** "Wide banner background, 2560 × 840, for a 'Starter Bundle' in a stylised Roblox shooter: a warm launch-day scene, indigo (#241D40) backdrop with gold (#FFC83D) and green (#3FD45C) angular light panels and confetti-like sparkles, a soft spotlight on the right where a coin pile and two weapon cases will be placed. Clean, simple, darker on the left for the title. No objects, no text, no logos, no border." → `banner_starter.png` (also used on Home's special offer card)

**6. Ticket icon (ChatGPT)** — unchanged, see Art plan above → `ticket.png`.

## Cases for Robux, Starter v2, OWNED, the YOU GOT popup (2026-11-22)
Owner: "Cases prices should show their Robux prices first, and then when you click it have the option for Tickets as well"; Starter = **2 cases + 1,500 coins + 3 Tickets**; case prices **99 / 199 / 399 / 499, and x3 for 249 / 499 / 999 / 1,249**; "it should say owned if it is owned and look good"; "much better feedback and fun for somebody who buys a bundle".
- **8 more developer products** (Standard / Elite / Apex / Knife, x1 and x3) in `Config/Products` (kind "case"); the Starter's description on Roblox updated. **20 products in all.**
- **Locked decision changed:** cases are no longer Tickets-only. Robux cases are paid random items, so they're prompted only where PolicyService allows paid random items (`RobuxService` "case" request, fail closed) and odds stay shown before buying (CONTENTS). Tickets stay earn-only for restricted players: the Starter's 3 Tickets and 2 cases are given only where allowed, else 1,100 extra coins.
- **Case tiles** show the Robux price (green) where allowed, else Tickets; the **case popup** shows BUY x1 (Robux) | BUY x3 (Robux) | WITH TICKETS, or Tickets alone where Robux cases aren't allowed.
- **OWNED:** bundle cards, the Starter row and Home's offer card show OWNED (indigo plate, no icon) once owned; on a bundle page BUY ITEM / BUY BUNDLE turn OWNED and say so when pressed; it updates live when skins or the Starter change.
- **YOU GOT popup** (`PopupCanvas.RewardPanel`, built by `tools/studio/ShopTicketCases.luau`): after every purchase (Robux receipt, daily skin, free skin, Ticket case) the picture pops in with a light sweep, the case reveal's stinger for its tier plays (`Config/UiSounds` RewardCommon/Rare/Epic/Legendary, the owner's case picks), and COLLECT closes it. First pass: more juice (confetti, rays, a count-up for coins, the bundle's items flying in) can follow once the owner has seen it.
- Tested in Studio play: tiles 99 / 199 / 399 / 499; popup with both Robux buttons and Tickets ([capture](Shop%20Economy/case_popup_robux_first.jpg)); fake receipt "3 Elite Cases" → Elite cases 1 → 4 and the popup ([capture](Shop%20Economy/reward_popup.jpg)); owned bundles and the Starter read OWNED.
- **Not tested:** the new Starter contents on a fresh account (this test account already has it), a real Robux purchase, a restricted account, phone.
- Art slots ready: bundle `banner`, `ShopCatalog.PACK_ART`, `PACK_BACKDROP` (paste uploaded ids; no Studio work).

## Launch art wired in (2026-11-22)
ChatGPT made all 11 images from the [master prompt](../04%20Tech/Prompts/2026-11-22%20Shop%20Art%20Master%20Prompt%20(ChatGPT).md) (`art-source/ui/shop/new/`). Uploaded as Decals to group 11116787 (recorded in `art-source/uploads.json`), then resolved to image ids in Studio:

| File | Decal | Image id (used in code) | Where |
|---|---|---|---|
| pack_1 … pack_6 | 109064291275452 · 86886520239434 · 78866372280146 · 75577400751519 · 92863181294549 · 110815832727983 | 133249202687167 · 92145452769066 · 90207390989766 · 80029818066118 · 100700481422006 · 132442670633809 | `ShopCatalog.PACK_ART` (Coins tab) |
| pack_backdrop | 88697341024977 | 111801042683623 | `ShopCatalog.PACK_BACKDROP` |
| banner_ruinblighted | 83121459082360 | 114348398658883 | RuinBlighted `banner` |
| banner_tempeststrike | 93782407729732 | 131808642557103 | TempestStrike `banner` |
| banner_starter | 115685547654856 | 96454339687407 | Starter `banner` + `ART.starterBanner` (Home's offer card) |
| ticket | 100513340169712 | 118693853905400 | `ART.ticket`: price plates (Ticket case tiles, case popup WITH TICKETS) and login reward cells |

- Titles, prices, hero renders and item tiles stay live UI on top. The cards' Studio `ImageColor3` tint (meant for the old grey placeholder) is cleared to white when real art is set, so the banners show their own colours.
- Home's offer card got a `Hero` ImageLabel (coin pile on the right of the Starter banner; `tools/studio/ShopOfferHero.luau`). **Save the Lobby place.**
- Prices, products, rewards and purchase rules unchanged.
- Checks: StyLua, Selene (0/0), `rojo build` pass. Studio play, desktop: [Home](Shop%20Economy/art_home.jpg), [Bundles](Shop%20Economy/art_bundles.jpg), [Starter](Shop%20Economy/art_starter.jpg), [Coins](Shop%20Economy/art_coins.jpg), [Daily login](Shop%20Economy/art_login.jpg), [case popup](Shop%20Economy/art_case_popup.jpg).
- **Not tested:** phone layout (no device emulation via MCP; banners use Crop, so narrow cards trim the sides of the scenery only), Ticket-priced case tiles on Home (only shown to restricted accounts; same `priceIcon` path as the popup's Ticket plate, which was seen).

## Shop fixes round 2 (2026-11-22)

- **Starter art.** Composited the existing case, coin pack and Ticket PNGs into [starter_contents.png](../../art-source/ui/shop/new/starter_contents.png), 1600 × 1000 RGBA. Approved by the owner, uploaded to group 11116787 as Decal `134519819682766`, and resolved in Studio to image `97381557374007`. The client uses that image on Home, Bundles, the Starter confirm, and the full Starter reward. The receipt's existing grant message drives the fallback presentation when cases are exchanged for coins.
- **Special Offers.** Starter → Ruin-Blighted → Tempest-Strike on the existing Studio card. Slides advance every six seconds, pause under the pointer, and can be selected by dots or touch swipe. The card opens the selected bundle's existing confirm or page. Launch and full Shop layouts use their existing release setting.
- **YOU GOT.** Daily login, daily skin and purchase confirmations share the Studio RewardPanel. The reveal adds a dim, whoosh, tier-coloured flash, rays, sparkles, coin count-up, sequential item art, and a Collect animation. Reduced motion keeps fades. Close, Collect and outside click all dismiss it.
- **Sounds selected.** Roblox UI Whoosh 02 `15675028888`, Roblox GUI Pickup `17208319162`, PSE Toggle Button 2 `9119717523`, APM Universal Flip - Hit `9042542887`, and Roblox GUI Select `17208396156`. Each has an alternate in `Config/UiSounds`. Timings, sizes and new cue volumes live in `Config/ShopFx`.
- **Studio QA, Lobby play.** Desktop auto-advance and hover pause, Dot3 selection and open to Tempest-Strike, Day 1 claim (+250 coins), free Faultline Stinger, test receipt `3734910773` (Ruin-Blighted, five item pictures), and test receipt `3734910889` (+500 coins). Checked dismissal with X, Collect and outside click. On iPhone 17 Pro landscape, inspected Home and the Tempest-Strike receipt `3734910786`, including six item pictures and label fit. These receipts used the Studio-only test hook and Studio player data.
- **Screenshots.** [Home on desktop](Shop%20Economy/round2_home_desktop.jpg) · [Tempest-Strike selected](Shop%20Economy/round2_home_tempest_desktop.jpg) · [Tempest-Strike bundle page](Shop%20Economy/round2_bundle_desktop.jpg) · [Daily login](Shop%20Economy/round2_login_desktop.jpg) · [free skin](Shop%20Economy/round2_free_skin_desktop.jpg) · [bundle receipt](Shop%20Economy/round2_receipt_bundle_desktop.jpg) · [coin receipt](Shop%20Economy/round2_receipt_coins_desktop.jpg) · [Home on phone](Shop%20Economy/round2_home_phone.jpg) · [six-item receipt on phone](Shop%20Economy/round2_receipt_phone.jpg).
- **Real-model art.** Studio's native PNG captures at 5760 × 2880 produced six square portraits (937–1024 px) and six 1024 px side icons. Spot-checked the full-size crops and transparent edges. [Contact sheet](Shop%20Economy/round2_real_model_contact.png) · [batch lists and commands](../../tools/render/Shop%20Art%20Round%202.md). Windows Computer Use stopped before the bulk run. No weapon Decals were uploaded and both live item-image ID maps still need the bulk pass.
- **Studio Edit audit.** The [verbatim baseline](Shop%20Economy/round2_audit_edit.txt) covered 225 skins, three active bundles and 20 lines. It found 65 missing side-icon entries and 10 missing Locker emblems. Every checked line had a `SkinArt.line` picture and every checked skin had a portrait. The Starter hero finding came before its upload. Emblems to review are Breakwater, Faultline, Misprint, Oilwake, Playback, Poolside, Rootglass, RuinBlighted, Sundial and TempestStrike. The Play client also exposed the three new Moltframe models for Judge, Phantom and Sheriff, included in the batch lists.
- **Pending verification.** The Starter card and Starter receipt with the new image, touch swipe direction measured independently of the timer, the full-layout toggle, reduced-motion playback, audio by ear, and the post-upload audit. Shop-only StyLua and Selene checks and the Rojo build passed. Whole-source StyLua reports an existing format diff in `BattlePassController`. Whole-source Selene reports an existing undefined `Content` in `PlayMenuController` and unused `probe` in `LoadingScreen`.
- **Studio handoff.** Clear the temporary `StarterGui._IconSheet`, restore the device simulator, sync the final Shop controller and catalog from Rojo, then save the Draft Duels place in Studio.

### Larger bundle artwork and HD inventory art (2026-11-22)

- Home uses a larger right-side hero for all three offers. The Starter card on Bundles has a taller case, coin and Ticket composition. The two featured Vandal pictures fill more of the left lane and have a slight upward tilt. Their item tiles stay in a separate grid with the price at the lower right.
- Ruin-Blighted has a broken arch emblem (Image `130399130528727`), and Tempest-Strike has a lightning emblem (Image `95165319256972`). Both are used by the Home and Bundles cards, bundle detail headers, and Locker. [Emblem preview](Shop%20Economy/bundle_emblems.png)
- Locker side icons are 1024 px wide for all five Ruin-Blighted bundle guns. Image IDs: Vandal `113939840386471`, Spectre `124957681903454`, Ghost `91257779594132`, Guardian `112331773283225`, Operator `93342554759044`. [Ruin-Blighted side artwork](Shop%20Economy/ruinblighted_locker_hd.png)
- The Daily cards still use `SkinArt.portrait`. All 228 eligible Shop roster keys now map to transparent, 832–1024 px square real-model renders. Reused the existing Studio pilot where available and rendered the other portraits from the repository’s Blender models. Roblox Open Cloud returned direct Image IDs. Paths with in-progress owner artwork retain those source PNGs, with the new render stored under an `_HD` suffix.
- Verified dimensions, transparency, upload IDs and local build without desktop or Studio control. The open place, mobile framing and in-game asset delivery still need a playtest after Rojo sync.

## Full Shop and Locker art audit (2026-11-22)

- The audited roster is 18 stock guns, 229 skins and 21 collection badges, using the Lobby and Match skin metadata plus the checked render lists. The offline audit reports zero findings for missing art and validates PNG dimensions and alpha. The Studio companion now walks the full Locker roster and the configured lines.
- Every audited look has a 1024 px side icon. This pass uploaded 242 of those icons, including all 17 Poolside guns and the Ruin-Blighted melee model from the Match roster. The five already upgraded Ruin-Blighted gun icons stayed in the map. The Locker uses the shared side-image lookup, so the PopCircuit Knife finds the Bat art. The 228 existing Shop portraits were retained and the Ruin-Blighted melee portrait was added.
- Added Breakwater, Faultline, Misprint, Oilwake, Playback, Poolside, Rootglass and Sundial badges. The existing Slipframe asset was retained. [New badges](Shop%20Economy/full_audit_new_badges.png)
- Ruin-Blighted and Tempest-Strike use new 1600 px transparent real-model heroes, images `122434274434504` and `78378943251206`. [Hero artwork](Shop%20Economy/full_audit_vandal_heroes.png)
- Home preloads offer art, advances after four seconds on opening, and uses six seconds between subsequent slides. Pointer movement over the card arms the hover pause. The outgoing banner fades under the incoming one.
- Backpack exposes OPEN 1 and OPEN 3 for a stack with at least three. The server consumes the requested quantity in a single write, gives distinct skins, and returns Tickets for exhausted case pools. The client plays one crate animation and pages through the three-case results using the existing reward panel. Shop purchase prices and throttling were retained.
- Verified the offline art audit, Rojo build, targeted formatting and lint, and local harnesses for case grants and carousel lifecycle. Studio and mobile visuals, Roblox client asset delivery, and the integrated Backpack interaction still need playtesting after Rojo sync.

### Ruined Reaver in the Ruin-Blighted bundle (2026-11-22)

Ruined Reaver is the sixth item in the 999 Robux Ruin-Blighted bundle. The Shop card lists five guns plus Ruined Reaver, and uses the existing knife portrait on the sixth tile and in the reward reveal. A new bundle receipt grants `Knife/RuinBlighted` through the same catalog-driven receipt path as the five guns. The existing individual Knife price applies. Receipt history stores transaction IDs, so this catalog edit does not backfill old purchases.

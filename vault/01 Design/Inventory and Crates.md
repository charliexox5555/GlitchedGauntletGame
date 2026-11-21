# Inventory and Crates

Owner's brief (2026-11-20): build an inventory to hold cases and other loot (reference: a "Backpack" grid of stacked items with ×counts), save it in the player data, design and model **3 crate tiers** in Blender (mostly a colour change between tiers), and let players **buy a crate and have it land in their inventory**. **Not in scope:** opening cases (no rolls, no reveal).

Owner on the current case art (`art-source/ui/shop/case_*.png`): **too flat, needs more to it.** The 3D crates replace it, and the Shop icons get re-rendered from the models.

## Phases
1. ✅ **Player data and inventory** (2026-11-20): wallet + item stacks in their own DataStore, atomic writes.
2. ✅ **Buying a case for coins** (2026-11-20): the Shop's case popup BUY (Coins) works end to end.
3. ⏳ **Crate design:** owner runs the ChatGPT prompts below and picks a shape → model sheet.
4. ⬜ **Crate models** in Blender MCP (`gauntlet-build-style`, `roblox-blender-modeling`): one mesh, tiers as colourways; import; Shop icons rendered from them.
5. ⬜ **Backpack screen** (the reference grid): a lobby menu that reads the published inventory. Mocked up in Studio first for the owner to edit.
6. ⬜ **Robux purchases** (BUY / BUY x3 Robux, coin packs): developer products + `ProcessReceipt` on the same atomic write, keyed by `PurchaseId`. Needs product ids from the Creator Dashboard (owner).
7. Parked: earning coins from matches (written by the match place to the same store), case opening.

## How it works (built)
| Piece | Where | What |
|---|---|---|
| Item list + wallet numbers | `src/shared/Config/Inventory.luau` | `ITEMS` (id, kind, name, tier, case, maxStack, retired), `BY_CASE` (Shop case → item), `STARTING_COINS` 2500 (placeholder until coins are earned), `MAX_COINS`, `STUDIO_GRANT` 1000, `TX_MEMORY` 25 |
| Save shape + read helpers | `src/shared/PlayerData.luau` | DataStore `PlayerDataV1` (**`PlayerDataV1_Studio` in Studio**, so test coins never reach a live save), key `u_<userId>`: `{ v = 1, coins, items = { [itemId] = count }, tx = { purchaseId } }`; `clean()` repairs any stored value; `publish()` / `coins()` / `items()` / `ready()` / `replica()` |
| Saving | `src/lobby/server/Services/PlayerDataService.luau` | `transact(player, txId, change)`: **one `UpdateAsync` per change**, reading the stored value fresh, so nothing is cached and saved later (no lost purchases across teleports or servers, no session lock needed). The `tx` list makes a retried write apply once. One change per player at a time ("busy"). |
| Buying | `src/lobby/server/Services/ShopService.luau` | `ShopRequest ("buyCase", caseId)`: price from `ShopCatalog`, PolicyService paid-random-items gate (fail closed), coins check and +1 item inside the write. `("devCoins")` Studio only. Answers on `ShopEvent`. |
| Client | `ShopController` | BUY (Coins) sends the request (client checks only to say why); Robux buttons say "coming"; in Studio the COINS tab packs grant test coins; results are toasts; the top coin counter shows the real balance. |

Published on the player for both places to read: `StateValues` **Coins** and **DataReady**, StringValue **Inventory** (JSON `{ [itemId] = count }`).

Coins are separate from the Locker save (`LockerV1`), which is unchanged.

LihFolk notes used: `04 Data and Persistence/DataStore Fundamentals`, `Data Loss Prevention and Recovery`, `Trading Systems Without Duplication` (single-key atomic write, provenance), `Purchase Data and Receipts` (idempotent grants), `Session Locking and Profile Libraries` (why the per-change write avoids needing one); `22 Anti-Exploit and Security` via `roblox-secure-remotes`.

### Tested (2026-11-20, Lobby place, Studio play, real DataStore)
- New save starts at 2500. Standard bought: 2500 → 2100, `CaseStandard` ×1. Apex: → 100, `CaseApex` ×1.
- Elite with 100 coins: refused, "Not enough coins", nothing written.
- Studio grant ×2: +1000 each.
- Double click (two buys at once): one bought, one "Still finishing your last purchase".
- Bad input (`"Nope"` case, a number as the action): rejected, nothing sent back.
- The stored key (read with a no-write `UpdateAsync`) matched the client: 1700 coins, Standard ×2, Apex ×1, 5 purchase ids.
- That first run wrote to the live store `PlayerDataV1` (the Studio store came with the review): the owner's account holds 1,700 coins, Standard ×2, Apex ×1 there. Harmless while coins are placeholders; wipe it before launch.

### Security review (roblox-reviewer, 2026-11-20) and fixes
Nothing critical or high: no exploit path to coins or items, no duplication, re-run and retry handling correct. Fixed:
- **Older servers could delete newer data** (Medium): writes now keep unknown item ids and fields (`clean(raw, true)`; the client only sees known items), and a save written by a newer `v` is refused ("rejoin to keep buying").
- **Refused buys still cost a DataStore request** (Medium): the server refuses from the loaded copy first (coins, full stack), `ShopRequest` slowed to `{ 0.5, 3 }`, plus a `ShopWrite` cap of about 10 writes a minute per player.
- Studio test coins go to their own store.
- A failed write no longer shows its unsaved result; an unclear failure reads the save back and reports success if the purchase id landed (no accidental second purchase).
- A failed load retries with backoff instead of locking the Shop for the session.
- A change that leaves bad numbers is refused (`PlayerData.valid`), never saved clamped.
- For later: the match place must award coins through the same UpdateAsync-with-purchase-id path, never GetAsync + SetAsync.

Re-test after the fixes (Studio store, fresh save): 2,500 → Apex → 500 → Elite refused (no write) → +1,000 → Elite → 600 → Standard → 200. An unknown item (`KeyFuture` ×3) and an unknown field survived a purchase and stayed hidden from the client; with `v = 2` stored, a grant was refused with "The game updated, rejoin to keep buying". Test save restored afterwards.

### What to test (owner)
- [ ] Open the Shop, click a case, BUY with coins: toast "STANDARD CASE added to your Backpack", the top counter drops.
- [ ] Try a case you can't afford: "Not enough coins".
- [ ] In Studio, click a coin pack on the COINS tab: +1000.
- [ ] Rejoin: coins and cases are still there.

## Crate design: ChatGPT prompts (paste in order)
Same three tiers and colours as the Shop already uses: **Standard** slate grey + cyan, **Elite** deep violet + gold, **Apex** black + red-orange with a faceted gem. The models are built from the sheet, so the sheet must show real shapes, not a painting.

**Prompt 1: shape options (pick one)**
> Design a loot crate for a stylised Roblox arena shooter. Show **3 different shape concepts side by side** on a plain dark grey background, all in the same colours: slate grey body, darker gunmetal frame, a small cyan light accent. Each crate is about 1.5 wide, 1 deep and 1 tall, sturdy and heavy, like a military supply crate crossed with a high-tech weapon case.
> The old version was too flat, so these need **real depth and layers**: a main body with **recessed side panels**; a separate **thick outer frame or corner guards** standing proud of the body; a **lid that is its own piece** with a raised centre plate and a bold geometric tier emblem (no letters); chunky **latches and hinges**; **carry handles** on the sides made of angled bars; a **lit window strip or vent slots** where the accent colour glows from inside; small bolts; **feet or skids** underneath so it sits off the floor. Every face should have at least three levels of depth.
> Strict shape rules: **no round curves and no spheres anywhere**: any curve is made of flat angled facets. **No blunt cut-off ends**: every edge and end is chamfered or cut at an angle. Chunky and blocky in spirit, between realistic and blocky, never pixel or voxel. Clean stylised shading like a modern stylised shooter: flat colours with soft light, a little edge highlight, **no photoreal textures, no grunge, no scratches, no glow bloom, no text or logos**. Same 3/4 front view and the same size for all three.

**Prompt 2: model sheet of the picked shape (say which one)**
> Take concept [1 / 2 / 3] and make a **model sheet** for a 3D modeller, on a plain dark grey background with no text: **front, side, back, top and 3/4 views** in the same scale, orthographic for front, side, back and top, lined up with each other. Keep every detail from the concept and show clearly how the pieces stack (body, frame or corner guards, lid, latches, handles, window strip, feet). Same rules as before: no round curves or spheres, chamfered or angled ends, clean stylised flat shading, no text.

**Prompt 3: the three tiers**
> Using the exact same crate model, make a **tier colour sheet**: the crate three times in the same 3/4 view and size. Colour roles stay the same on all three; only the colours change:
> - **Standard:** slate grey body, gunmetal frame, steel hardware, **cyan** light strip and emblem.
> - **Elite:** deep violet body, dark plum frame, **gold** hardware, gold light strip and emblem.
> - **Apex:** near-black body, dark graphite frame, gunmetal hardware, **hot red-orange** light strip, and the emblem becomes a **faceted red gem** set into the lid.
> Each tier should feel more valuable than the last through colour and the light strip only, not new shapes. Plain dark grey background, no text.

Save the results into `art-source/ui/shop/crates/` (`crate_concepts.png`, `crate_sheet.png`, `crate_tiers.png`) and point me at them.

## Changelog
- 2026-11-20: created. Phases 1 and 2 built and tested; crate prompts written.

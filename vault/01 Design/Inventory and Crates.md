# Inventory and Crates

Owner's brief (2026-11-20): build an inventory to hold cases and other loot (reference: a "Backpack" grid of stacked items with ×counts), save it in the player data, design and model **3 crate tiers** in Blender (mostly a colour change between tiers), and let players **buy a crate and have it land in their inventory**. **Not in scope:** opening cases (no rolls, no reveal).

Owner on the current case art (`art-source/ui/shop/case_*.png`): **too flat, needs more to it.** The 3D crates replace it, and the Shop icons get re-rendered from the models.

## Selected weapon case concept (2026-11-20)

The owner selected **the far-left case from the elongated rifle-case comparison**, favouring its clean geometry and shapes. The initial tall crate concepts were too chest-like; the approved direction is a long, shallow weapon transport case with two wraparound protective rails, recessed panels, separate raised lid plate, polygonal handles, chunky latches, small cyan window and low skids.

- [Five-view model sheet](../../art-source/ui/shop/crates/crate_sheet.png): top, front, back, short side and three-quarter views generated as a modelling reference. This is concept art, not a measured CAD drawing; reconcile view differences during modelling.
- [Selected concept comparison](https://chatgpt.com/library?file_id=libfile_b2bc2a87ae588191bdeffec16ee58cb9&account_id=personal): the original image remains available here. Copying it to `art-source/ui/shop/crates/crate_concepts.png` failed because the download host could not be resolved; no local concept file was created.
- [Tier colour sheet](../../art-source/ui/shop/crates/crate_tiers.png): the selected rifle case in Standard (slate grey / gunmetal / steel / cyan), Elite (deep violet / dark plum / gold) and Apex (near-black / graphite / gunmetal / red-orange, faceted red lid gem). Generated 2026-11-20. Shared construction and colour roles retained; no Blender models or Studio assets changed.

## Phases
1. ✅ **Player data and inventory** (2026-11-20): wallet + item stacks in their own DataStore, atomic writes.
2. ✅ **Buying a case for coins** (2026-11-20): the Shop's case popup BUY (Coins) works end to end.
3. ✅ **Crate design** (2026-11-20): concept, model sheet and tier sheet picked (section above).
4. ✅ **Crate model** (2026-11-20): built in Blender, rigged in Studio for animation, three tiers as colour data, tier icons rendered. See "Crate model" below.
5. ✅ **Backpack screen** (2026-11-20): bottom-bar BACKPACK (replaces the Battle Pass for the first release) opens a grid of stacks. Built in Studio for the owner to edit. See "Backpack" below.
5b. ✅ **Backpack icon** (2026-11-20): the owner's ChatGPT icon (`art-source/ui/lobby-icons/backpack_v2.png`), uploaded full-bleed 400 px (`backpack_v2_bar.png`) like the other bar icons; bar, phone dock and Backpack header.
5c. ✅ **Shop case art** (2026-11-20): renders, never ViewportFrames (owner: "that's not what Rivals does"). See "Shop art and denied feedback" below.
5d. ✅ **Not enough coins** feedback (2026-11-20). ⏳ Owner picks the sound on F4.
6. ⏸ **Robux purchases** (parked by the owner 2026-11-20: more Shop content first) (BUY / BUY x3 Robux, coin packs): developer products + `ProcessReceipt` on the same atomic write, keyed by `PurchaseId`. Needs product ids from the Creator Dashboard (owner).
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

## Crate model (built 2026-11-20)
- **Source:** `tools/blender/crates/build_crate.py` (re-runnable in live Blender MCP through `tools/blender/lobby_v4/send.py --port <port> --pid <pid>`), file `art-source/lobby/crates/Crate.blend`, previews `art-source/lobby/crates/preview/`, data `Crate.json` (part bounds, pivots).
- **Size:** 3.1 x 1.2 x 1.1 studs, 13 parts, 5,720 tris. Owner (2026-11-20): "a bit too long, compact it": shortened from 3.9 to 3.1, depth and height kept.
- **Style check:** faceted only (flat 1-segment chamfers, 6/8-sided bars, cut ends), flat shading, no modifiers or subdivision; the latch keepers stand proud of the panel frame (no coplanar faces).
- **Built for animation:** hollow base tray and hollow lid with dark `Interior` liners; parts split by moving group (`Base`, `Lid`, `Gem`, `LatchL`, `LatchR`, `Handle`) and colour role (`Body`, `Frame`, `Hardware`, `Light`, `Gem`, `Interior`).
- **Roblox:** asset 134857131915909 (`art-source/lobby/Exports/assets.json` "Crate"), rigged by `tools/studio/BuildCrate.luau` into `ReplicatedStorage.Crates.Crate` (Lobby place, Studio-owned: **save the place**). Motor6D tree Root → Base → Lid → Gem, Base → LatchL / LatchR / Handle; AnimationController + Animator, so the Animation Editor and code can drive it. Attachments for effects: `Base_Body.Burst` (inside), `Base_Body.Seam` (front of the lid seam), `Base_Light.Glow`, `Gem_Gem.GemFx`. **In Roblox the open direction is a positive X angle** (Lid +105 deg, latches +130, handle +45; checked in play). Axes: Roblox (x, y, z) = Blender (-x, z, y), front = -Z.
- **Tiers:** `src/shared/Config/Crates.luau` (role colours and materials per tier: Standard grey/cyan, Elite violet/gold, Apex black/red-orange); `src/shared/CrateLook.luau` `make(tier)`, `paint`, `joint`.
- **Icons:** `tools/blender/crates/render_icons.py` → `art-source/ui/backpack/crate_<tier>.png` (512 transparent; sheet `crate_icons_sheet.png`), images Standard 106773240441152, Elite 81160532398415, Apex 129794608887439 in `Config/Inventory` `icon`.

## Knife case: its own model (owner 2026-11-20, in design)

**Concept comparison generated (2026-11-20):** [Three knife-case shapes](../../art-source/ui/shop/crates/knife_case_concepts.png), left to right: A slim tactical case, B angled presentation lid, C tapered blade-echo outline. Shared dark-green body / darker-green frame / bright-steel hardware / green strip and gem, two front latches, one polygonal carry handle and low feet. **Owner selected A**, the slim tactical case. [Six-view model sheet](../../art-source/ui/shop/crates/knife_case_sheet.png) generated: orthographic front / short side / back / top, closed three-quarter, and open three-quarter with a dark foam tray and one empty knife-shaped cutout. The rear hinge, split guard rails, two front latches, handle and lid gem are shown as separate mechanical pieces. These are visual modelling references; reconcile any view differences when building.

**Built (2026-11-20).** `tools/blender/crates/build_knife_case.py` (reuses `build_crate.py`'s faceted helpers; background Blender is fine, it writes its own `art-source/lobby/crates/KnifeCase.blend` + `KnifeCase.json`): 1.64 x 0.67 x 0.77 studs, 13 parts, 5,140 tris, faceted only. From sheet A: straps with bolts wrapping base and lid, back hinges on the straps, two front latches with the handle between them, the strip light under the seam, a notched lid plate with the diamond gem mount, end panels, low feet under the straps, a foam tray with a knife cutout. Same part names, groups and pivot rules as the big crate. Env switches: `KNIFE_PREVIEW=<dir>` (six views incl. open), `KNIFE_EXPORT=1` (FBX), `KNIFE_ART=1` (UI renders).
- **Roblox:** asset 134286984339849 (`art-source/lobby/Exports/assets.json` "KnifeCase"); `tools/studio/BuildCrate.luau` now takes `WHICH = "Crate" | "KnifeCase"` (asset, pivots, burst and seam points per target) and built `ReplicatedStorage.Crates.KnifeCase` (Studio-owned: **save the Lobby place**).
- **Opening:** `Config/Crates` tier 4 has `template = "KnifeCase"` and `scale = 2.0` (3.3 studs in the world; the big crate opens at 5); `CrateLook.template(tier)` / `CrateLook.scale(tier)` pick them, falling back to the big crate if the template is missing; `Util/CaseOpening` scales every offset by that.
- **Pictures:** the crate's views and lights scaled to this size, tier-4 colours: card image 111410900647363 (Shop card + Backpack icon), wide 75937518028942 (popup). Studio Shop card updated.
- **Tested (Lobby play):** bought and opened from the Backpack; the knife case landed, opened (lid, latches, handle) and a Prism Knife (Common) rose with its card; no errors.

Owner: the Knife case shouldn't be the big crate recoloured; make a new case that's **shorter, smaller and more like for knives**, not the same model. Until it landed, the Knife case used the big crate painted tier 4 (dark green, bright steel, a green glow; `Config/Crates` [4]); built now (below).

**Constraints for the new model** (so the opening code keeps working): same moving parts as the big crate (`Base`, `Lid` hinged at the back, `LatchL` / `LatchR` on the front, `Handle`, `Gem` emblem on the lid) and the same colour roles (`Body`, `Frame`, `Hardware`, `Light`, `Gem`, `Interior`); hollow base and lid with a dark liner. About **1.6 x 0.7 x 0.45 studs** before the opening's scale (the big crate is 3.1 x 1.2 x 1.1), so it reads as the little sibling. Faceted only, no curves, carved ends (`gauntlet-build-style`). It will need its own opening scale and a lid angle in `Config/CaseOpening` and its own `Crates` template.

**Prompt 1: three shape options (attach `crate_apex_card.png` so it matches the family)**
> I'm attaching our current loot crate for a stylised Roblox arena shooter. Design its **little sibling: a knife case** that holds one knife. Show **3 different shape concepts side by side** on a plain dark grey background, same 3/4 front view and the same size for all three. It must be clearly **smaller, shorter and slimmer** than the crate: about 1.6 long, 0.7 deep and 0.45 tall (roughly half the crate's length and under half its height).
> Ideas to spread across the three: (A) a **slim tactical blade case**, low and flat, like a hard case for a combat knife; (B) a **faceted presentation box** with a raised, angled lid like a premium knife box; (C) a **tapered outline that echoes a blade**, wider at the handle end and narrowing toward the tip.
> Every concept keeps the crate's family details: **a lid that's its own piece, hinged at the back**, **two chunky latches on the front**, **one carry handle**, **corner guards** standing proud of the body, **a small faceted gem or emblem on the lid** (no letters), **a thin lit strip** where the accent colour glows, small bolts, low feet. Real depth: at least three levels on every face.
> Colours: **dark green body, darker green frame, bright steel hardware, a small green light accent and gem**.
> Strict shape rules: **no round curves and no spheres anywhere**: any curve is made of flat angled facets. **No blunt cut-off ends**: every edge and end is chamfered or cut at an angle. Chunky and blocky in spirit, between realistic and blocky, never pixel or voxel. Clean stylised shading: flat colours with soft light and a little edge highlight. **No photoreal textures, no grunge, no scratches, no glow bloom, no text or logos.**

**Prompt 2: model sheet of the picked shape (say which one)**
> Take concept [A / B / C] and make a **model sheet** for a 3D modeller, on a plain dark grey background with no text: **front, side, back and top views** (orthographic, same scale, lined up), a **3/4 view closed**, and a **3/4 view with the lid open** showing the inside: a dark foam tray with an empty knife-shaped cutout. Show clearly how the pieces stack (body, frame or corner guards, lid, hinge, latches, handle, gem, light strip, feet). Same rules: no round curves or spheres, chamfered or angled ends, clean stylised flat shading, no text.

Save them as `art-source/ui/shop/crates/knife_case_concepts.png` and `knife_case_sheet.png`. Next: build it in Blender (live MCP) from the sheet, faceted, with the same part names → upload → `BuildCrate`-style rig as `ReplicatedStorage.Crates.KnifeCase` → the opening picks the template by tier → new renders for the Shop card, popup and Backpack.

## Backpack (built 2026-11-20)
- **Bar:** `StarterGui.LobbyBar.Bottom.Backpack` (was BattlePass), label BACKPACK, orange accent `FF8F3D`; the phone dock tile, menu map and intro order follow (`LobbyHud`, `LobbyHudView`, `Icons`, backup `tools/studio/BuildLobbyHud.luau`). The Battle Pass screen still exists and the Shop's Season Pass card still opens it.
- **Screen:** `StarterGui.Backpack` + `UiTemplates.Lobby.BackpackCell` (builder `tools/studio/BuildBackpack.luau`), `Controllers/BackpackController`. After the owner's RIVALS reference: a header plate (icon, BACKPACK, one line), a 6-wide grid of stacks (crate art, big ×count), at least three rows with dark empty slots, the hovered stack's name under the grid, "OPENING CASES COMES IN A LATER UPDATE.", and a gold OPEN SHOP when empty. Live: a purchase updates it while open. Read only, no remotes.
- Playtested: bought cases show as Standard ×1, Elite ×2, Apex ×1; hover pops and names the stack; the bar button opens it.

### Backpack icon: ChatGPT prompt
> Make a game menu icon for a stylised Roblox shooter, in the exact style of our lobby bar icons (chunky, faceted, flat-shaded 3D, bright colour, clean soft lighting, no outline, no text, no glow), matching the attached locker, shop bag, range target and settings gear icons: a **tactical backpack** built from angled flat facets (no round curves; any curve is made of flat planes), chunky and readable at small size. A boxy main pack with a chamfered top flap, one big front pocket with a buckle strap, two side compression straps, a carry loop on top and a small bedroll or pouch on the side. Main colour **warm orange (#FF8F3D)** with darker orange-brown shadow facets, straps in dark charcoal, buckles in light steel. 3/4 front view, slightly from above, centred, filling most of the square. Output: `backpack.png`, 512x512, transparent background, plus a version on dark grey to check it.

Save it as `art-source/ui/lobby-icons/backpack_v2.png` (the other bar icons are in that folder) and tell me; I'll upload it and swap it into the bar, the phone dock and the Backpack header.

### What to test (owner, Backpack and crates)
- [ ] The bottom bar reads LOCKER · SHOP · BACKPACK · RANGE · SETTINGS; BACKPACK opens the screen, the X and Esc close it.
- [ ] Buy a case in the Shop with the Backpack closed, open it: the stack is there with the right count.
- [ ] Empty save (a new account): NOTHING HERE YET and OPEN SHOP, which opens the Shop.
- [ ] `ReplicatedStorage.Crates.Crate`: open it in the Animation Editor; the lid, latches, handle and gem joints move.
- [ ] **Save the Lobby place** (the crate template, the Backpack screen and the bar change live in the place).

## Shop art and denied feedback (2026-11-20)
- **Renders per slot shape** (memory `ui-item-art-renders`): `tools/blender/crates/render_cards.py` renders an end-on, higher view (aspect about 1:1) for the tall Home case cards and the square Backpack cells (`crate_<tier>_card.png`; images Standard 133624978874225, Elite 103320622297328, Apex 93123564652737 in `Config/Inventory.icon` and the cards' `CaseArt`). The wide 3/4 view (`crate_<tier>_wide.png`; 122735078835784 / 120685505151159 / 87218064940726) is `ShopCatalog.art`, used by the case popup and the Season Pass. The first try put the wide render on the cards and it spilled past the 140 px cards.
- **Denied:** `Config/UiSounds.PurchaseDenied` = Roblox "GUI - Negative" (0.17) over a quiet PSE "Thuddy buzzy A" (0.07). Plays on a local not-enough-coins check and on any refusal from the server; the pressed BUY button nudges (`UiMotion.nudge`, skipped with reduced motion) and the top coin count holds red for 0.35 s, then eases back. Candidates on the F4 board, SHARED → PURCHASE DENIED (6 options incl. Delete + buzz). A successful buy plays `Confirm`.
- **Toasts over menus:** `StarterGui.LobbyToast.DisplayOrder` 25 → 35 (menus are 30, MATCH FOUND 40); before this, "NOT ENOUGH COINS" was hidden behind the Shop popup's dim.
- Playtested: cards and popup show the crates; BUY with 300 coins on the 400 Standard case gives the sound (both layers played), the nudge, the red count and a visible toast; the Backpack shows the end-on crates filling the cells.
- Still flat: the Starter Bundle banner art (a baked ChatGPT banner with the old case).

## Changelog
- 2026-11-20: created. Phases 1 and 2 built and tested; crate prompts written.
- 2026-11-20 (evening): Shop case art = crate renders, backpack icon in, denied sound + nudge + red count, toasts over menus; Robux parked.
- 2026-11-20 (later): crate model built, compacted, rigged and tiered; tier icons; Backpack screen replaces the Battle Pass on the bar; backpack icon prompt.

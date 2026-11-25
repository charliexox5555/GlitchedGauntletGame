# Skin Tiers and Cases

Owner's brief (2026-11-20): cases grant **gun skins**. Remove "everyone has every skin"; skins are **owned per gun**. Tiers from reskins up to bundle-only exclusives; cases reflect the tiers. "Categorize them how you want right now, but we'll go over them later" → **everything below is provisional** until the owner's review.

Related: [Inventory and Crates](Inventory%20and%20Crates.md) (wallet, cases, Backpack), [UI Shop](../02%20Art/UI%20Shop.md) (paid random items rules).

## Tiers (lowest → highest)
| Tier | What it is (owner's words) | Colour | In cases |
|---|---|---|---|
| **Common** | reskins: new colours / textures on the stock gun | grey `B8B8BB` | yes |
| **Rare** | "a change in shape, similar to Rootglass or Sealwork", looks good, no custom animation | blue `3FA9FF` | yes |
| **Epic** | the tier above shape changes, "some animations" | violet `B58CFF` | yes |
| **Legendary** | "similar to exclusives, but you can unlock them in cases": animations, custom sounds | gold `FFC83D` | yes (none built yet) |
| **Exclusive** | only in Robux bundles, never in cases (Ruin-Blighted) | rose `FF4D8D` | **no** |

A skin is one gun in one line (a "pair"). A line has a tier; single guns can be lifted (the line's animated melee).

**Knives sit higher** (owner 2026-11-20): a knife reskin is at least **Rare**, a knife that changes shape (or animates) at least **Epic** (`Config/Skins.KNIFE_MIN`, applied in `SkinCases.tierOf`). Today: Prism and Redline knives Rare; Breakwater, Giltfold, Inkshift, Moltframe, Playback, PopCircuit (Bat), Rootglass, Sealwork and Sundial knives Epic. So the Standard case has no knives (136 skins in 8 lines, 12.5 % each).

### Lines, provisional (from the skin build ledgers, vault-lookup 2026-11-20)
| Line | Tier | Why |
|---|---|---|
| Prism, Redline, Nitrous, Oilwake, Misprint, Faultline, Poolside | Common | reskins on stock geometry |
| PopCircuit | Common (Bat: **Epic**) | gun reskin; the Bat has its own rig, 5 actions, a light trail |
| Rootglass | Rare (Leafblade: **Epic**) | structural shell; animated Leafblade inspect |
| Giltfold | Rare (Fan: **Epic**) | origami shell; the Fan opens, shuts and pulses |
| Sealwork, Inkshift, Payload, Moltframe, Breakwater | Rare | new shells / added hardware, stock motion. Moltframe → Legendary once its chamber flow ships |
| Playback, Sundial | Epic | reel window / turning dial, animated inspects |
| RuinBlighted | Exclusive | Shadow Mist rig, heavy custom animation, owner WAVs; bundle only (not in the Lobby yet) |
| (none yet) | Legendary | nothing built at this bar |

Open questions for the owner: tier names; Moltframe; Poolside and Rootglass were Battle Pass cosmetics (the pass is out of the first release, so they're in cases for now); whether reskins with an added part (Breakwater, Sundial) sit where they are.

## Cases (round 5, 2026-11-20: tier first, a Knife case; built)
The owner approved Claude's proposal ("Yes, build it"). Before this (round 3), tiers only decided what was *in* a case and every line in a section had the same chance, so a Common reskin dropped as often as an Epic.

**The roll** (`Config/Skins.CASES`, `Shared/SkinCases.roll`): a **section** by its chance (gun skins / knife skins), then a **tier** by its chance, then a **line** (every line in the tier the same chance, keeping "Playback = Giltfold"), then a **gun** in the line, each among what you don't own yet. A tier or section with nothing left drops out and the rest scale up. No duplicates; a case with nothing left can't be bought, and an opening that finds nothing refunds (unchanged).

| Case | Sections | Common | Rare | Epic | Legendary | Each line / knife today |
|---|---|---|---|---|---|---|
| Standard (400) | guns | 85 % | 15 % | — | — | Common 10.6 %, Rare 2.1 % |
| Elite (900) | guns | 50 % | 40 % | 10 % | — | Common 6.3 %, Rare 5.7 %, Epic 5 % |
| Apex (2,000) | guns 97 %, knives 3 % | — | 65 % | 30 % | 5 % | no Legendary line yet, so it drops out: guns Rare 66.4 % (9.5 % per line), Epic 30.6 % (15.3 %); knives Rare 2.1 %, Epic 0.9 % |
| **Knife (2,500)** | knives | 50 % | 35 % | 15 % | later | Common 25 % each (2), Rare 8.75 % each (4), Epic 3 % each (5) |

- **Apex has no Commons** (owner's idea): a 2,000-coin case never gives a reskin the 400 case gives. Apex keeps a 3 % knife slot, so a knife can still drop from a gun case.
- **Knife case** (`Inventory.CaseKnife`, crate tier 4, `ShopCatalog` id `Knife`, 2,500 coins, Robux 499 / 1,249 as "soon" placeholders): knives only. Crate look: dark green with bright steel and a green glow (`Config/Crates` tier 4, `render_icons.py` "knife"); pictures `crate_knife_card.png` (image 140470533134784, the Shop card and Backpack icon) and `crate_knife_wide.png` (99120082357595, the case popup). The Shop's Home row now holds four cases (cards cloned in Studio, `BuildShop.luau` matches; the Season Pass card narrowed to 568).
- **CONTENTS:** section (chance, "a tier is rolled first, then a skin line / knife in it") → tier rows (name in its colour, chance, "N skin lines · each the same chance") → line rows as before.
- **Round 6 (owner): knives use their line's tier like any gun.** The old knife floor (reskin = Rare, shape = Epic) is gone because knives have their own case now; the animated knives keep their per-gun Epic (the Bat, Leafblade, the fan). Knives today: Common Prism, Redline; Rare Breakwater, Inkshift, Moltframe, Sealwork; Epic Giltfold, Playback, PopCircuit (Bat), Rootglass, Sundial. So the Knife case got a Common tier (50 / 35 / 15; 20,000 rolls matched), and Apex's 3 % knife slot only holds Rare and Epic knives. The new Knife case model is in design ([Inventory and Crates](Inventory%20and%20Crates.md) → Knife case).
- **Tested (Lobby play):** every case's odds add to 100 %; 20,000 Apex rolls matched (guns Rare 66.0 / Epic 30.9, knives 3.0); Shop row, Knife popup and CONTENTS captured; a Knife case bought (2,500), opened from the Backpack (tier-4 crate in the world), case used, knife granted, no errors.
- Open for the owner: which line sits in which tier (still provisional), the exact percentages, the Knife price.

**CONTENTS (round 4):** pictures centred with a modest spill up-left (1.3x the tile); clicking a picture pops a card out **next to it with a pointer** (Back Out 0.22 s from 0.82), and a click anywhere else closes it. Before that: each section with its chance ("EVERY SKIN IN HERE HAS THE SAME CHANCE"), then one row per skin line (its Vandal's picture, combined odds, opens to each gun with its own odds); knives one row each. Pictures are the new **portraits** (below) spilling over their tier square like RIVALS' tiles; **click a picture** for a short card (picture on its tier tile, name, "RARE SKIN · GIVEN TO THE VANDAL" / "GIVEN TO A RANDOM GUN (17)", what the tier means).

**Portraits (owner: the side-on renders "don't look good"; RIVALS' are diagonal and fill the tile):** `tools/studio/RenderPortraits.luau` renders every case skin with the muzzle up-left, a front three-quarter perspective view and more contrast, 5 x 3 per sheet; `tools/render/icon_sheet.py --cols 5 --rows 3 --centered` cuts them (alpha from black / white captures) into `art-source/ui/item-portraits/` (sheet lists in `tools/render/portrait-lists/`); uploaded ids in `Shared/ItemPortraits`; `Shared/SkinArt.portrait` picks the portrait, else the side-on picture. The side-on `ItemIcons` stay for the Locker's wide gun cards (56 missing side-on pictures were rendered to `art-source/ui/item-icons/` but not uploaded).

## How it works (built 2026-11-20)
- **Ownership:** `Shared/PlayerData` save field `skins = { [gunId] = { line } }` (Stock always owned, never stored), published as the JSON StringValue `Skins`. Everyone starts with **no skins** (the owner's wipe).
- **Lobby Locker:** lists only owned lines (`LockerController.ownedLines`); `LockerService` refuses unowned equips (`notOwned`) and publishes `LockerSkins` filtered to owned pairs, re-filtering when skins load or are granted (`PlayerDataService.changed`). Old saves that equipped any skin show Stock.
- **Match:** `SkinPreviewService` reads `LockerV1` **and** the owned skins (read only) and publishes only owned pairs; a failed ownership read = all Stock. The **F7 skin preview** is Studio-only now (`Config/SkinPreview.USER_IDS` for live testers; empty = nobody).
- **Opening:** Backpack → pick a case → OPEN CASE → `ShopRequest("openCase", itemId)`. `ShopService` checks the case, the PolicyService gate and the write limit, then one atomic `PlayerDataService.transact`: re-checks the count, rolls with `Shared/SkinCases.roll` on the **stored** owned list with a **seed fixed for this purchase**, removes the case, grants the skin. `ShopEvent {kind = "opened", gun, line, tier, text}` → the reveal panel (picture or emblem, name in the tier colour, tier tag, EQUIP / NICE). EQUIP sends the normal `LockerRequest`.
- **CONTENTS (2026-11-23):** Shop, Backpack and Season Pass show the next opening's personalized odds from `SkinCases` and the player's saved ownership replica. Owned weapon-skin pairs stay visible at 0%. The server roll and the odds display use the same eligible groups. A line splits its chance among its unowned weapons, and fully owned lines, tiers and sections drop out of their respective draws. If the entire case is exhausted, all skin odds are 0% and the panel explains the Ticket refund. OPEN 3 updates ownership before rolling each subsequent crate. Owner playtest pending.
- **Studio:** `ShopRequest("devSkins")` owns every skin (Locker testing); Studio saves go to `PlayerDataV1_Studio`.
- **Data:** `src/shared/Config/Skins.luau` (tiers, lines, case odds), `src/shared/SkinCases.luau` (pool, contents, roll, names).

## Tested (2026-11-20, Lobby place, Studio play)
- Start: no owned skins; the old equips (Bulldog, Outlaw, Stinger) published as Stock.
- `equip Vandal Prism` (unowned): refused, nothing changed.
- Opening Standard: **Misprint Vandal (Common)**, the case gone, the skin owned, equip accepted.
- Opening Elite from the Backpack UI: **Inkshift Phantom (Rare)**, reveal shown, EQUIP put it on.
- Odds per case add up to 100 %.
- **Not tested live:** the match place's ownership filter (the match place was in another lane's play test). Check: join a match after opening a skin; the equipped owned skin shows, an unowned one doesn't.

### Security review (roblox-reviewer, 2026-11-20) and fixes
Nothing critical or high: no free skins or cases, no unowned skins worn in the Lobby or the match, no double opening, the roll can't be steered (server seed inside the write). Fixed: coins spent on cases that can never open (Medium) → buy refusal + refund on open; "Equipped" toast only after the server's equipped list shows it; a slow opening's late answer still shows the reveal (30 s window); `devSkins` rate-limited; the match's last failed read no longer waits. Known, parked: the case pool comes from the Lobby's SkinReady models, so a skin ready in the Lobby but missing in the match would show Stock in matches (fails safe); a released list or a validator check would close it.
Re-test: `devSkins` → 208 skins; opening Apex refunded 2,000 coins and removed the case; buying Standard refused. The Studio test save now owns every skin (Studio store only).

## Next
1. The opening presentation (options above), then the cinematic (the rigged crate: shake, latches, lid, effects, reveal) replacing the panel's entrance.
2. Owner review of tiers, names, odds and which lines sit where; Legendary content.
3. Exclusive delivery (Robux bundles) when the Shop work resumes.
4. Duplicates policy beyond "re-roll / can't open" (e.g. coins back) if wanted.

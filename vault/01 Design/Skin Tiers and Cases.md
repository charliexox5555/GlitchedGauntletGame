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

## Cases
Per case, the chance of each **tier** (`src/shared/Config/Skins.luau` CASE_ODDS); a tier's chance splits evenly over its skins. Owned skins are **re-rolled** (dropped), so the others' odds go up (the Shop's odds note). A tier with nothing left drops out and the rest scale. If a player owns everything a case can give, it can't be opened ("You already own everything this case can give") and they keep it.

| Case | Common | Rare | Epic | Legendary | Owner's brief |
|---|---|---|---|---|---|
| Standard (400) | 100 | | | | "only the reskinned ones" |
| Elite (900) | 80 | 19 | 1 | | reskins + shape changes, "very, very low chances of the animated ones" |
| Apex (2,000) | 50 | 33 | 13 | 4 | "everything besides exclusive" |

**Nothing left to give:** the Shop won't sell a case when you'd hold more of it than it has skins left for you, and opening a case that has run dry (the pools overlap: a Common from Apex can empty a held Standard) gives its **coin price back** in the same write (`ShopEvent` "refunded").

Today (Legendary empty) Apex shows 52.1 / 34.4 / 13.5 %. Standard holds 138 skins, Elite and Apex 208. The owner called the top case "elite cases"; ours are Standard / Elite / Apex (top = Apex).

## How it works (built 2026-11-20)
- **Ownership:** `Shared/PlayerData` save field `skins = { [gunId] = { line } }` (Stock always owned, never stored), published as the JSON StringValue `Skins`. Everyone starts with **no skins** (the owner's wipe).
- **Lobby Locker:** lists only owned lines (`LockerController.ownedLines`); `LockerService` refuses unowned equips (`notOwned`) and publishes `LockerSkins` filtered to owned pairs, re-filtering when skins load or are granted (`PlayerDataService.changed`). Old saves that equipped any skin show Stock.
- **Match:** `SkinPreviewService` reads `LockerV1` **and** the owned skins (read only) and publishes only owned pairs; a failed ownership read = all Stock. The **F7 skin preview** is Studio-only now (`Config/SkinPreview.USER_IDS` for live testers; empty = nobody).
- **Opening:** Backpack → pick a case → OPEN CASE → `ShopRequest("openCase", itemId)`. `ShopService` checks the case, the PolicyService gate and the write limit, then one atomic `PlayerDataService.transact`: re-checks the count, rolls with `Shared/SkinCases.roll` on the **stored** owned list with a **seed fixed for this purchase**, removes the case, grants the skin. `ShopEvent {kind = "opened", gun, line, tier, text}` → the reveal panel (picture or emblem, name in the tier colour, tier tag, EQUIP / NICE). EQUIP sends the normal `LockerRequest`.
- **Shop CONTENTS:** generated from the tiers (`SkinCases.contents`), every skin with its % (four significant digits), highest tier first; the old placeholder lists in `ShopCatalog` are gone.
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
1. The cinematic opening (the rigged crate: shake, latches, lid, effects, reveal) replacing the panel's entrance.
2. Owner review of tiers, names, odds and which lines sit where; Legendary content.
3. Exclusive delivery (Robux bundles) when the Shop work resumes.
4. Duplicates policy beyond "re-roll / can't open" (e.g. coins back) if wanted.

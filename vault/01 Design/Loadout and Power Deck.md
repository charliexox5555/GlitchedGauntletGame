# Loadout and Power Deck (direction, 2026-11-26)

**Why.** The owner, after two days of ad data (D1 3.19% for the 24th cohort; average play time 6.7, then 8.7 min; about 30% of new players reach match 3): "there's nothing to work towards." Everything resets after a match, and skins don't change how you play. RIVALS, Hypershot and Murder Duels all give a reason to keep playing: you unlock guns or powers. The owner's call: "a much better direction … it is copying rivals a bit, but I'm adding on the powers." This note is the plan. **Step 1 (the power deck) is built** (2026-11-26, see [Step 1 built](#step-1-built-2026-11-26)); the rest is not.

**Core loop, one sentence:** play matches → earn **coins** → unlock **powers and guns** → build your **loadout and power deck** → try new combos in matches → play again.

## Decisions (owner 2026-11-26, Claude's picks where the owner left it open)

1. **Currency: coins**, not keys (owner: "coins are so good, I don't want to copy the rivals keys"). Guns are bought once with coins. **Powers come from power cases, not direct coin buys** (owner 2026-11-26: "they will be in cases not by coins"; a step of its own after step 1). Coins come from matches, tasks and the battle pass. Guns and powers are sidegrades, not upgrades, so coins bought with Robux buy variety, not a win.
2. **Guns are a loadout, chosen before the match** (Locker): one primary and one secondary, plus the knife. The gun row on the pick screen goes, along with the shared weapon tiers that rose each round. The pick screen was 39% of mid-match quits (MatchLeft, 2026-11-26), and this makes each pause one decision.
3. **Round 1 is a secondary round** (owner's idea; Claude: yes, low friction, a known pattern): everyone plays round 1 with their secondary, the primary from round 2. That makes the secondary choice matter and keeps a small step up in the match. **Exception:** a new player's onboarding matches skip it; they open on the starter primary (First Ten Minutes: show the fantasy first).
4. **Powers stay drafted**, which is the game's identity. Each round you are dealt 3 cards **from your own equipped deck** (new powers while you have a free slot, upgrades of the ones you have, the odd Glitched card) and pick 1. Powers stack through the match: "stack them until you're unstoppable". This replaces the rising gun tiers as the match's escalation.
   - **Deck:** you equip up to **10** powers in the Locker (owner 2026-11-26: room "as we add power cases and more powers"; was 6). At least 3 stay equipped (Claude's pick, so a match can always fill Q, E and T).
   - **Starter deck:** **Dash, Updraft, Molly, Frost** (owner 2026-11-26). Every save owns and equips them, existing saves too.
   - The other powers come from power cases (next step) and the battle pass (Smoke, Electric Shock).
5. **Keys follow draft order, not the power** (Claude's pick; the owner left it open):
   - Your 1st power goes on slot 1 (Q), the 2nd on slot 2 (E), the 3rd on slot 3 (T). Players rebind the three slots in Settings (KEYBINDS → MODS).
   - Why not per-power keys in the Locker: more setup for a 10-year-old, and keys change between matches.
   - Why not today's fixed slots (every power belongs to Q, E or T): 6 of the 12 powers share E, so they can never be combined. Order-based slots let any three powers stack, which means more combos.
   - The structure the owner wants stays: always three keys, filled left to right.
6. **Fewer guns, balanced as sidegrades.** 18 guns today (13 primaries, 4 secondaries, the knife). The proposed set:
   - **8 primaries:**

     | Gun | Role | Unlock |
     |---|---|---|
     | Havoc | rifle | starter |
     | Prowler | SMG | |
     | Pump | shotgun | |
     | Lancer | burst rifle | |
     | Marksman | DMR | |
     | Deadeye | sniper | |
     | Mauler | LMG | |
     | Spirit | silenced rifle | |

   - **4 secondaries:** Classic (starter), Sheriff, Shorty, Hush.
   - **Parked** (data kept, hidden from offers and the Locker): Buckshot, Hornet, Scout, TwinShot, Barrage.
   - The owner confirms the cut. Balance moves from "tier power" to "same strength, different range", a pass in [Gun Balance](Gun%20Balance.md).
7. **The battle pass and tasks pay coins and unlocks**, not only cosmetics, so they matter.

## Locker and weapon progression (owner 2026-11-26, from RIVALS' weapon pages)
The Locker becomes a weapon hub: open a gun to unlock it, level it up, see its rewards, contracts and lifetime stats. It is a big piece of work; the owner agrees it's the right way.
- **Gun pages:** each gun has its own page: preview, unlock (coins), level and reward track, contracts, lifetime stats (kills, headshot %, wins with it), skins.
- **Weapon levels (Claude's pick):**
  - Levels come from **playing with the gun** (XP for kills, wins and rounds played with it), so players have a reason to stick with a gun and come back to it. Coins don't buy levels.
  - Level rewards are **cosmetic and coins only** (wraps, charms, kill effects, banners, a coin payout), never stats. This keeps guns as sidegrades and avoids pay-to-win.
- **Contracts:** per-gun challenges ("10 headshots with the Deadeye") that pay coins or cosmetics. Same engine as the tasks the owner is building: share it, don't build two.
- **Gun identity:** with no weapon tiers, every gun gets a clear signature so picking one is a playstyle, all around the same strength. Done in a [Gun Balance](Gun%20Balance.md) pass and playtested. Starting ideas:
  - Deadeye: one-shot headshot, slow.
  - Pump: big close burst.
  - Lancer: accurate bursts.
  - Mauler: big magazine, slow to start.
  - Prowler: fastest on the move.
  - Marksman: two-tap mid range.
  - Spirit: quiet, no tracers.
  - Havoc: the honest all-rounder.
- **Knives:** skins only for now, with no knife abilities.
- **Look:** a new Locker in the game's own style (`gauntlet-ui-style`), laid out like RIVALS' weapon pages: study, don't copy (`rivals-reference`). Built in Studio as real ScreenGuis; the owner edits.

## Locker design from the RIVALS study (2026-11-26)
Source: [RIVALS UI study](../03%20Research/Rivals%20Reference/UI%20and%20Client.md#loadout--weapon-pages-study-2026-11-26) (owner: "it should look much more like rivals … a nice looking UI, nothing like the one we currently have"). A full revamp in our Soft Edge style (`gauntlet-ui-style`: plates with one cut corner, Rubik Heavy, one gold act-now thing per screen, no pills or glow), built in Studio as real ScreenGuis for the owner to edit.
- **Stage:** the gun (or power) shown big in the middle of a 3D locker set in the lobby (we already have the Locker room and its camera rise). The UI sits in two side columns.
- **Left column, tabs and lists:**
  - **GUNS** (Primary and Secondary lists, locked ones with a lock and price).
  - **POWERS** (your deck of 10 slots at the top, then every power card).
  - **KNIFE** (skins only).
  - The selected item is a large card at the top.
- **Right column, cards that change with the selection:**
  - **Owned gun:** Details (name, role line, favourite) → Level (bar, next reward) → Contracts → Overview (inline stats: damage near/far, range, fire rate, spread, headshot, magazine, move speed) → Statistics (lifetime: kills, headshots, wins, damage, playtime).
  - **Locked gun:** a lock over the model, then **UNLOCK (coins, gold)** and **TRY IN THE RANGE** (we have the Range).
  - **Power:** Details → Level → its upgrade paths A / B / Glitched shown as cards → Statistics → EQUIP TO DECK.
- **Bottom bar:** SKIN, and later WRAP / CHARM / KILL EFFECT; BACK.
- **Levels:** from use only (XP per kill, round and win with that gun or power), about 50 XP a level early. Rewards are cosmetics and coins, a milestone every 5 levels. No buying levels at first.
- **Contracts:** two tracks per gun, eliminations and playtime, ending in prestige finishes (our own names and looks). They share the tasks engine.
- **Power cases / card packs (owner 2026-11-26: "they will be in cases not by coins"):** powers come only from power cases, not direct coin buys. A new card unlocks a power via `ModLoadout.grant`; duplicates are undecided (owner), for example that power's XP. Roblox rules: paid random items must show their odds, and coins can be bought with Robux, so the case screen lists odds (as our skin cases already do). A pity rule (a new power guaranteed within N opens) is worth adding so no power feels out of reach.

## Economy (needs a pass before launch)
Today a match pays 15 coins for finishing and 20 for a win, halved against bots, with a 400-coin daily cap (`Config/Economy.MATCH_COINS`). At about 10 coins a bot match, a 1,000-coin unlock is 100 matches. That is far too slow. Rules for the pass:
- **The first unlock comes in the first session:** about 150 coins, reachable after match 2 plus the first task.
- **Then roughly one unlock per 1–2 play sessions,** prices rising.
- Tasks and the battle pass carry most of the coins.

## Build order (each step playtested with the owner before the next)
(Updated 2026-11-26: the gun loadout ships with the new Locker; weapon levels, contracts and stats follow.)
1. **Power deck and unlocks.** **Built 2026-11-26** ([Step 1 built](#step-1-built-2026-11-26)).
   - ~~Coin prices per power~~: powers come from cases.
   - A starter deck.
   - A Locker deck screen (equip up to 10).
   - The draft deals from the deck.
   - Order-based key slots: `DraftService` columns become "a new power or an upgrade" cards, and `ModService` slots fill in draft order.
2. **Gun loadout and the new Locker (gun pages: unlock, equip).** Look: the approved [Locker v3 mockup](#locker-v3-mockup-2026-11-26).
   - Primary and secondary chosen in the Locker; the gun row leaves the pick screen; tier escalation goes.
   - The secondary-round rule.
   - Unlocks with coins, and the gun cut.
3. **Weapon levels, contracts, stats** (contracts share the tasks engine), and the gun identity pass.
4. **Economy pass:** coin rewards, the task and battle pass payouts, prices.
5. **Onboarding update:**
   - Match 1 gives the starter loadout.
   - After match 2 the first unlock is affordable.
   - The first task points at it ("Unlock your first power").

## Step 1 built (2026-11-26)
- **Data:** `Config/Mods`: no power is `free` any more, and the per-power `slot` is gone. New: `DECK_SIZE = 10`, `DECK_MIN = 3`, `STARTER_DECK`, `STARTER_VERSION`. `Shared/ModLoadout`: the saved `mods = { owned, equipped, starter }`; `clean` gives any save below the current `starter` version the starters once (owned and equipped), so existing players get them and a starter they unequip later stays off. The deck is capped at 10 (starters first, then by name). **`ModLoadout.grant(loadout, id)`** (owned, equipped while there is room) is what power cases and the battle pass should call; `canEquip` / `canUnequip` hold the 3–10 rule.
- **Draft** (`DraftService`): a player is dealt only their deck; bots draw from every built power. One new power per empty slot, from the deck, none the seat already holds, last draft's cards only when nothing else is left. A picked new power lands on the **first empty slot**, so keys follow draft order. Upgrades stay per filled slot (A/B, the odd Glitched card). The onboarding script still works, with Dash now on Q.
- **Draft screen** (`DraftController`, `Util/DraftScreen`): each empty column shows one new power, and its tab names the first empty slot's key (round 1: all three say Q). Filled columns show their own key. Tabs and pick keys follow the Settings MOD 1–3 bindings (keyboard; the bumpers still step cards).
- **Locker** (`Util/LockerAbilities`, POWERS tab, still code-built inside the Locker canvas): a **DECK n / 10** line; starters first; owned powers EQUIP / UNEQUIP, DECK FULL when there's no room, a message if you'd drop under 3; powers you don't own say LOCKED. Server (`LockerService`, `LockerModRequest`): owned only, 3–10 equipped, checked again inside the save transaction, rate-limited, Lobby only. The RIVALS-style Locker above replaces this screen in step 2.
- **Admin (F8 → Utilities → POWERS · DECK):** + NEXT POWER, + ALL POWERS, STARTER DECK, standing in for power cases while testing. The Utilities page scrolls now.
- **Dev panel:** SetSlot puts a power on the picked slot and clears it from any other.
- **Studio playtest** (`FreshOnboarding`): the new save got the 4 starters. Match 1 dealt Dash (Q), Updraft (E), Dash Glitched, then Molly (T), all from the starter deck. In the Locker, + NEXT POWER unlocked Firewall, and unequip/equip saved. Equipping a power you don't own, an 11th power, or dropping under 3 were all refused. Match 2 round 1 offered Molly / Dash / Firewall, all on Q; the match ended with Molly Q, Updraft E, Firewall T (impossible with fixed slots). Not checked: phones, a controller, a live server, the round-2 mixed screen (upgrades plus new cards on E) by eye.
- **Before publishing:** until power cases ship, players have only the 4 starters (plus the battle pass powers). Ship with the power case, or accept that for a while.
- **Battle pass note:** `Lobby/SeasonRewards` grants a pass power with `owned` + `equipped = true` directly; it should call `ModLoadout.grant` so a full deck isn't pushed past 10 (`clean` trims it on the next load either way).

## Open (owner)
- ~~The 2 starter powers~~ Molly and Frost. ~~Deck size~~ 10.
- The gun cut.
- Whether the onboarding matches keep the scripted Glitched card.
- Power case: price, odds, what a duplicate gives (owner: decide later; the packs idea above says power XP).

## Locker v2 mockup (2026-11-26)
Built in Studio as `StarterGui.LockerV2` by [BuildLockerV2.luau](../../tools/studio/BuildLockerV2.luau). It is a static layout for the owner to review and edit, with no code wired to it. It is **off by default**: tick `Enabled` in Studio to look at it. Captures are in `art-source/ui/locker-v2/`.
- **Three states:** owned gun, locked gun, power. Each is a pair of frames shown together (`Left.Guns` / `Left.Powers`, `Center.Gun` / `Lock` / `Power`, `Right.GunOwned` / `GunLocked` / `Power`). Switch them in Explorer, or set the workspace attribute `LockerV2State` (`owned` | `locked` | `power`) and re-run the script.
- **Layout (design 1920 × 1080):** tabs GUNS / POWERS / KNIFE and coins on top.
  - **Left (460 px):**
    - Guns: the loadout (primary and secondary) then the class lists, with level, EQUIPPED tags, and the dimmed name and coin price for locked guns.
    - Powers: the deck (5 × 2 slots, 4 / 10) then every power, with a role tag or POWER CASE.
  - **Middle:** the gun or power (the 3D stage in game).
  - **Right (460 px):** Details (name, role tag, one line), Level (bar, next reward), Contracts and Statistics rows, and Overview (10-segment bars plus a value).
    - Locked gun: a big padlock over the dimmed gun, a gold UNLOCK with the coin price, and TRY IN THE RANGE.
    - Power: Level, then the A / B / Glitched upgrade paths.
- **Rules from the self-review:**
  - **Gold** only for the one act-now action: EQUIP on an owned gun that isn't equipped, UNLOCK on a locked one, ADD TO DECK on an owned power outside the deck. Already equipped or in the deck shows a dark EQUIPPED / REMOVE FROM DECK.
  - **Tags size to their words.**
  - **No small lock icons in rows:** the image reads as a dash at 22 px.
- **The stats and names are placeholders:** Havoc 12, Deadeye 1,500 coins and so on. The real numbers come from `Config/Weapons` and the gun pass.
- **Open (owner):** the look, spacing and words; the stage behind (3D Locker room); whether the KNIFE tab is enough for skins; where SKINS opens.

## Locker v3 mockup (2026-11-26)
**Approved (owner 2026-11-26: "Yes, this direction").** Step 2 of the build order builds the real Locker from this mockup.
Owner on v2: "I want it to look much better", the weapons "much more like RIVALS", and powers as cards "you can move around so it feels like a real card". v3 replaces v2 as the direction (v2 stays in Studio, off, as history).
- **Where:** `StarterGui.LockerV3` (off) + `ReplicatedStorage.LockerV3Stage` (the showcase guns and the power card; parts under a ScreenGui are dropped when StarterGui copies it, so the stage lives in ReplicatedStorage). Built by [BuildLockerV3.luau](../../tools/studio/BuildLockerV3.luau); the drag-and-click preview is [LockerV3Preview.luau](../../tools/studio/LockerV3Preview.luau) (the Source of `LockerV3.Preview`). Icons: `tools/ui/make_locker_icons.py` → `art-source/ui/locker-v3/icons/` (uploaded; use the Image ids, not the Decal ids the upload returns). Captures: `art-source/ui/locker-v3/`.
- **Try it:** set the Workspace attribute `LockerV3Preview = true`, press Play. Click guns, powers and tabs; drag the middle to turn the gun or the card; Flip, EQUIP, ADD TO DECK and the Overview eye work; Back closes it. `LockerV3State` = `powers` / `locked` opens on that view. **Clear `LockerV3Preview` before publishing.**
- **Stage (from the RIVALS study: their locker camera is FOV 18 with a depth-of-field effect, far 0.75, in-focus radius 15):** our lobby Locker room, camera at (67, 7.8, -1600) looking at the gun spot (80, 6.6, -1600), FOV 20, the same depth of field, so the armoury wall and its guns blur behind. The plinth circle, its display guns and the Armorer are hidden locally. Guns are scaled to about 4.1 studs so pistols read as big as rifles, shown in the equipped skin (Redline Havoc, Nitrous Prowler, Poolside Pump, Prism Classic, Oilwake Sheriff); locked guns are ghosted with a lock disc over them. The real build should use an off-world copy of the room so no player walks through the shot.
- **Power card:** a 2.12 x 2.65 stud card: the draft card's face on a SurfaceGui (art, slanted role band, name, role, L1 note, charges, level; LightInfluence 0), a white sweep that slides as it turns, the Power Duels logo on the back, the role colour on the edge. It bobs, leans up to 10° toward the mouse, turns 0.35° per pixel dragged, settles on the nearer face, and spins in when a new power is picked.
- **UI recipe (RIVALS structure, our look):** translucent dark one-cut panels (`UiPlates.cut1`, 07080B at 22%) over dark side fades; chunky buttons = the cut plate with a vertical gradient + a shine on the top half (blue = look / open, gold = the one act-now thing, dark = done, red = back); round bottom buttons with the word under; white Rubik Heavy with a soft 80 % dark stroke where words sit on the scene. Selected power tile = a white bar under it (no outline ring).
- **Not built / open:**
  - "See it in action" is a placeholder row: a short looping clip or a live demo of the power on a bot in the stage (owner's "viewport of the ability in action" idea). Needs a choice: a recorded video asset (Roblox video upload) or a scripted demo in the stage.
  - Contracts and Statistics pages, the Skin / Charm / Kill FX trays, the knife tab beyond a placeholder, phones and controller layout.
  - Numbers, levels, prices and the deck are placeholders; nothing is wired to data or remotes.

## Step 2 plan: gun loadout and the real Locker v3 (2026-11-26)
**Built 2026-11-26 (parts A, B, C and most of D; Studio-tested, not published):**
- **A, data:** `guns` on the save (`Shared/GunLoadout`, `Config/Loadout`), `LockerGunRequest` (security review: no high findings; fixed the three low ones: no write for an equip that changes nothing, the queue and pad duels wait for a gun save, the admin profile reset resets guns). Admin F8 → POWERS · GUNS: **+ ALL GUNS**, **STARTER GUNS**. Bug found and fixed in testing: the save writer keeps only listed fields, `guns` had to be added (`PlayerDataService` `out.guns`).
- **B, matches:** tiers are now two phases (Sidearm round 1, Loadout round 2+, flat 50 shield from round 2); no gun row; each seat's guns come from the save when the draft closes; bots get a random pair; the 3-2-1 banner and top bar say SIDEARMS ONLY / FULL LOADOUT; the Range LOADOUT lists only the active set. Tested: a local bot match gave the Classic in round 1 and the equipped Prowler + Classic in round 2.
- **C + D, the Locker:** `Controllers/LockerV3Controller` owns the Locker (Lobby `Config.LOCKER_V3`; Locker v4 stays in the code, off). GUNS with real ownership, prices, EQUIP / UNLOCK / TRY, the Overview from `Config/Weapons`; SKIN opens a strip of owned skins; POWERS with the 3D card and the deck (`LockerModRequest`); KNIFE with its skins. Tested in Studio: unlock refused without coins (with the shortfall shown), equip, skins strip, powers, knife.
- **Owner playtest notes, done (2026-11-26):**
  - **Own room:** the Locker films `Workspace.LockerV3Room`, a copy of the lobby Locker room 3,000 studs away (`tools/studio/BuildLockerRoom.luau`: no plinths, Armorer, zone trigger or hallway link; Persistent streaming so it is always there; its gun-wall anchors show your skins). Nobody can walk into the shot.
  - **Opening:** the camera rises behind a wipe (Locker v4's open), then the columns slide in from their edges; tabs, selections and the skin strip slide too; buttons grow on hover and dip on press (from their centre); rows and tiles brighten on hover.
  - **All skins:** SKIN lists every skin of the gun (owned first, then by tier), each with its tier colour; locked ones show a lock, preview on the stage and say where they come from (skin cases / bundles).
  - **Unlock asks first:** a confirm window (name, picture, price, coins left, CANCEL / gold UNLOCK).
  - **TRY IN THE RANGE** goes to the Range (closes the Locker, `RangeTransition.travel`). The LOCKER title moved next to the tabs (Roblox's buttons cover the top-left). Favourite stars hidden until favourites exist; the Overview card follows the shown panel (works on locked guns too).
- **Not yet:** levels, contracts, statistics (step 3, hidden); Charm / Kill FX buttons (hidden); the onboarding "equip your new skin" guide of Locker v4 (the free case now auto-equips, so it is not needed in the flow); phones and controller; an off-world copy of the room. Depth of field needs a mid graphics level: on low settings the armoury wall shows sharp behind the panels.
Owner: "start step 2". Built in parts, each Studio-tested before the next; the owner playtests the whole step before publish.
- **Data (part A).** A new save field `guns = { owned = {[id]=true}, primary = id, secondary = id }` (`PlayerData.clean` default, no version bump, like `mods`), mirrored to the client as the JSON StringValue `LockerGuns`; `Shared/GunLoadout.luau` holds the rules (`clean`, `canEquip`, `canUnlock`), like `ModLoadout`.
  - **One config:** `Config/Loadout.luau`: the active set (8 primaries, 4 secondaries, in Locker order), the starter pair, coin prices, `SECONDARY_ROUNDS = 1`. Parked guns (Buckshot, Hornet, Scout, TwinShot, Barrage) keep their data but are not offered, sold or listed.
  - **Starter:** every save owns Havoc + Classic, equipped. *Claude's pick, owner can change:* existing players start from the same pair (no grandfathering); they keep their coins (new saves start with 500, enough for a first unlock).
  - **Prices (placeholders until the economy pass, step 4):** Sheriff 400, Shorty 400, Hush 500, Prowler 500, Pump 600, Lancer 750, Marksman 900, Spirit 1,000, Mauler 1,200, Deadeye 1,500.
  - **Remote:** `LockerGunRequest` (lobby): `("unlock", gunId)` and `("equip", gunId)`. Server checks: types and lengths, the gun is in the active set, Lobby zone, not in a found match or teleporting, rate limit, one write at a time per player; inside `PlayerDataService.transact` it re-checks coins and ownership, takes the coins and grants, or sets the slot. Replies to the client with the result. Security review before commit.
- **Matches (part B).**
  - The gun row leaves the pick screen: the offer has no guns, LOCK IN needs only the power pick (server `DraftService` + client `canLock`), and the cards lift into the empty row (the onboarding focus lift, without hiding columns).
  - Each seat takes its loadout from the save at the draft: rounds 1..`SECONDARY_ROUNDS` give only the secondary (the gun opens on it already), later rounds give primary + secondary. A save that hasn't arrived yet uses the starter pair.
  - **Tiers go:** `Config/Match.PHASES` becomes two phases, **Sidearm** (round 1, shield from the gun) and **Loadout** (round 2+, flat 50 shield). The HUD, match end and stats keep reading the phase name; "Heavy guns" announcements go.
  - **Onboarding** keeps its handed guns for now (Sidearm = Sheriff, Loadout = Prowler); the onboarding update is step 5.
  - **Bots** get a random primary + secondary from the active set at match start.
  - **Tasks to re-check** (the tasks owner): `roo2_tierSweep` ("an elimination with every weapon tier") and `due3_sidearm` read the gun's own `tier`, which stays in `Config/Weapons`, so they still work; flag them for the tasks pass.
  - **Range LOADOUT** stays free (that is TRY IN THE RANGE); it lists only the active set.
- **Locker (part C, then D).** The real Locker v3 replaces Locker v4 (`LockerController`):
  - Studio-built template `StarterGui.LockerV3` (from the mockup), filled by a new controller; the stage is the **real lobby Locker room** with the camera at FOV 20 + depth of field, hiding locally the plinth circle, the Armorer, every character in the room and the floating displays (simpler than an off-world copy and keeps the pegboard guns).
  - **Part C, GUNS:** the loadout card, the class lists from `Config/Loadout`, the 3D gun in its equipped skin, EQUIP / UNLOCK wired, TRY IN THE RANGE, Overview with real stats from `Config/Weapons`. The level card, Contracts and Statistics wait for step 3 (hidden, not faked).
  - **Part D, POWERS + skins:** the 3D power card and deck wired to `LockerModRequest`; SKIN opens the skin strip (equip through `LockerRequest`, as v4 does); KNIFE = knife skins. Charm / Kill FX buttons stay hidden until those exist.
  - Phones and controller come with part D.

## Power cases (owner 2026-11-26)
Powers come only from power cases. RIVALS-style **themed cases** (later up to three, each its own theme and powers) instead of tiers; **start with one** while there are few powers.
- **Case 1: SURGE** (electric power): charcoal body, gold accent, angled lightning-cut straps, a faceted energy-core window on the lid.
- **Shape:** a compact chest (about 2 x 1.4 x 1.2 studs), squarer than the long gun-skin case, with the same moving parts (`Base`, `Lid` hinged at the back, `LatchL` / `LatchR`, `Handle`, `Gem`) and colour roles, so `Util/CaseOpening` opens it like the others.
- **Never a duplicate:** a case always gives a power you don't own yet (equal odds among those); once you own every power in it, it can't be opened. The odds list shows the remaining powers.
- **Price: Tickets** (earn-only, like skin cases; about 4 a case, set in the economy pass), so powers can't be bought with Robux.
- Holds every built power outside the starter deck (today 8: Recon, Heal Orb, Firewall, Stim, Recall, Shock Dart, Flash, Roller).
- Model: Blender (live MCP), faceted, `gauntlet-build-style` + `gauntlet-model-joins`; script `tools/blender/crates/build_power_case.py` (reuses `build_crate.py`'s helpers).
- **Model v1 built (2026-11-26, Blender, waiting for the owner's look check):** `tools/blender/crates/build_power_case.py` → `art-source/lobby/crates/PowerCase.blend` + `PowerCase.json`, previews `art-source/lobby/crates/power_preview/`. 2.0 x 1.36 x 1.3 studs, 16 parts, 6.3k tris, faceted only (flat 1-segment chamfers, 6/8-sided bars, no modifiers). Charcoal body, graphite corner guards that wrap the clipped corners down to octagon feet, a skirt plinth, a hex bezel with a gold lightning bolt on the front, a gold surge strip on the lid front, gold-striped latches, gold zig-zag surge lines cut into the lid plate, a steel hex bezel holding a cut crystal core (the `Gem`, rides the lid). Same groups and pivots as the skin crate. Built in its own Blender window (`tools/blender/start_bridge.py`, bridge on port 9877) because the default bridge belonged to another project's file.
- **Next after a yes:** FBX → Open Cloud → `tools/studio/BuildCrate.luau` (`WHICH = "PowerCase"`) → `ReplicatedStorage.Crates.PowerCase`; UI renders (Shop card, Backpack icon); then the case system: an inventory item bought with Tickets, a server roll among the powers not owned (`ModLoadout.grant`), the opening with the 3D power card rising out, the odds list.
- **Built and tested (2026-11-26, Studio):** `Shared/PowerCases` + `Config/PowerCases` (owner: "rank powers in tiers so there are better powers that will be lower chances"): a tier is rolled first (Common 55, Rare 28, Epic 13, Legendary 4, renormalised over tiers with an unowned power), then equal odds inside it; PROPOSED ranking Common Recon / Heal Orb / Stim, Rare Firewall / Recall, Epic Flash / Shock Dart, Legendary Roller (owner to tune). `CasePower` item, 4 Tickets (`Economy.CASE_TICKETS.Power`), `ShopService` buys and opens it (no Robux product), reward `{ power, tier }`, `Power granted` event; the odds list per tier with card-art thumbnails (`Util/PowerCardFace.thumb`); Backpack result NEW POWER / SEE IN LOCKER; the Shop HOME got a POWERS row (`tools/studio/AddPowerCaseCard.luau`). Tested: bought via admin, opened twice (Roller, Recon granted and put in the deck).
- **Owner 2026-11-26: a card pack, not a case** ("it rips open the card pack and looks cool"). The system above stays; the item becomes the **SURGE PACK** and gets its own model (a faceted foil pouch with gold crimped seals, a front label panel, a top strip that tears off) and its own opening (`Util/PackOpening`): the pack floats up in front of the camera, shakes in its tier colour, the strip rips off, the 3D power card slides out and flips to its face. The Surge case model stays in the repo, unused.
- **SURGE PACK built (2026-11-26):** model `tools/blender/crates/build_power_pack.py` (faceted foil pouch with a back fin seam, gold crimped seals with cut corners and 17 teeth, a tear notch on the top seal; 2.5k tris) → `art-source/lobby/Exports/PowerPack.fbx` (asset 73626878472922) → `tools/studio/BuildPack.luau` → `ReplicatedStorage.Crates.PowerPack` (anchored parts, `TopPivot` attribute = the strip's hinge). The label is a SurfaceGui (charcoal, the gold faceted bolt `art-source/ui/pack/surge_bolt.png`, SURGE / POWER PACK / "1 POWER · NEVER A DUPLICATE", Rubik), no game logo. Its straight-on Studio capture `art-source/ui/pack/pack_label.png` is laid on the plate for the Blender UI renders (`PACK_ART`): Backpack and Shop popup icon `pack_power.png`, Shop card `pack_power_card.png`. `Config/Crates [7]` is `template = "PowerPack", pack = true`; `Util/CaseOpening.start` hands a pack tier to `Util/PackOpening` (yours only; others see nothing). Numbers in `Config/CaseOpening PACK`; rip sound PSE "Paper Tear Fast Harsh Rip" (9125724621). The item is SURGE PACK (Shop card kind POWER PACK). The Surge case model and `Crates.PowerCase` stay, unused.
- **SURGE PACK tested (2026-11-27, Studio Play):** a real open from the Backpack (OPEN 1 → Stim, then the Backpack's NEW POWER), plus Epic (Flash) and Legendary (Roller) previews; console clean. The name plate sits over the lobby HUD (DisplayOrder 20) at 72% height, the shown card is lifted clear of the PLAY bar. Stills: `art-source/lobby/crates/pack_preview/opening_*.jpg`. Open question for the owner: the pack is local only (others nearby see nothing), unlike the skin cases.
- **Pack v2 (owner 2026-11-27):** "I thought like we would see the pack open in the world space like the crate" → the pack now floats in the world in front of the opener (7 studs out, 3.6 up, 2.8x scale), tossed from their chest; nearby players see it through CaseShow (their plate reads "NAME · TIER POWER", quieter sounds, no flash or kick); the card arcs into the opener at the end. "Options for opening 3, similar to case openings layout" → OPEN 3 tosses three packs in a row (10 studs out, 6.5 apart), built up to the best tier together; the best one leads (stinger, flash, kick), the cards are 0.8 size and fly in one after another. "More satisfying" → a coil before the rip, an overshoot pop as the card grows, one shine across the card face, twinkling stars while it holds (a shockwave ring and a spinning halo were tried and removed, owner 2026-11-27: "I dont really like the effects behind the card ... the circle thing we dont need that"; only the soft tier glow stays behind the card). Numbers: `Config/CaseOpening PACK`. "The images in the collect screen are stretched" → `PowerCardFace.thumb` now crops the card art to each label's own shape (reveal, haul cells, odds list). Tested 2026-11-27: a real OPEN 1 (Firewall) watched in third person, a real OPEN 3 (three packs → NEW POWER 1 OF 3, haul row unstretched), Legendary and 3-pack previews measured (layout, plates, halo by tier, clean-up), console clean. Then captured on screen: the 3-pack row ripping on one beat and the reveal (stills `pack_preview/opening_open3_*.jpg`); the pack lights were toned down so they don't blow out the player.

## Launch plan for the loadout update (2026-11-27)
Owner decisions (2026-11-27):
- **Guns:** Hornet (Stinger) and Scout (Marshal) come back into the active set, buffed: **Scout** quicker, accurate from the hip, faster movement; **Hornet** a top fire rate with heavy recoil. **TwinShot (Outlaw) is removed completely**, including from every skin line (its skin models, the pass's Frostbite TwinShot swaps to an active gun). Buckshot (Judge) and Barrage (Ares) stay parked. Then a balance pass so every gun is good and has a clear identity ([Gun Balance](Gun%20Balance.md)).
- **Gun levels raise stats** by category (owner: "upgrades its overall stats in categories"), plus level rewards (coins, charms, maybe battle pass levels). This replaces the earlier "cosmetic only" pick; keep the steps small and capped so a new player's starter gun still wins fights (step 3).
- **Skin cases only drop skins for guns you own**: odds recalculate per player; the free case after match 1 gives **Havoc skins only**.
- **The power pack is bought with coins, plus a Robux option priced from the coin packs' rate** (owner: "do the conversion rate well, or flat out coins only"). Claude's pick: 1,500 coins or 99 R$ for one, 4,500 coins or 279 R$ for three (about the 99-1999 R$ coin packs' 12-16 coins per Robux, so Robux is never a cheaper way round). Tickets no longer buy packs. Not in the daily shop yet (too few powers).

Work, in order (each Studio-tested; sessions can split 1, 2+3 and 4):
1. **Gun set:** `Config/Loadout` adds Stinger and Marshal (prices, roles); TwinShot out of `Config/Weapons` (or `retired`), `ServerStorage.WeaponSkins/*/Outlaw`, `Config/Skins`, `SeasonCatalog` (Frostbite Outlaw -> an active gun), any bundle; data for saves that hold an Outlaw skin is dropped cleanly.
2. **Balance pass:** all 14 guns (10 primaries, 4 secondaries) as sidegrades with identities, a measured TTK table, bot-match playtests ([Gun Balance](Gun%20Balance.md)).
3. **Case odds by owned guns:** `SkinCases.pool` filters by `data.guns.owned` (server roll, buy check, odds list), the Starter case to Havoc; the daily shop rolls only skins for active guns.
4. **Pack pricing:** Robux products (1 and 3), coin price, the Shop popup buttons, receipts through `RobuxService`, Tickets removed for packs.
5. **Before publish:** the onboarding update (build order step 5: matches 1-2 hand out guns new players don't own; give the starter loadout or a "first unlock" moment), Locker v3 and the pack opening on **phones and controller** (81% of players are on mobile), the economy pass (coins per match vs gun and pack prices), what existing players get (grandfathering), push, publish, save the place.
6. **After:** weapon levels with stat upgrades, contracts and lifetime stats (step 3).

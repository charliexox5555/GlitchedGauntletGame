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

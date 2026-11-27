# Loadout and Power Deck (direction, 2026-11-26)

**Why.** The owner, after two days of ad data (D1 3.19% for the 24th cohort; average play time 6.7, then 8.7 min; about 30% of new players reach match 3): "there's nothing to work towards." Everything resets after a match, and skins don't change how you play. RIVALS, Hypershot and Murder Duels all give a reason to keep playing: you unlock guns or powers. The owner's call: "a much better direction … it is copying rivals a bit, but I'm adding on the powers." This note is the plan; nothing is built.

**Core loop, one sentence:** play matches → earn **coins** → unlock **powers and guns** → build your **loadout and power deck** → try new combos in matches → play again.

## Decisions (owner 2026-11-26, Claude's picks where the owner left it open)

1. **Currency: coins**, not keys (owner: "coins are so good, I don't want to copy the rivals keys"). Powers and guns are bought once with coins. Coins come from matches, tasks and the battle pass. Guns and powers are sidegrades, not upgrades, so coins bought with Robux buy variety, not a win.
2. **Guns are a loadout, chosen before the match** (Locker): one primary and one secondary, plus the knife. The gun row on the pick screen goes, along with the shared weapon tiers that rose each round. The pick screen was 39% of mid-match quits (MatchLeft, 2026-11-26), and this makes each pause one decision.
3. **Round 1 is a secondary round** (owner's idea; Claude: yes, low friction, a known pattern): everyone plays round 1 with their secondary, the primary from round 2. That makes the secondary choice matter and keeps a small step up in the match. **Exception:** a new player's onboarding matches skip it; they open on the starter primary (First Ten Minutes: show the fantasy first).
4. **Powers stay drafted**, which is the game's identity. Each round you are dealt 3 cards **from your own equipped deck** (new powers while you have a free slot, upgrades of the ones you have, the odd Glitched card) and pick 1. Powers stack through the match: "stack them until you're unstoppable". This replaces the rising gun tiers as the match's escalation.
   - **Deck:** you equip up to 6 powers in the Locker.
   - **Starter deck:** Dash, Updraft plus 2 more (proposed Molly and Frost; owner picks).
   - The other powers unlock with coins.
   - The draft already only deals powers a player may use (`ModLoadout.eligible`: free, or owned and equipped; the Locker has an ABILITIES tab). Today every power is `free = true`.
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

## Economy (needs a pass before launch)
Today a match pays 15 coins for finishing and 20 for a win, halved against bots, with a 400-coin daily cap (`Config/Economy.MATCH_COINS`). At about 10 coins a bot match, a 1,000-coin unlock is 100 matches. That is far too slow. Rules for the pass:
- **The first unlock comes in the first session:** about 150 coins, reachable after match 2 plus the first task.
- **Then roughly one unlock per 1–2 play sessions,** prices rising.
- Tasks and the battle pass carry most of the coins.

## Build order (each step playtested with the owner before the next)
1. **Power deck and unlocks.**
   - Coin prices per power.
   - A starter deck.
   - A Locker deck screen (equip up to 6).
   - The draft deals from the deck.
   - Order-based key slots: `DraftService` columns become "a new power or an upgrade" cards, and `ModService` slots fill in draft order.
2. **Gun loadout.**
   - Primary and secondary chosen in the Locker; the gun row leaves the pick screen; tier escalation goes.
   - The secondary-round rule.
   - Unlocks with coins, and the gun cut.
3. **Economy pass:** coin rewards, the task and battle pass payouts, prices.
4. **Onboarding update:**
   - Match 1 gives the starter loadout.
   - After match 2 the first unlock is affordable.
   - The first task points at it ("Unlock your first power").

## Open (owner)
- The 2 starter powers beside Dash and Updraft.
- The gun cut.
- Deck size (6 proposed).
- Whether the onboarding matches keep the scripted Glitched card.

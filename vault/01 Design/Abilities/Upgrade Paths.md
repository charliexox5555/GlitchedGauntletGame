# Upgrade paths: L2 and L3 for every ability

> **Status: all 9 decided and BUILT (2026-11-03 overnight), tested solo in Studio** ([playtest](../../05%20Production/Playtests/2026-11-03%20Ability%20Upgrades%20Overnight.md)); waiting for the user's test. Base changes from the review: Updraft 1 charge, Recall 20 s cooldown. Each ability note has an "Upgrades (L2/L3)" section with how its levels were built. Numbers and card text live in `Config/Mods`. Overrides the old A/B/G tables in [Mods](../Mods.md) (those were written for the abilities before the redesign).

## How upgrades work
- **L1** is the base ability you draft.
- **L2** offers 3 cards: **path A**, **path B** and, rarely, a **glitched** path (about 8%; when it doesn't show up you only see A and B).
- **L3** upgrades the path you took at L2.
- **Glitched abilities look different** (decided 2026-11-03): each glitched path gets its own look and sound that fits what it now does (e.g. the Frost Wall is ice, not fire), on top of the magenta glitch static.

## Keys: each ability has its own key (decided 2026-11-03)
Every ability belongs to one key and is always on that key, instead of picks filling Q, then E, then T in order. **Slot 1 = Q, slot 2 = E, slot 3 = T.** The user assigns the keys one ability at a time.

| Ability | Key |
|---|---|
| Dash | **E** (slot 2) |
| Updraft | **Q** (slot 1) |
| Molly | **E** (slot 2) |
| Firewall | **T** (slot 3) |
| Frost | **T** (slot 3) |
| Recon | **E** (slot 2) |
| Heal Orb | **E** (slot 2) |
| Stim | **Q** (slot 1) |
| Recall | **E** (slot 2) |

E has 5 abilities and Q and T have 2 each; the user is fine with that for now (more abilities are coming).

**The draft (decided 2026-11-03, built):** a filled slot locks its key: new abilities are only offered for your empty slots, and an ability for a filled slot never shows up. Once every slot is full the draft offers upgrades instead. See [Match Flow](../Match%20Flow.md) → Abilities.

## Path names as built (proposed by the ability sessions; the user can rename)
| Ability | Path A | Path B | Glitch |
|---|---|---|---|
| Dash | Long Dash | Ghost | Desync |
| Updraft | High Rise | Second Wind | Crash Down |
| Molly | Recharge | Bigger Fire | Fork Fire |
| Firewall | Short Wall | Long Wall | Frost Wall |
| Frost | Stockpile | Big Burst | Freeze Frame |
| Recon | Recharge | More Pulses | Ping Spike |
| Heal Orb | Charges | Long Heal | Barrier |
| Stim | Quick Stims | Strong Stim | Heal Zone |
| Recall | Recharge | Long Range | Crash Recovery |

The names below in each section are the ones decided in the review (e.g. Updraft "Height" / "Charges" / "Slam"); the table above is what the cards say now. Two glitches both start with "Crash" (Crash Down, Crash Recovery): see [Bugs & Ideas](../../05%20Production/Bugs%20%26%20Ideas.md).

## 1. Dash (E): decided 2026-11-03
L1 (unchanged): 12 studs in 0.15 s, 1 per round, no recharge.

| Level | Effect |
|---|---|
| **A2 Distance** | Dash 150% as far (18 studs) in the same 0.15 s. |
| **A3 Distance** | 200% as far (24 studs) in the same 0.15 s, and **2 charges**. |
| **B2 Ghost** | Bullets pass through you for 0.35 s from the press (longer than the dash itself, so you can dodge a shot you see coming). |
| **B3 Ghost** | After dashing you're nearly invisible for 1 s (enemies within 10 studs see a shimmer), and **2 charges**. |
| **G2 Desync** ⚡ | The dash leaves a decoy afterimage that keeps running your old direction for 1.5 s. Drawback: you can't shoot for 0.3 s after dashing. |
| **G3 Desync** ⚡ | The decoy fires fake shots (tracers and sound) at the nearest enemy, and you're invisible while it runs. |

Parked alternative glitch: **Rubberband**: press again within 2 s to snap back to where you dashed from, with a loud glitch sound.

## 2. Updraft: decided 2026-11-03
L1 (built): straight up ~14 studs, works mid-air, **1 per round** (lowered from 2 on 2026-11-03, already changed in `Config/Mods`), no recharge.

| Level | Effect |
|---|---|
| **A2 Height** | Launch 150% as high (~21 studs). |
| **A3 Height** | 200% as high (~28 studs). |
| **B2 Charges** | **2 charges**. |
| **B3 Charges** | **3 charges**. |
| **G2 Slam** ⚡ | Press crouch in the air to slam straight down: 30 damage within 8 studs of where you land. |
| **G3 Slam** ⚡ | The slam does 45 damage and Hinders enemies it hits for 1 s, and **2 charges**. |

## 3. Molly: decided 2026-11-03
L1 (built): fire grenade, 9-stud patch for 4 s, 45 damage/s, 1 per round, no recharge.

| Level | Effect |
|---|---|
| **A2 Recharge** | A used Molly comes back after **15 s**. |
| **A3 Recharge** | Comes back after **10 s**. |
| **B2 Bigger Fire** | The fire patch is 12 studs wide. |
| **B3 Bigger Fire** | 14 studs wide, and it burns for 6 s. |
| **G2 Fork Fire** ⚡ | On landing it splits into 3 small fires (5 studs each) that scatter randomly; they burn you at full damage. |
| **G3 Fork Fire** ⚡ | 5 fires, and the grenade bounces once more before it splits. |

Feel reference for Fork Fire: a cluster grenade that splits into bouncing bomblets (like Raze's Paint Shells in Valorant). Only the feel, not the look or name.

## 4. Firewall: decided 2026-11-03
L1 (built): steerable fire wall up to 40 studs long and 10 tall, lasts 6 s, 30 damage/s, 1 per round, no recharge.

| Level | Effect |
|---|---|
| **A2 Short Wall** | Recharges after **15 s**, but the wall is half as long (20 studs). |
| **A3 Short Wall** | Recharges after **6 s** (still 20 studs). |
| **B2 Long Wall** | 150% as long (60 studs). |
| **B3 Long Wall** | **2 charges** (still 60 studs). |
| **G2 Frost Wall** ⚡ | Becomes a wall of ice (frost look and sound, not fire). No damage: enemies who touch it are Hindered for 1.5 s. 60 studs long. |
| **G3 Frost Wall** ⚡ | **2 charges**. |

Watch in playtests: A3's 6 s recharge equals the wall's 6 s life, so a short wall can be up almost all the time.

## 5. Frost: decided 2026-11-03
L1 (built): thrown burst, everyone within 10 studs is Hindered for 3 s, 1 per round, no recharge.

| Level | Effect |
|---|---|
| **A2 Charges** | **2 charges**. |
| **A3 Charges** | **3 charges**. |
| **B2 Big Burst** | Double the area: **14-stud** radius (was 10). |
| **B3 Big Burst** | Triple the area: **17-stud** radius. |
| **G2 Freeze Frame** ⚡ | Hard freeze instead of Hinder: everyone in the burst can't move or shoot for 1.5 s. Drawback: it freezes you and your teammates too if you're in it. |
| **G3 Freeze Frame** ⚡ | The freeze lasts 2.5 s. |

## 6. Recon: decided 2026-11-03
L1 (built): charged dart that sticks and pulses twice, revealing enemies it can see within 40 studs for 2 s; 1 charge, back 30 s after use.

| Level | Effect |
|---|---|
| **A2 Recharge** | Back after **20 s**. |
| **A3 Recharge** | Back after **12 s**. |
| **B2 More Pulses** | **3 pulses**. |
| **B3 More Pulses** | **5 pulses**. |
| **G2 Ping Spike** ⚡ | One big pulse that reveals every enemy within 60 studs **through walls** for 4 s. No drawback (the user removed "enemies see you too"). |
| **G3 Ping Spike** ⚡ | Your shots deal +20% damage to enemies it revealed. |

## 7. Heal Orb: decided 2026-11-03
L1 (built): heal the ally in your crosshair 60 HP over 3 s (20 HP/s), or yourself 30 (10 HP/s); 1 per round, no recharge.

| Level | Effect |
|---|---|
| **A2 Charges** | **2 charges**. |
| **A3 Charges** | **3 charges**. |
| **B2 Long Heal** | The heal runs **twice as long** at the same rate: 6 s, so 120 to an ally, 60 to yourself. |
| **B3 Long Heal** | **Three times as long**: 9 s, so 180 to an ally, 90 to yourself. |
| **G2 Barrier** ⚡ | No heal. Instead the target (an ally in your crosshair, or yourself) gets a **Barrier that blocks the next hit** completely. |
| **G3 Barrier** ⚡ | The Barrier blocks **2 hits**. |

**Barrier (new, needs building):** the feel is like Iso's shield in Valorant (blocks one instance of damage, then pops), with our own look.
- **What counts as a hit** (proposed): one damage instance. A bullet is one hit; a shotgun blast is one hit (all its pellets); one tick of fire or a slam is one hit. It's checked in `WeaponService.hurt`, before the gun shield and health.
- **Lasts** until it blocks its hits or the round ends (proposed).
- **Look (proposed):** a see-through hex bubble around the whole body, so the player can still see out. Team colours, with magenta glitch static and a flicker. Enemies must be able to see it clearly so they know their next shot won't count. A front-only tactical shield was rejected: it couldn't block "the next hit" from behind.
- **First person:** faint hex pattern at the screen edges, and pips on the HUD for hits left. When it blocks: crack flash at the screen edge, a glassy shatter sound, and the bubble breaks into pixels.
- **Third person:** the bubble around the body; it shatters into pixels when it blocks. A "blocked" hit marker for the shooter instead of damage.
- Named Barrier, not "shield", so it doesn't mix up with the gun shields in [Gun Balance](../Gun%20Balance.md).

## 8. Stim: decided 2026-11-03
L1 (built): toss a beacon; a 10-stud zone for 8 s; you and your team in it are Stimmed (+15% move and fire rate, 15% faster reload, 30% faster swap), lasting 4 s after you leave; 1 per round, no recharge.

| Level | Effect |
|---|---|
| **A2 Quick Stims** | **2 charges**, but each zone lasts half as long (4 s, and 2 s after you leave). |
| **A3 Quick Stims** | **4 charges** (still half as long). |
| **B2 Strong Stim** | A bigger buff: +25% move and fire rate, 25% faster reload, 45% faster swap. |
| **B3 Strong Stim** | The zone lasts **twice as long** (16 s). |
| **G2 Heal Zone** ⚡ | No Stim. You and your team heal while standing in the zone: 7.5 HP/s, so **60 HP over the full 8 s** (about a Heal Orb). It looks like the Heal Orb (its colours and style) with the glitch static. |
| **G3 Heal Zone** ⚡ | **2 charges**. |

Confirmed by the user: the Strong Stim numbers, and B3 doubles only the zone (you still stay Stimmed 4 s after leaving).

## 9. Recall: decided 2026-11-03
L1: plant an anchor (free), press within 40 studs to teleport to it (0.6 s wind-up), the anchor stays all round; 2 hits break it. **Cooldown raised from 15 s to 20 s** (already changed in `Config/Mods`).

| Level | Effect |
|---|---|
| **A2 Recharge** | **10 s** cooldown. |
| **A3 Recharge** | **5 s** cooldown. |
| **B2 Long Range** | Teleport from **60 studs** away (150%). |
| **B3 Long Range** | **80 studs** (200%). |
| **G2 Crash Recovery** ⚡ | Passive: the first time you'd die in a round **while within 40 studs of your anchor**, you're pulled back to it at **1 HP** instead. Then the anchor breaks. Only works if the anchor is still standing. |
| **G3 Crash Recovery** ⚡ | You arrive with **40 HP** instead of 1. |

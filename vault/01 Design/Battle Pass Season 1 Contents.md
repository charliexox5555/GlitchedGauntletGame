# Battle Pass: Season 1 contents (2026-11-26)

First full list of what's in the Season 1 pass, for the owner to go through item by item. Powers, skin lines, charms, coins/tickets/cases and titles are owner-approved (2026-11-26). Season: 6 weeks, a tier per 30 min or 25 rounds won. Still open: final names. It replaces the placeholder tiers in `src/lobby/shared/SeasonCatalog.luau` once approved. The screen is in [UI Battle Pass](../02%20Art/UI%20Battle%20Pass.md).

## Changes (owner, 2026-11-27, after the loadout update)
- **Skins go to a random gun.** Like RIVALS' wraps, but these are real skins, not wraps. A skin tier names only its line. When it's claimed, the server rolls a gun the player **owns** that doesn't have that line yet. If they have it on every gun they own, it rolls from the guns they don't own yet; if every gun has it, the tier pays 500 coins (`Config/Season.SKIN_FALLBACK_COINS`). The Frostbite Knife (tier 30) stays fixed. In the table below, the gun names now only say which line each tier is; built in `Lobby/SeasonRewards.resolve`. Only guns that have a model for the line are rolled (`Locker.hasSkin`), and the rolled gun is saved per tier (`season.got`).
- **How a random-gun skin tile looks (owner 2026-11-27: "spinning reel").** Before the claim, the tile cycles the portraits of the guns this player could get (their own pool, 1.2 s per gun). Claiming spins it fast, slowing down, onto the rolled gun with a small pop, and from then on the tile shows that gun. The detail view shows a gun from the pool until it's claimed, then the rolled skin in 3D. Built in `BattlePassController` (reel), `SeasonPass.got` / `recordGot`, and the claim event carrying the gun.
- **Coins raised** (guns now cost 400-6,000, the set 30,900):
  - Premium: 500 / 650 / 750 / 900 / 1,000 / 1,200 = **5,000**, at tiers 3 / 7 / 11 / 16 / 22 / 27.
  - Free: 200 / 300 / 400 / 500 / 600 = **2,000**, at tiers 1 / 12 / 20 / 28 / 30.
  - In `SeasonCatalog`.
- **Goodie bags join Season 1.** 3 bags, at premium tier 14 and tiers 18 (free) and 19 (premium), kept in the Backpack and opened with the odds shown. One prize each (owner 2026-11-27): coins 58% (300-800), Tickets 18% (1-2), a Strike Box 9%, a SURGE power pack 7%, a Standard Case 5%, an Arcade skin for a random gun 3% (`src/shared/Config/GoodieBags.luau`). Built 2026-11-27.
- **Arcade and Frostbite are being made** (owner, 2026-11-27): [Arcade and Frostbite Handoff](../02%20Art/Skins/Arcade%20and%20Frostbite%20Handoff.md).
- **Charms go one per gun:** the player puts each charm on one gun, and it saves. Built by Antigravity: [Handoff - Charms](../05%20Production/Handoff%20-%20Charms%202026-11-27.md). A charm pack (like SURGE) comes later.

## Frame (kept from the placeholder)
- 30 tiers. Free track for everyone, premium track **689 Robux**, **+5 levels 499 Robux**.
- A late premium buyer gets every premium tier already reached. Unclaimed rewards are paid when the season ends.
- Free track = a taste (about 1 reward every 3 tiers). Premium = something every tier, a skin every 3 to 4 tiers.

## Instant on buying premium
- Title **SEASON 1** (placeholder name, see Titles).
- Gold name in the lobby (already listed as a perk).

## New content the pass needs
- **Skin line A, "Arcade"** (Rare: shape change; theme picked by the owner 2026-11-26): neon arcade cabinet, coin slot, joystick and button details, pixel-screen panels. 8 guns. Classic (the one free skin), Vandal, Sheriff, Spectre, Ghost, Bulldog, Marshal, Operator.
- **Skin line B, "Frostbite"** (Legendary: animation + its own sounds, the chase line; owner 2026-11-26): faceted ice crystal over dark metal, cold blue-white glow, ice that grows on inspect and cracks on kill. Guns: Phantom, Guardian (Marksman), Vandal, Knife (the Outlaw/TwinShot was removed from the game on 2026-11-27; its slot went to the Marksman, which had no pass skin).
- **8 charms** (2 free, 6 premium), owner-approved 2026-11-26. See Charms below. There's no charm system yet, so this needs building.
- **2 new powers**: **Smoke** (free) and **Electric Shock** (premium). See Powers below.
- **Titles shown in game.** Champion is saved but not displayed yet.

## Tier list
| Tier | Free | Premium |
|---|---|---|
| 1 | 100 coins | Arcade **Vandal** |
| 2 | — | Charm: **Joystick** (Rare) |
| 3 | Standard Case | 250 coins |
| 4 | — | 1 Ticket |
| 5 | — | Arcade **Sheriff** |
| 6 | Charm: **Arcade Token** (Common) | Standard Case |
| 7 | — | 300 coins |
| 8 | 1 Ticket | Charm: **Pixel Heart** (Rare) |
| 9 | — | Arcade **Spectre** |
| 10 | **Smoke (power unlock)** | Elite Case |
| 11 | — | 350 coins |
| 12 | 150 coins | Charm: **Game Cartridge** (Epic) |
| 13 | — | Arcade **Ghost** |
| 14 | — | 2 Tickets |
| 15 | **Arcade Classic (the free skin)** | Frostbite **Phantom** |
| 16 | — | 400 coins |
| 17 | — | Charm: **Snowflake Shard** (Rare) |
| 18 | Standard Case | Arcade **Bulldog** |
| 19 | — | Elite Case |
| 20 | 200 coins | **Electric Shock (premium-only power)** |
| 21 | — | Arcade **Marshal** |
| 22 | 1 Ticket | 450 coins |
| 23 | — | Charm: **Thunder Orb** (Epic) |
| 24 | — | Frostbite **Marksman** (Guardian; was the Outlaw, removed 2026-11-27) |
| 25 | Charm: **Ice Cube** (Rare) | Apex Case |
| 26 | — | Arcade **Operator** |
| 27 | — | 500 coins |
| 28 | 250 coins | Charm: **High Score** (Legendary) |
| 29 | — | Frostbite **Vandal** |
| 30 | 300 coins | Frostbite **Knife** + title **FROSTBITTEN** |

## Totals (coins and tickets kept as drafted, owner 2026-11-26)
| | Free | Premium |
|---|---|---|
| Skins | 1 (Arcade Classic) | 11 (7 Arcade, 4 Frostbite incl. Knife) |
| Charms | 2 | 6 |
| Powers | Smoke at 10 | Electric Shock at 20 (premium only) |
| Coins | 2,000 (was 1,000) | 5,000 (was 2,250) |
| Tickets | 2 | 3 |
| Cases | 2 Standard | 1 Standard, 2 Elite, 1 Apex |
| Titles | — | SEASON 1 (on buying), FROSTBITTEN (tier 30) |

Value check: 2,250 coins is about the 199 Robux pack on its own. 11 skins at shop prices (Rare 349, Legendary 649) are worth far more than 689, so premium is an easy yes. Free coins are 1,000 against the Path's 12,850, so the pass doesn't flood the economy.

## Powers (owner, 2026-11-26)
- **Free track: Smoke** at tier 10. Players who haven't reached tier 10 don't get Smoke offered in their draft.
- **Premium: Electric Shock** at tier 20, premium only, and meant to be a bit better than the free powers. The owner accepts slight pay-to-win on purpose: "still needs skill, but slight ptw", like RIVALS selling better weapons and upgrades. This overrides the old "pay-to-win check" rule for this power only.
- Both still follow the [Look & sound standard](Abilities/00%20Abilities.md#look--sound-standard-every-ability-this-is-not-optional).

**Smoke (draft, numbers to tune):** throw a canister (arc like Molly). It pops into a smoke dome about 12 studs across for about 10 s that blocks sight both ways. Bullets still pass through. 1 charge per round. A/B/G paths come later.

**Electric Shock (owner idea; lock-on approved 2026-11-26):** you throw it, and if it catches a player, lightning blasts down on them and does damage. It has to feel different from **Shock Dart** (bow bolt that explodes where it lands, with a bolt cracking down onto the spot). The difference (approved): Electric Shock **locks onto a player**. The thrown orb latches onto the first enemy it passes within about 4 studs of, a 0.5 s warning ring shows on them, then the strike lands on them wherever they moved (about 70 damage plus a short Hinder). If it reaches nobody, it fizzles. 1 charge per round. Numbers are to tune.

## Charms (owner, 2026-11-26)
They hang from the charm ring every gun already has (`CharmPoint`, `Charm` bone: [Art Direction](../02%20Art/Art%20Direction.md)). They're faceted shapes per the build rules, and the names are placeholders.

| Charm | Rarity | Track, tier | Look / extra |
|---|---|---|---|
| Arcade Token | Common | Free 6 | arcade coin token |
| Ice Cube | Rare | Free 25 | faceted ice cube |
| Joystick | Rare | Premium 2 | mini arcade stick |
| Pixel Heart | Rare | Premium 8 | faceted pixel heart |
| Snowflake Shard | Rare | Premium 17 | ice snowflake |
| Game Cartridge | Epic | Premium 12 | cartridge; small glint/spark extra |
| Thunder Orb | Epic | Premium 23 | crackles with electricity (Electric Shock tie-in) |
| High Score | Legendary | Premium 28 | a pixel screen that counts your kills this match |

**Motion:** every charm swings on its ring when you move, turn and shoot. Epic charms add a small effect. The Legendary charm reacts to the game (High Score ticks up on a kill, server-sent kill count only).

## Titles (locked by the owner, 2026-11-26)
**Both.** Buying premium gives a title straight away, and tier 30 gives a better one.
- **Buy premium:** **SEASON 1** (placeholder). It shows you bought the pass, and it's an advert every time someone sees it.
- **Premium tier 30:** **FROSTBITTEN** (placeholder), next to the Frostbite Knife. It's the flex title because you only get it by playing the whole pass.
- **Free track:** no title, so having one stays a reason to buy.
- **Equipping (owner idea):** a Titles section in your profile where you pick one. A new title auto-equips only when you have none on, and otherwise shows a toast with EQUIP. Champion (from the Task Path) shows up there too.
- **Later:** name tags over players (level, title, streak) are parked in [Bugs & Ideas](../05%20Production/Bugs%20%26%20Ideas.md).

## Season length and tiers (owner, 2026-11-26)
- **6 weeks.**
- **How you go up a tier (RIVALS-style, not XP):** one tier every **30 minutes in matches** OR every **25 rounds won**, whichever comes first. Both meters reset when you go up. The pass shows both, e.g. "12:40 LEFT OR 9 ROUNDS".
- **What counts:** only time in live rounds (not the lobby, the Range or between rounds). Bot-only matches count at half speed, like game XP. **First win of the day: +5 rounds.**
- **Pace:** finishing on time alone takes 15 h (about 21 min a day over 6 weeks). Good players finish sooner through rounds. 10 min a day reaches about tier 14: Smoke yes, the free Arcade Classic (tier 15) just out of reach, which is where +5 LEVELS sells.
- Season levels stay separate from game level and game XP. The counts are saved in the same match-end write as XP (ProgressionService), with the server as the only source.

## Flags to settle
1. ~~Powers vs "all Mods free"~~ **Settled 2026-11-26**, see Powers.
2. **Cases on premium (owner 2026-11-26):** cases stay on the premium track for everyone, as listed. There's **no country check and no swap**: the owner says games like RIVALS don't do it and it's too much work. If Roblox raises a problem, the owner will talk to them and change it then. The odds still show like the shop's.
3. ~~Season XP rule and length~~ **Settled 2026-11-26**, see Season length and tiers.
4. Names: line themes are set (Arcade, Frostbite), but the final line names, the title names and the charm names are still placeholders. Which theme is Rare and which is Legendary was Claude's call (Arcade Rare, Frostbite Legendary); the owner can swap them. Both lines stay out of the case pool.
5. No emotes this season (owner, 2026-11-26). The placeholder emote tiers are gone.

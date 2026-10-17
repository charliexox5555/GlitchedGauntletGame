# Ability Drafting, In-Match Upgrades, Random Modifiers and Between-Round Shops: Design Notes for a Roblox Draft Shooter

> Method note (Oct 17 2026): the sandbox's egress policy blocked WebFetch and curl for every external domain tried (beebom.com, dotesports.com, esports.gg, tracker.gg, playvalorant.com, vlr.gg, games.gg, allthings.how, idcgames.com). Every finding below therefore comes from WebSearch result summaries and snippets, not from full-page reads. Exact numbers should be treated as "reported by the cited page" and checked against the original before being quoted as fact. Where sources disagreed, both versions are listed.

## 1. Valorant "Gauntlet: Glitched" (Patch 13.06): draft flow, ability pool, L1–L3 upgrades, glitches, health/elimination, rounds, arenas, economy, reception

### Takeaway
Gauntlet: Glitched (live Sept 22 2026) is a 16-player, 8-duo 2v2 elimination tournament. Players build a KAY/O-like "Robo-Agent" by drafting abilities from a random pool between rounds. Each draft offers a new ability or an upgrade (L1 to L3, with a two-way branch at L2), and there is a rare random "glitch" chance from L2 that changes how an ability works. Each duo has a shared 100 HP pool, and the damage taken per lost round rises by stage. Rounds last 40 s, and there is no credit economy: players get a pick-1-of-3 weapon offer tiered by stage. Matches run about 8–15 min. Reception is thin but positive. The main complaint found was a launch bug that stopped players leaving the Death Cam.

### Cited Findings
**Launch and format**
- Patch 13.06 went live September 22, 2026, with Gauntlet: Glitched, the Warden rifle and Agent Mastery. — [Sheep Esports](https://www.sheepesports.com/en/articles/valorant-patch-13-06-adds-new-gauntlet-mode-warden-rifle-and-agent-mastery/en); [IDC Games](https://idcgames.com/en/valorant/news/valorant-patch-13.06-introduces-the-warden-rifle,-gauntlet-glitched-and-agent-mastery-2026-09-15-07-45-13851); [Dot Esports patch notes](https://dotesports.com/valorant/news/valroant-patch-13-6-notes)
- 16 players form 8 two-person teams in a round-robin-style tournament that runs until one duo remains. — [Beebom](https://beebom.com/valorant-gauntlet-glitched-mode/); [Shane the Gamer](https://www.shanethegamer.com/news/valorant-gauntlet-glitched-game-mode/); [IDC Games reveal](https://idcgames.com/en/valorant/news/valorant-unveils-gauntlet-glitched,-a-16-player-roguelike-mode-built-around-custom-agents-2026-09-15-09-00-13857)
- A match is said to run about 8–15 minutes. — [games.gg guide](https://games.gg/valorant/guides/valorant-gauntlet-glitched-guide/). One guide says this is a design expectation, not a measured average. — [1v9.gg](https://1v9.gg/blog/valorant-gauntlet-glitched-guide)
- The mode replaced Retake in the mode rotation. Sources disagree on whether it is limited-time or may become permanent. — [allthings.how](https://allthings.how/valorant-13-06-adds-the-warden-rifle-and-gauntlet-glitched-mode/); [tracker.gg](https://tracker.gg/valorant/articles/valorant-new-gauntlet-mode-preview-release-date-and-more); [valorant-spind.de](https://www.valorant-spind.de/en/valorant-gauntlet-glitched.html) (calls it limited-time)

**Robo-Agent and draft flow**
- Players do not pick a named Agent. They control a hybrid robot that looks like KAY/O and assemble its kit from other Agents' abilities. — [allthings.how 8-duo explainer](https://allthings.how/valorant-gauntlet-glitched-how-the-8-duo-ability-draft-mode-works/); [talkesport](https://www.talkesport.com/news/valorant/valorant-gauntlet-glitched-mode-release-date/)
- Each round opens with an ability draft. Teams either take a new ability or upgrade one they own, from Level 1 up to Level 3. — [Beebom](https://beebom.com/valorant-gauntlet-glitched-mode/); [allthings.how 2v2 explainer](https://allthings.how/gauntlet-glitched-in-valorant-how-the-2v2-roguelike-mode-works/)
- Draft options are randomized, and one guide says the pool is not fixed in advance. — [games.gg](https://games.gg/valorant/guides/valorant-gauntlet-glitched-guide/)
- **Upgrade branching:** moving to Level 2 means picking one of two paths, and Level 3 powers up exactly the path chosen. A Level 3 upgrade can change an ability's function entirely, not just its strength. — [valorant-spind.de](https://www.valorant-spind.de/en/valorant-gauntlet-glitched.html); [topuplist guide](https://topuplist.com/blogs/detail/valorant-gauntlet-glitched-guide-rules-ability-upgrades)
- Documented L3 upgrades: Yoru's Fakeout fires bullets on its own, Skye's Trailblazer becomes a giant wolf/animal that can kill in one bite, and Gekko's Wingman becomes much larger. — [Sportskeeda mastersheet](https://www.sportskeeda.com/valorant/valorant-gauntlet-glitched-mastersheet-features-abilities-everything-need-know); [Dot Esports reveal](https://dotesports.com/valorant/news/valorant-gauntlet-glitched-reveal)
- Abilities reported in the pool include Tejo's Guided Salvo, Deadlock's Gravnet, Fade's Haunt, Raze's Blast Pack and Boom Bot, Jett's Cloudburst, Omen's Shrouded Step, Astra's Nebula, Gekko's Dizzy and Wingman, Sage's Barrier/Healing Orb, Phoenix's Blaze and Skye's Trailblazer. Upgrade paths for most of them were not confirmed. — [Sportskeeda mastersheet](https://www.sportskeeda.com/valorant/valorant-gauntlet-glitched-mastersheet-features-abilities-everything-need-know); [VALORANT Wiki](https://wiki.playvalorant.com/en-us/Gauntlet:_Glitched)

**Glitches**
- Riot describes glitches as a "rare, random chance" and publishes no percentage. — [Sheep Esports / search summary](https://www.sheepesports.com/en/articles/valorant-patch-13-06-adds-new-gauntlet-mode-warden-rifle-and-agent-mastery/en)
- A glitch can occur from Level 2 onward and transforms the ability. Riot's own examples are Raze's Boom Bot and Gekko's Wingman. — [valorant-spind.de](https://www.valorant-spind.de/en/valorant-gauntlet-glitched.html); [Dot Esports reveal](https://dotesports.com/valorant/news/valorant-gauntlet-glitched-reveal)
- The official wiki has a table pairing each base ability with its glitch name and the glitch's own L3 upgrade. Examples: Jett Cloudburst becomes "CoveBurst", Boom Bot becomes "C4 Bot", Barrier Orb becomes "Beanstalk", and Blaze becomes "BE WATER". — [VALORANT Wiki](https://wiki.playvalorant.com/en-us/Gauntlet:_Glitched)
- Spind counts about 20 community-documented glitches, each with its own name and L3 upgrade. Example: Healing Orb becomes "Emphasis on Shield", which no longer heals and instead grants a shield against one source of damage. In other words, glitches are often sidegrades that change an ability's role, not pure buffs or nerfs. — [valorant-spind.de](https://www.valorant-spind.de/en/valorant-gauntlet-glitched.html)

**Health, elimination, rounds**
- Each duo has a shared health pool. Losing a round costs pool HP, and a duo at 0 is eliminated. — [allthings.how 2v2](https://allthings.how/gauntlet-glitched-in-valorant-how-the-2v2-roguelike-mode-works/)
- Every duo starts with 100 HP. The damage for a loss scales by stage: Stage 1 −10, Stage 2 −10, Stages 3–5 −20, Stages 6–7 −30. — [valorant-spind.de](https://www.valorant-spind.de/en/valorant-gauntlet-glitched.html). The 100 HP figure appeared in only one or two guide-type sources. One search summary called the starting total "unconfirmed".
- Rounds last 40 seconds and are played in sets of three within a stage. Each round sends teams to one of four arenas. — [valorant-spind.de](https://www.valorant-spind.de/en/valorant-gauntlet-glitched.html) (single source for the 40 s figure)

**Arenas**
- There are four arenas, inspired by existing bomb-mode maps (Breeze, Icebox and Corrode are cited) and tuned for 2v2. 1v9.gg notes that these are source maps, not verified arena names. — [games.gg](https://games.gg/valorant/guides/valorant-gauntlet-glitched-guide/); [1v9.gg](https://1v9.gg/blog/valorant-gauntlet-glitched-guide)

**Economy and weapons**
- There is no credit economy and no Spike. — [games.gg](https://games.gg/valorant/guides/valorant-gauntlet-glitched-guide/)
- After every round each player is offered one weapon out of three. Weapon offers stay fixed within a stage and can refresh when a new stage begins. Tiers are reported as: early stages offer pistols and SMGs (Ghost, Sheriff, Bandit, Shorty), later stages offer rifles and snipers (Warden, Phantom, Vandal, Judge/Odin). — [valorant-spind.de](https://www.valorant-spind.de/en/valorant-gauntlet-glitched.html); [games.gg](https://games.gg/valorant/guides/valorant-gauntlet-glitched-guide/)
- metabot.gg discusses eco and buy rounds in Gauntlet. This contradicts the other sources and looks poorly sourced. — [metabot.gg](https://metabot.gg/en/valorant/map/Gauntlet/weapons)
- The Warden is a new 2,900-credit automatic rifle with a 2x scope and 50 body damage at any range. — [Games Press dev update](https://www.gamespress.com/en-US/VALORANT-Dev-Update-New-Game-Mode-Automatic-Rifle-Agent-Mastery-System)

**Reception**
- A VLR.gg forum post calls the mode fun and possibly Riot's best limited-time mode so far. Its main suggestion is that some upgrades should carry drawbacks, for example a shorter cooldown that costs health, to add decision-making. This is a single user's opinion. — [VLR.gg thread](https://www.vlr.gg/758533/gauntlet-glitch)
- Riot Support acknowledged a bug (notice dated Sept 23 2026) where the Death Cam in Gauntlet: Glitched would not let players leave the match. — [Riot Support](https://support.riotgames.com/en-us/valorant/performance/gauntlet-glitched-death-cam-issue)
- Guide coverage describes the mode as a departure for players bored with standard sessions and says ranked-oriented players will need to adjust. A coaching-marketplace piece (promotional) argues it rewards understanding ability interactions over Agent mastery. — [games.gg](https://games.gg/valorant/guides/valorant-gauntlet-glitched-guide/); [ggclan.com](https://ggclan.com/news/valorant-gauntlet-glitched-mode-ability-builder-guide)
- One outlet frames the mode as a warm-up alternative to Deathmatch. — [valorantcrosshairdb](https://www.valorantcrosshairdb.com/blog/valorant-gauntlet-glitched-guide/)

### Inferences
- The core loop transfers directly to a Roblox gun game: short rounds (about 40 s), a draft between every round, a branch at L2, a function-changing L3, and a shared team HP pool whose loss damage scales by stage. Scaling the loss damage acts as a built-in match-length limiter, because late losses hurt more and the tournament resolves quickly.
- Replacing an economy with a stage-tiered weapon offer removes buy-menu time and the CS-style snowball. This fits a target draft phase under 20 s.
- Making glitches sidegrades that change an ability's role (heal becomes shield), rather than straight nerfs, plus giving each glitch its own L3, keeps them from feeling like punishment. The VLR feedback asking for "upgrades with drawbacks" suggests players want visible, chosen trade-offs, not only hidden random ones.

### Gaps
- Pick timer length, number of options per draft, whether both duo partners draft independently, whether opponents' builds are visible, and how matchmaking pairs duos (true round-robin or Swiss) could not be confirmed. Full pages were unreachable.
- Glitch probability is unpublished by Riot.
- No arena names, no official Riot patch-note text (playvalorant.com unreachable), and no broad Reddit or press critique were found. Reception evidence is very thin: one forum thread and a bug notice.

## 2. Overwatch 2 Stadium (2025): powers, items, between-round shop, build crafting, reception

### Takeaway
Stadium is a round-based, best-of-7 (first to 4 in Ranked) third-person/first-person mode. Players pick one of 12 hero-specific Powers before rounds 1, 3, 5 and 7, up to 4 total, and buy sell-back Items with Stadium Cash between rounds. Build-crafting was the most-praised element in playtests. Snowballing, stomps and matchmaking were the main complaints, and later coverage describes declining developer support.

### Cited Findings
- Each hero has 12 Powers. You pick one before rounds 1, 3, 5 and 7, for a maximum of four. Powers modify the hero's kit. — [esports.gg powers](https://esports.gg/news/overwatch/all-overwatch-2-stadium-powers-and-how-they-work); [Sportskeeda S16 notes](https://sportskeeda.com/esports/overwatch-2-season-16-patch-notes-stadium-released-new-hero-freja)
- At Season 16 launch, Powers could not be removed once equipped. — [Gfinity S16 notes](https://www.gfinityesports.com/article/overwatch-2-season-16-patch-notes)
- Items are bought with Stadium Cash, with 3,500 at game start. Cash is earned each round from sources including enemy bounties. Items can be sold back for full value. Items are Global (Weapon, Ability and Survival categories) or hero-specific. Prices range from 1,000 (Compensator, +5% weapon power) to 4,000 (Shieldbuster, Advanced Nanobiotics) for the higher tiers. — [esports.gg items](https://esports.gg/news/overwatch/every-overwatch-2-stadium-item-and-their-costs/); [Destructoid](https://www.destructoid.com/all-items-and-powers-in-overwatch-2-stadium/); [The Backdash](https://thebackdash.com/gaming/overwatch-2-stadium-mode-guide-all-powers-items-their-stadium-cash-cost)
- Win condition: first to four round wins. Blizzard lists first-to-3 (Quick Play) and first-to-4 (Ranked) defaults. Cash can be tied to MVP, bounties or healing. — [Blizzard news](https://news.blizzard.com/en-us/article/24226737/); [Blizzard "Keys to Victory"](https://overwatch.blizzard.com/en-us/news/24191424/)
- A Mercy Rule ends the match at round 3 if the winning team has 15,000 more Stadium Cash than the losers. Another launch report says it ends the match if a team loses the first three rounds. Sources conflict, and the rule likely changed by season. — [esports.gg/search summary](https://esports.gg/news/overwatch/every-overwatch-2-stadium-item-and-their-costs/); [Sportskeeda](https://sportskeeda.com/esports/overwatch-2-season-16-patch-notes-stadium-released-new-hero-freja)
- Playtest learnings: thousands of alpha testers came back for at least 5 of 7 four-hour sessions, and the number-one comment was the fun of creating hero builds. Blizzard fixed a Cassidy build that could one-shot 350+ HP heroes, nerfed overly powerful builds, and added items that counter powerful builds. — [Blizzard "Lessons Learned from the Playtests"](https://overwatch.blizzard.com/en-us/news/24191421/enter-the-stadium-lessons-learned-from-the-playtests/)
- Blizzard said that "snowballing was also an issue in some matches, and even with bounties on key targets, a leading team could access its more powerful items faster than the team catching up." — [Blizzard Lessons Learned](https://news.blizzard.com/en-us/article/24191421/enter-the-stadium-lessons-learned-from-the-playtests)
- Blizzard reverted a move of Stadium Ranked to best-of-five after weeks of critical feedback, because players "missed the strategic joy of longer games, countering your opponents' builds, and the possibility of glorious comeback runs in a close series." — [Blizzard Director's Take](https://overwatch.blizzard.com/en-us/news/24246201); [VPEsports](https://vpesports.com/games/overwatch/overwatch-2-the-return-of-the-up-to-4-wins-format-to-the-stadium)
- Season 19 changes cut first-round cash rewards and the MVP and heal-damage bonuses, which reduces the snowball inputs. — [VPEsports](https://vpesports.com/games/overwatch/overwatch-2-the-return-of-the-up-to-4-wins-format-to-the-stadium)
- Forum complaints cover balance, long matches, slow balance patches, and premade-vs-solo matchmaking. "The number 1 issue is Stomps/MM imbalance." — [Blizzard Forums "So is Stadium a failure?"](https://us.forums.blizzard.com/en/overwatch/t/so-is-stadium-a-failure/972764)
- MassivelyOP (June 2026): "Stadium is, at a baseline, still a great mode, but it's suffering from a lack of developer support and a confused vision." — [MassivelyOP](https://massivelyop.com/2026/06/03/not-so-massively-the-state-ium-of-overwatch-stadium-in-2026/)
- Gfinity reports Stadium was about 6% of daily play and that Blizzard stopped expanding it. Not verified against a Blizzard primary source. — [Gfinity](https://www.gfinityesports.com/article/how-overwatch-fumbled-its-most-promising-mode); [GosuGamers](https://www.gosugamers.net/entertainment/news/78803-overwatch-to-stop-expanding-stadium-as-blizzard-shifts-focus-to-other-game-modes)
- Insider Gaming framed Stadium as borrowing from Deadlock and Valorant. — [Insider Gaming](https://insider-gaming.com/overwatchs-stadium-a-round-based-competitive-mode-that-borrows-from-deadlock-valorant/)

### Inferences
- Powers on alternating rounds (1/3/5/7) with a cap of 4 is a cadence for "big decisions" that leaves even rounds for smaller shop tweaks. A Roblox game could alternate "ability draft" rounds with "stat/upgrade" rounds to keep each pre-round phase short.
- Selling items back at full value lets players pivot and counter-build cheaply. Bounties alone were not enough to stop snowballing, so catch-up needs to be structural (loss-scaled income or capped tiers), not only bounties.
- Long matches were a stated complaint, yet players rejected best-of-5. Stadium players value the comeback arc. A short Roblox format should keep some room to come back (for example, a shared HP pool) rather than single-elimination best-of-1.

### Gaps
- Exact Stadium cash-per-round formula, shop timer length, and current mercy-rule values could not be confirmed (pages unreachable).

## 3. Other comparables: Deadlock, Brawl Stars, Battlerite, Dota 2 Ability Draft, Rumbleverse, CS2/Valorant economy, Splitgate 2 / The Finals, Marvel Rivals, Rocket League Rumble

### Takeaway
The useful patterns are: Dota's Ability Draft (snake order, 7 s per pick, random auto-pick on timeout, combo denial); Rocket League Rumble's mirrored power-up queue (both teams get the same random items in the same order); CS2's capped, escalating loss bonus; Deadlock's three-category shop with an investment bonus; Brawl Stars' layered gadget/star power/hypercharge, which shows the risk of persistent unlocks; and The Finals' fixed loadout slots.

### Cited Findings
**Dota 2 Ability Draft**
- Each player starts as a random hero with no abilities. The pool comes from the 10 players' heroes plus 2 extra random heroes, giving about 48 regular abilities and 12 ultimates. Some abilities (Tempest Double, Morph) are excluded. — [Liquipedia](https://liquipedia.net/dota2/Ability_Draft); [bo3.gg](https://bo3.gg/dota2/articles/dota-2-ability-draft-guide)
- Each player takes 3 regular abilities and 1 ultimate in a snake order, with Radiant first, over 4 rounds. Each pick has a 7-second limit, and missing it assigns a random remaining ability. There is a planning phase of about 60 s. A Steam changelog mentions a 12 s single-player pick time, minus 1 s per additional teammate (status unclear). — [Liquipedia](https://liquipedia.net/dota2/Ability_Draft); [Steam changelog](https://steamcommunity.com/sharedfiles/filedetails/changelog/2967572098?p=5)
- Early picks often cannot complete combos. Later picks can finish combos or deny key abilities to opponents. — [bo3.gg](https://bo3.gg/dota2/articles/dota-2-ability-draft-guide)
- GosuGamers covered a "random ability draft" variant. — [GosuGamers](https://www.gosugamers.net/dota2/features/37701-one-player-s-take-on-the-new-random-ability-draft-mode)

**Rocket League Rumble**
- Released 2016 with 11 randomized power-ups. Each player has a 10 s power-up timer that resets at kickoff and after use. When it hits 0, a random power-up becomes available. — [Rocket League wiki](https://rocketleague.fandom.com/wiki/Rumble); [PC Gamer](https://pcgamer.com/rocket-leagues-free-rumble-mode-rolls-out-today)
- Power-ups: The Boot, Disruptor, Freezer, Grappling Hook, Haymaker, Magnetizer, Plunger, Power Hitter, Spike, Swapper, Tornado. — [Epic Games help](https://www.epicgames.com/help/rocket-league-c-202300000001622/gameplay-c-202300000001682/what-is-rumble-mode-in-rocket-league-a202300000014075)
- **Mirror fairness:** in online Rumble, the same power-ups go to both teams, and each team gets the same power-up queue in the same order. In non-3v3 private matches, power-ups are random per player. — [Rocket League wiki](https://rocketleague.fandom.com/wiki/Rumble)

**CS2 economy (catch-up)**
- Loss bonus ladder: $1,400, $1,900, $2,400, $2,900, then $3,400 from the fifth straight loss (+$500 per loss, capped). A round win resets the counter. Each half starts at $800, with a $16,000 cap. Win rewards are about $3,250–$3,500 (figures vary by source/version). — [csdb.gg](https://csdb.gg/guides/economy-guide/); [Supercraft wiki](https://supercraft.host/wiki/counter-strike-2/economy-guide); [KeenGamer](https://www.keengamer.com/articles/guides/a-guide-to-how-the-cs2-economy-works-in-counter-strike-2)

**Deadlock**
- Souls are the single currency, earned from objectives, minions and hero kills, and spent at Curiosity Shops. Items fall into Weapon, Vitality and Spirit. The loadout holds 12 items. Each category has 4 price tiers (about 500/1,250/3,000/6,200+ in one guide, 800/1,600/3,200/6,400 in a July 2026 snapshot). Investing more souls in one category raises a passive investment bonus. Expensive items build up from cheaper ones, and you pay only the difference. Each tier is a noticeable power breakpoint. — [metabot.gg Deadlock](https://metabot.gg/en/deadlock/guides/deadlock-items-shop-system-explained); [Dignitas](https://dignitas.gg/articles/understanding-items-in-deadlock); [deadlockmod.com](https://deadlockmod.com/guides/reading-the-shop-and-soul-curve)

**Brawl Stars**
- Hypercharge is a temporary state that greatly boosts a Brawler's abilities. It charges by dealing damage, separately from the Super bar. — [gametutorials guide](https://gametutorials.duckdns.org/posts/unleash-your-brawling-potential-the-ultimate-guide-to-star-powers-and-gadgets-for-every-brawler/) (low-quality source)
- In July 2023 Supercell admitted an "ongoing issue with the viability of certain brawlers' Gadgets and Star Powers". The April 2025 changes cut Hypercharge charge rates and raised Gadget cooldowns for many Brawlers. — [Mobile Matters](https://mobilematters.gg/brawl-stars/brawl-stars-balance-changes-july-2023); [esports.net](https://www.esports.net/news/mobile-games/brawl-stars-balance-changes-april-2025/)
- A progression guide says "the competitive game is between fully-finished brawlers; everything else is sub-competitive". Maxing one Brawler costs about 6–8k coins plus 5–8k power points. — [GuildOrder](https://guildorder.com/th/games/brawl_stars/guides/brawler-mastery-progression)

**Battlerite / Battlerite Royale**
- Battlerite Royale (2018): 20-player FFA or duos. Players pick a Battlerite loadout before the match, but abilities must be found in the world. Extra random Battlerites found during the match push the loadout past the usual five. Champions start with 50% less max HP than in Arena, and HP can be raised with items. — [TheGamer](https://www.thegamer.com/moba-battlerite-battle-royale-announcement/); [Stunlock dev update](https://blog.stunlock.com/dev-update-may-24/)

**The Finals / Splitgate 2**
- The Finals loadout: 1 Weapon, 3 Gadgets, 1 Specialization per class. Season 2 added the Dematerializer specialization. — [esports.gg](https://esports.gg/guides/the-finals/all-new-weapons-gadgets-and-specializations-in-the-finals-season-2); [Dexerto](https://www.dexerto.com/gaming/5-tips-for-the-finals-season-2-gadgets-2601767/)
- Splitgate: faction abilities were removed in "Arena Reloaded", and faction restrictions on equipment were removed. Dexerto's older guide lists faction-specific perks. — [Splitgate wiki](https://splitgatearenareloaded.wiki.gg/wiki/Ability); [Dexerto](https://www.dexerto.com/gaming/every-perk-in-splitgate-2-2863663/)

### Inferences
- Rocket League Rumble's mirrored queue is the clearest precedent for "fair randomness" in a team PvP mode. Applying it to the draft (both teams see the same offer set) removes most RNG complaints in 1v1/2v2/3v3.
- Dota's 7 s per pick with random auto-pick is proof that sub-10 s picks work for experienced players. Snake order matters only when picks come from one shared pool. Independent personal offers avoid the need for it.
- A capped, escalating loss bonus (CS2) is a well-understood catch-up model. In a no-currency draft game the same idea can be expressed as "the losing side gets an extra reroll or a higher rarity floor".
- Brawl Stars shows that persistent, grind-locked ability unlocks split the playerbase into "maxed" and "sub-competitive". Keeping all draft power inside the match (reset every match) avoids that pay-to-win perception, which matters on Roblox.

### Gaps
- No usable results on Rumbleverse perk cards, Marvel Rivals team-ups, or Battlerite's arena draft/ban system. Valorant's standard loss-bonus numbers were not retrieved.

## 4. Roguelike draft design: Hades, Slay the Spire, Vampire Survivors, Brotato, TFT augments (pick-from-3, rarity, synergy, reroll, weighting, pity)

### Takeaway
The proven toolkit is: pick 1 of 3; rarity tiers with context-dependent odds (elite/boss rewards better); a hidden rarity "offset" for bad-luck protection (Slay the Spire); prerequisite-gated synergy picks (Hades Duo boons); limited player-controlled pool editing (Vampire Survivors Reroll/Skip/Banish); escalating reroll cost and shop locks (Brotato); and fixed augment rounds at set stages (TFT).

### Cited Findings
**Slay the Spire**
- Card reward rarity: normal combats about 3% rare / 37% uncommon / 60% common, elites 10/40/50, bosses always rare, shops 9/37/54. — [StS Fandom wiki](https://slay-the-spire.fandom.com/wiki/Card_Rewards); [slaythespire.wiki.gg](https://slaythespire.wiki.gg/wiki/Card)
- **Pity offset:** the offset starts at −5% and rises +1% per common rolled. Rolling a rare resets it to −5%. It caps at +40%. Only card rewards affect it (not shop or Library cards). — [StS Fandom wiki](https://slay-the-spire.fandom.com/wiki/Card_Rewards)
- The first floor of each act cannot give a Rare (with exceptions). — [StS wiki](https://slay-the-spire.fandom.com/wiki/Card_Rewards); [Steam discussion](https://steamcommunity.com/app/646570/discussions/0/594015710347314793)

**Hades / Hades II**
- Boons from Erebus encounters, mini-bosses, or bought at a higher price from Charon (Styx) are more likely to be higher rarity. — [Hades Fandom wiki](https://hades.fandom.com/wiki/Boons?oldid=6594)
- Hades II rarity tiers: Common, Rare, Epic, Heroic. A Pom of Power adds one level to a boon. Duo, Legendary and Infusion boons cannot be Pom'd. Chaos boons in Hades 1 cannot be Pom'd or sold. — [Hades II Fextralife](https://hades2.wiki.fextralife.com/Boon); [Rogue Ranker](https://rogueranker.com/hades-2-boons/)
- Duo boons need the player to already own qualifying boons from both gods. In Hades II they appear after at least two compatible boons from each god (for example Natural Selection from Poseidon + Demeter). — [Prima Games](https://primagames.com/tips/hades-what-are-duo-boons-how-get-duo-boons); [Hades II Fextralife: Natural Selection](https://hades2.wiki.fextralife.com/Natural+Selection)

**Vampire Survivors**
- Level-up tools: Reroll, Skip, Banish. Players Banish early to raise the odds of wanted items later. Skip passes without taking a slot. The Preserve powerup gives each a 10% per rank (max 50%) chance not to be consumed. — [Steam discussion](https://steamcommunity.com/app/1794680/discussions/0/3276941718958957262); [VS wiki Preserve](https://vampire.survivors.wiki/w/Preserve)

**Brotato**
- Locking a shop item keeps its price and holds it until bought or unlocked. Reroll cost rises with each reroll in the same shop (no cap on count), scales with wave, and resets each new shop. Level-up rerolls use the same pricing but are tracked separately. — [Brotato wiki Shop](https://brotato.wiki.spellsandguns.com/Shop)

**TFT augments**
- Three augment rounds per game, typically Stage 2-1, 3-2 and 4-2 (one guide says 1-4, 3-3, 4-6 in some sets). Each offers 3 choices across Silver/Gold/Prismatic tiers. Reroll allowances changed by set (one reroll per slot, later up to 3 per armory, and hero-augment rerolls). — [metabot.gg TFT](https://metabot.gg/en/TFT/guides/tft-augments-explained-silver-gold-prismatic); [esports.gg TFT tips](https://esports.gg/guides/teamfight-tactics/top-3-tips-and-tricks-for-using-tft-augments-to-climb-ranks); [Dot Esports](https://dotesports.com/tft/news/how-tft-set-9-9-5-augments-work-all-evergreen-and-legend-tft-augments)
- Riot (Dragonlands learnings): "we're committed to increasing focus and resources to make sure that Augments are better balanced and fun at all points in the game." Riot will avoid early-game economy augments: "An 8-gold-per-turn trait that you can't get until Stage 4 or later doesn't warp things too much." — [Riot TFT /Dev](https://teamfighttactics.leagueoflegends.com/en-au/news/dev/dev-teamfight-tactics-dragonlands-learnings/)
- TFT Set 14 "hacks": the leftmost augment slot gets extra rerolls and shows augments from one category. — [esports.gg TFT hacks](https://esports.gg/news/teamfight-tactics/tft-hack-mechanic-how-hacks-work-in-tft-set-14/)

### Inferences
- For a match-scoped draft: use pick-1-of-3 offers that weight upgrades to already-owned abilities (the Hades Pom equivalent) more heavily as the match goes on, and add StS-style hidden pity that raises rare/glitch-variant odds after several commons.
- Gate the strongest synergy offers (Duo-style combos) behind owning prerequisites, so they appear only when relevant. This keeps them exciting without padding early offers.
- Following Riot's lesson, snowball-type options (economy, scaling) should be time-gated so they cannot appear early.
- One free reroll per draft (or a Banish), with escalating cost Brotato-style if there is a currency, gives agency without lengthening the phase much.

### Gaps
- No primary designer postmortem (Supergiant GDC, MegaCrit) was retrieved. Hades god-offer weighting rules were not found. The TFT rule "all players get the same augment tier in a round" could not be confirmed from a source.

## 5. Balance and fairness in competitive drafting: mirror vs independent offers, counter-picking, hidden vs visible builds, snowballing, short matches, readability

### Takeaway
The evidence favours: mirrored or seed-shared randomness for fairness (Rocket League Rumble); structural catch-up over bounties (Stadium's admission, CS2's loss bonus); counter-build options that need the enemy build to be visible (Stadium); and stage-scaled stakes to keep matches short (Gauntlet HP loss damage, Stadium mercy rule).

### Cited Findings
- Rumble online gives both teams the same power-up queue in the same order. — [Rocket League wiki](https://rocketleague.fandom.com/wiki/Rumble)
- Stadium: bounties did not stop leading teams reaching powerful items faster. Blizzard added counter-items against strong builds and nerfed overpowered builds. — [Blizzard Lessons Learned](https://overwatch.blizzard.com/en-us/news/24191421/enter-the-stadium-lessons-learned-from-the-playtests/)
- Stadium players valued "countering your opponents' builds" and "glorious comeback runs", enough to reverse a best-of-5 change. — [Blizzard Director's Take](https://overwatch.blizzard.com/en-us/news/24246201)
- Stadium's Season 19 cut early-round, MVP and heal/damage cash bonuses, reducing snowball inputs. — [VPEsports](https://vpesports.com/games/overwatch/overwatch-2-the-return-of-the-up-to-4-wins-format-to-the-stadium)
- The Stadium mercy rule ends lopsided matches early (a 15,000-cash lead at R3, or losing the first 3 rounds; sources conflict). — [esports.gg](https://esports.gg/news/overwatch/every-overwatch-2-stadium-item-and-their-costs/); [Sportskeeda](https://sportskeeda.com/esports/overwatch-2-season-16-patch-notes-stadium-released-new-hero-freja)
- The CS2 loss bonus escalates by $500 per consecutive loss to a cap and resets on a win. — [csdb.gg](https://csdb.gg/guides/economy-guide/)
- In Gauntlet, the damage for a lost round rises from 10 to 30 by stage, with 40 s rounds. — [valorant-spind.de](https://www.valorant-spind.de/en/valorant-gauntlet-glitched.html)
- In Dota Ability Draft, late picks can deny key abilities. Counter-drafting from a shared pool is a core skill. — [bo3.gg](https://bo3.gg/dota2/articles/dota-2-ability-draft-guide)
- Matchmaking imbalance (premades vs solos) and stomps were Stadium's top player complaint. — [Blizzard Forums](https://us.forums.blizzard.com/en/overwatch/t/so-is-stadium-a-failure/972764)

### Inferences
- **Mirror vs independent:** for 1v1 ranked-feel queues, mirror the offer set (same seed per round for both sides). For 2v2/3v3, give each slot an independent offer but mirror slot-for-slot across teams (Rumble style). Gauntlet tournament mode can use independent offers, since the many-team structure averages out luck.
- **Visibility:** show enemy abilities and their level during the draft (icon plus level pips). Without that, counter-picking, which Stadium players valued, is impossible. Glitched abilities need a distinct visual tell (a colour or shader) so opponents can read them mid-fight.
- **Catch-up:** give the losing side a better offer (an extra option, a reroll, or a rarity floor) rather than more currency. Scale round stakes by stage rather than giving leaders compounding power.
- **Length:** a shared team HP pool with escalating loss damage, plus a mercy rule, puts a hard limit on match length.

### Gaps
- No source directly compared hidden and visible enemy builds, and no data on readability in draft shooters was found. These recommendations are inferred.

## 6. Designing random "glitch" modifiers that are fun rather than frustrating (agency, telegraphing, positive vs negative randomness)

### Takeaway
Use input randomness, revealed before the player commits: show the glitch at draft time and let the player accept or decline it. Prefer sidegrades that change an ability's role over pure nerfs, and give glitches their own upgrade path. Gauntlet's glitches roughly follow this: rare, from L2, with their own named L3. Player feedback asks for visible trade-off upgrades.

### Cited Findings
- Input randomness resolves before the player decides, output randomness after. Engelstein calls this "the fundamental difference between randomness that supports strategy, and randomness that undercuts strategy." — [Skeleton Code Machine](https://www.skeletoncodemachine.com/p/input-output-randomness-part-1); [Game Developer](https://www.gamedeveloper.com/game-platforms/the-2-types-of-randomness-and-how-to-apply-them-to-your-board-game); [Loop & Ledger](https://loopandledger.beehiiv.com/p/input-vs-output-randomness)
- A strategic move undone by a bad roll feels worse than a bad hand. Into the Breach uses mostly input randomness, with output randomness only where it helps the player. — [boardgamedesign newsletter](https://boardgamedesign.beehiiv.com/p/019-input-vs-output-randomness-a-couple-of-words-out-of-order-and-more)
- An academic study found input randomness can also significantly reduce satisfaction, so it is not automatically better. — [arXiv 2107.08437](https://arxiv.org/pdf/2107.08437v1.pdf)
- Gauntlet glitches are rare, start at L2, transform the ability (for example Healing Orb becomes a one-hit shield), and each has its own L3. — [valorant-spind.de](https://www.valorant-spind.de/en/valorant-gauntlet-glitched.html); [VALORANT Wiki](https://wiki.playvalorant.com/en-us/Gauntlet:_Glitched)
- Player feedback: add upgrades with drawbacks (for example a shorter cooldown that costs health) for more decision-making. — [VLR.gg](https://www.vlr.gg/758533/gauntlet-glitch)
- Vampire Survivors Banish lets players remove unwanted outcomes from the pool, which is agency over randomness. — [Steam discussion](https://steamcommunity.com/app/1794680/discussions/0/3276941718958957262)

### Inferences
- Treat glitches as a draft offer ("Glitched: Boom Bot becomes C4 Bot"), shown with clear text and VFX, rather than a surprise that triggers mid-round. If a glitch must roll during play, make it player-positive (output randomness that only helps), as in Into the Breach.
- Make glitches rare, tied to a level (L2+ like Valorant), and recognisable at a glance by opponents.
- Add pity so glitch-hunters eventually get one. Never apply a forced net-negative glitch without an opt-out.

### Gaps
- No GDC talk on randomness in competitive shooters was retrieved. Riot's own rationale for glitch rarity was not found.

## 7. Draft phase UX: timers, auto-pick, keeping the pre-round phase under 20 s and engaging

### Takeaway
Precedents show very short per-pick timers work (Dota Ability Draft: 7 s with random auto-pick on timeout). Gauntlet's 40 s rounds and no buy menu (one weapon from three) imply a draft of a few seconds. Stadium's heavier shop contributed to "long matches" complaints.

### Cited Findings
- Dota Ability Draft: 7 s per pick, random remaining ability on timeout, plus a planning phase of about 60 s. An alternative changelog figure is 12 s minus 1 s per extra teammate. — [Liquipedia](https://liquipedia.net/dota2/Ability_Draft); [Steam changelog](https://steamcommunity.com/sharedfiles/filedetails/changelog/2967572098?p=5)
- Gauntlet: no economy, a single weapon pick from three per round, and offers fixed within a stage. — [games.gg](https://games.gg/valorant/guides/valorant-gauntlet-glitched-guide/); [valorant-spind.de](https://www.valorant-spind.de/en/valorant-gauntlet-glitched.html)
- Stadium: Powers only every other round (1/3/5/7). Long matches were a top complaint. — [esports.gg](https://esports.gg/news/overwatch/all-overwatch-2-stadium-powers-and-how-they-work); [Blizzard Forums](https://us.forums.blizzard.com/en/overwatch/t/so-is-stadium-a-failure/972764)
- Brotato separates locked items and reroll cost, so players can plan across shops. — [Brotato wiki](https://brotato.wiki.spellsandguns.com/Shop)

### Inferences
- Target: about 10–12 s ability pick (1 of 3 plus a reroll button), auto-pick on timeout (pick the upgrade for the highest-level owned ability, or the first card), and the weapon offer either in the same screen or kept for the whole stage (Gauntlet) so it doesn't need a pick every round.
- Skip the timer once all players have locked in. Show teammates' and enemies' picks live, which also serves the counter-play visibility needed in section 5.
- Use a short pre-match "planning" window (Dota's 60 s) only once, at match start in the tournament mode, not every round.

### Gaps
- No source gave Gauntlet's or Stadium's actual draft/shop timer length, and no UX postmortem on draft timers was found.

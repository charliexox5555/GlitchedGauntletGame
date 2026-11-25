# Fantasy and Retention Plan (2026-11-25)

Owner's ask: launch days are weak (ads bring players, no likes, few favorites, friends love it). Find what breaks in the first session and make the game's fantasy, and maybe its name, pull players in and keep them. Sources: the owner's live onboarding funnel (last hour, 37 players), the ads readout in [Draft Duels Launch Art](../02%20Art/Draft%20Duels%20Launch%20Art.md), the code (`Config/Match`, `Config/Onboarding`, `Config/Bots`, `Config/Mods`) and web research (links at the end).

**Status (2026-11-25, owner: "show them the better guns", "rig [the free case] for an epic gun"):** built, not published or playtested:
- A1 first-match escalation, applied to both onboarding matches (`Config/Match.ONBOARDING_MATCHES = 2`, `ONBOARDING_PHASE_ROUNDS = {2, 4, 4, 7, 7}`).
- A2 guaranteed, preselected Glitched card from round 2 (`GLITCH.onboardingRound`). Round 1 already preselects a Mod.
- A3 Rookie bots (`Config/Bots` `profiles.Rookie`, `AUTO.onboarding`).
- A4 `MatchLeft` `kind:device`.
- B1 (partial): match 1's results screen has OPEN FREE CASE as its main button and no dead REMATCH. No in-screen case reveal yet.
- C1: match 2 is first to 3.
- The free case is the gift-only **Starter Case** (always an Epic gun skin). It is a separate case, not a rigged Standard Case, because the Standard Case is sold and lists 85% Common / 15% Rare.
- Guns: the owner renamed them. Mods keep their names. Game name: owner, later.
- Open: B1 auto next match / in-screen reveal, C2 loser's card, D (page), E (level rewards, referrals: next update).

## 1. What the numbers say

The funnel's step names come from the server that logged them ("M1 R4 live or won" exists only in the 2026-11-25 code), so this hour ran the first-to-3 first match. **37 players is a small sample:** one player is about 3%. Read the shape, not the decimals.

| Break point | Lost | What it means |
|---|---|---|
| Save ready → Match 1 launched | 2 (5%) | Loading. Loading and match-start fixes from 2026-11-25/26 target this. |
| **M1 R1 live → M1 R1 done** | **6 (17%)** | They quit **during the first fight**, not in a gap. Rounds 2–4 then hold at about 96% each: whoever gets past round 1 keeps playing. |
| **Match 1 saved → Returned to hub** | **6 (25%)** | The end of match 1 is a natural stopping point, and a quarter of players take it. |
| Hub → Backpack → case → equip → queue | 3 | The guided free case works (the auto-open helped). |
| **Match 2 R1 live → Match 2 saved** | **5 (33%)** | Match 2 is Beginner first to 4: longer, with no new hook. |

Before the game even loads: ads readout 802 clicks → 102 plays (**13%**) on the Gold Sniper thumbnail. The ad does its job (3.4–5% CTR). **The game page turns away 7 of every 8 people who clicked.** That is the name/fantasy problem in numbers: the page doesn't promise anything worth pressing Play for.

Discovery facts that change priorities (2026 discovery docs):
- Home recommendations ("Recommended For You") only count players who came **organically** from Home. Ad players don't train the algorithm. Ads are a test bench for the funnel, not a growth engine.
- The ranking signals are play-through rate from an impression, **first-play bounce** (leaving within 60 s and within 61–180 s, a negative signal), play days (D1, D2–7, D8–28) and playtime. Likes and favorites are not listed signals; they are social proof on the page.
- Our round-1 quitters are exactly the 61–180 s bounce Roblox now penalises.

## 2. Diagnosis: the fantasy never arrives

1. **The hook is back-loaded.** What makes us different is "new power every round, guns get bigger". But round 1 is Sidearm tier, Light comes from round 2, Heavy from round 4 and Elite from round 7 (`Config/Match.PHASES`). A first match is first to 3 (at most 5 rounds), so a new player who wins 3–0 sees pistol → light → light and one or two Mods. **Their first 60 seconds is a pistol duel against bots: a weaker RIVALS.** That is where the 17% leave.
2. **The identity reads as "Valorant on Roblox".** Guns: Vandal, Phantom, Sheriff, Operator, Odin, Ares, Spectre, Bulldog, Judge, Marshal, Guardian, Outlaw, Stinger, Bucky. Mods: Updraft, Molly, Recon, Stim, Flash. Players who know the reference compare us with RIVALS and Valorant; younger players don't know it. The set of names together is also Riot IP exposure, and Today's Picks curation asks for original games.
3. **"Draft Duels" names the system, not the payoff.** "Draft" is esports and card-game jargon. About 35% of Roblox daily users are under 13 and 38% are 13–17. Top PvP names say the action or the fantasy (RIVALS, Arsenal, Blade Ball, Combat Warriors, The Strongest Battlegrounds). Nobody wants to draft; they want powers.
4. **Match end has no pull forward.** Results screen → lobby → "done". Match 1 ends at about 4–5 minutes, before the player has a goal. The onboarding goal (free case) is only revealed after they reach the lobby.
5. **Losing has no upside.** The loser's extra card is parked ([Match Flow](../01%20Design/Match%20Flow.md) line 61). ROUNDS (Steam, 96% positive, 27k reviews) is built on "the loser gets a power", which keeps the losing player in. Without it, losing round 1 is a reason to leave.

## 3. The fantasy

**Promise (one line, for the page, the thumbnail and the first 10 seconds):** *Every round you get a new power. Stack them until you're unstoppable.*

The player fantasy is **building a broken combo and beating someone with it.** Words a 10–15-year-old reads instantly: *power, OP, stack, combo, glitched.* "Draft" can stay as an in-game verb ("pick").

**Signature moment: Glitched cards.** We already roll a glitch card (`Config/Match.GLITCH`, 15% rising to 40%). Make it *the* moment: a glitch-styled card that breaks a rule (double Mod, infinite dash for a round, bullets bounce). It gives the screenshot, the thumbnail and a word to name the game after. (The repo started as *GlitchedGauntletGame*.)

### Name (Owner)

Recommendation, in order. Check each name on Roblox search for clashes before choosing.

| Name | Why | Risk |
|---|---|---|
| **Power Duels** (recommended) | Says the payoff in two common words; searchable ("power", "duels"); already on the owner's shortlist. | Generic; needs a strong icon. |
| **Glitch Duels** | Distinctive, ties to Glitched cards, fits the original repo name. | Only works if Glitched cards are visible in match 1. |
| Stack Duels / OP Duels | Literal "stack powers" or "OP" fantasy kids search for. | "OP" may read as low-effort. |

- Title format: `[NEW] Power Duels` or a truthful update tag. Misleading tags break the Community Standards.
- Keep "1v1 / 2v2" in the description's first line, not the title.
- The approved Draft Ticket logo would need a new mark (**Owner**).
- A name can't be A/B tested in Roblox. Test it through ads instead: two ad creatives with the name in the art, same budget, compare click → play.

### Thumbnails and icon
- Show **a power going off mid-fight** plus one emotion, not a calm gun close-up. The current best ad (5.0%) is a character plus a colourful arena. The Gold Sniper close-up is the weakest at turning clicks into plays.
- Use thumbnail personalization: up to 5 clearly different variants, at least 7 days between resets, no clickbait.

## 4. Fixes, ranked by impact on the funnel

**A. The first fight shows the fantasy** (targets the 17% in round 1)
1. **First-match escalation:** per-mode phases for a first match: Light from round 1, Heavy by round 3. A 3-round match then shows the big guns.
2. **Starter power:** round 1 opens with a flashy Mod already slotted (Dash or Molly), and a **guaranteed Glitched card in round 2 of match 1**.
3. **Tutorial bots for match 1:** a profile below Easy (reaction 0.42 s is still fast on a phone). More `firstMisses` and lower accuracy, so a first win is likely. Beginner is already capped at Easy (`Config/Bots` `beginnerMax`).
4. **Measure before tuning:** read `MatchLeft` (custom event, fields: phase, score, kind). If most quits are phase "Live" on phones, the cause is controls or performance, not design. Put the device into the `kind` field (for example `first:phone`) so this split exists. There are only three custom fields.

**B. Match end pulls forward** (targets the 25% after match 1)
1. **Reward cascade on the results screen, not in the lobby:** XP bar fills → level up → "FREE CASE!" opened right there (the case reveal is the joy moment). Then **NEXT MATCH starts in 5 s** with a big Play button and a small "Lobby" option. Instant in-server matches already exist (`INSTANT_MATCHES = 2`), so this is UI plus flow, not new servers.
2. Show a short goal before they can leave: "Win 2 more → Rare skin" or "Level 3 → new Mod skin".
3. The first favorite prompt comes after the first **win** (a plain, unrewarded "Enjoying it? Like and favorite"), not after match 2. Rewarding likes is a grey area, and games can't detect likes anyway.

**C. Match 2 holds** (targets the 33%)
1. Match 2 is first to 3 as well (every instant onboarding match), then first to 4.
2. **Unpark the loser's extra card:** the losing side gets one more pick (or a reroll). It is the comeback mechanic that makes losing round 1 a reason to stay.
3. Match 2 introduces one new thing: a Heavy gun or a second Glitched card. Every match has a "first".

**D. Page and ads** (targets the 13% click → play)
1. New name, plus thumbnails showing a power firing, plus a description whose first line is the promise.
2. Ads stay a funnel test bench. Judge a change by M1 R1 completion and match 1 → next match, not by plays.

**E. Reasons to come back** (D1/D7)
1. Fill the level rewards table for levels 1–10 (it's empty). Every early level gives something you can see.
2. Friend invite rewards through Roblox's referral system (`ReferredByPlayerId`, reward both players). Co-play is also a ranking signal.
3. The 7-day login board is built. Show it on the results screen of the first match of the day.
4. Later: a Glitched card of the week (a limited-time rule-breaker): a cheap event and a reason to come back.

## 5. Renaming guns and Mods off Valorant (Owner)

The guns keep their models and stats; only names and icons change. Name each one for what it *does*, in Draft-Duels voice (for example Sheriff → "Hand Cannon", Operator → "Railgun", Molly → "Firebomb", Updraft → "Rocket Jump"). Pass the list to the owner before anything changes. Names live in `Config/Weapons` / `Config/Mods` plus UI art.

## 6. Targets

| Metric | Now (37 players) | Target |
|---|---|---|
| M1 R1 live → done | 83% | ≥ 92% |
| Match 1 saved → next match started | ~62% (to queue) | ≥ 85% |
| Match 2 completion | 67% | ≥ 85% |
| Ad click → play | 13% | ≥ 30% |
| D1 retention | — | 10% decent, 15% good |
| Average session | — | 15–20 min (top D1 games sit at 19–24 min sessions) |

Benchmarks: GameAnalytics 2025 Roblox report (games with 19–24 min sessions: median D1 11.5%, top 5% 23.6%). Roblox's own benchmark scorecard appears at 100+ DAU.

## 7. Suggested order
1. Instrument `MatchLeft` with device. Ship. Read one day.
2. A1–A3 (first-match escalation, starter power, guaranteed Glitched card, tutorial bots) + B1 (results-screen cascade into the next match). This is the biggest expected gain.
3. Name + thumbnails + description (**Owner** picks the name), tested through two ad creatives.
4. C2 (loser's card), E1 (level rewards), E2 (referrals).
5. Gun and Mod renames.

## Sources
- Roblox discovery and signals: https://create.roblox.com/docs/discovery · https://devforum.roblox.com/t/recommended-for-you-algorithm-improvements-that-better-value-long-term-retention/4684575
- Thumbnail personalization tips: https://devforum.roblox.com/t/5-tips-from-roblox-staff-to-get-the-most-out-of-thumbnail-personalization/3471689
- Today's Picks criteria: https://devforum.roblox.com/t/roblox-curation-how-do-we-consider-games-for-today%E2%80%99s-picks/4005089
- Onboarding guidance: https://create.roblox.com/docs/production/game-design/onboarding
- GameAnalytics 2025 Roblox report: https://www.gameanalytics.com/cn/reports/2025-roblox-report
- Roblox age split (Feb 2026): https://about.roblox.com/newsroom/2026/02/moving-beyond-self-reported-age
- ROUNDS: https://store.steampowered.com/app/1557740/ROUNDS/
- Similar Roblox funnel (PvPvE survivors, 134 joins): https://devforum.roblox.com/t/playtest-where-am-i-losing-players%E2%80%94before-during-or-after-their-first-match/4780000
- Referral rewards: https://create.roblox.com/docs/production/promotion/referral-system
- Like/favorite rewards debate: https://devforum.roblox.com/t/is-rewarding-players-for-liking-favoriting-a-game-allowed/2926286

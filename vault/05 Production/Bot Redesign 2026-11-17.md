# Bot redesign

Owner brief, 2026-11-17. Bots should take varied routes, move cleanly around the map, use Mods where they matter, and rotate into the sudden-death circle. Hard temporarily fills all modes while the owner tests. Difficulty is selected through config and Studio.

## Design and research

- Separate route planning, path following and local obstacle handling. Turn along the route when travelling and reserve aim tracking for threats the bot has perceived. [Mike Booth, The Making of the Official Counter-Strike Bot](https://media.gdcvault.com/gdc04/slides/making_of_official.pdf)
- Score actions using meaningful context such as shields, range, ammunition and the match objective. Tune behavior effectiveness per difficulty while keeping regular player movement and combat rules. [Brie Chin-Deyerle, Thinking Like Players](https://media.gdcvault.com/GDC%2B2022/Speaker%2BSlides/ThinkingLikePlayersHowHaloInfinitesBotsMakeDecision_ChinDeyerle_Brie.pdf) and [Halo Infinite bot team](https://www.halowaypoint.com/en-us/news/inside-infinite-august-2021)
- Route to grounded points, recover on lost progress, and choose cover with tests against observed threats. [Pathfinding Edge Cases and Fallbacks](../LihFolk/09%20Gameplay%20Systems/Pathfinding%20Edge%20Cases%20and%20Fallbacks.md) and [Ranged Enemy Tactics](../LihFolk/09%20Gameplay%20Systems/Ranged%20Enemy%20Tactics%20-%20Cover%20Points,%20Line%20of%20Sight%20and%20Peeking.md)

## Implementation plan

1. Preserve the existing match seats, movement simulation, weapon rules and spectator aim publishing.
2. Validate routes and steer around walls and ledges. Give bots different openings and let them break contact, take cover and re-peek.
3. Prioritize rotation as the circle shrinks. Score Mod opportunities by situation and verify the cast direction or landing before spending a charge.
4. Group difficulty tuning by perception, aim, tactics, movement and Mods. Compare lower and higher settings in Studio. Check firefights, recovery, zone entry and runtime cost.

## Owner decision from the playtest

OldTown2's original centre is inside the fountain pedestal. The owner approved fixing blocked circle placement as part of the redesign. ZoneService now tests floor support and standing room around the final circle. If the preferred spot is blocked, it searches nearby ground. This applies to the shared zone for bots and players. If a map offers no suitable ground nearby, Studio reports the marker so the map can be corrected.

## Results

See the [Studio playtest](Playtests/2026-11-17%20Bot%20Redesign.md). Both Rojo projects built, and StyLua and Selene passed. See [Bots](../01%20Design/Bots.md) for the difficulty controls and Studio debugging.

## Targeting and movement follow-up (2026-11-17)

The owner's Hard playtest found occasional poor target choices and choppy movement. The old vision budget could be spent before checking every visible opponent. The fixed one-second target hold also prevented a quick response to a closer threat. The follow-up gives every opponent in a 3v3 a sight check, prioritizes threats in usable gun range, and weights close-range pressure, recent fire and squad crowding. Reacquisition uses actual sight history. Movement eases between directions before clearance checks, and aim takes a bounded turn toward the exposed part. Hard is temporary across all modes until difficulty selection is set up.

## Appearance and identity (2026-11-17)

The owner chose one pooled sample from all joining players' friends and a grounded mix of levels and Locker choices. Each bot keeps a fictional identity and a fitted appearance through respawns. Friends have first priority, then approved backup IDs, then generated palettes. Up to 5.5 seconds of first-spawn avatar lookup can overlap the draft. The bot's selected reference account supplies the standard Roblox avatar headshot. Its fake name and bot stats key stay independent of that account. See [Bots](../01%20Design/Bots.md#match-presentation) for the backup list and tuning. [Roblox avatar APIs](https://create.roblox.com/docs/reference/engine/classes/Players#GetHumanoidDescriptionFromUserIdAsync)

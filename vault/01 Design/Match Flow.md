# Match Flow

How a match runs in the match place, from the map loading to someone winning. The user set this flow on 2026-11-02, based on Valorant's Gauntlet: Glitched, and **revamped it on 2026-11-07** ([Match Structure Revamp](../05%20Production/Match%20Structure%20Revamp.md): select from the moment you join, sudden death, death camera and spectating, final-kill replay, a match-end screen). **Status: phase A built (select flow, seats, sudden death); B–D next.** Tech: [Architecture](../04%20Tech/Architecture.md) → Match system.

**2026-11-17 implementation check.** Voting, spectating, final-kill replay and match-end choices have landed in the checkout. The [Developer Handoff](../04%20Tech/Developer%20Handoff.md) maps the current services. The phase status above describes the earlier rollout.

## The flow
0. **Map vote:** before the first draft the eligible maps and Random go into a chance vote. Each vote is a ticket. The vote takes up to 12 seconds and shows the selected map before loading. Studio `ForceMap` bypasses the vote. See `Config/Match.VOTE`.
1. **Joining:** the teleport overlay shows the ready player count. The server opens map voting once all expected players have their vote screen ready. Seats that have not connected after 20 seconds can fill with bots. A connected player's loading UI still has time to finish. A late player takes their stand-in's seat (kit, guns, levels) at once during a select, else at the next round. **A leaver in team modes is replaced by a bot; a side that has had real players and has none left loses the match** (so a 1v1 leaver forfeits). In a Studio playtest with one player, an **AI bot** fills the other side ([Bots](Bots.md)), or `BotMatch` sets the mode.
2. **Round loop:**
   - **Select:** **30 s in round 1, 15 s after**, ending in the **3-2-1** (guns in hand, barrier up). Every player picks **1 of 3 guns** (top row) and **1 of 3 abilities** (below), behind their spawn barrier. **A gun and an ability are selected from the start** (your last gun while it's still offered, else the first gun; the first ability card), so doing nothing is fine. Every select skips to the 3-2-1 once everyone has locked in. Quick melee does nothing behind the barrier.
   - **Fight:** the barrier drops. One life each, 50 s.
   - **Sudden death:** when the clock runs out, a circle closes over 20 s to a 4-stud radius and stays. It prefers the map's `ZoneCentre` marker or the midpoint between the spawns. If that spot is blocked, ZoneService looks for playable ground nearby. Outside the circle, you lose health directly at 10/s, increasing by 5 every 5 s. A screen tint and warning tick signal the danger. Bots head inside. At the 60 s sudden-death cap, the side with more health plus shield wins.
   - **Round end:** 5 s, who won, the score. Both last fighters dying at once scores nobody. **Shooting and Mods stay on** (2026-11-16), but no damage counts; surviving bots keep moving. Combat locks again when the next select opens.
   - **A round that stops on a script error** is played again on the same map (3 in a row end the match on the score), never a new match ([fixes](../05%20Production/Playtests/2026-11-16%20Match%20Fixes%20Round%201.md)).
4. **Match end (2026-11-07):** first to 5 rounds. The match-winning kill replays for everyone **through the killer's eyes, as they saw it** (first person, their gun and arms; slow motion into the hit). Then the winners stand on the map in a victory scene with the post-match screen: VICTORY / DEFEAT, your stats (eliminations, deaths, assists, damage dealt and taken, MVP), a table of everyone in team modes, and **Rematch** (every real player votes → a new match on the same server), **Play Again** (Lobby, straight back into that mode's queue) or **Leave** (Lobby). Bot rematch votes appear after a short delay. The next match requires every human vote. After 20 s, any remaining players are sent to the Lobby. Death camera and first-person spectating of teammates happen during the rounds (your killer at round end with no teammate alive). Details: [Match Structure Revamp](../05%20Production/Match%20Structure%20Revamp.md).

| Number | Value | Where |
|---|---|---|
| Health | **100**, plus a shield of 0–50 from your gun or the phase ([Gun Balance](Gun%20Balance.md)) | `Config/Combat`, `Config/Weapons` |
| First select / later selects | 30 s / 15 s, each including the 3-2-1 | `Config/Match` |
| Countdown | 3 s | `Config/Match` |
| Round | 50 s, then sudden death | `Config/Match` |
| Sudden death | 20 s shrink to 4-stud radius; 10 HP/s +5 every 5 s; 60 s cap | `Config/Match SUDDEN_DEATH` |
| Round end | 5 s | `Config/Match` |
| Win | First to 5 | `Config/Match` |

## The draft
### Guns and phases
Both sides see the same three guns each round. The server draws from role groups and rotates the lineup when a new round would repeat the previous set.

| Rounds | Phase | Offers from |
|---|---|---|
| 1 | Sidearm | Three of Classic, Ghost, Sheriff and Shorty |
| 2 | Light | Sheriff, one of Bulldog or Spectre, and one of Stinger, Bucky, Judge or Marshal |
| 3 | Light | One SMG, one shotgun, and one of Bulldog or Marshal |
| 4–6 | Heavy | Vandal or Phantom, Guardian or Outlaw, and Ares |
| 7+ | Elite | One of Vandal, Phantom or Guardian, plus Odin and Operator |

- **Shield:** in the Sidearm and Light phases the gun you choose sets your shield, and the card shows it. Round-two Sheriff gives 50 shield for choosing to play another round with a sidearm. From Heavy on, everyone gets 50. See [Gun Balance](Gun%20Balance.md).
- **Sidearms** go in the secondary slot. Selecting a primary replaces any drafted sidearm with Classic. The knife is always carried. In round one and when picking Sheriff in round two, there is no primary.
- **Ammo** starts full each round. Each gun has its own reserve, and reloads transfer rounds from that reserve. The HUD shows loaded rounds and reserve. See [Gunplay](Gunplay.md#round-ammunition).
- **Timeout:** your last click counts. With no click, you get the first card.

### Abilities
- **Fixed slots:** every ability belongs to one slot. The three columns are Q, E and T. See [Upgrade Paths](Abilities/Upgrade%20Paths.md).
- **One column per slot:** an empty slot offers one new Mod. Each seat gets its own roll. The dealer favors cards seen by fewer seats and skips that seat's previous offer when another Mod is available. A filled slot offers upgrades for the equipped Mod. You pick one card per draft:
  - level 1 offers paths A and B. An eligible seat has a 15% chance of one Glitch card, rising by five percentage points after each eligible miss to 40%. A hit resets the chance;
  - an ability at level 2 offers the **next level of its path**; level 3 is **MAXED**.
  - Studio: `Config/Dev ALWAYS_GLITCH_CARDS` puts the glitch card in every level-1 column.
- **Timeout:** your last click counts; with no click, the first card.
- Abilities and levels stay for the whole match. Charges refill every round.
- The draft screen shows the enemy's abilities with their levels.
- Code: `DraftService` (offers and picks, server-checked), `DraftController` (cards), and `Config/Match` (`PHASES`, `GUN_POOLS_BY_ROUND`, `GLITCH`).
- **Tested 2026-11-03 (Studio match vs the test opponent):** abilities go into their own slots, round 4 offers A/B per ability, a pity-rolled glitch card appeared, Firewall L1 → B2 → B3 applied in game.
- **Tested 2026-11-03, one column per slot:** round 1 offered Stim (Q), Molly (E), Frost (T); after picking Stim, round 2 showed Stim A2 / B2 in Q next to Dash (E) and Firewall (T); after A2, round 3 offered Stim A3. [Playtest](../05%20Production/Playtests/2026-11-03%20Draft%20Columns.md)

### Parked for later
The loser's extra card and reroll are parked. Sudden death and rematch are implemented. Mobile has separate UI in parts of the game and still needs device playtests.

## UI
UI v1 (2026-11-03): built from the Figma design, PC first. [UI Design](../02%20Art/UI%20Design.md).

## References
Saved in `02 Art/References/match-ui/third-party/` (git-ignored, the repo is public).

![Gauntlet draft screen](../02%20Art/References/match-ui/third-party/gg-ability-draft.jpg)
![Gauntlet draft in game](../02%20Art/References/match-ui/third-party/gg-yt-iIe87PXblzQ.jpg)
![Gauntlet spawn barrier and top bar](../02%20Art/References/match-ui/third-party/gg-yt-7kg-nDtcdBg.jpg)

| Source | Take |
|---|---|
| [Beebom: Gauntlet Glitched](https://beebom.com/valorant-gauntlet-glitched-mode/) | "Draft an ability": three tall cards with an icon, name, role tag and short text. The chosen card is bright, the others dim |
| [Trying Gauntlet: Glitched (video)](https://www.youtube.com/watch?v=7kg-nDtcdBg) | You stand in your spawn behind a glowing barrier while you draft. A top bar shows the timer, both teams' abilities and the stage |
| [New Gauntlet Glitched mode (video)](https://www.youtube.com/watch?v=iIe87PXblzQ) | Cards float in front of you, with Lock In and Reroll under the chosen one |
| [Our research notes](../03%20Research/Notes/ability_draft_design.md) | One weapon out of three each round; the weapon offer stays fixed within a stage and refreshes at a new stage. Tiers rise with the stage |
| LihFolk: Round-Based Minigame Loop, Arena Rounds with Teams and Spectating, Spawn Points Safe Zones and Respawn Flow | Publish state and end times as attributes, not per-second remotes. `CharacterAutoLoads` off, pcall the loop, tie timers to a round id. Server rolls and stores offers, so a pick is only ever checked against that list |

**Gaps:** I couldn't get frames from the videos here, so the screenshots are the only look at the UI, and none shows Gauntlet's weapon pick. Ours (a gun row above the ability cards) comes from the user's description.

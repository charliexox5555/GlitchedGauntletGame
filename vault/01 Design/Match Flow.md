# Match Flow

How a match runs in the match place, from the map loading to someone winning. The user set this flow on 2026-11-02, based on Valorant's Gauntlet: Glitched, and **revamped it on 2026-11-07** ([Match Structure Revamp](../05%20Production/Match%20Structure%20Revamp.md): select from the moment you join, sudden death, death camera and spectating, final-kill replay, a match-end screen). **Status: phase A built (select flow, seats, sudden death); B–D next.** Tech: [Architecture](../04%20Tech/Architecture.md) → Match system.

## The flow
1. **Joining (2026-11-07):** a Lobby match starts the moment its first player is in: the round 1 select screen is the wait. Every listed player who isn't here yet gets a **bot stand-in**, and empty slots fill with bots. A late player takes their stand-in's seat (kit, guns, levels) at once during a select, else at the next round. **A leaver in team modes is replaced by a bot; a side that has had real players and has none left loses the match** (so a 1v1 leaver forfeits). In a Studio playtest with one player, an **AI bot** fills the other side ([Bots](Bots.md)), or `BotMatch` sets the mode.
2. **Round loop:**
   - **Select:** **30 s in round 1, 15 s after**, ending in the **3-2-1** (guns in hand, barrier up). Every player picks **1 of 3 guns** (top row) and **1 of 3 abilities** (below), behind their spawn barrier. **A gun and an ability are selected from the start** (your last gun while it's still offered, else the first gun; the first ability card), so doing nothing is fine. Round 1 runs its full time; later rounds skip to the 3-2-1 once everyone has locked in.
   - **Fight:** the barrier drops. One life each, 50 s.
   - **Sudden death:** when the clock runs out, a **circle closes on the map's middle** (a `ZoneCentre`-tagged part, else halfway between the spawns) over 20 s to an 8-stud circle and stays. Outside it you lose **health directly (the shield doesn't absorb it)**: 10/s, +5 every 5 s. It looks like a glitch-storm wall (Blender texture), with a screen tint and a warning tick outside. Bots head inside. If a round somehow lasts 60 s into sudden death, more health plus shield wins.
   - **Round end:** 5 s, who won, the score. Both last fighters dying at once scores nobody.
4. **Match end:** first to 5 rounds. In testing a new match then starts by itself; later this goes back to the Lobby.

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
Both sides see the same 3 guns. The offer stays the same through a phase and changes when a new phase opens, so the gun you liked is still there next round.

| Rounds | Phase | Offers from |
|---|---|---|
| 1 | Sidearm | Tier 1 |
| 2–3 | Light | Tier 2 |
| 4–6 | Heavy | Tier 3 |
| 7+ | Elite | Tier 4, filled up from Tier 3 (only 2 guns in Tier 4 so far) |

- **Shield:** in the Sidearm and Light phases the gun you choose sets your shield, and the card shows it. From Heavy on, everyone gets 50. See [Gun Balance](Gun%20Balance.md).
- **Sidearms** go in the secondary slot and stay for the match. Other guns go in the primary slot. The knife is always carried. In round 1 there's no primary.
- **Timeout:** your last click counts. With no click, you get the first card.

### Abilities
- **Fixed slots (2026-11-03):** every ability lives in one slot: slot 1 = Q, slot 2 = E, slot 3 = T (keys become rebindable later). The list is in [Upgrade Paths](Abilities/Upgrade%20Paths.md) → Keys (Q: Updraft, Stim · E: Dash, Molly, Recon, Heal Orb, Recall · T: Firewall, Frost).
- **One column per slot (changed 2026-11-03, like Gauntlet: Glitched):** the ability row always has 3 columns, Q / E / T. An **empty** slot's column offers **one new ability for that slot** (the first of a shuffled order both sides share). A **filled** slot's column offers **that ability's upgrades**. So once you draft an ability it's locked into its key, and the next draft shows its upgrade next to new abilities for your other keys. You pick **one card per draft**, from any column:
  - an ability at level 1 offers **path A** and **path B**, plus the **glitch path** by chance (8% per ability, +3% every draft that offered none, capped at 25%; magenta card);
  - an ability at level 2 offers the **next level of its path**; level 3 is **MAXED**.
  - Studio: `Config/Dev ALWAYS_GLITCH_CARDS` puts the glitch card in every level-1 column.
- **Timeout:** your last click counts; with no click, the first card.
- Abilities and levels stay for the whole match. Charges refill every round.
- The draft screen shows the enemy's abilities with their levels.
- Code: `DraftService` (offers and picks, server-checked), `DraftController` (cards), numbers in `Config/Match` (`ABILITY_OFFERS`, `GLITCH`).
- **Tested 2026-11-03 (Studio match vs the test opponent):** abilities go into their own slots, round 4 offers A/B per ability, a pity-rolled glitch card appeared, Firewall L1 → B2 → B3 applied in game.
- **Tested 2026-11-03, one column per slot:** round 1 offered Stim (Q), Molly (E), Frost (T); after picking Stim, round 2 showed Stim A2 / B2 in Q next to Dash (E) and Firewall (T); after A2, round 3 offered Stim A3. [Playtest](../05%20Production/Playtests/2026-11-03%20Draft%20Columns.md)

### Parked for later
Set aside for this first version, not dropped: the loser's extra card and reroll, overtime with a shrinking zone, rematch, mobile and gamepad controls.

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

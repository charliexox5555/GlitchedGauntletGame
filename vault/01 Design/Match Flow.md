# Match Flow

How a match runs in the match place, from the map loading to someone winning. The user set this flow on 2026-11-02, based on Valorant's Gauntlet: Glitched. **Status: first version built, rough UI, PC only.** Tech: [Architecture](../04%20Tech/Architecture.md) → Match system.

## The flow
1. **Waiting:** the map loads and players get in. A match needs both teams. In a Studio playtest with one player, a **test opponent** fills the other side.
2. **Get ready:** a short countdown before the first draft.
3. **Round loop:**
   - **Draft:** every player picks **1 of 3 guns** (top row) and **1 of 3 abilities** (below), behind their spawn barrier. It ends early when everyone has locked in.
   - **Countdown:** 3 seconds, guns in hand, barrier still up.
   - **Fight:** the barrier drops. One life each. The round ends when a team is dead or the timer runs out, then more health plus shield wins. Equal totals score nobody.
   - **Round end:** who won, the score.
4. **Match end:** first to 5 rounds. In testing a new match then starts by itself; later this goes back to the Lobby.

| Number | Value | Where |
|---|---|---|
| Health | **100**, plus a shield of 0–50 from your gun or the phase ([Gun Balance](Gun%20Balance.md)) | `Config/Combat`, `Config/Weapons` |
| Get ready | 5 s | `Config/Match` |
| First draft / later drafts | 25 s / 15 s | `Config/Match` |
| Countdown | 3 s | `Config/Match` |
| Round | 50 s | `Config/Match` |
| Round end | 4 s | `Config/Match` |
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
- 3 random abilities you don't own yet. Both sides are dealt from the same shuffled order, so 1v1 offers match until someone owns one of them.
- Each pick fills the next slot: **Q, then E, then T**. *(Changing, decided 2026-11-03: each ability will have its own fixed key, e.g. Dash is always E. See [Upgrade Paths](Abilities/Upgrade%20Paths.md).)* Abilities stay for the whole match. Charges refill every round.
- **After 3 picks** the row shows your 3 abilities as "Upgrades coming soon" cards you can't pick. That's the spot for the L1 → L3 upgrades later.
- The draft screen shows the enemy's abilities, as the locked draft rules say.

### Parked for later
Set aside for this first version, not dropped: the loser's extra card and reroll, upgrades and paths, glitches, overtime with a shrinking zone, rematch, mobile and gamepad controls, final UI design.

## Rough UI
Only built to be playable: full-screen layout in Scale with a 16:9 aspect constraint, on PC. Final design comes later.

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

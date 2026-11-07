# Playtest: Match Revamp Phase A (2026-11-07)

Phase A of the [Match Structure Revamp](../Match%20Structure%20Revamp.md): select flow, seats, sudden death. Run by Claude in the match Studio through the MCP, solo against bots (`ForceMap` Dockyard2), with round 1's select shortened to 10 s and the fight to 8 s for the run (put back to 30 s / 50 s after).

## Results
| Check | Result |
|---|---|
| The select opens at once, no "Get ready" | ✅ Draft at 0 s; the clock counts to the fight, then Countdown 3 → Live |
| Gun and ability preselected | ✅ Round 2 opened with the first gun and the first ability card selected; "Ready: press Enter or LOCK IN" |
| Round 2+ ends early when all locked | ✅ Locked at 13.4 s left → Countdown at once (the bot locks instantly) |
| Sudden death at 0 | ✅ Phase SuddenDeath, circle from 166.7 → 4 studs at the spawn midpoint |
| Zone damage straight to health | ✅ Outside: HP 100 → 50 a few seconds in, shield untouched |
| Round ends when a side is out | ✅ The bot went down → ROUND WON, zone and tint cleared |
| Wall and tint | ✅ Seen in game: magenta glitch-storm curtain with a bright ground line; tint when outside. Made denser and the tint softer after the first look |
| `BotMatch` 2v2 | ✅ Draft opens at once with 3 bots (the player plus a bot vs 2 bots) |
| Recheck after review fixes | ✅ Found and fixed a 32-bit attribute bug (zone times); the client radius now shrinks 166.7 → 96.9 in 9 s, the ring uses fewer segments as it shrinks |
| Output | Clean (only the known Studio-plugin sound warning, Bugs #2) |

## Not tested
- **Late joining and leaving** (stand-in takeover, a bot replacing a team-mode leaver, a 1v1 forfeit): needs two real clients (Studio Test → Clients and Servers, 2 players).
- The bots' path into the circle from far corners, on every map.
- The warning sound (`UiSounds.ZoneWarn`, provisional) and the wall's look, for the user.

## What to test (user)
1. Play a match: the select appears straight away (30 s), something is already picked, LOCK IN in round 2 skips to the 3-2-1.
2. Let a round time out: SUDDEN DEATH banner, the storm wall closing in, tint and tick outside, health dropping (not the shield).
3. Two clients (2v2 with `BotMatch`): leave with one client mid-round → a bot takes the seat next round.

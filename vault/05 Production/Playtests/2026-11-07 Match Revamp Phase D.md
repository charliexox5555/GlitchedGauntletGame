# Playtest: Match Revamp Phase D (2026-11-07)

Phase D of the [Match Structure Revamp](../Match%20Structure%20Revamp.md): stats, the victory scene, the post-match screen and Rematch / Play Again / Leave. Run by Claude in the match Studio through the MCP, 1v1 against a bot, first-to-1 and an 8 s select for the runs (put back to 5 and 30 s after); the bot won by a kill.

## Results
| Check | Result |
|---|---|
| Replay → MatchEnd | ✅ After the final-kill replay, the MatchEnd phase (20 s) |
| Victory scene | ✅ A copy of the winning bot standing on the map with its gun, camera in front; live bodies, viewmodel and combat HUD hidden |
| Post-match screen | ✅ DEFEAT banner with 0 — 1; your card (name, @username, Eliminations 0 / Deaths 1 / Assists 0, Damage Dealt 0 / Taken 10 = the 10 HP the test left); Rematch "0 / 1 VOTED", Play Again, Leave; "BACK TO THE LOBBY IN 18" |
| Rematch | ✅ One vote (the only real player) → a new match on the same server at once (Draft, round 1), the screen gone, camera back to normal |
| Nobody picks | ✅ After 20 s: Studio logs "would teleport … to the Lobby" (Studio can't teleport) and starts a new match |
| Output | Clean (only the known Studio-plugin sound warning, Bugs #2) |

## Found and fixed
- After a rematch the death camera started for a moment on the previous match's downed body: it now only starts during Live / SuddenDeath.

## Not tested
- **Real teleports** (Play Again requeue, Leave, the timeout): need a published place; Studio only logs them.
- Whether the cheer animation plays on the winners' copies (the screenshot shows the gun pose), a 2v2 / 3v3 end screen with the table, a forfeit end, two players voting a rematch.

## What to test (user)
1. A published test: finish a match, press Play Again → you land in the Lobby already searching the same mode. Leave → plain Lobby. Do nothing → Lobby after 20 s.
2. Two players: both press Rematch → a new match; one presses Leave → Rematch shows UNAVAILABLE for the other.
3. A team match: the table of everyone, the MVP star.

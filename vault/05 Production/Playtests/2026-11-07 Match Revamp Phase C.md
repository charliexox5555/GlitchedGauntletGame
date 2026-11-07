# Playtest: Match Revamp Phase C (2026-11-07)

Phase C of the [Match Structure Revamp](../Match%20Structure%20Revamp.md): the final-kill replay. Run by Claude in the match Studio through the MCP, 1v1 against a bot (`ForceMap` Dockyard2) with first-to-1 and an 8 s select for the runs (put back to 5 and 30 s after). The player was set to 10 HP and the bot killed them.

## Results
| Check | Result |
|---|---|
| The match-winning kill triggers a replay | ✅ About 0.8 s after the kill: the Replay phase, then MATCH OVER / DEFEAT |
| Letterbox and caption | ✅ Black bars; FINAL KILL with killer › victim in team colours |
| Copies of the fighters and the camera | ✅ Last run: over the killer's shoulder with their gun in the foreground, looking down a container alley at the victim |
| Live HUD, viewmodel and bodies hidden during it | ✅ |
| After the review fixes | ✅ Replayed again: over the killer bot's shoulder as it fires round a container |
| Output | Clean (only the known Studio-plugin sound warning, Bugs #2) |

## Found and fixed along the way
- **The death camera came back during the replay:** spectating stops when the replay starts, but its tick saw you still down and started the death camera again, taking the camera back. No death camera now in Replay, MatchEnd or Waiting.
- **Your own gun and arms stayed on the camera after death:** the death camera stood WeaponController down before its own clean-up ran. The death camera and the replay now remove them.
- **Framing in narrow alleys:** the camera picks the first clear spot: over either shoulder, else high behind the killer; in the slow motion, beside or above the victim along the shot's line; never closer than 3 studs.
- The MCP tool resets the camera to Custom whenever a client-side command is running while the camera type changes, which spoils tests. Check the replay with screenshots only.

## Not tested
- The slow-motion close-up: screenshots are too slow to catch it.
- The recorded shots' tracers and flashes on the copies, the victim's fall in the replay.
- A team-mode replay, where other fighters went down earlier in the window, and a sudden-death (zone) kill with no killer (the orbit camera).

## What to test (user)
1. Win or lose a match by a kill: does the replay read well (shoulder, then close-up of the hit)? Is it the right length (4.8 s + 0.6 s hold)?
2. A zone kill as the last kill: the camera should orbit the victim.

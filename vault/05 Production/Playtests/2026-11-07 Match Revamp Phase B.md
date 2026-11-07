# Playtest: Match Revamp Phase B (2026-11-07)

Phase B of the [Match Structure Revamp](../Match%20Structure%20Revamp.md): death camera and first-person spectating. Run by Claude in the match Studio through the MCP (`ForceMap` Dockyard2), round 1's select shortened to 8 s for the run (put back to 30 s after).

## Results
| Check | Result |
|---|---|
| Death camera | ✅ The gun goes, the camera pulls up and back out of the head and watches the body crumple (screen greyed); crosshair and own panels hidden |
| Spectate a teammate (2v2 `BotMatch`, downed by setting HP 0 / Downed on the server) | ✅ After about 2 s: through bot teammate VEX's eyes, their sidearm and arms, the SPECTATING bar with their name (ally colour) and health; own health and ammo panels hidden |
| Watch the killer at round end (1v1, killed by the bot) | ✅ ROUND LOST, then through BOLT's eyes (name in enemy colour) with their gun |
| Output | Clean (only the known Studio-plugin sound warning, Bugs #2) |

## Found and fixed
- **Going down wasn't seen on your own character:** the `Downed` attribute's change signal didn't fire on the local, simulated character in the test, so the death camera never started and the gun stayed in hand after death (`WeaponController` relied on the same signal). Now polled: `SpectateController`, `WeaponController.pollDowned` and `ModController`, like `DeathFxController` already did.

## Not tested
- Cycling between two living teammates (needs 3v3: only one teammate in 2v2), the gamepad and touch arrows.
- A spectated player's reload, ADS zoom and scope overlay, a held Mod, and their shots' flash/tracer from the view gun (code paths in; not watched closely in the run).
- Real players (spectating a person's view rather than a bot's), streaming on a big map, a late joiner watching a teammate.

## What to test (user)
1. 2v2 `BotMatch`: get killed, watch the death camera, then your teammate's view. Does their gun, ADS, reload and firing look right?
2. 1v1: lose a round, watch your killer for the round-end seconds.
3. 3v3: cycle teammates with click / right-click (gamepad triggers, the bar's arrows on touch).

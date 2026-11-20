# Bot redesign Studio playtest

The [redesign](../Bot%20Redesign%202026-11-17.md) was synced through Rojo and tested in the Match place. The checks below describe local Studio behavior.

| Run | What happened |
|---|---|
| **Normal, OldTown2, 2v2** | Three bots took different openings and progressed through rounds. Telemetry recorded Engage, Hunt, Retreat and Cover, plus successful Roller casts. |
| **Hard, OldTown2, 3v3, first circle check** | A test circle at the previous map centre put the final safe area inside the fountain pedestal. All five prioritized Rotate, but the terrain blocked them from the final circle. |
| **Hard, OldTown2, 3v3, actual overtime after the fix** | Extra HP in the temporary play session let the match reach overtime. ZoneService moved the centre from the fountain to clear ground 16 studs away. All five bots switched to Rotate and were inside when the 20-second shrink ended. At that point they were 2.7–3.9 studs inside the edge. Four bots recorded a Firewall cast. Recorded BotService rolling averages during overtime peaked at 0.80 ms for five bots. |
| **Easy, Whitebox, 1v1** | The final synced code reached Live. The bot travelled about 67 studs in the opening sample, switched from Roam to Hunt and fired a shot. This was a smoke test with a passive practice target. |

The tests exercised bot movement and the real overtime phase on OldTown2. Bot difficulty feel against an actively fighting human and individual Mod variants still need broader playtesting. The pre-existing Studio asset-type warning surfaced in the match logs.

## Follow-up check (2026-11-17)

Verified the Hard default and six isolated checks in the synced Match Studio window. These covered seeing the third opponent, switching to a nearby shooter mid-commit, ignoring a heard-but-hidden opponent, choosing an alternative to a crowded target, rejecting stale sight, and bounding the turn toward a new opponent. Four OldTown2 checks confirmed open floor, blocked fountain approach, obstacle deflection and zone limits. Formatting, lint and both Rojo builds passed. The owner's play session was left alone. The perceived smoothness of the new movement is still to assess in a full match.

## Appearance and profile thumbnails (2026-11-17)

The OldTown2 2v2 tests covered the generated fallback when the cache was still filling. In the final start, all three bots picked distinct friend-derived outfits before the draft finished. The client loaded standard Roblox headshots in the top bar and used its existing placeholder for a generated profile. The scoreboard payload contained bot levels and the cosmetic ID in its own field, with no player ID on bot entries. Drafted bots equipped installed skins or Stock, and the round-two respawn preserved the same names, levels, outfits and Locker. Studio hit the existing asset/audio warnings. The server's backup-user list is still empty.

## Voting and Hard opening (2026-11-17)

Ran a regular 2v2 Studio vote with the forced map cleared. All four top-bar slots were visible during the vote, before any bot body spawned. The three bots cast eligible votes for OldTown, Greenhouse and OldTown. OldTown won. Over the first 12 seconds of Live, all three left spawn, and the opening trace showed Roam, Hunt, Engage and Cover without a prolonged circling loop. Two teammates converged at a corner, so team openings now keep their assigned lanes and preserve a small teammate-spacing input along their routes.

## Routing and appearance polish (2026-11-17)

In a Hard 2v2, all three bots loaded distinct account portraits and their device icons appeared on the top bar. Round-two bodies kept the devices and portraits assigned to their seats. A separate fallback check exhausted the ready outfits and confirmed the generated R15 body had the standard joints, collision constraints and a local colour palette. In the final synced 2v2 opening, all three bots advanced 83–101 studs from their start positions over 6.75 seconds. The sample recorded one brief reversal across the three bots and no repeated reversal. StyLua, Selene and the Match Rojo build passed.

## Hard difficulty tuning (2026-11-17)

A synced 2v2 loaded the revised Hard profile. All three bots fired and landed hits in round one, recording seven hits across 25 shots in the opening combat sample. StyLua, Selene and both Rojo builds passed. This was a live-profile smoke test.

## Match flow and bot variety

A Hard 2v2 reached Sudden Death and the final results screen at 5–3. A play-only probe preserved teams through the first round to trigger overtime and shortened later fights. The circle snapshot shrank, the results remained open after the vote clock expired, and three bot votes showed as 3/4. A separate rematch vote check accepted the human vote. Round-history storage held 80 entries totaling over 1 KB. Across three sampled rounds the bots changed lanes or opening roles and the surviving bot moved during RoundEnd. Flash and Firewall blocked target acquisition in controlled fixtures and shot rays still passed through Firewall. The Locker replica round-tripped equipped lines through a JSON StringValue.

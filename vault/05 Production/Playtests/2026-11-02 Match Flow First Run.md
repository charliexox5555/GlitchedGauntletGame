# Playtest: 2026-11-02, match flow first run

**Build / commit:** first match system
**Testers (device):** Claude only, one player in Studio on PC with the test opponent, using real mouse and keyboard input plus server commands to finish rounds quickly
**Matches played:** 2 whole matches; this checks that the flow works, not whether it's fun

## What was tested
| Test | Result |
|---|---|
| Map loads, you spawn in your alcove on 150 health | ✅ |
| Test opponent takes the empty side and drafts | ✅ |
| Get ready → draft → countdown → fight → round end | ✅ |
| Draft: choose a gun and an ability with the mouse, lock in | ✅ Ends the draft early |
| Draft timeout with no clicks | ✅ You get the first gun and the first ability |
| Gun and ability arrive in your hand and in slot Q / E / T | ✅ |
| Phases: Sidearm, Light (round 2), Heavy (round 4), Elite (round 7) | ✅ |
| After 3 abilities: "Upgrades coming soon" cards, gun only | ✅ |
| Barrier: visible and solid before the fight, gone during it | ✅ |
| Real shots hit the opponent; it shoots back | ✅ A Classic shot did 78 to the head; it took you from 150 to 114 |
| Ability hold registers in a live round | ✅ Heal Orb's hold on the server. Finishing the heal wasn't tested |
| You die: round lost. It dies: round won | ✅ |
| Timer runs out on equal health: draw, nobody scores | ✅ |
| First to 5 ends the match, then a new match resets everything | ✅ 5–3, then score, gun and abilities reset |
| Hostile picks (gun not offered, unknown ability, wrong types, 5,000-character string, lock with nothing chosen) | ✅ None stuck |

## After the security review
An independent code review found no way to get an unoffered card or to fire or cast while locked, but it did find bugs. All are fixed:

| Bug | Fix | Checked in play |
|---|---|---|
| Shots refused at a round's end could stop your gun for the rest of the session | Counter resyncs once with each new loadout | ✅ Resync arrives once per loadout; shots still land after it. The exact failure needs real ping, so it wasn't reproduced |
| Firewall and Molly burned into the next round | Everything clears at round end | ✅ A real Firewall went from 10 parts to 0 at round end. Molly not cast |
| A death behind the barrier (or a failed spawn) lost the round instantly | Respawn before the barrier drops; no live player means no score; Reset Character off | ✅ Reset is off. Killed the moment a draft opened: back at spawn on 150 health before the barrier dropped, no point lost |
| Map spawns could give a 10 s shield | `Duration = 0` | ✅ By code |
| A leaver could erase the winner's result | Whoever stays wins the match | ❌ Not run: it needs 2 real clients |
| Teams never rebalanced | Rebalance while waiting and at match start | ❌ Not run: it needs 3 real clients |
| A late offer could open the draft during a fight | Ignored once its time has passed | ❌ By code only |
| Owner's dev panel worked in live matches | Off on live servers with test mode off | ❌ By code only |
| A missing map or a mid-round error left the server stuck | Retries the map; relocks and raises barriers | ❌ By code only |

## Not tested yet
- **Two real players.** Everything so far is one player plus the stand-in
- All 9 abilities inside a match, and their leftovers clearing between rounds
- A player leaving mid-match, or joining late
- Whether the numbers feel right: 150 health, 15-second drafts, 50-second rounds
- Anything but PC

## What the user should look at
- Does the draft feel right, and is 15 seconds enough?
- 150 health changes kills: see "Health" below.

## Health
Going from 100 to 150 means more shots to kill, because gun damage hasn't changed:

| Gun | At 100 health | At 150 health |
|---|---|---|
| Vandal | 4 body or 2 head | 5 body or 3 head |
| Phantom | 4 body or 2 head | 6 body or 3 head |
| Classic | 4 body or 2 head | 6 body or 3 head |
| Guardian | 2 body or 1 head | 3 body or 2 head |
| Outlaw | 1 body | 2 body or 1 head |
| Marshal | 1 body | 2 body or 1 head |
| Operator | 1 body | 1 body (exactly 150) |

## Top fixes (ranked)
None known. Waiting for the user's run.

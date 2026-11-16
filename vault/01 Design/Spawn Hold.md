# Spawn hold (pre-round), 2026-11-16

**Decision (owner asked for one, picked by Claude 2026-11-16):** players wait for the round **in place at their spawn markers on the open map**, RIVALS-style, not in spawn rooms and not in a Valorant-style raised room they drop from. **No spawn nooks or indents on any new map** (owner: they "don't look good").

## How it plays
- Draft (15-30 s) and the 3-2-1: you stand on your marker. You can look around (and see the draft screen). You **can't move or shoot**.
- Your body is a **ghost**: semi-transparent to everyone (about 0.6), can't be hit, doesn't collide with enemies. Bots the same.
- On GO the ghost goes solid and movement unlocks for everyone on the same frame.
- Spawn markers sit behind a spawn screen on the map, so nobody is seen standing at spawn when the round starts (layout check: enemy-half floor that sees a spawn ≤ ~5%).

## Why not the other two
| Option | For | Against |
|---|---|---|
| **Hold in place, ghosted (chosen)** | No map geometry; maps stay clean (no nooks, no gates); same on all 13 maps and every round reset; the draft screen is what you look at anyway | Needs a small code change (below) |
| Raised hold room, drop in (Valorant-like) | Feels like a launch | A room per side on every map (26 rooms) that must be hidden from the map; landing timing and height differences make starts unfair; you barely see it behind the draft screen |
| Spawn rooms behind gates (what we had) | Already built | The indents the owner dislikes; gates and walls per map |

## Build (code, not started; match place was busy)
- `MatchService`: during `Draft` / `Countdown`, set a Player attribute (e.g. `SpawnHold = true`) on each fighter; clear it on GO. Server rejects fire and damage while it's set (the round isn't live yet, so most of this exists: check `WeaponService` freeze).
- A client controller: while `SpawnHold`, zero the move input (clients own movement while Server Authority is off), keep camera look, set `LocalTransparencyModifier`-style ghosting on other characters (0.6) and on your own third-person body.
- Bots: `BotService` waits for GO (it already waits for the phase; check).
- `MapService.setBarriers` stays: maps without `ArenaBarrier` parts just have none. The old maps keep their gates until they're retired.
- Numbers (ghost transparency) in `Config/Match`.
- Security: nothing new from the client; the hold is server state.

First maps that need it: [Arena + Big Arena](Maps/Arena.md).

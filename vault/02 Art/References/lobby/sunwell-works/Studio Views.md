# V3 lobby Studio views

Captured from the connected **Lobby | gauntletgame** place, ID `71551303511506`, in Studio Edit mode. The tool framed each shot with the camera position and look target below. Coordinates are Roblox `(X, Y, Z)` in studs. The open camera's field of view was 70°. These views record the live V3 world used to plan Sunwell Works.

| Studio shot | Camera | Look target |
| --- | --- | --- |
| [Arrival view of the current circular hub and Gauntlet](../sunwell-refresh/studio/01-hub-from-spawn.jpg) | `(8, 4.6, 19)` | `(-3, 7, -25)` |
| [Reverse hub view toward Range and Shop](../sunwell-refresh/studio/02-hub-reverse.jpg) | `(12, 5, -17)` | `(-12, 5, 21)` |
| [Existing stacked-part bench and leaderboard niche](../sunwell-refresh/studio/03-hub-bench.jpg) | `(24, 3.4, -17)` | `(25, 2, -22)` |
| [Locker from the doorless steel threshold](../sunwell-refresh/studio/04-locker-threshold.jpg) | `(46, 4.5, 1)` | `(80, 6, 0)` |
| [Locker display bays and central Vandal projector](../sunwell-refresh/studio/05-locker-gallery.jpg) | `(62, 4.4, -13)` | `(91, 5.3, 6)` |
| [Locker return through the open collar](../sunwell-refresh/studio/06-locker-reverse.jpg) | `(90, 4.4, 12)` | `(56, 5, 0)` |
| [Shop entry and current featured-case canopy](../sunwell-refresh/studio/07-shop-from-arch.jpg) | `(-62, 3.7, 2)` | `(-117, 5.5, 0)` |
| [Shop wall displays and counter from the side](../sunwell-refresh/studio/08-shop-alcoves.jpg) | `(-94, 3.4, 11)` | `(-100, 4.5, -25)` |
| [Duels ramp and existing straight aisle](../sunwell-refresh/studio/09-duels-entry.jpg) | `(4, 3.5, -57)` | `(0, 4, -103)` |
| [Current paired 1v1 pad and status panels](../sunwell-refresh/studio/10-duels-station.jpg) | `(2, 2, -89)` | `(-23, 2.5, -96)` |
| [Gauntlet end stage and existing bulkhead](../sunwell-refresh/studio/11-duels-gauntlet.jpg) | `(9, 2.5, -202)` | `(0, 5.5, -245)` |
| [Range ready room and two preview windows](../sunwell-refresh/studio/12-range-ready-room.jpg) | `(-5, 3.4, 68)` | `(0, 3.8, 100)` |
| [Range preview window and threshold close-up](../sunwell-refresh/studio/13-range-preview-windows.jpg) | `(10, 1.8, 82)` | `(5, 3.2, 102)` |
| [Separate RangeFar practice lanes](../sunwell-refresh/studio/14-range-far-lanes.jpg) | `(-8, 4.6, 1261)` | `(0, 6, 1110)` |
| [RangeFar return portal](../sunwell-refresh/studio/15-range-far-return.jpg) | `(12, 4.6, 1260)` | `(28, 7, 1290)` |

## Active scene measured in Studio

- `Workspace.Lobby.Hub` contains the V3 hub, `Duels`, `Market`, `Vault`, `Range`, `Anchors`, `Markers` and effects. Current V3 entrances are Duels −Z, Shop −X, Locker +X and Range +Z.
- Within the live lobby there are 16 `LobbyQueue` zones and one each of `LobbySpawn`, `LobbyShop`, `LobbyBattlePass`, `LobbyLocker` and `LobbyRangeEntrance`. The archived old hub also holds tags. Scope counts to the active lobby.
- `Workspace.Lobby.Hub.Markers.RangeReturnPoint` was at `(0, -1.5, 84)`. `Workspace.Lobby.Greybox.RangeFar.RangeArrivalPoint` was at `(0, 0.5, 1278)`. `RangeExitTrigger` was at about `(32, 5, 1289.1)` in the same RangeFar folder.
- In the checked-in lobby code, `WorldPrompts.luau` routes queue tags by `Mode` and hooks each menu tag. `Panels.luau` renders a future-opening Range panel. Runtime behavior is for the staged build's playtest.

[Back to the concept pack](../../../Sunwell%20Lobby%20Reference%20Pack.md)

# Maps

The match maps: a mix of RIVALS (fast, simple, run-and-gun readable) and Valorant (disciplined layouts, callouts, clean value structure). The rules for building one are in the [Game Plan](../../05%20Production/Game%20Plan.md) §5.

**Status (2026-11-02):** the old sci-fi names (Cache, Firewall, Mainframe) are retired with the shelved digital theme. [Whitebox](Whitebox.md) is built and waiting for approval; the rest are ideas.

## Roster
| Map | Status | Modes | Idea | Built with |
|---|---|---|---|---|
| [Whitebox](Whitebox.md) | 🟡 Built, waiting for approval | 1v1, 2v2 | White panels under a big sky; four pillars around a diamond | Parts in Studio |
| **Bunker** | 💡 Idea | 2v2, 3v3 | Concrete halls and a sunlit central shaft, tying the maps to the Lobby. Tight flanks, one bright middle | The Lobby's Blender kits, which already exist |
| **Container Yard** | 💡 Idea | 1v1, 2v2 | Stacked shipping containers at a dock at dusk. Stack tops are the high lane | One Blender container kit, repeated |
| **Metro** | 💡 Idea | 2v2, 3v3 | A station: two platforms with a lower track lane between them and a parked train as cover | Blender kit plus Parts |
| **Rooftops** | 💡 Idea | 1v1, 2v2 | Two buildings joined by a bridge and ziplines or Updraft routes. Falling off is a real risk | Parts plus light Blender props |
| **Courtyard** | 💡 Idea | 2v2, 3v3 | A warm stone plaza with arches and a central fountain, the most Valorant-looking of the set (Ascent's open middle) | Blender kit |

## What every map shares
- **Rules:** Game Plan §5: three lanes, half cover 3 / full cover 7+, doors at least 6 wide, two exits per room, spawns out of sight.
- **Check before building:** a layout script like `tools/maps/whitebox_layout.py` that prints gaps, sightlines and route times.
- **Stages:** greybox → play → look, with a review at each stop.
- **Tracking:** the [Asset Tracker](../../06%20Assets/Asset%20Tracker.md) row and a note in `05 Production/Playtests/` for each test.

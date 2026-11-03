# Maps

The match maps: a mix of RIVALS (fast, simple, run-and-gun readable) and Valorant (disciplined layouts, callouts, clean value structure). The rules for building one are in the [Game Plan](../../05%20Production/Game%20Plan.md) §5.

**Status (2026-11-02):** the old sci-fi names (Cache, Firewall, Mainframe) are retired with the shelved digital theme. [Whitebox](Whitebox.md) is built and its layout is approved; the rest are ideas.

## Roster
| Map | Status | Modes | Idea | Built with |
|---|---|---|---|---|
| [Whitebox](Whitebox.md) | 🟡 Built, layout approved | 1v1, 2v2 | White panels under a big sky; four pillars around a diamond | Parts in Studio |
| **Bunker** | 💡 Idea | 2v2, 3v3 | Concrete halls and a sunlit central shaft, tying the maps to the Lobby. Tight flanks, one bright middle | The Lobby's Blender kits, which already exist |
| [Dockyard](Dockyard.md) | 🟡 Layout checked, scripts + kit built, not yet run in Studio | 1v1 to 4v4 | A container pier at dusk: red / blue / green lanes, a gantry crane over the middle, a Shed on each flank, harbour on both sides. Origin (-1500, 200, 0) | Parts greybox + one Blender kit |
| [Metro](Metro.md) | 🟠 Scripted, not yet run in Studio | 2v2–4v4 | Meridian station: two platforms, a sunken track lane with two staggered trains, a terrace over each end, service-corridor flanks. Origin (1500, 200, 0) | Blender kit (`Station`) plus Parts |
| **Rooftops** | 💡 Idea | 1v1, 2v2 | Two buildings joined by a bridge and ziplines or Updraft routes. Falling off is a real risk | Parts plus light Blender props |
| [Old Town](Old%20Town.md) | 🟠 Scripts written, not run in Studio | 2v2–4v4 (large) | Sunlit stone plaza, fountain, arcades with a cafe terrace, shaded alleys, a clock tower; origin (0, 200, 1500) | Blender kit plus Parts |

## What every map shares
- **Rules:** Game Plan §5: three lanes, half cover 3 / full cover 7+, doors at least 6 wide, two exits per room, spawns out of sight.
- **Check before building:** a layout script like `tools/maps/whitebox_layout.py` that prints gaps, sightlines and route times.
- **Stages:** greybox → play → look, with a review at each stop.
- **Tracking:** the [Asset Tracker](../../06%20Assets/Asset%20Tracker.md) row and a note in `05 Production/Playtests/` for each test.

## How a map is built (pipeline, 2026-11-03)
The Lobby's proven hybrid ([Lobby Kit](../../02%20Art/Lobby%20Kit.md) → Pipeline), adapted for match maps: **Parts are the gameplay and the collision; a Blender kit is the look.**
1. **Concept + layout check:** `tools/maps/<map>_layout.py` (like `whitebox_layout.py`): the top-down plan as data, printing gaps, sightlines, spawn safety, cover spread and route times, and writing `vault/02 Art/References/maps/<map>/<map>-layout.svg`. Rules: Game Plan §5 and "What every map shares" above.
2. **Greybox:** `tools/studio/maps/<Map>/Greybox.luau`, on the shared prelude `tools/studio/maps/MapKit.luau` (`newMap`, `section`, `box`, `wedge`, `cyl`, `spawnPad`, `barrier`, `report`). Bundle with `python tools/studio/maps/bundle.py <Map> Greybox -o <file>` and run it in the match place (edit mode). It builds `Workspace.<Map>` (Greybox / Art / Spawns / Barriers) at the map's own world origin, 4 spawns per team tagged `ArenaSpawn_A` / `ArenaSpawn_B`, barriers tagged `ArenaBarrier`.
3. **Blender kit:** `tools/blender/build_map_kit_<map>.py` (on `lobbykit.py` helpers) → `art-source/maps/<Map>/Kit_<Map>.blend`, one `Map_<Piece>` collection per piece at the origin, plus a contact sheet render in `vault/02 Art/References/maps/<map>/`. Export: `blender --background --factory-startup art-source/maps/<Map>/Kit_<Map>.blend --python tools/blender/export_lobby_kit.py -- --maps <Map> <Group>` → `art-source/maps/<Map>/Exports/`. Upload: `python tools/opencloud/upload_models.py --maps <Map> --group 11116787 <Group>`.
4. **Install + dress:** `python tools/studio/maps/kit_bundle.py <Map> <Group> -o kit.luau` (run in the match place: `ServerStorage.MapKit.<Map>`), then `tools/studio/maps/<Map>/Art.luau` places pieces with `put()` and hides replaced greybox with `hide()` (the greybox stays the collision), and `Lighting.luau` for the map's look.
5. **Check:** walk it, screenshots from each spawn, the middle and an overview, the mobile budget, then save the place and back up `art-source/maps/<Map>/<Map>.rbxm`.

**World origins** (so maps in Workspace never overlap): Whitebox (0, 200, 0); each new map gets its own origin, listed in its note.

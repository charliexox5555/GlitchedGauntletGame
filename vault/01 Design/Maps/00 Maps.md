# Maps

The match maps: a mix of RIVALS (fast, simple, run-and-gun readable) and Valorant (disciplined layouts, callouts, clean value structure). The rules for building one are in the [Game Plan](../../05%20Production/Game%20Plan.md) §5.

**Status (2026-11-03):** the **release lineup is 8 maps** (decided by Claude overnight on the user's "use your judgement"; research below). **Built in Studio:** Whitebox, Big Whitebox, Dockyard, Metro, Old Town (all playable as matches; `Workspace.ForceMap` = map id in Studio to test one). **Concepts:** Rooftops, Bunker. Matches pick a map by team size from `Config/Match MAPS`.

## Release lineup (2026-11-03)
Why 8: Valorant launched with 4 maps, its TDM and Skirmish modes with 3 each; RIVALS (about 30 maps now) holds a vote before each duel and forces its "Big" maps at 3v3 and up, reusing one layout family at two sizes. So: enough variety for a vote at every team size, small maps for duels, big ones for 3v3–4v4, indoor and outdoor, and one cheap "Big" twin of the first map.

| Size | Map | Teams | Where | Theme |
|---|---|---|---|---|
| Small | Whitebox | 1v1–2v2 | outdoor (sky) | white panel arena |
| Small | Rooftops | 1v1–2v2 | outdoor | concept |
| Medium | Bunker | 1v1–3v3 | indoor | concept |
| Medium–large | Dockyard | 1v1–4v4 | outdoor, dusk | container port |
| Large | Metro | 2v2–4v4 | indoor | metro station |
| Large | Old Town | 2v2–4v4 | outdoor, afternoon | stone plaza |
| Large | Big Whitebox | 3v3–4v4 | outdoor (sky) | Whitebox, bigger |

(8th slot open: a second indoor medium after the first playtests, e.g. a museum or a greenhouse.)

## Roster
| Map | Status | Modes | Idea | Built with |
|---|---|---|---|---|
| [Whitebox](Whitebox.md) | 🟡 Built, layout approved | 1v1, 2v2 | White panels under a big sky; four pillars around a diamond | Parts in Studio |
| [Big Whitebox](Big%20Whitebox.md) | 🟡 Built in Studio 2026-11-03, playtested solo | 3v3–4v4 | Whitebox scaled up: 120 × 176 room, three lanes, two perches a side. Origin (0, 200, -1500) | Parts (MapKit script) |
| [Dockyard](Dockyard.md) | 🟡 Built in Studio 2026-11-03, playtested solo (lighting brightened) | 1v1 to 4v4 | A container pier at dusk: red / blue / green lanes, a gantry crane over the middle, a Shed on each flank, harbour on both sides. Origin (-1500, 200, 0) | Blender kit (`Kit`) plus Parts |
| [Metro](Metro.md) | 🟡 Built in Studio 2026-11-03, playtested solo | 2v2–4v4 | Meridian station: two platforms, a sunken track lane with two staggered trains, a terrace over each end, service-corridor flanks. Origin (1500, 200, 0) | Blender kit (`Station`) plus Parts |
| [Old Town](Old%20Town.md) | 🟡 Built in Studio 2026-11-03, playtested solo | 2v2–4v4 (large) | Sunlit stone plaza, fountain, arcades with a cafe terrace, shaded alleys, a clock tower; origin (0, 200, 1500) | Blender kits (`Structure`, `Props`) plus Parts |
| [Rooftops](Rooftops.md) | 🟡 Built offline 2026-11-03 (kit uploaded), not yet run in Studio | 1v1, 2v2 | A city block at blue hour: two team roofs over a sunken Pit with a water-tank tower, side towers (+8) on a gangway and a plank ramp, 8-wide alleys to fall into (KillDepth 24). Origin (1500, 200, 1500) | Blender kit (`Kit`, asset 112960022711405) plus Parts |
| **Bunker** | 💡 Concept | 1v1–3v3 | Concrete halls and a sunlit central shaft, tying the maps to the Lobby. Tight flanks, one bright middle | The Lobby's Blender kits, which already exist |

## What every map shares
- **No z-fighting (user, 2026-11-03):** no two visible surfaces may share a plane and overlap (the renderer flickers between them). Parts butt edge to edge instead of overlapping; trims, paint, bands, caps, signs and cloth stand **≥ 0.05 studs proud** of the surface they sit on; split-material parts in a kit piece meet without coincident faces. Checked in Studio by `tools/studio/maps/Audit.luau` (`loadstring(src)("<Map>")`: rays at shared planes, hidden faces skipped; full list to `art-source/maps/<Map>/audit.json`). **Target 0.** Whitebox and Big Whitebox were fixed to 0 on 2026-11-03.
- **Looks natural:** props sit believably (no floating piles, nothing clipping), windows follow floor heights on a regular rhythm, door and window frames match their openings.
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
